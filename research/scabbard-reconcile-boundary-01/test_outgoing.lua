-- SPDX-License-Identifier: MPL-2.0
local outgoing = dofile("Scripts/outgoing.lua")
local function object(name)
    return {IsValid=function() return true end, GetFullName=function() return name end,
        GetAddress=function(self) return self.address or name end}
end
local function class(blueprint)
    return object("BlueprintGeneratedClass /Game/MainContent/Act/Item_BP/" .. blueprint .. "." .. blueprint .. "_C")
end
local pawn, mesh, foreignPawn = object("pawn"), object("mesh"), object("foreign pawn")
local function weapon(label, blueprint, asset, owner, parent, field)
    local actor, root, component = object(label), object(label .. " root"), object(label .. " held")
    actor.GetClass = function() return class(blueprint) end
    actor.GetOwner = function(self) return self.owner end
    actor.owner, actor.bHidden = owner, false
    root.GetAttachParent = function(self) return self.parent end
    root.parent = parent
    component.GetOwner = function() return actor end
    component.GetAttachParent = function() return root end
    component.SkeletalMesh = object("SkeletalMesh /Game/MainContent/Assets/creature/03_weapon/" .. asset .. "." .. asset)
    component.bVisible, component.bHiddenInGame = true, false
    actor[field or "SkeletalMesh"] = component
    return component, actor, root
end
local selectedHeld = weapon("incoming", "HildaStaff_BP", "hilda_staff", pawn, mesh)
local oldHeld, oldActor, oldRoot = weapon("old", "HildaDualMain_BP", "hilda_dualblade_mesh", pawn, mesh, "hilda_dualblade_mesh")
local world = weapon("pickup", "HildaCudgel_BP", "hilda_cudgel", foreignPawn)
local helper = weapon("helper", "HildaStaff_Unuse_BP", "hilda_staff_unuse", pawn, mesh)
local snapshot = {phase="STOWED", identity="current", registry="selected",
    pawn=pawn, mesh=mesh, selected={["incoming@incoming"]=true}}
local function check(expected, components, before, after)
    local calls = 0
    local result = outgoing(snapshot, function()
        calls = calls + 1
        return calls == 1 and (before or snapshot) or (after or snapshot)
    end, function() return components end)
    assert(result == expected, ("%s ~= %s"):format(result, expected))
end
check("CLEAR", {selectedHeld, world, helper})
check("UNKNOWN", {world})
check("UNKNOWN", {})
check("BLOCKED", {selectedHeld, oldHeld})
oldHeld.bVisible = false
check("CLEAR", {selectedHeld, oldHeld})
oldHeld.bVisible, oldHeld.bHiddenInGame = true, true
check("CLEAR", {selectedHeld, oldHeld})
oldHeld.bHiddenInGame = false
oldActor.bHidden = true
check("CLEAR", {selectedHeld, oldHeld})
oldActor.bHidden = false
oldRoot.parent = nil
check("UNKNOWN", {selectedHeld, oldHeld})
oldRoot.parent = oldRoot
check("UNKNOWN", {selectedHeld, oldHeld})
oldRoot.parent, oldActor.owner = mesh, foreignPawn
check("UNKNOWN", {selectedHeld, oldHeld})
oldActor.owner = pawn
oldActor.hilda_dualblade_mesh = nil
check("UNKNOWN", {selectedHeld, oldHeld})
local changed = {identity="current", registry="replaced"}
check("UNKNOWN", {selectedHeld}, changed)
check("UNKNOWN", {selectedHeld}, nil, changed)
check("UNKNOWN", {selectedHeld}, nil, {identity="new-pawn", registry="selected"})
print("PASS outgoing structural boundary, registry races and context change")
