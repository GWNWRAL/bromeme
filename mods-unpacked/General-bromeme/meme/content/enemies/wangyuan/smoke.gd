extends Node2D

# =============================================================================
#  王源的「烟」：挂在 boss 中心，指向玩家，持续发射三种弹幕
#
#  所有子弹都**从烟的中心**射出，靠方向（和速度倍率）打出形状：
#      · 椭圆弹幕：方向均匀铺一圈，速度按椭圆极坐标 r(θ)=ab/√((b·cosθ)²+(a·sinθ)²)
#                  调制（a=长轴速度、b=短轴速度，比例随机 → 曲率随机），
#                  于是弹幕前沿会展开成一个**越来越大的椭圆**
#      · 扇形弹幕：方向在以玩家为中心的扇面里铺开
#      · 线性弹幕：同一个方向连续吐出一串（子弹依次从中心射出，连成一条线）
#  发射动作由 boss 驱动（二阶段两根烟错峰开火）。
# =============================================================================

const MOD_DIR: String = "res://mods-unpacked/General-bromeme/"
const SPRITE_PATH: String = MOD_DIR + "meme/content/enemies/wangyuan/smoke.png"

const SPRITE_SCALE: float = 0.42

# 贴图本身是斜的：先按瞄准方向，再顺时针补 80°（原本是 -45°，现在合计 +35°）
const ANGLE_OFFSET: float = -PI * 0.25 + 1.3962634015954636   # 80°

const OVAL_MIN: int = 6
const OVAL_MAX: int = 12
const OVAL_LONG_MIN: float = 1.15
const OVAL_LONG_MAX: float = 2.20
const OVAL_SHORT_MIN: float = 0.40
const OVAL_SHORT_MAX: float = 0.90

const FAN_COUNT: int = 7
const FAN_SPREAD: float = 0.85

const LINE_COUNT: int = 7
const LINE_SPACING: float = 26.0       # 同一条线上子弹之间的前后间距
# 三条直线弹幕的方向（相对"朝玩家"的方向）：逆时针 30° / 正前 / 顺时针 30°
const LINE_ANGLES: Array = [-PI / 6.0, 0.0, PI / 6.0]

var _boss = null
var _sprite: Sprite = null
var _art_done: bool = false

var _queue: Array = []
var _queue_timer: float = 0.0


func setup(p_boss) -> void:
	_boss = p_boss
	set_process(true)
	_apply_art()


func _apply_art() -> void:
	if _art_done:
		return
	_art_done = true

	_sprite = Sprite.new()
	_sprite.name = "SmokeSprite"
	add_child(_sprite)

	var file := File.new()
	if file.open(SPRITE_PATH, File.READ) != OK:
		return
	var buffer: PoolByteArray = file.get_buffer(file.get_len())
	file.close()

	var image := Image.new()
	if image.load_png_from_buffer(buffer) != OK:
		return
	var texture := ImageTexture.new()
	texture.create_from_image(image, Texture.FLAG_FILTER)
	_sprite.texture = texture
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)


# 朝向玩家（贴图是斜的，用 ANGLE_OFFSET 校正）
func aim_at(target_pos: Vector2) -> void:
	if _sprite == null:
		return
	rotation = (target_pos - global_position).angle() + ANGLE_OFFSET


func _target_pos() -> Vector2:
	if _boss == null or not is_instance_valid(_boss):
		return global_position + Vector2.RIGHT
	if _boss.current_target == null or not is_instance_valid(_boss.current_target):
		return global_position + Vector2.RIGHT
	return _boss.current_target.global_position


func fire_pattern(kind: int) -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	match kind:
		0:
			fire_oval()
		1:
			fire_fan()
		_:
			fire_line()


# 死亡或回对象池时把队列清掉（现在三种弹幕都是一次性成型，队列暂时没人用，
# 留着是给以后"分次吐"的弹幕用的）
func clear_queue() -> void:
	_queue.clear()
	_queue_timer = 0.0


# 队列式分次发射（当前没有弹幕在用；线性弹幕已改成一次性三条）
func _process(delta: float) -> void:
	if _queue.empty():
		return
	_queue_timer -= delta
	while _queue_timer <= 0.0 and not _queue.empty():
		var shot: Array = _queue.pop_front()
		_queue_timer += float(shot[1])
		if _boss != null and is_instance_valid(_boss):
			var rot: float = float(shot[0])
			var lateral: float = 0.0
			if shot.size() > 3:
				lateral = float(shot[3])
			var pos: Vector2 = global_position + Vector2.RIGHT.rotated(rot + PI * 0.5) * lateral
			_boss.spawn_meme_bullet(rot, pos, float(shot[2]))


# 椭圆：一圈方向 + 速度按椭圆极坐标调制 → 前沿展开成一个越来越大的椭圆
func fire_oval() -> void:
	var count: int = OVAL_MIN + randi() % (OVAL_MAX - OVAL_MIN + 1)
	var long_axis: float = rand_range(OVAL_LONG_MIN, OVAL_LONG_MAX)     # 长轴方向的倍率
	var short_axis: float = rand_range(OVAL_SHORT_MIN, OVAL_SHORT_MAX)  # 短轴方向的倍率
	var spin: float = rand_range(-0.9, 0.9)
	var center: Vector2 = global_position

	for i in count:
		var t: float = TAU * float(i) / float(count) + spin
		var denom: float = sqrt(pow(short_axis * cos(t), 2.0) + pow(long_axis * sin(t), 2.0))
		var factor: float = (long_axis * short_axis) / max(0.05, denom)
		_boss.spawn_meme_bullet(t, center, factor)


# 扇形：方向在以玩家为中心的扇面里铺开，全部从中心射出
func fire_fan() -> void:
	var to_player: float = (_target_pos() - global_position).angle()
	var spread: float = FAN_SPREAD * rand_range(0.75, 1.35)
	var center: Vector2 = global_position

	for i in FAN_COUNT:
		var k: float = 0.0
		if FAN_COUNT > 1:
			k = float(i) / float(FAN_COUNT - 1) * 2.0 - 1.0
		_boss.spawn_meme_bullet(to_player + k * spread, center, 1.0)


# 线性：三条直线弹幕**同时**射出 —— 以朝玩家的方向为中心，
# 逆时针 30° / 正前 / 顺时针 30° 各一条，每条线上 7 发沿发射方向前后排开
# （不再走队列分次吐，整条线是一瞬间成型的）
func fire_line() -> void:
	var to_player: float = (_target_pos() - global_position).angle()
	for angle_offset in LINE_ANGLES:
		var rot: float = to_player + float(angle_offset)
		var dir := Vector2.RIGHT.rotated(rot)
		for i in LINE_COUNT:
			var pos: Vector2 = global_position + dir * (LINE_SPACING * float(i))
			_boss.spawn_meme_bullet(rot, pos, 1.0)
