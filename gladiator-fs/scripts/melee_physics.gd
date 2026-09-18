extends RefCounted
## Physical dimensions and a spring-driven hand, shared by players and NPCs.
## These are fixed material/geometry properties, never loot stats or upgrades.
const REST = Vector2(-0.70, 0.65)
const MIN_ANGLE = Vector2(-1.35, -0.90)
const MAX_ANGLE = Vector2(1.35, 1.35)

static func properties(kind: String) -> Dictionary:
	match kind:
		"sword": return {"mass": 1.3, "length": 1.36, "inertia": 0.65, "edge": 0.22, "radius": 0.095}
		"spear": return {"mass": 2.4, "length": 2.48, "inertia": 2.80, "edge": 1.96, "radius": 0.075}
		"hammer": return {"mass": 6.5, "length": 1.22, "inertia": 5.20, "edge": 0.80, "radius": 0.095}
		"shield": return {"mass": 3.4, "length": 0.65, "inertia": 1.8, "edge": 0.0, "radius": 0.26}
		"jar": return {"mass": 2.2, "length": 0.35, "inertia": 0.9, "edge": 0.0, "radius": 0.25}
		"trash", "food": return {"mass": 0.3, "length": 0.25, "inertia": 0.12, "edge": 0.0, "radius": 0.16}
		_: return {"mass": 0.0, "length": 0.20, "inertia": 0.2, "edge": 0.0, "radius": 0.16}

static func burden(weapon: String, shield: bool) -> float:
	return properties(weapon).mass + (properties("shield").mass if shield else 0.0)

static func movement_factor(weapon: String, shield: bool) -> float:
	var weight = burden(weapon, shield)
	# Ordinary kit stays nimble; most of the burden comes from genuinely heavy loads.
	return 1.0 / (1.0 + weight * 0.008 + maxf(0, weight - 4.0) * 0.048)

static func angle_limit(value: Vector2) -> Vector2:
	return value.clamp(MIN_ANGLE, MAX_ANGLE)

static func hand_frame(angles: Vector2, extension: float = 0.0) -> Transform3D:
	var orientation = Basis(Vector3.UP, angles.x) * Basis(Vector3.RIGHT, angles.y)
	var hand = Vector3(0.46, 1.38, -0.10) + orientation * Vector3(0, 0, -0.45 - extension)
	return Transform3D(orientation, hand)

static func shield_frame(pitch: float, raised: float) -> Transform3D:
	var orientation = Basis(Vector3.RIGHT, pitch * raised)
	var raised_center = Vector3(-0.17, 1.30, 0) + orientation * Vector3(0, 0, -0.72)
	return Transform3D(orientation, Vector3(-0.60, 0.95, 0.03).lerp(raised_center, raised))

static func integrate(angles: Vector2, speed: Vector2, target: Vector2, kind: String, delta: float, release: bool = false) -> Array:
	var stiffness = 380.0 if kind != "spear" else 310.0
	var damping = 30.0
	var max_speed = 18.0
	if kind == "hammer":
		stiffness = 650.0 if release else 75.0
		damping = 29.0 if release else 15.0
		max_speed = 22.0 if release else 3.2
	var acceleration = (angle_limit(target) - angles) * stiffness - speed * damping
	speed = (speed + acceleration * delta).limit_length(max_speed)
	var next = angle_limit(angles + speed * delta)
	if next.x == MIN_ANGLE.x or next.x == MAX_ANGLE.x: speed.x = 0
	if next.y == MIN_ANGLE.y or next.y == MAX_ANGLE.y: speed.y = 0
	return [next, speed]

static func impact_damage(kind: String, speed: float, height: float) -> float:
	# Shape, mass and speed determine impact. No equipment rolls or progression.
	var mass = maxf(0.45, properties(kind).mass)
	var impact = clampf(5.0 + pow(minf(speed, 16.0), 1.35) * sqrt(mass) * 1.05, 0, 65)
	if kind == "": impact *= 0.4
	var location = 2.2 if height >= 1.60 else (0.5 if height < 0.82 else 1.0)
	return impact * location

static func samples(kind: String) -> Array:
	var p = properties(kind)
	var result = []
	var count = maxi(2, ceili(p.length / 0.17))
	for i in range(count + 1):
		var distance = lerpf(0.06, p.length, float(i) / count)
		result.append({"point": Vector3(0, 0, -distance), "radius": p.radius, "edge": distance >= p.edge})
	if kind == "hammer":
		for x in [-0.31, 0.0, 0.31]:
			result.append({"point": Vector3(x, 0, -1.0), "radius": 0.22, "edge": true})
	return result

static func contact(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, radius: float, excluded: Array[RID], mask: int = 15) -> Dictionary:
	var shape = SphereShape3D.new()
	shape.radius = radius
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = to - from
	query.collision_mask = mask
	query.exclude = excluded
	var travel = space.cast_motion(query)
	var fraction = travel[1]
	query.motion = Vector3.ZERO
	query.transform.origin = from.lerp(to, minf(fraction + 0.015, 1.0))
	var info = space.get_rest_info(query)
	if info.is_empty():
		return {}
	return {"collider": instance_from_id(info.collider_id), "point": info.point, "normal": info.normal, "fraction": fraction}

static func sweep(actor, previous: Transform3D, current: Transform3D, delta: float) -> Dictionary:
	var excluded: Array[RID] = [actor.get_rid(), actor.shield_body.get_rid()]
	var space = actor.get_world_3d().direct_space_state
	var subdivisions = maxi(1, ceili(actor.weapon_previous_angle.distance_to(actor.weapon_angle) / 0.07))
	var points = actor.weapon_samples
	var local_previous = hand_frame(actor.weapon_previous_angle, actor.weapon_previous_extension)
	var local_current = hand_frame(actor.weapon_angle, actor.weapon_extension)
	# Substep curved motion, then sweep small spheres along the visible shaft/head.
	# Broad reach/cone tests cannot damage a target: an actual shape must touch it.
	for step in range(subdivisions):
		var a = previous.interpolate_with(current, float(step) / subdivisions)
		var b = previous.interpolate_with(current, float(step + 1) / subdivisions)
		var first = {}
		for sample in points:
			var start = a * sample.point
			var end = b * sample.point
			if start.distance_to(end) < 0.0001:
				continue
			var hit = contact(space, start, end, sample.radius, excluded)
			if hit.is_empty():
				continue
			if first.is_empty() or hit.fraction < first.fraction:
				first = hit
				first["velocity"] = (end - start) / (delta / subdivisions)
				# Locomotion and camera rotation alone cannot turn a held blade into a blender.
				var local_a = local_previous.interpolate_with(local_current, float(step) / subdivisions) * sample.point
				var local_b = local_previous.interpolate_with(local_current, float(step + 1) / subdivisions) * sample.point
				first["speed"] = local_a.distance_to(local_b) / (delta / subdivisions)
				first["edge"] = sample.edge
		if not first.is_empty():
			first["fraction"] = (step + first.fraction) / subdivisions
			return first
	return {}
