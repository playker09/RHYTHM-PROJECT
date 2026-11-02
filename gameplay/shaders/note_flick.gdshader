shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Flick: +X 를 가리키는 겹 쐐기. 뒤로 갈수록 희미해진다. 왼쪽은 노드를 180도 돌린다.
uniform float depth = 34.0;
uniform vec3 color : source_color = vec3(0.3, 1.0, 0.4);
uniform float energy = 1.8;
uniform float alpha = 1.0;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float chevron(vec2 p, float x0, float thick) {
	float d = abs((p.x - x0) + abs(p.y) * 1.35) - thick;
	float fw = fwidth(d) * 1.2;
	return 1.0 - smoothstep(-fw, fw, d);
}

void fragment() {
	vec2 p = vec2((UV.x - 0.5) * 3.0, (UV.y - 0.5) * 1.0);
	float mask = 1.0 - smoothstep(0.44, 0.47, abs(p.y));
	float c1 = chevron(p, 1.15, 0.11);
	float c2 = chevron(p, 0.6, 0.075) * 0.62;
	float c3 = chevron(p, 0.13, 0.05) * 0.32;
	float a = max(max(c1, c2), c3) * mask;
	float tail = smoothstep(-1.45, 0.9, p.x) * exp(-abs(p.y) * 9.0) * 0.25 * step(p.x, 1.1);
	vec3 c = mix(color, vec3(1.0), c1 * 0.35) * energy;
	ALBEDO = c;
	ALPHA = clamp(a + tail, 0.0, 1.0) * alpha * smoothstep(depth, depth * 0.72, max(-wp.z, 0.0));
}
