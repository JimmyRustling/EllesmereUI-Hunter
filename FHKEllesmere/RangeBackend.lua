-- Discover public spell/item probes and classify the current unit's range.
if EUI_CLIENT_BLOCKED then return end
local addon, NS = ...
NS = _G.FHKEllesmereNS or NS
if NS.GetUnitRange then return end
local DASH = '\226\128\147' -- en dash: range text format shared with FHK

local eventFrame = CreateFrame('Frame')


local probes = {}
local shot = nil



------------------------------------------------------------
-- VISUAL SETTINGS
------------------------------------------------------------

-- One line: state at left, verified distance or bracket at right.
local EXTRA_HEIGHT = 0
local MIN_HEIGHT = 30

------------------------------------------------------------
-- VALUE HELPERS
------------------------------------------------------------

local function Readable(value)

    return not (
        issecretvalue
        and issecretvalue(value)
    )
end

local function Number(value)

    return
        Readable(value)
        and type(value) == 'number'
        and value == value
        and value > -math.huge
        and value < math.huge
end

local function Call(fn, ...)

    if type(fn) ~= 'function' then
        return nil
    end

    local ok, value =
        pcall(
            fn,
            ...
        )

    if ok
        and Readable(value)
    then
        return value
    end
end

local function Boolean(value)

    if value == true
        or value == 1
    then
        return true
    end

    if value == false
        or value == 0
    then
        return false
    end
end

------------------------------------------------------------
-- DISCOVER HUNTER RANGE PROBES
------------------------------------------------------------

local function Discover()

    probes = {}
    shot = nil

    local book =
        C_SpellBook

    local spells =
        C_Spell

    local bank =
        Enum
        and Enum.SpellBookSpellBank
        and Enum.SpellBookSpellBank.Player

    local count =
        Call(
            book
            and book.GetNumSpellBookSkillLines
        )

    if not Number(count)
        or not bank
    then
        return
    end

    local seen = {}
    local brackets = {}

    for line = 1, count do

        local skill =
            Call(
                book.GetSpellBookSkillLineInfo,
                line
            )

        if type(skill) == 'table'
            and Number(skill.itemIndexOffset)
            and Number(skill.numSpellBookItems)
        then

            local first =
                skill.itemIndexOffset + 1

            local last =
                skill.itemIndexOffset
                + skill.numSpellBookItems

            for slot = first, last do

                local item =
                    Call(
                        book.GetSpellBookItemInfo,
                        slot,
                        bank
                    )

                local id =
                    type(item) == 'table'
                    and item.spellID

                if Number(id)
                    and not seen[id]
                then

                    seen[id] =
                        true

                    local info =
                        Call(
                            spells
                            and spells.GetSpellInfo,
                            id
                        )

                    if type(info) == 'table'
                        and Number(info.minRange)
                        and Number(info.maxRange)
                        and info.minRange >= 0
                        and info.maxRange > info.minRange
                    then

                        local probe = {
                            id = id,
                            slot = slot,
                            min = info.minRange,
                            max = info.maxRange,
                        }

                        ------------------------------------------------
                        -- AUTO SHOT
                        ------------------------------------------------

                        local auto =
                            Call(
                                book.IsRangedAutoAttackSpellBookItem,
                                slot,
                                bank
                            ) == true

                            or Call(
                                spells.IsRangedAutoAttackSpell,
                                id
                            ) == true

                            or id == 75

                        if auto then
                            shot = probe
                        end

                        ------------------------------------------------
                        -- HARMFUL SPELL RANGE PROBES
                        ------------------------------------------------

                        local harmful =
                            Call(
                                spells.IsSpellHarmful,
                                id
                            ) == true

                        local key =
                            info.minRange
                            .. ':'
                            .. info.maxRange

                        if harmful
                            and not brackets[key]
                            and #probes < 16
                        then

                            brackets[key] =
                                true

                            probes[
                                #probes + 1
                            ] = probe
                        end
                    end
                end
            end
        end
    end

    --------------------------------------------------------
    -- FALLBACK AUTO SHOT
    --------------------------------------------------------

    if not shot then

        local info =
            Call(
                spells
                and spells.GetSpellInfo,
                75
            )

        if type(info) == 'table'
            and Number(info.minRange)
            and Number(info.maxRange)
            and info.maxRange > info.minRange
        then

            shot = {
                id = 75,
                min = info.minRange,
                max = info.maxRange,
            }
        end
    end
end

------------------------------------------------------------
-- SPELL RANGE
------------------------------------------------------------

local function SpellRange(probe, unit)

    local book =
        C_SpellBook

    local bank =
        Enum
        and Enum.SpellBookSpellBank
        and Enum.SpellBookSpellBank.Player

    --------------------------------------------------------
    -- Spellbook range API first
    --------------------------------------------------------

    local value =
        probe.slot
        and Call(
            book
            and book.IsSpellBookItemInRange,
            probe.slot,
            bank,
            unit or 'target'
        )

    local answer =
        Boolean(value)

    if answer ~= nil then
        return answer
    end

    --------------------------------------------------------
    -- Direct spell API fallback
    --------------------------------------------------------

    return Boolean(
        Call(
            C_Spell
            and C_Spell.IsSpellInRange,
            probe.id,
            unit or 'target'
        )
    )
end

------------------------------------------------------------
-- COLOURS
------------------------------------------------------------

local hunter =
    RAID_CLASS_COLORS
    and RAID_CLASS_COLORS.HUNTER

local hunterGreen =
    hunter
    and {
        hunter.r,
        hunter.g,
        hunter.b
    }
    or {
        0.67,
        0.83,
        0.45
    }

local colors = {

    melee = {
        0.58,
        0.38,
        0.19
    },

    close = {
        0.92,
        0.18,
        0.17
    },

    far = {
        0.92,
        0.18,
        0.17
    },

    out = {
        0.92,
        0.18,
        0.17
    },

    beyond = {
        0.92,
        0.18,
        0.17
    },

    distance = {
        0.45,
        0.55,
        0.62
    },

    unknown = {
        0.42,
        0.42,
        0.42
    },
}

------------------------------------------------------------
-- FALLBACK BRACKET PARSER
------------------------------------------------------------

local function Bracket(text)

    if type(text) ~= 'string' then
        return nil, nil, nil
    end

    local low, high =
        text:match(
            '~([%d%.]+)%-([%d%.]+) yd'
        )

    if low then

        return
            string.format(
                '%s' .. DASH .. '%s yd',
                low,
                high
            ),
            tonumber(low),
            tonumber(high)
    end

    high =
        text:match(
            '<=([%d%.]+) yd'
        )

    if high then

        return
            '0' .. DASH
            .. high
            .. ' yd',
            0,
            tonumber(high)
    end

    low =
        text:match(
            '>([%d%.]+) yd'
        )

    if low then

        return
            low
            .. '+ yd',
            tonumber(low),
            nil
    end

    return nil, nil, nil
end

------------------------------------------------------------
-- AUTO SHOT RANGE
------------------------------------------------------------

local function ShotMinimum()

    if shot
        and Number(shot.min)
        and shot.min > 0
    then

        return shot.min
    end

    -- Hunter fallback
    return 8
end

-- Sniper Shot (Forever talent 1310687): the next 3 shots reach 10 yards further while its
-- buff is up. Read at most twice a second, only with the talent learned.
local sniperAt,sniperBonus=0,0
local function SniperBonus()
    local now=GetTime and GetTime() or 0
    if now-sniperAt<.5 then return sniperBonus end
    sniperAt,sniperBonus=now,0
    local T=NS.HunterTalents
    if not (T and T.Has and T.Has('sniperShot')) then return 0 end
    local name=C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(1310687)
    local get=C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
    if type(name)=='string' and type(get)=='function' then
        local ok,aura=pcall(get,'player',name,'HELPFUL')
        if ok and type(aura)=='table' and not (issecretvalue and issecretvalue(aura)) then sniperBonus=10 end
    end
    return sniperBonus
end
NS.EllesmereSniperBonus=SniperBonus
local function ShotMaximum()

    if shot
        and Number(shot.max)
        and shot.max > 0
    then

        return shot.max+SniperBonus()
    end

    -- Hunter fallback
    return 35+SniperBonus()
end

------------------------------------------------------------
-- SHOOTING COLOUR
------------------------------------------------------------

local function ShootingColor(
    low,
    high,
    yards
)

    local minRange =
        ShotMinimum()

    local maxRange =
        ShotMaximum()

    local position =
        Number(yards)
        and yards

        or Number(low)
        and Number(high)
        and (
            low + high
        ) / 2

        or Number(low)
        and low

        or (
            minRange
            + maxRange
        ) / 2

    --------------------------------------------------------
    -- Orange near minimum range.
    -- Hunter green towards maximum range.
    --------------------------------------------------------

    local span =
        math.max(
            1,
            maxRange - minRange
        )

    local fraction =
        math.max(
            0,
            math.min(
                1,
                (
                    position
                    - minRange
                )
                / span
            )
        )

    local near = {
        1,
        0.63,
        0.16
    }

    return {

        near[1]
            + (
                hunterGreen[1]
                - near[1]
            )
            * fraction,

        near[2]
            + (
                hunterGreen[2]
                - near[2]
            )
            * fraction,

        near[3]
            + (
                hunterGreen[3]
                - near[3]
            )
            * fraction,
    }
end

-- Nameplates use the same Hunter range palette as the main range bar.
function NS.NameplateRangeColor(yards)
    if not Number(yards) then return colors.unknown end
    if yards <= 5 then return colors.melee end
    if yards < ShotMinimum() then return colors.close end
    if yards > ShotMaximum() then return colors.far end
    return ShootingColor(nil, nil, yards)
end

local function ShootingBracket(raw, yards)
    local minimum, maximum = ShotMinimum(), ShotMaximum()
    local _, measuredLow, measuredHigh = Bracket(raw)
    local point = Number(yards) and yards or nil
    local edges = {minimum, 10, 15, 20, 25, 30, maximum}
    for index = 1, #edges - 1 do
        local low, high = edges[index], edges[index + 1]
        if high > low and
            ((point and point >= low and (point < high or
                index == #edges - 1 and point <= high)) or
            (not point and Number(measuredLow) and Number(measuredHigh) and
                measuredLow >= low and measuredHigh <= high)) then
            return string.format('%g' .. DASH .. '%g yd', low, high)
        end
    end
    -- A coarse probe spanning several bins does not justify a finer label.
    if Number(measuredLow) and Number(measuredHigh) then
        return string.format('%g' .. DASH .. '%g yd', math.max(minimum, measuredLow),
            math.min(maximum, measuredHigh))
    end
    return string.format('%g' .. DASH .. '%g yd', minimum, maximum)
end

------------------------------------------------------------
-- EXACT DISTANCE VALIDATION
------------------------------------------------------------

local function ExactMakesSense(
    state,
    yards
)

    if not Number(yards)
        or yards < 0
    then
        return false
    end

    local minRange =
        ShotMinimum()

    local maxRange =
        ShotMaximum()

    --------------------------------------------------------
    -- Small tolerances are deliberate.
    --
    -- The different range APIs do not necessarily update
    -- on precisely the same frame.
    --------------------------------------------------------

    if state == 'melee' then

        return
            yards <= 5.75

    elseif state == 'close' then

        return
            yards >= 4.25
            and yards <= minRange + 0.75

    elseif state == 'shoot' then

        return
            yards >= minRange - 0.75
            and yards <= maxRange + 1.0

    elseif state == 'far'
        or state == 'out'
        or state == 'beyond'
    then

        return
            yards >= maxRange - 1.0

    elseif state == 'distance'
        or state == 'unknown'
    then

        return true
    end

    return false
end

------------------------------------------------------------
-- PRESENTATION
------------------------------------------------------------

local function Present(
    state,
    raw,
    yards
)

    local minRange =
        ShotMinimum()

    local maxRange =
        ShotMaximum()

    --------------------------------------------------------
    -- USE EXACT RANGE TO CORRECT AMBIGUOUS STATES
    --
    -- We deliberately do NOT let it override an already
    -- confident Shooting / Melee / Deadzone result.
    --------------------------------------------------------

    if state == 'out' or state == 'distance' or state == 'unknown' then
        local measured, low, high = Bracket(raw)
        if Number(yards) then
            if yards <= 5 then state = 'melee'
            elseif yards < minRange then state = 'close'
            elseif yards < maxRange then state = 'distance'
            else state = 'far' end
        elseif measured then
            if high and high <= 5 then state = 'melee'
            elseif low and low >= 5 and low < minRange and high and
                high <= minRange then state = 'close'
            elseif low and low >= maxRange then state = 'far'
            else state = 'distance' end
        end
    end

    --------------------------------------------------------
    -- STATE LABEL
    --------------------------------------------------------

    local labels = {

        melee =
            'Melee',

        close =
            'Deadzone',

        shoot =
            'Shooting',

        far =
            'Out of range',

        out =
            'Out of range',

        beyond =
            'Out of range',

        distance =
            'Distance',

        unknown =
            raw
            or 'Range unavailable',
    }

    local title =
        labels[state]
        or raw
        or 'Range unavailable'

    --------------------------------------------------------
    -- AUTHORITATIVE GAMEPLAY BRACKET
    --------------------------------------------------------

    local bracket

    if state == 'melee' then

        bracket =
            '0' .. DASH .. '5 yd'

    elseif state == 'close' then

        bracket =
            string.format(
                '5' .. DASH .. '%g yd',
                minRange
            )

    elseif state == 'shoot' then

        bracket = ShootingBracket(raw, yards)

    elseif state == 'far'
    then

        bracket =
            string.format(
                '%g+ yd',
                maxRange
            )

    elseif state == 'distance' or state == 'beyond' or state == 'out' then

        bracket = Bracket(raw)

    else

        bracket =
            ''
    end

    bracket =
        bracket
        or ''

    --------------------------------------------------------
    -- LIVE EXACT DISTANCE
    --------------------------------------------------------

    local exact =
        '\226\128\148'

    if ExactMakesSense(
        state,
        yards
    )
    then

        exact =
            string.format(
                '%.1f yd',
                yards
            )
    end

    --------------------------------------------------------
    -- COLOUR
    --------------------------------------------------------

    local color

    if state == 'shoot' then

        local _, low, high =
            Bracket(raw)

        color =
            ShootingColor(
                low,
                high,
                yards
            )

    else

        color =
            colors[state]
            or colors.unknown
    end

    return
        title,
        exact,
        bracket,
        color,
        state
end

------------------------------------------------------------
-- RANGE MEASUREMENT
------------------------------------------------------------

local function Measure(unit)

    unit = unit or 'target'

    local api =
        NS.RangeLogic

    --------------------------------------------------------
    -- TARGET VALIDATION
    --------------------------------------------------------

    if Call(
        UnitExists,
        unit
    ) ~= true
    then

        return
            'unknown',
            'No target',
            nil
    end

    if Call(
        UnitIsDead,
        unit
    ) == true
    then

        return
            'unknown',
            'Target dead',
            nil
    end

    if Call(
        UnitCanAttack,
        'player',
        unit
    ) ~= true
    then

        return
            'unknown',
            'Friendly target',
            nil
    end

    --------------------------------------------------------
    -- NATIVE SWING RANGE
    --------------------------------------------------------

    local types =
        Enum
        and Enum.PlayerSwingType

    local native =
        unit == 'target'
        and C_SwingTimer
        and C_SwingTimer.IsTargetWithinSwingRange

    local melee =
        types
        and Boolean(
            Call(
                native,
                types.MainHand
            )
        )

    local ranged =
        types
        and Boolean(
            Call(
                native,
                types.Ranged
            )
        )

    --------------------------------------------------------
    -- SPELL RANGE PROBES
    --------------------------------------------------------

    local checks = {}

    for _, probe in ipairs(
        probes
    ) do

        checks[
            #checks + 1
        ] = {

            min =
                probe.min,

            max =
                probe.max,

            inside =
                SpellRange(
                    probe,
                    unit
                ),
        }
    end

    --------------------------------------------------------
    -- AUTO SHOT RANGE
    --------------------------------------------------------

    local auto

    if shot then

        auto = {

            min =
                shot.min,

            max =
                shot.max,

            inside =
                SpellRange(
                    shot,
                    unit
                ),
        }

        if auto.inside ~= nil then

            ranged =
                auto.inside
        end

        checks[
            #checks + 1
        ] =
            auto
    end

    --------------------------------------------------------
    -- LIBRANGECHECK BRACKET
    --------------------------------------------------------

    local bracket =
        api
        and api.ReadLibraryBracket
        and api.ReadLibraryBracket(unit)

    --------------------------------------------------------
    -- RANGELOGIC CLASSIFICATION
    --------------------------------------------------------

    local state, text =
        api.Measure(
            checks,
            melee,
            ranged,
            auto,
            bracket
        )

    --------------------------------------------------------
    -- LIVE EXACT DISTANCE
    --------------------------------------------------------

    local yards =
        api.ReadDistance
        and api.ReadDistance(
            unit
        )

    return
        state,
        text,
        yards
end


function NS.GetUnitRange(unit)
    local state, text, yards = Measure(unit or 'target')
    local title, exact, bracket, color, resolved = Present(state, text, yards)
    return {state=resolved,title=title,exact=exact,bracket=bracket,color=color,
        minimum=ShotMinimum(),maximum=ShotMaximum()}
end
function NS.GetTargetRange() return NS.GetUnitRange('target') end
eventFrame:RegisterEvent('PLAYER_LOGIN'); eventFrame:RegisterEvent('SPELLS_CHANGED')
eventFrame:SetScript('OnEvent', Discover)
