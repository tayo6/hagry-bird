extends Node
class_name Game
## Root game object: wires GameState + Go-generated level data + world + HUD.
## Spawned by bootstrap.gd; everything below it is created in code.

var state: GameState = null
var api: ApiClient = null
var audio: AudioManager = null
var hud: Hud = null
var world: GameWorld = null

var _levels: Array = []
var _level_index: int = 0


func _init(levels: Array) -> void:
	name = "Game"
	_levels = levels


func _ready() -> void:
	state = GameState.new()
	state.name = "GameState"
	add_child(state)

	api = ApiClient.new()
	api.name = "ApiClient"
	add_child(api)

	audio = AudioManager.new()
	audio.name = "AudioManager"
	add_child(audio)

	hud = Hud.new(self)
	hud.name = "Hud"
	hud.bind(state)
	hud.restart_button.pressed.connect(restart_level)
	hud.sound_toggle.toggled.connect(
			func(on: bool): AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not on))

	if _levels.is_empty():
		Log.error("BOOT", "no levels supplied to Game - showing error UI")
		hud._show_banner("NO LEVEL DATA", Color(1, 0.3, 0.3))
		hud.set_hint("Run tools/levelgen (see README) and rebuild.")
		return
	_load_current_level()


func _load_current_level() -> void:
	var data: Dictionary = _levels[_level_index]
	var lvl := Level.from_dict(data)
	Log.level("loading '%s' (%s) from %s data" % [lvl.display_name, lvl.id, "Go-generated"])
	world = GameWorld.new(self, lvl, state, audio)
	world.name = "GameWorld"
	state.begin_level(lvl.targets.size(), lvl.projectile_count)
	add_child(world)   # _ready populates targets/projectile once in the tree
	world.start()      # no-op while population is pending; safe either way
	Log.boot("game running: level %d/%d" % [_level_index + 1, _levels.size()])


func restart_level() -> void:
	Log.boot("restart requested")
	if world != null:
		world.queue_free()
		world = null
	# Rebuild fresh next frame so queue_free() completes cleanly.
	call_deferred("_rebuild_after_clear")


func _rebuild_after_clear() -> void:
	if _levels.is_empty():
		return
	_load_current_level()


## Test hook used by tests/smoke.gd (headless): deterministically resolves the
## current shot without waiting for real physics to settle. `win` destroys all
## targets; otherwise the remaining ammo is drained and the shot ends.
func debug_finish_shot(win: bool) -> void:
	if win:
		for t in world.targets_alive.duplicate():
			t.try_destroy("debug")
	else:
		# Lose path: drain all remaining ammo so _on_shot_over cannot arm a
		# fresh projectile and flip back to AIMING.
		state.projectiles_remaining = 0
	world._on_shot_over()
