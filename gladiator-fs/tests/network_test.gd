extends SceneTree
## Launched as four separate OS processes by run_network_test.py.
var game
var role = "client"
var clock = 0.0
var stage = 0
var stage_clock = 0.0
var seen = {}
var threw = false
var death_seen = false
var dead_clock = 0.0
var failures = []
var initial_ids = []
var remote_hand_seen = false
var remote_guard_seen = false
var replicated_hand_seen = false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "host": role = "host"
	call_deferred("run")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_no_input = true
	if role == "host":
		game.start_session(true, "Host", 3)
	else:
		game.join_session("127.0.0.1", "Client")

func verify(condition: bool, description: String) -> void:
	if condition:
		print("PASS NETWORK ", role, ": ", description)
	else:
		failures.append(description)
		printerr("FAIL NETWORK ", role, ": ", description)

func end() -> void:
	print("NETWORK RESULT ", role, ": ", "PASS" if failures.is_empty() else "FAIL")
	game.leave_session()
	game.queue_free()
	quit(0 if failures.is_empty() else 1)

func _physics_process(delta: float) -> bool:
	if not is_instance_valid(game): return false
	clock += delta
	stage_clock += delta
	if clock > 27:
		verify(false, "Test exceeded its deadline")
		end()
		return false
	if game.running:
		seen[game.phase] = true
	if role == "host":
		server_steps()
	else:
		client_steps(delta)
	return false

func server_steps() -> void:
	for actor in game.human_actors():
		if actor.uid == 1: continue
		remote_hand_seen = remote_hand_seen or (actor.input_attack and actor.weapon_angle.distance_to(Vector2(-0.70, 0.65)) > 0.25)
		remote_guard_seen = remote_guard_seen or (actor.guard_raise > 0.65 and actor.guard_pitch > 0.3)
	if stage == 0 and game.human_actors().size() == 4:
		verify(true, "Four separate processes joined one session")
		initial_ids = game.actors.keys()
		stage = 1
		stage_clock = 0
	elif stage == 1 and stage_clock > 2:
		var moved = true
		for actor in game.human_actors():
			if actor.uid != 1 and actor.position.z > 25:
				moved = false
		verify(moved, "Remote movement is simulated on the host")
		verify(remote_hand_seen, "Remote mouse gestures drive the host's physical hand")
		verify(remote_guard_seen, "Raised shield aim reaches the host")
		game.begin_round()
		stage = 2
		stage_clock = 0
	elif stage == 2 and stage_clock > 2:
		var dropped = true
		for actor in game.human_actors():
			if actor.uid != 1 and actor.held != "": dropped = false
		verify(dropped, "Reliable client throw actions reach the host")
		game.start_fight()
		stage = 3
		stage_clock = 0
	elif stage == 3 and stage_clock > 1:
		for actor in game.actors.values():
			if actor.bot: actor.alive = false
		stage = 4
		stage_clock = 0
	elif stage == 4 and stage_clock > 1:
		for actor in game.actors.values():
			if actor.bot: actor.alive = false
		stage = 5
		stage_clock = 0
	elif stage == 5 and stage_clock > 1:
		verify(game.phase == "betrayal", "Last Champion enters PvP with remote survivors")
		var remote = game.human_actors()[1]
		remote.take_hit(200, Vector3.ZERO, 1, "test")
		stage = 6
		stage_clock = 0
	elif stage == 6 and stage_clock > 3.5:
		verify(game.human_actors().size() == 3, "A departing client is removed without ending the session")
		verify(game.actors[1].favor >= 3, "Dead remote player can cheer with a cooldown")
		end()

func client_steps(delta: float) -> void:
	if not game.running:
		if seen.has("betrayal"):
			verify(game.actors.is_empty(), "Host departure returns the client to the menu")
			end()
		return
	var me = game.actors.get(game.local_id())
	if me == null: return
	if game.phase == "barracks":
		game.submit_input.rpc_id(1, Vector2(0, -1), 0.0, true, false, 0.45, true, Vector2(sin(clock * 4), 0.02))
		replicated_hand_seen = replicated_hand_seen or (me.guard_raise > 0.65 and me.weapon_angle.distance_to(Vector2(-0.70, 0.65)) > 0.25)
	elif game.phase == "entry" and not threw:
		game.submit_input.rpc_id(1, Vector2.ZERO, 0.0, false, false)
		game.submit_action.rpc_id(1, "throw")
		threw = true
	if game.phase == "betrayal" and not death_seen:
		for actor in game.human_actors():
			if not actor.alive:
				death_seen = true
				verify(true, "Host death state replicates to clients")
				verify(seen.has("barracks") and seen.has("entry") and seen.has("fight"), "Barracks, gates, combat and betrayal all replicate")
				verify(game.items.size() >= 10, "Physical equipment replicates")
				verify(replicated_hand_seen, "Weapon arcs and aimed shield poses replicate back to the client")
	if not me.alive and death_seen:
		dead_clock += delta
		if dead_clock < 0.1:
			game.submit_action.rpc_id(1, "pickup")
		if dead_clock > 1.5:
			end()
