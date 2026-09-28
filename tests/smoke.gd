extends SceneTree
## Headless smoke test — run with:
##   godot --headless --path . --script tests/smoke.gd
##
## Exit code 0 = all checks passed, 1 = failure. Used by scripts/test.sh and
## the GitHub Actions workflow BEFORE the web export happens.
##
## Checks (no rendering, no window, no editor):
##   1. project boots: main.tscn -> bootstrap.gd -> Game node exists
##   2. Go-generated level JSON loads through the same validator the game uses
##   3. world is built programmatically (ground, launcher, structures, targets)
##   4. GameState transitions AIMING -> WON (win path) and -> LOST (lose path)
##   5. ApiClient works fully offline (disabled short-circuit, no crash)
##   6. TrajectoryPreview math produces sane ballistic points

const EXPECTED_SCRIPTS := [
	"res://game/bootstrap.gd", "res://game/game.gd", "res://game/game_world.gd",
	"res://game/launcher.gd", "res://game/projectile.gd", "res://game/structure.gd",
	"res://game/target.gd", "res://game/level.gd", "res://game/camera_controller.gd",
	"res://game/game_state.gd", "res://game/api_client.gd",
]

var _failures: int = 0


func _initialize() -> void:
	_run()


## `_initialize` cannot await, so the actual checks live in an async helper.
## Every failure path calls quit(1); reaching the end calls quit(0).
func _run() -> void:
	print("[BOOT] === smoke test start (headless) ===")
	var ok := true
	for s in EXPECTED_SCRIPTS:
		if ResourceLoader.exists(s):
			print("[BOOT] ok script: %s" % s)
		else:
			printerr("[BOOT] MISSING script: %s" % s)
			ok = false
	if not ok:
		_finish(false)
		return

	# Boot the real game exactly like the main scene would.
	var main_scene := load("res://main.tscn")
	if main_scene == null:
		_finish(false)
		return
	root.add_child(main_scene.instantiate())
	await process_frame
	await process_frame

	var game_node := root.get_child(root.get_child_count() - 1)
	var game: Node = game_node.get_node_or_null("Game")
	if game == null:
		printerr("[BOOT] FAIL: bootstrap did not create a Game node")
		_finish(false)
		return
	print("[BOOT] ok: Game node created by bootstrap.gd")

	# --- level data pipeline -------------------------------------------------
	var loaded: Dictionary = LevelLoader.load_levels()
	if not loaded.ok or loaded.levels.is_empty():
		printerr("[GO DATA] FAIL: level loading failed: %s" % loaded.error)
		_finish(false)
		return
	print("[GO DATA] ok: levels loaded from %s (%d level(s))" % [loaded.source, loaded.levels.size()])

	# --- world contents --------------------------------------------------------
	var world: Node = game.get_node_or_null("GameWorld")
	if world == null:
		printerr("[BOOT] FAIL: GameWorld missing")
		_finish(false)
		return
	var expected_targets: int = loaded.levels[0]["targets"].size()
	if world.targets_alive.size() != expected_targets:
		printerr("[LEVEL] FAIL: expected %d targets, found %d" % [expected_targets, world.targets_alive.size()])
		_finish(false)
		return
	if world.launcher == null or world.camera_ctrl == null:
		printerr("[LEVEL] FAIL: launcher/camera not built")
		_finish(false)
		return
	print("[LEVEL] ok: world has %d target(s), launcher, camera, %d rigid body watcher(s)" % [world.targets_alive.size(), world.bodies.size()])

	# --- state machine: win path -----------------------------------------------
	var state: Node = game.get_node("GameState")
	if state.state != GameState.State.AIMING:
		printerr("[BOOT] FAIL: expected AIMING at start, got %s" % state.state_name(state.state))
		_finish(false)
		return
	game.debug_finish_shot(true)
	if state.state != GameState.State.WON:
		printerr("[BOOT] FAIL: expected WON after clearing targets, got %s" % state.state_name(state.state))
		_finish(false)
		return
	if state.score <= 0:
		printerr("[BOOT] FAIL: winning produced score %d" % state.score)
		_finish(false)
		return
	print("[BOOT] ok: win path works (score=%d)" % state.score)

	# --- restart + lose path -----------------------------------------------------
	game.restart_level()
	await process_frame
	await process_frame
	await process_frame   # rebuild happens via call_deferred -> needs an extra frame
	world = game.world
	state = game.get_node("GameState")
	if state.state != GameState.State.AIMING:
		printerr("[BOOT] FAIL: restart did not return to AIMING")
		_finish(false)
		return
	print("[BOOT] ok: restart returns to AIMING with fresh world")
	game.debug_finish_shot(false)
	if state.state != GameState.State.LOST:
		printerr("[BOOT] FAIL: expected LOST when out of balls, got %s" % state.state_name(state.state))
		_finish(false)
		return
	print("[BOOT] ok: lose path works")

	# --- API client offline behaviour ---------------------------------------------
	var api: Node = game.get_node("ApiClient")
	api.check_health()
	api.fetch_levels()
	api.submit_score("level_1", 42, true)
	await process_frame
	if api.is_enabled():
		print("[API] note: backend enabled; skipping offline assertions")
	else:
		print("[API] ok: ApiClient short-circuits cleanly while disabled")

	# --- trajectory math -------------------------------------------------------------
	# Launch from ground level with an upward velocity: the arc must rise to an
	# apex above the origin, then fall back and terminate at the ground clamp
	# (y ~ 0). Asserting "last point below first point" is physically wrong for
	# a ground launch, since the final dot is clamped onto y=0.02.
	var pts := TrajectoryPreview.simulate_points(Vector3.ZERO, Vector3(20, 10, 0), 1.0)
	var apex_y := 0.0
	for p in pts:
		apex_y = maxf(apex_y, p.y)
	var last := pts[pts.size() - 1]
	if pts.size() < 5 or apex_y <= 1.0 or last.y >= apex_y:
		printerr("[PHYSICS] FAIL: trajectory preview looks wrong (%d points, apex=%.2f, last_y=%.2f)" % [pts.size(), apex_y, last.y])
		_finish(false)
		return
	print("[PHYSICS] ok: trajectory simulation yields %d points (apex=%.2f, lands y=%.2f)" % [pts.size(), apex_y, last.y])

	_finish(_failures == 0)


func _finish(ok: bool) -> void:
	if ok:
		print("[BOOT] === smoke test PASSED ===")
	else:
		printerr("[BOOT] === smoke test FAILED ===")
	_failures = 0 if ok else 1
	quit(0 if ok else 1)
