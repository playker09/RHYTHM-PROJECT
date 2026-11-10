shader_type canvas_item;
// 씬 전환 와이프: 사선 잉크 면이 왼쪽에서 덮고(progress 0 -> 1) 같은 방향으로 걷힌다(1 -> 2).
// 앞뒤 가장자리에 보라/자홍 띠가 따라붙는다.
uniform float progress = 0.0;
uniform vec3 ink : source_color = vec3(0.027, 0.024, 0.05);
uniform vec3 violet : source_color = vec3(0.56, 0.48, 1.0);
uniform vec3 magenta : source_color = vec3(1.0, 0.31, 0.62);

float band(float x, float lo, float hi, float aa) {
	return smoothstep(lo - aa, lo + aa, x) * (1.0 - smoothstep(hi - aa, hi + aa, x));
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float x = UV.x + (0.5 - UV.y) * 0.28 * res.y / res.x;
	float aa = 1.0 / res.x;
	float head = mix(-0.4, 1.4, clamp(progress, 0.0, 1.0));
	float tail = mix(-0.4, 1.4, clamp(progress - 1.0, 0.0, 1.0));
	float cover = band(x, tail, head, aa);
	float b1 = band(x, tail - 0.035, head + 0.035, aa);
	float b2 = band(x, tail - 0.05, head + 0.05, aa);
	float b3 = band(x, tail - 0.085, head + 0.085, aa) * (1.0 - band(x, tail - 0.07, head + 0.07, aa));
	vec3 c = magenta;
	c = mix(c, violet, b1);
	// 잉크 면에는 옅은 사선 결
	float grain = 0.5 + 0.5 * sin((x - progress * 0.4) * 240.0);
	c = mix(c, ink * (1.0 + grain * 0.12), cover);
	COLOR = vec4(c, max(b2, b3 * 0.8));
}
