extends "res://entities/units/enemies/boss/boss.gd"

# =============================================================================
#  memeboss：叛忍
#
#  血量与魂5相同（150 + 675/波）。
#  一阶段四个动作随机：
#   1) 瞬移到角色身后（落点限制在地图内、且离角色至少 TELEPORT_MIN_PLAYER_DIST），
#      路径上撒一排尖刺
#   2) 朝角色打尖刺，然后二选一：朝角色冲刺 / 向后冲刺并**无冷却**立刻接下一个动作
#      （衔接的动作不会是 2）
#   3) 连续投掷四个红色手里剑
#   4) 分散投掷三个手里剑
#   每个动作结束冷却 1s。
#  二阶段（半血）：手里剑 +2、尖刺 +2，新增动作
#   5) 先 0.5s 前摇，然后连续冲刺两次，收尾分散发射三枚手里剑
#      （只有离角色 > DASH_CHAIN_MIN_DIST=300 时才发动；前摇结束时再复核一次，
#        太近就直接结束这个动作，不冲）
# =============================================================================

const MOD_DIR: String = "res://mods-unpacked/General-bromeme/"
const SPRITE_PATH: String = MOD_DIR + "meme/content/enemies/panren/panren.png"

const SPRITE_SCALE: float = 0.23       # 原 0.33，体型再 -30%
const SPRITE_POS_Y: float = -70.0
const PHASE2_HP_RATIO: float = 0.5
const ACTION_COOLDOWN: float = 1.0
const P2_SPEED_FACTOR: float = 0.9

# 尖刺：和魂5/一角鲸同一套（slash 弹幕）
const SPIKE_SCENE_PATH: String = "res://projectiles/slash/slash_projectile.tscn"
const SPIKE_SPEED: int = 700
const SPIKE_BASE_COUNT: int = 3            # 动作2：朝角色几发
const PATH_SPIKE_BASE_COUNT: int = 5       # 动作1：瞬移路径上几发
const PHASE2_COUNT_BONUS: int = 2          # 二阶段：尖刺 +2
const SPIKE_SPREAD: float = 0.36

# 手里剑
const SHURIKEN_TEXTURE_PATH: String = "res://projectiles/shuriken/shuriken.png"
const SHURIKEN_SPEED: int = 470
const BURST_BASE_COUNT: int = 4            # 动作3：连续投掷
const BURST_GAP: float = 0.13
const SPREAD_BASE_COUNT: int = 3           # 动作4 / 动作5收尾：分散投掷
const SPREAD_ANGLE: float = 0.42
const SHURIKEN_RED: Color = Color(1.0, 0.25, 0.25, 1.0)
const SHURIKEN_PLAIN: Color = Color(0.85, 0.9, 1.0, 1.0)
const SHURIKEN_DAMAGE_MULT: float = 0.85     # 手里剑伤害 -15%

# 瞬移
const TELEPORT_BACK_DIST: float = 360.0        # 目标落点：角色身后这么远（原 140 → 260 → 360，用户要求 +100）
const TELEPORT_TRIGGER_DIST: float = 250.0     # 只有离角色 < 这个距离才会发动瞬移（原 150，用户要求改 250）
const TELEPORT_MIN_PLAYER_DIST: float = 120.0  # 落点离角色至少这么远（避免贴脸躲不掉）
const PATH_SPIKE_SAFE_DIST: float = 110.0      # 路径尖刺不在角色这个半径内生成
const TELEPORT_FLASH_TIME: float = 0.22

# 冲刺
const DASH_SPEED: float = 937.5          # 原 1250，冲刺速度减慢 25%（1250 × 0.75）
const DASH_TIME: float = 0.42
const DASH_CHAIN_COUNT: int = 2                # 动作5：连冲两次
const DASH_WINDUP_TIME: float = 0.5            # 尖刺后"朝角色冲刺"的前摇
const KEEP_DISTANCE: float = 90.0              # 平常靠近到这么远就停
# 动作 5（二阶段连冲）：前摇 0.5s，且只在离角色 > 这个距离时才冲（太近就不冲）
const DASH_CHAIN_MIN_DIST: float = 300.0

const BROMEME_POOL_PREFIX: String = "bromeme_panren_pool_"
const ENEMY_PROJECTILE_PATH: String = "res://projectiles/bullet_enemy/enemy_projectile.tscn"

enum St {IDLE, TELEPORT, BURST, DASH, WINDUP}

var _st: int = St.IDLE
var _st_timer: float = 0.0
var _phase2: bool = false
var _art_done: bool = false
var _scale_patched: bool = false
var _attack_timer: float = ACTION_COOLDOWN

var _burst_left: int = 0
var _burst_timer: float = 0.0

var _dash_dir: Vector2 = Vector2.RIGHT
var _dash_time_left: float = 0.0
var _dash_left: int = 0
var _dash_then_spread: bool = false
var _windup_dir: Vector2 = Vector2.RIGHT

# 前摇结束后怎么冲：默认单次；动作 5 会把它设成"连冲 + 收尾分散手里剑"
var _windup_then_spread: bool = false
var _windup_dash_count: int = 1
# 前摇结束时要求的"离角色最小距离"（<=0 = 不检查）
var _windup_min_dist: float = 0.0

# 后撤冲刺的衔接：无冷却立刻接下一个动作，且下一个不能是动作 2
var _chain_immediately: bool = false
var _ban_action_two: bool = false

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
	_st = St.IDLE
	_st_timer = 0.0
	_attack_timer = ACTION_COOLDOWN


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
		_sprite.position = Vector2(0, SPRITE_POS_Y)
	if stats != null:
		stats.icon = texture


# 原版死亡动画（entity.tscn 里的 death）把 Animation/Sprite:scale 从 (1,1) 收到 0，
# 体型被改小的 boss 一死就会先弹回原尺寸（RESET 还会把池子里的实例复位成 1,1）。
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

	match _st:
		St.TELEPORT:
			_update_teleport(delta)
		St.BURST:
			_update_burst(delta)
		St.DASH:
			_update_dash(delta)
		St.WINDUP:
			_update_windup(delta)
		_:
			_move_toward_target(delta)
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_start_next_action()


# -----------------------------------------------------------------------------
#  动作调度
# -----------------------------------------------------------------------------


func _start_next_action() -> void:
	_br_tell_arm("_br_tell_body__start_next_action", [])


func _br_tell_body__start_next_action() -> void:
	# 动作 2/3/4 随时可出；瞬移（1）只有靠近角色时才会进入候选
	var options: Array = [2, 3, 4]
	if _phase2:
		options.append(5)
	if _teleport_allowed():
		options.append(1)
	if _ban_action_two:
		options.erase(2)
		_ban_action_two = false

	var pick: int = int(options[randi() % options.size()])
	match pick:
		1:
			_action_teleport()
		2:
			_action_spikes()
		3:
			_action_burst()
		4:
			_action_spread()
		_:
			_action_dash_chain()


func _finish_action() -> void:
	_st = St.IDLE
	if _chain_immediately:
		# 后撤冲刺的衔接：不冷却，立刻挑下一个动作
		_chain_immediately = false
		_start_next_action()
		return
	_attack_timer = ACTION_COOLDOWN


# 动作 1 的发动条件：离角色够近（< TELEPORT_TRIGGER_DIST）
func _teleport_allowed() -> bool:
	if current_target == null or not is_instance_valid(current_target):
		return false
	return global_position.distance_to(current_target.global_position) < TELEPORT_TRIGGER_DIST


# 动作 1：瞬移到角色身后 + 路径上撒尖刺
func _action_teleport() -> void:
	_st = St.TELEPORT
	_st_timer = TELEPORT_FLASH_TIME

	var player = current_target
	var from_pos: Vector2 = global_position
	var back: Vector2 = _behind_direction(player)
	var dest: Vector2 = _clamp_to_zone(player.global_position + back * TELEPORT_BACK_DIST)

	# 落点离角色太近会让"出现"变成躲不掉的伤害 → 沿同一方向推到安全距离
	if dest.distance_to(player.global_position) < TELEPORT_MIN_PLAYER_DIST:
		dest = _clamp_to_zone(player.global_position + back * TELEPORT_MIN_PLAYER_DIST)

	if dest.distance_to(player.global_position) < TELEPORT_MIN_PLAYER_DIST * 0.8:
		# 被逼到边角、怎么夹都不够远：这次不瞬移，就地打一排尖刺
		_fire_path_spikes(from_pos, from_pos + back * TELEPORT_BACK_DIST)
		_st_timer = 0.0
		return

	global_position = dest
	_fire_path_spikes(from_pos, dest)

	if _sprite != null and is_instance_valid(_sprite):
		_sprite.modulate = Color(1.7, 1.7, 1.7, 1.0)


func _update_teleport(delta: float) -> void:
	_st_timer -= delta
	# 闪一下然后恢复（二阶段带红 tint）
	if _st_timer <= TELEPORT_FLASH_TIME * 0.5 and _sprite != null and is_instance_valid(_sprite):
		if _phase2:
			_sprite.modulate = Color(1.0, 0.85, 0.85)
		else:
			_sprite.modulate = Color(1, 1, 1, 1)
	if _st_timer <= 0.0:
		_finish_action()


# 动作 2：尖刺 → 冲刺（朝角色 / 向后并立刻衔接）
func _action_spikes() -> void:
	var count: int = SPIKE_BASE_COUNT
	if _phase2:
		count += PHASE2_COUNT_BONUS
	var to_player: float = (current_target.global_position - global_position).angle()
	_fire_spike_fan(to_player, count)

	var dir: Vector2 = current_target.global_position - global_position
	if dir.length() < 1.0:
		dir = Vector2.RIGHT
	if randf() < 0.5:
		# 朝角色冲：先给 0.5s 前摇（看得见才躲得掉）
		_start_windup(dir.normalized())
	else:
		# 向后冲，然后立刻接下一个动作（无冷却，且不会是动作 2）
		_chain_immediately = true
		_ban_action_two = true
		_start_dash(-dir.normalized(), 1, false)


# 前摇：站着不动亮一下，时间到再冲
# 动作 5 复用它：先 0.5s 前摇，再按 _windup_then_spread（连冲+收尾）/ _windup_min_dist（距离门槛）出招
func _start_windup(dir: Vector2, count: int = 1, then_spread: bool = false, min_dist: float = 0.0) -> void:
	_st = St.WINDUP
	_windup_dir = dir
	_windup_dash_count = max(1, count)
	_windup_then_spread = then_spread
	_windup_min_dist = min_dist
	_st_timer = DASH_WINDUP_TIME
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.modulate = Color(1.5, 1.2, 1.2, 1.0)


func _update_windup(delta: float) -> void:
	_st_timer -= delta
	_current_movement = Vector2.ZERO
	if _st_timer > 0.0:
		return
	if _phase2:
		if _sprite != null and is_instance_valid(_sprite):
			_sprite.modulate = Color(1.0, 0.85, 0.85)
	else:
		if _sprite != null and is_instance_valid(_sprite):
			_sprite.modulate = Color(1, 1, 1, 1)

	# 距离门槛：前摇快结束时玩家可能已经贴上来了，太近就不冲了
	if _windup_min_dist > 0.0:
		if current_target == null or not is_instance_valid(current_target):
			_reset_windup_plan()
			_finish_action()
			return
		if global_position.distance_to(current_target.global_position) <= _windup_min_dist:
			_reset_windup_plan()
			_finish_action()
			return

	var count: int = _windup_dash_count
	var spread: bool = _windup_then_spread
	_reset_windup_plan()
	_start_dash(_windup_dir, count, spread)


func _reset_windup_plan() -> void:
	_windup_then_spread = false
	_windup_dash_count = 1
	_windup_min_dist = 0.0


# 动作 3：连续投掷红色手里剑
func _action_burst() -> void:
	_st = St.BURST
	_burst_left = BURST_BASE_COUNT
	if _phase2:
		_burst_left += PHASE2_COUNT_BONUS
	_burst_timer = 0.0


func _update_burst(delta: float) -> void:
	_burst_timer -= delta
	if _burst_timer > 0.0:
		return
	_burst_timer = BURST_GAP
	_burst_left -= 1
	_fire_shuriken_at_player(SHURIKEN_RED, rand_range(-0.12, 0.12))
	if _burst_left <= 0:
		_finish_action()


# 动作 4：分散投掷手里剑
func _action_spread() -> void:
	var count: int = SPREAD_BASE_COUNT
	if _phase2:
		count += PHASE2_COUNT_BONUS
	_fire_spread_shuriken(count)
	_finish_action()


# 动作 5（二阶段）：离角色 > DASH_CHAIN_MIN_DIST 时，先 0.5s 前摇再连冲两次，收尾分散手里剑
func _action_dash_chain() -> void:
	if current_target == null or not is_instance_valid(current_target):
		_finish_action()
		return

	var to_player: Vector2 = current_target.global_position - global_position
	var gap: float = to_player.length()
	if gap <= DASH_CHAIN_MIN_DIST:
		# 太近了：这个动作是拿来贴脸的，不冲（直接结束，走正常冷却）
		ModLoaderLog.info("叛忍动作5：距离 %.0f 未超过 %.0f，放弃连冲" % [gap, DASH_CHAIN_MIN_DIST], "bromeme")
		_finish_action()
		return

	var dir: Vector2 = to_player
	if dir.length() < 1.0:
		dir = Vector2.RIGHT
	# 前摇 0.5s（复用动作 2 那套），前摇结束时再复核一次距离
	_start_windup(dir.normalized(), DASH_CHAIN_COUNT, true, DASH_CHAIN_MIN_DIST)


# -----------------------------------------------------------------------------
#  冲刺（自己推位置：向前 / 向后都由调用方给方向）
# -----------------------------------------------------------------------------

func _start_dash(dir: Vector2, count: int, then_spread: bool) -> void:
	if dir.length() < 0.05:
		dir = Vector2.RIGHT.rotated(randf() * TAU)
	_st = St.DASH
	_dash_dir = dir.normalized()
	_dash_time_left = DASH_TIME
	_dash_left = max(1, count)
	if then_spread:
		_dash_then_spread = true


func _update_dash(delta: float) -> void:
	_dash_time_left -= delta
	global_position = _clamp_to_zone(global_position + _dash_dir * DASH_SPEED * delta)
	if _dash_time_left > 0.0:
		return

	_dash_left -= 1
	if _dash_left > 0:
		var dir: Vector2 = current_target.global_position - global_position
		if dir.length() < 1.0:
			dir = _dash_dir
		_start_dash(dir.normalized(), _dash_left, _dash_then_spread)
		return

	if _dash_then_spread:
		_dash_then_spread = false
		var count: int = SPREAD_BASE_COUNT
		if _phase2:
			count += PHASE2_COUNT_BONUS
		_fire_spread_shuriken(count)
	_finish_action()


# -----------------------------------------------------------------------------
#  移动 / 阶段
# -----------------------------------------------------------------------------

func _move_toward_target(delta: float) -> void:
	_can_move = true
	_move_locked = false
	var to_player: Vector2 = current_target.global_position - global_position
	if to_player.length() <= KEEP_DISTANCE:
		_current_movement = Vector2.ZERO
		return
	_current_movement = to_player.normalized()


func _enter_phase2() -> void:
	_phase2 = true
	if stats != null:
		current_stats.speed = int(max(1.0, float(stats.speed) * P2_SPEED_FACTOR))
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.modulate = Color(1.0, 0.85, 0.85)
	ModLoaderLog.info("叛忍进入二阶段：手里剑 +2、尖刺 +2，新增「0.5s 前摇 + 距离>%.0f 才连冲两次」接分散手里剑" % DASH_CHAIN_MIN_DIST, "bromeme")


# 角色身后：优先用角色的移动方向（没在动就退回"从 boss 指向角色"的反方向）
func _behind_direction(player) -> Vector2:
	var facing = player.get("_current_movement")
	if facing is Vector2 and (facing as Vector2).length() > 0.05:
		return -(facing as Vector2).normalized()
	var away: Vector2 = player.global_position - global_position
	if away.length() < 1.0:
		away = Vector2.RIGHT
	return -away.normalized()


# 夹在地图内：用原版 Entity.init 算好的 _min_pos / _max_pos（已经扣掉贴图半边）
func _clamp_to_zone(pos: Vector2) -> Vector2:
	var out: Vector2 = pos
	if _max_pos.x > _min_pos.x and _max_pos.y > _min_pos.y:
		out.x = clamp(out.x, _min_pos.x, _max_pos.x)
		out.y = clamp(out.y, _min_pos.y, _max_pos.y)
	return out


# -----------------------------------------------------------------------------
#  弹幕
# -----------------------------------------------------------------------------

# 瞬移路径上的尖刺：沿着路径均匀取样，跳过离角色太近的位置（保证躲得掉）
func _fire_path_spikes(from_pos: Vector2, to_pos: Vector2) -> void:
	var count: int = PATH_SPIKE_BASE_COUNT
	if _phase2:
		count += PHASE2_COUNT_BONUS
	var target: Vector2 = current_target.global_position
	for i in count:
		var t: float = 0.0
		if count > 1:
			t = float(i) / float(count - 1)
		var pos: Vector2 = from_pos.linear_interpolate(to_pos, t)
		if pos.distance_to(target) < PATH_SPIKE_SAFE_DIST:
			continue
		var rot: float = (target - pos).angle() + rand_range(-0.12, 0.12)
		_spawn_spike(rot, pos, SPIKE_SPEED)


func _fire_spike_fan(base_angle: float, count: int) -> void:
	for i in count:
		var k: float = 0.0
		if count > 1:
			k = float(i) / float(count - 1) * 2.0 - 1.0
		_spawn_spike(base_angle + k * SPIKE_SPREAD, global_position, SPIKE_SPEED)


func _fire_shuriken_at_player(tint: Color, angle_offset: float) -> void:
	var to_player: float = (current_target.global_position - global_position).angle()
	_spawn_shuriken(to_player + angle_offset, global_position, tint)


func _fire_spread_shuriken(count: int) -> void:
	var to_player: float = (current_target.global_position - global_position).angle()
	for i in count:
		var k: float = 0.0
		if count > 1:
			k = float(i) / float(count - 1) * 2.0 - 1.0
		_spawn_shuriken(to_player + k * SPREAD_ANGLE, global_position, SHURIKEN_PLAIN)


func _spawn_spike(rot: float, pos: Vector2, speed: int) -> void:
	var main = Utils.get_scene_node()
	if main == null:
		return
	var scene = load(SPIKE_SCENE_PATH)
	if scene == null:
		return
	var pool_id: int = Keys.generate_hash(BROMEME_POOL_PREFIX + SPIKE_SCENE_PATH)
	var projectile = main.get_node_from_pool(pool_id, main._enemy_projectiles)
	if not is_instance_valid(projectile):
		projectile = scene.instance()
		main.add_enemy_projectile(projectile)
	projectile.set_meta("pool_id", pool_id)

	projectile.global_position = pos
	projectile.set_from(self)
	projectile.velocity = Vector2.RIGHT.rotated(rot) * float(speed) * RunData.current_run_accessibility_settings.speed
	projectile.rotation = rot
	projectile.set_damage(int(max(1, current_stats.damage)))
	projectile.shoot()


# 自己造一发手里剑：专用对象池（不能借用原版 enemy_projectile 的池，会污染别的怪物的子弹）
func _spawn_shuriken(rot: float, pos: Vector2, tint: Color) -> void:
	var main = Utils.get_scene_node()
	if main == null:
		return
	var scene = load(ENEMY_PROJECTILE_PATH)
	if scene == null:
		return
	var pool_id: int = Keys.generate_hash(BROMEME_POOL_PREFIX + SHURIKEN_TEXTURE_PATH)
	var projectile = main.get_node_from_pool(pool_id, main._enemy_projectiles)
	if not is_instance_valid(projectile):
		projectile = scene.instance()
		main.add_enemy_projectile(projectile)
	projectile.set_meta("pool_id", pool_id)

	projectile.global_position = pos
	projectile.set_from(self)
	projectile.velocity = Vector2.RIGHT.rotated(rot) * float(SHURIKEN_SPEED) * RunData.current_run_accessibility_settings.speed
	projectile.rotation = rot
	projectile.set_damage(int(max(1, round(float(current_stats.damage) * SHURIKEN_DAMAGE_MULT))))

	var sprite = projectile.get_node_or_null("Sprite")
	if sprite != null:
		var tex = load(SHURIKEN_TEXTURE_PATH)
		if tex != null:
			sprite.texture = tex
		sprite.modulate = tint
		sprite.scale = Vector2(1.3, 1.3)
	projectile.shoot()


# -----------------------------------------------------------------------------
#  死亡 / 对象池复用
# -----------------------------------------------------------------------------

func die(args = Utils.default_die_args) -> void:
	.die(args)

	if args != null and args.cleaning_up:
		return

	var main = Utils.get_scene_node()
	if main != null and main.has_method("bromeme_spawn_red_box"):
		main.bromeme_spawn_red_box(self)


func respawn() -> void:
	.respawn()
	_reset_meme_state()


func _reset_meme_state() -> void:
	_br_tell_pending = []
	_br_tell_deferred = []
	_st = St.IDLE
	_st_timer = 0.0
	_phase2 = false
	_attack_timer = ACTION_COOLDOWN
	_burst_left = 0
	_burst_timer = 0.0
	_dash_time_left = 0.0
	_dash_left = 0
	_dash_then_spread = false
	_windup_dir = Vector2.RIGHT
	_reset_windup_plan()
	_chain_immediately = false
	_ban_action_two = false
	_current_movement = Vector2.ZERO
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.modulate = Color(1, 1, 1, 1)
		_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
