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
    actor.IsActorBeingDestroyed=function() return s.destroying==actor end
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
        a.IsActorBeingDestroyed=function() return s.destroying==a end
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
    mesh.GetAttachParent = function() return nil end
    hud.GetOwningPlayerPawn = function() return s.hudPawn end
    hud.IsInViewport = function() return not s.noHUD end
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
        if n=="HildaCudgel_BP_C" and s.noCudgel then return {} end
        return n == "HUDMainUMG_BP_C" and {hud} or actors[n]
    end
    env.IsKeyBindRegistered = function() return false end
    env.RegisterKeyBind = function(k, _, f) s.keys[k] = f end
    env.RegisterHook = function(p, a, b)
        s.hooks[p:match(":(.+)$")] = {a,b}
        if b then return 1,2 end
        return 3,3
    end
    env.UnregisterHook = function()
        if s.rejectUnhook then return false end
        s.unhooks = (s.unhooks or 0)+1
    end
    env.RegisterLoadMapPreHook = function(f) s.loadMap = f end
    env.RegisterLoadMapPostHook = function(f) s.loadPost = f end
    env.RegisterEndPlayPreHook = function(f) s.endPlay = f end
    env.ExecuteInGameThread = function(f) s.work[#s.work+1] = f end
    s.timers={}
    env.ExecuteInGameThreadWithDelay=function(ms,fn)
        assert(ms==2000)
        s.timers[#s.timers+1]={live=true,fn=fn}
        return #s.timers
    end
    env.CancelDelayedAction=function(i) if not s.rejectCancel then s.timers[i].live=false end end
    env.IsValidDelayedActionHandle=function(i) return s.timers[i].live end
    function s.fire(i)
        s.timers[i].live=false
        s.timers[i].fn()
        s.flush()
    end
    function s.flush()
        while #s.work>0 do table.remove(s.work,1)() end
    end
    function s.press(k) s.keys[k](); s.flush() end
    s.mesh=mesh
    function s.stock(part,value,propagate,skip)
        local pair=s.hooks.SetVisibility
        if not skip then assert(pair[1](param(part),param(value),param(propagate==true))==nil) end
        part.bVisible=value
        if not skip then assert(pair[2](param(part),param(value),param(propagate==true))==nil) end
    end
    local function setter(part,label)
        part.SetVisibility=function(_,value,propagate)
            assert(label~="mesh" and label~="main","attempt to write held/pawn mesh")
            assert(propagate==false,"unexpected propagation")
            s.writes[#s.writes+1]=label..tostring(value)
            s.stock(part,value,false,s.noDelivery==label and value==false)
            if s.failHide==label and not value then error("failed after hide") end
        end
    end
    for _, label in ipairs({"sheath", "A", "B", "spear", "staff", "dual", "mesh", "main"}) do
        local function unexpectedWrite()
            s.writes[#s.writes+1]=label
            error("unexpected write "..label)
        end
        setter(s[label],label)
        s[label].SetHiddenInGame=unexpectedWrite
    end
    function s.ending(owner, reason) s.endPlay(param(owner),reason~=nil and param(reason) or nil) end
    function s.slot()
        s.hooks.BndEvt__PlayerEquipment_K2Node_ComponentBoundEvent_0_SettingEquipmentDelegateType__DelegateSignature[1](param(pawn))
    end
    function s.draw()
        s.skill="hilda_cudgel_atk1_idle"
        s.hooks.BeginDoSkill[1](param(anim))
        s.skill="None"
    end
    function s.equip(mode)
        s.socket=({[0]="cudgel_r_hand",[1]="scabbard_a",[3]="dual_l_hand"})[mode]
        s.stock(main,mode~=1)
        s.stock(sheath,mode==1)
        s.hooks.EquipModeChange[1](param(actor),param(mode))
        actor.equipMode=mode
        s.flush()
    end
    function s.newSpear()
        local owner=obj("Actor /World/NewSpear",888,s.spearActor:GetClass():GetFullName())
        owner.IsActorBeingDestroyed=function() return false end
        owner.GetOwner=function() return pawn end
        owner.equipMode,owner.bHidden=2,false
        local r=obj("Root /World/NewSpear.Root",889)
        r.GetAttachParent=function() return mesh end
        r.GetAttachSocketName=function() return name("scabbard_a") end
        r.GetOwner=function() return owner end
        r.bVisible,r.bHiddenInGame=true,false
        local c=obj("Component /World/NewSpear.Mesh",890,"Class /Script/Engine.SkeletalMeshComponent")
        c.GetAttachParent=function() return r end
        c.GetAttachSocketName=function() return name("None") end
        c.GetOwner=r.GetOwner
        c.SkeletalMesh,c.bVisible,c.bHiddenInGame=s.spear.SkeletalMesh,true,false
        owner.RootComponent,owner.SkeletalMesh=r,c
        s.components[#s.components+1],objects["/World/NewSpear.Mesh"]=c,c
        setter(c,"new-spear")
        return c
    end
    function s.has(str) return table.concat(s.logs):find(str,1,true) ~= nil end
    assert(load(source,"candidate","t",env))()
    return s
end

local function started()
    local s=new()
    s.press(7)
    assert(s.has("stock_cudgel=true"),table.concat(s.logs))
    return s
end
local function suppress(s)
    s.equip(1)
    assert(s.timers[#s.timers] and s.timers[#s.timers].live,table.concat(s.logs))
    s.fire(#s.timers)
end

local s=started()
assert(#s.writes==0)
s.equip(1); s.equip(1)
assert(#s.timers==2 and not s.timers[1].live and s.timers[2].live)
s.fire(1)
assert(#s.writes==0)
s.draw(); s.fire(2)
assert(#s.writes==0 and s.has("reason=local-skill-pre"))
s.equip(1)
assert(#s.timers==2 and s.has("reason=draw-transition-or-writer"))
s.equip(0); s.equip(3)
suppress(s)
assert(s.has("state=SUPPRESSED category=PASS event=HIDDEN reason=sheath-delay targets=6"),table.concat(s.logs))
assert(not s.A.bVisible and not s.B.bVisible and not s.main.bVisible)
s.draw()
assert(s.A.bVisible and s.B.bVisible and s.sheath.bVisible and not s.main.bVisible)
s.press(8); s.press(7); s.press(8)
assert(s.has("epoch=2 state=PASS-THROUGH category=PASS event=CLEANED"))

local partial=started()
partial.components={partial.A,partial.sheath,partial.main}
local resources={"hilda_cudgel_use","hilda_cudgel_unuse","hilda_dual_sheath","hilda_dual_use","hilda_dual_unuse",
    "hilda_spear_sheath","hilda_spear_use","hilda_spear_unuse","hilda_staff_sheath","hilda_staff_use",
    "hilda_staff_unuse","hilda_shield_sheath","hilda_scabbard_B"}
local excluded={}
for _, resource in ipairs(resources) do excluded[#excluded+1]=partial.addComponent(resource,true) end
excluded[#excluded+1]=partial.addComponent("hilda_scabbard_A",false)
excluded[#excluded+1]=partial.addComponent("hilda_scabbard_A",true,"/Game/Other/")
suppress(partial)
assert(partial.has("matches=15 eligible=2") and partial.has("reason=sheath-delay targets=2"),table.concat(partial.logs))
for _,c in ipairs(excluded) do assert(c.bVisible) end
partial.press(8)

local replaced=started()
suppress(replaced)
local old=replaced.spear
replaced.destroying=replaced.spearActor
replaced.ending(replaced.spearActor,0)
assert(replaced.A.bVisible and replaced.B.bVisible and not old.bVisible)
replaced.spearActor.RootComponent.GetAttachParent=function() return nil end
local incoming=replaced.newSpear()
replaced.slot(); replaced.flush()
assert(replaced.has("category=RETIRED event=DESTROYED_OWNER asset=hilda_spear_unuse"))
assert(replaced.has("reason=equipment-endplay targets=6"),table.concat(replaced.logs))
assert(not incoming.bVisible and #replaced.timers==1 and not old.bVisible)
replaced.press(8)
assert(incoming.bVisible and not old.bVisible and replaced.has("event=CLEANED retired=1"))

local change=started()
suppress(change)
change.destroying=change.dualActor; change.ending(change.dualActor,0)
change.destroying=change.actor; change.ending(change.actor,0)
change.noCudgel=true
change.slot(); change.flush()
assert(change.has("stock_cudgel=false") and change.has("reason=stowed-not-retained"))
assert(change.A.bVisible and change.B.bVisible and change.spear.bVisible and change.staff.bVisible)
assert(not change.dual.bVisible and not change.sheath.bVisible)
change.press(8)
assert(change.has("event=CLEANED retired=2"))

local unknown=started()
suppress(unknown)
unknown.ending(unknown.dualActor,3)
unknown.slot(); unknown.flush(); unknown.press(8)
assert(unknown.has("event=UNKNOWN_ENDPLAY") and not unknown.has("event=CLEANED"))
assert(unknown.A.bVisible and unknown.spear.bVisible and not unknown.dual.bVisible)
unknown.press(7)
assert(unknown.has("event=START_BLOCKED"))

local reload=started()
suppress(reload)
reload.loadMap()
assert(reload.A.bVisible and reload.B.bVisible and reload.has("reason=load-map"))
local writes=#reload.writes
reload.noHUD=true
reload.loadPost(); reload.flush()
assert(#reload.writes==writes)
reload.noHUD=false
reload.pawn.GetAddress=function() return 1999 end
reload.press(7)
suppress(reload)
assert(not reload.A.bVisible)
reload.press(8)
assert(reload.has("event=CLEANED"))

local lost=started()
suppress(lost)
local oldCount=#lost.writes
lost.noHUD=true
lost.loadMap()
lost.press(8)
assert(#lost.writes==oldCount and lost.has("event=RELEASE_REFUSED") and not lost.has("event=CLEANED"))

local conflict=started()
suppress(conflict)
conflict.stock(conflict.A,false)
conflict.flush()
assert(conflict.has("event=FOREIGN_WRITER") and conflict.B.bVisible and not conflict.A.bVisible)
conflict.press(8)
assert(not conflict.has("event=CLEANED"))

local failure=started()
failure.failHide="staff"
suppress(failure)
assert(failure.has("event=HIDE") and failure.staff.bVisible and failure.A.bVisible)
failure.press(8)
assert(failure.has("event=CLEANED"))

local missing=started()
missing.noDelivery="staff"
suppress(missing)
assert(missing.has("event=HIDE") and not missing.staff.bVisible and missing.A.bVisible)
missing.press(8)
assert(not missing.has("event=CLEANED"))

local stale=started()
stale.equip(1)
stale.A.GetAddress=function() return 7777 end
stale.fire(1)
assert(#stale.writes==0 and stale.has("target generation changed"))
stale.press(8)

local timerFault=started()
timerFault.equip(1)
timerFault.rejectCancel=true
timerFault.draw()
timerFault.press(8)
assert(timerFault.has("event=TIMER_CANCEL") and not timerFault.has("event=CLEANED"))
timerFault.fire(1)
assert(#timerFault.writes==0)
timerFault.press(8); timerFault.press(7)
assert(timerFault.has("event=CLEANED") and timerFault.has("epoch=2"))
print("PASS: integrated catalogue, two policies, timers, retirement, new instances, reload, cleanup, conflicts and partial rollback")
