class_name TableLayout
extends RefCounted
## Table one layout ("Deep Space"). Coordinates are metres on the playfield
## plane (x right, y up-table) and are placed to sit on the printed artwork:
## sun at the top, black hole in the middle, Jupiter left, Saturn right,
## Earth between the flippers.

const W := 0.51              # playfield width
const H := 1.07              # playfield length
const LANE_X := 0.205        # inner wall of the shooter lane
const XC := -0.025           # centre line of the main playfield
const FLIP_Y := 0.13
const FLIP_DX := 0.088
const ARC_C := Vector2(0.0, 0.815)
const ARC_R := 0.255
const BALL_START := Vector2(0.23, 0.0745)
const HOLE := Vector2(-0.025, 0.63)

# Sensor ids
const S_TOP := [0, 1, 2]
const S_INLANE_L := 10
const S_INLANE_R := 11
const S_OUTLANE_L := 12
const S_OUTLANE_R := 13
const S_LANE := 20
const S_HOLE := 30
const S_SPINNER := 31
const S_ORBIT_R := 32
# Lit posts use ids from POST_ID upwards
const POST_ID := 100


static func mx(x: float) -> float:
	return 2.0 * XC - x


static func _arc(p: PinPhysics, r: float, a0: float, a1: float, steps: int) -> void:
	for i in steps:
		var t0 := deg_to_rad(lerpf(a0, a1, float(i) / steps))
		var t1 := deg_to_rad(lerpf(a0, a1, float(i + 1) / steps))
		p.add_seg(ARC_C + Vector2(cos(t0), sin(t0)) * r, ARC_C + Vector2(cos(t1), sin(t1)) * r)


static func build(p: PinPhysics) -> void:
	var K := PinPhysics.Kind
	var hw := W * 0.5
	var post := POST_ID

	# Outer walls, shooter lane and top arch
	p.add_seg(Vector2(-hw, -0.06), Vector2(-hw, ARC_C.y))
	p.add_seg(Vector2(hw, 0.0), Vector2(hw, ARC_C.y))
	p.add_seg(Vector2(LANE_X, -0.06), Vector2(LANE_X, 0.78))
	p.add_seg(Vector2(LANE_X, 0.06), Vector2(hw, 0.06))
	p.set_arc(ARC_C, ARC_R)
	# One-way gate: lets the launched ball out, stops it falling back in
	var a50 := deg_to_rad(50.0)
	p.add_seg(Vector2(LANE_X, 0.78), ARC_C + Vector2(cos(a50), sin(a50)) * ARC_R, K.GATE)

	# Orbit lanes: inner guide rails that follow the arch
	_arc(p, 0.195, 105.0, 165.0, 8)
	var l165 := ARC_C + Vector2(cos(deg_to_rad(165.0)), sin(deg_to_rad(165.0))) * 0.195
	p.add_seg(l165, Vector2(l165.x, 0.72))
	_arc(p, 0.195, 42.0, 75.0, 5)
	p.add_circ(Vector2(l165.x, 0.712), 0.008, K.POST, post)
	post += 1
	p.add_sensor(Rect2(-hw, 0.78, hw + l165.x, 0.03), S_SPINNER)
	p.add_sensor(Rect2(0.10, 0.96, 0.05, 0.05), S_ORBIT_R)

	# Lower playfield, built for the left and mirrored to the right
	for side in 2:
		var m := side == 1
		var f := func(x: float, y: float) -> Vector2:
			return Vector2(mx(x) if m else x, y)
		# outlane deflector, inlane guide
		p.add_seg(f.call(-0.255, 0.40), f.call(-0.222, 0.335))
		p.add_seg(f.call(-0.215, 0.295), f.call(-0.215, 0.19))
		# ends flush with the top surface of the resting flipper so the ball rolls on cleanly
		p.add_seg(f.call(-0.215, 0.19), f.call(-0.1092, 0.1371))
		p.add_circ(f.call(-0.215, 0.30), 0.007, K.POST, post)
		post += 1
		# slingshot triangle
		p.add_seg(f.call(-0.172, 0.33), f.call(-0.172, 0.212), K.RUBBER)
		p.add_seg(f.call(-0.172, 0.212), f.call(-0.118, 0.185), K.RUBBER)
		p.add_seg(f.call(-0.118, 0.185), f.call(-0.172, 0.33), K.SLING, side)
		# stand-up target bank on the side wall, with a guard post above it
		for i in 3:
			var y0 := 0.50 + i * 0.05
			p.add_seg(f.call(-0.249, y0), f.call(-0.249, y0 + 0.035), K.TARGET, side * 3 + i)
		p.add_circ(f.call(-0.205, 0.67), 0.008, K.POST, post)
		post += 1
		# planet bumper (Jupiter on the left, Saturn on the right)
		p.add_circ(f.call(-0.16, 0.44), 0.026, K.BUMPER, 3 + side)
		# angled stand-up target between the planet and the centre
		p.add_seg(f.call(-0.105, 0.365), f.call(-0.085, 0.40), K.TARGET, 8 + side)
		p.add_circ(f.call(-0.108, 0.358), 0.007, K.POST, post)
		post += 1
		# event-horizon posts around the black hole
		p.add_circ(f.call(HOLE.x - 0.068, HOLE.y + 0.028), 0.008, K.POST, post)
		post += 1
		p.add_circ(f.call(HOLE.x - 0.058, HOLE.y - 0.048), 0.008, K.POST, post)
		post += 1
		# lane sensors
		var inl := Rect2(Vector2(-0.215, 0.22), Vector2(0.043, 0.04))
		var outl := Rect2(Vector2(-0.255, 0.20), Vector2(0.04, 0.04))
		if m:
			inl = Rect2(Vector2(mx(-0.172), 0.22), Vector2(0.043, 0.04))
			outl = Rect2(Vector2(mx(-0.215), 0.20), Vector2(0.04, 0.04))
		p.add_sensor(inl, S_INLANE_R if m else S_INLANE_L)
		p.add_sensor(outl, S_OUTLANE_R if m else S_OUTLANE_L)

	# Flippers
	p.add_flipper(Vector2(XC - FLIP_DX, FLIP_Y), -28.0, 28.0, 0)
	p.add_flipper(Vector2(XC + FLIP_DX, FLIP_Y), 208.0, 152.0, 1)

	# Sun bumpers
	p.add_circ(Vector2(-0.105, 0.80), 0.028, K.BUMPER, 0)
	p.add_circ(Vector2(0.055, 0.80), 0.028, K.BUMPER, 1)
	p.add_circ(Vector2(XC, 0.735), 0.028, K.BUMPER, 2)

	# Black hole saucer and the chevron target bank that guards it from below
	p.add_sensor(Rect2(HOLE - Vector2(0.011, 0.011), Vector2(0.022, 0.022)), S_HOLE)
	p.add_seg(Vector2(XC - 0.052, 0.497), Vector2(XC - 0.004, 0.523), K.TARGET, 6)
	p.add_seg(Vector2(XC + 0.004, 0.523), Vector2(XC + 0.052, 0.497), K.TARGET, 7)
	p.add_circ(Vector2(XC, 0.526), 0.007, K.POST, post)
	post += 1

	# Asteroid belt: lit posts across the middle, and a centre post below the flippers
	for q in [Vector2(XC - 0.06, 0.455), Vector2(XC, 0.47), Vector2(XC + 0.06, 0.455), Vector2(XC, 0.05)]:
		p.add_circ(q, 0.007, K.POST, post)
		post += 1
	# Rebound posts above the slingshots and beside the chevron targets
	for sg in [-1.0, 1.0]:
		for q in [Vector2(XC + sg * 0.085, 0.295), Vector2(XC + sg * 0.10, 0.515)]:
			p.add_circ(q, 0.007, K.POST, post)
			post += 1
		# closes off the dead corner under each inlane guide (covered by a plastic)
		p.add_seg(Vector2(XC + sg * 0.19, 0.19), Vector2(XC + sg * 0.19, 0.03))
	# Pulsar bumper in the upper right
	p.add_circ(Vector2(0.13, 0.85), 0.018, K.BUMPER, 7)
	# Moons: small bumpers beside the black hole, and angled target pairs beside the sun
	for side in 2:
		var sg := -1.0 if side == 0 else 1.0
		p.add_circ(Vector2(XC + sg * 0.145, 0.585), 0.018, K.BUMPER, 5 + side)
		var t0 := Vector2(XC + sg * 0.115, 0.695)
		var t1 := Vector2(XC + sg * 0.106, 0.716)
		var t2 := Vector2(XC + sg * 0.097, 0.737)
		p.add_seg(t0, t1, K.TARGET, 10 + side * 2)
		p.add_seg(t1, t2, K.TARGET, 11 + side * 2)

	# Top rollover lanes
	p.add_seg(Vector2(-0.065, 0.89), Vector2(-0.065, 0.95))
	p.add_seg(Vector2(0.015, 0.89), Vector2(0.015, 0.95))
	p.add_circ(Vector2(-0.065, 0.885), 0.006, K.POST, post)
	post += 1
	p.add_circ(Vector2(0.015, 0.885), 0.006, K.POST, post)
	post += 1
	var lane_x := [-0.105, -0.025, 0.055]
	for i in 3:
		p.add_sensor(Rect2(lane_x[i] - 0.02, 0.90, 0.04, 0.04), S_TOP[i])

	# Shooter lane rest area
	p.add_sensor(Rect2(LANE_X, 0.06, hw - LANE_X, 0.06), S_LANE)


## Outlines of the raised plastic covers: slingshots, outlane shields and the
## two corner pieces behind the arch. Each entry is [outline, bevel].
static func plastics() -> Array:
	var out: Array = []
	for side in 2:
		var pts := [Vector2(-0.178, 0.342), Vector2(-0.178, 0.204), Vector2(-0.108, 0.176)]
		var shield := [Vector2(-0.255, 0.425), Vector2(-0.255, 0.345), Vector2(-0.232, 0.345), Vector2(-0.225, 0.40)]
		var a := PackedVector2Array()
		var b := PackedVector2Array()
		for q in pts:
			a.append(Vector2(mx(q.x) if side == 1 else q.x, q.y))
		for q in shield:
			b.append(Vector2(mx(q.x) if side == 1 else q.x, q.y))
		out.append([a, 0.003])
		out.append([b, 0.002])
	# covers over the dead corners beside the flippers
	for sg in [-1.0, 1.0]:
		var blk := PackedVector2Array([Vector2(XC + sg * 0.188, 0.186), Vector2(XC + sg * 0.091, 0.133),
			Vector2(XC + sg * 0.091, 0.04), Vector2(XC + sg * 0.188, 0.04)])
		out.append([blk, 0.003])
	# corners outside the arch
	for side in 2:
		var sg := -1.0 if side == 0 else 1.0
		var c := PackedVector2Array()
		c.append(Vector2(sg * 0.26, H + 0.012))
		c.append(Vector2(sg * 0.26, ARC_C.y + 0.05))
		for i in 9:
			var ang := deg_to_rad(lerpf(14.0, 80.0, i / 8.0))
			c.append(ARC_C + Vector2(sg * cos(ang), sin(ang)) * (ARC_R + 0.004))
		c.append(Vector2(sg * 0.04, H + 0.012))
		out.append([c, 0.0])
	return out
