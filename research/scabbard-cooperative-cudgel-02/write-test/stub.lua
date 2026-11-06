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
    pawn.scabbard_a = obj("Component /World/Hilda.ScabbardA", 11)
    pawn.scabbard_a.bVisible, pawn.scabbard_a.bHiddenInGame = true, false
    pawn.scabbard_a.GetOwner = function() return pawn end
    pawn.scabbard_a.SkeletalMesh = obj("SkeletalMesh /World/ScabbardA", 12)
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
    env.Key, env.ModifierKey = {F9=9,F10=10}, {CONTROL=1,ALT=2}
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
    function s.emitVis(value)
        local pair=s.hooks.SetVisibility
        assert(pair[1](param(sheath),param(value),param(false))==nil)
        sheath.bVisible=value
        assert(pair[2](param(sheath),param(value),param(false))==nil)
    end
    sheath.SetVisibility = function(_, v, prop)
        assert(prop==false)
        s.writes[#s.writes+1]=v
        s.emitVis(v)
        if s.breakAfterWrite then s.hudPawn=nil end
    end
    function s.draw()
        assert(s.hooks.BeginDoSkill[1](param(anim))==nil)
        s.flush()
    end
    function s.equip(mode, deliverWriter)
        s.socket = ({[0]="cudgel_r_hand",[1]="scabbard_a",[3]="dual_l_hand"})[mode]
        main.bVisible = mode~=1
        if deliverWriter~=false then s.emitVis(mode==1) end
        assert(s.hooks.EquipModeChange[1](param(actor),param(mode))==nil)
        actor.equipMode=mode
        s.flush()
    end
    function s.stow() s.equip(3); s.equip(1) end
    function s.has(str) return table.concat(s.logs):find(str,1,true) ~= nil end
    assert(load(source,"candidate","t",env))()
    return s
end
local function ready()
    local s=new()
    s.press(9); s.draw(); s.equip(0); s.stow()
    assert(#s.writes==0 and s.has("BASELINE_PASS"))
    s.press(9)
    assert(s.has("TEST_ARMED"))
    return s
end
local function scheduled(s)
    s.draw(); s.equip(0); s.stow()
    local i=#s.timers
    assert(s.timers[i].ms==2000 and s.timers[i].alive)
    return i
end
local function stale(s,i)
    local reads,n=s.reads,#s.writes
    s.fire(i)
    assert(s.reads==reads and #s.writes==n,"stale callback touched host")
end

do -- Normal hide, show before stock InHand, and STOP release after a fresh hide.
    local s=ready(); s.fire(scheduled(s)); assert(s.sheath.bVisible==false and s.main.bVisible==false)
    s.draw(); assert(s.sheath.bVisible and #s.writes==2)
    s.equip(0); assert(s.main.bVisible and not s.sheath.bVisible)
    s.stow(); s.fire(#s.timers); s.press(10)
    assert(s.sheath.bVisible and #s.writes==4 and s.has("event=CLEANED owned=false") and s.unhooks==3)
    assert(s.has("VISUAL_BEFORE") and s.has("VISUAL_AFTER") and s.has("VISUAL_STOP"))
    assert(s.has("scabbard_a=visible=true,hidden=false,pawn_owned=true") and s.pawn.scabbard_a.bVisible)
end
do -- Ordinary attack in the verified hand phase leaves the harness armed.
    local s=ready(); s.draw(); s.equip(0)
    s.skill="hilda_cudgel_atk1"; s.draw()
    assert(s.has("SKILL_IN_HAND") and not s.has("event=STOP") and #s.writes==0)
    s.stow(); s.fire(#s.timers); assert(s.has("event=HIDDEN"))
end
do -- Draw while Floating fences a late Sheath until verified InHand.
    local s=ready(); s.draw(); s.equip(0); s.equip(3)
    local count=#s.timers
    s.draw(); s.equip(3); s.equip(1); s.equip(1)
    assert(#s.timers==count and #s.writes==0 and s.has("SHEATH_SKIP") and not s.has("event=STOP"))
    s.equip(0); s.stow(); assert(#s.timers==count+1)
    s.fire(#s.timers); assert(s.has("event=HIDDEN"))
end
do -- Unknown skill in stowed state fails closed and retires a queued hide.
    local s=ready(); local i=scheduled(s)
    s.skill="unknown"; s.draw(); stale(s,i)
    assert(s.has("unsupported-draw") and s.has("event=CLEANED owned=false") and #s.writes==0)
end
do -- STOP with a hidden old generation cannot restore a replacement.
    local s=ready(); s.fire(scheduled(s)); s.hudPawn=nil; s.press(10)
    assert(#s.writes==1 and s.has("event=CLEANUP_PENDING owned=true") and not s.has("VISUAL_STOP"))
end
do -- Draw before deadline and a repeated Sheath cannot consume a newer attempt.
    local s=ready(); local old=scheduled(s); s.draw()
    assert(not s.timers[old].alive); stale(s,old)
    s.equip(0); s.stow(); local first=#s.timers; s.equip(1); local latest=#s.timers
    assert(latest>first and s.timers[latest].alive); stale(s,first)
    s.fire(latest); assert(#s.writes==1 and not s.sheath.bVisible)
end
for _,breakState in ipairs({
    function(s) s.socket="cudgel_r_hand" end,
    function(s) s.actorOwner={} ; s.actorOwner.IsValid=function()return false end end,
    function(s) s.sheath.SkeletalMesh=s.main.SkeletalMesh end,
    function(s) s.hudPawn=nil end,
}) do
    local s=ready(); local i=scheduled(s); breakState(s); s.fire(i)
    assert(#s.writes==0 and s.has("expiry-target-or-state"))
end
do -- Same-value foreign request transfers ownership; STOP cannot overwrite it.
    local s=ready(); s.fire(scheduled(s)); s.emitVis(false); s.flush()
    assert(#s.writes==1 and not s.sheath.bVisible and s.has("stock-took-ownership"))
end
do -- EndPlay retires the identity before a queued callback can access it.
    local s=ready(); local i=scheduled(s)
    s.endPlay({get=function()return s.pawn end})
    stale(s,i)
    assert(s.has("end-play") and #s.writes==0)
end
do -- Timer cancellation failure still invalidates the callback.
    local s=ready(); local i=scheduled(s); s.rejectCancel=true; s.draw()
    stale(s,i); assert(s.has("FAILED") and #s.writes==0)
end
do -- A partial hide with a lost readback cannot report a clean rollback.
    local s=ready(); local i=scheduled(s); s.breakAfterWrite=true; s.fire(i)
    assert(#s.writes==1 and s.has("CLEANUP_PENDING") and not s.has("event=CLEANED"))
end
do -- No write if baseline delivery did not match.
    local s=new(); s.press(9); s.draw(); s.equip(0,false); s.stow(); s.press(9)
    assert(#s.writes==0 and not s.has("TEST_ARMED"))
end
print("PASS: InHand attack, late Sheath, unknown stowed skill, lost-generation STOP, visual diagnostics, baseline, 2000ms one-shot, draw/cancel, stale generation, repeated Sheath, guards, same-value writer, EndPlay, partial-write cleanup and STOP rollback")
