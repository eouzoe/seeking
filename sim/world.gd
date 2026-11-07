extends RefCounted

const T := preload("res://sim/tune.gd")
const M := preload("res://sim/sim_math.gd")

const SCORE_ATTACH := 10.0
const SCORE_REST := 40.0

var tick := 0
var rng_s := 0
var time := 0.0
var started := false
var x := 0.0
var y := 0.0
var vx := 0.0
var vy := 0.0
var angle := 0.0
var omega := 0.0
var mode := "perch"
var crouch := 0.0
var prev_hold := false
var target := -1

var h_state := "idle"
var h_anchor := -1
var h_tip := 0.0
var h_rest := 0.0
var h_dx := 1.0
var h_dy := 0.0
var h_L := 0.0
var h_ax := 0.0
var h_ay := 0.0
var attaches := 0
var rests := 0
var bumps := 0
var score := 0.0
var max_x := 0.0
var segment := -1
var cause: Variant = null
var bump_t := -9.0
var save := 0

static func last_save(c: Dictionary) -> int:
	var pads: Array = c["pads"]
	for i in range(pads.size() - 1, -1, -1):
		if pads[i].get("save", false):
			return i
	return 0

static func _segment_at(c: Dictionary, px: float) -> int:
	var s := -1
	var segs: Array = c["segments"]
	for i in segs.size():
		if px >= float(segs[i]["x0"]):
			s = i
	return s

static func create(c: Dictionary, from_pad := 0) -> RefCounted:
	var w = load("res://sim/world.gd").new()
	var has_pad := from_pad > 0
	var sx: float
	var sy: float
	if has_pad:
		sx = float(c["pads"][from_pad]["x"])
		sy = float(c["pads"][from_pad]["y"])
	else:
		sx = float(c["start"]["x"])
		sy = float(c["start"]["y"])
	w.rng_s = int(c["seed"]) & 0xFFFFFFFF
	w.x = sx
	w.y = sy + T.BODY_R
	w.max_x = sx
	w.segment = _segment_at(c, sx) if has_pad else -1
	w.save = from_pad if has_pad else 0
	return w

func to_dict() -> Dictionary:
	return {
		"tick": tick, "rng": {"s": rng_s}, "time": time, "started": started,
		"x": x, "y": y, "vx": vx, "vy": vy, "angle": angle, "omega": omega,
		"mode": mode, "crouch": crouch, "prevHold": prev_hold, "target": target,
		"hook": {"state": h_state, "anchor": h_anchor, "tip": h_tip, "rest": h_rest, "dx": h_dx, "dy": h_dy, "L": h_L, "ax": h_ax, "ay": h_ay},
		"attaches": attaches, "rests": rests, "bumps": bumps, "score": score,
		"maxX": max_x, "segment": segment, "cause": cause, "bumpT": bump_t, "save": save,
	}

func _pick_target(c: Dictionary) -> void:
	var best := -1
	var best_score := INF
	var anchors: Array = c["anchors"]
	for i in anchors.size():
		var a: Dictionary = anchors[i]
		var dx: float = float(a["x"]) - x
		var dy: float = float(a["y"]) - y
		if dx < -10.0 or dx > T.HOOK_RANGE:
			continue
		var d := M.hypot(dx, dy)
		if d > T.HOOK_RANGE:
			continue
		var s := d + (8.0 if dx < -1.0 else 0.0) + (4.0 if dy < -1.0 else 0.0) - M.js_min(M.js_max(dx, 0.0), 6.0) * 0.4
		if s < best_score:
			best_score = s
			best = i
	target = best

func _shoot(c: Dictionary, ev: Array) -> void:
	if h_state == "stuck":
		return
	_pick_target(c)
	h_tip = 0.0
	if target < 0:
		h_state = "miss"
		h_dx = 0.7 if vx >= 0.0 else -0.7
		h_dy = 0.7
		ev.append({"type": "miss"})
		return
	h_state = "shoot"
	h_anchor = target
	ev.append({"type": "shoot", "anchor": target})

func _detach(ev: Array, boost := true) -> void:
	var rx := x - h_ax
	var ry := y - h_ay
	if boost:
		vx *= T.RELEASE_BOOST
		vy *= T.RELEASE_BOOST
		if vy > 0.0:
			vy += T.RELEASE_UP
	var sp := M.hypot(vx, vy)
	omega = 0.0
	h_state = "retract"
	h_tip = M.hypot(rx, ry)
	var div := h_tip if h_tip != 0.0 else 1.0
	h_dx = -rx / div
	h_dy = -ry / div
	mode = "air"
	ev.append({"type": "release", "speed": sp, "anchor": h_anchor})

func _die(why: String, ev: Array) -> void:
	if mode == "dead":
		return
	mode = "dead"
	cause = why
	h_state = "idle"
	ev.append({"type": "die", "cause": why, "x": x, "y": y, "vx": vx, "vy": vy})

func _bump_rect(cx: float, cy: float, hw: float, hh: float, R: float) -> bool:
	var qx := M.js_max(cx - hw, M.js_min(x, cx + hw))
	var qy := M.js_max(cy - hh, M.js_min(y, cy + hh))
	var dx := x - qx
	var dy := y - qy
	var d := M.hypot(dx, dy)
	if d >= R:
		return false
	if d < 1e-6:
		var px := hw - absf(x - cx)
		var py := hh - absf(y - cy)
		if px < py:
			dx = M.sign_or_one(x - cx)
			dy = 0.0
		else:
			dx = 0.0
			dy = M.sign_or_one(y - cy)
		d = 1.0
		x += dx * (px + R)
		y += dy * (py + R)
	else:
		dx /= d
		dy /= d
		x += dx * (R - d)
		y += dy * (R - d)
	var vn := vx * dx + vy * dy
	if vn < 0.0:
		var out := M.js_max(T.BUMP_MIN, -vn * T.BUMP_REST)
		vx -= vn * dx
		vy -= vn * dy
		vx += dx * out
		vy += dy * out
	return true

func step(c: Dictionary, hold: bool, ev: Array) -> void:
	var dt := T.DT
	tick += 1
	if mode == "dead":
		prev_hold = hold
		return
	if started:
		time += dt

	if hold and not prev_hold:
		if mode == "perch":
			if crouch <= 0.0:
				crouch = T.JUMP_DELAY
				started = true
				ev.append({"type": "crouch"})
		else:
			_shoot(c, ev)
	if not hold and prev_hold:
		if h_state == "stuck":
			_detach(ev)
		elif h_state == "shoot":
			h_state = "retract"
	prev_hold = hold

	if mode == "perch":
		_pick_target(c)
		if crouch > 0.0:
			crouch -= dt
			if crouch <= 0.0:
				mode = "air"
				vx = T.JUMP_VX
				vy = T.JUMP_VY
				ev.append({"type": "jump"})
				if hold:
					_shoot(c, ev)
		return

	if h_state == "shoot":
		var an: Dictionary = c["anchors"][h_anchor]
		var tx0: float = float(an["x"])
		var ty0: float = float(an["y"])
		var dx := tx0 - x
		var dy := ty0 - y
		var d := M.hypot(dx, dy)
		h_tip += T.HOOK_SPEED * dt
		h_dx = dx / d
		h_dy = dy / d
		if d > T.HOOK_RANGE * 1.25:
			h_state = "retract"
		elif h_tip >= d:
			h_state = "stuck"
			h_L = M.js_min(T.ROPE_MAX, M.js_max(T.ROPE_MIN, d))
			h_rest = M.js_min(h_L, T.ROPE_REST)
			h_ax = tx0
			h_ay = ty0
			mode = "swing"
			attaches += 1
			score += SCORE_ATTACH
			ev.append({"type": "attach", "anchor": h_anchor, "x": tx0, "y": ty0, "speed": M.hypot(vx, vy)})
	elif h_state == "retract":
		h_tip -= T.HOOK_SPEED * 1.4 * dt
		if h_tip <= 0.0:
			h_tip = 0.0
			h_state = "idle"
	elif h_state == "miss":
		h_tip += 40.0 * dt
		if h_tip > 3.2:
			h_state = "retract"
	if h_state != "stuck" and h_state != "shoot":
		_pick_target(c)

	vy -= T.GRAVITY * dt

	if h_state == "stuck":
		var rx := x - h_ax
		var ry := y - h_ay
		var d := M.hypot(rx, ry)
		if d == 0.0:
			d = 1.0
		var nx := rx / d
		var ny := ry / d
		var tx := -ny
		var ty := nx
		var vt := vx * tx + vy * ty
		var taut := d > h_L - 0.05
		if h_L > h_rest:
			h_L = M.js_max(h_rest, h_L - T.ELASTIC_RATE * dt)
		elif hold and taut and h_L > T.ROPE_MIN:
			var nL := M.js_max(T.ROPE_MIN, h_L - T.PUMP_RATE * dt)
			var k := h_L / nL
			vx += tx * vt * (k - 1.0)
			vy += ty * vt * (k - 1.0)
			vt *= k
			h_L = nL
		if taut and ny < 0.2 and absf(vt) > 0.5:
			var a := signf(vt) * T.SWING_ASSIST * dt
			vx += tx * a
			vy += ty * a

	var drag := 1.0 - T.AIR_DRAG * dt
	vx *= drag
	vy *= drag
	var sp := M.hypot(vx, vy)
	if sp > T.MAX_SPEED:
		vx *= T.MAX_SPEED / sp
		vy *= T.MAX_SPEED / sp
	x += vx * dt
	y += vy * dt

	if h_state == "stuck":
		var rx := x - h_ax
		var ry := y - h_ay
		var d := M.hypot(rx, ry)
		if d > h_L:
			var nx := rx / d
			var ny := ry / d
			x = h_ax + nx * h_L
			y = h_ay + ny * h_L
			var vr := vx * nx + vy * ny
			if vr > 0.0:
				vx -= vr * nx
				vy -= vr * ny
		var ta := atan2(-(h_ax - x), h_ay - y)
		angle += M.wrap_angle(ta - angle) * (1.0 - exp(-dt * 22.0))
	else:
		angle += M.wrap_angle(0.0 - angle) * (1.0 - exp(-dt * 6.0))
	angle = M.wrap_angle(angle)
	if x > max_x:
		max_x = x

	var segs: Array = c["segments"]
	var nxt := segment + 1
	if nxt < segs.size() and x >= float(segs[nxt]["x0"]):
		segment = nxt
		ev.append({"type": "segment", "index": nxt, "kind": segs[nxt]["kind"]})

	var R := T.BODY_R

	var hit := ""
	var trunks: Array = c["trunks"]
	for i in trunks.size():
		if hit != "":
			break
		var t: Dictionary = trunks[i]
		var tw: float = float(t["w"])
		var txp: float = float(t["x"])
		if not t["solid"] or absf(txp - x) > tw + R + 1.0:
			continue
		var top: float = float(t["top"])
		var hh := (top + 60.0) / 2.0
		if _bump_rect(txp, top - hh, tw, hh, R):
			hit = "trunk"
	var rocks: Array = c["rocks"]
	for i in rocks.size():
		if hit != "":
			break
		var k: Dictionary = rocks[i]
		var khw: float = float(k["hw"])
		var kx: float = float(k["x"])
		if absf(kx - x) > khw + R + 1.0:
			continue
		if _bump_rect(kx, float(k["y"]), khw, float(k["hh"]), R):
			if k["deadly"]:
				_die("crash", ev)
				return
			hit = "rock"
	if hit != "":
		var spd := M.hypot(vx, vy)
		if h_state == "stuck":
			_detach(ev, false)
		elif h_state == "shoot":
			h_state = "retract"
		if time - bump_t > 0.25:
			bumps += 1
			ev.append({"type": "bump", "x": x, "y": y, "speed": spd, "what": hit})
		bump_t = time

	var pads: Array = c["pads"]
	for i in pads.size():
		var p: Dictionary = pads[i]
		var ppx: float = float(p["x"])
		var ppy: float = float(p["y"])
		if absf(x - ppx) < float(p["w"]) * 0.5 and y - R <= ppy + 0.1 and y > ppy - 1.4 and vy <= 0.5:
			var sp2 := M.hypot(vx, vy)
			mode = "perch"
			crouch = 0.0
			vx = 0.0
			vy = 0.0
			omega = 0.0
			angle = 0.0
			y = ppy + R
			h_state = "idle"
			h_tip = 0.0
			rests += 1
			score += SCORE_REST
			ev.append({"type": "pad", "pad": i, "x": x, "y": y, "speed": sp2})
			if p.get("save", false) and i != save:
				save = i
				ev.append({"type": "save", "pad": i, "x": x, "y": y, "time": time, "score": score})
			return
	if y < T.CLOUD_Y + 0.15:
		_die("fall", ev)
