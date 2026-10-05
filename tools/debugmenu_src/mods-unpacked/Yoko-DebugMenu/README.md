<div align="center">

# Yoko-DebugMenu

**An in-game debugging toolkit for Brotato mod development and testing.**

[![Latest Release](https://img.shields.io/github/v/release/CYoJkoY/Yoko-DebugMenu?display_name=tag&sort=semver&style=flat-square)](https://github.com/CYoJkoY/Yoko-DebugMenu/releases)
[![Build](https://img.shields.io/github/actions/workflow/status/CYoJkoY/Yoko-DebugMenu/release.yml?style=flat-square&label=build)](https://github.com/CYoJkoY/Yoko-DebugMenu/actions/workflows/release.yml)
[![Mod Loader](https://img.shields.io/badge/Mod%20Loader-6.3.0-5965FF?style=flat-square)](#compatibility)
[![Godot](https://img.shields.io/badge/Godot-3.x-478CBF?style=flat-square&logo=godot-engine&logoColor=white)](https://godotengine.org/)
[![License](https://img.shields.io/github/license/CYoJkoY/Yoko-DebugMenu?style=flat-square)](LICENSE)

[Features](#features) · [Installation](#installation) · [Usage](#usage) · [Architecture](#architecture) · [Development](#development)

</div>

---

## What it is

Yoko-DebugMenu adds a dedicated in-game debug interface to Brotato without requiring changes to the base game files. It is designed for rapid iteration: manipulate player state, equipment, enemies, waves, and progression from one panel while testing mods.

The repository is a **Brotato Mod Loader** project written in GDScript. The mod extends the game's existing debug service instead of creating a separate gameplay loop.

## Features

| Area | Tools |
| :--- | :--- |
| **Player** | Give/remove items, weapons, and upgrades; add materials; randomize equipment; toggle invulnerability and invisibility; remove starting weapons |
| **Combat** | Enable one-shot enemies and slow motion for targeted testing |
| **Progression** | Unlock or relock progression entries for repeatable test runs |
| **Enemies & Waves** | Browse registered enemy entities and test vanilla or compatible modded encounters |
| **Input** | Open the menu with `T` or the configured player-1 left/right trigger combination |

Text-entry fields are respected, so the keyboard shortcut does not interfere with `LineEdit` or `TextEdit` input.

## Installation

Download the latest `DebugMenu-*.zip` from [Releases](https://github.com/CYoJkoY/Yoko-DebugMenu/releases) and place the ZIP in Brotato's Mod Loader `mods` directory.

Keep the release ZIP compressed for normal installation.

For source development, the expected mod layout is:

```text
mods-unpacked/
└── Yoko-DebugMenu/
    ├── content/
    ├── extensions/
    ├── manifest.json
    └── mod_main.gd
```

See the [Godot Mod Loader documentation](https://wiki.godotmodding.com/) for current installation conventions.

## Usage

1. Launch Brotato with Mod Loader enabled.
2. Enter a scene where the debug service is available.
3. Press `T`, or use the supported trigger combination on player 1.
4. Switch between the available debug tabs.
5. Close the panel when testing is complete.

## Architecture

The implementation is deliberately narrow:

```text
Brotato debug service
        │
        ▼
extensions/debug_service.gd
        │
        ▼
Yoko-DebugMenu
        │
        ├── Player tools
        ├── Enemy tools
        └── Wave / progression tools
```

`mod_main.gd` installs the extension for `res://singletons/debug_service.gd`. The custom debug interface lives under `content/`, so the UI can be edited as ordinary Godot content while the extension layer handles integration with Brotato.

```text
content/
└── scenes/
    ├── debug_menu.gd
    └── debug_menu.tscn

extensions/
└── debug_service.gd
```

## Development

The project uses the Godot 3.x Mod Loader extension model.

When changing the debug panel, keep UI concerns in `content/` and game-system integration in `extensions/`. New debug actions should target the narrowest appropriate game service so they remain isolated and easier to test.

Releases are built from semantic version tags. The release workflow requires the tag and `manifest.json` to agree exactly:

```text
manifest.json: 1.1.0
        │
        ├── tag v1.1.0  → build allowed
        └── tag v1.2.0  → build rejected
```

The workflow also imports Godot resources, creates the Mod Loader package, preserves generated `.import` data, verifies ZIP contents, and checks the packaged manifest before publishing the release.

## Compatibility

| Component | Declared target |
| :--- | :--- |
| Engine | Godot 3.x / GDScript |
| Mod Loader | **6.3.0** |
| Mod version | **1.1.0** |
| Brotato game version | **1.15.4** |
| License | MIT |

The manifest is the source of truth for declared compatibility.

## Project structure

```text
Yoko-DebugMenu/
├── .github/workflows/release.yml
├── content/
│   └── scenes/
├── extensions/
├── manifest.json
├── mod_main.gd
├── README.md
└── LICENSE
```

## License

This project is licensed under the [MIT License](LICENSE).

## Support the Author

If this project saves you time while developing or testing Brotato mods, consider supporting its continued development.

<div align="center">
  <a href="https://cyojkoy.github.io/Payment/">
    <img src="https://img.shields.io/badge/Support_the_Author-9E8F7E?style=for-the-badge&logo=buy-me-a-coffee&logoColor=BEB8AE" alt="Support the Author">
  </a>
</div>

---

<div align="center">
  <sub>Yoko-DebugMenu · Brotato debugging tools by CYoJkoY</sub>
</div>
