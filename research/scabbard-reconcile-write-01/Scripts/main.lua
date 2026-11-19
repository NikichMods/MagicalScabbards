-- SPDX-License-Identifier: MPL-2.0
local equipment = require("equipment")
local outgoing = require("outgoing")
local policy = require("reconcile")(250)
local makeVisibility = require("visibility")
local DRAW = "/Script/Genesis.BaseCharacterAnimInstance:BeginDoSkill"
local VIS = "/Script/Engine.SceneComponent:SetVisibility"
local HIDDEN = "/Script/Engine.SceneComponent:SetHiddenInGame"

local function log(event, detail)
    print("[ScabbardWrite01] " .. event .. " " .. (detail or "") .. "\n")
end

local controller, session, handle, loading, attempted, maskedIdentity, lastSample, windowIdentity
local hooks = {}
local epoch = 0

local function release(reason)
    epoch = epoch + 1
    policy.reset()
    attempted, maskedIdentity, lastSample, windowIdentity = nil, nil, nil, nil
    if controller and controller.active() then return controller.release(reason) end
    return not controller or not controller.pending()
end

local function sample(ticket)
    if ticket ~= session or loading then return end
    local ok, err = pcall(function()
        if controller.faulted() then
            release("writer-or-fault")
            return
        end
        local snapshot, now = equipment.read()
        local missed = lastSample and (not now or now < lastSample or now - lastSample > 250)
        lastSample = now
        if controller.active() then
            if missed or not equipment.supported(snapshot) or snapshot.identity ~= maskedIdentity
                or not controller.intact() then
                release("snapshot-changed")
            end
            return
        end
        if not equipment.supported(snapshot) then
            policy.reset()
            attempted, windowIdentity = nil, nil
            return
        end
        if missed or windowIdentity ~= snapshot.identity then
            windowIdentity = snapshot.identity
            log("WINDOW_START", ("ms=%.1f"):format(now))
        end
        if attempted and attempted ~= snapshot.identity then attempted = nil end
        if policy.observe(snapshot, now, equipment.read) ~= "SUPPRESSED" then
            attempted = nil
            return
        end
        if attempted == snapshot.identity then return end
        attempted = snapshot.identity
        local components, held
        local result, detail = outgoing.check(snapshot, equipment.read, function()
            log("CENSUS_BEGIN", ("ms=%.1f"):format(now))
            components = FindAllOf("SkeletalMeshComponent") or {}
            held = outgoing.heldComponents(components)
            return held
        end)
        if result ~= "CLEAR" then log("PASS_THROUGH", result .. " " .. detail); return end
        local rows = equipment.targets(snapshot, components)
        if not rows then log("PASS_THROUGH", "stock-kit-unconfirmed"); return end
        local transaction = epoch
        local function eligible(row)
            local current = equipment.read()
            return ticket == session and epoch == transaction and not loading and equipment.supported(current)
                and current.identity == snapshot.identity and current.registry == snapshot.registry
                and outgoing.inspect(current.pawn, current.mesh, current.selected, held) == "CLEAR"
                and equipment.resolve(row, true) ~= nil
        end
        if controller.mask(rows, eligible) then maskedIdentity = snapshot.identity end
    end)
    if not ok then
        log("FAULT", tostring(err))
        release("sample-failed")
        controller.invalidate()
    end
end

local function hook(path, pre, post)
    local fn = StaticFindObject(path)
    assert(equipment.name(fn) == "Function " .. path and (fn:GetFunctionFlags() & 0x400) ~= 0, path)
    local a, b = RegisterHook(path, pre, post)
    if math.type(a) == "integer" and math.type(b) == "integer" and a > 0 and b > 0 then
        hooks[path] = {a, b}
    else
        hooks[path] = false -- unknown registration state; block a second START
    end
    assert(hooks[path] and a ~= b, path)
end

local function watch(ticket, channel, stage, param, value, propagation)
    if ticket ~= session then return end
    local ok, err = pcall(function()
        controller.watch(channel, stage, equipment.id(param:get()), value:get(), propagation:get())
    end)
    if not ok then
        controller.invalidate()
        log("HOOK_FAULT", tostring(err))
    end
end

local function stop()
    local clean = release("stop")
    session = nil
    equipment.reset()
    if handle and (not IsValidDelayedActionHandle(handle) or CancelDelayedAction(handle)) then handle = nil end
    for path, ids in pairs(hooks) do
        if ids then
            local ok, result = pcall(UnregisterHook, path, ids[1], ids[2])
            if ok and result ~= false then hooks[path] = nil end
        end
    end
    log(clean and not handle and not next(hooks) and "CLEANED" or "CLEANUP_PENDING", "stop")
end

local function start()
    if session or handle or next(hooks) or (controller and controller.pending()) then return end
    local ticket = {}
    controller = makeVisibility(equipment.resolve, function(c, value) c:SetVisibility(value, false) end, log)
    session = ticket
    for _, entry in ipairs({{VIS, "visible"}, {HIDDEN, "hidden"}}) do
        local path, channel = entry[1], entry[2]
        hook(path, function(...) watch(ticket, channel, "pre", ...) end,
            function(...) watch(ticket, channel, "post", ...) end)
    end
    hook(DRAW, function(param)
        if session ~= ticket then return end
        local ok, err = pcall(function()
            if equipment.id(param:get()) == equipment.anim() then release("draw-pre") end
        end)
        if not ok then
            controller.invalidate()
            log("DRAW_FAULT", tostring(err))
        end
    end, function() end)
    handle = LoopInGameThreadWithDelay(100, function() sample(ticket) end)
    assert(math.type(handle) == "integer" and IsValidDelayedActionHandle(handle), "invalid loop handle")
    log("START", "stock-cudgel-only interval_ms=100")
end

local mods = {ModifierKey.CONTROL, ModifierKey.ALT}
assert(EngineTickAvailable and type(LoopInGameThreadWithDelay) == "function")
assert(not IsKeyBindRegistered(Key.F7, mods) and not IsKeyBindRegistered(Key.F8, mods), "test chord occupied")
RegisterLoadMapPreHook(function()
    loading = true
    release("load-map-pre")
    equipment.reset()
end)
RegisterLoadMapPostHook(function() loading = false end)
RegisterKeyBind(Key.F7, mods, function()
    ExecuteInGameThread(function()
        local ok, err = pcall(start)
        if not ok then log("START_FAILED", tostring(err)); stop() end
    end, EGameThreadMethod.EngineTick)
end)
RegisterKeyBind(Key.F8, mods, function() ExecuteInGameThread(stop, EGameThreadMethod.EngineTick) end)
