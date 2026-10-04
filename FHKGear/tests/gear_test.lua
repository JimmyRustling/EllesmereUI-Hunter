-- FHK Gear mocked tests (E2). Runs under fengari from the addon folder; see run.js.
local checks = 0
local function eq(actual, expected, what)
    checks = checks + 1
    if actual ~= expected then error(what .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2) end
end
local function near(actual, expected, what)
    checks = checks + 1
    if type(actual) ~= 'number' or math.abs(actual - expected) > 0.01 then error(what .. ': expected ~' .. expected .. ', got ' .. tostring(actual), 2) end
end

-- Client mocks -------------------------------------------------------------------------------
local level, combat, cursor, now = 20, false, nil, 100
local loaded, printed, statCalls, rewardTaken, rolled = {}, {}, 0, nil, {}
local inventoryCalls = 0
local RED = {r = 1, g = 0.125, b = 0.125}
ITEM_SOULBOUND, ITEM_BIND_ON_PICKUP, ITEM_BIND_ON_EQUIP = 'Soulbound', 'Binds when picked up', 'Binds when equipped'
ITEM_UNIQUE, ITEM_UNIQUE_EQUIPPABLE = 'Unique', 'Unique-Equipped'
NUM_BAG_SLOTS = 4
-- id, equipLoc, classID, stats, extra
local ITEMS = {
    [1] = {'Laminated Recurve Bow', 'INVTYPE_RANGED', 2, {ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 5.77}},
    [2] = {'Hunting Bow', 'INVTYPE_RANGED', 2, {ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 7}, {price = 500}},
    [3] = {'Scout Vest', 'INVTYPE_CHEST', 4, {ITEM_MOD_AGILITY_SHORT = 3, RESISTANCE0_NAME = 100}},
    [4] = {'Worn Vest', 'INVTYPE_CHEST', 4, {ITEM_MOD_AGILITY_SHORT = 2}, {price = 900}},
    [5] = {'Band of Stamina', 'INVTYPE_FINGER', 4, {ITEM_MOD_STAMINA_SHORT = 3}},
    [6] = {'Old Gun', 'INVTYPE_RANGEDRIGHT', 2, {ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 20}, {untrained = true}},
    [7] = {'Helm of Later', 'INVTYPE_HEAD', 4, {ITEM_MOD_AGILITY_SHORT = 9}, {req = 30}},
    [8] = {'Agile Ring', 'INVTYPE_FINGER', 4, {ITEM_MOD_AGILITY_SHORT = 2}},
    [9] = {'Linen Cloth', '', 7, {}, {price = 1000}},
    [10] = {'Keen Cloak', 'INVTYPE_CLOAK', 4, {}, {equip = 'Equip: Improves your chance to get a critical strike by 1%.'}},
    [11] = {'Green Bracers', 'INVTYPE_WRIST', 4, {ITEM_MOD_AGILITY_SHORT = 1}, {boe = true}},
    [12] = {'Shadow Boots', 'INVTYPE_FEET', 4, {ITEM_MOD_AGILITY_SHORT = 1}, {equip = 'Equip: Increases your effective stealth level.'}},
    [14] = {'Skycaller', 'INVTYPE_RANGEDRIGHT', 2, {ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 21.6}, {wand = true, equip = 'Equip: Increases damage done by Arcane spells and effects by up to 6.'}},
    [15] = {'Fiery Blade', 'INVTYPE_WEAPON', 2, {ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10}, {equip = 'Chance on hit: Blasts a target for 40 to 50 Fire damage.'}},
    [16] = {'Rage Blade', 'INVTYPE_WEAPON', 2, {ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10}, {equip = 'Chance on hit: Increases your attack power by 60 for 10 sec.'}},
    [17] = {'Hunter Badge', 'INVTYPE_TRINKET', 4, {}, {equip = 'Use: Increases your attack power by 120 for 20 sec. (2 Min Cooldown)'}},
    [18] = {'Venom Dirk', 'INVTYPE_WEAPON', 2, {}, {equip = 'Chance on hit: Wounds the target for 10 Nature damage every 2 sec for 10 sec.'}},
    [19] = {'Troll Ring', 'INVTYPE_FINGER', 4, {}, {equip = 'Chance on hit: Heals you for 60.'}},
    [20] = {'Fire Ward', 'INVTYPE_CLOAK', 4, {RESISTANCE2_NAME = 10}},
    [21] = {'Grey Cap', 'INVTYPE_HEAD', 4, {}, {quality = 0}},
    [22] = {'Plain Cap', 'INVTYPE_HEAD', 4, {}, {quality = 1}},
    [23] = {'Heavy Staff', 'INVTYPE_2HWEAPON', 2, {ITEM_MOD_AGILITY_SHORT = 20}},
    [24] = {'Small Sword', 'INVTYPE_WEAPONMAINHAND', 2, {ITEM_MOD_AGILITY_SHORT = 2}},
    [25] = {'Held Orb', 'INVTYPE_HOLDABLE', 4, {ITEM_MOD_AGILITY_SHORT = 1}},
    [26] = {'Epic Bracers', 'INVTYPE_WRIST', 4, {ITEM_MOD_AGILITY_SHORT = 10}, {quality = 4}},
    [27] = {'Rare Bracers', 'INVTYPE_WRIST', 4, {ITEM_MOD_AGILITY_SHORT = 5}, {quality = 3}},
    [28] = {'Rare BoE Bracers', 'INVTYPE_WRIST', 4, {ITEM_MOD_AGILITY_SHORT = 7}, {quality = 3, boe = true}},
    [29] = {'Better Grey Bow', 'INVTYPE_RANGED', 2, {ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 8}, {quality = 0}},
    [30] = {'Undead Slayer', 'INVTYPE_WEAPONMAINHAND', 2, {}, {equip = 'Equip: +30 Attack Power when fighting Undead.'}},
    [31] = {'Blocking Vest', 'INVTYPE_CHEST', 4, {ITEM_MOD_BLOCK_VALUE_SHORT = 5}},
    [13] = {'Lupine Buckler', 'INVTYPE_SHIELD', 4, {RESISTANCE0_NAME = 361, ITEM_MOD_INTELLECT_SHORT = 2, ITEM_MOD_SPIRIT_SHORT = 2}, {shield = true}},
}
local function Id(link) return tonumber(tostring(link):match('item:(%d+)')) end
function GetItemInfoInstant(link)
    local id = Id(link); local d = id and ITEMS[id]
    if not d then return nil end
    return id, nil, nil, d[2], nil, d[3], d[5] and d[5].subclass or 0
end
local missing = {}
C_Item = {
    GetItemInfo = function(link)
        local id = Id(link); local d = ITEMS[id]
        if not d or missing[id] then return nil end
        local x = d[5] or {}
        return d[1], link, x.quality or 2, 10, x.req or 1, nil, nil, nil, d[2], nil, x.price or 10, nil,nil,x.boe and 2 or 1,nil,x.setID
    end,
    GetItemStats = function(link) statCalls = statCalls + 1; local d = ITEMS[Id(link)]; return d and d[4] end,
    RequestLoadItemDataByID = function() end,
}
C_TooltipInfo = {GetHyperlink = function(link)
    local d = ITEMS[Id(link)]; local x = d[5] or {}
    local lines = {{leftText = d[1]}}
    if x.boe then lines[#lines + 1] = {leftText = ITEM_BIND_ON_EQUIP} end
    if x.untrained then lines[#lines + 1] = {leftText = 'Ranged', rightText = 'Gun', rightColor = RED} end
    if x.wand then lines[#lines + 1] = {leftText = 'Ranged', rightText = 'Wand', rightColor = RED} end
    if x.shield then lines[#lines + 1] = {leftText = 'Off Hand', rightText = 'Shield', rightColor = RED} end
    if x.req then lines[#lines + 1] = {leftText = 'Requires Level ' .. x.req, leftColor = level < x.req and RED or nil} end
    if x.speed then lines[#lines + 1] = {leftText = x.low .. ' - ' .. x.high .. ' Damage', rightText = 'Speed ' .. x.speed} end
    if x.equip then lines[#lines + 1] = {leftText = x.equip} end
    return {lines = lines}
end}
C_TooltipInfo.GetBagItem = function() return nil end
local equipped = {[18] = 'item:1', [5] = 'item:3', [11] = 'item:8'}
local bags = {[0] = {'item:2', 'item:4', 'item:5', 'item:6', 'item:7', 'item:10', 'item:11'}}
function GetInventoryItemLink(_, slot) inventoryCalls = inventoryCalls + 1; return equipped[slot] end
C_Container = {
    GetContainerNumSlots = function(bag) return bags[bag] and 10 or 0 end,
    GetContainerItemLink = function(bag, slot) return bags[bag] and bags[bag][slot] end,
    GetContainerItemInfo = function(bag, slot) local l = bags[bag] and bags[bag][slot]; return l and {hyperlink = l, isLocked = false} end,
    PickupContainerItem = function(bag, slot) cursor = bags[bag][slot]; bags[bag][slot] = nil end,
}
function EquipCursorItem(slot) local old = equipped[slot]; equipped[slot] = cursor; cursor = nil; if old then table.insert(bags[0], old) end end
function CursorHasItem() return cursor ~= nil end
function GetCursorInfo() if cursor then return 'item',Id(cursor),cursor end end
function ClearCursor() cursor = nil end
function SpellIsTargeting() return false end
function InCombatLockdown() return combat end
function UnitClass() return 'Hunter', 'HUNTER' end
function UnitLevel() return level end
function CanDualWield() return false end
function GetTime() return now end
C_AddOns = {IsAddOnLoaded = function(n) return loaded[n] == true end}
print = function(s) printed[#printed + 1] = tostring(s) end
local timers = {}
C_Timer = {After = function(_, fn) timers[#timers + 1] = fn end}
local function RunTimers() for _ = 1, 10 do local t = timers; timers = {}; if #t == 0 then return end; for _, fn in ipairs(t) do fn() end end end
local frames = {}
function CreateFrame()
    local f = {events = {}}
    f.RegisterEvent = function(self, e) self.events[e] = true end
    f.UnregisterEvent = function(self, e) self.events[e] = nil end
    f.SetScript = function(self, what, fn) self[what] = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
local choices, rollLink = {}, nil
function GetNumQuestChoices() return #choices end
function GetQuestItemLink(_, i) return choices[i] end
function GetQuestItemInfo(_, i) return 'x', nil, i == 1 and 3 or 1 end
function GetQuestReward(i) rewardTaken = i end
function GetLootRollItemLink() return rollLink end
local canNeed = true
function GetLootRollItemInfo() return nil, nil, nil, nil, nil, canNeed, true end
function RollOnLoot(id, choice) rolled[id] = choice end

-- Load the addon in TOC order ----------------------------------------------------------------
local ns = {}
local tocFiles = assert(FHK_TEST_TOC, 'runner supplies TOC order')
for _, file in ipairs(tocFiles) do
    assert(loadfile(file))('FHKGear', ns)
end
local core = frames[1]
local function Fire(event, ...) core.OnEvent(core, event, ...) end

-- Weights ---------------------------------------------------------------------------------------
local hw = ns.Weights.Defaults('HUNTER', 'None')
near(hw.Crit, 21, 'Hunter crit is valued per 1% (20 x Agility weight 1.05)')
eq(hw.RangedDPS, 2, 'Hunter ranged weapon DPS keeps AutoGear\'s value')
near(hw.MeleeDPS, 0.35, 'Hunter melee weapon DPS only counts for weaving')
eq(hw.DPS, nil, 'Hunter weapon DPS is split into ranged and melee')
near(ns.Weights.Defaults('HUNTER', 'Survival').MeleeDPS, 1, 'Survival values melee weapon DPS more')
local mage = ns.Weights.Defaults('MAGE', 'Fire')
eq(mage.SpellCrit > 5 and mage.Crit == 0, true, 'casters value spell crit per 1% and no melee crit')
eq(ns.Weights.Defaults('PRIEST', 'Holy').Healing, ns.Weights.Defaults('PRIEST', 'Holy').SpellPower, 'healers value +healing like spell power')
eq(ns.Weights.Defaults('DEATHKNIGHT', 'None'), nil, 'classes Forever lacks have no defaults')
local parsed, name = ns.Weights.Parse('( Pawn: v1: "Hunter: Beast Mastery": Agility=1.2, Ap=0.5, Dps=2.5, Bogus=4 )')
eq(name, 'Hunter: Beast Mastery', 'Pawn scale name is read')
eq(parsed.Agility, 1.2, 'Pawn Agility imports'); eq(parsed.AttackPower, 0.5, 'Pawn Ap maps to Attack Power')
eq(parsed.RangedDPS, 2.5, 'plain Dps fills ranged weapon DPS'); eq(parsed.DPS, nil, 'plain Dps is not kept twice')
eq(select(2, ns.Weights.Parse('Agility=1')) ~= nil, true, 'fewer than two stats is refused with a reason')
local back = ns.Weights.Parse(ns.Weights.Export(parsed, 'X'))
eq(back.Agility, 1.2, 'export then import keeps the weights')

-- Login with defaults: Mark Only ----------------------------------------------------------------
Fire('PLAYER_LOGIN'); RunTimers()
local c = ns.Char()
eq(c.autoEquip or c.autoQuest or c.autoRoll, false, 'new characters start in Mark Only')
eq(c.levellingOnly, true, 'Levelling Mode is on by default')
eq(c.autoEquipMaxQuality, 2, 'automatic equipping defaults to green or below')
eq(core.events.BAG_UPDATE_DELAYED, true, 'Mark Only listens to bags for Upgrade Found pop-ups')
c.popFound = false; ns.Changed()
eq(core.events.BAG_UPDATE_DELAYED, nil, 'Mark Only without pop-ups does not listen to bag events')
c.popFound = true; ns.Changed()
eq(core.events.START_LOOT_ROLL, nil, 'Mark Only does not listen to loot rolls')
eq(core.events.QUEST_COMPLETE, true, 'quest reward borders listen to the reward window')
eq(core.events.PLAYER_EQUIPMENT_CHANGED, true, 'tooltip comparisons watch equipment changes in Mark Only')
eq(core.events.SKILL_LINES_CHANGED, true, 'tooltip usability watches training in Mark Only')
eq(core.OnUpdate, nil, 'no OnUpdate script')

-- Items and scores ------------------------------------------------------------------------------
local bow = ns.Items.Read('item:2')
near(ns.Engine.Score(bow), 14, 'ranged weapon scores by ranged DPS weight')
local delta, slot = ns.Engine.Verdict(bow)
near(delta, 14 - 11.54, 'better bow is an upgrade by the score difference'); eq(slot, 18, 'bow goes in the ranged slot')
local calls = statCalls
ns.Items.Read('item:2'); ns.Engine.Score(bow)
eq(statCalls, calls, 'a second read and score hit the caches')
local d2, s2, why2 = ns.Engine.Verdict(ns.Items.Read('item:5'))
eq(s2, 12, 'a ring goes into the empty ring slot'); eq(why2, 'Fills an empty slot', 'empty slot reason')
local gun = ns.Items.Read('item:6')
eq(gun.usable, false, 'red weapon type marks an untrained weapon unusable'); eq(ns.Engine.Verdict(gun), nil, 'unusable item is never an upgrade')
eq(ns.Engine.Verdict(ns.Items.Read('item:7')), nil, 'item above your level is not an upgrade yet')
eq(ns.Engine.Verdict(ns.Items.Read('item:4')), nil, 'weaker chest is not an upgrade')
eq(ns.Items.Read('item:10').stats.Crit, 1, 'an Equip: crit line fills a stat the table lacks')
eq(ns.Items.Read('item:10').lineStats.Crit, true, 'a stat from an Equip: line is labelled as such')
eq(ns.Items.Read('item:12').unparsed[1], 'Equip: Increases your effective stealth level.', 'an Equip: line no rule understands is kept for /fhkgear item')
-- In game (E3, 2026-10-04): /fhkgear item on Lupine Buckler of the Owl read Armor=361, Intellect=2, Spirit=2, score 0.44, unusable (Shield).
local buckler = ns.Items.Read('item:13')
eq(buckler.usable, false, 'a Hunter cannot use a shield (red Shield text)'); eq(buckler.reason, 'Shield', 'the red text is the reason')
near(ns.Engine.Score(buckler), 0.44, 'buckler scores 0.44 as seen in game')
GameTooltip = {GetItem = function() return 'Lupine Buckler', 'item:13' end}
printed = {}; SlashCmdList.FHKGEAR('item')
eq(printed[1]:find('not usable: Shield', 1, true) ~= nil, true, '/fhkgear item says why an item is unusable')
GameTooltip = {GetItem = function() return 'Keen Cloak', 'item:10' end}
printed = {}; SlashCmdList.FHKGEAR('item')
eq(printed[1]:find('Crit=1 (Equip line)', 1, true) ~= nil, true, '/fhkgear item shows a stat came from an Equip: line')
GameTooltip = {GetItem = function() return 'Shadow Boots', 'item:12' end}
printed = {}; SlashCmdList.FHKGEAR('item')
eq(printed[2], '|cffd9a521Gear|r Line not scored yet: Equip: Increases your effective stealth level.', '/fhkgear item lists unscored Equip: lines')
-- Equip-line spell damage and procs (player: "equip power is not being weighted", "chance on proc ... need weighting")
local wand = ns.Items.Read('item:14')
eq(wand.stats.ArcaneDamage, 6, 'one-school spell damage is read from its Equip: line'); eq(wand.usable, false, 'a Hunter cannot use a wand')
local hunterW = ns.Weights.Current()
near(hunterW.ArcaneDamage, 0.105, 'Hunter Arcane spell damage is worth a little (Arcane Shot)')
near(ns.Weights.Defaults('MAGE', 'Arcane').ArcaneDamage, ns.Weights.Defaults('MAGE', 'Arcane').SpellDamage, 'an Arcane mage values Arcane damage like spell damage')
eq(ns.Weights.Defaults('MAGE', 'Fire').ArcaneDamage < ns.Weights.Defaults('MAGE', 'Fire').FireDamage, true, 'a Fire mage values Fire over Arcane')
eq(ns.Items.EquipLine('equip: increases damage done by shadow spells and effects by up to 9.'), 'ShadowDamage', 'Shadow school line')
eq(ns.Items.EquipLine('equip: increases damage done by magical spells and effects by up to 9.'), 'SpellDamage', 'all-school damage without healing')
eq(ns.Items.EquipLine('equip: restores 4 health per 5 sec.'), 'Hp5', 'health regen line')
eq(ns.Items.Read('item:30').stats.AttackPower, nil, 'conditional attack power is not counted as always active')
eq(ns.Items.Read('item:30').unparsed[1], 'Equip: +30 Attack Power when fighting Undead.', 'conditional effect stays visible for later modelling')
eq(ns.Items.Read('item:31').stats.BlockValue, 5, 'shield block value is not interpreted as percent block chance')
local blade = ns.Items.Read('item:15')
eq(blade.procs[1].damage, 45, 'a damage proc averages its range')
near(ns.Engine.ProcValue(blade, blade.procs[1], hunterW), 45 / 60 * 0.35, 'damage proc = damage per minute as melee DPS, priced at melee weapon DPS')
local rage = ns.Items.Read('item:16')
eq(rage.procs[1].stat, 'AttackPower', 'a stat proc is read'); eq(rage.procs[1].duration, 10, 'with its duration')
near(ns.Engine.ProcValue(rage, rage.procs[1], hunterW), 60 * (10 / 60) * (0.35 / 2) * hunterW.AttackPower, 'a melee stat proc counts its uptime, scaled to the Hunter melee share')
local badge = ns.Items.Read('item:17')
eq(badge.procs[1].kind, 'use', 'Use: effect'); eq(badge.procs[1].cooldown, 120, 'cooldown read from (2 Min Cooldown)')
c.fightLength=120
near(ns.Engine.ProcValue(badge, badge.procs[1], hunterW), 120 * (20 * 0.8 / 120) * hunterW.AttackPower, 'Use: one activation in a 120-second fight')
c.fightLength=15
near(ns.Engine.ProcValue(badge,badge.procs[1],hunterW),120*0.8*hunterW.AttackPower,'Use: short fight clips buff duration to the fight')
eq(ns.Engine.Verdict(badge) ~= nil, true, 'a Use: trinket fills an empty trinket slot with a real score')
eq(ns.Items.Read('item:18').procs[1].damage, 50, 'a damage-over-time proc counts every tick')
eq(ns.Items.Read('item:19').procs[1].heal, 60, 'a heal proc is read')
near(ns.Engine.Score(ns.Items.Read('item:20')), 10 * hunterW.Resistance, 'resistance has a small weight')
GameTooltip = {GetItem = function() return 'Hunter Badge', 'item:17' end}
printed = {}; SlashCmdList.FHKGEAR('item')
eq(printed[2] and printed[2]:find('Proc: +120 AttackPower for 20s (use, 120s cooldown)', 1, true) ~= nil, true, '/fhkgear item explains each proc')
eq(ns.Items.Read('item:11').bound, 'boe', 'bind-on-equip is read from the tooltip')
missing[2] = true; ns.Items.Invalidate()
eq(ns.Items.Read('item:2').missing, true, 'item data not loaded yet is reported as missing'); missing[2] = nil; ns.Items.Invalidate()

-- Custom weights override defaults -------------------------------------------------------------
ns.Weights.Custom('HUNTER', 'None', 'levelling', true).RangedDPS = 1
ns.Changed()
local _, source = ns.Weights.Current()
eq(source, 'Your None levelling weights', 'custom weights are named as the source')
near(ns.Engine.Score(ns.Items.Read('item:2')), 7, 'custom weights rescore cached items')
ns.Weights.Custom('HUNTER', 'None', 'levelling').RangedDPS = nil; ns.Changed()

-- Tooltip line ----------------------------------------------------------------------------------
local lines = {}
local tip = {AddLine = function(_, t) lines[#lines + 1] = t end}
ns.AddTooltipLine(tip, 'item:2'); eq(lines[1], 'Gear: +2.5 upgrade', 'tooltip shows the upgrade amount')
ns.AddTooltipLine(tip, 'item:1'); eq(lines[2], 'Gear: matches worn gear, score 11.5', 'link-only tooltip does not claim physical identity')
ns.AddTooltipLine(tip, 'item:9'); eq(#lines, 2, 'non-gear gets no tooltip line')
local invBefore = inventoryCalls
ns.AddTooltipLine(tip, 'item:2'); ns.AddTooltipLine(tip, 'item:4')
eq(inventoryCalls, invBefore, 'repeated tooltip hovers reuse equipped gear')
equipped[18] = 'item:2'; Fire('PLAYER_EQUIPMENT_CHANGED')
lines = {}; ns.AddTooltipLine(tip, 'item:2')
eq(lines[1], 'Gear: matches worn gear, score 14.0', 'manual equipment changes refresh the tooltip snapshot')
eq(inventoryCalls - invBefore, #ns.Engine.EQUIP_SLOTS, 'one fresh inventory read after an equipment change')
eq(#timers, 0, 'Mark Only equipment changes do not queue equip timers')
equipped[18] = 'item:1'; Fire('PLAYER_EQUIPMENT_CHANGED')
local trainBefore = statCalls
Fire('SKILL_LINES_CHANGED'); RunTimers(); ns.AddTooltipLine(tip, 'item:2')
eq(statCalls > trainBefore, true, 'training discards cached usability and equipment scores')
eq(#timers, 0, 'Mark Only training changes do not queue equip timers')
c.tooltip = false; ns.Changed()
eq(core.events.PLAYER_EQUIPMENT_CHANGED, true, 'quest comparisons still need equipment invalidation with tooltips off')
c.markQuest = false; c.popFound = false; ns.Changed()
eq(core.events.SKILL_LINES_CHANGED, nil, 'no training watcher when every scoring feature is off')
local hiddenBefore = inventoryCalls
ns.AddTooltipLine(tip, 'item:2')
eq(inventoryCalls, hiddenBefore, 'disabled tooltip does no equipment work')
c.tooltip = true; c.markQuest = true; ns.Changed()

-- Slot locks and ignored items -----------------------------------------------------------------
eq(ns.SetSlotLocked(18, true), true, 'a supported equipment slot can be locked')
eq(ns.Engine.Verdict(bow), nil, 'locked ranged slot never gets an upgrade')
eq(ns.SetSlotLocked(19, true), false, 'tabard is not a supported Gear slot')
ns.SetSlotLocked(18, false)
eq(ns.Engine.Verdict(bow) ~= nil, true, 'unlocking restores upgrade comparisons')
eq(ns.SetIgnored('item:2', true), true, 'an item link can be excluded')
eq(c.ignore[2], true, 'item exclusions are stored per item ID')
eq(ns.Engine.Verdict(bow), nil, 'ignored item never becomes an upgrade')
eq(ns.SetIgnored(' 2 ', false), true, 'a numeric item ID can be allowed again')
eq(ns.Engine.Verdict(bow) ~= nil, true, 'allowing the item restores comparisons')
eq(ns.SetIgnored('|cff1eff00|Hitem:2:0:0|h[Hunting Bow]|h|r', true), true, 'pasted coloured item hyperlink is accepted')
ns.SetIgnored(2, false)
for _, input in ipairs({'bad item', '0', '-2', '2.5', math.huge}) do
    eq(ns.SetIgnored(input, true), false, 'invalid exclusion is rejected: ' .. tostring(input))
end
eq(select(3, ns.Engine.Verdict(ns.Items.Read('item:21'))), 'Fills an empty slot', 'grey gear can fill an empty slot while levelling')
eq(ns.Engine.Verdict(ns.Items.Read('item:29')) ~= nil, true, 'a better grey weapon upgrades the starter weapon')
eq(select(3, ns.Engine.Verdict(ns.Items.Read('item:22'))), 'Fills an empty slot', 'ordinary gear with no weighted stats can still fill an empty slot')
equipped[16], equipped[17] = 'item:24', 'item:25'; Fire('PLAYER_EQUIPMENT_CHANGED')
local staff = ns.Items.Read('item:23')
eq(ns.Engine.Verdict(staff) ~= nil, true, 'a better two-hander beats both unlocked weapons')
ns.SetSlotLocked(17, true)
eq(ns.Engine.Verdict(staff), nil, 'a two-hander cannot remove a locked occupied off hand')
ns.SetSlotLocked(17, false)
missing[24] = true; ns.Items.Invalidate(); Fire('PLAYER_EQUIPMENT_CHANGED')
eq(ns.Engine.Verdict(staff), nil, 'unloaded equipped weapon is not treated as an empty slot')
missing[24] = nil; ns.Items.Invalidate(); Fire('PLAYER_EQUIPMENT_CHANGED')
eq(ns.Engine.Verdict(staff) ~= nil, true, 'comparison recovers when equipped item data arrives')
equipped[16], equipped[17] = nil, nil; Fire('PLAYER_EQUIPMENT_CHANGED')

-- Bounded cache, including bag-position entries -------------------------------------------------
local limit = ns.Items.CACHE_LIMIT
ns.Items.CACHE_LIMIT = 3; ns.Items.Invalidate()
local keep = ns.Items.Read('item:1')
ns.Items.Read('item:2'); ns.Items.Read('item:3'); ns.Items.Read('item:1')
ns.Items.Read('item:4')
eq(ns.Items.cache['item:1'], keep, 'recently hovered item survives cache pruning')
eq(ns.Items.cache['item:2'], nil, 'least recently used item is evicted')
ns.Items.Read('item:5', 0, 1); ns.Items.Read('item:5', 0, 2)
local size = 0; for _ in pairs(ns.Items.cache) do size = size + 1 end
eq(size, 3, 'bag-position variants count towards the same cache limit')
ns.Items.Invalidate()
eq(next(ns.Items.cache), nil, 'full invalidation clears the item cache')
ns.Items.CACHE_LIMIT = limit; ns.Engine.Invalidate()

-- Quest rewards ---------------------------------------------------------------------------------
local questBags=bags;bags={}
choices = {'item:4', 'item:2'}
local idx, how, _, ups = ns.Engine.QuestChoice()
eq(idx, 2, 'quest picks the upgrade'); eq(how, 'upgrade', 'by upgrade'); eq(ups[2] and not ups[1], true, 'only the upgrade is marked')
choices = {'item:4', 'item:3'}
idx, how = ns.Engine.QuestChoice()
eq(how, 'vendor', 'no upgrade falls back to vendor value'); eq(idx, 1, 'vendor value counts stack size (900 x 3 beats 10)')
choices = {'item:2', 'item:9'}
idx, how, _, ups = ns.Engine.QuestChoice()
eq(how, 'manual', 'a non-gear choice leaves the pick to the player'); eq(idx, nil, 'nothing is chosen'); eq(ups[1], true, 'the upgrade is still marked')
missing[4] = true; ns.Items.Invalidate(); choices = {'item:4'}
eq(select(2, ns.Engine.QuestChoice()), 'pending', 'unloaded reward data waits'); missing[4] = nil; ns.Items.Invalidate()
choices = {'item:4', 'item:2'}
Fire('QUEST_COMPLETE'); RunTimers()
eq(rewardTaken, nil, 'Mark Only never takes a quest reward')
c.autoQuest = true; ns.Changed()
Fire('QUEST_COMPLETE'); RunTimers()
eq(rewardTaken, 2, 'automatic mode takes the upgrade')
rewardTaken = nil; level = 60; ns.Changed()
eq(ns.LevellingCapped(), true, 'Levelling Mode caps automation at 60')
Fire('QUEST_COMPLETE'); RunTimers()
eq(rewardTaken, nil, 'at level 60 with Levelling Mode, quest rewards are only marked')
c.levellingOnly = false; ns.Changed()
eq(ns.Automating('autoQuest'), true, 'with Levelling Mode off, automation continues at 60')
c.levellingOnly = true; level = 20; c.autoQuest = false; ns.Changed()
bags=questBags

-- Auto-equip ------------------------------------------------------------------------------------
local originalBags = bags
bags = {[0] = {'item:26', 'item:27', 'item:11', 'item:28'}}
local epic = ns.Items.Read('item:26')
eq(ns.Engine.Verdict(epic) ~= nil, true, 'epic upgrade remains marked above the automatic rarity limit')
local candidates = ns.Engine.BagUpgrades(nil, true)
eq(#candidates, 1, 'automatic scan keeps the eligible upgrade for a shared target slot')
eq(candidates[1].info.id, 11, 'flagged epic and blue do not crowd out an eligible green')
c.autoEquipMaxQuality = 3; ns.Changed()
candidates = ns.Engine.BagUpgrades(nil, true)
eq(candidates[1].info.id, 28, 'blue limit with Auto-Equip Bind-on-Equip on permits the better blue BoE')
c.equipBoE = false; ns.Changed()
eq(ns.Engine.BagUpgrades(nil, true)[1].info.id, 27, 'Auto-Equip Bind-on-Equip off keeps every BoE in the bags')
c.equipBoE = true; ns.Changed()
c.autoEquipMaxQuality = 4; ns.Changed()
eq(ns.Engine.BagUpgrades(nil, true)[1].info.id, 26, 'epic limit permits an epic without a bind-on-equip restriction')
c.autoEquipMaxQuality = 0; ns.Changed()
eq(#ns.Engine.BagUpgrades(nil, true), 0, 'grey limit skips every green and higher item')
bags = {[0] = {'item:29'}}
eq(ns.Engine.BagUpgrades(nil, true)[1].info.id, 29, 'grey limit still permits a better grey weapon')
c.autoEquip = true; ns.Changed(); RunTimers()
eq(equipped[18], 'item:29', 'automatic action actually equips an improved grey weapon')
c.autoEquip = false; equipped[18] = 'item:1'; Fire('PLAYER_EQUIPMENT_CHANGED')
bags = {[0] = {'item:26', 'item:27', 'item:11'}}
c.autoEquipMaxQuality = 2; c.autoEquip = true; ns.Changed(); RunTimers()
eq(equipped[9], 'item:11', 'automatic action chooses the green and leaves blue and epic upgrades alone')
Fire('PLAYER_EQUIPMENT_CHANGED'); RunTimers()
eq(bags[0][1], 'item:26', 'epic remains in the bag above the quality cap')
eq(bags[0][2], 'item:27', 'blue remains in the bag above the quality cap')
c.autoEquip = false; equipped[9] = nil; Fire('PLAYER_EQUIPMENT_CHANGED')
bags = originalBags; c.autoEquipMaxQuality = 2; ns.Changed()
c.autoEquip = true; ns.Changed()
eq(core.events.BAG_UPDATE_DELAYED, true, 'auto-equip listens to bag changes')
combat = true; RunTimers()
eq(equipped[18], 'item:1', 'nothing is equipped in combat'); eq(core.events.PLAYER_REGEN_ENABLED, true, 'waits for combat to end')
combat = false; Fire('PLAYER_REGEN_ENABLED'); RunTimers()
eq(core.events.PLAYER_REGEN_ENABLED, nil, 'combat wait ends')
eq(equipped[15], 'item:10', 'the biggest gain goes first: the 1% crit cloak into the empty back slot')
eq(equipped[18], 'item:1', 'one item per pass')
Fire('PLAYER_EQUIPMENT_CHANGED'); RunTimers()
eq(equipped[18], 'item:2', 'the next pass equips the better bow')
Fire('PLAYER_EQUIPMENT_CHANGED'); RunTimers()
Fire('PLAYER_EQUIPMENT_CHANGED'); RunTimers()
eq(equipped[12], 'item:5', 'later passes fill the empty ring slot')
for _ = 1, 4 do Fire('PLAYER_EQUIPMENT_CHANGED'); RunTimers() end
eq(equipped[9], 'item:11', 'a bind-on-equip green may be equipped')
eq(equipped[1], nil, 'the over-level helm stays in the bag')
eq(equipped[5], 'item:3', 'the better chest stays on')
level = 60; ns.Changed()
eq(core.events.BAG_UPDATE_DELAYED, nil, 'at 60 in Levelling Mode, bag events are dropped')
level = 20; ns.Changed()
loaded.AutoGear = true; ns.Changed()
eq(ns.Automating('autoEquip'), false, 'with AutoGear enabled, Gear only marks'); eq(core.events.BAG_UPDATE_DELAYED, nil, 'and does not listen to bags')
loaded.AutoGear = nil; c.autoEquip = false; ns.Changed()

-- Loot rolls ------------------------------------------------------------------------------------
local rollBags=bags;bags={}
c.autoRoll = true; ns.Changed()
equipped[18] = 'item:1'
Fire('PLAYER_EQUIPMENT_CHANGED')
rollLink = 'item:2'; Fire('START_LOOT_ROLL', 7); eq(rolled[7], 1, 'Need on an upgrade')
rollLink = 'item:4'; Fire('START_LOOT_ROLL', 8); eq(rolled[8], 2, 'Greed on a non-upgrade')
canNeed = false; rollLink = 'item:2'; Fire('START_LOOT_ROLL', 9); eq(rolled[9], 2, 'Greed when Need is not allowed')
c.autoRoll = false; ns.Changed()
bags=rollBags

-- AutoGear migration ----------------------------------------------------------------------------
FHKGearDB = nil; ns.Account = ns.Account -- fresh account table is created lazily by Core
AutoGearDB = {ImportedWeights = {['HUNTER:None'] = {Agility = 2, RangedDPS = 3}}}
ns.Account().migratedAutoGear = nil
Fire('PLAYER_LOGIN'); RunTimers()
eq(ns.Account().imported['HUNTER:None'].Agility, 2, 'AutoGear imported weights are copied once')
local _, src = ns.Weights.Current()
eq(src, 'Imported from AutoGear', 'imported weights are the source when there are no custom ones')

-- Options (stub Ellesmere) ----------------------------------------------------------------------
local spec
local inputPopup
EllesmereUI = {RegisterPlugin = function(id, s) spec = s; spec.id = id; return true end, Widgets = {},
    BlankRowCfg = function() return {type = 'blank'} end,
    ShowInputPopup = function(_, cfg) inputPopup = cfg end}
local rows = {}
local W = EllesmereUI.Widgets
function W:SectionHeader() return nil, 30 end
function W:DualRow(_, _, l, r)
    assert(r, 'every Ellesmere row needs an explicit right-hand config')
    rows[#rows + 1] = {l, r}; return nil, 50
end
local opt = {}
for k, v in pairs(ns) do opt[k] = v end
assert(loadfile('Options.lua'))('FHKGear', opt)
eq(spec.id, 'FHKGear', 'plugin id is the folder name'); eq(spec.label, 'Gear', 'sidebar section is called Gear')
eq(#spec.modules[1].pages, 5, 'five pages including Model and Equipment Rules')
for _, page in ipairs(spec.modules[1].pages) do eq(spec.modules[1].buildPage(page, {}, -10) > 0, true, page .. ' page builds') end
local found
for _, r in ipairs(rows) do for _, cfg in ipairs(r) do if cfg and cfg.text == 'Levelling Mode' then found = cfg end end end
eq(found ~= nil, true, 'Levelling Mode toggle is on the Automation page')
found.setValue(false); eq(c.levellingOnly, false, 'the toggle writes the setting'); found.setValue(true)

rows = {}; spec.modules[1].buildPage('Equipment Rules', {}, 0)
local lock, add
for _, r in ipairs(rows) do for _, cfg in ipairs(r) do
    if cfg.text == 'Ranged' then lock = cfg elseif cfg.buttonText == 'Add Item' then add = cfg end
end end
eq(lock ~= nil and add ~= nil, true, 'Equipment Rules shows slot locks and an item exclusion control')
lock.setValue(true); eq(c.locked[18], true, 'slot toggle locks the actual ranged slot')
lock.setValue(false); eq(c.locked[18], nil, 'slot toggle unlocks it')
add.onClick(); inputPopup.onConfirm('item:2')
eq(c.ignore[2], true, 'Add Item popup stores the exclusion')
rows = {}; spec.modules[1].buildPage('Equipment Rules', {}, 0)
local allow
for _, r in ipairs(rows) do for _, cfg in ipairs(r) do if cfg.buttonText == 'Allow' then allow = cfg end end end
eq(allow ~= nil, true, 'ignored item has an Allow button')
allow.onClick(); eq(c.ignore[2], nil, 'Allow button removes the exclusion')
rows = {}; spec.modules[1].buildPage('Automation', {}, 0)
local rarity
for _, r in ipairs(rows) do for _, cfg in ipairs(r) do if cfg.text == 'Auto-Equip Up To' then rarity = cfg end end end
eq(rarity ~= nil, true, 'automatic rarity limit is shown in the Gear menu')
eq(rarity.values[3]:find('|cff0070dd', 1, true) ~= nil, true, 'Rare selector label uses its blue rarity colour')
eq(rarity.values[4]:find('|cffa335ee', 1, true) ~= nil, true, 'Epic selector label uses its purple rarity colour')
rarity.setValue(3); eq(c.autoEquipMaxQuality, 3, 'rarity selector stores the blue limit')
rarity.setValue(2)

-- Optional scoring addon and preferred sim exporter --------------------------------------------
local function FindRow(text)
    for _, r in ipairs(rows) do for _, cfg in ipairs(r) do if cfg.text == text then return cfg end end end
end
rows = {}; spec.modules[1].buildPage('Stat Weights', {}, 0)
eq(FindRow('Score Source').values.forevergear, nil, 'ForeverGear source is hidden without its addon')
eq(FindRow('MythicSim Character'), nil, 'MythicSim export is hidden without its addon')
local exported
SlashCmdList.MYTHICSIM = function(msg) exported = msg end
eq(ns.MythicSimAvailable(), false, 'a leftover slash handler alone does not enable the integration')
loaded.MythicSim = true
rows = {}; spec.modules[1].buildPage('Stat Weights', {}, 0)
local sim = FindRow('MythicSim Character')
eq(sim ~= nil, true, 'installed and enabled MythicSim gets a character export button')
sim.onClick(); eq(exported, 'export', 'button delegates to MythicSim export, not Pawn weights')
loaded.MythicSim = nil; exported = nil
eq(ns.OpenMythicSim(), false, 'export refuses to run after the addon becomes unavailable')
eq(exported, nil, 'unavailable exporter is not called')
local providerCallback, providerScore = nil, 42
ForeverGearAPI = {apiVersion = 1, IsReady = function() return true end,
    GetUpgradeState = function() return false, providerScore end,
    RegisterCallback = function(_, _, fn) providerCallback = fn end}
eq(ns.Engine.ForeverGearAvailable(), false, 'a stale scoring API alone does not enable ForeverGear')
loaded.ForeverGear = true
rows = {}; spec.modules[1].buildPage('Stat Weights', {}, 0)
eq(FindRow('Score Source').values.forevergear, 'ForeverGear', 'installed and ready ForeverGear appears as a score source')
FindRow('Score Source').setValue('forevergear')
near(ns.Engine.Score(ns.Items.Read('item:2')), 42, 'selected ForeverGear source delegates to its public API')
ns.Engine.Equipped()
providerScore = 43; providerCallback()
near(ns.Engine.Score(ns.Items.Read('item:2')), 43, 'ForeverGear profile callbacks invalidate cached scores')
near(ns.Engine.Equipped()[18].score, 43, 'provider callback also refreshes equipped scores')
ForeverGearAPI.IsReady = function() return false end
rows = {}; spec.modules[1].buildPage('Stat Weights', {}, 0)
eq(FindRow('Score Source').values.forevergear, nil, 'unready ForeverGear is hidden instead of exposing a dead source')
eq(FindRow('Score Source').getValue(), 'unavailable', 'an unavailable saved source shows its manual state accurately')
eq(ns.Engine.Score(ns.Items.Read('item:2')),nil,'an explicitly selected unavailable provider is unknown, never a zero-stat upgrade')
eq(ns.Engine.Verdict(ns.Items.Read('item:2')),nil,'an unavailable provider cannot choose equipment')
c.source = 'auto'; loaded.ForeverGear = nil; ForeverGearAPI = nil; ns.Changed()

-- Unsupported-client gate: loading any file must leave no runtime or settings -----------------
local oldFrames, oldSlash, oldGlobal = #frames, SlashCmdList.FHKGEAR, FHKGearNS
local oldSpec = spec
EUI_CLIENT_BLOCKED = true
local blocked = {}
for _, file in ipairs(tocFiles) do assert(loadfile(file))('FHKGear', blocked) end
eq(next(blocked), nil, 'blocked client creates no addon namespace entries')
eq(#frames, oldFrames, 'blocked client creates no event or options frames')
eq(SlashCmdList.FHKGEAR, oldSlash, 'blocked client does not register slash commands')
eq(FHKGearNS, oldGlobal, 'blocked client does not publish its namespace')
eq(spec, oldSpec, 'blocked client does not register Gear options')
EUI_CLIENT_BLOCKED = nil

-- Audit regressions use deterministic deadlines and unsuccessful client operations.
RunTimers()
assert(loadfile('tests/regression.lua'))({ns=ns,eq=eq,near=near,Fire=Fire,ITEMS=ITEMS,missing=missing,options=opt,spec=spec,
    getRows=function() return rows end,clearRows=function() rows={} end,
    setBags=function(value) bags=value end,getBags=function() return bags end,
    setEquipped=function(value) equipped=value end,getEquipped=function() return equipped end,
    setChoices=function(value) choices=value end,setRoll=function(value) rollLink=value end,
    getReward=function() return rewardTaken end,clearReward=function() rewardTaken=nil end,
    getRolled=function() return rolled end,setLevel=function(value) level=value end,
    getCursor=function() return cursor end,setCursor=function(value) cursor=value end,
    time=function() return now end,setTime=function(value) now=value end,
    printed=function() return printed end,loaded=loaded,core=core,getStats=function() return statCalls end,
    setNeed=function(value) canNeed=value end,getPopup=function() return inputPopup end})

print = function(s) io.write(tostring(s), '\n') end
print(('PASS: %d gear checks (E2 mocked; no in-game verification)'):format(checks))
