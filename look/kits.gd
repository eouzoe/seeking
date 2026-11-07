extends RefCounted

const BLEND := 80.0

const KITS := {
	"prologue": {
		"leaf_tint": Color(0.28, 0.34, 0.33), "bark_tint": Color(0.32, 0.31, 0.36),
		"bloom": 0.0, "bloom_tint": Color(0.9, 0.85, 0.95),
		"fall_leaf": 0.15, "fall_petal": 0.0, "leaf_color": Color(0.22, 0.28, 0.24), "petal_color": Color(0.9, 0.85, 0.9),
		"dapple": 0.0, "mist": 0.7, "mist_color": Color(0.55, 0.6, 0.78),
		"birds": 0.0, "butterflies": 0.0, "fireflies": 1.0,
	},
	"dawn": {
		"leaf_tint": Color(0.42, 0.56, 0.36), "bark_tint": Color(0.42, 0.38, 0.4),
		"bloom": 0.0, "bloom_tint": Color(1.0, 0.9, 0.92),
		"fall_leaf": 0.6, "fall_petal": 0.0, "leaf_color": Color(0.34, 0.46, 0.24), "petal_color": Color(1.0, 0.86, 0.9),
		"dapple": 0.3, "mist": 0.45, "mist_color": Color(0.95, 0.8, 0.78),
		"birds": 0.6, "butterflies": 0.0, "fireflies": 0.3,
	},
	"bloom": {
		"leaf_tint": Color(0.5, 0.64, 0.4), "bark_tint": Color(0.46, 0.42, 0.42),
		"bloom": 0.55, "bloom_tint": Color(1.0, 0.86, 0.9),
		"fall_leaf": 0.25, "fall_petal": 0.9, "leaf_color": Color(0.38, 0.52, 0.28), "petal_color": Color(1.0, 0.84, 0.9),
		"dapple": 1.0, "mist": 0.12, "mist_color": Color(0.95, 0.95, 0.9),
		"birds": 0.35, "butterflies": 1.0, "fireflies": 0.0,
	},
}

static func at(scenes: Array, x: float) -> Dictionary:
	if scenes.is_empty():
		return KITS["dawn"]
	var i := 0
	for k in scenes.size():
		if x >= float(scenes[k]["x0"]):
			i = k
	var cur: Dictionary = KITS.get(String(scenes[i]["id"]), KITS["dawn"])
	if i == 0:
		return cur
	var w := smoothstep(-BLEND, BLEND, x - float(scenes[i]["x0"]))
	if w >= 1.0:
		return cur
	var prev: Dictionary = KITS.get(String(scenes[i - 1]["id"]), KITS["dawn"])
	var out := {}
	for key: String in cur:
		var a: Variant = prev[key]
		var b: Variant = cur[key]
		if a is Color:
			out[key] = (a as Color).lerp(b as Color, w)
		else:
			out[key] = lerpf(float(a), float(b), w)
	return out
