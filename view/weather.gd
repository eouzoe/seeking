extends Node2D

const WorldView := preload("res://view/world_view.gd")

var look: Resource
var rain: GPUParticles2D
var rain_mat: ParticleProcessMaterial
var dust: CPUParticles2D
var leaves: GPUParticles2D
var petals: GPUParticles2D

func build(lk: Resource) -> void:
	look = lk

	rain = GPUParticles2D.new()
	rain.amount = maxi(int(look.rain_max), 1)
	rain.amount_ratio = 0.0
	rain.lifetime = 1.4
	rain.preprocess = 1.4
	rain.local_coords = false
	rain.visibility_rect = Rect2(-2000, -1500, 4000, 3000)
	rain.z_index = 8
	rain_mat = ParticleProcessMaterial.new()
	rain_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain_mat.emission_box_extents = Vector3(1500, 20, 0)
	rain_mat.direction = Vector3(0, 1, 0)
	rain_mat.spread = 2.0
	rain_mat.initial_velocity_min = 1100.0
	rain_mat.initial_velocity_max = 1350.0
	rain_mat.gravity = Vector3.ZERO
	rain_mat.particle_flag_align_y = true
	rain_mat.scale_min = 0.7
	rain_mat.scale_max = 1.2
	rain.process_material = rain_mat
	var streak := GradientTexture2D.new()
	streak.width = 2
	streak.height = 40
	streak.fill_from = Vector2(0.5, 0.0)
	streak.fill_to = Vector2(0.5, 1.0)
	var sg := Gradient.new()
	sg.set_color(0, Color(1, 1, 1, 0))
	sg.set_color(1, Color(1, 1, 1, 1))
	streak.gradient = sg
	rain.texture = streak
	var rm := CanvasItemMaterial.new()
	rm.light_mode = CanvasItemMaterial.LIGHT_MODE_NORMAL
	rain.material = rm
	add_child(rain)

	dust = CPUParticles2D.new()
	dust.amount = 140
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(1000, 560)
	dust.initial_velocity_min = 2.0
	dust.initial_velocity_max = 10.0
	dust.spread = 180.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.6
	dust.color = Color(1.6, 1.4, 1.1, 0.8)
	var dm := CanvasItemMaterial.new()
	dm.light_mode = CanvasItemMaterial.LIGHT_MODE_LIGHT_ONLY
	dm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	dust.material = dm
	dust.z_index = 5
	dust.local_coords = false
	add_child(dust)

	leaves = _faller(["res://art/elements/leaf_fall_a.png", "res://art/elements/leaf_fall_b.png", "res://art/elements/leaf_fall_c.png"], 48, 0.55)
	petals = _faller(["res://art/elements/petal_a.png", "res://art/elements/petal_b.png", "res://art/elements/petal_c.png"], 90, 0.45)

func _faller(paths: Array, n: int, size: float) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.amount = n
	p.amount_ratio = 0.0
	p.lifetime = 11.0
	p.preprocess = 11.0
	p.local_coords = false
	p.visibility_rect = Rect2(-2400, -1600, 4800, 3200)
	p.z_index = 5
	var tex: Texture2D = null
	for path: String in paths:
		if ResourceLoader.exists(path):
			tex = load(path)
			break
	p.texture = tex if tex != null else WorldView.leaf_tex_small()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(1300, 30, 0)
	m.direction = Vector3(0.3, 1, 0)
	m.spread = 25.0
	m.initial_velocity_min = 15.0
	m.initial_velocity_max = 40.0
	m.gravity = Vector3(0, 28, 0)
	m.angular_velocity_min = -120.0
	m.angular_velocity_max = 120.0
	m.angle_max = 360.0
	m.scale_min = size * 0.7
	m.scale_max = size * 1.3
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 2.5
	m.turbulence_noise_scale = 4.0
	m.turbulence_influence_min = 0.05
	m.turbulence_influence_max = 0.15
	p.process_material = m
	add_child(p)
	return p

func update(mood: Dictionary, cam_px: Vector2, view_h: float, wind: Vector2, kit: Dictionary = {}) -> void:
	var r: float = mood["rain"]
	rain.amount_ratio = r
	rain.emitting = r > 0.01
	rain.global_position = cam_px + Vector2(-wind.x * 260.0, -view_h * 0.6)
	rain_mat.direction = Vector3(wind.x * 1.6, 1.0, 0.0).normalized()
	rain.modulate = look.rain_color
	dust.global_position = cam_px
	dust.gravity = Vector2(wind.x * 40.0, -2.0)
	dust.modulate.a = 1.0 - r * 0.8
	for f: GPUParticles2D in [leaves, petals]:
		f.global_position = cam_px + Vector2(0, -view_h * 0.55)
		(f.process_material as ParticleProcessMaterial).gravity = Vector3(wind.x * 120.0, 28.0, 0.0)
	if not kit.is_empty():
		leaves.amount_ratio = float(kit["fall_leaf"])
		petals.amount_ratio = float(kit["fall_petal"])
		leaves.modulate = kit["leaf_color"]
		petals.modulate = kit["petal_color"]
