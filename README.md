# EllesmereUI Hunter addons (WoW Forever)

Plugins for [EllesmereUI](https://github.com/EllesmereGaming/EllesmereUI) on WoW Forever (interface 16001). They load **alongside** an existing EllesmereUI install and never edit Ellesmere's files. Their options appear inside Ellesmere's own pages.

| Folder | What it does |
|---|---|
| `FHKEllesmere` | Hunter companion. Range and dead-zone cues, swing timer refinements, aspect bar and advisor, pet frame auras, XP, food row and warnings, Hunter cues, leveling helpers, Hunter colors, Cooldown Manager key labels. |
| `FHKGear` | Gear module, an AutoGear replacement. Upgrade scores, Hunter scoring from live character stats, quest rewards, auto-equip and pop-ups, all on Ellesmere's Gear tab. |

## Install

1. Install EllesmereUI as usual (Wago or CurseForge).
2. Copy `FHKEllesmere` and `FHKGear` into `World of Warcraft/_classic_beta_/Interface/AddOns/`.
3. Fully restart WoW (new addon files are not picked up by `/reload`).
4. Open EllesmereUI's options. The new sections sit on the matching pages: Unit Frames, Quality of Life, Resource Bars > Swing Timer, Cooldown Manager, and Gear.

Most new features are off by default; turn on what you want.

## Status

- Tested with mocked integration suites only (E2). In-game verification (E3) is in progress; see `FHKEllesmere/CHANGELOG.md`.
- The companion hooks some Ellesmere internals. An Ellesmere update can break a feature until it is fixed here.

## Branches

- `hunter-addons`: these plugins.
- `forever-core-main`, `forever-core-935-release`: an optional patch to Ellesmere's own files (core fixes and the WoW Forever pet and aspect reminders), on upstream main and on the 9.3.5 release. It is kept as branches here so pieces can be offered upstream.
- `main`: upstream EllesmereUI, unchanged.

## Licences

- `FHKGear` adapts AutoGear and is shared under **CC BY-NC-SA 4.0** (see `FHKGear/LICENSE.md`).
- EllesmereUI is its author's work; nothing from it is redistributed in the plugin folders.
