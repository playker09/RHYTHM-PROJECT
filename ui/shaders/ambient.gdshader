shader_type canvas_item;
// 메뉴 공통 배경: 천천히 떠다니는 빛 덩어리 + 사선 헤어라인 + 비네트 + 그레인(밴딩 방지).
uniform vec3 ink : source_color = vec3(0.03, 0.027, 0.06);
uniform vec3 tint_a : source_color = vec3(0.56, 0.48, 1.0);
uniform vec3 tint_b : source_color = vec3(1.0, 0.31, 0.62);
uniform float strength = 0.5;
uniform float pulse = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float blob(vec2 p, vec2 c, float k) {
	vec2 d = p - c;
	return exp(-dot(d, d) * k);
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = res.x / res.y;
	vec2 p = vec2(UV.x * aspect, UV.y);
	float t = TIME * 0.11;
	// 사인 왜곡으로 격자 없는 유기적인 모양을 만든다
	vec2 w = p + 0.16 * vec2(sin(p.y * 3.1 + t * 1.3), cos(p.x * 2.7 - t));
	float a = blob(w, vec2(aspect * (0.2 + 0.1 * sin(t * 0.7)), 0.18 + 0.1 * cos(t)), 3.2)
		+ blob(w, vec2(aspect * (0.52 + 0.14 * cos(t * 0.5)), 0.05 + 0.08 * sin(t * 0.9)), 5.0) * 0.6;
	float b = blob(w, vec2(aspect * (0.92 + 0.08 * sin(t * 0.6)), 0.82 + 0.12 * cos(t * 0.8)), 2.8)
		+ blob(w, vec2(aspect * (0.68 + 0.12 * sin(t)), 1.05), 4.5) * 0.65;
	vec3 c = ink;
	c += tint_a * a * strength * 0.2 * (1.0 + pulse * 0.28);
	c += tint_b * b * strength * 0.16 * (1.0 + pulse * 0.28);
	// 사선 헤어라인
	float d = fract((FRAGCOORD.x + FRAGCOORD.y * 0.28) / 64.0);
	c += vec3(0.012) * smoothstep(1.0 / 32.0, 0.0, d);
	// 비네트
	vec2 v = UV - 0.5;
	c *= 1.0 - dot(v, v) * 0.9;
	// 그레인
	c += (hash(FRAGCOORD.xy + fract(TIME) * 91.0) - 0.5) * 0.016;
	COLOR = vec4(c, 1.0);
}
