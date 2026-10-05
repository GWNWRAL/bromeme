extends Node2D

# =============================================================================
#  苍 / 赫：挑战者身上环绕的两颗球（等价于「流浪机器人」的环绕，半径更大）
#
#  为什么不用原版宠物系统（PetEffect + pet.tscn）：
#    宠物要走 stat_pets 效果 → 队列 → entity_spawner 实例化 pet.tscn，
#    而 pet.gd 的 _ready 依赖 $TargetBehavior 与菜单信号，自造 .tscn 容易踩坑。
#    这里改成"挂在玩家身上的自管理节点"：视觉与机制（环绕 + 力场 + 接触伤害）一致，
#    但只依赖我们自己写的脚本，稳得多。
#
#  苍（蓝）：吸引怪物与子弹；接触的怪物持续受伤
#  赫（红）：排斥怪物与子弹；接触的怪物持续受伤
#  伤害 = 5 + 200%等级 + 50%meme值   （与物品描述里的 {0}({1}) 对应）
#
#  几何：绕玩家转，半径比流浪机器人更大（它 100~200，这里 240）
# =============================================================================

const RES_DIR: String = "res://mods-unpacked/General-bromeme/"
const CANG_ART: String = RES_DIR + "art/item/bromeme_cang.png"
const HE_ART: String = RES_DIR + "art/item/bromeme_he.png"

const ORBIT_RADIUS: float = 240.0      # 环绕半径（流浪机器人是 100~200）
const ORBIT_SPEED: float = 1.6         # 弧度/秒
const ORB_SCALE: float = 0.85          # 贴图缩放（96px 原图）
const FORCE_RADIUS: float = 300.0      # 力场作用半径
const FORCE_STRENGTH: float = 2200.0   # 力场强度（像素/秒²，按距离衰减）
const BULLET_PULL: float = 260.0       # 对子弹的拉扯强度（像素/秒）
const TOUCH_RADIUS: float = 42.0       # 接触判定半径（等同于"碰到"）
const DAMAGE_INTERVAL: float = 0.35    # 接触伤害的施加间隔（秒）
const BASE_DAMAGE: float = 5.0
const PER_LEVEL: float = 2.0           # 200% 等级
const PER_MELEE: float = 0.5           # 50% 近战伤害
const PER_ELEMENTAL: float = 0.5       # 50% 元素伤害
const PER_MEME: float = 0.5            # 50% meme值

var player_index: int = 0
var _orbs: Array = []
var _phase: float = 0.0
var _damage_timer: float = 0.0
var _touching: Dictionary = {}          # 球索引 -> 当前接触的怪物集合


func set_player_index(value: int) -> void:
	player_index = value


func _ready() -> void:
	_orbs = [
		_make_orb(CANG_ART, -1.0),   # 苍：吸引
		_make_orb(HE_ART, 1.0),      # 赫：排斥
	]


func _make_orb(art_path: String, direction: float) -> Sprite:
	var sprite := Sprite.new()
	var tex := _decode_png(art_path)
	if tex != null:
		sprite.texture = tex
		sprite.scale = Vector2(ORB_SCALE, ORB_SCALE)
	sprite.z_index = 1
	add_child(sprite)
	sprite.set_meta("bromeme_orb_dir", direction)
	return sprite


# 运行时解码 mod 里的 png（这些 png 没有 .import，load() 拿不到）
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


func _physics_process(delta: float) -> void:
	var player = null
	var players = RunData.players_data
	if players != null and player_index < players.size():
		player = players[player_index].get("character")
	var owner_node = get_parent()
	if owner_node == null or not is_instance_valid(owner_node):
		return

	_phase += delta * ORBIT_SPEED
	var origin: Vector2 = owner_node.global_position

	# 两颗球对向环绕
	var idx: int = 0
	for orb in _orbs:
		if orb == null or not is_instance_valid(orb):
			idx += 1
			continue
		var ang: float = _phase + (PI if idx == 1 else 0.0)
		orb.global_position = origin + Vector2(cos(ang), sin(ang)) * ORBIT_RADIUS
		idx += 1

	_apply_forces(delta)

	_damage_timer -= delta
	if _damage_timer <= 0.0:
		_damage_timer = DAMAGE_INTERVAL
		_apply_touch_damage()


# 力场：吸引 / 排斥怪物与子弹
func _apply_forces(delta: float) -> void:
	var spawner = _spawner()
	if spawner == null:
		return
	var enemies: Array = spawner.enemies
	if enemies != null:
		for enemy in enemies:
			if enemy == null or not is_instance_valid(enemy):
				continue
			for orb in _orbs:
				if orb == null or not is_instance_valid(orb):
					continue
				var dir_sign: float = float(orb.get_meta("bromeme_orb_dir"))
				var to_orb: Vector2 = orb.global_position - enemy.global_position
				var dist: float = to_orb.length()
				if dist > FORCE_RADIUS or dist < 0.001:
					continue
				var falloff: float = 1.0 - dist / FORCE_RADIUS
				# 苍 dir_sign=-1 → 朝球（吸引）；赫 dir_sign=+1 → 背球（排斥）
				var push: Vector2 = to_orb.normalized() * (-dir_sign) * FORCE_STRENGTH * falloff * delta
				enemy.global_position += push


func _spawner():
	var main = get_tree().current_scene if get_tree() != null else null
	if main == null:
		return null
	var sp = main.get("_entity_spawner")
	if sp != null:
		return sp
	for child in main.get_children():
		if child != null and child.get("enemies") != null:
			return child
	return null


# 接触伤害：对"贴到球上"的怪物持续造成伤害
func _apply_touch_damage() -> void:
	var spawner = _spawner()
	if spawner == null:
		return
	var enemies: Array = spawner.enemies
	if enemies == null:
		return
	var dmg: int = _current_damage()
	if dmg <= 0:
		return
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		for orb in _orbs:
			if orb == null or not is_instance_valid(orb):
				continue
			if orb.global_position.distance_to(enemy.global_position) > TOUCH_RADIUS:
				continue
			var args = TakeDamageArgs.new(player_index)
			args.from = orb
			enemy.take_damage(dmg, args)


# 伤害 = 5 + 200%等级 + 50%meme值 + 50%近战伤害 + 50%元素伤害
# （与物品描述里的 {0}({1}) 保持一致，改这里要同时改
#   brolab_compat/contents/effects/orb_pet_effect.gd）
func _current_damage() -> int:
	var level: float = float(RunData.get_player_level(player_index))
	var meme: float = float(Utils.get_stat(Keys.generate_hash("stat_meme"), player_index))
	var melee: float = float(Utils.get_stat(Keys.generate_hash("stat_melee_damage"), player_index))
	var elemental: float = float(Utils.get_stat(Keys.generate_hash("stat_elemental_damage"), player_index))
	return int(round(BASE_DAMAGE + PER_LEVEL * level + PER_MELEE * melee + PER_ELEMENTAL * elemental + PER_MEME * meme))
