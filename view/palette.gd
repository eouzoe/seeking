extends RefCounted

const KEYS: Array[Dictionary] = [
	{"t": 0.0, "star": 1.0, "zenith": "#070b1f", "horizon": "#1a2246", "glow": "#2b3566", "sun": "#dfe6ff", "fog": "#1a2246", "ink": "#05070f", "accent": "#ffe08a", "sun_a": 0.0},
	{"t": 0.22, "star": 0.5, "zenith": "#2b2a5a", "horizon": "#f08a6a", "glow": "#ffc27a", "sun": "#ffd9a0", "fog": "#c2708a", "ink": "#1a1030", "accent": "#ffb3c6", "sun_a": 0.9},
	{"t": 0.29, "star": 0.05, "zenith": "#4f78b8", "horizon": "#ffd2a6", "glow": "#ffd99a", "sun": "#ffeccc", "fog": "#d9b4a2", "ink": "#1d1f30", "accent": "#ffc2a0", "sun_a": 1.0},
	{"t": 0.38, "star": 0.0, "zenith": "#5ea3d6", "horizon": "#f7ebc6", "glow": "#ffe8a6", "sun": "#fff8e2", "fog": "#b2d5b2", "ink": "#143027", "accent": "#ffd23f", "sun_a": 1.0},
	{"t": 0.5, "star": 0.0, "zenith": "#4b95d2", "horizon": "#eef0cf", "glow": "#fff4cc", "sun": "#ffffff", "fog": "#a2ceaa", "ink": "#12291f", "accent": "#ffd23f", "sun_a": 1.0},
	{"t": 0.62, "star": 0.0, "zenith": "#6f8fc8", "horizon": "#ffd28a", "glow": "#ffb24f", "sun": "#fff0c8", "fog": "#f2b47c", "ink": "#2e1a1c", "accent": "#ffb347", "sun_a": 1.0},
	{"t": 0.68, "star": 0.0, "zenith": "#5a7fc8", "horizon": "#ffcf8a", "glow": "#ffb15a", "sun": "#ffe4b0", "fog": "#e0a880", "ink": "#2a1c2e", "accent": "#ffb347", "sun_a": 1.0},
	{"t": 0.78, "star": 0.4, "zenith": "#2a2458", "horizon": "#ff6f61", "glow": "#ff9c5a", "sun": "#ffd0a0", "fog": "#9a4e6e", "ink": "#14102a", "accent": "#ff8fa3", "sun_a": 0.9},
	{"t": 0.9, "star": 1.0, "zenith": "#0a1030", "horizon": "#243066", "glow": "#3a3f7a", "sun": "#e8ecff", "fog": "#243066", "ink": "#06081a", "accent": "#9fe0ff", "sun_a": 0.0},
]
const COLOR_NAMES: Array[String] = ["zenith", "horizon", "glow", "sun", "fog", "ink", "accent"]

static func sample(t: float) -> Dictionary:
	var tt := fposmod(t, 1.0)
	var a: Dictionary = KEYS[KEYS.size() - 1]
	var b: Dictionary = KEYS[0]
	var k := 0.0
	for i in KEYS.size():
		var lo: Dictionary = KEYS[i]
		var hi: Dictionary = KEYS[(i + 1) % KEYS.size()]
		var t0: float = lo["t"]
		var t1: float = hi["t"] if i + 1 < KEYS.size() else 1.0
		if tt >= t0 and tt < t1:
			a = lo
			b = hi
			k = (tt - t0) / maxf(t1 - t0, 0.0001)
			break
	var out := {}
	for n in COLOR_NAMES:
		out[n] = Color(a[n]).lerp(Color(b[n]), k)
	out["sun_a"] = lerpf(a["sun_a"], b["sun_a"], k)
	out["star"] = lerpf(a["star"], b["star"], k)
	return out
