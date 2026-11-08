extends "res://scripts/game_art.gd"
## 界面：状态栏、小地图、工坊、图鉴、标题、结局、触屏按钮。

# 界面（屏幕坐标 320x180）
func pset(x: float, y: float, col: Color) -> void:
	cv.draw_rect(Rect2(floorf(x), floorf(y), 1, 1), col)

func rect(x: float, y: float, w: float, h: float, col: Color) -> void:
	cv.draw_rect(Rect2(x, y, w, h), col)

func box(x: float, y: float, w: float, h: float, fill, line: Color) -> void:
	if fill != null:
		rect(x, y, w, h, fill)
	rect(x, y, w, 1, line)
	rect(x, y + h - 1, w, 1, line)
	rect(x, y, 1, h, line)
	rect(x + w - 1, y, 1, h, line)

func icon(pat: Array, x: int, y: int, col: Color) -> void:
	for j in pat.size():
		var row: String = pat[j]
		for i in row.length():
			if row[i] == "#":
				pset(x + i, y + j, col)

func digits(s: String, x: int, y: int, col: Color, sh = null) -> void:
	for ch in s:
		if DIG.has(ch):
			var g: String = DIG[ch]
			for i in 15:
				if g[i] == "1":
					var px := x + i % 3
					var py := y + i / 3
					if sh != null:
						pset(px + 1, py + 1, sh)
					pset(px, py, col)
		x += 4

func text_w(s: String, size: int, bold := false) -> float:
	var f: Font = font_b if bold else font
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

## 居中写字（带一像素阴影）
func text(s: String, cx: float, y: float, size: int, col: Color, sh = null, alpha := 1.0, bold := false) -> void:
	if alpha <= 0:
		return
	var f: Font = font_b if bold else font
	var x := cx - text_w(s, size, bold) / 2.0
	var base := y + f.get_ascent(size)
	if sh != null:
		var c2: Color = sh
		c2.a = alpha
		for o in [Vector2(0.6, 0.6), Vector2(0, 0.6), Vector2(0.6, 0)]:
			cv.draw_string(f, Vector2(x, base) + o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c2)
	col.a = alpha
	cv.draw_string(f, Vector2(x, base), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func text_r(s: String, x: float, y: float, size: int, col: Color, sh = null) -> void:
	text(s, x - text_w(s, size) / 2.0, y, size, col, sh)

func text_l(s: String, x: float, y: float, size: int, col: Color, sh = null) -> void:
	text(s, x + text_w(s, size) / 2.0, y, size, col, sh)

func wrap_text(s: String, size: int, max_w: float) -> Array:
	var key := "%s|%d|%d" % [s, size, max_w]
	if wrap_cache.has(key):
		return wrap_cache[key]
	var out := []
	var line := ""
	for ch in s:
		var t := line + ch
		if line != "" and text_w(t, size) > max_w and not "，。、；：！？）」』…".contains(ch):
			out.append(line)
			line = ch
		else:
			line = t
	if line != "":
		out.append(line)
	wrap_cache[key] = out
	return out

func dim() -> void:
	rect(0, 0, W, H, Color(0.008, 0.008, 0.03, 0.62))

func _draw_hud(c: CanvasItem) -> void:
	cv = c
	if S == "play" or S == "menu" or S == "codex" or S == "words":
		draw_hud_play()
		if touch_mode and S == "play":
			draw_touch_ui()
		if S == "menu":
			draw_menu()
		elif S == "codex":
			draw_codex()
		elif S == "words":
			draw_words_panel()
	elif S == "ending":
		draw_ending()
	elif S == "title":
		draw_title()
	elif S == "intro":
		draw_intro()
	elif S == "dead":
		draw_hud_play()
		draw_dead()

func draw_hud_play() -> void:
	for i in P.maxhp:
		icon(HEART, 5 + i * 7, 5, C_SH)
		icon(HEART, 4 + i * 7, 4, Pal.rc(CLAY, 5) if i < P.hp else Pal.rc(RUIN, 4))
	var wk := P.warm / P.maxwarm
	var bw := 46
	var fl := P.warm < 25 and sin(T * 10) > 0
	icon(ICO_TH, 4, 12, C_RED if fl else Pal.rc(ICE, 5))
	box(9, 13, bw + 2, 5, C_SH, Pal.rc(RUIN, 5))
	for i in int(ceilf(bw * wk)):
		rect(10 + i, 14, 1, 3, Pal.rc(ICE if wk < 0.3 else EMBER, 4 if i % 2 else 5))
	digits(str(ceili(P.warm)), bw + 14, 13, C_TEAL if wk < 0.3 else C_TXT, C_SH)
	icon(ICO_PAGE, 4, 22, Pal.rc(ORE, 5))
	digits(str(P.dust), 9, 21, C_TXT, C_SH)
	icon(ICO_EMB, 26, 22, Pal.rc(EMBER, 5))
	digits(str(P.ember), 31, 21, C_TXT, C_SH)
	if P.beacons:
		icon(ICO_BEA, 44, 21, Pal.rc(GOLD, 5))
		digits(str(P.beacons), 49, 21, C_TXT, C_SH)
	# 暗潮钟
	var ph := fposmod(tide_t, 150.0)
	var dark := tide_t > 0 and ph >= 112
	var left := 150 - ph if dark else (112 - tide_t if tide_t < 0 else 112 - ph)
	text_r("暗潮" if dark else "星息", W - 46, 2, 9, C_RED if dark else C_GOLD, C_SH)
	digits("%d:%02d" % [int(left / 60), int(fmod(left, 60))], W - 44, 6, C_RED if dark else C_TXT, C_SH)
	draw_minimap(W - 46, 15, 42)
	draw_sentence_hud()
	text_r("书页 %d/3" % P.bound, W - 4, 59, 9, C_TEAL, C_SH)
	# 首领血条
	if serp and (serp.st == "fight" or serp.st == "rise"):
		var hk := serp.hp / DEF.serp.hp
		text("回声蛇", W / 2.0, 4, 9, Color("#e57cb6"), C_SH)
		box(W / 2.0 - 60, 15, 120, 4, C_SH, Pal.rc(SERP, 2))
		rect(W / 2.0 - 59, 16, 118 * hk, 2, Pal.rc(SERP, 5))
	# 区域名
	var z: String = ZNAME[zn(P.x, P.y)]
	if z != zone_name:
		zone_name = z
		zone_t = 2.5
	zone_t -= 1.0 / 60.0
	if zone_t > 0 and S == "play":
		text(z, W / 2.0, 20, 10, C_DIM, C_SH, minf(1.0, zone_t))
	# 屏幕边缘箭头：炉灯（金）和书页（青）
	var arrows := []
	if Vector2(P.x, P.y).length() > 110:
		arrows.append([0.0, 0.0, GOLD])
	for pg in PAGES:
		if pg.state == "free" or pg.state == "sealed":
			arrows.append([pg.x, pg.y, ORE])
	for ar in arrows:
		var sx: float = ar[0] - ox
		var sy: float = ar[1] - oy
		if not (sx > 4 and sx < W - 4 and sy > 4 and sy < H - 4):
			var dx := float(sx) - W / 2.0
			var dy := float(sy) - H / 2.0
			var k := minf((W / 2.0 - 10) / maxf(0.001, absf(dx)), (H / 2.0 - 10) / maxf(0.001, absf(dy)))
			var axp := W / 2.0 + dx * k
			var ayp := H / 2.0 + dy * k
			var a := atan2(dy, dx)
			var col := Pal.rc(ar[2], 6 if sin(T * 4) > 0 else 5)
			for t in 5:
				for w in range(-t, t + 1):
					pset(roundf(axp + cos(a) * (2 - t) - sin(a) * w * 0.7), roundf(ayp + sin(a) * (2 - t) + cos(a) * w * 0.7), col)
	# 提示条
	var ty := H - 30.0
	for i in range(toasts.size() - 1, -1, -1):
		var t: Dictionary = toasts[i]
		var a := minf(1.0, minf(t.t * 2, (t.max - t.t) * 6))
		var lines := wrap_text(t.s, 10, 290)
		for j in range(lines.size() - 1, -1, -1):
			text(lines[j], W / 2.0, ty, 10, t.c, C_SH, a)
			ty -= 13
	if S == "play" and near_kiln():
		text("「E」工坊" if not touch_mode else "点这里 · 工坊", W / 2.0, H / 2.0 + 18, 9, C_GOLD, C_SH, 0.8 + 0.2 * sin(T * 4))

## 左下角的小句子：每格一个字，金色字发光
func draw_sentence_hud() -> void:
	for i in P.slots.size():
		var x := 4 + i * 13
		var y := H - 16
		var s = P.slots[i]
		box(x, y, 12, 12, Color(0.03, 0.03, 0.08, 0.7), Pal.rc(GOLD if s != null and s.gold else RUIN, 5 if s != null else 3))
		if s != null:
			text(s.c, x + 6, y + 1, 8, C_GOLD if s.gold else kind_col(s.c), C_SH)
	if not touch_mode and P.slots.size() > 0:
		text_l("F", 6 + P.slots.size() * 13, H - 14, 7, C_DIM, C_SH)

func kind_col(c: String) -> Color:
	match char_kind(c):
		"形": return C_TXT
		"动": return C_TEAL
		_: return C_CLAY

func draw_words_panel() -> void:
	dim()
	box(10, 8, 300, 164, C_PANEL, Pal.rc(ORE, 4))
	text("句子", W / 2.0, 11, 12, C_GOLD, C_SH, 1.0, true)
	for i in P.slots.size():
		var r := slot_rect(i)
		var s = P.slots[i]
		var line := Pal.rc(GOLD, 5) if s != null and s.gold else (Pal.rc(ORE, 5) if i == word_sel else Pal.rc(RUIN, 5))
		box(r.position.x, r.position.y, r.size.x, r.size.y, Pal.rc(SPACE, 2), line)
		if s != null:
			text(s.c, r.position.x + 13, r.position.y + 4, 15, C_GOLD if s.gold else kind_col(s.c), C_SH, 1.0, true)
			text(char_kind(s.c), r.position.x + 13, r.position.y + 27, 7, C_DIM, null)
	# 效果说明
	var y := 72.0
	var shown := 0
	for l in loadout_lines():
		for ln in wrap_text(l, 8, 280):
			if shown < 6:
				text(ln, W / 2.0, y, 8, C_TEAL if l.begins_with("成词") else (C_DIM if l.begins_with("（") else C_TXT), C_SH)
			y += 9
			shown += 1
	# 背包
	text_l("背包（点一下填进句子的空格）", 20, 125, 8, C_DIM, null)
	for i in mini(P.bag.size(), 14):
		var r := bag_rect(i)
		var w = P.bag[i]
		box(r.position.x, r.position.y, r.size.x, r.size.y, Pal.rc(SPACE, 2), Pal.rc(GOLD if w.gold else RUIN, 5))
		text(w.c, r.position.x + 9, r.position.y + 2, 11, C_GOLD if w.gold else kind_col(w.c), C_SH)
	if P.bag.is_empty():
		text_l("（空）", 22, 139, 8, C_DIM, null)
	var known_w: Array = save.words
	var hint := "在炉灯边可以点句子里的字把它取下来" if near_kiln() else "在外面只能往空格里填字，回炉灯才能重排"
	text("%s · 已发现的词 %d/%d · %s" % [hint, known_w.size(), WD.words.size(), "点外面关闭" if touch_mode else "F 关闭"], W / 2.0, 159, 7, C_DIM, C_SH)

func draw_minimap(x: int, y: int, s: int) -> void:
	box(x, y, s, s, C_PANEL, C_LINE)
	var k := s / (WR * 2 + 60)
	var cx := x + s / 2.0
	var cy := y + s / 2.0
	for r in rocks:
		pset(roundf(cx + r.x * k), roundf(cy + r.y * k), Pal.rc(MIRROR if r.zone == "echo" else RUIN, 5 if r.R > 18 else 4))
	pset(roundf(cx), roundf(cy), Pal.rc(GOLD, 6))
	pset(roundf(cx) + 1, roundf(cy), Pal.rc(GOLD, 5))
	for b in BEA:
		pset(roundf(cx + b.x * k), roundf(cy + b.y * k), Pal.rc(EMBER, 5))
	for pg in PAGES:
		if (pg.state == "free" or pg.state == "sealed") and sin(T * 5) > -0.3:
			var qx := roundf(cx + pg.x * k)
			var qy := roundf(cy + pg.y * k)
			pset(qx, qy, Pal.rc(ORE, 6))
			pset(qx + 1, qy, Pal.rc(ORE, 4))
			pset(qx, qy + 1, Pal.rc(ORE, 4))
	if serp and serp.st == "fight":
		pset(roundf(cx + serp.x * k), roundf(cy + serp.y * k), Pal.rc(SERP, 6))
	var px := roundf(cx + P.x * k)
	var py := roundf(cy + P.y * k)
	pset(px, py, Pal.rc(PAPER, 6))
	if sin(T * 8) > 0:
		for o in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			pset(px + o.x, py + o.y, Pal.rc(CLAY, 5))

func draw_touch_ui() -> void:
	for t in touches.values():
		if t.kind == "move":
			var st: Vector2 = t.start
			for i in 24:
				var a := i / 24.0 * TAU
				pset(st.x + cos(a) * 18, st.y + sin(a) * 18, Pal.rc(RUIN, 5))
			var kp: Vector2 = st + joy * 18
			box(kp.x - 2, kp.y - 2, 5, 5, Pal.rc(CLAY, 4), Pal.rc(CLAY, 6))
	box(W - 40, H - 40, 34, 34, Color(0.04, 0.04, 0.1, 0.5), Pal.rc(CLAY, 4))
	text("冲", W - 23, H - 30, 11, C_TXT, C_SH)
	box(W - 40, H - 76, 34, 30, Color(0.04, 0.04, 0.1, 0.5), Pal.rc(EMBER, 4))
	text("烬", W - 23, H - 68, 11, C_GOLD, C_SH)
	if P.beacons:
		box(W - 40, H - 108, 34, 28, Color(0.04, 0.04, 0.1, 0.5), Pal.rc(GOLD, 4))
		text("标", W - 23, H - 101, 11, C_GOLD, C_SH)

func draw_menu() -> void:
	dim()
	box(12, 8, 296, 164, C_PANEL, Pal.rc(CLAY, 4))
	text("炉灯工坊", W / 2.0, 11, 12, C_GOLD, C_SH, 1.0, true)
	icon(ICO_PAGE, 262, 16, Pal.rc(ORE, 5))
	digits(str(P.dust), 268, 15, C_TXT, C_SH)
	# 左边：两列卡片
	for i in SHOP.size():
		var it := SHOP[i]
		var r := menu_rect(i)
		var lv := shop_lvl(it)
		var full: bool = it.k != "beacon" and it.k != "forge" and lv >= it.max
		var cost := 0 if full else shop_cost(it)
		var can := not full and P.dust >= cost
		var sel := i == menu_sel
		box(r.position.x, r.position.y, r.size.x, r.size.y, Pal.rc(RUIN, 3) if sel else Pal.rc(SPACE, 2), Pal.rc(CLAY, 5) if sel else Pal.rc(RUIN, 4))
		var x := r.position.x
		var y := r.position.y
		if not touch_mode:
			digits(str(i + 1), x + 4, y + 4, C_GOLD, C_SH)
		text_l(it.name, x + (12 if not touch_mode else 5), y + 1, 10, C_TXT if can or full else C_DIM, C_SH)
		var sub := ""
		if it.k == "forge":
			sub = "背包 %d 字" % P.bag.size()
		elif it.k == "beacon":
			sub = "有 %d 座" % P.beacons
		else:
			sub = "●".repeat(lv) + "○".repeat(int(it.max) - lv)
		text_l(sub, x + 5, y + 16, 7, C_DIM, null)
		if full:
			text_r("已满", x + r.size.x - 4, y + 16, 7, C_DIM, null)
		else:
			var cs := str(cost)
			digits(cs, int(x + r.size.x - 10 - cs.length() * 4), int(y + 18), C_TXT if can else C_RED, C_SH)
			icon(ICO_PAGE, int(x + r.size.x - 8), int(y + 19), Pal.rc(ORE, 5 if can else 3))
	# 右边：选中项的详情
	var it2 := SHOP[clampi(menu_sel, 0, SHOP.size() - 1)]
	var lv2 := shop_lvl(it2)
	var full2: bool = it2.k != "beacon" and it2.k != "forge" and lv2 >= it2.max
	var cost2 := 0 if full2 else shop_cost(it2)
	var can2 := not full2 and P.dust >= cost2
	box(198, 30, 104, 130, Pal.rc(SPACE, 1), Pal.rc(RUIN, 4))
	text(it2.name, 250, 34, 13, C_GOLD, C_SH, 1.0, true)
	var lines := wrap_text(it2.desc, 9, 92)
	for i in lines.size():
		text(lines[i], 250, 58 + i * 12, 9, C_TXT, C_SH)
	if full2:
		text("已经满级了", 250, 112, 9, C_DIM, C_SH)
	else:
		text("需要 %d 页尘" % cost2, 250, 112, 9, C_TXT if can2 else C_RED, C_SH)
	var br := buy_rect()
	box(br.position.x, br.position.y, br.size.x, br.size.y, Pal.rc(CLAY, 3) if can2 else Pal.rc(SPACE, 2), Pal.rc(GOLD, 5) if can2 else Pal.rc(RUIN, 4))
	text("打造" if not full2 else "已满", br.get_center().x, br.position.y + 3, 10, C_GOLD if can2 else C_DIM, C_SH, 1.0, true)
	text("点卡片选择 · 点「打造」 · 点外面关闭" if touch_mode else "数字键直接打造 · 点卡片选择 · E 关闭", W / 2.0, 162, 7, C_DIM, null)

func draw_codex() -> void:
	dim()
	box(8, 8, 304, 164, C_PANEL, C_LINE)
	var n := 0
	for t in ORDER:
		if known(t):
			n += 1
	text("星海生物图鉴  %d/8" % n, W / 2.0, 11, 11, C_GOLD, C_SH, 1.0, true)
	for i in ORDER.size():
		var t: String = ORDER[i]
		var y := 34 + i * 16
		if i == codex_sel:
			rect(14, y - 2, 96, 15, Pal.rc(RUIN, 3))
		text_l(DEF[t].name if known(t) else "？？？", 20, y - 1, 10, C_TXT if known(t) else C_DIM, C_SH)
	var t: String = ORDER[codex_sel]
	var k := known(t)
	draw_portrait(t, 212, 58, 1 if t == "serp" else 2, k)
	if k:
		text(DEF[t].name, 212, 85, 12, C_GOLD, C_SH, 1.0, true)
		text(LORE[t][0], 212, 101, 9, C_TEAL, C_SH)
		var ls := wrap_text(LORE[t][1], 9, 180)
		for i in ls.size():
			text(ls[i], 212, 113 + i * 11, 9, C_TXT, C_SH)
	else:
		text("还没遇到过。去更远的地方找找。", 212, 100, 9, C_DIM, C_SH)
	text("点名字查看 · 点外面关闭" if touch_mode else "W/S 或鼠标选择 · Tab 关闭", W / 2.0, 158, 8, C_DIM, C_SH)

## 图鉴肖像：用同一套绘制函数，画在放大的坐标系里
func draw_portrait(t: String, cx: float, cy: float, sc: int, k: bool) -> void:
	var dm := Creature.new()
	dm.t = t
	dm.age = T
	dm.ph = 1
	dm.vx = 1
	dm.vy = 0.0001
	dm.st = "orbit" if t == "leech" else "open"
	dm.open = 1
	dm.ang = PI * 0.75
	dm.na = -PI / 2
	if t == "leech":
		for i in range(12, 0, -1):
			dm.tr.append(-i * 1.2)
			dm.tr.append(sin(T * 3 + i * 0.5) * 1.5)
	if t == "serp":
		dm.st = "fight"
		for i in 12:
			dm.seg.append(Vector2(-6 - i * 4.5, sin(T * 2 + i * 0.6) * 3))
	if t == "clam":
		dm.y = 3
	cv.draw_set_transform(Vector2(cx, cy), 0, Vector2(sc, sc))
	no_cull = true
	mono = not k
	mono_col = Pal.rc(RUIN, 3)
	match t:
		"hush": draw_hush(dm, 0)
		"folio": draw_folio(dm, 0)
		"clam": draw_clam(dm, 0)
		"moth": draw_moth(dm, 0)
		"leech": draw_leech(dm, 0)
		"mite": draw_mite(dm, 0)
		"grav": draw_grav(dm, 0)
		"serp": draw_serp(dm, 0)
	no_cull = false
	mono = false
	cv.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func draw_ending() -> void:
	if end_t <= 6:
		return
	dim()
	box(50, 28, 220, 128, C_PANEL, Pal.rc(GOLD, 4))
	text("第一章 · 已装订", W / 2.0, 36, 14, C_GOLD, C_SH, 1.0, true)
	var lines := [
		"用时  %d 分 %d 秒" % [int(gt / 60), int(fmod(gt, 60))],
		"碎掉过  %d 次" % P.deaths,
		"熬过暗潮  %d 次" % tides,
		"遇见生物  %d / 8 种" % seen.size(),
		"拾回页尘  %d" % P.dust_total,
	]
	for i in lines.size():
		text(lines[i], W / 2.0, 61 + i * 13, 10, C_TXT, C_SH)
	text("图书馆的第一层亮了。还有九千九百九十九层。", W / 2.0, 127, 9, C_TEAL, C_SH)
	text("Enter / 点击 继续自由探索", W / 2.0, 140, 8, C_DIM, C_SH, 0.6 + 0.4 * sin(T * 3))

func draw_title() -> void:
	dim()
	var by := sin(T * 2) * 2
	text("散 页", W / 2.0, 26, 30, C_CLAY, C_SH, 1.0, true)
	text("U N B O U N D", W / 2.0, 66, 9, C_DIM, C_SH)
	draw_clawd(cv, W / 2.0, 100 + by, 3, int(T * 3) % 2, roundi(sin(T * 0.7)), fmod(T, 3.3) < 0.15)
	text("一只小陶灵，在碎掉的宇宙图书馆里拾回文字", W / 2.0, 124, 10, C_TXT, C_SH)
	text("点击开始", W / 2.0, 144, 11, C_GOLD, C_SH, 0.6 + 0.4 * sin(T * 3))
	text("WASD 移动 · 鼠标射击 · 空格冲刺 · E 工坊 · F 句子 · Q 余烬 · B 信标 · Tab 图鉴", W / 2.0, 164, 8, C_DIM, C_SH)
	if int(save.clears):
		text("已通关 %d 次" % int(save.clears), W / 2.0, 5, 8, C_GOLD, C_SH)

func draw_intro() -> void:
	dim()
	dim()
	var y := 36.0
	for i in INTRO.size():
		var a := clampf((intro_t - i * 3.2) / 1.2, 0, 1)
		if a <= 0:
			continue
		for l in wrap_text(INTRO[i], 10, 270):
			text(l, W / 2.0, y, 10, C_GOLD if i == 4 else C_TXT, C_SH, a)
			y += 13
		y += 6
	if intro_t > 13:
		draw_clawd(cv, W / 2.0, y + 16, 2, int(T * 4) % 2, 0, fmod(T, 3.0) < 0.15)
	text("点击跳过", W - 30, H - 12, 8, C_DIM, C_SH, 0.6)

func draw_dead() -> void:
	var a := minf(1.0, dead_t)
	if dead_t > 0.4:
		dim()
		text("小克碎了", W / 2.0, 70, 16, C_CLAY, C_SH, a, true)
		text("炉灯正在把它重新烧好……", W / 2.0, 96, 10, C_DIM, C_SH, a)
