-- FHK Gear: which stat weights score an item, and Pawn-format import/export.
-- Order: the player's own weights for class/spec/phase (merged over the defaults), then weights
-- imported from AutoGear, then the built-in defaults (Data/Weights.lua) with the Forever fixes below.
-- ForeverGear's scores (levels 1-20, when installed) are a separate source the engine asks directly.
-- Adapted from AutoGear (CC BY-NC-SA 4.0); this file is CC BY-NC-SA 4.0. See LICENSE.md.
if EUI_CLIENT_BLOCKED then return end
local _, ns = ...
local W = {}
ns.Weights = W
local S = ns.Safe
W.version = 1 -- bumped whenever the effective weights may change; item scores are cached per version

-- Stats shown on the Stat Weights page, in this order.
W.STATS = {'Agility', 'Strength', 'Stamina', 'Intellect', 'Spirit', 'AttackPower', 'RangedAttackPower',
    'Crit', 'Hit', 'Haste', 'Armor', 'RangedDPS', 'MeleeDPS', 'SpellPower', 'Healing', 'SpellCrit',
    'SpellHit', 'Mp5', 'SpellDamage', 'ArcaneDamage', 'FireDamage', 'FrostDamage', 'NatureDamage',
    'ShadowDamage', 'HolyDamage', 'Hp5', 'Defense', 'Dodge', 'Parry', 'Block', 'BlockValue',
    'HastePercent', 'Resistance', 'Procs', 'Damage', 'WeaponSkill', 'DPS'}
W.LABELS = {AttackPower = 'Attack Power', RangedAttackPower = 'Ranged Attack Power', Crit = 'Crit (per 1%)',
    Hit = 'Hit (per 1%)', RangedDPS = 'Ranged Weapon DPS', MeleeDPS = 'Melee Weapon DPS', SpellPower = 'Spell Power',
    SpellCrit = 'Spell Crit (per 1%)', SpellHit = 'Spell Hit (per 1%)', Mp5 = 'Mana per 5 Sec',
    SpellDamage = 'Spell Damage (no healing)', ArcaneDamage = 'Arcane Spell Damage', FireDamage = 'Fire Spell Damage',
    FrostDamage = 'Frost Spell Damage', NatureDamage = 'Nature Spell Damage', ShadowDamage = 'Shadow Spell Damage',
    HolyDamage = 'Holy Spell Damage', Hp5 = 'Health per 5 Sec', HastePercent = 'Attack Speed (per 1%)',
    Resistance = 'Resistance (any school)', Procs = 'Default Procs per Minute', Block = 'Block (per 1%)', BlockValue = 'Shield Block Value',
    Damage = 'Average Weapon Damage', WeaponSkill = 'Weapon Skill (per point)', DPS = 'Weapon DPS (fallback)'}

-- Client item-stat keys (C_Item.GetItemStats) to our stat names.
W.ITEM_MOD = {
    ITEM_MOD_STRENGTH_SHORT = 'Strength', ITEM_MOD_AGILITY_SHORT = 'Agility', ITEM_MOD_STAMINA_SHORT = 'Stamina',
    ITEM_MOD_INTELLECT_SHORT = 'Intellect', ITEM_MOD_SPIRIT_SHORT = 'Spirit', RESISTANCE0_NAME = 'Armor',
    ITEM_MOD_ATTACK_POWER_SHORT = 'AttackPower', ITEM_MOD_RANGED_ATTACK_POWER_SHORT = 'RangedAttackPower',
    ITEM_MOD_CRIT_RATING_SHORT = 'Crit', ITEM_MOD_CRIT_MELEE_RATING_SHORT = 'Crit', ITEM_MOD_CRIT_RANGED_RATING_SHORT = 'Crit',
    ITEM_MOD_HIT_RATING_SHORT = 'Hit', ITEM_MOD_HIT_MELEE_RATING_SHORT = 'Hit', ITEM_MOD_HIT_RANGED_RATING_SHORT = 'Hit',
    ITEM_MOD_HASTE_RATING_SHORT = 'Haste', ITEM_MOD_DODGE_RATING_SHORT = 'Dodge', ITEM_MOD_PARRY_RATING_SHORT = 'Parry',
    ITEM_MOD_BLOCK_RATING_SHORT = 'Block', ITEM_MOD_BLOCK_VALUE_SHORT = 'BlockValue', ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = 'Defense',
    ITEM_MOD_SPELL_POWER_SHORT = 'SpellPower', ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 'SpellDamage',
    ITEM_MOD_SPELL_HEALING_DONE_SHORT = 'Healing', ITEM_MOD_SPELL_CRIT_RATING_SHORT = 'SpellCrit',
    ITEM_MOD_SPELL_HIT_RATING_SHORT = 'SpellHit', ITEM_MOD_MANA_REGENERATION_SHORT = 'Mp5', ITEM_MOD_POWER_REGEN0_SHORT = 'Mp5',
    ITEM_MOD_SPELL_PENETRATION_SHORT = 'SpellPenetration', ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 'ArmorPenetration',
    ITEM_MOD_EXPERTISE_RATING_SHORT = 'Expertise', ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 'DPS',
    RESISTANCE1_NAME = 'Resistance', RESISTANCE2_NAME = 'Resistance', RESISTANCE3_NAME = 'Resistance',
    RESISTANCE4_NAME = 'Resistance', RESISTANCE5_NAME = 'Resistance', RESISTANCE6_NAME = 'Resistance',
}

-- Forever fixes (FHK Gear's own judgement, editable on the Stat Weights page):
-- * Explicit "chance to hit by 1%" lines are percentages. Structured rating units still need E3.
--   AutoGear's table values them per rating point, which makes 1% crit worth about 2 Agility.
--   These per-1% values follow common levelling guidance (1% crit or hit is worth roughly
--   18-22 points of a physical class's main stat; about 10-12 spell power for casters).
-- * Hunters: ranged weapon DPS values weapon-based shots; melee weapon DPS is a heuristic for weaving
--   (Survival melee builds value it more). AutoGear values both at DPS = 2.
-- * Healers value +healing items like spell power.
local ROLE = {
    DRUID = {None = 'caster', Balance = 'caster', Feral = 'physical', ['Feral Combat'] = 'physical', Guardian = 'tank', Restoration = 'healer'},
    HUNTER = {None = 'physical', ['Beast Mastery'] = 'physical', Marksmanship = 'physical', Survival = 'physical'},
    MAGE = {None = 'caster', Arcane = 'caster', Fire = 'caster', Frost = 'caster'},
    PALADIN = {None = 'physical', Holy = 'healer', Protection = 'tank', Retribution = 'physical'},
    PRIEST = {None = 'healer', Discipline = 'healer', Holy = 'healer', Shadow = 'caster'},
    ROGUE = {None = 'physical', Assassination = 'physical', Outlaw = 'physical', Combat = 'physical', Subtlety = 'physical'},
    SHAMAN = {None = 'physical', Elemental = 'caster', Enhancement = 'physical', Restoration = 'healer'},
    WARLOCK = {None = 'caster', Affliction = 'caster', Demonology = 'caster', Destruction = 'caster'},
    WARRIOR = {None = 'physical', Arms = 'physical', Fury = 'physical', Protection = 'tank'},
}
-- One-school spell damage ("+6 Arcane damage") is worth spell power times how much of the spec's
-- damage is that school. Hunters: only Arcane Shot is spell damage, so a small value.
local SCHOOLS = {
    MAGE = {None = {Arcane = 0.5, Fire = 0.8, Frost = 0.8}, Arcane = {Arcane = 1, Fire = 0.3, Frost = 0.5},
        Fire = {Fire = 1, Arcane = 0.2, Frost = 0.2}, Frost = {Frost = 1, Arcane = 0.2, Fire = 0.2}},
    WARLOCK = {None = {Shadow = 1, Fire = 0.5}, Affliction = {Shadow = 1, Fire = 0.2}, Demonology = {Shadow = 0.9, Fire = 0.4},
        Destruction = {Fire = 0.8, Shadow = 0.8}},
    PRIEST = {None = {Holy = 0.3, Shadow = 0.3}, Shadow = {Shadow = 1}, Holy = {Holy = 0.3}, Discipline = {Holy = 0.3}},
    DRUID = {None = {Nature = 0.4, Arcane = 0.3}, Balance = {Arcane = 0.9, Nature = 0.9}},
    SHAMAN = {None = {Nature = 0.4, Fire = 0.3, Frost = 0.2}, Elemental = {Nature = 1, Fire = 0.5, Frost = 0.3}},
    PALADIN = {None = {Holy = 0.4}, Holy = {Holy = 0.3}, Retribution = {Holy = 0.4}, Protection = {Holy = 0.5}},
    HUNTER = {None = {Arcane = 0.1}, ['Beast Mastery'] = {Arcane = 0.1}, Marksmanship = {Arcane = 0.15}, Survival = {Arcane = 0.1}},
}
W.SCHOOLS = SCHOOLS
local PERCENT = {
    physical = {Crit = 20, Hit = 18},
    tank = {Crit = 6, Hit = 10, Defense = 1.5, Dodge = 14, Parry = 12, Block = 8},
    caster = {SpellCrit = 11, SpellHit = 10, Crit = 0, Hit = 0},
    healer = {SpellCrit = 7, SpellHit = 0, Crit = 0, Hit = 0},
}
W.ROLE = ROLE

local function Copy(t) local c = {}; for k, v in pairs(t or {}) do c[k] = v end; return c end

-- Built-in defaults for class/spec with the Forever fixes applied.
function W.Defaults(class, spec)
    local byClass = ns.DefaultWeights and ns.DefaultWeights[class]
    if not byClass then return nil end
    local base = byClass[spec] or byClass.None
    if not base then return nil end
    local w = Copy(base)
    local role = ROLE[class] and (ROLE[class][spec] or ROLE[class].None) or 'physical'
    local main = math.max(w.Agility or 0, w.Strength or 0, w.SpellPower or 0, w.Intellect or 0, 0.5)
    for stat, perPercent in pairs(PERCENT[role] or {}) do
        -- Per-1% values are in "main stat" units (spell power for spell stats); scale to this table.
        local unit = stat:find('^Spell') and math.max(w.SpellPower or 1, 0.5) or main
        w[stat] = perPercent * unit
    end
    if role == 'healer' then w.Healing = w.SpellPower or 1 end
    -- Spell damage without healing: full spell power for damage dealers, little for healers.
    local sp = w.SpellPower or 0
    w.SpellDamage = role == 'healer' and sp * 0.15 or sp
    local schools = SCHOOLS[class] and (SCHOOLS[class][spec] or SCHOOLS[class].None) or {}
    for _, school in ipairs({'Arcane', 'Fire', 'Frost', 'Nature', 'Shadow', 'Holy'}) do
        local share = schools[school] or 0
        -- Hunters have almost no spell power weight; value their Arcane share against Agility instead.
        w[school .. 'Damage'] = class == 'HUNTER' and share * (w.Agility or 1) or share * w.SpellDamage
    end
    w.Hp5 = (w.Stamina or 0.1) * 2
    -- Attack speed procs (e.g. "+20% attack speed for 15 sec"): 1% haste is a little less than 1% crit.
    w.HastePercent = (role == 'physical' or role == 'tank') and (w.Crit or 0) * 0.9 or 0
    w.Resistance = 0.03 * main -- levelling: a little survival, never worth a real stat
    w.Procs = 1
    if role == 'tank' then w.BlockValue = 0.15 * main end
    if class == 'HUNTER' then
        w.RangedDPS = w.DPS or 2
        w.MeleeDPS = spec == 'Survival' and 1 or 0.35
        w.DPS = nil
    end
    return w
end

-- Spec: the player's choice, else the client's specialization name when it matches a known
-- spec, else "None". Forever has no classic talent API (probe 2026-10-04).
function W.Specs(class)
    local list = {}
    for spec in pairs(ns.DefaultWeights and ns.DefaultWeights[class] or {}) do list[#list + 1] = spec end
    table.sort(list, function(a, b) if a == 'None' then return true elseif b == 'None' then return false end return a < b end)
    return list
end
function W.DetectedSpec(class)
    local api = C_SpecializationInfo
    local index = S.Read(api and api.GetSpecialization or _G.GetSpecialization)
    if S.Number(index) and index > 0 then
        local a,b = S.Read(api and api.GetSpecializationInfo or _G.GetSpecializationInfo, index)
        local name = S.Text(b) and b or S.Table(a) and S.Text(a.name) and a.name or nil
        if name and ns.DefaultWeights[class] and ns.DefaultWeights[class][name] then return name end
    end
    return 'None'
end
function W.ClassSpec()
    local _, class = S.Read(UnitClass,'player')
    if not S.Text(class) then return 'UNKNOWN','None' end
    local char = ns.Char()
    local spec = char.spec
    if not (spec and ns.DefaultWeights[class] and ns.DefaultWeights[class][spec]) then spec = W.DetectedSpec(class) end
    return class, spec
end
function W.Phase()
    local char = ns.Char()
    if char.phase == 'levelling' or char.phase == 'endgame' then return char.phase end
    local level = ns.Level and ns.Level() or S.Read(UnitLevel, 'player')
    local cutoff=S.Number(char.phaseLevel) and math.max(10,math.min(60,char.phaseLevel)) or 60
    return (S.Number(level) and level or 1) < cutoff and 'levelling' or 'endgame'
end

-- The player's own values for class/spec/phase (sparse; nil = use the default).
function W.Custom(class, spec, phase, create)
    local db = ns.Account()
    if not db.weights then if not create then return nil end; db.weights = {} end
    local key = class .. ':' .. spec .. ':' .. phase
    if create and not S.Table(db.weights[key]) then db.weights[key] = {} end
    return S.Table(db.weights[key]) and db.weights[key] or nil
end

local current, currentSource, currentVersion
function W.Invalidate() W.version = W.version + 1 end
-- Effective weights now, and a short label for where they came from.
function W.Current()
    if currentVersion == W.version and current then return current, currentSource end
    local class, spec = W.ClassSpec()
    local phase = W.Phase()
    local w = W.Defaults(class, spec)
    local source = 'Built-in ' .. spec .. ' defaults'
    local imported = ns.Account().imported and ns.Account().imported[class .. ':' .. spec]
    if S.Table(imported) then
        w = w or {}
        for k,v in pairs(imported) do if S.Number(v) and v >= 0 and v <= 100000 then w[k] = v elseif k == 'weapons' then w[k] = v end end
        source = 'Imported from AutoGear'
    end
    -- Hunters: the live model (HunterModel.lua) replaces the static table for every damage stat.
    local model = ns.HunterModel and ns.HunterModel.Current()
    if model then
        w = w or {}
        for k, v in pairs(model) do if type(v) == 'number' then w[k] = v end end
        w.scale, w.dps = model.scale, model.dps
        source = 'Hunter model (live stats)'
    end
    local custom = W.Custom(class, spec, phase)
    if custom and next(custom) then
        -- Your own numbers win; the model's weapon value is then off too (no mixed units).
        if model then w.scale, w.dps = nil, nil end
        w = w or {}
        for k, v in pairs(custom) do if S.Number(v) and v >= 0 and v <= 100000 then w[k] = v end end
        source = 'Your ' .. spec .. ' ' .. phase .. ' weights'
    end
    current, currentSource, currentVersion = w, source, W.version
    return w, source
end

-- Pawn-format import: ( Pawn: v1: "Hunter: Beast Mastery": Agility=1, Ap=0.5, ... ) or plain stat=value pairs.
local PAWN = {
    Strength = 'Strength', Agility = 'Agility', Stamina = 'Stamina', Intellect = 'Intellect', Spirit = 'Spirit',
    Armor = 'Armor', Ap = 'AttackPower', Rap = 'RangedAttackPower', CritRating = 'Crit', HitRating = 'Hit',
    HasteRating = 'Haste', SpellDamage = 'SpellPower', SpellPower = 'SpellPower', Healing = 'Healing',
    SpellCritRating = 'SpellCrit', SpellHitRating = 'SpellHit', Mp5 = 'Mp5', DefenseRating = 'Defense',
    DodgeRating = 'Dodge', ParryRating = 'Parry', BlockRating = 'Block', BlockValue = 'BlockValue',
    ArcaneSpellDamage = 'ArcaneDamage', FireSpellDamage = 'FireDamage', FrostSpellDamage = 'FrostDamage',
    NatureSpellDamage = 'NatureDamage', ShadowSpellDamage = 'ShadowDamage', HolySpellDamage = 'HolyDamage', Hp5 = 'Hp5',
    Dps = 'DPS', MeleeDps = 'MeleeDPS', RangedDps = 'RangedDPS',
}
W.PAWN = PAWN
local OWN = {}
for _, stat in ipairs(W.STATS) do OWN[stat] = stat end
-- Returns weights, scale name (or nil), or nil and a reason. Accepts Pawn stat names and our own.
function W.Parse(text)
    if not S.Text(text) or text == '' or #text > 32768 then return nil, 'Paste a weight scale or stat=value pairs.' end
    local name = text:match('Pawn:%s*v%d+:%s*"([^"]+)"')
    local native = text:match('^FHKW:2:') ~= nil
    if native then text = text:gsub('^FHKW:2:[^:]*:', '')
    elseif text:find('Pawn:', 1, true) then text = text:gsub('^.-Pawn:%s*v%d+:%s*"[^"]*"%s*:%s*', ''):gsub('%s*%)%s*$', '') end
    text = text:gsub('%s+([%w]+)%s*=', ',%1=')
    local out, count = {}, 0
    for entry in text:gmatch('[^,]+') do
        local key, number = entry:match('^%s*([%w]+)%s*=%s*(%S+)%s*$')
        if not key then return nil, 'Use complete comma-separated stat=value entries.' end
        local stat, value = (native and OWN[key] or PAWN[key] or OWN[key]), tonumber(number)
        if not S.Number(value) or value < 0 or value > 100000 then return nil, 'Invalid weight for ' .. key .. '.' end
        if stat then
            if out[stat] ~= nil then return nil, 'Duplicate stat: ' .. stat .. '.' end
            out[stat] = value
            count = count + 1
        end
    end
    if count < 2 then return nil, 'No usable weights found: include at least two stats.' end
    if not native then
        if out.DPS and not (out.RangedDPS or out.MeleeDPS) then out.RangedDPS, out.MeleeDPS = out.DPS, out.DPS end
        out.DPS = nil
    end
    -- Pawn's SpellDamage covers damage-and-healing items; it also prices damage-only ones.
    if out.SpellPower and not out.SpellDamage then out.SpellDamage = out.SpellPower end
    return out, name
end
local REVERSE = {}
for key, stat in pairs(PAWN) do if not REVERSE[stat] or #key < #REVERSE[stat] then REVERSE[stat] = key end end
REVERSE.Crit, REVERSE.Hit, REVERSE.SpellPower = 'CritRating', 'HitRating', 'SpellDamage'
function W.Export(w, name)
    local parts = {}
    for _, stat in ipairs(W.STATS) do
        local v = w and w[stat]
        if S.Number(v) and v >= 0 and v <= 100000 then parts[#parts + 1] = stat .. '=' .. ('%.17g'):format(v) end
    end
    return 'FHKW:2:' .. (name or 'FHK Gear'):gsub('[:,\r\n]', ' ') .. ':' .. table.concat(parts, ', ')
end
function W.ExportPawn(w, name)
    local parts = {}
    for _, stat in ipairs(W.STATS) do
        local v = w and w[stat]
        if stat ~= 'SpellDamage' and S.Number(v) and v >= 0 and REVERSE[stat] then
            parts[#parts + 1] = REVERSE[stat] .. '=' .. ('%.17g'):format(v)
        end
    end
    return ('( Pawn: v1: "%s": %s )'):format((name or 'FHK Gear'):gsub('["\r\n]', ''), table.concat(parts, ', ')),
        'Pawn cannot preserve separate damage-only weights. Rating/percent units must match your Pawn client.'
end
