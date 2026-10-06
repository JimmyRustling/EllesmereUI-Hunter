-- FHK Gear: settings, lifecycle and public bridges.
-- Adapted from AutoGear; CC BY-NC-SA 4.0. See LICENSE.md.
if EUI_CLIENT_BLOCKED then return end
local ADDON, ns = ...
local S = ns.Safe
ns.VERSION, ns.MAX_LEVEL = '0.5.3', 60
_G.FHKGearNS = ns
local DEFAULTS = {
    autoEquip=false,autoQuest=false,autoRoll=false,levellingOnly=true,
    markQuest=true,tooltip=true,chat=true,markBags=false,markRoll=false,markCharacter=false,
    equipBoE=true,autoEquipMaxQuality=2,equipBoEMaxQuality=2,phase='auto',phaseLevel=60,source='auto',
    ratingUnits='unknown',comparisonModel='weights',fightLength=15,meleeShare=0.175,
    incomingHits=0,useUptime=0.8,allowEstimates=true,targetType='any',objective='damage',weaponStyle='preset',
    profileIncludeWeights=false,profileIncludeRules=false,
    rollNeedUpgrades=true,rollGreedOthers=true,confirmEquipBinds=false,confirmLootRolls=false,autoBags=false,
    markerStyle='border',greedMarkerStyle='coin',markerSize=18,markerOpacity=1,markerPosition='TOPRIGHT',markerOffsetX=0,markerOffsetY=0,
    hunterPet='auto',multiTargets=1,autoAmmo=true,popActions=true,popFound=true,popDuration=8,
    -- 0.5.3 (review G2, G4): roll etiquette and the rarity cap scope. All off by default.
    rollMinGain=0,rollNeedArmorType=false,rollNeedMainStat=false,rarityCapBoEOnly=false,
    -- Non-gear loot (player, 2026-10-06): your roll by default; Greed or Need up to a rarity on request.
    rollNonGear='player',rollNonGearMaxQuality=2,
}
ns.CHAR_DEFAULTS = DEFAULTS
-- Colour tokens (review G12): every tooltip, status and pop-up colour. The player's own value lives in
-- FHKGearCharDB.textColours[key] = {r,g,b}; markers keep their own markerColours (upgrade, greed).
local COLOURS={upgrade={0.25,1,0.35},muted={0.6,0.6,0.6},greed={1,0.78,0.2},skill={1,0.78,0.2},
    caution={1,0.78,0.2},gain={0.25,1,0.35},loss={1,0.35,0.35}}
ns.COLOUR_DEFAULTS=COLOURS
ns.COLOUR_KEYS={'upgrade','muted','greed','skill','caution','gain','loss'}
-- Color-blind preset (review G14): Okabe-Ito sky blue and orange, never the uncommon-quality green.
ns.COLOURBLIND={upgrade={0.34,0.71,0.91},greed={0.9,0.62,0},gain={0.34,0.71,0.91},loss={0.9,0.62,0}}
local function ValidColour(c) return S.Table(c) and S.Number(c[1]) and S.Number(c[2]) and S.Number(c[3]) and c[1]>=0 and c[1]<=1 and c[2]>=0 and c[2]<=1 and c[3]>=0 and c[3]<=1 end
ns.ValidColour=ValidColour
function ns.Colour(key)
    local own=ns.Char().textColours[key]
    if ValidColour(own) then return own[1],own[2],own[3] end
    local d=COLOURS[key] or COLOURS.muted
    return d[1],d[2],d[3]
end
-- One click (review G14): marker shape and colors plus the matching text tokens. Resets undo it.
function ns.ApplyColourBlindPreset()
    local c,p=ns.Char(),ns.COLOURBLIND
    c.markerStyle,c.greedMarkerStyle='arrow','coin'
    c.markerColours={upgrade={p.upgrade[1],p.upgrade[2],p.upgrade[3]},greed={p.greed[1],p.greed[2],p.greed[3]}}
    for key,colour in pairs(p) do c.textColours[key]={colour[1],colour[2],colour[3]} end
end
function ns.ColourCode(key)
    local r,g,b=ns.Colour(key)
    return ('|cff%02x%02x%02x'):format(math.floor(r*255+0.5),math.floor(g*255+0.5),math.floor(b*255+0.5))
end
local char,account,levelHint
function ns.Char()
    if not S.Table(FHKGearCharDB) then FHKGearCharDB = {} end
    if char==FHKGearCharDB then return char end
    -- Rebind if SavedVariables is assigned after an early consumer.
    if char ~= FHKGearCharDB then char = FHKGearCharDB end
    -- 0.5.3 test builds saved a Greed on Non-Gear Loot toggle: carry an explicit choice over once.
    if char.rollGreedNonGear~=nil then
        if char.rollNonGear==nil and char.rollGreedNonGear==true then char.rollNonGear='greed' end
        char.rollGreedNonGear=nil
    end
    for k,v in pairs(DEFAULTS) do
        local value=char[k]
        if value==nil then char[k]=v
        elseif not S.Plain(value) or type(value)~=type(v) or type(v)=='number' and not S.Number(value) then
            S.Note('setting:' .. k,'Invalid saved setting reset');char[k]=v
        end
    end
    if char.rollNonGear~='player' and char.rollNonGear~='greed' and char.rollNonGear~='need' then char.rollNonGear='player' end
    for _,k in ipairs({'equipBoEMaxQuality','rollNonGearMaxQuality'}) do
        if char[k]<0 or char[k]>5 or char[k]~=math.floor(char[k]) then char[k]=DEFAULTS[k] end
    end
    for _,k in ipairs({'locked','ignore','ignoreLinks','ratingConversions','rotation','procRates','markerColours','hunterTalents','textColours'}) do
        if not S.Table(char[k]) then char[k] = {} end
    end
    return char
end
function ns.Account()
    if not S.Table(FHKGearDB) then FHKGearDB = {} end
    if account ~= FHKGearDB then
        account = FHKGearDB
        for _,key in ipairs({'weights','imported','migrationRules'}) do
            if account[key]~=nil and not S.Table(account[key]) then account[key]=nil;S.Note('account:' .. key,'Invalid saved library reset') end
        end
    end
    return account
end
function ns.Level()
    local value = S.Read(UnitLevel,'player')
    value = S.Number(value) and value or 1
    return levelHint and math.max(value,levelHint) or value
end
function ns.SetSlotLocked(slot,on)
    if not S.Number(slot) then return false end
    for _,id in ipairs(ns.Engine.EQUIP_SLOTS) do
        if slot==id then ns.Char().locked[slot]=on and true or nil;ns.Changed();return true end
    end
    return false
end
function ns.SetIgnored(value,on,instance)
    if not S.Plain(value) then return false end
    if instance and S.Text(value) and value:find('item:',1,true) then
        ns.Char().ignoreLinks[value]=on and true or nil;ns.Changed();return true
    end
    local id = S.Number(value) and value or S.Text(value) and tonumber(value:match('^%s*(%d+)%s*$') or value:match('item:(%d+)'))
    if not S.Number(id) or id<=0 or id>=math.huge or id~=math.floor(id) then return false end
    ns.Char().ignore[id]=on and true or nil;ns.Changed();return true
end
function ns.Say(message,forced)
    if S.Text(message) and (forced or ns.Char().chat) then print('|cffd9a521Gear|r ' .. message) end
end
-- An automatic action is reported once (review G13): by its pop-up card, or in chat when no card showed.
function ns.SayAction(message,shown) if not shown then ns.Say(message) end end
function ns.ResetSettings()
    local c=ns.Char()
    for k,v in pairs(DEFAULTS) do c[k]=v end
    c.spec,c.locked,c.ignore,c.ignoreLinks=nil,{},{},{}
    c.rotation,c.procRates,c.ratingConversions={},{},{}
    c.markerColours,c.hunterTalents,c.textColours={},{},{}
    ns.Changed('items')
end
function ns.AddOnLoaded(name)
    local loadedOrLoading,loaded=S.Read(C_AddOns and C_AddOns.IsAddOnLoaded or _G.IsAddOnLoaded,name)
    return S.Plain(loadedOrLoading) and loadedOrLoading==true and (loaded==nil or S.Plain(loaded) and loaded==true)
end
function ns.MythicSimAvailable() return ns.AddOnLoaded('MythicSim') and type(SlashCmdList.MYTHICSIM)=='function' end
function ns.OpenMythicSim()
    if not ns.MythicSimAvailable() then return false end
    local ok=S.Call('MythicSim export',SlashCmdList.MYTHICSIM,'export')
    if not ok then ns.Say('MythicSim could not open its export. Try /msim.',true) end
    return ok
end
function ns.AutoGearActive() return ns.AddOnLoaded('AutoGear') end
function ns.LevellingCapped() return ns.Char().levellingOnly and ns.Level()>=ns.MAX_LEVEL end
function ns.ActionAvailable(kind)
    if type(InCombatLockdown)~='function' then return false end
    if kind=='autoEquip' then return type(GetCursorInfo)=='function' and type(CursorHasItem)=='function' and type(EquipCursorItem)=='function' and C_Container and type(C_Container.PickupContainerItem)=='function' end
    if kind=='autoQuest' then return type(GetQuestReward)=='function' end
    if kind=='autoRoll' then return type(RollOnLoot)=='function' and type(GetLootRollItemInfo)=='function' end
    return false
end
function ns.Automating(kind) return ns.Char()[kind]==true and not ns.LevellingCapped() and not ns.AutoGearActive() and ns.ActionAvailable(kind) end
-- Upgrade Found pop-ups follow Levelling Mode (none from level 60) and stay off while AutoGear runs.
function ns.FoundPopUps() return ns.Char().popFound==true and not ns.LevellingCapped() and not ns.AutoGearActive() end
local bagsAfterCombat=false
-- forRoll: a loot roll item is not bound to you yet, even when it binds on pickup (review R3-4).
function ns.AutoEquipAllowed(info,forRoll)
    if not info or info.missing or not S.Number(info.quality) then return false end
    local c=ns.Char()
    local cap=S.Number(c.autoEquipMaxQuality) and c.autoEquipMaxQuality or 2
    if cap<0 or cap>5 then cap=2 end
    -- Rarity Cap: Bind on Equip Only (review G4): an item already bound to you (a quest reward, a BoP
    -- drop) cannot be sold or traded, so the cap no longer holds it back. BoE and unbound items keep it.
    local mine=c.rarityCapBoEOnly==true and (info.bound=='bound' or info.bound=='bop' and not forRoll)
    -- Bind on Equip has its own cap (player, 2026-10-06): an item you could still sell or trade binds
    -- only up to this rarity.
    local boeCap=S.Number(c.equipBoEMaxQuality) and c.equipBoEMaxQuality or 2
    return (mine or info.quality<=cap) and (info.bound~='boe' or c.equipBoE==true and info.quality<=boeCap)
end
local frame=CreateFrame('Frame')
ns.frame,ns.handlers=frame,{}
local handlers=ns.handlers
function ns.Want(event,on)
    if on then
        if C_EventUtils and S.Read(C_EventUtils.IsEventValid,event)==false then return end
        S.Call('event:' .. event,frame.RegisterEvent,frame,event)
    elseif frame.UnregisterEvent then frame:UnregisterEvent(event) end
end
local subscribedProvider
local function SubscribeProvider()
    local api=rawget(_G,'ForeverGearAPI')
    if not ns.AddOnLoaded('ForeverGear') or not S.Table(api) or api==subscribedProvider or type(api.RegisterCallback)~='function' then return end
    local ok=S.Call('ForeverGear callback',api.RegisterCallback,api,ADDON,function()
        ns.Engine.Invalidate()
        if ns.InvalidateOptions then ns.InvalidateOptions() end
        if ns.RefreshMarkers then ns.RefreshMarkers() end
        if ns.Automating('autoEquip') then ns.QueueEquip(0.3) end
    end)
    if ok then subscribedProvider=api end
end
function ns.ActiveFeatures()
    local c=ns.Char()
    return c.tooltip or c.markQuest or c.markBags or c.markRoll or c.markCharacter or ns.FoundPopUps() or ns.Automating('autoEquip') or ns.Automating('autoQuest') or ns.Automating('autoRoll')
end
function ns.Refresh()
    SubscribeProvider()
    local c=ns.Char()
    local equip,quest,roll=ns.Automating('autoEquip'),ns.Automating('autoQuest'),ns.Automating('autoRoll')
    ns.Want('BAG_UPDATE_DELAYED',equip or c.markBags or ns.FoundPopUps())
    ns.Want('PLAYER_EQUIPMENT_CHANGED',ns.ActiveFeatures())
    ns.Want('SKILL_LINES_CHANGED',ns.ActiveFeatures())
    ns.Want('PLAYER_LEVEL_UP',ns.ActiveFeatures())
    ns.Want('SPELLS_CHANGED',ns.ActiveFeatures())
    ns.Want('PLAYER_TALENT_UPDATE',ns.ActiveFeatures())
    ns.Want('PLAYER_SPECIALIZATION_CHANGED',ns.ActiveFeatures())
    ns.Want('WEAPON_ENCHANT_CHANGED',ns.ActiveFeatures())
    ns.Want('UNIT_PET',ns.ActiveFeatures() and ns.HunterModel and ns.HunterModel.Active())
    ns.Want('EQUIP_BIND_CONFIRM',equip)
    ns.Want('QUEST_COMPLETE',quest or c.markQuest)
    ns.Want('QUEST_FINISHED',quest or c.markQuest)
    ns.Want('START_LOOT_ROLL',roll or c.markRoll)
    ns.Want('CONFIRM_LOOT_ROLL',roll)
    ns.Want('CANCEL_LOOT_ROLL',roll or c.markRoll)
    if not equip and not bagsAfterCombat and not (ns.Notify and ns.Notify.Waiting and ns.Notify.Waiting()) then ns.Want('PLAYER_REGEN_ENABLED',false) end
    if ns.Actions then ns.Actions.Refresh();if equip then ns.QueueEquip(0.5) end end
    if ns.RefreshMarkers then ns.RefreshMarkers() end
end
function ns.Changed(reason)
    if ns.Actions then ns.Actions.Cancel() end
    if reason=='items' then ns.Items.Invalidate() end
    if ns.HunterModel then ns.HunterModel.Refresh() end
    ns.Weights.Invalidate();ns.Engine.Invalidate()
    if ns.Context then ns.Context.Invalidate() end
    if ns.InvalidateOptions then ns.InvalidateOptions() end
    if ns.StoreProfile then ns.StoreProfile() end
    ns.Refresh()
end
local skillCount,contextQueued=false,false
local function SkillCount()
    return S.Read(C_SkillInfo and C_SkillInfo.GetNumSkillLines or _G.GetNumSkillLines) or
        S.Read(C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines)
end
local function ContextChanged(requirements)
    if requirements then ns.Items.Invalidate() end
    if ns.HunterModel then ns.HunterModel.Refresh() end
    ns.Weights.Invalidate();ns.Engine.Invalidate()
    if ns.Context then ns.Context.Invalidate() end
    if ns.InvalidateOptions then ns.InvalidateOptions() end
    if ns.Automating('autoEquip') then ns.QueueEquip(0.3) end
    if ns.RefreshMarkers then ns.RefreshMarkers() end
end
handlers.SKILL_LINES_CHANGED=function()
    if ns.QueueModel then ns.QueueModel() end -- weapon skill-ups change a weapon's hit chance
    if ns.Notify then S.Call('skill pop-up',ns.Notify.SkillCheck) end
    if contextQueued then return end
    contextQueued=true
    C_Timer.After(0.2,function()
        contextQueued=false
        local count=SkillCount()
        if ns.ActiveFeatures() then
            if S.Number(count) and S.Number(skillCount) then
                if ns.Items.InvalidateRequirements(count~=skillCount) then ContextChanged(false) end
            else ContextChanged(true) end
        end
        skillCount=count
    end)
end
-- SPELLS_CHANGED and talent updates come in bursts and can be frequent. Coalesce them, and keep
-- the item cache: only entries blocked by requirements are dropped, so a newly learned weapon
-- skill unlocks items without re-reading every tooltip (audit status N03).
local spellsQueued=false
local function SpellsSettled()
    spellsQueued=false
    if not ns.ActiveFeatures() then return end
    ns.Items.InvalidateRequirements(true)
    ContextChanged(false)
end
local function QueueSpells()
    if spellsQueued then return end
    spellsQueued=true
    S.Call('spells timer',C_Timer and C_Timer.After,0.5,SpellsSettled)
end
handlers.SPELLS_CHANGED=QueueSpells
handlers.PLAYER_TALENT_UPDATE=QueueSpells
-- A temporary weapon enchant changes only the worn weapons' comparison, not item facts.
handlers.WEAPON_ENCHANT_CHANGED=function()
    ns.Engine.InvalidateEquipped()
    if ns.Automating('autoEquip') then ns.QueueEquip(0.3) end
    if ns.RefreshMarkers then ns.RefreshMarkers() end
end
handlers.PLAYER_SPECIALIZATION_CHANGED=function(unit) if not unit or unit=='player' then ContextChanged(false) end end
handlers.PLAYER_LEVEL_UP=function(level)
    if ns.Actions then ns.Actions.ClearManual() end
    if S.Number(level) then levelHint=level;ns.Refresh() end
    C_Timer.After(0.5,function()
        local actual=S.Read(UnitLevel,'player')
        if S.Number(actual) and levelHint and actual>=levelHint then levelHint=nil end
        ContextChanged(true);ns.Refresh()
    end)
end
-- The Hunter model reads live stats: refresh it once after equipment or pet changes settle, and
-- rescore only when its weights really moved (HunterModel.Refresh's 2 % rule).
local modelQueued=nil -- time queued; a lost timer can never block refreshes for more than 2 s
local function QueueModel()
    if not (ns.HunterModel and ns.HunterModel.Active()) then return end
    if modelQueued and S.Time()-modelQueued<2 then return end
    modelQueued=S.Time()
    S.Call('model timer',C_Timer and C_Timer.After,0.5,function()
        modelQueued=nil
        if ns.HunterModel.Refresh() then
            ns.Weights.Invalidate();ns.Engine.Invalidate()
            if ns.InvalidateOptions then ns.InvalidateOptions() end
            if ns.Automating('autoEquip') then ns.QueueEquip(0.3) end
            if ns.RefreshMarkers then ns.RefreshMarkers() end
        end
    end)
end
ns.QueueModel=QueueModel
handlers.UNIT_PET=function(unit) if unit=='player' then QueueModel() end end
handlers.PLAYER_EQUIPMENT_CHANGED=function(slot)
    ns.Engine.InvalidateEquipped()
    if ns.HunterModel then ns.HunterModel.AmmoChanged() end
    QueueModel()
    if ns.Actions and not ns.Actions.Acknowledge(slot) then ns.Actions.Changed(slot) end
    if ns.Automating('autoEquip') then ns.QueueEquip(0.3) end
    if ns.RefreshMarkers then ns.RefreshMarkers() end
end
handlers.BAG_UPDATE_DELAYED=function()
    -- Every Auto Shot changes the quiver stack (review GU6): in combat, do the bag work once afterwards.
    if S.Read(InCombatLockdown)==true then bagsAfterCombat=true;ns.Want('PLAYER_REGEN_ENABLED',true);return end
    if ns.Notify then ns.Notify.QueueFound() end
    -- Ammo bought or used up changes which guns or bows can shoot.
    if ns.HunterModel and ns.HunterModel.Active() then ns.HunterModel.AmmoChanged();QueueModel() end
    if ns.Automating('autoEquip') then ns.QueueEquip(0.3) end
    if ns.RefreshMarkers then ns.RefreshMarkers() end
end
function ns.BagsAfterCombat() if bagsAfterCombat then bagsAfterCombat=false;handlers.BAG_UPDATE_DELAYED() end end
local function Migrate()
    local acct,ag=ns.Account(),rawget(_G,'AutoGearDB')
    if acct.migratedAutoGear or not S.Table(ag) then return end
    acct.migratedAutoGear=true
    local scales,locks={},0
    if S.Table(ag.ImportedWeights) then
        acct.imported=acct.imported or {}
        for key,w in pairs(ag.ImportedWeights) do
            if S.Text(key) and S.Table(w) then
                local copy={}
                for stat,value in pairs(w) do
                    if S.Text(stat) and S.Number(value) and value>=0 and value<=100000 then copy[stat]=value
                    elseif stat=='weapons' and S.Text(value) then copy.weapons=value end
                end
                if copy.DPS then copy.RangedDPS,copy.MeleeDPS=copy.RangedDPS or copy.DPS,copy.MeleeDPS or copy.DPS;copy.DPS=nil end
                acct.imported[key]=copy
                if #scales<16 then scales[#scales+1]=key:gsub(':',' ') end
            end
        end
    end
    acct.migrationRules={locked={},quest={}}
    if ag.LockGearSlots and S.Table(ag.LockedGearSlots) then
        for slot,rule in pairs(ag.LockedGearSlots) do
            if S.Number(slot) and S.Table(rule) and rule.enabled then acct.migrationRules.locked[slot]=true;locks=locks+1 end
        end
    end
    -- Rules are offered for explicit import in Equipment Rules; automation stays OFF.
    -- Never silent (review G10): say once what was copied, and where it now takes effect.
    table.sort(scales)
    if #scales>0 then
        ns.Say(('Copied %d AutoGear weight scale%s (%s). Gear now scores those specs with them; your own weights on the Stat Weights page still win.')
            :format(#scales,#scales==1 and '' or 's',table.concat(scales,', ')),true)
    end
    if locks>0 then
        ns.Say(('Found %d AutoGear slot lock%s. They are not applied: import them in Gear > Equipment Rules > AutoGear Slot Locks.'):format(locks,locks==1 and '' or 's'),true)
    end
    acct.migrationSummary={scales=#scales,locks=locks}
end
-- What AutoGear does on this character and which Gear toggle covers it (review G10). Lines for the Disable dialog.
local AUTOGEAR_FEATURES={
    {keys={'Enabled'},text='equips upgrades',gear='autoEquip',label='Auto-Equip Upgrades'},
    {keys={'AutoLootRoll','AutoRollOnBoEBlues','AutoRollOnEpics'},text='rolls on loot',gear='autoRoll',label='Auto-Roll on Loot'},
    {keys={'AutoCompleteItemQuests'},text='picks quest rewards',gear='autoQuest',label='Auto-Pick Quest Rewards'},
    {keys={'AutoAcceptQuests'},text='accepts and hands in quests'},
    {keys={'AutoSellGreys'},text='sells grey items'},
    {keys={'AutoRepair'},text='repairs at vendors'},
    {keys={'AutoAcceptPartyInvitations'},text='accepts party invitations'},
}
function ns.AutoGearSummary()
    local ag,c,out=rawget(_G,'AutoGearDB'),ns.Char(),{}
    if not S.Table(ag) then return out end
    for _,f in ipairs(AUTOGEAR_FEATURES) do
        local on=false
        for _,key in ipairs(f.keys) do if S.Plain(ag[key]) and ag[key]==true then on=true end end
        if on then
            if f.gear then out[#out+1]=('AutoGear %s. Gear: %s is %s.'):format(f.text,f.label,c[f.gear] and 'on' or 'off')
            else out[#out+1]=('AutoGear %s. Gear does not do this.'):format(f.text) end
        end
    end
    return out
end
ns.Migrate=Migrate
handlers.ADDON_LOADED=function(name)
    if name==ADDON then char,account=nil,nil;ns.Char();ns.Account();ns.Weights.Invalidate();ns.Engine.Invalidate();ns.Context.Invalidate();return end
    if name=='EllesmereUIQoL' or name=='EllesmereUIOptions' then if ns.TryQoLLink then ns.TryQoLLink() end;return end
    if name=='ForeverGear' or name=='MythicSim' or name=='AutoGear' or name=='FHKEllesmere' then
        ns.Engine.Invalidate()
        if ns.InvalidateOptions then ns.InvalidateOptions() end
        if ns.InstallProfileBridge then ns.InstallProfileBridge() end
        if ns.TryQoLLink then ns.TryQoLLink() end
        ns.Refresh()
    end
end
handlers.PLAYER_LOGIN=function()
    ns.Want('PLAYER_LOGIN',false)
    ns.Char();ns.Account();Migrate();skillCount=SkillCount()
    if ns.InstallProfileBridge then ns.InstallProfileBridge() end
    ns.Changed()
    if ns.InstallMarkers then ns.InstallMarkers() end
    if ns.TryQoLLink then ns.TryQoLLink() end
    if ns.Notify then ns.Notify.RegisterUnlock();ns.Notify.QueueFound();S.Call('skill pop-up',ns.Notify.SkillCheck) end
end
ns.Want('ADDON_LOADED',true);ns.Want('PLAYER_LOGIN',true)
frame:SetScript('OnEvent',function(_,event,...) local fn=handlers[event];if fn then fn(...) end end)
SLASH_FHKGEAR1='/fhkgear'
SlashCmdList.FHKGEAR=function(message)
    local cmd,arg=(S.Text(message) and message or ''):match('^%s*(%S*)%s*(.-)%s*$')
    cmd=cmd:lower()
    local function Say(text) ns.Say(text,true) end
    if cmd=='scan' then
        local jobs=ns.Engine.BagUpgrades()
        if #jobs==0 then Say('No supported upgrades in your bags.') end
        for _,job in ipairs(jobs) do Say(('%s -> slot %d (%s)'):format(job.info.link,job.target,job.reason or 'upgrade')) end
    elseif cmd=='item' then
        local _,link=S.Read(GameTooltip and GameTooltip.GetItem,GameTooltip)
        local info=link and ns.Items.Read(link)
        if not info then Say('Hover an item first.');return end
        if info.missing then Say('Item data pending: ' .. (info.reason or 'loading'));return end
        local parts={}
        for stat,v in pairs(info.stats) do if S.Number(v) then parts[#parts+1]=stat .. '=' .. v .. (info.lineStats[stat] and ' (Equip line)' or '') end end
        table.sort(parts)
        local delta,slot,reason=ns.Engine.Verdict(info)
        local score=ns.Engine.Score(info)
        Say(('%s score %s, %s, stats: %s; verdict: %s'):format(link,S.Number(score) and ('%.2f'):format(score) or 'unavailable',
            info.usable and 'usable' or ('not usable: ' .. (info.reason or 'requirements')),table.concat(parts,', '),
            delta and ((reason or 'upgrade') .. ' -> slot ' .. slot) or reason or 'no upgrade'))
        local w=ns.Weights.Current() or {}
        for _,p in ipairs(info.procs or {}) do
            local what=p.stat and ('+%g %s for %ss'):format(p.amount,p.stat,tostring(p.duration or '?')) or p.damage and ('%g damage'):format(p.damage) or 'multiple/resource effect'
            local rate,known,note=ns.Engine.ProcRate(info,p,w)
            local how=p.kind=='use' and ('use, %ss cooldown'):format(tostring(p.cooldown or '?')) or ('%s, %.2f per minute; %s'):format(p.kind=='struck' and 'when struck' or 'chance on hit',rate*60,note)
            Say(('Proc: %s (%s) = +%.2f score (estimate)'):format(what,how,ns.Engine.ProcValue(info,p,w)))
        end
        for _,line in ipairs(info.unparsed or {}) do Say('Line not scored yet: ' .. line) end
        for _,line in ipairs(info.unknown or {}) do Say('Unknown: ' .. line) end
        for stat,value in pairs(info.rawRatings or {}) do Say(('Raw %s rating: %g'):format(stat,value)) end
    elseif cmd=='status' then
        local _,source=ns.Weights.Current();local class=ns.Weights.ClassSpec()
        local name,how=ns.Weights.SpecLabel()
        Say(('%s %s (%s), %s phase; weights: %s%s (approximate).'):format(name,class,how,ns.Weights.Phase(),source,ns.Engine.UsesForeverGear() and ' (ForeverGear scores)' or ''))
        Say(('Automatic: equip %s, quest %s, roll %s%s%s.'):format(tostring(ns.Automating('autoEquip')),tostring(ns.Automating('autoQuest')),tostring(ns.Automating('autoRoll')),
            ns.LevellingCapped() and '; Levelling Mode: off at 60' or '',ns.AutoGearActive() and '; AutoGear is enabled, so Gear only marks' or ''))
    elseif cmd=='errors' then
        if #S.errors==0 then Say('No recorded Gear API errors.') end
        for _,err in ipairs(S.errors) do Say(err.key .. ': ' .. err.message .. ' (' .. S.counts[err.key] .. ')') end
    elseif cmd=='ignore' or cmd=='allow' then
        if not ns.SetIgnored(arg,cmd=='ignore') then Say('Enter an item link or ID.') end
    elseif cmd=='lock' or cmd=='unlock' then
        if not ns.SetSlotLocked(tonumber(arg),cmd=='lock') then Say('Enter a supported slot number.') end
    elseif cmd=='context' and ns.Context then Say(ns.Context.Description())
    elseif cmd=='hunter' then
        if not (ns.HunterModel and ns.HunterModel.Available()) then Say('The Hunter model needs a Hunter and the client stat API.',true);return end
        local text=ns.HunterModel.Report()
        if EllesmereUI and EllesmereUI.ShowCopyPopup then EllesmereUI:ShowCopyPopup('FHK Gear Hunter Model','Live inputs, assumptions and weights. Ctrl+C to copy.',text)
        else for line in text:gmatch('[^\n]+') do Say(line,true) end end
    elseif EllesmereUI and EllesmereUI.OpenPlugin then EllesmereUI.OpenPlugin(ADDON) end
end

