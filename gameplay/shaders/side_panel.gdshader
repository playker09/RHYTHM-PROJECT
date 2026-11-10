shader_type spatial;
render_mode unshaded, cull_disabled;
// 하이웨이 옆 경사면. UV.x: 0 = 안쪽(레인 쪽) -> 1 = 바깥쪽.
// 안쪽 모서리에서 빛이 번지는 유리판 + 세로 골(리브) + 판정선 쪽으로 흐르는 쐐기 무늬.
uniform float depth = 34.0;
uniform vec3 rim : source_color = vec3(0.56, 0.48, 1.0);
uniform float scroll = 0.0;       // 마디 기준 흐름 (m)
uniform float spacing = 8.0;      // 쐐기 간격 (m)
uniform float pulse = 0.0;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float x = UV.x;
	float d = max(-wp.z, 0.0);
	float fade = smoothstep(depth, depth * 0.62, d);
	float out_fade = 1.0 - x * 0.65;

	// 판 자체의 은은한 색 + 안쪽 모서리 번짐
	vec3 c = rim * (0.035 * out_fade + exp(-x * 5.0) * (0.2 + pulse * 0.14));

	// 세로 골 2줄 (길 방향으로 뻗는 얇은 선)
	float fx = fwidth(x) * 1.2;
	float rib = (1.0 - smoothstep(0.004, 0.008 + fx, abs(x - 0.34)))
		+ (1.0 - smoothstep(0.004, 0.008 + fx, abs(x - 0.68))) * 0.7;
	c += rim * rib * 0.16;

	// 쐐기 무늬: 안쪽이 앞서는 V 모양이 판정선 쪽으로 흐른다. 마디마다 굵은 줄 + 박자마다 가는 줄
	float u = (d - scroll + x * 2.4) / spacing;
	float q = fract(u);
	float fw = fwidth(u) * 1.4;
	float chev = smoothstep(0.0, fw + 0.004, q) * (1.0 - smoothstep(0.03, 0.036 + fw, q));
	float trail = (1.0 - smoothstep(0.03, 0.32, q)) * step(0.03, q);   // 줄 뒤에 남는 잔광
	float q4 = fract(u * 4.0);
	float fw4 = fw * 4.0;
	float minor = smoothstep(0.0, fw4 + 0.01, q4) * (1.0 - smoothstep(0.03, 0.04 + fw4, q4));
	c += rim * (chev * (0.3 + pulse * 0.2) + trail * 0.07 + minor * 0.06) * out_fade;

	// 바깥 모서리
	float outer = smoothstep(0.985, 0.992, x);
	c += rim * outer * 0.6;

	ALBEDO = c;
	ALPHA = clamp(mix(0.9, 0.45, smoothstep(0.0, 0.9, x)) + outer + chev * 0.3, 0.0, 1.0) * fade;
}
