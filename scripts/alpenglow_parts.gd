class_name AlpenglowParts
extends ParadiseParts
## Themed 3D parts for the Alpenglow table: a lakeside castle at dusk. Tower
## and wine-barrel bumpers, heraldic shield targets, iron lanterns, the castle
## whose gate holds the ball, the stone causeway ramp, and a snowy peak at the
## back that glows pink when the ramp is made. Shares the wire rail, the
## cut-out targets and the playfield lights with ParadiseParts.

var _stone: StandardMaterial3D
var _stone_dark: StandardMaterial3D
var _slate: StandardMaterial3D
var _iron: StandardMaterial3D
var _window: StandardMaterial3D
var _gold: StandardMaterial3D
var _slabs: Array[StandardMaterial3D] = []
var _foliage: Array[StandardMaterial3D] = []


func _init(view: TableView) -> void:
	super(view)
	_stone = _noisy(Color(0.42, 0.40, 0.38), Color(0.72, 0.68, 0.62), 0.012, 0.9)
	_stone_dark = _noisy(Color(0.22, 0.21, 0.22), Color(0.42, 0.40, 0.40), 0.012, 0.95)
	_slate = v._mat(Color(0.16, 0.19, 0.28), 0.1, 0.5)
	_iron = v._mat(Color(0.07, 0.07, 0.08), 0.7, 0.45)
	_gold = v._mat(Color(1.0, 0.78, 0.25), 1.0, 0.25)
	_window = v._lit(Color(1.0, 0.72, 0.3), 1.5)
	for c in [Color(0.56, 0.54, 0.50), Color(0.48, 0.46, 0.44), Color(0.62, 0.59, 0.54)]:
		_slabs.append(v._mat(c, 0.0, 0.85))
	_foliage.append(_noisy(Color(0.70, 0.36, 0.04), Color(1.0, 0.74, 0.18), 0.008, 0.8))
	_foliage.append(_noisy(Color(0.46, 0.07, 0.05), Color(0.90, 0.28, 0.10), 0.008, 0.8))
	_foliage.append(_noisy(Color(0.05, 0.20, 0.10), Color(0.12, 0.38, 0.18), 0.008, 0.8))


func _cone_roof(r: float, h: float, pos: Vector3, parent: Node3D) -> void:
	v._cyl(r, h, pos + Vector3(0, h * 0.5, 0), _slate, parent, 0.0008)
	_sphere(0.0018, 1.0, _gold, pos + Vector3(0, h + 0.001, 0), parent)


# ------------------------------------------------------------------ bumpers

func bumper(c: PinPhysics.Circ, kind: String, root: Node3D) -> Array:
	var r := c.r
	v._cyl(r * 1.36, 0.0008, Vector3(0, 0.0004, 0), v._m_black, root)
	v._mesh(Parts.lathe(PackedVector2Array([Vector2(r * 1.2, 0.0005), Vector2(r * 1.2, 0.003),
		Vector2(r * 0.98, 0.0065), Vector2(r * 0.8, 0.0065), Vector2(r * 0.8, 0.013)]), 40), v._m_white, Vector3.ZERO, root)
	var ring := v._torus(r * 1.0, 0.0022, Vector3(0, 0.014, 0), v._m_chrome, root)
	var m: StandardMaterial3D
	if kind == "tower":
		# a round stone tower with lit windows and a pointed slate roof
		m = v._lit(Color(1.0, 0.72, 0.3), 0.1)
		v._cyl(r * 0.92, 0.05, Vector3(0, 0.038, 0), _stone, root)
		v._cyl(r * 1.02, 0.006, Vector3(0, 0.064, 0), _stone_dark, root)
		for k in 6:
			var a := TAU * k / 6.0
			v._box(Vector3(0.0045, 0.009, 0.002), Vector3(sin(a) * r * 0.92, 0.042, cos(a) * r * 0.92), m, root).rotation.y = a
		_cone_roof(r * 1.12, 0.036, Vector3(0, 0.067, 0), root)
	elif kind == "barrel":
		# a wine barrel standing on end; its hoops flash
		m = v._lit(Color(1.0, 0.6, 0.2), 0.1)
		m.albedo_color = Color(0.25, 0.2, 0.15)
		v._mesh(Parts.lathe(PackedVector2Array([Vector2(r * 0.8, 0.013), Vector2(r * 0.98, 0.028), Vector2(r * 1.03, 0.04),
			Vector2(r * 0.98, 0.052), Vector2(r * 0.8, 0.067), Vector2(0, 0.067)]), 32), _wood, Vector3.ZERO, root)
		for hoop in [[0.021, 0.9], [0.04, 1.04], [0.059, 0.9]]:
			v._torus(r * hoop[1], 0.0014, Vector3(0, hoop[0], 0), m, root)
		v._cyl(r * 0.72, 0.001, Vector3(0, 0.0676, 0), _wood_dark, root)
		v._cyl(0.003, 0.004, Vector3(0, 0.07, 0), _wood_dark, root)
	elif kind == "well":
		# a stone well with a little roof; the water glows when struck
		m = v._lit(Color(0.3, 0.75, 1.0), 0.1)
		v._cyl(r * 1.0, 0.022, Vector3(0, 0.024, 0), _stone, root)
		v._cyl(r * 0.78, 0.001, Vector3(0, 0.0356, 0), m, root)
		for sx in [-1.0, 1.0]:
			v._cyl(0.0018, 0.034, Vector3(sx * r * 0.85, 0.052, 0), _wood_dark, root)
		_cone_roof(r * 1.15, 0.02, Vector3(0, 0.069, 0), root)
	elif kind == "press":
		# a wine press: an open vat of grapes with a screw and beam above
		m = v._lit(Color(0.7, 0.25, 0.9), 0.1)
		v._cyl(r * 1.0, 0.028, Vector3(0, 0.027, 0), _wood, root, r * 1.08)
		for hh in [0.018, 0.036]:
			v._torus(r * 1.06, 0.0013, Vector3(0, hh, 0), _iron, root)
		v._cyl(r * 0.86, 0.001, Vector3(0, 0.0415, 0), m, root)
		v._cyl(0.0024, 0.04, Vector3(0, 0.06, 0), v._m_steel, root)
		v._box(Vector3(r * 2.3, 0.005, 0.006), Vector3(0, 0.08, 0), _wood_dark, root)
		for sx2 in [-1.0, 1.0]:
			v._box(Vector3(0.004, 0.068, 0.005), Vector3(sx2 * r * 1.12, 0.047, 0), _wood_dark, root)
	else:
		# a stone fountain standing in the lake
		m = v._lit(Color(0.4, 0.9, 1.0), 0.1)
		v._mesh(Parts.lathe(PackedVector2Array([Vector2(r * 0.7, 0.013), Vector2(r * 1.05, 0.02), Vector2(r * 1.05, 0.027),
			Vector2(r * 0.9, 0.027), Vector2(r * 0.9, 0.023), Vector2(0, 0.023)]), 32), _stone, Vector3.ZERO, root)
		v._cyl(r * 0.88, 0.001, Vector3(0, 0.0255, 0), m, root)
		v._cyl(r * 0.16, 0.03, Vector3(0, 0.04, 0), _stone, root)
		v._cyl(r * 0.5, 0.004, Vector3(0, 0.056, 0), _stone, root, r * 0.3)
		_sphere(r * 0.2, 1.3, m, Vector3(0, 0.064, 0), root)
	return [m, ring]


# -------------------------------------------------------------------- posts

## An iron lantern post. The collar under the lantern flashes when hit.
func torch(c: PinPhysics.Circ, col: Color) -> StandardMaterial3D:
	var p := TableView.to3(c.c, 0.0)
	var r := c.r
	v._cyl(r * 1.5, 0.0008, p + Vector3(0, 0.0004, 0), v._m_black)
	v._cyl(r * 0.34, 0.036, p + Vector3(0, 0.018, 0), _iron)
	v._torus(r * 0.82, 0.0019, p + Vector3(0, 0.014, 0), v._m_rubber_white)
	var band := v._lit(col, 0.1)
	v._cyl(r * 0.6, 0.003, p + Vector3(0, 0.0345, 0), band)
	v._box(Vector3(r * 0.95, 0.009, r * 0.95), p + Vector3(0, 0.0405, 0), _flame)
	v._cyl(r * 0.85, 0.005, p + Vector3(0, 0.0475, 0), _iron, v, 0.0006)
	return band


func shell_lamp(at: Vector2, col: Color, energy: float, r: float) -> StandardMaterial3D:
	var m := super(at, col, energy, r)
	m.albedo_color = Color.WHITE
	m.emission = Color(0.5, 0.22, 0.7).lerp(col, 0.25)
	return m


# ----------------------------------------------------------------- features

func features() -> void:
	var path := TableLayout.ramp_path()
	var split := 0
	for i in path.size():
		if path[i].y <= 0.80:
			split = i
		else:
			break
	_castle()
	_causeway(path, split)
	_rail(path, split)
	_mountain()
	_autumn()


func _lantern(at: Vector2, base: float, height: float) -> void:
	v._cyl(0.0012, height, TableView.to3(at, base + height * 0.5), _iron)
	v._box(Vector3(0.0048, 0.006, 0.0048), TableView.to3(at, base + height + 0.003), _flame)
	v._cyl(0.004, 0.003, TableView.to3(at, base + height + 0.0075), _iron, v, 0.0005)


## The castle over the ball pocket in the left wall: a gatehouse the ball rolls
## under, two gate towers, a tall keep and lit windows.
func _castle() -> void:
	# gatehouse spanning the pocket, high enough for the ball to pass beneath
	v._box(Vector3(0.078, 0.024, 0.094), TableView.to3(Vector2(-0.213, 0.516), 0.043), _stone)
	for k in 7:      # battlements along the front and the lake side
		v._box(Vector3(0.006, 0.006, 0.007), TableView.to3(Vector2(-0.177, 0.474 + k * 0.014), 0.058), _stone_dark)
		v._box(Vector3(0.007, 0.006, 0.006), TableView.to3(Vector2(-0.249 + k * 0.012, 0.47), 0.058), _stone_dark)
	for k2 in 3:     # lit windows facing the lake
		v._box(Vector3(0.0015, 0.008, 0.006), TableView.to3(Vector2(-0.1735, 0.492 + k2 * 0.022), 0.045), _window)
	# gate towers either side of the doorway
	for q in [Vector2(-0.20, 0.464), Vector2(-0.166, 0.556)]:
		v._cyl(0.0105, 0.07, TableView.to3(q, 0.035), _stone)
		v._cyl(0.0118, 0.005, TableView.to3(q, 0.0705), _stone_dark)
		_cone_roof(0.0128, 0.03, TableView.to3(q, 0.073), v)
		v._box(Vector3(0.0025, 0.008, 0.0015), TableView.to3(q + Vector2(0.0, -0.0105), 0.05), _window)
	# the keep, rising from the middle of the gatehouse
	var keep := Vector2(-0.195, 0.515)
	v._cyl(0.015, 0.05, TableView.to3(keep, 0.08), _stone)
	v._cyl(0.0168, 0.005, TableView.to3(keep, 0.1055), _stone_dark)
	_cone_roof(0.018, 0.036, TableView.to3(keep, 0.108), v)
	for k3 in 4:
		var a := TAU * k3 / 4.0 + 0.4
		v._box(Vector3(0.004, 0.009, 0.0018), TableView.to3(keep, 0.088) + Vector3(sin(a) * 0.015, 0, cos(a) * 0.015), _window).rotation.y = a
	# a banner on the keep
	v._cyl(0.0006, 0.022, TableView.to3(keep, 0.156), _iron)
	v._box(Vector3(0.012, 0.007, 0.0006), TableView.to3(keep, 0.163) + Vector3(0.006, 0, 0), v._lit(Color(0.9, 0.08, 0.08), 0.4))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.35)
	l.light_energy = 0.4
	l.omni_range = 0.12
	l.position = TableView.to3(Vector2(-0.2, 0.515), 0.02)
	v.add_child(l)


## The stone causeway up the right side, on piers, with a lantern row, the low
## wall that funnels shots onto it, and the gate arch into the mountain.
func _causeway(path: PackedVector3Array, split: int) -> void:
	var k := 0
	for i in split:
		var a := path[i]
		var b := path[i + 1]
		var seg := Vector2(b.y - a.y, b.z - a.z)
		var steps := maxi(1, int(round(seg.length() / 0.0125)))
		for j in steps:
			var p := a.lerp(b, (j + 0.5) / steps)
			var slab := v._box(Vector3(0.047, 0.0032, 0.012), TableView.to3(Vector2(p.x, p.y), p.z - 0.0016), _slabs[(k * 5 + k / 2) % _slabs.size()])
			slab.rotation.x = atan2(seg.y, seg.x)
			k += 1
	var y := 0.635
	var n := 0
	while y <= 0.781:
		var h := _height_at(path, y)
		if h > 0.012:        # a pier under the deck
			v._box(Vector3(0.05, h - 0.003, 0.011), TableView.to3(Vector2(0.18, y), (h - 0.003) * 0.5), _stone_dark)
		for side in [-1.0, 1.0]:
			v._box(Vector3(0.003, 0.006, 0.03), TableView.to3(Vector2(0.18 + side * 0.0245, y), h + 0.003), _stone)
			if n % 2 == 0:
				_lantern(Vector2(0.18 + side * 0.0245, y), h + 0.006, 0.014)
		y += 0.03
		n += 1
	# low stone wall along the funnel, with a lantern at each end
	for i4 in 9:
		var q := Vector2(0.045, 0.47).lerp(Vector2(0.155, 0.64), i4 / 8.0)
		var block := v._box(Vector3(0.007, 0.012 + 0.003 * (i4 % 2), 0.026), TableView.to3(q, 0.006), _stone)
		block.rotation.y = -atan2(0.11, 0.17)
	_lantern(Vector2(0.155, 0.64), 0.012, 0.02)
	# gate arch into the mountain
	for q3 in [Vector2(0.151, 0.803), Vector2(0.21, 0.806)]:
		v._box(Vector3(0.014, 0.12, 0.016), TableView.to3(q3, 0.06), _stone)
	v._box(Vector3(0.075, 0.014, 0.018), TableView.to3(Vector2(0.1805, 0.805), 0.127), _stone_dark)
	for bx in 4:
		v._box(Vector3(0.008, 0.007, 0.018), TableView.to3(Vector2(0.155 + bx * 0.017, 0.805), 0.1375), _stone)
	for q4 in [Vector2(0.151, 0.795), Vector2(0.21, 0.797)]:
		v._box(Vector3(0.005, 0.007, 0.002), TableView.to3(q4, 0.1), _window)


## The snowy peak at the back. Its cap glows pink, and flares when the ramp is made.
func _mountain() -> void:
	var base := TableView.to3(VOLCANO, VOLCANO_BASE)
	v._mesh(Parts.lathe(PackedVector2Array([Vector2(0.125, 0.0), Vector2(0.104, 0.03), Vector2(0.08, 0.07),
		Vector2(0.056, 0.108), Vector2(0.032, 0.146), Vector2(0.012, 0.168), Vector2(0.0, 0.172)]), 9), _rock, base)
	_lava = v._lit(Color(1.0, 0.5, 0.55), 0.5)
	_lava.albedo_color = Color(1.0, 0.94, 0.95)
	_lava.roughness = 0.6
	v._mesh(Parts.lathe(PackedVector2Array([Vector2(0.066, 0.094), Vector2(0.058, 0.108), Vector2(0.034, 0.146),
		Vector2(0.0135, 0.169), Vector2(0.0, 0.174)]), 9), _lava, base)
	for a in [0.5, 1.4, 2.3, 3.4]:       # snow gullies running down the rock
		v._mesh(Parts.tube(PackedVector3Array([base + Vector3(cos(a) * 0.062, 0.1, sin(a) * 0.062),
			base + Vector3(cos(a + 0.12) * 0.076, 0.078, sin(a + 0.12) * 0.076),
			base + Vector3(cos(a + 0.05) * 0.09, 0.055, sin(a + 0.05) * 0.09)]), 0.004, 5), _lava)
	_volcano_light = OmniLight3D.new()
	_volcano_light.light_color = Color(1.0, 0.55, 0.6)
	_volcano_light.light_energy = 0.3
	_volcano_light.omni_range = 0.4
	_volcano_light.position = base + Vector3(0, 0.2, 0.06)
	v.add_child(_volcano_light)
	var spark := SphereMesh.new()
	spark.radius = 0.003
	spark.height = 0.006
	spark.radial_segments = 6
	spark.rings = 4
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.albedo_color = Color(1.0, 0.8, 0.5)
	spark.material = spark_mat
	_burst = CPUParticles3D.new()
	_burst.mesh = spark
	_burst.amount = 80
	_burst.lifetime = 1.4
	_burst.one_shot = true
	_burst.emitting = false
	_burst.explosiveness = 0.9
	_burst.direction = Vector3.UP
	_burst.spread = 60.0
	_burst.gravity = Vector3(0, -0.5, 0)
	_burst.initial_velocity_min = 0.2
	_burst.initial_velocity_max = 0.55
	_burst.position = base + Vector3(0, 0.17, 0)
	v.add_child(_burst)


func _tree(at: Vector2, base: float, height: float, kind: int) -> void:
	var foot := TableView.to3(at, base)
	if kind == 2:        # a dark cypress
		v._cyl(0.0022, height * 0.25, foot + Vector3(0, height * 0.125, 0), _wood_dark)
		v._cyl(height * 0.2, height * 0.85, foot + Vector3(0, height * 0.6, 0), _foliage[2], v, 0.001)
		return
	v._cyl(0.003, height * 0.55, foot + Vector3(0, height * 0.275, 0), _wood_dark, v, 0.002)
	var top := foot + Vector3(0, height * 0.7, 0)
	for o in [Vector3.ZERO, Vector3(0.36, -0.12, 0.2), Vector3(-0.34, -0.1, 0.24), Vector3(0.05, 0.26, -0.1), Vector3(-0.1, -0.05, -0.36)]:
		var off: Vector3 = o
		_sphere(height * 0.3, 0.9, _foliage[kind], top + off * height * 0.75, v)


func _autumn() -> void:
	for side in [-1.0, 1.0]:
		_tree(Vector2(side * 0.225, 1.04), 0.034, 0.075, 0)
		_tree(Vector2(side * 0.185, 1.062), 0.034, 0.09, 1)
		_tree(Vector2(side * 0.243, 0.985), 0.034, 0.06, 1 if side > 0 else 0)
		_tree(Vector2(side * 0.15, 1.068), 0.034, 0.07, 2)
		_sphere(0.02, 0.7, _rock, TableView.to3(Vector2(side * 0.205, 0.995), 0.04), v)
		_lantern(Vector2(side * 0.168, 1.01), 0.034, 0.03)
	# trees and rocks by the castle and at the foot of the causeway
	_tree(Vector2(-0.245, 0.60), 0.0, 0.05, 2)
	_sphere(0.008, 0.7, _rock, TableView.to3(Vector2(-0.172, 0.458), 0.003), v)
	_sphere(0.007, 0.7, _rock, TableView.to3(Vector2(0.142, 0.432), 0.0025), v)


# ------------------------------------------------------------------ runtime

func sync(delta: float, time: float) -> void:
	_erupt = maxf(0.0, _erupt - delta * 0.6)
	_flame.emission_energy_multiplier = 1.7 + 0.35 * sin(time * 13.0) * sin(time * 5.1)
	_lava.emission_energy_multiplier = 0.45 + 0.15 * sin(time * 0.9) + _erupt * 3.5
	if _volcano_light != null:
		_volcano_light.light_energy = 0.3 + 0.1 * sin(time * 0.9) + _erupt * 3.0
