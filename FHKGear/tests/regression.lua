-- Concrete audit failure fixtures (E2). No real client behaviour is claimed.
local h=...
local ns,eq,near=h.ns,h.eq,h.near
local S,E=ns.Safe,ns.Engine
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
    h.setCursor(nil);h.setBags({});h.setEquipped({});h.setChoices({});h.clearReward();h.setLevel(20)
    ns.ResetSettings();ns.Items.Invalidate();ns.Engine.Invalidate();timers={}
    ns.Account().imported=nil;ns.Account().weights=nil;ns.Weights.Invalidate()
end
local function Item(id,loc,stats,extra)
    h.ITEMS[id]={'Fixture ' .. id,loc,2,stats or {},extra or {}}
    return 'item:' .. id
end
Reset()
eq(ns.Char().confirmEquipBinds,false,'bind confirmation is separately opt-in')
eq(ns.Char().confirmLootRolls,false,'loot confirmation is separately opt-in')
local bindCalls=0
EquipPendingItem=function() bindCalls=bindCalls+1 end
ns.Char().autoEquip=true;ns.Char().confirmEquipBinds=true;ns.Changed()
h.Fire('EQUIP_BIND_CONFIRM',18)
eq(bindCalls,0,'G01: unrelated bind has no owned transaction')
ns.Char().autoEquip=false;ns.Changed();timers={}

local tipAPI=C_TooltipInfo.GetHyperlink
C_TooltipInfo.GetHyperlink=function() return {lines={}} end
eq(ns.Items.Read('item:6').missing,true,'G02: empty tooltip is pending, never a usable gun')
eq(E.Verdict(ns.Items.Read('item:6')),nil,'G02: empty tooltip cannot produce an upgrade')
C_TooltipInfo.GetHyperlink=tipAPI
h.Fire('GET_ITEM_INFO_RECEIVED',6,true)
eq(ns.Items.Read('item:6').usable,false,'G02: complete red gun tooltip blocks after data arrives')

Reset();h.setEquipped({[18]='item:1',[5]='item:3'});h.setBags({[0]={'item:2'}});h.setChoices({'item:2','item:4'})
local index,how=E.QuestChoice()
eq(how,'vendor','G03: already-owned better bag bow removes redundant reward upgrade')
eq(index,1,'G03: vendor fallback still counts reward quantity')
h.missing[4]=true;ns.Items.Invalidate();ns.Char().autoQuest=true;ns.Changed()
h.Fire('QUEST_COMPLETE');h.Fire('QUEST_FINISHED');h.missing[4]=nil
h.Fire('GET_ITEM_INFO_RECEIVED',4,true);Advance(2)
eq(h.getReward(),nil,'G04: closed quest cannot be rewarded by an item callback')

Reset()
local dual=CanDualWield;CanDualWield=function() return true end
local two=Item(101,'INVTYPE_2HWEAPON',{ITEM_MOD_AGILITY_SHORT=12})
local main=Item(102,'INVTYPE_WEAPONMAINHAND',{ITEM_MOD_AGILITY_SHORT=7})
local off=Item(103,'INVTYPE_WEAPONOFFHAND',{ITEM_MOD_AGILITY_SHORT=7})
h.setEquipped({[16]=two});h.setBags({[0]={main,off}})
local jobs=E.BagUpgrades()
eq(jobs[1].target,16,'G05: pair replaces two-hander in main-hand-first order')
eq(jobs[1].follow.target,17,'G05: winning pair includes the off-hand continuation')
near(jobs[1].delta,2*ns.Weights.Current().Agility,'G05: compares entire pair against two-hander')
ns.Char().weaponStyle='2h';ns.Changed()
eq(E.Slots(ns.Items.Read(main),ns.Weights.Current()),nil,'G06: main-hand-only weapon cannot bypass two-hand preference')
ns.Char().weaponStyle='dagger and any';ns.Changed()
eq(E.Slots(ns.Items.Read(main),ns.Weights.Current()),nil,'G06: main-hand-only sword cannot bypass dagger requirement')
CanDualWield=dual

Reset();h.setEquipped({[11]='item:8'})
eq(select(2,E.Verdict(ns.Items.Read('item:8'))),12,'G07: second ordinary copy fills other ring slot')
local uniqueA=ns.Items.Read(Item(104,'INVTYPE_FINGER',{ITEM_MOD_AGILITY_SHORT=5}))
local uniqueB=ns.Items.Read(Item(105,'INVTYPE_TRINKET',{ITEM_MOD_AGILITY_SHORT=6}))
uniqueA.uniqueCategory,uniqueA.uniqueLimit='test',1
uniqueB.uniqueCategory,uniqueB.uniqueLimit='test',1
eq(E.Legal({[11]={info=uniqueA},[13]={info=uniqueB}}),false,'G08: category limits apply across ring and trinket slots')
local setProc=Item(106,'INVTYPE_CHEST',{}, {setID=123,equip='(2) Set: Chance on hit: Increases your attack power by 60 for 10 sec.'})
local info=ns.Items.Read(setProc)
eq(info.procs,nil,'G09: inactive set proc is not an ordinary proc')
near(E.Score(info),0,'G09: inactive set proc contributes no standalone value')
local setStatic=ns.Items.Read(Item(107,'INVTYPE_HEAD',{}, {setID=321,equip='(2) Set: +20 Attack Power.'}))
local partner=ns.Items.Read(Item(108,'INVTYPE_SHOULDER',{}, {setID=321}))
near(E.SetupScore({[1]={info=setStatic},[3]={info=partner}}),20*ns.Weights.Current().AttackPower,'G09: active set stat bonus counted once')

Reset()
local aliases=Item(109,'INVTYPE_CLOAK',{ITEM_MOD_CRIT_RATING_SHORT=1,ITEM_MOD_CRIT_MELEE_RATING_SHORT=1,ITEM_MOD_CRIT_RANGED_RATING_SHORT=1},{equip='Equip: Improves your chance to get a critical strike by 1%.'})
eq(ns.Items.Read(aliases).stats.Crit,1,'G11: redundant rating aliases and percent line yield one percent')
local rawRating=Item(110,'INVTYPE_HEAD',{ITEM_MOD_HIT_RATING_SHORT=4})
eq(select(2,E.Score(ns.Items.Read(rawRating))),false,'G10: raw rating has unknown units')
eq(E.AutomationSafe(ns.Items.Read(rawRating)),false,'G10: unknown rating cannot drive automation')
ns.Char().ratingUnits='rating';ns.Char().ratingConversions.Hit=2;ns.Changed('items')
eq(ns.Items.Read(rawRating).stats.Hit,2,'G10: explicit points-per-percent conversion is used')

Reset();h.setBags({[0]={'item:29','item:2'}});h.setEquipped({[18]='item:1'})
local pickup=C_Container.PickupContainerItem;local attempts=0
C_Container.PickupContainerItem=function(bag,slot) attempts=attempts+1;if slot~=1 then pickup(bag,slot) end end
ns.Char().autoEquip=true;ns.Changed();Advance(1);Advance(1)
eq(h.getEquipped()[18],'item:2','G12: no-op pickup does not hide ready fallback')
eq(attempts,2,'G12: no-op pickup is rejected and another candidate is attempted')
C_Container.PickupContainerItem=pickup
Reset();h.setBags({[0]={'item:10','item:2'}});h.setEquipped({[18]='item:1'})
local bagInfo=C_Container.GetContainerItemInfo
C_Container.GetContainerItemInfo=function(bag,slot) local value=bagInfo(bag,slot);if value and slot==1 then value.isLocked=true end;return value end
ns.Char().autoEquip=true;ns.Changed();Advance(1)
eq(h.getEquipped()[18],'item:2','G13: locked crit cloak does not block a ready bow')
C_Container.GetContainerItemInfo=bagInfo

Reset();ns.Char().autoRoll=true;ns.Changed();h.setRoll('item:4')
local rollInfo=GetLootRollItemInfo
GetLootRollItemInfo=function() return nil,nil,nil,nil,nil,false,false end
h.Fire('START_LOOT_ROLL',301,60000)
eq(h.getRolled()[301],nil,'G14: forbidden Greed remains manual')
GetLootRollItemInfo=rollInfo
ns.Char().rollNeedUpgrades=false;ns.Changed();h.setRoll('item:2');h.Fire('START_LOOT_ROLL',302,60000)
eq(h.getRolled()[302],nil,'Need toggle off leaves an upgrade roll manual')
ns.Char().rollNeedUpgrades=true;ns.Char().rollGreedOthers=false;ns.Changed();h.setEquipped({[5]='item:3'});E.InvalidateEquipped();h.setRoll('item:4')
h.Fire('START_LOOT_ROLL',303,60000)
eq(h.getRolled()[303],nil,'Greed toggle off leaves other loot manual')
-- GC5: RollOnLoot is not protected, so a roll that starts in combat is answered.
local lockAPI=InCombatLockdown;InCombatLockdown=function() return true end
Reset();ns.Char().autoRoll=true;ns.Changed();h.setNeed(true);h.setEquipped({[18]='item:1'});h.setRoll('item:2')
h.Fire('START_LOOT_ROLL',304,60000)
eq(h.getRolled()[304],1,'GC5: an upgrade roll is answered in combat')
InCombatLockdown=lockAPI
-- GC6: Need follows the auto-equip rarity cap.
local blueBow=Item(391,'INVTYPE_RANGED',{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=12},{quality=3})
h.setRoll(blueBow);h.Fire('START_LOOT_ROLL',305,60000)
eq(h.getRolled()[305],nil,'GC6: an upgrade above the auto-equip rarity cap stays a manual roll')
eq(select(2,E.RollChoice(305)),'Upgrade outside your auto-equip rules: choose manually','GC6: and says why')

local parsed=ns.Weights.Parse('Mp5=4,Hp5=3,Agility=1e2')
eq(parsed.Mp5,4,'G15: digit stat key imports');eq(parsed.Hp5,3,'G15: Hp5 imports');eq(parsed.Agility,100,'G15: full exponent imports')
eq(ns.Weights.Parse('Agility=1,Agility=2'),nil,'G15: duplicate keys are rejected')
eq(ns.Weights.Parse('Agility=1e309,Stamina=2'),nil,'G43: infinite import is rejected')
local native=ns.Weights.Parse(ns.Weights.Export({Agility=0,SpellPower=2,SpellDamage=7,DPS=3,Mp5=4},'Fixture'))
eq(native.Agility,0,'G16: native export preserves explicit zero');eq(native.SpellDamage,7,'G16: native export preserves separate damage-only weight');eq(native.DPS,3,'G16: native export preserves generic DPS')
Reset();AutoGearDB={ImportedWeights={['HUNTER:None']={Agility=2}}};ns.Account().migratedAutoGear=nil;ns.Migrate()
AutoGearDB.ImportedWeights['HUNTER:None'].Agility=90
eq(ns.Account().imported['HUNTER:None'].Agility,2,'G17: migration owns a deep copy')
eq(ns.Weights.Current().RangedDPS,2,'G17: sparse migration retains adjusted Hunter ranged default')
AutoGearDB=nil

Reset()
local p=ns.Effects.Proc('Chance on hit: Increases Strength by 20 and Agility by 30 for 10 sec.')
eq(p.stats.Strength,20,'G21: multi-buff first clause');eq(p.stats.Agility,30,'G21: multi-buff second clause')
eq(ns.Effects.Proc('Chance on hit: Reduces enemy armor by 200 for 10 sec.'),nil,'G21: enemy armor is never own Armor')
near(ns.Effects.Proc('Chance on hit: Deals 7.5-12.5 Fire damage.').damage,10,'G21: decimal hyphen damage range')
near(ns.Effects.Proc('Chance on hit: Deals 50 Nature damage over 10 sec.').damage,50,'G21: total-over-time is not multiplied by ticks')
ns.Char().procRates[15]={ppm=2,icd=10};ns.Char().meleeShare=0.5
local rate,known=E.ProcRate(ns.Items.Read('item:15'),ns.Items.Read('item:15').procs[1],ns.Weights.Current())
near(rate,(1/60)/(1+10/60),'G19: per-item PPM, participation and internal cooldown compose')
eq(known,true,'G19: explicit player rate has known inputs')
ns.Char().procRates[15]=nil
local _,estKnown,estNote=E.ProcRate(ns.Items.Read('item:15'),ns.Items.Read('item:15').procs[1],ns.Weights.Current())
eq(estKnown,true,'N01: a default-PPM estimate may drive automation by default');eq(estNote,'default PPM estimate','N01: it is still labelled an estimate')
ns.Char().allowEstimates=false
eq(select(2,E.ProcRate(ns.Items.Read('item:15'),ns.Items.Read('item:15').procs[1],ns.Weights.Current())),false,'G19/N01: with estimates off, a default PPM stays unknown')
ns.Char().allowEstimates=true
local damage={kind='use',cooldown=120,damage=60,stats={}}
near(E.ProcValue({id=201,equipLoc='INVTYPE_WEAPON'},damage,ns.Weights.Current()),E.ProcValue({id=202,equipLoc='INVTYPE_TRINKET'},damage,ns.Weights.Current()),'G20: direct damage uses same objective on weapon and trinket')

Reset();local before=h.getStats()
for _=1,20 do h.Fire('SKILL_LINES_CHANGED') end
eq(h.getStats(),before,'G31: burst skill events do not synchronously rescan items')
eq(#timers,1,'G31: one context timer coalesces skill burst');Advance(1)
ns.Char().autoEquip=true;h.setCursor('item:9');ns.Changed()
for _=1,12 do Advance(1) end
eq(#timers,0,'G34: occupied cursor retries stop after a bounded budget')
eq(h.getCursor(),'item:9','G34: unrelated cursor contents survive')
Reset();h.missing[2]=true;h.setBags({[0]={'item:2'}});ns.Char().autoEquip=true;ns.Changed();Advance(1)
eq(ns.Actions.PendingCount(),1,'G35: missing equip has one keyed waiter')
h.Fire('GET_ITEM_INFO_RECEIVED',999,false)
eq(ns.Actions.PendingCount(),1,'G35: unrelated failure does not wake or erase waiter')
ns.Char().autoEquip=false;ns.Changed();h.missing[2]=nil
eq(ns.Actions.PendingCount(),0,'G35: disabling cancels pending equip')
local instant=GetItemInfoInstant;GetItemInfoInstant=function() return nil end
eq(ns.Items.Read('item:2').missing,true,'G37: missing instant data retains validated link item ID')
GetItemInfoInstant=instant;ns.Items.Invalidate()
eq(S.Number(0/0),false,'G38: NaN rejected');eq(S.Number(math.huge),false,'G38: infinity rejected')
local secret={};issecretvalue=function(v) return v==secret end
eq(S.Number(secret),false,'G38: secret sentinel rejected before arithmetic')
eq(ns.SetIgnored(secret,true),false,'G38: secret item rule rejected before parsing')
issecretvalue=nil
local red,complete=ns.Items.IsRed({r=0.8,g=0.1,b=0.1})
eq(red,true,'G62: relative red below old threshold blocks');eq(complete,true,'G62: complete colour known')
eq(select(2,ns.Items.IsRed({r=1})),false,'G62: partial colour stays unknown')

Reset();local payload=ns.ExportProfile(true,true)
payload.settings.markerSize=24;payload.settings.rollNeedUpgrades=false;payload.rules.locked[18]=true
eq(ns.ApplyProfile(payload),true,'G53: versioned profile applies validated controls')
eq(ns.Char().markerSize,24,'G53: marker appearance transfers');eq(ns.Char().rollNeedUpgrades,false,'G53: roll policy transfers');eq(ns.Char().locked[18],true,'G53: optional locks transfer')
payload.settings.fightLength=math.huge
eq(ns.ApplyProfile(payload),false,'G53: non-finite profile rejected before mutation')
local early=ns.Char();FHKGearCharDB={chat=false};local late=ns.Char()
eq(late==early,false,'G40: SavedVariables assignment rebinds settings');eq(late.chat,false,'G40: loaded setting wins')

Reset();local prebuild=EllesmereUI.IsSearchPrebuild
EllesmereUI.IsSearchPrebuild=function() return true end
local oldChar=h.options.Char;h.options.Char=function() error('prebuild touched settings') end
local framesBefore=#timers
for _,page in ipairs(h.spec.modules[1].pages) do eq(h.spec.modules[1].buildPage(page,{},0)>0,true,'G44: static prebuild ' .. page) end
eq(#timers,framesBefore,'G44: prebuild starts no timers')
h.options.Char=oldChar;EllesmereUI.IsSearchPrebuild=prebuild
h.clearRows();h.spec.modules[1].buildPage('Model',{},0)
local rateButton
for _,row in ipairs(h.getRows()) do for _,cfg in ipairs(row) do if cfg.text=='Proc Rate Override' then rateButton=cfg end end end
rateButton.onClick();h.getPopup().onConfirm('14555, ppm=2, icd=10')
eq(ns.Char().procRates[14555].ppm,2,'proc override UI stores validated PPM')
eq(ns.Char().procRates[14555].icd,10,'proc override UI stores internal cooldown')
h.clearRows();h.spec.modules[1].buildPage('Stat Weights',{},0)
local agility
for _,row in ipairs(h.getRows()) do for _,cfg in ipairs(row) do if cfg.type=='input' and cfg.text==(ns.Weights.LABELS.Agility or 'Agility') then agility=cfg end end end
agility.setValue('1e309')
eq((ns.Weights.Custom('HUNTER','None','levelling') or {}).Agility,nil,'G43: infinite UI weight is rejected')
agility.setValue(agility.getValue())
eq(ns.Weights.Custom('HUNTER','None','levelling'),nil,'GU3: clicking in and out of a weight box saves nothing')
local pawnScale=ns.Weights.Parse('( Pawn: v1: "Test": Agility=1, AttackPower=0.5, IsPlate=-1000000, IsShield=-1000000 )')
eq(pawnScale and pawnScale.Agility,1,'GU4: Pawn "unusable" entries are skipped, not a reason to reject the scale')
eq(ns.Weights.Parse('Agility=1, Stamina=-1'),nil,'GU4: a negative value on a real stat is still rejected')
eq(ns.Weights.Parse('Crit=14',1)~=nil,true,'GU7: one rating conversion is accepted')
eq(ns.Weights.Parse('Crit=14'),nil,'GU7: weight scales still need two stats')
-- GU6: in combat, quiver changes from every shot cost nothing until combat ends.
local markerFn,markerRuns=ns.RefreshMarkers,0;ns.RefreshMarkers=function() markerRuns=markerRuns+1 end
local lockFn=InCombatLockdown;InCombatLockdown=function() return true end
for _=1,5 do h.Fire('BAG_UPDATE_DELAYED') end
eq(markerRuns,0,'GU6: bag updates in combat do no work')
InCombatLockdown=lockFn;h.Fire('PLAYER_REGEN_ENABLED')
eq(markerRuns,1,'GU6: one bag pass runs when combat ends')
ns.RefreshMarkers=markerFn
ns.Char().chat=false;local messages=#h.printed();SlashCmdList.FHKGEAR('status')
eq(#h.printed()>messages,true,'G50: requested diagnostic bypasses notification toggle')
Reset()

-- Own bind transaction and action failure shapes.
h.setBags({[0]={'item:11'}})
local equip=EquipCursorItem
local pendingSlot
EquipCursorItem=function(slot) pendingSlot=slot;h.Fire('EQUIP_BIND_CONFIRM',slot) end
EquipPendingItem=function(slot) bindCalls=bindCalls+1;equip(slot) end
ns.Char().autoEquip=true;ns.Char().confirmEquipBinds=false;ns.Changed();Advance(1)
local bindBefore=bindCalls
eq(pendingSlot,9,'owned BoE transaction reached bind prompt')
eq(h.getEquipped()[9],nil,'confirmation OFF leaves the bind for the player')
Advance(3)
eq(h.getCursor(),'item:11','manual bind receives time to respond, not a two-second cancellation')
h.Fire('EQUIP_BIND_CONFIRM',18)
eq(bindCalls,bindBefore,'wrong target cannot claim active transaction')
ns.Char().confirmEquipBinds=true
h.Fire('EQUIP_BIND_CONFIRM',9)
eq(bindCalls,bindBefore+1,'confirmation ON accepts only matching owned bind')
eq(h.getEquipped()[9],'item:11','matching bind is acknowledged from inventory')
h.Fire('EQUIP_BIND_CONFIRM',9)
eq(bindCalls,bindBefore+1,'completed transaction cannot confirm another bind')
EquipCursorItem=equip
Reset();h.setBags({[0]={'item:2'}})
local cursorAPI=GetCursorInfo;GetCursorInfo=nil
ns.Char().autoEquip=true;ns.Changed();Advance(1)
eq(h.getEquipped()[18],nil,'missing cursor identity API disables automatic equip')
eq(h.getBags()[0][1],'item:2','missing action API never picks up the item')
GetCursorInfo=cursorAPI
Reset();h.setBags({[0]={'item:2'}})
local realPickup=C_Container.PickupContainerItem
C_Container.PickupContainerItem=function() h.setCursor('item:9') end
ns.Char().autoEquip=true;ns.Changed();Advance(1)
eq(h.getEquipped()[18],nil,'wrong pickup cursor identity cannot be equipped')
eq(h.getCursor(),'item:9','wrong cursor item is preserved for the player')
C_Container.PickupContainerItem=realPickup

-- Permanent enchant source reconciliation; no guessed proc enchant values.
Reset()
local originalStats=C_Item.GetItemStats
local originalTip=C_TooltipInfo.GetHyperlink
local rawIncludesEnchant=true
C_Item.GetItemStats=function(link)
    if link:find('item:3:777',1,true) then return {ITEM_MOD_AGILITY_SHORT=rawIncludesEnchant and 6 or 3,RESISTANCE0_NAME=100} end
    return originalStats(link)
end
C_TooltipInfo.GetHyperlink=function(link)
    local data=originalTip(link)
    if link:find('item:3:777',1,true) then data.lines[#data.lines+1]={leftText='Enchanted: +3 Agility',type=15} end
    if link:find('item:3:888',1,true) then data.lines[#data.lines+1]={leftText='Fiery Weapon',type=15} end
    return data
end
eq(ns.Items.Read('item:3:777').stats.Agility,6,'enchant already in structured totals is not counted twice')
rawIncludesEnchant=false;ns.Items.Invalidate()
eq(ns.Items.Read('item:3:777').stats.Agility,6,'explicit stat enchant missing from structured totals is added once')
eq(E.AutomationSafe(ns.Items.Read('item:3:888')),false,'unknown proc enchant prevents automatic score choice')
eq(ns.Items.Read('item:3:777')==ns.Items.Read('item:3:888'),false,'full enchant identity remains distinct in cache')
C_Item.GetItemStats=originalStats;C_TooltipInfo.GetHyperlink=originalTip

-- Overlay objects stay outside native button state and hide on disable.
Reset()
local texture
local button={type='choice',GetID=function() return 1 end,IsShown=function() return true end}
function button:CreateTexture()
    texture={shown=false}
    function texture:SetTexture(v) self.art=v end
    function texture:SetBlendMode(v) self.blend=v end
    function texture:SetSize(w,h) self.width,self.height=w,h end
    function texture:SetPoint(...) self.point={...} end
    function texture:ClearAllPoints() self.point=nil end
    function texture:SetVertexColor(r,g,b,a) self.r,self.g,self.b,self.a=r,g,b,a end
    function texture:Show() self.shown=true end
    function texture:Hide() self.shown=false end
    return texture
end
QuestInfoItem1=button
ns.MarkQuestRewards({[1]=true})
eq(texture.shown,true,'G47: owned overlay marks shown reward')
eq(button.FHKGearBorder,nil,'G47: no addon state field on native button')
ns.Char().markQuest=false;ns.Changed()
eq(texture.shown,false,'G48: disabling hides existing overlay immediately')
ns.Char().markQuest=true;ns.Char().markerStyle='diamond';ns.Char().markerSize=24;ns.Char().markerOpacity=0.5
ns.Char().markerColours.upgrade={0.1,0.2,0.3};ns.MarkQuestRewards({[1]=true})
eq(texture.width,24,'marker icon size applies');near(texture.a,0.5,'marker opacity applies');near(texture.r,0.1,'marker colour applies')
eq(texture.art:find('UI-RaidTargetingIcon_3',1,true)~=nil,true,'marker icon style applies')
ns.Char().greedMarkerStyle='coin';ns.MarkQuestRewards({},1)
eq(texture.art:find('UI-GoldIcon',1,true)~=nil,true,'greed/vendor icon style is independently configurable')
ns.ClearQuestMarks();eq(texture.shown,false,'dialog close clears overlay')
QuestInfoItem1=nil

-- Source precedence, failing providers and warmed-pass costs.
Reset();h.loaded.ForeverGear=true
local readyCalls,scoreCalls=0,0
ForeverGearAPI={apiVersion=1,IsReady=function() readyCalls=readyCalls+1;return true end,
    GetUpgradeState=function() scoreCalls=scoreCalls+1;return false,42 end}
h.setEquipped({[18]='item:1'});h.setBags({[0]={'item:2','item:4','item:5'}})
E.Invalidate();E.BagUpgrades()
eq(readyCalls,1,'G33: one provider readiness check per complete bag pass')
ns.Items.Read('item:2');local warmed=h.getStats()
for _=1,100 do E.Verdict(ns.Items.Read('item:2')) end
eq(h.getStats(),warmed,'warm hover loop does not re-read item stats')
eq(readyCalls,1,'warm hover loop reuses readiness snapshot')
ns.Account().imported={['HUNTER:None']={Agility=2}};ns.Changed()
eq(E.UsesForeverGear(),false,'G60: migrated weights prevent automatic external takeover')
ns.Char().source='forevergear';h.setLevel(40);ns.Changed()
eq(E.UsesForeverGear(),true,'explicit provider selection works above automatic level range')
ForeverGearAPI.GetUpgradeState=function() return false,nil end;E.Invalidate()
eq(E.Score(ns.Items.Read('item:2')),nil,'G59: ready provider without score stays unavailable')
eq(E.Verdict(ns.Items.Read('item:2')),nil,'G59: nil provider score never fills empty slot')
ForeverGearAPI.GetUpgradeState=function() error('provider fixture error') end;E.Invalidate()
eq(E.Score(ns.Items.Read('item:2')),nil,'G42: failing provider returns explicit unavailable score')
eq(#S.errors>0,true,'G42: API failure retained for errors command')
h.loaded.ForeverGear=nil;ForeverGearAPI=nil
Reset();ns.Char().tooltip=false;ns.Char().markQuest=false;ns.Char().popFound=false;ns.Changed()
for _,event in ipairs({'BAG_UPDATE_DELAYED','PLAYER_EQUIPMENT_CHANGED','SKILL_LINES_CHANGED','PLAYER_LEVEL_UP','SPELLS_CHANGED','WEAPON_ENCHANT_CHANGED','START_LOOT_ROLL','QUEST_COMPLETE'}) do
    eq(h.core.events[event],nil,'G36: all-off unregisters ' .. event)
end
eq(h.core.events.PLAYER_LOGIN,nil,'G36: one-shot login is removed')
eq(#timers,0,'all-off leaves no queued work')
Reset()
ns.Char().autoEquip=true;h.setLevel(59);ns.Changed();h.Fire('PLAYER_LEVEL_UP',60)
eq(ns.Automating('autoEquip'),false,'level-60 payload caps actions before UnitLevel catches up')
Advance(1)
eq(ns.Automating('autoEquip'),false,'stale UnitLevel cannot undo level-60 cap')
h.setLevel(60);h.Fire('PLAYER_LEVEL_UP',60);Advance(1)
eq(ns.LevellingCapped(),true,'level API convergence retains cap');Reset()

-- Exact baseline beats greedy choices under category constraints.
local ringHigh=Item(211,'INVTYPE_FINGER',{ITEM_MOD_AGILITY_SHORT=100},{equip='Unique-Equipped: Baseline Test (1)'})
local ringNormal=Item(212,'INVTYPE_FINGER',{ITEM_MOD_AGILITY_SHORT=98})
local trinketHigh=Item(213,'INVTYPE_TRINKET',{ITEM_MOD_AGILITY_SHORT=99},{equip='Unique-Equipped: Baseline Test (1)'})
ns.Char().locked[12]=true;ns.Char().locked[14]=true
h.setBags({[0]={ringHigh,ringNormal,trinketHigh}})
local baseline,complete=E.BagBaseline()
eq(complete,true,'exact setup search completes this fixture')
eq(baseline[11].info.id,212,'category-constrained baseline uses slightly weaker normal ring')
eq(baseline[13].info.id,213,'category-constrained baseline preserves much stronger trinket')
near(E.SetupScore(baseline),197*ns.Weights.Current().Agility,'exact baseline compares total setup, not greedy first item')
eq(E.lastBaselineSteps<=10000,true,'exact setup search obeys work budget')

Reset();local skillCount=2
C_SkillInfo={GetNumSkillLines=function() return skillCount end}
h.Fire('PLAYER_LOGIN');Advance(1)
ns.Items.Read('item:2');local facts=ns.Items.cache['item:2']
for _=1,20 do h.Fire('SKILL_LINES_CHANGED') end
Advance(1)
eq(ns.Items.cache['item:2'],facts,'G31: known stable proficiency count retains immutable usable facts')
local blocked=ns.Items.Read('item:6');eq(blocked.usable,false,'proficiency fixture starts red')
h.ITEMS[6][5].untrained=false;skillCount=3;h.Fire('SKILL_LINES_CHANGED');Advance(1)
eq(ns.Items.Read('item:6').usable,true,'G31: new proficiency invalidates blocked requirements')
h.ITEMS[6][5].untrained=true;C_SkillInfo=nil;Reset()

-- Storage, profile and user-input boundaries added during final review.
local biggerTwo=Item(214,'INVTYPE_2HWEAPON',{ITEM_MOD_AGILITY_SHORT=30})
h.setEquipped({[16]=main,[17]=off});h.setBags({[0]={biggerTwo}})
local freeSlots=C_Container.GetContainerNumFreeSlots
C_Container.GetContainerNumFreeSlots=function() return 0,0 end
local twoJob={bag=0,slot=1,info=ns.Items.Read(biggerTwo,0,1),target=16}
eq(ns.Actions.Eligible(twoJob),false,'G12: full bags cannot absorb the second displaced hand')
C_Container.GetContainerNumFreeSlots=function(bag) return bag==0 and 1 or 0,0 end
eq(ns.Actions.Eligible(twoJob),true,'G12: general free slot permits the two-hander transaction')
C_Container.GetContainerNumFreeSlots=function(bag) return bag==1 and 3 or 0,bag==1 and 512 or 0 end
eq(ns.Actions.Eligible(twoJob),false,'specialised bag space does not count as weapon storage')
C_Container.GetContainerNumFreeSlots=freeSlots;Reset()
local id,rate=ns.ParseProcRate('14555, ppm=1.5, icd=10')
eq(id,14555,'proc input retains full item ID');near(rate.ppm,1.5,'proc input accepts finite decimal PPM')
eq(ns.ParseProcRate('14555, ppm=1junk'),nil,'proc input rejects numeric prefix with junk')
eq(ns.ParseProcRate('14555, ppm=1, ppm=2'),nil,'proc input rejects duplicate rate keys')
eq(ns.ParseProcRate('14555, ppm=1, chance=5'),nil,'proc input rejects competing rate models')
eq(ns.ParseProcRate('14555, ppm=1,, icd=0'),nil,'proc input rejects empty entries')
eq(ns.ParseProcRate('14555, ppm=1e309'),nil,'proc input rejects infinite rate')
-- GC3: two failed equips end retries for the session (a declined bind counts as two).
h.setTime(h.time()+120);Reset();local stuckBow=Item(392,'INVTYPE_RANGED',{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=8})
h.setEquipped({[18]='item:1'});h.setBags({[0]={stuckBow}})
local pickupOK=C_Container.PickupContainerItem;local pickTries=0
C_Container.PickupContainerItem=function() pickTries=pickTries+1 end
ns.Char().autoEquip=true;ns.Changed();Advance(1);Advance(1)
eq(pickTries,1,'GC3: a failed equip waits before retrying')
Advance(61);h.Fire('BAG_UPDATE_DELAYED');Advance(1);Advance(1)
eq(pickTries,2,'GC3: one retry after a minute')
Advance(600);h.Fire('BAG_UPDATE_DELAYED');Advance(1);Advance(1)
eq(pickTries,2,'GC3: after two failures the item is left alone this session')
C_Container.PickupContainerItem=pickupOK;ns.Char().autoEquip=false;ns.Changed()
-- GC10: never pick an item up while the player is dragging a spell or is dead.
Reset();h.setEquipped({[18]='item:1'});h.setBags({[0]={'item:2'}})
local cursorFn=GetCursorInfo;GetCursorInfo=function() return 'spell',75 end
ns.Char().autoEquip=true;ns.Changed();Advance(1);Advance(1)
eq(h.getEquipped()[18],'item:1','GC10: a spell on the cursor blocks auto-equip')
GetCursorInfo=cursorFn;UnitIsDeadOrGhost=function() return true end;h.Fire('BAG_UPDATE_DELAYED');Advance(1);Advance(1)
eq(h.getEquipped()[18],'item:1','GC10: and so does being dead')
UnitIsDeadOrGhost=nil;h.Fire('BAG_UPDATE_DELAYED');Advance(1);Advance(1)
eq(h.getEquipped()[18],'item:2','GC10: alive with an empty cursor it equips')
ns.Char().autoEquip=false;ns.Changed()
-- GC4: an item Gear took off is not put straight back over another item.
h.setTime(h.time()+120);Reset();h.setEquipped({[18]='item:1'});h.setBags({[0]={'item:2'}})
ns.Char().autoEquip=true;ns.Changed();Advance(1);Advance(1)
eq(h.getEquipped()[18],'item:2','GC4 setup: the better bow goes on')
local weightsFn=ns.Engine.Verdict
ns.Engine.Verdict=function(info,set) if info and info.link=='item:1' then return 0.5,18,'+0.5' end return weightsFn(info,set) end
h.Fire('BAG_UPDATE_DELAYED');Advance(1);Advance(1)
eq(h.getEquipped()[18],'item:2','GC4: the bow Gear removed does not swap back when weights shift')
ns.Engine.Verdict=weightsFn;ns.Char().autoEquip=false;ns.Changed();h.setTime(h.time()+700)
-- GC7: a reward link that is not built yet is retried, not dropped.
Reset();h.setEquipped({[18]='item:1'});h.setChoices({'item:2'})
local linkFn=GetQuestItemLink;local linkCalls=0
GetQuestItemLink=function(kind,i) linkCalls=linkCalls+1;if linkCalls<=1 then return nil end;return linkFn(kind,i) end
ns.Char().autoQuest=true;ns.Changed();h.Fire('QUEST_COMPLETE');Advance(1.1);Advance(1.1)
eq(h.getReward(),1,'GC7: the reward is chosen once its link arrives')
GetQuestItemLink=linkFn;h.Fire('QUEST_FINISHED');ns.Char().autoQuest=false;ns.Changed()
local validProfile=ns.ExportProfile(true,true)
validProfile.settings.procRates[14555]={ppm='bad'}
eq(ns.ApplyProfile(validProfile),false,'profile rejects malformed nested proc rate before mutation')
validProfile=ns.ExportProfile(true,true);validProfile.rules.locked='bad'
eq(ns.ApplyProfile(validProfile),false,'profile rejects non-table slot rules before mutation')
validProfile=ns.ExportProfile(true,true);validProfile.settings.markerColours.upgrade={1,0}
eq(ns.ApplyProfile(validProfile),false,'profile rejects incomplete RGB colour')
validProfile=ns.ExportProfile(true,true);validProfile.weights={fixture={Agility=math.huge}}
eq(ns.ApplyProfile(validProfile),false,'profile rejects invalid nested weight values')
validProfile=ns.ExportProfile(true,true);validProfile.settings.spec=nil;ns.Char().spec='Survival'
eq(ns.ApplyProfile(validProfile),true,'valid profile restores automatic spec selection')
eq(ns.Char().spec,nil,'profile without a selected spec clears old manual selection')
validProfile=ns.ExportProfile(true,true);validProfile.settings.source='hunter'
eq(ns.ApplyProfile(validProfile),true,'profile with the Hunter Model source imports (review GU1)');eq(ns.Char().source,'hunter','Hunter Model source survives the profile round trip');ns.Char().source='auto'
Reset();h.setEquipped({[18]='item:1'});h.setRoll('item:2');ns.Char().rollNeedUpgrades=false
eq(select(4,E.RollChoice(7)),true,'upgrade roll mark stays green when Need policy is off')
Reset();h.missing[2]=true;h.setBags({[0]={'item:2'}});ns.Char().autoEquip=true;ns.Changed();Advance(1)
for _=1,10 do h.Fire('GET_ITEM_INFO_RECEIVED',2,true);Advance(0.5) end
Advance(12)
eq(ns.Actions.PendingCount(),0,'G35: successful item events cannot reset the shared waiter budget forever')
h.missing[2]=nil;Reset()

-- Audit status N01-N04, N06 (Claude, 2026-10-04): defects reproduced with these mocks, now fixed.
-- Earlier fixtures leave 60-second failed-equip records; step past them first.
h.setTime(h.time()+120);Reset();h.setEquipped({[16]='item:15',[18]='item:1'});h.setBags({[0]={'item:2'}})
ns.Char().autoEquip=true;ns.Changed();Advance(1);Advance(1)
eq(h.getEquipped()[18],'item:2','N01: a worn chance-on-hit weapon no longer blocks an unrelated bow upgrade')
h.Fire('PLAYER_EQUIPMENT_CHANGED',18);Advance(1)
eq(ns.Actions.Manual(18),false,'GC1: the equip event for the swap Gear made is not a manual change')
Advance(3);h.setEquipped({[16]='item:15',[18]='item:1'});h.setBags({[0]={'item:2'}});h.Fire('PLAYER_EQUIPMENT_CHANGED',18);Advance(1);Advance(1)
eq(h.getEquipped()[18],'item:1','GC1: a ranged weapon the player swapped back by hand stays on')
eq(ns.Actions.Manual(18),true,'GC1: that slot is paused')
h.Fire('PLAYER_EQUIPMENT_CHANGED',0);eq(ns.Actions.Manual(0),false,'GC1: ammo running out never pauses the ammo slot')
h.setLevel(21);h.Fire('PLAYER_LEVEL_UP',21);Advance(1);Advance(1)
eq(h.getEquipped()[18],'item:2','GC1: the next level releases the slot and the upgrade goes on')
ns.Actions.ClearManual()
Reset();local betterBoots=Item(301,'INVTYPE_FEET',{ITEM_MOD_AGILITY_SHORT=5})
h.setEquipped({[8]='item:12'});h.setBags({[0]={betterBoots}})
ns.Char().autoEquip=true;ns.Changed();Advance(1);Advance(1)
eq(h.getEquipped()[8],'item:12','N01: an upgrade that replaces an item Gear cannot price stays manual')
eq(#E.BagUpgrades()>0,true,'N01: that upgrade is still marked')
Reset();h.setEquipped({[18]='item:1'});h.setBags({[0]={'item:4','item:12','item:16'}});h.setChoices({'item:4','item:2'})
local qIndex,qHow=E.QuestChoice()
eq(qHow,'upgrade','N02: uncertain bag items no longer force quest choice to manual');eq(qIndex,2,'N02: the bow reward is chosen')
Reset();h.setEquipped({[8]='item:12'});h.setChoices({Item(302,'INVTYPE_FEET',{ITEM_MOD_AGILITY_SHORT=9})})
local _,howBoots,whyBoots=E.QuestChoice()
eq(howBoots,'manual','N02: a reward replacing an unpriced worn item stays manual');eq(whyBoots,'Best reward replaces an item Gear cannot price','N02: and says why')
Reset();h.setEquipped({[18]='item:1'});h.setBags({[0]={'item:2','item:4','item:5'}});ns.Changed();E.BagUpgrades()
local cachedBefore=0;for _ in pairs(ns.Items.cache) do cachedBefore=cachedBefore+1 end
local statsBefore=h.getStats()
for _=1,20 do h.Fire('SPELLS_CHANGED') end
Advance(1)
local cachedAfter=0;for _ in pairs(ns.Items.cache) do cachedAfter=cachedAfter+1 end
E.BagUpgrades()
eq(cachedAfter,cachedBefore,'N03: a burst of SPELLS_CHANGED keeps usable cached items')
eq(h.getStats(),statsBefore,'N03: no item is re-read after the burst')
Reset();local badge=Item(303,'INVTYPE_TRINKET',nil,{equip='Use: Increases your attack power by 50 for 15 sec. (2 Min Cooldown)'})
h.ITEMS[303][4]=nil
eq(ns.Items.Read(badge).missing,nil,'N04: a complete tooltip with a nil stat table is "no stats", not pending')
h.setEquipped({[13]=badge,[18]='item:1'});ns.Changed()
local _,_,badgeWhy=E.Verdict(ns.Items.Read('item:2'))
eq(badgeWhy~='Equipped comparison unavailable',true,'N04: wearing a statless trinket keeps comparisons working')
Reset();local prebuildN06=EllesmereUI.IsSearchPrebuild;EllesmereUI.IsSearchPrebuild=function() return true end
h.clearRows();h.spec.modules[1].buildPage('Markers',{},0)
local labels={};for _,r in ipairs(h.getRows()) do for _,cfg in ipairs(r) do if cfg and cfg.text then labels[cfg.text]=true end end end
eq(labels['Tooltip Score'],true,'N06: a page indexes its own labels');eq(labels['Levelling Mode'],nil,'N06: and not other pages\' labels')
-- SC-5: the search index files each label under its real section header; Hunter Model is hunters only.
local WW=EllesmereUI.Widgets;local heads={};local header=WW.SectionHeader;WW.SectionHeader=function(_,_,text,...) heads[#heads+1]=text;return nil,30 end
h.clearRows();heads={};h.spec.modules[1].buildPage('Markers',{},0)
eq(table.concat(heads,','),'MARKERS,APPEARANCE,TEXT COLORS','SC-5: Markers labels sit under their real sections')
h.clearRows();heads={};h.spec.modules[1].buildPage('Model',{},0)
local hasHunter=false;for _,t in ipairs(heads) do if t=='HUNTER MODEL' then hasHunter=true end end
eq(hasHunter,true,'SC-5: a hunter indexes the Hunter Model section')
local class=UnitClass;UnitClass=function() return 'Mage','MAGE' end
h.clearRows();heads={};h.spec.modules[1].buildPage('Model',{},0)
hasHunter=false;for _,t in ipairs(heads) do if t=='HUNTER MODEL' then hasHunter=true end end
eq(hasHunter,false,'SC-5: other classes never see Hunter Model labels in search')
UnitClass=class;WW.SectionHeader=header
EllesmereUI.IsSearchPrebuild=prebuildN06;Reset()

-- v1.0 UI pass (Claude, 2026-10-04): Ellesmere row contract, BoE pair, rarity list, preview, Ellesmere bags.
do
Reset()
local function AllRows()
    local out={}
    for _,page in ipairs(h.spec.modules[1].pages) do
        h.clearRows();h.spec.modules[1].buildPage(page,{},0)
        for _,r in ipairs(h.getRows()) do for _,cfg in ipairs(r) do if cfg then out[#out+1]={page=page,cfg=cfg} end end end
    end
    return out
end
local badGate
for _,entry in ipairs(AllRows()) do
    local gate=entry.cfg.disabled
    if gate~=nil and type(gate)~='function' then badGate=entry.page .. ': ' .. tostring(entry.cfg.text) end
    if type(gate)=='function' then gate() end
end
eq(badGate,nil,'V1: every disabled gate is a function, as Ellesmere calls cfg.disabled()')
local function Find(page,text)
    h.clearRows();h.spec.modules[1].buildPage(page,{},0)
    for _,r in ipairs(h.getRows()) do for _,cfg in ipairs(r) do if cfg and cfg.text==text then return cfg end end end
end
local rarity=Find('Automation','Auto-Equip Up To')
eq(rarity.values[5]:find('|cffff8000',1,true)~=nil,true,'V1: Legendary uses Blizzard orange')
eq(rarity.order[6],5,'V1: Legendary is the last rarity choice')
rarity.setValue(5);eq(ns.Char().autoEquipMaxQuality,5,'V1: the Legendary cap is stored')
local boe,confirm=Find('Automation','Auto-Equip Bind-on-Equip'),Find('Automation','Auto-Confirm Bind Prompt')
eq(boe~=nil and confirm~=nil,true,'V1: the BoE equip and bind-prompt toggles are a pair')
ns.Char().autoEquip=false
eq(boe.disabled(),true,'V1: BoE equip waits for Auto-Equip Upgrades')
ns.Char().autoEquip=true;ns.Char().equipBoE=false
eq(confirm.disabled(),true,'V1: bind prompt confirmation waits for Auto-Equip Bind-on-Equip')
ns.Char().equipBoE=true
eq(confirm.disabled(),false,'V1: both on enables bind prompt confirmation')
ns.Char().autoEquip=false;ns.Changed()
eq(type(h.spec.modules[1].getHeaderBuilder('Markers')),'function','V1: Markers has a live preview header')
eq(h.spec.modules[1].getHeaderBuilder('Automation'),nil,'V1: other pages have no header')
local size=Find('Markers','Icon Size')
eq(size.type,'slider','V1: marker size is an Ellesmere slider')
size.setValue(99);eq(ns.Char().markerSize,48,'V1: slider values are clamped')
local opacity=Find('Markers','Marker Opacity');opacity.setValue(50);near(ns.Char().markerOpacity,0.5,'V1: opacity slider stores a fraction')
eq(opacity.getValue(),50,'V1: opacity slider shows a percentage')

-- Ellesmere bags: buttons are found on its own refresh, without a hover.
Reset();h.setEquipped({[18]='item:1'});h.setBags({[0]={'item:2'}})
local hookFn=hooksecurefunc
hooksecurefunc=function(t,k,fn) local o=t[k];t[k]=function(...) local r=o(...);fn(...);return r end end
local eTexture
local slotParent={GetObjectType=function() return 'Frame' end,GetID=function() return 0 end}
local eButton={IconBorder={},GetObjectType=function() return 'ItemButton' end,GetParent=function() return slotParent end,
    GetID=function() return 1 end,IsShown=function() return true end}
function eButton:CreateTexture()
    eTexture={shown=false}
    for _,m in ipairs({'SetTexture','SetBlendMode','SetSize','SetPoint','ClearAllPoints','SetVertexColor'}) do eTexture[m]=function() end end
    function eTexture:Show() self.shown=true end
    function eTexture:Hide() self.shown=false end
    return eTexture
end
slotParent.GetChildren=function() return eButton end
local refreshes=0
EUI_Bags={IsShown=function() return true end,GetChildren=function() return slotParent end,RefreshInventory=function() refreshes=refreshes+1 end}
ns.Char().markBags=true;ns.Changed();ns.RefreshMarkers();Advance(1)
eq(eTexture and eTexture.shown,true,'V1: an Ellesmere bag upgrade is marked without a hover')
EUI_Bags:RefreshInventory();eq(refreshes,1,'V1: the hook keeps Ellesmere refresh behaviour')
eq(#timers>0,true,'V1: an Ellesmere bag refresh queues one marker pass')
ns.Char().markBags=false;ns.Changed()
eq(eTexture.shown,false,'V1: turning bag icons off hides Ellesmere bag marks')
-- GU2: Ellesmere's public overlay hook paints live slots; turning the marks off unregisters it.
local painter
EUI_Bags={IsShown=function() return true end,GetChildren=function() return slotParent end,RefreshInventory=function() end,
    RegisterItemOverlayIcon=function(name,fn) if name=='FHKGear' then painter=fn end end,
    UnregisterItemOverlayIcon=function(name) if name=='FHKGear' then painter=nil end end}
ns.Char().markBags=true;ns.Changed();ns.RefreshMarkers();Advance(1)
eq(type(painter),'function','GU2: Gear registers with the Ellesmere overlay hook')
local overlay={IsShown=function() return true end};overlay.CreateTexture=eButton.CreateTexture
local poolButton={_textOverlay=overlay}
painter(poolButton,{bag=0,slot=1});eq(eTexture.shown,true,'GU2: the overlay marks the upgrade at its live slot')
painter(poolButton,{bag=0,slot=2});eq(eTexture.shown,false,'GU2: a reused pool button at another slot drops the mark')
painter(poolButton,{bag=0,slot=0});eq(eTexture.shown,false,'GU2: placeholder slots never mark')
painter(poolButton,{bag=0,slot=1});ns.RefreshMarkers();Advance(1);eq(eTexture.shown,true,'GU2: a marker pass keeps the overlay mark at its last slot')
ns.Char().markBags=false;ns.Changed();ns.RefreshMarkers()
eq(painter,nil,'GU2: bag marks off unregisters the overlay (zero cost while off)')
eq(eTexture.shown,false,'GU2: and hides the overlay mark')
-- GU2: a Blizzard pool button reused for another slot is read live, never from the stored slot.
EUI_Bags=nil;local liveSlot=1;local bTexture
local bButton={IsShown=function() return true end,GetBagID=function() return 0 end,GetID=function() return liveSlot end}
function bButton:CreateTexture() local t=eButton.CreateTexture(self);bTexture=t;return t end
local cFrame={IsShown=function() return true end,EnumerateValidItems=function() local done=false;return function() if not done then done=true;return 1,bButton end end end}
ContainerFrameUtil_EnumerateContainerFrames=function() return ipairs({cFrame}) end
ns.Char().markBags=true;ns.Changed();ns.RefreshMarkers();Advance(1)
eq(bTexture and bTexture.shown,true,'GU2: Blizzard bag buttons are found through the container enumerator')
liveSlot=2;ns.RefreshMarkers();Advance(1)
eq(bTexture.shown,false,'GU2: a recycled Blizzard button no longer carries the old slot mark')
ContainerFrameUtil_EnumerateContainerFrames=nil;ns.Char().markBags=false;ns.Changed()
hooksecurefunc=hookFn;Reset()
end

-- Bags (player question 2026-10-04): identical bags fill each empty bag slot once; quiver haste counts once.
do
Reset()
local linen=Item(320,'INVTYPE_BAG',{},{equip='6 Slot Bag'})
h.setEquipped({[18]='item:1'})
h.setBags({[0]={linen,linen,linen,linen,linen,linen,linen,linen,linen,linen}})
local equips=0
local equipFn=EquipCursorItem
EquipCursorItem=function(slot) equips=equips+1;return equipFn(slot) end
ns.Char().autoEquip=true;ns.Char().autoBags=true;ns.Changed()
for _=1,12 do Advance(1);h.Fire("PLAYER_EQUIPMENT_CHANGED");h.Fire("BAG_UPDATE_DELAYED") end
local filled=0
for slot=20,23 do if h.getEquipped()[slot]==linen then filled=filled+1 end end
eq(filled,4,'bags: each empty bag slot gets one bag')
eq(equips,4,'bags: no bag is equipped twice and no identical bag replaces another')
local left=0;for _,link in pairs(h.getBags()[0]) do if link==linen then left=left+1 end end
eq(left,6,'bags: the other six identical bags stay in the bags')
ns.Char().autoBags=false;ns.Changed();h.setEquipped({[18]='item:1'});h.setBags({[0]={linen}});equips=0
for _=1,3 do Advance(1) end
eq(equips,0,'bags: Auto-Equip Empty Bag Upgrades off equips no bag')
EquipCursorItem=equipFn;ns.Char().autoEquip=false;ns.Changed()
Reset()
local bow=Item(321,'INVTYPE_RANGED',{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=6},{subclass=2})
local quiverA=Item(322,'INVTYPE_QUIVER',{},{subclass=2,equip='Equip: Increases ranged attack speed by 15%.'})
local quiverB=Item(323,'INVTYPE_QUIVER',{},{subclass=2,equip='Equip: Increases ranged attack speed by 15%.'})
local one=E.SetupScore({[18]={info=ns.Items.Read(bow)},[20]={info=ns.Items.Read(quiverA)}})
local two=E.SetupScore({[18]={info=ns.Items.Read(bow)},[20]={info=ns.Items.Read(quiverA)},[21]={info=ns.Items.Read(quiverB)}})
near(two,one+E.Score(ns.Items.Read(quiverB),21),'quivers: a second quiver adds no extra ranged haste')
Reset()
Reset()
local general=Item(324,'INVTYPE_BAG',{},{equip='10 Slot Bag'});h.ITEMS[324][3]=1
local herb=Item(325,'INVTYPE_BAG',{},{equip='12 Slot Herb Bag',subclass=2});h.ITEMS[325][3]=1
eq(E.BagCapacity(ns.Items.Read(general)),10,'bags: general bag slots count')
eq(E.BagCapacity(ns.Items.Read(herb)),0,'bags: profession bag slots never count as general space')
h.setEquipped({[18]='item:1',[20]=general});h.setBags({[0]={herb}})
eq(#E.BagUpgrades(),0,'bags: a profession bag is never a candidate (not over a general bag, not into an empty slot)')
Reset()
end

-- Hunter model (Claude, 2026-10-04). Mocked client stat API; numbers are fixtures, not Forever values.
do
Reset()
local api={UnitRangedAttackPower=function() return 100,20,0 end,UnitAttackPower=function() return 60,0,0 end,
    GetRangedCritChance=function() return 6 end,GetCritChance=function() return 5 end,GetRangedHitModifier=function() return 0 end,
    GetHitModifier=function() return 0 end,GetRangedHaste=function() return 0,0 end,
    UnitStat=function() return 50,50,0,0 end,
    GetRangedAttackPowerForStat=function(i,v) return i==2 and v*2 or 0 end,GetAttackPowerForStat=function(i,v) return (i==1 or i==2) and v or 0 end,
    GetCritChanceFromStat=function(i,v) return i==2 and v/2000 or 0 end,
    UnitExists=function() return false end,UnitIsDead=function() return false end}
local saved={}
for k,v in pairs(api) do saved[k]=_G[k];_G[k]=v end
local skills={[45]={rank=100,modifier=0},[226]={rank=60,modifier=0},[46]={rank=100,modifier=0}}
local savedSkill,savedSpell,savedKnown=C_SkillInfo,C_Spell,IsPlayerSpell
C_SkillInfo={GetSkillLineInfoByID=function(id) return skills[id] end}
local spells={['Aimed Shot']={spellID=19434,castTime=2000,text='An aimed shot that increases ranged damage by 20.'},
    ['Arcane Shot']={spellID=3044,castTime=0,text='An instant shot that causes 20 Arcane damage.'}}
local names={[19434]='Aimed Shot',[3044]='Arcane Shot',[2643]='Multi-Shot',[1978]='Serpent Sting',[2973]='Raptor Strike',[19485]='Mortal Shots'}
C_Spell={GetSpellInfo=function(key)
        if type(key)=='number' then return names[key] and {name=names[key],spellID=key,castTime=0} or nil end
        local s=spells[key];return s and {name=key,spellID=s.spellID,castTime=s.castTime} or nil end,
    GetSpellDescription=function(id) for _,s in pairs(spells) do if s.spellID==id then return s.text end end end}
IsPlayerSpell=function(id) return id==19434 or id==3044 or id==1515 end
local function Bow(id,dps,speed,sub)
    return Item(id,'INVTYPE_RANGED',{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=dps},{subclass=sub or 2,speed=('%.2f'):format(speed),low=1,high=2})
end
local arrows=Item(340,'INVTYPE_AMMO',{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=2},{subclass=2});h.ITEMS[340][3]=6
local worn=Bow(341,10,2.5)
h.setEquipped({[18]=worn,[0]=arrows});ns.Changed()
local M=ns.HunterModel
eq(M.Available(),true,'HM: available for a Hunter with the stat API')
local w,source=ns.Weights.Current()
eq(source,'Hunter model (live stats)','HM: Automatic source uses the Hunter model')
near(w.Agility,1.05,'HM: Agility is the yardstick (default Agility weight)')
eq(w.Agility>2*w.RangedAttackPower,true,'HM: 1 Agility beats 2 ranged AP because it also adds crit')
eq(w.Hit>0 and w.Crit>0,true,'HM: hit and crit have value below the cap')
local slow,fast=Bow(342,12,3.0),Bow(343,12,1.8)
local vs,ks=M.WeaponValue(ns.Items.Read(slow),18,w)
local vf=M.WeaponValue(ns.Items.Read(fast),18,w)
eq(vs>vf,true,'HM: same DPS, the slower bow is worth more (Aimed Shot hits harder)')
eq(ks,true,'HM: weapon value is known with skill and ammo read')
local crossbow=Bow(344,12,3.0,18)
eq(M.WeaponValue(ns.Items.Read(crossbow),18,w)<vs,true,'HM: low crossbow skill (60/100) costs misses')
local gun=Bow(345,12,3.0,3)
local _,gk,gwhy=M.WeaponValue(ns.Items.Read(gun),18,w)
eq(gk,false,'HM: a gun with only arrows in your bags is not automatic')
eq(gwhy,'No matching ammo in your bags','HM: and says why')
eq(E.AutomationSafe(ns.Items.Read(gun)),false,'HM: so auto-equip leaves it alone')
eq(E.AutomationSafe(ns.Items.Read(slow)),true,'HM: a usable bow with arrows stays automatic')
local detected=w.dps.RangedAttackPower
ns.Char().hunterPet='none';ns.Changed()
local noPet=ns.Weights.Current().dps.RangedAttackPower
ns.Char().hunterPet='pet';ns.Changed()
eq(ns.Weights.Current().dps.RangedAttackPower>noPet,true,'HM: with a pet, ranged AP also feeds 22% to the pet')
near(detected,ns.Weights.Current().dps.RangedAttackPower,'HM: Detect counts the pet without Lone Wolf, even with no pet out (no swap churn)')
local knownFn=IsPlayerSpell;IsPlayerSpell=function(id) return id==19434 or id==3044 end;ns.Char().hunterPet='auto';ns.Changed()
near(ns.Weights.Current().dps.RangedAttackPower,noPet,'GU10: before Tame Beast, Detect counts no pet')
IsPlayerSpell=knownFn;ns.Char().hunterPet='pet';ns.Changed()
ns.Char().hunterPet='auto';ns.Char().hunterTalents.loneWolf=1;ns.Changed()
near(ns.Weights.Current().dps.RangedAttackPower,noPet*1.2,'HM: Lone Wolf with no pet out: no pet share, +20% damage')
ns.Char().hunterTalents={};ns.Changed()
local crit0=ns.Weights.Current().dps.Crit
ns.Char().hunterTalents.mortalShots=5;ns.Changed()
eq(ns.Weights.Current().dps.Crit>crit0,true,'HM: Mortal Shots raises the value of crit')
eq(M.TalentRank('mortalShots'),5,'HM: a rank you set is used')
ns.Char().hunterTalents={};ns.Changed()
GetRangedHitModifier=function() return 9 end;ns.Changed()
near(ns.Weights.Current().Hit,0,'HM: hit above the miss cap is worth nothing')
GetRangedHitModifier=api.GetRangedHitModifier;ns.Changed()
local savedTalents=C_SpecializationInfo
C_SpecializationInfo={GetTalentInfo=function(q) if q.specializationIndex==2 and q.tier==2 and q.column==1 then return {name='Mortal Shots',rank=3} end end}
M.Invalidate()
local rank,how=M.TalentRank('mortalShots')
eq(rank,3,'HM: talent window ranks are read when the client answers')
eq(how,'talent window','HM: and the method is reported')
C_SpecializationInfo=savedTalents;M.Invalidate()
local spec=select(2,ns.Weights.ClassSpec())
ns.Weights.Custom('HUNTER',spec,ns.Weights.Phase(),true).Agility=2;ns.Changed()
eq(ns.Weights.Current().scale,nil,'HM: your own weights switch the model weapon value off')
local custom=ns.Weights.Custom('HUNTER',spec,ns.Weights.Phase());for k in pairs(custom) do custom[k]=nil end;ns.Changed()
local report=M.Report()
eq(report:find('Model DPS',1,true)~=nil,true,'HM: the report shows the model DPS')
eq(report:find('Aimed Shot: spell 19434, bonus 20',1,true)~=nil,true,'HM: the report shows parsed abilities')
ns.Char().source='weights';ns.Changed()
eq(select(2,ns.Weights.Current())~='Hunter model (live stats)',true,'HM: Stat Weights source turns the model off')
ns.Char().source='auto'
for k,v in pairs(saved) do _G[k]=v end
C_SkillInfo,C_Spell,IsPlayerSpell=savedSkill,savedSpell,savedKnown;ns.Changed();Reset()
end

-- Bag slots by client inventory ID (Forever uses the retail offset) and the reagent bag.
do
Reset()
local saveMap=C_Container.ContainerIDToInventoryID
C_Container.ContainerIDToInventoryID=function(bag) return 30+bag end
local hadReagent=E.HAS_REAGENT_BAG
E.HAS_REAGENT_BAG=true;E.EQUIP_SLOTS[#E.EQUIP_SLOTS+1]=24
local general=Item(350,'INVTYPE_BAG',{},{equip='8 Slot Bag'});h.ITEMS[350][3]=1
local reagent=Item(351,'INVTYPE_BAG',{},{equip='16 Slot Reagent Bag',subclass=11});h.ITEMS[351][3]=1
h.setEquipped({[18]='item:1'});h.setBags({[0]={general,general,reagent}})
eq(E.Inventory(20),31,'bag slots: bag 1 uses the client inventory ID')
eq(E.Inventory(24),35,'bag slots: the reagent bag too')
eq(E.FromInventory(35),24,'bag slots: and maps back')
local reagentSlots=E.Slots(ns.Items.Read(reagent))
eq(reagentSlots and reagentSlots[1],24,'reagent bag fits only the reagent slot')
ns.Char().autoEquip=true;ns.Char().autoBags=true;ns.Changed()
for _=1,8 do Advance(1);h.Fire('PLAYER_EQUIPMENT_CHANGED');h.Fire('BAG_UPDATE_DELAYED') end
local eqd=h.getEquipped()
eq(eqd[31]==general and eqd[32]==general,true,'bag slots: general bags go to the real bag slots')
eq(eqd[35],reagent,'bag slots: the reagent bag goes to the reagent slot')
eq(eqd[20],nil,'bag slots: nothing is equipped to the Classic IDs on this client')
table.remove(E.EQUIP_SLOTS);E.HAS_REAGENT_BAG=hadReagent;C_Container.ContainerIDToInventoryID=saveMap
ns.Char().autoEquip=false;ns.Changed();Reset()
eq(select(2,ns.HunterModel.TalentRank('mortalShots'))~='talent window',true,'HM: talent window ranks are forgotten when the client stops answering')
end

-- v1.0 audit stress tests (Claude, 2026-10-04): interactions, loops, refresh triggers and cost. E2 only.
do
h.setTime(h.time()+10) -- earlier fixtures drop queued timers; let the model queue expire
Reset()
local api2={UnitRangedAttackPower=function() return 100,20,0 end,UnitAttackPower=function() return 60,0,0 end,
    GetRangedCritChance=function() return 6 end,GetCritChance=function() return 5 end,GetRangedHitModifier=function() return 0 end,
    GetHitModifier=function() return 0 end,GetRangedHaste=function() return 0,0 end,UnitStat=function() return 50,50,0,0 end,
    GetRangedAttackPowerForStat=function(i,v) return i==2 and v*2 or 0 end,GetAttackPowerForStat=function(i,v) return (i==1 or i==2) and v or 0 end,
    GetCritChanceFromStat=function(i,v) return i==2 and v/2000 or 0 end,UnitExists=function() return true end,UnitIsDead=function() return false end}
local saved2={}
for k,v in pairs(api2) do saved2[k]=_G[k];_G[k]=v end
local skillCalls=0
local skillRanks={[45]=100,[46]=100,[226]=60}
local oldSkill,oldSpell,oldKnown=C_SkillInfo,C_Spell,IsPlayerSpell
C_SkillInfo={GetSkillLineInfoByID=function(id) skillCalls=skillCalls+1;return skillRanks[id] and {rank=skillRanks[id],modifier=0,name=({[45]='Bows',[46]='Guns',[226]='Crossbows'})[id]} or nil end}
C_Spell={GetSpellInfo=function(key) if key=='Aimed Shot' or key==19434 then return {name='Aimed Shot',spellID=19434,castTime=2000} end end,
    GetSpellDescription=function(id) if id==19434 then return 'An aimed shot that increases ranged damage by 20.' end end}
IsPlayerSpell=function(id) return id==19434 or id==1515 end
local function Weapon(id,dps,speed,sub) return Item(id,'INVTYPE_RANGED',{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=dps},{subclass=sub,speed=('%.2f'):format(speed),low=1,high=2}) end
local arrows2=Item(360,'INVTYPE_AMMO',{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=2},{subclass=2});h.ITEMS[360][3]=6
local bullets=Item(361,'INVTYPE_AMMO',{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=2},{subclass=3});h.ITEMS[361][3]=6
local bow1=Weapon(362,8,2.6,2)

-- 1. A gun with no bullets stays manual; buying bullets makes it automatic without any other change.
local gun2=Weapon(363,14,2.8,3)
h.setEquipped({[18]=bow1,[0]=arrows2});h.setBags({[0]={gun2}});ns.Changed()
eq(E.AutomationSafe(ns.Items.Read(gun2)),false,'stress: gun without bullets is manual')
h.setBags({[0]={gun2,bullets}});h.Fire('BAG_UPDATE_DELAYED');Advance(1)
eq(E.AutomationSafe(ns.Items.Read(gun2)),true,'stress: bullets bought, the gun becomes automatic (ammo refresh)')

-- 2. Weapon skill: flagged with the gain once trained; a skill-up refreshes the value.
local xbow=Weapon(364,14,2.8,18)
local w2=ns.Weights.Current()
local note=ns.HunterModel.SkillNote(ns.Items.Read(xbow),18,w2)
eq(note and note.name,'Crossbows','stress: skill note names the weapon skill')
eq(note and note.skill==60 and note.cap==100 and note.gain>0,true,'stress: skill note shows 60/100 and the gain once trained')
local tipLines={}
local tip={AddLine=function(_,text) tipLines[#tipLines+1]=text end}
ns.AddTooltipLine(tip,xbow)
local flagged=false;for _,text in ipairs(tipLines) do if text:find('Crossbows skill 60/100',1,true) then flagged=true end end
eq(flagged,true,'stress: the tooltip flags the weapon skill')
local before=ns.Engine.Score(ns.Items.Read(xbow),18)
skillRanks[226]=100;h.Fire('SKILL_LINES_CHANGED');Advance(1)
eq(ns.Engine.Score(ns.Items.Read(xbow),18)>before,true,'stress: a skill-up rescores the crossbow')
eq(ns.HunterModel.SkillNote(ns.Items.Read(xbow),18,ns.Weights.Current()),nil,'stress: no flag once trained')
skillRanks[226]=60

-- 3. Swap-loop stability: equip until settled, then ten more passes change nothing.
Reset();h.setEquipped({[18]=bow1,[0]=arrows2})
local ringA=Item(365,'INVTYPE_FINGER',{ITEM_MOD_AGILITY_SHORT=4})
local ringB=Item(366,'INVTYPE_FINGER',{},{equip='Equip: Improves your chance to get a critical strike by 1%.'})
local ringC=Item(367,'INVTYPE_FINGER',{ITEM_MOD_AGILITY_SHORT=3})
local hitBelt=Item(368,'INVTYPE_WAIST',{},{equip='Equip: Improves your chance to hit by 1%.'})
local bow2,bow3=Weapon(369,9,3.0,2),Weapon(370,9.5,2.0,2)
h.setBags({[0]={ringA,ringB,ringC,hitBelt,bow2,bow3}})
local equips2,history=0,{}
local equipOld=EquipCursorItem
EquipCursorItem=function(slot) equips2=equips2+1;history[#history+1]=slot;return equipOld(slot) end
ns.Char().autoEquip=true;ns.Char().percentHitUnits=nil;ns.Char().ratingUnits='percent';ns.Changed()
for _=1,20 do Advance(1);h.Fire('PLAYER_EQUIPMENT_CHANGED');h.Fire('BAG_UPDATE_DELAYED') end
local settled=equips2
for _=1,10 do Advance(1);h.Fire('PLAYER_EQUIPMENT_CHANGED');h.Fire('BAG_UPDATE_DELAYED') end
eq(equips2,settled,'stress: once settled, further passes equip nothing (no swap loop)')
eq(settled>0 and settled<=6,true,'stress: each upgrade is equipped at most once')
EquipCursorItem=equipOld;ns.Char().autoEquip=false;ns.Changed()

-- 4. Quivers: a worn quiver keeps its slot; a better general bag never replaces it.
Reset()
local quiver=Item(371,'INVTYPE_QUIVER',{},{subclass=2,equip='Equip: Increases ranged attack speed by 15%.'});h.ITEMS[371][3]=11
local big=Item(372,'INVTYPE_BAG',{},{equip='16 Slot Bag'});h.ITEMS[372][3]=1
local small=Item(373,'INVTYPE_BAG',{},{equip='6 Slot Bag'});h.ITEMS[373][3]=1
local betterQuiver=Item(374,'INVTYPE_QUIVER',{},{subclass=2,equip='18 Slot Quiver. Equip: Increases ranged attack speed by 15%.'});h.ITEMS[374][3]=11
h.setEquipped({[18]=bow1,[20]=quiver,[21]=small,[22]=small,[23]=small});h.setBags({[0]={big}})
local targets={};for _,job in ipairs(E.BagUpgrades()) do targets[#targets+1]=job.target end
eq(#targets>0,true,'stress: the bigger bag is still an upgrade')
local hitQuiver=false;for _,t in ipairs(targets) do if t==20 then hitQuiver=true end end
eq(hitQuiver,false,'stress: a general bag never replaces the worn quiver')
local slots=E.Slots(ns.Items.Read(betterQuiver))
eq(slots and #slots==1 and slots[1]==20,true,'stress: a new quiver only replaces the quiver')

-- 5. Missing client conversions: the model still works and says what it estimated.
Reset();h.setEquipped({[18]=bow1,[0]=arrows2})
local rapFor=GetRangedAttackPowerForStat;GetRangedAttackPowerForStat=nil;ns.Changed()
local report2=ns.HunterModel.Report()
eq(report2:find('agility to ranged AP',1,true)~=nil,true,'stress: a missing conversion is reported as an estimate')
eq(ns.Weights.Current().Agility~=nil,true,'stress: weights still build without it')
GetRangedAttackPowerForStat=rapFor

-- 6. Slider bursts settle into one change.
Reset()
local changes=0
local changedFn=h.options.Changed
h.options.Changed=function(...) changes=changes+1;return changedFn(...) end
h.clearRows();h.spec.modules[1].buildPage('Markers',{},0)
local sizeRow;for _,r in ipairs(h.getRows()) do for _,cfg in ipairs(r) do if cfg and cfg.text=='Icon Size' then sizeRow=cfg end end end
for v=10,40 do sizeRow.setValue(v) end
eq(changes,0,'stress: a slider drag does no full change while dragging')
Advance(1)
eq(changes,1,'stress: and exactly one when it settles')
eq(ns.Char().markerSize,40,'stress: the last value is kept')
h.options.Changed=changedFn

-- 7. Cost: a full bag pass and 100 warm hovers with the model on.
Reset();h.setEquipped({[18]=bow1,[0]=arrows2})
local many={}
for i=1,36 do many[#many+1]=Weapon(400+i,5+i%7,1.8+(i%5)*0.3,({2,3,18})[i%3+1]) end
for i=1,36 do many[#many+1]=Item(450+i,'INVTYPE_FINGER',{ITEM_MOD_AGILITY_SHORT=i%5}) end
h.setBags({[0]=many});ns.Changed()
skillCalls=0
local statsBefore=h.getStats()
E.BagUpgrades()
eq(skillCalls<=3,true,'stress: one full pass reads each weapon skill line once (' .. skillCalls .. ' reads)')
ns.AddTooltipLine(tip,many[1]);ns.AddTooltipLine(tip,many[40]) -- first hover reads by link (bag passes cache by bag position)
local warmStats=h.getStats()
skillCalls=0
for _=1,100 do ns.AddTooltipLine(tip,many[1]);ns.AddTooltipLine(tip,many[40]) end
eq(h.getStats(),warmStats,'stress: 100 warm hovers read no item stats')
eq(skillCalls,0,'stress: and no weapon skills')
eq(warmStats-statsBefore<=#many,true,'stress: the pass reads each item at most once')

for k,v in pairs(saved2) do _G[k]=v end
C_SkillInfo,C_Spell,IsPlayerSpell=oldSkill,oldSpell,oldKnown;ns.Changed();Reset()
end

-- Ammo (player question 2026-10-04): best usable ammo for the worn weapon, a new tier on the level-up.
do
h.setTime(h.time()+10)
Reset();h.setLevel(9)
local bowA=Item(380,'INVTYPE_RANGED',{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=6},{subclass=2})
local rough=Item(381,'INVTYPE_AMMO',{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=2},{subclass=2,quality=1});h.ITEMS[381][3]=6
local sharp=Item(382,'INVTYPE_AMMO',{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=4},{subclass=2,quality=1,req=10});h.ITEMS[382][3]=6
local shot=Item(383,'INVTYPE_AMMO',{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=9},{subclass=3,quality=1});h.ITEMS[383][3]=6
h.setEquipped({[18]=bowA,[0]=rough});h.setBags({[0]={sharp,shot}})
ns.Char().autoEquip=true;ns.Changed()
for _=1,3 do Advance(1) end
eq(h.getEquipped()[0],rough,'ammo: level-10 arrows wait at level 9; bullets never fit a bow')
local tipText={}
local tip={AddLine=function(_,text) tipText[#tipText+1]=text end}
ns.AddTooltipLine(tip,sharp);ns.AddTooltipLine(tip,shot)
eq(tipText[1],'Gear: usable at level 10','ammo: the tooltip says when the next tier is usable')
eq(tipText[2],'Gear: does not fit your ranged weapon','ammo: and when ammo is the wrong type')
h.setLevel(10);h.Fire('PLAYER_LEVEL_UP',10)
for _=1,4 do Advance(1) end
eq(h.getEquipped()[0],sharp,'ammo: the new tier is equipped right after the level-up')
for _=1,3 do Advance(1);h.Fire('PLAYER_EQUIPMENT_CHANGED');h.Fire('BAG_UPDATE_DELAYED') end
eq(h.getEquipped()[0],sharp,'ammo: and stays (no swapping back)')
h.setEquipped({[18]=bowA});h.setBags({[0]={rough}});h.Fire('PLAYER_EQUIPMENT_CHANGED')
for _=1,3 do Advance(1) end
eq(h.getEquipped()[0],rough,'ammo: an empty ammo slot is filled')
ns.Char().autoAmmo=false;h.setEquipped({[18]=bowA,[0]=rough});h.setBags({[0]={Item(384,'INVTYPE_AMMO',{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=5},{subclass=2,quality=1})}})
h.ITEMS[384][3]=6;ns.Changed()
for _=1,3 do Advance(1) end
eq(h.getEquipped()[0],rough,'ammo: Auto-Equip Better Ammo off leaves the ammo slot alone')
-- GC2: a handful of better arrows never replaces a full quiver.
local counts={[381]=1000,[382]=12};local countAPI=GetItemCount;GetItemCount=function(id) return counts[id] end
ns.Char().autoAmmo=true;h.setEquipped({[18]=bowA,[0]=rough});h.setBags({[0]={sharp}});ns.Changed()
for _=1,3 do Advance(1) end
eq(h.getEquipped()[0],rough,'GC2: 12 better arrows do not replace 1000 worse ones')
counts[382]=400;h.Fire('BAG_UPDATE_DELAYED');for _=1,3 do Advance(1) end
eq(h.getEquipped()[0],sharp,'GC2: a real stack of better arrows goes on')
GetItemCount=countAPI;ns.Char().autoAmmo=false
ns.Char().autoAmmo=true;ns.Char().autoEquip=false;ns.Changed();Reset()
end

-- Pop-ups (player request 2026-10-04): Ellesmere-style cards replace AutoGear's window. Stub UI objects.
do
h.setTime(h.time()+10)
Reset()
local created={}
local function Stub()
    local o={shown=true,height=0,scripts={},text=''}
    return setmetatable(o,{__index=function(t,k)
        if k=='IsShown' then return function(self) return self.shown end end
        if k=='Show' then return function(self) self.shown=true end end
        if k=='Hide' then return function(self) self.shown=false end end
        if k=='SetShown' then return function(self,v) self.shown=v and true or false end end
        if k=='SetHeight' then return function(self,v) self.height=v end end
        if k=='GetHeight' then return function(self) return self.height end end
        if k=='SetText' then return function(self,v) self.text=v end end
        if k=='SetScript' then return function(self,what,fn) self.scripts[what]=fn end end
        if k=='CreateTexture' or k=='CreateFontString' or k=='CreateAnimationGroup' or k=='CreateAnimation' then return function() local s=Stub();created[#created+1]=s;return s end end
        if k=='GetEffectiveScale' then return function() return 1 end end
        if type(k)=='string' and k:match('^%u') then return function() end end
        return nil
    end})
end
local oldCreate,oldParent=CreateFrame,UIParent
CreateFrame=function(kind) local f=Stub();f.kind=kind;created[#created+1]=f;return f end
UIParent=Stub()
local equipLink=Item(390,'INVTYPE_FINGER',{ITEM_MOD_AGILITY_SHORT=6,ITEM_MOD_STAMINA_SHORT=1})
local oldRing=Item(391,'INVTYPE_FINGER',{ITEM_MOD_STAMINA_SHORT=3})
eq(ns.Notify.Equipped(equipLink,3.2,oldRing),true,'pop-ups: an Equipped card is shown')
local stats=ns.Notify.StatChanges(ns.Items.Read(equipLink),oldRing)
eq(stats:find('+6 Agility',1,true)~=nil and stats:find('-2 Stamina',1,true)~=nil,true,'pop-ups: the card lists the stat changes')
ns.Char().popActions=false
eq(ns.Notify.Equipped(equipLink,3.2,oldRing),false,'pop-ups: Action Pop-Ups off shows nothing')
ns.Char().popActions=true
-- Upgrade Found: primed at login (no cards for old items), then once per new upgrade.
ns.Notify.ResetFound()
local shown={}
local realShow=ns.Notify.Show
ns.Notify.Show=function(kind,data) shown[#shown+1]={kind=kind,data=data};return true end
local ring2=Item(392,'INVTYPE_FINGER',{ITEM_MOD_AGILITY_SHORT=9})
local ring3=Item(393,'INVTYPE_FINGER',{ITEM_MOD_AGILITY_SHORT=12})
h.setEquipped({[18]='item:1',[11]=oldRing,[12]=oldRing});h.setBags({[0]={ring2}});ns.Changed()
ns.Notify.ScanFound()
eq(#shown,0,'pop-ups: the first pass after login shows nothing for items already in the bags')
h.setBags({[0]={ring2,ring3}});ns.Notify.ScanFound()
eq(#shown,1,'pop-ups: a new upgrade shows one Upgrade Found card')
eq(shown[1] and shown[1].kind,'found','pop-ups: as an Upgrade Found card')
eq(shown[1] and shown[1].data.job~=nil,true,'pop-ups: with Equip and Never Equip')
ns.Notify.ScanFound()
eq(#shown,1,'pop-ups: never twice for the same item')
local ring4=Item(394,'INVTYPE_FINGER',{ITEM_MOD_AGILITY_SHORT=15})
ns.Char().autoEquip=true;ns.Changed();h.setBags({[0]={ring2,ring3,ring4}});ns.Notify.ScanFound()
eq(#shown,1,'pop-ups: no Upgrade Found card for an item auto-equip will equip itself')
ns.Char().autoEquip=false;h.setLevel(60);ns.Changed()
eq(ns.FoundPopUps(),false,'pop-ups: no Upgrade Found pop-ups at 60 in Levelling Mode')
h.setLevel(20);ns.Changed()
-- Weapon skill: the Equipped card names an untrained skill; Skill Maxed only after real training.
local oldSkillInfo=C_SkillInfo
local ranks={[45]=60}
C_SkillInfo={GetSkillLineInfoByID=function(id) return ranks[id] and {rank=ranks[id],modifier=0,name='Bows'} or nil end}
local bowS=Item(395,'INVTYPE_RANGED',{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=8},{subclass=2,speed='2.60',low=1,high=2})
local count=#shown
ns.Notify.Equipped(bowS,2,nil)
eq(shown[count+1] and shown[count+1].data.detail:find('Bows skill 60/100',1,true)~=nil,true,'skill: the Equipped card names an untrained weapon skill')
h.setEquipped({[18]=bowS});ns.Notify.ResetSkills();ns.Notify.SkillCheck()
eq(#shown,count+1,'skill: the first check only remembers where the skill stands')
ranks[45]=100;ns.Notify.SkillCheck()
eq(shown[count+2] and shown[count+2].kind,'skill','skill: reaching the cap after training shows Weapon Skill Maxed')
ns.Notify.SkillCheck()
eq(#shown,count+2,'skill: once only')
h.setLevel(21);ns.Notify.SkillCheck();ranks[45]=105;ns.Notify.SkillCheck()
eq(#shown,count+2,'skill: catching up after a level-up (5 points) shows nothing')
C_SkillInfo=oldSkillInfo;h.setLevel(20);ns.Changed()
ns.Notify.Show=realShow
-- Never Equip on a real card stores the exclusion.
ns.Notify.Show('found',{link=ring3,title='Upgrade Found',job={bag=0,slot=2,target=11}})
local never
-- Find the card's Never Equip button through its label text.
for _,o in ipairs(created) do if o.label and o.label.text=='Never Equip' then never=o end end
eq(never~=nil,true,'pop-ups: the card has a Never Equip button')
if never then never.scripts.OnClick();eq(ns.Char().ignore[393],true,'pop-ups: Never Equip adds the item to Never Equip') end
ns.Char().ignore={}
CreateFrame,UIParent=oldCreate,oldParent
Reset()
end
