extends RigidBody3D
class_name Target
## The thing you actually want to hit: a glowing orb sitting on/in the tower.
##
## Destruction rule (simple collision detection): any projectile or fast-moving
## structure touching it with relative speed above `destroy_threshold` pops it.
## On pop it freezes, sinks and fades out — then frees itself.

signal destroyed(target: Target)

# FreezeMode.KINEMATIC_FIXED (numeric: enum constants are not exposed
	# to GDScript in all 4.x builds).
const KINEMATIC_REST := 1

var points: int = GameSettings.target_points
var destroy_threshold: float = 4.5
var is_destroyed: bool = false
var _fade_time: float = 0.0
var _visual: MeshInstance3D = null
var _inner: MeshInstance3D = null


func _ready() -> void:
	mass = 1.2
	collision_layer = 8   # targets
	collision_mask = 1 | 2 | 4 | 8
	can_sleep = true
	physics_material_override = _bounce_material()
	_build_shape()
	_build_visual()
	body_entered.connect(_on_body_entered)


static func create(parent: Node, position: Vector3, radius: float = 0.42, pts: int = -1) -> Target:
	var t := Target.new()
	t.name = "Target"
	if pts > 0:
		t.points = pts
	parent.add_child(t)
	t.global_position = position
	return t


func try_destroy(reason: String) -> void:
	if is_destroyed:
		return
	is_destroyed = true
	Log.physics("target destroyed (%s) +%d pts" % [reason, points])
	emit_signal("destroyed", self)
	freeze_mode = KINEMATIC_REST
	freeze = true
	set_collision_mask_value(1, false)
	set_collision_layer_value(8, false)
	_fade_time = 0.75


func settle_speed() -> float:
	return 0.0 if is_destroyed else linear_velocity.length()


func _physics_process(delta: float) -> void:
	if _fade_time > 0.0:
		_fade_time -= delta
		var k := clampf(1.0 - _fade_time / 0.75, 0.0, 1.0)
		global_position += Vector3(0, -1.2 * delta, 0)
		var sc := maxf(1.0 - k, 0.02)
		scale = Vector3(sc, sc, sc)
		if _fade_time <= 0.0:
			queue_free()


func _on_body_entered(body: Node) -> void:
	if is_destroyed:
		return
	var rel := absf(linear_velocity.dot((body as RigidBody3D).linear_velocity)) \
		if body is RigidBody3D else 0.0
	if body is Projectile:
		rel = body.linear_velocity.length()
	if rel >= destroy_threshold:
		try_destroy("impact speed %.1f" % rel)


func _build_shape() -> void:
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var sphere := SphereShape3D.new()
	sphere.radius = 0.45
	cs.shape = sphere
	add_child(cs)


func _build_visual() -> void:
	_visual = MeshInstance3D.new()
	_visual.name = "Visual"
	_visual.mesh = Theme3D.sphere(0.42, Theme3D.TARGET_A)
	_visual.material_override = Theme3D.emissive_mat(Theme3D.TARGET_A, 0.45)
	add_child(_visual)
	_inner = MeshInstance3D.new()
	_inner.name = "Inner"
	_inner.mesh = Theme3D.sphere(0.22, Theme3D.TARGET_B)
	_inner.material_override = Theme3D.emissive_mat(Theme3D.TARGET_B, 0.8)
	add_child(_inner)


func _bounce_material() -> PhysicsMaterial:
	var m := PhysicsMaterial.new()
	m.bounce = 0.2
	m.friction = 0.8
	return m
