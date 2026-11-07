extends CanvasLayer

var host: Node
var screen: Control
var title: Texture2D
var title_dot := Vector2(-1, -1)
var tbc: Texture2D
var icon_continue: Texture2D
var icon_hold: Texture2D
var t := 0.0
var menu_a := 0.0
var idle := 0.0
var pause_a := 0.0
var end_a := 0.0
var continue_rect := Rect2()
var exit_rect := Rect2()
var exit_armed := -10.0
const ARM := 2.0

func build(h: Node) -> void:
	host = h
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	title = _opt("res://art/ui/title.png")
	tbc = _opt("res://art/ui/tbc.png")
	icon_continue = _opt("res://art/ui/icon_continue.png")
	icon_hold = _opt("res://art/ui/icon_hold.png")
	if FileAccess.file_exists("res://art/ui/title.json"):
		var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/ui/title.json"))
		var d: Dictionary = j.get("i_dot", {})
		title_dot = Vector2(float(d.get("x", -1)), float(d.get("y", -1)))
	screen = Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.draw.connect(_draw_screen)
	add_child(screen)

func _opt(p: String) -> Texture2D:
	return load(p) as Texture2D if ResourceLoader.exists(p) else null

func _process(delta: float) -> void:
	t += delta
	var in_menu: bool = host.menu
	menu_a = move_toward(menu_a, 1.0 if in_menu else 0.0, delta * (0.6 if in_menu else 2.5))
	idle = idle + delta if in_menu else 0.0
	pause_a = move_toward(pause_a, 1.0 if host.paused else 0.0, delta * 5.0)
	end_a = move_toward(end_a, 1.0 if host.ending else 0.0, delta * (0.7 if host.ending else 3.0))
	screen.queue_redraw()

func _input(e: InputEvent) -> void:

	if host.paused and e is InputEventMouseButton and e.pressed and continue_rect.has_point(e.position):
		host.set_paused(false)
		get_viewport().set_input_as_handled()

	elif host.paused and e is InputEventMouseButton and e.pressed and exit_rect.has_point(e.position):
		if t - exit_armed < ARM:
			get_tree().quit()
		else:
			exit_armed = t
		get_viewport().set_input_as_handled()

func _draw_screen() -> void:
	var sz := screen.get_viewport_rect().size
	var c := sz * 0.5

	if menu_a > 0.001:
		var top := Vector2(c.x, sz.y * 0.24)
		var breathe := 0.75 + 0.25 * sin(t * 1.6)
		var dot := top
		if title != null:
			var w := minf(sz.x * 0.36, float(title.get_width()))
			var k := w / float(title.get_width())
			var rect := Rect2(top - Vector2(w * 0.5, title.get_height() * k * 0.5), Vector2(w, title.get_height() * k))
			screen.draw_texture_rect(title, rect, false, Color(1, 1, 1, menu_a))
			if title_dot.x >= 0.0:
				dot = rect.position + title_dot * k
			else:
				dot = Vector2(-1000, -1000)
		_glow(dot, breathe, menu_a)
		if idle > 2.5:
			var ha := clampf((idle - 2.5) / 1.0, 0.0, 1.0) * menu_a
			var p := Vector2(c.x, sz.y * 0.86)
			var press := 0.88 + 0.12 * (0.5 + 0.5 * sin(t * 2.2))
			if icon_hold != null:
				var s := 56.0 * press
				screen.draw_texture_rect(icon_hold, Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, 0.75 * ha))
			else:
				screen.draw_arc(p, 18.0 * press, 0.0, TAU, 48, Color(0.94, 0.89, 0.84, 0.7 * ha), 1.5, true)
				screen.draw_circle(p, 3.0, Color(0.94, 0.89, 0.84, 0.8 * ha))

	if pause_a > 0.001:
		screen.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.02, 0.025, 0.05, 0.5 * pause_a))
		var pw := minf(420.0, sz.x * 0.6)
		var ph := 240.0
		var rise := (1.0 - pause_a) * 14.0
		var panel := Rect2(c - Vector2(pw, ph) * 0.5 + Vector2(0, rise), Vector2(pw, ph))
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.06, 0.07, 0.11, 0.82 * pause_a)
		box.border_color = Color(0.94, 0.89, 0.84, 0.28 * pause_a)
		box.set_border_width_all(1)
		box.set_corner_radius_all(18)
		box.shadow_color = Color(0, 0, 0, 0.35 * pause_a)
		box.shadow_size = 24
		box.anti_aliasing = true
		screen.draw_style_box(box, panel)

		var s := 72.0
		var cc := Vector2(c.x, panel.position.y + ph * 0.42)
		continue_rect = Rect2(cc - Vector2(s, s) * 0.5, Vector2(s, s))
		var hover := continue_rect.has_point(screen.get_local_mouse_position())
		if hover:
			screen.draw_circle(cc, s * 0.62, Color(1.0, 0.85, 0.6, 0.08 * pause_a))

		var ec := Vector2(c.x, panel.position.y + ph * 0.8)
		var es := 34.0
		exit_rect = Rect2(ec - Vector2(es, es) * 0.5, Vector2(es, es))
		var armed := t - exit_armed < ARM
		var ea := (0.95 if armed else (0.6 if exit_rect.has_point(screen.get_local_mouse_position()) else 0.35)) * pause_a
		if armed:
			screen.draw_circle(ec, es * 0.75, Color(1.0, 0.6, 0.45, (0.16 + 0.08 * sin(t * 9.0)) * pause_a))
		var ecol := Color(1.0, 0.75, 0.62, ea) if armed else Color(0.94, 0.89, 0.84, ea)
		screen.draw_arc(ec, es * 0.36, -PI * 0.33, PI * 1.33, 32, ecol, 2.0, true)
		screen.draw_line(ec + Vector2(0, -es * 0.48), ec + Vector2(0, -es * 0.12), ecol, 2.0, true)
		if icon_continue != null:
			screen.draw_texture_rect(icon_continue, continue_rect, false, Color(1, 1, 1, 0.9 * pause_a))
		else:
			var tri := PackedVector2Array([cc + Vector2(-14, -20), cc + Vector2(22, 0), cc + Vector2(-14, 20)])
			screen.draw_colored_polygon(tri, Color(0.94, 0.89, 0.84, 0.85 * pause_a))

	if end_a > 0.001:
		screen.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.012, 0.014, 0.03, end_a))
		var ta := clampf((end_a - 0.6) / 0.4, 0.0, 1.0)
		if tbc != null:
			var w := minf(sz.x * 0.3, float(tbc.get_width()))
			var k := w / float(tbc.get_width())
			screen.draw_texture_rect(tbc, Rect2(c - Vector2(w, tbc.get_height() * k) * 0.5, Vector2(w, tbc.get_height() * k)), false, Color(1, 1, 1, ta))
		else:
			var f := ThemeDB.fallback_font
			var txt := "to be continued"
			var fs := 22
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			screen.draw_string(f, c + Vector2(-tw * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.94, 0.89, 0.84, 0.8 * ta))
		_glow(c + Vector2(0, -60), 0.75 + 0.25 * sin(t * 1.6), ta)

func _glow(p: Vector2, breathe: float, a: float) -> void:
	for i in 6:
		var r := 4.0 + float(i) * 9.0 * breathe
		screen.draw_circle(p, r, Color(1.0, 0.72, 0.4, 0.06 * (1.0 - float(i) / 6.0) * a))
	screen.draw_circle(p, 2.2, Color(1.0, 0.85, 0.6, 0.9 * a))
