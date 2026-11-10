shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
// Field 레일 아래로 떨어지는 빛 커튼. UV.y: 0 = 레일, 1 = 아래 끝.
uniform float depth = 34.0;
uniform vec3 color : source_color = vec3(0.35, 0.75, 1.0);
uniform float air_z = 1.0;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = max(air_z - wp.z, 0.0);
	float f = 1.0 - UV.y;
	ALBEDO = color * f * f * 0.45 * smoothstep(depth, depth * 0.66, d);
}
