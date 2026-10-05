extends "res://entities/units/enemies/boss/boss.gd"

# =============================================================================
#  memeboss：魂5
#
#  一阶段（>50% 血）
#      · 移动靠近玩家（用原版移动行为）
#      · 每 4s 在「玩家方向逆时针 90°」处生成一把由子弹构成的镰刀/关刀，
#        顺时针扫过 180° 后消失（每 0.1s 吐一簇，扫完即止）
#      · 扫完有 35% 概率朝玩家冲刺一次
#
#  二阶段（<=50% 血）
#      · 移动改为远离玩家
#      · 每 2.2s 随机放一种弹幕群（环形/扇形/螺旋，速度随机快慢）
#      · 另有激光（原版 bullet_laser 贴图 + 加速）与红色弩箭
#        （原版十字弩弹贴图染红，速度 = 普通弹幕 3 倍）
#      · 玩家靠近 320px 内有 50% 概率重放一阶段的镰刀连招
#      · 每 10s 朝远离玩家的方向做一次长位移
# =============================================================================

const MOD_DIR: String = "res://mods-unpacked/General-bromeme/"
const SPRITE_PATH: String = MOD_DIR + "meme/content/enemies/hun5/hun5.png"
const LASER_TEXTURE_PATH: String = "res://projectiles/bullet_laser/bullet_laser_0000.png"
const BOLT_TEXTURE_PATH: String = "res://weapons/ranged/crossbow/crossbow_projectile.png"
const ENEMY_PROJECTILE_PATH: String = "res://projectiles/bullet_enemy/enemy_projectile.tscn"
const BROMEME_POOL_PREFIX: String = "bromeme_hun5_pool_"   # 专用对象池前缀（避免污染原版子弹池）
# 挥舞原版武器：镰刀（染黑）和剑（染红）
const SICKLE_TEXTURE_PATH: String = "res://dlcs/dlc_1/weapons/melee/sickle/sickle.png"
const SWORD_TEXTURE_PATH: String = "res://weapons/melee/sword/sword.png"
# 一角鲸的尖刺（原版 dlc_1/enemies/narwhal 就是用它打人）
const SPIKE_SCENE_PATH: String = "res://projectiles/slash/slash_projectile.tscn"

const BULLET_SPEED: int = 300
const BOLT_SPEED: int = 900              # 普通弹幕的 3 倍
const LASER_SPEED: int = 720

const SPRITE_SCALE: float = 0.5625   # 原 0.75，体型缩小 25%
const PHASE2_HP_RATIO: float = 0.5

# 一阶段
const P1_ATTACK_INTERVAL: float = 2.4
# 一阶段每次攻击之间再叠一段随机间隔（0.2 ~ 2s），节奏不固定
const P1_INTERVAL_RANDOM_MIN: float = 0.2
const P1_INTERVAL_RANDOM_MAX: float = 2.0
# 碰撞伤害（本体 Hitbox + 刀身 Hitbox 都用这个）倍率：-15%
const CONTACT_DAMAGE_MULT: float = 0.6
const BLADE_START_OFFSET: float = -PI * 0.5   # 相对玩家方向：逆时针 90°
const BLADE_SWEEP: float = PI                 # 顺时针扫 180°
const BLADE_TIME: float = 1.0                 # 180° 扫完所需时间（决定角速度）
const BLADE_BLADES: int = 7                   # 刀身几发子弹
const BLADE_CURVE: float = 0.16               # 刀身自身的弧度
const BLADE_BASE_DIST: float = 46.0           # 刀身起点到魂5的距离（原来 74，太靠外）
const BLADE_STEP_DIST: float = 22.0           # 每发之间的间距（原来 36）
const BLADE_DRIFT: float = 12.0               # 向外的漂移速度（原来 45，太外扩）

# 镰刀弹幕的"黑色镰刀向前伸出"动作（只是表现，不带伤害）
const BLADE_SPRITE_SCALE: float = 1.7         # 伸出来的黑镰刀大小
const BLADE_SPRITE_REACH: float = 165.0       # 向前伸出的最大距离
const BLADE_SPRITE_TIME: float = 0.5          # 伸出 + 收回的总时长
const BLADE_SPRITE_OUT_RATIO: float = 0.45    # 前 45% 的时间用来伸出，剩下收回
const PHASE1_DASH_CHANCE: float = 0.35

# 二阶段
const P2_ATTACK_INTERVAL: float = 2.2
const P2_SPEED_FACTOR: float = 0.6
const CLOSE_RANGE: float = 320.0
const CLOSE_BLADE_CHANCE: float = 0.5
const DISPLACE_INTERVAL: float = 10.0
const DISPLACE_TIME: float = 0.7
const DISPLACE_SPEED: float = 1500.0
const KEEP_AWAY_RANGE: float = 420.0          # 二阶段贴太近才后退，够远就随机游走
const EDGE_AVOID_MARGIN: float = 170.0        # 离场地边界这么近就开始往中间掰（别被逼到墙角）
const EDGE_CENTER_BIAS: float = 0.65          # 贴边时"回中心"方向的权重
const LEG_MIN: float = 1.0
const LEG_MAX: float = 2.0
const LEG_TURN_RATE: float = 2.4
const BOLT_BURST: int = 9                     # 弩箭连发 9 支
const BOLT_BURST_GAP: float = 0.07
const BOLT_SPREAD: float = 0.12
# 伤害倍率：所有弹幕 -10%；红色的"箭"（弩箭）+10%
const BULLET_DAMAGE_MULT: float = 0.9
const BOLT_DAMAGE_MULT: float = 1.1
# 总体再 -10%（作用在下面所有伤害出口上：弹幕 / 箭 / 碰撞）
const GLOBAL_DAMAGE_MULT: float = 0.9
# 二阶段那圈/扇/螺旋的球状子弹：保持原版颜色（之前改成褐色，用户要求还原）
const PLAIN_BULLET_TINT: Color = Color(1, 1, 1, 1)
const LINE_DURATION: float = 1.8              # 变身台词停留时间

# 武器挥砍
const WEAPON_SWING_TIME: float = 0.9           # 原 0.6，挥砍放慢 → 镰刀/剑扫过去更慢
const WEAPON_SWING_TICK: float = 0.1125        # 跟着挥砍时长一起放慢，保证每轮斩击弹数量不变
const WEAPON_BULLET_SPEED: int = 640          # 镰刀斩击弹（原 320，翻倍）
const WEAPON_HANDLE: float = 92.0             # 武器绕本体旋转的半径（随武器尺寸一起翻倍，免得糊在身上）
const WEAPON_SPRITE_SCALE: float = 1.8        # 镰刀/剑贴图放大倍数（原 0.9，翻倍）
# 刀身碰撞伤害：挥砍 / 镰刀伸出时，把 boss 自带的 Hitbox 临时推到刀身位置并放大，
# 刀扫过玩家就算一次接触伤害（伤害值 = boss 的接触伤害 current_stats.damage）
const WEAPON_HITBOX_REACH: float = 150.0      # 挥砍时 Hitbox 推到多远的刀身位置
const WEAPON_HITBOX_RADIUS: float = 66.0      # 挥砍时的刀身碰撞半径
const BLADE_HITBOX_RADIUS: float = 58.0       # 镰刀伸出时的碰撞半径
const SPIKE_COUNT: int = 7                    # 剑招：正前方 180° 一圈尖刺（原 13，减半，保留正中那发）
const SPIKE_SPEED: int = 720
const SPIKE_SWING_TIME: float = 0.55          # 原 0.35，挥剑动作（只是表现）也放慢
# 近战三招（镰刀突刺 / 挥镰刀 / 挥剑）统一加 0.3s 前摇：
# 前摇和挥砍期间**不停止移动**，只是移速降到 MELEE_MOVE_SPEED_FACTOR（60%）
# —— 用户要求"不要停下，改成移速 60%"。实现方式是临时改 bonus_speed
#   （unit.gd:223 get_move_speed() = current_stats.speed + bonus_speed + decaying_bonus_speed）。
const MELEE_WINDUP_TIME: float = 0.3
const MELEE_MOVE_SPEED_FACTOR: float = 0.6

enum St {IDLE, BLADE, DASH, DISPLACE, WEAPON}

var _st: int = St.IDLE
var _st_timer: float = 0.0
var _phase2: bool = false
var _art_done: bool = false
var _scale_patched: bool = false

var _blade_angle: float = 0.0
var _blade_from: float = 0.0
var _blade_elapsed: float = 0.0
var _displace_timer: float = 0.0
var _attack_timer: float = P1_ATTACK_INTERVAL
var _displace_cooldown: float = DISPLACE_INTERVAL
var _bolt_queue: int = 0
var _bolt_timer: float = 0.0
var _leg_timer: float = 0.0
var _leg_dir: Vector2 = Vector2.RIGHT
var _leg_curved: bool = false
var _leg_spin: float = 0.0
var _line_label: Label = null
var _line_timer: float = 0.0
var _weapon_kind: int = 0
var _weapon_elapsed: float = 0.0
var _weapon_from: float = 0.0
var _weapon_sweep: float = 0.0
var _weapon_tick_timer: float = 0.0
var _weapon_swing_time: float = WEAPON_SWING_TIME
var _weapon_sprite: Sprite = null
# 近战前摇计时（>0 = 还在前摇，站着不动；到 0 才真正出招）
var _melee_windup: float = 0.0
# 前摇结束要回到哪个状态（BLADE / WEAPON）
var _melee_windup_state: int = St.IDLE
# 剑招那一圈尖刺是否已经放过（前摇结束才放，避免前摇期间就吃伤害）
var _spike_fan_fired: bool = false
# 近战减速是否生效中 + 对应的 bonus_speed 偏移（结束时要准确还原）
var _melee_slow_active: bool = false
var _melee_slow_bonus: int = 0

# 镰刀弹幕配套的"黑镰刀向前伸出"表现（挂在 boss 身上，自己 add_child）
var _blade_sprite: Sprite = null
var _blade_sprite_angle: float = 0.0
var _blade_sprite_elapsed: float = 0.0

# 刀身碰撞：用 boss 自带的 Hitbox 变形实现（改前先复制形状资源，别动到共享的那份）
var _hitbox_shape: CollisionShape2D = null
var _hitbox_home_pos: Vector2 = Vector2.ZERO
var _hitbox_home_radius: float = -1.0

onready var _bullets = $Hun5Bullets
onready var _charge_behavior = $ChargeAttackBehavior
onready var _sprite = $Animation/Sprite


func init(zone_min_pos: Vector2, zone_max_pos: Vector2, players_ref: Array = [], entity_spawner_ref = null) -> void:
	.init(zone_min_pos, zone_max_pos, players_ref, entity_spawner_ref)

	_apply_boss_art()
	if _bullets != null:
		_bullets.init(self)
		register_attack_behavior(_bullets)
	if _charge_behavior != null:
		_charge_behavior.init(self)
		register_attack_behavior(_charge_behavior)

	_st = St.IDLE
	_attack_timer = _p1_delay()


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

	for anim_name in ["death", "RESET"]:
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

	if dead:
		return
	# 兜底：替换失败时至少保证活着的时候体型正确
	if not _scale_patched and _sprite != null and is_instance_valid(_sprite):
		_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	# 武器精灵只在 WEAPON 状态存在：如果状态被别的动作抢走（比如挥砍中途后撤），
	# 这里把残留的镰刀/剑清掉，否则会一直挂在手上
	if _st != St.WEAPON and _weapon_sprite != null:
		_weapon_sprite.queue_free()
		_weapon_sprite = null
		_reset_weapon_hitbox()
		# 关键：两个移动开关都要恢复！以前只写了 _can_move = true，
		# _move_locked 留在 true 的话 unit.gd:215 的 get_movement() 会一直返回
		# _current_movement（此时是零向量）→ 魂5 挥砍被打断后就永久停在原地不动。
		_can_move = true
		_move_locked = false
		# 减速也要还原，否则被打断后移速永远只有 60%
		_clear_melee_slow()
		# 前摇被打断时也要把计时清零，否则下一次进 WEAPON 会先白等一个残值
		_melee_windup = 0.0
		_melee_windup_state = St.IDLE
		_move_locked = false
	# 碰撞伤害 -15%（本体 Hitbox 和刀身 Hitbox 是同一个，每帧写一次免得被原版同步覆盖）
	var hitbox = get_node_or_null("Hitbox")
	if hitbox != null:
		hitbox.damage = _contact_damage()
	if current_target == null or not is_instance_valid(current_target):
		return

	if not _phase2 and max_stats.health > 0 and current_stats.health <= int(max_stats.health * PHASE2_HP_RATIO):
		_enter_phase2()

	# 弩箭连发（独立于状态机，打完为止）
	_update_bolt_burst(delta)
	# 变身台词飘字
	_update_line(delta)

	match _st:
		St.BLADE:
			_update_blade(delta)
		St.WEAPON:
			_update_weapon(delta)
		St.DASH:
			_update_dash(delta)
		St.DISPLACE:
			_update_displace(delta)
		_:
			_update_idle(delta)


# -----------------------------------------------------------------------------
#  待机：决定下一招
# -----------------------------------------------------------------------------

func _update_idle(delta: float) -> void:
	# 兜底：IDLE 就是"该自由移动"的状态。任何一招把移动锁住之后没来得及恢复
	# （被打断 / 状态被抢走 / 中途死亡重生），都会在这里解开，避免"停一次就再也不动"。
	_can_move = true
	_move_locked = false

	# 极少数情况下带着未清零的前摇进 IDLE（动作被抢），一并清掉
	_melee_windup = 0.0
	_melee_windup_state = St.IDLE
	# 兜底：近战减速一定要还原（不然被打断后移速一直只有 60%）
	_clear_melee_slow()

	if _phase2:
		_phase2_move(delta)

	_attack_timer -= delta
	if _phase2:
		_displace_cooldown -= delta
		if _displace_cooldown <= 0.0:
			_displace_cooldown = DISPLACE_INTERVAL
			_start_displace()
			return

	if _attack_timer > 0.0:
		return

	if _phase2:
		_attack_timer = P2_ATTACK_INTERVAL
		var distance: float = global_position.distance_to(current_target.global_position)
		if distance <= CLOSE_RANGE and randf() < CLOSE_BLADE_CHANCE:
			_start_melee_attack()    # 玩家贴脸 → 有概率放近战连招（镰刀弹幕 / 挥镰刀 / 挥剑）
		else:
			_fire_random_group()     # 否则随机弹幕群 / 激光 / 弩箭
	else:
		_attack_timer = _p1_delay()
		_start_melee_attack()


# 一阶段（以及二阶段贴脸时）的近战连招：三分之一概率轮到哪一种
func _start_melee_attack() -> void:
	match randi() % 3:
		0:
			_start_blade()
		1:
			_start_weapon_swing(0)   # 镰刀（黑）
		_:
			_start_spike_fan()       # 剑：正前方 180° 一圈一角鲸尖刺


func _enter_phase2() -> void:
	_phase2 = true
	if stats != null:
		current_stats.speed = int(max(1.0, float(stats.speed) * P2_SPEED_FACTOR))
	if _sprite != null:
		_sprite.modulate = Color(1.0, 0.85, 0.85)
	_attack_timer = P2_ATTACK_INTERVAL
	_displace_cooldown = DISPLACE_INTERVAL
	# 变身的瞬间先来一个后撤
	_start_displace()
	_show_line("嘻嘻，我一定要活下去")
	ModLoaderLog.info("魂5 进入二阶段：后撤 + 随机游走 + 弹幕群/激光/红色弩箭", "bromeme")


# 半血时冒一句小字，飘一下淡出
func _show_line(text: String) -> void:
	var main = Utils.get_scene_node()
	if main == null:
		return
	var label := Label.new()
	label.text = text
	label.align = Label.ALIGN_CENTER
	label.valign = Label.VALIGN_CENTER
	label.rect_size = Vector2(360, 40)
	label.rect_position = Vector2(-180, -140)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if main._current_wave_label != null:
		var font: Font = main._current_wave_label.get_font("font")
		if font != null:
			var f = font.duplicate()
			if f is DynamicFont:
				f.size = 22
			label.add_font_override("font", f)
	label.add_color_override("font_color", Color(1.0, 0.95, 0.6, 1.0))
	label.add_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_constant_override("outline_size", 8)
	add_child(label)
	_line_label = label
	_line_timer = LINE_DURATION


func _update_line(delta: float) -> void:
	if _line_label == null or not is_instance_valid(_line_label):
		return
	_line_timer -= delta
	_line_label.rect_position.y -= 16.0 * delta
	_line_label.modulate.a = clamp(_line_timer / LINE_DURATION, 0.0, 1.0)
	if _line_timer <= 0.0:
		_line_label.queue_free()
		_line_label = null


# 二阶段移动：太近就跑开，拉开距离后随机游走（直线/曲线）
func _phase2_move(delta: float) -> void:
	_move_locked = true
	var distance: float = global_position.distance_to(current_target.global_position)

	if distance <= KEEP_AWAY_RANGE:
		var away: Vector2 = global_position - current_target.global_position
		if away.length() < 1.0:
			away = Vector2.RIGHT
		away = away.normalized()
		# 贴边时不要一直往墙里退 → 把方向往场地中心掰，避免被逼到墙角
		if _near_zone_edge():
			var to_center: Vector2 = _zone_center() - global_position
			if to_center.length() > 1.0:
				away = (away * (1.0 - EDGE_CENTER_BIAS) + to_center.normalized() * EDGE_CENTER_BIAS).normalized()
		_current_movement = away
		_leg_timer = 0.0          # 拉开距离后重新抽一段随机路线
		return

	_leg_timer -= delta
	if _leg_timer <= 0.0:
		_start_new_leg()
	if _leg_curved:
		_leg_dir = _leg_dir.rotated(_leg_spin * delta)
	_current_movement = _leg_dir


func _start_new_leg() -> void:
	_leg_timer = rand_range(LEG_MIN, LEG_MAX)
	_leg_curved = randf() < 0.5
	_leg_spin = rand_range(-LEG_TURN_RATE, LEG_TURN_RATE) if _leg_curved else 0.0
	_leg_dir = Vector2.RIGHT.rotated(randf() * TAU)
	# 贴边抽路线时也偏向场地中心，别在墙角附近打转
	if _near_zone_edge():
		var to_center: Vector2 = _zone_center() - global_position
		if to_center.length() > 1.0:
			_leg_dir = (_leg_dir * (1.0 - EDGE_CENTER_BIAS) + to_center.normalized() * EDGE_CENTER_BIAS).normalized()


# 是否贴到场地边界附近（用原版 Entity.init 算好的 _min_pos / _max_pos）
func _near_zone_edge() -> bool:
	if _max_pos.x <= _min_pos.x or _max_pos.y <= _min_pos.y:
		return false
	return global_position.x < _min_pos.x + EDGE_AVOID_MARGIN \
			or global_position.x > _max_pos.x - EDGE_AVOID_MARGIN \
			or global_position.y < _min_pos.y + EDGE_AVOID_MARGIN \
			or global_position.y > _max_pos.y - EDGE_AVOID_MARGIN


func _zone_center() -> Vector2:
	return (_min_pos + _max_pos) * 0.5


# -----------------------------------------------------------------------------
#  一阶段连招：镰刀 / 关刀扫击
# -----------------------------------------------------------------------------

# 近战前摇：返回 true = 还在前摇（调用方这一帧直接 return）。
# 前摇期间**不停止移动**，只是按 60% 移速走（_apply_melee_slow）。
func _melee_windup_update(delta: float) -> bool:
	_apply_melee_slow()
	_melee_windup -= delta
	return _melee_windup > 0.0


# 近战期间减速到 60%：临时给 bonus_speed 加一个负偏移（unit.gd 的 get_move_speed 会算进去），
# 并且恢复移动能力（不锁 _can_move / _move_locked，让它继续追人，只是慢）
func _apply_melee_slow() -> void:
	_can_move = true
	_move_locked = false
	if not _melee_slow_active:
		_melee_slow_active = true
		_melee_slow_bonus = int(round(float(current_stats.speed) * (MELEE_MOVE_SPEED_FACTOR - 1.0)))
	bonus_speed = _melee_slow_bonus


# 近战结束 / 被打断：把减速还原（只还原自己加的那部分，不吃掉冲刺那类别的 bonus_speed）
func _clear_melee_slow() -> void:
	if _melee_slow_active:
		_melee_slow_active = false
		bonus_speed = 0
		_melee_slow_bonus = 0


# 近战起手：起前摇 + 减速到 60%，时间到由 _update_blade / _update_weapon 接手出招
func _begin_melee_windup(state: int) -> void:
	_st = state
	_melee_windup = MELEE_WINDUP_TIME
	_melee_windup_state = state
	# 不停下：只减速（用户要求移速 60%）
	_apply_melee_slow()
	# 上一招被打断时刀身 Hitbox 可能还推在外面，前摇期间收回来（前摇不该有刀身伤害）
	_reset_weapon_hitbox()


func _start_blade() -> void:
	_blade_from = (current_target.global_position - global_position).angle() + BLADE_START_OFFSET
	_blade_angle = _blade_from
	_blade_elapsed = 0.0
	# 先 0.3s 前摇（只减速、不伸刀、不吐刀）；前摇结束时 _update_blade 才真正出招
	_begin_melee_windup(St.BLADE)


func _update_blade(delta: float) -> void:
	# 前摇阶段：只减速，什么都不放
	if _melee_windup > 0.0:
		if _melee_windup_update(delta):
			return

	# 前摇结束，真正开始出招：把黑镰刀朝玩家方向伸出去（纯表现，伤害还是那圈刀身子弹）
	if _blade_elapsed == 0.0 and _blade_sprite == null:
		_blade_from = (current_target.global_position - global_position).angle() + BLADE_START_OFFSET
		_blade_angle = _blade_from
		_spawn_blade_sprite((current_target.global_position - global_position).angle())
		# 只吐一次：整把刀一口气生成，靠子弹自身速度转 180°（不再一簇一簇吐）
		_fire_blade_once()

	# 出招期间继续保持 60% 移速（不停下）
	_apply_melee_slow()

	_blade_elapsed += delta
	_update_blade_sprite(delta)
	# 刀已经在飞了，这里只是等它"扫完"这段时间再收招
	if _blade_elapsed >= BLADE_TIME:
		_clear_blade_sprite()
		_clear_melee_slow()
		_can_move = true
		_move_locked = false
		_st = St.IDLE
		_attack_timer = _p1_delay()
		if not _phase2 and randf() < PHASE1_DASH_CHANCE:
			_start_dash()
		elif _phase2:
			_start_displace()


# -----------------------------------------------------------------------------
#  黑镰刀伸出动作：offset.x 从 0 推到 BLADE_SPRITE_REACH 再收回来
#  （贴图和挥舞用的镰刀同一张，涂成近黑）
# -----------------------------------------------------------------------------

func _spawn_blade_sprite(angle: float) -> void:
	_clear_blade_sprite()
	var tex = load(SICKLE_TEXTURE_PATH)
	if tex == null:
		return
	var sp := Sprite.new()
	sp.texture = tex
	sp.scale = Vector2(BLADE_SPRITE_SCALE, BLADE_SPRITE_SCALE)
	sp.modulate = Color(0.08, 0.08, 0.08, 1.0)
	sp.rotation = angle
	sp.offset = Vector2(0, 0)
	add_child(sp)
	_blade_sprite = sp
	_blade_sprite_angle = angle
	_blade_sprite_elapsed = 0.0


func _update_blade_sprite(delta: float) -> void:
	if _blade_sprite == null or not is_instance_valid(_blade_sprite):
		return
	_blade_sprite_elapsed += delta
	var total: float = max(0.05, BLADE_SPRITE_TIME)
	var t: float = clamp(_blade_sprite_elapsed / total, 0.0, 1.0)
	var reach: float = 0.0
	if t <= BLADE_SPRITE_OUT_RATIO:
		# 快速伸出（ease-out）
		var k: float = t / BLADE_SPRITE_OUT_RATIO
		reach = BLADE_SPRITE_REACH * (1.0 - pow(1.0 - k, 3.0))
	else:
		# 慢慢收回
		var k2: float = (t - BLADE_SPRITE_OUT_RATIO) / max(0.05, 1.0 - BLADE_SPRITE_OUT_RATIO)
		reach = BLADE_SPRITE_REACH * (1.0 - k2 * k2)
	_blade_sprite.offset = Vector2(reach, 0)
	# 伸出的镰刀同样有碰撞伤害：Hitbox 跟着镰刀一起伸出去
	_set_weapon_hitbox(reach, _blade_sprite_angle, BLADE_HITBOX_RADIUS)
	_blade_sprite.modulate.a = 1.0 if t < 0.8 else max(0.0, 1.0 - (t - 0.8) / 0.2)
	if t >= 1.0:
		_clear_blade_sprite()


func _clear_blade_sprite() -> void:
	if _blade_sprite != null and is_instance_valid(_blade_sprite):
		_blade_sprite.queue_free()
	_blade_sprite = null
	_blade_sprite_elapsed = 0.0
	_reset_weapon_hitbox()


# 一次成型：每发子弹带切向速度 → 整把刀往前飞的同时顺时针转，约 180° 后散开
func _fire_blade_once() -> void:
	if _bullets == null or current_target == null:
		return
	_bullets.projectile_damage = _projectile_damage()
	var spin: float = BLADE_SWEEP / max(0.05, BLADE_TIME)   # 角速度

	for i in BLADE_BLADES:
		var d: float = BLADE_BASE_DIST + float(i) * BLADE_STEP_DIST
		var theta: float = _blade_from + float(i) * BLADE_CURVE
		var dir := Vector2(cos(theta), sin(theta))
		var tangential := Vector2(-sin(theta), cos(theta)) * (spin * d)
		var vel: Vector2 = tangential + dir * BLADE_DRIFT
		_bullets.spawn_projectile(vel.angle(), global_position + dir * d, int(round(vel.length())))


# -----------------------------------------------------------------------------
#  近战：挥舞原版镰刀（黑）/ 剑（红）
# -----------------------------------------------------------------------------

func _start_weapon_swing(kind: int) -> void:
	if current_target == null or not is_instance_valid(current_target):
		return
	# 先 0.5s 前摇（站着不动，武器还没开始挥），前摇结束时 _update_weapon 才出招
	_begin_melee_windup(St.WEAPON)
	_weapon_kind = kind
	_weapon_elapsed = 0.0
	_weapon_tick_timer = 0.0
	_weapon_swing_time = WEAPON_SWING_TIME

	var to_player: float = (current_target.global_position - global_position).angle()
	if kind == 0:
		# 镰刀：从左后方横扫到右后方
		_weapon_from = to_player - 1.6
		_weapon_sweep = 3.2
	else:
		# 剑：反方向下劈
		_weapon_from = to_player + 1.2
		_weapon_sweep = -2.4

	_weapon_sprite = Sprite.new()
	var tex = load(SICKLE_TEXTURE_PATH if kind == 0 else SWORD_TEXTURE_PATH)
	if tex != null:
		_weapon_sprite.texture = tex
	_weapon_sprite.scale = Vector2(WEAPON_SPRITE_SCALE, WEAPON_SPRITE_SCALE)
	_weapon_sprite.offset = Vector2(WEAPON_HANDLE, 0)
	_weapon_sprite.modulate = Color(0.08, 0.08, 0.08, 1.0) if kind == 0 else Color(1.0, 0.2, 0.2, 1.0)
	# 前摇期间刀就停在起手角度（看得见要砍哪边，但还没动）
	_weapon_sprite.rotation = _weapon_from
	_weapon_sprite.modulate.a = 1.0
	add_child(_weapon_sprite)


func _update_weapon(delta: float) -> void:
	# 前摇阶段：只减速到 60%，武器停在起手角度，Hitbox 收在老家
	if _melee_windup > 0.0:
		if _melee_windup_update(delta):
			return
		# 前摇结束：按起手角度把刀摆正，清掉上一次挥砍残留的淡出
		if _weapon_sprite != null and is_instance_valid(_weapon_sprite):
			_weapon_sprite.rotation = _weapon_from
			_weapon_sprite.modulate.a = 1.0
		# 剑招：那一圈尖刺现在才放（前摇期间只是举剑）
		if _weapon_kind == 1 and not _spike_fan_fired:
			_spike_fan_fired = true
			if current_target != null and is_instance_valid(current_target):
				_fire_spike_fan((current_target.global_position - global_position).angle())
		_melee_windup_state = St.IDLE

	# 挥砍期间同样保持 60% 移速（不停下）
	_apply_melee_slow()

	_weapon_elapsed += delta
	_weapon_tick_timer -= delta
	var swing_time: float = _weapon_swing_time if _weapon_swing_time > 0.0 else WEAPON_SWING_TIME
	var progress: float = min(1.0, _weapon_elapsed / swing_time)
	var angle: float = _weapon_from + _weapon_sweep * progress

	if _weapon_sprite != null and is_instance_valid(_weapon_sprite):
		_weapon_sprite.rotation = angle
		_weapon_sprite.modulate.a = max(0.25, 1.0 - progress * 0.5)

	# 刀身碰撞：Hitbox 跟着剑/镰刀扫过去
	_set_weapon_hitbox(WEAPON_HITBOX_REACH, angle, WEAPON_HITBOX_RADIUS)

	if _weapon_tick_timer <= 0.0:
		_weapon_tick_timer = WEAPON_SWING_TICK
		_fire_weapon_slash(angle)

	if progress >= 1.0:
		_end_weapon()


func _fire_weapon_slash(angle: float) -> void:
	if _bullets == null:
		return
	_bullets.projectile_damage = _projectile_damage()
	var dir := Vector2.RIGHT.rotated(angle)
	for k in 2:
		var off: Vector2 = dir.rotated(rand_range(-0.14, 0.14)) * rand_range(58.0, 112.0)
		_bullets.spawn_projectile(angle, global_position + off, WEAPON_BULLET_SPEED)


func _end_weapon() -> void:
	if _weapon_sprite != null and is_instance_valid(_weapon_sprite):
		_weapon_sprite.queue_free()
	_weapon_sprite = null
	_reset_weapon_hitbox()
	_clear_melee_slow()
	_st = St.IDLE
	if _phase2:
		_attack_timer = P2_ATTACK_INTERVAL
	else:
		_attack_timer = _p1_delay()


# -----------------------------------------------------------------------------
#  刀身碰撞：把 boss 自带的 Hitbox 推到刀身位置并放大
#  （直接用原版 Hitbox → 伤害流程、无敌帧、击退全都走原版那套）
# -----------------------------------------------------------------------------

func _ensure_weapon_hitbox() -> void:
	if _hitbox_shape != null:
		return
	var hitbox = get_node_or_null("Hitbox")
	if hitbox == null:
		return
	var shape_node = hitbox.get_node_or_null("Collision")
	if shape_node == null:
		return
	if shape_node.shape != null:
		# 形状资源是场景里共享的：先复制一份，免得影响另一只魂5
		shape_node.shape = shape_node.shape.duplicate()
		if shape_node.shape is CircleShape2D:
			_hitbox_home_radius = shape_node.shape.radius
	_hitbox_shape = shape_node
	_hitbox_home_pos = shape_node.position


func _set_weapon_hitbox(reach: float, angle: float, radius: float) -> void:
	_ensure_weapon_hitbox()
	if _hitbox_shape == null:
		return
	if _hitbox_shape.shape is CircleShape2D:
		_hitbox_shape.shape.radius = radius
	_hitbox_shape.position = _hitbox_home_pos + Vector2.RIGHT.rotated(angle) * max(0.0, reach)


func _reset_weapon_hitbox() -> void:
	if _hitbox_shape == null:
		return
	if _hitbox_shape.shape is CircleShape2D and _hitbox_home_radius > 0.0:
		_hitbox_shape.shape.radius = _hitbox_home_radius
	_hitbox_shape.position = _hitbox_home_pos


# -----------------------------------------------------------------------------
#  剑招：正前方 180° 发射一圈「一角鲸」尖刺（模仿原版一角鲸的尖刺攻击）
#  挥剑动作只作为表现，真正的伤害是那一圈尖刺
# -----------------------------------------------------------------------------

func _start_spike_fan() -> void:
	if current_target == null or not is_instance_valid(current_target):
		return
	# 先 0.5s 前摇（站着不动、剑还没挥、尖刺还没放），前摇结束时 _update_weapon 才出招
	_begin_melee_windup(St.WEAPON)
	_weapon_kind = 1
	_weapon_elapsed = 0.0
	_weapon_tick_timer = 999.0        # 这一招不吐普通斩击弹
	_weapon_swing_time = SPIKE_SWING_TIME
	_spike_fan_fired = false

	var to_player: float = (current_target.global_position - global_position).angle()
	_weapon_from = to_player - 0.55
	_weapon_sweep = 1.1

	_weapon_sprite = Sprite.new()
	var tex = load(SWORD_TEXTURE_PATH)
	if tex != null:
		_weapon_sprite.texture = tex
	_weapon_sprite.scale = Vector2(WEAPON_SPRITE_SCALE, WEAPON_SPRITE_SCALE)
	_weapon_sprite.offset = Vector2(WEAPON_HANDLE, 0)
	_weapon_sprite.modulate = Color(1.0, 0.2, 0.2, 1.0)
	_weapon_sprite.modulate.a = 1.0
	_weapon_sprite.rotation = _weapon_from
	add_child(_weapon_sprite)
	# 尖刺推迟到前摇结束后再放（由 _update_weapon 触发 _spike_fan_fired 那一手）


# 正前方 180°：以玩家方向为中心铺一圈尖刺
func _fire_spike_fan(base_angle: float) -> void:
	for i in SPIKE_COUNT:
		var k: float = 0.0
		if SPIKE_COUNT > 1:
			k = float(i) / float(SPIKE_COUNT - 1) * 2.0 - 1.0
		var rot: float = base_angle + k * (PI * 0.5) + rand_range(-0.05, 0.05)
		_spawn_spike(rot, global_position, SPIKE_SPEED)


# 一角鲸的尖刺（原版 slash_projectile），用专用池避免和原版/别的怪串味
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
	projectile.set_damage(_projectile_damage())
	projectile.shoot()


# -----------------------------------------------------------------------------
#  冲刺（复用海象那套 charge 行为）
# -----------------------------------------------------------------------------

func _start_dash() -> void:
	if _charge_behavior == null:
		_st = St.IDLE
		return
	_st = St.DASH
	_st_timer = 0.8
	_charge_behavior.charge_duration = 0.65
	_charge_behavior.charge_speed = 1200.0
	if _charge_behavior._unlock_move_timer != null:
		_charge_behavior._unlock_move_timer.wait_time = 0.65
	_current_attack_behavior = _charge_behavior
	_charge_behavior.reset()
	_charge_behavior._current_cd = 0.0


func _update_dash(delta: float) -> void:
	_st_timer -= delta
	if _st_timer <= 0.0:
		if _charge_behavior != null and _charge_behavior._unlock_move_timer != null \
				and _charge_behavior._unlock_move_timer.time_left > 0.0:
			_charge_behavior._unlock_move_timer.stop()
			_charge_behavior.on_unlock_move_timer_timeout()
		_end_dash_behavior()
		_st = St.IDLE
		if _phase2:
			_attack_timer = P2_ATTACK_INTERVAL
		else:
			_attack_timer = _p1_delay()


# 冲刺结束必须做两件事，否则会"冲一次之后无限冲"：
#  1) 把被 tick 的 attack behavior 换回普通攻击行为（不然 charge 行为还是 current，
#     它自己的冷却一到就会再次触发冲锋）
#  2) 把 charge 的冷却推到很远，双保险
func _end_dash_behavior() -> void:
	if _charge_behavior != null:
		_charge_behavior._current_cd = 99999.0
	if _bullets != null:
		_current_attack_behavior = _bullets


# -----------------------------------------------------------------------------
#  二阶段：长位移（远离玩家）
# -----------------------------------------------------------------------------

func _start_displace() -> void:
	if current_target == null or not is_instance_valid(current_target):
		return
	_st = St.DISPLACE
	_displace_timer = DISPLACE_TIME
	var away: Vector2 = global_position - current_target.global_position
	if away.length() < 1.0:
		away = Vector2.RIGHT
	_move_locked = true
	_current_movement = away.normalized()
	bonus_speed = int(DISPLACE_SPEED)


func _update_displace(delta: float) -> void:
	_displace_timer -= delta
	if _displace_timer <= 0.0:
		bonus_speed = 0
		_move_locked = false
		_st = St.IDLE
		_attack_timer = min(_attack_timer, 0.8)


# -----------------------------------------------------------------------------
#  二阶段：随机弹幕群 / 激光 / 红色弩箭
# -----------------------------------------------------------------------------

func _fire_random_group() -> void:
	# 加权随机：弩箭权重更高（更容易掏弩箭）
	var pick: int = randi() % 10
	match pick:
		0, 1:
			_fire_ring(randi() % 10 + 10, rand_range(0.6, 1.5))
		2, 3:
			_fire_fan(randi() % 4 + 5, rand_range(0.5, 1.1), rand_range(0.7, 1.4))
		4:
			_fire_spiral()
		5, 6:
			_fire_laser()
		_:
			_fire_bolts()          # 7,8,9 → 30% 概率弩箭


# 褐色球状子弹：和 _spawn_custom 一样走专用对象池 + 原版伤害流程，
# 但**不动贴图**（保留原版球状外观），只染色 → 不会污染别的怪物的子弹
func _spawn_tinted_bullet(rot: float, pos: Vector2, speed: int, tint: Color) -> void:
	var main = Utils.get_scene_node()
	if main == null:
		return
	var scene = load(ENEMY_PROJECTILE_PATH)
	if scene == null:
		return
	var pool_id: int = Keys.generate_hash(BROMEME_POOL_PREFIX + "tinted_ball")
	var projectile = main.get_node_from_pool(pool_id, main._enemy_projectiles)
	if not is_instance_valid(projectile):
		projectile = scene.instance()
		main.add_enemy_projectile(projectile)
	projectile.set_meta("pool_id", pool_id)

	projectile.global_position = pos
	projectile.set_from(self)
	projectile.velocity = Vector2.RIGHT.rotated(rot) * float(speed) * RunData.current_run_accessibility_settings.speed
	projectile.rotation = rot
	projectile.set_damage(_projectile_damage())

	var sprite = projectile.get_node_or_null("Sprite")
	if sprite != null:
		sprite.modulate = tint
	projectile.shoot()


func _fire_ring(count: int, speed_mult: float) -> void:
	if _bullets == null:
		return
	var spin: float = randf() * TAU
	var speed: int = int(round(float(BULLET_SPEED) * speed_mult))
	for i in count:
		var a: float = TAU * float(i) / float(count) + spin
		_spawn_tinted_bullet(a, global_position, speed, PLAIN_BULLET_TINT)


func _fire_fan(count: int, spread: float, speed_mult: float) -> void:
	if _bullets == null:
		return
	var to_player: float = (current_target.global_position - global_position).angle()
	var speed: int = int(round(float(BULLET_SPEED) * speed_mult))
	for i in count:
		var k: float = 0.0
		if count > 1:
			k = float(i) / float(count - 1) * 2.0 - 1.0
		_spawn_tinted_bullet(to_player + k * spread, global_position, speed, PLAIN_BULLET_TINT)


# 螺旋：三圈，每圈错开一点
func _fire_spiral() -> void:
	if _bullets == null:
		return
	var base: float = randf() * TAU
	var speed: int = int(round(float(BULLET_SPEED) * rand_range(0.7, 1.3)))
	for ring in 3:
		var offset: float = base + float(ring) * 0.35
		for i in 12:
			_spawn_tinted_bullet(offset + TAU * float(i) / 12.0, global_position, speed, PLAIN_BULLET_TINT)


# 激光：原版 bullet_laser 贴图，拉长 + 加速
func _fire_laser() -> void:
	var to_player: float = (current_target.global_position - global_position).angle()
	var count: int = 1 + randi() % 3
	for i in count:
		var rot: float = to_player + rand_range(-0.28, 0.28)
		_spawn_custom(rot, global_position, LASER_SPEED, Color(1.0, 0.85, 1.0),
				Vector2(1.9, 1.3), LASER_TEXTURE_PATH)


# 红色弩箭：连发 9 支（每 0.07s 一支，边打边瞄玩家）
func _fire_bolts() -> void:
	_bolt_queue = BOLT_BURST
	_bolt_timer = 0.0


func _fire_one_bolt() -> void:
	var to_player: float = (current_target.global_position - global_position).angle()
	_spawn_custom(to_player + rand_range(-BOLT_SPREAD, BOLT_SPREAD), global_position, BOLT_SPEED,
			Color(1.0, 0.25, 0.25), Vector2(1.6, 1.2), BOLT_TEXTURE_PATH, BOLT_DAMAGE_MULT)


func _update_bolt_burst(delta: float) -> void:
	if _bolt_queue <= 0:
		return
	_bolt_timer -= delta
	if _bolt_timer <= 0.0:
		_bolt_timer = BOLT_BURST_GAP
		_bolt_queue -= 1
		_fire_one_bolt()


# 自己造一发敌方抛射物：走**专用对象池** + 原版伤害流程，外观可换贴图/染色/缩放
#
# 重要：不能借用原版 enemy_projectile 的对象池！那个池是全游戏敌人共用的，
# 我们改了池里实例的贴图/染色/缩放后，别的怪物下次取出同一发子弹就会带着
# 我们的外观（这就是"修改其他怪物子弹"的 bug）。所以每种外观用独立 pool_id。
# 一阶段的出手间隔：固定间隔 + 0.2~2s 随机
func _p1_delay() -> float:
	return P1_ATTACK_INTERVAL + rand_range(P1_INTERVAL_RANDOM_MIN, P1_INTERVAL_RANDOM_MAX)


# 碰撞伤害（比弹幕更疼一点，所以单独一个倍率）
func _contact_damage() -> int:
	return int(max(1, round(float(current_stats.damage) * CONTACT_DAMAGE_MULT * GLOBAL_DAMAGE_MULT)))


# 统一的弹幕伤害：默认 -10%（BULLET_DAMAGE_MULT），弩箭那一路传 BOLT_DAMAGE_MULT (+10%)；
# 再统一乘 GLOBAL_DAMAGE_MULT（总体 -10%）
func _projectile_damage(mult: float = BULLET_DAMAGE_MULT) -> int:
	return int(max(1, round(float(current_stats.damage) * mult * GLOBAL_DAMAGE_MULT)))


func _spawn_custom(rot: float, pos: Vector2, speed: int, tint: Color, scale: Vector2, texture_path: String,
		damage_mult: float = BULLET_DAMAGE_MULT) -> void:
	var main = Utils.get_scene_node()
	if main == null:
		return
	var scene = load(ENEMY_PROJECTILE_PATH)
	if scene == null:
		return
	var pool_id: int = Keys.generate_hash(BROMEME_POOL_PREFIX + texture_path)
	var projectile = main.get_node_from_pool(pool_id, main._enemy_projectiles)
	if not is_instance_valid(projectile):
		projectile = scene.instance()
		main.add_enemy_projectile(projectile)
	projectile.set_meta("pool_id", pool_id)

	projectile.global_position = pos
	projectile.set_from(self)
	projectile.velocity = Vector2.RIGHT.rotated(rot) * float(speed) * RunData.current_run_accessibility_settings.speed
	projectile.rotation = rot
	projectile.set_damage(_projectile_damage(damage_mult))

	var sprite = projectile.get_node_or_null("Sprite")
	if sprite != null:
		var tex = load(texture_path)
		if tex != null:
			sprite.texture = tex
		sprite.modulate = tint
		sprite.scale = scale
	projectile.shoot()


func die(args = Utils.default_die_args) -> void:
	.die(args)

	# 死亡瞬间把身上挂的临时节点收掉：挥砍到一半就死的话，武器精灵会僵在手上
	# （而且这个实例回对象池后，武器会跟着留到下一只魂5身上），台词也一起清掉
	_end_weapon()
	_clear_blade_sprite()
	if _line_label != null and is_instance_valid(_line_label):
		_line_label.queue_free()
	_line_label = null
	_line_timer = 0.0

	if args != null and args.cleaning_up:
		return

	var main = Utils.get_scene_node()
	if main != null and main.has_method("bromeme_spawn_red_box"):
		main.bromeme_spawn_red_box(self)


# 对象池复用的入口：被回收后再次刷出走的是 respawn()，init() 不会重跑，
# 所以这里必须自己复位，否则新刷出来的魂5会带着上一只的二阶段/台词/武器。
func respawn() -> void:
	.respawn()
	_reset_meme_state()


# 复位的具体内容：单独放一个函数，探针/调试可以直接调用它检查残留
func _reset_meme_state() -> void:
	_st = St.IDLE
	_st_timer = 0.0
	_phase2 = false
	_displace_timer = 0.0
	_displace_cooldown = DISPLACE_INTERVAL
	_blade_angle = 0.0
	_blade_from = 0.0
	_blade_elapsed = 0.0
	_bolt_queue = 0
	_bolt_timer = 0.0
	_leg_timer = 0.0
	_leg_dir = Vector2.RIGHT
	_leg_curved = false
	_leg_spin = 0.0
	_weapon_kind = 0
	_weapon_elapsed = 0.0
	_weapon_from = 0.0
	_weapon_sweep = 0.0
	_weapon_tick_timer = 0.0
	_weapon_swing_time = WEAPON_SWING_TIME
	_melee_windup = 0.0
	_melee_windup_state = St.IDLE
	_spike_fan_fired = false
	_melee_slow_active = false
	_melee_slow_bonus = 0
	_attack_timer = _p1_delay()
	_end_weapon()
	_clear_blade_sprite()
	if _line_label != null and is_instance_valid(_line_label):
		_line_label.queue_free()
	_line_label = null
	_line_timer = 0.0
	if _bullets != null:
		_current_attack_behavior = _bullets
	# 冲撞中途死亡的话，把 charge 行为的状态也解开（移速/质量/锁移动）
	if _charge_behavior != null:
		_charge_behavior.reset()
	_end_dash_behavior()
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.modulate = Color(1, 1, 1, 1)
		_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
