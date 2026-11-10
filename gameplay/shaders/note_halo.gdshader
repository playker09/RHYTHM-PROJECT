shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
// 노트 아래 바닥에 번지는 빛. plane 크기(size) 안에 body 크기의 막대에서 퍼진다.
uniform float depth = 34.0;
uniform vec3 color : source_color = vec3(0.6, 0.94, 1.0);
uniform vec2 size = vec2(1.6, 1.0);
uniform vec2 body = vec2(0.95, 0.3);
uniform float energy = 0.14;
uniform float alpha = 1.0;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = (UV - 0.5) * size;
	vec2 q = abs(p) - body * 0.5;
	float sd = length(max(q, vec2(0.0)));
	float edge = 1.0 - smoothstep(0.75, 1.0, max(abs(UV.x - 0.5), abs(UV.y - 0.5)) * 2.0);
	float g = exp(-sd * 11.0) * edge;
	ALBEDO = color * g * energy * alpha * smoothstep(depth, depth * 0.74, max(-wp.z, 0.0));
}
