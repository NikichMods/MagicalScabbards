# MagicalScabbards 0.1.1

- Blue sparks play just before Hilda's scabbards disappear with a supported stowed weapon loadout.
- A normal roll keeps hidden scabbards hidden while the weapons stay stowed. Drawing a weapon restores the scabbards.
- Recognized item actions, including potions, locator stones, Glimmer and elemental enhancements, preserve hidden scabbards while the weapons stay stowed.
- A brief game-thread stall can leave already-hidden scabbards hidden when the same stowed equipment is confirmed after the pause.
- Scabbards still hide after three seconds of confirmed stowed state. The sparks use an existing Asterigos effect. The package contains Lua source and documentation.

**Target environment:** Asterigos Steam 1.09 / build 12996889, Windows x64, UE4SS v3.0.1-1181-g83330635.

**Install:** Close the game and extract `MagicalScabbards-0.1.1.zip` into the UE4SS `Mods` directory. The package creates `Mods/MagicalScabbards/Scripts/main.lua`. Replace the previous MagicalScabbards installation and keep one active copy. The mod starts automatically. `Ctrl+Alt+F8` is optional for stopping and restarting the mod during play.

**Known limits:** Scabbards can briefly return when swapping weapons in the menu or when a skill draws a weapon. Cosmetic playback can be skipped if the effect is unavailable. A cleanup warning can occur during game exit. Hot Lua reload is unsupported.

The source is licensed under MPL-2.0. The accompanying checksum and manifest identify the exact release package.
