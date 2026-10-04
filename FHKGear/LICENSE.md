# Licence

FHK Gear is licensed under **Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International** (CC BY-NC-SA 4.0). The full licence text is in [LICENSE-CC-BY-NC-SA-4.0.md](LICENSE-CC-BY-NC-SA-4.0.md).

## Attribution

FHK Gear is adapted from **AutoGear** by Synthetikaryote and BujuArena (CC BY-NC-SA 4.0; CurseForge project 39179, WoWInterface 26415), including the local WoW Forever patch notes in AutoGear's `FOREVER-PATCH.md`.

Original work: [AutoGear project and source link](https://www.curseforge.com/wow/addons/autogear).

What was adapted and what changed:

- `Data/Weights.lua`: AutoGear's classic-era default stat weights, limited to the nine classes WoW Forever has.
- `Weights.lua`: AutoGear's Pawn/stat=value import idea and key names; new Forever per-1% crit/hit values, split ranged/melee weapon DPS for Hunters, per class/spec/phase custom weights and Pawn export.
- `Engine.lua`: AutoGear's slot rules, weapon styles and quest-reward rules (independent comparison per choice, manual when a non-gear choice exists, highest vendor value when nothing is an upgrade); rewritten as cached pure functions.
- `Items.lua`: structured stats first, tooltip only for usability, binding and missing Equip: lines; cached per item.
- `Core.lua`, `Markers.lua`: rewritten event model (no OnUpdate, events only for enabled features, Levelling Mode), Ellesmere options tab.
- `Effects.lua`, `Equipment.lua`: adapted English effect/slot vocabulary and policy ideas, with new typed parsing, finite scoring and complete setup checks.
- `Safety.lua`, `Actions.lua`, `Context.lua`, `Profiles.lua`, `Options.lua`: original FHK implementation, distributed under the same CC BY-NC-SA 4.0 licence.
- `Data/Procs.lua`: numeric reference rates researched from the MIT-licensed wowsims-derived MythicSim engine. No engine implementation is copied. The pinned source and uncertainty are recorded in that file.

The complete licence file was replaced with the unmodified [official CC legal text](https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode.txt) on 2026-10-04. It is stored as plain text in the Markdown-named file.

Changes are listed in [CHANGELOG.md](CHANGELOG.md). This is a non-commercial project; any redistribution must keep this licence and attribution.
