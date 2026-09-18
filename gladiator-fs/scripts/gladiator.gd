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
var stamina = 100.0
var stamina_delay = 0.0
var exhausted = false
var sprinting = false
var guard_broken = 0.0
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
var swing_origin = Melee.REST
var swing_start_angle = Melee.REST
var swing_direction = Vector2.ZERO
var swing_spent = false
var weapon_extension = 0.0
var weapon_previous_extension = 0.0
var heavy_windup = 0.0
var heavy_release = 0.0
var heavy_recovery = 0.0
var heavy_goal = Melee.REST
var heavy_prepare = Melee.REST
var stab_time = 0.0
var stab_landed = false
var stab_limit = 0.72
var stab_aim = Vector2.ZERO
var kick_resolved = false
var shield_body: StaticBody3D
var guard_raise = 0.0
var guard_pitch = 0.0
var move_velocity = Vector3.ZERO
var bot_swing_clock = 0.0
var bot_swing_cycle = 0
var bot_threat_time = 0.0
var bot_guard_time = 0.0
var bot_guard_cooldown = 0.0
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
var remote_extension = 0.0
var replica_initialized = false

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 2
	floor_snap_length = 0.25
	var collision = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.4 if archetype != "boar" else 0.55
	shape.height = 2.10 if archetype != "boar" else 1.3
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

func set_first_person_view(enabled: bool) -> void:
	# Local rendering only: avoid self-occlusion without changing combat geometry.
	if parts.has("head"):
		parts.head.visible = not enabled
		parts.torso.visible = not enabled
	nameplate.visible = not enabled

func can_act() -> bool:
	return alive and knockdown <= 0 and dodge_time <= 0 and game.phase in ["barracks", "fight", "betrayal", "entry"]

func request_action(action: String) -> void:
	if not can_act():
		return
	match action:
		"stab":
			if stab_time <= 0 and kick_time <= 0 and heavy_windup <= 0 and heavy_release <= 0 and heavy_recovery <= 0:
				stab_time = stab_windup() + 0.12 + 0.22
				stab_aim = Vector2(0.23, input_pitch * 0.85)
				stab_landed = false
				stab_limit = 0.72
				weapon_hit_cooldowns.clear()
				swing_spent = true
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
			if kick_time <= 0 and attack_time <= 0 and stamina >= 10 and not exhausted:
				kick_time = 0.55
				kick_resolved = false
				consume_stamina(10)
		"jump":
			if is_on_floor():
				velocity.y = 7.2
		"dodge":
			if dodge_cooldown <= 0 and is_on_floor() and stamina >= 24 and not exhausted:
				consume_stamina(24)
				var direction = Vector3(input_move.x, 0, input_move.y)
				if direction.length() < 0.1:
					direction = forward()
				impulse = direction.normalized() * 10.5
				dodge_time = 0.30
				dodge_cooldown = 0.65
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
	weapon_previous_extension = weapon_extension
	weapon_previous_frame = global_transform * Melee.hand_frame(weapon_angle, weapon_extension)
	input_age += delta
	last_hit_age += delta
	weapon_motion_age += delta
	weapon_contact_cooldown = maxf(0, weapon_contact_cooldown - delta)
	for id in weapon_hit_cooldowns.keys():
		weapon_hit_cooldowns[id] -= delta
		if weapon_hit_cooldowns[id] <= 0:
			weapon_hit_cooldowns.erase(id)
	for property in ["knockdown", "invulnerable", "kick_time", "dodge_time", "dodge_cooldown", "taunt_time", "taunt_cooldown", "hazard_cooldown", "pickup_cooldown", "guard_broken", "stamina_delay", "heavy_recovery"]:
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
	if kick_time > 0 and kick_time <= 0.43 and not kick_resolved:
		kick_resolved = true
		if can_act(): game.resolve_strike(self, true)
	blocking = can_act() and input_block and shield and kick_time <= 0 and taunt_time <= 0 and guard_broken <= 0 and not exhausted
	sprinting = can_act() and input_sprint and input_move.length() > 0.1 and not blocking and not exhausted and taunt_time <= 0
	if blocking:
		consume_stamina(8.0 * delta)
		if exhausted: break_guard()
	elif sprinting:
		consume_stamina(18.0 * delta)
		sprinting = not exhausted
	elif stamina_delay <= 0 and alive:
		stamina = minf(100, stamina + 30.0 * delta)
	if exhausted and stamina >= 25: exhausted = false
	guard_raise = move_toward(guard_raise, 1.0 if blocking else 0.0, delta * 7.5)
	guard_pitch = lerpf(guard_pitch, input_pitch, 1.0 - exp(-delta * 20.0))
	update_hand(delta)
	var direction = Vector3(input_move.x, 0, input_move.y).limit_length(1)
	var weight_factor = Melee.movement_factor(held, shield)
	var speed = (10.0 if sprinting else 7.0) * weight_factor
	if bot:
		speed = (5.2 if archetype != "champion" else 6.4) * weight_factor
	if blocking:
		speed *= 0.85
	if not alive or knockdown > 0 or taunt_time > 0 or dodge_time > 0 or game.phase == "result":
		direction = Vector3.ZERO
	if archetype == "boar" and attack_time > 0 and not attack_resolved:
		direction = Vector3.ZERO
	var acceleration = (45.0 if direction.length() < 0.1 else 38.0) * weight_factor
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

func consume_stamina(amount: float) -> void:
	stamina = maxf(0, stamina - amount)
	stamina_delay = 0.55
	if stamina <= 0: exhausted = true

func break_guard() -> void:
	guard_broken = 0.9
	blocking = false
	shield_body.collision_layer = 0
	game.event("block", global_position + Vector3.UP, title + ": noodle arms!")

func absorb_block(speed: float, mass: float) -> void:
	consume_stamina(clampf(10.0 + speed * mass * 0.38, 12, 45))
	if exhausted: break_guard()

func set_weapon_input(grip: bool, aim: Vector2) -> void:
	var bounded = Melee.angle_limit(aim)
	var previous = weapon_target if input_attack else weapon_angle
	if grip and not input_attack:
		swing_origin = weapon_angle
		swing_start_angle = weapon_angle
		swing_direction = Vector2.ZERO
		swing_spent = false
		weapon_travel = 0
	var motion = bounded - previous
	if grip and motion.length() > 0.004:
		if swing_direction != Vector2.ZERO and motion.normalized().dot(swing_direction) < -0.3:
			# A reversal starts a new stroke; little wiggles never add up to a full swing.
			swing_origin = previous
			swing_start_angle = weapon_angle
			swing_spent = false
			swing_direction = motion.normalized()
		elif swing_direction == Vector2.ZERO:
			swing_direction = motion.normalized()
		weapon_travel = bounded.distance_to(swing_origin)
		weapon_motion_age = 0
	input_attack = grip
	weapon_target = bounded

func stab_windup() -> float:
	return 0.40 if held == "hammer" else 0.09

func stab_active() -> bool:
	return stab_time > 0.22 and stab_time <= 0.34 and not stab_landed

func committed_swing() -> bool:
	if stab_time > 0: return stab_active()
	if swing_spent or heavy_windup > 0 or heavy_recovery > 0: return false
	if held == "hammer" and heavy_release <= 0: return false
	return (input_attack or heavy_release > 0) and weapon_motion_age < 0.6 and weapon_travel >= 0.52 and weapon_angle.distance_to(swing_start_angle) >= 0.32 and weapon_velocity.length() >= 2.7

func update_hand(delta: float) -> void:
	if not can_act() or kick_time > 0 or taunt_time > 0:
		stab_time = 0
		heavy_windup = 0
		heavy_release = 0
		weapon_extension = move_toward(weapon_extension, 0, delta * 8)
		var idle = Melee.integrate(weapon_angle, weapon_velocity, Melee.REST, held, delta)
		weapon_angle = idle[0]
		weapon_velocity = idle[1]
		return
	var hand_target = weapon_target if input_attack else Melee.REST
	var release = false
	weapon_extension = 0
	if stab_time > 0:
		stab_time = maxf(0, stab_time - delta)
		var elapsed = stab_windup() + 0.34 - stab_time
		hand_target = stab_aim
		if elapsed < stab_windup():
			weapon_extension = lerpf(0, -0.28, elapsed / stab_windup())
		elif stab_time > 0.22:
			weapon_extension = lerpf(-0.28, 0.72, (elapsed - stab_windup()) / 0.12)
		else:
			weapon_extension = 0.72 * (stab_time / 0.22)
		weapon_extension = minf(weapon_extension, stab_limit)
	elif held == "hammer":
		if heavy_windup > 0:
			heavy_windup = maxf(0, heavy_windup - delta)
			heavy_goal = weapon_target if input_attack else heavy_goal
			hand_target = heavy_prepare
			if heavy_windup <= 0:
				heavy_release = 0.30
				swing_start_angle = weapon_angle
				swing_spent = false
		elif heavy_release > 0:
			heavy_release = maxf(0, heavy_release - delta)
			hand_target = heavy_goal
			release = true
			weapon_motion_age = 0
			if heavy_release <= 0:
				heavy_recovery = 0.22
				swing_spent = true
		elif input_attack and not swing_spent and heavy_recovery <= 0 and weapon_motion_age < 0.22 and weapon_travel >= 0.52:
			heavy_windup = 0.40
			heavy_goal = weapon_target
			heavy_prepare = Melee.angle_limit(weapon_angle - (weapon_target - weapon_angle).normalized() * 0.65)
			hand_target = heavy_prepare
	elif bot and bot_swing_clock > 0 and not input_attack:
		hand_target = weapon_target
	var hand = Melee.integrate(weapon_angle, weapon_velocity, hand_target, "sword" if stab_time > 0 else held, delta, release)
	weapon_angle = hand[0]
	weapon_velocity = hand[1]

func reset_weapon() -> void:
	weapon_kind = held
	weapon_samples = Melee.samples(held)
	weapon_angle = Melee.REST
	weapon_target = Melee.REST
	weapon_previous_angle = weapon_angle
	weapon_velocity = Vector2.ZERO
	weapon_motion_age = 10.0
	weapon_travel = 0.0
	swing_origin = Melee.REST
	swing_start_angle = Melee.REST
	swing_direction = Vector2.ZERO
	swing_spent = false
	weapon_extension = 0
	weapon_previous_extension = 0
	heavy_windup = 0
	heavy_release = 0
	heavy_recovery = 0
	stab_time = 0
	stab_landed = false
	weapon_hit_cooldowns.clear()
	input_attack = false
	weapon_previous_frame = global_transform * Melee.hand_frame(weapon_angle)

func finish_melee_tick(delta: float) -> void:
	if not can_act() or kick_time > 0 or taunt_time > 0 or archetype == "boar":
		return
	if not input_attack and heavy_release <= 0 and stab_time <= 0:
		return
	if stab_time > 0 and not stab_active():
		return
	var current = global_transform * Melee.hand_frame(weapon_angle, weapon_extension)
	var hit = Melee.sweep(self, weapon_previous_frame, current, delta)
	if hit.is_empty():
		return
	game.resolve_weapon_contact(self, hit)
	# Contact stops the hand at the obstruction and absorbs/rebounds its momentum.
	var safe_fraction = maxf(0, hit.fraction - 0.04)
	weapon_angle = weapon_previous_angle.lerp(weapon_angle, safe_fraction)
	weapon_extension = lerpf(weapon_previous_extension, weapon_extension, safe_fraction)
	if stab_time > 0:
		stab_limit = weapon_extension
		stab_landed = true
	weapon_velocity *= -0.12

func drive_ai_weapon(_target, delta: float) -> void:
	bot_swing_clock -= delta
	if bot_swing_clock <= 0:
		bot_swing_cycle += 1
		bot_swing_clock = 1.8 if held == "hammer" else 1.25
	var overhead = bot_swing_cycle % 3 == 0
	var side = 1.0 if bot_swing_cycle % 2 == 0 else -1.0
	var length = 1.8 if held == "hammer" else 1.25
	var elapsed_swing = length - bot_swing_clock
	var windup = 0.24
	if elapsed_swing < windup:
		set_weapon_input(false, Vector2(0, 1.18) if overhead else Vector2(side * 1.10, 0.20))
	elif elapsed_swing < windup + (0.95 if held == "hammer" else 0.38):
		set_weapon_input(true, Vector2(0, -0.5) if overhead else Vector2(-side * 1.10, 0.02))
	else:
		set_weapon_input(false, Melee.REST)

func drive_ai_defense(target, delta: float) -> void:
	bot_guard_time = maxf(0, bot_guard_time - delta)
	bot_guard_cooldown = maxf(0, bot_guard_cooldown - delta)
	var toward = (target.global_position - global_position).normalized()
	var visible_attack = target.committed_swing() or target.heavy_windup > 0 or target.stab_active()
	if visible_attack and global_position.distance_to(target.global_position) < 3.5 and forward().dot(toward) > 0.3:
		bot_threat_time += delta
	else:
		bot_threat_time = 0
	# React to visible motion, then leave a generous opening. Holding LMB is not a threat.
	var reaction = 0.20 + posmod(uid, 3) * 0.06
	if bot_threat_time >= reaction and bot_guard_cooldown <= 0 and stamina >= 20:
		bot_guard_time = 0.38
		bot_guard_cooldown = 1.35
		input_pitch = clampf(target.weapon_angle.y * 0.5, -0.35, 0.55)
	input_block = shield and bot_guard_time > 0 and not committed_swing() and heavy_windup <= 0

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
		shield_body.collision_layer = 0
		input_attack = false
		stab_time = 0
		heavy_windup = 0
		heavy_release = 0
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
		weapon_extension = lerpf(weapon_extension, remote_extension, 1.0 - exp(-delta * 32.0))
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
	var hand = Melee.hand_frame(weapon_angle, weapon_extension)
	var guard = Melee.shield_frame(guard_pitch, guard_raise)
	var reach = hand.origin - parts.right_arm.position
	parts.right_arm.basis = Basis.looking_at(reach.normalized()) * Basis(Vector3.RIGHT, PI / 2)
	parts.right_arm.scale.y = clampf(reach.length() / 0.40, 0.85, 2.8)
	var left_reach = guard.origin - parts.left_arm.position
	parts.left_arm.basis = Basis.looking_at(left_reach.normalized()) * Basis(Vector3.RIGHT, PI / 2)
	parts.left_arm.scale.y = clampf(left_reach.length() / 0.40, 0.85, 2.4)
	parts.legs[1].position.z = 0
	parts.legs[1].scale.y = 1
	if kick_time > 0:
		var kick = sin(clampf((0.55 - kick_time) / 0.36, 0, 1) * PI)
		# The leg extends down local -Y, so POSITIVE pitch swings the boot forward (-Z).
		parts.legs[1].rotation.x = kick * 1.4
		parts.legs[1].position.z = -kick * 0.2
		parts.legs[1].scale.y = 1.0 + kick * 0.20
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
	return {"id": uid, "n": title, "a": archetype, "c": tint, "b": bot, "p": global_position, "r": rotation.y, "v": Vector2(velocity.x, velocity.z).length(), "h": health, "alive": alive, "held": held, "shield": shield, "block": blocking, "down": knockdown, "atk": attack_time, "len": attack_length, "kick": kick_time, "taunt": taunt_time, "favor": favor, "wins": wins, "drag": dragging, "hand": weapon_angle, "grip": input_attack, "guard": guard_raise, "pitch": guard_pitch, "stamina": stamina, "exhausted": exhausted, "guard_broken": guard_broken, "extension": weapon_extension, "stab": stab_time}

func receive(data: Dictionary) -> void:
	remote_position = data.p
	remote_yaw = data.r
	remote_speed = data.v
	health = data.h
	stamina = data.stamina
	exhausted = data.exhausted
	guard_broken = data.guard_broken
	stab_time = data.stab
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
	remote_extension = data.extension
	input_attack = data.grip
	collision_layer = 0
	collision_mask = 0
	if not replica_initialized or global_position.distance_to(remote_position) > 7:
		global_position = remote_position
		rotation.y = remote_yaw
		weapon_angle = remote_weapon_angle
		guard_raise = remote_guard_raise
		guard_pitch = remote_guard_pitch
		weapon_extension = remote_extension
		reset_physics_interpolation()
		replica_initialized = true
