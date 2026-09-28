extends RefCounted
class_name Theme3D
## Procedural look & feel for SHAPESHOT.
##
## No external art assets: every material/mesh is created in code with flat
## stylised colours, which keeps the web build tiny and avoids texture imports.

# palette ---------------------------------------------------------------------
const GROUND := Color(0.36, 0.62, 0.36)
const PLATFORM := Color(0.78, 0.72, 0.60)
const SKY_TOP := Color(0.35, 0.62, 0.88)
const SKY_BOTTOM := Color(0.78, 0.90, 0.96)
const WOOD := Color(0.55, 0.36, 0.20)
const STONE := Color(0.62, 0.63, 0.66)
const GLASS := Color(0.62, 0.85, 0.92)
const RUBBER := Color(0.35, 0.30, 0.45)
const TARGET_A := Color(0.95, 0.35, 0.25)
const TARGET_B := Color(0.98, 0.75, 0.20)
const PROJECTILE_A := Color(0.93, 0.25, 0.28)
const PROJECTILE_B := Color(0.98, 0.96, 0.92)
const FORK_POST := Color(0.45, 0.30, 0.16)
const BAND := Color(0.16, 0.12, 0.10)

static var _mat_cache: Dictionary = {}


## Matte standard material (cached, shared across instances).
static func mat(color: Color, roughness: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%f_%f" % [color.to_html(), roughness, metallic]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache[key] = m
	return m


static func emissive_mat(color: Color, energy: float = 0.6) -> StandardMaterial3D:
	var m := mat(color, 0.5)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


# primitive builders ------------------------------------------------------------

static func make_mesh_instance(mesh: Mesh, material: Material, xform: Transform3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.transform = xform
	return mi


static func box(size: Vector3, color: Color) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	b.material = mat(color)
	return b


static func cylinder(radius: float, height: float, color: Color) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.material = mat(color)
	return c


static func sphere(radius: float, color: Color) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_steps = 16
	s.rings = 10
	s.material = mat(color)
	return s


## Simple two-tone ball: white sphere with a red stripe band around it.
static func make_projectile_mesh(radius: float) -> Node3D:
	var root := Node3D.new()
	root.name = "BallVisual"
	var body := MeshInstance3D.new()
	body.mesh = sphere(radius, PROJECTILE_B)
	root.add_child(body)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.86
	torus.outer_radius = radius * 1.02
	torus.rings = 16
	torus.ring_segments = 24
	ring.mesh = torus
	ring.material_override = mat(PROJECTILE_A, 0.6)
	ring.rotation_degrees = Vector3(90, 0, 0)
	root.add_child(ring)
	return root


## Environment (sky + ambient + fog + tonemap) built procedurally.
static func build_environment() -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY_TOP
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.98, 0.94)
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = SKY_BOTTOM
	env.fog_density = 0.006
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = false

	var we := WorldEnvironment.new()
	we.environment = env
	return we


static func build_sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	return sun
