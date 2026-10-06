-- FHK Gear 0.5.3 (class kits row H): review items G1-G4, G9-G14 and D8. Mocked (E2); no in-game claim.
local h=...
local ns,eq=h.ns,h.eq
local E=ns.Engine
local opt=h.options
local timers={}
C_Timer.After=function(delay,fn) timers[#timers+1]={due=h.time()+delay,fn=fn} end
local function Advance(seconds)
    h.setTime(h.time()+seconds)
    for _=1,100 do
        local nextIndex
        for i,t in ipairs(timers) do if t.due<=h.time() then nextIndex=i;break end end
        if not nextIndex then return end
        local timer=table.remove(timers,nextIndex);timer.fn()
    end
    error('Unbounded due timer work')
end
local function Reset()
    h.setCursor(nil);h.setBags({});h.setEquipped({});h.setChoices({});h.clearReward();h.setLevel(20);h.setNeed(true)
    ns.ResetSettings();ns.Items.Invalidate();ns.Engine.Invalidate();timers={}
    -- Stat weights, not the live Hunter model the earlier suites leave available: fixed fixture scores.
    ns.Char().source='weights';ns.Changed()
    ns.Account().imported=nil;ns.Account().weights=nil;ns.Weights.Invalidate()
end
local function Item(id,loc,stats,extra,classID)
    h.ITEMS[id]={'Fixture ' .. id,loc,classID or 2,stats or {},extra or {}}
    return 'item:' .. id
end
local function Rows(page)
    h.clearRows();h.spec.modules[1].buildPage(page,{},0)
    local out={}
    for _,r in ipairs(h.getRows()) do for _,cfg in ipairs(r) do if type(cfg)=='table' then out[#out+1]=cfg end end end
    return out
end
local function Find(cfgs,text,field)
    for _,cfg in ipairs(cfgs) do if cfg[field or 'text']==text then return cfg end end
end
local function Has(text,part) return type(text)=='string' and text:find(part,1,true)~=nil end

-- Defaults: every new setting is off, and adds no events --------------------------------------------
Reset()
local d=ns.CHAR_DEFAULTS
eq(d.rollMinGain,0,'G2: Minimum Need Gain defaults to 0 (off)')
eq(d.rollNeedArmorType or d.rollNeedMainStat or d.rarityCapBoEOnly,false,'G2/G4: new rules default off')
eq(d.rollNonGear,'player','non-gear loot is the player\'s roll by default')
eq(d.rollNonGearMaxQuality==2 and d.equipBoEMaxQuality==2,true,'non-gear and Bind on Equip caps default to Uncommon')
eq(next(ns.Char().textColours),nil,'G12: no custom text colors by default')
local c=ns.Char()
c.rollNeedArmorType,c.rollNeedMainStat,c.rollNonGear,c.rarityCapBoEOnly,c.rollMinGain=true,true,'greed',true,20;ns.Changed()
eq(h.core.events.START_LOOT_ROLL,nil,'zero cost: roll rules alone register no loot events')
eq(h.core.events.EQUIP_BIND_CONFIRM,nil,'zero cost: the BoE-only rarity cap alone registers no equip events')
-- Corrupted saved values reset; a later SavedVariables table rebinds.
local saved=FHKGearCharDB
FHKGearCharDB={rollMinGain='lots',rollNeedArmorType=1,textColours='red',rarityCapBoEOnly=true}
local bad=ns.Char()
eq(bad.rollMinGain,0,'corrupt: a non-number Minimum Need Gain resets');eq(bad.rollNeedArmorType,false,'corrupt: a non-boolean toggle resets')
eq(type(bad.textColours),'table','corrupt: text colors become a table');eq(bad.rarityCapBoEOnly,true,'corrupt: valid saved settings survive')
-- Upgrade from 0.5.2 (player, 2026-10-06: "non gear loot should not default to auto greed think mounts
-- or whatever it should be a player roll or need"): Greed on Other Loot no longer covers it.
FHKGearCharDB={autoRoll=true,rollGreedOthers=true}
eq(ns.Char().rollNonGear,'player','migration: Greed on Other Loot does not turn on non-gear rolls')
FHKGearCharDB={autoRoll=true,rollGreedNonGear=true}
local migrated=ns.Char()
eq(migrated.rollNonGear,'greed','migration: a test build\'s Greed on Non-Gear Loot carries over')
eq(migrated.rollGreedNonGear,nil,'migration: the old key is removed')
FHKGearCharDB={rollGreedNonGear=false}
eq(ns.Char().rollNonGear,'player','migration: off stays Player Roll')
FHKGearCharDB={rollNonGear='bogus',rollNonGearMaxQuality=9,equipBoEMaxQuality=2.5}
local fixed=ns.Char()
eq(fixed.rollNonGear=='player' and fixed.rollNonGearMaxQuality==2 and fixed.equipBoEMaxQuality==2,true,'corrupt: bad non-gear mode and caps reset')
FHKGearCharDB={}
eq(ns.Char().rollNonGear,'player','migration: a new character starts on Player Roll')
FHKGearCharDB=saved;ns.Char();Reset()

-- G1: spec on the status line, and rogue "None" means any weapon ----------------------------------
local name,how=ns.Weights.SpecLabel()
eq(name,'No Spec','G1: no detected spec reads No Spec');eq(how,'no spec detected','G1: and says nothing was detected')
local specAPI=C_SpecializationInfo
C_SpecializationInfo={GetSpecialization=function() return 2 end,GetSpecializationInfo=function(i) return 254,i==2 and 'Marksmanship' or 'Other' end}
ns.Weights.Invalidate()
name,how=ns.Weights.SpecLabel()
eq(name,'Marksmanship','G1: the client specialization name is used');eq(how,'detected','G1: and labelled detected')
ns.Char().spec='Survival'
name,how=ns.Weights.SpecLabel()
eq(name,'Survival','G1: the Spec dropdown wins');eq(how,'chosen','G1: and is labelled chosen')
eq(Has(opt.StatusText(),'Weights: Survival (chosen)'),true,'G1: the status line names the weights in use')
local statusRow=Rows('Automation')[1]
eq(statusRow.type=='label' and Has(statusRow.text,'Weights: Survival (chosen)'),true,'G1: the Automation page status row shows it')
ns.Char().spec=nil
C_SpecializationInfo={GetSpecialization=function() error('restricted') end}
eq(select(2,ns.Weights.SpecLabel()),'no spec detected','G1: an unreadable spec API falls back to No Spec')
C_SpecializationInfo=specAPI;ns.Weights.Invalidate()
eq(ns.Weights.Defaults('ROGUE','None').weapons,'any','G1: rogue without a spec compares any weapon')
eq(ns.Weights.Defaults('ROGUE','Assassination').weapons,'dagger and any','G1: Assassination keeps its dagger preference')
local sword=ns.Items.Read(Item(530,'INVTYPE_WEAPONMAINHAND',{ITEM_MOD_AGILITY_SHORT=3},{subclass=7}))
eq(E.Slots(sword,ns.Weights.Defaults('ROGUE','None'))~=nil,true,'G1: a rogue with no spec may use a sword')
eq(E.Slots(sword,ns.Weights.Defaults('ROGUE','Assassination')),nil,'G1: an Assassination rogue keeps dagger main hand')
SlashCmdList.FHKGEAR('status')
local out=h.printed()
eq(Has(out[#out-1],'No Spec HUNTER (no spec detected)'),true,'G1: /fhkgear status says how the spec was found')

-- G2: roll etiquette --------------------------------------------------------------------------------
Reset();ns.Char().autoRoll=true;ns.Changed()
h.setRoll('item:9') -- Linen Cloth: not gear
local choice,why,info,up=E.RollChoice(1)
eq(choice,nil,'G2: non-gear loot is left to you by default');eq(why,'Non-gear loot: choose manually','G2: and says why');eq(up,false,'G2: never marked as an upgrade')
h.Fire('START_LOOT_ROLL',501,60000);eq(h.getRolled()[501],nil,'G2: no automatic roll on non-gear loot')
ns.Char().rollNonGear='greed';ns.Changed()
h.Fire('START_LOOT_ROLL',502,60000);eq(h.getRolled()[502],2,'G2: Non-Gear Loot Rolls: Greed rolls Greed')
local greedAPI=GetLootRollItemInfo;GetLootRollItemInfo=function() return nil,nil,nil,nil,nil,true,false end
eq(E.RollChoice(503),nil,'G2: non-gear Greed still needs the roll to allow Greed')
GetLootRollItemInfo=greedAPI
-- Need (player, 2026-10-06: "a toggle for auto need non loot rolls"): only where the roll allows Need.
ns.Char().rollNonGear='need';ns.Changed()
eq(E.RollChoice(510),1,'non-gear Need: rolls Need when allowed')
local needAPI=GetLootRollItemInfo;GetLootRollItemInfo=function() return nil,nil,nil,nil,nil,false,true end
eq(E.RollChoice(511),nil,'non-gear Need: a roll that forbids Need is your roll, never a silent Greed')
GetLootRollItemInfo=needAPI
ns.Char().rollNonGear='player';ns.Changed()
eq(E.RollChoice(512),nil,'non-gear: Player Roll leaves it to you')
-- Whatever the mode, what a player chooses for is never rolled for them (player, 2026-10-06).
local G=function(info) return E.NonGearAllowed(info,2) end
eq(E.NonGearAllowed({quality=3,classID=7,subclassID=5},3),true,'Non-Gear Up To Rare includes rare trade goods')
eq(E.NonGearAllowed({quality=4,classID=7,subclassID=5},3),false,'Non-Gear Up To Rare excludes epics')
eq(E.NonGearAllowed({quality=4,classID=15,subclassID=5},5),false,'a mount stays your roll at any cap')
eq(G({quality=1,classID=7,subclassID=5}),true,'non-gear Greed: plain cloth (trade goods) is greeded')
eq(G({quality=2,classID=0,subclassID=5}),true,'non-gear Greed: uncommon food is greeded')
eq(G({quality=3,classID=7,subclassID=5}),false,'non-gear Greed: rare or better is always your roll')
eq(G({quality=2,classID=15,subclassID=5}),false,'non-gear Greed: a mount is always your roll')
eq(G({quality=1,classID=15,subclassID=2}),false,'non-gear Greed: a companion pet is always your roll')
eq(G({quality=2,classID=9,subclassID=0}),false,'non-gear Greed: a recipe is always your roll')
eq(G({quality=1,classID=12,subclassID=0}),false,'non-gear Greed: a quest item is always your roll')
eq(G({quality=1,classID=13,subclassID=0}),false,'non-gear Greed: a key is always your roll')
eq(G({quality=1,classID=17}),false,'non-gear Greed: a battle pet is always your roll')
eq(G({quality=1,classID=15}),false,'non-gear Greed: an unknown miscellaneous item is your roll')
eq(G({classID=7}) or G({quality=1}) or G(nil),false,'non-gear Greed: unknown item data is your roll')
-- Minimum Need Gain: Hunting Bow (14) over Laminated Recurve Bow (11.54) is a 21% gain.
Reset();ns.Char().autoRoll=true;ns.Changed();h.setEquipped({[18]='item:1'});h.setRoll('item:2')
eq(E.RollChoice(504),1,'G2: Need on an upgrade with Minimum Need Gain at 0')
ns.Char().rollMinGain=25
choice,why=E.RollChoice(505)
eq(choice,2,'G2: a 21% gain below a 25% minimum is Greed');eq(Has(why,'Minimum Need Gain (25%)'),true,'G2: and names the rule')
ns.Char().rollGreedOthers=false
choice,why=E.RollChoice(506)
eq(choice,nil,'G2: without Greed on Other Loot it is left to you');eq(Has(why,'choose manually'),true,'G2: and says so')
ns.Char().rollGreedOthers=true;ns.Char().rollMinGain=20
eq(E.RollChoice(507),1,'G2: a 21% gain clears a 20% minimum')
ns.Char().rollMinGain=50;h.setRoll('item:5')
eq(E.RollChoice(508),1,'G2: filling an empty slot always clears the minimum')
-- Armor type: a level 20 Hunter wears Leather, Mail from 40. Cloaks never count.
Reset();ns.Char().autoRoll=true;ns.Changed()
local mail=Item(531,'INVTYPE_CHEST',{ITEM_MOD_AGILITY_SHORT=8},{subclass=3},4)
local leather=Item(532,'INVTYPE_LEGS',{ITEM_MOD_AGILITY_SHORT=8},{subclass=2},4)
local cloak=Item(533,'INVTYPE_CLOAK',{ITEM_MOD_AGILITY_SHORT=8},{subclass=1},4)
h.setRoll(mail);eq(E.RollChoice(510),1,'G2: armor type is not checked while the toggle is off')
ns.Char().rollNeedArmorType=true
eq(E.ArmorType(),2,'G2: a level 20 Hunter wears Leather')
choice,why=E.RollChoice(511)
eq(choice,2,'G2: Mail before 40 is Greed for a Hunter');eq(why,'Not your armor type (Leather)','G2: and says which type is yours')
h.setRoll(leather);eq(E.RollChoice(512),1,'G2: Leather is Needed at 20')
h.setRoll(cloak);eq(E.RollChoice(513),1,'G2: a cloth cloak is never an armor-type question')
h.setLevel(40);E.Invalidate()
eq(E.ArmorType(),3,'G2: Hunters wear Mail from 40')
h.setRoll(mail);eq(E.RollChoice(514),1,'G2: Mail is Needed at 40')
h.setRoll(leather);eq(E.RollChoice(515),2,'G2: Leather is Greed at 40')
h.setLevel(20)
local classAPI=UnitClass;UnitClass=function() error('restricted') end
eq(E.ArmorType(),nil,'G2: an unreadable class means no armor rule (never a wrong block)')
UnitClass=classAPI
-- Main stat: the highest of Agility, Strength and Intellect in the weights (Agility for a Hunter).
Reset();ns.Char().autoRoll=true;ns.Char().rollNeedMainStat=true;ns.Changed()
eq(E.MainStat(),'Agility','G2: a Hunter main stat is Agility')
eq(E.MainStat({Strength=2,Agility=1,Intellect=0.5}),'Strength','G2: the main stat follows the weights')
eq(E.MainStat({Stamina=1}),nil,'G2: no primary weight means no main stat rule')
h.setRoll(Item(534,'INVTYPE_HAND',{ITEM_MOD_STRENGTH_SHORT=12}))
choice,why=E.RollChoice(516)
eq(choice,2,'G2: Strength gloves are Greed for a Hunter');eq(why,'No Agility','G2: and the reason names the main stat')
h.setRoll(Item(535,'INVTYPE_WAIST',{ITEM_MOD_STAMINA_SHORT=12}))
eq(E.RollChoice(517),1,'G2: a Stamina-only item has no primary stat and is judged by score')
h.setRoll(Item(536,'INVTYPE_FEET',{ITEM_MOD_STRENGTH_SHORT=3,ITEM_MOD_AGILITY_SHORT=3}))
eq(E.RollChoice(518),1,'G2: an item with the main stat among others may be Needed')
ns.Char().rollNeedUpgrades=false
eq(select(2,E.RollChoice(519)),'Need on upgrades is off: choose manually','G2: the rules never act while Need on Upgrades is off')
-- Options rows: labels, and disabled until Auto-Roll and Need on Upgrades are on.
Reset()
local auto=Rows('Automation')
local minRow,nonGear,armorRow,mainRow=Find(auto,'Minimum Need Gain'),Find(auto,'Non-Gear Loot Rolls'),Find(auto,'Need Only My Armor Type'),Find(auto,'Need Only My Main Stat')
eq(minRow and nonGear and armorRow and mainRow and true,true,'G2: the four roll rules are on the Automation page')
eq(minRow.type,'slider','G2: Minimum Need Gain is a slider');eq(minRow.min==0 and minRow.max==50,true,'G2: from 0 to 50 percent')
eq(minRow.disabled(),true,'G2: rules are disabled while Auto-Roll is off');eq(minRow.disabledTooltip,'Need on Upgrades','G2: and name what they need')
eq(Has(armorRow.tooltip,'yours now: Leather'),true,'G2: the armor tooltip names your armor type')
eq(Has(mainRow.tooltip,'now Agility'),true,'G2: the main stat tooltip names your main stat')
ns.Char().autoRoll=true
eq(minRow.disabled(),false,'G2: enabled with Auto-Roll and Need on Upgrades');eq(nonGear.disabled(),false,'G2: Non-Gear Loot Rolls follows Auto-Roll')
eq(nonGear.type,'dropdown','non-gear: a Player Roll / Greed / Need dropdown')
local capRow,boeRow=Find(auto,'Non-Gear Up To'),Find(auto,'Bind on Equip Up To')
eq(capRow and boeRow and capRow.type=='dropdown' and boeRow.type=='dropdown',true,'rarity caps are dropdowns')
eq(Has(capRow.values[3],'Rare (Blue)') and Has(capRow.values[3],'|c'),true,'rarity choices are written in their quality color')
eq(capRow.disabled(),true,'Non-Gear Up To waits for Greed or Need');eq(capRow.disabledTooltip,'Non-Gear Loot Rolls: Greed or Need','and says so')
nonGear.setValue('need');eq(ns.Char().rollNonGear,'need','the mode writes its setting');eq(capRow.disabled(),false,'and opens the cap')
nonGear.setValue('bogus');eq(ns.Char().rollNonGear,'need','an unknown mode is refused')
capRow.setValue(9);eq(ns.Char().rollNonGearMaxQuality,2,'an unknown rarity is refused');capRow.setValue(3);eq(ns.Char().rollNonGearMaxQuality,3,'the cap writes its setting')
minRow.setValue(80);eq(ns.Char().rollMinGain,50,'G2: the slider clamps to 50')
armorRow.setValue(true);eq(ns.Char().rollNeedArmorType,true,'G2: the toggle writes its setting')
-- Profiles carry the new settings and reject bad ones.
local payload=ns.ExportProfile(false,false);payload.settings.rollMinGain=15;payload.settings.rollNonGear='need'
eq(ns.ApplyProfile(payload),true,'G2: a profile with the roll rules applies');eq(ns.Char().rollMinGain,15,'G2: Minimum Need Gain transfers')
payload.settings.rollMinGain=80;eq(ns.ApplyProfile(payload),false,'G2: an out-of-range Minimum Need Gain is rejected')
-- R3-3: another player's profile never turns on automation or its confirmations here.
Reset();ns.Char().autoRoll=false;ns.Char().confirmLootRolls=false;ns.Char().rollNonGear='player'
local shared=ns.ExportProfile(false,false)
shared.settings.autoRoll=true;shared.settings.confirmLootRolls=true;shared.settings.rollNonGear='need';shared.settings.rollNonGearMaxQuality=5;shared.settings.markerSize=30
eq(ns.ApplyProfile(shared),true,'R3-3: the shared profile applies')
eq(ns.Char().autoRoll==false and ns.Char().confirmLootRolls==false and ns.Char().rollNonGear=='player',true,'R3-3: automation and confirmations stay the character')
eq(ns.Char().markerSize,30,'R3-3: looks still come with the profile')
-- R3-4: a Bind on Pickup roll item is not yours yet, so the rarity cap still holds.
ns.Char().rarityCapBoEOnly=true;ns.Char().autoEquipMaxQuality=2
eq(ns.AutoEquipAllowed({quality=4,bound='bop'}),true,'R3-4: a soulbound epic in the bags passes the cap')
eq(ns.AutoEquipAllowed({quality=4,bound='bop'},true),false,'R3-4: the same epic on a loot roll does not')
ns.Char().rarityCapBoEOnly=false
-- R3-5: non-gear you cannot use is always your roll.
eq(E.NonGearAllowed({quality=1,classID=7,subclassID=5,usable=false},5),false,'R3-5: an unusable item is never rolled for you')
Reset()
Reset()

-- G3: Shift as the reward window opens leaves the choice to you -----------------------------------
Reset();h.setEquipped({[18]='item:1'});h.setChoices({'item:4','item:2'});ns.Char().autoQuest=true;ns.Changed()
local marked=0;local markFn=ns.MarkQuestRewards;ns.MarkQuestRewards=function(...) marked=marked+1;return markFn(...) end
local shift=true;IsShiftKeyDown=function() return shift end
h.Fire('QUEST_COMPLETE')
eq(h.getReward(),nil,'G3: Shift held: no reward is taken');eq(marked>0,true,'G3: rewards are still marked')
eq(ns.Actions.QuestShift(),true,'G3: the window remembers the Shift choice')
shift=false;h.Fire('GET_ITEM_INFO_RECEIVED',2,true);Advance(2)
eq(h.getReward(),nil,'G3: releasing Shift in the same window still leaves it to you')
h.Fire('QUEST_FINISHED');eq(ns.Actions.QuestShift(),false,'G3: closing the window forgets it')
local before=#h.printed()
h.Fire('QUEST_COMPLETE')
eq(h.getReward(),2,'G3: the next window without Shift is picked as usual')
eq(Has(h.printed()[#h.printed()],'Picked quest reward item:2'),true,'G13: with no card shown, chat reports the pick')
eq(#h.printed(),before+1,'G13: exactly one chat line')
h.Fire('QUEST_FINISHED');h.clearReward()
IsShiftKeyDown=function() error('restricted') end
h.Fire('QUEST_COMPLETE');eq(h.getReward(),2,'G3: an unreadable Shift key never blocks the pick')
h.Fire('QUEST_FINISHED');h.clearReward()
IsShiftKeyDown=function() return true end;ns.Char().autoQuest=false;ns.Changed()
h.Fire('QUEST_COMPLETE');eq(ns.Actions.QuestShift(),false,'G3: Shift means nothing while Auto-Pick is off')
h.Fire('QUEST_FINISHED');IsShiftKeyDown=nil;ns.MarkQuestRewards=markFn
eq(Has(Find(Rows('Automation'),'Auto-Pick Quest Rewards').tooltip,'Hold Shift'),true,'G3: the Auto-Pick tooltip explains Shift')
Reset()
-- SQ-4: EllesmereUI's Quest Tracker Auto Turn-In hands in a one-choice quest itself; Gear only marks it.
Reset();h.setEquipped({[18]='item:1'});h.setChoices({'item:2'});ns.Char().autoQuest=true;ns.Changed()
local eqtOn=true
EllesmereUIQuestTracker={Cfg=function(k) if k=='autoTurnIn' then return eqtOn end end}
h.Fire('QUEST_COMPLETE');eq(h.getReward(),nil,'SQ-4: one choice with Ellesmere Auto Turn-In on: Gear leaves the hand-in to it')
h.Fire('QUEST_FINISHED');h.clearReward()
eqtOn=false;h.Fire('QUEST_COMPLETE');eq(h.getReward(),1,'SQ-4: with its Auto Turn-In off, Gear picks as usual')
h.Fire('QUEST_FINISHED');h.clearReward()
eqtOn=true;h.setChoices({'item:4','item:2'});h.Fire('QUEST_COMPLETE');eq(h.getReward(),2,'SQ-4: several choices are still picked by Gear')
h.Fire('QUEST_FINISHED');h.clearReward()
EllesmereUIQuestTracker={Cfg=function() error('broken') end};h.setChoices({'item:2'})
h.Fire('QUEST_COMPLETE');eq(h.getReward(),1,'SQ-4: an unreadable Quest Tracker setting never blocks the pick')
h.Fire('QUEST_FINISHED');h.clearReward();EllesmereUIQuestTracker=nil;Reset()

-- G4: Rarity Cap: Bind on Equip Only -------------------------------------------------------------
Reset()
eq(ns.AutoEquipAllowed({quality=3,bound='bop'}),false,'G4: by default the cap holds back a soulbound blue')
ns.Char().rarityCapBoEOnly=true
eq(ns.AutoEquipAllowed({quality=3,bound='bop'}),true,'G4: Bind on Equip Only lets a Bind on Pickup blue through')
eq(ns.AutoEquipAllowed({quality=4,bound='bound'}),true,'G4: and an already-bound epic')
eq(ns.AutoEquipAllowed({quality=3,bound='boe'}),false,'G4: a Bind on Equip blue is still capped')
eq(ns.AutoEquipAllowed({quality=3}),false,'G4: an unbound blue is still capped (it can be sold)')
ns.Char().equipBoE=false
eq(ns.AutoEquipAllowed({quality=2,bound='boe'}),false,'G4: Auto-Equip Bind-on-Equip off still keeps every BoE')
ns.Char().equipBoE=true;ns.Char().rarityCapBoEOnly=false
local bagInfo=C_Container.GetContainerItemInfo
C_Container.GetContainerItemInfo=function(bag,slot) local v=bagInfo(bag,slot);if v then v.isBound=true end;return v end
h.setBags({[0]={'item:27'}});ns.Items.Invalidate();ns.Changed()
eq(#E.BagUpgrades(nil,true),0,'G4: a soulbound blue in the bags waits under the green cap')
ns.Char().rarityCapBoEOnly=true;ns.Changed()
local jobs=E.BagUpgrades(nil,true)
eq(jobs[1] and jobs[1].info.id,27,'G4: with Bind on Equip Only it becomes an automatic upgrade')
C_Container.GetContainerItemInfo=bagInfo
local capRow=Find(Rows('Automation'),'Rarity Cap: Bind on Equip Only')
eq(capRow~=nil,true,'G4: the option is next to Auto-Equip Up To')
ns.Char().autoEquip,ns.Char().autoRoll=false,false
eq(capRow.disabled(),true,'G4: disabled while auto-equip and auto-roll are off')
ns.Char().autoRoll=true;eq(capRow.disabled(),false,'G4: enabled by Auto-Roll too (Need follows the cap)')
Reset()

-- G9: Phase tooltip ---------------------------------------------------------------------------------
Reset()
local phase=Find(Rows('Stat Weights'),'Phase')
eq(Has(phase.tooltip,'Phase switches only your own weights'),true,'G9: Phase says what it switches')
eq(Has(phase.tooltip,'no effect now'),true,'G9: and that it changes nothing without your own weights')
ns.Weights.Custom('HUNTER','None','endgame',true).Agility=2
phase=Find(Rows('Stat Weights'),'Phase')
eq(Has(phase.tooltip,'no effect now'),false,'G9: with your own weights in a phase, the warning goes')
Reset()

-- G10: AutoGear migration and the Disable dialog -----------------------------------------------------
Reset();ns.Char().chat=false
local acct=ns.Account();acct.migratedAutoGear=nil
AutoGearDB={ImportedWeights={['HUNTER:None']={Agility=2},['ROGUE:Combat']={Agility=1}},LockGearSlots=true,LockedGearSlots={[18]={enabled=true},[1]={enabled=false}},
    Enabled=true,AutoSellGreys=true,AutoLootRoll=false}
before=#h.printed()
ns.Migrate()
local lines=h.printed()
eq(#lines,before+2,'G10: migration is never silent, even with chat messages off')
eq(Has(lines[before+1],'Copied 2 AutoGear weight scales (HUNTER None, ROGUE Combat)'),true,'G10: names the copied scales')
eq(Has(lines[before+2],'Found 1 AutoGear slot lock'),true,'G10: and says the locks wait for an explicit import')
eq(acct.migrationSummary.scales==2 and acct.migrationSummary.locks==1,true,'G10: the summary is kept for the AutoGear row')
before=#h.printed();ns.Migrate();eq(#h.printed(),before,'G10: migration runs and speaks once')
local summary=ns.AutoGearSummary()
eq(#summary,2,'G10: only what AutoGear has on is listed')
eq(summary[1],'AutoGear equips upgrades. Gear: Auto-Equip Upgrades is off.','G10: a covered feature names its Gear toggle and state')
eq(summary[2],'AutoGear sells grey items. Gear does not do this.','G10: an uncovered feature says Gear does not do it')
AutoGearDB.Enabled='yes';eq(#ns.AutoGearSummary(),1,'G10: only a real true counts')
h.loaded.AutoGear=true
local popup;EllesmereUI.ShowConfirmPopup=function(_,cfg) popup=cfg end
local disable=Find(Rows('Automation'),'Disable AutoGear','buttonText')
eq(disable~=nil and Has(disable.tooltip,'Gear copied 2 of its weight scales; 1 slot locks wait'),true,'G10: the AutoGear row says what was copied')
disable.onClick()
eq(popup and Has(popup.message,'AutoGear sells grey items. Gear does not do this.'),true,'G10: the dialog lists what AutoGear did')
eq(Has(popup.message,'nothing is switched on for you'),true,'G10: and promises nothing turns on')
AutoGearDB={};disable.onClick()
eq(Has(popup.message,'AutoGear has no automatic actions on'),true,'G10: an idle AutoGear says so')
h.loaded.AutoGear=nil;AutoGearDB=nil;EllesmereUI.ShowConfirmPopup=nil;acct.migrationSummary=nil
Reset()

-- G11: the tooltip names the replaced item; above-level items say when they become upgrades ---------
Reset();h.setEquipped({[18]='item:1'})
local tipLines={}
local tip={AddLine=function(_,text,r,g,b) tipLines[#tipLines+1]={text=text,r=r,g=g,b=b} end}
ns.AddTooltipLine(tip,'item:2')
eq(tipLines[1].text,'Gear: +2.5 upgrade over Laminated Recurve Bow','G11: the upgrade line names the replaced item')
local helm=ns.Items.Read('item:7')
eq(helm.usable,false,'G11: fixture: a level 30 helm is red at 20');eq(helm.levelOnly,true,'G11: blocked only by its level')
eq(ns.Items.Read('item:6').levelOnly,nil,'G11: an untrained gun is not level-only')
ns.AddTooltipLine(tip,'item:7')
eq(tipLines[2].text,'Gear: upgrade at level 30 (Fills an empty slot)','G11: an above-level item says when it becomes an upgrade')
local count=#tipLines;ns.AddTooltipLine(tip,'item:6')
eq(#tipLines,count,'G11: no "blocked" noise for gear you cannot use (the client text is red already)')
local laterLink=Item(537,'INVTYPE_RANGED',{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=3},{req=25})
ns.AddTooltipLine(tip,laterLink)
eq(tipLines[#tipLines].text,'Gear: usable at level 25, not an upgrade','G11: an above-level non-upgrade says so quietly')
eq(E.Verdict(helm),nil,'G11: above-level items are never upgrades for automation')
h.setLevel(30);ns.Items.Invalidate();E.Invalidate()
eq(ns.Items.Read('item:7').usable,true,'G11: at its level the helm is usable');eq(E.Verdict(ns.Items.Read('item:7'))~=nil,true,'G11: and a real upgrade')
Reset()

-- G12: color tokens ---------------------------------------------------------------------------------
Reset();h.setEquipped({[18]='item:1'})
eq(ns.ColourCode('upgrade'),'|cff40ff59','G12: the default upgrade token keeps the old green')
eq(ns.ColourCode('caution'),'|cffffc733','G12: the default caution token keeps the old gold')
ns.Char().textColours.upgrade={0,0,1}
tipLines={};ns.AddTooltipLine(tip,'item:2')
eq(tipLines[1].r==0 and tipLines[1].g==0 and tipLines[1].b==1,true,'G12: the tooltip upgrade line uses the token')
ns.Char().textColours.upgrade={2,0,0}
eq(select(1,ns.Colour('upgrade')),0.25,'G12: an out-of-range saved color falls back to the default')
ns.Char().textColours.upgrade='bad';eq(select(2,ns.Colour('upgrade')),1,'G12: a corrupt saved color falls back too')
eq(select(1,ns.Colour('nonsense')),0.6,'G12: an unknown token is muted, never an error')
ns.Char().textColours.gain={0,0,1}
local changes=ns.Notify.StatChanges(ns.Items.Read('item:2'),'item:1')
eq(Has(changes,'|cff0000ff'),true,'G12: pop-up stat gains use the gain token')
ns.Char().textColours.caution={0,1,0};ns.Char().autoEquip=false
eq(Has(opt.StatusText(),'|cff00ff00Marks only'),true,'G12: the status line uses the caution token')
local mk=Rows('Markers')
local up=Find(mk,'Upgrade Text');local reset=Find(mk,'Text Colors')
eq(up and up.type,'colorpicker','G12: each text color has a native picker')
local pickers=0;for _,cfg in ipairs(mk) do if cfg.type=='colorpicker' then pickers=pickers+1 end end
eq(pickers,#ns.COLOUR_KEYS,'G12: one picker per token')
up.setValue(0.5,0.25,1);eq(ns.Char().textColours.upgrade[2],0.25,'G12: the picker stores the token')
eq(select(3,up.getValue()),1,'G12: and reads it back')
up.setValue('x',0,0);eq(ns.Char().textColours.upgrade[1],0.5,'G12: a bad pick is ignored')
reset.onClick();eq(next(ns.Char().textColours),nil,'G12: Text Colors Reset clears every token')
local tokenProfile=ns.ExportProfile(false,false);tokenProfile.settings.textColours={upgrade={0,1,0}}
eq(ns.ApplyProfile(tokenProfile),true,'G12: text colors travel with the profile');eq(ns.Char().textColours.upgrade[2],1,'G12: and apply')
tokenProfile.settings.textColours={bogus={0,1,0}};eq(ns.ApplyProfile(tokenProfile),false,'G12: an unknown token is rejected')
tokenProfile.settings.textColours={upgrade={0,1}};eq(ns.ApplyProfile(tokenProfile),false,'G12: an incomplete color is rejected')
Reset()

-- G13: one report per action: the card, or chat when no card shows --------------------------------
Reset()
before=#h.printed()
ns.SayAction('Equipped x.',true);eq(#h.printed(),before,'G13: a shown card replaces the chat line')
ns.SayAction('Equipped x.',false);eq(#h.printed(),before+1,'G13: no card: one chat line')
ns.Char().chat=false;ns.SayAction('Equipped y.',false);eq(#h.printed(),before+1,'G13: Chat Messages off silences the fallback')
ns.Char().chat=true
local rolledFn=ns.Notify.Rolled;ns.Notify.Rolled=function() return true end
ns.Char().autoRoll=true;ns.Changed();h.setEquipped({[18]='item:1'});h.setRoll('item:2')
before=#h.printed();h.Fire('START_LOOT_ROLL',540,60000)
eq(h.getRolled()[540],1,'G13: fixture rolls Need');eq(#h.printed(),before,'G13: a roll with its card prints nothing')
ns.Notify.Rolled=function() return false end
h.Fire('START_LOOT_ROLL',541,60000)
eq(Has(h.printed()[#h.printed()],'Rolled Need on item:2'),true,'G13: a roll without a card is one chat line')
ns.Notify.Rolled=rolledFn
eq(Has(Find(Rows('Automation'),'Chat Messages').tooltip,'the card replaces the chat line'),true,'G13: the Chat Messages tooltip says so')
Reset()

-- G14: color-blind marker preset ----------------------------------------------------------------------
Reset()
local preset=Find(Rows('Markers'),'Color-Blind Markers')
eq(preset and preset.buttonText,'Apply','G14: the preset is a button on the Markers page')
preset.onClick()
c=ns.Char()
eq(c.markerStyle,'arrow','G14: upgrades become an arrow (a shape, not only a hue)');eq(c.greedMarkerStyle,'coin','G14: greed keeps the coin')
eq(c.markerColours.upgrade[3],ns.COLOURBLIND.upgrade[3],'G14: the upgrade marker turns blue')
eq(c.markerColours.upgrade[2]<1 and c.markerColours.upgrade[3]>c.markerColours.upgrade[2],true,'G14: not the uncommon-quality green')
eq(c.textColours.loss[1],ns.COLOURBLIND.loss[1],'G14: stat gain and loss colors change to blue and orange')
eq(ns.ValidColour(c.markerColours.greed),true,'G14: the preset writes valid colors')
local profileCheck=ns.ExportProfile(false,false);eq(ns.ApplyProfile(profileCheck),true,'G14: a preset profile validates')
Find(Rows('Markers'),'Marker Appearance').onClick()
eq(c.markerStyle,'border','G14: Marker Appearance Reset restores the border');eq(next(c.markerColours),nil,'G14: and the marker colors')
Reset()

-- D8: spell known reads C_SpellBook first and falls back through the shims ------------------------
local M=ns.HunterModel
local book,player,known=C_SpellBook,IsPlayerSpell,IsSpellKnown
C_SpellBook=nil;IsPlayerSpell=nil;IsSpellKnown=function(id) return id==1515 end
eq(M.Known(1515),true,'D8: with no C_SpellBook and no IsPlayerSpell, IsSpellKnown still answers')
C_SpellBook={IsSpellKnown=function() return false end};IsPlayerSpell=function() return true end
eq(M.Known(1515),false,'D8: C_SpellBook.IsSpellKnown is asked first')
C_SpellBook={IsSpellKnown=function() error('restricted') end}
eq(M.Known(1515),true,'D8: an error in C_SpellBook falls back to the shims')
local secretFn=issecretvalue;issecretvalue=function(v) return v=='secret' end
C_SpellBook={IsSpellKnown=function() return 'secret' end};IsPlayerSpell=nil;IsSpellKnown=nil
eq(M.Known(1515),nil,'D8: a secret answer is unknown, never "not learned"')
issecretvalue=secretFn
C_SpellBook=nil
eq(M.Known(1515),nil,'D8: no API at all is unknown')
C_SpellBook,IsPlayerSpell,IsSpellKnown=book,player,known
Reset()
