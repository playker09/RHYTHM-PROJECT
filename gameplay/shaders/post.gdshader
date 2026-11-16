shader_type canvas_item;
// 3D 무대 위에 얹는 마무리: 색수차(가장자리만) + 비네트 + 그레인 + 메뉴용 흐림/어둡게.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float dim = 0.0;            // 0~1 잉크색으로 덮는 정도
uniform float blur = 0.0;           // mip 단계
uniform float aberration = 1.0;
uniform float vignette = 0.55;
uniform float glitch = 0.0;         // 0~1 연출용 글리치
uniform vec2 flash = vec2(0.0);     // 연출 발광 (왼쪽, 오른쪽) 0~1: 화면 가장자리에서 번지는 빛
uniform vec3 flash_left = vec3(0.56, 0.48, 1.0);
uniform vec3 flash_right = vec3(1.0, 0.31, 0.62);
uniform vec3 ink : source_color = vec3(0.027, 0.024, 0.05);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 d = SCREEN_UV - 0.5;
	float r2 = dot(d, d);
	vec2 off = d * r2 * 0.014 * aberration;
	vec2 uv = SCREEN_UV;
	if (glitch > 0.001) {
		// 가로 띠가 좌우로 밀리고 색이 갈라진다 (1/24초마다 무늬가 바뀜)
		float t = floor(TIME * 24.0);
		float band = floor(uv.y * mix(9.0, 34.0, hash(vec2(t, 3.0))));
		float on = step(1.0 - glitch * 0.6, hash(vec2(band, t)));
		uv.x += (hash(vec2(band, t + 7.0)) - 0.5) * 0.12 * glitch * on;
		off.x += glitch * 0.006 * (0.4 + on);
	}
	vec3 c;
	c.r = textureLod(screen_tex, uv + off, blur).r;
	c.g = textureLod(screen_tex, uv, blur).g;
	c.b = textureLod(screen_tex, uv - off, blur).b;
	c *= 1.0 - r2 * vignette * 1.5;
	// 가장자리에서 화면 안쪽으로 번지는 빛 (가운데 판정 영역은 거의 건드리지 않는다)
	float gl = pow(1.0 - SCREEN_UV.x, 2.6);
	float gr = pow(SCREEN_UV.x, 2.6);
	c += (flash_left * flash.x * gl + flash_right * flash.y * gr) * 0.42;
	c = mix(c, ink, dim);
	c += (hash(FRAGCOORD.xy + fract(TIME) * 91.0) - 0.5) * 0.014;
	COLOR = vec4(c, 1.0);
}
