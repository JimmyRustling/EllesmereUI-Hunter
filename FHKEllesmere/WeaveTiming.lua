-- Advisory timing model. These estimates never alter WoW's native swing clock.
if EUI_CLIENT_BLOCKED then return end
local _, NS = ...
NS = _G.FHKEllesmereNS or NS
if NS.WeaveTiming then return end
if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end
local Timing = {}
NS.WeaveTiming = Timing

-- Change these defaults when Forever's Hunter mechanics change. Players can
-- also adjust either estimate in the native Ellesmere timing controls.
local defaults = {
    enabled = true,
    lockout = true,
    lockoutMode = 'melee', -- 'melee' follows PLAYER_SWING; 'fixed' is a fallback
    lockoutSeconds = 1.0,
    aim = true,
    aimSeconds = 0.5,
    plantSeconds = 0,
    resetRangedOnMelee = true, -- provisional Forever beta behavior
}
local settings = {}
local lockoutUntil, lockoutDuration

local function Valid(key, value)
    if key == 'lockoutMode' then return value == 'melee' or value == 'fixed' end
    if type(defaults[key]) == 'boolean' then return type(value) == 'boolean' end
    if key == 'plantSeconds' then
        return type(value) == 'number' and value == value and value >= 0 and value <= 2
    end
    return type(value) == 'number' and value == value and value >= 0.1 and value <= 2
end

local function Load()
    local saved = type(FHKEllesmereDB) == 'table' and
        type(FHKEllesmereDB.weaveTiming) == 'table' and
        FHKEllesmereDB.weaveTiming or nil
    for key, value in pairs(defaults) do
        if saved and Valid(key, saved[key]) then settings[key] = saved[key]
        else settings[key] = value end
    end
end

local function Save()
    if type(FHKEllesmereDB) ~= 'table' then return end
    FHKEllesmereDB.weaveTiming = FHKEllesmereDB.weaveTiming or {}
    for key, value in pairs(settings) do
        FHKEllesmereDB.weaveTiming[key] = value
    end
end

function Timing.ResetClock()
    lockoutUntil, lockoutDuration = nil, nil
end

function Timing.MeleeSwing(now, meleeDuration)
    if not settings.enabled or not settings.lockout then return end
    local duration = settings.lockoutMode == 'melee' and meleeDuration or settings.lockoutSeconds
    if type(duration) ~= 'number' or duration <= 0 then return end
    local finish = now + duration
    -- Either weapon still cooling down keeps the proposed restriction visible.
    if not lockoutUntil or finish > lockoutUntil then
        lockoutUntil, lockoutDuration = finish, duration
    end
end

function Timing.RangedSwing()
    -- An actual ranged shot disproves any remaining predicted lockout.
    lockoutUntil, lockoutDuration = nil, nil
end

function Timing.GetPlantSeconds()
    return settings.enabled and settings.plantSeconds or 0
end

function Timing.RangedResetsOnMelee()
    return settings.enabled and settings.resetRangedOnMelee
end

function Timing.MechanicalCost(meleeSpeed, rangedSpeed)
    if type(meleeSpeed) ~= 'number' or meleeSpeed <= 0 then return nil end
    local swing = meleeSpeed
    if settings.resetRangedOnMelee and type(rangedSpeed) == 'number' and
        rangedSpeed > 0 then swing = rangedSpeed end
    return swing + Timing.GetPlantSeconds()
end

function Timing.ProjectedDelay(startAt, nextShot, meleeSpeed, rangedSpeed)
    local cost = Timing.MechanicalCost(meleeSpeed, rangedSpeed)
    if type(startAt) ~= 'number' or type(nextShot) ~= 'number' or not cost then return nil end
    return math.max(0, startAt + cost - nextShot)
end

function Timing.BreakEvenEnd(nextShot, meleeSpeed, meleeDamage, rangedDPS, rangedSpeed)
    local cost = Timing.MechanicalCost(meleeSpeed, rangedSpeed)
    if type(nextShot) ~= 'number' or not cost or type(meleeDamage) ~= 'number' or
        type(rangedDPS) ~= 'number' or rangedDPS <= 0 then return nil end
    return math.min(nextShot, nextShot - cost + meleeDamage / rangedDPS)
end

function Timing.State(now, rangedExpires)
    if not settings.enabled then return nil end
    if settings.lockout and lockoutUntil and lockoutUntil > now then
        return 'lockout', lockoutUntil - now, lockoutDuration
    end
    local remaining = rangedExpires and rangedExpires - now
    if settings.aim and type(remaining) == 'number' and
        remaining > 0 and remaining <= settings.aimSeconds then
        return 'aim', remaining, settings.aimSeconds
    end
end

function Timing.GetSettings() return settings end

local frame = CreateFrame('Frame')
frame:RegisterEvent('PLAYER_LOGIN')
frame:SetScript('OnEvent', Load)
Load()

SLASH_FHKTIMING1 = '/fhktiming'
SlashCmdList.FHKTIMING = function(input)
    local command, argument = tostring(input or ''):lower():match('^%s*(%S*)%s*(%S*)')
    if command == 'off' then settings.enabled = false
    elseif command == 'on' then settings.enabled = true
    elseif command == 'reset' then
        for key, value in pairs(defaults) do settings[key] = value end
        Timing.ResetClock()
    elseif command == 'rangedreset' then
        if argument ~= 'on' and argument ~= 'off' then
            print('Use /fhktiming rangedreset on|off')
            return
        end
        settings.resetRangedOnMelee = argument == 'on'
    elseif command == 'lockout' or command == 'aim' or command == 'plant' then
        if command ~= 'plant' and (argument == 'on' or argument == 'off') then
            settings[command] = argument == 'on'
            if command == 'lockout' and argument == 'off' then Timing.ResetClock() end
        elseif command == 'lockout' and (argument == 'melee' or argument == 'fixed') then
            settings.lockoutMode = argument
            Timing.ResetClock()
        else
            local value = tonumber(argument)
            -- The same bounds as the saved settings (review C7), or a value would not survive /reload.
            local minimum = command == 'plant' and 0 or 0.1
            if value and value >= minimum and value <= 2 then
                settings[command .. 'Seconds'] = value
                if command == 'lockout' then
                    settings.lockoutMode = 'fixed'
                    Timing.ResetClock()
                end
            else
                print('Use /fhktiming ' .. command ..
                    (command == 'lockout' and ' on|off|melee|fixed|0-2' or ' 0-2'))
                return
            end
        end
    elseif command ~= '' and command ~= 'status' then
        print('Use /fhktiming on|off|status|reset|rangedreset on|off|lockout on|off|melee|fixed|SECONDS|aim on|off|SECONDS|plant SECONDS')
        return
    end
    Save()
    print(string.format('Hunter timing estimates: %s; melee lockout %s (%s%s); aim %s %.1fs; extra plant %.2fs; ranged reset on melee %s',
        settings.enabled and 'on' or 'off', settings.lockout and 'on' or 'off',
        settings.lockoutMode, settings.lockoutMode == 'fixed' and
            string.format(' %.1fs', settings.lockoutSeconds) or '',
        settings.aim and 'on' or 'off', settings.aimSeconds, settings.plantSeconds,
        settings.resetRangedOnMelee and 'on' or 'off'))
end
