# Adversarial review 2: warnings and training (2026-10-06)

Read-only review, evidence E1 (static reading only). Nothing here was run in game. Items marked
**probe** need an in-game check before anyone acts on them.

Scope (all in `Interface/AddOns/FHKEllesmere/`): `Warnings.lua`, `HunterCues.lua`, `PetElements.lua`,
`RankNotifier.lua` + `ClassTrainingData.lua`, `AutoTrain.lua`, `TalentPlanner.lua`. Also read for
context: `Bootstrap.lua` (`NS.EllesmereAway`), `Profiles.lua` (Resync, PROFILE_KEYS), `AGENT_BRIEF_CLASS_KITS.md`.

APIs checked against Forever UI source (the api-audit clone):
- `GetTrainerServiceInfo` returns name, type, texture, reqLevel, subText (Blizzard_TrainerUI.lua:634). Both callers read it correctly.
- `C_Trainer.GetTrainerType` exists. Its enum: General 0, Tradeskills 2, Pet 3.
- `IsTradeskillTrainer` exists.
- `UnitUsesAmmo` is documented.
- `GetPetActionInfo` returns 7+ values (PetActionBar.lua:110).
- `C_ClassTalents.HasUnspentTalentPoints` returns (bool, class, spec).
- `TraitNodeInfo` has both `activeRank` and `currentRank`.
- `EUI.ApplyModuleFont(fs, fontPath, size, moduleKey, flags)` matches the call. `BuildAlertSoundTables` returns literal data, so caching it is safe.

## Findings

### R2-1: Ammo total cache is wiped by every Flush, so a full bag scan runs on every combat aura or health event (should, high)
- **Where:** Warnings.lua:1003 (wipe in `Flush`), 619-642 (`TotalAmmo`), 668 (call).
- **Scenario:** A default hunter (ammo=true and tranq=true are both on by default) has fewer than 200 arrows. In combat, each `UNIT_AURA` on the player or target queues a Flush. Each Flush clears `totalCache`, so `CheckAmmo` walks every bag slot. Each slot costs a `GetContainerItemInfo` table plus a `GetItemInfoInstant`. This repeats several times a second. The comment on the cache ("until the bags or the equipment change") is not what the code does.
- **Fix:** Clear `totalCache` only in `driver` OnEvent for `BAG_UPDATE_DELAYED`, `PLAYER_EQUIPMENT_CHANGED`, `UNIT_INVENTORY_CHANGED`(player) and `PLAYER_ENTERING_WORLD`, not in `Flush`.
- **Test:** Yes. Low ammo plus 5 UNIT_AURA flushes should give at most one bag scan.

### R2-2: The combat lane can stay stuck above the character, or never move there (should)
- **Where:** Warnings.lua:453-454 (paint cache), 1011-1022.
- **Scenario:** Layout runs only when Show repaints or when Hide runs. The paint cache compares size, but not which lane the row is in. A critical row (for example "Ammo Slot Empty") is re-shown on `PLAYER_REGEN_ENABLED`. If `CentreSize()==WarnSize()`, Show returns early and Layout never runs. That happens with Ellesmere's durability text at 22 or less, or with Warning Text Style on and both sizes equal.
- **Result:** The row stays above the character after combat. The reverse also happens: a critical row shown out of combat never moves to the centre lane in combat. Rows owned by other modules that are not re-shown on REGEN have the same problem.
- **Fix:** Add `centre=CentreLane()` to `warningPaint`. Simpler: in OnEvent, for `PLAYER_REGEN_ENABLED`/`DISABLED`, set `row.warningPaint=nil` for every row and call `Layout()` after Flush.
- **Test:** Yes. Equal sizes, a critical row, then a combat-to-out-of-combat transition: the row should re-anchor to the container.

### R2-3: The Auto Train class filter skips class-trainer skills that are not in the data: Dual Wield, Mail, Plate Mail, Pick Lock (should)
- **Where:** AutoTrain.lua:37-60, 122-123, 140-143. ClassTrainingData.lua has none of these names; grep found no Dual Wield, Mail, Plate Mail or Pick Lock.
- **Scenario:** A hunter or warrior at 20 (Dual Wield), a hunter or shaman at 40 (Mail), a warrior or paladin at 40 (Plate Mail), a rogue at 16 (Pick Lock). The generator keeps only class skill lines, so these services count as "not class spells" and are left unbought. The chat line then blames "Weapon Masters Too is off".
- **Impact:** This regresses the old behaviour ("every General service trained") on class trainers.
- **Fix:** Filter only when the trainer is a weapon master. That is, skip the filter if any available service matches the class set (`ClassSpell`). Alternatively, add an allow-list for armour and weapon proficiencies.
- **Test:** Yes: a mock trainer with 'Arcane Shot' plus 'Dual Wield' buys both, and a weapon-master mock buys neither. Whether these skills are listed at the class trainer is a **probe**.

### R2-4: "Profession Trainers Too" can learn a whole new profession without the confirm dialog (should)
- **Where:** AutoTrain.lua:162-172; compare Blizzard_TrainerUI.lua:882 (`CONFIRM_PROFESSION`).
- **Scenario:** With professions on, the player talks to a Blacksmithing trainer just to browse. The "Apprentice Blacksmith" service is `available`, so `BuyTrainerService` learns it. That spends a profession slot without Blizzard's confirmation.
- **Fix:** At a tradeskill trainer, skip a service whose profession is not yet known. Or train only when `GetTrainerServiceStepIndex()` is nil or the profession is already known. Or skip names matching `^Apprentice `.
- **Test:** Yes. **Probe:** check the Forever service names.

### R2-5: Demonic Sacrifice detection by aura name can silence warlock pet warnings for good (should, probe)
- **Where:** Warnings.lua:848-866.
- **The names:** 'Fel Intellect' is not a sacrifice buff in Classic. The sacrifice buffs are Burning Wish, Fel Stamina, Touch of Shadow and Fel Energy. 'Fel Stamina' and 'Fel Intellect' are also Demonology talent names.
- **Scenario:** If the talent passives are returned by `GetAuraDataBySpellName('player',...)`, a warlock with either talent reads as "sacrificed". "Summon Demon" then never shows. The match is also English-only.
- **Fix:** Use spell IDs 18789, 18790, 18791 and 18792 through `C_UnitAuras.GetPlayerAuraBySpellID`, and drop 'Fel Intellect'.
- **Test:** Yes: the talent-named aura alone should not count as sacrificed.

### R2-6: Talent Planner commit: result unchecked, possibly the wrong API, and it may commit the player's own staged picks (should, probe)
- **Where:** TalentPlanner.lua:156-159.
- **Unchecked result:** `CommitConfig` is not checked. If it fails, chat still says "Learned X", and the staged ranks stay pending.
- **Wrong API:** Forever's own class talent frame commits with `C_ClassTalents.CommitConfig(configID)` (Blizzard_ClassTalentsFrame.lua:1171-1177), not `C_Traits.CommitConfig`.
- **Player's picks:** When `ConfigHasStagedChanges` is true, any picks the player staged in the Blizzard frame are committed too.
- **Fix:**
  - At the start of `Learn`, skip if `ConfigHasStagedChanges` is already true.
  - Commit through `C_ClassTalents.CommitConfig`, falling back to `C_Traits`.
  - On failure, call `C_Traits.RollbackConfig` and say so.
- **Test:** Yes (mock a failing commit).

### R2-7: Talent Planner may buy extra ranks of one talent (probe)
- **Where:** TalentPlanner.lua:59, 112, 133-155.
- **Scenario:** `node.rank` is read from `activeRank`. If `activeRank` excludes staged purchases, then after `PurchaseRank` the next loop pass returns the same pick and buys rank 2 instead of the next planned talent.
- **Check in game:** Have 2 points free and a plan of A(1/3) then B. A should end at 1/3 and B should be learned.
- **Fix if confirmed:** Use `currentRank`, or count the purchases made in this pass.

### R2-8: The Out of Ammo away state is never re-checked on mount, dismount or resurrection (should)
- **Where:** Warnings.lua:685, 1032-1033.
- **Scenario:** `CheckAmmo` hides act-now ammo while mounted or dead (`AwayFor('act')`). But `AMMO_EVENTS` has no mount, control or alive events. When pet warnings are off (the default):
  - mounting or taking a taxi leaves "Out of Ammo" on screen;
  - after dismounting or resurrecting, it stays hidden until a bag or combat event.
- **Fix:** Add `PLAYER_MOUNT_DISPLAY_CHANGED`, `PLAYER_CONTROL_GAINED`/`LOST`, `PLAYER_ALIVE` and `PLAYER_UNGHOST` to `AMMO_EVENTS` (each `Valid()`).
- **Test:** Yes.

### R2-9: Switching profile does not re-apply the error line and the spam filter (should)
- **Where:** the Profiles.lua Resync list, and Warnings.lua:1048-1068.
- **Scenario:** `SyncEllesmereWarnings` runs on a profile switch, but `SyncEllesmereErrorText` and `SyncEllesmereErrorFilter` do not. When profiles differ in `errorRaise` or `errorFilter`, the game error line keeps the old profile's position and filtering.
- **Fix:** Call both at the end of `NS.SyncEllesmereWarnings`.
- **Test:** Yes.

### R2-10: New Spell Sound "None" still plays the lane sound (should)
- **Where:** RankNotifier.lua:272, 488; Warnings.lua:427-431.
- **Scenario:** 'none' is turned into nil, so Warnings falls back to the "Other Warning Sound". A player who set Other Warning Sound to Raid Warning and New Spell Sound to None still hears Raid Warning.
- **Fix:** Pass `cfg.sound` through unchanged ('none' now silences), and drop the extra alone-play branch when the sound is 'none'.
- **Test:** Yes.

### R2-11: Pet warning events are unfiltered, and a vivid preset adds a UIParent scan to every Flush (should)
- **Where:** Warnings.lua:1037, 1059, 1002, 91-100.
- **Unfiltered events:** `UNIT_HEALTH`, `UNIT_MAXHEALTH`, `UNIT_AURA` and `UNIT_FLAGS` are registered with `RegisterEvent`. In a raid, every member and nameplate wakes the handler.
- **UIParent scan:** Each Flush calls `SyncEllesmereNativeWarningOutline`. While the durability label is not found and a vivid preset is active, that runs `{UIParent:GetChildren()}`, a large table allocation per Flush.
- **Fix:**
  - Register those events with `RegisterUnitEvent(...,'player','pet')`, plus 'target' on a second frame where needed.
  - Move the native-outline sync out of `Flush` into its own durability, theme and login events.
- **Test:** Optional.

### Nice to have
- **R2-12:** TalentPlanner.lua:282-288 registers 5 events while the plan is off, against the brief's zero-cost rule. With auto on, `Learn` reads the whole tree on every `PLAYER_REGEN_ENABLED` even with no points. Gate on `HasUnspentTalentPoints` first.
- **R2-13:** RankNotifier.lua:380-394. At a weapon master (also a General trainer), chat suggests Auto Train, which then will not buy those skills.
- **R2-14:** AutoTrain.lua:37-60 matches English data names only. RankNotifier also indexes the client's names (`SpellName(e[1])`); AutoTrain should too.
- **R2-15:** Warnings.lua:1113-1114 compares `s.ammoCritical`/`s.ammoLow` without validating them. A corrupted string value raises an error. Add both keys to `LIMITS`.
- **R2-16:** AutoTrain.lua:24-25 lets a NaN `keepGold` pass validation, and then nothing is ever bought. Add `s.keepGold~=s.keepGold`.
- **R2-17:** Warnings.lua:1013 restarts the Pet Level notice on every loading screen (`PLAYER_ENTERING_WORLD`), not only at login.
- **R2-18:** PetElements.lua:351-355 keeps the pet-target ticker running at 4 Hz while the feature is on, even with no pet.
- **R2-19:** TalentPlanner.lua:125 `blockedNode` is never reset on Clear or plan edits.
- **R2-20:** AutoTrain.lua:64-67. Poison tiers ("Instant Poison III") are never `KnownName`, so they are ordered as new spells, not upgrades.
- **R2-21:** PetElements.lua:415 shows the Cleanse edge swatch to warlocks, but `dispel` is forced off for them.

## Checked and fine
- Lane override keys round-trip: `OVERRIDE_OF` maps feignResist to feign. Corrupted entries read as the default.
- Sound plays once, on arrival, with a 3 s throttle per key. No module calls `PlayEllesmereCueSound` beside Show.
- HunterCues hold times are clamped by LIMITS. The combat ticker stops on `REGEN_ENABLED`. Warlocks register only Pet Idle's events.
- AutoTrain retries a purchase at most twice per spell. `TRAINER_UPDATE` acts only while waiting. It skips pet trainers.
- RankNotifier is coalesced, defers in combat, and registers nothing while off.
- TalentPlanner never acts in combat (it checks at the start of `Learn`).
- PetElements touches secure attributes and unit watch only out of combat.
