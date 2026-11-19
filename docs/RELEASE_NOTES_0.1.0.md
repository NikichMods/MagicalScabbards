# MagicalScabbards 0.1.0 — First stable release

MagicalScabbards makes Hilda's scabbards disappear when her weapons are put away and restores them when she draws a weapon. Weapons in her hands and the bracers on her wrists remain visible.

- Hide after 3 seconds of confirmed stowed state
- Automatic startup with UE4SS
- Tested with all six weapon families in representative equipment combinations
- Safe restoration on weapon draw, map reload, and optional Ctrl+Alt+F8 stop/restart
- Original game meshes; no save-file changes

**Supported test environment:** Asterigos Steam 1.09 / build 12996889, Windows x64, UE4SS v3.0.1-1181-g83330635.

**Install:** Download `MagicalScabbards-0.1.0.zip` below and extract it into the UE4SS `Mods` directory. It should create `Mods/MagicalScabbards/Scripts/main.lua`. Disable any older MagicalScabbards copy first. The mod starts automatically; you do not need to press F8 before exiting the game.

**Known limits:** Changing weapons in the menu and using bracers may temporarily show the scabbards again. No magic VFX yet. Hot Lua reload is not supported. A single cleanup warning was observed close to process shutdown in one test, while normal in-game behavior and explicit stop/restart/stop passed. Please report repeatable in-game issues with your UE4SS log.

The source code is available under MPL-2.0. The ZIP contains no game assets or bundled UE4SS. The `.zip.sha256` and `.manifest.json` assets identify the exact released package.
