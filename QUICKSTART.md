# Quick start: Forever Companion 1.9.5 + FHK Gear 0.5.3

Two plugins for [EllesmereUI](https://github.com/EllesmereGaming/EllesmereUI) on **WoW Forever**. They add class features, warnings, vendor restock and an AutoGear replacement inside Ellesmere's own options. They never edit Ellesmere's files.

> **Test build.** Everything passes automated tests against EllesmereUI 9.3.5, 9.3.8 and the current 9.3.9 main, but it has had little in-game play. Please report anything odd.

## 1. Install (2 minutes)

1. **Close WoW completely.**
2. **Install EllesmereUI** (version 9.3.5 or newer) from CurseForge or Wago, with its modules as they come.
3. **Copy the two addon folders.** Copy `FHKEllesmere` and `FHKGear` from this download into:
   ```
   World of Warcraft/_classic_beta_/Interface/AddOns/
   ```
   You should end up with `Interface/AddOns/FHKEllesmere/FHKEllesmere.toc`, not a folder inside a folder.
4. **Start WoW.** At character select, open **AddOns** and make sure **FHK - Ellesmere Companion** and **FHK Gear** are ticked.
5. **Turn on error messages.** In game, type `/console scriptErrors 1` once, so any error shows on screen.

New files need a **full restart**. `/reload` is not enough after installing or updating.

## 2. First five minutes

Open EllesmereUI's options. Two new entries are in the sidebar:
- **Forever Companion**: its first page is named after **your class** (Hunter, Mage, Warlock...) and gathers that class's features in one place. Every row has an open icon that jumps to all of its settings. The other pages follow Ellesmere's modules (General, Action Bars, Unit Frames, Nameplates, Resource Bars, Warnings).
- **Gear**: the AutoGear replacement (Automation, Stat Weights, Markers, Equipment Rules, Model).

**Everything starts off.** Turn on what you want to try, for example:

| Class | Try first |
|---|---|
| Every class | **Warnings > Vendor Restock** (food, drink, reagents, ammo), **Warnings > New Spells**, **Warnings > Training** (Auto Train, Talent Planner `/fhktalentplan`) |
| Paladin, Priest, Mage, Warlock, Shaman, Druid, Warrior | **Unit Frames > Class Buffs** (click-to-cast auras, armors, blessings, shields with missing / expiring warnings) |
| Rogue, Shaman (and any class with stones or oils) | **Unit Frames > Weapon Enchants** (poison / imbue timers, click to re-apply) |
| Warlock, Mage, Rogue, Shaman, Paladin, Priest, Druid | **Warnings > Class Supplies** (shards, stones, conjures, reagents) |
| Rogue, Druid | **Resource Bars > Behind Indicator** and **Energy Tick**, **Warnings > Class Cues** |
| Warrior | **Warnings > Class Cues** (stance cues, Overpower / Revenge / Execute glows) |
| Hunter | The **Hunter** page: **Turn On Recommended Hunter Set** (Undo puts everything back) |
| Warlock | **Unit Frames > Pets And Summons** (demon bar) and the pet warnings on your class page |
| Gear | **Automation**: Auto-Equip Upgrades, Auto-Pick Quest Rewards, Auto-Roll on Loot. Non-gear loot is always your roll unless you choose otherwise. |

Most bars and icons can be moved in **Ellesmere's Unlock Mode**. Every section has a **Reset**.

## 3. Good to know

- **Settings** are saved per Ellesmere profile and follow profile switches. What Gear does by itself (auto-equip, auto-roll, Need) stays per character.
- **It leaves your setup alone.** It never changes your keybinds or macros. It changes a game setting only when you flip one of its own switches.
- **It defers to Ellesmere.** Gradients, Dynamic Health Color, threat colors, Smooth Bars and the combat indicator stay as you set them in Ellesmere, unless you turn a companion option on.
- **Vendor Restock spending:**
  - It reserves your repair bill first and spends at most 25 % of your gold per visit (you can change this).
  - It never buys anything Ellesmere marks as junk.
  - Hold **Shift** when opening a vendor to skip a visit.
- **AutoGear:** if you use it, Gear only marks upgrades until you disable AutoGear (the Gear page has a button).

## 4. Updating

Close WoW, replace the two folders, start WoW. Your settings are kept.

## 5. Something wrong?

Please send:
1. what you did and what you expected;
2. a **screenshot**, with the error window if one appeared;
3. your class, level and EllesmereUI version (top left of its options);
4. for slowdowns, the output of `/fhkperf` after a minute of play.

To turn it off, untick either addon at character select. Every companion switch restores Ellesmere's own look when turned off.

More detail: `TESTERS.md` (tester guide), `FEATURES.md` (full feature list), `FHKEllesmere/CHANGELOG.md`.
