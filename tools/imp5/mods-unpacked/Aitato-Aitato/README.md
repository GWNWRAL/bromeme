# Aitato

**Version 0.0.1** — a Brotato content mod.

First character: **DeepSeek / 大肥鱼**.

---

## Character: DeepSeek (大肥鱼)

`character_aitato_deepseek`

| | |
|---|---|
| **Starting item** | **Scared Sausage** (害怕的香肠) |
| **Starting weapon choice** | **Stick** (树枝) / **Knife** (菜刀) / **Screwdriver** (螺丝刀) / **Pistol** (手枪) / **Wand** (法杖) / **Brick** (板砖, DLC only) |
| **When she stops moving** | Falls asleep: **HP Regeneration +10**, and she **cannot attack** |
| **While asleep** | Her art is swapped for the **`deepsleep`** sprite |
| **When she moves again** | Wakes up; art and stats are restored |

### In-game description (shown on the character)

* 停止移动时开始睡觉：生命再生+10，但无法攻击。
* 开局自带一个害怕的香肠。

Both lines are rendered by a plain-text `description` effect
(`extensions/description_effect.gd`), the same pattern used by the reference
mods: `static get_id()` + an empty `get_args()`, so the effect line shows exactly
what `text_key` translates to — no numbers, no BBCode, no icon.

---

## Files

```
Aitato-Aitato/                    <- folder MUST be {namespace}-{name}
├── manifest.json                 # name Aitato, namespace Aitato, version 0.0.1
├── mod_main.gd                   # extensions + translations + content + diagnostics
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
│   ├── deepsleep.png             # 96x96 sleeping art  (from 素材/, do not rename)
│   └── effects/
│       ├── deepseek_starting_item.tres
│       └── deepseek_sleep.tres
└── extensions/
    ├── description_effect.gd     # plain-text description effect
    ├── player_aitato.gd          # sleep / wake, +10 regen, art swap, item + DLC weapon
    └── weapon_aitato.gd          # blocks attacks while asleep

.import/                          # compiled .stex texture cache (REQUIRED, at zip root)
```

---

## How it works

* **Sleep detection** — `player_aitato.gd` extends
  `res://entities/units/player/player.gd`, is active only for
  `character_aitato_deepseek`, and watches `_current_movement` each physics
  frame. After 0.15 s of no movement she falls asleep.
* **+10 HP Regeneration** — added with
  `TempStats.add_stat(Keys.stat_hp_regeneration_hash, 10, player_index)` on
  falling asleep and removed on waking (also on wave cleanup).
* **Cannot attack** — `weapon_aitato.gd` extends `res://weapons/weapon.gd` and
  returns `false` from `should_shoot()` while the owner reports
  `aitato_is_sleeping()`.
* **Sleeping art** — `deepsleep.png` is a `Sprite` child of the player's
  `Animation/Sprite` node, shown only while asleep.
* **No blank potato** — the character's body art is an `ItemAppearanceData` that
  vanilla adds as a **child of the potato sprite**, so the potato cannot be
  hidden with `visible = false` (that would hide the art too). Instead the potato
  is made fully transparent (`self_modulate.a = 0`) while the art is shown, and
  the sleeping sprite replaces the art. The potato is only hidden when there is
  art to show in its place.
* **Starting items** — the Scared Sausage (`item_scared_sausage`) is granted once
  by `player_aitato.gd` through `RunData.add_item()`; `starting_weapons` lists
  the five base-game weapons.
* **Brick / 板砖 is a DLC weapon.** Referencing it from the `.tres` would break
  the whole CharacterData when the DLC is inactive, so it is granted at runtime
  by `player_aitato.gd`, only when
  `ProgressData.is_dlc_available_and_active("abyssal_terrors")` is true.
* **Diagnostics** — on startup the mod logs
  `status: in ItemService.characters=… hash=… unlocked=… pool_size=…` so
  "character not in the list" issues can be diagnosed from `modloader.log`.

Tunable constants: `SLEEP_DELAY`, `HP_REGEN_BONUS`, `DEEPSLEEP_TEXTURE_PATH`,
`BRICK_WEAPON_PATH`, `SCARED_SAUSAGE_ID` in `extensions/player_aitato.gd`.

---

## Requirements

* Brotato **1.1.15.4**
* **Brotato ModLoader** 6.x
* **Darkly77-ContentLoader** (recommended — used to register the content; the mod
  falls back to manual `ItemService` registration if it is missing)

---

## Packaging notes (learned the hard way)

1. **Folder name must be `{namespace}-{name}`** (`Aitato-Aitato`), matching
   `manifest.json`. The loader rejects anything else outright.
2. **Never reference DLC resources** (`res://dlcs/dlc_1/...`) from a `.tres`.
   If the DLC is not active the resource fails to parse and the character cannot
   be loaded at all — this was the cause of the startup crash. Spoon and Brick
   are both DLC weapons.
3. **Never reference another mod's resources** — that mod may not be installed.
4. **Zip paths must use forward slashes.** PowerShell's `Compress-Archive`
   writes `\` separators, which Godot's `load_resource_pack` refuses. Build the
   archive with `System.IO.Compression.ZipArchive` instead.
5. **Textures must ship as compiled `.stex`** plus their `.import`/`.md5`
   companions, and the `.import/` folder must sit at the **zip root** (because
   the `.import` files reference `res://.import/...`). Re-import after changing
   any PNG, or the old texture is served from the cache.
6. **Never write UTF-8 BOMs** into `.gd`/`.tres` files. PowerShell's
   `Set-Content -Encoding UTF8` adds one and Godot fails with
   `Parse Error: Expected '['`.
