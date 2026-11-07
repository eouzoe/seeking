shader_type canvas_item;

global uniform vec2 wind;
uniform float amount = 1.0;

void vertex() {
	vec2 wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float ph = wp.x * 0.004 + wp.y * 0.003;
	float s = sin(TIME * 1.3 + ph) * 0.5 + sin(TIME * 2.9 + ph * 1.7) * 0.25;
	float w = length(wind);
	VERTEX.x += (wind.x * 22.0 + s * (2.5 + w * 16.0)) * amount;
	VERTEX.y += s * (1.0 + w * 4.0) * amount;
}
