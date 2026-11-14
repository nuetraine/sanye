extends "res://scripts/game_state.gd"
## 世界里的像素绘制：炉灯、生物、子弹、粒子、小克。
##
## 画面精细度是原型的两倍：一个“单位”= 2×2 个精细像素。
## 生物、炉灯、小克都先“烤”成小贴图（按动作帧、朝向缓存），之后每帧只贴图，
## 既清楚又省电。贴图里存的不是颜色而是“材质 + 明暗阶”，由 sprite.gdshader
## 按所在位置的光照挪动明暗阶后查色板。

class Spr:
	var tex: ImageTexture
	var ox := 0.0
	var oy := 0.0
	var w := 0.0
	var h := 0.0

var sprs := {}
var atlas: ImageTexture      # 14×16 的“单个像素”图集：x = 明暗阶（+7 为自发光），y = 材质
var _bd := PackedByteArray()
var _bw := 0
var _bh := 0
var _bcx := 0
var _bcy := 0

func make_atlas() -> void:
	var img := Image.create(14, 16, false, Image.FORMAT_RGBA8)
	for m in 16:
		for l in 7:
			img.set_pixel(l, m, Color8(m * 16 + 8, l * 36 + 18, 0, 255))
			img.set_pixel(l + 7, m, Color8(m * 16 + 8, l * 36 + 18, 255, 255))
	atlas = ImageTexture.create_from_image(img)

func _lv(l: float) -> int:
	return 6 if l >= 6.0 else (int(l) if l > 0.0 else 0)

# ---------- 烤贴图 ----------
## 在正在烤的贴图上点一个精细像素（x、y 是相对锚点的单位坐标）
func ip(x: float, y: float, m: int, l: float, e := false) -> void:
	ipx(floori(x * 2.0), floori(y * 2.0), m, l, e)

## 同上，但坐标直接是精细像素
func ipx(px: int, py: int, m: int, l: float, e := false) -> void:
	px += _bcx
	py += _bcy
	if px < 0 or py < 0 or px >= _bw or py >= _bh:
		return
	var k := (py * _bw + px) * 4
	_bd[k] = m * 16 + 8
	_bd[k + 1] = _lv(l) * 36 + 18
	_bd[k + 2] = 255 if e else 0
	_bd[k + 3] = 255

func bake(key: String, hw: float, hh: float, fn: Callable) -> Spr:
	var s: Spr = sprs.get(key)
	if s != null:
		return s
	_bcx = ceili(hw * 2.0)
	_bcy = ceili(hh * 2.0)
	_bw = _bcx * 2 + 1
	_bh = _bcy * 2 + 1
	_bd = PackedByteArray()
	_bd.resize(_bw * _bh * 4)
	fn.call()
	s = Spr.new()
	s.tex = ImageTexture.create_from_image(Image.create_from_data(_bw, _bh, false, Image.FORMAT_RGBA8, _bd))
	s.ox = -_bcx / 2.0
	s.oy = -_bcy / 2.0
	s.w = _bw / 2.0
	s.h = _bh / 2.0
	sprs[key] = s
	return s

# ---------- 往屏幕上画 ----------
func snap(v: float) -> float:
	return floorf(v * 2.0) / 2.0

func on_screen(x: float, y: float, mg := 20.0) -> bool:
	return no_cull or (x - ox > -mg and x - ox < W + mg and y - oy > -mg and y - oy < H + mg)

## 贴一张烤好的图。sh = 明暗偏移（光照），flash = 整体闪白，alpha < 1 用抖动表现半透明
func sd(s: Spr, x: float, y: float, sh := 0, flash := false, alpha := 1.0) -> void:
	cv.draw_texture_rect(s.tex, Rect2(snap(x) + s.ox, snap(y) + s.oy, s.w, s.h), false,
		Color((sh + 4) / 8.0, 1.0 if flash else 0.0, 1.0 if mono else 0.0, alpha))

## 画一个精细像素（sz 可以调大成一小块）
func sp(x: float, y: float, m: int, l: float, sh := 0, sz := 0.5) -> void:
	if not no_cull and (x < ox - 1 or x > ox + W + 1 or y < oy - 1 or y > oy + H + 1):
		return
	cv.draw_texture_rect_region(atlas, Rect2(snap(x), snap(y), sz, sz), Rect2(_lv(l), m, 1, 1),
		Color((sh + 4) / 8.0, 0.0, 1.0 if mono else 0.0, 1.0))

## 画一个实心矩形（单位坐标）
func sr(x: float, y: float, w: float, h: float, m: int, l: float, sh := 0) -> void:
	cv.draw_texture_rect_region(atlas, Rect2(snap(x), snap(y), w, h), Rect2(_lv(l), m, 1, 1),
		Color((sh + 4) / 8.0, 0.0, 1.0 if mono else 0.0, 1.0))

func shift_at(x: float, y: float) -> int:
	var L := light_at(x, y)
	if L >= 0.5:
		return 0
	if L >= 0.33:
		return -1
	if L >= 0.2:
		return -2
	return -3

# ---------- 通用：小球 ----------
func _p_ball(r: float, m: int, base: float) -> void:
	var R := ceili(r * 2.0)
	for jj in range(-R, R + 1):
		for ii in range(-R, R + 1):
			var x := ii * 0.5 + 0.25
			var y := jj * 0.5 + 0.25
			if x * x + y * y > r * r:
				continue
			var nx := x / r
			var ny := y / r
			var nz := sqrt(maxf(0.0, 1.0 - nx * nx - ny * ny))
			var L := nx * SUNV.x + ny * SUNV.y + nz * SUNV.z
			ipx(ii, jj, m, floorf(base + (L - 0.55) * 3.2 + Pal.bay(ii, jj) - 0.5))

func ball(cx: float, cy: float, r: float, m: int, base: float, sh: int, alpha := 1.0) -> void:
	r = maxf(0.5, roundf(r * 4.0) / 4.0)
	sd(bake("ball|%d|%d|%.2f" % [m, int(base), r], r + 0.5, r + 0.5, _p_ball.bind(r, m, base)), cx, cy, sh, false, alpha)

# ---------- 暖圈 ----------
func _draw_zones(c: CanvasItem) -> void:
	cv = c
	draw_ring(0, 0, kiln_r(), GOLD)
	for b in BEA:
		draw_ring(roundi(b.x), roundi(b.y), 56, EMBER)

## 暖圈：一圈缓缓转动的虚线 + 圈里稀疏的暗红点
func draw_ring(x: int, y: int, r: float, m: int) -> void:
	if not on_screen(x, y, r + 10):
		return
	var n := floori(r * TAU / 1.5)
	for i in n:
		if i % 6 >= 3:
			continue
		var a := float(i) / n * TAU + T * 0.05
		sp(x + cos(a) * r, y + sin(a) * r, m, 3 if i % 6 == 1 else 2)
	var R := ceili(r)
	var gy := y - R - posmod(y - R, 4)
	while gy <= y + R:
		var gx := x - R - posmod(x - R, 4)
		while gx <= x + R:
			var d := Vector2(gx - x, gy - y).length()
			if d < r and 0.03125 < 0.06 * (1 - d / r) * (0.5 + TIDE):
				sp(gx, gy, WINE, 2)
			gx += 4
		gy += 4

# ---------- 世界 ----------
func _draw_world(c: CanvasItem) -> void:
	cv = c
	draw_kiln()
	draw_beacons()
	draw_pages()
	draw_cocoon()
	draw_pickups()
	for cc in cr:
		if cc.dead or not on_screen(cc.x, cc.y, 30):
			continue
		var sh := shift_at(cc.x, cc.y)
		if cc.t == "moth":
			sh = maxi(-1, sh)
		if cc.flash > 0:
			sh = 2
		draw_creature(cc, sh)
	draw_bullets()
	draw_player()
	draw_particles()
	if S == "ending":
		draw_ending_world()

func draw_creature(cc: Creature, sh: int) -> void:
	match cc.t:
		"hush": draw_hush(cc, sh)
		"folio": draw_folio(cc, sh)
		"moth": draw_moth(cc, sh)
		"leech": draw_leech(cc, sh)
		"clam": draw_clam(cc, sh)
		"grav": draw_grav(cc, sh)
		"mite": draw_mite(cc, sh)
		"serp": draw_serp(cc, sh)

# ---------- 书页 ----------
func _p_page(s: float) -> void:
	var w := roundi(10 * s)
	var h := roundi(14 * s)
	var x0 := -w / 2
	var y0 := -h / 2
	for j in h:
		for i in w:
			# 右上角折角
			if i + (h - 1 - j) >= w + h - 3 and j < 2:
				continue
			var edge := i == 0 or j == 0 or i == w - 1 or j == h - 1
			var line := not edge and j >= 2 and j <= h - 3 and j % 3 == 2 and i >= 2 and i <= w - 3 - (2 if j % 6 == 5 else 0)
			var l := 6.0
			if line:
				l = 5
			elif i == w - 1 or j == h - 1:
				l = 4
			ipx(x0 + i, y0 + j, ORE if line else PAPER, l, true)
	ipx(x0 + w - 2, y0 + 1, PAPER, 4, true)
	ipx(x0 + w - 2, y0 + 2, PAPER, 4, true)
	ipx(x0 + w - 3, y0 + 2, PAPER, 4, true)

func draw_page_icon(x: float, y: float, s := 1.0) -> void:
	sd(bake("page|%.1f" % s, 3 * s + 0.5, 4 * s + 0.5, _p_page.bind(s)), x, y)

func draw_pages() -> void:
	for pg in PAGES:
		if pg.state != "free" or not on_screen(pg.x, pg.y, 30):
			continue
		var by := sin(T * 2) * 2
		draw_page_icon(pg.x, pg.y + by, 1.4)
		for i in 8:
			var a := T * 1.5 + i * TAU / 8
			sp(pg.x + cos(a) * 13, pg.y + by + sin(a) * 5, ORE, 5 + (i % 2), 0, 1.0 if i % 2 == 0 else 0.5)

func draw_cocoon() -> void:
	var pg: Dictionary = PAGES[2]
	if serp == null or (serp.st != "sleep" and serp.st != "rise"):
		return
	if not on_screen(pg.x, pg.y, 30):
		return
	var pul := sin(T * 1.6) * 1.2
	ball(pg.x, pg.y, 15 + pul, SERP, 3, 0, 0.75)
	draw_page_icon(pg.x, pg.y)
	for i in 20:
		var a := T * (0.6 + (i % 3) * 0.2) + i * 1.7
		var r := 10 + (i % 4) * 2.2
		sp(pg.x + cos(a) * r, pg.y + sin(a) * r * 0.7, ORE, 5 + (i % 2), 0, 1.0 if i % 5 == 0 else 0.5)

# ---------- 炉灯 ----------
func _p_kiln() -> void:
	# 石头底座
	for jj in range(8, 24):
		var y := jj * 0.5
		for ii in range(-30, 31):
			var x := ii * 0.5
			var w := 14 - (y - 4) * 1.6
			if absf(x) > w:
				continue
			var l := 3 - (y - 4) * 0.35 + (0.6 if x < 0 else -0.6) + Pal.bay(ii, jj)
			if y < 4.5:
				l += 1
			ipx(ii, jj, ROCK, l)
	# 砖砌的炉身
	for jj in range(-30, 10):
		var y := jj * 0.5 + 0.25
		for ii in range(-23, 23):
			var x := ii * 0.5 + 0.25
			var den := 12.0 if y < -3 else 8.0
			var e := x * x / 121.0 + (y + 3) * (y + 3) / (den * den)
			if e > 1:
				continue
			var L := (-x / 11.0) * 0.5 + (-(y + 3) / 12.0) * 0.6
			var l := floorf(3.3 + L * 1.6 + Pal.bay(ii, jj) - 0.5)
			var row := floori((y + 20) / 2.5)
			if fposmod(y + 20, 2.5) < 0.5:
				l -= 1
			elif posmod(ii + (row % 2) * 5, 10) == 0:
				l -= 1
			if e > 0.9:
				l = minf(l, 2) - (1 if x > 0 or y > 0 else 0)
			ipx(ii, jj, CLAY, l)
	# 烟囱
	for jj in range(-40, -24):
		for ii in range(2, 11):
			var cap := jj < -37
			if not cap and (ii < 3 or ii > 9):
				continue
			var l := 5 if ii < 5 else (3 if ii < 8 else 2)
			if cap:
				l += 1
			elif jj == -37:
				l -= 1
			ipx(ii, jj, CLAY, l)
	# 炉口的拱形边
	for jj in range(-12, 10):
		var y := jj * 0.5 + 0.25
		for ii in range(-10, 10):
			var x := ii * 0.5 + 0.25
			if _arch(x, y, 0.75) and not _arch(x, y, 0.0):
				ipx(ii, jj, CLAY, 1 if x > 0 else 5 if y < -3 else 2)

func _arch(x: float, y: float, grow: float) -> bool:
	if y < -5 - grow or y > 4.5:
		return false
	if y < -2:
		return absf(x) <= 4 + grow - (-2 - y) * 1.4
	return absf(x) <= 4 + grow

func draw_kiln() -> void:
	if not on_screen(0, 0, 40):
		return
	sd(bake("kiln", 16, 21, _p_kiln), 0, 0)
	# 炉火：每帧现算的噪声火苗
	for jj in range(-10, 9):
		var y := jj * 0.5 + 0.25
		for ii in range(-8, 8):
			var x := ii * 0.5 + 0.25
			if not _arch(x, y, 0.0):
				continue
			var f := Pal.n2(x * 0.6 + 3, y * 0.5 + T * 6) * 1.4 + (y + 5) / 9.0
			var l := floorf(f * 3.6 + 1 + Pal.bay(ii, jj) * 0.6)
			sp(x, y, GOLD if l >= 4 else EMBER, minf(6, l))
	for i in P.bound:
		var a := T * 0.8 + i * TAU / 3
		draw_page_icon(cos(a) * 22, -6 + sin(a) * 8)

# ---------- 信标 ----------
func _p_beacon() -> void:
	for jj in range(-12, 6):
		for ii in range(-3, 3):
			var l := 5 if ii < -1 else (3 if ii < 1 else 2)
			if posmod(jj, 4) == 0:
				l -= 1
			ipx(ii, jj, CLAY, l)
	for jj in range(-14, -12):
		for ii in range(-4, 4):
			ipx(ii, jj, CLAY, 4 if ii < 0 else 2)
	for jj in range(6, 8):
		for ii in range(-7, 7):
			ipx(ii, jj, ROCK, 4 if jj == 6 else 2)

func draw_beacons() -> void:
	for b in BEA:
		if not on_screen(b.x, b.y):
			continue
		var bx := snap(b.x)
		var by := snap(b.y)
		sd(bake("beacon", 4, 8, _p_beacon), bx, by, shift_at(b.x, b.y))
		if b.hp >= 3 or sin(T * 20) > 0:
			# 火苗：一个会晃的小水滴形
			for jj in range(-8, 0):
				var y := jj * 0.5
				var wd := 1.4 * sin((jj + 8) / 8.0 * PI * 0.85 + 0.35) + 0.2
				var sway := sin(T * 9 + jj * 0.5) * 0.4 * (-jj / 8.0)
				for ii in range(-4, 4):
					var x := ii * 0.5 + 0.25
					if absf(x - sway) > wd:
						continue
					var core := absf(x - sway) < wd * 0.45 and jj > -6
					sp(bx + x - 0.25, by - 7 + y, GOLD if core else EMBER, 6 if core else 5 - (1 if jj < -5 else 0))

# ---------- 引力胎 ----------
func _p_grav(f: int) -> void:
	for jj in range(-12, 12):
		for ii in range(-12, 12):
			var x := ii * 0.5 + 0.25
			var y := jj * 0.5 + 0.25
			var d := sqrt(x * x + y * y)
			if d > 5.6:
				continue
			if d > 4.3:
				var s := sin(f / 8.0 * TAU + atan2(y, x) * 3)
				ipx(ii, jj, GRAV, (6 if s > 0.5 else 5) - (1 if d > 5.1 else 0), true)
			else:
				ipx(ii, jj, GRAV, 0, true)

func draw_grav(c: Creature, _sh: int) -> void:
	var pts := []
	for k in 30:
		var r := 8 + (k % 6) * 1.9
		var a := c.age * (3.2 - (k % 6) * 0.35) + k * 0.83
		pts.append(Vector3(cos(a) * r, sin(a) * r * 0.42, r))
	for p in pts:
		if p.y < 0:
			sp(c.x + p.x, c.y + p.y, GOLD if p.z < 10 else GRAV, 5)
			sp(c.x + p.x + 0.5, c.y + p.y, EMBER if p.z < 10 else GRAV, 4)
	sd(bake("grav|%d" % (int(T * 5) % 8), 6, 6, _p_grav.bind(int(T * 5) % 8)), c.x, c.y)
	for p in pts:
		if p.y >= 0:
			sp(c.x + p.x, c.y + p.y, GOLD if p.z < 10 else GRAV, 6)
			sp(c.x + p.x + 0.5, c.y + p.y, EMBER if p.z < 10 else GRAV, 5)
	if c.flash > 0:
		ball(c.x, c.y, 4, PAPER, 6, 0)

# ---------- 镜螨 ----------
func _p_mite(ai: int, g: int) -> void:
	var ang := ai / 32.0 * TAU
	var fx := cos(ang)
	var fy := sin(ang)
	var gp := g / 8.0 * TAU
	for i in 3:
		for s in [-1.0, 1.0]:
			var t := -1.5 + i * 1.6
			var wob := 0.5 if sin(gp * 2 + i) > 0 else 0.0
			for q in 4:
				var rr := 4.6 + q * 0.4
				ip(fx * t - fy * s * rr, fy * t + fx * s * rr + wob, MOTH, 4 - q * 0.5)
	for jj in range(-10, 10):
		for ii in range(-10, 10):
			var x := ii * 0.5 + 0.25
			var y := jj * 0.5 + 0.25
			var d := sqrt(x * x + y * y)
			if d > 4.6:
				continue
			var dd := (x * fx + y * fy) / d
			if dd > -0.15 or d < 2:
				var glint := absf((x * -fy + y * fx) - sin(gp) * 4) < 0.6
				var l := 3 + (1 if dd > 0.6 else 0) + (1 if x + y < -1 else 0)
				if d > 4.0:
					l -= 1
				ipx(ii, jj, MIRROR, 6 if glint else l, glint)
			else:
				ipx(ii, jj, SERP, 5 if d < 3.2 else 3)

func draw_mite(c: Creature, sh: int) -> void:
	var ai := posmod(roundi(c.ang / TAU * 32.0), 32)
	var g := int(fposmod(T * 1.7, TAU) / TAU * 8.0) % 8
	sd(bake("mite|%d|%d" % [ai, g], 7, 7, _p_mite.bind(ai, g)), c.x, c.y, sh)
	if c.flash > 0:
		ball(c.x, c.y, 3, PAPER, 6, 0)

# ---------- 回声蛇 ----------
func draw_serp(c: Creature, sh: int) -> void:
	if c.st == "sleep" or c.st == "dead":
		return
	for i in range(c.seg.size() - 1, -1, -1):
		var sg := c.seg[i]
		ball(sg.x, sg.y, 4.2 - i * 0.12, SERP, 3, sh)
		sp(sg.x - 0.5, sg.y - 0.5, ORE, 6 if sin(T * 4 + i * 1.3) > 0.2 else 4, 0, 1.0)
	var fl := c.flash > 0
	ball(c.x, c.y, 6.2, PAPER if fl else SERP, 6 if fl else 4, 0)
	var fx := cos(c.ha)
	var fy := sin(c.ha)
	for s in [-1, 1]:
		var ex: float = c.x + fx * 2.5 - fy * s * 2.5
		var ey: float = c.y + fy * 2.5 + fx * s * 2.5
		sp(ex - 0.75, ey - 0.75, ORE, 6, 0, 1.5)
		sp(ex - 0.25 + fx * 0.4, ey - 0.25 + fy * 0.4, SERP, 0, 0, 0.5)
	for k in 8:
		var aa := T * 3 + k * TAU / 8
		sp(c.x + fx * 4.5 + cos(aa) * 1.8, c.y + fy * 4.5 + sin(aa) * 1.8, GOLD, 5 + (k % 2))

## 结局：图书馆第一层书架在炉灯上方显形
func draw_ending_world() -> void:
	var lv := mini(12, floori(end_t * 2))
	for i in lv:
		var w := 110 - i * 7
		var y := -24 - i * 11
		sr(-w / 2.0, y, w + 1, 0.5, ORE, 4)
		sr(-w / 2.0, y + 0.5, w + 1, 0.5, ORE, 2)
		for x in range(-w / 2, w / 2 + 1):
			if sin(T * 3 + x * 0.3 + i) > 0.6:
				sr(x, y, 1, 0.5, ORE, 6)
			if i % 2 == 0 and posmod(x, 9) == 0:
				sr(x, y + 1, 0.5, 10, ORE, 3)
		var x := -w / 2 + 2
		while x < w / 2 - 2:
			if _h1(i * 99 + x) > 0.4 and posmod(x, 9) != 0:
				var m := GOLD if _h1(i * 31 + x) > 0.5 else (WINE if _h1(i * 57 + x) > 0.6 else PAPER)
				var top := 2 + (1 if _h1(i * 13 + x) > 0.7 else 0)
				sr(x, y + top, 1.5, 11 - top, m, 2)
				sr(x, y + top, 0.5, 11 - top, m, 3)
				sr(x, y + top + 2, 1.5, 0.5, m, 4)
			x += 2
	for i in 3:
		var r := fmod(end_t * 40 + i * 60, 200.0)
		var a := 0.0
		while a < TAU:
			if randf() < 0.5:
				sp(cos(a) * r, sin(a) * r * 0.6, GOLD, 4)
			a += 0.02

func _h1(i: int) -> float:
	var h := (i * 374761393 + 668265263) & 0xffffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
	return float(h ^ (h >> 16)) / 4294967296.0

# ---------- 掉落物 / 子弹 / 粒子 ----------
func _p_wordpk(gold: bool, f: int) -> void:
	var m := GOLD if gold else PAPER
	for j in 10:
		for i in 8:
			if i + (9 - j) >= 15:
				continue
			var edge := i == 7 or j == 9
			var l := 4 if edge else (6 if gold and (i + j + f * 2) % 4 == 0 else 5)
			ipx(i - 4, j - 5, m, l, true)
	# 纸上的一个“字”
	for q in [[2, 2], [3, 2], [4, 2], [3, 3], [2, 4], [3, 4], [4, 4], [3, 5], [2, 6], [4, 6]]:
		ipx(q[0] - 4, q[1] - 5, ORE if not gold else WINE, 3, true)

func draw_pickups() -> void:
	for p in PK:
		if not on_screen(p.x, p.y):
			continue
		var tw := sin(T * 8 + p.age * 3) > 0
		if p.k == "word":
			var f := int(T * 6) % 2
			sd(bake("wordpk|%s|%d" % [p.gold, f], 2.5, 3, _p_wordpk.bind(p.gold, f)), p.x, p.y + sin(T * 3 + p.age) * 0.8)
			if tw:
				sp(p.x + 2.5, p.y - 3, GOLD if p.gold else ORE, 6)
		elif p.k == "dust":
			sp(p.x, p.y, ORE, 6 if tw else 5)
			sp(p.x + 0.5, p.y, ORE, 4 if tw else 3)
			sp(p.x - 0.5, p.y, ORE, 4 if tw else 3)
			sp(p.x, p.y + 0.5, ORE, 4 if tw else 3)
			sp(p.x, p.y - 0.5, ORE, 4 if tw else 3)
			if tw:
				sp(p.x + 1, p.y, ORE, 2)
				sp(p.x - 1, p.y, ORE, 2)
		else:
			sp(p.x - 0.5, p.y - 0.5, EMBER, 4, 0, 1.5)
			sp(p.x, p.y - 1, EMBER, 4)
			sp(p.x - 0.5, p.y - 0.5, EMBER, 6, 0, 1.0)
			sp(p.x, p.y, GOLD, 6 if tw else 5)

func draw_bullets() -> void:
	for b in PB:
		var l := maxf(0.0001, Vector2(b.vx, b.vy).length())
		var ux := b.vx / l
		var uy := b.vy / l
		var tail := 4 if b.small else 8
		for k in range(tail, 0, -1):
			sp(b.x - ux * k * 0.5, b.y - uy * k * 0.5, CLAY if k > 2 else b.mat, 6 - k * 0.5)
		if b.big:
			sp(b.x - 1, b.y - 1, b.mat, 4, 0, 2.0)
			sp(b.x - 0.5, b.y - 0.5, b.mat, 6, 0, 1.0)
		elif b.small:
			sp(b.x - 0.25, b.y - 0.25, b.mat, 6)
		else:
			sp(b.x - 0.5, b.y - 0.5, b.mat, 6, 0, 1.0)
			sp(b.x + ux * 0.5 - 0.25, b.y + uy * 0.5 - 0.25, PAPER, 6)
		if LO.get("gold", false) and int(T * 20 + b.x) % 5 == 0:
			sp(b.x - 1, b.y - 1, GOLD, 6)
	for b in EB:
		var fl := sin(T * 14 + b.x) > 0
		sp(b.x - 1, b.y - 0.5, b.m, 4, 0, 0.5)
		sp(b.x + 0.5, b.y - 0.5, b.m, 4, 0, 0.5)
		sp(b.x - 0.5, b.y - 1, b.m, 4, 0, 0.5)
		sp(b.x - 0.5, b.y + 0.5, b.m, 4, 0, 0.5)
		sp(b.x - 0.5, b.y - 0.5, b.m, 5 if fl else 6, 0, 1.0)
		sp(b.x - 0.5 if fl else b.x, b.y - 0.5, PAPER, 6)

func draw_particles() -> void:
	for p in PT:
		if not on_screen(p.x, p.y, 2):
			continue
		var k := p.life / p.mx
		var bx := floori(p.x * 2.0)
		var by := floori(p.y * 2.0)
		var l := floorf(p.l * (0.4 + 0.6 * k) + Pal.bay(bx, by) * 0.8)
		if not p.emit and k < 0.4 and Pal.bay(bx, by) > k * 2.5:
			continue
		sp(p.x, p.y, p.m, l, 0, 1.0 if p.emit and k > 0.55 else 0.5)

# ---------- 小克 ----------
func draw_player() -> void:
	if S == "dead" or S == "title" or S == "intro":
		return
	if P.inv > 0 and S == "play" and int(T * 16) % 2 == 0 and P.inv < 1.05:
		return
	var sy := P.y + sin(T * 3) * 0.8
	var ex := 1 if P.ax > 0.35 else (-1 if P.ax < -0.35 else 0)
	draw_clawd(P.x, sy, int(P.anim) % 2, ex, fmod(T, 3.7) < 0.12, P.warm < 25, P.dash_t > 0.12)
	for i in P.carry.size():
		var a := T * 2 + i * TAU / P.carry.size()
		draw_page_icon(P.x + cos(a) * 10, P.y + sin(a) * 6 - 2, 0.7)

## 小克：Claude 的橙色小吉祥物（26×16 精细像素）
func _p_clawd(fr: int, ex: int, blink: bool, frost: bool) -> void:
	for j in 16:
		for i in 26:
			var body := i >= 4 and i <= 21 and j <= 11
			var arm := (i < 4 or i > 21) and j >= 4 and j <= 7
			var leg := j >= 12 and (i >> 1) in [2, 4, 8, 10]
			if not (body or arm or leg):
				continue
			var l := 4
			if leg:
				var li := [2, 4, 8, 10].find(i >> 1)
				if j >= 14 and ((fr == 1 and li % 2 == 0) or (fr == 0 and li % 2 == 1)):
					continue
				l = 3 if i % 2 == 0 else 2
			elif arm:
				l = 4 if j <= 4 else 3
				if j == 7:
					l = 2
			else:
				if j <= 1:
					l = 5
				elif j >= 10:
					l = 3
				if i == 21 and j >= 2:
					l -= 1
				if i == 4 and j >= 2 and j <= 9:
					l = 5
				if j == 11:
					l = 2
			var m := CLAY
			if frost and j <= 2 and (i * 5 + j * 3) % 4 == 0:
				m = ICE
				l = 6
			ipx(i - 13, j - 8, m, l)
	var j0 := 6 if blink else 4
	for e in [8, 16]:
		for j in range(j0, 8):
			for i in 2:
				ipx(e + ex * 2 + i - 13, j - 8, CLAY, 0)

func draw_clawd(x: float, y: float, fr: int, ex: int, blink: bool, frost := false, flash := false) -> void:
	sd(bake("clawd|%d|%d|%s|%s" % [fr, ex, blink, frost], 6.5, 4, _p_clawd.bind(fr, ex, blink, frost)), x, y, 0, flash)

# ---------- 静默水母 ----------
func _p_hush(f: int) -> void:
	var ph := f / 12.0 * TAU
	var r := 6 + sin(ph) * 0.8
	for k in 5:
		var bx := -4.0 + k * 2
		for jj in 20:
			var j := jj * 0.5
			if k % 2 == 1 and jj % 4 >= 2:
				continue
			var x := bx + sin(ph + k + j * 0.6) * (j * 0.25)
			ip(x, 1.5 + j, JELLY, 4 - j * 0.35)
			if k % 2 == 0 and jj < 12:
				ip(x + 0.5, 1.5 + j, JELLY, 3 - j * 0.35)
	var R := ceili(r * 2.0) + 3
	for jj in range(-R, 4):
		for ii in range(-R, R):
			var x := ii * 0.5 + 0.25
			var y := jj * 0.5 + 0.25
			var e := x * x / ((r + 1) * (r + 1)) + y * y / (r * r)
			if e > 1:
				continue
			var edge := e > 0.7 or y > 1.0
			if not edge and Pal.bay(ii, jj) > 0.45:
				continue
			var l := 3
			if edge:
				l = 5 if y < -r * 0.4 else 4
				if e > 0.88 and x < 0 and y < 0:
					l = 6
			ipx(ii, jj, JELLY, l)
	for i in 4:
		var a := i * 1.9
		var lit := sin(ph * 2 + i * 2) > 0
		ip(cos(a) * 3, -2 + sin(a) * 1.6, JELLY, 6 if lit else 5, true)
		if lit:
			ip(cos(a) * 3 + 0.5, -2 + sin(a) * 1.6, JELLY, 5, true)

func draw_hush(c: Creature, sh: int) -> void:
	var f := int(fposmod(c.age * 2.2 + c.ph, TAU) / TAU * 12.0) % 12
	sd(bake("hush|%d" % f, 9, 13, _p_hush.bind(f)), c.x, c.y, sh)

# ---------- 书鳐 ----------
func _p_folio(ai: int, f: int) -> void:
	var a := ai / 24.0 * TAU
	var fx := cos(a)
	var fy := sin(a)
	var sx := -fy
	var sy := fx
	var ph := f / 8.0 * TAU
	var fl := sin(ph)
	var span := 8 * (0.45 + 0.55 * absf(fl))
	for kk in range(2, 16):
		var k := kk * 0.5
		var t := -4.0 - k
		var wob := sin(ph - k * 0.7) * 1.5
		ip(fx * t + sx * wob, fy * t + sy * wob, WINE, 5 - k * 0.3)
	var t := -3.5
	while t <= 3.5:
		for sd_ in [-1.0, 1.0]:
			var u := 0.0
			while u <= 1.001:
				var cover := u > 0.86 or absf(t) > 3.15
				var lit := 1 if sd_ * fl > 0 else 0
				var stripe := int(floorf(t * 2.0 + 20.0)) % 2
				var l := (3 + lit) if cover else (4 + lit + (0 if stripe else -1) + (1 if u < 0.25 else 0))
				ip(fx * t + sx * sd_ * u * span, fy * t + sy * sd_ * u * span, WINE if cover else PAPER, l)
				u += 0.04
		t += 0.2
	t = -4.0
	while t <= 4.0:
		ip(fx * t, fy * t, WINE, 2)
		ip(fx * t + sx * 0.5, fy * t + sy * 0.5, WINE, 2)
		t += 0.25

func draw_folio(c: Creature, sh: int) -> void:
	var ai := posmod(roundi(atan2(c.vy, c.vx) / TAU * 24.0), 24)
	var f := int(fposmod(c.age * 7 + c.ph, TAU) / TAU * 8.0) % 8
	sd(bake("folio|%d|%d" % [ai, f], 13, 13, _p_folio.bind(ai, f)), c.x, c.y, sh)
	if c.flash > 0:
		ball(c.x, c.y, 4, PAPER, 6, 0)

# ---------- 蚀字蛾 ----------
const MOTH_A := ["W........W", "WW......WW", "wWW.EE.WWw", ".wWWBBWWw.", "..wwBBww..", "....bb...."]
const MOTH_B := ["....EE....", ".wWWBBWWw.", "WWWWBBWWWW", "Ww..bb..wW", "w........w"]

func _p_moth(fr: int, burn: bool) -> void:
	var pat: Array = MOTH_A if fr == 0 else MOTH_B
	var b := EMBER if burn else MOTH
	for j in pat.size():
		var row: String = pat[j]
		for i in row.length():
			match row[i]:
				"W": ipx(i - 5, j - 3, b, 5)
				"w": ipx(i - 5, j - 3, b, 4)
				"B": ipx(i - 5, j - 3, b, 4)
				"b": ipx(i - 5, j - 3, b, 3)
				"E": ipx(i - 5, j - 3, SERP, 6, true)

func draw_moth(c: Creature, sh: int) -> void:
	var fr := int(c.age * 24) % 2
	var burn := c.st == "burn"
	sd(bake("moth|%d|%s" % [fr, burn], 3, 2, _p_moth.bind(fr, burn)), c.x, c.y, sh)

# ---------- 轨道蛭 ----------
func draw_leech(c: Creature, sh: int) -> void:
	var n := c.tr.size() / 2
	var red := c.st == "wind"
	var shake := (randf() - 0.5) * 2 if red else 0.0
	var k := 0
	while k < n:
		ball(c.tr[k * 2] + shake, c.tr[k * 2 + 1], 1 + float(k) / n * 1.8, LEECH, 3, sh)
		k += 2
	ball(c.x + shake, c.y, 3.2, EMBER if red else LEECH, 5 if red else 4, 0 if red else sh)
	sp(c.x + shake - 0.5, c.y - 0.5, WINE, 6 if red else 2, 0, 1.0)
	sp(c.x + shake - 0.5, c.y - 0.5, PAPER if red else WINE, 6 if red else 4)

# ---------- 冰核贝 ----------
func _p_clam(ai: int, oi: int, pearl: bool) -> void:
	var na := ai / 32.0 * TAU
	var ta := na + PI / 2
	var tx := cos(ta)
	var ty := sin(ta)
	var nx := cos(na)
	var ny := sin(na)
	var op := oi / 6.0 * 3
	var u := -5.0
	while u <= 5.0:
		var hh := 3.4 * sqrt(maxf(0.0, 1 - pow(u / 5.3, 2)))
		var rib := int(floorf(u * 1.0 + 20.0)) % 2 == 0
		var v := 0.0
		while v <= hh + op + 0.01:
			var l := -1.0
			if v <= hh * 0.5:
				l = 2 + (0 if rib else 1)
			elif v >= hh * 0.5 + op:
				l = 4 + (0 if rib else 1) - (1 if v > hh + op - 0.5 else 0)
				if v < hh * 0.5 + op + 0.5:
					l = 6
			if l >= 0:
				ip(tx * u + nx * v, ty * u + ny * v, ICE, l)
			v += 0.25
		u += 0.25
	if pearl:
		var px := nx * (1.7 + op * 0.5)
		var py := ny * (1.7 + op * 0.5)
		for jj in range(-2, 2):
			for ii in range(-2, 2):
				if absi(ii * 2 + 1) + absi(jj * 2 + 1) > 5:
					continue
				ip(px + ii * 0.5, py + jj * 0.5, GOLD if ii + jj < -1 else EMBER, 6 if ii + jj < 0 else 5, true)

func draw_clam(c: Creature, sh: int) -> void:
	var ai := posmod(roundi(c.na / TAU * 32.0), 32)
	var oi := clampi(roundi(c.open * 6.0), 0, 6)
	var pearl := c.st != "empty" and c.open > 0.2
	sd(bake("clam|%d|%d|%s" % [ai, oi, pearl], 8, 8, _p_clam.bind(ai, oi, pearl)), c.x, c.y, sh)
	if c.flash > 0:
		sp(c.x - 0.5, c.y - 0.5, PAPER, 6, 0, 1.0)
