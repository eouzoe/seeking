extends RefCounted

const Author := preload("res://game/author.gd")
const Prologue := preload("res://game/content/prologue.gd")
const Spring := preload("res://game/content/spring.gd")

static func build() -> Dictionary:
	var a := Author.new(0.0)
	var scenes: Array = []
	var chapters: Array = []
	chapters.append({"id": "prologue", "pad": a.pads.size()})
	Prologue.build_into(a, scenes)
	chapters.append({"id": "spring", "pad": a.pads.size()})
	Spring.build_into(a, scenes)
	var c: Dictionary = a.finish("demo", 1, Vector2(0, 10))
	if not a.errors.is_empty():
		pass
	c["scenes"] = scenes
	c["chapters"] = chapters
	return c
