-- SPDX-License-Identifier: MPL-2.0
-- Host seam smoke test. The stubs do not establish in-game API behavior.
package.path = "Scripts/?.lua;" .. package.path
local logs, keys, ticks = {}, {}, {}
local pre, loadPre, loadPost
local scans, getterCalls, now, weapon, hand = 0, 0, 0, 7, 7
local emit = print
print = function(line) logs[#logs + 1] = line end

local function object(fullName, className)
    local obj = {}
    function obj:IsValid() return true end
    function obj:GetFullName() return fullName end
    function obj:GetAddress() return fullName end
    function obj:GetClass() return object(className) end
    return obj
end

local anim = object("Anim live", "BlueprintGeneratedClass hilda.hilda_AnimBP_C")
local none = {ToString=function() return "None" end}
anim.GetDoingSkill = function() return none end
anim.GetToDoSkill = anim.GetDoingSkill
local pawn = object("Hilda local", "BlueprintGeneratedClass /Game/MainContent/Act/Character_BP/hilda_BP.hilda_BP_C")
pawn.bHidden = false
local mesh = object("Mesh local.CharacterMesh0", "Class /Script/Engine.SkeletalMeshComponent")
pawn.Mesh = mesh
mesh.bVisible, mesh.bHiddenInGame = true, false
mesh.GetOwner = function() return pawn end
mesh.GetAnimInstance = function() return anim end
local hud = object("HUD local.hud")
hud.IsInViewport = function() return true end
hud.GetOwningPlayerPawn = function() return pawn end

local draw = "/Script/Genesis.BaseCharacterAnimInstance:BeginDoSkill"
local clock = "/Script/Engine.GameplayStatics:GetRealTimeSeconds"
local fn = object("Function " .. draw)
fn.GetFunctionFlags = function() return 0x400 end
local timer = setmetatable(object("Function " .. clock), {__call=function() return now / 1000 end})
local cdo = object("GameplayStatics /Script/Engine.Default__GameplayStatics")
local global = object("GameGlobal /Script/Genesis.Default__GameGlobal")
global.GetInUseWeaponType = function(_, _, slot)
    getterCalls = getterCalls + 1
    return slot == 0 and weapon or 7
end
global.GetInHandWeaponType = function() getterCalls = getterCalls + 1; return hand end
global.GetWeaponObject = function() getterCalls = getterCalls + 1; return nil end
local objects = {[draw]=fn, [clock]=timer, ["/Script/Engine.Default__GameplayStatics"]=cdo,
    ["/Script/Genesis.Default__GameGlobal"]=global, ["local.hud"]=hud}
StaticFindObject = function(path) return objects[path] end
FindAllOf = function(className)
    assert(className == "HUDMainUMG_BP_C")
    scans = scans + 1
    return {hud}
end

EngineTickAvailable, EGameThreadMethod = true, {EngineTick=1}
Key, ModifierKey = {F7=7,F8=8}, {CONTROL=1,ALT=2}
IsKeyBindRegistered = function() return false end
RegisterKeyBind = function(key, _, fn) keys[key] = fn end
ExecuteInGameThread = function(fn, method) assert(method == 1); fn() end
RegisterLoadMapPreHook = function(fn) loadPre = fn end
RegisterLoadMapPostHook = function(fn) loadPost = fn end
RegisterHook = function(path, callback)
    assert(path == draw and not pre)
    pre = callback
    return 1, 2
end
UnregisterHook = function(path, a, b) assert(path == draw and a == 1 and b == 2); pre = nil end
LoopInGameThreadWithDelay = function(delay, fn)
    assert(delay == 100)
    local handle = #ticks + 1
    ticks[handle] = {live=true, call=fn}
    return handle
end
IsValidDelayedActionHandle = function(handle) return ticks[handle].live end
CancelDelayedAction = function(handle) ticks[handle].live = false; return true end

dofile("Scripts/main.lua")
keys[7]()
keys[7]()
assert(#ticks == 1)
ticks[1].call()
assert(scans == 1 and getterCalls == 3 and logs[#logs]:find("UNKNOWN", 1, true))
for kind = 0, 5 do
    weapon, now = kind, now + 100
    ticks[1].call()
    assert(logs[#logs]:find("UNKNOWN", 1, true) and logs[#logs]:find("slots=", 1, true))
end
assert(scans == 1 and getterCalls == 33)
local before = #logs
pre({get=function() return object("Anim foreign") end})
assert(#logs == before)
pre({get=function() return anim end})
assert(logs[#logs]:find("SKILL_PRE", 1, true))
hand, now = 3, now + 100
ticks[1].call()
assert(logs[#logs]:find("DRAWN", 1, true))
loadPre()
local calls = getterCalls
ticks[1].call()
assert(getterCalls == calls and logs[#logs]:find("loading", 1, true))
loadPost()
ticks[1].call()
assert(scans == 2 and getterCalls == calls + 5)
keys[8]()
assert(not pre and not ticks[1].live and logs[#logs]:find("writes=0", 1, true))
keys[7]()
before = #logs
ticks[1].call()
assert(#logs == before and getterCalls == calls + 5)
ticks[2].call()
assert(getterCalls == calls + 10)
keys[8]()
for _, line in ipairs(logs) do assert(not line:find("WOULD_HIDE", 1, true)) end

local item = "/Game/MainContent/Act/Item_BP/HildaCudgel_BP"
local actor = object("Cudgel selected", "BlueprintGeneratedClass " .. item .. ".HildaCudgel_BP_C")
local root = object("Root cudgel")
local function linked(o, owner, parent, socketName)
    o.GetOwner = function() return owner end
    o.GetAttachParent = function() return parent end
    o.GetAttachSocketName = function() return {ToString=function() return socketName end} end
    return o
end
local function component(resource)
    local o = linked(object("Component " .. resource, "Class /Script/Engine.SkeletalMeshComponent"), actor, root, "None")
    o.SkeletalMesh = object("SkeletalMesh /Game/MainContent/Assets/creature/03_weapon/" .. resource .. "." .. resource)
    return o
end
actor.RootComponent = linked(root, actor, mesh, "scabbard_a")
root.bVisible, root.bHiddenInGame = true, false
actor.GetOwner = function() return pawn end
actor.IsActorBeingDestroyed = function() return false end
actor.bHidden, actor.equipMode = false, 1
actor.SkeletalMesh = component("hilda_cudgel")
actor.SkeletalMesh.bVisible, actor.SkeletalMesh.bHiddenInGame = false, false
actor.hilda_cudgel_sheath = component("hilda_cudgel_sheath")
global.GetWeaponObject = function(_, _, kind, slot)
    assert(kind == 2)
    if slot == 1 then return actor end
end
weapon, hand = 2, 7
keys[7]()
for t = 0, 2900, 100 do now = t; ticks[3].call() end
assert(logs[#logs]:find("STOWED decision=PASS-THROUGH", 1, true))
now = 3000
ticks[3].call()
assert(logs[#logs]:find("WOULD_HIDE", 1, true))
pre({get=function() return anim end})
now = 3100
ticks[3].call()
assert(logs[#logs]:find("STOWED decision=PASS-THROUGH", 1, true))
actor.SkeletalMesh.bVisible = true
now = 3200
ticks[3].call()
assert(logs[#logs]:find("UNKNOWN", 1, true))
keys[8]()
emit("PASS observer mock: six incomplete slots, stowed cudgel, held, local pre, load, stop and stale callback")
