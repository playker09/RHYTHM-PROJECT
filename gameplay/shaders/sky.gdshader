shader_type sky;
// 인게임 하늘: 소실점의 빛 + 박자에 맞춰 뛰는 고리 + 별.
uniform float pulse = 0.0;
uniform vec3 horizon_dir = vec3(0.0, -0.05, -1.0);

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 fwd = normalize(horizon_dir);
	float a = acos(clamp(dot(dir, fwd), -1.0, 1.0));
	float side = clamp(dir.x * 1.8 + 0.5, 0.0, 1.0);
	vec3 tone = mix(vec3(0.42, 0.33, 1.0), vec3(1.0, 0.26, 0.58), side);

	vec3 c = mix(vec3(0.0016, 0.0014, 0.005), vec3(0.005, 0.003, 0.014), exp(-abs(dir.y) * 3.5));
	c += tone * exp(-a * 7.0) * (0.09 + pulse * 0.05);
	c += mix(tone, vec3(1.0), 0.45) * exp(-a * 30.0) * (0.16 + pulse * 0.26);

	// 큰 고리 두 개
	float r1 = abs(a - (0.34 + pulse * 0.012));
	float r2 = abs(a - 0.56);
	c += tone * (exp(-r1 * 260.0) * (0.035 + pulse * 0.11) + exp(-r2 * 420.0) * 0.016);

	// 별
	vec3 g = floor(dir * 150.0);
	float h = hash(g);
	if (h > 0.9965 && dir.y > -0.02) {
		float tw = 0.45 + 0.55 * sin(TIME * (1.0 + h * 5.0) + h * 80.0);
		float dot_mask = smoothstep(0.32, 0.08, length(fract(dir * 150.0) - 0.5));
		c += vec3(0.8, 0.85, 1.0) * tw * 0.3 * fract(h * 311.0) * dot_mask;
	}
	COLOR = c;
}
