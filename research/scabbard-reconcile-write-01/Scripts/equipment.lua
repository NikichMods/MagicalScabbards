-- SPDX-License-Identifier: MPL-2.0
-- Read-only equipment snapshot and exact target descriptors.
local CLOCK = "/Script/Engine.GameplayStatics:GetRealTimeSeconds"
local ITEM = "BlueprintGeneratedClass /Game/MainContent/Act/Item_BP/"
local SKELETAL = "Class /Script/Engine.SkeletalMeshComponent"
local MESH = "SkeletalMesh /Game/MainContent/Assets/creature/03_weapon/"
local roles = {
    [1] = {HildaDualMain_BP = {"hilda_dualmain_mesh", "scabbard_b", "hilda_dualblade_mesh", "hilda_dual_sheath"},
           HildaDualOff_BP = {"hilda_dualoff_mesh"}},
    [2] = {HildaCudgel_BP = {"hilda_cudgel", "scabbard_a", nil, "hilda_cudgel_sheath"}},
    [4] = {HildaStaff_BP = {"hilda_staff", "scabbard_b", nil, "hilda_staff_sheath"}},
}

local function valid(o) return o ~= nil and o:IsValid() end
local function name(o) return valid(o) and o:GetFullName() or nil end
local function id(o) return valid(o) and (name(o) .. "@" .. tostring(o:GetAddress())) or "-" end
local function class(o) return valid(o) and name(o:GetClass()) or nil end
local function socket(o) return valid(o) and o:GetAttachSocketName():ToString() or "-" end
local function visible(o) return valid(o) and o.bVisible == true and o.bHiddenInGame == false end
local function enum(n) return math.type(n) == "integer" and (n >= 0 and n <= 5 or n == 7) end
local function state(phase) return {phase=phase} end

local hudPath, animId
local hudRetry = 0

local function context()
    local hud = hudPath and StaticFindObject(hudPath)
    if not valid(hud) or not hud:IsInViewport() then
        if hudRetry > 0 then
            hudRetry = hudRetry - 1
            return
        end
        hudRetry = 9
        hud = nil
        for _, candidate in ipairs(FindAllOf("HUDMainUMG_BP_C") or {}) do
            if valid(candidate) and candidate:IsInViewport() then
                if hud then return end
                hud = candidate
            end
        end
        hudPath = name(hud) and name(hud):match("^[^ ]+ (.+)$")
    end
    if not valid(hud) then return end
    local pawn = hud:GetOwningPlayerPawn()
    if class(pawn) ~= "BlueprintGeneratedClass /Game/MainContent/Act/Character_BP/hilda_BP.hilda_BP_C"
        or pawn.bHidden ~= false then return end
    local mesh = pawn.Mesh
    if class(mesh) ~= SKELETAL or not name(mesh):match("%.CharacterMesh0$")
        or id(mesh:GetOwner()) ~= id(pawn) or not visible(mesh) then return end
    local anim = mesh:GetAnimInstance()
    if not (class(anim) or ""):match("%.hilda_AnimBP_C$") then return end
    return pawn, mesh, anim, id(hud)
end

local function checkMesh(c, actor, root, resource)
    return class(c) == SKELETAL and id(c:GetOwner()) == id(actor) and id(c:GetAttachParent()) == id(root)
        and socket(c) == "None" and name(c.SkeletalMesh) == MESH .. resource .. "." .. resource
end

local function inspect(actor, pawn, mesh, role)
    if not valid(actor) then return false, "-" end
    local root, held = actor.RootComponent, actor.SkeletalMesh
    local blade = role and role[3] and actor[role[3]]
    local sheath = role and role[4] and actor[role[4]]
    local key = table.concat({id(actor), id(root), id(held), id(blade), id(sheath), socket(root),
        valid(held) and id(held.SkeletalMesh) or "-", valid(blade) and id(blade.SkeletalMesh) or "-",
        valid(sheath) and id(sheath.SkeletalMesh) or "-"}, "|")
    local stowed = role and id(actor:GetOwner()) == id(pawn) and actor.bHidden == false
        and actor:IsActorBeingDestroyed() == false and actor.equipMode == 1
        and valid(root) and id(root:GetOwner()) == id(actor)
        and checkMesh(held, actor, root, role[1]) and held.bVisible == false and held.bHiddenInGame == false
        and (not role[2] or (visible(root) and id(root:GetAttachParent()) == id(mesh) and socket(root) == role[2]))
        and (not role[3] or (checkMesh(blade, actor, root, role[3]) and blade.bVisible == false))
        and (not role[4] or checkMesh(sheath, actor, root, role[4]))
    return stowed, key
end

local function readEquipmentState()
    local pawn, mesh, anim, hud = context()
    if not pawn then
        animId = nil
        return state("UNKNOWN"), nil, "no-context"
    end
    animId = id(anim)
    local clock, statics = StaticFindObject(CLOCK), StaticFindObject("/Script/Engine.Default__GameplayStatics")
    assert(name(clock) == "Function " .. CLOCK and name(statics) == "GameplayStatics /Script/Engine.Default__GameplayStatics")
    local now = clock(statics, pawn) * 1000
    local global = StaticFindObject("/Script/Genesis.Default__GameGlobal")
    assert(name(global) == "GameGlobal /Script/Genesis.Default__GameGlobal")
    local hand = global:GetInHandWeaponType(pawn)
    assert(enum(hand), "invalid hand")
    local doing, nextSkill = anim:GetDoingSkill():ToString(), anim:GetToDoSkill():ToString()
    local key = {hud, id(pawn), id(mesh), animId}
    local complete, occupied = true, false
    local registry, selected, byType, kinds = {}, {}, {}, {}
    for slot = 0, 1 do
        local kind = global:GetInUseWeaponType(pawn, slot)
        assert(enum(kind), "invalid slot")
        key[#key + 1] = kind
        registry[#registry + 1] = kind
        kinds[slot + 1] = kind
        if kind ~= 7 then
            occupied = true
            local seen = {}
            for handSlot = 0, 1 do
                local actor = global:GetWeaponObject(pawn, kind, handSlot)
                local actorClass = class(actor)
                local actorId = id(actor)
                registry[#registry + 1] = actorId
                if actorId ~= "-" then selected[actorId] = true end
                if actorId ~= "-" and (kind == 2 or kind == 4) then byType[kind] = actor end
                local role
                for short, row in pairs(roles[kind] or {}) do
                    if actorClass == ITEM .. short .. "." .. short .. "_C" then
                        role = row
                        if seen[short] then complete = false end
                        seen[short] = true
                        break
                    end
                end
                local stowed, identity = inspect(actor, pawn, mesh, role)
                if actorClass and not stowed then complete = false end
                key[#key + 1] = identity
            end
            if not roles[kind] then complete = false end
            for short in pairs(roles[kind] or {}) do
                if not seen[short] then complete = false end
            end
        end
    end
    local phase = hand ~= 7 and "DRAWN" or "UNKNOWN"
    if hand == 7 and occupied and complete and doing == "None" and nextSkill == "None" then phase = "STOWED" end
    return {phase=phase, identity=table.concat(key, ";"), registry=table.concat(registry, ";"),
        pawn=pawn, mesh=mesh, selected=selected, byType=byType, kinds=kinds}, now
end

local function path(o)
    return assert(name(o):match("^[^ ]+ (.+)$"))
end

local function blueprint(short)
    return ITEM .. short .. "." .. short .. "_C"
end

local function fingerprint(c, pawn, mesh, rule, requireMode)
    if class(c) ~= SKELETAL or name(c.SkeletalMesh) ~= MESH .. rule.asset .. "." .. rule.asset then return end
    local owner = c:GetOwner()
    if not valid(owner) or id(owner[rule.field]) ~= id(c) then return end
    local parent = c:GetAttachParent()
    if rule.actor then
        if class(owner) ~= blueprint(rule.actor) or id(owner:GetOwner()) ~= id(pawn)
            or owner:IsActorBeingDestroyed() ~= false or owner.bHidden ~= false
            or (requireMode and owner.equipMode ~= rule.mode) then return end
        local root = owner.RootComponent
        if not valid(root) or id(parent) ~= id(root) or id(root:GetOwner()) ~= id(owner)
            or id(root:GetAttachParent()) ~= id(mesh) or socket(root) ~= rule.mount
            or socket(c) ~= "None" or (requireMode and not visible(root)) then return end
    elseif id(owner) ~= id(pawn) or id(parent) ~= id(mesh) or socket(c) ~= rule.mount then
        return
    end
    return table.concat({id(c), id(c.SkeletalMesh), id(owner), id(parent), id(mesh), id(pawn), socket(c)}, "|")
end

local kit = {
    {field="scabbard_a", asset="hilda_scabbard_A", mount="scabbard_a"},
    {field="scabbard_b", asset="hilda_scabbard_B", mount="scabbard_b"},
    {actor="HildaCudgel_BP", kind=2, field="hilda_cudgel_sheath", asset="hilda_cudgel_sheath", mount="scabbard_a", mode=1},
    {actor="HildaStaff_BP", kind=4, field="hilda_staff_sheath", asset="hilda_staff_sheath", mount="scabbard_b", mode=1},
    {actor="HildaSpear_Unuse_BP", field="SkeletalMesh", asset="hilda_spear_unuse", mount="scabbard_a", mode=2},
    {actor="HildaDual_Unuse_BP", field="SkeletalMesh", asset="hilda_dual_unuse", mount="scabbard_b", mode=2},
}
local function supported(snapshot)
    return snapshot.phase == "STOWED" and snapshot.byType[2] and snapshot.byType[4]
        and snapshot.kinds[1] == 2 and snapshot.kinds[2] == 4
end

local function targets(snapshot, components)
    if not supported(snapshot) then return end
    local pawn, mesh = snapshot.pawn, snapshot.mesh
    local rows = {}
    for _, rule in ipairs(kit) do
        local c
        if not rule.actor then
            c = pawn[rule.field]
        elseif rule.kind then
            c = snapshot.byType[rule.kind][rule.field]
        else
            for _, candidate in ipairs(components) do
                if fingerprint(candidate, pawn, mesh, rule, true) then
                    if c then return end
                    c = candidate
                end
            end
        end
        local fingerprintKey = fingerprint(c, pawn, mesh, rule, true)
        if not fingerprintKey or not visible(c) then return end
        local ancestors, parent = {}, c:GetAttachParent()
        for _ = 1, 16 do
            if not valid(parent) then break end
            local key = id(parent)
            if ancestors[key] then return end
            ancestors[key], parent = true, parent:GetAttachParent()
        end
        if valid(parent) then return end
        rows[#rows + 1] = {key=id(c), path=path(c), pawn=path(pawn), mesh=path(mesh),
            fingerprint=fingerprintKey, rule=rule, ancestors=ancestors}
    end
    return rows
end

local function resolve(row, requireMode)
    local pawn, mesh = StaticFindObject(row.pawn), StaticFindObject(row.mesh)
    if not valid(pawn) or not valid(mesh) or id(pawn.Mesh) ~= id(mesh) or id(mesh:GetOwner()) ~= id(pawn) then return end
    local c = StaticFindObject(row.path)
    if fingerprint(c, pawn, mesh, row.rule, requireMode) == row.fingerprint then return c end
end

return {read=readEquipmentState, targets=targets, resolve=resolve, id=id, name=name, supported=supported,
    anim=function() return animId end, reset=function() hudPath, animId, hudRetry = nil, nil, 0 end}
