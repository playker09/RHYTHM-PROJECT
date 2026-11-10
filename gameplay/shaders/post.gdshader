shader_type canvas_item;
// 3D 무대 위에 얹는 마무리: 색수차(가장자리만) + 비네트 + 그레인 + 메뉴용 흐림/어둡게.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float dim = 0.0;            // 0~1 잉크색으로 덮는 정도
uniform float blur = 0.0;           // mip 단계
uniform float aberration = 1.0;
uniform float vignette = 0.55;
uniform vec3 ink : source_color = vec3(0.027, 0.024, 0.05);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 d = SCREEN_UV - 0.5;
	float r2 = dot(d, d);
	vec2 off = d * r2 * 0.014 * aberration;
	vec3 c;
	c.r = textureLod(screen_tex, SCREEN_UV + off, blur).r;
	c.g = textureLod(screen_tex, SCREEN_UV, blur).g;
	c.b = textureLod(screen_tex, SCREEN_UV - off, blur).b;
	c *= 1.0 - r2 * vignette * 1.5;
	c = mix(c, ink, dim);
	c += (hash(FRAGCOORD.xy + fract(TIME) * 91.0) - 0.5) * 0.014;
	COLOR = vec4(c, 1.0);
}
