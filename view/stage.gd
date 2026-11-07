extends Node2D

const S := preload("res://game/snap.gd")
const Palette := preload("res://view/palette.gd")
const WorldView := preload("res://view/world_view.gd")
const GirlView := preload("res://view/girl_view.gd")
const CameraRig := preload("res://view/camera_rig.gd")
const SkyView := preload("res://view/sky.gd")
const Weather := preload("res://view/weather.gd")
const Grade := preload("res://view/grade.gd")
const Fauna := preload("res://view/fauna.gd")
const Kits := preload("res://look/kits.gd")
const UI := preload("res://view/ui.gd")
const AudioView := preload("res://view/audio_view.gd")

var host: Node
var look: Resource
var world: Node2D
var girl: Node2D
var rig: Camera2D
var sky: Node2D
var weather: Node2D
var grade: Node
var fauna: Node2D
var audio: Node
var wind := Vector2.ZERO

func setup(h: Node, lk: Resource) -> void:
	host = h
	look = lk
	sky = SkyView.new()
	add_child(sky)
	sky.build(host.course, look)
	world = WorldView.new()
	add_child(world)
	world.build(host.course, look)
	girl = GirlView.new()
	add_child(girl)
	girl.build(look, world, host.course)
	rig = CameraRig.new()
	add_child(rig)
	rig.make_current()
	weather = Weather.new()
	add_child(weather)
	weather.build(look)
	grade = Grade.new()
	add_child(grade)
	grade.build(look)
	fauna = Fauna.new()
	add_child(fauna)
	fauna.build(look)
	var ui := UI.new()
	add_child(ui)
	ui.build(host)
	audio = AudioView.new()
	add_child(audio)
	audio.setup(host.course, rig)
	host.stepped.connect(_on_stepped)
	host.sim_event.connect(_on_event)
	host.respawned.connect(_on_respawned)
	_on_respawned(host.snap)

func _on_respawned(snap: PackedFloat64Array) -> void:
	girl.body.modulate = Color.WHITE
	girl.cloak.modulate = Color.WHITE
	girl.place(snap, true, wind)
	rig.follow(snap, true)

func _on_stepped(snap: PackedFloat64Array) -> void:
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	girl.place(snap, false, wind)
	rig.follow(snap, false)
	world.step_springs(dt)
	sky.on_physics(snap, dt)

func _on_event(kind: String, data: PackedFloat64Array, snap: PackedFloat64Array) -> void:
	girl.on_event(kind, snap)
	audio.on_event(kind, data)
	match kind:
		"attach":
			var speed := data[2] if data.size() > 2 else 10.0
			world.react_attach(int(snap[S.HOOK_ANCHOR]), girl.body.position, speed)
			rig.kick(0.25 + speed * 0.02)
		"bump":
			rig.kick(0.8)
		"pad":
			rig.kick(0.3)

func _process(delta: float) -> void:
	var snap: PackedFloat64Array = host.snap
	if snap.is_empty():
		return
	if snap[S.MODE] == S.MODE_DEAD:
		rig.follow(snap, false)
	var mood: Dictionary = host.mood()
	var pal := Palette.sample(float(mood["t"]))
	wind = Vector2(float(mood["wind"]) * look.wind_sway, 0.0)
	RenderingServer.global_shader_parameter_set(&"wind", wind)
	RenderingServer.global_shader_parameter_set(&"storm", float(mood["storm"]))
	RenderingServer.global_shader_parameter_set(&"flash", float(mood["flash"]))
	var vp := get_viewport_rect().size
	sky.update(snap, pal, mood, rig.center, vp)
	world.update_far(pal, float(mood["overcast"]))
	world.update_lanterns(mood, Time.get_ticks_msec() / 1000.0)
	girl.update_look(snap, pal, mood, host.dead_time, delta)
	var kit := Kits.at(host.course.get("scenes", []), snap[S.X])
	weather.update(mood, rig.position, vp.y / rig.zoom.y, wind, kit)
	fauna.update(kit, rig.position, vp / rig.zoom, vp, wind, Color(pal["fog"]), delta)
	grade.update(pal, mood, sky.sun_uv)
	audio.update(snap, mood, delta)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		var k := e as InputEventKey
		var mac_full := k.keycode == KEY_F and k.ctrl_pressed and k.meta_pressed
		if k.keycode == KEY_F11 or mac_full:
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
