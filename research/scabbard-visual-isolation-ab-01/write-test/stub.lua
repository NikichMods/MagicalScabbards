-- SPDX-License-Identifier: MPL-2.0
-- Run with stock Lua 5.4: lua stub.lua path/to/Scripts/main.lua
local file = assert(io.open(assert(arg[1]), "r"))
local source = file:read("*a")
file:close()
local function new()
    local s = {keys={}, hooks={}, logs={}, timers={}, cancelled={}, work={}, writes={}, reads=0}
    local env = setmetatable({}, {__index=_G})
    local function obj(name, address, class)
        return {IsValid=function() return true end, GetFullName=function() return name end,
            GetAddress=function() return address end,
            GetClass=function() return {GetFullName=function() return class end} end}
    end
    local function param(v) return {get=function() return v end} end
    local function name(v) return {ToString=function() return v end} end
    local base = "/Game/MainContent/Act/Item_BP/HildaCudgel_BP.HildaCudgel_BP_C"
    local asset = "/Game/MainContent/Assets/creature/03_weapon/"
    local hud = obj("HUD /World/HUD", 1)
    local pawn = obj("Pawn /World/Hilda", 2, "BlueprintGeneratedClass /Game/MainContent/Act/Character_BP/hilda_BP.hilda_BP_C")
    local actor = obj("Actor /World/Cudgel", 3, "BlueprintGeneratedClass " .. base)
    local mesh, root = obj("Mesh /World/Hilda.Mesh", 4), obj("Root /World/Cudgel.Root", 5)
    local main, sheath = obj("Component /World/Cudgel.Main", 6), obj("Component /World/Cudgel.Sheath", 7)
    local anim = obj("Anim /World/Hilda.Anim", 8, "Anim /Game/hilda_AnimBP.hilda_AnimBP_C")
    s.socket, s.pawn, s.actor, s.sheath, s.main, s.hudPawn = "scabbard_a", pawn, actor, sheath, main, pawn
    s.skill = "hilda_cudgel_atk1_idle"
    pawn.Mesh, actor.RootComponent, actor.SkeletalMesh, actor.hilda_cudgel_sheath = mesh, root, main, sheath
    actor.bHidden, actor.equipMode = false, 1
    main.bVisible, sheath.bVisible, main.bHiddenInGame, sheath.bHiddenInGame = false, true, false, false
    main.SkeletalMesh = obj("SkeletalMesh " .. asset .. "hilda_cudgel.hilda_cudgel", 9)
    sheath.SkeletalMesh = obj("SkeletalMesh " .. asset .. "hilda_cudgel_sheath.hilda_cudgel_sheath", 10)
    pawn.bHidden = false
    for i, label in ipairs({"A", "B"}) do
        local part = obj("Component /World/Hilda.Scabbard" .. label, 10+i, "Class /Script/Engine.SkeletalMeshComponent")
        local socket = "scabbard_" .. label:lower()
        part.bVisible, part.bHiddenInGame = true, false
        part.GetOwner = function() return pawn end
        part.GetAttachParent = function() return mesh end
        part.GetAttachSocketName = function() return name(socket) end
        local meshName = "hilda_scabbard_" .. label
        part.SkeletalMesh = obj("SkeletalMesh " .. asset .. meshName .. "." .. meshName, 12+i)
        pawn[socket], s[label] = part, part
    end
    mesh.GetAnimInstance = function() return anim end
    hud.GetOwningPlayerPawn = function() return s.hudPawn end
    hud.IsInViewport = function() return true end
    actor.GetOwner = function() return s.actorOwner or pawn end
    sheath.GetOwner = function() return actor end
    main.GetOwner = sheath.GetOwner
    root.GetAttachParent = function() return mesh end
    root.GetAttachSocketName = function() return name(s.socket) end
    anim.GetToDoSkill = function() return name(s.skill) end
    env.EngineTickAvailable = true
    env.EGameThreadMethod = {EngineTick=1}
    env.Key, env.ModifierKey = {F7=7,F8=8}, {CONTROL=1,ALT=2}
    env.print = function(line) s.logs[#s.logs+1] = line end
    env.StaticFindObject = function(p)
        s.reads = s.reads + 1
        if p == "/World/HUD" then return hud end
        if p == "/World/Cudgel" then return actor end
        local f = obj("Function " .. p, 20)
        f.type = function() return "UFunction" end
        f.GetFunctionFlags = function() return p:match(":EquipModeChange$") and 0 or 0x400 end
        return f
    end
    env.FindAllOf = function(n) return n == "HUDMainUMG_BP_C" and {hud} or {actor} end
    env.IsKeyBindRegistered = function() return false end
    env.RegisterKeyBind = function(k, _, f) s.keys[k] = f end
    env.RegisterHook = function(p, a, b)
        s.hooks[p:match(":(.+)$")] = {a,b}
        if b then return 1,2 end
        return 3,3
    end
    env.UnregisterHook = function() s.unhooks = (s.unhooks or 0)+1 end
    env.RegisterLoadMapPreHook = function(f) s.loadMap = f end
    env.RegisterEndPlayPreHook = function(f) s.endPlay = f end
    env.ExecuteInGameThread = function(f) s.work[#s.work+1] = f end
    env.ExecuteInGameThreadWithDelay = function(ms,f)
        local i=#s.timers+1
        s.timers[i]={ms=ms,call=f,alive=true}
        return i
    end
    env.IsValidDelayedActionHandle = function(i) return s.timers[i].alive end
    env.CancelDelayedAction = function(i)
        if s.rejectCancel then return false end
        s.timers[i].alive=false; s.cancelled[#s.cancelled+1]=i
        return true
    end
    function s.flush()
        while #s.work>0 do table.remove(s.work,1)() end
    end
    function s.press(k) s.keys[k](); s.flush() end
    function s.fire(i)
        s.timers[i].alive=false
        s.timers[i].call()
        s.flush()
    end
    function s.emit(label, field, value, skip)
        local part = s[label]
        local property = field == "SetVisibility" and "bVisible" or "bHiddenInGame"
        local pair = s.hooks[field]
        if not skip then assert(pair[1](param(part),param(value),param(false))==nil) end
        part[property] = value
        if not skip then assert(pair[2](param(part),param(value),param(false))==nil) end
    end
    for _, label in ipairs({"A", "B"}) do
        s[label].SetVisibility = function(_, value, propagation)
            assert(propagation == false)
            s.writes[#s.writes+1] = label .. tostring(value)
            s.emit(label,"SetVisibility",value,s.noDelivery)
            if s.partial and not value then error("setter after write") end
        end
    end
    function s.has(str) return table.concat(s.logs):find(str,1,true) ~= nil end
    assert(load(source,"candidate","t",env))()
    return s
end
local function ready()
    local s = new()
    s.press(7)
    assert(s.has("event=BASELINE") and #s.writes == 0)
    return s
end
local function hidden()
    local s = ready()
    s.press(7)
    assert(not s.A.bVisible and s.B.bVisible and #s.writes == 2)
    return s
end
do
    local s = hidden()
    s.press(7); assert(s.A.bVisible and s.B.bVisible)
    s.press(7); assert(s.A.bVisible and not s.B.bVisible)
    s.press(7); assert(s.A.bVisible and s.B.bVisible and s.has("event=CLEANED"))
    assert(table.concat(s.writes,",") == "Atrue,Afalse,Atrue,Btrue,Bfalse,Btrue" and s.unhooks == 4)
    assert(s.sheath.bVisible and not s.main.bVisible and not s.timers[1].alive)
end
do
    local s = hidden()
    s.press(8)
    assert(s.A.bVisible and s.has("event=CLEANED") and s.has("owned=nil"))
    s.press(7); s.fire(1)
    assert(#s.writes == 3 and s.unhooks == 4)
end
do
    local s = hidden()
    s.keys[8]() -- Foreign same-value setter while STOP is queued.
    s.emit("A","SetVisibility",false); s.flush()
    assert(#s.writes == 2 and not s.A.bVisible and s.has("event=FOREIGN") and s.has("event=CLEANED"))
end
do
    local s = hidden()
    s.emit("A","SetHiddenInGame",true); s.flush()
    assert(s.A.bVisible and s.A.bHiddenInGame and s.has("foreign-writer") and s.has("event=CLEANED"))
end
for _, retire in ipairs({
    function(s) s.endPlay({get=function()return s.pawn end}) end,
    function(s) s.loadMap() end,
    function(s) s.pawn.scabbard_a=s.B end,
    function(s) s.hudPawn=nil end,
}) do
    local s = hidden()
    s.keys[8](); retire(s); s.flush()
    assert(#s.writes == 2 and s.has("event=CLEANUP_PENDING") and s.unhooks == 4)
end
do
    local s = ready()
    s.noDelivery = true; s.press(7)
    assert(s.A.bVisible and #s.writes == 1 and s.has("setter ownership unverified") and not s.has("event=HIDDEN"))
end
do
    local s = ready()
    s.partial = true; s.press(7)
    assert(s.A.bVisible and #s.writes == 3 and s.has("event=FAILED") and s.has("event=CLEANED"))
end
do
    local s = ready()
    s.A.GetOwner = function() return s.actor end
    s.press(7)
    assert(#s.writes == 0 and s.has("invalid A") and s.has("event=CLEANED"))
end
do
    local s = hidden()
    s.fire(1)
    assert(s.A.bVisible and s.has("time-limit") and s.has("event=CLEANED"))
end
print("PASS: A/B isolation, STOP, same-value foreign writer, native hidden writer, identity, EndPlay, LoadMap, missing delivery, partial write, timeout and cleanup")
