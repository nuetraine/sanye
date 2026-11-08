// 暗潮 / 寒冷时画面四周压暗
shader_type canvas_item;
#include "res://shaders/common.gdshaderinc"
uniform float tide = 0.0;
uniform float cold = 0.0;

void fragment() {
	vec2 p = floor(UV * vec2(320.0, 180.0));
	vec2 d = (p - vec2(160.0, 90.0)) / vec2(160.0, 90.0);
	float v = dot(d, d);
	if (bay(p) < (v - 0.55) * 0.9 * max(tide, cold * 0.8)) {
		COLOR = cold > tide ? rc(8.0, 1.0) : rc(0.0, 0.0);
	} else {
		COLOR = vec4(0.0);
	}
}
