shader_type canvas_item;
// 글자에 세로 그라데이션. start = 색이 바뀌기 시작하는 높이(px, 라벨 위쪽 기준), span = 거기서부터 다 바뀔 때까지의 높이(px).
uniform vec4 top : source_color = vec4(1.0);
uniform vec4 bottom : source_color = vec4(1.0);
uniform float span = 100.0;
uniform float start = 0.0;
varying float py;

void vertex() {
	py = VERTEX.y;
}

void fragment() {
	float a = texture(TEXTURE, UV).a;
	COLOR = vec4(mix(top.rgb, bottom.rgb, clamp((py - start) / span, 0.0, 1.0)), a * COLOR.a);
}
