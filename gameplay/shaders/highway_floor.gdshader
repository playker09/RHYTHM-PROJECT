shader_type spatial;
render_mode unshaded, cull_disabled;
// 하이웨이 바닥: 검은 유리 + 레인 선 + 실제 박자에 맞춰 흐르는 박자선/마디선 + 일식 반사 + 누른 레인 빛.
uniform float depth = 34.0;
uniform float lane_w = 1.1;
uniform float half_w = 2.2;
uniform float next_beat = 0.0;     // 판정선에서 다음 박까지 거리 (m)
uniform float beat_len = 8.0;      // 박 간격 (m)
uniform float next_bar = 0.0;      // 다음 마디까지 거리 (m)
uniform float pulse = 0.0;
uniform vec4 press = vec4(0.0);
uniform vec3 tone_left : source_color = vec3(0.56, 0.48, 1.0);
uniform vec3 tone_right : source_color = vec3(1.0, 0.31, 0.62);
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float line(float dist, float w) {
	float f = fwidth(dist) * 1.3;
	return 1.0 - smoothstep(w, w + f, dist);
}

void fragment() {
	float z = wp.z;
	float d = max(-z, 0.0);
	float u = clamp(wp.x / (half_w * 2.0) + 0.5, 0.0, 1.0);
	vec3 tone = mix(tone_left, tone_right, u);
	float far_soft = 1.0 - smoothstep(10.0, depth, d) * 0.6;

	// 유리 바탕: 가운데가 살짝 밝고, 먼 쪽은 일식 빛을 받아 물든다
	vec3 c = vec3(0.0022, 0.002, 0.007);
	c += tone * 0.004 * (1.0 - abs(u - 0.5) * 1.4);
	c += tone * smoothstep(8.0, depth, d) * (0.02 + pulse * 0.012);
	// 중앙으로 내려오는 일식 반사 띠
	c += mix(tone, vec3(1.0), 0.5) * exp(-abs(wp.x) * 1.6) * smoothstep(4.0, depth, d) * (0.012 + pulse * 0.014);

	// 레인 선
	float lx = wp.x / lane_w;
	float dl = abs(fract(lx + 0.5) - 0.5) * lane_w;
	c += vec3(0.5, 0.52, 0.95) * line(dl, 0.008) * 0.14 * far_soft;
	// 레인 선 옆 옅은 번짐
	c += vec3(0.4, 0.4, 0.9) * exp(-dl * 26.0) * 0.012 * far_soft;

	// 박자선 / 마디선 (판정선 위쪽에만)
	if (z < 0.0) {
		float q = fract((d - next_beat) / beat_len);
		float beat_d = min(q, 1.0 - q) * beat_len;
		float qb = fract((d - next_bar) / (beat_len * 4.0));
		float bar_d = min(qb, 1.0 - qb) * beat_len * 4.0;
		c += vec3(0.4, 0.42, 0.8) * line(beat_d, 0.008) * 0.05 * far_soft;
		c += mix(tone, vec3(1.0), 0.55) * (line(bar_d, 0.014) * 0.2 + exp(-bar_d * 5.0) * 0.022) * far_soft;
	}

	// 판정선 주변 빛
	c += vec3(0.5, 0.75, 1.0) * exp(-abs(z) * 2.0) * (0.03 + pulse * 0.05);

	// 누른 레인: 판정선에서 안쪽으로 번지는 빛
	float id = clamp(floor(lx + 2.0), 0.0, 3.0);
	float pr = id < 0.5 ? press.x : (id < 1.5 ? press.y : (id < 2.5 ? press.z : press.w));
	float cx = 1.0 - pow(abs(fract(lx) - 0.5) * 2.0, 4.0);
	c += vec3(0.5, 0.86, 1.0) * pr * cx * exp(-d * 0.26) * exp(-max(z, 0.0) * 2.5) * 0.2;

	// 카메라 아래쪽은 어둡게 가라앉힌다
	c *= 1.0 - smoothstep(1.6, 6.0, z) * 0.75;

	ALBEDO = c;
	ALPHA = smoothstep(depth, depth * 0.7, d) * 0.96;
}
