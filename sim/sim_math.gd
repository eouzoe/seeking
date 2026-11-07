extends RefCounted

const K_TAU := PI * 2.0

static func hypot(x: float, y: float) -> float:
	return sqrt(x * x + y * y)

static func is_neg_zero(x: float) -> bool:
	if x != 0.0:
		return false
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, x)
	return (b[7] & 0x80) != 0

static func js_round(x: float) -> float:
	if is_nan(x) or is_inf(x):
		return x
	var f := floorf(x)
	if f == x:
		return x
	if x >= -0.5 and x < 0.0:
		return -0.0
	if x > 0.0 and x < 0.5:
		return 0.0
	var d := x - f
	return f + 1.0 if d >= 0.5 else f

static func wrap_angle(a: float) -> float:
	return a - js_round(a / K_TAU) * K_TAU

static func sign_or_one(x: float) -> float:
	if x > 0.0:
		return 1.0
	if x < 0.0:
		return -1.0
	return 1.0

static func js_max(a: float, b: float) -> float:
	if a > b:
		return a
	if b > a:
		return b
	if a == 0.0 and b == 0.0:
		return b if is_neg_zero(a) else a
	return a

static func js_min(a: float, b: float) -> float:
	if a < b:
		return a
	if b < a:
		return b
	if a == 0.0 and b == 0.0:
		return a if is_neg_zero(a) else b
	return a
