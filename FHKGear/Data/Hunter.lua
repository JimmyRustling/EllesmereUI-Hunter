-- FHK Gear: Forever Hunter facts for the live Hunter model (HunterModel.lua). Facts only, no code.
-- Sources, read 2026-10-04 (client 1.60.1.70205):
--   talents: https://foreverdb.net/class/Hunter/talents (values are the full-rank totals);
--   abilities: https://foreverdb.net/spell/<id> (Arcane Shot 3044, Aimed Shot 19434, Multi-Shot 2643,
--     Serpent Sting 1978, Raptor Strike 2973);
--   combat tables and pet conversions: Forever UI source, Blizzard_UIPanels_Game/Camelot/
--     PaperDollFrameStats.lua and PaperDollFrame.lua (HUNTER_PET_BONUS).
-- Per-rank ability numbers are read live from the client's spell descriptions; the patterns are here.
-- CC BY-NC-SA 4.0 (part of FHK Gear). See LICENSE.md.
if EUI_CLIENT_BLOCKED then return end
local _, ns = ...
ns.HunterData = {
    -- key = {id = talent spell ID, max = ranks, effect at full rank}. "inSheet" talents already show in the
    -- character sheet's live numbers, so the model never adds them a second time.
    talents = {
        rangedSpecialization = {id = 19507, max = 5, rangedDamage = 0.05, name = 'Ranged Weapon Specialization'},
        mortalShots = {id = 19485, max = 5, rangedCritBonus = 0.30, name = 'Mortal Shots'},
        barrage = {id = 19461, max = 3, aimedMulti = 0.10, name = 'Barrage'},
        improvedArcaneShot = {id = 19454, max = 5, arcaneCooldown = 1.5, name = 'Improved Arcane Shot'},
        improvedStings = {id = 1310661, max = 3, serpent = 0.20, name = 'Improved Stings'},
        focusedFire = {id = 1223755, max = 2, petActiveDamage = 0.02, name = 'Focused Fire'},
        loneWolf = {id = 415370, max = 1, noPetDamage = 0.20, name = 'Lone Wolf'},
        unleashedFury = {id = 19616, max = 5, petDamage = 0.15, name = 'Unleashed Fury'},
        ferocity = {id = 19598, max = 5, petCrit = 10, name = 'Ferocity'},
        lightningReflexes = {id = 19168, max = 5, agility = 0.10, name = 'Lightning Reflexes'},
        carefulAim = {id = 1223984, max = 5, intellectToAP = 1.00, name = 'Careful Aim'},
        predatorsEdge = {id = 1310627, max = 5, meleeCritBonus = 0.30, offHand = 0.50, name = "Predator's Edge"},
        lethalAttacks = {id = 19426, max = 5, inSheet = 'crit', name = 'Lethal Attacks'},
        surefooted = {id = 19290, max = 3, inSheet = 'hit', name = 'Surefooted'},
    },
    -- Talents shown on the Model page, in tree order.
    talentOrder = {'focusedFire', 'unleashedFury', 'ferocity', 'loneWolf', 'mortalShots', 'barrage', 'rangedSpecialization',
        'improvedArcaneShot', 'improvedStings', 'carefulAim', 'lightningReflexes', 'predatorsEdge'},
    -- Rank-1 IDs; the model asks the client for the highest known rank by name.
    abilities = {
        arcane = {id = 3044, name = 'Arcane Shot', cooldown = 6, rap = 0.204, pattern = '(%d+) Arcane damage'},
        aimed = {id = 19434, name = 'Aimed Shot', cooldown = 6, cast = 2, pattern = 'ranged damage by (%d+)'},
        multi = {id = 2643, name = 'Multi-Shot', cooldown = 6, cast = 0.5, pattern = 'additional (%d+)'},
        serpent = {id = 1978, name = 'Serpent Sting', duration = 15, pattern = '(%d+) Nature damage over (%d+) sec'},
        raptor = {id = 2973, name = 'Raptor Strike', cooldown = 6, pattern = 'weapon damage plus (%d+)'},
    },
    pet = {rapToAP = 0.22, rapToSpellDamage = 0.1287, stamina = 0.30, resistance = 0.40, baseCrit = 5, baseMiss = 5},
    -- Camelot PaperDollFrameStats: 5 skill ranks per level; 0.04 % miss per point of skill short, up to
    -- 10 points; the 5.0 / 5.2 / 5.4 / 9.0 % table for mobs 0-3 levels above you continues at
    -- 7 % + 0.4 % per point beyond 10. Mobs dodge 5 %.
    combat = {apPerDPS = 14, skillPerLevel = 5, baseMiss = 5, missPerSkill = 0.04, missPerSkillOver10 = 0.4,
        dodge = 5, critMultiplier = 2, dualWieldMiss = 19, offHand = 0.5},
    -- Weapon subclass -> weapon skill line (Camelot PaperDollFrameStats WEAPON_SUBCLASS_TO_SKILL_ID).
    skills = {[0] = 44, [1] = 172, [2] = 45, [3] = 46, [4] = 54, [5] = 160, [6] = 229, [7] = 43, [8] = 55,
        [10] = 136, [13] = 162, [15] = 173, [16] = 176, [18] = 226, [19] = 228},
    ammoFor = {[2] = 2, [18] = 2, [3] = 3}, -- bows and crossbows take arrows (2); guns take bullets (3)
    -- Stat indexes for the client's stat-conversion functions (LE_UNIT_STAT_*).
    stat = {strength = 1, agility = 2, stamina = 3, intellect = 4},
}
