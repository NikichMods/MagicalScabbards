-- SPDX-License-Identifier: MPL-2.0
local ASSET = "/Game/MainContent/Assets/fx/bp/skill/hilda/_staff/private/astral_missile_shoot.astral_missile_shoot"
local HILDA = "BlueprintGeneratedClass /Game/MainContent/Act/Character_BP/hilda_BP.hilda_BP_C"
local PSC = "Class /Script/Engine.ParticleSystemComponent"
local FADE, SCALE, TIMEOUT_MS = 0.45, 0.7, 1600
local owned, queued, attempted, armed, loading
local alive

local function log(event, detail)
    print(("[MSStockVfxFade01] %s %s\n"):format(event, detail or ""))
end

local function valid(o) return o ~= nil and o:IsValid() end
local function name(o) return valid(o) and o:GetFullName() or nil end
local function same(a, b)
    return valid(a) and valid(b) and a:GetAddress() == b:GetAddress()
end

local function native(path)
    local fn = StaticFindObject(path)
    assert(name(fn) == "Function " .. path and (fn:GetFunctionFlags() & 0x400) ~= 0, path)
    return fn
end

local function static(module, class, method)
    local base = "/Script/" .. module .. "."
    local fn = native(base .. class .. ":" .. method)
    local cdo = StaticFindObject(base .. "Default__" .. class)
    assert(name(cdo) and name(cdo:GetClass()) == "Class " .. base .. class, class)
    return function(...) return fn(cdo, ...) end
end

local function cleanup(reason)
    if not owned then return end
    local ok, result = pcall(function()
        local c = StaticFindObject(owned.path)
        if not alive(c) or c:GetAddress() ~= owned.address then return "ALREADY_GONE" end
        assert(name(c:GetClass()) == PSC, "owned component class changed")
        c:K2_DestroyComponent(c)
        assert(not alive(c), "destruction not confirmed")
        return "DESTROYED"
    end)
    if ok then
        owned = nil
        log(result, "reason=" .. reason)
    else
        log("CLEANUP_PENDING", reason .. " " .. tostring(result))
    end
end

local function anchor()
    local hud
    for _, candidate in ipairs(FindAllOf("HUDMainUMG_BP_C") or {}) do
        if alive(candidate) and candidate:IsInViewport() then
            assert(not hud, "ambiguous gameplay HUD")
            hud = candidate
        end
    end
    assert(hud, "gameplay HUD missing")
    local pawn = hud:GetOwningPlayerPawn()
    assert(alive(pawn) and name(pawn:GetClass()) == HILDA and pawn.bHidden == false
        and not pawn:IsActorBeingDestroyed(), "active Hilda missing")
    local mesh = pawn.Mesh
    assert(alive(mesh) and name(mesh):match("%.CharacterMesh0$") and same(mesh:GetOwner(), pawn)
        and mesh.bVisible == true and mesh.bHiddenInGame == false, "Hilda mesh unavailable")
    return pawn, mesh
end

local function play()
    if owned then cleanup("manual-interruption"); return end
    if attempted or loading then return end
    local asset = StaticFindObject(ASSET)
    if not alive(asset) or name(asset) ~= "ParticleSystem " .. ASSET then
        log("MISS", "perform one ordinary Astral staff shot, stow and retry")
        return
    end
    local input = static("Genesis", "GameGlobal", "GetInputMode")
    assert(input(true, false) == 0 and input(false, true) == 0, "not in gameplay input mode")
    local pawn, mesh = anchor()
    local socket = FName("scabbard_b", EFindName.FNAME_Find)
    local fade = FName("Fade", EFindName.FNAME_Find)
    assert(socket:ToString() == "scabbard_b" and mesh:DoesSocketExist(socket), "socket unavailable")
    assert(fade:ToString() == "Fade", "Fade unresolved")
    local spawn = static("Engine", "GameplayStatics", "SpawnEmitterAttached")
    native("/Script/Engine.ActorComponent:K2_DestroyComponent")
    native("/Script/Engine.ActorComponent:Activate")
    native("/Script/Engine.FXSystemComponent:SetFloatParameter")
    attempted = true
    -- Relative transform, auto-destroy, no pool, and no activation until Fade is set.
    local c = spawn(asset, mesh, socket, {X=0,Y=0,Z=0}, {Pitch=0,Yaw=0,Roll=0},
        {X=SCALE,Y=SCALE,Z=SCALE}, 0, true, 0, false)
    assert(alive(c) and name(c:GetClass()) == PSC, "spawn result unverified")
    owned = {path=assert(name(c):match("^[^ ]+ (.+)$")), address=c:GetAddress(), pawn=pawn:GetAddress()}
    assert(same(c.Template, asset) and same(c:GetAttachParent(), mesh)
        and c:GetAttachSocketName():ToString() == "scabbard_b",
        "spawn attachment mismatch")
    local handle = ExecuteInGameThreadWithDelay(TIMEOUT_MS, function() cleanup("watchdog") end)
    assert(math.type(handle) == "integer" and IsValidDelayedActionHandle(handle), "watchdog unavailable")
    c:SetFloatParameter(fade, FADE)
    local params, found = c.InstanceParameters, false
    local count = params:GetArrayNum()
    for i = 1, count do
        assert(i <= params:GetArrayNum(), "instance parameter array changed")
        local row = params[i]
        if row.Name:ToString() == "Fade" then found = math.abs(row.Scalar - FADE) < 0.0001; break end
    end
    assert(found, "Fade instance readback failed")
    c:Activate(false)
    log("ACTIVATED", ("socket=scabbard_b fade=%.2f scale=%.2f object=%s"):format(FADE, SCALE, owned.path))
end

local ok, failure = pcall(function()
    assert(EngineTickAvailable and EGameThreadMethod and EGameThreadMethod.EngineTick, "EngineTick unavailable")
    for _, api in ipairs({"ExecuteInGameThread", "ExecuteInGameThreadWithDelay", "IsValidDelayedActionHandle",
        "RegisterLoadMapPreHook", "RegisterLoadMapPostHook", "RegisterEndPlayPreHook",
        "RegisterKeyBind", "IsKeyBindRegistered", "StaticFindObject", "FindAllOf"}) do
        assert(type(_G[api]) == "function", api .. " unavailable")
    end
    -- UE4SS exposes FName as callable userdata.
    assert(EFindName and math.type(EFindName.FNAME_Find) == "integer", "FNAME_Find unavailable")
    assert(FName("None", EFindName.FNAME_Find):ToString() == "None", "FName lookup failed")
    local mods = {ModifierKey.CONTROL, ModifierKey.ALT}
    assert(Key.F5 and not IsKeyBindRegistered(Key.F5, mods), "Ctrl+Alt+F5 unavailable")
    RegisterLoadMapPreHook(function() loading = true; cleanup("load-map") end)
    RegisterLoadMapPostHook(function() loading = false end)
    RegisterEndPlayPreHook(function(param)
        if not owned then return end
        local actor = param:get()
        if valid(actor) and actor:GetAddress() == owned.pawn then cleanup("pawn-end-play") end
    end)
    RegisterKeyBind(Key.F5, mods, function()
        if not armed or queued then return end
        queued = true
        local scheduled, err = pcall(ExecuteInGameThread, function()
            queued = false
            local ran, issue = pcall(function()
                alive = alive or static("Engine", "KismetSystemLibrary", "IsValid")
                play()
            end)
            if not ran then log("FAILED", tostring(issue)); cleanup("error") end
        end, EGameThreadMethod.EngineTick)
        if not scheduled then queued = false; log("FAILED", tostring(err)) end
    end)
    armed = true
    log("ARMED", "Ctrl+Alt+F5 once in gameplay; press again to interrupt")
end)
if not ok then log("INIT_FAILED", tostring(failure)) end
