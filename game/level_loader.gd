extends RefCounted
class_name LevelLoader
## Loads level JSON with a small search path:
##
##   1. res://generated/levels.json   (written by the Go tool in CI / build.sh)
##   2. user://generated/levels.json  (web export: generated/ is filtered out
##      of .pck files, so build_web.sh copies it into the user dir at runtime —
##      actually it is bundled via an unfiltered export; this is the fallback)
##   3. res://data/levels.json        (committed fallback for pure-Godot runs)
##
## Anything produced by Go and anything committed to the repo goes through the
## SAME validator, so a malformed data file fails loudly with [GO DATA] logs.

const CANDIDATES := [
	"res://generated/levels.json",
	"user://levels_generated.json",
	"res://data/levels.json",
]


static func load_levels() -> Dictionary:
	## Returns {"ok": bool, "source": String, "levels": Array, "error": String}
	for path in CANDIDATES:
		if not FileAccess.file_exists(path):
			Log.go_data("candidate not present: %s" % path)
			continue
		var raw := _read_json(path)
		if raw == null:
			continue
		var check := LevelData.validate(raw)
		if not check.ok:
			Log.error("GO DATA", "validation failed for %s: %s" % [path, check.error])
			return {"ok": false, "source": path, "levels": [], "error": check.error}
		var meta: Variant = raw.get("meta", null)
		var generator: String = "unknown"
		if typeof(meta) == TYPE_DICTIONARY:
			generator = str(meta.get("generator", "unknown"))
		Log.go_data("loaded %d level(s) from %s (generator: %s)" % [check.levels.size(), path, generator])
		return {"ok": true, "source": path, "levels": check.levels, "error": ""}
	var msg := "no level data found (checked: %s)" % ", ".join(CANDIDATES)
	Log.error("GO DATA", msg)
	return {"ok": false, "source": "", "levels": [], "error": msg}


static func _read_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		Log.error("GO DATA", "cannot open %s (err=%d)" % [path, FileAccess.get_open_error()])
		return null
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		Log.error("GO DATA", "%s is not valid JSON" % path)
		return null
	return parsed
