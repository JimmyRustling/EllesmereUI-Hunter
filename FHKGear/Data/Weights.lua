-- Default stat weights by class and spec, adapted from AutoGear (classic-era table,
-- AutoGear.lua as installed 2026-09-26) by Synthetikaryote and BujuArena, licensed
-- CC BY-NC-SA 4.0 (https://creativecommons.org/licenses/by-nc-sa/4.0/).
-- Change: only the nine classes WoW Forever has. FHK Gear adjustments for Forever
-- live in Weights.lua, not here. This file is CC BY-NC-SA 4.0.
if EUI_CLIENT_BLOCKED then return end
local _, ns = ...
local E = 0.000001 -- "almost no value": still beats an empty slot
ns.DefaultWeights = {
	["DRUID"] = {
		["None"] = {
			Strength = E, Agility = E, Stamina = 0.05, Intellect = 0.26, Spirit = 0.5,
			Armor = 0.001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = 0.5, SpellPenetration = E, Haste = 0.5, Mp5 = 0.05,
			AttackPower = E, ArmorPenetration = E, Crit = 0.9, SpellCrit = 0.9, Hit = 0.9, SpellHit = 0.9,
			Expertise = E, Versatility = 0.8, Multistrike = 1, Mastery = 1.45, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = 0.33, DamageProc = 0.33, DamageSpellProc = 0.33, MeleeProc = 0.33, RangedProc = E,
			DPS = 1
		},
		["Balance"] = {
			Strength = E, Agility = E, Stamina = 0.05, Intellect = 0.26, Spirit = 0.1,
			Armor = 0.001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = 0.8, SpellPenetration = 0.1, Haste = 0.8, Mp5 = 0.01,
			AttackPower = E, ArmorPenetration = E, Crit = 0.1, SpellCrit = 1, Hit = 0.1, SpellHit = 1,
			Expertise = E, Versatility = 0.8, Multistrike = 1, Mastery = 0.6, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = 0.05, DamageProc = 0.33, DamageSpellProc = 0.33, MeleeProc = E, RangedProc = E,
			DPS = 0.01
		},
		["Feral"] = {
			Strength = 0.3, Agility = 1.05, Stamina = 1, Intellect = 0.1, Spirit = 0.2,
			Armor = 0.08, Dodge = 0.4, Parry = E, Block = E, Defense = 0.05,
			SpellPower = E, SpellPenetration = E, Haste = 0.8, Mp5 = E,
			AttackPower = 1, ArmorPenetration = E, Crit = 1.1, SpellCrit = E, Hit = 0.3, SpellHit = E,
			Expertise = 0.4, Versatility = 0.8, Multistrike = 1, Mastery = 1, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = 0.05, DamageProc = 0.33, DamageSpellProc = E, MeleeProc = 0.33, RangedProc = E,
			DPS = 0.8
		},
		["Feral Combat"] = { -- Classic spec name
			Strength = 0.3, Agility = 1.05, Stamina = 1, Intellect = 0.1, Spirit = 0.2,
			Armor = 0.08, Dodge = 0.4, Parry = E, Block = E, Defense = 0.05,
			SpellPower = E, SpellPenetration = E, Haste = 0.8, Mp5 = E,
			AttackPower = 1, ArmorPenetration = E, Crit = 1.1, SpellCrit = E, Hit = 0.3, SpellHit = E,
			Expertise = 0.4, Versatility = 0.8, Multistrike = 1, Mastery = 1, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = 0.05, DamageProc = 0.33, DamageSpellProc = E, MeleeProc = 0.33, RangedProc = E,
			DPS = 0.8
		},
		["Guardian"] = {
			Strength = E, Agility = 1.05, Stamina = 1, Intellect = E, Spirit = E,
			Armor = 0.08, Dodge = 0.4, Parry = E, Block = E, Defense = 1.33,
			SpellPower = E, SpellPenetration = E, Haste = 0.8, Mp5 = E,
			AttackPower = 1, ArmorPenetration = E, Crit = 1.1, SpellCrit = E, Hit = 0.3, SpellHit = E,
			Expertise = 0.4, Versatility = 0.8, Multistrike = 1, Mastery = 1, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = 0.05, DamageProc = 0.33, DamageSpellProc = E, MeleeProc = 0.33, RangedProc = E,
			DPS = 0.8
		},
		["Restoration"] = {
			Strength = E, Agility = E, Stamina = 0.05, Intellect = 0.6, Spirit = 1.0,
			Armor = 0.001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = 0.85, SpellPenetration = E, Haste = 0.8, Mp5 = 3,
			AttackPower = E, ArmorPenetration = E, Crit = E, SpellCrit = 0.5, Hit = E, SpellHit = E,
			Expertise = E, Versatility = 0.8, Multistrike = 1, Mastery = 0.65, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = 0.33, DamageProc = E, DamageSpellProc = E, MeleeProc = E, RangedProc = E,
			DPS = 0.01
		}
	},
	["HUNTER"] = {
		["None"] = {
			Strength = 0.3, Agility = 1.05, Stamina = 0.15, Intellect = E, Spirit = 0.2,
			Armor = 0.0001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = E, SpellPenetration = E, Haste = 0.8, Mp5 = E,
			AttackPower = 1, ArmorPenetration = 0.8, Crit = 0.8, SpellCrit = E, Hit = 0.4, SpellHit = E,
			Expertise = 0.1, Versatility = 0.8, Multistrike = 1, Mastery = E, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = E, DamageProc = 0.33, DamageSpellProc = E, MeleeProc = 0.1, RangedProc = 0.33,
			DPS = 2
		},
		["Beast Mastery"] = {
			Strength = 0.3, Agility = 1.05, Stamina = 0.15, Intellect = E, Spirit = 0.2,
			Armor = 0.0001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = E, SpellPenetration = E, Haste = 0.9, Mp5 = E,
			AttackPower = 1, ArmorPenetration = 0.8, Crit = 2, SpellCrit = E, Hit = 1.4, SpellHit = E,
			Expertise = 0.1, Versatility = 0.8, Multistrike = 1, Mastery = 1.5, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = E, DamageProc = 0.33, DamageSpellProc = E, MeleeProc = E, RangedProc = 0.33,
			DPS = 2
		},
		["Marksmanship"] = {
			Strength = 0.3, Agility = 1.05, Stamina = 0.15, Intellect = E, Spirit = 0.2,
			Armor = 0.0001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = E, SpellPenetration = E, Haste = 1.61, Mp5 = E,
			AttackPower = 1, ArmorPenetration = E, Crit = 1.66, SpellCrit = E, Hit = 3.49, SpellHit = E,
			Expertise = E, Versatility = 0.8, Multistrike = 1, Mastery = 1.38, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = E, DamageProc = 0.33, DamageSpellProc = E, MeleeProc = E, RangedProc = 0.33,
			DPS = 2
		},
		["Survival"] = {
			Strength = 0.3, Agility = 1.05, Stamina = 0.15, Intellect = E, Spirit = 0.2,
			Armor = 0.0001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = E, SpellPenetration = E, Haste = 1.33, Mp5 = E,
			AttackPower = 1, ArmorPenetration = E, Crit = 1.37, SpellCrit = E, Hit = 3.19, SpellHit = E,
			Expertise = E, Versatility = 0.8, Multistrike = 1, Mastery = 1.27, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = E, DamageProc = 0.33, DamageSpellProc = 0.1, MeleeProc = 0.25, RangedProc = 0.1,
			DPS = 2
		}
	},
	["MAGE"] = {
		["None"] = {
			Strength = E, Agility = E, Stamina = 0.05, Intellect = 0.40, Spirit = 0.9,
			Armor = 0.001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = 2.8, SpellPenetration = 0.005, Haste = 1.28, Mp5 = .005,
			AttackPower = E, ArmorPenetration = E, Crit = E, SpellCrit = 1.3, Hit = E, SpellHit = 1.25,
			Expertise = E, Versatility = 0.8, Multistrike = 1, Mastery = 1.4, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = E, DamageProc = 0.33, DamageSpellProc = 0.33, MeleeProc = E, RangedProc = E,
			DPS = 0.01
		},
		["Arcane"] = {
			Strength = E, Agility = E, Stamina = 0.01, Intellect = 0.40, Spirit = 0.9,
			Armor = 0.0001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = 1.1, SpellPenetration = 0.2, Haste = 0.5, Mp5 = E,
			AttackPower = E, ArmorPenetration = E, Crit = E, SpellCrit = 1.3, Hit = E, SpellHit = 1.25,
			Expertise = E, Versatility = 0.8, Multistrike = 1, Mastery = 0.9, ExperienceGained = 100,
			RedSockets = 10, YellowSockets = 8, BlueSockets = 7, MetaSockets = 20,
			HealingProc = E, DamageProc = 0.33, DamageSpellProc = 0.33, MeleeProc = E, RangedProc = E,
			DPS = 0.01
		},
		["Fire"] = {
			Strength = E, Agility = E, Stamina = 0.05, Intellect = 1, Spirit = 0.9,
			Armor = 0.0001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = 1.1, SpellPenetration = E, Haste = 0.8, Mp5 = E,
			AttackPower = E, ArmorPenetration = E, Crit = E, SpellCrit = 2.4, Hit = E, SpellHit = 1.75,
			Expertise = E, Versatility = 0.8, Multistrike = 1, Mastery = 0.9, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = E, DamageProc = 0.33, DamageSpellProc = 0.33, MeleeProc = E, RangedProc = E,
			DPS = 0.01
		},
		["Frost"] = {
			Strength = E, Agility = E, Stamina = 0.05, Intellect = 0.40, Spirit = 0.8,
			Armor = 0.0001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = 1, SpellPenetration = 0.3, Haste = 0.8, Mp5 = E,
			AttackPower = E, ArmorPenetration = E, Crit = E, SpellCrit = 1.3, Hit = E, SpellHit = 1.25,
			Expertise = E, Versatility = 0.8, Multistrike = 1, Mastery = 0.9, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = E, DamageProc = 0.33, DamageSpellProc = 0.33, MeleeProc = E, RangedProc = E,
			DPS = 0.01
		}
	},
	["PALADIN"] = {
		["None"] = {
			Strength = 2.33, Agility = E, Stamina = 0.05, Intellect = E, Spirit = 1,
			Armor = 0.001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = E, SpellPenetration = E, Haste = 0.79, Mp5 = E,
			AttackPower = 1, ArmorPenetration = E, Crit = 0.98, SpellCrit = 0.98, Hit = 1.77, SpellHit = 0.77,
			Expertise = 1.3, Versatility = 0.8, Multistrike = 1, Mastery = 1.13, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = 0.33, DamageProc = 0.33, DamageSpellProc = 0.33, MeleeProc = 0.33, RangedProc = E,
			DPS = 1.33333, Damage = 0.66667
		},
		["Holy"] = {
			Strength = E, Agility = E, Stamina = 0.05, Intellect = 0.26, Spirit = 1,
			Armor = 0.001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = 0.7, SpellPenetration = E, Haste = 0.8, Mp5 = E,
			AttackPower = E, ArmorPenetration = E, Crit = E, SpellCrit = 0.1, Hit = E, SpellHit = 0.1,
			Expertise = E, Versatility = 0.8, Multistrike = 1, Mastery = 0.3, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = 0.33, DamageProc = 0.1, DamageSpellProc = 0.1, MeleeProc = 0.05, RangedProc = E,
			DPS = 0.01
		},
		["Protection"] = {
			weapons = "weapon and shield",
			Strength = 1, Agility = 0.3, Stamina = 0.65, Intellect = 0.1, Spirit = 0.3,
			Armor = 0.05, Dodge = 0.8, Parry = 0.75, Block = 0.8, Defense = 3,
			SpellPower = 0.05, SpellPenetration = E, Haste = 0.5, Mp5 = E,
			AttackPower = 0.4, ArmorPenetration = 0.1, Crit = 0.25, SpellCrit = E, Hit = E,
			Expertise = 0.2, Versatility = 0.8, Multistrike = 1, Mastery = 0.05, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = 0.05, DamageProc = 0.33, DamageSpellProc = 0.25, SpellProc = 0.25, MeleeProc = 0.1, RangedProc = E,
			DPS = 1.33333, Damage = 0.66667
		},
		["Retribution"] = {
			weapons = "2h",
			Strength = 2.33, Agility = E, Stamina = 0.05, Intellect = 0.1, Spirit = 0.3,
			Armor = 0.001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = E, SpellPenetration = E, Haste = 0.79, Mp5 = E,
			AttackPower = 1, ArmorPenetration = E, Crit = 0.98, SpellCrit = 0.1, Hit = 1.77, SpellHit = 0.1,
			Expertise = 1.3, Versatility = 0.8, Multistrike = 1, Mastery = 1.13, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = 0.05, DamageProc = 0.33, DamageSpellProc = E, MeleeProc = 0.25, RangedProc = E,
			DPS = 1, Damage = 1
		}
	},
	["PRIEST"] = {
		["None"] = {
			Strength = E, Agility = E, Stamina = 0.05, Intellect = 0.26, Spirit = 1,
			Armor = 0.001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = 2.75, SpellPenetration = E, Haste = 2, Mp5 = 4,
			AttackPower = E, ArmorPenetration = E, Crit = E, SpellCrit = 1.6, Hit = E, SpellHit = 1.95,
			Expertise = E, Versatility = 0.8, Multistrike = 1, Mastery = 1.7, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = 0.33, DamageProc = 0.33, DamageSpellProc = 0.33, MeleeProc = E, RangedProc = E,
			DPS = 0.01
		},
		["Discipline"] = {
			Strength = E, Agility = E, Stamina = E, Intellect = 0.26, Spirit = 1,
			Armor = 0.0001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = 0.8, SpellPenetration = E, Haste = 1, Mp5 = 4,
			AttackPower = E, ArmorPenetration = E, Crit = E, SpellCrit = 0.25, Hit = E, SpellHit = E,
			Expertise = E, Versatility = 0.8, Multistrike = 1, Mastery = 0.5, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = 0.33, DamageProc = 0.1, DamageSpellProc = 0.1, MeleeProc = E, RangedProc = E,
			DPS = 0.01
		},
		["Holy"] = {
			Strength = E, Agility = E, Stamina = 0.05, Intellect = 0.26, Spirit = 1.8,
			Armor = 0.001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = 0.7, SpellPenetration = E, Haste = 0.47, Mp5 = 4,
			AttackPower = E, ArmorPenetration = E, Crit = E, SpellCrit = 0.47, Hit = E, SpellHit = E,
			Expertise = E, Versatility = 0.8, Multistrike = 1, Mastery = 0.36, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = 0.33, DamageProc = 0.1, DamageSpellProc = 0.1, MeleeProc = E, RangedProc = E,
			DPS = 0.01
		},
		["Shadow"] = {
			Strength = E, Agility = E, Stamina = 0.05, Intellect = 0.26, Spirit = 1,
			Armor = 0.001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = 1, SpellPenetration = E, Haste = 1, Mp5 = 3,
			AttackPower = E, ArmorPenetration = E, Crit = E, SpellCrit = 1, Hit = E, SpellHit = 1,
			Expertise = E, Versatility = 0.8, Multistrike = 1, Mastery = 1, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = 0.1, DamageProc = 0.33, DamageSpellProc = 0.33, MeleeProc = E, RangedProc = E,
			DPS = 0.01
		}
	},
	["ROGUE"] = {
		["None"] = {
			weapons = "dagger and any",
			Strength = E, Agility = 1.1, Stamina = 0.05, Intellect = E, Spirit = E,
			Armor = 0.001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = E, SpellPenetration = E, Haste = 1.05, Mp5 = E,
			AttackPower = 1, ArmorPenetration = E, Crit = 1.1, SpellCrit = E, Hit = 1.75, SpellHit = E,
			Expertise = 1.85, Versatility = 0.8, Multistrike = 1, Mastery = 1.5, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = E, DamageProc = 0.33, DamageSpellProc = E, MeleeProc = 0.33, RangedProc = E,
			DPS = 3.075
		},
		["Assassination"] = {
			weapons = "dagger and any",
			Strength = E, Agility = 1.1, Stamina = 0.05, Intellect = E, Spirit = E,
			Armor = 0.001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = E, SpellPenetration = E, Haste = 1.05, Mp5 = E,
			AttackPower = 1, ArmorPenetration = E, Crit = 1.1, SpellCrit = E, Hit = 1.75, SpellHit = E,
			Expertise = 1.1, Versatility = 0.8, Multistrike = 1, Mastery = 1.3, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = E, DamageProc = 0.33, DamageSpellProc = E, MeleeProc = 0.33, RangedProc = E,
			DPS = 2
		},
		["Outlaw"] = {
			weapons = "dual wield",
			Strength = E, Agility = 1.1, Stamina = 0.05, Intellect = E, Spirit = E,
			Armor = 0.001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = E, SpellPenetration = E, Haste = 1.05, Mp5 = E,
			AttackPower = 1, ArmorPenetration = E, Crit = 1.1, SpellCrit = E, Hit = 1.75, SpellHit = E,
			Expertise = 1.85, Versatility = 0.8, Multistrike = 1, Mastery = 1.5, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = E, DamageProc = 0.33, DamageSpellProc = E, MeleeProc = 0.33, RangedProc = E,
			DPS = 3.075
		},
		["Combat"] = {
			weapons = "dual wield",
			Strength = E, Agility = 1.1, Stamina = 0.05, Intellect = E, Spirit = E,
			Armor = 0.001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = E, SpellPenetration = E, Haste = 1.05, Mp5 = E,
			AttackPower = 1, ArmorPenetration = E, Crit = 1.1, SpellCrit = E, Hit = 1.75, SpellHit = E,
			Expertise = 1.85, Versatility = 0.8, Multistrike = 1, Mastery = 1.5, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = E, DamageProc = 0.33, DamageSpellProc = E, MeleeProc = 0.33, RangedProc = E,
			DPS = 3.075
		},
		["Subtlety"] = {
			weapons = "dagger and any",
			Strength = 0.3, Agility = 1.1, Stamina = 0.2, Intellect = E, Spirit = E,
			Armor = 0.001, Dodge = 0.1, Parry = 0.1, Block = E, Defense = E,
			SpellPower = E, SpellPenetration = E, Haste = 0.5, Mp5 = E,
			AttackPower = 0.4, ArmorPenetration = E, Crit = 1.1, SpellCrit = E, Hit = 0.6, SpellHit = E,
			Expertise = E, Versatility = 0.8, Multistrike = 1, Mastery = 0.9, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = E, DamageProc = 0.33, DamageSpellProc = E, MeleeProc = 0.33, RangedProc = E,
			DPS = 2
		}
	},
	["SHAMAN"] = {
		["None"] = {
			Strength = E, Agility = 1, Stamina = 0.05, Intellect = 0.26, Spirit = 1,
			Armor = 0.001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = 1, SpellPenetration = 1, Haste = 1, Mp5 = E,
			AttackPower = 1, ArmorPenetration = 1, Crit = 1.11, SpellCrit = 1.11, Hit = 2.7, SpellHit = 2.7,
			Expertise = E, Versatility = 0.8, Multistrike = 1, Mastery = 1.62, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = E, DamageProc = 0.33, DamageSpellProc = 0.33, MeleeProc = 0.33, RangedProc = E,
			DPS = 1.2, Damage = 0.8
		},
		["Elemental"] = {
			Strength = E, Agility = E, Stamina = 0.05, Intellect = 0.26, Spirit = 1,
			Armor = 0.001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = 0.6, SpellPenetration = 0.1, Haste = 0.9, Mp5 = E,
			AttackPower = E, ArmorPenetration = E, Crit = 0.9, SpellCrit = 0.9, Hit = E, SpellHit = E,
			Expertise = E, Versatility = 0.8, Multistrike = 1, Mastery = 1, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = E, DamageProc = 0.33, DamageSpellProc = 0.33, MeleeProc = E, RangedProc = E,
			DPS = 0.13333, Damage = 0.06667
		},
		["Enhancement"] = {
			weapons = "dual wield",
			Strength = E, Agility = 1.05, Stamina = 0.1, Intellect = E, Spirit = 1,
			Armor = 0.001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = E, SpellPenetration = E, Haste = 0.95, Mp5 = E,
			AttackPower = 1, ArmorPenetration = 0.4, Crit = 1, SpellCrit = 1, Hit = 0.8, SpellHit = 0.8,
			Expertise = 0.3, Versatility = 0.8, Multistrike = 0.95, Mastery = 1, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = E, DamageProc = 0.33, DamageSpellProc = E, MeleeProc = 0.33, RangedProc = E,
			DPS = 1.2, Damage = 0.8
		},
		["Restoration"] = {
			Strength = E, Agility = E, Stamina = 0.05, Intellect = 0.26, Spirit = 1,
			Armor = 0.001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = 0.75, SpellPenetration = E, Haste = 0.6, Mp5 = E,
			AttackPower = E, ArmorPenetration = E, Crit = 0.4, SpellCrit = 0.4, Hit = E, SpellHit = E,
			Expertise = E, Versatility = 0.8, Multistrike = 1, Mastery = 0.55, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = 0.33, DamageProc = E, DamageSpellProc = E, MeleeProc = E, RangedProc = E,
			DPS = 0.01
		}
	},
	["WARLOCK"] = {
		["None"] = {
			Strength = E, Agility = E, Stamina = 0.4, Intellect = 0.2, Spirit = 0.7,
			Armor = 0.001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = 1, SpellPenetration = 0.05, Haste = 2.32, Mp5 = E,
			AttackPower = E, ArmorPenetration = E, Crit = E, SpellCrit = 4, Hit = E, SpellHit = 7,
			Expertise = E, Versatility = 0.8, Multistrike = 1, Mastery = 1.24, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = E, DamageProc = 0.33, DamageSpellProc = 0.33, MeleeProc = E, RangedProc = E,
			DPS = 0.01
		},
		["Affliction"] = {
			Strength = E, Agility = E, Stamina = 0.4, Intellect = 0.2, Spirit = 0.7,
			Armor = 0.001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = 1, SpellPenetration = 0.05, Haste = 2.32, Mp5 = 1.5,
			AttackPower = E, ArmorPenetration = E, Crit = E, SpellCrit = 4, Hit = E, SpellHit = 7,
			Expertise = E, Versatility = 0.8, Multistrike = 1, Mastery = 1.24, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = E, DamageProc = 0.33, DamageSpellProc = 0.33, MeleeProc = E, RangedProc = E,
			DPS = 0.01
		},
		["Demonology"] = {
			Strength = E, Agility = E, Stamina = 0.4, Intellect = 0.2, Spirit = 0.7,
			Armor = 0.001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = 1, SpellPenetration = 0.05, Haste = 2.37, Mp5 = 1.5,
			AttackPower = E, ArmorPenetration = E, Crit = E, SpellCrit = 4, Hit = E, SpellHit = 7,
			Expertise = E, Versatility = 0.8, Multistrike = 1, Mastery = 2.57, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = E, DamageProc = 0.33, DamageSpellProc = 0.33, MeleeProc = E, RangedProc = E,
			DPS = 0.01
		},
		["Destruction"] = {
			Strength = E, Agility = E, Stamina = 0.4, Intellect = 0.2, Spirit = 0.7,
			Armor = 0.001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = 1, SpellPenetration = 0.05, Haste = 2.08, Mp5 = 1.5,
			AttackPower = E, ArmorPenetration = E, Crit = E, SpellCrit = 6, Hit = E, SpellHit = 7,
			Expertise = E, Versatility = 0.8, Multistrike = 1, Mastery = 1.4, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = E, DamageProc = 0.33, DamageSpellProc = 0.33, MeleeProc = E, RangedProc = E,
			DPS = 0.01
		}
	},
	["WARRIOR"] = {
		["None"] = {
			Strength = 2.02, Agility = 0.5, Stamina = 0.05, Intellect = E, Spirit = E,
			Armor = 0.001, Dodge = E, Parry = E, Block = 0.5, Defense = 4,
			SpellPower = E, SpellPenetration = E, Haste = 0.8, Mp5 = E,
			AttackPower = 0.88, ArmorPenetration = E, Crit = 1.34, SpellCrit = E, Hit = 2, SpellHit = E,
			Expertise = 1.46, Versatility = 0.8, Multistrike = 1, Mastery = 0.9, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = E, DamageProc = 0.33, DamageSpellProc = E, MeleeProc = 0.33, RangedProc = E,
			DPS = 1.33333, Damage = 0.66667
		},
		["Arms"] = {
			weapons = "2h",
			Strength = 2.02, Agility = 0.5, Stamina = 0.05, Intellect = E, Spirit = E,
			Armor = 0.001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = E, SpellPenetration = E, Haste = 0.8, Mp5 = E,
			AttackPower = 0.88, ArmorPenetration = E, Crit = 1.34, SpellCrit = E, Hit = 2, SpellHit = E,
			Expertise = 1.46, Versatility = 0.8, Multistrike = 1, Mastery = 0.9, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = E, DamageProc = 0.33, DamageSpellProc = E, MeleeProc = 0.33, RangedProc = E,
			DPS = 1, Damage = 1
		},
		["Fury"] = {
			weapons = "dual wield", -- AutoGear: "2hDW" from WotLK; Forever is pre-WotLK
			Strength = 2.98, Agility = 0.5, Stamina = 0.05, Intellect = E, Spirit = E,
			Armor = 0.001, Dodge = E, Parry = E, Block = E, Defense = E,
			SpellPower = E, SpellPenetration = E, Haste = 1.37, Mp5 = E,
			AttackPower = 1.36, ArmorPenetration = E, Crit = 1.98, SpellCrit = E, Hit = 2.47, SpellHit = E,
			Expertise = 2.47, Versatility = 0.8, Multistrike = 1, Mastery = 1.57, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = E, DamageProc = 0.33, DamageSpellProc = E, MeleeProc = 0.33, RangedProc = E,
			DPS = 1.2, Damage = 0.8
		},
		["Protection"] = {
			weapons = "weapon and shield",
			Strength = 1.2, Agility = 0.5, Stamina = 1.5, Intellect = E, Spirit = E,
			Armor = 0.13, Dodge = 1, Parry = 1.03, Block = 0.5, Defense = 4,
			SpellPower = E, SpellPenetration = E, Haste = E, Mp5 = E,
			AttackPower = E, ArmorPenetration = E, Crit = 0.4, SpellCrit = E, Hit = 0.02, SpellHit = E,
			Expertise = 0.04, Versatility = 0.8, Multistrike = 1, Mastery = 1, ExperienceGained = 100,
			RedSockets = E, YellowSockets = E, BlueSockets = E, MetaSockets = E,
			HealingProc = E, DamageProc = 0.33, DamageSpellProc = E, MeleeProc = 0.33, RangedProc = E,
			DPS = 1.33333, Damage = 0.66667
		}
	}
}
