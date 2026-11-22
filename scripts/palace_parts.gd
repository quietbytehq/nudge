class_name PalaceParts
extends AlpenglowParts
## Themed 3D parts for Palace Night: an Arabian palace garden by moonlight.
## Painted lantern, jar, pavilion and fountain bumpers, five jewel-coloured
## doors as the target row, the genie lamp over the saucer, a red-carpet ramp
## up the right side and the palace at the back, whose domes glow when the
## ramp is made. Builds on AlpenglowParts for the ramp deck, rail and backdrop.


func _init(view: TableView) -> void:
	super(view)
	# white marble and sapphire tile instead of stone; a red and gold carpet deck
	_stone = _noisy(Color(0.78, 0.76, 0.72), Color(0.95, 0.93, 0.88), 0.012, 0.6)
	_stone_dark = _noisy(Color(0.08, 0.16, 0.42), Color(0.18, 0.32, 0.7), 0.012, 0.5)
	_iron = v._mat(Color(0.75, 0.55, 0.2), 0.9, 0.3)
	_slabs.clear()
	for c in [Color(0.62, 0.06, 0.08), Color(0.55, 0.05, 0.07), Color(0.85, 0.62, 0.18)]:
		_slabs.append(v._mat(c, 0.0, 0.7))


func bumper(c: PinPhysics.Circ, kind: String, root: Node3D) -> Array:
	var order := ["lantern", "jar", "pavilion", "fountain"]
	var heights := [0.085, 0.08, 0.08, 0.06]
	var idx := order.find(kind)
	if idx < 0:
		return super(c, kind, root)
	var r := c.r
	v._cyl(r * 1.36, 0.0008, Vector3(0, 0.0004, 0), v._m_black, root)
	v._mesh(Parts.lathe(PackedVector2Array([Vector2(r * 1.2, 0.0005), Vector2(r * 1.2, 0.003),
		Vector2(r * 0.98, 0.0065), Vector2(r * 0.8, 0.0065), Vector2(r * 0.8, 0.013)]), 40), v._m_white, Vector3.ZERO, root)
	var ring := v._torus(r * 1.0, 0.0022, Vector3(0, 0.014, 0), v._m_chrome, root)
	var cols := [Color(1.0, 0.7, 0.3), Color(0.35, 0.6, 1.0), Color(1.0, 0.85, 0.45), Color(0.4, 0.85, 1.0)]
	var m := v._lit(cols[idx], 0.1)
	v._torus(r * 1.15, 0.0018, Vector3(0, 0.003, 0), m, root)
	sprite("bump_%d.png" % idx, Vector3(0, 0.004, 0), heights[idx] * (r / 0.024), root)
	return [m, ring]


func shell_lamp(at: Vector2, col: Color, energy: float, r: float) -> StandardMaterial3D:
	var m := super(at, col, energy, r)
	m.emission = Color(1.0, 0.75, 0.3).lerp(Color(0.3, 0.5, 1.0), 0.35)
	return m


func features() -> void:
	var path := TableLayout.ramp_path()
	var split := 0
	for i in path.size():
		if path[i].y <= 0.80:
			split = i
		else:
			break
	_causeway(path, split)
	_rail(path, split)
	_mountain()          # the palace at the back (mountain.png holds the palace art)
	_autumn()            # the garden: cypress and palm trees, a pavilion, lanterns
	_genie()


## Nothing in the left wall on this table: the lamp saucer is at the head of the pool.
func _castle() -> void:
	pass


## The genie lamp behind the saucer, and the flying carpet hovering over the ramp.
func _genie() -> void:
	var hole := TableLayout.HOLE
	sprite("lamp.png", TableView.to3(hole + Vector2(0.0, 0.034), 0.0), 0.045, v)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.4, 0.7, 1.0)
	glow.light_energy = 0.35
	glow.omni_range = 0.12
	glow.position = TableView.to3(hole + Vector2(0.0, 0.03), 0.04)
	v.add_child(glow)
	sprite("carpet.png", TableView.to3(Vector2(0.11, 0.985), 0.13), 0.06, v)
