# Changelog: FHK Ellesmere Companion / Forever UI refinements

Every change gets an entry, using the template and evidence levels in [DEVELOPMENT.md](DEVELOPMENT.md#proof-of-updates).
E1 = static checks, E2 = mocked integration, E3 = seen working in game. Only E3 means "works".

## 1.9.5 test build (class kits for every class, Vendor Restock, scenario and adversarial reviews; FHK Gear 0.5.3; new TOC files: full restart)

### Suite review: the companion and Gear inside EllesmereUI main 9.3.9 (Claude + three read-only reviewers; fixes by agents A, F, G and the lead; 2026-10-06)
- **Reports:** [SUITE_REVIEW_CORE_2026-10-06.md](SUITE_REVIEW_CORE_2026-10-06.md), [SUITE_REVIEW_FRAMES_2026-10-06.md](SUITE_REVIEW_FRAMES_2026-10-06.md), [SUITE_REVIEW_QOL_2026-10-06.md](SUITE_REVIEW_QOL_2026-10-06.md).
  - Ellesmere main is staged at `.dev/staged-main-939`.
  - 49 findings, 3 must. E1 review; fixes E2.
- **APIs:** no core API we use changed on main. Every hooked internal still exists. Nothing taints.
- **Must, fixed:**
  - **SQ-1 (F):** an Ellesmere junk sale's bag update no longer ends our restock purchase early. A purchase settles only when stock rose; a dropped buy is undone and retried once.
  - **SC-1 (lead):** restore snapshots (bag/menu visibility, theme, class HUD, combat layout) belong to one profile store. Ellesmere's Reset ALL or a same-name import can never restore an old snapshot into a fresh profile.
  - **SF-1 (G):** our bar colouring never writes a fill Ellesmere owns. That covers its gradients on Unit Frames, Resource Bars and the swing row, Dynamic Health Color, thresholds and bands. Our hook re-attaches when Ellesmere's Fill Opacity clears it (SF-2).
- **Should, fixed:**
  - **SQ-2, SQ-3 (F):** a junk sale no longer uses up our retry. Restock never buys an item Ellesmere Bags marks as junk (`EUI_CategoryManager:IsJunk`).
  - **SQ-6 (F, probe):** the default warning lanes clear Ellesmere's buff-reminder icons.
  - **SQ-7 (A):** "Leave Raid Buffs To Ellesmere" (on). In instances, Ellesmere's own raid-buff reminder speaks for Fortitude, Arcane Intellect, Mark of the Wild and Battle Shout.
  - **SQ-4 (lead):** a one-choice quest is left to Ellesmere's Quest Tracker auto turn-in when that is on.
  - **SQ-5 (lead):** Auto Train never makes a second pick of a lone trainer option.
  - **SQ-14 (lead):** Class Supplies reads the vendor list once per visit.
  - **SC-3 (lead and G):** our movers are filed under FHKEllesmere, never inside a suite module's layout export.
  - **SC-4 (lead):** Class HUD shortcuts grey out when their module is not loaded.
  - **SC-5 (lead):** Gear search results land on their real section; Hunter Model labels are indexed for hunters only.
  - **SC-6 (lead):** two keys added to the Resets; a validator now checks that every profile key has a Reset.
  - **SC-7 (lead):** a profile switched in combat resyncs after combat.
- **Frames (G):**
  - **SF-3, SF-6:** our health ramp and neutral colour step aside for Ellesmere's own options.
  - **SF-5:** the gold aggro edge and range name colour step aside for Ellesmere's threat border and name colour. Enemy health % text is written only on change and keeps Ellesmere's colour outside dark mode.
  - **SF-9:** the range text keeps its X/Y offsets.
  - **SF-11, cost:**
    - one plate pass instead of two;
    - range readings reused for 0.3 s;
    - each sweep visits the target plus 8 plates in turn, and target, threat and faction events repaint their plate at once;
    - writes happen on change only.
    - Mocked 25-plate pull: 15 to 8 Unit API calls per plate, and 9 plates per sweep instead of 25.
  - **SC-2:** our resource text pairs no longer live in Ellesmere's Unit Frames profile (a blank slot for anyone without the companion). Its profile keeps native keys; the pairs live in `ufTextVariants`, migrated automatically, and are set under Unit Frames > RESOURCE TEXT PAIRS.
- **Defaults changed on published installs only** (CLAUDE.md "Ship features, not personal setup"; the owner's install is unchanged and saved choices are kept):
  - Nameplate Opacity Priority: off.
  - Instant Health: off, so Ellesmere's Smooth Bars decides.
  - The combat icon keeps Ellesmere's style (no white block).
  - No edge badges.
  - The pet happiness square is off, so Ellesmere's face shows.
- **All installs:** no neutral-to-red repaint on nameplates.
- **Probes:**
  - SF-12: does Forever fire its own Overpower or Mongoose glow?
  - SF-13, SF-14: the pet-target secure button anchor, and child frames created on secure frames in combat.
  - ModernChrome micro-button re-parenting.
- **Tests (E2):**
  - Validate 2,964 (main 2,962).
  - All element suites 9,976, including the new SuiteFramesTests (64).
  - Standalone on all nine classes, live and on Ellesmere main.
  - FHK Gear 710.
  - `Apply.ps1 -Mode Check`: 0 changes.

### Test harness: a failing suite now fails the run (Claude, 2026-10-06)
- **Found during the suite review:** the Lua runner (fengari-node-cli) exits 0 even after a Lua error.
  - **RunIntegration** only required the PASS lines of its first six element suites, so a failure in any later suite would pass: class buffs, weapon enchants, class supplies, class cues, new spells, restock, customisability.
  - **RunStandalone** trusted the exit status alone.
- **Fix:**
  - HunterElementTests prints a final "PASS: all element suites" line, which RunIntegration requires.
  - Each standalone run must print its own PASS line.
  - Any Lua stack trace fails both runners.
  - RunThemeChecks and the FHK Gear runner already required a final PASS line.
- **Verified:** a planted failure now exits 1, and the clean tree exits 0. Earlier results in this changelog came from runs whose output was checked for errors by hand, so they stand.

### Vendor Restock categories and packaging (Claude + build agent R; 2026-10-06)
- **Restock.lua** (agent R) adds four categories to the Vendor Restock engine, each off by default:
  - **Food** (all classes) and **Drink** (mana users), matched by the item's Food or Drink spell, with tiers 1-55.
    - Bridge before a better tier unlocks.
    - Use Up Old Stock.
    - Conjured food and water count.
    - Mages are paused once they conjure, unless Buy Anyway is on.
  - **Class Reagents**, up to the same Keep and Warn Below numbers as Class Supplies. Thieves' Tools is bought once.
  - **Pet Food**, moved from PetFood.lua with its settings migrated:
    - the player's food is reserved, so pets never eat it;
    - a diet cache per pet family, so it works with the pet dismissed.
- The budget rows (Keep At Least, Max Spend Per Visit, Leave Free Bag Slots) are shared by every category. Warnings > VENDOR RESTOCK now shows for every class, and every class page has a Vendor Restock group.
- **Versions:** companion 1.9.5, FHK Gear 0.5.3.
- **Package:** `dist/ForeverCompanion-1.9.5_FHKGear-0.5.3_test.zip` (101 files).
  - Clean-room test: only EllesmereUI plus the unzipped folders; standalone on all nine classes and Gear 703 pass.
  - Staged Ellesmere 9.3.8 passes.
  - `Apply.ps1 -Mode Check`: 0 changes.
- **Tests (E2):**
  - restock categories 160, restock and ammo 120, pet food 98, class supplies 215;
  - every suite in `npm test` passes.
- **E3 owed:** CLASS_KITS_PROBES.md. Not pushed.
- **Ellesmere main (9.3.9, commit 14245494, 2026-10-06, untagged):** staged in `.dev/staged-main-939` with `git archive origin/main`.
  - Validate, integration (every suite), standalone on all nine classes and the theme checks all pass (E2).
  - The 43 upstream commits since 9.3.8 are mostly additive:
    - core: Name Format helpers, search synonyms, a bags profile hook;
    - Raid Frames and Quickdraw files split up;
    - Bags Junk Marker, Nameplates debuff colouring, locales;
    - Unit Frames combo-point arc internals, which the companion never calls.
  - None of them change the plugin, options or row-tool APIs the companion uses.

### Feature, customisability and Forever API review, plus the first builds from it (Claude, 2026-10-06)
- **Why:** player: "did we also review gaps in feature comprehension, function, customisability, option toggles and settings ... every need/use case ... with a special focus on wow forever hunters ... everything uses the wow forever api". The player also asked for:
  - a pet summon bar;
  - a Hunter tab;
  - per-bracket range options;
  - warning and cue text styling and placement;
  - auto train;
  - a talent planner;
  - class kits for other classes.
- **Reviews:** five parallel read-only agents (use cases, customisability, API audit, summons, Gear), then three class-kit agents. Records:
  - [FEATURE_REVIEW_2026-10-06.md](FEATURE_REVIEW_2026-10-06.md): every gap with its status;
  - [CLASS_KITS_2026-10-06.md](CLASS_KITS_2026-10-06.md): per-class plan, shared engines and probes.
- **Forever API bugs fixed:**
  - Auto-Buy Pet Food never bought anything: the merchant data now comes from `C_MerchantFrame`.
  - The Unspent Talent warning could never fire (boolean API).
  - The melee attack cue never lit (`C_Spell.IsCurrentSpell`).
  - Talent ranks now come from Forever's Traits tree instead of always reading rank 1.
  - Skill-line count, macro limits and the Reagent enum.
- **New, all off by default:**
  - **Hunter hub:** a Hunter page with the features' own rows and links to their sections, plus the Recommended set.
  - **Range brackets:** per-bracket show, text, label, pulse and sound, with presets.
  - **Warning lanes:** Unlock Mode movers, horizontal offset, and Warning Text Style (size and outline).
  - **Pets And Summons bar:** hunter pet controls and Summon Hawk counter; warlock demons.
  - **Auto Train:** any class.
  - **Talent Planner:** `/fhktalentplan`, Forever's own tree; picks stamped by level; learning is opt-in.
- **Fixes:**
  - The Growl reminder now waits for a dungeon or a tank.
  - Wording fixes: Range Indicator Shape / Texture, Restart Bow After Melee, Show Melee Ready Ring, the pet frame hint, and no Reset on the frame range bar.
- **New TOC files:** `SummonBar.lua`, `AutoTrain.lua`, `TalentPlanner.lua`. A **full client restart** is needed, not `/reload`.
- **Tests:** E2 only.
  - Integration 2935, plus 23 summon, 13 auto train and 17 talent planner checks.
  - Pet food 87, hunter cues 69.
  - Standalone: 516 option rows on both cores.
  - Ellesmere 9.3.8 staged suites pass.
  - Gear 505.
- **E3 owed:** the probes in both docs, especially talent learning, weapon enchants, error types and aura secrecy. Not pushed.

### Options follow the logged-in class (Claude, 2026-10-06)
- **Why:** player: "the class hub detects what class the players logged into? to hide irrelevant options from their class?"
- **Class page:** the hub page is named after the character's class (Hunter, Mage, Warlock...). Each class lists its own groups, then the shared Training And Talents and Alerts groups. The hunter page keeps the Recommended set.
- **Hidden for other classes:**
  - Hunter only: Aspects, Pet Food, Hunter Cues, Hunter Range And Corpses, Auto Attack Indicators, Hunter Timing Compatibility, and the pet happiness rows.
  - Hunter and warlock only: Pet Auras And Target, Pets And Summons, Pet Combat Icon, and the cues section (named Pet Cues for warlocks). Player: "warlocks have pets so some options are applicable".
  - Other classes see Warnings and Cue Colors instead of Hunter Warnings and Hunter Colors.
  - If the class can't be read, every section stays.
- **In progress (agent F):** warlock pet behaviour behind those rows: Pet Auras / Target, Missing / Dead Pet with Demonic Sacrifice awareness, Pet On Passive, Pet Idle; hunter-only rows inside Warnings hidden for other classes.
- **Tests (E2):** standalone runs as Mage, Warlock and Rogue check the class page, that warlocks keep the pet sections, and that no hunter or pet section leaks to other classes. Rows: Hunter 516, Mage 294, Warlock 339, Rogue 294.

### Adversarial review, round 2: the class kits (Claude + three read-only reviewers; fixes by agents A, B, D, E, F and the lead; 2026-10-06)
- **Reports:** [ADVERSARIAL_REVIEW_2_CLASS_MODULES.md](ADVERSARIAL_REVIEW_2_CLASS_MODULES.md), [ADVERSARIAL_REVIEW_2_WARNINGS_TRAINING.md](ADVERSARIAL_REVIEW_2_WARNINGS_TRAINING.md), [ADVERSARIAL_REVIEW_2_OPTIONS_GEAR.md](ADVERSARIAL_REVIEW_2_OPTIONS_GEAR.md).
  - 53 findings: 1 must, 25 should, the rest nice or probe.
  - No Lua errors, taint or secret-value comparisons were found.
- **Must (R1-1, B):** weapon enchant cues re-check on mount, taxi, death and vehicle changes. "NO POISON" no longer sticks while mounted or dead.
- **Performance:**
  - **R1-2:** Slice and Dice keeps one timer.
  - **R1-7:** the behind indicator caches its stun check.
  - **R1-8:** reactive glows keep a spell-to-button map and allocate nothing per update.
  - **R2-1:** the ammo total is rescanned only on bag changes.
  - **R2-11:** pet and aura events are registered for player and pet only.
  - **R2-12:** the Talent Planner registers nothing while unused and reads nothing without a point.
- **Behaviour:**
  - **R1-4 (A):** a seal cast counts while auras are unreadable, so NO SEAL does not stick.
  - **R1-5 (A):** stale combat flag after re-enabling.
  - **R1-6 (B):** hidden weapon pods take no clicks.
  - **R1-9 (D):** the Overpower hint only while you auto-attack.
  - **R1-3, R1-16, R1-17 (D):** the stance and form error by class; the tick spark falls back to its own bar; the opener poll stops on unreadable range.
  - **R2-2 (F):** a critical row never sticks in the wrong lane.
  - **R2-5 (F):** Demonic Sacrifice by spell ID (18789-18792).
  - **R2-8, R2-9 (F):** ammo and pet cues re-check away changes; a profile switch re-applies the error line and filter.
  - **R2-13 (E):** no Auto Train hint at a weapon master.
- **Lead, Auto Train:**
  - **R2-3:** the class filter applies only at a weapon master, so Dual Wield, Mail and Pick Lock still train.
  - **R2-4:** never learns a new profession by itself.
  - **R2-14:** client names.
  - **R2-16:** NaN gold floor.
  - **R2-20:** poison tiers ordered as upgrades.
- **Lead, Talent Planner:**
  - **R2-6:** commits through C_ClassTalents, checks the result and rolls back on failure; never commits picks the player staged.
  - **R2-7:** never buys the same talent twice when activeRank lags.
  - **R2-19:** the paused message resets on plan edits.
- **Lead, options:**
  - **R3-1:** Turn On Recommended Hunter Set remembers each setting, and Undo restores exactly those. It no longer forces off shared features that were already on.
  - **R3-2:** Cue Colors shows the Auto Shot swatches to hunters only, and its Reset clears only its own colors.
  - **Nice:** `cdmLabels` added to the Cooldown Manager reset list.
- **Lead, FHK Gear:**
  - **R3-3:** automation and its confirmations stay with the character; an imported profile never turns on another player's Auto-Roll or Need.
  - **R3-4:** on a loot roll, a Bind on Pickup item is not "yours" yet, so the rarity cap holds.
  - **R3-5:** non-gear you cannot use is always your roll.
- **Rejected, R2-10:** a module sound of None keeps the lane's default sound by design. Per-warning overrides can silence one cue.
- **Test harness:** standalone runs use a runner file per process, so parallel runs never overwrite each other.
- **Tests (E2):** class buffs 192, weapon enchants 189, class cues 266, pets 349, new spell alerts 7,123, auto train 23, talent planner 28, FHK Gear 703.
- **Probes added:** CLASS_KITS_PROBES.md.

### Scenario review: what a real player would find silly (Claude + review agent; fixes by agents A, B, D, E, F and the lead; 2026-10-06)
- **Why:** player: "things like this we really need to scrutinise when we're developing here".
- **Review:** [SCENARIO_REVIEW_2026-10-06.md](SCENARIO_REVIEW_2026-10-06.md). It walked every feature for 9 classes, at levels 1-60, in 14 situations. 52 findings (17 must), E1.
- **Shared fixes:**
  - **S2:** `NS.EllesmereAway(kind)` in Bootstrap: no reminders while dead, on a taxi or in a vehicle, and no buff or made-item reminders while mounted. All Forever APIs were checked in the docs.
  - **S1:** a cue's own sound now replaces the lane sound instead of playing on top of it. `ShowEllesmereWarning` takes a 6th argument; a module set to None keeps the lane's sound.
- **Class Supplies (lead):**
  - **S22:** a per-item Warn Below (four Ankhs are plenty; ten Symbols of Kings are not).
  - **S23:** Smart warnings name a reagent at a vendor only when that vendor sells it ("Buy Flash Powder here"); entering rest shows them for 10 s.
  - **S24:** no shards gives one line, "No Soul Shards (Healthstone, Soulstone)".
  - **S25:** the away rule applies.
  - **S26, S27:** feathers, Rune of Portals, Symbol of Divinity and Thieves' Tools are off by default.
- **Auto Train (lead):**
  - **S46:** at a weapon master nothing is bought unless Weapon Masters Too is on. The class's spell list (ClassTrainingData) tells a class trainer from a weapon master.
  - **S47:** upgrades of spells you know are trained before new spells.
- **Others (lead):**
  - **S48:** the talent plan says why it paused while points wait.
  - **S49:** no Cheetah advice while swimming.
  - **S50:** the gathering reminder follows the away rule.
  - **S51:** Infernal and Ritual of Doom dim without their reagent.
- **Class Buffs (A):**
  - **S31:** Shadowform out of combat only, with a 10 s grace.
  - **S32:** Quiet While Resting (default on).
  - **S33:** a 1.6 s seal grace after a drop or a Judgement, non-critical by default.
  - **S34:** shields out of combat, Low off.
  - **S35:** Thorns off.
- **Class Cues (D):**
  - **S40:** never "leave Defensive Stance" hints while grouped or in an instance.
  - **S41:** the Revenge hint only after Defensive Stance was used in the last 5 min.
  - **S42:** Slice and Dice at 2+ points, skipped under 35% target health.
  - **S43:** the opener cue only within 10 yd.
- **New Spell Alerts (E):**
  - **S44:** mage teleports and portals are counted at the portal trainer, not the class trainer.
  - **S45:** at a trainer, chat says how many you can afford.
- **FHK Gear (lead):** non-gear loot is your roll by default, with Player Roll / Greed / Need up to a rarity. Bind on Equip Up To. Mounts, pets, recipes, quest items and keys are always your roll.
- **Weapon Enchants (B):**
  - **S36:** missing and none-in-bags merge into one line; none-in-bags shows only when resting or at a vendor.
  - **S37:** expiring at min(setting, 20% of the enchant's duration).
  - **S38:** for other classes the master toggle is the stone and oil reminder.
  - **S39:** away rule.
- **Hunter and warlock pets, warnings, ammo (F):**
  - **Pet On Passive** (hunter, warlock).
  - **Missing / Dead Pet:**
    - an out-of-combat mode (3 s settle);
    - I Play Without A Pet, plus Lone Wolf;
    - warlock Summon Demon, quiet under Demonic Sacrifice.
  - **Health Funnel Reminder** (no range read: unverified).
  - **Pet Level** as a 10 s notice.
  - **Not Shooting** cue.
  - **Per-warning lane and sound overrides** (Automatic / Top Lane / Above Character), using Ellesmere's alert sound catalogue.
  - **Previews:** the combat lane gets one.
  - **Fonts:** warning text uses Ellesmere's module font with its shadow.
  - **Ammo warnings:**
    - hunter only;
    - a separate off-by-default option for warriors and rogues;
    - the count totals fitting ammo ("Low Sharp Arrow (40): 1000 More In Bags").
  - **Hunter's Mark:** a partner's Mark counts.
  - **Pet Idle:** quiet on Passive or while the target is held.
  - **Pet element colours** gained swatches, and warlocks get Pet Auras / Pet Target.
- **Vendor Restock engine + Auto-Buy Ammo** (`AmmoBuy.lua`, Warnings > VENDOR RESTOCK, off by default):
  - **Budget per visit:** your money, minus Keep At Least (default 0) and the repair bill, capped at Max Spend Per Visit (default 25%). It is spent from a running balance.
  - **Order:** a minimum pass then a fill pass.
  - **Purchases:**
    - whole vendor bundles;
    - bag families and Leave Free Bag Slots (2);
    - a no-gain skip;
    - Shift skips the visit;
    - one chat summary.
  - **Ammo:**
    - **What it buys:** the best usable common tier, never worse than the equipped ammo unless you are low.
    - **Modes:** Fill Quiver (default) / Fill Quiver And Bags / Keep At Least (1000 hunter, 200 warrior or rogue).
    - **New tiers:** 200 of a newly unlocked tier.
    - **Next-tier bridge:** within 1 level, or 2 at 75%+ XP, buy 200 only.
    - **Use Up Old Ammo:** older ammo counts, but never two or more tiers behind.
- **In progress:** food, drink (mana users; mages greyed once they conjure), class reagents and pet food categories on the engine.
- **Tests (E2):** auto train 20, class supplies 184, class buffs 184, weapon enchants 165, class cues 251, new spell alerts 7,120, pet 318, hunter cues 145, restock and ammo 123. FHK Gear 697. Full `npm test` passes, with standalone runs on all nine classes.

### Class kits: buff bar, weapon enchants, class supplies, class cues, customisability (Claude + build agents A-D, G; 2026-10-06)
- **Why:** player: "paladins have auras mages have armor rogue has poisons ... timers on weapon poisons ... a behind target indicator ... similar to our range indicator ... with two colours". Plan: [BUILD_PLAN_CLASS_KITS_2026-10-06.md](BUILD_PLAN_CLASS_KITS_2026-10-06.md). Everything is off by default, registers no events while off, and is class gated (no frames, events or rows for a class without the feature).
- **Class Buff Bar** (`ClassBuffs.lua`, Unit Frames > CLASS BUFFS, all classes but hunter and rogue):
  - click-to-cast buttons for paladin auras, seals and blessings, priest Inner Fire / Fortitude / Shadowform, mage armors and Intellect, warlock armor, shaman shields, druid Mark / Thorns / Omen (caster form), warrior Battle Shout;
  - rank-aware by name; missing and expiring cues;
  - no cues while dead, mounted, on a taxi or in a vehicle.
- **Weapon Enchants** (`WeaponEnchants.lua`, Unit Frames > WEAPON ENCHANTS): a pod per weapon with poison, imbue, stone or oil, timer, charges and bag count.
  - Click applies the chosen item out of combat (Blizzard's secure `target-slot`).
  - Rogues pick a poison per hand; shamans a preferred imbue.
  - Data comes from Forever DB2 build 1.60.1.70205 (E1).
- **Class Supplies** (`ClassStock.lua`, Warnings > CLASS SUPPLIES): reagents and made items with counts, plus click to create.
  - Covers shards, stones, Ankh, powders, conjures, runes, symbols, candles and seeds.
  - Soul bag full and a Soulstone-on-someone timer.
  - **Lead review fix:** a new **Smart** default for its warnings. Bought reagents warn only when resting or at a vendor; made items warn out of combat. A rogue without Flash Powder is no longer nagged across the zone.
- **Class Cues** (`ClassCues.lua`):
  - **Behind Indicator** (rogue, druid; Resource Bars) in two colours, with new `behind` (#FEF367) and `front` tokens.
  - **Energy Tick Spark** (rogue, cat druid).
  - **Warnings > CLASS CUES:** Stealth / Prowl First, Must Be Behind, warrior stance, Leave Form, stealth opener, reactive glows (Overpower, Revenge, Execute, Victory Rush, Riposte), stance mismatch hint and Slice and Dice.
  - The error names were checked against Forever's GlobalStrings (wago.tools build 1.60.1.70205, E1).
  - **Lead review fix:** fresh evidence now wins over "it targets you", and a stunned or incapacitated target (Gouge, Cheap Shot, Kidney Shot, Sap, Blind, Pounce, Bash, Hammer of Justice and others) reads unknown instead of In Front. Without this, Gouge, step behind, Backstab always showed IN FRONT.
- **Customisability polish** (agent G): range, attack, range bar, XP bar, damage flash, key press and swing timer sections moved to cogs and swatches. Dependent rows grey out with the master toggle's name, and each section has its own confirmed Reset. The Target of Target bar now turns pet green when the target attacks your pet (`totOnPet`), as its tooltip promised.
- **New Spell Alerts** (`RankNotifier.lua` + generated `ClassTrainingData.lua`, Warnings > NEW SPELLS; agent E):
  - It says "New: Instant Poison III" or "N new spells at your trainer" on level-up, at login and on a Poisons skill-up, in the lane and/or chat.
  - Ignore list; it waits out combat and, optionally, resting.
  - At the class trainer, the trainer's own list corrects the data for the session.
  - Data comes from Forever's client tables (wago.tools DB2 build 1.60.1.70205), generated by `tools/GenerateTrainingData.js` (E1): 403 spells, 1,415 ranks. It is cross-checked against foreverdb.net, with differences listed in CLASS_KITS_PROBES.md. No WhatsTraining data.
- **Class pages filled** for every class. A standalone check fails if a class-page row names an option that does not exist.
- **New TOC files:** `ClassBuffs.lua`, `WeaponEnchants.lua`, `ClassStock.lua`, `ClassCues.lua`. A full client restart is needed.
- **Tests (E2):**
  - class buffs 162, weapon enchants 147, class supplies 170, class cues 229, customisability 662;
  - standalone on all nine classes (Hunter 680 rows, Warrior 431, Paladin 447, Rogue 489, Priest 445, Shaman 441, Mage 435, Warlock 553, Druid 501);
  - themes 611; installer pass.
- **E3 owed:** the probes in each module's agent report, gathered in HANDOVER.

## 1.9.4 test build (adversarial review fixes; FHK Gear 0.5.2)

### Adversarial review: every finding fixed, designed or deferred (Claude, 2026-10-06)
- **Why:** player: "performance/error reviews? have we comprehensively reviewed each feature, edge cases, race conditions, nils", then "parallel agents".
- **How:**
  - Ten read-only agents reviewed every companion and Gear file.
  - Each finding was checked against the code before fixing.
  - Full table, with fixed / by design / deferred and the reasons: [ADVERSARIAL_REVIEW_2026-10-06.md](ADVERSARIAL_REVIEW_2026-10-06.md).
- **Publishing rule:** native-indicator changes, the power-text seed, chrome caps, the error lane, the chat fade and AutoGear pausing are now owner-only or off by default.
  - Combat Layout restores its CVars once per character, and its Cooldown Manager undo finds bars by key.
- **Correctness:**
  - **Aspects:** another hunter's Pack or Wild is no longer read as yours; the combat-start paint uses combat rules; Only When Wrong takes no clicks.
  - **Swing:** READY bars stay full after Ellesmere idles the row; the cursor melee ring no longer blinks on every Auto Shot; the one-ring colours are correct; the dual-wield melee clock no longer restarts.
  - **Range:** a stale bracket no longer hides a live Shooting or Melee answer; this is also ported to FHK's own `RangeLogic.lua`.
  - **Pet food:** the list view draws from every bag; stale Edit / Delete links are hidden; mid-feed view changes clean up; Blizzard bags under the gamepad UI fall back to the row.
  - **Unit frames:** recycled plates drop the old unit's marks; the rarity badge shows on a plate that turns hostile.
  - **XP:** native dividers are found (`_divHost`); the 9.3.8 gradient colour is read correctly; the quest overlay returns when Ellesmere's own is turned off.
  - **Themes:** swatch edits survive a preset switch; Restore refreshes plates and treats missing dark-mode toggles as off.
- **Performance:**
  - Unit events limited to drawn units, with a 0.05 s repaint limit.
  - Range measurements cached for 0.05 s per unit.
  - Plate-add bursts coalesced into one sweep per frame.
  - The resource sweep and the standalone swing ticker run only when needed.
  - Icon-edge and fill caches no longer allocate per tint.
- **Tests:**
  - `RunThemeChecks.js` joins `npm test`. It had been failing unnoticed since the owner-only gating: its General-page check now builds as the owner.
  - On a stock 9.3.8 tree the options-extension block is skipped, since only the local core patch has that file.
  - New mocked checks: swing READY (2), cursor rings (3), standalone ticker (2), dual-wield clock, range bracket (2), pet food (6), Combat Layout bar keys, themes (3).
- **Tester zip:** `dist/ForeverCompanion-1.9.4_FHKGear-0.5.2_test.zip`, 84 files, docs redacted, plus this review.
  - The zip now uses forward-slash paths. PowerShell 5.1's `Compress-Archive` writes backslashes, which flatten into odd file names with Mac or Linux unzip; the 1.9.3 zip had that problem.
  - Clean-room check: unzipped beside stock 9.3.8 with no other addons, the code is byte-identical to live and the standalone harness passes. Windows' own extractor also opens it.
- **Version:** 1.9.4. **E1/E2 only**; in-game checks 22-31 added to `IN_GAME_CHECKS_2026-10-05.md`. Not pushed.

## 1.9.3 (pet food row, Hunter cues, priority 2/3, leveling helpers; new TOC files: full restart)

### Tester package: no-overwrite proof, dependencies and a self-contained zip (Claude, 2026-10-06)
- **Why:** player: make sure nothing overwrites keybinds or macros, that everything displays without Forever Hunter Keys, and that the package holds everything testers need.
- **Keybinds, macros and game settings (code audit):**
  - The only binding and macro writer is the Quest Bar (`QuestBar.lua`). Its option was already hidden without ForeverHunterKeys, but `/fhkquestbar on` still worked: now refused without FHK. Turning it off still works.
  - The only CVar writers are Hunter Polish and Combat Layout (owner-only, with undo) and two visible toggles that change a game setting when the player flips them (soft-target sword icons, object interact icon).
  - The standalone harness now also types `on` and `apply` into every slash command; nothing writes a binding, macro or CVar.
- **Dependencies:**
  - The companion's OptionalDeps gain EllesmereUICooldownManager and EllesmereUIRaidFrames (both read, neither declared before).
  - FHK Gear's gain EllesmereUIBags (bag markers).
  - Every artwork path the plugins reference exists either in their own folder or in stock EllesmereUI 9.3.8.
- **Tester zip:** `FHK-Ellesmere-Patch/dist/ForeverCompanion-1.9.3_FHKGear-0.5.1_test.zip`.
  - Contents: the two addon folders, README, FEATURES.md, and the new TESTERS.md (install, what to try, how to report).
  - Clean-room check: unzipped next to stock EllesmereUI 9.3.8 with no other addons (`.dev/staged-release`), the standalone harness passes. The file set matches live, with docs redacted.
- **Stale texts fixed:** the XP number label; the soft-target tooltip no longer mentions the owner-only Combat Layout.
- **E1/E2** only; all suites pass. Not pushed.

### Release pass: Ellesmere row tools, owner-only presets, Ellesmere 9.3.8, XP formats, performance (Claude, 2026-10-05)
- **Why:** player requests before publishing:
  - "Ellesmere uses cogs for settings, multidirectional arrows, an eye for previews; get those into our UI";
  - "we shouldn't be overwriting others' settings, keybinds, macros... this is just shipping the Forever Companion and Forever AutoGear and their enhancements to Ellesmere";
  - "anything that moves the combat or pet combat indicator?";
  - "patch it to work with the latest Ellesmere";
  - XP text formats and overlap with native features;
  - a performance review.
- **Ellesmere row tools** (`RefinementOptions.lua` `Extras`):
  - Any companion row half may now carry `swatches` (Ellesmere's `BuildInlineSwatches`), `cog` and `move` (`BuildInlineCog`, the move one with Ellesmere's directions icon), and `preview`: an eye button with Ellesmere's visible / invisible icons, its alpha states and the disabled-reason tooltip.
  - **Converted:**
    - Aspects: preview eye and edge swatches on Aspect Element, a layout cog on Aspect Display, a multiSwatch for the six aspect colours.
    - Pet Auras / Target / XP Bar: size cogs and offset move arrows.
    - Warnings: threshold cogs, lane move arrows, preview eye, a colour multiSwatch.
    - Action History: flash, history and key-label cogs, preview eye.
    - Pet Food button size cog.
    - General: preview eye on Preview Scenario.
    - Unit Frames: health and happiness swatches inline.
    - Nameplates: edge swatches inline; Smooth Cue Fades cog.
    - Mob Rarity: level and quest swatches inline, a badge cog.
    - Leveling Helpers: bar swatches inline, a range-fade cog.
    - Hunter Cues: Feign Death and Growl cogs.
    - Hunter Colors: two multiSwatch rows.
  - About 40 option rows fewer. The standalone harness drives every cog row, swatch and preview.
- **Owner-only presets** (published install = the companion's own features with their defaults):
  - Shown only alongside ForeverHunterKeys: Hunter Keyboard Layout (Apply / Undo Hunter Layout and Polish, Fade Wing Bars, Guide Quest Bar), Reviewed Hunter Cues, Combat Layout (and `/fhklayout` apply), and Macro Modifier Key Labels.
  - Everyone else gets **Key Labels And Menu** (Keyboard-First Key Labels, off by default without FHK; Menu And Bags Visibility).
  - The standalone harness now fails if any owner-only row shows on a published install, or if anything outside the player's own option changes writes a keybind, macro or CVar.
- **Combat indicators:** Pet Combat Icon gets a size cog and X / Y move arrows (`petCombatSize`, `petCombatX`, `petCombatY`). Combat Icon Style gets a White Block size cog (`combatBlockSize`). The player icon moves with Ellesmere's native combat indicator options. All four keys are in `PROFILE_KEYS`.
- **Ellesmere 9.3.8** (latest upstream; installed 9.3.5): built `.dev/staged-938` from tag `v9.3.8`; Validate, integration and standalone all pass there.
  - **Adapter updates:** 9.3.8's XP gradient and Quest XP Overlay helpers are included in the native XP slice. The XP number checks follow 9.3.8's text slots. The no-target opacity checks run only where the core patch provides it (stock has none).
- **Overlap with 9.3.8:**
  - Ellesmere now has a **Quest XP Overlay**; our Completed Quest XP stands down (and greys out, saying why) while it is on.
  - Native XP text slots cover Current %, Current, Current / Max, Current / Max (Remaining), Rested, Rested %, Completed Quests (and %), Level, XP per Hour, Leveling In, Time This Level and Time This Session.
  - **Not native:** "XP to level" and "% to level" as items of their own. Ellesmere's item list is private, so they can't be added from a plugin; they're a core-patch or upstream request.
  - Our Session XP tooltip and 10% ticks remain alternatives to the native text items and dividers.
- **XP Number Format** replaces the Full XP Numbers toggle:
  - Ellesmere (17.6K), Full (17,600) or Rounded (18K, 1.3M), saved as `xpBar.numbers`; the old toggle maps across.
  - On 9.3.8, values under 10,000 are always shown in full by Ellesmere.
- **Performance review:**
  - Every always-attached OnUpdate is throttled (companion sweep 0.15 s, unit paint 0.15 s, Hunter swing fallback 0.05 s, Hunter-only and skipped with FHK). Animation OnUpdates detach when idle. Tickers run only while their state is live.
  - **Fixed:** the quest-bar poller ran every frame on installs that never use it; it now attaches only while the quest bar is on.
  - Rarity's UNIT_HEALTH handler is a table lookup.
  - FHK Gear has no OnUpdate.
- **E1/E2:** live and 9.3.8 suites pass; integration 2913 (live) / 2911 (9.3.8, where two patch-only checks are skipped); aspect 174; pet 149; standalone on the installed, stock 9.3.5 and 9.3.8 cores. **No E3**; checks 18-21 in [IN_GAME_CHECKS_2026-10-05.md](IN_GAME_CHECKS_2026-10-05.md).

### Aspect Visibility: Only When Wrong (Ksuper's rule) (Claude, 2026-10-05)
- **Why:** the player relayed Ksuper2's suggestion: in combat with Cheetah, show Cheetah; in combat with Hawk, nothing; in combat with neither, show Hawk; out of combat, nothing. The existing choices (Always / In Combat / Mouseover) always showed the element in combat.
- **New choice:** Unit Frames > Aspects > **Aspect Visibility: Only When Wrong**.
  - Out of combat it is hidden (the same state driver as In Combat). In combat it is invisible while there is no advice, and appears only while the aspect is wrong.
  - With Cheetah or Pack up, the element shows that aspect with its red pulsing edge and the Hawk badge. With no aspect at all, the main icon shows Hawk, the aspect to cast.
  - Visibility uses alpha, so it changes safely in combat. In Bar mode the hidden bar keeps its clicks, as Mouseover does.
- **Note:** Monkey When Mob Is On You still counts as advice. Turn it off for Ksuper's exact rule (Hawk up means nothing shown).
- **E2:** aspect suite 171 (+7: state driver, Cheetah shown, Hawk hidden, no aspect shows Hawk, other modes unchanged). **No E3**; check 17.

### Standalone proof and corrupted-settings hardening (Claude, 2026-10-05)
- **Why:** player: confirm FHK Ellesmere and FHK Gear work with no other addons, and do an adversarial review for edge cases, races and loops.
- **New harness `StandaloneTests.lua` + `RunStandalone.js` (in `npm test`):**
  - Each addon is loaded file by file in TOC order into a bare client: EllesmereUI's core API names (read from the installed core, then again from stock 9.3.5 in `.dev/staged-935-base`), no Ellesmere modules, and no ForeverHunterKeys, RestedXP, AutoGear or any other addon. Unknown globals stay nil.
  - It drives login, every registered event out of and in combat, timers and tickers, show/hide scripts, every slash command, and every options row (read, re-set, click), plus the plugin Reset.
  - A mutation check (a file reaching into `ForeverHunterKeysNS`) confirmed the harness fails on a hidden dependency.
- **Result:**
  - Both addons load and run on the installed and the stock 9.3.5 core: FHK Ellesmere 36 files and 381 option rows, FHK Gear 17 files and 142 option rows.
  - No hidden dependency: every reference to ForeverHunterKeys, RestedXP, AutoGear, LibStub and ForeverGear is guarded, and a static scan found no namespace field that only Forever Hunter Keys provides.
- **Found and fixed by the corrupted-settings pass** (saved tables replaced by strings, and every saved value given the wrong type):
  - 32 `FHKEllesmereDB = FHKEllesmereDB or {}` guards kept a non-table value and then indexed it (8 modules errored at login). They now replace any non-table.
  - `Companion.lua` compared a saved version flag with a number without checking its type.
  - FHK Gear survived both passes unchanged.
- **Correction to "Code audit, part 3":** the first bullet over-claimed. `Bootstrap.lua` makes `FHKEllesmereNS` *be* `ForeverHunterKeysNS` when Forever Hunter Keys is installed, so `NS.groups` already held FHK's groups on the owner install, and macro keys were found. The change to read `ForeverHunterKeysNS.groups` explicitly is harmless and clearer, but it fixed no live bug. The other part 3 fixes stand.
- **E2:** the standalone run plus every existing suite pass; Gear 467. **No E3**; check 16 in [IN_GAME_CHECKS_2026-10-05.md](IN_GAME_CHECKS_2026-10-05.md) runs it in the client.

### Aspect bar: Cheetah / Pack in combat pulses red on itself (Claude, 2026-10-05)
- **Why:** player: a warning for Cheetah when it is active in combat, with a red border around it, in line with the design rules (state shown on the element itself).
- **Before:** Icon / Current Only already put a pulsing red edge on the active icon, and Warnings has an optional lane line. In **Bar** mode, though, the red pulse went to the suggested aspect (Hawk), not the one that was wrong.
- **Now:** on the bar, with Cheetah or Pack active in combat, that button pulses red (Danger Edge Color) and stays at full opacity even when Dim Inactive is on. The aspect to switch to gets the steady gold advice edge (Advice Edge Color). With no aspect at all in combat, the suggestion is still the red one. The same applies on the hover bar in Current Only mode.
- **Unchanged:** the bar lists learned aspects only, and rebuilds after combat when one is learned.
- **E2:** aspect suite 164 (+3). **No E3**; check 15 in [IN_GAME_CHECKS_2026-10-05.md](IN_GAME_CHECKS_2026-10-05.md).

### Companion options refresh at once (Claude, 2026-10-05)
- **Why:** player, in game: switching Aspect Element, Pet Auras (and other section toggles) on left the options under them greyed out until another tab was opened and back.
- **Cause:** Ellesmere's own rows call `EllesmereUI:RefreshPage()` after a change, which re-reads every row's value and disabled state in place. Most companion builders (Aspects, Pet Auras and Target, and others) only saved and synced.
- **Fix:** the shared section renderer (`RefinementOptions.lua` `RenderSection`, used by the plugin pages and the 9.3.4 in-page sections) wraps every toggle, dropdown and button so it refreshes the page after its own work. Sliders are left alone so a drag is never interrupted. This covers every companion section, including ones written later.
- **E1/E2:** 51 files validate; integration 2907 (+2: a toggle refreshes the page, sliders are not wrapped). **No E3**; check 1 in [IN_GAME_CHECKS_2026-10-05.md](IN_GAME_CHECKS_2026-10-05.md).
- **Also:** one consolidated in-game list, [IN_GAME_CHECKS_2026-10-05.md](IN_GAME_CHECKS_2026-10-05.md), replaces the scattered E3 lists.

### Feed Pet: Food Only shrinks the Ellesmere bags to the pet's food (Claude, 2026-10-05)
- **Why:** player, in game: casting Feed Pet only opened the normal Ellesmere bags (screenshot: All Items, every category). They want the inventory itself to change: "only show the food the pet can eat, basically shrinking the existing UI".
- **Likely cause of "nothing happened":** Feed Pet was detected correctly (Forever uses the same rule: `C_Spell.GetTargetSpellID() == 6991`). But the Pet Food Row sat above the bag window, and with the bags at the top of the screen it was drawn off-screen. The row now goes below the bags when there is no room above.
- **New default, Feeding View = Food Only:**
  - While Feed Pet waits for food, Ellesmere's own grid draws one **Pet Food (n)** section: everything the pet eats, raw meat included. There are no pinned, recent, empty or "+" sections, whatever tab is open, and the window refits.
  - Clicking a stack feeds it (Ellesmere's native item button). When Feed Pet ends, the full layout, the tab and the window size come back. Bags that Feed Pet opened close again without redrawing the full layout first.
  - **How:** Ellesmere's `ns.RenderGridView` / `ns.RenderListView` are wrapped from the companion. No Ellesmere file changes. During the draw only, it takes the All Items layout, borrows one plain, visible category as the carrier (renamed "Pet Food") and suppresses recent, add and empty user sections. All of it is restored right after, even if the draw errors; an error falls back to the normal draw. Outside feeding the wrapper checks one flag.
  - **Fallback:** without Ellesmere's bag renderer (Blizzard bags, another Ellesmere version), Food Only shows the Pet Food row instead.
  - **Limits:** Ellesmere never makes the window shorter than its category list. In list mode, only food in the open tab is listed.
- **Settings:** `petFood.view` gains `filter` (default). A saved plain `row` moves to Food Only once (`viewFilter` flag); Row + Grey Out and Off are kept. The options dropdown is Food Only / Pet Food Row / Row + Grey Out / Off. No new TOC file: `/reload` loads it.
- **E1/E2:** 51 Lua files validate. Pet food suite 80 (+24): filtered draw, one section, nothing else drawn, Ellesmere state restored, slot data untouched, refit both ways, no refresh loop, list view, hidden-category carrier, error fallback, Feed-Pet-opened bags, the fallback row and the migration. **No E3.**
- **In game:** cast Feed Pet with the bags closed, then with them open on another tab. Check the single Pet Food section, that clicking feeds, and that the normal layout returns afterwards.

### Code audit, part 3: three behaviour bugs the mocks hid (Claude, 2026-10-05)
- **Why:** player: "let's close this all out". A final pass over Codex's part 2, looking for behaviour the mocks could not show.
- **Fixed:**
  - **Macro keys were never found (Cooldown Key Labels, Aspect bar keys):** both read `FHKEllesmereNS.groups`, but Forever Hunter Keys keeps its action groups in `ForeverHunterKeysNS.groups`. The tests set the companion table by hand, so they passed. Both now read Forever Hunter Keys' list (falling back to the companion table).
  - **Cooldown labels missed rebuilt icons:** the `ns.UpdateCDMKeybinds` hook never fires, because Ellesmere calls its local function. New and rebuilt icons are now caught through `ns.ShowCDMKeybindBadge`, which every keybind text passes through: an unhooked text schedules one discovery pass for the next frame. Also rediscovers on `UPDATE_MACROS`.
  - **Pet Idle never started on entering combat:** `PLAYER_REGEN_DISABLED` fires before `InCombatLockdown()` turns true, so the combat ticker was never created. The combat events now set the state directly.
  - **Smaller fixes:**
    - Trap Broken stays quiet when the trapped target died.
    - Loot Left Behind skips locked slots (group rolls, others' loot).
    - `UNIT_FLAGS` re-checks only Feign Death, not every cue.
- **E1/E2:** 51 Lua files validate. Mocked checks: 2905 + 161 + 147 + 26 + 56 + **67** + **60** (+4 new regression checks: combat-entry ticker, macro list from Forever Hunter Keys, rebuilt icon). Package Check reports 0 differences; Gear 467. **No E3.**
- **In game (E3 owed):** a cooldown icon for Aspect of the Hawk shows C-X; Pet Idle appears 1.5 s into a pull with a passive pet.

### Code audit, part 2: warning lifetime, recycled visuals and refreshes (Codex, 2026-10-04)
- **Why:** continue Claude's audit after publication of the fork. The remaining five requested areas were reviewed; fixes are local, not pushed.
- **Hunter cues:** disabling Feign cancels its ticker and pending resist check, including while another cue stays enabled. All-off/non-Hunter sync stops both tickers and clears the lane. Trap warning expiry is scoped to each arrival; disabling clears it immediately. Failed/secret aura and tracking reads remain unknown, and secondary API returns are secret-guarded. Reactive glow wrappers are children of their buttons, follow paging, and refresh their native style on settings/profile sync.
- **Warnings:** identical visible warnings skip repeated text/font/layout writes. Active lane text repaints immediately when its shared color token changes, preserving reduced-motion changes and fade interruption.
- **Leveling helpers:** LOOT_READY and LOOT_OPENED share one snapshot, retain cleared-slot evidence and cannot resurrect auto-looted items. Old warning timeouts cannot hide newer notices; disabling clears notices and pending snapshots. NPC bag closing waits until native closing handlers finish, then checks visibility/ownership again. Range opacity changes repaint an already faded target and release replaced frames. Mana reveal runs the native health writer first and follows its portrait/pet visibility relationship. Disabling the mirror skin restores the original text font and border opacity.
- **Cooldown labels:** retain native text separately from the override. Clearing a manual label or disabling macro labels restores it immediately; recycled icons use their current spell, blank native labels remain blank, and SetText hooks cannot recurse or multiply on rediscovery.
- **Swing additions:** the clip marker recognizes higher ranks by localized spell name, updates on cast delay/stop/failure and shared-clock refreshes, hides with the swing feature, and follows a replaced cast bar. Unchanged Raptor queue state skips the row pass on unrelated ACTIONBAR_UPDATE_STATE events. Color changes invalidate cached spark styling and repaint the clip marker.
- **Color apply:** refreshes active warning text, pet elements, Hunter cues and native swing refinements, alongside the existing unit/nameplate/range/cursor refreshes.
- **Settings/TOC:** no new keys, defaults, controls or files. Remains unreleased 1.9.3; reload loads these fixes if all prior TOC additions were already loaded. Otherwise full client restart.
- **E1/E2:** 51 Lua files validate; **3419** mocked checks (2905 + 161 + 147 + 26 + 56 + 65 + 59), including **46 new regression checks**, pass. Installer/package results are recorded in [the continuation audit](CODE_AUDIT_CONTINUATION_2026-10-04.md). **No E3 or measured CPU/FPS claim.**
- **Recovery:** `Snapshot-20261004-pre-codex-published-audit-215952.zip`. No third-party, SavedVariables, binding, upstream or GitHub writes.

### Code audit, part 1: pet food performance and auto-buy safety (Claude, 2026-10-04)
- **Why:** player: "push and audit". The first part covers PetFood and its warning.
- **Result:**
  - **No bag re-scans on unrelated events:** the Pet Food Warning no longer clears the food cache on every warning re-check (pet health, auras and more, out of combat). Only `BAG_UPDATE_DELAYED` and the owner's `UNIT_PET` clear it.
  - **Diet cache kept across bag updates:** what the pet eats (`CanPetEatItem`) is only cleared when the pet changes, so a bag update costs one call per new item instead of one per slot.
  - **Auto-Buy:** one purchase per vendor visit (bag counts lag behind a purchase), plus one retry 0.6 s after the window opens, because vendor item data can arrive late. `MERCHANT_CLOSED` resets the visit.
- **E2:** pet food suite 56 (+1: no second purchase in one visit). **No E3.**
- **Still to audit:** HunterCues, LevelingQoL, CdmLabels, the SwingIntegration additions, Companion colours (see HANDOVER).

### Publish audit: personal presets gated to the owner install; every colour customisable in its own section (Claude, 2026-10-04)
- **Why:** player: ship the features, not our layout, macros or keybinds; every colour, shape or icon needs a toggle and its colour, in the right Ellesmere section. Full record: [PUBLISH_AUDIT_2026-10-04.md](PUBLISH_AUDIT_2026-10-04.md).
- **Result:**
  - **Presets gated:** Quest Bar keys and macros, idle chrome, reviewed profile, chrome and fonts, chat fade, combat hide and quiet chat, nameplate range fade, and swing timer setup now apply by themselves only with ForeverHunterKeys (the owner). Everyone else uses the buttons.
  - **New swatches in their own sections:**
    - Unit Frames: pet Happy / Content / Unhappy; Health 50 % / 25 % / Critical;
    - Nameplates: On You / On Pet edge; Elite / Rare level; Quest Count;
    - Hunter Warnings: Act-Now / Caution;
    - Leveling Helpers: Breath / Fatigue / Feign Death bars.

    Each section has its own Reset. They are shared tokens changed in place, health colour curves rebuild, and the pet XP badge and Passive letter use Caution and Danger.
  - **Fix:** `/fhkeui chat restore` with nothing saved no longer sets a fade.
- **E1/E2:** Validate 51 files; integration 2893 + element suites. Preset tests cover both the published and the owner install. The Mob Rarity page height is +64 on purpose. **No E3.**

### Forum list: mana reveal, quest/elite badge, NPC bag closing, Cooldown key labels (Claude, 2026-10-04)
- **Why:** player: "carry on with the forum list"; the quick, levelling-useful items from plan section 11.
- **Result:**
  - **FR23 Show When Mana Missing** (Leveling Helpers, opt-in). With Ellesmere's own Unit Frames > Show When Health Missing on, the player frame also shows while mana is below full (drinking between pulls).
    - It wraps Ellesmere's two reveal writers (`HealthVisibilityAlpha`, `UpdateHealthVisibilityUnit`) for the player only, and repaints on the player's `UNIT_POWER_UPDATE` / `UNIT_MAXPOWER`.
    - Mana only, never rage or energy. An unreadable value counts as full, so the frame never sticks.
  - **FR27 elite badge vs quest mark:** when our Rarity badge and Ellesmere's quest mark both use the top-right corner, the badge moves just left of the quest mark (its count grows rightward), and returns once the mob is no longer a quest mob. On Forever, Ellesmere draws no elite or rare marks, so our badge is the only elite mark.
  - **FR32 Close Bags Opened By NPCs** (Leveling Helpers, on).
    - Vendor, mailbox, auction house and trade windows open the bags through `OpenAllBags`, which Ellesmere follows, but nothing closed Ellesmere's bags again.
    - Bags that opened within half a second of the window now close with it, through Ellesmere's `ToggleAllBags`.
    - Bags already open, opened later, or holding a Feed Pet selection stay. The bank already did this natively.
  - **FR28 Cooldown Key Labels** (new `CdmLabels.lua`, Cooldown Manager > Cooldown Key Labels):
    - **Macro Modifier Key Labels** (on): spells cast from Forever Hunter Keys' modifier macros show their exact key on cooldown icons, e.g. C-X for Aspect of the Hawk instead of the macro's bare X.
    - **Manual labels:** `/fhkcdm label <spell> = <text>` / `/fhkcdm clear <spell>`, saved with the Ellesmere profile (`cdmLabels`).
    - **How:** each icon's own keybind text is hooked (`ns.cdmBarIcons`, `ns._ecmeFC`, `ns._hookFrameData`), so Ellesmere's styling and Show Keybind switch stay in charge. Bindings are never changed.
- **Not built, with reasons (plan section 11):**
  - FR33: Ellesmere sells junk through `C_MerchantFrame.SellAllJunkItems()`, which can't skip one item from outside, so it stays a policy note.
  - FR21 / FR31: native setup first.
  - FR24: rank audit, doc.
  - FR26 / FR29: research gates.
  - FR30: low Hunter value.
- **E1/E2:**
  - Validate: 51 files PASS.
  - Integration: 2881 + 161 + 147 + 26 + 55 + 50 + **40 leveling helper** checks (mana reveal, NPC bag closing, Cooldown labels) + 2 rarity placement checks.
  - **No E3.**

### Priority 2 and 3 cleared; Pet Food row; leveling helpers; Hunter colors (Claude, 2026-10-04)
- **Why:** the player asked to clear plan 10.3 Priority 2 and 3, then the quick, useful forum picks. Several changes follow the player's in-game feedback:
  - Feed Pet only opened the normal bags, with no food row (screenshot, category view);
  - reactive skills should glow like procs;
  - the breath bar needed skinning;
  - colors must use Ellesmere's own picker.
- **Pet Food row** (replaces Food Only; **on by default**, player request).
  - While Feed Pet waits for food, a strip on top of the bags (Ellesmere's in any view, or Blizzard's) lists everything the pet eats, raw meat included. A click feeds that stack (secure `/use bag slot`, set out of combat).
  - Feeding View: Pet Food Row / Row + Grey Out / Off. The old Food Only holder-packing is removed: it could not make a row in category view.
  - The bags open for feeding and close afterwards. If Blizzard's handler opened them a moment before, the open is still treated as ours.
- **Raptor Strike queue** (plan 9.9): the melee row takes Ellesmere's native queue colour and "MELEE - Raptor Strike" label while Raptor Strike waits for the next swing.
  - It uses the native Queue Highlight switch and `queueR/G/B`, reads `IsCurrentSpell` by name, and refreshes on `ACTIONBAR_UPDATE_STATE`.
  - No Ellesmere file is edited (its `QUEUE_SPELLS` list is private).
- **Mongoose Bite / Counterattack glow** (on by default, player). While usable, their action buttons glow with Ellesmere's own Proc Glow style and colour, through the public `EllesmereUI.Glows`. Ellesmere only glows what `IsSpellOverlayed` reports, and Classic reactive skills never are.
- **More Hunter cues** (opt-in, shared warning lane):
  - Pet Idle (no pet target for 1.5 s in combat);
  - Trap Broken (Freezing Trap gone well before expiry, same target);
  - Hunter's Mark on elites;
  - Trueshot Aura missing (talent);
  - Rapid Killing proc (talent).
- **Warning sounds:** an Act-Now sound and an Other Warning sound (None / Raid Warning / Alarm / Ready Check / Soft Tick), played on arrival, at most every 3 s per warning.
- **Pet XP bar:**
  - a gold "TP n" badge for unspent training points;
  - a stance letter (A / D / P, Passive in red);
  - the tooltip lists stance and abilities with autocast state, refreshed on `PET_BAR_UPDATE`.
- **Pet food extras:**
  - Feed Pet timer: a cooldown sweep on the food button while Feed Pet Effect is on the pet.
  - Auto-Buy Pet Food (opt-in): tops up to a target count with Food Choice, at most two stacks per visit and a tenth of your money, and prints each purchase.
- **Leveling Helpers** (new `LevelingQoL.lua`, Quality of Life > Leveling Helpers):
  - Skin Breath And Fatigue Bars (on): Forever's `MirrorTimerContainer` bars (breath, fatigue, Feign Death) get the flat Ellesmere look. Blizzard keeps the timers and the Edit Mode position.
  - Loot Left Behind (on): lists unlooted items of a chosen rarity in chat, with a lane warning and a bags-full hint.
  - Zone Levels On Map (on, Classic ranges).
  - Target Range Fade (opt-in): never in the dead zone.
  - Gathering Tracking Reminder (opt-in).
- **Hunter Colors** (Quality of Life > Hunter Colors): Ellesmere's native color-picker rows, with hex input, for Shooting / Melee / Cast / Retry / Danger / Caution.
  - Tokens change in place, bar fills follow at 73 %, and the palette rebuilds.
  - Reset restores the Forever palette.
  - Profile key `hunterColors`.
- **Auto Shot Clip Marker** (Swing Timer > Hunter Timing, opt-in): a tick on Ellesmere's cast bar where the next Auto Shot falls during Aimed Shot / Multi-Shot.
- **Sniper Shot** (talent): the range indicator's maximum widens by 10 yards while its buff is up, read at most twice a second. If FHK's copy of `RangeBackend` loads first, its copy is used instead.
- **Fixes found on the way:**
  - The Hunter Cues options section had never been added: the existing "REVIEWED HUNTER CUES" title fooled a substring duplicate check.
  - Two `x and f()` calls dropped later return values (clip marker clock).
  - New permanent static checks in `Validate.js`: every `NS.AddEllesmere*Options` is appended to a page, and every module settings table is in `PROFILE_KEYS` (plan 2 profile export check).
- **Deferred, with reasons:**
  - Stable info: no Forever stable API is confirmed yet (needs a probe).
  - Pet ability learning tracker: needs a beast/ability dataset (ForeverDB reference only; permission needed before bundling).
  - Recommended Cooldown Manager layout: written as a plan note (doc only).
- **E1/E2:**
  - Validate: 50 files, all static checks PASS.
  - Integration: 2879 + 161 aspect + 147 pet + 26 probe + 55 pet food + 50 hunter cue + 22 leveling helper.
  - Installer PASS.
  - **No E3.**

### Hunter cues: Stop Attack on your crowd control, Feign Death, Growl, Tracking, Beast tooltip (Claude, 2026-10-04)
- **Why:** plan 10.3 items 6-10, the rest of Priority 1. Player: "lets see if we can smash it all out in this session".
- **Result:** new `HunterCues.lua` (TOC after Warnings; **full restart**), Quality of Life > Hunter Cues, every cue off by default. Cues use the shared warning lane: `Warnings.lua` now exports `NS.ShowEllesmereWarning` / `NS.HideEllesmereWarning`, with danger keys put first. Events are registered only for the cues that are on.
  - **Stop Attack On Your Crowd Control** (danger, above the character). Auto Shot (`START/STOP_AUTOREPEAT_SPELL`) or melee auto attack (`PLAYER_ENTER/LEAVE_COMBAT`) is on while the target carries your own Freezing Trap Effect, Scatter Shot, Scare Beast or Wyvern Sting. It reads `GetAuraDataBySpellName` with `HARMFUL|PLAYER`; names cover every rank.
  - **Feign Death Warnings:**
    - **Feign Death Resisted** when the cast succeeds but `UnitIsFeignDeath('player')` is readably false 0.3 s later. There is no public combat-log reader on Forever (probe 2).
    - A **countdown** before Forever's 6-minute Feign Death kills you, from a slider (default 5:00). It is amber, and red for the last 30 s. A 1 s ticker runs only while feigning.
  - **Growl Reminder** (out of combat): Growl autocast on in a group. With **Growl Off While Solo**, also off while solo. Reads `GetPetActionInfo` autocast flags, as confirmed by probe 1.
  - **Tracking Reminder:** only with Improved Tracking learned, out of combat, for a living hostile target. It names the learned Track spell matching `UnitCreatureType`'s type ID with its icon, e.g. "Track Humanoids (+5%)". Active tracking comes from `C_Minimap.GetTrackingInfo`, as confirmed by probe 1. Lane rows can't be clicked, so it does not switch tracking.
  - **Beast Tooltip** on beasts that aren't player-controlled:
    - family;
    - `UnitAttackSpeed` (1.5 s or faster in gold);
    - "tame: level OK" (green) or "too high" (red), or "learn Tame Beast" without the spell.
    - It speaks to level only: no API says whether a beast is tameable, and Forever allows no taming above your level.
  - Unreadable or restricted answers stay quiet everywhere. Profile key `hunterCues` is in `PROFILE_KEYS`, the QoL reset group and profile resync.
- **E1/E2:** Validate 49 files PASS. Integration 2869 + 161 + 143 + 26 + 44 + **28 hunter cue** checks; `RunIntegration.js` requires every element suite. Installer PASS. Package refreshed to **1.9.2**; Check reports 0 differences.
- **E3 needed:** that `UnitIsFeignDeath` reads true while feigning, the exact Forever trap aura names, Growl on the pet bar, and tooltip lines on live beasts.

### Pet food: Food Button, Feeding View (Grey Out / Food Only) and No / Low Pet Food (Claude, 2026-10-04)
- **Why:** plan 10.3 item 5. Player:
  - "Feed Pet shows every bag item";
  - Blizzard's bags already grey out what Feed Pet can't take, so Ellesmere's bags should behave the same;
  - "anything the pet can eat should become a single row in the bag UI when it's cast";
  - "triggering Feed Pet should bring up the bag UI";
  - lowest-value food.
- **Research (E1):** Blizzard's rule (Blizzard_FrameXMLUtil/ItemUtil.lua, read from the Forever source tree):
  - the item context is Feed Pet when `C_Spell.GetTargetSpellID() == FEED_PET_SPELL_ID`;
  - an item matches when `C_PetInfo.CanPetEatItem(itemID)`;
  - mismatches get a black 0.8 overlay;
  - Blizzard opens all bags on `CURRENT_SPELL_CAST_CHANGED` when `SpellCanTargetItem()` is true, and closes them again if they were closed.

  Ellesmere's bag buttons are the same `ContainerFrameItemButtonTemplate`, but are never told the context changed. This rule also settles the probe's open question of "Feed Pet specifically, not any targeting spell".
- **Result:** new `PetFood.lua` (TOC after PetElements; **full restart**). Unit Frames > Pet Food; everything is off by default.
  - **Feeding View** (Off / Grey Out / Food Only). Ellesmere bags only; Blizzard's own bags stay Blizzard's.
    - When Feed Pet starts targeting, closed Ellesmere bags open through `OpenAllBags` (Ellesmere's hook). They close again through Ellesmere's `ToggleAllBags` only if we opened them.
    - **Grey Out** calls each Ellesmere button's native `UpdateItemContextMatching`, which gives Blizzard's exact overlay. A button without it gets the same black 0.8 overlay drawn by us.
    - **Food Only** hides every non-food item's holder frame and moves the food into the first slots (top row first).
      - Raw meat and anything else the pet eats counts, because every bag item is asked `CanPetEatItem`.
      - Out of combat only. The original places are restored, then Ellesmere re-lays its bags.
      - An Ellesmere refresh mid-feed re-applies it; Ellesmere re-shows its own holders on every refresh.
    - **Restore:** when Feed Pet stops being the target spell (food chosen, cancelled, another spell). A half-second safety check runs only while feeding, in case a cancel fires no event. A restore that would fall in combat waits for combat to end.
  - **Pet Food Button** beside the pet frame.
    - Left click feeds the chosen food (secure macro `/cast Feed Pet` + `/use bag slot`). Right click lists every edible stack.
    - It is built and changed out of combat only, and a state driver hides it in combat and without a living pet.
    - The border shows happiness. With no food it shows the greyed Feed Pet icon with 0 and no action.
    - Unlock Mode mover "Pet Food".
  - **Food Choice:**
    - **Closest To Pet Level** (default);
    - **Cheapest:** the lowest vendor value at most 20 levels below the pet, then the lower level, then the smaller stack. It falls back to the closest food when nothing qualifies. The 20-level floor is the Classic rule, unverified on Forever (E3).
  - **No auto-feed:** WoW only casts Feed Pet from a key press or click. A key binding and a pulse were built, then dropped at the player's request, because the Feed Pet Reminder already prompts.
  - **Pet Food Warning** (Warnings, beside the Feed Pet Reminder): out of combat, No Pet Food or Low Pet Food (n) below a slider (default 10). It is quiet for Lone Wolf, without Feed Pet, and without a living pet.
  - Profile key `petFood` is in `PROFILE_KEYS`, the Unit Frames reset and profile resync. The warning keys live in the profile-scoped `warnings` table.
- **E1/E2:**
  - Validate: 48 files PASS.
  - Integration: 2869 + 161 + 143 + 26 + **44 pet food** checks. New `PetFoodTests.lua` in the element suite; `RunIntegration.js` now fails if that suite doesn't report.
  - Covered: edible scan and cache; unreadable never counts; ranking and Cheapest; secure button, no secure changes in combat with the change after combat; chooser; no-food state; Tame Beast doesn't trigger, Feed Pet does; native overlay path and fallback; Blizzard buttons untouched; open and close; Food Only hide, pack and restore, including after combat; the cancel safety check; non-Hunters get nothing.
  - **No E3.**

- **E1/E2, 2026-10-04:** removed the malformed `/fhkprobe` talent query that omitted `column`. The player's two build-70205 reports contain its exact error; the two remaining complete queries returned nil. The legacy-count talent bridge also supplies required tier/column fields and checks names before table indexing. This does not establish accurate multi-rank talent detection on Forever.
- **E1/E2:** the probe skips raw combat-log event registration when no public reader exists, the client reports restrictions, or its restriction answer is unreadable. The supplied reports list no reader in either namespace and zero raw events. Registration was a suspect for the player's blocked action; the action name/stack is still unknown. No claim that this fixes the block.
- **E1/E2:** `/fhkprobe blocked` copies the last owned-addon block, exact action, attribution and stack for FHKEllesmere, ForeverHunterKeys or FHKGear. It prints before attempting copy-window UI and does not run another probe. The previous `/fhk blocked` only records ForeverHunterKeys, which explains the empty report with an FHKEllesmere popup. Diagnostics stay per character, outside profile exports.
- **E1/E2:** a five-minute callback removes the targeting watcher even when no later game event arrives; another full probe extends its lifetime. Removed the probe's instruction to call `/reload`; no ReloadUI call was added. The Feed Pet cursor sample is now confirmed, but food filtering/flyout is still unbuilt and must distinguish Feed Pet from other targeting spells.
- **E3 observations only:** player reports prove Feed Pet `SpellIsTargeting` true, plain crit/hit outside combat and secret crit/hit in the other sample. The popup names FHKEllesmere. A later screenshot shows the updated probe reporting `combat log unavailable: no public reader`. None proves the new features or blocked-action fix. See [second probe evidence](PROBE_2026-10-04_SECOND_RUN.md).
- **Checks:** 47 owned Lua files validate; **2869 + 161 aspect + 143 pet + 26 probe = 3199** mocked checks pass. ProbeTests and its suite runner also pass ASCII/Lua 5.1 parsing. Gear remains 0.5.1: 467 checks / 17 TOC files pass. Companion and Gear live Check each report zero differences. Companion TEMP UI-only Check -> Apply (3 changed files) -> Check ends at zero differences; existing fixture `%TEMP%/fhk-add-list-190-b69b1d2ee5ea4770b52d4f62cfd08ad0`. No live Apply, third-party, SavedVariables or upstream writes.
- **Loading:** no new TOC entry in 1.9.1; the earlier 1.9.0 aspect/pet files still require the full client restart. User requested a wrap-up and handover to Claude; no further Add features were started.
- **E3, limited retest:** after loading the update the player reported two probe runs without another blocked-action popup. `/fhkprobe blocked` reported no owned-addon block since the patch loaded. Record the probe regression as no longer reproduced in those two runs; the original exact protected action was never captured, and the broader aspect/pet secure-action acceptance remains open.

## 1.9.0 milestone (Add items 1-4; awaiting in-game check)

### Add items 2-4: pet auras/target, XP and feeding reminder (Codex, 2026-10-04)
- **E1/E2:** `PetElements.lua` attaches to the pet health bar through our existing `RefineEllesmereBar` discovery. New widgets use the health bar's public parent and anchors, so they inherit pet-frame visibility and avoid clipping inside the fill. No new Ellesmere namespace discovery or vendor hooks. The observer exists only while a pet element is enabled; repeated host observations return immediately. Layout/host changes defer in combat.
- **E1/E2:** independent **Pet Auras**, **Pet Target** and **Pet XP Bar**, all OFF initially, under **Forever Companion -> Unit Frames -> Pet Auras And Target**. Debuffs first, then buffs; bounded 2-12 icons, stacks, readable cooldown sweeps, overflow `+`, unknown `?`, house tooltips and click-through hover. Harmful effects are red; Curse/Disease/Magic/Poison can be gold when Improved Mend Pet is known. That edge means a possible cleanse, not a guaranteed dispel. [ForeverDB 19572](https://foreverdb.net/spell/19572), checked 2026-10-04; individual public record only, no compiled dataset copied.
- **E1/E2:** fixed secure `pettarget` click action and native unit watch; name/health percentage update from scoped pet/target events. Unknown health shows `?`, with no arithmetic on secrets. Target sizing/gap and aura size/count/offset are configurable. Cosmetic combat updates do not change secure attributes or layout. XP-only creates no aura pool or target button.
- **E1/E2:** XP reads the **global `GetPetExperience`** confirmed by probe 1 and native Camelot PaperDoll callers. `UNIT_PET_EXPERIENCE` uses the **owner `player`** token. Loyalty/training use `C_PetInfo`; the tooltip preserves the loyalty name and computes available points as total minus used. Probe fixture 130/6825, Best Friend, 110 total/7 used -> 103 available. Zero required XP shows Capped; missing/secret values show `?`. Tooltip data is cached on events. Height/offset are adjustable; the bar follows pet-frame width.
- **E1/E2:** **Feed Pet Reminder** and **Remind When Content** under **Forever Companion -> Warnings**. The master is OFF; content preference ON beneath it. Out of combat, content is amber and unhappy is red; happy clears it. Quiet before Feed Pet is learned, with Lone Wolf, dead/missing pets, dead player, mounted/taxi/vehicle, or unreadable happiness. A lazily created driver scopes owner/pet events and coalesces updates; OFF removes its events and invalidates callbacks. No feeding, food choice or targeting action is automated. Feeding-in-progress behaviour remains an E3 observation; edible-food filtering/flyout still waits on probe 2.
- **E1/E2:** `petElements` joins PROFILE_KEYS, Unit Frames Reset and profile resync; feeding lives in the existing profile-scoped `warnings` table. Settings persist with profiles; Reset stops features. Static search labels avoid settings/UI writes. Pet modules add no repeating timer or OnUpdate; target-health and XP events do not scan auras.
- **Validation:** Lua 5.1/ASCII/TOC checks pass for **47 owned Lua files**. `RunIntegration.js` now runs **2869 integration + 161 aspect + 143 pet checks**. New fixtures cover attachment boundaries, debuff-first selection, burst coalescing, no cross-component reads, tooltip caches, nil/secret APIs, missing/dead pet, combat changes, owner XP events, training subtraction, profiles/reset and feeding states. Auto Shot toggling alone does not imply weaving; a recent ranged swing does. Advice preview cannot cast a fake recommendation. Gear stays 0.5.1: **467 checks / 17 TOC files PASS**. E1/E2 only; no new E3 or measured CPU/FPS claim.
- **Loading/acceptance:** full client restart; three new companion TOC files in this batch. [Pet checks](PET_ACCEPTANCE_2026-10-04.md), [aspect checks](ASPECT_ACCEPTANCE_2026-10-04.md). Original pre-batch snapshot remains `Snapshot-20261004-pre-add-list-184918.zip`. No vendor, SavedVariables or live installer Apply writes.
- **Distribution, E2:** refreshed companion 1.9.0 payload; live Check reports 0 differences. Clean temporary UI-only Check -> Apply -> Check passes for 42 files; final single-file update also passed Check -> Apply -> Check. Fixture `%TEMP%/fhk-add-list-190-b69b1d2ee5ea4770b52d4f62cfd08ad0`. Unchanged Gear 0.5.1 live Check reports 0 differences. No live Apply.

### Add list item 1: aspect element (Codex, 2026-10-04)
- **E1/E2:** completed the preserved, previously unloaded aspect draft as `AspectLogic.lua` and `AspectBar.lua`. Enable **Aspect Element** under **Forever Companion -> Unit Frames -> Aspects**. Defaults OFF. Icon shows the active aspect, advice badge and optional name; Bar shows learned secure spell buttons; Current Only opens that bar on hover. Viper/Falcon are excluded. Key labels read actual spell/macro bindings; no binding writes.
- **E1/E2:** range holds for 0.75 seconds and ordinary combat advice changes at most every 2 seconds. Cheetah/Pack and confirmed missing aspect in combat use a red pulse; range/style advice uses gold, travel advice is dim. Dead, mounted, taxi, vehicle or unreadable aura/state suppress advice. Level-one characters with no learned aspects are not nagged. Auto style reads owned talent data and recent ranged swings; explicit Ranged/Weave/Melee overrides remain available.
- **E1/E2:** built numeric learned-spell actions out of combat. Restricted public hover handlers open/close Current Only in combat; aura updates repaint textures/edges without moving buttons or changing actions. Layout, learned-spell and disable changes defer to combat end. Optional advice click is out of combat only and defaults OFF. Disabled state drivers are removed so combat transitions cannot reshow disabled elements.
- **E1/E2:** eight color swatches, size, gap, orientation, key/name toggles, dimming, advice controls, visibility, preview and Unlock Mode placement. Settings/colors/position are profile-scoped; plugin Reset now resyncs live companion features. Search prebuild emits all labels without settings writes or UI creation. Uses public Ellesmere borders, font and mover APIs; default placement is movable near the player area, without a private native-frame anchor.
- **E1/E2:** replaced our duplicate Cheetah/Pack text while the element is enabled, including the preview and duplicate event registrations. Disabling it restores an enabled lane warning. Native Missing Aspect/H02 remains a player setting; turn it off if both cues overlap.
- **Performance, E2:** no feature events or UI while initially OFF; no repeating timer without a living hostile target. The target-scoped 0.25-second check uses cached spell/aura data. Spell bursts coalesce; Icon mode has no cooldown listener, and explicit style has no swing listeners. No measured CPU/FPS claim.
- **Validation:** current batch counts above supersede the initial aspect pass. **161 aspect checks** also run separately with `RunAspectTests.js`. Fixtures cover decisions, hysteresis, learned ranks, actual modifier binds, aura errors/secrets, stale events, profile/reset, disabled work, combat attributes, restricted-hover scripts, visibility and cooldowns. These remain E2; the mock does not prove taint, actual clicks, secret behaviour or geometry in game.
- **API evidence, E1:** Blizzard public source branch `forever`, commit `9a789c074b8e73c5d604ef2d6af3bb5b3aefb348`: Spell/SpellBook, UnitAura, Unit and SwingTimer documentation, SecureHandlers/RestrictedFrames/SecureStateDriver and secure templates; plus plan 7.1's highest-known-rank probe. No vendor implementation, SavedVariables or live installer write. Snapshot `Snapshot-20261004-pre-add-list-184918.zip`.
- **Loading:** full client restart. [Exact in-game checks](ASPECT_ACCEPTANCE_2026-10-04.md). Pet auras/target, XP and feeding reminder were completed in the continuation above; feeding filters still wait on probe 2.

## Historical 1.8.0 additions (completed and packaged; awaiting in-game check)

### Forum requests: broader review and to-do cross-reference (Codex, 2026-10-04)
- **E1, docs:** indexed 532 exported threads / 1,585 message records; screened requests and checked the relevant live owned/native source against the existing forum triage and master list. New `FORUM_REQUESTS_REVIEW_2026-10-04.md` records source links, current coverage, recommendations and research gates. Earlier triage labels are historical where superseded.
- **E1:** Xhor's aura-display request is substantially covered by native All Buffs/All Debuffs and movers; start with setup/E3 and a possible simple preset. Incoming-heal prediction with separate own/other colours is already in installed player/target/focus frames. Mana-cost prediction exists on both native power-bar hosts; PvP faction flags also exist. No new E2/E3 claim.
- **E1:** plan section 11 adds candidate IDs FR21-FR33, including map reveal/zone levels, mana-aware visibility, spell-rank review, gathering tracking, PvP class/active-aura clarity and independent elite/quest indicators. Arena/trinkets stay research-gated. The player's ten Hunter Priority 1 items keep their order; previously built enhancements remain built E2 with live acceptance open.
- **E1:** corrected XP-dedupe scope: native completed-quest text does not itself replace the requested yellow fill; share validated totals and remove only equivalent duplicate work.
- **Validation:** source-link/ID and document-reference checks only. No runtime, third-party, SavedVariables, package/installer or upstream write; no reload needed. Documentation backup: `.dev/thread-suggestions-review-20261004/docs-before/`.

### Master to-do reconciled with the player's list (Codex, 2026-10-04)
- **E1, docs:** plan section 10 moves the six built enhancements into Crossed off, keeps aspect warning integration and XP dedupe open, preserves the player's Add order and labels the aspect bar as designed only. Built does not mean verified in game.
- **E1:** core Check identifies installed 9.3.5 pre-release (2d061e23); 22 files already applied, 0 changes. The release/main choice and live probe remain pending.
- **Distribution (E2):** refreshed Gear 0.5.1 and companion 1.8.0 payloads; both live Check plans report 0 differences. Gear clean temporary Check -> Apply -> Check passes (23 payload files). No live Apply or vendor/SavedVariables edits; the handover records the fixture and rollback snapshot.
- **Existing E2 reproduced during handover:** Gear 0.5.1, 467 checks / 17 Lua files; companion 2847 checks / 45 Lua files. No new runtime change or E3 in this docs/package reconciliation.

### Nameplates: green edge for mobs on your pet; Warnings: hide errors a warning already shows (Claude, 2026-10-04)
- **Why:** master to-do §10.2, items 6 and 7.
  - Forum: "who is the enemy hitting" (5) and enemy target on nameplates (16). Pet tanking is how a Hunter levels.
  - Plan §1.K: one problem should show once, not as a warning plus a red error line.
- **Result:**
  - **Green Edge When Attacking Your Pet** (Nameplates, under Gold Edge When Attacking You; off by default).
    - An enemy in combat whose target is your pet gets a thin pet-green edge (the happy-pet colour).
    - Gold (on you) wins over green; no edge means someone else.
    - It uses the existing gold-edge frame and event path, and repaints only when the colour changes.
    - New profile key `petAggroPlates` is in `PROFILE_KEYS` and the Nameplates reset group.
  - **Hide Errors A Warning Shows** (Warnings, beside Hide Spam Errors; off by default). It hides these red error lines while their matching warning is on:
    - "Target too close" (range indicator);
    - facing errors (Face Target);
    - out-of-ammo errors (ammo warning);
    - "Your pet is dead" / no pet (pet warning).
  - **How it works:**
    - The first matching `UI_ERROR_MESSAGE` (matched by the client's own global string) teaches us that error's message type. The type is then switched off with the same native `SetMessageTypeEnabled` the spam filter uses.
    - If a learned type later carries a different message, the type is shared by other errors: it goes back on for good, and that message is shown.
    - Types Blizzard or the spam filter already hide are left alone.
    - Turning off a warning, or the option itself, restores every type it hid.
    - The event is registered only while the option is on.
  - **Constant names unconfirmed:** `SPELL_FAILED_NO_AMMO`, `SPELL_FAILED_NEED_AMMO`, `PET_SPELL_DEAD` and `SPELL_FAILED_NO_PET` are standard client global strings but are not in the sparse Forever UI source. A missing one simply never matches. E3 will show which fire.
- **E1/E2:** Validate PASS. Integration **2847** (+14):
  - pet edge: green, gold wins, someone else gets none;
  - routing: off by default; Too Close hidden once learned; unrelated errors never hidden; a shared type goes back on and shows the swallowed message, and is never hidden again; follows the ammo toggle; off restores.
- **No E3. No new files.**

### Swing timer: Active Row Only, Auto Shot latency zone, weapon spark colors (Claude, 2026-10-04)
- **Why:** master to-do §10.2 item 5. Forum requests:
  - hide the swing you aren't using (4 + 1);
  - a latency segment "so Hunters know when it's safe to move" (5);
  - spark colour per weapon (3).
- **Result:** three new rows in Resource Bars > Swing Timer > Hunter Timing, all off by default.
  - **Active Row Only:**
    - no weave READY states;
    - while meleeing without Auto Shot, the bow row (reset by every swing) stays hidden;
    - a real weave still shows BOTH CD.
  - **Auto Shot Latency Zone:**
    - a red band (45 % alpha) at the end of the Auto Shot row, the width of your world latency;
    - it sits on the right edge while filling and the left edge with Deplete Fill;
    - `GetNetStats` is read at most every 10 s, and only while the zone shows;
    - the zone is advisory and changes no timer.
  - **Weapon Spark Colors:**
    - ranged, main-hand and off-hand spark swatches on the row;
    - defaults are the bright shooting jade, melee violet and warm white, so the spark reads against the deep fills;
    - off keeps the thin white line.
  - Settings live beside the native swing settings (`swingTimer.fhkActiveRowOnly`, `fhkLatencyZone`, `fhkSparkColors`, `fhkSpark`), so they travel with the Ellesmere profile like `hunterMode`.
- **E1/E2:** Validate PASS (the US-spelling label rule caught "Colours"). Integration **2833** (+9):
  - active row only while shooting and while meleeing, and off restores;
  - the latency zone's width (120 ms of a 3 s shot = 4 %), its edge, and off hides it;
  - spark colour on, and off restores the white line.
- **No E3. No new files** (`/reload` is enough).

### Pet happiness: Hide When Happy; ammo warning names wrong or unequipped ammo (Claude, 2026-10-04)
- **Why:** master to-do §10.2, items 1 and 3.
  - Hide When Happy is a forum request (3 reactions).
  - The ammo warning said nothing when arrows sat in the slot with a gun equipped, and "Out of Ammo" when the slot was only empty.
- **Result:**
  - **Hide When Happy** (Unit Frames > Colour and Text Refinements, under Pet Happiness Style; off by default).
    - While the pet is happy, the happiness icon fades out and its hover is dropped.
    - The dark-theme happiness strip hides too.
    - Content or unhappy brings both back at once.
    - The native icon is faded, not hidden, so Ellesmere's own Show/Hide stays in charge.
    - New profile key `petMoodHideHappy` is in `PROFILE_KEYS` and the Unit Frames reset group.
  - **Ammo warning** (`Warnings.lua`), new states:
    - **Wrong Ammo - Equip Bullets:** the wrong ammo is in the slot and fitting ammo is in your bags.
    - **Wrong Ammo - No Bullets in Bags.**
    - **Ammo Slot Empty - Equip Arrows:** the slot is empty while fitting ammo is in your bags.
    - All three are critical (they show in combat).
    - Bows and crossbows take arrows; guns take bullets.
    - Bags are scanned only while the slot is empty or wrong, so nothing extra runs while you shoot.
    - FHK Gear's Auto-Equip Better Ammo fixes the slot by itself when it is on. The warning then clears on the equipment event.
- **E1/E2:** Validate 44 files PASS. Integration **2824** (+10):
  - Hide When Happy is off by default, fades the icon only while happy, returns when content and restores when turned off;
  - wrong ammo is found, with and without fitting ammo in the bags, and the text names what to equip;
  - an empty slot with ammo in the bags is reported;
  - fitting ammo is ok.
- **No E3. No new files** (`/reload` is enough).

### Master to-do: one list of done, enhance and add (Claude, 2026-10-04)
- **Why:** player: "flesh out the todo list, see what we've crossed off, where we just need to enhance, where we need to add".
- **Result (docs only):**
  - [FOREVER_HUNTER_COVERAGE_PLAN.md](FOREVER_HUNTER_COVERAGE_PLAN.md) gains §10, merging the coverage matrix, the designs, the forum to-do and FHK Gear into Crossed off / Enhance / Add / Waiting.
  - Coverage-matrix rows that FHK Gear 0.5.0 now covers are updated: ammo slot, wrong ammo, quiver haste, weapon skill, gear and quest rewards.
- **E1:** text only; no addon file changed.

### `/fhkprobe`: one-shot read of the Forever client facts the plan needs (Claude, 2026-10-04)
- **Why:** player: "/fhkprobe did nothing". The command was only proposed in [FOREVER_HUNTER_COVERAGE_PLAN.md](FOREVER_HUNTER_COVERAGE_PLAN.md) §7 and had never been built; my summary wrongly suggested starting with it.
- **Result:** `/fhkprobe` (end of `HunterTalents.lua`, already in the TOC, so `/reload` is enough) reads every §7 question once:
  - build;
  - Lone Wolf;
  - the talent APIs;
  - top-rank aspect/mark/aura descriptions;
  - pet existence and death, XP, loyalty, training points, happiness, talent tree and food types;
  - the pet bar's autocast flags with `PET_MODE_PASSIVE`;
  - the tracking API names and entries;
  - the combat-log function;
  - `SpellIsTargeting`;
  - item stats from the equipped ranged weapon;
  - crit and hit.

  Every call is protected. A missing API reads `missing`, an error reads `error: ...` and a secret value reads `<secret>`. It prints the answers to chat and saves them to `FHKEllesmereDB.probe`, which is per character on purpose (diagnostics, not a profile key). For 5 minutes after typing it, it also counts combat-log sub-events and records whether choosing Feed Pet's food counts as spell targeting. Nothing runs until the command is typed.
- **E1/E2:** Validate 44 files PASS. Integration **2808** (+8): registered; survives missing, failing and secret answers; multiple returns recorded; pet-bar flags listed; absent API reported; never writes profile keys; confirms the save.
- **E3 (first run, player screenshots):** the probe ran and answered every question it could. Answers recorded in the plan, §7.1. Key facts:
  - `C_PetInfo` gives pet XP, loyalty name, training points and happiness;
  - the tracking list comes from `C_Minimap.GetTrackingInfo`;
  - `CombatLogGetCurrentEventInfo` is nil;
  - the classic talent APIs are missing, and `C_SpecializationInfo.GetTalentInfo` wants `query.tier`;
  - pet modes are Assist / Defensive Assist / Passive tokens (the pet was on Passive).
- **Follow-up (E2, 2809):**
  - The probe now also tries the tier/column talent query shapes, lists `C_CombatLog` and counts raw combat-log fires.
  - The combat-log watcher reads through `C_CombatLog.GetCurrentEventInfo` when present.
  - Plain `/fhkprobe` prints only a summary; `/fhkprobe all` prints every line, and the saved copy always has everything.
- **Copy window (E2, 2814; player: "capture to a file or to a lua frame so I can copy it"):**
  - `/fhkprobe` opens a movable window with every answer (plus combat-log and Feed Pet samples), already selected for Ctrl+C. Esc closes it.
  - The box is read-only: a stray key restores the text.
  - If the window can't be built, the summary line says so instead of failing.
  - Fixed a test-only bug: a local `saved` shadowed the table used to restore the mocked globals.

### Learned-talent checks for talent-driven Hunter features (Claude, 2026-10-04)
- **Why:** player: "some are tied into talents, so we should bring in the respective checks for that talent and check if it's learnt". ForeverDB (client build 70205) shows Forever Hunter talents that change what a cue should do, e.g. Lone Wolf (+20 % damage without a pet).
- **Result:**
  - New `HunterTalents.lua` (TOC after `Profiles.lua`; shared on the namespace, first copy wins, like `RangeLogic`). It keeps a table of 23 Forever Hunter talents by spell ID and reads ranks only when talents/spells/level change, coalesced to one refresh. Read order: talent window by localized name, then "talent spell known", else unknown. Unknown never enables a feature. Non-Hunters register nothing. `/fhktalents` prints each rank and how it was read.
  - First use: the in-combat **Call / Revive Pet** cue (`Warnings.lua`) stays quiet for Lone Wolf, and warnings re-check after talent changes. The Ellesmere-side H01 reminder has the same rule (core 0.4.0).
  - Gating rule and the talent → feature map: [FOREVER_HUNTER_COVERAGE_PLAN.md](FOREVER_HUNTER_COVERAGE_PLAN.md) §0.1.
- **E1/E2:** Validate 44 files; integration **2800** (+19: talent-window rank by name, fallback, unknown, one refresh per event burst, faulty listener isolated, non-Hunter idle, first-copy-wins, Lone Wolf cue suppression/return, blocked client). Also PASS on staged release and staged main; theme 553; installer PASS; package refreshed, Check 0 changes. **New TOC file: full client restart.** No E3: run `/fhktalents` in game to confirm which read path Forever answers. Backup `Snapshot-20261004-pre-hunter-talents.zip`. The refresh also packaged another session's `FULL_KEYMAP.md` edit.

### Ellesmere 9.3.5 release/main compatibility, module map and integration audit (Claude, 2026-10-04)
- **Why:** the player asked to merge our patch with Ellesmere's new 9.3.5, update the patcher and audit whether the patch can live inside Ellesmere's own modules. Full record: [ELLESMERE_935_MERGE_AUDIT_2026-10-04.md](ELLESMERE_935_MERGE_AUDIT_2026-10-04.md).
- **Result (tooling and docs only; no live addon file changed):**
  - `RunIntegration.js`, `RunThemeChecks.js` and `Validate.js` accept `FHK_GAME_ROOT` (a staged game root). Native slices are searched across every Lua file of a module, so upstream file splits don't break the adapters. The XP adapter handles 9.3.5's `UpdateXPBar(levelUp)` / `XPPaintText`. `Validate.lua` mocks the new upvalues and the readout dirty flag. `ValidateThemes.lua` loads the installed options-extension file first.
  - New `GenerateModuleMap.js` → [ELLESMERE_MODULE_MAP.md](ELLESMERE_MODULE_MAP.md) (+ `_main`): every Ellesmere module's files, hook points, settings keys, events, frames and options page/section/control list.
  - The audit maps every companion feature to its native home (page > section, function), marking each in-module, standalone or drop (now native). It also covers the Hunter notification gaps, aspect clarity, the beast tooltip (beastmaster.io reuse limits) and the keybind non-overwrite rule.
- **E1/E2:** all native identifiers we use still exist in the release and main. Validate 43 files, integration **2781**, theme/class **553** PASS on live, the staged release and staged main. Installer validation PASS. No E3.
- **Note:** the package Check reports 1 file ahead in live: `ForeverHunterKeys/FULL_KEYMAP.md` (Razer Chroma section added by another session at 10:14). Not refreshed here; run `RefreshPackage.js` when that work lands.

### Performance pass: player-only events, batched repaints, no per-tick tables (Claude, 2026-10-03)
- **Why:** player: "let's look at performance enhancements across Ellesmere". `/fhkperf` (62 FPS): all addons 0.33 ms per frame; FHKEllesmere highest at 0.078 ms. Steady-state cost is about 2% of a 16 ms frame, so the targets were work done for nothing and garbage that feeds collection hitches. Ellesmere's own modules are third-party and unchanged.
- **Result:**
  - **Spellcast events are player-only** (`RegisterUnitEvent(event,'player')`): SwingIntegration, HunterRuntime, ActionPressFeedback (cast mode) and FHK `SwingBars.lua` (plus its `UNIT_INVENTORY_CHANGED`). Before, every nearby unit's cast ran our handlers. SwingIntegration queued a **full swing-row sync** and SwingBars ran a full `Refresh()` for each of them. Each handler still checks for the player; a plain `RegisterEvent` fallback is kept for clients or mocks without unit registration.
  - **Resource bar text:** health/power events are player-only (they fired for every nameplate). Paint no longer builds about a dozen tables per call; it ran on every player power tick.
  - **Unit frames:** threat, faction and target-change events (`UNIT_THREAT_*`, `UNIT_FACTION`, `UNIT_TARGET`) used to repaint every unit frame immediately, once per mob per change. Nameplate copies are now skipped (the target/focus token fires too), and the rest share one repaint on the next frame. The 0.15 s busy sweep remains the backstop.
  - **No per-tick tables:**
    - cursor swing rings (20 Hz; 5 tables per tick);
    - swing rows (20 Hz; the row list is cached until Ellesmere adds a row);
    - HunterRuntime (20 Hz).
  - **`/fhkperf mark`:** sets a baseline, so the next `/fhkperf` counts frames over 50 ms **since the mark**. Without a mark it says that peaks include login and loading screens.
  - **Static guard:** `Validate.js` fails if a `UNIT_SPELLCAST_*` event is registered for all units again.
- **E1/E2:**
  - Validate (with the new guard), integration **2781** (batched threat repaint, nameplate copy ignored, `/fhkperf mark`), theme checks 553, installer and all 16 FHK Python suites PASS.
  - `Apply.ps1 -Mode Check`: 0 files need changes. Package refreshed.
  - No E3: the frame-time effect needs an in-game `/fhkperf mark` session.

### Attack squares: opacity, show-while-off, artwork note (Claude, 2026-10-03)
- **Why:** player asked to make sure the patch offers the customization options for today's changes. Audit of today's features against their settings: in the Either Side of Range layout, **Attack Indicator Opacity** was ignored and **Attack Indicator Artwork** silently did nothing; there was no way to keep the squares up while attacks are off. Everything else (combat icon style, loot icon, flee mark, ToT gold, swing READY toggles, cursor radius/texture, range block, text slots) already has a setting.
- **Result:**
  - The squares and their labels follow Attack Indicator Opacity, including the onset pulse.
  - New toggle **Show Attack Squares While Off** (`indicators.attacks.showIdle`, default off; per-profile through `indicators`): keeps both squares up as quiet grey when no attack is on.
  - A label row says that the Either Side of Range layout uses framed squares and that the artwork choice applies to the other layouts.
  - Switching layouts clears the label opacity, so the glyph layouts are not dimmed twice.
- **E1/E2:** integration (show-while-off, opacity, defaults, layout switch) PASS within the 2781 above. No E3.

### READY states only when they ask something of you (Claude, 2026-10-03)
- **Why:** player: "the melee bar only needs to be purple when in range... Auto Shot ready is also flashing green the minute it's ready, but this only matters when one's on cooldown". With Auto Shot switched on, the gap between its timer ending and the next shot firing faded the row out and back in, or flashed AUTO SHOT READY in jade, though Auto Shot fires by itself.
- **Result:**
  - While Auto Shot is on, its row holds through that gap: no fade, no READY flash.
  - AUTO SHOT READY appears only while melee is cooling **and** Auto Shot is off (after a weave, when you need to press it).
  - MELEE READY is unchanged: violet only with the target in melee reach, grey otherwise.
- **E1/E2:** integration **2772** (row held between shots, no READY with Auto Shot on, READY with it off); Validate, theme checks and installer PASS; package refreshed. No E3.

### BOTH CD moves to the melee row; AUTO SHOT READY (Claude, 2026-10-03)
- **Why:** player:
  - "when the melee weapon swing timer is longer than the Auto Shot, the Auto Shot should be ready before the melee: Auto Shot ready, melee swing timer then continues";
  - "that's why the BOTH bar is always in the melee row". The melee swing puts both on cooldown; FHK's `resetRangedOnMelee` restarts the bow at full ranged speed on every swing.
- **Result (combined layout):**
  - While both cool, the **melee row** reads **BOTH CD** (slate), and the Auto Shot row folds away. Its full bar is the time until the **first** attack frees up (player's example: melee 2.8 s, Auto Shot 2 s, so BOTH fills over 2 s). Then the attack that is still cooling runs a **fresh bar for just its remainder** (here 0.8 s on the top bar). An intermediate version that ran BOTH on the last-ending clock was replaced the same session (player: BOTH should last only until Auto Shot is ready, so you can tell when you can shoot again).
  - Faster melee: BOTH fills over the melee time, then MELEE READY on top and the Auto Shot row runs a fresh bar for its remaining cooldown.
  - Slower melee: BOTH fills until Auto Shot is ready. Then **AUTO SHOT READY** appears on the Auto Shot row below (full bar; jade in shooting range, grey in the deadzone, melee or 35+) while the top bar runs the melee remainder as MELEE.
  - Auto-attacking in melee, both always cool, so the melee row is the BOTH CD bar.
  - The melee row's timer is re-armed to the right clock whenever Ellesmere's own swing event moves it.
- **E1/E2:** integration **2770** (weave after stepping out; faster and slower weapon cases with labels, timers and folding; auto-attacking in melee); Validate, theme checks and installer PASS; package refreshed. No E3.

### Swing timers show whenever they cool; melee timer in melee (Claude, 2026-10-03)
- **Why:** player: the timers "should come up and show whenever something's on cooldown", not only while an attack is switched on, "maybe that's why the melee swing timer isn't showing when I'm in melee range and auto attacking". Confirmed in code: in melee each swing resets the bow clock, so both cool. The combined layout folded the melee row into BOTH CD, and the attack-on rule hid the Auto Shot row (Auto Shot off), so nothing showed. This supersedes the attack-on-only rule above for the swing rows and rings. The attack squares beside the range block still show only while their attack is on.
- **Result:**
  - A swing row shows whenever its timer is cooling, as does each cursor sweep.
  - MELEE READY shows while shooting or auto-attacking.
  - While auto attack is on, the melee row shows its own swing beside BOTH CD (violet in reach). After a weave with auto attack off, BOTH CD alone covers both.
  - The 0.1 s per-shot blip filter, BOTH CD counting to the first attack free, and grey-out-of-reach are kept.
- **E1/E2:** integration **2769** (cooling timer shows with nothing switched on; nothing cooling and nothing on hides; auto attacking in melee shows a violet melee row beside BOTH CD; cooling cursor sweep shows); Validate, theme checks and installer PASS; package refreshed. No E3.

### BOTH CD counts to the first attack that frees up (Claude, 2026-10-03)
- **Why:** player: "when the melee weapon is faster, melee auto might come up again before the ranged Auto Shot is ready... if the melee swing timer is longer, the ranged weapon is ready before the melee weapon". BOTH CD had followed the Auto Shot clock, so with a faster melee weapon its countdown ran past the moment melee was free.
- **Result:**
  - In combined mode with both busy, the BOTH CD row is driven by whichever clock ends first.
  - Faster melee: BOTH CD runs to the melee timer, then the row re-arms to the Auto Shot clock (AUTO SHOT, remaining time) and MELEE READY shows.
  - Slower melee: BOTH CD runs to Auto Shot, then AUTO SHOT is free and the melee row shows the rest of its swing (grey out of reach). The melee row now also shows a real swing still cooling with auto attack off, a weave after stepping out.
- **E1/E2:** integration **2767** (both weapon-speed cases: countdown target, hand-over labels and timers, melee remainder shown); Validate, theme checks and installer PASS; package refreshed. No E3.

### MELEE READY for weaving; the per-shot blink fixed at its cause (Claude, 2026-10-03)
- **Why:** player: "the melee bar should show but grey when ready but the current target is out of range, in case you want to melee weave, as the other target will be in range but not targeted". The `/fhkswingdebug` trace showed the cause of the earlier "bugging out": each Auto Shot set the melee clock busy for about 0.1 s (busy=true at 194255.24-.30, false at .36) with auto attack off. In combined mode that hid MELEE READY and turned the Auto Shot row to BOTH CD on every shot.
- **Result:**
  - The melee clock counts only while auto attack is on, on the bars and on the cursor, so the per-shot blip no longer touches either row.
  - While Auto Shot is on, the melee row shows MELEE READY: grey with the target out of melee reach, violet in reach. While auto attack is on it shows the melee swing as before. With neither on, both rows hide.
  - The cursor's violet melee-ready ring may show while shooting, but only when the target is in reach.
- **E1/E2:** integration **2762** (MELEE READY grey while shooting at range, per-shot blip keeps the row and no BOTH CD, both rows hide with neither attack, melee row with auto attack); Validate, theme checks and installer PASS; package refreshed. **E3** for the trace evidence only.
- **Follow-up (player: "if I melee and walk out of melee range the BOTH bar should be coming back in... when you melee both are on CD anyway"):** ignoring the melee clock without auto attack also hid a real weave. A melee clock now counts while auto attack is on **or** when it is a real swing (duration 0.5 s or more, `NS.EllesmereRealMeleeSwing`), on the bars and the cursor. The 0.1 s per-shot blip stays ignored. A weave shows BOTH CD after stepping out even when Auto Shot switched auto attack off. Integration **2763**.

### Attack squares only while their attack is on (Claude, 2026-10-03)
- **Why:** player screenshot plus `/fhkswingdebug` trace. The trace confirmed the melee swing row stays hidden (`wanted=false alpha=0`) while only Auto Shot runs (**E3** for the swing-row rule). But both squares beside the range block showed with any hostile target: "should only show when Auto Shot or melee is active".
- **Result:** a square appears only while its attack is switched on (retry counts for Auto Shot), fading in with its one pulse and out when the attack stops. Nothing shows beside the block when idle.
- **Note:** the screenshot showed 20-unit squares without labels, the previous Combat Layout values. `/fhklayout` must be re-run for the 18-unit squares with labels and the lifted block.
- **E1/E2:** integration **2761** (no square with no attack; only the Auto Shot square with Auto Shot on); Validate, theme checks and installer PASS; package refreshed.

### Swing timers show only while their attack is on (Claude, 2026-10-03)
- **Why:** player: "auto swing timers should only come in when they're active, not be permanently there... when Auto Shot is active it shows, when auto attack is active it shows". The MELEE READY row appeared on every Auto Shot cycle with auto attack off. That was the "bugging out", not only its colour.
- **Result:**
  - The AUTO SHOT row shows only while Auto Shot / Shoot / Throw is switched on (a retry or cast cue counts). The MELEE row shows only while auto attack is on, and MELEE READY means melee is idle while auto attack runs.
  - Switching an attack off fades its row out even with a timer still running.
  - The cursor's Auto Shot and melee rings follow the same rule.
  - State comes from live `IsCurrentSpell` (75, 5019, 2764, 6603) plus the companion's start/stop event state (`NS.EllesmereAttackState`, shared as `NS.EllesmereAttacksOn`).
  - The swing integration now also refreshes on `START_AUTOREPEAT_SPELL`, `PLAYER_ENTER_COMBAT` and `PLAYER_LEAVE_COMBAT`.
  - The native "always show" option (`hideWhenIdle=false`) still keeps both rows up.
- **E1/E2:** integration **2760** (melee row hidden with auto attack off while Auto Shot cycles, Auto Shot row hidden when off with a running timer, both shown when on, cursor sweep follows); Validate, theme checks and installer PASS; package refreshed. No E3.

### Diagnostic: `/fhkswingdebug` (Claude, 2026-10-03)
- **Why:** player: "the melee ready still bugging out on the swing timer" after both colour fixes. The cause could not be identified from code alone.
- **What:** `/fhkswingdebug` toggles a chat trace of the melee swing row. One line per change of `wanted`, `ready`, `busy`, `rangedBusy`, melee reach, range state, fill colour and row alpha. Off by default; zero cost while off. E1 (parses; suites PASS 2754).

### One indicator frame; attack squares beside the range block (Claude, 2026-10-03)
- **Why:** player:
  - picked option A: framed squares with labels underneath, lifting the range block 10 units;
  - "range indicator, combat indicator, happiness should all use the same framing" as the racial (Cooldown Manager) icons;
  - "retry should replace the Auto Shot square when retrying, as only Auto Shot can be retried; keeps things clean".
- **Shared framing (Bootstrap):** `NS.AddEllesmereFrameBorder` (Ellesmere's own `PP.CreateBorder`, the Cooldown Manager icon border; four-strip fallback) and `NS.CreateEllesmereFramedBlock`, a flat fill inside it. Now used by:
  - the range colour block (replaces its separate outline texture);
  - the white combat blocks (player, pet, target);
  - the happiness square;
  - the attack squares.
- **Attack squares (`flank` layout):**
  - Framed 18-unit squares: Auto Shot / Shoot / Throw on the left, melee on the right, 6 units from the block, labels underneath.
  - Shown with a hostile target, like the block. Idle: dark slate square, grey label. Running: the attack's fill (jade / violet) and bright label, with one pulse as it lights, then static.
  - Retry turns the Auto Shot square lime and its label reads RETRY; the separate retry glyph stays hidden in this layout. Horizontal and vertical layouts keep the glyphs.
- **Combat Layout geometry (with undo):** the range block and squares share a bottom line at y -118 (block lifted 10 units, now -104 to -118). The labels end 2 units above the swing bars. The essential cooldown row rises to y -78 (bottom 2 units above the squares; it is empty in the player's setup).
- **E1/E2:** Validate PASS; integration **2754** (framed block helper, square states idle/running/retry, label under the square, retry glyph hidden, layout restore, range block border shown and hidden by style, combat block and happiness square on the shared frame, geometry); theme checks 553; installer PASS; package refreshed. No E3.

### Attack indicators either side of the range block (Claude, 2026-10-03)
- **Why:** player: "put the auto indicators either side of the range bar: right for Auto Shot / ranged attacks like wanding, left for melee, and the middle for retry".
- **Result:**
  - New attack indicator orientation **Either Side of Range** (`flank`): the ranged cell (AUTO / SHOOT / THROW) on the left, melee on the right (player flipped it after the first build), retry centred, briefly over the range block while it shows. Gap = space between each icon and the block; the middle width follows the range block width.
  - Combat Layout (with undo): flank, gap 6, labels off (position says what each is), 20-unit icons, row top at y -108, so the icons share the block's bottom line (-128) and stay 2 units above the swing bars. Horizontal and vertical layouts restore the original placement (retry 28 u, right of the row).
- **E1/E2:** integration **2745** (flank geometry, sides, centred unlabelled retry, restore on horizontal, layout writes); Validate, theme checks and installer PASS; package refreshed. No E3.

### MELEE READY no longer flashes violet at range (Claude, 2026-10-03)
- **Why:** player: "melee ready is flashing purple sometimes when an Auto Shot goes off regardless of our range; it should only be purple when we can use it or we're in the deadzone".
- **Cause (two paths):**
  - The shared melee check counted an `unknown` range read as actionable, so a momentary unknown read as a shot fired lit the row violet for the 0.2 s cache.
  - A native fill repaint was only invalidated, so Ellesmere's own colour could show until the next 50 ms tick.
- **Result:**
  - Actionable means melee or deadzone. An unknown read keeps the last real answer for the same target (by GUID); only a target never read counts as actionable, as before.
  - A native repaint of the fill is overwritten in the same call (merged rows excepted, which Ellesmere hides).
  - The cursor's melee-ready ring uses the same check.
  - **Follow-up (player: "still flashing purple when out of melee range and an Auto Shot has just reset the swing timer"):** the first fix covered only the ready state. An Auto Shot resets the shared clock, which reads briefly as a melee swing (cooling), and cooling still painted violet. Out of reach, the melee row is now quiet whether ready or cooling, and the cursor's melee sweep is hidden. Integration **2746** adds that case.
- **E1/E2:** integration **2741** (out of reach quiet, unknown keeps quiet, native repaint overwritten, deadzone violet, new unread target actionable); Validate, theme checks and installer PASS. No E3.

### Cursor swing rings keep their weapon colour (Claude, 2026-10-03)
- **Why:** player: the GCD ring (white) and the swing ring (grey when both swings cool) "look very similar".
- **Result:** cooling cursor rings always show their weapon colour, jade for Auto Shot and violet for melee, including when both cool. The grey both-cooling ring colour (earlier today, replacing red) is removed from the cursor only: two sweeping rings already say both are cooling, and the swing bars keep their slate BOTH CD. White now means only the GCD at the cursor.
- **E1/E2:** integration **2736** (both-cooling rings jade and violet); Validate, theme checks and installer PASS; package refreshed. No E3.

### In-game confirmation, combat (player screenshot, 2026-10-03, vs Thistlefur Shaman at 10-20 yd)
- **E3 (seen working in game):**
  - compact cursor stack hugging the cursor (swing-sweep anchor fix);
  - gold plate edge while the mob attacks the player;
  - gold target of target ("Wolf") from a hostile target;
  - bold flee notches at 20 % on the target frame (mob at 17 %);
  - target text `perhpnum` / `levelname` / `perppnum` with the level kept on a truncated name;
  - range strip on the target frame's centre-facing edge;
  - MELEE READY quiet at range;
  - player and pet white combat blocks, happiness square;
  - target debuffs above the frame.
- **Observed:** at 10-20 yd five elements were gold at once: range block, frame strip and plate text (the approaching-deadzone gradient) plus plate edge and target of target ("act now"). That is two meanings in one colour on screen together. Follow-up offered to the player.

### Cursor ring matches the other rings (Claude, 2026-10-03)
- **Why:** player: patch "the default cursor highlight ring... the one that's class coloured, to make it align with the others".
- **Result:** Combat Layout sets Ellesmere's cursor ring art to `ring_thin` (was `ring_normal`), with undo, and calls `_ECL_Apply`. Size (base 28 x scale 0.6 = 17 u) and class colour are unchanged: its outer edge (r8.4) already sits 1.5 u inside the GCD ring's inner edge (r11 x .906 = 9.97), the gap every ring keeps. All five rings now share one band weight.
- **E1/E2:** integration **2736** (art set, size kept, refresh called, undo restores); Validate, theme checks and installer PASS; package refreshed. No E3.

### Fix: swing sweep rings never took their size (Claude, 2026-10-03)
- **Why:** player screenshots after three sizing passes: "still too large in radius; the GCD and cursor are kinda perfect size". Measured against the GCD ring in the same image, the swing sweep was about 64 u across, every time.
- **Cause:** `CooldownFrameTemplate` anchors to all points of its parent; Blizzard's own uses (EquipmentFlyout, PaperDoll) inherit it with no anchors and fill their button. The sweep's `SetPoint('CENTER')` + `SetSize` left those anchors in place, so the sweep always filled the 64-unit root. Only the ready rings (plain textures) and the mocked widths followed the maths; the passes above changed the GCD/cast rings in game but never the sweep.
- **Fix:** `cd:ClearAllPoints()` before `SetPoint('CENTER')` in `SwingCursor.lua`, so the sweep takes its computed size (Auto Shot r13.8, melee r16.9 with the current Combat Layout).
- **Guard (E1):** `Validate.js` fails any FHKEllesmere `CooldownFrameTemplate` frame that is positioned without first clearing its anchors; it was confirmed to fail with the fix removed. The Lua mock cannot model template anchors (E2 widths passed throughout).
- **E1/E2:** Validate PASS (new static check); integration 2734; theme checks 553; installer PASS; package refreshed. No E3.

### Swing rings hug the GCD; melee ready only in reach (Claude, 2026-10-03)
- **Why:** player screenshot at 20-25 yd: the outer violet melee-ready ring was lit, and "weapon swing timer rings are huge".
- **Result:**
  - The cursor's melee-ready ring lights only when melee is actionable: the same shared check as the swing bar's MELEE READY (`NS.EllesmereMeleeActionable`, target in melee, deadzone or unknown range). At range only the Auto Shot ring shows.
  - Combat Layout: the swing rings no longer reserve the cast slot (`swingCursor.avoidCast=false`). Ellesmere's cast ring moves outermost (radius 21), shown only while casting; the Auto Shot ring already turns rose for shot casts.
  - Ring order: cursor (17 u), GCD r11, Auto Shot r13.8 (41 px), melee r16.9 (51 px), cast r21. Undo restores everything.
- **E1/E2:** Validate PASS; integration **2734** (melee-ready ring dark out of reach, layout writes and undo of `avoidCast` and the cast radius); theme checks 553; installer PASS; package refreshed. No E3.

### Cursor rings: tighter stack, Auto Shot inside melee (Claude, 2026-10-03)
- **Why:** player screenshot: still "a little large" on their 16-inch **2560x1440** laptop (the first pass assumed 1600 tall). The Auto Shot ring sat outermost, with empty bands reserved for the cast and melee rings between it and the GCD.
- **Geometry:** UI scale 0.8 at 1440 tall gives 1 unit = 1.5 px = 0.21 mm (~184 PPI).
- **Result:**
  - Ring order is now cursor, GCD, cast, **Auto Shot, then melee** (the ring watched most sits nearest the cursor).
  - Gaps are 1.5 u (~2 px).
  - Combat Layout sets thin ring art on GCD and cast (and so on the swing rings, which match the GCD), GCD radius 11 and cast radius 14 (minimum swing radius 10), with undo.
  - Swing rings: Auto Shot r17.1, melee r20.5. The stack is **41 u = 62 px = 8.5 mm** (~1 degree at 50 cm), down from 59 u. Auto Shot alone is 34 u (51 px).
- **E1/E2:** Validate PASS; integration **2733** (gap, order, cast scale, detached and opt-out cases, layout writes and undo of ring art); theme checks 553; installer PASS; package refreshed. No E3.

### Retry has its own colour: acid lime (Claude, 2026-10-03)
- **Why:** player: "some of the colours aren't very appealing, e.g. the gold and the retry"; picked from a visual comparison (gold, electric cyan, acid lime).
- **Measured:** lime #C6FF3D is at least 14 dE OKLab from every other token (20 from the jade Auto Shot bar beside it), and stays at least 13 apart under deutan and protan simulation.
- **Result:** retry swing-bar fill `#B8EB2E`; cursor ring sweep, retry icon and HUD retry cue `#C6FF3D` (tokens `retry` / `retryFill`). Gold no longer means retry. Dark mode shows retry as a thin lime strip.
- **Label (E3, player screenshot):** the colour was approved ("colours good"). A dark retry label was tried and rejected ("retry in black is not"), and its dark time readout vanished over the empty track. Labels stay white with the black outline, like every bar.
- **Attention gold:** not changed yet; awaiting the player's pick (sunflower / honey / keep).
- **E1/E2:** Validate PASS; integration **2733** (ring, fill, dark-mode strip, label white during and after retry); theme checks 553; installer PASS; package refreshed.

### Flee mark: bold edge notches (Claude, 2026-10-03)
- **Why:** player screenshot (learned fleer Ghostpaw Runner, hostile red bar): the 2 px, 60 % white line ran the full bar height through the centre-facing "100% | 629"; then "needs to be clearer... maybe a bolder line".
- **Result:** the mark at 20 % is two notches on the bar's top and bottom edges, each 30 % of the bar height, so the vertically centred text stays clear. Each notch is a solid white 3 px core inside a 5 px black outline, readable on red, gold and class-colour fills. Reverse-fill bars mirror it.
- **E3 (from the screenshot):** the learned flee mark appears on a beast that fled earlier; the out-of-range strip is grey on the frame's centre-facing left edge.
- **E1/E2:** Validate PASS; integration **2731** (two notches at 20 %, 30 % height, white core 3 px, black outline 5 px); theme checks 553; installer PASS; package refreshed.

### Range colours: red only for the deadzone; gold target of target only from enemies (Claude, 2026-10-03)
- **Why:** colour-meaning review against the combat audit. Out of range had been red with the deadzone because both meant "no action"; the player: "deadzone is bad for a hunter... maybe 35+ is grey... deadzone red". Gold target of target briefly marked identity (self/friendly too); after the review the player asked to fix it to the act-now meaning.
- **Result:**
  - Range: deadzone (5-8 yd, and the ambiguous DEADZONE? bracket) stays WoW red, the only red range state. Out of range (35+, far, beyond) uses the neutral grey `#9EA8B3` shared with unknown range and the dimmed out-of-range action buttons. Covers the range block, frame strip, plate glow and text. The shooting edge keeps its gold-to-jade gradient.
  - Cursor rings: both swings cooling is grey (was red), matching the swing bars' BOTH CD.
  - Target of target: gold only when a hostile target is on you. A friend or yourself targeting you keeps the native class colour, which already reads as you.
  - Colour tokens: `danger` = critical health and deadzone; `neutral` = no action available.
- **E1/E2:** Validate PASS; integration **2728** (35+ grey, deadzone red, both-cooling rings grey, friendly target of target native); theme checks 553; installer PASS; package refreshed. No E3.

### Dead resource text reads "0% | DEAD" (Claude, 2026-10-03)
- **Why:** player screenshot as a ghost: health "0% | DEAD", power "5% | 39" (fill already empty); "can we fix the resource bar so when dead it shows 0% dead like the health bar?". Supersedes the earlier rule that emptied the power text on death.
- **Result:** for a dead or ghost unit, our resource pieces return 0 and DEAD, so `perppnum` reads "0% | DEAD" (`both` reads "DEAD | 0%"), the same words as Ellesmere's health tag. The fill still empties. A state change repaints the text at once, because death and release do not always fire a power event. Units with no resource keep an empty row; a restricted dead flag is never treated as dead. Resurrection restores the real values.
- **E1/E2:** Validate PASS; integration **2724** (dead, ghost, sweep repaint with no power event, replaced text and zones not hidden, resurrection, secret flag); theme checks 553; installer PASS; package refreshed. No E3.

### Target text matches the player; pet moves inwards (Claude, 2026-10-03)
- **Why:** player screenshot: "with long names the level doesn't show; also we only have % not #% on the target frames"; then "pet frame also needs to shift inwards".
- **Result (Combat Layout, with undo):**
  - Target health `perhpnum` ("100% | 1155") and power `perppnum` ("100% | 1155"), the same order as the player (it read "1155 | 100%").
  - Target name slot `levelname`: the level leads, so a long name truncates and the level stays.
  - Pet frame: inner edge flush with the player frame's inner edge (was the outer), health text on its right, facing the centre. `pet.leftTextContent` / `rightTextContent` leave the retired list. The pet's status squares stay on its outer (left) side, now under the player frame.
- **E3 from the screenshot:** player health and power on the right; target range readouts on the left; frames 12 u out.
- **E1/E2:** Validate PASS; integration **2718**; theme checks 553; installer PASS; package refreshed.

### Readouts and the range strip face the centre (Claude, 2026-10-03)
- **Why:** player: move the health and the target's range indicator "into the center: from the left on the player frame to the right, and on the target from the right to the left".
- **Result (Combat Layout, with undo):**
  - Player: health text `perhpnum` moves from the left slot to the right, power text right.
  - Target: health % in the left slot, name and level (`namelevel`) on the outer right, power text left.
  - Target range strip: side left (outside placement), on the edge facing the swing bars.
  - Frames sit 12 u from the swing bar (was 8), so the strip clears it by about 5 u; pet, target of target and focus follow their frames. Combat blocks stay on the outer edges.
  - `player.leftTextContent` / `rightTextContent` leave the retired list (in use again).
- **E1/E2:** Validate PASS; integration **2717** (text slots, power side, strip side, 12 u gap, undo of side); theme checks 553; installer PASS; package refreshed. No E3.

### In-game confirmation, combat (player screenshot, 2026-10-03, level 22 vs Ghostpaw Runner)
- **E3 (seen working in game, in combat):**
  - white combat blocks on player, pet and target, the player and pet blocks in one column;
  - green happiness square beside the pet block;
  - target debuffs (Hunter's Mark, Serpent Sting) above the target frame and the player buff above the player frame, clear of other frames;
  - jade range block above the swing bars, MELEE READY quiet slate, AUTO SHOT jade with time left;
  - AUTO attack cue under the utility row;
  - jade frame range strip and plate range text (20-25);
  - full XP numbers with the violet quest forecast.
- **Still unconfirmed:** target of target was absent (fleeing mob), so the overlap the player reported is not reproduced; gold plate edge (the mob was fleeing, not attacking); cast colours; warnings lane; Frenzy.

### Flee mark learns fleeing creatures (Claude, 2026-10-03)
- **Why:** the same screenshot and chat: "Ghostpaw Runner attempts to run away in fear!" at 14 %. It is a beast, and the mark was humanoid-only, so it never showed.
- **Result:** the mark still shows for every enemy humanoid NPC, and also for any creature whose "attempts to run away in fear" emote (`CHAT_MSG_MONSTER_EMOTE`, name from the sender or the text) has been seen. Names are kept per character (`fleeLearned`, rawset; not a profile key). Other emotes teach nothing. English emote text only. Option renamed Flee Mark.
- **E1/E2:** Validate PASS; integration **2716** (unseen beast unmarked, learned beast marked, other beasts unmarked, pre-formatted emote, unrelated emote ignored); theme checks 553; installer PASS; package refreshed. No E3.

### Cursor rings sized for the laptop screen (Claude, 2026-10-03)
- **Why:** player: "the size of the cursor circles... take up loads of screen real estate; calculate based on my laptop monitor screen the best radius for them".
- **Inputs:** Config.wtf uiScale 0.8, maximised 2560x1600 (16-inch Razer Blade, ~189 PPI): 1 UI unit = 1.667 px = 0.22 mm. Ring art measured from `EllesmereUIQoL/Media/ring_*.tga` (inner edge at 50% alpha, radius 1): thin .906, light .859, normal .813, heavy .766, thick .688.
- **Before:** cursor 17 u wide, GCD r21, cast r30, swing rings at fixed +8 and +6 unit steps: melee r38, Auto Shot r44. The stack was **88 u = 147 px = 19.7 mm** across, and the melee band (outer 38) touched the Auto Shot band (inner 37.8).
- **Rule:** every ring's inner edge sits 2 u (3.3 px) outside the ring it surrounds; the whole stack stays within ~1.5 degrees at 50 cm, so the arcs read while looking at the cursor.
- **Result:**
  - `SwingCursor.lua` nests from the measured band edges instead of fixed steps; the retry icon sits 6 u under the outermost ring.
  - Combat Layout writes, with undo: Ellesmere GCD radius 12 (band 10.3-12), cast radius 18 (band 14.6-18), swing minimum radius 14. Swing rings then come out at melee r23.3 (band 20.0-23.3) and Auto Shot r29.4 (band 25.3-29.4).
  - Stack: **59 u = 98 px = 13.2 mm** across, 33% narrower and 55% less area. Gaps 1.9-2.6 u between every band. Undo for the companion's nested settings now restores inside their own table.
- **E1/E2:** Validate PASS; integration **2708** (gap-based nesting in two-ring, single-ring, cast-scale, detached and opt-out cases; layout writes and undo); theme checks 553; installer PASS; package refreshed. No E3.

### Target combat icon restored (Claude, 2026-10-03)
- **Why:** player: "combat indicator on target frame is missing". The Combat Layout had set the target style to None ("one combat glyph") when it was a second pair of swords; as a white block it no longer competes.
- **Result:** Combat Layout sets the target combat icon to Standard, top-right anchor, 16 u slot at x +20, vertically centred: the mirror of the player's slot, outside the target frame's right edge. The white block draws over it and shows the target's own combat state (Ellesmere's UNIT_FLAGS handling). Undo still restores the profile's original style. Supersedes "One combat glyph (the target frame's is removed)" below.
- **E1/E2:** Validate PASS; integration **2706** (target slot style, anchor, offset, size); theme checks 553; installer PASS; package refreshed. No E3.

### Loot icon replaces a corpse's 0% (Claude, 2026-10-03)
- **Why:** player screenshot (dead Wildthorn Stalker: "0%" with the bag floating on the frame's top edge): "on dead enemy unit frames we replace the 0% health with the dynamic loot bag icon".
- **Result:** while a unit-frame corpse has loot (or, once looted, skinning), the existing dynamic icon moves into the health text's slot (same side as the text, sized 1.3x its font, 14-24 u) and that text is hidden. It keeps its behaviour: bag or skinning knife, white within reach, dim when farther. Only a text zone that shows health alone is replaced, so names, levels and power never disappear. No loot or a living unit restores the text. Option: Loot Icon Replaces 0% (`lootInHealthText`, default on, profile key); still governed by Loot Icons / skinning toggles.
- **E1/E2:** Validate PASS; integration **2706** (text hidden and name kept, icon anchored to the text, option off restores, empty corpse restores); theme checks 553; installer PASS; package refreshed. No E3.

### Combat icons as white blocks (Claude, 2026-10-03)
- **Why:** player: "combat indicators, let's simplify them too to white blocks; there's a few asset choices for the combat indicator within Ellesmere UI".
- **Ellesmere's choices checked:** six styles (`EllesmereUI/media/combat/combat0-5.tga`): Arcade, Dungeoneer and Classic are crossed swords; Cross, Circle and Square are red. Ellesmere draws those six exactly as authored (vertex colour forced white, no tint), so its Square can't be made white, and red is reserved for danger.
- **Result:** a 12 u white block with a 1 px black outline, drawn on our own textures centred in the native combat icon's slot (native art at alpha 0). It follows Ellesmere's own show/hide, on the player frame and on the pet combat icon. Same grammar as the range block and happiness square. Option: Combat Icon Style -> White Block (default) / Ellesmere Icon (`combatIconStyle`, profile key).
- **Combat Layout:** player combat slot 16 u at x -20 (was 18 u at -22), so the player and pet blocks share one centre line 12 u outside the frames. Re-run `/fhklayout`.
- **Performance (E3, player `/fhkperf` screenshots):** all addons 0.30-0.64 ms per frame at 62-67 FPS; FHKEllesmere 0.07-0.40 ms.
- **E1/E2:** Validate PASS; integration **2700** (white, 12 u, black outline, native hidden, follows Ellesmere show/hide, hides out of combat, Ellesmere Icon restores native, layout slot); theme checks 553; installer PASS; package refreshed. No E3 for the block.

### Pet happiness as a square (Claude, 2026-10-03)
- **Why:** player: "the pet icon is kinda ugly... the default blizz icon is like a smiley face; we need something clean, maybe just a square".
- **Result:** the default happiness display is a 12 u block in the mood colour (happy green, content gold, unhappy red) with a 1 px black outline, drawn on our own textures inside the native icon's slot. The native face is hidden under it, so its tooltip and events stay. Same grammar as the range block. The paw remains as Pet Happiness Style -> Paw (`petMoodStyle`).
- **E1/E2:** Validate PASS; integration **2687** (square, colour, outline, native hidden, paw fallback); theme checks 553; installer PASS; package refreshed. No E3.

### Status column; player debuffs above the frame (Claude, 2026-10-03)
- **Why:** player screenshot: player debuffs ("Rooted") overlapped the pet frame; "the pet icon looks out of place as does the combat indicator on the player frame... combat indicators are important.. on both".
- **Status column (Combat Layout):** status icons sit just outside each frame's outer (left) edge, vertically centred, never over bars or numbers.
  - Player: the Ellesmere combat icon (top-left anchor, x -22, centred, 18 u).
  - Pet: a new combat icon (16 u, `petCombatIcon`, default on) that copies the player icon's artwork, colour and coordinates; then the happiness paw (align left, x -24, 16 u).
  - Positions stay fixed whether or not an icon shows.
- **Player debuffs:** top-right above the frame, mirroring the target (debuffs top-left, buffs top-right).
- **E1/E2:** Validate PASS; integration **2683** (column positions, debuff anchors, pet combat icon shows and hides); theme checks 553; installer PASS; package refreshed. No E3.

### In-game confirmation (player screenshots, 2026-10-03 01:2x game time)
- **E3 (seen working in game, out of combat):**
  - full XP numbers ("Level 21 - 21,195 / 25,200");
  - range colour block centred above the swing timer, red at 35+;
  - WoW hunter class colour on own health;
  - Combat Layout frame positions (player and target flanking the centre, pet under player, utility row centred);
  - side action clusters hidden out of combat;
  - white plate names (range-coloured names off) with range text kept;
  - gold target of target when the mob is on you (earlier screenshot).
  - Player: "looking clean so far".
- **Still E2 (not yet seen):**
  - spam-error filter;
  - combat-lane warnings;
  - Frenzy alert;
  - attack cue onset / fade;
  - warnings fade-out;
  - swing loop stop;
  - flee mark;
  - gold aggro plate edge;
  - rose cast bar and enemy cast states;
  - essential cooldown row (needs spells assigned in the Cooldown Manager).

### Range as a colour block above the swing bars (Claude, 2026-10-03)
- **Why:** player, on the weapon icon: "move the position of this indicator, more central above the swing bars; should just be a coloured block with a black outline that changes colour based on the range".
- **Result:** new Range Indicator Style "Color Block": the range fill alone (jade / violet / gold / red, facing warnings included) with a 1 px black outline. No icon and no text; the yardage stays on the nameplate, and a facing error still names itself under the block. Width and height are adjustable (default 48 x 14).
- **Combat Layout:**
  - The block is centred directly above the swing bars (-114 .. -128).
  - The native swing timer moves 10.5 units down (`swingTimer.anchorY` -137 -> -147.5, kept in the undo record) to make room.
  - Utility moves to -188, procs to -221; the AUTO / MELEE cue is centred at -241.
- **E1/E2:** Validate PASS; integration **2674** (block render, outline, no text, centred position, swing move and its undo); theme checks 553; installer PASS; package refreshed. No E3.

### One combat icon (really); target auras above; layout text changes retired (Claude, 2026-10-03)
- **Why:** player screenshots after the layout:
  - target debuffs overlapped target of target;
  - crossed swords still on a nameplate and under the character;
  - "resource bar's small on the target frame; text looks strange on the bar and pet frame".
- **Swords:** a correction. They were not the game's soft-target icons: the undo record shows `SoftTargetIconEnemy/Friend` were already 0. They are our own class combat glyphs, the per-plate "engaged" mark and the centre HUD combat icon. Both are now off by default; Nameplates -> Extra Combat Icons (`extraCombatIcons`) brings them back. The player frame keeps its icon.
- **Target auras:** Combat Layout puts target debuffs top-left and buffs top-right, above the frame.
- **Retired from Combat Layout:**
  - the 6-unit target power row (it crushed its text);
  - the player/pet split text with a grey raw value (grey on a coloured fill read muddy).
  - Re-running `/fhklayout` writes those keys back from the undo record and drops them from it.
  - The raw-value grey colouring in UnitRefinements is reverted.
- **E1/E2:** Validate PASS; integration **2667** (retired values restored and dropped from undo, aura anchors, centre combat icon off by default and opt-in); theme checks 553; installer PASS; package refreshed. No E3.

### WoW class colours; XP numbers from the first draw; range as a weapon icon; layout overlap fixed (Claude, 2026-10-03)
- **Why:** player after reload: "still not loading instantly; for classes just use the wow class colour, let's simplify things"; "range indicator is also gone... maybe an action bar icon that changes colour rather than the bar"; Unlock Mode showed the cooldown row overlapping the swing timer.
- **Class colours:**
  - Coloured no longer writes class or class-resource colours, so classes use Ellesmere's WoW defaults (hunter `#AAD372`) unless the player picked one.
  - Own health uses that colour as is, uncapped: white text relies on its shadow, as on Blizzard's bars. Pet and warning fills keep the readable cap.
  - Existing profiles drop only our exact earlier vivid values once (`classVersion` 1). The accent follows the WoW class colour.
  - This supersedes the vivid-lime entry below.
- **XP numbers:** instead of rewriting the text after Ellesmere drew it (which lost the race at login), the XP-bar module wraps Ellesmere's own number formatter. Only the XP readout uses it. Full grouped values therefore come from the first draw. Off returns the native formatter's output.
- **Range icon:** new Range Indicator Style "Weapon Icon". The equipped ranged weapon sits in a border painted by the existing range fill (jade, violet, gold, red, facing warnings), with the yardage beneath. It follows weapon swaps; size is adjustable. Combat Layout now uses it beside the attack cue instead of switching range off.
- **Layout geometry:**
  - The swing timer frame is -120..-155, not the visible bar alone.
  - Essential row moves to -92; utility to -178.
  - Procs move under utility at -211 (above the essential row they reached the character's feet and the centre cast bar).
  - Frames are top-aligned at -72; the attack cue and range icon sit on one row at -231.
  - Run `/fhklayout` again to apply; undo still restores the original values.
- **Test file:** a bad splice in `ValidateThemes.lua` was recovered from Claude Code's file history (v20) before the class-colour edits were reapplied.
- **E1/E2:** Validate PASS; integration **2666** (WoW class colour as is, picked colour as is, icon style, geometry); theme checks **553** (no class colours written, vivid migration); installer PASS; FHK swing PASS; package refreshed. No E3.

### Hunter health reads lime, not khaki; XP numbers at load (Claude, 2026-10-03)
- **Why:** player screenshots after reload: own health at 100 % still read olive beside pet green; full XP numbers "doesn't seem to show instant on load".
- **Cause:** fills were the class accent scaled down to the readable cap. Scaling the pale lime `#A7F05A` gives `#6A9939`, whose chroma (OKLCH 0.136) reads khaki.
- **Result:**
  - When the class colour is still our palette accent, the unit fill uses the palette's designed fill. Classes whose fill is their scaled accent look the same; a class colour the player picked is scaled as before.
  - Hunter fill is `#71970F`: same hue, chroma 0.155, 3.04 : 1 against the warm white label (the old fill was 2.997).
  - The saved resource colour migrates once, only from the exact old `6A9939` (`fillVersion` 1).
  - XP readout: rewritten at world entry and again 1 s later, so full numbers appear without waiting for an XP gain.
- **E1/E2:** Validate PASS; integration **2660** (designed hunter fill on own accent); theme checks **594** (designed exception, more saturated, still yellow-green, contrast); installer PASS; package refreshed. No E3.

### Full XP numbers (Claude, 2026-10-03)
- **Why:** player: "xp bar shows 19k/25k need values in full not rounded". Ellesmere's XP readout uses `AbbreviateLargeNumbers` with no option to turn it off.
- **Result:** `xpBar.fullNumbers` (default on; XP Bar Refinements -> Full XP Numbers). A `SetText` hook on the native readout rewrites only its raw-values form in the native layout (level prefix, percent and rested pieces kept) with grouped digits: "Level 21 - 18,932 / 25,200". Percent mode and restricted reads keep the native text. Off redraws the native rounded text.
- **E1/E2:** Validate PASS; integration **2659** (full grouped values through the installed native painter, switch-off restores rounding); theme checks 592; installer PASS; package refreshed. No E3.

### Target of target on you turns gold (Claude, 2026-10-03)
- **Why:** player: "when target of target is you that bar should be a different colour".
- **Result:** when `UnitIsUnit('targettarget','player')` is publicly true, the target-of-target health bar is the readable WoW gold fill (the act-now colour of the gold plate edge), held static rather than health-shaded. On your pet it keeps pet green (own-unit path). Other units keep their colour. A restricted read keeps the native colour. `totOnYou` (profile key, default on); Unit Frames -> Gold Target of Target on You.
- **E1/E2:** Validate PASS; integration **2657** (gold on you, native on others, restricted read); theme checks 592; installer PASS; package refreshed. No E3. In-combat identity may be restricted on this client; check in game whether it stays gold through a fight.

### Pulse once, hold still, fade out; idle swing loop stopped (Claude, 2026-10-03)
- **Why:** Codex research review (persistent states should not animate) and player: "animations should have a smooth pulse then stay static and a smooth fadeout"; "fix the loop".
- **Attack cue (AUTO / MELEE):** the per-frame sine pulse (about 1 Hz for as long as an attack ran) is replaced by native animation groups: a 0.9 s smooth onset pulse, then static at the set opacity, then a 0.3 s smooth fade when the attack stops. Reduced motion and unlock previews switch without animation.
- **Warnings:** no warning loops any more (the top row used to pulse forever, including information such as talent points). Each warning fades in with one smooth pulse, holds, and fades out over 0.3 s instead of vanishing. A warning that returns while fading simply stays.
- **Loop:** ForeverHunterKeys `SwingBars.lua` refreshed at 20 Hz even while idle. It now runs only while a swing timer, cast or retry cue is live, stops itself afterwards, and events (including the new `CURRENT_SPELL_CAST_CHANGED`) restart it. Weave-macro Auto Shot toggles arrive through that event instead of polling. The non-Ellesmere fallback cue flash is static.
- **E1/E2:** Validate PASS; integration **2650** (single onset, no repeat, fade-out/return, attack onset/hold/fade); theme checks 592; FHK `test_swingbars` PASS (loop stops when timers run out, event-driven toggle); installer PASS; package refreshed. No E3.

### Enemy cast states join the palette (Claude, 2026-10-03)
- **Why:** player: "the cast bar has colours for uninterruptable and interruptable ... different types of casts". Ellesmere's defaults clashed with the UI's colour language: nameplate casts were violet (melee range, on the same plate as the melee glow), the mid-cast interrupt was green, and the interrupted flash was red (good news shown as danger).
- **Result (Colored theme, `castVersion` 2, backed up, restored by Original):**
  - Target, focus and boss cast bars plus nameplates: normal cast tan `#9A8660` (3.1 : 1 under white text).
  - Your interrupt ready, including ready mid-cast: WoW gold `#C5A100` (act now).
  - Not interruptible: slate `#575C68` (quiet).
  - Important cast fill and glow: danger red `#FF4D40`. The deeper red was 5 dE from the hostile health fill directly above it.
  - Interrupted flash: white `#F2F2F5`.
  - Your own casts stay rose.
- **E1/E2:** Validate PASS; integration 2642; theme checks **592** (apply and full restore); installer PASS; package refreshed. No E3.

### Rose for your casts; soft-target swords off (Claude, 2026-10-03)
- **Why:** player: "we can change the colour of the cast bar"; "ellesmere draws the swords". Cast blue `#3FA7FF`/`#3791DD` was mana blue (0 dE) 8 units from the mana bar.
- **Cast colour:** chosen by search over hue for the readable fill most distinct from every fill near the swing bar. Rose: `cast` `#FF6FB1` (7.4 : 1 on the track), `castFill` `#FE51A4`. At least 13.8 dE OKLab x100 from mana, melee, hostile, retry and shoot; at least 8.2 under protan/deutan simulation (closest: shoot fill for deutan, different labels on the same bar).
- **Applied to:** cast ring; swing CAST fill; the Ellesmere player cast bar under Colored (`castVersion` 1, backed up, restored by Original; enemy cast bars stay neutral, so rose means "you are casting"). The native cast circle migrates only our own earlier `3FA7FF`.
- **Swords:** the crossed swords are the game's soft-target icons. Ellesmere's hide hook returns early when `UnitCanAttack` is secret (combat), so the enemy icon reappeared; one sat over the pet. Combat Layout sets `SoftTargetIconEnemy`/`SoftTargetIconFriend` to 0 and Undo restores the previous values. Nameplates -> Soft-Target Sword Icons toggle.
- **E1/E2:** Validate PASS; integration **2642**; theme checks **589**; installer PASS; package refreshed. No E3.

### UI audit changes: Combat Layout, alert filtering, state palette (Claude, 2026-10-03)
- **Why:** player asked to patch every P0-P3 recommendation from the [Wolf UI Combat Audit](https://claude.ai/artifact/YVA4vA7zSKkbhuJt9urRh2) and to refine the shoot/melee colours to be "modern, harmonious, visibly clear".
- **Spam errors (P0):** `warnings.errorFilter` (default on) uses Blizzard's own `UIErrorsFrame:SetMessageTypeEnabled` (retail blacklists these; Forever's override empties the list) for spell/ability cooldown, out of range and out of mana/focus/energy/rage. Voice lines go with them. Actionable errors stay red. Off restores each type's previous state.
- **Range strip (P0):** correction to the audit: the frame tab already had a 2 px black border. Combat Layout widens it to 3 px with a 7 px strip.
- **Combat Layout (P1/P2):** new `CombatLayout.lua`, `/fhklayout` and `/fhklayout undo`, Unit Frames -> Combat Layout buttons. Built around the swing bar (260 wide, -142/-158):
  - Cooldown Manager essential row 40 u centred at -114, procs 24 u at -76, utility 30 u at -181.
  - Player and target 8 u either side, tops level with the essential row.
  - Pet and target of target under the cast-bar slot, edges flush (target of target 181 x 20); focus under target of target.
  - Target power row 6 u; target shows % only. Player and pet show % plus a raw value in its own slot.
  - One combat glyph (the target frame's is removed).
  - Side action clusters on hover only; out-of-range icons dim slate instead of red.
  - Separate range row off; range-coloured plate names off.
  - Attack cue under the utility row; RestedXP guide and ForeverSplits fade to 40 % in combat.
  - Every value is kept per character and profile; one Undo restores them, including keys that did not exist. Queued in combat.
- **Centre lane (P1):** in combat, action warnings (pet health, dead pet, out of ammo, Frenzy, unsafe aspect) sit 150 u above centre at up to 22 px. Information and game errors stay in the top lane. `warnings.critical` and `criticalY`.
- **Raw values secondary (P2):** a zone holding only the raw health value is painted `#9EA8B3`.
- **Keybind labels (P2):** wheel is `WU`/`WD`; labels over 3 characters use lowercase modifiers (`SMwU` -> `SWU`, `SIns` -> `sIns`).
- **Pet green (P2, deviates from the audit's teal):** WoW friendly green `#2E9E33` (hue 123, the friendly reaction hue). It is 39 deg from the jade shooting fill (was 16) and leaves teal to Mage and rested XP.
- **State palette:** the bright state set shares one perceived lightness. Melee violet goes from `#C45CFF` (OKLCH L 0.67) to `#C787FF` (L 0.74): 7.6 : 1 on the track (was 5.8) and 4.8 : 1 on Ashenvale ground (was 3.7). Jade, gold and red are unchanged; cast blue `#3FA7FF` is unchanged (player's choice). Non-target range glow uses normal blending instead of additive, which vanished on bright ground (every bright hue is under 2.5 : 1 on Barrens tan or snow).
- **P3:**
  - Humanoid flee mark: a 2 px white tick at 20 % on enemy humanoid NPC targets (`fleeTick`).
  - Frenzy -> "Tranquilizing Shot - Frenzy" once the spell is known (`warnings.tranq`).
  - Gold plate edge when an enemy's target is you (`aggroPlates`).
  - Hunter hue kept (pet moved instead). Desaturation is done through the dim range tint.
  - PvP: apply the layout on a copied PvP profile (focus already sits under target of target).
- **Not changed (third-party or engine):** RestedXP Active Targets position (drag it), floating combat text colour/position (engine), the nameplate and centre crossed-sword glyphs (source not identified yet).
- **E1/E2:** Validate PASS (43 files); integration **2638** (filter and restore, centre lane, Frenzy and restricted auras, aggro edge and restricted reads, flee mark humanoid/beast/player, secondary raw text, layout geometry, apply twice then undo, combat queue, labels); installer PASS; package refreshed. No E3.

### /fhkautodebug trace for the Auto Shot cue (Claude, 2026-10-03)
- **Why:** player: the Auto Shot indicator "flashes up intermittently outside of combat for no reason". Static review found several inputs that can light it (START/STOP_AUTOREPEAT flag, `IsCurrentSpell` 75/5019/2764, no-argument `IsAutoRepeatSpell()`, thrown pulse, ranged `PLAYER_SWING`, Auto Shot cast/retry events) and no way to tell which fired.
- **Result:** `/fhkautodebug` toggles a session-only trace. Out of combat it prints which input turned the attack cue on, and any Auto Shot spellcast or swing event. Off by default; no cost while off beyond one flag check. Diagnosis, not a fix.
- **E1/E2:** Validate PASS; integration 2571. Not yet run in game.

### No olive own-health; quiet BOTH CD (Claude, 2026-10-03)
- **Why:** final-pass screenshot: own health at 83 % read olive (hunter `#6A9939` RGB-blended toward gold from 100 % down: at 83 % about `#829B2A`), the colour the player rejected; the swing bar's `BOTH CD` and its world cue were alarm red while nothing is actionable, so red meant "wait" as well as out of range / hostile / low health.
- **Result:** in Coloured, own unit health holds its class (or pet) colour down to 60 %, then ramps to gold by 50 %; gold -> orange -> red below is unchanged, as is Original. C-side curve uses the same `Shade`, so secret health matches. `BOTH CD` fill is the quiet slate `#40424A` and its world colour the neutral grey, matching quiet MELEE READY. FHK's own non-Ellesmere fallback stays red.
- **E1/E2:** Validate PASS; integration **2571** (holds class at 83/60 %, slate blocked fill, neutral blocked cue); FHK test_swingbars PASS. No E3.

### /fhkperf shows slow-frame counts (Claude, 2026-10-03)
- **Why:** player's readout showed FHKEllesmere peak 152.7 ms and EllesmereUI 886.6 ms; PeakTime covers the whole session including login/reload, so one load spike looks like stutter.
- **Result:** each row adds "N over 50 ms" from `Enum.AddOnProfilerMetric.CountTimeOver50Ms` when the client has it (guarded; omitted otherwise). A count of 1-2 is load; a growing count is in-play stutter.
- **E1/E2:** Validate PASS; integration 2567. Not yet run in game.

### Quest XP forecast is a violet tint (Claude, 2026-10-03)
- **Why:** player approved "violet tint" for the completed-quest forecast instead of lemon yellow: the forecast is more of the same progress, not a second meaning.
- **Result:** in Coloured the forecast is the earned XP colour mixed 50 % toward Ellesmere's track `(.06,.06,.08)`, drawn opaque so rested blue never shows through (default `#431E63`). Its 1 px edge repeats the earned edge at 60 % alpha. It follows the earned colour live, including native swatch edits. Custom Quest XP colour and the native gold outside Coloured are unchanged. Removed the unused `questXPFill`/`questXPAccent` tokens. Fixed a multi-value truncation (`bar and bar:GetStatusBarColor()`) caught by the new swatch test.
- **E1/E2:** Validate PASS; integration **2567** (tint, hue, opacity, soft edge, follows native edit). No E3.

### /fhkperf addon profiler readout (Claude, 2026-10-03)
- **Why:** player reports a large recent FPS drop. Static review found every companion driver throttled (0.05-0.5 s), so measure before changing code.
- **Result:** `/fhkperf` prints FPS, frame time and the top 12 loaded addons by `C_AddOnProfiler` recent average and peak time, plus the addon total. Read-only, no driver, nothing runs until typed; says so when the profiler API is absent.
- **E1/E2:** Validate PASS; integration PASS. Not yet run in game.

### Gold set to WoW's own hue, fully saturated (Claude, 2026-10-03)
- **Why:** player screenshot after reload: the amber `#CB9419` read as orange on the neutral target frame and plate; "patch the yellow in".
- **Result:** one gold `#C5A100` = WoW gold `FFD100` (hue 49) deepened with zero blue, for `reactionNeutral`, `healthMid` and the retry fill. Muted yellow (the old `#9E8719`) is what read olive; a saturated gold at this lightness reads gold. `NS.ReadableGoldContrast` 2.4 -> 2.2 (L* about 68). Rogue/energy `#AFA847`, Priest `#CF9C3F`. `VIVID_VERSION` 4 and Companion refinement v5 replace the exact amber, olive and pastel neutrals; player-picked colours stay. White text on gold is 2.2 : 1, carried by its shadow/outline.
- **E1/E2:** Validate PASS; integration **2564** (amber migration); theme/class **587**. No E3. Supersedes the amber entry below.

### One amber gold for neutral, retry and half health (Claude, 2026-10-03)
- **Why:** player: "the gold we use for neutrals seems out of place now... and the retry bar uses it too" (screenshots: mustard neutral target frame and nameplate). At the 3 : 1 cap every yellow lands near L* 58, where hues 49-56 read olive/khaki and even amber reads mustard, while red, blue and jade stay vivid.
- **Result:** `NS.ReadableGoldContrast=2.4`: `EllesmereReadableBarFill` caps hues 35-65 at 2.4 : 1 (L* about 65); other hues keep 3 : 1. One amber gold `#CB9419` (hue 41) is now `reactionNeutral`, `healthMid` (own-health 50 % stop) and so the retry swing fill. Rogue/energy fill `#A7A044`, Priest `#C6953C`. Labels keep their black shadow or outline for edge contrast. `VIVID_VERSION` 3 re-applies Colored once; Companion refinement v4 also replaces the exact old olive `(.62,.53,.10)` neutral (and the older pastel) in nameplate/unit-frame profiles and theme backups, leaving player-picked colours.
- **Accessibility note:** gold fills now give white text 2.4 : 1 (below WCAG 3 : 1 for large text); the shadow/outline is what carries legibility there. Lemon (Rogue/energy) still reads slightly khaki.
- **E1/E2:** Validate PASS; integration **2563** (olive migration); theme/class **587** (gold vs non-gold caps). No E3.

### Top alert lane; pet range warning made conditional (Claude, 2026-10-03)
- **Why:** player: the game error text "should move upwards and be large"; "where the Blizzard error text is, is where our cues should be"; low ammo and unspent talent warnings are great but belong up there; "Pet Too Far Away, no idea what that's for". Loot cue confirmed perfect (unchanged).
- **Result:** with **Top Alert Lane** (Warnings options, `warnings.errorRaise`, default on; `warnings.errorY`, default 110, slider 20-400; both inside the existing per-profile `warnings` table) Blizzard's UIErrorsFrame is anchored TOP of the screen at that distance, 900 wide and one line tall (newest error replaces the last), in the warning font at 80 % of the Low Durability size with the 16 px+ world outline. Our warning stack sits centred directly beneath it. Blizzard re-anchors are followed back. Off restores the native anchor, width, height and font and returns the warnings to the Low Durability position. Ellesmere's own Low Durability warning stays where its settings put it.
- **Pet range:** renamed **Pet Too Far To Mend**; it shows "Move Closer To Mend Pet" only when the pet is at or below the Mend Pet health threshold and out of Mend range. A healthy distant pet stays quiet.
- **E1/E2:** Validate PASS; integration **2562** (raised anchor, size, width, one-line height, follow-back, exact restore, warnings under the error line and back, quiet healthy distant pet); theme/class 585. No E3.

### Modern text, quiet melee-ready, resourceless enemies, soft XP ticks (Claude, 2026-10-03)
- **Why:** player review against Ksuper/Fshy UIs and new screenshots: every label had THICKOUTLINE plus a shadow; MELEE READY was a full violet bar at 30-35 yd; beasts targeted mid-fight still read "0 | 0%"; black XP ticks chopped the bar. Player: "everything should be modern". Range cues deliberately unchanged (player: range matters).
- **Text roles** (`ApplyEllesmereCueText`): **bar** text (unit-frame, resource, raid/action/cooldown module fonts, XP readout) keeps its native font flags (the player's Ellesmere setting is shadow) with a black 1,-1 shadow: no outline on a solid 3 : 1 fill. **Cue** text (nameplate module fonts, swing labels, class counter) keeps OUTLINE, THICKOUTLINE from 12, plus shadow. **World** text unchanged. Strong Theme Outlines off still restores native flags and shadows exactly.
- **Melee ready:** the row keeps violet only while melee is actionable (target range melee/close/unknown); otherwise the fill is `Colours.quiet` slate (dark mode: no strip). Range sampled at most 5x/s, only while the row reads ready. E1 only: no mocked melee-row test yet.
- **Resourceless enemies:** a public zero maximum is remembered per unit through combat (cleared on target/focus/pet/unit-target change). An NPC first targeted mid-fight gets a native colour-curve vertex tint over its power percent: clear at 0 %, untouched above, so Lua never reads the restricted value. Enemy players keep their rows.
- **XP ticks:** soft white 12 % marks in every theme (Colored used black 45 %).
- **Outline weight follows type size:** world and cue text use THICKOUTLINE only from 16 px (large warnings such as Low Durability at 30 keep it); names, ranges and numbers below that use OUTLINE, so red and jade text keep their colour instead of being eaten by a 2 px stroke. Blizzard's UIErrorsFrame ("Out of range.", "Pet Too Far Away") joins the world treatment; its font and size stay native.
- **E1/E2:** Validate PASS; integration **2535**; theme/class **585**. No E3.

### Coloured fills lifted to one lightness; empty power row; paw badge (Claude, 2026-10-03)
- **Why:** player screenshot showed the own health bar as olive beside a vivid blue mana bar and red target: the 4.75 : 1 readable-fill cap pressed yellows/greens to mud while reds/blues stayed saturated, and the profile's Class Darken was 55 (not set by companion code). Beasts showed "0 | 0%" on the power row. Player asked for the pet happiness paw to sit on the frame like the combat badge.
- **Result:** `NS.ReadableFillContrast=3` (was 4.75): every labelled bar label is outlined, as on WoW's bright stock bars. All nine class fills and the power fills are now their accents at that cap (L* 58, e.g. hunter `#6A9939`, mana `#3791DD`, focus `#DE6B0B`). Swing fills lifted the same way (jade `#2F9D7B`, violet `#C25BFD`, cast `#3791DD`). Own-pet health is a cool green `#2C9F5F` apart from the hunter lime. Coloured hostile red `#A82921` → `#C8302A`. `VIVID_VERSION` 2 re-applies Colored once on reload, which also returns Class Darken to 0 and replaces later palette swatch edits on that profile.
- **Power row:** a public zero maximum power hides the power fill and power-only text (same alpha path as the dead state); a restricted (secret) maximum keeps the row.
- **Paw:** with Status Icons on Frame Edge (`statusIconBadge`, renamed from "Combat and Loot Icons on Frame Edge") and the native Right alignment, the happiness paw is centred on the pet bar's top-right corner; native size and X/Y apply, Left/Top stay native.
- **E1/E2:** Validate PASS (42 files), integration **2529** (new: empty power row, secret maximum, paw badge, Left stays native), theme/class **573** (class fill = accent at the shared cap). Installer PASS; refreshed package Check **0 changes**. No E3; `/reload` needed. Known limit: yellow fills (Rogue/energy `#958E3C`, Priest `#B08435`) are still khaki at 3 : 1.

### Release-candidate engineering and UX audit (Codex, 2026-10-02)
- **Result:** 32 findings with stable IDs, severity, impacts, concrete fixes and an A-M release report in `RELEASE_CANDIDATE_AUDIT_2026-10-02.md`. Fixed RC01-RC14 in 15 live companion Lua files; retained the separate approved yellow XP forecast update and current vivid design.
- **Reliability/UX:** restored four missing native Style toggles via one shared detail builder; quest-bar Off now refuses combat/dragging atomically; optional Unit Frames resource controls are safe/disabled; queued layout/pet/wings/legacy chrome requests retain profile identity/name; cast history preserves observed keys; dead power caches track replacement fill/font/zones.
- **Profiles:** AutoGear mode joins `PROFILE_KEYS` and migrates through existing Attach. Added missing cursor/chat/resource/AutoGear/class-HUD resync and motion/chat/key-label/cursor reset keys. Theme/class behavior still stored with character snapshots is explicitly reported as a profile-portability release gap; restoration tables were not blindly moved into export.
- **Runtime/animation:** chrome retries now arm only for delayed installed XP discovery and park when settled/exhausted; AutoGear pause checks share its 50 ms cadence, level-up weights wait one timer turn; blocked clients skip all 27 modules; reduced motion stops active cue fades immediately even when their target is unchanged. No new TOC, artwork or permanent gameplay driver.
- **E1/E2:** 42 Lua files PASS; **2511 integration assertions**, **564 theme/class checks** PASS, including the actual core extension schema/copied callbacks/native row builder. Installer PASS; all **16** active FHK assertion scripts and 13 RestedXP touchpoints PASS. Core static checks (20 Lua/22 paths), candidate/review/installer tests (15/9/10) PASS. Both live Check plans report **0 changes**; generated companion package refreshed. No new E3 or CPU/FPS measurement.
- **Boundaries:** 3261 third-party files hash-identical to baseline. No SavedVariables writes by this audit; 30/764 differ at the latest comparison and 38 differed earlier as external state changed, so the report does not claim they were unchanged. No live installer Apply, upstream action or edits to the staged upstream child.
- **Recovery/next:** snapshot `Snapshot-20261002-231411-pre-release-audit.zip` predates the separate yellow XP follow-up; preserve that change during selective rollback. `/reload` loads these edits; prior unconsumed TOC additions still require a full restart. Next: complete theme/class profile behavior migration and the report's combat/restore/scaling/motion E3 matrix; benchmark redundant sweeps before event-lifecycle refactoring.

### XP completed-quest forecast changed to yellow (Codex, 2026-10-02)
- **Why/result:** player requested yellow instead of orange. Coloured forecast now uses the existing Rogue/energy lemon pair: deep fill `#71691F`, electric yellow edge `#FEF367`. Earned purple, rested Mage blue, outlined text and custom quest colours retain their existing behavior.
- **Files/settings:** owned Bootstrap and XPBarRefinements fallback, three existing colour expectations, generated package and current palette/handover documentation. No new setting, migration or TOC; no third-party/SavedVariables edits.
- **E1/E2:** 42 Lua files PASS, current integration **2460** and theme/class **560** checks PASS. Installer PASS; refreshed package Check **0 changes**, Ellesmere untouched. No E3; `/reload` is sufficient.

### XP palette aligned with the vivid theme (Codex, 2026-10-02)
- Final package refreshed; installer validation PASS; read-only Check **0 changes**, Ellesmere files untouched. No Apply needed.
- **Why:** player's screenshot showed the old pastel lavender earned fill and a mustard quest forecast. Player confirmed earned XP purple, rejected gold for the forecast, and chose the Mage palette for rested blue.
- **Result:** Coloured earned XP uses deep electric violet `#762DB2` / edge `#C45CFF`; rested bonus uses Mage cyan-blue `#146E86` / edge `#3FC7EB`; completed quests use Druid orange `#A84608` / edge `#FE7B0D`. Forecasts are opaque so quest/rested colours do not blend. Bright edges follow actual fill textures; gain highlights now follow XP colour. White readout keeps the shared black outline/shadow, including direct native font changes; small labels use OUTLINE, >=12 THICKOUTLINE. Coloured ticks are black, Original retains previous white ticks.
- **Files/settings:** owned Bootstrap, ThemePresets and XPBarRefinements; native XP swatches remain editable. Existing Coloured profiles migrate XP once without reapplying edited class colours; captured native XP colour mode/fill/rested alpha restore exactly with Original. No new preference/TOC, layout/visibility/motion changes, third-party/SavedVariables edits or upstream actions. New `xpVersion` metadata remains per character inside existing theme state.
- **E1/E2:** Validate PASS (42 Lua files), integration PASS (**2420**) and theme/class checks PASS (**544**). Actual installed XP painter/resolver run in mocks; colour/extent/layering, custom swatches, secret channels/alpha, pixel scaling/orientation, direct font changes, combat deferral, XP-only migration and exact restore covered. The supplied screenshot documents the prior appearance; revised colours still await E3. No CPU claim. Snapshot `Snapshot-20261002-225628-pre-vivid-xp.zip`; `/reload` is sufficient.
- **Handover:** `CLAUDE_VIVID_THEME_HANDOVER_2026-10-02.md` records the accepted design, full class/gameplay palette, current changes, package/sharing limits and a critique checklist.

### Vivid Coloured palette, readable text and pixel edges (Codex, 2026-10-02)
- Final package refreshed; installer validation PASS, read-only Check **0 changes**, Ellesmere files untouched. Live owned edits already installed; no Apply needed.
- Player approved extending the electric jade/world-name direction throughout Coloured: nine vivid class identities and matching deep fills, including red and gold Priest rather than white. Central class/power pairs feed native colours and the current class accent; primary power uses the matching theme palette. Shared class colours remain bright; group fills deepen separately. Existing Coloured profiles migrate once, later swatch edits survive, native palette locks/combat queues/Original restore remain. See `VIVID_PALETTE.md`.
- Melee tan/bronze becomes violet `#C45CFF` / amethyst `#762DB2` across range, attack and swing cues; shooting jade/cast blue retained. Own health follows class -> gold -> orange -> red (own pet starts green); other units retain native reaction/health fills. Neutral enemies turn red immediately on public player/pet aggro and return to their native colour when it clears. Public labelled fill channels deepen for contrast; active resources keep their own hue, deepening as they drain and brightening as they build, including class overrides and pet focus. Mana stays blue per the player's choice. Restricted health/power still uses native curves.
- Reversible shared font service covers native module applications and owned names/range/health/power/swing/warning/rarity text. Thick outlines on world text >=10 / values >=12, fine below; native font path/size and MONOCHROME/SLUG retained. Native Low Durability joins through its actual anonymous frame/font setter, with no replacement warning. Weak registries preserve restoration and avoid steady shadow writes.
- Player screenshots exposed an Auto Shot cell box: corrected the caller to outline the bow glyph itself, as requested. Transparent swords/paws/loot/skinning/retry symbols get black pixel silhouettes, following native art/crop/alpha/hiding; nameplate combat glyph is now included. Outside range tabs have adjustable 0-3 physical-pixel borders (default 2), preserving the five-pixel colour strip, explicit Inside stripe and fades. Central range rail now has a one-physical-pixel black outline, in both orientations, without boxing its labels; UI-scale changes refresh it. Added a physical-pixel health/power seam to custom unit frames, with native fade/visibility and power-bar replacement handling.
- Profile-scoped Style controls: **Strong Theme Outlines / Readable Colored Fills / Pixel Icon Edges / Health / Power Separator**, included in global reset. Range tab border is nested in existing indicators.frame. Changed owned Bootstrap, Companion, RangeIntegration, SwingIntegration, UnitRefinements, ResourceRefinements, Warnings, Rarity, ClassMechanics, ThemePresets and Profiles. No new TOC, third-party/SavedVariables write or upstream action.
- **E1/E2:** 42 Lua files, **2388 integration assertions**, **515 theme/class checks** PASS, including installed native durability bodies, secret curves, all class health starts, resource overrides, public/restricted aggro, contrast/restore/migration/profile storage, glyph changes/scaling/hiding, separators and range border choices. Supplied screenshots document the observed styling and defects; these subsequent corrections await E3 after reload. No CPU claim. Snapshot `Snapshot-20261002-212937-pre-vivid-theme.zip`. `/reload` loads this continuation; the two earlier TOC additions still require their first full restart.

### Coloured palette review, preserve vivid gameplay cues (Codex, 2026-10-02)
- Reviewed the current live palette, Claude's latest colour changes and the player's five supplied screenshots. Saved findings in `COLOURED_PALETTE_REVIEW_2026-10-02.md`.
- Keep the bright jade/gold/red/blue and pet mood cues, with deeper fills beneath white labels. Melee tan is the weakest terrain-facing accent. Identified the combined enemy-health ramp and range-coloured name behaviour behind the red-at-100% / gold-at-53% screenshots; recommend separating reaction identity from injury/range cues. Recommendations are not implemented.
- **Evidence:** E1 source review and sRGB contrast calculations; Validate PASS (42 Lua files). E2 existing theme/class baseline PASS (436 mocked checks). Supplied screenshots support the recorded static observations only; no new interactive E3 or accessibility certification. No addon, third-party or SavedVariables edits; no restart or package refresh required.

### Dark mode discoverability (Codex, 2026-10-02)
- Player could not find a dark-mode toggle. Added **Dark Mode** to **Global Settings > Style > Forever Theme Presets**, using the existing profile-aware native preset controls. Off restores the captured original look; palette-source locks and combat deferral remain in force. Colored and Afterglow stay available in the preset dropdown.
- Added **Dark Mode / UI Look > Open Style** at the end of Global Settings > General. It opens the Style page, scrolls to the presets and highlights Dark Mode. Without the core options-extension API, the control remains available under Forever Companion > General; the legacy suite keeps it on Style.
- `/fhktheme dark` and `/fhktheme restore` remain available. Updated player instructions to show the current locations. Existing Claude sign-off refinements are retained; no new setting key, TOC entry, third-party edit or SavedVariables file edit.
- **Evidence:** E1/E2: 42 Lua files, 2243 integration assertions, 429 theme/class checks PASS, including toggle apply/restore, color lock, profile getter and General shortcut. Installer PASS; refreshed package Check reports 0 changes. In-game placement/toggle check pending. Snapshot `Snapshot-20261002-194014-pre-dark-mode-control.zip`. `/reload` loads this change; the earlier new TOC files still need a full restart once.

### Sign-off fixes: clean bar icons, key labels, AutoGear modes, dead power row (Claude, 2026-10-02 late)
- **Clean action bar icons (player request: "why are Shadowmeld and Elune's Light so much cleaner?"):**
  - Those are Cooldown Manager icons: 8% icon trim and no keybind text, so the art reads first.
  - Hunter polish v2 gives every bar the same 8% trim (`iconZoom`) and a softer keybind colour (`.86 .88 .92`).
  - Undo keeps the original pre-polish look across the upgrade and also restores the trim and colour.
- **Keyboard-first key labels (new, default on, `keyboardKeyLabels` in `PROFILE_KEYS`):**
  - A button bound to both a keyboard key and a Naga output shows the keyboard key ("SG", not "SF12").
  - Insert/Delete shorten to Ins/Del so labels are never cut off.
  - Post-hook on `EAB.ApplyFontsForBar`; text only, bindings untouched; respects Hide Keybind.
  - Toggle under Action Bars > Hunter Keyboard Layout.
- **AutoGear Levelling / Endgame modes (player request), per character:**
  - **Levelling:** the bow counts far more than the melee weapon (`RangedDPS 8, MeleeDPS 3, Damage .15`), so slower, harder-hitting weapons win.
  - **Endgame:** AutoGear only acts on sim weights imported in AutoGear; without them, scanning and quest picks pause, which saves the CPU.
  - **Automatic** (default): Endgame at max level. Dropdown and status line in Global Settings > General > AutoGear.
- **Dead power row (player report: corpse showed "3% | 24" beside DEAD):**
  - While a unit is dead or a ghost, the power fill and power-only text go empty.
  - Alpha only: the real value stays underneath and returns on resurrection. A secret dead flag is never treated as dead.
  - Reverses the earlier "no new hide behavior" choice, at the player's request.
- **Quest count on nameplates (player report: "0/2" drawn over the mob name):**
  - **Cause:** Ellesmere centres the count on its small top-left icon frame, so a count wider than the icon runs into the centred name. It was also white, like the name.
  - **Fix:** in a top corner slot, the count now sits just outside the bar corner and grows away from the name. It keeps the native slot offsets, size and outline. It takes quest yellow (new `quest` token), so it reads as a quest mark.
  - Other slots keep the native centred count.
  - New toggle **Quest Count Beside Bar Corner** (Nameplates > Display > Mob Rarity, default on, `rarityQuestCount` in `PROFILE_KEYS` and the Nameplates reset list).
  - **Not changed:** the bag icon left of the bar is Questie's own nameplate objective icon (Questie > Nameplates), so the quest shows twice. That is the player's choice.
- **Coloured preset readability (player review, chose Coloured over Dark):**
  - Light class fills under white text measured 1.7:1, the yellow level 1.1:1, and the bars blended into green terrain.
  - Coloured now also sets Ellesmere's native Class Color Darken 40 (about 4.5:1) and Power Color Darken 20 (mana about 5:1). The hue is kept.
  - Values live in the dark-mode table the preset already backs up, so Original / Restore returns them.
- **WoW-aligned warning palette (player request: "fit into WoW, high contrast", replacing the modern pastels):**
  - **Text and lines:** WoW's own colours from `QuestDifficultyColors` and `NORMAL_FONT_COLOR`: gold `1 .82 0`, orange `1 .5 .25`, and red `1 .3 .25` (lifted for dark backgrounds). These drive health text, range lines, warnings and pet mood (green `.30 .85 .30`).
  - **Fills:** new tokens, saturated like the icon art: bronze gold `#AF8115`, burnt orange `#B75616`, crimson `#B12319`.
    - White text reads at 3.1, 4.3 and 6.0 : 1; the old pastels were 1.4 to 2 : 1.
    - Lightness steps down (L* 57, 48, 39), so the ramp still reads with red-green colour blindness; under deuteranopia the old pastel gold and orange were nearly identical.
    - Bronze gold matches Forever's frame art.
  - **One warning at a time:** while a fill warns, its health number stays white, as Blizzard's frames do. The text carries the warning only in dark mode, with bar colours off, or with the opt-in pet happiness fill. The text ramp is white, then gold at 40 %, orange at 25 % and red at 10 %.
  - `PaintEllesmereHealthText` takes the bar context (`unitframes`, `nameplates`, `resourcebars`). Docs updated (DEVELOPMENT palette table, README).
- **Attack colours on the WoW palette (swing bars, cursor rings, attack-pulse icons):**
  - **Bright set** for icons, rings and lines over the world:
    - ranged: jade `#40D6A8`. It is not WoW green, so it never merges with the hunter-green health bar beside the swing bars;
    - melee: WoW warrior tan `#C69B6D`;
    - retry: WoW gold (act now; was tan);
    - both cooling: WoW red;
    - cast: the cast-ring blue `#3FA7FF` the player kept.
  - **Deep fills** for swing bars with white labels: jade `#17876B`, tan `#9A6E42`, blue `#1F73C2`, crimson, bronze gold (4.4 to 6 : 1). They are new `*Fill` tokens plus `EllesmereSwingFillColors`, and the native swing defaults follow them.
- **Reaction fills in the Coloured preset (player report: pale cream neutral bar):**
  - Deep WoW red `#A82921`, olive gold `#9E8719` (kept apart from the bronze 50 % health stop), green `#338C38` and tapped grey `#6B6B6B`.
  - Applied to unit-frame enemy colours and nameplate hostile/neutral/tapped.
  - Backed up with the preset, and backfilled into older backups, so Original / Restore returns them.
- **Combat and loot icons on the frame edge (player report: they covered the name):**
  - While Ellesmere's Combat Indicator is in its default Center position, it now straddles the health bar's top edge, clear of the vertically centred text. The loot bag follows. Native X/Y offsets still apply.
  - Portrait and corner positions stay native.
  - New toggle **Combat and Loot Icons on Frame Edge** (Unit Frames, default on, `statusIconBadge` in `PROFILE_KEYS` and the reset list).
  - The badge follows Ellesmere's re-anchor through an instance `SetPoint` post-hook.
- **Neutral mobs were cream (root cause):** refinement v2 in `Companion.lua` had written the old pastel caution yellow into Ellesmere's unit-frame and nameplate neutral colour, so neutral bars stayed pale whatever the preset.
  - Refinement v3 replaces exactly that value with the deep olive gold `reactionNeutral`, including inside theme preset backups. A colour the player picked is kept.
  - New installs write the deep fill directly.
- **Dark mode, clean and purposeful (player request: black and a dark shade of black):**
  - The Dark preset now sets remaining health to `#1C1D21` over black for missing health. The old native grey missing segment drew the eye to what was lost.
  - Power Color Darken is 70 and BG Power Color Darken 85. Player principle: in dark mode colour must mean something, so power is near-black navy and the mana number carries depletion.
  - **Dark Mode Health Line** (default on, `darkHealthLine` in `PROFILE_KEYS`): a 1px line along the top of the remaining health, anchored to the fill texture so it follows natively, restricted values included. It uses the health text ramp (light, then WoW gold, orange, red), so bar and number agree. It hides outside dark mode, on resource fills and on corpses.
- **Dark mode reaches the swing timers and cursor rings (player request):**
  - New shared `EllesmereDarkMode()` follows Ellesmere's unit-frame Dark Mode switch, which the Dark preset turns on, and a `darkFill` token.
  - **Swing bars:** black fill, with the state colour (jade, tan, gold retry, red, blue cast) as a 2px strip along the bottom of the fill, so it tracks the timer.
  - **Cursor rings:** a black heavy ring behind a thin sweep in the state colour.
  - Both return to their normal look when dark mode is off.
- **Dark mode: neon text, dark power bar, dark nameplates (player requests):**
  - **Neon text:** health text at rest is the player's class colour pushed to neon: full brightness, at least 60 % saturation, so a hunter gets lime. Below 60 % it hands over to WoW gold, orange and red. The health line uses the same colour. Text curves are cached per rest colour.
  - **Unit-frame power:** dark fill. The number and a 1px line along the remaining power use the resource colour as neon (mana blue, focus orange, rage red, energy yellow).
  - **Nameplates** (Ellesmere has no dark plates; the companion follows the same switch):
    - dark fill, black background and the health line;
    - range shows as a 2px strip along the bottom of every enemy plate, target included;
    - the glow is off and the target's native glow drops to a faint light edge;
    - names show reaction in WoW colours (red, gold, green) instead of range;
    - the range text is hidden, since the strip carries range.
  - Everything restores when dark mode is off.
- **Empty option headers:** a companion section now draws its header only when it has a row, so AUTOGEAR no longer shows an empty title when AutoGear is not installed.
- **Player glow and circle (question, no change):** that is the game's target outline and selection circle, shown because the player targeted themselves (`graphicsOutlineMode` 2 in `Config.wtf`). The engine colours both by reaction. No addon API can recolour them, so a health-coloured circle is not possible.
  - Self Highlight (Accessibility) was checked too. The client has only on/off CVars: `findYourselfModeCircle`, `findYourselfModeOutline`, `findYourselfModeIcon` and their combat/raid/BG scopes.
  - The `WowB.exe` strings and the Forever UI source have no colour setting for them.
  - A low-health switch is also not possible: player health is a secret value in combat, so Lua cannot test a threshold.
- **Evidence:** E1/E2. Integration 2292, themes 436 (new: dark power bar and neon text, dark nameplates, dark swing strip and dark rings, neutral migration, dark health line, dark preset values, attack colours, reaction preset with restore, combat edge badge, WoW palette ramp, dark-mode text handover, dead and ghost power row, resurrection restore, sweep path, secret flag, quest count placement both corners, side slots and off), themes 417, FHK 15/15, installer PASS, package and core checks 0 changes. Bar trim, labels and the dead row need E3. Two prior new TOC files still require a **full restart**.

### Final pass after the Codex handoff (Claude, 2026-10-02 evening)
- **Lua error (in game, 370+ counts):** `UnitRefinements.lua:372` compared a secret anchor from `GetPoint` on 9.3.5.
  - Power-text alignment now rebuilds the placement from Ellesmere's own settings and `power._ppTextOvr` with `PP.Point`, and never reads the anchor back.
  - During construction it falls back to the text's parent overlay.
  - This also restores the health/resource edge alignment the player saw drift (insets 5 vs 2).
- **Damage flash (player request):**
  - **Problem:** the old trail dropped out on restricted (secret) health, which is the usual case in combat. It also drew in the UI accent at 40%.
  - **Readable values:** the timed red drain is kept, held at full strength and fading only at the end.
  - **Restricted values:** an invisible helper StatusBar eases natively toward the secret value (`SetValue(v, ExponentialEaseOut)`). A red BORDER-layer texture between the bar background and the fill is anchored to the helper's fill, so only the lost segment shows. Heals stay hidden under the fill.
  - New `damage` colour token. The old 40% default moves once to 85%; picked values are kept. Labels are now "Damage Flash ...".
- **Health text in combat:** health text keeps warning when health is restricted. The same ramp is used as a cached native colour curve (`UnitHealthPercent` with the curve, vertex tint over white text), on unit-frame zones, nameplates and resource-bar text. This matters most in Dark mode, where text is the warning.
- **Pet (player decision):**
  - The pet bar shows health like every bar, and the paw icon shows happiness.
  - Happiness as the fill is opt-in (`petHappinessColors == true`).
  - New **Pet Happiness Paw Icon** toggle (`petMoodIcon`, profile key).
  - The paw is restyled again after Ellesmere repaints its stock face: the cache now keys on `_atlas`, and the restyle is post-hooked on `UF_ApplyPetHappiness`.
  - The reviewed preset no longer forces the all-themes strip. The forced strip is switched off once (`iconCarriesMood`), and the Dark-mode strip stays.
- **Quiet chat (player request), default on:**
  - Chat is hidden unless typing or hovered, and fades 2 s after the mouse leaves. It uses Ellesmere idle fade at strength 100.
  - Public chat lines no longer wake it (post-hook drops the engine idle observer while quiet); whispers still do.
  - Previous fade settings are kept on the chat profile and restored when switched off. `/fhkellesmere chat ...` overrides it.
  - New key `chatQuiet` in `PROFILE_KEYS`.
- **Options placement (player request; needs the local core patch's extension API):**
  - Theme presets sit on **Global Settings > Style** as native rows.
  - Each refined Ellesmere page ends with a **Forever Companion** button to its plugin page.
  - Other companion controls stay on the plugin pages, because extension rows are copied once and would go stale after a profile switch.
  - Retries when Ellesmere's on-demand options load (`ShowModule` post-hook).
- **AutoGear CPU (player report):** the integration forced a full rescan on every `GET_ITEM_INFO_RECEIVED` and on every `SKILL_LINES_CHANGED`, which fires on each weapon-skill point.
  - Item-data events are left to AutoGear's own throttled handling.
  - Skill and spell events count only when the number of skill lines changes, meaning a new proficiency.
  - Rescans are coalesced 1 s after the last change.
- **Text consistency:** the nameplate range text, when not assigned to a native slot, now uses Ellesmere's nameplate font helper, the same face and outline as the health numbers.
- **Opacity ownership:** the Nameplate Opacity Priority tooltip states that while on, it replaces the Ellesmere Non-Target and No-Target Opacity for enemy plates.
- **Evidence:** E1/E2.
  - Integration 2176 (new tests: secret-anchor alignment, both damage-flash paths, the combat health-text curve, pet health vs paw, quiet chat wake, native Style placement with links, AutoGear skill-line gating). Themes 417, FHK 15/15, installer PASS, package and core checks 0 changes, RestedXP adapter PASS.
  - The native interpolation speed and the BORDER-layer stacking need E3.

### Final Hunter cues and AutoGear proficiency guard (2026-10-02)
- **Gear defect:** installed AutoGear's structured tooltip parser uses `textRight` instead of `rightText`, missing red right-column proficiency requirements. New owned `AutoGearIntegration.lua` supplies guarded tooltip requirements from both columns plus the optional client `CanUseItem` verdict, leaves scoring native, rejects invalid candidates and rechecks due equip queues before pickup. Pending/unknown requirements cannot initiate an equip. Already-equipped baselines and native near-future level rolls remain; a missed proficiency cancels that roll exception. The FHK vendor upgrade policy now rejects `unusable` / `itemDataMissing` items before score comparison. Explicit Always purchases keep their original semantics.
- **Cost/lifecycle:** reuse the existing AutoGear update callback at its 50 ms cadence; no added polling driver. Shared parsed tooltip data avoids another read during ordinary candidate scoring. Training/data events coalesce native refreshes and defer them in combat. No skill refresh events while AutoGear is absent. AutoGear is an optional TOC dependency; no third-party files changed or direct equip actions added.
- **Reviewed profile:** player asked to finish the review's improvements. New owned `FinalPolish.lua` applies happiness-as-strip, conditional Mend/range/aspect warnings, missing/dead pet in combat, shared LoS/movement errors and native custom cast blue `3FA7FF` once at login. Thresholds, fonts and ring geometry stay as chosen. Existing profile-scoped nested keys carry the behavior; per-character applied flag and profile-guarded restore snapshot stay out of exports. Snapshot follows rename/delete. General has Apply Reviewed Hunter Cues / Restore Previous Hunter Cues; later edits and restoration survive loading.
- **New Forever cue:** native retail missing-pet collector/page is excluded on Forever. Combat-only missing/dead pet warns only after learned Call Pet, suppresses player death/mount/taxi/vehicle context, and never infers pet death from absence. No summon/resurrect automation. New optional confirmed LoS/movement feedback shares the existing range indicator and facing-cue clearing/lifetime, without camera prediction or another widget.
- **Screenshot:** death still retains native fill colors and the native DEAD label. Existing edge-inset correction, immediate actual mana and low-mana text work at zero health; no fabricated resource zero or new hide behavior.
- **Evidence:** E1/E2, 42 Lua files, 2142 integration assertions, 417 theme checks, all 15 active FHK scripts (47 trainer/vendor assertions) PASS. Installed native AutoGear right-column parser/candidate/queue/pickup/equip consumers run in mocks; rejection before pickup, usable upgrades, optional API, missing data, future-level exception, combat deferral/coalescing, absent-addon event budget and death text/inset are covered. Installer validation PASS, refreshed Check 0 changes, RestedXP touchpoints 13/13 PASS. Native/vendor hashes unchanged; no SavedVariables edits, E3 or measured CPU/FPS claim. Backup `Snapshot-20261002-181104-pre-final-polish.zip`. Two new TOC files: **full restart required**.

### Pet happiness, immediate mana colors and text alignment (2026-10-02)
- **Screenshot findings:** the green paw is the existing happy-pet cue (yellow = content, red = unhappy). In colored themes the pet health fill also follows happiness unless Happiness Strip In All Themes is enabled, so a happy injured pet can remain green. The screenshot shows full mana; depletion coloring cannot be judged from that state alone. Existing resource shading retains its hue while dimming to a 45% floor; low-mana text becomes readable blue. Dark fills stay native and warnings stay in text.
- **Immediate feedback:** post-hook the native `UF_PaintPowerText` path to repaint only the affected unit's power fill and resource labels on the native value update. No wait for the general sweep. Preserve native values/formatting, secret-safe curves, palette, alpha, off behavior and dark fills. The older engine event fallback also repaints feedback. Register the documented `UNIT_HAPPINESS` event for immediate pet fill/strip/paw refresh; strip options now refresh immediately.
- **Alignment:** health edge labels use native inset 5; power labels use 2. New **Align Power and Health Text**, default on under Forever Companion -> Unit Frames, uses matching left/right insets while keeping fonts, row anchors and native X/Y offsets independent. Native pixel scaling is applied once; existing scaled Y is retained without drift. Centered/hidden text and active stock artwork remain native. Off reapplies the native inset. `alignPowerText` is classified in `PROFILE_KEYS`, Unit Frames reset and feature resync.
- **Evidence:** E1/E2, 39 Lua files, 2043 integration assertions and 414 theme checks PASS; installer validation PASS, refreshed Check 0 changes. Tests execute installed native power-position/color, power-value and power-text bodies, covering immediate spend/regen, dark/off behavior, construction, left/right/center, offsets/scaling/no drift, stock-style switching, profile storage/reset, and happiness events/strip separation. No E3 or CPU measurement. No third-party or SavedVariables edits; WoW was running. Backup `Snapshot-20261002-174909-pre-pet-mana-text.zip`; no new TOC entry, `/reload` is sufficient.

### Cast cursor following and Default profile review (2026-10-02)
- **Finding/repair:** the saved Default profile already enables/attaches the cast circle. Native attached positioning can depend on the base cursor frame. `SwingCursor.lua` now post-hooks the native ring lifecycle and positions active attached casts from Ellesmere's shared mouse service, independent of a stalled reticle. Native timing, spark and duration-object handling stay native. Follow unsubscribes on stop/hide/disable/detach/unlock; camera look preserves the last visible position. Native apply/re-anchor paths cannot strand an active ring. The live trigger remains unconfirmed.
- **Readability:** default 30-unit cast and GCD-cleared 29-unit inner swing radii nearly touch. **Keep Clear of Cast Ring** on the existing Cursor/Swing Timer page defaults on and provides eight units of clearance with scales accounted for. Off retains the previous geometry. `avoidCast` is nested in the already profile-scoped/reset `swingCursor`; no character flag or new top-level key.
- **Performance:** owned swings now consume the existing shared render/state samples; their separate per-frame cursor query and idle fallback state driver are removed when the native mouse service is available. Motion positioning parks at rest and unsubscribes on hide; the existing shared clock state tick remains while enabled. Fallback is enabled-only when the service is absent. No CPU/FPS result is claimed.
- **Review:** [PROFILE_AT_A_GLANCE_REVIEW_2026-10-02.md](PROFILE_AT_A_GLANCE_REVIEW_2026-10-02.md) audits Default saved at 17:04:57 London, including confirmed saved opacity/chrome settings. It prioritizes native custom cast color, optional pet/aspect warnings and reducing duplicate timing cues. Retail pet reminders are excluded on Forever, leaving a genuine missing/dead pet opportunity. Optional profile preferences remain as saved; SavedVariables were only read.
- **Evidence:** E1/E2, 39 Lua files, 1909 integration assertions and 414 theme checks PASS. Tests execute the installed native ring factory and mouse service, check one cursor render sample for cast/swing together, stillness parking/re-arm, immediate release, native timing/duration objects, scale/secret guards, detach/hide/unlock and cast/swing clearance. Installer validation PASS, refreshed-package Check 0 changes; installed Cursor and Mouse hashes unchanged. No E3. Backup `Snapshot-20261002-165825-pre-cast-cursor-review.zip`; `/reload` is sufficient.

### Menu and bags hidden while idle (2026-10-02)
- **Request/finding:** the player wants the menu and bags hidden outside combat too. The previous companion preset selected `hide_in_combat`, whose intended behavior shows the bars again afterward. Blizzard-owned menu/bag holders also defer protected show/hide operations during combat. Idle visibility now uses Ellesmere's existing hover-alpha path.
- **Behavior/options:** Forever Companion -> Action Bars -> Menu And Bags Visibility. Default for this player's requested setup is **Show On Hover**: the micro menu and bag bar, including its keyring, rest at zero opacity in and out of combat and reveal when hovered. **Combat Or Hover** shows them automatically in combat as well. **Native Settings** restores the active profile's captured native visibility. Native fade timing, layout, clicks and other bars are retained; no new animation/polling driver.
- **Migration/storage:** earlier combat-hide snapshots seed the original restore baseline before the old hide veto is removed. `chromeVisibility` belongs to `PROFILE_KEYS`, profile resync and Action Bars reset. `chromeIdleRequested` and profile-name-keyed `chromeVisibilityBefore` are per-character metadata; rename/delete move/clear the corresponding snapshots. Requests during combat wait for combat to end; a queued request cannot change a different native profile. Later Native Settings choices persist across reloads. New profile copies do not inherit character restore snapshots, consistent with existing Restore Original Look storage.
- **Files:** live owned `ActionBarLayout.lua`, `RefinementOptions.lua`, `Profiles.lua`; `Validate.lua` / `RunIntegration.js` execute the installed native visibility, hover resting-alpha and managed extra-bar alpha functions. No third-party addon or SavedVariables file was edited.
- **Evidence:** E1/E2: 39 Lua files, 1855 integration assertions, 414 theme/class checks PASS. Covers hover-only and combat-or-hover inside/outside combat, native restoration, legacy migration, profile storage/rename/delete/reset and deferred combat changes. Installer validation PASS; refreshed-package Check 0 changes; installed Action Bars SHA-256 unchanged (`E07DCA2970A5BD7599568F05B75429B92225EA34745ED47344826D1BB3106DD9`). No E3 result or CPU benchmark. Backup `../Snapshot-20261002-160222-pre-menu-bag-idle.zip`; no TOC change, `/reload` is sufficient.

### Nameplate opacity priorities (2026-10-02)
- **Player decision:** target clearest; focus slightly dimmer; mouseover next; in-range idle dimmer; out-of-range idle faintest. The player confirmed this means visibility, after clarifying the original use of "lower opacity". Existing appearance/disappearance motion is retained.
- **Behavior:** one final root opacity, default target 100%, focus 85%, mouseover 75%, in-range idle 55%, outside-range idle 25%. Target wins over focus, focus over hover, and all three stay readable outside range. Unknown range uses idle opacity; unreadable selection flags stay fully visible. Corpse readiness and marker animations retain their existing implementation.
- **Native integration:** the owned companion wraps native `NT_Apply` at runtime; no installed Ellesmere file is edited. Final opacity is recorded in the native cache so pool cleanup restores full alpha. Native non-target/no-target/range factors do not multiply the priority again. Off restores their current native result without changing saved native settings. Explicit Custom distance is honored. Ordinary updates reuse the companion's displayed range sample; no new polling/animation driver is added, and settled plates skip redundant writes.
- **Controls/storage:** Forever Companion -> Nameplates -> Nameplate Opacity Priority, with five percentage sliders and an off switch. `nameplateOpacity` is in `PROFILE_KEYS`, profile resync and Nameplates reset. `/fhkopacity` includes the active priority state.
- **Evidence:** E1/E2: 39 Lua files parse, 1809 integration assertions and 414 theme/class checks pass. Checks execute the installed native opacity consumer/range sweep and cover precedence, hover exit, target/focus changes, unavailable values, native Custom distance, no-target behavior, pooled spawn/cleanup, off restoration and profile storage/switch/reset. Installer validation PASS; refreshed-package Check reports 0 changes. Installed Nameplates SHA-256 remained `27376D5269F42C21F41D3D9470DAC2826445DE5108435778F93F54AB015DFFF7`. No new E3 or CPU benchmark. Backup `../Snapshot-20261002-154550-pre-opacity-priorities.zip`. No new TOC entry; `/reload` is sufficient.

### Opacity coherence, facing cue and immediate damage feedback (2026-10-02)
- **Why:** the player reported inconsistent opacity after Claude's installed core patch, requested out-of-range fading and a facing cue, and clarified that real health/text must update instantly while only the lost-health segment drains.
- **Opacity:** Hunter automatic plate fading now adapts the native `Range_SweepBeyond` path as well as the single-target reader. A short-lived GUID-aware cache shares readings with range text/marks; Custom remains native; unknown remains visible. The requested native fade activates once if disabled, with the native 50% default if alpha was absent/100. Chosen custom settings and later native edits are retained.
- **Cue restoration/performance:** marker animations start at existing alpha, retain changes to the native base, and release restricted alpha to native output. Visible markers share a verdict; empty plates/hidden guide parents do not probe. Guide registrations reuse state; finished frame fades leave the active sweep.
- **Facing:** a steady `FACE TARGET` label on the existing range HUD responds to explicit native facing errors. Harmful-cast success, target/world change, or 1.2-second expiry clears it. Events unregister off. `/fhkfacing` and Check Facing Data perform a guarded on-demand position check; estimates are diagnostic, with no camera-based prediction or directional arrow. `/fhkopacity [unit]` explains the native opacity layers.
- **Damage:** Instant Health Feedback defaults on within Damage Trail and finishes native interpolation through `SetToTargetValue`; native health text stays immediate. Only the lost segment drains/fades. Default duration 0.18 seconds; old default 0.28 is shortened once, other/later choices retained. Successive hits start from the visible edge, avoiding resurrected chunks; healing stops the animation driver immediately. Restricted health snaps through the engine but never enters trail arithmetic.
- **Files:** live `Companion.lua`, `CueFades.lua`, `DamageTrail.lua`, `RangeIntegration.lua`, `RefinementOptions.lua`; integration harness `Validate.lua` / `RunIntegration.js`; generated package, README, handover and the linked review.
- **Storage:** `indicators.range.facingWarning` and `damageTrails.<kind>.instantHealth` ride with the existing `PROFILE_KEYS` parents. `rangeOpacityRequested`, `rangeOpacityBefore`, `quickDamageTrailApplied` and `damageTrailDurationBefore` are per-character application flags / restore metadata.
- **Evidence:** E1/E2: 39 Lua files parse; 1756 integration and 414 theme checks pass, including the installed native opacity consumer and composition, rapid hits and max-health changes. Installer validation and package Check pass with 0 changes. No in-game observation or CPU benchmark. **Restart:** `/reload`; no TOC changes. Backup `../Snapshot-20261002-150421-pre-opacity-review.zip`.
- **Further audit:** [Opacity and feedback review](OPACITY_AND_FEEDBACK_REVIEW_2026-10-02.md) separates implemented fixes, existing Ellesmere features, remaining performance opportunities and the E3 checklist.

### Checked against installed Ellesmere 9.3.5 (2026-10-02)
- The suite is now 9.3.5 plus the core candidate (see `../Ellesmere-Core-Patch/CHANGELOG.md`). The companion takes its 9.3.5 path: options register through `RegisterPlugin`.
- **Validate.js:** 9.3.5 renamed "Menu, Bags & XP Bars" to "Menu, Bags & Rep Bars", and XP moved to a new "XP Bar" page. Appended page names are used only on 9.3.4; 9.3.5 routes sections by module. So when the installed suite has `RegisterPlugin`, the 9.3.4 name is accepted. Deep links must still name a page that exists in the installed suite.
- **Hook audit (E1):** every Ellesmere function, field and setting the companion uses still exists, except `ns._csForever` and `charSheetUseForeverStyle`. ModernChrome only clears or sets those, so it is harmless.
- **Evidence:** E1/E2. Validate.js, integration 1693, themes 414, installer and package check pass. The plugin pages have not yet been seen in game.

### Unit-frame range bar extends the frame (2026-10-02)
- **Why:** the player found the range bar too thin and sitting on the frame's left border, where it read as a stray line rather than part of the frame. They asked for it to extend the frame and default to the outer right.
- **Change (`RangeIntegration.lua`):** the bar is now a small bordered tab outside the frame. By default it sits on the right, 5 px of colour inside Ellesmere's own 1 px pixel-perfect border (`PP.CreateBorder`), full frame height. At gap 0 it overlaps the frame by one border pixel, so the two borders merge into one line. New **Range Bar Placement** option: Extends the Frame (default) or Inside the Frame (the old edge stripe).
- **Migration:** saves made before the new option was added move from the old default (left, 3 px) to the outer-right tab. A side or thickness the player chose is kept, and it also extends the frame. `indicators` is already a per-profile key.
- **Evidence:** E2. The integration suite (1692 checks) covers tab geometry, the border overlap, gap, bottom placement, the inside fallback and both migrations. The Ellesmere validator's mock now resolves shipped icon paths to file IDs, matching the FHK icon change below. Themes 414, installer and package check pass. Not yet seen in game (E3).

### Core candidate review corrections, package 0.1.1 (2026-10-02)
- **F12/F31:** prepared-only corrections ignore empty reminder commits, preserve ordinary elapsed/estimated flight displays and keep an existing flight across world entry. The section-header table concern was checked against the native parent export and did not require a source change.
- **Evidence:** E2. Core Lua 5.1 checks pass; 14 candidate tests and six disposable-folder installer tests pass. No installed-addon or SavedVariables writes and no E3 evidence. The focused review delta is `../Ellesmere-Core-Patch/review-fixes.patch`.

### Core audit candidates prepared separately (2026-10-02)
- **Scope:** F07/F12/F27/F29/F30/F31/F33/F40/F42/F45 candidates live in the isolated `.dev/EllesmereUI-core-audit` worktree and `Ellesmere-Core-Patch/`, not the live companion package. No live addon changes. The player directed "Prepare the patches only; do not install"; the installed suite stays 9.3.4.
- **Evidence:** E2. Core Lua 5.1 static/compilation checks pass (16 Lua files); 12 candidate behavioral tests and six disposable-folder installer tests pass. No in-game verification. See `../Ellesmere-Core-Patch/CHANGELOG.md` and README for per-item scope and remaining checks. Inherited companion test counts are separate evidence.
- **Publication:** nothing posted/pushed; local Chat change separated from the upstream review candidate. F07/F40 maintainer discussion remains outstanding. Full restart required after any future core candidate installation because files/TOC entries are new.

### Non-target range glow sits outside the bar (2026-10-02)
- **Why:** the player saw nameplates look inconsistent: an "internal glow" on some, a bright line across the health text ("691") on others, nothing on a few.
- **Cause:** three states looked alike.
  - The current target uses Ellesmere's own glow, which includes a centre fill (native, unchanged).
  - Our non-target ring used corner 10 / extend 4, so its top and bottom strips reached 6 units into the bar and met across the text on short plates.
  - Plates with no readable range get no mark (by design).
- **Fix:** the ring is corner 7 / extend 7, sitting fully outside the bar edge. It never draws inside the bar or across the text.
- **Evidence:** E2 (1684, ring geometry asserted). Needs `/reload` and an in-game look.

### Quest bar 8: active item replaces RestedXP Follow (2026-10-02)
- **Why:** the player doesn't use RestedXP Follow and wants the active guide item on a quick key instead.
- **Change:**
  - **Bar 8 slots:** 1 is RestedXP targeting (U); 2 is the **active guide item**, on **Shift+U and I** (and Ctrl+Naga 12, which falls back to this slot); 3-7 are further guide items on Shift+I / Ctrl+I / Ctrl+U / Alt+U / Alt+Shift+U; 8 is an unbound seventh item.
  - The Follow macro no longer goes on the bar.
  - Keys still on another bar-8 button from the earlier layout are moved, not reported as player rebinds. A key the player rebound to something else is still left alone.
- **Files:** live `QuestBar.lua`, `RefinementOptions.lua` (tooltip); FHK `FULL_KEYMAP.md`; `Validate.lua` (updated slot and key assertions, plus an upgrade-migration check); generated package.
- **Evidence:** E2 integration PASS (1683), FHK 15/15, installer PASS, package check 0 changes. Applies on `/reload` (the quest bar refreshes on entering the world).

### Micro menu and bag bar hide in combat (2026-10-02)
- **Why:** the player asked for the bag slots, keyring and menu to fade out in combat like chat.
- **Change:** **Hide Menu And Bags In Combat** (Action Bars -> Hunter Keyboard Layout) adds Ellesmere's native `hide_in_combat` lane to `MicroBar` and `BagBar`, keeping any existing visibility rule. The keyring lives in the bag bar. Ellesmere's managed-bar combat refresh (`PLAYER_REGEN_DISABLED/ENABLED`) handles the transitions.
  - Off restores each bar's exact previous visibility fields (`fhkCombatHideBefore` on the native bar settings).
  - Changes requested in combat apply when combat ends.
  - Switched on once for this player (`fhkChromeCombatApplied`); turning it off later sticks.
- **Evidence:** E2 integration PASS (1680, +9), theme checks PASS, installer PASS, package check 0 changes. Needs a `/reload` and an in-game look.

### Pet action bar centred above the combat rows (2026-10-02, player's choice)
- **Options the player suggested:**
  - **Vertical, 2 columns beside the unit frames:** rejected. Left of the player and pet frames is the chat window, and right of the target frame are target-of-target and the RestedXP bar.
  - **Centred above the middle bars:** chosen. That space is free, about 100 units between the third combat row and the attack icon under the swing HUD.
- **Change:** the pet bar is one row of 10, centred (x 0), 12 units above the third combat row. `PET_BAR_VERSION` 3 re-places only the pet bar, once. It still counts as a wing for Fade Wing Bars While Idle.
- **Evidence:** E2 (1671; clearance asserted against the combat rows and the HUD). Needs a `/reload` and an in-game look.

### Pet action bar moved clear of the pet frame (2026-10-02)
- **Why:** the player's screenshot showed the new 5x2 pet action bar overlapping the pet unit frame.
- **Geometry (from saved settings):** UI scale 0.8, so the screen is 960 units tall. The pet frame is centred at (-263, -210) with 25 health, 4 gap and 6 power, so its bottom edge is about 247 units from the screen bottom. The 5x2 bar's top reached about 262: a 14-unit overlap.
- **Fix:** the pet bar is now **one row of 10** in the gap above the left wing (bottom 198, top 230), clear of the wing below and the pet frame above. `PET_BAR_VERSION` 2 re-places only the pet bar, once.
- **Checked:** Ellesmere's pet frame has no aura or cast-bar settings, so it reserves no hidden space under itself or against the player frame.
- **Noted, not changed:** the chat window (bottom-left) runs behind the left wing's left half. Chat now fades after 5 s and hides in combat; resizing it is the player's call.
- **Evidence:** E2 (1671, including a pet-frame clearance assertion). Needs a `/reload` (the pet bar moves at login) and an in-game look.

### Chat fades sooner; optional hide in combat (2026-10-02)
- **Why:** the player found chat took too long to fade, and asked about hiding it in combat.
- **Fade:** the companion's chat setup used a 10 s idle delay (Ellesmere's own default is 15 s). It's now **5 s** with full fade. A one-time step (`chatFadeVersion` 2, per character) changes it only if the saved value is still our 10. A delay set in Ellesmere's native Chat options (Idle Fade Delay) is left alone.
- **Hide Chat In Combat** (Chat page on 9.3.4; Forever Companion General page on 9.3.5):
  - adds Ellesmere's native `hide_in_combat` visibility lane to the existing chat visibility through `SetVisibilitySelection`, so any other rule (e.g. party only) is kept;
  - the native chat module handles the combat transitions;
  - off restores the exact previous visibility, kept on the chat profile as `fhkVisibilityBefore`.
- **Default for this player:** Hide Chat In Combat is switched on once at login (`chatCombatHideApplied`, per character), because the player asked for chat to fade out in combat. Turning the toggle off afterwards sticks.
- **Keybind audit (same request, read-only):** live bindings and macros match the FHK profile. There are no duplicate bindings and no stray keys on FHK slots; 1 and 2 are Blizzard defaults, so they aren't in the cache.
  - The suspected duplicate, Alt+Shift+Q, is **Summon Hawk** (Forever Beast Mastery talent, 15 BM points). It shares Arcane Shot's 6 s cooldown, so it mirrors Arcane Shot's sweep.
  - Only Auto Shot appears in several macros (the melee-weave returns), as intended.
- **E3 to check:** whispers during combat appear when chat returns; pressing Enter to type in combat still works (native behaviour of the hidden chat stack).
- **Files:** live `Companion.lua`, `RefinementOptions.lua`; `Validate.lua` (+6); generated package.
- **Evidence:** E2 integration PASS (1669), installer PASS, package check 0 changes. No E3.

### Pet bar, paw happiness icon, presets on Style (2026-10-02)
- **Pet action bar (player report: "where's my pet bar?"):** Ellesmere's native PetBar was saved `alwaysHidden=true` / visibility `never` (set by neither FHK addon), and its old position (-433, -466) was off the bottom-left of the screen.
  - The Hunter layout now includes it: top of the left (pet) wing, 5x2, same button size.
  - It's placed **once on its own** (`p.fhkPetBarVersion`), so every other bar stays as the player left it.
  - It joins the existing Undo step. Combat defers only the pet-bar step, never the full layout.
  - Undo skips bars an older snapshot never covered.
- **Pet happiness icon (player report: "still using the default Blizz one"):** Ellesmere's pet frame shows Blizzard's stock mood faces (`UI-PetMad` / `Neutral` / `Happiness`). It's now restyled as a flat **paw glyph**:
  - new `media/menu-paw.png`, built by `Build-PawIcon.ps1` with editable SVG, in the same pipeline as the skinning/keyring glyphs;
  - tinted with the same mood colours as the pet bar and strip;
  - native position, size, side options and the hover tooltip (happiness, damage, loyalty, diet) are kept;
  - turning Pet Happiness colours off restores the stock art.
- **Theme presets moved to Global Settings -> Style** (player request), beside Ellesmere's own look choices; they were under Colors.
- **Files:** live `ActionBarLayout.lua`, `UnitRefinements.lua`, `RefinementOptions.lua`; NEW media `menu-paw.png/.svg`, `Build-PawIcon.ps1`; `Validate.js` (paw glyph check), `Validate.lua` (+13), `ValidateThemes.lua` (Style page); `RefreshPackage.js` owns the new media; `AFTERGLOW.md`/`HANDOVER.md` paths.
- **Evidence:** E2 integration PASS (1663), theme checks PASS (414), Lua parse PASS, installer PASS, package check 0 changes. No E3.
- **Restart needed:** **full restart** (new texture file and `Profiles.lua`). The pet bar placement runs at the next login.

### Options work on Ellesmere 9.3.5's sealed pages (2026-10-02)
- **Why:** reviewing the core candidate confirmed (E1, pristine 9.3.5 source) that 9.3.5 deliberately seals its own option pages. Outside addons can no longer change them; the change is ignored and the player gets a notice naming the addon. The supported route is `EllesmereUI.RegisterPlugin`. Every companion options section used the old page injection, so all of them would have vanished after an upgrade.
- **Change:** `RefinementOptions.lua` runs in one of two modes.
  - **9.3.4 (installed, no `RegisterPlugin`):** unchanged. Sections still appear on the native pages.
  - **9.3.5+:** the same sections register once as a **Forever Companion** plugin section in the sidebar, with pages General, Action Bars, Unit Frames, Nameplates, Resource Bars and Warnings. They're rendered by one shared section renderer, so advanced-row hiding and every control behave identically.
  - The plugin's own **Reset** clears all companion settings on the active profile. On 9.3.5 the suite's Reset buttons can't be wrapped, so audit F02's per-module reset becomes this single reset.
- **Unaffected on 9.3.5 (checked in source):** `_ModuleNS` is still open, so gameplay refinements keep their access. All 79 Ellesmere symbols and runtime hook points the companion uses still exist; deep links (`NavigateToElementSettings`) still work.
- **Fail-soft on 9.3.5 (needs E3):**
  - `holder._fvDivHost` is gone, so our XP ticks may sit beside native dividers;
  - nameplate "Range" text-slot choices need page wrapping and are 9.3.4-only.
- **Policy note:** `UnitRefinements` still extends the native Power Text dropdown by wrapping the shared widget factory. 9.3.5 doesn't block this, but it is against the new policy's spirit; move those formats onto the plugin page if the maintainer objects.
- **Files:** live `RefinementOptions.lua`; `Validate.lua` (+7: plugin registration, pages, rendering, sealed pages untouched, own Reset); generated package.
- **Evidence:** E1 against 9.3.5 `RegisterPlugin` validation rules (id, label, pages, callbacks); E2 integration PASS (1650), theme checks PASS (413), Lua parse PASS, installer PASS, package check 0 changes, FHK 15/15. No E3; 9.3.5 is not installed.

### Audit pass 2: every companion-side finding closed (2026-10-02)
- **Why:** the player asked to close out the whole audit, except the health colour change as health drops (their own request), and clarified that dark modes should warn through text, not bar fills.
- **Dark modes warn in text (player direction):** a bar's own dark switch now hands its fill to Ellesmere for health and for resources. This covers Unit Frames (one switch) and Resource Bars (per-bar `health`/`primary`/`secondary` `darkTheme`); both the gradient and resource dimming stop. Text colours keep warning. Before, unit-frame power bars still dimmed in dark mode, and our gradient repainted the dark Resource Bars health bar.
- **F02:** each module's native Reset also clears that module's companion settings (Nameplates, Unit Frames, Resource Bars, Action Bars, QoL map in `Profiles.lua` `RESET_KEYS`). This wraps `config.onReset`; Ellesmere then reloads as usual.
- **F04:** history key labels seen held are bright; labels looked up from a binding are dimmed.
- **F06 (revised by the player):** pending quest XP is a **quest-gold** segment ahead of the earned fill at 55% (colour picker plus default button), with no tooltip text. The interim tooltip wording ("3 of 5 known" and so on) was removed at the player's request.
- **F08:**
  - XP options -> Action Bars "Menu, Bags & XP Bars";
  - press flash/history -> "Bar Animations";
  - Forever Class HUD -> Resource Bars "Class, Power and Health Bars".
- **F14/F34:** Apply Hunter Layout and Apply Hunter Polish keep one undo step on the native Action Bars profile, so it travels with profile copies. The new Undo buttons restore exactly what was replaced, including user adjustments, unlock links and the cooldown-number CVar. Applying prints a one-line summary.
- **F18 + bug:** the centre range text now uses the Resource Bars font. This exposed three files passing the font key `'resourcebars'`; Ellesmere's key is `resourceBars`, so that text had ignored the player's Resource Bars font choice. Fixed in `RangeIntegration.lua`, `ResourceRefinements.lua` and `ClassMechanics.lua`. `Validate.js` now rejects unknown font-module keys.
- **F19:**
  - semantic gameplay colour tokens live in `FHKEllesmereNS.Colours` (`Bootstrap.lua`);
  - `Companion`, `UnitRefinements`, `Warnings` and `XPBarRefinements` read them (same values);
  - the precedence table (one channel per fact) is in style guide 5a-ii.
- **F20 / F21 / F25:**
  - F20 and F21 closed by the player's 2026-10-02 screenshots: layout accepted; FHK shows real icons for unlearned spells, no "?".
  - F25: the object interact icon is engine-drawn and already range-gated (`SoftTargetIconGameObject`, `PLAYER_SOFT_INTERACT_CHANGED`). It can't be faded by addons; a native **Object Interact Icon** toggle is added instead.
- **F23:** **Range Cue Preset** (Minimal / Weaving / Detailed / Custom) on Nameplates. Current defaults read as Weaving.
- **F24:** Resource Bars class page gains goal buttons:
  - Track Cooldowns And Procs; Track Buff Durations;
  - Warn When A Buff Is Missing; Show My Auras As Bars;
  - Hunter: Hunter Warnings and Swing Timer.
  - Each deep-links to the existing Ellesmere page. `Validate.js` checks every linked/appended page exists.
- **F26:** history section explains "what you pressed" vs Spell History's "what was cast", with a button to open Spell History.
- **F32:** **Preview Scenario** on Global -> General and `/fhkpreview` show fixed states for about 10 seconds:
  - In Range, Approaching Deadzone, Deadzone, Melee, Out of Range, Range Unknown;
  - Warnings, Action History.
- **F35:** shared idle gate (`EllesmereBusy`). Unit Frames, Resource Bars and Companion sweeps run at 0.15 s only in combat, with a target or focus, with visible nameplates or in unlock mode; otherwise once a second. Target/focus/pet/combat-start events repaint immediately; player health/power events already did.
- **F44:**
  - optional **Naga Button Labels** in history: F9-F12/Insert/Delete -> N1-N6; Synapse chords -> N9/N11/N12; modifiers kept, so Shift+F9 shows as S+N1;
  - every option label now uses Ellesmere's US wording (Color, Center); `Validate.js` enforces it.
- **F46:** **Reduce Companion Motion** (Global -> General):
  - steady warnings; history fades without sliding;
  - instant cue fades and XP fill; no XP glow or damage trail.
- **F47:** fine-tuning rows (sizes, offsets, opacities, custom colours) are tagged advanced and hidden by default. A section with hidden rows shows "N advanced rows hidden" with a **Show Advanced Options** button; the same switch is on Global -> General.
- **Still open (not ours to edit, or needs the player):**
  - F07, F12, F27, F29, F30, F31, F33, F40, F42, F45 are Ellesmere core: upstream proposals only, never edited here;
  - F38 is the in-game pass.
- **Files:** live `Bootstrap`, `Profiles`, `UnitRefinements`, `ResourceRefinements`, `RangeIntegration`, `Companion`, `Warnings`, `XPBarRefinements`, `ActionPressFeedback`, `ActionBarLayout`, `HunterPolish`, `DamageTrail`, `CueFades`, `ClassMechanics`, `ThemePresets`, `RefinementOptions`; `Validate.js` (3 new static checks), `Validate.lua` (+~50), `ValidateThemes.lua` (+~10); style guide; generated package.
- **Evidence:** E1 Ellesmere source review (reset, pages, navigation, fonts, soft-target CVars); E2 integration PASS (1643), theme checks PASS (413), Lua parse PASS, installer PASS, package check 0 changes, FHK 15/15, RestedXP adapter PASS. No E3 for these changes.
- **Restart needed:** no new files since `Profiles.lua` (one full restart covers both).

### Companion settings ride with Ellesmere profiles (2026-10-02, audit F01 + F41)
- **Why:** exporting, sharing or switching an Ellesmere profile reproduced the native layout but not the companion's range cues, warnings, colours, history, XP or HUD settings. Those lived only in the per-character `FHKEllesmereDB` (audit F01, P1).
- **Change:** NEW `Profiles.lua` (after `Bootstrap.lua`):
  - **Storage:** about 40 gameplay/appearance keys (`PROFILE_KEYS`) now live on `EllesmereUIDB.profiles[<active>].fhkEllesmere`. A metatable on `FHKEllesmereDB` reads and writes them there, so no module changed.
  - **Per character:** binding/slot ownership (quest bar), restore snapshots (`*Before`), version flags and FHK weave timing.
  - **Switch:** takes effect immediately, and live features re-sync through Ellesmere's dark-mode refresh callback.
  - **First visit:** a profile seen for the first time copies the previous one.
  - **Copy, rename, delete and export:** native, because Ellesmere copies, moves or removes the whole profile table.
  - **Import:** a post-hook on `ImportProfile` applies a full string's companion settings. Subset strings keep the recipient's.
  - **F41:** `themePresets` and `classHUD` (per character, keyed by profile name) now follow profile renames and deletes.
- **Migration on first login:** this character's settings move onto the active profile ("Default"). If a profile already carries companion settings from another character, the profile wins, and the character's values are kept under `_preProfile`. Alts on the same Ellesmere profile now share companion settings.
- **Ellesmere checked (read-only):**
  - `ExportProfile` deep-copies the stored profile, so unknown root keys ride along;
  - `SaveCurrentAsProfile` deep-copies;
  - `RenameProfile` moves the same table;
  - `DeleteProfile` removes it;
  - no whitelist strips unknown profile keys;
  - `AutoSaveActiveProfile` is a no-op.
- **Files:** NEW live `Profiles.lua`; TOC; `RefreshPackage.js` (owned file); `Validate.lua` (+19 assertions); `DEVELOPMENT.md` "Settings storage" (the rule for classifying new keys); generated package.
- **Rollback:** `Snapshot-20261002-101713-pre-profiles.zip` in the game root. Settings already migrated stay on the profile; restoring the old files makes the companion read only `FHKEllesmereDB` again, so it would start from defaults. Copy `fhkEllesmere` back from `EllesmereUIDB` with WoW closed if needed.
- **Evidence:** E1 Ellesmere profile-path review; E2 integration PASS (1590), Lua parse PASS (39 files), installer PASS, theme checks PASS, package check 0 changes, FHK 15/15. No E3.
- **Restart needed:** **yes, a full restart** (new TOC file).
- **E3 checks:**
  - settings survive the restart;
  - copy a profile and change a warning toggle in the copy only;
  - switch back and forth;
  - export, then import as a new profile;
  - rename and delete a copy.

### Audit pass 1 and theme validation (2026-10-02)
- **Why:** the player asked to work through the 2026-10-02 UI audit and to validate the Afterglow and Dark themes and their setup. Per-finding status is in `UI_AUDIT_2026-10-02.md` -> Status.
- **Afterglow contrast fix:** health fill `#12142D` sat on missing-health `#202638`, a 1.22:1 contrast, so remaining health was nearly invisible. Native Dark is `#111111` on `#4F4F4F` (2.3:1). Missing health is now slate `#4A5470` (2.44:1); resource backings keep `#202638`, and mana on that backing is above 4.5:1. `ValidateThemes.lua` now asserts both contrasts. The player has no preset applied (checked in SavedVariables), so nothing changes until a preset is picked.
- **Theme setup gap: pet happiness in dark themes.** Codex made native Dark win over pet happiness, which silently dropped the player's happiness colour under Dark/Afterglow. Following the player's direction, dark themes now keep the pet fill dark and show happiness as a **thin placeable strip** (Unit Frames -> COLOUR AND TEXT REFINEMENTS):
  - position Top/Bottom/Left/Right; thickness 1-8 px;
  - length 10-100% with Left/Center/Right alignment for top/bottom strips;
  - gap and opacity;
  - "Happiness Strip In All Themes", which keeps the health colours on the fill everywhere.
  - Outside dark themes, happiness remains the bar colour by default.
- **F05:** Loot Icons and Skinning Icons are now independent; turning loot off no longer hides skinning cues.
- **F16:** Health/Resource Text Colours off now hands colour back to Ellesmere (no fixed whites) and asks Unit Frames, Nameplates and Resource Bars to repaint their own colours. This also fixed a fallthrough where player-bar health text could take the resource colour.
- **F13:** Player Resource Format no longer raises the power-bar height; height stays with the native Power Height control. (Existing heights are unchanged.)
- **F11:** moving Low Ammo below Critical (or the reverse) drags the other value with it and prints which one moved.
- **F37:** Hunter Polish records its version after the native refreshes and returns `'partial'` with a chat note if one fails. Settings are still saved and apply on reload.
- **F39 (P1):** `QuestBar.lua` and FHK `RestedXPMarkers.lua` no longer read RestedXP directly. All reads go through FHK's `RestedXPAdapter.lua`; see the FHK changelog for the new adapter calls and checked touchpoints.
- **F03 (P1):** quest bar 8 ownership:
  - it records what each key did before it claimed it;
  - a claimed key that the player rebinds is left alone and reported once;
  - Action Bars -> HUNTER KEYBOARD LAYOUT gets a **Guide Quest Bar (Bar 8)** toggle and `/fhkquestbar on|off`;
  - off restores replaced keys, clears its bar-8 macros, brings back RestedXP's own item panel and lets FHK bind Ctrl+Naga 12 again;
  - `/fhkquestbar` lists owned keys and conflicts.
  - Keys claimed before this version have no recorded "before" value; turning off unbinds those.
- **F10 / F04 / F43 / F28:**
  - history and flash controls grey out with the reason until their feature is on; folding is disabled in cast mode;
  - cast mode is renamed "Casts From Bar Keys";
  - "History Visible Seconds" is renamed "Hide History After Idle (sec)";
  - every companion opacity slider now reads in % (history, flash, range glow, stripe, range bar, range indicator, attack icons, damage trail).
- **F22:** only the top (most urgent) warning keeps pulsing. Others pulse twice on arrival and then hold steady, and the next one takes over the pulse when the top one clears.
- **F09:** both Health Bar Colours toggles say that they are one shared setting.
- **Files:** live `ThemePresets.lua`, `UnitRefinements.lua`, `ResourceRefinements.lua`, `Companion.lua`, `Warnings.lua`, `HunterPolish.lua`, `QuestBar.lua`, `ActionPressFeedback.lua`, `RangeIntegration.lua`, `DamageTrail.lua`, `RefinementOptions.lua`; FHK `RestedXPAdapter.lua`, `RestedXPMarkers.lua`, `tools/CheckRestedXP.js`; `Validate.lua` (+68 assertions), `ValidateThemes.lua` (+2), FHK tests `test_rxp_markers.py` and `test_rxp_forever_automation.py`; generated package; `UI_AUDIT_2026-10-02.md` status; `AFTERGLOW.md`.
- **Evidence:** E1 audit re-check against current code; E2 integration PASS (1571), theme checks PASS (401), Lua parse PASS, installer PASS, package check 0 changes, FHK tests 15/15, RestedXP adapter 13/13 touchpoints on the installed RestedXP. No E3.
- **Restart needed:** no new files; `/reload`.

### Unit-frame range bar (2026-10-02)
- **Why:** the player asked for a range indicator on the unit frames that can sit on the left, right, top or bottom with a thickness setting. Their style reference was the accent edge on the selected row in Ellesmere's damage meter.
- **Change:** target, focus and (optionally) target-of-target frames get a thin accent bar in the same range colours as the nameplates and HUD: mint when shooting, yellow nearing the deadzone, coral in the deadzone or out of range, accent in melee. Enemies only. It's hidden while range is unknown and fades in (0.2 s) and out (0.35 s) with the shared Companion smoothstep fade. The target uses the HUD's cached range sample; other units use the same range reader as nameplates. It runs in the existing Companion tick (no new OnUpdate), and the bar is created only when first needed.
- **Controls:** Unit Frames -> RANGE BAR:
  - on/off, position (Left / Right / Top / Bottom), thickness (1-12 px), gap (moves it outward), opacity, style (Flat / Native Texture);
  - colour (Range State / Custom) and a custom colour;
  - per-frame toggles for Target, Focus and Target of Target.
- **Defaults:** on; left edge, 3 px, inside the frame, 90% opacity; Target and Focus on, Target of Target off.
- **Refactor:** the nameplate edge stripe and the new bar share one `PlaceEdge` helper in `RangeIntegration.lua`.
- **Files:** live `RangeIntegration.lua`, `Companion.lua`, `RefinementOptions.lua`; `Validate.lua` (+16 assertions); generated package.
- **Evidence:** E2 integration PASS (1503 checks), Lua parse PASS, installer PASS, package check 0 changes. No E3.
- **Restart needed:** no; `/reload`.

### Soft range glow on non-target nameplates (2026-10-02)
- **Why:** the player's first in-game look (screenshots, 2026-10-02) showed that the selected target's range-tinted glow reads clearly. The 6px edge stripe on other enemy plates was nearly invisible against the beige health fill.
- **Change:** non-target enemy plates now get a soft glow tinted by range. It reuses Ellesmere's own target-glow artwork (`EllesmereUINameplates/Media/background.png`, same 9-slice coordinates, ADD blend, BACKGROUND strata) but is tighter (4px vs 6px extend, 10px vs 12px corners), dimmer (45% opacity) and has no centre fill, so the selected target's full glow stays dominant. Created lazily per plate; it inherits the plate's own range fade because it's parented to our plate overlay.
- **Controls:** Nameplates -> HUNTER RANGE AND CORPSES: new **Non-Target Range Mark** (Soft Glow / Edge Stripe) and **Range Glow Opacity**. The old toggle is renamed "Non-Target Range Mark" and still switches either style off. Existing stripe position/thickness/colour settings apply in Edge Stripe mode; custom colour applies to both.
- **Settings:** `indicators.plate.mode` (`glow` default) and `glowOpacity` (0.45). `EllesmereIndicatorSettings` now fills in keys missing from older saved settings without overwriting saved values.
- **Files:** live `RangeIntegration.lua`, `Companion.lua` (one call, with a stripe fallback), `RefinementOptions.lua` (label); `Validate.lua` (+11 assertions); `Validate.js` (artwork check); generated package.
- **Evidence:** E2 integration PASS (1487 checks), Lua parse PASS, installer PASS, package check 0 changes. **E3 from the same screenshots, for earlier work:** nameplate range text, a target glow tinted by range (deadzone and shooting colours), the Unspent Talent Points warning stacking under Low Durability, attack indicators, unit frames and the bar layout all render in game.
- **Restart needed:** no; `/reload`.

### Forever build 70170 review and ammo check (2026-10-02, Claude pickup after Codex)
- **Why:** the client patched itself from 1.60.1.70124 to 70170 overnight. Reviewed the Blizzard UI diff (119 files) against everything our addons call.
- **Findings:** nothing we use was removed or renamed. The nameplate option `useOutlinedNameWhenAboveHealthBar` became `useOutlinedFontWhenAboveHealthBar` (not used by us). The `TOGGLECOLLECTIONSHEIRLOOM` binding was removed (not used). The stable UI was reworked, but `diet:UpdateHappiness` and `C_PetInfo` happiness are unchanged. The client added new APIs: `UnitUsesAmmo(unit)` and `C_Spell.GetItemCooldown(itemID)`.
- **Change:** `Warnings.lua` asks `UnitUsesAmmo('player')` first when it returns a readable boolean, and otherwise falls back to the bow/gun/crossbow check. The server's answer now decides whether the ammo warning applies.
- **Files:** live `Warnings.lua`; `Validate.lua` (+3 assertions); generated package. `.dev/wow-ui-source-forever` fast-forwarded to `9a789c0` (70170).
- **Evidence:** E1 API diff review; E2 integration PASS (1476 checks), Lua parse PASS (38 files), installer PASS, theme checks PASS (399), package check reports 0 changes. No E3.
- **Restart needed:** no new files; `/reload` is enough.

### Saved critical product/UI audit (2026-10-02, side conversation)
- **Why:** preserve the requested audit on disk so future work can refer to stable finding IDs instead of relying on chat history.
- **Files:** NEW `UI_AUDIT_2026-10-02.md`; root `HANDOVER.md` links to the report.
- **Coverage:** all 47 findings (0 P0, 6 P1, 37 P2, 4 P3), master table, installed-module coverage, ten detailed sections, four-phase roadmap, product recommendations, evidence references and follow-up rules. All findings remain open observations/proposals; no fixes are claimed.
- **Settings / Ellesmere surface touched:** none. Documentation only; live addon code, generated package, third-party files and SavedVariables are unchanged.
- **Evidence:** E1 static audit and document structure/link checks; supplied screenshot observations are labelled separately. No new E2 or E3 checks; current in-game verification remains pending. Recheck source-dependent findings against later changes.
- **Restart needed:** no.

### Press feedback and animated action history (2026-10-01)
- **Why:** give every action-bar press a visible response, including a rejected or cooldown-blocked action, and let viewers follow recent inputs or successful casts.
- **Controls:** Action Bars -> KEY PRESS AND ACTION HISTORY. Flash Every Action Press and Recent Action History both default off. The separate Recent Actions unit uses Ellesmere Unlock Mode for movement and resizing, with a stable preview while editing. Native action-bar fonts and the live accent are reused.
- **Motion:** new icons fade in while sliding from the side; previous entries move along and become more subtle; the oldest slides out. The strip fades after a configurable idle delay (six seconds initially). Horizontal or vertical layout, 3-8 icons, size, spacing, zoom, opacity, older-icon opacity, key label size/position and optional mouse clicks are configurable. Press mode can fold consecutive repeats into an xN count. Flash opacity/duration are separate controls.
- **Input / casts:** secure post-hooks observe native main/multi/pet/stance and click-routed action paths without changing bindings or actions. Key labels use a held primary/secondary binding when detectable, otherwise the assigned primary binding. Successful Casts only records readable player cast successes associated with an action-bar input; unsolicited auto/pet casts are excluded. Current-engine resolved macro spell IDs and legacy macro lookup are supported. Instant successes are deferred until the protected input handler returns; same-frame casts retain their own input labels. Arbitrary multi-spell macro sequences and restricted payloads cannot always be associated, so they may be omitted.
- **Runtime:** engine Alpha/Translation animations are reused; no new Lua OnUpdate. Cells and pending inputs are bounded. Rapid inputs continue from interpolated positions. Failed, quietly failed and interrupted cast results consume their pending input without adding history, preventing it from labelling a later automatic cast. Disabling hides/stops visuals, unregisters events/listeners and invalidates deferred results; installed post-hooks then return immediately.
- **Files:** NEW live `ActionPressFeedback.lua`, TOC, native options append, package generator, integration tests and documentation. Existing side-conversation ThemePresets/ClassMechanics files and registrations are preserved.
- **Rollback:** `Snapshot-20261001-232053-pre-keypress-feedback.zip` in the game root.
- **Evidence:** E1 native Forever bindings, animation and event API review; E2 integration PASS (1473 checks, 96 added), Lua 5.1 parse PASS (38 files), installer/package consistency and active FHK regression checks PASS. No E3 evidence. Full client restart required for the new TOC entry.
- **E3:** enable each feature separately; spam abilities on cooldown/out of range; check keyboard/modifier/Naga/wheel/custom-page/pet/stance paths, casts and interrupted/instant casts. Move/resize, preview, switch orientation, observe entrance/overflow/idle fades, and check disable/reload persistence. Successful mode must not invent failed casts or flood from Auto Shot. Artwork exploration remains paused.

The previous Codex session hit its usage limit part-way through. State was audited on 2026-10-01; see DEVELOPMENT.md → Current state.
Rollback point taken before the fixes below: `Snapshot-20261001-2049-pre-1.8-fixes.zip` (game root).

### Optional Afterglow presets and class HUD (2026-10-01, side conversation)
- **Why:** add the requested third palette alongside Coloured and Dark, keep Ellesmere's clean layout and animation settings, and cover native Forever class resources. This is separately authorised palette work; the parent's artwork/backlog work is retained.
- **Themes:** new `ThemePresets.lua`, native Global Settings -> Colors -> FOREVER THEME PRESETS. Initially no preset is active. Coloured turns native dark switches off; Dark uses the original palette and native dark switches; Afterglow uses ink/slate health surfaces, coloured resources, nine classic class accents, two small health-edge strips and the existing native Pixels panel background. Restore Original Look restores the pre-preset palette, switches, accent, resource colour preferences and panel background. Native palette-sharing locks are respected. Layout, fonts, secure actions and motion settings are retained. Combat changes queue and cancel across profile changes. Native setter errors attempt palette rollback; off has no events after login and no trim textures are created before Afterglow is selected.
- **Classes:** new opt-in `ClassMechanics.lua`, separate Forever Class HUD toggle and `/fhkclasshud on|off`. Uses native primary power on all nine classes; native target combo points for Rogue/Cat; shifted Druid mana; Shaman totem timers and existing multicast controls when available. Retains existing custom resource/ability trackers, stance/pet handling and Hunter refinements. Off restores only the enable switches it changed, preserving newly adjusted positions and unrelated totem-class selections.
- **Warlock:** optional actual carried-inventory count for item 6265, named from client metadata. Bank, reagent bank, account bank and item uses are excluded. Shows readable zero, hides on missing/erroring/restricted data and requests metadata once per enable session. Follows the native power-bar parent for visibility/fades. No new OnUpdate. Item identity and placement require a Warlock E3 check; no retail shard pips or assumed server-specific mechanics are introduced.
- **Combo motion finding:** installed native `CreatePip:SetActive` shows/hides instantly. `ApplySmoothing` explicitly excludes pips. Existing motion is preserved. A brief gain-highlight fade is documented as a suggested follow-up, not implemented or visually verified.
- **Files:** live `ThemePresets.lua`, `ClassMechanics.lua`, minimal TOC/options append; generator and generated package; isolated `ValidateThemes.lua`/`RunThemeChecks.js`; `AFTERGLOW.md`, README, DEVELOPMENT and HANDOVER. No third-party or WTF edits.
- **Rollback:** `Snapshot-20261001-231705-pre-afterglow.zip` (before side-conversation changes).
- **Evidence:** E1 native API/animation/class audit; E2 399 isolated theme/class-HUD checks PASS, including mixed raid/party/party-target restoration, restricted frame units, native page refresh and combat-deferred counter reparenting. Existing gameplay harness PASS (1452 checks at the final regression check), Lua 5.1 parse PASS (38 current files, including the parent's new action-feedback module), installer PASS and package check reports 0 files need changes at check time. No E3 evidence. New files require a full client restart. See AFTERGLOW.md for the nine-class coverage table, colour-sharing caveats and in-game checklist.

### Gameplay enhancement pass (2026-10-01)
- **Why:** continue the agreed UI enhancements while the artwork experiment is paused.
- **Resource text:** each health/resource Left, Center and Right slot has an inline direction cog with independent X/Y offsets (-500 to 500). Offsets persist when a slot is hidden; disabling slots restores the native label. Existing defaults retain the original placement.
- **World cues:** new `CueFades.lua`, loaded before `Companion.lua`. Nameplates -> HUNTER RANGE AND CORPSES -> Smooth Cue Fades (default off). Reused engine Alpha animations ease corpse readiness between 90% and 28% over 0.23 seconds. Interrupted animations resume at the interpolated alpha; recycled units snap to their own state. Guide markers, rarity badges and raid textures use the shared Ellesmere range engine. Marker out-of-range opacity is adjustable, including zero. Unknown/restricted range leaves markers visible. Disable stops animations, releases the range consumer and restores original region opacity. No additional Lua OnUpdate loop.
- **Guide markers:** FHK's existing guide overlay now parents to the styled plate (or the original plate when no styled plate exists), so it inherits native plate opacity. Registers its texture through the companion bridge for the optional range fade; guide target reads and duplicate-raid-marker suppression are unchanged.
- **Hunter warnings:** QoL -> HUNTER WARNINGS adds opt-in Cheetah/Pack combat warnings, Mend Pet reminders (40% threshold, adjustable), and Pet Too Far Away. Uses localized Mend Pet names for rank-independent aura/range checks. Clears on recovery, death, dismissal or disable; suppresses Mend while already healing, out of range or unlearned. Missing/restricted health and aura reads do not generate a Mend reminder. Aspect and health checks use events; pet range uses the native 0.25-second animation ticker only while a pet reminder is enabled, a living pet exists and Mend Pet is learned. The ticker rechecks health only on a range-state change. All-off unregisters every warning event and stops the timer. Existing ammo/talent readers now guard restricted numeric values.
- **Idle wings:** Action Bars -> HUNTER KEYBOARD LAYOUT -> Fade Wing Bars While Idle (default off). Applies native Match Any visibility for combat or mouseover to Bar4-Bar8; centre rows retain their settings. Uses native fades and binding handling. Changes defer in combat; disabling restores saved per-profile visibility, including multi-selection and opacity. Reapplying the Hunter layout retains the enabled wing preset.
- **Native dark-theme compatibility:** the unit-frame refinements preserve Ellesmere's dark health fills, including pet health, while its existing dark-theme setting is enabled. This prevents our health/happiness recolouring from overwriting the native option. Nameplate health and resource dimming retain their own behaviour; no new artwork/theme is installed.
- **Files:** live `ResourceRefinements.lua`, `RefinementOptions.lua`, `UnitRefinements.lua`, `Companion.lua`, `Warnings.lua`, `ActionBarLayout.lua`, NEW `CueFades.lua`, TOC; FHK `RestedXPMarkers.lua`; package generator, mocked tests, generated package and guides.
- **Rollback:** `Snapshot-20261001-224146-pre-text-and-cues.zip` in the game root.
- **Evidence:** E2. Lua 5.1 parse PASS (35 files), integration PASS (1377 checks), installer PASS, package check reports 0 changes, FHK Python tests 15/15 PASS, RestedXP adapter 10/10 touchpoints PASS. This pass adds 236 assertions over the XP takeover total, including repeated API-argument checks. No in-game verification.
- **Restart / E3:** fully restart for the new TOC file. Check every text slot's cog and persistence, loot/skin readiness transitions, guide/rare/raid marker fade and disable restoration, all three new warning toggles and pet range/recovery. Check that wing-bar keybinds work while faded and the bars return on combat/hover. All remain E2 until observed in game.
- **Open:** the player clarified that the interact cog is the floating icon above a world object. Its separate native fade access is unconfirmed; it has not been changed. The artwork/dark-mode design exploration is paused at the player's request. Remaining gameplay backlog is in DEVELOPMENT and HANDOVER.

### XP bar upgrade (2026-10-01, takeover)
- **Why:** show the XP waiting in completed quests, make XP gains readable, and show progress this session.
- **Files:** NEW live `XPBarRefinements.lua` (TOC, before `RefinementOptions.lua`); `RefinementOptions.lua`; `RefreshPackage.js`; `Validate.lua`; generated package; README, DEVELOPMENT and HANDOVER updated.
- **Completed quests:** unique non-header quest-log entries that are ready for turn-in or complete. Adds only positive, public rewards; clips projected fill at the level maximum. The accent overlay draws at 35% alpha between the native rested and earned-XP layers. Missing, zero, erroring or restricted reward reads hide the overlay when no XP is known; partial data is labelled "Known XP" in the tooltip.
- **API correction to the design:** Blizzard's native quest UI calls `GetQuestLogRewardXP()` without arguments for the selected quest. The scanner prefers Forever's native `GetQuestLogSelection` / `SelectQuestLogEntry` log-index API; otherwise it uses documented `C_QuestLog.GetSelectedQuest` / `SetSelectedQuest` with quest IDs. It verifies each selection and restores it after reading. It does not assume that the legacy reward function accepts a quest ID. Quest events are coalesced for 0.3 seconds; selection-triggered synchronous events are ignored during scans.
- **Motion:** uses native `StatusBarInterpolation.ExponentialEaseOut` for rising XP; snaps on level/range changes. A reused engine Alpha animation highlights the gain segment for 0.8 seconds with OUT smoothing. No Lua `OnUpdate`.
- **Ticks:** nine subtle 1-physical-pixel ticks at 10% intervals, horizontal or vertical. Ellesmere's native Forever 5% dividers are hidden while custom ticks are enabled and restored through native layout on disable. Tracks resize, scale and display changes.
- **Tooltip:** known completed-quest XP, earned session XP and XP/hr, and time to level. Counts an observed level boundary, avoids inventing XP for unobserved multi-level jumps, respects native click-through and tooltip ownership. Session data resets on reload or re-enabling its toggle.
- **Settings:** `FHKEllesmereDB.xpBar.{quests,smooth,glow,ticks,tooltip}`; all default on for this private companion, individually configurable in Action Bars -> XP BAR REFINEMENTS. With all off, events are unregistered, pending work is invalidated, added visuals hide and native setter arguments pass through unchanged.
- **Diagnostic:** `/fhkxp` reports reward and selection API availability, completed quests, readable positive rewards and pending XP. No Questie estimates or fallback data are included.
- **Rollback:** `Snapshot-20261001-222251-pre-xp-refinements.zip` (game root).
- **Evidence:** E2. Lua 5.1 validation PASS (34 files), integration PASS (1141 checks, 84 added assertions including repeated legacy-call argument checks), installer PASS, `Apply.ps1 -Mode Check` reports 0 changes. No in-game verification; player confirmed the previous work is also untested.
- **Restart needed:** yes, new TOC file. After restart run `/fhkxp` with completed quests, compare known XP to rewards, turn one in, gain XP across a level, check mouseover stats and toggle each feature off. Check that the quest-log selection remains unchanged and no Lua errors appear.
- **Open limitation:** Forever's vanilla quest UI disables the reward lookup. The lookup and quest-log coverage (including collapsed headers) must be checked in game before calling this E3. If it returns no rewards, the overlay remains hidden; a licensed data fallback is separate follow-up work.

### Completion pass (2026-10-01)
- **Why:** finish the interrupted update and make the package match live again.
- **Damage trail wired:**
  - `DamageTrail.lua` added to the TOC (after `RangeIntegration.lua`);
  - attached to every Ellesmere unit-frame `Health` bar and nameplate `health` bar from `UnitRefinements.lua`;
  - settings rows added to Unit Frames → COLOUR AND TEXT REFINEMENTS and Nameplates → HUNTER RANGE AND CORPSES;
  - default colour now follows the live UI accent (`EllesmereUI.GetAccentColor`) instead of a hard-coded bronze, and a picked colour still overrides it.
- **ASCII-only sources:** all FHKEllesmere `.lua`/`.toc` files.
  - Option labels now use plain ASCII (`->`, `;`, `,`, `'`, `-`).
  - Range text keeps identical runtime output (`5–8 yd`, `·`) through byte-escaped `DASH`/`DOT` constants, so the format still matches FHK and existing tests.
- **Tests:**
  - `Validate.lua` Display-page expectations updated for the sixth rarity row (420 → 452, CAST BAR -372 → -404);
  - added assertions for Rarity Level Format / Badge Position;
  - added a 10-check damage-trail block (loss, width, easing, accent, fade, idle stop, heal, disabled, restricted values).
- **Package:**
  - `RefreshPackage.js` and `package.json` → 1.8.0;
  - owned files now include `WeaveTiming.lua`, `RangeIntegration.lua` and `DamageTrail.lua`;
  - package refreshed; FHK context hunks unchanged (13).
- **Files:** `FHKEllesmere.toc`, `DamageTrail.lua`, `UnitRefinements.lua`, `RefinementOptions.lua`, `Companion.lua`, `RangeBackend.lua`, `RangeIntegration.lua`, `SwingCursor.lua`, `SwingIntegration.lua`; package: `Validate.lua`, `RefreshPackage.js`, `package.json`, `patches.json`, `files/`
- **Evidence:** E2.
  - `Validate.js` PASS (31 files);
  - `RunIntegration.js` PASS (1079 checks);
  - `ValidateInstaller.js` PASS;
  - `Apply.ps1 -Mode Check`: "0 files need changes".
  - **E3 pending.**
- **Restart needed:** yes (TOC gained `DamageTrail.lua`).
- **Not done (needs in-game testing or is upstream-only prep):** load-time events → `Apply()` arm/disarm, own `OnUpdate` → `EllesmereUI.Tick` drivers, private keys on frames → weak tables, default-OFF settings, `.dev` upstream module sync. See ELLESMERE_STYLE_GUIDE.md section 11.

### Range indicators: native settings and movers
- **Why:** Range bar, plate accent and auto-attack icons should be configurable and movable like other Ellesmere elements.
- **Files:** `RangeIntegration.lua` (NEW, TOC), `Companion.lua`, `RefinementOptions.lua`, `SwingCursor.lua`
- **Settings:** `indicators.range`, `indicators.plate`, `indicators.attacks` (defaults in `RangeIntegration.lua`)
- **Ellesmere surface touched:** `MakeUnlockElement`, `RegisterUnlockElements`, `NotifyElementResized`, `_unlockActive`, `Range_*`
- **Evidence:** E2 PASS after the completion pass. (The earlier failure at `Validate.lua:1254` was a stale expectation, not a bug.) E3 not done.
- **Restart needed:** yes (new TOC entry)

### Smooth damage trail
- **Why:** A short fading segment shows how much health was just lost, while native values stay immediate.
- **Files:** `DamageTrail.lua` (NEW, TOC), wired in by the completion pass above
- **Settings:** `damageTrails.unitframes` / `damageTrails.nameplates`: enabled, duration .28, opacity .4, colour nil = live accent
- **Evidence:** E2 (10 mocked checks). E3 pending.
- **Restart needed:** yes

### Nameplate rarity: format and position
- **Files:** `Rarity.lua`, `RefinementOptions.lua`
- **Settings:** `rarityIconPosition` (`bottomleft` / `topright`), `rarityMarkerStyle` (`symbols` / `letters`)
- **Evidence:** E1. E2 covered by the same failing Display-page assertion. E3 not done.

### Weave timing available without FHK
- **Files:** `WeaveTiming.lua` (NEW, TOC). Copied from FHK and guarded by `if NS.WeaveTiming then return end`.
- **Evidence:** E1.

### Swing clock / cursor adjustments
- **Files:** `HunterRuntime.lua`, `SwingCursor.lua`
- **Evidence:** E1. What changed has not been reviewed yet; diff against `files/FHKEllesmere/` (1.7.0).

### Packaging
- Done in the completion pass. Still 1.7.0: `DEVELOPER_HANDOFF.md` and the `.dev` upstream module (to be rebased on current `main` before any sync).

### Colour rules: resources dim, pet bar shows happiness (`UnitRefinements.lua`)
- **Why:** resource bars used the health warning gradient (base -> amber -> orange -> coral), so draining mana looked like dying. The player asked for happiness as the pet's health-bar colour.
- **Resources:** keep their own hue and only dim, to 45% brightness at empty (`Shade`, `RESOURCE_FLOOR`). Covers both the public path and the native colour-curve path, so restricted values stay safe. Warm colours now mean health only.
- **Pet:** with a happiness value (`C_PetInfo.GetPetHappiness`: 1 unhappy red, 2 content yellow, 3 happy green), the pet health bar takes that colour instead of the health gradient.
  - Toggle: Unit Frames -> COLOUR AND TEXT REFINEMENTS -> Pet Happiness Bar Colour (`petHappinessColors`).
  - Ellesmere's own happiness icon stays.
- **Evidence:** E2. `Validate.lua` resource assertions rewritten to the new rule; 4 pet happiness checks; integration 1057 PASS. E3 pending.

### Hunter warnings (NEW `Warnings.lua`, TOC)
- **Why:** the player asked for a low-ammo warning like Ellesmere's Low Durability, plus an unspent-talents warning.
- **Look:** copies Ellesmere's durability-warning shape (`EllesmereUIQoL.lua`): "extras" font at the durability size, the 0.4 s 1 -> 0.3 alpha pulse, click-through, HIGH strata, stacked just below the durability warning (respects its saved position/offset). A 0.25 s OUT fade-in on appearance.
- **Low ammo:** only with a bow/gun/crossbow in the ranged slot.
  - Amber "Low Ammo (N)" below 200, out of combat.
  - Red "Ammo Critical (N)" / "Out of Ammo" at or below 50, also in combat.
  - Ammo from `INVSLOT_AMMO` (Forever's Camelot paperdoll has the ammo slot).
- **Unspent talents:** "Unspent Talent Points (N)" in the live accent colour, slower pulse, out of combat. Points come from whichever API exists: `C_ClassTalents.HasUnspentTalentPoints` (documented in Forever's API docs), `UnitCharacterPoints`, `GetUnspentTalentPoints`.
- **Events:** only registered while a warning is on, and only events the client knows (`C_EventUtils.IsEventValid`). One coalesced check per frame.
- **Options:** Quality of Life → HUNTER WARNINGS (toggles, thresholds, Preview). Settings in `FHKEllesmereDB.warnings`.
- **Evidence:** E2. 12 mocked checks (states, wand/thrown exclusion, combat behaviour, restock clears, talents on/off). E3 pending.

### Hunter polish (NEW `HunterPolish.lua`, TOC)
- **Why:** the action-bar profile was untouched Ellesmere defaults.
- **What:** sets Ellesmere's own options once (version 1), re-applicable from Action Bars → HUNTER KEYBOARD LAYOUT → Apply Hunter Polish:
  - press = accent Border (5), hover = Light (1), cast highlight on;
  - desaturate on cooldown; CD swipe 60%;
  - Out of Range Coloring on all 8 bars;
  - `countdownForCooldowns` CVar on.
  - Each refresh uses Ellesmere's own setter path (`ApplyPushedTextures`, `_DesatSettingChanged`, `ApplyRangeColoring`, ...). Every choice can be changed back in Ellesmere's options.
- **Evidence:** E2 (7 mocked checks). E3 pending.

### Action bar layout v2 and Naga 12 (with FHK 2.9.96)
- **`ActionBarLayout.lua`: `LAYOUT_VERSION` 2** (applies once more, then Unlock Mode edits are kept):
  - the centre stack is three combat rows only;
  - right wing: recovery/items (bar 6) low, rare buffs (bar 5) high;
  - the RestedXP quest bar (bar 8) moves out of the centre to the right, above the right wing, as 4x2 beside the quest tracker.
- **`QuestBar.lua`:** Ctrl+Naga 12 (Alt+Ctrl+I) clicks RestedXP's own first active-item button (fallback: bar 8 button 3) and sets `QuestBarOwnsCtrlNaga` so FHK leaves that key alone.
- **`Validate.lua`:** grouping assertions follow the new principle (combat aspects in the centre, rare buffs on the wing, Feed with beast tools, Pet Move To on the pet bar).
- **Evidence:** E2. Integration 1028 PASS. E3 pending: after restart, check the bar positions, Ctrl+Naga 12 using a guide item, and Shift+Naga 12 targeting.

### Packaging tools (with FHK 2.9.96)
- `RefreshPackage.js`: generic refresh of any FHK context hunk from live files (anchored by unchanged edges; stops if an edge moved). Upgrade variants that can no longer be anchored are dropped with a note (dropped: `Profile.lua` "Previously applied 1.5 refinements").
- `ValidateInstaller.js`: the newer-version check no longer hard-codes an FHK version.
- `Validate.lua`: asserts the FHK 2.9.96 key anchors (F weave, C Wing Clip, 3/4/5 control, G traps, Ctrl+wheel down Pet Move To).
- **Evidence:** E2. Validate PASS, integration 1049 PASS, installer PASS, Apply Check 0 changes.

### Documentation
- Added `DEVELOPMENT.md` (developer/agent guide), this `CHANGELOG.md`, and the root `CLAUDE.md`.
- Added `ELLESMERE_STYLE_GUIDE.md`: upstream acceptance rules, suite module map, module anatomy, options idiom, colour/typography/pixel tokens, icon and animation conventions, taint rules, localisation, merge plan and a compliance audit of FHKEllesmere. Studied installed 9.3.4 and upstream `main` 9.3.5 (`a134e53`).
- Finding: our "Ellesmere bronze" `#DDA880` is a hard-coded near-match. Ellesmere's Forever accent is `#DCA77F` and user-changeable.
- Finding: 34 non-ASCII characters, default-on settings, load-time event registration and private keys on frames would block an upstream PR (style guide section 11).

---

## Released history

Reconstructed on 2026-10-01 from the release zips in the game root. Everything below was released on 2026-10-01. Earlier entries have no recorded evidence level.

### 1.7.0 (`FHK-Ellesmere-Patch-1.7.0.zip`, `EllesmereUIForeverRefinements-1.7.0.zip`)
- Mob Rarity section on Nameplates → Display: gold/silver levels, `+`/`++`, native elite/rare badges, skull rank.
- Health/resource dynamic fill colours; resource text tint; unit-frame resource formats.
- Resource Bars independent L/C/R text slots.
- Swing Timer Hunter Layout (combined/separate), Melee Ready, Auto Shot Cast/Retry. Cursor rings with 4 modes.
- One-time hunter action bar preset; RXP on native Action Bar 8.
- Flat bag/keyring chrome with new key glyph.
- Upstream review module prepared against EllesmereUI `47920e5` (staged, not submitted).
- New TOC files, so a full restart was needed.
- Evidence recorded at the time: E2 (mocked suite + installer); E3 outstanding per README.

### 1.6.0
- FHK became optional: the UI has its own weapon clocks and range backend (`HunterRuntime`, `RangeBackend`).
- FHK target bumped to 2.9.94.

### 1.2.0 – 1.5.0
- Selected plates keep Ellesmere's original target glow, tinted only by range; fallback box removed.
- Iterative range, plate and swing refinements (per-version detail not reconstructed; see the zips).

### 1.1.0 (`FHK-Ellesmere-Companion-1.1.0.zip`)
- Target nameplate range text below the health/cast bar; range-coloured soft glow (mint / soft yellow / coral).

### 1.0.0 (`FHK-Ellesmere-Companion-1.0.0.zip`)
- First FHK + Ellesmere companion, for FHK 2.9.91 (patched to 2.9.92).
