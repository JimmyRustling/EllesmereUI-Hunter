# Adversarial review, 2026-10-06 (Forever Companion 1.9.4, FHK Gear 0.5.2)

**Request (player):** "performance/error reviews? have we comprehensively reviewed each feature, edge cases, race conditions, nils etc", then "parallel agents".

**Method:**
- Ten read-only review agents, one per file group. They checked the code against `.dev/wow-ui-source-forever`, the installed EllesmereUI 9.3.5 and the staged 9.3.8.
- Claude checked every finding against the code before fixing it.
- Each fix has a mocked regression test where the harness can reach it.

**Evidence:** fixes are E1 (static) or E2 (mocked). Nothing below is E3 (seen in game). The in-game checks for the riskiest items are in `IN_GAME_CHECKS_2026-10-05.md`, rows 22-31.

**Status key:**
- **Fixed:** changed, and tested where the harness reaches it.
- **By design:** reviewed; current behaviour kept, with the reason given.
- **Deferred:** real, but needs an in-game check or a larger change. The reason is given.

## 1. Publishing rule and presets (Profiles, Companion, AutoGear glue, Chrome, Warnings, Polish, Layouts)

| # | Finding | Status |
|---|---|---|
| R1 | `RefineNativeIndicators` turned off Ellesmere's range texts and recoloured neutral units on every install | Fixed: owner only (`_G.ForeverHunterKeysNS`); published installs keep Ellesmere as configured |
| R2 | AutoGear glue paused AutoGear on published installs ("auto" default) | Fixed: published default is "Leave AutoGear Alone"; pausing needs AutoGear's imported weights |
| R3 | Chrome end-cap writes to Ellesmere's action bar profile | Fixed: owner only |
| R4 | Error-lane move and spam filter on by default | Fixed: default off on published installs |
| R5 | Chat idle-fade migration on every install | Fixed: only after the companion configured chat |
| R6 | Error lane turned off kept rewriting the error frame | Fixed: restored once, then left alone |
| R7 | Hunter Polish re-apply overwrote its undo | By design: one-step undo (tested contract); the change was reverted |
| R8 | Action bar layout re-apply overwrote its undo | By design: same as R7 |
| R9 | Combat Layout records did not follow profile rename/delete | Fixed: `combatLayout` is name-keyed in `Profiles.lua` |
| R10 | Soft-target icon CVars were restored per profile, though they are character-wide | Fixed: one original per character, restored when the last profile is undone |
| R11 | Cooldown Manager undo used list positions | Fixed: undo finds bars by key (test reorders bars between apply and undo) |
| R12 | One `reviewedProfileBefore` slot per character | Deferred: owner-only feature; needs a keyed-by-profile schema and migration |
| R13 | A queued combat apply/undo for another profile fired later | Fixed: dropped when the profile differs |
| R14 | `EllesmereAutoGearPaused` walked talents every 50 ms | Fixed: 2 s cache, reset on mode change |
| R15 | `BAG_UPDATE_DELAYED` ran a full chrome refresh per event | Fixed: coalesced to one per 0.5 s |
| R16 | Error routing may re-enable a spam-filtered type | Deferred: low confidence; UIErrorsFrame source unavailable |

## 2. Range (RangeLogic, RangeBackend, RangeIntegration)

| # | Finding | Status |
|---|---|---|
| 1 | Top text slot passed `'BOTTOM'` to `SetJustifyH` | Fixed: `justify='CENTER'` |
| 2 | A stale library bracket turned a live Shooting/Melee answer into "Range unavailable" | Fixed (also ported to FHK's own `RangeLogic.lua` for the owner install); tested |
| 3 | Sniper Shot bonus reached the display but not the classification | Fixed: `auto.max` includes it. Needs E3 (row 25) |
| 4 | On the owner install FHK's range files run instead | Noted: fix 2 ported; other range fixes are FHKEllesmere-only |
| 5 | `GetUnitRange` had no cache and allocated ~25 tables per call | Fixed: per unit+GUID 0.05 s cache, reset on spell changes |
| 6 | Non-hunters: Ellesmere single-unit helpers called per plate | Fixed: target uses them; other plates use `Range_SweepBeyond` |
| 7 | Sniper aura lookup may read secret in combat or use the talent name | Deferred: needs E3 (row 25) |
| 8 | Spellbook walk on every `SPELLS_CHANGED` | Fixed: one per frame |
| 9 | UI scale change kept old pixel geometry | Fixed: revision bump |
| 10 | Unassigned range text restyled every tick | Fixed: font and anchor only on change |

## 3. Aspects, pet elements, talents, resources

| # | Finding | Status |
|---|---|---|
| A1 | Another hunter's Pack/Wild read as yours | Fixed: `HELPFUL|PLAYER` plus a source check |
| A2 | Combat-start paint used out-of-combat rules | Fixed: combat flag from `PLAYER_REGEN_DISABLED` |
| A3 | "Only When Wrong" left invisible clickable frames | Fixed: no mouse in that mode |
| AP4 | Pet-target health never updated (no unit events for `pettarget`) | Fixed: 0.25 s poll while the button shows |
| AP5 | Passive talents read as unknown | Fixed: any known API counts. The talent-window tier/column query is unchanged (needs `/fhktalents`, row 30) |
| A6 | Click Advice enabled with In Combat / Only When Wrong | Fixed: disabled with a reason |
| AP7 | Secure pet-target button anchored to an unprotected bar | Deferred: needs an in-game combat re-layout check |
| AP8 | Resource bar sweep ran for every class, always | Fixed: runs only while a text slot is on |

## 4. Unit frames and rarity

| # | Finding | Status |
|---|---|---|
| U1 | Batched unit events repainted every frame in group combat | Fixed: drawn units only; repaints at most every 0.05 s |
| U2 | Power Bar Opacity reset to 100 % | Fixed: saved and restored |
| U3 | Health text on other units forced white | Fixed: plates only, as designed |
| U4 | One-time power-text seed on every install | Fixed: owner only, never in combat |
| U5 | Colour caches stale after a swatch change | Fixed |
| U6 | Recycled plate kept the old unit's aggro edge / dark line | Fixed: hooks read the plate's new unit; `SetUnit`/`ClearUnit` hide the marks |
| U7 | Per-sweep allocations and layout churn | Partly fixed: constant tables hoisted (plate texts). Remaining layout caching deferred (cost only) |
| U8 | Flee mark English-only (`'Humanoid'`, emote text) | Deferred: no creature-type ID API in the Forever source |
| U9 | Rarity badge missing on a friendly-to-hostile plate | Fixed: `Attach` instead of paint, retried next frame |

## 5. Companion, Bootstrap, HunterRuntime, WeaveTiming

| # | Finding | Status |
|---|---|---|
| C1 | = R1 | Fixed |
| C2 | Every event ran a full plate sweep (15 plates = 15 sweeps) | Fixed: plate add/remove bursts coalesce to one sweep per frame; swing events keep range samples |
| C3 | HUD anchor ignored profile switches | Fixed: `AnchorEllesmereHUD` runs on profile resync |
| C4 | Target beyond-range adapter disagreed with the plate sweep | Fixed: same state set |
| C5 | Icon-edge hooks allocated on every tint | Fixed: compare in locals, allocate only on change |
| C6 | = R5 | Fixed |
| C7 | `/fhktiming` accepted values the saved settings reject | Fixed: same bounds |
| C8 | Readable-fill cache unbounded | Fixed: quantised key, capped at 512 |
| C9 | Attack-cue layout switch left fades running | Fixed |
| C10 | Dual-wield melee clock restarted on each later hand | Fixed; tested |
| C11 | Facing cue heard every unit's casts | Fixed: player only |

## 6. Swing timer and cursor (SwingIntegration, SwingCursor, HunterRuntime)

| # | Finding | Status |
|---|---|---|
| S1 | READY fill wiped by Ellesmere's IdleRow / ST_Apply | Fixed: native timer writes re-arm READY; ST_Apply clears it; tested |
| S2 | Cursor melee-ready ring blinked on every Auto Shot | Fixed: same real-swing gate as the bars; tested |
| S3 | One-ring layout: brown at range, melee clock in the shot colour | Fixed; tested |
| S4 | Rings appearing during mouselook used a stale point | Fixed: the frozen point is taken once on activation |
| S5 | Spark styling lost after a native restyle | Fixed: `SetSize` hook re-arms it |
| S6 | Melee reach cached across target switches | Fixed: GUID checked first |
| S7 | Per-tick closures, scale and anchor writes | Fixed (closure hoisted; scale and retry anchor on change). Cast-ring double anchoring deferred |
| HR | Standalone HunterRuntime ticked at 20 Hz forever | Fixed: sleeps one second after the last clock or attack; events wake it; tested |

## 7. Pet food, options plumbing

| # | Finding | Status |
|---|---|---|
| P1 | List view filtered the open tab, not every bag | Fixed: every bag, one Pet Food section; tested |
| P2 | Gamepad UI: Ellesmere bags exist but Blizzard's open | Fixed: re-checked after opening; falls back to the row. Needs E3 (row 27) |
| P3 | Stale Edit / Delete links over the Pet Food header | Fixed; tested |
| P4 | Mid-feed view change left the ticker, filter or bags | Fixed: one `EndFeed`; regen kept while a row must close; tested |
| P5 | Food Only cannot narrow the window | By design: height shrinks; width keeps Ellesmere's layout |
| P6 | Food Choice disabled for the row views | Fixed |
| P7 | Navigation buttons refreshed the page they opened | Fixed: refresh only if the module and page are unchanged |
| P8 | No carrier category hid food | Fixed: row fallback; tested |

## 8. XP bar, press feedback, theme presets

| # | Finding | Status |
|---|---|---|
| T1 | Preset switches wiped later swatch edits | Fixed for preset switches: edits made after a preset survive; tested. Restore Original Look stays an exact roundtrip, and a version-migration re-apply replaces only our values |
| T2 | Theme state is per character, the settings it changes are account-wide | Deferred: needs moving `themePresets` into the profile store with a migration |
| X3 | Native dividers field is `_divHost`, not `_fvDivHost` | Fixed (mock renamed too) |
| T4 | Restore skipped toggles registered after the backup | Fixed: missing means off |
| X5 | 9.3.8 gradient fill read as white | Fixed: falls back to the XP fill token |
| X6 | Turning off Ellesmere's quest overlay did not bring ours back | Fixed: quest events stay registered while the option is on |
| T7 | Restore did not refresh nameplates | Fixed |
| T8 | Unit-frame cast colours captured with AceDB defaults | Fixed: `rawget` |
| X9 | Casts mode listed mouse clicks with Include Mouse Clicks off | Fixed (E1) |
| X10 | Quests under collapsed headers missed in the forecast | Deferred: expanding headers is intrusive; undercount accepted |
| X11 | Every keypress restyled every history cell | Deferred: cost only |
| X12 | Number-format tooltip said "every XP text" | Fixed: says 9.3.8 slots show under 10,000 in full |

## 9. FHK Gear: actions, equipment, engine

| # | Finding | Status |
|---|---|---|
| GC1 | Auto-equip undid the player's own equipment changes | Fixed: a slot changed by hand is left alone until the next level; tested |
| GC2 | A handful of better ammo replaced a full stack | Fixed: needs 200 or at least the worn count; tested |
| GC3 | A refused or failing equip retried every minute forever | Fixed: second failure, or a declined bind, ends retries for the session; tested. Tradeable/refundable confirms do not exist in the Forever source |
| GC4 | Live weights could swap two near-equal items back and forth | Fixed: an item Gear removed is not put back over another for 10 minutes; tested |
| GC5 | Loot rolls in combat never made | Fixed: `RollOnLoot` is not protected; tested |
| GC6 | Need ignored the auto-equip rules | Fixed: an upgrade outside them stays a manual roll; tested |
| GC7 | A missing reward link was never retried | Fixed: timed retries in the same budget; tested |
| GC8 | Ability Adjusted: `known` never true; non-dagger returned nil | Part fixed: non-dagger scores 0. `known` stays false by design: the mode is an estimate and automation stays manual, as its status line says |
| GC9 | Full rescore on every spell/talent burst | Deferred: a signature could miss rank changes; cost unmeasured |
| GC10 | Picked up items while dead or dragging a spell | Fixed; tested |
| GC11 | Bags equipped with `EquipCursorItem`, not `PutItemInBag` | Deferred: needs E3 (row 31) |

## 10. FHK Gear: options, markers, pop-ups, profiles, weights, model

| # | Finding | Status |
|---|---|---|
| GU1 | Profiles rejected the Hunter Model source | Fixed; round-trip tested |
| GU2 | Bag marks on recycled Blizzard buttons; Ellesmere marks a refresh late | Fixed: live bag/slot, the container enumerator, and Ellesmere's `RegisterItemOverlayIcon` (unregistered when off); tested |
| GU3 | Clicking in and out of a weight box saved custom weights | Fixed; tested |
| GU4 | One unknown Pawn entry rejected the scale | Fixed; tested |
| GU5 | Upgrade Found cards lost in combat | Fixed: the scan waits for combat to end (E1) |
| GU6 | Every Auto Shot ran bag, model and marker work | Fixed: bag work waits for combat to end; tested |
| GU7 | A single rating conversion rejected | Fixed; tested |
| GU8 | Main hand scored without the dual-wield miss | Deferred: needs per-setup weapon scoring; small effect at the default melee share |
| GU9 | Unusable ammo counted in the model | Fixed |
| GU10 | Pet counted before Tame Beast | Fixed; tested |
| GU11 | Roll border covered the roll frame's text | Fixed: painted on the item icon |

## Test totals after the fixes

| Suite | Live (9.3.5 + local core patch) | Staged stock 9.3.8 |
|---|---|---|
| Validate (static) | pass | pass |
| Integration | 2928 | 2926 |
| Aspect / pet / probe / pet food / cues / leveling | 174 / 149 / 26 / 86 / 67 / 60 | same |
| Standalone, no other addons | pass (installed and stock 9.3.5 cores) | pass |
| Themes and class HUD | 574 (now part of `npm test`) | 554; the options-extension block is skipped because stock 9.3.8 has no such core file |
| Installer | pass; `Apply.ps1 -Mode Check`: 0 files need changes | n/a |
| FHK Gear | 505 | n/a |

**Found while checking:** `RunThemeChecks.js` was not part of `npm test`, and it had been failing since the owner-only gating. Its General-page check now builds as the owner install, and it now runs in `npm test`.

**Not run:** the FHK Python test venv fails to import `lupa`, so `test_range_logic.py` did not run. The ported R2 change is covered by the Validate load of FHK's `RangeLogic.lua`.
