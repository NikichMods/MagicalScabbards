-- SPDX-License-Identifier: MPL-2.0
-- One pawn-owned cudgel, read-only. Keep only primitive identities between callbacks.
local ID = "visual-boundaries-observer-01"
local EQUIP = "/Game/MainContent/Act/Item_BP/HildaCudgel_BP.HildaCudgel_BP_C:EquipModeChange"
local HIDDEN = "/Script/Engine.SceneComponent:SetHiddenInGame"
local BEGIN = "/Script/Genesis.BaseCharacterAnimInstance:BeginDoSkill"
local HILDA = "BlueprintGeneratedClass /Game/MainContent/Act/Character_BP/hilda_BP.hilda_BP_C"
local CUDGEL = "BlueprintGeneratedClass /Game/MainContent/Act/Item_BP/HildaCudgel_BP.HildaCudgel_BP_C"
local hooks = {}
local active, done, queued, fault = false, false, false, false
local pawnId, pawnPath, actorId, actorPath, mainId, sheathId, sheathAddress, animId
local controlIds, hiddenCalls, hiddenControls = {}, 0, 0
local samples, events, seq = 0, 0, 0
local function log(event, fields)
    seq = seq + 1
    print("MS_VISUAL05 id=" .. ID .. " seq=" .. seq .. " time=" .. os.time()
        .. " event=" .. event .. " " .. (fields or "") .. "\n")
end
local function valid(o) return o ~= nil and o:IsValid() end
local function id(o)
    return valid(o) and (o:GetFullName() .. "@" .. tostring(o:GetAddress())) or "none"
end
local function q(v) return string.format("%q", tostring(v):gsub("%c", "?"):sub(1, 300)) end
local function isClass(o, class) return valid(o) and o:GetClass():GetFullName() == class end

local function stop(reason)
    if done then return end
    active, done = false, true
    log("STOP", "reason=" .. q(reason) .. " samples=" .. samples .. " events=" .. events .. " hidden_calls=" .. hiddenCalls .. " hidden_controls=" .. hiddenControls)
    local clean = true
    for _, h in ipairs(hooks) do
        local ok, err = pcall(UnregisterHook, h.path, h.pre, h.post)
        if not ok then clean = false; log("UNHOOK_ERROR", "detail=" .. q(err)) end
    end
    log(clean and "CLEANED" or "CLEANUP_PENDING", "keys=inert")
end
local function stopLater(reason)
    active = false
    local ok = pcall(ExecuteInGameThread, function() stop(reason) end, EGameThreadMethod.EngineTick)
    if not ok then fault = true; log("CLEANUP_PENDING", "until=process-exit") end
end
local function fail(err)
    if fault or done then return end
    fault = true
    log("FAILED", "detail=" .. q(err))
    stopLater("failure")
end

local function state(actor)
    local owner, root = actor:GetOwner(), actor.RootComponent
    assert(id(actor) == actorId and id(owner) == pawnId and valid(root), "actor/owner generation changed")
    local parent = root:GetAttachParent()
    local main, sheath = actor.SkeletalMesh, actor.hilda_cudgel_sheath
    assert(id(main) == mainId and id(sheath) == sheathId
        and id(main:GetOwner()) == actorId and id(sheath:GetOwner()) == actorId, "component ownership changed")
    local parentMatch = valid(parent) and id(parent) == id(owner.Mesh)
    local mode = actor.equipMode
    assert(math.type(mode) == "integer", "equipMode is not an integer")
    assert(type(main.bVisible) == "boolean" and type(sheath.bVisible) == "boolean"
        and type(main.bHiddenInGame) == "boolean" and type(sheath.bHiddenInGame) == "boolean",
        "visibility fields unavailable")
    return " mode=" .. mode .. " socket=" .. q(root:GetAttachSocketName():ToString())
        .. " parent_matches_pawn_mesh=" .. tostring(parentMatch)
        .. " main_visible=" .. tostring(main.bVisible) .. " sheath_visible=" .. tostring(sheath.bVisible)
        .. " main_hidden=" .. tostring(main.bHiddenInGame) .. " sheath_hidden=" .. tostring(sheath.bHiddenInGame)
end

local function guarded(fn)
    if not active then return end
    local ok, err = pcall(fn)
    if not ok then fail(err) end
end
local function currentActor()
    local pawn, actor = StaticFindObject(pawnPath), StaticFindObject(actorPath)
    assert(id(pawn) == pawnId and id(actor) == actorId and id(actor:GetOwner()) == pawnId, "target generation changed")
    return actor
end
local function evidence(event, fields)
    events = events + 1
    log(event, fields)
    if events >= 24 then stopLater("target-event-limit") end
end
local function observeDraw(context)
    guarded(function()
        local anim = context:get()
        if id(anim) ~= animId then return end
        local pending = anim:GetToDoSkill():ToString()
        evidence("BEGIN_PRE", "pending=" .. q(pending) .. state(currentActor()))
    end)
end
local function observeEquip(context, arg)
    guarded(function()
        local actor = context:get()
        if id(actor) ~= actorId then return end
        log("DELIVERY", "kind=equip_post")
        local requested = arg:get()
        assert(math.type(requested) == "integer", "EquipModeChange parameter is not integer")
        evidence("EQUIP_POST", "requested=" .. requested .. state(actor))
    end)
end
local function observeHidden(phase, context, arg, propagate)
    if not active then return end
    hiddenCalls = hiddenCalls + 1
    if hiddenCalls > 1024 then stopLater("hidden-dispatch-limit"); return end
    guarded(function()
        local component = context:get()
        if not valid(component) then return end
        local address = tostring(component:GetAddress())
        local expected = controlIds[address]
        if address ~= sheathAddress and not expected then return end
        local objectId = id(component)
        if expected and objectId == expected then
            local pawn = StaticFindObject(pawnPath)
            if id(pawn) ~= pawnId or id(component:GetOwner()) ~= pawnId then return end
            if phase == "post" then hiddenControls = hiddenControls + 1 end
            evidence("HIDDEN_CONTROL", "phase=" .. phase .. " requested=" .. tostring(arg:get())
                .. " hidden=" .. tostring(component.bHiddenInGame) .. " component=" .. q(objectId))
        elseif objectId == sheathId then
            local requested, propagation = arg:get(), propagate:get()
            assert(type(requested) == "boolean" and type(propagation) == "boolean", "hidden binding mismatch")
            evidence("HIDDEN_TARGET", "phase=" .. phase .. " requested=" .. tostring(requested)
                .. " propagate=" .. tostring(propagation) .. state(component:GetOwner()))
        end
    end)
end

local function hook(path, native, before, after)
    local fn = StaticFindObject(path)
    assert(valid(fn) and fn:type() == "UFunction" and fn:GetFullName() == "Function " .. path
        and ((fn:GetFunctionFlags() & 0x400) ~= 0) == native, "unexpected hook target " .. path)
    log("HOOK_BEGIN", "path=" .. path)
    local pre, post
    if native then pre, post = RegisterHook(path, before, after)
    else pre, post = RegisterHook(path, after) end
    hooks[#hooks + 1] = {path=path, pre=pre, post=post}
    assert(math.type(pre) == "integer" and math.type(post) == "integer"
        and pre > 0 and post > 0 and (pre ~= post) == native, "unexpected hook IDs")
    log("HOOK_END", "path=" .. path)
end
local function find(class)
    log("LOOKUP_BEGIN", "class=" .. class)
    local found = FindAllOf(class) or {}
    log("LOOKUP_END", "class=" .. class .. " count=" .. #found)
    assert(#found <= 8, "class candidate budget")
    return found
end
local function sample()
    local pawn, count = nil, 0
    for _, hud in ipairs(find("HUDMainUMG_BP_C")) do
        if valid(hud) and hud:IsInViewport() then count, pawn = count + 1, hud:GetOwningPlayerPawn() end
    end
    assert(count == 1 and isClass(pawn, HILDA), "local gameplay pawn unavailable")
    local actor, actors = nil, 0
    for _, candidate in ipairs(find("HildaCudgel_BP_C")) do
        if isClass(candidate, CUDGEL) and id(candidate:GetOwner()) == id(pawn) then
            actor, actors = candidate, actors + 1
        end
    end
    assert(actors == 1, "expected one cudgel owned by local pawn")
    if samples == 0 then
        local main, sheath = actor.SkeletalMesh, actor.hilda_cudgel_sheath
        assert(valid(main) and valid(sheath) and id(main) ~= id(sheath), "expected separate cudgel components")
        pawnId, actorId, mainId, sheathId = id(pawn), id(actor), id(main), id(sheath)
        sheathAddress = tostring(sheath:GetAddress())
        pawnPath = assert(pawn:GetFullName():match("^[^ ]+ (.+)$"))
        actorPath = assert(actor:GetFullName():match("^[^ ]+ (.+)$"))
        local anim = pawn.Mesh:GetAnimInstance()
        assert(valid(anim) and anim:GetClass():GetFullName():match("%.hilda_AnimBP_C$"), "unexpected anim instance")
        animId = id(anim)
        for _, control in ipairs({pawn.scabbard_a, pawn.scabbard_b}) do
            if valid(control) and id(control:GetOwner()) == pawnId then
                controlIds[tostring(control:GetAddress())] = id(control)
            end
        end
        assert(id(currentActor()) == actorId, "actor path does not resolve")
        local root = actor.RootComponent
        assert(valid(root) and valid(pawn.Mesh) and id(root:GetAttachParent()) == id(pawn.Mesh)
            and root:GetAttachSocketName():ToString() == "scabbard_a"
            and main.bVisible == false and sheath.bVisible == true, "first snapshot must be stowed")
        log("TARGET", "pawn=" .. q(pawnId) .. " actor=" .. q(actorId)
            .. " main=" .. q(mainId) .. " sheath=" .. q(sheathId)
            .. " main_asset=" .. q(id(main.SkeletalMesh)) .. " sheath_asset=" .. q(id(sheath.SkeletalMesh)))
        hook(BEGIN, true, observeDraw, function() end)
        hook(EQUIP, false, nil, observeEquip)
        hook(HIDDEN, true, function(ctx, flag, prop) observeHidden("pre", ctx, flag, prop) end,
            function(ctx, flag, prop) observeHidden("post", ctx, flag, prop) end)
        ExecuteInGameThreadWithDelay(120000, function() stop("timeout") end)
        active = true
    end
    samples = samples + 1
    log("SNAPSHOT", "sample=" .. samples .. state(actor))
    if samples >= 3 then stop("sample-limit") end
end
local function bind(key, fn, mods)
    RegisterKeyBind(key, mods, function()
        if done or queued or fault then return end
        queued = true
        local ok, err = pcall(ExecuteInGameThread, function()
            queued = false
            if done or fault then return end
            local success, problem = pcall(fn)
            if not success then fail(problem) end
        end, EGameThreadMethod.EngineTick)
        if not ok then fail(err) end
    end)
end
assert(EngineTickAvailable == true, "EngineTick required")
local mods = {ModifierKey.CONTROL, ModifierKey.ALT}
assert(not IsKeyBindRegistered(Key.F9, mods) and not IsKeyBindRegistered(Key.F10, mods), "observer chord occupied")
bind(Key.F9, sample, mods)
bind(Key.F10, function() stop("user") end, mods)
log("ARMED", "samples=3 callbacks=24 seconds=120 sample=Ctrl+Alt+F9 stop=Ctrl+Alt+F10")
