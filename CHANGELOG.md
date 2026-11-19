# Changelog

## 0.1.0 — 2026-11-19

First stable release of MagicalScabbards for Asterigos: Curse of the Stars.

- Hide Hilda's confirmed stowed scabbard set after 3 seconds.
- Restore normal visibility at the start of weapon draw, during transitions, and when the mod is disabled.
- Support the six weapon families in the verified equipment combinations, including bracers equipped alongside other weapons.
- Automatic UE4SS startup with optional `Ctrl+Alt+F8` stop/restart.
- Scoped component ownership, foreign-writer protection, rollback, and safe handling of equipment changes and map loads.
- Readable logs, exact source identity, reproducible source-only ZIP, and SHA-256 checksums.

Based on the game-tested `0.1.0-test.1` candidate. The stable source differs in version metadata, release documentation and packaging only; there are no changes to weapon visibility mechanics.

**Limitations:** No magic VFX yet; hot Lua reload is unsupported; compatibility is only verified on the documented game/UE4SS build. An isolated process-shutdown cleanup warning has not been fully explained. No F8 action is required for routine game exit.
