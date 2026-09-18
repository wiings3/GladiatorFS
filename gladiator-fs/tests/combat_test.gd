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
	for actor in [player, target]:
		actor.health = 100
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
	check(target.health == 100, "Holding left click without moving cannot deal damage")
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
	await swing(Vector2(0.16, 0.8), Vector2(0.16, -0.25), 32)
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
	check(sword_angle.x > hammer_angle.x + 0.3, "The heavy hammer accelerates and swings more slowly")
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
	game.mouse_grip = true
	game.mouse_weapon_target = Vector2.ZERO
	var yaw = game.camera_yaw
	game.steer_mouse(Vector2(-80, 0))
	check(game.mouse_weapon_target.x > 0.7 and game.camera_yaw == yaw, "Left drag controls the hand while the camera stays steady")
	game.mouse_weapon_target = Vector2(0.24, 0.8)
	game.steer_mouse(Vector2(0, 80))
	check(game.mouse_weapon_target.y < 0.01, "Downward mouse movement lowers the weapon through an overhead arc")
	game.mouse_grip = false
	var pitch = game.camera_pitch
	game.steer_mouse(Vector2(0, -50))
	check(game.camera_pitch > pitch, "Mouse look can aim a raised shield upward")
	print("COMBAT CHECKS: ", checks, "  FAILURES: ", failures.size())
	game.leave_session()
	await frames(2)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
