extends Node
## 程序化音效：启动时把每个音效“合成”成一段声音，之后直接播放。
## （原型用 WebAudio 实时合成；这里预先渲染，手机和网页上更省电、更稳定。）

const RATE := 22050
const MASTER := 0.55
enum { SINE, SQUARE, TRI, SAW }

var lib := {}
var pool: Array[AudioStreamPlayer] = []
var _next := 0
var _buf := PackedFloat32Array()
var amb: AudioStreamPlayer
var tide_pl: AudioStreamPlayer
var muted := false
const PENTA := [523.3, 587.3, 659.3, 784.0, 880.0, 1046.5, 1174.7, 1318.5]

func _ready() -> void:
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	_build()
	amb = AudioStreamPlayer.new()
	add_child(amb)
	amb.stream = _ambient()
	amb.play()
	tide_pl = AudioStreamPlayer.new()
	add_child(tide_pl)
	tide_pl.stream = _tide_drone()
	tide_pl.volume_db = -80.0
	tide_pl.play()

func play(name: String, pitch := 1.0) -> void:
	if muted or not lib.has(name):
		return
	var p := pool[_next]
	_next = (_next + 1) % pool.size()
	p.stream = lib[name]
	p.pitch_scale = pitch
	p.play()

func set_tide(t: float) -> void:
	if tide_pl:
		tide_pl.volume_db = linear_to_db(maxf(t, 0.0001))

func set_duck(k: float) -> void:
	var cur := db_to_linear(AudioServer.get_bus_volume_db(0))
	AudioServer.set_bus_volume_db(0, linear_to_db(lerpf(cur, k, 0.1)))

func toggle_mute() -> bool:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	return muted

# ---------- 合成 ----------
func _new(d: float) -> void:
	_buf = PackedFloat32Array()
	_buf.resize(int(d * RATE))

func _tone(f: float, d: float, type: int, v: float, f2 := -1.0, delay := 0.0) -> void:
	v *= MASTER
	var st := int(delay * RATE)
	var n := int((d + 0.05) * RATE)
	var ph := 0.0
	for i in n:
		var idx := st + i
		if idx >= _buf.size():
			break
		var t := float(i) / RATE
		var fr := f
		if f2 > 0.0:
			fr = f * pow(f2 / f, minf(t, d) / d)
		ph += fr / RATE
		ph -= floorf(ph)
		var w := 0.0
		match type:
			SINE: w = sin(TAU * ph)
			SQUARE: w = 1.0 if ph < 0.5 else -1.0
			TRI: w = 4.0 * absf(ph - 0.5) - 1.0
			_: w = 2.0 * ph - 1.0
		var g := 0.0
		if t < 0.008:
			g = 0.0001 * pow(v / 0.0001, t / 0.008)
		else:
			g = v * pow(0.0001 / v, minf(1.0, (t - 0.008) / maxf(0.001, d - 0.008)))
		_buf[idx] += w * g

func _noise(d: float, v: float, fc := 1200.0, q := 1.0, delay := 0.0, lowpass := false) -> void:
	v *= MASTER
	var w0 := TAU * fc / RATE
	var al := sin(w0) / (2.0 * q)
	var cw := cos(w0)
	var b0: float
	var b1: float
	var b2: float
	if lowpass:
		b0 = (1.0 - cw) / 2.0
		b1 = 1.0 - cw
		b2 = b0
	else:
		b0 = al
		b1 = 0.0
		b2 = -al
	var a0 := 1.0 + al
	var a1 := -2.0 * cw
	var a2 := 1.0 - al
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var st := int(delay * RATE)
	var n := int((d + 0.05) * RATE)
	for i in n:
		var idx := st + i
		if idx >= _buf.size():
			break
		var x := randf() * 2.0 - 1.0
		var y := (b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		var t := float(i) / RATE
		_buf[idx] += y * v * pow(0.0001 / v, minf(1.0, t / d))

func _stream(loop := false, rate := RATE) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(_buf.size() * 2)
	for i in _buf.size():
		bytes.encode_s16(i * 2, int(clampf(_buf[i], -1.0, 1.0) * 32767.0))
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = _buf.size()
	return s

func _build() -> void:
	_new(0.13); _tone(880, 0.07, SQUARE, 0.035, 520); lib.shoot = _stream()
	_new(0.12); _noise(0.06, 0.12, 2400, 2); lib.hit = _stream()
	_new(0.11); _noise(0.05, 0.08, 700, 1.5); lib.rock = _stream()
	for i in PENTA.size():
		_new(0.24)
		_tone(PENTA[i], 0.18, SINE, 0.05)
		lib["dust%d" % i] = _stream()
	_new(0.31); _tone(330, 0.25, TRI, 0.08, 660); lib.ember = _stream()
	_new(0.28); _noise(0.22, 0.14, 900, 0.7); _tone(180, 0.15, SINE, 0.06, 90); lib.dash = _stream()
	_new(0.31); _tone(220, 0.25, SQUARE, 0.08, 70); _noise(0.15, 0.15, 500, 1); lib.hurt = _stream()
	_new(0.18); _tone(660, 0.08, SQUARE, 0.05, 1320); _noise(0.12, 0.1, 3000, 1); lib.kill = _stream()
	_new(0.18); _tone(2400, 0.12, SINE, 0.05, 1800); lib.ping = _stream()
	_new(0.46); _tone(1600, 0.4, SINE, 0.04, 400); lib.cold = _stream()
	_new(1.26); _tone(110, 1.2, SAW, 0.05, 55); lib.warn = _stream()
	_new(0.5); _tone(260, 0.12, SQUARE, 0.05, 200); _tone(392, 0.3, TRI, 0.06, 523, 0.08); lib.eat = _stream()
	_new(0.36); _tone(392, 0.3, SINE, 0.04); lib.note = _stream()
	_new(0.95)
	for i in 4:
		_tone(330 * pow(2.0, [0, -3, -7, -12][i] / 12.0), 0.4, TRI, 0.08, -1.0, i * 0.12)
	lib.die = _stream()
	_new(1.1)
	for i in 6:
		_tone(523 * pow(2.0, [0, 7, 12, 16, 19, 24][i] / 12.0), 0.6, SINE, 0.06, -1.0, i * 0.09)
	lib.page = _stream()

## 背景低音：四个缓慢起伏的振荡器，低通后循环（10 秒一圈，首尾相接）
func _ambient() -> AudioStreamWAV:
	var rate := 11025
	var n := rate * 10
	_buf = PackedFloat32Array()
	_buf.resize(n)
	var fs := [55.0, 82.4, 110.2, 164.8]
	var lf := [0.1, 0.2, 0.1, 0.2]
	for i in 4:
		var g0 := 0.35 if i > 1 else 0.8
		for s in n:
			var t := float(s) / rate
			var ph: float = fmod(fs[i] * t, 1.0)
			var w := (4.0 * absf(ph - 0.5) - 1.0) if i % 2 == 1 else sin(TAU * ph)
			_buf[s] += w * g0 * (1.0 + 0.3 * sin(TAU * lf[i] * t))
	_lowpass(380.0, rate, 0.05 * MASTER)
	return _stream(true, rate)

## 暗潮来临时的低沉锯齿嗡鸣
func _tide_drone() -> AudioStreamWAV:
	var rate := 11025
	var n := rate * 10
	_buf = PackedFloat32Array()
	_buf.resize(n)
	for s in n:
		var t := float(s) / rate
		_buf[s] = (2.0 * fmod(36.7 * t, 1.0) - 1.0) + (2.0 * fmod(38.1 * t, 1.0) - 1.0)
	_lowpass(160.0, rate, 0.05 * MASTER)
	return _stream(true, rate)

func _lowpass(fc: float, rate: int, gain: float) -> void:
	var w0 := TAU * fc / rate
	var al := sin(w0) / 2.0
	var cw := cos(w0)
	var b0 := (1.0 - cw) / 2.0
	var b1 := 1.0 - cw
	var a0 := 1.0 + al
	var a1 := -2.0 * cw
	var a2 := 1.0 - al
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for pass_ in 2:
		for i in _buf.size():
			var x := _buf[i]
			var y := (b0 * x + b1 * x1 + b0 * x2 - a1 * y1 - a2 * y2) / a0
			x2 = x1
			x1 = x
			y2 = y1
			y1 = y
			if pass_ == 1:
				_buf[i] = y * gain
