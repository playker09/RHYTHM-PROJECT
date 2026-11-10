shader_type spatial;
render_mode unshaded, cull_back;
// 멀리 떠다니는 결정 조각(MultiMesh). 면 방향으로 가짜 반사광을 낸다.
// INSTANCE_CUSTOM: x = 위상, y = 색 섞임, z = 회전 속도.
uniform vec3 tone_a : source_color = vec3(0.56, 0.48, 1.0);
uniform vec3 tone_b : source_color = vec3(1.0, 0.31, 0.62);
uniform float fade_far = 170.0;
uniform float scroll = 0.0;
uniform float range_z = 180.0;
varying float mixv;
varying vec3 wn;
varying vec3 wpos;

void vertex() {
	float ph = INSTANCE_CUSTOM.x * 6.283;
	float sp = 0.15 + INSTANCE_CUSTOM.z * 0.35;
	float a = TIME * sp + ph;
	mat3 ry = mat3(vec3(cos(a), 0.0, -sin(a)), vec3(0.0, 1.0, 0.0), vec3(sin(a), 0.0, cos(a)));
	float b = TIME * sp * 0.6 + ph * 2.0;
	mat3 rx = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cos(b), sin(b)), vec3(0.0, -sin(b), cos(b)));
	vec3 v = ry * rx * VERTEX;
	vec3 n = ry * rx * NORMAL;
	vec4 w = MODEL_MATRIX * vec4(v, 1.0);
	// 카메라 쪽으로 천천히 흘러오고, 지나가면 뒤로 돌아간다
	w.z = mod(w.z + scroll + range_z, range_z) - range_z + 12.0;
	w.y += sin(TIME * 0.3 + ph) * 0.6;
	wpos = w.xyz;
	wn = normalize(mat3(MODEL_MATRIX) * n);
	mixv = INSTANCE_CUSTOM.y;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * w;
}

void fragment() {
	vec3 tone = mix(tone_a, tone_b, mixv);
	vec3 n = normalize(wn);
	float l = clamp(dot(n, normalize(vec3(-0.3, 0.5, 0.8))), 0.0, 1.0);
	float l2 = clamp(dot(n, normalize(vec3(0.2, -0.6, -0.7))), 0.0, 1.0);
	vec3 c = tone * (0.015 + pow(l, 3.0) * 0.4 + l2 * 0.06);
	c += vec3(1.0) * pow(l, 16.0) * 0.5;
	float d = max(-wpos.z, 0.0);
	float fade = smoothstep(fade_far, fade_far * 0.5, d) * smoothstep(10.0, -8.0, wpos.z);
	ALBEDO = c * fade;
}
