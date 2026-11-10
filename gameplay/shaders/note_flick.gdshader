shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Flick: +X 를 가리키는 세 겹 쐐기 + 뒤로 끌리는 빛줄기. 왼쪽은 mirror = -1.
uniform float depth = 34.0;
uniform vec3 color : source_color = vec3(0.3, 1.0, 0.4);
uniform float energy = 2.0;
uniform float alpha = 1.0;
uniform float mirror = 1.0;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float chevron(vec2 p, float x0, float thick) {
	float d = abs((p.x - x0) + abs(p.y) * 1.1) - thick;
	float fw = fwidth(d) * 1.2;
	return 1.0 - smoothstep(-fw, fw, d);
}

void fragment() {
	// p.x: -1.5 ~ 1.5, p.y: -0.5 ~ 0.5
	vec2 p = vec2((UV.x - 0.5) * 3.0 * mirror, UV.y - 0.5);
	float mask = 1.0 - smoothstep(0.4, 0.44, abs(p.y));
	// 쐐기가 진행 방향으로 차례로 밝아진다
	float t = fract(TIME * 1.6);
	float c1 = chevron(p, 1.0, 0.1);
	float c2 = chevron(p, 0.52, 0.075);
	float c3 = chevron(p, 0.1, 0.055);
	float w1 = 0.75 + 0.25 * smoothstep(0.5, 0.9, t);
	float w2 = 0.5 + 0.3 * smoothstep(0.25, 0.6, t) * (1.0 - smoothstep(0.7, 1.0, t));
	float w3 = 0.28 + 0.3 * smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.4, 0.7, t));
	float a = max(max(c1 * w1, c2 * w2), c3 * w3) * mask;
	float tail = smoothstep(-1.45, 0.6, p.x) * exp(-abs(p.y) * 11.0) * 0.3 * step(p.x, 0.95);
	float halo = exp(-length(vec2(p.x - 0.6, p.y * 1.6)) * 3.2) * 0.16;
	vec3 c = mix(color, vec3(max(color.r, max(color.g, color.b))), c1 * 0.5) * energy;
	ALBEDO = c;
	ALPHA = clamp(a + tail + halo, 0.0, 1.0) * alpha * smoothstep(depth, depth * 0.74, max(-wp.z, 0.0));
}
