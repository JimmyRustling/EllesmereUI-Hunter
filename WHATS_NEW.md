# What's new: Forever Companion 1.9.5 + FHK Gear 0.5.3

**Forever Companion is no longer hunter-only.** Every class now has its own page and features. Everything starts **off**: turn on what you want. Install: [QUICKSTART.md](QUICKSTART.md). Every option, page by page: [OPTIONS.md](OPTIONS.md).

## For every class

- **Your class page.** The first Forever Companion page is named after your class and gathers its features. Options follow the character you log in with: a mage never sees hunter or pet settings.
- **Class Buffs** (Unit Frames): a click-to-cast bar for your auras, seals and blessings (paladin), Inner Fire / Fortitude / Shadowform (priest), armors and Intellect (mage), Demon Armor (warlock), shields with charges (shaman), Mark / Thorns / Omen (druid, caster form) and Battle Shout (warrior).
  - Every rank is matched by name; the current buff is highlighted.
  - Missing and expiring warnings stay quiet while dead, mounted, on a flight path or resting.
  - In dungeons, Ellesmere's own raid-buff reminder speaks for Fortitude, Intellect, Mark and Battle Shout.
- **Weapon Enchants** (Unit Frames): a timer pod per weapon for poisons, shaman imbues, sharpening stones and oils, with charges and bag count. Click to re-apply out of combat.
- **Class Supplies** (Warnings): counts for shards, healthstones, soulstones, Ankh, powders, conjured water, food and gems, runes, symbols, candles and seeds.
  - Click to create stones and conjures.
  - A Soulstone timer.
  - Reagents you buy are mentioned only at a vendor that sells them ("Buy Flash Powder here").
- **New Spell alerts** (Warnings): "New: Instant Poison III" or "3 new spells at your trainer" after a level-up. Built from WoW Forever's own game data, with an ignore list. At a trainer, it tells you how many you can afford.
- **Vendor Restock** (Warnings): buys **food**, **drink** (mana users), **class reagents**, **ammo** and **pet food** up to the amounts you set.
  - **Before a better tier:** it buys a small amount just before better food or ammo unlocks.
  - **Mages:** it never buys water or food for a mage who can conjure, unless you choose.
  - **Budget:** it reserves your repair bill first, spends at most 25 % of your gold per visit, keeps 2 bag slots free, and never buys anything Ellesmere marks as junk.
  - **Skip a visit:** hold Shift when opening a vendor.
- **Auto Train** at your class trainer (upgrades first; weapon masters and new professions left to you) and a **Talent Planner** (`/fhktalentplan`): plan your talents by level and learn them in order.

## By class

- **Rogue and druid:**
  - a two-colour **Behind indicator** (behind or in front of your target);
  - an **energy tick** spark;
  - Stealth / Prowl First, Must Be Behind and Leave Form cues;
  - opener suggestions;
  - a Riposte glow;
  - Slice and Dice reminders.
- **Warrior:**
  - stance cues ("Battle Stance");
  - Overpower, Revenge, Execute and Victory Rush glows;
  - a stance hint that never tells a grouped tank to leave Defensive Stance.
- **Warlock:**
  - the demon summon bar;
  - Missing Demon ("Summon Demon"), quiet after Demonic Sacrifice;
  - Pet On Passive;
  - a Health Funnel reminder;
  - pet auras and target;
  - shard and stone supplies.
- **Hunter:**
  - **Pet On Passive** and a **Not Shooting** cue;
  - Missing / Dead Pet out of combat, with "I play without a pet" and Lone Wolf aware;
  - a pet level notice;
  - Auto-Buy Ammo with a quiver mode;
  - a Recommended set you can **Undo** exactly.

## Warnings

- Each warning can have its own **lane** (top, or above your character in combat) and **sound**.
- One sound per warning, never two.
- Previews for every lane.
- Warnings use Ellesmere's own font and shadow.

## FHK Gear 0.5.3

- **Non-gear loot is your roll by default.** You can choose Greed or Need up to a rarity. Mounts, pets, recipes, quest items, keys and anything you can't use are always your roll.
- **Bind on Equip Up To:** bind-on-equip upgrades equip only up to the rarity you choose. Rarity choices show in their quality colours.
- **Shift** as a quest reward window opens lets you pick the reward yourself.
- **Roll etiquette:** Minimum Need Gain; Need only on your armour type or main stat.
- **Per character:** automation and confirmations stay with each character, so an imported profile never turns them on.
- **Other additions:** colour-blind markers, the spec shown on the status line, and "upgrade at level N" in tooltips.

## Plays nicely with EllesmereUI

- **Tested Ellesmere versions:** 9.3.5, 9.3.8 and the current 9.3.9 main. The addons work with **only EllesmereUI installed**.
- **Ellesmere's choices win:** your choices in Ellesmere (gradients, Dynamic Health Color, threat colours, Smooth Bars, nameplate opacity, combat indicator) stay as you set them, unless you turn a companion option on.
- **Ellesmere features:** the companion works alongside Ellesmere's auto repair, junk selling and Quest Tracker auto turn-in.
- **Lighter nameplates:** nameplate work in big pulls was cut roughly in half.

## Status

This is a **test build**:
- it passes thousands of automated checks on all nine classes;
- it has been through scenario, adversarial and EllesmereUI-integration reviews;
- it has had little in-game play so far.

Please report anything odd (see [QUICKSTART.md](QUICKSTART.md) section 5). Full technical history: `FHKEllesmere/CHANGELOG.md`.
