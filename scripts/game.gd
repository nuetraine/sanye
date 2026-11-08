extends "res://scripts/game_hud.gd"
## 《散页 Unbound》入口：搭场景、输入、主循环、自动试玩。

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

	TRX.resize(400)
	TRY.resize(400)
	load_save()
	load_words()
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

# 输入（键盘 / 鼠标 / 触屏）
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
		mouse_moved = true
	elif e is InputEventScreenTouch:
		touch_mode = true
		var pos: Vector2 = e.position
		if e.pressed:
			click_q = true
			tap_pos = pos
			var kind := "aim"
			if S != "play":
				kind = "btn"
			elif pos.x > W - 44 and pos.y > H - 44:
				kind = "dash"
				jp["dash"] = true
			elif pos.x > W - 44 and pos.y > H - 80:
				kind = "btn"
				jp[KEY_Q] = true
			elif pos.x > W - 44 and pos.y > H - 112:
				kind = "btn"
				jp[KEY_B] = true
			elif pos.x > W - 48 and pos.y > 12 and pos.y < 60:
				kind = "btn"
				jp[KEY_TAB] = true
			elif near_kiln() and absf(pos.x - W / 2.0) < 24 and absf(pos.y - (H / 2.0 + 24)) < 10:
				kind = "btn"
				jp[KEY_E] = true
			elif pos.x < 4 + P.slots.size() * 13 and pos.y > H - 18:
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
			if S == "play" and pressed(KEY_TAB):
				S = "codex"
			elif S == "play" and pressed(KEY_F):
				S = "words"
				word_sel = -1
		"words":
			upd_words_panel()
		"menu":
			for i in range(1, SHOP.size() + 1):
				if pressed(KEY_0 + i):
					try_buy(i - 1)
			if pressed(KEY_W) or pressed(KEY_UP):
				menu_sel = (menu_sel + SHOP.size() - 1) % SHOP.size()
			if pressed(KEY_S) or pressed(KEY_DOWN):
				menu_sel = (menu_sel + 1) % SHOP.size()
			if pressed(KEY_ENTER) or pressed(KEY_SPACE):
				try_buy(menu_sel)
			var mp := pointer()
			var mi := floori((mp.y - 38) / 15.0)
			var closed := pressed(KEY_E) or pressed(KEY_ESCAPE) or pressed(KEY_TAB)
			if mp.x > 40 and mp.x < 280 and mi >= 0 and mi < SHOP.size():
				if mouse_moved or click_q:
					menu_sel = mi
				if click_q:
					try_buy(mi)
			elif click_q and (mp.y > 152 or mp.x < 36 or mp.x > 284 or mp.y < 10):
				closed = true
			if closed:
				S = "play"
		"codex":
			if pressed(KEY_W) or pressed(KEY_UP):
				codex_sel = (codex_sel + 7) % 8
			if pressed(KEY_S) or pressed(KEY_DOWN):
				codex_sel = (codex_sel + 1) % 8
			var mp := pointer()
			var mi := floori((mp.y - 34) / 16.0)
			if mp.x > 14 and mp.x < 110 and mi >= 0 and mi < 8 and (mouse_moved or click_q):
				codex_sel = mi
			elif click_q and (mp.y > 152 or mp.x < 8 or mp.x > 312):
				S = "play"
			if pressed(KEY_TAB) or pressed(KEY_ESCAPE) or pressed(KEY_E):
				S = "play"
		"dead":
			dead_t += dt
			if dead_t > 2.6:
				respawn()
		"ending":
			end_t += dt
			upd_creatures(dt)
			if end_t > 7 and (pressed(KEY_ENTER) or click_q):
				S = "play"
				free_mode = true
				toast("自由探索：残烛还在打寒颤，宇宙还有很多散页。", C_DIM, 5)
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

var _shots := {1.0: "title", 3.9: "fire", 4.6: "words", 5.2: "play", 7.0: "menu", 9.0: "codex", 13.0: "tide", 17.0: "serp", 23.0: "ending"}

func _autoplay_step(dt: float) -> void:
	_ap_t += dt
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

func _once(t: float) -> bool:
	if _ap_t > t and not _done.has(t):
		_done[t] = true
		return true
	return false
