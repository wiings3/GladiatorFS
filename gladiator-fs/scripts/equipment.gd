extends RigidBody3D
const V = preload("res://scripts/visuals.gd")
var game
var uid = 0
var kind = "sword"
var thrower = 0
var flight_time = 0.0
var age = 0.0
var last_position = Vector3.ZERO
var target_position = Vector3.ZERO
var target_rotation = Vector3.ZERO
var replica_initialized = false

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	mass = 2.0 if kind == "hammer" else 1.0
	continuous_cd = true
	var mesh = V.weapon(kind)
	add_child(mesh)
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	match kind:
		"spear": shape.size = Vector3(0.16, 0.16, 3.3); collision.position.z = -0.6
		"sword": shape.size = Vector3(0.28, 0.12, 1.5); collision.position.z = -0.5
		"hammer": shape.size = Vector3(0.85, 0.42, 1.5); collision.position.z = -0.3
		"shield": shape.size = Vector3(1.2, 1.2, 0.16)
		_: shape.size = Vector3(0.5, 0.5, 0.5)
	collision.shape = shape
	add_child(collision)
	var physics = PhysicsMaterial.new()
	physics.friction = 0.85
	physics.bounce = 0.15
	physics_material_override = physics
	freeze = not game.authority
	last_position = global_position

func _physics_process(delta: float) -> void:
	if not game.running:
		return
	if not game.authority:
		global_position = global_position.lerp(target_position, minf(delta * 22, 1.0))
		rotation = Vector3(lerp_angle(rotation.x, target_rotation.x, delta * 20), lerp_angle(rotation.y, target_rotation.y, delta * 20), lerp_angle(rotation.z, target_rotation.z, delta * 20))
		return
	age += delta
	if flight_time > 0:
		flight_time -= delta
		game.sweep_projectile(self, last_position, global_position)
	last_position = global_position
	if global_position.y < -10 or age > 150:
		game.remove_item(uid)

func serialize() -> Dictionary:
	return {"id": uid, "k": kind, "p": global_position, "r": rotation}

func receive(data: Dictionary) -> void:
	target_position = data.p
	target_rotation = data.r
	if not replica_initialized or global_position.distance_to(target_position) > 6:
		global_position = target_position
		rotation = target_rotation
		replica_initialized = true
