class_name Rock
extends RefCounted
## 小行星：逐像素可破坏。每颗石头有一张小贴图，
## R=材质 G/B=法线 A=反照率，由 rock.gdshader 实时打光。

var x := 0
var y := 0
var R := 0
var c := 0
var S := 0
var x0 := 0
var y0 := 0
var m := PackedByteArray()      # 0 空 / 1 石 / 2 矿(页尘) / 3 余烬
var alb := PackedFloat32Array()
var NX := PackedFloat32Array()
var NY := PackedFloat32Array()
var D := PackedFloat32Array()
var cnt := 0
var zone := ""
var tint := 1
var tex: ImageTexture
var spr: Sprite2D

static func build(px: int, py: int, rad: int, zn: String, rng: RandomNumberGenerator) -> Rock:
	var r := Rock.new()
	r.x = px
	r.y = py
	r.R = rad
	r.zone = zn
	r.tint = 10 if zn == "echo" else 1
	r.c = rad + 3
	r.S = 2 * r.c + 1
	var S := r.S
	r.x0 = px - r.c
	r.y0 = py - r.c
	r.m.resize(S * S)
	r.alb.resize(S * S)
	r.NX.resize(S * S)
	r.NY.resize(S * S)
	r.D.resize(S * S)
	var sx := rng.randf() * 100.0
	var sy := rng.randf() * 100.0
	var oreP := 0.95 if zn == "nursery" else (0.96 if zn == "leech" else 0.968)
	var embP := 0.8 if zn == "drift" else (0.82 if zn == "shallow" else 0.86)
	for j in S:
		for i in S:
			var dx := float(i - r.c)
			var dy := float(j - r.c)
			var d := sqrt(dx * dx + dy * dy)
			if d > rad + 1.5:
				continue
			var ux := dx / d if d > 0.0 else 1.0
			var uy := dy / d if d > 0.0 else 0.0
			var rr := minf(rad + 1.0, rad * (0.74 + 0.34 * Pal.n2(ux * 1.3 + sx, uy * 1.3 + sy) + 0.1 * Pal.n2(ux * 4.0 + sx, uy * 4.0 + sy)))
			if d >= rr:
				continue
			var wx := px + dx
			var wy := py + dy
			var v := 1
			var vein := 1.0 - absf(2.0 * Pal.fbm(wx * 0.09 + sx, wy * 0.09) - 1.0)
			if vein > oreP and Pal.n2(wx * 0.08, wy * 0.08 + sy) > 0.45:
				v = 2
			if v == 1 and d < rr - 1.5 and Pal.n2(wx * 0.17 + sy, wy * 0.17) > embP + 0.1 * (1.0 - d / rr):
				v = 3
			var k := j * S + i
			r.m[k] = v
			r.cnt += 1
			r.alb[k] = 0.7 + 0.34 * Pal.fbm(wx * 0.21, wy * 0.21) - (0.12 if Pal.n2(wx * 0.09 + 5.0, wy * 0.09) > 0.68 else 0.0)
	r.calc_normals()
	r.rebuild_image()
	return r

func _h(k: int) -> float:
	return sqrt(minf(D[k], 10.0)) * 2.6

## 用距离场估算“鼓起来”的法线，挖掉一块后重新算
func calc_normals() -> void:
	for k in S * S:
		D[k] = 99.0 if m[k] != 0 else 0.0
	for j in range(1, S - 1):
		for i in range(1, S - 1):
			var k := j * S + i
			if D[k] == 0.0:
				continue
			D[k] = minf(D[k], minf(minf(D[k - 1] + 1.0, D[k - S] + 1.0), minf(D[k - S - 1] + 1.41, D[k - S + 1] + 1.41)))
	for j in range(S - 2, 0, -1):
		for i in range(S - 2, 0, -1):
			var k := j * S + i
			if D[k] == 0.0:
				continue
			D[k] = minf(D[k], minf(minf(D[k + 1] + 1.0, D[k + S] + 1.0), minf(D[k + S + 1] + 1.41, D[k + S - 1] + 1.41)))
	for j in range(1, S - 1):
		for i in range(1, S - 1):
			var k := j * S + i
			if m[k] == 0:
				continue
			var gx := _h(k + 1) - _h(k - 1)
			var gy := _h(k + S) - _h(k - S)
			var l := sqrt(gx * gx + gy * gy + 4.84)
			NX[k] = -gx / l
			NY[k] = -gy / l

func rebuild_image() -> void:
	var data := PackedByteArray()
	data.resize(S * S * 4)
	var tf := 4 if tint == 10 else 0
	for k in S * S:
		var v := m[k]
		if v == 0:
			continue
		data[k * 4] = (v + tf) * 30
		data[k * 4 + 1] = clampi(int((NX[k] + 1.0) * 127.5), 0, 255)
		data[k * 4 + 2] = clampi(int((NY[k] + 1.0) * 127.5), 0, 255)
		data[k * 4 + 3] = clampi(int(alb[k] / 1.2 * 255.0), 8, 255)
	var img := Image.create_from_data(S, S, false, Image.FORMAT_RGBA8, data)
	if tex == null:
		tex = ImageTexture.create_from_image(img)
	else:
		tex.update(img)

func at(wx: int, wy: int) -> bool:
	var i := wx - x0
	var j := wy - y0
	if i < 0 or j < 0 or i >= S or j >= S:
		return false
	return m[j * S + i] != 0
