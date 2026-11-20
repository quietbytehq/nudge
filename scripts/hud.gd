class_name Hud
extends CanvasLayer
## In-game display: an arcade-style score plate with rolling digits, steel-ball
## icons for balls left, a star burst for the bonus multiplier, pop-up points
## where things are hit, and big animated announcements.

const POP_COLS := {"gold": Color(1.0, 0.85, 0.15), "cyan": Color(0.2, 0.9, 1.0),
	"pink": Color(1.0, 0.3, 0.7), "green": Color(0.45, 1.0, 0.35), "orange": Color(1.0, 0.5, 0.1)}

var effects_enabled := true

var _display: Font
var _body: Font
var _canvas: Control
var _score: Label
var _mult: Label
var _best: Label
var _toast: Label
var _help: Label
var _pause: Label
var _flash: ColorRect
var _ball_tex: Texture2D
var _pops: Array[Label] = []
var _bangs: Array[Node2D] = []       # comic hit words: star burst + word
var _bang_life: Array[float] = []
var _bang_i := 0
var _letters: Array[Label] = []      # big event banner, one label per character
var _banner_t := -1.0
var _banner_n := 0
var _banner_hue := 0.0
var _pop_life: Array[float] = []
var _pop_i := 0

var _balls_total := 3
var _balls_left := 3
var _multiplier := 1
var _shown := 0.0
var _target := 0
var _pulse := 0.0
var _mult_pulse := 0.0
var _toast_time := 0.0
var _toast_total := 1.0
var _clock := 0.0
var _charge := -1.0
var _size := Vector2(1600, 900)


func setup(balls_total: int, table: Dictionary = {}) -> void:
	layer = 5
	_balls_total = balls_total
	_display = Tables.font("Bungee-Regular")
	_body = Tables.font("Audiowide-Regular")
	_ball_tex = Tables.texture("res://assets/ui/ball.png")

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_canvas)

	# the table's name logo, top left under the score
	if table.has("id"):
		var logo := Tables.texture(Tables.dir(table["id"]) + "logo.png")
		if logo != null:
			var tr := TextureRect.new()
			tr.texture = logo
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(tr)
			# tucked under the score plate, clear of the table
			tr.offset_left = 30
			tr.offset_right = 300
			tr.offset_top = 142
			tr.offset_bottom = 232

	_score = _label("0", 66, Color(1.0, 0.86, 0.15), Color(0.85, 0.1, 0.45), 12, true)
	_score.position = Vector2(112, 34)
	_mult = _label("x1", 34, Color(1, 1, 1), Color(0.3, 0.05, 0.3), 9, true)
	_mult.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mult.size = Vector2(90, 44)
	_best = _label("0", 26, Color(0.75, 0.95, 1.0), Color(0.05, 0.1, 0.35), 7, true)

	_toast = _label("", 50, Color(1, 1, 1), Color(0.1, 0.05, 0.3), 14, true)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.anchor_left = 0.0
	_toast.anchor_right = 1.0
	_toast.anchor_top = 0.2
	_toast.anchor_bottom = 0.2
	_toast.offset_left = 0
	_toast.offset_right = 0
	_toast.modulate.a = 0.0

	_help = _label("FLIPPERS  Left / Right Shift        LAUNCH  hold Space        NUDGE  A  D  W\nCAMERA  C        EFFECTS  E        PAUSE  Esc        HIDE THIS  H",
		15, Color(0.85, 0.92, 1.0, 0.8), Color(0, 0, 0, 0.9), 5, false)
	_help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 20)
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_help.visible = false       # the controls are shown before the game; H brings them up

	for i in 8:
		var b := Node2D.new()
		var star := Polygon2D.new()
		var pts := PackedVector2Array()
		for k in 24:
			var rr := 78.0 if k % 2 == 0 else 46.0
			pts.append(Vector2(cos(TAU * k / 24.0), sin(TAU * k / 24.0) * 0.72) * rr)
		star.polygon = pts
		b.add_child(star)
		var edge := Line2D.new()
		edge.points = pts
		edge.closed = true
		edge.width = 5.0
		edge.default_color = Color(0.08, 0.02, 0.15)
		b.add_child(edge)
		var word := _label("", 40, Color(1, 1, 1), Color(0.08, 0.02, 0.15), 12, true)
		remove_child(word)
		b.add_child(word)
		b.visible = false
		add_child(b)
		_bangs.append(b)
		_bang_life.append(0.0)
	for i in 44:
		var ch := _label("", 62, Color(1, 1, 1), Color(0.07, 0.02, 0.14), 14, true)
		ch.visible = false
		_letters.append(ch)

	for i in 14:
		var p := _label("", 34, Color(1, 1, 1), Color(0, 0, 0, 0.95), 9, true)
		p.visible = false
		_pops.append(p)
		_pop_life.append(0.0)

	_pause = _label("", 60, Color(1.0, 0.86, 0.15), Color(0.85, 0.1, 0.45), 14, true)
	_pause.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_pause.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pause.grow_vertical = Control.GROW_DIRECTION_BOTH
	_pause.visible = false


func _label(text: String, size: int, col: Color, outline: Color, outline_px: int, display: bool) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	var f := _display if display else _body
	if f != null:
		ls.font = f
	ls.font_size = size
	ls.font_color = col
	ls.outline_size = outline_px
	ls.outline_color = outline
	ls.shadow_size = 6
	ls.shadow_color = Color(0, 0, 0, 0.7)
	ls.shadow_offset = Vector2(3, 4)
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


# ---------------------------------------------------------------- API

func refresh(delta: float, score: int, best: int, balls_left: int, multiplier: int, charge: float) -> void:
	_clock += delta
	_size = _canvas.size
	if score > _target:
		_pulse = 1.0
	_target = score
	if multiplier != _multiplier:
		_mult_pulse = 1.0
	_multiplier = multiplier
	_balls_left = balls_left
	_charge = charge
	# digits roll up to the real score
	if _shown < _target:
		_shown = minf(float(_target), _shown + maxf(40.0, (_target - _shown) * 9.0) * delta)
	elif _shown > _target:
		_shown = float(_target)
	_pulse = maxf(0.0, _pulse - delta * 3.5)
	_mult_pulse = maxf(0.0, _mult_pulse - delta * 2.0)
	_score.text = commas(int(_shown))
	_score.pivot_offset = Vector2(0, _score.size.y * 0.5)
	_score.scale = Vector2.ONE * (1.0 + 0.14 * _pulse)
	_score.label_settings.font_color = Color(1.0, 0.86, 0.15).lerp(Color(1, 1, 1), _pulse * 0.8)

	_mult.text = "x%d" % multiplier
	_mult.position = Vector2(_size.x - 128, 86)
	_mult.pivot_offset = _mult.size * 0.5
	_mult.scale = Vector2.ONE * (1.0 + 0.5 * _mult_pulse)
	_best.text = commas(best)
	_best.position = Vector2(_size.x - 172, 154)

	_flash.color.a = maxf(0.0, _flash.color.a - delta * 1.8)
	if _toast_time > 0.0:
		_toast_time -= delta
		var age := _toast_total - _toast_time
		_toast.modulate.a = clampf(_toast_time * 2.5, 0.0, 1.0)
		_toast.pivot_offset = _toast.size * 0.5
		_toast.scale = Vector2.ONE * (1.0 + 0.7 * maxf(0.0, 1.0 - age * 5.0))
		_toast.label_settings.font_color = Color.from_hsv(fmod(_clock * 0.6, 1.0), 0.45, 1.0)
	else:
		_toast.modulate.a = 0.0
	for i in _pops.size():
		if _pop_life[i] > 0.0:
			_pop_life[i] -= delta
			var p := _pops[i]
			var t := _pop_life[i] / 0.9
			p.position.y -= 70.0 * delta
			p.modulate.a = clampf(t * 2.0, 0.0, 1.0)
			p.scale = Vector2.ONE * (1.0 + 0.6 * maxf(0.0, t - 0.75) * 4.0)
			if _pop_life[i] <= 0.0:
				p.visible = false
	_fx(delta)
	_canvas.queue_redraw()


## Animates the comic hit words and the big banner letters.
func _fx(delta: float) -> void:
	for i in _bangs.size():
		if _bang_life[i] <= 0.0:
			continue
		_bang_life[i] -= delta
		var b := _bangs[i]
		var t := 1.0 - _bang_life[i] / 0.75           # 0 -> 1 over its life
		var s := 1.0
		if t < 0.18:
			s = lerpf(0.15, 1.35, t / 0.18)            # punch in
		elif t < 0.32:
			s = lerpf(1.35, 1.0, (t - 0.18) / 0.14)    # settle
		b.scale = Vector2.ONE * s
		b.position.y -= 26.0 * delta
		b.modulate.a = clampf((1.0 - t) * 4.0, 0.0, 1.0)
		if _bang_life[i] <= 0.0:
			b.visible = false
	if _banner_t >= 0.0:
		_banner_t += delta
		var total := 2.3
		for i in _banner_n:
			var l := _letters[i]
			var lt := _banner_t - i * 0.028
			if lt < 0.0:
				l.modulate.a = 0.0
				continue
			var pop := 1.0 + 0.9 * maxf(0.0, 1.0 - lt / 0.22)
			l.scale = Vector2.ONE * pop
			l.position.y = l.get_meta("y0") + sin(_banner_t * 7.0 + i * 0.55) * 7.0
			l.rotation = sin(_banner_t * 5.0 + i * 0.9) * 0.06
			l.label_settings.font_color = Color.from_hsv(fmod(_banner_hue + i * 0.035 + _banner_t * 0.25, 1.0), 0.55, 1.0)
			l.modulate.a = clampf((total - _banner_t) * 3.0, 0.0, 1.0)
		if _banner_t > total:
			_banner_t = -1.0
			for i in _banner_n:
				_letters[i].visible = false


## A comic-book word bursting out where something was hit.
func bang(at: Vector2, word: String, colour: String = "gold") -> void:
	if not effects_enabled:
		return
	var b := _bangs[_bang_i]
	_bang_life[_bang_i] = 0.75
	_bang_i = (_bang_i + 1) % _bangs.size()
	var col: Color = POP_COLS.get(colour, POP_COLS["gold"])
	(b.get_child(0) as Polygon2D).color = col
	var lab := b.get_child(2) as Label
	lab.text = word
	lab.label_settings.font_color = Color(1, 1, 1)
	lab.reset_size()
	lab.position = -lab.size * 0.5
	b.position = Vector2(clampf(at.x, 110.0, _size.x - 110.0), clampf(at.y - 70.0, 150.0, _size.y - 80.0))
	b.rotation = randf_range(-0.28, 0.28)
	b.scale = Vector2.ONE * 0.15
	b.modulate.a = 1.0
	b.visible = true


## A big announcement whose letters drop in one by one, wave and change colour.
func banner(text: String) -> void:
	if not effects_enabled:
		toast(text, 2.0)
		return
	text = text.to_upper().substr(0, _letters.size())
	for l in _letters:
		l.visible = false
	var font: Font = _display if _display != null else ThemeDB.fallback_font
	var widths: Array[float] = []
	var total_w := 0.0
	for i in text.length():
		var w := font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 62).x
		widths.append(w)
		total_w += w
	var scale_fit := minf(1.0, (_size.x - 80.0) / maxf(total_w, 1.0))
	var x := (_size.x - total_w * scale_fit) * 0.5
	for i in text.length():
		var l := _letters[i]
		l.text = text[i]
		l.label_settings.font_size = int(62 * scale_fit)
		l.reset_size()
		l.pivot_offset = l.size * 0.5
		l.position = Vector2(x, 250.0)
		l.set_meta("y0", 250.0)
		l.modulate.a = 0.0
		l.visible = true
		x += widths[i] * scale_fit
	_banner_n = text.length()
	_banner_t = 0.0
	_banner_hue = randf()


func toast(text: String, seconds: float = 2.5) -> void:
	_toast.text = text.to_upper()
	_toast_time = seconds
	_toast_total = seconds


## Points popping up at a screen position, e.g. where a bumper was hit.
func popup(at: Vector2, text: String, colour: String = "gold") -> void:
	if not effects_enabled:
		return
	var p := _pops[_pop_i]
	_pop_life[_pop_i] = 0.9
	_pop_i = (_pop_i + 1) % _pops.size()
	p.text = text
	p.label_settings.font_color = POP_COLS.get(colour, POP_COLS["gold"])
	p.reset_size()
	p.position = at - p.size * 0.5 - Vector2(0, 26)
	p.pivot_offset = p.size * 0.5
	p.modulate.a = 1.0
	p.visible = true


func flash(col: Color, alpha: float) -> void:
	if effects_enabled:
		_flash.color = Color(col.r, col.g, col.b, alpha)


func set_pause(on: bool, text: String = "") -> void:
	_pause.text = text
	_pause.visible = on


func toggle_help() -> void:
	_help.visible = not _help.visible


static func commas(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


# ---------------------------------------------------------------- drawing

func _plate(rect: Rect2, hue: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.02, 0.1, 0.82)
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(4)
	sb.border_color = Color.from_hsv(hue, 0.85, 1.0)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 10
	_canvas.draw_style_box(sb, rect)
	var inner := StyleBoxFlat.new()
	inner.bg_color = Color(0, 0, 0, 0)
	inner.set_corner_radius_all(16)
	inner.set_border_width_all(2)
	inner.border_color = Color.from_hsv(fmod(hue + 0.45, 1.0), 0.7, 1.0, 0.7)
	_canvas.draw_style_box(inner, rect.grow(-8))


func _ball(c: Vector2, r: float, lit: bool) -> void:
	if _ball_tex != null:
		# a real photographed-style steel ball
		if lit:
			_canvas.draw_circle(c + Vector2(2, 4), r * 0.96, Color(0, 0, 0, 0.55))
		var tint := Color(1, 1, 1) if lit else Color(0.22, 0.24, 0.32, 0.85)
		_canvas.draw_texture_rect(_ball_tex, Rect2(c - Vector2(r, r) * 1.04, Vector2(r, r) * 2.08), false, tint)
		return
	if not lit:
		_canvas.draw_circle(c, r, Color(0.12, 0.13, 0.2, 0.9))
		_canvas.draw_arc(c, r, 0, TAU, 32, Color(0.4, 0.45, 0.6, 0.8), 2.0, true)
		return
	_canvas.draw_circle(c + Vector2(2, 3), r, Color(0, 0, 0, 0.5))
	_canvas.draw_circle(c, r, Color(0.36, 0.39, 0.47))
	_canvas.draw_circle(c - Vector2(0.12, 0.14) * r, r * 0.8, Color(0.66, 0.69, 0.76))
	_canvas.draw_circle(c - Vector2(0.24, 0.28) * r, r * 0.52, Color(0.86, 0.88, 0.93))
	_canvas.draw_circle(c - Vector2(0.36, 0.4) * r, r * 0.2, Color(1, 1, 1))
	_canvas.draw_arc(c, r * 0.78, 0.5, 2.3, 16, Color(0.2, 0.3, 0.6, 0.8), r * 0.14, true)
	_canvas.draw_arc(c, r, 0, TAU, 40, Color(0.08, 0.08, 0.14), 2.0, true)


func _star(c: Vector2, r_out: float, r_in: float, points: int, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in points * 2:
		var a := rot + PI * i / points
		pts.append(c + Vector2(cos(a), sin(a)) * (r_out if i % 2 == 0 else r_in))
	_canvas.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	_canvas.draw_polyline(pts, Color(0.1, 0.02, 0.15), 2.5, true)


func _caption(text: String, at: Vector2, col: Color) -> void:
	var f := _body if _body != null else ThemeDB.fallback_font
	_canvas.draw_string_outline(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color(0, 0, 0, 0.9))
	_canvas.draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)


func _draw_canvas() -> void:
	var hue := fmod(_clock * 0.08, 1.0)
	# score plate with a big steel ball
	var w := maxf(380.0, 150.0 + _score.size.x * _score.scale.x)
	_plate(Rect2(18, 16, w, 122), hue)
	_caption("SCORE", Vector2(116, 44), Color(0.3, 0.95, 1.0))
	_ball(Vector2(66, 78), 34.0 + 4.0 * _pulse, true)
	_star(Vector2(44, 52), 9.0 + 5.0 * _pulse, 3.5, 4, _clock * 2.0, Color(1, 1, 1, 0.95))

	# balls, bonus and best plate
	var x0 := _size.x - 290.0
	_plate(Rect2(x0, 16, 272, 182), fmod(hue + 0.5, 1.0))
	_caption("BALLS", Vector2(x0 + 22, 50), Color(0.3, 0.95, 1.0))
	for i in _balls_total:
		var lit := i < _balls_left
		var bob := sin(_clock * 3.0 + i) * 2.0 if lit else 0.0
		_ball(Vector2(x0 + 122 + i * 46, 44 + bob), 17.0, lit)
	_caption("BONUS", Vector2(x0 + 22, 114), Color(1.0, 0.5, 0.8))
	var mc := Vector2(_size.x - 83, 108)
	var mcol := Color.from_hsv(fmod(0.08 + 0.13 * (_multiplier - 1), 1.0), 0.9, 1.0)
	_star(mc, 40.0 + 14.0 * _mult_pulse, 27.0 + 8.0 * _mult_pulse, 10, _clock * 0.8, mcol)
	_caption("BEST", Vector2(x0 + 22, 178), Color(1.0, 0.85, 0.2))
	_star(Vector2(x0 + 92, 172), 12.0, 5.0, 5, -PI * 0.5, Color(1.0, 0.85, 0.2))

	# launch power meter: a row of balls that fills up
	if _charge >= 0.0:
		var bx := _size.x * 0.5 - 150.0
		var by := _size.y - 80.0
		_plate(Rect2(bx - 26, by - 44, 352, 78), fmod(hue + 0.25, 1.0))
		_caption("LAUNCH POWER", Vector2(bx - 6, by - 20), Color(1.0, 0.85, 0.2))
		for i in 10:
			_ball(Vector2(bx + 6 + i * 32, by + 8), 11.0, _charge * 10.0 > i + 0.2)
