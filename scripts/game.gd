extends "res://scripts/game_hud.gd"
## 《散页 Unbound》入口：搭场景、输入、主循环、自动试玩。

var bg: ColorRect
var vig: ColorRect
var hud_spr_painter: Node2D
var spr_mat: ShaderMaterial
var fire_lock := false       # 点界面的那一下不算开火，松开鼠标后才恢复
var restart_arm := false
var save_t := 0.0

func fire_locked() -> bool:
	return fire_lock

func restart_arm_v() -> bool:
	return restart_arm

func _ready() -> void:
	R0.seed = 20261108
	font = _load_font()
	var fb := FontVariation.new()
	fb.base_font = font
	fb.variation_embolden = 0.7
	font_b = fb
	make_atlas()
	spr_mat = ShaderMaterial.new()
	spr_mat.shader = load("res://shaders/sprite.gdshader")
	spr_mat.set_shader_parameter("pal", Pal.pal_tex)

	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)
	bg = ColorRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_mat = ShaderMaterial.new()
	bg_mat.shader = load("res://shaders/bg.gdshader")
	bg_mat.set_shader_parameter("pal", Pal.pal_tex)
	bg.material = bg_mat
	bg_layer.add_child(bg)

	zone_painter = PAINTER.new()
	zone_painter.fn = _draw_zones
	zone_painter.material = spr_mat
	add_child(zone_painter)
	rock_layer = Node2D.new()
	add_child(rock_layer)
	ent_painter = PAINTER.new()
	ent_painter.fn = _draw_world
	ent_painter.material = spr_mat
	add_child(ent_painter)
	rock_mat = ShaderMaterial.new()
	rock_mat.shader = load("res://shaders/rock.gdshader")
	rock_mat.set_shader_parameter("pal", Pal.pal_tex)

	camera = Camera2D.new()
	camera.zoom = Vector2(U, U)
	add_child(camera)
	camera.make_current()

	var vig_layer := CanvasLayer.new()
	vig_layer.layer = 1
	add_child(vig_layer)
	vig = ColorRect.new()
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
	hud_spr_painter = PAINTER.new()
	hud_spr_painter.fn = _draw_hud_sprites
	hud_spr_painter.material = spr_mat
	hud_layer.add_child(hud_spr_painter)

	get_viewport().size_changed.connect(_on_resize)
	_on_resize()

	TRX.resize(400)
	TRY.resize(400)
	load_save()
	load_words()
	var t0 := Time.get_ticks_msec()
	new_world()
	print("world generated in %d ms, rocks=%d" % [Time.get_ticks_msec() - t0, rocks.size()])
	var args := OS.get_cmdline_user_args()
	if args.has("--autoplay"):
		_autoplay = true
	if args.has("--bot"):
		_bot = true
		_autoplay = true
	if _autoplay:
		save.erase("run")

## 窗口大小变了：自己算一个整数放大倍数（像素不会糊），画面铺满整个窗口，
## 窗口比 640×360 的整数倍多出来的部分用来多看一点世界，不留黑边。
func _on_resize() -> void:
	var win := get_window()
	var ws := Vector2(win.size)
	var k := maxf(1.0, floorf(minf(ws.x / 640.0, ws.y / 360.0)))
	if not is_equal_approx(win.content_scale_factor, k):
		win.content_scale_factor = k
	var vs := ws / k
	W = maxi(1, ceili(vs.x / U))
	H = maxi(1, ceili(vs.y / U))
	PO = Vector2(floorf((W - 320) / 2.0), floorf((H - 180) / 2.0))
	bg.size = vs
	vig.size = vs
	bg_mat.set_shader_parameter("res", vs)
	vig_mat.set_shader_parameter("res", vs)

## 内置的开源中文字体（思源黑体 / Noto Sans SC，OFL 许可），网页和手机上也能显示中文
func _load_font() -> Font:
	var f = load("res://fonts/NotoSansSC-Regular.otf")
	if f is Font:
		return f
	return ThemeDB.fallback_font

# 输入（键盘 / 鼠标 / 触屏）。位置都换算成“单位”
func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		var kc: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
		jp[kc] = true
		if kc == KEY_M:
			toast("静音" if Sfx.toggle_mute() else "声音开启", C_DIM, 1.5)
	elif e is InputEventMouseButton:
		touch_mode = false
		if e.button_index == MOUSE_BUTTON_LEFT:
			mouse_down = e.pressed
			if e.pressed:
				click_q = true
				if S != "play":
					fire_lock = true
			else:
				fire_lock = false
		elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
			jp["dash"] = true
	elif e is InputEventMouseMotion:
		touch_mode = false
		mouse_moved = true
	elif e is InputEventScreenTouch:
		touch_mode = true
		var pos: Vector2 = e.position / U
		if e.pressed:
			click_q = true
			tap_pos = pos
			var kind := "aim"
			if S != "play":
				kind = "btn"
			elif touch_btn(0).has_point(pos):
				kind = "dash"
				jp["dash"] = true
			elif touch_btn(1).has_point(pos):
				kind = "btn"
				jp[KEY_Q] = true
			elif touch_btn(2).has_point(pos) and (near_kiln() or P.beacons > 0):
				kind = "btn"
				jp[KEY_E if near_kiln() else KEY_B] = true
			elif pos.x > W - 48 and pos.y > 12 and pos.y < 60:
				kind = "btn"
				jp[KEY_TAB] = true
			elif pos.x < 6 + P.slots.size() * 15 and pos.y > H - 20:
				kind = "btn"
				jp[KEY_F] = true
			elif pos.x < W / 2.0:
				kind = "move"
			touches[e.index] = {"kind": kind, "start": pos, "pos": pos}
		else:
			touches.erase(e.index)
		_touch_sync()
	elif e is InputEventScreenDrag:
		if touches.has(e.index):
			touches[e.index].pos = e.position / U
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
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		mouse_down = false
		fire_lock = false
		touches.clear()
		_touch_sync()
		if S == "play":
			save_run()

func _physics_process(dt: float) -> void:
	if _autoplay:
		if _bot:
			_bot_step(dt)
		else:
			_autoplay_step(dt)
	step(dt)

func _process(_dt: float) -> void:
	present()

func step(dt: float) -> void:
	T += dt
	duck = 1.0
	var go := click_q or pressed(KEY_ENTER) or pressed(KEY_KP_ENTER) or pressed(KEY_SPACE)
	match S:
		"title":
			cam_pos = Vector2(cos(T * 0.05) * 60, sin(T * 0.05) * 40)
			if has_run():
				var mp := ppointer()
				if pressed(KEY_N) or (click_q and title_btn(1).has_point(mp)):
					if restart_arm:
						clear_run()
						S = "intro"
						intro_t = 0.0
					restart_arm = true
				elif go and (not click_q or title_btn(0).has_point(mp)):
					load_run()
					S = "play"
					cam_pos = Vector2(P.x, P.y)
					toast("欢迎回来。炉灯一直给你留着火。", C_GOLD, 4)
			elif go:
				S = "intro"
				intro_t = 0.0
		"intro":
			intro_t += dt
			if go and intro_t > 0.4:
				intro_t = 15.0 if intro_t < 15.0 else 99.0
			if intro_t > 18.5:
				S = "play"
				toast("找回三张失落之页，带回炉灯装订。", C_GOLD, 5)
				if touch_mode:
					toast("左边拖动移动 · 右边按住射击 · 右下角冲刺 · 点左下角的句子换字", C_DIM, 6)
				else:
					toast("WASD 移动 · 鼠标射击 · 空格冲刺 · Q 吃余烬 · F 句子", C_DIM, 6)
		"play":
			gt += dt
			tide_t += dt
			upd_tide(dt)
			upd_player(dt)
			upd_creatures(dt)
			upd_bullets(dt)
			upd_pickups(dt)
			upd_beacons(dt)
			upd_spawns(dt)
			check_discover()
			save_t += dt
			if save_t > 15.0 and S == "play":
				save_t = 0.0
				save_run()
			if S == "play" and pressed(KEY_TAB):
				S = "codex"
			elif S == "play" and pressed(KEY_F):
				S = "words"
				word_sel = -1
		"words":
			upd_words_panel()
		"menu":
			for i in range(1, SHOP.size() + 1):
				if pressed(KEY_0 + i) or pressed(KEY_KP_0 + i):
					menu_sel = i - 1
					try_buy(i - 1)
			if pressed(KEY_W) or pressed(KEY_UP):
				menu_sel = (menu_sel + SHOP.size() - 2) % SHOP.size()
			if pressed(KEY_S) or pressed(KEY_DOWN):
				menu_sel = (menu_sel + 2) % SHOP.size()
			if pressed(KEY_A) or pressed(KEY_LEFT):
				menu_sel = (menu_sel + SHOP.size() - 1) % SHOP.size()
			if pressed(KEY_D) or pressed(KEY_RIGHT):
				menu_sel = (menu_sel + 1) % SHOP.size()
			if pressed(KEY_ENTER) or pressed(KEY_KP_ENTER) or pressed(KEY_SPACE):
				try_buy(menu_sel)
			var mp := ppointer()
			var closed := pressed(KEY_E) or pressed(KEY_ESCAPE) or pressed(KEY_TAB)
			var on_card := false
			for i in SHOP.size():
				if menu_rect(i).has_point(mp):
					on_card = true
					if click_q:
						menu_sel = i
			if click_q and buy_rect().has_point(mp):
				try_buy(menu_sel)
			elif click_q and not on_card and not Rect2(12, 8, 296, 164).has_point(mp):
				closed = true
			if closed:
				S = "play"
				save_run()
		"codex":
			if pressed(KEY_W) or pressed(KEY_UP):
				codex_sel = (codex_sel + 7) % 8
			if pressed(KEY_S) or pressed(KEY_DOWN):
				codex_sel = (codex_sel + 1) % 8
			var mp := ppointer()
			var mi := floori((mp.y - 32) / 16.0)
			if mp.x > 14 and mp.x < 110 and mi >= 0 and mi < 8 and (mouse_moved or click_q):
				codex_sel = mi
			elif click_q and not Rect2(8, 8, 304, 164).has_point(mp):
				S = "play"
			if pressed(KEY_TAB) or pressed(KEY_ESCAPE) or pressed(KEY_E):
				S = "play"
		"dead":
			dead_t += dt
			if dead_t > 2.6:
				respawn()
				save_run()
		"ending":
			end_t += dt
			upd_creatures(dt)
			if end_t > 7 and (pressed(KEY_ENTER) or pressed(KEY_KP_ENTER) or click_q):
				S = "play"
				free_mode = true
				toast("自由探索：残烛还在打寒颤，宇宙还有很多散页。", C_DIM, 5)
				save_run()
	if randf() < 0.3:
		part(3 + (randf() - 0.5) * 3, -20, (randf() - 0.5) * 6, -10 - randf() * 8, 2.2, MOTH, 3)
	upd_particles(dt)
	if S == "play" or S == "dead" or S == "ending":
		var e := S == "ending"
		var tgt := Vector2(0, -30) if e else Vector2(P.x + P.ax * 14, P.y + P.ay * 10)
		cam_pos += (tgt - cam_pos) * minf(1.0, dt * (1.5 if e else 5.0))
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
	mouse_moved = false

func present() -> void:
	var sx := (randf() - 0.5) * shk
	var sy := (randf() - 0.5) * shk
	var vs := Vector2(get_window().size) / get_window().content_scale_factor
	camera.position = Vector2(snap(cam_pos.x + sx), snap(cam_pos.y + sy))
	ox = camera.position.x - vs.x / (2.0 * U)
	oy = camera.position.y - vs.y / (2.0 * U)
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
	hud_spr_painter.queue_redraw()

var _shots := {1.0: "title", 3.9: "fire", 4.6: "words", 5.2: "play", 7.0: "menu", 9.0: "codex", 13.0: "tide", 17.0: "serp", 23.0: "ending"}

## 测试用：把八种生物摆在炉灯旁边拍一张“全家福”（godot -- --autoplay --gallery）
func _gallery_step() -> void:
	if S == "title":
		click_q = true
	elif S == "intro":
		intro_t = 99
	if _once(1.5):
		cr.clear()
		toasts.clear()
		tide_t = 0.0
		var xs := [-110, -80, -50, -20, 20, 50, 80, 110]
		for i in ORDER.size():
			var t: String = ORDER[i]
			if t == "serp":
				continue
			var c := mk(t, xs[i], -48 if i % 2 == 0 else 52)
			c.hx = c.x
			c.hy = c.y
			match t:
				"leech":
					c.st = "orbit"
					c.orR = 8
				"clam":
					c.st = "open"
					c.tm = 99
					c.na = -PI / 2
				"mite":
					c.ang = 2.2
				"folio":
					c.vx = 20
					c.vy = -8
		serp.st = "fight"
		serp.x = 60
		serp.y = 20
		serp.burst_t = 99
		for i in serp.seg.size():
			serp.seg[i] = Vector2(64 + i * 5, 22 + sin(i * 0.7) * 6)
		P.hp = 99
		P.inv = 99
		P.carry = [0]
		P.bound = 1
		P.dust = 37
		for i in 30:
			add_pick(-60 + randf() * 120, 30 + randf() * 30, "dust" if i % 3 else "ember")
		var w := Pick.new()
		w.x = -30
		w.y = 30
		w.k = "word"
		w.age = -99
		PK.append(w)
		var b := Beacon.new()
		b.x = -70
		b.y = 20
		BEA.append(b)
	for c in cr:
		c.cd = 9
		if c.t != "serp":
			c.x = c.hx
			c.y = c.hy
	for p in PK:
		p.age = minf(p.age, 0.0)
	if serp:
		serp.x = 60
		serp.y = 20
	if _ap_t > 1.5:
		P.x = 0
		P.y = 30
		P.vx = 0
		P.vy = 0
	_ap_aim = Vector2(1, -0.3)
	_ap_fire = _ap_t > 2.5
	if _once(3.2):
		get_viewport().get_texture().get_image().save_png("user://shot_gallery.png")
	if _ap_t > 3.5:
		get_tree().quit()

func _autoplay_step(dt: float) -> void:
	_ap_t += dt
	if OS.get_cmdline_user_args().has("--gallery"):
		_gallery_step()
		return
	for k in _shots.keys():
		if _ap_t >= k:
			var img := get_viewport().get_texture().get_image()
			img.save_png("user://shot_%s.png" % _shots[k])
			print("shot ", _shots[k], " S=", S)
			_shots.erase(k)
	if S == "title" and _ap_t > 0.5:
		click_q = true
	elif S == "intro" and _ap_t > 1.5:
		intro_t = 99
	if _once(2.0):
		P.slots = [{"c": "雨", "gold": false}, {"c": "火", "gold": false}, {"c": "石", "gold": true}]
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--sentence="):
				P.slots = []
				for ch in a.substr(11):
					P.slots.append({"c": ch, "gold": false})
		P.bag = [{"c": "穿", "gold": false}, {"c": "针", "gold": false}, {"c": "回", "gold": false}, {"c": "环", "gold": false}]
		calc_loadout()
	if _once(4.2):
		jp[KEY_F] = true
	if _once(4.9):
		jp[KEY_F] = true
	if _once(6.0):
		P.dust = 120
		P.x = 0
		P.y = 20
		jp[KEY_E] = true
	if _once(6.5):
		jp[KEY_2] = true
		jp[KEY_3] = true
		jp[KEY_1] = true
	if _once(8.0):
		jp[KEY_E] = true
		seen["hush"] = true
		seen["mite"] = true
	if _once(8.3):
		jp[KEY_TAB] = true
		codex_sel = 5
	if _once(10.0):
		jp[KEY_TAB] = true
		P.x = 200
		P.y = 100
		jp[KEY_B] = true
	if _ap_t > 10.5 and tide_t < 112:
		tide_t = 113
		TIDE = 1.0
	if _once(14.0):
		P.x = PAGES[2].x + 150
		P.y = PAGES[2].y + 150
		P.hp = 99
		cam_pos = Vector2(P.x, P.y)
	if _once(19.0):
		P.hp = 5
		P.carry = [0, 1, 2]
		P.x = 0
		P.y = 20
		cam_pos = Vector2(0, 20)
	if S == "play" and _ap_t < 6.0:
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
	elif S == "play" and _ap_t > 14.0 and serp:
		_ap_aim = Vector2(serp.x - P.x, serp.y - P.y)
		_ap_fire = true
		joy = Vector2.ZERO
	else:
		_ap_fire = false
		joy = Vector2.ZERO
	if _ap_t > 24.0:
		get_tree().quit()

var _done := {}

## 长时间自动乱玩（测试用：godot -- --bot [--bot-secs=600]）。每帧多跑几步逻辑，
## 到处飞、乱射、买东西、开关面板，用来揪出运行时报错。
var _bot_t := 0.0
var _bot_dir := Vector2.RIGHT
var _bot_next := 0.0
var _bot_secs := 300.0
func _bot_step(dt: float) -> void:
	if _bot_t == 0.0:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--bot-secs="):
				_bot_secs = float(a.substr(11))
		clear_run()
	var n := 1 if OS.get_cmdline_user_args().has("--perf") else 5
	for i in n:
		_bot_tick(dt)
		if i < n - 1:
			step(dt)

func _bot_tick(dt: float) -> void:
	_bot_t += dt
	if S == "title" or S == "intro" or S == "ending":
		click_q = true
		if S == "intro":
			intro_t = 99
		return
	if S == "menu":
		jp[KEY_1 + randi() % 7] = true
		if randf() < 0.05:
			jp[KEY_E] = true
		return
	if S == "words":
		if randf() < 0.1:
			jp[KEY_F] = true
		return
	if S == "codex":
		if randf() < 0.1:
			jp[KEY_TAB] = true
		return
	if S != "play":
		return
	if _bot_t > _bot_next:
		_bot_next = _bot_t + 1.0 + randf() * 4.0
		var goal := Vector2.ZERO
		var r := randf()
		if P.warm < 35 or P.hp <= 2 or not P.carry.is_empty() or TIDE > 0.5:
			goal = Vector2.ZERO
		elif r < 0.5:
			for pg in PAGES:
				if pg.state == "free" or (pg.state == "sealed" and P.bound >= 2):
					goal = Vector2(pg.x, pg.y)
					break
		else:
			goal = Vector2(P.x, P.y) + Vector2.from_angle(randf() * TAU) * 300
		_bot_dir = (goal - Vector2(P.x, P.y)).normalized().rotated((randf() - 0.5) * 0.8)
		if randf() < 0.15:
			jp[[KEY_Q, KEY_B, KEY_F, KEY_TAB, KEY_E, KEY_SPACE][randi() % 6]] = true
		if near_kiln() and randf() < 0.5:
			jp[KEY_E] = true
		if randf() < 0.1:
			P.dust += 40
		if randf() < 0.05:
			var ks: Array = WD.chars.keys()
			give_word(ks[randi() % ks.size()], randf() < 0.3)
		if randf() < 0.03:
			for i in P.slots.size():
				P.slots[i] = null
	joy = _bot_dir
	var tgt: Creature = null
	var bd := 140.0
	for c in cr:
		var d := Vector2(c.x - P.x, c.y - P.y).length()
		if d < bd and not c.dead and not (c.t == "serp" and c.st != "fight"):
			bd = d
			tgt = c
	_ap_aim = Vector2(tgt.x - P.x, tgt.y - P.y) if tgt else _bot_dir
	_ap_fire = true
	if OS.get_cmdline_user_args().has("--perf") and Engine.get_physics_frames() % 120 == 0:
		print("perf: physics %.2f ms, process %.2f ms, fps %d, draws %d, cr %d, pt %d" % [Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, Performance.get_monitor(Performance.TIME_PROCESS) * 1000, Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), cr.size(), PT.size()])
	if _bot_t > _bot_secs:
		print("bot done: t=%.0f gt=%.0f deaths=%d bound=%d dust=%d kills=%d tides=%d sprs=%d" % [_bot_t, gt, P.deaths, P.bound, P.dust_total, P.kills, tides, sprs.size()])
		get_tree().quit()


func _once(t: float) -> bool:
	if _ap_t > t and not _done.has(t):
		_done[t] = true
		return true
	return false
