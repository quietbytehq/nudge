extends Node
## Application shell: arcade intro -> table select -> game.
## Owns the music, the audio buses and the input map.

const TITLE := "NUDGE"
const STUDIO := "QUIETBYTE"
const UI_DIR := "res://assets/ui/"
const CARD_COLS := [Color(1.0, 0.55, 0.1), Color(0.1, 0.8, 1.0), Color(1.0, 0.2, 0.6),
	Color(0.5, 1.0, 0.25), Color(1.0, 0.85, 0.1), Color(0.65, 0.4, 1.0)]

enum Screen { INTRO, SELECT, HOWTO, GAME, NAME, TOPTEN }

var screen: int = Screen.INTRO
var game: Game
var selected := 0

var _ui: CanvasLayer
var _intro: Control
var _select: Control
var _bg: TextureRect
var _title: Control
var _press: Label
var _lines: Array[ColorRect] = []
var _display: Font
var _body: Font
var _clock := 0.0
var _howto: Control
var _howto_canvas: Control
var _howto_index := 0
var _howto_press: Label
var _top: Control
var _top_rows: VBoxContainer
var _top_highlight := -1
var _name_panel: Control
var _name_label: Label
var _name_score: Label
var _name_text := ""
var _pending_score := 0
var _pending_table := ""
var _pending_table_id := ""
var _online_hint: Label
var _shot_table := 0
var _flash: ColorRect
var _cards: Array[Panel] = []
var _hint: Label
var _music: AudioStreamPlayer
var _music_path := ""
var _intro_ready := false

var _shot_dir := ""
var _frame := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_setup_input()
	Settings.load_all()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--table="):
			_shot_table = clampi(int(arg.trim_prefix("--table=")), 0, Tables.LIST.size() - 1)
		if arg.begins_with("--quality="):
			Settings.quality = clampi(int(arg.trim_prefix("--quality=")), 0, 2)
			Settings.quality_auto = false
	Settings.apply_viewport(get_viewport())
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_dir = a.trim_prefix("--shot=")

	_display = Tables.font("Bungee-Regular")
	_body = Tables.font("Audiowide-Regular")
	if _body != null:
		var th := Theme.new()
		th.default_font = _body
		get_tree().root.theme = th

	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)

	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	_build_intro()
	_build_select()
	_build_howto()
	_build_top()
	_build_name()
	_show_intro()


# ---------------------------------------------------------------- audio / input

func _setup_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -9.0)


func _play_music(path: String) -> void:
	if path == _music_path and _music.playing:
		return
	_music_path = path
	var stream := Tables.audio(path)
	if stream == null:
		_music.stop()
		return
	if stream is AudioStreamMP3:
		stream.loop = true
	_music.stream = stream
	_music.volume_db = -40.0
	_music.play()
	create_tween().tween_property(_music, "volume_db", 0.0, 0.8)


func _key(action: String, code: Key, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.location = location
	InputMap.action_add_event(action, ev)


func _pad(action: String, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _setup_input() -> void:
	# Defaults are registered in code for now; a remapping screen comes with
	# the settings menu.
	for a in ["flipper_left", "flipper_right", "launch", "nudge_left", "nudge_right",
			"nudge_up", "pause", "camera_mode", "toggle_help", "toggle_effects", "debug_ball", "quality"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
	_key("flipper_left", KEY_SHIFT, KEY_LOCATION_LEFT)
	_key("flipper_left", KEY_CTRL, KEY_LOCATION_LEFT)
	_key("flipper_left", KEY_Z)
	_key("flipper_right", KEY_SHIFT, KEY_LOCATION_RIGHT)
	_key("flipper_right", KEY_CTRL, KEY_LOCATION_RIGHT)
	_key("flipper_right", KEY_SLASH)
	_key("launch", KEY_SPACE)
	_key("nudge_left", KEY_A)
	_key("nudge_right", KEY_D)
	_key("nudge_up", KEY_W)
	_key("pause", KEY_ESCAPE)
	_key("camera_mode", KEY_C)
	_key("toggle_help", KEY_H)
	_key("toggle_effects", KEY_E)
	_key("debug_ball", KEY_M)
	_key("quality", KEY_G)
	_pad("flipper_left", JOY_BUTTON_LEFT_SHOULDER)
	_pad("flipper_right", JOY_BUTTON_RIGHT_SHOULDER)
	_pad("launch", JOY_BUTTON_A)
	_pad("pause", JOY_BUTTON_START)
	_pad("camera_mode", JOY_BUTTON_Y)
	_pad("nudge_left", JOY_BUTTON_DPAD_LEFT)
	_pad("nudge_right", JOY_BUTTON_DPAD_RIGHT)
	_pad("nudge_up", JOY_BUTTON_DPAD_UP)


# ---------------------------------------------------------------- UI helpers

func _full(c: Control, parent: Node) -> Control:
	parent.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _text(text: String, size: int, color: Color, outline: Color, outline_px: int, glow: Color = Color(0, 0, 0, 0), display: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	var fnt := _display if display else _body
	if fnt != null:
		ls.font = fnt
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline_px
	ls.outline_color = outline
	if glow.a > 0.0:
		ls.shadow_size = int(size * 0.35)
		ls.shadow_color = glow
		ls.shadow_offset = Vector2.ZERO
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _place(l: Control, parent: Control, y_anchor: float) -> void:
	parent.add_child(l)
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = y_anchor
	l.anchor_bottom = y_anchor
	l.offset_left = 0
	l.offset_right = 0
	l.grow_vertical = Control.GROW_DIRECTION_BOTH


func _backdrop(parent: Control, dim: float) -> TextureRect:
	var black := ColorRect.new()
	black.color = Color(0.01, 0.01, 0.03)
	_full(black, parent)
	var tr := TextureRect.new()
	tr.texture = Tables.texture(UI_DIR + "intro.jpg")
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.modulate = Color(dim, dim, dim)
	_full(tr, parent)
	return tr


func _shade(parent: Control, top_alpha: float, bottom_alpha: float) -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, top_alpha))
	g.set_color(1, Color(0, 0, 0, bottom_alpha))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	_full(tr, parent)


# ---------------------------------------------------------------- intro

func _build_intro() -> void:
	_intro = _full(Control.new(), _ui)
	_intro.clip_contents = true
	_bg = _backdrop(_intro, 1.0)
	_shade(_intro, 0.35, 0.75)

	var studio := _text(STUDIO + "   PRESENTS", 26, Color(0.75, 0.9, 1.0), Color(0, 0, 0, 0.9), 8)
	_place(studio, _intro, 0.075)
	var logo := Tables.texture(UI_DIR + "logo.png")
	if logo != null:
		var tr := TextureRect.new()
		tr.texture = logo
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_intro.add_child(tr)
		tr.anchor_left = 0.14
		tr.anchor_right = 0.86
		tr.anchor_top = 0.10
		tr.anchor_bottom = 0.56
		tr.offset_left = 0
		tr.offset_right = 0
		tr.offset_top = 0
		tr.offset_bottom = 0
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_title = tr
	else:
		_title = _text(TITLE, 190, Color(1.0, 0.9, 0.3), Color(1.0, 0.25, 0.5), 22, Color(0.2, 0.5, 1.0, 0.75), true)
		_place(_title, _intro, 0.30)
	var sub := _text("COSMIC DRIFT   *   PARADISE BAY", 30, Color(1.0, 0.85, 0.3), Color(0.6, 0.1, 0.5), 10, Color(0, 0, 0, 0), true)
	_place(sub, _intro, 0.60)
	for y in [0.775, 0.905]:
		var line := ColorRect.new()
		_intro.add_child(line)
		line.anchor_left = 0.24
		line.anchor_right = 0.76
		line.anchor_top = y
		line.anchor_bottom = y
		line.offset_top = -3
		line.offset_bottom = 3
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lines.append(line)
	_press = _text("PRESS ANY KEY TO START", 54, Color(1.0, 1.0, 1.0), Color(0.1, 0.2, 0.9), 14, Color(0, 0, 0, 0), true)
	_place(_press, _intro, 0.84)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_full(_flash, _ui)


func _show_intro() -> void:
	screen = Screen.INTRO
	_hide_all()
	_intro.visible = true
	_intro_ready = false
	_play_music(UI_DIR + "intro_music.mp3")

	# arcade-style entrance: white flash, title slams in, then the prompt blinks
	_flash.color.a = 1.0
	create_tween().tween_property(_flash, "color:a", 0.0, 0.7)
	await get_tree().process_frame
	_bg.pivot_offset = _bg.size * 0.5
	_bg.scale = Vector2.ONE
	var zoom := create_tween().set_loops()
	zoom.tween_property(_bg, "scale", Vector2(1.07, 1.07), 9.0).set_trans(Tween.TRANS_SINE)
	zoom.tween_property(_bg, "scale", Vector2.ONE, 9.0).set_trans(Tween.TRANS_SINE)

	_title.pivot_offset = _title.size * 0.5
	_title.scale = Vector2(3.2, 3.2)
	_title.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(_title, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_title, "modulate:a", 1.0, 0.25)
	var pulse := create_tween().set_loops()
	pulse.tween_interval(0.6)
	pulse.tween_property(_title, "scale", Vector2(1.035, 1.035), 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_title, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)

	_press.modulate.a = 0.0
	var blink := create_tween().set_loops()
	blink.tween_interval(0.25)
	blink.tween_property(_press, "modulate:a", 1.0, 0.12)
	blink.tween_interval(0.55)
	blink.tween_property(_press, "modulate:a", 0.15, 0.25)
	await get_tree().create_timer(0.5).timeout
	_intro_ready = true


# ---------------------------------------------------------------- table select

func _build_select() -> void:
	_select = _full(Control.new(), _ui)
	_backdrop(_select, 0.28)
	_shade(_select, 0.5, 0.7)
	var head := _text("SELECT TABLE", 78, Color(1.0, 0.9, 0.3), Color(0.95, 0.15, 0.5), 16, Color(0, 0, 0, 0), true)
	_place(head, _select, 0.10)

	var center := CenterContainer.new()
	_full(center, _select)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 34)
	grid.add_theme_constant_override("v_separation", 34)
	center.add_child(grid)

	for i in Tables.LIST.size():
		var t: Dictionary = Tables.LIST[i]
		var card := Panel.new()
		card.custom_minimum_size = Vector2(400, 250)
		card.clip_contents = true
		grid.add_child(card)
		var thumb := Tables.texture(Tables.dir(t["id"]) + "card.jpg") if t["available"] else null
		if thumb != null:
			var tr := TextureRect.new()
			tr.texture = thumb
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			card.add_child(tr)
			tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 5)
		var num := _text(str(i + 1), 44, CARD_COLS[i % CARD_COLS.size()], Color(0, 0, 0, 0.95), 12, Color(0, 0, 0, 0), true)
		card.add_child(num)
		num.position = Vector2(18, 8)
		var card_logo := Tables.texture(Tables.dir(t["id"]) + "logo.png") if t["available"] else null
		if card_logo != null:
			var lr := TextureRect.new()
			lr.texture = card_logo
			lr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			lr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			card.add_child(lr)
			lr.anchor_left = 0.08
			lr.anchor_right = 0.92
			lr.anchor_top = 0.52
			lr.anchor_bottom = 1.0
			lr.offset_left = 0
			lr.offset_right = 0
			lr.offset_top = 0
			lr.offset_bottom = -6
		var name_l := _text(t["name"].to_upper(), 34, Color(1, 1, 1) if t["available"] else CARD_COLS[i % CARD_COLS.size()].lerp(Color(0.5, 0.5, 0.6), 0.35), Color(0, 0, 0, 0.95), 12, Color(0, 0, 0, 0), true)
		card.add_child(name_l)
		name_l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 12)
		name_l.grow_vertical = Control.GROW_DIRECTION_BEGIN
		name_l.visible = card_logo == null
		if not t["available"]:
			var q := _text("?", 110, CARD_COLS[i % CARD_COLS.size()].darkened(0.25), Color(0, 0, 0, 0.9), 10, Color(0, 0, 0, 0), true)
			card.add_child(q)
			q.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			q.grow_horizontal = Control.GROW_DIRECTION_BOTH
			q.grow_vertical = Control.GROW_DIRECTION_BOTH
			q.position.y -= 22
			var soon := _text("COMING SOON", 20, Color(0.8, 0.85, 0.95), Color(0, 0, 0, 0.9), 6)
			card.add_child(soon)
			soon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 14)
			soon.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_cards.append(card)

	_hint = _text("", 24, Color(0.85, 0.92, 1.0), Color(0, 0, 0, 0.9), 8)
	_place(_hint, _select, 0.92)
	_select.visible = false


func _refresh_cards() -> void:
	for i in _cards.size():
		var t: Dictionary = Tables.LIST[i]
		var sb := StyleBoxFlat.new()
		var accent: Color = CARD_COLS[i % CARD_COLS.size()]
		sb.bg_color = accent.darkened(0.82)
		sb.bg_color.a = 0.94
		sb.set_corner_radius_all(14)
		var on := i == selected
		sb.set_border_width_all(5 if on else 2)
		sb.border_color = accent if on else accent.darkened(0.45)
		if on:
			sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.45)
			sb.shadow_size = 18
		_cards[i].add_theme_stylebox_override("panel", sb)
		_cards[i].modulate = Color(1, 1, 1) if on else Color(0.72, 0.72, 0.72)
	var t: Dictionary = Tables.LIST[selected]
	if t["available"]:
		_hint.text = "%s  -  %s\nArrow keys choose     Enter plays     T top ten     Esc goes back" % [t["name"], t["tagline"]]
	else:
		_hint.text = "%s is not built yet\nArrow keys choose     T top ten     Esc goes back" % t["name"]


func _hide_all() -> void:
	for c in [_intro, _select, _howto, _top, _name_panel]:
		if c != null:
			c.visible = false


func _show_select() -> void:
	screen = Screen.SELECT
	_hide_all()
	_select.visible = true
	_flash.color.a = 0.6
	create_tween().tween_property(_flash, "color:a", 0.0, 0.35)
	_play_music(UI_DIR + "intro_music.mp3")
	_refresh_cards()


# ---------------------------------------------------------------- game

func _start_game(index: int) -> void:
	var t: Dictionary = Tables.LIST[index]
	if not t["available"]:
		return
	screen = Screen.GAME
	_hide_all()
	_flash.color.a = 1.0
	create_tween().tween_property(_flash, "color:a", 0.0, 0.5)
	game = Game.new()
	game.table = t
	game.autoplay_dir = _shot_dir
	game.exit_requested.connect(_leave_game)
	game.game_finished.connect(_on_game_finished)
	add_child(game)
	_play_music(Tables.dir(t["id"]) + "music.mp3")


func _leave_game() -> void:
	if game != null:
		game.queue_free()
		game = null
	_show_select()


func _input(event: InputEvent) -> void:
	if screen == Screen.INTRO:
		if not _intro_ready:
			return
		var go := false
		if event is InputEventKey and event.pressed and not event.echo:
			go = true
		elif event is InputEventJoypadButton and event.pressed:
			go = true
		elif event is InputEventMouseButton and event.pressed:
			go = true
		if go:
			get_viewport().set_input_as_handled()
			_show_select()
	elif screen == Screen.SELECT:
		var n := Tables.LIST.size()
		var moved := true
		if event.is_action_pressed("ui_right"):
			selected = (selected + 1) % n
		elif event.is_action_pressed("ui_left"):
			selected = (selected + n - 1) % n
		elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
			selected = (selected + 3) % n
		else:
			moved = false
		if moved:
			_refresh_cards()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			if Tables.LIST[selected]["available"]:
				_show_howto(selected)
		elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_T:
			get_viewport().set_input_as_handled()
			_show_top(-1)
		elif event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_show_intro()


	elif screen == Screen.HOWTO:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_show_select()
		elif _any_press(event):
			get_viewport().set_input_as_handled()
			_start_game(_howto_index)
	elif screen == Screen.TOPTEN:
		if _any_press(event):
			get_viewport().set_input_as_handled()
			_show_select()
	elif screen == Screen.NAME:
		if event is InputEventKey and event.pressed:
			get_viewport().set_input_as_handled()
			if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				var who := _name_text.strip_edges()
				if who == "":
					who = "PLAYER"
				if Settings.online:
					Online.submit(self, who, _pending_score, _pending_table_id)
				_show_top(Settings.add_top(who, _pending_score, _pending_table))
			elif event.keycode == KEY_TAB:
				Settings.online = not Settings.online
				Settings.save_quality()
				_refresh_online_hint()
			elif event.keycode == KEY_BACKSPACE:
				_name_text = _name_text.substr(0, maxi(0, _name_text.length() - 1))
			elif event.unicode >= 32 and event.unicode < 127 and _name_text.length() < 12:
				_name_text += char(event.unicode).to_upper()


func _any_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventJoypadButton or event is InputEventMouseButton:
		return event.pressed
	return false


# ---------------------------------------------------------------- how to play

const HOWTO_ROWS := [
	[["L SHIFT", "R SHIFT"], "FLIPPERS"],
	[["SPACE"], "HOLD, THEN RELEASE TO LAUNCH"],
	[["A", "D", "W"], "NUDGE THE TABLE"],
	[["C"], "CHANGE CAMERA VIEW"],
	[["G"], "GRAPHICS QUALITY"],
	[["E"], "REDUCE EFFECTS"],
	[["ESC"], "PAUSE   (THEN Q TO LEAVE)"],
]


func _build_howto() -> void:
	_howto = _full(Control.new(), _ui)
	_backdrop(_howto, 0.22)
	_shade(_howto, 0.55, 0.75)
	var head := _text("HOW TO PLAY", 78, Color(1.0, 0.9, 0.3), Color(0.95, 0.15, 0.5), 16, Color(0, 0, 0, 0), true)
	_place(head, _howto, 0.11)
	_howto_canvas = _full(Control.new(), _howto)
	_howto_canvas.draw.connect(_draw_howto)
	var tip := _text("Light all three top lanes to raise the bonus multiplier.   Feed the black hole for 1,000.\nScore 100,000 or more to enter the TOP TEN.",
		22, Color(0.8, 0.92, 1.0), Color(0, 0, 0, 0.9), 7)
	_place(tip, _howto, 0.80)
	_howto_press = _text("PRESS ANY KEY TO PLAY", 44, Color(1, 1, 1), Color(0.1, 0.2, 0.9), 12, Color(0, 0, 0, 0), true)
	_place(_howto_press, _howto, 0.92)
	_howto.visible = false


func _draw_howto() -> void:
	var c := _howto_canvas
	var sz := c.size
	var f: Font = _body if _body != null else ThemeDB.fallback_font
	var fd: Font = _display if _display != null else f
	var y := sz.y * 0.25
	for i in HOWTO_ROWS.size():
		var keys: Array = HOWTO_ROWS[i][0]
		var col: Color = CARD_COLS[i % CARD_COLS.size()]
		var x := sz.x * 0.5 - 30.0
		for k in range(keys.size() - 1, -1, -1):
			var label: String = keys[k]
			var w := maxf(62.0, f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 34.0)
			var cap := StyleBoxFlat.new()
			cap.bg_color = Color(0.1, 0.11, 0.2, 0.95)
			cap.set_corner_radius_all(10)
			cap.set_border_width_all(3)
			cap.border_width_bottom = 8
			cap.border_color = col
			c.draw_style_box(cap, Rect2(x - w, y - 28, w, 54))
			c.draw_string(f, Vector2(x - w, y + 5), label, HORIZONTAL_ALIGNMENT_CENTER, w, 24, Color(1, 1, 1))
			x -= w + 12.0
		var at := Vector2(sz.x * 0.5 + 14.0, y + 9.0)
		c.draw_string_outline(fd, at, HOWTO_ROWS[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 8, Color(0, 0, 0, 0.9))
		c.draw_string(fd, at, HOWTO_ROWS[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, col.lerp(Color(1, 1, 1), 0.35))
		y += sz.y * 0.073


func _show_howto(index: int) -> void:
	screen = Screen.HOWTO
	_howto_index = index
	_hide_all()
	_howto.visible = true
	_howto_canvas.queue_redraw()
	_flash.color.a = 0.5
	create_tween().tween_property(_flash, "color:a", 0.0, 0.35)


# ---------------------------------------------------------------- top ten

func _build_top() -> void:
	_top = _full(Control.new(), _ui)
	_backdrop(_top, 0.22)
	_shade(_top, 0.55, 0.75)
	var head := _text("TOP TEN PLAYERS", 74, Color(1.0, 0.9, 0.3), Color(0.95, 0.15, 0.5), 16, Color(0, 0, 0, 0), true)
	_place(head, _top, 0.10)
	var center := CenterContainer.new()
	_full(center, _top)
	_top_rows = VBoxContainer.new()
	_top_rows.add_theme_constant_override("separation", 6)
	center.add_child(_top_rows)
	var foot := _text("Score %s or more to earn a place        Press any key" % Hud.commas(Settings.TOP_SCORE_MIN),
		22, Color(0.8, 0.92, 1.0), Color(0, 0, 0, 0.9), 7)
	_place(foot, _top, 0.93)
	_top.visible = false


func _show_top(highlight: int) -> void:
	screen = Screen.TOPTEN
	_top_highlight = highlight
	_hide_all()
	for ch in _top_rows.get_children():
		ch.queue_free()
	var list := Settings.top_ten()
	var medal := [Color(1.0, 0.85, 0.15), Color(0.82, 0.86, 0.95), Color(0.95, 0.55, 0.25)]
	for i in Settings.TOP_SIZE:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 30)
		var col: Color = medal[i] if i < 3 else Color(0.75, 0.9, 1.0)
		var has := i < list.size()
		var cells := [["%d" % (i + 1), 70, HORIZONTAL_ALIGNMENT_RIGHT],
			[str(list[i]["name"]) if has else "- - -", 360, HORIZONTAL_ALIGNMENT_LEFT],
			[Hud.commas(int(list[i]["score"])) if has else "", 300, HORIZONTAL_ALIGNMENT_RIGHT],
			[str(list[i]["table"]).to_upper() if has else "", 300, HORIZONTAL_ALIGNMENT_LEFT]]
		for k in cells.size():
			var l := _text(cells[k][0], 34 if k < 3 else 20, col if has else Color(0.4, 0.45, 0.6), Color(0, 0, 0, 0.95), 9, Color(0, 0, 0, 0), k < 3)
			l.horizontal_alignment = cells[k][2]
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.custom_minimum_size = Vector2(cells[k][1], 46)
			row.add_child(l)
		row.set_meta("rank", i)
		_top_rows.add_child(row)
	_top.visible = true
	_play_music(UI_DIR + "intro_music.mp3")
	_flash.color.a = 0.6
	create_tween().tween_property(_flash, "color:a", 0.0, 0.4)


# ---------------------------------------------------------------- name entry

func _build_name() -> void:
	_name_panel = _full(Control.new(), _ui)
	_backdrop(_name_panel, 0.2)
	_shade(_name_panel, 0.6, 0.8)
	var head := _text("NEW HIGH SCORE!", 84, Color(1.0, 0.9, 0.3), Color(0.95, 0.15, 0.5), 18, Color(0, 0, 0, 0), true)
	_place(head, _name_panel, 0.2)
	_name_score = _text("0", 64, Color(0.4, 1.0, 1.0), Color(0.05, 0.1, 0.5), 14, Color(0, 0, 0, 0), true)
	_place(_name_score, _name_panel, 0.36)
	var ask := _text("ENTER YOUR NAME", 30, Color(1, 1, 1), Color(0, 0, 0, 0.9), 8)
	_place(ask, _name_panel, 0.52)
	_name_label = _text("_", 70, Color(1, 1, 1), Color(0.6, 0.1, 0.8), 14, Color(0, 0, 0, 0), true)
	_place(_name_label, _name_panel, 0.64)
	var hint := _text("Type your name, then press Enter", 22, Color(0.8, 0.92, 1.0), Color(0, 0, 0, 0.9), 7)
	_place(hint, _name_panel, 0.80)
	_online_hint = _text("", 18, Color(1.0, 0.85, 0.35), Color(0, 0, 0, 0.9), 6)
	_place(_online_hint, _name_panel, 0.88)
	_name_panel.visible = false


func _refresh_online_hint() -> void:
	if Settings.online:
		_online_hint.text = "Your name and score will also be posted to the global top 100 at %s  -  Tab: keep it on this computer only" % Online.SITE
	else:
		_online_hint.text = "This score stays on this computer  -  Tab: also post it to the global top 100 at %s" % Online.SITE


func _on_game_finished(final_score: int) -> void:
	if not Settings.qualifies(final_score) or _shot_dir != "":
		return
	_pending_score = final_score
	_pending_table = game.table["name"]
	_pending_table_id = game.table["id"]
	_refresh_online_hint()
	game.queue_free()
	game = null
	screen = Screen.NAME
	_hide_all()
	_name_text = ""
	_name_score.text = Hud.commas(final_score)
	_name_panel.visible = true
	_play_music(UI_DIR + "intro_music.mp3")


# ---------------------------------------------------------------- self-check

func _process(delta: float) -> void:
	_clock += delta
	if screen == Screen.INTRO:
		# the prompt and its neon rules cycle through the rainbow
		var hue := fmod(_clock * 0.22, 1.0)
		_press.label_settings.font_color = Color.from_hsv(hue, 0.35, 1.0)
		_press.label_settings.outline_color = Color.from_hsv(fmod(hue + 0.55, 1.0), 0.9, 0.85)
		for i in _lines.size():
			var w := 0.5 + 0.5 * sin(_clock * 2.4 + i * PI)
			_lines[i].color = Color.from_hsv(fmod(hue + 0.3 + i * 0.25, 1.0), 0.85, 1.0, 0.55 + 0.45 * w)
			_lines[i].anchor_left = 0.5 - 0.20 - 0.07 * w
			_lines[i].anchor_right = 0.5 + 0.20 + 0.07 * w
	elif screen == Screen.HOWTO:
		_howto_press.modulate.a = 0.35 + 0.65 * absf(sin(_clock * 3.0))
		_howto_press.label_settings.font_color = Color.from_hsv(fmod(_clock * 0.22, 1.0), 0.35, 1.0)
	elif screen == Screen.NAME:
		_name_label.text = _name_text + ("_" if fmod(_clock, 0.8) < 0.45 else " ")
	elif screen == Screen.TOPTEN and _top_highlight >= 0:
		for row in _top_rows.get_children():
			if row.get_meta("rank", -1) == _top_highlight:
				row.modulate = Color.from_hsv(fmod(_clock * 0.5, 1.0), 0.5, 1.0)
	if _shot_dir == "" or screen == Screen.GAME:
		return
	_frame += 1
	if _frame == 100:
		_save_shot("intro")
		_show_select()
	elif _frame == 150:
		_save_shot("select")
		_show_top(-1)
	elif _frame == 190:
		_save_shot("topten")
		# show the name-entry screen too, without recording anything
		_hide_all()
		screen = Screen.NAME
		_name_text = "ACE"
		_name_score.text = Hud.commas(123450)
		_refresh_online_hint()
		_name_panel.visible = true
	elif _frame == 210:
		_save_shot("name")
		_show_howto(0)
	elif _frame == 230:
		_save_shot("howto")
		_start_game(_shot_table)


func _save_shot(shot_name: String) -> void:
	var dir_path := ProjectSettings.globalize_path("res://").path_join(_shot_dir)
	DirAccess.make_dir_recursive_absolute(dir_path)
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(dir_path.path_join("screen_%s.png" % shot_name))
