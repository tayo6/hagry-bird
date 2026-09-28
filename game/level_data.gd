extends RefCounted
class_name LevelData
## Parses + validates the JSON produced by the Go level generator.
##
## The Godot side never edits level content; it only reads what
## tools/levelgen writes into generated/levels.json (see data/levels.json
## for the committed fallback used when the Go step is skipped locally).

const REQUIRED_LEVEL_FIELDS := ["id", "name", "projectiles", "launcher", "structures", "targets"]
const VALID_MATERIALS := ["wood", "stone", "glass", "rubber"]


static func validate(raw: Variant) -> Dictionary:
	## Returns {"ok": bool, "error": String, "levels": Array}
	var result := {"ok": false, "error": "", "levels": []}
	if typeof(raw) != TYPE_DICTIONARY:
		result.error = "root must be a JSON object"
		return result
	if not raw.has("levels") or typeof(raw["levels"]) != TYPE_ARRAY:
		result.error = "missing 'levels' array"
		return result
	var levels: Array = raw["levels"]
	if levels.is_empty():
		result.error = "'levels' array is empty"
		return result
	for i in levels.size():
		var err := _validate_level(levels[i], i)
		if err != "":
			result.error = err
			return result
	result.levels = levels
	result.ok = true
	return result


static func _validate_level(entry: Variant, index: int) -> String:
	var prefix := "levels[%d]" % index
	if typeof(entry) != TYPE_DICTIONARY:
		return "%s: not an object" % prefix
	for field in REQUIRED_LEVEL_FIELDS:
		if not entry.has(field):
			return "%s: missing required field '%s'" % [prefix, field]
	# NOTE: Godot's JSON parser returns every number as TYPE_FLOAT, so we
	# accept int-or-float and require a whole value >= 1 (same semantics the
	# Go validator enforces on its side).
	var proj: Variant = entry["projectiles"]
	if typeof(proj) != TYPE_INT and typeof(proj) != TYPE_FLOAT:
		return "%s: 'projectiles' must be a number >= 1" % prefix
	if float(proj) < 1.0 or float(proj) != float(int(proj)):
		return "%s: 'projectiles' must be an int >= 1" % prefix
	if typeof(entry["structures"]) != TYPE_ARRAY or typeof(entry["targets"]) != TYPE_ARRAY:
		return "%s: 'structures'/'targets' must be arrays" % prefix
	if entry["targets"].is_empty():
		return "%s: level needs at least one target" % prefix
	var launcher: Dictionary = entry["launcher"]
	if not launcher.has("position"):
		return "%s: launcher missing 'position'" % prefix
	for s in entry["structures"]:
		if typeof(s) != TYPE_DICTIONARY:
			return "%s: structure entry is not an object" % prefix
		if not s.has("kind") or not s.has("position"):
			return "%s: structure missing kind/position" % prefix
		if s.has("material") and not VALID_MATERIALS.has(s["material"]):
			return "%s: unknown material '%s'" % [prefix, s["material"]]
	for t in entry["targets"]:
		if typeof(t) != TYPE_DICTIONARY or not t.has("position"):
			return "%s: target missing position" % prefix
	return ""


static func first_level(levels: Array) -> Dictionary:
	return levels[0] if not levels.is_empty() else {}
