extends CanvasLayer

const NEXT := "res://game/main.tscn"
const STALL_LIMIT := 3.0
const WARM_FRAMES := 4
const MIN_TIME := 0.9

var t := 0.0
var progress := 0.0
var shown := 0.0
var last_change := 0.0
var packed: PackedScene
var game: Node
var warm := 0
var reveal := 0.0
var screen: Control

func _ready() -> void:
	layer = 100
	screen = Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.draw.connect(_draw_screen)
	add_child(screen)
	var err := ResourceLoader.load_threaded_request(NEXT, "PackedScene", true)
	if err != OK:
		_load_sync("load_threaded_request returned %s" % error_string(err))

func _load_sync(why: String) -> void:
	packed = load(NEXT) as PackedScene

func _process(delta: float) -> void:
	t += delta
	if packed == null:
		var prog: Array = []
		var st := ResourceLoader.load_threaded_get_status(NEXT, prog)
		match st:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				var p: float = prog[0] if prog.size() > 0 else 0.0
				if p > progress:
					progress = p
					last_change = t
				elif t - last_change > STALL_LIMIT:
					_load_sync("progress stuck at %d%% for over %.0f s" % [int(progress * 100.0), STALL_LIMIT])
			ResourceLoader.THREAD_LOAD_LOADED:
				packed = ResourceLoader.load_threaded_get(NEXT) as PackedScene
			_:
				_load_sync("status %d (failed or invalid path)" % st)
		if packed == null and st != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			get_tree().change_scene_to_file(NEXT)
			return
	else:
		progress = 1.0
		if game == null:
			game = packed.instantiate()
			get_tree().root.add_child(game)
			get_tree().root.move_child(game, 0)
		elif warm < WARM_FRAMES:
			warm += 1
		elif t > MIN_TIME:
			reveal += delta / 0.8
			if reveal >= 1.0:
				get_tree().current_scene = game
				queue_free()
	shown = move_toward(shown, progress, delta * 1.5)
	screen.queue_redraw()

func _draw_screen() -> void:
	var sz := screen.get_viewport_rect().size
	var a := 1.0 - smoothstep(0.0, 1.0, reveal)
	screen.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.012, 0.014, 0.03, a))
	var c := sz * 0.5
	var breathe := 0.75 + 0.25 * sin(t * 1.6)
	for i in 6:
		var r := 4.0 + float(i) * 9.0 * breathe
		screen.draw_circle(c + Vector2(0, -26), r, Color(1.0, 0.72, 0.4, 0.06 * (1.0 - float(i) / 6.0) * a))
	screen.draw_circle(c + Vector2(0, -26), 2.2, Color(1.0, 0.85, 0.6, 0.9 * a))
	var w := sz.x * 0.42
	var x0 := c.x - w * 0.5
	screen.draw_line(Vector2(x0, c.y), Vector2(x0 + w, c.y), Color(0.5, 0.55, 0.75, 0.08 * a), 1.0)
	screen.draw_line(Vector2(x0, c.y), Vector2(x0 + w * shown, c.y), Color(1.0, 0.8, 0.6, 0.6 * a), 1.0)
