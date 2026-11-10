shader_type spatial;
render_mode unshaded, cull_disabled;
// 길 양옆에 늘어선 기둥(얇은 판). UV.y: 0 = 위, 1 = 아래.
// 판 하나를 셰이더로 깎아 보이게 한다: 뾰족한 머리, 바깥 테두리 + 안쪽 테두리, 가운데 빛 홈, 칸마다 다른 면 밝기.
// 박자에 맞춰 아래에서 빛이 오른다.
uniform float depth = 150.0;
uniform vec3 rim : source_color = vec3(0.56, 0.48, 1.0);
uniform float pulse = 0.0;
uniform float near_z = 8.0;
varying vec3 wp;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void fragment() {
	float d = max(-wp.z, 0.0);
	float fade = smoothstep(depth, depth * 0.35, d) * (1.0 - smoothstep(near_z - 6.0, near_z, wp.z));
	float ex = abs(UV.x - 0.5) * 2.0;     // 0 = 가운데, 1 = 가장자리
	float h = 1.0 - UV.y;                 // 0 = 바닥, 1 = 꼭대기
	float fw = fwidth(ex) * 1.5;
	float fh = fwidth(h) * 1.5;

	// 머리를 뾰족하게 깎는다 (가운데가 가장 높다)
	float cut = 1.0 - ex * 0.045;         // 이 높이 위는 잘라 낸다
	float shape = 1.0 - smoothstep(cut - fh, cut, h);
	float cap = smoothstep(cut - 0.012 - fh, cut - 0.004, h) * shape;

	// 테두리 두 겹 + 가운데 홈
	float edge = smoothstep(0.88 - fw, 0.93, ex);
	float inner = 1.0 - smoothstep(0.0, 0.03 + fw, abs(ex - 0.66));
	float slit = 1.0 - smoothstep(0.02, 0.05 + fw, ex);

	// 세로로 나뉜 칸: 칸마다 면 밝기가 조금씩 다르고, 경계에 눈금
	float cells = h * 9.0;
	float id = floor(cells);
	float seg = abs(fract(cells) - 0.5);
	float joint = smoothstep(0.47 - fh * 9.0, 0.5, seg);
	float plate = 0.5 + hash(id) * 0.9;
	float in_frame = 1.0 - smoothstep(0.62, 0.66, ex);   // 안쪽 테두리 안

	float foot = exp(-h * 5.0);
	float rise = exp(-abs(h - (1.0 - pulse) * 1.2) * 9.0) * pulse;

	vec3 c = rim * (0.008 + foot * 0.04 + rise * 0.08);
	c += rim * in_frame * plate * 0.018;                               // 칸 면
	c += rim * joint * (0.05 + in_frame * 0.05);                       // 칸 경계 눈금
	c += rim * inner * 0.09;                                           // 안쪽 테두리
	c += mix(rim, vec3(1.0), 0.4) * slit * (0.05 + rise * 0.6 + foot * 0.1);   // 가운데 홈
	c += mix(rim, vec3(1.0), 0.3) * edge * (0.16 + pulse * 0.2 + rise * 0.7);  // 바깥 테두리
	c += mix(rim, vec3(1.0), 0.5) * cap * (0.3 + pulse * 0.25);        // 머리 모서리

	ALBEDO = c;
	ALPHA = clamp(0.35 + edge * 0.5 + cap * 0.5 + inner * 0.1, 0.0, 1.0) * fade * shape;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
