extends Node
class_name CameraController
## Simple side-view camera with projectile tracking.
##
## - Idle/aiming: frames launcher + structure (auto distance from level bounds).
## - Flight: pans toward the ball, clamped so the tower stays in view.
## No fancy smoothing rigs — just critically-damped lerp per frame.

var camera: Camera3D = null

var _target_x: float = 0.0
var _target_y: float = 5.0
var _zoom: float = 24.0
var _follow_body: RigidBody3D = null
var _frame_center_x: float = 10.0
var _frame_half_width: float = 16.0


func _init(parent: Node) -> void:
	camera = Camera3D.new()
	camera.name = "GameCamera"
	# Side view down -Z, looking at the X/Y play plane.
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 50.0
	camera.current = true
	parent.add_child(camera)
	camera.position = Vector3(_frame_center_x, _target_y, _zoom)
	camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)


func frame_level(launcher_pos: Vector3, structures_area_center_x: float, span_x: float) -> void:
	## Compute a framing that shows launcher + tower regardless of screen size.
	_frame_center_x = (launcher_pos.x + structures_area_center_x) * 0.5
	_frame_half_width = maxf(span_x * 0.5, 10.0)
	_zoom = _required_zoom()
	_target_y = maxf(4.5, _frame_half_width * 0.28)
	_follow_body = null
	_apply_instant()
	Log.boot("camera framed: center=%.1f half=%.1f zoom=%.1f" % [_frame_center_x, _frame_half_width, _zoom])


func follow(body: RigidBody3D) -> void:
	_follow_body = body
	Log.input_ev("camera: following projectile")


func unfollow() -> void:
	_follow_body = null


func _process(delta: float) -> void:
	var desired_x := _frame_center_x
	var desired_y := _target_y
	if _follow_body != null and is_instance_valid(_follow_body):
		var bp := _follow_body.global_position
		# Pan toward the ball but never lose the tower entirely.
		desired_x = clampf(bp.x * 0.65 + _frame_center_x * 0.35,
			_frame_center_x - _frame_half_width * 0.4,
			_frame_center_x + _frame_half_width * 1.15)
		desired_y = maxf(_target_y, bp.y + 2.0)
	var w := 1.0 - exp(-4.0 * delta)
	camera.position.x = lerpf(camera.position.x, desired_x, w)
	camera.position.y = lerpf(camera.position.y, desired_y, w)
	camera.position.z = lerpf(camera.position.z, _zoom, w)
	camera.look_at_from_position(camera.position, Vector3(desired_x, desired_y * 0.42, 0.0), Vector3.UP)


func _apply_instant() -> void:
	_zoom = _required_zoom()
	camera.position = Vector3(_frame_center_x, _target_y, _zoom)
	camera.look_at_from_position(camera.position, Vector3(_frame_center_x, _target_y * 0.42, 0.0), Vector3.UP)


func _required_zoom() -> float:
	## Pull back enough that the whole play field fits horizontally for the
	## current viewport aspect (responsive on phones in landscape/portrait).
	# NOTE: this class extends Node (not Node3D), so get_viewport() is only
	# valid once the node is in the tree; fall back to the root window size.
	var vp_size := Vector2.ZERO
	var vp := get_viewport()
	if vp != null:
		vp_size = vp.get_visible_rect().size
	if vp_size == Vector2.ZERO:
		var win_size := DisplayServer.window_get_size()
		vp_size = Vector2(win_size.x, win_size.y)
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		vp_size = Vector2(1280.0, 720.0)  # headless-safe fallback
	var aspect: float = vp_size.x / maxf(vp_size.y, 1.0)
	var fov_h_est: float = deg_to_rad(camera.fov) * maxf(aspect, 0.75)
	var need: float = (_frame_half_width + 2.0) / tan(fov_h_est * 0.5)
	return clampf(maxf(need, 14.0), 12.0, 46.0)
