class_name TableView
extends Node3D
## Builds the 3D machine from the physics world using detailed procedural
## parts, and keeps the moving parts (balls, flippers, lamps, trails, sparks)
## in sync with it. Mapping: physics (x, y) -> local 3D (x, height, -y). The
## whole node is tilted so the playfield really slopes towards the player.

const TILT_DEG := 6.5
const WALL_H := 0.027
const TRAIL_SECONDS := 2.0
const TRAIL_COLS := [
	[Color(1.0, 0.2, 0.03), Color(1.0, 0.55, 0.15)],     # burning orange
	[Color(0.03, 0.45, 1.0), Color(0.3, 0.75, 1.0)],       # electric blue
]

var phys: PinPhysics
var table: Dictionary = {}
var effects_enabled := true
var cam_local := Vector3(0, 1, 1)     # camera position in table space (set by the game)
var score_label: Label3D

var _ball_nodes: Dictionary = {}
var _trails: Dictionary = {}
var _trail_col := 0
var _flip_nodes: Array[Node3D] = []
var _bumper_caps: Array[StandardMaterial3D] = []
var _bumper_rings: Array[MeshInstance3D] = []
var _bumper_lights: Array[OmniLight3D] = []
var _bumper_flash: Array[float] = []
var _sling_mats: Array[StandardMaterial3D] = []
var _sling_flash: Array[float] = [0.0, 0.0]
var _target_mats: Dictionary = {}
var _target_flash: Dictionary = {}
var _inserts: Dictionary = {}
var _insert_on: Dictionary = {}
var _post_mats: Dictionary = {}
var _post_flash: Dictionary = {}
var _lamps: Array[StandardMaterial3D] = []
var _lamp_phase: Array[float] = []
var _lamp_speed: Array[float] = []
var _excite := 0.0
var _time := 0.0
var _floor: ShaderMaterial        # animated playfield art
var _floor_size := Vector2.ONE
var _floor_cz := 0.0
var _floor_balls: Array[Vector4] = []
var _floor_hits: Array[Vector4] = []
var _floor_hit_i := 0
var _flashes: Array[OmniLight3D] = []
var _flash_i := 0
var _hole_mat: StandardMaterial3D
var _hole_light: OmniLight3D
var _hole_pulse := 0.0
var _theme: ParadiseParts         # themed parts, for tables that have them
var _target_lit := {}             # targets that stay lit (table rules)
var _spinner: Node3D
var _spin_speed := 0.0
var _flashers: Array[StandardMaterial3D] = []
var _plunger: Node3D
var _plunger_z := 0.0
var _sparks: Array[CPUParticles3D] = []
var _spark_i := 0

var _m_chrome: StandardMaterial3D
var _m_steel: StandardMaterial3D
var _m_ball: StandardMaterial3D
var _m_rubber: StandardMaterial3D
var _m_rubber_white: StandardMaterial3D
var _m_rubber_red: StandardMaterial3D
var _m_white: StandardMaterial3D
var _m_wood: StandardMaterial3D
var _m_black: StandardMaterial3D
var _m_plastic: StandardMaterial3D
var _m_trail: StandardMaterial3D
var _ball_mesh: SphereMesh
var _screw_mesh: ArrayMesh
var _disc: CylinderMesh
var _bezel: CylinderMesh


func setup(p: PinPhysics, table_def: Dictionary = {}) -> void:
	phys = p
	table = table_def
	rotation.x = deg_to_rad(TILT_DEG)
	_make_materials()
	if table.get("theme", "") == "paradise":
		_theme = ParadiseParts.new(self)
	elif table.get("theme", "") == "alpenglow":
		_theme = AlpenglowParts.new(self)
	elif table.get("theme", "") == "palace":
		_theme = PalaceParts.new(self)
	_build_cabinet()
	_build_plastics()
	_build_segments()
	_build_circles()
	_build_flippers()
	_build_inserts()
	_build_switches()
	_build_lamps()
	_build_features()
	_build_details()
	_build_sparks()


static func to3(v: Vector2, h: float = 0.0) -> Vector3:
	return Vector3(v.x, h, -v.y)


func ball_world(v: Vector2) -> Vector3:
	return to_global(to3(v, PinPhysics.BALL_R))


# ---------------------------------------------------------------- materials

func _mat(col: Color, metallic: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metallic
	m.roughness = rough
	return m


## Translucent-looking coloured plastic lit from inside.
func _lit(col: Color, energy: float) -> StandardMaterial3D:
	var m := _mat(col * 0.75, 0.0, 0.2)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.clearcoat_enabled = true
	m.clearcoat = 0.5
	m.clearcoat_roughness = 0.12
	return m


func _tex(name: String) -> Texture2D:
	if not table.has("id"):
		return null
	return Tables.texture(Tables.dir(table["id"]) + name)


func _make_materials() -> void:
	_m_chrome = _mat(Color(0.9, 0.91, 0.93), 1.0, 0.16)
	_m_steel = _mat(Color(0.72, 0.73, 0.76), 1.0, 0.34)
	_m_ball = _mat(Color(0.95, 0.95, 0.97), 1.0, 0.05)
	_m_rubber = _mat(Color(0.03, 0.03, 0.035), 0.0, 0.8)
	_m_rubber_white = _mat(Color(0.7, 0.7, 0.67), 0.0, 0.6)
	_m_rubber_red = _mat(Color(0.8, 0.06, 0.05), 0.0, 0.5)
	_m_white = _mat(Color(0.82, 0.82, 0.8), 0.0, 0.32)
	_m_white.clearcoat_enabled = true
	_m_white.clearcoat = 0.3
	_m_wood = _mat(Color(0.05, 0.035, 0.03), 0.0, 0.5)
	_m_black = _mat(Color(0.015, 0.015, 0.02), 0.2, 0.35)
	_m_plastic = _mat(Color(0.9, 0.9, 0.9), 0.0, 0.12)
	var ptex := _tex("plastics.jpg")
	if ptex != null:
		_m_plastic.albedo_texture = ptex
		_m_plastic.emission_enabled = true
		_m_plastic.emission_texture = ptex
		_m_plastic.emission_energy_multiplier = 0.05
	else:
		_m_plastic.albedo_color = Color(0.15, 0.2, 0.5)
	_m_plastic.clearcoat_enabled = true
	_m_plastic.clearcoat = 0.4
	_m_plastic.clearcoat_roughness = 0.15
	_m_trail = StandardMaterial3D.new()
	_m_trail.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_m_trail.vertex_color_use_as_albedo = true
	_m_trail.albedo_color = Color(1.35, 1.35, 1.35)
	_m_trail.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_m_trail.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_m_trail.cull_mode = BaseMaterial3D.CULL_DISABLED
	_m_trail.no_depth_test = false
	_ball_mesh = SphereMesh.new()
	_ball_mesh.radius = PinPhysics.BALL_R
	_ball_mesh.height = PinPhysics.BALL_R * 2.0
	_ball_mesh.radial_segments = 64
	_ball_mesh.rings = 32
	_screw_mesh = Parts.lathe(PackedVector2Array([Vector2(0.0032, 0), Vector2(0.0032, 0.0011),
		Vector2(0.0019, 0.002), Vector2(0, 0.0021)]), 12)
	_disc = CylinderMesh.new()
	_disc.top_radius = 0.0068
	_disc.bottom_radius = 0.0068
	_disc.height = 0.0005
	_disc.radial_segments = 20
	_bezel = CylinderMesh.new()
	_bezel.top_radius = 0.0084
	_bezel.bottom_radius = 0.0084
	_bezel.height = 0.0003
	_bezel.radial_segments = 20


func _mesh(mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _mesh(bm, mat, pos, parent)


func _cyl(r: float, h: float, pos: Vector3, mat: Material, parent: Node3D = self, top_r: float = -1.0) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.bottom_radius = r
	cm.top_radius = r if top_r < 0.0 else top_r
	cm.height = h
	cm.radial_segments = 32
	return _mesh(cm, mat, pos, parent)


func _torus(r: float, thick: float, pos: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var tm := TorusMesh.new()
	tm.inner_radius = r - thick
	tm.outer_radius = r + thick
	tm.rings = 32
	tm.ring_segments = 10
	return _mesh(tm, mat, pos, parent)


func _screw(at: Vector2, h: float) -> void:
	_mesh(_screw_mesh, _m_chrome, to3(at, h))


func _seg_box(a: Vector2, b: Vector2, h: float, thick: float, mat: Material, y0: float = 0.0) -> MeshInstance3D:
	var mi := _box(Vector3(a.distance_to(b) + thick * 0.5, h, thick), to3((a + b) * 0.5, y0 + h * 0.5), mat)
	mi.rotation.y = atan2(b.y - a.y, b.x - a.x)
	return mi


func _wire(a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	_mesh(Parts.tube(PackedVector3Array([a, b]), r, 8), mat)


# ---------------------------------------------------------------- cabinet

func _build_cabinet() -> void:
	var W := TableLayout.W
	var H := TableLayout.H
	var art := _tex("playfield.jpg")
	var backglass := _tex("backglass.jpg")
	var pf_size := Vector2(W + 0.01, H + 0.08)
	var pf_center := Vector3(0, 0, -H * 0.5 + 0.03)
	_box(Vector3(pf_size.x, 0.02, pf_size.y), pf_center + Vector3(0, -0.0102, 0), _m_wood)
	# The printed artwork sits on its own sheet so the whole image maps onto
	# the playfield (top of the image = far end of the table).
	# the art is kept a little darker than the parts so obstacles stand out
	var tint: Color = Color(0.74, 0.74, 0.76) * float(table.get("look", {}).get("albedo", 1.0))
	var pf: Material
	if art != null:
		var fl: Dictionary = table.get("floor", {})
		_floor = ShaderMaterial.new()
		_floor.shader = load("res://shaders/floor.gdshader")
		_floor.set_shader_parameter("art", art)
		_floor.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
		_floor.set_shader_parameter("aspect", Vector2(1.0, pf_size.y / pf_size.x))
		for k in fl:
			_floor.set_shader_parameter(k, fl[k])
		_floor_size = pf_size
		_floor_cz = pf_center.z
		for i in 4:
			_floor_balls.append(Vector4.ZERO)
			_floor_hits.append(Vector4(0, 0, 9, 0))
		pf = _floor
	else:
		var plain := _mat(Color(0.08, 0.12, 0.3), 0.0, 0.22)
		plain.clearcoat_enabled = true
		plain.clearcoat = 0.5
		plain.clearcoat_roughness = 0.1
		pf = plain
	var pm := PlaneMesh.new()
	pm.size = pf_size
	_mesh(pm, pf, pf_center)

	# cabinet sides: wood body, steel inner liner, chrome top rail
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.04, 0.1, H + 0.2), Vector3(sx * (W * 0.5 + 0.0215), 0.015, -H * 0.5 + 0.03), _m_wood)
		_box(Vector3(0.0015, 0.06, H + 0.1), Vector3(sx * (W * 0.5 + 0.001), 0.03, -H * 0.5 + 0.02), _m_steel)
		_wire(Vector3(sx * (W * 0.5 + 0.012), 0.066, 0.13), Vector3(sx * (W * 0.5 + 0.012), 0.066, -H - 0.03), 0.006, _m_steel)
	_box(Vector3(W + 0.09, 0.1, 0.03), Vector3(0, 0.015, -H - 0.02), _m_wood)
	# cabinet body with printed side art, standing on four chrome legs
	_box(Vector3(W + 0.09, 0.42, H + 0.2), Vector3(0, -0.245, -H * 0.5 + 0.03), _m_black)
	var body_art := _tex("backglass.jpg")
	if body_art != null:
		var cm2 := _mat(Color(0.7, 0.7, 0.7), 0.0, 0.35)
		cm2.albedo_texture = body_art
		for sx in [-1.0, 1.0]:
			var sq2 := QuadMesh.new()
			sq2.size = Vector2(H + 0.16, 0.38)
			var smi := _mesh(sq2, cm2, Vector3(sx * (W * 0.5 + 0.0462), -0.245, -H * 0.5 + 0.03))
			smi.rotation.y = sx * PI * 0.5
		var fq := QuadMesh.new()
		fq.size = Vector2(W + 0.05, 0.36)
		_mesh(fq, cm2, Vector3(0, -0.25, 0.1312))
	for sx in [-1.0, 1.0]:
		_cyl(0.02, 0.5, Vector3(sx * (W * 0.5 + 0.03), -0.7, 0.1), _m_chrome)
		_cyl(0.02, 0.63, Vector3(sx * (W * 0.5 + 0.03), -0.765, -H - 0.01), _m_chrome)

	# lockdown bar across the front
	var bar := CapsuleMesh.new()
	bar.radius = 0.021
	bar.height = W + 0.13
	var bar_mi := _mesh(bar, _m_steel, Vector3(0, 0.052, 0.118))
	bar_mi.rotation.z = PI * 0.5
	bar_mi.scale = Vector3(0.75, 1, 1.25)
	_box(Vector3(W + 0.09, 0.1, 0.05), Vector3(0, 0.0, 0.125), _m_wood)

	# apron with a notch for the drain, instruction cards and artwork
	var apron := PackedVector2Array([Vector2(-0.255, -0.075), Vector2(0.205, -0.075), Vector2(0.205, 0.04),
		Vector2(0.05, 0.04), Vector2(0.02, 0.02), Vector2(-0.07, 0.02), Vector2(-0.10, 0.04), Vector2(-0.255, 0.04)])
	var am := _mat(Color(0.55, 0.55, 0.6), 0.1, 0.25)
	var atex := _tex("apron.jpg")
	if atex != null:
		am.albedo_texture = atex
	else:
		am.albedo_color = Color(0.03, 0.03, 0.05)
	am.clearcoat_enabled = true
	am.clearcoat = 0.8
	_mesh(Parts.extrude(apron, 0.0, 0.034, 0.003), am)
	for cx in [-0.175, 0.125]:
		var card := PackedVector2Array([Vector2(cx - 0.052, -0.058), Vector2(cx + 0.052, -0.058),
			Vector2(cx + 0.052, 0.012), Vector2(cx - 0.052, 0.012)])
		_mesh(Parts.extrude(card, 0.034, 0.0352, 0.0006), _mat(Color(0.5, 0.5, 0.48), 0.0, 0.5))
		var inner := PackedVector2Array([Vector2(cx - 0.046, -0.052), Vector2(cx + 0.046, -0.052),
			Vector2(cx + 0.046, -0.02), Vector2(cx - 0.046, -0.02)])
		_mesh(Parts.extrude(inner, 0.0352, 0.0356, 0.0), _lit(Color(1.0, 0.45, 0.05) if cx < 0 else Color(0.1, 0.5, 1.0), 0.5))
		_screw(Vector2(cx - 0.047, 0.007), 0.0352)
		_screw(Vector2(cx + 0.047, 0.007), 0.0352)

	# printed instruction cards
	for d in [[-0.175, "%s\n\nSPACE  launch\nSHIFT  flippers\nA D W  nudge" % str(table.get("name", "NUDGE")).to_upper()], [0.125, "SCORING\n\n%s  1,000\nTARGET  500\nTOP LANES  x BONUS" % table.get("saucer", "BLACK HOLE")]]:
		var lbl := Label3D.new()
		lbl.text = d[1]
		lbl.font_size = 40
		lbl.pixel_size = 0.00016
		lbl.modulate = Color(0.05, 0.05, 0.08)
		lbl.outline_size = 0
		lbl.line_spacing = -4.0
		var cfont := Tables.font("Audiowide-Regular")
		if cfont != null:
			lbl.font = cfont
			lbl.font_size = 30
		lbl.position = to3(Vector2(d[0], -0.004), 0.0354)
		lbl.rotation.x = -PI * 0.5
		add_child(lbl)

	# backboard artwork behind the arch and printed blades along the cabinet sides
	var deco := _tex("backglass.jpg")
	if deco != null:
		var dm := _mat(Color(0.55, 0.55, 0.55), 0.0, 0.3)
		dm.albedo_texture = deco
		var bq := QuadMesh.new()
		bq.size = Vector2(W, 0.062)
		_mesh(bq, dm, Vector3(0, 0.031, -H - 0.004))
		for sx in [-1.0, 1.0]:
			var sq := QuadMesh.new()
			sq.size = Vector2(H + 0.06, 0.03)
			var side_mi := _mesh(sq, dm, Vector3(sx * (W * 0.5 - 0.0005), 0.045, -H * 0.5 + 0.02))
			side_mi.rotation.y = -sx * PI * 0.5
	# screws along the top rails
	for sx in [-1.0, 1.0]:
		for k in 9:
			_mesh(_screw_mesh, _m_steel, Vector3(sx * (W * 0.5 + 0.024), 0.065, 0.06 - k * 0.14))

	# shooter lane plunger
	_plunger = Node3D.new()
	_plunger.position = to3(Vector2(0.23, -0.02), PinPhysics.BALL_R)
	_plunger.rotation.x = -PI * 0.5
	_plunger_z = _plunger.position.z
	add_child(_plunger)
	_mesh(Parts.lathe(PackedVector2Array([Vector2(0.0035, -0.08), Vector2(0.0035, 0.066), Vector2(0.0078, 0.066),
		Vector2(0.0078, 0.079), Vector2(0.004, 0.081), Vector2(0, 0.081)]), 16), _m_chrome, Vector3.ZERO, _plunger)

	# backbox with the backlit artwork and the machine score display
	_box(Vector3(W + 0.09, 0.44, 0.08), Vector3(0, 0.28, -H - 0.075), _m_black)
	_box(Vector3(W - 0.04, 0.11, 0.004), Vector3(0, 0.20, -H - 0.033), _mat(Color(0.004, 0.004, 0.006), 0.0, 0.15))
	if backglass != null:
		var qm := QuadMesh.new()
		qm.size = Vector2(0.39, 0.219)
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(0.3, 0.3, 0.3)
		bm.albedo_texture = backglass
		bm.emission_enabled = true
		bm.emission_texture = backglass
		bm.emission_energy_multiplier = 0.7
		_mesh(qm, bm, Vector3(0, 0.38, -H - 0.034))
	score_label = Label3D.new()
	score_label.text = "0"
	score_label.font_size = 96
	score_label.pixel_size = 0.0009
	score_label.modulate = Color(1.0, 0.45, 0.1)
	score_label.outline_size = 0
	score_label.shaded = false
	var sfont := Tables.font("Bungee-Regular")
	if sfont != null:
		score_label.font = sfont
	score_label.position = Vector3(0, 0.20, -H - 0.03)
	add_child(score_label)

	# general-illumination bulbs tucked along the sides
	for d in [[Vector2(-0.24, 0.30), Color(1.0, 0.2, 0.7)], [Vector2(0.19, 0.30), Color(0.1, 0.7, 1.0)],
			[Vector2(-0.24, 0.72), Color(0.2, 0.6, 1.0)], [Vector2(0.19, 0.72), Color(1.0, 0.3, 0.6)],
			[Vector2(-0.025, 0.95), Color(1.0, 0.7, 0.4)]]:
		var l := OmniLight3D.new()
		l.position = to3(d[0], 0.045)
		l.light_color = d[1]
		l.light_energy = 0.16
		l.omni_range = 0.3
		add_child(l)


var _m_glass: StandardMaterial3D
var _m_glass_rim: StandardMaterial3D

func _glass_mat() -> StandardMaterial3D:
	if _m_glass == null:
		_m_glass = _m_plastic.duplicate()
		_m_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_m_glass.albedo_color = Color(1, 1, 1, float(table.get("glass", 0.42)))
		_m_glass.emission_energy_multiplier = 0.03
		_m_glass.roughness = 0.05
		_m_glass.metallic_specular = 0.8
		_m_glass.clearcoat = 1.0
		_m_glass.clearcoat_roughness = 0.03
	return _m_glass


func _glass_rim_mat() -> StandardMaterial3D:
	if _m_glass_rim == null:
		var c: Color = table.get("glass_rim", Color(1.0, 0.85, 0.45))
		_m_glass_rim = _lit(c, 1.6)
	return _m_glass_rim


func _build_plastics() -> void:
	var i := 0
	for entry in TableLayout.plastics():
		var poly: PackedVector2Array = entry[0]
		var bevel: float = entry[1]
		# each cover shows a different part of the plastics art sheet
		var uv := Rect2(0.5 * (i % 2), 0.25 * ((i / 2) % 4), 0.5, 0.25)
		if bevel > 0.0:
			# slingshots and lane covers are tinted clear acrylic, so the floor art shows through
			_mesh(Parts.extrude(poly, 0.0300, 0.0335, bevel, uv), _glass_mat())
			for e in poly.size():
				_seg_box(poly[e], poly[(e + 1) % poly.size()], 0.0014, 0.0018, _glass_rim_mat(), 0.0333)
		else:
			_mesh(Parts.extrude(poly, 0.0285, 0.0300, 0.0), _m_white)
			_mesh(Parts.extrude(poly, 0.0300, 0.0335, bevel, uv), _m_plastic)
		var cen := Vector2.ZERO
		for q in poly:
			cen += q
		cen /= poly.size()
		if poly.size() == 4 and bevel >= 0.003:
			for q2 in poly:
				_cyl(0.003, 0.0285, to3(q2 + (cen - q2).normalized() * 0.014, 0.01425), _m_steel)
		var picks := [0, 1, 2, 3] if poly.size() == 4 else [0, 1, 2] if poly.size() < 4 else [0, 1, poly.size() - 1]
		for k in picks:
			var q: Vector2 = poly[k]
			_screw(q + (cen - q).normalized() * 0.011, 0.0335)
		i += 1


# ---------------------------------------------------------------- colliders

func _build_segments() -> void:
	var K := PinPhysics.Kind
	var wire_ends := {}
	var rubber_ends := {}
	for s in phys.segs:
		match s.kind:
			K.GATE:
				_wire(to3(s.a, 0.02), to3(s.b, 0.02), 0.0012, _m_chrome)
			K.RUBBER, K.SLING:
				_wire(to3(s.a, 0.0135), to3(s.b, 0.0135), 0.0032, _m_rubber_red)
				rubber_ends[s.a] = true
				rubber_ends[s.b] = true
				if s.kind == K.SLING:
					var m := _lit(Color(1.0, 0.2, 0.1), 0.3)
					_sling_mats.append(m)
					_seg_box(s.a, s.b, 0.006, 0.004, m, 0.021)
			K.TARGET:
				_build_target(s)
			_:
				if s.a.distance_to(s.b) > 0.5:
					_seg_box(s.a, s.b, WALL_H, 0.0025, _m_steel)
				else:
					_wire(to3(s.a, 0.017), to3(s.b, 0.017), 0.0017, _m_chrome)
					wire_ends[s.a] = true
					wire_ends[s.b] = true
	# top arch as a steel blade
	if phys.has_arc:
		var n := 56
		for i in n:
			var a0 := PI * i / n
			var a1 := PI * (i + 1) / n
			_seg_box(phys.arc_c + Vector2(cos(a0), sin(a0)) * phys.arc_r,
				phys.arc_c + Vector2(cos(a1), sin(a1)) * phys.arc_r, WALL_H, 0.0025, _m_steel)
	# wire guides stand on small legs
	var ferrule := Parts.lathe(PackedVector2Array([Vector2(0.0034, 0), Vector2(0.0034, 0.0015), Vector2(0.002, 0.003)]), 10)
	for p in wire_ends:
		_wire(to3(p, 0.0), to3(p, 0.017), 0.0017, _m_chrome)
		_mesh(ferrule, _m_steel, to3(p, 0.0))
	# rubber rings are stretched round star posts
	var star := Parts.lathe(_post_profile(0.0055), 16)
	for p in rubber_ends:
		_mesh(star, _mat(Color(0.1, 0.5, 1.0), 0.0, 0.25), to3(p, 0.0))
		_screw(p, 0.031)


func _build_target(s: PinPhysics.Seg) -> void:
	if _theme != null:
		_target_mats[s.id] = _theme.surfboard(s) if s.id < 5 else _theme.shell_target(s)
		_target_flash[s.id] = 0.0
		return
	var cols := [Color(1.0, 0.8, 0.1), Color(1.0, 0.3, 0.1), Color(0.1, 0.8, 1.0), Color(0.45, 1.0, 0.25),
		Color(1.0, 0.15, 0.6), Color(0.6, 0.35, 1.0)]
	var m := _lit(cols[s.id % cols.size()], 0.08)
	_target_mats[s.id] = m
	_target_flash[s.id] = 0.0
	var plen := s.a.distance_to(s.b)
	_seg_box(s.a, s.b, 0.026, 0.0022, _m_white, 0.003)
	_seg_box(s.a.lerp(s.b, 0.08), s.a.lerp(s.b, 0.92), 0.02, 0.0042, m, 0.006)
	_seg_box(s.a, s.b, 0.005, 0.007, _m_steel, 0.0).scale.x = 0.7
	_seg_box(s.a.lerp(s.b, 0.25), s.a.lerp(s.b, 0.75), 0.0018, 0.006, _m_chrome, 0.027)
	if plen > 0.03:
		_screw(s.a.lerp(s.b, 0.5), 0.0288)


func _post_profile(r: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(r * 0.95, 0), Vector2(r * 0.95, 0.003), Vector2(r * 0.6, 0.0045),
		Vector2(r * 0.6, 0.010), Vector2(r * 0.8, 0.011), Vector2(r * 0.8, 0.017), Vector2(r * 0.6, 0.018),
		Vector2(r * 0.6, 0.024), Vector2(r * 0.9, 0.026), Vector2(r * 0.9, 0.029), Vector2(r * 0.55, 0.031), Vector2(0, 0.031)])


func _build_circles() -> void:
	var K := PinPhysics.Kind
	var cols := [Color(1.0, 0.2, 0.08), Color(1.0, 0.8, 0.05), Color(1.0, 0.12, 0.55), Color(1.0, 0.5, 0.1),
		Color(0.95, 0.75, 0.3), Color(0.1, 0.8, 1.0), Color(0.45, 1.0, 0.25), Color(0.6, 0.3, 1.0)]
	var post_cols := [Color(0.1, 0.6, 1.0), Color(1.0, 0.15, 0.7), Color(0.25, 1.0, 0.45), Color(1.0, 0.8, 0.1),
		Color(1.0, 0.4, 0.1), Color(0.6, 0.35, 1.0)]
	cols = table.get("bumper_cols", cols)
	for c in phys.circs:
		var r := c.r
		if c.kind == K.BUMPER:
			var col: Color = cols[c.id % cols.size()]
			var root := Node3D.new()
			root.position = to3(c.c, 0.0)
			add_child(root)
			if _theme != null:
				var kinds: Array = table.get("bumper_kinds", ["beach"])
				var kind: String = kinds[c.id % kinds.size()]
				var res: Array = _theme.bumper(c, kind, root)
				_bumper_caps.append(res[0])
				_bumper_rings.append(res[1])
				var tl := OmniLight3D.new()
				tl.light_color = Color(1.0, 0.95, 0.9) if kind == "beach" else Color(1.0, 0.6, 0.25)
				tl.light_energy = 0.03
				tl.omni_range = 0.24
				tl.position = Vector3(0, 0.085, 0)
				root.add_child(tl)
				_bumper_lights.append(tl)
				_bumper_flash.append(0.0)
				continue
			_cyl(r * 1.36, 0.0008, Vector3(0, 0.0004, 0), _m_black, root)
			# skirt, body, kicker ring, cap and centre button
			_mesh(Parts.lathe(PackedVector2Array([Vector2(r * 1.2, 0.0005), Vector2(r * 1.2, 0.003),
				Vector2(r * 0.98, 0.0065), Vector2(r * 0.8, 0.0065)]), 40), _m_white, Vector3.ZERO, root)
			_mesh(Parts.lathe(PackedVector2Array([Vector2(r * 0.8, 0.0065), Vector2(r * 0.8, 0.027)]), 40),
				_m_white, Vector3.ZERO, root)
			var rib := _mat(col, 0.0, 0.3)
			var ring := _torus(r * 1.0, 0.0022, Vector3(0, 0.014, 0), _m_chrome, root)
			_bumper_rings.append(ring)
			var capm := _lit(col, 0.08)
			_mesh(Parts.lathe(PackedVector2Array([Vector2(r * 0.8, 0.027), Vector2(r * 1.22, 0.029),
				Vector2(r * 1.27, 0.0325), Vector2(r * 1.2, 0.036), Vector2(r * 0.95, 0.0385),
				Vector2(r * 0.5, 0.0398)]), 48), capm, Vector3.ZERO, root)
			_mesh(Parts.lathe(PackedVector2Array([Vector2(r * 0.5, 0.0398), Vector2(r * 0.5, 0.0412),
				Vector2(r * 0.4, 0.0424), Vector2(0, 0.0428)]), 32), _m_white, Vector3.ZERO, root)
			_torus(r * 0.86, 0.0012, Vector3(0, 0.0388, 0), _m_white, root)
			_torus(r * 1.12, 0.0009, Vector3(0, 0.0352, 0), _m_white, root)
			for k2 in 10:
				var sa := TAU * k2 / 10.0
				var stripe := _box(Vector3(r * 0.42, 0.0006, 0.0022), Vector3(cos(sa) * r * 0.78, 0.0383, sin(sa) * r * 0.78), _m_white, root)
				stripe.rotation.y = -sa
			for k in 12:
				var ra := TAU * k / 12.0
				_box(Vector3(0.0026, 0.019, 0.0026), Vector3(cos(ra) * r * 0.82, 0.017, sin(ra) * r * 0.82), rib, root)
			_mesh(_screw_mesh, _m_chrome, Vector3(r * 0.72, 0.0389, 0), root)
			_mesh(_screw_mesh, _m_chrome, Vector3(-r * 0.72, 0.0389, 0), root)
			_bumper_caps.append(capm)
			var l := OmniLight3D.new()
			l.light_color = col
			l.light_energy = 0.15
			l.omni_range = 0.24
			l.position = Vector3(0, 0.06, 0)
			root.add_child(l)
			_bumper_lights.append(l)
			_bumper_flash.append(0.0)
		else:
			var lit := c.id >= TableLayout.POST_ID
			if lit and _theme != null:
				_post_mats[c.id] = _theme.torch(c, post_cols[c.id % post_cols.size()])
				_post_flash[c.id] = 0.0
				continue
			var pm: Material = _m_white
			if lit:
				var lm := _lit(post_cols[c.id % post_cols.size()], 0.1)
				_post_mats[c.id] = lm
				_post_flash[c.id] = 0.0
				pm = lm
			_cyl(r * 1.5, 0.0008, to3(c.c, 0.0004), _m_black)
			_mesh(Parts.lathe(_post_profile(r * 0.82), 20), pm, to3(c.c, 0.0))
			_torus(r * 0.82, 0.0019, to3(c.c, 0.014), _m_rubber_white if lit else _m_rubber)
			_screw(c.c, 0.031)


func _build_flippers() -> void:
	for f in phys.flippers:
		var root := Node3D.new()
		root.position = to3(f.pivot, 0.0)
		add_child(root)
		_mesh(Parts.extrude(Parts.flipper_outline(f.length, 0.0102, 0.0062), 0.004, 0.0215, 0.0028), _mat(Color(1.0, 0.78, 0.05), 0.0, 0.3), Vector3.ZERO, root)
		var band := PackedVector3Array()
		for q in Parts.flipper_outline(f.length, 0.0112, 0.0072, 12):
			band.append(Vector3(q.x, 0.0125, -q.y))
		_mesh(Parts.tube(band, 0.0024, 8, true), _m_rubber_red, Vector3.ZERO, root)
		_mesh(Parts.lathe(PackedVector2Array([Vector2(0.0052, 0.0215), Vector2(0.0052, 0.0236),
			Vector2(0.003, 0.025), Vector2(0, 0.0252)]), 16), _m_chrome, Vector3.ZERO, root)
		_flip_nodes.append(root)


# ---------------------------------------------------------------- lamps

func _lamp(at: Vector2, col: Color, energy: float, r: float = 0.0068) -> StandardMaterial3D:
	if _theme != null:
		return _theme.shell_lamp(at, col, energy, r)
	var m := _lit(col, energy)
	var b := _mesh(_bezel, _m_black, to3(at, 0.0003))
	var d := _mesh(_disc, m, to3(at, 0.0006))
	var k := r / 0.0068
	b.scale = Vector3(k, 1, k)
	d.scale = Vector3(k, 1, k)
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


func _arrow(at: Vector2, dir: Vector2, col: Color) -> StandardMaterial3D:
	if _theme != null:
		return _theme.shell_lamp(at, col, 0.3, 0.0062)
	var m := _lit(col, 0.3)
	var f := dir.normalized()
	var s := Vector2(-f.y, f.x)
	for pass_i in 2:
		var k := 1.25 if pass_i == 0 else 1.0
		var tri := PackedVector2Array([at + f * 0.011 * k, at - f * 0.006 * k - s * 0.008 * k, at - f * 0.006 * k + s * 0.008 * k])
		var mi := _mesh(Parts.extrude(tri, 0.0001, 0.0004 + pass_i * 0.0004, 0.0), _m_black if pass_i == 0 else m)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


func _build_inserts() -> void:
	for s in phys.sensors:
		if s.id in [TableLayout.S_LANE, TableLayout.S_HOLE, TableLayout.S_SPINNER]:
			continue
		var col := Color(0.2, 1.0, 0.5) if s.id < 10 else Color(1.0, 0.5, 0.1)
		if s.id >= 12:
			col = Color(1.0, 0.1, 0.1)
		_inserts[s.id] = _lamp(s.rect.get_center(), col, 0.15, 0.011)
		_insert_on[s.id] = 0.0


func _build_switches() -> void:
	# rollover switch wires poking through the playfield at each lane
	for s in phys.sensors:
		if s.id in [TableLayout.S_LANE, TableLayout.S_HOLE, TableLayout.S_SPINNER]:
			continue
		var c := s.rect.get_center()
		var path := PackedVector3Array([to3(c - Vector2(0, 0.013), 0.0), to3(c - Vector2(0, 0.008), 0.0035),
			to3(c + Vector2(0, 0.008), 0.0035), to3(c + Vector2(0, 0.013), 0.0)])
		_mesh(Parts.tube(path, 0.0007, 6), _m_chrome)


func _add_lamp(m: StandardMaterial3D, phase: float, speed: float) -> void:
	_lamps.append(m)
	_lamp_phase.append(phase)
	_lamp_speed.append(speed)


func _build_lamps() -> void:
	# Playfield lamps that chase and pulse; they also surge on hits.
	if _theme != null:
		_theme.lamps()
		return
	var hole := TableLayout.HOLE
	var xc := TableLayout.XC
	for i in 14:                 # accretion ring around the black hole
		var a := TAU * i / 14.0
		_add_lamp(_lamp(hole + Vector2(cos(a) * 0.105, sin(a) * 0.075), Color(1.0, 0.5, 0.1), 0.3), i * 0.45, 5.0)
	for i in 6:                  # centre shot line from the flippers
		_add_lamp(_arrow(Vector2(xc, 0.23 + i * 0.042), Vector2(0, 1), Color(0.3, 0.8, 1.0)), i * 0.7, 6.0)
	for side in 2:
		var sg := -1.0 if side == 0 else 1.0
		for i in 6:              # diagonal lines towards the planets
			_add_lamp(_arrow(Vector2(xc + sg * (0.03 + i * 0.022), 0.25 + i * 0.03), Vector2(sg * 0.6, 0.8), Color(1.0, 0.3, 0.8)), i * 0.7 + 1.0, 6.0)
		for i in 5:              # orbit entrances
			_add_lamp(_arrow(Vector2(xc + sg * 0.205, 0.44 + i * 0.045), Vector2(0, 1), Color(0.4, 1.0, 0.6)), i * 0.8, 4.0)
		for i in 4:              # arcs above the flippers
			_add_lamp(_lamp(Vector2(xc + sg * (0.05 + i * 0.03), 0.175 + i * 0.012), Color(1.0, 0.85, 0.3), 0.3), i * 0.9, 3.0)
	for i in 9:                  # sun corona under the top lanes
		var a2 := PI * (0.12 + 0.76 * i / 8.0)
		_add_lamp(_lamp(Vector2(xc + cos(a2) * 0.15, 0.845 + sin(a2) * 0.03), Color(1.0, 0.65, 0.1), 0.3), i * 0.5, 7.0)


func _build_features() -> void:
	# black hole saucer: a dark well with a chrome lip and a glowing ring
	var hole := TableLayout.HOLE
	var well := StandardMaterial3D.new()
	well.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	well.albedo_color = Color.BLACK
	_cyl(0.019, 0.0012, to3(hole, 0.0008), well)
	_torus(0.0195, 0.0014, to3(hole, 0.0016), _m_chrome)
	_hole_mat = _lit(Color(1.0, 0.45, 0.05), 2.0)
	_torus(0.024, 0.0022, to3(hole, 0.002), _hole_mat)
	_hole_light = OmniLight3D.new()
	_hole_light.light_color = Color(1.0, 0.5, 0.15)
	_hole_light.light_energy = 0.4
	_hole_light.omni_range = 0.3
	_hole_light.position = to3(hole, 0.05)
	add_child(_hole_light)

	# spinner in the left orbit lane, hung from a wire bracket
	for s in phys.sensors:
		if s.id == TableLayout.S_SPINNER:
			var c := s.rect.get_center()
			var hw := s.rect.size.x * 0.5
			_spinner = Node3D.new()
			_spinner.position = to3(c, 0.02)
			add_child(_spinner)
			_box(Vector3(hw * 2.0 - 0.014, 0.022, 0.0012), Vector3.ZERO, _lit(Color(0.3, 0.8, 1.0), 1.0), _spinner)
			_wire(to3(c - Vector2(hw - 0.003, 0), 0.02), to3(c + Vector2(hw - 0.003, 0), 0.02), 0.0011, _m_chrome)
			for sx in [-1.0, 1.0]:
				_wire(to3(c + Vector2(sx * (hw - 0.003), 0), 0.0), to3(c + Vector2(sx * (hw - 0.003), 0), 0.032), 0.0014, _m_chrome)

	if _theme != null:
		_theme.features()

	# pooled flash lights for impacts
	for i in 4:
		var l := OmniLight3D.new()
		l.light_energy = 0.0
		l.omni_range = 0.45
		add_child(l)
		_flashes.append(l)


func _build_details() -> void:
	var xc := TableLayout.XC
	# wire arches over the top lanes
	for pair in [[-0.145, -0.065], [-0.065, 0.015], [0.015, 0.095]]:
		var path := PackedVector3Array()
		for i in 9:
			var t := i / 8.0
			path.append(to3(Vector2(lerpf(pair[0], pair[1], t), 0.955), 0.017 + 0.022 * sin(PI * t)))
		_mesh(Parts.tube(path, 0.0011, 6), _m_chrome)
	_wire(to3(Vector2(-0.145, 0.955), 0.0), to3(Vector2(-0.145, 0.955), 0.017), 0.0011, _m_chrome)
	_wire(to3(Vector2(0.095, 0.955), 0.0), to3(Vector2(0.095, 0.955), 0.017), 0.0011, _m_chrome)

	# flasher domes on the plastics; they strobe when the table gets excited
	var dome := Parts.lathe(PackedVector2Array([Vector2(0.012, 0), Vector2(0.0116, 0.004), Vector2(0.0098, 0.0078),
		Vector2(0.0062, 0.0104), Vector2(0, 0.0115)]), 20)
	var spots := [Vector2(xc - 0.13, 0.245), Vector2(xc + 0.13, 0.245), Vector2(xc - 0.145, 0.09), Vector2(xc + 0.145, 0.09),
		Vector2(-0.21, 1.01), Vector2(0.21, 1.01), Vector2(-0.243, 0.385), Vector2(0.193, 0.385)]
	for i in spots.size():
		var m := _lit(Color(1.0, 0.15, 0.1) if i % 2 == 0 else Color(0.1, 0.45, 1.0), 0.1)
		_flashers.append(m)
		_torus(0.0125, 0.0012, to3(spots[i], 0.0338), _m_chrome)
		_mesh(dome, m, to3(spots[i], 0.0335))

	# star rollover buttons
	var star := PackedVector2Array()
	for i in 10:
		var a := PI * i / 5.0
		star.append(Vector2(cos(a), sin(a)) * (0.0075 if i % 2 == 0 else 0.0034))
	for q in [Vector2(xc - 0.06, 0.365), Vector2(xc + 0.06, 0.365), Vector2(xc - 0.2, 0.47), Vector2(xc + 0.2, 0.47),
			Vector2(xc, 0.695), Vector2(xc - 0.05, 0.86), Vector2(xc + 0.05, 0.86)]:
		var pts := PackedVector2Array()
		for v in star:
			pts.append(q + v)
		_cyl(0.0095, 0.0006, to3(q, 0.0003), _m_black)
		_mesh(Parts.extrude(pts, 0.0002, 0.0016, 0.0004), _m_white)


func _build_sparks() -> void:
	var sm := SphereMesh.new()
	sm.radius = 0.0008
	sm.height = 0.0016
	sm.radial_segments = 6
	sm.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(3.0, 1.9, 0.7)
	for i in 10:
		var ps := CPUParticles3D.new()
		ps.mesh = sm
		ps.material_override = mat
		ps.emitting = false
		ps.one_shot = true
		ps.amount = 48
		ps.lifetime = 0.3
		ps.explosiveness = 1.0
		ps.direction = Vector3.UP
		ps.spread = 85.0
		ps.initial_velocity_min = 0.15
		ps.initial_velocity_max = 0.75
		ps.gravity = Vector3(0, -2.5, 0)
		ps.damping_min = 1.0
		ps.damping_max = 3.0
		ps.scale_amount_min = 0.4
		ps.scale_amount_max = 1.4
		add_child(ps)
		_sparks.append(ps)


# ---------------------------------------------------------------- reactions

func spark(at: Vector2, _strength: float) -> void:
	if not effects_enabled:
		return
	var ps := _sparks[_spark_i]
	_spark_i = (_spark_i + 1) % _sparks.size()
	ps.position = to3(at, 0.014)
	ps.restart()
	ps.emitting = true


func _floor_uv(v: Vector2) -> Vector2:
	return Vector2(v.x / _floor_size.x + 0.5, (-v.y - _floor_cz) / _floor_size.y + 0.5)


func flash_at(at: Vector2, col: Color, energy: float) -> void:
	if not effects_enabled:
		return
	if _floor != null:
		var uv := _floor_uv(at)
		_floor_hits[_floor_hit_i] = Vector4(uv.x, uv.y, 0.0, clampf(energy * 0.5, 0.4, 1.2))
		_floor_hit_i = (_floor_hit_i + 1) % 4
	var l := _flashes[_flash_i]
	_flash_i = (_flash_i + 1) % _flashes.size()
	l.position = to3(at, 0.05)
	l.light_color = col
	l.light_energy = energy * 0.45


func excite(amount: float) -> void:
	_excite = minf(_excite + amount, 1.5)


func next_trail_color() -> void:
	_trail_col = (_trail_col + 1) % TRAIL_COLS.size()


func set_plunger(charge: float) -> void:
	if _plunger != null:
		_plunger.position.z = _plunger_z + charge * 0.035


func flash_post(id: int) -> void:
	if _post_flash.has(id):
		_post_flash[id] = 1.0


func spin(speed: float) -> void:
	_spin_speed = maxf(_spin_speed, speed * 22.0)


## Keeps a target lit, or lets it go dark again.
func set_target_lit(id: int, on: bool) -> void:
	if on:
		_target_lit[id] = true
	else:
		_target_lit.erase(id)


## The volcano goes off (tables that have one).
func erupt() -> void:
	if _theme != null:
		_theme.erupt()


func hole_pulse(amount: float) -> void:
	_hole_pulse = amount


func flash_bumper(id: int) -> void:
	if id >= 0 and id < _bumper_flash.size():
		_bumper_flash[id] = 1.0


func flash_sling(id: int) -> void:
	if id >= 0 and id < _sling_flash.size():
		_sling_flash[id] = 1.0


func flash_target(id: int) -> void:
	if _target_flash.has(id):
		_target_flash[id] = 1.0


func set_insert(id: int, on: bool) -> void:
	if _insert_on.has(id):
		_insert_on[id] = 1.0 if on else 0.0


func pulse_insert(id: int) -> void:
	if _insert_on.has(id):
		_insert_on[id] = maxf(_insert_on[id], 0.999)


# ---------------------------------------------------------------- per frame

func sync(delta: float, frac: float) -> void:
	_time += delta
	for i in phys.flippers.size():
		var f := phys.flippers[i]
		_flip_nodes[i].rotation.y = lerp_angle(f.prev_angle, f.angle, frac)

	# balls and their light trails
	var seen := {}
	for b in phys.balls:
		if not b.active:
			continue
		seen[b.id] = true
		var node: MeshInstance3D = _ball_nodes.get(b.id)
		if node == null:
			node = _mesh(_ball_mesh, _m_ball)
			_ball_nodes[b.id] = node
			var tm := _mesh(ImmediateMesh.new(), _m_trail)
			tm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_trails[b.id] = {"node": tm, "pts": []}
		var p3 := to3(b.prev.lerp(b.pos, frac), PinPhysics.BALL_R + b.z)
		var move := p3 - node.position
		var dist := move.length()
		if dist > 1e-6 and dist < 0.2:
			var axis := Vector3.UP.cross(move / dist)
			if axis.length_squared() > 1e-8:
				node.rotate(axis.normalized(), dist / PinPhysics.BALL_R)
		node.position = p3
		_update_trail(_trails[b.id], p3, 0.0 if b.held else b.vel.length())
	for id in _ball_nodes.keys():
		if not seen.has(id):
			_ball_nodes[id].queue_free()
			_ball_nodes.erase(id)
			_trails[id]["node"].queue_free()
			_trails.erase(id)

	if _theme != null:
		_theme.sync(delta, _time)

	if _floor != null:
		var n := 0
		for i in 4:
			_floor_balls[i] = Vector4.ZERO
			_floor_hits[i].z += delta
		for b in phys.balls:
			if b.active and n < 4:
				var uv := _floor_uv(b.pos)
				_floor_balls[n] = Vector4(uv.x, uv.y, 1.0, 0.0)
				n += 1
		_floor.set_shader_parameter("ball", _floor_balls)
		_floor.set_shader_parameter("hit", _floor_hits)
		_floor.set_shader_parameter("excite", _excite)
		_floor.set_shader_parameter("fx", 1.0 if effects_enabled else 0.0)

	# lamps
	_excite = maxf(0.0, _excite - delta * 1.6)
	for i in _lamps.size():
		var w := maxf(0.0, sin(_time * _lamp_speed[i] - _lamp_phase[i]))
		_lamps[i].emission_energy_multiplier = 0.12 + 0.9 * pow(w, 5.0) + _excite * 0.4
	for l in _flashes:
		l.light_energy = maxf(0.0, l.light_energy - delta * 14.0)
	for i in _flashers.size():
		var strobe := 1.0 if int(_time * 14.0 + i) % 2 == 0 else 0.0
		_flashers[i].emission_energy_multiplier = 0.1 + minf(_excite, 1.0) * strobe * 3.0
	for id in _post_mats:
		_post_flash[id] = maxf(0.0, _post_flash[id] - delta * 4.0)
		_post_mats[id].emission_energy_multiplier = 0.1 + _post_flash[id] * 2.0
	_hole_pulse = maxf(0.0, _hole_pulse - delta * 1.2)
	_hole_mat.emission_energy_multiplier = 0.7 + 0.3 * sin(_time * 3.0) + _hole_pulse * 3.0
	_hole_light.light_energy = 0.2 + _hole_pulse * 2.0
	if _spinner != null and _spin_speed > 0.05:
		_spinner.rotate_x(_spin_speed * delta)
		_spin_speed *= exp(-1.6 * delta)
	for i in _bumper_flash.size():
		_bumper_flash[i] = maxf(0.0, _bumper_flash[i] - delta * 5.0)
		var fl := _bumper_flash[i]
		_bumper_lights[i].light_energy = 0.03 + fl * 1.0
		_bumper_caps[i].emission_energy_multiplier = 0.08 + fl * 1.6
		_bumper_rings[i].position.y = 0.014 - fl * 0.007
	for i in _sling_mats.size():
		_sling_flash[i] = maxf(0.0, _sling_flash[i] - delta * 6.0)
		_sling_mats[i].emission_energy_multiplier = 0.2 + _sling_flash[i] * 3.0
	for id in _target_mats:
		_target_flash[id] = maxf(0.0, _target_flash[id] - delta * 4.0)
		_target_mats[id].emission_energy_multiplier = 0.08 + _target_flash[id] * 1.8 + (0.9 if _target_lit.has(id) else 0.0)
	for id in _inserts:
		var v: float = _insert_on[id]
		if v > 0.0 and v < 1.0:
			v = maxf(0.0, v - delta * 1.5)
			_insert_on[id] = v
		_inserts[id].emission_energy_multiplier = 0.12 + v * 1.8


## Long-exposure style light trail: a ribbon that lingers for TRAIL_SECONDS,
## faces the camera, and only lays down light while the ball is moving fast.
func _update_trail(tr: Dictionary, p: Vector3, speed: float) -> void:
	var pts: Array = tr["pts"]      # each: [position, time, strength, colour index]
	while pts.size() > 0 and _time - pts[pts.size() - 1][1] > TRAIL_SECONDS:
		pts.pop_back()
	if pts.size() > 0 and p.distance_to(pts[0][0]) > 0.12:
		pts.clear()
	if pts.is_empty() or p.distance_to(pts[0][0]) > 0.007:
		pts.push_front([p, _time, clampf((speed - 0.9) / 1.3, 0.0, 1.0), _trail_col])
		if pts.size() > 420:
			pts.pop_back()
	var im: ImmediateMesh = tr["node"].mesh
	im.clear_surfaces()
	if not effects_enabled or pts.size() < 3:
		return
	var n := pts.size()
	for layer in 2:
		var width := 0.0105 if layer == 0 else 0.0038
		var gain := 0.5 if layer == 0 else 1.0
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in n:
			var e: Array = pts[i]
			var a: Vector3 = e[0]
			var dir: Vector3 = (a - pts[i + 1][0]) if i < n - 1 else (pts[i - 1][0] - a)
			var side := dir.cross(cam_local - a)
			if side.length_squared() < 1e-12:
				side = Vector3.RIGHT
			side = side.normalized()
			var life: float = 1.0 - (_time - float(e[1])) / TRAIL_SECONDS
			var col: Color = TRAIL_COLS[e[3]][layer]
			var c := Color(col.r, col.g, col.b, gain * float(e[2]) * life * sqrt(life))
			var w: float = width * (0.35 + 0.65 * life)
			im.surface_set_color(c)
			im.surface_add_vertex(a + side * w)
			im.surface_set_color(c)
			im.surface_add_vertex(a - side * w)
		im.surface_end()
