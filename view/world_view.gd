extends Node2D

const PX := 24.0
const CLOUD_SEA_Y := 0.0
const SWAY := preload("res://view/shaders/sway.gdshader")
const Kits := preload("res://look/kits.gd")
var TRUNK_TINT := Color(0.42, 0.38, 0.4)
var look: Resource
var sway_near: ShaderMaterial
var sway_far: ShaderMaterial
var tip_springs: Dictionary = {}
var dapples: Array[PointLight2D] = []
var leaf_burst: CPUParticles2D
const FAR_LAYERS: Array[Dictionary] = [
	{"par": 0.08, "base": 15.0, "amp": 16.0, "freq": 0.012, "depth": 0.0, "seed": 101},
	{"par": 0.16, "base": 13.0, "amp": 11.0, "freq": 0.02, "depth": 0.22, "seed": 102},
	{"par": 0.3, "base": 10.0, "amp": 7.0, "freq": 0.035, "depth": 0.5, "seed": 103},
	{"par": 0.5, "base": 7.0, "amp": 5.0, "freq": 0.05, "depth": 0.75, "seed": 104},
]

var course: Dictionary
var anchor_tips: Array[Node2D] = []
var lanterns: Array[PointLight2D] = []
var lantern_bodies: Array[Node2D] = []
var far_polys: Array[Node2D] = []
var far_depths: Array[float] = []
var bark_tex: CanvasTexture
var leaf_tex: CanvasTexture
var leaves: Array[CanvasTexture] = []
var far_trees: Array[Texture2D] = []
var rock_tex: CanvasTexture

static func w2s(x: float, y: float) -> Vector2:
	return Vector2(x * PX, -y * PX)

func build(c: Dictionary, lk: Resource) -> void:
	course = c
	look = lk
	TRUNK_TINT = lk.trunk_tint
	sway_near = ShaderMaterial.new()
	sway_near.shader = SWAY
	sway_far = ShaderMaterial.new()
	sway_far.shader = SWAY
	sway_far.set_shader_parameter(&"amount", 0.35)
	bark_tex = _load_tex("bark")
	rock_tex = _load_tex("rock")
	for n in ["leaf_a", "leaf_b", "leaf_c", "leaf_d"]:
		leaves.append(_load_tex(n))
	leaf_tex = leaves[0]
	for n in ["far_a", "far_b"]:
		far_trees.append(load("res://art/scene/%s.png" % n))
	_build_far_layers()
	var trunks: Array = c["trunks"]
	for i in trunks.size():
		_build_trunk(trunks[i])
	for a: Dictionary in c["anchors"]:
		_build_anchor(a, trunks[int(a["trunk"])])
	for p: Dictionary in c["pads"]:
		if float(p["w"]) > 0.0:
			_build_pad(p, trunks[int(p["trunk"])])
	for r: Dictionary in c["rocks"]:
		_build_rock(r)
	_build_fx()

func _opt_tex(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

func _load_tex(n: String) -> CanvasTexture:
	var ct := CanvasTexture.new()
	ct.diffuse_texture = load("res://art/scene/%s.png" % n)
	ct.normal_texture = load("res://art/scene/%s_n.png" % n)
	ct.specular_color = Color(0.05, 0.05, 0.05)
	ct.specular_shininess = 0.5
	ct.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	return ct

func _leaf_sprite(c: Vector2, w_px: float, tint: Color, rng: RandomNumberGenerator, parent: Node) -> Sprite2D:
	var t: CanvasTexture = leaves[rng.randi() % leaves.size()]
	var s := Sprite2D.new()
	s.texture = t
	var k := w_px / float(t.diffuse_texture.get_width())
	s.scale = Vector2(k * (1.0 if rng.randf() < 0.5 else -1.0), k)
	s.rotation = rng.randf_range(-0.25, 0.25)
	s.position = c
	s.modulate = tint
	parent.add_child(s)
	return s

func _make_tex(kind: int, freq: float, dark: Color, light: Color, bump: float, size: Vector2i) -> CanvasTexture:
	var n := FastNoiseLite.new()
	n.noise_type = kind as FastNoiseLite.NoiseType
	n.frequency = freq
	n.fractal_octaves = 4
	var ramp := Gradient.new()
	ramp.set_color(0, dark)
	ramp.set_color(1, light)
	var diffuse := NoiseTexture2D.new()
	diffuse.width = size.x
	diffuse.height = size.y
	diffuse.seamless = true
	diffuse.noise = n
	diffuse.color_ramp = ramp
	var normal := NoiseTexture2D.new()
	normal.width = size.x
	normal.height = size.y
	normal.seamless = true
	normal.noise = n
	normal.as_normal_map = true
	normal.bump_strength = bump
	var ct := CanvasTexture.new()
	ct.diffuse_texture = diffuse
	ct.normal_texture = normal
	ct.specular_color = Color(0.06, 0.06, 0.06)
	ct.specular_shininess = 0.6
	ct.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	return ct

func _poly(points: PackedVector2Array, tex: CanvasTexture, tint: Color, parent: Node = self) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.texture = tex
	p.color = tint
	p.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	parent.add_child(p)
	return p

func _occluder(points: PackedVector2Array, parent: Node = self) -> void:
	var o := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	poly.polygon = points
	poly.cull_mode = OccluderPolygon2D.CULL_DISABLED
	o.occluder = poly
	parent.add_child(o)

func _ellipse(center: Vector2, r: Vector2, n: int, wobble: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		var k := 1.0 + rng.randf_range(-wobble, wobble)
		pts.append(center + Vector2(cos(a) * r.x, sin(a) * r.y) * k)
	return pts

func _build_far_layers() -> void:
	var length: float = course["length"]
	for L in FAR_LAYERS:
		var par: float = L["par"]
		var px := Parallax2D.new()
		px.scroll_scale = Vector2(par, 1.0)
		px.z_index = -50 + int(float(L["depth"]) * 10.0)
		add_child(px)
		var n := FastNoiseLite.new()
		n.seed = int(L["seed"])
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX
		n.frequency = float(L["freq"])
		n.fractal_type = FastNoiseLite.FRACTAL_RIDGED
		n.fractal_octaves = 4
		var x0 := -80.0
		var x1 := length * par + 120.0
		var pts := PackedVector2Array()
		pts.append(w2s(x0, -20.0))
		var x := x0
		while x <= x1:
			var h := float(L["base"]) + (n.get_noise_1d(x) * 0.5 + 0.5) * float(L["amp"])
			pts.append(w2s(x, h))
			x += 1.5
		pts.append(w2s(x1, -20.0))
		var p := Polygon2D.new()
		p.polygon = pts
		p.light_mask = 0
		px.add_child(p)
		far_polys.append(p)
		far_depths.append(float(L["depth"]))
	_build_tree_layer(0.62, 0.4, 201, 9.0, 0.55)
	_build_tree_layer(0.8, 0.55, 202, 7.5, 0.75)
	_build_foreground(1.35, 301)

func _build_tree_layer(par: float, depth: float, seed_v: int, spacing: float, scale_k: float) -> void:
	var length: float = course["length"]
	var px := Parallax2D.new()
	px.scroll_scale = Vector2(par, 1.0)
	px.z_index = -40 + int(depth * 10.0)
	add_child(px)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var poly_pts := PackedVector2Array()
	var x := -60.0
	var x1 := length * par + 120.0
	var holder := Node2D.new()
	holder.material = sway_far
	px.add_child(holder)
	while x < x1:
		var top := rng.randf_range(20.0, 30.0) * scale_k + 6.0
		var tex: Texture2D = far_trees[rng.randi() % far_trees.size()]
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		var h_px := (top + 8.0) * PX * 0.7
		var k := h_px / float(tex.get_height())
		s.scale = Vector2(k * (1.0 if rng.randf() < 0.5 else -1.0), k)
		s.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())
		s.position = w2s(x, -8.0)
		s.light_mask = 0
		s.use_parent_material = true
		holder.add_child(s)
		x += spacing * rng.randf_range(0.7, 1.4)
	far_polys.append(holder)
	far_depths.append(depth)

func _build_foreground(par: float, seed_v: int) -> void:
	var length: float = course["length"]
	var px := Parallax2D.new()
	px.scroll_scale = Vector2(par, 1.0)
	px.z_index = 20
	add_child(px)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var x := -40.0
	while x < length * par + 80.0:
		var c := _ellipse(w2s(x, rng.randf_range(34.0, 39.0)), Vector2(rng.randf_range(5.0, 9.0), rng.randf_range(3.0, 4.5)) * PX, 18, 0.2, rng)
		var fg := _leaf_sprite(c[0].lerp(c[c.size() / 2], 0.5), rng.randf_range(10.0, 16.0) * PX, Color(0.1, 0.11, 0.13), rng, px)
		fg.light_mask = 0
		x += rng.randf_range(14.0, 30.0)

func update_far(pal: Dictionary, overcast: float) -> void:
	for i in far_polys.size():
		var d: float = far_depths[i]
		var fog: Color = pal["fog"]
		var ink: Color = pal["ink"]
		var hor: Color = pal["horizon"]
		var c := hor.lerp(fog, 0.35 + d * 0.4).lerp(ink, 0.12 + d * 0.6)
		c = c.lerp(Color(0.62, 0.64, 0.7), overcast * 0.4)
		far_polys[i].modulate = c

func _build_trunk(t: Dictionary) -> void:
	var x: float = t["x"]
	var w: float = t["w"]
	var top: float = t["top"]
	var solid: bool = t["solid"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(x * 131.0 + top * 7.0)
	var root := Node2D.new()
	root.z_index = 0 if solid else -2
	add_child(root)
	var bot := -12.0
	var pts := PackedVector2Array([w2s(x - w * 0.75, bot), w2s(x - w * 0.5, top), w2s(x + w * 0.5, top), w2s(x + w * 0.75, bot)])
	if solid:
		pts = PackedVector2Array([w2s(x - w * 0.75, bot), w2s(x - w * 0.55, top - 0.6), w2s(x - w * 0.15, top), w2s(x + w * 0.1, top - 0.9), w2s(x + w * 0.4, top + 0.2), w2s(x + w * 0.6, top - 0.5), w2s(x + w * 0.75, bot)])
		var p := _poly(pts, bark_tex, TRUNK_TINT * Color(0.9, 0.9, 0.95), root)
		p.texture_scale = Vector2(1.5, 1.5)
		_occluder(pts, root)
		return
	var kit := Kits.at(course.get("scenes", []), x)
	_poly(pts, bark_tex, kit["bark_tint"], root)
	var span: float = t["span"]
	if span <= 0.0:
		return
	var crown := Node2D.new()
	crown.z_index = 2
	root.add_child(crown)
	var blobs := 5 + int(span * 0.3)
	var bloom_tex: Texture2D = _opt_tex("res://art/elements/bloom_%s.png" % ("a" if rng.randf() < 0.5 else "b"))
	for i in blobs:
		var fx := rng.randf_range(-1.0, 1.0)
		var cx := x + fx * span * 0.75
		var cy := top - 1.5 + rng.randf_range(-2.0, 2.5) - absf(fx) * 2.0
		var r := Vector2(rng.randf_range(3.0, 5.0), rng.randf_range(2.2, 3.4)) * PX
		var shade := rng.randf_range(0.75, 1.0)
		var blob := _leaf_sprite(w2s(cx, cy), r.x * 2.3, Color(kit["leaf_tint"]) * Color(shade, shade, shade), rng, crown)
		blob.material = sway_near
		if bloom_tex != null and rng.randf() < float(kit["bloom"]):
			var b := Sprite2D.new()
			b.texture = bloom_tex
			var k := r.x * 1.3 / float(bloom_tex.get_width())
			b.scale = Vector2(k * (1.0 if rng.randf() < 0.5 else -1.0), k)
			b.position = w2s(cx, cy) + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.5, 0.0)) * r
			b.modulate = kit["bloom_tint"]
			b.material = sway_near
			crown.add_child(b)
	var dap: Texture2D = _opt_tex("res://art/elements/dapple.png")
	if dap != null and rng.randf() < float(kit["dapple"]):
		var l := PointLight2D.new()
		l.texture = dap
		l.texture_scale = span * PX * 1.6 / float(dap.get_width())
		l.height = 80.0
		l.energy = 0.35 + 0.25 * float(kit["dapple"])
		l.color = Color(1.0, 0.94, 0.8)
		l.position = w2s(x, top - 12.0)
		root.add_child(l)
		dapples.append(l)

func _build_anchor(a: Dictionary, t: Dictionary) -> void:
	var ax: float = a["x"]
	var ay: float = a["y"]
	var tip := Node2D.new()
	tip.position = w2s(ax, ay)
	tip.z_index = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ax * 97.0 + ay * 13.0)
	if a["on"] == "vine":
		var top: float = t["top"]
		var vine := Line2D.new()
		vine.points = PackedVector2Array([w2s(ax, top - 2.0) - tip.position, Vector2.ZERO])
		vine.width = 0.22 * PX
		vine.default_color = Color(0.35, 0.42, 0.25)

		tip.add_child(vine)
	else:
		var tx: float = t["x"]
		var side := signf(ax - tx) if absf(ax - tx) > 0.01 else 1.0
		var base_y := ay - 1.2
		var pts := PackedVector2Array([w2s(tx, base_y - 0.45) - tip.position, w2s(tx, base_y + 0.45) - tip.position, Vector2(0, -0.12 * PX), Vector2(0, 0.12 * PX)])
		var b := _poly(pts, bark_tex, TRUNK_TINT, tip)
		b.texture_scale = Vector2(2, 2)
		var _unused := side
	var tuft := _leaf_sprite(Vector2.ZERO, 2.8 * PX, Color(Kits.at(course.get("scenes", []), ax)["leaf_tint"]) * 1.1, rng, tip)
	tuft.z_index = 1
	tuft.material = sway_near
	add_child(tip)
	anchor_tips.append(tip)

func _build_pad(p: Dictionary, t: Dictionary) -> void:
	var px: float = p["x"]
	var py: float = p["y"]
	var w: float = p["w"]
	var tx: float = t["x"]
	var x0 := minf(tx, px - w * 0.5)
	var x1 := maxf(tx, px + w * 0.5)
	var pts := PackedVector2Array([w2s(x0, py), w2s(x1, py + 0.15), w2s(x1, py - 0.5), w2s(x0, py - 0.75)])
	var b := _poly(pts, bark_tex, TRUNK_TINT * Color(1.1, 1.1, 1.1))
	b.z_index = 1
	_occluder(pts)
	var lx := x1 - 0.6 if absf(x1 - tx) > absf(x0 - tx) else x0 + 0.6
	var lamp := Node2D.new()
	lamp.position = w2s(lx, py - 1.6)
	lamp.z_index = 3
	add_child(lamp)
	var cord := Line2D.new()
	cord.points = PackedVector2Array([Vector2(0, -1.0 * PX), Vector2.ZERO])
	cord.width = 2.0
	cord.default_color = Color(0.15, 0.12, 0.1)
	lamp.add_child(cord)
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-6, -8), Vector2(6, -8), Vector2(8, 4), Vector2(0, 12), Vector2(-8, 4)])
	body.color = Color(1.6, 1.15, 0.6)
	body.light_mask = 0
	lamp.add_child(body)
	var light := PointLight2D.new()
	light.texture = _radial_tex()
	light.texture_scale = 7.0
	light.height = 70.0
	light.color = look.lantern_color
	light.energy = look.lantern_energy.x
	light.shadow_enabled = false
	lamp.add_child(light)
	lanterns.append(light)
	lantern_bodies.append(lamp)

func _build_rock(r: Dictionary) -> void:
	var x: float = r["x"]
	var y: float = r["y"]
	var hw: float = r["hw"]
	var hh: float = r["hh"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(x * 31.0)
	var pts := PackedVector2Array()
	var n := 10
	for i in n:
		var a := TAU * float(i) / float(n)
		var k := rng.randf_range(0.85, 1.05)
		pts.append(w2s(x + cos(a) * hw * k, y + sin(a) * hh * k))
	var p := _poly(pts, rock_tex, Color(0.9, 0.9, 0.9))
	p.z_index = 1
	_occluder(pts)

static var _leaf: ImageTexture

static func leaf_tex_small() -> ImageTexture:
	if _leaf == null:
		var img := Image.create(12, 6, false, Image.FORMAT_RGBA8)
		for y in 6:
			for x in 12:
				var u := (float(x) + 0.5) / 12.0 * 2.0 - 1.0
				var v := (float(y) + 0.5) / 6.0 * 2.0 - 1.0
				var w := 1.0 - absf(u) * (0.6 if u > 0.0 else 0.25)
				var a := clampf((w - absf(v)) * 3.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_leaf = ImageTexture.create_from_image(img)
	return _leaf

static var _radial: GradientTexture2D

static func _radial_tex() -> GradientTexture2D:
	if _radial == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		_radial = GradientTexture2D.new()
		_radial.gradient = g
		_radial.fill = GradientTexture2D.FILL_RADIAL
		_radial.fill_from = Vector2(0.5, 0.5)
		_radial.fill_to = Vector2(1.0, 0.5)
		_radial.width = 256
		_radial.height = 256
	return _radial

func _build_fx() -> void:
	leaf_burst = CPUParticles2D.new()
	leaf_burst.emitting = false
	leaf_burst.one_shot = true
	leaf_burst.explosiveness = 0.9
	leaf_burst.amount = 14
	leaf_burst.lifetime = 2.4
	leaf_burst.gravity = Vector2(0, 160)
	leaf_burst.initial_velocity_min = 40.0
	leaf_burst.initial_velocity_max = 140.0
	leaf_burst.spread = 180.0
	leaf_burst.angular_velocity_min = -200.0
	leaf_burst.angular_velocity_max = 200.0
	leaf_burst.scale_amount_min = 1.2
	leaf_burst.scale_amount_max = 2.2
	leaf_burst.color = Color(0.45, 0.7, 0.35)
	leaf_burst.damping_min = 30.0
	leaf_burst.damping_max = 60.0
	leaf_burst.z_index = 6
	leaf_burst.texture = leaf_tex_small()
	add_child(leaf_burst)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.5, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	for lamp in lantern_bodies:
		var ff := CPUParticles2D.new()
		ff.amount = 9
		ff.lifetime = 6.0
		ff.preprocess = 6.0
		ff.texture = _radial_tex()
		ff.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		ff.emission_sphere_radius = 90.0
		ff.gravity = Vector2.ZERO
		ff.direction = Vector2(0, -1)
		ff.spread = 180.0
		ff.initial_velocity_min = 4.0
		ff.initial_velocity_max = 14.0
		ff.scale_amount_min = 0.025
		ff.scale_amount_max = 0.045
		ff.color = Color(1.5, 1.3, 0.5)
		ff.color_ramp = ramp
		var fm := CanvasItemMaterial.new()
		fm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		fm.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		ff.material = fm
		ff.z_index = 6
		lamp.add_child(ff)

func react_attach(a: int, toward_px: Vector2, speed: float) -> void:
	if a < 0 or a >= anchor_tips.size():
		return
	var tip := anchor_tips[a]
	var pull := (toward_px - tip.position).normalized() * clampf(speed, 4.0, 30.0) * 9.0
	tip_springs[a] = [Vector2.ZERO, pull]
	leaf_burst.global_position = tip.global_position
	leaf_burst.restart()

func tip_offset(a: int) -> Vector2:
	return Vector2(tip_springs[a][0]) if tip_springs.has(a) else Vector2.ZERO

func step_springs(delta: float) -> void:
	for a: int in tip_springs.keys():
		var s: Array = tip_springs[a]
		var off: Vector2 = s[0]
		var vel: Vector2 = s[1]
		vel += (-off * 90.0 - vel * 5.5) * delta
		off += vel * delta
		var tip := anchor_tips[a]
		tip.position = tip.position - Vector2(s[0]) + off
		if off.length() < 0.05 and vel.length() < 0.5:
			tip.position -= off
			tip_springs.erase(a)
		else:
			tip_springs[a] = [off, vel]

func update_lanterns(mood: Dictionary, tt: float) -> void:
	var base := lerpf(look.lantern_energy.x, look.lantern_energy.y, float(mood["overcast"]))
	var wind: float = mood["wind"]
	for i in lanterns.size():
		var f := (0.88 + 0.12 * sin(tt * 0.9 + i)) * (1.0 + 0.06 * sin(tt * 11.0 + i * 1.7) + 0.04 * sin(tt * 23.0 + i * 3.1))
		lanterns[i].energy = base * f
		lanterns[i].texture_scale = 10.0 * (0.97 + 0.03 * f)
		lantern_bodies[i].rotation = (0.04 + wind * 0.4) * sin(tt * 1.3 + i * 2.0)
	for i in dapples.size():
		dapples[i].offset = Vector2(sin(tt * 0.5 + i) * 6.0 + wind * 30.0, cos(tt * 0.37 + i * 1.3) * 3.0)
