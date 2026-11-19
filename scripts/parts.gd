class_name Parts
extends RefCounted
## Procedural mesh builders for machine parts: turned parts (lathe), plates
## with bevelled edges (extrude) and bent wire or rubber (tube).
## Heights are metres above the playfield; 2D points are playfield (x, y).


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3,
		ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO) -> void:
	# Godot front faces wind clockwise; fix the order from the wanted normal.
	if (c - a).cross(b - a).dot(na + nb + nc) < 0.0:
		var t := b
		b = c
		c = t
		var tn := nb
		nb = nc
		nc = tn
		var tu := ub
		ub = uc
		uc = tu
	st.set_normal(na)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_normal(nb)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_normal(nc)
	st.set_uv(uc)
	st.add_vertex(c)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3) -> void:
	_tri(st, a, b, d, na, nb, nd)
	_tri(st, a, d, c, na, nd, nc)


## Revolves a (radius, height) profile, listed bottom to top, around the Y axis.
static func lathe(profile: PackedVector2Array, seg: int = 32) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profile.size() - 1:
		var a := profile[i]
		var b := profile[i + 1]
		var n2 := Vector2(b.y - a.y, a.x - b.x)
		if n2.length_squared() < 1e-14:
			continue
		n2 = n2.normalized()
		for j in seg:
			var t0 := TAU * j / seg
			var t1 := TAU * (j + 1) / seg
			var c0 := Vector3(cos(t0), 0, sin(t0))
			var c1 := Vector3(cos(t1), 0, sin(t1))
			var n0 := c0 * n2.x + Vector3.UP * n2.y
			var n1 := c1 * n2.x + Vector3.UP * n2.y
			_quad(st, c0 * a.x + Vector3.UP * a.y, c1 * a.x + Vector3.UP * a.y,
				c0 * b.x + Vector3.UP * b.y, c1 * b.x + Vector3.UP * b.y, n0, n1, n0, n1)
	return st.commit()


## A plate with the given outline between heights h0 and h1, with a bevelled
## top edge. The top face is UV-mapped across the outline's bounding box.
static func extrude(poly_in: PackedVector2Array, h0: float, h1: float, bevel: float = 0.0,
		uv_rect := Rect2(0, 0, 1, 1)) -> ArrayMesh:
	var poly := poly_in.duplicate()
	var n := poly.size()
	var area := 0.0
	var cen := Vector2.ZERO
	var lo := poly[0]
	var hi := poly[0]
	for i in n:
		var p := poly[i]
		var q := poly[(i + 1) % n]
		area += p.x * q.y - q.x * p.y
		cen += p
		lo = lo.min(p)
		hi = hi.max(p)
	cen /= n
	if area < 0.0:
		poly.reverse()
	var top := PackedVector2Array()
	for p in poly:
		var d := cen - p
		top.append(p + d.normalized() * minf(bevel, d.length() * 0.4) if bevel > 0.0 else p)
	var hb := h1 - bevel
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var e := b - a
		if e.length_squared() < 1e-12:
			continue
		var n2 := Vector2(e.y, -e.x).normalized()
		var n3 := Vector3(n2.x, 0, -n2.y)
		_quad(st, _v(a, h0), _v(b, h0), _v(a, hb), _v(b, hb), n3, n3, n3, n3)
		if bevel > 0.0:
			var nb := (n3 + Vector3.UP).normalized()
			_quad(st, _v(a, hb), _v(b, hb), _v(top[i], h1), _v(top[(i + 1) % n], h1), nb, nb, nb, nb)
	var size := (hi - lo).max(Vector2(1e-6, 1e-6))
	var idx := Geometry2D.triangulate_polygon(top)
	for k in range(0, idx.size(), 3):
		var uv: Array[Vector2] = []
		var vs: Array[Vector3] = []
		for m in 3:
			var p: Vector2 = top[idx[k + m]]
			var u := (p - lo) / size
			uv.append(uv_rect.position + Vector2(u.x, 1.0 - u.y) * uv_rect.size)
			vs.append(_v(p, h1))
		_tri(st, vs[0], vs[1], vs[2], Vector3.UP, Vector3.UP, Vector3.UP, uv[0], uv[1], uv[2])
	return st.commit()


static func _v(p: Vector2, h: float) -> Vector3:
	return Vector3(p.x, h, -p.y)


## A round tube following a 3D polyline (wire guides, rubber rings).
static func tube(path: PackedVector3Array, r: float, sides: int = 8, closed: bool = false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := path.size()
	var rings: Array = []
	for i in n:
		var prev := path[(i - 1 + n) % n] if (closed or i > 0) else path[i]
		var next := path[(i + 1) % n] if (closed or i < n - 1) else path[i]
		var tan := (next - prev).normalized()
		var ref := Vector3.UP if absf(tan.y) < 0.95 else Vector3.RIGHT
		var u := tan.cross(ref).normalized()
		var v := u.cross(tan).normalized()
		var ring: Array[Vector3] = []
		for j in sides:
			var a := TAU * j / sides
			ring.append(u * cos(a) + v * sin(a))
		rings.append(ring)
	var count := n if closed else n - 1
	for i in count:
		var i2 := (i + 1) % n
		for j in sides:
			var j2 := (j + 1) % sides
			var d0: Vector3 = rings[i][j]
			var d1: Vector3 = rings[i][j2]
			var e0: Vector3 = rings[i2][j]
			var e1: Vector3 = rings[i2][j2]
			_quad(st, path[i] + d0 * r, path[i] + d1 * r, path[i2] + e0 * r, path[i2] + e1 * r, d0, d1, e0, e1)
	return st.commit()


## Outline of a tapered flipper lying along +x from the origin.
static func flipper_outline(length: float, r_base: float, r_tip: float, steps: int = 10) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var a := PI * 0.5 + PI * i / steps
		pts.append(Vector2(cos(a), sin(a)) * r_base)
	for i in steps + 1:
		var a := -PI * 0.5 + PI * i / steps
		pts.append(Vector2(length, 0) + Vector2(cos(a), sin(a)) * r_tip)
	return pts
