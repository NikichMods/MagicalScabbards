# SPDX-License-Identifier: MPL-2.0
"""Run frozen Lua 5.4 evidence and the current entry point in separate VMs."""
import os
from pathlib import Path

from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
LEGACY = ROOT / "research/scabbard-reconcile-bracer-03/test_write.lua"


def run(source, cwd):
    os.chdir(cwd)
    lua = LuaRuntime()
    assert lua.eval('_VERSION') == "Lua 5.4"
    lua.execute(source)
    return lua


def adapted_source():
    # Reuse the complete accepted Bracer 03 suite without changing its frozen files.
    # Only adapt activation to autostart/F8 and enable diagnostic assertions.
    source = LEGACY.read_text(encoding="utf-8")
    source = source.replace("local function fixture()", "local function fixture(options)\n    options = options or {}", 1)
    source = source.replace(
        "    anim.GetDoingSkill = function() return none end\n    anim.GetToDoSkill = anim.GetDoingSkill",
        """    anim.GetDoingSkill = function() return {ToString=function() return s.doing or "None" end} end
    anim.GetToDoSkill = function() return {ToString=function() return s.pendingSkill or "None" end} end""",
        1,
    )
    old = '    dofile("Scripts/main.lua")\n    s.keys[7]()'
    new = '''    if options.setup then options.setup(s) end
    local file = assert(io.open("Scripts/main.lua", "r"))
    local source = file:read("a"); file:close()
    if not options.quiet then
        local count
        source, count = source:gsub("local DEBUG_LOGGING = false", "local DEBUG_LOGGING = true")
        assert(count == 1)
    end
    assert(load(source, "@Scripts/main.lua"))()'''
    assert source.count(old) == 1
    source = source.replace(old, new)
    assert source.count('s.keys[7](); stale()') == 1
    return source.replace('s.keys[7](); stale()', 's.keys[8](); stale()')


if __name__ == "__main__":
    for directory, names in [
        ("scabbard-state-reconcile-01", ["test.lua", "test_observer.lua"]),
        ("scabbard-reconcile-boundary-01", ["test_outgoing.lua"]),
        ("scabbard-reconcile-write-01", ["test_write.lua"]),
        ("scabbard-reconcile-write-02", ["test_write.lua"]),
        ("scabbard-reconcile-universal-01", ["test_write.lua"]),
        ("scabbard-reconcile-bracer-01", ["test_write.lua"]),
        ("scabbard-reconcile-bracer-02", ["test_write.lua"]),
        ("scabbard-reconcile-bracer-03", ["test_write.lua"]),
    ]:
        cwd = ROOT / "research" / directory
        for name in names:
            run((cwd / name).read_text(encoding="utf-8"), cwd)
    source = adapted_source()
    run(source, ROOT)
    os.chdir(ROOT)
    lua = LuaRuntime()
    lua.globals().fixture = lua.execute(source.split("\nlocal s = fixture()", 1)[0] + "\nreturn fixture")
    lua.execute((ROOT / "tests/test_runtime.lua").read_text(encoding="utf-8"))
    print("PASS: frozen suites + current entry-point regression + lifecycle/diagnostics (Lua 5.4)")
