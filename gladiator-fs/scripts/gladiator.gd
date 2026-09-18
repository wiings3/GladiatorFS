extends CharacterBody3D
const V = preload("res://scripts/visuals.gd")
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

func forward() -> Vector3:
	return Vector3.FORWARD.rotated(Vector3.UP, rotation.y)

func can_act() -> bool:
	return alive and knockdown <= 0 and dodge_time <= 0 and game.phase in ["barracks", "fight", "betrayal", "entry"]

func request_action(action: String) -> void:
	if not can_act():
		return
	match action:
		"attack":
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
	input_age += delta
	last_hit_age += delta
	for property in ["knockdown", "invulnerable", "kick_time", "dodge_time", "dodge_cooldown", "taunt_time", "taunt_cooldown", "hazard_cooldown", "pickup_cooldown"]:
		set(property, maxf(0, get(property) - delta))
	if input_age > 0.5 and not bot:
		input_move = Vector2.ZERO
		input_block = false
		input_sprint = false
	if attack_time > 0:
		attack_time = maxf(0, attack_time - delta)
		if not attack_resolved and attack_length - attack_time >= attack_windup:
			attack_resolved = true
			if alive and knockdown <= 0:
				if archetype == "boar":
					impulse = forward() * 14
				else:
					game.resolve_strike(self, false)
	if alive:
		rotation.y = input_yaw
	blocking = can_act() and input_block and attack_time <= 0 and kick_time <= 0 and taunt_time <= 0
	var direction = Vector3(input_move.x, 0, input_move.y).limit_length(1)
	var speed = 7.5 if input_sprint else 5.3
	if bot:
		speed = 4.4 if archetype != "champion" else 5.6
	if blocking:
		speed = 2.6
	if attack_time > 0:
		speed *= 0.50
	if not alive or knockdown > 0 or taunt_time > 0 or dodge_time > 0 or game.phase == "result":
		direction = Vector3.ZERO
	if archetype == "boar" and attack_time > 0 and not attack_resolved:
		direction = Vector3.ZERO
	velocity.x = direction.x * speed + impulse.x
	velocity.z = direction.z * speed + impulse.z
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
	impulse = impulse.move_toward(Vector3.ZERO, delta * (11 if is_on_floor() else 2.5))
	if global_position.y < -1.6 and alive:
		take_hit(1000, Vector3.ZERO, last_attacker if last_hit_age < 6 else 0, "pit")
	if archetype == "boar" and impulse.length() > 5 and alive:
		game.boar_collision(self)

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
		if held != "" and reason != "pit":
			game.drop_equipment(self, false, false)
	if health <= 0:
		alive = false
		blocking = false
		attack_time = 0
		collision_layer = 0
		collision_mask = 1
		game.actor_died(self, attacker, reason)
	else:
		game.event("hit", global_position + Vector3.UP, "")

func shield_intersection(from: Vector3, to: Vector3) -> float:
	# A finite shield plane intercepts strikes/projectiles, including ones aimed at allies.
	if not alive or not blocking or not shield:
		return -1
	var normal = forward()
	var center = global_position + Vector3(0, 1.2, 0) + normal * 0.7
	var direction = to - from
	var denominator = normal.dot(direction)
	if denominator >= -0.001:
		return -1
	var t = normal.dot(center - from) / denominator
	if t < 0 or t > 1:
		return -1
	var offset = from + direction * t - center
	var side = normal.cross(Vector3.UP)
	if absf(offset.dot(side)) < 0.80 and absf(offset.y) < 0.78:
		return t
	return -1

func _process(delta: float) -> void:
	if not game.authority:
		global_position = global_position.lerp(remote_position, minf(delta * 18, 1))
		rotation.y = lerp_angle(rotation.y, remote_yaw, minf(delta * 20, 1))
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
	parts.left_arm.rotation = Vector3(-0.9 if blocking else -0.2, 0, 0)
	parts.right_arm.rotation = Vector3(-0.25, 0, 0)
	if kick_time > 0.5:
		parts.legs[1].rotation.x = -1.25
	if taunt_time > 0:
		parts.left_arm.rotation.z = 2.5
		parts.right_arm.rotation.z = -2.5
	if attack_time > 0:
		var progress = 1.0 - attack_time / attack_length
		if held == "spear":
			parts.right_arm.rotation.x = -0.25 - sin(progress * PI) * 0.7
		elif held == "hammer":
			parts.right_arm.rotation.x = -sin(progress * TAU) * 1.5
		else:
			parts.right_arm.rotation.y = lerpf(-1.4, 1.4, smoothstep(0.15, 0.7, progress))
	if held_model:
		held_model.position.z = -sin((1.0 - attack_time / attack_length) * PI) * 0.5 if attack_time > 0 and held == "spear" else 0.0
	if shield_model:
		shield_model.position = Vector3(0.18, 0.15, -0.4) if blocking else Vector3(-0.08, -0.05, 0)

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
		parts.right.add_child(held_model)
	if shield:
		shield_model = V.weapon("shield")
		parts.left.add_child(shield_model)

func serialize() -> Dictionary:
	return {"id": uid, "n": title, "a": archetype, "c": tint, "b": bot, "p": global_position, "r": rotation.y, "v": Vector2(velocity.x, velocity.z).length(), "h": health, "alive": alive, "held": held, "shield": shield, "block": blocking, "down": knockdown, "atk": attack_time, "len": attack_length, "kick": kick_time, "taunt": taunt_time, "favor": favor, "wins": wins, "drag": dragging}

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
	collision_layer = 0
	collision_mask = 0
	if not replica_initialized or global_position.distance_to(remote_position) > 7:
		global_position = remote_position
		rotation.y = remote_yaw
		replica_initialized = true
