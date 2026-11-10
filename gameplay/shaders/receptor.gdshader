shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// 키 패드: 둥근 테두리 틀. press 가 오르면 안이 차오르며 빛난다.
uniform vec2 size = vec2(1.1, 0.84);
uniform vec2 body = vec2(0.98, 0.6);
uniform vec3 color : source_color = vec3(0.6, 0.64, 1.0);
uniform vec3 hot : source_color = vec3(0.6, 0.94, 1.0);
uniform float press = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * size;
	float r = 0.07;
	vec2 q = abs(p) - body * 0.5 + r;
	float sd = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
	float fw = fwidth(sd) * 1.2;
	float fill = 1.0 - smoothstep(-fw, fw, sd);
	float ring = 1.0 - smoothstep(0.012, 0.012 + fw, abs(sd + 0.014));
	float glow = exp(-max(sd, 0.0) * 16.0) * press;
	vec3 c = mix(color * 0.9, hot * 2.2, press);
	// 안쪽: 평소엔 어두운 유리, 누르면 판정선 쪽부터 밝다
	float grad = mix(0.35, 1.0, 1.0 - UV.y);
	float inner = fill * mix(0.1, 0.55 * grad, press);
	ALBEDO = c * (1.0 + ring * 0.6);
	ALPHA = clamp(inner + ring * mix(0.55, 1.0, press) + glow * 0.5 * (1.0 - fill), 0.0, 1.0);
}
