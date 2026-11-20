class_name Game
extends Node3D
## One game on one table: wires physics, table view, camera, sound, input,
## scoring and the HUD together. Physics runs in _physics_process at a fixed 120 Hz;
## everything visual interpolates between physics states.

const BALLS_PER_GAME := 3
const SAVE_PATH := "user://pinball.cfg"
const NUDGE := 0.35

signal exit_requested
signal game_finished(final_score: int)

var table: Dictionary = Tables.LIST[0]
var autoplay_dir := ""        # set by the app for automated screenshot runs

var phys: PinPhysics
var view: TableView
var cam: CameraRig
var sfx: Sfx

var score := 0
var best := 0
var ball_num := 1
var multiplier := 1
var game_over := false
var paused := false
var charge := 0.0
var charging := false
var respawn_timer := -1.0
var top_lit := [false, false, false]
var toast_time := 0.0
var nudge_heat := 0.0
var _held: Array = []            # [ball, seconds left] captured by the black hole
var _hole_cooldown := 0.0
var hud: Hud
var _env: Environment
var _spots: Array[SpotLight3D] = []
var _probe: ReflectionProbe
var _fps_clock := 0.0
var _fps_frames := 0

# automated screenshot run (used for visual checks): --shot=<dir>
var _shot_dir := ""
var _frame := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_best()

	phys = PinPhysics.new()
	TableLayout.table_id = table["id"]
	TableLayout.build(phys)

	_build_environment()
	_build_room()
	view = TableView.new()
	add_child(view)
	view.setup(phys, table)

	cam = CameraRig.new()
	add_child(cam)
	cam.table = view
	cam.make_current()

	sfx = Sfx.new()
	sfx.table_id = table["id"]
	sfx._layered = table.get("layered", [])
	add_child(sfx)

	_build_hud()
	_new_game()
	cam.snap()
	apply_quality()
	_shot_dir = autoplay_dir


# ---------------------------------------------------------------- setup

func _look() -> Dictionary:
	var look: Dictionary = table.get("look", {}).duplicate()
	# tuning aid: --look=albedo,exposure,ambient,contrast,spots
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--look="):
			var v := a.trim_prefix("--look=").split_floats(",")
			var keys := ["albedo", "exposure", "ambient", "contrast", "spots", "saturation"]
			for i in mini(v.size(), keys.size()):
				look[keys[i]] = v[i]
	table = table.duplicate()
	table["look"] = look
	return look


func _build_environment() -> void:
	var env := Environment.new()
	# A "dark room with a softbox overhead" sky. The camera always looks down,
	# so only the dark lower half is ever seen as background, while the bright
	# upper half gives chrome and the steel ball something to reflect.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.95, 0.97, 1.0)
	sky_mat.sky_horizon_color = Color(0.10, 0.11, 0.15)
	sky_mat.sky_curve = 0.35
	sky_mat.ground_bottom_color = Color(0.008, 0.008, 0.012)
	sky_mat.ground_horizon_color = Color(0.03, 0.03, 0.045)
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.2
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.22
	env.adjustment_saturation = 1.22
	env.glow_enabled = false
	env.glow_intensity = 0.07
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 3.0
	env.ssr_enabled = true
	env.ssao_enabled = true
	env.ssao_radius = 0.05
	env.ssao_intensity = 2.6
	# per-table lighting: brightly printed tables need less light and contrast
	var look := _look()
	env.tonemap_exposure = look.get("exposure", env.tonemap_exposure)
	env.ambient_light_energy = look.get("ambient", env.ambient_light_energy)
	env.adjustment_contrast = look.get("contrast", env.adjustment_contrast)
	env.adjustment_saturation = look.get("saturation", env.adjustment_saturation)
	_env = env
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# a dim overall wash, then two shadow-casting spotlights for depth
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-70, 20, 0)
	sun.light_energy = 0.12
	add_child(sun)
	for d in [[Vector3(-0.45, 1.0, -0.15), Color(1.0, 0.95, 0.88), 1.7], [Vector3(0.5, 0.9, -0.95), Color(0.8, 0.88, 1.0), 0.8]]:
		var sp := SpotLight3D.new()
		sp.position = d[0]
		add_child(sp)
		sp.look_at(Vector3(-0.02, 0.03, -0.5), Vector3.UP)
		sp.light_color = d[1]
		sp.light_energy = d[2] * look.get("spots", 1.0)
		sp.spot_range = 2.5
		sp.spot_angle = 38.0
		sp.spot_attenuation = 0.6
		sp.shadow_enabled = true
		sp.shadow_blur = 1.2
		sp.shadow_bias = 0.02
		_spots.append(sp)


## The arcade around the machine: carpet, dim walls and a reflection probe so
## chrome and the steel ball mirror their surroundings.
func _build_room() -> void:
	var floor_y := -0.98
	var carpet := Tables.texture("res://assets/ui/carpet.jpg")
	var wall := Tables.texture("res://assets/ui/arcade_wall.jpg")
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(0.3, 0.3, 0.33) if carpet != null else Color(0.02, 0.02, 0.03)
	fm.albedo_texture = carpet
	fm.uv1_scale = Vector3(5, 5, 5)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(10, 10)
	fl.mesh = pm
	fl.material_override = fm
	fl.position = Vector3(0, floor_y, -0.5)
	add_child(fl)
	# soft shadow under the cabinet
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.92))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_texture = gt
	var sh := MeshInstance3D.new()
	var spm := PlaneMesh.new()
	spm.size = Vector2(2.6, 3.4)
	sh.mesh = spm
	sh.material_override = sm
	sh.position = Vector3(0, floor_y + 0.003, -0.5)
	add_child(sh)
	if wall != null:
		var wm := StandardMaterial3D.new()
		wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		wm.albedo_color = Color(0.36, 0.36, 0.4)
		wm.albedo_texture = wall
		for d in [[Vector3(0, floor_y + 2.2, -4.2), 0.0], [Vector3(-4.0, floor_y + 2.2, -0.5), PI * 0.5], [Vector3(4.0, floor_y + 2.2, -0.5), -PI * 0.5]]:
			var q := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(8.6, 4.8)
			q.mesh = qm
			q.material_override = wm
			q.position = d[0]
			q.rotation.y = d[1]
			add_child(q)
	_probe = ReflectionProbe.new()
	_probe.position = Vector3(0, 0.22, -0.5)
	_probe.size = Vector3(1.6, 1.6, 2.6)
	_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	_probe.max_distance = 12.0
	add_child(_probe)


## Applies the graphics quality (Settings.quality) to lighting and effects.
func apply_quality() -> void:
	var q := Settings.quality
	_env.ssr_enabled = q >= 2
	_env.ssao_enabled = q >= 1
	for sp in _spots:
		sp.shadow_enabled = q >= 1
	_probe.visible = q >= 1


func _build_hud() -> void:
	hud = Hud.new()
	add_child(hud)
	hud.setup(BALLS_PER_GAME, table)


# ---------------------------------------------------------------- game flow

func _new_game() -> void:
	score = 0
	ball_num = 1
	multiplier = 1
	game_over = false
	top_lit = [false, false, false]
	for id in TableLayout.S_TOP:
		view.set_insert(id, false)
	phys.clear_balls()
	_spawn_ball()
	sfx.play_flat("start")
	_toast("Ball 1 - hold Space and release to launch")


func _spawn_ball() -> void:
	phys.add_ball(TableLayout.BALL_START)


func _ball_in_lane() -> PinPhysics.Ball:
	for b in phys.balls:
		if b.active and b.pos.x > TableLayout.LANE_X and b.pos.y < 0.12 and b.vel.length() < 0.3:
			return b
	return null


func _toast(text: String, seconds: float = 2.5) -> void:
	hud.toast(text, seconds)


func _add_score(points: int) -> void:
	score += points * multiplier


## Shows the points just scored floating up from where it happened.
func _pop(at: Vector2, points: int, colour: String) -> void:
	var wp := view.ball_world(at)
	if not cam.is_position_behind(wp):
		hud.popup(cam.unproject_position(wp), "+" + _commas(points * multiplier), colour)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		paused = not paused
		hud.set_pause(paused, "PAUSED\nESC  RESUME        Q  LEAVE TABLE")
	elif event.is_action_pressed("camera_mode"):
		cam.mode = (cam.mode + 1) % CameraRig.MODE_NAMES.size()
		_toast("Camera: " + CameraRig.MODE_NAMES[cam.mode], 1.5)
	elif event.is_action_pressed("quality"):
		Settings.quality = (Settings.quality + 1) % 3
		Settings.quality_auto = false
		Settings.apply_viewport(get_viewport())
		apply_quality()
		Settings.save_quality()
		_toast("Graphics: " + Settings.QUALITY_NAMES[Settings.quality], 1.5)
	elif event.is_action_pressed("toggle_help"):
		hud.toggle_help()
	elif event.is_action_pressed("toggle_effects"):
		view.effects_enabled = not view.effects_enabled
		cam.shake_enabled = view.effects_enabled
		_toast("Effects: " + ("on" if view.effects_enabled else "reduced"), 1.5)
	elif event.is_action_pressed("debug_ball") and not game_over:
		phys.add_ball(Vector2(TableLayout.XC, 0.55), Vector2(randf_range(-0.6, 0.6), 0.8))
	if paused:
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_Q:
			exit_requested.emit()
		return
	if event.is_action_pressed("launch"):
		if game_over:
			_new_game()
		elif _ball_in_lane() != null:
			charging = true
			charge = 0.0
	elif event.is_action_released("launch") and charging:
		charging = false
		var b := _ball_in_lane()
		if b != null:
			b.vel.y = 1.5 + 2.1 * charge
			sfx.play("launch", view.ball_world(b.pos), 0.5 + 0.5 * charge)
	for dirn in [["nudge_left", Vector2(-NUDGE, 0.05)], ["nudge_right", Vector2(NUDGE, 0.05)], ["nudge_up", Vector2(0, NUDGE)]]:
		if event.is_action_pressed(dirn[0]) and nudge_heat < 1.0:
			phys.nudge(dirn[1])
			nudge_heat += 0.45
			cam.add_shake(0.5)


func _physics_process(delta: float) -> void:
	if paused:
		return
	phys.set_flipper(0, Input.is_action_pressed("flipper_left") and not game_over)
	phys.set_flipper(2, Input.is_action_pressed("flipper_left") and not game_over)
	phys.set_flipper(1, Input.is_action_pressed("flipper_right") and not game_over)
	if _shot_dir != "":
		_autoplay()
	if charging:
		charge = minf(1.0, charge + delta / 0.9)
	nudge_heat = maxf(0.0, nudge_heat - delta * 0.4)

	phys.step(delta)
	_handle_events()
	_hole_cooldown = maxf(0.0, _hole_cooldown - delta)
	for h in _held.duplicate():
		h[1] -= delta
		if h[1] <= 0.0:
			var hb: PinPhysics.Ball = h[0]
			hb.held = false
			hb.vel = Vector2(randf_range(-0.9, 0.9), -1.5)
			_held.erase(h)
			view.hole_pulse(1.0)
			view.spark(hb.pos, 3.0)
			view.flash_at(hb.pos, Color(1.0, 0.6, 0.2), 5.0)
			_flash_screen(Color(1.0, 0.7, 0.4), 0.35)
			cam.add_shake(0.6)
			sfx.play("bumper", view.ball_world(hb.pos), 1.0)

	# rescue a ball that has come to rest somewhere it should not
	for b in phys.balls:
		if b.active and b.still_time > 4.0 and b.pos.x < TableLayout.LANE_X \
				and not phys.flippers[0].pressed and not phys.flippers[1].pressed:
			b.vel = Vector2(randf_range(-0.3, 0.3), 0.4)
			b.still_time = 0.0

	if respawn_timer > 0.0:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_spawn_ball()
			_toast("Ball %d" % ball_num)


func _handle_events() -> void:
	var E := PinPhysics.Ev
	for e in phys.events:
		var kind: int = e[0]
		var at: Vector2 = e[1]
		var strength: float = e[2]
		var id: int = e[3]
		var wp := view.ball_world(at)
		var vol := clampf(strength / 2.5, 0.1, 1.0)
		match kind:
			E.BUMPER:
				_add_score(100)
				_pop(at, 100, "gold")
				view.flash_bumper(id)
				view.spark(at, strength)
				view.flash_at(at, Color(1.0, 0.6, 0.2), 3.0)
				view.excite(0.5)
				cam.add_shake(0.35)
				sfx.play("bumper", wp, 0.9)
			E.SLING:
				_add_score(10)
				view.flash_sling(id)
				view.spark(at, strength)
				view.flash_at(at, Color(1.0, 0.3, 0.2), 1.6)
				view.excite(0.2)
				sfx.play("sling", wp, 0.8)
			E.TARGET:
				_add_score(500)
				_pop(at, 500, "cyan")
				view.flash_target(id)
				view.spark(at, strength)
				view.flash_at(at, Color(1.0, 0.9, 0.3), 2.2)
				view.excite(0.4)
				sfx.play("target", wp, 0.7)
			E.WALL:
				sfx.play("metal", wp, vol * 0.6)
				if strength > 1.1:
					view.spark(at, strength)
			E.RUBBER:
				sfx.play("rubber", wp, vol)
				if id >= TableLayout.POST_ID:
					_add_score(20)
					view.flash_post(id)
					if strength > 0.8:
						view.spark(at, strength * 0.5)
			E.FLIPPER:
				if strength > 1.0:
					view.next_trail_color()
				if strength > 1.5:
					view.spark(at, strength * 0.6)
					view.flash_at(at, Color(0.5, 0.8, 1.0), 1.5)
			E.BALL:
				sfx.play("ball", wp, vol)
				view.spark(at, strength)
			E.FLIP_UP:
				sfx.play("flipper", wp, 0.8)
			E.FLIP_DOWN:
				sfx.play("flipper_down", wp, 0.4)
			E.SENSOR:
				_on_sensor(id, wp, at)
			E.DRAIN:
				_on_drain(wp)
	phys.events.clear()


func _flash_screen(col: Color, alpha: float) -> void:
	if view.effects_enabled:
		hud.flash(col, alpha)


func _capture(at: Vector2) -> void:
	# The black hole swallows a slow enough ball, holds it, then spits it out.
	if _hole_cooldown > 0.0:
		return
	for b in phys.balls:
		if b.active and not b.held and b.pos.distance_to(at) < 0.03 and b.vel.length() < 2.6:
			b.held = true
			b.vel = Vector2.ZERO
			b.pos = TableLayout.HOLE
			b.prev = b.pos
			_held.append([b, 1.1])
			_hole_cooldown = 2.0
			_add_score(1000)
			_pop(at, 1000, "orange")
			view.hole_pulse(1.0)
			view.excite(1.5)
			sfx.play("bonus", view.ball_world(at), 0.8)
			_toast("%s  +%s" % [table.get("saucer", "BLACK HOLE"), _commas(1000 * multiplier)], 1.6)
			return


func _on_sensor(id: int, wp: Vector3, at: Vector2 = Vector2.ZERO) -> void:
	if id == TableLayout.S_LANE:
		return
	if id == TableLayout.S_HOLE:
		_capture(TableLayout.HOLE)
		return
	if id == TableLayout.S_SPINNER:
		var speed := 1.0
		for b in phys.balls:
			if b.active and b.pos.distance_to(at) < 0.03:
				speed = b.vel.length()
		_add_score(100)
		_pop(at, 100, "pink")
		view.spin(speed)
		view.excite(0.3)
		sfx.play("metal", wp, 0.5)
		return
	if id in TableLayout.S_TOP:
		var i: int = TableLayout.S_TOP.find(id)
		_add_score(250)
		_pop(at, 250, "green")
		top_lit[i] = true
		view.set_insert(id, true)
		sfx.play("rollover", wp, 0.6)
		if not top_lit.has(false):
			multiplier = mini(multiplier + 1, 5)
			top_lit = [false, false, false]
			for s in TableLayout.S_TOP:
				view.set_insert(s, false)
			sfx.play("bonus", wp, 0.8)
			view.excite(1.5)
			_flash_screen(Color(0.5, 0.8, 1.0), 0.3)
			_toast("Bonus multiplier x%d" % multiplier)
	else:
		_add_score(50)
		view.pulse_insert(id)
		sfx.play("rollover", wp, 0.4)


func _on_drain(wp: Vector3) -> void:
	sfx.play("drain", wp, 0.7)
	if phys.active_balls().size() > 0:
		return
	phys.clear_balls()
	_held.clear()
	charging = false
	ball_num += 1
	if ball_num > BALLS_PER_GAME:
		game_over = true
		if score > best:
			best = score
			_save_best()
			_toast("New best score! Press Space to play again", 9999.0)
		else:
			_toast("Game over - press Space to play again", 9999.0)
		game_finished.emit(score)
	else:
		respawn_timer = 1.2


func _process(delta: float) -> void:
	var frac := 0.0 if paused else Engine.get_physics_interpolation_fraction()
	cam.update_rig(delta, phys.active_balls())
	view.cam_local = view.to_local(cam.global_position)
	view.set_plunger(charge if charging else 0.0)
	view.sync(0.0 if paused else delta, frac)

	view.score_label.text = _commas(score)
	hud.effects_enabled = view.effects_enabled
	var left := 0 if game_over else BALLS_PER_GAME - ball_num + 1
	hud.refresh(delta, score, maxi(best, score), left, multiplier, charge if charging else -1.0)

	# if the game runs slowly, step the graphics quality down by itself
	if Settings.quality_auto and Settings.quality > 0 and not paused and _shot_dir == "":
		_fps_clock += delta
		if _fps_clock > 2.5:
			_fps_frames += 1
		if _fps_clock > 6.0:
			var fps := _fps_frames / (_fps_clock - 2.5)
			_fps_clock = 0.0
			_fps_frames = 0
			if fps < 45.0:
				Settings.quality -= 1
				Settings.apply_viewport(get_viewport())
				apply_quality()
				Settings.save_quality()
				_toast("Graphics set to %s for smoother play" % Settings.QUALITY_NAMES[Settings.quality], 2.5)

	if _shot_dir != "":
		_shot_step()


func _commas(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func _load_best() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		best = int(cf.get_value("scores", table["id"], 0))


func _save_best() -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	cf.set_value("scores", table["id"], best)
	cf.save(SAVE_PATH)


# ---------------------------------------------------------------- self-check
# Plays automatically, saves screenshots and reports whether the ball and the
# flippers were on screen in every frame. Run: godot --path . -- --shot=shots

var _tick := 0
var _vis_fail_ball := 0
var _vis_fail_flip := 0
var _vis_frames := 0


func _autoplay() -> void:
	_tick += 1
	if _tick == 40:
		var b := _ball_in_lane()
		if b != null:
			b.vel.y = 3.3
	if _tick == 700:
		phys.add_ball(Vector2(TableLayout.XC, 0.6), Vector2(0.5, 0.9))
		phys.add_ball(Vector2(-0.1, 0.5), Vector2(-0.4, 0.6))
	for f in phys.flippers:
		var press := false
		for b in phys.balls:
			if b.active and b.pos.y < 0.2 and b.vel.y < 0.0 and absf(b.pos.x - f.pivot.x) < 0.1:
				press = true
		if f.id == 2:
			continue
		if press or (f.pressed and _tick % 30 != 0):
			phys.set_flipper(f.id, true)
		else:
			phys.set_flipper(f.id, false)
	phys.set_flipper(2, phys.flippers[0].pressed)


func _on_screen(world_pos: Vector3) -> bool:
	if cam.is_position_behind(world_pos):
		return false
	var r := get_viewport().get_visible_rect()
	return r.grow(-4.0).has_point(cam.unproject_position(world_pos))


func _shot_step() -> void:
	_frame += 1
	if _frame > 20:
		_vis_frames += 1
		for b in phys.active_balls():
			if not _on_screen(view.ball_world(b.prev.lerp(b.pos, 1.0))):
				_vis_fail_ball += 1
				break
		for f in phys.flippers:
			if not cam.flippers_needed or f.id >= 2:
				break
			if not _on_screen(view.ball_world(f.pivot)) or not _on_screen(view.ball_world(f.tip())):
				_vis_fail_flip += 1
				break
	if _frame in [30, 150, 330, 520, 900, 1100]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://").path_join(_shot_dir))
		var img := get_viewport().get_texture().get_image()
		if img != null:
			img.save_png(ProjectSettings.globalize_path("res://").path_join(_shot_dir).path_join("shot_%04d.png" % _frame))
	if _frame == 300:
		cam.mode = CameraRig.Mode.FULL_TABLE
	if _frame == 360:
		cam.mode = CameraRig.Mode.DYNAMIC
	if _frame >= 1120:
		print("SELFCHECK frames=%d ball_offscreen=%d flippers_offscreen=%d fps=%d score=%d sfx_samples=%d" % [
			_vis_frames, _vis_fail_ball, _vis_fail_flip, int(Engine.get_frames_per_second()), score, sfx.sample_count()])
		get_tree().quit()
