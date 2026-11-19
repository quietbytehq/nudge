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
		"name": "Deep Space",
		"tagline": "Sun, pulsar, black hole and the outer planets",
		"available": true,
		"layered": ["bumper"],
		"accent": Color(0.35, 0.7, 1.0),
	},
	{"id": "table_2", "name": "Table 2", "tagline": "Coming soon", "available": false},
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
