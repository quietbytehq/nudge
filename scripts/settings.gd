class_name Settings
extends RefCounted
## Saved settings and the top-ten table (user://pinball.cfg).

const PATH := "user://pinball.cfg"
const QUALITY_NAMES := ["Low", "Medium", "High"]
const TOP_SCORE_MIN := 100000      # a score must reach this to enter the top ten
const TOP_SIZE := 10

static var quality := 2            # 0 low, 1 medium, 2 high
static var quality_auto := true    # lower the quality automatically if the game runs slowly


static func _cfg() -> ConfigFile:
	var cf := ConfigFile.new()
	cf.load(PATH)
	return cf


static func load_all() -> void:
	var cf := _cfg()
	quality = clampi(int(cf.get_value("settings", "quality", 2)), 0, 2)
	quality_auto = bool(cf.get_value("settings", "quality_auto", true))


static func save_quality() -> void:
	var cf := _cfg()
	cf.set_value("settings", "quality", quality)
	cf.set_value("settings", "quality_auto", quality_auto)
	cf.save(PATH)


## Resolution and edge smoothing for the chosen quality.
static func apply_viewport(vp: Viewport) -> void:
	vp.use_taa = false
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.texture_mipmap_bias = -0.8
	match quality:
		2:
			vp.msaa_3d = Viewport.MSAA_4X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.scaling_3d_scale = 1.3
			vp.anisotropic_filtering_level = Viewport.ANISOTROPY_16X
		1:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.scaling_3d_scale = 1.0
			vp.anisotropic_filtering_level = Viewport.ANISOTROPY_8X
		_:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.scaling_3d_scale = 0.8
			vp.anisotropic_filtering_level = Viewport.ANISOTROPY_4X


# ---------------------------------------------------------------- top ten

static func top_ten() -> Array:
	var list: Array = _cfg().get_value("scores", "top_ten", [])
	return list


static func qualifies(score: int) -> bool:
	if score < TOP_SCORE_MIN:
		return false
	var list := top_ten()
	return list.size() < TOP_SIZE or score > int(list[list.size() - 1]["score"])


## Adds an entry and returns its rank (0 = first place).
static func add_top(player: String, score: int, table_name: String) -> int:
	var list := top_ten()
	var entry := {"name": player, "score": score, "table": table_name}
	var rank := list.size()
	for i in list.size():
		if score > int(list[i]["score"]):
			rank = i
			break
	list.insert(rank, entry)
	while list.size() > TOP_SIZE:
		list.pop_back()
	var cf := _cfg()
	cf.set_value("scores", "top_ten", list)
	cf.save(PATH)
	return rank
