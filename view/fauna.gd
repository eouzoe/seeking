extends Node2D

const PX := 24.0

var look: Resource
var bird_frames: SpriteFrames
var fly_frames: SpriteFrames
var bird_layer: CanvasLayer
var flocks: Array = []
var next_flock := 6.0
var butterflies: Array = []
var mists: Array[Sprite2D] = []
var mist_tex: Texture2D
var rng := RandomNumberGenerator.new()

func build(lk: Resource) -> void:
	look = lk
	rng.seed = 2026
	bird_frames = _frames(["res://art/elements/bird_0.png", "res://art/elements/bird_1.png", "res://art/elements/bird_2.png", "res://art/elements/bird_1.png"], 9.0)
	fly_frames = _frames(["res://art/elements/butterfly_0.png", "res://art/elements/butterfly_1.png"], 11.0)
	bird_layer = CanvasLayer.new()
	bird_layer.layer = -5
	add_child(bird_layer)

	mist_tex = load("res://art/elements/mist_band.png") as Texture2D if ResourceLoader.exists("res://art/elements/mist_band.png") else null
	if mist_tex != null:
		for z in [-3, 9]:
			var m := Sprite2D.new()
			m.texture = mist_tex
			m.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			m.region_enabled = true
			m.region_rect = Rect2(0, 0, mist_tex.get_width() * 4, mist_tex.get_height())
			m.z_index = z
			m.light_mask = 0
			add_child(m)
			mists.append(m)

func _frames(paths: Array, fps: float) -> SpriteFrames:
	for p: String in paths:
		if not ResourceLoader.exists(p):
			return null
	var f := SpriteFrames.new()
	f.set_animation_speed(&"default", fps)
	for p: String in paths:
		f.add_frame(&"default", load(p))
	return f

func update(kit: Dictionary, cam_px: Vector2, view: Vector2, vp: Vector2, wind: Vector2, fog: Color, delta: float) -> void:
	_update_birds(kit, vp, fog, delta)
	_update_butterflies(kit, cam_px, view, delta)
	for i in mists.size():
		var m := mists[i]
		var front := i == 1
		var t := Time.get_ticks_msec() / 1000.0

		m.position = Vector2(cam_px.x, -(6.0 if not front else 3.0) * PX)
		var w := m.region_rect.size.x
		m.region_rect.position.x = fmod(t * (8.0 + wind.x * 60.0) * (1.6 if front else 1.0), float(mist_tex.get_width()))
		m.scale = Vector2.ONE * (view.x / w * 1.2) * Vector2(1.0, 2.2 if not front else 1.6)
		var c: Color = kit["mist_color"]
		m.modulate = Color(c.r, c.g, c.b, float(kit["mist"]) * (0.55 if not front else 0.18))

func _update_birds(kit: Dictionary, vp: Vector2, fog: Color, delta: float) -> void:
	if bird_frames == null:
		return
	var rate: float = kit["birds"]
	next_flock -= delta * rate
	if next_flock <= 0.0 and rate > 0.05:
		next_flock = rng.randf_range(14.0, 30.0)

		var n := rng.randi_range(3, 6)
		var base := Vector2(-60.0, rng.randf_range(0.12, 0.35) * vp.y)
		var v := Vector2(rng.randf_range(60.0, 95.0), rng.randf_range(-6.0, 4.0))
		var nodes: Array = []
		for i in n:
			var b := AnimatedSprite2D.new()
			b.sprite_frames = bird_frames
			b.play()
			b.frame = rng.randi_range(0, 3)
			b.speed_scale = rng.randf_range(0.85, 1.2)
			var s := rng.randf_range(0.16, 0.24)
			b.scale = Vector2(s, s)
			b.position = base + Vector2(-float(i) * rng.randf_range(16.0, 30.0), float(i % 2) * rng.randf_range(6.0, 14.0) + rng.randf_range(-4.0, 4.0))
			bird_layer.add_child(b)
			nodes.append(b)
		flocks.append({"nodes": nodes, "v": v})
	for f: Dictionary in flocks.duplicate():
		var alive := false
		for b: AnimatedSprite2D in f["nodes"]:
			b.position += Vector2(f["v"]) * delta + Vector2(0, sin(Time.get_ticks_msec() / 400.0 + b.position.x * 0.05) * 0.15)
			b.modulate = fog.darkened(0.45)
			if b.position.x < vp.x + 80.0:
				alive = true
		if not alive:
			for b: AnimatedSprite2D in f["nodes"]:
				b.queue_free()
			flocks.erase(f)

func _update_butterflies(kit: Dictionary, cam_px: Vector2, view: Vector2, delta: float) -> void:
	if fly_frames == null:
		return
	var want := int(round(float(kit["butterflies"]) * 3.0))
	while butterflies.size() < want:
		var b := AnimatedSprite2D.new()
		b.sprite_frames = fly_frames
		b.play()
		b.scale = Vector2.ONE * 0.32
		b.z_index = 5
		b.modulate = Color(1.0, 0.95, 0.85)
		add_child(b)
		var home := cam_px + Vector2(rng.randf_range(0.1, 0.45) * view.x, rng.randf_range(-0.05, 0.25) * view.y)
		b.position = home
		butterflies.append({"node": b, "home": home, "ph": rng.randf() * TAU})
	while butterflies.size() > want:
		var d: Dictionary = butterflies.pop_back()
		(d["node"] as Node).queue_free()
	var t := Time.get_ticks_msec() / 1000.0
	for d: Dictionary in butterflies:
		var b: AnimatedSprite2D = d["node"]
		var home: Vector2 = d["home"]

		if home.x < cam_px.x - view.x * 0.6:
			home = cam_px + Vector2(view.x * rng.randf_range(0.3, 0.55), rng.randf_range(-0.05, 0.25) * view.y)
			d["home"] = home
		var ph: float = d["ph"]
		var target := home + Vector2(sin(t * 0.7 + ph) * 60.0, sin(t * 1.9 + ph * 2.0) * 22.0 + sin(t * 4.3 + ph) * 6.0)
		var prev := b.position
		b.position = b.position.lerp(target, 1.0 - exp(-delta * 2.0))
		b.flip_h = b.position.x < prev.x
