// 共用：4x4 抖动 + 调色板取色
uniform sampler2D pal : filter_nearest;
float bay(vec2 p) {
	const float B[16] = float[16](0.,8.,2.,10.,12.,4.,14.,6.,3.,11.,1.,9.,15.,7.,13.,5.);
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	return (B[y * 4 + x] + 0.5) / 16.0;
}
vec4 rc(float m, float l) {
	return texelFetch(pal, ivec2(int(clamp(floor(l), 0.0, 6.0)), int(m)), 0);
}
