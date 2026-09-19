extends Node3D
## All network RPCs live on /root/Main. Only the host simulates gameplay.
const Actor = preload("res://scripts/gladiator.gd")
const Equipment = preload("res://scripts/equipment.gd")
const Arena = preload("res://scripts/arena.gd")
const Interface = preload("res://scripts/interface.gd")
const Sound = preload("res://scripts/arena_audio.gd")
const V = preload("res://scripts/visuals.gd")
const Melee = preload("res://scripts/melee_physics.gd")
const MODES = ["Free-for-All", "Co-op Survival", "Champion Fight", "Last Champion"]
const PORT = 27840
const COLORS = [Color("398b91"), Color("b74a37"), Color("7f73a6"), Color("c19435")]
var actors = {}
var items = {}
var arena
var ui
var sound
var camera: Camera3D
var authority = true
var networked = false
var running = false
var menu_open = false
var phase = "menu"
var mode = 1
var round_number = 1
var phase_elapsed = 0.0
var elapsed = 0.0
var remaining = 180.0
var wave = 0
var wave_pause = 0.0
var pit_open = false
var pit_warned = false
var beast_released = false
var champion_released = false
var first_barracks = true
var next_item_id = 1
var next_bot_id = -1
var snapshot_clock = 0.0
var snapshot_sequence = 0
var last_snapshot_sequence = -1
var pending_snapshots = {}
var input_clock = 0.0
var crowd_clock = 0.0
var sensitivity = 1.0
var swing_sensitivity = 1.0
var mouse_weapon_target = Melee.REST
var camera_yaw = 0.0
var camera_pitch = -0.30
var camera_center = Vector3(0, 1.5, 25)
var camera_initialized = false
const CAMERA_ZOOM_MIN = 2.0
const CAMERA_ZOOM_MAX = 9.0
var first_person = true
var third_person_zoom = 5.2
var camera_distance = 5.2
var camera_subject = null
var pending_name = "Gladiator"
var connection_wait = 0.0
var spectating_id = 0
var spectator_cooldowns = {}
var demo_clock = 0.0
var test_no_input = false
var effect_nodes = []

func _ready() -> void:
	name = "Main"
	arena = Arena.new()
	arena.name = "Arena"
	arena.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(arena)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 68
	camera.far = 180
	camera.current = true
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(camera)
	sound = Sound.new()
	add_child(sound)
	ui = Interface.new()
	ui.game = self
	add_child(ui)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): leave_session("Couldn't connect. Check the host IP and UDP 27840."))
	multiplayer.server_disconnected.connect(func(): leave_session("The host left the arena."))
	multiplayer.peer_disconnected.connect(_disconnected)
	_setup_inputs()

func _setup_inputs() -> void:
	var keys = {"move_left": KEY_A, "move_right": KEY_D, "move_forward": KEY_W, "move_back": KEY_S, "sprint": KEY_SHIFT}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key = InputEventKey.new()
			key.physical_keycode = keys[action]
			InputMap.action_add_event(action, key)
	if not InputMap.has_action("guard"):
		InputMap.add_action("guard")
		var mouse = InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("guard", mouse)

func local_id() -> int:
	return multiplayer.get_unique_id() if networked else 1

func start_session(online: bool, player_name: String, chosen_mode: int) -> void:
	if running or connection_wait > 0:
		return
	if online:
		var peer = ENetMultiplayerPeer.new()
		var error = peer.create_server(PORT, 3, 3)
		if error != OK:
			ui.status.text = "Port %d is in use. Close the other host or use Join." % PORT
			return
		multiplayer.multiplayer_peer = peer
	else:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	authority = true
	networked = online
	mode = clampi(chosen_mode, 0, 3)
	round_number = 1
	first_barracks = true
	running = true
	spawn_actor(1, clean_name(player_name), "player", Vector3(0, 0.05, 26), false, COLORS[0])
	enter_barracks()
	_show_game()
	ui.announce("WELCOME TO THE BARRACKS", "Grab some equipment. Press Enter when you're ready.")

func join_session(address: String, player_name: String) -> void:
	if running or connection_wait > 0:
		return
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address.strip_edges(), PORT, 3)
	if error != OK:
		ui.status.text = "Invalid host address. Enter an IP address or hostname."
		return
	authority = false
	networked = true
	pending_name = clean_name(player_name)
	multiplayer.multiplayer_peer = peer
	connection_wait = 10
	ui.status.text = "Connecting…"

func clean_name(value: String) -> String:
	var result = value.strip_edges().replace("\n", "").replace("\r", "").replace("\t", "").left(18)
	return result if not result.is_empty() else "Gladiator"

func _connected() -> void:
	connection_wait = 0
	register_player.rpc_id(1, pending_name)

@rpc("any_peer", "call_remote", "reliable", 0)
func register_player(player_name: String) -> void:
	if not authority or not running:
		return
	var id = multiplayer.get_remote_sender_id()
	if id <= 1 or actors.has(id):
		return
	var humans = human_actors()
	if humans.size() >= 4:
		return
	var actor = spawn_actor(id, clean_name(player_name), "player", Vector3(humans.size() * 1.5, 0.05, 26), false, COLORS[humans.size() % 4])
	if phase != "barracks":
		actor.alive = false
		actor.health = 0
		actor.collision_layer = 0
	event("crowd", actor.position, actor.title + " joined the arena.")
	# The next 20 Hz update sends a complete snapshot to the newly registered peer.

func _disconnected(id: int) -> void:
	if authority and actors.has(id):
		event("", Vector3.ZERO, actors[id].title + " left the arena.")
		remove_actor(id)

func leave_session(message: String = "") -> void:
	running = false
	sound.stop_all()
	connection_wait = 0
	if networked and multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	networked = false
	authority = true
	phase = "menu"
	for id in actors.keys():
		remove_actor(id)
	for id in items.keys():
		remove_item(id)
	spectator_cooldowns.clear()
	pending_snapshots.clear()
	last_snapshot_sequence = -1
	ui.menu.show()
	ui.hud.hide()
	ui.pause_panel.hide()
	ui.status.text = message
	menu_open = false
	camera_initialized = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _show_game() -> void:
	ui.menu.hide()
	ui.hud.show()
	ui.pause_panel.hide()
	menu_open = false
	first_person = true
	mouse_weapon_target = Melee.REST
	camera_initialized = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle_menu() -> void:
	menu_open = not menu_open
	if not menu_open and actors.has(local_id()):
		# Resume from the visible hand pose instead of manufacturing a swing while
		# the cursor was released for the menu.
		mouse_weapon_target = actors[local_id()].weapon_angle
	ui.pause_panel.visible = menu_open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu_open else Input.MOUSE_MODE_CAPTURED

func spawn_actor(id: int, actor_name: String, type: String, pos: Vector3, is_bot: bool, color: Color):
	var actor = Actor.new()
	actor.name = "Gladiator_" + str(id).replace("-", "bot")
	actor.game = self
	actor.uid = id
	actor.title = actor_name
	actor.archetype = type
	actor.bot = is_bot
	actor.tint = color
	actor.position = pos
	if type == "spearman":
		actor.held = "spear"
		actor.shield = false
	elif type == "heavy":
		actor.held = "hammer"
		actor.shield = false
	elif type == "boar":
		actor.held = ""
		actor.shield = false
	add_child(actor)
	actors[id] = actor
	actor.reset_physics_interpolation()
	return actor

func remove_actor(id: int) -> void:
	if not actors.has(id):
		return
	var actor = actors[id]
	actors.erase(id)
	remove_child(actor)
	actor.queue_free()

func spawn_item(kind: String, pos: Vector3, velocity: Vector3 = Vector3.ZERO, owner_id: int = 0):
	var item = Equipment.new()
	item.game = self
	item.uid = next_item_id
	next_item_id += 1
	item.kind = kind
	item.position = pos
	item.thrower = owner_id
	item.flight_time = 3.0 if owner_id != 0 else 0.0
	add_child(item)
	item.linear_velocity = velocity
	if velocity.length() > 0.1:
		item.look_at(pos + velocity, Vector3.UP)
	else:
		item.rotation.y = randf() * TAU
	items[item.uid] = item
	return item

func remove_item(id: int) -> void:
	if items.has(id):
		var item = items[id]
		items.erase(id)
		remove_child(item)
		item.queue_free()

func human_actors(living_only: bool = false) -> Array:
	var result = []
	for actor in actors.values():
		if not actor.bot and (actor.alive or not living_only):
			result.append(actor)
	return result

func enemies_left() -> int:
	var count = 0
	for actor in actors.values():
		if actor.bot and actor.alive:
			count += 1
	return count

func enter_barracks() -> void:
	phase = "barracks"
	phase_elapsed = 0
	elapsed = 0
	remaining = 45
	pit_open = false
	pit_warned = false
	beast_released = false
	champion_released = false
	wave = 0
	crowd_clock = 0
	wave_pause = 0
	for id in actors.keys():
		if actors[id].bot:
			remove_actor(id)
	for id in items.keys():
		remove_item(id)
	var index = 0
	for actor in human_actors():
		actor.position = Vector3(-2.25 + index * 1.5, 0.05, 26)
		actor.velocity = Vector3.ZERO
		actor.impulse = Vector3.ZERO
		actor.move_velocity = Vector3.ZERO
		actor.health = 100
		actor.stamina = 100
		actor.exhausted = false
		actor.stamina_delay = 0
		actor.guard_broken = 0
		actor.kick_time = 0
		actor.dodge_time = 0
		actor.dodge_cooldown = 0
		actor.alive = true
		actor.held = "sword"
		actor.shield = true
		actor.helmet_on = true
		actor.knockdown = 0
		actor.attack_time = 0
		actor.grabber = 0
		actor.dragging = 0
		actor.collision_layer = 2
		actor.collision_mask = 1 | 2
		actor.input_yaw = 0
		actor.input_pitch = 0
		actor.guard_raise = 0
		actor.guard_pitch = 0
		actor.shield_body.collision_layer = 0
		actor.reset_weapon()
		actor.reset_physics_interpolation()
		index += 1
	var kinds = ["sword", "spear", "hammer", "shield"]
	for n in range(4):
		for copy in range(2):
			spawn_item(kinds[n], Vector3(-4.9 + copy * 1.4, 0.8, 21.2 + n * 2.0))
	for pos in [Vector3(-12, 0.7, -8), Vector3(13, 0.7, 9), Vector3(-9, 0.7, 9)]:
		spawn_item("jar", pos)
	for kind in kinds:
		spawn_item(kind, Vector3(randf_range(-13, -8), 0.6, randf_range(-12, -5)))
	if round_number > 1:
		announce("BACK TO THE BARRACKS", "Everyone returns. Fresh equipment. Same questionable judgment.")

func begin_round() -> void:
	if not authority or phase != "barracks":
		return
	first_barracks = false
	phase = "entry"
	phase_elapsed = 0
	remaining = 6
	announce("THE GATES ARE OPEN", "Enter the arena. " + MODES[mode] + " begins in six seconds.")
	event("horn", Vector3.ZERO, "")

func start_fight() -> void:
	phase = "fight"
	phase_elapsed = 0
	elapsed = 0
	remaining = 180
	var index = 0
	for actor in human_actors():
		if actor.position.z > 15:
			actor.position = Vector3(-4.5 + index * 3, 0.1, 12.5)
			actor.reset_weapon()
			actor.reset_physics_interpolation()
		actor.health = 100
		actor.grabber = 0
		actor.dragging = 0
		index += 1
	if mode == 0:
		if human_actors().size() == 1:
			spawn_enemy("basic", Vector3(-9, 0.1, -10))
			spawn_enemy("spearman", Vector3(9, 0.1, -10))
			spawn_enemy("heavy", Vector3(0, 0.1, -12))
	elif mode == 2:
		spawn_enemy("champion", Vector3(0, 0.1, -12))
	else:
		spawn_wave()
	announce("GIVE THEM A SHOW", objective_text())

func spawn_enemy(type: String, pos: Vector3):
	var names = {"basic": "Arena Guard", "spearman": "Spearman", "heavy": "The Mallet", "champion": "THE RENT COLLECTOR", "boar": "UNPAID INTERN"}
	var enemy = spawn_actor(next_bot_id, names[type], type, pos, true, Color("b5523c") if type != "champion" else Color("695881"))
	next_bot_id -= 1
	return enemy

func spawn_wave() -> void:
	wave += 1
	var count = mini(2 + human_actors(true).size() + wave - 1, 8)
	for i in range(count):
		var types = ["basic", "spearman", "heavy"]
		spawn_enemy(types[i % mini(wave + 1, 3)], Vector3(-11 + (i % 5) * 5.3, 0.1, -12 + int(i / 5) * 3))
	announce("WAVE %d" % wave, "Friendly fire is on. Try to remember who your friends are.")

func finish_round(text: String, winners: Array = []) -> void:
	if phase == "result":
		return
	phase = "result"
	phase_elapsed = 0
	remaining = 8
	for actor in winners:
		actor.wins += 1
		actor.favor += 10
	announce(text, "Returning to the barracks in eight seconds.", 7.5)
	event("horn", Vector3.ZERO, "")

func _physics_process(delta: float) -> void:
	if not running:
		return
	if not test_no_input:
		collect_input(delta)
	if authority:
		phase_elapsed += delta
		for actor in actors.values():
			if actor.bot and actor.alive and phase in ["fight", "betrayal"]:
				think(actor, delta)
			actor.server_tick(delta)
		for actor in actors.values():
			actor.finish_melee_tick(delta)
		advance_round(delta)
		snapshot_clock += delta
		if networked and snapshot_clock >= 0.05:
			snapshot_clock = 0
			if multiplayer.get_peers().size() > 0:
				broadcast_snapshot()

func advance_round(delta: float) -> void:
	if phase == "barracks":
		if not first_barracks:
			remaining = maxf(0, 45 - phase_elapsed)
			if remaining <= 0:
				begin_round()
	elif phase == "entry":
		remaining = maxf(0, 6 - phase_elapsed)
		if remaining <= 0:
			start_fight()
	elif phase == "result":
		remaining = maxf(0, 8 - phase_elapsed)
		if remaining <= 0:
			round_number += 1
			enter_barracks()
	elif phase in ["fight", "betrayal"]:
		elapsed += delta
		remaining -= delta
		if elapsed >= 18 and not pit_warned:
			pit_warned = true
			announce("WATCH YOUR STEP", "The central trapdoor opens in three seconds.")
		if elapsed >= 21 and not pit_open:
			pit_open = true
			event("horn", Vector3.ZERO, "The pit is open.")
		if elapsed >= 38 and not beast_released and phase == "fight":
			beast_released = true
			spawn_enemy("boar", Vector3(0, 0.1, -15.5))
			announce("RELEASE THE INTERN", "The boar is not on anybody's team.")
		check_hazards()
		crowd_clock += delta
		if crowd_clock >= 22:
			crowd_clock = 0
			crowd_gift()
		var survivors = human_actors(true)
		if mode == 0 or phase == "betrayal":
			var contenders = []
			for actor in actors.values():
				if actor.alive and actor.archetype != "boar":
					contenders.append(actor)
			if contenders.size() <= 1:
				finish_round(contenders[0].title.to_upper() + " TAKES THE LAUREL" if contenders.size() == 1 else "NOBODY SURVIVED", contenders)
		elif survivors.is_empty():
			finish_round("THE HOUSE WINS")
		elif enemies_left() == 0:
			if mode == 1 and wave < 3:
				wave_pause += delta
				if wave_pause >= 3:
					wave_pause = 0
					spawn_wave()
			elif mode == 3 and not champion_released:
				champion_released = true
				spawn_enemy("champion", Vector3(0, 0.1, -12))
				announce("ONE LAST OBSTACLE", "The Rent Collector has entered the arena.")
			elif mode == 3 and survivors.size() > 1:
				phase = "betrayal"
				remaining = 120
				announce("THE CROWD DEMANDS A SINGLE CHAMPION", "Your friends are now the opposition.", 5)
			else:
				finish_round("THE UNLUCKY FEW SURVIVE", survivors)
		if remaining <= 0 and phase != "result":
			finish_round("TIME'S UP. THE CROWD BOOS.")

func nearest_opponent(actor, max_distance: float = 1000.0):
	var best = null
	var distance = max_distance
	for other in actors.values():
		if other == actor or not other.alive:
			continue
		if actor.bot and mode != 0 and actor.archetype != "boar" and other.bot and other.archetype != "boar":
			continue
		var d = actor.position.distance_to(other.position)
		if d < distance:
			best = other
			distance = d
	return best

func think(actor, _delta: float) -> void:
	var target = nearest_opponent(actor)
	actor.input_age = 0
	actor.input_block = false
	if target == null:
		actor.input_move = Vector2.ZERO
		actor.input_attack = false
		return
	var offset = target.position - actor.position
	offset.y = 0
	var distance = offset.length()
	var direction = offset.normalized()
	if actor.archetype != "boar" or actor.attack_time <= 0:
		var turn = wrapf(atan2(-direction.x, -direction.z) - actor.input_yaw, -PI, PI)
		actor.input_yaw += clampf(turn, -_delta * 3.5, _delta * 3.5)
	var reach = 2.65 if actor.held == "spear" else 1.55
	var destination = target.position
	# Route around the square pit rather than walking directly through it.
	if pit_open:
		var crossing = Geometry2D.segment_intersects_segment(Vector2(actor.position.x, actor.position.z), Vector2(target.position.x, target.position.z), Vector2(-5.2, -5.2), Vector2(5.2, 5.2))
		var near_pit = absf(actor.position.x) < 5.7 and absf(actor.position.z) < 5.7
		if crossing != null or near_pit:
			var side_x = -1 if actor.position.x < 0 else 1
			var side_z = -1 if target.position.z < 0 else 1
			destination = Vector3(side_x * 6.4, 0, side_z * 6.4)
	var steering = (destination - actor.position)
	steering.y = 0
	steering = steering.normalized()
	if distance < reach:
		steering = Vector3.ZERO
		if actor.archetype != "boar":
			actor.drive_ai_weapon(target, _delta)
	elif actor.archetype != "boar":
		actor.input_attack = false
		actor.bot_swing_clock = 0
	if actor.held == "spear" and distance < 1.6:
		steering = -direction * 0.65
	if actor.archetype == "boar" and distance < 7:
		actor.request_action("attack")
	actor.drive_ai_defense(target, _delta)
	if actor.archetype == "champion" and target.blocking and distance < 1.9:
		actor.request_action("kick")
	# Separation keeps groups readable and prevents every NPC occupying one point.
	for other in actors.values():
		if other == actor or not other.alive:
			continue
		var away = actor.position - other.position
		away.y = 0
		if away.length() < 1.2 and away.length() > 0.05:
			steering += away.normalized() * 0.65
	actor.input_move = Vector2(steering.x, steering.z).limit_length(1)
	if actor.held == "" and actor.archetype != "boar" and actor.pickup_cooldown <= 0:
		actor.request_action("pickup")

func closest_item(actor, radius: float = 2.4):
	var best = null
	var distance = radius
	for item in items.values():
		var d = actor.position.distance_to(item.position)
		if d < distance and item.flight_time <= 0:
			distance = d
			best = item
	return best

func pickup(actor) -> void:
	var item = closest_item(actor)
	if item == null:
		return
	var kind = item.kind
	if kind == "food":
		actor.health = minf(100, actor.health + 30)
	elif kind == "helmet" and not actor.helmet_on:
		actor.helmet_on = true
		event("pickup", actor.position, actor.title + " jams the helmet back on.")
	elif kind == "shield":
		if actor.shield:
			return
		actor.shield = true
	else:
		if actor.held != "":
			drop_equipment(actor, false, false)
		actor.held = kind
	remove_item(item.uid)
	event("pickup", actor.position, "")

func drop_equipment(actor, throwing: bool, offhand: bool) -> void:
	var kind = "shield" if offhand and actor.shield else actor.held if not offhand else ""
	if kind == "":
		return
	if offhand:
		actor.shield = false
	else:
		actor.held = ""
	var direction = actor.forward()
	if throwing:
		direction = Vector3(0, sin(actor.input_pitch), -cos(actor.input_pitch)).rotated(Vector3.UP, actor.rotation.y)
	var speed = 18.0 if kind != "hammer" else 13.0
	var velocity = direction * (speed if throwing else 2.0) + Vector3.UP * (3.5 if throwing else 1.0)
	spawn_item(kind, actor.position + Vector3(0, 1.25, 0) + actor.forward() * 0.95, velocity, actor.uid if throwing else 0)
	if throwing:
		event("throw", actor.position, "")

func toggle_grab(actor) -> void:
	if actor.dragging != 0:
		if actors.has(actor.dragging):
			actors[actor.dragging].grabber = 0
		actor.dragging = 0
		return
	for other in actors.values():
		if other != actor and (not other.alive or other.knockdown > 0) and other.grabber == 0 and actor.position.distance_to(other.position) < 2.4:
			actor.dragging = other.uid
			other.grabber = actor.uid
			return

func blocking_shield(from: Vector3, to: Vector3, ignored_id: int):
	var earliest = 2.0
	var guard = null
	for actor in actors.values():
		if actor.uid == ignored_id:
			continue
		var t = actor.shield_intersection(from, to)
		if t >= 0 and t < earliest:
			earliest = t
			guard = actor
	return guard

func resolve_strike(attacker, kick: bool) -> void:
	# Kicks keep a short body-range query. Weapons exclusively use swept geometry.
	if not kick:
		return
	var closest = null
	var best_distance = 1.9
	var origin = attacker.position + Vector3(0, 1.2, 0)
	for target in actors.values():
		if target == attacker or not target.alive:
			continue
		var offset = target.position - attacker.position
		if absf(offset.y) > 1.8:
			continue
		offset.y = 0
		var distance = offset.length()
		if distance < best_distance and attacker.forward().dot(offset.normalized()) > 0.40:
			closest = target
			best_distance = distance
	if closest == null:
		event("throw", origin, "")
		return
	var end = closest.position + Vector3(0, 1.2, 0)
	var wall_query = PhysicsRayQueryParameters3D.create(origin, end, 1)
	if not get_world_3d().direct_space_state.intersect_ray(wall_query).is_empty():
		return
	closest.take_hit(5, attacker.forward() * 9.5 + Vector3.UP * 3.4, attacker.uid, "kick")

func resolve_weapon_contact(attacker, hit: Dictionary) -> void:
	var collider = hit.collider
	if not is_instance_valid(collider):
		return
	var speed = hit.speed
	var has_intent = attacker.committed_swing() and speed >= 2.8
	if collider.has_meta("guard_id"):
		var guard = actors.get(collider.get_meta("guard_id"))
		if guard and has_intent and attacker.weapon_contact_cooldown <= 0:
			guard.favor += 1
			guard.absorb_block(speed, Melee.properties(attacker.held).mass)
			guard.impulse += attacker.forward() * minf(4.0, Melee.properties(attacker.held).mass * speed * 0.12)
			event("block", hit.point, "")
			attacker.weapon_contact_cooldown = 0.20
			attacker.register_swing_contact(1.35)
		return
	if collider is CharacterBody3D:
		if not has_intent or not hit.edge or attacker.weapon_hit_cooldowns.has(collider.uid):
			return
		var direction = hit.velocity.normalized()
		var stabbing = attacker.stab_time > 0
		var force = Melee.impact_force(attacker.held, speed) * (0.48 if stabbing else 1.0)
		var height = collider.to_local(hit.point).y
		var damage = Melee.stab_damage(attacker.held, speed, height) if stabbing else Melee.impact_damage(attacker.held, speed, height)
		if height >= 1.60:
			damage = collider.protect_head_hit(damage, direction)
		attacker.weapon_hit_cooldowns[collider.uid] = 0.5
		attacker.weapon_travel = 0
		if not stabbing:
			attacker.register_swing_contact(1.0)
		attacker.weapon_contacts += 1
		var health_before = collider.health
		collider.take_hit(damage, direction * force + Vector3.UP * force * 0.22, attacker.uid, "swing")
		if height >= 1.60 and collider.health < health_before and phase in ["fight", "betrayal"]:
			attacker.favor += 3
			event("crowd", hit.point, "BONK! " + collider.title + " felt that one.")
	elif collider is RigidBody3D:
		if speed > 1 and has_intent:
			collider.apply_impulse(hit.velocity.normalized() * minf(9, speed * Melee.properties(attacker.held).mass * 0.35), hit.point - collider.global_position)
			attacker.register_swing_contact(0.85)
	elif speed > 1.5 and attacker.weapon_contact_cooldown <= 0:
		event("block", hit.point, "")
		attacker.weapon_contact_cooldown = 0.20
		if has_intent: attacker.register_swing_contact(1.15)

func sweep_projectile(item, from: Vector3, to: Vector3) -> void:
	if item.flight_time <= 0 or from.distance_to(to) < 0.001:
		return
	var excluded: Array[RID] = [item.get_rid()]
	if item.age < 0.35 and actors.has(item.thrower):
		excluded.append(actors[item.thrower].get_rid())
		excluded.append(actors[item.thrower].shield_body.get_rid())
	# Use the same physical shield as melee. The nearest body or shield wins;
	# a low or rearward shield cannot protect a body already struck in front of it.
	var contact = Melee.contact(get_world_3d().direct_space_state, from, to, 0.12, excluded, 2 | 8)
	if contact.is_empty() or not is_instance_valid(contact.collider):
		return
	var collider = contact.collider
	item.flight_time = 0
	if collider.has_meta("guard_id"):
		var guard = actors.get(collider.get_meta("guard_id"))
		if guard:
			guard.absorb_block(item.linear_velocity.length(), Melee.properties(item.kind).mass)
			item.linear_velocity = contact.normal * 4 + Vector3.UP * 2
			guard.favor += 3
			event("block", contact.point, "")
	elif collider is CharacterBody3D:
		var owner_id = item.thrower
		var push = item.linear_velocity.normalized() * (9.0 if item.kind == "hammer" else 4.0)
		if item.kind == "food":
			collider.health = minf(100, collider.health + 25)
			remove_item(item.uid)
		else:
			collider.take_hit(5 if item.kind == "trash" else 25, push + Vector3.UP, owner_id, "throw")
			item.linear_velocity *= -0.15
		if actors.has(owner_id):
			actors[owner_id].favor += 4

func actor_died(actor, attacker_id: int, reason: String) -> void:
	drop_equipment(actor, false, false)
	drop_equipment(actor, false, true)
	if actors.has(attacker_id) and attacker_id != actor.uid:
		actors[attacker_id].favor += 18 if reason == "pit" else 8
	event("death", actor.position, actor.title + (" found the pointy end." if reason == "pit" else " has left the mortal roster."))

func check_hazards() -> void:
	var ends = arena.beam_ends()
	for actor in actors.values():
		if not actor.alive or actor.hazard_cooldown > 0:
			continue
		var p = actor.position + Vector3.UP * 0.8
		var nearest = Geometry3D.get_closest_point_to_segment(p, ends[0], ends[1])
		if p.distance_to(nearest) < 0.70:
			actor.hazard_cooldown = 1.4
			var outward = (actor.position - arena.sweeper.position).normalized()
			actor.take_hit(20, outward * 10 + Vector3.UP * 4, 0, "beam")

func boar_collision(boar) -> void:
	for actor in actors.values():
		if actor == boar or not actor.alive or actor.hazard_cooldown > 0:
			continue
		if actor.position.distance_to(boar.position) < 1.4:
			actor.hazard_cooldown = 1.2
			actor.take_hit(25, boar.forward() * 12 + Vector3.UP * 5, boar.uid, "boar")

func crowd_gift() -> void:
	var favorite = null
	for actor in human_actors(true):
		if favorite == null or actor.favor > favorite.favor:
			favorite = actor
	if favorite:
		var food = favorite.favor >= 8
		spawn_item("food" if food else "trash", favorite.position + Vector3(0, 6, -1))
		event("crowd", favorite.position, "The crowd sends bread!" if food else "The crowd has brought tomatoes.")

func spectator_action(id: int, action: String, requested_target: int = 0) -> void:
	if not actors.has(id) or actors[id].alive or phase not in ["fight", "betrayal"]:
		return
	if Time.get_ticks_msec() < spectator_cooldowns.get(id, 0):
		return
	var living = actors.values().filter(func(actor): return actor.alive)
	if living.is_empty():
		return
	var target = living[0]
	if actors.has(requested_target) and actors[requested_target].alive:
		target = actors[requested_target]
	if action not in ["pickup", "throw"]:
		return
	spectator_cooldowns[id] = Time.get_ticks_msec() + 6000
	if action == "pickup":
		target.favor += 3
		event("crowd", target.position, actors[id].title + " cheers from the stands.")
	elif action == "throw":
		var from = target.position + Vector3(0, 4.5, 6)
		spawn_item("trash", from, Vector3(0, -2.3, -10), id)

func collect_input(delta: float) -> void:
	var move = Vector2.ZERO
	var block = false
	var sprint = false
	var steer_weapon = false
	if not menu_open:
		var raw = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var world = Vector3(raw.x, 0, raw.y).rotated(Vector3.UP, camera_yaw)
		move = Vector2(world.x, world.z)
		block = Input.is_action_pressed("guard")
		sprint = Input.is_action_pressed("sprint")
		# A held weapon is always steered by mouse motion. LMB is reserved for stabs.
		steer_weapon = true
	if authority:
		apply_input(local_id(), move, camera_yaw, block, sprint, camera_pitch, steer_weapon, mouse_weapon_target)
	else:
		input_clock += delta
		if input_clock >= 1.0 / 30.0:
			input_clock = 0
			submit_input.rpc_id(1, move, camera_yaw, block, sprint, camera_pitch, steer_weapon, mouse_weapon_target)

func apply_input(id: int, move: Vector2, yaw: float, block: bool, sprint: bool, pitch: float = 0.0, steer_weapon: bool = false, hand: Vector2 = Melee.REST) -> void:
	if not actors.has(id) or not move.is_finite() or not is_finite(yaw) or not is_finite(pitch) or not hand.is_finite():
		return
	var actor = actors[id]
	actor.input_move = move.limit_length(1.0)
	actor.input_yaw = wrapf(yaw, -PI, PI)
	actor.input_pitch = clampf(pitch, -1.0, 0.9)
	actor.input_block = block
	actor.input_sprint = sprint
	actor.set_weapon_input(steer_weapon, hand)
	actor.input_age = 0

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func submit_input(move: Vector2, yaw: float, block: bool, sprint: bool, pitch: float = 0.0, steer_weapon: bool = false, hand: Vector2 = Melee.REST) -> void:
	if authority:
		apply_input(multiplayer.get_remote_sender_id(), move, yaw, block, sprint, pitch, steer_weapon, hand)

@rpc("any_peer", "call_remote", "reliable", 0)
func submit_action(action: String, requested_target: int = 0) -> void:
	if not authority:
		return
	act(multiplayer.get_remote_sender_id(), action, requested_target)

func act(id: int, action: String, requested_target: int = 0) -> void:
	if not actors.has(id):
		return
	if not actors[id].alive:
		spectator_action(id, action, requested_target)
	else:
		actors[id].request_action(action)

func _unhandled_input(input: InputEvent) -> void:
	if not running:
		return
	if input is InputEventKey and input.pressed and not input.echo and input.physical_keycode == KEY_ESCAPE:
		toggle_menu()
		get_viewport().set_input_as_handled()
		return
	if menu_open:
		return
	if input is InputEventKey and input.pressed and not input.echo and input.physical_keycode == KEY_C:
		toggle_perspective()
		get_viewport().set_input_as_handled()
		return
	if input is InputEventMouseButton and input.pressed and input.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom_camera(-1.0 if input.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0)
		get_viewport().set_input_as_handled()
		return
	if input is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		steer_mouse(input.relative)
	var action = ""
	if input is InputEventMouseButton and input.button_index == MOUSE_BUTTON_LEFT:
		action = weapon_button(input.pressed)
	if input is InputEventKey and input.pressed and not input.echo:
		var controls = {KEY_SPACE: "jump", KEY_CTRL: "dodge", KEY_F: "kick", KEY_E: "pickup", KEY_Q: "drop", KEY_R: "throw", KEY_V: "throw_shield", KEY_T: "taunt", KEY_G: "grab"}
		action = controls.get(input.physical_keycode, "")
		if input.physical_keycode == KEY_ENTER and authority:
			begin_round()
		if input.physical_keycode in [KEY_1, KEY_2, KEY_3, KEY_4] and authority and phase == "barracks":
			mode = input.physical_keycode - KEY_1
		if input.physical_keycode in [KEY_LEFT, KEY_RIGHT]:
			cycle_spectator(1 if input.physical_keycode == KEY_RIGHT else -1)
	if action != "":
		if authority:
			act(local_id(), action, spectating_id)
		else:
			submit_action.rpc_id(1, action, spectating_id)

func toggle_perspective() -> void:
	var actor = actors.get(local_id())
	if not is_instance_valid(actor) or not actor.alive: return
	first_person = not first_person
	camera_distance = third_person_zoom
	ui.toast("FIRST PERSON  ·  C to switch" if first_person else "THIRD PERSON  ·  Scroll to zoom  ·  C to switch")

func zoom_camera(steps: float) -> void:
	var actor = actors.get(local_id())
	if first_person or not is_instance_valid(actor) or not actor.alive: return
	third_person_zoom = clampf(third_person_zoom + steps * 0.65, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)

func weapon_button(pressed: bool) -> String:
	# Pressing LMB performs exactly one stab. Holding or releasing it has no
	# bearing on mouse-driven swings.
	return "stab" if pressed else ""

func steer_mouse(motion: Vector2) -> void:
	# The same motion freely turns the camera and steers the held weapon. Damage
	# still requires a committed stroke, so ordinary aim corrections cannot chip.
	camera_yaw -= motion.x * 0.003 * sensitivity
	camera_pitch = clampf(camera_pitch - motion.y * 0.003 * sensitivity, -1.0, 0.9)
	var drag = motion * swing_sensitivity
	mouse_weapon_target -= drag * 0.010
	# A mostly vertical pull naturally crosses the front of the body; a lateral
	# pull levels the hand. Diagonal drags keep both axes under direct control.
	if absf(drag.y) > absf(drag.x) * 1.5:
		mouse_weapon_target.x = move_toward(mouse_weapon_target.x, 0.24, absf(drag.y) * 0.010)
	elif absf(drag.x) > absf(drag.y) * 1.5:
		mouse_weapon_target.y = move_toward(mouse_weapon_target.y, 0.02, absf(drag.x) * 0.009)
	mouse_weapon_target = Melee.angle_limit(mouse_weapon_target)

func cycle_spectator(direction: int) -> void:
	var list = []
	for actor in actors.values():
		if actor.alive:
			list.append(actor.uid)
	if not list.is_empty():
		var index = list.find(spectating_id)
		spectating_id = list[posmod(index + direction, list.size())]

func snapshot() -> Dictionary:
	var a = []
	var i = []
	for actor in actors.values(): a.append(actor.serialize())
	for item in items.values(): i.append(item.serialize())
	return {"actors": a, "items": i, "phase": phase, "mode": mode, "round": round_number, "elapsed": elapsed, "remaining": remaining, "wave": wave, "pit": pit_open, "beast": beast_released}

func broadcast_snapshot() -> void:
	# Keep every ENet datagram below its MTU. An incomplete snapshot is simply skipped;
	# the next complete one is sufficient because snapshots contain all entities.
	snapshot_sequence += 1
	var payload = var_to_bytes(snapshot()).compress(FileAccess.COMPRESSION_DEFLATE)
	var count = ceili(float(payload.size()) / 900.0)
	for index in range(count):
		receive_snapshot_chunk.rpc(snapshot_sequence, index, count, payload.slice(index * 900, (index + 1) * 900))

@rpc("authority", "call_remote", "unreliable", 2)
func receive_snapshot_chunk(sequence: int, index: int, count: int, payload: PackedByteArray) -> void:
	if authority or sequence <= last_snapshot_sequence or count < 1 or count > 64 or index < 0 or index >= count or payload.size() > 900:
		return
	if not pending_snapshots.has(sequence):
		pending_snapshots[sequence] = {}
	pending_snapshots[sequence][index] = payload
	if pending_snapshots[sequence].size() == count:
		var assembled = PackedByteArray()
		for part in range(count):
			if not pending_snapshots[sequence].has(part):
				return
			assembled.append_array(pending_snapshots[sequence][part])
		var decoded = assembled.decompress_dynamic(262144, FileAccess.COMPRESSION_DEFLATE)
		var data = bytes_to_var(decoded)
		if data is Dictionary and data.has("actors") and data.has("items"):
			last_snapshot_sequence = sequence
			receive_snapshot(data)
	for key in pending_snapshots.keys():
		if key <= last_snapshot_sequence or key < sequence - 3:
			pending_snapshots.erase(key)

func receive_snapshot(data: Dictionary) -> void:
	if authority:
		return
	if not running:
		running = true
		_show_game()
	phase = data.phase
	mode = data.mode
	round_number = data.round
	elapsed = data.elapsed
	remaining = data.remaining
	wave = data.wave
	pit_open = data.pit
	beast_released = data.beast
	var actor_ids = []
	for row in data.actors:
		var id = int(row.id)
		actor_ids.append(id)
		if not actors.has(id):
			spawn_actor(id, row.n, row.a, row.p, row.b, row.c)
		actors[id].receive(row)
	for id in actors.keys():
		if id not in actor_ids:
			remove_actor(id)
	var item_ids = []
	for row in data.items:
		var id = int(row.id)
		item_ids.append(id)
		if not items.has(id):
			var item = Equipment.new()
			item.game = self
			item.uid = id
			item.kind = row.k
			item.position = row.p
			add_child(item)
			items[id] = item
		items[id].receive(row)
	for id in items.keys():
		if id not in item_ids:
			remove_item(id)

func announce(text: String, sub: String = "", duration: float = 3.5) -> void:
	show_announcement(text, sub, duration)
	if networked and multiplayer.get_peers().size() > 0:
		show_announcement.rpc(text, sub, duration)

@rpc("authority", "call_remote", "reliable", 0)
func show_announcement(text: String, sub: String, duration: float) -> void:
	ui.announce(text, sub, duration)

func event(cue: String, pos: Vector3, text: String) -> void:
	show_event(cue, pos, text)
	if networked and multiplayer.get_peers().size() > 0:
		show_event.rpc(cue, pos, text)

@rpc("authority", "call_remote", "reliable", 0)
func show_event(cue: String, pos: Vector3, text: String) -> void:
	sound.play(cue)
	ui.toast(text)
	if cue in ["hit", "block"]:
		for n in range(5):
			var spark = V.box(self, Vector3.ONE * randf_range(0.035, 0.09), pos, Color("ffe3a0") if cue == "block" else Color("ba543b"))
			spark.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			effect_nodes.append({"node": spark, "v": Vector3(randf_range(-3, 3), randf_range(1, 4), randf_range(-3, 3)), "life": 0.35})

func _process(delta: float) -> void:
	demo_clock += delta
	if connection_wait > 0:
		connection_wait -= delta
		if connection_wait <= 0:
			leave_session("Connection timed out. Check the IP, firewall, and UDP 27840.")
	arena.update_state(pit_open, phase == "entry", beast_released, elapsed, delta)
	update_camera(delta)
	for index in range(effect_nodes.size() - 1, -1, -1):
		var effect = effect_nodes[index]
		effect.life -= delta
		effect.node.position += effect.v * delta
		effect.v.y -= delta * 12
		if effect.life <= 0:
			effect.node.queue_free()
			effect_nodes.remove_at(index)

func update_camera(delta: float) -> void:
	var actor = actors.get(local_id()) if running else null
	var eye_view = first_person and is_instance_valid(actor) and actor.alive and actor.knockdown <= 0
	if is_instance_valid(camera_subject) and camera_subject != actor:
		camera_subject.set_first_person_view(false)
	camera_subject = actor
	if is_instance_valid(actor): actor.set_first_person_view(eye_view)
	camera.near = 0.04 if eye_view else 0.1
	camera.fov = 86 if eye_view else 68
	if not running:
		camera.position = Vector3(sin(demo_clock * 0.025) * 4 + 21, 20, 28)
		camera.look_at(Vector3(0, 0.5, -1), Vector3.UP)
		return
	if actor == null:
		return
	if not actor.alive:
		if not actors.has(spectating_id) or not actors[spectating_id].alive:
			cycle_spectator(1)
		var target = actors.get(spectating_id)
		var focus = target.get_global_transform_interpolated().origin + Vector3.UP if target else Vector3.ZERO
		camera.position = camera.position.lerp(Vector3(0, 14, 21), minf(delta * 3, 1))
		camera.look_at(focus, Vector3.UP)
		return
	var focus = actor.get_global_transform_interpolated().origin + Vector3(0, 1.65, 0)
	if not camera_initialized:
		camera_center = focus
		camera_initialized = true
	# Follow exactly the position at which the character is rendered. A second
	# smoothing filter here makes strafing visibly wobble relative to the camera.
	camera_center = focus
	var basis_yaw = Basis(Vector3.UP, camera_yaw)
	if eye_view:
		# Stay inside the head capsule, with enough room to see the physical sword at rest.
		camera.position = actor.get_global_transform_interpolated().origin + Vector3(0, 1.85, 0) + basis_yaw * Vector3(0.08, 0, 0.16)
		camera.basis = basis_yaw * Basis(Vector3.RIGHT, camera_pitch)
		return
	camera_distance = lerpf(camera_distance, third_person_zoom, 1.0 - exp(-delta * 12.0))
	var offset = Vector3(0.55, -sin(camera_pitch) * camera_distance, cos(camera_pitch) * camera_distance)
	var desired = camera_center + basis_yaw * offset
	var query = PhysicsRayQueryParameters3D.create(camera_center, desired, 1)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		desired = hit.position + hit.normal * 0.25
	camera.position = desired
	var aim = camera_center + basis_yaw * Vector3(0.55, sin(camera_pitch) * 2.0, -2.0)
	camera.look_at(aim, Vector3.UP)

func objective_text() -> String:
	if phase == "barracks": return "Choose your equipment. Sparring here is nonlethal."
	if phase == "entry": return "Walk through the gate. Stragglers will be moved into the arena."
	if phase == "result": return "The crowd has its answer."
	if phase == "betrayal": return "ONLY ONE OF YOU MAY LEAVE."
	match mode:
		0: return "Last gladiator standing takes the laurel."
		1: return "SURVIVE TOGETHER  /  WAVE %d OF 3  /  %d ENEMIES" % [wave, enemies_left()]
		2: return "Defeat the Rent Collector. Mind the shield."
		3: return "Survive the guards and champion. Trust is temporary."
	return ""

func time_text() -> String:
	return "%d:%02d" % [int(maxf(remaining, 0)) / 60, int(maxf(remaining, 0)) % 60]

func interaction_prompt(actor) -> String:
	if not actor.alive:
		return "YOU'RE DEAD. YOU'RE STILL A PROBLEM."
	if actor.knockdown > 0:
		return "KNOCKED DOWN"
	if actor.dragging != 0:
		return "G  ·  LET GO"
	var item = closest_item(actor)
	if item:
		return "E  ·  " + ("EAT BREAD" if item.kind == "food" else "TAKE " + item.kind.to_upper())
	return ""
