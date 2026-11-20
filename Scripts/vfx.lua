-- SPDX-License-Identifier: MPL-2.0
local equipment = require("equipment")
local ASSET = "/Game/MainContent/Assets/fx/bp/skill/hilda_ult/_stf01/private/stf01_spark.stf01_spark"
local PSC = "Class /Script/Engine.ParticleSystemComponent"
-- Accepted test.3 appearance; fixed for all confirmed stowed weapon combinations.
local SCALE, RATE, CUTOFF_MS = 0.60, 0.5, 1500
local owned, sessionFault, reportedMiss, loadAttempted
local alive, spawn

local function log(event, detail)
    print(("[MagicalScabbards VFX] %s %s\n"):format(event, detail))
end

local function same(a, b)
    local id = equipment.id(a)
    return id ~= "-" and id == equipment.id(b)
end

-- Only a single exact stock asset; errors cannot block scabbard hiding.
-- LoadAsset is synchronous: try at most once per session/map if not resident.
local function getAsset()
    local asset = StaticFindObject(ASSET)
    if equipment.name(asset) == "ParticleSystem " .. ASSET then return asset end
    if not loadAttempted then
        loadAttempted = true
        if type(LoadAsset) == "function" then
            local ok, loaded = pcall(LoadAsset, ASSET)
            if ok and equipment.name(loaded) == "ParticleSystem " .. ASSET then
                log("ASSET_LOADED", "exact stock stf01_spark")
                return loaded
            end
        end
    end
end

local function static(class, method)
    local base = "/Script/Engine."
    local path = base .. class .. ":" .. method
    local fn = StaticFindObject(path)
    local cdo = StaticFindObject(base .. "Default__" .. class)
    assert(equipment.name(fn) == "Function " .. path and (fn:GetFunctionFlags() & 0x400) ~= 0
        and equipment.name(cdo) == class .. " " .. base .. "Default__" .. class, path)
    return function(...) return fn(cdo, ...) end
end

local function cleanup(reason)
    if not owned then return end
    local ok, result = pcall(function()
        local c = StaticFindObject(owned.path)
        if equipment.id(c) ~= owned.id or not alive(c) then return "ALREADY_GONE" end
        assert(equipment.name(c:GetClass()) == PSC, "component class changed")
        c:K2_DestroyComponent(c)
        assert(not alive(c), "destruction not confirmed")
        return "DESTROYED"
    end)
    if ok then
        owned = nil
        log(result, "reason=" .. reason)
    else
        sessionFault = true
        log("CLEANUP_PENDING", reason .. " " .. tostring(result))
    end
end

local function play(snapshot, elapsed)
    local asset = getAsset()
    if not asset then
        if not reportedMiss then log("MISS", "stf01_spark is not resident") end
        reportedMiss = true
        return
    end
    alive = alive or static("KismetSystemLibrary", "IsValid")
    assert(alive(snapshot.pawn) and alive(snapshot.mesh) and alive(asset), "invalid attachment context")
    local socket = FName("scabbard_b", EFindName.FNAME_Find)
    assert(socket:ToString() == "scabbard_b" and snapshot.mesh:DoesSocketExist(socket), "socket unavailable")
    spawn = spawn or static("GameplayStatics", "SpawnEmitterAttached")
    local c = spawn(asset, snapshot.mesh, socket, {X=0,Y=0,Z=0}, {Pitch=0,Yaw=0,Roll=0},
        {X=SCALE,Y=SCALE,Z=SCALE}, 0, true, 0, false)
    assert(alive(c) and equipment.name(c:GetClass()) == PSC, "spawn result unverified")
    local ref = {path=assert(equipment.name(c):match("^[^ ]+ (.+)$")), id=equipment.id(c),
        pawn=equipment.id(snapshot.pawn)}
    owned = ref
    assert(same(c.Template, asset) and same(c:GetAttachParent(), snapshot.mesh)
        and c:GetAttachSocketName():ToString() == "scabbard_b", "spawn attachment mismatch")
    local handle = ExecuteInGameThreadWithDelay(CUTOFF_MS, function()
        if owned == ref then cleanup("watchdog") end
    end)
    assert(math.type(handle) == "integer" and IsValidDelayedActionHandle(handle), "watchdog unavailable")
    assert(type(c.CustomTimeDilation) == "number", "PSC CustomTimeDilation unavailable")
    c.CustomTimeDilation = RATE
    assert(math.abs(c.CustomTimeDilation - RATE) < 0.0001, "PSC CustomTimeDilation readback failed")
    c:Activate(false)
    log("ACTIVATED", ("stowed_ms=%.1f asset=stf01_spark socket=scabbard_b scale=%.2f rate=%.1f cutoff_ms=%d")
        :format(elapsed, SCALE, RATE, CUTOFF_MS))
end

return {
    preview = function(snapshot, elapsed)
        if sessionFault or owned then return end
        local ok, err = pcall(play, snapshot, elapsed)
        if not ok then
            sessionFault = true
            log("FAILED", tostring(err))
            cleanup("error")
        end
    end,
    cleanup = cleanup,
    reset = function(reason)
        cleanup(reason)
        loadAttempted, reportedMiss = nil, nil
    end,
    endPlay = function(key)
        if owned and owned.pawn == key then cleanup("pawn-end-play") end
    end,
}
