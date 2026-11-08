extends Node2D
## 《散页 Unbound》主逻辑 —— 从 HTML 原型移植的第一个可玩切片。
## 小克（一只陶灵）在碎掉的宇宙图书馆里飞行、射击、挖矿、保暖。
## 切片包含：移动/冲刺/射击、可破坏小行星、页尘与余烬、体温与炉灯、
## 暗潮循环，以及五种生物（静默水母、书鳐、冰核贝、轨道蛭、蚀字蛾）。
## 尚未移植：工坊、信标、失落之页、镜螨、引力胎、回声蛇、图鉴、结局。

const PAINTER := preload("res://scripts/painter.gd")
const W := 320
const H := 180
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
}
const TARGET := {"hush": 15, "folio": 9, "leech": 15}
const INTRO := [
	"很久以前，「万语星图书馆」环绕着一颗叫「残烛」的恒星旋转，收藏着宇宙里说过的每一句话。",
	"后来残烛打了个寒颤。图书馆碎了——那一天叫做「大散页」。",
	"书页散成星尘。有的变成了生物，有的变成了寒冷，有的沉进了黑洞。",
	"你是小克，图书馆炉膛里烧出来的最后一只陶灵。",
	"去把散页拾回来吧。",
]
const CL := ["..HHHHHHHHH..", "..BBBBBBBBB..", "AABBBBBBBBBAA", "AABBBBBBBBBAA", "..BBBBBBBBB..", "..SSSSSSSSS..", "..L.L...L.L..", "..L.L...L.L.."]
const HEART := [".#.#.", "#####", "#####", ".###.", "..#.."]
const ICO_PAGE := [".#.", "###", ".#."]
const ICO_EMB := [".#.", "###", "###"]
const ICO_TH := [".#.", ".#.", ".#.", "###", "###"]
const DIG := {"0": "111101101101111", "1": "010110010010111", "2": "111001111100111", "3": "111001111001111", "4": "101101111001001", "5": "111100111001111", "6": "111100111101111", "7": "111001001001001", "8": "111101111101111", "9": "111101111001111", ":": "000010000010000", "/": "001001010100100"}

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

class Bullet:
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var life := 0.75
	var dmg := 1

class Pick:
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var k := "dust"
	var v := 1
	var age := 0.0

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

# ---------- 输入 ----------
var jp := {}
var mouse_down := false
var click_q := false
var touch_mode := false
var touches := {}
var joy := Vector2.ZERO
var touch_fire := false
var touch_aim := Vector2.ZERO

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
var ox := 0
var oy := 0
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

func _ready() -> void:
	R0.seed = 20261108
	font = _load_font(500)
	font_b = _load_font(700)

	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)
	var bg := ColorRect.new()
	bg.size = Vector2(W, H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_mat = ShaderMaterial.new()
	bg_mat.shader = load("res://shaders/bg.gdshader")
	bg_mat.set_shader_parameter("pal", Pal.pal_tex)
	bg.material = bg_mat
	bg_layer.add_child(bg)

	zone_painter = PAINTER.new()
	zone_painter.fn = _draw_zones
	add_child(zone_painter)
	rock_layer = Node2D.new()
	add_child(rock_layer)
	ent_painter = PAINTER.new()
	ent_painter.fn = _draw_world
	add_child(ent_painter)
	rock_mat = ShaderMaterial.new()
	rock_mat.shader = load("res://shaders/rock.gdshader")
	rock_mat.set_shader_parameter("pal", Pal.pal_tex)

	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()

	var vig_layer := CanvasLayer.new()
	vig_layer.layer = 1
	add_child(vig_layer)
	var vig := ColorRect.new()
	vig.size = Vector2(W, H)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig_mat = ShaderMaterial.new()
	vig_mat.shader = load("res://shaders/vignette.gdshader")
	vig_mat.set_shader_parameter("pal", Pal.pal_tex)
	vig.material = vig_mat
	vig_layer.add_child(vig)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 2
	add_child(hud_layer)
	hud_painter = PAINTER.new()
	hud_painter.fn = _draw_hud
	hud_layer.add_child(hud_painter)

	var t0 := Time.get_ticks_msec()
	new_world()
	print("world generated in %d ms, rocks=%d" % [Time.get_ticks_msec() - t0, rocks.size()])
	if OS.get_cmdline_user_args().has("--autoplay"):
		_autoplay = true

## 找一款系统里的中文字体直接加载（网页版以后需要打包一款开源中文字体）
func _load_font(weight: int) -> Font:
	for n in ["Hiragino Sans GB", "PingFang SC", "Microsoft YaHei", "Noto Sans CJK SC", "Source Han Sans SC", "WenQuanYi Micro Hei", "Droid Sans Fallback"]:
		var path := OS.get_system_font_path(n, weight, 100, false)
		if path != "" and FileAccess.file_exists(path):
			var f := FontFile.new()
			if f.load_dynamic_font(path) == OK and f.get_height(10) > 0:
				return f
	return ThemeDB.fallback_font

# =====================================================================
# 世界生成
# =====================================================================
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
		if ok:
			for o in rocks:
				if Vector2(x - o.x, y - o.y).length() < R + o.R + 16:
					ok = false
					break
		if ok:
			rocks.append(Rock.build(roundi(x), roundi(y), roundi(R), z, R0))
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
	mk(t, p.x, p.y)

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
	gen_rocks()
	cr.clear()
	PB.clear()
	PK.clear()
	PT.clear()
	gen_clams()
	for t in TARGET:
		var g := 0
		while count_type(t) < TARGET[t] and g < 60:
			g += 1
			spawn(t)

func count_type(t: String) -> int:
	var n := 0
	for c in cr:
		if c.t == t:
			n += 1
	return n

# =====================================================================
# 小工具
# =====================================================================
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
	return 64.0

func key(k: int) -> bool:
	return Input.is_key_pressed(k)

func pressed(k) -> bool:
	return jp.has(k)

# =====================================================================
# 输入（键盘 / 鼠标 / 触屏）
# =====================================================================
func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		jp[e.keycode] = true
		if e.keycode == KEY_M:
			toast("静音" if Sfx.toggle_mute() else "声音开启", C_DIM, 1.5)
	elif e is InputEventMouseButton:
		touch_mode = false
		if e.button_index == MOUSE_BUTTON_LEFT:
			mouse_down = e.pressed
			if e.pressed:
				click_q = true
		elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
			jp["dash"] = true
	elif e is InputEventMouseMotion:
		touch_mode = false
	elif e is InputEventScreenTouch:
		touch_mode = true
		var pos: Vector2 = e.position
		if e.pressed:
			click_q = true
			var kind := "aim"
			if pos.x > W - 44 and pos.y > H - 44:
				kind = "dash"
				jp["dash"] = true
			elif pos.x > W - 44 and pos.y > H - 80:
				kind = "btn"
				jp[KEY_Q] = true
			elif pos.x < W / 2.0:
				kind = "move"
			touches[e.index] = {"kind": kind, "start": pos, "pos": pos}
		else:
			touches.erase(e.index)
		_touch_sync()
	elif e is InputEventScreenDrag:
		if touches.has(e.index):
			touches[e.index].pos = e.position
		_touch_sync()

func _touch_sync() -> void:
	joy = Vector2.ZERO
	touch_fire = false
	for t in touches.values():
		if t.kind == "move":
			joy = (t.pos - t.start) / 18.0
			if joy.length() > 1.0:
				joy = joy.normalized()
		elif t.kind == "aim":
			touch_fire = true
			touch_aim = t.pos

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		mouse_down = false
		touches.clear()
		_touch_sync()

# =====================================================================
# 主循环
# =====================================================================
var _autoplay := false
var _ap_t := 0.0

func _physics_process(dt: float) -> void:
	if _autoplay:
		_autoplay_step(dt)
	step(dt)
	present()

func step(dt: float) -> void:
	T += dt
	duck = 1.0
	var go := click_q or pressed(KEY_ENTER) or pressed(KEY_SPACE)
	match S:
		"title":
			cam_pos = Vector2(cos(T * 0.05) * 60, sin(T * 0.05) * 40)
			if go:
				S = "intro"
				intro_t = 0.0
		"intro":
			intro_t += dt
			if go and intro_t > 0.4:
				intro_t = 15.0 if intro_t < 15.0 else 99.0
			if intro_t > 18.5:
				S = "play"
				toast("活下去：挖页尘、吃余烬、别让体温降到 0。", C_GOLD, 5)
				if touch_mode:
					toast("左边拖动移动 · 右边按住射击 · 右下角冲刺", C_DIM, 6)
				else:
					toast("WASD 移动 · 鼠标瞄准、左键射击 · 空格冲刺 · Q 吃余烬", C_DIM, 6)
		"play":
			gt += dt
			tide_t += dt
			upd_tide(dt)
			upd_player(dt)
			upd_creatures(dt)
			upd_bullets(dt)
			upd_pickups(dt)
			upd_spawns(dt)
			check_discover()
		"dead":
			dead_t += dt
			if dead_t > 2.6:
				respawn()
	if randf() < 0.3:
		part(3 + (randf() - 0.5) * 3, -20, (randf() - 0.5) * 6, -10 - randf() * 8, 2.2, MOTH, 3)
	upd_particles(dt)
	if S == "play" or S == "dead":
		var tgt := Vector2(P.x + P.ax * 14, P.y + P.ay * 10)
		cam_pos += (tgt - cam_pos) * minf(1.0, dt * 5)
	for t in toasts:
		t.t -= dt
	toasts = toasts.filter(func(t): return t.t > 0)
	shk = maxf(0.0, shk - dt * 14)
	for r in dirty:
		r.calc_normals()
		r.rebuild_image()
	dirty.clear()
	Sfx.set_duck(duck)
	Sfx.set_tide(TIDE)
	jp.clear()
	click_q = false

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
		P.dash_cd = 1.3
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
	var firing := mouse_down or touch_fire or (_autoplay and _ap_fire)
	if firing and P.fire_cd <= 0 and S == "play":
		P.fire_cd = 0.2
		var b := Bullet.new()
		b.x = P.x + P.ax * 5
		b.y = P.y + P.ay * 5
		b.vx = P.ax * 265 + P.vx * 0.3
		b.vy = P.ay * 265 + P.vy * 0.3
		b.dmg = P.dmg
		PB.append(b)
		P.vx -= P.ax * 5
		P.vy -= P.ay * 5
		Sfx.play("shoot", 1.0 + randf() * 0.09)
	# 体温
	var in_kiln := pd < kiln_r()
	if in_kiln:
		P.warm = minf(P.maxwarm, P.warm + 24 * dt)
	else:
		var drain := 0.8 * (1 + pd / 800) * (1 + 1.3 * TIDE)
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
		if P.heal_t >= 7 and P.hp < P.maxhp:
			P.heal_t = 0
			P.hp += 1
			burst(P.x, P.y, 6, GOLD, 5, 30, 0.6)
		tip("kiln", "这里是炉灯。站在暖圈里会回暖、慢慢修补裂缝。")
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
	P.inv -= dt

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
		toast("掉落的页尘留在了原地，回去捡吧。", C_DIM)

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
		if d > 700 and c.t != "moth":
			continue
		match c.t:
			"hush":
				c.vx = cos(c.age * 0.31 + c.ph) * 7 + (c.hx - c.x) * 0.02
				c.vy = sin(c.age * 0.23 + c.ph * 2) * 5 - 2.5 * (0.5 + 0.5 * sin(c.age * 2.2 + c.ph)) + (c.hy - c.y) * 0.02
				c.x += c.vx * dt
				c.y += c.vy * dt
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
				c.flee -= dt
				var el := maxf(0.0001, sqrt(ex * ex + ey * ey))
				c.vx += (ex / el * sp - c.vx) * dt * 1.5
				c.vy += (ey / el * sp - c.vy) * dt * 1.5
				c.x += c.vx * dt
				c.y += c.vy * dt
				c.tm -= dt
				if c.tm <= 0:
					c.tm = 5 + randf() * 4
					add_pick(c.x, c.y, "dust", -c.vx * 0.3, -c.vy * 0.3)
			"moth":
				if c.st == "burn":
					c.tm -= dt
					if c.tm <= 0:
						kill(c, true)
					c.x += sin(c.age * 20) * 20 * dt
				else:
					var ex := P.x - c.x
					var ey := P.y - c.y
					var el := maxf(0.0001, sqrt(ex * ex + ey * ey))
					var j := sin(c.age * 7 + c.ph) * 0.9
					var ux := (ex * cos(j) - ey * sin(j)) / el
					var uy := (ex * sin(j) + ey * cos(j)) / el
					c.vx += (ux * c.sp - c.vx) * dt * 2.6
					c.vy += (uy * c.sp - c.vy) * dt * 2.6
					c.x += c.vx * dt
					c.y += c.vy * dt
					if Vector2(c.x, c.y).length() < kiln_r() - 4:
						burst(c.x, c.y, 8, EMBER, 5, 30, 0.5)
						kill(c, false)
					elif d < c.r + 4 and S == "play" and P.inv <= 0:
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
					c.ang += c.w * dt
					c.x += (hx + cos(c.ang) * c.orR - c.x) * minf(1.0, dt * 4)
					c.y += (hy + sin(c.ang) * c.orR - c.y) * minf(1.0, dt * 4)
					if d < 115 and c.cd <= 0 and S == "play":
						c.st = "wind"
						c.tm = 0.75
						Sfx.play("note", pow(2.0, [0, 3, 5, 7, 10][randi() % 5] / 12.0))
				elif c.st == "wind":
					c.tm -= dt
					if c.tm <= 0:
						c.st = "lunge"
						c.tm = 0.55
						c.vx = dx / d * 215
						c.vy = dy / d * 215
				elif c.st == "lunge":
					c.tm -= dt
					c.x += c.vx * dt
					c.y += c.vy * dt
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
						c.x += ex / el * 55 * dt
						c.y += ey / el * 55 * dt
				if d < c.r + 4:
					hurt_player(1, c.x, c.y)
			"clam":
				c.tm -= dt
				if c.st == "grow":
					c.open = maxf(0.0, c.open - dt * 3)
					if c.tm <= 0:
						c.st = "open"
						c.tm = 2.6
				elif c.st == "open":
					c.open = minf(1.0, c.open + dt * 3)
					if c.tm <= 0:
						c.st = "grow"
						c.tm = 3.5 + randf() * 2
				elif c.st == "empty":
					c.open = maxf(0.0, c.open - dt * 2)
					if c.tm <= 0:
						c.st = "grow"
						c.tm = 2
						c.hp = DEF.clam.hp
		if c.t != "clam" and c.t != "leech" and not c.dead:
			var r := rock_at(c.x, c.y)
			if r:
				var ex := c.x - r.x
				var ey := c.y - r.y
				var el := maxf(0.0001, sqrt(ex * ex + ey * ey))
				c.x += ex / el * 1.5
				c.y += ey / el * 1.5
	cr = cr.filter(func(c): return not c.dead)

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
	if c.t != "clam":
		var dx := c.x - P.x
		var dy := c.y - P.y
		var d := maxf(0.0001, sqrt(dx * dx + dy * dy))
		c.x += dx / d * 2
		c.y += dy / d * 2
	if c.hp <= 0:
		kill(c, true)

func kill(c: Creature, drop: bool) -> void:
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
		return
	c.dead = true
	if drop:
		P.kills += 1
		Sfx.play("kill")
		for i in D.dust:
			add_pick(c.x, c.y, "dust", (randf() - 0.5) * 50, (randf() - 0.5) * 50)
		var em: float = D.ember
		if em >= 1.0 or (em > 0.0 and randf() < fmod(em, 1.0)):
			for i in maxi(1, floori(em)):
				add_pick(c.x, c.y, "ember", (randf() - 0.5) * 40, (randf() - 0.5) * 40)
	var m: int = {"hush": JELLY, "folio": PAPER, "moth": MOTH, "leech": LEECH}[c.t]
	burst(c.x, c.y, 14, m, 5, 45, 0.6)
	if c.t == "folio" and drop:
		toast("一本书鳐散成了纸片……", C_DIM)

# ---------- 子弹 / 挖矿 ----------
func carve(r: Rock, x: float, y: float, rad: float) -> int:
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
		for s in 2:
			if b.life <= 0:
				break
			b.x += b.vx * dt / 2
			b.y += b.vy * dt / 2
			var r := rock_at(b.x, b.y)
			if r:
				carve(r, b.x, b.y, 2.3)
				b.life = 0
				Sfx.play("rock")
				break
			for c in cr:
				if c.dead:
					continue
				if Vector2(b.x - c.x, b.y - c.y).length() < c.r + 1.5:
					hurt_c(c, b.dmg, b.x, b.y)
					b.life = 0
					break
		if b.life <= 0:
			burst(b.x, b.y, 2, CLAY, 5, 20, 0.2)
	PB = PB.filter(func(b): return b.life > 0)

func upd_pickups(dt: float) -> void:
	var mag := 40.0
	var keep: Array[Pick] = []
	for p in PK:
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
			if p.k == "dust":
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
		if p.age < 90:
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
			seen[c.t] = true
			toast("新生物 ·「%s」" % DEF[c.t].name, C_GOLD, 4)
			Sfx.play("note")

# =====================================================================
# 画面
# =====================================================================
func build_lights() -> void:
	lights.clear()
	var f := 0.92 + 0.08 * sin(T * 11) * sin(T * 4.3)
	lights.append(Vector4(0, -2, kiln_r() * 1.8, 1.25 * f))
	if S != "title" and S != "intro":
		lights.append(Vector4(P.x, P.y, 62, 0.75))
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

func shift_at(x: float, y: float) -> int:
	var L := light_at(x, y)
	if L >= 0.5:
		return 0
	if L >= 0.33:
		return -1
	if L >= 0.2:
		return -2
	return -3

func present() -> void:
	var sx := (randf() - 0.5) * shk
	var sy := (randf() - 0.5) * shk
	camera.position = Vector2(roundf(cam_pos.x + sx), roundf(cam_pos.y + sy))
	ox = int(camera.position.x) - W / 2
	oy = int(camera.position.y) - H / 2
	build_lights()
	var arr := PackedVector4Array()
	arr.resize(24)
	for i in lights.size():
		arr[i] = lights[i]
	rock_mat.set_shader_parameter("lights", arr)
	rock_mat.set_shader_parameter("nlights", lights.size())
	rock_mat.set_shader_parameter("sun", SUN)
	rock_mat.set_shader_parameter("amb", AMB)
	rock_mat.set_shader_parameter("time", T)
	bg_mat.set_shader_parameter("cam", cam_pos)
	bg_mat.set_shader_parameter("tide", TIDE)
	bg_mat.set_shader_parameter("time", T)
	var cold := (25.0 - P.warm) / 25.0 if S == "play" and P.warm < 25 else 0.0
	vig_mat.set_shader_parameter("tide", TIDE)
	vig_mat.set_shader_parameter("cold", cold)
	zone_painter.queue_redraw()
	ent_painter.queue_redraw()
	hud_painter.queue_redraw()

# ---------- 世界像素绘制（世界坐标） ----------
func wp(x: float, y: float, m: int, l: float) -> void:
	var sx := floori(x)
	var sy := floori(y)
	if sx < ox or sx >= ox + W or sy < oy or sy >= oy + H:
		return
	cv.draw_rect(Rect2(sx, sy, 1, 1), Pal.rc(m, l))

func on_screen(x: float, y: float, mg := 20.0) -> bool:
	return x - ox > -mg and x - ox < W + mg and y - oy > -mg and y - oy < H + mg

func ball(cx: float, cy: float, r: float, m: int, base: float, sh: int) -> void:
	var R := ceili(r)
	var fx := floori(cx)
	var fy := floori(cy)
	for dy in range(-R, R + 1):
		for dx in range(-R, R + 1):
			if dx * dx + dy * dy > r * r:
				continue
			var px := fx + dx
			var py := fy + dy
			var nx := dx / r
			var ny := dy / r
			var nz := sqrt(maxf(0.0, 1.0 - nx * nx - ny * ny))
			var L := nx * SUNV.x + ny * SUNV.y + nz * SUNV.z
			wp(px, py, m, floorf(base + (L - 0.55) * 3.2 + Pal.bay(px, py) - 0.5) + sh)

func _draw_zones(c: CanvasItem) -> void:
	cv = c
	var r := kiln_r()
	if not on_screen(0, 0, r + 10):
		return
	var n := floori(r * TAU / 3)
	for i in n:
		if i % 3 == 2:
			continue
		var a := float(i) / n * TAU + T * 0.05
		wp(cos(a) * r, sin(a) * r, GOLD, 2 + (1 if i % 3 == 0 else 0))
	# 暖圈里稀疏的暗红点（只在抖动矩阵最小的格子上）
	var R := ceili(r)
	var gy := -R - posmod(-R, 4)
	while gy <= R:
		var gx := -R - posmod(-R, 4)
		while gx <= R:
			var d := sqrt(float(gx * gx + gy * gy))
			if d < r and 0.03125 < 0.06 * (1 - d / r) * (0.5 + TIDE):
				wp(gx, gy, WINE, 2)
			gx += 4
		gy += 4

func _draw_world(c: CanvasItem) -> void:
	cv = c
	draw_kiln()
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
	draw_bullets()
	draw_player()
	draw_particles()

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

func draw_pickups() -> void:
	for p in PK:
		if not on_screen(p.x, p.y):
			continue
		var tw := sin(T * 8 + p.age * 3) > 0
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
		for k in 4:
			wp(b.x - b.vx / l * k, b.y - b.vy / l * k, CLAY if k else GOLD, 6 - k)
		wp(b.x + 0.5, b.y + 0.5, GOLD, 5)

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

# =====================================================================
# 界面（屏幕坐标 320x180）
# =====================================================================
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
	if S == "play":
		draw_hud_play()
		if touch_mode:
			draw_touch_ui()
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
	# 暗潮钟
	var ph := fposmod(tide_t, 150.0)
	var dark := tide_t > 0 and ph >= 112
	var left := 150 - ph if dark else (112 - tide_t if tide_t < 0 else 112 - ph)
	text_r("暗潮" if dark else "星息", W - 46, 2, 9, C_RED if dark else C_GOLD, C_SH)
	digits("%d:%02d" % [int(left / 60), int(fmod(left, 60))], W - 44, 6, C_RED if dark else C_TXT, C_SH)
	draw_minimap(W - 46, 15, 42)
	# 区域名
	var z: String = ZNAME[zn(P.x, P.y)]
	if z != zone_name:
		zone_name = z
		zone_t = 2.5
	zone_t -= 1.0 / 60.0
	if zone_t > 0 and S == "play":
		text(z, W / 2.0, 20, 10, C_DIM, C_SH, minf(1.0, zone_t))
	# 指向炉灯的箭头
	if Vector2(P.x, P.y).length() > 110:
		var sx := -ox
		var sy := -oy
		if not (sx > 4 and sx < W - 4 and sy > 4 and sy < H - 4):
			var dx := float(sx) - W / 2.0
			var dy := float(sy) - H / 2.0
			var k := minf((W / 2.0 - 10) / maxf(0.001, absf(dx)), (H / 2.0 - 10) / maxf(0.001, absf(dy)))
			var axp := W / 2.0 + dx * k
			var ayp := H / 2.0 + dy * k
			var a := atan2(dy, dx)
			var col := Pal.rc(GOLD, 6 if sin(T * 4) > 0 else 5)
			for t in 5:
				for w in range(-t, t + 1):
					pset(roundf(axp + cos(a) * (2 - t) - sin(a) * w * 0.7), roundf(ayp + sin(a) * (2 - t) + cos(a) * w * 0.7), col)
	# 提示条
	var ty := H - 14.0
	for i in range(toasts.size() - 1, -1, -1):
		var t: Dictionary = toasts[i]
		var a := minf(1.0, minf(t.t * 2, (t.max - t.t) * 6))
		var lines := wrap_text(t.s, 10, 290)
		for j in range(lines.size() - 1, -1, -1):
			text(lines[j], W / 2.0, ty, 10, t.c, C_SH, a)
			ty -= 13

func draw_minimap(x: int, y: int, s: int) -> void:
	box(x, y, s, s, C_PANEL, C_LINE)
	var k := s / (WR * 2 + 60)
	var cx := x + s / 2.0
	var cy := y + s / 2.0
	for r in rocks:
		pset(roundf(cx + r.x * k), roundf(cy + r.y * k), Pal.rc(MIRROR if r.zone == "echo" else RUIN, 5 if r.R > 18 else 4))
	pset(roundf(cx), roundf(cy), Pal.rc(GOLD, 6))
	pset(roundf(cx) + 1, roundf(cy), Pal.rc(GOLD, 5))
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

func draw_title() -> void:
	dim()
	var by := sin(T * 2) * 2
	text("散 页", W / 2.0, 26, 30, C_CLAY, C_SH, 1.0, true)
	text("U N B O U N D", W / 2.0, 66, 9, C_DIM, C_SH)
	draw_clawd(cv, W / 2.0, 100 + by, 3, int(T * 3) % 2, roundi(sin(T * 0.7)), fmod(T, 3.3) < 0.15)
	text("一只小陶灵，在碎掉的宇宙图书馆里拾回文字", W / 2.0, 124, 10, C_TXT, C_SH)
	text("点击开始", W / 2.0, 144, 11, C_GOLD, C_SH, 0.6 + 0.4 * sin(T * 3))
	text("WASD 移动 · 鼠标瞄准射击 · 空格冲刺 · Q 吃余烬 · M 静音", W / 2.0, 164, 8, C_DIM, C_SH)

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

# =====================================================================
# 自动试玩（仅用于测试：godot -- --autoplay）
# =====================================================================
var _ap_aim := Vector2.RIGHT
var _ap_fire := false

var _shots := {1.0: "title", 4.0: "play1", 9.0: "play2", 16.0: "tide"}

func _autoplay_step(dt: float) -> void:
	_ap_t += dt
	for k in _shots.keys():
		if _ap_t >= k:
			var img := get_viewport().get_texture().get_image()
			img.save_png("user://shot_%s.png" % _shots[k])
			print("shot ", ProjectSettings.globalize_path("user://shot_%s.png" % _shots[k]))
			_shots.erase(k)
	if _ap_t > 12.0 and tide_t < 112:
		tide_t = 113
		TIDE = 1.0
	if _ap_t > 17.0:
		get_tree().quit()
	if S == "title" and _ap_t > 0.5:
		click_q = true
	elif S == "intro" and _ap_t > 1.5:
		intro_t = 99
	elif S == "play":
		# 朝最近的石头飞过去并开火
		var best: Rock = null
		var bd := 1e9
		for r in rocks:
			var d := Vector2(r.x - P.x, r.y - P.y).length()
			if d < bd:
				bd = d
				best = r
		if best:
			_ap_aim = Vector2(best.x - P.x, best.y - P.y)
			_ap_fire = bd < 120
			joy = _ap_aim.normalized() * (0.8 if bd > 60 else 0.0)
