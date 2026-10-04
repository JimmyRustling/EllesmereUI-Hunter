-- FHK Gear: live Hunter damage model. Reads the same numbers as Forever's character sheet (ranged
-- attack power, crit, hit, haste, stat conversions, weapon skill, pet happiness), adds the researched
-- Forever rules in Data/Hunter.lua, and turns "damage per second" into stat weights in Agility units,
-- plus a per-weapon value where speed, ammo and weapon skill matter.
-- Model, per second of a levelling fight (fight length and melee share from the Model page):
--   Auto Shot  = (weapon DPS + ammo DPS + RAP/14) x haste            (independent of weapon speed)
--   Aimed / Multi-Shot (shared cooldown) = weapon hit + bonus per cast, minus the Auto Shot time its
--     cast costs; the better one is used, so slow weapons favour Aimed Shot
--   Arcane Shot = bonus + 0.204 x RAP per cast;  Serpent Sting = its total once per fight
--   all shots x landed (miss from weapon skill, minus hit; dodge) x crit (x2, Mortal Shots) x talents
--   melee (weaving share) = weapon + AP/14, Raptor Strike, off hand; pet = 22 % of RAP as its AP / 14
-- Approximations, labelled in /fhkgear hunter: mana is unlimited, mob armour is ignored (it lowers the
-- physical shots against Arcane Shot), and gear hit is valued from your hit without gear (no swap loops).
-- CC BY-NC-SA 4.0 (part of FHK Gear). See LICENSE.md.
if EUI_CLIENT_BLOCKED then return end
local _, ns = ...
local S = ns.Safe
local D = ns.HunterData
local M = {}
ns.HunterModel = M
local state, weights, lastWeights

local function Number(v, default) return S.Number(v) and v or default end
local function Settings() return ns.Char() end

-- Talent ranks: the player's own setting first, then the client's talent window, then "spell known".
local windowRanks, windowTried
local function TalentWindow()
    if windowTried then return windowRanks end
    windowTried, windowRanks = true, nil
    local api = C_SpecializationInfo and C_SpecializationInfo.GetTalentInfo
    if type(api) ~= 'function' then return nil end
    local byName, found = {}, false
    for spec = 1, 3 do
        for tier = 1, 11 do
            for column = 1, 4 do
                local ok, info = pcall(api, {specializationIndex = spec, tier = tier, column = column})
                if not ok then return nil end -- this client wants another query shape: stop at once
                if S.Table(info) and S.Text(info.name) and S.Number(info.rank) then
                    byName[info.name] = info.rank; found = true
                end
            end
        end
    end
    windowRanks = found and byName or nil
    return windowRanks
end
local function SpellName(id)
    local info = S.Read(C_Spell and C_Spell.GetSpellInfo, id)
    return S.Table(info) and S.Text(info.name) and info.name or nil
end
local function Known(id)
    for _, fn in ipairs({C_SpellBook and C_SpellBook.IsSpellKnown, _G.IsPlayerSpell, _G.IsSpellKnown}) do
        local v = S.Read(fn, id)
        if S.Plain(v) and type(v) == 'boolean' then return v end
    end
    return nil
end
-- rank, how ('set' / 'talent window' / 'spell known' / 'not learned' / 'unknown')
function M.TalentRank(key)
    local t = D.talents[key]
    if not t then return 0, 'unknown' end
    local own = Settings().hunterTalents[key]
    if S.Number(own) and own >= 0 and own <= t.max then return own, 'set' end
    local window = TalentWindow()
    local name = SpellName(t.id) or t.name
    if window and S.Number(window[name]) then return math.min(t.max, window[name]), 'talent window' end
    local known = Known(t.id)
    if known == true then return 1, t.max == 1 and 'spell known' or 'spell known (rank unread)' end
    if known == false then return 0, 'not learned' end
    return 0, 'unknown'
end
local function Fraction(key) local t = D.talents[key]; return M.TalentRank(key) / t.max end

-- Highest known rank of an ability, its numbers from the live description, and its cast time.
local function Ability(key)
    local a = D.abilities[key]
    local info = S.Read(C_Spell and C_Spell.GetSpellInfo, SpellName(a.id) or a.name)
    if not (S.Table(info) and S.Number(info.spellID)) then return nil end
    if Known(info.spellID) == false then return nil end
    local text = S.Read(C_Spell and C_Spell.GetSpellDescription or _G.GetSpellDescription, info.spellID)
    local bonus, over = 0, nil
    if S.Text(text) then
        local a1, a2 = text:match(a.pattern)
        bonus, over = tonumber(a1) or 0, tonumber(a2)
    end
    local cast = S.Number(info.castTime) and info.castTime / 1000 or a.cast or 0
    return {id = info.spellID, bonus = bonus, duration = over or a.duration, cast = cast, cooldown = a.cooldown, read = S.Text(text)}
end

-- Stat conversion from the client (exact, includes this level), else a labelled fallback.
local function Conversion(fn, index, current, fallback)
    if type(fn) ~= 'function' then return fallback, false end
    local a, b = S.Read(fn, index, current + 10), S.Read(fn, index, current)
    if S.Number(a) and S.Number(b) then return (a - b) / 10, true end
    return fallback, false
end
-- Weapon skill per skill line, read once per model refresh (cached in the state).
local function SkillLine(line, st)
    local cached = st.skills[line]
    if cached then return cached end
    local info = S.Read(C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID, line)
    if S.Table(info) and S.Number(info.rank) then
        cached = {rank = info.rank + Number(info.modifier, 0), read = true, name = S.Text(info.name) and info.name or nil}
    else cached = {read = false} end
    st.skills[line] = cached
    return cached
end
local function SkillFor(subclassID, st)
    local line = subclassID and D.skills[subclassID]
    local cap = st.level * D.combat.skillPerLevel
    if not line then return cap, cap, false end
    local s = SkillLine(line, st)
    if s.read then return s.rank, cap, true, s.name end
    return cap, cap, false
end
-- Miss chance against a mob of your level from a weapon-skill shortfall (Camelot table).
local function Miss(deficit)
    local c = D.combat
    if deficit <= 10 then return c.baseMiss + deficit * c.missPerSkill end
    return 7 + (deficit - 10) * c.missPerSkillOver10
end
-- Worn items read straight from the item cache: never through scoring, which asks the model.
local function Worn(slot)
    local link = S.Read(GetInventoryItemLink, 'player', ns.Engine.Inventory and ns.Engine.Inventory(slot) or slot)
    local info = S.Text(link) and ns.Items.Read(link) or nil
    return info and not info.missing and info or nil
end
-- Best ammo per type (2 arrows, 3 bullets) in the ammo slot or the bags, read once per refresh.
local function ReadAmmo()
    local out = {}
    local function Consider(info)
        if info and not info.missing and info.classID == 6 and S.Number(info.subclassID) then
            out[info.subclassID] = math.max(out[info.subclassID] or 0, Number(info.stats.DPS, 0))
        end
    end
    Consider(Worn(0))
    for _, job in ipairs(ns.Engine.BagItems and ns.Engine.BagItems() or {}) do if job.info.classID == 6 then Consider(job.info) end end
    return out
end
local function AmmoDPS(weaponSubclass)
    local want = D.ammoFor[weaponSubclass]
    if not want then return 0, true end
    local ammo = M.State().ammo
    if ammo[want] then return ammo[want], true end
    return 0, false
end
M.AmmoDPS = AmmoDPS

function M.Available()
    local _, class = S.Read(UnitClass, 'player')
    return class == 'HUNTER' and type(UnitRangedAttackPower) == 'function' and type(GetRangedCritChance) == 'function'
end
function M.Active()
    local source = Settings().source
    return M.Available() and (source == 'hunter' or source == 'auto')
end
function M.Invalidate() state = nil; windowTried = nil end
-- Ammo in the bags changes only with bag or equipment events; settings changes reuse the last read.
local ammoCache
function M.AmmoChanged() ammoCache = nil end

-- Live inputs, read only when the weights are rebuilt (equipment, level, talents, pet, settings).
function M.State()
    if state then return state end
    local c, st = Settings(), {estimates = {}, skills = {}}
    st.level = ns.Level()
    local base, pos, neg = S.Read(UnitRangedAttackPower, 'player')
    st.rap = math.max(0, Number(base, 0) + Number(pos, 0) + Number(neg, 0))
    base, pos, neg = S.Read(UnitAttackPower, 'player')
    st.ap = math.max(0, Number(base, 0) + Number(pos, 0) + Number(neg, 0))
    st.rangedCrit = Number(S.Read(GetRangedCritChance), 5)
    st.meleeCrit = Number(S.Read(GetCritChance), 5)
    local rating = function(cr) return cr and Number(S.Read(GetCombatRatingBonus, cr), 0) or 0 end
    st.rangedHit = rating(rawget(_G, 'CR_HIT_RANGED')) + Number(S.Read(GetRangedHitModifier or GetHitModifier), 0)
    st.meleeHit = rating(rawget(_G, 'CR_HIT_MELEE')) + Number(S.Read(GetHitModifier), 0)
    local hb, ha = S.Read(GetRangedHaste)
    st.haste = Number(hb, 0) + Number(ha, 0)
    -- Hit from worn items is taken back out, so wearing a hit item never lowers its own value.
    local gearHit = 0
    for _, slot in ipairs(ns.Engine.EQUIP_SLOTS or {}) do
        local info = Worn(slot)
        if info and S.Number(info.stats.Hit) then gearHit = gearHit + info.stats.Hit end
    end
    st.baseRangedHit, st.baseMeleeHit = math.max(0, st.rangedHit - gearHit), math.max(0, st.meleeHit - gearHit)
    local stat = D.stat
    local function Stat(index) local _, effective = S.Read(UnitStat, 'player', index); return Number(effective, 0) end
    local agi, str, int = Stat(stat.agility), Stat(stat.strength), Stat(stat.intellect)
    local ok
    st.agiRAP, ok = Conversion(GetRangedAttackPowerForStat, stat.agility, agi, 2); if not ok then st.estimates[#st.estimates + 1] = 'agility to ranged AP' end
    st.agiAP = Conversion(GetAttackPowerForStat, stat.agility, agi, 1)
    st.agiCrit, ok = Conversion(GetCritChanceFromStat, stat.agility, agi, 1 / (1 + 0.87 * st.level) / 100)
    st.agiCrit = st.agiCrit * 100
    if not ok then st.estimates[#st.estimates + 1] = 'agility to crit' end
    st.strAP = Conversion(GetAttackPowerForStat, stat.strength, str, 1)
    st.strRAP = Conversion(GetRangedAttackPowerForStat, stat.strength, str, 0)
    st.intRAP = Conversion(GetRangedAttackPowerForStat, stat.intellect, int, 0)
    st.intAP = Conversion(GetAttackPowerForStat, stat.intellect, int, 0)
    local careful = D.talents.carefulAim.intellectToAP * Fraction('carefulAim')
    if careful > 0 and st.intRAP == 0 then st.intRAP, st.intAP = careful, careful end -- talent not in the conversion API
    st.agilityMultiplier = 1 + D.talents.lightningReflexes.agility * Fraction('lightningReflexes')
    -- Pet: present, its happiness damage (125 % when happy), talents.
    -- Detect: a Hunter levels with a pet, so it counts even while dead, dismissed or despawned on a
    -- flight path (no weight churn or gear swaps). Only a Lone Wolf Hunter follows whether a pet is out.
    local petUp = true
    if M.TalentRank('loneWolf') > 0 then petUp = S.Read(UnitExists, 'pet') == true and S.Read(UnitIsDead, 'pet') ~= true end
    if c.hunterPet == 'pet' then petUp = true elseif c.hunterPet == 'none' then petUp = false end
    st.pet = petUp
    local _, petDamage = S.Read(C_PetInfo and C_PetInfo.GetPetHappiness)
    st.petMultiplier = (Number(petDamage, 100) / 100) * (1 + D.talents.unleashedFury.petDamage * Fraction('unleashedFury'))
    st.petCrit = D.pet.baseCrit + D.talents.ferocity.petCrit * Fraction('ferocity')
    -- Talent damage multipliers.
    local all = 1
    if petUp then all = all * (1 + D.talents.focusedFire.petActiveDamage * Fraction('focusedFire')) end
    if not petUp then all = all * (1 + D.talents.loneWolf.noPetDamage * Fraction('loneWolf')) end
    if petUp then st.petMultiplier = st.petMultiplier * (1 + D.talents.focusedFire.petActiveDamage * Fraction('focusedFire')) end
    st.all = all
    st.rangedMultiplier = all * (1 + D.talents.rangedSpecialization.rangedDamage * Fraction('rangedSpecialization'))
    st.rangedCritMultiplier = D.combat.critMultiplier + (D.combat.critMultiplier - 1) * D.talents.mortalShots.rangedCritBonus * Fraction('mortalShots')
    st.meleeCritMultiplier = D.combat.critMultiplier + (D.combat.critMultiplier - 1) * D.talents.predatorsEdge.meleeCritBonus * Fraction('predatorsEdge')
    st.barrage = 1 + D.talents.barrage.aimedMulti * Fraction('barrage')
    st.stings = 1 + D.talents.improvedStings.serpent * Fraction('improvedStings')
    st.offHand = D.combat.offHand * (1 + D.talents.predatorsEdge.offHand * Fraction('predatorsEdge'))
    -- Abilities you know right now.
    st.arcane, st.aimed, st.multi, st.serpent, st.raptor = Ability('arcane'), Ability('aimed'), Ability('multi'), Ability('serpent'), Ability('raptor')
    if st.arcane then st.arcane.cooldown = st.arcane.cooldown - D.talents.improvedArcaneShot.arcaneCooldown * Fraction('improvedArcaneShot') end
    st.fight = math.max(1, math.min(600, Number(c.fightLength, 15)))
    st.melee = math.max(0, math.min(1, Number(c.meleeShare, 0.175)))
    st.targets = math.max(1, math.min(10, Number(c.multiTargets, 1)))
    -- Worn weapons, as the model sees them.
    st.worn = {[16] = Worn(16), [17] = Worn(17), [18] = Worn(18)}
    state = st
    ammoCache = ammoCache or ReadAmmo()
    st.ammo = ammoCache
    -- What weapon values depend on beyond the weights: ammo types you have, and ranged weapon skills.
    local parts = {}
    for _, sub in ipairs({2, 3}) do parts[#parts + 1] = st.ammo[sub] and ('a' .. sub .. ':' .. st.ammo[sub]) or ('a' .. sub .. ':-') end
    for _, line in ipairs({45, 46, 226}) do local s = SkillLine(line, st); parts[#parts + 1] = line .. ':' .. tostring(s.rank) end
    parts[#parts + 1] = 'L' .. st.level
    st.signature = table.concat(parts, ',')
    return st
end

local function WeaponFacts(info, st)
    if not info or info.missing then return nil end
    local speed = Number(info.speed, nil)
    local dps = Number(info.stats.DPS, nil)
    if not dps and speed and S.Number(info.stats.Damage) and speed > 0 then dps = info.stats.Damage / speed end
    if not (speed and dps and speed > 0) then return nil end
    local skill, cap, read, name = SkillFor(info.subclassID, st)
    return {dps = dps, speed = speed, deficit = math.max(0, cap - skill), skillRead = read, subclassID = info.subclassID,
        skill = skill, cap = cap, skillName = name}
end
M.WeaponFacts = WeaponFacts

-- Ranged damage per second while shooting, for a given weapon and stat changes.
local function Ranged(st, w, d)
    if not w then return 0 end
    d = d or {}
    local rap = st.rap + (d.rap or 0)
    local gear = d.gearHit or (st.rangedHit - st.baseRangedHit)
    local miss = math.max(0, Miss(w.deficit) - math.max(0, st.baseRangedHit + (d.hit or 0) + gear))
    local landed = math.max(0, 1 - miss / 100 - D.combat.dodge / 100)
    local crit = math.min(100, st.rangedCrit + (d.crit or 0))
    local critFactor = 1 + crit / 100 * (st.rangedCritMultiplier - 1)
    local haste = 1 + (st.haste + (d.haste or 0)) / 100
    local ammo = w.ammo or 0
    local perShot = (w.dps + ammo) * w.speed + rap / D.combat.apPerDPS * w.speed
    local auto = perShot / (w.speed / haste)
    local dps = auto
    -- Aimed Shot and Multi-Shot share a cooldown: use whichever is worth more for this weapon.
    local best = 0
    if st.aimed then best = math.max(best, (perShot + st.aimed.bonus) * st.barrage - st.aimed.cast * auto) end
    if st.multi then best = math.max(best, (perShot + st.multi.bonus) * st.targets * st.barrage - st.multi.cast * auto) end
    dps = dps + math.max(0, best) / 6
    if st.arcane then dps = dps + (st.arcane.bonus + D.abilities.arcane.rap * rap) / math.max(1, st.arcane.cooldown) end
    local total = dps * landed * critFactor
    if st.serpent and st.serpent.bonus > 0 then
        local duration = st.serpent.duration or 15
        total = total + st.serpent.bonus * math.min(1, st.fight / duration) / st.fight * landed * st.stings
    end
    return total * st.rangedMultiplier
end
local function Melee(st, main, off, d)
    if not main and not off then return 0 end
    d = d or {}
    local ap = st.ap + (d.ap or 0)
    local crit = math.min(100, st.meleeCrit + (d.crit or 0))
    local critFactor = 1 + crit / 100 * (st.meleeCritMultiplier - 1)
    local function Landed(w, extra)
        local gear = d.gearHit or (st.meleeHit - st.baseMeleeHit)
        local miss = math.max(0, Miss(w.deficit) + (extra or 0) - math.max(0, st.baseMeleeHit + (d.hit or 0) + gear))
        return math.max(0, 1 - miss / 100 - D.combat.dodge / 100)
    end
    local dps = 0
    local haste = 1 + (d.haste or 0) / 100
    if main then
        local perSwing = main.dps * main.speed + ap / D.combat.apPerDPS * main.speed
        dps = dps + perSwing / main.speed * haste * Landed(main, off and D.combat.dualWieldMiss or 0)
        if st.raptor then dps = dps + (perSwing + st.raptor.bonus) / math.max(1, st.raptor.cooldown) * Landed(main) end
    end
    if off then
        local perSwing = (off.dps * off.speed + ap / D.combat.apPerDPS * off.speed) * st.offHand
        dps = dps + perSwing / off.speed * haste * Landed(off, D.combat.dualWieldMiss)
    end
    return dps * critFactor * st.all
end
local function Pet(st, d)
    if not st.pet then return 0 end
    local rap = st.rap + ((d and d.rap) or 0)
    return D.pet.rapToAP * rap / D.combat.apPerDPS * st.petMultiplier * (1 - D.pet.baseMiss / 100) * (1 + st.petCrit / 100)
end
local function Weapons(st)
    local f = st.wornFacts
    if not f then
        f = {WeaponFacts(st.worn[18], st), WeaponFacts(st.worn[16], st), WeaponFacts(st.worn[17], st)}
        if f[1] then f[1].ammo = AmmoDPS(f[1].subclassID) end
        st.wornFacts = f
    end
    return f[1], f[2], f[3]
end
-- Total damage per second for a stat change d (rap, ap, crit, hit, haste in percent points).
local function Total(st, d)
    local r, mh, oh = Weapons(st)
    return Ranged(st, r, d) * (1 - st.melee) + Melee(st, mh, oh, d) * st.melee + Pet(st, d)
end
M.Total = function(d) return Total(M.State(), d) end

-- Weights in Agility units: the default Hunter Agility weight stays the yardstick, so survival stats
-- (Stamina, Armor, resistances) keep their built-in values next to the damage stats.
function M.Weights(defaults)
    local st = M.State()
    local base = Total(st)
    local function Gain(d) return Total(st, d) - base end
    local dps = {}
    local agi = 10 * st.agilityMultiplier
    dps.Agility = Gain({rap = st.agiRAP * agi, ap = st.agiAP * agi, crit = st.agiCrit * agi}) / 10
    dps.Strength = Gain({ap = st.strAP * 10, rap = st.strRAP * 10}) / 10
    dps.Intellect = Gain({ap = st.intAP * 10, rap = st.intRAP * 10}) / 10
    dps.RangedAttackPower = Gain({rap = 10}) / 10
    dps.AttackPower = Gain({ap = 10, rap = 10}) / 10
    dps.Crit = Gain({crit = 1})
    -- Hit is valued from your hit without gear, so wearing a hit item never changes its own worth.
    dps.Hit = Total(st, {hit = 1, gearHit = 0}) - Total(st, {gearHit = 0})
    dps.HastePercent = Gain({haste = 1})
    local yardstick = Number(defaults and defaults.Agility, 1.05)
    local scale = dps.Agility > 0 and yardstick / dps.Agility or nil
    if not scale then return nil, 'No ranged weapon or stats to model' end
    local w = {}
    for stat, value in pairs(dps) do w[stat] = math.max(0, value * scale) end
    -- Pet: 30 % of your Stamina becomes the pet's (it tanks while you level).
    w.Stamina = Number(defaults and defaults.Stamina, 0.15) * (st.pet and (1 + D.pet.stamina) or 1)
    w.DirectDPS, w.RangedDPS, w.MeleeDPS = scale, scale, scale * st.melee
    w.scale, w.dps, w.base = scale, dps, base
    return w
end
-- A weapon's own worth in Agility units (its damage, speed, ammo and your skill with it).
function M.WeaponValue(info, slot, w)
    local st = M.State()
    local facts = WeaponFacts(info, st)
    local scale = w and w.scale
    if not (facts and scale) then return 0, true end
    local r, mh, oh = Weapons(st)
    -- Unread skill (client without the skill API) is assumed capped and noted, not a reason to stop.
    local known = true
    if not facts.skillRead and #st.estimates < 8 then st.estimates[#st.estimates + 1] = 'weapon skill' end
    if slot == 18 or ns.Engine.RANGED[info.equipLoc] and not slot then
        local ammo, found = AmmoDPS(facts.subclassID)
        facts.ammo = ammo
        if D.ammoFor[facts.subclassID] and not found then return 0, false, 'No matching ammo in your bags' end
        return Ranged(st, facts) * (1 - st.melee) * scale, known
    end
    if slot == 17 then return Melee(st, nil, facts) * st.melee * scale, known end
    return Melee(st, facts, nil) * st.melee * scale, known
end

-- Weapon skill below your cap costs misses, but it trains with use. Say how much more the weapon is
-- worth once trained (score units), so an upgrade-after-training is visible and stays your choice.
function M.SkillNote(info, slot, w)
    local st = M.State()
    local facts = WeaponFacts(info, st)
    if not (facts and facts.deficit > 0 and facts.skillRead and w and w.scale) then return nil end
    local now = M.WeaponValue(info, slot, w)
    local deficit = facts.deficit
    facts.deficit = 0
    local trained
    if slot == 18 or ns.Engine.RANGED[info.equipLoc] and not slot then
        facts.ammo = AmmoDPS(facts.subclassID)
        trained = Ranged(st, facts) * (1 - st.melee) * w.scale
    elseif slot == 17 then trained = Melee(st, nil, facts) * st.melee * w.scale
    else trained = Melee(st, facts, nil) * st.melee * w.scale end
    return {name = facts.skillName or 'Weapon', skill = facts.skill, cap = facts.cap, deficit = deficit, gain = math.max(0, trained - (now or 0))}
end

-- Rebuilt weights replace the old ones only after a real change (2 %), so scores stay stable.
function M.Refresh()
    M.Invalidate()
    if not M.Active() then lastWeights = nil; return false end
    local fresh = M.Weights(ns.Weights.Defaults(ns.Weights.ClassSpec()))
    if not fresh then return false end
    local changed = not lastWeights or lastWeights.signature ~= state.signature
    fresh.signature = state.signature
    if lastWeights and not changed then
        for stat, value in pairs(fresh.dps) do
            local old = lastWeights.dps[stat] or 0
            if math.abs(value - old) > 0.02 * math.max(math.abs(old), 0.0001) then changed = true end
        end
    end
    if changed then lastWeights = fresh end
    return changed
end
function M.Current()
    if not M.Active() then return nil end
    if not lastWeights then M.Refresh() end
    return lastWeights
end

-- One copyable report: every live input, what the model assumes, and its weights.
function M.Report()
    local st, w = M.State(), M.Current()
    local rows = {('FHK Gear %s Hunter model, level %d'):format(ns.VERSION, st.level)}
    local function Add(text, ...) rows[#rows + 1] = text:format(...) end
    Add('Ranged AP %d, melee AP %d, ranged crit %.2f%%, melee crit %.2f%%', st.rap, st.ap, st.rangedCrit, st.meleeCrit)
    Add('Ranged hit %.1f%% (%.1f%% without gear), haste %.1f%%', st.rangedHit, st.baseRangedHit, st.haste)
    Add('Per Agility: %.3f ranged AP, %.3f AP, %.4f%% crit; x%.2f Agility from talents', st.agiRAP, st.agiAP, st.agiCrit, st.agilityMultiplier)
    Add('Per Strength %.2f AP; per Intellect %.2f ranged AP', st.strAP, st.intRAP)
    Add('Pet %s, pet damage x%.2f, pet crit %.0f%%', st.pet and 'active' or 'none', st.petMultiplier, st.petCrit)
    Add('Damage x%.3f ranged, x%.3f all; crit x%.2f ranged, x%.2f melee', st.rangedMultiplier, st.all, st.rangedCritMultiplier, st.meleeCritMultiplier)
    for _, key in ipairs({'arcane', 'aimed', 'multi', 'serpent', 'raptor'}) do
        local a = st[key]
        Add('%s: %s', D.abilities[key].name, a and ('spell ' .. a.id .. ', bonus ' .. a.bonus .. ', cast ' .. a.cast .. 's' .. (a.read and '' or ', description unread')) or 'not known')
    end
    for _, key in ipairs(D.talentOrder) do local rank, how = M.TalentRank(key); Add('Talent %s: %d/%d (%s)', D.talents[key].name, rank, D.talents[key].max, how) end
    local r = Weapons(st)
    if r then Add('Ranged weapon %.1f DPS, %.2f speed, ammo %.1f DPS, skill short by %d', r.dps, r.speed, r.ammo or 0, r.deficit) end
    Add('Model DPS (levelling estimate): %.1f', Total(st))
    if w then
        local out = {}
        for _, stat in ipairs({'Agility', 'Strength', 'Intellect', 'AttackPower', 'RangedAttackPower', 'Crit', 'Hit', 'HastePercent', 'Stamina'}) do
            out[#out + 1] = ('%s=%.3g'):format(stat, w[stat] or 0)
        end
        Add('Weights (Agility units): %s', table.concat(out, ', '))
        Add('1 Agility = %.3f DPS', w.dps.Agility)
    else Add('Weights: unavailable (no ranged weapon, or the model is off)') end
    if #st.estimates > 0 then Add('Estimated (client conversion unavailable): %s', table.concat(st.estimates, ', ')) end
    Add('Assumes: unlimited mana, mob armour ignored, level-equal mobs, Aimed/Multi on a 6 s shared cooldown')
    Add('Reagent bag slots in this client: %s', tostring(rawget(_G, 'NUM_REAGENTBAG_SLOTS')))
    for _, name in ipairs({'HUNTER_AGILITY_TOOLTIP', 'CR_HUNTER_HIT_CAP_TOOLTIP', 'STAT_HUNTER_CRIT_BONUS', 'RANGED_ATTACK_POWER_TOOLTIP'}) do
        local text = rawget(_G, name); Add('%s = %s', name, S.Text(text) and text:gsub('\n', ' ') or 'nil')
    end
    return table.concat(rows, '\n')
end
