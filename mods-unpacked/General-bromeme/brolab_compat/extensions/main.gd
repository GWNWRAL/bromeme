extends "res://main.gd"


var bromeme_midas_timers: Dictionary = {}

# --- 挑战者的减速光环（常量必须放在所有函数之前）--------------------------------
const BROMEME_AURA_RADIUS: float = 150.0       # 击退光环半径
const BROMEME_ENEMY_LAYER: int = 4             # 敌人物理 body 的碰撞层（ENEMIES_BIT）

var _bromeme_addons_done: bool = false


func _ready():
	for player_index in _players.size():
		var player = _players[player_index]
		
		# Handle Midas
		# value, brolab_midas_count, brolab_midas_multiplier, curse_factor
		var midas_effects: Array = RunData.get_player_effect(Keys.generate_hash("brolab_effect_midas_hand"), player_index)
		
		if not midas_effects.empty():
			if not bromeme_midas_timers.has(player_index):
				bromeme_midas_timers[player_index] = []
			
			for midas_effect in midas_effects:
				var timer: Timer = Timer.new()
				timer.one_shot = false
				timer.wait_time = midas_effect[0]
				timer.name = "BrolabMidasTimer"
				player.add_child(timer)
				timer.start()
				timer.connect("timeout", self, "_on_brolab_midas_timer_timeout", [midas_effect[1], midas_effect[2], player_index])
				bromeme_midas_timers[player_index].push_back(timer)
		
		var need_reset_player: bool = false
		# value, brolab_receive_item_id, brolab_receive_item_wave, curse_factor, is_cursed, end_wave
		var receive_item_effects: Array = RunData.get_player_effect(Keys.generate_hash("brolab_effect_receive_item_at_wave"), player_index)
		if not receive_item_effects.empty():
			# Cache
			var _item = ItemService.get_item_from_id(Keys.generate_hash("item_acid"))
			
			var remove_array: Array = []
			for receive_item_effect in receive_item_effects:
				if receive_item_effect[2] <= RunData.current_wave:
					var end_wave = -1 
					if receive_item_effect.size() > 5:
						end_wave = receive_item_effect[5]
					if end_wave <= 0:
						remove_array.push_back(receive_item_effect)
					elif end_wave < RunData.current_wave:
						remove_array.push_back(receive_item_effect)
						continue
					
					var item_data = ItemService.get_element(ItemService.items, Keys.generate_hash(receive_item_effect[1]))
					if not item_data == null:
						var is_cursed: bool = receive_item_effect[4]
						var dlc = null
						var actual_item_data = item_data
						
						if is_cursed:
							dlc = ProgressData.get_dlc_data("abyssal_terrors")	
						
						for i in receive_item_effect[0]:
							if dlc:
								actual_item_data = dlc.curse_item(item_data, player_index, false)
							if actual_item_data.my_id_hash == Keys.item_axolotl_hash:
								for effect in actual_item_data.effects:
									if effect is SwapMaxMinStatEffect:
										effect.stats_swapped = effect._find_min_max_stat_keys(player_index)
							RunData.add_item(actual_item_data, player_index)
							
						_floating_text_manager.display_icon(receive_item_effect[0], item_data.icon, _floating_text_manager.stat_pos_sounds, _floating_text_manager.stat_neg_sounds, player.global_position - Vector2(0, 50), _floating_text_manager.direction, -10.0)
						
						need_reset_player = true
			
			for remove_entry in remove_array:
				receive_item_effects.erase(remove_entry)
		
		# value, brolab_receive_stat_key, brolab_receive_stat_wave, curse_factor, end_wave
		var receive_stat_effects: Array = RunData.get_player_effect(Keys.generate_hash("brolab_effect_receive_stat_at_wave"), player_index)
		if not receive_stat_effects.empty():
			var remove_array: Array = []
			
			for receive_stat_effect in receive_stat_effects:
				if receive_stat_effect[2] <= RunData.current_wave:
					var end_wave = -1 
					if receive_stat_effect.size() > 4:
						end_wave = receive_stat_effect[4]
					if end_wave <= 0:
						remove_array.push_back(receive_stat_effect)
					elif end_wave < RunData.current_wave:
						remove_array.push_back(receive_stat_effect)
						continue
					
					var effects: Dictionary = RunData.get_player_effects(player_index)
					if effects.has(Keys.generate_hash(receive_stat_effect[1])):
						RunData.add_stat(Keys.generate_hash(receive_stat_effect[1]), receive_stat_effect[0], player_index)
						
						need_reset_player = true
			
			for remove_entry in remove_array:
				receive_stat_effects.erase(remove_entry)
		
		# [key, value, starting_wave, end_wave]
		var stats_end_of_wave_after_wave: Array = RunData.get_player_effect(Keys.generate_hash("brolab_stats_end_of_wave_after_wave"), player_index)
		if not stats_end_of_wave_after_wave.empty():
			var remove_array: = []
			for j in stats_end_of_wave_after_wave.size():
				var eff = stats_end_of_wave_after_wave[j]
				if RunData.current_wave == int(eff[2]):
					var effect_items: Array = RunData.get_player_effect(Keys.generate_hash("stats_end_of_wave"), player_index)
					var has_effect: bool = false
					for existing_item in effect_items:
						if existing_item[0] == eff[0]:
							existing_item[1] += int(eff[1])
							has_effect = true
							break
					if not has_effect:
						effect_items.append([eff[0], int(eff[1])]) 
				if RunData.current_wave == (int(eff[3]) + 1):
					var effect_items: Array = RunData.get_player_effect(Keys.generate_hash("stats_end_of_wave"), player_index)
					for i in effect_items.size():
						var effect_item = effect_items[i]
						if effect_item[0] == eff[0]:
							effect_item[1] -= eff[1]
							if effect_item[1] == 0:
								effect_items.remove(i)
							break
					
					remove_array.push_back(eff)
			for j in remove_array:
				stats_end_of_wave_after_wave.erase(j)
		
		if need_reset_player:
			player.update_player_stats(true)

func _on_WaveTimer_timeout() -> void:
	._on_WaveTimer_timeout()
	for timers in bromeme_midas_timers.values():
		for timer in timers:
			if is_instance_valid(timer):
				timer.queue_free()
	
	# key, value, pct_converted, to_stat, to_value, target_wave
	for player_index in _players.size():
		var current_wave = RunData.current_wave
		for eff in RunData.get_player_effect(Keys.generate_hash("brolab_effect_convert_stats_at_wave"), player_index):
			if current_wave == int(eff[5]):
				var effects: Dictionary = RunData.get_player_effects(player_index)
				
				if (not eff[0] == "materials" and not effects.has(Keys.generate_hash(eff[0])) or (not eff[3] == "materials" and not effects.has(Keys.generate_hash(eff[3])))):
					continue
				
				var from_value = 0
				if not eff[0] == "materials":
					from_value = effects[Keys.generate_hash(eff[0])]
				else:
					from_value = RunData.get_player_gold(player_index)
				
				if from_value == 0:
					continue
				
				var from_value_pct = from_value * float(eff[2])
				var from_value_chunk = int(floor(from_value_pct / eff[1]))
				
				if from_value_chunk == 0:
					return
				
				from_value_pct = from_value_chunk * eff[1]
				var to_value = int(max(1, from_value_chunk * int(eff[4])))
				
				if not eff[0] == "materials":
					RunData.remove_stat(Keys.generate_hash(eff[0]), from_value_pct, player_index)
				else:
					RunData.remove_gold(from_value_pct, player_index)
				
				if not eff[3] == "materials":
					RunData.add_stat(Keys.generate_hash(eff[3]), to_value, player_index)
				else:
					RunData.add_gold(to_value, player_index)
				
				_players[player_index].update_player_stats(true)


func _on_brolab_midas_timer_timeout(count: int, multiplier: int, player_index: int) -> void:
	var all_enemies: Array = _entity_spawner.enemies
	if all_enemies.empty():
		return
	
	var enemies: Array = []
	if all_enemies.size() <= count:
		enemies = all_enemies
	
	if enemies.empty():
		var index_array: Array = []
		for i in all_enemies.size():
			index_array.append(i)
		
		for i in count:
			var index = Utils.get_rand_element(index_array)
			index_array.erase(index)
			
			enemies.append(all_enemies[index])
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy.get("_pending_die"):
			continue
		
		var take_damage_args: = TakeDamageArgs.new(player_index)
		enemy.stats = enemy.stats.duplicate()
		enemy.stats.value *= multiplier
		enemy.take_damage(max(999999, enemy.max_stats.health * 3), take_damage_args)


# =============================================================================
#  meme 值 / meme 入侵 / memeboss
# =============================================================================

const MEME_STAT_KEY: String = "stat_meme"
# meme 入侵的 boss 池：每次随机抽一个
const MEME_BOSS_POOL: Array = [
	"res://mods-unpacked/General-bromeme/meme/content/enemies/sunxiaochuan/sunxiaochuan.tscn",
	"res://mods-unpacked/General-bromeme/meme/content/enemies/wangyuan/wangyuan.tscn",
	"res://mods-unpacked/General-bromeme/meme/content/enemies/van/van.tscn",
	"res://mods-unpacked/General-bromeme/meme/content/enemies/hun5/hun5.tscn",
	"res://mods-unpacked/General-bromeme/meme/content/enemies/panren/panren.tscn",
]
const MEME_FX_SCRIPT_PATH: String = "res://mods-unpacked/General-bromeme/meme/meme_invasion.gd"
const RED_BOX_DATA_PATH: String = "res://items/consumables/legendary_item_box/legendary_item_box_data.tres"
const MEME_BOSS_SPAWN_DISTANCE: float = 430.0
const MEME_LOG_NAME: String = "bromeme"
# 每局的固定盐值（存到 user:// 里）：同一局里不管怎么读档重打同一波，
# "这波有没有 meme 入侵 / 抽到哪个 boss"都不会变；换一局才会变。
const MEME_SALT_PATH: String = "user://bromeme_meme_salt.json"

var _meme_run_salt: int = 0
var _meme_salt_identity: String = ""
# 挑战者（character_bromeme_challenger_777）身上的标记：每一波必定入侵
const MEME_ALWAYS_MARKER: String = "bromeme_always_meme_invade"


func _on_EntitySpawner_players_spawned(players: Array) -> void:
	._on_EntitySpawner_players_spawned(players)
	call_deferred("_bromeme_check_meme_invasion")


# 给玩家挂两个自管理节点：
#   1) 减速光环（Area2D，只在自己是挑战者时生效）
#   2) 苍 / 赫 的环绕球（挑战者初始携带）
# 给玩家挂减速光环（Area2D，只在自己是挑战者时生效）。
# 苍/赫 不做在这里 —— 它们现在是**真宠物**，由原版 stat_pets 流程生成
# （物品 json 用 PetEffect + scene，见 content/pets/orb/）。
# =============================================================================
#  挑战者：每 1 秒击退周围敌人（用户 2.42.28 要求，取代原来的减速光环）
#
#  实现要点（借鉴炮塔那条灯笼 knockback_aura 的思路）：
#    * 用 Timer 每秒触发一次，而不是每帧遍历全场敌人
#    * "周围有哪些敌人"由 Area2D 的 body_entered/body_exited 事件维护（照原版
#      WanderingBot 的 Range 写法：collision_layer=0, mask=4），**绝不遍历
#      _entity_spawner.enemies** —— 那是之前原生访问违例崩溃的来源
#    * 击退直接写 enemy.knockback_vector（Unit 自带），方向是"从玩家指向敌人"
# =============================================================================
const BROMEME_KNOCKBACK_INTERVAL: float = 1.0
const BROMEME_KNOCKBACK_FORCE: float = 420.0


func _bromeme_attach_player_addons() -> void:
	for player_index in _players.size():
		var player = _players[player_index]
		if player == null or not is_instance_valid(player):
			continue

		# 范围检测：怪物（ENEMIES_BIT=4）作为物理 body 进来
		if player.get_node_or_null("BromemeAura") == null:
			var aura := Area2D.new()
			aura.name = "BromemeAura"
			aura.collision_layer = 0
			aura.collision_mask = BROMEME_ENEMY_LAYER
			aura.monitorable = false
			aura.monitoring = true
			var shape := CollisionShape2D.new()
			var circle := CircleShape2D.new()
			circle.radius = BROMEME_AURA_RADIUS
			shape.shape = circle
			aura.add_child(shape)
			player.add_child(aura)
			aura.connect("body_entered", self, "_bromeme_aura_body_entered")
			aura.connect("body_exited", self, "_bromeme_aura_body_exited")

			# 每秒触发一次击退
			var timer := Timer.new()
			timer.name = "BromemeKnockbackTimer"
			timer.wait_time = BROMEME_KNOCKBACK_INTERVAL
			timer.autostart = true
			timer.one_shot = false
			player.add_child(timer)
			timer.connect("timeout", self, "_bromeme_knockback_timeout", [player])
			ModLoaderLog.info("击退光环：已挂载（玩家数=%d）" % _players.size(), MEME_LOG_NAME)


# 在册的怪物（进入范围时登记，离开时移除）
var _bromeme_aura_bodies: Dictionary = {}


func _bromeme_aura_body_entered(body) -> void:
	if body == null or not is_instance_valid(body):
		return
	_bromeme_aura_bodies[body.get_instance_id()] = body


func _bromeme_aura_body_exited(body) -> void:
	if body == null:
		return
	_bromeme_aura_bodies.erase(body.get_instance_id())


# 每 1 秒：把在册的怪物从玩家身边推开
func _bromeme_knockback_timeout(player) -> void:
	if player == null or not is_instance_valid(player):
		return
	for player_index in _players.size():
		if _players[player_index] != player:
			continue
		if not _bromeme_is_challenger(player_index):
			return
		break

	var origin: Vector2 = player.global_position
	var dead_keys: Array = []
	var pushed: int = 0
	for key in _bromeme_aura_bodies.keys():
		var enemy = _bromeme_aura_bodies[key]
		if enemy == null or not is_instance_valid(enemy):
			dead_keys.append(key)
			continue
		var delta_v: Vector2 = enemy.global_position - origin
		var dist: float = delta_v.length()
		if dist > BROMEME_AURA_RADIUS:
			continue
		var dir: Vector2 = delta_v.normalized() if dist > 0.001 else Vector2.RIGHT
		# Unit.knockback_vector 是原版自带的击退累积量
		enemy.knockback_vector = dir * BROMEME_KNOCKBACK_FORCE
		pushed += 1
	for key in dead_keys:
		_bromeme_aura_bodies.erase(key)
	if pushed > 0:
		ModLoaderLog.info("击退光环：推开了 %d 个敌人" % pushed, MEME_LOG_NAME)


func _bromeme_get_aura(player):
	if player == null or not is_instance_valid(player):
		return null
	return player.get_node_or_null("BromemeAura")


func _physics_process(delta: float) -> void:
	._physics_process(delta)
	_bromeme_ensure_addons()


# 把"给玩家挂击退光环"放到每帧补齐，而不是依赖 call_deferred
# （实测那一条 deferred 调用在这个脚本上不执行，同一个钩子里的入侵检查却会跑）。
func _bromeme_ensure_addons() -> void:
	if _bromeme_addons_done:
		return
	if _players.size() == 0:
		return
	_bromeme_addons_done = true
	_bromeme_attach_player_addons()


func bromeme_meme_value(player_index: int) -> int:
	return int(Utils.get_stat(Keys.generate_hash(MEME_STAT_KEY), player_index))


# 角色身上带 bromeme_always_meme_invade 标记（挑战者）→ 无视 meme 值必定入侵
func bromeme_forces_invasion(player_index: int) -> bool:
	var character = RunData.get_player_character(player_index)
	if character == null:
		return false
	for effect in character.effects:
		if effect == null or not is_instance_valid(effect):
			continue
		if String(effect.custom_key) == MEME_ALWAYS_MARKER:
			return true
	return false


# meme 入侵概率曲线（用户指定）：y = 1 - exp(-(max(x,0)/100)^0.9)
#   1 点 ≈ 2.6%   9 点 ≈ 20.0%   50 点 ≈ 47.9%   100 点 ≈ 63.2%
# 说明行的实时概率（extensions/text_bromeme.gd）用同一个公式，改这里要一起改。
func bromeme_meme_invasion_chance(value: int) -> float:
	var x: float = max(0.0, float(value))
	return 1.0 - exp(-pow(x / 100.0, 0.9))


# -----------------------------------------------------------------------------
#  固定随机数（本局盐值）
# -----------------------------------------------------------------------------

func _bromeme_run_identity() -> String:
	var character_id: String = ""
	var character = RunData.get_player_character(0)
	if character != null:
		character_id = String(character.my_id)
	return "%s|%d|%d|%d" % [character_id, int(RunData.current_difficulty), int(RunData.current_zone), int(RunData.nb_of_waves)]


# 本局是不是读档继续来的（RunData 扩展里维护；扩展没装上时安全地当作"新开一局"）
func bromeme_run_resumed() -> bool:
	return bool(RunData.get("bromeme_run_resumed"))


func _bromeme_ensure_salt() -> void:
	var identity: String = _bromeme_run_identity()
	var stored: Dictionary = {}
	var file := File.new()
	if file.file_exists(MEME_SALT_PATH) and file.open(MEME_SALT_PATH, File.READ) == OK:
		var parsed = parse_json(file.get_as_text())
		file.close()
		if parsed is Dictionary:
			stored = parsed

	var resumed: bool = bromeme_run_resumed()
	var wave: int = int(RunData.current_wave)
	var retries: int = int(RunData.retries)
	var reuse: bool = int(stored.get("salt", 0)) != 0 \
			and String(stored.get("identity", "")) == identity \
			and (resumed or wave > 1)
	if reuse:
		_meme_run_salt = int(stored.get("salt", 0))
		_meme_salt_identity = identity
		ModLoaderLog.info("meme 随机种子沿用 = %d（%s）wave=%d 接着打=%s 重试=%d" % [
			_meme_run_salt, identity, wave, str(resumed), retries], MEME_LOG_NAME)
		return

	# 全新一局：摇一个新的盐值并存下来
	_meme_run_salt = int(abs(randi() * 2654435761 + 12345)) % 2147483647
	if _meme_run_salt == 0:
		_meme_run_salt = 1
	_meme_salt_identity = identity

	var out := File.new()
	if out.open(MEME_SALT_PATH, File.WRITE) == OK:
		out.store_string(to_json({"salt": _meme_run_salt, "identity": identity, "wave": RunData.current_wave}))
		out.close()
	ModLoaderLog.info("本局 meme 随机种子 = %d（%s）wave=%d 接着打=%s 重试=%d" % [
		_meme_run_salt, identity, wave, str(resumed), retries], MEME_LOG_NAME)


# 由「本局盐值 + 波数 + 用途」派生的确定性随机数：
# 同一波重打（SL）结果完全一致，不同用途互不相关。
func _bromeme_wave_rng(purpose: String, player_index: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Keys.generate_hash("%s|%d|%d|%d" % [purpose, _meme_run_salt, RunData.current_wave, player_index]))
	return rng


# 「反抗孙笑川」：持有这件道具 → 本波必定入侵，而且 boss 指定孙笑川
const BROMEME_SUNXIAOCHUAN_PATH: String = "res://mods-unpacked/General-bromeme/meme/content/enemies/sunxiaochuan/sunxiaochuan.tscn"
const BROMEME_RESIST_SXC_ID: String = "item_bromeme_fkcs_87"
# 丁真：第 10 波必定王源入侵
const BROMEME_WANGYUAN_PATH: String = "res://mods-unpacked/General-bromeme/meme/content/enemies/wangyuan/wangyuan.tscn"
const BROMEME_DZ_ID: String = "character_bromeme_dz_220"
const BROMEME_DZ_WAVE: int = 10


const BROMEME_ITEM_PREFIX_FOR_UNLOCK: String = "item_bromeme_"


# 把本 mod 里 unlocked_by_default 的商店货重新塞进解锁表（存档里可能还是旧 id），
# 并重建一次解锁池，保证商店能刷出这些道具。
func _bromeme_ensure_unlocked_items() -> void:
	var added: int = 0
	for item in ItemService.items:
		if item == null or not is_instance_valid(item):
			continue
		if not String(item.my_id).begins_with(BROMEME_ITEM_PREFIX_FOR_UNLOCK):
			continue
		if not item.unlocked_by_default:
			continue
		# 关键：必须同时要求 can_be_looted。
		# json 里标了 "locked": true 的道具（8 个 meme 面板专属道具）是
		# unlocked_by_default = false + can_be_looted = false，本来就被上面那条挡掉了；
		# 但早期版本给它们写的是"unlocked_by_default = true + can_be_looted = false"
		# （图鉴已解锁但不进商店），只判 unlocked_by_default 会把它们又塞回解锁表。
		if not item.can_be_looted:
			continue
		if ProgressData.items_unlocked.has(item.my_id_hash):
			continue
		ProgressData.items_unlocked.append(item.my_id_hash)
		added += 1

	if added > 0:
		ItemService.init_unlocked_pool()
		ModLoaderLog.info("补回 %d 件本 mod 商店货的解锁状态" % added, MEME_LOG_NAME)


# 卡道具的贴图修复：读档发生的时机比 mod 内容装载早，所以读档时按 my_id 反查来源
# 常常失败。进入商店前内容一定装完了，这时统一把没图的卡道具修一遍。
func _bromeme_repair_card_icons() -> void:
	if not ItemService.has_method("bromeme_pick_icon_for_source"):
		return
	var fixed: int = 0
	for item in ItemService.items:
		if item == null or not is_instance_valid(item):
			continue
		var my_id: String = String(item.my_id)
		if not my_id.begins_with("item_bromeme_pick_"):
			continue
		if item.icon != null:
			continue
		var tex = ItemService.call("bromeme_pick_icon_for_source", my_id)
		if tex == null:
			continue
		# 重新赋一次（同一引用在某些 UI 上不会刷新，先清空再设）
		item.icon = null
		item.icon = tex
		fixed += 1
	if fixed > 0:
		ModLoaderLog.info("卡道具贴图修复 %d 件（进商店时补图）" % fixed, MEME_LOG_NAME)


func _bromeme_is_character(player_index: int, id_part: String) -> bool:	
	var players = RunData.players_data
	if players == null or player_index >= players.size():
		return false
	var character = players[player_index].get("character")
	if character == null:
		return false
	return String(character.my_id).find(id_part) >= 0


func _bromeme_dz_wangyuan(player_index: int) -> bool:
	return RunData.current_wave == BROMEME_DZ_WAVE and _bromeme_is_character(player_index, BROMEME_DZ_ID)


func _bromeme_owns_resist_sxc(player_index: int) -> bool:
	for item in RunData.get_player_items(player_index):
		if item == null or not is_instance_valid(item):
			continue
		if String(item.my_id).find(BROMEME_RESIST_SXC_ID) >= 0:
			return true
	return false


# =============================================================================
#  挑战者：每击杀一个精英或首领 → 生命再生 +5、伤害 +5%
#  （直接加进属性里，永久生效，存档也带着；不需要额外的计数器）
# =============================================================================
const BROMEME_CHALLENGER_ID: String = "character_bromeme_challenger_777"
const BROMEME_CHALLENGER_HP_REGEN: int = 5      # 每次击杀 +5 生命再生
const BROMEME_CHALLENGER_DAMAGE: int = 5        # 每次击杀 +5% 伤害（stat_percent_damage）


func _on_enemy_died(enemy, args) -> void:
	._on_enemy_died(enemy, args)
	_bromeme_challenger_kill(enemy)


func _bromeme_challenger_kill(enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var player_index: int = 0
	if not _bromeme_is_challenger(player_index):
		return

	# 动态取属性（字段名不对时得到 null，不会变成致命解析错误）
	var data = enemy.get("enemy_data")
	if data == null:
		return
	var is_boss: bool = bool(data.get("is_boss"))
	var is_elite: bool = bool(data.get("is_elite"))
	if not is_boss and not is_elite:
		return

	RunData.add_stat(Keys.generate_hash("stat_hp_regeneration"), BROMEME_CHALLENGER_HP_REGEN, player_index)
	RunData.add_stat(Keys.generate_hash("stat_percent_damage"), BROMEME_CHALLENGER_DAMAGE, player_index)

	ModLoaderLog.info("挑战者：精英/首领击杀 → 生命再生 +%d、伤害 +%d%%" % [
			BROMEME_CHALLENGER_HP_REGEN, BROMEME_CHALLENGER_DAMAGE], MEME_LOG_NAME)

func _bromeme_is_challenger(player_index: int) -> bool:
	var players = RunData.players_data
	if players == null or player_index >= players.size():
		return false
	var character = players[player_index].get("character")
	if character == null:
		return false
	return String(character.my_id).find(BROMEME_CHALLENGER_ID) >= 0

func _bromeme_check_meme_invasion() -> void:
	if _cleaning_up:
		return
	# 注意：这里**不能**再写 `if RunData.current_wave > RunData.nb_of_waves: return`。
	# 原版那一句是给"消耗品掉落"用的（无尽模式掉率要衰减），但 meme 入侵不是原版机制，
	# 20 波之后（nb_of_waves = 20 的无尽局）本来也应该继续入侵 —— 之前的写法导致
	# "20 波之后再也不刷新 meme 入侵"，已按用户反馈去掉。

	_bromeme_ensure_salt()

	var triggered: Array = []
	var info: Array = []
	for player_index in RunData.get_player_count():
		var value: int = bromeme_meme_value(player_index)
		var forced: bool = bromeme_forces_invasion(player_index) or _bromeme_owns_resist_sxc(player_index) or _bromeme_dz_wangyuan(player_index)
		if value <= 0 and not forced:
			continue
		var chance: float = 1.0 if forced else bromeme_meme_invasion_chance(value)
		# 用固定随机数（不是全局 randi）：同一波重打结果不变
		var roll: float = _bromeme_wave_rng("meme_invade", player_index).randf()
		info.append("P%d meme=%d 概率=%.1f%% 掷=%.3f%s" % [
			player_index + 1, value, chance * 100.0, roll, "（必定）" if forced else ""])
		if forced or roll < chance:
			triggered.append(player_index)

	var info_text: String = ""
	for entry in info:
		if info_text != "":
			info_text += ", "
		info_text += str(entry)

	if triggered.empty():
		if info_text != "":
			ModLoaderLog.info("meme 入侵未触发（%s）" % info_text, MEME_LOG_NAME)
		return

	ModLoaderLog.info("meme 入侵！%s" % info_text, MEME_LOG_NAME)
	_bromeme_play_meme_fx()
	for player_index in triggered:
		_bromeme_spawn_meme_boss(player_index)


func _bromeme_play_meme_fx(fx_text: String = "") -> void:
	var fx_script = load(MEME_FX_SCRIPT_PATH)
	if fx_script == null:
		ModLoaderLog.error("meme 入侵特效脚本加载失败：%s" % MEME_FX_SCRIPT_PATH, MEME_LOG_NAME)
		return
	var fx = fx_script.new()
	# 复用同一套欢乐特效，只换字（比如「入侵奖励」）
	if not fx_text.empty() and "TEXT" in fx:
		fx.TEXT = fx_text
	var ui = $UI
	ui.add_child(fx)
	# 插到 PauseMenu 之前：特效盖住 HUD，但被暂停菜单盖住
	var pause_menu = ui.get_node_or_null("PauseMenu")
	if pause_menu != null:
		ui.move_child(fx, pause_menu.get_index())
	if fx.has_method("setup"):
		var font: Font = null
		if _current_wave_label != null:
			font = _current_wave_label.get_font("font")
		fx.setup(font, get_viewport().get_visible_rect().size)
	if fx.has_method("play"):
		fx.play(self)


func _bromeme_spawn_meme_boss(player_index: int) -> void:
	if MEME_BOSS_POOL.empty():
		return
	# 抽哪个 boss 也走固定随机数：同一波读档重打还是同一个 boss
	var pick_rng: RandomNumberGenerator = _bromeme_wave_rng("meme_boss", player_index)
	var path: String = str(MEME_BOSS_POOL[pick_rng.randi() % MEME_BOSS_POOL.size()])
	var scene = load(path)
	if scene == null:
		ModLoaderLog.error("找不到 memeboss 场景：%s" % path, MEME_LOG_NAME)
		return
	if player_index >= _players.size() or _players[player_index] == null:
		return

	var base: Vector2 = _players[player_index].global_position
	var angle: float = randf() * TAU
	var pos: Vector2 = base + Vector2(cos(angle), sin(angle)) * MEME_BOSS_SPAWN_DISTANCE

	if _bromeme_owns_resist_sxc(player_index):
		path = BROMEME_SUNXIAOCHUAN_PATH
		ModLoaderLog.info("反抗孙笑川：本波 boss 指定为孙笑川", MEME_LOG_NAME)
	elif _bromeme_dz_wangyuan(player_index):
		path = BROMEME_WANGYUAN_PATH
		ModLoaderLog.info("丁真：第 %d 波 boss 指定为王源" % BROMEME_DZ_WAVE, MEME_LOG_NAME)
	ModLoaderLog.info("meme 入侵 boss：%s" % path.get_file(), MEME_LOG_NAME)
	_entity_spawner.spawn_entity_birth(EntityType.ENEMY, scene, pos)


# memeboss 死亡时调用。以前是掉一个红色宝箱，现在改成记一面旗：
# 本波结束（切商店之前）触发一次 meme 物品选择。
var _bromeme_pending_picks: int = 0


func bromeme_spawn_red_box(unit: Unit) -> void:
	_bromeme_pending_picks += 1
	ModLoaderLog.info("memeboss 击杀：本波结束触发 1 次 meme 物品选择（待触发 %d 次）" % _bromeme_pending_picks, MEME_LOG_NAME)


# =============================================================================
#  波次结束的「本 mod 物品 4 选 1」
#
#  做法照 Fantasy / Hextech：自己一套模态面板，不动原版的升级面板
#  （原版那个面板卡皮巴拉、Fantasy 等一堆 mod 都在用，我们的 level 会被它们的
#   get_upgrades 分支顶掉，所以干脆不挤）。
#
#  时机：切到商店场景之前（_change_scene），弹面板 → 等玩家选 / 不选 →
#  选中就把卡里的效果 apply 到玩家身上（道具不进背包）→ 再切场景。
# =============================================================================

const BROMEME_PICK_UI_PATH: String = "res://mods-unpacked/General-bromeme/extensions/ui/bromeme_pick_ui.gd"
const BROMEME_EXCLUSIVE_PREFIX: String = "bromeme_pick|exclusive|"
const BROMEME_AXOLOTL_ID: String = "item_axolotl"
const BROMEME_CORE_ID: String = "item_bromeme_meme_core"

# meme值属性 key（stat_meme.tres 里 stat_name 就是这个）
const BROMEME_MEME_STAT_KEY: String = "stat_meme"
# 出售meme 的额外奖励
const BROMEME_SELL_MEME_HARVEST: int = 25
const BROMEME_SELL_MEME_VALUE: int = 35
# 出售meme：额外每条主要属性 +5
const BROMEME_SELL_MEME_ALL_STATS: int = 5


# 取道具显示名：原版 / 其它 mod 的 name 是翻译键，必须走 item_service 里那个 helper
func bromeme_ui_name(item) -> String:
	if item == null or not is_instance_valid(item):
		return ""
	if ItemService.has_method("bromeme_display_name"):
		return String(ItemService.call("bromeme_display_name", item))
	return String(item.name)


func _change_scene(path: String) -> void:
	# 进商店之前补一次本 mod 商店货的解锁状态：
	# ProgressData 是从存档读进来的，而存档里可能还是改 id 之前的旧记录
	# （item_brolab_*），商店池就会把我们 24 件 unlocked_by_default 的道具全漏掉。
	if path == RunData.get_shop_scene_path():
		_bromeme_ensure_unlocked_items()
		# 卡道具的贴图不在存档里，读档那一刻内容可能还没装载完 ——
		# 进商店前统一强制修一次（这时一定装完了），修好后重设 icon 让 UI 重新取图。
		_bromeme_repair_card_icons()

	# 不再是每波强制出：只有 memeboss 被打掉（有待触发次数）时才弹
	if path == RunData.get_shop_scene_path() and _bromeme_pending_picks > 0:
		_bromeme_pending_picks = 0
		var pending = _bromeme_show_pick_panel()
		if pending is GDScriptFunctionState:
			yield(pending, "completed")
	._change_scene(path)


# 每个玩家轮流弹一次（单人就是一次；多人是依次弹，各自选各自的）
func _bromeme_show_pick_panel():
	var ui_script = load(BROMEME_PICK_UI_PATH)
	if ui_script == null:
		ModLoaderLog.error("4 选 1 面板脚本读不到：" + BROMEME_PICK_UI_PATH, MEME_LOG_NAME)
		return null

	for player_index in RunData.get_player_count():
		var cards = ItemService.call("bromeme_build_pick_cards", player_index)
		if cards == null or cards.empty():
			continue

		# 弹面板之前先来一发「入侵奖励」欢乐特效（和 meme 入侵同一套，文案走翻译）
		_bromeme_play_meme_fx(tr("入侵奖励"))

		var panel = ui_script.new()
		$UI.add_child(panel)
		# 同级 Control 按树顺序绘制：插到 PauseMenu 之前，
		# 这样面板盖住 HUD，但暂停菜单盖在面板上面
		var pause_menu = $UI.get_node_or_null("PauseMenu")
		if pause_menu != null:
			$UI.move_child(panel, pause_menu.get_index())
		panel.setup(cards, player_index)

		var chosen = yield(panel, "picked")
		if is_instance_valid(panel):
			panel.queue_free()

		_bromeme_apply_pick(chosen, player_index)


# 选中的卡：做成一件道具进背包（图标带减淡的 logo）；专属道具再跑一遍自己的行为
func _bromeme_apply_pick(chosen, player_index: int) -> void:
	if chosen == null:
		ModLoaderLog.info("4 选 1：不选", MEME_LOG_NAME)
		return

	var card_id: String = String(chosen.my_id)
	ModLoaderLog.info("4 选 1 选择：%s" % String(chosen.name), MEME_LOG_NAME)

	var item = ItemService.call("bromeme_make_pick_item", chosen, player_index)
	if item == null:
		RunData.apply_item_effects(chosen, player_index)
		return

	if card_id.begins_with(BROMEME_EXCLUSIVE_PREFIX):
		var item_id: String = card_id.substr(BROMEME_EXCLUSIVE_PREFIX.length())

		# 原版蝾螈：给真道具，让它自己的效果生效
		if item_id == BROMEME_AXOLOTL_ID:
			var real_item = ItemService.get_item_from_id(Keys.generate_hash(item_id))
			if real_item != null:
				RunData.add_item(real_item, player_index, true)
			return

		# meme核心：除了「买东西 +1 meme值」，再送两条从任意物品抽的随机效果
		if item_id == BROMEME_CORE_ID:
			for i in 2:
				var buff = ItemService.call("bromeme_make_random_buff")
				if buff != null and is_instance_valid(buff):
					item.effects.append(buff)
					ModLoaderLog.info("meme核心：额外随机效果 %s +%d" % [String(buff.key), int(buff.value)], MEME_LOG_NAME)

		_bromeme_run_exclusive_behaviour(item_id, player_index)

		# 安全闸：专属道具的 max_nb 是持有上限（直升机/苍/赫/混沌那批都是 1）。
		# 池子已按 max_nb 过滤，这里再挡一次 —— 任何路径都不可能超量发放。
		var real = ItemService.get_item_from_id(Keys.generate_hash(item_id))
		if real != null and is_instance_valid(real) and real.max_nb > 0 \
				and RunData.get_nb_item(real.my_id_hash, player_index) >= real.max_nb:
			ModLoaderLog.info("4 选 1：%s 已达持有上限 %d，跳过发放" % [
					item_id, real.max_nb], MEME_LOG_NAME)
			return

	RunData.add_item(item, player_index, true)


func _bromeme_run_exclusive_behaviour(item_id: String, player_index: int) -> void:
	match item_id:
		"item_bromeme_meme_chaos":
			_bromeme_chaos_meme(player_index)
		"item_bromeme_meme_random":
			_bromeme_random_meme(player_index)
		"item_bromeme_meme_sell":
			_bromeme_sell_meme(player_index)
		"item_bromeme_meme_entropy":
			_bromeme_entropy_meme(player_index)
		"item_bromeme_meme_gambler":
			_bromeme_gambler_meme(player_index)
		"item_bromeme_meme_quantum":
			_bromeme_quantum_meme(player_index)
		"item_bromeme_meme_sacrifice":
			_bromeme_sacrifice_meme(player_index)
		_:
			pass


# 熵增meme：每条主属性独立随机 ×0~3
func _bromeme_entropy_meme(player_index: int) -> void:
	for key in Utils.get_primary_stat_keys():
		var stat_key: int = int(key)
		if _bromeme_stat_skipped(stat_key):
			continue
		var raw: float = RunData.get_player_effect(stat_key, player_index)
		if raw == 0:
			continue
		var target: int = int(round(raw * rand_range(0.0, 3.0)))
		RunData.add_stat(stat_key, int(round(float(target) - raw)), player_index)
	Utils.reset_stat_cache(player_index)
	ModLoaderLog.info("熵增meme：每条主属性随机 ×0~3", MEME_LOG_NAME)


# 赌徒meme：50% 材料翻倍，50% 材料清零
# 注意：游戏的货币变量就是 player_data.gold，但中文界面的叫法是「材料」（成就"持有3000材料"
# 读的正是 get_player_gold()），所以这里统一用"材料"这个说法。
# 材料为 0 时对 0 翻倍/清零都没有变化，会明确记一条日志（以前是静默 return，看着像"没生效"）。
func _bromeme_gambler_meme(player_index: int) -> void:
	var materials: int = RunData.get_player_gold(player_index)
	if materials <= 0:
		ModLoaderLog.info("赌徒meme：当前材料为 0，翻倍/清零都没有变化", MEME_LOG_NAME)
		return
	if Utils.get_chance_success(0.5):
		RunData.add_gold(materials, player_index)
		ModLoaderLog.info("赌徒meme：材料翻倍 +%d（%d → %d）" % [
				materials, materials, materials * 2], MEME_LOG_NAME)
	else:
		RunData.remove_gold(materials, player_index)
		ModLoaderLog.info("赌徒meme：材料清零 -%d（%d → 0）" % [
				materials, materials], MEME_LOG_NAME)


# 量子meme：把所有道具换成「同稀有度」的另一件道具，再额外获得 1~8 件道具，额外 +25 meme值
func _bromeme_quantum_meme(player_index: int) -> void:
	var shop_items: Array = ItemService.call("bromeme_shop_items")
	if shop_items.empty():
		return

	var owned: Array = RunData.get_player_items(player_index).duplicate()
	var swapped: int = 0
	var skipped: int = 0
	# 同 tier 的候选表：tier -> 候选数组（只算一次，避免每件道具都重扫全池）
	var by_tier: Dictionary = {}
	for item in shop_items:
		if item == null or not is_instance_valid(item):
			continue
		var t: int = int(item.tier)
		if not by_tier.has(t):
			by_tier[t] = []
		by_tier[t].append(item)

	for victim in owned:
		if victim == null or not is_instance_valid(victim):
			continue
		# 角色不参与替换（原版把角色也放进 items 里，量子meme 不该把人换掉）
		if String(victim.my_id).begins_with("character_"):
			skipped += 1
			continue
		var candidates: Array = by_tier.get(int(victim.tier), [])
		# 同稀有度的"另一件"：排除它自己；同 tier 只有它一件时跳过（不动，避免凭空消失）
		var eligible: Array = []
		for candidate in candidates:
			if candidate.my_id_hash != victim.my_id_hash:
				eligible.append(candidate)
		if eligible.empty():
			skipped += 1
			continue
		var replacement = eligible[randi() % eligible.size()]
		RunData.remove_item(victim, player_index)
		RunData.add_item(replacement, player_index, true)
		swapped += 1

	# 额外获得 1~8 件道具（同样不会给角色）
	var extra_count: int = 1 + (randi() % 8)
	var extra_names: Array = []
	for i in extra_count:
		var pick = shop_items[randi() % shop_items.size()]
		if String(pick.my_id).begins_with("character_"):
			continue
		RunData.add_item(pick, player_index, true)
		extra_names.append(bromeme_ui_name(pick))

	# 额外 +25 meme值
	RunData.add_stat(Keys.generate_hash(BROMEME_MEME_STAT_KEY), 25, player_index)
	Utils.reset_stat_cache(player_index)

	ModLoaderLog.info("量子meme：%d 件同稀有度替换（%d 件同档无替身跳过），额外 %d 件道具（%s），meme值 +25" % [
			swapped, skipped, extra_count, PoolStringArray(extra_names).join("、")], MEME_LOG_NAME)


# 献祭meme：随机两条主属性清零，其余每条 +5~+25
func _bromeme_sacrifice_meme(player_index: int) -> void:
	var owned: Array = []
	for key in Utils.get_primary_stat_keys():
		var stat_key: int = int(key)
		if _bromeme_stat_skipped(stat_key):
			continue
		if RunData.get_player_effect(stat_key, player_index) > 0:
			owned.append(stat_key)
	if owned.size() < 2:
		return

	owned.shuffle()
	var victims: Array = [owned[0], owned[1]]
	var victim_names: Array = []
	for stat_key in victims:
		var raw: float = RunData.get_player_effect(stat_key, player_index)
		RunData.add_stat(stat_key, -int(round(raw)), player_index)
		victim_names.append(tr(String(Keys.hash_to_string.get(stat_key, "")).to_upper()))

	for stat_key in owned:
		if victims.has(stat_key):
			continue
		RunData.add_stat(stat_key, int(round(rand_range(5.0, 25.0))), player_index)
	Utils.reset_stat_cache(player_index)
	ModLoaderLog.info("献祭meme：%s 清零，其余主属性 +5~+25" % PoolStringArray(victim_names).join("、"), MEME_LOG_NAME)


# 击杀数这类计数器不参与任何属性变换（转职 / 改造 / 混沌 / 熵增 / 献祭）
func _bromeme_stat_skipped(stat_key: int) -> bool:
	if not ItemService.has_method("bromeme_stat_excluded"):
		return false
	return bool(ItemService.call("bromeme_stat_excluded", stat_key))


# 混沌meme：所有主属性的数值随机洗牌，然后每项 +5
func _bromeme_chaos_meme(player_index: int) -> void:
	var keys: Array = Utils.get_primary_stat_keys()
	var entries: Array = []
	var values: Array = []
	for key in keys:
		var stat_key: int = int(key)
		if _bromeme_stat_skipped(stat_key):
			continue
		var raw: float = RunData.get_player_effect(stat_key, player_index)
		entries.append([stat_key, raw])
		values.append(raw)
	values.shuffle()

	for i in entries.size():
		var stat_key: int = entries[i][0]
		var old_value: float = entries[i][1]
		var new_value: float = float(values[i]) + 5.0
		RunData.add_stat(stat_key, int(round(new_value - old_value)), player_index)
	Utils.reset_stat_cache(player_index)
	ModLoaderLog.info("混沌meme：主属性随机洗牌后每项 +5", MEME_LOG_NAME)


# 随机meme：再随机给两个 meme 道具（组合 / 改造属性）
func _bromeme_random_meme(player_index: int) -> void:
	for i in 2:
		var cards = ItemService.call("bromeme_build_pick_cards", player_index)
		if cards == null or cards.empty():
			return
		var card = cards[randi() % cards.size()]
		var item = ItemService.call("bromeme_make_pick_item", card, player_index)
		if item != null:
			RunData.add_item(item, player_index, true)
	ModLoaderLog.info("随机meme：额外获得两个 meme 道具", MEME_LOG_NAME)


# 出售meme：按 100% 价格回收所有道具，额外 +25 收获、+35 meme值
# 注意：不出售「角色」（角色不在背包 items 里，这里再兜一层），
# 也不出售价值 <= 0 的道具 —— 卖掉它们一分钱都拿不到，等于白扔，保留在背包里。
func _bromeme_sell_meme(player_index: int) -> void:
	var owned: Array = RunData.get_player_items(player_index).duplicate()
	var total: int = 0
	var count: int = 0
	var kept_count: int = 0
	var kept_names: Array = []
	for item in owned:
		if item == null or not is_instance_valid(item):
			continue
		if String(item.my_id).begins_with("character_"):
			kept_count += 1
			continue
		if int(item.value) <= 0:
			kept_count += 1
			kept_names.append(bromeme_ui_name(item))
			continue
		total += int(item.value)
		count += 1
		RunData.remove_item(item, player_index)
	if total > 0:
		RunData.add_gold(total, player_index)

	RunData.add_stat(Keys.stat_harvesting_hash, BROMEME_SELL_MEME_HARVEST, player_index)
	RunData.add_stat(Keys.generate_hash(BROMEME_MEME_STAT_KEY), BROMEME_SELL_MEME_VALUE, player_index)

	# 额外全主要属性 +5（走 Utils.get_primary_stat_keys()，和熵增/献祭同一个范围；
	# 击杀数这类计数器由 _bromeme_stat_skipped() 排除，不参与）
	var stat_count: int = 0
	for key in Utils.get_primary_stat_keys():
		var stat_key: int = int(key)
		if _bromeme_stat_skipped(stat_key):
			continue
		RunData.add_stat(stat_key, BROMEME_SELL_MEME_ALL_STATS, player_index)
		stat_count += 1

	Utils.reset_stat_cache(player_index)

	ModLoaderLog.info("出售meme：回收 %d 件道具，共 %d 金；保留价值为0的 %d 件（%s）；额外 +%d 收获、+%d meme值、%d 条主要属性各 +%d" % [
			count, total, kept_count, PoolStringArray(kept_names).join("、"),
			BROMEME_SELL_MEME_HARVEST, BROMEME_SELL_MEME_VALUE,
			stat_count, BROMEME_SELL_MEME_ALL_STATS], MEME_LOG_NAME)
