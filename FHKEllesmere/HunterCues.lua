-- Hunter cues, plan 10.3 items 6-10. Every cue is opt-in (off by default), registers its
-- events only while on, and shows in the shared warning lane (Warnings.lua), so they look,
-- stack and move like every other companion warning. Advisory only: nothing is cast.
--   6 Stop Attack: Auto Shot or melee is on while your target is held by your own Freezing
--     Trap, Scatter Shot, Scare Beast or Wyvern Sting (attacking breaks it). Danger.
--   7 Feign Death: Resisted (cast succeeded but you are not feigning; Forever exposes no
--     combat-log reader, so this reads UnitIsFeignDeath), and a countdown before Forever's
--     6-minute Feign Death kills you.
--   8 Growl: on in a group (it pulls threat from the tank), or off while solo.
--   9 Tracking: with Improved Tracking (+5 % damage to the tracked type), name the Track
--     spell that matches your target, out of combat.
--  10 Beast tooltip: family, attack speed and whether its level allows taming (Forever: no
--     taming above your level). There is no tameability API, so it only speaks to level.
-- Priority 2/3 additions (same rules):
--   Pet Idle: in combat with a hostile target, your living pet has had no target for 1.5 s.
--   Trap Broken: your Freezing Trap left your target well before it would have run out.
--   Reactive Strikes (player: "they're procs, give them the spell highlight"): while Mongoose
--     Bite (after a dodge) or Counterattack (after a parry) is usable, their action buttons
--     glow with Ellesmere's own Proc Glow style and colour (EllesmereUI.Glows; Ellesmere only
--     glows spells Blizzard's IsSpellOverlayed reports, which Classic reactive skills never are).
--   Hunter's Mark: an elite, rare-elite or boss target without your Hunter's Mark.
--   Trueshot Aura: learned (talent) but not on you, out of combat.
--   Rapid Killing: the talent's proc is up (your next Shot hits harder).
-- Unreadable or restricted answers always stay quiet.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end
local H={}
NS.HunterCues=H
local FEIGN_DEATH,FEIGN_LIMIT=5384,360
local DEFAULTS={ccBreak=false,feign=false,feignWarn=300,growl=false,growlSolo=true,tracking=false,beastTooltip=false,
    petIdle=false,trapBroken=false,reactive=true,huntersMark=false,trueshot=false,rapidKilling=false}
function NS.EllesmereHunterCueSettings()
    FHKEllesmereDB=FHKEllesmereDB or {}
    local s=FHKEllesmereDB.hunterCues
    if type(s)~='table' then s={};FHKEllesmereDB.hunterCues=s end
    for k,v in pairs(DEFAULTS) do if s[k]==nil then s[k]=v end end
    return s
end
local function Plain(v) return not (issecretvalue and issecretvalue(v)) end
local function Public(v) if Plain(v) then return v end end
local function Read(fn,...)
    if type(fn)~='function' then return end
    local ok,a,b,c,d,e,f,g,h,i=pcall(fn,...)
    if ok then return Public(a),Public(b),Public(c),Public(d),Public(e),Public(f),Public(g),Public(h),Public(i) end
end
local function Aura(unit,name,filter)
    local get=C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
    if not name or type(get)~='function' then return nil,false end
    local ok,value=pcall(get,unit,name,filter)
    if not ok or not Plain(value) then return nil,false end
    return value,value==nil or type(value)=='table'
end
local function Num(v) return Plain(v) and type(v)=='number' and v==v end
-- PLAYER_REGEN_DISABLED fires before InCombatLockdown turns true, so the events set this flag
-- (otherwise the Pet Idle ticker never started on entering combat).
local combatFlag=nil
local function InCombat()
    if combatFlag~=nil then return combatFlag end
    return Read(_G.InCombatLockdown)~=false
end
local function Hunter() return select(2,Read(_G.UnitClass,'player'))=='HUNTER' end
local function SpellName(id)
    local name=C_Spell and Read(C_Spell.GetSpellName,id)
    if type(name)~='string' then name=Read(_G.GetSpellInfo,id) end
    return type(name)=='string' and name or nil
end
local function Known(id)
    return Read(C_SpellBook and C_SpellBook.IsSpellKnown,id)==true or Read(_G.IsPlayerSpell,id)==true
end
local C=NS.Colours or {}
local RED,AMBER=C.alert or {1,.27,.27},C.caution or {1,.82,0}
local function Show(key,text,colour,critical) if NS.ShowEllesmereWarning then NS.ShowEllesmereWarning(key,text,colour,false,critical) end end
local function Hide(key) if NS.HideEllesmereWarning then NS.HideEllesmereWarning(key) end end

-------------------------------------------------------------------------------
-- 6. Stop Attack on your own crowd control.
-------------------------------------------------------------------------------
local CC={3355,19503,1513,19386} -- Freezing Trap Effect, Scatter Shot, Scare Beast, Wyvern Sting (rank 1; names cover ranks)
local shooting,meleeing=false,false
function H.HeldBy(unit)
    local get=C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
    for _,id in ipairs(CC) do
        local name=SpellName(id)
        if name then
            local aura=Read(get,unit,name,'HARMFUL|PLAYER')
            if type(aura)=='table' then return name end
        end
    end
end
function H.CheckCC()
    local s=NS.EllesmereHunterCueSettings()
    if not s.ccBreak or not (shooting or meleeing) or Read(_G.UnitExists,'target')~=true then Hide('ccBreak');return end
    local held=H.HeldBy('target')
    if held then Show('ccBreak','Stop Attack - '..held,RED,true) else Hide('ccBreak') end
end

-------------------------------------------------------------------------------
-- 7. Feign Death: resisted, and the 6-minute countdown.
-------------------------------------------------------------------------------
local feignAt,feignTicker,resistToken=nil,nil,0
local function Feigning() return Read(_G.UnitIsFeignDeath,'player') end
function H.CheckFeign(now)
    local s=NS.EllesmereHunterCueSettings()
    now=now or (GetTime and GetTime() or 0)
    local feigning=s.feign and Feigning()==true
    if feigning and not feignAt then feignAt=now end
    if not feigning then
        feignAt=nil
        if feignTicker then feignTicker:Cancel();feignTicker=nil end
        Hide('feign')
        if not s.feign then resistToken=resistToken+1;Hide('feignResist') end
        return
    end
    if not feignTicker and C_Timer and C_Timer.NewTicker then feignTicker=C_Timer.NewTicker(1,function() H.CheckFeign() end) end
    local elapsed=now-feignAt
    local warn=Num(s.feignWarn) and s.feignWarn or 300
    if elapsed>=warn then
        local left=math.max(0,math.floor(FEIGN_LIMIT-elapsed+.5))
        Show('feign','Cancel Feign Death ('..left..'s)',left<=30 and RED or AMBER,true)
    else Hide('feign') end
end
function H.FeignCast()
    local s=NS.EllesmereHunterCueSettings()
    if not s.feign then return end
    resistToken=resistToken+1
    local token=resistToken
    -- Feign Death applies at once; a moment later a resisted cast is still not feigning.
    C_Timer.After(.3,function()
        if token~=resistToken or not NS.EllesmereHunterCueSettings().feign or not Hunter() then return end
        if Feigning()==false and Read(_G.UnitIsDeadOrGhost,'player')==false then
            Show('feignResist','Feign Death Resisted',RED,true)
            C_Timer.After(2.5,function() if token==resistToken then Hide('feignResist') end end)
        end
    end)
end

-------------------------------------------------------------------------------
-- 8. Growl autocast for the group.
-------------------------------------------------------------------------------
local GROWL=2649
function H.GrowlAutocast()
    local name=SpellName(GROWL)
    for i=1,(_G.NUM_PET_ACTION_SLOTS or 10) do
        local slotName,_,_,_,allowed,enabled,spellID=Read(_G.GetPetActionInfo,i)
        local isGrowl=Num(spellID) and SpellName(spellID)==name or slotName==name
        if name and isGrowl and allowed==true and type(enabled)=='boolean' then return enabled end
    end
end
function H.CheckGrowl()
    local s=NS.EllesmereHunterCueSettings()
    if not s.growl or InCombat() or Read(_G.UnitExists,'pet')~=true or Read(_G.UnitIsDeadOrGhost,'pet')~=false then Hide('growl');return end
    local on=H.GrowlAutocast()
    local grouped=Read(_G.IsInGroup)
    if type(grouped)~='boolean' then Hide('growl');return end
    if on==true and grouped then Show('growl','Growl Is On - Turn It Off In A Group',AMBER)
    elseif on==false and not grouped and s.growlSolo then Show('growl','Growl Is Off - Turn It On Solo',AMBER)
    else Hide('growl') end
end

-------------------------------------------------------------------------------
-- 9. Tracking for Improved Tracking.
-------------------------------------------------------------------------------
-- Creature type ID (UnitCreatureType's second return) -> Track spell.
local TRACK={[1]=1494,[2]=19879,[3]=19878,[4]=19880,[5]=19882,[6]=19884,[7]=19883}
function H.ActiveTracking()
    local M=C_Minimap
    local n=M and Read(M.GetNumTrackingTypes)
    if not Num(n) then return nil,nil,false end
    for i=1,n do
        local info=Read(M.GetTrackingInfo,i)
        if type(info)~='table' or not Plain(info.type) or not Plain(info.active) then return nil,nil,false end
        if info.type=='spell' and info.active==true then
            if not Num(info.spellID) then return nil,nil,false end
            return info.spellID,Public(info.texture),true
        end
    end
    return nil,nil,true
end
function H.CheckTracking()
    local s=NS.EllesmereHunterCueSettings()
    local T=NS.HunterTalents
    if not s.tracking or InCombat() or not (T and Read(T.Has,'improvedTracking')==true) or
        Read(_G.UnitCanAttack,'player','target')~=true or Read(_G.UnitIsDead,'target')~=false then Hide('tracking');return end
    local _,typeID=Read(_G.UnitCreatureType,'target')
    local want=Num(typeID) and TRACK[typeID]
    if not want or not Known(want) then Hide('tracking');return end
    local active,_,readable=H.ActiveTracking()
    if not readable or active==want then Hide('tracking');return end
    local icon=C_Spell and Read(C_Spell.GetSpellTexture,want)
    local name=SpellName(want) or 'Track'
    Show('tracking',(icon and ('|T'..icon..':0|t ') or '')..name..' (+5%)',AMBER)
end

-------------------------------------------------------------------------------
-- 10. Beast tooltip.
-------------------------------------------------------------------------------
local TAME_BEAST=1515
function H.BeastLine(unit)
    if Read(_G.UnitExists,unit)~=true or Read(_G.UnitPlayerControlled,unit)~=false then return end
    local _,typeID=Read(_G.UnitCreatureType,unit)
    if typeID~=1 then return end
    local parts={}
    local family=Read(_G.UnitCreatureFamily,unit)
    if type(family)=='string' then parts[#parts+1]=family end
    local speed=Read(_G.UnitAttackSpeed,unit)
    if Num(speed) and speed>0 then
        local text=('attack speed %.2f'):format(speed)
        parts[#parts+1]=speed<=1.5 and ('|cffffd100'..text..' (fast)|r') or text
    end
    local level,mine=Read(_G.UnitLevel,unit),Read(_G.UnitLevel,'player')
    local r,g,b=.75,.75,.75
    if Num(level) and Num(mine) then
        if level<0 or level>mine then parts[#parts+1]='tame: too high';r,g,b=1,.3,.25
        elseif Known(TAME_BEAST) then parts[#parts+1]='tame: level OK';r,g,b=.3,.85,.3
        else parts[#parts+1]='tame: level OK (learn Tame Beast)' end
    end
    if #parts==0 then return end
    return table.concat(parts,' - '),r,g,b
end
local tooltipHooked=false
local function HookTooltip()
    if tooltipHooked then return end
    local api=TooltipDataProcessor
    if not (api and type(api.AddTooltipPostCall)=='function' and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit) then return end
    tooltipHooked=pcall(api.AddTooltipPostCall,Enum.TooltipDataType.Unit,function(tooltip)
        if not NS.EllesmereHunterCueSettings().beastTooltip or not Hunter() then return end
        if not (tooltip and tooltip.GetUnit and tooltip.AddLine) then return end
        local _,unit=Read(tooltip.GetUnit,tooltip)
        if type(unit)~='string' then return end
        local text,r,g,b=H.BeastLine(unit)
        if text then tooltip:AddLine(text,r,g,b) end
    end)
end

-------------------------------------------------------------------------------
-- Pet Idle, Reactive Strikes (checked on a combat-only half-second ticker).
-------------------------------------------------------------------------------
local idleSince,combatTicker=nil,nil
local function HostileTarget()
    return Read(_G.UnitCanAttack,'player','target')==true and Read(_G.UnitIsDead,'target')==false
end
function H.CheckPetIdle(now)
    local s=NS.EllesmereHunterCueSettings()
    now=now or (GetTime and GetTime() or 0)
    if not s.petIdle or not InCombat() or not HostileTarget() or Read(_G.UnitExists,'pet')~=true or
        Read(_G.UnitIsDeadOrGhost,'pet')~=false then idleSince=nil;Hide('petIdle');return end
    if Read(_G.UnitExists,'pettarget')==false then
        idleSince=idleSince or now
        if now-idleSince>=1.5 then Show('petIdle','Pet Idle - Send It In',AMBER,true) end
    else idleSince=nil;Hide('petIdle') end
end
local REACTIVE={1495,19306} -- Mongoose Bite, Counterattack
local glowing={} -- button -> wrapper
local function ButtonSpellName(btn)
    local slot=btn.action or (btn.GetAttribute and Read(btn.GetAttribute,btn,'action'))
    if not Num(slot) then return end
    local kind,id=Read(_G.GetActionInfo,slot)
    if kind=='macro' then id=Read(_G.GetMacroSpell,id);kind=Num(id) and 'spell' or nil end
    if kind=='spell' and Num(id) then return SpellName(id) end
end
local function ActionButtons(fn)
    local ab=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIActionBars
    local bars=ab and ab.barButtons
    if type(bars)~='table' then return end
    for _,list in pairs(bars) do
        if type(list)=='table' then for _,btn in ipairs(list) do if type(btn)=='table' then fn(btn) end end end
    end
end
-- Ellesmere's proc glow settings, drawn with its shared engine on our own wrapper.
local function StartGlow(btn)
    local G=EUI.Glows
    if not G then return end
    local wrapper=glowing[btn]
    if not wrapper then
        wrapper=CreateFrame('Frame',nil,btn);wrapper:SetAllPoints(btn);wrapper:EnableMouse(false)
        glowing[btn]=wrapper
    end
    wrapper:SetFrameLevel((btn:GetFrameLevel() or 1)+10)
    local w,h=Read(btn.GetWidth,btn) or 45,Read(btn.GetHeight,btn) or 45
    local ab=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIActionBars
    local p=ab and ab.EAB and ab.EAB.db and ab.EAB.db.profile or {}
    pcall(G.StopAllGlows,wrapper);wrapper:Show();wrapper:SetAlpha(1)
    if not p.procGlowEnabled or not G.MakeView then
        pcall(G.StartGlow,wrapper,6,w,1,.788,.137,nil,h) -- Ellesmere's default proc look
        return
    end
    local list=G.MakeView({1,2,3,4,5,6,7}).list
    local entry=list[p.procGlowType or 1] or list[1]
    local c=p.procGlowColor or {r=1,g=.776,b=.376}
    local cr,cg,cb=c.r,c.g,c.b
    if G.ResolveColor then cr,cg,cb=G.ResolveColor(p.procGlowUseClassColor and 'class' or (p.procGlowColorMode=='default' and 'default' or 'custom'),c.r,c.g,c.b) end
    if cr==nil and (entry.procedural or entry.buttonGlow or entry.autocast or entry.shapeGlow) then
        local d=G.DEFAULT_COLOR or {r=1,g=.788,b=.137};cr,cg,cb=d.r,d.g,d.b
    end
    if entry.procedural then
        local n,th,period=p.procGlowLines or 8,p.procGlowThickness or 2,p.procGlowSpeed or 4
        local len=math.max(1,math.min(math.floor((w+h)*(2/n-.1)),math.min(w,h)))
        pcall(G.StartProceduralAnts,wrapper,n,th,period,len,cr,cg,cb,w,h)
    elseif entry.buttonGlow then pcall(G.StartButtonGlow,wrapper,w,cr,cg,cb,nil,h)
    elseif entry.autocast then pcall(G.StartAutoCastShine,wrapper,w,cr,cg,cb,1.0,h)
    elseif entry.shapeGlow then pcall(G.StartGlow,wrapper,6,w,cr or 1,cg or .788,cb or .137,nil,h)
    else pcall(G.StartFlipBookGlow,wrapper,w,entry,cr,cg,cb,h) end
end
local function StopGlow(btn)
    local wrapper=glowing[btn]
    if not wrapper then return end
    if EUI.Glows then pcall(EUI.Glows.StopAllGlows,wrapper) end
    wrapper:Hide()
end
function H.CheckReactive()
    local s=NS.EllesmereHunterCueSettings()
    local usable=C_Spell and C_Spell.IsSpellUsable
    local live={}
    if s.reactive and Hunter() then
        for _,id in ipairs(REACTIVE) do
            local name=SpellName(id)
            if name and Known(id) and Read(usable,name)==true then live[name]=true end
        end
    end
    local want={}
    if next(live) then ActionButtons(function(btn) local name=ButtonSpellName(btn);if name and live[name] then want[btn]=true end end) end
    for btn in pairs(glowing) do if not want[btn] then StopGlow(btn) end end
    for btn in pairs(want) do
        local wrapper=glowing[btn]
        if not (wrapper and wrapper.IsShown and wrapper:IsShown()) then StartGlow(btn) end
    end
end
H.Glowing=function() return glowing end
local function CombatTick(on)
    if on and not combatTicker and C_Timer and C_Timer.NewTicker then
        combatTicker=C_Timer.NewTicker(.5,function() H.CheckPetIdle() end)
    elseif not on and combatTicker then combatTicker:Cancel();combatTicker=nil end
end
H.CombatTick=CombatTick

-------------------------------------------------------------------------------
-- Trap Broken: Freezing Trap left the target well before its expiry.
-------------------------------------------------------------------------------
local trap={guid=nil,expires=nil}
local trapToken=0
function H.CheckTrap(now)
    local s=NS.EllesmereHunterCueSettings()
    if not s.trapBroken then trap.guid,trap.expires=nil,nil;trapToken=trapToken+1;Hide('trapBroken');return end
    now=now or (GetTime and GetTime() or 0)
    local guid=Read(_G.UnitGUID,'target')
    local name=SpellName(3355)
    local aura,readable=Aura('target',name,'HARMFUL|PLAYER')
    if not readable then trap.guid,trap.expires=nil,nil;return end
    if type(aura)=='table' then
        trap.guid=guid;trap.expires=Num(aura.expirationTime) and aura.expirationTime>0 and aura.expirationTime or nil
        return
    end
    -- A dead target lost the trap by dying, not by being broken.
    if trap.guid and trap.guid==guid and trap.expires and now<trap.expires-.5 and Read(_G.UnitIsDead,'target')==false then
        Show('trapBroken','Trap Broken',AMBER,true)
        trapToken=trapToken+1
        local token=trapToken
        C_Timer.After(2.5,function() if token==trapToken then Hide('trapBroken') end end)
    end
    trap.guid,trap.expires=nil,nil
end

-------------------------------------------------------------------------------
-- Hunter's Mark, Trueshot Aura, Rapid Killing.
-------------------------------------------------------------------------------
local BIG={elite=true,rareelite=true,worldboss=true}
function H.CheckMark()
    local s=NS.EllesmereHunterCueSettings()
    if not s.huntersMark or not HostileTarget() or not Known(1130) then Hide('huntersMark');return end
    local class=Read(_G.UnitClassification,'target')
    if not class or not BIG[class] then Hide('huntersMark');return end
    local name=SpellName(1130)
    local mark,readable=Aura('target',name,'HARMFUL|PLAYER')
    if readable and mark==nil then Show('huntersMark',name,AMBER) else Hide('huntersMark') end
end
local function PlayerAura(id)
    local name=SpellName(id)
    if not name then return nil end
    local aura,readable=Aura('player',name,'HELPFUL')
    if not readable then return nil end
    return type(aura)=='table'
end
function H.CheckBuffs()
    local s=NS.EllesmereHunterCueSettings()
    local T=NS.HunterTalents
    if s.trueshot and not InCombat() and T and Read(T.Has,'trueshotAura')==true and PlayerAura(1299346)==false then
        Show('trueshot',SpellName(1299346) or 'Trueshot Aura',AMBER)
    else Hide('trueshot') end
    if s.rapidKilling and T and Read(T.Has,'rapidKilling')==true and PlayerAura(415405)==true then
        local accent=EUI.GetAccentColor and {EUI.GetAccentColor()} or AMBER
        Show('rapidKilling',(SpellName(415405) or 'Rapid Killing')..' - Next Shot +20%',accent)
    else Hide('rapidKilling') end
end

-------------------------------------------------------------------------------
-- Events: only for the cues that are on.
-------------------------------------------------------------------------------
local driver
local function All()
    H.CheckCC();H.CheckFeign();H.CheckGrowl();H.CheckTracking();H.CheckMark();H.CheckBuffs();H.CheckTrap()
    local s=NS.EllesmereHunterCueSettings()
    CombatTick(s.petIdle and InCombat())
    H.CheckPetIdle();H.CheckReactive()
end
function H.OnEvent(_,event,unit,_,spellID)
    if event=='UNIT_SPELLCAST_SUCCEEDED' then
        if unit=='player' and Num(spellID) and spellID==FEIGN_DEATH then H.FeignCast() end
        return
    end
    if event=='PLAYER_REGEN_DISABLED' then combatFlag=true elseif event=='PLAYER_REGEN_ENABLED' then combatFlag=false end
    if event=='UNIT_FLAGS' then H.CheckFeign();return end
    if event=='START_AUTOREPEAT_SPELL' then shooting=true elseif event=='STOP_AUTOREPEAT_SPELL' then shooting=false
    elseif event=='PLAYER_ENTER_COMBAT' then meleeing=true elseif event=='PLAYER_LEAVE_COMBAT' then meleeing=false end
    if event=='UNIT_AURA' then
        if unit=='target' then H.CheckCC();H.CheckTrap();H.CheckMark() elseif unit=='player' then H.CheckFeign();H.CheckBuffs() end
        return
    end
    if event=='SPELL_UPDATE_USABLE' or event=='ACTIONBAR_SLOT_CHANGED' or event=='ACTIONBAR_PAGE_CHANGED' or event=='UPDATE_BONUS_ACTIONBAR' then H.CheckReactive();return end
    if event=='UNIT_TARGET' then H.CheckPetIdle();return end
    All()
end
function NS.SyncEllesmereHunterCues()
    local s=NS.EllesmereHunterCueSettings()
    if driver then driver:UnregisterAllEvents() end
    local hunter=Hunter()
    for btn,wrapper in pairs(glowing) do if wrapper:IsShown() then StopGlow(btn) end end
    combatFlag=nil
    shooting=Read(C_Spell and C_Spell.IsCurrentSpell,75)==true
    meleeing=Read(C_Spell and C_Spell.IsCurrentSpell,6603)==true
    if hunter and s.beastTooltip then HookTooltip() end
    local any=hunter and (s.ccBreak or s.feign or s.growl or s.tracking or s.petIdle or s.trapBroken or s.reactive or s.huntersMark or s.trueshot or s.rapidKilling)
    if not any then
        for _,key in ipairs({'ccBreak','feign','feignResist','growl','tracking','petIdle','trapBroken','huntersMark','trueshot','rapidKilling'}) do Hide(key) end
        CombatTick(false);idleSince=nil;trap.guid,trap.expires=nil,nil;trapToken=trapToken+1
        resistToken=resistToken+1;feignAt=nil
        if feignTicker then feignTicker:Cancel();feignTicker=nil end
        H.CheckReactive();return
    end
    if not driver then driver=CreateFrame('Frame');driver:SetScript('OnEvent',H.OnEvent) end
    local function Unit(event,...) if driver.RegisterUnitEvent then driver:RegisterUnitEvent(event,...) else driver:RegisterEvent(event) end end
    for _,event in ipairs({'PLAYER_ENTERING_WORLD','PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED','PLAYER_TARGET_CHANGED'}) do driver:RegisterEvent(event) end
    if s.ccBreak then
        for _,event in ipairs({'START_AUTOREPEAT_SPELL','STOP_AUTOREPEAT_SPELL','PLAYER_ENTER_COMBAT','PLAYER_LEAVE_COMBAT'}) do driver:RegisterEvent(event) end
        Unit('UNIT_AURA','target','player')
    end
    if s.feign then Unit('UNIT_SPELLCAST_SUCCEEDED','player');Unit('UNIT_AURA','player','target');Unit('UNIT_FLAGS','player') end
    if s.growl then driver:RegisterEvent('PET_BAR_UPDATE');driver:RegisterEvent('GROUP_ROSTER_UPDATE');Unit('UNIT_PET','player') end
    if s.tracking then driver:RegisterEvent('MINIMAP_UPDATE_TRACKING');driver:RegisterEvent('SPELLS_CHANGED') end
    if s.petIdle then Unit('UNIT_TARGET','pet');Unit('UNIT_PET','player') end
    if s.reactive then
        for _,event in ipairs({'SPELL_UPDATE_USABLE','ACTIONBAR_SLOT_CHANGED','ACTIONBAR_PAGE_CHANGED','UPDATE_BONUS_ACTIONBAR','SPELLS_CHANGED'}) do driver:RegisterEvent(event) end
    end
    if s.trapBroken or s.huntersMark then Unit('UNIT_AURA','target','player') end
    if s.trueshot or s.rapidKilling then Unit('UNIT_AURA','player','target');driver:RegisterEvent('SPELLS_CHANGED') end
    All()
end
if NS.HunterTalents and NS.HunterTalents.OnChange then NS.HunterTalents.OnChange(function() if driver then H.CheckTracking() end end) end

function NS.AddEllesmereHunterCueOptions(Row)
    local s=NS.EllesmereHunterCueSettings()
    local function Set(key,v) s[key]=v;NS.SyncEllesmereHunterCues();if EUI.RefreshPage then EUI:RefreshPage() end end
    Row({type='toggle',text='Stop Attack On Your Crowd Control',tooltip='Red, above your character: Auto Shot or melee is on while your target is held by your own Freezing Trap, Scatter Shot, Scare Beast or Wyvern Sting.',
        getValue=function() return s.ccBreak end,setValue=function(v) Set('ccBreak',v) end},
        {type='toggle',text='Feign Death Warnings',tooltip='Feign Death Resisted when the cast lands but you are not feigning, and a countdown before Feign Death kills you after 6 minutes.',
        getValue=function() return s.feign end,setValue=function(v) Set('feign',v) end})
    Row({type='slider',text='Feign Countdown From',min=60,max=330,step=30,
        tooltip='Seconds into Feign Death when the countdown starts. It turns red for the last 30 seconds.',
        disabled=function() return not s.feign end,disabledTooltip='Feign Death Warnings',
        getValue=function() return s.feignWarn end,setValue=function(v) s.feignWarn=v end},
        {type='toggle',text='Growl Reminder',tooltip='Out of combat: Growl autocast on while in a group (it takes threat from the tank).',
        getValue=function() return s.growl end,setValue=function(v) Set('growl',v) end})
    Row({type='toggle',text='Growl Off While Solo',tooltip='Also reminds you when Growl autocast is off while solo, where your pet should hold the mob.',
        disabled=function() return not s.growl end,disabledTooltip='Growl Reminder',
        getValue=function() return s.growlSolo end,setValue=function(v) Set('growlSolo',v) end},
        {type='toggle',text='Tracking Reminder',tooltip='With Improved Tracking learned, names the Track spell that matches your target out of combat (+5% damage to that type).',
        getValue=function() return s.tracking end,setValue=function(v) Set('tracking',v) end})
    Row({type='toggle',text='Pet Idle',tooltip='In combat with a hostile target: your pet has had no target for 1.5 seconds.',
        getValue=function() return s.petIdle end,setValue=function(v) Set('petIdle',v) end},
        {type='toggle',text='Trap Broken',tooltip='Your Freezing Trap came off your target well before it would have run out.',
        getValue=function() return s.trapBroken end,setValue=function(v) Set('trapBroken',v) end})
    Row({type='toggle',text='Mongoose Bite / Counterattack Glow',tooltip='While Mongoose Bite (after a dodge) or Counterattack (after a parry) can be cast, its action buttons glow like a proc, using your Action Bars Proc Glow style and color.',
        getValue=function() return s.reactive end,setValue=function(v) Set('reactive',v) end},
        {type='toggle',text='Hunter\'s Mark On Elites',tooltip='An elite, rare elite or boss target without your Hunter\'s Mark.',
        getValue=function() return s.huntersMark end,setValue=function(v) Set('huntersMark',v) end})
    Row({type='toggle',text='Trueshot Aura Missing',tooltip='Out of combat, with the Trueshot Aura talent learned, when the aura is not on you.',
        getValue=function() return s.trueshot end,setValue=function(v) Set('trueshot',v) end},
        {type='toggle',text='Rapid Killing Proc',tooltip='With the Rapid Killing talent: shows while your next Shot deals 20% more damage.',
        getValue=function() return s.rapidKilling end,setValue=function(v) Set('rapidKilling',v) end})
    Row({type='toggle',text='Beast Tooltip',tooltip='On beasts: family, attack speed (fast ones in gold) and whether their level lets you tame them. Forever allows no taming above your level.',
        getValue=function() return s.beastTooltip end,setValue=function(v) Set('beastTooltip',v) end},
        {type='label',text='Level only: no API says whether a beast is tameable'})
end

local boot=CreateFrame('Frame')
boot:RegisterEvent('PLAYER_LOGIN')
boot:SetScript('OnEvent',function(self) self:UnregisterAllEvents();NS.SyncEllesmereHunterCues() end)
