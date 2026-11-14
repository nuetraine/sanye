extends Node2D
## 状态与玩法逻辑：常量、数据、世界生成、玩家、生物、子弹、工坊、存档。
## 继承链：game_state → game_art（世界绘制）→ game_hud（界面）→ game（主循环/输入）

## 《散页 Unbound》主逻辑 —— 从 HTML 原型完整移植。
## 小克（一只陶灵）在碎掉的宇宙图书馆里飞行、射击、挖矿、保暖，
## 找回三张失落之页带回炉灯装订。包含：工坊升级、信标、暗潮、
## 八种生物（含首领回声蛇）、图鉴、结局与存档。

const PAINTER := preload("res://scripts/painter.gd")
const U := 2                 # 一个“单位”= 2 个精细像素（画面精细度是原来的两倍）
var W := 320                 # 屏幕宽高（单位）。窗口变大时会跟着变，至少 320×180
var H := 180
var PO := Vector2.ZERO       # 面板（工坊/图鉴/句子…）居中时的偏移
const WR := 1350.0
const GC := 64
const SUNV := Vector3(-0.5496, -0.4997, 0.6695)

enum { SPACE, ROCK, ORE, EMBER, CLAY, JELLY, MOTH, LEECH, ICE, GRAV, MIRROR, SERP, PAPER, GOLD, RUIN, WINE }

const ZNAME := {"shallow": "浅页带", "leech": "蛭环", "nursery": "坍缩苗圃", "echo": "回声深处", "drift": "冷寂漂流区"}
const DEF := {
	"hush": {"name": "静默水母", "hp": 3, "r": 6, "dust": 3, "ember": 0.0},
	"folio": {"name": "书鳐", "hp": 8, "r": 7, "dust": 10, "ember": 0.0},
	"clam": {"name": "冰核贝", "hp": 2, "r": 5, "dust": 2, "ember": 3.0},
	"moth": {"name": "蚀字蛾", "hp": 1, "r": 3, "dust": 1, "ember": 0.0},
	"leech": {"name": "轨道蛭", "hp": 4, "r": 5, "dust": 5, "ember": 0.3},
	"mite": {"name": "镜螨", "hp": 4, "r": 5, "dust": 8, "ember": 0.0},
	"grav": {"name": "引力胎", "hp": 10, "r": 6, "dust": 16, "ember": 0.0},
	"serp": {"name": "回声蛇", "hp": 48, "r": 8, "dust": 40, "ember": 4.0},

}

const LORE := {
	"hush": ["浮游 · 无害但冰冷", "以声音为食的透明钟形生物。它们漂过的地方，连星星的嗡鸣都会停下来。碰到它会冷到陶心，体温骤降。"],
	"folio": ["迁徙 · 温顺", "大散页之后，有些书没有死。它们学会了扇动封皮，在星海里成群迁徙，边飞边抖落不想要的段落——那就是页尘。"],
	"clam": ["固着 · 可采集", "冰壳里裹着一粒火。没人知道它们从哪儿学会了保存温暖，只知道它们每隔一会儿要张嘴喘口气——那时射中火珠，就能取到余烬。"],
	"moth": ["群居 · 暗潮时出没", "啃食一切写着字的东西。暗潮来临时成群出现，扑向光——也扑向你，因为你身上全是字。炉火太烫，它们不敢靠近。"],
	"leech": ["伏击 · 绕石而居", "一生绕着一颗石头转，像在念一句咒语。看到路过的小陶灵会停下、发红、然后直线扑来。躲开那一下就好。"],
	"mite": ["反射 · 只能打背面", "背着一面磨得发亮的壳，会把你说过的话原样还给你——正面射它，字弹会被弹回来。它转身很慢，绕到背后打那块粉色软肉。"],
	"grav": ["幼体黑洞 · 贪吃", "还没长大的黑洞幼体，正处在什么都想往嘴里塞的年纪。会把你、你的字弹、地上的页尘一起往里拽。"],
	"serp": ["守页者 · 首领", "吞下所有在虚空里说出口的话，然后一遍遍复述。它走的路，永远是你刚刚走过的路——别回头踩自己的脚印。只有头会受伤。"],

}

const ORDER := ["hush", "folio", "clam", "moth", "leech", "mite", "grav", "serp"]
const TARGET := {"hush": 15, "folio": 9, "leech": 15, "grav": 7, "mite": 10}
const PAGE_TXT := [
	"「寒冷不是热的缺席，而是一切停止说话的声音。」——体温上限 +30，保温 +15%",
	"「万物彼此吸引，因为它们都想被读到。」——字弹伤害 +1",
	"「宇宙说出的第一个字还在回响，它叫『在』。」",

]

const INTRO := [
	"很久以前，「万语星图书馆」环绕着一颗叫「残烛」的恒星旋转，收藏着宇宙里说过的每一句话。",
	"后来残烛打了个寒颤。图书馆碎了——那一天叫做「大散页」。",
	"书页散成星尘。有的变成了生物，有的变成了寒冷，有的沉进了黑洞。",
	"你是小克，图书馆炉膛里烧出来的最后一只陶灵。",
	"去把散页拾回来吧。",

]


class Creature:
	var t := ""
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var hp := 1.0
	var r := 5.0
	var age := 0.0
	var ph := 0.0
	var st := "idle"
	var tm := 0.0
	var cd := 0.0
	var flash := 0.0
	var dead := false
	var hx := 0.0
	var hy := 0.0
	var off := 0
	var flee := 0.0
	var home: Rock = null
	var orR := 0.0
	var ang := 0.0
	var w := 0.0
	var tr := PackedFloat32Array()
	var na := 0.0
	var open := 0.0
	var sp := 0.0
	var sing := 0.0
	var seg: Array[Vector2] = []
	var burst_t := 4.0
	var ha := 0.0
	var burn := 0.0
	var burn_t := 0.0
	var slow := 0.0
	var calm := 0.0

class EBullet:
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var life := 4.0
	var m := 11

class Beacon:
	var x := 0.0
	var y := 0.0
	var hp := 10.0
	var age := 0.0

class Bullet:
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var life := 0.75
	var max_life := 0.75
	var dmg := 1
	# 字句效果
	var mat := 13
	var big := false
	var small := false
	var carve_r := 2.3
	var pierce := 0
	var ret := false
	var returning := false
	var home := 0.0
	var split := 0
	var burn := 0.0
	var frost := 0.0
	var grav := 0.0
	var calm := 0.0
	var orbit := 0.0
	var orb_a := 0.0
	var sp := 265.0
	var hit: Array = []
	var w := {}

class Pick:
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var k := "dust"
	var v := 1
	var age := 0.0
	var wc := ""
	var gold := false

class Part:
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var life := 0.5
	var mx := 0.5
	var m := 0
	var l := 4.0
	var emit := false

class PlayerState:
	var x := 0.0
	var y := 34.0
	var vx := 0.0
	var vy := 0.0
	var hp := 5
	var maxhp := 5
	var warm := 100.0
	var maxwarm := 100.0
	var dust := 0
	var ember := 1
	var dash_cd := 0.0
	var dash_t := 0.0
	var fire_cd := 0.0
	var ax := 1.0
	var ay := 0.0
	var cold_t := 0.0
	var heal_t := 0.0
	var deaths := 0
	var dust_total := 0
	var anim := 0.0
	var moving := false
	var inv := 0.0
	var kills := 0
	var dmg := 1
	var beacons := 0
	var carry: Array[int] = []
	var bound := 0
	var glaze := 0.0
	var bag: Array = []        # 背包里的字 {"c": "穿", "gold": false}
	var slots: Array = []      # 句槽，空位为 null
	var shot_i := 0

# ---------- 状态 ----------
var S := "title"
var T := 0.0
var gt := 0.0
var tide_t := -35.0
var TIDE := 0.0
var SUN := 1.0
const AMB := 0.08
var tides := 0
var tide_w := false
var tide_d := false
var tide_sp := 0.0
var intro_t := 0.0
var dead_t := 0.0
var P := PlayerState.new()
var cr: Array[Creature] = []
var PB: Array[Bullet] = []
var PK: Array[Pick] = []
var PT: Array[Part] = []
var rocks: Array[Rock] = []
var grid := {}
var dirty := {}
var toasts: Array = []
var tips := {}
var seen := {}
var lights: Array[Vector4] = []
var cam_pos := Vector2(0, 20)
var shk := 0.0
var duck := 1.0
var spawn_t := 3.0
var chime_i := 0
var chime_t := 0.0
var zone_name := ""
var zone_t := 0.0
var R0 := RandomNumberGenerator.new()
var WD := {}                 # data/words.json
var LO := {}                 # 当前句子算出的字弹配置
var word_sel := -1
var PAGES: Array[Dictionary] = []
var UP := {"kiln": 0, "bolt": 0, "shell": 0, "glaze": 0, "puff": 0}
var BEA: Array[Beacon] = []
var EB: Array[EBullet] = []
var serp: Creature = null
var TRX := PackedFloat32Array()
var TRY := PackedFloat32Array()
var tr_i := 0
var menu_sel := 0
var codex_sel := 0
var end_t := 0.0
var free_mode := false
var save := {"codex": [], "clears": 0, "words": []}
const SAVE_PATH := "user://sanye-save.json"
var SHOP: Array[Dictionary] = [
	{"k": "beacon", "name": "信标", "desc": "一座小火塔，放下后周围变暖（B 放置）", "cost": [25], "max": 99},
	{"k": "kiln", "name": "炉火", "desc": "炉灯暖圈变大，修补裂缝更快", "cost": [35, 70, 120], "max": 3},
	{"k": "bolt", "name": "句槽", "desc": "句子多一格（最多 5 格）", "cost": [45, 100], "max": 2},
	{"k": "shell", "name": "陶壳", "desc": "生命上限 +1，并补满", "cost": [40, 90], "max": 2},
	{"k": "glaze", "name": "保温釉", "desc": "在外面体温流失 -20%", "cost": [30, 75], "max": 2},
	{"k": "puff", "name": "喷气孔", "desc": "冲刺冷却减半", "cost": [50], "max": 1},
	{"k": "forge", "name": "炼字", "desc": "用页尘炼出一个随机的字", "cost": [30], "max": 999},
]

# 画图鉴肖像时：不按摄像机裁剪，可选单色剪影
var no_cull := false
var mono := false
var mono_col := Color.BLACK

# ---------- 输入 ----------
var jp := {}
var mouse_down := false
var click_q := false
var touch_mode := false
var touches := {}
var joy := Vector2.ZERO
var touch_fire := false
var touch_aim := Vector2.ZERO
var tap_pos := Vector2(-99, -99)
var mouse_moved := false

# ---------- 画面 ----------
var camera: Camera2D
var rock_layer: Node2D
var zone_painter: Node2D
var ent_painter: Node2D
var hud_painter: Node2D
var rock_mat: ShaderMaterial
var bg_mat: ShaderMaterial
var vig_mat: ShaderMaterial
var cv: CanvasItem
var ox := 0.0
var oy := 0.0
var font: Font
var font_b: Font
var wrap_cache := {}
var C_TXT := Color("#fff1d6")
var C_SH := Color("#07060f")
var C_DIM := Color("#9aa3c0")
var C_GOLD := Color("#ffd27a")
var C_TEAL := Color("#aeeee8")
var C_RED := Color("#ff7a6a")
var C_CLAY := Color("#f0a07e")
var C_PANEL := Color("#0a0b18")
var C_LINE := Color("#3a3f66")

# 世界生成
func zn(x: float, y: float) -> String:
	var d := sqrt(x * x + y * y)
	var a := atan2(y, x)
	if d < 480.0:
		return "shallow"
	if absf(a) < 0.95:
		return "leech"
	if a > 1.45 and a < 3.05:
		return "nursery"
	if a < -0.7 and a > -2.45:
		return "echo"
	return "drift"

func _gkey(gx: int, gy: int) -> Vector2i:
	return Vector2i(gx, gy)

func grid_add(r: Rock) -> void:
	for gy in range(floori(float(r.y - r.c) / GC), floori(float(r.y + r.c) / GC) + 1):
		for gx in range(floori(float(r.x - r.c) / GC), floori(float(r.x + r.c) / GC) + 1):
			var k := Vector2i(gx, gy)
			if not grid.has(k):
				grid[k] = []
			grid[k].append(r)

func grid_del(r: Rock) -> void:
	for k in grid:
		grid[k].erase(r)

func rock_at(x: float, y: float) -> Rock:
	var a = grid.get(Vector2i(floori(x / GC), floori(y / GC)))
	if a == null:
		return null
	var ix := floori(x)
	var iy := floori(y)
	for r in a:
		if r.at(ix, iy):
			return r
	return null

func gen_rocks() -> void:
	for r in rocks:
		if r.spr:
			r.spr.queue_free()
	rocks.clear()
	grid.clear()
	var t := 0
	while t < 5000 and rocks.size() < 200:
		t += 1
		var a := R0.randf() * TAU
		var d := sqrt(R0.randf()) * WR
		var x := cos(a) * d
		var y := sin(a) * d
		var z := zn(x, y)
		if z == "echo" and R0.randf() < 0.45:
			continue
		var R := 0.0
		match z:
			"nursery": R = 6 + R0.randf() * 14
			"shallow": R = 8 + R0.randf() * 18
			"leech": R = 11 + R0.randf() * 24
			"echo": R = 9 + R0.randf() * 18
			_: R = 10 + R0.randf() * 28
		var ok := d >= 120 + R and d <= WR - 30
		for pg in PAGES:
			if Vector2(x - pg.x, y - pg.y).length() < 62 + R:
				ok = false
		if ok:
			for o in rocks:
				if Vector2(x - o.x, y - o.y).length() < R + o.R + 16:
					ok = false
					break
		if ok:
			rocks.append(Rock.build(roundi(x), roundi(y), roundi(R), z, R0))
	# 回声茧周围一圈白石
	for k in 9:
		var a := k / 9.0 * TAU + 0.3
		var x: float = PAGES[2].x + cos(a) * 120
		var y: float = PAGES[2].y + sin(a) * 120
		if Vector2(x, y).length() < WR - 20:
			rocks.append(Rock.build(roundi(x), roundi(y), 7 + (k % 3) * 3, "echo", R0))
	for r in rocks:
		grid_add(r)
		_make_sprite(r)

func _make_sprite(r: Rock) -> void:
	var s := Sprite2D.new()
	s.texture = r.tex
	s.centered = false
	s.position = Vector2(r.x0, r.y0)
	s.material = rock_mat
	rock_layer.add_child(s)
	r.spr = s

func mk(t: String, x: float, y: float) -> Creature:
	var c := Creature.new()
	c.t = t
	c.x = x
	c.y = y
	c.hx = x
	c.hy = y
	c.hp = DEF[t].hp
	c.r = DEF[t].r
	c.age = randf() * 10.0
	c.ph = randf() * TAU
	cr.append(c)
	return c

func zone_spot(t: String) -> Vector2:
	for k in 60:
		var a := randf() * TAU
		var d := sqrt(randf()) * WR
		var x := cos(a) * d
		var y := sin(a) * d
		if d < 150 or Vector2(x - P.x, y - P.y).length() < 230 or rock_at(x, y):
			continue
		if t == "hush" and d < 170:
			continue
		if t == "folio" and (d < 200 or d > 950):
			continue
		var z := zn(x, y)
		if t == "grav" and z != "nursery":
			continue
		if t == "mite" and not (z == "echo" or (z == "leech" and d > 650) or (z == "drift" and d > 700)):
			continue
		if Vector2(x - PAGES[2].x, y - PAGES[2].y).length() < 150:
			continue
		return Vector2(x, y)
	return Vector2.INF

func spawn(t: String) -> void:
	if t == "leech":
		var cand: Array[Rock] = []
		for r in rocks:
			if r.R >= 10 and Vector2(r.x - P.x, r.y - P.y).length() > 240 and (r.zone == "leech" or (Vector2(r.x, r.y).length() > 420 and randf() < 0.25)):
				cand.append(r)
		if cand.is_empty():
			return
		var r: Rock = cand[randi() % cand.size()]
		var c := mk("leech", r.x + r.R + 10, r.y)
		c.home = r
		c.orR = r.R + 11
		c.ang = randf() * TAU
		c.w = (-1.0 if randf() < 0.5 else 1.0) * (0.6 + randf() * 0.4)
		c.st = "orbit"
		return
	var p := zone_spot(t)
	if p == Vector2.INF:
		return
	if t == "folio":
		var ph := randf() * TAU
		for i in 3:
			var c := mk("folio", p.x + i * 10, p.y + i * 6)
			c.hx = p.x
			c.hy = p.y
			c.ph = ph
			c.off = i
		return
	var c := mk(t, p.x, p.y)
	if t == "mite":
		c.ang = randf() * TAU

func gen_clams() -> void:
	var n := 0
	var cand: Array[Rock] = []
	for r in rocks:
		if r.R >= 11 and r.zone != "nursery" and r.zone != "echo":
			cand.append(r)
	if cand.is_empty():
		return
	for t in 200:
		if n >= 24:
			break
		var r: Rock = cand[randi() % cand.size()]
		var a := randf() * TAU
		var ca := cos(a)
		var sa := sin(a)
		var px := r.x + ca * (r.R + 4)
		var py := r.y + sa * (r.R + 4)
		for s in r.R + 4:
			if rock_at(px - ca, py - sa):
				break
			px -= ca
			py -= sa
		if not rock_at(px - ca * 2, py - sa * 2):
			continue
		if Vector2(px, py).length() < 140:
			continue
		var c := mk("clam", px + ca * 1.5, py + sa * 1.5)
		c.na = a
		c.tm = randf() * 5
		c.st = "grow"
		n += 1

func new_world() -> void:
	PAGES = [
		{"id": 0, "x": cos(0.12) * 1080, "y": sin(0.12) * 1080, "name": "论寒冷", "state": "free"},
		{"id": 1, "x": cos(2.25) * 1050, "y": sin(2.25) * 1050, "name": "论引力", "state": "free"},
		{"id": 2, "x": 0.0, "y": -1110.0, "name": "论回声", "state": "sealed"},
	]
	gen_rocks()
	cr.clear()
	PB.clear()
	EB.clear()
	PK.clear()
	PT.clear()
	BEA.clear()
	gen_clams()
	for t in TARGET:
		var g := 0
		while count_type(t) < TARGET[t] and g < 60:
			g += 1
			spawn(t)
	# 守页的生物：第一页周围一窝轨道蛭，第二页旁边两只引力胎
	for i in 4:
		var c := mk("leech", PAGES[0].x, PAGES[0].y)
		c.orR = 30 if i < 2 else 46
		c.ang = i * 1.6
		c.w = (-1.0 if i % 2 else 1.0) * 0.7
		c.st = "orbit"
	for a in [0.4, 2.6]:
		mk("grav", PAGES[1].x + cos(a) * 55, PAGES[1].y + sin(a) * 55)
	serp = mk("serp", PAGES[2].x, PAGES[2].y)
	serp.st = "sleep"
	serp.burst_t = 4
	for i in 18:
		serp.seg.append(Vector2(PAGES[2].x, PAGES[2].y + i * 2))

func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if d is Dictionary:
		save.merge(d, true)

func persist() -> void:
	var codex: Array = save.codex
	for t in seen:
		if not codex.has(t):
			codex.append(t)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save))

func known(t: String) -> bool:
	return seen.has(t) or (save.codex as Array).has(t)

func count_type(t: String) -> int:
	var n := 0
	for c in cr:
		if c.t == t:
			n += 1
	return n

# 小工具
func toast(s: String, c: Color, d := 3.4) -> void:
	toasts.append({"s": s, "c": c, "t": d, "max": d})
	if toasts.size() > 3:
		toasts.pop_front()

func tip(id: String, s: String) -> void:
	if tips.has(id):
		return
	tips[id] = true
	toast(s, C_TEAL, 5)

func add_pick(x: float, y: float, k: String, vx := 0.0, vy := 0.0, v := 1) -> void:
	if PK.size() > 320:
		PK.pop_front()
	var p := Pick.new()
	p.x = x
	p.y = y
	p.vx = vx + (randf() - 0.5) * 14
	p.vy = vy + (randf() - 0.5) * 14
	p.k = k
	p.v = v
	PK.append(p)

func part(x: float, y: float, vx: float, vy: float, life: float, m: int, l: float, emit := false) -> void:
	if PT.size() > 900:
		PT.pop_front()
	var p := Part.new()
	p.x = x
	p.y = y
	p.vx = vx
	p.vy = vy
	p.life = life
	p.mx = life
	p.m = m
	p.l = l
	p.emit = emit
	PT.append(p)

func burst(x: float, y: float, n: int, m: int, l: float, sp := 50.0, life := 0.6, emit := true) -> void:
	for i in n:
		var a := randf() * TAU
		var s := sp * (0.3 + randf())
		part(x, y, cos(a) * s, sin(a) * s, life * (0.5 + randf() * 0.8), m, l, emit)

func kiln_r() -> float:
	return 64.0 + 24.0 * UP.kiln

func warm_zone(x: float, y: float) -> int:
	if Vector2(x, y).length() < kiln_r():
		return 2
	for b in BEA:
		if Vector2(x - b.x, y - b.y).length() < 56:
			return 1
	return 0

func key(k: int) -> bool:
	return Input.is_physical_key_pressed(k)

func pressed(k) -> bool:
	return jp.has(k)

# 主循环
var _bot := false
var _autoplay := false
var _ap_t := 0.0

## 菜单里用的指针位置（屏幕坐标）：鼠标或最后一次触摸
func pointer() -> Vector2:
	if touch_mode:
		return tap_pos
	return hud_painter.get_local_mouse_position() / U

## 面板里用的指针位置（面板按 320×180 设计，居中摆放）
func ppointer() -> Vector2:
	return pointer() - PO

func fire_locked() -> bool:
	return false

func title_btn(i: int) -> Rect2:
	return Rect2(84 + i * 80, 138, 72, 17)

# ---------- 进度存档：升级、字、书页都记下来，关掉再打开可以接着玩 ----------
func has_run() -> bool:
	return save.get("run") is Dictionary

func clear_run() -> void:
	save.erase("run")
	persist()

func save_run() -> void:
	if S == "title" or S == "intro" or P.hp <= 0:
		return
	var pgs := []
	for pg in PAGES:
		var carried: bool = pg.state == "carried"
		pgs.append({"state": "free" if carried else pg.state, "x": P.x if carried else pg.x, "y": P.y if carried else pg.y})
	var bea := []
	for b in BEA:
		bea.append([b.x, b.y, b.hp])
	save["run"] = {
		"dust": P.dust, "ember": P.ember, "beacons": P.beacons, "hp": P.hp, "maxhp": P.maxhp,
		"warm": P.warm, "maxwarm": P.maxwarm, "glaze": P.glaze, "dmg": P.dmg, "deaths": P.deaths,
		"dust_total": P.dust_total, "kills": P.kills, "slots": P.slots, "bag": P.bag, "up": UP,
		"pages": pgs, "bea": bea, "gt": gt, "tides": tides, "seen": seen.keys(), "tips": tips.keys(),
		"serp_dead": serp != null and serp.st == "dead", "free": free_mode,
	}
	persist()

func _word_ok(w) -> bool:
	return w is Dictionary and w.has("c") and WD.chars.has(w.c)

func load_run() -> void:
	var r: Dictionary = save.run
	P.dust = int(r.get("dust", 0))
	P.ember = int(r.get("ember", 1))
	P.beacons = int(r.get("beacons", 0))
	P.maxhp = clampi(int(r.get("maxhp", 5)), 5, 7)
	P.hp = clampi(int(r.get("hp", 5)), 1, P.maxhp)
	P.maxwarm = float(r.get("maxwarm", 100.0))
	P.warm = clampf(float(r.get("warm", 100.0)), 40.0, P.maxwarm)
	P.glaze = float(r.get("glaze", 0.0))
	P.dmg = int(r.get("dmg", 1))
	P.deaths = int(r.get("deaths", 0))
	P.dust_total = int(r.get("dust_total", 0))
	P.kills = int(r.get("kills", 0))
	var up: Dictionary = r.get("up", {})
	for k in UP:
		UP[k] = int(up.get(k, 0))
	P.slots.clear()
	for w in r.get("slots", []):
		P.slots.append({"c": w.c, "gold": bool(w.get("gold", false))} if _word_ok(w) else null)
	while P.slots.size() < int(WD.start_slots) + UP.bolt:
		P.slots.append(null)
	P.bag.clear()
	for w in r.get("bag", []):
		if _word_ok(w):
			P.bag.append({"c": w.c, "gold": bool(w.get("gold", false))})
	var pgs: Array = r.get("pages", [])
	P.bound = 0
	for i in mini(pgs.size(), PAGES.size()):
		PAGES[i].state = str(pgs[i].get("state", PAGES[i].state))
		PAGES[i].x = float(pgs[i].get("x", PAGES[i].x))
		PAGES[i].y = float(pgs[i].get("y", PAGES[i].y))
		if PAGES[i].state == "bound":
			P.bound += 1
	if bool(r.get("serp_dead", false)) and serp:
		serp.st = "dead"
		serp.hp = 0
	BEA.clear()
	for q in r.get("bea", []):
		var b := Beacon.new()
		b.x = float(q[0])
		b.y = float(q[1])
		b.hp = float(q[2])
		BEA.append(b)
	gt = float(r.get("gt", 0.0))
	tides = int(r.get("tides", 0))
	free_mode = bool(r.get("free", false))
	for t in r.get("seen", []):
		seen[str(t)] = true
	for t in r.get("tips", []):
		tips[str(t)] = true
	P.x = 0
	P.y = 34
	calc_loadout()

func near_kiln() -> bool:
	return Vector2(P.x, P.y).length() < kiln_r()

func try_buy(i: int) -> void:
	if i < 0 or i >= SHOP.size():
		return
	var it := SHOP[i]
	var lv := shop_lvl(it)
	if it.k != "beacon" and lv >= it.max:
		toast("已经满级了。", C_DIM)
		return
	var c := shop_cost(it)
	if P.dust < c:
		toast("页尘不够（还差 %d）。" % (c - P.dust), C_RED)
		return
	P.dust -= c
	match it.k:
		"beacon": P.beacons += 1
		"forge":
			var keys: Array = WD.chars.keys()
			give_word(keys[randi() % keys.size()], randf() < float(WD.gold_chance))
		"bolt":
			UP.bolt += 1
			P.slots.append(null)
			calc_loadout()
		"shell":
			UP.shell += 1
			P.maxhp += 1
			P.hp = P.maxhp
		_: UP[it.k] += 1
	Sfx.play("buy")
	save_run()
	burst(0, -6, 24, GOLD, 6, 50, 0.9)
	if it.k != "forge":
		toast("打造：" + it.name + ("（按 B 放置）" if it.k == "beacon" else " Lv%d" % shop_lvl(it)), C_GOLD)

func shop_lvl(it: Dictionary) -> int:
	if it.k == "forge":
		return 0
	return P.beacons if it.k == "beacon" else UP[it.k]

func shop_cost(it: Dictionary) -> int:
	var cs: Array = it.cost
	return cs[mini(shop_lvl(it), cs.size() - 1)] if it.k != "beacon" and it.k != "forge" else cs[0]

# ---------- 字句构筑 ----------
func load_words() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/words.json"))
	WD = d if d is Dictionary else {"chars": {}, "words": {}, "drop": {}, "gold_chance": 0.05, "forge_cost": 30, "start_slots": 3, "start_words": []}
	P.slots.clear()
	for i in int(WD.start_slots):
		P.slots.append(null)
	var sw: Array = WD.start_words
	for i in sw.size():
		P.slots[i] = {"c": sw[i], "gold": false}
	calc_loadout()

## 工坊布局：左边两列卡片，右边详情 + 打造按钮
func menu_rect(i: int) -> Rect2:
	return Rect2(18 + (i % 2) * 89, 30 + (i / 2) * 33, 85, 30)

func buy_rect() -> Rect2:
	return Rect2(210, 132, 80, 18)

## 句子面板的布局（state 和 hud 共用）
func slot_rect(i: int) -> Rect2:
	var n := P.slots.size()
	return Rect2(160 - n * 15 + i * 30 + 2, 34, 26, 26)

func bag_rect(i: int) -> Rect2:
	return Rect2(22 + i * 20, 136, 18, 18)

func upd_words_panel() -> void:
	if pressed(KEY_F) or pressed(KEY_ESCAPE) or pressed(KEY_TAB):
		S = "play"
		return
	if not click_q:
		return
	var mp := ppointer()
	for i in P.slots.size():
		if slot_rect(i).has_point(mp):
			if P.slots[i] == null:
				word_sel = i
			elif not near_kiln():
				toast("只能在炉灯边把字取下来。在外面只能往空格里填。", C_DIM)
			else:
				P.bag.append(P.slots[i])
				P.slots[i] = null
				word_sel = i
				Sfx.play("ping")
				calc_loadout()
			return
	for i in P.bag.size():
		if bag_rect(i).has_point(mp):
			var tgt := word_sel if word_sel >= 0 and word_sel < P.slots.size() and P.slots[word_sel] == null else P.slots.find(null)
			if tgt < 0:
				toast("句子满了。回炉灯把不要的字取下来。" if not near_kiln() else "先点句子里的一个字把它取下来。", C_DIM)
				return
			P.slots[tgt] = P.bag[i]
			P.bag.remove_at(i)
			word_sel = -1
			Sfx.play("beacon")
			calc_loadout()
			return
	if mp.y > 160 or mp.y < 10 or mp.x < 10 or mp.x > 310:
		S = "play"

func char_kind(c: String) -> String:
	return WD.chars[c].kind if WD.chars.has(c) else ""

## 拾到 / 炼出一个字：有空格就自动填进去，否则放进背包
func give_word(c: String, gold: bool) -> void:
	var w := {"c": c, "gold": gold}
	var placed := false
	for i in P.slots.size():
		if P.slots[i] == null:
			P.slots[i] = w
			placed = true
			break
	if not placed:
		P.bag.append(w)
	Sfx.play("page" if gold else "beacon")
	var tag := "金色字" if gold else "字"
	toast("拾到%s「%s」（%s）：%s" % [tag, c, char_kind(c), WD.chars[c].desc], C_GOLD if gold else C_TEAL, 4.5)
	tip("word", "字会填进屏幕左下角的句子里，句子决定字弹的效果。按 F（或点左下角的句子）可以查看和调整。")
	calc_loadout()

## 根据句槽里的字，算出字弹的样子和效果
func calc_loadout() -> void:
	var lo := {"shape": "", "shape_lv": 0, "mods": {}, "words": [], "gold": false}
	for s in P.slots:
		if s == null:
			continue
		var lv := 2 if s.gold else 1
		if s.gold:
			lo.gold = true
		var k := char_kind(s.c)
		if k == "形":
			if lo.shape == "":
				lo.shape = s.c
				lo.shape_lv = lv
		elif k != "":
			lo.mods[s.c] = int(lo.mods.get(s.c, 0)) + lv
	for i in P.slots.size() - 1:
		var a = P.slots[i]
		var b = P.slots[i + 1]
		if a == null or b == null:
			continue
		var wd: String = a.c + b.c
		if WD.words.has(wd) and not lo.words.has(wd):
			lo.words.append(wd)
			var known_w: Array = save.words
			if not known_w.has(wd):
				known_w.append(wd)
				persist()
				Sfx.play("page")
				shk = 3
				toast("成词「%s」！%s" % [wd, WD.words[wd]], C_GOLD, 5)
	LO = lo

func mod(c: String) -> int:
	return int(LO.mods.get(c, 0))

func has_word(w: String) -> bool:
	return (LO.words as Array).has(w)

## 一句话描述当前字弹（给句子面板用）
func loadout_lines() -> Array:
	var out := []
	if LO.shape != "":
		out.append("「%s」%s" % [LO.shape, WD.chars[LO.shape].desc])
	for c in LO.mods:
		out.append("「%s」%s%s" % [c, WD.chars[c].desc, "（×%d）" % LO.mods[c] if LO.mods[c] > 1 else ""])
	for w in LO.words:
		out.append("成词「%s」%s" % [w, WD.words[w]])
	var shapes := 0
	for sl in P.slots:
		if sl != null and char_kind(sl.c) == "形":
			shapes += 1
	if shapes > 1:
		out.append("（一句话只有第一个「形」字算数，后面的形字只用来成词）")
	if out.is_empty():
		out.append("句子是空的：普通字弹。")
	return out

## 按句子射出一轮字弹
func fire_sentence() -> float:
	var sp := 265.0
	var life := 0.75
	var dmg := P.dmg
	var cd := 0.2
	var carve_r := 2.3
	var n := 1
	var spread := 0.0
	var big := false
	var orbit := 0.0
	var slv: int = LO.shape_lv
	match LO.shape:
		"针":
			sp *= 1.45 + 0.25 * (slv - 1)
			life = 0.8
		"雨":
			n = 3 if slv == 1 else 5
			spread = 0.2
			cd *= 1.25
		"石":
			sp *= 0.65
			dmg += slv
			carve_r = 4.5
			cd *= 1.4
			big = true
		"环":
			orbit = 0.9 * slv
	if has_word("穿针"):
		sp *= 1.2
	var mat := GOLD
	if mod("火"):
		mat = EMBER
	elif mod("霜"):
		mat = ICE
	elif mod("重"):
		mat = GRAV
	elif mod("静"):
		mat = JELLY
	for k in n:
		var a := (k - (n - 1) / 2.0) * spread
		var dx := P.ax * cos(a) - P.ay * sin(a)
		var dy := P.ax * sin(a) + P.ay * cos(a)
		var b := Bullet.new()
		b.x = P.x + dx * 5
		b.y = P.y + dy * 5
		b.vx = dx * sp + P.vx * 0.3
		b.vy = dy * sp + P.vy * 0.3
		b.sp = sp
		b.life = life + orbit
		b.max_life = life
		b.dmg = dmg
		b.carve_r = carve_r
		b.big = big
		b.mat = mat
		b.orbit = orbit
		b.orb_a = atan2(dy, dx) + k * TAU / n
		b.pierce = 999 if has_word("穿针") else mod("穿")
		b.ret = mod("回") > 0
		b.home = mod("寻") * 5.0
		b.split = mod("裂")
		b.burn = mod("火") * 1.5
		b.frost = mod("霜") * 1.5
		b.grav = mod("重")
		b.calm = mod("静") * 3.0
		for w in LO.words:
			b.w[w] = true
		PB.append(b)
	# 字弹音高跟着句子里的字走：一句话就是一小段旋律
	var chars := []
	for s in P.slots:
		if s != null:
			chars.append(s.c)
	var pitch := 1.0 + randf() * 0.09
	if not chars.is_empty():
		var ks: Array = WD.chars.keys()
		var semi: int = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24, 26][ks.find(chars[P.shot_i % chars.size()]) % 12]
		pitch = pow(2.0, (semi - 7) / 12.0)
	P.shot_i += 1
	Sfx.play("shoot", pitch)
	return cd

func spawn_small(x: float, y: float, a: float, src: Bullet) -> void:
	var b := Bullet.new()
	b.x = x
	b.y = y
	b.vx = cos(a) * 200
	b.vy = sin(a) * 200
	b.life = 0.35
	b.max_life = 0.35
	b.dmg = 1
	b.small = true
	b.mat = src.mat
	b.burn = src.burn
	b.frost = src.frost
	b.hit = src.hit.duplicate()
	PB.append(b)

func upd_tide(dt: float) -> void:
	var ph := fposmod(tide_t, 150.0)
	var dark := tide_t > 0 and ph >= 112
	var warnz := tide_t > 0 and ph >= 100 and ph < 112
	TIDE += ((1.0 if dark else 0.0) - TIDE) * minf(1.0, dt * 0.8)
	SUN = 1.0 - 0.88 * TIDE
	if warnz:
		SUN *= 0.8 + 0.2 * sin(T * 9) * sin(T * 3.3)
	if warnz and not tide_w:
		tide_w = true
		Sfx.play("warn")
		toast("残烛在打寒颤……暗潮快来了。", C_GOLD)
		tip("tide", "暗潮里会冷得更快，蚀字蛾会扑向光。躲回炉灯的暖圈里！")
	if dark and not tide_d:
		tide_d = true
		tides += 1
		toast("暗潮 · 第 %d 次" % tides, C_RED, 3)
	if not dark and tide_d:
		tide_d = false
		tide_w = false
		toast("残烛又亮了。活下来了。", C_GOLD)
		P.ember += 1
		for c in cr:
			if c.t == "moth":
				c.st = "burn"
				c.tm = randf() * 2.5
	if dark:
		tide_sp -= dt
		if tide_sp <= 0:
			tide_sp = maxf(1.3, 2.6 - tides * 0.25)
			if count_type("moth") < 26 + tides * 6:
				var a := randf() * TAU
				var d := 200 + randf() * 40
				var x := P.x + cos(a) * d
				var y := P.y + sin(a) * d
				if Vector2(x, y).length() > kiln_r() + 30:
					var k := 3 + int(randf() * 2 + tides)
					for i in k:
						var c := mk("moth", x + (randf() - 0.5) * 20, y + (randf() - 0.5) * 20)
						c.sp = 58 + randf() * 22 + tides * 4

func upd_player(dt: float) -> void:
	var ix := float(int(key(KEY_D) or key(KEY_RIGHT)) - int(key(KEY_A) or key(KEY_LEFT))) + joy.x
	var iy := float(int(key(KEY_S) or key(KEY_DOWN)) - int(key(KEY_W) or key(KEY_UP))) + joy.y
	var il := sqrt(ix * ix + iy * iy)
	if il > 1.0:
		ix /= il
		iy /= il
		il = 1.0
	P.moving = il > 0.05
	# 瞄准
	var aim := Vector2.ZERO
	if touch_mode:
		if touch_fire:
			aim = Vector2(ox + touch_aim.x, oy + touch_aim.y) - Vector2(P.x, P.y)
		elif il > 0.3:
			aim = Vector2(ix, iy) * 10
	elif not _autoplay:
		aim = get_global_mouse_position() - Vector2(P.x, P.y)
	else:
		aim = _ap_aim
	if aim.length() > 2:
		aim = aim.normalized()
		P.ax = aim.x
		P.ay = aim.y
	const ACC := 235.0
	P.vx += ix * ACC * dt
	P.vy += iy * ACC * dt
	var drag := 0.6 if P.dash_t > 0 else 2.35
	P.vx *= exp(-drag * dt)
	P.vy *= exp(-drag * dt)
	# 引力胎把人往里拽
	for c in cr:
		if c.t == "grav" and not c.dead:
			var gx := c.x - P.x
			var gy := c.y - P.y
			var gd := sqrt(gx * gx + gy * gy)
			if gd < 95 and gd > 1:
				var f := 175 * pow(1 - gd / 95, 1.2)
				P.vx += gx / gd * f * dt
				P.vy += gy / gd * f * dt
	var pd := Vector2(P.x, P.y).length()
	if pd > WR:
		P.vx -= P.x / pd * 260 * dt
		P.vy -= P.y / pd * 260 * dt
		tip("edge", "再往外是彻底的寂静，连光都不肯去。")
	# 冲刺
	P.dash_cd -= dt
	P.dash_t -= dt
	if (pressed(KEY_SPACE) or pressed(KEY_SHIFT) or pressed("dash")) and P.dash_cd <= 0:
		var dx := ix / il if il > 0.05 else P.ax
		var dy := iy / il if il > 0.05 else P.ay
		P.vx = dx * 250
		P.vy = dy * 250
		P.dash_t = 0.22
		P.inv = maxf(P.inv, 0.28)
		P.dash_cd = 0.75 if UP.puff else 1.3
		Sfx.play("dash")
		for i in 10:
			part(P.x - dx * 4, P.y - dy * 4, -dx * 60 + (randf() - 0.5) * 50, -dy * 60 + (randf() - 0.5) * 50, 0.5, CLAY, 5, true)
	# 移动 + 撞石头
	var steps := maxi(1, ceili(Vector2(P.vx, P.vy).length() * dt / 2.0))
	for s in steps:
		P.x += P.vx * dt / steps
		P.y += P.vy * dt / steps
		collide_p()
	if P.moving and randf() < 0.5:
		part(P.x - ix * 5 + (randf() - 0.5) * 3, P.y - iy * 4 + 3, -ix * 25 + (randf() - 0.5) * 10, -iy * 25 + (randf() - 0.5) * 10, 0.35, PAPER, 3)
	P.anim += dt * (10.0 if P.moving else 3.0)
	# 射击
	P.fire_cd -= dt
	var firing := (mouse_down and not fire_locked()) or touch_fire or (_autoplay and _ap_fire)
	if firing and P.fire_cd <= 0 and S == "play":
		P.fire_cd = fire_sentence()
		P.vx -= P.ax * 5
		P.vy -= P.ay * 5
	# 体温
	var wz := warm_zone(P.x, P.y)
	var in_kiln := wz == 2
	if wz:
		P.warm = minf(P.maxwarm, P.warm + (24 if in_kiln else 16) * dt)
	else:
		var drain: float = 0.8 * (1 + pd / 800) * (1 + 1.3 * TIDE) * (1 - 0.2 * UP.glaze) * (1 - P.glaze)
		P.warm = maxf(0.0, P.warm - drain * dt)
	if P.warm <= 0:
		P.cold_t += dt
		if P.cold_t >= 3:
			P.cold_t = 0
			P.hp -= 1
			shk = 3
			Sfx.play("hurt")
			toast("好冷……陶身裂了一道缝。", C_TEAL)
			if P.hp <= 0:
				player_die()
	else:
		P.cold_t = 0
	if P.warm < 25:
		tip("cold", "体温太低了！按 Q（或屏幕上的「烬」）吞一颗余烬，或者回到炉灯边。")
	if in_kiln:
		P.heal_t += dt
		if P.heal_t >= maxf(3, 7 - UP.kiln * 1.5) and P.hp < P.maxhp:
			P.heal_t = 0
			P.hp += 1
			burst(P.x, P.y, 6, GOLD, 5, 30, 0.6)
		tip("kiln", "这里是炉灯。站在暖圈里会回暖、慢慢修补裂缝。按 E 打开工坊。")
	else:
		P.heal_t = 0
	# 余烬
	if pressed(KEY_Q):
		if P.ember > 0:
			P.ember -= 1
			P.warm = minf(P.maxwarm, P.warm + 35)
			Sfx.play("eat")
			burst(P.x, P.y, 14, EMBER, 5, 40, 0.7)
		else:
			toast("没有余烬了。打开冰核贝、敲碎橙色的矿脉都能找到。", C_DIM)
	# 信标
	if pressed(KEY_B):
		if P.beacons > 0:
			if in_kiln:
				toast("炉灯旁边不需要信标。", C_DIM)
			else:
				P.beacons -= 1
				var b := Beacon.new()
				b.x = P.x
				b.y = P.y + 2
				BEA.append(b)
				Sfx.play("beacon")
				toast("信标点亮了：一小圈温暖。", C_GOLD)
		else:
			toast("还没有信标。去炉灯工坊打造（E）。", C_DIM)
	# 炉灯：装订书页 / 工坊
	if in_kiln and not P.carry.is_empty():
		var ids := P.carry.duplicate()
		P.carry.clear()
		for id in ids:
			PAGES[id].state = "bound"
			P.bound += 1
			bind_page(id)
	if S == "play" and pressed(KEY_E):
		if in_kiln:
			S = "menu"
			menu_sel = 0
			Sfx.play("beacon")
		else:
			toast("要在炉灯的暖圈里才能打开工坊。", C_DIM)
	# 拾起失落之页
	for pg in PAGES:
		if pg.state == "free" and Vector2(pg.x - P.x, pg.y - P.y).length() < 11:
			pg.state = "carried"
			P.carry.append(pg.id)
			Sfx.play("page")
			shk = 2
			burst(pg.x, pg.y, 30, ORE, 6, 60, 1)
			toast("拾到失落之页 ·「%s」" % pg.name, C_TEAL, 4)
			toast("带回炉灯装订它。", C_DIM, 4)
	P.inv -= dt
	TRX[tr_i] = P.x
	TRY[tr_i] = P.y
	tr_i = (tr_i + 1) % 400

func bind_page(id: int) -> void:
	Sfx.play("page")
	shk = 5
	burst(0, -4, 60, ORE, 6, 90, 1.6)
	toast("装订：失落之页「%s」" % PAGES[id].name, C_GOLD, 5)
	toast(PAGE_TXT[id], C_TEAL, 6)
	if id == 0:
		P.maxwarm += 30
		P.warm = P.maxwarm
		P.glaze += 0.15
	elif id == 1:
		P.dmg += 1
	if id == 2:
		S = "ending"
		end_t = 0
		save.clears = int(save.clears) + 1
		persist()
	elif P.bound < 3:
		toast("还剩 %d 页。" % (3 - P.bound), C_DIM, 4)
	save_run()

func collide_p() -> void:
	var r := 4.5
	var px := 0.0
	var py := 0.0
	var n := 0
	for k in 12:
		var a := k / 12.0 * TAU
		if rock_at(P.x + cos(a) * r, P.y + sin(a) * r):
			px -= cos(a)
			py -= sin(a)
			n += 1
	if n:
		var l := maxf(0.0001, sqrt(px * px + py * py))
		var nx := px / l
		var ny := py / l
		P.x += nx * 0.9
		P.y += ny * 0.9
		var vn := P.vx * nx + P.vy * ny
		if vn < 0:
			P.vx -= 1.4 * vn * nx
			P.vy -= 1.4 * vn * ny

func hurt_player(n: int, sx: float, sy: float) -> void:
	if P.inv > 0 or S != "play":
		return
	P.hp -= n
	P.inv = 1.1
	shk = maxf(shk, 4)
	Sfx.play("hurt")
	var d := maxf(0.0001, Vector2(P.x - sx, P.y - sy).length())
	P.vx += (P.x - sx) / d * 120
	P.vy += (P.y - sy) / d * 120
	burst(P.x, P.y, 10, CLAY, 4, 60, 0.5, false)
	if P.hp <= 0:
		player_die()

func player_die() -> void:
	S = "dead"
	dead_t = 0
	P.deaths += 1
	Sfx.play("die")
	burst(P.x, P.y, 40, CLAY, 4, 90, 1.2, false)
	var lose := P.dust / 2
	P.dust -= lose
	var cnt := mini(lose, 40)
	for i in cnt:
		add_pick(P.x, P.y, "dust", (randf() - 0.5) * 80, (randf() - 0.5) * 80, maxi(1, roundi(float(lose) / cnt)))
	for id in P.carry:
		PAGES[id].state = "free"
		PAGES[id].x = P.x + (randf() - 0.5) * 20
		PAGES[id].y = P.y + (randf() - 0.5) * 20
	P.carry.clear()
	if serp and serp.st != "sleep" and serp.st != "dead":
		reset_serp()

func reset_serp() -> void:
	serp.st = "sleep"
	serp.hp = DEF.serp.hp
	serp.x = PAGES[2].x
	serp.y = PAGES[2].y
	for i in serp.seg.size():
		serp.seg[i] = Vector2(serp.x, serp.y)
	EB.clear()

func respawn() -> void:
	S = "play"
	P.x = 0
	P.y = 34
	P.vx = 0
	P.vy = 0
	P.hp = P.maxhp
	P.warm = maxf(60, P.warm)
	P.inv = 2
	cam_pos = Vector2(0, 30)
	toast("小克碎成了陶片……又在炉灯里重新烧好了。", C_CLAY)
	if P.deaths == 1:
		toast("掉落的页尘和书页留在了原地，回去捡吧。", C_DIM)

# ---------- 生物 ----------
func upd_creatures(dt: float) -> void:
	for c in cr:
		if c.dead:
			continue
		c.age += dt
		c.flash -= dt
		c.cd -= dt
		var dx := P.x - c.x
		var dy := P.y - c.y
		var d := maxf(0.0001, sqrt(dx * dx + dy * dy))
		if d > 700 and c.t != "moth" and c.t != "serp":
			continue
		# 字句效果：灼烧、减速、安静
		c.slow -= dt
		c.calm -= dt
		if c.t == "serp" and c.st != "fight":
			c.burn = 0
		if c.burn > 0:
			c.burn -= dt
			c.burn_t -= dt
			if c.burn_t <= 0:
				c.burn_t = 0.5
				part(c.x, c.y - 2, (randf() - 0.5) * 10, -15, 0.5, EMBER, 5, true)
				if c.t != "clam" or c.st == "open":
					c.hp -= 1
					c.flash = 0.08
					if c.hp <= 0:
						kill(c, true)
						continue
		var cdt := dt * (0.4 if c.slow > 0 else 1.0)
		match c.t:
			"hush":
				c.vx = cos(c.age * 0.31 + c.ph) * 7 + (c.hx - c.x) * 0.02
				c.vy = sin(c.age * 0.23 + c.ph * 2) * 5 - 2.5 * (0.5 + 0.5 * sin(c.age * 2.2 + c.ph)) + (c.hy - c.y) * 0.02
				c.x += c.vx * cdt
				c.y += c.vy * cdt
				if d < c.r + 5 and c.cd <= 0 and S == "play":
					P.warm = maxf(0.0, P.warm - 14)
					P.vx += dx / d * 70
					P.vy += dy / d * 70
					c.cd = 1.2
					Sfx.play("cold")
					burst(P.x, P.y, 10, JELLY, 5, 30, 0.7)
					tip("hush", "被静默水母碰到了，体温 -14。")
				if d < 60:
					duck = minf(duck, 0.35 + d / 60 * 0.65)
			"folio":
				var tx := c.hx + cos(c.age * 0.21 + c.ph) * 130 + cos(c.off * 2.1) * 12
				var ty := c.hy + sin(c.age * 0.33 + c.ph) * 90 + sin(c.off * 2.1) * 10
				var sp := 95.0 if c.flee > 0 else 30.0
				var ex := tx - c.x
				var ey := ty - c.y
				if c.flee > 0:
					ex = -dx
					ey = -dy
				c.flee -= cdt
				var el := maxf(0.0001, sqrt(ex * ex + ey * ey))
				c.vx += (ex / el * sp - c.vx) * cdt * 1.5
				c.vy += (ey / el * sp - c.vy) * cdt * 1.5
				c.x += c.vx * cdt
				c.y += c.vy * cdt
				c.tm -= cdt
				if c.tm <= 0:
					c.tm = 5 + randf() * 4
					add_pick(c.x, c.y, "dust", -c.vx * 0.3, -c.vy * 0.3)
			"moth":
				if c.st == "burn":
					c.tm -= cdt
					if c.tm <= 0:
						kill(c, true)
					c.x += sin(c.age * 20) * 20 * cdt
				else:
					var tx := P.x if c.calm <= 0 else c.x + cos(c.ph) * 50
					var ty := P.y if c.calm <= 0 else c.y + sin(c.ph) * 50
					var best := 230.0
					for b in BEA:
						var bd := Vector2(b.x - c.x, b.y - c.y).length()
						if bd < best:
							best = bd
							tx = b.x
							ty = b.y
					var ex := tx - c.x
					var ey := ty - c.y
					var el := maxf(0.0001, sqrt(ex * ex + ey * ey))
					var j := sin(c.age * 7 + c.ph) * 0.9
					var ux := (ex * cos(j) - ey * sin(j)) / el
					var uy := (ex * sin(j) + ey * cos(j)) / el
					c.vx += (ux * c.sp - c.vx) * cdt * 2.6
					c.vy += (uy * c.sp - c.vy) * cdt * 2.6
					c.x += c.vx * cdt
					c.y += c.vy * cdt
					if Vector2(c.x, c.y).length() < kiln_r() - 4:
						burst(c.x, c.y, 8, EMBER, 5, 30, 0.5)
						kill(c, false)
					for b in BEA:
						if c.dead:
							break
						if Vector2(b.x - c.x, b.y - c.y).length() < 6:
							b.hp -= cdt * 0.5
							c.vx *= -0.5
							c.vy *= -0.5
							c.sing += cdt
							if c.sing > 1.2:
								burst(c.x, c.y, 6, EMBER, 5, 25, 0.4)
								kill(c, true)
					if c.dead:
						pass
					elif d < c.r + 4 and S == "play" and P.inv <= 0 and c.calm <= 0:
						hurt_player(1, c.x, c.y)
						kill(c, false)
			"leech":
				c.tr.append(c.x)
				c.tr.append(c.y)
				if c.tr.size() > 28:
					c.tr = c.tr.slice(2)
				var alive := c.home != null and rocks.has(c.home)
				var hx := float(c.home.x) if alive else c.hx
				var hy := float(c.home.y) if alive else c.hy
				if c.st == "orbit":
					c.ang += c.w * cdt
					c.x += (hx + cos(c.ang) * c.orR - c.x) * minf(1.0, cdt * 4)
					c.y += (hy + sin(c.ang) * c.orR - c.y) * minf(1.0, cdt * 4)
					if d < 115 and c.cd <= 0 and c.calm <= 0 and S == "play":
						c.st = "wind"
						c.tm = 0.75
						Sfx.play("note", pow(2.0, [0, 3, 5, 7, 10][randi() % 5] / 12.0))
				elif c.st == "wind":
					c.tm -= cdt
					if c.tm <= 0:
						c.st = "lunge"
						c.tm = 0.55
						c.vx = dx / d * 215
						c.vy = dy / d * 215
				elif c.st == "lunge":
					c.tm -= cdt
					c.x += c.vx * cdt
					c.y += c.vy * cdt
					if rock_at(c.x, c.y) and c.tm < 0.45:
						c.tm = 0
						burst(c.x, c.y, 6, ROCK, 4, 30, 0.4, false)
					if c.tm <= 0:
						c.st = "back"
				else:
					var ex := hx + cos(c.ang) * c.orR - c.x
					var ey := hy + sin(c.ang) * c.orR - c.y
					var el := sqrt(ex * ex + ey * ey)
					if el < 4:
						c.st = "orbit"
						c.cd = 1.6
					else:
						c.x += ex / el * 55 * cdt
						c.y += ey / el * 55 * cdt
				if d < c.r + 4:
					hurt_player(1, c.x, c.y)
			"clam":
				if not rock_at(c.x - cos(c.na) * 3.5, c.y - sin(c.na) * 3.5) and not rock_at(c.x - cos(c.na) * 6.0, c.y - sin(c.na) * 6.0):
					burst(c.x, c.y, 10, ICE, 5, 40, 0.6)
					if c.st != "empty":
						add_pick(c.x, c.y, "ember")
					c.dead = true
					continue
				c.tm -= cdt
				if c.st == "grow":
					c.open = maxf(0.0, c.open - cdt * 3)
					if c.tm <= 0:
						c.st = "open"
						c.tm = 2.6
				elif c.st == "open":
					c.open = minf(1.0, c.open + cdt * 3)
					if c.tm <= 0:
						c.st = "grow"
						c.tm = 3.5 + randf() * 2
				elif c.st == "empty":
					c.open = maxf(0.0, c.open - cdt * 2)
					if c.tm <= 0:
						c.st = "grow"
						c.tm = 2
						c.hp = DEF.clam.hp
			"grav":
				c.x += (cos(c.age * 0.2 + c.ph) * 6 + (c.hx - c.x) * 0.03) * cdt
				c.y += (sin(c.age * 0.17 + c.ph) * 6 + (c.hy - c.y) * 0.03) * cdt
				for p in PK:
					var ex := c.x - p.x
					var ey := c.y - p.y
					var el := sqrt(ex * ex + ey * ey)
					if el < 95 and el > 0.5:
						var f := 160 * (1 - el / 95)
						p.vx += ex / el * f * cdt
						p.vy += ey / el * f * cdt
						if el < 5:
							p.k = "eaten"
							if d < 200:
								tip("gravEat", "引力胎把你的页尘吃掉了！")
				if d < c.r + 3:
					hurt_player(1, c.x, c.y)
			"mite":
				var ta := atan2(dy, dx)
				var da := fposmod(ta - c.ang + PI, TAU) - PI
				c.ang += clampf(da, -1.5 * cdt, 1.5 * cdt)
				if d < 230 and c.calm <= 0:
					c.vx += (dx / d * 26 - c.vx) * cdt
					c.vy += (dy / d * 26 - c.vy) * cdt
				else:
					c.vx *= 0.98
					c.vy *= 0.98
				c.x += c.vx * cdt
				c.y += c.vy * cdt
				if rock_at(c.x, c.y):
					c.x -= c.vx * cdt * 2
					c.y -= c.vy * cdt * 2
					c.vx *= -0.5
					c.vy *= -0.5
				if d < c.r + 4:
					hurt_player(1, c.x, c.y)
			"serp":
				upd_serp(c, cdt, d)
		if c.t != "clam" and c.t != "leech" and c.t != "serp" and not c.dead:
			var r := rock_at(c.x, c.y)
			if r:
				var ex := c.x - r.x
				var ey := c.y - r.y
				var el := maxf(0.0001, sqrt(ex * ex + ey * ey))
				c.x += ex / el * 1.5
				c.y += ey / el * 1.5
	cr = cr.filter(func(c): return not c.dead)

func upd_serp(c: Creature, dt: float, d: float) -> void:
	if c.st == "sleep":
		if d < 270 and S == "play":
			c.st = "rise"
			c.tm = 2.2
			Sfx.play("roar")
			shk = 8
			toast("回声蛇醒了。别踩自己走过的路！", C_RED, 4)
			tip("serp", "它会沿着你刚走过的路追来。只有头会受伤。")
		return
	if c.st == "dead":
		return
	if c.st == "rise":
		c.tm -= dt
		shk = maxf(shk, 2)
		if c.tm <= 0:
			c.st = "fight"
		return
	var hpk := c.hp / DEF.serp.hp
	var delay := 84 if hpk > 0.5 else 62
	var k := posmod(tr_i - delay, 400)
	var ex := TRX[k] - c.x
	var ey := TRY[k] - c.y
	var el := maxf(0.0001, sqrt(ex * ex + ey * ey))
	var sp := minf(el * 5, 150.0)
	c.x += ex / el * sp * dt
	c.y += ey / el * sp * dt
	c.ha = atan2(ey, ex)
	var prev := Vector2(c.x, c.y)
	for i in c.seg.size():
		var sv := c.seg[i] - prev
		var sl := maxf(0.0001, sv.length())
		if sl > 5.5:
			c.seg[i] = prev + sv / sl * 5.5
		prev = c.seg[i]
	c.burst_t -= dt
	if c.burst_t <= 0:
		c.burst_t = 4.6 if hpk > 0.5 else 3.3
		var n := 10 if hpk > 0.5 else 12
		var o := randf() * TAU
		for i in n:
			var a := o + float(i) / n * TAU
			add_eb(c.x, c.y, cos(a) * 52, sin(a) * 52, 4.5, SERP)
		if hpk <= 0.5:
			for si in [6, 12]:
				var sg: Vector2 = c.seg[si]
				for i in 6:
					var a := o + i / 6.0 * TAU + 0.5
					add_eb(sg.x, sg.y, cos(a) * 40, sin(a) * 40, 4, ORE)
		Sfx.play("roar")
		c.flash = 0.25
	if d < c.r + 4:
		hurt_player(1 if hpk > 0.5 else 2, c.x, c.y)
	for sg in c.seg:
		if Vector2(P.x - sg.x, P.y - sg.y).length() < 8:
			hurt_player(1, sg.x, sg.y)
	if Vector2(P.x - PAGES[2].x, P.y - PAGES[2].y).length() > 620:
		reset_serp()
		toast("回声蛇退回了茧里。", C_DIM)

func add_eb(x: float, y: float, vx: float, vy: float, life: float, m: int) -> void:
	var b := EBullet.new()
	b.x = x
	b.y = y
	b.vx = vx
	b.vy = vy
	b.life = life
	b.m = m
	EB.append(b)

func hurt_c(c: Creature, dmg: int, bx: float, by: float) -> void:
	if c.t == "clam" and c.st != "open":
		burst(bx, by, 3, ICE, 6, 30, 0.25)
		Sfx.play("ping")
		tip("clam", "冰核贝合着壳时打不动。等它张嘴！")
		return
	c.hp -= dmg
	c.flash = 0.12
	Sfx.play("hit")
	if c.t == "folio":
		for f in cr:
			if f.t == "folio" and f.hx == c.hx:
				f.flee = 3
	if c.t != "clam" and c.t != "serp":
		var dx := c.x - P.x
		var dy := c.y - P.y
		var d := maxf(0.0001, sqrt(dx * dx + dy * dy))
		c.x += dx / d * 2
		c.y += dy / d * 2
	if c.hp <= 0:
		kill(c, true)

func kill(c: Creature, drop: bool) -> void:
	if c.dead or (c.t == "serp" and c.st == "dead") or (c.t == "clam" and c.st == "empty"):
		return
	var D: Dictionary = DEF[c.t]
	if c.t == "clam":
		c.st = "empty"
		c.tm = 45
		for i in int(D.ember):
			add_pick(c.x, c.y, "ember", cos(c.na) * 40, sin(c.na) * 40)
		for i in D.dust:
			add_pick(c.x, c.y, "dust", cos(c.na) * 30, sin(c.na) * 30)
		Sfx.play("ember")
		burst(c.x, c.y, 12, EMBER, 6, 40, 0.6)
		if randf() < float(WD.drop.get("clam", 0.0)):
			var keys: Array = WD.chars.keys()
			var p := Pick.new()
			p.x = c.x
			p.y = c.y
			p.vx = cos(c.na) * 30
			p.vy = sin(c.na) * 30
			p.k = "word"
			p.wc = keys[randi() % keys.size()]
			p.gold = randf() < float(WD.gold_chance)
			PK.append(p)
		return
	c.dead = c.t != "serp"
	if drop and randf() < float(WD.drop.get(c.t, 0.0)):
		var keys: Array = WD.chars.keys()
		var p := Pick.new()
		p.x = c.x
		p.y = c.y
		p.vx = (randf() - 0.5) * 30
		p.vy = (randf() - 0.5) * 30
		p.k = "word"
		p.wc = keys[randi() % keys.size()]
		p.gold = c.t == "serp" or randf() < float(WD.gold_chance)
		PK.append(p)
	if drop:
		P.kills += 1
		Sfx.play("kill")
		for i in D.dust:
			add_pick(c.x, c.y, "dust", (randf() - 0.5) * 50, (randf() - 0.5) * 50)
		var em: float = D.ember
		if em >= 1.0 or (em > 0.0 and randf() < fmod(em, 1.0)):
			for i in maxi(1, floori(em)):
				add_pick(c.x, c.y, "ember", (randf() - 0.5) * 40, (randf() - 0.5) * 40)
	var m: int = {"hush": JELLY, "folio": PAPER, "moth": MOTH, "leech": LEECH, "mite": MIRROR, "grav": GRAV, "serp": SERP}[c.t]
	var big := c.t == "serp"
	burst(c.x, c.y, 80 if big else 14, m, 5, 110 if big else 45, 1.6 if big else 0.6)
	if c.t == "folio" and drop:
		toast("一本书鳐散成了纸片……", C_DIM)
	if c.t == "grav":
		burst(c.x, c.y, 30, GOLD, 6, 80, 0.8)
		shk = 4
	if big:
		c.st = "dead"
		shk = 12
		PAGES[2].state = "free"
		toast("回声蛇散成了一千句回声。", C_GOLD, 5)
		toast("第三页「论回声」从茧里漂了出来。", C_TEAL, 5)
		for sg in c.seg:
			burst(sg.x, sg.y, 8, SERP, 5, 50, 1)
		EB.clear()

# ---------- 子弹 / 挖矿 ----------
func carve(r: Rock, x: float, y: float, rad: float) -> int:
	if r.spr == null:
		return 0   # 这块石头刚刚已经被打碎了
	var ci := floori(x) - r.x0
	var cj := floori(y) - r.y0
	var R := ceili(rad)
	var got := 0
	for j in range(cj - R, cj + R + 1):
		for i in range(ci - R, ci + R + 1):
			if i < 1 or j < 1 or i >= r.S - 1 or j >= r.S - 1:
				continue
			var k := j * r.S + i
			var v := r.m[k]
			if v == 0:
				continue
			if (i - ci) * (i - ci) + (j - cj) * (j - cj) > rad * rad:
				continue
			r.m[k] = 0
			r.cnt -= 1
			got += 1
			var wx := r.x0 + i + 0.5
			var wy := r.y0 + j + 0.5
			var ang := atan2(wy - r.y, wx - r.x)
			var ca := cos(ang)
			var sa := sin(ang)
			if v == 2 and randf() < 0.6:
				add_pick(wx, wy, "dust", ca * 20, sa * 20)
			elif v == 3 and randf() < 0.11:
				add_pick(wx, wy, "ember", ca * 16, sa * 16)
			elif v == 1 and randf() < 0.025:
				add_pick(wx, wy, "dust", ca * 15, sa * 15)
			if randf() < 0.5:
				var m := ORE if v == 2 else (EMBER if v == 3 else r.tint)
				part(wx, wy, (randf() - 0.5) * 40 + ca * 20, (randf() - 0.5) * 40 + sa * 20, 0.5, m, 5 if v > 1 else 3, v > 1)
	if got:
		if r.cnt < 10:
			rocks.erase(r)
			grid_del(r)
			dirty.erase(r)
			r.spr.queue_free()
			r.spr = null
			for k in r.S * r.S:
				if r.m[k] and randf() < 0.5:
					part(r.x0 + k % r.S, r.y0 + k / r.S, (randf() - 0.5) * 30, (randf() - 0.5) * 30, 0.8, r.tint, 3)
		else:
			dirty[r] = true
	return got

func upd_bullets(dt: float) -> void:
	for b in PB:
		b.life -= dt
		# 环：先绕着小克转
		if b.orbit > 0:
			b.orbit -= dt
			b.orb_a += 7.0 * dt
			b.x = P.x + cos(b.orb_a) * 14
			b.y = P.y + sin(b.orb_a) * 14
			if b.orbit <= 0:
				b.vx = P.ax * b.sp
				b.vy = P.ay * b.sp
				b.life = b.max_life
		else:
			for c in cr:
				if c.t == "grav" and not c.dead:
					var ex := c.x - b.x
					var ey := c.y - b.y
					var el := sqrt(ex * ex + ey * ey)
					if el < 95 and el > 1:
						var f := 2400 * pow(1 - el / 95, 2)
						b.vx += ex / el * f * dt
						b.vy += ey / el * f * dt
			# 寻：拐向附近的敌人
			if b.home > 0 and not b.returning:
				var best: Creature = null
				var bd := 110.0
				for c in cr:
					if c.dead or b.hit.has(c) or (c.t == "serp" and c.st != "fight"):
						continue
					var cd := Vector2(c.x - b.x, c.y - b.y).length()
					if cd < bd:
						bd = cd
						best = c
				if best:
					var v := Vector2(b.vx, b.vy)
					var want := Vector2(best.x - b.x, best.y - b.y).angle()
					var turn := clampf(angle_difference(v.angle(), want), -b.home * dt, b.home * dt)
					v = v.rotated(turn)
					b.vx = v.x
					b.vy = v.y
			# 回：飞到一半折返
			if b.ret and not b.returning and b.life < b.max_life * 0.45:
				b.returning = true
				b.hit.clear()
			if b.returning:
				var to := Vector2(P.x - b.x, P.y - b.y)
				var v := to.normalized() * b.sp * 0.9
				b.vx = v.x
				b.vy = v.y
				b.life = maxf(b.life, 0.1)
				if to.length() < 7:
					if b.w.has("回环") and not b.w.has("_looped"):
						b.w["_looped"] = true
						b.returning = false
						b.ret = false
						b.orbit = 0.9
						b.orb_a = (-to).angle()
						b.life = b.max_life + 0.9
					else:
						b.life = -1
				if b.w.has("重回"):
					for p in PK:
						if Vector2(p.x - b.x, p.y - b.y).length() < 30 and p.k != "eaten":
							p.vx = (P.x - p.x) * 6
							p.vy = (P.y - p.y) * 6
			# 重：吸引页尘
			if b.grav > 0:
				var rr := 22.0 + 10.0 * b.grav
				for p in PK:
					var ex := b.x - p.x
					var ey := b.y - p.y
					var el := sqrt(ex * ex + ey * ey)
					if el < rr and el > 1 and p.k != "eaten":
						p.vx += ex / el * 400 * dt
						p.vy += ey / el * 400 * dt
		for s in 2:
			if b.life <= 0:
				break
			if b.orbit <= 0:
				b.x += b.vx * dt / 2
				b.y += b.vy * dt / 2
			var r := rock_at(b.x, b.y)
			if r:
				carve(r, b.x, b.y, b.carve_r)
				if b.w.has("火石"):
					var r2 := rock_at(b.x, b.y)
					carve(r if r2 == null else r2, b.x, b.y, 6.0)
					burst(b.x, b.y, 14, EMBER, 6, 60, 0.5)
					shk = maxf(shk, 2)
				if (b.w.has("裂石") or b.split > 0) and not b.small:
					var back := atan2(-b.vy, -b.vx)
					for i in 3:
						spawn_small(b.x - b.vx * 0.02, b.y - b.vy * 0.02, back + (i - 1) * 0.7, b)
				b.life = 0
				Sfx.play("rock")
				break
			for c in cr:
				if c.dead or b.hit.has(c):
					continue
				if c.t == "serp":
					if c.st == "sleep" or c.st == "dead":
						if c.st == "sleep" and Vector2(b.x - c.x, b.y - c.y).length() < 14:
							b.life = 0
							burst(b.x, b.y, 3, SERP, 5, 20, 0.3)
						continue
					if Vector2(b.x - c.x, b.y - c.y).length() < c.r + 1:
						bullet_hit(b, c)
						if b.life <= 0:
							break
						continue
					var blk := false
					for sg in c.seg:
						if Vector2(b.x - sg.x, b.y - sg.y).length() < 5:
							blk = true
							break
					if blk:
						b.life = 0
						burst(b.x, b.y, 3, ORE, 5, 25, 0.3)
						Sfx.play("ping")
						break
					continue
				if Vector2(b.x - c.x, b.y - c.y).length() < c.r + (2.5 if b.big else 1.5):
					if c.t == "mite":
						var hx := b.x - c.x
						var hy := b.y - c.y
						var hl := maxf(0.0001, sqrt(hx * hx + hy * hy))
						if (cos(c.ang) * hx + sin(c.ang) * hy) / hl > 0.2:
							var spd := Vector2(b.vx, b.vy).length() * 0.45
							var dv := Vector2(P.x - c.x, P.y - c.y).normalized().rotated((randf() - 0.5) * 0.5) * spd
							add_eb(b.x, b.y, dv.x, dv.y, 2.5, CLAY)
							b.life = 0
							Sfx.play("ping")
							burst(b.x, b.y, 4, MIRROR, 6, 30, 0.3)
							tip("mite", "镜螨把字弹弹回来了！绕到它背后打粉色的软肉。")
							break
					bullet_hit(b, c)
					if b.life <= 0:
						break
		if b.life <= 0 and not b.returning:
			burst(b.x, b.y, 2, b.mat, 5, 20, 0.2)
	PB = PB.filter(func(b): return b.life > 0)
	for b in EB:
		b.life -= dt
		b.x += b.vx * dt
		b.y += b.vy * dt
		if rock_at(b.x, b.y):
			b.life = 0
		if Vector2(b.x - P.x, b.y - P.y).length() < 4.5 and P.inv <= 0 and S == "play":
			hurt_player(1, b.x, b.y)
			b.life = 0
	EB = EB.filter(func(b): return b.life > 0)

## 字弹命中生物：伤害 + 句子里的效果
func bullet_hit(b: Bullet, c: Creature) -> void:
	if c.t == "clam" and c.st == "grow" and b.burn > 0:
		c.st = "open"
		c.tm = 1.5
		c.open = 1.0
		tip("fireclam", "「火」把冰核贝烫开了！")
	hurt_c(c, b.dmg, b.x, b.y)
	if b.burn > 0:
		c.burn = maxf(c.burn, b.burn)
	if b.frost > 0:
		c.slow = maxf(c.slow, b.frost)
		burst(c.x, c.y, 4, ICE, 6, 20, 0.4)
	if b.calm > 0:
		c.calm = maxf(c.calm, b.calm)
		if c.t == "leech" and c.st != "orbit":
			c.st = "back"
	b.hit.append(c)
	if b.split > 0 and not b.small:
		var a := atan2(b.vy, b.vx)
		for i in 3 * b.split:
			spawn_small(b.x, b.y, a + (i - (3 * b.split - 1) / 2.0) * 0.5, b)
	if b.pierce > 0:
		b.pierce -= 1
	else:
		b.life = 0

func upd_beacons(dt: float) -> void:
	for b in BEA:
		b.age += dt
		if b.hp <= 0:
			burst(b.x, b.y, 20, GOLD, 5, 40, 0.8)
			toast("一座信标被蚀字蛾啃灭了。", C_RED)
	BEA = BEA.filter(func(b): return b.hp > 0)

func upd_pickups(dt: float) -> void:
	var mag := 40.0 + (15.0 if P.bound >= 1 else 0.0)
	var keep: Array[Pick] = []
	for p in PK:
		if p.k == "eaten":
			continue
		p.age += dt
		p.vx *= exp(-2 * dt)
		p.vy *= exp(-2 * dt)
		var dx := P.x - p.x
		var dy := P.y - p.y
		var d := maxf(0.0001, sqrt(dx * dx + dy * dy))
		if d < mag and p.age > 0.35 and S == "play":
			var f := (1 - d / mag) * 520 + 60
			p.vx += dx / d * f * dt
			p.vy += dy / d * f * dt
		p.x += p.vx * dt
		p.y += p.vy * dt
		if d < 6 and p.age > 0.3 and S == "play":
			if p.k == "word":
				give_word(p.wc, p.gold)
			elif p.k == "dust":
				P.dust += p.v
				P.dust_total += p.v
				if T - chime_t > 0.9:
					chime_i = 0
				chime_t = T
				Sfx.play("dust%d" % mini(7, chime_i))
				chime_i += 1
			else:
				P.ember += p.v
				Sfx.play("ember")
				tip("ember", "拾到余烬：体温低时按 Q 吞下它。")
			continue
		if p.age < 90 or p.k == "word":
			keep.append(p)
	PK = keep

func upd_spawns(dt: float) -> void:
	spawn_t -= dt
	if spawn_t > 0:
		return
	spawn_t = 4
	for t in TARGET:
		if count_type(t) < TARGET[t]:
			spawn(t)

func upd_particles(dt: float) -> void:
	var keep: Array[Part] = []
	for p in PT:
		p.life -= dt
		if p.life <= 0:
			continue
		p.vx *= exp(-1.8 * dt)
		p.vy *= exp(-1.8 * dt)
		p.x += p.vx * dt
		p.y += p.vy * dt
		keep.append(p)
	PT = keep

func check_discover() -> void:
	for c in cr:
		if seen.has(c.t) or c.dead:
			continue
		if Vector2(c.x - P.x, c.y - P.y).length() < 130:
			if c.t == "serp" and c.st == "sleep":
				continue
			seen[c.t] = true
			toast("新生物 ·「%s」  (Tab 图鉴)" % DEF[c.t].name, C_GOLD, 4)
			Sfx.play("note")
			persist()

# 画面
func build_lights() -> void:
	lights.clear()
	var f := 0.92 + 0.08 * sin(T * 11) * sin(T * 4.3)
	lights.append(Vector4(0, -2, kiln_r() * 1.8, 1.25 * f))
	for b in BEA:
		lights.append(Vector4(b.x, b.y - 5, 90, 0.9 * f * ((0.5 + 0.5 * sin(T * 20)) if b.hp < 3 else 1.0)))
	if S != "title" and S != "intro":
		lights.append(Vector4(P.x, P.y, 62, 0.75))
	for pg in PAGES:
		if pg.state == "free":
			lights.append(Vector4(pg.x, pg.y, 55, 0.8))
	var n := 0
	for b in PB:
		n += 1
		if n > 10:
			break
		lights.append(Vector4(b.x, b.y, 22, 0.5))
	for c in cr:
		if lights.size() >= 24:
			break
		if c.t == "hush" and absf(c.x - cam_pos.x) < 220 and absf(c.y - cam_pos.y) < 150:
			lights.append(Vector4(c.x, c.y, 34, 0.35))
		if c.t == "serp" and c.st != "dead":
			lights.append(Vector4(c.x, c.y, 60, 0.5 if c.st == "sleep" else 0.7))
	if lights.size() > 24:
		lights.resize(24)

func light_at(x: float, y: float) -> float:
	var L := AMB + SUN * 0.55
	for l in lights:
		var dx := l.x - x
		var dy := l.y - y
		var d2 := dx * dx + dy * dy
		if d2 < l.z * l.z:
			var k := 1.0 - sqrt(d2) / l.z
			L += l.w * k * k
	return L

# 自动试玩（仅用于测试：godot -- --autoplay）
var _ap_aim := Vector2.RIGHT
var _ap_fire := false
