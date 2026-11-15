extends "res://scripts/game.gd"
## 暗潮试炼：《散页》的“幸存者”玩法试玩版（独立模式，不碰主线存档）。
##
## 一局十分钟左右：笔自动出手，生物一波比一波多；打散它们掉页尘，
## 攒够就升级，从三张卡里挑一支新笔、给笔升级，或者拿一个「字」（被动）。
## 笔练满五级、又拿到它的搭档字，就能“成词进化”。九分钟时回声蛇出现，打倒它就赢。
##
## 只借用主线的画面（贴图、色板、小克、生物的样子）和音效，逻辑全部在这个文件里。

class SV extends Creature:
	var mhp := 1.0
	var xp := 1
	var spd := 30.0
	var dmg := 1
	var elite := false
	var kx := 0.0          # 击退速度
	var ky := 0.0
	var blade_cd := 0.0    # 被绕身刻刀砍过后的冷却
	var fire_cd := 0.0     # 被火地烧过后的冷却
	var burn_dps := 0.0
	var gone_t := 0.0      # 跑出屏幕外多久了
	var tr_t := 0.0

## 每种生物在试炼里的数值：hp、速度、经验、碰一下扣几颗心、半径
const MT := {
	"moth": {"hp": 4.0, "sp": 52.0, "xp": 1, "dmg": 1, "r": 3.0},
	"hush": {"hp": 14.0, "sp": 24.0, "xp": 2, "dmg": 1, "r": 6.0},
	"folio": {"hp": 9.0, "sp": 70.0, "xp": 2, "dmg": 1, "r": 6.0},
	"leech": {"hp": 16.0, "sp": 36.0, "xp": 3, "dmg": 1, "r": 4.0},
	"chill": {"hp": 22.0, "sp": 30.0, "xp": 3, "dmg": 1, "r": 5.0},
	"icicle": {"hp": 12.0, "sp": 34.0, "xp": 3, "dmg": 1, "r": 4.0},
	"mite": {"hp": 45.0, "sp": 27.0, "xp": 5, "dmg": 1, "r": 5.0},
	"snail": {"hp": 70.0, "sp": 19.0, "xp": 6, "dmg": 2, "r": 5.0},
	"mothq": {"hp": 380.0, "sp": 30.0, "xp": 30, "dmg": 2, "r": 8.0},
	"grav": {"hp": 650.0, "sp": 20.0, "xp": 45, "dmg": 2, "r": 6.0},
	"comet": {"hp": 60.0, "sp": 85.0, "xp": 0, "dmg": 0, "r": 4.0},
	"clam": {"hp": 20.0, "sp": 0.0, "xp": 2, "dmg": 0, "r": 5.0},
	"serp": {"hp": 9000.0, "sp": 62.0, "xp": 0, "dmg": 2, "r": 8.0},
}

## 五支笔：自动出手。lv 1~5，第 5 级之后配上搭档字可以进化
const SPENS := [
	{"name": "毛笔", "evo": "雨", "ename": "暴雨",
		"lv": ["朝最近的敌人射字弹", "多射一发", "伤害 +40%", "多射一发", "出手更快，伤害 +40%"],
		"edesc": "字弹连成一阵急雨，每隔两秒再朝四面八方泼一圈"},
	{"name": "排刷", "evo": "火", "ename": "燎原",
		"lv": ["朝敌人刷出一片短程字弹", "多刷两发", "伤害 +40%", "射程更远，多刷两发", "出手更快，伤害 +40%"],
		"edesc": "刷出去的字弹落地成火，烧出一整片"},
	{"name": "刻刀", "evo": "环", "ename": "回环",
		"lv": ["朝身前挥一刀，刀长伤害高", "刀更长", "前后各挥一刀", "伤害 +40%", "出手更快，刀更长"],
		"edesc": "三把刻刀一直绕着你转，砍到什么都不停"},
	{"name": "砚雷", "evo": "裂", "ename": "裂石",
		"lv": ["往敌人堆里扔一团墨，炸开一片", "多扔一团", "炸得更大", "多扔一团", "伤害 +50%"],
		"edesc": "每团墨炸开后，再裂成四团小墨接着炸"},
	{"name": "墨线", "evo": "穿", "ename": "穿针",
		"lv": ["射出一道穿透一切的墨线", "更粗，伤害 +30%", "前后各射一道", "出手更快", "伤害 +50%"],
		"edesc": "墨线变成十字，绕着你扫一整圈"},
]

## 字：升级时拿的被动。kind 沿用主线的形 / 动 / 性，另加三个“身”字
const SW := {
	"针": {"max": 5, "kind": "形", "d": "字弹更快、飞得更远（+15%）"},
	"雨": {"max": 3, "kind": "形", "d": "毛笔、排刷、砚雷每次多出手一发"},
	"石": {"max": 5, "kind": "形", "d": "所有伤害 +15%"},
	"环": {"max": 5, "kind": "形", "d": "范围 +15%：刀更长、墨团更大、墨线更粗"},
	"穿": {"max": 3, "kind": "动", "d": "字弹多穿过 1 个敌人"},
	"寻": {"max": 3, "kind": "动", "d": "字弹会拐向附近的敌人"},
	"裂": {"max": 3, "kind": "动", "d": "字弹命中时，有机会裂出两枚小字弹"},
	"连": {"max": 3, "kind": "动", "d": "命中有机会电到旁边两个敌人"},
	"火": {"max": 3, "kind": "性", "d": "命中点燃敌人，每秒烧掉一截血"},
	"霜": {"max": 3, "kind": "性", "d": "命中让敌人变慢"},
	"暴": {"max": 3, "kind": "性", "d": "一成机会打出 2.5 倍伤害"},
	"重": {"max": 3, "kind": "性", "d": "吸页尘的范围 +50%"},
	"疾": {"max": 3, "kind": "身", "d": "跑得更快（+10%）"},
	"炉": {"max": 5, "kind": "身", "d": "所有笔的出手间隔 -8%"},
	"心": {"max": 3, "kind": "身", "d": "多两颗心，并且回满"},
}
const MAX_PENS := 4
const MAX_WORDS := 6
const BOSS_AT := 540.0
const CAP := 480              # 同屏生物上限（网页版也要跑得动）
const GCELL := 16.0

var E: Array[SV] = []
var G := {}                   # 空间网格：格子编号 → Array[SV]
var GCN := {}                  # 格子里的生物个数和重心 Vector3(sx, sy, n)
var gt2 := 0.0                # 这一局过了多久
var pens := {}                # 笔序号 → 等级（6 = 已进化）
var words := {}               # 字 → 等级
var pen_cd := [0.0, 0.0, 0.0, 0.0, 0.0]
var lv := 1
var xp := 0
var lv_q := 0                 # 还没选的升级次数
var opts: Array = []
var opt_sel := 0
var kills2 := 0
var spawn_acc := 0.0
var ev_done := {}
var sboss: SV = null
var SL: Array = []            # 刀光 {x, y, a, arc, r, t}
var BEAMS: Array = []         # 墨线 {x, y, a, len, w, t, sweep}
var BOOMS: Array = []         # 爆炸圈 {x, y, r, t}
var INKB: Array = []          # 飞行中的墨团 {x, y, tx, ty, t, T, r, dmg, split}
var FIRE: Array = []          # 地上的火 {x, y, r, t}
var ZAPS: Array = []          # 电弧 {ax, ay, bx, by, t}
var NUMS: Array = []          # 伤害数字 {x, y, v, t, c}
var blade_a := 0.0
var sweep_t := 0.0
var rain_t := 0.0
var hurt_t := 0.0
var banner := ""
var banner_t := 0.0
var banner_c := Color.WHITE
var snd_t := {}
var over_t := 0.0
var won := false
var best := {}
var slowmo := 0.0
var _fast := 1
var _shot_at := {}
var _perf_n := 0
var _perf_us := 0
var _perf_max := 0

# ======================================================================
# 启动
# ======================================================================
func _ready() -> void:
	super._ready()
	rock_layer.visible = false
	cr.clear()
	PK.clear()
	PB.clear()
	EB.clear()
	BEA.clear()
	LAMPS.clear()
	INK.clear()
	_load_best()
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--fast="):
			_fast = maxi(1, int(a.substr(7)))
	start_run()

## 试炼不需要主线的世界（省掉一秒多的生成时间）
func new_world() -> void:
	pass

func start_run() -> void:
	E.clear()
	PK.clear()
	PB.clear()
	EB.clear()
	PT.clear()
	SL.clear()
	BEAMS.clear()
	BOOMS.clear()
	INKB.clear()
	FIRE.clear()
	ZAPS.clear()
	NUMS.clear()
	toasts.clear()
	P = PlayerState.new()
	P.x = 0
	P.y = 0
	P.maxhp = 8
	P.hp = 8
	P.ch = 0
	cam_pos = Vector2.ZERO
	gt2 = 0.0
	pens = {0: 1}
	words = {}
	pen_cd = [0.3, 0.0, 0.0, 0.0, 0.0]
	lv = 1
	xp = 0
	lv_q = 0
	kills2 = 0
	spawn_acc = 0.0
	ev_done = {}
	sboss = null
	won = false
	over_t = 0.0
	slowmo = 0.0
	TIDE = 0.0
	S = "sv"
	set_banner("暗潮试炼", "撑到回声蛇出现，然后打倒它", C_GOLD)
	if touch_mode:
		toast("拖动屏幕移动 · 笔会自动出手", C_DIM, 6)
	else:
		toast("WASD 或按住鼠标移动 · 空格冲刺 · 笔会自动出手 · Esc 暂停", C_DIM, 6)

func _load_best() -> void:
	if FileAccess.file_exists("user://sanye-surv.json"):
		var f := FileAccess.open("user://sanye-surv.json", FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			best = d

func _save_best() -> void:
	var t := float(best.get("time", 0.0))
	if gt2 > t:
		best.time = gt2
	best.lv = maxi(int(best.get("lv", 0)), lv)
	best.kills = maxi(int(best.get("kills", 0)), kills2)
	if won:
		best.wins = int(best.get("wins", 0)) + 1
	if _autoplay:
		return
	var f := FileAccess.open("user://sanye-surv.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(best))

func set_banner(s: String, sub: String, c: Color) -> void:
	banner = s
	banner_c = c
	banner_t = 3.2
	if sub != "":
		toast(sub, c, 4)

func snd(n: String, pitch := 1.0, gap := 0.05) -> void:
	var t0: float = snd_t.get(n, -9.0)
	if T - t0 < gap:
		return
	snd_t[n] = T
	Sfx.play(n, pitch)

func w(c: String) -> int:
	return int(words.get(c, 0))

func plv(i: int) -> int:
	return int(pens.get(i, 0))

func evolved(i: int) -> bool:
	return plv(i) >= 6

func dmg_k() -> float:
	return 1.0 + 0.15 * w("石")

func area_k() -> float:
	return 1.0 + 0.15 * w("环")

func cd_k() -> float:
	return pow(0.92, w("炉"))

func xp_need() -> int:
	return int(5 + lv * 4.0 + pow(maxf(0.0, lv - 8.0), 1.85) * 1.6)

# ======================================================================
# 输入：触屏整块屏幕都是摇杆；键盘鼠标交给主线的处理
# ======================================================================
func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		touch_mode = true
		var pos: Vector2 = e.position / U
		if e.pressed:
			click_q = true
			tap_pos = pos
			touches[e.index] = {"kind": "move", "start": pos, "pos": pos}
		else:
			touches.erase(e.index)
		_touch_sync()
	elif e is InputEventScreenDrag:
		if touches.has(e.index):
			var t: Dictionary = touches[e.index]
			t.pos = e.position / U
			# 摇杆跟着手指走，拉太远时起点跟上来
			var d: Vector2 = t.pos - t.start
			if d.length() > 22:
				t.start = t.pos - d.normalized() * 22
		_touch_sync()
	else:
		super._input(e)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		mouse_down = false
		touches.clear()
		_touch_sync()
		if S == "sv" and not _autoplay:
			S = "pause"

func _physics_process(dt: float) -> void:
	for i in _fast:
		if _autoplay:
			_sv_bot(dt)
		var t0 := Time.get_ticks_usec()
		step(dt)
		var us := Time.get_ticks_usec() - t0
		if S == "sv":
			_perf_n += 1
			_perf_us += us
			_perf_max = maxi(_perf_max, us)

# ======================================================================
# 主循环
# ======================================================================
func step(dt: float) -> void:
	T += dt
	match S:
		"sv":
			var k := 0.35 if slowmo > 0 else 1.0
			slowmo -= dt
			sv_update(dt * k)
			if pressed(KEY_ESCAPE) or pressed(KEY_P):
				S = "pause"
		"lvl":
			upd_lvl_panel()
		"pause":
			var mp := ppointer()
			if pressed(KEY_ESCAPE) or pressed(KEY_P) or pressed(KEY_ENTER) or pressed(KEY_SPACE) or (click_q and pause_btn(0).has_point(mp)):
				S = "sv"
			elif pressed(KEY_Q) or (click_q and pause_btn(1).has_point(mp)):
				get_tree().change_scene_to_file("res://main.tscn")
		"over":
			over_t += dt
			upd_particles(dt)
			upd_fx(dt)
			var mp := ppointer()
			if over_t > 1.2:
				if pressed(KEY_ENTER) or pressed(KEY_SPACE) or pressed(KEY_R) or (click_q and pause_btn(0).has_point(mp)):
					start_run()
				elif pressed(KEY_ESCAPE) or pressed(KEY_Q) or (click_q and pause_btn(1).has_point(mp)):
					get_tree().change_scene_to_file("res://main.tscn")
	cam_pos += (Vector2(P.x, P.y) - cam_pos) * minf(1.0, dt * 8.0)
	for t in toasts:
		t.t -= dt
	toasts = toasts.filter(func(t): return t.t > 0)
	banner_t -= dt
	shk = maxf(0.0, shk - dt * 14)
	Sfx.set_duck(1.0)
	Sfx.set_tide(TIDE * 0.6)
	jp.clear()
	click_q = false
	mouse_moved = false

var _fps_t := 0.0

func sv_update(dt: float) -> void:
	gt2 += dt
	# 调试：F9 快进一分钟（测试后期怪海用）
	if pressed(KEY_F9):
		gt2 += 60.0
	_fps_t += dt
	if _fps_t > 5.0:
		_fps_t = 0.0
		print("surv t=%d fps=%d enemies=%d step_ms=%.2f" % [int(gt2), Engine.get_frames_per_second(), E.size(), _perf_us / 1000.0 / maxf(1, _perf_n)])
		_perf_us = 0
		_perf_n = 0
	hurt_t = maxf(0.0, hurt_t - dt)
	upd_events()
	upd_spawn(dt)
	sv_player(dt)
	build_grid()
	upd_enemies(dt)
	upd_pens(dt)
	upd_shots(dt)
	upd_inkb(dt)
	upd_eb(dt)
	upd_gems(dt)
	upd_fx(dt)
	upd_particles(dt)
	var tt := 1.0 if ev_tide() else 0.0
	TIDE += (tt - TIDE) * minf(1.0, dt * 1.5)
	if xp >= xp_need() and S == "sv":
		xp -= xp_need()
		lv += 1
		lv_q += 1
	if lv_q > 0 and S == "sv":
		open_lvl()

# ======================================================================
# 小克
# ======================================================================
func sv_player(dt: float) -> void:
	var ix := float(int(key(KEY_D) or key(KEY_RIGHT)) - int(key(KEY_A) or key(KEY_LEFT))) + joy.x
	var iy := float(int(key(KEY_S) or key(KEY_DOWN)) - int(key(KEY_W) or key(KEY_UP))) + joy.y
	if mouse_down and not touch_mode and absf(ix) + absf(iy) < 0.05:
		var m := get_global_mouse_position() - Vector2(P.x, P.y)
		if m.length() > 6:
			m = m.normalized()
			ix = m.x
			iy = m.y
	if _autoplay:
		ix = _bot_mv.x
		iy = _bot_mv.y
	var il := sqrt(ix * ix + iy * iy)
	if il > 1.0:
		ix /= il
		iy /= il
		il = 1.0
	P.moving = il > 0.05
	if P.moving:
		P.ax = ix / il
		P.ay = iy / il
		P.anim += dt * 8
	var spd := 78.0 * (1.0 + 0.1 * w("疾"))
	P.dash_cd -= dt
	P.dash_t -= dt
	P.inv -= dt
	if (pressed(KEY_SPACE) or pressed(KEY_SHIFT) or pressed("dash")) and P.dash_cd <= 0:
		P.vx = P.ax * 260
		P.vy = P.ay * 260
		P.dash_t = 0.18
		P.inv = maxf(P.inv, 0.3)
		P.dash_cd = 2.2
		Sfx.play("dash")
		for i in 8:
			part(P.x, P.y, -P.ax * 60 + (randf() - 0.5) * 40, -P.ay * 60 + (randf() - 0.5) * 40, 0.4, CLAY, 4)
	if P.dash_t > 0:
		P.vx *= exp(-2.0 * dt)
		P.vy *= exp(-2.0 * dt)
	else:
		var k := minf(1.0, dt * 14.0)
		P.vx += (ix * spd - P.vx) * k
		P.vy += (iy * spd - P.vy) * k
	# 引力胎把人往里拽
	for e in E:
		if e.t == "grav" and not e.dead:
			var gx := e.x - P.x
			var gy := e.y - P.y
			var gd := sqrt(gx * gx + gy * gy)
			if gd < 110 and gd > 1:
				var f := 60.0 * (1 - gd / 110)
				P.x += gx / gd * f * dt
				P.y += gy / gd * f * dt
	P.x += P.vx * dt
	P.y += P.vy * dt

func hurt(n: int, sx: float, sy: float) -> void:
	if P.inv > 0 or S != "sv":
		return
	P.hp -= n
	P.inv = 1.0
	hurt_t = 0.35
	shk = 6
	Sfx.play("hurt")
	burst(P.x, P.y, 10, CLAY, 5, 60, 0.5)
	# 挨打时把身边的东西推开一点，给自己留口气
	for e in E:
		var dx := e.x - P.x
		var dy := e.y - P.y
		var d := sqrt(dx * dx + dy * dy)
		if d < 34 and d > 0.1 and not e.elite and e != sboss:
			e.kx += dx / d * 160
			e.ky += dy / d * 160
	if P.hp <= 0:
		P.hp = 0
		end_run(false)

func end_run(win: bool) -> void:
	won = win
	S = "over"
	over_t = 0.0
	_save_best()
	if win:
		Sfx.play("page")
		toast("炉灯重新亮了起来。", C_GOLD, 6)
	else:
		Sfx.play("die")
		burst(P.x, P.y, 30, CLAY, 6, 90, 1.0)
	print("SURV END win=%s t=%.1f lv=%d kills=%d pens=%s words=%s god_saves=%d" % [win, gt2, lv, kills2, str(pens), str(words), _god_saves])

# ======================================================================
# 生物：生成、波次、事件
# ======================================================================
func hp_k() -> float:
	return 1.0 + gt2 / 80.0 + pow(gt2 / 300.0, 2.0)

func pool() -> Array:
	var m := gt2 / 60.0
	if m < 1:
		return [["moth", 6], ["hush", 2]]
	if m < 2:
		return [["moth", 5], ["hush", 3], ["folio", 2]]
	if m < 3:
		return [["moth", 4], ["hush", 2], ["folio", 2], ["leech", 3]]
	if m < 4:
		return [["moth", 4], ["leech", 3], ["hush", 2], ["chill", 2]]
	if m < 5:
		return [["moth", 3], ["leech", 3], ["chill", 3], ["icicle", 2]]
	if m < 6:
		return [["moth", 4], ["mite", 2], ["leech", 2], ["chill", 2], ["icicle", 2]]
	if m < 7:
		return [["moth", 3], ["mite", 3], ["snail", 1], ["icicle", 2], ["hush", 2]]
	if m < 8:
		return [["moth", 4], ["mite", 3], ["snail", 2], ["chill", 2], ["leech", 2]]
	return [["moth", 5], ["mite", 3], ["snail", 2], ["icicle", 3], ["leech", 2], ["chill", 2]]

func pick_type() -> String:
	var p := pool()
	var tot := 0.0
	for q in p:
		tot += q[1]
	var r := randf() * tot
	for q in p:
		r -= q[1]
		if r <= 0:
			return q[0]
	return "moth"

func ring_pos(extra := 20.0) -> Vector2:
	var R := Vector2(W, H).length() * 0.5 + extra
	var a := randf() * TAU
	# 偏向小克前进的方向，免得一直从背后追
	if P.moving and randf() < 0.5:
		a = atan2(P.ay, P.ax) + (randf() - 0.5) * 2.2
	return Vector2(P.x + cos(a) * R, P.y + sin(a) * R)

func add_e(t: String, x: float, y: float) -> SV:
	var d: Dictionary = MT[t]
	var e := SV.new()
	e.t = t
	e.x = x
	e.y = y
	e.r = d.r
	e.spd = d.sp * (0.9 + randf() * 0.2)
	e.mhp = d.hp * (hp_k() if t != "serp" else 1.0)
	e.hp = e.mhp
	e.xp = d.xp
	e.dmg = d.dmg
	e.ph = randf() * TAU
	e.cd = 1.0 + randf() * 2.0
	e.st = "chase"
	match t:
		"mothq", "grav":
			e.elite = true
		"clam":
			e.st = "open"
			e.open = 1.0
			e.na = -PI / 2
		"leech", "comet":
			e.tr = PackedFloat32Array()
	E.append(e)
	return e

func upd_spawn(dt: float) -> void:
	var rate := 1.1 + gt2 * 0.045
	# 场上太空的时候补得更快，保证一直有一片怪海
	var want := 6.0 + gt2 * 0.55 + pow(gt2 / 200.0, 2.0) * 25.0
	if E.size() < want:
		rate += (want - E.size()) * 0.6
	if sboss != null:
		rate *= 0.45
	if ev_tide():
		rate *= 0.5
	spawn_acc += rate * dt
	while spawn_acc >= 1.0:
		spawn_acc -= 1.0
		if E.size() >= CAP:
			continue
		var p := ring_pos()
		var t := pick_type()
		if t == "moth" and randf() < 0.5:
			# 蛾子成小群出现
			for i in 3 + int(gt2 / 120.0):
				if E.size() < CAP:
					add_e("moth", p.x + (randf() - 0.5) * 16, p.y + (randf() - 0.5) * 16)
		else:
			add_e(t, p.x, p.y)

func ev_tide() -> bool:
	for a in [180.0, 300.0, 420.0]:
		if gt2 >= a and gt2 < a + 22.0:
			return true
	return false

func once(id: String, at: float) -> bool:
	if gt2 >= at and not ev_done.has(id):
		ev_done[id] = true
		return true
	return false

func upd_events() -> void:
	if once("folio1", 62):
		flock(18)
		set_banner("书鳐迁徙", "一大群书鳐从旁边飞过", C_TEAL)
	if once("folio2", 235):
		flock(30)
		set_banner("书鳐迁徙", "", C_TEAL)
	if once("folio3", 470):
		flock(40)
	for i in 3:
		var at: float = [180.0, 300.0, 420.0][i]
		if once("tide%d" % i, at):
			set_banner("暗潮", "四面八方都围上来了", C_RED)
			Sfx.play("warn")
			var types: Array = [["moth"], ["chill", "moth", "icicle"], ["moth", "hush", "mite"]][i]
			encircle(types, [48, 56, 84][i])
	if once("mq1", 150):
		elite("mothq")
	if once("gv1", 270):
		elite("grav")
	if once("mq2", 360):
		elite("mothq")
		elite("mothq")
	if once("gv2", 480):
		elite("grav")
		elite("mothq")
	for at in [95.0, 255.0, 395.0, 505.0]:
		if once("comet%d" % int(at), at):
			var p := ring_pos(-10)
			var c := add_e("comet", p.x, p.y)
			c.mhp = MT.comet.hp * hp_k()
			c.hp = c.mhp
			toast("一条彗尾鱼游了过来，追上它！", C_TEAL, 4)
	for k in 12:
		var at := 40.0 + k * 48.0
		if once("clam%d" % k, at):
			var a := randf() * TAU
			var R := 70.0 + randf() * 50
			add_e("clam", P.x + cos(a) * R, P.y + sin(a) * R)
	if once("boss_warn", BOSS_AT - 6):
		set_banner("回声蛇醒了", "它在复述你走过的路", C_RED)
		Sfx.play("roar")
		shk = 8
	if once("boss", BOSS_AT):
		var p := ring_pos(-20)
		sboss = add_e("serp", p.x, p.y)
		sboss.elite = true
		sboss.ha = atan2(P.y - p.y, P.x - p.x)
		sboss.seg = []
		for i in 16:
			sboss.seg.append(Vector2(p.x, p.y))
		sboss.cd = 5.0
		sboss.burst_t = 3.0

func flock(n: int) -> void:
	var a := randf() * TAU
	var R := Vector2(W, H).length() * 0.5 + 30
	var sx := P.x + cos(a) * R
	var sy := P.y + sin(a) * R
	var dirx := -cos(a)
	var diry := -sin(a)
	for i in n:
		if E.size() >= CAP + 40:
			break
		var off := (i - n / 2.0) * 7.0
		var e := add_e("folio", sx - diry * off + dirx * (randf() * 30), sy + dirx * off + diry * (randf() * 30))
		e.st = "fly"
		e.vx = dirx * 75
		e.vy = diry * 75

func encircle(types: Array, n: int) -> void:
	var R := Vector2(W, H).length() * 0.5 + 10
	for i in n:
		var a := float(i) / n * TAU
		var e := add_e(types[i % types.size()], P.x + cos(a) * R, P.y + sin(a) * R)
		e.spd *= 0.8

func elite(t: String) -> void:
	var p := ring_pos()
	var e := add_e(t, p.x, p.y)
	e.elite = true
	toast("精英：%s 来了，打倒它会掉一张散页" % DEF[t].name, C_GOLD, 4)

# ---------- 空间网格 ----------
func gk(x: float, y: float) -> int:
	return (floori(x / GCELL) + 4096) * 8192 + (floori(y / GCELL) + 4096)

func build_grid() -> void:
	G.clear()
	GCN.clear()
	for e in E:
		if e.dead:
			continue
		var k := gk(e.x, e.y)
		var a = G.get(k)
		if a == null:
			G[k] = [e]
			GCN[k] = Vector3(e.x, e.y, 1)
		else:
			a.append(e)
			GCN[k] += Vector3(e.x, e.y, 1)

## 附近的生物（查 3×3 个格子）
func near_list(x: float, y: float) -> Array:
	var out := []
	var cx := floori(x / GCELL)
	var cy := floori(y / GCELL)
	for j in range(-1, 2):
		for i in range(-1, 2):
			var a = G.get((cx + i + 4096) * 8192 + (cy + j + 4096))
			if a != null:
				out.append_array(a)
	return out

func nearest(x: float, y: float, maxd: float, excl: SV = null) -> SV:
	var bd := maxd * maxd
	var best_e: SV = null
	for e in E:
		if e.dead or e == excl or e.t == "clam":
			continue
		var dx := e.x - x
		var dy := e.y - y
		var d := dx * dx + dy * dy
		if d < bd:
			bd = d
			best_e = e
	return best_e

## 随机挑一个屏幕上的生物（砚雷用，偏向扎堆的地方）
func crowd_target(maxd: float) -> Vector2:
	var bestk := -1
	var bestn := 0.0
	for k in GCN:
		var v: Vector3 = GCN[k]
		var c := Vector2(v.x / v.z, v.y / v.z)
		if c.distance_to(Vector2(P.x, P.y)) > maxd:
			continue
		var n := v.z + randf() * 2.0
		if n > bestn:
			bestn = n
			bestk = k
	if bestk >= 0:
		var v: Vector3 = GCN[bestk]
		return Vector2(v.x / v.z, v.y / v.z)
	var e := nearest(P.x, P.y, maxd)
	if e:
		return Vector2(e.x, e.y)
	return Vector2(P.x + P.ax * 50, P.y + P.ay * 50)

# ---------- 每只生物 ----------
func upd_enemies(dt: float) -> void:
	var far := Vector2(W, H).length() * 0.5 + 70
	var keep: Array[SV] = []
	for e in E:
		if e.dead:
			continue
		e.age += dt
		e.flash -= dt
		e.blade_cd -= dt
		e.fire_cd -= dt
		e.slow -= dt
		if e.burn_t > 0:
			e.burn_t -= dt
			e.burn += e.burn_dps * dt
			if e.burn >= 1.0:
				var b := floorf(e.burn)
				e.burn -= b
				dmg_e(e, b, e.x, e.y, 0.0, false, false)
				if randf() < 0.3:
					part(e.x, e.y - 2, (randf() - 0.5) * 10, -20, 0.4, EMBER, 5, true)
				if e.dead:
					continue
		var dx := P.x - e.x
		var dy := P.y - e.y
		var d := sqrt(dx * dx + dy * dy)
		var ux := dx / maxf(d, 0.01)
		var uy := dy / maxf(d, 0.01)
		var sk := 0.5 if e.slow > 0 else 1.0
		var vx := 0.0
		var vy := 0.0
		match e.t:
			"serp":
				upd_boss(e, dt, d, ux, uy)
				keep.append(e)
				continue
			"folio":
				if e.st == "fly":
					vx = e.vx
					vy = e.vy
					if d > far + 60:
						e.dead = true
						continue
				else:
					var wob := sin(e.age * 3 + e.ph) * 0.5
					vx = (ux - uy * wob) * e.spd
					vy = (uy + ux * wob) * e.spd
					e.vx = vx
					e.vy = vy
			"leech":
				e.cd -= dt
				if e.st == "chase":
					vx = ux * e.spd
					vy = uy * e.spd
					if d < 70 and e.cd <= 0:
						e.st = "wind"
						e.tm = 0.5
				elif e.st == "wind":
					e.tm -= dt
					if e.tm <= 0:
						e.st = "lunge"
						e.tm = 0.45
						e.vx = ux * 190
						e.vy = uy * 190
				else:
					e.tm -= dt
					vx = e.vx
					vy = e.vy
					if e.tm <= 0:
						e.st = "chase"
						e.cd = 2.5
				_trail(e, dt, 8)
			"icicle":
				if e.st == "chase":
					e.ang = atan2(uy, ux)
					vx = ux * e.spd
					vy = uy * e.spd
					e.cd -= dt
					if d < 120 and e.cd <= 0:
						e.st = "aim"
						e.tm = 0.8
				elif e.st == "aim":
					e.tm -= dt
					if e.tm > 0.35:
						e.ang = atan2(uy, ux)
					if e.tm <= 0:
						e.st = "dash"
						e.tm = 0.9
				else:
					e.tm -= dt
					vx = cos(e.ang) * 230
					vy = sin(e.ang) * 230
					if randf() < 0.5:
						part(e.x, e.y, 0, 0, 0.3, ICE, 5)
					if e.tm <= 0:
						e.st = "chase"
						e.cd = 2.5 + randf()
			"mite":
				var ta := atan2(uy, ux)
				e.ang = rotate_toward(e.ang, ta, dt * 1.6)
				vx = ux * e.spd
				vy = uy * e.spd
			"snail":
				e.ang = atan2(uy, ux)
				e.w = 1.0 if ux >= 0 else -1.0
				vx = ux * e.spd
				vy = uy * e.spd
			"mothq":
				vx = ux * e.spd
				vy = uy * e.spd
				e.cd -= dt
				if e.cd <= 0 and E.size() < CAP + 30:
					e.cd = 1.4
					for i in 2:
						var m := add_e("moth", e.x + (randf() - 0.5) * 8, e.y + (randf() - 0.5) * 8)
						m.xp = 0
			"grav":
				vx = ux * e.spd
				vy = uy * e.spd
			"comet":
				var a := atan2(-uy, -ux) + sin(e.age * 1.3) * 0.9
				vx = cos(a) * e.spd
				vy = sin(a) * e.spd
				e.vx = vx
				e.vy = vy
				_trail(e, dt, 12)
				if e.age > 30 and d > far:
					e.dead = true
					toast("彗尾鱼游走了……", C_DIM, 2)
					continue
			"clam":
				pass
			"chill":
				e.sp = clampf(1.0 - d / 60.0, 0.0, 1.0)
				var wob := sin(e.age * 2 + e.ph) * 0.6
				vx = (ux - uy * wob) * e.spd
				vy = (uy + ux * wob) * e.spd
			_:
				var wob := sin(e.age * 2.5 + e.ph) * 0.35
				vx = (ux - uy * wob) * e.spd
				vy = (uy + ux * wob) * e.spd
		# 挤一挤：从自己所在格子的重心往外推
		var k := gk(e.x, e.y)
		var gc = GCN.get(k)
		if gc != null and gc.z > 1.5 and e.t != "clam":
			var cx: float = gc.x / gc.z
			var cy: float = gc.y / gc.z
			var px := e.x - cx
			var py := e.y - cy
			var pl := sqrt(px * px + py * py)
			if pl < 0.01:
				px = randf() - 0.5
				py = randf() - 0.5
				pl = 0.7
			var f := minf(60.0, (gc.z - 1.0) * 9.0)
			vx += px / pl * f
			vy += py / pl * f
		e.x += (vx * sk + e.kx) * dt
		e.y += (vy * sk + e.ky) * dt
		var kd := exp(-9.0 * dt)
		e.kx *= kd
		e.ky *= kd
		# 碰到小克
		if e.dmg > 0 and d < e.r + 3.5:
			hurt(e.dmg, e.x, e.y)
		# 落在屏幕外太远的，挪到前面去（不浪费）
		if d > far and e.st != "fly" and not e.elite and e.t != "comet":
			e.gone_t += dt
			if e.gone_t > 1.5:
				e.gone_t = 0.0
				var p := ring_pos()
				e.x = p.x
				e.y = p.y
		elif d > far * 2.5 and e.t == "clam":
			e.dead = true
			continue
		else:
			e.gone_t = 0.0
		keep.append(e)
	E = keep

func _trail(e: SV, dt: float, n: int) -> void:
	e.tr_t -= dt
	if e.tr_t > 0:
		return
	e.tr_t = 0.04
	e.tr.insert(0, e.y)
	e.tr.insert(0, e.x)
	if e.tr.size() > n * 2:
		e.tr.resize(n * 2)

# ---------- 回声蛇 ----------
func upd_boss(e: SV, dt: float, d: float, ux: float, uy: float) -> void:
	var rage := e.hp < e.mhp * 0.5
	e.cd -= dt
	e.burst_t -= dt
	var sp := e.spd * (1.25 if rage else 1.0) * (0.6 if e.slow > 0 else 1.0)
	match e.st:
		"chase":
			e.ha = rotate_toward(e.ha, atan2(uy, ux), dt * (2.6 if rage else 2.0))
			e.vx = cos(e.ha) * sp
			e.vy = sin(e.ha) * sp
			if e.cd <= 0 and d < 170:
				e.st = "aim"
				e.tm = 0.9
				Sfx.play("warn", 1.4)
			if e.burst_t <= 0:
				e.burst_t = 2.6 if rage else 3.6
				var n := 16 if rage else 12
				for i in n:
					var a := float(i) / n * TAU + e.age
					add_eb(e.x, e.y, cos(a) * 58, sin(a) * 58, 5.0, SERP)
				Sfx.play("note", 0.7)
		"aim":
			e.tm -= dt
			e.vx *= exp(-6 * dt)
			e.vy *= exp(-6 * dt)
			if e.tm > 0.3:
				e.ha = atan2(uy, ux)
			if e.tm <= 0:
				e.st = "charge"
				e.tm = 1.0
				shk = 5
				Sfx.play("roar", 1.5)
		"charge":
			e.tm -= dt
			e.vx = cos(e.ha) * 250
			e.vy = sin(e.ha) * 250
			if randf() < 0.6:
				part(e.x, e.y, 0, 0, 0.5, SERP, 5, true)
			if e.tm <= 0:
				e.st = "chase"
				e.cd = 4.5 if rage else 6.0
	e.x += e.vx * dt + e.kx * dt
	e.y += e.vy * dt + e.ky * dt
	e.kx *= exp(-9 * dt)
	e.ky *= exp(-9 * dt)
	# 身子一节跟一节
	var prev := Vector2(e.x, e.y)
	for i in e.seg.size():
		var s := e.seg[i]
		var v := s - prev
		var L := v.length()
		if L > 5.0:
			s = prev + v / L * 5.0
		e.seg[i] = s
		prev = s
		if s.distance_to(Vector2(P.x, P.y)) < 7:
			hurt(1, s.x, s.y)
	if d < e.r + 4:
		hurt(e.dmg, e.x, e.y)
	# 跑太远就从前面绕回来
	if d > Vector2(W, H).length() * 0.5 + 140:
		var p := ring_pos()
		e.x = p.x
		e.y = p.y
		for i in e.seg.size():
			e.seg[i] = Vector2(p.x, p.y)

func upd_eb(dt: float) -> void:
	var keep: Array[EBullet] = []
	for b in EB:
		b.life -= dt
		b.x += b.vx * dt
		b.y += b.vy * dt
		if b.life <= 0:
			continue
		if absf(b.x - P.x) < 3.5 and absf(b.y - P.y) < 3.5:
			hurt(1, b.x, b.y)
			continue
		keep.append(b)
	EB = keep

# ======================================================================
# 伤害
# ======================================================================
## 打一只生物。proc = 能不能触发火/霜/连这些附加效果
func dmg_e(e: SV, d: float, sx: float, sy: float, kb := 40.0, proc := true, crit_ok := true) -> void:
	if e.dead:
		return
	var crit := false
	if crit_ok and w("暴") > 0 and randf() < 0.1 * w("暴"):
		d *= 2.5
		crit = true
	if e.t == "mite":
		# 镜螨的正面打不动
		var fx := cos(e.ang)
		var fy := sin(e.ang)
		var vx := sx - e.x
		var vy := sy - e.y
		var vl := maxf(0.01, sqrt(vx * vx + vy * vy))
		if (vx * fx + vy * fy) / vl > 0.35:
			d *= 0.35
			if randf() < 0.3:
				part(e.x + fx * 4, e.y + fy * 4, fx * 30, fy * 30, 0.3, MIRROR, 6, true)
	e.hp -= d
	if crit_ok:
		e.flash = 0.08
	if kb > 0 and not e.elite:
		var kx := e.x - sx
		var ky := e.y - sy
		var kl := maxf(0.01, sqrt(kx * kx + ky * ky))
		e.kx += kx / kl * kb
		e.ky += ky / kl * kb
	if NUMS.size() < 60 and crit_ok and d >= 1.0:
		NUMS.append({"x": e.x + (randf() - 0.5) * 4, "y": e.y - e.r - 2, "v": roundi(d), "t": 0.6, "c": crit})
	if proc:
		if w("火") > 0:
			e.burn_t = 3.0
			e.burn_dps = maxf(e.burn_dps, 4.0 * w("火") * dmg_k())
		if w("霜") > 0:
			e.slow = 0.6 + 0.5 * w("霜")
		if w("连") > 0 and randf() < 0.12 * w("连"):
			chain(e, d * 0.6, 2)
	if e.hp <= 0:
		kill_e(e)
	else:
		snd("hit", 0.9 + randf() * 0.3, 0.06)

func chain(src: SV, d: float, n: int) -> void:
	var cur := src
	var hit := [src]
	for i in n:
		var best_e: SV = null
		var bd := 50.0 * 50.0
		for e: SV in near_list(cur.x, cur.y) + near_list(cur.x + 30, cur.y) + near_list(cur.x - 30, cur.y):
			if e.dead or hit.has(e):
				continue
			var dd: float = (e.x - cur.x) * (e.x - cur.x) + (e.y - cur.y) * (e.y - cur.y)
			if dd < bd:
				bd = dd
				best_e = e
		if best_e == null:
			break
		ZAPS.append({"ax": cur.x, "ay": cur.y, "bx": best_e.x, "by": best_e.y, "t": 0.18})
		hit.append(best_e)
		dmg_e(best_e, d, cur.x, cur.y, 20.0, false, false)
		cur = best_e

func kill_e(e: SV) -> void:
	e.dead = true
	kills2 += 1
	var m: int = DEF[e.t].m if DEF.has(e.t) else PAPER
	burst(e.x, e.y, 6 if E.size() < 200 else 3, m, 5, 45, 0.45)
	snd("kill", 0.8 + randf() * 0.5, 0.045)
	if e.xp > 0:
		drop_gem(e.x, e.y, e.xp)
	if randf() < 0.022:
		add_pick(e.x, e.y, "ember")
	match e.t:
		"clam":
			add_pick(e.x, e.y, "ember")
			if randf() < 0.5:
				add_pick(e.x, e.y, "kiln")
			Sfx.play("ember")
		"comet":
			for i in 14:
				drop_gem(e.x + (randf() - 0.5) * 20, e.y + (randf() - 0.5) * 20, 6)
			add_pick(e.x, e.y, "ember")
			add_pick(e.x, e.y, "kiln")
			toast("抓到彗尾鱼！", C_TEAL, 3)
		"mothq", "grav":
			add_pick(e.x, e.y, "page")
			for i in 6:
				drop_gem(e.x + (randf() - 0.5) * 16, e.y + (randf() - 0.5) * 16, 5)
			shk = 6
			Sfx.play("buy")
		"serp":
			shk = 14
			slowmo = 1.6
			burst(e.x, e.y, 60, SERP, 6, 120, 1.4)
			for s in e.seg:
				burst(s.x, s.y, 6, SERP, 5, 60, 0.8)
			sboss = null
			# 屏幕上剩下的都散掉
			for o in E:
				if not o.dead and o != e:
					o.dead = true
					burst(o.x, o.y, 3, DEF[o.t].m if DEF.has(o.t) else PAPER, 5, 40, 0.5)
			set_banner("回声蛇安静了", "", C_GOLD)
			get_tree().create_timer(2.2).timeout.connect(func(): if S == "sv": end_run(true))

func drop_gem(x: float, y: float, v: int) -> void:
	if PK.size() > 240:
		# 太多了就并进一颗离得远的
		var p: Pick = PK[randi() % PK.size()]
		if p.k == "dust":
			p.v += v
			return
	add_pick(x, y, "dust", 0, 0, v)

# ======================================================================
# 笔
# ======================================================================
func upd_pens(dt: float) -> void:
	for i in 5:
		var l := plv(i)
		if l <= 0:
			continue
		pen_cd[i] -= dt
		if pen_cd[i] > 0:
			continue
		match i:
			0: pen_cd[i] = fire_brush(l)
			1: pen_cd[i] = fire_broom(l)
			2: pen_cd[i] = fire_knife(l)
			3: pen_cd[i] = fire_inkb(l)
			4: pen_cd[i] = fire_line(l)
	# 回环：绕身刻刀
	if evolved(2):
		blade_a += dt * 4.2
		var R := 26.0 * area_k()
		for k in 3:
			var a := blade_a + k * TAU / 3
			var bx := P.x + cos(a) * R
			var by := P.y + sin(a) * R
			for e: SV in near_list(bx, by):
				if e.dead or e.blade_cd > 0:
					continue
				if absf(e.x - bx) < e.r + 5 and absf(e.y - by) < e.r + 5:
					e.blade_cd = 0.35
					dmg_e(e, 22.0 * dmg_k(), P.x, P.y, 60.0)
	# 燎原：地上的火
	for f in FIRE:
		for e: SV in near_list(f.x, f.y):
			if e.dead or e.fire_cd > 0:
				continue
			if (e.x - f.x) * (e.x - f.x) + (e.y - f.y) * (e.y - f.y) < f.r * f.r:
				e.fire_cd = 0.4
				dmg_e(e, 7.0 * dmg_k(), e.x, e.y, 0.0, false, false)
				e.burn_t = 2.0
				e.burn_dps = maxf(e.burn_dps, 6.0 * dmg_k())
	# 暴雨：每两秒泼一圈
	if evolved(0):
		rain_t -= dt
		if rain_t <= 0:
			rain_t = 2.0
			for k in 20:
				var a := float(k) / 20.0 * TAU
				shot(P.x, P.y, a, 11.0 * dmg_k(), 0)
	# 穿针：十字墨线扫一圈
	if evolved(4):
		sweep_t -= dt
		if sweep_t <= 0:
			sweep_t = 3.2
			for k in 4:
				BEAMS.append({"x": P.x, "y": P.y, "a": k * PI / 2, "len": 210.0, "w": 5.0 * area_k(), "t": 1.3, "max": 1.3, "sweep": true, "dmg": 26.0 * dmg_k(), "hit": {}})
			Sfx.play("roar", 2.2)

func target_angle(maxd := 190.0) -> float:
	var e := nearest(P.x, P.y, maxd)
	if e:
		return atan2(e.y - P.y, e.x - P.x)
	return atan2(P.ay, P.ax)

func shot(x: float, y: float, a: float, dmg: float, kind: int) -> Bullet:
	var b := Bullet.new()
	var spk := 1.0 + 0.15 * w("针")
	b.x = x
	b.y = y
	b.sp = (230.0 if kind == 0 else 200.0) * spk
	b.vx = cos(a) * b.sp
	b.vy = sin(a) * b.sp
	b.life = (0.85 if kind == 0 else 0.28 + 0.06 * mini(plv(1), 5)) * spk
	b.max_life = b.life
	b.dmg = 0
	b.crit = dmg
	b.pierce = w("穿") + (1 if kind == 1 else 0)
	b.home = 0.0 if kind == 1 else 3.0 * w("寻")
	b.split = w("裂")
	b.small = kind == 1
	b.burn = 1.0 if kind == 1 and evolved(1) else 0.0
	b.mat = EMBER if b.burn > 0 else (CLAY if kind == 0 else GOLD)
	b.hit = []
	PB.append(b)
	return b

func fire_brush(l: int) -> float:
	var n := 1 + (1 if l >= 2 else 0) + (1 if l >= 4 else 0) + w("雨")
	var dmg := 8.0 * (1.4 if l >= 3 else 1.0) * (1.4 if l >= 5 else 1.0) * dmg_k()
	# 每发找不同的目标
	var tg: Array = []
	for e in E:
		if e.dead or e.t == "clam":
			continue
		var dd := (e.x - P.x) * (e.x - P.x) + (e.y - P.y) * (e.y - P.y)
		if dd < 200 * 200:
			tg.append([dd, e])
	tg.sort_custom(func(a, b): return a[0] < b[0])
	for k in n:
		var a := atan2(P.ay, P.ax) + (k - n / 2.0) * 0.15
		if not tg.is_empty():
			var e: SV = tg[k % tg.size()][1]
			a = atan2(e.y - P.y, e.x - P.x) + (randf() - 0.5) * 0.06
		shot(P.x, P.y, a, dmg, 0)
	snd("shoot", 1.0 + randf() * 0.2, 0.08)
	var cd := (0.5 if l < 5 else 0.4) * cd_k()
	if evolved(0):
		cd = 0.16 * cd_k()
	return cd

func fire_broom(l: int) -> float:
	var n := 5 + (2 if l >= 2 else 0) + (2 if l >= 4 else 0) + w("雨") * 2
	var dmg := 6.0 * (1.4 if l >= 3 else 1.0) * (1.4 if l >= 5 else 1.0) * dmg_k()
	var a0 := target_angle(120)
	for k in n:
		var a := a0 + (float(k) / maxf(1, n - 1) - 0.5) * 1.1 + (randf() - 0.5) * 0.08
		var b := shot(P.x, P.y, a, dmg, 1)
		b.sp *= 0.85 + randf() * 0.3
		b.vx = cos(a) * b.sp
		b.vy = sin(a) * b.sp
	snd("dash", 1.6, 0.1)
	return (1.15 if l < 5 else 0.85) * cd_k()

func fire_knife(l: int) -> float:
	var R := (34.0 + (8 if l >= 2 else 0) + (8 if l >= 5 else 0)) * area_k()
	var dmg := 20.0 * (1.4 if l >= 4 else 1.0) * dmg_k()
	var a0 := target_angle(R + 40)
	var dirs := [a0]
	if l >= 3:
		dirs.append(a0 + PI)
	if evolved(2):
		dirs = [a0, a0 + PI * 2 / 3, a0 + PI * 4 / 3]
	for a in dirs:
		slash_at(a, R, dmg, 1.25)
	snd("hit", 0.6, 0.1)
	return (1.25 if l < 5 else 0.95) * cd_k()

func slash_at(a: float, R: float, dmg: float, arc: float) -> void:
	SL.append({"x": P.x, "y": P.y, "a": a, "arc": arc, "r": R, "t": 0.16})
	for e in E:
		if e.dead:
			continue
		var dx := e.x - P.x
		var dy := e.y - P.y
		var d := sqrt(dx * dx + dy * dy)
		if d > R + e.r:
			continue
		var da := absf(angle_difference(a, atan2(dy, dx)))
		if da < arc * 0.5 or d < 8:
			dmg_e(e, dmg, P.x, P.y, 90.0)
	# 刻刀能劈开敌人的子弹
	var keep: Array[EBullet] = []
	for b in EB:
		var dx := b.x - P.x
		var dy := b.y - P.y
		if dx * dx + dy * dy < R * R and absf(angle_difference(a, atan2(dy, dx))) < arc * 0.5:
			burst(b.x, b.y, 3, PAPER, 6, 30, 0.3)
			continue
		keep.append(b)
	EB = keep

func fire_inkb(l: int) -> float:
	var n := 1 + (1 if l >= 2 else 0) + (1 if l >= 4 else 0) + w("雨")
	var r := (24.0 + (8 if l >= 3 else 0)) * area_k()
	var dmg := 18.0 * (1.5 if l >= 5 else 1.0) * dmg_k()
	for k in n:
		var t := crowd_target(170)
		t += Vector2((randf() - 0.5) * 30, (randf() - 0.5) * 30) * (1.0 if k > 0 else 0.3)
		var fl := 0.45 + Vector2(P.x, P.y).distance_to(t) / 400.0
		INKB.append({"x": P.x, "y": P.y, "sx": P.x, "sy": P.y, "tx": t.x, "ty": t.y, "t": 0.0, "T": fl, "r": r, "dmg": dmg, "split": evolved(3)})
	return 1.6 * cd_k()

func upd_inkb(dt: float) -> void:
	var keep := []
	for b in INKB:
		b.t += dt
		var k: float = minf(1.0, b.t / b.T)
		b.x = lerpf(b.sx, b.tx, k)
		b.y = lerpf(b.sy, b.ty, k) - sin(k * PI) * 26.0
		if k >= 1.0:
			boom(b.tx, b.ty, b.r, b.dmg)
			if b.split:
				for q in 4:
					var a := q * PI / 2 + PI / 4
					keep.append({"x": b.tx, "y": b.ty, "sx": b.tx, "sy": b.ty, "tx": b.tx + cos(a) * b.r * 1.3, "ty": b.ty + sin(a) * b.r * 1.3, "t": 0.0, "T": 0.3, "r": b.r * 0.6, "dmg": b.dmg * 0.6, "split": false})
			continue
		keep.append(b)
	INKB = keep

func boom(x: float, y: float, r: float, dmg: float) -> void:
	BOOMS.append({"x": x, "y": y, "r": r, "t": 0.3})
	snd("rock", 0.6 + randf() * 0.2, 0.06)
	shk = maxf(shk, 2.5)
	for i in 8:
		var a := randf() * TAU
		part(x + cos(a) * r * 0.5, y + sin(a) * r * 0.5, cos(a) * 40, sin(a) * 40, 0.5, GRAV, 4)
	for e in E:
		if e.dead:
			continue
		var dx := e.x - x
		var dy := e.y - y
		if dx * dx + dy * dy < (r + e.r) * (r + e.r):
			dmg_e(e, dmg, x, y, 70.0)

func fire_line(l: int) -> float:
	var a := target_angle(220)
	var wd := (4.0 + (2.0 if l >= 2 else 0.0)) * area_k()
	var dmg := 24.0 * (1.3 if l >= 2 else 1.0) * (1.5 if l >= 5 else 1.0) * dmg_k()
	var dirs := [a]
	if l >= 3:
		dirs.append(a + PI)
	for d in dirs:
		BEAMS.append({"x": P.x, "y": P.y, "a": d, "len": 230.0, "w": wd, "t": 0.22, "max": 0.22, "sweep": false, "dmg": dmg, "hit": {}})
	Sfx.play("ping", 0.7)
	shk = maxf(shk, 2.0)
	return (2.3 if l < 4 else 1.7) * cd_k()

func upd_beams(dt: float) -> void:
	var keep := []
	for b in BEAMS:
		b.t -= dt
		if b.t <= 0:
			continue
		b.x = P.x
		b.y = P.y
		if b.sweep:
			b.a += dt * TAU / 1.3 * 0.5
		var fx := cos(b.a)
		var fy := sin(b.a)
		var hit: Dictionary = b.hit
		for e in E:
			if e.dead:
				continue
			var dx: float = e.x - b.x
			var dy: float = e.y - b.y
			var along := dx * fx + dy * fy
			if along < 0 or along > b.len:
				continue
			var side := absf(-dx * fy + dy * fx)
			if side > b.w + e.r:
				continue
			var last: float = hit.get(e, -9.0)
			if T - last < (0.3 if b.sweep else 99.0):
				continue
			hit[e] = T
			dmg_e(e, b.dmg, b.x, b.y, 50.0)
		keep.append(b)
	BEAMS = keep

# ---------- 字弹 ----------
func upd_shots(dt: float) -> void:
	var keep: Array[Bullet] = []
	for b in PB:
		b.life -= dt
		if b.life <= 0:
			if b.burn > 0 and FIRE.size() < 40:
				FIRE.append({"x": b.x, "y": b.y, "r": 9.0 * area_k(), "t": 2.6})
			continue
		if b.home > 0:
			var e := nearest(b.x, b.y, 70)
			if e:
				var a := atan2(b.vy, b.vx)
				a = rotate_toward(a, atan2(e.y - b.y, e.x - b.x), b.home * dt)
				b.vx = cos(a) * b.sp
				b.vy = sin(a) * b.sp
		b.x += b.vx * dt
		b.y += b.vy * dt
		var dead := false
		for e: SV in near_list(b.x, b.y):
			if e.dead or b.hit.has(e):
				continue
			var rr := e.r + (2.5 if not b.small else 2.0)
			if absf(e.x - b.x) > rr or absf(e.y - b.y) > rr:
				continue
			b.hit.append(e)
			dmg_e(e, b.crit, b.x, b.y, 35.0)
			if b.split > 0 and not b.small and randf() < 0.2 * b.split:
				var a := atan2(b.vy, b.vx)
				for s in [-0.6, 0.6]:
					var nb := shot(b.x, b.y, a + s, b.crit * 0.5, 0)
					nb.small = true
					nb.split = 0
					nb.life = 0.35
					nb.hit = [e]
			if b.burn > 0 and FIRE.size() < 40:
				FIRE.append({"x": b.x, "y": b.y, "r": 9.0 * area_k(), "t": 2.6})
				b.burn = 0.0
			if b.pierce > 0:
				b.pierce -= 1
			else:
				dead = true
				break
		if not dead:
			keep.append(b)
	PB = keep
	upd_beams(dt)

# ======================================================================
# 掉落：页尘（经验）、余烬（回心）、炉心（清屏）、散页（宝箱）
# ======================================================================
func mag_r() -> float:
	return 26.0 * (1.0 + 0.5 * w("重"))

func upd_gems(dt: float) -> void:
	var keep: Array[Pick] = []
	var mr := mag_r()
	for p in PK:
		p.age += dt
		var dx := P.x - p.x
		var dy := P.y - p.y
		var d := sqrt(dx * dx + dy * dy)
		var pull := d < mr or p.gold
		# 引力胎会把页尘也吸过去
		if not pull:
			p.vx *= exp(-4 * dt)
			p.vy *= exp(-4 * dt)
		else:
			var sp := 120.0 + p.age * 40.0 if not p.gold else 260.0
			p.vx += (dx / maxf(d, 0.1) * sp - p.vx) * minf(1.0, dt * 8)
			p.vy += (dy / maxf(d, 0.1) * sp - p.vy) * minf(1.0, dt * 8)
		p.x += p.vx * dt
		p.y += p.vy * dt
		if d < 5:
			collect(p)
			continue
		if d > 600 and p.k == "dust":
			continue
		keep.append(p)
	PK = keep

func collect(p: Pick) -> void:
	match p.k:
		"dust":
			xp += p.v
			chime_i = (chime_i + 1) % 8
			snd("dust%d" % chime_i, 1.0, 0.035)
		"ember":
			if P.hp < P.maxhp:
				P.hp += 1
				toast("余烬暖了一下陶心 +1", C_CLAY, 1.5)
			Sfx.play("ember")
		"kiln":
			kiln_blast()
		"page":
			open_page()

## 炉心：一圈热浪，屏幕上的小东西全散掉，页尘都吸过来
func kiln_blast() -> void:
	Sfx.play("roar", 1.2)
	shk = 10
	BOOMS.append({"x": P.x, "y": P.y, "r": Vector2(W, H).length() * 0.5, "t": 0.6})
	for e in E:
		if e.dead:
			continue
		if absf(e.x - P.x) < W * 0.6 and absf(e.y - P.y) < H * 0.6:
			if e.elite or e.t == "serp":
				dmg_e(e, 60.0 * dmg_k(), P.x, P.y, 0.0, false, false)
			elif e.t != "clam" and e.t != "comet":
				kill_e(e)
	for p in PK:
		if p.k == "dust":
			p.gold = true
	set_banner("炉心", "一圈热浪扫过去，页尘全飞过来", C_GOLD)

## 散页（精英掉的）：能进化就进化，否则随机给几次升级
func open_page() -> void:
	Sfx.play("page")
	shk = 4
	var ev := evo_ready()
	if ev >= 0:
		do_evo(ev)
		return
	var n := 1 + (1 if randf() < 0.5 else 0) + (1 if randf() < 0.2 else 0)
	var got := []
	for i in n:
		var c := owned_upgrades()
		if c.is_empty():
			break
		var o: Dictionary = c[randi() % c.size()]
		apply_opt(o)
		got.append(opt_title(o, true))
	if got.is_empty():
		P.hp = P.maxhp
		set_banner("散页", "陶心回满了", C_GOLD)
	else:
		set_banner("散页", "、".join(got), C_GOLD)

func owned_upgrades() -> Array:
	var c := []
	for i in pens:
		if plv(i) < 5:
			c.append({"k": "pen", "i": i})
	for s in words:
		if w(s) < SW[s].max:
			c.append({"k": "word", "c": s})
	return c

# ======================================================================
# 升级三选一
# ======================================================================
func evo_ready() -> int:
	for i in pens:
		if plv(i) == 5 and w(SPENS[i].evo) > 0:
			return i
	return -1

func gen_opts() -> Array:
	var out := []
	var ev := evo_ready()
	if ev >= 0:
		out.append({"k": "evo", "i": ev})
	var c := []   # [选项, 权重]
	for i in 5:
		var l := plv(i)
		if l > 0 and l < 5:
			c.append([{"k": "pen", "i": i}, 10.0])
		elif l == 0 and pens.size() < MAX_PENS:
			c.append([{"k": "pen", "i": i}, 7.0])
	for s in SW:
		var l := w(s)
		if l > 0 and l < SW[s].max:
			c.append([{"k": "word", "c": s}, 8.0])
		elif l == 0 and words.size() < MAX_WORDS:
			var wt := 5.0
			# 手上有的笔的搭档字更容易出现
			for i in pens:
				if SPENS[i].evo == s:
					wt = 9.0
			c.append([{"k": "word", "c": s}, wt])
	while out.size() < 3 and not c.is_empty():
		var tot := 0.0
		for q in c:
			tot += q[1]
		var r := randf() * tot
		for j in c.size():
			r -= c[j][1]
			if r <= 0:
				out.append(c[j][0])
				c.remove_at(j)
				break
	if out.is_empty():
		out.append({"k": "heal"})
		out.append({"k": "dust"})
	return out

func open_lvl() -> void:
	opts = gen_opts()
	opt_sel = 0
	S = "lvl"
	Sfx.play("buy")

func opt_title(o: Dictionary, short := false) -> String:
	match o.k:
		"pen":
			var l := plv(o.i)
			if short:
				return "%s Lv%d" % [SPENS[o.i].name, l]
			return "%s%s" % [SPENS[o.i].name, " · 新笔" if l == 0 else " Lv%d→%d" % [l, l + 1]]
		"word":
			var l := w(o.c)
			if short:
				return "「%s」Lv%d" % [o.c, l]
			return "「%s」%s" % [o.c, " · 新字" if l == 0 else " Lv%d→%d" % [l, l + 1]]
		"evo":
			return "成词「%s」" % SPENS[o.i].ename
		"heal":
			return "余烬"
		"dust":
			return "一把页尘"
	return ""

func opt_desc(o: Dictionary) -> String:
	match o.k:
		"pen":
			var l := plv(o.i)
			var s: String = SPENS[o.i].lv[l]
			if l == 4 or l == 0:
				s += "\n满级后配「%s」能进化成「%s」" % [SPENS[o.i].evo, SPENS[o.i].ename]
			return s
		"word":
			var s: String = SW[o.c].d
			for i in pens:
				if SPENS[i].evo == o.c and not evolved(i):
					s += "\n%s满级后能成词「%s」" % [SPENS[i].name, SPENS[i].ename]
			return s
		"evo":
			return "%s +「%s」\n%s" % [SPENS[o.i].name, SPENS[o.i].evo, SPENS[o.i].edesc]
		"heal":
			return "回满陶心"
		"dust":
			return "立刻多拿一截经验"
	return ""

func apply_opt(o: Dictionary) -> void:
	match o.k:
		"pen":
			pens[o.i] = plv(o.i) + 1
		"word":
			words[o.c] = w(o.c) + 1
			if o.c == "心":
				P.maxhp += 2
				P.hp = P.maxhp
		"evo":
			do_evo(o.i)
		"heal":
			P.hp = P.maxhp
		"dust":
			xp += xp_need() / 2

func do_evo(i: int) -> void:
	pens[i] = 6
	Sfx.play("page")
	shk = 8
	slowmo = 0.6
	burst(P.x, P.y, 40, GOLD, 6, 100, 1.0)
	set_banner("成词「%s」" % SPENS[i].ename, SPENS[i].edesc, C_GOLD)

func card_rect(i: int) -> Rect2:
	var n := opts.size()
	var cw := 94.0
	var gap := 8.0
	var x0 := 160.0 - (n * cw + (n - 1) * gap) / 2.0
	return Rect2(x0 + i * (cw + gap), 46, cw, 104)

func pause_btn(i: int) -> Rect2:
	return Rect2(88 + i * 76, 140, 68, 17)

func upd_lvl_panel() -> void:
	var n := opts.size()
	var pick := -1
	for i in n:
		if pressed(KEY_1 + i) or pressed(KEY_KP_1 + i):
			pick = i
	if pressed(KEY_A) or pressed(KEY_LEFT):
		opt_sel = (opt_sel + n - 1) % n
	if pressed(KEY_D) or pressed(KEY_RIGHT):
		opt_sel = (opt_sel + 1) % n
	if pressed(KEY_ENTER) or pressed(KEY_KP_ENTER) or pressed(KEY_SPACE):
		pick = opt_sel
	var mp := ppointer()
	for i in n:
		if card_rect(i).has_point(mp):
			if mouse_moved:
				opt_sel = i
			if click_q:
				pick = i
	if _autoplay:
		_lvl_wait += get_physics_process_delta_time()
		if _lvl_wait < 0.4:
			if not _shot_at.has("lvl") or (not _shot_at.has("evo") and opts[0].k == "evo"):
				var nm := "evo" if opts[0].k == "evo" else "lvl"
				_shot_at[nm] = true
				_shot(nm)
			return
		_lvl_wait = 0.0
		pick = _bot_pick()
	if pick >= 0:
		apply_opt(opts[pick])
		lv_q -= 1
		Sfx.play("eat")
		if lv_q > 0:
			opts = gen_opts()
			opt_sel = 0
		else:
			S = "sv"
			P.inv = maxf(P.inv, 0.5)

# ======================================================================
# 一闪而过的效果
# ======================================================================
func upd_fx(dt: float) -> void:
	for a in [SL, BOOMS, ZAPS, FIRE]:
		for f in a:
			f.t -= dt
	SL = SL.filter(func(f): return f.t > 0)
	BOOMS = BOOMS.filter(func(f): return f.t > 0)
	ZAPS = ZAPS.filter(func(f): return f.t > 0)
	FIRE = FIRE.filter(func(f): return f.t > 0)
	for n in NUMS:
		n.t -= dt
		n.y -= dt * 18
	NUMS = NUMS.filter(func(f): return f.t > 0)
	for f in FIRE:
		if randf() < 0.25:
			part(f.x + (randf() - 0.5) * f.r * 1.6, f.y + (randf() - 0.5) * f.r, (randf() - 0.5) * 6, -18 - randf() * 10, 0.5, EMBER if randf() < 0.7 else GOLD, 5, true)

# ======================================================================
# 画面
# ======================================================================
func shift_at(_x: float, _y: float) -> int:
	return -1 if TIDE > 0.5 else 0

func present() -> void:
	super.present()

func _draw_zones(c: CanvasItem) -> void:
	cv = c
	# 地上的火
	for f in FIRE:
		var n := int(f.r * 1.6)
		for i in n:
			var a: float = i * 2.39996 + f.x
			var rr: float = f.r * sqrt(float(i) / n)
			var fl := sin(T * 9 + i) > 0
			sp(f.x + cos(a) * rr, f.y + sin(a) * rr * 0.7, EMBER if fl else WINE, 5 if fl else 3, 0, 1.0)
	# 页尘、余烬、散页
	for p in PK:
		if not on_screen(p.x, p.y):
			continue
		var tw := sin(T * 8 + p.age * 3) > 0
		match p.k:
			"dust":
				var big := p.v >= 5
				var m := GOLD if big else ORE
				var s := 1.0 if big else 0.5
				sp(p.x - s * 0.5, p.y - s * 0.5, m, 6 if tw else 5, 0, s)
				sp(p.x - s * 0.5 - s, p.y - s * 0.5, m, 4, 0, s)
				sp(p.x - s * 0.5 + s, p.y - s * 0.5, m, 4, 0, s)
				sp(p.x - s * 0.5, p.y - s * 0.5 - s, m, 4, 0, s)
				sp(p.x - s * 0.5, p.y - s * 0.5 + s, m, 3, 0, s)
			"ember":
				sp(p.x - 1, p.y - 1, EMBER, 4, 0, 2.0)
				sp(p.x - 0.5, p.y - 1, EMBER, 6, 0, 1.0)
				sp(p.x, p.y, GOLD, 6 if tw else 5)
			"kiln":
				ball(p.x, p.y + sin(T * 3) * 1.0, 3.0, GOLD, 5, 0)
				for k in 8:
					var a := T * 2 + k * TAU / 8
					sp(p.x + cos(a) * 5.5, p.y + sin(a) * 5.5, EMBER, 6 if tw else 5)
			"page":
				draw_page_icon(p.x, p.y + sin(T * 3) * 1.5, 1.0)
				for k in 6:
					var a := T * 1.5 + k * TAU / 6
					sp(p.x + cos(a) * 9, p.y + sin(a) * 9, GOLD, 6 if (k + int(T * 6)) % 2 == 0 else 4)
	# 预告线：霜棱、回声蛇
	for e in E:
		if e.t == "serp" and e.st == "aim":
			var s := 6.0
			while s < 220:
				if int(s / 3.0 + T * 20) % 3 != 0:
					sp(e.x + cos(e.ha) * s, e.y + sin(e.ha) * s, SERP, 6 if e.tm < 0.3 else 4, 0, 1.0)
				s += 1.5

func _draw_world(c: CanvasItem) -> void:
	cv = c
	for e in E:
		if e.dead or not on_screen(e.x, e.y, 30):
			continue
		var sh := shift_at(e.x, e.y)
		if e.flash > 0:
			sh = 2
		draw_creature(e, sh)
		if e.elite and e.t != "serp":
			# 精英头上一圈金点
			for k in 6:
				var a := T * 2.5 + k * TAU / 6
				sp(e.x + cos(a) * (e.r + 5), e.y + sin(a) * (e.r + 5) * 0.5 - 1, GOLD, 6 if k % 2 == 0 else 4)
		if e.burn_t > 0 and int(T * 10 + e.ph * 3) % 3 == 0:
			sp(e.x - 0.5, e.y - e.r - 1, EMBER, 6, 0, 1.0)
		if e.slow > 0 and int(T * 6 + e.ph) % 4 == 0:
			sp(e.x + 2, e.y - e.r, ICE, 6)
	draw_bullets()
	# 飞行中的墨团
	for b in INKB:
		ball(b.x, b.y, 2.5, GRAV, 3, 0)
		sp(b.x - 0.5, b.y - 1.5, GRAV, 6)
	# 回环：绕身刻刀
	if evolved(2):
		var R := 26.0 * area_k()
		for k in 3:
			var a := blade_a + k * TAU / 3
			for q in 7:
				var aa := a - q * 0.06
				var rr := R + (q % 2) * 0.5
				sp(P.x + cos(aa) * rr, P.y + sin(aa) * rr, PAPER if q < 2 else MIRROR, 6 - q * 0.6, 0, 1.0 if q < 3 else 0.5)
			for q in 6:
				sp(P.x + cos(a) * (R - 3 + q), P.y + sin(a) * (R - 3 + q), PAPER, 6)
	# 刀光
	for s in SL:
		var k: float = s.t / 0.16
		var n := int(s.arc * s.r / 1.2)
		for i in n:
			var a: float = s.a - s.arc * 0.5 + s.arc * float(i) / n
			for q in 4:
				var rr: float = s.r - q * 2.0
				if Pal.bay(i, q) > k + 0.2:
					continue
				sp(s.x + cos(a) * rr, s.y + sin(a) * rr, PAPER if q == 0 else MIRROR, 6 - q, 0, 1.0 if q == 0 else 0.5)
	# 爆炸圈
	for b in BOOMS:
		var k: float = 1.0 - b.t / (0.6 if b.r > 100 else 0.3)
		var rr: float = b.r * (0.4 + 0.6 * k)
		var n := int(rr * 1.6) + 8
		for i in n:
			var a := float(i) / n * TAU
			sp(b.x + cos(a) * rr, b.y + sin(a) * rr, GOLD if b.r > 100 else GRAV, 6 if i % 2 == 0 else 4, 0, 1.0)
		if b.r < 100 and k < 0.4:
			ball(b.x, b.y, minf(6.0, b.r * 0.3) * (1.0 - k), GRAV, 3, 0, 0.6)
	# 墨线
	for b in BEAMS:
		var fx := cos(b.a)
		var fy := sin(b.a)
		var k: float = b.t / b.max
		var wd: float = b.w * (0.4 + 0.6 * minf(1.0, k * 3.0))
		var s := 4.0
		while s < b.len:
			for q in range(-int(wd), int(wd) + 1, 2):
				var core := absi(q) <= 1
				sp(b.x + fx * s - fy * q * 0.5, b.y + fy * s + fx * q * 0.5, PAPER if core else GRAV, 6 if core else 4, 0, 1.0)
			s += 2.0
	# 电弧
	for z in ZAPS:
		var L := Vector2(z.bx - z.ax, z.by - z.ay)
		var n := int(L.length() / 2.0)
		for i in n:
			var t := float(i) / maxf(1, n)
			sp(z.ax + L.x * t + (randf() - 0.5) * 3, z.ay + L.y * t + (randf() - 0.5) * 3, MIRROR, 6, 0, 1.0)
	draw_particles()
	# 小克画在最上面，怪再多也找得到自己
	if S != "over" or won:
		if P.inv <= 0 or int(T * 16) % 2 == 0 or P.inv > 0.6:
			draw_player()

func _draw_hud(c: CanvasItem) -> void:
	cv = c
	OFS = Vector2.ZERO
	# 伤害数字（世界坐标换成屏幕坐标）
	for n in NUMS:
		var a: float = minf(1.0, n.t * 3.0)
		text(str(n.v), n.x - ox, n.y - oy, 9 if n.c else 7, C_GOLD if n.c else C_TXT, C_SH, a, n.c)
	if hurt_t > 0:
		rect(0, 0, W, H, Color(0.8, 0.1, 0.1, hurt_t * 0.5))
	draw_sv_hud()
	if S == "lvl":
		dim(0.55)
		OFS = PO
		draw_lvl()
	elif S == "pause":
		dim(0.7)
		OFS = PO
		text("暂停", 160, 40, 16, C_GOLD, C_SH, 1.0, true)
		draw_build(160, 74)
		draw_btns(["继续", "回到标题"])
	elif S == "over" and over_t > 0.6:
		dim(minf(0.75, (over_t - 0.6) * 1.5))
		OFS = PO
		if won:
			text("炉灯重新亮了", 160, 18, 16, C_GOLD, C_SH, 1.0, true)
			text("你在暗潮里撑过了 %s，打倒了回声蛇" % fmt_t(gt2), 160, 44, 9, C_TXT, C_SH)
		else:
			text("陶身碎了", 160, 18, 16, C_RED, C_SH, 1.0, true)
			text("在暗潮里撑了 %s" % fmt_t(gt2), 160, 44, 9, C_TXT, C_SH)
		text("等级 %d · 打散 %d 只生物" % [lv, kills2], 160, 58, 9, C_DIM, C_SH)
		draw_build(160, 76)
		text("最好成绩：%s · 等级 %d · 通关 %d 次" % [fmt_t(float(best.get("time", 0.0))), int(best.get("lv", 0)), int(best.get("wins", 0))], 160, 124, 8, C_DIM, C_SH)
		draw_btns(["再来一局", "回到标题"])
	OFS = Vector2.ZERO
	if H > W:
		rect(0, H / 2.0 - 12, W, 24, Color(0.02, 0.02, 0.06, 0.85))
		text("把手机横过来玩，画面更大", W / 2.0, H / 2.0 - 6, 10, C_GOLD, C_SH)

func _draw_hud_sprites(_c: CanvasItem) -> void:
	pass

func fmt_t(t: float) -> String:
	return "%d:%02d" % [int(t / 60), int(fmod(t, 60))]

func draw_btns(names: Array) -> void:
	for i in 2:
		var r := pause_btn(i)
		box(r.position.x, r.position.y, r.size.x, r.size.y, Pal.rc(CLAY, 2) if i == 0 else Pal.rc(SPACE, 2), Pal.rc(GOLD, 5) if i == 0 else Pal.rc(RUIN, 5))
		text(names[i], r.get_center().x, r.position.y + 2, 10, C_GOLD if i == 0 else C_DIM, C_SH)
	if not touch_mode:
		text("Enter %s · Esc %s" % [names[0], names[1]], 160, 162, 8, C_DIM, C_SH)

## 这一局拿到的笔和字
func draw_build(cx: float, y: float) -> void:
	var ps := []
	for i in pens:
		ps.append(("「%s」" % SPENS[i].ename) if evolved(i) else "%s %d" % [SPENS[i].name, plv(i)])
	var ws := []
	for s in words:
		ws.append("%s%d" % [s, w(s)])
	text("笔：" + "  ".join(ps), cx, y, 9, C_CLAY, C_SH)
	text("字：" + ("  ".join(ws) if not ws.is_empty() else "（还没有）"), cx, y + 14, 9, C_TEAL, C_SH)
	var hint := []
	for i in pens:
		if not evolved(i):
			hint.append("%s+%s→%s" % [SPENS[i].name, SPENS[i].evo, SPENS[i].ename])
	if not hint.is_empty():
		text("成词：" + "  ".join(hint), cx, y + 28, 8, C_DIM, C_SH)

func draw_sv_hud() -> void:
	# 顶上一条经验
	var k := clampf(float(xp) / xp_need(), 0.0, 1.0)
	rect(0, 0, W, 4, Color(0.03, 0.03, 0.08, 0.9))
	rect(0, 0, W * k, 4, Pal.rc(ORE, 4))
	rect(0, 0, W * k, 1, Pal.rc(ORE, 6))
	text_l("Lv %d" % lv, 3, 4, 9, C_GOLD, C_SH)
	# 生命
	for i in P.maxhp:
		icon(HEART, 4 + i * 6.5, 16, Pal.rc(CLAY, 5) if i < P.hp else Pal.rc(RUIN, 5))
	# 时间和击退数
	var tc := C_RED if sboss != null else C_TXT
	text(fmt_t(gt2), W / 2.0, 5, 12, tc, C_SH, 1.0, true)
	text("打散 %d" % kills2, W / 2.0, 20, 8, C_DIM, C_SH)
	if sboss == null and gt2 < BOSS_AT:
		text_r("回声蛇 %s 后醒来" % fmt_t(BOSS_AT - gt2), W - 4, 6, 8, C_DIM, C_SH)
	# 右上：冲刺冷却
	if P.dash_cd > 0:
		text_r("冲刺 %.1f" % P.dash_cd, W - 4, 16, 8, C_DIM, C_SH)
	# 左下：笔和字
	var x := 4.0
	var y := H - 26.0
	for i in pens:
		var name: String = SPENS[i].ename if evolved(i) else SPENS[i].name
		var tw := text_w(name, 8) + 6
		box(x, y, tw, 11, Color(0.05, 0.05, 0.1, 0.8), Pal.rc(GOLD if evolved(i) else CLAY, 5))
		text_l(name, x + 3, y + 0.5, 8, C_GOLD if evolved(i) else C_CLAY)
		var l := mini(plv(i), 5)
		for q in 5:
			rect(x + 1.5 + q * (tw - 3) / 5.0, y + 9.5, (tw - 3) / 5.0 - 0.5, 1, Pal.rc(GOLD if q < l else RUIN, 5 if q < l else 3))
		x += tw + 3
	x = 4.0
	y = H - 13.0
	for s in words:
		box(x, y, 16, 11, Color(0.05, 0.05, 0.1, 0.8), kind_col(SW[s].kind))
		text_l(s, x + 2, y + 0.5, 8, C_TXT)
		text_l(str(w(s)), x + 11, y + 2, 6, C_DIM)
		x += 18
	# 首领血条
	if sboss != null and not sboss.dead:
		var bw := minf(200.0, W - 120)
		var bx := W / 2.0 - bw / 2.0
		box(bx - 1, 32, bw + 2, 5, C_SH, Pal.rc(SERP, 5))
		rect(bx, 33, bw * maxf(0.0, sboss.hp / sboss.mhp), 3, Pal.rc(SERP, 4))
		text("回声蛇", W / 2.0, 38, 8, C_RED, C_SH)
	# 大字横幅
	if banner_t > 0:
		var a := minf(1.0, banner_t * 2.0) * minf(1.0, (3.2 - banner_t) * 4.0)
		text(banner, W / 2.0, H * 0.16, 18, banner_c, C_SH, a, true)
	# 提示
	var ty := H * 0.16 + 26
	for t in toasts:
		text(t.s, W / 2.0, ty, 9, t.c, C_SH, minf(1.0, t.t))
		ty += 12
	# 触屏摇杆
	for t in touches.values():
		if t.kind == "move":
			var c0: Vector2 = t.start
			for i in 16:
				var a := i * TAU / 16
				rect(c0.x + cos(a) * 22, c0.y + sin(a) * 22, 1, 1, Color(1, 1, 1, 0.25))
			rect(t.pos.x - 2, t.pos.y - 2, 4, 4, Color(1, 0.85, 0.6, 0.5))

func kind_col(c: String) -> Color:
	match c:
		"形": return Pal.rc(ORE, 5)
		"动": return Pal.rc(GOLD, 5)
		"性": return Pal.rc(EMBER, 5)
	return Pal.rc(CLAY, 5)

func draw_lvl() -> void:
	text("升级！挑一个", 160, 14, 14, C_GOLD, C_SH, 1.0, true)
	text("Lv %d" % lv, 160, 32, 8, C_DIM, C_SH)
	for i in opts.size():
		var o: Dictionary = opts[i]
		var r := card_rect(i)
		var sel := i == opt_sel
		var evo: bool = o.k == "evo"
		var fill := Color(0.18, 0.12, 0.04, 0.95) if evo else Color(0.06, 0.06, 0.12, 0.95)
		var line := Pal.rc(GOLD, 6) if sel or evo else Pal.rc(RUIN, 5)
		var yy := r.position.y - (3.0 if sel else 0.0)
		box(r.position.x, yy, r.size.x, r.size.y, fill, line)
		if sel:
			box(r.position.x + 1, yy + 1, r.size.x - 2, r.size.y - 2, null, Pal.rc(GOLD, 4))
		var cx := r.get_center().x
		# 大字
		var big := ""
		var col := C_CLAY
		match o.k:
			"pen":
				big = SPENS[o.i].name
				col = C_CLAY
			"word":
				big = o.c
				col = kind_col(SW[o.c].kind)
			"evo":
				big = SPENS[o.i].ename
				col = C_GOLD
			"heal":
				big = "余烬"
				col = C_RED
			"dust":
				big = "页尘"
				col = C_TEAL
		text(big, cx, yy + 6, 18 if big.length() <= 2 else 14, col, C_SH, 1.0, true)
		var tag := ""
		match o.k:
			"pen":
				tag = "笔 · 新的" if plv(o.i) == 0 else "笔 · Lv%d→%d" % [plv(o.i), plv(o.i) + 1]
			"word":
				tag = "%s字 · 新的" % SW[o.c].kind if w(o.c) == 0 else "%s字 · Lv%d→%d" % [SW[o.c].kind, w(o.c), w(o.c) + 1]
			"evo":
				tag = "成词进化！"
		text(tag, cx, yy + 32, 8, C_GOLD if evo else C_DIM, C_SH)
		var ly := yy + 46
		for para in opt_desc(o).split("\n"):
			for ln in wrap_text(para, 8, r.size.x - 8):
				text(ln, cx, ly, 8, C_TXT if ly < yy + 60 else C_TEAL, C_SH)
				ly += 10
		if not touch_mode:
			text(str(i + 1), r.position.x + 5, yy + 2, 8, C_DIM)
	if not touch_mode:
		text("点卡片，或按 1/2/3 · ←→ 加 Enter", 160, 160, 8, C_DIM, C_SH)

# ======================================================================
# 自动试玩（测试用）：godot -- --surv --autoplay [--fast=4]
# ======================================================================
var _bot_mv := Vector2.ZERO
var _god_saves := 0
var _lvl_wait := 0.0
var _sbt := 0.0
var _bot_a := 0.0

func _sv_bot(dt: float) -> void:
	_sbt += dt
	if S == "over":
		if over_t > 2.0:
			print("perf: avg %.2f ms, max %.2f ms, frames %d" % [_perf_us / 1000.0 / maxf(1, _perf_n), _perf_max / 1000.0, _perf_n])
			_shot("over")
			get_tree().quit()
		return
	if S != "sv":
		return
	_bot_a += dt * 0.35
	var v := Vector2(cos(_bot_a), sin(_bot_a)) * 0.6
	for e in E:
		var d := Vector2(P.x - e.x, P.y - e.y)
		var L := d.length()
		if L < 60 and L > 0.1:
			v += d / L * pow((60 - L) / 60, 2.0) * (4.0 if e.elite else 2.5)
	var g: Pick = null
	var gd := 90.0
	for p in PK:
		var L := Vector2(p.x - P.x, p.y - P.y).length()
		if L < gd:
			gd = L
			g = p
	if g:
		v += Vector2(g.x - P.x, g.y - P.y).normalized() * 0.8
	_bot_mv = v.normalized() if v.length() > 0.2 else v
	for t in [20.0, 70.0, 185.0, 300.0, 430.0, 545.0, 560.0]:
		if gt2 >= t and not _shot_at.has(t):
			_shot_at[t] = true
			_shot("t%d" % int(t))
			print("t=%d lv=%d enemies=%d pk=%d pb=%d pt=%d kills=%d hp=%d avg_ms=%.2f max_ms=%.2f" % [int(gt2), lv, E.size(), PK.size(), PB.size(), PT.size(), kills2, P.hp, _perf_us / 1000.0 / maxf(1, _perf_n), _perf_max / 1000.0])
			_perf_max = 0
	if gt2 > 720:
		end_run(false)
	if _sv_god() and P.hp <= 3:
		P.hp = P.maxhp
		_god_saves += 1

func _sv_god() -> bool:
	return OS.get_cmdline_user_args().has("--god")

func _bot_pick() -> int:
	for i in opts.size():
		if opts[i].k == "evo":
			return i
	# 偏好：先拿笔，再拿搭档字
	for i in opts.size():
		var o: Dictionary = opts[i]
		if o.k == "word":
			for p in pens:
				if SPENS[p].evo == o.c:
					return i
	for i in opts.size():
		if opts[i].k == "pen":
			return i
	return randi() % opts.size()

func _shot(name: String) -> void:
	if OS.get_cmdline_user_args().has("--noshot"):
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://surv_%s.png" % name)
