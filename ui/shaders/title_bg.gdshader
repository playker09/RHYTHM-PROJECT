shader_type canvas_item;
// 타이틀 배경: 지평선으로 빨려 들어가는 4레인 하이웨이와 달려오는 빛줄기.
uniform float reveal = 1.0;

float hash(float x) {
	return fract(sin(x * 91.17) * 43758.5453);
}

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = res.x / res.y;
	const float H = 0.40;
	vec2 p = vec2((UV.x - 0.5) * aspect, UV.y - H);
	vec3 violet = vec3(0.45, 0.36, 1.0);
	vec3 magenta = vec3(1.0, 0.24, 0.55);
	vec3 side = mix(violet, magenta, smoothstep(-0.5, 0.5, p.x));

	// 하늘: 지평선 빛
	float dist = length(vec2(p.x, p.y * 2.1));
	vec3 c = vec3(0.022, 0.018, 0.05);
	c += side * exp(-dist * 3.8) * 0.5;
	c += vec3(1.0, 0.92, 1.0) * exp(-abs(p.y) * 62.0) * exp(-abs(p.x) * 1.5) * 0.42;

	if (p.y > 0.0) {
		float z = 0.30 / p.y;              // 깊이
		float lx = p.x * z * 1.15;         // 레인 좌표 (1 = 레인 폭)
		float fade = exp(-z * 0.09);
		vec3 f = vec3(0.012, 0.011, 0.03);
		// 레인 안쪽 / 바깥 경사면
		float inside = 1.0 - smoothstep(1.97, 2.03, abs(lx));
		f = mix(side * 0.11 * (1.0 - smoothstep(2.0, 8.0, abs(lx))), f, inside);
		// 레인 선
		float wid = fwidth(lx);
		float dl = abs(fract(lx + 0.5) - 0.5);
		float line = 1.0 - smoothstep(0.004, 0.004 + wid * 1.5, dl);
		f += vec3(0.55, 0.6, 0.95) * line * inside * 0.3;
		// 양쪽 레일
		float rail = 1.0 - smoothstep(0.018, 0.018 + wid * 1.5, abs(abs(lx) - 2.0));
		f += side * rail * 1.8;
		// 달려오는 빛줄기
		float id = floor(lx);
		if (abs(lx) < 2.0) {
			float q = fract(z * 0.13 + TIME * (0.55 + hash(id + 3.0) * 0.25) + hash(id));
			float q2 = fract(z * 0.13 + TIME * (0.35 + hash(id + 8.0) * 0.2) + hash(id + 5.0));
			float bars = smoothstep(0.975, 0.992, q) + smoothstep(0.985, 0.996, q2) * 0.7;
			float cx = 1.0 - smoothstep(0.32, 0.47, abs(fract(lx) - 0.5));
			f += mix(vec3(0.45, 0.95, 1.0), vec3(1.0), 0.45) * bars * cx * 2.0;
		}
		c = mix(c, f, fade) + f * (1.0 - fade) * 0.15;
		c += side * exp(-p.y * 12.0) * 0.1;
	}
	vec2 v = UV - 0.5;
	c *= 1.0 - dot(v, v) * 1.0;
	c += (grain(FRAGCOORD.xy + fract(TIME) * 53.0) - 0.5) * 0.018;
	COLOR = vec4(c * reveal, 1.0);
}
