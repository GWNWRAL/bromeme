# Aitato 崩溃修复说明(0.0.2 / BounceNullFix 1.0.1)

> 结论:崩溃**不是 Aitato 自己写了危险代码**,而是本机 Brotato 的定制 Godot 构建
> **把"对 null 值调方法"实现成了进程级陷阱**;Aitato 让 DeepSeek 的开局武器池成了
> 这局游戏的装备来源,于是走上了那条必崩的路径。
> 本次修改给 Aitato 加了**武器池校验**,给 Aitato-BounceNullFix 加了**动作体 `_hitbox`
> 补全**,把这条路径上的地雷拆掉。

---

## 一、修改内容与版本号

| mod | 版本 | 文件 | 说明 |
|---|---|---|---|
| **Aitato** | 0.0.1 → **0.0.2** | `mod_main.gd`、`manifest.json` | 开局武器池校验 + 必崩武器剔除 |
| **Aitato-BounceNullFix** | 1.0.0 → **1.0.1** | 新增 `extensions/weapon_service_projectile_hitbox_fix.gd`,`mod_main.gd`(`PATCHES` 注册)、`manifest.json`、`README.md` | 在 `WeaponService` 交还对象前补全 `_hitbox` |

安装位置(已覆盖安装):

```
D:\Apps\steam\steamapps\workshop\content\1942280\3609140959\Aitato.zip             107041 字节  0.0.2
D:\Apps\steam\steamapps\workshop\content\1942280\3609140959\Aitato-BounceNullFix.zip  11830 字节  1.0.1
```

* 旧版已备份在工作区:`D:\DSH\_aitato_work\backup\Aitato-0.0.1.zip`、
  `Aitato-BounceNullFix-1.0.0.zip`
* 重新打包脚本:`D:\DSH\_aitato_work\build_dist.py`(zip 内部布局与旧版逐条一致)
* 新包 md5:`Aitato.zip` = `ebd85ddc0ce406f33da582abf9646723`,
  `Aitato-BounceNullFix.zip` = `cac8be0605570010ecb5fb2712ca6acb`

### Aitato 0.0.2 具体改了什么

`_add_dlc_pool_weapons()` 现在**先验证再入池**:

```gdscript
var unusable_reason := _weapon_is_usable(weapon)
if unusable_reason != "":
    ModLoaderLog.warn("DLC weapon skipped, would crash on equip (" + unusable_reason + "): " + str(weapon.my_id), LOG_NAME)
    continue
```

`_weapon_is_usable()` 的判定:

1. 武器数据必须带一个 `PackedScene`(字段名从属性表自动识别,不写死);
2. 该场景必须能 `instance()`(失败 = 调用方拿到 null,之后必崩);
3. 场景必须满足 vanilla `weapon.gd` 的节点契约:`$Sprite` 与 `$Sprite/Hitbox` 存在
   (缺一个,`weapon.gd` 的 `onready var _hitbox = $Sprite/Hitbox` 就是 null);
4. 场景不得使用 Godot 4 的节点名(`Sprite2D` / `Marker2D`),本构建里那不是节点类型。

另外新增 `_sanitize_starting_weapons()`:把开局池里**连场景都实例不出来**的条目
(那种武器一进关必崩)剔除并写日志;其余问题只报告、不擅自删别人的武器。

> 安全阀:如果认不出场景字段,校验会**跳过**(只提醒不拒绝),避免因为字段改名
> 就把玩家正常开局武器清空。

### Aitato-BounceNullFix 1.0.1 具体改了什么

新增扩展 `extensions/weapon_service_projectile_hitbox_fix.gd`
(`extends "res://singletons/weapon_service.gd"`),覆盖三个"把新对象交还给调用方"的入口:
`spawn_projectile` / `manage_special_spawn_projectile` / `explode`。交还之前:

```gdscript
if node.get("_hitbox") != null:
    return node                                   # 已经就绪,不动
var hitbox = node.get_node_or_null("%Hitbox")
if hitbox == null:
    hitbox = node.find_node("Hitbox", true, false)
node.set("_hitbox", hitbox)                       # 用场景里已存在的真 Hitbox 补上
```

补进去的是**同一个** `Hitbox` 节点(子节点在 `instance()` 之后就已存在),
入树时 `onready` 会再赋一次同样的值 ⇒ 玩法行为与 vanilla 完全一致,只是不再触碰 null。

---

## 二、崩溃原因

### 第 1 层(根因,引擎侧):对 null 调方法 = 杀进程

本机是定制构建 `Godot Engine v3.7.dev.custom_build.74e86be54`。它对
"在 null Variant 上调用方法"**不做容错**(上游 Godot 3.x 会返回
`CALL_ERROR_INVALID_METHOD` 并打印脚本错误),而是直接执行陷阱桩:

```
0xC0000005  读地址 0x38   @  Brotato.exe+0x1F8D28A
调用链      GDScriptFunction::call → Variant::call_ptr (core/variant_call.cpp)
```

* 偏移 `0x1F8D28A` 在 14 天内出现 **60+ 次**,是**固定、确定性**的;
* 属性访问 null 只是脚本错误(游戏继续),**方法调用** null 才致命 ——
  这正是"有些 mod 写错只是报错、有些直接闪退"的原因。

### 第 2 层(本次触发链):`_hitbox` 还没被赋值就被使用

```gdscript
# res://projectiles/projectile.gd:31
onready var _hitbox := $"%Hitbox" as Area2D      # 只有"入树 + 跑完 _ready()"才有值

# res://singletons/weapon_service.gd:387-394  (spawn_projectile)
projectile = projectile_scene.instance()
if args.deferred:
    main.call_deferred("add_player_projectile", projectile)   # 下一帧才入树
...
return projectile                                             # 却立刻返回
```

`args.deferred == true` 时,调用方拿到的是**还没入树**的动作体,`_hitbox` 仍是 null。
而调用方常常紧接着就用它:

```gdscript
# Yoko-Fantasy  mods-unpacked/Yoko-Fantasy/extensions/melee_weapon.gd:86(以及 :90)
projectile._hitbox.connect("killed_something", self, "on_killed_something", [projectile._hitbox])
```

`<null>.connect(...)` → 进程被杀。

* 谁会置 `args.deferred = true`(**本次会话实际启用**):`Dbear-Capybara`
  `extensions/service/weapon_service_mod.gd:154/181/218`、`extensions/weapon_mod.gd:501`;
* Capybara 自己消费同一模式的地方(`extensions/weapon_mod.gd:633/639`)有 `== null` 判空,
  **Yoko-Fantasy 的这两行没有**。

### 证据(硬)

全部 09-21 的 10 个转储(WER + 自抓私有内存转储,20:09 → 21:06)完全同型:

| 项 | 值 |
|---|---|
| `rip_rva` | `0x1f8d28a`(全部一致) |
| `p_method` | `connect` |
| `p_argcount` | `4` |
| 参数类型 | `(STRING, OBJECT, STRING, ARRAY)` |
| 接收者 `self` | Variant 类型 = **NIL** |

即 `X.connect("killed_something", <obj>, "on_killed_something", [<…>])` 而 `X == null`。
(对比:09-20 那一族是 `p_argcount=1` 的 `get_rand_enemy`,已由 BounceNullFix 1.0.0 修掉。)

日志侧佐证(最新崩溃会话 `logs\godot2026-09-21T21.06.49.log` 末尾,紧接着就是死亡):

```
ERROR: Script inherits from native type 'Reference', so it can't be instanced in object of type 'Node2D'.
   at: instance_create (modules/gdscript/gdscript.cpp:326) - Method failed. Returning: nullptr
ERROR: Parameter "p_child" is null.
   at: add_child (scene/main/node.cpp:1320)
```

—— `instance()` 失败返回 null、`add_child(null)` 报错,紧接着就是对 null 调方法。

### Aitato 到底"参与"在哪

* Aitato 自己的代码里**没有**任何 `_hitbox` / `connect` 的危险调用
  (`extensions/player_aitato.gd` 全程判空,`Sprite.new()` 不用场景实例);
* 但 Aitato 让 **DeepSeek** 成为开局角色,而该角色的开局武器池(日志实测 18 把:
  5 把 vanilla + **11 把 Yoko-Fantasy 近战武器** + Aitato 加的 2 把 DLC 勺子/板砖)
  就是这局游戏的装备来源 —— 拿近战武器 → 走 Yoko 的
  `_fantasy_projectiles_every_x_melee_shoot()` → `spawn_projectile()`(被 Capybara 扩展成
  deferred)→ 那两行无保护的 `_hitbox.connect(...)` → 崩。
* 这解释了"关掉 Aitato 就不崩":关掉后你不打这个角色,也就不带这些武器开局。
  **真正的缺陷在引擎 + Yoko/Capybara 的调用约定,Aitato 是"入口"。**

> 关于 DLC 勺子/板砖:我逐条静态扫过全部 118 个 mod 包,没有发现
> "Reference 脚本挂在 Node2D 节点上"的场景;已安装 pck 的节点名扫描因 pck 内文件
> 压缩而无法定论。所以 **没有证据**表明 DLC 武器场景本身是坏的 —— Aitato 0.0.2 现在会
> 在运行时逐把验证并在 `modloader.log` 写下结论,若真有坏的武器,日志会直接点名。

---

## 三、怎么验证

1. **启动游戏**,看 `%APPDATA%\Brotato\logs\modloader.log`,应出现:

   ```
   INFO BounceNullFix: patched res://singletons/weapon_service.gd
   INFO BounceNullFix: BounceNullFix ready: 5 patch(es) installed
   INFO Aitato: Added to weapon pool: weapon_spoon_1
   INFO Aitato: weapon pool size: ...
   ```

   若 DLC 武器有问题,会变成
   `WARN Aitato: DLC weapon skipped, would crash on equip (…)`:这就是 Aitato 层防线生效。

2. **复现原崩溃场景**:用 DeepSeek 开局,拿近战"每 X 次攻击发射抛射物"的武器打第 1 波
   (原来一次就闪退)。

3. **仍崩溃时取证**:确认 WER 里 `Brotato.exe+0x1F8D28A` 是否还在;
   要拿方法名/参数,用工作区里已有的一次性调试器脚本
   (`D:\DSH\_crash_analysis\livecatch.py` + `readargs.py`)做首次异常捕获。

---

## 四、避免方式(给 mod 作者 / 给自己以后的规则)

**A. 只要可能为 null,就先判空,再调方法**

```gdscript
if obj == null or not is_instance_valid(obj): return
obj.method()                       # 引擎不会给你第二次机会
```

**B. 场景实例化的返回值必须判空**(`instance()` 会因为脚本/原生类型不匹配返回 null):

```gdscript
var node = SCENE.instance()
if node == null: return            # 不要 add_child(node) 之后还去用 node
add_child(node)
```

**C. 不要假设"刚生成的对象已经 ready"**

* `onready var x = $Path` 的语义是"**入树后**才有值";
* 跨函数/跨帧拿到的对象,先 `is_node_ready()`(vanilla `unit.gd:600` 就是这么写的:
  没 ready 就 `call_deferred`);
* 从对象池取出、或 `spawn_projectile` 之类接口拿到的对象,**都不能假设已就绪**。

**D. 不要跨 mod patch 别人的脚本**

`install_script_extension` 装在别的 mod 的脚本上,对方一改路径/结构就会静默失效
(本地 BounceNullFix 对 Capybara 的三个补丁就属于这种"可选项",已保留但随时可能失效)。
优先扩展 **vanilla** 脚本。

**E. 场景必须用 Godot 3 的节点名**

`Sprite` / `Position2D` / `PoolRealArray`;`Sprite2D`、`Marker2D`、`PackedFloat32Array`
在本构建里不可用(实测报 `Cannot get class 'Marker2D'`)。
从 Godot 4 移植 mod 时,这是第一大坑。

**F. 内容 mod 交付"会拿在手里的东西"之前先自检**

Aitato 0.0.2 的 `_weapon_is_usable()` 就是模板:实例化一次、检查节点契约、
`free()` 掉,不合格就不给玩家 —— 一样东西宁可不要,也不要让玩家带着它进关。

**G. 留可验证的诊断日志**

每个"我往游戏里加了什么"的动作都写一行日志(本 mod 的 `Added to weapon pool: …` /
`skipped … (原因)`),出问题时能直接从日志定位,不必再抓 2.7 GB 的转储。

---

## 五、遗留风险(未修 / 需要别人修)

| 项 | 说明 |
|---|---|
| 引擎根因 | "对 null 调方法杀进程"应由 Blobfish 修(上游 Godot 只报错)。建议附偏移 `Brotato.exe+0x1F8D28A` 反馈 |
| 其它同名写法的行 | 本次未启用的 mod 里也有同样的 4 参数无保护写法:`JonathanFox-FoxLab/extensions/weapon_service.gd:105`、`Lasonbrah-Elemento/.../robin_bow_weapon.gd:15`、`haoqi-NZmodNEW/...`(4 处)。它们一旦启用会以完全相同的方式崩;**BounceNullFix 1.0.1 的 `_hitbox` 补全对它们同样有效** |
| Yoko-Fantasy | 真正的写法缺陷在它那边(`melee_weapon.gd:86/90` 缺判空);若你能联系作者,建议照 Capybara 的写法(判断 + `yield` 重试)修 |
| MoreElites-BossPack | 场景 `Particles2D` 节点挂了 `extends CPUParticles2D` 的脚本,每局报 3 条 `Script inherits from native type 'CPUParticles2D'…`(非致命,但建议作者改成 `CPUParticles2D` 节点类型) |
| `weapon.gd` 的 `_hitbox` | 若某把**武器**场景缺 `Sprite/Hitbox`,`weapon.gd:_ready()` 里的 `_hitbox.connect(...)` 同样致命,**mod 侧无法完全拦截**(基类 `_ready` 自动多级调用,扩展拦不住)—— 只能靠 A.~F. 的纪律和作者的场景检查 |

---

*取证脚本都在 `D:\DSH\_crash_analysis\`(`all_dumps.py` 批量读转储签名、
`readyscan.py`/`zipscan*.py` 扫 mod 源码与场景、`pcknames.py` 查 pck 节点名、
`peek.py` 直接打印 zip 内文件、`build_dist.py` 打包)。*
