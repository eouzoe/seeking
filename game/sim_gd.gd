extends RefCounted

const World := preload("res://sim/world.gd")
const MODES := {"perch": 0.0, "air": 1.0, "swing": 2.0, "dead": 3.0}
const HOOKS := {"idle": 0.0, "shoot": 1.0, "stuck": 2.0, "retract": 3.0, "miss": 4.0}

var course: Dictionary
var world: Variant
var events: Array = []

func load_course(json: String) -> bool:
	var c: Variant = JSON.parse_string(json)
	if not c is Dictionary:
		return false
	course = c
	world = World.create(course)
	return true

func reset(from_pad: int) -> void:
	world = World.create(course, maxi(from_pad, 0))

func step(hold: bool) -> int:
	events.clear()
	world.step(course, hold, events)
	return events.size()

func event_kind(i: int) -> String:
	return String(events[i]["type"]) if i >= 0 and i < events.size() else ""

func event_data(i: int) -> PackedFloat64Array:
	if i < 0 or i >= events.size():
		return PackedFloat64Array()
	var e: Dictionary = events[i]
	match String(e["type"]):
		"attach", "bump", "pad":
			return PackedFloat64Array([e["x"], e["y"], e["speed"]])
		"die":
			return PackedFloat64Array([e["x"], e["y"], Vector2(e["vx"], e["vy"]).length()])
		"release":
			return PackedFloat64Array([0.0, 0.0, e["speed"]])
	return PackedFloat64Array()

func tick() -> int:
	return world.tick

func snapshot() -> PackedFloat64Array:
	var w: Variant = world
	return PackedFloat64Array([w.x, w.y, w.vx, w.vy, w.angle, MODES[w.mode], HOOKS[w.h_state], w.h_anchor, w.h_ax, w.h_ay, w.h_tip, w.h_L, w.crouch, w.time, w.score, w.save, w.target, w.h_dx, w.h_dy])
