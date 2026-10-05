# Aitato

**Version 0.0.1** — a Brotato mod that adds new characters and content.

First character: **DeepSeek / 大肥鱼**.

---

## Character: DeepSeek (大肥鱼)

`character_aitato_deepseek`

DeepSeek is always tired. The moment she stops moving she falls asleep.

| | |
|---|---|
| **While sleeping** | HP Regeneration **+10**, but she **cannot attack** |
| **Charge bar** | Appears under her feet while asleep and fills over **1 second** |
| **When it fills** | **Critical Damage doubled** and **Armor doubled** for **10 seconds** |
| **Starting item** | **Scared Sausage** (害怕的香肠) |

Moving again wakes her up and resets the bar. The charge bar and the buff timer
both reset at the end of every wave.

### In-game description lines

1. 停止移动后开始睡觉：生命再生 +10，但无法攻击。
2. 睡觉时脚下会出现一个充能条，1 秒攒满。
3. 攒满后获得持续 10 秒的暴击伤害翻倍和护甲翻倍。
4. 开局自带一个害怕的香肠。

---

## Files

```
Aitato-Aitato/                    <- folder MUST be {namespace}-{name}
├── manifest.json                 # name Aitato, namespace Aitato, version 0.0.1
├── mod_main.gd                   # extensions + translations + content registration
├── translations/
│   ├── trans.csv                 # source: key,zh_Hans_CN,en
│   ├── trans.en.translation      # compiled by Godot's csv_translation importer
│   └── trans.zh_Hans_CN.translation
├── content_data/
│   └── aitato_content_data.tres  # ContentLoader entry point
├── contents/
│   ├── characters/deepseek/
│   │   ├── deepseek_data.tres    # CharacterData
│   │   ├── deepseek_appearance.tres
│   │   ├── deepseek.png          # 96x96 character art  (from 素材/)
│   │   ├── deepseek_icon.png     # selection-screen icon
│   │   ├── deepsleep.png         # 96x96 sleeping art  (from 素材/)
│   │   └── effects/deepseek_effect_0..4.tres
│   └── items/scared_sausage/
│       ├── scared_sausage_data.tres
│       └── scared_sausage_icon.png
└── extensions/
    ├── player_aitato.gd          # sleep state, charge bar, buff, art swap
    └── weapon_aitato.gd          # block attacks while asleep

.import/                          # compiled .stex texture cache (REQUIRED, at zip root)
```

The sleeping texture is deliberately named **`deepsleep.png`**.

---

## How it works

* **Sleep detection** — `player_aitato.gd` extends
  `res://entities/units/player/player.gd` and watches `_current_movement` in
  `_physics_process()`. After 0.15 s of no movement the player is "asleep".
* **+10 HP Regeneration** — the vanilla `temp_stats_while_not_moving` effect on
  the character data handles this; vanilla already applies and removes it as the
  player starts/stops moving (`Player.check_not_moving_stats()`).
* **Cannot attack** — `weapon_aitato.gd` extends `res://weapons/weapon.gd` and
  returns `false` from `should_shoot()` while the owner is asleep. Brotato has no
  built-in "disable attacks" flag, so this is the supported hook.
* **Sleeping art** — `deepsleep.png` is added as a `Sprite` child of the
  player's `Animation/Sprite` node and shown only while asleep; the character's
  normal body art (an `ItemAppearanceData`) is hidden meanwhile.
* **Charge bar** — a small `Node2D` (background + fill sprites using a generated
  1x1 white texture) parented next to the body sprite so it tracks the player but
  does not inherit the sprite's left/right mirroring.
* **Doubled Armor** — `TempStats.add_stat(Keys.stat_armor_hash, current_armor, …)`
  while the buff lasts (removed when it ends).
* **Doubled Critical Damage** — weapon crit damage is a plain multiplier copied
  off the weapon resource at init time and never touched by any player stat, so
  the weapon's live `current_stats.crit_damage` and its hitbox are doubled
  directly. The original value is remembered in the weapon's metadata and
  re-applied by `weapon_aitato.gd::init_stats()` after every stat recalculation.
* **Text** — `translations/trans.csv` is compiled into `PHashTranslation`
  resources and registered with `ModLoaderMod.add_translation()`, matching the
  reference mod. English and Simplified Chinese are provided.

Tunable constants live at the top of `extensions/player_aitato.gd`:
`CHARGE_DURATION`, `BUFF_DURATION`, `SLEEP_DELAY`, `BAR_*`.

---

## Requirements

* Brotato **1.1.15.4**
* **Brotato ModLoader** 6.x
* **Darkly77-ContentLoader** (recommended — used to register the content; the mod
  falls back to manual `ItemService` registration if it is missing)

---

## Packaging notes (learned the hard way)

These four things will break the mod if you re-pack it by hand:

1. **Folder name must be `{namespace}-{name}`** (`Aitato-Aitato`), matching
   `manifest.json`. The loader rejects anything else outright.
2. **Zip paths must use forward slashes.** PowerShell's `Compress-Archive`
   writes `\` separators, which Godot's `load_resource_pack` refuses. Build the
   archive with `System.IO.Compression.ZipArchive` instead.
3. **Textures must ship as compiled `.stex`** plus their `.import`/`.md5`
   companions, and the `.import/` folder must sit at the **zip root** (because
   the `.import` files reference `res://.import/...`). A raw PNG alone will not
   load.
4. **Never write UTF-8 BOMs** into `.gd`/`.tres` files. PowerShell's
   `Set-Content -Encoding UTF8` adds one and Godot fails with
   `Parse Error: Expected '['`.
