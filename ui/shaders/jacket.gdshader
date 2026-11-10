shader_type canvas_item;
// 곡별 생성 재킷 아트. seed 와 세 가지 색으로 원/호/사선 띠를 조합한다.
uniform float seed = 0.0;
uniform vec3 c1 : source_color = vec3(0.1, 0.05, 0.3);
uniform vec3 c2 : source_color = vec3(0.5, 0.2, 0.8);
uniform vec3 c3 : source_color = vec3(1.0, 0.5, 0.7);

float hash(float x) {
	return fract(sin(x * 12.9898 + seed) * 43758.5453);
}

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = UV - 0.5;
	float aa = fwidth(p.x) * 1.5;
	float ang = hash(1.0) * 6.283;
	vec2 dir = vec2(cos(ang), sin(ang));
	vec3 c = mix(c1, c2, smoothstep(-0.7, 0.7, dot(p, dir)));

	// 큰 원 + 그림자
	vec2 o = vec2(hash(2.0) - 0.5, hash(3.0) - 0.5) * 0.5;
	float r = 0.2 + hash(4.0) * 0.2;
	float d = length(p - o);
	c *= 1.0 - smoothstep(r + 0.14, r, d) * 0.3;
	vec3 disc = mix(c3, c2, smoothstep(-0.4, 0.4, dot(p - o, dir.yx)));
	c = mix(c, disc, smoothstep(r + aa, r - aa, d));

	// 동심 호
	float rings = abs(fract(length(p + o) * (7.0 + hash(5.0) * 5.0)) - 0.5);
	float ring_mask = smoothstep(0.03, 0.03 - aa * 8.0, rings) * smoothstep(-0.2, 0.3, dot(p, dir.yx));
	c = mix(c, vec3(1.0), ring_mask * 0.22);

	// 사선 띠
	vec2 band_dir = vec2(cos(ang + 1.1), sin(ang + 1.1));
	float bd = dot(p, band_dir) - (hash(6.0) - 0.5) * 0.5;
	float band = smoothstep(0.06 + aa, 0.06 - aa, abs(bd));
	c = mix(c, c1 * 0.5, band * 0.75);
	float hair = smoothstep(aa * 1.2, 0.0, abs(bd - 0.085));
	c = mix(c, vec3(1.0), hair * 0.75);

	// 빛 + 비네트 + 그레인
	c += vec3(1.0) * smoothstep(0.9, 0.0, length(p - vec2(-0.45, -0.45))) * 0.09;
	c *= 1.0 - dot(p, p) * 0.5;
	c += (grain(UV * 913.0 + seed) - 0.5) * 0.035;
	COLOR = vec4(c, COLOR.a);
}
