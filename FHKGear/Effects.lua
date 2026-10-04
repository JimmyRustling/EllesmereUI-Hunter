-- FHK Gear: typed English effect facts, independent of scores/actions.
-- Adapted pattern vocabulary from AutoGear. CC BY-NC-SA 4.0; see LICENSE.md.
if EUI_CLIENT_BLOCKED then return end
local _, ns = ...
local S, F = ns.Safe, {}
ns.Effects = F
local N = '([%d]+%.?[%d]*)'
local RULES = {
    {'chance to get a critical strike with spells by ' .. N .. '%%', 'SpellCrit'},
    {'chance to hit with spells by ' .. N .. '%%', 'SpellHit'},
    {'chance to get a critical strike by ' .. N .. '%%', 'Crit'}, {'chance to hit by ' .. N .. '%%', 'Hit'},
    {'damage and healing done by magical spells and effects by up to ' .. N, 'SpellPower'},
    {'healing done by spells and effects by up to ' .. N, 'Healing'},
    {'restores ' .. N .. ' mana per 5 sec', 'Mp5'}, {'restores ' .. N .. ' health per 5 sec', 'Hp5'},
    {'increased defense %+' .. N, 'Defense'}, {'chance to dodge an attack by ' .. N .. '%%', 'Dodge'},
    {'chance to parry an attack by ' .. N .. '%%', 'Parry'}, {'chance to block attacks with a shield by ' .. N .. '%%', 'Block'},
    {'block value of your shield by ' .. N, 'BlockValue'},
}
local SCHOOLS = {arcane='ArcaneDamage',fire='FireDamage',frost='FrostDamage',nature='NatureDamage',shadow='ShadowDamage',holy='HolyDamage',magical='SpellDamage'}
local BUFFS = {['ranged attack power']='RangedAttackPower',['attack power']='AttackPower',agility='Agility',strength='Strength',
    stamina='Stamina',intellect='Intellect',spirit='Spirit',armor='Armor',['attack speed']='HastePercent'}
local function Amount(text) local n = tonumber(text); return S.Number(n) and n >= 0 and n <= 1000000 and n or nil end
local function Add(stats, stat, text)
    local n = Amount(text)
    if stat and n then stats[stat] = (stats[stat] or 0) + n; return true end
end
function F.Seconds(text)
    if not S.Text(text) then return nil end
    local m,s = tonumber(text:match(N .. '%s*min')) or 0, tonumber(text:match(N .. '%s*sec')) or 0
    local v = m * 60 + s
    return S.Number(v) and v > 0 and v or nil
end
function F.Static(text)
    if not S.Text(text) then return nil end
    local lower, stats = text:lower(), {}
    if lower:find('when fighting',1,true) or lower:find('against',1,true) then return nil, 'conditional' end
    local body = lower
    for _,rule in ipairs(RULES) do
        local v = body:match(rule[1])
        if Add(stats,rule[2],v) then body = body:gsub(rule[1],' ',1) end
    end
    local school, v = body:match('damage done by (%a+) spells and effects by up to ' .. N)
    if Add(stats,SCHOOLS[school],v) then body = body:gsub('damage done by (%a+) spells and effects by up to ' .. N,' ',1) end
    local rap = body:match('%+' .. N .. ' ranged attack power')
    if Add(stats,'RangedAttackPower',rap) then body = body:gsub('%+' .. N .. ' ranged attack power',' ',1) end
    Add(stats,'AttackPower',body:match('%+' .. N .. ' attack power'))
    -- Multiple supported buff/stat clauses on the same line are retained.
    for word,stat in pairs(BUFFS) do
        if stat ~= 'RangedAttackPower' and stat ~= 'AttackPower' and stat ~= 'HastePercent' then
            Add(stats,stat,body:match(word .. ' by ' .. N))
        end
    end
    return next(stats) and stats or nil
end
function F.Proc(text)
    if not S.Text(text) then return nil end
    local body = text:lower()
    -- An enemy debuff is not a player stat buff. Keep it unknown until modeled.
    if body:find('reduces',1,true) or body:find('decreases',1,true) then return nil, 'Enemy debuff not modeled' end
    local p = {kind=body:find('use:',1,true) and 'use' or body:find('when struck',1,true) and 'struck' or 'chance',text=body,stats={}}
    p.ranged = body:find('ranged',1,true) ~= nil and not body:find('melee',1,true)
    local cd = body:match('%(([^%)]-)cooldown%)')
    p.cooldown = F.Seconds(cd)
    p.duration = F.Seconds(body:match('for ([%d%.]+ sec)') or body:match('for ([%d%.]+ min)'))
    p.chance = Amount(body:match(N .. '%% chance'))
    local work = body:gsub('%b()', '')
    local rap = work:match('ranged attack power by ' .. N)
    if Add(p.stats,'RangedAttackPower',rap) then work = work:gsub('ranged attack power by ' .. N,' ',1) end
    for word,stat in pairs(BUFFS) do if stat ~= 'RangedAttackPower' then Add(p.stats,stat,work:match(word .. ' by ' .. N)) end end
    local static = F.Static(work)
    for stat,v in pairs(static or {}) do if p.stats[stat] == nil then p.stats[stat] = v end end
    if work:find('damage',1,true) and not work:find('damage done',1,true) then
        local a,b = work:match(N .. '%s+to%s+' .. N)
        if not a then a,b = work:match(N .. '%s*%-%s*' .. N) end
        local lo,hi = Amount(a),Amount(b)
        p.damage = lo and hi and (lo + hi) / 2 or Amount(work:match(N .. ' %a*%s*damage'))
        local tick = Amount(work:match('every ' .. N .. ' sec'))
        if p.damage and tick and tick > 0 and p.duration then
            p.tick, p.tickDamage = tick, p.damage
            p.damage = p.damage * math.floor(p.duration / tick)
        elseif p.damage and work:find(' over ',1,true) then
            p.duration = F.Seconds(work:match('over ([%d%.]+ sec)'))
            p.totalOverTime = p.duration ~= nil
        end
    end
    p.heal = Amount(work:match('heals? [%a ]-for ' .. N) or work:match('restores ' .. N .. ' health'))
    p.mana = Amount(work:match('restores ' .. N .. ' mana'))
    if not (next(p.stats) or p.damage or p.heal or p.mana) then return nil, 'Effect not modeled' end
    local components=0;for _ in pairs(p.stats) do components=components+1 end
    if p.damage then components=components+1 end;if p.heal then components=components+1 end;if p.mana then components=components+1 end
    local _,clauses=body:gsub(' and ',' ')
    p.partial=clauses>=components or body:find('summon',1,true)~=nil or body:find('absorbs',1,true)~=nil or body:find('extra attack',1,true)~=nil
    -- Compatibility diagnostic for a single-stat effect. Engine uses all p.stats.
    local stat,amount = next(p.stats)
    if stat and not next(p.stats,stat) then p.stat,p.amount = stat,amount end
    return p
end
function F.Skill(text)
    local skill,n = text:lower():match('increased ([%a ]-) %+' .. N)
    return skill,n and Amount(n)
end
function F.Enchant(text)
    if not S.Text(text) then return nil end
    local lower,stats=text:lower(),{}
    local names={agility='Agility',strength='Strength',stamina='Stamina',intellect='Intellect',spirit='Spirit',armor='Armor',
        ['attack power']='AttackPower',['ranged attack power']='RangedAttackPower',['weapon damage']='Damage',['spell damage']='SpellDamage',['healing']='Healing'}
    for word,stat in pairs(names) do
        local n=lower:match('%+' .. N .. '%s+' .. word .. '%f[^%a]') or lower:match(word .. '%s+%+' .. N)
        Add(stats,stat,n)
    end
    return next(stats) and stats or F.Static(lower)
end
function F.Conditional(text)
    local lower = text:lower()
    local n, creature = lower:match('%+' .. N .. ' attack power when fighting ([%a ]+)')
    if not n then n,creature = lower:match('%+' .. N .. ' attack power against ([%a ]+)') end
    return n and {stat='AttackPower',amount=Amount(n),creature=creature:gsub('[%s%.]+$','')} or nil
end
