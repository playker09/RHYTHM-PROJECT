shader_type canvas_item;
// 씬 전환용 사선 와이프. tail < d < head 구간을 덮는다 (head/tail: 0~1.5).
uniform float head = 0.0;
uniform float tail = -0.4;
uniform vec3 ink : source_color = vec3(0.03, 0.027, 0.06);
uniform vec3 rim_a : source_color = vec3(0.56, 0.48, 1.0);
uniform vec3 rim_b : source_color = vec3(1.0, 0.31, 0.62);

void fragment() {
	float d = UV.x + (1.0 - UV.y) * 0.28;
	float a = smoothstep(head + 0.002, head - 0.002, d) * smoothstep(tail - 0.002, tail + 0.002, d);
	float rim = max(smoothstep(0.03, 0.0, abs(d - head)), smoothstep(0.03, 0.0, abs(d - tail)));
	vec3 c = mix(ink, mix(rim_a, rim_b, UV.y), rim);
	COLOR = vec4(c, a);
}
