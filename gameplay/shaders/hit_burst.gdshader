shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, depth_test_disabled;
// 타격 이펙트: 퍼지는 고리 + 방사 광선 + 중심 섬광. progress 0 -> 1.
uniform vec3 color : source_color = vec3(1.0, 0.88, 0.54);
uniform float progress = 0.0;
uniform float seed = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float t = progress;
	float ease = 1.0 - (1.0 - t) * (1.0 - t);
	float inv = 1.0 - t;
	float ring = exp(-abs(r - ease * 0.72) * 46.0) * inv * inv * 1.3;
	float flash = exp(-r * (6.0 + t * 8.0)) * inv * inv * inv * 2.6;
	// 고리 바깥으로 튀는 불꽃
	float sparks = pow(abs(sin(ang * 5.0 + seed * 6.28)), 40.0) * exp(-abs(r - ease * 0.86) * 22.0) * inv * 1.6;
	vec3 c = mix(color, vec3(1.0), flash * 0.4);
	ALBEDO = c * (ring + flash + sparks) * 1.5 * (1.0 - smoothstep(0.8, 1.0, r));
	ALPHA = 1.0;
}
