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

const ZNAME := {
	"shallow": "浅页带", "leech": "蛭环", "nursery": "坍缩苗圃", "echo": "回声深处", "drift": "冷寂漂流区",
	"hall": "前厅", "stacks": "书架迷宫", "dark": "熄灯区", "ink": "墨海",
}
## m = 打散时迸出的碎屑颜色；as = 在图鉴里算作哪一种
const DEF := {
	"hush": {"name": "静默水母", "hp": 3, "r": 6, "dust": 3, "ember": 0.0, "m": JELLY},
	"folio": {"name": "书鳐", "hp": 8, "r": 7, "dust": 10, "ember": 0.0, "m": PAPER},
	"clam": {"name": "冰核贝", "hp": 2, "r": 5, "dust": 2, "ember": 3.0, "m": ICE},
	"moth": {"name": "蚀字蛾", "hp": 1, "r": 3, "dust": 1, "ember": 0.0, "m": MOTH},
	"leech": {"name": "轨道蛭", "hp": 4, "r": 5, "dust": 5, "ember": 0.3, "m": LEECH},
	"mite": {"name": "镜螨", "hp": 4, "r": 5, "dust": 8, "ember": 0.0, "m": MIRROR},
	"grav": {"name": "引力胎", "hp": 10, "r": 6, "dust": 16, "ember": 0.0, "m": GRAV},
	"comma": {"name": "逗号蜂", "hp": 3, "r": 4, "dust": 5, "ember": 0.15, "m": GOLD},
	"serp": {"name": "回声蛇", "hp": 48, "r": 8, "dust": 40, "ember": 4.0, "m": SERP},
	"blot": {"name": "墨团", "hp": 6, "r": 7, "dust": 6, "ember": 0.0, "m": GRAV},
	"blotlet": {"name": "小墨团", "hp": 2, "r": 4, "dust": 2, "ember": 0.0, "m": GRAV, "as": "blot"},
	"worm": {"name": "书虫", "hp": 7, "r": 5, "dust": 9, "ember": 0.0, "m": PAPER},
	"wisp": {"name": "灯魇", "hp": 5, "r": 5, "dust": 7, "ember": 1.0, "m": JELLY},
	"redact": {"name": "删节者", "hp": 90, "r": 11, "dust": 60, "ember": 5.0, "m": RUIN},
}

const LORE := {
	"hush": ["浮游 · 无害但冰冷", "以声音为食的透明钟形生物。它们漂过的地方，连星星的嗡鸣都会停下来。碰到它会冷到陶心，体温骤降。"],
	"folio": ["迁徙 · 温顺", "大散页之后，有些书没有死。它们学会了扇动封皮，在星海里成群迁徙，边飞边抖落不想要的段落——那就是页尘。"],
	"clam": ["固着 · 可采集", "冰壳里裹着一粒火。没人知道它们从哪儿学会了保存温暖，只知道它们每隔一会儿要张嘴喘口气——那时射中火珠，就能取到余烬。"],
	"moth": ["群居 · 暗潮时出没", "啃食一切写着字的东西。暗潮来临时成群出现，扑向光——也扑向你，因为你身上全是字。炉火太烫，它们不敢靠近。"],
	"leech": ["伏击 · 绕石而居", "一生绕着一颗石头转，像在念一句咒语。看到路过的小陶灵会停下、发红、然后直线扑来。躲开那一下就好。"],
	"mite": ["反射 · 只能打背面", "背着一面磨得发亮的壳，会把你说过的话原样还给你——正面射它，字弹会被弹回来。它转身很慢，绕到背后打那块粉色软肉。"],
	"grav": ["幼体黑洞 · 贪吃", "还没长大的黑洞幼体，正处在什么都想往嘴里塞的年纪。会把你、你的字弹、地上的页尘一起往里拽。"],
	"comma": ["远程 · 保持距离", "一句话说到一半停下来喘气的地方，长出了翅膀。它不靠近你，只在远处绕着飞，隔一会儿朝你甩一个绿色的墨点。它发红的那一下就是要甩了。"],
	"serp": ["守页者 · 第一章首领", "吞下所有在虚空里说出口的话，然后一遍遍复述。它走的路，永远是你刚刚走过的路——别回头踩自己的脚印。只有头会受伤。快不行的时候，它会停下来瞄准，然后直直撞过来。"],
	"blot": ["分裂 · 墨海里滋生", "打翻的墨水学会了自己爬。一跳一跳地扑过来，打散以后会裂成两团小的——小的跳得更快。"],
	"worm": ["钻洞 · 啃书架", "把书从第一页啃到最后一页，再把书架也啃了。石头和书架挡不住它，它会直接钻过来。它啃出来的洞里常常掉出页尘。"],
	"wisp": ["潜行 · 只在光里显形", "熄了的灯里住着的东西。在暗处你只看得见一双眼睛，字弹会直接穿过去；把它引到亮处——路灯、信标、炉灯——它才有身体可以打。"],
	"redact": ["删节者 · 第二章首领", "图书馆里最后一位审稿人，早就忘了自己在审什么，只记得要划掉。它画的线要过一会儿才落下：看见细线就赶紧让开。"],
}

## 五种笔：同一句话，换一支笔就是另一种打法
const PENS := [
	{"name": "毛笔", "desc": "一发一发的字弹，句子里的字全都生效"},
	{"name": "排刷", "desc": "一次刷出一片短射程的字弹，贴脸最疼"},
	{"name": "刻刀", "desc": "身前挥一刀：伤害高，能劈开敌人的子弹，镜螨要绕后"},
	{"name": "砚雷", "desc": "朝准星扔一团墨，炸开一片，连镜螨的正面也炸得到"},
	{"name": "墨线", "desc": "按住蓄力，松开射出一道穿透一切的墨线"},
]
const ORDER := ["hush", "folio", "clam", "moth", "leech", "mite", "grav", "comma", "serp", "blot", "worm", "wisp", "redact"]
const PAGE_TXT := [
	"「寒冷不是热的缺席，而是一切停止说话的声音。」——体温上限 +30，保温 +15%",
	"「万物彼此吸引，因为它们都想被读到。」——字弹伤害 +1",
	"「宇宙说出的第一个字还在回响，它叫『在』。」",
	"「沉默不是空的，它只是把话都收好了。」——生命上限 +1，并补满",
	"「被忘掉的字并没有消失，它们只是在等人再念一遍。」——所有的笔出手快 15%",
	"「留白是写给后来人的。」",
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
	var mark := 0.0

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
	var bounce := 0
	var chain := 0
	var mark := 0.0
	var crit := 0.0

class Bomb:
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var dist := 0.0
	var age := 0.0

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
	var pen := 0               # 当前拿着的笔
	var pens := 1              # 已经有几支笔
	var charge := 0.0          # 墨线蓄力 0~1
	var aim_d := 60.0          # 准星离小克多远（砚雷用）
	var haste := 1.0           # 出手间隔的倍数（越小越快）

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
var UP := {"kiln": 0, "bolt": 0, "shell": 0, "glaze": 0, "puff": 0, "pen": 0}
var BM: Array[Bomb] = []
var FX: Array = []           # 刀光 / 墨线 / 爆炸圈 这些一闪而过的效果
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
	{"k": "pen", "name": "笔架", "desc": "多一支笔：排刷、刻刀、砚雷、墨线（数字键或 R 换笔）", "cost": [40, 70, 110, 150], "max": 4},
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
	if chapter == 2:
		if d < 420.0:
			return "hall"
		if absf(a) < 1.05:
			return "stacks"
		if a < -1.05 and a > -2.2:
			return "ink"
		return "dark"
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
	for gy in range(floori(float(r.y - r.ch) / GC), floori(float(r.y + r.ch) / GC) + 1):
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
	if chapter == 2:
		_gen_stacks()
	var cap := 200 if chapter == 1 else rocks.size() + 105
	var t := 0
	while t < 5000 and rocks.size() < cap:
		t += 1
		var a := R0.randf() * TAU
		var d := sqrt(R0.randf()) * WR
		var x := cos(a) * d
		var y := sin(a) * d
		var z := zn(x, y)
		if z == "stacks":
			continue
		if (z == "echo" and R0.randf() < 0.45) or (z == "ink" and R0.randf() < 0.5):
			continue
		var R := 0.0
		match z:
			"nursery": R = 6 + R0.randf() * 14
			"shallow": R = 8 + R0.randf() * 18
			"leech": R = 11 + R0.randf() * 24
			"echo": R = 9 + R0.randf() * 18
			"hall": R = 7 + R0.randf() * 13
			"dark": R = 10 + R0.randf() * 24
			"ink": R = 8 + R0.randf() * 14
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
	# 首领周围一圈石头
	for k in 9:
		var a := k / 9.0 * TAU + 0.3
		var x: float = PAGES[2].x + cos(a) * 120
		var y: float = PAGES[2].y + sin(a) * 120
		if Vector2(x, y).length() < WR - 20:
			rocks.append(Rock.build(roundi(x), roundi(y), 7 + (k % 3) * 3, "echo" if chapter == 1 else "ink", R0))
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
		if d < 150 or Vector2(x - P.x, y - P.y).length() < 230:
			continue
		if t != "worm" and rock_at(x, y):
			continue
		var z := zn(x, y)
		if chapter == 1:
			if t == "hush" and d < 170:
				continue
			if t == "folio" and (d < 200 or d > 950):
				continue
			if t == "grav" and z != "nursery":
				continue
			if t == "mite" and not (z == "echo" or (z == "leech" and d > 650) or (z == "drift" and d > 700)):
				continue
			if t == "comma" and not (z == "drift" or (z == "leech" and d > 600)):
				continue
		else:
			if t == "blot" and z != "ink" and not (z == "stacks" and randf() < 0.12):
				continue
			if t == "worm" and z != "stacks" and not (z == "hall" and d > 260):
				continue
			if t == "wisp" and z != "dark":
				continue
			if t == "comma" and (z == "ink" or d < 250):
				continue
			if t == "hush" and (z == "stacks" or d < 170):
				continue
			if t == "mite" and not ((z == "stacks" and d > 600) or (z == "dark" and d > 700)):
				continue
			if t == "folio" and (d < 200 or d > 950):
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
	init_c(mk(t, p.x, p.y))

func gen_clams() -> void:
	var n := 0
	var cand: Array[Rock] = []
	for r in rocks:
		if r.R >= 11 and not r.box and r.zone != "nursery" and r.zone != "echo" and r.zone != "ink":
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
	R0.seed = 20261108 + (chapter - 1) * 977
	if chapter == 1:
		PAGES = [
			{"id": 0, "gid": 0, "x": cos(0.12) * 1080, "y": sin(0.12) * 1080, "name": "论寒冷", "state": "free"},
			{"id": 1, "gid": 1, "x": cos(2.25) * 1050, "y": sin(2.25) * 1050, "name": "论引力", "state": "free"},
			{"id": 2, "gid": 2, "x": 0.0, "y": -1110.0, "name": "论回声", "state": "sealed"},
		]
	else:
		PAGES = [
			{"id": 0, "gid": 3, "x": cos(0.1) * 1080, "y": sin(0.1) * 1080, "name": "论沉默", "state": "free"},
			{"id": 1, "gid": 4, "x": cos(2.4) * 1050, "y": sin(2.4) * 1050, "name": "论遗忘", "state": "free"},
			{"id": 2, "gid": 5, "x": 0.0, "y": -1110.0, "name": "论空白", "state": "sealed"},
		]
	gen_rocks()
	cr.clear()
	PB.clear()
	EB.clear()
	PK.clear()
	BEA.clear()
	BM.clear()
	FX.clear()
	HZ.clear()
	LAMPS.clear()
	INK.clear()
	spawn_q.clear()
	serp = null
	redact = null
	gen_clams()
	if chapter == 2:
		gen_ch2()
	for t in targets():
		var g := 0
		while count_type(t) < targets()[t] and g < 60:
			g += 1
			spawn(t)
	if chapter == 1:
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
	else:
		# 第一页：书架深处一窝书虫；第二页：三只灯魇守着三盏熄掉的灯
		for i in 3:
			init_c(mk("worm", PAGES[0].x + cos(i * 2.1) * 40, PAGES[0].y + sin(i * 2.1) * 40))
		for i in 3:
			mk("wisp", PAGES[1].x + cos(i * 2.1 + 1) * 80, PAGES[1].y + sin(i * 2.1 + 1) * 80)
		redact = mk("redact", PAGES[2].x, PAGES[2].y)
		redact.st = "sleep"
	apply_pages()
	zone_name = ""
	if bg_mat:
		bg_mat.set_shader_parameter("chap", float(chapter))

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
	for l in LAMPS:
		if l.lit > 0 and Vector2(x - l.x, y - l.y).length() < 40:
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
	stash_pages()
	var bea := []
	for b in BEA:
		bea.append([b.x, b.y, b.hp])
	save["run"] = {
		"dust": P.dust, "ember": P.ember, "beacons": P.beacons, "hp": P.hp, "maxhp": P.maxhp,
		"warm": P.warm, "maxwarm": P.maxwarm, "glaze": P.glaze, "dmg": P.dmg, "deaths": P.deaths,
		"dust_total": P.dust_total, "kills": P.kills, "slots": P.slots, "bag": P.bag, "up": UP,
		"pstore": page_store, "bea": bea, "gt": gt, "tides": tides, "seen": seen.keys(), "tips": tips.keys(),
		"free": free_mode, "pen": P.pen, "ch": chapter, "unlocked": unlocked, "haste": P.haste,
	}
	persist()

func _word_ok(w) -> bool:
	return w is Dictionary and w.has("c") and WD.chars.has(w.c)

func load_run() -> void:
	var r: Dictionary = save.run
	P.dust = int(r.get("dust", 0))
	P.ember = int(r.get("ember", 1))
	P.beacons = int(r.get("beacons", 0))
	P.maxhp = clampi(int(r.get("maxhp", 5)), 5, 8)
	P.hp = clampi(int(r.get("hp", 5)), 1, P.maxhp)
	P.maxwarm = float(r.get("maxwarm", 100.0))
	P.warm = clampf(float(r.get("warm", 100.0)), 40.0, P.maxwarm)
	P.glaze = float(r.get("glaze", 0.0))
	P.dmg = int(r.get("dmg", 1))
	P.haste = clampf(float(r.get("haste", 1.0)), 0.5, 1.0)
	P.deaths = int(r.get("deaths", 0))
	P.dust_total = int(r.get("dust_total", 0))
	P.kills = int(r.get("kills", 0))
	var up: Dictionary = r.get("up", {})
	for k in UP:
		UP[k] = int(up.get(k, 0))
	P.pens = 1 + UP.pen
	P.pen = clampi(int(r.get("pen", 0)), 0, P.pens - 1)
	P.slots.clear()
	for w in r.get("slots", []):
		P.slots.append({"c": w.c, "gold": bool(w.get("gold", false))} if _word_ok(w) else null)
	while P.slots.size() < int(WD.start_slots) + UP.bolt:
		P.slots.append(null)
	P.bag.clear()
	for w in r.get("bag", []):
		if _word_ok(w):
			P.bag.append({"c": w.c, "gold": bool(w.get("gold", false))})
	# 书页：新存档按章节记；旧存档只有第一章的三张
	page_store = {}
	var ps = r.get("pstore")
	if ps is Dictionary:
		for k in ps:
			if ps[k] is Array:
				page_store[str(k)] = ps[k]
	elif r.get("pages") is Array:
		page_store["1"] = r.pages
	unlocked = clampi(int(r.get("unlocked", 1)), 1, 2)
	var b1 := 0
	for q in page_store.get("1", []):
		if str(q.get("state", "")) == "bound":
			b1 += 1
	if b1 >= 3:
		unlocked = 2
	var ch := clampi(int(r.get("ch", 1)), 1, unlocked)
	if ch != chapter:
		chapter = ch
		new_world()
	else:
		apply_pages()
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
		"pen":
			UP.pen += 1
			P.pens = 1 + UP.pen
			P.pen = P.pens - 1
			toast("新笔「%s」：%s" % [PENS[P.pen].name, PENS[P.pen].desc], C_TEAL, 6)
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
	if has_word("暴雨") and LO.shape == "雨":
		n += 2
	if P.pen == 1:
		n += 4
		spread = 0.13 if spread == 0.0 else spread * 0.8
		life *= 0.42
		cd *= 2.1
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
		b.bounce = mod("弹") * 2
		b.chain = (mod("连") + 2) if has_word("连环") else mod("连")
		b.mark = mod("蚀") * 4.0
		b.crit = 0.2 * mod("暴")
		if P.pen == 1:
			var k2 := 0.8 + randf() * 0.4
			b.vx *= k2
			b.vy *= k2
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

func set_pen(i: int) -> void:
	if i == P.pen or i < 0 or i >= P.pens:
		return
	P.pen = i
	P.charge = 0.0
	Sfx.play("ping", 0.7 + i * 0.12)
	toast("换笔：%s" % PENS[i].name, C_TEAL, 1.6)

## 这个生物现在能不能被打到
func can_hit(c: Creature) -> bool:
	if c.dead:
		return false
	if c.t == "serp" or c.t == "redact":
		return c.st == "fight"
	if c.t == "wisp":
		return c.open > 0.5
	return true

## 镜螨的正面会挡住从 (x, y) 方向来的攻击
func mite_blocks(c: Creature, x: float, y: float) -> bool:
	if c.t != "mite":
		return false
	var hx := x - c.x
	var hy := y - c.y
	var hl := maxf(0.0001, sqrt(hx * hx + hy * hy))
	return (cos(c.ang) * hx + sin(c.ang) * hy) / hl > 0.2

## 刻刀 / 砚雷 / 墨线命中：伤害 + 句子里“性”字的效果
func fx_hit(c: Creature, dmg: int, x: float, y: float) -> void:
	if c.t == "clam" and c.st == "grow" and mod("火") > 0:
		c.st = "open"
		c.tm = 1.5
		c.open = 1.0
	if randf() < 0.2 * mod("暴"):
		dmg *= 3
		burst(c.x, c.y, 8, GOLD, 6, 50, 0.4)
	if c.mark > 0:
		dmg += 1
	hurt_c(c, dmg, x, y)
	if mod("火") > 0:
		c.burn = maxf(c.burn, mod("火") * 1.5)
	if mod("霜") > 0:
		c.slow = maxf(c.slow, mod("霜") * 1.5)
		burst(c.x, c.y, 4, ICE, 6, 20, 0.4)
	if mod("静") > 0:
		c.calm = maxf(c.calm, mod("静") * 3.0)
	if mod("蚀") > 0:
		c.mark = maxf(c.mark, mod("蚀") * 4.0)

func pen_mat() -> int:
	if mod("火"):
		return EMBER
	if mod("霜"):
		return ICE
	if mod("蚀"):
		return GRAV
	return GOLD

## 刻刀：身前一个扇形
func slash() -> float:
	var a0 := atan2(P.ay, P.ax)
	var reach := 30.0 + (8.0 if LO.shape == "针" else 0.0)
	var dmg: int = 2 + P.dmg + (LO.shape_lv if LO.shape == "石" else 0)
	for c in cr:
		if not can_hit(c):
			continue
		var v := Vector2(c.x - P.x, c.y - P.y)
		if v.length() > reach + c.r or absf(angle_difference(a0, v.angle())) > 1.0:
			continue
		if mite_blocks(c, P.x, P.y):
			Sfx.play("ping")
			burst(c.x, c.y, 4, MIRROR, 6, 30, 0.3)
			tip("mite", "镜螨的正面挡住了！绕到它背后打粉色的软肉。")
			continue
		fx_hit(c, dmg, c.x, c.y)
	for b in EB:
		var v := Vector2(b.x - P.x, b.y - P.y)
		if v.length() < reach and absf(angle_difference(a0, v.angle())) < 1.0:
			b.life = 0
			burst(b.x, b.y, 4, b.m, 6, 30, 0.3)
	for k in 5:
		var a := a0 + (k - 2) * 0.4
		var px := P.x + cos(a) * reach * 0.7
		var py := P.y + sin(a) * reach * 0.7
		var r := rock_at(px, py)
		if r:
			carve(r, px, py, 4.5)
	FX.append({"k": "slash", "x": P.x, "y": P.y, "a": a0, "r": reach, "t": 0.16, "max": 0.16, "m": pen_mat()})
	P.vx += P.ax * 45
	P.vy += P.ay * 45
	Sfx.play("dash", 1.7)
	return 0.36

## 砚雷：朝准星扔出去，到地方 / 撞到东西就炸
func throw_bomb() -> float:
	var b := Bomb.new()
	b.x = P.x + P.ax * 5
	b.y = P.y + P.ay * 5
	b.vx = P.ax * 175
	b.vy = P.ay * 175
	b.dist = clampf(P.aim_d, 30.0, 150.0)
	BM.append(b)
	P.vx -= P.ax * 12
	P.vy -= P.ay * 12
	Sfx.play("dash", 0.6)
	return 0.8

func explode(x: float, y: float) -> void:
	var rad: float = 24.0 + (7.0 * LO.shape_lv if LO.shape == "石" else 0.0)
	for c in cr:
		if can_hit(c) and Vector2(c.x - x, c.y - y).length() < rad + c.r:
			fx_hit(c, 2 + P.dmg, x, y)
	for b in EB:
		if Vector2(b.x - x, b.y - y).length() < rad:
			b.life = 0
	for k in 9:
		var a := k / 8.0 * TAU
		var d := 0.0 if k == 8 else rad * 0.45
		var px := x + cos(a) * d
		var py := y + sin(a) * d
		var r := rock_at(px, py)
		if r:
			carve(r, px, py, 7.0)
	if mod("裂") > 0:
		var src := Bullet.new()
		src.mat = pen_mat()
		src.burn = mod("火") * 1.5
		src.frost = mod("霜") * 1.5
		for i in 6 * mod("裂"):
			spawn_small(x, y, i / (6.0 * mod("裂")) * TAU, src)
	FX.append({"k": "boom", "x": x, "y": y, "r": rad, "t": 0.3, "max": 0.3, "m": pen_mat()})
	burst(x, y, 26, pen_mat(), 6, 90, 0.6)
	burst(x, y, 14, SPACE, 3, 50, 0.9, false)
	shk = maxf(shk, 3.5)
	Sfx.play("rock", 0.5)
	Sfx.play("kill", 0.6)

func upd_bombs(dt: float) -> void:
	for b in BM:
		b.age += dt
		b.x += b.vx * dt
		b.y += b.vy * dt
		b.dist -= 175.0 * dt
		var hit := b.dist <= 0 or rock_at(b.x, b.y) != null
		if not hit:
			for c in cr:
				if can_hit(c) and Vector2(c.x - b.x, c.y - b.y).length() < c.r + 2:
					hit = true
					break
		if hit:
			explode(b.x, b.y)
			b.age = -1
		elif randf() < 0.6:
			part(b.x, b.y, (randf() - 0.5) * 10, (randf() - 0.5) * 10, 0.4, pen_mat(), 4)
	BM = BM.filter(func(b): return b.age >= 0)
	for f in FX:
		f.t -= dt
	FX = FX.filter(func(f): return f.t > 0)

## 墨线：蓄力越久越粗越疼，穿过所有敌人，石头只能钻一小段
func fire_beam(ch: float) -> void:
	var dmg := roundi(1 + ch * 4) + P.dmg
	var x := P.x + P.ax * 6
	var y := P.y + P.ay * 6
	var rock_budget := 10 + int(ch * 26)
	var done := {}
	var n := 0
	while n < 115:
		n += 1
		x += P.ax * 2
		y += P.ay * 2
		var r := rock_at(x, y)
		if r:
			carve(r, x, y, 2.0 + ch * 1.5)
			rock_budget -= 1
			if rock_budget <= 0:
				break
		var stop := false
		for c in cr:
			if done.has(c) or not can_hit(c):
				continue
			if Vector2(c.x - x, c.y - y).length() < c.r + 2 + ch * 2:
				if mite_blocks(c, P.x, P.y):
					Sfx.play("ping")
					burst(x, y, 8, MIRROR, 6, 40, 0.4)
					stop = true
					break
				done[c] = true
				fx_hit(c, dmg, x, y)
		if stop:
			break
		if n % 3 == 0:
			part(x, y, (randf() - 0.5) * 30, (randf() - 0.5) * 30, 0.35, pen_mat(), 5, true)
	FX.append({"k": "beam", "x": P.x + P.ax * 6, "y": P.y + P.ay * 6, "x1": x, "y1": y, "w": 0.5 + ch * 1.5, "t": 0.2, "max": 0.2, "m": pen_mat()})
	P.vx -= P.ax * (30 + ch * 60)
	P.vy -= P.ay * (30 + ch * 60)
	shk = maxf(shk, 1.5 + ch * 3)
	Sfx.play("roar", 2.2)
	Sfx.play("shoot", 0.5)

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
		P.aim_d = aim.length() if not touch_mode or touch_fire else 90.0
		aim = aim.normalized()
		P.ax = aim.x
		P.ay = aim.y
	const ACC := 235.0
	P.vx += ix * ACC * dt
	P.vy += iy * ACC * dt
	var drag := 0.6 if P.dash_t > 0 else 2.35
	if chapter == 2 and P.dash_t <= 0 and in_ink(P.x, P.y):
		drag = 7.0
		tip("ink", "墨池会拖住脚步。冲刺可以滑过去。")
		if P.moving and randf() < 0.3:
			part(P.x, P.y + 3, (randf() - 0.5) * 20, (randf() - 0.5) * 20, 0.5, GRAV, 3)
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
	P.fire_cd -= dt / P.haste
	var firing := (mouse_down and not fire_locked()) or touch_fire or (_autoplay and _ap_fire)
	for i in P.pens:
		if pressed(KEY_1 + i) and P.pen != i:
			set_pen(i)
	if pressed(KEY_R) or pressed("wheel_dn"):
		set_pen((P.pen + 1) % P.pens)
	if pressed("wheel_up"):
		set_pen((P.pen + P.pens - 1) % P.pens)
	if P.pen == 4:
		if firing:
			if P.charge == 0.0:
				Sfx.play("warn", 2.4)
			P.charge = minf(1.0, P.charge + dt / 0.9)
		elif P.charge > 0.0:
			if P.charge > 0.2 and P.fire_cd <= 0:
				fire_beam(P.charge)
				P.fire_cd = 0.25
			P.charge = 0.0
	elif firing and P.fire_cd <= 0 and S == "play":
		match P.pen:
			2: P.fire_cd = slash()
			3: P.fire_cd = throw_bomb()
			_:
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
	if S == "play" and pressed(KEY_G):
		if unlocked < 2:
			toast("装订完这一章的三张书页，才能翻到下一章。", C_DIM)
		elif not in_kiln:
			toast("要在炉灯的暖圈里才能翻章。", C_DIM)
		else:
			goto_chapter(3 - chapter)
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
	var gid: int = PAGES[id].gid
	Sfx.play("page")
	shk = 5
	burst(0, -4, 60, ORE, 6, 90, 1.6)
	toast("装订：失落之页「%s」" % PAGES[id].name, C_GOLD, 5)
	toast(PAGE_TXT[gid], C_TEAL, 6)
	match gid:
		0:
			P.maxwarm += 30
			P.warm = P.maxwarm
			P.glaze += 0.15
		1:
			P.dmg += 1
		3:
			P.maxhp += 1
			P.hp = P.maxhp
		4:
			P.haste = 0.85
	if id == 2:
		S = "ending"
		end_t = 0
		save.clears = int(save.clears) + 1
		unlocked = 2
		persist()
	elif ch_bound() < 3:
		toast("这一章还剩 %d 页。" % (3 - ch_bound()), C_DIM, 4)
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
	P.charge = 0
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
	var b := boss()
	if b and b.st != "sleep" and b.st != "dead":
		reset_serp()
	HZ.clear()

func reset_serp() -> void:
	# 首领回到沉睡（两章通用）
	var b := boss()
	if b == null:
		return
	b.st = "sleep"
	b.hp = DEF[b.t].hp
	b.x = PAGES[2].x
	b.y = PAGES[2].y
	b.vx = 0
	b.vy = 0
	b.off = 0
	b.orR = 0
	b.sing = 0
	b.burn = 0
	for i in b.seg.size():
		b.seg[i] = Vector2(b.x, b.y)
	EB.clear()
	HZ.clear()

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
		if d > 700 and c.t != "moth" and not is_boss(c):
			continue
		# 字句效果：灼烧、减速、安静
		c.slow -= dt
		c.calm -= dt
		c.mark -= dt
		if is_boss(c) and c.st != "fight":
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
			"redact":
				upd_redact(c, cdt, d)
			"comma":
				upd_comma(c, cdt, d, dx, dy)
			"blot", "blotlet":
				upd_blot(c, cdt, d, dx, dy)
			"worm":
				upd_worm(c, cdt, d, dx, dy)
			"wisp":
				upd_wisp(c, cdt, d, dx, dy)
		if not (c.t in ["clam", "leech", "serp", "redact", "worm", "wisp"]) and not c.dead:
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
	var hpk: float = c.hp / DEF.serp.hp
	var p3 := hpk <= 0.25
	if p3 and c.orR == 0:
		c.orR = 1
		c.sing = 1.5
		shk = 6
		toast("回声蛇不再只跟着脚印了——看到细线，它就要直直撞过来！", C_RED, 4)
	if c.off == 1:
		# 第三阶段：停下来瞄准
		c.tm -= dt
		if c.tm <= 0:
			c.off = 2
			c.tm = 0.55
			c.vx = cos(c.ha) * 340
			c.vy = sin(c.ha) * 340
			Sfx.play("roar", 1.4)
	elif c.off == 2:
		# 直线冲撞，沿路撒下回声
		c.tm -= dt
		c.x += c.vx * dt
		c.y += c.vy * dt
		c.w -= dt
		if c.w <= 0:
			c.w = 0.045
			add_eb(c.x, c.y, (randf() - 0.5) * 24, (randf() - 0.5) * 24, 2.6, SERP)
		if c.tm <= 0:
			c.off = 0
			c.sing = 4.2
	else:
		var delay := 84 if hpk > 0.5 else 62
		var k := posmod(tr_i - delay, 400)
		var ex := TRX[k] - c.x
		var ey := TRY[k] - c.y
		var el := maxf(0.0001, sqrt(ex * ex + ey * ey))
		var sp := minf(el * 5, 150.0)
		c.x += ex / el * sp * dt
		c.y += ey / el * sp * dt
		c.ha = atan2(ey, ex)
		if p3:
			c.sing -= dt
			if c.sing <= 0 and d < 260:
				c.off = 1
				c.tm = 0.8
				c.ha = atan2(P.y - c.y, P.x - c.x)
				HZ.append({"x": c.x + cos(c.ha) * 95, "y": c.y + sin(c.ha) * 95, "a": c.ha, "t": 0.8, "w": 5.0, "len": 95.0, "dmg": false})
				Sfx.play("warn", 1.5)
	var prev := Vector2(c.x, c.y)
	for i in c.seg.size():
		var sv := c.seg[i] - prev
		var sl := maxf(0.0001, sv.length())
		if sl > 5.5:
			c.seg[i] = prev + sv / sl * 5.5
		prev = c.seg[i]
	c.burst_t -= dt
	if c.burst_t <= 0 and c.off == 0:
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
	if c.t != "clam" and not is_boss(c):
		var dx := c.x - P.x
		var dy := c.y - P.y
		var d := maxf(0.0001, sqrt(dx * dx + dy * dy))
		c.x += dx / d * 2
		c.y += dy / d * 2
	if c.hp <= 0:
		kill(c, true)

func kill(c: Creature, drop: bool) -> void:
	if c.dead or (is_boss(c) and c.st == "dead") or (c.t == "clam" and c.st == "empty"):
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
	var big := is_boss(c)
	c.dead = not big
	if drop and randf() < float(WD.drop.get(c.t, 0.0)):
		var keys: Array = WD.chars.keys()
		var p := Pick.new()
		p.x = c.x
		p.y = c.y
		p.vx = (randf() - 0.5) * 30
		p.vy = (randf() - 0.5) * 30
		p.k = "word"
		p.wc = keys[randi() % keys.size()]
		p.gold = big or randf() < float(WD.gold_chance)
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
	var m: int = D.m
	burst(c.x, c.y, 80 if big else 14, m, 5, 110 if big else 45, 1.6 if big else 0.6)
	if c.t == "folio" and drop:
		toast("一本书鳐散成了纸片……", C_DIM)
	if c.t == "grav":
		burst(c.x, c.y, 30, GOLD, 6, 80, 0.8)
		shk = 4
	if c.t == "blot":
		# 打散以后裂成两团小的
		for s in [-1.0, 1.0]:
			spawn_q.append(["blotlet", c.x + s * 5, c.y, s * 60, -20.0])
	if c.t == "worm":
		for sg in c.seg:
			burst(sg.x, sg.y, 3, PAPER, 5, 30, 0.5)
	if big:
		c.st = "dead"
		shk = 12
		PAGES[2].state = "free"
		if c.t == "serp":
			toast("回声蛇散成了一千句回声。", C_GOLD, 5)
			toast("第三页「论回声」从茧里漂了出来。", C_TEAL, 5)
		else:
			toast("删节者把自己也划掉了。", C_GOLD, 5)
			toast("第三页「论空白」露了出来。", C_TEAL, 5)
		for sg in c.seg:
			burst(sg.x, sg.y, 8, m, 5, 50, 1)
		EB.clear()
		HZ.clear()

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
			if i < 1 or j < 1 or i >= r.S - 1 or j >= r.SH - 1:
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
			for k in r.S * r.SH:
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
					if b.hit.has(c) or not can_hit(c):
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
				if b.w.has("寻回"):
					for c in cr:
						if can_hit(c) and not b.hit.has(c) and Vector2(c.x - b.x, c.y - b.y).length() < 60:
							v = Vector2(c.x - b.x, c.y - b.y).normalized() * b.sp * 0.9
							break
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
			if r and b.bounce > 0 and b.orbit <= 0:
				b.bounce -= 1
				var nrm := rock_normal(r, b.x, b.y)
				var bv := Vector2(b.vx, b.vy)
				if bv.dot(nrm) < 0:
					bv = bv.bounce(nrm)
				b.x -= b.vx * dt / 2
				b.y -= b.vy * dt / 2
				b.vx = bv.x
				b.vy = bv.y
				b.life = maxf(b.life, 0.35)
				b.hit.clear()
				if b.w.has("重弹"):
					b.dmg += 1
				carve(r, b.x - nrm.x * 2, b.y - nrm.y * 2, 1.6)
				burst(b.x, b.y, 3, b.mat, 6, 30, 0.25)
				Sfx.play("ping", 1.3)
				continue
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
				if not can_hit(c):
					if c.t == "redact" and c.st == "sleep" and Vector2(b.x - c.x, b.y - c.y).length() < 15:
						b.life = 0
						burst(b.x, b.y, 3, RUIN, 6, 20, 0.3)
						break
					continue
				if hit_dist(c, b.x, b.y) < c.r + (2.5 if b.big else 1.5):
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
	var dmg := b.dmg
	if b.crit > 0 and randf() < b.crit:
		dmg *= 3
		burst(c.x, c.y, 8, GOLD, 6, 50, 0.4)
	if c.mark > 0:
		dmg += 1
	hurt_c(c, dmg, b.x, b.y)
	if b.mark > 0:
		c.mark = maxf(c.mark, b.mark)
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
	if b.chain > 0:
		var best: Creature = null
		var bd := 75.0
		for o in cr:
			if o == c or b.hit.has(o) or not can_hit(o):
				continue
			var od := Vector2(o.x - c.x, o.y - c.y).length()
			if od < bd:
				bd = od
				best = o
		if best:
			b.chain -= 1
			var v := Vector2(best.x - b.x, best.y - b.y).normalized() * maxf(b.sp, 220.0)
			b.vx = v.x
			b.vy = v.y
			b.life = maxf(b.life, 0.35)
			b.orbit = 0
			b.returning = false
			burst(b.x, b.y, 5, ORE, 6, 40, 0.3)
			return
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
	var tg := targets()
	for t in tg:
		if count_type(t) < tg[t]:
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
		var t: String = DEF[c.t].get("as", c.t)
		if seen.has(t) or c.dead:
			continue
		if Vector2(c.x - P.x, c.y - P.y).length() < 130:
			if (is_boss(c) and c.st == "sleep") or (c.t == "wisp" and c.open < 0.5):
				continue
			seen[t] = true
			toast("新生物 ·「%s」  (Tab 图鉴)" % DEF[t].name, C_GOLD, 4)
			Sfx.play("note")
			persist()

# 画面
func build_lights() -> void:
	SUNE = SUN * (1.0 - 0.85 * zone_dark)
	lights.clear()
	var f := 0.92 + 0.08 * sin(T * 11) * sin(T * 4.3)
	lights.append(Vector4(0, -2, kiln_r() * 1.8, 1.25 * f))
	for b in BEA:
		lights.append(Vector4(b.x, b.y - 5, 90, 0.9 * f * ((0.5 + 0.5 * sin(T * 20)) if b.hp < 3 else 1.0)))
	if S != "title" and S != "intro":
		lights.append(Vector4(P.x, P.y, 62 + 30 * P.charge, 0.75 + 0.4 * P.charge))
	for pg in PAGES:
		if pg.state == "free":
			lights.append(Vector4(pg.x, pg.y, 55, 0.8))
	for l in LAMPS:
		if l.lit > 0 and absf(l.x - cam_pos.x) < 280 and absf(l.y - cam_pos.y) < 200:
			lights.append(Vector4(l.x, l.y - 10, 85, 0.95 * f * (1.0 if l.lit > 6 else 0.5 + 0.5 * sin(T * 18))))
	for fx in FX:
		if fx.k == "boom":
			lights.append(Vector4(fx.x, fx.y, 80, 1.4 * fx.t / fx.max))
		elif fx.k == "beam":
			lights.append(Vector4((fx.x + fx.x1) / 2.0, (fx.y + fx.y1) / 2.0, 110, 1.0 * fx.t / fx.max))
	for b in BM:
		lights.append(Vector4(b.x, b.y, 26, 0.6))
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
		if is_boss(c) and c.st != "dead":
			lights.append(Vector4(c.x, c.y, 60, 0.5 if c.st == "sleep" else 0.7))
	if lights.size() > 24:
		lights.resize(24)

func light_at(x: float, y: float) -> float:
	var L := AMB + SUNE * 0.55
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

func targets() -> Dictionary:
	return TARGETS[chapter]

func boss() -> Creature:
	return serp if serp != null else redact

func is_boss(c: Creature) -> bool:
	return c.t == "serp" or c.t == "redact"

func ch_bound() -> int:
	var n := 0
	for pg in PAGES:
		if pg.state == "bound":
			n += 1
	return n

func rock_normal(r: Rock, x: float, y: float) -> Vector2:
	# 石头表面朝外的方向（书架是长方形，按哪一面更近来算）
	if r.box:
		var dx := (x - r.x) / maxf(1.0, r.hw)
		var dy := (y - r.y) / maxf(1.0, r.hh)
		return Vector2(signf(dx), 0) if absf(dx) > absf(dy) else Vector2(0, signf(dy))
	return Vector2(x - r.x, y - r.y).normalized()

func _gen_stacks() -> void:
	# 书架迷宫：一格一格地摆横着或竖着的书架，留出能走的过道
	var gy := -WR
	while gy < WR:
		var gx := 380.0
		while gx < WR:
			var x := gx + (R0.randf() - 0.5) * 22
			var y := gy + (R0.randf() - 0.5) * 16
			var roll := R0.randf()
			gx += 112
			if zn(x, y) != "stacks" or Vector2(x, y).length() > WR - 70 or Vector2(x, y).length() < 450:
				continue
			if Vector2(x - PAGES[0].x, y - PAGES[0].y).length() < 80:
				continue
			if roll < 0.42:
				rocks.append(Rock.build_box(roundi(x), roundi(y), 26 + R0.randi() % 14, 5, "stacks", R0))
			elif roll < 0.78:
				rocks.append(Rock.build_box(roundi(x), roundi(y), 5, 20 + R0.randi() % 12, "stacks", R0))
		gy += 84

func gen_ch2() -> void:
	# 墨海里的墨池
	var t := 0
	while t < 500 and INK.size() < 16:
		t += 1
		var a := -1.08 - R0.randf() * 1.08
		var d := 480 + R0.randf() * 790
		var p := Vector2(cos(a) * d, sin(a) * d)
		var r: float = [24.0, 34.0, 46.0][R0.randi() % 3]
		if p.distance_to(Vector2(PAGES[2].x, PAGES[2].y)) < 150 + r:
			continue
		var ok := true
		for q in INK:
			if Vector2(q.x - p.x, q.y - p.y).length() < q.z + r + 30:
				ok = false
		if ok:
			INK.append(Vector3(p.x, p.y, r))
	for k in 6:
		var a := k / 6.0 * TAU + 0.5
		var p := Vector2(PAGES[2].x + cos(a) * 170, PAGES[2].y + sin(a) * 170)
		if p.length() < WR - 30:
			INK.append(Vector3(p.x, p.y, 24.0))
	# 熄灯区的路灯
	t = 0
	while t < 800 and LAMPS.size() < 17:
		t += 1
		var a := 1.1 + R0.randf() * 2.93
		var d := 470 + R0.randf() * 790
		var p := Vector2(cos(a) * d, sin(a) * d)
		if rock_at(p.x, p.y) or rock_at(p.x, p.y - 10):
			continue
		var ok := true
		for l in LAMPS:
			if Vector2(l.x - p.x, l.y - p.y).length() < 150:
				ok = false
		if ok:
			LAMPS.append({"x": p.x, "y": p.y, "lit": 0.0})
	for k in 3:
		var a := k / 3.0 * TAU + 0.9
		LAMPS.append({"x": PAGES[1].x + cos(a) * 58, "y": PAGES[1].y + sin(a) * 58 + 8, "lit": 0.0})

func in_ink(x: float, y: float) -> bool:
	for q in INK:
		if absf(x - q.x) < q.z and Vector2(x - q.x, y - q.y).length() < q.z - 2:
			return true
	return false

func init_c(c: Creature) -> void:
	# 新生物出生时各自要准备的东西
	match c.t:
		"mite":
			c.ang = randf() * TAU
		"comma":
			c.off = randi() % 2
			c.tm = 1.0 + randf() * 2.0
		"blot", "blotlet":
			c.tm = randf()
		"worm":
			c.ang = randf() * TAU
			c.seg.clear()
			for i in 7:
				c.seg.append(Vector2(c.x, c.y))

func apply_pages() -> void:
	# 把记下来的书页状态套到当前这一章的世界上
	var st: Array = page_store.get(str(chapter), [])
	for i in mini(st.size(), PAGES.size()):
		PAGES[i].state = str(st[i].get("state", PAGES[i].state))
		PAGES[i].x = float(st[i].get("x", PAGES[i].x))
		PAGES[i].y = float(st[i].get("y", PAGES[i].y))
	var b := boss()
	if b and PAGES[2].state != "sealed":
		b.st = "dead"
		b.hp = 0
	P.bound = 0
	for k in page_store:
		for q in page_store[k]:
			if str(q.get("state", "")) == "bound":
				P.bound += 1

func stash_pages() -> void:
	var pgs := []
	for pg in PAGES:
		var carried: bool = pg.state == "carried"
		pgs.append({"state": "free" if carried else pg.state, "x": P.x if carried else pg.x, "y": P.y if carried else pg.y})
	page_store[str(chapter)] = pgs

func goto_chapter(n: int) -> void:
	# 翻到另一章：炉灯跟着走，带出去的信标收回来
	if n == chapter or n < 1 or n > unlocked or not P.carry.is_empty():
		return
	stash_pages()
	P.beacons += BEA.size()
	chapter = n
	new_world()
	P.x = 0
	P.y = 34
	P.vx = 0
	P.vy = 0
	P.inv = 1.5
	P.charge = 0
	cam_pos = Vector2(0, 30)
	for i in 400:
		TRX[i] = P.x
		TRY[i] = P.y
	toasts.clear()
	shk = 6
	Sfx.play("page")
	burst(0, -4, 60, ORE, 6, 90, 1.6)
	toast(CHNAME[n], C_GOLD, 5)
	if n == 2:
		toast("炉灯跟着你翻到了下一章。这里的三张书页在书架迷宫、熄灯区和墨海。", C_TEAL, 6)
	save_run()

func hit_dist(c: Creature, x: float, y: float) -> float:
	# 字弹离这只生物有多远（书虫的身子也算）
	var d := Vector2(x - c.x, y - c.y).length()
	if c.t == "worm":
		for sg in c.seg:
			d = minf(d, Vector2(x - sg.x, y - sg.y).length() + 1.5)
	return d

func fx_near(f: Dictionary, x: float, y: float) -> bool:
	# 刀光 / 爆炸 / 墨线有没有扫到 (x, y)
	match f.k:
		"boom":
			return Vector2(x - f.x, y - f.y).length() < f.r + 4
		"slash":
			var v := Vector2(x - f.x, y - f.y)
			return v.length() < f.r + 4 and absf(angle_difference(f.a, v.angle())) < 1.0
		"beam":
			var a := Vector2(f.x, f.y)
			var b := Vector2(f.x1, f.y1)
			return Geometry2D.get_closest_point_to_segment(Vector2(x, y), a, b).distance_to(Vector2(x, y)) < 6
	return false

func upd_world2(dt: float) -> void:
	# 第二章的环境：熄灯区变暗、路灯、删除线，还有排队等着出生的生物
	var dk := 1.0 if chapter == 2 and zn(P.x, P.y) == "dark" else 0.0
	zone_dark += (dk - zone_dark) * minf(1.0, dt * 1.5)
	if dk > 0:
		tip("dark", "熄灯区很暗。朝路灯开一枪能把它点亮：亮一分钟，周围暖和。")
	for l in LAMPS:
		if l.lit > 0:
			l.lit -= dt
			continue
		if Vector2(l.x - P.x, l.y - P.y).length() > 280:
			continue
		var hit := false
		for b in PB:
			if Vector2(b.x - l.x, b.y - (l.y - 10)).length() < 7:
				hit = true
				break
		if not hit:
			for f in FX:
				if f.t > f.max - 0.05 and fx_near(f, l.x, l.y - 10):
					hit = true
		if hit:
			l.lit = 60.0
			Sfx.play("beacon", 1.3)
			burst(l.x, l.y - 10, 14, GOLD, 6, 40, 0.6)
			tip("lamp", "路灯点亮了。灯魇只有在亮处才有身体，把它们引到灯下再打。")
	for h in HZ:
		var was: float = h.t
		h.t -= dt
		if was > 0 and h.t <= 0 and h.dmg:
			Sfx.play("rock", 0.6)
			shk = maxf(shk, 2.5)
		if h.t <= 0 and h.dmg and S == "play":
			var px: float = P.x - h.x
			var py: float = P.y - h.y
			var al: float = px * cos(h.a) + py * sin(h.a)
			var pe: float = -px * sin(h.a) + py * cos(h.a)
			if absf(pe) < h.w and absf(al) < h.len:
				hurt_player(1, h.x + cos(h.a) * al, h.y + sin(h.a) * al)
	HZ = HZ.filter(func(h): return h.t > (-0.3 if h.dmg else 0.0))
	for q in spawn_q:
		var c := mk(q[0], q[1], q[2])
		init_c(c)
		c.vx = q[3]
		c.vy = q[4]
		c.tm = 0.5
		c.flash = 0.1
	spawn_q.clear()

func upd_comma(c: Creature, dt: float, d: float, dx: float, dy: float) -> void:
	# 逗号蜂：不靠近，绕着小克飞，停一下、吐一个墨点
	if d < 240 and c.calm <= 0:
		var rad := clampf((d - 95.0) / 40.0, -1.0, 1.0)
		var side := 1.0 if c.off == 0 else -1.0
		var tx := dx / d * rad - dy / d * side * 0.8
		var ty := dy / d * rad + dx / d * side * 0.8
		var sp := 12.0 if c.st == "aim" else 55.0
		c.vx += (tx * sp - c.vx) * dt * 2.5
		c.vy += (ty * sp - c.vy) * dt * 2.5
		c.tm -= dt
		if c.st == "aim":
			if c.tm <= 0:
				c.st = "idle"
				c.tm = 1.9 + randf()
				add_eb(c.x, c.y, dx / d * 72, dy / d * 72, 3.2, LEECH)
				Sfx.play("note", 1.6)
				if randf() < 0.3:
					c.off = 1 - c.off
		elif c.tm <= 0 and d < 175 and S == "play":
			c.st = "aim"
			c.tm = 0.45
	else:
		c.st = "idle"
		c.vx += (cos(c.age * 0.4 + c.ph) * 12 + (c.hx - c.x) * 0.03 - c.vx) * dt
		c.vy += (sin(c.age * 0.5 + c.ph) * 10 + (c.hy - c.y) * 0.03 - c.vy) * dt
	c.x += c.vx * dt
	c.y += c.vy * dt
	if d < c.r + 4:
		hurt_player(1, c.x, c.y)

func upd_blot(c: Creature, dt: float, d: float, dx: float, dy: float) -> void:
	# 墨团：一跳一跳地扑过来
	var small := c.t == "blotlet"
	c.tm -= dt
	if c.tm <= 0:
		c.tm = (0.7 if small else 1.3) + randf() * 0.3
		var a := randf() * TAU
		var sp := 25.0
		if d < 210 and c.calm <= 0 and S == "play":
			a = atan2(dy, dx) + (randf() - 0.5) * 0.5
			sp = 100.0 if small else 82.0
		c.vx = cos(a) * sp
		c.vy = sin(a) * sp
		c.sp = 1.0
		for i in 3:
			part(c.x, c.y + 2, (randf() - 0.5) * 20, (randf() - 0.5) * 20, 0.6, GRAV, 3)
	c.sp = maxf(0.0, c.sp - dt * 2.5)
	c.vx *= exp(-2.2 * dt)
	c.vy *= exp(-2.2 * dt)
	c.x += c.vx * dt
	c.y += c.vy * dt
	if d < c.r + 3:
		hurt_player(1, c.x, c.y)

func upd_worm(c: Creature, dt: float, d: float, dx: float, dy: float) -> void:
	# 书虫：像一枚会拐弯的慢导弹，石头和书架直接啃穿
	c.flee -= dt
	var chase := d < 175 and c.calm <= 0 and c.flee <= 0 and S == "play"
	var want := c.ang + sin(c.age * 0.7 + c.ph) * 0.9
	if chase:
		want = atan2(dy, dx)
	elif Vector2(c.hx - c.x, c.hy - c.y).length() > 170:
		want = atan2(c.hy - c.y, c.hx - c.x)
	c.ang += clampf(angle_difference(c.ang, want), -2.3 * dt, 2.3 * dt)
	var hx := c.x + cos(c.ang) * 3
	var hy := c.y + sin(c.ang) * 3
	var r := rock_at(hx, hy)
	var sp := (64.0 if chase else 30.0) * (0.55 if r else 1.0)
	c.x += cos(c.ang) * sp * dt
	c.y += sin(c.ang) * sp * dt
	if r and c.cd <= 0 and d < 380:
		carve(r, hx, hy, 3.2)
		c.cd = 0.16
	var prev := Vector2(c.x, c.y)
	for i in c.seg.size():
		var sv := c.seg[i] - prev
		var sl := maxf(0.0001, sv.length())
		if sl > 3.4:
			c.seg[i] = prev + sv / sl * 3.4
		prev = c.seg[i]
	if d < c.r + 4:
		hurt_player(1, c.x, c.y)
		c.flee = 2.2

func upd_wisp(c: Creature, dt: float, d: float, dx: float, dy: float) -> void:
	# 灯魇：暗处只有一双眼睛、打不到、飘得快；亮处显形、变慢、能打
	var lit := light_at(c.x, c.y) >= 0.4
	c.open += ((1.0 if lit else 0.0) - c.open) * minf(1.0, dt * 5)
	if d < 270 and c.calm <= 0 and S == "play":
		var sp := 22.0 if lit else 72.0
		var tx := P.x - P.ax * 12 - c.x
		var ty := P.y - P.ay * 12 - c.y
		var tl := maxf(0.0001, sqrt(tx * tx + ty * ty))
		c.vx += (tx / tl * sp - c.vx) * dt * 2.0
		c.vy += (ty / tl * sp - c.vy) * dt * 2.0
	else:
		c.vx += ((c.hx - c.x) * 0.05 + cos(c.age * 0.5 + c.ph) * 8 - c.vx) * dt
		c.vy += ((c.hy - c.y) * 0.05 + sin(c.age * 0.4 + c.ph) * 8 - c.vy) * dt
	c.x += c.vx * dt
	c.y += c.vy * dt
	if d < c.r + 4 and S == "play" and P.inv <= 0:
		hurt_player(1, c.x, c.y)
		P.warm = maxf(0.0, P.warm - 8)
		burst(c.x, c.y, 10, JELLY, 4, 40, 0.5)
		var a := randf() * TAU
		c.x = P.x + cos(a) * 130
		c.y = P.y + sin(a) * 130
		c.vx = 0
		c.vy = 0
		tip("wisp", "灯魇只在光里才有身体：把它引到路灯、信标或炉灯旁边再打。")

func upd_redact(c: Creature, dt: float, d: float) -> void:
	# 第二章首领「删节者」：删除线、螺旋弹幕、召墨团；半血以后放完招就闪走
	if c.st == "sleep":
		if d < 230 and S == "play":
			c.st = "rise"
			c.tm = 2.0
			Sfx.play("roar", 0.7)
			shk = 8
			toast("删节者睁开了眼睛。看到细线就躲开！", C_RED, 4)
			tip("redact", "细线是预告：一眨眼之后那里会落下一道删除线。")
		return
	if c.st == "dead":
		return
	if c.st == "rise":
		c.tm -= dt
		shk = maxf(shk, 2)
		if c.tm <= 0:
			c.st = "fight"
			c.burst_t = 1.2
			c.off = 0
		return
	var hpk: float = c.hp / DEF.redact.hp
	var p2 := hpk <= 0.5
	if p2 and c.orR == 0:
		c.orR = 1
		shk = 8
		Sfx.play("roar", 0.5)
		toast("删节者开始乱划了！", C_RED, 3)
	var dx := P.x - c.x
	var dy := P.y - c.y
	var k := clampf((d - 100.0) / 50.0, -1.0, 1.0)
	c.vx += (dx / d * k * 42 - c.vx) * dt * 1.5
	c.vy += (dy / d * k * 42 - c.vy) * dt * 1.5
	c.x += c.vx * dt
	c.y += c.vy * dt
	c.ha = atan2(dy, dx)
	c.burst_t -= dt
	if c.sing > 0:
		# 螺旋弹幕
		c.sing -= dt
		c.w -= dt
		if c.w <= 0:
			c.w = 0.12 if p2 else 0.16
			c.ang += 0.41
			var arms := 3 if p2 else 2
			for s in arms:
				var a := c.ang + s * TAU / arms
				add_eb(c.x, c.y, cos(a) * 58, sin(a) * 58, 4.0, WINE)
	elif c.burst_t <= 0:
		var pat := c.off % 3
		c.off += 1
		c.flash = 0.25
		Sfx.play("roar", 0.8)
		match pat:
			0:
				var n := 5 if p2 else 3
				for i in n:
					var a := atan2(dy, dx) if i == 0 else randf() * PI
					var o := Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf() * 55
					HZ.append({"x": P.x + o.x, "y": P.y + o.y, "a": a, "t": 0.9 + i * 0.22, "w": 5.0, "len": 240.0, "dmg": true})
				Sfx.play("warn", 1.4)
				c.burst_t = 2.7 if p2 else 3.3
			1:
				c.sing = 2.6
				c.w = 0
				c.burst_t = 4.3 if p2 else 4.9
			2:
				if count_type("blotlet") < 8:
					for i in (3 if p2 else 2):
						spawn_q.append(["blotlet", c.x + cos(i * 2.1) * 16, c.y + sin(i * 2.1) * 16, cos(i * 2.1) * 70, sin(i * 2.1) * 70])
				var o := randf() * TAU
				for i in 10:
					var a := o + i / 10.0 * TAU
					add_eb(c.x, c.y, cos(a) * 50, sin(a) * 50, 4.2, WINE)
				c.burst_t = 3.0 if p2 else 3.7
		if p2 and pat != 1:
			burst(c.x, c.y, 30, RUIN, 5, 70, 0.7)
			var a := randf() * TAU
			c.x = P.x + cos(a) * 118
			c.y = P.y + sin(a) * 118
			c.vx = 0
			c.vy = 0
			burst(c.x, c.y, 30, RUIN, 5, 70, 0.7)
	if d < c.r + 4:
		hurt_player(1, c.x, c.y)
	if Vector2(P.x - PAGES[2].x, P.y - PAGES[2].y).length() > 620:
		reset_serp()
		toast("删节者合上了眼睛。", C_DIM)

# ---------- 章节 / 第二章「阅览室残骸」 ----------
var chapter := 1
var unlocked := 1            # 已经能去到第几章
var page_store := {}         # 每一章三张书页的状态："1" → [{state, x, y} ×3]
var zone_dark := 0.0         # 熄灯区里画面压暗的程度
var SUNE := 1.0              # 算上熄灯区之后，实际照到东西上的“太阳”亮度
var LAMPS: Array = []        # 熄灯区的路灯 {x, y, lit}
var INK: Array = []          # 墨海里的墨池 Vector3(x, y, 半径)
var HZ: Array = []           # 预告线 / 删除线 {x, y, a, t, w, len, dmg}
var spawn_q: Array = []      # 等这一帧结束再生出来的生物 [类型, x, y, vx, vy]
var redact: Creature = null
const CHNAME := ["", "第一章 · 星海散页", "第二章 · 阅览室残骸"]
const TARGETS := [
	{},
	{"hush": 15, "folio": 9, "leech": 15, "grav": 7, "mite": 10, "comma": 5},
	{"blot": 13, "worm": 8, "comma": 11, "wisp": 9, "hush": 6, "mite": 6, "folio": 3},
]
