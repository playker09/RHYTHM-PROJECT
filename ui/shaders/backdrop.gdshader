shader_type canvas_item;
// 뒤 화면을 흐리고 어둡게 덮는 막
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float lod = 3.0;
uniform vec4 tint = vec4(0.03, 0.025, 0.06, 0.72);

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, lod).rgb;
	COLOR = vec4(mix(c, tint.rgb, tint.a), COLOR.a);
}
