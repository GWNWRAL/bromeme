extends Node

const PROBE: String = "MemeProbe"
const BOSS_DIR: String = "res://mods-unpacked/General-bromeme/meme/content/enemies/"
const EXT: String = "res://mods-unpacked/General-bromeme/brolab_compat/extensions/main.gd"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	yield(get_tree().create_timer(10.0), "timeout")
	ModLoaderLog.info("=== MemeProbe start ===", PROBE)
	_test_death_scale()
	yield(_test_reset_state(), "completed")
	_test_run_data_extension()
	_test_codex()
	_test_damage()
	_test_meme_event()
	ModLoaderLog.info("=== MemeProbe end ===", PROBE)


# 6) meme 事件面板：能不能实例化、背景帧读不读得到、选项按钮建没建出来
func _test_meme_event() -> void:
	var script = load("res://mods-unpacked/General-bromeme/meme/meme_event.gd")
	if script == null:
		ModLoaderLog.error("meme 事件面板脚本加载失败", PROBE)
		return
	var panel = script.new()
	add_child(panel)
	panel.play("测试：闹吃 vs 古振兴", ["帮助闹吃", "保持中立", "帮助古振兴", "全部打倒"], null, null, Vector2(1280, 720))
	yield(get_tree(), "idle_frame")
	ModLoaderLog.info("meme 事件面板: 背景帧=%d 选项按钮=%d layer=%d 可见=%s" % [
		panel._frames.size(), panel._buttons.size(), panel.layer, str(panel._root != null)], PROBE)
	panel.queue_free()


# 5) 弹幕伤害倍率：Van -20%，魂5 -10%，魂5 的弩箭 +10%
func _test_damage() -> void:
	var van = _make_boss("van/van")
	if van != null:
		var map: Dictionary = (van.get_script() as GDScript).get_script_constant_map()
		var saved_damage: int = _force_damage(van, 10)
		van.set("_bullets", van.get_node_or_null("VanBullets"))
		van._prepare_bullets()
		var got: int = 0
		if van.get("_bullets") != null:
			got = int(van._bullets.projectile_damage)
		ModLoaderLog.info("Van 伤害: 基础=10 倍率=%s -> 弹幕=%d（应 8）" % [
			str(map.get("BULLET_DAMAGE_MULT", -1.0)), got], PROBE)
		_restore_damage(van, saved_damage)
		van.free()

	var hun5 = _make_boss("hun5/hun5")
	if hun5 != null:
		var saved2: int = _force_damage(hun5, 10)
		var map2: Dictionary = (hun5.get_script() as GDScript).get_script_constant_map()
		ModLoaderLog.info("魂5 伤害: 基础=10 倍率=%s 箭倍率=%s -> 弹幕=%d（应 9）弩箭=%d（应 11）" % [
			str(map2.get("BULLET_DAMAGE_MULT", -1.0)), str(map2.get("BOLT_DAMAGE_MULT", -1.0)),
			hun5._projectile_damage(), hun5._projectile_damage(hun5.BOLT_DAMAGE_MULT)], PROBE)
		_restore_damage(hun5, saved2)
		hun5.free()


# 探针里没进场，current_stats 是空的（damage=0）；直接改它自己那份实例数据，
# 不动 stats 资源本身（改完还要还回去）
func _force_damage(node, value: int) -> int:
	if node.current_stats == null:
		node.current_stats = node.stats.duplicate(true)
	var saved: int = int(node.current_stats.damage)
	node.current_stats.damage = value
	return saved


func _restore_damage(node, saved: int) -> void:
	if node.current_stats != null:
		node.current_stats.damage = saved


# 4) 图鉴条目：ItemService.entities 里有没有我们的 memeboss，名字是不是可读文本（不是 key）
func _test_codex() -> void:
	var parts: PoolStringArray = []
	for entity in ItemService.entities:
		if entity == null or not String(entity.my_id).begins_with("meme_"):
			continue
		var desc: String = String(entity.behaviour_description)
		if desc.length() > 10:
			desc = desc.substr(0, 10) + "…"
		parts.append("%s 名字=%s 描述=%s 图标=%s 血量=%s 精英=%s" % [
			entity.my_id, String(entity.name), desc, str(entity.icon != null),
			str(entity.stats.health if entity.stats != null else -1), str(entity.is_elite)])
	if parts.empty():
		ModLoaderLog.error("图鉴：entities 里找不到任何 meme_ 条目", PROBE)
	else:
		ModLoaderLog.info("图鉴条目 %d 个: %s" % [parts.size(), parts.join(" | ")], PROBE)


# 1) 死亡缩放轨道补丁：death / RESET 的 Sprite:scale 首帧是否换成自己的体型，
#    以及原版共享动画资源是否没被污染
func _test_death_scale() -> void:
	for rel in ["sunxiaochuan/sunxiaochuan", "wangyuan/wangyuan", "van/van", "hun5/hun5", "panren/panren"]:
		var node = _make_boss(rel)
		if node == null:
			continue
		var player = node.get_node_or_null("AnimationPlayer")
		var before := {}
		for anim_name in ["death", "RESET"]:
			var src = player.get_animation(anim_name)
			var idx: int = _scale_track(src)
			before[anim_name] = [src, src.track_get_key_value(idx, 0) if idx >= 0 else "no-track"]

		var map: Dictionary = (node.get_script() as GDScript).get_script_constant_map()
		node._patch_scale_animations()

		var parts: PoolStringArray = []
		for anim_name in ["death", "RESET"]:
			var now = player.get_animation(anim_name)
			var idx: int = _scale_track(now)
			parts.append("%s: %s -> %s 仍共享=%s" % [anim_name, str(before[anim_name][1]),
				str(now.track_get_key_value(idx, 0) if idx >= 0 else "no-track"),
				str(now == before[anim_name][0])])
		ModLoaderLog.info("%s SPRITE_SCALE=%s patched=%s | %s" % [
			rel, str(map.get("SPRITE_SCALE", -1.0)), str(node._scale_patched), parts.join(" | ")], PROBE)
		if rel.begins_with("van"):
			ModLoaderLog.info("Van COOLDOWN_FAN_COUNT=%s" % str(map.get("COOLDOWN_FAN_COUNT", -1)), PROBE)
		node.free()


# 2) 对象池复用复位（不走 respawn()，直接调 _reset_meme_state，避免没进场时的空 Timer）
func _test_reset_state() -> void:
	for rel in ["sunxiaochuan/sunxiaochuan", "wangyuan/wangyuan", "van/van", "hun5/hun5", "panren/panren"]:
		var node = _make_boss(rel)
		if node == null:
			continue
		# 探针里没进场，onready 变量是 null；手动补 _sprite（复位里 tint/体型那两行要用）。
		# _charge_behavior / _bullets 不能补：那些节点的 Timer 在 _ready() 里建，
		# 没进场就是 null，调 reset() 会直接把引擎搞崩（探针限制，不是 mod 的问题）。
		if node.get("_sprite") == null:
			node.set("_sprite", node.get_node_or_null("Animation/Sprite"))

		node._phase2 = true
		var sprite = node.get("_sprite")
		var dirty: PoolStringArray = []
		if sprite != null:
			sprite.modulate = Color(1.0, 0.5, 0.5, 1.0)
			dirty.append("tint")

		var weapon = null
		if node.get("_weapon_sprite") != null or node.has_method("_end_weapon"):
			var sp := Sprite.new()
			node.add_child(sp)
			node._weapon_sprite = sp
			weapon = sp
			dirty.append("weapon")

		var line = null
		if node.has_method("_show_line"):
			node._show_line("测试残留")
			line = node._line_label
			dirty.append("line")

		if node.get("_smokes") != null:
			if node._smokes.empty() and node.has_method("_spawn_smoke"):
				node._spawn_smoke()
			for smoke in node._smokes:
				if is_instance_valid(smoke):
					smoke.visible = false
					smoke._queue.append([0.0, 0.1, 1.0])
			if not node._smokes.empty():
				dirty.append("smoke")

		node._reset_meme_state()
		yield(get_tree(), "idle_frame")

		var weapon_ok: String = "n/a"
		if weapon != null:
			weapon_ok = str(not is_instance_valid(weapon))
		var line_ok: String = "n/a"
		if line != null:
			line_ok = str(not is_instance_valid(line))
		var smoke_ok: String = "n/a"
		var queued: int = 0
		if node.get("_smokes") != null and not node._smokes.empty():
			var visible_all := true
			for smoke in node._smokes:
				if is_instance_valid(smoke):
					if not smoke.visible:
						visible_all = false
					queued += smoke._queue.size()
			smoke_ok = str(visible_all)

		ModLoaderLog.info("%s 复位: phase2=%s tint=%s 武器释放=%s 台词释放=%s 烟可见=%s 队列=%d | 脏=[%s]" % [
			rel, str(node._phase2), str(sprite.modulate if sprite != null else "-"),
			weapon_ok, line_ok, smoke_ok, queued, dirty.join(", ")], PROBE)
		node.free()


# 3) RunData 扩展是否装在这条脚本链的最上层（盐值靠它区分"接着打/全新一局"）
func _test_run_data_extension() -> void:
	var script = RunData.get_script()
	var path: String = "<no script>"
	if script != null:
		path = script.resource_path
	var has_flag: bool = RunData.get("bromeme_run_resumed") != null
	ModLoaderLog.info("RunData 扩展: script=%s flag=%s reset=%s reset_wave=%s resume=%s 当前值=%s" % [
		path, str(has_flag), str(RunData.has_method("reset")),
		str(RunData.has_method("reset_to_start_wave_state")),
		str(RunData.has_method("resume_from_state")), str(RunData.get("bromeme_run_resumed"))], PROBE)

	# hun5 贴边避让 / panren 瞬移夹边界都依赖原版 Entity 的 _min_pos/_max_pos
	var probe_boss = _make_boss("hun5/hun5")
	if probe_boss != null:
		ModLoaderLog.info("地图边界变量: _min_pos=%s _max_pos=%s（非 Null 即存在）" % [
			str(probe_boss.get("_min_pos")), str(probe_boss.get("_max_pos"))], PROBE)
		probe_boss.free()


func _make_boss(rel: String):
	var scene = load(BOSS_DIR + rel + ".tscn")
	if scene == null:
		ModLoaderLog.error("场景 load 失败: %s" % rel, PROBE)
		return null
	var node = scene.instance()
	if node == null:
		ModLoaderLog.error("instance 失败: %s" % rel, PROBE)
	return node


func _scale_track(anim: Animation) -> int:
	if anim == null:
		return -1
	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_VALUE:
			continue
		var path: String = str(anim.track_get_path(i))
		if path.find("Sprite") >= 0 and path.ends_with(":scale"):
			return i
	return -1
