extends "res://singletons/utils.gd"

# =============================================================================
#  属性小图标的 BBCode 渲染兜底
#
#  现象（用户反馈）：苍/赫 的乘区里，**meme 值那一项的图标不显示**。
#
#  原因：原版 Utils.get_scaling_stat_icon_text() 是这么拼的 ——
#      small_icon = ItemService.get_stat_small_icon(stat_hsh)
#      return "...[img=%sx%s]%s[/img]" % [w, w, small_icon.resource_path]
#    它取的是 `small_icon.resource_path`。而本 mod 的 meme 属性图
#    （meme/stat_meme_icon.png）是**运行时**用 png 字节解码出来的 ImageTexture，
#    `resource_path` 是空串 → BBCode 里就成了 `[img=15x15][/img]` → 图标不显示。
#    （同一个坑之前也坑过角色贴图与道具图标。）
#
#  修法：路径为空时改用 `small_icon` **对象本身**作 [img] 参数 ——
#    Godot 的 BBCode 解析器接受 Object 类型的 [img] 参数（原版 _get_icon()
#    自己也用 markdown 的 [img=..]path[/img] 形式，空资源时填占位图）。
#    真取不到小图标时，退回原版逻辑，行为不变。
# =============================================================================

func get_scaling_stat_icon_text(stat_hsh: int, scaling: float = 1.0, show_plus_prefix: bool = true) -> String:
	var small_icon = ItemService.get_stat_small_icon(stat_hsh)
	if small_icon != null and String(small_icon.resource_path) == "":
		# 运行时贴图（本 mod 自定义属性）：用对象本身渲染，避免空路径
		var w: int = 15 * ProgressData.settings.font_size
		var prefix: String = "+" if show_plus_prefix and scaling > 0.0 else ""
		var color: String = "white" if scaling > 0.0 else "#f6617c"
		return "[color=%s]%s%s%%[/color][img=%sx%s]%s[/img]" % [
				color, prefix, str(round(scaling * 100.0)), w, w, small_icon]
	# 其余情况（原版属性、带 resource_path 的资源）走原版实现
	return .get_scaling_stat_icon_text(stat_hsh, scaling, show_plus_prefix)
