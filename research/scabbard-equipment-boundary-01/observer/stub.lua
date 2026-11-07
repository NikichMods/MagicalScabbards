-- SPDX-License-Identifier: MPL-2.0
local source = assert(arg[1], "pass observer script")
local function fixture()
    local s = {logs={}, keys={}, jobs={}, unhooks=0}
    local env = setmetatable({}, {__index=_G})
    local function obj(full, cls)
        local o = {bVisible=true, bHiddenInGame=false, bHidden=false}
        function o:IsValid() return not self.dead end
        function o:GetFullName() return full end
        function o:GetAddress() return tostring(self) end
        function o:GetClass() return obj(cls) end
        function o:GetOwner() return self.owner end
        function o:GetAttachParent() return self.parent end
        function o:GetAttachSocketName() return {ToString=function() return self.socket or "None" end} end
        return o
    end
    local function param(v) return {get=function() return v end} end
    local hilda = "/Game/MainContent/Act/Character_BP/hilda_BP.hilda_BP_C"
    local pawn = obj("hilda_BP_C World.Hilda", "BlueprintGeneratedClass " .. hilda)
    local mesh = obj("SkeletalMeshComponent World.Hilda.CharacterMesh0")
    pawn.Mesh, mesh.owner, s.pawn = mesh, pawn, pawn
    local hud = obj("HUDMainUMG_BP_C World.HUD")
    function hud:IsInViewport() return true end
    function hud:GetOwningPlayerPawn() return s.pawn end
    local objects, classes = {["World.HUD"]=hud}, {HUDMainUMG_BP_C={hud}}
    local function component(owner, parent, socket, meshName, suffix)
        local c = obj("SkeletalMeshComponent " .. suffix)
        c.owner, c.parent, c.socket = owner, parent, socket
        c.SkeletalMesh = obj("SkeletalMesh /Game/MainContent/Assets/creature/03_weapon/" .. meshName .. "." .. meshName)
        return c
    end
    pawn.scabbard_a = component(pawn,mesh,"scabbard_a","hilda_scabbard_A","World.Hilda.A")
    pawn.scabbard_b = component(pawn,mesh,"scabbard_b","hilda_scabbard_B","World.Hilda.B")
    for _, spec in ipairs({
        {"HildaCudgel_BP","hilda_cudgel_sheath","hilda_cudgel_sheath","scabbard_a",1},
        {"HildaSpear_Unuse_BP","SkeletalMesh","hilda_spear_unuse","scabbard_a",2},
        {"HildaStaff_BP","hilda_staff_sheath","hilda_staff_sheath","scabbard_b",1},
        {"HildaDual_Unuse_BP","SkeletalMesh","hilda_dual_unuse","scabbard_b",2},
    }) do
        local n, slot, asset, socket, mode = table.unpack(spec)
        local a = obj("Actor World." .. n, "BlueprintGeneratedClass /Game/MainContent/Act/Item_BP/" .. n .. "." .. n .. "_C")
        local root = obj("SceneComponent World." .. n .. ".DefaultSceneRoot")
        root.owner, root.parent, root.socket = a, mesh, socket
        a.owner, a.equipMode, a.RootComponent = pawn, mode, root
        a[slot] = component(a,root,nil,asset,"World." .. n .. "." .. slot)
        classes[n .. "_C"], objects["World." .. n], s[n] = {a}, a, a
    end
    env.FindAllOf = function(n) return classes[n] end
    env.StaticFindObject = function(n)
        if objects[n] then return objects[n] end
        if not n:find(":BndEvt__",1,true) then return end
        local f = obj("Function " .. n)
        f.type = function() return "UFunction" end
        f.GetFunctionFlags = function() return 0 end
        return f
    end
    env.EngineTickAvailable, env.EGameThreadMethod = true, {EngineTick=1}
    env.Key, env.ModifierKey = {F7=7,F8=8}, {CONTROL=1,ALT=2}
    env.IsKeyBindRegistered = function() return false end
    env.RegisterKeyBind = function(k,_,fn) s.keys[k]=fn end
    env.RegisterHook = function(_, fn) s.notify=fn; return 1,1 end
    env.UnregisterHook = function() s.unhooks=s.unhooks+1 end
    env.RegisterLoadMapPreHook = function(fn) s.loadMap=fn end
    env.RegisterEndPlayPreHook = function(fn) s.endPlay=fn end
    env.ExecuteInGameThread = function(fn) s.jobs[#s.jobs+1]=fn end
    env.print = function(line) s.logs[#s.logs+1]=line end
    function s.flush() while #s.jobs>0 do table.remove(s.jobs,1)() end end
    function s.press(k) s.keys[k](); s.flush() end
    function s.event(o, value) s.notify(param(o),param(value)); s.flush() end
    function s.has(str) return table.concat(s.logs):find(str,1,true) ~= nil end
    assert(loadfile(source,"t",env))()
    return s
end
do
    local s=fixture(); s.press(7)
    s.event(s.HildaCudgel_BP,1); assert(not s.has("event=EQUIP_POST"))
    s.event(s.pawn,1); assert(s.has("stage=post part=staff exact=true same=true"))
    s.HildaStaff_BP.RootComponent.parent=nil
    s.press(7)
    assert(s.has("stage=after part=staff exact=false same=false") and s.has("post_seen=true") and s.unhooks==1)
end
do
    local s=fixture(); s.press(7); s.HildaSpear_Unuse_BP.dead=true
    s.event(s.pawn,1); s.press(7)
    assert(s.has("stage=post part=spear exact=false same=false") and s.has("post_seen=true"))
end
do
    local s=fixture(); s.press(7); s.press(7)
    assert(s.has("post_seen=false") and s.has("event=CLEANED"))
end
for _, interrupt in ipairs({
    function(s) s.press(8) end,
    function(s) s.loadMap(); s.flush() end,
    function(s) s.endPlay({get=function() return s.pawn end}); s.flush() end,
    function(s) s.pawn=nil; s.press(7) end,
}) do
    local s=fixture(); s.press(7); interrupt(s); s.press(7)
    assert(s.has("event=CLEANED") and not s.has("event=COMPLETE") and s.unhooks==1)
end
do
    local s=fixture(); s.HildaStaff_BP.RootComponent.socket="wrong"; s.press(7)
    assert(s.has("baseline mismatch staff") and not s.has("event=ARMED"))
end
print("PASS: 8 equipment-boundary scenarios")
