extends RigidBody3D
class_name Structure
## A physics block (wood / stone / glass / rubber). Structures form the tower;
## when knocked hard enough they topple under real rigid-body simulation.

signal damaged(material: String, impact_speed: float)

const MATERIAL_DEFAULTS := {
	"wood":   {"mass": 6.0,  "restitution": 0.18, "friction": 0.9,  "color": Theme3D.WOOD},
	"stone":  {"mass": 14.0, "restitution": 0.08, "friction": 1.0,  "color": Theme3D.STONE},
	"glass":  {"mass": 3.5,  "restitution": 0.12, "friction": 0.55, "color": Theme3D.GLASS},
	"rubber": {"mass": 4.5,  "restitution": 0.55, "friction": 1.1,  "color": Theme3D.RUBBER},
}

var block_material: String = "wood"
var half_size: Vector3 = Vector3(0.4, 1.0, 0.4)


func _ready() -> void:
	var defs: Dictionary = MATERIAL_DEFAULTS.get(block_material, MATERIAL_DEFAULTS["wood"])
	mass = float(defs["mass"]) * (half_size.x * half_size.y * half_size.z * 2.0 / 0.32)
	mass = maxf(mass, 0.5)
	collision_layer = 4   # structures
	collision_mask = 1 | 2 | 4 | 8
	can_sleep = true
	continuous_cd = true
	material = _physics_material(float(defs["friction"]), float(defs["restitution"]))
	_build_shape()
	_build_visual(Color(defs["color"]))


static func create(parent: Node, kind: String, position: Vector3, size: Vector3) -> Structure:
	## Factory used by Level: `size` is the FULL box size (metres).
	var s := Structure.new()
	s.block_material = kind if MATERIAL_DEFAULTS.has(kind) else "wood"
	s.half_size = size * 0.5
	s.name = "Structure_%s" % kind
	parent.add_child(s)
	s.global_position = position + Vector3(0, size.y * 0.5, 0)
	return s


func settle_speed() -> float:
	return global_linear_velocity.length()


func _build_shape() -> void:
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var shape := BoxShape3D.new()
	shape.size = half_size * 2.0
	cs.shape = shape
	add_child(cs)


func _build_visual(color: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Visual"
	mi.mesh = Theme3D.box(half_size * 2.0, color)
	add_child(mi)


func _physics_material(friction: float, bounce: float) -> PhysicsMaterial:
	var m := PhysicsMaterial.new()
	m.bounce = bounce
	m.friction = friction
	return m
