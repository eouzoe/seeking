extends RefCounted

const CALM := {"slot": 27.5, "jitter": 3.75, "attack": Vector2(1, 2), "hold": Vector2(3, 8), "release": Vector2(4, 8), "ch": 1}
const STORM := {"slot": 11.5, "jitter": 1.75, "attack": Vector2(0.8, 1.5), "hold": Vector2(2, 5), "release": Vector2(3, 6), "ch": 2}
const BOLT_CYCLE := 4.7

const BLEND := 80.0

var length := 1.0
var seed_v := 0
var scenes: Array = []

func _init(course_length: float, course_seed: int, scene_list: Array = []) -> void:
	length = maxf(course_length, 1.0)
	seed_v = course_seed
	scenes = scene_list

func _scene_val(key: String, x: float) -> float:
	var i := 0
	for k in scenes.size():
		if x >= float(scenes[k]["x0"]):
			i = k
	var s: Dictionary = scenes[i]
	var ab: Array = s[key]
	var u := clampf((x - float(s["x0"])) / maxf(float(s["x1"]) - float(s["x0"]), 1.0), 0.0, 1.0)
	var v := lerpf(float(ab[0]), float(ab[1]), u)
	if i > 0:
		var prev_end := float(scenes[i - 1][key][1])
		var w := smoothstep(-BLEND, BLEND, x - float(s["x0"]))
		v = lerpf(prev_end, v, w)
	return v

static func _ramp(p: float, a: float, b: float) -> float:
	return smoothstep(0.0, 1.0, (p - a) / (b - a))

func mood(x: float, wall: float) -> Dictionary:
	var p := clampf(x / length, 0.0, 1.0)
	var t := 0.22 + 0.42 * p
	var overcast := _ramp(p, 0.3, 0.4) * (1.0 - _ramp(p, 0.62, 0.72))
	var rain := _ramp(p, 0.38, 0.44) * (1.0 - _ramp(p, 0.61, 0.67))
	var storm := _ramp(p, 0.46, 0.5) * (1.0 - _ramp(p, 0.58, 0.62))
	var clearing := _ramp(p, 0.63, 0.67) * (1.0 - _ramp(p, 0.76, 0.84))
	var rainbow := _ramp(p, 0.7, 0.76) * (1.0 - _ramp(p, 0.93, 0.98))
	var base_wind := 0.08
	if not scenes.is_empty():
		t = _scene_val("time", x)
		overcast = _scene_val("overcast", x)
		rain = _scene_val("rain", x)
		storm = _scene_val("storm", x)
		clearing = _scene_val("clearing", x)
		rainbow = _scene_val("rainbow", x)
		base_wind = _scene_val("wind", x)
	var flash := 0.0
	var cyc := fmod(wall, BOLT_CYCLE)
	if storm > 0.2:
		if cyc < 0.12:
			flash = (1.0 - cyc / 0.12) * storm
		elif cyc > 0.25 and cyc < 0.32:
			flash = 0.5 * storm
	var wind_need := minf(1.0, overcast * 0.9 + storm)
	var gust := gust_at(wall, storm, wind_need)
	var wind := base_wind + overcast * 0.17 + rain * 0.07 + storm * 0.13 + gust * (0.05 + overcast * 0.1 + rain * 0.08 + storm * 0.22)
	return {
		"p": p, "t": t, "overcast": overcast, "rain": rain, "storm": storm, "clearing": clearing,
		"rainbow": rainbow, "flash": flash, "bolt_seed": int(floor(wall / BOLT_CYCLE)), "wind": wind, "gust": gust,
	}

func gust_at(t: float, storm: float, need: float) -> float:
	var calm := _train(t, CALM) * clampf(need, 0.0, 1.0)
	return maxf(calm, clampf(storm, 0.0, 1.0) * _train(t, STORM)) if storm > 0.0 else calm

func _hash01(k: int, i: int) -> float:
	var h := hash([seed_v, k, i])
	return float(h & 0xffffff) / float(0xffffff)

func _train(t: float, tr: Dictionary) -> float:
	var slot: float = tr["slot"]
	var k0 := int(floor(t / slot))
	var v := 0.0
	var ch: int = tr["ch"]
	for k in range(k0 - 1, k0 + 1):
		var start := float(k) * slot + slot * 0.5 + (_hash01(k, ch * 16) * 2.0 - 1.0) * float(tr["jitter"])
		var at: Vector2 = tr["attack"]
		var ht: Vector2 = tr["hold"]
		var rt: Vector2 = tr["release"]
		var a := lerpf(at.x, at.y, _hash01(k, ch * 16 + 1))
		var hd := lerpf(ht.x, ht.y, _hash01(k, ch * 16 + 2))
		var r := lerpf(rt.x, rt.y, _hash01(k, ch * 16 + 3))
		var amp := 0.55 + 0.45 * _hash01(k, ch * 16 + 4)
		var u := t - start
		var e := 0.0
		if u > 0.0 and u < a:
			e = smoothstep(0.0, 1.0, u / a)
		elif u >= a and u < a + hd:
			e = 1.0
		elif u >= a + hd and u < a + hd + r:
			e = 1.0 - smoothstep(0.0, 1.0, (u - a - hd) / r)
		v = maxf(v, e * amp)
	return v
