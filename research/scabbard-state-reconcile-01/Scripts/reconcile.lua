-- SPDX-License-Identifier: MPL-2.0
-- Policy only. The host supplies independently validated snapshots and time.
local function new(maxGapMs)
    local identity, since, last
    local function reset()
        identity, since, last = nil, nil, nil
    end

    local function observe(state, now, confirm)
        if state.phase ~= "STOWED" or type(state.identity) ~= "string"
            or state.identity == "" or type(now) ~= "number" or not (now >= 0 and now < math.huge) then
            reset()
            return "PASS-THROUGH"
        end
        if identity ~= state.identity or now < last or now - last > maxGapMs then
            identity, since = state.identity, now
        end
        last = now
        if now - since < 3000 then return "PASS-THROUGH" end

        local fresh = confirm()
        if fresh.phase ~= "STOWED" or fresh.identity ~= identity then
            reset()
            return "PASS-THROUGH"
        end
        return "SUPPRESSED" -- Intent only; no write or ownership is implied.
    end

    return {observe = observe, reset = reset}
end

return new
