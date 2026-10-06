# Class kits: in-game probes (E3 owed, 2026-10-06)

Everything below is E1/E2 so far. Run these in game. Record results in `IN_GAME_CHECKS.md` and the CHANGELOG.

## Class Buff Bar (`ClassBuffs.lua`)

1. **Charges:** `/run local a=C_UnitAuras.GetAuraDataBySpellName('player','Inner Fire','HELPFUL|PLAYER') print(a and a.applications,a and a.charges,a and a.expirationTime)`. Repeat for Lightning Shield. Note where the charges show up.
2. **Paladin auras readable as auras:** `/run print(C_UnitAuras.GetAuraDataBySpellName('player','Devotion Aura','HELPFUL|PLAYER'))`
3. **Omen of Clarity passive:** `/run print(C_Spell.IsSpellPassive('Omen of Clarity'))`
4. **Aura secrecy:** `/run print(C_Secrets.ShouldAurasBeSecret())`. Run once in combat and once out.
5. **No Seal:** a paladin auto-attacking with no seal sees NO SEAL. It clears when you seal or stop attacking.
6. **Self-cast with a friend targeted:** click a blessing or Fortitude button while a friendly target is selected. It should land on you, at the highest rank.
7. **Cancel aura:** right-click Righteous Fury or Shadowform. `/cancelaura` should remove the buff.
8. **Druid:** Cat Form hides the bar.
9. **New ranks:** after training a rank, the button updates (`LEARNED_SPELL_IN_SKILL_LINE` / `SPELLS_CHANGED`).

## Weapon Enchants (`WeaponEnchants.lua`)

1. **Enchant data:**
   - Probe: `/run for s=0,2 do for i,e in ipairs(C_Item.GetWeaponEnchantInfo(s) or {}) do print(s,i,e.hasEnchant,e.enchantType,e.timeLeft,e.charges,e.enchantID,e.enchantIconID) end end`
   - Expect timeLeft in ms and enchant types 2 or 3.
   - Expect Instant Poison enchant IDs 323-625, and Rockbiter 29 or 7568.
2. **Poisons skill:** `/run print(C_SpellBook.IsSpellKnown(2842))` is true once a rogue has learned Poisons.
3. **Applying an item:**
   - Clicking a pod with a poison or a sharpening stone applies it to slot 16 or 17 with no extra click.
   - Replacing an enchant shows the game's confirm.
4. **Shaman:** clicking the pod casts the imbue.
5. **`WEAPON_ENCHANT_CHANGED`** fires on apply and on expiry.
6. **Warlock stones:** Firestone and Spellstone apply as weapon enchants on Forever.
7. **Occult Poison** exists.

## Class Supplies (`ClassStock.lua`)

1. **Item names:** `/run for _,id in ipairs{6265,5512,19004,5232,5522,1254,17030,5140,5530,5060,7676,5350,8079,5349,22895,5514,8008,17031,17032,17056,17020,17033,21177,17028,17029,17034,17038,17021,17026,5565,16583} do print(id,C_Item.GetItemNameByID(id)) end`
2. **Soul bag:** with a soul bag, `/run for b=0,4 do print(b,C_Container.GetContainerNumFreeSlots(b)) end` reports bagFamily 4.
3. **Highest rank:** clicking Healthstone or Water casts the highest rank by name.
4. **Soulstone timer:** using a Soulstone on a party member starts the timer with their name.
5. **Equipped stone:** `/run print(C_Item.GetItemCount(13602),C_Item.IsEquippedItem(13602))`
6. **Forever rank by name:** `/run print(C_Spell.GetSpellInfo('Vanish').spellID)` with rank 3 trained.

## Class Cues (`ClassCues.lua`)

1. **Error listener:** use the CLASS_KITS error listener, then try each of these:
   - Backstab from the front
   - Ambush while unstealthed
   - Overpower in Defensive Stance
   - a potion in Bear Form
   - Shred in caster form

   The names are E1 against Forever GlobalStrings. Confirm the runtime `GetGameMessageInfo` names.
2. **Target of target in combat:** `/run print(UnitIsUnit('targettarget','player'))` is readable in combat.
3. **Holds:**
   - Gouge or Cheap Shot a mob, step behind it: the indicator shows neutral, not FRONT.
   - Backstab: BEHIND.
   - Is the target's stun aura readable in combat?
4. **Energy ticks:** `/run local f=CreateFrame('Frame') f:RegisterUnitEvent('UNIT_POWER_FREQUENT','player') f:SetScript('OnEvent',function(_,_,_,p) if p=='ENERGY' then print(GetTime(),UnitPower('player',3)) end end)`. Expect +20 every 2 s, and `ERB_PrimaryBar` to exist.
5. **Warrior data:**
   - `UNIT_COMBAT` payloads for DODGE / PARRY / BLOCK.
   - `GetShapeshiftFormID()` returns 17 / 18 / 19.
   - `IsSpellUsable('Overpower')` in the wrong stance.
6. **Victory Rush:** `/run print(C_Spell.GetSpellName(402927))`

## Customisability (agent G)

1. **Range Indicator shape cog:** switch the shape between Block, Icon and Bar; each cog row greys out when it doesn't apply. The eye previews.
2. **Swing Timer off:** its rows grey out with "requires Enable Swing Timer".
3. **Target of Target:** an enemy attacking your pet turns the target-of-target bar green.
4. **XP bar:** the tick and glow opacity settings update the bar live.
5. **Section resets:** each Reset button confirms first and changes only its own section.

## FHK Gear 0.5.3

1. **Spec detection:**
   - `/dump C_SpecializationInfo.GetSpecialization(), C_SpecializationInfo.GetSpecializationInfo(1)` on a talented non-hunter.
   - Check the status line.
2. **Shift to choose:** hold Shift as a quest reward window opens. No pick should happen.
3. **Bind on Equip Only:** a soulbound blue quest reward with Bind on Equip Only on gets equipped.
4. **Level hint:** an item 5 or more levels above you shows "upgrade at level N".
5. **Group rolls:**
   - roll rules on;
   - Non-Gear Loot Rolls on Greed, then Need;
   - Bind on Equip Up To.
6. **Hunter spell check:** `/dump C_SpellBook.IsSpellKnown(1515)` on a hunter, before and after level 10.
7. **Color-Blind Markers:** apply them.
8. **Disable AutoGear:** check the dialog text.

## New Spell Alerts (`RankNotifier.lua`, `ClassTrainingData.lua`)

1. **Rogue Poisons skill:** `/run local i=C_SkillInfo.GetSkillLineInfoByID(40) print(i and i.rank,i and i.maxRank)` and `/run print(C_SpellBook.IsSpellKnown(8681),C_SpellBook.IsSpellKnown(8687))` (poison recipes report as known).
2. **Rogue trainer:** `/run for i=1,GetNumTrainerServices() do local n,k,_,l,s=GetTrainerServiceInfo(i) local _,r=GetTrainerServiceSkillReq(i) if n and n:find('Poison') then print(n,s,k,l,r) end end`. This checks the name format and the Poisons-skill estimate (5 x level - 20).
3. **Alerts on level-up:** turn the alerts on, then level up and check the lane cue and the chat list. Visit a trainer, then run `/run for _,n in ipairs(FHKEllesmereNS.RankNotifier.Notes()) do print(n) end`.
4. **Data differences to settle at trainers:**
   - Berserker Rage level: 32 in the client, 30 on ForeverDB.
   - Whether Sunder Armor 1, Intercept 1 and the rank-1 totems are sold (the client teaches them by quest).
   - Touch of Weakness on an Undead priest.
   - Whether the Season of Discovery poisons (Numbing, Atrophic, Sebacious, Occult) are sold.

## Pets, warnings and ammo (agent F)

1. **Pet On Passive:** set the pet to Passive in combat, as a hunter and as a warlock. Check `/run for i=1,10 do print(i,GetPetActionInfo(i)) end`.
2. **Demonic Sacrifice aura names on Forever:** Touch of Shadow, Burning Wish, Fel Stamina, Fel Energy, Fel Intellect.
3. **At an ammo vendor:**
   - `/dump C_MerchantFrame.GetItemInfo(i)`
   - `/run print(GetMerchantItemMaxStack(i))`
   - `/run print(C_Item.GetItemFamily(2515))`
   - `/run print(C_Container.GetContainerNumFreeSlots(<quiver bag>))`

   Expect family bits of 1 for a quiver and 2 for an ammo pouch.
4. **Not Shooting** after Disengage or Scatter Shot.
5. **Warning text shadow:** check it with Ellesmere's outline set to None and to Drop Shadow.
6. **Paladin:** does Judgement fire `UNIT_SPELLCAST_SUCCEEDED` with a "Judgement" name (seal grace)? Is `IsResting()` true in an inn and false in a dungeon?

## Adversarial round 2 probes

1. **Talent Planner:** with 2 free points and a plan of A (1/3) then B, A should stop at 1/3 and B should be learned (activeRank and staged ranks). Also check that the commit goes through C_ClassTalents with no extra confirmation.
2. **Profession trainer:** with "Profession Trainers Too" on, the new profession ("Apprentice ...") is never learned automatically. Check the Forever service names.
3. **Class trainer:** Dual Wield, Mail, Plate Mail and Pick Lock are sold there and get trained.
4. **Weapon enchant list shape:** `/dump C_Item.GetWeaponEnchantInfo(0)` (list or keyed).
5. **Warrior error text:** the `ERR_SPELL_FAILED_SHAPESHIFT_FORM_S` text in each case.
6. **Death checks:** `UnitIsDeadOrGhost('player')` during Feign Death (should be false). Is `PLAYER_MOUNT_DISPLAY_CHANGED` valid on Forever?
7. **Pet and mount item classes:** `/dump GetItemInfoInstant(8485)` (pet carrier) and `/dump GetItemInfoInstant(13335)` (mount). These should report class 15 with subclass 2 for the pet and 5 for the mount.

## Suite review on Ellesmere main (9.3.9) probes

1. **Glow (SF-12):** does Forever show its own proc glow on Overpower or Mongoose Bite? If it does, our reactive glow doubles it.
2. **Pet-target button anchor (SF-13):** does the pet-target secure button, anchored to Ellesmere's pet health bar, cause `ADDON_ACTION_BLOCKED` in combat?
3. **Frames created in combat (SF-14):** reload in combat and watch for taint from child frames we create on secure unit frames.
4. **Micro buttons (ModernChrome):** watch for Edit Mode taint after we re-parent the micro buttons.
5. **Merchant order (SQ-1/SQ-8):**
   - With Ellesmere auto repair and junk selling on, a restock visit buys every category in full.
   - A guild-paid repair does not block purchases.
6. **Warning lanes and buff icons (SQ-6):** with Ellesmere Aura Buff Reminders on, our lanes clear its icons. Check the real icon size and scale.
7. **Raid buffs in dungeons (SQ-7):** inside a dungeon, as a mage without Arcane Intellect, only Ellesmere's reminder shows. In the open world, ours shows.
8. **One-reward quests (SQ-4):** with Ellesmere Quest Tracker auto turn-in on, a one-reward quest is handed in once.
9. **Profile switch in combat (SC-7):** switch profiles with the keybind in combat. Features update when combat ends, with no error.
10. **Reset ALL (SC-1):** after Ellesmere Reset ALL, no old bag/menu visibility or theme comes back by itself.
