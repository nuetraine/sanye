// 特效：圈、撒点的圆、光束、预告线。每个特效只画一个四边形，形状在这里按精细像素算出来，
// 不用脚本一个点一个点地画（怪海里几十个圈同时出现时省下大半绘制时间）。
// UV = 相对特效中心的单位坐标；顶点颜色里塞参数：
//   r = (材质 + 16 × 点距档) / 128，g = (明暗阶 + 8 × 类型) / 64，b = 半径或半宽 / 512，a = 相位或密度
// 类型：0 点圈，1 撒点的圆，2 我方光束（青白芯），3 预告虚线，4 敌方光束（白芯红边）
shader_type canvas_item;
#include "res://shaders/common.gdshaderinc"
uniform float time = 0.0;
varying vec4 vc;
varying vec2 wpos;

float hh(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	vc = COLOR;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// 把采样点挪到所在精细像素的中心，这样斜着的线也是一格一格的
	vec2 ws = (floor(wpos * 2.0) + 0.5) * 0.5;
	vec2 dw = ws - wpos;
	vec2 q = UV + dFdx(UV) / dFdx(wpos.x) * dw.x + dFdy(UV) / dFdy(wpos.y) * dw.y;
	float fm = floor(vc.r * 128.0 + 0.5);
	float m = mod(fm, 16.0);
	float si = floor(fm / 16.0);
	float fl = floor(vc.g * 64.0 + 0.5);
	float l = mod(fl, 8.0);
	float ty = floor(fl / 8.0);
	float R = vc.b * 512.0;
	vec4 col;
	if (ty < 0.5) {
		float d = length(q);
		if (abs(d - R) > 0.5) discard;
		float stp = 1.0 + si * 0.5;
		float n = max(8.0, floor(R * 6.2832 / stp));
		float f = fract((atan(q.y, q.x) / 6.2832 + vc.a) * n);
		if (f * R * 6.2832 / n > 0.95) discard;
		col = rc(m, l);
	} else if (ty < 1.5) {
		vec2 e = vec2(q.x, q.y / 0.8);
		if (dot(e, e) > R * R) discard;
		vec2 cell = floor(q);
		float h = hh(cell + vec2(R, m));
		if (h > vc.a) discard;
		col = rc(m, sin(time * 9.0 + h * 400.0) > 0.0 ? l : l - 2.0);
	} else if (ty < 2.5 || ty > 3.5) {
		if (q.x < 0.0 || abs(q.y) > R) discard;
		if (abs(q.y) <= 0.8) col = ty < 2.5 ? rc(8.0, 6.0) : rc(12.0, 6.0);
		else {
			if (bay(floor(wpos * 2.0)) > 0.62) discard;
			col = rc(m, l);
		}
	} else {
		if (q.x < 0.0 || abs(q.y) > 0.3) discard;
		if (fract(q.x / 4.5 - time * 4.0) > 0.66) discard;
		col = rc(m, l);
	}
	COLOR = col;
}
