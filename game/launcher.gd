extends Node
class_name Launcher
## Y-shaped slingshot built procedurally. Owns the *aiming maths* and the
## currently armed projectile; input routing happens in GameWorld.
##
## Drag model (side view, X = forward, Y = up):
##   - pointer grabs the ball at rest position
##   - dragging backward (toward -X / down) stores pull vector p
##   - release launches with velocity = -p * launch_power  (slingshot style)

signal drag_started
signal drag_updated(pull: Vector3, velocity: Vector3)
signal drag_cancelled
signal released(velocity: Vector3)

const FORK_HEIGHT := 2.4
const CUP_OFFSET := Vector3(0.0, FORK_HEIGHT + 0.15, 0.0)  # ball rest point

var node_3d: Node3D = null                 # visual root, added to the world
var cup_position: Vector3 = CUP_OFFSET     # global ball anchor
var dragging: bool = false
var current_pull: Vector3 = Vector3.ZERO   # from cup toward pointer (world space)
var band_left: MeshInstance3D = null
var band_right: MeshInstance3D = null


func _init(parent: Node, origin: Vector3) -> void:
	node_3d = _build_visual()
	parent.add_child(node_3d)
	node_3d.global_position = origin
	cup_position = origin + CUP_OFFSET


static func pull_to_velocity(pull: Vector3) -> Vector3:
	## Pure function (unit-tested): launch velocity for a given pull vector.
	var v := -pull * GameSettings.launch_power
	var speed := v.length()
	if speed > GameSettings.max_launch_speed:
		v = v.normalized() * GameSettings.max_launch_speed
	return v


static func clamp_pull(pull: Vector3) -> Vector3:
	if pull.length() > GameSettings.max_drag_meters:
		return pull.normalized() * GameSettings.max_drag_meters
	return pull


func begin_drag() -> void:
	dragging = true
	current_pull = Vector3.ZERO
	emit_signal("drag_started")
	Log.input_ev("drag start @ cup=(%.1f, %.1f, %.1f)" % [cup_position.x, cup_position.y, cup_position.z])


func update_drag(pointer_world: Vector3) -> void:
	if not dragging:
		return
	var raw := pointer_world - cup_position
	# Side-view aim: keep depth roughly locked so play stays 2D-ish.
	raw.z = clampf(raw.z, -0.6, 0.6)
	current_pull = clamp_pull(raw)
	emit_signal("drag_updated", current_pull, pull_to_velocity(current_pull))


func end_drag() -> void:
	if not dragging:
		return
	dragging = false
	var velocity := pull_to_velocity(current_pull)
	var ok := velocity.length() >= GameSettings.min_launch_speed
	current_pull = Vector3.ZERO
	if ok:
		emit_signal("released", velocity)
	else:
		emit_signal("drag_cancelled")
		Log.input_ev("release ignored (speed %.1f < min %.1f)" % [velocity.length(), GameSettings.min_launch_speed])


## Ball position while dragging (for moving the frozen rigid body).
func loaded_ball_position() -> Vector3:
	return cup_position + current_pull


## Rebuild the two elastic bands between fork prongs and the ball.
func refresh_bands(ball_pos: Vector3) -> void:
	if band_left == null or node_3d == null:
		return
	var left_tip := node_3d.to_global(Vector3(-0.55, FORK_HEIGHT, 0.0))
	var right_tip := node_3d.to_global(Vector3(0.55, FORK_HEIGHT, 0.0))
	band_left.transform = _segment_transform(left_tip, ball_pos)
	band_right.transform = _segment_transform(right_tip, ball_pos)


func _build_visual() -> Node3D:
	var root := Node3D.new()
	root.name = "Launcher"

	# base mound
	var mound := MeshInstance3D.new()
	mound.mesh = Theme3D.sphere(0.85, Theme3D.PLATFORM)
	mound.scale = Vector3(1.0, 0.45, 1.0)
	mound.position = Vector3(0, 0.1, 0)
	root.add_child(mound)

	# trunk
	var trunk := MeshInstance3D.new()
	trunk.mesh = Theme3D.cylinder(0.16, FORK_HEIGHT, Theme3D.FORK_POST)
	trunk.position = Vector3(0, FORK_HEIGHT * 0.5, 0)
	root.add_child(trunk)

	# two prongs (angled boxes)
	for side in [-1, 1]:
		var prong := MeshInstance3D.new()
		prong.mesh = Theme3D.box(Vector3(0.16, 0.9, 0.16), Theme3D.FORK_POST)
		prong.position = Vector3(0.34 * side, FORK_HEIGHT - 0.1, 0)
		prong.rotation_z = deg_to_rad(-24.0 * side)
		root.add_child(prong)

	# elastic bands (unit-height Y cylinders stretched along segments)
	band_left = MeshInstance3D.new()
	band_left.name = "BandLeft"
	band_left.mesh = Theme3D.cylinder(0.045, 1.0, Theme3D.BAND)
	root.add_child(band_left)

	band_right = MeshInstance3D.new()
	band_right.name = "BandRight"
	band_right.mesh = Theme3D.cylinder(0.045, 1.0, Theme3D.BAND)
	root.add_child(band_right)

	return root


static func _segment_transform(from: Vector3, to: Vector3) -> Transform3D:
	## Orient a unit-height Y-cylinder along `from -> to` in global space.
	var delta := to - from
	var length := maxf(delta.length(), 0.05)
	var basis := Basis.IDENTITY
	if delta.length_squared() > 1e-8:
		basis = _y_aligned_basis(delta.normalized()).scaled(Vector3(1.0, length, 1.0))
	return Transform3D(basis, (from + to) * 0.5)


static func _y_aligned_basis(dir: Vector3) -> Basis:
	## Rotation that maps +Y onto `dir` (shortest arc).
	var axis := Vector3.UP.cross(dir)
	if axis.length_squared() < 1e-9:
		if dir.y > 0:
			return Basis.IDENTITY
		return Basis(Vector3.RIGHT, PI)
	var ang := acos(clampf(Vector3.UP.dot(dir), -1.0, 1.0))
	return Basis(axis.normalized(), ang)
