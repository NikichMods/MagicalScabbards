# SPDX-License-Identifier: MPL-2.0
"""Offline Lua 5.4 syntax and deterministic catalogue policy for VFX viewer.
Does not claim the UMG/particle host actually works in Steam 1.09.
"""
from pathlib import Path
from lupa import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "research" / "vfx-browser-01" / "Scripts"
lua = LuaRuntime(unpack_returned_tuples=True)

# Compile only: the host-bound main script must not run outside UE4SS.
for file in (BASE / "main.lua", BASE / "catalog.lua"):
    result = lua.globals().load(file.read_text(encoding="utf-8"), f"@{file.name}")
    if isinstance(result, tuple):
        raise AssertionError(f"Lua 5.4 compile failure for {file.name}: {result!r}")
    assert callable(result), f"no callable Lua chunk: {file.name}"

# Three individual keys: F7 next, F6 previous, F9 repeat; no Ctrl/Alt chords.
main_text = (BASE / "main.lua").read_text(encoding="utf-8")
assert 'local KEYS = {{Key.F6,"PREVIOUS"},{Key.F7,"NEXT"},{Key.F9,"REPLAY"}}' in main_text
assert 'action=="NEXT" and 1 or action=="PREVIOUS" and -1 or 0' in main_text
assert "selectCandidate(pair[2])" in main_text
assert "RegisterKeyBind(pair[1]" in main_text
assert "IsKeyBindRegistered(pair[1])" in main_text
assert "preview(step)" in main_text
assert "Key.F5" not in main_text
assert "ModifierKey." not in main_text
assert "RegisterKeyBind(" in main_text and main_text.count("RegisterKeyBind(") == 1
# A zero step in preview must preserve the currently selected index for replay.
assert "elseif step~=0 then" in main_text
assert "selected=((selected-1+step) % #entries)+1" in main_text

catalog = lua.execute((BASE / "catalog.lua").read_text(encoding="utf-8"))
build = catalog["build"]

def rows(values=(), limit=20):
    return build(lua.table_from(list(values)), limit)

a = rows()
assert len(a) == 6, len(a)
assert len(set(a[i]["path"] for i in range(1, len(a) + 1))) == 6
assert "throw_spark_astral" in a[1]["path"]
assert "astral_missile_shoot" in a[6]["path"]
assert all(a[i]["origin"] != "loaded" for i in range(1, 7))

prefix = "/Game/MainContent/Assets/fx/bp/anything/"
dyn = [f"{prefix}spark_{i:02d}.spark_{i:02d}" for i in reversed(range(30))]
dyn += [f"{prefix}spark_05.spark_05", f"{prefix}twinkle_cloud.twinkle_cloud"]
dyn += ["/Game/OtherContent/Assets/fx/spark_01.spark_01", f"{prefix}splash_splash.splash_splash"]
b = rows(dyn)
assert len(b) == 20
assert len(set(b[i]["path"] for i in range(1, 21))) == 20
assert b[7]["path"].endswith("spark_00.spark_00"), b[7]["path"]
assert b[20]["path"].endswith("spark_13.spark_13"), b[20]["path"]
assert all(b[i]["origin"] == "loaded" for i in range(7, 21))
assert not any("OtherContent" in b[i]["path"] for i in range(1, 21))

assert len(rows([], 2)) == 2
for bad in (0, 21, -1):
    try:
        rows([], bad)
        raise AssertionError(f"bad cap {bad} accepted")
    except AssertionError as e:
        if "accepted" in str(e):
            raise
    except Exception:
        pass

print("VFX_BROWSER_POLICY_PASS: lua syntax, seeds, bounded sorted dynamic scan, exact prefix and cap")
