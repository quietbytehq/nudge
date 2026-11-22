class_name TableLayout
extends RefCounted
## Table layouts. Table one ("Cosmic Drift") is described first. Coordinates are metres on the playfield
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
## Which table to build, and where its ball-swallowing feature sits.
static var table_id := "deep_space"
static var HOLE := Vector2(-0.025, 0.63)

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
const S_RAMP := 40
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
	if table_id == "paradise_bay" or table_id == "alpenglow":
		HOLE = Vector2(-0.225, 0.518)
		_build_paradise(p)
		return
	if table_id == "palace_night":
		HOLE = Vector2(-0.025, 0.612)
		_build_paradise(p)
		return
	HOLE = Vector2(-0.025, 0.63)
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


## Table two, "Paradise Bay". Laid out after the concept painting: beach-ball
## and coconut bumpers at the top, a row of five surfboards across the middle,
## the tiki hut on the left, and the wooden pier on the right, which is a ramp
## the ball rides up, through the volcano and down a wire rail to the left
## inlane. A third flipper sits above the hut.
static func _build_paradise(p: PinPhysics) -> void:
	var K := PinPhysics.Kind
	var hw := W * 0.5
	var post := POST_ID
	# Palace Night shares the ramp and the target row, but has no third flipper
	# and no wall pocket: its genie-lamp saucer sits at the head of the pool
	var palace := table_id == "palace_night"

	# Outer walls, shooter lane, top arch and one-way gate
	p.add_seg(Vector2(-hw, -0.06), Vector2(-hw, ARC_C.y))
	p.add_seg(Vector2(hw, 0.0), Vector2(hw, ARC_C.y))
	p.add_seg(Vector2(LANE_X, -0.06), Vector2(LANE_X, 0.78))
	p.add_seg(Vector2(LANE_X, 0.06), Vector2(hw, 0.06))
	p.set_arc(ARC_C, ARC_R)
	var a50 := deg_to_rad(50.0)
	p.add_seg(Vector2(LANE_X, 0.78), ARC_C + Vector2(cos(a50), sin(a50)) * ARC_R, K.GATE)

	# Orbit lanes; the left one has the spinner and feeds the third flipper
	_arc(p, 0.195, 105.0, 165.0, 8)
	var l165 := ARC_C + Vector2(cos(deg_to_rad(165.0)), sin(deg_to_rad(165.0))) * 0.195
	p.add_seg(l165, Vector2(l165.x, 0.77))
	_arc(p, 0.195, 42.0, 75.0, 5)
	p.add_circ(Vector2(l165.x, 0.762), 0.008, K.POST, post)
	post += 1
	p.add_sensor(Rect2(-hw, 0.78, hw + l165.x, 0.03), S_SPINNER)
	p.add_sensor(Rect2(0.10, 0.96, 0.05, 0.05), S_ORBIT_R)

	# Lower playfield, built for the left and mirrored to the right
	for side in 2:
		var m := side == 1
		var f := func(x: float, y: float) -> Vector2:
			return Vector2(mx(x) if m else x, y)
		p.add_seg(f.call(-0.255, 0.40), f.call(-0.222, 0.335))
		p.add_seg(f.call(-0.215, 0.295), f.call(-0.215, 0.19))
		p.add_seg(f.call(-0.215, 0.19), f.call(-0.1092, 0.1371))
		p.add_circ(f.call(-0.215, 0.30), 0.007, K.POST, post)
		post += 1
		p.add_seg(f.call(-0.172, 0.33), f.call(-0.172, 0.212), K.RUBBER)
		p.add_seg(f.call(-0.172, 0.212), f.call(-0.118, 0.185), K.RUBBER)
		p.add_seg(f.call(-0.118, 0.185), f.call(-0.172, 0.33), K.SLING, side)
		# tiki torches (lit posts) on the sand and in the shallows
		p.add_seg(f.call(XC - 0.19, 0.19), f.call(XC - 0.19, 0.03))
		var inl := Rect2(Vector2(-0.215, 0.22), Vector2(0.043, 0.04))
		var outl := Rect2(Vector2(-0.255, 0.20), Vector2(0.04, 0.04))
		if m:
			inl = Rect2(Vector2(mx(-0.172), 0.22), Vector2(0.043, 0.04))
			outl = Rect2(Vector2(mx(-0.215), 0.20), Vector2(0.04, 0.04))
		p.add_sensor(inl, S_INLANE_R if m else S_INLANE_L)
		p.add_sensor(outl, S_OUTLANE_R if m else S_OUTLANE_L)
	p.add_circ(Vector2(XC, 0.05), 0.007, K.POST, post)
	post += 1
	# tiki torches (lit posts) on the islets in the lagoon, clear of the shot lines
	for q in [Vector2(0.045, 0.47)]:
		p.add_circ(q, 0.007, K.POST, post)
		post += 1
	# two angled shell targets that split the lagoon into shot lanes
	p.add_seg(Vector2(-0.112, 0.385), Vector2(-0.094, 0.415), K.TARGET, 5)
	p.add_seg(Vector2(0.057, 0.385), Vector2(0.039, 0.415), K.TARGET, 6)

	# Main flippers, then the third one above the tiki hut with its feed guide
	p.add_flipper(Vector2(XC - FLIP_DX, FLIP_Y), -28.0, 28.0, 0)
	p.add_flipper(Vector2(XC + FLIP_DX, FLIP_Y), 208.0, 152.0, 1)
	if palace:
		# genie lamp saucer at the head of the pool, with a post either side
		p.add_sensor(Rect2(HOLE - Vector2(0.012, 0.012), Vector2(0.024, 0.024)), S_HOLE)
		for sg in [-1.0, 1.0]:
			p.add_circ(HOLE + Vector2(sg * 0.048, 0.018), 0.007, K.POST, post)
			post += 1
	else:
		var upper := p.add_flipper(Vector2(-0.19, 0.665), -28.0, 28.0, 2)
		upper.length = 0.058
		p.add_seg(Vector2(-hw, 0.705), Vector2(-0.1862, 0.6721))

		# Tiki hut: a pocket in the left wall that holds the ball, then kicks it out
		p.add_seg(Vector2(-hw, 0.565), Vector2(-0.168, 0.546))
		p.add_seg(Vector2(-hw, 0.487), Vector2(-0.20, 0.475))
		p.add_sensor(Rect2(HOLE - Vector2(0.025, 0.025), Vector2(0.05, 0.05)), S_HOLE)

	# Surfboard row across the lagoon, backed by a peaked rail so that balls
	# coming down from the bumpers roll off to either side
	for i in 5:
		var x0 := -0.125 + i * 0.04
		p.add_seg(Vector2(x0, 0.69), Vector2(x0 + 0.04, 0.69), K.TARGET, i)
	p.add_seg(Vector2(-0.125, 0.69), Vector2(-0.125, 0.70))
	p.add_seg(Vector2(0.075, 0.69), Vector2(0.075, 0.70))
	p.add_seg(Vector2(-0.125, 0.70), Vector2(-0.025, 0.735))
	p.add_seg(Vector2(-0.025, 0.735), Vector2(0.075, 0.70))

	# Beach-ball and coconut bumpers
	p.add_circ(Vector2(-0.128, 0.79), 0.026, K.BUMPER, 0)
	p.add_circ(Vector2(-0.055, 0.82), 0.028, K.BUMPER, 1)
	p.add_circ(Vector2(0.025, 0.795), 0.028, K.BUMPER, 2)
	p.add_circ(Vector2(0.105, 0.825), 0.026, K.BUMPER, 3)
	# near-side bumpers, tucked between the shot lanes: a tiki drum below the
	# hut, a harbour buoy at the foot of the jetty, a rock islet in the lagoon
	p.add_circ(Vector2(-0.214, 0.412), 0.02, K.BUMPER, 4)
	p.add_circ(Vector2(0.16, 0.388), 0.02, K.BUMPER, 5)
	p.add_seg(Vector2(-hw, 0.455), Vector2(-0.2275, 0.4285))   # no gap between the drum and the wall
	p.add_seg(Vector2(LANE_X, 0.445), Vector2(0.173, 0.405))     # nor between the buoy and the lane wall
	p.add_circ(Vector2(-0.125, 0.515), 0.02, K.BUMPER, 6)

	# The pier ramp. A jetty runs out into the lagoon and funnels shots from
	# the left flipper into the pier along the right side. A ball still moving
	# up-table fast enough at the foot of the pier is taken onto the ramp; a
	# slow one rolls back out along the jetty.
	p.add_seg(Vector2(0.045, 0.47), Vector2(0.155, 0.64))
	p.add_seg(Vector2(0.155, 0.64), Vector2(0.155, 0.782))
	p.add_seg(Vector2(0.155, 0.782), Vector2(LANE_X, 0.80))
	p.add_seg(Vector2(0.155, 0.70), Vector2(LANE_X, 0.70))
	p.add_sensor(Rect2(0.16, 0.61, 0.043, 0.05), S_RAMP)
	p.sensors[p.sensors.size() - 1].min_vy = 0.9

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
	p.add_sensor(Rect2(LANE_X, 0.06, hw - LANE_X, 0.06), S_LANE)


## True for points inside closed-off parts of the table where no ball can be
## (behind the surfboard row, inside the ramp lane beyond its back wall).
static func is_solid(q: Vector2) -> bool:
	if table_id == "deep_space":
		return false
	if q.x > -0.15 and q.x < 0.10 and q.y > 0.675 and q.y < 0.76:
		return true
	return q.x > 0.14 and q.y > 0.55 and q.y < 0.81


## Centre line of the Paradise Bay ramp as (x, y, height): up the pier, through
## the volcano at the back, then down the wire rail to the left inlane.
static func ramp_path() -> PackedVector3Array:
	var key := [Vector3(0.180, 0.60, 0.0), Vector3(0.180, 0.64, 0.008), Vector3(0.180, 0.70, 0.034),
		Vector3(0.180, 0.76, 0.064), Vector3(0.178, 0.80, 0.082),
		Vector3(0.165, 0.87, 0.088), Vector3(0.135, 0.94, 0.090), Vector3(0.085, 0.995, 0.090),
		Vector3(0.02, 1.02, 0.090), Vector3(-0.06, 1.015, 0.090), Vector3(-0.13, 0.985, 0.090),
		Vector3(-0.19, 0.93, 0.089), Vector3(-0.228, 0.86, 0.087), Vector3(-0.243, 0.78, 0.085),
		Vector3(-0.245, 0.66, 0.080), Vector3(-0.245, 0.52, 0.070), Vector3(-0.243, 0.42, 0.052),
		Vector3(-0.232, 0.36, 0.034), Vector3(-0.212, 0.325, 0.018), Vector3(-0.1935, 0.30, 0.004)]
	var out := PackedVector3Array()
	for i in key.size() - 1:
		var p0: Vector3 = key[maxi(i - 1, 0)]
		var p1: Vector3 = key[i]
		var p2: Vector3 = key[i + 1]
		var p3: Vector3 = key[mini(i + 2, key.size() - 1)]
		for j in 6:
			out.append(p1.cubic_interpolate(p2, p0, p3, j / 6.0))
	out.append(key[key.size() - 1])
	return out
