shader_type spatial;
render_mode unshaded, cull_disabled;
// 하이웨이 옆 구조물 윗면. UV.x: 0 = 안쪽(레인 쪽) -> 1 = 바깥쪽. 부드러운 그라데이션 없이 각진 면 + 밝은 테두리.
uniform vec4 base_color : source_color = vec4(0.2, 0.15, 0.5, 1.0);
uniform vec4 edge_color : source_color = vec4(0.7, 0.55, 1.0, 1.0);
uniform float stripes = 22.0;

void fragment() {
	float x = UV.x;
	float s = step(0.5, fract(x * stripes));
	vec3 c = base_color.rgb * (0.78 + 0.22 * s);
	if (x < 0.03 || x > 0.985) {
		c = edge_color.rgb;
	}
	ALBEDO = c;
}
