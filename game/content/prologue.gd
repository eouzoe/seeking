extends RefCounted

static func build_into(a: RefCounted, scenes: Array) -> void:
	var s0: float = a.x

	a.segment("p-camp", "rest", [["t", -6, 1.1, 34, 14], ["p", 0, 10, 8, true]])

	a.segment("p1-first", "warmup", [["t", 8, 0.9, 32, 13], ["b", 14, 22], ["t", 36, 1.0, 34, 14], ["b", 30, 23]])

	a.segment("p2-two", "warmup", [["t", 8, 0.9, 32, 13], ["b", 14, 23], ["t", 34, 0.9, 33, 13], ["b", 28, 23], ["t", 56, 1.0, 34, 14], ["b", 48, 23]])

	a.segment("p3-vine", "warmup", [["t", 10, 0.9, 33, 14], ["v", 13, 22], ["t", 34, 0.9, 33, 13], ["b", 27, 24], ["t", 62, 1.0, 34, 14], ["b", 52, 23]])

	a.segment("p-tail", "warmup", [["t", 8, 0.9, 33, 13], ["b", 15, 24], ["s", 26, 1.0, 7], ["t", 38, 0.9, 34, 13], ["b", 31, 24], ["t", 52, 1.0, 34, 14], ["v", 46, 23]])
	scenes.append({"id": "prologue", "name": "prologue", "chapter": "prologue", "x0": s0, "x1": a.x, "time": [0.1, 0.205], "overcast": [0.0, 0.0], "rain": [0.0, 0.0], "storm": [0.0, 0.0], "clearing": [0.0, 0.0], "rainbow": [0.0, 0.0], "wind": [0.0, 0.0]})
