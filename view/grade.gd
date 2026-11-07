extends Node

var look: Resource
var post_mat: ShaderMaterial
var grade_tex: GradientTexture1D
var env: Environment

func build(lk: Resource) -> void:
	look = lk
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = preload("res://view/shaders/post.gdshader")
	grade_tex = GradientTexture1D.new()
	grade_tex.gradient = Gradient.new()
	grade_tex.width = 256
	post_mat.set_shader_parameter(&"grade", grade_tex)
	rect.material = post_mat
	layer.add_child(rect)

	env = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_bloom = 0.02
	env.set_glow_level(1, 0.0)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(5, 1.0)
	env.set_glow_level(6, 0.6)

	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.adjustment_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func update(pal: Dictionary, mood: Dictionary, sun_uv: Vector2) -> void:
	var overcast: float = mood["overcast"]
	var flash: float = mood["flash"]
	var sun_amt: float = float(pal["sun_a"]) * (1.0 - overcast * 0.9)

	var g := grade_tex.gradient
	g.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	var ink: Color = pal["ink"]
	g.colors = PackedColorArray([ink.darkened(0.2), ink.lerp(Color(pal["zenith"]), 0.5), Color(pal["fog"]).lerp(Color(pal["glow"]), 0.5), Color(pal["sun"]).lerp(Color.WHITE, 0.3)])
	post_mat.set_shader_parameter(&"grade_amount", look.grade_amount * lerpf(1.0, 1.25, overcast))
	post_mat.set_shader_parameter(&"sun_uv", sun_uv)
	post_mat.set_shader_parameter(&"ray_color", pal["glow"])

	post_mat.set_shader_parameter(&"ray_amount", look.ray_amount * 4.0 * float(mood["clearing"]))
	post_mat.set_shader_parameter(&"ray_threshold", look.ray_threshold)
	post_mat.set_shader_parameter(&"grain", look.grain * (1.0 + float(mood["rain"]) * 0.6))
	post_mat.set_shader_parameter(&"chroma", look.chroma)
	post_mat.set_shader_parameter(&"vignette", look.vignette * (1.0 + float(mood["storm"]) * 0.5))
	env.tonemap_exposure = look.exposure * (1.0 - float(mood["storm"]) * 0.25) + flash * look.flash_exposure
	env.tonemap_agx_contrast = look.agx_contrast
	env.glow_intensity = look.glow_intensity * lerpf(1.0, 0.7, overcast)
	env.glow_strength = look.glow_strength
	env.glow_hdr_threshold = look.glow_threshold
	env.adjustment_saturation = look.saturation * lerpf(1.0, 0.8, float(mood["storm"]))
