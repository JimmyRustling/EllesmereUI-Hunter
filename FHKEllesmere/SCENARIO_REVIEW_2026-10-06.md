# Scenario review: class, level and situation (2026-10-06)

**Request (player, 2026-10-06):**
- "hunter autobuy should buy the highest ammo available but what happens if they're close to the next level up of ammo buying a full quiver worth of ammo would be silly"
- "what about auto buy food/drink up to x amount 1 stack 2 stacks, mages have conjure so no reason for them to ever be out, things like this we really need to scrutinise when we're developing here"

**Method:** a read-only review agent read the plan docs (CLASS_KITS, FEATURE_REVIEW, BUILD_PLAN, AGENT_BRIEF, FEATURES). It then walked every module for 9 classes, at levels 1-60, in 14 situations:
- solo, dungeon group, city / inn, at a vendor or trainer, on a taxi, mounted, dead or ghost;
- resting, swimming, in combat, just levelled, just trained, low on gold, bags full.

**Modules read:** Warnings, HunterCues, PetFood, SummonBar, AutoTrain, TalentPlanner, LevelingQoL, AspectBar / AspectLogic, the range parts of Companion and RangeIntegration, and ClassStock. Five more were read as they stood at 13:00-13:10, possibly partial: ClassBuffs, WeaponEnchants, ClassCues, RankNotifier / ClassTrainingData and AmmoBuy.

**Evidence:**
- **E1 only:** code and Forever client tables, wago.tools DB2 build **1.60.1.70205** (ItemSparse, Item, ItemEffect, ItemXItemEffect, SpellItemEnchantment, SpellMisc, SpellDuration, SpellName).
- **Not verified in game.**
- DB2 gives an item's level, price and stack, but not **which NPC sells it**. Vendor availability is marked "unverified" wherever it matters.

**Severity:** **must** (do before testers), **should** (this pass if cheap), **nice**.

**Owners:** A ClassBuffs, B WeaponEnchants, D ClassCues, E RankNotifier, F Warnings / HunterCues / PetElements / AmmoBuy, G range options, lead for everything else.

---

## 0. Cross-cutting (lead)

| ID | Class / level / situation | What happens | Why it's silly | Fix | Sev |
|---|---|---|---|---|---|
| S1 | Any class; any cue with its own sound | `Warnings.lua` `Show()` plays the lane sound (`warnSound` / `dangerSound`) for every new key (`:447`, `Sound(key,critical)`). ClassStock, ClassBuffs, WeaponEnchants, ClassCues and RankNotifier then play their own sound, with a different throttle key. | **Double sound** for one cue whenever both are set. | Add `NS.ShowEllesmereWarning(key,text,colour,slow,critical,sound)`. A module sound replaces the lane default for that key, and one throttle key is used per lane key. Modules stop calling `PlayEllesmereCueSound` beside `Show`. Owner F (Warnings), with A / B / D / E passing `sound`. | must |
| S2 | All classes; dead, ghost, taxi, vehicle, mounted | Each module has its own "away" test, with different results: ClassBuffs blocks dead / mounted / taxi / vehicle; WeaponEnchants blocks dead / taxi; ClassStock, Warnings ammo / pet food, HunterCues Trueshot and LevelingQoL gather block nothing. | Reminders fire while you cannot act. | Add one `NS.EllesmereAway(kind)` in Bootstrap that returns dead / ghost / taxi / vehicle, plus `mounted`, `swimming` and `resting` flags. Each cue declares a policy (table below). | must |

**Away policy** (what each kind of cue ignores):

| Cue kind | Dead / ghost | Taxi / vehicle | Mounted | Swimming | Resting | In combat |
|---|---|---|---|---|---|---|
| Missing self-buff / armor / aura | quiet | quiet | quiet | show | quiet (S32) | per group |
| Made item (stone, conjure) low | quiet | quiet | quiet | show | show | quiet |
| Bought reagent / ammo / food low | quiet | quiet | show | show | show once on entering, then icon only | quiet |
| Act-now (out of ammo, dead pet, Stop Attack) | quiet | quiet | quiet | show | show | show |

---

## 1. AmmoBuy.lua (F, in progress)

**Ammo tiers from DB2 (E1):**

| Level | Arrow | Bullet | Price per bundle of 200 |
|---|---|---|---|
| 1 | Rough Arrow 2512 | Light Shot 2516 | 10c |
| 10 | Sharp Arrow 2515 | Heavy Shot 2519 | 50c |
| 25 | Razor Arrow 3030 | Solid Shot 3033 | 3s |
| 40 | Jagged Arrow 11285 | Accurate Slugs 11284 | 10s |
| 51 | Ice Threaded Arrow 19316 | Ice Threaded Bullet 19317 | 60s (uncommon; vendor unverified) |

Thorium Headed Arrow 18042 and Thorium Shells 15997 (level 52, bundle 100) are crafted.

| ID | Class / level / situation | What happens | Why it's silly | Fix | Sev |
|---|---|---|---|---|---|
| S3 | Hunter 9, 24 or 39, near the next tier | `keep=1000` is bought from the current best tier. A level 9 hunter at 90% XP buys 1000 Rough Arrows; one level later Sharp unlocks. | **Player's exact case.** It fills the quiver with ammo that is obsolete within minutes. | **Next-tier bridge** (engine section 3). If a better tier for this ammo type unlocks within **1 level** (or you are at 75% XP or more into level N-1), buy only the **bridge amount** (default 200, one bundle). Tier levels come from the vendor's own list plus `GetItemInfo` minLevel, with the DB2 table above as fallback. | must |
| S4 | Hunter 10, 25 or 40, first vendor after unlock, carrying 1000 lower-grade | `Carried()` counts every arrow regardless of grade, so `need = keep - have <= 0` and it buys nothing. | **Lower-grade stock blocks the upgrade forever.** The new tier is never bought while old arrows remain. | Count by tier. On the first visit after a tier unlocks, always buy at least **200** of the new tier: FHKGear equips new ammo once it has a real stack of 200 (FEATURES.md "Bags and ammo"). Lower grade counts toward Keep only under "Use Up Old Ammo" (default on); chat says "carrying 800 Sharp Arrow (older)". | must |
| S5 | Hunter, any level, bags nearly full | `space=true` adds **every free general-bag slot** times 200 to the room. | It fills the bags with arrows, and the next loot is left behind (LevelingQoL "Bags Full"). | Fill modes: **Keep At Least** (count) / **Fill Quiver** (default) / **Fill Quiver And Bags**. Add **Leave Free Bag Slots** (default 2). | must |
| S6 | Hunter, level 1-12 with less than 1g | `keepGold=1` default means nothing is ever bought. "kept your gold floor (1g)" prints. | 1000 Rough Arrows cost 50c. A gold floor larger than the whole budget makes the feature dead at the levels that need it. | Gold floor default **0**, plus **Max Spend Per Visit** (default 25% of money). Engine budget, section 6. | must |
| S7 | Any; vendor sells ammo and food, or Ellesmere Auto Repair is on | AmmoBuy and PetFood both act on `MERCHANT_SHOW` in the same frame from a stale `GetMoney`. Ellesmere QoL repairs and sells junk at the same moment (`EllesmereUIQoL.lua:1004`). | The gold floor and the "tenth of your money" can both be broken, and repair can fail for lack of money. | **One engine** with a sequential budget: reserve `GetRepairAllCost()` when `CanMerchantRepair()`, then buy in priority order (section 6). | must |
| S8 | Warrior or rogue 10-60 with a stat bow or gun | Keeps 1000 arrows for a weapon that pulls once per mob. | 5 bag slots of arrows for a warrior. | Class default Keep: **200** for warrior / rogue, 1000 for hunter. | should |
| S9 | Any; bags full or below floor, every vendor | `told` resets on each `MERCHANT_SHOW`, so "no room" or "gold floor" prints at **every** vendor. | Chat spam that cannot be fixed at a food vendor. | Print each reason once per session and level, or when it changes. One summary line per visit (section 8). | should |
| S10 | Hunter 51-60 | `Better()` picks Ice Threaded (60s / 200) wherever it is sold. | 4000 rounds cost 12g per visit at 60, which may not be the player's intent. | The **Max Spend Per Visit** cap, plus a cog choice "Best Tier / Best Common Tier" (default: best common, quality 1). | should |

---

## 2. Warnings.lua (F)

| ID | Class / level / situation | What happens | Why it's silly | Fix | Sev |
|---|---|---|---|---|---|
| S11 | Warrior or rogue 10-60 with a quest-reward bow or gun and no ammo | `ammo=true` default. `UsesAmmo()` is true, slot empty, nothing fits, so count=0: red **"Out of Ammo"** that is **critical**, above the character in every fight, forever. | **A warning a warrior cannot (and does not want to) act on.** Many melee classes equip a ranged weapon for stats. | Ammo warnings default to hunters only. Non-hunters get the low ammo warning out of combat only once they have carried that ammo this session, and never the critical lane. Hide the row for classes that cannot use bows or guns (mage, priest, warlock, druid, paladin, shaman), where it has no effect. | must |
| S12 | Hunter, any level, equipped stack low while other ammo is in the bags | Count = `GetInventoryItemCount(ammo slot)`, the equipped item only. With 150 Sharp equipped and 1000 Rough in the bags: red "Ammo Critical" in combat at 50. | It cries wolf. Classic does not switch ammo by itself, but the fix is "equip the other ammo", not "you're out". | Report the total of fitting ammo. Show "Low Sharp Arrow (150): 1000 Rough in bags" in amber. Make it critical only when the **total** is at or under the Critical threshold. | should |
| S13 | Hunter 10-60, taxi, dead or mounted | The No / Low Pet Food warning has no away guard (`:662-671`). | Unactionable while flying or as a ghost. | Use the away policy (S2): "bought supply" row. | should |
| S14 | Hunter, just tamed a pet 3 or more levels below | "Pet Level 50 (5 Levels Below You)" stays for hours (`:821-830`). | It cannot clear until the pet levels; it is a state, not news. | Show it for 10 s on login, `UNIT_PET` and `PLAYER_LEVEL_UP`, then leave only the pet XP badge (H6). | should |
| S15 | Hunter, dead or ghost | Low Ammo stays on the lane. | Noise during a corpse run. | Away policy. | nice |

---

## 3. HunterCues.lua (F)

| ID | Class / level / situation | What happens | Why it's silly | Fix | Sev |
|---|---|---|---|---|---|
| S16 | Hunter 6-60, dungeon with 2 hunters, elite target | Hunter's Mark is read with `HARMFUL\|PLAYER` (`:438`), so another hunter's Mark reads as missing. | You are told to overwrite your partner's Mark: a wasted GCD and mana. | Read `HARMFUL`. Any Hunter's Mark on the target hides the cue. | should |
| S17 | Hunter with the Trueshot talent, dead or ghost | The aura drops on death, and `CheckBuffs` has no away guard. | "Trueshot Aura" shows as a ghost. | Away policy. | should |
| S18 | Hunter, dungeon, pet on Passive or Stay to avoid breaking crowd control | Pet Idle shows "Send It In" after 1.5 s. | It contradicts a deliberate choice, and Pet On Passive already covers Passive. | Quiet when `NS.EllesmerePetPassive()==true` or the target is held (`H.HeldBy`). | should |

---

## 4. PetFood.lua auto-buy (lead; moves into the engine)

| ID | Class / level / situation | What happens | Why it's silly | Fix | Sev |
|---|---|---|---|---|---|
| S19 | Hunter 10-60 who eats bread or meat themselves | `NS.EllesmerePetFoodCount` counts **every** edible item (`:129`), including the player's own food, and the Feed button may feed it. A player food restock would double-count. | The pet eats your dinner, and "Keep Pet Food 20" is met by your bread. | **Reservation** (engine section 5): food the engine buys for the player is skipped by PetFood until the bags hold more than the player's target. | must |
| S20 | Hunter; pet dismissed in town, or dead | `F.AutoBuy` needs `UnitExists('pet')` and `CanPetEatItem` (`:676`). | It never restocks in the city, where you usually leave the pet. | Cache the diet per pet family (`UnitCreatureFamily`, plus the `ItemPetFoodID` bit when known) per character, and buy from the cache. | should |
| S21 | Hunter, any vendor | There is no Shift skip and no gold floor; the only limit is "a tenth of your money". | Inconsistent with AmmoBuy and AutoTrain. | Join the engine: shared Shift skip, floor and budget. | should |

---

## 5. ClassStock.lua (lead)

| ID | Class / level / situation | What happens | Why it's silly | Fix | Sev |
|---|---|---|---|---|---|
| S22 | Shaman 30+, paladin 30+, druid 20+, warlock 50+ | One `reagentLow=5` applies to every reagent. Ankh (stack 5, long cooldown), Symbol of Divinity, Rebirth seeds, Infernal Stone and Demonic Figurine all show "Low X (4)" in every city, every session. | Use rates differ by 20 times. 4 Ankhs is plenty. | **Keep and Low per item** (defaults in engine section 9). This is the same number the restock engine buys to. | must |
| S23 | Rogue, mage or paladin 20+ in a city, at a vendor that does not sell the item | The "Smart" cue fires when resting or at **any** vendor (`:414-420`). | "No Flash Powder" at the armorer, and on every city walk. | **At a vendor:** warn only if **this** vendor sells it, as "Buy Flash Powder here". With the engine on, it buys instead. **Resting:** show for 10 s on entering rest, then icon only. | must |
| S24 | Warlock 10-60 with 0 shards | "No Soul Shards", "No Healthstone" and "No Soulstone" make 3 lines. Stones cannot be made without a shard. | Unactionable duplicates. | With 0 shards, hide the stone cues and show one line: "No Soul Shards (Healthstone, Soulstone)". | must |
| S25 | Mage 4-60 or warlock 10-60, on a taxi, dead or mounted | Conjured, stone and shard cues have no away guard, so they show whenever out of combat. | You cannot conjure on a taxi, as a ghost, or mounted. | Away policy (S2), "made item" row. | should |
| S26 | Mage 12+, priest 34+, paladin 30+, mage 40+ | Light Feather, Symbol of Divinity and Rune of Portals default **on**. | Most levellers never carry them, so it is a permanent nag. | `def=false` for feathers (both), Divinity and Portals. Teleport runes stay on. | should |
| S27 | Rogue 16+ | Thieves' Tools defaults on with threshold 1, but it is never consumed. | "No Thieves' Tools" at every vendor for rogues who never pick locks. | `def=false`, and once bought never auto-buy again (the engine treats it as `oneTime`). | should |
| S28 | Mage, just trained a new Conjure Water rank | `all=true` counts lower-rank water as OK. | You carry 20 weak waters and get no prompt. | When only lower-rank conjures remain, show the icon with an "old" corner mark and a one-off "Conjure new rank" lane line. | nice |
| S29 | Druid 30+, just trained Rebirth rank 2, carrying Maple Seeds | Only the top seed counts, so "No Stranglethorn Seed" shows. | The warning is right (casting from the spellbook uses the top rank), but there is no buy path. | The engine restocks the top-rank seed; the tooltip says lower seeds still work for rank 1. | nice |
| S30 | Rogue 22+, paladin, shaman, mage, druid at a vendor that sells the reagent | It warns "No Flash Powder" but cannot buy it. | **Missing obvious companion feature.** | The Vendor Restock engine. | must |

---

## 6. ClassBuffs.lua (A)

| ID | Class / level / situation | What happens | Why it's silly | Fix | Sev |
|---|---|---|---|---|---|
| S31 | Shadow priest 40-60, dungeon, drops Shadowform to heal | The Shadowform group has `when='always'`, so "NO SHADOWFORM" shows in combat for the whole heal. | **A cue that cannot clear** while the player does the right thing. | Out of combat only (`when='rest'`), plus a 10 s grace after leaving the form. | must |
| S32 | Mage, warlock, priest, druid or paladin in a city or inn | The "rest" cues ("NO ARMOR", "NO ARCANE INTELLECT", "NO BLESSING") fire while resting. | AFK in Orgrimmar does not need Frost Armor. | Add a **Quiet While Resting** toggle (default on). Cues return on leaving rest or entering an instance. | should |
| S33 | Paladin 1-60, melee, Judgement rotation | The Seal cue is `when='melee'` and `critical=true`. Judgement consumes the seal, so "NO SEAL" shows above the character every rotation, with sound. | It is a normal one-GCD gap, not a mistake. | Add a 1.6 s grace after seal loss or a Judgement cast (`UNIT_SPELLCAST_SUCCEEDED`), and make it non-critical by default. | should |
| S34 | Shaman 8-30, levelling | The shield group is `'always'` with Low at 1 charge. Lightning Shield costs mana; many levellers skip it. | In-combat "NO SHIELD" / "LOW" spam. | Default shields to out of combat, and the Low cue off. | should |
| S35 | Druid 6-60 | The Thorns cue is on by default (10 min buff, caster form only). | A reminder every 10 min out of combat, for a buff most use only on tanks or pets. | Thorns cue default off. | nice |

---

## 7. WeaponEnchants.lua (B)

| ID | Class / level / situation | What happens | Why it's silly | Fix | Sev |
|---|---|---|---|---|---|
| S36 | Rogue 20, Poisons just learned, none in bags | "NO INSTANT POISON (MAIN HAND)", "NO INSTANT POISON (OFF HAND)" and "OUT OF INSTANT POISON" appear everywhere out of combat. | **3 lines for one problem**, far from any vendor. | Merge to one line ("NO POISON: none in bags"). Missing-with-no-items shows only resting or at a vendor (the Smart window). | must |
| S37 | Shaman 1-60 | Expiring is a fixed 5 min. Forever DB2 `SpellItemEnchantment.Duration` is 3600 for Rockbiter, Flametongue, Frostbrand and Windfury (Classic 1.12: 5 min; probe). | If imbues last 5 min or less on Forever, the imbue reads **"EXPIRING" from the moment it is applied**. | Threshold = min(setting, 20% of the duration seen at apply). Probe imbue `timeLeft` right after casting. | should (must if the probe shows 5 min) |
| S38 | Mage, priest, warlock, druid, hunter, warrior or paladin | The master toggle shows for every class, but `Kind()` is 'none' unless "Stone And Oil Reminder" is on. | **A toggle with no effect** for 7 of 9 classes. | For non-rogue / non-shaman, the master toggle turns stones on, or the stones row becomes the master. | should |
| S39 | Rogue or shaman, mounted | Suppression covers dead and taxi only. | "NO ROCKBITER" while riding. | Add mounted (missing cue only). | nice |

---

## 8. ClassCues.lua (D)

| ID | Class / level / situation | What happens | Why it's silly | Fix | Sev |
|---|---|---|---|---|---|
| S40 | Warrior 24-60 tanking (Defensive), group or dungeon | The Execute rule (Battle / Berserker) gives "Battle Stance - Execute" at 20% boss health. The Overpower window gives "Battle Stance - Overpower" on a dodge. | It **tells the tank to leave Defensive Stance.** | Never suggest leaving Defensive while grouped or in an instance. The Execute and Overpower hints from Defensive apply solo only. | must |
| S41 | Warrior 10-60, Battle Stance DPS with a shield | Every block, dodge or parry opens the Revenge window, giving "Defensive Stance - Revenge". | Constant advice to switch to a stance DPS does not use. | Revenge rule default **off**, or only after Defensive was used in the last 5 min. | must |
| S42 | Rogue 10-60, solo trash | The Slice and Dice cue shows at `sndPoints=1` in combat on any mob. | It nags on a 10% health mob about to die. | `sndPoints` default 2, and skip when target health is under 35%. | should |
| S43 | Rogue or druid, stealthed past mobs | The opener cue fires for any hostile target while stealthed, at any range. | "Garrote" while sneaking past. | Only in melee range or within 10 yd (shared range reader); unknown range stays quiet. | should |

---

## 9. RankNotifier.lua and ClassTrainingData (E)

| ID | Class / level / situation | What happens | Why it's silly | Fix | Sev |
|---|---|---|---|---|---|
| S44 | Mage 20+ (teleports), 40+ (portals) | Listed as "new spells at your trainer". Classic teaches them at **portal trainers** in capitals. | The player visits the wrong NPC. | Tag the group "(portal trainer)" in the data and the text. | should |
| S45 | Any class, low on gold | Counts every spell with no cost. | "6 new spells" when you can afford 2. | At a trainer, add affordable versus total cost (the service cost is live there). | nice |

---

## 10. AutoTrain.lua (lead)

| ID | Class / level / situation | What happens | Why it's silly | Fix | Sev |
|---|---|---|---|---|---|
| S46 | Any class at a weapon master, 10-30 | Trainer type is not pet or tradeskill, so it buys **every** weapon skill offered (staves, maces...). | Gold wasted on weapons you'll never use, at the poorest levels. | Class trainers only by default; a "Weapon Masters Too" toggle (off). | should |
| S47 | Any class 20-40 saving for ammo, food or a mount | Keep At Least is 0 and it trains in list order. | Spends the restock and mount money; a cheap utility rank can block a core rank. | Share the engine's gold floor. Order: upgrades of spells already known, then new spells; skip if the cost is over X% of money (default 100). | should |

---

## 11. TalentPlanner, LevelingQoL, AspectBar, SummonBar, range (lead / G)

| ID | Module | Class / level / situation | What happens | Why it's silly | Fix | Sev |
|---|---|---|---|---|---|---|
| S48 | TalentPlanner | Any, a plan pick blocked by the tier gate | `P.Learn` stops silently; Warnings says "Unspent Talent Point: X". | No reason given, so the player cannot fix the plan. | Chat once: "Plan blocked at X: needs N points in <tree>". | should |
| S49 | AspectLogic | Hunter 20+ (Cheetah), swimming | Travel advice suggests Cheetah while moving. | Cheetah does not raise swim speed. | `IsSwimming()` hides travel advice. | should |
| S50 | LevelingQoL | Hunter or miner / herbalist, taxi or ghost | The Gathering Tracking reminder shows. | Unactionable. | Away policy. | nice |
| S51 | SummonBar | Warlock 50+ / 60 | Infernal and Ritual of Doom dim by Soul Shards. | They need an Infernal Stone or a Demonic Figurine. | Dim by the reagent count. | nice |
| S52 | Warnings options | Mage, priest, warlock, druid, paladin, shaman | The "Low Ammo Warning" row is shown (on by default). | A toggle with no effect. | Show it only for classes that can use bows or guns. | nice |

---

## 12. Vendor Restock engine: requirements

**Shape:**
- **File:** new `Restock.lua` (owner F, since it absorbs AmmoBuy; the lead integrates PetFood's buy path).
- **Options:** Warnings > **VENDOR RESTOCK**. Each category is one row: toggle + "Keep" slider, with a cog for mode, bridge and limits.
- **Hub:** each class hub gets a row.
- **Defaults:** every category **off**; the master is off.
- **Cost while off:** no events. While on: `MERCHANT_SHOW`, `MERCHANT_CLOSED`, `MERCHANT_UPDATE`, `BAG_UPDATE_DELAYED` (only during a visit), and `PLAYER_LOGIN`.
- **Profile keys:** look and behaviour. **Character keys:** pet diet cache, one-time flags, last tier seen.

### 1. Categories

| Category | Who sees it | Identify an offer (runtime, no fixed ID list) | What counts in the bags |
|---|---|---|---|
| Ammo | Hunter; warrior / rogue with a bow, gun or crossbow | `GetItemInfoInstant` class 6, subclass 2 (arrow) for bow (2) or crossbow (18), subclass 3 (bullet) for gun (3) | That subclass, split **by tier** (minLevel) |
| Food | All classes | Class 0, subclass 5, and `C_Item.GetItemSpell(id)` name == `C_Spell.GetSpellName(433)` ("Food"). This excludes buff food ("Food" spells with Well Fed are separate IDs such as 25660, which are skipped) and Refreshment | Food spell items plus conjured food (5349, 1113, 1114, 1487, 8075, 8076, 22895) |
| Drink | Mana users only (priest, mage, warlock, druid, paladin, shaman, hunter) | Class 0, subclass 5, spell name == `GetSpellName(430)` ("Drink") | Drink items plus conjured water (5350, 2288, 2136, 3772, 8077, 8078, 8079, Forever 231778) |
| Class reagents | Per class, from ClassStock `KITS` plus the gates in section 9 | Exact item IDs | Exact item IDs (all ranks where ClassStock says `all`) |
| Pet food | Hunter with a pet (or a cached diet) | `CanPetEatItem`, or the cached diet | Edible items minus the player's food reservation |

Forever adds vendor food and drink with new IDs: Crisp Spring Water 252031 (level 1), Gustberry Juice 252027 (level 5, 25c per 5), Galestrider Jerky 252022 and others. Matching by spell name and level covers them with no data change.

### 2. Targets

- **Unit:** `count` or `stacks`. Stacks use `C_Item.GetItemMaxStackSizeByID` (food and drink 20, ammo 200, Ankh / Divinity / Infernal / Figurine 5, runes 10, Symbol of Kings 100). The UI shows "1 stack (20)".
- **Default Keep:** Food 1 stack, Drink 1 stack (2 stacks at 40+ is a cog option), ammo per S8, reagents per section 9.
- **Purchases are whole vendor bundles.** `info.stackCount` is the increment the Blizzard split frame uses (`MerchantFrame.lua:713-739`): 5 for food and drink, 200 for ammo, 20 for Symbol of Kings.
- **Batch:** `GetMerchantItemMaxStack(i)` per call. Quantity is in items, a multiple of the bundle.

### 3. Tiers and the next-tier bridge (ammo, food, drink)

- **Tier = required level.** Ammo unlocks at 1 / 10 / 25 / 40 (51 limited). Vendor food and drink unlock at **1 / 5 / 15 / 25 / 35 / 45** (55: Hyjal Nectar 18300, Filet o' Flank 238638; vendor unverified).
- **Best offer:** the highest minLevel at or under your level, then the cheapest per unit. Food and drink prefer quality 1, bundle 5. Skip `hasExtendedCost`, `isPurchasable==false`, `numAvailable==0` and secret reads.
- **Bridge:**
  - **When:** a better tier exists for the category, by vendor list or table, at level L+1 (or L+N, cog 0-3), and you are at 75% XP or more into that level (`UnitXP` / `UnitXPMax`, public reads only; unknown means no bridge).
  - **What:** buy only **Bridge Amount** (ammo 200; food and drink 5, one bundle), not the target.
  - **Level 60:** nothing to bridge.
- **New tier:** on the first visit after a tier unlocks, buy at least the bridge amount of the new tier even if lower grade meets Keep. Ammo: at least 200, FHKGear's equip threshold.
- **Lower grade:**
  - "Use Up Old Stock" (default on): lower-grade items count toward Keep.
  - Off: only the best usable tier counts.
  - Lower grade never counts when it is 2 or more tiers below (for example level-1 water at 30).

### 4. Mage and conjure rules

- **Mage, Conjure Water known** (5504, or any rank by name): the Drink category is **greyed** with "You conjure water". The cog has "Buy Anyway" (off).
- **Mage, Conjure Food known** (587): the same for Food.
- **Mage levels 1-3:** drink is allowed until Conjure Water is learned. On `SPELLS_CHANGED` the engine stops and says once: "Conjure Water learned: Drink restock paused".
- **Every class:** conjured food and water in the bags count toward Food / Drink (water from a party mage stops a priest's purchase).
- **Mana gems, Healthstones and Soulstones are never bought.** ClassStock handles them.

### 5. Pet food interplay

- **PetFood auto-buy moves into the engine** as the Pet Food category, keeping Food Choice (closest level / cheapest) and Keep Pet Food.
- **Reservation:** the item IDs the engine buys as player Food make up a "player food" set (per character, last 3 bought). PetFood's count, Food Only view and Feed button skip that set while its total is at or under the player's Food Keep. Above it, the surplus is fair game.
- **Choosing player food:** prefer a type the current pet **cannot** eat (`ItemPetFoodID` diet bit versus the pet's diet). A bear or boar eats everything, so this falls back to the reservation.
- **Diet cache:** per pet family per character, so the restock works with the pet dismissed or dead (S20).

### 6. Order and money

- **Budget for the visit:** `GetMoney()` - **Keep At Least** (default 0) - `GetRepairAllCost()` (when `CanMerchantRepair()`, so Ellesmere's Auto Repair is never starved), then capped at **Max Spend Per Visit** (default 25% of money, cog 5-100%).
- **Order:** "minimum" pass, then "fill" pass. Each item is skipped when its unit price would break the budget.
  1. Ammo up to Critical (hunter: 200 or the bridge).
  2. Class reagents up to Low (Ankh 1, Flash Powder 5, seeds 1...).
  3. Drink up to 1 bundle (mana users).
  4. Food up to 1 bundle.
  5. Pet food up to 1 bundle.
  6. Fill to Keep, in the same order (ammo, reagents, drink, food, pet food).
- **Rationale:** a hunter without ammo cannot fight; a caster without drink only rests longer. Reagents are cheap and gate key spells.
- **Low on gold:** the minimum pass guarantees the essentials, and the fill pass stops at the cap.
- **Running balance:** deduct `price x quantity` locally after each `BuyMerchantItem`. Never re-read `GetMoney()` mid-visit (it lags).

### 7. Bags, limits and the loop guard

- **Room:** computed per item: free slots in bags whose family accepts it (`C_Container.GetContainerNumFreeSlots` family bits: quiver 1 = arrows, ammo pouch 2 = bullets, soul bag 4 = shards; general bags 0), plus space on partial stacks.
- **Leave Free Bag Slots:** default 2, general bags only. A quiver is not a general bag.
- **Ammo fill modes:** Keep At Least / **Fill Quiver** (default) / Fill Quiver And Bags.
- **Limited stock:** `numAvailable > 0` caps; `0` skips; `-1` is unlimited.
- **Loop guard:**
  - one pass per visit (`visited` is set **before** buying);
  - one 0.6 s retry for late merchant data, only if nothing was bought;
  - after the pass, the `BAG_UPDATE_DELAYED` recount must show a gain;
  - an item with no gain (server refused: full, sold out or money) is skipped for the rest of the visit and for the next 60 s, and named once in chat.
- **Unreadable:** any unreadable bag, money or merchant read means no purchase for that category (unknown is never "missing").

### 8. Controls and feedback

- **Shift skip:** hold Shift when the vendor opens to skip the whole visit, and print "Restock skipped (Shift)". Repair is Ellesmere's and unaffected.
- **Per-category toggles:** Ammo, Food, Drink, Class Reagents (with a per-reagent sub-toggle list in the cog), Pet Food. Section **Reset**.
- **Chat:** **one summary line** per visit ("Restocked: 200 Sharp Arrow, 20 Ice Cold Milk, 5 Flash Powder (1s 35c)"). Reasons that blocked (floor, bags) print once per session.
- **Cues:**
  - ClassStock and Warnings low cues read the engine's Keep and Low, so the lane says the same numbers the vendor buys to.
  - At a vendor that sells a low item, with the category off, the cue reads "Buy X here".
- **Tests:** off means zero events; class gates; the bridge at 9 / 24 / 39 and at 4 / 14 / 24 / 34 / 44; lower-grade blocking; mage conjure greying; reservation; budget order with repair cost; Shift; bundle multiples; `numAvailable`; no-gain guard; secret reads; bags full with the slot reserve.

### 9. Class reagent defaults (Keep / Low; DB2 price per vendor bundle, E1; vendors unverified)

| Class | Item (ID) | Gate | Keep / Low | Price |
|---|---|---|---|---|
| Rogue | Flash Powder 5140 | Vanish | 10 / 3 | 25c |
| Rogue | Blinding Powder 5530 | Blind | 5 / 2 | 5s |
| Rogue | Thieves' Tools 5060 | Pick Lock | 1, one-time | 15s |
| Rogue (option) | Vials 3371, 3372, 8925; Dust of Decay 2928; Essence of Pain 2930; Deathweed 5173; Dust of Deterioration 8924; Essence of Agony 8923 | Poisons skill | Per crafted poison: off by default (phase 2) | 20c / 5 to 25s / 5 |
| Shaman | Ankh 17030 | Reincarnation | 2 / 1 | 20s |
| Shaman | Fish Oil 17058, Shiny Fish Scales 17057 | Water Walking / Breathing | 5 / 1, off | 30c |
| Mage | Rune of Teleportation 17031 | Teleport | 5 / 2 | 10s |
| Mage | Rune of Portals 17032 | Portal | 5 / 2, off | 20s |
| Mage | Arcane Powder 17020 | Arcane Brilliance | 20 / 5 | 10s |
| Mage | Light Feather 17056 | Slow Fall | 10 / 3, off | 30c |
| Priest | Holy Candle 17028 / Sacred Candle 17029 | Prayer of Fortitude rank | 20 / 5 | 7s / 10s |
| Priest | Light Feather 17056 | Levitate | 5 / 2, off | 30c |
| Paladin | Symbol of Kings 21177 | Greater Blessings | 40 / 10 | 30s / 20 |
| Paladin | Symbol of Divinity 17033 | Divine Intervention | 1 / 0, off | 20s |
| Druid | Top Rebirth seed (17034-17038) | Rebirth rank | 2 / 1 | 2s-20s |
| Druid | Wild Berries 17021 / Wild Thornroot 17026 | Gift of the Wild rank | 10 / 3 | 7s / 10s |
| Warlock | Infernal Stone 5565 | Inferno | 1 / 0, off | 50s |
| Warlock | Demonic Figurine 16583 | Ritual of Doom | 1 / 0, off | 1g |

### 10. Standard vendor food and drink (DB2 1.60.1.70205, E1; price per bundle of 5, stack 20)

| Req. level | Drink | Bread (4) | Meat (1) | Fish (2) | Cheese (3) | Fungus (5) | Fruit (6) | Price / 5 |
|---|---|---|---|---|---|---|---|---|
| 1 | Refreshing Spring Water 159 | Tough Hunk of Bread 4540 | Tough Jerky 117 | Slitherskin Mackerel 787 | Darnassian Bleu 2070 | Forest Mushroom Cap 4604 | Shiny Red Apple 4536 | 25c |
| 5 | Ice Cold Milk 1179 | Freshly Baked Bread 4541 | Haunch of Meat 2287 | Longjaw Mud Snapper 4592 (20c) | Dalaran Sharp 414 | Red-speckled Mushroom 4605 | Tel'Abim Banana 4537 | 1s 25c |
| 15 | Melon Juice 1205 | Moist Cornbread 4542 | Mutton Chop 3770 | Bristle Whisker Catfish 4593 | Dwarven Mild 422 | Spongy Morel 4606 | Snapvine Watermelon 4538 | 5s |
| 25 | Sweet Nectar 1708 | Mulgore Spice Bread 4544 | Wild Hog Shank 3771 | Rockscale Cod 4594 | Stormwind Brie 1707 | Delicious Cave Mold 4607 | Goldenbark Apple 4539 | 10s |
| 35 | Moonberry Juice 1645 | Soft Banana Bread 4601 | Cured Ham Steak 4599 | Striped Yellowtail 21552 | Fine Aged Cheddar 3927 | Raw Black Truffle 4608 | Moon Harvest Pumpkin 4602 | 20s |
| 45 | Morning Glory Dew 8766 | Homemade Cherry Pie 8950 | Roasted Quail 8952 | Spinefin Halibut 8957 | Alterac Swiss 8932 | Dried King Bolete 8948 | Deep Fried Plantains 8953 | 40s |
| 55 | Hyjal Nectar 18300 (vendor unverified) | - | Filet o' Flank 238638 (Forever, vendor unverified) | - | - | - | - | 40s / 50s |

- **Why the bridge matters for food:** at 45+, one stack each of food and drink is 3.2g. Buying 2 stacks of level 35 food at 44 / 80% XP wastes 1.6g.
- **Column numbers** are the `Item.ItemPetFoodID` diet bit, used for the reservation in section 5.
- **Conjured flag:** ItemSparse `Flags_0` bit 0x2. It is not used at runtime, because Forever sells two conjured-flagged items: Expiring Crab Cake 268912 and Expiring Crocolisk Steak 268913.

### APIs (verified in the Forever docs / Mainline MerchantFrame that camelot loads)

- `C_MerchantFrame.GetItemInfo(i)`: `{name, price, stackCount, numAvailable, isPurchasable, isUsable, hasExtendedCost}`.
- Globals used by Forever's Mainline MerchantFrame: `GetMerchantNumItems`, `GetMerchantItemID`, `GetMerchantItemMaxStack`, `GetMerchantItemLink`, `BuyMerchantItem(i, qty)`, `GetRepairAllCost`, `CanMerchantRepair`.
- `C_Item`: `GetItemInfoInstant`, `GetItemInfo`, `GetItemCount(item, includeBank)`, `GetItemSpell`, `GetItemMaxStackSizeByID`.
- `C_Container`: `GetContainerNumFreeSlots` (free, family), `GetContainerNumSlots`, `GetContainerItemInfo`.
- `C_Spell.GetSpellName`, `C_SpellBook.IsSpellKnown`, `C_PetInfo.CanPetEatItem`.

---

## 13. Missing obvious features per class

- **All:**
  - food restock (drink too for mana users);
  - one restock summary line;
  - "Leave N bag slots free" shared with Loot Left Behind;
  - a merchant "Buy X here" hint for low supplies.
- **Warrior:**
  - no supplies at all; a thrown weapon / ammo option only if they shoot;
  - optional sharpening / weightstone restock where a vendor sells them (unverified; most are crafted).
- **Paladin:**
  - Symbol of Kings restock (bulk, bundle 20);
  - drink restock;
  - Seal grace (S33).
- **Hunter:**
  - ammo bridge and new-tier buy (S3 / S4);
  - quiver upgrade hint when a vendor sells a bigger quiver (Medium Quiver 11362 at level 10, Heavy 7371 at 30, Quickdraw 8217 at 40; vendor unverified);
  - pet food restock with the pet dismissed (S20).
- **Rogue:**
  - Flash and Blinding Powder restock;
  - poison reagent restock and a one-click craft from the poison pod (phase 2);
  - Thieves' Tools as a one-time buy.
- **Priest:**
  - candle and feather restock;
  - drink;
  - Shadowform out-of-combat cue (S31).
- **Shaman:**
  - Ankh restock;
  - a **totem tools check**: Earth 5175, Fire 5176, Water 5177 and Air 5178 are quest items. Probe whether Forever totems still need them in the bags;
  - drink.
- **Mage:**
  - no water or food buying once conjured (section 4);
  - rune and powder restock;
  - "Conjure new rank" after training (S28);
  - "conjure before leaving town" (out of combat, resting, drink count under Low).
- **Warlock:**
  - one shard line (S24);
  - Infernal Stone and Figurine restock (off);
  - "too many shards" bag hint when the soul bag is full;
  - drink.
- **Druid:**
  - seed and herb restock for the current Rebirth / Gift rank;
  - drink.
