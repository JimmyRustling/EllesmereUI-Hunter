# Suite review: visual modules we hook or draw on (2026-10-06)

Reviewer: read-only adversarial pass (Claude). Scope: Forever Companion 1.9.5 (`Interface/AddOns/FHKEllesmere/`) against EllesmereUI **main 9.3.9 (14245494)** as staged in `.dev/staged-main-939/Interface/AddOns/`.
Evidence: **E1 only** (static reading on both sides). Anything marked **probe** needs the client.
Ellesmere paths below are relative to `.dev/staged-main-939/Interface/AddOns/`. Ours are relative to `Interface/AddOns/FHKEllesmere/`.

Severity: **must** = a deterministic visible break or error on a reachable path while our feature is at its default. **should** = a duplicate or override that silently defeats a native Ellesmere setting, or a fragile or costly pattern. **nice** = polish, or a probe-only risk.

---

## 1. Hook fragility: dependency check on main

Every Ellesmere internal we read, hook or replace still exists on main, and almost every access is nil-guarded. A missing target is therefore a **silent no-op** unless it is listed under "unguarded".

| Our file:line | Ellesmere target | On main | If missing |
|---|---|---|---|
| UnitRefinements.lua:1032-1126 | `ns.ContentToZone` / `SetTextZone` / `SetTextZoneRaw` / `UF_PaintPowerText` / `TextPieces` (replaced or post-hooked) | EUI_UnitFrames_Text.lua:961, 1009 (Forever wrap), 1054, 1082, 1103; all callers go through `ns.` (Builders.lua:454, Power.lua:561-596, Text.lua:187) | guarded, no-op |
| UnitRefinements.lua:411-421 | `ns.UF_RefreshPetHappiness`, `UF_ApplyPetHappiness`, `pf._petHappy._tex/_atlas` | ForeverExtras.lua:24, 73, 95 (OnEvent bound to the original function, which is why we also HookScript) | guarded |
| UnitRefinements.lua:1000-1010, 1342-1363 | `frame._combatIndicator` (texture), its `SetPoint`/`Show`/`Hide` | Init.lua:852-929 (player + target only) | guarded |
| UnitRefinements.lua:141 | `_G._EUI_ResolvedPowerType` | **absent on main**; it falls back to `UnitPowerType` | silent fallback |
| UnitRefinements.lua:1523-1556, Companion.lua:567-814 | `np.plates`, `plate.health/healthBG/hpText/hpNumber/name/glowFrame/glowTextures/cast`, `SetUnit/ClearUnit`, `GetTargetGlowColor/Alpha` | PlatePool.lua:35-243, Overlays.lua:39-53, Plate.lua:950/1074, Layout.lua:846-849 | guarded |
| CueFades.lua:214-231 | `np.NT_Apply` (replaced), `np._UpdateMouseover` (hooked), `_ntCurAlpha` cache | CastState.lua:40-56; every caller uses `ns.NT_Apply` (Init.lua:385/399, Plate.lua:979, Events.lua:498-500) | guarded |
| Rarity.lua:130-169 | `ns.GetUnitLevelText` (replaced), `NP_UpdateForeverLevel`, `_fvLevelBox._fs`, `classFrame/classText`, `GetClassificationSlot`, `IsQuestMob`, `_npForever` | Layout.lua:626 (signature is now `(unit, color)` and `"diff"` reads as our `plain`, which the code intends), Styles.lua:653/711, Name.lua:89-116, Colors.lua:220 | guarded |
| RangeIntegration.lua:471-519 | `GetTextSlot`, `SlotTextHost`, `SetFSFont`, `GetTextSlotSize`, `PlaceSlotText` | Layout.lua:472/1429/1446, EllesmereUINameplates.lua:30 | guarded |
| ResourceRefinements.lua:13, ClassCues.lua:687/712, ClassMechanics.lua:45 | `_G.ERB_HealthBar`, `_G.ERB_PrimaryBar` (wrapper frame; the fill lives on `bar._sb`) | EllesmereUIResourceBars.lua:2030-2058, 3362, 3538 | guarded |
| SwingIntegration.lua:199-428, 491-544 | `ERB_SwingTimerFrame`, rows `_def/_bar/_tag/_time/_spark/_merged/_end/_dur/_durObj`, shell `OnEvent` (synthetic `PLAYER_SWING`/`PLAYER_DEAD`), `ns.ST_Apply`, `ns.ERB_BuildSwingTimerPage` (LOD options), global `EUI.SetElementVisibility` (replaced) | SwingTimer.lua:85, 186-239, 637-660, 790; SwingTimerPage_Options.lua:13; SharedHelpers.lua:77 | **partly unguarded**, see SF-15 |
| HunterCues.lua:343-385, ClassCues.lua:460-499 | `ab.barButtons`, `ab.EAB.db.profile.procGlow*`, `EUI.Glows.{StartGlow,StopAllGlows,MakeView,ResolveColor,DEFAULT_COLOR,...}` | EllesmereUIActionBars.lua:1673-1674, 510-513; EllesmereUI_Glows.lua:1195-1221, 1288, 1296, 1364 | pcall-guarded |
| ActionPressFeedback.lua:315-354 | `ns.barButtons`, `ns._eabApplyAll` (hooked), Blizzard `ActionButtonDown` / `MultiActionButtonDown` | EllesmereUIActionBars.lua:6027 | guarded |
| CdmLabels.lua:95-139 | `cdmBarIcons`, `_hookFrameData[icon].keybindText`, `ApplyCachedKeybinds`, `ShowCDMKeybindBadge` | EUI_CDM_Rebuild.lua:757-810, 1019; CdmHooks.lua:34; CdmKeybindStyle.lua:82. Internal rebuilds call the **local** `ApplyCachedKeybinds` (Rebuild.lua:806/819), which our comment already accounts for via the badge hook | guarded |
| HunterPolish.lua:191-197 | `EAB:ApplyFontsForBar` | EUI_ActionBars_Apply.lua:280 | guarded |
| XPBarRefinements.lua:352-386 | `EllesmereEAB_XPBar_Rested`, parent `_bar/_restedBar/_text`; **instance override** of `bar.SetValue` | EUI_ActionBars_XPBar.lua:1692-1705, DataBars.lua:351 | guarded |
| SwingCursor.lua:425-471 | `ECL_CastRoot`, ring `StartRing*`, `_ECL_ApplyCastCircle/_ECL_UpdateVisibility/_ECL_Apply/_ECL_AceDB` | EllesmereUIQoL_Cursor.lua:401-413, 821, 1377-1383 | guarded |

The ToT, pet-frame and health post-hooks all run in the same frame as Ellesmere's write (hooksecurefunc fires after it), so they do not flicker. The problems are elsewhere: we keep painting after Ellesmere has painted differently (SF-1, SF-3), or our hook gets removed underneath us (SF-2).

---

## 2. Findings

### SF-1: our fill colouring wipes Ellesmere gradients (UF and Resource Bars), **must**
- **Ours:** UnitRefinements.lua:620-627 (`Shade` then `SetStatusBarColor`/`SetVertexColor`), :641-654 (setter hook takes the new colour as `base`), :1617-1623 (0.15 s sweep); ResourceRefinements.lua:52 (hooks the ERB **fill texture**), :122-125 (repaints on every player `UNIT_POWER_FREQUENT`/`UNIT_HEALTH`).
- **Ellesmere:** EllesmereUIResourceBars.lua:1695-1721 (`ApplyBarGradient`: `rawVC(ft,1,1,1,1)`, then `SetGradient`, change-gated by `ft._lgOn`), callers :3459/3645/4470/4497/4611/4765/4794. EllesmereUIUnitFrames.lua:1332-1337 (UF `ApplyBarGradient` = `SetVertexColor(1,1,1,1)` + `SetGradient`), :2083-2091 (in `PostUpdateColor`). EUI_UnitFrames_Text.lua:110-115 (a plain `UNIT_HEALTH` does not re-run the colour chain).
- **Failure:** The player turns on Resource Bars > Primary > Gradient. ERB's `rawVC(…1,1,1,1)` fires our hook, so `state.base` becomes white. On the next power tick our `Shade(white)` `SetVertexColor` replaces the gradient. ERB's `_lgOn` cache never re-applies it, so the bar stays flat grey-white. On the UF player and pet frames, the gradient is lost after the first damage tick until the next identity or colour pass. Both `resourceBarColors` and `healthBarColors` default to on (UnitRefinements.lua:561).
- **Fix (ours):** In `PaintBar`, treat the fill as natively owned (`enabled=false`, no write) when the profile has `gradientEnabled` (ERB: `rb.ERB.db.profile[state.key].gradientEnabled`; UF: `uf.db.profile[unitKey].gradientEnabled`), or when `fill._lgOn` is true.
- **Test:** yes, mocked (Validate.lua): with the gradient on, a power change produces no `SetVertexColor` from us.

### SF-2: ERB Fill Opacity uninstall deletes our setter hook, **should**
- **Ours:** UnitRefinements.lua:638-655 (hooks once; `barStates` never re-hooks); ResourceRefinements.lua:50-52.
- **Ellesmere:** EllesmereUIResourceBars.lua:1799-1806 (the wrapper captures the existing instance method, which is our hook), :1776-1780 (`tex.SetVertexColor = nil` on returning to 100).
- **Failure:** Fill Opacity is set to 80 and then back to 100. That nils the instance field, which removes our `hooksecurefunc` as well. ERB repaints (for example a druid shifting to cat: energy yellow) go unseen, and our next tick repaints `Shade(stale mana blue)`, so the bar shows the wrong colour.
- **Fix:** Store the hooked function in `state`. In `RefineBar`, if `rawget(bar, setter) ~= state.hook`, drop `barStates[bar]` and hook again.
- **Test:** yes, mocked.

### SF-3: our health ramp stacks on Ellesmere's Dynamic Health Color and ERB thresholds/bands, **should**
- **Ours:** UnitRefinements.lua:162-178, 561, 620-623; curve reset :651.
- **Ellesmere:** EllesmereUIUnitFrames.lua:1813-1832 (`UF_DynamicHealthColor`, modes classic/customDynamic/classReactive), :2064-2067, :2092-2098; ERB EllesmereUIResourceBars.lua:4478-4486 (threshold or band curve `SetVertexColor`).
- **Failure:** Health Color Mode is set to Classic. Ellesmere paints yellow at 50%, our hook adopts that as the base and blends our gold over it, and below 50% our ramp replaces Ellesmere's entirely. With secret values, `base` flips between class and dynamic on every `UNIT_HEALTH`, so `state.curve` (33 `CreateColor`) is rebuilt twice per event.
- **Fix:** Set `enabled=false` when the unit's `healthColorMode` is non-nil and not `none`, or when ERB threshold or band colouring is active for that bar.
- **Test:** yes, mocked.

### SF-4: nameplate opacity replaces Ellesmere Non-Target Opacity and Out-of-Range fade, on by default, **should**
- **Ours:** CueFades.lua:144 (`enabled=true`), 147-150, 168-205, 214-241 (`np.NT_Apply` replaced; new plates deferred with `C_Timer.After(0)`, :238).
- **Ellesmere:** EUI_Nameplates_CastState.lua:40-56 (`nonTargetAlpha × _oorCurAlpha`), Init.lua:355-390 (the OOR sweep sets `_oorCurAlpha` and then calls `ns.NT_Apply`), Plate.lua:979, 1090-1095.
- **Failure:** The user's Non-Target Opacity and Out-of-Range alpha sliders do nothing. Enemy plates sit at .55/.25 even with no target. With native NT off, a new plate shows at alpha 1 for one frame and then pops down.
- **Fix:** Default off unless `_G.ForeverHunterKeysNS ~= nil`. When on, multiply by `plate._oorCurAlpha` and defer to native when `p.nonTargetAlpha < 100`.
- **Test:** yes, mocked.

### SF-5: aggro edge, range name colour and white health text override Ellesmere's threat and text-slot lanes, **should**
- **Ours:** UnitRefinements.lua:1294-1329, 1551 (edge drawn 2 px outside, at level +5 on OVERLAY 7); Companion.lua:592-600, 772 (re-asserts the name colour after every native `SetTextColor`); UnitRefinements.lua:104-109 with 1553-1555 (enemy plate `hpText`/`hpNumber` forced white every sweep).
- **Ellesmere:** EUI_Nameplates_Health.lua:369-420 (Threat Colors Border/Name channels, `_threatBdOn`/`_threatNameOn`); Colors.lua:512-560; Plate.lua:796-806 (`hpText` Text Slot Color).
- **Failure:** In a group with Threat Colors Border on, an off-tank's mob carries Ellesmere's red border plus our gold ring, so two contradicting borders show. The threat Name colour is always masked. The user's health % slot colour is white within 0.15 s of every `ApplyAppearance` (a visible flicker after a settings change, wrong permanently).
- **Fix:** Skip `PaintAggro` when `plate._threatBdOn`. Skip the name override when `plate._threatNameOn`. In the nameplate branch of `PaintEllesmereHealthText`, only force white when our dark fill is active.
- **Test:** yes, mocked.

### SF-6: neutral aggro hue overrides Ellesmere's in-combat neutral tint, **should**
- **Ours:** UnitRefinements.lua:490-522, 583-586.
- **Ellesmere:** EUI_Nameplates_Colors.lua:264-271 (`enemyInCombat` for neutrals in combat); Health.lua:353-360 (skip-if-unchanged).
- **Failure:** A neutral mob in combat is painted the user's `enemyInCombat` colour, and our hook repaints it `profile.hostile` on the same frame.
- **Fix:** Apply only in the `unitframes` context.
- **Test:** mocked.

### SF-7: Damage Flash "Instant Health" disables Ellesmere Smooth Bars by default, **should**
- **Ours:** DamageTrail.lua:28-30, 138 (`SetToTargetValue` on every `SetValue`).
- **Ellesmere:** EUI_UnitFrames_Layout.lua:823-826, Reload.lua:1580-1585 (`smoothBars` is opt-in).
- **Failure:** The user enables Smooth Bars and nothing changes.
- **Fix:** Leave `instantHealth` unset by default, which follows native: skip when `bar.smoothing` is the ease-out value unless the player set it explicitly.
- **Test:** mocked.

### SF-8: combat block, pet mood square and edge badge replace native options by default, **should**
- **Ours:** UnitRefinements.lua:1342-1363 (`icon:SetAlpha(0)` plus a white block), 983-1010 (re-anchors on every native `SetPoint`), 375-376, 397-406.
- **Ellesmere:** Init.lua:862-929 (combat style, colour mode and position), ForeverExtras.lua:73-119 (happiness size, align and offsets).
- **Failure:** The user picks Combat Indicator "Class Theme" in class colour and sees a white square. "Center" is moved onto the top edge. The pet Right/X/Y offsets are reinterpreted.
- **Fix:** Default `combatIconStyle='native'` and `statusIconBadge=false` unless on the owner's install.
- **Test:** no (E1 static is enough).

### SF-9: range text offsets are reset every sweep by our own second writer, **should**
- **Ours:** Companion.lua:782-784 (re-anchors to `(0,-5)` every tick) against RangeIntegration.lua:510-515 (places at `textX/textY` only when `_fhkTextAnchor` changes).
- **Failure:** The player sets Default Range Text Position X=20, Y=-12. It shows for one sweep and then snaps back.
- **Fix:** Drop Companion 782-784 when `FHK.PaintEllesmereRangeText` exists, or clear `f._fhkTextAnchor` there.
- **Test:** yes, mocked.

### SF-10: swing-row fill colour desyncs Ellesmere's change-gate and wipes the swing gradient, **should**
- **Ours:** SwingIntegration.lua:273-278, 374-378.
- **Ellesmere:** EllesmereUIResourceBars.lua:1695-1733 (`_lfOn`/`_lgOn` caches); SwingTimer.lua:395-413 (`cfg.gradientEnabled`).
- **Failure:** With the swing gradient on, the first READY/busy change replaces the gradient for good. When our colour stops, Ellesmere's cache keeps our stale colour until `ST_Apply`.
- **Fix:** Skip our fill paint when `cfg.gradientEnabled`. When we stop painting, call `ns.ST_Apply()`.
- **Test:** mocked.

### SF-11: combined per-plate polling cost, **should**
- **Ours:** Companion.lua:60-75 (sample cache TTL 0.1 s, shorter than the 0.15 s sweep, so it never hits across sweeps), 735-814, 1346-1355; UnitRefinements.lua:1523-1556, 1617-1623; Profiles.lua:35-41 (busy whenever any plate exists).
- **Ellesmere:** Init.lua:355-390 (OOR checks 8 plates per tick, round robin), Health.lua:325-360 (event-driven, skip-if-unchanged).
- **Estimate for 25 plates:** UnitRefinements makes about 25 C calls per plate (`OwnUnit` ×3, `NeutralAggroColor`, dark line, `PaintAggro`, 2× health text). Companion makes about 35 (sample, opacity, loot, glow, text re-anchor). That is about 1,500 calls per 0.15 s, roughly 10k/s, plus about 3 short-lived tables or strings per plate per sweep (around 500 per second of garbage), all while plates exist and regardless of events.
- **Pull storm:** 25× `NAME_PLATE_UNIT_ADDED` costs 2 Companion sweeps, 25 CueFades closures with `NT_Apply`, 25 Rarity closures with `Attach`, and DamageTrail looping all tracked bars 25 times. That is acceptable. We do not multiply Ellesmere's per-event cost (all post-hooks are O(1)); we add a constant polling floor on top of it.
- **Fix:** Set the sample TTL to at least the sweep interval, merge the two drivers, round-robin plates (8 per tick) for range and opacity, and remove the per-sweep `f.text` re-anchor (SF-9).
- **Test:** `/fhkperf` **probe**; a mocked call counter.

### SF-12: reactive glow wrappers, **nice, probe**
- **Ours:** HunterCues.lua:352-385, ClassCues.lua:468-499 (wrapper parented to the secure button, no shape mask).
- **Ellesmere:** EUI_ActionBars_Glows.lua:120-226 (wrapper parented to `btn:GetParent()`, honours shape masks).
- **Probe:** whether Forever fires the overlay glow for Overpower or Mongoose Bite (if so, the glow is doubled).
- **Fix:** Parent to `btn:GetParent()`, and skip ours while `btn.SpellActivationAlert` is shown.

### SF-13: pet-target secure button anchored to Ellesmere's pet Health bar, **nice, probe**
- **Ours:** PetElements.lua:138-139, 157-159.
- **Ellesmere:** EUI_UnitFrames_Layout.lua:679-681 (Health re-anchor, combat-guarded in Reload).
- A protected frame anchored to `Health` makes `Health` implicitly protected.
- **Fix:** Anchor to the pet frame (`Parent()`), which is already protected.
- **Probe:** for `ADDON_ACTION_BLOCKED`.

### SF-14: child frames created on secure unit frames during combat, **nice, probe**
- UnitRefinements.lua:306, 1376, 1451 create holders lazily, possibly in combat. :841 guards this; the others do not.
- **Fix:** Pre-create them at login.

### SF-15: unguarded swing internals, **nice**
- SwingIntegration.lua:305 and :405 use `row._durObj` without a guard (only :347 checks it). Synthetic events go into Ellesmere's private handler at :301-303 and :553-554. The global `EUI.SetElementVisibility` is replaced at :535-541.
- All are valid on main, but a rename would raise a nil-index error 20 times a second.
- **Fix:** Guard on `row._durObj and row._bar.SetTimerDuration`.

### SF-16: energy-tick spark uses a per-frame Lua OnUpdate, **nice**
- ClassCues.lua:754-771, against Ellesmere's engine-animated ManaRegenSpark (EllesmereUI_ManaRegenSpark.lua header). These coexist: mana on theirs, energy on ours.

### SF-17: duplicated displays, **nice**
- WeaponEnchants pods duplicate the PAB weapon-enchant cells and ForeverImbues (PlayerAuraBars.lua:2878-2921). Ours is off by default.
- The Class HUD turns on ERB combo points while the UF combo arc defaults to `target` (EllesmereUIUnitFrames.lua:441; ForeverExtras.lua:232-237).
- Coexistence: show a hint, or offer `foreverComboLocation='never'`.

### SF-18: own-unit colour lags the value by up to 0.15 s, **nice**
- UnitRefinements.lua:1617-1623 against Text.lua:110-115.
- **Fix:** Call `PaintBar` from the DamageTrail `SetValue` hook for own units.

## 3. Taint summary (question 4)
- No `SetAttribute`, `SetPoint`, `Show` or `Hide` on Ellesmere-owned **secure** frames in combat.
- Our own secure bars change attributes only out of combat (SummonBar, ClassBuffs, WeaponEnchants and AspectBar all gate on `OutsideCombat`).
- `HookScript('PostClick')` on Ellesmere action buttons is a post-hook only, installed out of combat (ActionPressFeedback.lua:316-326).
- Blizzard functions are hooked only with `hooksecurefunc`.
- The direct overrides (`ns.ContentToZone`, `SetTextZoneRaw`, `NT_Apply`, `GetUnitLevelText`, `ERB_BuildSwingTimerPage`, `EUI.SetElementVisibility`, `EUI.Widgets.DualRow`, XP `bar.SetValue`) replace addon Lua, so they add no taint to Blizzard secure code.
- Residual probes: SF-13, SF-14, and ModernChrome.lua:206-221, which re-parents and lays out Blizzard micro buttons (out of combat, Edit Mode taint **probe**).
