// 小行星打光：太阳 + 点光源，量化到 7 阶色板并抖动
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

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	if (t.a < 0.01) discard;
	vec2 w = floor(wpos);
	int code = int(t.r * 255.0 / 30.0 + 0.5);
	float tint = code >= 4 ? 10.0 : 1.0;
	int v = code >= 4 ? code - 4 : code;
	vec3 n;
	n.xy = t.gb * 2.0 - 1.0;
	n.z = sqrt(max(0.0, 1.0 - dot(n.xy, n.xy)));
	float L = amb * 0.6 + sun * max(0.0, dot(n, SUNV)) * 0.95;
	for (int i = 0; i < 24; i++) {
		if (i >= nlights) break;
		vec4 l = lights[i];
		vec2 d = l.xy - w;
		float d2 = dot(d, d);
		if (d2 >= l.z * l.z) continue;
		float kk = 1.0 - sqrt(d2) / l.z;
		float dd = (n.x * d.x + n.y * d.y + n.z * 16.0) / sqrt(d2 + 256.0);
		L += l.w * kk * kk * max(0.12, dd) * 1.3;
	}
	float lv = floor(L * t.a * 1.2 * 6.4 + bay(w) - 0.5);
	vec4 col;
	if (v == 2) {
		float p = sin(time * 2.2 + w.x * 0.21 + w.y * 0.13);
		float e = 3.0 + (p > 0.55 ? 2.0 : (p > -0.2 ? 1.0 : 0.0));
		col = rc(2.0, e >= lv ? e : lv);
	} else if (v == 3) {
		float e = max(lv, 2.0 + (sin(time * 1.3 + w.x * 0.3) > 0.3 ? 1.0 : 0.0));
		col = rc(3.0, e);
	} else {
		col = rc(tint, lv);
	}
	COLOR = col;
}
