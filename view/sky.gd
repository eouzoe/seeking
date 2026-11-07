extends Node2D

const S := preload("res://game/snap.gd")
const PX := 24.0

var look: Resource
var sky_mat: ShaderMaterial
var cloud_mat: ShaderMaterial
var sun: DirectionalLight2D
var bolt: Line2D
var bolt_seed := -1
var sun_uv := Vector2(0.7, 0.3)
var impact_age := 99.0
var impact_x := 0.0
var in_cloud := false

func build(course: Dictionary, lk: Resource) -> void:
	look = lk
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = preload("res://view/shaders/sky.gdshader")
	rect.material = sky_mat
	layer.add_child(rect)
	bolt = Line2D.new()
	bolt.width = 3.0
	bolt.default_color = Color(5.0, 5.2, 6.5)
	bolt.visible = false
	layer.add_child(bolt)

	var length: float = course["length"]
	var cloud := Polygon2D.new()
	cloud.polygon = PackedVector2Array([Vector2(-200 * PX, -3 * PX), Vector2((length + 200) * PX, -3 * PX), Vector2((length + 200) * PX, 40 * PX), Vector2(-200 * PX, 40 * PX)])
	cloud_mat = ShaderMaterial.new()
	cloud_mat.shader = preload("res://view/shaders/cloud_sea.gdshader")
	cloud.material = cloud_mat
	cloud.z_index = 10
	cloud.light_mask = 0
	add_child(cloud)

	sun = DirectionalLight2D.new()
	sun.shadow_enabled = false
	sun.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	sun.shadow_filter_smooth = 4.0
	sun.shadow_item_cull_mask = 1
	sun.shadow_color = Color(0.0, 0.0, 0.05, 0.75)
	sun.max_distance = 4000.0
	add_child(sun)

func on_physics(snap: PackedFloat64Array, delta: float) -> void:
	impact_age += delta
	if snap[S.Y] < 0.3 and not in_cloud:
		in_cloud = true
		impact_age = 0.0
		impact_x = snap[S.X]
	elif snap[S.Y] > 1.0:
		in_cloud = false

func update(snap: PackedFloat64Array, pal: Dictionary, mood: Dictionary, cam_center: Vector2, vp: Vector2) -> void:
	var prog := clampf((float(mood["t"]) - 0.215) / (0.68 - 0.215), 0.0, 1.0)
	var overcast: float = mood["overcast"]
	var storm: float = mood["storm"]
	var sun_x := lerpf(0.82, 0.2, prog)
	var sun_y := 0.62 - sin(prog * PI) * 0.45 + clampf(-cam_center.y / 40.0, -0.2, 0.2) * 0.15
	sun_uv = Vector2(sun_x, sun_y)
	var sun_amt: float = float(pal["sun_a"]) * (1.0 - overcast * 0.9) * (1.0 + float(mood["clearing"]) * 0.3)
	var horizon_uv := 0.72 + clampf(-cam_center.y / 30.0, -0.3, 0.3)
	var stormy := Color(0.36, 0.4, 0.48)
	sky_mat.set_shader_parameter(&"zenith", Color(pal["zenith"]).lerp(stormy.darkened(0.3), storm * 0.7))
	sky_mat.set_shader_parameter(&"horizon", Color(pal["horizon"]).lerp(stormy, storm * 0.6))
	sky_mat.set_shader_parameter(&"glow_color", pal["glow"])
	sky_mat.set_shader_parameter(&"sun_color", pal["sun"])
	sky_mat.set_shader_parameter(&"sun_uv", sun_uv)
	sky_mat.set_shader_parameter(&"sun_amount", sun_amt)
	sky_mat.set_shader_parameter(&"horizon_uv", horizon_uv)
	sky_mat.set_shader_parameter(&"aspect", vp.x / maxf(vp.y, 1.0))
	sky_mat.set_shader_parameter(&"overcast", overcast)
	sky_mat.set_shader_parameter(&"rainbow", mood["rainbow"])
	sky_mat.set_shader_parameter(&"stars", pal["star"])
	var dir := Vector2(0.5 - sun_x, 0.9 - sun_y * 0.6).normalized()
	sun.rotation = dir.angle() - PI * 0.5
	sun.height = look.sun_height
	var flash: float = mood["flash"]
	sun.color = Color(pal["sun"]).lerp(Color(0.7, 0.75, 0.85), overcast).lerp(Color(0.85, 0.9, 1.0), flash)
	sun.energy = lerpf(look.sun_energy.x, look.sun_energy.y, sun_amt) + flash * 2.5
	cloud_mat.set_shader_parameter(&"body", Color(pal["horizon"]).lerp(Color(pal["fog"]), 0.35).darkened(0.18).lerp(stormy, storm * 0.5))
	cloud_mat.set_shader_parameter(&"shade", Color(pal["fog"]).lerp(Color(pal["ink"]), 0.35))
	cloud_mat.set_shader_parameter(&"rim", pal["glow"])
	cloud_mat.set_shader_parameter(&"rim_power", 0.45 * sun_amt)
	cloud_mat.set_shader_parameter(&"girl", Vector2(snap[S.X], snap[S.Y]))
	cloud_mat.set_shader_parameter(&"impact", Vector2(impact_x, 0.0))
	cloud_mat.set_shader_parameter(&"impact_age", impact_age)
	_update_bolt(mood, vp)

func _update_bolt(mood: Dictionary, vp: Vector2) -> void:
	var flash: float = mood["flash"]
	var seed_now: int = mood["bolt_seed"]
	if flash > 0.6 and seed_now != bolt_seed:
		bolt_seed = seed_now
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_now * 7919
		var x := rng.randf_range(0.15, 0.85) * vp.x
		var y := 0.0
		var pts := PackedVector2Array([Vector2(x, y)])
		while y < vp.y * 0.55:
			y += rng.randf_range(18.0, 46.0)
			x += rng.randf_range(-28.0, 28.0)
			pts.append(Vector2(x, y))
		bolt.points = pts
	bolt.visible = flash > 0.05
	bolt.modulate.a = clampf(flash * 1.4, 0.0, 1.0)
	bolt.width = 2.0 + flash * 3.0
