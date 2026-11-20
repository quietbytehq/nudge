extends SceneTree
## Headless physics checks:  godot --headless -s tests/sim_test.gd

const P := preload("res://scripts/pin_physics.gd")
const L := preload("res://scripts/table_layout.gd")
const DT := 1.0 / 120.0

var fails := 0


func _init() -> void:
	for id in ["deep_space", "paradise_bay"]:
		print("===== table: ", id)
		L.table_id = id
		test_launch()
		test_weak_launch()
		test_flipper_shot()
		test_cradle()
		test_chaos()
		test_frame_rate_independence()
	print("RESULT: ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		fails += 1


func world() -> PinPhysics:
	var p := P.new()
	L.build(p)
	return p


func in_bounds(b) -> bool:
	if is_nan(b.pos.x) or is_nan(b.pos.y):
		return false
	return absf(b.pos.x) <= 0.2555 - 0.013 and b.pos.y <= 1.0705 - 0.013


func test_launch() -> void:
	print("launch (full power)")
	var p := world()
	var b := p.add_ball(L.BALL_START)
	for i in 60:
		step_all(p)
	check(b.pos.distance_to(L.BALL_START) < 0.002 and b.vel.length() < 0.02, "ball rests on the plunger")
	b.vel = Vector2(0, 3.5)
	var ok := true
	var left_lane := false
	var max_y := 0.0
	for i in 600:
		step_all(p)
		ok = ok and (in_bounds(b) or not b.active)
		max_y = maxf(max_y, b.pos.y)
		if b.pos.x < L.LANE_X - 0.02:
			left_lane = true
	check(ok, "ball stayed inside the table")
	check(left_lane, "ball left the shooter lane (max y %.3f)" % max_y)


func test_weak_launch() -> void:
	print("launch (weak)")
	var p := world()
	var b := p.add_ball(L.BALL_START, Vector2(0, 1.0))
	for i in 720:
		step_all(p)
	check(b.pos.distance_to(L.BALL_START) < 0.004, "weak launch rolls back to the plunger")


func test_flipper_shot() -> void:
	print("flipper shot")
	# The table is full of obstacles, so judge the flipper by the speed it
	# gives the ball rather than by how far the ball happens to travel.
	var best := 0.0
	var speeds := []
	for k in 7:
		var p := world()
		var f = p.flippers[0]
		var x: float = f.pivot.x + 0.02 + 0.007 * k
		var b := p.add_ball(Vector2(x, 0.22))
		var top := 0.0
		var flipped := false
		for i in 240:
			if not flipped and b.pos.y < 0.16 and b.vel.y < 0:
				p.set_flipper(0, true)
				flipped = true
			step_all(p)
			if flipped and b.vel.y > 0.0:
				top = maxf(top, b.vel.length())
		best = maxf(best, top)
		speeds.append("%.1f" % top)
	print("    launch speeds by contact point (m/s): ", speeds)
	check(best > 2.5, "a flipper shot launches the ball hard (best %.1f m/s)" % best)


func test_cradle() -> void:
	print("cradle")
	var p := world()
	p.set_flipper(0, true)
	var b := p.add_ball(Vector2(-0.195, 0.28))
	for i in 720:
		step_all(p)
	check(b.active and b.vel.length() < 0.03, "ball settles on a raised flipper (speed %.3f)" % b.vel.length())
	check(b.pos.y > 0.12 and b.pos.y < 0.2, "ball is held in the cradle (y %.3f)" % b.pos.y)
	# Release, let the ball roll towards the tip, then flip. Timing sets the shot.
	var peaks := []
	var best := 0.0
	for delay in [40, 55, 70, 85, 100]:
		var q := world()
		q.set_flipper(0, true)
		var c := q.add_ball(b.pos)
		for i in 120:
			step_all(q)
		q.set_flipper(0, false)
		for i in delay:
			step_all(q)
		q.set_flipper(0, true)
		var top := 0.0
		for i in 360:
			step_all(q)
			top = maxf(top, c.pos.y)
		peaks.append("%.2f" % top)
		best = maxf(best, top)
	print("    peak heights by release delay: ", peaks)
	check(best > 0.4, "ball can be shot from a cradle (best %.2f m)" % best)


## Steps the world; a ball taken by the ramp is put down where the rail ends,
## as the game does after the ride.
func step_all(w: P) -> void:
	w.step(DT)
	for b in w.balls:
		if b.active and b.held:
			b.held = false
			b.pos = Vector2(-0.1935, 0.30)
			b.prev = b.pos
			b.vel = Vector2(0.0, -0.55)


func test_chaos() -> void:
	print("chaos (3 balls, 5 simulated minutes, random flipping)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var p := world()
	var ok := true
	var counts := {}
	var max_speed := 0.0
	var drains := 0
	var stuck := 0
	var rescues := 0
	var t0 := Time.get_ticks_usec()
	for i in 120 * 300:
		if p.active_balls().size() < 3:
			var at := Vector2(rng.randf_range(-0.2, 0.15), rng.randf_range(0.45, 0.9))
			var v0 := Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2))
			if not L.is_solid(at):
				p.add_ball(at, v0)
		if i % 12 == 0:
			p.set_flipper(0, rng.randf() < 0.4)
			p.set_flipper(1, rng.randf() < 0.4)
		step_all(p)
		for b in p.balls:
			if b.active:
				ok = ok and in_bounds(b)
				max_speed = maxf(max_speed, b.vel.length())
				# same rescue the game applies to a ball balanced on a post
				if b.still_time > 4.0 and b.still_time < 4.0 + DT:
					rescues += 1
					print("    rest at (%.3f, %.3f)" % [b.pos.x, b.pos.y])
					b.vel = Vector2(rng.randf_range(-0.3, 0.3), 0.4)
				if b.still_time > 8.0:
					stuck += 1
					b.active = false
		for e in p.events:
			counts[e[0]] = counts.get(e[0], 0) + 1
			if e[0] == P.Ev.DRAIN:
				drains += 1
		p.events.clear()
		if p.balls.size() > 40:
			p.balls = p.active_balls()
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var names := P.Ev.keys()
	var out := {}
	for k in counts:
		out[names[k]] = counts[k]
	print("    events: ", out)
	print("    max speed %.2f m/s, drains %d, rescues %d, stuck %d, cpu %.0f ms for 300 s (%.2f%% of real time)" % [max_speed, drains, rescues, stuck, ms, ms / 3000.0])
	check(ok, "no ball ever escaped the table")
	check(stuck == 0, "no ball got stuck")
	check(drains > 10, "balls drain normally")
	for need in [P.Ev.BUMPER, P.Ev.SLING, P.Ev.TARGET, P.Ev.SENSOR, P.Ev.FLIPPER]:
		check(counts.get(need, 0) > 0, "%s events occur" % names[need])


func test_frame_rate_independence() -> void:
	print("fixed step")
	# The game always steps physics at 120 Hz regardless of rendering rate, so
	# identical inputs must give identical results run to run.
	var res := []
	for run in 2:
		var p := world()
		var b := p.add_ball(L.BALL_START, Vector2(0, 3.2))
		for i in 480:
			step_all(p)
		res.append(b.pos)
	check(res[0] == res[1], "simulation is deterministic")
