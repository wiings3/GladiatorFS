extends Node3D
## Shared, deterministic arena geometry; gameplay hazards are evaluated by the host.
const V = preload("res://scripts/visuals.gd")
var trap: StaticBody3D
var trap_mesh: Node3D
var trap_shape: CollisionShape3D
var arena_gate: StaticBody3D
var beast_gate: Node3D
var sweeper: Node3D
var pit_open = false
var gate_open = false
var warning_ring: MeshInstance3D
var spectator_mesh: MultiMeshInstance3D

func _ready() -> void:
	_build_lighting()
	_build_floor()
	_build_stands()
	_build_barracks()
	_build_hazards()

func _build_lighting() -> void:
	var environment = WorldEnvironment.new()
	var env = Environment.new()
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("658e9d")
	sky_mat.sky_horizon_color = Color("e9d7b6")
	sky_mat.ground_bottom_color = Color("80664d")
	sky_mat.ground_horizon_color = Color("e9d7b6")
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c2d6d4")
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env
	add_child(environment)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("fff0de")
	sun.light_energy = 0.78
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 85
	add_child(sun)

func _build_floor() -> void:
	V.solid(self, Vector3(13, 0.6, 34), Vector3(-10.5, -0.3, 0), V.SAND)
	V.solid(self, Vector3(13, 0.6, 34), Vector3(10.5, -0.3, 0), V.SAND)
	V.solid(self, Vector3(8, 0.6, 13), Vector3(0, -0.3, -10.5), V.SAND)
	V.solid(self, Vector3(8, 0.6, 13), Vector3(0, -0.3, 10.5), V.SAND)
	V.solid(self, Vector3(8, 0.5, 8), Vector3(0, -3.3, 0), V.INK)
	for side in [-1, 1]:
		V.solid(self, Vector3(0.35, 3.2, 8.1), Vector3(side * 4.15, -1.6, 0), V.DARK_STONE)
		V.solid(self, Vector3(8.1, 3.2, 0.35), Vector3(0, -1.6, side * 4.15), V.DARK_STONE)
	for x in range(-3, 4):
		for z in range(-3, 4):
			V.cylinder(self, 0.16, 1.6, Vector3(x, -2.3, z), V.IRON, 0)
	var rng = RandomNumberGenerator.new()
	rng.seed = 54
	for i in range(110):
		var p = Vector3(rng.randf_range(-16, 16), 0.007, rng.randf_range(-16, 16))
		if absf(p.x) < 4.5 and absf(p.z) < 4.5:
			continue
		V.box(self, Vector3(rng.randf_range(0.1, 0.6), 0.012, rng.randf_range(0.05, 0.15)), p, V.SAND.darkened(0.10))
	for side in [-1, 1]:
		V.solid(self, Vector3(1.0, 3.2, 35), Vector3(side * 17.5, 1.6, 0), V.STONE)
		V.solid(self, Vector3(13, 3.2, 1), Vector3(side * 10.5, 1.6, 17.5), V.STONE)
		V.solid(self, Vector3(13, 3.2, 1), Vector3(side * 10.5, 1.6, -17.5), V.STONE)
	V.solid(self, Vector3(8, 5, 1), Vector3(0, 2.5, -18), V.INK)
	V.label(self, "THE UNLUCKY FEW", Vector3(0, 5.4, -17.2), 55)

func _build_stands() -> void:
	for tier in range(3):
		var extent = 19.2 + tier * 2.4
		var y = 1.6 + tier * 0.80
		for side in [-1, 1]:
			V.box(self, Vector3(2.4, y * 2, extent * 2), Vector3(side * extent, y, 0), V.DARK_STONE.lightened(tier * 0.07))
			if side < 0:
				V.box(self, Vector3(extent * 2, y * 2, 2.4), Vector3(0, y, side * extent), V.DARK_STONE.lightened(tier * 0.07))
			else:
				# Leave the central south opening clear for the barracks and gate.
				for edge in [-1, 1]:
					V.box(self, Vector3(extent - 9.0, y * 2, 2.4), Vector3(edge * (extent + 9.0) / 2.0, y, extent), V.DARK_STONE.lightened(tier * 0.07))
	for side in [-1, 1]:
		for along in range(-24, 25, 4):
			for flip in [false, true]:
				if flip and side > 0 and abs(along) < 10:
					continue
				var pos = Vector3(side * 25.5, 5.6, along) if not flip else Vector3(along, 5.6, side * 25.5)
				V.box(self, Vector3(1.0, 11.2, 1.0), pos, V.STONE)
				V.box(self, Vector3(1.45, 0.40, 1.45), pos + Vector3(0, 5.5, 0), V.BRONZE)
		V.box(self, Vector3(53, 1.0, 1.4), Vector3(0, 11.7, side * 25.5), V.STONE)
		V.box(self, Vector3(1.4, 1.0, 53), Vector3(side * 25.5, 11.7, 0), V.STONE)
		for x in [-13, -6, 6, 13]:
			var banner = V.box(self, Vector3(1.45, 3.0, 0.13), Vector3(x, 4.9, side * 17.0), V.RED if x < 0 else V.TEAL)
			V.box(banner, Vector3(0.16, 2.3, 0.03), Vector3(0, 0, -side * 0.08), V.BRONZE)
	# Crowd uses one draw call, with deterministic color variation.
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var crowd_shape = CapsuleMesh.new()
	crowd_shape.radius = 0.23
	crowd_shape.height = 1.15
	crowd_shape.radial_segments = 6
	crowd_shape.rings = 2
	mm.mesh = crowd_shape
	mm.instance_count = 384
	var palette = [Color("783c31"), Color("365c62"), Color("baa37a"), Color("5b544b"), Color("a87b43")]
	for i in range(384):
		var tier = int(i / 128)
		var side = int((i % 128) / 32)
		var along = -22.0 + (i % 32) * 1.4
		var radius = 19.1 + tier * 2.4
		var pos = Vector3(along, 3.90 + tier * 1.6, radius)
		pos = pos.rotated(Vector3.UP, side * PI / 2)
		var crowd_basis = Basis.IDENTITY
		if side == 0 and absf(along) < 9:
			crowd_basis = crowd_basis.scaled(Vector3.ONE * 0.001)
			pos.y = -10
		mm.set_instance_transform(i, Transform3D(crowd_basis, pos))
		mm.set_instance_color(i, palette[i % palette.size()])
	spectator_mesh = MultiMeshInstance3D.new()
	spectator_mesh.multimesh = mm
	var crowd_mat = StandardMaterial3D.new()
	crowd_mat.vertex_color_use_as_albedo = true
	spectator_mesh.material_override = crowd_mat
	add_child(spectator_mesh)

func _build_barracks() -> void:
	V.solid(self, Vector3(16, 0.6, 16), Vector3(0, -0.3, 25), V.DARK_STONE)
	V.solid(self, Vector3(1, 5, 16), Vector3(-8.5, 2.5, 25), V.STONE)
	V.solid(self, Vector3(1, 5, 16), Vector3(8.5, 2.5, 25), V.STONE)
	V.solid(self, Vector3(18, 5, 1), Vector3(0, 2.5, 33), V.STONE)
	V.label(self, "THE BARRACKS", Vector3(0, 3.8, 32.4), 40).rotation.y = PI
	V.label(self, "TAKE SOMETHING SHARP", Vector3(-4.5, 2.7, 24.5), 23).rotation.y = PI / 2
	for x in [-6.6, 6.6]:
		V.solid(self, Vector3(1.3, 0.6, 5), Vector3(x, 0.3, 28), V.WOOD)
		for z in [19.5, 30.5]:
			V.cylinder(self, 0.17, 2.2, Vector3(x, 1.1, z), V.WOOD)
			V.sphere(self, 0.26, Vector3(x, 2.35, z), Color("ffb447"))
			var lamp = OmniLight3D.new()
			lamp.position = Vector3(x, 2.5, z)
			lamp.light_color = Color("ffb563")
			lamp.light_energy = 1.8
			lamp.omni_range = 7.0
			add_child(lamp)
	arena_gate = StaticBody3D.new()
	arena_gate.position = Vector3(0, 0, 17.5)
	arena_gate.collision_layer = 1
	add_child(arena_gate)
	var shape = CollisionShape3D.new()
	var block = BoxShape3D.new()
	block.size = Vector3(8, 4.0, 0.35)
	shape.shape = block
	shape.position.y = 2
	arena_gate.add_child(shape)
	for x in range(-7, 8):
		V.box(arena_gate, Vector3(0.12, 4.0, 0.18), Vector3(x * 0.5, 2, 0), V.IRON)
	V.box(arena_gate, Vector3(8, 0.25, 0.3), Vector3(0, 3.5, 0), V.BRONZE)
	V.label(self, "MIND THE POINTY END", Vector3(0, 4.7, 17.4), 28)

func _build_hazards() -> void:
	trap = StaticBody3D.new()
	trap.collision_layer = 1
	add_child(trap)
	trap_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(8, 0.35, 8)
	trap_shape.shape = shape
	trap_shape.position.y = -0.18
	trap.add_child(trap_shape)
	trap_mesh = Node3D.new()
	trap.add_child(trap_mesh)
	for x in range(-7, 8):
		V.box(trap_mesh, Vector3(0.44, 0.2, 7.95), Vector3(x * 0.5, -0.12, 0), V.WOOD.lightened((x % 3) * 0.035))
	for z in [-3.5, 0, 3.5]:
		V.box(trap_mesh, Vector3(7.95, 0.06, 0.16), Vector3(0, 0.01, z), V.IRON)
	for side in [-1, 1]:
		V.box(self, Vector3(8.8, 0.04, 0.2), Vector3(0, 0.025, side * 4.35), V.BRONZE)
		V.box(self, Vector3(0.2, 0.04, 8.8), Vector3(side * 4.35, 0.025, 0), V.BRONZE)
	sweeper = Node3D.new()
	sweeper.position = Vector3(10.5, 0, -1.5)
	add_child(sweeper)
	V.cylinder(sweeper, 0.28, 1.8, Vector3(0, 0.9, 0), V.IRON)
	V.box(sweeper, Vector3(6.4, 0.34, 0.40), Vector3(0, 0.82, 0), V.WOOD)
	for x in [-2.8, -1.8, 1.8, 2.8]:
		V.box(sweeper, Vector3(0.16, 0.48, 0.53), Vector3(x, 0.82, 0), V.BRONZE)
	var ring = TorusMesh.new()
	ring.inner_radius = 3.2
	ring.outer_radius = 3.35
	ring.rings = 32
	ring.ring_segments = 8
	warning_ring = V.mesh(self, ring, Vector3(10.5, 0.02, -1.5), V.RED)
	warning_ring.scale.y = 0.1
	beast_gate = Node3D.new()
	beast_gate.position = Vector3(0, 0, -17.35)
	add_child(beast_gate)
	for x in range(-7, 8):
		V.box(beast_gate, Vector3(0.13, 4, 0.20), Vector3(x * 0.5, 2, 0), V.IRON)
	V.label(self, "DO NOT FEED THE BOAR", Vector3(0, 4.3, -17.2), 25)

func update_state(open_pit: bool, open_gate: bool, released: bool, elapsed: float, delta: float) -> void:
	if open_pit != pit_open:
		pit_open = open_pit
		trap_shape.set_deferred("disabled", pit_open)
	trap_mesh.position.y = move_toward(trap_mesh.position.y, -3.0 if pit_open else 0.0, delta * 4)
	trap_mesh.visible = trap_mesh.position.y > -2.8
	if gate_open != open_gate:
		gate_open = open_gate
		arena_gate.get_child(0).set_deferred("disabled", gate_open)
	arena_gate.position.y = move_toward(arena_gate.position.y, 4.4 if open_gate else 0, delta * 3)
	beast_gate.position.y = move_toward(beast_gate.position.y, 4.3 if released else 0, delta * 2.8)
	sweeper.rotation.y = elapsed * 0.78

func beam_ends() -> Array:
	return [sweeper.to_global(Vector3(-3.2, 0.82, 0)), sweeper.to_global(Vector3(3.2, 0.82, 0))]
