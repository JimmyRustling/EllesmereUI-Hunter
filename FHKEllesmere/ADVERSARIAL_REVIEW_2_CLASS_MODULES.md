# Adversarial review 2: class modules (2026-10-06)

Scope: `Interface/AddOns/FHKEllesmere/ClassBuffs.lua`, `WeaponEnchants.lua`, `ClassCues.lua`. Read-only review; no code changed.
Evidence: **E1 (static) only**. I read the code paths, the Forever API docs (`Blizzard_APIDocumentationGenerated`) and `Blizzard_FrameXML/SecureTemplates.lua` / `Blizzard_RestrictedAddOnEnvironment/SecureStateDriver.lua` in the full clone. Nothing here was checked in game. "Probe" marks findings that only an in-game check can settle.

## What checked out (no finding)

- **APIs and events.** Every event registered exists in the Forever docs. `C_Item.GetWeaponEnchantInfo` returns a list of `{hasEnchant, enchantType, timeLeft, charges, enchantID, enchantIconID}`, and `BuffFrame.lua` confirms `timeLeft` is in ms. `UNIT_SPELLCAST_SUCCEEDED` (unit, castGUID, spellID), `UNIT_COMBAT` (unit, event, flagText, ...) and `UI_ERROR_MESSAGE` (type, message) are unpacked in the right order. `GetItemInfoInstant` returns classID and subclassID at the right positions.
- **Secure buttons.**
  - Size, anchors, show/hide and `SetAttribute` all run behind `OutsideCombat()`, with changes queued for `PLAYER_REGEN_ENABLED`.
  - `RegisterForClicks('AnyUp')` is correct for mouse clicks: `SecureActionButton_OnClick` treats a secure mouse press as acting on up.
  - `type=item` with `item='item:ID'` plus `target-slot` applies to the weapon (`OnActionButtonClick` calls `UseInventoryItem(slot)` when `SpellCanTargetItem()` is true).
  - `macrotext2` resolves through the modified-attribute suffix.
  - An insecure `PreClick` hook is safe.
- **Code hygiene.**
  - No global leaks: every assignment target is a declared local or an NS field.
  - Forward declarations (`Show`, `Hide`, `PaintBehind`, `SparkUpdate`) are assigned before any runtime call.
  - Stale-timer tokens (`epoch`, `evidence.token`, `stateToken`, `previewToken`) are sound.
  - All three modules are zero-cost while off: no events, tickers or OnUpdate.

## Findings

| ID | File:line | Sev | Scenario -> wrong result | Minimal fix | Test? |
|---|---|---|---|---|---|
| R1-1 | WeaponEnchants.lua:720-721 (EVENTS), 520 | **must** | `W.Cues` applies `Away('buff')`, but no event re-runs it when the away state changes: no mount, death or taxi events are registered. Scenario: a single weapon, no poison, "NO INSTANT POISON" is up (no countdown, so no ticker); the player mounts -> the cue stays up while mounted, and through death and the ghost run. It does not return after dismounting until a bag or inventory event fires. | Register `PLAYER_MOUNT_DISPLAY_CHANGED`, `PLAYER_DEAD`, `PLAYER_ALIVE`, `PLAYER_UNGHOST`, `PLAYER_CONTROL_LOST` and `PLAYER_CONTROL_GAINED` (as ClassBuffs does) and route them to `W.Cues();W.Paint()`. | Yes: mount -> cue hidden; dismount -> back. |
| R1-2 | ClassCues.lua:597-608, 817, 875 | should | `CheckSnD` allocates a new `C_Timer.After` closure on every call while Slice and Dice is up and CP >= the minimum. It runs on every target `UNIT_HEALTH`. In group combat (~5-10/s for up to 30 s), hundreds of no-op timers pile up. | Keep `snd.timerAt`; schedule only when the boundary changes (ClassBuffs `Schedule` pattern). | Yes: 20 health events -> 1 pending timer. |
| R1-3 | ClassCues.lua:313 vs 315 | should | `ERR_SPELL_FAILED_SHAPESHIFT_FORM_S` is read two ways. For druids it means "can't while in X" (LEAVE FORM); for warriors the capture is shown as the stance needed. Both can't be right. If it reads "can't do that while in Battle Stance", the warrior is told "BATTLE STANCE", the stance they are already in. | Drop it from the warrior `stance` keys, or route it to a "WRONG STANCE" text without the capture. **Probe** the string. | Yes, with the real string. |
| R1-4 | ClassBuffs.lua:234-236, 248 | should (probe) | In combat, a failed or secret read keeps the last state, and with `ShouldAurasBeSecret()` nothing is read at all. Seal (`when='melee'`) and Battle Shout (`'combat'`) cue only in combat. Scenario: the seal is missing at the pull, the paladin casts one in combat, reads are restricted -> "NO SEAL" plus a pulsing edge for the whole fight. | When reads are unavailable, treat a kept `missing` as `unknown` for `melee` and `combat` groups, or mark the seal active on its own `UNIT_SPELLCAST_SUCCEEDED`. | Yes. |
| R1-5 | ClassBuffs.lua:657-690 | should | `combatFlag` is maintained only while the regen events are registered, and `Sync` never resets it (ClassCues does, line 846). Scenario: disable out of combat (flag false), enter combat, re-enable -> `InCombat()` is false all fight: "NO BLESSING" / "NO ARMOR" fire in combat and the Battle Shout cue is suppressed. | `combatFlag=nil` in `Sync`. | Yes. |
| R1-6 | WeaponEnchants.lua:436-442, 335 | should | With visibility "Needs Attention", the holder is at alpha 0 but still shown, mouse-enabled and clickable. An invisible pod swallows world clicks and applies a poison or stone when clicked, and shows a tooltip on hover. | When alpha is 0 in attention mode, also `EnableMouse(false)` on the pods (not protected), or use a state driver out of combat. | Yes. |
| R1-7 | ClassCues.lua:178-198, 294, 817 | should | `TargetHeld` runs up to 21 `GetAuraDataBySpellName` pcalls on every paint while the target targets you. That is the 4 Hz melee ticker plus every coalesced target `UNIT_HEALTH`: about 100-200 aura queries per second in combat. | Cache the result; recompute on target `UNIT_AURA` and target change (both already registered). | Optional. |
| R1-8 | ClassCues.lua:487-509, 820 | should | On every `SPELL_UPDATE_USABLE` flush, `ReactiveLive` and `CheckReactive` allocate two tables. While any reactive spell is usable (the whole Execute phase), they also walk every action button: about 120 `GetActionInfo` and `GetSpellName` calls per rage change. | Reuse module-level tables; cache button -> spell name, rebuilt on `ACTIONBAR_SLOT_CHANGED`, `ACTIONBAR_PAGE_CHANGED` and `UPDATE_BONUS_ACTIONBAR`. | No. |
| R1-9 | ClassCues.lua:807 | should | `UNIT_COMBAT('target','DODGE')` fires for anyone's attack the target dodges. Grouped Berserker warrior: the tank's dodged swings repeatedly open the window -> "Battle Stance - Overpower" when Overpower is not available to you. | Open the Overpower window only when solo (as S40 does for Defensive), or confirm with `C_Spell.IsSpellUsable` in Battle Stance. **Probe**. | Yes. |
| R1-10 | WeaponEnchants.lua:173 | nice (probe) | `ipairs` over the enchant list; Blizzard's `BuffFrame` iterates it with `pairs`. If the list is ever keyed sparsely (for example by enchant type), `ipairs` sees nothing -> the enchant reads as missing every time. | Use `pairs`. | Yes. |
| R1-11 | WeaponEnchants.lua:578-588 | nice | A 1 Hz ticker runs for the whole 30-60 minute enchant to update minute labels. | Edge timer (ClassBuffs `Schedule`). | No. |
| R1-12 | ClassBuffs.lua:695; WeaponEnchants.lua:671 | nice | Preview calls `holder:Show()`, but the state driver re-resolves visibility every 0.2 s (`SecureStateDriver` OnUpdate). With "In Combat" visibility out of combat, the preview vanishes after about 0.2 s. | Register a `show` driver for the preview, then restore it. | No. |
| R1-13 | WeaponEnchants.lua:212 | nice | Poison ranks learned at runtime are stored at required level 0, so `BestItem` picks a higher rank the player can't use yet; the click then fails. | Store `UnitLevel` as the floor, or read the required level. | Yes. |
| R1-14 | ClassCues.lua:922-929, 1091 | nice | Class-cue swatches and "Reset Class Cue Colors" don't repaint a cue already on screen. | Pass `after=function() C.Flush(true) end`. | No. |
| R1-15 | ClassBuffs.lua:394; WeaponEnchants.lua:337 | nice | Both Unlock elements use `order=622`. | Make one of them 623. | No. |
| R1-16 | ClassCues.lua:671-676 | probe | `TickHost` checks only that `ERB_PrimaryBar` exists. If that bar exists but is hidden (Ellesmere's power bar is off), the spark is parented to a hidden frame and never shows, against what the tooltip promises. | Add `bar:IsShown()` to the check. | Yes. |
| R1-17 | ClassCues.lua:386-397, 413 | probe | When range is unreadable, the opener cue never shows, and a 4 Hz poll runs for the whole stealth. | Treat an `unknown` range as in range, or stop polling. | Yes. |
| R1-18 | ClassCues.lua:639 | nice | Furor (+40 on entering Cat Form) and Relentless Strikes (+25) gains near the cadence re-anchor the tick phase. | Ignore gains in the frame of `UNIT_DISPLAYPOWER`. | No. |

## Summary (must / should)

- **Must:**
  - **R1-1:** a WeaponEnchants missing cue stays up while mounted, dead or on a taxi, because no away-state event is registered.
- **Should:**
  - **R1-2:** Slice and Dice timer pile-up on target health events.
  - **R1-3:** the shapeshift error is read two contradictory ways (warrior vs druid).
  - **R1-4:** "NO SEAL" stays up all fight when aura reads are restricted in combat (probe).
  - **R1-5:** a stale ClassBuffs combat flag after re-enabling in combat.
  - **R1-6:** invisible but clickable pods in Needs Attention mode.
  - **R1-7:** behind-indicator aura queries at high frequency.
  - **R1-8:** reactive glow allocations and full button walks per usable update.
  - **R1-9:** Overpower hint from other players' dodged attacks.

Probes to run in game: R1-3 (the stance error string), R1-4 (`C_Secrets.ShouldAurasBeSecret()` in combat), R1-9, R1-10, R1-16, R1-17.
