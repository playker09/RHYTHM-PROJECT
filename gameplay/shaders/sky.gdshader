shader_type sky;
// 무대 하늘: 잉크색 공허 + 성운 + 별 + 소실점의 일식(검은 원반과 코로나). 박자에 맞춰 코로나가 뛴다.
uniform float pulse = 0.0;
uniform float energy = 1.0;            // 전체 밝기 (메뉴에서 낮춘다)
uniform vec3 eclipse_dir = vec3(0.0, 0.0, -1.0);
uniform float eclipse_radius = 0.1;    // 라디안
uniform vec3 tone_left : source_color = vec3(0.42, 0.33, 1.0);
uniform vec3 tone_right : source_color = vec3(1.0, 0.26, 0.58);

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash3(i), hash3(i + vec3(1.0, 0.0, 0.0)), f.x), mix(hash3(i + vec3(0.0, 1.0, 0.0)), hash3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0.0, 0.0, 1.0)), hash3(i + vec3(1.0, 0.0, 1.0)), f.x), mix(hash3(i + vec3(0.0, 1.0, 1.0)), hash3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += noise3(p) * a;
		p = p * 2.03 + vec3(1.7, 9.2, 4.1);
		a *= 0.5;
	}
	return v;
}

float stars(vec3 dir, float scale, float cut) {
	vec3 g = floor(dir * scale);
	float h = hash3(g);
	if (h < cut) {
		return 0.0;
	}
	float tw = 0.55 + 0.45 * sin(TIME * (0.8 + h * 4.0) + h * 80.0);
	float m = smoothstep(0.34, 0.05, length(fract(dir * scale) - 0.5));
	return tw * m * fract(h * 311.0);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 fwd = normalize(eclipse_dir);
	float a = acos(clamp(dot(dir, fwd), -1.0, 1.0));
	float side = clamp(dir.x * 1.6 + 0.5, 0.0, 1.0);
	vec3 tone = mix(tone_left, tone_right, side);

	// 바탕: 위는 거의 검정, 지평선 쪽은 보랏빛
	vec3 c = mix(vec3(0.0012, 0.001, 0.004), vec3(0.006, 0.004, 0.018), exp(-abs(dir.y) * 3.0));

	// 성운
	float n = fbm(dir * 2.6 + vec3(0.0, TIME * 0.006, 0.0));
	float n2 = fbm(dir * 5.5 - vec3(TIME * 0.004, 0.0, 3.0));
	float cloud = smoothstep(0.42, 0.85, n) * (0.4 + n2);
	c += tone * cloud * 0.028 * exp(-abs(dir.y) * 1.6);

	// 별 (두 겹)
	float below = smoothstep(-0.12, 0.05, dir.y);
	c += vec3(0.8, 0.85, 1.0) * (stars(dir, 140.0, 0.9955) * 0.5 + stars(dir, 70.0, 0.997) * 0.9) * below;

	// 일식: 넓은 헤일로 + 코로나(방사 무늬) + 가장자리 고리 + 검은 원반
	float r = eclipse_radius;
	float out_d = max(a - r, 0.0);
	vec3 up = normalize(cross(cross(fwd, vec3(0.0, 1.0, 0.0)), fwd));
	vec3 right = normalize(cross(fwd, up));
	float ang = atan(dot(dir, up), dot(dir, right));
	float rays = 0.55 + 0.45 * noise3(vec3(ang * 5.0, TIME * 0.12, 1.3)) + 0.25 * noise3(vec3(ang * 17.0, TIME * 0.2, 7.7));
	float halo = exp(-out_d * 5.5) * (0.07 + pulse * 0.035);
	float corona = exp(-out_d * (26.0 - pulse * 6.0)) * rays * (0.55 + pulse * 0.5);
	float rim = exp(-abs(a - r) * 420.0) * (1.6 + pulse * 1.6);
	vec3 hot = mix(tone, vec3(1.0, 0.94, 1.0), 0.6);
	c += tone * halo + mix(tone, hot, 0.5) * corona + hot * rim;
	// 가로로 번지는 빛줄기
	float dy = dot(dir, up);
	float dx = dot(dir, right);
	c += hot * exp(-abs(dy) * 150.0) * exp(-abs(dx) * 2.6) * (0.1 + pulse * 0.1);
	// 원반 안쪽은 어둡게 (안쪽 가장자리에만 옅은 빛)
	float inside = 1.0 - smoothstep(r - 0.004, r, a);
	c = mix(c, tone * 0.012 * (1.0 + pulse) * smoothstep(r * 0.4, r, a), inside);

	// 멀리 있는 큰 고리
	c += tone * (exp(-abs(a - (0.36 + pulse * 0.01)) * 300.0) * (0.03 + pulse * 0.07) + exp(-abs(a - 0.6) * 420.0) * 0.014);

	COLOR = c * energy;
}
