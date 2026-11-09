-- SPDX-License-Identifier: MPL-2.0
-- The host adapter resolves every row afresh and never returns a replacement.
return function(resolve, set, report)
    local owned, debt = {}, {}
    local request, fault

    local function get(row)
        local ok, component = pcall(resolve, row)
        return ok and component or nil
    end

    local function write(row, value, probe)
        local component = get(row)
        local before = probe and true or not value
        if not component or component.bVisible ~= before then return false, false end
        local call = {key=row.key, value=value, row=row}
        request = call
        local ok = pcall(set, component, value)
        request = nil
        component = get(row)
        local confirmed = call.pre and call.post and not call.interference
            and component and component.bVisible == value
        if confirmed then return ok == true, true end
        if not probe and (not component or component.bVisible ~= before or call.interference) then
            debt[row.key] = "unconfirmed-write"
        end
        return false, false
    end

    local function release(reason)
        if request then
            fault = true
            return false
        end
        for i = #owned, 1, -1 do
            local row = owned[i]
            if row.foreign then
                if not row.foreignConfirmed then debt[row.key] = "foreign-write-unconfirmed" end
            else
                local component = get(row)
                if component and component.bVisible == false then
                    local _, restored = write(row, true)
                    if not restored then debt[row.key] = "restore-unconfirmed" end
                elseif not component or component.bVisible ~= true then
                    debt[row.key] = "identity-or-flag-lost"
                end
            end
            owned[i] = nil
        end
        if next(debt) then
            fault = true
            for key, detail in pairs(debt) do report("CLEANUP_PENDING", detail .. " " .. key) end
            return false
        end
        report("RELEASED", reason)
        return true
    end

    local function watch(channel, stage, key, value, propagate)
        local call = request
        if channel == "visible" and call and key == call.key and not call[stage]
            and (stage == "pre" or call.pre) and value == call.value and propagate == false then
            call[stage] = true
            return
        end
        local function affected(row)
            return row.key == key or (propagate == true and row.ancestors[key])
        end
        if call and affected(call.row) then
            fault = true
            if channel == "visible" then call.interference = true end
        end
        for _, row in ipairs(owned) do
            if affected(row) then
                fault = true
                if channel == "visible" then
                    row.foreign = true
                    if stage == "pre" then row.foreignConfirmed = false end
                    if stage == "post" and row.key == key then
                        local component = get(row)
                        row.foreignConfirmed = component and component.bVisible == value
                    end
                end
                if stage == "pre" then report("WRITER", channel .. " " .. key) end
            end
        end
    end

    local function mask(rows, eligible)
        if fault or #owned > 0 or #rows == 0 then return false end
        for _, row in ipairs(rows) do
            local component = get(row)
            if not eligible(row) or not component or component.bVisible ~= true or component.bHiddenInGame ~= false then
                return false
            end
            if not write(row, true, true) or fault then
                fault = true
                report("PROBE_FAILED", row.key)
                return false
            end
        end
        for _, row in ipairs(rows) do
            local component = get(row)
            if fault or not eligible(row) or not component
                or component.bVisible ~= true or component.bHiddenInGame ~= false then
                if #owned > 0 then release("admission-changed") end
                return false
            end
            local ok, confirmed = write(row, false)
            if confirmed then owned[#owned + 1] = row end
            if not ok or fault then
                fault = true
                report("WRITE_FAILED", row.key)
                release("partial-hide")
                return false
            end
        end
        if not eligible(rows[#rows]) then
            release("admission-changed-after-hide")
            return false
        end
        report("HIDDEN", "targets=" .. #owned)
        return true
    end

    local function intact()
        if fault then return false end
        for _, row in ipairs(owned) do
            local component = get(row)
            if not component or component.bVisible ~= false or component.bHiddenInGame ~= false then
                fault = true
                return false
            end
        end
        return true
    end

    return {
        mask=mask, release=release, watch=watch, intact=intact,
        active=function() return #owned > 0 end,
        faulted=function() return fault == true end,
        pending=function() return next(debt) ~= nil end,
        invalidate=function()
            fault = true
            if request then request.interference = true end
            for _, row in ipairs(owned) do row.foreign = true; row.foreignConfirmed = false end
        end,
    }
end
