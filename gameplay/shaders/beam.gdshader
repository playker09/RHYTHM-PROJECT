shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
// 키 입력 빔. UV.y = 1 쪽이 밝고 반대쪽으로 사라진다.
uniform vec4 color : source_color = vec4(0.4, 0.85, 1.0, 1.0);
uniform float intensity = 0.8;
uniform float power = 1.6;

void fragment() {
	float fade = pow(clamp(UV.y, 0.0, 1.0), power);
	float side = 1.0 - pow(abs(UV.x - 0.5) * 2.0, 3.0) * 0.5;
	ALBEDO = color.rgb * intensity * fade * side;
	ALPHA = 1.0;
}
