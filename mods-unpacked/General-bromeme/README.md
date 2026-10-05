# bromeme

Brolab 里做出来的一批角色和物品（20 个角色 + 87 个物品），打包成一个独立 mod。

## 安装

把 `Bromeme.zip` 丢进 Brotato 的 mod 目录（Steam 创意工坊或者 `mods` 文件夹），
在游戏里启用即可。**不需要安装 BroLab，也不会往 `brolab` 目录里写任何东西。**

## 炮塔（`character_brolab_pt_431`）重做

### 0.2.5

- 新增「+30 击退」：`lantern_effect_0d`（`key = knockback`, `text_key = EFFECT_KNOCKBACK`）改 `value = 30`
  —— 就是灯笼自己给 +15 击退用的那条。这条同时也决定光环的推人力度：
  `knockback_aura_effect_behavior.gd` 里是 `max(1.0, Utils.get_stat(knockback))`。

### 0.2.4

- 击退光环改成**直接用原版灯笼那条效果本体**：`res://dlcs/dlc_1/items/lantern/effects/lantern_effect_1.tres`
  （`key = knockback_aura`），只把 `value` 改成 **1** —— 那个值就是
  `knockback_aura_effect_behavior.gd` 里 `KnockbackTimer.wait_time` 的秒数，
  所以现在是**每 1 秒**击退附近的敌人，并且用的是游戏自己的光环（半径 200 的 hitbox、
  敲钟音效、扩散动画都是原版的），之前那套自写计时器已从 `player_turret.gd` 移除。
  `text_key` 用单数版 `EFFECT_KNOCKBACK_AURA`（原版灯笼是 3 秒，所以用的是复数版）。
- 新增「有 100% 概率立即吸收掉落的材料」：`sifds_relic_effect_1`（`instant_gold_attracting = 100`），
  即原版 Sifd's Relic 的那条，原样引用。
- 新增「攻击速度的修改 +50%」「伤害的修改 +50%」：`golem_effect_2`
  （`stat_gains_modification_effect`）分别把 `stat_displayed` / `stats_modified`
  指向 `stat_attack_speed` 与 `stat_damage`，`value = 50`。

### 0.2.3

- **去掉**「生命窃取 -100」那条（原来靠它把速度上限压到 -100）。
- 「速度至多为 -100%」改为**固定值**：`shackles_effect_4` 不再锁到当前生命窃取，
  而是 `set_cap_to_current_stat = ""` + `value = -100`，显示与效果都与之前一致。

### 0.2.2

角色效果换成下面这一组（原来的命中爆炸、属性获取 -50%、开局 2 个炮塔等都去掉了）：

| 效果 | 来自 |
|---|---|
| +25 最大生命值 | `cake_effect_1` 改 value |
| +10 护甲 | `campfire_effect_2` 改 key=stat_armor |
| +10 生命再生 | `campfire_effect_2` |
| 速度至多为 -100% | `shackles_effect_4`（0.2.3 起为固定 -100） |
| 按下移动键时护甲翻倍，但无法回复生命 | 新（`custom_key` 标记 + `extensions/player_turret.gd`） |
| 刚按下移动键时获得 0.25 秒无敌（冷却 1 秒） | 新（同上） |
| 每 1 秒击退附近的敌人 | 原版灯笼效果（0.2.4 起） |
| +30 击退 | 原版灯笼那两条（0.2.5 起），同时也决定光环推人力度 |
| 100% 概率立即吸收掉落的材料 | 原版 Sifd's Relic 效果 |
| 攻击速度的修改 +50% / 伤害的修改 +50% | `golem_effect_2` 改 stat |

- 两条"按下移动键"机制只在角色带对应标记效果时生效（`custom_key` =
  `bromeme_turret_move` / `bromeme_turret_iframe`），其它角色、原版角色完全不受影响：
  * 看的是 player 的 `_current_movement`（原始输入方向），速度被卡到 -100% 也照样能触发；
  * 护甲翻倍 = 把当前护甲原样加进 `TempStats`；“无法回复生命” = 当前生命再生临时压成 0；松开移动键立刻还原；
  * 无敌直接启动 player 自带的 `$InvincibilityTimer`（原版 `take_damage()` 就是看它），冷却 1 秒用时间戳记。

## 相比 0.1.x 的变化

0.1.x 的做法是把 `resources/` 下的 json 和图标**拷贝**到
`%APPDATA%\Brotato\brolab\`，再由 BroLab 读进去。这带来三个问题：

1. **残留**：只删掉 mod 的话，`brolab` 里会留下一堆孤儿 json 和图标。
2. **撞车**：BroLab 用 unix 时间戳当文件名、手打的名字 + `randi() % 512` 当 `my_id`，
   和别人用 BroLab 做的东西很容易重名/重 id，于是出现重复角色、重复物品。
3. **没有局内贴图**：BroLab 写死了角色外观（圆土豆 + 默认眼睛嘴巴），
   用它导入的角色在局内只能看到土豆。

0.2.0 改成这个 mod **自己**读 `resources/`、自己构造 `CharacterData` / `ItemData`
并直接注册到 `ItemService`，因此：

* 不写 `brolab`，删掉 mod 干干净净，不会影响别人的 BroLab 内容；
* `my_id` 固定写在 json 里（107 个全部唯一），不再随机，不会撞车，
  重复安装/升级也不会出现第二个同名角色；
* 注册前会按 `my_id` 去重：如果 `ItemService` 里已经有同 id 的内容
  （比如从 0.1.x 升级上来、`brolab` 里还留着旧副本），会先把旧的踢掉再放本 mod 这份，
  所以商店和选人界面永远不会出现两个一样的角色/物品；
* 角色局内用 `art/char/<id>.png` 当身体贴图（原版土豆和腿会被隐藏），
  商店/背包图标用 `art/item/<id>.png`。

## 从 0.1.x 升级（启动时自动清理）

0.1.x 往 `%APPDATA%\Brotato\brolab\` 拷过 107 个 json 和 107 张图标。0.2.0 不再碰那个目录，
但旧文件不会自己消失（只是因为下面说的去重，不会再变成重复内容），所以 mod 每次启动时会顺手清掉。

判定条件很严，**必须同时满足**才删：

1. 文件名和本 mod `resources/` 里的某个文件完全一样，**并且**
2. 文件里的 `my_id` 和本 mod 那份完全一样。

只按文件名是不够的 —— 实测里就有一个 `1761042954.json`，文件名和我们的「猪猪侠」撞了，
但里面其实是用户的「代步机器人」(`item_brolab_ly_166`)，这种情况会被保留。

图标同理：只删被这些已确认属于本 mod 的 json 引用的图标，
而且**只要还有任何别的 json（包括 BroLab 自己的内容）引用它，就不删**。

清理结果会打进日志：

```
INFO bromeme: 清理了 0.1.x 残留在 brolab 里的 29 个 json + 29 张图标
```

不想要这个行为的话，把 `mod_main.gd` 里的 `BROLAB_CLEANUP_ENABLED` 改成 `false` 即可。

> 注意：如果你习惯在 BroLab 编辑器里改这些内容，改动导出到 `resources/` 之后
> brolab 里那份会被自动删掉（因为已经和 mod 里的一致了）。要继续用编辑器改的话，
> 先别把改动同步进 `resources/`，或者关掉上面的开关。

## 目录结构

```
mod_main.gd                读 resources/ 并注册内容；装载内置效果脚本和脚本扩展
manifest.json
resources/                 内容定义（唯一真源）
  *.json                   一个文件一个角色/物品
  icons/                   原始图标素材（只用于生成 art/，不打进 zip）
  edited/                  改过的图（只用于生成 art/，不打进 zip）
    <id>.png               替换图标 **和** 局内身体贴图
    <id>.body.png          只替换局内身体贴图，图标保持原样
    *.bg-attempt.png       仅供对比的尝试稿，构建时不认
  _index.json              由 build 脚本生成的资源清单
art/                       由 icons/ + edited/ 生成的 96x96 贴图（进 zip）
  char/<id>.png            图标 / 选人界面头像
  body/<id>.png            局内身体贴图（只有和图标不同时才生成）
  item/<id>.png            商店 / 背包图标
brolab_compat/             从 BroLab 借来的自定义效果（天元鼎 / 丁真 需要）
extensions/
  player_bromeme.gd           局内隐藏原版土豆与腿，只对带 bromeme 标记的角色生效
  player_turret.gd            炮塔的“按下移动键”机制：护甲翻倍 / 无法回复生命 / 0.25s 无敌
  character_panel_bromeme.gd  角色信息面板（暂停/背包里的预览）同样处理
```

## 改内容

1. 编辑 `resources/*.json`（或者用 BroLab 编辑器导出后覆盖过来）；
2. 重新生成 `art/` 和 `resources/_index.json`；
3. 重新打包 zip。

这三个步骤由 `bromeme_build.py` 一次做完（脚本在开发目录里，不在 mod 内）。
`bromeme_edits.py` 负责生成 `resources/edited/`（镜像 / 抠图）。

### 用 Photoshop 改图

不用改任何脚本：把导出的 PNG 丢进 `resources/edited/`，

* `resources/edited/<id>.png` —— 图标和局内图一起换
* `resources/edited/<id>.body.png` —— 只换局内图，图标不动

然后跑一次 `bromeme_build.py` 即可。

> **龙卷风（`1760863546`）目前只做了镜像，没抠背景。**
> 那张图是"机甲 + 火焰背景"，机甲主体也是橙色系，用颜色分割一定会把机甲咬碎
> （各类 key 都试过，最好也会留下锯齿状火苗），所以宁可不动。
> 想要抠图的话，用 PS 的「选择主体 / 移除背景」导出，
> 存成 `resources/edited/1760863546.png` 再重新构建就行。
> 我的最佳自动尝试留在 `resources/edited/1760863546.bg-attempt.png` 供对比。

## 兼容性

* 不依赖 ContentLoader，也不依赖 BroLab。
* 如果同时装了 BroLab：本 mod 从 `brolab` 目录**读**不到东西也不受影响；
  两边注册的效果 id 相同（`brolab_effect_*`），脚本扩展会互相链式调用，
  结果一致。
* `my_id` 沿用 0.1.x 的值，所以老存档里的解锁状态、难度进度都还有效。
