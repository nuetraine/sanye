// 小行星打光：太阳 + 点光源，量化到 7 阶色板并抖动。
// 贴图一格 = 一个单位；这里把每格再细分成 2×2 个精细像素：
// 轮廓的锯齿角被削圆 / 填平，法线在格子之间过渡，表面加一层细颗粒。
shader_type canvas_item;
#include "res://shaders/common.gdshaderinc"
uniform vec4 lights[24];
uniform int nlights = 0;
uniform float sun = 1.0;
uniform float amb = 0.08;
uniform float time = 0.0;
varying vec2 wpos;
const vec3 SUNV = vec3(-0.5496, -0.4997, 0.6695);

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec4 tf(sampler2D tx, ivec2 p, ivec2 ts) {
	if (p.x < 0 || p.y < 0 || p.x >= ts.x || p.y >= ts.y) return vec4(0.0);
	return texelFetch(tx, p, 0);
}

void fragment() {
	ivec2 ts = textureSize(TEXTURE, 0);
	vec2 hp = floor(UV * vec2(ts) * 2.0);
	ivec2 ti = ivec2(floor(hp * 0.5));
	ivec2 q = ivec2(mod(hp, 2.0)) * 2 - 1;
	vec4 c = tf(TEXTURE, ti, ts);
	vec4 a = tf(TEXTURE, ti + ivec2(q.x, 0), ts);
	vec4 b = tf(TEXTURE, ti + ivec2(0, q.y), ts);
	bool cs = c.a > 0.01, as = a.a > 0.01, bs = b.a > 0.01;
	vec4 t = c;
	if (cs) {
		// 凸出来的尖角削掉（孤零零的一格不削，免得看不见）
		if (!as && !bs) {
			bool oa = tf(TEXTURE, ti - ivec2(q.x, 0), ts).a > 0.01;
			bool ob = tf(TEXTURE, ti - ivec2(0, q.y), ts).a > 0.01;
			if (oa && ob) discard;
		}
	} else {
		// 凹进去的直角填平
		if (as && bs) t = a; else discard;
	}
	vec2 w = floor(wpos * 2.0);
	int code = int(t.r * 255.0 / 30.0 + 0.5);
	float tint = code >= 4 ? 10.0 : 1.0;
	int v = code >= 4 ? code - 4 : code;
	vec2 ng = t.gb;
	if (cs && as) ng += (a.gb - c.gb) * 0.25;
	if (cs && bs) ng += (b.gb - c.gb) * 0.25;
	vec3 n;
	n.xy = ng * 2.0 - 1.0;
	n.z = sqrt(max(0.0, 1.0 - dot(n.xy, n.xy)));
	float L = amb * 0.6 + sun * max(0.0, dot(n, SUNV)) * 0.95;
	for (int i = 0; i < 24; i++) {
		if (i >= nlights) break;
		vec4 l = lights[i];
		vec2 d = l.xy - wpos;
		float d2 = dot(d, d);
		if (d2 >= l.z * l.z) continue;
		float kk = 1.0 - sqrt(d2) / l.z;
		float dd = (n.x * d.x + n.y * d.y + n.z * 16.0) / sqrt(d2 + 256.0);
		L += l.w * kk * kk * max(0.12, dd) * 1.3;
	}
	float grain = 0.9 + 0.2 * hash(w);
	float lv = floor(L * t.a * grain * 1.2 * 6.4 + bay(w) - 0.5);
	vec4 col;
	if (v == 2) {
		float p = sin(time * 2.2 + wpos.x * 0.21 + wpos.y * 0.13);
		float e = 3.0 + (p > 0.55 ? 2.0 : (p > -0.2 ? 1.0 : 0.0));
		col = rc(2.0, e >= lv ? e : lv);
	} else if (v == 3) {
		float e = max(lv, 2.0 + (sin(time * 1.3 + wpos.x * 0.3) > 0.3 ? 1.0 : 0.0));
		col = rc(3.0, e);
	} else {
		col = rc(tint, lv);
	}
	COLOR = col;
}
