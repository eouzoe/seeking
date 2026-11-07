shader_type canvas_item;

uniform vec4 body : source_color = vec4(0.85, 0.82, 0.9, 1.0);
uniform vec4 shade : source_color = vec4(0.55, 0.5, 0.65, 1.0);
uniform vec4 rim : source_color = vec4(1.0, 0.85, 0.6, 1.0);
uniform float rim_power = 1.4;
uniform float px_per_unit = 24.0;
uniform float edge_units = 2.2;
uniform float speed = 0.35;

uniform vec2 girl = vec2(0.0, 100.0);
uniform vec2 impact = vec2(0.0, 0.0);
uniform float impact_age = 99.0;

varying vec2 world_px;

void vertex() {
	world_px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 w = world_px / px_per_unit;
	float t = TIME * speed;

	float edge = (fbm(vec2(w.x * 0.08 + t * 0.2, 0.0)) - 0.5) * edge_units * 2.0 + fbm(vec2(w.x * 0.35 - t, 3.0)) * 0.8;

	float near = exp(-pow((w.x - girl.x) / 2.2, 2.0)) * smoothstep(4.0, 0.0, girl.y);
	edge += near * 1.6;

	float ring_r = impact_age * 7.0;
	float dx = abs(w.x - impact.x);
	float ring = exp(-pow((dx - ring_r) * 0.9, 2.0)) * exp(-impact_age * 0.9);
	edge -= ring * 1.8;
	float depth = w.y - edge;
	float a = smoothstep(-0.4, 0.6, depth);
	float puff = fbm(w * vec2(0.18, 0.35) + vec2(t * 0.6, 0.0));
	vec3 c = mix(body.rgb, shade.rgb, clamp(depth * 0.12 + (0.5 - puff) * 0.6, 0.0, 1.0));

	float lit = exp(-max(depth, 0.0) * 1.2) * smoothstep(-0.4, 0.3, depth);
	c += rim.rgb * lit * rim_power;
	c += rim.rgb * ring * lit * 1.5;
	COLOR = vec4(c, a);
}
