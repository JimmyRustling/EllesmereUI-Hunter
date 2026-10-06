# Forever Companion + FHK Gear for EllesmereUI (WoW Forever)

Plugins for [EllesmereUI](https://github.com/EllesmereGaming/EllesmereUI) on WoW Forever (interface 16001). They load **alongside** an existing EllesmereUI install and never edit Ellesmere's files. Their options appear inside Ellesmere's own pages.

**Download:** [`download/ForeverCompanion-1.9.5_FHKGear-0.5.3.zip`](download/ForeverCompanion-1.9.5_FHKGear-0.5.3.zip). **Install:** see [QUICKSTART.md](QUICKSTART.md), about 2 minutes.

| Folder | What it does |
|---|---|
| `FHKEllesmere` | **Forever Companion**: a page for your class, plus the features below. |
| `FHKGear` | **FHK Gear**: an AutoGear replacement with upgrade scores, Hunter scoring from live stats, quest rewards, auto-equip, loot rolls and pop-ups, on Ellesmere's Gear tab. |

**Forever Companion features:**
- **For every class:**
  - Class Buffs (click-to-cast auras, armors, blessings and shields, with missing / expiring warnings);
  - Weapon Enchants (poison, imbue, stone and oil timers);
  - Class Supplies (shards, stones, conjures, reagents);
  - New Spell alerts from Forever's own game data;
  - Vendor Restock (food, drink, reagents, ammo, pet food);
  - Auto Train and a Talent Planner.
- **Rogue and druid:** Behind indicator, energy tick and class cues.
- **Warrior:** stance cues and reactive glows.
- **Hunter and warlock:** pet and demon tools.
- **Hunter:** range and dead-zone cues, swing timer refinements, the aspect bar, hunter warnings and cues.
- **Everywhere:** leveling helpers, XP bar refinements, theme presets.

## Install

1. Install EllesmereUI (9.3.5 or newer) as usual, from Wago or CurseForge.
2. Copy `FHKEllesmere` and `FHKGear` into `World of Warcraft/_classic_beta_/Interface/AddOns/`.
3. **Fully restart WoW.** New addon files are not picked up by `/reload`.
4. Open EllesmereUI's options. **Forever Companion** (its first page is named after your class) and **Gear** are in the sidebar.

Everything starts **off**: turn on what you want. Nothing here changes your keybinds, macros or game settings by itself, and it defers to the options you chose in Ellesmere.

## Status

- **Version:** 1.9.5 / FHK Gear 0.5.3, a **test build**.
- **Automated tests:** passes against EllesmereUI 9.3.5, 9.3.8 and the current 9.3.9 main. These are mocked integration suites, a standalone load test as all nine classes with no other addons, and scenario, adversarial and suite-integration reviews. In-game verification is in progress; see `FHKEllesmere/CHANGELOG.md` and `FHKEllesmere/CLASS_KITS_PROBES.md`.
- **Ellesmere updates:** the companion hooks some Ellesmere internals, so an Ellesmere update can break a feature until it is fixed here.
- **Reporting problems:** see [QUICKSTART.md](QUICKSTART.md) section 5. The full feature list is in [FEATURES.md](FEATURES.md) and the tester guide in [TESTERS.md](TESTERS.md).

## Branches

- `hunter-addons`: these plugins.
- `forever-core-main`, `forever-core-935-release`: an optional patch to Ellesmere's own files. These are kept as branches so pieces can be offered upstream. **Not needed** for the plugins.
- `main`: upstream EllesmereUI, unchanged.

## Licences

- `FHKGear` adapts AutoGear and is shared under **CC BY-NC-SA 4.0** (see `FHKGear/LICENSE.md`).
- EllesmereUI is its author's work; nothing from it is redistributed in the plugin folders.
