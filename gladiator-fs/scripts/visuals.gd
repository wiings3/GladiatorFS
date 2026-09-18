class_name ArenaVisuals
extends RefCounted
## Small, original mesh kit. No external assets or import dependencies.

const SAND = Color("c99960")
const STONE = Color("d7b886")
const DARK_STONE = Color("77614d")
const BRONZE = Color("b8853c")
const IRON = Color("67797e")
const WOOD = Color("674532")
const INK = Color("25262b")
const RED = Color("a84232")
const TEAL = Color("387e82")
static var materials = {}

static func material(color: Color, metal: float = 0.0) -> StandardMaterial3D:
	var key = str(color) + str(metal)
	if not materials.has(key):
		var m = StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		m.metallic = metal
		materials[key] = m
	return materials[key]

static func mesh(parent: Node3D, shape: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.mesh = shape
	node.position = pos
	node.material_override = material(color)
	parent.add_child(node)
	return node

static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var shape = BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, pos, color)

static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, top: float = -1.0) -> MeshInstance3D:
	var shape = CylinderMesh.new()
	shape.top_radius = radius if top < 0 else top
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 10
	return mesh(parent, shape, pos, color)

static func sphere(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var shape = SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = 10
	shape.rings = 5
	return mesh(parent, shape, pos, color)

static func solid(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	box(body, size, Vector3.ZERO, color)
	var collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	return body

static func label(parent: Node3D, content: String, pos: Vector3, size: int = 40) -> Label3D:
	var node = Label3D.new()
	node.text = content
	node.position = pos
	node.font_size = size
	node.pixel_size = 0.012
	node.modulate = Color("f4dfb0")
	node.outline_modulate = INK
	node.outline_size = 7
	parent.add_child(node)
	return node

static func weapon(kind: String) -> Node3D:
	# Weapon meshes point down -Z. The same meshes are held, dropped and thrown.
	var root = Node3D.new()
	match kind:
		"sword":
			box(root, Vector3(0.13, 0.12, 0.36), Vector3(0, 0, 0.1), WOOD)
			box(root, Vector3(0.48, 0.10, 0.12), Vector3(0, 0, -0.09), BRONZE)
			box(root, Vector3(0.18, 0.065, 1.00), Vector3(0, 0, -0.63), Color("c8d6d3"))
			var tip = cylinder(root, 0.11, 0.27, Vector3(0, 0, -1.23), Color("d8e1d9"), 0)
			tip.rotation.x = -PI / 2
		"spear":
			box(root, Vector3(0.075, 0.075, 2.9), Vector3(0, 0, -0.55), WOOD)
			var tip = cylinder(root, 0.14, 0.55, Vector3(0, 0, -2.22), Color("c8d6d3"), 0)
			tip.rotation.x = -PI / 2
			box(root, Vector3(0.13, 0.13, 0.22), Vector3(0, 0, -1.9), BRONZE)
		"hammer":
			box(root, Vector3(0.12, 0.12, 1.25), Vector3(0, 0, -0.32), WOOD)
			box(root, Vector3(0.88, 0.42, 0.46), Vector3(0, 0, -1.0), IRON)
			box(root, Vector3(0.20, 0.45, 0.48), Vector3(0, 0, -1.0), BRONZE)
		"shield":
			var rim = cylinder(root, 0.62, 0.13, Vector3.ZERO, BRONZE)
			rim.rotation.x = PI / 2
			var center = cylinder(root, 0.54, 0.15, Vector3(0, 0, -0.025), RED)
			center.rotation.x = PI / 2
			sphere(root, 0.16, Vector3(0, 0, -0.11), BRONZE)
		"jar":
			cylinder(root, 0.34, 0.6, Vector3.ZERO, Color("bd7045"), 0.23)
			cylinder(root, 0.24, 0.10, Vector3(0, 0.35, 0), STONE)
		"food":
			var loaf = sphere(root, 0.27, Vector3.ZERO, Color("ecb457"))
			loaf.scale = Vector3(1.3, 0.6, 0.85)
		"trash":
			sphere(root, 0.20, Vector3.ZERO, Color("b44131"))
			box(root, Vector3(0.12, 0.10, 0.12), Vector3(0, 0.19, 0), TEAL)
	return root

static func gladiator(root: Node3D, color: Color, beast: bool = false) -> Dictionary:
	if beast:
		var body = sphere(root, 0.7, Vector3(0, 0.8, 0), WOOD)
		body.scale = Vector3(0.9, 0.8, 1.45)
		box(root, Vector3(0.8, 0.55, 0.75), Vector3(0, 0.8, -0.85), DARK_STONE)
		box(root, Vector3(0.5, 0.30, 0.23), Vector3(0, 0.68, -1.28), Color("be957b"))
		for side in [-1, 1]:
			cylinder(root, 0.09, 0.40, Vector3(side * 0.33, 0.90, -1.18), STONE, 0)
			box(root, Vector3(0.15, 0.18, 0.24), Vector3(side * 0.28, 1.21, -0.72), WOOD)
			for z in [-0.45, 0.5]:
				box(root, Vector3(0.19, 0.48, 0.23), Vector3(side * 0.40, 0.26, z), INK)
		return {}
	var skin = Color("c39470")
	var legs = []
	for side in [-1, 1]:
		var leg = Node3D.new()
		leg.position = Vector3(side * 0.23, 0.8, 0)
		root.add_child(leg)
		box(leg, Vector3(0.25, 0.66, 0.26), Vector3(0, -0.32, 0), skin)
		box(leg, Vector3(0.29, 0.12, 0.44), Vector3(0, -0.70, -0.09), WOOD)
		box(leg, Vector3(0.27, 0.21, 0.30), Vector3(0, -0.48, 0), BRONZE)
		legs.append(leg)
	var chest = Node3D.new()
	chest.name = "Torso"
	root.add_child(chest)
	var torso = cylinder(chest, 0.43, 0.63, Vector3(0, 1.20, 0), color, 0.48)
	torso.scale.z = 0.7
	cylinder(chest, 0.48, 0.32, Vector3(0, 0.78, 0), color.darkened(0.15), 0.38)
	box(chest, Vector3(0.86, 0.12, 0.59), Vector3(0, 0.94, 0), WOOD)
	box(chest, Vector3(0.18, 0.17, 0.065), Vector3(0, 0.94, -0.32), BRONZE)
	# Group the head so the local first-person camera can see past its own helmet.
	var head = Node3D.new()
	head.name = "Head"
	root.add_child(head)
	box(head, Vector3(0.45, 0.43, 0.40), Vector3(0, 1.74, -0.02), skin)
	var helmet = cylinder(head, 0.39, 0.45, Vector3(0, 1.92, 0.015), BRONZE, 0.29)
	helmet.scale.z = 0.85
	box(head, Vector3(0.53, 0.09, 0.10), Vector3(0, 1.79, -0.33), INK)
	box(head, Vector3(0.09, 0.27, 0.10), Vector3(0, 1.72, -0.36), BRONZE)
	box(head, Vector3(0.17, 0.38, 0.55), Vector3(0, 2.22, 0.01), color)
	var hands = []
	for side in [-1, 1]:
		var arm = Node3D.new()
		arm.position = Vector3(side * 0.54, 1.35, 0)
		root.add_child(arm)
		box(arm, Vector3(0.24, 0.47, 0.26), Vector3(0, -0.15, 0), skin)
		box(arm, Vector3(0.31, 0.18, 0.32), Vector3(0, 0.12, 0), BRONZE)
		box(arm, Vector3(0.27, 0.17, 0.27), Vector3(0, -0.36, 0), WOOD)
		var hand = Node3D.new()
		hand.position = Vector3(0, -0.32, -0.10)
		arm.add_child(hand)
		hands.append(hand)
	return {"legs": legs, "head": head, "torso": chest, "left": hands[0], "right": hands[1], "left_arm": hands[0].get_parent(), "right_arm": hands[1].get_parent()}
