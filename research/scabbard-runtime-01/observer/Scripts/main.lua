-- SPDX-License-Identifier: MPL-2.0
-- Research only: no gameplay writes. All object reads are synchronous.
local ID = "scabbard-runtime-01-observer-01"
local CLASS = "/Game/MainContent/Act/Character_BP/hilda_BP.hilda_BP_C"
local ACTION = CLASS .. ":ExecuteAction"
local PREFIX = "MS_OBSERVER id=" .. ID
local active, stopped, pending = false, false, false
local deadline, pre, post, pawnId
local samples, events = 0, 0
local targetActions = {
    scabbard_on = true, scabbard_off = true,
    weapon_in_hand = true, weapon_leave_hand = true,
}
local actorClasses = { "HildaCudgel_BP_C", "HildaCudgel_Use_BP_C", "HildaCudgel_Unuse_BP_C" }

local function log(event, fields)
    print(PREFIX .. " event=" .. event .. " " .. (fields or "") .. "\n")
end

local function quote(value)
    return string.format("%q", tostring(value):gsub("%c", "?"):sub(1, 320))
end

local function valid(object)
    return object ~= nil and object:IsValid()
end

local function id(object)
    if not valid(object) then return "none" end
    return object:GetFullName() .. "@" .. tostring(object:GetAddress())
end

local function stop(reason)
    if stopped then return end
    active, stopped, pawnId = false, true, nil
    log("STOP", "reason=" .. quote(reason) .. " samples=" .. samples .. " actions=" .. events)
    if pre and post then
        local ok, problem = pcall(UnregisterHook, ACTION, pre, post)
        if not ok then log("CLEANUP_PENDING", "until=process-exit detail=" .. quote(problem)); return end
    end
    log("CLEANED", "keybinds=inert")
end

local function guarded(fn)
    local ok, problem = pcall(fn)
    if not ok then stop("failure: " .. tostring(problem)) end
end

local function classIs(object, path)
    return valid(object) and object:GetClass():GetFullName() == "BlueprintGeneratedClass " .. path
end

local function readComponent(label, component, context)
    if not valid(component) then
        log("COMPONENT", context .. " slot=" .. label .. " present=false")
        return
    end
    assert(component:GetClass():GetFullName() == "Class /Script/Engine.SkeletalMeshComponent",
        "unexpected component class at " .. label)
    local hidden, visible = component.bHiddenInGame, component.bVisible
    assert(type(hidden) == "boolean" and type(visible) == "boolean", "visibility fields unavailable")
    log("COMPONENT", context .. " slot=" .. label .. " component=" .. quote(id(component))
        .. " owner=" .. quote(id(component:GetOwner())) .. " asset=" .. quote(id(component.SkeletalMesh))
        .. " attach=" .. quote(id(component:GetAttachParent())) .. " socket=" .. quote(component:GetAttachSocketName():ToString())
        .. " hidden=" .. tostring(hidden) .. " visible=" .. tostring(visible))
end

local function readPawn(pawn, context)
    local global = StaticFindObject("/Script/Genesis.Default__GameGlobal")
    assert(valid(global), "GameGlobal CDO unavailable")
    log("BATTLE_BEGIN", context)
    local battle = global:GetIsBattleState(pawn)
    assert(type(battle) == "boolean", "battle getter did not return boolean")
    log("PAWN", context .. " pawn=" .. quote(id(pawn)) .. " battle=" .. tostring(battle))
    readComponent("scabbard_a", pawn.scabbard_a, context)
    readComponent("scabbard_b", pawn.scabbard_b, context)
end

local function observe(context, _, actionParam)
    if not active or not pawnId or events >= 24 then return end
    local ok, problem = pcall(function()
        local pawn = context:get()
        if not classIs(pawn, CLASS) or id(pawn) ~= pawnId then return end
        local action = actionParam:get():ToString()
        if not targetActions[action] then return end
        events = events + 1
        local fields = "action=" .. action .. " sequence=" .. events .. " time=" .. os.time()
        log("ACTION_POST", fields)
        readPawn(pawn, fields)
        if events == 24 then log("ACTION_LIMIT", "further_actions=omitted") end
    end)
    if not ok then
        active, pawnId = false, nil
        log("FAILED", "hook=" .. quote(problem))
        local queued = pcall(ExecuteInGameThread, function() stop("hook failure") end, EGameThreadMethod.EngineTick)
        if not queued then log("CLEANUP_PENDING", "until=process-exit") end
    end
    -- Blueprint post hook deliberately returns nil.
end

local function findExact(class)
    log("LOOKUP_BEGIN", "class=" .. class)
    local values = FindAllOf(class) or {}
    log("LOOKUP_END", "class=" .. class .. " found=" .. #values)
    assert(#values <= 8, "candidate count exceeded for " .. class)
    return values
end

local function sample()
    samples = samples + 1
    local fields = "sample=" .. samples .. " time=" .. os.time()
    local pawn, count = nil, 0
    pawnId = nil
    for _, hud in ipairs(findExact("HUDMainUMG_BP_C")) do
        if valid(hud) and hud:IsInViewport() then
            count = count + 1
            pawn = hud:GetOwningPlayerPawn()
        end
    end
    if count ~= 1 or not classIs(pawn, CLASS) then
        log("NO_GAMEPLAY_PAWN", fields .. " viewport_huds=" .. count)
        return
    end
    if not pre then
        local fn = StaticFindObject(ACTION)
        assert(valid(fn) and fn:type() == "UFunction" and fn:GetFullName() == "Function " .. ACTION,
            "ExecuteAction unavailable")
        assert((fn:GetFunctionFlags() & 0x400) == 0, "ExecuteAction must be Blueprint")
        log("HOOK_BEGIN", "path=" .. ACTION)
        pre, post = RegisterHook(ACTION, observe)
        assert(math.type(pre) == "integer" and pre > 0 and pre == post, "unexpected Blueprint hook IDs")
        log("HOOK_END", "mode=post")
    end
    pawnId = id(pawn)
    readPawn(pawn, fields)
    for _, class in ipairs(actorClasses) do
        for _, actor in ipairs(findExact(class)) do
            if valid(actor) and actor:GetClass():GetFullName():match("%." .. class .. "$") then
                local context = fields .. " actor=" .. quote(id(actor))
                local root = actor.RootComponent
                local parent = valid(root) and root:GetAttachParent() or nil
                log("ACTOR", context .. " actor_owner=" .. quote(id(actor:GetOwner()))
                    .. " root_parent=" .. quote(id(parent))
                    .. " root_parent_owner=" .. quote(valid(parent) and id(parent:GetOwner()) or "none")
                    .. " actor_hidden=" .. tostring(actor.bHidden))
                readComponent("SkeletalMesh", actor.SkeletalMesh, context)
                if class == actorClasses[1] then
                    readComponent("hilda_cudgel_sheath", actor.hilda_cudgel_sheath, context)
                end
            end
        end
    end
end

local function control()
    if stopped then return end
    if not active then
        deadline, active = os.time() + 300, true
        ExecuteInGameThreadWithDelay(300000, function() stop("timeout") end)
    end
    if os.time() >= deadline then stop("timeout"); return end
    sample()
    if samples >= 6 then stop("sample-limit") end
end

log("ARMED", "sample=Ctrl+Alt+F9 stop=Ctrl+Alt+F10 max_samples=6 max_actions=24 timeout_seconds=300")
guarded(function()
    assert(EngineTickAvailable == true, "engine-tick dispatch unavailable")
    local modifiers = {ModifierKey.CONTROL, ModifierKey.ALT}
    assert(not IsKeyBindRegistered(Key.F9, modifiers) and not IsKeyBindRegistered(Key.F10, modifiers),
        "observer chord already registered")
    local function bind(key, fn)
        RegisterKeyBind(key, modifiers, function()
            if stopped or pending then return end
            pending = true
            local ok, problem = pcall(ExecuteInGameThread, function()
                pending = false
                guarded(fn)
            end, EGameThreadMethod.EngineTick)
            if not ok then
                pending, active, stopped, pawnId = false, false, true, nil
                log("FAILED", "dispatch=" .. quote(problem) .. " callbacks=inert cleanup=process-exit")
            end
        end)
    end
    bind(Key.F9, control)
    bind(Key.F10, function() stop("user") end)
end)
