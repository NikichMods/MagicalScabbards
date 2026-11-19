-- SPDX-License-Identifier: MPL-2.0
-- Run with stock Lua 5.4: lua stub.lua path/to/Scripts/main.lua
local file = assert(io.open(assert(arg[1]), "r"))
local source = file:read("*a")
file:close()
local function new()
    local s = {keys={}, hooks={}, logs={}, work={}, writes={}, reads=0}
    local env = setmetatable({}, {__index=_G})
    local function obj(name, address, class)
        return {IsValid=function() return true end, GetFullName=function() return name end,
            GetAddress=function() return address end,
            GetClass=function() return {IsValid=function() return true end, GetFullName=function() return class end} end}
    end
    local function param(v) return {get=function() return v end} end
    local function name(v) return {ToString=function() return v end} end
    local base = "/Game/MainContent/Act/Item_BP/HildaCudgel_BP.HildaCudgel_BP_C"
    local asset = "/Game/MainContent/Assets/creature/03_weapon/"
    local hud = obj("HUD /World/HUD", 1)
    local pawn = obj("Pawn /World/Hilda", 2, "BlueprintGeneratedClass /Game/MainContent/Act/Character_BP/hilda_BP.hilda_BP_C")
    local actor = obj("Actor /World/Cudgel", 3, "BlueprintGeneratedClass " .. base)
    local mesh, root = obj("Mesh /World/Hilda.CharacterMesh0", 4, "Class /Script/Engine.SkeletalMeshComponent"), obj("Root /World/Cudgel.Root", 5)
    local main, sheath = obj("Component /World/Cudgel.Main", 6, "Class /Script/Engine.SkeletalMeshComponent"), obj("Component /World/Cudgel.Sheath", 7, "Class /Script/Engine.SkeletalMeshComponent")
    local anim = obj("Anim /World/Hilda.Anim", 8, "Anim /Game/hilda_AnimBP.hilda_AnimBP_C")
    s.socket, s.pawn, s.actor, s.sheath, s.main, s.hudPawn = "scabbard_a", pawn, actor, sheath, main, pawn
    s.skill, s.anim = "None", anim
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
    mesh.bVisible, root.bVisible = true, true
    mesh.bHiddenInGame, root.bHiddenInGame = false, false
    mesh.GetOwner = function() return pawn end
    root.GetOwner = function() return actor end
    main.GetAttachParent = function() return root end
    sheath.GetAttachParent = main.GetAttachParent
    main.GetAttachSocketName = function() return name("None") end
    sheath.GetAttachSocketName = main.GetAttachSocketName
    local actors, objects = {HildaCudgel_BP_C={actor}}, {["/World/Cudgel"]=actor}
    for i, spec in ipairs({
        {"spear","HildaSpear_Unuse_BP","SkeletalMesh","hilda_spear_unuse","scabbard_a",2},
        {"staff","HildaStaff_BP","hilda_staff_sheath","hilda_staff_sheath","scabbard_b",1},
        {"dual","HildaDual_Unuse_BP","SkeletalMesh","hilda_dual_unuse","scabbard_b",2},
    }) do
        local label, n, property, meshName, attach, mode = table.unpack(spec)
        local a = obj("Actor /World/" .. n, 20+i*4,
            "BlueprintGeneratedClass /Game/MainContent/Act/Item_BP/" .. n .. "." .. n .. "_C")
        local r = obj("SceneComponent /World/" .. n .. ".DefaultSceneRoot", 21+i*4)
        local c = obj("SkeletalMeshComponent /World/" .. n .. "." .. property, 22+i*4,
            "Class /Script/Engine.SkeletalMeshComponent")
        a.RootComponent, a[property], a.equipMode, a.bHidden = r, c, mode, false
        a.GetOwner = function() return pawn end
        r.GetOwner = function() return a end
        r.GetAttachParent = function() return mesh end
        r.GetAttachSocketName = function() return name(attach) end
        r.bVisible, r.bHiddenInGame = true, false
        c.GetOwner = r.GetOwner
        c.GetAttachParent = function() return r end
        c.GetAttachSocketName = main.GetAttachSocketName
        c.bVisible, c.bHiddenInGame = true, false
        c.SkeletalMesh = obj("SkeletalMesh " .. asset .. meshName .. "." .. meshName, 23+i*4)
        s[label], s[label.."Actor"] = c, a
        actors[n .. "_C"], objects["/World/" .. n] = {a}, a
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
    anim.GetDoingSkill = anim.GetToDoSkill
    env.EngineTickAvailable = true
    env.EGameThreadMethod = {EngineTick=1}
    env.Key, env.ModifierKey = {F7=7,F8=8}, {CONTROL=1,ALT=2}
    env.print = function(line) s.logs[#s.logs+1] = line end
    env.StaticFindObject = function(p)
        s.reads = s.reads + 1
        if p == "/World/HUD" then return hud end
        if objects[p] then return objects[p] end
        local f = obj("Function " .. p, 20)
        f.type = function() return "UFunction" end
        f.GetFunctionFlags = function() return (p:match(":EquipModeChange$") or p:find(":BndEvt__",1,true)) and 0 or 0x400 end
        return f
    end
    s.components = {main, sheath, s.A, s.B, s.spear, s.staff, s.dual}
    for _, c in ipairs(s.components) do
        objects[c:GetFullName():match("^[^ ]+ (.+)$")] = c
    end
    function s.addComponent(resource, localOwner, packageRoot)
        local index = #s.components
        local path = "/World/Extra" .. index
        local c = obj("Component " .. path, 100+index, "Class /Script/Engine.SkeletalMeshComponent")
        c.SkeletalMesh = obj("SkeletalMesh " .. (packageRoot or asset) .. resource .. "." .. resource, 200+index)
        c.GetOwner = function() return localOwner and pawn or actor end
        c.GetAttachParent = function() return mesh end
        c.GetAttachSocketName = function() return name("scabbard_a") end
        c.bVisible, c.bHiddenInGame = true, false
        c.SetVisibility = function() error("unexpected catalogue write") end
        s.components[#s.components+1], objects[path] = c, c
        return c
    end
    env.FindAllOf = function(n)
        if n == "SkeletalMeshComponent" then
            s.scans = (s.scans or 0)+1
            return s.components
        end
        return n == "HUDMainUMG_BP_C" and {hud} or actors[n]
    end
    env.IsKeyBindRegistered = function() return false end
    env.RegisterKeyBind = function(k, _, f) s.keys[k] = f end
    env.RegisterHook = function(p, a, b)
        s.hooks[p:match(":(.+)$")] = {a,b}
        if b then return 1,2 end
        return 3,3
    end
    env.UnregisterHook = function() s.unhooks = (s.unhooks or 0)+1 end
    env.RegisterLoadMapPreHook = function(f) s.loadMap = f end
    env.RegisterLoadMapPostHook = function(f) s.loadPost = f end
    env.RegisterEndPlayPreHook = function(f) s.endPlay = f end
    env.ExecuteInGameThread = function(f) s.work[#s.work+1] = f end
    s.timers = {}
    env.ExecuteInGameThreadWithDelay = function(ms, fn)
        assert(ms == 2000)
        local i = #s.timers + 1
        s.timers[i] = {active=true, run=fn}
        return i
    end
    env.IsValidDelayedActionHandle = function(i) return s.timers[i].active end
    env.CancelDelayedAction = function(i)
        if not s.rejectCancel then s.timers[i].active = false end
    end
    function s.fire(i)
        s.timers[i].active = false
        s.timers[i].run()
        s.flush()
    end
    function s.flush()
        while #s.work>0 do table.remove(s.work,1)() end
    end
    function s.press(k) s.keys[k](); s.flush() end
    function s.emit(label, field, value, skip)
        local part = s[label]
        local property = field == "SetVisibility" and "bVisible" or "bHiddenInGame"
        local pair = s.hooks[field]
        if not skip then assert(pair[1](param(part),param(value),param(false))==nil) end
        part[property] = value
        if not skip then assert(pair[2](param(part),param(value),param(false))==nil) end
    end
    for _, label in ipairs({"sheath", "A", "B", "spear", "staff", "dual"}) do
        s[label].SetVisibility = function(_, value, propagation)
            assert(propagation == false)
            s.writes[#s.writes+1] = label .. tostring(value)
            if s.rejectRestore == label and value then error("restore refused") end
            s.emit(label,"SetVisibility",value,s.noDelivery == label or (s.missingHide == label and not value))
            if s.partial == label and not value then error("setter after write") end
        end
    end
    function s.has(str) return table.concat(s.logs):find(str,1,true) ~= nil end
    assert(load(source,"candidate","t",env))()
    return s
end
local function draw(s,skill)
    s.skill=skill or "hilda_cudgel_atk1_idle"
    s.hooks.BeginDoSkill[1]({get=function() return s.anim end})
    s.skill="None"
    s.flush()
end
local function equip(s,mode)
    s.socket=({[0]="cudgel_r_hand",[1]="scabbard_a",[3]="dual_l_hand"})[mode]
    s.emit("main","SetVisibility",mode~=1)
    s.emit("sheath","SetVisibility",mode==1)
    s.hooks.EquipModeChange[1]({get=function() return s.actor end},{get=function() return mode end})
    s.actor.equipMode=mode
    s.flush()
end
local function cycle(s)
    draw(s); equip(s,0); equip(s,3); equip(s,1)
end
local function slot(s)
    s.hooks.BndEvt__PlayerEquipment_K2Node_ComponentBoundEvent_0_SettingEquipmentDelegateType__DelegateSignature[1](
        {get=function() return s.pawn end},{get=function() return 2 end})
end
local s=new()
s.press(7)
assert(s.has("control=blocked"))
cycle(s); assert(s.timers[1] and s.timers[1].active,table.concat(s.logs)); draw(s)
assert(not s.timers[1].active and s.has("SHADOW_CANCEL reason=draw"))
s.fire(1); assert(not s.has("SHADOW_HIDE token=1"))
equip(s,0); equip(s,1); equip(s,1)
assert(#s.timers==3 and not s.timers[2].active and s.timers[3].active)
s.fire(2); s.fire(3)
assert(s.has("SHADOW_HIDE") and s.has("reason=equipment-boundary-unverified"))
cycle(s); s.staffActor.equipMode=2; s.fire(4)
assert(s.has("detail=") and s.has("actor context changed staff"))
slot(s); assert(s.has("SETTING_EQUIP_POST") and s.has("stage=old-at-post part=staff exact=false"))
s.staffActor.equipMode=1; cycle(s); assert(s.timers[5].active)
s.emit("spear","SetHiddenInGame",true); assert(not s.timers[5].active and s.has("WRITER"))
s.emit("spear","SetHiddenInGame",false)
cycle(s); assert(s.timers[6].active)
s.loadMap(); s.pawn.GetAddress=function() return 1000 end
s.loadPost(); s.flush(); s.fire(6)
assert(s.has("reason=load-map") and s.has("Hilda@1000"))
cycle(s); s.fire(7)
s.press(8); assert(s.has("event=CLEANED"))
s.press(7); cycle(s); assert(s.timers[8].active)
s.rejectCancel=true; draw(s); s.fire(8)
assert(s.has("reason=timer-cancel") and s.has("state=cleanup_pending"))
s.press(8); assert(s.has("epoch=2 state=stopped category=PASS event=CLEANED"))
assert(#s.writes==0)
for _=1,30 do s.press(7); cycle(s); s.fire(#s.timers); s.press(8) end
assert(#s.writes==0)
print("PASS: sustained freeplay, timer and writer boundaries, load generation, faults and restart; zero writes")

local catalog = new()
catalog.components = {}
catalog.press(7)
assert(not catalog.has("event=CATALOGUE "))
local resources = {
    "hilda_cudgel_sheath", "hilda_cudgel_use", "hilda_cudgel_unuse",
    "hilda_dual_sheath", "hilda_dual_use", "hilda_dual_unuse",
    "hilda_spear_sheath", "hilda_spear_use", "hilda_spear_unuse",
    "hilda_staff_sheath", "hilda_staff_use", "hilda_staff_unuse",
    "hilda_shield_sheath", "hilda_scabbard_A", "hilda_scabbard_B",
}
local added = {}
for _, resource in ipairs(resources) do
    added[resource] = catalog.addComponent(resource,true)
end
catalog.addComponent("hilda_scabbard_A",false)
catalog.addComponent("hilda_scabbard_A",true,"/Game/Other/")
catalog.addComponent("hilda_cudgel",true)
slot(catalog)
local log = table.concat(catalog.logs)
local _, count = log:gsub("event=CATALOGUE ", "")
assert(count == 15, log)
for _, resource in ipairs(resources) do
    assert(catalog.has("stage=equipment-post resource="..resource.." "))
end
added.hilda_staff_use.GetAttachSocketName = function()
    return {ToString=function() return "held" end}
end
catalog.endPlay({get=function() return catalog.pawn end})
assert(catalog.has("ENDPLAY_TARGET resource=hilda_staff_use ending_owner=true same=false"))
assert(catalog.has("ENDPLAY_TARGET resource=hilda_staff_unuse ending_owner=true same=true"))
assert(catalog.scans == 2 and #catalog.writes == 0)
catalog.press(8)

local boundary = new()
boundary.press(7)
boundary.sheath.GetAttachParent = function() return nil end
boundary.endPlay({get=function() return boundary.actor end})
assert(boundary.has("ENDPLAY_TARGET resource=hilda_cudgel_sheath ending_owner=true same=false"))
assert(boundary.has("ENDPLAY_TARGET resource=hilda_scabbard_A ending_owner=false same=true"))
assert(boundary.scans == 1 and #boundary.writes == 0)
boundary.press(8)
print("PASS: exact 15-asset catalogue, optional and new rows, ownership, EndPlay identity; zero writes")
