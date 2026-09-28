extends Node3D
class_name GameWorld
## Builds the entire 3D play field at runtime: ground, slingshot, structures,
## targets and the armed projectile. Owns all pointer input (mouse + touch)
## and converts it to world-space drag via camera raycasts.
##
## Physics note: nothing here animates the ball. After `Projectile.fire()`
## the RigidBody3D is exclusively driven by Godot's 3D physics engine.

signal shot_finished()            # current ball settled / went OOB
signal target_destroyed(points: int)
signal empty_shot_resolved()      # reserved for future per-shot stats

var level: Level = null
var state: GameState = null
var launcher: Launcher = null
var camera_ctrl: CameraController = null
var trajectory: TrajectoryPreview = null
var audio: AudioManager = null

var bodies: Array[RigidBody3D] = []          # everything settle-detection watches
var targets_alive: Array[Target] = []
var current_ball: Projectile = null

var _world_root: Node3D = null
var _settle_timer: float = 0.0
var _settling: bool = false


func _init(parent: Node, p_level: Level, p_state: GameState, p_audio: AudioManager) -> void:
	name = "GameWorld"
	level = p_level
	state = p_state
	audio = p_audio

	_world_root = Node3D.new()
	_world_root.name = "WorldRoot"
	add_child(_world_root)

	_world_root.add_child(Theme3D.build_environment())
	_world_root.add_child(Theme3D.build_sun())
	_build_ground()

	launcher = Launcher.new(_world_root, level.launcher_position)
	launcher.released.connect(_on_launch)
	trajectory = TrajectoryPreview.new(_world_root)
	camera_ctrl = CameraController.new(self)

	var built := level.build(_world_root)
	for s in built["structures"]:
		bodies.append(s)
	for t in built["targets"]:
		targets_alive.append(t)
		bodies.append(t)
		t.destroyed.connect(_on_target_destroyed)

	var b := level.bounds()
	camera_ctrl.frame_level(level.launcher_position, b["center_x"], b["span_x"])
	Log.boot("world ready: %d rigid bodies, %d targets" % [bodies.size(), targets_alive.size()])


func start() -> void:
	_arm_next_projectile()


# --- projectile lifecycle ------------------------------------------------------

func _arm_next_projectile() -> void:
	current_ball = Projectile.new()
	current_ball.name = "Projectile"
	_world_root.add_child(current_ball)
	current_ball.arm(launcher.cup_position)
	current_ball.bounced.connect(func(strength: float): audio.play_bounce(strength))
	bodies.append(current_ball)
	launcher.refresh_bands(current_ball.global_position)
	state.state = GameState.State.AIMING
	Log.level("projectile armed (%d left)" % state.projectiles_remaining)


func _on_launch(velocity: Vector3) -> void:
	if current_ball == null or state.state != GameState.State.AIMING:
		return
	trajectory.hide()
	current_ball.fire(velocity)
	state.spend_projectile()
	state.state = GameState.State.FLYING
	camera_ctrl.follow(current_ball)
	audio.play_launch(clampf(velocity.length() / GameSettings.max_launch_speed, 0.0, 1.0))
	_settling = false


func _on_shot_over() -> void:
	_settling = false
	camera_ctrl.unfollow()
	if state.remaining_targets() <= 0:
		state.win()
	elif not state.has_projectiles():
		state.lose()
	else:
		if is_instance_valid(current_ball):
			bodies.erase(current_ball)
			current_ball.queue_free()
		current_ball = null
		launcher.refresh_bands(launcher.cup_position)
		_arm_next_projectile()
	emit_signal("shot_finished")


# --- settle detection (physics-driven end-of-shot) ------------------------------

func _physics_process(delta: float) -> void:
	match state.state:
		GameState.State.FLYING:
			if current_ball != null and not current_ball.in_flight:
				return
			if _everything_slow():
				_settling = true
				_settle_timer = 0.0
		GameState.State.SETTLING:
			_settle_timer += delta
			if _everything_slow():
				if _settle_timer >= GameSettings.settle_time_seconds:
					_on_shot_over()
			else:
				_settling = false
				state.state = GameState.State.FLYING


func _everything_slow() -> bool:
	for b in bodies:
		if not is_instance_valid(b):
			continue
		if b is Target and (b as Target).is_destroyed:
			continue
		if b is Projectile and not (b as Projectile).in_flight:
			continue
		if b is RigidBody3D and b.freeze:
			continue
		if b.get_global_linear_velocity().length() > GameSettings.settle_speed_threshold:
			return false
	return true


func _on_target_destroyed(target: Target) -> void:
	targets_alive.erase(target)
	state.register_target_destroyed(target.points)
	audio.play_target_pop()
	emit_signal("target_destroyed", target.points)
	if state.remaining_targets() <= 0 and state.state == GameState.State.SETTLING:
		_settle_timer = maxf(_settle_timer, GameSettings.settle_time_seconds - 0.6)


# --- environment -----------------------------------------------------------------

func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	ground.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(240, 2, 80)
	cs.shape = box
	cs.position = Vector3(40, -1.0, 0)
	ground.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = Theme3D.box(Vector3(240, 2, 80), Theme3D.GROUND)
	mi.position = Vector3(40, -1.0, 0)
	ground.add_child(mi)
	_world_root.add_child(ground)
	Log.physics("static ground body created (layer 1)")


# --- input (mouse + touch; keyboard never required) --------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if state.state != GameState.State.AIMING or current_ball == null:
		return
	var pos: Variant = null
	var pressed := false
	var released := false
	if event is InputEventScreenTouch:
		pressed = event.pressed
		released = not event.pressed
		pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		released = not event.pressed
		pos = event.position
	elif event is InputEventMouseMotion:
		pos = event.position
	if pos == null:
		return
	audio.unlock_from_gesture()
	if pressed:
		var wp := _pointer_world(pos as Vector2)
		if wp != null and wp.distance_to(current_ball.global_position) <= maxf(current_ball.radius * 3.0, 1.4):
			launcher.begin_drag()
			get_viewport().set_input_as_handled()
	elif launcher.dragging:
		if released:
			launcher.end_drag()
			trajectory.hide()
		else:
			var wp2 := _pointer_world(pos as Vector2)
			if wp2 != null:
				launcher.update_drag(wp2)
				var ball_pos := launcher.loaded_ball_position()
				current_ball.global_position = ball_pos
				launcher.refresh_bands(ball_pos)
				trajectory.show_from(ball_pos, Launcher.pull_to_velocity(launcher.current_pull),
						GameSettings.gravity_scale)
		get_viewport().set_input_as_handled()


func _pointer_world(screen_pos: Vector2) -> Variant:
	var cam := camera_ctrl.camera
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if absf(dir.z) < 1e-5:
		return null
	var t := -from.z / dir.z
	if t < 0.0:
		return null
	return from + dir * t


# --- restart support -----------------------------------------------------------------

func teardown() -> void:
	if trajectory:
		trajectory.hide()
	for c in _world_root.get_children():
		c.queue_free()
	bodies.clear()
	targets_alive.clear()
	current_ball = null
	launcher = null
