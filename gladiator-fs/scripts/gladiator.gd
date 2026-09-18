extends CharacterBody3D
const V = preload("res://scripts/visuals.gd")
const Melee = preload("res://scripts/melee_physics.gd")
const GRAVITY = 22.0
var game
var uid = 1
var title = "Gladiator"
var archetype = "player"
var tint = V.TEAL
var bot = false
var health = 100.0
var alive = true
var favor = 0
var wins = 0
var held = "sword"
var shield = true
var input_move = Vector2.ZERO
var input_yaw = 0.0
var input_pitch = 0.0
var input_block = false
var input_sprint = false
var input_attack = false
var weapon_target = Melee.REST
var weapon_angle = Melee.REST
var weapon_previous_angle = Melee.REST
var weapon_velocity = Vector2.ZERO
var weapon_previous_frame = Transform3D.IDENTITY
var weapon_samples = []
var weapon_kind = "!"
var weapon_motion_age = 10.0
var weapon_travel = 0.0
var weapon_hit_cooldowns = {}
var weapon_contact_cooldown = 0.0
var weapon_contacts = 0
var shield_body: StaticBody3D
var guard_raise = 0.0
var guard_pitch = 0.0
var move_velocity = Vector3.ZERO
var bot_swing_clock = 0.0
var bot_swing_cycle = 0
var input_age = 0.0
var blocking = false
var knockdown = 0.0
var invulnerable = 0.0
var attack_time = 0.0
var attack_length = 0.65
var attack_windup = 0.2
var attack_resolved = false
var kick_time = 0.0
var dodge_time = 0.0
var dodge_cooldown = 0.0
var taunt_time = 0.0
var taunt_cooldown = 0.0
var hazard_cooldown = 0.0
var pickup_cooldown = 0.0
var last_attacker = 0
var last_hit_age = 99.0
var grabber = 0
var dragging = 0
var impulse = Vector3.ZERO
var pose: Node3D
var parts = {}
var nameplate: Label3D
var held_model: Node3D
var shield_model: Node3D
var last_equipment = "!"
var step_time = 0.0
var remote_position = Vector3.ZERO
var remote_yaw = 0.0
var remote_speed = 0.0
var remote_weapon_angle = Melee.REST
var remote_guard_raise = 0.0
var remote_guard_pitch = 0.0
var replica_initialized = false

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 2
	floor_snap_length = 0.25
	var collision = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.4 if archetype != "boar" else 0.55
	shape.height = 1.85 if archetype != "boar" else 1.3
	collision.shape = shape
	collision.position.y = shape.height / 2
	add_child(collision)
	shield_body = StaticBody3D.new()
	shield_body.collision_layer = 0
	shield_body.collision_mask = 0
	shield_body.set_meta("guard_id", uid)
	add_child(shield_body)
	var shield_collision = CollisionShape3D.new()
	var shield_shape = CylinderShape3D.new()
	shield_shape.radius = 0.62
	shield_shape.height = 0.16
	shield_collision.shape = shield_shape
	shield_collision.rotation.x = PI / 2
	shield_body.add_child(shield_collision)
	pose = Node3D.new()
	add_child(pose)
	parts = V.gladiator(pose, tint, archetype == "boar")
	nameplate = V.label(self, title, Vector3(0, 2.75, 0), 25)
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.pixel_size = 0.007
	nameplate.no_depth_test = false
	if archetype == "champion":
		pose.scale = Vector3.ONE * 1.12
	_refresh_equipment()
	reset_weapon()

func forward() -> Vector3:
	return Vector3.FORWARD.rotated(Vector3.UP, rotation.y)

func can_act() -> bool:
	return alive and knockdown <= 0 and dodge_time <= 0 and game.phase in ["barracks", "fight", "betrayal", "entry"]

func request_action(action: String) -> void:
	if not can_act():
		return
	match action:
		"attack":
			# Human melee comes only from held mouse input and swept weapon contact.
			if archetype != "boar":
				return
			if attack_time <= 0 and kick_time <= 0:
				attack_length = 1.05 if held == "hammer" else 0.62
				attack_windup = 0.42 if held == "hammer" else 0.19
				if archetype == "boar":
					attack_length = 1.5
					attack_windup = 0.65
				attack_time = attack_length
				attack_resolved = false
				blocking = false
				taunt_time = 0
		"kick":
			if kick_time <= 0 and attack_time <= 0:
				kick_time = 0.85
				game.resolve_strike(self, true)
		"jump":
			if is_on_floor():
				velocity.y = 7.2
		"dodge":
			if dodge_cooldown <= 0 and is_on_floor():
				var direction = Vector3(input_move.x, 0, input_move.y)
				if direction.length() < 0.1:
					direction = forward()
				impulse = direction.normalized() * 10.5
				dodge_time = 0.30
				dodge_cooldown = 1.2
				invulnerable = 0.16
		"taunt":
			if taunt_cooldown <= 0:
				taunt_time = 1.35
				taunt_cooldown = 8.0
				var brave = game.nearest_opponent(self, 5.0) != null
				if game.phase in ["fight", "betrayal"]:
					favor += 8 if brave else 2
				game.event("taunt", global_position, title + (" tempts fate." if brave else " waves at the cheap seats."))
		"pickup":
			if pickup_cooldown <= 0:
				pickup_cooldown = 0.3
				game.pickup(self)
		"drop": game.drop_equipment(self, false, false)
		"throw": game.drop_equipment(self, true, false)
		"throw_shield": game.drop_equipment(self, true, true)
		"grab": game.toggle_grab(self)

func server_tick(delta: float) -> void:
	if weapon_kind != held:
		reset_weapon()
	weapon_previous_angle = weapon_angle
	weapon_previous_frame = global_transform * Melee.hand_frame(weapon_angle)
	input_age += delta
	last_hit_age += delta
	weapon_motion_age += delta
	weapon_contact_cooldown = maxf(0, weapon_contact_cooldown - delta)
	for id in weapon_hit_cooldowns.keys():
		weapon_hit_cooldowns[id] -= delta
		if weapon_hit_cooldowns[id] <= 0:
			weapon_hit_cooldowns.erase(id)
	for property in ["knockdown", "invulnerable", "kick_time", "dodge_time", "dodge_cooldown", "taunt_time", "taunt_cooldown", "hazard_cooldown", "pickup_cooldown"]:
		set(property, maxf(0, get(property) - delta))
	if input_age > 0.5 and not bot:
		input_move = Vector2.ZERO
		input_block = false
		input_sprint = false
		input_attack = false
	if attack_time > 0:
		attack_time = maxf(0, attack_time - delta)
		if not attack_resolved and attack_length - attack_time >= attack_windup:
			attack_resolved = true
			if alive and knockdown <= 0:
				if archetype == "boar":
					impulse = forward() * 14
	if alive:
		rotation.y = input_yaw
	blocking = can_act() and input_block and shield and kick_time <= 0 and taunt_time <= 0
	guard_raise = move_toward(guard_raise, 1.0 if blocking else 0.0, delta * 7.5)
	guard_pitch = lerpf(guard_pitch, input_pitch, 1.0 - exp(-delta * 20.0))
	var hand_target = weapon_target if input_attack and can_act() else Melee.REST
	if bot and bot_swing_clock > 0 and not input_attack:
		hand_target = weapon_target
	var hand = Melee.integrate(weapon_angle, weapon_velocity, hand_target, held, delta)
	weapon_angle = hand[0]
	weapon_velocity = hand[1]
	if input_attack:
		weapon_travel += weapon_angle.distance_to(weapon_previous_angle)
	else:
		weapon_travel = 0.0
	var direction = Vector3(input_move.x, 0, input_move.y).limit_length(1)
	var weight_factor = Melee.movement_factor(held, shield)
	var speed = (8.8 if input_sprint else 6.5) * weight_factor
	if bot:
		speed = (5.2 if archetype != "champion" else 6.4) * weight_factor
	if blocking:
		speed *= 0.65
	if input_attack:
		speed *= 0.90
	if not alive or knockdown > 0 or taunt_time > 0 or dodge_time > 0 or game.phase == "result":
		direction = Vector3.ZERO
	if archetype == "boar" and attack_time > 0 and not attack_resolved:
		direction = Vector3.ZERO
	var acceleration = (34.0 if direction.length() < 0.1 else 28.0) * weight_factor
	move_velocity = move_velocity.move_toward(direction * speed, acceleration * delta)
	velocity.x = move_velocity.x + impulse.x
	velocity.z = move_velocity.z + impulse.z
	if grabber != 0:
		var carrier = game.actors.get(grabber)
		if alive and knockdown <= 0:
			if is_instance_valid(carrier):
				carrier.dragging = 0
			grabber = 0
		elif is_instance_valid(carrier) and carrier.alive and global_position.distance_to(carrier.global_position) < 4.0:
			var destination = carrier.global_position - carrier.forward() * 1.25
			var drag = (destination - global_position) * 7
			velocity.x = drag.x
			velocity.z = drag.z
		else:
			if is_instance_valid(carrier):
				carrier.dragging = 0
			grabber = 0
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0:
		velocity.y = -0.5
	move_and_slide()
	shield_body.transform = Melee.shield_frame(guard_pitch, guard_raise)
	shield_body.collision_layer = 8 if blocking and guard_raise >= 0.65 else 0
	impulse = impulse.move_toward(Vector3.ZERO, delta * (11 if is_on_floor() else 2.5))
	if global_position.y < -1.6 and alive:
		take_hit(1000, Vector3.ZERO, last_attacker if last_hit_age < 6 else 0, "pit")
	if archetype == "boar" and impulse.length() > 5 and alive:
		game.boar_collision(self)

func reset_weapon() -> void:
	weapon_kind = held
	weapon_samples = Melee.samples(held)
	weapon_angle = Melee.REST
	weapon_target = Melee.REST
	weapon_previous_angle = weapon_angle
	weapon_velocity = Vector2.ZERO
	weapon_motion_age = 10.0
	weapon_travel = 0.0
	weapon_hit_cooldowns.clear()
	input_attack = false
	weapon_previous_frame = global_transform * Melee.hand_frame(weapon_angle)

func finish_melee_tick(delta: float) -> void:
	if not can_act() or not input_attack or archetype == "boar":
		return
	var current = global_transform * Melee.hand_frame(weapon_angle)
	var hit = Melee.sweep(self, weapon_previous_frame, current, delta)
	if hit.is_empty():
		return
	game.resolve_weapon_contact(self, hit)
	# Contact stops the hand at the obstruction and absorbs/rebounds its momentum.
	var safe_fraction = maxf(0, hit.fraction - 0.04)
	var attempted_travel = weapon_previous_angle.distance_to(weapon_angle)
	weapon_angle = weapon_previous_angle.lerp(weapon_angle, safe_fraction)
	weapon_travel = maxf(0, weapon_travel - attempted_travel * (1.0 - safe_fraction))
	weapon_velocity *= -0.12

func drive_ai_weapon(target, delta: float) -> void:
	bot_swing_clock -= delta
	if bot_swing_clock <= 0:
		bot_swing_cycle += 1
		bot_swing_clock = 1.55 + Melee.properties(held).inertia * 0.16
	var overhead = bot_swing_cycle % 3 == 0
	var side = 1.0 if bot_swing_cycle % 2 == 0 else -1.0
	var length = 1.55 + Melee.properties(held).inertia * 0.16
	var elapsed_swing = length - bot_swing_clock
	var windup = 0.45 + Melee.properties(held).inertia * 0.08
	if elapsed_swing < windup:
		input_attack = false
		weapon_target = Vector2(0, 1.18) if overhead else Vector2(side * 1.10, 0.20)
	elif elapsed_swing < windup + 0.55 + Melee.properties(held).inertia * 0.08:
		input_attack = true
		weapon_motion_age = 0.0
		weapon_target = Vector2(0, -0.5) if overhead else Vector2(-side * 1.10, 0.02)
	else:
		input_attack = false
		weapon_target = Melee.REST
	input_block = shield and not input_attack and target.input_attack
	input_pitch = 0.35 if target.weapon_angle.y > 0.7 else 0.0

func take_hit(amount: float, push: Vector3, attacker: int, reason: String = "hit") -> void:
	if not alive or (invulnerable > 0 and reason != "pit"):
		return
	if game.phase in ["result", "menu"]:
		return
	if game.phase in ["barracks", "entry"]:
		amount = 0
	health = maxf(0, health - amount)
	last_attacker = attacker
	last_hit_age = 0
	impulse += Vector3(push.x, 0, push.z)
	velocity.y = maxf(velocity.y, push.y)
	if push.length() > 8.0:
		knockdown = 1.35
		attack_time = 0
		blocking = false
		input_attack = false
		weapon_velocity = Vector2.ZERO
		if held != "" and reason != "pit":
			game.drop_equipment(self, false, false)
	if health <= 0:
		alive = false
		blocking = false
		input_attack = false
		shield_body.collision_layer = 0
		attack_time = 0
		collision_layer = 0
		collision_mask = 1
		game.actor_died(self, attacker, reason)
	else:
		game.event("hit", global_position + Vector3.UP, "")

func shield_intersection(from: Vector3, to: Vector3) -> float:
	# A finite shield plane intercepts strikes/projectiles, including ones aimed at allies.
	if not alive or not blocking or not shield or guard_raise < 0.65:
		return -1
	var frame = global_transform * Melee.shield_frame(guard_pitch, guard_raise)
	var normal = -frame.basis.z
	var center = frame.origin
	var direction = to - from
	var denominator = normal.dot(direction)
	if denominator >= -0.001:
		return -1
	var t = normal.dot(center - from) / denominator
	if t < 0 or t > 1:
		return -1
	var offset = frame.affine_inverse() * (from + direction * t)
	if Vector2(offset.x, offset.y).length() <= 0.65:
		return t
	return -1

func _physics_process(delta: float) -> void:
	if not game.authority:
		global_position = global_position.lerp(remote_position, 1.0 - exp(-delta * 18.0))
		rotation.y = lerp_angle(rotation.y, remote_yaw, 1.0 - exp(-delta * 20.0))
		weapon_angle = weapon_angle.lerp(remote_weapon_angle, 1.0 - exp(-delta * 24.0))
		guard_raise = lerpf(guard_raise, remote_guard_raise, 1.0 - exp(-delta * 24.0))
		guard_pitch = lerpf(guard_pitch, remote_guard_pitch, 1.0 - exp(-delta * 24.0))
	_refresh_equipment()
	var moving = Vector2(velocity.x, velocity.z).length() if game.authority else remote_speed
	step_time += delta * moving * 2.1
	var down = not alive or knockdown > 0
	pose.rotation.z = lerp_angle(pose.rotation.z, 1.45 if down else 0.0, minf(12 * delta, 1))
	pose.position.y = lerpf(pose.position.y, 0.35 if down else 0.0, minf(12 * delta, 1))
	nameplate.text = title + ("  ·  DOWN" if knockdown > 0 and alive else "")
	nameplate.modulate = tint.lightened(0.45) if alive else Color("a99c89")
	if parts.is_empty():
		pose.rotation.x = -0.15 if attack_time > 0 and not attack_resolved else 0
		return
	parts.legs[0].rotation.x = sin(step_time) * minf(moving * 0.12, 0.65) if not down else 0
	parts.legs[1].rotation.x = -parts.legs[0].rotation.x
	var hand = Melee.hand_frame(weapon_angle)
	var guard = Melee.shield_frame(guard_pitch, guard_raise)
	var reach = hand.origin - parts.right_arm.position
	parts.right_arm.basis = Basis.looking_at(reach.normalized()) * Basis(Vector3.RIGHT, PI / 2)
	var left_reach = guard.origin - parts.left_arm.position
	parts.left_arm.basis = Basis.looking_at(left_reach.normalized()) * Basis(Vector3.RIGHT, PI / 2)
	if kick_time > 0.5:
		parts.legs[1].rotation.x = -1.25
	if taunt_time > 0:
		parts.left_arm.rotation.z = 2.5
		parts.right_arm.rotation.z = -2.5
	if held_model:
		held_model.transform = hand
	if shield_model:
		shield_model.transform = guard

func _refresh_equipment() -> void:
	var key = held + str(shield)
	if key == last_equipment or parts.is_empty():
		return
	last_equipment = key
	if is_instance_valid(held_model):
		held_model.queue_free()
		held_model = null
	if is_instance_valid(shield_model):
		shield_model.queue_free()
		shield_model = null
	if held != "":
		held_model = V.weapon(held)
		pose.add_child(held_model)
	if shield:
		shield_model = V.weapon("shield")
		pose.add_child(shield_model)

func serialize() -> Dictionary:
	return {"id": uid, "n": title, "a": archetype, "c": tint, "b": bot, "p": global_position, "r": rotation.y, "v": Vector2(velocity.x, velocity.z).length(), "h": health, "alive": alive, "held": held, "shield": shield, "block": blocking, "down": knockdown, "atk": attack_time, "len": attack_length, "kick": kick_time, "taunt": taunt_time, "favor": favor, "wins": wins, "drag": dragging, "hand": weapon_angle, "grip": input_attack, "guard": guard_raise, "pitch": guard_pitch}

func receive(data: Dictionary) -> void:
	remote_position = data.p
	remote_yaw = data.r
	remote_speed = data.v
	health = data.h
	alive = data.alive
	held = data.held
	shield = data.shield
	blocking = data.block
	knockdown = data.down
	attack_time = data.atk
	attack_length = data.len
	kick_time = data.kick
	taunt_time = data.taunt
	favor = data.favor
	wins = data.wins
	dragging = data.drag
	remote_weapon_angle = data.hand
	remote_guard_raise = data.guard
	remote_guard_pitch = data.pitch
	input_attack = data.grip
	collision_layer = 0
	collision_mask = 0
	if not replica_initialized or global_position.distance_to(remote_position) > 7:
		global_position = remote_position
		rotation.y = remote_yaw
		weapon_angle = remote_weapon_angle
		guard_raise = remote_guard_raise
		guard_pitch = remote_guard_pitch
		reset_physics_interpolation()
		replica_initialized = true
