extends Node
## 全局工具：限定调色板（每种材质 7 阶）、4x4 抖动矩阵、噪声

enum { SPACE, ROCK, ORE, EMBER, CLAY, JELLY, MOTH, LEECH, ICE, GRAV, MIRROR, SERP, PAPER, GOLD, RUIN, WINE }

const RAMPS := [
	["#020208","#060714","#0b0d22","#131634","#1d2048","#2b2f63","#454a8a"],
	["#07060c","#14121f","#241f33","#383049","#524662","#73647f","#a493a8"],
	["#06121a","#0f2f3f","#1a5466","#2f8a98","#5fc4c8","#aeeee8","#f2fffc"],
	["#1a0904","#46170a","#83300f","#c55516","#f08a2a","#ffc66a","#fff2c8"],
	["#1c0a06","#4a1c10","#7e3420","#b4533a","#d97757","#f0a07e","#ffd9c2"],
	["#060a1c","#0f1d42","#1b3a6e","#2f63a0","#5b97cf","#a4cff0","#eef8ff"],
	["#0c0808","#251a1c","#433034","#6a4b4f","#94706e","#c09c94","#ecd8cc"],
	["#060c06","#132412","#22401c","#3a6626","#5f9334","#9cc45a","#e0f2a6"],
	["#06101a","#10283c","#1f4a66","#357896","#62acc4","#a8dcea","#effcff"],
	["#040208","#0e0718","#1c0e30","#33195a","#55308c","#8a5cc4","#d4b8ff"],
	["#0a0a0e","#1c1d26","#34363f","#555865","#82879a","#b7bccc","#f0f3fa"],
	["#12040e","#300a26","#561445","#87246a","#bc3f8e","#e57cb6","#ffd0e8"],
	["#0e0c08","#28231a","#4a4232","#77694f","#a8977a","#d6c8a8","#fbf4e2"],
	["#140a02","#3a1e06","#6e3a0a","#b06410","#e8981e","#ffd062","#fff6d0"],
	["#04040a","#090a14","#10121f","#181b2d","#22263d","#2e3350","#3e4466"],
	["#100406","#2a0a10","#4a1018","#701a22","#9a2a2c","#c4463c","#e87a62"],
]
const BAY := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var cols := PackedColorArray()
var bayf := PackedFloat32Array()
var pal_tex: ImageTexture
var _n := FastNoiseLite.new()
var _f := FastNoiseLite.new()

func _init() -> void:
	var img := Image.create(7, RAMPS.size(), false, Image.FORMAT_RGBA8)
	for m in RAMPS.size():
		for i in 7:
			var c := Color(RAMPS[m][i])
			cols.append(c)
			img.set_pixel(i, m, c)
	pal_tex = ImageTexture.create_from_image(img)
	for v in BAY:
		bayf.append((v + 0.5) / 16.0)
	_n.noise_type = FastNoiseLite.TYPE_VALUE
	_n.frequency = 1.0
	_n.fractal_type = FastNoiseLite.FRACTAL_NONE
	_n.seed = 7
	_f.noise_type = FastNoiseLite.TYPE_VALUE
	_f.frequency = 1.0
	_f.fractal_type = FastNoiseLite.FRACTAL_FBM
	_f.fractal_octaves = 4
	_f.fractal_lacunarity = 2.03
	_f.fractal_gain = 0.5
	_f.seed = 11

## 取材质 m 的第 l 阶颜色（0 暗 ~ 6 亮）
func rc(m: int, l: float) -> Color:
	var li := 0
	if l >= 6.0:
		li = 6
	elif l > 0.0:
		li = int(l)
	return cols[m * 7 + li]

func bay(x: int, y: int) -> float:
	return bayf[(y & 3) * 4 + (x & 3)]

func n2(x: float, y: float) -> float:
	return _n.get_noise_2d(x, y) * 0.5 + 0.5

func fbm(x: float, y: float) -> float:
	return _f.get_noise_2d(x, y) * 0.5 + 0.5
