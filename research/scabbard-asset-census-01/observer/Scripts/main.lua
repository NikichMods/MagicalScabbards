-- SPDX-License-Identifier: MPL-2.0
-- One read-only snapshot on the game thread. No gameplay hooks or retained objects.
local WEAPONS = "/Game/MainContent/Assets/creature/03_weapon/"
local PAWN = "BlueprintGeneratedClass /Game/MainContent/Act/Character_BP/hilda_BP.hilda_BP_C"
local CUDGEL = "BlueprintGeneratedClass /Game/MainContent/Act/Item_BP/HildaCudgel_BP.HildaCudgel_BP_C"
local SKELETAL = "Class /Script/Engine.SkeletalMeshComponent"
local assets = {}
for _, name in ipairs({
    "hilda_cudgel_sheath", "hilda_cudgel_unuse", "hilda_cudgel_use",
    "hilda_dual_sheath", "hilda_dual_unuse", "hilda_dual_use",
    "hilda_scabbard_A", "hilda_scabbard_B", "hilda_shield_sheath",
    "hilda_spear_sheath", "hilda_spear_unuse", "hilda_spear_use",
    "hilda_staff_sheath", "hilda_staff_unuse", "hilda_staff_use",
}) do
    assets["SkeletalMesh " .. WEAPONS .. name .. "." .. name] = name
end

local stopped, queued = false, false
local function log(event, fields)
    print("MS_ASSETS id=scabbard-asset-census-01 event=" .. event .. " " .. (fields or "") .. "\n")
end
local function q(value) return string.format("%q", tostring(value):gsub("%c", "?"):sub(1, 320)) end
local function valid(o) return o ~= nil and o:IsValid() end
local function name(o) return valid(o) and o:GetFullName() or nil end
local function id(o) return valid(o) and (o:GetFullName() .. "@" .. tostring(o:GetAddress())) or nil end
local function class(o) return valid(o) and name(o:GetClass()) or nil end
local function bit(value)
    assert(type(value) == "boolean", "visibility binding unavailable")
    return tostring(value)
end
local function stop(reason)
    if stopped then return end
    stopped = true
    log("STOP", "reason=" .. q(reason))
    log("CLEANED", "keybinds=inert")
end
local function unique(kind, predicate)
    local list = FindAllOf(kind) or {}
    assert(#list <= 16, "context lookup budget: " .. kind)
    local found
    for _, o in ipairs(list) do
        if valid(o) and predicate(o) then
            assert(not found, "ambiguous " .. kind)
            found = o
        end
    end
    return assert(found, "missing " .. kind)
end

local function context()
    local hud = unique("HUDMainUMG_BP_C", function(o) return o:IsInViewport() end)
    local pawn = hud:GetOwningPlayerPawn()
    assert(class(pawn) == PAWN and pawn.bHidden == false, "local Hilda unavailable")
    local pawnId = id(pawn)
    local mesh = pawn.Mesh
    assert(class(mesh) == SKELETAL and id(mesh:GetOwner()) == pawnId
        and name(mesh):match("%.CharacterMesh0$"), "invalid CharacterMesh0")
    local actor = unique("HildaCudgel_BP_C", function(o)
        return class(o) == CUDGEL and id(o:GetOwner()) == pawnId
    end)
    local root, main, sheath = actor.RootComponent, actor.SkeletalMesh, actor.hilda_cudgel_sheath
    assert(actor.bHidden == false and actor.equipMode == 1 and valid(root)
        and id(root:GetOwner()) == id(actor) and id(root:GetAttachParent()) == id(mesh)
        and root:GetAttachSocketName():ToString() == "scabbard_a", "cudgel not stowed on local Hilda")
    assert(class(main) == SKELETAL and id(main:GetOwner()) == id(actor)
        and name(main.SkeletalMesh) == "SkeletalMesh " .. WEAPONS .. "hilda_cudgel.hilda_cudgel"
        and main.bVisible == false and main.bHiddenInGame == false, "unexpected held mesh")
    local anim = mesh:GetAnimInstance()
    assert((class(anim) or ""):match("%.hilda_AnimBP_C$") and anim:GetToDoSkill():ToString() == "None"
        and anim:GetDoingSkill():ToString() == "None", "anim unavailable or skill active")
    local a, b = pawn.scabbard_a, pawn.scabbard_b
    for _, target in ipairs({
        {a, pawn, mesh, "scabbard_a", "hilda_scabbard_A"},
        {b, pawn, mesh, "scabbard_b", "hilda_scabbard_B"},
        {sheath, actor, root, "None", "hilda_cudgel_sheath"},
    }) do
        local c = target[1]
        assert(class(c) == SKELETAL and id(c:GetOwner()) == id(target[2])
            and id(c:GetAttachParent()) == id(target[3]) and c:GetAttachSocketName():ToString() == target[4]
            and assets[name(c.SkeletalMesh)] == target[5], "invalid control: " .. target[5])
    end
    assert(sheath.bVisible == true and sheath.bHiddenInGame == false, "expected native stowed sheath")
    local generation = {}
    for _, o in ipairs({hud, pawn, mesh, anim, actor, root, main, sheath, a, b,
        main.SkeletalMesh, sheath.SkeletalMesh, a.SkeletalMesh, b.SkeletalMesh}) do
        generation[#generation + 1] = assert(id(o), "lost context object")
    end
    return {pawn=pawnId, mesh=id(mesh), actor=id(actor), generation=table.concat(generation, "|"),
        controls={[id(a)]="A", [id(b)]="B", [id(sheath)]="sheath"}}
end

local function attachment(component, ctx, rootId)
    local seen, chain = {}, {}
    local node, rooted = component, false
    for _ = 1, 12 do
        local key = id(node)
        if not key then return chain, "detached", rooted end
        if seen[key] then return chain, "cycle", rooted end
        seen[key] = true
        rooted = rooted or key == rootId
        chain[#chain + 1] = q(key) .. ":socket=" .. q(node:GetAttachSocketName():ToString())
            .. ":owner=" .. q(id(node:GetOwner())) .. ":visible=" .. bit(node.bVisible)
            .. ":hidden=" .. bit(node.bHiddenInGame)
        if key == ctx.mesh then return chain, "local-mesh", rooted end
        if name(node):match("%.CharacterMesh0$") then return chain, "other-mesh", rooted end
        node = node:GetAttachParent()
    end
    return chain, "depth-limit", rooted
end

local function inspect(c, asset, ctx)
    local componentId, owner = id(c), c:GetOwner()
    local ownerId = id(owner)
    local ownerOwner = valid(owner) and id(owner:GetOwner()) or nil
    local ownerRoot = valid(owner) and id(owner.RootComponent) or nil
    local chain, anchor, rooted = attachment(c, ctx, ownerRoot)
    local relationship = "unresolved"
    if ctx.controls[componentId] then
        relationship = "control"
    elseif anchor == "local-mesh" and (ownerId == ctx.pawn
        or (rooted and (ownerOwner == ctx.pawn or ownerOwner == ctx.actor))) then
        relationship = "attached-candidate"
    elseif (anchor == "other-mesh" or anchor == "detached")
        and ownerId and ownerId ~= ctx.pawn and ownerOwner ~= ctx.pawn and ownerOwner ~= ctx.actor then
        relationship = "outside-local"
    end
    local mode = valid(owner) and owner.equipMode or nil
    return relationship, "category=" .. relationship .. " control=" .. (ctx.controls[componentId] or "none")
        .. " asset=" .. q(name(asset)) .. " asset_id=" .. q(id(asset)) .. " component=" .. q(componentId)
        .. " component_class=" .. q(class(c)) .. " actor=" .. q(ownerId) .. " actor_class=" .. q(class(owner))
        .. " actor_owner=" .. q(ownerOwner) .. " actor_hidden=" .. (ownerId and bit(owner.bHidden) or "unknown")
        .. " actor_mode_raw=" .. (type(mode) == "number" and tostring(mode) or "unknown")
        .. " visible=" .. bit(c.bVisible) .. " hidden=" .. bit(c.bHiddenInGame)
        .. " socket=" .. q(c:GetAttachSocketName():ToString()) .. " anchor=" .. anchor
        .. " chain=" .. table.concat(chain, " -> ")
end

local function snapshot()
    local before = context()
    log("LOOKUP_BEGIN", "class=SkeletalMeshComponent")
    local list = FindAllOf("SkeletalMeshComponent") or {}
    log("LOOKUP_END", "count=" .. #list)
    assert(#list <= 4096, "component scan budget")
    local rows, seen, controls = {}, {}, 0
    local counts = {["attached-candidate"]=0, ["outside-local"]=0, unresolved=0}
    for _, c in ipairs(list) do
        if valid(c) then
            local asset = c.SkeletalMesh
            if assets[name(asset)] and not seen[id(c)] then
                assert(#rows < 32, "matched component budget")
                seen[id(c)] = true
                local category, fields = inspect(c, asset, before)
                rows[#rows + 1] = fields
                if category == "control" then controls = controls + 1
                else counts[category] = counts[category] + 1 end
            end
        end
    end
    assert(controls == 3, "incomplete scan: missing known controls")
    assert(context().generation == before.generation, "context generation changed")
    if stopped then return end
    log("SNAPSHOT", "pawn=" .. q(before.pawn) .. " main_actor=" .. q(before.actor) .. " equipMode=1")
    for _, fields in ipairs(rows) do log("COMPONENT", fields) end
    log("COMPLETE", "controls=3 attached=" .. counts["attached-candidate"]
        .. " outside=" .. counts["outside-local"] .. " unresolved=" .. counts.unresolved)
    stop("snapshot-complete")
end

local ok, err = pcall(function()
    assert(EngineTickAvailable == true, "engine-tick dispatch unavailable")
    local mods = {ModifierKey.CONTROL, ModifierKey.ALT}
    assert(not IsKeyBindRegistered(Key.F9, mods) and not IsKeyBindRegistered(Key.F10, mods), "key conflict")
    RegisterKeyBind(Key.F10, mods, function() stop("user") end)
    RegisterKeyBind(Key.F9, mods, function()
        if stopped or queued then return end
        queued = true
        local dispatched, problem = pcall(ExecuteInGameThread, function()
            if stopped then return end
            local sampled, failure = pcall(snapshot)
            if not sampled then stop("incomplete: " .. tostring(failure)) end
        end, EGameThreadMethod.EngineTick)
        if not dispatched then stop("dispatch: " .. tostring(problem)) end
    end)
end)
if ok then log("ARMED", "sample=Ctrl+Alt+F9 stop=Ctrl+Alt+F10")
else stop("setup: " .. tostring(err)) end
