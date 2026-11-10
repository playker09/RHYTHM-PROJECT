shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, depth_test_disabled;
// 타격 이펙트: 퍼지는 고리 두 겹 + 방사 광선 + 중심 섬광. progress 0 -> 1.
uniform vec3 color : source_color = vec3(1.0, 0.88, 0.54);
uniform float progress = 0.0;
uniform float seed = 0.0;
uniform float power = 1.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float t = progress;
	float ease = 1.0 - pow(1.0 - t, 3.0);
	float inv = 1.0 - t;
	float ring = exp(-abs(r - ease * 0.74) * 52.0) * inv * inv * 1.5;
	float ring2 = exp(-abs(r - ease * 0.46) * 70.0) * inv * inv * inv * 0.8;
	float flash = exp(-r * (5.0 + t * 10.0)) * inv * inv * inv * 3.0;
	// 고리 바깥으로 튀는 광선 (길이가 제각각)
	float k = sin(ang * 7.0 + seed * 6.28) * 0.5 + 0.5;
	float k2 = sin(ang * 13.0 - seed * 11.0) * 0.5 + 0.5;
	float spokes = pow(k * k2, 6.0) * exp(-abs(r - ease * 0.6) * 9.0) * inv * 2.2;
	vec3 c = mix(color, vec3(1.0), clamp(flash * 0.5 + ring * 0.2, 0.0, 0.8));
	ALBEDO = c * (ring + ring2 + flash + spokes) * 1.5 * power * (1.0 - smoothstep(0.8, 1.0, r));
	ALPHA = 1.0;
}
