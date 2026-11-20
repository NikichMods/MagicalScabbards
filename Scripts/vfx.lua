-- SPDX-License-Identifier: MPL-2.0
local equipment = require("equipment")
local ASSET = "/Game/MainContent/Assets/fx/bp/skill/hilda/_staff/private/astral_missile_shoot.astral_missile_shoot"
local PSC = "Class /Script/Engine.ParticleSystemComponent"
local owned, sessionFault, reportedMiss
local alive, spawn

local function log(event, detail)
    print(("[MagicalScabbards VFX] %s %s\n"):format(event, detail))
end

local function same(a, b)
    local id = equipment.id(a)
    return id ~= "-" and id == equipment.id(b)
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
    local asset = StaticFindObject(ASSET)
    if equipment.name(asset) ~= "ParticleSystem " .. ASSET then
        if not reportedMiss then log("MISS", "Astral staff asset is not resident") end
        reportedMiss = true
        return
    end
    alive = alive or static("KismetSystemLibrary", "IsValid")
    assert(alive(snapshot.pawn) and alive(snapshot.mesh) and alive(asset), "invalid attachment context")
    local socket = FName("scabbard_b", EFindName.FNAME_Find)
    local fade = FName("Fade", EFindName.FNAME_Find)
    assert(socket:ToString() == "scabbard_b" and snapshot.mesh:DoesSocketExist(socket)
        and fade:ToString() == "Fade", "socket or parameter unavailable")
    spawn = spawn or static("GameplayStatics", "SpawnEmitterAttached")
    local c = spawn(asset, snapshot.mesh, socket, {X=0,Y=0,Z=0}, {Pitch=0,Yaw=0,Roll=0},
        {X=0.7,Y=0.7,Z=0.7}, 0, true, 0, false)
    assert(alive(c) and equipment.name(c:GetClass()) == PSC, "spawn result unverified")
    local ref = {path=assert(equipment.name(c):match("^[^ ]+ (.+)$")), id=equipment.id(c),
        pawn=equipment.id(snapshot.pawn)}
    owned = ref
    assert(same(c.Template, asset) and same(c:GetAttachParent(), snapshot.mesh)
        and c:GetAttachSocketName():ToString() == "scabbard_b", "spawn attachment mismatch")
    local handle = ExecuteInGameThreadWithDelay(1600, function()
        if owned == ref then cleanup("watchdog") end
    end)
    assert(math.type(handle) == "integer" and IsValidDelayedActionHandle(handle), "watchdog unavailable")
    c:SetFloatParameter(fade, 0.45)
    local params, found = c.InstanceParameters, false
    local count = params:GetArrayNum()
    for i = 1, count do
        assert(i <= params:GetArrayNum(), "instance parameter array changed")
        local row = params[i]
        if row.Name:ToString() == "Fade" then found = math.abs(row.Scalar - 0.45) < 0.0001; break end
    end
    assert(found, "Fade instance readback failed")
    c:Activate(false)
    log("ACTIVATED", ("stowed_ms=%.1f socket=scabbard_b fade=0.45 scale=0.70"):format(elapsed))
end

return {
    preview = function(snapshot, elapsed)
        if sessionFault or owned or (snapshot.kinds[1] ~= 4 and snapshot.kinds[2] ~= 4) then return end
        local ok, err = pcall(play, snapshot, elapsed)
        if not ok then
            sessionFault = true
            log("FAILED", tostring(err))
            cleanup("error")
        end
    end,
    cleanup = cleanup,
    endPlay = function(key)
        if owned and owned.pawn == key then cleanup("pawn-end-play") end
    end,
}
