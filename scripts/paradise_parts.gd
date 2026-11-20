class_name ParadiseParts
extends RefCounted
## Themed 3D parts for the Paradise Bay table: beach-ball and coconut bumpers,
## standing surfboard targets, tiki torches, shell lights, the tiki hut, the
## wooden pier ramp, the chrome wire rail, the volcano and the palms.
## TableView calls into this while it builds and every frame from sync().

var v: TableView
var _wood: StandardMaterial3D
var _wood_dark: StandardMaterial3D
var _rope: StandardMaterial3D
var _rock: StandardMaterial3D
var _leaf: StandardMaterial3D
var _thatch: StandardMaterial3D
var _flame: StandardMaterial3D
var _lava: StandardMaterial3D
var _water: StandardMaterial3D
var _shell: Texture2D
var _volcano_light: OmniLight3D
var _burst: CPUParticles3D
var _smoke: CPUParticles3D
var _erupt := 0.0
var _beach_tex: ImageTexture
var _plank_cols: Array[StandardMaterial3D] = []

const VOLCANO := Vector2(0.0, 1.085)
const VOLCANO_BASE := 0.034


func _init(view: TableView) -> void:
	v = view
	_shell = v._tex("shell.png")
	_wood = v._mat(Color(0.47, 0.30, 0.16), 0.0, 0.8)
	_wood_dark = v._mat(Color(0.30, 0.18, 0.09), 0.0, 0.85)
	_rope = v._mat(Color(0.80, 0.68, 0.45), 0.0, 0.9)
	for c in [Color(0.55, 0.36, 0.19), Color(0.48, 0.30, 0.15), Color(0.62, 0.42, 0.23), Color(0.43, 0.27, 0.14)]:
		_plank_cols.append(v._mat(c, 0.0, 0.75))
	_rock = _noisy(Color(0.20, 0.17, 0.16), Color(0.42, 0.36, 0.32), 0.03, 0.95)
	_thatch = _noisy(Color(0.55, 0.40, 0.16), Color(0.92, 0.76, 0.40), 0.012, 1.0)
	_leaf = v._mat(Color(0.13, 0.55, 0.16), 0.0, 0.55)
	_leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	_flame = v._lit(Color(1.0, 0.55, 0.08), 2.2)
	_lava = v._lit(Color(1.0, 0.32, 0.03), 1.6)
	_water = v._lit(Color(0.75, 0.95, 1.0), 0.5)
	_beach_tex = _beach_ball_texture()


## A material with blotchy colour variation that needs no UVs (triplanar).
func _noisy(dark: Color, light: Color, cell: float, rough: float) -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	var grad := Gradient.new()
	grad.set_color(0, dark)
	grad.set_color(1, light)
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = grad
	var m := v._mat(Color.WHITE, 0.0, rough)
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * (1.0 / (cell * 20.0))
	return m


func _beach_ball_texture() -> ImageTexture:
	var cols := [Color(0.92, 0.08, 0.08), Color(0.97, 0.97, 0.95), Color(0.08, 0.35, 0.85),
		Color(0.97, 0.97, 0.95), Color(0.92, 0.08, 0.08), Color(0.97, 0.97, 0.95),
		Color(0.08, 0.35, 0.85), Color(0.97, 0.97, 0.95)]
	var img := Image.create(256, 64, false, Image.FORMAT_RGB8)
	for x in 256:
		var c: Color = cols[int(x * cols.size() / 256.0) % cols.size()]
		for y in 64:
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _sphere(r: float, squash: float, mat: Material, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 40
	sm.rings = 20
	var mi := v._mesh(sm, mat, pos, parent)
	mi.scale = Vector3(1.0, squash, 1.0)
	return mi


# ------------------------------------------------------------------ bumpers

## Builds a themed bumper under root. Returns [flash material, kicker ring].
func bumper(c: PinPhysics.Circ, kind: String, root: Node3D) -> Array:
	var r := c.r
	v._cyl(r * 1.36, 0.0008, Vector3(0, 0.0004, 0), v._m_black, root)
	v._mesh(Parts.lathe(PackedVector2Array([Vector2(r * 1.2, 0.0005), Vector2(r * 1.2, 0.003),
		Vector2(r * 0.98, 0.0065), Vector2(r * 0.8, 0.0065), Vector2(r * 0.8, 0.013)]), 40), v._m_white, Vector3.ZERO, root)
	var ring := v._torus(r * 1.0, 0.0022, Vector3(0, 0.014, 0), v._m_chrome, root)
	var m: StandardMaterial3D
	if kind == "drum":
		# a tiki drum: wooden shell, rope lacing and a skin that glows when struck
		m = v._lit(Color(1.0, 0.85, 0.55), 0.1)
		m.albedo_color = Color(0.93, 0.85, 0.68)
		v._cyl(r * 1.0, 0.03, Vector3(0, 0.028, 0), _wood, root, r * 1.12)
		v._cyl(r * 1.1, 0.002, Vector3(0, 0.044, 0), m, root)
		for hh in [0.018, 0.041]:
			v._torus(r * 1.08, 0.0014, Vector3(0, hh, 0), _rope, root)
		for k in 10:
			var da := TAU * k / 10.0
			var lace := v._box(Vector3(0.0012, 0.024, 0.0012), Vector3(cos(da) * r * 1.09, 0.03, sin(da) * r * 1.09), _rope, root)
			lace.rotation.z = 0.25 if k % 2 == 0 else -0.25
		return [m, ring]
	if kind == "buoy":
		# a harbour buoy: red and white float with a lamp on top
		m = v._lit(Color(1.0, 0.25, 0.1), 0.1)
		var red := v._mat(Color(0.86, 0.1, 0.08), 0.0, 0.3)
		v._mesh(Parts.lathe(PackedVector2Array([Vector2(r * 0.95, 0.013), Vector2(r * 1.05, 0.02), Vector2(r * 0.9, 0.032),
			Vector2(r * 0.55, 0.05), Vector2(r * 0.3, 0.06), Vector2(0, 0.061)]), 28), red, Vector3.ZERO, root)
		v._cyl(r * 0.99, 0.006, Vector3(0, 0.0275, 0), v._m_white, root, r * 0.92)
		v._cyl(0.0022, 0.012, Vector3(0, 0.066, 0), v._m_steel, root)
		_sphere(0.0048, 1.0, m, Vector3(0, 0.074, 0), root)
		return [m, ring]
	if kind == "islet":
		# a rock islet with a little palm; a ring of light at the waterline flashes
		m = v._lit(Color(0.4, 1.0, 0.9), 0.1)
		v._torus(r * 1.12, 0.0016, Vector3(0, 0.004, 0), m, root)
		_sphere(r * 0.98, 0.75, _rock, Vector3(0, 0.013 + r * 0.45, 0), root)
		_sphere(r * 0.55, 0.8, _rock, Vector3(r * 0.5, 0.013 + r * 0.9, r * 0.2), root)
		var tr := PackedVector3Array()
		for i in 5:
			var t := i / 4.0
			tr.append(Vector3(-r * 0.2 + 0.008 * t * t, 0.013 + r * 0.8 + 0.045 * t, 0.004 * sin(t * 2.0)))
		v._mesh(Parts.tube(tr, 0.0024, 6), _wood, Vector3.ZERO, root)
		for k in 7:
			var leaf := v._mesh(_frond(0.034, 0.007, 0.01, 0.014), _leaf, tr[4], root)
			leaf.rotation.y = TAU * k / 7.0
		return [m, ring]
	if kind == "beach":
		m = v._mat(Color.WHITE, 0.0, 0.18)
		m.albedo_texture = _beach_tex
		m.emission_enabled = true
		m.emission = Color.WHITE
		m.emission_texture = _beach_tex
		m.clearcoat_enabled = true
		m.clearcoat = 0.8
		m.clearcoat_roughness = 0.08
		_sphere(r * 1.12, 1.0, m, Vector3(0, 0.012 + r * 1.12, 0), root)
		v._cyl(r * 0.2, 0.0012, Vector3(0, 0.012 + r * 2.24, 0), v._m_white, root)
	else:
		m = _noisy(Color(0.25, 0.14, 0.06), Color(0.56, 0.36, 0.16), 0.006, 0.85)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.55, 0.15)
		var top := 0.012 + r * 2.0
		_sphere(r * 1.1, 0.92, m, Vector3(0, 0.012 + r * 1.0, 0), root)
		# three dark "eyes" and a crown of leaves
		for k in 3:
			var a := TAU * k / 3.0 + 0.5
			_sphere(r * 0.13, 0.5, _wood_dark, Vector3(cos(a) * r * 0.35, top - r * 0.07, sin(a) * r * 0.35), root)
		for k in 7:
			var leaf := v._mesh(_frond(r * 1.15, r * 0.34, 0.012, 0.03), _leaf, Vector3(0, top - 0.002, 0), root)
			leaf.rotation.y = TAU * k / 7.0
	return [m, ring]


# ------------------------------------------------------------------ targets

## A surfboard standing on its tail, leaning back a little, cut out of its
## painted artwork. It lights up when hit.
func surfboard(s: PinPhysics.Seg) -> StandardMaterial3D:
	var cols := [Color(0.9, 0.15, 0.1), Color(1.0, 0.7, 0.1), Color(0.2, 0.6, 1.0), Color(0.9, 0.1, 0.25), Color(0.1, 0.8, 0.75)]
	var tex := v._tex("board_%d.png" % s.id)
	var m := v._mat(Color.WHITE, 0.0, 0.25)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.emission_enabled = true
	var h := 0.08
	var w := 0.03
	if tex != null:
		m.albedo_texture = tex
		m.emission_texture = tex
		m.emission = Color.WHITE
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		w = h * tex.get_width() / float(tex.get_height())
		if w > 0.037:          # wide artwork (shields): shrink to fit its slot
			h *= 0.037 / w
			w = 0.037
	else:
		m.albedo_color = cols[s.id % 5]
		m.emission = cols[s.id % 5]
	var back: StandardMaterial3D = m.duplicate()
	back.albedo_color = Color(0.35, 0.22, 0.12)
	back.emission_enabled = false
	var c := (s.a + s.b) * 0.5
	var lean := deg_to_rad(-16.0)
	var foot := TableView.to3(c + Vector2(0, 0.005), 0.005)
	for layer in 2:
		var qm := QuadMesh.new()
		qm.size = Vector2(w, h)
		var mi := v._mesh(qm, m if layer == 0 else back, foot + Vector3(0, h * 0.5 * cos(lean), h * 0.5 * sin(lean) - layer * 0.0022))
		mi.rotation.x = lean
	# wooden stand and a chrome foot
	v._box(Vector3(0.03, 0.007, 0.009), TableView.to3(c + Vector2(0, 0.006), 0.0035), _wood)
	v._box(Vector3(0.036, 0.002, 0.013), TableView.to3(c + Vector2(0, 0.006), 0.001), v._m_steel)
	return m


## A big scallop shell standing on edge, facing down the table. Lights when hit.
func shell_target(s: PinPhysics.Seg) -> StandardMaterial3D:
	var m := v._mat(Color(1.0, 0.85, 0.6), 0.0, 0.3)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.emission_enabled = true
	m.emission = Color(1.0, 0.75, 0.35)
	if _shell != null:
		m.albedo_texture = _shell
		m.emission_texture = _shell
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.4
	var d := (s.b - s.a).normalized()
	var n := Vector2(d.y, -d.x)
	if n.y > 0.0:
		n = -n
	var c := (s.a + s.b) * 0.5
	var size := s.a.distance_to(s.b) * 1.15
	var yaw := atan2(n.x, -n.y)
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	var mi := v._mesh(qm, m, TableView.to3(c, size * 0.5 + 0.003))
	mi.rotation = Vector3(deg_to_rad(-12.0), yaw, 0)
	var foot := v._box(Vector3(size * 0.8, 0.005, 0.006), TableView.to3(c, 0.0025), _wood)
	foot.rotation.y = yaw
	return m


# -------------------------------------------------------------------- posts

## A tiki torch: bamboo pole, rubber ring, bowl and a flame. The glowing band
## under the bowl is the part that flashes when the ball hits the post.
func torch(c: PinPhysics.Circ, col: Color) -> StandardMaterial3D:
	var p := TableView.to3(c.c, 0.0)
	var r := c.r
	v._cyl(r * 1.5, 0.0008, p + Vector3(0, 0.0004, 0), v._m_black)
	v._cyl(r * 0.5, 0.034, p + Vector3(0, 0.017, 0), _wood)
	for h in [0.008, 0.02]:
		v._cyl(r * 0.58, 0.0016, p + Vector3(0, h, 0), _wood_dark)
	v._torus(r * 0.82, 0.0019, p + Vector3(0, 0.014, 0), v._m_rubber_white)
	var band := v._lit(col, 0.1)
	v._cyl(r * 0.62, 0.004, p + Vector3(0, 0.031, 0), band)
	v._cyl(r * 0.5, 0.006, p + Vector3(0, 0.037, 0), _wood_dark, v, r * 0.85)
	v._mesh(Parts.lathe(PackedVector2Array([Vector2(r * 0.55, 0.0), Vector2(r * 0.62, 0.004), Vector2(r * 0.4, 0.010),
		Vector2(r * 0.12, 0.017), Vector2(0, 0.019)]), 12), _flame, p + Vector3(0, 0.040, 0))
	return band


# ------------------------------------------------------------------- lights

## A scallop-shell playfield light. The caller animates its emission energy.
func shell_lamp(at: Vector2, col: Color, energy: float, r: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.9, 0.75, 0.45)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.78, 0.35).lerp(col, 0.3)
	m.emission_energy_multiplier = energy
	if _shell != null:
		m.albedo_texture = _shell
		m.emission_texture = _shell
	var pm := PlaneMesh.new()
	pm.size = Vector2(r * 3.6, r * 3.6)
	var mi := v._mesh(pm, m, TableView.to3(at, 0.0008))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


func lamps() -> void:
	var xc := TableLayout.XC
	var gold := Color(1.0, 0.8, 0.3)
	for i in 5:                  # one in front of each surfboard
		v._add_lamp(shell_lamp(Vector2(-0.105 + i * 0.04, 0.652), gold, 0.3, 0.0075), i * 0.9, 5.0)
	for i in 5:                  # centre line up the beach into the lagoon
		v._add_lamp(shell_lamp(Vector2(xc, 0.235 + i * 0.055), gold, 0.3, 0.0068), i * 0.7, 6.0)
	for i in 4:                  # towards the pier ramp, and towards the hut
		v._add_lamp(shell_lamp(Vector2(0.03, 0.26).lerp(Vector2(0.15, 0.425), i / 3.0), Color(1.0, 0.5, 0.2), 0.3, 0.0068), i * 0.7 + 1.0, 6.0)
		v._add_lamp(shell_lamp(Vector2(-0.08, 0.26).lerp(Vector2(-0.165, 0.455), i / 3.0), Color(1.0, 0.5, 0.2), 0.3, 0.0068), i * 0.7 + 2.0, 6.0)
	for q in [Vector2(-0.095, 0.865), Vector2(-0.01, 0.865), Vector2(0.065, 0.87), Vector2(-0.16, 0.74), Vector2(0.12, 0.745)]:
		v._add_lamp(shell_lamp(q, gold, 0.3, 0.0068), q.x * 30.0, 4.0)
	for side in [-1.0, 1.0]:     # arcs above the flippers
		for i in 3:
			v._add_lamp(shell_lamp(Vector2(xc + side * (0.055 + i * 0.03), 0.178 + i * 0.012), gold, 0.3, 0.006), i * 0.9, 3.0)


# ----------------------------------------------------------------- features

func features() -> void:
	_hut()
	_pier_and_rail()
	_volcano()
	_scenery()


func _hut() -> void:
	var c := Vector2(-0.201, 0.517)
	for q in [Vector2(-0.25, 0.478), Vector2(-0.25, 0.558), Vector2(-0.20, 0.467), Vector2(-0.168, 0.552)]:
		v._cyl(0.0032, 0.05, TableView.to3(q, 0.025), _wood)
		v._cyl(0.0038, 0.002, TableView.to3(q, 0.012), _wood_dark)
	# two layers of thatch
	v._cyl(0.054, 0.024, TableView.to3(c, 0.060), _thatch, v, 0.028)
	v._cyl(0.034, 0.028, TableView.to3(c, 0.084), _thatch, v, 0.004)
	v._cyl(0.055, 0.0025, TableView.to3(c, 0.0485), _wood_dark, v, 0.054)
	# a ragged fringe of straw round the eaves
	for k in 22:
		var fa := TAU * k / 22.0
		var straw := v._box(Vector3(0.006, 0.009, 0.0012), TableView.to3(c, 0.044) + Vector3(cos(fa) * 0.053, 0, sin(fa) * 0.053), _thatch)
		straw.rotation.y = -fa + PI * 0.5
	# carved tiki totems guarding the doorway, with glowing eyes
	for tq in [Vector2(-0.192, 0.459), Vector2(-0.158, 0.556)]:
		var tp := TableView.to3(tq, 0.0)
		v._cyl(0.0062, 0.034, tp + Vector3(0, 0.017, 0), _wood)
		v._cyl(0.0072, 0.004, tp + Vector3(0, 0.034, 0), _wood_dark)
		v._box(Vector3(0.007, 0.0022, 0.002), tp + Vector3(0.001, 0.011, 0.0058), _wood_dark)
		for ex in [-0.0022, 0.0022]:
			_sphere(0.0013, 1.0, _flame, tp + Vector3(ex + 0.001, 0.022, 0.0058), v)
	# bottles on the bar
	var bottle_cols := [Color(0.1, 0.7, 0.3), Color(0.9, 0.5, 0.1), Color(0.2, 0.5, 0.9), Color(0.85, 0.15, 0.2)]
	for bi in 4:
		v._cyl(0.0016, 0.008, TableView.to3(Vector2(-0.2495, 0.492 + bi * 0.017), 0.02), v._lit(bottle_cols[bi], 0.5), v, 0.0008)
	# the bar at the back, with a row of little lanterns
	v._box(Vector3(0.008, 0.016, 0.07), TableView.to3(Vector2(-0.2505, 0.518), 0.008), _wood_dark)
	for i in 3:
		_sphere(0.003, 1.0, _flame, TableView.to3(Vector2(-0.249, 0.498 + i * 0.02), 0.019), v)
	for q2 in [Vector2(-0.20, 0.467), Vector2(-0.168, 0.552)]:
		_sphere(0.0034, 1.4, _flame, TableView.to3(q2, 0.054), v)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.35)
	l.light_energy = 0.35
	l.omni_range = 0.12
	l.position = TableView.to3(c, 0.035)
	v.add_child(l)


func _pier_and_rail() -> void:
	var path := TableLayout.ramp_path()
	# split the path where the planks end and the wire rail begins
	var split := 0
	for i in path.size():
		if path[i].y <= 0.80:
			split = i
		else:
			break
	# planks, each tilted to the slope
	var i2 := 0
	var acc := 0.0
	var k := 0
	while i2 < split:
		var a := path[i2]
		var b := path[i2 + 1]
		var seg := Vector2(b.y - a.y, b.z - a.z)
		var steps := maxi(1, int(round(seg.length() / 0.0105)))
		for j in steps:
			var p := a.lerp(b, (j + 0.5) / steps)
			var plank := v._box(Vector3(0.047, 0.0026, 0.0098), TableView.to3(Vector2(p.x, p.y), p.z - 0.0013), _plank_cols[(k * 7 + k / 3) % _plank_cols.size()])
			plank.rotation.x = atan2(seg.y, seg.x)
			k += 1
		acc += seg.length()
		i2 += 1
	# posts and rope down both sides of the pier
	for side in [-1.0, 1.0]:
		var rope := PackedVector3Array()
		var y := 0.60
		while y <= 0.781:
			var h := _height_at(path, y)
			var q := Vector2(0.18 + side * 0.0245, y)
			v._cyl(0.0028, h + 0.022, TableView.to3(q, (h + 0.022) * 0.5), _wood_dark)
			v._cyl(0.0034, 0.002, TableView.to3(q, h + 0.023), _wood)
			rope.append(TableView.to3(q, h + 0.018))
			y += 0.045
		v._mesh(Parts.tube(rope, 0.0011, 6), _rope)
	# the jetty that funnels shots onto the pier: a row of posts joined by rope
	var jetty := PackedVector3Array()
	for i4 in 7:
		var jq := Vector2(0.045, 0.47).lerp(Vector2(0.155, 0.64), i4 / 6.0)
		v._cyl(0.0034, 0.03, TableView.to3(jq, 0.015), _wood_dark)
		v._cyl(0.0040, 0.002, TableView.to3(jq, 0.031), _wood)
		jetty.append(TableView.to3(jq, 0.026))
	v._mesh(Parts.tube(jetty, 0.0012, 6), _rope)
	# rock arch where the pier goes into the mountain
	for q3 in [[Vector2(0.15, 0.80), 0.022, 2.6], [Vector2(0.212, 0.805), 0.02, 2.9], [Vector2(0.181, 0.812), 0.03, 0.45]]:
		var blob := _sphere(q3[1], q3[2], _rock, TableView.to3(q3[0], 0.03 if q3[2] > 1.0 else 0.118), v)
		blob.scale.z = 1.3
	_rail(path, split)


## The chrome wire rail from the tunnel down to the inlane: two runners under
## the ball, two guides beside it, and hoops.
func _rail(path: PackedVector3Array, split: int) -> void:
	var runs: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array(), PackedVector3Array(), PackedVector3Array()]
	var last_hoop := -1.0
	var dist := 0.0
	for i3 in range(split, path.size()):
		var p3 := TableView.to3(Vector2(path[i3].x, path[i3].y), path[i3].z)
		var nxt := path[mini(i3 + 1, path.size() - 1)]
		var prv := path[maxi(i3 - 1, 0)]
		var tan := (TableView.to3(Vector2(nxt.x, nxt.y), nxt.z) - TableView.to3(Vector2(prv.x, prv.y), prv.z)).normalized()
		var side3 := tan.cross(Vector3.UP).normalized()
		runs[0].append(p3 + side3 * 0.008 + Vector3.UP * 0.001)
		runs[1].append(p3 - side3 * 0.008 + Vector3.UP * 0.001)
		runs[2].append(p3 + side3 * 0.0152 + Vector3.UP * 0.0125)
		runs[3].append(p3 - side3 * 0.0152 + Vector3.UP * 0.0125)
		if i3 > split:
			dist += path[i3].distance_to(path[i3 - 1])
		if dist - last_hoop > 0.14 and i3 < path.size() - 2:
			last_hoop = dist
			var tm := TorusMesh.new()
			tm.inner_radius = 0.0162
			tm.outer_radius = 0.0180
			tm.rings = 20
			tm.ring_segments = 6
			var hoop := v._mesh(tm, v._m_chrome, p3 + Vector3.UP * 0.0125)
			var up2 := side3.cross(tan).normalized()
			hoop.basis = Basis(side3, tan, up2)
			# a leg down to the table where there is room for one
			if path[i3].z > 0.03 and (absf(path[i3].x) > 0.22 or path[i3].y > 0.97):
				v._wire(p3 + Vector3.DOWN * 0.004, Vector3(p3.x, 0.0, p3.z), 0.0013, v._m_chrome)
	for run in runs:
		v._mesh(Parts.tube(run, 0.0015, 6), v._m_chrome)


func _height_at(path: PackedVector3Array, y: float) -> float:
	for i in path.size() - 1:
		if path[i + 1].y >= y:
			var span := maxf(path[i + 1].y - path[i].y, 1e-6)
			return lerpf(path[i].z, path[i + 1].z, clampf((y - path[i].y) / span, 0.0, 1.0))
	return 0.0


func _volcano() -> void:
	var base := TableView.to3(VOLCANO, VOLCANO_BASE)
	v._mesh(Parts.lathe(PackedVector2Array([Vector2(0.118, 0.0), Vector2(0.10, 0.028), Vector2(0.076, 0.066),
		Vector2(0.052, 0.10), Vector2(0.032, 0.126), Vector2(0.024, 0.134), Vector2(0.017, 0.126), Vector2(0.0, 0.122)]), 40),
		_rock, base)
	v._cyl(0.0175, 0.002, base + Vector3(0, 0.1255, 0), _lava)
	# lava running down the front of the cone
	var prof := [Vector2(0.021, 0.131), Vector2(0.034, 0.124), Vector2(0.054, 0.098), Vector2(0.078, 0.063), Vector2(0.101, 0.026)]
	for a in [1.15, 1.6, 2.0, 0.75, 2.45]:
		var stream := PackedVector3Array()
		for i in prof.size():
			var wob: float = a + sin(i * 2.1 + a * 5.0) * 0.07
			var pr: Vector2 = prof[i]
			stream.append(base + Vector3(cos(wob) * pr.x, pr.y + 0.0005, sin(wob) * pr.x))
			if i >= 2 + int(a * 10.0) % 3:
				break
		v._mesh(Parts.tube(stream, 0.0028, 6), _lava)
	_volcano_light = OmniLight3D.new()
	_volcano_light.light_color = Color(1.0, 0.4, 0.1)
	_volcano_light.light_energy = 0.5
	_volcano_light.omni_range = 0.35
	_volcano_light.position = base + Vector3(0, 0.16, 0.03)
	v.add_child(_volcano_light)
	# drifting smoke, and the burst of lava thrown out by an eruption
	var puff := SphereMesh.new()
	puff.radius = 0.012
	puff.height = 0.024
	puff.radial_segments = 10
	puff.rings = 6
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.albedo_color = Color(0.75, 0.72, 0.7, 0.35)
	puff.material = smoke_mat
	_smoke = CPUParticles3D.new()
	_smoke.mesh = puff
	_smoke.amount = 14
	_smoke.lifetime = 3.0
	_smoke.direction = Vector3(0.15, 1, 0)
	_smoke.spread = 14.0
	_smoke.gravity = Vector3.ZERO
	_smoke.initial_velocity_min = 0.02
	_smoke.initial_velocity_max = 0.035
	_smoke.scale_amount_min = 0.5
	_smoke.scale_amount_max = 1.6
	_smoke.position = base + Vector3(0, 0.135, 0)
	v.add_child(_smoke)
	var ember := SphereMesh.new()
	ember.radius = 0.0035
	ember.height = 0.007
	ember.radial_segments = 6
	ember.rings = 4
	var ember_mat := StandardMaterial3D.new()
	ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_mat.albedo_color = Color(1.0, 0.5, 0.08)
	ember.material = ember_mat
	_burst = CPUParticles3D.new()
	_burst.mesh = ember
	_burst.amount = 70
	_burst.lifetime = 1.1
	_burst.one_shot = true
	_burst.emitting = false
	_burst.explosiveness = 0.85
	_burst.direction = Vector3.UP
	_burst.spread = 32.0
	_burst.gravity = Vector3(0, -1.6, 0)
	_burst.initial_velocity_min = 0.35
	_burst.initial_velocity_max = 0.75
	_burst.position = base + Vector3(0, 0.13, 0)
	v.add_child(_burst)


func _scenery() -> void:
	# rock outcrops with waterfalls in the top corners, and palms behind them
	for side in [-1.0, 1.0]:
		for q in [[Vector2(side * 0.21, 1.03), 0.034, 0.9], [Vector2(side * 0.165, 1.055), 0.028, 1.1], [Vector2(side * 0.238, 0.975), 0.022, 0.8]]:
			var blob := _sphere(q[1], q[2], _rock, TableView.to3(q[0], 0.034 + q[1] * q[2] * 0.55), v)
			blob.rotation.y = side * 0.6
		for wf in [[0.19, 1.012, 0.012, 0.048], [0.224, 0.992, 0.008, 0.036]]:
			var fall := v._box(Vector3(wf[2], wf[3], 0.002), TableView.to3(Vector2(side * wf[0], wf[1]), 0.036 + wf[3] * 0.5), _water)
			fall.rotation.x = deg_to_rad(-14.0)
			for fk in 3:   # foam where the water lands
				_sphere(0.004, 0.6, v._m_white, TableView.to3(Vector2(side * wf[0] + (fk - 1) * 0.005, wf[1] - 0.008), 0.036), v)
		_palm(Vector2(side * 0.232, 1.045), 0.13, side * 0.035)
		_palm(Vector2(side * 0.185, 1.075), 0.165, side * -0.02)
	# small rocks at the mouth of the hut and the foot of the pier
	for q2 in [[Vector2(-0.168, 0.462), 0.008], [Vector2(0.142, 0.432), 0.007]]:
		_sphere(q2[1], 0.7, _rock, TableView.to3(q2[0], q2[1] * 0.35), v)


## One palm frond (or coconut leaf): a tapering strip that droops at the tip.
func _frond(length: float, width: float, rise: float, droop: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 6
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var w0 := width * pow(sin(PI * (0.08 + 0.92 * t0)), 0.6)
		var w1 := width * pow(sin(PI * (0.08 + 0.92 * t1)), 0.6) if i < n - 1 else 0.0
		var c0 := Vector3(t0 * length, rise * t0 * 2.0 - droop * t0 * t0 * 3.0, 0)
		var c1 := Vector3(t1 * length, rise * t1 * 2.0 - droop * t1 * t1 * 3.0, 0)
		var a := c0 + Vector3(0, -w0 * 0.25, -w0)
		var b := c0 + Vector3(0, -w0 * 0.25, w0)
		var c := c1 + Vector3(0, -w1 * 0.25, -w1)
		var d := c1 + Vector3(0, -w1 * 0.25, w1)
		for tri in [[a, c0, c], [c0, c1, c], [c0, b, c1], [b, d, c1]]:
			var nrm: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
			for p in tri:
				st.set_normal(nrm)
				st.add_vertex(p)
	return st.commit()


func _palm(at: Vector2, height: float, lean: float) -> void:
	var trunk := PackedVector3Array()
	var base := TableView.to3(at, 0.034)
	for i in 6:
		var t := i / 5.0
		trunk.append(base + Vector3(lean * t * t, height * t, 0.012 * sin(t * 2.4)))
	v._mesh(Parts.tube(trunk, 0.0042, 7), _wood)
	var top := trunk[5]
	for k in 8:
		var leaf := v._mesh(_frond(0.062, 0.011, 0.016, 0.022), _leaf, top)
		leaf.rotation.y = TAU * k / 8.0 + at.x * 9.0
	for k2 in 3:
		_sphere(0.0048, 1.0, _wood_dark, top + Vector3(cos(k2 * 2.1) * 0.006, -0.006, sin(k2 * 2.1) * 0.006), v)


# ------------------------------------------------------------------ runtime

func erupt() -> void:
	_erupt = 1.0
	if _burst != null:
		_burst.restart()
		_burst.emitting = true


func sync(delta: float, time: float) -> void:
	_erupt = maxf(0.0, _erupt - delta * 0.8)
	_flame.emission_energy_multiplier = 1.9 + 0.5 * sin(time * 17.0) * sin(time * 7.3)
	_lava.emission_energy_multiplier = 1.5 + 0.4 * sin(time * 2.3) + _erupt * 5.0
	if _volcano_light != null:
		_volcano_light.light_energy = 0.45 + 0.15 * sin(time * 2.3) + _erupt * 3.0
