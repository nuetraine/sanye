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
	var args0 := OS.get_cmdline_user_args()
	for a in args0:
		if a.begins_with("--ch="):
			chapter = clampi(int(a.substr(5)), 1, NCH)
			unlocked = chapter
	_bot_god = args0.has("--god")
	var t0 := Time.get_ticks_msec()
	new_world()
	print("world generated in %d ms, rocks=%d" % [Time.get_ticks_msec() - t0, rocks.size()])
	var args := OS.get_cmdline_user_args()
	if args.has("--autoplay"):
		_autoplay = true
	if args.has("--bot"):
		_bot = true
		_autoplay = true
	if args.has("--load") and has_run():
		load_run()
		S = "play"
		print("loaded: ch=%d unlocked=%d bound=%d pens=%d" % [chapter, unlocked, P.bound, P.pens])
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
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			jp["wheel_dn"] = true
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			jp["wheel_up"] = true
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
			elif touch_btn(4).has_point(pos) and near_kiln():
				kind = "btn"
				jp[KEY_C] = true
			elif touch_btn(5).has_point(pos):
				kind = "btn"
				jp["skill"] = true
			elif skill_rect().has_point(pos):
				kind = "btn"
				jp["skill_next"] = true
			elif touch_btn(3).has_point(pos) and near_kiln() and unlocked >= 2:
				kind = "btn"
				jp[KEY_G] = true
			elif pos.x > W - 48 and pos.y > 12 and pos.y < 60:
				kind = "btn"
				jp[KEY_TAB] = true
			elif pen_rect().has_point(pos) and P.pens > 1:
				kind = "btn"
				jp[KEY_R] = true
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
			upd_bombs(dt)
			upd_world2(dt)
			upd_world3(dt)
			upd_belt(dt)
			upd_hi(dt)
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
		"chars":
			upd_chars_panel()
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
			var cn := ORDER.size()
			if pressed(KEY_W) or pressed(KEY_UP):
				codex_sel = (codex_sel + cn - 1) % cn
			if pressed(KEY_S) or pressed(KEY_DOWN):
				codex_sel = (codex_sel + 1) % cn
			if pressed(KEY_A) or pressed(KEY_LEFT):
				codex_sel = maxi(0, codex_sel - 10)
			if pressed(KEY_D) or pressed(KEY_RIGHT):
				codex_sel = mini(cn - 1, codex_sel + 10)
			var mp := ppointer()
			var mi := -1
			for i in cn:
				if codex_rect(i).has_point(mp):
					mi = i
			if mi >= 0 and (mouse_moved or click_q):
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
				if chapter < NCH:
					goto_chapter(chapter + 1)
					toast("想回前面的章节，在炉灯边按 G（或点「翻章」）。", C_DIM, 6)
				else:
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
	rock_mat.set_shader_parameter("sun", SUNE)
	rock_mat.set_shader_parameter("amb", AMB)
	rock_mat.set_shader_parameter("time", T)
	bg_mat.set_shader_parameter("cam", cam_pos)
	bg_mat.set_shader_parameter("tide", TIDE)
	bg_mat.set_shader_parameter("time", T)
	var cold := (25.0 - P.warm) / 25.0 if S == "play" and P.warm < 25 else 0.0
	vig_mat.set_shader_parameter("tide", maxf(TIDE, zone_dark * 0.7))
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
		var n := 0
		for t in ORDER:
			if is_boss_t(t):
				continue
			var c := mk(t, -125 + (n % 6) * 50, -62 + (n / 6) * 50)
			n += 1
			c.hx = c.x
			c.hy = c.y
			init_c(c)
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
				"worm":
					c.ang = 0.3
					for i in c.seg.size():
						c.seg[i] = Vector2(c.x - (i + 1) * 3.4, c.y - sin(i * 0.8) * 2)
				"wisp":
					c.open = 1
				"tick":
					c.st = "tired"
					c.tm = 99
		var bl := mk("blotlet", 138, 58)
		bl.hx = bl.x
		bl.hy = bl.y
		var b := boss()
		cr.append(b)
		b.st = "fight"
		b.burst_t = 99
		for i in b.seg.size():
			b.seg[i] = Vector2(64 + i * 5, 22 + sin(i * 0.7) * 6)
		P.hp = 99
		P.inv = 99
		P.carry = [0]
		P.bound = 1
		P.dust = 37
		UP.pen = 4
		P.pens = 5
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--pen="):
				P.pen = int(a.substr(6))
		for i in 30:
			add_pick(-60 + randf() * 120, 30 + randf() * 30, "dust" if i % 3 else "ember")
		var w := Pick.new()
		w.x = -30
		w.y = 30
		w.k = "word"
		w.age = -99
		PK.append(w)
		var be := Beacon.new()
		be.x = -70
		be.y = 20
		BEA.append(be)
		LAMPS.append({"x": -100.0, "y": 20.0, "lit": 60.0})
		LAMPS.append({"x": 105.0, "y": 15.0, "lit": 0.0})
		INK.append(Vector3(30, 78, 24))
		HZ.append({"x": 0.0, "y": -20.0, "a": 0.4, "t": 9.0, "w": 5.0, "len": 80.0, "dmg": true})
	for c in cr:
		c.cd = 9
		c.tm = maxf(c.tm, 1.0)
		if not is_boss(c):
			c.x = c.hx
			c.y = c.hy
	for p in PK:
		p.age = minf(p.age, 0.0)
	var bb := boss()
	if bb:
		bb.x = 75
		bb.y = 14
		bb.vx = 0
		bb.vy = 0
		bb.burst_t = 99
	if _ap_t > 1.5:
		P.x = 0
		P.y = 30
		P.vx = 0
		P.vy = 0
	_ap_aim = Vector2(1, -0.3) * 60
	_ap_fire = _ap_t > 2.5 and (P.pen != 4 or _ap_t < 3.05)
	if _once(3.2):
		get_viewport().get_texture().get_image().save_png("user://shot_gallery.png")
	if _ap_t > 3.5:
		get_tree().quit()

func _autoplay_step(dt: float) -> void:
	_ap_t += dt
	if OS.get_cmdline_user_args().has("--gallery"):
		_gallery_step()
		return
	var shots := _shots if chapter == 1 else (_shots2 if chapter == 2 else (_shots3 if chapter == 3 else _shotshi))
	for k in shots.keys():
		if _ap_t >= k:
			var img := get_viewport().get_texture().get_image()
			img.save_png("user://shot_%s.png" % shots[k])
			print("shot ", shots[k], " S=", S)
			shots.erase(k)
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
		if OS.get_cmdline_user_args().has("--bigbag"):
			var ks: Array = WD.chars.keys()
			for i in 40:
				P.bag.append({"c": ks[randi() % ks.size()], "gold": randf() < 0.15})
		calc_loadout()
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--pen="):
				UP.pen = 4
				P.pens = 5
				P.pen = int(a.substr(6))
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
	if _once(7.3) and OS.get_cmdline_user_args().has("--chars"):
		jp[KEY_E] = true
	if _once(7.5) and OS.get_cmdline_user_args().has("--chars"):
		jp[KEY_C] = true
		_shots[7.9] = "chars"
	if _once(8.0) and OS.get_cmdline_user_args().has("--chars"):
		jp[KEY_C] = true
		set_char(int(Time.get_ticks_msec()) % 3 + 1)
		return
	if _once(8.0):
		jp[KEY_E] = true
		seen["hush"] = true
		seen["mite"] = true
	if _once(8.3):
		jp[KEY_TAB] = true
		codex_sel = 5
		if chapter >= 4:
			for t in ORDER:
				seen[t] = true
			codex_sel = ORDER.size() - 1
	if chapter >= 4 and _ap_t > 8.6 and _ap_t < 9.2:
		S = "codex"
	if chapter == 2 and _ap_t > 9.9:
		_ap2_step()
		return
	if chapter == 3 and _ap_t > 9.9:
		_ap3_step()
		return
	if OS.get_cmdline_user_args().has("--mobs") and _ap_t > 9.9:
		_mobs_step()
		return
	if chapter >= 4 and _ap_t > 9.9:
		_aphi_step()
		return
	if OS.get_cmdline_user_args().has("--penfx") and _ap_t > 9.9:
		_penfx_step()
		return
	if OS.get_cmdline_user_args().has("--belt") and _ap_t > 9.9:
		_belt_step()
		return
	if OS.get_cmdline_user_args().has("--tide") and _ap_t > 9.9:
		_tide_step()
		return
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
			_ap_fire = bd < 120 and (P.pen != 4 or fmod(_ap_t, 1.3) < 1.0)
			joy = _ap_aim.normalized() * (0.8 if bd > 60 else 0.0)
	elif S == "play" and _ap_t > 14.0 and serp:
		if _once(15.5) and OS.get_cmdline_user_args().has("--p3"):
			serp.hp = 10
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
	unlocked = NCH
	if S == "title" or S == "intro" or S == "ending":
		click_q = true
		if S == "intro":
			intro_t = 99
		return
	if S == "chars":
		jp[[KEY_A, KEY_D, KEY_ENTER, KEY_C][randi() % 4]] = true
		return
	if S == "menu":
		jp[KEY_1 + randi() % 9] = true
		if randf() < 0.05:
			jp[KEY_E] = true
		return
	if S == "words":
		if randf() < 0.1:
			jp[KEY_F] = true
		return
	if S == "codex":
		jp[[KEY_W, KEY_S, KEY_A, KEY_D][randi() % 4]] = true
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
				if pg.state == "free" or (pg.state == "sealed" and ch_bound() >= 2):
					goal = Vector2(pg.x, pg.y)
					break
		else:
			goal = Vector2(P.x, P.y) + Vector2.from_angle(randf() * TAU) * 300
		_bot_dir = (goal - Vector2(P.x, P.y)).normalized().rotated((randf() - 0.5) * 0.8)
		if randf() < 0.2:
			jp[[KEY_Q, KEY_B, KEY_F, KEY_TAB, KEY_E, KEY_SPACE, KEY_R, KEY_C, KEY_X, KEY_Z, KEY_X, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5][randi() % 14]] = true
		if near_kiln() and randf() < 0.5:
			jp[KEY_E] = true
		if near_kiln() and randf() < 0.04:
			jp[KEY_G] = true
		if randf() < 0.1:
			P.dust += 40
		if randf() < 0.05:
			var ks: Array = WD.chars.keys()
			give_word(ks[randi() % ks.size()], randf() < 0.3)
		if randf() < 0.03:
			for i in P.slots.size():
				P.slots[i] = null
		if _bot_god and P.hp < 3:
			P.hp = P.maxhp
			P.warm = P.maxwarm
	joy = _bot_dir
	var tgt: Creature = null
	var bd := 140.0
	for c in cr:
		var d := Vector2(c.x - P.x, c.y - P.y).length()
		if d < bd and can_hit(c):
			bd = d
			tgt = c
	_ap_aim = Vector2(tgt.x - P.x, tgt.y - P.y) if tgt else _bot_dir * 60
	_ap_fire = P.pen != 4 or fmod(_bot_t, 1.4) < 1.0
	if OS.get_cmdline_user_args().has("--perf") and Engine.get_physics_frames() % 120 == 0:
		print("perf: physics %.2f ms, process %.2f ms, fps %d, draws %d, cr %d, pt %d" % [Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, Performance.get_monitor(Performance.TIME_PROCESS) * 1000, Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), cr.size(), PT.size()])
	if _bot_t > _bot_secs:
		print("bot done: t=%.0f gt=%.0f ch=%d deaths=%d bound=%d dust=%d kills=%d tides=%d sprs=%d rocks=%d seen=%s" % [_bot_t, gt, chapter, P.deaths, P.bound, P.dust_total, P.kills, tides, sprs.size(), rocks.size(), seen.keys()])
		get_tree().quit()

func _once(t: float) -> bool:
	if _ap_t > t and not _done.has(t):
		_done[t] = true
		return true
	return false

func _ap2_step() -> void:
	# 第二章的自动截图：书架迷宫、熄灯区、墨海、首领
	if _once(10.0):
		jp[KEY_TAB] = true
		var best: Rock = null
		for r in rocks:
			if r.box and r.hw > r.hh and (best == null or Vector2(r.x - 650, r.y - 60).length() < Vector2(best.x - 650, best.y - 60).length()):
				best = r
		P.x = best.x - 20
		P.y = best.y + 22
		cam_pos = Vector2(P.x, P.y)
		_ap_aim = Vector2(20, -22)
		init_c(mk("worm", P.x + 60, P.y - 30))
		init_c(mk("comma", P.x - 60, P.y - 20))
		P.hp = 99
	if _once(12.4):
		var l: Dictionary = LAMPS[0]
		P.x = l.x + 26
		P.y = l.y + 6
		cam_pos = Vector2(P.x, P.y)
		_ap_aim = Vector2(-26, -16)
		mk("wisp", l.x - 20, l.y - 12)
		mk("wisp", l.x + 90, l.y - 40)
	if _once(14.8):
		var q: Vector3 = INK[0]
		P.x = q.x + q.z + 16
		P.y = q.y
		cam_pos = Vector2(P.x, P.y)
		_ap_aim = Vector2(-1, 0.2) * 60
		init_c(mk("blot", q.x - 10, q.y - 20))
		init_c(mk("blot", q.x + 10, q.y + 30))
	if _once(17.0):
		P.x = PAGES[2].x + 110
		P.y = PAGES[2].y + 70
		cam_pos = Vector2(P.x, P.y)
	if _ap_t > 17.0 and redact:
		_ap_aim = Vector2(redact.x - P.x, redact.y - P.y)
		P.hp = 99
	_ap_fire = _ap_t > 10.3
	joy = Vector2.ZERO
	if _ap_t > 23.5:
		get_tree().quit()

var _bot_god := false
var _shots2 := {1.0: "title", 5.2: "hall", 9.0: "codex", 12.2: "stacks", 14.6: "dark", 16.8: "ink", 20.6: "boss", 22.6: "boss2"}
var _shots3 := {1.0: "title", 5.2: "tower", 9.0: "codex3", 12.2: "wind", 14.8: "gear", 17.4: "flare", 18.6: "flare2", 22.9: "boss3", 24.0: "boss3b", 25.9: "skills"}

func _ap3_step() -> void:
	# 第三章的自动截图：页风回廊、齿轮钟室、烛焰台、装订师、技能
	P.hp = 99
	if _once(10.0):
		S = "play"
		var q: Dictionary = WINDS[WINDS.size() - 1]
		P.x = q.x - cos(q.a) * q.len * 0.6
		P.y = q.y - sin(q.a) * q.len * 0.6
		cam_pos = Vector2(P.x, P.y)
		for i in 3:
			var c := mk("dove", P.x + 60 + i * 10, P.y - 40 + i * 6)
			c.hx = c.x
			c.hy = c.y
			c.off = i
	if _once(12.6):
		var q: Dictionary = CLOCKS[0]
		P.x = q.x + q.r + 22
		P.y = q.y + 10
		cam_pos = Vector2(P.x, P.y)
		_ap_aim = Vector2(-1, 0) * 60
		var c := mk("tick", P.x + 20, P.y + 30)
		init_c(c)
		var c2 := mk("tick", P.x - 10, P.y - 34)
		init_c(c2)
		c2.st = "tired"
		c2.tm = 99
		init_c(mk("stamp", P.x + 50, P.y - 10))
	if _once(15.2):
		var best: Rock = null
		for r in rocks:
			if r.zone == "flare" and r.R > 14 and (best == null or Vector2(r.x, r.y + 500).length() < Vector2(best.x, best.y + 500).length()):
				best = r
		P.x = best.x + 30
		P.y = best.y + best.R + 8
		cam_pos = Vector2(P.x - 20, P.y - 20)
		for i in 3:
			init_c(mk("cinder", P.x + 40 + i * 20, P.y - 30 - i * 10))
		flare_st = 0
		flare_t = 0.5
		_ap_aim = Vector2(1, -0.5) * 60
	if _once(19.0):
		P.x = PAGES[2].x + 110
		P.y = PAGES[2].y + 70
		cam_pos = Vector2(P.x, P.y)
		flare_st = 0
		flare_t = 99
	if _ap_t > 19.0 and binder:
		_ap_aim = Vector2(binder.x - P.x, binder.y - P.y)
		if _once(22.2):
			binder.burst_t = 0
			binder.sing = 0
			binder.off = 1
	if _once(24.6):
		UP.seal = 3
		P.sk = 1
		P.sk_cd = 0
		jp[KEY_X] = true
	if _once(25.4):
		P.sk = 0
		P.sk_cd = 0
		jp[KEY_X] = true
	if _once(26.4) and binder:
		kill(binder, true)
	if _once(27.0):
		P.carry = [0, 1, 2]
		for pg in PAGES:
			pg.state = "carried"
		P.x = 0
		P.y = 20
		cam_pos = Vector2(0, 20)
	if _once(35.0):
		get_viewport().get_texture().get_image().save_png("user://shot_ending3.png")
		print("ending3 S=%s unlocked=%d dashk=%.2f skk=%.2f" % [S, unlocked, P.dashk, P.skk])
	_ap_fire = _ap_t > 10.3 and _ap_t < 24.4
	joy = Vector2.ZERO
	if _ap_t > 35.5:
		get_tree().quit()

## 测试用：暗潮第三次（冷息、霜棱、扑灯母都会来）
func _tide_step() -> void:
	P.hp = 99
	if _once(10.0):
		S = "play"
		P.x = 200
		P.y = 100
		jp[KEY_B] = true
		tides = 2
		tide_t = 113
		TIDE = 1.0
		for k in [12.5, 14.0, 15.5, 17.0]:
			_shots[k] = "tide_%d" % int(k * 10)
	var t := near_c(P.x, P.y, 140.0)
	_ap_aim = Vector2(t.x - P.x, t.y - P.y) if t else Vector2(1, 0) * 60
	_ap_fire = fmod(_ap_t, 2.0) < 1.2
	joy = Vector2(sin(_ap_t * 0.7), cos(_ap_t * 0.5)) * 0.4
	if _ap_t > 17.5:
		print("tide test: chill=", count_type("chill"), " icicle=", count_type("icicle"), " mothq=", count_type("mothq"), " moth=", count_type("moth"))
		get_tree().quit()

## 测试用：刻刀 / 砚雷 / 墨线 配不同的句子
const _PENFX := [[2, "穿环连"], [2, "雨弹裂"], [3, "雨回环"], [3, "针弹寻"], [4, "雨弹连"], [4, "环寻裂"]]
var _pf_spot := Vector2.ZERO
func _penfx_step() -> void:
	P.hp = 99
	var stage := int((_ap_t - 10.0) / 2.5)
	if stage >= _PENFX.size():
		get_tree().quit()
		return
	var t0 := 10.0 + stage * 2.5
	if _once(t0):
		S = "play"
		if stage == 0:
			var best := 1e9
			for k in 200:
				var a := randf() * TAU
				var q := Vector2(cos(a), sin(a)) * (240 + randf() * 200)
				var n := 0.0
				for r in rocks:
					var dd := Vector2(r.x, r.y).distance_to(q)
					if dd < 110:
						n += 110 - dd
				if n < best:
					best = n
					_pf_spot = q
		for c in cr:
			if Vector2(c.x, c.y).distance_to(_pf_spot) < 200:
				c.dead = true
		P.x = _pf_spot.x
		P.y = _pf_spot.y
		P.vx = 0
		P.vy = 0
		cam_pos = _pf_spot
		var cfg: Array = _PENFX[stage]
		P.slots = []
		for ch in String(cfg[1]):
			P.slots.append({"c": ch, "gold": false})
		calc_loadout()
		UP.pen = 4
		P.pens = 5
		P.pen = cfg[0]
		for i in 6:
			var a := -0.9 + i * 0.36
			var c := mk("hush", P.x + cos(a) * (45 + (i % 2) * 30), P.y + sin(a) * (45 + (i % 2) * 30))
			c.hp = 40
			c.hx = c.x
			c.hy = c.y
		if stage % 2 == 1:
			for i in 4:
				add_eb(P.x + 70, P.y - 20 + i * 12, -60, 0, 3.0, EMBER)
		_shots[t0 + (1.36 if cfg[0] == 4 else 1.0)] = "pen_%d" % stage
		print("penfx ", stage, " pen=", cfg[0], " ", cfg[1], " syn=", syn_lines())
	P.vx = 0
	P.vy = 0
	P.x = _pf_spot.x
	P.y = _pf_spot.y
	_ap_aim = Vector2(1, 0) * 60
	if P.pen == 4:
		_ap_fire = _ap_t - t0 < 1.3
	else:
		_ap_fire = true

## 测试用：矿脉带、各种小行星、石蜗 / 钻岩虫 / 彗尾鱼、流星雨
func _belt_step() -> void:
	P.hp = 99
	if _once(10.0):
		S = "play"
		# 1) 一排各种样子的石头
		var base := Vector2(-260, -60)
		var kinds := ["lump", "potato", "crater", "shale", "magma", "iron", "crystal", "geode", "moss"]
		for r in rocks.duplicate():
			if Vector2(r.x, r.y).distance_to(base + Vector2(0, 10)) < 140:
				rocks.erase(r)
				grid_del(r)
				r.spr.queue_free()
				r.spr = null
		for i in kinds.size():
			var rr := Rock.build(roundi(base.x + (i % 5 - 2) * 46), roundi(base.y + (i / 5) * 50 - 10), 15 if kinds[i] != "potato" else 17, "belt", R0, kinds[i])
			rocks.append(rr)
			grid_add(rr)
			_make_sprite(rr)
		P.x = base.x + 23
		P.y = base.y + 15
		cam_pos = Vector2(P.x, P.y)
		for c in cr:
			c.dead = true
		_shots[11.0] = "rocks"
	if _once(11.5):
		# 2) 矿脉带里：石蜗、钻岩虫、彗尾鱼
		var a := 3.05
		var p := Vector2(cos(a), sin(a)) * 850
		var best: Rock = null
		for r in rocks:
			if r.zone == "belt" and r.R > 14 and not r.box and (best == null or Vector2(r.x, r.y).distance_to(p) < Vector2(best.x, best.y).distance_to(p)):
				best = r
		P.x = best.x + best.R + 40
		P.y = best.y + 10
		cam_pos = Vector2(P.x - 20, P.y)
		for i in 2:
			var c := mk("snail", best.x, best.y)
			c.home = best
			c.ang = i * PI + 0.4
			c.w = 1.0
			c.st = "crawl"
		var c2 := mk("comet", P.x - 30, P.y - 60)
		c2.hx = c2.x
		c2.hy = c2.y
		var o: Rock = null
		for r in rocks:
			if r != best and r.R > 11 and not r.box and Vector2(r.x - P.x, r.y - P.y).length() < 140 and Vector2(r.x - P.x, r.y - P.y).length() > 50:
				o = r
				break
		if o:
			var c3 := mk("borer", o.x, o.y)
			c3.home = o
			c3.st = "lurk"
			c3.cd = 2.5
		_shots[12.5] = "belt_a"
		_shots[14.6] = "belt_b"
	if _once(15.0):
		met_st = 1
		met_t = 1.2
		met_a = PI * 0.75
		_shots[15.6] = "meteor_warn"
		_shots[17.0] = "meteor"
		_shots[18.0] = "meteor2"
	var t := near_c(P.x, P.y, 120.0)
	_ap_aim = Vector2(t.x - P.x, t.y - P.y) if t else Vector2(-1, 0) * 60
	_ap_fire = _ap_t > 13.0 and fmod(_ap_t, 1.5) < 0.8
	if _ap_t > 19.0:
		print("belt test: snail=", count_type("snail"), " borer=", count_type("borer"), " comet=", count_type("comet"), " zone=", zn(P.x, P.y))
		get_tree().quit()

## 第四章起的自动截图：三个区域、生物、首领的几招、通关
var _shotshi := {1.0: "title", 9.0: "codex_hi"}
func _aphi_step() -> void:
	P.hp = 99
	var ch := chapter
	var zs: Array = [["lake", "pillar", "aurora"], ["prism", "echoval", "shadow"], ["sea", "ash", "core"]][ch - 4]
	var mobs: Array = [["spider", "roller", "bat"], ["mimic", "prismbug", "shard"], ["salamander", "ashghost", "drip"]][ch - 4]
	for zi in 3:
		var t0 := 10.0 + zi * 3.0
		if _once(t0):
			S = "play"
			var a: float = [0.3, 2.2, -1.6][zi]
			var p := Vector2(cos(a), sin(a)) * 700.0
			if zi == 2 and ch == 4 and not AUR.is_empty():
				p = Vector2(-300, AUR[0].y0 + sin(T * AUR[0].sp + AUR[0].ph - 300 * 0.004) * AUR[0].amp)
			if zi == 1 and ch == 4 and not PILLARS.is_empty():
				p = Vector2(PILLARS[0].x + 30, PILLARS[0].y + 20)
				for q in PILLARS:
					if Vector2(q.x, q.y).distance_to(p) < 160:
						q.st = 2
						q.r = q.R
						q.t = 9.0
			P.x = p.x
			P.y = p.y
			cam_pos = p
			var t: String = mobs[zi]
			for i in (2 if t == "bat" else 3):
				var c := mk(t, P.x + 50 + i * 16, P.y - 30 + i * 18)
				c.hx = c.x
				c.hy = c.y
				c.off = i
				init_c(c)
			_shotshi[t0 + 1.6] = "z%d_%s" % [ch, zs[zi]]
			_shotshi[t0 + 2.6] = "z%d_%sb" % [ch, zs[zi]]
	if _once(19.0):
		P.x = PAGES[2].x + 100
		P.y = PAGES[2].y + 60
		cam_pos = Vector2(P.x, P.y)
		_shotshi[21.5] = "boss%d_a" % ch
		_shotshi[24.0] = "boss%d_b" % ch
		_shotshi[26.5] = "boss%d_c" % ch
	if _ap_t > 19.0 and bossc and bossc.st != "dead":
		_ap_aim = Vector2(bossc.x - P.x, bossc.y - P.y)
		_ap_fire = fmod(_ap_t, 1.0) < 0.6 and _ap_t > 22.0
	if _once(28.0) and bossc:
		kill(bossc, true)
	if _once(29.0):
		P.carry = [0, 1, 2]
		for pg in PAGES:
			pg.state = "carried"
		P.x = 0
		P.y = 20
		cam_pos = Vector2(0, 20)
	if _once(36.0):
		get_viewport().get_texture().get_image().save_png("user://shot_ending%d.png" % ch)
		print("ending%d S=%s unlocked=%d" % [ch, S, unlocked])
	if _ap_t > 36.5:
		get_tree().quit()

## 测试用：把第四到六章的生物和首领摆成一排拍照
func _mobs_step() -> void:
	P.hp = 99
	if _once(10.0):
		S = "play"
		for c in cr:
			c.dead = true
		var base := Vector2(0, 150)
		for r in rocks.duplicate():
			if Vector2(r.x, r.y).distance_to(base) < 190:
				rocks.erase(r)
				grid_del(r)
				r.spr.queue_free()
				r.spr = null
		var ts := ["spider", "roller", "bat", "index", "mimic", "mimic", "prismbug", "shard", "shade", "mirror", "salamander", "ashghost", "drip", "wick"]
		for i in ts.size():
			var c := mk(ts[i], base.x - 20 + (i % 5) * 52, base.y - 50 + (i / 5) * 50)
			c.hx = c.x
			c.hy = c.y
			init_c(c)
			if BOSS_T.has(ts[i]):
				c.st = "fight"
				c.burst_t = 99
			if i == 5:
				c.st = "chase"
				c.tm = 99
			if ts[i] == "roller":
				c.r = 7.0
			if ts[i] == "shade":
				c.st = "follow"
			if ts[i] == "ashghost":
				c.open = 1.0
			if ts[i] == "salamander":
				for k in 8:
					c.tr.append(c.x - 16 + k * 2.0)
					c.tr.append(c.y + sin(k * 0.9) * 2.0)
		P.x = base.x + 150
		P.y = base.y + 80
		cam_pos = base
		_shotshi[10.3] = "mobs"
		_shots[10.3] = "mobs"
	freeze_t = 9.0
	toasts.clear()
	P.x = 150
	P.y = 150
	P.vx = 0
	P.vy = 0
	if _ap_t > 11.0:
		get_tree().quit()
