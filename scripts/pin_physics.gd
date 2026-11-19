class_name PinPhysics
extends RefCounted
## Custom fixed-step pinball physics.
##
## The ball is simulated on the playfield plane (x = left/right, y = up the
## table, metres). Gravity is the component of real gravity along a 6.5 degree
## slope for a rolling sphere. Everything is sub-stepped so the ball never moves
## more than a fraction of its radius per step, which rules out tunnelling.
## This class is the single authority on ball position: rendering, camera,
## sound and effects only read from it and react to its events.

const BALL_R := 0.0135
const GRAVITY := 0.793        # 9.81 * sin(6.5 deg) * 5/7 (rolling sphere)
const SUBSTEPS := 8
const MAX_SPEED := 7.0
const REST_THRESH := 0.2      # impacts slower than this do not bounce
const CELL := 0.05
const GRID_W := 64

const FLIP_UP_SPEED := 30.0   # rad/s
const FLIP_DOWN_SPEED := 16.0

enum Kind { WALL, RUBBER, SLING, TARGET, BUMPER, POST, GATE }
enum Ev { WALL, RUBBER, SLING, TARGET, BUMPER, FLIPPER, BALL, DRAIN, SENSOR, FLIP_UP, FLIP_DOWN }


class Seg:
	var a: Vector2
	var b: Vector2
	var kind: int = 0
	var id: int = -1
	var e: float = 0.4
	var mu: float = 0.06
	var kick: float = 0.0
	var one_way: bool = false
	var n: Vector2 = Vector2.ZERO


class Circ:
	var c: Vector2
	var r: float
	var kind: int = 0
	var id: int = -1
	var e: float = 0.6
	var mu: float = 0.06
	var kick: float = 0.0


class Flipper:
	var pivot: Vector2
	var length: float = 0.072
	var radius: float = 0.008
	var rest: float = 0.0
	var up: float = 0.0
	var angle: float = 0.0
	var prev_angle: float = 0.0
	var omega: float = 0.0
	var pressed: bool = false
	var id: int = 0

	func tip() -> Vector2:
		return pivot + Vector2(cos(angle), sin(angle)) * length


class Ball:
	var pos: Vector2
	var prev: Vector2
	var vel: Vector2 = Vector2.ZERO
	var active: bool = true
	var id: int = 0
	var sensors: Dictionary = {}
	var still_time: float = 0.0
	var held: bool = false       # captured by a saucer; frozen in place


class Sensor:
	var rect: Rect2
	var id: int = 0


var segs: Array[Seg] = []
var circs: Array[Circ] = []
var flippers: Array[Flipper] = []
var balls: Array[Ball] = []
var sensors: Array[Sensor] = []
var events: Array = []          # each: [Ev, Vector2 pos, float strength, int id]

var has_arc := false
var arc_c := Vector2.ZERO
var arc_r := 0.0
var drain_y := -0.03

var _grid: Dictionary = {}
var _next_ball_id := 0


# ---------------------------------------------------------------- building

func add_seg(a: Vector2, b: Vector2, kind: int = Kind.WALL, id: int = -1) -> Seg:
	var s := Seg.new()
	s.a = a
	s.b = b
	s.kind = kind
	s.id = id
	match kind:
		Kind.RUBBER:
			s.e = 0.7
			s.mu = 0.12
		Kind.SLING:
			s.e = 0.7
			s.mu = 0.12
			s.kick = 1.1
		Kind.TARGET:
			s.e = 0.55
		Kind.GATE:
			s.e = 0.3
			s.one_way = true
			var d := (b - a).normalized()
			s.n = Vector2(-d.y, d.x)
	segs.append(s)
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * (BALL_R + 0.004)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * (BALL_R + 0.004)
	_grid_insert(lo, hi, s)
	return s


func add_circ(c: Vector2, r: float, kind: int = Kind.POST, id: int = -1) -> Circ:
	var o := Circ.new()
	o.c = c
	o.r = r
	o.kind = kind
	o.id = id
	if kind == Kind.BUMPER:
		o.e = 0.6
		o.kick = 1.3
	else:
		o.e = 0.8
		o.mu = 0.12
	circs.append(o)
	var ext := Vector2.ONE * (r + BALL_R + 0.004)
	_grid_insert(c - ext, c + ext, o)
	return o


func add_flipper(pivot: Vector2, rest_deg: float, up_deg: float, id: int) -> Flipper:
	var f := Flipper.new()
	f.pivot = pivot
	f.rest = deg_to_rad(rest_deg)
	f.up = deg_to_rad(up_deg)
	f.angle = f.rest
	f.prev_angle = f.rest
	f.id = id
	flippers.append(f)
	return f


func add_sensor(rect: Rect2, id: int) -> void:
	var s := Sensor.new()
	s.rect = rect
	s.id = id
	sensors.append(s)


func set_arc(c: Vector2, r: float) -> void:
	has_arc = true
	arc_c = c
	arc_r = r


func add_ball(pos: Vector2, vel: Vector2 = Vector2.ZERO) -> Ball:
	var b := Ball.new()
	b.pos = pos
	b.prev = pos
	b.vel = vel
	b.id = _next_ball_id
	_next_ball_id += 1
	balls.append(b)
	return b


func clear_balls() -> void:
	balls.clear()


func active_balls() -> Array[Ball]:
	var out: Array[Ball] = []
	for b in balls:
		if b.active:
			out.append(b)
	return out


func set_flipper(id: int, pressed: bool) -> void:
	for f in flippers:
		if f.id == id and f.pressed != pressed:
			f.pressed = pressed
			events.append([Ev.FLIP_UP if pressed else Ev.FLIP_DOWN, f.pivot, 1.0, id])


func nudge(impulse: Vector2) -> void:
	for b in balls:
		if b.active:
			b.vel += impulse


# ---------------------------------------------------------------- stepping

func step(dt: float) -> void:
	for f in flippers:
		f.prev_angle = f.angle
	for b in balls:
		b.prev = b.pos
	var h := dt / SUBSTEPS
	for _i in SUBSTEPS:
		_substep(h)
	_post_step(dt)


func _substep(h: float) -> void:
	for f in flippers:
		var target := f.up if f.pressed else f.rest
		var spd := FLIP_UP_SPEED if f.pressed else FLIP_DOWN_SPEED
		var na := move_toward(f.angle, target, spd * h)
		f.omega = (na - f.angle) / h
		f.angle = na

	for b in balls:
		if not b.active or b.held:
			continue
		b.vel.y -= GRAVITY * h
		b.vel *= 1.0 - 0.04 * h
		var sp2 := b.vel.length_squared()
		if sp2 > MAX_SPEED * MAX_SPEED:
			b.vel *= MAX_SPEED / sqrt(sp2)
		b.pos += b.vel * h

		var key := _key(b.pos)
		if _grid.has(key):
			for o in _grid[key]:
				if o is Seg:
					_hit_seg(b, o)
				else:
					_hit_circ(b, o)
		if has_arc and b.pos.y > arc_c.y:
			_hit_arc(b)
		for f in flippers:
			_hit_flipper(b, f)

	var n := balls.size()
	for i in n:
		var a := balls[i]
		if not a.active or a.held:
			continue
		for j in range(i + 1, n):
			var c := balls[j]
			if c.active and not c.held:
				_hit_balls(a, c)


func _post_step(dt: float) -> void:
	for b in balls:
		if not b.active:
			continue
		if b.pos.y < drain_y:
			b.active = false
			events.append([Ev.DRAIN, b.pos, 1.0, b.id])
			continue
		if b.held:
			b.still_time = 0.0
			continue
		if b.vel.length_squared() < 0.0004:
			b.still_time += dt
		else:
			b.still_time = 0.0
		for s in sensors:
			var inside := s.rect.has_point(b.pos)
			var was: bool = b.sensors.get(s.id, false)
			if inside and not was:
				events.append([Ev.SENSOR, b.pos, 1.0, s.id])
			b.sensors[s.id] = inside


# ---------------------------------------------------------------- contacts

## Resolves a contact against surface point q moving at velocity u.
## Returns the impact speed along the normal (0 if separating, -1 if no contact).
func _resolve(b: Ball, q: Vector2, reach: float, u: Vector2, e: float, mu: float) -> float:
	var d := b.pos - q
	var dist2 := d.length_squared()
	if dist2 >= reach * reach or dist2 < 1e-12:
		return -1.0
	var dist := sqrt(dist2)
	var nrm := d / dist
	b.pos = q + nrm * reach
	var rel := b.vel - u
	var vn := rel.dot(nrm)
	if vn >= 0.0:
		return 0.0
	var ee := e if -vn > REST_THRESH else 0.0
	var jn := -(1.0 + ee) * vn
	rel += nrm * jn
	var t := Vector2(-nrm.y, nrm.x)
	var vt := rel.dot(t)
	var jt := minf(absf(vt), mu * jn)
	rel -= t * signf(vt) * jt
	b.vel = rel + u
	return -vn


func _hit_seg(b: Ball, s: Seg) -> void:
	if s.one_way:
		if (b.pos - s.a).dot(s.n) < 0.0 or b.vel.dot(s.n) >= 0.0:
			return
	var q := Geometry2D.get_closest_point_to_segment(b.pos, s.a, s.b)
	var imp := _resolve(b, q, BALL_R, Vector2.ZERO, s.e, s.mu)
	if imp <= REST_THRESH:
		return
	if s.kind == Kind.SLING:
		if imp > 0.3:
			b.vel += (b.pos - q).normalized() * s.kick
			events.append([Ev.SLING, q, imp, s.id])
	elif s.kind == Kind.TARGET:
		events.append([Ev.TARGET, q, imp, s.id])
	elif s.kind == Kind.RUBBER:
		events.append([Ev.RUBBER, q, imp, s.id])
	else:
		events.append([Ev.WALL, q, imp, s.id])


func _hit_circ(b: Ball, o: Circ) -> void:
	var imp := _resolve(b, o.c, o.r + BALL_R, Vector2.ZERO, o.e, o.mu)
	if imp <= REST_THRESH:
		return
	var nrm := (b.pos - o.c).normalized()
	if o.kind == Kind.BUMPER:
		b.vel += nrm * o.kick
		events.append([Ev.BUMPER, o.c + nrm * o.r, imp, o.id])
	else:
		events.append([Ev.RUBBER, o.c + nrm * o.r, imp, o.id])


func _hit_arc(b: Ball) -> void:
	var d := b.pos - arc_c
	var dist := d.length()
	var limit := arc_r - BALL_R
	if dist <= limit or dist < 1e-6:
		return
	var nrm := -d / dist          # points back towards the arc centre
	b.pos = arc_c - nrm * limit
	var vn := b.vel.dot(nrm)
	if vn >= 0.0:
		return
	var ee := 0.35 if -vn > REST_THRESH else 0.0
	var jn := -(1.0 + ee) * vn
	b.vel += nrm * jn
	var t := Vector2(-nrm.y, nrm.x)
	var vt := b.vel.dot(t)
	b.vel -= t * signf(vt) * minf(absf(vt), 0.05 * jn)
	if -vn > 0.6:
		events.append([Ev.WALL, b.pos - nrm * BALL_R, -vn, -1])


func _hit_flipper(b: Ball, f: Flipper) -> void:
	var tip := f.tip()
	var c := Geometry2D.get_closest_point_to_segment(b.pos, f.pivot, tip)
	var d := b.pos - c
	var reach := BALL_R + f.radius
	if d.length_squared() >= reach * reach:
		return
	var arm := c - f.pivot
	var u := Vector2(-arm.y, arm.x) * f.omega
	var imp := _resolve(b, c, reach, u, 0.4, 0.12)
	if imp > 0.5:
		events.append([Ev.FLIPPER, c, imp, f.id])


func _hit_balls(a: Ball, c: Ball) -> void:
	var d := c.pos - a.pos
	var dist2 := d.length_squared()
	var reach := BALL_R * 2.0
	if dist2 >= reach * reach or dist2 < 1e-12:
		return
	var dist := sqrt(dist2)
	var nrm := d / dist
	var push := (reach - dist) * 0.5
	a.pos -= nrm * push
	c.pos += nrm * push
	var vn := (c.vel - a.vel).dot(nrm)
	if vn < 0.0:
		var j := -(1.0 + 0.9) * vn * 0.5
		a.vel -= nrm * j
		c.vel += nrm * j
		if -vn > 0.4:
			events.append([Ev.BALL, a.pos + nrm * BALL_R, -vn, -1])


# ---------------------------------------------------------------- grid

func _key(p: Vector2) -> int:
	return int(floor((p.x + 0.5) / CELL)) + int(floor((p.y + 0.3) / CELL)) * GRID_W


func _grid_insert(lo: Vector2, hi: Vector2, o: Variant) -> void:
	var x0 := int(floor((lo.x + 0.5) / CELL))
	var x1 := int(floor((hi.x + 0.5) / CELL))
	var y0 := int(floor((lo.y + 0.3) / CELL))
	var y1 := int(floor((hi.y + 0.3) / CELL))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var k := x + y * GRID_W
			if not _grid.has(k):
				_grid[k] = []
			_grid[k].append(o)
