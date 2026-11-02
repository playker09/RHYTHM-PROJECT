shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Hold 몸통: 양옆이 밝은 반투명 띠 + 판정선 쪽으로 흐르는 무늬.
uniform float depth = 34.0;
uniform vec3 color : source_color = vec3(1.0, 0.6, 0.2);
uniform float energy = 1.0;
uniform float alpha = 1.0;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float e = abs(UV.x - 0.5) * 2.0;
	float rail = smoothstep(0.86, 0.93, e);
	// 먼 쪽은 줄무늬가 뭉개지므로 무늬를 뺀다
	float flow = (0.5 + 0.5 * sin(wp.z * 3.4 - TIME * 9.0)) * exp(max(-wp.z, 0.0) * -0.22);
	float a = 0.3 + rail * 0.7 + flow * 0.1;
	ALBEDO = color * energy * (0.75 + rail * 1.2 + flow * 0.2);
	ALPHA = a * alpha * smoothstep(depth, depth * 0.72, max(-wp.z, 0.0));
}
