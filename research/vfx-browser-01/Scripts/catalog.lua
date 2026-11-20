-- SPDX-License-Identifier: MPL-2.0
-- Research-only catalog. A package-name derivation is a candidate, NOT proof that
-- its UObject is a ParticleSystem. Only exact runtime type+path admits spawning.
local root = "/Game/MainContent/Assets/fx/bp/"
local seed = {
    {"Bracelet astral spark", "skill/hilda/_bracelet_charge/private/throw_spark_astral", "package-only"},
    {"Staff cast spark", "skill/hilda_ult/_stf01/private/stf01_spark", "package-only"},
    {"Fire spark 01", "general/fire/spark_01", "package-only"},
    {"Ultimate active spark", "skill/hilda_ult/_active/private/ult_active_spark", "package-only"},
    {"Astral hit", "general/astral/astral_hit_01", "package+export"},
    {"Astral staff shot (negative control)", "skill/hilda/_staff/private/astral_missile_shoot", "exact-object"},
}
local function packageObject(relative)
    local base = relative:match("([^/]+)$")
    return root .. relative .. "." .. base
end
local function build(loaded, max)
    max = max or 20
    assert(type(max) == "number" and max >= 1 and max <= 20, "invalid catalog cap")
    local out, known = {}, {}
    for _, item in ipairs(seed) do
        if #out >= max then break end
        local path = packageObject(item[2])
        out[#out + 1] = {label=item[1], path=path, origin=item[3]}
        known[path] = true
    end
    local discovered = {}
    for _, path in ipairs(loaded or {}) do
        if type(path) == "string" and path:find("^" .. root:gsub("([^%w])", "%%%1"))
            and path:match("%.[%w_]+$") and not known[path] then
            local leaf = (path:match("([^/.]+)$") or ""):lower()
            if leaf:find("spark", 1, true) or leaf:find("glint", 1, true)
                or leaf:find("shimmer", 1, true) or leaf:find("flash", 1, true)
                or leaf:find("twinkle", 1, true) then
                discovered[#discovered + 1] = path
                known[path] = true
            end
        end
    end
    table.sort(discovered)
    for _, path in ipairs(discovered) do
        if #out >= max then break end
        out[#out + 1] = {label=path:match("([^/.]+)$"),path=path,origin="loaded"}
    end
    return out
end
return {build=build, seed=seed}
