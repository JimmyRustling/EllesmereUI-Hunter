-- Class cues for rogues, druids and warriors (CLASS_KITS_2026-10-06.md engines E5, E6, E7).
-- Player, 2026-10-06: "a behind target indicator ... similar to our range indicator it should
-- show when infront when behind the target with two colours". Forever has no facing API for
-- NPCs, so the Behind indicator is evidence-based:
--   FRONT   the target is targeting you (mobs face what they attack), or "must be behind" fired;
--   BEHIND  a behind-only ability (Backstab, Ambush, Garrote, Shred, Ravage) just succeeded;
--   LIKELY  optional: the target attacks someone else;
--   neutral otherwise. Evidence holds for a set time and resets on target / target's target change.
-- Also: state cues from UI_ERROR_MESSAGE (matched by GetGameMessageInfo names, then by the
-- client's own GlobalStrings text), a stealth / Prowl opener cue, reactive ability glows
-- (Overpower, Revenge, Execute, Victory Rush, Riposte) in Ellesmere's proc glow style, a
-- warrior stance-mismatch hint, rogue Slice and Dice missing / expiring, and an energy tick spark.
-- Every feature is off by default, class gated, registers events only while on, coalesces its
-- checks (C_Timer.After(0)) and runs a timer only while something counts down. Nothing is cast.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end
local C={}
NS.ClassCues=C
local unpack=unpack or table.unpack

-------------------------------------------------------------------------------
-- Guarded reads.
-------------------------------------------------------------------------------
local function Plain(v) return not (issecretvalue and issecretvalue(v)) end
local function Number(v) return Plain(v) and type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function Text(v) return Plain(v) and type(v)=='string' and v~='' end
local function Table(v) return Plain(v) and type(v)=='table' end
local function Read(fn,...)
    if type(fn)~='function' then return end
    local ok,a,b,c,d=pcall(fn,...)
    if ok and Plain(a) then return a,Plain(b) and b or nil,Plain(c) and c or nil,Plain(d) and d or nil end
end
local function Now() local n=Read(_G.GetTime);return Number(n) and n or 0 end
local function Class() local _,c=Read(_G.UnitClass,'player');return c end
C.Class=Class
local function SpellName(id)
    if not Number(id) then return end
    local n=Read(C_Spell and C_Spell.GetSpellName,id)
    if not Text(n) then n=Read(_G.GetSpellInfo,id) end
    return Text(n) and n or nil
end
local function SpellIcon(id) local t=Read(C_Spell and C_Spell.GetSpellTexture,id);return (Number(t) or Text(t)) and t or nil end
local function KnownID(id)
    if not Number(id) then return false end
    return Read(C_SpellBook and C_SpellBook.IsSpellKnown,id)==true or Read(_G.IsPlayerSpell,id)==true
end
-- Any rank: C_Spell.GetSpellInfo(name) gives the highest learned rank.
local function Known(id)
    if KnownID(id) then return true end
    local name=SpellName(id)
    local info=name and Read(C_Spell and C_Spell.GetSpellInfo,name)
    return Table(info) and Number(info.spellID) and info.spellID~=id and KnownID(info.spellID) or false
end
C.Known=Known
local function Yes(v) return Plain(v) and v==true end
local function HostileTarget()
    return Yes(Read(_G.UnitExists,'target')) and Yes(Read(_G.UnitCanAttack,'player','target')) and Read(_G.UnitIsDead,'target')==false
end
local combatFlag
local function InCombat()
    if combatFlag~=nil then return combatFlag end
    return Yes(Read(_G.UnitAffectingCombat,'player')) or Yes(Read(_G.InCombatLockdown))
end
local function After(delay,fn) if C_Timer and C_Timer.After then C_Timer.After(delay,fn) return true end end
-- Target health fraction, only when readable (UnitHealth may return secrets).
local function TargetHealth()
    local hp,max=Read(_G.UnitHealth,'target'),Read(_G.UnitHealthMax,'target')
    if Number(hp) and Number(max) and max>0 and hp>0 then return hp/max end
end
-- Solo: readably not in a group and not in an instance (unreadable counts as grouped).
local function Solo()
    local inside=Read(_G.IsInInstance)
    return Read(_G.IsInGroup)==false and inside==false
end

-------------------------------------------------------------------------------
-- Settings: three profile keys, validated on every read.
-------------------------------------------------------------------------------
local SOUNDS={none=true,raid=true,alarm=true,ready=true,tick=true}
local SOUND_VALUES={none='None',raid='Raid Warning',alarm='Alarm',ready='Ready Check',tick='Tick'}
local SOUND_ORDER={'none','raid','alarm','ready','tick'}
local SPEC={
    behindIndicator={
        DEFAULTS={enabled=false,likely=false,hold=3,sound='none',text=true,shape='block',width=60,height=16,opacity=.95,fontSize=11,
            meleeOnly=false,combatOnly=false,labelBehind='BEHIND',labelFront='FRONT',labelLikely='LIKELY',labelNeutral=''},
        CHOICES={sound=SOUNDS,shape={block=true,bar=true,text=true}},
        LIMITS={hold={1,10},width={16,200},height={4,40},opacity={.1,1},fontSize={8,20}}},
    classCues={
        DEFAULTS={stealth=false,stance=false,form=false,behindError=false,hold=1.5,sound='none',aboveCharacter=false,
            opener=false,openerRogue='garrote',openerDruid='ravage',
            reactive=false,overpower=true,revenge=true,execute=true,victoryRush=true,riposte=true,stanceHint=false,
            snd=false,sndWarn=3,sndPoints=2},
        CHOICES={sound=SOUNDS,openerRogue={garrote=true,cheap=true},openerDruid={ravage=true,pounce=true}},
        LIMITS={hold={.5,5},sndWarn={1,10},sndPoints={1,5}}},
    energyTick={
        DEFAULTS={enabled=false,place='power',width=2,opacity=1,barWidth=120,barHeight=6},
        CHOICES={place={power=true,standalone=true}},
        LIMITS={width={1,6},opacity={.1,1},barWidth={40,300},barHeight={2,20}}},
}
local POINTS={CENTER=true,TOP=true,BOTTOM=true,LEFT=true,RIGHT=true,TOPLEFT=true,TOPRIGHT=true,BOTTOMLEFT=true,BOTTOMRIGHT=true}
local function ValidLabel(x) return Plain(x) and type(x)=='string' and #x<=24 and not x:find('|',1,true) end
local function ValidColour(c) return Table(c) and Number(c[1]) and Number(c[2]) and Number(c[3]) and c[1]>=0 and c[1]<=1 and c[2]>=0 and c[2]<=1 and c[3]>=0 and c[3]<=1 end
local function ValidPosition(p) return Table(p) and Text(p.point) and POINTS[p.point] and Text(p.relPoint) and POINTS[p.relPoint] and Number(p.x) and Number(p.y) end
local function Settings(key)
    if not Table(FHKEllesmereDB) then FHKEllesmereDB={} end
    local spec=SPEC[key]
    local s=FHKEllesmereDB[key]
    if not Table(s) then s={};FHKEllesmereDB[key]=s end
    for k,v in pairs(spec.DEFAULTS) do
        local x=s[k]
        if type(v)=='boolean' then if not Plain(x) or type(x)~='boolean' then s[k]=v end
        elseif spec.LIMITS[k] then if not Number(x) or x<spec.LIMITS[k][1] or x>spec.LIMITS[k][2] then s[k]=v end
        elseif spec.CHOICES[k] then if not Text(x) or not spec.CHOICES[k][x] then s[k]=v end
        elseif type(v)=='string' then if not ValidLabel(x) then s[k]=v end end
    end
    if s.colors~=nil and not Table(s.colors) then s.colors=nil end
    if s.position~=nil and not ValidPosition(s.position) then s.position=nil end
    return s
end
function NS.EllesmereBehindSettings() return Settings('behindIndicator') end
function NS.EllesmereClassCueSettings() return Settings('classCues') end
function NS.EllesmereEnergyTickSettings() return Settings('energyTick') end
C.SPEC=SPEC

-- Colours: per-element overrides, else the NS.Colours token, else the shipped value.
local TOKEN={behind='behind',front='front',neutral='neutral',likely='neutral',tick='text',cue='caution',opener='behind',snd='caution',stance='caution'}
local FALLBACK={behind={254/255,243/255,103/255},front={1,.3,.25},neutral={.62,.66,.70},tick={.96,.945,.925},caution={1,.82,0},text={.96,.945,.925}}
local function Colour(s,key)
    local c=Table(s) and Table(s.colors) and s.colors[key]
    if ValidColour(c) then return c[1],c[2],c[3] end
    local token=TOKEN[key] or key
    c=NS.Colours and NS.Colours[token]
    if not ValidColour(c) then c=FALLBACK[token] or FALLBACK.neutral end
    return c[1],c[2],c[3]
end
C.Colour=Colour
local function ColourList(s,key) local r,g,b=Colour(s,key);return {r,g,b} end

local CLASS={behind={ROGUE=true,DRUID=true},tick={ROGUE=true,DRUID=true},cues={ROGUE=true,DRUID=true,WARRIOR=true}}
C.CLASS=CLASS

-------------------------------------------------------------------------------
-- Spells (rank 1 IDs; names cover every rank). Victory Rush 402927 is Forever's.
-------------------------------------------------------------------------------
local SPELL={backstab=53,ambush=8676,garrote=703,shred=5221,ravage=6785,cheap=1833,pounce=9005,
    overpower=7384,revenge=6572,execute=5308,victoryRush=402927,riposte=14251,snd=5171,
    battle=2457,defensive=71,berserker=2458}
C.SPELL=SPELL
local BEHIND_ONLY={backstab=true,ambush=true,garrote=true,shred=true,ravage=true}
-- Stuns and incapacitates (any caster): a held target keeps you targeted but cannot turn, so
-- "it targets you" no longer means In Front (lead review: Gouge or Cheap Shot, step behind, Backstab).
local HOLDS={1776,1833,408,6770,2094,9005,5211,853,20066,12809,7922,20253,24394,20549,6358,19503,3355,118,2637,9484,5530}
local behindNames,holdNames={},{}
local function RefreshNames()
    for k in pairs(behindNames) do behindNames[k]=nil end
    for key in pairs(BEHIND_ONLY) do local n=SpellName(SPELL[key]);if n then behindNames[n]=true end end
    for i=#holdNames,1,-1 do holdNames[i]=nil end
    local seen={}
    for _,id in ipairs(HOLDS) do local n=SpellName(id);if n and not seen[n] then seen[n]=true;holdNames[#holdNames+1]=n end end
end

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------
local driver=CreateFrame('Frame')
local cls,bcfg,ccfg,tcfg
local on={behind=false,cues=false,tick=false}
local evidence={kind=nil,untilTime=0,token=0}
local lastState,previewState,previewToken=nil,nil,0
local block,meleeTicker
local Show,Hide

-------------------------------------------------------------------------------
-- 1. Behind indicator.
-------------------------------------------------------------------------------
local function TargetOnYou() return Read(_G.UnitIsUnit,'targettarget','player') end
-- true: the target is stunned or incapacitated; false: readable and free; nil: unknown (secret).
-- Cached (review R1-7): recomputed only after a target UNIT_AURA, a target change or a name refresh.
local held,heldDirty=nil,true
local function ReadHeld()
    local get=C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
    if type(get)~='function' then return nil end
    for _,name in ipairs(holdNames) do
        local ok,a=pcall(get,'target',name,'HARMFUL')
        if not ok or not Plain(a) then return nil end
        if type(a)=='table' then return true end
    end
    return false
end
local function TargetHeld()
    if heldDirty then held=ReadHeld();heldDirty=false end
    return held
end
local function HeldChanged() heldDirty=true end
C.TargetHeld=TargetHeld
-- nil: hidden (no hostile living target); else 'front' / 'behind' / 'likely' / 'neutral'.
function C.BehindState(now)
    if not HostileTarget() then return nil end
    now=now or Now()
    local onYou=TargetOnYou()
    -- Fresh evidence wins: a landed Backstab proves Behind, the must-be-behind error In Front.
    if evidence.kind and now<evidence.untilTime then return evidence.kind end
    if onYou==true then
        -- A held target cannot turn to face you; unknown hold keeps the old answer.
        if TargetHeld()==true then return 'neutral' end
        return 'front'
    end
    local s=bcfg or NS.EllesmereBehindSettings()
    if s.likely and onYou==false and Yes(Read(_G.UnitExists,'targettarget')) then return 'likely' end
    return 'neutral'
end
local function ClearEvidence() evidence.kind=nil;evidence.untilTime=0;evidence.token=evidence.token+1 end
local PaintBehind
local function Evidence(kind)
    local s=bcfg or NS.EllesmereBehindSettings()
    evidence.kind=kind;evidence.untilTime=Now()+s.hold;evidence.token=evidence.token+1
    local token=evidence.token
    After(s.hold+.05,function() if token==evidence.token then evidence.kind=nil;if PaintBehind then PaintBehind() end end end)
end
C.Evidence=Evidence
local function InMelee()
    local get=NS.GetEllesmereRangeSample or NS.GetEllesmereRange
    local r=Read(get,'target')
    local state=Table(r) and Plain(r.state) and r.state or nil
    -- Unreadable range never hides the indicator.
    if state==nil or state=='unknown' then return true end
    return state=='melee'
end
local function Font(fs,size)
    local path=Read(EUI.GetFontPath,'extras')
    fs:SetFont(Text(path) and path or 'Fonts\\FRIZQT__.TTF',size,'OUTLINE')
    if NS.ApplyEllesmereCueText then NS.ApplyEllesmereCueText(fs,'world') end
end
local function PositionBehind()
    if not block then return end
    local p=NS.EllesmereBehindSettings().position
    block:ClearAllPoints()
    if ValidPosition(p) then block:SetPoint(p.point,UIParent,p.relPoint,p.x,p.y)
    elseif _G.FHKEllesmereRange then block:SetPoint('TOP',_G.FHKEllesmereRange,'BOTTOM',0,-4)
    else block:SetPoint('CENTER',UIParent,'CENTER',0,-170) end
end
local function LayoutBehind()
    if not block then return end
    local s=NS.EllesmereBehindSettings()
    block:SetSize(s.width,s.height)
    block.fill:ClearAllPoints()
    if s.shape=='bar' then
        block.fill:SetPoint('BOTTOMLEFT',block,'BOTTOMLEFT',0,0);block.fill:SetPoint('BOTTOMRIGHT',block,'BOTTOMRIGHT',0,0)
        block.fill:SetHeight(math.max(2,math.floor(s.height/4)))
    else block.fill:SetAllPoints(block) end
    Font(block.text,s.fontSize)
    PositionBehind()
end
local function BuildBehind()
    if block then return end
    block=CreateFrame('Frame','FHKEllesmereBehind',UIParent)
    block:SetFrameStrata('MEDIUM')
    block.fill=block:CreateTexture(nil,'ARTWORK')
    block.fill:SetColorTexture(1,1,1,1)
    block.text=block:CreateFontString(nil,'OVERLAY')
    block.text:SetPoint('CENTER',block,'CENTER',0,0)
    block:Hide()
    if EUI.MakeUnlockElement and EUI.RegisterUnlockElements then
        EUI:RegisterUnlockElements({EUI.MakeUnlockElement({key='FHKEllesmereBehind',label='Behind Indicator',group='Resource & Cast Bars',order=531,noResize=true,
            getFrame=function() return block end,getSize=function() return block:GetWidth(),block:GetHeight() end,
            isHidden=function() return not on.behind end,
            savePos=function(_,point,relPoint,x,y)
                local p={point=point,relPoint=relPoint,x=x,y=y}
                if ValidPosition(p) then NS.EllesmereBehindSettings().position=p;PositionBehind() end
            end,
            loadPos=function() return NS.EllesmereBehindSettings().position end,
            clearPos=function() NS.EllesmereBehindSettings().position=nil;PositionBehind() end,applyPos=PositionBehind})},'FHKEllesmere')
    end
    LayoutBehind()
end
local LABEL_KEY={behind='labelBehind',front='labelFront',likely='labelLikely',neutral='labelNeutral'}
PaintBehind=function()
    if not block then return end
    local s=NS.EllesmereBehindSettings()
    local state=previewState
    if not state and on.behind then
        state=C.BehindState()
        if state and s.combatOnly and not InCombat() then state=nil end
        if state and s.meleeOnly and not InMelee() then state=nil end
        if state=='front' and lastState~='front' and s.sound~='none' and NS.PlayEllesmereCueSound then NS.PlayEllesmereCueSound(s.sound,'classCuesFront') end
        lastState=state
    end
    if not state then block:Hide();return end
    local r,g,b=Colour(s,state)
    if s.shape=='text' then block.fill:Hide() else block.fill:Show();block.fill:SetVertexColor(r,g,b,s.opacity) end
    local label=s[LABEL_KEY[state]] or ''
    if s.text and label~='' then
        block.text:SetText(label)
        if s.shape=='block' then block.text:SetTextColor(1,1,1,1) else block.text:SetTextColor(r,g,b,1) end
        block.text:Show()
    else block.text:SetText('');block.text:Hide() end
    block:Show()
end
C.PaintBehind=function() PaintBehind() end
local function MeleeTicker(want)
    if want and not meleeTicker and C_Timer and C_Timer.NewTicker then meleeTicker=C_Timer.NewTicker(.25,function() PaintBehind() end)
    elseif not want and meleeTicker then meleeTicker:Cancel();meleeTicker=nil end
end
function NS.PreviewEllesmereBehind()
    if not block then BuildBehind() end
    previewToken=previewToken+1
    local token=previewToken
    previewState='behind';PaintBehind()
    After(1.5,function() if token==previewToken then previewState='front';PaintBehind() end end)
    After(3,function() if token==previewToken then previewState=nil;PaintBehind() end end)
end

-------------------------------------------------------------------------------
-- 2. State cues from UI_ERROR_MESSAGE. Names from GetGameMessageInfo (errorName) first, the
-- LE_GAME_ERR_* index next, then the client's own GlobalStrings text (with %s as a capture).
-------------------------------------------------------------------------------
local ERRORS={
    {kind='stealth',classes={ROGUE=true,DRUID=true},keys={'SPELL_FAILED_ONLY_STEALTHED'}},
    {kind='behind',classes={ROGUE=true,DRUID=true},keys={'SPELL_FAILED_NOT_BEHIND','SPELL_FAILED_UNIT_NOT_BEHIND'}},
    {kind='stance',classes={WARRIOR=true},keys={'SPELL_FAILED_ONLY_SHAPESHIFT','ERR_SPELL_FAILED_SHAPESHIFT_FORM_S'}},
    {kind='form',classes={DRUID=true},keys={'SPELL_FAILED_NOT_SHAPESHIFT','ERR_NOT_WHILE_SHAPESHIFTED','ERR_NO_ITEMS_WHILE_SHAPESHIFTED',
        'ERR_CANT_INTERACT_SHAPESHIFTED','ERR_MOUNT_SHAPESHIFTED','ERR_TAXIPLAYERSHAPESHIFTED','ERR_SPELL_FAILED_SHAPESHIFT_FORM_S'}},
    {kind='formNeeded',classes={DRUID=true},keys={'SPELL_FAILED_ONLY_SHAPESHIFT'}},
}
C.ERRORS=ERRORS
local patterns={}
local function Pattern(fmt)
    local p=patterns[fmt]
    if p==nil then
        p=fmt:gsub('%%%d?%$?[sd]','\1'):gsub('[%^%$%(%)%%%.%[%]%*%+%-%?]','%%%0'):gsub('\1','(.+)')
        p='^'..p..'$';patterns[fmt]=p
    end
    return p
end
local function TextMatch(key,message)
    for _,name in ipairs({key,'ERR_'..key}) do
        local text=_G[name]
        if Text(text) then
            if message==text then return true end
            if text:find('%',1,true) then local cap=message:match(Pattern(text));if cap then return true,cap end end
        end
    end
end
function C.ClassifyError(id,message,class)
    if not Plain(id) or not Plain(message) then return end
    local errName=Number(id) and Read(_G.GetGameMessageInfo,id) or nil
    if not Text(errName) then errName=nil end
    message=Text(message) and message or nil
    for _,e in ipairs(ERRORS) do
        if e.classes[class] then
            for _,key in ipairs(e.keys) do
                local errKey=key:find('^ERR_') and key or ('ERR_'..key)
                local hit=errName and (errName==key or errName==errKey)
                local le=_G['LE_GAME_'..errKey]
                if not hit and Number(id) and Number(le) and le==id then hit=true end
                local textHit,cap
                if message then textHit,cap=TextMatch(key,message) end
                if hit or textHit then return e.kind,cap,key end
            end
        end
    end
end
local stateToken=0
-- One shapeshift string, two meanings (review R1-3, probe): "can't while in X" is LEAVE FORM for
-- druids; for warriors it names the stance you are in, so it shows WRONG STANCE without the capture.
local NOT_WHILE_KEY='ERR_SPELL_FAILED_SHAPESHIFT_FORM_S'
local function StateCue(kind,cap,key)
    if kind=='stance' and key==NOT_WHILE_KEY then cap=nil end
    local s=ccfg
    local text
    if kind=='stealth' then if not s.stealth then return end;text=cls=='DRUID' and 'PROWL FIRST' or 'STEALTH FIRST'
    elseif kind=='behind' then if not s.behindError then return end;text='GET BEHIND'
    elseif kind=='stance' then if not s.stance then return end;text=Text(cap) and cap:sub(1,40):upper() or 'WRONG STANCE'
    elseif kind=='form' then if not s.form then return end;text='LEAVE FORM'
    elseif kind=='formNeeded' then if not s.form then return end;text=Text(cap) and cap:sub(1,40):upper() or 'WRONG FORM' end
    if not text then return end
    Show('classCueState',text,ColourList(s,'cue'),s.aboveCharacter,s.sound~='none' and s.sound or nil)
    stateToken=stateToken+1
    local token=stateToken
    if not After(s.hold,function() if token==stateToken then Hide('classCueState') end end) then Hide('classCueState') end
end
C.StateCue=StateCue

-------------------------------------------------------------------------------
-- 3. Stealth / Prowl opener.
-------------------------------------------------------------------------------
local function MainHandDagger()
    local id=Read(_G.GetInventoryItemID,'player',16)
    if not Number(id) then return false end
    local info=C_Item and C_Item.GetItemInfoInstant or _G.GetItemInfoInstant
    if type(info)~='function' then return false end
    local ok,_,_,_,_,_,classID,subclassID=pcall(info,id)
    return ok and Number(classID) and Number(subclassID) and classID==2 and subclassID==15 or false
end
C.MainHandDagger=MainHandDagger
-- Within reach: melee, or a readable distance under 10 yd (shared range reader). Unknown is quiet.
-- Second return: true when the range could not be read at all.
local function OpenerRange()
    local r=Read(NS.GetEllesmereRangeSample or NS.GetEllesmereRange,'target')
    if not Table(r) or not Plain(r.state) or r.state=='unknown' then return false,true end
    if r.state=='melee' then return true,false end
    if r.state~='distance' or not Number(r.distance) then return false,true end
    return r.distance<10,false
end
C.OpenerRange=OpenerRange
local openerTicker
function C.Opener()
    local s=ccfg or NS.EllesmereClassCueSettings()
    if not s.opener or Read(_G.IsStealthed)~=true or not HostileTarget() then return nil end
    local near,unknown=OpenerRange()
    if not near then return nil,true,unknown end
    local front=TargetOnYou()==true or on.behind and C.BehindState()=='front'
    local order
    if cls=='ROGUE' then
        order={}
        if MainHandDagger() then order[1]='ambush' end
        if s.openerRogue=='cheap' then order[#order+1]='cheap';order[#order+1]='garrote'
        else order[#order+1]='garrote';order[#order+1]='cheap' end
    elseif cls=='DRUID' then
        order=s.openerDruid=='pounce' and {'pounce','ravage'} or {'ravage','pounce'}
    else return nil end
    for _,key in ipairs(order) do
        if not (front and BEHIND_ONLY[key]) and Known(SPELL[key]) then return key end
    end
end
-- Range has no event: a 0.25 s poll runs only while stealthed with a hostile target out of reach.
local function OpenerPoll(want)
    if want and not openerTicker and C_Timer and C_Timer.NewTicker then openerTicker=C_Timer.NewTicker(.25,function() C.CheckOpener() end)
    elseif not want and openerTicker then openerTicker:Cancel();openerTicker=nil end
end
C.OpenerPoll=function() return openerTicker end
-- Unreadable range (review R1-17): give up polling after 8 tries (2 s) until the next stealth,
-- target or equipment event; the cue stays quiet.
local openerTries=0
C.ResetOpenerTries=function() openerTries=0 end
function C.CheckOpener()
    local key,far,unknown=nil,false,false
    if on.cues then key,far,unknown=C.Opener() end
    if far and unknown then openerTries=openerTries+1 elseif far then openerTries=0 end
    OpenerPoll(far==true and openerTries<8)
    if not key then Hide('classCueOpener');return end
    local id=SPELL[key]
    local icon=SpellIcon(id)
    Show('classCueOpener',(icon and ('|T'..icon..':0|t ') or '')..(SpellName(id) or key),ColourList(ccfg,'opener'),false)
end

-------------------------------------------------------------------------------
-- 4. Reactive ability glows (HunterCues pattern: Ellesmere's own proc glow engine and style).
-------------------------------------------------------------------------------
local REACTIVE={WARRIOR={'overpower','revenge','execute','victoryRush'},ROGUE={'riposte'}}
C.REACTIVE=REACTIVE
local glowing={}
local function ButtonSpellName(btn)
    local slot=btn.action or (btn.GetAttribute and Read(btn.GetAttribute,btn,'action'))
    if not Number(slot) then return end
    local kind,id=Read(_G.GetActionInfo,slot)
    if kind=='macro' then id=Read(_G.GetMacroSpell,id);kind=Number(id) and 'spell' or nil end
    if kind=='spell' and Number(id) then return SpellName(id) end
end
local function ActionButtons(fn)
    local ab=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIActionBars
    local bars=ab and ab.barButtons
    if not Table(bars) then return end
    for _,list in pairs(bars) do
        if type(list)=='table' then for _,btn in ipairs(list) do if type(btn)=='table' then fn(btn) end end end
    end
end
local function StartGlow(btn)
    local G=EUI.Glows
    if not G then return end
    local wrapper=glowing[btn]
    if not wrapper then
        wrapper=CreateFrame('Frame',nil,btn);wrapper:SetAllPoints(btn);wrapper:EnableMouse(false)
        glowing[btn]=wrapper
    end
    wrapper:SetFrameLevel((Read(btn.GetFrameLevel,btn) or 1)+10)
    local w,h=Read(btn.GetWidth,btn) or 45,Read(btn.GetHeight,btn) or 45
    local ab=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIActionBars
    local p=ab and ab.EAB and ab.EAB.db and ab.EAB.db.profile or {}
    pcall(G.StopAllGlows,wrapper);wrapper:Show();wrapper:SetAlpha(1)
    if not p.procGlowEnabled or not G.MakeView then
        pcall(G.StartGlow,wrapper,6,w,1,.788,.137,nil,h)
        return
    end
    local list=G.MakeView({1,2,3,4,5,6,7}).list
    local entry=list[p.procGlowType or 1] or list[1]
    local c=p.procGlowColor or {r=1,g=.776,b=.376}
    local cr,cg,cb=c.r,c.g,c.b
    if G.ResolveColor then cr,cg,cb=G.ResolveColor(p.procGlowUseClassColor and 'class' or (p.procGlowColorMode=='default' and 'default' or 'custom'),c.r,c.g,c.b) end
    if cr==nil then local d=G.DEFAULT_COLOR or {r=1,g=.788,b=.137};cr,cg,cb=d.r,d.g,d.b end
    if entry.procedural then
        local n,th,period=p.procGlowLines or 8,p.procGlowThickness or 2,p.procGlowSpeed or 4
        local len=math.max(1,math.min(math.floor((w+h)*(2/n-.1)),math.min(w,h)))
        pcall(G.StartProceduralAnts,wrapper,n,th,period,len,cr,cg,cb,w,h)
    elseif entry.buttonGlow then pcall(G.StartButtonGlow,wrapper,w,cr,cg,cb,nil,h)
    elseif entry.autocast then pcall(G.StartAutoCastShine,wrapper,w,cr,cg,cb,1.0,h)
    elseif entry.shapeGlow then pcall(G.StartGlow,wrapper,6,w,cr,cg,cb,nil,h)
    else pcall(G.StartFlipBookGlow,wrapper,w,entry,cr,cg,cb,h) end
end
local function StopGlow(btn)
    local wrapper=glowing[btn]
    if not wrapper then return end
    if EUI.Glows then pcall(EUI.Glows.StopAllGlows,wrapper) end
    wrapper:Hide()
end
-- Reused tables and a spell -> buttons map (review R1-8), rebuilt only after a slot, page,
-- bonus bar, stance or spellbook change.
local live,want,byName,mapDirty={},{},{},true
local function MapChanged() mapDirty=true end
C.MapChanged=MapChanged
local function RebuildMap()
    for _,list in pairs(byName) do for i=#list,1,-1 do list[i]=nil end end
    ActionButtons(function(btn)
        local name=ButtonSpellName(btn)
        if name then local list=byName[name];if not list then list={};byName[name]=list end;list[#list+1]=btn end
    end)
    mapDirty=false
end
C.MapBuilds=0
function C.ReactiveLive()
    for k in pairs(live) do live[k]=nil end
    local s=ccfg
    if not (on.cues and s and s.reactive and REACTIVE[cls]) then return live end
    local usable=C_Spell and C_Spell.IsSpellUsable
    for _,key in ipairs(REACTIVE[cls]) do
        if s[key] then
            local name=SpellName(SPELL[key])
            if name and Known(SPELL[key]) and Read(usable,name)==true then live[name]=true end
        end
    end
    return live
end
function C.CheckReactive()
    C.ReactiveLive()
    for k in pairs(want) do want[k]=nil end
    if next(live) then
        if mapDirty then RebuildMap();C.MapBuilds=C.MapBuilds+1 end
        for name in pairs(live) do local list=byName[name];if list then for _,btn in ipairs(list) do want[btn]=true end end end
    end
    for btn in pairs(glowing) do if not want[btn] then StopGlow(btn) end end
    for btn in pairs(want) do
        local wrapper=glowing[btn]
        if not (wrapper and wrapper:IsShown()) then StartGlow(btn) end
    end
end
C.Glowing=function() return glowing end

-------------------------------------------------------------------------------
-- Warrior stance-mismatch hint: the reactive window opened (UNIT_COMBAT dodge / parry / block,
-- or an Execute-range target when health is readable) but you are in the wrong stance.
-------------------------------------------------------------------------------
local FORM={battle=17,defensive=18,berserker=19}
local windows={overpower=0,revenge=0}
local defensiveAt,lastForm=nil,nil
-- Revenge advice only for a warrior who used Defensive Stance in the last 5 minutes (S41).
local function NoteForm()
    local form=Read(_G.GetShapeshiftFormID)
    if not Number(form) then return end
    if form==FORM.defensive or lastForm==FORM.defensive then defensiveAt=Now() end
    lastForm=form
end
C.NoteForm=NoteForm
local stanceToken=0
local STANCE_RULES={
    {key='overpower',stances={[FORM.battle]=true},want='battle',soloFromDefensive=true},
    {key='revenge',stances={[FORM.defensive]=true},want='defensive',recentDefensive=true},
    {key='execute',stances={[FORM.battle]=true,[FORM.berserker]=true},want='battle',soloFromDefensive=true},
}
local function ExecuteRange() local f=TargetHealth();return f~=nil and f<.2 end
function C.StanceHint(now)
    local s=ccfg
    if not (on.cues and s and s.stanceHint and cls=='WARRIOR') or not HostileTarget() then return nil end
    now=now or Now()
    local form=Read(_G.GetShapeshiftFormID)
    if not Number(form) then return nil end
    if form==FORM.defensive then defensiveAt=now end
    for _,rule in ipairs(STANCE_RULES) do
        local open=rule.key=='execute' and ExecuteRange() or rule.key~='execute' and windows[rule.key]>now
        -- Never tell a tank to leave Defensive Stance in a group or an instance (S40).
        if open and rule.soloFromDefensive and form==FORM.defensive and not Solo() then open=false end
        if open and rule.recentDefensive and not (defensiveAt and now-defensiveAt<=300) then open=false end
        if s[rule.key] and open and not rule.stances[form] and Known(SPELL[rule.key]) then return rule.key,rule.want end
    end
end
function C.CheckStance()
    local key,want=C.StanceHint()
    if not key then Hide('classCueStance');return end
    Show('classCueStance',(SpellName(SPELL[want]) or want)..' - '..(SpellName(SPELL[key]) or key),ColourList(ccfg,'stance'),ccfg.aboveCharacter)
end
local function OpenWindow(key)
    windows[key]=Now()+5
    stanceToken=stanceToken+1
    local token=stanceToken
    After(5.05,function() if token==stanceToken and C.CheckStance then C.CheckStance() end end)
end

-------------------------------------------------------------------------------
-- 5. Slice and Dice. Aura reads can turn secret in combat: the last readable answer is kept.
-------------------------------------------------------------------------------
local snd={expires=nil,token=0,timerAt=nil} -- expires: number, false (missing) or nil (unknown)
local function ComboPoints()
    local cp=Read(_G.GetComboPoints,'player','target')
    if not Number(cp) then cp=Read(_G.UnitPower,'player',Enum and Enum.PowerType and Enum.PowerType.ComboPoints or 4) end
    return Number(cp) and cp or nil
end
local function ReadSnD()
    local name=SpellName(SPELL.snd)
    local get=C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
    if not name or type(get)~='function' then return end
    local ok,a=pcall(get,'player',name,'HELPFUL|PLAYER')
    if not ok or not Plain(a) then return end
    if a==nil then snd.expires=false;return end
    if type(a)~='table' then return end
    local exp=a.expirationTime
    snd.expires=Number(exp) and exp>0 and exp or math.huge
end
function C.SnDState(now)
    local s=ccfg
    if not (on.cues and s and s.snd and cls=='ROGUE') or not Known(SPELL.snd) then return nil end
    if not InCombat() or not HostileTarget() then return nil end
    local cp=ComboPoints()
    if not cp or cp<s.sndPoints then return nil end
    -- A target about to die needs no Slice and Dice (S42; only when health is readable).
    local hp=TargetHealth()
    if hp and hp<.35 then return nil end
    now=now or Now()
    if snd.expires==false then return 'missing' end
    if not Number(snd.expires) then return nil end
    if snd.expires<=now then return 'missing' end
    if snd.expires-now<=s.sndWarn then return 'expiring',snd.expires end
    return nil,snd.expires
end
function C.CheckSnD()
    local now=Now()
    ReadSnD()
    local state,expires=C.SnDState(now)
    -- One timer to the next boundary (warn window, then expiry); no ticker. A new timer only when
    -- that boundary moves (review R1-2): health and combo point events reuse the pending one.
    local at
    if Number(expires) and expires<math.huge then at=expires-now>ccfg.sndWarn and expires-ccfg.sndWarn or expires end
    if at~=snd.timerAt then
        snd.token=snd.token+1;snd.timerAt=at
        if at then
            local token=snd.token
            if After(at-now+.05,function() if token==snd.token then snd.timerAt=nil;C.CheckSnD() end end) then C.SnDTimers=(C.SnDTimers or 0)+1 end
        end
    end
    local name=SpellName(SPELL.snd) or 'Slice and Dice'
    if state=='missing' then Show('classCueSnD',name,ColourList(ccfg,'snd'),false)
    elseif state=='expiring' then Show('classCueSnD',name..' Expiring',ColourList(ccfg,'snd'),false)
    else Hide('classCueSnD') end
end

-------------------------------------------------------------------------------
-- 6. Energy tick spark (probe first): ticks are +20 energy every 2 s (+40 under Adrenaline
-- Rush); the next one is predicted from the last seen. The spark moves only while energy is
-- below maximum.
-------------------------------------------------------------------------------
local ENERGY=Enum and Enum.PowerType and Enum.PowerType.Energy or 3
local tick={last=nil,energy=nil,max=nil}
local spark,tickBar
local previewTickUntil=0
local function NearCadence(now)
    if not tick.last then return false end
    local phase=(now-tick.last)%2
    return phase<=.35 or phase>=1.65
end
function C.OnEnergy(now)
    now=now or Now()
    local e,m=Read(_G.UnitPower,'player',ENERGY),Read(_G.UnitPowerMax,'player',ENERGY)
    if not Number(e) or not Number(m) then return end
    local prev=tick.energy
    tick.energy,tick.max=e,m
    if prev and e>prev then
        local d=e-prev
        -- Natural ticks are exactly 20 (40 with Adrenaline Rush); a smaller one at the cap or
        -- any gain on the 2 s cadence also counts. Other gains (Relentless Strikes, Thistle Tea) do not.
        if d==20 or d==40 or (d<=45 and NearCadence(now)) then tick.last=now end
    end
end
C.Tick=tick
local function TickPosition()
    if not tickBar then return end
    local p=NS.EllesmereEnergyTickSettings().position
    tickBar:ClearAllPoints()
    if ValidPosition(p) then tickBar:SetPoint(p.point,UIParent,p.relPoint,p.x,p.y)
    elseif _G.ERB_PrimaryBar then tickBar:SetPoint('TOP',_G.ERB_PrimaryBar,'BOTTOM',0,-3)
    else tickBar:SetPoint('CENTER',UIParent,'CENTER',0,-200) end
end
local function BuildTickBar()
    if tickBar then return tickBar end
    tickBar=CreateFrame('Frame','FHKEllesmereEnergyTick',UIParent)
    tickBar:SetFrameStrata('MEDIUM')
    tickBar.bg=tickBar:CreateTexture(nil,'BACKGROUND');tickBar.bg:SetAllPoints(tickBar);tickBar.bg:SetColorTexture(.07,.08,.11,.8)
    tickBar:Hide()
    if EUI.MakeUnlockElement and EUI.RegisterUnlockElements then
        EUI:RegisterUnlockElements({EUI.MakeUnlockElement({key='FHKEllesmereEnergyTick',label='Energy Tick',group='Resource & Cast Bars',order=532,noResize=true,
            getFrame=function() return tickBar end,getSize=function() return tickBar:GetWidth(),tickBar:GetHeight() end,
            isHidden=function() return not (on.tick and tcfg and tcfg.place=='standalone') end,
            savePos=function(_,point,relPoint,x,y)
                local p={point=point,relPoint=relPoint,x=x,y=y}
                if ValidPosition(p) then NS.EllesmereEnergyTickSettings().position=p;TickPosition() end
            end,
            loadPos=function() return NS.EllesmereEnergyTickSettings().position end,
            clearPos=function() NS.EllesmereEnergyTickSettings().position=nil;TickPosition() end,applyPos=TickPosition})},'FHKEllesmere')
    end
    return tickBar
end
-- The host: Ellesmere's power bar (a plain frame, ERB_PrimaryBar) or our own tick bar.
local function TickHost()
    local s=NS.EllesmereEnergyTickSettings()
    local bar=_G.ERB_PrimaryBar
    -- Ellesmere's power bar turned off (hidden): the spark uses its own bar (review R1-16).
    if s.place=='power' and Table(bar) and type(bar.GetWidth)=='function' and Read(bar.IsVisible or bar.IsShown,bar)==true then return bar,true end
    return BuildTickBar(),false
end
C.TickHost=TickHost
local SparkUpdate
local function SparkVisible(now)
    if now<previewTickUntil then return true end
    if not on.tick or not tick.last then return false end
    if Read(_G.UnitPowerType,'player')~=ENERGY then return false end
    return Number(tick.energy) and Number(tick.max) and tick.energy<tick.max or false
end
local function LayoutSpark()
    local host,native=TickHost()
    local s=NS.EllesmereEnergyTickSettings()
    if not native then host:SetSize(s.barWidth,s.barHeight);TickPosition() end
    if tickBar and native then tickBar:Hide() end
    if not spark then
        spark=CreateFrame('Frame',nil,host)
        spark.line=spark:CreateTexture(nil,'OVERLAY')
        spark.line:SetColorTexture(1,1,1,1)
    elseif spark:GetParent()~=host then spark:SetParent(host) end
    spark:SetAllPoints(host)
    if Read(host.GetFrameLevel,host) then spark:SetFrameLevel((Read(host.GetFrameLevel,host) or 1)+5) end
    spark.host,spark.native=host,native
    local r,g,b=Colour(s,'tick')
    spark.line:SetVertexColor(r,g,b,s.opacity)
    local w,h=Read(host.GetWidth,host),Read(host.GetHeight,host)
    spark.vertical=Number(w) and Number(h) and h>w or false
    if spark.vertical then spark.line:SetSize(Number(w) and w or 6,s.width) else spark.line:SetSize(s.width,Number(h) and h or 6) end
end
local function PaintSpark(now)
    if not spark then return end
    local host=spark.host
    local w,h=Read(host.GetWidth,host),Read(host.GetHeight,host)
    local frac=now<previewTickUntil and ((now%2)/2) or ((now-tick.last)%2)/2
    if spark.vertical then
        if Number(h) then spark.line:SetPoint('CENTER',spark,'BOTTOM',0,frac*h) end
    elseif Number(w) then spark.line:SetPoint('CENTER',spark,'LEFT',frac*w,0) end
end
C.PaintSpark=PaintSpark
SparkUpdate=function()
    local now=Now()
    if not SparkVisible(now) then C.RefreshSpark();return end
    PaintSpark(now)
end
function C.RefreshSpark()
    local now=Now()
    local visible=SparkVisible(now)
    if not visible then
        if spark then spark:SetScript('OnUpdate',nil);spark:Hide() end
        if tickBar then tickBar:Hide() end
        return false
    end
    if not spark or spark.host~=(TickHost()) then LayoutSpark() end
    if not spark.native then spark.host:Show() end
    spark:Show();PaintSpark(now)
    if not spark:GetScript('OnUpdate') then spark:SetScript('OnUpdate',SparkUpdate) end
    return true
end
function NS.PreviewEllesmereEnergyTick()
    previewTickUntil=Now()+4
    LayoutSpark();C.RefreshSpark()
    After(4.05,function() C.RefreshSpark() end)
end

-------------------------------------------------------------------------------
-- Lane helpers and preview.
-------------------------------------------------------------------------------
local LANE_KEYS={'classCueState','classCueOpener','classCueStance','classCueSnD'}
-- Lane cues are act-now: quiet while dead, on a taxi, in a vehicle or mounted (shared away policy).
-- The module sound rides with the cue (6th argument); nil keeps the lane's default sound.
Show=function(key,text,colour,critical,sound)
    if NS.EllesmereAway and NS.EllesmereAway('act') then Hide(key);return end
    if NS.ShowEllesmereWarning then NS.ShowEllesmereWarning(key,text,colour,false,critical==true,sound) end
end
Hide=function(key) if NS.HideEllesmereWarning then NS.HideEllesmereWarning(key) end end
local cuePreviewToken=0
function NS.PreviewEllesmereClassCues()
    local s=NS.EllesmereClassCueSettings()
    local c=Class()
    local text=c=='WARRIOR' and 'BATTLE STANCE' or c=='DRUID' and 'PROWL FIRST' or 'STEALTH FIRST'
    Show('classCueState',text,ColourList(s,'cue'),s.aboveCharacter)
    if c=='ROGUE' then Show('classCueSnD',SpellName(SPELL.snd) or 'Slice and Dice',ColourList(s,'snd'),false) end
    cuePreviewToken=cuePreviewToken+1
    local token=cuePreviewToken
    After(3,function() if token==cuePreviewToken then Hide('classCueState');Hide('classCueSnD');C.Flush(true) end end)
end

-------------------------------------------------------------------------------
-- Events: coalesced; only what the enabled features need.
-------------------------------------------------------------------------------
local dirty={}
local scheduled=false
function C.Flush(all)
    scheduled=false
    if all then dirty.behind,dirty.opener,dirty.reactive,dirty.stance,dirty.snd=true,true,true,true,true end
    if dirty.behind then dirty.behind=nil;if on.behind then PaintBehind();MeleeTicker(bcfg.meleeOnly and HostileTarget()) end end
    if dirty.opener then dirty.opener=nil;if on.cues then C.CheckOpener() end end
    if dirty.reactive then dirty.reactive=nil;C.CheckReactive() end
    if dirty.stance then dirty.stance=nil;if on.cues then C.CheckStance() end end
    if dirty.snd then dirty.snd=nil;if on.cues then C.CheckSnD() end end
end
local function Mark(...)
    for i=1,select('#',...) do dirty[select(i,...)]=true end
    if scheduled then return end
    scheduled=true
    if not After(0,function() C.Flush() end) then C.Flush() end
end
C.Mark=Mark
function C.OnEvent(_,event,a,b,c)
    if event=='UI_ERROR_MESSAGE' then
        local kind,cap,key=C.ClassifyError(a,b,cls)
        if not kind then return end
        if kind=='behind' and on.behind and HostileTarget() then Evidence('front');Mark('behind','opener') end
        if on.cues then StateCue(kind,cap,key) end
        return
    end
    if event=='UNIT_SPELLCAST_SUCCEEDED' then
        if a~='player' or not Number(c) then return end
        local name=SpellName(c)
        if on.behind and name and behindNames[name] then Evidence('behind');Mark('behind','opener') end
        if name and name==SpellName(SPELL.snd) then snd.expires=nil;Mark('snd') end
        return
    end
    if event=='UNIT_POWER_FREQUENT' then
        if a~='player' then return end
        if b=='ENERGY' and on.tick then C.OnEnergy();C.RefreshSpark() end
        if b=='COMBO_POINTS' then Mark('snd') end
        return
    end
    if event=='UNIT_MAXPOWER' or event=='UNIT_DISPLAYPOWER' then if on.tick then C.OnEnergy();C.RefreshSpark() end;return end
    if event=='UNIT_COMBAT' then
        if not (on.cues and ccfg.stanceHint) or not Plain(b) or not Plain(c) then return end
        -- UNIT_COMBAT names no attacker (review R1-9, probe): only while you auto-attack the target.
        if a=='target' and b=='DODGE' then if Read(C_Spell and C_Spell.IsCurrentSpell,6603)==true then OpenWindow('overpower');Mark('stance') end
        elseif a=='player' and (b=='DODGE' or b=='PARRY' or b=='BLOCK' or c=='BLOCK') then OpenWindow('revenge');Mark('stance') end
        return
    end
    if event=='PLAYER_REGEN_DISABLED' then combatFlag=true elseif event=='PLAYER_REGEN_ENABLED' then combatFlag=false end
    if event=='PLAYER_TARGET_CHANGED' then
        HeldChanged();openerTries=0
        ClearEvidence();windows.overpower=0
        Mark('behind','opener','reactive','stance','snd');return
    end
    if event=='UNIT_TARGET' then if a=='target' then ClearEvidence();Mark('behind','opener') end;return end
    if event=='UNIT_HEALTH' then Mark('behind','opener','stance','snd');return end
    if event=='UNIT_AURA' then if a=='target' then HeldChanged();Mark('behind') else Mark('snd') end;return end
    if event=='UPDATE_STEALTH' or event=='PLAYER_EQUIPMENT_CHANGED' then openerTries=0;Mark('opener');return end
    if event=='ACTIONBAR_SLOT_CHANGED' or event=='ACTIONBAR_PAGE_CHANGED' or event=='UPDATE_BONUS_ACTIONBAR' then MapChanged();Mark('reactive');return end
    if event=='SPELL_UPDATE_USABLE' then Mark('reactive');return end
    if event=='UPDATE_SHAPESHIFT_FORM' then
        MapChanged()
        if on.cues and ccfg.stanceHint then NoteForm() end
        if on.tick then C.OnEnergy();C.RefreshSpark() end
        Mark('reactive','stance');return
    end
    if event=='SPELLS_CHANGED' then RefreshNames();MapChanged();HeldChanged() end
    if event=='PLAYER_ENTERING_WORLD' then RefreshNames();HeldChanged();MapChanged();if on.behind then PositionBehind() end;if on.tick then C.OnEnergy();C.RefreshSpark() end end
    Mark('behind','opener','reactive','stance','snd')
end
driver:SetScript('OnEvent',C.OnEvent)

local function Sync()
    cls=Class()
    bcfg,ccfg,tcfg=NS.EllesmereBehindSettings(),NS.EllesmereClassCueSettings(),NS.EllesmereEnergyTickSettings()
    on.behind=bcfg.enabled and CLASS.behind[cls] or false
    on.tick=tcfg.enabled and CLASS.tick[cls] or false
    local s=ccfg
    local rogue,druid,warrior=cls=='ROGUE',cls=='DRUID',cls=='WARRIOR'
    local state=(rogue or druid) and (s.stealth or s.behindError) or warrior and s.stance or druid and s.form
    local opener=(rogue or druid) and s.opener
    local reactive=s.reactive and REACTIVE[cls]~=nil
    local stance=warrior and s.stanceHint
    local sndOn=rogue and s.snd
    on.cues=(state or opener or reactive or stance or sndOn) and true or false
    driver:UnregisterAllEvents()
    combatFlag=nil
    -- Off: nothing left behind.
    if not on.behind then
        ClearEvidence();MeleeTicker(false);lastState=nil
        if block and not previewState then block:Hide() end
    end
    if not on.tick then tick.last,tick.energy,tick.max=nil,nil,nil end
    if not on.cues then for _,k in ipairs(LANE_KEYS) do Hide(k) end;stateToken=stateToken+1;snd.token=snd.token+1;snd.timerAt=nil;snd.expires=nil end
    if not on.cues or not opener then Hide('classCueOpener');OpenerPoll(false) end
    if not on.cues or not stance then Hide('classCueStance');windows.overpower,windows.revenge=0,0 else NoteForm() end
    if not on.cues or not sndOn then Hide('classCueSnD') end
    if not on.behind and not on.cues and not on.tick then
        C.CheckReactive();C.RefreshSpark();return
    end
    local events,units={},{}
    local function E(...) for i=1,select('#',...) do events[select(i,...)]=true end end
    local function U(event,...) units[event]=units[event] or {};for i=1,select('#',...) do units[event][select(i,...)]=true end end
    E('PLAYER_ENTERING_WORLD')
    if on.behind then
        BuildBehind();LayoutBehind()
        E('PLAYER_TARGET_CHANGED','UI_ERROR_MESSAGE','PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED')
        U('UNIT_TARGET','target');U('UNIT_SPELLCAST_SUCCEEDED','player');U('UNIT_HEALTH','target');U('UNIT_AURA','target')
    end
    if state then E('UI_ERROR_MESSAGE') end
    if opener then E('UPDATE_STEALTH','PLAYER_TARGET_CHANGED','PLAYER_EQUIPMENT_CHANGED','SPELLS_CHANGED');U('UNIT_TARGET','target');U('UNIT_HEALTH','target') end
    if reactive then E('SPELL_UPDATE_USABLE','ACTIONBAR_SLOT_CHANGED','ACTIONBAR_PAGE_CHANGED','UPDATE_BONUS_ACTIONBAR','SPELLS_CHANGED','UPDATE_SHAPESHIFT_FORM','PLAYER_TARGET_CHANGED') end
    if stance then E('UPDATE_SHAPESHIFT_FORM','PLAYER_TARGET_CHANGED');U('UNIT_COMBAT','player','target');U('UNIT_HEALTH','target') end
    if sndOn then
        E('PLAYER_TARGET_CHANGED','PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED','SPELLS_CHANGED')
        U('UNIT_AURA','player');U('UNIT_POWER_FREQUENT','player');U('UNIT_SPELLCAST_SUCCEEDED','player');U('UNIT_HEALTH','target')
    end
    if on.tick then E('UPDATE_SHAPESHIFT_FORM');U('UNIT_POWER_FREQUENT','player');U('UNIT_MAXPOWER','player');U('UNIT_DISPLAYPOWER','player') end
    for event in pairs(events) do driver:RegisterEvent(event) end
    for event,set in pairs(units) do
        local list={}
        for unit in pairs(set) do list[#list+1]=unit end
        table.sort(list)
        if driver.RegisterUnitEvent then driver:RegisterUnitEvent(event,unpack(list)) else driver:RegisterEvent(event) end
    end
    RefreshNames();HeldChanged();MapChanged()
    -- The combat flag is only kept while the regen events that maintain it are registered.
    combatFlag=nil
    if events.PLAYER_REGEN_DISABLED then combatFlag=InCombat() end
    if on.tick then
        if spark then LayoutSpark() end
        C.OnEnergy()
    end
    C.RefreshSpark()
    C.Flush(true)
end
C.Sync=Sync
C.State=function() return {driver=driver,block=block,spark=spark,tickBar=tickBar,on=on,evidence=evidence,meleeTicker=meleeTicker,windows=windows,snd=snd} end
function NS.SyncEllesmereClassCues() Sync() end
NS.SyncEllesmereBehind=NS.SyncEllesmereClassCues
NS.SyncEllesmereEnergyTick=NS.SyncEllesmereClassCues

-------------------------------------------------------------------------------
-- Options.
-------------------------------------------------------------------------------
local function Setter(key,after)
    return function(k,v)
        local spec=SPEC[key]
        local d=spec.DEFAULTS[k]
        if spec.LIMITS[k] then if not Number(v) or v<spec.LIMITS[k][1] or v>spec.LIMITS[k][2] then return end
        elseif spec.CHOICES[k] then if not Text(v) or not spec.CHOICES[k][v] then return end
        elseif type(d)=='boolean' then if not Plain(v) or type(v)~='boolean' then return end
        elseif type(d)=='string' then
            if not Plain(v) or type(v)~='string' then return end
            v=v:gsub('|',''):gsub('^%s+',''):gsub('%s+$',''):sub(1,24)
        else return end
        Settings(key)[k]=v
        if after then after() end
        Sync()
        if EUI.RefreshPage then pcall(EUI.RefreshPage,EUI) end
    end
end
local function Swatch(key,colourKey,tooltip,after)
    return {tooltip=tooltip,hasAlpha=false,getValue=function() local r,g,b=Colour(Settings(key),colourKey);return r,g,b,1 end,
        setValue=function(r,g,b)
            local c={r,g,b}
            if not ValidColour(c) then return end
            local s=Settings(key);s.colors=Table(s.colors) and s.colors or {};s.colors[colourKey]=c
            if after then after() end
        end}
end
local function Blank() return EUI.BlankRowCfg and EUI.BlankRowCfg() or {type='label',text=''} end
local function ResetKeys(key,keep)
    local s=Settings(key)
    for k,v in pairs(SPEC[key].DEFAULTS) do if not keep[k] then s[k]=v end end
    s.colors=nil;s.position=nil
end

-- Resource Bars > BEHIND INDICATOR (rogue, druid).
function NS.AddEllesmereBehindOptions(Row)
    local class=Class()
    if not CLASS.behind[class] then return end
    if EUI.IsSearchPrebuild and EUI.IsSearchPrebuild() then
        Row({type='label',text='Behind Indicator'},{type='label',text='Likely Behind'})
        Row({type='label',text='Evidence Hold (sec)'},{type='label',text='Sound When In Front'})
        return
    end
    local function S() return NS.EllesmereBehindSettings() end
    local Set=Setter('behindIndicator',function() if block then LayoutBehind() end end)
    local function Off() return not S().enabled end
    local repaint=function() if block then PaintBehind() end end
    local behindSpell=SpellName(class=='DRUID' and SPELL.shred or SPELL.backstab) or (class=='DRUID' and 'Shred' or 'Backstab')
    local main={type='toggle',text='Behind Indicator',
        tooltip='A block under the range indicator. In Front: your target is attacking you (mobs face what they attack) or the game said you must be behind. Behind: '..behindSpell..' or another behind-only ability just landed. Unknown otherwise. Forever has no facing API, so this follows that evidence.',
        getValue=function() return S().enabled end,setValue=function(v) Set('enabled',v) end}
    main.swatches={Swatch('behindIndicator','behind','Behind Color',repaint),Swatch('behindIndicator','front','In Front Color',repaint),
        Swatch('behindIndicator','neutral','Unknown Color',repaint),Swatch('behindIndicator','likely','Likely Behind Color',repaint)}
    main.preview={tip='Preview Behind, then In Front',show=NS.PreviewEllesmereBehind,duration=3,disabled=Off,disabledTooltip='Behind Indicator'}
    main.cog={title='Behind Indicator Layout',disabled=Off,disabledTooltip='Behind Indicator',rows={
        {type='dropdown',label='Shape',values={block='Color Block',bar='Bar Under Text',text='Text Only'},order={'block','bar','text'},
            get=function() return S().shape end,set=function(v) Set('shape',v) end},
        {type='slider',label='Width',min=16,max=200,step=1,get=function() return S().width end,set=function(v) Set('width',v) end},
        {type='slider',label='Height',min=4,max=40,step=1,get=function() return S().height end,set=function(v) Set('height',v) end},
        {type='slider',label='Opacity %',min=10,max=100,step=5,get=function() return math.floor(S().opacity*100+.5) end,
            set=function(v) if Number(v) then Set('opacity',v/100) end end},
        {type='slider',label='Font Size',min=8,max=20,step=1,get=function() return S().fontSize end,set=function(v) Set('fontSize',v) end}}}
    Row(main,{type='toggle',text='Likely Behind',disabled=Off,disabledTooltip='Behind Indicator',
        tooltip='While your target attacks someone else, the indicator says Likely: it is probably facing them.',
        getValue=function() return S().likely end,setValue=function(v) Set('likely',v) end})
    Row({type='slider',text='Evidence Hold (sec)',min=1,max=10,step=.5,disabled=Off,disabledTooltip='Behind Indicator',
        tooltip='How long a landed behind-only ability or a "must be behind" error keeps the indicator on Behind or In Front.',
        getValue=function() return S().hold end,setValue=function(v) Set('hold',v) end},
        {type='dropdown',text='Sound When In Front',values=SOUND_VALUES,order=SOUND_ORDER,disabled=Off,disabledTooltip='Behind Indicator',
        getValue=function() return S().sound end,
        setValue=function(v) Set('sound',v);if NS.PlayEllesmereCueSound then NS.PlayEllesmereCueSound(v,'classCuesFrontPreview') end end})
    Row({type='toggle',text='Only In Melee Range',disabled=Off,disabledTooltip='Behind Indicator',
        tooltip='Shows only while your target is in melee range (an unreadable range still shows it).',
        getValue=function() return S().meleeOnly end,setValue=function(v) Set('meleeOnly',v) end},
        {type='toggle',text='Only In Combat',disabled=Off,disabledTooltip='Behind Indicator',
        getValue=function() return S().combatOnly end,setValue=function(v) Set('combatOnly',v) end})
    local text={type='toggle',text='Behind Indicator Text',disabled=Off,disabledTooltip='Behind Indicator',
        getValue=function() return S().text end,setValue=function(v) Set('text',v) end}
    local function Label(label,k) return {type='input',label=label,get=function() return S()[k] end,set=function(v) Set(k,v) end} end
    text.cog={title='Behind Indicator Text',disabled=function() return Off() or not S().text end,disabledTooltip='Behind Indicator Text',rows={
        Label('Behind Label','labelBehind'),Label('In Front Label','labelFront'),Label('Likely Behind Label','labelLikely'),Label('Unknown Label','labelNeutral')}}
    Row(text,{type='label',text='Move it in Unlock Mode: Behind Indicator'})
    Row({type='button',text='Reset Behind Colors',onClick=function() S().colors=nil;repaint() end},
        {type='button',text='Reset Behind Indicator',onClick=function() ResetKeys('behindIndicator',{enabled=true});if block then LayoutBehind() end;Sync() end})
end

-- Resource Bars > ENERGY TICK (rogue, druid in Cat Form).
function NS.AddEllesmereEnergyTickOptions(Row)
    if not CLASS.tick[Class()] then return end
    if EUI.IsSearchPrebuild and EUI.IsSearchPrebuild() then
        Row({type='label',text='Energy Tick Spark'},{type='label',text='Energy Tick Placement'})
        return
    end
    local function S() return NS.EllesmereEnergyTickSettings() end
    local Set=Setter('energyTick',function() if spark then LayoutSpark() end end)
    local function Off() return not S().enabled end
    local main={type='toggle',text='Energy Tick Spark',
        tooltip='Energy comes in ticks of 20 every 2 seconds. A spark sweeps across the energy bar to the next tick, while your energy is below full. Learned from your own ticks: it starts after the first one.',
        getValue=function() return S().enabled end,setValue=function(v) Set('enabled',v) end}
    main.swatches={Swatch('energyTick','tick','Spark Color',function() if spark then LayoutSpark() end end)}
    main.preview={tip='Preview the spark',show=NS.PreviewEllesmereEnergyTick,duration=4,disabled=Off,disabledTooltip='Energy Tick Spark'}
    main.cog={title='Energy Tick Spark',disabled=Off,disabledTooltip='Energy Tick Spark',rows={
        {type='slider',label='Spark Width',min=1,max=6,step=1,get=function() return S().width end,set=function(v) Set('width',v) end},
        {type='slider',label='Spark Opacity %',min=10,max=100,step=5,get=function() return math.floor(S().opacity*100+.5) end,
            set=function(v) if Number(v) then Set('opacity',v/100) end end},
        {type='slider',label='Tick Bar Width',min=40,max=300,step=1,get=function() return S().barWidth end,set=function(v) Set('barWidth',v) end},
        {type='slider',label='Tick Bar Height',min=2,max=20,step=1,get=function() return S().barHeight end,set=function(v) Set('barHeight',v) end}}}
    Row(main,{type='dropdown',text='Energy Tick Placement',values={power='On The Power Bar',standalone='Own Tick Bar'},order={'power','standalone'},
        disabled=Off,disabledTooltip='Energy Tick Spark',
        tooltip='On The Power Bar draws over Ellesmere\'s power bar (its own tick bar when that bar is off). Own Tick Bar moves in Unlock Mode: Energy Tick.',
        getValue=function() return S().place end,setValue=function(v) Set('place',v) end})
    Row({type='button',text='Reset Energy Tick',onClick=function() ResetKeys('energyTick',{enabled=true});if spark then LayoutSpark() end;Sync() end},
        {type='label',text='Ticks are learned from your energy; probe in game first'})
end

-- Warnings > CLASS CUES (rogue, druid, warrior).
function NS.AddEllesmereClassCueOptions(Row)
    local class=Class()
    if not CLASS.cues[class] then return end
    local rogue,druid,warrior=class=='ROGUE',class=='DRUID',class=='WARRIOR'
    if EUI.IsSearchPrebuild and EUI.IsSearchPrebuild() then
        if rogue then Row({type='label',text='Stealth First Cue'},{type='label',text='Must Be Behind Cue'})
            Row({type='label',text='Stealth Opener Cue'},{type='label',text='Riposte Glow'})
            Row({type='label',text='Slice And Dice Cue'},{type='label',text='Cue Hold (sec)'})
        elseif druid then Row({type='label',text='Prowl First Cue'},{type='label',text='Leave Form Cue'})
            Row({type='label',text='Must Be Behind Cue'},{type='label',text='Prowl Opener Cue'})
        else Row({type='label',text='Wrong Stance Cue'},{type='label',text='Reactive Ability Glow'})
            Row({type='label',text='Stance Mismatch Hint'},{type='label',text='Cue Hold (sec)'}) end
        return
    end
    local function S() return NS.EllesmereClassCueSettings() end
    local Set=Setter('classCues')
    local function Toggle(text,k,tooltip,disabled,disabledTooltip)
        return {type='toggle',text=text,tooltip=tooltip,disabled=disabled,disabledTooltip=disabledTooltip,
            getValue=function() return S()[k] end,setValue=function(v) Set(k,v) end}
    end
    local function NoState()
        local s=S()
        if warrior then return not s.stance end
        return not (s.stealth or s.behindError or druid and s.form)
    end
    local stealthText=druid and 'Prowl First Cue' or 'Stealth First Cue'
    local stateCue=warrior and Toggle('Wrong Stance Cue','stance','When an ability fails because of your stance, the lane names the stance it needs (for example BATTLE STANCE).')
        or Toggle(stealthText,'stealth','When an ability fails because it needs '..(druid and 'Prowl' or 'Stealth')..', the warning lane says '..(druid and 'PROWL FIRST' or 'STEALTH FIRST')..'.')
    stateCue.swatches={Swatch('classCues','cue','State Cue Color')}
    stateCue.preview={tip='Preview the class cues',show=NS.PreviewEllesmereClassCues,duration=3}
    local behindCue=Toggle('Must Be Behind Cue','behindError','When an ability fails because you are not behind your target, the lane says GET BEHIND (the Behind Indicator also turns In Front).')
    if rogue then
        Row(stateCue,behindCue)
        local opener=Toggle('Stealth Opener Cue','opener','While stealthed with a hostile target in melee or within 10 yards: Ambush with a dagger in your main hand, else your chosen opener. In front of the target, behind-only openers are skipped.')
        opener.swatches={Swatch('classCues','opener','Opener Color')}
        opener.cog={title='Stealth Opener',disabled=function() return not S().opener end,disabledTooltip='Stealth Opener Cue',rows={
            {type='dropdown',label='Opener Without A Dagger',values={garrote=SpellName(SPELL.garrote) or 'Garrote',cheap=SpellName(SPELL.cheap) or 'Cheap Shot'},order={'garrote','cheap'},
                get=function() return S().openerRogue end,set=function(v) Set('openerRogue',v) end}}}
        local riposte=Toggle('Riposte Glow','reactive','While Riposte can be cast (after a parry), its action buttons glow like a proc, using your Action Bars Proc Glow style and color.')
        Row(opener,riposte)
        local sndRow=Toggle('Slice And Dice Cue','snd','In combat with a target and enough combo points: Slice and Dice missing, or about to run out. Quiet on a target under 35% health.')
        sndRow.swatches={Swatch('classCues','snd','Slice And Dice Color')}
        sndRow.cog={title='Slice And Dice',disabled=function() return not S().snd end,disabledTooltip='Slice And Dice Cue',rows={
            {type='slider',label='Expiring At (sec)',min=1,max=10,step=1,get=function() return S().sndWarn end,set=function(v) Set('sndWarn',v) end},
            {type='slider',label='Minimum Combo Points',min=1,max=5,step=1,get=function() return S().sndPoints end,set=function(v) Set('sndPoints',v) end}}}
        Row(sndRow,Blank())
    elseif druid then
        Row(stateCue,Toggle('Leave Form Cue','form','When something fails because you are shapeshifted, the lane says LEAVE FORM; when it needs a form, it names the form.'))
        local opener=Toggle('Prowl Opener Cue','opener','While in Prowl with a hostile target in melee or within 10 yards: Ravage or Pounce. In front of the target, Ravage (behind only) is skipped.')
        opener.swatches={Swatch('classCues','opener','Opener Color')}
        opener.cog={title='Prowl Opener',disabled=function() return not S().opener end,disabledTooltip='Prowl Opener Cue',rows={
            {type='dropdown',label='Preferred Opener',values={ravage=SpellName(SPELL.ravage) or 'Ravage',pounce=SpellName(SPELL.pounce) or 'Pounce'},order={'ravage','pounce'},
                get=function() return S().openerDruid end,set=function(v) Set('openerDruid',v) end}}}
        Row(behindCue,opener)
    else
        local reactive=Toggle('Reactive Ability Glow','reactive','While Overpower, Revenge, Execute or Victory Rush can be cast, its action buttons glow like a proc, using your Action Bars Proc Glow style and color.')
        local function Sub(label,k) return {type='toggle',label=label,get=function() return S()[k] end,set=function(v) Set(k,v) end} end
        reactive.cog={title='Reactive Ability Glow',disabled=function() return not S().reactive end,disabledTooltip='Reactive Ability Glow',rows={
            Sub(SpellName(SPELL.overpower) or 'Overpower','overpower'),Sub(SpellName(SPELL.revenge) or 'Revenge','revenge'),
            Sub(SpellName(SPELL.execute) or 'Execute','execute'),Sub(SpellName(SPELL.victoryRush) or 'Victory Rush','victoryRush')}}
        Row(stateCue,reactive)
        local hint=Toggle('Stance Mismatch Hint','stanceHint','After your target dodges (Overpower) or you dodge, parry or block (Revenge, only if you used Defensive Stance in the last 5 minutes), or on an Execute-range target: names the stance you need. Never asks you to leave Defensive Stance in a group or an instance.')
        hint.swatches={Swatch('classCues','stance','Stance Hint Color')}
        Row(hint,{type='label',text='Dodges come from the game\'s combat text events'})
    end
    Row({type='slider',text='Cue Hold (sec)',min=.5,max=5,step=.5,disabled=NoState,disabledTooltip=warrior and 'Wrong Stance Cue' or stealthText,
        tooltip='How long a state cue stays in the warning lane.',getValue=function() return S().hold end,setValue=function(v) Set('hold',v) end},
        {type='dropdown',text='State Cue Sound',values=SOUND_VALUES,order=SOUND_ORDER,disabled=NoState,disabledTooltip=warrior and 'Wrong Stance Cue' or stealthText,
        getValue=function() return S().sound end,
        setValue=function(v) Set('sound',v);if NS.PlayEllesmereCueSound then NS.PlayEllesmereCueSound(v,'classCuesStatePreview') end end})
    Row(Toggle('Above Character In Combat','aboveCharacter','State cues and the stance hint go above your character in combat, like other act-now warnings.'),
        {type='button',text='Reset Class Cue Colors',onClick=function() S().colors=nil end})
    Row({type='button',text='Reset Class Cues',onClick=function()
        local keep={}
        for k,v in pairs(SPEC.classCues.DEFAULTS) do if type(v)=='boolean' and v==false then keep[k]=true end end
        keep.aboveCharacter=nil
        ResetKeys('classCues',keep);Sync()
    end},{type='label',text='Reset keeps which cues are on'})
end

local boot=CreateFrame('Frame')
boot:RegisterEvent('PLAYER_LOGIN')
boot:SetScript('OnEvent',function(self) self:UnregisterAllEvents();Sync() end)
