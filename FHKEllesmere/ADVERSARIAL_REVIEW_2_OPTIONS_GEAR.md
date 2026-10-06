# Adversarial review 2: options integration layer and FHK Gear 0.5.3

- Date: 2026-10-06. Reviewer: Claude (read-only adversarial agent). Evidence: **E1 only** (code reading). Nothing here was seen in game.
- Scope:
  - Part 1: `FHKEllesmere/RefinementOptions.lua` (class gate, neutral titles, class hub, Recommended set), `Profiles.lua`, `Bootstrap.lua` (`NS.EllesmereAway`, `behind` / `front` tokens), TOC order.
  - Part 2: FHK Gear "Unreleased / 0.5.3".
- Ellesmere plugin API was read only: `EllesmereUI_Panel.lua` `NavigateToElementSettings` (3304) and `RegisterPlugin` / `GetPluginModuleKey` / `OpenPlugin` (5002-5089).
- Test runs at review time:
  - `node Interface/AddOns/FHKGear/tests/run.js`: 697 passing.
  - `node Validate.js` and `node RunIntegration.js`: all pass.
- Severity: **must** = wrong action or data loss; **should** = real failure in a plausible case; **nice** = polish or hardening. **probe** = needs the game to confirm.

## Verified, no finding

- **Class gate.** `SECTION_CLASSES` + `SectionAllowed` + `ClassTitle`:
  - A warlock gets PETS AND SUMMONS, PET AURAS AND TARGET and PET CUES (only Pet Idle, via `PetRow`).
  - Other non-hunters get WARNINGS (rows filtered by class in `Warnings.lua:1127-1206`) and CUE COLORS.
  - Every class-hub row references a section its class is allowed. `RunStandalone.js` runs all 9 classes.
- **Hub links.** `HubRows` stores `link.section=ClassTitle(item[2])`, so the WARNINGS and PET CUES links resolve.
  - `NavigateToElementSettings` matches `header._sectionName` exactly, then highlights the first member whose label *contains* the row text.
  - Each hub label is the first such member in its section (for example "Range Indicator" comes before "Range Indicator Text").
- **TOC order.** The new files read `NS.ClassTrainingData`, `NS.EllesmereAway` and `NS.Ellesmere*Settings` at call time, never at file scope. Bootstrap is first and RefinementOptions is last. No load-order defect.
- **`NS.EllesmereAway`.** It returns a reason only for a readable `true`, and an unreadable state is never a reason.
  - `bought` stays visible while mounted. `buff` / `made` / `act` are quiet while mounted.
  - Every caller treats a nil result as "not away".
  - The fallbacks in `Warnings.lua:66` and `HunterCues.lua:78` mirror it.
- **`behind` / `front` tokens.** `ClassCues.lua:126-135` falls back to its own values if a token is missing. Player colours live in `behindIndicator.colors`, so there is no `hunterColors` interaction.
- **Profile keys.** All 10 new class-kit keys are in `PROFILE_KEYS`, a reset list and the Resync list (via the `SyncEllesmereBehind` / `EnergyTick` aliases). These stay per character: `weaponEnchantsLearned`, `classStockSoulstone`, `rankNotifierIgnore`, `restockSeen` (rawset), `talentPlan`.
- **Gear 0.5.3:**
  - **Shift on quest rewards** (`Actions.lua:243-264`): only an explicit `true` from Shift blocks the pick.
  - **SayAction:** `S.Call` returns `true,result`, and `N.Show` returns true only when a card shows, so an action is never reported twice.
  - **D8 `Known()`:** answers in order and treats a secret answer as unknown.
  - **Events while off:** `START_LOOT_ROLL` is registered for Mark Roll only; `RollOnLoot` is gated by `Automating('autoRoll')`.
  - **BoE cap:** `AutoEquipAllowed` covers bag equips, hand-pair follow-ups and ammo.
  - **Text colours:** validated on read (`ns.Colour`) and in profiles.
  - **Migration:** the `rollGreedNonGear` migration is correct.
  - **Shared rule:** Need-not-allowed never falls back to a silent Greed.

## Findings

| ID | Where | Sev | Failure scenario | Minimal fix | Test |
|---|---|---|---|---|---|
| R3-1 | RefinementOptions.lua:365-376, 401 | should | "Turn Off Hunter Set" forces every RECOMMENDED toggle off, including default-on and class-shared ones: Low Ammo (`ammo=true`), Unspent Talent (`talents=true`), Combat Warnings Above Character (`critical=true`), Range Indicator, Facing Failure Cue, and the shared ALERTS rows. A hunter who tries On then Off ends below a fresh install. The tooltip also says nothing in the game changes, but Top Alert Lane and Hide Spam Errors move and filter `UIErrorsFrame`. | On Turn On, rawset a per-character snapshot `{label=previous}` and restore it on Turn Off (or switch off only what Turn On changed). Reword the tooltip. | yes (standalone On then Off restores defaults) |
| R3-2 | RefinementOptions.lua:1081-1105; Profiles.lua:153 | should | CUE COLORS shows for every class with "Shooting" and "Retry (Auto Shot)" swatches. Its "Reset Hunter Colors" sets `hunterColors=nil`, which also resets health, happiness, rarity, aggro-edge, mirror and alert colours set in other sections. Example: a rogue's Health 25% colour is lost. The QoL native Reset does the same through the whole-key `hunterColors` entry. | Use `NS.EllesmereResetColors({'shoot','melee','cast','retry','danger','caution'},'Reset Cue Colors')`. Hide `shoot` / `retry` for non-hunters. Reset per-token in `RESET_KEYS`. | yes |
| R3-3 | Gear Profiles.lua:89-137 with FHKEllesmere Profiles.lua:127-137 | should | Importing someone else's full Ellesmere profile carries `fhkGearSettings`. That includes `autoRoll`, `autoEquip`, `autoQuest`, `confirmLootRolls`, `rollNonGear='need'`, `rollNonGearMaxQuality` up to 5 and `rarityCapBoEOnly`. The recipient gets automatic Need (non-gear up to Legendary) and auto-confirmed BoP rolls without ever choosing them. 0.5.3's new roll keys widen an older hole. | Never transfer the automation masters (`autoEquip`, `autoQuest`, `autoRoll`) or the `confirm*` keys: keep the recipient's values in `ApplyProfile`. Optionally keep `rollNonGear` too. | yes |
| R3-4 | Core.lua:153, Equipment.lua:552 | should | With "Rarity Cap: Bind on Equip Only", a roll item reads `bound='bop'` from its link tooltip, so a raid epic BoP upgrade passes an Uncommon cap and is Needed. With Auto-Confirm Roll Prompt on, it is fully automatic. The stated rationale ("cannot be sold or traded") is true only after the item is won. | Pass a roll flag to `AutoEquipAllowed`; for rolls, count only `bound=='bound'` as `mine`. Or update the option text if this is intended. | yes |
| R3-5 | Equipment.lua:521-541; Items.lua:220 | should, **probe** | Non-gear Need never checks usability. `Items.Read` skips tooltip lines when `equipLoc==''`, so `info.usable` is always true. Shirts and tabards (`INVTYPE_BODY` / `INVTYPE_TABARD`, class 4) also count as non-gear. With Need and Up To Epic, Gear Needs another class's tokens or class items if Forever does not file them under 9/12/13. | For `need`, require `C_PlayerInfo.CanUseItem(id)~=false` and no red tooltip line. Make class 15 subclass 0 (Junk) of rare quality or higher the player's roll. | yes |
| R3-6 | Equipment.lua:525-526 | **probe** | Mounts and pets are excluded only as class 15 subclass 5 / 2. If Forever data files a white pet carrier or a mount as 15/0, it gets Greed or Need at a cap at or above its quality. Most pet carriers are quality 1, inside the default Uncommon cap. | Probe: `/dump GetItemInfoInstant(8485)` (Cat Carrier) and `GetItemInfoInstant(13335)` (a mount). If either is 15/0, add an item-ID or tooltip ("Use: Teaches you how to summon" / "Summons and dismisses") exclusion. | after probe |
| R3-7 | RefinementOptions.lua:358-361 | nice | The hub's missing-row check only fires when the section exists. A renamed or gated section drops all of its hub rows silently, and `StandaloneTests.lua:522` cannot see it. | Also record when no `pluginSections[page]` entry has that title while `SectionAllowed(item[2])` is true. | yes |
| R3-8 | RefinementOptions.lua:188, 1053-1109 | nice, **probe** | Titles and the class page are fixed at the first `Install()` (file load). If `UnitClass` is unreadable then, the hunter titles and no class page register. A later `Install()` with a known class queues WARNINGS beside HUNTER WARNINGS, a duplicate section. | Cache the first non-nil class once and use it for every decision. Probe: does `UnitClass('player')` read at file load on Forever? | no |
| R3-9 | Profiles.lua:142-154 | nice | `cdmLabels`, `extraCombatIcons` and `combatFadeGuides` are in no reset list, so plugin Reset and native Reset leave them. Not today's keys. | Add an `EllesmereUICooldownManager={'cdmLabels'}` entry; add `extraCombatIcons` under Nameplates. | yes |
| R3-10 | Core.lua:11, 70 | nice | Behaviour change: an existing Auto-Equip Up To = Rare user now keeps blue BoE upgrades in bags, with no in-game notice (the G10 "never silent" spirit). | A one-time `Say` when `autoEquipMaxQuality>equipBoEMaxQuality` and `equipBoE`, with a flag. | yes |
| R3-11 | Gear Profiles.lua:14, 96; Core.lua:54 | nice | A profile with `equipBoEMaxQuality=2.5` or `rollNonGearMaxQuality=4.9` validates. `Char()` normalizes only on rebind, so the dropdown shows blank for the session. | Require an integer for `*MaxQuality` in `ValidateProfile`. | yes |
| R3-12 | Equipment.lua:507-511 | nice | Minimum Need Gain for a 2H weapon divides by the main-hand score only, overstating the gain when an off hand is also replaced. | For 2H, sum the scores of slots 16 and 17. | yes |
| R3-13 | RefinementOptions.lua:873; HunterCues.lua:451 | nice | The Flee Mark tooltip tells every class to "Have Concussive Shot ready". The Hunter's Mark cue is not rechecked on mount or dismount; it has no away events. | Make the tooltip class-neutral; add `PLAYER_MOUNT_DISPLAY_CHANGED` to the mark check. | no |
| R3-14 | Gear CHANGELOG G12 vs Profiles.lua:36 | nice | `textColours` is described as per character, but it travels in the per-Ellesmere-profile `fhkGearSettings` and is re-applied at login. | Fix the wording, or drop it from `ExportProfile`. | no |

**Probes owed (E3):** R3-5, R3-6, R3-8. Also:
- Does `UnitIsDeadOrGhost('player')` return false while you are in Feign Death? If it returns true, every `act` cue goes quiet while you feign.
- Is `PLAYER_MOUNT_DISPLAY_CHANGED` valid on Forever? `ClassBuffs` / `ClassStock` / `Warnings` rely on it, and `C_EventUtils.IsEventValid` already guards it.

## Summary

There are no **must** findings. The class gate, the neutral titles and the hub links hold for all 9 classes. TOC order and `EllesmereAway` are sound. Gear's rolls never act while the toggle is off and never equip BoE above the cap.

Should findings:
- R3-1: Turn Off Hunter Set clobbers default-on and shared alerts.
- R3-2: CUE COLORS Reset wipes other sections' colours.
- R3-3: a profile import turns on another player's roll and equip automation.
- R3-4: the BoE-only cap lets BoP epics be auto-Needed.
- R3-5: non-gear Need never checks usability (probe).
- R3-6: mount and pet classification on Forever (probe).
