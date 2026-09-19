extends SceneTree
var game
var failures = []
var checks = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS CAMERA: ", description)
	else:
		failures.append(description)
		printerr("FAIL CAMERA: ", description)

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func key(code: Key, echo: bool = false) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	game._unhandled_input(event)

func wheel(button: MouseButton) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	game._unhandled_input(event)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_no_input = true
	game.start_session(false, "Camera test", 0)
	game.set_physics_process(false)
	game.set_process(false)
	var player = game.actors[1]
	player.position = Vector3(0, 0.05, 7)
	player.reset_physics_interpolation()
	var other = game.spawn_actor(2, "Friend", "player", Vector3(3, 0.05, 7), false, Color.CORAL)
	game.camera_yaw = 0
	game.camera_pitch = 0
	await frames(3)
	game.update_camera(1.0 / 60)
	var eye = player.get_global_transform_interpolated().origin + Vector3(0.08, 1.85, 0.16)
	check(game.first_person and game.camera.position.distance_to(eye) < 0.001, "New sessions start at eye level in first person")
	check(not player.parts.head.visible and not player.parts.torso.visible and not player.nameplate.visible and other.parts.head.visible and other.parts.torso.visible, "Only the local player's head, torso and nameplate are hidden")
	check(player.parts.right_arm.is_visible_in_tree() and player.held_model.is_visible_in_tree() and player.shield_model.is_visible_in_tree(), "First person keeps the real arms, weapon and shield visible")
	wheel(MOUSE_BUTTON_WHEEL_UP)
	check(is_equal_approx(game.third_person_zoom, 5.2), "Wheel input in first person preserves the saved third-person zoom")
	key(KEY_C)
	game.update_camera(1.0 / 60)
	check(not game.first_person and game.camera.position.z > player.position.z + 4 and player.parts.head.visible, "C switches to third person and restores the full character")
	wheel(MOUSE_BUTTON_WHEEL_UP)
	var wanted = game.third_person_zoom
	game.update_camera(1.0 / 60)
	check(wanted < 5.2 and game.camera_distance > wanted and game.camera_distance < 5.2, "Wheel up zooms closer with a smooth transition")
	wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check(is_equal_approx(game.third_person_zoom, 5.2), "Wheel down zooms back out")
	for i in range(30): wheel(MOUSE_BUTTON_WHEEL_UP)
	check(game.third_person_zoom == game.CAMERA_ZOOM_MIN, "Near zoom stops before entering the character")
	for i in range(30): wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check(game.third_person_zoom == game.CAMERA_ZOOM_MAX, "Far zoom has a fixed limit")
	var wall = game.V.solid(game, Vector3(5, 5, 0.3), Vector3(0, 2, 10), Color.GRAY)
	await frames(2)
	for i in range(90): game.update_camera(1.0 / 60)
	check(game.camera.position.z < 9.85 and game.camera.position.z > 9, "A wall pulls the third-person camera forward instead of letting zoom pass through")
	wall.queue_free()
	await frames(2)
	key(KEY_C)
	game.update_camera(1.0 / 60)
	check(game.first_person and game.camera.position.distance_to(eye) < 0.001, "C switches to an eye-level first-person camera")
	key(KEY_C, true)
	check(game.first_person, "Holding C does not repeatedly toggle the view")
	wheel(MOUSE_BUTTON_WHEEL_UP)
	check(game.third_person_zoom == game.CAMERA_ZOOM_MAX, "Wheel input in first person preserves the saved third-person zoom")
	var hand_before = game.mouse_weapon_target
	game.steer_mouse(Vector2(40, -20))
	game.update_camera(1.0 / 60)
	var direction = -game.camera.basis.z
	check(direction.x > 0 and direction.y > 0 and game.mouse_weapon_target.distance_to(hand_before) > 0.2, "First-person mouse motion aims the camera and weapon without LMB")
	key(KEY_C)
	game.update_camera(1.0 / 60)
	check(not game.first_person and player.parts.head.visible and player.parts.torso.visible and player.nameplate.visible and game.camera_distance == game.CAMERA_ZOOM_MAX, "Returning to third person restores the full character and previous zoom")
	game.toggle_menu()
	key(KEY_C)
	wheel(MOUSE_BUTTON_WHEEL_UP)
	check(not game.first_person and game.third_person_zoom == game.CAMERA_ZOOM_MAX, "Menu input cannot accidentally change view or zoom")
	game.toggle_menu()
	key(KEY_C)
	player.knockdown = 0.5
	game.update_camera(1.0 / 60)
	check(game.first_person and player.parts.head.visible and game.camera.position.distance_to(player.position) > 2, "Knockdowns briefly show the character without forgetting the selected view")
	player.knockdown = 0
	game.update_camera(1.0 / 60)
	check(not player.parts.head.visible, "Recovering returns to first person")
	player.alive = false
	game.update_camera(1.0 / 60)
	check(player.parts.head.visible and game.spectating_id == other.uid, "Death restores the local model and switches to spectator view")
	game.enter_barracks()
	await frames(2)
	game.update_camera(1.0 / 60)
	check(game.first_person and not player.parts.head.visible, "Respawning keeps the player's selected perspective")
	game.leave_session()
	game.update_camera(1.0 / 60)
	check(game.camera_subject == null, "Leaving releases the camera subject cleanly")
	print("CAMERA CHECKS: ", checks, "  FAILURES: ", failures.size())
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
