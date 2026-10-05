# Aitato

**Version 0.0.1** — a Brotato content mod.

First character: **DeepSeek / 大肥鱼**.

---

## Character: DeepSeek (大肥鱼)

`character_aitato_deepseek`

| | |
|---|---|
| **Starting item** | **Scared Sausage** (害怕的香肠) |
| **Elemental Damage modifications** | **-25%** |
| **Starting weapon choice** | **Stick** (树枝) / **Knife** (菜刀) / **Screwdriver** (螺丝刀) / **Pistol** (手枪) / **Wrench** (扳手) / **Spoon** (勺子, DLC) / **Brick** (板砖, DLC) |
| **When she stops moving** | Falls asleep: **HP Regeneration +10** |
| **While asleep** | Her art is swapped for the **`deepsleep`** sprite |
| **When she moves again** | Wakes up; art and stats are restored |

### In-game description (shown on the character)

* 停止移动时开始睡觉：生命再生{0}。
* 开局自带{0}个害怕的香肠。

Each `{0}` is a **`CustomArg` placeholder**, not a literal number: the effect
carries `value = 10` / `value = 1`, and the arg is bound with
`arg_value = ArgValue.VALUE` so the displayed number always comes from the
effect's own `value`. Change the value and the description follows.

All three effects are plain vanilla `Effect` resources
(`res://items/global/effect.gd`) — no custom script and no BBCode.

**Text is registered at runtime** in `mod_main.gd` via
`Translation.new()` + `add_message()`, under `en`, `zh_Hans_CN` and `zh`. The
compiled `translations/trans.*.translation` resources are kept only as a
fallback. This matters because Godot 3's `PHashTranslation` — what the
`csv_translation` importer produces — uses a perfect-hash table that **collides
for certain key sets, and a colliding key silently resolves to its own raw key
text**. `Translation.add_message()` stores a plain dictionary and always
resolves.

---

## Files

```
Aitato-Aitato/                    <- folder MUST be {namespace}-{name}
├── manifest.json                 # name Aitato, namespace Aitato, version 0.0.1
├── mod_main.gd                   # extensions + runtime text + content + pool + diagnostics
├── translations/
│   ├── trans.csv                 # readable source (key,zh_Hans_CN,en)
│   ├── trans.en.translation      # compiled fallback
│   └── trans.zh_Hans_CN.translation
├── content_data/
│   └── aitato_content_data.tres  # ContentLoader entry point
├── contents/characters/deepseek/
│   ├── deepseek_data.tres        # CharacterData
│   ├── deepseek_appearance.tres  # ItemAppearanceData (body art)
│   ├── deepseek.png              # 96x96 character art  (from 素材/)
│   ├── deepseek_icon.png         # 96x96 selection-screen icon
│   ├── deepsleep.png             # 96x96 sleeping art  (from 素材/, do not rename)
│   └── effects/
│       ├── deepseek_starting_item.tres   # vanilla "starting_item" effect (Scared Sausage)
│       ├── deepseek_sleep.tres           # stat_hp_regeneration +10 + custom text
│       └── deepseek_elemental.tres       # 元素伤害的修改 -25% (Mage-style gains modifier)
└── extensions/
    └── player_aitato.gd          # sleep / wake state + art swap

.import/                          # compiled .stex texture cache (REQUIRED, at zip root)
```

---

## How it works

* **Sleep detection** — `player_aitato.gd` extends
  `res://entities/units/player/player.gd`, is active only for
  `character_aitato_deepseek`, and watches `_current_movement` each physics
  frame. After 0.15 s of no movement she falls asleep.
  (`_current_movement == Vector2.ZERO` is exactly what vanilla itself uses to
  test "standing still" in `weapons/weapon.gd`.)
* **+10 HP Regeneration** — a normal character effect
  (`key = "stat_hp_regeneration"`, `value = 10`), applied by the vanilla effect
  system on run start. It is **not** a sleep-only buff, so the number is always
  granted; the extension only handles the sleep/wake state and the art swap.
* **Sleeping art** — `deepsleep.png` (96×96) is a `Sprite` child of the player's
  `Animation/Sprite` node, shown only while asleep. Same size and framing as the
  standing art, so the swap does not jump.
* **No blank potato** — the character's body art is an `ItemAppearanceData` that
  vanilla adds as a **child of the potato sprite**, so the potato cannot be
  hidden with `visible = false` (that would hide the art too). Instead the potato
  is made fully transparent (`self_modulate.a = 0`) while the art is shown, and
  the sleeping sprite replaces the art. The potato is only hidden when there is
  art to show in its place.
* **Starting item** — the Scared Sausage is **the same resource pattern the
  vanilla Mage uses** (`items/characters/mage/mage_effect_3b.tres`):
  `key = "item_scared_sausage"`, `custom_key = "starting_item"`,
  `storage_method = KEY_VALUE`, `effect_sign = FROM_VALUE`. Vanilla grants it in
  `RunData.add_starting_items_and_weapons()`, which walks
  `effects[Keys.starting_item_hash]`. Because `custom_key` is `starting_item`,
  `CharacterDescription` also strips this line from the effect list and shows the
  item itself instead — no custom granting code is needed.
* **Elemental Damage modifications -25%** — this is the Mage's *second* elemental
  effect (`items/characters/mage/mage_effect_2.tres`), not its first. The Mage has
  two, and vanilla words them differently on purpose:
  * `mage_effect_1` — `key = "stat_elemental_damage"`, `value = 5`
    → flat: `+5 元素伤害`.
  * `mage_effect_2` — `res://effects/items/stat_gains_modification_effect.gd`,
    `stat_displayed = "stat_elemental_damage"` → `元素伤害的修改+25%`.

  `deepseek_elemental.tres` mirrors **effect_2** with the negative twin key
  (`effect_reduce_stat_gains`, `value = -25`), which resolves to vanilla's
  `的修改减少{1}` and renders as `元素伤害的修改-25%` / `-25% Elemental Damage
  modifications`.

  Mechanically it adds `-25` to `gain_stat_elemental_damage`, and
  `RunData.get_stat()` is `get_player_effect(stat) * get_stat_gain(stat)` where
  `get_stat_gain = 1 + gain/100`. So it reduces *the modifier applied to* the
  stat (item and level-up gains) by 25% — it does **not** subtract 25 from the
  stat itself. The flat variant is a single line away if you ever want both.
* **Spoon (勺子) and Brick (板砖) are DLC weapons.** Referencing them from the
  character `.tres` would break the whole CharacterData when the DLC is inactive
  (that was a startup crash), and granting them at run start is not what was
  wanted. Instead `mod_main.gd` **appends them to the character's
  `starting_weapons` weapon pool** — the same array the weapon-selection screen
  reads (`weapon_selection.gd`) — and unlocks them in `ProgressData`, but only
  when `ProgressData.is_dlc_available_and_active("abyssal_terrors")` is true.
* **Diagnostics** — on startup the mod logs the text locales, the weapon-pool
  additions, and
  `status: in ItemService.characters=… hash=… unlocked=… pool_size=…`, so
  "character not in the list" issues can be diagnosed from `modloader.log`.

Tunable constants: `SLEEP_DELAY`, `DEEPSLEEP_TEXTURE_PATH` in
`extensions/player_aitato.gd`; `TEXT`, `TEXT_LOCALE_ALIASES` and
`DLC_POOL_WEAPONS` in `mod_main.gd`; the numbers themselves in the `value` field
of the effect `.tres` files.

---

## Updating the art

`素材/` is the art source; the mod carries its own copies at **96×96**.

1. **The art must be 96×96.** No scaling is applied anywhere. Vanilla creates
   appearance sprites with no scaling, both in gameplay (`player.gd`) and in the
   character-selection preview (`character_panel_ui.gd`):

   ```gdscript
   var item_sprite = Sprite.new()
   item_sprite.texture = appearance.get_sprite()
   character_node.add_child(item_sprite)      # no scale applied
   ```

   and `ItemAppearanceData` has no `scale` field either, so **texture size is
   rendered size**. Resizing the textures to 96×96 is what makes both paths
   correct without any code.
2. **Both art files must be the same size and share the same framing.** The
   standing and sleeping art are swapped in place, so they must line up: both are
   authored with their content centred on the canvas (currently
   `bbox x[14..81] y[3..92]` for both, centre `(47.5, 47.5)`), which is what keeps
   the swap from jumping.
3. **Re-import, or the old art is served from the cache.** The `.stex` filename
   hash is derived from the *resource path*, not the pixel content, so replacing
   a PNG silently leaves a stale `.stex` behind. Recompile with Godot 3.6.2:

   ```
   <godot> --path <staging> --editor --quit
   ```
   where `<staging>` mirrors the real layout:
   ```
   <staging>/project.godot
   <staging>/mods-unpacked/Aitato-Aitato/contents/characters/deepseek/*.png(+.import)
   <staging>/.import/                      <- regenerated here
   ```
   `--editor --quit` runs Godot's resource scan and import on startup. Copy the
   existing `.import` companions in first; Godot then keeps the same
   `res://.import/<name>-<hash>.stex` targets and only refreshes the payload.
4. **Verify before shipping.** `build_zip.ps1` refuses to package unless every
   PNG is exactly 96×96 and every `.stex` is newer than its PNG. To eyeball the
   actual compiled pixels, `verify_art.gd` loads them back and saves PNGs.

---

## Requirements

* Brotato **1.1.15.4**
* **Brotato ModLoader** 6.x
* **Darkly77-ContentLoader** (recommended — used to register the content; the mod
  falls back to manual `ItemService` registration if it is missing)

---

## Packaging notes (learned the hard way)

1. **The zip root must be `mods-unpacked/`.** The ModLoader validates a zip by
   calling `ProjectSettings.load_resource_pack()` and then checking whether a
   *new* directory appeared under `res://mods-unpacked/`. A zip rooted at
   `Aitato-Aitato/` therefore loads with `SUCCESS ... loaded` and then logs
   `does not have the correct file structure` (or, worse, silently registers
   nothing). Layout that works:
   ```
   mods-unpacked/Aitato-Aitato/manifest.json
   mods-unpacked/Aitato-Aitato/...
   .import/*.stex                 <- at the ZIP ROOT, not inside the mod folder
   ```
2. **The `.import/` cache belongs at the zip root**, because the `.import` files
   reference `res://.import/...`, which is *outside* the mod directory. Inside
   the mod folder it is invisible to the engine and every texture fails with
   `Unable to open file: res://.import/<name>.stex`.
3. **Folder name must be `{namespace}-{name}`** (`Aitato-Aitato`), matching
   `manifest.json`. The loader rejects anything else outright.
4. **Never reference DLC resources** (`res://dlcs/dlc_1/...`) from a `.tres`.
   If the DLC is not active the resource fails to parse and the character cannot
   be loaded at all — this was the cause of a startup crash. Spoon and Brick
   are both DLC weapons.
5. **Never reference another mod's resources** — that mod may not be installed.
6. **Zip paths must use forward slashes.** PowerShell's `Compress-Archive`
   writes `\` separators, which Godot's `load_resource_pack` refuses. Build the
   archive with `System.IO.Compression.ZipArchive` instead (see
   `../build_zip.ps1`).
7. **Textures must ship as compiled `.stex`** plus their `.import`/`.md5`
   companions. Re-import after changing any PNG, or the old texture is served
   from the cache.
8. **Never write UTF-8 BOMs** into `.gd`/`.tres` files. PowerShell's
   `Set-Content -Encoding UTF8` adds one and Godot fails with
   `Parse Error: Expected '['`.
9. **Do not rely on compiled CSV translations for custom keys.**
   `csv_translation` produces a `PHashTranslation`, whose perfect-hash table
   collides for some key sets; a colliding key silently resolves to its own raw
   key text, so the UI shows the key instead of the text. Register text at
   runtime with `Translation.new()` + `add_message()` — and prefer vanilla
   `text_key`s (`effect_starting_item`) and stat keys (`stat_elemental_damage`)
   wherever the game already has the string.
