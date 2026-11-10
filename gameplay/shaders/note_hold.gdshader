shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Hold 몸통: 유리관처럼 양옆 레일이 밝고, 가운데로 쐐기 무늬가 판정선 쪽으로 흐른다. held = 누르고 있는 동안 1.
uniform float depth = 34.0;
uniform vec3 color : source_color = vec3(1.0, 0.6, 0.2);
uniform float energy = 1.0;
uniform float alpha = 1.0;
uniform float held = 0.0;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float e = abs(UV.x - 0.5) * 2.0;
	float fw = fwidth(e) * 1.5;
	float rail = smoothstep(0.86 - fw, 0.9, e);
	float d = max(-wp.z, 0.0);
	float near = exp(-d * 0.16);
	// 먼 쪽은 무늬가 뭉개지므로 뺀다
	float v = fract((wp.z - e * 0.35) * 1.3 - TIME * (2.2 + held * 3.0));
	float chev = smoothstep(0.0, 0.1, v) * (1.0 - smoothstep(0.1, 0.45, v)) * near;
	float centre = (1.0 - e) * (1.0 - e);
	float a = 0.2 + centre * 0.12 + rail * 0.8 + chev * (0.12 + held * 0.2) + held * 0.14;
	vec3 c = color * (0.7 + chev * 0.5 + held * 0.2);
	c = mix(c, mix(color, vec3(max(color.r, max(color.g, color.b))), 0.5) * (1.2 + held * 0.4), rail);
	ALBEDO = c * energy;
	ALPHA = clamp(a, 0.0, 1.0) * alpha * smoothstep(depth, depth * 0.74, d);
}
