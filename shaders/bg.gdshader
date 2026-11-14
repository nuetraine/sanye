// 远景：星云、垂死恒星“残烛”、三层视差星空
shader_type canvas_item;
#include "res://shaders/common.gdshaderinc"
uniform vec2 cam;
uniform float tide = 0.0;
uniform float time = 0.0;
uniform float chap = 1.0;
uniform vec2 res = vec2(640.0, 360.0);

float h2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = h2(i), b = h2(i + vec2(1.0, 0.0)), c = h2(i + vec2(0.0, 1.0)), d = h2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
float fbm(vec2 p) {
	return n2(p) * 0.5 + n2(p * 2.03) * 0.25 + n2(p * 4.1) * 0.15 + n2(p * 8.3) * 0.1;
}

void fragment() {
	// pp = 精细像素坐标，p = 单位坐标（一个单位 = 2 个精细像素）
	vec2 pp = floor(UV * res);
	vec2 p = pp * 0.5;
	float b = bay(pp);
	vec2 n = floor(cam * 0.2) * 0.5 + vec2(200.0, 210.0) + p;
	float a = fbm(n * 0.007);
	float c2 = fbm(n * 0.011 + vec2(40.0, 9.0));
	float hot = max(0.0, 1.0 - length(n - vec2(170.0, 120.0)) / 360.0);
	float m = 0.0;
	float l = pow(max(0.0, a - 0.35) * 2.3, 1.6) * 4.2;
	if (c2 > 0.56 && c2 > a) { m = 2.0; l = (c2 - 0.56) * 9.0; }
	if (hot > 0.45 && hot * 1.4 > l * 0.45) { m = 15.0; l = (hot - 0.45) * 4.5; }
	// 第二章：星云换成墨紫色
	if (chap > 1.5) { if (m == 2.0) m = 9.0; else if (m == 15.0) m = 11.0; }
	float li = floor(l + b - 0.5);
	vec4 col;
	if (tide > 0.02 && b < tide) {
		col = li <= 1.0 ? rc(0.0, 0.0) : rc(m == 15.0 ? 0.0 : m, min(li - 1.0, 2.0));
	} else {
		col = li <= 0.0 ? rc(0.0, 0.0) : rc(m, min(li, m == 0.0 ? 4.0 : 2.0));
	}
	// 残烛
	vec2 sc = floor((vec2(52.0, 34.0) - cam * 0.015) * 2.0 + 0.5) * 0.5;
	vec2 dd = p - sc;
	if (abs(dd.x) <= 34.0 && abs(dd.y) <= 34.0) {
		float d = length(dd);
		float sr = 11.0 - 3.0 * tide;
		if (d < sr) {
			col = rc(tide > 0.5 ? 15.0 : 13.0, floor(6.0 - d / sr * 2.5 - tide * 2.5 + b * 0.9));
		} else {
			float cor = (1.0 - (d - sr) / (22.0 + 6.0 * sin(atan(dd.y, dd.x) * 5.0 + time * 0.3))) * (1.0 - tide * 0.75);
			if (cor > 0.0 && b < cor * 0.55) col = rc(15.0, 1.0 + cor * 2.5);
		}
	}
	// 星星（三层视差）：小星是一个精细像素，亮星带十字芒
	for (int L = 0; L < 3; L++) {
		float par = L == 0 ? 0.04 : (L == 1 ? 0.1 : 0.2);
		float cell = 40.0;
		vec2 q = pp + floor(cam * par * 2.0) + vec2(float(L) * 1000.0);
		vec2 ci = floor(q / cell);
		if (h2(ci + vec2(float(L) * 17.0, 3.0)) < 0.34 - float(L) * 0.06) {
			vec2 sp = ci * cell + floor(vec2(h2(ci + 5.3), h2(ci + 9.1)) * (cell - 6.0)) + 3.0;
			float tw = h2(ci + 1.7) * (0.7 + 0.3 * sin(time * 2.0 + h2(ci + 2.9) * 6.283)) * (1.0 - tide * 0.5);
			float sl = floor(2.0 + tw * 4.5);
			float mm = h2(ci + 4.4);
			float sm = mm < 0.2 ? 13.0 : (mm < 0.6 ? 8.0 : 12.0);
			vec2 e = abs(q - sp);
			float md = e.x + e.y;
			if (md < 0.5) col = rc(sm, sl);
			else if (L >= 1 && sl >= 4.0 && md < 1.5) col = rc(sm, sl - 2.0);
			else if (L == 2 && sl >= 5.0 && md < 2.5 && (e.x < 0.5 || e.y < 0.5)) col = rc(sm, sl - 4.0);
		}
	}
	COLOR = col;
}
