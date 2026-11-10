shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
// 길 아래 깊은 곳의 격자 평면. 곡 속도에 맞춰 카메라 쪽으로 흐른다.
uniform float scroll = 0.0;
uniform float cell = 8.0;
uniform float pulse = 0.0;
uniform vec3 tone_left : source_color = vec3(0.56, 0.48, 1.0);
uniform vec3 tone_right : source_color = vec3(1.0, 0.31, 0.62);
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid(float v) {
	float q = abs(fract(v) - 0.5);          // 선 위에서 0.5
	float fw = fwidth(v) * 1.5;
	return smoothstep(0.5 - fw - 0.012, 0.5 - 0.012, q);
}

void fragment() {
	vec2 g = vec2(wp.x, wp.z + scroll) / cell;
	float lines = max(grid(g.x), grid(g.y));
	float dist = length(wp.xz - vec2(0.0, 8.0));
	float fade = exp(-dist * 0.012) * smoothstep(6.0, 30.0, dist);
	// 먼 곳은 선이 뭉개져 반짝이므로 줄인다
	fade *= 1.0 - smoothstep(0.25, 0.6, max(fwidth(g.x), fwidth(g.y)));
	vec3 tone = mix(tone_left, tone_right, clamp(wp.x / 120.0 + 0.5, 0.0, 1.0));
	ALBEDO = tone * lines * (0.035 + pulse * 0.02) * fade;
}
