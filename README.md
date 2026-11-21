# MagicalScabbards

MagicalScabbards is a lightweight **Asterigos: Curse of the Stars** mod that hides Hilda's scabbards and weapons stored inside them when her weapons are put away.

The scabbards return when Hilda starts drawing a weapon. They remain visible while the weapon is drawn or being put away, then disappear after **3 seconds of confirmed stowed state**.

**Latest stable version:** 0.1.1 — [Download on GitHub Releases](https://github.com/NikichMods/MagicalScabbards/releases/latest).

## Features

- Works with sword and shield, cudgel, daggers, spear, staff, and bracers in the tested equipment combinations.
- Keeps weapons in Hilda's hands and her wrist bracers visible.
- Restores the game's normal scabbard visibility when a weapon is drawn, during equipment changes, and when the mod is disabled.
- Uses the game's existing meshes. No replacement game assets, save changes, or other mods are required beyond UE4SS.
- Plays blue sparks just before the scabbards disappear.
- Keeps hidden scabbards hidden during normal rolls and recognized item actions while the weapons stay stowed.
- Preserves existing hides across brief stalls when the next check confirms the same stowed equipment.

## Requirements

Verified with **Asterigos Steam 1.09 / build 12996889**, Windows x64, UE4.27, and **UE4SS v3.0.1-1181-g83330635**. Other game and UE4SS versions are not verified.

Install UE4SS separately. This mod does not include UE4SS, game assets, or assets from other mods. Do not use an asset-replacement mod that removes the original scabbard meshes if you expect MagicalScabbards to show them again.

## Installation

1. Close the game.
2. Download `MagicalScabbards-0.1.1.zip` from [Releases](https://github.com/NikichMods/MagicalScabbards/releases/tag/v0.1.1).
3. Extract it into your **UE4SS `Mods` folder**. The package creates `Mods/MagicalScabbards/Scripts/main.lua` with five other Lua files beside it.
4. Keep `Mods/MagicalScabbards/enabled.txt` in place for automatic startup.
5. Keep only one active MagicalScabbards installation.

MagicalScabbards starts automatically when the game loads. No hotkeys are needed for normal play.

**Optional control:** `Ctrl+Alt+F8` turns the mod off for the current game session and restores its own hidden components. Press it again to restart the mod and begin a new 3-second observation window. **You do not need to press F8 before quitting the game.** If a cleanup error is reported in the log, save the log before restarting.

**Permanent disable / uninstall:** Close the game, remove `enabled.txt` and disable any `MagicalScabbards : 1` entry in `mods.txt`, or remove the mod folder entirely. UE4SS checks both ways of enabling a mod. Do not replace or hot-reload Lua files while the game is running.

## Behavior and limitations

- Changing weapons in the menu may briefly show scabbards and restart the 3-second countdown. This is intentional.
- Using bracers may also trigger the ordinary show/hide cycle. The wrist meshes themselves are not hidden.
- Hot Lua unloading is not supported. Use F8 to disable the active session, or close the game to update files.
- A `CLEANUP_PENDING owner-ended` warning can occur at game exit. Its cause is unknown. Report any repeatable problem during play.

## Troubleshooting

The UE4SS log identifies the mod as `[MagicalScabbards 0.1.1]`. Look for `START`, `HIDDEN`, `RELEASED`, and `CLEANED`. Effects are logged under `[MagicalScabbards VFX]`. If a problem happens, include the game and UE4SS versions, equipped weapon types, steps, and relevant log in a [GitHub Issue](https://github.com/NikichMods/MagicalScabbards/issues).

The ZIP includes a `manifest.json` with the exact source commit and SHA-256 of the files. The matching checksums and manifest are also included as release assets. Do not install the archive one folder deeper than shown above.

## License and project

Original source code and accompanying documentation: **MPL-2.0**. See [LICENSE](LICENSE) and [LICENSING.md](LICENSING.md). Asterigos and other third-party content belong to their respective owners.

[Changelog](CHANGELOG.md) · [Release evidence](docs/RELEASE_0.1.1.md) · [Project status](docs/STATUS.md)
