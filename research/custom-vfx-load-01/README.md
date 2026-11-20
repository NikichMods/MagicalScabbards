# Custom VFX asset-load probe 01 — research only

**Status:** SOURCE PREPARED, **NO GAME PASS**, **NO COOKED ASSET BUILT**, **NOT INSTALLED**. Do not publish as a test/release version. Target is the user's installed Asterigos Steam 1.09 (build 12996889), Windows x64, UE4.27, UE4SS 3.0.1-1181-g83330635.

**Goal:** distinguish three independent facts: (a) stock cooked object can be opened by `LoadAsset`, (b) newly authored asset is mounted at a separate unique package path, and (c) UE4SS can open it. A positive control alone does not prove (b)/(c). A negative result does not by itself identify whether cooking, package path, mount, engine-version compatibility, IoStore, or load timing failed.

## Evidence and package format

- The installed game uses **IoStore**: `Genesis/Content/Paks/pakchunk0-WindowsNoEditor.utoc/.ucas`. The historically analyzed No Scabbard distribution also uses `pakchunk95-WindowsNoEditor_P.pak/.utoc/.ucas` (no third-party bytes copied). See [docs/NO_SCABBARD_REFERENCE.md](../../docs/NO_SCABBARD_REFERENCE.md).
- Stock asset-loading is a separate question from mounting a new asset. UE4SS declares `LoadAsset(path)` **game-thread only**. Engine UE4.27 cooking should target the installed platform.
- UE4SS `BPModLoaderMod` has a known `LogicMods` .pak pipeline, but it does not by itself prove mounting of this game's custom IoStore trio. Investigate the actual loaded modules and supported mounting before selecting the packaging route. **Do not change the EXE, enable arbitrary native loaders, overwrite stock paths or bypass encrypted files automatically.**
- Asterigos has previously installed asset-replacement packages; these demonstrate historical override packaging, **not** loading new uniquely named Niagara assets into the running game.

## Minimal custom fixture

1. Verify if a licensed **UE4.27 Editor** and the applicable cooking/IoStore tools are available locally. Recover exact installed game/tool versions; do not download Unreal Editor or replace the game EXE without a reason and permission.
2. In a throwaway locally owned editor project, author **one minimal, self-contained asset** named `NS_VFX_LoadProbe` under `Content/NikichMods/MagicalScabbards/VFX/`. Prefer Niagara (one small burst, one simple sprite, no light or external assets) if its cooking/plugin prerequisites are satisfied. This stage tests **loading, not appearance**, so it needs neither 30 particles nor special color.
3. Cook for Windows with the actual UE4.27 toolchain. Check exact package/mount point against `/Game/NikichMods/MagicalScabbards/VFX/NS_VFX_LoadProbe.NS_VFX_LoadProbe`. Stage it using a **proven** discovery/mount mechanism for the target game's IoStore environment. Keep binary/cooked outputs outside Git and preserve their SHA-256 in a local report. If packaging/mounting remains unproven, stop here and report the missing fact rather than guessing.
4. With the game fully closed, stage only the independent research mod in `Mods/MSVfxLoadProbe01/Scripts/main.lua` with `Mods/MSVfxLoadProbe01/enabled.txt`. Preserve the stable MagicalScabbards installation and other mods. Audit `Ctrl+Alt+F6` conflicts before installation; the script refuses to override a registered binding. The probe **does not automatically execute** its load test.
5. Launch game normally, enter controllable gameplay, press **Ctrl+Alt+F6 once**. Read exact `[MSVfxLoadProbe01]` lines in UE4SS log: `CONTROL_FOUND` should identify stock `astral_missile_shoot`, `CUSTOM_FOUND` should identify the unique fixture. `CUSTOM_MISS` is **not** proof of an incompatible UE4SS API until mounting is independently confirmed. No particle is spawned or scabbard modified.
6. Close the game. Remove research probe and any mounted test fixture from active game paths. Confirm ordinary stable v0.1.0 still works if this test made any installation changes.

**Stop and preserve results** when both paths are checked, an unexpected error occurs, or the custom cooked source cannot be built/mounted safely. No repeated polls, no brute-force asset discovery, no automatic retries. Record fixture path, file/sha256, mount log, result and exact host build. Do not commit or share proprietary game assets, binary toolchain, machine paths or private logs.

## Interpretation

| Observed result | Conclusion |
| --- | --- |
| CONTROL_FOUND, CUSTOM_FOUND | Proof the unique authored asset is accessible through UE4SS under the given package path, **not yet proof that SpawnSystemAttached renders or cleans up** |
| CONTROL_FOUND, CUSTOM_MISS | Stock LoadAsset works. Custom mount/path/cook/runtime identity still unknown; inspect mount evidence |
| CONTROL_MISS, CUSTOM_MISS | Diagnose a stock reference / timing / LoadAsset invocation before attributing failure to custom packaging |
| *_ERROR / INIT_FAILED | Targeted API or runtime failure; stop and inspect the exact error |
| Custom fixture cannot be cooked/mounted | BLOCKED at delivery, not a VFX failure; avoid modifying production |

**Next gate after a true CUSTOM_FOUND:** a separate narrow research-only spawn/attachment/lifetime test, then one production VFX candidate for disappearance only. No gameplay-modification code belongs in this probe.
