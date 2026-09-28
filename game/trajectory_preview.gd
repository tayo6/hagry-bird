extends Node
class_name TrajectoryPreview
## Dotted ballistic preview drawn with a MeshInstance3D + SurfaceTool.
##
## IMPORTANT: this is only a *visual aid*. The actual flight is 100% Godot
## physics (RigidBody3D). The integrator below mirrors the closed-form of a
## semi-implicit Euler step at the fixed physics tick rate, including linear
## damping and gravity_scale, so the dots match what the engine will do.

const DOT_COUNT := 26
const DOT_SPACING_SECONDS := 0.055   # one dot per ~3 physics ticks @60Hz
const DOT_RADIUS := 0.09

var _mesh_instance: MeshInstance3D = null
var _material: StandardMaterial3D = null
var _sphere: SphereMesh = null


func _init(parent: Node) -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "TrajectoryDots"
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
	_sphere = SphereMesh.new()
	_sphere.radius = DOT_RADIUS
	_sphere.height = DOT_RADIUS * 2.0
	_sphere.radial_steps = 6
	_sphere.rings = 4
	_mesh_instance.material_override = _material
	parent.add_child(_mesh_instance)
	hide()


func hide() -> void:
	if _mesh_instance:
		_mesh_instance.visible = false


func visible() -> bool:
	return _mesh_instance != null and _mesh_instance.visible


func show_from(origin: Vector3, velocity: Vector3, gravity_scale: float = 1.0) -> void:
	var points := simulate_points(origin, velocity, gravity_scale)
	_build(points)
	_mesh_instance.visible = true


static func simulate_points(origin: Vector3, velocity: Vector3, gravity_scale: float = 1.0) -> PackedVector3Array:
	## Pure function (unit-testable): returns sampled positions along the path.
	var pts := PackedVector3Array()
	var g := Vector3(0.0, -ProjectSettings.get_setting("physics/3d/default_gravity") * gravity_scale, 0.0)
	var dt := 1.0 / float(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"))
	var pos := origin
	var vel := velocity
	var steps_per_dot := maxi(int(DOT_SPACING_SECONDS / dt), 1)
	for i in DOT_COUNT:
		for s in steps_per_dot:
			# Godot's rigid-body integration order: damp, then gravity, then move.
			vel -= vel * GameSettings.linear_damp * dt
			vel += g * dt
			pos += vel * dt
		if pos.y < -0.02:
			pts.append(Vector3(pos.x, 0.02, pos.z))  # clamp last dot onto ground
			break
		pts.append(pos)
	return pts


func _build(points: PackedVector3Array) -> void:
	if points.is_empty():
		_mesh_instance.mesh = null
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radius := DOT_RADIUS
	var ring := PackedVector3Array([
		Vector3(1, 0, 0), Vector3(0.71, 0, 0.71), Vector3(0, 0, 1), Vector3(-0.71, 0, 0.71),
		Vector3(-1, 0, 0), Vector3(-0.71, 0, -0.71), Vector3(0, 0, -1), Vector3(0.71, 0, -0.71),
	])
	for p in points:
		var top := p + Vector3(0, radius, 0)
		var bottom := p - Vector3(0, radius, 0)
		for i in ring.size():
			var a := ring[i] * radius + p
			var b := ring[(i + 1) % ring.size()] * radius + p
			_tri(st, top, a, b)
			_tri(st, bottom, b, a)
	st.generate_normals()
	_mesh_instance.mesh = st.commit()


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
