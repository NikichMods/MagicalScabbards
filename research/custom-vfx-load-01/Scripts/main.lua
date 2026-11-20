-- SPDX-License-Identifier: MPL-2.0
-- Research-only asset-load test. NEVER spawns particles, mutates the game or touches scabbards.
-- Run only after local review, controlled installation and complete game restart.
local PREFIX = "[MSVfxLoadProbe01] "
local CONTROL = "/Game/MainContent/Assets/fx/bp/skill/hilda/_staff/private/astral_missile_shoot.astral_missile_shoot"
-- Must match the exact package created in the UE4.27 research cooking project.
local CUSTOM = "/Game/NikichMods/MagicalScabbards/VFX/NS_VFX_LoadProbe.NS_VFX_LoadProbe"
local done = false

local function log(event, detail)
    print(PREFIX .. event .. " " .. tostring(detail or "") .. "\n")
end

local function check(label, path)
    local ok, obj = pcall(LoadAsset, path)
    if not ok then
        log(label .. "_ERROR", tostring(obj))
        return
    end
    if not obj then
        log(label .. "_MISS", path)
        return
    end
    local valid, name = pcall(function()
        if not obj:IsValid() then return nil end
        return obj:GetFullName()
    end)
    if valid and name then
        log(label .. "_FOUND", name)
    else
        log(label .. "_UNVERIFIED", tostring(name))
    end
end

local function probe()
    if done then return end
    done = true
    log("BEGIN", "read-only; no particle spawn")
    check("CONTROL", CONTROL)
    check("CUSTOM", CUSTOM)
    log("COMPLETE", "compare FOUND/MISS before attempting any VFX spawning")
end

local ok, err = pcall(function()
    assert(EngineTickAvailable and EGameThreadMethod and EGameThreadMethod.EngineTick,
        "EngineTick game thread unavailable")
    assert(Key and Key.F6 and ModifierKey and ModifierKey.CONTROL and ModifierKey.ALT,
        "Ctrl+Alt+F6 unavailable")
    assert(type(LoadAsset) == "function" and type(RegisterKeyBind) == "function"
        and type(IsKeyBindRegistered) == "function" and type(ExecuteInGameThread) == "function",
        "required UE4SS functions unavailable")
    local modifiers = {ModifierKey.CONTROL, ModifierKey.ALT}
    assert(not IsKeyBindRegistered(Key.F6, modifiers), "Ctrl+Alt+F6 already registered")
    RegisterKeyBind(Key.F6, modifiers, function()
        ExecuteInGameThread(function()
            local worked, problem = pcall(probe)
            if not worked then log("PROBE_FAILED", tostring(problem)) end
        end, EGameThreadMethod.EngineTick)
    end)
    log("READY", "Ctrl+Alt+F6 after entering active gameplay")
end)
if not ok then log("INIT_FAILED", tostring(err)) end
