shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// 공중 Field 띠. UV.x: 0/1 = 양쪽 가장자리. 유리판 + 밝은 레일 + 판정선 쪽으로 흐르는 가로줄.
uniform float depth = 34.0;
uniform vec3 color : source_color = vec3(0.35, 0.75, 1.0);
uniform vec3 edge : source_color = vec3(0.75, 0.97, 1.0);
uniform float air_z = 1.0;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float e = abs(UV.x - 0.5) * 2.0;
	float fw = fwidth(e) * 1.4;
	float rail = smoothstep(0.94 - fw, 0.96, e);
	float d = max(air_z - wp.z, 0.0);
	float near = exp(-d * 0.12);
	float v = fract(d * 0.9 + TIME * 2.4);
	float scan = smoothstep(0.0, 0.06, v) * (1.0 - smoothstep(0.06, 0.5, v)) * near;
	float fill = 0.13 + pow(e, 3.0) * 0.3 + scan * 0.1;
	vec3 c = color * (0.9 + scan * 0.6);
	ALBEDO = mix(c, edge * 2.4, rail);
	ALPHA = clamp(fill + rail, 0.0, 1.0) * smoothstep(depth, depth * 0.66, d);
}
