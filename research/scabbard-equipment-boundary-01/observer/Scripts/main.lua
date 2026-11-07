-- SPDX-License-Identifier: MPL-2.0
-- Read-only: compare the six frozen-candidate targets at a stock equipment notification.
local HILDA = "/Game/MainContent/Act/Character_BP/hilda_BP.hilda_BP_C"
local EVENT = HILDA .. ":BndEvt__PlayerEquipment_K2Node_ComponentBoundEvent_0_SettingEquipmentDelegateType__DelegateSignature"
local ITEM = "/Game/MainContent/Act/Item_BP/"
local STOCK = "SkeletalMesh /Game/MainContent/Assets/creature/03_weapon/"
local SPEC = {
    {"sheath","HildaCudgel_BP","hilda_cudgel_sheath","hilda_cudgel_sheath","scabbard_a",1},
    {"A",false,"scabbard_a","hilda_scabbard_A","scabbard_a"},
    {"B",false,"scabbard_b","hilda_scabbard_B","scabbard_b"},
    {"spear","HildaSpear_Unuse_BP","SkeletalMesh","hilda_spear_unuse","scabbard_a",2},
    {"staff","HildaStaff_BP","hilda_staff_sheath","hilda_staff_sheath","scabbard_b",1},
    {"dual","HildaDual_Unuse_BP","SkeletalMesh","hilda_dual_unuse","scabbard_b",2},
}
local phase, queued, closing = "idle", false, false
local hudPath, hudId, pawnId, meshId, pre, post
local baseline = {}
local function log(event, fields)
    print("MS_EQUIP_BOUNDARY id=equipment-boundary-01 event=" .. event .. " " .. (fields or "") .. "\n")
end
local function name(o) return o and o:IsValid() and o:GetFullName() or nil end
local function id(o) return name(o) and (name(o) .. "@" .. tostring(o:GetAddress())) or nil end
local function path(o) return assert(name(o):match("^[^ ]+ (.+)$")) end
local function class(o) return name(o) and name(o:GetClass()) or nil end
local function socket(o) return name(o) and o:GetAttachSocketName():ToString() or "unknown" end
local function q(v) return string.format("%q", tostring(v)) end
local function find(kind, accept)
    local list = FindAllOf(kind) or {}
    assert(#list <= 16, "lookup budget " .. kind)
    local match
    for _, o in ipairs(list) do
        if name(o) and accept(o) then
            assert(not match, "ambiguous " .. kind)
            match = o
        end
    end
    return assert(match, "missing " .. kind)
end
local function stop(reason)
    if phase == "done" then return end
    phase, closing = "done", true
    log("STOP", "reason=" .. q(reason))
    local ok = not pre or pcall(UnregisterHook, EVENT, pre, post)
    log(ok and "CLEANED" or "CLEANUP_PENDING", "keys=inert")
end
local function stopLater(reason)
    if closing then return end
    closing = true
    local ok = pcall(ExecuteInGameThread, function() stop(reason) end, EGameThreadMethod.EngineTick)
    if not ok then log("CLEANUP_PENDING", "reason=dispatch") end
end
local function pawnContext(hud)
    local pawn = name(hud) and hud:IsInViewport() and hud:GetOwningPlayerPawn() or nil
    assert(class(pawn) == "BlueprintGeneratedClass " .. HILDA, "no local Hilda")
    local mesh = pawn.Mesh
    assert(id(mesh) and name(mesh):match("%.CharacterMesh0$") and id(mesh:GetOwner()) == id(pawn), "invalid pawn mesh")
    return pawn, mesh
end
local function row(spec, pawn, mesh, actor, saved, stage)
    local label, n, property, assetName, rootSocket, mode = table.unpack(spec, 1, 6)
    local root = n and name(actor) and actor.RootComponent or nil
    local c = name(actor) and actor[property] or nil
    local asset = name(c) and c.SkeletalMesh or nil
    local parent = name(c) and c:GetAttachParent() or nil
    local attached = id(c) and id(c:GetOwner()) == id(actor)
        and id(parent) == id(n and root or mesh) and id(parent) ~= nil
        and socket(c) == (n and "None" or rootSocket)
        and (not n or (id(root:GetOwner()) == id(actor) and id(actor:GetOwner()) == id(pawn)
            and id(root:GetAttachParent()) == id(mesh) and socket(root) == rootSocket))
    local exact = attached and name(asset) == STOCK .. assetName .. "." .. assetName
        and (not n or actor.equipMode == mode)
    local same = saved and exact and saved.actor == id(actor) and saved.root == id(root)
        and saved.component == id(c) and saved.asset == id(asset) or false
    log("TARGET", "stage=" .. stage .. " part=" .. label .. " exact=" .. tostring(not not exact)
        .. " same=" .. tostring(same) .. " actor=" .. q(id(actor)) .. " component=" .. q(id(c))
        .. " root=" .. q(id(root)) .. " actor_owner=" .. q(n and name(actor) and id(actor:GetOwner()) or nil)
        .. " asset=" .. q(id(asset)) .. " root_socket=" .. q(socket(root)) .. " component_socket=" .. q(socket(c))
        .. " mode=" .. q(n and name(actor) and actor.equipMode or nil)
        .. " actor_hidden=" .. q(name(actor) and tostring(actor.bHidden) or nil)
        .. " visible=" .. q(name(c) and tostring(c.bVisible) or nil)
        .. " hidden=" .. q(name(c) and tostring(c.bHiddenInGame) or nil))
    if not saved then
        assert(exact and actor.bHidden == false and c.bVisible == true and c.bHiddenInGame == false,
            "baseline mismatch " .. label)
        baseline[label] = {actor=id(actor), root=id(root), component=id(c), asset=id(asset), path=path(actor)}
    end
end
local function sample(stage)
    local hud = StaticFindObject(hudPath)
    assert(id(hud) == hudId, "HUD generation changed")
    local pawn, mesh = pawnContext(hud)
    assert(id(pawn) == pawnId and id(mesh) == meshId, "pawn generation changed")
    for _, spec in ipairs(SPEC) do
        local saved = baseline[spec[1]]
        row(spec, pawn, mesh, spec[2] and StaticFindObject(saved.path) or pawn, saved, stage)
    end
end
local function onEquipment(param, weaponType)
    if closing or phase ~= "armed" then return end
    local ok, err = pcall(function()
        if id(param:get()) ~= pawnId then return end
        phase = "observed"
        local raw = weaponType:get()
        assert(math.type(raw) == "integer", "weapon enum unavailable")
        log("EQUIP_POST", "weapon_type=" .. raw)
        sample("post")
    end)
    if not ok then stopLater("post: " .. tostring(err)) end
end
local function step()
    if phase == "idle" then
        local hud = find("HUDMainUMG_BP_C", function(o) return o:IsInViewport() end)
        local pawn, mesh = pawnContext(hud)
        hudPath, hudId, pawnId, meshId = path(hud), id(hud), id(pawn), id(mesh)
        for _, spec in ipairs(SPEC) do
            local n = spec[2]
            local actor = n and find(n .. "_C", function(o)
                return class(o) == "BlueprintGeneratedClass " .. ITEM .. n .. "." .. n .. "_C"
                    and id(o:GetOwner()) == pawnId
            end) or pawn
            row(spec, pawn, mesh, actor, nil, "baseline")
        end
        local f = StaticFindObject(EVENT)
        assert(name(f) == "Function " .. EVENT and f:type() == "UFunction"
            and (f:GetFunctionFlags() & 0x400) == 0, "unexpected notification function")
        pre, post = RegisterHook(EVENT, onEquipment)
        assert(math.type(pre) == "integer" and pre > 0 and pre == post, "unexpected Blueprint hook IDs")
        phase = "armed"
        log("ARMED", "targets=6")
    else
        sample("after")
        log("COMPLETE", "post_seen=" .. tostring(phase == "observed"))
        stop("sample-complete")
    end
end
assert(EngineTickAvailable == true and type(RegisterLoadMapPreHook) == "function"
    and type(RegisterEndPlayPreHook) == "function", "required API unavailable")
RegisterLoadMapPreHook(function()
    if phase == "armed" or phase == "observed" then stopLater("load-map") end
end)
RegisterEndPlayPreHook(function(param)
    if phase ~= "armed" and phase ~= "observed" then return end
    local ok, ended = pcall(function() return id(param:get()) end)
    if not ok or ended == pawnId then stopLater("pawn-end-play") end
end)
local mods = {ModifierKey.CONTROL, ModifierKey.ALT}
assert(not IsKeyBindRegistered(Key.F7, mods) and not IsKeyBindRegistered(Key.F8, mods), "test chord occupied")
RegisterKeyBind(Key.F7, mods, function()
    if closing or queued then return end
    queued = true
    local ok = pcall(ExecuteInGameThread, function()
        if closing then return end
        queued = false
        local good, err = pcall(step)
        if not good then stop("control: " .. tostring(err)) end
    end, EGameThreadMethod.EngineTick)
    if not ok then stopLater("dispatch") end
end)
RegisterKeyBind(Key.F8, mods, function() stopLater("user") end)
log("LOADED", "step=Ctrl+Alt+F7 stop=Ctrl+Alt+F8")
