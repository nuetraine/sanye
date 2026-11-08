extends "res://scripts/game_state.gd"
## 世界里的像素绘制：炉灯、生物、子弹、粒子、小克。

func shift_at(x: float, y: float) -> int:
	var L := light_at(x, y)
	if L >= 0.5:
		return 0
	if L >= 0.33:
		return -1
	if L >= 0.2:
		return -2
	return -3

# ---------- 世界像素绘制（世界坐标） ----------
func wp(x: float, y: float, m: int, l: float) -> void:
	var sx := floori(x)
	var sy := floori(y)
	if not no_cull and (sx < ox or sx >= ox + W or sy < oy or sy >= oy + H):
		return
	cv.draw_rect(Rect2(sx, sy, 1, 1), mono_col if mono else Pal.rc(m, l))

func on_screen(x: float, y: float, mg := 20.0) -> bool:
	return x - ox > -mg and x - ox < W + mg and y - oy > -mg and y - oy < H + mg

func ball(cx: float, cy: float, r: float, m: int, base: float, sh: int, alpha := 1.0) -> void:
	var R := ceili(r)
	var fx := floori(cx)
	var fy := floori(cy)
	for dy in range(-R, R + 1):
		for dx in range(-R, R + 1):
			if dx * dx + dy * dy > r * r:
				continue
			var px := fx + dx
			var py := fy + dy
			if alpha < 1.0 and Pal.bay(px, py) > alpha:
				continue
			var nx := dx / r
			var ny := dy / r
			var nz := sqrt(maxf(0.0, 1.0 - nx * nx - ny * ny))
			var L := nx * SUNV.x + ny * SUNV.y + nz * SUNV.z
			wp(px, py, m, floorf(base + (L - 0.55) * 3.2 + Pal.bay(px, py) - 0.5) + sh)

func _draw_zones(c: CanvasItem) -> void:
	cv = c
	draw_ring(0, 0, kiln_r(), GOLD)
	for b in BEA:
		draw_ring(roundi(b.x), roundi(b.y), 56, EMBER)

## 暖圈：一圈虚线 + 圈里稀疏的暗红点（只在抖动矩阵最小的格子上）
func draw_ring(x: int, y: int, r: float, m: int) -> void:
	if not on_screen(x, y, r + 10):
		return
	var n := floori(r * TAU / 3)
	for i in n:
		if i % 3 == 2:
			continue
		var a := float(i) / n * TAU + T * 0.05
		wp(x + cos(a) * r, y + sin(a) * r, m, 2 + (1 if i % 3 == 0 else 0))
	var R := ceili(r)
	var gy := y - R - posmod(y - R, 4)
	while gy <= y + R:
		var gx := x - R - posmod(x - R, 4)
		while gx <= x + R:
			var d := Vector2(gx - x, gy - y).length()
			if d < r and 0.03125 < 0.06 * (1 - d / r) * (0.5 + TIDE):
				wp(gx, gy, WINE, 2)
			gx += 4
		gy += 4

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
			sh = 1
		match cc.t:
			"hush": draw_hush(cc, sh)
			"folio": draw_folio(cc, sh)
			"moth": draw_moth(cc, sh)
			"leech": draw_leech(cc, sh)
			"clam": draw_clam(cc, sh)
			"grav": draw_grav(cc, sh)
			"mite": draw_mite(cc, sh)
			"serp": draw_serp(cc, sh)
	draw_bullets()
	draw_player()
	draw_particles()
	if S == "ending":
		draw_ending_world()

func draw_page_icon(x: float, y: float, s := 1.0) -> void:
	var w := roundi(5 * s)
	var h := roundi(7 * s)
	for j in h:
		for i in w:
			var line := j > 0 and j < h - 1 and j % 2 == 0 and i > 0 and i < w - 1
			wp(x - w / 2.0 + i, y - h / 2.0 + j, ORE if line else PAPER, 5 if line else 6)

func draw_beacons() -> void:
	for b in BEA:
		if not on_screen(b.x, b.y):
			continue
		var sh := shift_at(b.x, b.y)
		for dy in range(-6, 3):
			for dx in range(-1, 2):
				wp(b.x + dx, b.y + dy, CLAY, (4 if dx < 0 else (2 if dx > 0 else 3)) + sh)
		for dx in range(-3, 4):
			wp(b.x + dx, b.y + 3, ROCK, 3)
		if b.hp >= 3 or sin(T * 20) > 0:
			for dy in range(-3, 1):
				for dx in range(-1, 2):
					if dy == -3 and dx != 0:
						continue
					wp(b.x + dx, b.y - 8 + dy, GOLD if dy > -2 else EMBER, 6 if dy == 0 else 5 - (1 if sin(T * 9 + dx) > 0.4 else 0))

func draw_pages() -> void:
	for pg in PAGES:
		if pg.state != "free" or not on_screen(pg.x, pg.y, 30):
			continue
		var by := sin(T * 2) * 2
		draw_page_icon(pg.x, pg.y + by, 1.4)
		for i in 6:
			var a := T * 1.5 + i * TAU / 6
			wp(pg.x + cos(a) * 13, pg.y + by + sin(a) * 5, ORE, 5 + (i % 2))

func draw_cocoon() -> void:
	var pg: Dictionary = PAGES[2]
	if serp == null or (serp.st != "sleep" and serp.st != "rise"):
		return
	if not on_screen(pg.x, pg.y, 30):
		return
	var pul := sin(T * 1.6) * 1.2
	ball(pg.x, pg.y, 15 + pul, SERP, 3, 0, 0.75)
	draw_page_icon(pg.x, pg.y)
	for i in 14:
		var a := T * (0.6 + (i % 3) * 0.2) + i * 1.7
		var r := 10 + (i % 4) * 2.2
		wp(pg.x + cos(a) * r, pg.y + sin(a) * r * 0.7, ORE, 5)

func draw_grav(c: Creature, sh: int) -> void:
	var pts := []
	for k in 30:
		var r := 8 + (k % 6) * 1.9
		var a := c.age * (3.2 - (k % 6) * 0.35) + k * 0.83
		pts.append(Vector3(cos(a) * r, sin(a) * r * 0.42, r))
	for p in pts:
		if p.y < 0:
			wp(c.x + p.x, c.y + p.y, GOLD if p.z < 10 else GRAV, 5)
			wp(c.x + p.x + 1, c.y + p.y, EMBER if p.z < 10 else GRAV, 4)
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var d := sqrt(float(dx * dx + dy * dy))
			if d > 5.6:
				continue
			if d > 4.3:
				wp(c.x + dx, c.y + dy, GRAV, 5 + (1 if sin(T * 4 + atan2(dy, dx) * 3) > 0.5 else 0))
			else:
				wp(c.x + dx, c.y + dy, GRAV, 0)
	for p in pts:
		if p.y >= 0:
			wp(c.x + p.x, c.y + p.y, GOLD if p.z < 10 else GRAV, 6)
			wp(c.x + p.x + 1, c.y + p.y, EMBER if p.z < 10 else GRAV, 5)
	if c.flash > 0:
		ball(c.x, c.y, 4, PAPER, 6, 0)

func draw_mite(c: Creature, sh: int) -> void:
	var fx := cos(c.ang)
	var fy := sin(c.ang)
	for i in 3:
		for s in [-1, 1]:
			var t := -1.5 + i * 1.6
			wp(c.x + fx * t - fy * s * 5.5, c.y + fy * t + fx * s * 5.5 + (0.5 if sin(c.age * 10 + i) > 0 else 0.0), MOTH, 3 + sh)
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			var d := sqrt(float(dx * dx + dy * dy))
			if d > 4.6:
				continue
			var dd := (dx * fx + dy * fy) / (d if d > 0 else 1.0)
			if dd > -0.15 or d < 2:
				var g := absf((dx * -fy + dy * fx) - sin(T * 1.7) * 4) < 0.8
				wp(c.x + dx, c.y + dy, MIRROR, 6 if g else 3 + (1 if dd > 0.6 else 0) + (1 if dx + dy < -1 else 0) + sh)
			else:
				wp(c.x + dx, c.y + dy, SERP, 5 if d < 3.2 else 3)
	if c.flash > 0:
		ball(c.x, c.y, 3, PAPER, 6, 0)

func draw_serp(c: Creature, sh: int) -> void:
	if c.st == "sleep" or c.st == "dead":
		return
	for i in range(c.seg.size() - 1, -1, -1):
		var sg := c.seg[i]
		ball(sg.x, sg.y, 4.2 - i * 0.12, SERP, 3, sh)
		wp(sg.x, sg.y, ORE, 6 if sin(T * 4 + i * 1.3) > 0.2 else 4)
	var fl := c.flash > 0
	ball(c.x, c.y, 6.2, PAPER if fl else SERP, 6 if fl else 4, 0)
	var fx := cos(c.ha)
	var fy := sin(c.ha)
	for s in [-1, 1]:
		wp(c.x + fx * 2.5 - fy * s * 2.5, c.y + fy * 2.5 + fx * s * 2.5, ORE, 6)
	for k in 6:
		var aa := T * 3 + k * TAU / 6
		wp(c.x + fx * 4.5 + cos(aa) * 1.6, c.y + fy * 4.5 + sin(aa) * 1.6, GOLD, 5)

## 结局：图书馆第一层书架在炉灯上方显形
func draw_ending_world() -> void:
	var lv := mini(12, floori(end_t * 2))
	for i in lv:
		var w := 110 - i * 7
		var y := -24 - i * 11
		for x in range(-w / 2, w / 2 + 1):
			wp(x, y, ORE, 6 if sin(T * 3 + x * 0.3 + i) > 0.6 else 4)
			if i % 2 == 0 and posmod(x, 9) == 0:
				for yy in 11:
					wp(x, y + yy, ORE, 3)
		var x := -w / 2 + 2
		while x < w / 2 - 2:
			if _h1(i * 99 + x) > 0.4:
				for yy in range(2, 9):
					wp(x, y + yy, GOLD if _h1(i * 31 + x) > 0.5 else PAPER, 2 + (1 if posmod(yy + x, 3) == 0 else 0))
			x += 2
	for i in 3:
		var r := fmod(end_t * 40 + i * 60, 200.0)
		var a := 0.0
		while a < TAU:
			if randf() < 0.5:
				wp(cos(a) * r, sin(a) * r * 0.6, GOLD, 4)
			a += 0.04

func _h1(i: int) -> float:
	var h := (i * 374761393 + 668265263) & 0xffffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
	return float(h ^ (h >> 16)) / 4294967296.0

func draw_kiln() -> void:
	if not on_screen(0, 0, 40):
		return
	for dy in range(4, 12):
		for dx in range(-14, 15):
			var w := 14 - (dy - 4) * 1.6
			if absf(dx) > w:
				continue
			wp(dx, dy, ROCK, 3 - (dy - 4) * 0.35 + (0.6 if dx < 0 else -0.6) + Pal.bay(dx, dy))
	for dy in range(-14, 5):
		for dx in range(-11, 12):
			var den := 12.0 if dy < -3 else 8.0
			var e := (dx * dx) / 121.0 + ((dy + 3) * (dy + 3)) / (den * den)
			if e > 1:
				continue
			var L := (-dx / 11.0) * 0.5 + (-(dy + 3) / 12.0) * 0.6
			var l := floorf(3.3 + L * 1.6 + Pal.bay(dx, dy) - 0.5)
			if posmod(dy + 20, 5) == 0 and absi(dx) < 10:
				l -= 1
			wp(dx, dy, CLAY, l)
	for dy in range(-19, -12):
		for dx in range(-2, 3):
			wp(dx + 3, dy, CLAY, 4 if dx < 0 else 2)
	for dy in range(-5, 5):
		for dx in range(-4, 5):
			var arch := absf(dx) <= 4 - (-2 - dy) * 1.4 if dy < -2 else absi(dx) <= 4
			if not arch:
				continue
			var f := Pal.n2(dx * 0.6 + 3, dy * 0.5 + T * 6) * 1.4 + (dy + 5) / 9.0
			var l := floorf(f * 3.6 + 1 + Pal.bay(dx, dy) * 0.6)
			wp(dx, dy, GOLD if l >= 4 else EMBER, minf(6, l))
	for i in P.bound:
		var a := T * 0.8 + i * TAU / 3
		draw_page_icon(cos(a) * 22, -6 + sin(a) * 8)

func draw_pickups() -> void:
	for p in PK:
		if not on_screen(p.x, p.y):
			continue
		var tw := sin(T * 8 + p.age * 3) > 0
		if p.k == "word":
			# 一小张发光的纸片，金色字会闪
			var m := GOLD if p.gold else PAPER
			for dy in range(-2, 3):
				for dx in range(-2, 2):
					wp(p.x + dx, p.y + dy, m, 6 if (dx + dy + int(T * 6)) % 4 == 0 and p.gold else 5)
			wp(p.x - 1, p.y - 1, ORE, 6)
			wp(p.x, p.y + 1, ORE, 5 if tw else 4)
			continue
		if p.k == "dust":
			wp(p.x, p.y, ORE, 6 if tw else 5)
			if tw:
				wp(p.x + 1, p.y, ORE, 3)
				wp(p.x - 1, p.y, ORE, 3)
		else:
			wp(p.x, p.y, EMBER, 6)
			wp(p.x + 1, p.y, EMBER, 4)
			wp(p.x, p.y + 1, EMBER, 4)
			wp(p.x + 1, p.y + 1, EMBER, 3)

func draw_bullets() -> void:
	for b in PB:
		var l := maxf(0.0001, Vector2(b.vx, b.vy).length())
		var tail := 2 if b.small else 4
		for k in tail:
			wp(b.x - b.vx / l * k, b.y - b.vy / l * k, CLAY if k else b.mat, 6 - k)
		wp(b.x + 0.5, b.y + 0.5, b.mat, 5)
		if b.big:
			wp(b.x + 1, b.y, b.mat, 5)
			wp(b.x, b.y + 1, b.mat, 4)
			wp(b.x + 1, b.y + 1, b.mat, 4)
		if LO.get("gold", false) and int(T * 20 + b.x) % 5 == 0:
			wp(b.x - 1, b.y - 1, GOLD, 6)
	for b in EB:
		var fl := sin(T * 14 + b.x) > 0
		wp(b.x, b.y, b.m, 6)
		wp(b.x + 1, b.y, b.m, 5 if fl else 4)
		wp(b.x, b.y + 1, b.m, 4 if fl else 5)
		wp(b.x - 1, b.y, b.m, 4)
		wp(b.x, b.y - 1, b.m, 4)

func draw_particles() -> void:
	for p in PT:
		if not on_screen(p.x, p.y, 2):
			continue
		var k := p.life / p.mx
		var bx := floori(p.x)
		var by := floori(p.y)
		var l := floorf(p.l * (0.4 + 0.6 * k) + Pal.bay(bx, by) * 0.8)
		if not p.emit and k < 0.4 and Pal.bay(bx, by) > k * 2.5:
			continue
		wp(p.x, p.y, p.m, l)

func draw_player() -> void:
	if S == "dead" or S == "title" or S == "intro":
		return
	if P.inv > 0 and S == "play" and int(T * 16) % 2 == 0 and P.inv < 1.05:
		return
	var sx := roundf(P.x)
	var sy := roundf(P.y + sin(T * 3) * 0.8)
	var ex := 1 if P.ax > 0.35 else (-1 if P.ax < -0.35 else 0)
	draw_clawd(cv, sx, sy, 1, int(P.anim) % 2, ex, fmod(T, 3.7) < 0.12, P.warm < 25, P.dash_t > 0.12)
	for i in P.carry.size():
		var a := T * 2 + i * TAU / P.carry.size()
		draw_page_icon(P.x + cos(a) * 10, P.y + sin(a) * 6 - 2, 0.7)

## 小克：Claude 的橙色小吉祥物（13x8 像素）
func draw_clawd(c: CanvasItem, sx: float, sy: float, s: int, fr: int, ex: int, blink: bool, frost := false, flash := false) -> void:
	var x0 := roundf(sx - 13 * s / 2.0)
	var y0 := roundf(sy - 8 * s / 2.0)
	for j in 8:
		for i in 13:
			var ch: String = CL[j][i]
			if ch == ".":
				continue
			if ch == "L" and j == 7 and ((fr and (i == 2 or i == 8)) or (not fr and (i == 4 or i == 10))):
				continue
			var l := 4
			if ch == "H":
				l = 5
			elif ch == "S" or ch == "L":
				l = 3
			elif ch == "A":
				l = 4 if j == 2 else 3
			var col := Pal.rc(PAPER, 6) if flash else Pal.rc(CLAY, l)
			if frost and j <= 1 and (i * 5 + j * 3) % 4 == 0:
				col = Pal.rc(ICE, 6)
			c.draw_rect(Rect2(x0 + i * s, y0 + j * s, s, s), col)
	for e in [4, 8]:
		var j0 := 3 if blink else 2
		c.draw_rect(Rect2(x0 + (e + ex) * s, y0 + j0 * s, s, (4 - j0) * s), Pal.rc(CLAY, 0))

func draw_hush(c: Creature, sh: int) -> void:
	var pul := sin(c.age * 2.2 + c.ph)
	var r := 6 + pul * 0.8
	for k in 5:
		var bx := -4 + k * 2
		for j in 9:
			if j % 2 == 0 or k % 2 == 0:
				wp(c.x + bx + sin(c.age * 3 + k + j * 0.6) * (j * 0.25), c.y + 2 + j, JELLY, 3 - j * 0.3 + sh)
	var rr := ceili(r)
	var fx := floori(c.x)
	var fy := floori(c.y)
	for dy in range(-rr, 2):
		for dx in range(-rr - 1, rr + 2):
			var e := dx * dx / ((r + 1) * (r + 1)) + dy * dy / (r * r)
			if e > 1:
				continue
			var px := fx + dx
			var py := fy + dy
			var edge := e > 0.62
			if not edge and Pal.bay(px, py) > 0.4:
				continue
			wp(px, py, JELLY, ((5 if dy < -r * 0.4 else 4) if edge else 3) + sh)
	for i in 4:
		var a := i * 1.9 + c.ph
		wp(c.x + cos(a) * 3, c.y - 2 + sin(a) * 1.6, JELLY, 6 if sin(T * 3 + i * 2 + c.ph) > 0 else 5)

func draw_folio(c: Creature, sh: int) -> void:
	var a := atan2(c.vy, c.vx)
	var fx := cos(a)
	var fy := sin(a)
	var sx := -fy
	var sy := fx
	var fl := sin(c.age * 7 + c.ph)
	var span := 8 * (0.45 + 0.55 * absf(fl))
	for k in range(1, 8):
		var t := -4.0 - k
		var wob := sin(c.age * 5 - k * 0.7) * 1.5
		wp(c.x + fx * t + sx * wob, c.y + fy * t + sy * wob, WINE, 5 - k * 0.3 + sh)
	var t := -3.5
	while t <= 3.5:
		for sd in [-1.0, 1.0]:
			var u := 0.0
			while u <= 1.001:
				var cover := u > 0.82 or absf(t) > 3.1
				var lit := 1 if sd * fl > 0 else 0
				var l := (3 + lit) if cover else (4 + lit + (0 if roundi(t * 2) % 2 != 0 else -1))
				wp(c.x + fx * t + sx * sd * u * span, c.y + fy * t + sy * sd * u * span, WINE if cover else PAPER, l + sh)
				u += 0.1
		t += 0.45
	t = -4.0
	while t <= 4.0:
		wp(c.x + fx * t, c.y + fy * t, WINE, 2 + sh)
		t += 0.5
	if c.flash > 0:
		ball(c.x, c.y, 4, PAPER, 6, 0)

func draw_moth(c: Creature, sh: int) -> void:
	var fl := int(c.age * 24) % 2
	var b := EMBER if c.st == "burn" else MOTH
	wp(c.x, c.y, b, 4 + sh)
	wp(c.x, c.y + 1, b, 3 + sh)
	for s in [-1, 1]:
		wp(c.x + s, c.y - fl, b, 5 + sh)
		wp(c.x + s * 2, c.y - fl, b, 4 + sh)
		if fl == 0:
			wp(c.x + s * 2, c.y + 1, b, 3 + sh)
	wp(c.x, c.y - 1, SERP, 6)

func draw_leech(c: Creature, sh: int) -> void:
	var n := c.tr.size() / 2
	var red := c.st == "wind"
	var shake := (randf() - 0.5) * 2 if red else 0.0
	var k := 0
	while k < n:
		ball(c.tr[k * 2] + shake, c.tr[k * 2 + 1], 1 + float(k) / n * 1.8, LEECH, 3, sh)
		k += 2
	ball(c.x + shake, c.y, 3.2, EMBER if red else LEECH, 5 if red else 4, 0 if red else sh)
	wp(c.x + shake, c.y, WINE, 6 if red else 3)

func draw_clam(c: Creature, sh: int) -> void:
	var ta := c.na + PI / 2
	var tx := cos(ta)
	var ty := sin(ta)
	var nx := cos(c.na)
	var ny := sin(c.na)
	var op := c.open * 3
	var u := -5.0
	while u <= 5.0:
		var hh := 3.4 * sqrt(maxf(0.0, 1 - pow(u / 5.3, 2)))
		var odd := roundi(u) % 2 != 0
		var v := 0.0
		while v <= hh + op + 0.01:
			var l := -1.0
			if v <= hh * 0.5:
				l = 2 + (0 if odd else 1)
			elif v >= hh * 0.5 + op:
				l = 4 + (0 if odd else 1) - (1 if v > hh + op - 0.6 else 0)
			if l >= 0:
				wp(c.x + tx * u + nx * v, c.y + ty * u + ny * v, ICE, l + sh)
			v += 0.5
		u += 0.5
	if c.st != "empty" and c.open > 0.2:
		var px := c.x + nx * (1.7 + op * 0.5)
		var py := c.y + ny * (1.7 + op * 0.5)
		wp(px, py, EMBER, 6)
		wp(px + 1, py, EMBER, 5)
		wp(px, py + 1, EMBER, 5)
		wp(px + 1, py + 1, GOLD, 4)
	if c.flash > 0:
		wp(c.x, c.y, PAPER, 6)
