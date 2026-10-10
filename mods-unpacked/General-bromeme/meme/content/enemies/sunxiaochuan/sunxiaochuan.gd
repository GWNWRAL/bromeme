extends "res://entities/units/enemies/boss/boss.gd"

# =============================================================================
#  memeboss：孙笑川（NMSL 字母弹幕）
#
#  血量/伤害直接照抄土豆兄弟的精英 boss「水母」(dlcs/dlc_1/enemies/jellyfish)：
#       health 1 + 750/波，damage 1 + 1.5/波，speed 225，knockback_resistance 1.0
#  攻击方式：按 N -> M -> S -> L 的顺序，每轮把子弹在 boss 周围摆成一个字母，
#            然后所有子弹一起朝玩家飞过去（字母形状冲脸）。
#  死亡掉落：红色宝箱（原版 legendary_item_box，就是那个红箱子）。
# =============================================================================

const MOD_DIR: String = "res://mods-unpacked/General-bromeme/"
const SPRITE_PATH: String = MOD_DIR + "meme/content/enemies/sunxiaochuan/sunxiaochuan.png"

const PROJECTILE_SPEED: int = 313      # 原 250，加快 25%
const VOLLEY_INTERVAL: float = 2.26    # 原 2.6，攻击频率 +15%（2.6 / 1.15）
const FIRST_VOLLEY_DELAY: float = 1.8
const CELL: float = 42.0               # 原 32，字母里的子弹间距拉大 → 弹幕更分散
# 飞行时每偏离字母中心 1 格，额外向外扇开多少弧度：
#   0    = 完全平行（整幅字母像一堵墙平移过去，形状一点不变）
#   0.06 = 轻微向外散开（默认）
#   0.22 = 明显扇形散开（原 0.12，用户要求"分散角度更大"）
const LETTER_FLIGHT_FAN: float = 0.22
const SPRITE_SCALE: float = 0.54   # 原 0.72，体型缩小 25%

# 二阶段（血量 <= 50%）：在两次弹幕的间隙冲一次，模仿原版海象的 charge
const PHASE2_HP_RATIO: float = 0.5
const DASH_DELAY: float = 0.7      # 弹幕打完多久后开冲
const DASH_RECOVER: float = 0.35   # 冲刺结束后的额外缓冲
const DASH_SPEED: float = 600.0    # 冲刺速度：原 900 × 2/3 = 600（场景里是 900，这里显式覆盖）

const LETTERS: Array = ["N", "M", "S", "L"]

# 5x5 点阵，1 = 一颗子弹
const PATTERNS: Dictionary = {
	"N": ["10001", "11001", "10101", "10011", "10001"],
	"M": ["10001", "11011", "10101", "10001", "10001"],
	"S": ["01111", "10000", "01110", "00001", "11110"],
	"L": ["10000", "10000", "10000", "10000", "11111"],
}

var _volley_timer: float = 0.0
var _letter_index: int = 0
var _sprite_fixed: bool = false
var _scale_patched: bool = false

var _phase2: bool = false
var _dash_pending: bool = false
var _dash_timer: float = 0.0
var _dashing: bool = false
var _dash_end_timer: float = 0.0

onready var _letter_behavior = $LetterAttackBehavior
onready var _charge_behavior = $ChargeAttackBehavior
onready var _sprite = $Animation/Sprite


# =============================================================================
#  出招前摇（对齐原版 enemy.gd / shoot.tres）
#
#  原版：play("shoot") → 动画 1 秒，method 轨在 t=0 调 start_shoot()、t=0.8 调 shoot()
#        → boss.shoot() → 攻击行为真正发射。所以"0.8 秒前摇"是动画自带的。
#  这里照抄：入口只 arm（播动画 + 记住这一招），shoot() 被动画回调时才执行。
# =============================================================================
const BR_TELL_ANIM: String = "shoot"

var _br_tell_pending: Array = []       # [body 方法名, 参数数组]
var _br_tell_deferred: Array = []      # 被拒而延迟重试的招


# 入口调用：播 shoot 并记住要出的招
func _br_tell_arm(body_name: String, args: Array = []) -> void:
	# ⚠️ 一次只排一个前摇：
	#    · 同一招被每帧重复调用 → 直接忽略（重播会让动画永远停在第 0 帧）
	#    · **别的招**在前摇期间来抢 → 也拒绝，否则会被覆盖掉（表现为"某一招被吞"）
	#      被拒的招会在下一轮循环自然重试。
	if not _br_tell_pending.empty():
		if String(_br_tell_pending[0]) == body_name:
			# 同一招：入口被重复调用，直接忽略
			return
		# 不同招来抢：记下来等当前前摇结束后补上
		_br_tell_deferred = [body_name, args]
		return
	_br_tell_pending = [body_name, args]
	_tell_watch_frames = 0
	var player = get_node_or_null("AnimationPlayer")
	if player == null:
		_br_tell_fire_pending()
		return
	player.playback_speed = 1.0
	player.play(BR_TELL_ANIM)



# 看门狗帧数：shoot 动画 1 秒（含 0.8s 方法轨），60fps 下留足余量。
# 万一动画没播到方法轨（被打断 / 播放器异常），这里强制出招，避免永久卡住。
const BR_TELL_WATCHDOG_FRAMES: int = 120

var _tell_watch_frames: int = 0


# 每帧由 boss 的 _physics_process 调用
func _br_tell_watchdog() -> void:
	if _br_tell_pending.empty():
		return
	_tell_watch_frames += 1
	if _tell_watch_frames >= BR_TELL_WATCHDOG_FRAMES:
		_br_tell_fire_pending()

# 「这一招已经打出去了」的钩子：孙笑川二阶段用它串联动作队列（见下方 _br_tell_on_fired 实现）


# 真正执行挂起的那一招（shoot 回调与看门狗共用）
func _br_tell_fire_pending() -> void:
	if _br_tell_pending.empty():
		return
	var body_name: String = String(_br_tell_pending[0])
	var args: Array = _br_tell_pending[1]
	_br_tell_pending = []
	_tell_watch_frames = 0
	if has_method(body_name):
		callv(body_name, args)
	_br_tell_on_fired()
	# 前摇期间被抢的招：立刻为它开一段新前摇（延迟但不丢弃）
	if not _br_tell_deferred.empty():
		var d_name: String = String(_br_tell_deferred[0])
		var d_args: Array = _br_tell_deferred[1]
		_br_tell_deferred = []
		_br_tell_arm(d_name, d_args)

# 原版在 t=0 由动画 method 轨调用（这里不需要额外动作，留作占位/兼容）
func start_shoot() -> void:
	pass


# 原版在 t=0.8 由动画 method 轨调用 → 这里真正出招
func shoot() -> void:
	_br_tell_fire_pending()


func init(zone_min_pos: Vector2, zone_max_pos: Vector2, players_ref: Array = [], entity_spawner_ref = null) -> void:
	.init(zone_min_pos, zone_max_pos, players_ref, entity_spawner_ref)

	_apply_boss_art()
	if _letter_behavior != null:
		_letter_behavior.init(self)
		register_attack_behavior(_letter_behavior)

	# 开场先给玩家一点反应时间
	_volley_timer = VOLLEY_INTERVAL - FIRST_VOLLEY_DELAY
	_letter_index = 0


# PNG 用运行时读取的方式加载：mod 里的图片没有 .import/导入缓存，
# 直接 load() 拿不到，这里按字节读进来自己造 ImageTexture。
func _apply_boss_art() -> void:
	if _sprite_fixed:
		return
	_sprite_fixed = true
	_patch_scale_animations()

	var file := File.new()
	if file.open(SPRITE_PATH, File.READ) != OK:
		ModLoaderLog.error("%s: 读不到 boss 贴图 %s（若 zip 在游戏运行中被替换过，mod 内所有文件都会读失败，重启游戏即可）" % [enemy_id, SPRITE_PATH], "bromeme")
		return
	var buffer: PoolByteArray = file.get_buffer(file.get_len())
	file.close()

	var image := Image.new()
	if image.load_png_from_buffer(buffer) != OK:
		ModLoaderLog.error("%s: boss 贴图解码失败 %s" % [enemy_id, SPRITE_PATH], "bromeme")
		return
	var texture := ImageTexture.new()
	texture.create_from_image(image, Texture.FLAG_FILTER)

	if _sprite != null:
		_sprite.texture = texture
		_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
		_sprite.position = Vector2(0, -60)

	if stats != null:
		stats.icon = texture


# 原版死亡动画（entity.tscn 里的 death）把 Animation/Sprite:scale 从 (1,1) 收到 0，
# 体型被改小的 boss 一死就会先弹回原尺寸（RESET 还会把池子里的实例复位成 1,1）。
# 这里把 death / RESET 里那条缩放轨道的起始关键帧换成自己的体型；动画资源是全游戏
# 共享的，必须先 duplicate 再改。替换失败就退回"活着时每帧纠正"。
func _patch_scale_animations() -> void:
	var player = get_node_or_null("AnimationPlayer")
	if player == null:
		return
	# ⚠️ 必须遍历**所有**动画：只改 death/RESET 的话，idle 等动画的 scale 轨
	# 仍是原始体型，一播就把 _sprite.scale 拉回去（表现为 boss 突然变大）。
	for anim_name in player.get_animation_list():
		if not player.has_animation(anim_name):
			continue
		var src: Animation = player.get_animation(anim_name)
		if src == null:
			continue
		var anim = src.duplicate(true)
		if anim == null or not (anim is Animation):
			continue
		for i in anim.get_track_count():
			if anim.track_get_type(i) != Animation.TYPE_VALUE:
				continue
			var path: String = str(anim.track_get_path(i))
			if path.find("Sprite") < 0 or not path.ends_with(":scale"):
				continue
			if anim.track_get_key_count(i) > 0:
				anim.track_set_key_value(i, 0, Vector2(SPRITE_SCALE, SPRITE_SCALE))
		player.add_animation(anim_name, anim)
		if player.get_animation(anim_name) == anim:
			_scale_patched = true

	if not _scale_patched:
		ModLoaderLog.info("%s: 死亡缩放轨道替换失败，改用每帧纠正" % enemy_id, "bromeme")


func _physics_process(delta: float) -> void:
	._physics_process(delta)
	_br_tell_watchdog()
	if dead:
		return
	# 兜底：替换失败时至少保证活着的时候体型正确
	if not _scale_patched and _sprite != null and is_instance_valid(_sprite):
		_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	if current_target == null or not is_instance_valid(current_target):
		return

	if not _phase2 and max_stats.health > 0 and current_stats.health <= int(max_stats.health * PHASE2_HP_RATIO):
		_enter_phase2()

	# 一阶段：定时器驱动弹幕
	if not _phase2:
		_volley_timer += delta
		if _volley_timer >= VOLLEY_INTERVAL:
			_volley_timer = 0.0
			_fire_letter()
		return

	# 二阶段：由动作队列严格串联（前摇→发射→前摇→冲刺→前摇→…）
	if _dashing:
		_dash_end_timer -= delta
		if _dash_end_timer <= 0.0:
			_end_dash()
		return
	if _dash_gap > 0.0:
		# 冲刺后的一点点收招间隙，然后由队列接下一轮（走前摇）
		_dash_gap -= delta
		if _dash_gap <= 0.0 and not _acting and not _action_queue.empty():
			_start_next_action()
		return
	if not _acting and _action_queue.empty():
		_action_queue.append("letter")
		_action_queue.append("dash")
	if not _acting and not _action_queue.empty():
		_start_next_action()


# 半血：进入二阶段，把海象那套冲刺（charging_attack_behavior）接进来


# =============================================================================
#  二阶段动作队列：严格串联"前摇 → 发射"与"前摇 → 冲刺"
#
#  为什么需要它：弹幕每 2.26s 必然重排一次前摇，而冲刺只能在前摇间隙排，
#  于是冲刺总被弹幕抢掉（或被自己的补位逻辑锁住）→ 永远冲不出去。
#  改成队列后每完成一个动作才取下一个，顺序天然正确：
#      前摇→弹幕发射 → 前摇→冲刺 → 前摇→弹幕发射 → …
# =============================================================================
const DASH_GAP: float = 0.35

var _action_queue: Array = []
var _acting: bool = false
var _dash_gap: float = 0.0


func _start_next_action() -> void:
	if _action_queue.empty():
		return
	var act: String = String(_action_queue.pop_front())
	_acting = true
	if act == "dash":
		# 冲刺**不加**我们的 shoot 前摇：
		# `_charge_behavior.start_shoot()` 本身就是前摇（锁移动 + 伸缩动画），
		# 再套一层会互相打断，导致"有前摇但不冲"。
		_br_tell_body__begin_dash()
	else:
		# 弹幕保留前摇（前摇 → 发射）
		_br_tell_arm("_br_tell_body__fire_letter", [])


# 前摇结束、这一招已打出去 → 立刻排下一个动作（冲刺类由 _end_dash 接续）
func _br_tell_on_fired() -> void:
	if not _acting:
		return
	if _dashing:
		return
	_acting = false
	if _phase2 and not _action_queue.empty():
		_start_next_action()


func _enter_phase2() -> void:
	_phase2 = true
	if _charge_behavior != null:
		_charge_behavior.init(self)
		register_attack_behavior(_charge_behavior)
	if _sprite != null:
		_sprite.modulate = Color(1.0, 0.6, 0.6)
	_action_queue = ["letter", "dash"]
	_acting = false
	_dash_gap = 0.0
	ModLoaderLog.info("孙笑川进入二阶段：动作队列驱动（弹幕/冲刺交替）", "bromeme")


# 切换到冲刺行为：它自己的 physics_process 会播 shoot 动画，
# 动画回调再触发 start_shoot()/shoot()，由原版逻辑把 boss 甩出去。
func _begin_dash() -> void:
	_br_tell_arm("_br_tell_body__begin_dash", [])


func _br_tell_body__begin_dash() -> void:
	if _charge_behavior == null:
		return
	_dashing = true
	_dash_end_timer = float(_charge_behavior.charge_duration) + DASH_RECOVER
	_current_attack_behavior = _charge_behavior
	_charge_behavior.reset()
	_charge_behavior._current_cd = 0.0
	# 冲刺速度：场景里是 900，这里显式覆盖为原来的 2/3（900 × 2/3 = 600）
	_charge_behavior.charge_speed = DASH_SPEED
	_charge_behavior.start_shoot()
	_charge_behavior.shoot()


func _end_dash() -> void:
	_dashing = false
	_acting = false
	_current_attack_behavior = _letter_behavior
	# 冲刺结束 → 排队先打一轮弹幕，再冲刺
	if _phase2:
		_action_queue.append("letter")
		_action_queue.append("dash")
		_dash_gap = DASH_GAP
	if _charge_behavior == null:
		return
	# 冲刺的移速/质量是由它自己的计时器恢复的；万一切换时还没恢复，这里兜底
	if _charge_behavior._unlock_move_timer != null and _charge_behavior._unlock_move_timer.time_left > 0.0:
		_charge_behavior._unlock_move_timer.stop()
		_charge_behavior.on_unlock_move_timer_timeout()


# 把下一个字母摆到 boss 周围，然后整幅字母朝玩家飞过去
#
# 注意：这里**不再**让每发子弹各自瞄准玩家 —— 那样飞出去会全部汇聚成一小坨，
# 字母形状立刻散掉。现在整幅字母用同一个方向平行推进（形状一路保持），
# 再按横向格位加一点向外的扇开角度，避免看着像一堵死板的墙。
func _fire_letter() -> void:
	_br_tell_arm("_br_tell_body__fire_letter", [])


func _br_tell_body__fire_letter() -> void:
	if _letter_behavior == null:
		return
	var letter: String = str(LETTERS[_letter_index])
	_letter_index = (_letter_index + 1) % LETTERS.size()

	var pattern: Array = PATTERNS[letter]
	var target: Vector2 = current_target.global_position
	var origin: Vector2 = global_position

	_letter_behavior.projectile_damage = int(max(1, current_stats.damage))

	var rows: int = pattern.size()
	var cols: int = str(pattern[0]).length()
	var half := Vector2(float(cols) * CELL * 0.5, float(rows) * CELL * 0.5)

	var base_rot: float = (target - origin).angle()
	var perp := Vector2(-sin(base_rot), cos(base_rot))   # 垂直"字母前进方向"的方向

	for r in rows:
		var row: String = str(pattern[r])
		for c in cols:
			if row[c] != "1":
				continue
			var pos: Vector2 = origin + Vector2(float(c) * CELL, float(r) * CELL) - half
			var lateral_cells: float = (pos - origin).dot(perp) / CELL
			var rot: float = base_rot + lateral_cells * LETTER_FLIGHT_FAN
			_letter_behavior.spawn_projectile(rot, pos, PROJECTILE_SPEED)


func die(args = Utils.default_die_args) -> void:
	.die(args)

	if args != null and args.cleaning_up:
		return

	var main = Utils.get_scene_node()
	if main != null and main.has_method("bromeme_spawn_red_box"):
		main.bromeme_spawn_red_box(self)


# 对象池复用的入口：被回收后再次刷出走的是 respawn()，init() 不会重跑，
# 所以这里要自己复位，否则新刷出来的孙笑川会带着上一只的二阶段/冲刺中间状态。
func respawn() -> void:
	.respawn()
	_reset_meme_state()


# 复位的具体内容：单独放一个函数，探针/调试可以直接调用它检查残留
func _reset_meme_state() -> void:
	_br_tell_pending = []
	_br_tell_deferred = []
	_action_queue = []
	_acting = false
	_dash_gap = 0.0
	_volley_timer = VOLLEY_INTERVAL - FIRST_VOLLEY_DELAY
	_letter_index = 0
	_phase2 = false
	_dash_pending = false
	_dash_timer = 0.0
	_dashing = false
	_dash_end_timer = 0.0
	if _letter_behavior != null:
		_current_attack_behavior = _letter_behavior
	# 冲刺中途死亡的话，把 charge 行为的状态也解开（移速/质量/锁移动）
	if _charge_behavior != null:
		_charge_behavior.reset()
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.modulate = Color(1, 1, 1, 1)
		_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
