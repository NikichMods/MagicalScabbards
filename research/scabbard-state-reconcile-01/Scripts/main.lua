-- SPDX-License-Identifier: MPL-2.0
-- Read-only survey. SUPPRESSED from the pure policy means WOULD_HIDE here.
local reconcile = require("reconcile")(250)
local DRAW = "/Script/Genesis.BaseCharacterAnimInstance:BeginDoSkill"
local CLOCK = "/Script/Engine.GameplayStatics:GetRealTimeSeconds"
local ITEM = "BlueprintGeneratedClass /Game/MainContent/Act/Item_BP/"
local SKELETAL = "Class /Script/Engine.SkeletalMeshComponent"
local MESH = "SkeletalMesh /Game/MainContent/Assets/creature/03_weapon/"
local roles = {
    [1] = {HildaDualMain_BP = {"hilda_dualmain_mesh", "scabbard_b", "hilda_dualblade_mesh", "hilda_dual_sheath"},
           HildaDualOff_BP = {"hilda_dualoff_mesh"}},
    [2] = {HildaCudgel_BP = {"hilda_cudgel", "scabbard_a", nil, "hilda_cudgel_sheath"}},
    [4] = {HildaStaff_BP = {"hilda_staff", "scabbard_b", nil, "hilda_staff_sheath"}},
}

local function valid(o) return o ~= nil and o:IsValid() end
local function name(o) return valid(o) and o:GetFullName() or nil end
local function id(o) return valid(o) and (name(o) .. "@" .. tostring(o:GetAddress())) or "-" end
local function class(o) return valid(o) and name(o:GetClass()) or nil end
local function socket(o) return valid(o) and o:GetAttachSocketName():ToString() or "-" end
local function visible(o) return valid(o) and o.bVisible == true and o.bHiddenInGame == false end
local function enum(n) return math.type(n) == "integer" and (n >= 0 and n <= 5 or n == 7) end
local function log(event, fields) print("[ScabbardReconcile] " .. event .. " " .. (fields or "")) end
local function state(phase) return {phase=phase} end

local hudPath, animId, loading, handle, hookA, hookB, session
local hudRetry = 0
local lastLine, lastTime, worstGap, samples = nil, nil, 0, 0

local function context()
    local hud = hudPath and StaticFindObject(hudPath)
    if not valid(hud) or not hud:IsInViewport() then
        if hudRetry > 0 then
            hudRetry = hudRetry - 1
            return
        end
        hudRetry = 9
        hud = nil
        for _, candidate in ipairs(FindAllOf("HUDMainUMG_BP_C") or {}) do
            if valid(candidate) and candidate:IsInViewport() then
                if hud then return end
                hud = candidate
            end
        end
        hudPath = name(hud) and name(hud):match("^[^ ]+ (.+)$")
    end
    if not valid(hud) then return end
    local pawn = hud:GetOwningPlayerPawn()
    if class(pawn) ~= "BlueprintGeneratedClass /Game/MainContent/Act/Character_BP/hilda_BP.hilda_BP_C"
        or pawn.bHidden ~= false then return end
    local mesh = pawn.Mesh
    if class(mesh) ~= SKELETAL or not name(mesh):match("%.CharacterMesh0$")
        or id(mesh:GetOwner()) ~= id(pawn) or not visible(mesh) then return end
    local anim = mesh:GetAnimInstance()
    if not (class(anim) or ""):match("%.hilda_AnimBP_C$") then return end
    return pawn, mesh, anim, id(hud)
end

local function checkMesh(c, actor, root, resource)
    return class(c) == SKELETAL and id(c:GetOwner()) == id(actor) and id(c:GetAttachParent()) == id(root)
        and socket(c) == "None" and name(c.SkeletalMesh) == MESH .. resource .. "." .. resource
end

local function inspect(actor, pawn, mesh, role)
    if not valid(actor) then return false, "-", "-" end
    local root, held = actor.RootComponent, actor.SkeletalMesh
    local blade = role and role[3] and actor[role[3]]
    local sheath = role and role[4] and actor[role[4]]
    local key = table.concat({id(actor), id(root), id(held), id(blade), id(sheath), socket(root),
        valid(held) and id(held.SkeletalMesh) or "-", valid(blade) and id(blade.SkeletalMesh) or "-",
        valid(sheath) and id(sheath.SkeletalMesh) or "-"}, "|")
    local label = ("%s:%s:%s:%s:%s:%s"):format(class(actor) or "?", tostring(actor.equipMode),
        socket(root), valid(held) and (name(held.SkeletalMesh) or "?") or "-",
        tostring(valid(held) and held.bVisible), tostring(valid(held) and held.bHiddenInGame))
    local stowed = role and id(actor:GetOwner()) == id(pawn) and actor.bHidden == false
        and actor:IsActorBeingDestroyed() == false and actor.equipMode == 1
        and valid(root) and id(root:GetOwner()) == id(actor)
        and checkMesh(held, actor, root, role[1]) and held.bVisible == false and held.bHiddenInGame == false
        and (not role[2] or (visible(root) and id(root:GetAttachParent()) == id(mesh) and socket(root) == role[2]))
        and (not role[3] or (checkMesh(blade, actor, root, role[3]) and blade.bVisible == false))
        and (not role[4] or checkMesh(sheath, actor, root, role[4]))
    return stowed, key, label
end

local function readEquipmentState()
    if loading then return state("UNKNOWN"), nil, "loading" end
    local pawn, mesh, anim, hud = context()
    if not pawn then
        animId = nil
        return state("UNKNOWN"), nil, "no-context"
    end
    animId = id(anim)
    local clock, statics = StaticFindObject(CLOCK), StaticFindObject("/Script/Engine.Default__GameplayStatics")
    assert(name(clock) == "Function " .. CLOCK and name(statics) == "GameplayStatics /Script/Engine.Default__GameplayStatics")
    local now = clock(statics, pawn) * 1000
    local global = StaticFindObject("/Script/Genesis.Default__GameGlobal")
    assert(name(global) == "GameGlobal /Script/Genesis.Default__GameGlobal")
    local hand = global:GetInHandWeaponType(pawn)
    assert(enum(hand), "invalid hand")
    local doing, nextSkill = anim:GetDoingSkill():ToString(), anim:GetToDoSkill():ToString()
    local key, labels = {hud, id(pawn), id(mesh), animId}, {}
    local complete, occupied = true, false
    for slot = 0, 1 do
        local kind = global:GetInUseWeaponType(pawn, slot)
        assert(enum(kind), "invalid slot")
        key[#key + 1], labels[#labels + 1] = kind, tostring(kind)
        if kind ~= 7 then
            occupied = true
            local seen = {}
            for handSlot = 0, 1 do
                local actor = global:GetWeaponObject(pawn, kind, handSlot)
                local actorClass = class(actor)
                local role
                for short, row in pairs(roles[kind] or {}) do
                    if actorClass == ITEM .. short .. "." .. short .. "_C" then
                        role = row
                        if seen[short] then complete = false end
                        seen[short] = true
                        break
                    end
                end
                local stowed, identity, label = inspect(actor, pawn, mesh, role)
                if actorClass and not stowed then complete = false end
                key[#key + 1], labels[#labels + 1] = identity, label
            end
            if not roles[kind] then complete = false end
            for short in pairs(roles[kind] or {}) do
                if not seen[short] then complete = false end
            end
        end
    end
    local phase = hand ~= 7 and "DRAWN" or "UNKNOWN"
    if hand == 7 and occupied and complete and doing == "None" and nextSkill == "None" then phase = "STOWED" end
    return {phase=phase, identity=table.concat(key, ";")}, now,
        ("hand=%d busy=%s slots=%q"):format(hand, tostring(doing ~= "None" or nextSkill ~= "None"), table.concat(labels, ";"))
end

local function sample(ticket)
    if session ~= ticket then return end
    local ok, err = pcall(function()
        local snapshot, now, detail = readEquipmentState()
        if now and lastTime and now >= lastTime then worstGap = math.max(worstGap, now - lastTime) end
        lastTime, samples = now, samples + 1
        local intent = reconcile.observe(snapshot, now, readEquipmentState)
        local line = ("%s decision=%s %s id=%q"):format(snapshot.phase,
            intent == "SUPPRESSED" and "WOULD_HIDE" or "PASS-THROUGH", detail, snapshot.identity or "-")
        if line ~= lastLine then
            log("SAMPLE", ("ms=%.1f %s"):format(now or -1, line))
            lastLine = line
        end
    end)
    if not ok then
        animId, lastTime = nil, nil
        reconcile.reset()
        local detail = tostring(err)
        if detail ~= lastLine then log("READ_FAILED", detail); lastLine = detail end
    end
end

local function stop()
    session, animId, hudPath = nil, nil, nil
    reconcile.reset()
    if hookA then
        local ok, result = pcall(UnregisterHook, DRAW, hookA, hookB)
        if ok and result ~= false then hookA, hookB = nil, nil end
    end
    if handle and (not IsValidDelayedActionHandle(handle) or CancelDelayedAction(handle)) then handle = nil end
    log((handle or hookA) and "STOP_PENDING" or "STOP", ("samples=%d max_gap_ms=%.1f writes=0"):format(samples, worstGap))
end

local function start()
    if session or handle or hookA then return end
    local ticket = {}
    local fn = StaticFindObject(DRAW)
    assert(name(fn) == "Function " .. DRAW and (fn:GetFunctionFlags() & 0x400) ~= 0)
    hookA, hookB = RegisterHook(DRAW, function(param)
        if session == ticket and animId and id(param:get()) == animId then
            reconcile.reset()
            -- Aggregate repeated combo callbacks into one change marker per observation.
            if lastLine ~= "PRE" then log("SKILL_PRE", ("sample_ms=%.1f"):format(lastTime or -1)) end
            lastLine = "PRE"
        end
    end, function() end)
    assert(math.type(hookA) == "integer" and math.type(hookB) == "integer" and hookA > 0 and hookB > 0 and hookA ~= hookB)
    lastLine, lastTime, worstGap, samples, hudRetry = nil, nil, 0, 0, 0
    handle = LoopInGameThreadWithDelay(100, function() sample(ticket) end)
    assert(math.type(handle) == "integer" and IsValidDelayedActionHandle(handle))
    session = ticket
    log("START", "read_only=true interval_ms=100")
end

local mods = {ModifierKey.CONTROL, ModifierKey.ALT}
assert(EngineTickAvailable and type(LoopInGameThreadWithDelay) == "function")
assert(not IsKeyBindRegistered(Key.F7, mods) and not IsKeyBindRegistered(Key.F8, mods), "test chord occupied")
RegisterLoadMapPreHook(function()
    loading, hudPath, animId, lastTime = true, nil, nil, nil
    hudRetry = 0
    reconcile.reset()
end)
RegisterLoadMapPostHook(function() loading = false end)
RegisterKeyBind(Key.F7, mods, function()
    ExecuteInGameThread(function()
        local ok, err = pcall(start)
        if not ok then log("START_FAILED", tostring(err)); stop() end
    end, EGameThreadMethod.EngineTick)
end)
RegisterKeyBind(Key.F8, mods, function() ExecuteInGameThread(stop, EGameThreadMethod.EngineTick) end)
