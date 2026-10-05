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
4. Open EllesmereUI's options. On EllesmereUI 9.3.5 and later, the companion has its own **Forever Companion** entry in the sidebar (pages: General, Action Bars, Unit Frames, Nameplates, Resource Bars, Warnings), and Gear has its **Gear** tab. Settings use Ellesmere's own controls: cogs, move arrows, preview eyes and color swatches.

Most new features are off by default; turn on what you want. Nothing here changes your keybinds, macros or game settings by itself: those presets belong to the author's private setup and are not part of this release.

## Status

- Tested against EllesmereUI **9.3.5** and **9.3.8** with mocked integration suites and a standalone load test (no other addons installed) (E2). In-game verification (E3) is in progress; see `FHKEllesmere/CHANGELOG.md` and `FHKEllesmere/IN_GAME_CHECKS.md`.
- The companion hooks some Ellesmere internals. An Ellesmere update can break a feature until it is fixed here.

## Branches

- `hunter-addons`: these plugins.
- `forever-core-main`, `forever-core-935-release`: an optional patch to Ellesmere's own files (core fixes and the WoW Forever pet and aspect reminders), on upstream main and on the 9.3.5 release. It is kept as branches here so pieces can be offered upstream.
- `main`: upstream EllesmereUI, unchanged.

## Licences

- `FHKGear` adapts AutoGear and is shared under **CC BY-NC-SA 4.0** (see `FHKGear/LICENSE.md`).
- EllesmereUI is its author's work; nothing from it is redistributed in the plugin folders.
