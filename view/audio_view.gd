extends Node

const S := preload("res://game/snap.gd")
const PX := 24.0
const MASTER_DB := -0.915
const SFX_BUS_DB := -6.94
const OFF := -80.0
const NEAR_DB := -33.0
const MID_DB := -8.0

const SCENE_MUSIC := {"dawn": "chasing-daylight", "bloom": "meanwhile"}
const MUSIC_FADE := 6.0

const EDGES := [0.12, 0.32, 0.62, 0.7]
const WEIGHTS := {
	"robin": [1.0, 0.6, 0.6, 1.0, 0.3], "blackbird": [1.0, 0.3, 0.4, 1.0, 0.0], "songthrush": [1.0, 0.3, 0.6, 0.7, 0.0],
	"wren": [0.8, 1.0, 0.6, 0.8, 1.0], "goldcrest": [0.6, 0.6, 0.4, 0.4, 0.3], "greattit": [0.7, 0.8, 0.5, 0.6, 0.3],
	"firecrest": [0.4, 0.6, 0.3, 0.3, 0.3], "chiffchaff": [0.3, 0.8, 0.4, 0.5, 0.4], "blackcap": [0.3, 0.8, 0.4, 0.8, 0.8],
	"chaffinch": [0.5, 1.0, 0.6, 0.8, 1.0],
}
const DENSITY := [1.0, 0.7, 0.6, 0.8, 0.25]
const MAX_VOICES := 3

var amb_json: Dictionary
var scenes: Array = []
var sfx: Dictionary = {}
var beds: Dictionary = {}
var bed_db: Dictionary = {}
var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var music_scene := ""
var music_fade := 1.0
var thunder: AudioStreamPlayer
var thunder_at := -1.0
var bolt_seed := -1
var wall := 0.0
var rng := RandomNumberGenerator.new()

var birds: Dictionary = {}
var voices: Array = []
var band_free_at := {"low": 0.0, "mid": 0.0, "high": 0.0}
var pigeon_next := 30.0

var prev_hook := 0
var prev_y := 0.0
var prev_len := 0.0
var cam: Camera2D
var pending: Array = []

func setup(course: Dictionary, camera: Camera2D) -> void:
	scenes = course.get("scenes", [])
	cam = camera
	rng.randomize()
	amb_json = JSON.parse_string(FileAccess.get_file_as_string("res://audio/amb/ambience.json"))
	_buses()
	_load_sfx()
	for id: String in amb_json["beds"]:
		var b: Dictionary = amb_json["beds"][id]
		var p := AudioStreamPlayer.new()
		var st: AudioStreamOggVorbis = load("res://audio/amb/" + String(b["file"]))
		st.loop = true
		p.stream = st
		p.bus = &"Ambience"
		p.volume_db = OFF
		add_child(p)
		p.play(rng.randf() * float(b["len"]))
		beds[id] = p
		bed_db[id] = OFF
	music_a = _music_player()
	music_b = _music_player()
	thunder = AudioStreamPlayer.new()
	thunder.bus = &"Thunder"
	add_child(thunder)
	for sp: String in WEIGHTS:
		birds[sp] = {"next": rng.randf_range(0.5, 8.0) + float(amb_json["birds"][sp]["rank"]) * 1.5, "left": 0, "last": []}

func _music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = &"Music"
	p.volume_db = OFF
	add_child(p)
	return p

func _bus(bus_name: String, send: String, volume_db: float) -> int:
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, send)
	AudioServer.set_bus_volume_db(i, volume_db)
	return i

func _buses() -> void:
	AudioServer.set_bus_volume_db(0, MASTER_DB)
	var m := _bus("Music", "Master", 0.0)
	if AudioServer.get_bus_effect_count(m) == 0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 1400.0
		AudioServer.add_bus_effect(m, lp)
	var a := _bus("Ambience", "Master", 0.0)
	if AudioServer.get_bus_effect_count(a) == 0:
		AudioServer.add_bus_effect(a, AudioEffectLowPassFilter.new())

		var haas := AudioEffectDelay.new()
		haas.dry = 0.0
		haas.tap1_active = true
		haas.tap1_delay_ms = 0.0
		haas.tap1_level_db = 0.0
		haas.tap1_pan = -0.85
		haas.tap2_active = true
		haas.tap2_delay_ms = 15.0
		haas.tap2_level_db = 0.0
		haas.tap2_pan = 0.85
		haas.feedback_active = false
		AudioServer.add_bus_effect(a, haas)

	var b := _bus("Birds", "Master", 0.0)
	if AudioServer.get_bus_effect_count(b) == 0:
		AudioServer.add_bus_effect(b, AudioEffectLowPassFilter.new())
	var t := _bus("Thunder", "Ambience", 0.0)
	if AudioServer.get_bus_effect_count(t) == 0:
		var tl := AudioEffectLowPassFilter.new()
		tl.cutoff_hz = 360.0
		AudioServer.add_bus_effect(t, tl)
	var s := _bus("SFX", "Master", SFX_BUS_DB)
	if AudioServer.get_bus_effect_count(s) == 0:
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.35
		rv.wet = 0.08
		rv.dry = 1.0
		AudioServer.add_bus_effect(s, rv)

const SFX_FILES := {
	"launch": ["hook-launch"], "whump": ["hook-whump"], "zip": ["hook-zip-1", "hook-zip-2"],
	"bite": ["hook-bite-1", "hook-bite-2", "hook-bite-3"], "clasp": ["hook-clasp"], "reel": ["hook-reel-1", "hook-reel-2"],
	"latch": ["hook-latch-1", "hook-latch-2"], "rope": ["hook-rope-1", "hook-rope-2", "hook-rope-3"], "dock": ["hook-dock"],
	"land": ["branch-land-1", "branch-land-2", "branch-land-3", "branch-land-4"], "leaves": ["branch-leaves"],
	"creak": ["branch-creak-1", "branch-creak-2"], "bump": ["branch-bump"], "shake": ["branch-shake-1", "branch-shake-2", "branch-shake-3"],
	"canopy": ["branch-canopy"], "cloth": ["cloth1", "cloth2", "cloth3", "cloth4"],
	"thunder": ["thunder-1", "thunder-2", "thunder-3"],
}

func _load_sfx() -> void:
	for n: String in SFX_FILES:
		var r := AudioStreamRandomizer.new()
		r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
		r.random_pitch = 1.06
		var dir := "amb" if n == "thunder" else "sfx"
		var i := 0
		for f: String in SFX_FILES[n]:
			r.add_stream(i, load("res://audio/%s/%s.ogg" % [dir, f]))
			i += 1
		sfx[n] = r

static func at(dbfs: float, level := -20.0) -> float:
	return dbfs - level + 7.85

func play(n: String, db: float, pitch := 1.0, delay := 0.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = sfx[n]
	p.volume_db = db
	p.pitch_scale = pitch
	p.bus = &"SFX"
	add_child(p)
	p.finished.connect(p.queue_free)
	if delay > 0.0:
		pending.append({"at": wall + delay, "player": p})
	else:
		p.play()

func on_event(kind: String, data: PackedFloat64Array) -> void:
	var speed := data[2] if data.size() > 2 else 0.0
	match kind:
		"shoot":
			play("launch", at(-34))
			play("whump", at(-40))
			play("zip", at(-38))
		"miss":
			play("zip", at(-38))
		"attach":
			var k := 3.0 * clampf(speed / 25.0, 0.0, 1.0)
			play("bite", at(-29) + k)
			play("clasp", at(-39, -22) + k)
		"release":
			play("latch", at(-34))
			play("rope", at(-40) + linear_to_db(1.0 + minf(0.4, speed * 0.015)))
		"bump":
			var kb := -6.0 * (1.0 - clampf(speed / 20.0, 0.0, 1.0))
			play("bump", at(-27) + kb)
			play("shake", at(-44) + kb)
		"pad":
			play("land", at(-28))
			play("leaves", at(-40))
			play("creak", at(-40), 1.0, 0.05)
		"jump":
			play("land", at(-32), 1.05)
			play("cloth", linear_to_db(0.25), 1.1)
		"die":
			play("cloth", linear_to_db(0.5), 0.6)

func update(snap: PackedFloat64Array, mood: Dictionary, delta: float) -> void:
	wall += delta
	var y := snap[S.Y]
	var dead := snap[S.MODE] == S.MODE_DEAD
	var above := clampf((y - 32.0) / 6.0, 0.0, 1.0)
	var rain: float = mood["rain"]
	var overcast: float = mood["overcast"]
	var storm: float = mood["storm"]

	var p := clampf((float(mood["t"]) - 0.22) / 0.42, 0.0, 1.0)

	var f := 1400.0 + above * above * 15000.0
	f *= 1.0 - rain * 0.3
	if dead:
		f = 500.0
	var lp: AudioEffectLowPassFilter = AudioServer.get_bus_effect(AudioServer.get_bus_index(&"Music"), 0)
	lp.cutoff_hz = lerpf(lp.cutoff_hz, f, 1.0 - exp(-delta / (0.25 if above > 0.5 else 0.6)))
	var g := (0.26 + above * 0.1) * (0.7 if dead else 1.0)
	_music(snap[S.X], linear_to_db(g), delta)

	var u := clampf(overcast * 0.4 + rain * 0.2 + storm * 0.6, 0.0, 1.0)
	var aft := smoothstep(0.0, 1.0, (p - 0.7) / 0.05)
	var rain_on := smoothstep(0.0, 1.0, rain / 0.15)
	var rain_k := linear_to_db(maxf(1e-4, 1.0 - 0.4 * above))
	var wind_up := 2.0 * above
	var tgt := {
		"windCalm": -44.0 - 6.0 * u + 2.5 * aft + wind_up,
		"windMid": -51.0 + 7.0 * minf(1.0, u / 0.5) - 3.0 * smoothstep(0.0, 1.0, (u - 0.6) / 0.4) + 3.0 * aft + wind_up,
		"windStrong": OFF if u < 0.55 else -52.0 + 9.0 * smoothstep(0.0, 1.0, (u - 0.55) / 0.45) + wind_up,
		"gustTrees": -45.0 + 3.0 * u + 3.0 * aft + 4.0 * above,
		"gustLeaves": -46.0 + 3.0 * u + 3.0 * aft - 3.0 * above,
		"rainLight": OFF if rain <= 0.0 else -48.0 + 5.0 * smoothstep(0.0, 1.0, rain / 0.5) + linear_to_db(maxf(1e-4, rain_on)) + rain_k,
		"rainUnder": OFF if rain <= 0.3 else -55.0 + 14.0 * smoothstep(0.0, 1.0, (rain - 0.3) / 0.6) + rain_k,
		"rainHeavy": OFF if storm <= 0.0 else -60.0 + 21.5 * storm + rain_k,
		"birdsFar": OFF, "dawn": OFF, "afterRain": OFF,
	}
	var far_on := 1.0 - smoothstep(0.0, 1.0, rain / 0.3)
	if far_on > 0.01:
		tgt["birdsFar"] = -45.5 - 3.0 * (1.0 - smoothstep(0.0, 1.0, (p - 0.1) / 0.06)) - 3.0 * overcast - 2.0 * aft + 3.0 * above + linear_to_db(far_on)
	if p < 0.24:
		tgt["dawn"] = -45.0 - 7.0 * (p / 0.2) if p < 0.2 else -52.0 + linear_to_db(maxf(1e-4, 1.0 - smoothstep(0.0, 1.0, (p - 0.2) / 0.04)))
	if p > 0.6 and p < 0.8:
		var k := smoothstep(0.0, 1.0, (p - 0.62) / 0.04) * (1.0 - smoothstep(0.0, 1.0, (rain - 0.2) / 0.3)) * (1.0 - smoothstep(0.0, 1.0, (p - 0.7) / 0.1))
		if k > 0.001:
			tgt["afterRain"] = -44.0 + linear_to_db(k)
	var gust: float = mood["gust"]
	for id: String in beds:
		var target: float = tgt.get(id, OFF)
		var db := OFF if target <= OFF + 1.0 else target - float(amb_json["beds"][id]["lufs"])
		if id == "gustTrees" or id == "gustLeaves":
			db += linear_to_db(maxf(gust, 1e-4))
		var rate := 0.08 if id.begins_with("gust") else 0.8
		var cur: float = bed_db[id]

		var lin := lerpf(db_to_linear(cur), db_to_linear(db), 1.0 - exp(-delta / rate))
		bed_db[id] = linear_to_db(maxf(lin, 1e-5))
		(beds[id] as AudioStreamPlayer).volume_db = bed_db[id]
	var amb_lp: AudioEffectLowPassFilter = AudioServer.get_bus_effect(AudioServer.get_bus_index(&"Ambience"), 0)
	amb_lp.cutoff_hz = lerpf(amb_lp.cutoff_hz, 500.0 if dead else 20000.0, 1.0 - exp(-delta / 0.5))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Ambience"), linear_to_db(0.5) if dead else 0.0)

	var b_lp: AudioEffectLowPassFilter = AudioServer.get_bus_effect(AudioServer.get_bus_index(&"Birds"), 0)
	b_lp.cutoff_hz = 20000.0 - 16000.0 * smoothstep(0.0, 1.0, above)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Birds"), -6.0 * above)

	for i in range(pending.size() - 1, -1, -1):
		if wall >= float(pending[i]["at"]):
			(pending[i]["player"] as AudioStreamPlayer).play()
			pending.remove_at(i)
	_birds(p, rain, overcast, storm, dead)
	_thunder(mood)
	_self_detected(snap)

func _music(x: float, db: float, delta: float) -> void:
	var sid := "dawn"
	for s: Dictionary in scenes:
		if x >= float(s["x0"]):
			sid = s["id"]
	var track: String = SCENE_MUSIC.get(sid, "chasing-daylight")
	if sid != music_scene:
		var cur_track := ""
		if music_a.stream != null:
			cur_track = music_a.stream.resource_path.get_file().get_basename()
		music_scene = sid
		if cur_track != track:

			var tmp := music_b
			music_b = music_a
			music_a = tmp
			var st: AudioStreamOggVorbis = load("res://audio/music/%s.ogg" % track)
			st.loop = true
			music_a.stream = st
			music_a.volume_db = OFF
			music_a.play()
			music_fade = 0.0 if music_b.playing else 1.0
	music_fade = minf(1.0, music_fade + delta / MUSIC_FADE)
	var lin := db_to_linear(db)
	music_a.volume_db = linear_to_db(maxf(lin * music_fade, 1e-5))
	music_b.volume_db = linear_to_db(maxf(lin * (1.0 - music_fade), 1e-5))
	if music_fade >= 1.0 and music_b.playing:
		music_b.stop()

static func _blend(p: float, values: Array) -> float:
	var v: float = values[0]
	for i in EDGES.size():
		v = lerpf(v, float(values[i + 1]), smoothstep(0.0, 1.0, (p - (float(EDGES[i]) - 0.015)) / 0.03))
	return v

func _birds(p: float, rain: float, overcast: float, storm: float, dead: bool) -> void:
	for i in range(voices.size() - 1, -1, -1):
		var v: Dictionary = voices[i]
		if wall >= float(v["end"]):
			(v["player"] as Node).queue_free()
			voices.remove_at(i)
	if dead or cam == null:
		return
	var heavy := rain > 0.55 or storm > 0.2
	var weather := (1.0 - 0.5 * overcast) * (1.0 - smoothstep(0.0, 1.0, (rain - 0.3) / 0.4))
	var density := _blend(p, DENSITY) * weather
	for sp: String in birds:
		var st: Dictionary = birds[sp]
		var w := (1.0 if sp == "songthrush" else 0.0) if heavy else _blend(p, WEIGHTS[sp])
		if w <= 0.01 or wall < float(st["next"]):
			continue
		var info: Dictionary = amb_json["birds"][sp]
		var band: String = info["band"]
		if voices.size() >= MAX_VOICES or wall < float(band_free_at[band]):
			st["next"] = wall + rng.randf_range(0.2, 1.0)
			continue
		if int(st["left"]) <= 0:

			if rng.randf() > w:
				st["next"] = wall + rng.randf_range(10.0, 30.0)
				continue
			st["left"] = 1 if heavy else rng.randi_range(3, 8)
			st["x"] = cam.get_screen_center_position().x + rng.randf_range(-200.0, 900.0)
			st["mid"] = rng.randf() < 0.4
		var clips: Array = info["clips"]
		var last: Array = st["last"]
		var pick := rng.randi() % clips.size()
		for t in 4:
			if not last.has(pick):
				break
			pick = rng.randi() % clips.size()
		last.append(pick)
		if last.size() > 3:
			last.pop_front()
		var clip: Dictionary = clips[pick]
		var pl := AudioStreamPlayer2D.new()
		pl.stream = load("res://audio/amb/" + String(info["file"]))
		pl.bus = &"Birds"
		pl.position = Vector2(float(st["x"]), cam.get_screen_center_position().y - 200.0)
		pl.pitch_scale = pow(2.0, rng.randf_range(-50.0, 50.0) / 1200.0)
		pl.volume_db = NEAR_DB - float(clip["lvl"]) + 7.85 - rng.randf_range(0.0, 4.0) + (MID_DB if st["mid"] else 0.0) + (-6.0 if heavy else 0.0)
		pl.max_distance = 3000.0
		pl.attenuation = 1.2
		add_child(pl)
		pl.play(float(clip["off"]))
		var dur := float(clip["dur"]) / pl.pitch_scale
		voices.append({"player": pl, "end": wall + dur})
		band_free_at[band] = wall + dur + rng.randf_range(0.2, 1.0)
		st["left"] = int(st["left"]) - 1
		var gap := float(info["gap"]) * rng.randf_range(0.75, 1.25)
		if heavy:
			st["next"] = wall + rng.randf_range(45.0, 90.0)
		elif int(st["left"]) > 0:
			st["next"] = wall + maxf(gap, dur + 0.3)
		else:
			st["next"] = wall + rng.randf_range(30.0, 90.0) / maxf(density, 0.05)

	if wall >= pigeon_next:
		pigeon_next = wall + rng.randf_range(60.0, 180.0) / maxf(density, 0.1)
		if rain < 0.3:
			var pg: Dictionary = amb_json["far"]["pigeon"]
			var pp := AudioStreamPlayer.new()
			pp.stream = load("res://audio/amb/" + String(pg["file"]))
			pp.bus = &"Birds"
			pp.volume_db = -47.0 - float(pg["level"])
			add_child(pp)
			pp.finished.connect(pp.queue_free)
			pp.play()

func _thunder(mood: Dictionary) -> void:
	var seed_now: int = mood["bolt_seed"]
	if float(mood["flash"]) > 0.6 and seed_now != bolt_seed:
		bolt_seed = seed_now
		thunder_at = wall + rng.randf_range(2.6, 4.2)
	if thunder_at > 0.0 and wall >= thunder_at:
		thunder_at = -1.0
		thunder.stream = sfx["thunder"]
		thunder.pitch_scale = rng.randf_range(0.82, 0.92)
		thunder.volume_db = OFF
		thunder.play()
		create_tween().tween_property(thunder, "volume_db", linear_to_db(0.22), 0.6)

func _self_detected(snap: PackedFloat64Array) -> void:
	var hook := int(snap[S.HOOK])
	var l := snap[11]

	if prev_hook == S.HOOK_RETRACT and hook == S.HOOK_IDLE:
		play("dock", at(-40, -24))
	var y := snap[S.Y]
	if prev_y < 36.0 and y >= 36.0 and snap[S.VY] > 0.0:
		play("canopy", at(-36))
	prev_hook = hook
	prev_len = l
	prev_y = y
