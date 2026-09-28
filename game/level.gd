extends RefCounted
class_name Level
## Turns one validated level dictionary (from the Go-generated JSON) into
## concrete world nodes. Pure placement logic: no gameplay rules here.
##
## Field names mirror tools/levelgen exactly:
##   id, name, projectiles, launcher.position, structures[], targets[]

var id: String = ""
var display_name: String = ""
var projectile_count: int = GameSettings.default_projectile_count
var launcher_position: Vector3 = Vector3(-8, 0, 0)
var structures: Array[Dictionary] = []
var targets: Array[Dictionary] = []


static func from_dict(data: Dictionary) -> Level:
	var lv := Level.new()
	lv.id = str(data.get("id", "level"))
	lv.display_name = str(data.get("name", lv.id))
	lv.projectile_count = int(data.get("projectiles", GameSettings.default_projectile_count))
	lv.launcher_position = _vec3((data.get("launcher", {}) as Dictionary).get("position", [0, 0, 0]))
	for s in data.get("structures", []):
		lv.structures.append({
			"kind": str(s.get("kind", "wood")),
			"position": _vec3(s.get("position", [0, 0, 0])),
			"size": _vec3(s.get("size", [0.5, 1.0, 0.5])),
		})
	for t in data.get("targets", []):
		lv.targets.append({
			"position": _vec3(t.get("position", [0, 1, 0])),
			"points": int(t.get("points", GameSettings.target_points)),
		})
	return lv


## Spawn every body of this level into `parent`; returns spawned node arrays
## so GameWorld can wire signals and settle-detection.
func build(parent: Node) -> Dictionary:
	var built_structures: Array[Structure] = []
	var built_targets: Array[Target] = []
	for s in structures:
		built_structures.append(Structure.create(parent, s["kind"], s["position"], s["size"]))
	for t in targets:
		var tgt := Target.create(parent, t["position"], 0.42, int(t["points"]))
		built_targets.append(tgt)
	Log.level("built '%s': %d structure(s), %d target(s), %d projectile(s)" % [
		display_name, built_structures.size(), built_targets.size(), projectile_count])
	return {"structures": built_structures, "targets": built_targets}


## Horizontal extent + center of the play area (for camera framing).
func bounds() -> Dictionary:
	var min_x := launcher_position.x
	var max_x := launcher_position.x
	for s in structures:
		min_x = minf(min_x, s["position"].x - s["size"].x * 0.5)
		max_x = maxf(max_x, s["position"].x + s["size"].x * 0.5)
	for t in targets:
		min_x = minf(min_x, t["position"].x - 0.5)
		max_x = maxf(max_x, t["position"].x + 0.5)
	return {"center_x": (min_x + max_x) * 0.5, "span_x": max_x - min_x, "min_x": min_x, "max_x": max_x}


static func _vec3(v: Variant) -> Vector3:
	if typeof(v) == TYPE_ARRAY and v.size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return Vector3.ZERO
