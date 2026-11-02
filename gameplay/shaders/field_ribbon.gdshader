shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// 공중 Field 띠. UV.x: 0/1 = 양쪽 가장자리. 판정선 쪽으로 빛이 흐른다.
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
	float rail = smoothstep(0.93 - fw, 0.95, e);
	float d = max(air_z - wp.z, 0.0);
	float flow = 0.5 + 0.5 * sin(d * 1.1 + TIME * 7.0);
	float fill = 0.2 + pow(e, 3.0) * 0.28 + flow * 0.06;
	ALBEDO = mix(color * (1.0 + flow * 0.25), edge * 2.2, rail);
	ALPHA = clamp(fill + rail, 0.0, 1.0) * smoothstep(depth, depth * 0.62, d);
}
