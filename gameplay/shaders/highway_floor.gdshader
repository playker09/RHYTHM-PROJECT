shader_type spatial;
render_mode unshaded, cull_disabled;
// 하이웨이 바닥: 어두운 유리 + 레인 선 + 실제 박자에 맞춰 흐르는 박자선 + 누른 레인 빛.
uniform float depth = 34.0;
uniform float lane_w = 1.1;
uniform float half_w = 2.2;
uniform float next_beat = 0.0;     // 판정선에서 다음 박까지 거리 (m)
uniform float beat_len = 8.0;      // 박 간격 (m)
uniform float next_bar = 0.0;      // 다음 마디까지 거리 (m)
uniform float pulse = 0.0;
uniform vec4 press = vec4(0.0);
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
	vec3 c = mix(vec3(0.0035, 0.004, 0.011), vec3(0.008, 0.006, 0.024), smoothstep(6.0, 32.0, d));

	// 레인 선 (중앙은 조금 더 밝게)
	float lx = wp.x / lane_w;
	float dl = abs(fract(lx + 0.5) - 0.5) * lane_w;
	float far_soft = 1.0 - smoothstep(10.0, 34.0, d) * 0.65;
	c += vec3(0.42, 0.5, 0.9) * line(dl, 0.01) * 0.16 * far_soft;

	// 박자선 / 마디선 (판정선 위쪽에만)
	if (z < 0.0) {
		float q = fract((d - next_beat) / beat_len);
		float beat_d = min(q, 1.0 - q) * beat_len;
		float qb = fract((d - next_bar) / (beat_len * 4.0));
		float bar_d = min(qb, 1.0 - qb) * beat_len * 4.0;
		c += vec3(0.36, 0.4, 0.75) * line(beat_d, 0.01) * 0.05 * far_soft;
		c += vec3(0.75, 0.72, 1.0) * line(bar_d, 0.016) * 0.18 * far_soft;
	}

	// 판정선 주변 빛
	c += vec3(0.25, 0.7, 0.85) * exp(-abs(z) * 2.2) * (0.035 + pulse * 0.06);

	// 누른 레인: 판정선에서 안쪽으로 번지는 빛
	float id = clamp(floor(lx + 2.0), 0.0, 3.0);
	float pr = id < 0.5 ? press.x : (id < 1.5 ? press.y : (id < 2.5 ? press.z : press.w));
	float cx = 1.0 - pow(abs(fract(lx) - 0.5) * 2.0, 4.0);
	c += vec3(0.4, 0.85, 1.0) * pr * cx * exp(-d * 0.3) * exp(-max(z, 0.0) * 2.5) * 0.22;

	ALBEDO = c;
	ALPHA = smoothstep(depth, depth * 0.7, d);
}
