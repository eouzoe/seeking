extends RefCounted

var x := 0.0
var trunks: Array = []
var anchors: Array = []
var rocks: Array = []
var pads: Array = []
var segments: Array = []
var errors: PackedStringArray = []

func _init(start_x := 0.0) -> void:
	x = start_x

func _nearest_trunk(px: float, py: float, on: String) -> int:
	var best := -1
	var bd := INF
	for i in trunks.size():
		var t: Dictionary = trunks[i]
		if t["solid"]:
			continue
		var dx := absf(float(t["x"]) - px)
		if on == "branch":
			if dx < 1.5 or dx > 18.0 or py > float(t["top"]) + 2.0:
				continue
		elif dx > float(t["span"]):
			continue
		if dx < bd:
			bd = dx
			best = i
	return best

func segment(id: String, kind: String, items: Array) -> void:
	var x0 := x
	var last := 0.0
	for it: Array in items:
		if it[0] == "t":
			trunks.append({"x": x0 + float(it[1]), "w": float(it[2]), "top": float(it[3]), "span": float(it[4]), "solid": false})
		elif it[0] == "s":
			trunks.append({"x": x0 + float(it[1]), "w": float(it[2]), "top": float(it[3]), "span": 0.0, "solid": true})
	for it: Array in items:
		var k: String = it[0]
		if k == "b" or k == "v":
			var on := "branch" if k == "b" else "vine"
			var ax := x0 + float(it[1])
			var ay := float(it[2])
			var tr := _nearest_trunk(ax, ay, on)
			if tr < 0:
				errors.append("%s: anchor (%s, %s) %s has no trunk to grow from" % [id, ax, ay, on])
				continue
			anchors.append({"x": ax, "y": ay, "on": on, "trunk": tr})
			last = maxf(last, float(it[1]))
		elif k == "r":
			rocks.append({"x": x0 + float(it[1]), "y": float(it[2]), "hw": float(it[3]), "hh": float(it[4]), "deadly": it.size() > 5 and bool(it[5])})
		elif k == "p":
			var px := x0 + float(it[1])
			var tr := _nearest_trunk(px, float(it[2]), "branch")
			if tr < 0:
				errors.append("%s: pad (%s, %s) has no trunk" % [id, px, it[2]])
				continue
			pads.append({"x": px, "y": float(it[2]), "w": float(it[3]), "trunk": tr, "save": it.size() > 4 and bool(it[4])})
			last = maxf(last, float(it[1]))
	segments.append({"id": id, "kind": kind, "x0": x0, "x1": x0 + last})
	x = x0 + last

func finish(id: String, seed_v: int, start: Vector2) -> Dictionary:
	var sorted := anchors.duplicate()
	sorted.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["x"]) < float(q["x"]))
	var last_pad: Dictionary = pads[pads.size() - 1]
	return {
		"id": id, "seed": seed_v, "start": {"x": start.x, "y": start.y},
		"trunks": trunks, "anchors": sorted, "rocks": rocks, "pads": pads, "segments": segments,
		"length": float(last_pad["x"]) - float(last_pad["w"]) / 2.0 + 2.0,
	}
