shader_type spatial;
render_mode unshaded, cull_disabled;
// 빛나는 선/면 공통. energy > 1 이면 글로우가 번진다. 먼 쪽과 카메라 가까운 쪽은 흐려진다.
uniform float depth = 34.0;
uniform vec3 color : source_color = vec3(1.0);
uniform float energy = 1.0;
uniform float alpha = 1.0;
uniform float x_fade = 0.0;       // > 0 이면 로컬 X 양끝으로 사라짐 (반폭, m)
uniform float near_z = 100.0;     // 이 z 를 넘어 카메라로 오면 사라짐
varying vec3 wp;
varying float lx;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lx = VERTEX.x;
}

void fragment() {
	float a = alpha * smoothstep(depth, depth * 0.62, max(-wp.z, 0.0));
	if (x_fade > 0.0) {
		a *= 1.0 - smoothstep(x_fade * 0.35, x_fade, abs(lx));
	}
	a *= 1.0 - smoothstep(near_z - 2.0, near_z, wp.z);
	ALBEDO = color * energy;
	ALPHA = a;
}
