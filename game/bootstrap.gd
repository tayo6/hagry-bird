extends Node
## Bootstrap: the ONLY script attached in main.tscn.
##
## Responsibilities (kept tiny on purpose):
##   1. apply optional runtime overrides (CI smoke tests use this)
##   2. load + validate level JSON produced by the Go tool
##      (res://generated/levels.json, falling back to res://data/levels.json)
##   3. hand control to Game, which builds the whole world programmatically
##
## Nothing here needs the Godot editor. Run headless with:
##   godot --headless --path .                 (play locally)
##   godot --headless --path . --script tests/smoke.gd   (CI validation)

const GAME_SCRIPT := "res://game/game.gd"


func _ready() -> void:
	Log.boot("=== SHAPESHOT bootstrap (code-first build, no editor) ===")
	GameSettings.load_overrides()

	var result: Dictionary = LevelLoader.load_levels()
	if not result.ok:
		Log.error("BOOT", "level loading failed: %s" % result.error)
		Log.export_tag("aborting - generated/levels.json missing or invalid; run scripts/build.sh")
		# Still start the game class so the HUD can show the error banner.
		result.levels = []

	var game: Node = load(GAME_SCRIPT).new(result.levels)
	add_child(game)
	Log.boot("bootstrap complete -> handing over to Game node")
