-- SPDX-License-Identifier: MPL-2.0
-- Run with Lua 5.4 from this directory: lua stub.lua
local source = arg[1] or "Scripts/main.lua"
local function run(scenario)
    local records, keys, queue = {}, {}, {}
    local function object(full, cls)
        local o = {valid=true, bVisible=true, bHiddenInGame=false, bHidden=false}
        function o:IsValid() return self.valid end
        function o:GetFullName() assert(self.valid); return full end
        function o:GetAddress() return self.address or tostring(self) end
        function o:GetClass() return object(cls) end
        function o:GetOwner() return self.owner end
        function o:GetAttachParent() return self.parent end
        function o:GetAttachSocketName() return {ToString=function() return self.socket or "None" end} end
        return o
    end
    local skeletal = "Class /Script/Engine.SkeletalMeshComponent"
    local function component(owner, slot, asset, parent, socket)
        local c = object("SkeletalMeshComponent " .. owner:GetFullName():match(" (.+)") .. "." .. slot, skeletal)
        c.owner, c.parent, c.socket = owner, parent, socket
        if asset then
            c.SkeletalMesh = object("SkeletalMesh /Game/MainContent/Assets/creature/03_weapon/" .. asset .. "." .. asset)
        end
        return c
    end
    local pawn = object("hilda_BP_C World.Hilda", "BlueprintGeneratedClass /Game/MainContent/Act/Character_BP/hilda_BP.hilda_BP_C")
    local actor = object("HildaCudgel_BP_C World.Cudgel", "BlueprintGeneratedClass /Game/MainContent/Act/Item_BP/HildaCudgel_BP.HildaCudgel_BP_C")
    local anim = object("hilda_AnimBP_C World.Anim", "BlueprintGeneratedClass /Game/Anim.hilda_AnimBP_C")
    function anim:GetToDoSkill() return {ToString=function() return "None" end} end
    anim.GetDoingSkill = anim.GetToDoSkill
    local hud = object("HUDMainUMG_BP_C World.Hud")
    function hud:IsInViewport() return true end
    function hud:GetOwningPlayerPawn() return pawn end
    pawn.Mesh = component(pawn, "CharacterMesh0")
    function pawn.Mesh:GetAnimInstance() return anim end
    pawn.scabbard_a = component(pawn, "scabbard_a", "hilda_scabbard_A", pawn.Mesh, "scabbard_a")
    pawn.scabbard_b = component(pawn, "scabbard_b", "hilda_scabbard_B", pawn.Mesh, "scabbard_b")
    actor.owner, actor.equipMode = pawn, 1
    actor.RootComponent = component(actor, "DefaultSceneRoot", nil, pawn.Mesh, "scabbard_a")
    actor.SkeletalMesh = component(actor, "SkeletalMesh", "hilda_cudgel", actor.RootComponent)
    actor.SkeletalMesh.bVisible = false
    actor.hilda_cudgel_sheath = component(actor, "hilda_cudgel_sheath", "hilda_cudgel_sheath", actor.RootComponent)

    local function helper(label, mesh, owner, parent)
        local h = object(label .. " World." .. label, "BlueprintGeneratedClass /Game/Test." .. label)
        h.owner = owner
        h.RootComponent = component(h, "DefaultSceneRoot", nil, parent, "scabbard_a")
        return component(h, "SkeletalMesh", mesh, h.RootComponent)
    end
    local unuse = helper("HildaCudgel_Unuse_BP_C", "hilda_cudgel_unuse", pawn, pawn.Mesh)
    local use = helper("HildaCudgel_Use_BP_C", "hilda_cudgel_use", pawn, nil)
    local foreign = helper("Foreign", "hilda_dual_unuse", nil, nil)
    local child = component(pawn, "DynamicChild", "hilda_staff_use", pawn.scabbard_b)
    local wrong = helper("WrongOwner", "hilda_spear_use", nil, pawn.Mesh)
    local impostor = component(pawn, "Impostor", nil, pawn.Mesh)
    impostor.SkeletalMesh = object("SkeletalMesh /Game/Other/hilda_staff_use.hilda_staff_use")
    local list = {pawn.scabbard_a, pawn.scabbard_b, actor.hilda_cudgel_sheath, actor.SkeletalMesh,
        unuse, use, foreign, child, wrong, impostor, unuse}
    local scans = 0
    local env = setmetatable({
        Key={F9=9,F10=10}, ModifierKey={CONTROL=1,ALT=2}, EngineTickAvailable=true,
        EGameThreadMethod={EngineTick=1}, IsKeyBindRegistered=function() return false end,
        RegisterKeyBind=function(key, _, fn) keys[key]=fn end,
        ExecuteInGameThread=function(fn, method)
            assert(method == 1)
            queue[#queue + 1]=fn
        end,
        print=function(line) records[#records + 1]=line end,
        FindAllOf=function(kind)
            if kind == "HUDMainUMG_BP_C" then return {hud} end
            if kind == "HildaCudgel_BP_C" then return {actor} end
            assert(kind == "SkeletalMeshComponent")
            scans = scans + 1
            if scenario == "replace-generation" then pawn.address = "new-address" end
            if scenario == "missing" then return nil end
            if scenario == "over-budget" then
                local overflow = {}
                for i=1,4097 do overflow[i]=child end
                return overflow
            end
            if scenario == "match-budget" then
                local overflow = {}
                for i=1,33 do overflow[i]=component(pawn, "Dynamic" .. i, "hilda_staff_use", pawn.Mesh) end
                return overflow
            end
            return list
        end,
    }, {__index=function(_, key) assert(_G[key], "unexpected global " .. key); return _G[key] end})
    if scenario == "bad-control-owner" then pawn.scabbard_b.owner=actor end
    if scenario == "bad-control-parent" then pawn.scabbard_b.parent=actor.RootComponent end
    if scenario == "pawn-lost" then pawn.valid=false end
    if scenario == "drawn" then actor.equipMode=2 end
    if scenario == "cycle" then unuse.parent=unuse end
    assert(loadfile(source, "t", env))()
    if scenario == "stop-first" then keys[10]() end
    keys[9]()
    keys[9]()
    assert(#queue <= 1)
    if scenario == "stop-queued" then keys[10]() end
    if queue[1] then queue[1]() end
    keys[9]()
    keys[10]()
    local log = table.concat(records)
    local function has(s) assert(log:find(s, 1, true), scenario .. ": missing " .. s .. "\n" .. log) end
    has("event=CLEANED")
    if scenario == "ok" or scenario == "cycle" then
        assert(scans == 1)
        has(scenario == "ok" and "controls=3 attached=2 outside=1 unresolved=2"
            or "controls=3 attached=1 outside=1 unresolved=3")
        has("control=sheath")
        has("control=A")
        has("control=B")
        has("DynamicChild")
        assert(not log:find("Impostor", 1, true))
        if scenario == "cycle" then has("anchor=cycle") end
    else
        assert(not log:find("event=COMPLETE", 1, true))
        assert(not log:find("event=COMPONENT", 1, true))
        local expected = {
            ["bad-control-owner"]="invalid control", ["bad-control-parent"]="invalid control",
            ["pawn-lost"]="local Hilda unavailable", drawn="not stowed",
            missing="incomplete scan", ["replace-generation"]="context generation changed",
            ["over-budget"]="component scan budget", ["match-budget"]="matched component budget",
            ["stop-first"]='reason="user"', ["stop-queued"]='reason="user"',
        }
        has(expected[scenario])
        if scenario:find("^stop") then assert(scans == 0) end
    end
end

for _, scenario in ipairs({"ok", "cycle", "bad-control-owner", "bad-control-parent", "pawn-lost", "drawn",
    "missing", "replace-generation", "over-budget", "match-budget", "stop-first", "stop-queued"}) do
    run(scenario)
end
print("PASS: 12 census scenarios")
