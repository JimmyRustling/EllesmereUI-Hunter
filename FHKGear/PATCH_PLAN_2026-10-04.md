# FHK Gear audit repair plan

2026-10-04. Authorized by the player: plan and execute the audit repairs.

Live owned addon files are the source of truth. Do not edit vendor addons or SavedVariables. Keep the original audit unchanged as the baseline. Record implementation and E1/E2 evidence in a separate repair ledger and changelogs. E3 remains a player check.

## Execution order

1. Snapshot the owned addon/package, preserve the passing baseline, then add transaction and data fixtures before changing their behaviour.
2. Item facts and numeric safety: public finite-value guards; complete tooltip/stat readiness; exact-source reconciliation; typed effects; category uniqueness; bounded targeted item requests. Unknown data must not become a zero-score upgrade.
3. Safe actions: matching bind ownership; inventory acknowledgement; source identity checks; bounded failures with eligible fallbacks; cancellation/generation guards for quest and roll callbacks; allowed roll choices; combat/cursor/cap guards at every action.
4. Comparison: one legal worn/bag baseline, independent quest rewards, duplicate physical item handling and complete ordered MH/OH/2H alternatives. Rank candidates once, then compare legal pairs; no permanent scan.
5. Model/context: learned spells/ranks, explicit damage and recovery objectives, weapon speed/average damage, verified spell-slot constraints, school/proc participation and target-conditioned effects. Preserve approximate stat scoring and expose unknown assumptions. Do not invent server rating conversions, proc rates or nine-class rotations.
6. Performance/lifecycle: coalesced dirty flags, relevant skill/spell/spec invalidation, per-pass provider snapshot, bounded pending/retry maps, teardown on disable and no work from hidden search prebuild.
7. UI/coverage: explain blocked/pending/approximate states; fresh cached pages; per-character AutoGear disable; safe owned marker registries; supported native bag/roll/character overlays; direct lock/ignore controls; bag/quiver candidates with safe capacity rules.
8. Integration/distribution: lossless native settings/weight export, conditional external exporter, profile bridge through owned/public APIs, companion Gear routing, separate licensed package and canonical licence text. No upstream action.
9. Verify focused regression fixtures, all existing meaningful checks, companion/package checks where affected; inspect changes; update README/CHANGELOG/HANDOVER and the repair ledger. Finish with exact live-game acceptance steps.

## Maintainability and scale

- Item parsing owns facts, never weights or actions. Cache immutable complete facts by full item identity; refresh location/binding separately.
- Scoring returns value plus confidence/reason. A missing/secret/non-finite value is unknown, not zero. Approximate score units never claim DPS.
- Equipment comparisons own legality and full configurations. Action code consumes a checked plan and rechecks each source/target at execution.
- One event scheduler coalesces activity. Store bounded per-ID waiters and generation tokens; stop timers when work is cancelled or reaches a deadline.
- Ability records are small, source-labelled and class-scoped. Read learned-spell context only on login/level/spell/talent changes, never per hover. Unknown APIs fall back to manual spec and approximate scoring.
- Public integration functions carry validation/versioning. No copying vendor private state or defining Pawn globals for bag icons.
- Each audit ID is tracked as fixed, mitigated, pending E3, or deferred with a concrete reason. A code fix does not close an E3 check.

## Validation gates

- Start: 193 mocked checks plus seven Lua 5.1/ASCII/no-OnUpdate checks pass.
- Preserve grey upgrades, rarity colours/limits, manual non-gear quest choices, quantity-adjusted vendor fallback, 59/60 Levelling Mode and AutoGear coexistence.
- Add fixtures for audit failures, including full bags, duplicate copies, category limits, failed pickup, unrelated binds, cancelled callbacks, bad numbers, provider failure, cache invalidation and settings round trips.
- Measure warm tooltip/item reads, repeated skill events, provider calls and bounded pending work under mocks. Report calls, not FPS.
- Packaging uses Check before any Apply. Generate package assets from live source; validate a clean temporary install without deploying vendor files.

## Evidence limits

The player must verify real tooltip completeness, rating units, secret values, action permissions, bind event payloads, rotation timing, spec detection, UI geometry and actual addon CPU. Unknown mechanics will remain labelled and will not silently decide automatic actions.
