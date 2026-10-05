# Aitato

**Version 0.0.1** 鈥?a Brotato mod that adds new characters and content.

First character: **DeepSeek / 澶ц偉楸?*.

---

## Character: DeepSeek (澶ц偉楸?

`character_aitato_deepseek`

DeepSeek is always tired. The moment she stops moving she falls asleep.

| | |
|---|---|
| **While sleeping** | HP Regeneration **+10**, but she **cannot attack** |
| **Charge bar** | Appears under her feet while asleep and fills over **1 second** |
| **When it fills** | **Critical Damage doubled** and **Armor doubled** for **10 seconds** |
| **Starting item** | **Scared Sausage** (瀹虫€曠殑棣欒偁) |

Moving again wakes her up and resets the bar. The charge bar and the buff timer
both reset at the end of every wave.

### In-game description lines

1. 鍋滄绉诲姩鍚庡紑濮嬬潯瑙夛細鐢熷懡鍐嶇敓 +10锛屼絾鏃犳硶鏀诲嚮銆?2. 鐫¤鏃惰剼涓嬩細鍑虹幇涓€涓厖鑳芥潯锛? 绉掓敀婊°€?3. 鏀掓弧鍚庤幏寰楁寔缁?10 绉掔殑鏆村嚮浼ゅ缈诲€嶅拰鎶ょ敳缈诲€嶃€?4. 寮€灞€鑷甫涓€涓鎬曠殑棣欒偁銆?
---

## Files

```
Aitato/
鈹溾攢鈹€ manifest.json                       # mod metadata (name, version 0.0.1, deps)
鈹溾攢鈹€ mod_main.gd                         # registers extensions, content and text
鈹溾攢鈹€ content_data/
鈹?  鈹斺攢鈹€ aitato_content_data.tres        # ContentLoader entry point
鈹溾攢鈹€ contents/
鈹?  鈹溾攢鈹€ characters/deepseek/
鈹?  鈹?  鈹溾攢鈹€ deepseek_data.tres          # CharacterData
鈹?  鈹?  鈹溾攢鈹€ deepseek_appearance.tres    # ItemAppearanceData (body art)
鈹?  鈹?  鈹溾攢鈹€ deepseek.png                # 96x96 character art  (from 绱犳潗/)
鈹?  鈹?  鈹溾攢鈹€ deepseek_icon.png           # selection-screen icon
鈹?  鈹?  鈹溾攢鈹€ deepsleep.png               # 96x96 sleeping art  (from 绱犳潗/)
鈹?  鈹?  鈹斺攢鈹€ effects/                    # deepseek_effect_0..4.tres
鈹?  鈹斺攢鈹€ items/scared_sausage/
鈹?      鈹溾攢鈹€ scared_sausage_data.tres    # "Scared Sausage" ItemData
鈹?      鈹斺攢鈹€ scared_sausage_icon.png
鈹斺攢鈹€ extensions/
    鈹溾攢鈹€ player_aitato.gd                # sleep state, charge bar, buff, art swap
    鈹斺攢鈹€ weapon_aitato.gd                # block attacks while asleep
```

The sleeping texture is deliberately named **`deepsleep.png`**.

---

## How it works (implementation notes)

* **Sleep detection** 鈥?`player_aitato.gd` extends
  `res://entities/units/player/player.gd` and watches `_current_movement` in
  `_physics_process()`. After 0.15 s of no movement the player is "asleep".
* **+10 HP Regeneration** 鈥?the vanilla `temp_stats_while_not_moving` effect on
  the character data handles this; vanilla already applies and removes it as the
  player starts/stops moving (`Player.check_not_moving_stats()`).
* **Cannot attack** 鈥?`weapon_aitato.gd` extends `res://weapon.gd` and returns
  `false` from `should_shoot()` while the owner is asleep. Brotato has no
  built-in "disable attacks" flag, so this is the supported hook.
* **Sleeping art** 鈥?`deepsleep.png` is added as a `Sprite` child of the
  player's `Animation/Sprite` node and shown only while asleep; the character's
  normal body art (an `ItemAppearanceData`) is hidden meanwhile.
* **Charge bar** 鈥?a small `Node2D` (background + fill sprites using a generated
  1x1 white texture) parented next to the body sprite so it tracks the player but
  does not inherit the sprite's left/right mirroring. It fills over
  `CHARGE_DURATION` (1.0 s) and turns cyan when full.
* **Doubled Armor** 鈥?`TempStats.add_stat(Keys.stat_armor_hash, current_armor, 鈥?`
  while the buff lasts (removed when it ends).
* **Doubled Critical Damage** 鈥?weapon crit damage is a plain multiplier copied
  off the weapon resource at init time and never touched by any player stat, so
  the weapon's live `current_stats.crit_damage` and its hitbox are doubled
  directly. The original value is remembered in the weapon's metadata and
  re-applied by `weapon_aitato.gd::init_stats()` after every stat recalculation.
* **Text** 鈥?English and Chinese strings are registered at runtime
  (`TranslationServer.add_translation`), so no pre-compiled `.translation`
  resources are required.

Tunable constants live at the top of `extensions/player_aitato.gd`:
`CHARGE_DURATION`, `BUFF_DURATION`, `SLEEP_DELAY`, `BAR_*`.

---

## Requirements

* Brotato **1.1.15.4**
* **Brotato ModLoader** 6.x
* **Darkly77-ContentLoader** (recommended 鈥?used to register the content; the mod
  falls back to manual `ItemService` registration if it is missing)

## Installation

Use the same route as the other mods in your setup (e.g. the Steam Workshop or
your mod manager). The archive is laid out like every other mod:

```
Aitato.zip
鈹斺攢鈹€ mods-unpacked/
    鈹斺攢鈹€ Aitato/
        鈹溾攢鈹€ manifest.json
        鈹斺攢鈹€ ...
```

The unpacked folder is also provided at `mods-unpacked/Aitato-Aitato/` for setups that
read an unpacked mods directory directly.
