class_name Rock
extends RefCounted
## 石头 / 书架：逐像素可破坏。每块有一张小贴图，
## R=材质和色调 G/B=法线 A=反照率，由 rock.gdshader 实时打光。

## 色调表（和 rock.gdshader 里的 TINT 一一对应）：下标 → 调色板材质
const TINTS := [1, 10, 15, 12, 14, 9, 13, 5]
const ZONE_TI := {"echo": 1, "stacks": 2, "hall": 3, "dark": 4, "ink": 5}

var x := 0
var y := 0
var R := 0
var c := 0                      # 中心到贴图边的距离（横向）
var ch := 0                     # 同上（纵向）
var S := 0                      # 贴图宽
var SH := 0                     # 贴图高
var x0 := 0
var y0 := 0
var m := PackedByteArray()      # 0 空 / 1 石 / 2 矿(页尘) / 3 余烬
var ti := PackedByteArray()     # 每个像素的色调下标
var alb := PackedFloat32Array()
var NX := PackedFloat32Array()
var NY := PackedFloat32Array()
var D := PackedFloat32Array()
var cnt := 0
var zone := ""
var tint := 1                   # 碎屑粒子用的材质
var box := false                # 书架（长方形）
var hw := 0
var hh := 0
var tex: ImageTexture
var spr: Sprite2D

func _alloc(px: int, py: int, cx: int, cy: int, zn: String) -> void:
	x = px
	y = py
	zone = zn
	c = cx
	ch = cy
	S = 2 * c + 1
	SH = 2 * ch + 1
	x0 = px - c
	y0 = py - ch
	var n := S * SH
	m.resize(n)
	ti.resize(n)
	alb.resize(n)
	NX.resize(n)
	NY.resize(n)
	D.resize(n)
	tint = TINTS[int(ZONE_TI.get(zn, 0))]

static func build(px: int, py: int, rad: int, zn: String, rng: RandomNumberGenerator) -> Rock:
	var r := Rock.new()
	r.R = rad
	r._alloc(px, py, rad + 3, rad + 3, zn)
	var S := r.S
	var tix := int(ZONE_TI.get(zn, 0))
	var sx := rng.randf() * 100.0
	var sy := rng.randf() * 100.0
	var oreP := 0.95 if zn == "nursery" else (0.96 if zn == "leech" or zn == "hall" else 0.968)
	var embP := 0.8 if zn == "drift" or zn == "dark" else (0.82 if zn == "shallow" or zn == "hall" else 0.86)
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
			r.ti[k] = tix
			r.cnt += 1
			r.alb[k] = 0.7 + 0.34 * Pal.fbm(wx * 0.21, wy * 0.21) - (0.12 if Pal.n2(wx * 0.09 + 5.0, wy * 0.09) > 0.68 else 0.0)
	r.calc_normals()
	r.rebuild_image()
	return r

## 书架：木框里插着一排颜色各异的书。发青光的书里夹着页尘，发橙光的夹着余烬。
static func build_box(px: int, py: int, hw_: int, hh_: int, zn: String, rng: RandomNumberGenerator) -> Rock:
	var r := Rock.new()
	r.box = true
	r.hw = hw_
	r.hh = hh_
	r.R = maxi(hw_, hh_)
	r._alloc(px, py, hw_ + 3, hh_ + 3, zn)
	r.tint = 15
	var horiz := hw_ >= hh_
	var n := (2 * hw_ + 1) if horiz else (2 * hh_ + 1)     # 沿着书架方向有多长
	var dep := (2 * hh_ + 1) if horiz else (2 * hw_ + 1)   # 书架有多深
	var u := 1
	while u < n - 1:
		var bw := 2 + (rng.randi() % 3)
		var gap := rng.randf() < 0.1
		var pick := rng.randf()
		var bt := 3
		if pick < 0.3:
			bt = 2
		elif pick < 0.45:
			bt = 6
		elif pick < 0.6:
			bt = 7
		elif pick < 0.72:
			bt = 4
		var bv := 1
		var sp := rng.randf()
		if sp < 0.07:
			bv = 2
		elif sp < 0.11:
			bv = 3
		var short := rng.randi() % 3
		var band := 2 + rng.randi() % maxi(1, dep - 5)
		for q in bw:
			if u + q >= n - 1:
				break
			for w in range(1, dep - 1):
				var i := (u + q + 3) if horiz else (w + 3)
				var j := (w + 3) if horiz else (u + q + 3)
				var k := j * r.S + i
				if gap or w <= short:
					r.m[k] = 1
					r.ti[k] = 2
					r.alb[k] = 0.32
				else:
					r.m[k] = bv
					r.ti[k] = bt
					r.alb[k] = (0.7 if q == 0 else 1.0) * (0.75 if w == band else 1.0) * (0.9 + 0.2 * rng.randf())
		u += bw
	# 木框
	for j in range(3, r.SH - 3):
		for i in range(3, r.S - 3):
			var k := j * r.S + i
			var edge := i == 3 or j == 3 or i == r.S - 4 or j == r.SH - 4
			if edge or r.m[k] == 0:
				r.m[k] = 1
				r.ti[k] = 2
				r.alb[k] = 0.62 if edge else 0.32
			r.cnt += 1
	r.calc_normals()
	r.rebuild_image()
	return r

func _h(k: int) -> float:
	return sqrt(minf(D[k], 10.0)) * 2.6

## 用距离场估算“鼓起来”的法线，挖掉一块后重新算
func calc_normals() -> void:
	for k in S * SH:
		D[k] = 99.0 if m[k] != 0 else 0.0
	for j in range(1, SH - 1):
		for i in range(1, S - 1):
			var k := j * S + i
			if D[k] == 0.0:
				continue
			D[k] = minf(D[k], minf(minf(D[k - 1] + 1.0, D[k - S] + 1.0), minf(D[k - S - 1] + 1.41, D[k - S + 1] + 1.41)))
	for j in range(SH - 2, 0, -1):
		for i in range(S - 2, 0, -1):
			var k := j * S + i
			if D[k] == 0.0:
				continue
			D[k] = minf(D[k], minf(minf(D[k + 1] + 1.0, D[k + S] + 1.0), minf(D[k + S + 1] + 1.41, D[k + S - 1] + 1.41)))
	var flat := 2.0 if box else 1.0
	for j in range(1, SH - 1):
		for i in range(1, S - 1):
			var k := j * S + i
			if m[k] == 0:
				continue
			var gx := (_h(k + 1) - _h(k - 1)) / flat
			var gy := (_h(k + S) - _h(k - S)) / flat
			var l := sqrt(gx * gx + gy * gy + 4.84)
			NX[k] = -gx / l
			NY[k] = -gy / l

func rebuild_image() -> void:
	var data := PackedByteArray()
	data.resize(S * SH * 4)
	for k in S * SH:
		var v := m[k]
		if v == 0:
			continue
		data[k * 4] = (v + 4 * ti[k]) * 8
		data[k * 4 + 1] = clampi(int((NX[k] + 1.0) * 127.5), 0, 255)
		data[k * 4 + 2] = clampi(int((NY[k] + 1.0) * 127.5), 0, 255)
		data[k * 4 + 3] = clampi(int(alb[k] / 1.2 * 255.0), 8, 255)
	var img := Image.create_from_data(S, SH, false, Image.FORMAT_RGBA8, data)
	if tex == null:
		tex = ImageTexture.create_from_image(img)
	else:
		tex.update(img)

func at(wx: int, wy: int) -> bool:
	var i := wx - x0
	var j := wy - y0
	if i < 0 or j < 0 or i >= S or j >= SH:
		return false
	return m[j * S + i] != 0
