// 精灵：贴图里存的是“材质 + 明暗阶”，这里按光照把明暗阶挪一挪再查色板
// 顶点颜色：r = 明暗偏移（(偏移+4)/8），g = 整体闪白，b = 单色剪影，a = 抖动透明度
shader_type canvas_item;
#include "res://shaders/common.gdshaderinc"
varying vec4 vc;
varying vec2 wpos;

void vertex() {
	vc = COLOR;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	if (t.a < 0.5) discard;
	if (vc.a < 0.99 && bay(floor(wpos * 2.0)) > vc.a) discard;
	// alpha 约 200：这是一张直接存颜色的图（比如蓝色大肥鱼），按光照稍微压暗一点就行
	if (t.a < 0.9) {
		vec4 tc = vec4(t.rgb * (1.0 + 0.12 * (floor(vc.r * 8.0 + 0.5) - 4.0)), 1.0);
		if (vc.g > 0.5) tc = rc(12.0, 6.0);
		if (vc.b > 0.5) tc = rc(14.0, 3.0);
		COLOR = tc;
	} else {
	float m = floor(t.r * 255.0 / 16.0);
	float l = floor(t.g * 255.0 / 36.0);
	if (t.b < 0.5) l = clamp(l + floor(vc.r * 8.0 + 0.5) - 4.0, 0.0, 6.0);
	vec4 col = rc(m, l);
	if (vc.g > 0.5) col = rc(12.0, 6.0);
	if (vc.b > 0.5) col = rc(14.0, 3.0);
	COLOR = col;
	}
}
