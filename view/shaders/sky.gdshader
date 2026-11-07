shader_type canvas_item;

uniform vec4 zenith : source_color = vec4(0.3, 0.45, 0.75, 1.0);
uniform vec4 horizon : source_color = vec4(1.0, 0.85, 0.65, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.8, 0.5, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform vec2 sun_uv = vec2(0.7, 0.35);
uniform float sun_amount = 1.0;
uniform float horizon_uv = 0.75;
uniform float aspect = 1.7778;
uniform float overcast = 0.0;
uniform float rainbow = 0.0;
uniform float stars = 0.0;
global uniform float flash;

void fragment() {
	float h = clamp((UV.y - 0.0) / max(horizon_uv, 0.05), 0.0, 1.0);
	vec3 c = mix(zenith.rgb, horizon.rgb, pow(h, 1.6));
	vec2 d = (UV - sun_uv) * vec2(aspect, 1.0);
	float r = length(d);

	c += glow_color.rgb * 0.32 * exp(-r * 3.2) * sun_amount;

	float disc = smoothstep(0.045, 0.03, r);

	c += sun_color.rgb * (disc * 2.2 + exp(-r * 22.0) * 0.6) * sun_amount;

	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(g) * vec3(0.78, 0.82, 0.9), overcast * 0.8);

	vec2 rc = vec2(1.0 - sun_uv.x, horizon_uv + 0.35);
	float rr = length((UV - rc) * vec2(aspect, 1.0));
	float band = (rr - 0.55) / 0.07;
	if (band > 0.0 && band < 1.0 && UV.y < horizon_uv) {
		vec3 bow = clamp(abs(fract(band * 0.85 + vec3(0.0, 0.66, 0.33)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
		c = mix(c, c + bow * 0.35, rainbow * sin(band * 3.14159) * smoothstep(horizon_uv, horizon_uv - 0.3, UV.y));
	}

	if (stars > 0.001) {
		vec2 g = UV * vec2(aspect, 1.0) * 90.0;
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5;
		float h = fract(sin(dot(id, vec2(12.9898, 78.233))) * 43758.5453);
		vec2 off = vec2(fract(h * 7.31), fract(h * 3.17)) - 0.5;
		float d = length(f - off * 0.7);
		float tw = 0.65 + 0.35 * sin(TIME * (1.0 + h * 2.0) + h * 40.0);
		float s = smoothstep(0.08 + h * 0.06, 0.0, d) * step(0.86, h) * tw;
		c += vec3(0.85, 0.9, 1.0) * s * stars * (1.0 - smoothstep(0.0, horizon_uv, UV.y) * 0.85) * (1.0 - overcast);
	}

	c += vec3(0.8, 0.85, 1.0) * flash * 1.8;
	COLOR = vec4(c, 1.0);
}
