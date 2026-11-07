extends Node

const S := preload("res://game/snap.gd")
const Director := preload("res://game/director.gd")
const RESPAWN_DELAY := 1.2

signal stepped(snap: PackedFloat64Array)
signal sim_event(kind: String, data: PackedFloat64Array, snap: PackedFloat64Array)
signal respawned(snap: PackedFloat64Array)
signal started

var course: Dictionary
var director: RefCounted
var sim: RefCounted
var snap := PackedFloat64Array()
var wall := 0.0
var dead_time := 0.0
var input_provider: Callable
var sim_factory: Callable
var menu := false
var chapter := 0
var unlocked: Array[String] = []
const PROGRESS := "user://progress.cfg"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup(c: Dictionary) -> void:
	course = c
	director = Director.new(float(c["length"]), int(c["seed"]), c.get("scenes", []))
	sim = sim_factory.call() if sim_factory.is_valid() else preload("res://game/sim_gd.gd").new()
	sim.call(&"load_course", JSON.stringify(_ints_back(c), "", false, true))
	_load_progress()
	menu = true
	chapter = maxi(0, _chapter_index(unlocked[unlocked.size() - 1]))
	sim.call(&"reset", _chapter_pad(chapter))
	snap = sim.call(&"snapshot")
	started.emit()

func mood() -> Dictionary:
	return director.mood(snap[S.X], wall)

func _chapter_pad(i: int) -> int:
	var chs: Array = course.get("chapters", [])
	return int(chs[i]["pad"]) if i < chs.size() else 0

func _chapter_index(id: String) -> int:
	var chs: Array = course.get("chapters", [])
	for i in chs.size():
		if chs[i]["id"] == id:
			return i
	return -1

func _load_progress() -> void:
	var cf := ConfigFile.new()
	cf.load(PROGRESS)
	var saved: Array = cf.get_value("progress", "unlocked", ["prologue"])
	unlocked.clear()
	for s: Variant in saved:
		unlocked.append(String(s))

func _unlock(id: String) -> void:
	if unlocked.has(id):
		return
	unlocked.append(id)
	var cf := ConfigFile.new()
	cf.set_value("progress", "unlocked", unlocked)
	cf.save(PROGRESS)

func select(step: int) -> void:
	if not menu:
		return
	var chs: Array = course.get("chapters", [])
	var i := chapter
	while true:
		i += step
		if i < 0 or i >= chs.size():
			return
		if unlocked.has(String(chs[i]["id"])):
			break
	chapter = i
	sim.call(&"reset", _chapter_pad(chapter))
	snap = sim.call(&"snapshot")
	respawned.emit(snap)

func to_menu() -> void:
	menu = true
	dead_time = 0.0
	sim.call(&"reset", _chapter_pad(chapter))
	snap = sim.call(&"snapshot")
	respawned.emit(snap)

func _hold() -> bool:
	if input_provider.is_valid():
		return input_provider.call(snap)
	return Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func restart() -> void:
	sim.call(&"reset", int(snap[S.SAVE]))
	dead_time = 0.0
	snap = sim.call(&"snapshot")
	respawned.emit(snap)

func _physics_process(delta: float) -> void:
	if paused:
		return
	wall += delta
	if snap[S.MODE] == S.MODE_DEAD:
		dead_time += delta
		if dead_time > RESPAWN_DELAY:
			restart()
		return
	if ending:
		stepped.emit(snap)
		return
	if menu:
		stepped.emit(snap)
		if not _hold():
			return
		menu = false
	var n: int = sim.call(&"step", _hold())
	snap = sim.call(&"snapshot")
	for ch: Dictionary in course.get("chapters", []):
		var pad: Dictionary = course["pads"][int(ch["pad"])]
		if snap[S.X] >= float(pad["x"]):
			_unlock(String(ch["id"]))
	if not ending and int(snap[S.SAVE]) == _last_save() and _last_save() > _chapter_pad(chapter) and snap[S.MODE] == S.MODE_PERCH:
		ending = true
		ending_time = 0.0
		finished.emit()
	for i in n:
		sim_event.emit(String(sim.call(&"event_kind", i)), sim.call(&"event_data", i), snap)
	stepped.emit(snap)

static func _ints_back(v: Variant) -> Variant:
	if v is float and v == roundf(v) and absf(v) < 9.0e15:
		return int(v)
	if v is Dictionary:
		var d := {}
		for k: Variant in v:
			d[k] = _ints_back(v[k])
		return d
	if v is Array:
		var a: Array = []
		for x: Variant in v:
			a.append(_ints_back(x))
		return a
	return v

const DOUBLE := 0.45
var paused := false
var paused_at := 0.0
signal finished
var ending := false
var ending_time := 0.0
const ENDING_HOLD := 6.0

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func set_paused(p: bool) -> void:
	paused = p
	paused_at = _now()
	get_tree().paused = p

func _last_save() -> int:
	var pads: Array = course["pads"]
	for i in range(pads.size() - 1, -1, -1):
		if pads[i]["save"]:
			return i
	return -1

func _process(delta: float) -> void:
	if ending:
		ending_time += delta
		if ending_time > ENDING_HOLD:
			_leave_ending()

func _leave_ending() -> void:
	ending = false
	ending_time = 0.0
	to_menu()

func _unhandled_input(e: InputEvent) -> void:
	var pressed: bool = (e is InputEventKey and e.pressed and not e.echo) or (e is InputEventMouseButton and e.pressed) or (e is InputEventJoypadButton and e.pressed)
	if not pressed:
		return
	if ending:
		if ending_time > 1.5:
			_leave_ending()
		get_viewport().set_input_as_handled()
		return
	if not (e is InputEventKey):
		return
	var k := e as InputEventKey
	if k.keycode == KEY_ESCAPE:
		if menu:
			set_paused(not paused)
		elif not paused:
			set_paused(true)
		elif _now() - paused_at < DOUBLE:
			set_paused(false)
			to_menu()
		else:
			set_paused(false)
		get_viewport().set_input_as_handled()
	elif menu and (k.keycode == KEY_LEFT or k.keycode == KEY_A):
		select(-1)
	elif menu and (k.keycode == KEY_RIGHT or k.keycode == KEY_D):
		select(1)
