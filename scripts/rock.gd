class_name Rock
extends RefCounted
## 石头 / 书架：逐像素可破坏。每块有一张小贴图，
## R=材质和色调 G/B=法线 A=反照率，由 rock.gdshader 实时打光。

## 色调表（和 rock.gdshader 里的 TINT 一一对应）：下标 → 调色板材质
## 8 = 金箔矿、9 = 字晶（这两个只给矿脉用），10 冰晶 11 陶土 12 灰页 13 苔 14 粉晶 15 青晶
const TINTS := [1, 10, 15, 12, 14, 9, 13, 5, 13, 9, 8, 4, 6, 7, 11, 2]
const ZONE_TI := {"echo": 1, "stacks": 2, "hall": 3, "dark": 4, "ink": 5, "gear": 1, "tower": 3, "flare": 6, "wind": 3}
const ORE_GOLD := 8
const ORE_WORD := 9
## 石头的样子：普通 / 长条 / 陨坑 / 页岩 / 熔岩 / 陨铁 / 晶簇 / 晶洞 / 苔石
const KIND_NAME := {"lump": "碎石", "potato": "长条石", "crater": "陨坑石", "shale": "页岩", "magma": "熔岩石",
	"iron": "陨铁", "crystal": "晶簇", "geode": "晶洞", "moss": "苔石"}

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
var kind := "lump"
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

static func pick_kind(zn: String, rad: int, rng: RandomNumberGenerator) -> String:
	var w := {"lump": 30.0, "potato": 16.0, "crater": 14.0, "shale": 7.0, "magma": 5.0, "iron": 4.0, "crystal": 4.0, "geode": 2.0, "moss": 0.0}
	match zn:
		"belt":
			w = {"lump": 6.0, "potato": 8.0, "crater": 8.0, "shale": 4.0, "magma": 8.0, "iron": 16.0, "crystal": 22.0, "geode": 20.0, "moss": 0.0}
		"nursery":
			w.moss = 24.0
		"shallow":
			w.moss = 8.0
		"hall", "stacks", "tower", "wind":
			w.shale = 30.0
		"flare":
			w.magma = 34.0
		"gear":
			w.iron = 26.0
		"dark":
			w.crystal = 18.0
		"echo":
			w.crater = 28.0
			w.iron = 8.0
		"drift":
			w.crater += 10.0
			w.iron += 4.0
	if rad < 11:
		w.geode = 0.0
	if rad < 8:
		w.crystal = 0.0
	var tot := 0.0
	for k in w:
		tot += w[k]
	var r := rng.randf() * tot
	for k in w:
		r -= w[k]
		if r <= 0.0:
			return k
	return "lump"

static func build(px: int, py: int, rad: int, zn: String, rng: RandomNumberGenerator, force_kind := "") -> Rock:
	var r := Rock.new()
	r.R = rad
	r._alloc(px, py, rad + 3, rad + 3, zn)
	var S := r.S
	var kind := force_kind if force_kind != "" else pick_kind(zn, rad, rng)
	r.kind = kind
	var tix := int(ZONE_TI.get(zn, 0))
	match kind:
		"iron":
			tix = 1
		"magma":
			tix = 4
		"crystal":
			tix = 5 if zn == "dark" or zn == "ink" else ([10, 10, 14, 15][rng.randi() % 4])
		"geode":
			tix = 0 if tix == 6 else tix
	r.tint = TINTS[tix]
	var sx := rng.randf() * 100.0
	var sy := rng.randf() * 100.0
	var oreP := 0.95 if zn == "nursery" or zn == "belt" else (0.96 if zn == "leech" or zn == "hall" else 0.968)
	var embP := 0.8 if zn == "drift" or zn == "dark" else (0.82 if zn == "shallow" or zn == "hall" else 0.86)
	if kind == "iron":
		oreP = 0.985
		embP = 9.0
	if kind == "crystal":
		embP = 9.0
	# 矿脉的种类：大多是青色页尘，偶尔是金箔（页尘多）或字晶（可能敲出字）
	var ore_ti := tix
	var orr := rng.randf()
	if zn == "belt":
		orr *= 0.55
	if orr < 0.1:
		ore_ti = ORE_GOLD
	elif orr < 0.16 and rad >= 9:
		ore_ti = ORE_WORD
	if kind == "geode":
		ore_ti = [tix, ORE_GOLD, ORE_GOLD, ORE_WORD][rng.randi() % 4]
	var rot := rng.randf() * PI
	var ratio := 0.55 + rng.randf() * 0.2
	var craters := []
	var ncr := 0
	if kind == "crater":
		ncr = 2 + rng.randi() % 4
	elif kind == "lump" or kind == "potato" or kind == "iron":
		ncr = rng.randi() % 2
	for q in ncr:
		var ca := rng.randf() * TAU
		var cd := rng.randf() * rad * 0.85
		craters.append(Vector3(cos(ca) * cd, sin(ca) * cd, rad * (0.18 + rng.randf() * 0.22)))
	var spikes := []
	if kind == "crystal":
		var n := 5 + rng.randi() % 4
		for q in n:
			spikes.append(Vector3(q * TAU / n + rng.randf() * 0.5, 0.65 + rng.randf() * 0.35, 0.28 + rng.randf() * 0.15))
	var band_a := rng.randf() * PI
	var band_w := 1.6 + rng.randf() * 1.2
	var band_ti: int = [11, 12, 4, 0][rng.randi() % 4]
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
			var dd := d
			var facet := 0
			match kind:
				"potato":
					var ex := dx * cos(rot) + dy * sin(rot)
					var ey := (-dx * sin(rot) + dy * cos(rot)) / ratio
					dd = sqrt(ex * ex + ey * ey)
					var ua := atan2(ey, ex)
					rr = minf(rad + 1.0, rad * (0.8 + 0.25 * Pal.n2(cos(ua) * 1.5 + sx, sin(ua) * 1.5 + sy)))
				"iron":
					rr = minf(rad + 1.0, rad * (0.84 + 0.16 * Pal.n2(ux * 0.9 + sx, uy * 0.9 + sy)))
				"crystal":
					var a := atan2(dy, dx)
					var best := 0.42
					for q in spikes.size():
						var sp: Vector3 = spikes[q]
						var t := 1.0 - absf(angle_difference(a, sp.x)) / sp.z
						if t > 0.0:
							var v2 := 0.42 + (sp.y - 0.42) * t
							if v2 > best:
								best = v2
								facet = q * 2 + (1 if angle_difference(a, sp.x) > 0.0 else 0)
					rr = rad * best + 0.6
			if dd >= rr:
				continue
			# 陨坑咬掉边缘
			var in_cr := -1.0
			for q in craters.size():
				var cv: Vector3 = craters[q]
				var cdist := Vector2(dx - cv.x, dy - cv.y).length() / cv.z
				if cdist < 1.0:
					in_cr = maxf(in_cr, cdist)
					if kind == "crater" and Vector2(cv.x, cv.y).length() > rad * 0.62 and cdist < 0.75:
						in_cr = 9.0
			if in_cr > 8.0:
				continue
			var wx := px + dx
			var wy := py + dy
			var v := 1
			var k := j * S + i
			var pti := tix
			var alb := 0.7 + 0.34 * Pal.fbm(wx * 0.21, wy * 0.21) - (0.12 if Pal.n2(wx * 0.09 + 5.0, wy * 0.09) > 0.68 else 0.0)
			var vein := 1.0 - absf(2.0 * Pal.fbm(wx * 0.09 + sx, wy * 0.09) - 1.0)
			if vein > oreP and Pal.n2(wx * 0.08, wy * 0.08 + sy) > 0.45:
				v = 2
			if v == 1 and d < rr - 1.5 and Pal.n2(wx * 0.17 + sy, wy * 0.17) > embP + 0.1 * (1.0 - d / rr):
				v = 3
			match kind:
				"magma":
					var crack := 1.0 - absf(2.0 * Pal.fbm(wx * 0.14 + sy, wy * 0.14 + sx) - 1.0)
					alb *= 0.72
					if crack > 0.9 and d < rr - 1.0:
						v = 3
				"iron":
					var wm := absf(sin(wx * 0.9 + wy * 0.5)) < 0.18 or absf(sin(wx * 0.2 - wy * 1.0)) < 0.18 or absf(sin(-wx * 0.75 + wy * 0.6)) < 0.18
					alb = 0.9 + (0.18 if wm else 0.0) - 0.15 * d / rr
				"crystal":
					alb = 0.72 + (0.32 if facet % 2 == 0 else 0.0) + 0.2 * (d / rr)
					if v == 2 or rng.randf() < 0.03:
						v = 2
						ore_ti = ORE_GOLD if ore_ti == tix else ore_ti
				"shale":
					var bu := (dx * cos(band_a) + dy * sin(band_a)) / band_w + Pal.n2(wx * 0.15, wy * 0.15) * 1.5
					pti = 3 if int(floorf(bu)) % 2 == 0 else band_ti
					alb *= 0.9 + (0.15 if int(floorf(bu * 2.0)) % 3 == 0 else 0.0)
				"moss":
					if -(ux * 0.6 + uy * 0.8) > 0.15 and d > rr * 0.45 and Pal.n2(wx * 0.3 + sx, wy * 0.3) > 0.35:
						pti = 13
				"geode":
					if d < rr - 3.0:
						v = 2
						alb = 0.6 + 0.5 * (d / rr) + (0.2 if Pal.bay(i, j) > 0.7 else 0.0)
					else:
						v = 1
						alb *= 0.85
			if in_cr >= 0.0:
				alb *= 0.55 + 0.2 * in_cr if in_cr < 0.8 else 1.25
			r.m[k] = v
			r.ti[k] = ore_ti if v == 2 else pti
			r.cnt += 1
			r.alb[k] = alb
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
		data[k * 4] = (v + 4 * ti[k]) * 4
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
