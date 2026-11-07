extends Camera2D

const S := preload("res://game/snap.gd")
const PX := 24.0

var center := Vector2.ZERO
var web_zoom := 1.0
var shake := 0.0

func _init() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS

func _ready() -> void:
	position_smoothing_enabled = false

func follow(snap: PackedFloat64Array, teleport: bool) -> void:
	var above := clampf((snap[S.Y] - 32.0) / 6.0, 0.0, 1.0)
	var sp := Vector2(snap[S.VX], snap[S.VY]).length()
	var tx := snap[S.X] + 6.0 + snap[S.VX] * 0.22
	var ty := maxf(10.5, snap[S.Y] + 3.5 - above * 1.5)
	var tz := 1.0 + minf(0.2, sp / 180.0) + above * 0.45
	if snap[S.MODE] == S.MODE_DEAD:
		ty = center.y
		tx = center.x + (tx - center.x) * 0.2
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var k := 1.0 - exp(-dt * 4.0)
	center.x += (tx - center.x) * k
	center.y += (ty - center.y) * k
	web_zoom += (tz - web_zoom) * (1.0 - exp(-dt * 2.2))
	if teleport:
		center = Vector2(tx, ty)
		web_zoom = tz
	position = Vector2(center.x * PX, -center.y * PX)
	zoom = Vector2.ONE * (1.25 / web_zoom)
	if teleport:
		reset_physics_interpolation()

func kick(amount: float) -> void:
	shake = maxf(shake, amount)

func _process(delta: float) -> void:
	shake = maxf(shake - delta * 2.5, 0.0)
	offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * shake * 14.0
