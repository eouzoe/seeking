extends Node2D

const S := preload("res://game/snap.gd")
const WorldView := preload("res://view/world_view.gd")
const PX := 24.0
const BODY_R := 0.55
const CHAR_H := 3.0
const K := PX * CHAR_H / 130.0
const O := Vector2(65, 80)
const FEET_BELOW := (140.0 - 80.0) * CHAR_H / 130.0
const STAND_LIFT := FEET_BELOW - BODY_R
const J_NECK := Vector2(66.0, 58.0)
const J_SHOULDER := Vector2(79.0, 67.0)
const J_ELBOW := Vector2(88.0, 81.0)
const J_HIP_NEAR := Vector2(70.0, 98.0)
const J_HIP_FAR := Vector2(59.0, 98.0)
const UPPER := 16.64
const LAUNCHER := 21.1
const DEG := PI / 180.0
const REST_UPPER := 32.74 * DEG
const REST_FORE := 76.29 * DEG
const REST_LEG_FAR := -0.32 * DEG
const REST_LEG_NEAR := 2.23 * DEG
const CLAW_HUB := Vector2(60, 75)
const CLOAK_CHAIN: Array[Vector2] = [Vector2(64.7, 52), Vector2(64.7, 62), Vector2(64.7, 72), Vector2(64.7, 82), Vector2(64.7, 92), Vector2(64.7, 102), Vector2(64.7, 111)]
const CLOAK_HW := 31.6
const CLOAK_STIFF: Array[float] = [999.0, 34.0, 20.0, 13.0, 9.0, 7.0, 6.0]
const TRAIL_MAX := 40

var look: Resource
var world: Node2D
var course: Dictionary
var atlas: Dictionary
var sc := 4.0
var tex: CanvasTexture
var rig: Node2D
var body: Node2D
var parts: Dictionary = {}
var lights: Array[CanvasItem] = []
var cloak: Polygon2D
var cloak_light: Polygon2D
var claw: Node2D
var prongs: Array[Sprite2D] = []
var body_light: PointLight2D
var rope: Line2D
var aim_light: PointLight2D
var trail: Line2D
var trail_p: PackedVector2Array = []
var trail_v: PackedVector2Array = []
var pose := {"body": 0.0, "head": 0.05, "arm": REST_UPPER, "fore": REST_FORE - REST_UPPER, "leg_far": REST_LEG_FAR, "leg_near": REST_LEG_NEAR, "squat": 0.0, "lift": STAND_LIFT}
var recoil := 0.0
var bump_t := -9.0
var wall := 0.0
var fx := PackedVector2Array()
var fo := PackedVector2Array()
var frest: Array[Vector2] = []
var flen: Array[float] = []
var fready := false
var muzzle := Vector2.ZERO
var fore_dir := Vector2.RIGHT

func build(lk: Resource, w: Node2D, c: Dictionary = {}) -> void:
	look = lk
	world = w
	course = c
	atlas = JSON.parse_string(FileAccess.get_file_as_string("res://art/girl/atlas.json"))
	sc = float(atlas["sc"])
	tex = CanvasTexture.new()
	tex.diffuse_texture = load("res://art/girl/girl.png")
	tex.normal_texture = load("res://art/girl/girl_n.png")
	tex.specular_color = Color(0.12, 0.11, 0.1)
	tex.specular_shininess = 0.4

	trail = Line2D.new()
	var wc := Curve.new()
	wc.add_point(Vector2(0, 0))
	wc.add_point(Vector2(1, 1))
	trail.width_curve = wc
	var tg := Gradient.new()
	tg.set_color(0, Color(1.4, 1.3, 1.2, 0.0))
	tg.set_color(1, Color(1.0, 0.95, 0.9, 0.14))
	trail.gradient = tg
	trail.z_index = 3
	trail.material = _add_mat()
	add_child(trail)

	body = Node2D.new()
	body.z_index = 4
	add_child(body)
	rig = Node2D.new()
	body.add_child(rig)
	_part("leg-far", J_HIP_FAR, 0)
	_part("leg-near", J_HIP_NEAR, 1)
	_part("torso", O, 2)
	_part("arm-upper", J_SHOULDER, 3)
	_part("hood", J_NECK, 5)
	_part("launcher", J_ELBOW, 6)
	cloak = Polygon2D.new()
	cloak.texture = tex
	cloak.z_index = 8
	add_child(cloak)
	if atlas["parts"].has("cloak-light"):
		cloak_light = Polygon2D.new()
		cloak_light.texture = load("res://art/girl/girl.png")
		cloak_light.material = _add_mat()
		cloak_light.z_index = 8
		add_child(cloak_light)
		lights.append(cloak_light)
	_init_cloak()

	body_light = PointLight2D.new()
	body_light.texture = WorldView._radial_tex()
	body_light.texture_scale = 2.2
	body_light.height = 40.0
	body_light.color = Color(1.0, 0.85, 0.7)
	rig.add_child(body_light)
	var occ := LightOccluder2D.new()
	var op := OccluderPolygon2D.new()
	op.polygon = PackedVector2Array([Vector2(-10, -30), Vector2(10, -30), Vector2(14, 30), Vector2(-14, 30)])
	occ.occluder = op
	occ.occluder_light_mask = 2
	rig.add_child(occ)

	rope = Line2D.new()
	rope.width = 3.0
	rope.z_index = 3
	rope.visible = false
	add_child(rope)
	_build_claw()
	aim_light = PointLight2D.new()
	aim_light.texture = WorldView._radial_tex()
	aim_light.texture_scale = 1.4
	aim_light.height = 30.0
	aim_light.color = Color(1.0, 0.9, 0.6)
	aim_light.energy = 0.0
	add_child(aim_light)

func _add_mat() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return m

func _part(name: String, joint: Vector2, z: int, parent: Node2D = null) -> Sprite2D:
	var d: Dictionary = atlas["parts"][name]
	var s := Sprite2D.new()
	s.texture = tex
	s.region_enabled = true
	s.region_rect = Rect2(d["x"], d["y"], d["w"], d["h"])
	s.centered = false
	s.offset = -Vector2((joint.x - float(d["ox"])) * sc, (joint.y - float(d["oy"])) * sc)
	s.scale = Vector2.ONE * (K / sc)
	s.position = (joint - O) * K
	s.z_index = z
	(parent if parent != null else rig).add_child(s)
	parts[name] = s
	if atlas["parts"].has(name + "-light"):
		var dl: Dictionary = atlas["parts"][name + "-light"]
		var l := Sprite2D.new()
		l.texture = load("res://art/girl/girl.png")
		l.region_enabled = true
		l.region_rect = Rect2(dl["x"], dl["y"], dl["w"], dl["h"])
		l.centered = false
		l.offset = s.offset
		l.material = _add_mat()
		s.add_child(l)
		lights.append(l)
	return s

func _build_claw() -> void:
	claw = Node2D.new()
	claw.z_index = 7
	add_child(claw)
	for side: float in [1.0, -1.0]:
		var p := _part("claw-prong", CLAW_HUB, 0, claw)
		p.position = Vector2.ZERO
		p.scale = Vector2(1.0, side) * (K / sc)
		prongs.append(p)
	for n in ["claw-tip", "claw-hub"]:
		var s := _part(n, CLAW_HUB, 1, claw)
		s.position = Vector2.ZERO

func _uv(name: String, c: Vector2) -> Vector2:
	var d: Dictionary = atlas["parts"][name]
	var u := float(d["x"]) + (c.x - float(d["ox"])) * sc
	var v := float(d["y"]) + (c.y - float(d["oy"])) * sc
	return Vector2(clampf(u, d["x"], float(d["x"]) + float(d["w"])), clampf(v, d["y"], float(d["y"]) + float(d["h"])))

func _init_cloak() -> void:
	var n := CLOAK_CHAIN.size()
	fx.resize(n)
	fo.resize(n)
	frest.clear()
	flen.clear()
	for i in n:
		frest.append((CLOAK_CHAIN[i] - O) * K)
		flen.append(0.0 if i == 0 else CLOAK_CHAIN[i].distance_to(CLOAK_CHAIN[i - 1]) * K)
	var quads: Array = []
	for i in n - 1:
		quads.append(PackedInt32Array([i, n + i, n + i + 1, i + 1]))
	cloak.polygons = quads
	cloak.uv = _cloak_uv("cloak")
	if cloak_light != null:
		cloak_light.polygons = quads
		cloak_light.uv = _cloak_uv("cloak-light")

func _cloak_uv(name: String) -> PackedVector2Array:
	var n := CLOAK_CHAIN.size()
	var l := PackedVector2Array()
	var r := PackedVector2Array()
	for i in n:
		var a := CLOAK_CHAIN[maxi(0, i - 1)]
		var b := CLOAK_CHAIN[mini(n - 1, i + 1)]
		var d := (b - a).normalized()
		var nrm := Vector2(-d.y, d.x)
		l.append(_uv(name, CLOAK_CHAIN[i] - nrm * CLOAK_HW))
		r.append(_uv(name, CLOAK_CHAIN[i] + nrm * CLOAK_HW))
	return l + r

static func _dir(a: float) -> Vector2:
	return Vector2(sin(a), cos(a))

static func _wrap(a: float) -> float:
	return a - roundf(a / TAU) * TAU

func _aim_arm(t: Vector2) -> float:
	var sh := rig.global_transform * ((J_SHOULDER - O) * K)
	var d := t - sh
	return _wrap(atan2(d.x, d.y) - pose["body"])

func _target_pose(snap: PackedFloat64Array) -> Dictionary:
	var t := {"body": 0.0, "head": 0.05, "arm": REST_UPPER, "fore": REST_FORE - REST_UPPER, "leg_far": REST_LEG_FAR, "leg_near": REST_LEG_NEAR, "squat": 0.0, "lift": STAND_LIFT}
	var mode := snap[S.MODE]
	var hook := int(snap[S.HOOK])
	var vx := snap[S.VX]
	var vy := snap[S.VY]
	if mode == S.MODE_PERCH:
		var breathe := sin(wall * 2.1) * 0.035
		t["head"] = 0.05 + breathe * 0.5
		t["arm"] = REST_UPPER - breathe * 0.6
		if snap[12] > 0.0:
			t["squat"] = 0.9
			t["arm"] = -0.7
			t["fore"] = 0.5
			t["head"] = -0.18
			t["leg_near"] = 0.25
	elif mode == S.MODE_SWING:
		t["lift"] = 0.0
		t["body"] = snap[S.ANGLE]
		t["arm"] = _aim_arm(Vector2(snap[S.HOOK_AX], -snap[S.HOOK_AY]) * PX)
		t["fore"] = 0.0
		var r := Vector2(snap[S.X] - snap[S.HOOK_AX], snap[S.Y] - snap[S.HOOK_AY])
		var vt := (vx * -r.y + vy * r.x) / maxf(r.length(), 0.001)
		var fw := clampf(-vt * 0.035, -0.8, 0.8)
		t["leg_near"] = 0.15 + fw * 0.9
		t["leg_far"] = -0.05 + fw * 0.6
		t["head"] = clampf(-snap[S.ANGLE] * 0.55, -0.6, 0.6) + 0.1
	elif mode == S.MODE_AIR:
		t["lift"] = 0.0
		var bumped := snap[13] - bump_t < 0.35
		if bumped:
			t.merge({"body": 0.2, "arm": 1.1, "fore": 1.2, "leg_far": 1.0, "leg_near": 1.1, "head": 0.4}, true)
		else:
			var fl := 1.0 - clampf(absf(vy) / 7.0, 0.0, 1.0)
			var up := vy > 0.0
			var lean := clampf(-vx * 0.01, -0.25, 0.25)
			t["body"] = lerpf(lean, lean * 0.5, fl)
			t["arm"] = lerpf(-0.6 if up else 1.6, 0.5, fl)
			t["fore"] = lerpf(0.3, 0.55, fl)
			t["leg_near"] = lerpf(0.55 if up else -0.35, 0.3, fl)
			t["leg_far"] = lerpf(0.35 if up else -0.5, 0.05, fl)
			t["head"] = lerpf(0.15 if up else -0.1, 0.05, fl)
			var target := int(snap[S.TARGET])
			if target >= 0 and course.has("anchors"):
				var a: Dictionary = course["anchors"][target]
				t["arm"] = _aim_arm(Vector2(a["x"], -float(a["y"])) * PX)
				t["fore"] = 0.0
		if hook == S.HOOK_SHOOT or hook == 4:
			t["arm"] = _aim_arm(body.position + Vector2(snap[S.HOOK_DX], -snap[S.HOOK_DY]) * 10.0 * PX)
			t["fore"] = 0.0
	else:
		t.merge({"lift": 0.0, "body": sin(wall * 1.2) * 0.5 + 0.6, "arm": 2.7, "fore": 0.4, "leg_far": -0.25, "leg_near": -0.1, "head": -0.35}, true)
	return t

func _smooth(k: String, tgt: float, rate: float, dt: float, ang: bool) -> void:
	var cur: float = pose[k]
	var d := _wrap(tgt - cur) if ang else tgt - cur
	pose[k] = cur + d * (1.0 - exp(-rate * dt))

func place(snap: PackedFloat64Array, teleport: bool, wind: Vector2) -> void:
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	wall += dt
	var p := Vector2(snap[S.X] * PX, -snap[S.Y] * PX)
	body.position = p
	var tg := _target_pose(snap)
	if teleport:
		pose = tg.duplicate()
		recoil = 0.0
	var mode := snap[S.MODE]
	var hook := int(snap[S.HOOK])
	var swinging := mode == S.MODE_SWING
	var fast := 16.0 if swinging or snap[13] - bump_t < 0.4 else 9.0
	var aiming := swinging or hook == S.HOOK_SHOOT or hook == 4
	_smooth("lift", tg["lift"], 30.0 if mode == S.MODE_PERCH else 18.0, dt, false)
	_smooth("squat", tg["squat"], 22.0, dt, false)
	_smooth("body", tg["body"], 30.0 if swinging else 10.0, dt, true)
	_smooth("head", tg["head"], 10.0, dt, true)
	_smooth("arm", float(tg["arm"]) - recoil * 0.3, 60.0 if aiming else fast, dt, true)
	_smooth("fore", float(tg["fore"]) + recoil * 0.35, 60.0 if aiming else fast, dt, true)
	_smooth("leg_far", tg["leg_far"], fast * 0.8, dt, true)
	_smooth("leg_near", tg["leg_near"], fast * 0.8, dt, true)
	recoil = maxf(0.0, recoil - dt * 7.0)
	_apply_pose()
	_step_cloak(dt, wind, Vector2(snap[S.VX], snap[S.VY]).length(), teleport)
	_step_trail(p, Vector2(snap[S.VX], -snap[S.VY]) * PX, teleport, wind)
	_place_hook(snap)
	if teleport:
		body.reset_physics_interpolation()
		rig.reset_physics_interpolation()

func _apply_pose() -> void:
	var squat: float = pose["squat"]
	var lift: float = pose["lift"]
	rig.position = Vector2(0, -(lift - 0.16 * squat * FEET_BELOW) * PX)
	rig.rotation = -float(pose["body"])
	rig.scale = Vector2(1.0 + 0.08 * squat, 1.0 - 0.16 * squat)
	var arm: float = pose["arm"]
	var fore: float = pose["fore"]
	parts["leg-far"].rotation = -(float(pose["leg_far"]) - REST_LEG_FAR)
	parts["leg-near"].rotation = -(float(pose["leg_near"]) - REST_LEG_NEAR)
	parts["arm-upper"].rotation = -(arm - REST_UPPER)
	parts["hood"].rotation = -float(pose["head"])
	var sh := (J_SHOULDER - O) * K
	var elbow := sh + _dir(arm) * UPPER * K
	parts["launcher"].position = elbow
	parts["launcher"].rotation = -(arm + fore - REST_FORE)
	var m_local := elbow + _dir(arm + fore) * LAUNCHER * K
	muzzle = rig.transform * m_local
	fore_dir = rig.transform.basis_xform(_dir(arm + fore)).normalized()

func _step_cloak(dt: float, wind: Vector2, speed: float, teleport: bool) -> void:
	var n := frest.size()
	var origin := body.position + rig.position
	var rot := rig.rotation
	var target := func(i: int) -> Vector2: return origin + frest[i].rotated(rot)
	if not fready or teleport or fx[0].distance_to(target.call(0)) > 6.0 * PX:
		for i in n:
			fx[i] = target.call(i)
			fo[i] = fx[i]
		fready = true
	else:
		var steps := 1
		var h := dt / float(steps)
		var keep := pow(0.5, h)
		var g := 11.0 * PX
		var wx := wind.x * 4.0 * PX
		var flutter := (6.0 + speed * 0.6) * PX
		var side := Vector2(cos(rig.rotation), sin(rig.rotation))
		fo[0] = fx[0]
		fx[0] = target.call(0)
		for i in range(1, n):
			var v := (fx[i] - fo[i]) * keep
			fo[i] = fx[i]
			var fl := flutter * (float(i) / float(n - 1)) * sin(wall * 9.0 + i * 1.7)
			fx[i] += v + (Vector2(wx, g) + side * fl) * h * h
			var st := minf(1.0, CLOAK_STIFF[i] * h)
			fx[i] += (target.call(i) - fx[i]) * st
		for it in 2:
			for i in range(1, n):
				var d := fx[i] - fx[i - 1]
				var dl := maxf(d.length(), 0.0001)
				fx[i] -= d * ((dl - flen[i]) / dl)
	var hw := CLOAK_HW * K * (rig.scale.x + rig.scale.y) * 0.5
	var l := PackedVector2Array()
	var r := PackedVector2Array()
	for i in n:
		var d := (fx[mini(n - 1, i + 1)] - fx[maxi(0, i - 1)]).normalized()
		var nrm := Vector2(-d.y, d.x)
		l.append(fx[i] - nrm * hw)
		r.append(fx[i] + nrm * hw)
	cloak.polygon = l + r
	if cloak_light != null:
		cloak_light.polygon = cloak.polygon

func _place_hook(snap: PackedFloat64Array) -> void:
	var hook := int(snap[S.HOOK])
	var p := body.position
	var tip: Vector2
	var open := 0.0
	if hook == S.HOOK_STUCK:
		tip = Vector2(snap[S.HOOK_AX] * PX, -snap[S.HOOK_AY] * PX) + world.tip_offset(int(snap[S.HOOK_ANCHOR]))
	elif hook == S.HOOK_SHOOT or hook == S.HOOK_RETRACT or hook == 4:
		tip = p + muzzle + Vector2(snap[S.HOOK_DX], -snap[S.HOOK_DY]) * snap[S.HOOK_TIP] * PX
		open = 1.0
	else:
		tip = p + muzzle
	var hand := p + muzzle
	rope.visible = hook >= S.HOOK_SHOOT and hook <= 4 and hand.distance_to(tip) > 2.0
	rope.points = PackedVector2Array([hand, tip])
	claw.position = tip
	var dir := (tip - hand).normalized() if rope.visible else fore_dir
	claw.rotation = dir.angle()
	var spread := 0.28 + open * 0.95
	prongs[0].rotation = spread
	prongs[1].rotation = -spread
	var target := int(snap[S.TARGET])
	var want := 0.0
	if target >= 0 and target < world.anchor_tips.size() and hook == S.HOOK_IDLE:
		aim_light.position = world.anchor_tips[target].position
		want = 0.75 + 0.25 * sin(wall * 4.0)
	aim_light.energy = move_toward(aim_light.energy, want, 0.08)

func on_event(kind: String, snap: PackedFloat64Array) -> void:
	if kind == "shoot":
		recoil = 1.0
	elif kind == "bump":
		bump_t = snap[13]

func _step_trail(p: Vector2, vel: Vector2, teleport: bool, wind: Vector2) -> void:
	if teleport:
		trail_p.clear()
		trail_v.clear()
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	for i in trail_p.size():
		trail_v[i] = trail_v[i] * (1.0 - 3.0 * dt) + Vector2(wind.x * 60.0, -8.0) * dt
		trail_p[i] += trail_v[i] * dt
	var spd := vel.length() / PX
	if spd > 8.0:
		trail_p.append(p + Vector2(0, -10))
		trail_v.append(vel * 0.08)
	var cap := TRAIL_MAX if spd > 8.0 else maxi(trail_p.size() - 2, 0)
	while trail_p.size() > cap:
		trail_p.remove_at(0)
		trail_v.remove_at(0)
	trail.points = trail_p
	trail.width = move_toward(trail.width, clampf((spd - 8.0) * 0.8, 0.0, 14.0), 0.25)

func update_look(snap: PackedFloat64Array, pal: Dictionary, mood: Dictionary, dead_time: float, delta: float) -> void:
	rope.default_color = look.rope
	var sun_amt: float = float(pal["sun_a"]) * (1.0 - float(mood["overcast"]) * 0.9)
	var sun_c: Color = Color(pal["sun"]) * (0.25 + 0.75 * sun_amt)
	for l in lights:
		l.modulate = Color(sun_c.r, sun_c.g, sun_c.b, 1.0)
	body_light.energy = lerpf(look.girl_light_energy.x, look.girl_light_energy.y, float(mood["overcast"]))
	if snap[S.MODE] == S.MODE_DEAD:
		if snap[S.Y] < 3.0:
			body.position.y += 60.0 * delta
			body.modulate.a = clampf(1.0 - dead_time * 1.2, 0.0, 1.0)
			cloak.modulate = body.modulate
		return
	var sink := clampf(1.0 - snap[S.Y] / 2.0, 0.0, 1.0)
	body.modulate = Color.WHITE.lerp(Color(pal["horizon"]).lerp(Color.WHITE, 0.4), sink * 0.6)
	cloak.modulate = body.modulate
