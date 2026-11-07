extends Node

const SimHost := preload("res://game/sim_host.gd")
const Stage := preload("res://view/stage.gd")

func _ready() -> void:

	var course: Dictionary = preload("res://game/content/chapters.gd").build()
	var host := SimHost.new()
	add_child(host)
	host.setup(course)
	var stage := Stage.new()
	add_child(stage)
	stage.setup(host, load("res://look/default.tres"))
