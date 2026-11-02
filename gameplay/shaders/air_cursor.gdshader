shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;
// 공중 커서: 항상 카메라를 보는 마름모 + 십자 빛.
uniform vec3 color : source_color = vec3(1.0);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float dia = abs(p.x) + abs(p.y);
	float fw = fwidth(dia) * 1.2;
	float body = 1.0 - smoothstep(0.28 - fw, 0.28 + fw, dia);
	float ring = 1.0 - smoothstep(0.018, 0.018 + fw, abs(dia - 0.44));
	float flare = exp(-abs(p.y) * 40.0) * (1.0 - abs(p.x)) * (1.0 - abs(p.x)) + exp(-abs(p.x) * 40.0) * (1.0 - abs(p.y)) * (1.0 - abs(p.y)) * 0.6;
	float halo = max(exp(-length(p) * 5.0) - 0.0067, 0.0) * 0.45;
	vec3 c = mix(color, vec3(1.0), body * 0.75) * 1.6;
	ALBEDO = c;
	ALPHA = clamp(body + ring * 0.9 + flare * 0.8 + halo, 0.0, 1.0);
}
