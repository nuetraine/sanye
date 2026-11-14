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
	for q in INK:
		if not on_screen(q.x, q.y, q.z + 6):
			continue
		sd(bake("ink|%d" % int(q.z), q.z + 2, q.z + 2, _p_ink.bind(q.z)), q.x, q.y)
		# 墨面上慢慢游动的反光
		for i in 7:
			var a: float = T * (0.25 + i * 0.03) + i * 1.9 + q.x
			var rr: float = q.z * (0.25 + 0.09 * i)
			sp(q.x + cos(a) * rr, q.y + sin(a * 1.3) * rr * 0.8, GRAV, 4 if i % 2 == 0 else 3, 0, 1.0 if i % 3 == 0 else 0.5)
	draw_zones3()
	draw_ring(0, 0, kiln_r(), GOLD)
	for b in BEA:
		draw_ring(roundi(b.x), roundi(b.y), 56, EMBER)
	for l in LAMPS:
		if l.lit > 0:
			draw_ring(roundi(l.x), roundi(l.y), 40, GOLD)

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
	draw_lamps()
	draw_pages()
	draw_cocoon()
	draw_pickups()
	for cc in cr:
		if cc.dead or not on_screen(cc.x, cc.y, 40):
			continue
		var sh := shift_at(cc.x, cc.y)
		if cc.t == "moth":
			sh = maxi(-1, sh)
		if cc.flash > 0:
			sh = 2
		draw_creature(cc, sh)
		if cc.mark > 0 and sin(T * 12) > -0.4:
			# “蚀”的记号
			sp(cc.x - 0.5, cc.y - cc.r - 5, GRAV, 6, 0, 1.0)
			sp(cc.x - 0.25, cc.y - cc.r - 6, GRAV, 5)
			sp(cc.x - 0.25, cc.y - cc.r - 3.5, GRAV, 5)
	draw_hazards()
	draw_hazards3()
	draw_bullets()
	draw_bombs()
	draw_player()
	draw_aim()
	draw_fx()
	draw_skill_fx()
	draw_particles()
	draw_flare()
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
		"comma": draw_comma(cc, sh)
		"blot", "blotlet": draw_blot(cc, sh)
		"worm": draw_worm(cc, sh)
		"wisp": draw_wisp(cc, sh)
		"redact": draw_redact(cc, sh)
		"dove": draw_dove(cc, sh)
		"tick": draw_tick(cc, sh)
		"cinder": draw_cinder(cc, sh)
		"chill": draw_chill(cc, sh)
		"icicle": draw_icicle(cc, sh)
		"mothq": draw_mothq(cc, sh)
		"stamp": draw_stamp(cc, sh)
		"binder": draw_binder(cc, sh)

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
		var a := T * 0.8 + i * TAU / maxi(3, P.bound)
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
	draw_pc(P.ch, P.x, sy, int(P.anim) % 2, ex, fmod(T, 3.7) < 0.12, P.warm < 25, P.dash_t > 0.12)
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

func _p_ink(r: float) -> void:
	# 墨池：边缘不规则的一摊黑，边上一圈发紫
	var R := ceili(r * 2.0)
	for jj in range(-R, R):
		for ii in range(-R, R):
			var x := ii * 0.5 + 0.25
			var y := jj * 0.5 + 0.25
			var d := sqrt(x * x + y * y)
			var a := atan2(y, x)
			var rr := r * (0.84 + 0.16 * Pal.n2(cos(a) * 2.2 + r, sin(a) * 2.2))
			if d > rr:
				continue
			if d > rr - 1.0:
				ipx(ii, jj, GRAV, 3)
			elif d > rr - 2.5:
				ipx(ii, jj, GRAV, 2 if Pal.bay(ii, jj) > 0.4 else 1)
			else:
				var n := Pal.n2(x * 0.22 + r, y * 0.22)
				ipx(ii, jj, GRAV if n > 0.62 else SPACE, 1 if n > 0.62 else 0)

func _p_lamp(lit: bool) -> void:
	for jj in range(-16, 9):
		for ii in range(-1, 1):
			ipx(ii, jj, MIRROR, 3 if ii < 0 else 2)
	for jj in range(9, 11):
		for ii in range(-5, 5):
			ipx(ii, jj, MIRROR, 3 if jj == 9 else 1)
	for jj in range(-26, -16):
		for ii in range(-5, 5):
			var edge := ii == -5 or ii == 4 or jj == -26 or jj == -17
			if edge:
				ipx(ii, jj, MIRROR, 4 if ii < 0 or jj == -26 else 2)
			elif lit:
				var core := absi(ii * 2 + 1) < 5 and jj > -24
				ipx(ii, jj, GOLD if core else EMBER, 6 if core else 5, true)
			else:
				ipx(ii, jj, RUIN, 3 if (ii + jj) % 3 else 4)
	for ii in range(-3, 3):
		ipx(ii, -27, MIRROR, 3)
	ipx(-1, -28, MIRROR, 4)
	ipx(0, -28, MIRROR, 3)

func draw_lamps() -> void:
	for l in LAMPS:
		if not on_screen(l.x, l.y, 20):
			continue
		var lit: bool = l.lit > 0 and (l.lit > 6 or sin(T * 18) > 0)
		sd(bake("lamp|%s" % lit, 3.5, 15, _p_lamp.bind(lit)), l.x, l.y, 0 if lit else maxi(-2, shift_at(l.x, l.y)))
		if lit:
			for i in 3:
				var a: float = T * 2.0 + i * 2.1
				sp(l.x + cos(a) * 4, l.y - 10.5 + sin(a) * 3, GOLD, 5)

func draw_hazards() -> void:
	for h in HZ:
		var ca := cos(h.a)
		var sa := sin(h.a)
		if h.t > 0:
			# 预告：一条闪烁的细虚线，越接近落下越密
			var gap := 3 if h.t > 0.35 else 1
			var u: float = -h.len
			var i := 0
			while u <= h.len:
				if (i + int(T * 14)) % (gap + 2) < 2:
					sp(h.x + ca * u, h.y + sa * u, WINE, 6)
				u += 1.0
				i += 1
		elif h.dmg:
			# 删除线落下：一道粗黑杠，中间一线白
			var k: float = 1.0 + h.t / 0.3
			var w: float = maxf(1.0, h.w * 2.0 * k)
			var u: float = -h.len
			while u <= h.len:
				var x: float = h.x + ca * u
				var y: float = h.y + sa * u
				if on_screen(x, y, 8):
					sr(x - w / 2.0, y - w / 2.0, w, w, SPACE, 0)
				u += 2.0
			u = -h.len
			while u <= h.len:
				sp(h.x + ca * u - 0.5, h.y + sa * u - 0.5, PAPER if k > 0.5 else WINE, 6, 0, 1.0)
				u += 1.0

func draw_bombs() -> void:
	for b in BM:
		ball(b.x, b.y, 2.5, GRAV, 3, 0)
		sp(b.x - 1, b.y - 1, PAPER, 6)
		sp(b.x - b.vx * 0.02, b.y - b.vy * 0.02 - 2, GOLD if sin(T * 40) > 0 else EMBER, 6)

func draw_fx() -> void:
	for f in FX:
		var k: float = f.t / f.max
		match f.k:
			"slash":
				# 一弯刀光，从一头扫到另一头
				var n := 34 if f.get("w", 1.0) < 1.2 else (48 if f.get("w", 1.0) < 3.0 else 90)
				for i in n:
					var u := float(i) / (n - 1)
					if absf(u - (1.0 - k)) > (0.4 if f.get("w", 1.0) < 3.0 else 0.6):
						continue
					var fw: float = f.get("w", 1.0)
					var a: float = f.a - fw + 2.0 * fw * u
					if f.get("back", false):
						a = f.a + fw - 2.0 * fw * u
					var thick := 1.0 - absf(u - (1.0 - k)) / 0.4
					for q in 4:
						var rr: float = f.r * (0.66 + q * 0.11)
						if q < 3 and thick < 0.3 + q * 0.15:
							continue
						sp(f.x + cos(a) * rr - 0.5, f.y + sin(a) * rr - 0.5, PAPER if q == 3 else f.m, 6 if q >= 2 else 4 + q, 0, 1.0)
			"boom":
				var rr: float = f.r * (1.0 - k * 0.75)
				var n := int(rr * 5)
				for i in n:
					var a := float(i) / n * TAU
					if Pal.bay(i, i / 4) > k + 0.25:
						continue
					sp(f.x + cos(a) * rr - 0.5, f.y + sin(a) * rr - 0.5, f.m, 6, 0, 1.0)
					sp(f.x + cos(a) * rr * 0.86, f.y + sin(a) * rr * 0.86, PAPER, 6)
					if i % 3 == 0:
						sp(f.x + cos(a) * rr * 0.6, f.y + sin(a) * rr * 0.6, f.m, 4)
			"beam":
				var dv := Vector2(f.x1 - f.x, f.y1 - f.y)
				var L := maxf(0.001, dv.length())
				var u := dv / L
				var w: float = maxf(0.5, snap(f.w * 2.0 * k + 0.5))
				var s := 0.0
				while s < L:
					var px: float = f.x + u.x * s
					var py: float = f.y + u.y * s
					if on_screen(px, py, 6):
						sr(px - w / 2.0, py - w / 2.0, w, w, f.m, 6 if k > 0.5 else 5)
						if w > 1.0:
							sp(px - 0.25, py - 0.25, PAPER, 6)
					s += maxf(0.5, w * 0.5)

func draw_aim() -> void:
	# 砚雷的落点 / 墨线的蓄力
	if S != "play":
		return
	if P.pen == 3 and not touch_mode:
		var d := clampf(P.aim_d, 30.0, bomb_range())
		var x := P.x + P.ax * d
		var y := P.y + P.ay * d
		for i in 4:
			var a := i * PI / 2 + T * 2
			sp(x + cos(a) * 3, y + sin(a) * 3, GOLD, 5)
	if P.pen == 4 and P.charge > 0:
		var m := pen_mat()
		var n := int(8 + 40 * P.charge)
		for i in n:
			if (i + int(T * 30)) % 3 == 0:
				continue
			sp(P.x + P.ax * (8 + i * 3), P.y + P.ay * (8 + i * 3), m, 3 + int(P.charge * 3))
		var rr := 14.0 * (1.0 - P.charge) + 5.0
		for i in 8:
			var a := T * 7 + i * TAU / 8
			sp(P.x + cos(a) * rr - 0.25, P.y + sin(a) * rr - 0.25, m if i % 2 else PAPER, 6, 0, 1.0 if P.charge >= 1.0 else 0.5)

func _p_comma(f: int, aim: bool) -> void:
	# 逗号蜂：圆脑袋拖着一撇尾巴，黑黄相间
	var m := EMBER if aim else GOLD
	for q in 20:
		var t := q / 19.0
		var x := 0.6 - t * t * 3.4
		var y := 0.8 + t * 5.0
		var wd := 1.7 * (1 - t) + 0.25
		var dark := q % 6 >= 3
		var ii := -wd
		while ii <= wd:
			ip(x + ii, y, SPACE if dark else m, 2 if dark else (5 if ii < 0 else 4))
			ii += 0.5
	for jj in range(-7, 5):
		for ii in range(-6, 6):
			var x := ii * 0.5 + 0.25
			var y := jj * 0.5 + 0.25 + 0.5
			var d2 := x * x + y * y
			if d2 > 8.0:
				continue
			var l := 4
			if x + y < -1.2:
				l = 5
			if d2 > 5.6:
				l = 3 if x + y > 0 else 5
			ipx(ii, jj, m, l)
	for e in [-3, 1]:
		ipx(e, -3, PAPER, 6, true)
		ipx(e + 1, -3, PAPER, 6, true)
		ipx(e, -2, PAPER, 6, true)
		ipx(e + 1, -2, SPACE, 0)
	# 翅膀
	for q in 7:
		for s in [-1, 1]:
			var wx: float = s * (2.0 + q * 0.5)
			var wy: float = (-3.0 - q * 0.45) if f == 0 else (-2.0 - q * 0.1)
			ip(wx, wy, MIRROR, 6 - q * 0.4)
			ip(wx, wy + 0.5, MIRROR, 4 - q * 0.4)

func draw_comma(c: Creature, sh: int) -> void:
	var f := int(c.age * 22) % 2
	var aim := c.st == "aim"
	sd(bake("comma|%d|%s" % [f, aim], 5, 7, _p_comma.bind(f, aim)), c.x, c.y + sin(c.age * 5) * 0.8, 0 if aim else sh, c.flash > 0)

func _p_blot(f: int, small: bool, hop: int) -> void:
	# 墨团：一坨会晃的墨，边上发紫，两只青色的眼睛
	var r := 4.0 if small else 7.0
	var sq := 1.0 + hop * 0.12
	var R := ceili(r * 2.0) + 4
	for jj in range(-R, R):
		for ii in range(-R, R):
			var x := ii * 0.5 + 0.25
			var y := jj * 0.5 + 0.25
			var a := atan2(y, x)
			var rr := r * (0.86 + 0.14 * sin(a * 3 + f / 6.0 * TAU) + 0.05 * sin(a * 7 - f / 6.0 * TAU * 2))
			var e := sqrt(x * x / (sq * sq) + y * y * sq * sq)
			if e > rr:
				continue
			if e > rr - 0.8:
				ipx(ii, jj, GRAV, 5 if x + y < 0 else 3)
			elif e > rr - 1.8:
				ipx(ii, jj, GRAV, 2)
			else:
				ipx(ii, jj, SPACE, 1 if Pal.bay(ii, jj) > 0.7 else 0)
	# 高光
	var hl := r * 0.45
	ip(-hl, -hl, PAPER, 6)
	ip(-hl + 0.5, -hl, PAPER, 5)
	ip(-hl, -hl + 0.5, GRAV, 6)
	for e in [-1.0, 1.0]:
		var ex: float = e * r * 0.3
		ip(ex, 0, ORE, 6, true)
		ip(ex - 0.5, 0, ORE, 6, true)
		if not small:
			ip(ex, 0.5, ORE, 5, true)
			ip(ex - 0.5, 0.5, ORE, 5, true)
	# 往下滴的墨
	for q in 3:
		var dx := (q - 1) * r * 0.5
		for t in 2 + (q + f) % 3:
			ip(dx, r * 0.8 + t * 0.5, GRAV, 2)

func draw_blot(c: Creature, sh: int) -> void:
	var small := c.t == "blotlet"
	var f := int(c.age * 6) % 6
	var hop := clampi(roundi(c.sp * 2.0), 0, 2)
	sd(bake("blot|%d|%s|%d" % [f, small, hop], 9 if not small else 6, 9 if not small else 6, _p_blot.bind(f, small, hop)), c.x, c.y - hop * 1.5, maxi(sh, -1), c.flash > 0)

func draw_worm(c: Creature, sh: int) -> void:
	# 书虫：一节一节的纸色身子，戴着一副小眼镜
	var n := c.seg.size()
	for i in range(n - 1, -1, -1):
		var sg := c.seg[i]
		ball(sg.x, sg.y, 3.0 - i * 0.2, PAPER if i % 2 == 0 else MOTH, 4 if i % 2 == 0 else 3, sh)
	var fl := c.flash > 0
	ball(c.x, c.y, 3.6, PAPER, 6 if fl else 5, 0 if fl else sh)
	var fx := cos(c.ang)
	var fy := sin(c.ang)
	for s in [-1.0, 1.0]:
		var ex: float = c.x + fx * 1.3 - fy * s * 1.6
		var ey: float = c.y + fy * 1.3 + fx * s * 1.6
		sp(ex - 0.75, ey - 0.75, ORE, 6, 0, 1.5)
		sp(ex - 0.25, ey - 0.25, SPACE, 0)
		# 大颚
		var bite := 0.6 + 0.5 * sin(c.age * 14)
		sp(c.x + fx * 4.0 - fy * s * bite - 0.25, c.y + fy * 4.0 + fx * s * bite - 0.25, WINE, 5)
		sp(c.x + fx * 4.6 - fy * s * bite * 0.6 - 0.25, c.y + fy * 4.6 + fx * s * bite * 0.6 - 0.25, WINE, 4)

func _p_wisp(f: int) -> void:
	# 灯魇：一缕倒挂的冷火
	var ph := f / 8.0 * TAU
	for jj in range(-16, 14):
		var y := jj * 0.5 + 0.25
		var t := (y + 8.0) / 15.0
		var wd := 5.2 * sin(clampf(t, 0.0, 1.0) * PI * 0.62 + 0.25) * (1.0 if y < 3 else 1.0 - (y - 3) / 5.0)
		var sway := sin(ph + y * 0.5) * 0.9 * t
		for ii in range(-14, 14):
			var x := ii * 0.5 + 0.25
			var e := absf(x - sway)
			if e > wd:
				continue
			var rim := e > wd - 0.9
			if not rim and Pal.bay(ii, jj) > 0.6:
				continue
			# 底下撕成几缕
			if y > 3 and int(floorf((x - sway) * 1.0 + 20.0 + f * 0.25)) % 2 == 0:
				continue
			ipx(ii, jj, JELLY, 5 if rim else 3, rim)

func draw_wisp(c: Creature, _sh: int) -> void:
	var f := int(c.age * 7) % 8
	var by := sin(c.age * 3) * 1.2
	if c.open > 0.08:
		sd(bake("wisp|%d" % f, 8, 9, _p_wisp.bind(f)), c.x, c.y + by, 0, c.flash > 0, c.open)
	# 眼睛：暗处只看得见这个
	if c.open > 0.5 or sin(c.age * 1.7 + c.ph) > -0.75:
		for s in [-1.0, 1.0]:
			sp(c.x + s * 1.8 - 0.5, c.y + by - 2.5, GOLD, 6, 0, 1.0)
			sp(c.x + s * 1.8 - 0.5, c.y + by - 2.0, EMBER, 5, 0, 0.5)

func _p_redact(ei: int, lid: int) -> void:
	# 删节者：一块厚重的黑条，中间睁着一只眼。lid：0 全睁 1 半睁 2 闭眼
	var HW := 34
	var HH := 14
	for jj in range(-HH, HH):
		for ii in range(-HW, HW):
			# 两头撕得参差不齐
			var tear := int(Pal.n2(jj * 0.9, 3.7) * 5.0)
			if ii < -HW + tear or ii >= HW - int(Pal.n2(jj * 0.9, 9.1) * 5.0):
				continue
			var edge := jj == -HH or jj == HH - 1
			var l := 0.0
			var m := SPACE
			if edge or jj == -HH + 1:
				m = MIRROR
				l = 5 if jj < 0 else 2
			elif ii < -HW + tear + 2 or ii >= HW - int(Pal.n2(jj * 0.9, 9.1) * 5.0) - 2:
				m = MIRROR
				l = 3
			elif (jj + HH) % 6 == 3 and absi(ii) > 13 and (ii + jj * 7) % 11 != 0:
				# 被涂掉的一行行字
				m = RUIN
				l = 5
			ipx(ii, jj, m, l)
	# 眼睛
	var a := ei / 16.0 * TAU
	var px := roundi(cos(a) * 4.0)
	var py := roundi(sin(a) * 2.0)
	for jj in range(-9, 9):
		for ii in range(-13, 13):
			var x := (ii + 0.5) / 12.5
			var y := (jj + 0.5) / 8.5
			var open := 1.0 if lid == 0 else (0.45 if lid == 1 else 0.12)
			if x * x + y * y / (open * open) > 1.0:
				continue
			if lid == 2:
				ipx(ii, jj, WINE, 4)
				continue
			var dx := ii - px
			var dy := jj - py
			var d2 := dx * dx + dy * dy
			if d2 <= 5:
				ipx(ii, jj, SPACE, 0)
			elif d2 <= 22:
				ipx(ii, jj, WINE, 5 if dx + dy < 0 else 4, true)
			else:
				ipx(ii, jj, PAPER, 6 if jj < 3 else 5, true)
	if lid < 2:
		ipx(px - 2, py - 2, PAPER, 6, true)

func draw_redact(c: Creature, sh: int) -> void:
	if c.st == "dead":
		return
	var lid := 0
	if c.st == "sleep":
		lid = 2
	elif c.st == "rise":
		lid = 1
	elif fmod(c.age, 3.1) < 0.12:
		lid = 1
	var ei := posmod(roundi(c.ha / TAU * 16.0), 16)
	var x := c.x
	var y := c.y + sin(c.age * 1.4) * 1.5
	if c.st == "rise":
		x += (randf() - 0.5) * 2
	sd(bake("redact|%d|%d" % [ei if lid < 2 else 0, lid], 17.5, 7.5, _p_redact.bind(ei if lid < 2 else 0, lid)), x, y, 0 if c.st != "sleep" else maxi(sh, -1), c.flash > 0)
	if c.st == "sleep":
		return
	# 绕着它转的碎字：一小段一小段被划掉的横线
	for i in 10:
		var a := c.age * (0.9 if i % 2 == 0 else -0.7) + i * TAU / 10
		var rr := 24.0 + (i % 3) * 4
		var qx := x + cos(a) * rr
		var qy := y + sin(a) * rr * 0.55
		sr(qx - 2, qy, 4, 0.5, RUIN, 6)
		sr(qx - 2.5, qy + 0.5, 5, 0.5, WINE if c.sing > 0 else SPACE, 5 if c.sing > 0 else 0)

func draw_pc(ci: int, x: float, y: float, fr: int, ex: int, blink: bool, frost := false, flash := false) -> void:
	if ci == 0:
		draw_clawd(x, y, fr, ex, blink, frost, flash)
		return
	sd(bake("ch|%d|%d|%d|%s|%s" % [ci, fr, ex, blink, frost], 7, 6, _p_char.bind(ci, fr, ex, blink, frost)), x, y, 0, flash)

func _eyes(ex: int, blink: bool, y0: int, m: int, l: float) -> void:
	for e in [-5, 2]:
		for j in range(y0 + (2 if blink else 0), y0 + 4):
			for i in 2:
				ipx(e + ex + i, j, m, l, m != SPACE)

func _feet(fr: int, xs: Array, y0: int, m: int) -> void:
	for q in xs.size():
		var up := (fr == 1 and q % 2 == 0) or (fr == 0 and q % 2 == 1)
		for j in range(y0, y0 + (2 if up else 4)):
			for i in 2:
				ipx(xs[q] + i, j, m, 3 if i == 0 else 2)

func _p_char(ci: int, fr: int, ex: int, blink: bool, frost: bool) -> void:
	match ci:
		1:
			# 小瓷：白底青花的小瓷瓶
			for j in range(-11, 7):
				var hw := 0.0
				if j <= -10:
					hw = 3.5
				elif j <= -8:
					hw = 2.5
				else:
					hw = 7.6 * sqrt(maxf(0.0, 1.0 - pow((j + 0.5) / 7.6, 2.0)))
					hw = maxf(hw, 3.0)
				for i in range(-9, 9):
					var x := i + 0.5
					if absf(x) > hw:
						continue
					var l := 6.0
					if x > hw - 2.2:
						l = 4
					elif x > hw * 0.3:
						l = 5
					var m := PAPER
					# 青花：肩上一圈点，肚子上一道波浪
					if (j == -6 and posmod(i, 3) == 0) or (j == 3 + (1 if posmod(i, 4) < 2 else 0)) or j == -10:
						m = JELLY
						l = 4
					if frost and j <= -8:
						m = ICE
						l = 6
					ipx(i, j, m, l)
			_eyes(ex, blink, -3, SPACE, 0)
			_feet(fr, [-5, 3], 7, JELLY)
		2:
			# 阿砖：一块长了腿的老窑砖
			for j in range(-8, 6):
				for i in range(-12, 12):
					var row := (j + 8) / 5
					var mortar := (j + 8) % 5 == 4 or posmod(i + 12 + row * 5, 10) == 9
					var l := 4.0
					if j == -8 or i == -12:
						l = 5
					if i >= 10 or j == 5:
						l = 3
					if mortar:
						l = 2
					var m := WINE
					if frost and j <= -6 and (i * 5 + j * 3) % 4 == 0:
						m = ICE
						l = 6
					ipx(i, j, m, l)
			_eyes(ex, blink, -4, PAPER, 6)
			_feet(fr, [-10, -5, 3, 8], 6, WINE)
		3:
			# 墨墨：软木塞、细脖子、贴着标签的墨水瓶
			for j in range(-12, 7):
				var hw := 8.0
				var m := SPACE
				if j <= -10:
					hw = 3.0
					m = MOTH
				elif j <= -8:
					hw = 4.0
				elif j == -7 or j == 6:
					hw = 7.0
				for i in range(-9, 9):
					var x := i + 0.5
					if absf(x) > hw:
						continue
					var l := 5.0 if m == MOTH else 1.0
					var mm := m
					if m == SPACE:
						if absf(x) > hw - 1.0 or j == -9 or j == 6:
							mm = GRAV
							l = 5 if x < 0 else 3
						elif i == -6:
							mm = GRAV
							l = 6
						elif j >= -3 and j <= 3 and i >= -6 and i <= 5 and (j > -3 or i > -6):
							mm = PAPER
							l = 6 if j < 3 else 4
					elif i >= 1:
						l = 4
					if frost and j <= -10:
						mm = ICE
						l = 6
					ipx(i, j, mm, l)
			_eyes(ex, blink, -2, SPACE, 0)
			_feet(fr, [-6, 4], 7, GRAV)

# ---------- 第三章：页风、钟、烛焰、新生物 ----------
func _hh(i: int, k: int) -> float:
	return fposmod(sin(i * 12.9898 + k * 78.233) * 43758.5453, 1.0)

func draw_zones3() -> void:
	if chapter != 3:
		return
	# 页风：一道道顺着风向飞的纸屑
	for q in WINDS:
		if not on_screen(q.x, q.y, q.len + 10):
			continue
		var ca := cos(q.a)
		var sa := sin(q.a)
		var n := int(q.len * q.w / 28.0)
		for i in n:
			var u: float = fposmod(T * 85.0 * (0.7 + 0.6 * _hh(i, 1)) + _hh(i, 2) * q.len * 2.0, q.len * 2.0) - q.len
			var v: float = (_hh(i, 3) - 0.5) * 2.0 * q.w * 0.9
			var x: float = q.x + ca * u - sa * v
			var y: float = q.y + sa * u + ca * v
			var fade: float = 1.0 - absf(u) / q.len
			for k in 3:
				if fade < 0.25 and k > 0:
					break
				sp(x - ca * k * 1.2, y - sa * k * 1.2, PAPER, 5 - k * 1.5 if fade > 0.4 else 3 - k)
		# 两条边：稀疏的虚线
		var e: float = -q.len
		while e <= q.len:
			for sd_ in [-1.0, 1.0]:
				var px: float = q.x + ca * e - sa * q.w * sd_
				var py: float = q.y + sa * e + ca * q.w * sd_
				if int(e + T * 20.0) % 6 < 2:
					sp(px, py, RUIN, 4)
			e += 2.0
	# 钟面
	for q in CLOCKS:
		if not on_screen(q.x, q.y, q.r + 6):
			continue
		var n := int(q.r * TAU / 1.5)
		for i in n:
			var a := float(i) / n * TAU
			sp(q.x + cos(a) * q.r, q.y + sin(a) * q.r, MIRROR, 3 if i % 2 == 0 else 2)
			if i % 3 == 0:
				sp(q.x + cos(a) * (q.r + 1.5), q.y + sin(a) * (q.r + 1.5), RUIN, 4)
		for k in 12:
			var a := k / 12.0 * TAU
			for t in (3 if k % 3 == 0 else 2):
				sp(q.x + cos(a) * (q.r - 2 - t * 0.5), q.y + sin(a) * (q.r - 2 - t * 0.5), GOLD, 5 if k % 3 == 0 else 3)

func draw_hazards3() -> void:
	if chapter != 3:
		return
	# 钟针
	for q in CLOCKS:
		if not on_screen(q.x, q.y, q.r + 6):
			continue
		for hi in q.hands.size():
			var h: Dictionary = q.hands[hi]
			var ca := cos(h.a)
			var sa := sin(h.a)
			var u := 0.0
			while u <= h.len:
				var w := 1.5 if u < h.len - 4 else 1.0
				sr(q.x + ca * u - w / 2.0, q.y + sa * u - w / 2.0, w, w, MIRROR if hi == 0 else RUIN, 5 if hi == 0 else 6)
				u += 0.5
			sp(q.x + ca * h.len - 0.5, q.y + sa * h.len - 0.5, GOLD, 6, 0, 1.0)
		ball(q.x, q.y, 2.5, GOLD, 4, 0)
	# 印章兽的冲击圈
	for s in SHOCK:
		var k: float = 1.0 - s.r / s.max
		var n := int(s.r * 3.0)
		for i in n:
			if Pal.bay(i, i / 3) > k + 0.2:
				continue
			var a := float(i) / n * TAU
			sp(s.x + cos(a) * s.r - 0.25, s.y + sin(a) * s.r - 0.25, WINE, 6 if i % 2 == 0 else 5)
	# 装订师的线
	for th in THR:
		var A := Vector2(th.ax, th.ay)
		var B := Vector2(th.bx, th.by)
		var L := A.distance_to(B)
		var u := (B - A) / maxf(0.001, L)
		var s := 0.0
		var i := 0
		while s <= L:
			var p := A + u * s
			if th.t > 0:
				var gap := 3 if th.t > 0.4 else 1
				if (i + int(T * 14)) % (gap + 2) < 2:
					sp(p.x, p.y, PAPER, 5)
			else:
				sp(p.x - 0.25, p.y - 0.25, WINE, 6 if (i + int(T * 30)) % 4 else 4, 0, 1.0 if th.life > 0.4 else 0.5)
			s += 1.0
			i += 1
		for e in [A, B]:
			sp(e.x - 0.5, e.y - 0.5, MIRROR, 6, 0, 1.0)
			sp(e.x - 0.25, e.y - 1.5, MIRROR, 4, 0, 1.0)

## 烛焰：预告时天上掉火星，烧的时候整列整列地照下来，被石头挡住的地方没有
func draw_flare() -> void:
	if chapter != 3 or flare_st == 0:
		return
	var x := floorf(ox / 3.0) * 3.0
	while x < ox + W + 3:
		if not in_flare(x, cam_pos.y):
			x += 3.0
			continue
		if flare_st == 1:
			var k := int(x * 7.0 + T * 30.0)
			if k % 11 == 0:
				var y := oy + fposmod(T * 160.0 + x * 13.0, H)
				sp(x, y, EMBER, 6, 0, 1.0)
				sp(x, y - 1.5, GOLD, 5)
		else:
			# 火雨：一道道往下落的火线，碰到石头就停，石头下面是安全的影子
			var a := clampf(flare_k / 0.15, 0.0, 1.0) * clampf(flare_t / 0.4, 0.0, 1.0)
			var hx := _hh(int(x), 7)
			if hx < 0.15 + 0.5 * a:
				var y := oy
				var ph := hx * 97.0
				var top_hit := false
				while y < oy + H:
					if rock_at(x, y):
						top_hit = true
						break
					if fposmod(y * 0.8 - T * 260.0 + ph, 26.0) < 7.0:
						sp(x, y, GOLD if fposmod(y * 0.8 - T * 260.0 + ph, 26.0) < 2.0 else EMBER, 6, 0, 1.0 if hx < 0.3 else 0.5)
					y += 1.0
				if top_hit and int(T * 30.0 + x) % 2 == 0:
					sp(x - 0.5, y - 1.5, GOLD, 6, 0, 1.0)
		x += 3.0

func draw_skill_fx() -> void:
	if S != "play" and S != "ending":
		return
	draw_pen_fx()
	if P.shield_t > 0 and (P.shield_t > 0.8 or sin(T * 20) > 0):
		for i in 16:
			var a := T * 3.0 + i * TAU / 16.0
			sp(P.x + cos(a) * 10 - 0.25, P.y + sin(a) * 10 - 0.25, GRAV if i % 2 else MIRROR, 6, 0, 1.0 if i % 4 == 0 else 0.5)
	if freeze_t > 0:
		for c in cr:
			if c.dead or not on_screen(c.x, c.y, 10):
				continue
			for i in 4:
				var a := i * TAU / 4.0 + c.ph
				sp(c.x + cos(a) * (c.r + 1.5), c.y + sin(a) * (c.r + 1.5), ICE, 6)

func _p_dove(di: int, f: int, aim: bool) -> void:
	var a := di / 16.0 * TAU
	var ca := cos(a)
	var sa := sin(a)
	var wing := 4.2 if f == 0 else 2.6
	for jj in range(-14, 14):
		for ii in range(-14, 14):
			var X := ii * 0.5 + 0.25
			var Y := jj * 0.5 + 0.25
			var x := X * ca + Y * sa
			var y := -X * sa + Y * ca
			if x > 6.0 or x < -4.0:
				continue
			var half := (6.0 - x) / 10.0 * wing
			if absf(y) > half:
				continue
			if x < -2.5 and absf(y) < (-2.5 - x) * 1.2:
				continue
			var l := 6.0 if y < 0 else 4.0
			if absf(y) < 0.3:
				l = 3.0
			elif absf(y) > half - 0.5:
				l = 5.0 if y < 0 else 3.0
			ipx(ii, jj, ORE if aim and absf(y) < 0.6 else PAPER, l)
	# 眼睛
	var ex := 3.0 * ca + 0.6 * sa
	var ey := 3.0 * sa - 0.6 * ca
	ip(ex, ey, SPACE, 0)

func draw_dove(c: Creature, sh: int) -> void:
	var di := posmod(roundi(atan2(c.vy, c.vx) / TAU * 16.0), 16)
	var f := int(c.age * (14.0 if c.st == "dive" else 6.0) + c.off) % 2
	var aim := c.st == "aim"
	sd(bake("dove|%d|%d|%s" % [di, f, aim], 7, 7, _p_dove.bind(di, f, aim)), c.x, c.y, 0 if aim else sh, c.flash > 0)

func _p_tick(f: int, open: bool, k: int) -> void:
	for jj in range(-12, 12):
		for ii in range(-14, 14):
			var x := ii * 0.5 + 0.25
			var y := jj * 0.5 + 0.25
			var e := (x * x) / 36.0 + (y * y) / 25.0
			# 腿
			if e > 1.0:
				var leg := absf(x) > 4.0 and absf(x) < 7.0 and int(floorf(y + 5.0 + (f if x < 0 else 1 - f))) % 3 == 0 and absf(y) < 4.5
				if leg:
					ipx(ii, jj, RUIN, 2)
				continue
			if open and absf(x) < 1.2 + (1.0 - e) * 1.2 and y < 3.5:
				ipx(ii, jj, SERP, 5 if absf(x) < 0.6 else 4)
				continue
			var l := 4.0
			if x + y < -3.5:
				l = 6.0
			elif x + y < -1.0:
				l = 5.0
			elif e > 0.8:
				l = 2.0
			if absf(x) < 0.3 and not open:
				l = 2.0
			if int(floorf(y + 6.0)) % 3 == 0 and e < 0.85 and absf(x) > 0.5:
				l -= 1.0
			ipx(ii, jj, GOLD, l)
	# 眼睛
	for s in [-1.0, 1.0]:
		ip(s * 1.6, 3.0, WINE, 6, true)
		ip(s * 1.6 + 0.5 * s, 3.0, WINE, 5, true)
	# 背上的发条钥匙
	var kw: float = [2.5, 1.2, 0.3, 1.2][k]
	for t in 5:
		ip(0, -5.0 - t * 0.5, MIRROR, 4)
	var q: float = -kw
	while q <= kw:
		ip(q, -7.5, MIRROR, 6 if q < 0 else 5)
		ip(q, -8.0, MIRROR, 5)
		q += 0.5

func draw_tick(c: Creature, sh: int) -> void:
	var open := c.st == "tired"
	var f := int(c.age * 8.0) % 2 if c.st != "tired" else 0
	var k := 0 if open else int(c.age * (14.0 if c.st == "wind" else 6.0)) % 4
	var x := c.x + ((randf() - 0.5) * 1.5 if c.st == "wind" else 0.0)
	sd(bake("tick|%d|%s|%d" % [f, open, k], 7.5, 6.5, _p_tick.bind(f, open, k)), x, c.y, sh, c.flash > 0)
	if open and int(c.age * 10) % 3 == 0:
		part(c.x + (randf() - 0.5) * 6, c.y - 4, (randf() - 0.5) * 6, -12, 0.6, MIRROR, 4)

func _p_cinder(f: int, big: bool) -> void:
	var r := 4.4 if big else 3.0
	_p_ball(r, EMBER, 4)
	# 火苗
	for jj in range(-int(r * 2) - 10, -int(r * 2) + 2):
		for ii in range(-6, 6):
			var x := ii * 0.5 + 0.25
			var y := jj * 0.5 + 0.25 + r
			var t := clampf(-y / 5.0, 0.0, 1.0)
			var wd := 1.8 * (1.0 - t) + 0.2
			var sway := sin(f * 1.6 + t * 4.0) * t * 1.0
			if absf(x - sway) > wd:
				continue
			ipx(ii, jj, GOLD if absf(x - sway) < wd * 0.5 else EMBER, 6 if t > 0.4 else 5, true)
	for s in [-1.0, 1.0]:
		ip(s * r * 0.35, r * 0.15, SPACE, 0)

func draw_cinder(c: Creature, sh: int) -> void:
	var big := c.st == "swell"
	var f := int(c.age * 10.0) % 4
	var fl := c.flash > 0 or (big and sin(c.age * 40.0) > 0)
	sd(bake("cinder|%d|%s" % [f, big], 6, 9, _p_cinder.bind(f, big)), c.x, c.y + sin(c.age * 3) * 0.8, maxi(sh, 0), fl)

func _p_stamp() -> void:
	for jj in range(-20, 14):
		for ii in range(-14, 14):
			var x := ii * 0.5 + 0.25
			var y := jj * 0.5 + 0.25
			# 把手
			if y < -5.5:
				var hw := 1.6 if y > -8.0 else 2.6
				if absf(x) < hw and y > -10.0:
					ipx(ii, jj, RUIN, 5 if x < 0 else 3)
				continue
			if absf(x) > 6.5 or y > 6.5:
				continue
			var edge := absf(x) > 5.6 or y < -4.6 or y > 5.6
			var l := 4.0
			if edge:
				l = 5.0 if (x < 0 or y < -4.6) else 2.0
			ipx(ii, jj, WINE, l)
	# 印面上的花纹
	var g := ["#####", "#.#.#", "#####", "#...#", "#####"]
	for j in 5:
		for i in 5:
			if g[j][i] == "#":
				ip(-2.5 + i * 1.25, -2.5 + j * 1.25, WINE, 6)
	for s in [-1.0, 1.0]:
		ip(s * 2.0, -3.6, PAPER, 6, true)
		ip(s * 2.0, -3.1, SPACE, 0)

func draw_stamp(c: Creature, sh: int) -> void:
	if c.sp > 0.5:
		for i in 9:
			sp(c.x - 4 + i, c.y + 6, SPACE, 0)
	sd(bake("stamp", 7.5, 10.5, _p_stamp), c.x, c.y - c.sp, sh, c.flash > 0)

func _p_binder(ei: int, lid: int) -> void:
	# 装订师：一卷线轴，上下两片轮缘，中间缠满红线，正中一只眼睛
	for jj in range(-26, 26):
		for ii in range(-26, 26):
			var x := ii * 0.5 + 0.25
			var y := jj * 0.5 + 0.25
			if absf(y) > 10.5 and absf(y) < 13.0 and absf(x) < 12.0:
				ipx(ii, jj, MIRROR if y < 0 else RUIN, (5 if x < 0 else 4) if y < 0 else 3)
				continue
			if absf(y) <= 10.5 and absf(x) < 9.0:
				var stripe := int(floorf(y + 11.0 + x * 0.25)) % 2 == 0
				var l := 4.0 if stripe else 5.0
				if absf(x) > 7.8:
					l = 2.0
				ipx(ii, jj, WINE, l)
	var a := ei / 16.0 * TAU
	var px := roundi(cos(a) * 3.0)
	var py := roundi(sin(a) * 2.0)
	for jj in range(-8, 8):
		for ii in range(-11, 11):
			var x := (ii + 0.5) / 10.5
			var y := (jj + 0.5) / 7.5
			var open := 1.0 if lid == 0 else (0.45 if lid == 1 else 0.12)
			if x * x + y * y / (open * open) > 1.0:
				continue
			if lid == 2:
				ipx(ii, jj, SPACE, 1)
				continue
			var dx := ii - px
			var dy := jj - py
			var d2 := dx * dx + dy * dy
			if d2 <= 4:
				ipx(ii, jj, SPACE, 0)
			elif d2 <= 16:
				ipx(ii, jj, GOLD, 5 if dx + dy < 0 else 4, true)
			else:
				ipx(ii, jj, PAPER, 6 if jj < 2 else 5, true)
	if lid < 2:
		ipx(px - 2, py - 2, PAPER, 6, true)

func draw_binder(c: Creature, sh: int) -> void:
	if c.st == "dead":
		return
	var lid := 0
	if c.st == "sleep":
		lid = 2
	elif c.st == "rise" or fmod(c.age, 2.7) < 0.12:
		lid = 1
	var ei := posmod(roundi(c.ha / TAU * 16.0), 16)
	var x := c.x
	var y := c.y + sin(c.age * 1.3) * 1.5
	if c.st == "rise":
		x += (randf() - 0.5) * 2
	# 穿过线轴的大针（先画在后面的半截）
	var na := c.ang if c.st == "fight" else -0.8
	var nu := Vector2(cos(na), sin(na))
	var u := -20.0
	while u < 22.0:
		var w := 1.5 if u < 16.0 else 1.0
		if absf(u) > 8.0:
			sr(x + nu.x * u - w / 2.0, y + nu.y * u - w / 2.0, w, w, MIRROR, 5 if u > 0 else 4, 0 if c.st != "sleep" else -1)
		u += 0.5
	sp(x + nu.x * 22.5 - 0.25, y + nu.y * 22.5 - 0.25, PAPER, 6)
	for e in [-17.0, -15.5]:
		sp(x + nu.x * e - 0.25, y + nu.y * e - 0.25, SPACE, 0)
	sd(bake("binder|%d|%d" % [ei if lid < 2 else 0, lid], 13, 13, _p_binder.bind(ei if lid < 2 else 0, lid)), x, y, 0 if c.st != "sleep" else maxi(sh, -1), c.flash > 0)
	if c.st == "sleep":
		return
	# 线头：一圈飘着的红线
	for i in 12:
		var a := c.age * (1.1 if i % 2 == 0 else -0.8) + i * TAU / 12
		var rr := 20.0 + (i % 3) * 3
		sp(x + cos(a) * rr, y + sin(a) * rr * 0.6, WINE, 5 if c.sp > 0 else 4)
	if c.sp > 0:
		# 拉线：一根线连到小克
		var d := Vector2(P.x - x, P.y - y)
		var L := d.length()
		var s := 8.0
		while s < L - 5:
			if int(s + T * 40) % 3:
				sp(x + d.x / L * s, y + d.y / L * s, WINE, 6)
			s += 1.0

# ---------- 笔字联动的特效 ----------
func draw_pen_fx() -> void:
	for l in LINES:
		var dv := Vector2(l.x1 - l.x, l.y1 - l.y)
		var L := maxf(0.001, dv.length())
		var u := dv / L
		var s := 0.0
		var fade: float = clampf(l.t / 0.3, 0.0, 1.0)
		while s < L:
			var px: float = l.x + u.x * s
			var py: float = l.y + u.y * s
			if on_screen(px, py, 6) and Pal.bay(int(s), int(T * 20)) < fade:
				var j := sin(s * 0.7 + T * 18) * 0.8
				sp(px - u.y * j - 0.5, py + u.x * j - 0.5, l.m, 5 if int(s + T * 30) % 3 else 6, 0, 1.0)
			s += 1.0
	for f in FX:
		if f.k != "zap":
			continue
		var a := Vector2(f.x, f.y)
		var b := Vector2(f.x1, f.y1)
		var n := int(a.distance_to(b) / 2.5) + 1
		var nv := (b - a).normalized().orthogonal()
		var prev := a
		for i in range(1, n + 1):
			var p := a.lerp(b, float(i) / n)
			if i < n:
				p += nv * (randf() - 0.5) * 5.0
			var m := maxi(1, int(prev.distance_to(p) * 2))
			for q in m:
				var pp := prev.lerp(p, float(q) / m)
				sp(pp.x - 0.25, pp.y - 0.25, PAPER if q % 2 else ORE, 6)
			prev = p

# ---------- 冷息 ----------
func _p_chill(f: int, hot: bool) -> void:
	for jj in range(-14, 14):
		for ii in range(-12, 12):
			var x := ii * 0.5 + 0.25
			var y := jj * 0.5 + 0.25
			# 头是一团圆雾，下面拖着三缕飘带
			var head := x * x + (y + 1.5) * (y + 1.5) < 18.0
			var tail := false
			if y > 0 and y < 6.5:
				for k in 3:
					var cx := (k - 1) * 2.0 + sin(y * 0.9 + f * 1.6 + k * 2.0) * 0.9
					if absf(x - cx) < 0.9 * (1.0 - y / 7.0) + 0.2:
						tail = true
			if not head and not tail:
				continue
			var lv := 4.0
			if head:
				var d := sqrt(x * x + (y + 1.5) * (y + 1.5)) / 4.25
				lv = 5.0 - d * 1.6 - (0.6 if Pal.bay(ii, jj) > 0.6 else 0.0)
				if x < -1 and y < -3:
					lv = 6
			else:
				lv = 3.5 - y * 0.2 + (0.8 if Pal.bay(ii, jj) > 0.5 else 0.0)
			ipx(ii, jj, ICE, clampf(lv, 2, 6), hot and head)
	# 眼睛：两道空心的月牙
	for s in [-1.0, 1.0]:
		ip(s * 1.5, -2.0, SPACE, 0)
		ip(s * 1.5, -1.5, SPACE, 0)
		ip(s * 1.5 + s * 0.5, -1.5, PAPER if hot else SPACE, 6 if hot else 0, hot)
	# 嘴：小小的“o”，在吸气
	ip(0, 0.5, SPACE, 0)

func draw_chill(c: Creature, sh: int) -> void:
	var f := int(c.age * 6.0) % 4
	var hot := c.sp > 0.3
	var a := 0.55 + 0.35 * clampf(c.sp + (0.3 if c.flash > 0 else 0.0), 0.0, 1.0) if c.st != "melt" else clampf(c.tm, 0.1, 0.8)
	sd(bake("chill|%d|%s" % [f, hot], 6, 7, _p_chill.bind(f, hot)), c.x, c.y + sin(c.age * 2.0) * 1.2, 0, c.flash > 0, a)

# ---------- 霜棱 ----------
func _p_icicle(di: int) -> void:
	var a := di / 16.0 * TAU
	var ca := cos(a)
	var sa := sin(a)
	for jj in range(-16, 16):
		for ii in range(-16, 16):
			var x := ii * 0.5 + 0.25
			var y := jj * 0.5 + 0.25
			var u := x * ca + y * sa
			var v := -x * sa + y * ca
			if u < -5.0 or u > 7.0:
				continue
			# 前面尖、后面短的菱形
			var w := (u + 5.0) / 3.0 * 1.9 if u < -2.0 else (7.0 - u) / 9.0 * 1.9
			if absf(v) > w:
				continue
			var lv := 4.0 + (1.0 if v < 0 else 0.0) + (1.0 if absf(v) < 0.4 else 0.0)
			if u > 5.0:
				lv = 6
			ipx(ii, jj, ICE if absf(v) > 0.4 else MIRROR, lv, u > 4.5)
	ip(ca * 1.5 - sa * 0.5, sa * 1.5 + ca * 0.5, SERP, 6, true)

func draw_icicle(c: Creature, sh: int) -> void:
	if c.st == "aim":
		var L := 210.0
		var s := 4.0
		while s < L:
			if int(s / 3.0 + T * 20) % 3 != 0:
				sp(c.x + cos(c.ang) * s - 0.25, c.y + sin(c.ang) * s - 0.25, SERP if c.tm < 0.35 else ICE, 6 if c.tm < 0.35 else 5)
			s += 1.0
	var di := posmod(roundi(c.ang / TAU * 16.0), 16)
	var jit := (randf() - 0.5) * 1.5 if c.st == "aim" and c.tm < 0.35 else 0.0
	var a := 1.0 if c.st != "melt" else clampf(c.tm, 0.1, 1.0)
	sd(bake("icicle|%d" % di, 8, 8, _p_icicle.bind(di)), c.x + jit, c.y, 0 if c.st == "dash" else sh, c.flash > 0, a)

# ---------- 扑灯母 ----------
func _p_mothq(f: int) -> void:
	var lift: float = 1.0 if f == 0 else 0.55
	for jj in range(-22, 22):
		for ii in range(-26, 26):
			var x := ii * 0.5 + 0.25
			var y := jj * 0.5 + 0.25
			var ax := absf(x)
			# 身体
			if ax < 1.4 and y > -4.5 and y < 6.5 and (ax * ax) / 1.96 + pow((y - 1.0) / 5.5, 2) < 1.0:
				var seg := int(floorf(y + 5.0)) % 2 == 0
				ipx(ii, jj, MOTH, 3 if seg else 2)
				continue
			# 上翅：大，向外上方张开
			var wx := (ax - 1.0) / 11.5
			var wy := (y + 1.0) / (8.0 * lift)
			var up := wx > 0 and wx < 1.0 and wy < 0.2 and wx * wx + wy * wy < 1.0 and wy > -1.0 + wx * 0.3
			# 下翅：小，圆
			var lx := (ax - 1.0) / 7.0
			var ly := (y - 3.0) / (4.5 * lift)
			var lo := lx > 0 and lx * lx + ly * ly < 1.0 and y > 0.5
			if not up and not lo:
				continue
			var lv := 4.0 - (0.0 if Pal.bay(ii, jj) > 0.4 else 0.6)
			if up and wx * wx + wy * wy > 0.75:
				lv = 3
			# 翅膀上的两个“灯斑”
			var ex := 6.0
			var ey := -2.5 * lift
			var ed := (ax - ex) * (ax - ex) + (y - ey) * (y - ey)
			if up and ed < 5.0:
				ipx(ii, jj, EMBER if ed > 1.6 else GOLD, 6 if ed < 1.6 else 5, true)
				continue
			if lo and (ax - 4.0) * (ax - 4.0) + (y - 4.5) * (y - 4.5) < 1.2:
				lv = 2
			ipx(ii, jj, MOTH, lv)
	# 触角
	for k in 6:
		for s in [-1.0, 1.0]:
			ip(s * (0.6 + k * 0.45), -5.0 - k * 0.55, MOTH, 4)
	for s in [-1.0, 1.0]:
		ip(s * 0.7, -4.0, SERP, 6, true)

func draw_mothq(c: Creature, sh: int) -> void:
	var f := int(c.age * 9.0) % 2
	var a := 1.0 if c.st != "melt" else clampf(c.tm, 0.1, 1.0)
	sd(bake("mothq|%d" % f, 14, 12, _p_mothq.bind(f)), c.x, c.y, sh, c.flash > 0, a)
