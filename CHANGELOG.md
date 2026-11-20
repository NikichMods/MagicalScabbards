# Changelog

## 0.1.1-test.5 — development candidate, not released

- Preserve hidden scabbards across delayed observations when the current equipment is still stowed and the mask remains intact. New hides still require a continuous three-second observation window.

## 0.1.1-test.4 — development candidate, not released

- Added a single short Staff cast spark to every confirmed stowed scabbard disappearance, regardless of equipped weapon family (new game acceptance pending).
- Fixed scale 0.60, time rate 0.5, cleanup 1500 ms; stock particle light and other visual settings unchanged.
- Removed the research VFX Browser dependency and settings bridge.
- Added a bounded exact-asset load fallback for nonresident spark templates; cosmetic failure does not block normal hide/show.
- Updated exact-source candidate packaging to include the new `vfx.lua` module.

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
