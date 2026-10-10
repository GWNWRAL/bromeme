extends "res://entities/units/enemies/boss/boss.gd"

# =============================================================================
#  memeboss：Van
#
#  · 冲刺节奏：2 短 + 1 长，每 0.5s 起一次；三连冲完冷却 2s，然后循环
#      短冲 0.22s、长冲 0.75s（都是 900 速度）→ 225px / 675px
#  · 二阶段（半血）：
#      - 每次冲刺开始时，朝玩家方向左右各 30° 各打一发
#      - 每次冷却期间打一次「♂」符号弹幕（圆环 + 箭杆 + 箭头，用子弹摆出来）
#  · 死亡掉红色宝箱
# =============================================================================

const MOD_DIR: String = "res://mods-unpacked/General-bromeme/"
const SPRITE_PATH: String = MOD_DIR + "meme/content/enemies/van/van.png"

# 冲刺：2 短 + 1 长，三段**连续**衔接（中间不停顿），打完冷却 2s
# 距离 = 速度 × 时长（时长不同：短冲 0.5s、长冲 1.0s）
const DASH_SPEED: float = 750.0       # 用户指定：750（倍率为 1.0，所以实际速度就是 750）
const SHORT_DASH: float = 0.5
const LONG_DASH: float = 1.0
# 倍率去掉：之前是 2.0，实际速度会变成 600×2=1200；用户要求不要 ×2 → 改为 1.0
const SHORT_DASH_SPEED_MULT: float = 1.0
const LONG_DASH_SPEED_MULT: float = 1.0
const DASH_CHAIN_GAP: float = 0.05    # 只留一点点衔接缝隙，保证是"连续冲刺"
const FIRST_DASH_DELAY: float = 0.3
const COOLDOWN: float = 3.0          # 三连冲之后的冷却（原 2.0，+1s）
const SPRITE_SCALE: float = 1.125  # 原 1.5，体型缩小 25%
const PHASE2_HP_RATIO: float = 0.5

const BULLET_SPEED: int = 450          # 原 300 ×1.5
const SIDE_BULLET_SPEED: int = 450     # 原 300 ×1.5
const SIDE_ANGLE: float = 0.5235987755982988   # 30°
const SIDE_BULLET_COUNT: int = 3               # 每侧 3 发（原 1 发）
const SIDE_BULLET_SPREAD: float = 0.14         # 每侧 3 发之间的小夹角(弧度)
const ARROW_ANGLE_DELAY: float = 0.5           # 冷却开始多久后放 ♂
const ARROW_VOLLEY_COUNT: int = 2              # 二阶段连放两个 ♂
const ARROW_VOLLEY_GAP: float = 0.4
const ARROW_VOLLEY_ROT: float = 0.35           # 第二个 ♂ 整体转一点，避免完全重叠
const COOLDOWN_FAN_COUNT: int = 5              # 冷却期的扇形弹幕群（原 7，减 2）
const COOLDOWN_FAN_SPREAD: float = 0.9
const COOLDOWN_FAN_DELAY: float = 0.5
const BULLET_DAMAGE_MULT: float = 0.8         # 弹幕伤害 -20%（扇形 / 两侧三连 / ♂ 都走这里）

const ARROW_CELL: float = 24.0         # 原 16，♂ 放大 1.5 倍

enum State {DASH, COOLDOWN}

var _state: int = State.DASH
var _state_timer: float = 0.0
var _dash_index: int = 0
var _dashing: bool = false
var _dash_timer: float = 0.0
var _phase2: bool = false
var _arrow_fired: bool = false
var _fan_fired: bool = false
var _arrow_volleys_left: int = 0
var _arrow_timer: float = 0.0
var _art_done: bool = false
var _scale_patched: bool = false

onready var _bullets = $VanBullets
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
			# 同一招：只是入口被重复调用（例如每帧都成立），直接忽略
			return
		# 不同招在前摇期间来抢：不丢弃，记下来等当前前摇结束后补上
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

# 「这一招已经打出去了」的钩子（空实现）。需要"严格串联动作"的 boss 可覆写它，
# 用来立刻排下一招（见孙笑川二阶段的动作队列）。
func _br_tell_on_fired() -> void:
	pass



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
	if _charge_behavior != null:
		_charge_behavior.init(self)
		register_attack_behavior(_charge_behavior)
	if _bullets != null:
		_bullets.init(self)
		register_attack_behavior(_bullets)

	_state = State.DASH
	_state_timer = FIRST_DASH_DELAY
	_dash_index = 0


func _apply_boss_art() -> void:
	if _art_done:
		return
	_art_done = true
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
		_sprite.position = Vector2(0, -70)
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

	# 冲刺进行中：等它跑完
	if _dashing:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_finish_dash()
		return

	_state_timer += delta

	if _state == State.DASH:
		# 只有第一段有起手延迟；后续段落由 _finish_dash() 立刻接上
		if _dash_index == 0 and _state_timer >= FIRST_DASH_DELAY:
			_start_dash()
	else:
		# 一阶段冷却：先来一轮 5 发扇形弹幕群（二阶段不放扇形）
		if not _phase2 and not _fan_fired and _state_timer >= COOLDOWN_FAN_DELAY:
			_fire_cooldown_fan()
		# 二阶段冷却：连放两个 ♂
		if _phase2 and _arrow_volleys_left > 0:
			_arrow_timer -= delta
			if _arrow_timer <= 0.0:
				var idx: int = ARROW_VOLLEY_COUNT - _arrow_volleys_left
				_fire_arrow_volley(float(idx) * ARROW_VOLLEY_ROT)
				_arrow_volleys_left -= 1
				_arrow_fired = true
				_arrow_timer = ARROW_VOLLEY_GAP
		if _state_timer >= COOLDOWN:
			_state = State.DASH
			_state_timer = 0.0
			_dash_index = 0


# -----------------------------------------------------------------------------
#  冲刺
# -----------------------------------------------------------------------------


# 冲刺：**状态机推进必须立刻发生**（否则 _dashing 不置位、_state_timer 不清零，
# DASH 分支每帧成立 → 每帧重播前摇 → 永远冲不出去）。
# 所以这里先推进状态机并预排参数，前摇动画播完（shoot 回调）再真正甩出去。
func _start_dash() -> void:
	if _charge_behavior == null:
		return

	var duration: float = LONG_DASH if _dash_index >= 2 else SHORT_DASH
	var speed: float = DASH_SPEED * (LONG_DASH_SPEED_MULT if _dash_index >= 2 else SHORT_DASH_SPEED_MULT)

	# ① 立刻推进状态机
	_dashing = true
	_dash_timer = duration + DASH_CHAIN_GAP
	_state_timer = 0.0
	_dash_index += 1
	_current_attack_behavior = _charge_behavior

	# ② 参数先配好（前摇期间就在蓄力，视觉一致）
	_charge_behavior.charge_duration = duration
	_charge_behavior.charge_speed = speed
	if _charge_behavior._unlock_move_timer != null:
		_charge_behavior._unlock_move_timer.wait_time = duration

	# ③ 排前摇；动画 0.8s 后回调 shoot() → 执行 body 真正开冲
	_br_tell_arm("_br_tell_body__start_dash", [])


func _br_tell_body__start_dash() -> void:
	if _charge_behavior == null:
		return
	# 二阶段：起冲瞬间左右 30° 各三发
	if _phase2:
		_fire_side_bullets()

	# 直接驱动冲刺行为（对齐原版动画回调里的 start_shoot()/shoot() 两步）。
	# 不复用它的 physics_process —— 那个会自己 play("shoot")，和我们的前摇打架。
	_charge_behavior.reset()
	_charge_behavior.start_shoot()      # _can_move=false、mass 调整、set_target()
	_charge_behavior.shoot()            # bonus_speed=charge_speed、方向、解锁计时开始
	# 冲刺期间不要让行为再自己触发一次
	_charge_behavior._current_cd = 1.0e9


func _finish_dash() -> void:
	_dashing = false
	if _charge_behavior != null:
		if _charge_behavior._unlock_move_timer != null and _charge_behavior._unlock_move_timer.time_left > 0.0:
			_charge_behavior._unlock_move_timer.stop()
			_charge_behavior.on_unlock_move_timer_timeout()
	_current_attack_behavior = _bullets

	if _dash_index >= 3:
		# 三连冲结束 → 冷却
		_state = State.COOLDOWN
		_state_timer = 0.0
		_arrow_fired = false
		_fan_fired = false
		_arrow_volleys_left = ARROW_VOLLEY_COUNT if _phase2 else 0
		_arrow_timer = ARROW_ANGLE_DELAY
	else:
		# 连续冲刺：立刻接上下一段（短→短→长）
		_start_dash()


# -----------------------------------------------------------------------------
#  二阶段：半血
# -----------------------------------------------------------------------------

func _enter_phase2() -> void:
	_phase2 = true
	if _sprite != null:
		_sprite.modulate = Color(1.0, 0.8, 0.5)
	ModLoaderLog.info("Van 进入二阶段：冲刺起手左右各一发 + 冷却期 ♂ 弹幕", "bromeme")


# 冲刺起手：朝玩家方向 ±30° 各三发（三发之间带一点小夹角）
func _fire_side_bullets() -> void:
	if _bullets == null:
		return
	var to_player: float = (current_target.global_position - global_position).angle()
	_prepare_bullets()
	for s in [-1.0, 1.0]:
		var base: float = to_player + s * SIDE_ANGLE
		for i in SIDE_BULLET_COUNT:
			var k: float = float(i) - float(SIDE_BULLET_COUNT - 1) * 0.5
			_bullets.spawn_projectile(base + k * SIDE_BULLET_SPREAD, global_position, SIDE_BULLET_SPEED)


# 冷却期的扇形弹幕群：5 发，以玩家方向为中心张开
func _fire_cooldown_fan() -> void:
	_br_tell_arm("_br_tell_body__fire_cooldown_fan", [])


func _br_tell_body__fire_cooldown_fan() -> void:
	if _bullets == null:
		return
	_fan_fired = true
	_prepare_bullets()
	var to_player: float = (current_target.global_position - global_position).angle()
	for i in COOLDOWN_FAN_COUNT:
		var k: float = 0.0
		if COOLDOWN_FAN_COUNT > 1:
			k = float(i) / float(COOLDOWN_FAN_COUNT - 1) * 2.0 - 1.0
		_bullets.spawn_projectile(to_player + k * COOLDOWN_FAN_SPREAD, global_position, BULLET_SPEED)


# 冷却期间一次「♂」：圆环 + 箭杆 + 箭头，全部朝玩家飞
# extra_rot 用来把整幅图形转一点，方便连放两个时不重叠
func _fire_arrow_volley(extra_rot: float = 0.0) -> void:
	_br_tell_arm("_br_tell_body__fire_arrow_volley", [extra_rot])


func _br_tell_body__fire_arrow_volley(extra_rot: float = 0.0) -> void:
	if _bullets == null:
		return
	_arrow_fired = true
	_prepare_bullets()

	var points: Array = _arrow_points()
	var target: Vector2 = current_target.global_position
	for offset in points:
		var pos: Vector2 = global_position + offset.rotated(extra_rot)
		var rot: float = (target - pos).angle()
		_bullets.spawn_projectile(rot, pos, BULLET_SPEED)


# ♂ 形状：圆心附近的圆环 + 45° 方向伸出的箭杆 + 箭头（比之前更大、子弹更多）
func _arrow_points() -> Array:
	var pts: Array = []
	var radius: float = ARROW_CELL * 3.0
	var center := Vector2(-ARROW_CELL * 1.2, ARROW_CELL * 1.6)
	var shaft_dir := Vector2(cos(-PI * 0.25), sin(-PI * 0.25))

	# 圆环
	for i in 18:
		var a: float = TAU * float(i) / 18.0
		pts.append(center + Vector2(cos(a), sin(a)) * radius)

	# 箭杆
	var start: Vector2 = center + shaft_dir * (radius - 2.0)
	for i in range(1, 8):
		pts.append(start + shaft_dir * (ARROW_CELL * 0.9 * float(i)))

	# 箭头：从杆末端往回两侧张开
	var tip: Vector2 = start + shaft_dir * (ARROW_CELL * 0.9 * 8.0)
	var perp := Vector2(-shaft_dir.y, shaft_dir.x)
	pts.append(tip)
	for side in [-1.0, 1.0]:
		for i in range(1, 6):
			pts.append(tip - shaft_dir * (ARROW_CELL * 0.8 * float(i)) + perp * (ARROW_CELL * 0.55 * float(i) * side))
		pts.append(tip + perp * (ARROW_CELL * 1.1 * side) - shaft_dir * (ARROW_CELL * 0.4))

	return pts


func _prepare_bullets() -> void:
	if _bullets != null:
		_bullets.projectile_damage = int(max(1, round(float(current_stats.damage) * BULLET_DAMAGE_MULT)))


func die(args = Utils.default_die_args) -> void:
	.die(args)

	if args != null and args.cleaning_up:
		return

	var main = Utils.get_scene_node()
	if main != null and main.has_method("bromeme_spawn_red_box"):
		main.bromeme_spawn_red_box(self)


# 对象池复用的入口：被回收后再次刷出走的是 respawn()，init() 不会重跑，
# 所以这里要自己复位，否则新刷出来的 Van 会带着上一只的二阶段/冲刺中间状态。
func respawn() -> void:
	.respawn()
	_reset_meme_state()


# 复位的具体内容：单独放一个函数，探针/调试可以直接调用它检查残留
func _reset_meme_state() -> void:
	_br_tell_pending = []
	_br_tell_deferred = []
	_state = State.DASH
	_state_timer = FIRST_DASH_DELAY
	_dash_index = 0
	_dashing = false
	_dash_timer = 0.0
	_phase2 = false
	_arrow_fired = false
	_fan_fired = false
	_arrow_volleys_left = 0
	_arrow_timer = 0.0
	if _bullets != null:
		_current_attack_behavior = _bullets
	# 冲刺中途死亡的话，把 charge 行为的状态也解开（移速/质量/锁移动）
	if _charge_behavior != null:
		_charge_behavior.reset()
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.modulate = Color(1, 1, 1, 1)
		_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
