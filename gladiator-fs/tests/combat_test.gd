extends SceneTree
const Melee = preload("res://scripts/melee_physics.gd")
var game
var player
var target
var checks = 0
var failures = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if value:
		print("PASS COMBAT: ", description)
	else:
		failures.append(description)
		printerr("FAIL COMBAT: ", description)

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func prepare(kind: String = "sword", guard: bool = false, target_yaw: float = PI, start: Vector2 = Vector2(-1.0, 0.02)) -> void:
	for id in game.items.keys(): game.remove_item(id)
	for actor in [player, target]:
		actor.health = 100
		actor.stamina = 100
		actor.stamina_delay = 0
		actor.exhausted = false
		actor.guard_broken = 0
		actor.kick_time = 0
		actor.dodge_time = 0
		actor.dodge_cooldown = 0
		actor.bot_guard_cooldown = 0
		actor.bot_guard_time = 0
		actor.bot_threat_time = 0
		actor.favor = 0
		actor.alive = true
		actor.velocity = Vector3.ZERO
		actor.move_velocity = Vector3.ZERO
		actor.impulse = Vector3.ZERO
		actor.knockdown = 0
		actor.invulnerable = 0
		actor.input_move = Vector2.ZERO
		actor.input_block = false
		actor.input_pitch = 0
		actor.guard_raise = 0
		actor.guard_pitch = 0
		actor.shield_body.collision_layer = 0
		actor.collision_layer = 2
		actor.held = kind if actor == player else "sword"
		actor.shield = guard if actor == target else false
		actor.reset_weapon()
		actor.reset_physics_interpolation()
	player.position = Vector3(0, 0.05, 10)
	player.rotation.y = 0
	player.input_yaw = 0
	target.position = Vector3(0, 0.05, 8.5)
	target.rotation.y = target_yaw
	target.input_yaw = target_yaw
	target.input_block = guard
	player.weapon_angle = start
	player.weapon_target = start
	for i in range(12):
		game.apply_input(1, Vector2.ZERO, 0, false, false, 0, true, start)
		target.input_age = 0
		player.server_tick(1.0 / 60.0)
		target.server_tick(1.0 / 60.0)
		await physics_frame
	player.weapon_travel = 0
	player.weapon_contacts = 0

func swing(from: Vector2, to: Vector2, steps: int = 22) -> void:
	for i in range(steps + 20):
		var aim = from.lerp(to, minf(float(i + 1) / steps, 1.0))
		game.apply_input(1, Vector2.ZERO, 0, false, false, 0, true, aim)
		target.input_age = 0
		player.server_tick(1.0 / 60.0)
		target.server_tick(1.0 / 60.0)
		player.finish_melee_tick(1.0 / 60.0)
		await physics_frame

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_no_input = true
	game.start_session(false, "Mouse tester", 0)
	game.set_physics_process(false)
	game.phase = "fight"
	player = game.actors[1]
	target = game.spawn_actor(2, "Contact target", "player", Vector3(0, 0.05, 8.5), false, Color.CORAL)
	for id in game.items.keys(): game.remove_item(id)
	await frames(3)
	await prepare()
	await swing(Vector2(-1, 0.02), Vector2(1, 0.02))
	check(target.health < 100, "A lateral mouse-guided blade path strikes a body")
	check(player.weapon_contacts == 1, "One pass cannot repeatedly damage the same body")
	await prepare("sword", false, PI, Vector2(0.24, 1.18))
	await swing(Vector2(0.24, 1.18), Vector2(0.24, -0.55))
	check(target.health < 100, "A downward pull produces an overhead contact")
	await prepare("sword", true)
	await swing(Vector2(-1, 0.02), Vector2(1, 0.02))
	check(target.health == 100 and target.favor > 0, "The visible raised shield physically stops the blade")
	await prepare("sword", true, 0)
	await swing(Vector2(-1, 0.02), Vector2(1, 0.02))
	check(target.health < 100, "An attack from behind bypasses a forward shield")
	await prepare("sword", true)
	var excluded: Array[RID] = [player.get_rid(), player.shield_body.get_rid()]
	for pitch in [0.85, -0.75]:
		target.input_pitch = pitch
		for i in range(30):
			target.input_age = 0
			target.server_tick(1.0 / 60.0)
			await physics_frame
		var hit = Melee.contact(game.get_world_3d().direct_space_state, Vector3(0.1, 3.1, 8.9), Vector3(0.1, 0.8, 8.9), 0.12, excluded, 2 | 8)
		var caught = not hit.is_empty() and hit.collider.has_meta("guard_id")
		check(caught if pitch > 0 else not caught, "An upward-aimed shield catches a descending blow" if pitch > 0 else "A lowered aim exposes the head to a descending blow")
	await prepare()
	var wall = game.V.solid(game, Vector3(3.5, 3, 0.2), Vector3(0, 1.5, 9), Color.GRAY)
	await frames(2)
	await swing(Vector2(-1, 0.02), Vector2(1, 0.02))
	check(target.health == 100 and player.weapon_angle.x < 0.5, "A solid wall stops the swing before it reaches a body")
	wall.queue_free()
	await frames(2)
	await prepare()
	game.phase = "barracks"
	await swing(Vector2(-1, 0.02), Vector2(1, 0.02))
	check(target.health == 100 and player.weapon_contacts == 1, "Real weapon contact is nonlethal in the barracks")
	game.phase = "fight"
	await prepare()
	game.apply_input(1, Vector2.ZERO, 0, false, false, 0, true, Vector2(-1, 0.02))
	await swing(Vector2(-1, 0.02), Vector2(-1, 0.02))
	check(target.health == 100, "Holding the weapon still cannot deal damage")
	await prepare()
	target.position.x = -3
	await swing(Vector2(-1, 0.02), Vector2(1, 0.02))
	check(target.health == 100, "A swing cannot hit a body outside the blade's path")
	await prepare("sword", false, PI, Vector2(0.24, 0))
	target.position.z = 7.3
	await swing(Vector2(0.24, 0.9), Vector2(0.24, -0.4))
	check(target.health == 100, "A short blade cannot reach the distant target")
	await prepare("spear", false, PI, Vector2(0.16, 0.8))
	target.position.z = 7.3
	await swing(Vector2(0.16, 0.8), Vector2(0.16, -0.25), 18)
	check(target.health < 100, "A spear's physical tip reaches farther")
	var sword_angle = Vector2(-1, 0)
	var hammer_angle = sword_angle
	var sword_velocity = Vector2.ZERO
	var hammer_velocity = Vector2.ZERO
	for i in range(18):
		var sword = Melee.integrate(sword_angle, sword_velocity, Vector2(1, 0), "sword", 1.0 / 60.0)
		var hammer = Melee.integrate(hammer_angle, hammer_velocity, Vector2(1, 0), "hammer", 1.0 / 60.0)
		sword_angle = sword[0]; sword_velocity = sword[1]
		hammer_angle = hammer[0]; hammer_velocity = hammer[1]
	check(sword_angle.x > hammer_angle.x + 0.3, "The sword responds quickly while the hammer resists during windup")
	check(Melee.movement_factor("hammer", true) < Melee.movement_factor("sword", true), "Heavier carried equipment reduces movement speed")
	check(Melee.movement_factor("sword", false) > Melee.movement_factor("sword", true), "Dropping the shield removes its carried weight")
	var distances = []
	for kind in ["sword", "hammer"]:
		await prepare(kind)
		player.position = Vector3(-10, 0.05, 12)
		target.position = Vector3(10, 0.05, 8)
		for i in range(60):
			game.apply_input(1, Vector2(1, 0), 0, false, false)
			player.server_tick(1.0 / 60.0)
			await physics_frame
		distances.append(player.position.x + 10)
	check(distances[0] > distances[1] + 0.7, "The heavier load actually travels less distance over the same second")
	game.mouse_weapon_target = Vector2.ZERO
	var yaw = game.camera_yaw
	game.steer_mouse(Vector2(-80, 0))
	check(game.mouse_weapon_target.x > 0.7 and game.camera_yaw > yaw, "Mouse motion swings the hand AND turns the camera without an attack button")
	player.input_attack = false
	game.collect_input(0.0)
	check(player.input_attack, "Normal gameplay continuously sends mouse weapon control without LMB")
	game.mouse_weapon_target = Vector2(0.24, 0.8)
	game.steer_mouse(Vector2(0, 80))
	check(game.mouse_weapon_target.y < 0.01, "Downward mouse movement lowers the weapon through an overhead arc")
	var pitch = game.camera_pitch
	game.steer_mouse(Vector2(0, -50))
	check(game.camera_pitch > pitch, "Mouse look can aim a raised shield upward")
	await new_combat_checks()
	print("COMBAT CHECKS: ", checks, "  FAILURES: ", failures.size())
	game.leave_session()
	await frames(2)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func tick(aim: Vector2, grip: bool = true, move: Vector2 = Vector2.ZERO, sprint: bool = false, block: bool = false) -> void:
	game.apply_input(1, move, 0, block, sprint, 0, grip, aim)
	target.input_age = 0
	player.server_tick(1.0 / 60.0)
	target.server_tick(1.0 / 60.0)
	player.finish_melee_tick(1.0 / 60.0)
	await physics_frame

func thrust() -> void:
	game.act(1, game.weapon_button(true))
	game.weapon_button(false)
	for i in range(32): await tick(Melee.REST, false)

func new_combat_checks() -> void:
	await prepare("sword", false, PI, Vector2(0.24, 0))
	for i in range(150): await tick(Vector2(0.24 + sin(i * 1.4) * 0.07, 0))
	check(target.health == 100 and player.weapon_contacts == 0, "Small repeated wiggles against a body never accumulate into damage")
	await prepare()
	await swing(Vector2(-1, 0.02), Vector2(1, 0.02), 28)
	var slower_damage = 100 - target.health
	await prepare()
	await swing(Vector2(-1, 0.02), Vector2(1, 0.02), 10)
	check(100 - target.health > slower_damage + 4, "A faster real sword contact deals more damage")
	await prepare("sword", false, PI, Vector2(-1, 0.32))
	await swing(Vector2(-1, 0.32), Vector2(1, 0.32), 16)
	var head_damage = 100 - target.health
	await prepare("sword", false, PI, Vector2(-1, -0.45))
	await swing(Vector2(-1, -0.45), Vector2(1, -0.45), 16)
	var leg_damage = 100 - target.health
	check(head_damage > leg_damage * 2 and leg_damage > 0, "Physical head contact hurts much more than the same swing at the legs")
	await prepare("sword", false, PI, Vector2(-1, 0.32))
	target.invulnerable = 2.0
	await swing(Vector2(-1, 0.32), Vector2(1, 0.32), 16)
	check(target.health == 100 and player.favor == 0, "A dodged head contact cannot award damage or head-hit favor")
	check(Melee.impact_damage("hammer", 8, 1.2) > Melee.impact_damage("sword", 8, 1.2), "More weapon mass produces a harder impact at the same speed")
	await prepare("sword", false, PI, Melee.REST)
	await thrust()
	check(target.health < 100 and player.weapon_contacts == 1, "A single tap produces one physical forward stab")
	check(player.stab_time <= 0, "The stab retracts and completes its recovery")
	await prepare("sword", true, PI, Melee.REST)
	await thrust()
	check(target.health == 100 and target.stamina < 90, "The raised shield intercepts a stab and spends stamina")
	await prepare("sword", false, PI, Melee.REST)
	target.position.x = 3
	await thrust()
	check(target.health == 100, "A stab misses a target outside its actual path")
	check(game.weapon_button(true) == "stab" and game.weapon_button(false) == "", "LMB press requests one stab and release requests nothing")
	var hand_before = game.mouse_weapon_target
	game.steer_mouse(Vector2(35, 0))
	check(game.mouse_weapon_target.distance_to(hand_before) > 0.2, "Mouse motion keeps steering the weapon without LMB")
	await prepare("hammer")
	target.position.x = 5
	var windup_speed = 0.0
	var release_speed = 0.0
	var early_angle = 0.0
	for i in range(58):
		await tick(Vector2(1, 0.02))
		if player.heavy_windup > 0: windup_speed = maxf(windup_speed, player.weapon_velocity.length())
		if player.heavy_release > 0: release_speed = maxf(release_speed, player.weapon_velocity.length())
		if i == 17: early_angle = player.weapon_angle.x
	check(early_angle < -0.9, "The hammer visibly winds back instead of instantly sweeping forward")
	check(release_speed > windup_speed * 2.5 and release_speed > 9, "The hammer releases much faster than its windup")
	await prepare("hammer")
	target.position.x = 5
	var windups = 0
	var winding = false
	var outside_release = false
	for i in range(150):
		await tick(Vector2(lerpf(-1, 1, minf((i + 1) / 60.0, 1)), 0.02))
		if player.heavy_windup > 0 and not winding: windups += 1
		winding = player.heavy_windup > 0
		outside_release = outside_release or (player.committed_swing() and player.heavy_release <= 0)
	check(windups == 1 and not outside_release, "A slower hammer gesture still winds up; holding still never auto-swings again")
	await prepare("sword", true, PI, Melee.REST)
	for i in range(45):
		target.drive_ai_defense(player, 1.0 / 60.0)
		await tick(Melee.REST)
	check(target.guard_raise < 0.1, "NPC defense does not react to an idle controlled weapon")
	await prepare("hammer", true)
	var instant_block = false
	var delayed_block = false
	for i in range(80):
		target.drive_ai_defense(player, 1.0 / 60.0)
		await tick(Vector2(1, 0.02))
		if i < 10: instant_block = instant_block or target.blocking
		if i > 18: delayed_block = delayed_block or target.blocking
	check(not instant_block and delayed_block, "NPCs react to a visible windup after a human-sized delay")
	check(not target.blocking, "NPCs lower their shield and leave an opening after a brief block")
	await prepare()
	player.request_action("kick")
	for i in range(9): await tick(Melee.REST, false)
	var boot = player.to_local(player.parts.legs[1].to_global(Vector3(0, -0.70, -0.09)))
	check(boot.z < -0.65 and target.knockdown > 0, "F kicks the visible boot forward and knocks down the opponent in front")
	await prepare()
	target.position = Vector3(0, 0.05, 11.5)
	player.request_action("kick")
	for i in range(10): await tick(Melee.REST, false)
	check(target.health == 100, "A forward kick cannot hit someone behind the player")
	await prepare()
	target.position.x = 10
	var before = player.stamina
	for i in range(25): await tick(Melee.REST, false, Vector2.ZERO, true)
	check(player.stamina == before, "Holding sprint while stationary does not waste stamina")
	for i in range(30): await tick(Melee.REST, false, Vector2(1, 0), true)
	check(player.stamina < before - 8 and player.sprinting, "Sprinting drains stamina only while moving")
	player.stamina = 0.1
	await tick(Melee.REST, false, Vector2(1, 0), true)
	check(player.exhausted and not player.sprinting, "Exhaustion ends sprinting")
	player.request_action("dodge")
	check(player.dodge_time <= 0, "An exhausted player cannot dodge")
	for i in range(110): await tick(Melee.REST, false)
	check(player.stamina >= 25 and not player.exhausted, "Stamina regenerates and clears exhaustion after a short rest")
	before = player.stamina
	player.request_action("dodge")
	check(player.dodge_time > 0 and is_equal_approx(before - player.stamina, 24), "Dodging spends stamina once")
	await prepare("sword", true)
	target.stamina = 8
	await swing(Vector2(-1, 0.02), Vector2(1, 0.02), 10)
	check(target.exhausted and not target.blocking and target.shield_body.collision_layer == 0, "An impact breaks an exhausted guard and disables shield blocking")
	await prepare()
	player.shield = true
	for i in range(30): await tick(Melee.REST, false, Vector2.ZERO, false, true)
	check(player.stamina < 97 and player.blocking, "Keeping a shield raised drains stamina")
	game.enter_barracks()
	check(player.stamina == 100 and not player.exhausted and player.stab_time == 0, "A new round restores stamina and clears attack state")
