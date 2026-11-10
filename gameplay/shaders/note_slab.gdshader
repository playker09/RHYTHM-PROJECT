shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// 입체 노트(깎인 판). 면마다 밝기가 다르다: COLOR.r = 면 밝기, COLOR.g = 윗면 여부. UV = 윗면 좌표.
uniform float depth = 34.0;
uniform vec3 color : source_color = vec3(0.6, 0.94, 1.0);
uniform float energy = 1.0;
uniform float alpha = 1.0;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float face = COLOR.r;
	float top = COLOR.g;
	vec2 p = (UV - 0.5) * 2.0;
	// 하이라이트는 노트 색의 밝기를 따른다 (MISS처럼 어두운 색이면 흰 심도 같이 어두워진다)
	vec3 hi = vec3(max(color.r, max(color.g, color.b)));
	// 윗면: 가운데 좁은 흰 심 + 색이 도는 면 + 둘레의 밝은 색 테(멀리서도 판 모양과 색이 읽히게)
	float core = (1.0 - smoothstep(0.0, 0.4, abs(p.y))) * (1.0 - pow(abs(p.x), 6.0));
	float tips = smoothstep(0.5, 1.0, abs(p.x));
	float border = max(smoothstep(0.62, 0.8, abs(p.y)), smoothstep(0.93, 0.97, abs(p.x)));
	vec3 top_c = mix(color * 0.7, hi, core * 0.6) * (0.9 + core * 0.4);
	top_c = mix(top_c, color * 1.05, tips * 0.75);
	top_c = mix(top_c, mix(color, hi, 0.25) * 1.2, border);
	// 옆면: 카메라 쪽 면은 밝은 색 띠, 나머지는 어둡게 (윗면과 명암 차이를 크게)
	vec3 side_c = mix(color * 0.22, mix(color, hi, 0.3) * 1.1, face);
	ALBEDO = mix(side_c, top_c, top) * energy;
	ALPHA = alpha * smoothstep(depth, depth * 0.74, max(-wp.z, 0.0));
}
