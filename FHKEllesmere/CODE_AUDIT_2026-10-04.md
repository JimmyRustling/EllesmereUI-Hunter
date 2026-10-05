# Published-fork code audit continuation (Codex, 2026-10-04)

Continues Claude's part 1 (PetFood/Warnings). Current live companion is unreleased **1.9.3**. This pass closes the five code-review areas named in the incoming HANDOVER; client acceptance remains open.

## Publication and recovery

Read-only GitHub checks confirmed the published heads: `hunter-addons` = `8f46b416d2eef6404f9bbfde4135ff76b3426f62`, `forever-core-main` = `af78743d77063e21aad4f8ef4f3c75a48d2aac65`, `forever-core-935-release` = `65758f9ff63c8cbbefa78e21bed9dede798fc59c`.

No push was requested or made in this continuation. Both audit parts remain local. ForeverHunterKeys remains private. Recovery snapshot: `Snapshot-20261004-pre-codex-published-audit-215952.zip` at the game root, containing the owned companion and package as received.

## Review results

| Area | Findings addressed |
|---|---|
| HunterCues | Feign/all-off ticker cleanup; pending disabled warnings; per-arrival trap expiry; unreadable absence; secondary secret returns; recycled/paged button glow visibility; native glow style refresh |
| Shared warning lane | Repeated identical repaint/layout work; immediate shared-token repaint with motion/fade behavior retained |
| LevelingQoL | Ready/open auto-loot snapshot ordering; cleared slots; stale timeout; disable cleanup; NPC close-handler order; changed fade opacity/replaced host; native mana-reveal writer/model/pet preservation; mirror font/art restoration |
| CdmLabels | Native-text snapshot; immediate clear/disable restoration; current recycled spell; blank/secret text; bounded non-recursive hooks |
| SwingIntegration additions | Higher-rank clip casts; delay/stop/failure/shared-clock refresh; replaced bar/disabled feature; unchanged Raptor action-state events; cached spark color refresh. Existing latency bounds and world/home fallback were reviewed and retained |
| Companion colors | Missing warning/pet/cue/spark/marker repaints added; tokens still mutate in place and resets retain the shipped palette |

Existing UI rows and controls were retained; no section height or setting key changed. The new sections remain routed through the companion plugin and its native DualRow builder. This is a structural review, not a visual sign-off in the client.

## Evidence

- **E1:** 51 Lua files validate as Lua 5.1/ASCII; TOC/dependencies/options/profile checks pass.
- **E2:** 3419 mocked checks: 2905 integration + 161 aspect + 147 pet + 26 probe + 56 pet food + 65 Hunter cue + 59 leveling/label checks. Baseline was 3373; 46 new regression checks.
- Installer validation and refreshed live package Check: pending final run.
- No new TOC file/default/settings key. Reload suffices for this continuation after the earlier TOC files have been loaded by a full restart.
- No third-party addon, SavedVariables, binding, GitHub or upstream writes. No CPU/FPS measurement and no E3 claim.

## Next acceptance

1. Restart the client if PetFood/HunterCues/LevelingQoL/CdmLabels were not loaded previously.
2. Disable Feign during a feign and immediately after a cast; check that no warning or ticker-driven countdown returns. Check secret/missing aura states and overlapping trap cues in gameplay.
3. Trigger Mongoose/Counterattack, change bar page/visibility and proc style, and check the glow follows the button.
4. Auto-loot with full bags; loot some slots, close the window and confirm only items actually left are named. Toggle the notice off and check it clears.
5. Close vendor/mail/trade/auction windows with bags initially open and initially closed. Native closure and the deferred close must not reopen them. Opening bags manually within the existing half-second timing heuristic still needs observation.
6. Check mana reveal with hover, pet visibility, portrait and health changes; change far-target opacity; disable the mirror skin and check the original font/art returns.
7. Set/clear a manual cooldown label, toggle macro labels, recycle an icon to a different spell and turn native keybind visibility off.
8. Cast a higher-rank Aimed/Multi-Shot, observe delay/interrupt/stop and clock updates, and change shooting/warning colors while visible.

Feign-resist detection remains an inference from public player state; without a combat-log reader it cannot distinguish every voluntary early cancel from a resisted cast. The earlier Gear/aspect/pet acceptance lists and decisions about release/main and the optional exported profile remain outstanding.

## Part 3 (Claude, 2026-10-05)

A final pass for behaviour the mocks hid. Details in the companion CHANGELOG ("Code audit, part 3").

| Area | Finding | Fix |
|---|---|---|
| CdmLabels, AspectBar | Read `FHKEllesmereNS.groups`; Forever Hunter Keys keeps its groups in `ForeverHunterKeysNS.groups`, so macro keys were never found in game | Read Forever Hunter Keys' list, falling back to the companion table |
| CdmLabels | `ns.UpdateCDMKeybinds` hook is dead (Ellesmere calls the local) | Discover through `ns.ShowCDMKeybindBadge`, once per frame for unhooked texts; also on `UPDATE_MACROS` |
| HunterCues | `PLAYER_REGEN_DISABLED` fires before lockdown, so the Pet Idle ticker never started | Combat events set the state |
| HunterCues | Trap Broken fired when the trapped target died | Quiet unless the target is alive |
| HunterCues | `UNIT_FLAGS` ran every cue | Feign Death only |
| LevelingQoL | Locked loot slots counted as left behind | Skipped |

Package Check: 0 differences after the refresh.
