-- SPDX-License-Identifier: MPL-2.0
-- One-session research harness. Only the verified stock cudgel sheath may be written.
local BASE = "/Game/MainContent/Act/Item_BP/HildaCudgel_BP.HildaCudgel_BP_C"
local EQUIP = BASE .. ":EquipModeChange"
local DRAW = "/Script/Genesis.BaseCharacterAnimInstance:BeginDoSkill"
local VIS = "/Script/Engine.SceneComponent:SetVisibility"
local WEAPONS = "/Game/MainContent/Assets/creature/03_weapon/"
local phase, queued, stopping = "idle", false, false
local hooks, target = {}, nil
local token, pending, deadline = 0, nil, nil
local owned, ownCall, retired = false, nil, false
local drawPending = false
local baselineStep, writerPair, events = 0, nil, 0
local function log(event, fields)
    print("MS_WRITE07 id=cooperative-cudgel-02 event=" .. event .. " " .. (fields or "") .. "\n")
end
local function valid(o) return o ~= nil and o:IsValid() end
local function identity(o)
    if valid(o) then return o:GetFullName() .. "@" .. tostring(o:GetAddress()) end
end
local function path(o) return assert(o:GetFullName():match("^[^ ]+ (.+)$"), "object path unavailable") end
local function class(o) return valid(o) and o:GetClass():GetFullName() or nil end
local function resolve()
    if retired then return end
    local hud = StaticFindObject(target.hudPath)
    local actor = StaticFindObject(target.actorPath)
    if identity(hud) ~= target.hud or not hud:IsInViewport() or identity(actor) ~= target.actor then return end
    local pawn = hud:GetOwningPlayerPawn()
    if identity(pawn) ~= target.pawn or identity(actor:GetOwner()) ~= target.pawn then return end
    local mesh, root, sheath, main = pawn.Mesh, actor.RootComponent, actor.hilda_cudgel_sheath, actor.SkeletalMesh
    if identity(mesh) ~= target.mesh or identity(root) ~= target.root
        or identity(sheath) ~= target.sheath or identity(main) ~= target.main then return end
    if identity(root:GetAttachParent()) ~= target.mesh or identity(sheath:GetOwner()) ~= target.actor
        or identity(main:GetOwner()) ~= target.actor or identity(sheath.SkeletalMesh) ~= target.sheathAsset
        or identity(main.SkeletalMesh) ~= target.mainAsset or actor.bHidden ~= false then return end
    return actor, sheath, main, root:GetAttachSocketName():ToString(), pawn
end
local function stowed(expected, post)
    local actor, sheath, main, socket = resolve()
    if actor and socket == "scabbard_a" and (post or actor.equipMode == 1)
        and main.bVisible == false and main.bHiddenInGame == false
        and sheath.bVisible == expected and sheath.bHiddenInGame == false then return sheath end
end
local function weaponOut(socket, expected, sheath, main)
    return socket == expected and main.bVisible == true and main.bHiddenInGame == false
        and sheath.bVisible == false and sheath.bHiddenInGame == false
end
local function visual(event)
    local actor, sheath, main, socket, pawn = resolve()
    assert(actor, "visual target lost")
    local function flags(component)
        return "visible=" .. tostring(component.bVisible) .. ",hidden=" .. tostring(component.bHiddenInGame)
    end
    local function scabbard(name)
        local ok, detail = pcall(function()
            local component = pawn[name]
            if not valid(component) then return "unavailable" end
            return flags(component) .. ",pawn_owned=" .. tostring(identity(component:GetOwner()) == target.pawn)
                .. ",asset=" .. string.format("%q", tostring(identity(component.SkeletalMesh)))
        end)
        return ok and detail or "unreadable"
    end
    log(event, "token=" .. token .. " socket=" .. socket .. " target=" .. string.format("%q", target.sheath)
        .. " asset=" .. string.format("%q", target.sheathAsset) .. " sheath_" .. flags(sheath)
        .. " held_" .. flags(main) .. " scabbard_a=" .. scabbard("scabbard_a") .. " scabbard_b=" .. scabbard("scabbard_b"))
end
local function invalidate(reason)
    token = token + 1
    local old = pending
    pending = nil
    if old then
        local ok, err = pcall(CancelDelayedAction, old)
        local checked, active = pcall(IsValidDelayedActionHandle, old)
        log("CANCEL", "reason=" .. reason .. " token=" .. token .. " inactive=" .. tostring(checked and not active))
        assert(ok and checked and not active, "timer cancellation unverified: " .. tostring(err))
    end
end
local function setOwned(component, visible)
    local _, exact, main = resolve()
    assert(identity(exact) == target.sheath and identity(component) == target.sheath, "write target lost")
    local mainBefore, mainHidden = main.bVisible, main.bHiddenInGame
    assert(ownCall == nil, "reentrant write")
    local call = {value=visible}
    ownCall = call
    if not visible then owned = true end -- Retain cleanup responsibility if readback itself fails.
    log("WRITE_BEGIN", "visible=" .. tostring(visible) .. " token=" .. token)
    local ok, problem = pcall(function() component:SetVisibility(visible, false) end)
    ownCall = nil
    local _, current, currentMain = resolve()
    assert(identity(current) == target.sheath, "post-write identity unavailable")
    if not call.conflict then owned = current.bVisible == false end
    assert(ok, problem)
    assert(not call.conflict and current.bVisible == visible and current.bHiddenInGame == false
        and currentMain.bVisible == mainBefore and currentMain.bHiddenInGame == mainHidden, "write readback mismatch")
    log(visible and "RESTORED" or "HIDDEN", "token=" .. token)
end
local function release()
    if not owned then return end
    local component = stowed(false, false)
    assert(component, "owned mask cannot be safely restored")
    setOwned(component, true)
end
local function stop(reason)
    if phase == "done" then return end
    phase, stopping = "done", true
    log("STOP", "reason=" .. reason)
    local canceled = pcall(invalidate, "stop")
    local wasOwned = owned
    local restored = pcall(release)
    if wasOwned and restored and not pcall(visual, "VISUAL_STOP") then
        log("VISUAL_UNAVAILABLE", "stage=stop")
    end
    local timeoutClean = true
    if deadline then
        local ok, clean = pcall(function()
            if IsValidDelayedActionHandle(deadline) then CancelDelayedAction(deadline) end
            return not IsValidDelayedActionHandle(deadline)
        end)
        timeoutClean = ok and clean
        deadline = nil
    end
    local clean = canceled and restored and timeoutClean and not owned
    for _, h in ipairs(hooks) do
        local ok = pcall(UnregisterHook, h.path, h.pre, h.post)
        clean = clean and ok
    end
    log(clean and "CLEANED" or "CLEANUP_PENDING", "owned=" .. tostring(owned) .. " keys=inert")
end
local function stopLater(reason)
    if stopping or phase == "done" then return end
    stopping = true
    -- Invalidate immediately. Cleanup cannot run inside the currently executing hook.
    token = token + 1
    local ok = pcall(ExecuteInGameThread, function() stop(reason) end, EGameThreadMethod.EngineTick)
    if not ok then log("CLEANUP_PENDING", "reason=dispatch until=process-exit") end
end
local function guarded(fn)
    if stopping or phase == "idle" or phase == "done" then return end
    local ok, err = pcall(fn)
    if not ok then log("FAILED", "detail=" .. string.format("%q", tostring(err))); stopLater("failure") end
end
local function countEvent()
    events = events + 1
    assert(events <= 48, "target event budget exhausted")
end
local function schedule()
    invalidate("fresh-sheath")
    local mine = token
    local handle = ExecuteInGameThreadWithDelay(2000, function()
        if stopping or phase ~= "test" or token ~= mine or drawPending then return end
        pending = nil
        token = token + 1
        guarded(function()
            local component = stowed(true, false)
            if not component then stopLater("expiry-target-or-state"); return end
            assert(not owned, "existing mask at expiry")
            visual("VISUAL_BEFORE")
            setOwned(component, false)
            visual("VISUAL_AFTER")
        end)
    end)
    assert(math.type(handle) == "integer" and IsValidDelayedActionHandle(handle), "timer handle unavailable")
    pending = handle
    log("SCHEDULE", "token=" .. mine .. " delay_ms=2000")
end
local function onDraw(context)
    guarded(function()
        local anim = context:get()
        if identity(anim) ~= target.anim then return end
        countEvent()
        local skill = anim:GetToDoSkill():ToString()
        log("DRAW_PRE", "pending=" .. skill)
        if phase == "baseline" then
            baselineStep = skill == "hilda_cudgel_atk1_idle" and stowed(true, false) and 1 or 0
            return
        end
        local actor, sheath, main, socket = resolve()
        if not actor then stopLater("draw-target-lost"); return end
        if actor.equipMode == 0 and weaponOut(socket, "cudgel_r_hand", sheath, main) then
            if owned or pending or drawPending then stopLater("inconsistent-in-hand"); return end
            log("SKILL_IN_HAND", "skill=" .. skill)
            return
        end
        local floating = actor.equipMode == 3 and weaponOut(socket, "dual_l_hand", sheath, main)
        if skill ~= "hilda_cudgel_atk1_idle" or not (stowed(not owned, false) or floating) then
            stopLater("unsupported-draw")
            return
        end
        invalidate("draw")
        drawPending = true
        release()
    end)
end
local function onVisibility(which, context, flag, propagation)
    -- Own-call callbacks must remain distinguishable during explicit STOP.
    if phase == "idle" or (stopping and not ownCall) then return end
    local ok, err = pcall(function()
        local object = context:get()
        if not valid(object) or tostring(object:GetAddress()) ~= target.sheathAddress
            or identity(object) ~= target.sheath then return end
        local hadMask = owned
        -- A foreign pre owns the channel even if its argument cannot be decoded.
        if which == "pre" and not ownCall then owned = false end
        local value, prop = flag:get(), propagation:get()
        assert(type(value) == "boolean" and type(prop) == "boolean", "setter binding mismatch")
        if ownCall and ownCall.value == value and prop == false and not ownCall[which] then
            ownCall[which] = true
            return
        end
        countEvent()
        log("VANILLA_SET", "stage=" .. which .. " requested=" .. tostring(value))
        if which == "pre" then
            if ownCall then ownCall.conflict = true end
            owned = false
            writerPair = {value=value, propagation=prop}
            if hadMask then stopLater("stock-took-ownership"); return end
            if phase == "test" then invalidate("stock-setter") end
        elseif writerPair and writerPair.value == value and writerPair.propagation == prop then
            writerPair.post = object.bVisible == value
        end
    end)
    if not ok then
        if ownCall then ownCall.conflict = true end
        log("FAILED", "detail=" .. string.format("%q", tostring(err)))
        stopLater("writer-hook-failure")
    end
end
local function onEquip(context, arg)
    guarded(function()
        if identity(context:get()) ~= target.actor then return end
        countEvent()
        local mode = arg:get()
        assert(math.type(mode) == "integer", "equip mode unavailable")
        local actor, sheath, main, socket = resolve()
        assert(actor, "equip target lost")
        local postStowed = mode == 1 and stowed(true, true) ~= nil
        local hand = mode == 0 and weaponOut(socket, "cudgel_r_hand", sheath, main)
        local floating = mode == 3 and weaponOut(socket, "dual_l_hand", sheath, main)
        local paired = writerPair and writerPair.post and not writerPair.propagation and writerPair.value == (mode == 1)
        writerPair = nil
        log("EQUIP_POST", "mode=" .. mode .. " socket=" .. socket .. " paired=" .. tostring(not not paired))
        if phase == "baseline" then
            if baselineStep == 1 and hand and paired then baselineStep = 2
            elseif baselineStep == 2 and floating and paired then baselineStep = 3
            elseif baselineStep == 3 and postStowed and paired then baselineStep = 4; log("BASELINE_PASS")
            else baselineStep = 0 end
        elseif phase == "test" then
            if not paired or not (postStowed or hand or floating) then stopLater("unexpected-equip"); return end
            if postStowed then
                if drawPending then
                    invalidate("late-sheath")
                    log("SHEATH_SKIP", "reason=draw-pending")
                else
                    schedule()
                end
            else
                invalidate("non-sheath")
                release()
                -- Floating can still belong to the older stow. Only verified InHand closes draw.
                if hand then drawPending = false end
            end
        end
    end)
end
local function hook(name, native, pre, post)
    local f = StaticFindObject(name)
    assert(valid(f) and f:type() == "UFunction" and f:GetFullName() == "Function " .. name
        and ((f:GetFunctionFlags() & 0x400) ~= 0) == native, "hook signature mismatch")
    local a, b
    if native then a, b = RegisterHook(name, pre, post) else a, b = RegisterHook(name, post) end
    hooks[#hooks + 1] = {path=name, pre=a, post=b}
    assert(math.type(a) == "integer" and math.type(b) == "integer" and a > 0 and b > 0
        and (a ~= b) == native, "hook IDs mismatch")
end
local function selectOne(name, predicate)
    local matches, selected = 0, nil
    local list = FindAllOf(name) or {}
    assert(#list <= 8, "lookup budget")
    for _, o in ipairs(list) do
        if valid(o) and predicate(o) then matches, selected = matches + 1, o end
    end
    assert(matches == 1, "expected one " .. name)
    return selected
end
local function start()
    local hud = selectOne("HUDMainUMG_BP_C", function(o) return o:IsInViewport() end)
    local pawn = hud:GetOwningPlayerPawn()
    assert(class(pawn) == "BlueprintGeneratedClass /Game/MainContent/Act/Character_BP/hilda_BP.hilda_BP_C", "pawn class")
    local actor = selectOne("HildaCudgel_BP_C", function(o)
        return class(o) == "BlueprintGeneratedClass " .. BASE and identity(o:GetOwner()) == identity(pawn)
    end)
    local main, sheath, mesh, root = actor.SkeletalMesh, actor.hilda_cudgel_sheath, pawn.Mesh, actor.RootComponent
    assert(valid(main) and valid(sheath) and valid(mesh) and valid(root)
        and identity(main) ~= identity(sheath), "missing cudgel components")
    assert(valid(main.SkeletalMesh) and path(main.SkeletalMesh) == WEAPONS .. "hilda_cudgel.hilda_cudgel"
        and valid(sheath.SkeletalMesh) and path(sheath.SkeletalMesh) == WEAPONS .. "hilda_cudgel_sheath.hilda_cudgel_sheath",
        "non-stock asset")
    local anim = mesh:GetAnimInstance()
    assert(valid(anim) and class(anim):match("%.hilda_AnimBP_C$"), "anim identity")
    target = {hud=identity(hud), hudPath=path(hud), pawn=identity(pawn), actor=identity(actor), actorPath=path(actor),
        main=identity(main), sheath=identity(sheath), mesh=identity(mesh), root=identity(root), anim=identity(anim),
        sheathAddress=tostring(sheath:GetAddress()), sheathAsset=identity(sheath.SkeletalMesh), mainAsset=identity(main.SkeletalMesh)}
    assert(stowed(true, false), "start with stock cudgel stowed")
    RegisterEndPlayPreHook(function(arg)
        guarded(function()
            local ended = identity(arg:get())
            if ended ~= target.actor and ended ~= target.pawn then return end
            retired = true
            stopLater("end-play")
        end)
    end)
    hook(DRAW, true, onDraw, function() end)
    hook(EQUIP, false, nil, onEquip)
    hook(VIS, true, function(c,v,p) onVisibility("pre",c,v,p) end, function(c,v,p) onVisibility("post",c,v,p) end)
    deadline = ExecuteInGameThreadWithDelay(120000, function() deadline = nil; stop("time-limit") end)
    assert(math.type(deadline) == "integer" and IsValidDelayedActionHandle(deadline), "timeout handle unavailable")
    phase = "baseline"
    log("BASELINE_START", "actor=" .. target.actor .. " sheath=" .. target.sheath)
end
local function arm()
    if phase == "idle" then start(); return end
    assert(phase == "baseline" and baselineStep == 4 and stowed(true, false), "baseline not passed")
    phase = "test"
    log("TEST_ARMED", "wait_for_fresh_sheath=true")
end
assert(EngineTickAvailable == true and type(RegisterEndPlayPreHook) == "function"
    and type(ExecuteInGameThreadWithDelay) == "function" and type(CancelDelayedAction) == "function"
    and type(IsValidDelayedActionHandle) == "function", "required scheduler or lifecycle capability unavailable")
local mods = {ModifierKey.CONTROL, ModifierKey.ALT}
assert(not IsKeyBindRegistered(Key.F9, mods) and not IsKeyBindRegistered(Key.F10, mods), "test chord occupied")
local function bind(key, fn)
    RegisterKeyBind(key, mods, function()
        if queued or stopping or phase == "done" then return end
        queued = true
        local ok = pcall(ExecuteInGameThread, function()
            queued = false
            if stopping or phase == "done" then return end
            local good, err = pcall(fn)
            if not good then log("FAILED", "detail=" .. string.format("%q", tostring(err))); stop("control-failure") end
        end, EGameThreadMethod.EngineTick)
        if not ok then stopLater("key-dispatch"); end
    end)
end
bind(Key.F9, arm)
bind(Key.F10, function() stop("user") end)
log("LOADED", "baseline_arm=Ctrl+Alt+F9 stop=Ctrl+Alt+F10 seconds=120")
