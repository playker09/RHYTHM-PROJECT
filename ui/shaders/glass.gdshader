shader_type canvas_item;
// 유리 막: 뒤 화면을 흐리고 색을 입힌다. 전체 화면 막과 패널 바탕에 같이 쓴다.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float lod = 3.0;
uniform vec4 tint = vec4(0.03, 0.025, 0.06, 0.72);

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, lod).rgb;
	// mip 한 단계 위와 섞어 계단진 흐림을 줄인다
	c = mix(c, textureLod(screen_tex, SCREEN_UV, lod + 1.0).rgb, 0.5);
	COLOR = vec4(mix(c, tint.rgb, tint.a), COLOR.a);
}
