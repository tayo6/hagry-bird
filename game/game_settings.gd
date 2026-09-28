extends Node
class_name GameSettings
## Central, tunable configuration for the whole game.
##
## Everything physics/gameplay related lives here so the prototype can be
## tuned from one file (and so future levels can override values from JSON).
## All values are unit-tested / used by Launcher + Projectile.

# --- projectile physics ------------------------------------------------------
static var projectile_mass: float = 2.0            # kg
static var projectile_radius: float = 0.45         # metres
static var gravity_scale: float = 1.0              # multiplier on world gravity
static var restitution: float = 0.42               # bounciness of ball + blocks
static var linear_damp: float = 0.12               # air drag on the ball

# --- launch tuning -----------------------------------------------------------
static var launch_power: float = 13.0              # velocity per metre of drag
static var max_drag_meters: float = 2.6            # how far you can pull back
static var min_launch_speed: float = 3.0           # tap = no launch
static var max_launch_speed: float = 42.0          # safety clamp

# --- gameplay ----------------------------------------------------------------
static var default_projectile_count: int = 3       # overridden by level data
static var target_points: int = 100                # score per destroyed target
static var settle_time_seconds: float = 2.6        # world rest detection window
static var settle_speed_threshold: float = 0.35    # "everything slow" threshold
static var out_of_bounds_y: float = -25.0          # fell off the world
static var out_of_bounds_x: float = 90.0           # flew past the horizon

# --- scoring bonus -------------------------------------------------------------
static var unused_projectile_bonus: int = 500      # per ball left on win

# --- API (optional backend) ----------------------------------------------------
## Leave empty to run fully offline. When set, ApiClient becomes active.
static var api_base_url: String = ""

# --- runtime overrides ---------------------------------------------------------
const OVERRIDES_PATH := "user://settings_overrides.json"

## Allow CI smoke tests to push config through a JSON file
## (`godot --headless --path . -- --overrides <file>`).
static func load_overrides() -> void:
	var args := OS.get_cmdline_user_args()
	var idx := args.find("--overrides")
	if idx == -1 or idx + 1 >= args.size():
		return
	var path: String = args[idx + 1]
	var abs_path := ProjectSettings.globalize_path(path) if not path.begins_with("user://") else path
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		push_warning("[BOOT] overrides file not found: %s" % abs_path)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[BOOT] overrides file is not a JSON object: %s" % abs_path)
		return
	# NOTE: this runs as a *static* function, so instance-style setters like
	# set() cannot be used; we assign each whitelisted static var explicitly.
	var applied: int = 0
	for key in parsed.keys():
		match key:
			"projectile_mass":
				projectile_mass = float(parsed[key]); applied += 1
			"projectile_radius":
				projectile_radius = float(parsed[key]); applied += 1
			"gravity_scale":
				gravity_scale = float(parsed[key]); applied += 1
			"restitution":
				restitution = float(parsed[key]); applied += 1
			"linear_damp":
				linear_damp = float(parsed[key]); applied += 1
			"launch_power":
				launch_power = float(parsed[key]); applied += 1
			"max_drag_meters":
				max_drag_meters = float(parsed[key]); applied += 1
			"default_projectile_count":
				default_projectile_count = int(parsed[key]); applied += 1
			"target_points":
				target_points = int(parsed[key]); applied += 1
			"settle_time_seconds":
				settle_time_seconds = float(parsed[key]); applied += 1
	Log.boot("applied runtime overrides from %s (%d keys)" % [abs_path, applied])
