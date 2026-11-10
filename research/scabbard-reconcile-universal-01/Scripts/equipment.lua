-- SPDX-License-Identifier: MPL-2.0
-- Read-only equipment snapshot and exact target descriptors.
local CLOCK = "/Script/Engine.GameplayStatics:GetRealTimeSeconds"
local ITEM = "BlueprintGeneratedClass /Game/MainContent/Act/Item_BP/"
local SKELETAL = "Class /Script/Engine.SkeletalMeshComponent"
local MESH = "SkeletalMesh /Game/MainContent/Assets/creature/03_weapon/"
local roles = {
    [0] = {HildaShield_BP = {"hilda_shield", "scabbard_a", nil, "hilda_shield_sheath"},
           HildaSword_BP = {"hilda_sword", "scabbard_b"}},
    [1] = {HildaDualMain_BP = {"hilda_dualmain_mesh", "scabbard_b", "hilda_dualblade_mesh", "hilda_dual_sheath"},
           HildaDualOff_BP = {"hilda_dualoff_mesh"}},
    [2] = {HildaCudgel_BP = {"hilda_cudgel", "scabbard_a", nil, "hilda_cudgel_sheath"}},
    [3] = {HildaSpear_BP = {"hilda_spear", "scabbard_a", nil, "hilda_spear_sheath"}},
    [4] = {HildaStaff_BP = {"hilda_staff", "scabbard_b", nil, "hilda_staff_sheath"}},
    [5] = {HildaBracelet_BP = {"hilda_bracelet", "bracelet_r_hand", observationOnly=true}},
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
    local stowed = role and not role.observationOnly and id(actor:GetOwner()) == id(pawn) and actor.bHidden == false
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
    local registry, selected, kinds, expectedSheaths = {}, {}, {}, {}
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
                local role
                for short, row in pairs(roles[kind] or {}) do
                    if actorClass == ITEM .. short .. "." .. short .. "_C" then
                        role = row
                        if seen[short] then complete = false end
                        seen[short] = true
                        if role[4] then expectedSheaths[id(actor[role[4]])] = true end
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
    local note
    if not occupied then note = "empty-equipment"
    elseif kinds[1] == 5 or kinds[2] == 5 then note = "bracer-stowed-role-unconfirmed" end
    return {phase=phase, identity=table.concat(key, ";"), registry=table.concat(registry, ";"),
        pawn=pawn, mesh=mesh, selected=selected, kinds=kinds, expectedSheaths=expectedSheaths, note=note}, now
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
            or (requireMode and not rule.modes[owner.equipMode]) then return end
        local root = owner.RootComponent
        if not valid(root) or id(parent) ~= id(root) or id(root:GetOwner()) ~= id(owner)
            or id(root:GetAttachParent()) ~= id(mesh) or socket(root) ~= rule.mount
            or socket(c) ~= "None" or (requireMode and not visible(root)) then return end
    elseif id(owner) ~= id(pawn) or id(parent) ~= id(mesh) or socket(c) ~= rule.mount then
        return
    end
    return table.concat({id(c), id(c.SkeletalMesh), id(owner), id(parent), id(mesh), id(pawn), socket(c)}, "|")
end

local catalogue = {}
local function register(rule)
    catalogue[MESH .. rule.asset .. "." .. rule.asset] = rule
end
for _, mount in ipairs({"a", "b"}) do
    register({field="scabbard_" .. mount, asset="hilda_scabbard_" .. mount:upper(), mount="scabbard_" .. mount})
end
for _, family in pairs(roles) do
    for actor, role in pairs(family) do
        if role[4] then
            register({actor=actor, selected=true, field=role[4], asset=role[4], mount=role[2], modes={[1]=true}})
        end
    end
end
for _, row in ipairs({{"cudgel", "a"}, {"dual", "b"}, {"spear", "a"}, {"staff", "b"}}) do
    local family, mount = row[1], "scabbard_" .. row[2]
    local title = family:sub(1, 1):upper() .. family:sub(2)
    register({actor="Hilda" .. title .. "_Unuse_BP", field="SkeletalMesh",
        asset="hilda_" .. family .. "_unuse", mount=mount, modes={[2]=true}})
    register({actor="Hilda" .. title .. "_Use_BP", field="SkeletalMesh",
        asset="hilda_" .. family .. "_use", mount=mount, modes={[1]=true,[2]=true}})
end

local function supported(snapshot)
    return snapshot.phase == "STOWED"
end

local function targets(snapshot, components)
    if not supported(snapshot) then return end
    local pawn, mesh = snapshot.pawn, snapshot.mesh
    local rows, seen, observed, skipped = {}, {}, {}, 0
    local assets = {}
    local pawnKey = id(pawn)
    for _, c in ipairs(components) do
        local rule = class(c) == SKELETAL and catalogue[name(c.SkeletalMesh)]
        if not rule then goto continue end
        local owner = c:GetOwner()
        local ownerKey = id(owner)
        if ownerKey ~= pawnKey and (not valid(owner) or id(owner:GetOwner()) ~= pawnKey) then goto continue end
        local fingerprintKey = fingerprint(c, pawn, mesh, rule, true)
        if not fingerprintKey or (rule.selected and not snapshot.selected[ownerKey])
            or (rule.actor and not rule.selected and snapshot.selected[ownerKey]) then
            skipped = skipped + 1
            goto continue
        end
        local key = id(c)
        observed[key] = true
        if not visible(c) then goto continue end
        if seen[key] then goto continue end
        seen[key] = true
        local ancestors, parent = {}, c:GetAttachParent()
        for _ = 1, 16 do
            if not valid(parent) then break end
            local key = id(parent)
            if ancestors[key] then return nil, "attachment-cycle" end
            ancestors[key], parent = true, parent:GetAttachParent()
        end
        if valid(parent) then return nil, "attachment-depth" end
        rows[#rows + 1] = {key=key, path=path(c), pawn=path(pawn), pawnKey=pawnKey, mesh=path(mesh),
            owner=ownerKey, asset=id(c.SkeletalMesh), fingerprint=fingerprintKey, rule=rule, ancestors=ancestors}
        assets[#assets + 1] = rule.asset
        ::continue::
    end
    table.sort(rows, function(a, b) return a.key < b.key end)
    table.sort(assets)
    local missing = 0
    for key in pairs(snapshot.expectedSheaths) do
        if not observed[key] then missing = missing + 1 end
    end
    if #rows == 0 then return nil, (skipped > 0 or missing > 0) and "stock-role-unconfirmed" or "no-visible-confirmed-targets" end
    return rows, ("local-stock-rejected=%d expected-sheath-missing=%d assets=%s"):format(
        skipped, missing, table.concat(assets, ","))
end

local function resolveAdmission(row)
    local pawn, mesh = StaticFindObject(row.pawn), StaticFindObject(row.mesh)
    if id(pawn) ~= row.pawnKey or not valid(mesh) or id(pawn.Mesh) ~= id(mesh)
        or id(mesh:GetOwner()) ~= row.pawnKey then return end
    local c = StaticFindObject(row.path)
    if fingerprint(c, pawn, mesh, row.rule, true) == row.fingerprint then return c end
end

local function ownedComponent(row)
    local c = StaticFindObject(row.path)
    if not valid(c) then return nil, "missing-component" end
    if id(c) ~= row.key or class(c) ~= SKELETAL then return nil, "component-replaced" end
    if id(c.SkeletalMesh) ~= row.asset then return nil, "asset-changed" end
    local owner = c:GetOwner()
    if id(owner) ~= row.owner or id(owner[row.rule.field]) ~= row.key then return nil, "owner-or-field-changed" end
    return c, owner
end

local function resolveOwned(row)
    local c, owner = ownedComponent(row)
    if not c then return nil, owner end
    if row.ending then return nil, "owner-ended" end
    local pawn = StaticFindObject(row.pawn)
    if id(pawn) ~= row.pawnKey or pawn:IsActorBeingDestroyed() ~= false then return nil, "pawn-lost" end
    if row.rule.actor and (id(owner:GetOwner()) ~= row.pawnKey or owner:IsActorBeingDestroyed() ~= false) then
        return nil, "actor-not-live-local"
    end
    local seen, parent = {}, c
    for _ = 1, 16 do
        parent = parent:GetAttachParent()
        if not valid(parent) then return c end
        local key, parentOwner = id(parent), id(parent:GetOwner())
        if seen[key] or (parentOwner ~= row.owner and parentOwner ~= row.pawnKey) then
            return nil, "attachment-no-longer-local"
        end
        seen[key] = true
    end
    return nil, "attachment-depth"
end

local function retired(row, actor)
    if row.owner ~= id(actor) then return false end
    local c, owner = ownedComponent(row)
    return c ~= nil and id(owner) == row.owner
end

local function affectedByAncestor(row, key)
    if row.ancestors[key] then return true end
    local c = ownedComponent(row)
    if not c then return true end
    local seen = {}
    for _ = 1, 16 do
        c = c:GetAttachParent()
        if not valid(c) then return false end
        local parent = id(c)
        if parent == key or seen[parent] then return true end
        seen[parent] = true
    end
    return true
end

return {read=readEquipmentState, targets=targets, admission=resolveAdmission, owned=resolveOwned,
    retired=retired, ancestor=affectedByAncestor, id=id, name=name, supported=supported,
    anim=function() return animId end, reset=function() hudPath, animId, hudRetry = nil, nil, 0 end}
