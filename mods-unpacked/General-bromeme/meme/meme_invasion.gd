extends Control

# =============================================================================
#  「meme入侵」提示特效
#
#  每次触发随机选一种（5 选 1），全部用纯代码搭 UI + 手写动画（不依赖 Tween /
#  AnimationPlayer，避免不同引擎版本差异）：
#     0 彩虹弹跳   1 抖动爆闪   2 贴图狂欢（拿 mod 里道具贴图乱拼）
#     3 冲击波方块 4 逐字弹出
#  自己 5 秒后销毁。
#
#  以前这里是 CanvasLayer(layer=6)，会盖在暂停菜单上面；现在改成 Control，
#  由 main 扩展插到 $UI 里 PauseMenu 之前 —— 和原版 UI 一样：
#  盖住 HUD 和战斗画面，但被暂停菜单/确认弹窗盖住。
# =============================================================================

const LIFE: float = 2.0
# 默认文案；外部可以覆盖（复用同一套动画，只换字）
var TEXT: String = "meme入侵"
# ---------------------------------------------------------------------------
#  音效：汽笛 + 罐头笑声 + 礼炮（音调随机）；看着「严肃/警戒」的变体改成警笛
#  想把某个变体归到严肃那边，直接往 SERIOUS_VARIANTS 里加编号即可。
# ---------------------------------------------------------------------------
const SFX_SCRIPT_PATH: String = "res://mods-unpacked/General-bromeme/meme/meme_sfx.gd"
const SERIOUS_VARIANTS: Array = [1, 3, 5, 7, 8, 16, 17, 18]
const SFX_LOG_NAME: String = "bromeme"
# 绿色线条 / 贴图出现后很快淡出（不然整屏元素堆着太缭乱）
const QUICK_FADE_START: float = 0.85
const QUICK_FADE_TIME: float = 0.45

var _t: float = 0.0
var _variant: int = 0
var _font: Font = null
var _screen: Vector2 = Vector2(1280, 720)
var _center: Vector2 = Vector2.ZERO
var _box: Vector2 = Vector2(980, 240)

var _label: Label = null
var _shadow: Label = null
var _chars: Array = []
var _sprites: Array = []
var _sdata: Array = []
var _blocks: Array = []
var _bdata: Array = []


# 绿色线条 / 贴图通用的快速淡出：0.85s 之后开始，0.45s 内淡完
func _quick_fade() -> float:
	if _t <= QUICK_FADE_START:
		return 1.0
	return max(0.0, 1.0 - (_t - QUICK_FADE_START) / QUICK_FADE_TIME)


func setup(font: Font, screen: Vector2) -> void:
	_font = font
	_screen = screen
	_center = screen * 0.5


func play(main_node = null) -> void:
	# Control 铺满屏幕、不吃鼠标（特效只是看，不挡操作/暂停菜单）
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_variant = randi() % 20
	match _variant:
		0:
			_build_rainbow()
		1:
			_build_shake()
		2:
			_build_collage(main_node)
		3:
			_build_shockwave()
		4:
			_build_typewriter()
		5:
			_build_scanline()
		6:
			_build_blockstorm()
		7:
			_build_quake()
		8:
			_build_radar()
		9:
			_build_iconrain()
		10:
			_build_rv_rain()
		11:
			_build_rv_rise()
		12:
			_build_rv_orbit()
		13:
			_build_rv_burst()
		14:
			_build_rv_bounce()
		15:
			_build_rv_columns()
		16:
			_build_rv_frame()
		17:
			_build_rv_strobe()
		18:
			_build_rv_vortex()
		_:
			_build_rv_scale()
	_play_sfx()
	set_process(true)


# 严肃变体 → 警笛；其余 → 汽笛 + 罐头笑声 + 礼炮（三种一起放，音高各自随机）
func _play_sfx() -> void:
	var sfx_script = load(SFX_SCRIPT_PATH)
	if sfx_script == null:
		ModLoaderLog.error("meme 音效脚本加载失败：%s" % SFX_SCRIPT_PATH, SFX_LOG_NAME)
		return
	var serious: bool = SERIOUS_VARIANTS.has(_variant)
	if serious:
		sfx_script.play("siren", self)
	else:
		sfx_script.play("whistle", self)
		sfx_script.play("laugh", self)
		sfx_script.play("salute", self)
	var names: String = "警笛" if serious else "汽笛+罐头笑声+礼炮"
	ModLoaderLog.info("meme 入侵音效：变体 %d → %s" % [_variant, names], SFX_LOG_NAME)


# -----------------------------------------------------------------------------
#  基础构件
# -----------------------------------------------------------------------------

func _make_font(size: int) -> Font:
	if _font == null:
		return null
	var f = _font.duplicate()
	if f is DynamicFont:
		f.size = size
		f.use_filter = true
		f.use_mipmaps = true
	return f


func _make_label(text: String, size: int, color: Color, outline: int = 12) -> Label:
	var l := Label.new()
	l.text = text
	l.align = Label.ALIGN_CENTER
	l.valign = Label.VALIGN_CENTER
	l.rect_size = _box
	l.rect_pivot_offset = _box * 0.5
	l.rect_position = _center - _box * 0.5
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := _make_font(size)
	if f != null:
		l.add_font_override("font", f)
	l.add_color_override("font_color", color)
	l.add_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_constant_override("outline_size", outline)
	add_child(l)
	return l


func _make_block(color: Color, size: Vector2, pos: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.rect_size = size
	r.rect_pivot_offset = size * 0.5
	r.rect_position = pos - size * 0.5
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _mod_icons() -> Array:
	var out: Array = []
	for item in ItemService.items:
		if item == null:
			continue
		if str(item.my_id).begins_with("item_bromeme_") and item.icon != null:
			out.append(item.icon)
	return out


# 原版（以及别的 mod）的道具贴图：用来做荒诞拼贴
func _vanilla_icons() -> Array:
	var out: Array = []
	for item in ItemService.items:
		if item == null:
			continue
		if str(item.my_id).begins_with("item_bromeme_"):
			continue
		if item.icon != null:
			out.append(item.icon)
	return out


# 放一张随机贴图，返回它（位置按中心点给）
func _add_icon(icons: Array, size: float, center_pos: Vector2) -> TextureRect:
	var s := TextureRect.new()
	s.texture = icons[randi() % icons.size()]
	s.expand = true
	s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	s.rect_size = Vector2(size, size)
	s.rect_pivot_offset = s.rect_size * 0.5
	s.rect_position = center_pos - s.rect_size * 0.5
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(s)
	_sprites.append(s)
	return s


# -----------------------------------------------------------------------------
#  0 彩虹弹跳
# -----------------------------------------------------------------------------

func _build_rainbow() -> void:
	_shadow = _make_label(TEXT, 120, Color(0.1, 0.05, 0.2, 0.85), 16)
	_label = _make_label(TEXT, 120, Color(1, 1, 1, 1), 12)
	for i in 8:
		var ang: float = TAU * float(i) / 8.0
		var b := _make_block(Color(1, 1, 1, 0.25), Vector2(26, 26), _center + Vector2(cos(ang), sin(ang)) * 120.0)
		_blocks.append(b)
		_bdata.append([ang])


func _update_rainbow(delta: float) -> void:
	var intro: float = min(1.0, _t / 0.45)
	var bounce: float = 0.15 + 0.85 * (1.0 - pow(1.0 - intro, 3.0))
	var wob: float = 1.0 + 0.06 * sin(_t * 9.0)
	if _label != null:
		_label.rect_scale = Vector2.ONE * (bounce * wob)
		_label.rect_rotation = sin(_t * 4.0) * 0.04
		var hue: float = fmod(_t * 0.45, 1.0)
		_label.add_color_override("font_color", Color.from_hsv(hue, 0.75, 1.0))
	if _shadow != null:
		_shadow.rect_scale = Vector2.ONE * (bounce * wob * 1.16)
		_shadow.rect_rotation = _label.rect_rotation if _label != null else 0.0
		_shadow.add_color_override("font_color", Color(0.35, 0.1, 0.5, 0.55))
	for i in _blocks.size():
		var b: ColorRect = _blocks[i]
		if b == null:
			continue
		var ang: float = float(_bdata[i][0]) + _t * 1.6
		var radius: float = 130.0 + 40.0 * sin(_t * 3.0 + i)
		b.rect_position = _center + Vector2(cos(ang), sin(ang)) * radius - b.rect_size * 0.5
		b.rect_rotation = rad2deg(_t * 2.0 + i)
		b.color = Color.from_hsv(fmod(_t * 0.45 + float(i) / 8.0, 1.0), 0.8, 1.0, 0.85)


# -----------------------------------------------------------------------------
#  1 抖动爆闪
# -----------------------------------------------------------------------------

func _build_shake() -> void:
	_label = _make_label(TEXT, 128, Color(1, 0.2, 0.2, 1), 14)
	for i in 4:
		var b := _make_block(Color(1, 0, 0, 0.5), Vector2(_screen.x * 0.5, 8), _center + Vector2(0, (i - 1.5) * 60.0))
		_blocks.append(b)
		_bdata.append([(i - 1.5) * 60.0])


func _update_shake(delta: float) -> void:
	var p: float = clamp(_t / LIFE, 0.0, 1.0)
	var power: float = 22.0 * (1.0 - p)
	if _label != null:
		_label.rect_position = _center - _box * 0.5 + Vector2(rand_range(-power, power), rand_range(-power, power))
		_label.rect_rotation = rand_range(-0.07, 0.07)
		var flash: bool = int(_t * 16.0) % 2 == 0
		_label.add_color_override("font_color", Color(1, 0.15, 0.15, 1) if flash else Color(1, 1, 1, 1))
		_label.rect_scale = Vector2.ONE * (1.0 + 0.05 * sin(_t * 30.0))
	for i in _blocks.size():
		var b: ColorRect = _blocks[i]
		if b == null:
			continue
		var y: float = float(_bdata[i][0])
		b.rect_position = _center + Vector2(rand_range(-power * 2.0, power * 2.0), y) - b.rect_size * 0.5
		b.color = Color(1, 0.1, 0.1, 0.35 + 0.35 * abs(sin(_t * 8.0)))


# -----------------------------------------------------------------------------
#  2 贴图狂欢：拿 mod 里的道具贴图到处乱飞
# -----------------------------------------------------------------------------

func _build_collage(main_node = null) -> void:
	var icons: Array = _mod_icons()
	_label = _make_label(TEXT, 110, Color(1, 1, 0.85, 1), 12)
	if icons.empty():
		return
	for i in 26:
		var s := TextureRect.new()
		s.texture = icons[randi() % icons.size()]
		s.expand = true
		s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var size: float = rand_range(52.0, 118.0)
		s.rect_size = Vector2(size, size)
		s.rect_pivot_offset = s.rect_size * 0.5
		s.rect_position = Vector2(rand_range(0.0, _screen.x - size), rand_range(0.0, _screen.y - size))
		s.modulate = Color(1, 1, 1, 0.0)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(s)
		_sprites.append(s)
		_sdata.append([
			Vector2(rand_range(-260.0, 260.0), rand_range(-260.0, 260.0)),
			rand_range(-220.0, 220.0),
			rand_range(0.0, 0.35),
		])


func _update_collage(delta: float) -> void:
	if _label != null:
		_label.rect_scale = Vector2.ONE * (1.0 + 0.08 * sin(_t * 7.0))
		_label.add_color_override("font_color", Color.from_hsv(fmod(_t * 0.6, 1.0), 0.35, 1.0))
	for i in _sprites.size():
		var s: TextureRect = _sprites[i]
		if s == null:
			continue
		var d: Array = _sdata[i]
		var vel: Vector2 = d[0]
		var pos: Vector2 = s.rect_position + vel * delta
		var size: Vector2 = s.rect_size
		if pos.x < -size.x:
			pos.x = _screen.x
		if pos.x > _screen.x:
			pos.x = -size.x
		if pos.y < -size.y:
			pos.y = _screen.y
		if pos.y > _screen.y:
			pos.y = -size.y
		s.rect_position = pos
		s.rect_rotation = rad2deg(float(d[1]) * _t)
		var fade_in: float = min(1.0, max(0.0, (_t - float(d[2])) / 0.35))
		var fade_out: float = 1.0 if _t < LIFE - 0.35 else max(0.0, (LIFE - _t) / 0.35)
		s.modulate = Color(1, 1, 1, fade_in * fade_out)


# -----------------------------------------------------------------------------
#  3 冲击波方块
# -----------------------------------------------------------------------------

func _build_shockwave() -> void:
	_label = _make_label(TEXT, 120, Color(1, 1, 1, 1), 12)
	for i in 10:
		var hue: float = float(i) / 10.0
		var b := _make_block(Color.from_hsv(hue, 0.85, 1.0, 0.9), Vector2(90, 90), _center)
		_blocks.append(b)
		_bdata.append([TAU * float(i) / 10.0, rand_range(240.0, 420.0), rand_range(1.0, 2.2)])


func _update_shockwave(delta: float) -> void:
	if _label != null:
		var intro: float = min(1.0, _t / 0.35)
		var sc: float = 4.0 - 3.0 * (1.0 - pow(1.0 - intro, 2.0))
		_label.rect_scale = Vector2.ONE * sc
		if _t > 0.4:
			var power: float = 8.0 * max(0.0, 1.0 - (_t - 0.4) / 1.2)
			_label.rect_position = _center - _box * 0.5 + Vector2(rand_range(-power, power), rand_range(-power, power))
	for i in _blocks.size():
		var b: ColorRect = _blocks[i]
		if b == null:
			continue
		var d: Array = _bdata[i]
		var ang: float = float(d[0]) + _t * float(d[2])
		var radius: float = float(d[1]) * min(1.0, _t / 1.6) + 40.0 * _t
		b.rect_position = _center + Vector2(cos(ang), sin(ang)) * radius - b.rect_size * 0.5
		b.rect_rotation = rad2deg(_t * float(d[2]) * 2.0)
		b.color = Color(b.color.r, b.color.g, b.color.b, 0.9 * _quick_fade())


# -----------------------------------------------------------------------------
#  4 逐字弹出
# -----------------------------------------------------------------------------

func _build_typewriter() -> void:
	var n: int = TEXT.length()
	var step: float = min(180.0, _screen.x * 0.8 / float(max(1, n)))
	var start_x: float = _center.x - step * float(n - 1) * 0.5
	for i in n:
		var ch: String = TEXT[i]
		var l := _make_label(ch, 110, Color(1, 1, 1, 1), 12)
		l.rect_size = Vector2(step, 200.0)
		l.rect_pivot_offset = l.rect_size * 0.5
		l.rect_position = Vector2(start_x + step * float(i), _center.y) - l.rect_size * 0.5
		l.rect_scale = Vector2(0.01, 0.01)
		_chars.append(l)


func _update_typewriter(delta: float) -> void:
	for i in _chars.size():
		var l: Label = _chars[i]
		if l == null:
			continue
		var t: float = _t - float(i) * 0.13
		if t <= 0.0:
			continue
		var intro: float = min(1.0, t / 0.28)
		# 简单回弹
		var sc: float = 1.0 + 0.5 * sin(PI * intro) * (1.0 - intro)
		l.rect_scale = Vector2(sc, sc)
		var hue: float = fmod(float(i) * 0.12 + _t * 0.5, 1.0)
		l.add_color_override("font_color", Color.from_hsv(hue, 0.6, 1.0))
		if _t > 1.4:
			l.rect_position += Vector2(rand_range(-6.0, 6.0), rand_range(-6.0, 6.0))
			l.rect_rotation = rad2deg(rand_range(-0.06, 0.06))


# -----------------------------------------------------------------------------
#  主循环
# -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	match _variant:
		0:
			_update_rainbow(delta)
		1:
			_update_shake(delta)
		2:
			_update_collage(delta)
		3:
			_update_shockwave(delta)
		4:
			_update_typewriter(delta)
		5:
			_update_scanline(delta)
		6:
			_update_blockstorm(delta)
		7:
			_update_quake(delta)
		8:
			_update_radar(delta)
		9:
			_update_iconrain(delta)
		10:
			_update_rv_rain(delta)
		11:
			_update_rv_rise(delta)
		12:
			_update_rv_orbit(delta)
		13:
			_update_rv_burst(delta)
		14:
			_update_rv_bounce(delta)
		15:
			_update_rv_columns(delta)
		16:
			_update_rv_frame(delta)
		17:
			_update_rv_strobe(delta)
		18:
			_update_rv_vortex(delta)
		_:
			_update_rv_scale(delta)

	if _t >= LIFE:
		queue_free()


# -----------------------------------------------------------------------------
#  5 扫描线
# -----------------------------------------------------------------------------

func _build_scanline() -> void:
	_label = _make_label(TEXT, 118, Color(1, 1, 1, 1), 12)
	for i in 7:
		var y: float = _screen.y * float(i) / 7.0
		var b := _make_block(Color(0.4, 1.0, 0.6, 0.7), Vector2(_screen.x, 16), Vector2(_screen.x * 0.5, y))
		_blocks.append(b)
		_bdata.append([y])


func _update_scanline(delta: float) -> void:
	for i in _blocks.size():
		var b: ColorRect = _blocks[i]
		if b == null:
			continue
		var y: float = fmod(float(_bdata[i][0]) + _t * 540.0, _screen.y + 40.0) - 20.0
		b.rect_position = Vector2(0, y - b.rect_size.y * 0.5)
		b.color = Color(0.35, 1.0, 0.55, 0.3 + 0.35 * abs(sin(_t * 6.0 + float(i))))
	if _label != null:
		var flash: bool = int(_t * 14.0) % 2 == 0
		_label.add_color_override("font_color", Color(0.55, 1.0, 0.72, 1) if flash else Color(1, 1, 1, 1))
		_label.rect_position = _center - _box * 0.5 + Vector2(rand_range(-7.0, 7.0) if flash else 0.0, 0)
		_label.rect_scale = Vector2.ONE


# -----------------------------------------------------------------------------
#  6 方块风暴
# -----------------------------------------------------------------------------

func _build_blockstorm() -> void:
	_label = _make_label(TEXT, 120, Color(1, 0.9, 0.4, 1), 12)
	_label.rect_scale = Vector2.ONE * 6.0
	for i in 22:
		var size: float = rand_range(18.0, 54.0)
		var pos := Vector2(rand_range(0.0, _screen.x), rand_range(0.0, _screen.y))
		var b := _make_block(Color.from_hsv(randf(), 0.8, 1.0, 0.9), Vector2(size, size), pos)
		_blocks.append(b)
		var dir: Vector2 = (pos - _center)
		if dir.length() < 1.0:
			dir = Vector2.RIGHT
		_bdata.append([rand_range(0.0, 0.35), rand_range(-6.0, 6.0), pos.x, pos.y, dir.normalized().x, dir.normalized().y])


func _update_blockstorm(delta: float) -> void:
	var intro: float = min(1.0, _t / 0.4)
	if _label != null:
		_label.rect_scale = Vector2.ONE * (1.0 + 5.0 * pow(1.0 - intro, 2.0) + 0.12 * sin(_t * 18.0) * (1.0 - intro))
		_label.add_color_override("font_color", Color.from_hsv(fmod(_t * 0.3, 1.0), 0.5, 1.0))
	for i in _blocks.size():
		var b: ColorRect = _blocks[i]
		if b == null:
			continue
		var d: Array = _bdata[i]
		var life: float = max(0.0, _t - float(d[0]))
		var grow: float = min(1.0, life / 0.3)
		b.rect_scale = Vector2(grow, grow)
		var dir := Vector2(float(d[4]), float(d[5]))
		b.rect_position = Vector2(float(d[2]), float(d[3])) + dir * (170.0 * life) - b.rect_size * 0.5
		b.rect_rotation = rad2deg(float(d[1]) * life)
		b.color = Color(b.color.r, b.color.g, b.color.b, 0.9 * _quick_fade())


# -----------------------------------------------------------------------------
#  7 落字地震
# -----------------------------------------------------------------------------

func _build_quake() -> void:
	_label = _make_label(TEXT, 122, Color(1, 0.85, 0.2, 1), 14)
	_label.rect_position = _center - _box * 0.5 + Vector2(0, -_screen.y * 0.9)
	var ground := _make_block(Color(0.16, 0.13, 0.11, 1.0), Vector2(_screen.x, 26), Vector2(_screen.x * 0.5, _screen.y - 38.0))
	_blocks.append(ground)
	_bdata.append([_screen.x * 0.5, _screen.y - 38.0])
	for i in 12:
		var size: float = rand_range(14.0, 40.0)
		var pos := Vector2(rand_range(0.0, _screen.x), _screen.y - 64.0)
		var b := _make_block(Color(0.6, 0.5, 0.35, 0.9), Vector2(size, size), pos)
		_blocks.append(b)
		_bdata.append([pos.x, pos.y])


func _update_quake(delta: float) -> void:
	var land: float = 0.55
	if _label != null:
		if _t < land:
			var p: float = _t / land
			_label.rect_position = _center - _box * 0.5 + Vector2(0, -_screen.y * 0.9 + _screen.y * 0.9 * p * p)
			_label.rect_scale = Vector2.ONE
		else:
			var since: float = _t - land
			var damp: float = max(0.0, 1.0 - since * 2.6)
			var squash: float = 1.0 + 0.3 * abs(sin(since * 14.0)) * damp
			_label.rect_position = _center - _box * 0.5 + Vector2(rand_range(-9.0, 9.0) * damp, -abs(sin(since * 9.0)) * 20.0 * damp)
			_label.rect_scale = Vector2(squash, max(0.4, 2.0 - squash))
	var shake: float = 7.0 * max(0.0, 1.0 - max(0.0, _t - 0.4) * 1.1)
	for i in _blocks.size():
		var b: ColorRect = _blocks[i]
		if b == null:
			continue
		var d: Array = _bdata[i]
		b.rect_position = Vector2(float(d[0]), float(d[1])) - b.rect_size * 0.5 + Vector2(rand_range(-shake, shake), rand_range(-shake, shake))


# -----------------------------------------------------------------------------
#  8 雷达扫描
# -----------------------------------------------------------------------------

func _build_radar() -> void:
	_label = _make_label(TEXT, 116, Color(0.55, 1.0, 0.9, 1), 12)
	for i in 4:
		var b := _make_block(Color(0.4, 1.0, 0.8, 0.5), Vector2(320, 6), _center)
		_blocks.append(b)
		_bdata.append([TAU * float(i) / 4.0])
	for i in 5:
		var ring := _make_block(Color(0.3, 0.9, 0.7, 0.3), Vector2(120, 120), _center)
		_blocks.append(ring)
		_bdata.append([-1.0, 0.2 * float(i)])


func _update_radar(delta: float) -> void:
	for i in _blocks.size():
		var b: ColorRect = _blocks[i]
		if b == null:
			continue
		var d: Array = _bdata[i]
		if float(d[0]) < 0.0:
			var phase: float = fmod(_t * 0.85 + float(d[1]), 1.0)
			var size: float = 120.0 + phase * 900.0
			b.rect_size = Vector2(size, size)
			b.rect_pivot_offset = Vector2(size, size) * 0.5
			b.rect_position = _center - Vector2(size, size) * 0.5
			b.color = Color(0.3, 0.9, 0.7, 0.32 * (1.0 - phase))
		else:
			var ang: float = float(d[0]) + _t * 2.2
			b.rect_position = _center + Vector2(cos(ang), sin(ang)) * 200.0 - b.rect_size * 0.5
			b.rect_rotation = rad2deg(ang)
			b.color = Color(0.4, 1.0, 0.8, 0.45)
	if _label != null:
		_label.rect_scale = Vector2.ONE * (1.0 + 0.1 * sin(_t * 8.0))
		_label.add_color_override("font_color", Color(0.55, 1.0, 0.9, 1) if int(_t * 6.0) % 2 == 0 else Color(1, 1, 1, 1))


# -----------------------------------------------------------------------------
#  9 贴图雨
# -----------------------------------------------------------------------------

func _build_iconrain() -> void:
	_label = _make_label(TEXT, 112, Color(1, 1, 1, 1), 12)
	_label.rect_position = _center - _box * 0.5 + Vector2(0, _screen.y * 0.6)
	var icons: Array = _mod_icons()
	if icons.empty():
		return
	for i in 18:
		var s := TextureRect.new()
		s.texture = icons[randi() % icons.size()]
		s.expand = true
		s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var size: float = rand_range(48.0, 96.0)
		s.rect_size = Vector2(size, size)
		s.rect_pivot_offset = s.rect_size * 0.5
		s.rect_position = Vector2(rand_range(0.0, _screen.x), rand_range(-_screen.y, -size))
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(s)
		_sprites.append(s)
		_sdata.append([rand_range(180.0, 420.0), rand_range(-160.0, 160.0)])


func _update_iconrain(delta: float) -> void:
	for i in _sprites.size():
		var s: TextureRect = _sprites[i]
		if s == null:
			continue
		var d: Array = _sdata[i]
		s.rect_position += Vector2(0, float(d[0]) * delta)
		s.rect_rotation = rad2deg(float(d[1]) * _t)
		if s.rect_position.y > _screen.y + s.rect_size.y:
			s.rect_position.y = -s.rect_size.y
	if _label != null:
		var rise: float = min(1.0, _t / 0.5)
		var y: float = _screen.y * 0.6 * (1.0 - rise) - 12.0 * sin(_t * 6.0) * rise
		_label.rect_position = _center - _box * 0.5 + Vector2(0, y)
		_label.rect_scale = Vector2.ONE * (1.0 + 0.05 * sin(_t * 10.0))


# =============================================================================
#  10-19：原版贴图乱舞（随机贴图 + 随机缩放，无意义荒诞拼贴）
#  共用一套 builder / updater，靠 mode 区分动作
# =============================================================================

func _build_rv(mode: int, count: int, smin: float, smax: float) -> void:
	_label = _make_label(TEXT, 116, Color(1, 1, 1, 1), 12)
	var icons: Array = _vanilla_icons()
	if icons.empty():
		return
	for i in count:
		var size: float = rand_range(smin, smax)
		var pos := Vector2(rand_range(0.0, _screen.x), rand_range(0.0, _screen.y))
		var s := _add_icon(icons, size, pos)
		match mode:
			0:
				s.rect_position = Vector2(rand_range(0.0, _screen.x), rand_range(-_screen.y, 0.0))
				_sdata.append([rand_range(160.0, 520.0), rand_range(-200.0, 200.0)])
			1:
				s.rect_position = Vector2(rand_range(0.0, _screen.x), rand_range(_screen.y, _screen.y * 2.0))
				_sdata.append([rand_range(160.0, 520.0), rand_range(-200.0, 200.0)])
			2:
				_sdata.append([randf() * TAU, rand_range(120.0, 460.0), rand_range(-1.6, 1.6)])
			3:
				var ang: float = randf() * TAU
				_sdata.append([cos(ang), sin(ang), rand_range(180.0, 620.0), rand_range(0.0, 0.35)])
			4:
				_sdata.append([rand_range(-320.0, 320.0), rand_range(-320.0, 320.0), rand_range(-4.0, 4.0)])
			5:
				var col: float = floor(rand_range(0.0, 6.0)) * (_screen.x / 6.0) + 30.0
				s.rect_position = Vector2(col, rand_range(0.0, _screen.y))
				_sdata.append([col, rand_range(140.0, 420.0)])
			6:
				var ang2: float = TAU * float(i) / float(max(1, count))
				var rx: float = _screen.x * 0.42
				var ry: float = _screen.y * 0.40
				s.rect_position = _center + Vector2(cos(ang2) * rx, sin(ang2) * ry) - s.rect_size * 0.5
				_sdata.append([ang2, randf() * TAU])
			7:
				_sdata.append([rand_range(0.05, 0.25)])
			8:
				_sdata.append([randf() * TAU, rand_range(260.0, 760.0), rand_range(-1.4, 1.4)])
			_:
				_sdata.append([randf() * TAU, rand_range(-3.0, 3.0)])


func _update_icon_mode(delta: float, mode: int) -> void:
	if _label != null:
		_label.rect_scale = Vector2.ONE * (1.0 + 0.07 * sin(_t * 7.0))
		_label.add_color_override("font_color", Color.from_hsv(fmod(_t * 0.35, 1.0), 0.35, 1.0))

	for i in _sprites.size():
		var s: TextureRect = _sprites[i]
		if s == null:
			continue
		var d: Array = _sdata[i]
		match mode:
			0:
				s.rect_position.y += float(d[0]) * delta
				s.rect_rotation = rad2deg(float(d[1]) * _t)
				if s.rect_position.y > _screen.y + s.rect_size.y:
					s.rect_position.y = -s.rect_size.y
			1:
				s.rect_position.y -= float(d[0]) * delta
				s.rect_rotation = rad2deg(float(d[1]) * _t)
				if s.rect_position.y < -s.rect_size.y:
					s.rect_position.y = _screen.y
			2:
				var ang: float = float(d[0]) + float(d[2]) * _t
				var r: float = float(d[1]) * (1.0 + 0.25 * sin(_t * 2.0 + float(d[0])))
				s.rect_position = _center + Vector2(cos(ang), sin(ang)) * r - s.rect_size * 0.5
				s.rect_rotation = rad2deg(_t * 2.0)
			3:
				var dir := Vector2(float(d[0]), float(d[1]))
				s.rect_position = _center + dir * (float(d[2]) * max(0.0, _t - float(d[3]))) - s.rect_size * 0.5
				s.rect_rotation = rad2deg(_t * 3.0)
			4:
				var pos: Vector2 = s.rect_position + Vector2(float(d[0]), float(d[1])) * delta
				var size: Vector2 = s.rect_size
				if pos.x < 0.0 or pos.x > _screen.x - size.x:
					d[0] = -float(d[0])
				if pos.y < 0.0 or pos.y > _screen.y - size.y:
					d[1] = -float(d[1])
				s.rect_position = pos
				s.rect_rotation = rad2deg(float(d[2]) * _t)
			5:
				s.rect_position.y -= float(d[1]) * delta
				s.rect_rotation = rad2deg(20.0 * sin(_t * 3.0 + float(d[0])))
				if s.rect_position.y < -s.rect_size.y:
					s.rect_position.y = _screen.y
			6:
				s.rect_scale = Vector2.ONE * (1.0 + 0.25 * sin(_t * 5.0 + float(d[1])))
			7:
				if _t >= float(d[0]):
					d[0] = _t + rand_range(0.08, 0.2)
					s.rect_position = Vector2(rand_range(0.0, max(1.0, _screen.x - s.rect_size.x)),
							rand_range(0.0, max(1.0, _screen.y - s.rect_size.y)))
					s.rect_rotation = rad2deg(rand_range(-180.0, 180.0))
			8:
				var ang2: float = float(d[0]) + float(d[2]) * _t
				var r2: float = max(18.0, float(d[1]) - _t * 110.0)
				s.rect_position = _center + Vector2(cos(ang2), sin(ang2)) * r2 - s.rect_size * 0.5
				s.rect_scale = Vector2.ONE * max(0.15, r2 / max(1.0, float(d[1])))
			_:
				s.rect_scale = Vector2.ONE * abs(0.4 + 2.4 * sin(_t * 3.0 + float(d[0])))
				s.rect_rotation = rad2deg(float(d[1]) * _t)

		var fade: float = 1.0 if _t < LIFE - 0.3 else max(0.0, (LIFE - _t) / 0.3)
		s.modulate = Color(1, 1, 1, fade)


func _build_rv_rain() -> void:
	_build_rv(0, 22, 28.0, 150.0)


func _build_rv_rise() -> void:
	_build_rv(1, 20, 28.0, 140.0)


func _build_rv_orbit() -> void:
	_build_rv(2, 16, 40.0, 120.0)


func _build_rv_burst() -> void:
	_build_rv(3, 24, 30.0, 130.0)


func _build_rv_bounce() -> void:
	_build_rv(4, 14, 44.0, 150.0)


func _build_rv_columns() -> void:
	_build_rv(5, 24, 32.0, 110.0)


func _build_rv_frame() -> void:
	_build_rv(6, 18, 40.0, 120.0)


func _build_rv_strobe() -> void:
	_build_rv(7, 18, 36.0, 160.0)


func _build_rv_vortex() -> void:
	_build_rv(8, 20, 36.0, 130.0)


func _build_rv_scale() -> void:
	_build_rv(9, 18, 34.0, 120.0)


func _update_rv_rain(delta: float) -> void:
	_update_icon_mode(delta, 0)


func _update_rv_rise(delta: float) -> void:
	_update_icon_mode(delta, 1)


func _update_rv_orbit(delta: float) -> void:
	_update_icon_mode(delta, 2)


func _update_rv_burst(delta: float) -> void:
	_update_icon_mode(delta, 3)


func _update_rv_bounce(delta: float) -> void:
	_update_icon_mode(delta, 4)


func _update_rv_columns(delta: float) -> void:
	_update_icon_mode(delta, 5)


func _update_rv_frame(delta: float) -> void:
	_update_icon_mode(delta, 6)


func _update_rv_strobe(delta: float) -> void:
	_update_icon_mode(delta, 7)


func _update_rv_vortex(delta: float) -> void:
	_update_icon_mode(delta, 8)


func _update_rv_scale(delta: float) -> void:
	_update_icon_mode(delta, 9)
