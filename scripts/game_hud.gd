extends "res://scripts/game_art.gd"
## 界面：状态栏、小地图、工坊、图鉴、标题、结局、触屏按钮。
##
## 坐标都用“单位”（屏幕至少 320×180 个单位，一个单位 = 2 个精细像素）。
## 四角的状态栏贴着屏幕边；工坊 / 图鉴 / 句子这些面板按 320×180 设计，整体居中（OFS）。

const HEART := ["..##...##..", ".####.####.", "###########", "###########", "###########", ".#########.", "..#######..", "...#####...", "....###....", ".....#....."]
const I_DUST := ["...#...", "..###..", ".#####.", "#######", ".#####.", "..###..", "...#..."]
const I_EMB := ["...#...", "..##...", "..###..", ".####..", ".#####.", ".#####.", "..###.."]
const I_BEA := ["..###..", ".#####.", "..###..", "...#...", "...#...", "..###..", ".#####."]
const I_TH := ["..#..", "..#..", "..#..", "..#..", "..#..", ".###.", "#####", "#####", ".###."]

var OFS := Vector2.ZERO

func hp(x: float, y: float, col: Color) -> void:
	cv.draw_rect(Rect2(floorf((x + OFS.x) * U), floorf((y + OFS.y) * U), 1, 1), col)

func rect(x: float, y: float, w: float, h: float, col: Color) -> void:
	cv.draw_rect(Rect2(roundf((x + OFS.x) * U), roundf((y + OFS.y) * U), roundf(w * U), roundf(h * U)), col)

## 细边框（一个精细像素粗）
func box(x: float, y: float, w: float, h: float, fill, line: Color) -> void:
	if fill != null:
		rect(x, y, w, h, fill)
	rect(x, y, w, 0.5, line)
	rect(x, y + h - 0.5, w, 0.5, line)
	rect(x, y, 0.5, h, line)
	rect(x + w - 0.5, y, 0.5, h, line)

## 小图标：图案里一格 = 一个精细像素，带右下阴影
func icon(pat: Array, x: float, y: float, col: Color, sh = C_SH) -> void:
	for pass_ in 2:
		if pass_ == 0 and sh == null:
			continue
		for j in pat.size():
			var row: String = pat[j]
			var i := 0
			while i < row.length():
				if row[i] != "#":
					i += 1
					continue
				var i0 := i
				while i < row.length() and row[i] == "#":
					i += 1
				var o := 0.5 if pass_ == 0 else 0.0
				rect(x + i0 * 0.5 + o, y + j * 0.5 + o, (i - i0) * 0.5, 0.5, sh if pass_ == 0 else col)

func text_w(s: String, size: int, bold := false) -> float:
	var f: Font = font_b if bold else font
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size * U).x / U

## 居中写字（带阴影）
func text(s: String, cx: float, y: float, size: int, col: Color, sh = null, alpha := 1.0, bold := false) -> void:
	if alpha <= 0:
		return
	var f: Font = font_b if bold else font
	var x := (cx - text_w(s, size, bold) / 2.0 + OFS.x) * U
	var base := (y + OFS.y) * U + f.get_ascent(size * U)
	if sh != null:
		var c2: Color = sh
		c2.a = alpha
		for o in [Vector2(1, 1), Vector2(0, 1), Vector2(1, 0)]:
			cv.draw_string(f, Vector2(x, base) + o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size * U, c2)
	col.a = alpha
	cv.draw_string(f, Vector2(x, base), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size * U, col)

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

func dim(a := 0.62) -> void:
	var o := OFS
	OFS = Vector2.ZERO
	rect(0, 0, W + 1, H + 1, Color(0.008, 0.008, 0.03, a))
	OFS = o

func _draw_hud(c: CanvasItem) -> void:
	cv = c
	OFS = Vector2.ZERO
	if S == "play" or S == "menu" or S == "codex" or S == "words" or S == "chars":
		draw_hud_play()
		if touch_mode and S == "play":
			draw_touch_ui()
		if S != "play":
			dim()
			OFS = PO
			if S == "menu":
				draw_menu()
			elif S == "chars":
				draw_chars()
			elif S == "codex":
				draw_codex()
			else:
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
	OFS = Vector2.ZERO
	if H > W:
		rect(0, H / 2.0 - 12, W, 24, Color(0.02, 0.02, 0.06, 0.85))
		text("把手机横过来玩，画面更大", W / 2.0, H / 2.0 - 6, 10, C_GOLD, C_SH)

## 界面上要用精灵着色器画的东西（小克、图鉴肖像），画在界面文字之上的另一层
func _draw_hud_sprites(c: CanvasItem) -> void:
	cv = c
	no_cull = true
	var o := PO * U
	if S == "title":
		c.draw_set_transform(o + Vector2(160, 100 + sin(T * 2) * 2) * U, 0, Vector2(3 * U, 3 * U))
		draw_clawd(0, 0, int(T * 3) % 2, roundi(sin(T * 0.7)), fmod(T, 3.3) < 0.15)
	elif S == "intro" and intro_t > 13:
		c.draw_set_transform(o + Vector2(160, intro_clawd_y) * U, 0, Vector2(2 * U, 2 * U))
		draw_clawd(0, 0, int(T * 4) % 2, 0, fmod(T, 3.0) < 0.15)
	elif S == "chars":
		for i in CHARS.size():
			var r := char_rect(i)
			c.draw_set_transform(o + Vector2(r.position.x + r.size.x / 2.0, r.position.y + (19.0 if i == 4 else 15.0) + (sin(T * 3) * 1.0 if i == char_sel else 0.0)) * U, 0, Vector2((1.0 if i == 4 else 2.0) * U, (1.0 if i == 4 else 2.0) * U))
			draw_pc(i, 0, 0, int(T * 4) % 2 if i == char_sel else 0, 0, fmod(T + i, 3.0) < 0.15)
	elif S == "codex":
		var t: String = ORDER[codex_sel]
		draw_portrait(t, 214, 58, 1 if t == "serp" else 2, known(t))
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	no_cull = false

var intro_clawd_y := 140.0

func restart_arm_v() -> bool:
	return false

func draw_hud_play() -> void:
	# 左上：生命、体温、页尘 / 余烬 / 信标
	for i in P.maxhp:
		icon(HEART, 4 + i * 6.5, 3.5, Pal.rc(CLAY, 5) if i < P.hp else Pal.rc(RUIN, 5))
	var wk := P.warm / P.maxwarm
	var bw := 56.0
	var fl := P.warm < 25 and sin(T * 10) > 0
	icon(I_TH, 4, 10.5, C_RED if fl else Pal.rc(ICE, 5))
	box(8.5, 11.5, bw + 1, 4, C_SH, Pal.rc(RUIN, 6))
	var cold := wk < 0.3
	rect(9, 12, bw * wk, 3, Pal.rc(ICE if cold else EMBER, 4))
	rect(9, 12, bw * wk, 1, Pal.rc(ICE if cold else EMBER, 5))
	if wk > 0.02:
		rect(9 + bw * wk - 0.5, 12, 0.5, 3, Pal.rc(ICE if cold else GOLD, 6))
	text_l(str(ceili(P.warm)), bw + 12, 9, 8, C_TEAL if cold else C_TXT, C_SH)
	var x := 4.0
	icon(I_DUST, x, 19, Pal.rc(ORE, 5))
	text_l(str(P.dust), x + 5, 16.5, 8, C_TXT, C_SH)
	x += 9 + text_w(str(P.dust), 8)
	icon(I_EMB, x, 19, Pal.rc(EMBER, 5))
	text_l(str(P.ember), x + 5, 16.5, 8, C_TXT, C_SH)
	x += 9 + text_w(str(P.ember), 8)
	if P.beacons:
		icon(I_BEA, x, 19, Pal.rc(GOLD, 5))
		text_l(str(P.beacons), x + 5, 16.5, 8, C_TXT, C_SH)
	# 右上：暗潮钟、小地图、书页数
	var ph := fposmod(tide_t, 150.0)
	var dark := tide_t > 0 and ph >= 112
	var left := 150 - ph if dark else (112 - tide_t if tide_t < 0 else 112 - ph)
	var clock := "%s %d:%02d" % ["暗潮" if dark else "星息", int(left / 60), int(fmod(left, 60))]
	text_r(clock, W - 4, 2, 9, C_RED if dark else C_GOLD, C_SH)
	draw_minimap(W - 46, 15, 42)
	draw_sentence_hud()
	draw_pen_hud()
	text_r("%s书页 %d/3" % ["" if unlocked < 2 else ("一·" if chapter == 1 else "二·"), ch_bound()], W - 4, 59, 9, C_TEAL, C_SH)
	# 首领血条
	var bs := boss()
	if bs and (bs.st == "fight" or bs.st == "rise"):
		var hk := clampf(bs.hp / DEF[bs.t].hp, 0.0, 1.0)
		var bm := SERP if bs.t == "serp" else WINE
		text(DEF[bs.t].name, W / 2.0, 3, 9, Pal.rc(bm, 5), C_SH)
		box(W / 2.0 - 60, 15, 120, 4, C_SH, Pal.rc(bm, 3))
		rect(W / 2.0 - 59.5, 15.5, 119 * hk, 3, Pal.rc(bm, 4))
		rect(W / 2.0 - 59.5, 15.5, 119 * hk, 1, Pal.rc(bm, 5))
	# 区域名
	var z: String = ZNAME[zn(P.x, P.y)]
	if z != zone_name:
		zone_name = z
		zone_t = 2.5
	zone_t -= 1.0 / 60.0
	if zone_t > 0 and S == "play":
		text(z, W / 2.0, 24, 10, C_DIM, C_SH, minf(1.0, zone_t))
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
			var dx := sx - W / 2.0
			var dy := sy - H / 2.0
			var k := minf((W / 2.0 - 10) / maxf(0.001, absf(dx)), (H / 2.0 - 10) / maxf(0.001, absf(dy)))
			var axp := W / 2.0 + dx * k
			var ayp := H / 2.0 + dy * k
			var a := atan2(dy, dx)
			var col := Pal.rc(ar[2], 6 if sin(T * 4) > 0 else 5)
			for t in 9:
				for w in range(-t, t + 1):
					var bx := axp + (cos(a) * (4 - t) - sin(a) * w * 0.7) * 0.5
					var by := ayp + (sin(a) * (4 - t) + cos(a) * w * 0.7) * 0.5
					hp(bx + 0.5, by + 0.5, C_SH)
					hp(bx, by, col)
	# 提示条：屏幕下方居中，带半透明底，不压到两边的按钮
	var ty := H - (46.0 if P.pens > 1 else 31.0)
	var tw := minf(300.0, W - (110.0 if touch_mode else 40.0))
	for i in range(toasts.size() - 1, -1, -1):
		var t: Dictionary = toasts[i]
		var a := minf(1.0, minf(t.t * 2, (t.max - t.t) * 6))
		var lines := wrap_text(t.s, 9, tw)
		for j in range(lines.size() - 1, -1, -1):
			var lw := text_w(lines[j], 9)
			rect(W / 2.0 - lw / 2.0 - 4, ty - 0.5, lw + 8, 12, Color(0.02, 0.02, 0.07, 0.6 * a))
			text(lines[j], W / 2.0, ty, 9, t.c, C_SH, a)
			ty -= 12
		ty -= 1
	if S == "play" and near_kiln() and not touch_mode:
		text("E 工坊 · C 换角色" if unlocked < 2 else "E 工坊 · C 换角色 · G 翻到第%s章" % ("二" if chapter == 1 else "一"), P.x - ox, P.y - oy - 22, 8, C_GOLD, C_SH, 0.8 + 0.2 * sin(T * 4))

## 左下角的小句子：每格一个字，金色字发光
func draw_sentence_hud() -> void:
	for i in P.slots.size():
		var x := 4 + i * 15
		var y := H - 18
		var s = P.slots[i]
		box(x, y, 14, 14, Color(0.03, 0.03, 0.08, 0.75), Pal.rc(GOLD if s != null and s.gold else RUIN, 5 if s != null else 4))
		if s != null:
			text(s.c, x + 7, y + 0.5, 9, C_GOLD if s.gold else kind_col(s.c), C_SH)
	if not touch_mode and P.slots.size() > 0:
		text_l("F 换字", 7 + P.slots.size() * 15, H - 14, 8, C_DIM, C_SH)

func kind_col(c: String) -> Color:
	match char_kind(c):
		"形": return C_TXT
		"动": return C_TEAL
		_: return C_CLAY

func draw_words_panel() -> void:
	box(10, 8, 300, 164, C_PANEL, Pal.rc(ORE, 4))
	text("句子", 160, 11, 12, C_GOLD, C_SH, 1.0, true)
	for i in P.slots.size():
		var r := slot_rect(i)
		var s = P.slots[i]
		var line := Pal.rc(GOLD, 5) if s != null and s.gold else (Pal.rc(ORE, 5) if i == word_sel else Pal.rc(RUIN, 5))
		box(r.position.x, r.position.y, r.size.x, r.size.y, Pal.rc(SPACE, 2), line)
		if s != null:
			text(s.c, r.position.x + 13, r.position.y + 2, 15, C_GOLD if s.gold else kind_col(s.c), C_SH, 1.0, true)
			text(char_kind(s.c), r.position.x + 13, r.position.y + 27, 8, C_DIM, null)
	# 效果说明
	var y := 73.0
	var shown := 0
	for l in loadout_lines():
		for ln in wrap_text(l, 8, 280):
			if shown < 5:
				text(ln, 160, y, 8, C_TEAL if l.begins_with("成词") else (C_DIM if l.begins_with("（") else C_TXT), C_SH)
			y += 10
			shown += 1
	# 背包
	text_l("背包（点一下填进句子的空格）", 20, 124, 8, C_DIM, null)
	for i in mini(P.bag.size(), 14):
		var r := bag_rect(i)
		var w = P.bag[i]
		box(r.position.x, r.position.y, r.size.x, r.size.y, Pal.rc(SPACE, 2), Pal.rc(GOLD if w.gold else RUIN, 5))
		text(w.c, r.position.x + 9, r.position.y + 1, 11, C_GOLD if w.gold else kind_col(w.c), C_SH)
	if P.bag.is_empty():
		text_l("（空）", 22, 139, 8, C_DIM, null)
	elif P.bag.size() > 14:
		text_r("…还有 %d 个" % (P.bag.size() - 14), 306, 124, 8, C_DIM, null)
	var known_w: Array = save.words
	var hint := "在炉灯边可以点句子里的字把它取下来" if near_kiln() else "在外面只能往空格里填字，回炉灯才能重排"
	text("%s · 已发现的词 %d/%d · %s" % [hint, known_w.size(), WD.words.size(), "点外面关闭" if touch_mode else "F 关闭"], 160, 158, 8, C_DIM, C_SH)

func draw_minimap(x: float, y: float, s: float) -> void:
	box(x, y, s, s, Color(0.04, 0.043, 0.094, 0.85), C_LINE)
	var k := s / (WR * 2 + 60)
	var cx := x + s / 2.0
	var cy := y + s / 2.0
	for r in rocks:
		var c := Pal.rc(MIRROR if r.zone == "echo" else (WINE if r.box else RUIN), (4 if r.box else 6) if r.R > 18 else 5)
		if r.box:
			rect(snap(cx + (r.x - r.hw) * k), snap(cy + (r.y - r.hh) * k), maxf(0.5, snap(r.hw * 2 * k)), maxf(0.5, snap(r.hh * 2 * k)), c)
		elif r.R > 18:
			rect(snap(cx + r.x * k), snap(cy + r.y * k), 1, 1, c)
		else:
			hp(cx + r.x * k, cy + r.y * k, c)
	rect(snap(cx) - 0.5, snap(cy) - 0.5, 1.5, 1.5, Pal.rc(GOLD, 6))
	for b in BEA:
		rect(snap(cx + b.x * k), snap(cy + b.y * k), 1, 1, Pal.rc(EMBER, 5))
	for pg in PAGES:
		if (pg.state == "free" or pg.state == "sealed") and sin(T * 5) > -0.3:
			var qx := snap(cx + pg.x * k)
			var qy := snap(cy + pg.y * k)
			rect(qx - 0.5, qy - 1, 1.5, 2, Pal.rc(ORE, 4))
			rect(qx, qy - 0.5, 0.5, 1, Pal.rc(ORE, 6))
	for q in INK:
		rect(snap(cx + q.x * k) - 0.5, snap(cy + q.y * k) - 0.5, 1.5 if q.z > 30 else 1.0, 1.5 if q.z > 30 else 1.0, Pal.rc(GRAV, 3))
	for l in LAMPS:
		if l.lit > 0:
			hp(cx + l.x * k, cy + l.y * k, Pal.rc(GOLD, 6))
	var bs := boss()
	if bs and bs.st == "fight":
		rect(snap(cx + bs.x * k) - 0.5, snap(cy + bs.y * k) - 0.5, 1.5, 1.5, Pal.rc(SERP, 6))
	var px := snap(cx + P.x * k)
	var py := snap(cy + P.y * k)
	if sin(T * 8) > 0:
		rect(px - 1, py, 2.5, 0.5, Pal.rc(CLAY, 5))
		rect(px, py - 1, 0.5, 2.5, Pal.rc(CLAY, 5))
	rect(px - 0.5, py - 0.5, 1.5, 1.5, Pal.rc(PAPER, 6))

## 触屏按钮的位置（state / hud / 输入共用）：0 冲 1 烬 2 标或坊
func touch_btn(i: int) -> Rect2:
	match i:
		0: return Rect2(W - 42, H - 42, 36, 36)
		1: return Rect2(W - 42, H - 76, 36, 30)
		2: return Rect2(W - 42, H - 110, 36, 30)
		3: return Rect2(W - 82, H - 36, 36, 30)
		_: return Rect2(W - 122, H - 36, 36, 30)

func draw_touch_ui() -> void:
	for t in touches.values():
		if t.kind == "move":
			var st: Vector2 = t.start
			for i in 48:
				var a := i / 48.0 * TAU
				hp(st.x + cos(a) * 18, st.y + sin(a) * 18, Pal.rc(RUIN, 6))
			var kp: Vector2 = st + joy * 18
			box(kp.x - 3, kp.y - 3, 6, 6, Pal.rc(CLAY, 4), Pal.rc(CLAY, 6))
	var names := ["冲", "烬", "坊" if near_kiln() else "标", "翻章", "角色"]
	var mats := [CLAY, EMBER, GOLD, ORE, CLAY]
	for i in 5:
		if i == 4 and not near_kiln():
			continue
		if i == 2 and not near_kiln() and P.beacons == 0:
			continue
		if i == 3 and not (near_kiln() and unlocked >= 2):
			continue
		var r := touch_btn(i)
		box(r.position.x, r.position.y, r.size.x, r.size.y, Color(0.04, 0.04, 0.1, 0.55), Pal.rc(mats[i], 4))
		text(names[i], r.get_center().x, r.get_center().y - (8 if i < 3 else 6), 12 if i < 3 else 9, C_TXT if i == 0 else C_GOLD, C_SH)

func draw_menu() -> void:
	box(12, 8, 296, 164, C_PANEL, Pal.rc(CLAY, 4))
	text("炉灯工坊", 160, 11, 12, C_GOLD, C_SH, 1.0, true)
	icon(I_DUST, 262, 16, Pal.rc(ORE, 5))
	text_l(str(P.dust), 268, 13, 9, C_TXT, C_SH)
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
			text_l(str(i + 1), x + 4, y + 2, 8, C_GOLD, C_SH)
		text_l(it.name, x + (12 if not touch_mode else 5), y + 1, 10, C_TXT if can or full else C_DIM, C_SH)
		var sub := ""
		if it.k == "forge":
			sub = "背包 %d 字" % P.bag.size()
		elif it.k == "beacon":
			sub = "有 %d 座" % P.beacons
		else:
			sub = "●".repeat(lv) + "○".repeat(int(it.max) - lv)
		text_l(sub, x + 5, y + 16, 8, C_DIM, null)
		if full:
			text_r("已满", x + r.size.x - 4, y + 16, 8, C_DIM, null)
		else:
			text_r(str(cost), x + r.size.x - 10, y + 16, 8, C_TXT if can else C_RED, C_SH)
			icon(I_DUST, x + r.size.x - 8.5, y + 19, Pal.rc(ORE, 5 if can else 3), null)
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
	text("打造" if not full2 else "已满", br.get_center().x, br.position.y + 2, 10, C_GOLD if can2 else C_DIM, C_SH, 1.0, true)
	text("点卡片选择 · 点「打造」 · 点外面关闭" if touch_mode else "数字键直接打造 · 点卡片选择 · E 关闭", 160, 159.5, 8, C_DIM, null)

func draw_codex() -> void:
	box(8, 8, 304, 164, C_PANEL, C_LINE)
	var n := 0
	for t in ORDER:
		if known(t):
			n += 1
	text("星海生物图鉴  %d/%d" % [n, ORDER.size()], 160, 11, 11, C_GOLD, C_SH, 1.0, true)
	for i in ORDER.size():
		var t: String = ORDER[i]
		var r := codex_rect(i)
		if i == codex_sel:
			rect(r.position.x, r.position.y, r.size.x, r.size.y, Pal.rc(RUIN, 3))
		text_l(DEF[t].name if known(t) else "？？？", r.position.x + 3, r.position.y + 1, 9, (C_RED if is_boss_t(t) else C_TXT) if known(t) else C_DIM, C_SH)
	var t: String = ORDER[codex_sel]
	if known(t):
		text(DEF[t].name, 214, 85, 12, C_GOLD, C_SH, 1.0, true)
		text(LORE[t][0], 214, 101, 9, C_TEAL, C_SH)
		var ls := wrap_text(LORE[t][1], 9, 180)
		for i in ls.size():
			text(ls[i], 214, 113 + i * 11, 9, C_TXT, C_SH)
	else:
		text("还没遇到过。去更远的地方找找。", 214, 100, 9, C_DIM, C_SH)
	text("点名字查看 · 点外面关闭" if touch_mode else "WASD 或鼠标选择 · Tab 关闭", 160, 158, 8, C_DIM, C_SH)

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
	dm.r = DEF[t].r
	if t == "leech":
		for i in range(12, 0, -1):
			dm.tr.append(-i * 1.2)
			dm.tr.append(sin(T * 3 + i * 0.5) * 1.5)
	if t == "serp":
		dm.st = "fight"
		for i in 12:
			dm.seg.append(Vector2(-6 - i * 4.5, sin(T * 2 + i * 0.6) * 3))
	if t == "worm":
		dm.ang = 0
		dm.x = 8
		for i in 7:
			dm.seg.append(Vector2(8 - (i + 1) * 3.4, sin(T * 3 + i * 0.8) * 1.6))
	if t == "redact":
		dm.st = "fight"
		dm.ha = T * 0.6
	if t == "blot":
		dm.sp = 0.5 + 0.5 * sin(T * 3)
	if t == "clam":
		dm.y = 3
	cv.draw_set_transform((PO + Vector2(cx, cy)) * U, 0, Vector2(sc * U, sc * U))
	mono = not k
	draw_creature(dm, 0)
	mono = false

func draw_ending() -> void:
	if end_t <= 6:
		return
	dim()
	OFS = PO
	box(50, 28, 220, 128, C_PANEL, Pal.rc(GOLD, 4))
	text("%s · 已装订" % ("第一章" if chapter == 1 else "第二章"), 160, 36, 14, C_GOLD, C_SH, 1.0, true)
	var lines := [
		"用时  %d 分 %d 秒" % [int(gt / 60), int(fmod(gt, 60))],
		"碎掉过  %d 次" % P.deaths,
		"熬过暗潮  %d 次" % tides,
		"遇见生物  %d / %d 种" % [seen.size(), ORDER.size()],
		"拾回页尘  %d" % P.dust_total,
	]
	for i in lines.size():
		text(lines[i], 160, 61 + i * 13, 10, C_TXT, C_SH)
	if chapter == 1:
		text("图书馆的第一层亮了。再往里，是阅览室的残骸。", 160, 127, 9, C_TEAL, C_SH)
		text("%s 前往第二章" % ("点一下" if touch_mode else "Enter / 点击"), 160, 140, 8, C_GOLD, C_SH, 0.6 + 0.4 * sin(T * 3))
	else:
		text("图书馆的第二层亮了。还有九千九百九十八层。", 160, 127, 9, C_TEAL, C_SH)
		text("%s 继续自由探索" % ("点一下" if touch_mode else "Enter / 点击"), 160, 140, 8, C_DIM, C_SH, 0.6 + 0.4 * sin(T * 3))

func draw_title() -> void:
	dim()
	OFS = PO
	text("散 页", 160, 26, 30, C_CLAY, C_SH, 1.0, true)
	text("U N B O U N D", 160, 66, 9, C_DIM, C_SH)
	text("一只小陶灵，在碎掉的宇宙图书馆里拾回文字", 160, 121, 10, C_TXT, C_SH)
	if has_run():
		var names := ["继续旅程", "再点一次确认" if restart_arm_v() else "重新开始"]
		for i in 2:
			var r := title_btn(i)
			box(r.position.x, r.position.y, r.size.x, r.size.y, Pal.rc(CLAY, 2) if i == 0 else Pal.rc(SPACE, 2), Pal.rc(GOLD, 5) if i == 0 else Pal.rc(RUIN, 5))
			text(names[i], r.get_center().x, r.position.y + 2, 10, C_GOLD if i == 0 else C_DIM, C_SH)
	else:
		text("点击开始", 160, 142, 11, C_GOLD, C_SH, 0.6 + 0.4 * sin(T * 3))
	if DisplayServer.is_touchscreen_available():
		text("左边拖动移动 · 右边按住射击 · 右下角冲刺", 160, 164, 8, C_DIM, C_SH)
	else:
		text("WASD 移动 · 鼠标射击 · 空格冲刺 · E 工坊 · F 句子 · Q 余烬 · B 信标 · Tab 图鉴", 160, 164, 8, C_DIM, C_SH)
	if int(save.clears):
		text("已通关 %d 次" % int(save.clears), 160, 6, 8, C_GOLD, C_SH)

func draw_intro() -> void:
	dim(0.86)
	OFS = PO
	var y := 30.0
	for i in INTRO.size():
		var a := clampf((intro_t - i * 3.2) / 1.2, 0, 1)
		if a <= 0:
			continue
		for l in wrap_text(INTRO[i], 10, 270):
			text(l, 160, y, 10, C_GOLD if i == 4 else C_TXT, C_SH, a)
			y += 13
		y += 6
	intro_clawd_y = y + 14
	text("点击跳过", 290, 166, 8, C_DIM, C_SH, 0.6)

func draw_dead() -> void:
	var a := minf(1.0, dead_t)
	if dead_t > 0.4:
		dim()
		text("小克碎了", W / 2.0, H / 2.0 - 20, 16, C_CLAY, C_SH, a, true)
		text("炉灯正在把它重新烧好……", W / 2.0, H / 2.0 + 6, 10, C_DIM, C_SH, a)

func pen_rect() -> Rect2:
	# 左下角句子上方的“笔”按钮
	return Rect2(4, H - 33, 44, 13)

func draw_pen_hud() -> void:
	if P.pens <= 1:
		return
	var r := pen_rect()
	box(r.position.x, r.position.y, r.size.x, r.size.y, Color(0.03, 0.03, 0.08, 0.75), Pal.rc(CLAY, 4))
	if P.pen == 4 and P.charge > 0:
		rect(r.position.x + 0.5, r.position.y + r.size.y - 2, (r.size.x - 1) * P.charge, 1.5, Pal.rc(GOLD if P.charge >= 1.0 else EMBER, 5))
	text_l(PENS[P.pen].name, r.position.x + 3, r.position.y + 0.5, 9, C_CLAY, C_SH)
	for i in P.pens:
		rect(r.position.x + 25 + i * 3.5, r.position.y + 5.5, 2.5, 2.5, Pal.rc(CLAY, 6) if i == P.pen else Pal.rc(RUIN, 6))
	if not touch_mode:
		text_l("R 换笔", r.position.x + r.size.x + 3, r.position.y + 1.5, 8, C_DIM, C_SH)

func codex_rect(i: int) -> Rect2:
	# 图鉴名单：左边两列，每列 7 个
	return Rect2(12 + (i / 7) * 50, 32 + (i % 7) * 16, 49, 15)

func is_boss_t(t: String) -> bool:
	return t == "serp" or t == "redact"

func draw_chars() -> void:
	box(12, 8, 296, 164, C_PANEL, Pal.rc(CLAY, 4))
	text("换一副陶身", 160, 11, 12, C_GOLD, C_SH, 1.0, true)
	for i in CHARS.size():
		var c: Dictionary = CHARS[i]
		var r := char_rect(i)
		var sel := i == char_sel
		box(r.position.x, r.position.y, r.size.x, r.size.y, Pal.rc(RUIN, 3) if sel else Pal.rc(SPACE, 2), Pal.rc(GOLD, 5) if sel else Pal.rc(RUIN, 4))
		var cx := r.position.x + r.size.x / 2.0
		text(c.name, cx, r.position.y + 31, 10, C_GOLD if sel else C_TXT, C_SH, 1.0, true)
		text(c.tag, cx, r.position.y + 45, 7, C_TEAL, C_SH)
		if i == P.ch:
			text("现在的样子", cx, r.position.y + r.size.y - 11, 7, C_DIM, null)
	# 选中的那只：详细说明
	var c2: Dictionary = CHARS[char_sel]
	box(18, 100, 284, 54, Pal.rc(SPACE, 1), Pal.rc(RUIN, 4))
	var ls := wrap_text(c2.desc, 9, 268)
	for j in ls.size():
		text(ls[j], 160, 104 + j * 11, 9, C_TXT, C_SH)
	if char_sel != P.ch:
		text("%s换上「%s」" % ["点它的卡片" if touch_mode else "Enter ", c2.name], 160, 104 + ls.size() * 11 + 1, 8, C_GOLD, null, 0.7 + 0.3 * sin(T * 4))
	text("升级、字和书页都会带着走，随时能换回来 · %s" % ("点外面关闭" if touch_mode else "A/D 选 · C 关闭"), 160, 159, 8, C_DIM, null)

