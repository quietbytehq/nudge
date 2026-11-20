class_name Tables
extends RefCounted
## The table roster. Each table has its own folder under res://assets/tables/<id>/
## holding its artwork, music and themed sounds:
##   playfield.jpg  backglass.jpg  card.jpg  music.mp3  sfx/<event>_<n>.wav
## Themed sounds replace the shared mechanical sound for that event, except
## the events listed in "layered", which play on top of it.

const LIST := [
	{
		"id": "deep_space",
		"name": "Cosmic Drift",
		"tagline": "Sun, pulsar, black hole and the outer planets",
		"available": true,
		"layered": ["bumper"],
		"saucer": "BLACK HOLE",
	},
	{
		"id": "paradise_bay",
		"name": "Paradise Bay",
		"tagline": "Ride the pier through the volcano; surfboards, tiki hut, three flippers",
		"available": true,
		"layered": ["bumper"],
		"saucer": "TIKI HUT",
		"saucer_reach": 0.05,
		"saucer_speed": 5.0,
		"saucer_kick": Vector2(1.2, -0.9),
		"ramp": true,
		"theme": "paradise",
		"bumper_kinds": ["beach", "coconut", "coconut", "beach", "drum", "buoy", "islet"],
		"look": {"albedo": 0.8, "exposure": 0.9, "ambient": 0.2, "contrast": 1.1, "spots": 0.7},
		"bumper_cols": [Color(0.55, 0.33, 0.14), Color(0.6, 0.36, 0.15), Color(0.5, 0.3, 0.12),
			Color(1.0, 0.25, 0.2), Color(0.1, 0.6, 1.0), Color(1.0, 0.75, 0.1), Color(0.2, 0.85, 0.5)],
	},
	{"id": "table_3", "name": "Table 3", "tagline": "Coming soon", "available": false},
	{"id": "table_4", "name": "Table 4", "tagline": "Coming soon", "available": false},
	{"id": "table_5", "name": "Table 5", "tagline": "Coming soon", "available": false},
	{"id": "table_6", "name": "Table 6", "tagline": "Coming soon", "available": false},
]


static func dir(id: String) -> String:
	return "res://assets/tables/%s/" % id


## Loads an image as a texture whether or not the editor has imported it yet.
static func texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			img.generate_mipmaps()
			return ImageTexture.create_from_image(img)
	return null


## Loads a .wav or .mp3 whether or not the editor has imported it yet.
static func audio(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		if path.ends_with(".mp3"):
			return AudioStreamMP3.load_from_file(path)
		return AudioStreamWAV.load_from_file(path)
	return null


## Loads a .ttf from res://assets/fonts/ whether or not it has been imported.
## Returns null if the font is missing, so callers fall back to the default.
static func font(font_name: String) -> Font:
	var path := "res://assets/fonts/%s.ttf" % font_name
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var f := FontFile.new()
		if f.load_dynamic_font(path) == OK:
			return f
	return null
