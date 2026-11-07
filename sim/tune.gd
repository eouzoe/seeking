extends RefCounted

const TICK_HZ := 120.0
const DT := 1.0 / TICK_HZ

const GRAVITY := 36.0
const AIR_DRAG := 0.04
const MAX_SPEED := 36.0
const BODY_R := 0.55
const JUMP_VX := 6.5
const JUMP_VY := 13.0
const JUMP_DELAY := 0.07
const HOOK_RANGE := 26.0
const HOOK_SPEED := 150.0
const ROPE_MIN := 2.6
const ROPE_MAX := 30.0
const ROPE_REST := 14.0
const ELASTIC_RATE := 16.0
const PUMP_RATE := 1.4
const SWING_ASSIST := 5.0
const RELEASE_BOOST := 1.07
const RELEASE_UP := 2.2
const BUMP_REST := 0.45
const BUMP_MIN := 4.0
const CLOUD_Y := 0.0
