shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;
// 공중 커서: 항상 카메라를 보는 마름모 + 바깥 마름모 테 + 십자 빛.
uniform vec3 color : source_color = vec3(1.0);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float dia = abs(p.x) + abs(p.y);
	float fw = fwidth(dia) * 1.2;
	float body = 1.0 - smoothstep(0.2 - fw, 0.2 + fw, dia);
	float ring = 1.0 - smoothstep(0.016, 0.016 + fw, abs(dia - 0.36));
	// 테는 네 꼭짓점 근처만 남긴다
	ring *= smoothstep(0.1, 0.2, abs(abs(p.x) - abs(p.y)));
	float flare = exp(-abs(p.y) * 46.0) * (1.0 - abs(p.x)) * (1.0 - abs(p.x)) + exp(-abs(p.x) * 46.0) * (1.0 - abs(p.y)) * (1.0 - abs(p.y)) * 0.55;
	float halo = max(exp(-length(p) * 4.5) - 0.011, 0.0) * 0.5;
	vec3 c = mix(color, vec3(1.0), body * 0.8) * 2.0;
	ALBEDO = c;
	ALPHA = clamp(body + ring * 0.9 + flare * 0.8 + halo, 0.0, 1.0);
}
