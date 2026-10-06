# Suite review: QoL overlaps with EllesmereUI main (2026-10-06)

Read-only adversarial review. Our side: Forever Companion (FHKEllesmere 1.9.5) and FHK Gear 0.5.3.
Ellesmere side: main 9.3.9 (commit 14245494), staged at `.dev/staged-main-939/Interface/AddOns/`.
Evidence: **E1 static only**. Nothing here was mocked or run in game. "Probe" means only the client can settle it.

Paths below are short forms:
- `QoL` = `EllesmereUIQoL/EllesmereUIQoL.lua`
- `Bags` = `EllesmereUIBags/EllesmereUIBags.lua`
- `EQT-QoL` = `EllesmereUIQuestTracker/EllesmereUIQuestTracker_QoL.lua`
- `ABR` = `EllesmereUIAuraBuffReminders/EllesmereUIAuraBuffReminders.lua`
- Our files are under `Interface/AddOns/FHKEllesmere/` or `Interface/AddOns/FHKGear/`.

## Answers to the brief

### 1. Merchant visit

**Who runs first.** Ellesmere does.
- QoL creates `EUI_MerchantHandler` and registers MERCHANT_SHOW inside its PLAYER_LOGIN handler (QoL:52-53, QoL:1296-1298). QoL loads before FHKEllesmere, which lists it as an OptionalDep.
- Our driver registers in `E.Sync` (AmmoBuy.lua:186-191). That is reached from Restock's PLAYER_LOGIN boot (Restock.lua:874-876) and is re-run, with re-registration, on every profile sync.
- Under WoW's registration-order dispatch, QoL repairs (QoL:1326 / 1331) and starts the junk sweep (QoL:1337) in the same dispatch, before our handler (AmmoBuy.lua:324). The order holds only by convention, so treat it as **probe**.
- Our first purchase goes out one frame later (`Queue` uses `C_Timer.After(0)`, AmmoBuy.lua:292-297).

**Budget.**
- Computed once at MERCHANT_SHOW: `GetMoney - Keep At Least - GetRepairAllCost`, capped at Max Spend % (AmmoBuy.lua:329-333). After that it is a running local balance.
- Junk income is never added. That under-spends, which is harmless.
- The repair is subtracted even when the guild pays. Also an under-spend, also harmless.
- The only way to over-spend is SQ-8 (probe).

**Can the junk sale sell what we buy?**
- QoL's own sweep only counts `quality == Poor and not hasNoValue` (QoL:1044-1056).
- Our purchases are vendor commons (Restock.lua:324 prefers quality 1, AmmoBuy.lua:442 tier filter), so the QoL sweep never sells them.
- Conjured items are white and have no value, so neither path sells them.
- The **Bags Junk Marker** path is different: it sells marked item IDs of any quality (Bags_Categories:1049-1056, Bags:4067-4088). See SQ-3.

**Bag slots.**
- Junk sales free slots, and our `Room` re-reads free slots at each step (AmmoBuy.lua:127-151).
- Ellesmere needs no slots for repair or selling.
- Our default `leaveFree=2` (AmmoBuy.lua:80) also covers FHK Gear's one-free-slot rule for two-hand swaps (Actions.lua:91-97). Leave Free 0 can block that swap (nice).

**Server limits.** QoL states the server drops sell requests past a rate limit (QoL:1028-1031). Bags sells one item every 0.08 s (Bags:4171-4172). Whether buys share that limiter is a **probe**. A dropped `BuyMerchantItem` today ends as "added nothing", the item is skipped for 60 s (AmmoBuy.lua:281-283, 302-313), and is folded into SQ-1.

### 2. Trainer

- **Hook.** Train All calls the global `BuyTrainerService(i)` (QoL:905-917), so our `hooksecurefunc` (AutoTrain.lua:113-116) still sees it on main. `Try` defers 0.5 s after a foreign buy (AutoTrain.lua:126).
- **Double buying.** Possible only while our purchase is in flight when Train All is clicked. Each spell is capped at 2 attempts. Whether the server rejects a duplicate learn is a **probe** (SQ-10).
- **Gossip.** QoL Auto Select Single Gossip (QoL:1380-1412) and Blizzard's own `selectOptionWhenOnlyOption` (GossipFrameShared.lua:195-198) both select a lone option. Ours selects it too (SQ-5).
- **Quests at trainers.** All three back off when the NPC offers quests (AutoTrain.lua:101-102, QoL:1398-1405, EQT-QoL:79-117), so they agree there.

### 3. Quests

- **Rewards.** EQT turns in only when `GetNumQuestChoices() <= 1` (EQT-QoL:138-144). FHK Gear picks only when there is at least 1 choice (Equipment.lua:446-447, Actions.lua:243-264). The two overlap at exactly one choice (SQ-4).
- **QuestBar vs tracker.** EQT's quest-item key is an override binding that defaults to none. If the player picks one of our bar-8 keys, it outranks ours (SQ-17).

### 4. Buff reminders

- **Weapon enchants.** On Forever, ABR runs only the Forever raid buffs (MotW, Battle Shout, Fortitude, Arcane Intellect), Camp and custom IDs (ABR:4638-4648, 1368-1378, 4297-4329). Consumables, pets and therefore weapon enchants are retail-only (ABR:4668, 4675). So nothing duplicates WeaponEnchants.
- **Class buffs.** ClassBuffs does duplicate ABR's caster-side raid buff reminders inside instances (SQ-7).
- **Player Aura Bars** show the same enchant and imbue timers as our pods (UnitFrames_PlayerAuraBars:2861, EUI_UnitFrames_ForeverImbues.lua). That is duplicate display only (SQ-15).

**Coexistence rules:**
1. Ellesmere owns group raid-buff coverage.
2. Our ClassBuffs owns self-buff upkeep and the click-to-cast buttons. Silence our cue (keep the button) for the four ABR families while ABR would show them here.
3. Our pods own weapon enchant reminders and clicks. Player Aura Bars stays a passive timer, and any hide is offered as a button, never automatic.

### 5. Errors and alerts

- **Error frame.** BlizzardSkin does not skin, move or re-font `UIErrorsFrame` on main. The only references are `AddMessage` calls (SocketPanel:257/547/1219).
- QoL Hide Error Messages swaps `UIErrorsFrame`'s OnEvent (QoL:3969-3990).
- We move and re-font the frame and use `SetMessageTypeEnabled` (Warnings.lua:154-197, 204-219, 251-272). The two coexist; the one leak is SQ-11.
- **Warning lane.** By default the lane rides Ellesmere's durability-warning anchor (Warnings.lua:337-348, QoL:3212-3216). The critical lane is centre-anchored. Both share screen space with ABR's icon anchor (SQ-6).

### 6. Bags

- **Overlay API.** Unchanged on main (Bags:3488-3514). `_textOverlay` exists in grid and list (Bags:2409, 3286; Bags_List:226). The `RefreshInventory` method we hook still exists. Hooks are valid.
- **Z-order.** Our marker texture sits on `_textOverlay`, a child frame above the button. Junk coin (`btn` OVERLAY 6, BOTTOMLEFT; Bags_Grid:132-146) and quest marker (`_textOverlay` OVERLAY 6, BOTTOMLEFT; Bags_Grid:372-381) sit at the same corner. Only a player-chosen BOTTOMLEFT marker position overlaps them (SQ-16).
- **Close bags.** Still valid. Bags has no auto-close of its own on main, hooks `OpenAllBags` (Bags:7374) and replaces `ToggleAllBags` (Bags:7326). One edge case is SQ-13.

### 7. Combined cost

See SQ-14. Ellesmere has no MERCHANT_UPDATE handler on main (grep). Ours are AmmoBuy.lua:346 and ClassStock.lua:608.

## Findings

### SQ-1: a junk sale's bag event settles our purchase as "added nothing" (must)

**Where (ours):**
- AmmoBuy.lua:271-284: buy, then `s.waiting`
- AmmoBuy.lua:302-313: `E.Settle`
- AmmoBuy.lua:344-345: any BAG_UPDATE_DELAYED settles

**Where (Ellesmere):**
- QoL:1336-1337: sweep starts synchronously at MERCHANT_SHOW
- QoL:1114: `SellAllJunkItems`, re-passes every 0.4-1.6 s
- QoL:1123-1131: Junk Marker route
- Bags:4096-4177: one `UseContainerItem` every 0.08 s
- QoL:1236-1290: guild repair holds the sweep up to 0.5 s, then releases it mid-restock

**Scenario.** The player has two grey items and Vendor Restock is on.
1. The sales go out at MERCHANT_SHOW.
2. Our ammo buy goes out one frame later.
3. The sale's BAG_UPDATE_DELAYED arrives first.
4. `Measure` is unchanged, so the arrows are skipped for 60 s and the ammo category stops with "a purchase added nothing ... another addon".
5. The arrows do arrive, but the fill pass never runs.

With the Bags sweep (one sale per 0.08 s), this is near-certain on any visit that sells junk.

**Fix.** On BAG_UPDATE_DELAYED, settle only when `after > before`. Otherwise keep waiting, and let the existing 3 s timer be the only "no gain" verdict. Optionally retry once on a timeout if `GetMoney()` did not fall, to cover a dropped buy.

**Test.** Yes, E2. In AmmoBuyTests, fire an unrelated BAG_UPDATE_DELAYED before the stock rises. Expect no skip and the fill pass to continue.

### SQ-2: a sale's MERCHANT_UPDATE uses up our one late-data retry (should, probe)

**Where:**
- Ours: AmmoBuy.lua:314-320 (`Retry` sets `s.retried` and empties `pending`), AmmoBuy.lua:346-347 (any MERCHANT_UPDATE calls `Retry`).
- Ellesmere: the junk sweep (QoL:1337, Bags:4171).

**Scenario.**
1. The vendor's item data is not cached at MERCHANT_SHOW, so a planner is pending.
2. A junk sale updates the buyback list, which fires MERCHANT_UPDATE (probe).
3. That runs `Retry` before the data arrives.
4. The 0.6 s retry then returns early, and food is silently skipped for the visit.

**Fix.** On MERCHANT_UPDATE, try `Begin` only for pending planners and keep the ones that still fail. Set `retried` only in the 0.6 s timer.

**Test.** Yes, E2.

### SQ-3: Junk Marker sells items Restock buys (should)

**Where:**
- Ours: AmmoBuy.lua:236-256 (`Guard` has no junk check).
- Ellesmere: Bags_Categories:1049-1056 (a marked item ID is junk at any quality), Bags:4067-4088 (gathered at MERCHANT_SHOW).

**Scenario.**
1. The player marked an outgrown food or pet-food ID as junk, and Restock or PetFood still buys that ID.
2. The purchase merges into the gathered junk stack, and the sweep sells the whole stack, fresh units included.
3. `Measure` drops, which compounds SQ-1.
4. The next visit buys the item again. The result is a money loop.

**Fix.** In `Guard`, skip an offer when `EUI_CategoryManager and EUI_CategoryManager:IsJunkMarkerEnabled() and EUI_CategoryManager:IsJunk(o.id)`. Say once per visit: "marked as junk in Ellesmere Bags".

**Test.** Yes, E2.

### SQ-4: both addons hand in a quest with exactly one reward choice (should, probe)

**Where:**
- Ellesmere: EQT-QoL:138-144 (`GetQuestReward(numChoices)` when there are 0 or 1 choices).
- Ours: Actions.lua:243-264, Equipment.lua:446-470 (a single choice is picked as an upgrade or for vendor value).

**Scenario.**
- With EQT Auto Turn-In on, both send `GetQuestReward(1)` in the same QUEST_COMPLETE. The server reply to the second call is a probe.
- If the player turned off EQT's "Shift skip", holding Shift no longer stops the hand-in, although our tooltip promises Shift leaves the choice to the player.

**Fix.** In `Quest()`, when `GetNumQuestChoices() == 1` and `_G.EllesmereUIQuestTracker.Cfg('enabled') ~= false and Cfg('autoTurnIn')`, mark the reward only and let EQT hand in.

**Test.** Yes, E2 (FHKGear `tests/run.js`).

### SQ-5: the trainer option is selected two or three times (should, probe)

**Where:**
- Ours: AutoTrain.lua:95-106, and AutoTrain.lua:167-175 (`OnTrainer` calls `End()` and resets `attempts`).
- Ellesmere: QoL:1380-1412.
- Blizzard: GossipFrameShared.lua:195-198.

**Scenario.**
1. A trainer has one gossip option.
2. Blizzard, QoL and we each select it.
3. A second TRAINER_SHOW (probe) restarts our session while a purchase is in flight.
4. The reset `attempts` can buy that rank again.

**Fix.** In `T.OnGossip`, return when `#options == 1` and either `option.selectOptionWhenOnlyOption` is set or `EllesmereUIDB.autoGossip` is on.

**Test.** Yes, E2.

### SQ-6: the warning lane overlaps ABR icons (should, probe)

**Where:**
- Ours: Warnings.lua:337-348 (rows grow down from Ellesmere's durability anchor at about centre +227), Warnings.lua:389 (the combat lane grows up from centre +150).
- Ellesmere: ABR:2199-2204 and 5128-5140 (icons centred at centre +200).

**Scenario.** In a dungeon (ABR's default for raid buffs), "Low ammo" or the critical lane draws over the Fortitude reminder icon.

**Fix.** When ABR is loaded and `display.remindersEnabled`, start the lane below ABR's anchor minus its icon size, or cap the critical lane's top under it. A probe is needed for the real icon size.

**Test.** No, use an in-game probe.

### SQ-7: ClassBuffs duplicates ABR Forever raid buffs (should)

**Where:**
- Ours: ClassBuffs.lua:61-62, 77-78, 94, 101-102.
- Ellesmere: ABR:4504-4568 (caster path: shows when the player or group lacks the buff), ABR:2237-2250 (on by default, open world off).

**Scenario.** A mage in a dungeon sees both "Arcane Intellect" cues.

**Fix.** Apply coexistence rule 2: silence the cue only, read-only, with a toggle.

**Test.** Yes, E2.

### SQ-8: the repair bill may be double-counted the other way (nice, probe)

**Where:** AmmoBuy.lua:153-157, 332. Ellesmere repairs first (QoL:1331).

**Scenario.** If the client clears `GetRepairAllCost` before `GetMoney` drops, the budget ignores the bill and can dip into Keep At Least.

**Fix.** Probe first. If confirmed, defer the budget to the first PLAYER_MONEY or 0.5 s.

### SQ-9: our early buys corrupt Ellesmere's guild-repair report (nice)

**Where:** QoL:1236-1290 (counts every debit in the first 0.5 s as the player's share).

**Effect.** Chat says "Repaired for X" without "(guild bank)". This is a wording problem only.

**Fix.** Delay our first step 0.6 s when `CanGuildBankRepair()` and Ellesmere auto-repair are both on.

### SQ-10: duplicate buys with Train All (nice, probe)

Already bounded by the 0.5 s hook and 2 attempts per spell. No change needed.

### SQ-11: our released error bypasses Ellesmere's hide (nice)

**Where:** Warnings.lua:260 calls `AddMessage` directly, so it skips QoL:3969.

**Fix.** Skip the re-show when `EllesmereUIDB.hideErrorMessages` is on.

### SQ-12: auto-equip at a merchant stops the Bags sweep (nice)

**Where:** Actions.lua:117-121 (a BoE bind prompt can hold the item on the cursor up to 15 s). Bags:4160 stops selling while the cursor holds an item.

**Fix.** `QueueEquip` waits while a merchant is open.

### SQ-13: closing bags while the UI is hidden re-opens them (nice)

**Where:** LevelingQoL.lua:302 tests `IsShown`, but `ToggleEUI` (Bags:7258) tests `IsVisible`. With Alt+Z, the toggle shows the bags again.

**Fix.** Require `IsVisible` too.

### SQ-14: combined cost during a restock (nice, probe)

- **Per purchase or sale:** Bags refresh, coalesced to 0.1 s (Bags:7526-7531). Our `RefreshInventory` hook, coalesced to 0.2 s, runs two bag scans (Markers.lua:250-266, 228-234). FHK Gear's BAG_UPDATE_DELAYED handler runs `QueueEquip` at 0.3 s, one more scan (Core.lua:308-316).
- **Other handlers:** ModernChrome waits 0.5 s, Warnings runs next frame, PetFood only invalidates. All bounded.
- **MERCHANT_UPDATE:** ClassStock re-reads up to 200 offers on every event (ClassStock.lua:570-576, 608). Coalesce it with a 0.2 s timer.
- **Probe** the frame time on a 12-grey visit.

### SQ-15: duplicate weapon-enchant timers (nice)

Player Aura Bars weapon cells and our pods show the same timers. Offer a button to hide the Player Aura Bars row, never automatically (Ship features rule).

### SQ-16: FHK Gear markers on main (nice)

Hooks are valid on main. Only a BOTTOMLEFT marker overlaps the junk coin or quest marker. A note in the options is enough.

### SQ-17: QuestBar keys vs the EQT quest-item key (nice)

**Where:** EQT-QoL:208-260 (override binding) vs QuestBar.lua:6.

**Fix.** Warn when EQT's `questItemHotkey` is one of our `SLOT_KEYS`.
