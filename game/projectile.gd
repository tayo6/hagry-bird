extends RigidBody3D
class_name Projectile
## The launched ball. Real physics only — after launch this body is fully
## controlled by the Godot 3D physics engine (no animation, no tweens).

signal launched(velocity: Vector3)
signal came_to_rest()
signal bounced(strength: float)

var radius: float = GameSettings.projectile_radius:
	set(value):
		radius = value
		_rebuild_shape()

var armed: bool = false          # sitting in the fork, waiting for input
var in_flight: bool = false
var rest_reported: bool = false


func _ready() -> void:
	mass = GameSettings.projectile_mass
	gravity_scale = GameSettings.gravity_scale
	linear_damp = GameSettings.linear_damp
	can_sleep = true
	var pm := PhysicsMaterial.new()
	pm.bounce = GameSettings.restitution
	pm.friction = 0.6
	physics_material_override = pm
	collision_layer = 2   # projectiles
	# Layers: 1 ground, 2 projectiles, 4 structures, 8 targets.
	collision_mask = 1 | 4 | 8
	body_entered.connect(_on_body_entered)
	_rebuild_shape()
	_build_visual()


func arm(at_position: Vector3) -> void:
	global_position = at_position
	freeze_mode = 1  # FreezeMode.KINEMATIC_FIXED
	freeze = true
	armed = true
	in_flight = false
	rest_reported = false
	reset_physics_interpolation()


func disarm() -> void:
	armed = false
	freeze = false


## Launch with an explicit velocity (m/s). Called by Launcher on release.
func fire(velocity: Vector3) -> void:
	if in_flight:
		return
	disarm()
	# Convert from kinematic freeze straight to dynamic motion.
	linear_velocity = velocity
	# A touch of spin reads better visually and is still pure physics.
	apply_torque_impulse(Vector3(0, -radius * mass * velocity.length() * 0.05, 0))
	in_flight = true
	emit_signal("launched", velocity)
	Log.physics("projectile fired: v=%s speed=%.1f m/s" % [
		_velocity_str(velocity), velocity.length()])


func settle_speed() -> float:
	return linear_velocity.length()


func out_of_bounds() -> bool:
	var p := global_position
	return p.y < GameSettings.out_of_bounds_y or absf(p.x) > GameSettings.out_of_bounds_x \
		or absf(p.z) > GameSettings.out_of_bounds_x


func _physics_process(_delta: float) -> void:
	pass  # rest detection is centralised in GameWorld.settle logic


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if in_flight and not rest_reported and state != null:
		if state.transform.origin.y < GameSettings.out_of_bounds_y:
			rest_reported = true
			set_deferred("_report_fell_out", true)


func _report_fell_out(_v: bool) -> void:
	Log.physics("projectile fell out of bounds -> rest")
	emit_signal("came_to_rest")


func _velocity_str(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]


func _on_body_entered(body: Node) -> void:
	if not in_flight:
		return
	var strength: float = clampf(linear_velocity.length() / 30.0, 0.0, 1.0)
	if strength > 0.08:
		emit_signal("bounced", strength)
	# Heavy hits knock blocks/targets loose (gameplay assist, still physics-driven).
	if body is Structure and linear_velocity.length() > 6.0:
		var s := body as Structure
		s.apply_central_impulse(linear_velocity * 0.35 * mass)
	if body is Target and linear_velocity.length() > 4.0:
		(body as Target).try_destroy("impact")


func _rebuild_shape() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			child.queue_free()
	var shape_node := CollisionShape3D.new()
	shape_node.name = "Shape"
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape_node.shape = sphere
	add_child(shape_node)


func _build_visual() -> void:
	for child in get_children():
		if child.name == "BallVisual":
			child.queue_free()
	var visual := Theme3D.make_projectile_mesh(radius)
	visual.name = "BallVisual"
	add_child(visual)
