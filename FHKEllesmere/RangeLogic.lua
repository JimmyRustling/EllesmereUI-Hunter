-- Public-only range classification shared with the optional Hunter addon.
if EUI_CLIENT_BLOCKED then return end
local _, NS = ...
NS = _G.FHKEllesmereNS or NS
if NS.RangeLogic then return end
local Range = {}
NS.RangeLogic = Range

local function Number(value)
    return (not issecretvalue or not issecretvalue(value)) and
        type(value) == 'number' and value == value and
        value > -math.huge and value < math.huge
end

local function Readable(value)
    return not issecretvalue or not issecretvalue(value)
end

function Range.ReadDistance(unit)
    if type(UnitDistanceSquared) ~= 'function' then return nil end
    local ok, squared, checked = pcall(UnitDistanceSquared, unit)
    if not ok or not Readable(checked) or checked ~= true or
        not Number(squared) or squared < 0 then return nil end
    return math.sqrt(squared)
end

function Range.ReadLibraryBracket(unit)
    if not LibStub then return nil end
    local ok, lib = pcall(LibStub, 'LibRangeCheck-3.0', true)
    if not ok or not lib or type(lib.GetRange) ~= 'function' then return nil end
    local success, low, high = pcall(lib.GetRange, lib, unit or 'target', true, false, 0.15)
    if not success or not Number(low) or low < 0 then return nil end
    if high ~= nil and (not Number(high) or high <= low) then return nil end
    return {low = low, high = high}
end

function Range.Measure(probes, melee, ranged, shot, bracket)
    local low, high, measured = 0, math.huge, false
    if bracket and Number(bracket.low) and bracket.low >= 0 and
        (bracket.high == nil or (Number(bracket.high) and bracket.high > bracket.low)) then
        low, high, measured = bracket.low, bracket.high or math.huge, true
    end
    for _, probe in ipairs(probes) do
        if Number(probe.min) and Number(probe.max) and probe.max > 0 and
            Readable(probe.inside) then
            if probe.inside == true then
                low, high, measured = math.max(low, probe.min), math.min(high, probe.max), true
            elseif probe.inside == false and probe.min == 0 then
                low, measured = math.max(low, probe.max), true
            end
        end
    end
    if (not Readable(ranged) or type(ranged) ~= 'boolean') and shot and
        Readable(shot.inside) and type(shot.inside) == 'boolean' then
        ranged = shot.inside
    end
    local state = 'unknown'
    if Readable(ranged) and ranged == true then state = 'shoot'
    elseif Readable(melee) and melee == true then state = 'melee'
    elseif Readable(ranged) and ranged == false and shot then
        if high <= shot.min and high < math.huge and shot.min > 0 then
            state, high = 'close', math.min(high, shot.min)
        elseif measured and low >= 5 and low < shot.min and
            high <= shot.max then
            -- A coarse 5-10 bracket can straddle the 8-yard boundary.
            -- The measured lower bound rules out melee, and Ranged=false
            -- rules out shooting. No separate melee API answer is needed.
            state, high = 'close', math.min(high, shot.min)
        elseif measured and low >= shot.max then
            state, low = 'far', math.max(low, shot.max)
        end
    end
    -- A measured 0-5 yard bracket is melee even when the swing-range API
    -- has not yet reported true for this target.
    if measured and high <= 5 and state ~= 'shoot' then state = 'melee' end
    if low >= high then
        -- A stale library bracket against a live yes/no answer (review R2): keep the answer,
        -- drop the yards. Only a conflict with nothing else known is unavailable.
        if state == 'shoot' or state == 'melee' then low, high, measured = 0, math.huge, false
        else return 'unknown', 'Range unavailable' end
    end
    if state == 'unknown' and Readable(ranged) and ranged == false then state = 'out' end
    if state == 'unknown' and measured then
        state = high == math.huge and 'beyond' or 'distance'
    end
    local yards = 'yards unavailable'
    if measured then
        if high == math.huge then yards = string.format('>%g yd', low)
        elseif low == 0 then yards = string.format('<=%g yd', high)
        else yards = string.format('~%g-%g yd', low, high) end
    end
    local labels = {melee = 'Melee', close = 'Too close', shoot = 'Shooting',
        far = 'Too far', distance = 'Distance', beyond = 'Out of range',
        out = 'Out of range', unknown = 'Range unavailable'}
    if state == 'unknown' then return state, labels[state] end
    return state, labels[state] .. ' | ' .. yards
end
