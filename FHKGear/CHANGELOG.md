# Changelog: FHK Gear

Evidence levels: E1 = static checks, E2 = mocked tests, E3 = seen working in game. Only E3 means "works".

## 0.5.1 (2026-10-04, Claude): weapon skill on pop-ups
- **Why:** master to-do §10.2 (weapon skill readout). The player: "weapon skill can be levelled on an upgrade".
- **Result:**
  - **Equipped pop-up:** a weapon below your skill cap adds "Bows skill 60/100: trains as you use it" to the card.
  - **New Weapon Skill Maxed pop-up:** shows when a worn weapon's skill reaches your cap after real training (25 or more points behind).
    - The few points each level-up adds never trigger it.
    - The first check after login only records where each skill stands.
    - It follows Action Pop-Ups.
    - Skills are read live (`C_SkillInfo.GetSkillLineInfoByID`) on `SKILL_LINES_CHANGED`, never from the model cache.
  - The bag and worn weapon tooltips keep their existing skill line.
- **No new files or settings** (`/reload` is enough).
- **E2:** 467 checks (+5): the card names the skill; the first check is silent; Skill Maxed shows once; a level-up catch-up is silent. **No E3.**
- **Handover reconciliation (Codex, E1/E2):** root HANDOVER now starts with Claude's 0.5.1 state; fresh checks reproduce 467 Gear / 17 TOC files and companion 2847 / 45 files. Gear package still says 0.5.0 (4 differing files); companion package Check reports 6 differing files. Refresh from live source before applying either payload. No addon code or SavedVariables changed by this reconciliation; no new E3.

## 0.5.0 (2026-10-04, Claude): live Hunter model, bag slots by client ID, reagent bag, bag edge cases
- **Why:** the player asked why the deeper Hunter scoring should wait. Everything it needs is on the character sheet or researchable, and the Hunter section is the priority. They also asked how bags, the reagent bag and repeated bag equips are handled.
- **Hunter model** (`HunterModel.lua` + `Data/Hunter.lua`). It is the new default score source for Hunters ("Automatic", or pick "Hunter Model (Live Stats)").
  - **Live inputs**, from the same client calls Forever's own character sheet makes (`Camelot/PaperDollFrameStats.lua`): ranged and melee AP, ranged and melee crit, hit (rating plus modifier), ranged haste including quiver/ammo haste, and per-weapon-type skill (`C_SkillInfo.GetSkillLineInfoByID`). It also reads pet happiness damage (`C_PetInfo`), and the exact Agility / Strength / Intellect conversions at your level (`GetRangedAttackPowerForStat`, `GetAttackPowerForStat`, `GetCritChanceFromStat`).
  - **Researched rules:**
    - the Forever pet gets 22 % of your ranged AP and 30 % of your Stamina (`HUNTER_PET_BONUS`);
    - miss is 5 % plus 0.04 % per weapon-skill point short, and 7 % + 0.4 %/point beyond 10 (Forever's 5.0 / 5.2 / 5.4 / 9.0 table); mobs dodge 5 %;
    - Arcane Shot scales at 0.204 × ranged AP; Aimed Shot (2 s cast) and Multi-Shot (0.5 s) share a 6 s cooldown;
    - talent effects from the ForeverDB calculator: Ranged Weapon Specialization, Mortal Shots, Barrage, Improved Arcane Shot, Improved Stings, Focused Fire, Lone Wolf, Unleashed Fury, Ferocity, Lightning Reflexes, Careful Aim, Predator's Edge.
    - Per-rank ability bonuses are parsed from the live spell descriptions.
  - **What it changes:**
    - Stat weights follow your character, in Agility units (Agility keeps its default weight as the yardstick, so Stamina and other survival weights sit beside it). Stamina gains the pet's 30 % share when a pet is out.
    - Weapons get their own value. The slower of two equal-DPS bows is worth more (Aimed Shot), and a weapon type you're unskilled with loses value to misses.
    - A gun with only arrows in your bags (or the reverse) stays manual: "No matching ammo in your bags".
    - The tooltip adds the DPS gain: "+3.1 upgrade (+0.6 DPS)".
  - **Stability:**
    - Gear hit is valued from your hit without gear, so wearing a hit item never makes it look worse (no swap loops).
    - Weights are rebuilt only after equipment, pet, level, talent or setting changes (coalesced 0.5 s), and replace the old ones only when they move by more than 2 %.
    - Worn items are read from the item cache, not through scoring, so the model can't recurse.
  - **Talent ranks:** your own value first (Model page sliders), then the talent window (every `{specializationIndex, tier, column}` query; it stops at the first refusal), then "talent spell known" (rank 1). The method shows in each slider's tooltip and in the report.
  - **UI:**
    - a HUNTER MODEL section on the Model page: live model DPS and the DPS of 1 Agility, Pet (Detect / Always Out / No Pet), Multi-Shot Targets, a rank slider per talent, Use Detected, and a Model Report button;
    - a note on Stat Weights while the model is in use (typing a weight switches that spec and phase to your own numbers and turns the model's weapon value off);
    - `/fhkgear hunter` opens the copyable report: inputs, parsed abilities, talent ranks and how they were read, weights, assumptions, the reagent-bag slot count, and the client's Hunter tooltip strings.
  - **Assumed, and listed in the report:** unlimited mana, mob armour ignored, level-equal mobs. Base pet damage that gear can't change is left out.
- **Bag slots by client inventory ID:**
  - Forever's constants use the retail offset (`CONTAINER_BAG_OFFSET = 30`), so equipped bags are probably not the Classic 20-23. Gear keeps its own slot numbers (20-23 bags, 24 reagent bag) and asks `C_Container.ContainerIDToInventoryID` at every inventory call (read, equip, bind prompt, acknowledgement).
  - Before this, bag automation and bag locks would have pointed at the wrong slots on Forever.
- **Reagent bag** (the player's screenshot shows the slot): reagent bags (container subclass 11) fit only the reagent slot, and general bags never go there. Locks show "Reagent Bag". The keyring needs nothing from Gear.
- **Bag edge cases:**
  - ten identical bags fill the four empty slots once each, and the other six stay in your bags (test);
  - quiver/ammo-pouch haste counts once, not once per quiver;
  - profession bags (herb, enchanting, soul...) are never candidates, so a 12-slot herb bag can't replace a 10-slot general bag;
  - occupied bags stay manual, as before.
- **Quivers stay put (player question):**
  - A worn quiver or ammo pouch (item class 11) keeps its bag slot. General bags fill only the other bag slots, and a new quiver replaces only the quiver (or fills a slot when you wear none).
  - Ammo containers are never candidates for other classes.
- **Weapon skill flagged (player question):**
  - When a weapon type you're still training costs an item value, the tooltip adds a gold line: "Crossbows skill 60/100: +2.3 more once trained", plus "(upgrade then)" when it beats your worn weapon once trained.
  - Such an item is not auto-equipped until it's an upgrade now. Skill trains with use.
  - A weapon skill-up refreshes the model.
- **Auto-Equip Better Ammo (player question; new toggle, needs Auto-Equip Upgrades):**
  - After gear upgrades, Gear puts the best usable arrows or bullets for your worn ranged weapon in the ammo slot. That covers an empty slot, the wrong type, or better ammo in your bags.
  - A higher tier bought early equips right after the level-up that makes it usable: the level-up re-reads item requirements and queues an equip pass (after combat if you're fighting).
  - Ammo tooltips say "better ammo (+x damage per second)", "usable at level N", "does not fit your ranged weapon" or "your equipped ammo".
  - If the client leaves the stack on the cursor after equipping the ammo slot, Gear puts it back. **E3:** the first ammo equip.
- **v1.0 audit fixes (stress tests):**
  - **Slider drags:** these used to run a full change (rescoring, profile write, event set, model and bag scan) on every tick. Now the preview follows at once and one change runs 0.15 s after the last tick.
  - **Ammo:** cached between model refreshes and re-read only after bag or equipment events. Buying bullets refreshes the model, so a gun becomes automatic without anything else changing.
  - **Model refresh:** also triggers when a model input outside the weights changes (ammo types held, ranged weapon skills, level), not only when weights move by 2 %.
  - **Pet "Detect":** now counts the pet for every Hunter without Lone Wolf, even while it's dead, dismissed or despawned on a flight path. Before, those moments shifted the weights and could have triggered gear swaps. Only Lone Wolf Hunters follow whether a pet is out.
  - **Unreadable weapon skill:** this no longer blocks automation for every weapon. Skill is assumed capped, and the report lists it as an estimate.
  - **Worn weapon facts and skill lines** are read once per model refresh, not on every weapon score.
  - **Queued timers:** the model and settings queues expire after 2 s and 1 s, so a timer the client drops can never block refreshes.
  - **Profile import:** accepts the reagent bag lock (slot 24).
- **Pop-ups (player request: Gear replaces AutoGear, including its window).** New `Notify.lua`: Ellesmere-style cards, never modal (no dimmer, no blocked clicks).
  - **Look:** Ellesmere's own palette (popup background 0.06 / 0.08 / 0.10, 1 px edge at 15 % white, `MakeFont`, `MakeBorder`, the accent colour for the stripe and title, gold for vendor and greed), the `eui-close` icon, and buttons whose border turns accent on hover.
  - **Content:** the item icon with a quality-coloured border, the name in its quality colour, a detail line (the gain in score and DPS, and the item it replaces), and a stat-change line ("+6 Agility, -2 Stamina", green up and red down). Hovering shows the full item tooltip, including Gear's line.
  - **Motion:** slides in from the right while fading in (0.25 s, eased out). It fades away after Pop-Up Duration (default 8 s); hovering keeps it, and right-click or the close icon dismisses it. Up to three stack. Everything uses AnimationGroups (no OnUpdate), and no frame exists until the first card.
  - **Cards:**
    - Equipped (gear and ammo);
    - Quest Reward (upgrade, or best vendor value);
    - Rolled Need or Greed;
    - **Upgrade Found**, with **Equip** and **Never Equip** buttons, for upgrades Gear leaves to you (marks-only mode, above the rarity cap, uncertain, untrained skill). Each item shows once per session. The first pass after login only remembers what's already in your bags. Nothing shows for items auto-equip is about to equip. Equip works only out of combat and only for the exact item, still in the same bag slot.
  - **Settings** (Automation page, POP-UPS): Action Pop-Ups, Upgrade Found Pop-Ups, Pop-Up Duration, and Pop-Up Preview. The cards move in Ellesmere's Unlock Mode as "Gear Pop-Ups".
  - Upgrade Found follows Levelling Mode (none from 60, no bag listening) and stays off while AutoGear is enabled.
- **In game:** on the player's Hunter, AutoGear is still enabled (`WTF/.../Tripel-Star/AddOns.txt`). Its own pop-up is what shows, and Gear only marks while it's on. Use Disable AutoGear on the Automation page to test Gear's automation.
- **E1/E2:** `node Interface/AddOns/FHKGear/tests/run.js`: **462 checks PASS** (+81 in 0.5.0; the pop-up tests included). Covered: the Hunter model; bag slots by client ID and the reagent bag; bag fill; quiver stacking and protection; profession bags; the skill flag; ammo (including the level-10 tier on level-up). Stress tests cover:
  - no swap loop after settling;
  - bullets bought;
  - a skill-up;
  - missing conversions;
  - one change per slider burst;
  - a 72-item bag pass reads each skill line once and each item at most once;
  - 200 warm hovers read nothing.
  
  16 TOC files Lua 5.1 / ASCII / no OnUpdate. **No E3**: run `/fhkgear hunter` in game.

## 0.4.0 (2026-10-04, Claude): v1.0 UI pass, the BoE pair, Legendary, Ellesmere bag marks
- **Why:** the player asked whether Gear has all the Ellesmere UI and customisation it needs for v1.0, whether the rarity colours are Blizzard's, and for bind-on-equip to be two options: equip BoEs, and auto-confirm the bind.
- **Bug fixed (would have hit in game):** dependent rows passed `disabled` as a boolean, but Ellesmere calls `cfg.disabled()` as a function. With Auto-Roll off (the default), the loot-roll rows would throw and the rest of the Automation page would not render. Every gate is now a function, and a regression test checks every row on every page.
- **Bind on equip, now a pair** (new BIND ON EQUIP section):
  - **Auto-Equip Bind-on-Equip** (was "Equip Bind-on-Equip Greens"): follows your Auto-Equip Up To rarity instead of a fixed green cap.
  - **Auto-Confirm Bind Prompt** (was "Confirm Gear Equip Binds"): accepts the prompt only for the item Gear is equipping. Greyed out until both Auto-Equip Upgrades and Auto-Equip Bind-on-Equip are on.
  - Defaults unchanged: BoE equip on, bind confirmation off.
- **Rarity:** the selector already used Blizzard's `ITEM_QUALITY_COLORS` (fallbacks are the same hex values). Added **Legendary** (ff8000) as a cap.
- **Ellesmere conventions:**
  - **Status line** at the top of Automation, in colour: "Active: equips upgrades, ..." (green), or "Marks only" with the reason (gold): every action off, level 60 with Levelling Mode, or AutoGear enabled.
  - **Sliders** replace the number boxes: icon size, marker opacity, fight length, melee participation, Use availability, incoming hits.
  - **Inline colour swatches** on the Upgrade and Greed Marker Style rows (replacing two colour rows).
  - **Inline cog** on Upgrade Marker Style for icon position and X/Y offsets (replacing three rows).
  - **Live preview header** on Markers: an upgrade sample and a greed sample, painted by the real marker code, which update as you change style, colour, size or opacity.
  - **Greyed-out dependents** with `disabledTooltip`: rarity cap, empty-bag upgrades and the BoE pair need Auto-Equip; roll rows need Auto-Roll; every appearance row needs at least one marker; Endgame From Level needs Phase "By Level"; Rating Conversions needs Rating Units "Rating"; ability casts need Ability Adjusted.
  - Section spacers, a row divider, and one-sentence tooltips on every control. The Roll and Bind section is split into BIND ON EQUIP and LOOT ROLLS. Search labels are updated per page.
  - Slider drags and swatch picks apply in place, with no page rebuild. Toggles that change the status line or the set of rows rebuild the page.
- **Ellesmere bags:** Bag Upgrade Icons used to mark Ellesmere bag slots only after you hovered them. Gear now hooks `EUI_Bags:RefreshInventory` (with `hooksecurefunc`, installed only once bag icons are on) and finds the item buttons on each refresh. That gives one coalesced marker pass per refresh.
- **E1/E2:** `node Interface/AddOns/FHKGear/tests/run.js`: **381 checks PASS** (+19: the row contract, the BoE pair, Legendary, sliders, the preview header, Ellesmere bag discovery, hook and hide). 14 TOC files Lua 5.1 / ASCII / no OnUpdate. Snapshot `FHK-Ellesmere-Patch/Snapshot-20261004-pre-gear-v1-ui.zip`. **No E3.**

## 0.3.1 (2026-10-04, Claude): automation no longer stalls on uncertain items; idle cost restored
- **Why:** reconciliation audit [AUDIT_STATUS_2026-10-04.md](AUDIT_STATUS_2026-10-04.md) reproduced four defects in 0.3.0 with the existing mocks. The player asked for the remaining gaps to be fixed.
- **N01, auto-equip:** uncertainty is now local to the decision. An automatic swap is blocked only when the candidate, the item(s) it replaces (both hands for a two-hander, or a temporary weapon enchant there), or a second Use: effect is uncertain (`Engine.TouchedKnown`). Before, one worn "Chance on hit" weapon or one unscored line stopped every upgrade.
  - A default or reference procs-per-minute value counts as an estimate that may drive automation. New Model-page toggle **Automate With Proc Estimates** (default on); off restores "mark only" for such items.
- **N02, quest rewards and loot rolls:** the owned-gear baseline leaves out pending or uncertain bag items instead of aborting. Only the chosen reward's own comparison must be certain; otherwise it stays manual with the reason "Best reward replaces an item Gear cannot price".
- **N03, performance:** `SPELLS_CHANGED` and `PLAYER_TALENT_UPDATE` are coalesced (0.5 s). They drop only requirement-blocked cache entries plus context, instead of wiping the whole item cache and re-reading every tooltip. `WEAPON_ENCHANT_CHANGED` refreshes only the worn-gear comparison.
- **N04, statless items:** once the tooltip is complete, a nil `GetItemStats` result means "no structured stats" (e.g. a Use-only trinket), not "still loading". Before, wearing such an item made every comparison "unavailable".
- **N05:** added the missing 0.3.0 entry below.
- **N06:** the hidden search pre-build indexes each page's own labels only, so Ellesmere search opens the right page.
- **G54, packaging:** generated `FHK-Gear-Package` (`node FHK-Gear-Package/Refresh.js`: 20 payload files and a SHA-256 manifest).
  - Live game: `Apply.ps1 -Mode Check` reports 0 changes.
  - Clean temporary game root: Check, then Apply -AllowWrite (20 files, hash-verified, rollback snapshot), then Check again: 0 changes.
  - No install to the live game was needed or made. Re-run Refresh.js after any Gear change.
- **E1/E2:** `node Interface/AddOns/FHKGear/tests/run.js`: **362 checks PASS** (+15: the N01-N04 and N06 regressions, the estimate toggle); 14 TOC files Lua 5.1 / ASCII / no OnUpdate. Snapshot `Snapshot-20261004-pre-gear-n01-n06.zip`. **No E3** (0.3.x hasn't been loaded in game yet). N04 still needs one in-game check: `/fhkgear item` on a Use-only trinket.

## 0.3.0 (2026-10-04, Codex): audit repairs (entry written by Claude from the repair ledger)
- **Why:** Codex's 62-finding audit ([AUDIT_2026-10-04.md](AUDIT_2026-10-04.md)), repaired with the player's approval. Item-by-item status and evidence: [REPAIRS_2026-10-04.md](REPAIRS_2026-10-04.md) (37 fixed, 21 mitigated, 3 open, 1 pending).
- **Result, by area:**
  - **New files:** `Safety.lua`, `Effects.lua`, `Context.lua`, `Equipment.lua`, `Actions.lua`, `Profiles.lua`, `Data/Procs.lua`.
  - **Safe actions:** owned equip transactions (exact cursor link, target and acknowledgement; bounded failures with fallbacks); bind and roll confirmations only for Gear's own action (both off by default); quest and roll work cancelled when the window closes.
  - **Comparison:** legal complete setups; owned bag gear as the quest/roll baseline (search capped at 10,000 nodes); unique-equipped categories; duplicate copies; main-hand + off-hand vs two-hander recommendations (multi-step swaps are never automatic); set bonuses at their thresholds.
  - **Facts and scoring:** finite-value and secret guards; complete-tooltip readiness; rating units need confirmation; stat sources reconciled; typed proc/Use effects with rate, ICD and participation settings; permanent stat enchants; weapon speed and damage; quiver haste and bag capacity.
  - **UI:** five pages (Automation, Stat Weights, Markers, Equipment Rules, Model); coloured auto-equip rarity cap; Need/Greed policies; marker styles, colours, size and position; bag, roll and character-slot markers (off by default); slot locks and Never Equip.
  - **Integration:** an Ellesmere profile bridge through the companion (`fhkGearSettings`; weights and rules are separate opt-ins); the companion routes its AutoGear options to Gear; optional MythicSim export and ForeverGear source, shown only when installed.
  - **Licence:** official CC BY-NC-SA 4.0 text, and the attribution links AutoGear's source.
- **E1/E2:** 347 mocked checks and 14 Lua files PASS; companion 2,814 PASS. **No E3.** Packaging (G54) pending: `FHK-Gear-Package` holds `Apply.ps1` / `Refresh.js` but no generated payload.

## 0.2.1 (2026-10-04, Codex): rarity limit, equipment rules, caches and scoring review
- **Player direction:** grey upgrades remain eligible, including improved starter weapons. Compare complete weapon setups using learned abilities and levelling rotations; a stat score alone is not proof of a DPS gain. Prefer MythicSim's character exporter, shown only with its addon, and hide unavailable ForeverGear scoring.
- **Automation menu:** coloured Auto-Equip Up To selector (grey, white, green, blue, purple), default green. Higher rarities keep existing tooltip/quest marks. Filtering happens before the best candidate per slot is chosen, so a flagged epic cannot hide an eligible green. Existing bind-on-equip restrictions also apply. Quest choice and loot rolls keep their separate settings.
- **Equipment Rules page:** all 17 scored slots can be locked. Never Equip accepts item links or positive integer IDs, with Allow buttons to remove exclusions. Controls stay per character in the existing `locked`/`ignore` tables. A two-hander cannot displace a locked occupied off hand.
- **Performance/correctness:** tooltip equipment snapshots are refreshed on equipment, skill, level, weight/settings and item-data changes. Automatic actions read fresh equipment. Missing equipped item data is not treated as an empty slot. Item cache uses a 256-entry LRU, including bag-position variants; score entries use weak item keys. No polling/OnUpdate. Equipment/training changes in Mark Only do not queue equip passes, and the equipment watcher drops when tooltips and auto-equip are off.
- **Scoring fixes:** structured block value maps to `BlockValue`, not percent block. Conditional attack-power lines remain visible as unscored instead of being counted as always active. The broader rating/percent, weapon-slot, spell-rank, talent and proc assumptions are documented in `SCORING_REVIEW_2026-10-04.md`; no rotation simulator was added or claimed.
- **Optional tools:** ForeverGear requires a loaded addon and ready public scoring API; an unavailable saved source displays the stat-weight fallback. Public provider callbacks invalidate scores/equipment, and availability changes cannot reuse stale scores. Its fallback weight rows are labelled as fallback while provider scoring is active. MythicSim delegates to its own `export` slash command, with a website copy shortcut, only when the addon/handler is available. Official MIT-licensed 0.3.0 archive inspected as a reference only; MythicSim is not installed in the live game folder. Pawn weight strings remain distinct from character exports.
- **House rules:** all seven Lua files now stop on `EUI_CLIENT_BLOCKED`; incomplete option rows use `BlankRowCfg`. Attribution/licence preserved. No third-party or SavedVariables edits; companion package unchanged (Gear is still not packaged).
- **E1/E2:** all seven TOC Lua files parse as Lua 5.1, ASCII-only, no OnUpdate; **193 mocked checks PASS**, including actual auto-equip of a better grey, rarity filtering, locked off-hand protection, cache reuse/eviction, optional exporter routing/provider changes and blocked-client early exits. **No new E3.** `/reload` loads this code after the earlier addon-creation restart; no TOC file-list additions. Snapshot: `Snapshot-20261004-pre-gear-controls-cache.zip`.
- **Next E3:** render the new Equipment Rules/rarity controls, exercise grey/green/blue limits, manual gear/training cache refresh and the installed-tool options; all prior proc/crit/hit/automatic-action/Gear-tab/Disable AutoGear checks still remain. Bag icons, roll/character markers, full weapon-pair/ability model and packaging/profile export remain unfinished.

## 0.2.0 (2026-10-04, Claude): every Equip line and proc is weighted (our own model)
- **Why:** player, on the Skycaller wand (Equip: +6 Arcane spell damage): "the equip power though is not being weighted"; "chance on proc etc... all these things need weighting"; "we should be improving on the logic/autogear rather than relying on how it's done".
- **AutoGear's way, for comparison:** it takes the first number on a proc or Use: line, divides it by 3 or 6, and adds it only if the line names a stat, so most procs score nothing or something arbitrary.
- **Result (FHK Gear's own model):**
  - **Spell damage lines:**
    - one-school lines ("damage done by Arcane spells by up to 6") become `ArcaneDamage`, `FireDamage` etc.;
    - "magical spells" without healing becomes `SpellDamage`.
    - Each class and spec values each school by how much of its damage is that school: an Arcane mage fully, a Fire mage a little, a Hunter at 0.1 x Agility for Arcane Shot.
  - **Other lines:** health per 5 sec, shield block chance and block value, and resistances (small levelling weight).
  - **Procs and Use: effects:** each line is stored as facts (damage, heal, mana, temporary stat with duration, cooldown) and priced with the current weights:
    - chance-on-hit procs fire `Procs` times a minute (default 1, editable); "when struck" half as often;
    - Use: effects are used on cooldown 80% of the time;
    - damage becomes extra DPS, priced like that weapon's DPS; damage over time counts every tick;
    - heals and mana become per-5-second regen;
    - a temporary stat counts for its uptime; on a melee weapon of a ranged class, uptime shrinks by the weaving share (MeleeDPS / RangedDPS);
    - attack-speed procs are valued at 0.9 x crit per 1%.
  - `/fhkgear item` prints each proc with what it read and what it adds ("Proc: +120 AttackPower for 20s (use, 120s cooldown) = +16.00 score"), plus any line not scored yet.
  - New rows on Stat Weights: the six spell schools, Spell Damage (no healing), Health per 5 Sec, Shield Block Value, Attack Speed (per 1%), Resistance, Procs per Minute. Pawn import/export knows the school names.
- **E2:** 109 checks (+21). E3 still to see: a real Forever proc item and a crit/hit item via `/fhkgear item`.
- **E3 (player screenshot, after /reload):** `/fhkgear item` on Skycaller read `ArcaneDamage=6 (Equip line)` and `DPS=21.5625`, said "not usable: Wand" for a Hunter, and scored it 43.76 (21.5625 x 2 ranged DPS = 43.13, plus 6 x 0.105 Arcane = 0.63). So on Forever, one-school spell damage sits on a separate Equip: line, not in the stat table, and Gear now weights it. Still to see: a proc item and a crit/hit item.

## 0.1.1 (2026-10-04, Claude): first in-game reading; clearer `/fhkgear item`
- **E3 (player screenshot):** `/fhkgear item` on Lupine Buckler of the Owl read Armor=361, Intellect=2, Spirit=2 from the structured stat table and scored it 0.44 (Spirit 2 x 0.2, Armor 361 x 0.0001, Intellect almost 0). The red "Shield" text marked it unusable for a Hunter. So the stat table, tooltip usability check and score arithmetic work in the Forever client.
- **Why the change:** player: "think it's separate in WoW Forever", i.e. crit and hit sit on separate "Equip:" lines, not in the stat table. Gear already reads those lines when the table lacks the stat; now that is visible.
- **Result:**
  - `/fhkgear item` marks stats read from an Equip: line ("Crit=1 (Equip line)").
  - It lists Equip: lines Gear doesn't score yet ("Equip line not scored yet: ..."), so new Forever wordings can be added.
  - It says "not usable: Shield" instead of "usable false (Shield)".
- **E2:** 88 checks (+8), including the buckler as seen in game. Crit/hit lines on a real Forever item: still to see (E3).

## 0.1.0 (2026-10-04, Claude): first version, replaces AutoGear
- **Why:** player: "auto gear is a standalone addon, we need to refactor it and improve on the idea and bring it into Ellesmere UI with our own module ... the options should be in the Ellesmere style ... everything needs to work standalone so AutoGear is no longer needed". Decisions (2026-10-04):
  - its own addon, appearing as a Gear tab in Ellesmere;
  - AutoGear's code reused under its licence, CC BY-NC-SA 4.0 with attribution;
  - marking by default, with each automatic action its own toggle;
  - "Levelling Mode": automation only at levels 1-59;
  - built for performance.
- **Result:**
  - **Engine** (`Engine.lua`): adapts AutoGear's rules, rewritten as cached pure functions:
    - slot rules and weapon styles;
    - rings, trinkets and dual-wield weapons replace the weaker of their two slots;
    - a two-hander is measured against main hand plus off hand;
    - unique items only replace their own copy;
    - level requirements and red tooltip text block use;
    - quest rewards: each choice is compared with what is worn. Any non-gear choice leaves the pick manual (upgrades are still marked). Otherwise the biggest upgrade wins, and with no upgrade the highest vendor value (stack size counted);
    - loot rolls: Need only on an upgrade you may Need on.
  - **Items** (`Items.lua`): stats come from `C_Item.GetItemStats`. The tooltip is read once per item, only for usability, binding and Equip: lines the stat table lacks (crit/hit % on a 1.x-era client). Cached until level or skills change.
  - **Weights** (`Weights.lua`, `Data/Weights.lua`):
    - AutoGear's classic defaults for the nine Forever classes, plus Forever fixes: crit/hit per 1%, Hunter ranged vs melee weapon DPS, healers value +healing;
    - your own weights per class/spec/phase, merged over the defaults;
    - AutoGear's imported weights migrated once;
    - Pawn-format import and export;
    - ForeverGear's public API as an optional score source at levels 1-20.
  - **Performance** (`Core.lua`):
    - no OnUpdate (AutoGear runs a 20 Hz loop permanently);
    - events registered only for features that are on: Mark Only listens to quest windows only, and tooltips are a hook;
    - one coalesced pass after a burst of bag events, one equip per pass, out of combat only, never with an item on the cursor;
    - item-data events are registered only while something waits for them;
    - at level 60 with Levelling Mode, bag, equipment and roll events are dropped.
  - **Safety:**
    - while AutoGear is enabled, Gear only marks;
    - blue and epic bind-on-equip items are never auto-equipped (greens optional);
    - only the bind prompt Gear itself caused is confirmed;
    - an item that fails to equip 3 times is skipped.
  - **UI** (`Markers.lua`, `Options.lua`):
    - a tooltip line ("Gear: +2.5 upgrade" / score / equipped);
    - green borders on upgrade quest rewards, gold on the highest vendor value when nothing is an upgrade;
    - a Gear section in the Ellesmere sidebar via `RegisterPlugin`, with pages Automation / Stat Weights / Markers, built with Ellesmere widgets and popups (Disable AutoGear uses Ellesmere's Forever-safe reload popup);
    - with the local core patch, a "GEAR → Open" row on the QoL page;
    - `/fhkgear` opens the tab; `/fhkgear scan|item|status` are for in-game checks.
- **E1/E2:** `node Interface/AddOns/FHKGear/tests/run.js`: 7 TOC files parse as Lua 5.1, ASCII only, no OnUpdate; **80** mocked checks PASS. No E3: new addon, so **full client restart**. `/fhkgear status` shows which client APIs Forever offers. Not yet: bag-slot upgrade arrows, loot-roll frame borders, quivers/ammo bags.
