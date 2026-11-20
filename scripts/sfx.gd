class_name Sfx
extends Node3D
## Sound effects, positioned at the impact point on the table.
## Shared mechanical samples come from res://assets/sfx/<name>_<n>.wav and each
## table adds its own themed set from res://assets/tables/<id>/sfx/. Several
## variants per sound are chosen at random so repeated hits never sound
## identical. A sound with no samples falls back to a synthesised stand-in.

const RATE := 22050
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer3D] = []
var _next := 0
var _rng := RandomNumberGenerator.new()
var _samples: Dictionary = {}      # name -> Array[AudioStream] (shared mechanical)
var _theme: Dictionary = {}        # name -> Array[AudioStream] (table specific)
var _layered: Array = []
var _last_pick: Dictionary = {}
var _flat: Array[AudioStreamPlayer] = []
var _flat_next := 0
var _ambient: AudioStreamPlayer
var table_id := ""
var _voice: Dictionary = {}        # announcer lines: name -> AudioStream
var _voice_player: AudioStreamPlayer
var _voice_level := 0
var _voice_next := ""
var _voice_next_level := 0
var voice_enabled := true


func _ready() -> void:
	_rng.seed = 12345
	_streams["flipper"] = _synth([70.0, 140.0], 0.09, 40.0, 0.7, 0.9)
	_streams["flipper_down"] = _synth([55.0], 0.06, 55.0, 0.5, 0.5)
	_streams["bumper"] = _synth([95.0, 190.0, 760.0], 0.16, 26.0, 0.35, 0.9)
	_streams["sling"] = _synth([180.0, 420.0], 0.08, 45.0, 0.6, 0.8)
	_streams["target"] = _synth([1320.0, 1980.0], 0.30, 12.0, 0.05, 0.6)
	_streams["rollover"] = _synth([880.0, 1760.0], 0.22, 14.0, 0.02, 0.5)
	_streams["metal"] = _synth([2100.0, 3300.0, 4700.0], 0.05, 70.0, 0.25, 0.5)
	_streams["rubber"] = _synth([240.0], 0.05, 60.0, 0.3, 0.6)
	_streams["ball"] = _synth([2600.0, 5200.0], 0.04, 90.0, 0.1, 0.5)
	_streams["launch"] = _synth([60.0, 120.0], 0.22, 16.0, 0.8, 0.9)
	_streams["drain"] = _sweep(420.0, 90.0, 0.7, 0.5)
	_streams["bonus"] = _sweep(660.0, 1320.0, 0.35, 0.5)
	for sound in _streams.keys():
		var list := _load_set("res://assets/sfx/", sound)
		if list.size() > 0:
			_samples[sound] = list
	_load_theme()
	for line in ["start", "allright", "heehay", "ohyeah", "haha", "niceshot", "combo", "jackpot",
			"multiball", "unbelievable", "easy", "tough", "lastball", "highscore", "gameover"]:
		var vs := Tables.audio("res://assets/voice/%s.wav" % line)
		if vs != null:
			_voice[line] = vs
	_voice_player = AudioStreamPlayer.new()
	_voice_player.bus = "SFX"
	_voice_player.volume_db = -1.0
	add_child(_voice_player)
	_voice_player.finished.connect(_voice_done)
	for i in 4:
		var fp := AudioStreamPlayer.new()
		fp.bus = "SFX"
		add_child(fp)
		_flat.append(fp)
	for i in 12:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 4.0
		p.max_distance = 30.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.panning_strength = 2.0
		add_child(p)
		_players.append(p)


func play(sound: String, world_pos: Vector3, strength: float = 1.0) -> void:
	var themed: Array = _theme.get(sound, [])
	if themed.size() > 0:
		_play_stream(_pick(themed, "t_" + sound), world_pos, strength * 0.8)
		if not _layered.has(sound):
			return
	var variants: Array = _samples.get(sound, [])
	if variants.size() > 0:
		_play_stream(_pick(variants, sound), world_pos, strength)
	elif _streams.has(sound) and themed.is_empty():
		_play_stream(_streams[sound], world_pos, strength)


## Plays a themed, non-positional sound such as the game-start sting.
func play_flat(sound: String, volume_db: float = -4.0) -> void:
	var themed: Array = _theme.get(sound, [])
	if themed.is_empty():
		return
	var p := _flat[_flat_next]
	_flat_next = (_flat_next + 1) % _flat.size()
	p.stream = _pick(themed, "t_" + sound)
	p.volume_db = volume_db
	p.play()


## The announcer. A line of a higher level cuts in on the one playing; with
## wait = true a line that cannot play yet is said next instead of dropped.
func say(line: String, level: int = 1, wait: bool = false) -> void:
	if not voice_enabled or not _voice.has(line):
		return
	if _voice_player.playing and level <= _voice_level:
		if wait and level >= _voice_next_level:
			_voice_next = line
			_voice_next_level = level
		return
	_voice_level = level
	_voice_player.stream = _voice[line]
	_voice_player.play()


func _voice_done() -> void:
	_voice_level = 0
	if _voice_next != "":
		var line := _voice_next
		var level := _voice_next_level
		_voice_next = ""
		_voice_next_level = 0
		say(line, level)


func voice_count() -> int:
	return _voice.size()


func _pick(variants: Array, key: String) -> AudioStream:
	var pick := _rng.randi() % variants.size()
	if variants.size() > 1 and pick == _last_pick.get(key, -1):
		pick = (pick + 1) % variants.size()
	_last_pick[key] = pick
	return variants[pick]


func _play_stream(stream: AudioStream, world_pos: Vector3, strength: float) -> void:
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.global_position = world_pos
	p.pitch_scale = _rng.randf_range(0.95, 1.06)
	p.volume_db = linear_to_db(clampf(strength, 0.08, 1.0)) + _rng.randf_range(-1.0, 0.0)
	p.play()


func _load_set(dir_path: String, sound: String) -> Array:
	var list: Array = []
	for n in range(1, 9):
		var stream := Tables.audio("%s%s_%d.wav" % [dir_path, sound, n])
		if stream != null:
			list.append(stream)
	return list


func _load_theme() -> void:
	if table_id == "":
		return
	var base := Tables.dir(table_id) + "sfx/"
	for sound in ["bumper", "target", "rollover", "bonus", "drain", "start", "sling", "launch"]:
		var list := _load_set(base, sound)
		if list.size() > 0:
			_theme[sound] = list
	var amb := Tables.audio(base + "ambient.wav")
	if amb != null:
		if amb is AudioStreamWAV:
			amb.loop_mode = AudioStreamWAV.LOOP_FORWARD
			amb.loop_end = int(amb.get_length() * amb.mix_rate)
		_ambient = AudioStreamPlayer.new()
		_ambient.stream = amb
		_ambient.bus = "SFX"
		_ambient.volume_db = -16.0
		add_child(_ambient)
		_ambient.play()


func sample_count() -> int:
	var n := 0
	for k in _samples:
		n += _samples[k].size()
	for k in _theme:
		n += _theme[k].size()
	return n


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s


func _synth(freqs: Array, dur: float, decay: float, noise: float, gain: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for f in freqs:
			v += sin(TAU * f * t)
		v /= freqs.size()
		v = v * (1.0 - noise) + _rng.randf_range(-1.0, 1.0) * noise * exp(-decay * 2.0 * t)
		out[i] = v * exp(-decay * t) * gain * minf(1.0, i / 30.0)
	return _wav(out)


func _sweep(f0: float, f1: float, dur: float, gain: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += TAU * lerpf(f0, f1, t) / RATE
		out[i] = (sin(phase) + 0.3 * sin(phase * 2.0)) * gain * (1.0 - t) * minf(1.0, i / 60.0)
	return _wav(out)
