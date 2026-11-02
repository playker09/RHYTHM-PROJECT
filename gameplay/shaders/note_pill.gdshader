shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Tap/Hold 머리, 키패드: 둥근 막대 + 밝은 심 + 바깥 번짐. plane 크기(size) 안에 body 크기로 그린다.
uniform float depth = 34.0;
uniform vec3 color : source_color = vec3(0.6, 0.94, 1.0);
uniform vec2 size = vec2(1.0, 0.5);
uniform vec2 body = vec2(0.92, 0.17);
uniform float energy = 1.5;
uniform float core = 1.0;
uniform float halo = 0.55;
uniform float alpha = 1.0;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = (UV - 0.5) * size;
	vec2 q = abs(p) - body * 0.5 + 0.05;
	float sd = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - 0.05;
	float fw = fwidth(sd) * 1.2;
	float fill = 1.0 - smoothstep(-fw, fw, sd);
	float glow = exp(-max(sd, 0.0) * 13.0) * halo;
	float inner = (1.0 - smoothstep(0.0, body.y * 0.3, abs(p.y))) * core;
	vec3 c = mix(color * energy, vec3(1.0) * energy * 1.25, inner * fill);
	ALBEDO = c;
	ALPHA = clamp(fill + glow * (1.0 - fill), 0.0, 1.0) * alpha * smoothstep(depth, depth * 0.72, max(-wp.z, 0.0));
}
