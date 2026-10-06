-- Check actual equip requirements, not the class/spec scoring preference.
local NS = _G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not NS then return end
local generation=0
local function Public(v) return not (issecretvalue and issecretvalue(v)) end
local function Number(v)
    return Public(v) and type(v)=='number' and v==v and v>-math.huge and v<math.huge
end
local function Read(fn,...)
    if type(fn)~='function' then return nil end
    local ok,v=pcall(fn,...)
    if ok and Public(v) then return v end
end
local function Tooltip(inventoryID,lootID,bag,slot,reward,link,data)
    if Public(data) and type(data)=='table' then return data end
    local api=C_TooltipInfo
    if not api then return end
    if bag~=nil and slot~=nil then return Read(api.GetBagItem,bag,slot)
    elseif inventoryID then return Read(api.GetInventoryItem,'player',inventoryID)
    elseif lootID then return Read(api.GetLootRollItem,lootID)
    elseif reward then return Read(api.GetQuestItem,'choice',reward)
    elseif link then return Read(api.GetHyperlink,link) end
end
local function Red(text,color)
    if not Public(text) or not Public(color) then return nil end
    if type(text)~='string' or text=='' then return false end
    if not color or type(color.GetRGB)~='function' then return nil end
    local ok,r,g,b=pcall(color.GetRGB,color)
    if not ok or not Number(r) or not Number(g) or not Number(b) then return nil end
    return r>.5 and r>g*3 and r>b*3 and math.abs(b-g)<.1
end
local function Requirements(info,data)
    if not Public(info) or type(info)~='table' then return nil,'requirements unavailable' end
    if not Public(info.isGear) then return nil,'requirements unavailable' end
    if not Public(info.equipped) then return nil,'requirements unavailable' end
    if not info.isGear or info.equipped then return true end
    if info.itemDataMissing then return nil,'item data pending' end
    if info.item and type(info.item.IsItemDataCached)=='function' and Read(info.item.IsItemDataCached,info.item)~=true then
        return nil,'item data pending'
    end
    local canUse
    if Number(info.id) then canUse=Read(C_PlayerInfo and C_PlayerInfo.CanUseItem,info.id) end
    local unknown,leftBlocked=false,false
    if Public(data) and type(data)=='table' and Public(data.lines) and type(data.lines)=='table' and #data.lines>0 then
        for _,line in ipairs(data.lines) do
            if not Public(line) or type(line)~='table' then unknown=true
            else
                local left,right=Red(line.leftText,line.leftColor),Red(line.rightText,line.rightColor)
                if right then return false,'equip requirements not met',true end
                if left then leftBlocked=true end
                if left==nil or right==nil then unknown=true end
            end
        end
        if leftBlocked or canUse==false then return false,'equip requirements not met' end
        if not unknown then return true end
    end
    -- Older clients expose the same colors through the already-read tooltip.
    if not data and AutoGearTooltip and type(AutoGearTooltip.NumLines)=='function' then
        local count=Read(AutoGearTooltip.NumLines,AutoGearTooltip)
        if Number(count) and count>0 then
            for i=1,count do
                for _,side in ipairs({'Left','Right'}) do
                    local fs=_G['AutoGearTooltipText'..side..i]
                    if fs then
                        local text=Read(fs.GetText,fs)
                        local red=Red(text,{GetRGB=function() return fs:GetTextColor() end})
                        if red and side=='Right' then return false,'equip requirements not met',true end
                        if red then leftBlocked=true end
                        if red==nil then unknown=true end
                    end
                end
            end
            if leftBlocked or canUse==false then return false,'equip requirements not met' end
            if not unknown then return true end
        end
    end
    if canUse==false then return false,'equip requirements not met' end
    if canUse==true then return true end
    return nil,'requirements unavailable'
end
NS.EllesmereGearRequirements=Requirements
local function Guard(info,data)
    local allowed,why,rightBlocked=Requirements(info,data)
    if Public(info) and type(info)=='table' then info._fhkRequirementsGeneration=generation end
    if allowed~=true and Public(info) and type(info)=='table' and Public(info.isGear) and info.isGear and
        Public(info.equipped) and not info.equipped then
        -- Native near-future level rolls survive; a missed proficiency never does.
        if allowed==nil or rightBlocked or not info.unusable then info.Within5levels=nil end
        info.usable=nil;info.unusable=1
        info.reason='('..why..')'
    end
    return info,allowed
end
-- Levelling / Endgame modes (player request). Levelling (below max level by
-- default): a Hunter keeps AutoGear's own stat weights but values the bow far
-- above the melee weapon and favours slower, harder-hitting weapons; AutoGear's
-- built-in profile weighs every weapon's DPS alike (DPS = 2) and ignores
-- per-hit damage. Rough classic scale: ~14 attack power per weapon DPS, times
-- the share of damage each weapon drives for a weaving Hunter. Sim weights,
-- once imported in AutoGear, always win. Endgame (max level by default) runs
-- only on imported sim weights (BiS raid gear serves PvP too); without them
-- AutoGear is paused entirely, which also saves its scanning cost.
local LEVELLING_HUNTER={RangedDPS=8,MeleeDPS=3,Damage=.15}
local function MaxLevel()
    local max=Read(_G.GetMaxPlayerLevel)
    return Number(max) and max or 60
end
function NS.EllesmereAutoGearMode()
    -- Published install (review R2): no intervention unless the player picks a mode. Endgame
    -- pausing needs imported sim weights, which stock AutoGear cannot hold.
    local chosen=type(FHKEllesmereDB)=='table' and FHKEllesmereDB.autoGearMode or (_G.ForeverHunterKeysNS~=nil and 'auto' or 'off')
    if chosen=='off' then return 'off','off' end
    if chosen=='levelling' or chosen=='endgame' then return chosen,chosen end
    local level=Read(UnitLevel,'player')
    return Number(level) and level>=MaxLevel() and 'endgame' or 'levelling','auto'
end
-- AutoGear asks every 50 ms: the class:spec lookup walks the talent tabs, so it is cached for
-- two seconds (review R14); the imported-weights table itself is read fresh every time.
local specKey,specAt=nil,-10
local function SpecKey()
    local now=GetTime and GetTime() or 0
    if specKey~=nil and now-specAt>=0 and now-specAt<2 then return specKey end
    local ok,_,class,spec=pcall(_G.AutoGearGetClassAndSpec)
    specKey=ok and Public(class) and Public(spec) and type(class)=='string' and type(spec)=='string' and class..':'..spec or false
    specAt=now
    return specKey
end
local function HasImportedWeights()
    local db=_G.AutoGearDB
    if type(db)~='table' or type(db.ImportedWeights)~='table' or type(_G.AutoGearGetClassAndSpec)~='function' then return false end
    local key=SpecKey()
    return key and db.ImportedWeights[key]~=nil or false
end
function NS.EllesmereAutoGearPaused()
    -- Pausing only makes sense where AutoGear can import sim weights (stock AutoGear cannot).
    local db=_G.AutoGearDB
    return NS.EllesmereAutoGearMode()=='endgame' and type(db)=='table' and type(db.ImportedWeights)=='table' and not HasImportedWeights()
end
function NS.ResetEllesmereAutoGearPause() specKey=nil end
local function Hunter()
    local _,class=UnitClass('player')
    return Public(class) and class=='HUNTER'
end
local function AdjustWeights()
    local w=_G.AutoGearCurrentWeighting
    if type(w)~='table' or w._fhkLevelling or not Hunter() or HasImportedWeights() or NS.EllesmereAutoGearMode()~='levelling' then return end
    -- A copy: AutoGear's shared default table stays untouched.
    local copy={}
    for k,v in pairs(w) do copy[k]=v end
    copy.DPS=0
    for k,v in pairs(LEVELLING_HUNTER) do copy[k]=v end
    copy._fhkLevelling=true
    _G.AutoGearCurrentWeighting=copy
end
local function ReapplyWeights()
    if type(_G.AutoGearSetStatWeights)=='function' then pcall(_G.AutoGearSetStatWeights) end
    if type(AutoGearQueueLocalUpdate)=='function' then AutoGearQueueLocalUpdate() end
    if type(AutoGearQueueScan)=='function' then AutoGearQueueScan(true) end
end
NS.SyncEllesmereAutoGearMode=ReapplyWeights
function NS.SetEllesmereAutoGearMode(mode)
    if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end
    FHKEllesmereDB.autoGearMode=(mode=='off' or mode=='auto' or mode=='levelling' or mode=='endgame') and mode or nil
    if NS.ResetEllesmereAutoGearPause then NS.ResetEllesmereAutoGearPause() end
    ReapplyWeights()
    if _G.EllesmereUI and _G.EllesmereUI.RefreshPage then _G.EllesmereUI:RefreshPage(true) end
end
local function Status()
    if NS.EllesmereAutoGearMode()=='off' then return 'AutoGear runs as it is' end
    if NS.EllesmereAutoGearPaused() then return 'Paused: import sim weights in AutoGear' end
    if HasImportedWeights() then return 'Using your imported sim weights' end
    return NS.EllesmereAutoGearMode()=='levelling' and 'Levelling weights active' or 'Endgame'
end
NS.EllesmereAutoGearStatus=Status
function NS.AddEllesmereAutoGearOptions(Row)
    local gear=rawget(_G,'FHKGearNS')
    if type(gear)=='table' and type(gear.Char)=='function' then
        Row({type='labeledButton',text='FHK Gear',buttonText='Open Gear',
            tooltip='Upgrade scores, automatic rarity limits, weapon rules and weights.',
            onClick=function() if EllesmereUI and EllesmereUI.OpenPlugin then EllesmereUI.OpenPlugin('FHKGear') end end},
            {type='toggle',text='Levelling Mode',getValue=function() return gear.Char().levellingOnly==true end,
                setValue=function(v) gear.Char().levellingOnly=v==true;gear.Changed() end,
                tooltip='Gear automation stops at level 60. Marks remain available.'})
        return
    end
    if type(_G.AutoGearMain)~='function' then return end
    Row({type='dropdown',text='AutoGear Mode',values={off='Leave AutoGear Alone',auto='Automatic',levelling='Levelling',endgame='Endgame'},
        order={'off','auto','levelling','endgame'},
        tooltip='Levelling: the bow counts far more than the melee weapon and slower hard-hitting weapons are favored. Endgame: AutoGear runs only on sim weights you import in AutoGear (/ag), and pauses without them. Automatic: Endgame at max level. Leave AutoGear Alone: no changes to AutoGear.',
        getValue=function() return select(2,NS.EllesmereAutoGearMode()) end,
        setValue=function(v) NS.SetEllesmereAutoGearMode(v) end},
        {type='label',text=Status()})
end

local installed=false
local originalRead,originalMain,mainWrapper
local lastRun
local driver=CreateFrame('Frame')
local pendingRefresh,refreshScheduled=false,false
-- Related events coalesce into one rescan after a one-second window.
local REFRESH_DELAY=1
local function Refresh()
    if not installed or not pendingRefresh or refreshScheduled or Read(InCombatLockdown)==true then return end
    refreshScheduled=true
    C_Timer.After(REFRESH_DELAY,function()
        refreshScheduled=false
        if not pendingRefresh or Read(InCombatLockdown)==true then return end
        pendingRefresh=false
        if type(AutoGearQueueLocalUpdate)=='function' then AutoGearQueueLocalUpdate() end
        if type(AutoGearQueueScan)=='function' then AutoGearQueueScan(true) end
    end)
end
local function PruneQueue(now)
    if Read(InCombatLockdown)==true or Read(UnitAffectingCombat,'player')==true or Read(UnitIsDeadOrGhost,'player')==true then return end
    local queue=_G.AutoGearActionQueue
    if type(queue)~='table' then return end
    for i=#queue,1,-1 do
        local action=queue[i]
        -- Never interfere with an item already picked up or awaiting confirmation.
        if action.action=='equip' and not action.ensuringEquipped and Number(action.t) and now>action.t and
            action._fhkRequirementsGeneration~=generation then
            local info=action.info
            local link=type(info)=='table' and Public(info.link) and info.link
            local checked=link and Read(_G.AutoGearReadItemInfo,nil,nil,nil,nil,nil,link)
            if not checked or checked.unusable or not checked.usable then
                table.remove(queue,i)
            else action._fhkRequirementsGeneration=generation end
        end
    end
end
local function Install()
    if installed or type(_G.AutoGearReadItemInfo)~='function' or type(_G.AutoGearMain)~='function' then return end
    originalRead,originalMain=_G.AutoGearReadItemInfo,_G.AutoGearMain
    _G.AutoGearReadItemInfo=function(inventoryID,lootID,bag,slot,reward,link,data)
        data=Tooltip(inventoryID,lootID,bag,slot,reward,link,data)
        local info=originalRead(inventoryID,lootID,bag,slot,reward,link,data)
        Guard(info,data)
        return info
    end
    local originalConsider=_G.AutoGearConsiderItem
    if type(originalConsider)=='function' then
        _G.AutoGearConsiderItem=function(info,...)
            if type(info)=='table' and info.isGear and not info.equipped then
                if info._fhkRequirementsGeneration~=generation then Guard(info,Tooltip(nil,nil,nil,nil,nil,info.link)) end
                if info.unusable and not (select(3,...) and info.Within5levels) then return nil end
            end
            return originalConsider(info,...)
        end
    end
    if type(_G.AutoGearSetStatWeights)=='function' then
        local originalWeights=_G.AutoGearSetStatWeights
        _G.AutoGearSetStatWeights=function(...)
            local a,b=originalWeights(...)
            AdjustWeights()
            return a,b
        end
        AdjustWeights()
    end
    if type(_G.AutoGearChooseQuestReward)=='function' then
        local originalChoose=_G.AutoGearChooseQuestReward
        _G.AutoGearChooseQuestReward=function(...)
            -- Endgame without sim weights: the choice stays with the player.
            if NS.EllesmereAutoGearPaused() then return nil,'weights' end
            return originalChoose(...)
        end
    end
    mainWrapper=function(...)
        -- Stay on AutoGear's own 50 ms cadence, including the queue guard.
        local now=GetTime()
        if not Number(now) then return end
        if lastRun and now>=lastRun and now-lastRun<=.05 then return end
        lastRun=now
        -- Mode and imported-weight checks share the cadence, even while paused.
        if NS.EllesmereAutoGearPaused() then return end
        PruneQueue(now)
        return originalMain(...)
    end
    _G.AutoGearMain=mainWrapper
    local frame=_G.AutoGearFrame
    if frame and frame:GetScript('OnUpdate')==originalMain then frame:SetScript('OnUpdate',mainWrapper) end
    installed=true
    -- Item data arrival is AutoGear's own (throttled) job; it is not a reason
    -- to re-check what the character can equip.
    for _,event in ipairs({'SKILL_LINES_CHANGED','SPELLS_CHANGED','PLAYER_LEVEL_UP','PLAYER_ENTERING_WORLD',
        'PLAYER_REGEN_ENABLED'}) do
        if not C_EventUtils or not C_EventUtils.IsEventValid or C_EventUtils.IsEventValid(event) then driver:RegisterEvent(event) end
    end
end
-- A new proficiency (mail, a weapon type) adds a skill line; a weapon-skill
-- point while levelling does not, and fires SKILL_LINES_CHANGED every few swings.
local skillLines
local function SkillLineCount()
    -- Forever's skills frame uses C_SkillInfo (API audit 2026-10-06); spellbook tabs are not proficiencies.
    return C_SkillInfo and Read(C_SkillInfo.GetNumSkillLines) or Read(_G.GetNumSkillLines) or (C_SpellBook and Read(C_SpellBook.GetNumSpellBookSkillLines))
end
driver:RegisterEvent('ADDON_LOADED');driver:RegisterEvent('PLAYER_LOGIN')
driver:SetScript('OnEvent',function(_,event)
    Install()
    if not installed then return end
    if event=='ADDON_LOADED' then return end
    if event=='PLAYER_REGEN_ENABLED' then Refresh();return end
    -- PLAYER_LEVEL_UP is synchronous; let UnitLevel settle before Automatic
    -- selects and reapplies the new mode's weights.
    if event=='PLAYER_LEVEL_UP' then C_Timer.After(0,ReapplyWeights) end
    if event=='SKILL_LINES_CHANGED' or event=='SPELLS_CHANGED' then
        local count=SkillLineCount()
        if Number(count) and count==skillLines then return end
        if Number(count) then skillLines=count end
    end
    generation=generation+1
    pendingRefresh=true;Refresh()
end)
Install()
