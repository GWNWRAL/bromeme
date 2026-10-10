extends "res://entities/units/enemies/boss/boss.gd"

# =============================================================================
#  memeboss：王源
#
#  · 血量 = 孙笑川 × 0.8（200 基础 + 1800/波，孙笑川是 250 + 2250/波）
#  · 中心挂一根「烟」（本 mod 烟的道具贴图），指向玩家
#  · 烟持续发射三种弹幕：椭圆（曲率/大小随机，越飞越大）、扇形、线性
#  · 子弹速度 = 孙笑川 250 的 1.5 倍 = 375
#  · 半血进入二阶段：停止移动，再长出一根烟，之后所有烟一起齐射
#  · 死亡照旧掉红色宝箱
# =============================================================================

const MOD_DIR: String = "res://mods-unpacked/General-bromeme/"
const SPRITE_PATH: String = MOD_DIR + "meme/content/enemies/wangyuan/wangyuan.png"
const SMOKE_SCRIPT_PATH: String = MOD_DIR + "meme/content/enemies/wangyuan/smoke.gd"

const BULLET_SPEED: int = 375          # 孙笑川 250 × 1.5
const VOLLEY_INTERVAL: float = 2.0
const FIRST_VOLLEY_DELAY: float = 1.4
const SPRITE_SCALE: float = 0.525  # 原 0.7，体型缩小 25%
const PHASE2_HP_RATIO: float = 0.5
const PHASE2_STAGGER: float = 0.7     # 二阶段多根烟之间的错峰间隔
# 后续烟的摆位：相对王源本体的环带距离（原来只有 ±60/±40 的方形随机，太近）
const SMOKE_MIN_DIST: float = 90.0
const SMOKE_MAX_DIST: float = 200.0
const PATTERN_COUNT: int = 3

# 二阶段移动：移速减慢 + 自己在场地里随机游走（直线或曲线）
const PHASE2_SPEED_FACTOR: float = 0.4     # 相对基础移速
const LEG_MIN: float = 1.0                 # 每段直线/曲线持续多久
const LEG_MAX: float = 1.9
const LEG_TURN_RATE: float = 2.4           # 曲线模式的方向角速度上限(弧度/秒)
const LEG_TOWARD_PLAYER_CHANCE: float = 0.5

var _smokes: Array = []
var _volley_timer: float = 0.0
var _phase2: bool = false
var _art_done: bool = false

var _stagger_queue: Array = []
var _stagger_timer: float = 0.0

var _leg_timer: float = 0.0
var _leg_dir: Vector2 = Vector2.RIGHT
var _leg_curved: bool = false
var _leg_spin: float = 0.0
var _scale_patched: bool = false

onready var _bullets = $SmokeBullets
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
	if _bullets != null:
		_bullets.init(self)
		register_attack_behavior(_bullets)

	_spawn_smoke()
	_volley_timer = VOLLEY_INTERVAL - FIRST_VOLLEY_DELAY


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

	if _phase2:
		_phase2_move(delta)

	# 所有烟都指着玩家
	for smoke in _smokes:
		if is_instance_valid(smoke):
			smoke.aim_at(current_target.global_position)

	_volley_timer += delta
	if _volley_timer >= VOLLEY_INTERVAL:
		_volley_timer = 0.0
		_fire_all_smokes()

	# 错峰：后续的烟隔 PHASE2_STAGGER 再开火
	if not _stagger_queue.empty():
		_stagger_timer -= delta
		if _stagger_timer <= 0.0:
			_stagger_timer = PHASE2_STAGGER
			_fire_smoke(int(_stagger_queue.pop_front()))


# 半血：移速减慢（不是停住），再长一根烟，并开始随机游走


func _enter_phase2() -> void:
	_phase2 = true
	if stats != null:
		current_stats.speed = int(max(1.0, float(stats.speed) * PHASE2_SPEED_FACTOR))
	_start_new_leg()
	_spawn_smoke()
	if _sprite != null:
		_sprite.modulate = Color(1.0, 0.75, 0.75)
	ModLoaderLog.info("王源进入二阶段：移速 x%.2f，%d 根烟错峰开火，随机游走"
			% [PHASE2_SPEED_FACTOR, _smokes.size()], "bromeme")


# 每段随机移动：直线或曲线，方向有概率朝着玩家
func _start_new_leg() -> void:
	_leg_timer = rand_range(LEG_MIN, LEG_MAX)
	_leg_curved = randf() < 0.5
	_leg_spin = rand_range(-LEG_TURN_RATE, LEG_TURN_RATE) if _leg_curved else 0.0

	var angle: float = randf() * TAU
	if current_target != null and is_instance_valid(current_target) and randf() < LEG_TOWARD_PLAYER_CHANCE:
		angle = (current_target.global_position - global_position).angle() + rand_range(-0.9, 0.9)
	_leg_dir = Vector2(cos(angle), sin(angle))


func _phase2_move(delta: float) -> void:
	_leg_timer -= delta
	if _leg_timer <= 0.0:
		_start_new_leg()
	if _leg_curved:
		_leg_dir = _leg_dir.rotated(_leg_spin * delta)
	# 锁住移动方向，让原版"追玩家"的移动行为让位给这套随机游走
	_move_locked = true
	_current_movement = _leg_dir


func _spawn_smoke() -> void:
	var smoke_script = load(SMOKE_SCRIPT_PATH)
	if smoke_script == null:
		return
	var smoke = smoke_script.new()
	smoke.name = "Smoke%d" % (_smokes.size() + 1)
	add_child(smoke)
	smoke.setup(self)
	# 第二根烟（及后续长出来的烟）要离王源本体远一点，否则两根烟几乎叠在一起。
	# 做法：随机角度 + 随机半径，并保证最小间距 SMOKE_MIN_DIST，
	# 让每根烟都落在 [SMOKE_MIN_DIST, SMOKE_MAX_DIST] 的环带里。
	if _smokes.size() > 0:
		var ang: float = randf() * TAU
		var dist: float = rand_range(SMOKE_MIN_DIST, SMOKE_MAX_DIST)
		smoke.position = Vector2(cos(ang), sin(ang)) * dist
	_smokes.append(smoke)


# 每轮：先让第一根烟开火，剩下的（二阶段长出来的）错峰依次开火
func _fire_all_smokes() -> void:
	_br_tell_arm("_br_tell_body__fire_all_smokes", [])


func _br_tell_body__fire_all_smokes() -> void:
	_fire_smoke(0)
	_stagger_queue.clear()
	for i in range(1, _smokes.size()):
		_stagger_queue.append(i)
	if not _stagger_queue.empty():
		_stagger_timer = PHASE2_STAGGER


func _fire_smoke(index: int) -> void:
	if index < 0 or index >= _smokes.size():
		return
	var smoke = _smokes[index]
	if smoke == null or not is_instance_valid(smoke):
		return
	if _bullets != null:
		_bullets.projectile_damage = int(max(1, current_stats.damage))
	smoke.fire_pattern(randi() % PATTERN_COUNT)


# 烟发射的子弹统一出口：全部从烟的中心射出，speed_scale 用来做椭圆调制
func spawn_meme_bullet(rot: float, pos: Vector2, speed_scale: float = 1.0) -> void:
	if _bullets == null:
		return
	var speed: int = int(round(float(BULLET_SPEED) * max(0.05, speed_scale)))
	_bullets.spawn_projectile(rot, pos, speed)


func die(args = Utils.default_die_args) -> void:
	.die(args)

	# 两根烟是自己 add_child 的：死亡时先藏起来、清掉没吐完的弹幕，
	# 免得尸体都缩没了烟还杵在那儿继续开火
	for smoke in _smokes:
		if smoke != null and is_instance_valid(smoke):
			smoke.visible = false
			smoke.clear_queue()

	if args != null and args.cleaning_up:
		return

	var main = Utils.get_scene_node()
	if main != null and main.has_method("bromeme_spawn_red_box"):
		main.bromeme_spawn_red_box(self)


# 对象池复用的入口：被回收后再次刷出走的是 respawn()，init() 不会重跑，
# 所以这里要自己复位状态，并把藏起来的烟重新亮出来。
func respawn() -> void:
	.respawn()
	_reset_meme_state()


# 复位的具体内容：单独放一个函数，探针/调试可以直接调用它检查残留
func _reset_meme_state() -> void:
	_br_tell_pending = []
	_br_tell_deferred = []
	_phase2 = false
	_volley_timer = VOLLEY_INTERVAL - FIRST_VOLLEY_DELAY
	_stagger_queue.clear()
	_stagger_timer = 0.0
	_leg_timer = 0.0
	_leg_dir = Vector2.RIGHT
	_leg_curved = false
	_leg_spin = 0.0
	for smoke in _smokes:
		if smoke != null and is_instance_valid(smoke):
			smoke.visible = true
			smoke.clear_queue()
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.modulate = Color(1, 1, 1, 1)
		_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
