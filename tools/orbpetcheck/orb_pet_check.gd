extends "res://stub_pet.gd"

class _StubDamageArgs:
	var from_player_index: int = 0
	var from = null
	func _init(_i: int = 0, _h = null) -> void:
		from_player_index = _i

class _StubKeys:
	var empty_hash: int = 0
	func generate_hash(_s: String) -> int: return 0

class _StubRunData:
	var players_data = []
	func get_player_level(_i: int) -> int: return 1
	func get_player_count() -> int: return 1

class _StubUtils:
	func get_stat(_h: int, _i: int) -> float: return 0.0
	func get_scene_node(): return null

class _StubWeaponStatsArgs:
	pass

class _StubWeaponService:
	func init_melee_pet_stats(_a, _b, _c = null):
		return null

class _StubLog:
	func info(_a, _b = "") -> void: pass

var ModLoaderLog = _StubLog.new()
var WeaponServiceInitStatsArgs = _StubWeaponStatsArgs
var WeaponService = _StubWeaponService.new()
var Keys = _StubKeys.new()
var RunData = _StubRunData.new()
var Utils = _StubUtils.new()
var TakeDamageArgs = _StubDamageArgs


# =============================================================================
#  苍 / 赫：绕玩家环绕的两颗球（真宠物，走原版 stat_pets 生成流程）
#
#  写法照抄卡皮巴拉 / Toys&Balls：
#    · 宠物场景实例化 res://entities/units/pet/pet.tscn，并**显式覆盖 stats**
#      （pet.tscn 根来自 unit.tscn，其 stats 是 null；不给就会在
#       Unit.init_current_stats() 的 max_stats.copy_stats(stats) 处原生崩溃）
#    · 脚本 extends Pet，移动方式自己写
#    · 数值只存在一处：orb_weapon_stats.tres（描述与实伤共用，避免两处不一致）
#
#  区别：不追怪，固定绕玩家转，半径比流浪机器人更大（它 100~200，这里 240）。
#  苍：吸引怪物与子弹；赫：排斥。两者都对碰到的怪物持续造成伤害。
# =============================================================================

# 贴图读构建产物 art/item/<json名>.png —— 构建脚本按 **json 文件名(stem)** 命名：
#   1791000301.json（苍）→ art/item/1791000301.png
#   1791000302.json（赫）→ art/item/1791000302.png
# 注意：resources/icons/ 不进 zip（构建脚本的既有约定），所以不能读那里。
const CANG_ART: String = "res://mods-unpacked/General-bromeme/art/item/1791000301.png"
const HE_ART: String = "res://mods-unpacked/General-bromeme/art/item/1791000302.png"
const WEAPON_STATS_PATH: String = "res://mods-unpacked/General-bromeme/content/pets/orb/orb_weapon_stats.tres"
const PET_STATS_PATH: String = "res://mods-unpacked/General-bromeme/content/pets/orb/orb_stats.tres"

const ORBIT_RADIUS: float = 240.0
const ORBIT_SPEED: float = 1.6
const ART_SCALE: float = 0.85
const FORCE_RADIUS: float = 300.0
# 力场强度：每帧位移 = FORCE_STRENGTH * falloff * PER_FRAME_STEP（像素）
# 2200（太强）→ 450（仍偏强）→ 150
const FORCE_STRENGTH: float = 150.0
const PER_FRAME_STEP: float = 0.016
const CANG_DAMAGE_MULT: float = 0.5            # 苍的伤害减半（用户要求）
# 接触伤害判定半径：原 46 → 92（碰撞体积翻倍，用户要求）
const TOUCH_RADIUS: float = 92.0
const DAMAGE_INTERVAL: float = 0.35

# 由场景覆盖：true = 吸引（苍），false = 排斥（赫）
export (bool) var is_attract: bool = true
export (float) var orbit_radius: float = ORBIT_RADIUS

var _phase: float = 0.0
var _damage_timer: float = 0.0
var _art_done: bool = false
var _weapon_stats = null
# 照抄原版 WanderingBot：玩家引用来自 init() 传进来的 players_ref。
# 之前用 RunData.players_data[pi].get("character") 取不到，所以球根本不动。
var _players: Array = []


# 原版 WanderingBot 就是这么拿玩家引用的
func init(zone_min_pos: Vector2, zone_max_pos: Vector2, players_ref: Array = [], entity_spawner_ref = null) -> void:
	.init(zone_min_pos, zone_max_pos, players_ref, entity_spawner_ref)
	_players = players_ref


func _ready() -> void:
	# ⚠️ 故意**不**调用 Pet._ready()：它会连 pause menu 信号（重复连报
	#   ERR_INVALID_PARAMETER）并访问 _animation.modulate。这颗球不需要那套。
	#
	# 兜底：场景若没成功覆盖 stats，这里补上。绝不能是 null ——
	# Unit.init_current_stats() 会直接 stats.get_base_health() / copy_stats(stats)。
	if stats == null:
		stats = load(PET_STATS_PATH)
	_phase = 0.0
	_weapon_stats = load(WEAPON_STATS_PATH)
	_apply_art()
	_setup_range()


# 自己的范围探测：照原版 WanderingBot 的 Range（layer=0, mask=ENEMIES_BIT）
func _setup_range() -> void:
	if get_node_or_null("BromemeRange") != null:
		return
	var range_area := Area2D.new()
	range_area.name = "BromemeRange"
	range_area.collision_layer = 0
	range_area.collision_mask = 4          # ENEMIES_BIT
	range_area.monitorable = false
	range_area.monitoring = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = FORCE_RADIUS
	shape.shape = circle
	range_area.add_child(shape)
	add_child(range_area)
	range_area.connect("body_entered", self, "_on_range_body_entered")
	range_area.connect("body_exited", self, "_on_range_body_exited")


var _near_bodies: Dictionary = {}


func _on_range_body_entered(body) -> void:
	if body == null or not is_instance_valid(body):
		return
	_near_bodies[body.get_instance_id()] = body


func _on_range_body_exited(body) -> void:
	if body == null:
		return
	_near_bodies.erase(body.get_instance_id())


func _apply_art() -> void:
	if _art_done:
		return
	_art_done = true
	var path: String = CANG_ART if is_attract else HE_ART
	var tex := _decode_png(path)
	if tex == null:
		return
	for node_path in ["Animation/Sprite", "Animation/Sprite2D"]:
		var sp = get_node_or_null(node_path)
		if sp != null and sp is Sprite:
			sp.texture = tex
			sp.scale = Vector2(ART_SCALE, ART_SCALE)
			sp.position = Vector2.ZERO


func update_highlight(_value: bool = true) -> void:
	pass


func _update_transparency(_value) -> void:
	pass


func _decode_png(path: String) -> Texture:
	var file := File.new()
	if file.open(path, File.READ) != OK:
		return null
	var buffer: PoolByteArray = file.get_buffer(file.get_len())
	file.close()
	var image := Image.new()
	if image.load_png_from_buffer(buffer) != OK:
		return null
	image.convert(Image.FORMAT_RGBA8)
	var tex := ImageTexture.new()
	tex.create_from_image(image, Texture.FLAG_FILTER)
	return tex


# 用 _process 而不是 _process：
#   Unit 定义了 _process（每帧移动/动画/物理积分），若我们覆写它且不调
#   super，基类那套就被顶掉；实测球完全不环绕。_process 基类没定义，互不干扰。
func _process(delta: float) -> void:
	if dead:
		return
	# 照原版 WanderingBot：直接用 init() 拿到的 players_ref
	if player_index < 0 or player_index >= _players.size():
		return
	var player = _players[player_index]
	if player == null or not is_instance_valid(player):
		return

	# 环绕（不走父类的 TargetBehavior 追怪）
	_phase += delta * ORBIT_SPEED
	var ang: float = _phase if is_attract else _phase + PI
	var ppos: Vector2 = player.global_position
	global_position = Vector2(ppos.x + cos(ang) * orbit_radius, ppos.y + sin(ang) * orbit_radius)

	_apply_forces()

	_damage_timer -= delta
	if _damage_timer <= 0.0:
		_damage_timer = DAMAGE_INTERVAL
		_apply_touch_damage()


# 力场：苍吸引 / 赫排斥
# 用 Area2D 的 body_entered/exited 事件维护"在册怪物"，不再遍历 _entity_spawner.enemies
func _apply_forces() -> void:
	if _near_bodies.empty():
		return
	var dir_sign: float = 1.0 if is_attract else -1.0
	var dead_keys: Array = []
	for key in _near_bodies.keys():
		var enemy = _near_bodies[key]
		if enemy == null or not is_instance_valid(enemy):
			dead_keys.append(key)
			continue
		var delta_v: Vector2 = global_position - enemy.global_position
		var dist: float = delta_v.length()
		if dist > FORCE_RADIUS or dist < 0.001:
			continue
		var falloff: float = 1.0 - dist / FORCE_RADIUS
		# 吸引 → 朝球；排斥 → 背球
		enemy.global_position += delta_v.normalized() * dir_sign * FORCE_STRENGTH * falloff * PER_FRAME_STEP
	for key in dead_keys:
		_near_bodies.erase(key)


func _apply_touch_damage() -> void:
	if _near_bodies.empty():
		return
	var dmg: int = _current_damage()
	if dmg <= 0:
		return
	var dead_keys: Array = []
	for key in _near_bodies.keys():
		var enemy = _near_bodies[key]
		if enemy == null or not is_instance_valid(enemy):
			dead_keys.append(key)
			continue
		if global_position.distance_to(enemy.global_position) > TOUCH_RADIUS:
			continue
		var args = TakeDamageArgs.new(player_index)
		args.from = self
		enemy.take_damage(dmg, args)
	for key in dead_keys:
		_near_bodies.erase(key)


# 与物品描述同一个来源：orb_weapon_stats.tres
# 苍（is_attract=true）再乘 CANG_DAMAGE_MULT（减半），赫保持原值。
func _current_damage() -> int:
	if _weapon_stats == null:
		_weapon_stats = load(WEAPON_STATS_PATH)
	if _weapon_stats == null:
		return 5
	var args = WeaponServiceInitStatsArgs.new()
	var current_stats = WeaponService.init_melee_pet_stats(_weapon_stats, player_index, args)
	if current_stats == null:
		return 5
	var dmg: float = float(current_stats.damage)
	if is_attract:
		dmg *= CANG_DAMAGE_MULT
	return int(max(1, round(dmg)))
