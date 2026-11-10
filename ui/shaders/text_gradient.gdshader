shader_type canvas_item;
// 글자에 세로 그라데이션. span = 라벨 위쪽부터 그라데이션이 끝나는 높이(px).
uniform vec4 top : source_color = vec4(1.0);
uniform vec4 bottom : source_color = vec4(1.0);
uniform float span = 100.0;
varying float py;

void vertex() {
	py = VERTEX.y;
}

void fragment() {
	float a = texture(TEXTURE, UV).a;
	COLOR = vec4(mix(top.rgb, bottom.rgb, clamp(py / span, 0.0, 1.0)), a * COLOR.a);
}
