shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D grade : source_color, repeat_disable, filter_linear;
uniform float grade_amount = 0.55;
uniform vec2 sun_uv = vec2(0.7, 0.3);
uniform vec4 ray_color : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float ray_amount = 0.6;
uniform float ray_threshold = 0.85;
uniform float ray_decay = 0.965;
uniform float vignette = 0.35;
global uniform float flash;
uniform float chroma = 0.012;
uniform float grain = 0.035;

const int SAMPLES = 48;

void fragment() {
	vec3 base = texture(screen, SCREEN_UV).rgb;
	vec3 lw = vec3(0.2126, 0.7152, 0.0722);
	float lum = dot(min(base, vec3(1.0)), lw);
	vec3 mapped = texture(grade, vec2(clamp(lum, 0.0, 1.0), 0.5)).rgb;
	vec3 tint = mapped / max(dot(mapped, lw), 0.04);
	vec3 c = mix(base, base * tint, grade_amount);

	if (ray_amount > 0.0) {
		vec2 delta = (SCREEN_UV - sun_uv) / float(SAMPLES) * 0.9;
		vec2 uv = SCREEN_UV;
		float illum = 1.0;
		vec3 rays = vec3(0.0);
		for (int i = 0; i < SAMPLES; i++) {
			uv -= delta;
			vec3 s = textureLod(screen, uv, 1.5).rgb;
			float b = max(dot(s, vec3(0.333)) - ray_threshold, 0.0);
			rays += s * b * illum;
			illum *= ray_decay;
		}
		c += rays / float(SAMPLES) * ray_color.rgb * ray_amount * 4.0;
	}

	vec2 v = SCREEN_UV - 0.5;
	vec2 ca = v * dot(v, v) * chroma;
	c.r += (texture(screen, SCREEN_UV + ca).r - base.r) * 0.8;
	c.b += (texture(screen, SCREEN_UV - ca).b - base.b) * 0.8;

	float n = fract(sin(dot(SCREEN_UV * vec2(1280.0, 720.0) + fract(TIME * 7.13) * 91.7, vec2(12.9898, 78.233))) * 43758.5453);
	float l2 = dot(c, vec3(0.333));
	c += (n - 0.5) * grain * (1.0 - smoothstep(0.2, 1.0, l2));

	c *= 1.0 - dot(v, v) * vignette * 2.0;
	COLOR = vec4(c, 1.0);
}
