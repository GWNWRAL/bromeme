# Aitato

**Version 0.0.1** — a Brotato content mod.

First character: **DeepSeek / 大肥鱼**.

---

## Character: DeepSeek (大肥鱼)

`character_aitato_deepseek`

| | |
|---|---|
| **Starting item** | **Scared Sausage** (害怕的香肠) |
| **Starting weapon choice** | **Stick** (树枝) / **Knife** (菜刀) / **Screwdriver** (螺丝刀) |
| **When she stops moving** | Falls asleep: **HP Regeneration +10**, and she **cannot attack** |
| **While asleep** | Her art is swapped for the **`deepsleep`** sprite |
| **When she moves again** | Wakes up; art and stats are restored |

### In-game description

* 开局自带一个害怕的香肠。

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
├── contents/characters/deepseek/
│   ├── deepseek_data.tres        # CharacterData
│   ├── deepseek_appearance.tres  # ItemAppearanceData (body art)
│   ├── deepseek.png              # 96x96 character art  (from 素材/)
│   ├── deepseek_icon.png         # selection-screen icon
│   ├── deepsleep.png             # 96x96 sleeping art  (from 素材/)
│   └── effects/
│       └── deepseek_starting_item.tres
└── extensions/
    ├── player_aitato.gd          # sleep / wake, +10 regen, art swap
    └── weapon_aitato.gd          # blocks attacks while asleep

.import/                          # compiled .stex texture cache (REQUIRED, at zip root)
```

The sleeping texture is deliberately named **`deepsleep.png`**.

---

## How it works

* **Sleep detection** — `player_aitato.gd` extends
  `res://entities/units/player/player.gd`, is active only for
  `character_aitato_deepseek`, and watches `_current_movement` each physics
  frame. After 0.15 s of no movement she falls asleep.
* **+10 HP Regeneration** — added with
  `TempStats.add_stat(Keys.stat_hp_regeneration_hash, 10, player_index)` on
  falling asleep and removed on waking (also on wave cleanup). `TempStats` is
  cleared by the game at the end of every wave.
* **Cannot attack** — `weapon_aitato.gd` extends `res://weapons/weapon.gd` and
  returns `false` from `should_shoot()` while the owner reports
  `aitato_is_sleeping()`. Brotato has no built-in "disable attacks" flag, so
  this is the supported hook.
* **Sleeping art** — `deepsleep.png` is created as a `Sprite` child of the
  player's `Animation/Sprite` node and shown only while asleep; the character's
  normal body art (an `ItemAppearanceData`) is hidden meanwhile.
* **Starting items** — the `starting_item` effect on the character data grants
  the vanilla `item_scared_sausage` on run start; `starting_weapons` lists
  Stick / Knife / Screwdriver.
* **Text** — `translations/trans.csv` is compiled into `PHashTranslation`
  resources and registered with `ModLoaderMod.add_translation()`, matching the
  reference mod. English and Simplified Chinese are provided.

Tunable constants live at the top of `extensions/player_aitato.gd`:
`SLEEP_DELAY`, `HP_REGEN_BONUS`, `DEEPSLEEP_TEXTURE_PATH`.

---

## Requirements

* Brotato **1.1.15.4**
* **Brotato ModLoader** 6.x
* **Darkly77-ContentLoader** (recommended — used to register the content; the mod
  falls back to manual `ItemService` registration if it is missing)

---

## Packaging notes (learned the hard way)

These will break the mod if you re-pack it by hand:

1. **Folder name must be `{namespace}-{name}`** (`Aitato-Aitato`), matching
   `manifest.json`. The loader rejects anything else outright.
2. **Never reference another mod's resources** — that mod may not be installed.
3. **Never reference DLC resources** (`res://dlcs/dlc_1/...`) from
   `starting_weapons`. If the DLC is not active, the `.tres` fails to parse and
   the character cannot be loaded at all. The Spoon is a DLC weapon, so a
   base-game weapon is used in its place.
4. **Zip paths must use forward slashes.** PowerShell's `Compress-Archive`
   writes `\` separators, which Godot's `load_resource_pack` refuses. Build the
   archive with `System.IO.Compression.ZipArchive` instead.
5. **Textures must ship as compiled `.stex`** plus their `.import`/`.md5`
   companions, and the `.import/` folder must sit at the **zip root** (because
   the `.import` files reference `res://.import/...`). A raw PNG alone will not
   load.
6. **Never write UTF-8 BOMs** into `.gd`/`.tres` files. PowerShell's
   `Set-Content -Encoding UTF8` adds one and Godot fails with
   `Parse Error: Expected '['`.
