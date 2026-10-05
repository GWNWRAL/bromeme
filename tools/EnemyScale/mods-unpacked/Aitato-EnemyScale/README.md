# Aitato :: EnemyScale

**v1.0.0** — 让敌人的**生命 / 伤害 / 速度每波指数级（复利）增长**，三个数值都能在游戏内的
Mod Options 里用滑杆调整（默认 **5% / 5% / 0%**）。

---

## 核心公式

```
第 N 波倍率 = (1 + 每波增长率) ^ N
```

**是乘方，不是 `1 + N × 增长率`。** 每一波都在前一波的基础上再涨，所以增长是复利的：

| 波数 | 本模组 +5%（复利） | 线性做法 +5% |
|---|---|---|
| 1 | ×1.0500 | ×1.0500 |
| 2 | ×1.1025 | ×1.1000 |
| 3 | ×1.1576 | ×1.1500 |
| 10 | ×1.6289 | ×1.5000 |
| 20 | ×2.6533 | ×2.0000 |
| 40 | ×7.0400 | ×3.0000 |
| 60 | ×18.6792 | ×4.0000 |

对照需求里的定义：某个倍率已经是 **200%**、增长率 5% 时，下一波是
`2.00 × 1.05 = 2.10`，即 **200% → 210%**（线性做法只会得到 205%）。
逐波比值恒为 1.05 —— 这正是"复利"的定义。

---

## 配置项（Mod Options）

| 键 | 含义 | 默认 | 范围 |
|---|---|---|---|
| `hp_percent_per_wave` | 敌人生命每波增长 | `0.05` | 0 – 1.0，步进 0.01 |
| `damage_percent_per_wave` | 敌人伤害每波增长 | `0.05` | 0 – 1.0，步进 0.01 |
| `speed_percent_per_wave` | 敌人速度每波增长 | `0` | 0 – 0.3，步进 0.01 |

在 `manifest.json` 的 `extra.godot.config_schema` 中声明，modloader 会把它们渲染成
滑杆；改动后通过 `setting_changed` 信号即时生效并写回
`%APPDATA%\Brotato\configs\Aitato-EnemyScale\default.json`。

> 速度默认关闭，因为速度一改手感变化很大。

---

## 实现方式

扩展 `res://singletons/entity_service.gd`（`extensions/singletons/entity_service.gd`），
在三个"最终敌人属性"出口上乘一个因子：

```gdscript
get_final_enemy_health(from_value, percent_modifier) -> int
get_final_enemy_damage(from_value, percent_modifier) -> int
get_final_enemy_speed(from_value, effects_factor, percent_modifier) -> int
```

选这三个入口的原因：

1. 原版把难度、诅咒、无尽、玩家属性等所有倍率都在这里乘到基础值上并缓存；在**最终
   结果**上再乘一层，与既有倍率是相乘关系，不会互相覆盖。
2. `main.gd` 每波开始时调用 `EntityService.reset_cache()`，这是读取当前波数的天然时机，
   本模组顺便覆写它来刷新配置并输出一行可核对的日志：

   ```
   INFO Aitato-EnemyScale: wave 3 -> hp x1.1576, damage x1.1576, speed x1.0000 (5% / 5% / 0% per wave, compounding)
   ```

---

## 安全阀

| 项 | 行为 |
|---|---|
| 增长率为负 | 视为 0（不变） |
| 增长率 > 1.0 | 封顶到 1.0（每波翻倍） |
| 波数 > 200 | 不再继续叠加 |
| 倍率上限 | `1e6`，避免极端配置下把巨大浮点转 int 溢出 |
| 无 ModOptions | 不报错，使用默认值，游戏照常运行 |

---

## 兼容性提醒

**不要和 `opaaaaaaaaaaaa-EnemiesEvolve` 同时启用。** 两者的实现方式相同（都扩展
`entity_service.gd`），同时启用会**叠加**成双重增长。本模组是它的复利版本，用其一即可。

---

## 文件结构

```
mods-unpacked/Aitato-EnemyScale/
├── manifest.json                                  # 元数据 + config_schema
├── mod_main.gd                                    # 安装脚本扩展
└── extensions/singletons/entity_service.gd        # 复利倍率 + 配置读写
```

## 注意：扩展继承链上的命名

ModLoader 会把所有扩展**串成一条继承链**（后加载的包住先加载的），因此扩展里的
**常量**必须使用独立前缀，否则会与链上其它模组撞名并导致整份扩展解析失败：

```
Parse Error: The member "SE_MOD_ID" already exists in a parent class.
INFO ModLoader:ScriptExtension: Installing script extension: Null <- .../entity_service.gd
```

本模组统一使用 `ES_` / `es_` 前缀（`ES_MOD_ID`、`ES_LOG_NAME`、`es_hp_factor()` …）
规避这个问题——这也是最初照搬参照物 `se_` 前缀时踩到的坑。
