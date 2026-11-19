-- SPDX-License-Identifier: MPL-2.0
-- Read-only structural witness. Clear is scoped to known stock held fields.
local ITEM = "BlueprintGeneratedClass /Game/MainContent/Act/Item_BP/"
local MESH = "SkeletalMesh /Game/MainContent/Assets/creature/03_weapon/"
local held = {
    HildaShield_BP = {SkeletalMesh="hilda_shield"},
    HildaSword_BP = {SkeletalMesh="hilda_sword"},
    HildaCudgel_BP = {SkeletalMesh="hilda_cudgel"},
    HildaStaff_BP = {SkeletalMesh="hilda_staff"},
    HildaDualMain_BP = {SkeletalMesh="hilda_dualmain_mesh", hilda_dualblade_mesh="hilda_dualblade_mesh"},
    HildaDualOff_BP = {SkeletalMesh="hilda_dualoff_mesh"},
    HildaSpear_BP = {SkeletalMesh="hilda_spear"},
    HildaBracelet_BP = {SkeletalMesh="hilda_bracelet"},
}
local classes, stockAssets = {}, {}
for short, fields in pairs(held) do
    classes[ITEM .. short .. "." .. short .. "_C"] = fields
    for _, resource in pairs(fields) do stockAssets[MESH .. resource .. "." .. resource] = resource end
end

local function valid(o) return o ~= nil and o:IsValid() end
local function name(o) return valid(o) and o:GetFullName() or nil end
local function id(o) return valid(o) and (name(o) .. "@" .. tostring(o:GetAddress())) or "-" end

local function attached(component, meshId)
    local seen = {}
    for _ = 1, 16 do
        local parent = component:GetAttachParent()
        local key = id(parent)
        if key == meshId then return true end
        if key == "-" then return false end
        if seen[key] then return nil end
        seen[key], component = true, parent
    end
end

local function inspect(pawn, mesh, selected, components)
    local pawnId, meshId = id(pawn), id(mesh)
    if pawnId == "-" or meshId == "-" or type(components) ~= "table" or #components == 0 then
        return "UNKNOWN", "missing-context-or-census"
    end
    local result, details, stockCount, seen = "CLEAR", {}, 0, {}
    for _, component in ipairs(components) do
        local resource = valid(component) and stockAssets[name(component.SkeletalMesh)]
        if resource then
            stockCount = stockCount + 1
            local actor = component:GetOwner()
            local actorId = id(actor)
            if selected[actorId] then
                seen[actorId] = true
            else
                local onMesh = attached(component, meshId)
                local localOwner = valid(actor) and id(actor:GetOwner()) == pawnId
                if onMesh ~= false or localOwner then
                    local fields = valid(actor) and classes[name(actor:GetClass())]
                    local exact = false
                    for field, expected in pairs(fields or {}) do
                        if expected == resource and id(actor[field]) == id(component) then exact = true end
                    end
                    local hidden = component.bVisible == false or component.bHiddenInGame == true
                        or (valid(actor) and actor.bHidden == true)
                    local flagsKnown = type(component.bVisible) == "boolean"
                        and type(component.bHiddenInGame) == "boolean"
                        and valid(actor) and type(actor.bHidden) == "boolean"
                    if onMesh and localOwner and exact and flagsKnown and not hidden then
                        result = "BLOCKED"
                    elseif not hidden and result ~= "BLOCKED" then
                        result = "UNKNOWN"
                    end
                    details[#details + 1] = ("%s:attached=%s:local=%s:role=%s:hidden=%s"):format(
                        resource, tostring(onMesh), tostring(localOwner), tostring(exact), tostring(hidden))
                end
            end
        end
    end
    for key in pairs(selected) do
        if not seen[key] and result == "CLEAR" then result = "UNKNOWN" end
    end
    if stockCount == 0 then result = "UNKNOWN" end
    table.sort(details)
    return result, ("components=%d stock_held=%d outgoing=%q"):format(#components, stockCount, table.concat(details, ";"))
end

-- Re-read after the census. A positive result is for this exact observation,
-- and cannot be cached as write permission for a later game-thread callback.
local function check(expected, read, census)
    local before = read()
    if before.identity ~= expected.identity or before.registry ~= expected.registry then
        return "UNKNOWN", "snapshot-changed-before-census"
    end
    local result, detail = inspect(before.pawn, before.mesh, before.selected, census())
    local after = read()
    if after.identity ~= before.identity or after.registry ~= before.registry or after.phase ~= before.phase then
        return "UNKNOWN", "snapshot-changed-during-census " .. detail
    end
    return result, detail
end

local function heldComponents(components)
    local result = {}
    for _, component in ipairs(components) do
        if valid(component) and stockAssets[name(component.SkeletalMesh)] then
            result[#result + 1] = component
        end
    end
    return result
end

return {check=check, inspect=inspect, heldComponents=heldComponents}
