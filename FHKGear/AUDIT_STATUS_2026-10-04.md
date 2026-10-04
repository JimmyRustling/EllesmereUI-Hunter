# FHK Gear audit status: where 0.3.0 stands (Claude, 2026-10-04, 15:40)

This reconciles three sources:
- the 62-finding baseline audit ([AUDIT_2026-10-04.md](AUDIT_2026-10-04.md), Codex, 13:27);
- Codex's repair ledger ([REPAIRS_2026-10-04.md](REPAIRS_2026-10-04.md));
- the live code (TOC 0.3.0, 14 Lua files, about 2,700 lines).

The baseline and ledger are unchanged. This file adds independent checks and new findings, then says what's left. Audit only: no code was changed.

## 1. Verification run

| Check | Result |
|---|---|
| `node Interface/AddOns/FHKGear/tests/run.js` | **347 checks PASS**; 14 TOC files parse as Lua 5.1, ASCII only, no OnUpdate (E1/E2) |
| Companion `node Validate.js` / `node RunIntegration.js` | 44 files PASS / **2,814 PASS** (E2) |
| Reproduction probes (scratch harness built on `tests/gear_test.lua` mocks) | 4 new defects reproduced (N01-N04, E2) |
| Ledger spot checks against the code | G01, G04, G12, G13, G14, G35, G37, G40, G43, G44, G47, G59, G60 behave as the ledger says (E1) |
| In game | **No E3 since 0.2.0.** 0.3.0 has never been loaded in the client by the player (new TOC files: full restart). |

**Ledger status:** 37 fixed, 21 mitigated, 3 open (G22 levelling simulator, G23 hit/crit/haste marginal model, G27 pet gear), 1 pending (G54 packaging). I agree with those statuses, with the exceptions below.

## 2. New findings (not in the baseline audit)

### N01. One uncertain worn item switches auto-equip off entirely (High, correctness/UX). E2
- **Where:** `Engine.lua` `E.Score` (any unknown proc rate, unparsed line or unknown effect sets `known=false`); `Equipment.lua` `E.SetupScore` (`known = known and k` over every slot); `E.BagUpgrades` (`if automatic and not baselineKnown then return {}`).
- **Problem:** "Chance on hit" procs without an explicit % in the tooltip always count as an unknown rate (`ProcRate`: `known` is true only with a player-entered PPM). Any worn item with such a proc, or any unscored line, makes the whole setup "unknown", and auto-equip returns no jobs. Gear says nothing about this.
- **Failure scenario (reproduced):** wear Fiery Blade (chance on hit) in the main hand; a better bow sits in the bags. With auto-equip ON, the bow is never equipped (`jobs(auto) = 0`). Remove the blade and the bow equips.
- **Recommendation:** make uncertainty local to the decision:
  - an automatic swap is blocked only when the candidate, or the item it replaces, is uncertain;
  - other slots use their best-known score;
  - treat a default-PPM proc as "estimated" (allowed for marking and for automation by default, with an opt-out), and keep "unknown" for genuinely unparsed effects;
  - show the blocking item in `/fhkgear status`.

### N02. One uncertain bag item makes quest-reward and loot-roll automation manual (High, correctness/UX). E2
- **Where:** `Equipment.lua` `E.BagBaseline` (`if E.Slots(job.info…) and not E.AutomationSafe(job.info) then return worn,false end`), used by `E.QuestChoice` and `E.RollChoice`.
- **Problem:** the owned-gear baseline aborts if any equippable bag item is uncertain: a proc item, an unscored line ("Equip: Increases your effective stealth level."), an unconfirmed rating, or a pending item.
- **Failure scenario (reproduced):** Shadow Boots or Rage Blade in the bags makes every quest choice "manual: Setup search incomplete". Bags almost always hold such an item while levelling, so Auto-Pick Quest Rewards rarely acts.
- **Recommendation:** drop uncertain bag items from the baseline. At worst a reward is chosen that an uncertain bag item might have beaten, which the tooltip can say. Abort only when an uncertain bag item competes for the same slot as the best reward and is within the uncertainty margin.

### N03. Spells-changed events wipe the whole item cache, even in Mark Only (Medium, performance). E2
- **Where:** `Core.lua` `ns.Refresh` registers `SPELLS_CHANGED`, `WEAPON_ENCHANT_CHANGED`, `PLAYER_TALENT_UPDATE` and others whenever `ActiveFeatures()` is true. With defaults that's always true, because the tooltip and quest borders are on. `handlers.SPELLS_CHANGED` calls `ContextChanged(true)`, which runs `Items.Invalidate()` (full wipe), clears every score cache, rebuilds options and refreshes markers.
- **Problem:** this isn't coalesced, unlike `SKILL_LINES_CHANGED`, and SPELLS_CHANGED can fire often (spellbook updates, forms, mounting, rank learning). Each event forces every item to be re-read (tooltip + stats) on the next hover or pass. That goes against the "zero cost while idle" goal (plan §4.6).
- **Failure scenario (reproduced):** 20 SPELLS_CHANGED events give 20 full wipes (`Items.version +20`, 12 cached items down to 0), and the next pass re-reads every item.
- **Recommendation:**
  - coalesce like `SKILL_LINES_CHANGED`;
  - for spells and enchants, invalidate only usability-blocked entries (`Items.InvalidateRequirements`) plus the context snapshot, and only when a learned-spell count or signature changed;
  - only rotation mode (`comparisonModel == 'rotation'`) needs spell context at all;
  - `WEAPON_ENCHANT_CHANGED` should drop only the equipped weapon entries;
  - measure SPELLS_CHANGED frequency in game with `/etrace` before and after.

### N04. An item whose stat table is nil stays "pending" forever, and wearing it disables comparisons (Medium/High, correctness). E2; client behaviour needs E3
- **Where:** `Items.lua` `Items.Read`: `if not ready or not rawReady then info.missing=true …`. `rawReady` needs `C_Item.GetItemStats` to return a table.
- **Problem:** if the client returns nil, not `{}`, for an item without structured stats (for example a Use-only trinket), the item is never cached and stays "pending". When worn, `E.Equipped` is never complete and `E.SetupScore` fails `Legal()`, so every verdict reads "Equipped comparison unavailable" and nothing is marked or equipped.
- **Failure scenario (reproduced in the mock):** a statless Use trinket reads "Tooltip or stats pending"; wearing it makes the better bow "Equipped comparison unavailable".
- **E3 check:** hover a Use-only trinket (or an item with no green stats) and run `/fhkgear item`.
- **Recommendation:** once the tooltip is complete and the name, quality and equip location are known, treat a nil stat table as `{}` (no stats), not pending.

### N05. CHANGELOG has no 0.3.0 entry (Low, docs). E1
The TOC and `ns.VERSION` say 0.3.0 and the ledger's G56 says "new changelog entry", but `CHANGELOG.md` stops at 0.2.1. The 0.3.0 work (seven new files, the transaction model, the profile bridge, the Model page, marker styles) is only recorded in `REPAIRS_2026-10-04.md`. That breaks the workspace rule that every change goes in the CHANGELOG with an evidence level.

### N06. Search pre-build indexes every label on every page (Low, UX). E1
- **Where:** `Options.lua` `buildPage`, the `IsSearchPrebuild()` branch.
- **Problem:** all 32 labels are recorded on each of the 5 pages, so an Ellesmere search for "Levelling Mode" lists five results and four of them open the wrong page.
- **Recommendation:** one static label list per page.

### N07. Hot paths still allocate per call (Low, performance). E1
- `Items.Read` cache hits with a bag position call `C_Container.GetContainerItemInfo` (a new table per call) to refresh binding.
- `E.Verdict` recomputes the base `SetupScore` and copies the 21-slot set for each candidate slot, on every tooltip hover and for every bag item in a pass.
- `RefreshMarkers` runs `BagUpgrades` and then `Verdict` again for every bag item.

These are fine at levelling bag sizes but are the remaining garbage sources. Recommendation: cache the base setup score per (equipped version, weights version); refresh binding only on `BAG_UPDATE`; let `RefreshMarkers` reuse the `BagUpgrades` results.

### N08. Statements to correct in the ledger (Low, docs). E1
- **G36** says disabled mode removes active gear events. With defaults (tooltip and quest borders on), seven context events stay registered (see N03). Accurate only when every feature is off.
- **G52** "fixed": the mocks still return a table from `GetItemStats` for every item (N04) and fire no SPELLS_CHANGED bursts (N03). Keep it "mitigated" until those fixtures exist.

## 3. What's left, in priority order

1. **Fix N01 and N02.** Without them, the automatic features the player asked for rarely act once the character wears or carries any proc or unusual item.
2. **Fix N03** (performance regression vs the 0.2.0 event model) **and N04** (after a quick E3 check of a statless item).
3. **First 0.3.0 session in game** (full restart): the ledger's 21-step acceptance checklist (`REPAIRS_2026-10-04.md`, "In-game acceptance checklist"). Highest value first:
   - steps 1-2 (status, context, errors; all five pages render);
   - step 5 (crit/hit units);
   - step 6 (proc items);
   - step 4 (rarity cap, auto-equip);
   - step 11 (quest choice);
   - step 13 (markers in Ellesmere bags).
4. **Write the 0.3.0 CHANGELOG entry** (N05) and fix the search labels (N06).
5. **G54 packaging:**
   - generate the `FHK-Gear-Package` payload (only `Apply.ps1` and `Refresh.js` exist; there are no files yet);
   - validate a clean temporary install;
   - Check before Apply.
6. **Model work the ledger marks open or mitigated:**
   - Hunter ranged weapon speed and AP normalisation (G24);
   - weapon skill (G25);
   - pet gear (G27);
   - more learned-ability records beyond Aimed Shot, Backstab and Frostbolt (G18);
   - reward-plus-owned-partner weapon comparison (G05).
   Don't guess server constants; label estimates.
7. **N07 allocations**, after in-game CPU measurements show they matter (ledger step 21).

## 4. Beast data: ForeverDB replaces beastmaster.io (player, 2026-10-04)

The player found [foreverdb.net/pets](https://foreverdb.net/pets). What it offers, checked 2026-10-04:
- **Per family:** taught ability, diet and level range, for 20 families including the new Core Hound and Fox.
- **Per beast:** attack speed for fast rares.
- **Forever changes:** e.g. "Tame Beast no longer works on beasts higher than the Hunter's level", Furious Howl -40%, Aggressive mode restored.

Sources, per its About page:
- families, abilities, diets and speeds come from the Forever client;
- which creatures are tameable comes from the open **CMaNGOS classic-db (GPL-3.0)**, labelled "Classic data" until seen in Forever.

**Reuse:** ForeverDB states **no reuse licence** for its compiled data, and its robots.txt disallows `/api`. So, as with beastmaster.io: use it as the reference, don't bulk-copy it.

**Recommended design for the beast tooltip** (update to merge audit §7 and plan §1C): read everything about the hovered beast **live from the client**. It's licence-free and always matches the server.
- `UnitCreatureType` = Beast and `UnitCreatureFamily` set → it's a tameable family.
- `UnitLevel` vs your level → "too high level" (Forever's rule).
- `UnitAttackSpeed('mouseover')` → its real swing time (the documented `UnitAttackSpeed` exists in the Forever UI source).
- `UnitClassification` → elite or rare.

Add a small table of our own, family → taught ability and diet (about 20 game facts, cited to ForeverDB as the reference). Rare-pet looks and spawn locations are the only things that would need ForeverDB's compiled data; link to its page instead, or ask the author (Contact page) before bundling anything.

## 5. Fix status (0.3.1, Claude, 2026-10-04 16:05)
| ID | Status | Evidence |
|---|---|---|
| N01 | **Fixed:** uncertainty is local (`Engine.TouchedKnown`); default PPM counts as an estimate; new Model toggle "Automate With Proc Estimates" | E2: regression `N01` (worn proc weapon, bow upgrade equips; uncertain worn boots stay manual but marked) |
| N02 | **Fixed:** baseline leaves out uncertain/pending bag items; only the chosen reward's comparison must be certain | E2: regression `N02` (quest picks the bow with uncertain items in bags; manual with a reason when the reward replaces an unpriced item) |
| N03 | **Fixed:** coalesced spell/talent events keep the item cache; weapon enchants refresh only the worn comparison | E2: regression `N03` (20 events: cache kept, zero re-reads) |
| N04 | **Fixed in code, E3 owed:** complete tooltip + nil stats = no stats | E2: regression `N04`; in game: `/fhkgear item` on a Use-only trinket |
| N05 | **Fixed:** 0.3.0 and 0.3.1 CHANGELOG entries | E1 |
| N06 | **Fixed:** per-page search labels | E2: regression `N06` |
| N07 | Open (low): measure CPU in game first | - |
| N08 | Ledger wording: G36 and G52 should read "mitigated" | the ledger stays Codex's record |

| G54 | **Fixed (E2):** payload generated; live Check 0 changes; clean temp-root Check, Apply and Check pass (20 files) | `FHK-Gear-Package` |

Gear suite: **362 checks PASS**. Next: the in-game session (ledger checklist, plus the N04 check), then the open model work (G05, G18, G24-G27).

## 6. v1.0 readiness (Claude, 2026-10-04, after 0.4.0)

### Done: code, E1/E2
- **Pages:** all five, built with Ellesmere widgets only:
  - house conventions: Title Case, one-sentence tooltips, function `disabled` gates with `disabledTooltip`, section spacers, sliders, inline swatches and cog;
  - a live marker preview and a colour status line.
- **Automation:** every action is a separate toggle. Levelling Mode, a Grey-Legendary cap in Blizzard colours, the BoE pair (equip / auto-confirm), Need and Greed policies and roll confirmation.
- **Markers:** tooltip, quest, bag (Blizzard and Ellesmere bags), roll and character marks, with style, colour, size, opacity and placement.
- **Rules:** slot locks, Never Equip (item or variant), AutoGear lock import.
- **Profiles:** follow the Ellesmere profile through the companion; weights and rules are opt-ins.
- **Packaging:** `FHK-Gear-Package` refreshed for 0.4.0; live Check shows 0 changes.
- **Tests:** 381 Gear checks; companion 2,814.

### Blocking 1.0: only the player can do these
1. **First in-game session on 0.4.0** (full restart, because the TOC changed since 0.2.0). Work through the ledger's 21-step checklist (`REPAIRS_2026-10-04.md`), plus:
   - **UI:** open all five pages. Toggle Auto-Roll off and check the Loot Rolls rows show greyed out, not an empty page (this was the 0.3.x crash). Check the swatches, the placement cog and that the Markers preview updates live. Toggle Auto-Equip and check the status line and the greyed BoE pair.
   - **Ellesmere bags:** turn on Bag Upgrade Icons, open the Ellesmere bags and check upgrades are marked **without hovering**.
   - **N04:** run `/fhkgear item` on a Use-only trinket.
   - Report anything odd. `/fhkgear errors` gives copyable diagnostics.
2. **Fix whatever that session turns up**, then set the version to 1.0.0, refresh the package and run Check.

### Proposed for after 1.0 (1.1+), not blocking
- **Model depth:**
  - G22 levelling simulator;
  - G23 state-dependent hit/crit/haste;
  - G18 more learned abilities;
  - G24 Hunter ranged speed normalisation;
  - G25 weapon skill;
  - G27 pet gear;
  - G05 reward-plus-owned-partner comparison.
  Today these are labelled estimates, or the case stays manual, so they're safe to ship.
- **N07 allocations:** only if in-game CPU (checklist step 21) shows a cost.
- **Forum §9.6:** show who rolled Need/Greed on the roll frame (needs a `C_LootHistory` probe).
- **Ellesmere bank** marks (bank items aren't scored today).

## 7. Hunter section (Claude, 2026-10-04, 0.5.0)

The player asked why deeper Hunter scoring should wait for 1.1. It shouldn't: the inputs are on the character sheet. 0.5.0 builds it; CHANGELOG 0.5.0 has the detail.
- **Done (E2):**
  - the live Hunter model (G23 hit/crit/haste by state, G24 ranged speed through Aimed/Multi-Shot, G25 weapon skill per weapon type, G27 the pet's share of ranged AP and Stamina, G18 Hunter abilities from live descriptions);
  - the ammo-type check;
  - bag slots by client ID and the reagent bag;
  - bag edge cases.
- **Needs E3 (one command):** `/fhkgear hunter` in game, paste the report. It confirms:
  - the stat-conversion functions answer;
  - the talent query shape works (or falls back);
  - ability descriptions parse;
  - the bag inventory IDs and reagent-bag count;
  - the client's Hunter tooltip strings (e.g. the hit-cap text).

### Hunter feature completeness: what's still not built
1. ~~Ammo slot~~ **done (0.5.0):** Auto-Equip Better Ammo, including a new tier on level-up. E3: the first ammo equip.
2. **Mana:** the model assumes unlimited mana. Intellect and Mp5 keep their small default weights; Careful Aim's AP from Intellect is counted.
3. **Talent ranks** can't be read until the talent query shape is confirmed (the probe). Until then a multi-rank talent reads as rank 1 when its spell is known, and you can set ranks on the Model page.
4. **Base pet damage** and pet abilities aren't modelled. Gear can't change them; only the 22 % ranged-AP share is.
5. **Armour penetration and expertise** (the Forever sheet has them) keep their static weights.
6. **Who rolled Need/Greed** (forum §9.6) and **bank** marks: unchanged.


## 8. v1.0 readiness audit (Claude, 2026-10-04, 0.5.0)

**Method:**
- a read-through of every path the Hunter model touches (weights, scoring, setup search, actions, events, options, profiles);
- stress tests in `tests/regression.lua` ("v1.0 audit stress tests" and the ammo and bag blocks);
- call-count performance checks.

| Area | Finding | Status |
|---|---|---|
| Interaction: pet | Detect followed `UnitExists('pet')`, so a dead or despawned pet shifted the weights and could swap gear | **Fixed:** the pet always counts unless you have Lone Wolf |
| Interaction: ammo | Buying bullets didn't refresh weapon values; a gun stayed "no ammo" | **Fixed:** bag events refresh the model when model inputs change |
| Interaction: skill | Skill-ups didn't refresh values | **Fixed:** `SKILL_LINES_CHANGED` queues a model refresh |
| Interaction: hit | Wearing a hit item would lower its own value (swap loop risk) | Fixed in 0.5.0 (gear-free hit baseline); stress test shows no swap loop |
| Interaction: bags | Quiver replaced by a bigger bag; herb bag over a general bag; quiver haste stacking; Classic bag IDs on a retail-offset client; reagent slot | **Fixed** (0.5.0), all tested |
| Correctness | No skill API would make every weapon unknown (automation off) | **Fixed:** assumed capped and reported |
| Performance | A slider drag ran a full change on every tick | **Fixed:** settles once |
| Performance | The model re-read bags (ammo), worn weapons and skill lines per score | **Fixed:** cached per refresh |
| Performance | Hovers | 200 warm hovers: 0 item reads, 0 skill reads (E2) |
| Robustness | Queued-timer flags could stick if a timer was lost | **Fixed:** they expire |
| In game | **AutoGear is enabled** on the player's Hunter, so Gear has only ever marked; the "upgrade found" pop-up is AutoGear's | Player: Disable AutoGear (Automation page) before testing |

**Verdict:** code-complete for Hunters (E2, 449 checks).
- **What's left for 1.0 is in game:** Disable AutoGear, full restart, `/fhkgear hunter` (paste the report), the ledger checklist, the first ammo equip and the first bag equip (real inventory IDs).
- **After 1.0:**
  - mana modelling;
  - talent ranks once the query shape is known;
  - base pet damage;
  - armour penetration / expertise;
  - the loot-roll Need/Greed names;
  - the forum QoL item "upgrade left in the loot window" (plan §9).
