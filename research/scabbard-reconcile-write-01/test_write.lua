-- SPDX-License-Identifier: MPL-2.0
package.path = "Scripts/?.lua;" .. package.path
local VIS = "/Script/Engine.SceneComponent:SetVisibility"
local HIDDEN = "/Script/Engine.SceneComponent:SetHiddenInGame"
local DRAW = "/Script/Genesis.BaseCharacterAnimInstance:BeginDoSkill"
local CLOCK = "/Script/Engine.GameplayStatics:GetRealTimeSeconds"
local SC = "Class /Script/Engine.SkeletalMeshComponent"
local emit = print
local function fixture()
    local s = {now=0, scans=0, hides=0, restores=0, hooks={}, ticks={}, logs={}, keys={}, objects={}}
    local function object(kind, path, class)
        local o = {address=path, bVisible=true, bHiddenInGame=false, bHidden=false}
        function o:IsValid() return true end
        function o:GetAddress() return self.address end
        function o:GetFullName() return kind .. " " .. path end
        function o:GetClass() return {IsValid=function() return true end, GetFullName=function() return class end} end
        function o:GetOwner() return self.owner end
        function o:GetAttachParent() return self.parent end
        function o:GetAttachSocketName() return {ToString=function() return self.socket or "None" end} end
        function o:IsActorBeingDestroyed() return false end
        s.objects[path] = o
        return o
    end
    local function param(value) return {get=function() return value end} end
    function s.event(path, stage, component, value, propagate)
        local hook = s.hooks[path]
        if hook then hook[stage](param(component), param(value), param(propagate)) end
    end
    local function component(path, asset, owner, parent, socket)
        local c = object("Mesh", path, SC)
        c.owner, c.parent, c.socket = owner, parent, socket
        if asset then c.SkeletalMesh = object("SkeletalMesh",
            "/Game/MainContent/Assets/creature/03_weapon/" .. asset .. "." .. asset) end
        function c:SetVisibility(value, propagate)
            assert(self.target and not propagate, "unexpected write target")
            if s.fail == self and not value then error("injected setter failure") end
            s.event(VIS, 1, self, value, propagate)
            if not value then s.hides = s.hides + 1
            elseif not self.bVisible then s.restores = s.restores + 1 end
            self.bVisible = value
            if not s.missingPost then s.event(VIS, 2, self, value, propagate) end
            if not value and s.afterHide then s.afterHide(self) end
        end
        return c
    end
    local pawn = object("Hilda", "pawn",
        "BlueprintGeneratedClass /Game/MainContent/Act/Character_BP/hilda_BP.hilda_BP_C")
    local mesh = component("pawn.CharacterMesh0", nil, pawn)
    pawn.Mesh = mesh
    local anim = object("Anim", "anim", "BlueprintGeneratedClass Hilda.hilda_AnimBP_C")
    local none = {ToString=function() return "None" end}
    anim.GetDoingSkill = function() return none end
    anim.GetToDoSkill = anim.GetDoingSkill
    mesh.GetAnimInstance = function() return anim end
    local hud = object("HUD", "hud")
    hud.IsInViewport = function() return true end
    hud.GetOwningPlayerPawn = function() return pawn end
    local function actor(short, mount, mode, actorName)
        local p = "/Game/MainContent/Act/Item_BP/" .. short
        local a = object("Actor", actorName, "BlueprintGeneratedClass " .. p .. "." .. short .. "_C")
        a.owner, a.equipMode = pawn, mode
        a.RootComponent = component(actorName .. ".root", nil, a, mesh, mount)
        return a
    end
    local cudgel = actor("HildaCudgel_BP", "scabbard_a", 1, "cudgel")
    local staff = actor("HildaStaff_BP", "scabbard_b", 1, "staff")
    local spear = actor("HildaSpear_Unuse_BP", "scabbard_a", 2, "spear-unuse")
    local dual = actor("HildaDual_Unuse_BP", "scabbard_b", 2, "dual-unuse")
    local function weaponMesh(a, field, asset)
        a[field] = component(a.address .. "." .. field, asset, a, a.RootComponent)
        return a[field]
    end
    s.held = weaponMesh(cudgel, "SkeletalMesh", "hilda_cudgel")
    local staffHeld = weaponMesh(staff, "SkeletalMesh", "hilda_staff")
    s.held.bVisible, staffHeld.bVisible = false, false
    pawn.scabbard_a = component("pawn.a", "hilda_scabbard_A", pawn, mesh, "scabbard_a")
    pawn.scabbard_b = component("pawn.b", "hilda_scabbard_B", pawn, mesh, "scabbard_b")
    s.targets = {pawn.scabbard_a, pawn.scabbard_b, weaponMesh(cudgel, "hilda_cudgel_sheath", "hilda_cudgel_sheath"),
        weaponMesh(staff, "hilda_staff_sheath", "hilda_staff_sheath"),
        weaponMesh(spear, "SkeletalMesh", "hilda_spear_unuse"), weaponMesh(dual, "SkeletalMesh", "hilda_dual_unuse")}
    s.outgoing = weaponMesh(actor("HildaCudgel_BP", "cudgel_r_hand", 0, "old"), "SkeletalMesh", "hilda_cudgel")
    s.outgoing.bVisible = false
    s.pickup = weaponMesh(actor("HildaCudgel_BP", "None", 0, "pickup"), "SkeletalMesh", "hilda_cudgel")
    s.pickup.owner.owner, s.pickup.parent.parent = nil, nil
    s.components = {s.held, staffHeld, s.outgoing, s.pickup}
    for _, target in ipairs(s.targets) do target.target = true; s.components[#s.components + 1] = target end
    s.second, s.hand = 4, 7
    local global = object("GameGlobal", "/Script/Genesis.Default__GameGlobal")
    global.GetInUseWeaponType = function(_, _, slot) return slot == 0 and 2 or s.second end
    global.GetInHandWeaponType = function() return s.hand end
    global.GetWeaponObject = function(_, _, kind, slot)
        if kind == 2 and slot == 1 then return cudgel end
        if kind == 4 and slot == 0 then return staff end
    end
    object("GameplayStatics", "/Script/Engine.Default__GameplayStatics")
    setmetatable(object("Function", CLOCK), {__call=function() return s.now / 1000 end})
    for _, path in ipairs({VIS, HIDDEN, DRAW}) do
        object("Function", path).GetFunctionFlags = function() return 0x400 end
    end
    StaticFindObject = function(path) return s.objects[path] end
    FindAllOf = function(class)
        if class == "HUDMainUMG_BP_C" then return {hud} end
        assert(class == "SkeletalMeshComponent")
        s.scans = s.scans + 1
        if s.onCensus then s.onCensus() end
        return s.components
    end
    EngineTickAvailable, EGameThreadMethod = true, {EngineTick=1}
    Key, ModifierKey = {F7=7,F8=8}, {CONTROL=1,ALT=2}
    IsKeyBindRegistered = function() return false end
    RegisterKeyBind = function(key, _, fn) s.keys[key] = fn end
    ExecuteInGameThread = function(fn) fn() end
    RegisterLoadMapPreHook = function(fn) s.loadPre = fn end
    RegisterLoadMapPostHook = function(fn) s.loadPost = fn end
    RegisterHook = function(path, pre, post) s.hooks[path]={pre,post}; return 1,2 end
    UnregisterHook = function(path) s.hooks[path]=nil end
    LoopInGameThreadWithDelay = function(ms, callback)
        assert(ms == 100)
        s.ticks[#s.ticks+1] = {callback=callback, live=true}
        return #s.ticks
    end
    IsValidDelayedActionHandle = function(id) return s.ticks[id].live end
    CancelDelayedAction = function(id) s.ticks[id].live = false; return true end
    print = function(line) s.logs[#s.logs+1] = line end
    dofile("Scripts/main.lua")
    s.keys[7]()
    function s.tick(t) s.now=t; s.ticks[#s.ticks].callback() end
    function s.arm(t)
        for at = t, t + 2900, 100 do s.tick(at) end
        s.tick(t+2999)
    end
    function s.draw() s.event(DRAW, 1, anim) end
    function s.has(event)
        for _, log in ipairs(s.logs) do if log:find(event, 1, true) then return true end end
        return false
    end
    function s.visible()
        for _, target in ipairs(s.targets) do assert(target.bVisible) end
        assert(not s.held.bVisible and s.pickup.bVisible)
    end
    s.pawn = pawn
    return s
end

local s = fixture()
s.arm(0); assert(s.hides == 0 and s.scans == 0)
s.tick(3000); assert(s.hides == 6 and s.scans == 1 and s.has("HIDDEN"))
for t=3100,4000,100 do s.tick(t) end
assert(s.scans == 1 and s.restores == 0)
s.draw(); assert(s.restores == 6 and s.has("draw-pre")); s.visible()
s.arm(4100); s.tick(7100); assert(s.hides == 12)
s.loadPre(); assert(s.restores == 12 and s.has("load-map-pre")); s.visible()
s.tick(7200); s.pawn.address = "new"; s.loadPost()
s.arm(7300); assert(s.hides == 12); s.tick(10300); assert(s.hides == 18)
s.keys[8](); assert(s.restores == 18 and s.has("CLEANED")); s.visible()
local stale = s.ticks[1].callback
s.keys[7](); stale(); assert(s.scans == 3)

s = fixture(); s.arm(0); s.draw(); s.tick(3000); assert(s.hides == 0)
s = fixture(); s.arm(0); s.pawn.address = "new"; s.tick(3000); assert(s.hides == 0 and s.scans == 0)
s = fixture(); s.outgoing.bVisible = true; s.arm(0); s.tick(3000)
assert(s.hides == 0 and s.has("BLOCKED"))
s.tick(3100); assert(s.scans == 1)
s = fixture(); s.onCensus = function() s.second = 5 end; s.arm(0); s.tick(3000)
assert(s.hides == 0 and s.has("snapshot-changed-during-census"))
s = fixture(); s.targets[1].owner = nil; s.arm(0); s.tick(3000)
assert(s.hides == 0 and s.has("stock-kit-unconfirmed"))
s = fixture(); s.missingPost = true; s.arm(0); s.tick(3000)
assert(s.hides == 0 and s.has("PROBE_FAILED"))

s = fixture(); s.arm(0); s.tick(3000)
local a = s.targets[1]
s.event(VIS, 1, a, false, false); s.event(VIS, 2, a, false, false)
s.tick(3100); assert(not a.bVisible and s.restores == 5 and s.has("WRITER"))
s.keys[8](); assert(s.has("CLEANED"))
s = fixture(); s.arm(0); s.tick(3000); a = s.targets[1]
s.event(HIDDEN, 1, a, true, false); a.bHiddenInGame=true; s.event(HIDDEN, 2, a, true, false)
s.tick(3100); assert(a.bHiddenInGame and s.restores == 6); s.visible()
s = fixture(); s.fail=s.targets[3]; s.arm(0); s.tick(3000)
assert(s.hides == 2 and s.restores == 2 and s.has("WRITE_FAILED")); s.visible()
s = fixture(); s.afterHide=function() s.outgoing.bVisible=true end; s.arm(0); s.tick(3000)
assert(s.hides == 1 and s.restores == 1); s.visible()
s = fixture(); s.afterHide=function() s.second=5 end; s.arm(0); s.tick(3000)
assert(s.hides == 1 and s.restores == 1); s.visible()
s = fixture(); s.afterHide=function() if s.hides == 6 then s.second=5 end end
s.arm(0); s.tick(3000)
assert(s.hides == 6 and s.restores == 6 and not s.has("HIDDEN targets")); s.visible()
s = fixture(); s.arm(0); s.tick(3000); s.second=5; s.tick(3100)
assert(s.restores == 6 and s.has("snapshot-changed")); s.visible()
s = fixture(); s.arm(0); s.tick(3000); s.ticks[1].callback()
assert(s.hides == 6); s.tick(3400); assert(s.restores == 6); s.visible()
s = fixture(); s.arm(0); s.tick(3000); s.targets[1].address="replacement"
s.tick(3100); assert(s.restores == 5 and s.has("CLEANUP_PENDING"))
assert(not s.targets[1].bVisible); s.keys[8](); assert(not s.has("CLEANED"))
emit("PASS write integration: timing, admission, outgoing, writers, rollback, draw, reload, STOP and stale loop")
