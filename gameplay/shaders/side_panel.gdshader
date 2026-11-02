shader_type spatial;
render_mode unshaded, cull_disabled;
// 하이웨이 옆 경사면. UV.x: 0 = 안쪽(레인 쪽) -> 1 = 바깥쪽.
// 안쪽 모서리에서 빛이 번지고 바깥으로 갈수록 투명해지는 유리판 + 흐르는 쐐기 무늬.
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
	vec3 c = rim * (0.012 + exp(-x * 6.0) * (0.11 + pulse * 0.1));

	// 쐐기 무늬: 안쪽이 앞서는 V 모양이 판정선 쪽으로 흐른다
	float q = fract((d - scroll + x * 2.4) / spacing);
	float fw = fwidth(q) * 1.4;
	float chev = smoothstep(0.0, fw + 0.004, q) * (1.0 - smoothstep(0.018, 0.022 + fw, q));
	c += rim * chev * 0.1 * (1.0 - x * 0.6);

	// 바깥 모서리
	float outer = smoothstep(0.988, 0.993, x);
	c += rim * outer * 0.5;

	ALBEDO = c;
	ALPHA = (mix(0.85, 0.3, smoothstep(0.0, 0.9, x)) + outer + chev * 0.3) * fade;
}
