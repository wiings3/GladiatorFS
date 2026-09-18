extends SceneTree
## Run: godot --headless --path gladiator-fs --script res://tests/gameplay_test.gd
var game
var failures = []
var checks = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ", description)
	else:
		print("PASS: ", description)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func reset_actor(actor, pos: Vector3, yaw: float) -> void:
	actor.position = pos
	actor.rotation.y = yaw
	actor.input_yaw = yaw
	actor.velocity = Vector3.ZERO
	actor.impulse = Vector3.ZERO
	actor.knockdown = 0
	actor.invulnerable = 0
	actor.health = 100
	actor.alive = true
	actor.blocking = false
	actor.input_block = false
	actor.attack_time = 0
	actor.kick_time = 0
	actor.collision_layer = 2
	actor.collision_mask = 3

func kill_bots() -> void:
	for actor in game.actors.values():
		if actor.bot:
			actor.alive = false

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	game.test_no_input = true
	game.start_session(false, "Tester", 1)
	await frames(12)
	check(game.phase == "barracks" and game.items.size() >= 12, "Practice starts in stocked barracks")
	var player = game.actors[1]
	var start_z = player.position.z
	for i in range(45):
		game.apply_input(1, Vector2(0, -1), 0, false, false)
		await physics_frame
	check(player.position.z < start_z - 2.5, "WASD input moves the character on the floor")
	game.set_physics_process(false)
	var target = game.spawn_actor(2, "Friend", "player", Vector3(0, 0.05, 8), false, Color.CORAL)
	reset_actor(player, Vector3(0, 0.05, 10), 0)
	game.resolve_strike(player, false)
	check(target.health == 100, "Barracks sparring is nonlethal")
	game.phase = "fight"
	player.held = "sword"
	reset_actor(target, Vector3(0, 0.05, 8), PI)
	target.blocking = true
	game.resolve_strike(player, false)
	check(target.health == 100, "Frontal shield intercepts a sword strike")
	target.rotation.y = 0
	game.resolve_strike(player, false)
	check(target.health == 75, "A shield does not protect the back")
	reset_actor(target, Vector3(0, 0.05, 6.5), PI)
	game.resolve_strike(player, false)
	check(target.health == 100, "Sword cannot hit outside its reach")
	player.held = "spear"
	game.resolve_strike(player, false)
	check(target.health == 75, "Spear reaches a distant target without weapon modifiers")
	reset_actor(target, Vector3(0, 0.05, 8.5), PI)
	target.held = "sword"
	game.resolve_strike(player, true)
	check(target.knockdown > 0 and target.held == "" and target.health == 95, "Kick knocks down and disarms")
	reset_actor(target, Vector3(0, 0.05, 8), PI)
	target.invulnerable = 0.1
	game.resolve_strike(player, false)
	check(target.health == 100, "Dodge invulnerability rejects a hit")
	reset_actor(target, Vector3(0, 0.05, 6), PI)
	player.held = "sword"
	game.drop_equipment(player, true, false)
	await frames(26)
	check(player.held == "" and target.health == 75, "Thrown weapon hits through host physics and leaves the hand")
	check(game.items.values().any(func(item): return item.kind == "sword" and item.thrower == 1 and item.flight_time <= 0), "Thrown weapon remains recoverable after impact")
	player.held = ""
	var pickup = game.spawn_item("hammer", player.position + Vector3(0.1, 0.5, 0.1))
	var pickup_id = pickup.uid
	game.pickup(player)
	check(player.held == "hammer" and not game.items.has(pickup_id), "Picking up equipment transfers it from the world")
	reset_actor(target, Vector3(0, 0.05, 8), PI)
	target.take_hit(200, Vector3.ZERO, 1, "throw")
	check(not target.alive and game.actors.has(2), "Death keeps the player in the session as a spectator")
	var old_favor = player.favor
	game.spectator_action(2, "pickup")
	game.spectator_action(2, "pickup")
	check(player.favor == old_favor + 3, "Spectator cheering works and obeys its cooldown")
	game.enter_barracks()
	check(target.alive and target.health == 100 and player.health == 100, "Between rounds revives and heals every connected player")
	game.mode = 1
	game.begin_round()
	game.phase_elapsed = 6.1
	game.advance_round(0.01)
	check(game.phase == "fight" and game.wave == 1 and game.enemies_left() > 0, "Gates lead into co-op survival")
	game.elapsed = 21
	game.advance_round(0.01)
	await frames(2)
	check(game.pit_open and game.arena.trap_shape.disabled, "Trapdoor warning culminates in an open physical pit")
	game.elapsed = 38
	game.advance_round(0.01)
	check(game.beast_released and game.actors.values().any(func(a): return a.archetype == "boar"), "Animal gate releases a charging boar")
	for i in range(3):
		kill_bots()
		game.advance_round(3.1)
	check(game.phase == "result", "Survival ends after all three waves")
	game.enter_barracks()
	game.mode = 2
	game.start_fight()
	check(game.actors.values().any(func(a): return a.archetype == "champion" and a.alive), "Champion mode spawns the boss")
	kill_bots()
	game.advance_round(0.01)
	check(game.phase == "result", "Champion defeat ends the event")
	game.enter_barracks()
	game.mode = 3
	game.start_fight()
	kill_bots()
	game.advance_round(0.01)
	check(game.champion_released, "Last Champion follows guards with the champion")
	kill_bots()
	game.advance_round(0.01)
	check(game.phase == "betrayal", "Last Champion turns surviving friends against each other")
	target.take_hit(200, Vector3.ZERO, 1, "hit")
	game.advance_round(0.01)
	check(game.phase == "result" and player.wins > 0, "Last survivor wins the betrayal")
	game.remove_actor(2)
	game.enter_barracks()
	game.mode = 0
	game.start_fight()
	check(game.enemies_left() == 3, "Solo Free-for-All supplies three opponents")
	kill_bots()
	game.advance_round(0.01)
	check(game.phase == "result", "Free-for-All recognizes the final survivor")
	var data = game.snapshot()
	check(data.actors.size() == game.actors.size() and data.items.size() == game.items.size(), "Snapshot contains the complete live session")
	game.leave_session()
	await frames(3)
	check(game.actors.is_empty() and game.items.is_empty() and not game.running, "Leaving cleans up the session")
	print("GAMEPLAY CHECKS: ", checks, "  FAILURES: ", failures.size())
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
