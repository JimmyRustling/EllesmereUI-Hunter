# Tester guide: Forever Companion 1.9.5 and FHK Gear 0.5.3 (test build)

Thanks for testing. This is a **test build**: everything passes automated tests, but it has had little in-game play. Please report anything odd.

## What you need

- **EllesmereUI 9.3.5 or newer** (9.3.8 is the latest), from CurseForge or Wago, with its modules as they come.
- Nothing else. These two folders are all there is: no other addon or library is needed.

## Install

1. Close WoW.
2. Unzip, then copy `FHKEllesmere` and `FHKGear` into `World of Warcraft/_classic_beta_/Interface/AddOns/`.
3. Start WoW. At character select, check both are enabled in the AddOns list: **FHK - Ellesmere Companion** and **FHK Gear**.
4. In game, type `/console scriptErrors 1` once, so any Lua error shows on screen.
5. Open EllesmereUI's options. In the sidebar you'll find two entries:
   - **Forever Companion**: its first page is named after your class (Hunter, Mage, Warlock...) and gathers that class's features. The other pages are General, Action Bars, Unit Frames, Nameplates, Resource Bars and Warnings.
   - **Gear**.

   Options follow the character you log in with: a mage never sees hunter or pet settings.

## What it changes, and what it never does

- Most features start **off**: turn on what you want to try.
- Settings are saved per Ellesmere profile.
- It **never** changes your keybinds or macros. It changes a game setting only when you flip one of its own switches (the soft-target and interact icon toggles).
- If you use **AutoGear**, FHK Gear only marks upgrades until you disable AutoGear (the Gear page has a button).
- **It defers to Ellesmere's own choices.** Gradients, Dynamic Health Color, threat colours, Smooth Bars, nameplate opacity, the combat indicator and the pet happiness face stay as you set them in Ellesmere, until you turn a companion option on.
- **It shares work with Ellesmere modules:**
  - In dungeons, Ellesmere's raid-buff reminder speaks for Fortitude, Intellect, Mark and Battle Shout.
  - At a vendor, nothing Ellesmere marks as junk is bought.
  - A one-reward quest is left to Ellesmere's Quest Tracker auto turn-in when that is on.

## What to try

The full list is in `FEATURES.md`. **Start with your class page**: it has every class feature in one place, each with a link to all of its settings. Good places to start:
- **Every class:**
  - Unit Frames > Class Buffs: a click-to-cast bar of your auras, armors, blessings or shields, with missing and expiring warnings. Not for hunters, who have Aspects, or rogues.
  - Unit Frames > Weapon Enchants: poison, imbue, stone or oil timers, click to re-apply.
  - Warnings > Class Supplies: reagent and made-item counts (shards, stones, powders, water, symbols...).
  - Warnings > New Spells: "New: Instant Poison III" when your trainer has something new.
  - Warnings > Vendor Restock: buys food, drink, reagents, ammo and pet food at vendors, up to what you set. It never buys water or food for a mage who conjures.
  - Warnings > Training: Auto Train and the Talent Planner (`/fhktalentplan`).
- **Rogues and druids:** Resource Bars > Behind Indicator (two colors, behind or in front of your target) and Energy Tick; Warnings > Class Cues.
- **Warriors:** Warnings > Class Cues (stance cues, Overpower / Revenge / Execute glows).
- **Hunters:**
  - Resource Bars: Range Indicator and Auto Attack Indicators.
  - Unit Frames: Aspects.
  - Unit Frames: Pet Food. Cast Feed Pet and your bags show only what the pet eats.
  - Warnings: Hunter Warnings and Hunter Cues.
- **Warlocks:** Unit Frames > Pets And Summons (the demon bar), plus the pet warnings on your class page.
- **Any class, also:**
  - Gear: Automation (now with Non-Gear Loot Rolls and Bind on Equip Up To) and Markers.
  - Warnings: Leveling Helpers.
  - Action Bars: XP Bar Refinements and Key Press and Action History.
  - General: Forever Theme Presets.

## Reporting a problem

Please include:
1. what you did and what you expected;
2. a **screenshot** (with the error window, if one appeared);
3. your class, level and EllesmereUI version (top left of its options);
4. for slowdowns, the output of `/fhkperf` after a minute of play.

## Turning it off

Disable either addon at character select. Your EllesmereUI settings are kept, and every companion switch restores the native look when turned off.
