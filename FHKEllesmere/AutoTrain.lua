-- Auto Train (player, 2026-10-06: "auto train too which selects the training option on the npc
-- menu"). Any class: at a trainer's conversation, pick "I want to train"; at the trainer, learn
-- every spell you can afford, one at a time. Hold Shift on the NPC to skip. Off by default.
-- Ellesmere QoL's Train All Button stays the manual tool; this only adds the automation.
-- APIs: C_GossipInfo and the trainer service globals, as Forever's own Blizzard_TrainerUI uses them.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end
local T={}
NS.AutoTrain=T
local DEFAULTS={enabled=false,gossip=true,professions=false,keepGold=0,weaponMasters=false}
local TRAINER_GOSSIP_ICON=132058 -- Interface/GossipFrame/TrainerGossipIcon
local NOT_TRAINING={'unlearn','untrain','reset','forget','respec','talent'}
local function Plain(v) return not (issecretvalue and issecretvalue(v)) end
local function Number(v) return Plain(v) and type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function Read(fn,...)
    if type(fn)~='function' then return end
    local ok,a,b,c,d,e,f=pcall(fn,...)
    if ok and Plain(a) then return a,b,c,d,e,f end
end
function NS.EllesmereAutoTrainSettings()
    if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end
    local s=FHKEllesmereDB.autoTrain
    if type(s)~='table' then s={};FHKEllesmereDB.autoTrain=s end
    for k,v in pairs(DEFAULTS) do if type(s[k])~=type(v) then s[k]=v end end
    if s.keepGold~=s.keepGold or s.keepGold<0 or s.keepGold>1000 then s.keepGold=0 end
    return s
end
local function Say(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cff0cd29fForever Companion:|r '..text) end
end
local function Skip() return Read(_G.IsShiftKeyDown)==true end
-- Class trainer or weapon master (SCENARIO_REVIEW S46): both are General trainers, and a weapon
-- master sells every weapon skill. The class's own spell list (ClassTrainingData.lua) tells them
-- apart: only those spells are bought unless Weapon Masters Too is on. Without the data, every
-- General service is trained as before.
local classNames
function T.ClassNames()
    if classNames~=nil then return classNames or nil end
    local D=NS.ClassTrainingData
    local _,class=Read(_G.UnitClass,'player')
    local build=type(D)=='table' and type(class)=='string' and D[class]
    if type(build)~='function' then return nil end
    classNames=false
    local ok,list=pcall(build)
    if not ok or type(list)~='table' then return nil end
    local set={}
    for _,g in ipairs(list) do
        if type(g)=='table' and type(g[1])=='string' then
            set[g[1]]=true
            -- The client's own name too, so a translated client matches (review R2-14).
            local first=type(g[2])=='table' and g[2][1]
            local client=Number(first) and Read(C_Spell and C_Spell.GetSpellName,first)
            if type(client)=='string' and client~='' then set[client]=true end
            for i=2,#g do local r=g[i];if type(r)=='table' and type(r[4])=='string' then set[r[4]]=true end end
        end
    end
    classNames=set
    return set
end
local function ClassSpell(set,name)
    if not set or set[name] then return true end
    local base=name:match('^(.-)%s+[IVXL]+$') -- poison tiers: "Instant Poison III"
    return base~=nil and set[base]==true
end
T.ClassSpell=ClassSpell
-- A spell you already have a rank of: its upgrade is trained before new spells (S47), so a
-- cheap new utility spell never spends the money a core rank needs.
local function KnownOne(name)
    local info=Read(C_Spell and C_Spell.GetSpellInfo,name)
    return type(info)=='table' and Number(info.spellID) and true or false
end
local function KnownName(name)
    if KnownOne(name) then return true end
    -- A poison tier ("Instant Poison III") upgrades the tier you have (review R2-20).
    local base=name:match('^(.-)%s+[IVXL]+$')
    return base~=nil and (KnownOne(base) or KnownOne(base..' II') or KnownOne(base..' I'))
end

-- 1. The conversation: the trainer option, after any quests the NPC offers.
function T.TrainerOption()
    local options=C_GossipInfo and Read(C_GossipInfo.GetOptions)
    local best
    for _,option in ipairs(type(options)=='table' and options or {}) do
        local name=type(option.name)=='string' and option.name:lower() or ''
        local icon=option.icon==TRAINER_GOSSIP_ICON or option.overrideIconID==TRAINER_GOSSIP_ICON
        local excluded=false
        for _,word in ipairs(NOT_TRAINING) do if name:find(word,1,true) then excluded=true;break end end
        local status=Enum and Enum.GossipOptionStatus and Enum.GossipOptionStatus.Available or 0
        local available=option.status==nil or option.status==status
        if available and not excluded and (icon or name:find('train',1,true)) and
            (not best or (option.orderIndex or 0)<(best.orderIndex or 0)) then best=option end
    end
    return best
end
function T.OnGossip()
    local s=NS.EllesmereAutoTrainSettings()
    if not s.enabled or not s.gossip or Skip() then return end
    local option=T.TrainerOption()
    if not option then return end
    local G=C_GossipInfo
    local quests=(Read(G.GetNumAvailableQuests) or 0)+(Read(G.GetNumActiveQuests) or 0)
    if Number(quests) and quests>0 then return end -- quests first; the player picks
    -- A lone option is already picked by Blizzard (selectOptionWhenOnlyOption) or by EllesmereUI QoL's
    -- Auto Select Gossip: never a second pick, which would restart the trainer (suite review SQ-5).
    local options=Read(G.GetOptions)
    if type(options)=='table' and #options==1 and (option.selectOptionWhenOnlyOption==true or
        (type(_G.EllesmereUIDB)=='table' and _G.EllesmereUIDB.autoGossip==true)) then return end
    -- No "confirmed" argument: a conversation that costs gold still asks the player.
    if option.gossipOptionID and type(G.SelectOption)=='function' then pcall(G.SelectOption,option.gossipOptionID)
    elseif option.orderIndex and type(G.SelectOptionByIndex)=='function' then pcall(G.SelectOptionByIndex,option.orderIndex) end
end

-- 2. The trainer: one purchase at a time, each confirmed by the next list update.
local session,waiting,attempts,restoreFilter,spent,count,filter,skipped,newProfession
-- Learning a profession uses one of two slots and Blizzard asks first: never done here (R2-4).
local function LearnsProfession(name) return type(name)=='string' and name:match('^Apprentice ')~=nil end
local otherBuyAt,buyingSelf=-10,false
if hooksecurefunc and type(_G.BuyTrainerService)=='function' then
    -- Ellesmere's Train All Button or another addon may be buying: let those purchases land.
    hooksecurefunc('BuyTrainerService',function() if not buyingSelf then otherBuyAt=Read(_G.GetTime) or 0 end end)
end
local function Floor() return (NS.EllesmereAutoTrainSettings().keepGold or 0)*10000 end
local Try
local function Arm()
    local mine=session
    if C_Timer and C_Timer.After then C_Timer.After(1,function() if session==mine and waiting then waiting=false;Try() end end) end
end
Try=function()
    if not session or waiting then return end
    local now=Read(_G.GetTime) or 0
    if now-otherBuyAt<.5 then waiting=true;Arm();return end
    local money=Read(_G.GetMoney) or 0
    local floor=Floor()
    local total=Read(_G.GetNumTrainerServices) or 0
    -- Pass 1: upgrades of spells you know; pass 2: new spells.
    for pass=1,2 do for index=1,total do
        local name,kind,_,_,rank=Read(_G.GetTrainerServiceInfo,index)
        rank=type(rank)=='string' and rank or ''
        local ours=type(name)=='string' and ClassSpell(filter,name) and not (newProfession and LearnsProfession(name))
        if type(name)=='string' and kind=='available' and not ours and not skipped[name] then skipped[name]=true;skipped.n=(skipped.n or 0)+1 end
        if ours and kind=='available' and (pass==2)~=KnownName(name) then
            local key=name..':'..rank
            local cost=Read(_G.GetTrainerServiceCost,index) or 0
            if (attempts[key] or 0)<2 and Number(cost) and money-cost>=floor then
                attempts[key]=(attempts[key] or 0)+1
                waiting=true
                buyingSelf=true;local ok=pcall(_G.BuyTrainerService,index);buyingSelf=false
                if ok then
                    spent,count=spent+cost,count+1
                    Say('Trained '..name..(rank~='' and (' ('..rank..')') or '')..'.')
                end
                Arm()
                return
            end
        end
    end end
    if (skipped.n or 0)>0 and not skipped.told then
        skipped.told=true
        Say(('Left %d %s for you: not class spells (Weapon Masters Too is off).'):format(skipped.n,skipped.n==1 and 'skill' or 'skills'))
    end
    if count>0 then
        local coins=(_G.C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString and Read(C_CurrencyInfo.GetCoinTextureString,spent)) or (tostring(spent)..'c')
        Say(('Trained %d %s for %s.'):format(count,count==1 and 'spell' or 'spells',coins))
        count,spent=0,0
    end
end
local function End()
    session,waiting=nil,false
    if restoreFilter and type(_G.SetTrainerServiceTypeFilter)=='function' then pcall(_G.SetTrainerServiceTypeFilter,'available',false) end
    restoreFilter=nil
end
function T.OnTrainer()
    End()
    local s=NS.EllesmereAutoTrainSettings()
    if not s.enabled or Skip() then return end
    local kind=C_Trainer and Read(C_Trainer.GetTrainerType)
    local types=Enum and Enum.TrainerType or {}
    if kind==(types.Pet or 3) then return end -- pet trainers: your pet, your choice
    if (kind==(types.Tradeskills or 2) or Read(_G.IsTradeskillTrainer)==true) and not s.professions then return end
    session,attempts,spent,count,skipped={}, {},0,0,{}
    -- Professions are never filtered; a General trainer sells only class spells unless chosen.
    local professionTrainer=kind==(types.Tradeskills or 2) or Read(_G.IsTradeskillTrainer)==true
    filter=(not professionTrainer and not s.weaponMasters) and T.ClassNames() or nil
    -- A class trainer also sells Dual Wield, Mail or Pick Lock, which are not class spells in the
    -- data: the filter applies only when no service is a class spell, i.e. a weapon master (R2-3).
    if filter then
        for index=1,Read(_G.GetNumTrainerServices) or 0 do
            local name=Read(_G.GetTrainerServiceInfo,index)
            if type(name)=='string' and ClassSpell(filter,name) then filter=nil;break end
        end
    end
    newProfession=professionTrainer
    -- The service list holds only entries that pass the window's filter.
    if type(_G.GetTrainerServiceTypeFilter)=='function' and type(_G.SetTrainerServiceTypeFilter)=='function' and
        Read(_G.GetTrainerServiceTypeFilter,'available')~=true then
        pcall(_G.SetTrainerServiceTypeFilter,'available',true);restoreFilter=true
    end
    Try()
end
T.Try=Try
local driver=CreateFrame('Frame')
driver:SetScript('OnEvent',function(_,event)
    if event=='GOSSIP_SHOW' then T.OnGossip()
    elseif event=='TRAINER_SHOW' then T.OnTrainer()
    elseif event=='TRAINER_UPDATE' then if session and waiting then waiting=false;Try() end
    elseif event=='TRAINER_CLOSED' then End() end
end)
function NS.SyncEllesmereAutoTrain()
    local s=NS.EllesmereAutoTrainSettings()
    driver:UnregisterAllEvents()
    if not s.enabled then End();return end
    for _,event in ipairs({'GOSSIP_SHOW','TRAINER_SHOW','TRAINER_UPDATE','TRAINER_CLOSED'}) do
        if not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(event) then driver:RegisterEvent(event) end
    end
end

function NS.AddEllesmereAutoTrainOptions(Row)
    local s=NS.EllesmereAutoTrainSettings()
    local function Set(k,v) s[k]=v;NS.SyncEllesmereAutoTrain() end
    local off=function() return not s.enabled end
    local train={type='toggle',text='Auto Train',
        tooltip='At your class trainer, learns every spell you can afford, one by one, upgrades of spells you know first, and lists each in chat. Hold Shift when you talk to the trainer to skip. Pet trainers and weapon masters are left to you unless chosen in the cog.',
        getValue=function() return s.enabled end,setValue=function(v) Set('enabled',v) end}
    train.cog={title='Auto Train',disabled=off,disabledTooltip='Auto Train',rows={
        {type='slider',label='Keep At Least (Gold)',min=0,max=100,step=1,get=function() return s.keepGold end,set=function(v) s.keepGold=v end},
        {type='toggle',label='Profession Trainers Too',get=function() return s.professions end,set=function(v) s.professions=v end},
        {type='toggle',label='Weapon Masters Too',get=function() return s.weaponMasters end,set=function(v) s.weaponMasters=v end}}}
    Row(train,{type='toggle',text='Open Trainer From Conversation',disabled=off,disabledTooltip='Auto Train',
        tooltip='Picks the trainer option ("I want to train") when you talk to a trainer. NPCs offering quests are left to you first.',
        getValue=function() return s.gossip end,setValue=function(v) Set('gossip',v) end})
end

local boot=CreateFrame('Frame')
boot:RegisterEvent('PLAYER_LOGIN')
boot:SetScript('OnEvent',function(self) self:UnregisterAllEvents();NS.SyncEllesmereAutoTrain() end)
