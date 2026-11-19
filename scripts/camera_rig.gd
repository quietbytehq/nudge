class_name CameraRig
extends Camera3D
## Gameplay camera. In Dynamic Follow it sits low and close behind the
## flippers, like a player leaning over the glass, and travels with the ball.
## While the ball is in the lower playfield or coming down, the framing always
## includes both flippers; when the ball is climbing through the upper
## playfield the camera rides up with it. It never rotates the table.

enum Mode { DYNAMIC, FULL_TABLE, REDUCED_MOTION }
const MODE_NAMES := ["Dynamic Follow", "Full Table", "Reduced Motion"]

## Direction from the focus point to the camera, in table space.
const VIEW_DIR := Vector3(0.0, 0.62, 0.78)
const FULL_DIR := Vector3(0.0, 0.83, 0.56)
const BASE_DIST := 0.46
const FULL_DIST := 1.52
const FULL_FOCUS := Vector2(TableLayout.XC + 0.02, 0.50)
const FLIPPER_Y := 0.06          # lowest point that must stay on screen
const NEAR_K := 0.5             # ground distance seen below the focus, per metre of camera distance

var mode: int = Mode.DYNAMIC
var follow_strength := 0.8       # 0..1, exposed in settings later
var shake_enabled := true
var table: TableView
var flippers_needed := true

var _focus := Vector2(TableLayout.XC, 0.25)
var _dist := BASE_DIST
var _goal := Vector2(TableLayout.XC, 0.25)
var _goal_dist := BASE_DIST
var _dir := VIEW_DIR
var _shake := 0.0


func _ready() -> void:
	fov = 56.0
	near = 0.02
	far = 20.0


func snap() -> void:
	_focus = _goal
	_dist = _goal_dist
	_apply(0.0)


func add_shake(amount: float) -> void:
	if shake_enabled and mode == Mode.DYNAMIC:
		_shake = minf(_shake + amount, 1.0)


func update_rig(delta: float, balls: Array) -> void:
	var goal := FULL_FOCUS
	var gdist := FULL_DIST
	var gdir := FULL_DIR
	if mode == Mode.DYNAMIC:
		gdir = VIEW_DIR
		goal = Vector2(TableLayout.XC, 0.29)
		gdist = BASE_DIST
	if mode == Mode.DYNAMIC and balls.size() > 0:
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		var mean := Vector2.ZERO
		var fastest := 0.0
		flippers_needed = false
		for b in balls:
			var look: Vector2 = b.vel * 0.16
			if look.length() > 0.18:
				look = look.normalized() * 0.18
			mean += b.pos + look
			lo = lo.min(b.pos)
			hi = hi.max(b.pos)
			fastest = maxf(fastest, b.vel.length())
			if b.pos.y < 0.66 or b.vel.y < 0.1:
				flippers_needed = true
		mean /= balls.size()
		goal.x = clampf(lerpf(TableLayout.XC, mean.x, 0.45 * follow_strength), -0.07, 0.03)
		goal.y = lerpf(0.27, mean.y - 0.10, follow_strength)
		gdist = BASE_DIST + 0.05 * clampf(fastest / 4.0, 0.0, 1.0)
		# multiball: widen to keep every ball in frame
		gdist += (hi.y - lo.y) * 0.18 + (hi.x - lo.x) * 0.25
		if flippers_needed:
			# keep both flippers on screen: cap how far up-table we look,
			# then stand back just enough
			goal.y = clampf(goal.y, 0.27, 0.36)
			gdist = maxf(gdist, (goal.y - FLIPPER_Y) / NEAR_K)
		else:
			goal.y = clampf(goal.y, 0.27, 0.62)
		gdist = minf(gdist, 0.95)
		# dead zone: ignore tiny changes so the view stays calm
		if goal.distance_to(_goal) > 0.012 or absf(gdist - _goal_dist) > 0.02:
			_goal = goal
			_goal_dist = gdist
	else:
		flippers_needed = true
		_goal = goal
		_goal_dist = gdist

	var k := 1.0 - exp(-5.0 * delta)
	var kd := 1.0 - exp(-3.5 * delta)
	_focus = _focus.lerp(_goal, k)
	_dist = lerpf(_dist, _goal_dist, kd)
	_dir = _dir.lerp(gdir, kd)
	_apply(delta)


func _apply(delta: float) -> void:
	if table == null:
		return
	var f3 := TableView.to3(_focus, 0.0)
	var cam_local := f3 + _dir.normalized() * _dist
	var target := table.to_global(f3)
	global_position = table.to_global(cam_local)
	look_at(target, Vector3.UP)
	if _shake > 0.001:
		_shake *= exp(-14.0 * delta)
		h_offset = randf_range(-1.0, 1.0) * _shake * 0.003
		v_offset = randf_range(-1.0, 1.0) * _shake * 0.003
	else:
		h_offset = 0.0
		v_offset = 0.0
