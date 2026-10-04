-- Hunter warnings in the style of Ellesmere's Low Durability warning (same
-- font, size, pulse and position, stacked just below it): low/empty ammo and
-- unspent talent points, unsafe aspects and pet status. New reminders are opt-in.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end

local DEFAULTS={ammo=true,ammoLow=200,ammoCritical=50,talents=true,aspects=false,petHealth=false,petLow=40,petRange=false,petStatus=false,
    feed=false,feedContent=true,petFood=false,petFoodLow=10,dangerSound='none',warnSound='none',
    errorRaise=true,errorY=110,errorFilter=true,critical=true,criticalY=150,tranq=true}
local AMMO_WEAPONS={[2]=true,[3]=true,[18]=true} -- bows, guns, crossbows
local AMMO_SLOT,RANGED_SLOT=_G.INVSLOT_AMMO or 0,_G.INVSLOT_RANGED or 18
local C=NS.Colours or {}
local RED,AMBER=C.alert or {1,0.27,0.27},C.caution or {1,0.82,0}
local function Public(v) return not (issecretvalue and issecretvalue(v)) end
local function Number(v)
    return Public(v) and type(v)=='number' and v==v and v>-math.huge and v<math.huge
end
local function Read(fn,...)
    if type(fn)~='function' then return nil end
    local ok,a,b,c=pcall(fn,...)
    if ok and Public(a) and Public(b) and Public(c) then return a,b,c,true end
    return nil,nil,nil,false
end
local function Calm() return NS.EllesmereReduceMotion and NS.EllesmereReduceMotion() end
local function Hunter() return select(2,Read(UnitClass,'player'))=='HUNTER' end

-- Native durability uses direct SetFont calls and an anonymous UIParent child.
-- Discover its verified public frame shape on theme/settings/inventory events,
-- then hook only that label. No replacement warning or polling driver.
local nativeWarningText,nativeWarningHooks,driver
function NS.SyncEllesmereNativeWarningOutline()
    if not NS.ApplyEllesmereCueText or not hooksecurefunc then return end
    nativeWarningHooks=nativeWarningHooks or {}
    for _,key in ipairs({'_applyDurWarn','_durWarnApplySettings','_durWarnPreview'}) do
        if not nativeWarningHooks[key] and type(EUI[key])=='function' then
            hooksecurefunc(EUI,key,NS.SyncEllesmereNativeWarningOutline);nativeWarningHooks[key]=true
        end
    end
    if not nativeWarningText and NS.EllesmereVividTextEnabled and NS.EllesmereVividTextEnabled() and
        UIParent and UIParent.GetChildren then
        local found
        for _,frame in ipairs({UIParent:GetChildren()}) do
            if Public(frame) and frame._text and type(frame._applySettings)=='function' and
                type(frame._show)=='function' and frame._text.GetFont then
                if found then return end -- ambiguous native surface: leave it alone
                found=frame._text
            end
        end
        if found then
            nativeWarningText=found
            hooksecurefunc(found,'SetFont',function(fs) NS.ApplyEllesmereCueText(fs,'world',true) end)
        end
    end
    if driver then
        local wait=not nativeWarningText and NS.EllesmereVividTextEnabled and NS.EllesmereVividTextEnabled() and
            (not EllesmereUIDB or EllesmereUIDB.repairWarning~=false)
        for _,event in ipairs({'UPDATE_INVENTORY_DURABILITY','UPDATE_INVENTORY_ALERTS'}) do
            if wait then driver:RegisterEvent(event) else driver:UnregisterEvent(event) end
        end
    end
    if nativeWarningText then NS.ApplyEllesmereCueText(nativeWarningText,'world') end
    if NS.SyncEllesmereErrorText then NS.SyncEllesmereErrorText() end
end

-- Blizzard's error line ("Out of range.", "You have no target.") sat over the
-- middle of the screen, among nameplates (player: "should move upwards and be
-- large"). It moves to the top of the screen, below the guide arrow, in the
-- warning font at 80 % of the warning size, with the world outline. Off restores
-- its native anchors, font and width. Blizzard re-anchors are followed back.
local errorBase,errorPlacing
-- One alert lane at the top of the screen (player: "where the Blizzard error text
-- is, is where our cues should be"): the error line first, our warnings beneath.
local function ErrorSize()
    local db=EllesmereUIDB
    return math.floor(((db and db.durWarnTextSize) or 30)*.8+.5)
end
local function ErrorTop()
    local s=NS.EllesmereWarningSettings()
    return Number(s.errorY) and s.errorY or 110
end
function NS.EllesmereWarningLaneTop()
    if NS.EllesmereWarningSettings().errorRaise==false then return end
    return ErrorTop()+ErrorSize()+8
end
function NS.SyncEllesmereErrorText()
    local f=UIErrorsFrame
    if not f or not f.GetFont or not f.SetPoint or not f.GetNumPoints then return end
    local s=NS.EllesmereWarningSettings()
    if not errorBase then
        local path,size,flags=f:GetFont()
        local width,height=f:GetWidth(),f:GetHeight()
        if not Public(path) or type(path)~='string' or not Number(size) or not Public(flags) or
            not Number(width) or not Number(height) then return end
        errorBase={font={path,size,flags or ''},width=width,height=height,points={}}
        for i=1,f:GetNumPoints() do errorBase.points[i]={f:GetPoint(i)} end
        if hooksecurefunc then hooksecurefunc(f,'SetPoint',function()
            if not errorPlacing and NS.EllesmereWarningSettings().errorRaise~=false then NS.SyncEllesmereErrorText() end
        end) end
    end
    errorPlacing=true
    f:ClearAllPoints()
    if s.errorRaise~=false then
        -- One line tall: the newest error replaces the last instead of stacking
        -- down into the warnings beneath it.
        local size=ErrorSize()
        f:SetPoint('TOP',UIParent,'TOP',0,-ErrorTop())
        f:SetWidth(math.max(errorBase.width,900));f:SetHeight(size+8)
        f:SetFont(EUI.GetFontPath and EUI.GetFontPath('extras') or errorBase.font[1],size,errorBase.font[3])
    else
        for _,p in ipairs(errorBase.points) do f:SetPoint(unpack(p)) end
        f:SetWidth(errorBase.width);f:SetHeight(errorBase.height)
        f:SetFont(errorBase.font[1],errorBase.font[2],errorBase.font[3])
    end
    errorPlacing=nil
    if NS.ApplyEllesmereCueText then NS.ApplyEllesmereCueText(f,'world',true) end
    if NS.LayoutEllesmereWarnings then NS.LayoutEllesmereWarnings() end
end

-- Spam errors (player audit: "Spell is not ready yet" was the loudest thing on
-- screen). Retail Blizzard hides these through its own message-type list and
-- Forever empties that list; this uses the same native switch, which also
-- silences their voice lines. Errors that need action stay red. Off restores
-- each type's exact previous state.
local SPAM_ERRORS={'LE_GAME_ERR_SPELL_COOLDOWN','LE_GAME_ERR_ABILITY_COOLDOWN','LE_GAME_ERR_OUT_OF_RANGE',
    'LE_GAME_ERR_SPELL_OUT_OF_RANGE','LE_GAME_ERR_OUT_OF_MANA','LE_GAME_ERR_OUT_OF_FOCUS',
    'LE_GAME_ERR_OUT_OF_ENERGY','LE_GAME_ERR_OUT_OF_RAGE'}
local errorFilterBefore
function NS.SyncEllesmereErrorFilter()
    local f,list=UIErrorsFrame,_G.BLACK_LISTED_MESSAGE_TYPES
    if not f or type(f.SetMessageTypeEnabled)~='function' or type(list)~='table' then return end
    local on=NS.EllesmereWarningSettings().errorFilter~=false
    if on and not errorFilterBefore then
        errorFilterBefore={}
        for _,name in ipairs(SPAM_ERRORS) do
            local id=_G[name]
            if Number(id) then errorFilterBefore[id]=list[id]==true;f:SetMessageTypeEnabled(id,false) end
        end
    elseif not on and errorFilterBefore then
        for id,hidden in pairs(errorFilterBefore) do f:SetMessageTypeEnabled(id,not hidden) end
        errorFilterBefore=nil
    end
end

-- Errors a cue already shows (plan §1.K: one problem shows once). The client gives
-- each error a message type; the first time a matching error arrives (matched by the
-- client's own global string) its type is learned and switched off with the same
-- native switch as the spam filter. A learned type that later carries a different
-- message is shared by other errors: it goes back on for good and that message shows.
local function RangeCue(key)
    local r=NS.EllesmereIndicatorSettings and NS.EllesmereIndicatorSettings('range')
    return not r or r.enabled~=false and (not key or r[key]~=false)
end
local ROUTES={
    {keys={'SPELL_FAILED_TOO_CLOSE'},on=function() return RangeCue() end},
    {keys={'ERR_BADATTACKFACING','SPELL_FAILED_UNIT_NOT_INFRONT','SPELL_FAILED_NOT_INFRONT'},on=function() return RangeCue('facingWarning') end},
    {keys={'SPELL_FAILED_NO_AMMO','SPELL_FAILED_NEED_AMMO','SPELL_FAILED_NEED_AMMO_POUCH'},on=function(s) return s.ammo end},
    {keys={'PET_SPELL_DEAD','SPELL_FAILED_NO_PET'},on=function(s) return s.petStatus end},
}
local routed,shared={},{}
local routeFrame
local function RouteFor(message)
    for i,route in ipairs(ROUTES) do
        for _,key in ipairs(route.keys) do
            local text=_G[key]
            if type(text)=='string' and text==message then return i end
        end
    end
end
local function Release(id)
    local f=UIErrorsFrame
    if f and type(f.SetMessageTypeEnabled)=='function' then f:SetMessageTypeEnabled(id,true) end
    routed[id]=nil
end
function NS.EllesmereRouteError(id,message)
    if not Number(id) or not Public(message) or type(message)~='string' then return end
    local s=NS.EllesmereWarningSettings()
    local f,list=UIErrorsFrame,_G.BLACK_LISTED_MESSAGE_TYPES
    if not f or type(f.SetMessageTypeEnabled)~='function' then return end
    local route=RouteFor(message)
    if routed[id] then
        if route~=routed[id] then
            -- Shared type: never hide it again, and show what we just swallowed.
            Release(id);shared[id]=true
            if type(f.AddMessage)=='function' then f:AddMessage(message,1,.1,.1,1) end
        end
        return
    end
    if not route or shared[id] or not s.errorRoute or not ROUTES[route].on(s) then return end
    -- Types the player or the spam filter already hide are left alone.
    if type(list)=='table' and list[id]==true then return end
    routed[id]=route;f:SetMessageTypeEnabled(id,false)
end
function NS.SyncEllesmereErrorRoutes()
    local s=NS.EllesmereWarningSettings()
    for id,route in pairs(routed) do
        if not s.errorRoute or not ROUTES[route].on(s) then Release(id) end
    end
    if s.errorRoute and not routeFrame then
        routeFrame=CreateFrame('Frame')
        routeFrame:SetScript('OnEvent',function(_,_,id,message) NS.EllesmereRouteError(id,message) end)
    end
    if routeFrame then
        if s.errorRoute then routeFrame:RegisterEvent('UI_ERROR_MESSAGE') else routeFrame:UnregisterAllEvents() end
    end
end

function NS.EllesmereWarningSettings()
    FHKEllesmereDB=FHKEllesmereDB or {}
    local s=FHKEllesmereDB.warnings
    if type(s)~='table' then s={}; FHKEllesmereDB.warnings=s end
    for k,v in pairs(DEFAULTS) do if s[k]==nil then s[k]=v end end
    return s
end

-- One row per warning, built on first use.
local rows,order={}, {'tranq','aspects','ammo','petStatus','petHealth','petRange','feed','petFood','talents'}
local container,centre
-- In combat, warnings that need an action now sit above the character, inside
-- the eye's working field (audit); information and game errors stay at the top.
local function CentreLane()
    local s=NS.EllesmereWarningSettings()
    return s.critical~=false and InCombatLockdown()
end
local function CentreSize()
    local db=EllesmereUIDB
    return math.min((db and db.durWarnTextSize) or 30,22)
end
local function Anchor()
    container:ClearAllPoints()
    local lane=NS.EllesmereWarningLaneTop and NS.EllesmereWarningLaneTop()
    if lane then container:SetPoint('TOP',UIParent,'TOP',0,-lane);return end
    local db=EllesmereUIDB
    local pos=db and db.durWarnPos
    local size=(db and db.durWarnTextSize) or 30
    if pos and pos.point then
        container:SetPoint('TOP',UIParent,pos.relPoint or pos.point,pos.x or 0,(pos.y or 250)-size*0.75)
    else
        container:SetPoint('TOP',UIParent,'CENTER',0,((db and db.durWarnYOffset) or 250)-size*0.75)
    end
end
local function Row(key)
    if rows[key] then return rows[key] end
    if not container then
        container=CreateFrame('Frame',nil,UIParent)
        container:SetSize(500,1); container:SetFrameStrata('HIGH'); container:SetFrameLevel(50)
        container:EnableMouse(false)
    end
    local row=CreateFrame('Frame',nil,container)
    row:SetSize(500,40); row:EnableMouse(false)
    local fs=row:CreateFontString(nil,'OVERLAY'); fs:SetPoint('CENTER')
    row.text=fs
    -- One smooth pulse on arrival, then static; a smooth fade on the way out
    -- (player: "a smooth pulse then stay static and a smooth fadeout").
    -- Nothing loops: a warning that stays is a state, not news.
    local ag=fs:CreateAnimationGroup()
    local out=ag:CreateAnimation('Alpha'); out:SetFromAlpha(1); out:SetToAlpha(0.45); out:SetOrder(1); out:SetSmoothing('IN_OUT')
    local back=ag:CreateAnimation('Alpha'); back:SetFromAlpha(0.45); back:SetToAlpha(1); back:SetOrder(2); back:SetSmoothing('IN_OUT')
    row.pulse,row.pulseOut,row.pulseBack=ag,out,back
    -- House show fade: 0.25 s, easing out.
    local fade=row:CreateAnimationGroup(); local a=fade:CreateAnimation('Alpha')
    a:SetFromAlpha(0); a:SetToAlpha(1); a:SetDuration(0.25); a:SetSmoothing('OUT'); row.fade=fade
    local gone=row:CreateAnimationGroup(); local z=gone:CreateAnimation('Alpha')
    z:SetFromAlpha(1); z:SetToAlpha(0); z:SetDuration(0.3); z:SetSmoothing('IN_OUT'); row.fadeOut=gone
    gone:SetScript('OnFinished',function()
        if row.leaving then row.leaving=nil; row:Hide(); NS.LayoutEllesmereWarnings() end
    end)
    row:SetScript('OnHide',function() ag:Stop() end)
    row:Hide(); rows[key]=row
    return row
end
local function Layout()
    if not container then return end
    Anchor()
    if not centre then
        centre=CreateFrame('Frame',nil,UIParent)
        centre:SetSize(500,1);centre:SetFrameStrata('HIGH');centre:SetFrameLevel(50);centre:EnableMouse(false)
    end
    local s=NS.EllesmereWarningSettings()
    centre:ClearAllPoints();centre:SetPoint('BOTTOM',UIParent,'CENTER',0,Number(s.criticalY) and s.criticalY or 150)
    local inCentre=CentreLane()
    local y,cy,primary=0,0,nil
    for _,key in ipairs(order) do
        local row=rows[key]
        if row and row:IsShown() then
            row:ClearAllPoints()
            -- The centre lane grows upward from its anchor, away from the character.
            if inCentre and row.critical then row:SetPoint('BOTTOM',centre,'BOTTOM',0,cy);cy=cy+row:GetHeight()
            else row:SetPoint('TOP',container,'TOP',0,y);y=y-row:GetHeight() end
            if not row.leaving then
                row.primary=primary==nil
                primary=primary or row
            end
            if Calm() then row.pulse:Stop() end
        end
    end
end
NS.LayoutEllesmereWarnings=Layout
-- Per-cue sounds (plan 10.3 P3): one choice for act-now warnings, one for the rest, played
-- only when a warning arrives, at most every 3 s per warning. None by default.
local SOUNDS={raid=_G.SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959,alarm=_G.SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3 or 12889,
    ready=_G.SOUNDKIT and SOUNDKIT.READY_CHECK or 8960,tick=_G.SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856}
local soundAt={}
local function Sound(key,critical)
    local s=NS.EllesmereWarningSettings()
    local id=SOUNDS[critical and s.dangerSound or s.warnSound]
    if not id or type(PlaySound)~='function' then return end
    local now=GetTime and GetTime() or 0
    if soundAt[key] and now-soundAt[key]<3 then return end
    soundAt[key]=now
    pcall(PlaySound,id,'Master')
end
NS.EllesmereWarningSound=Sound
local function Show(key,text,colour,slow,critical)
    local row=Row(key)
    row.critical=critical==true
    local db=EllesmereUIDB
    local size=(row.critical and CentreLane()) and CentreSize() or (db and db.durWarnTextSize) or 30
    row.text:SetFont(EUI.GetFontPath and EUI.GetFontPath('extras') or EUI.EXPRESSWAY or 'Fonts\\FRIZQT__.TTF',size,
        EUI.GetFontOutlineFlag and EUI.GetFontOutlineFlag('extras') or 'OUTLINE')
    if NS.ApplyEllesmereCueText then NS.ApplyEllesmereCueText(row.text,'world',true) end
    row:SetHeight(size+10)
    row.text:SetText(text); row.text:SetTextColor(colour[1],colour[2],colour[3],1)
    local d=slow and 0.5 or 0.35
    row.pulseOut:SetDuration(d); row.pulseBack:SetDuration(d)
    -- A warning that returns while fading out simply stays.
    local arriving=not row:IsShown()
    if row.leaving then row.leaving=nil; row.fadeOut:Stop() end
    row:Show(); Layout()
    if arriving then row.fade:Play(); if not Calm() then row.pulse:Play() end; Sound(key,critical) end
end
local function Hide(key)
    local row=rows[key]
    if not row or not row:IsShown() or row.leaving then return end
    if Calm() then row:Hide(); Layout(); return end
    row.leaving=true; row.pulse:Stop(); row.fadeOut:Play(); Layout()
end
-- The same lane for other companion cues (HunterCues.lua): one look, one stack. Danger
-- keys go to the front; the rest sit before the talent reminder.
local FRONT={ccBreak=true,feignResist=true,feign=true}
function NS.ShowEllesmereWarning(key,text,colour,slow,critical)
    local listed=false
    for _,k in ipairs(order) do if k==key then listed=true;break end end
    if not listed then
        if FRONT[key] then table.insert(order,1,key) else table.insert(order,math.max(1,#order),key) end
    end
    Show(key,text,colour,slow,critical)
end
NS.HideEllesmereWarning=Hide

-------------------------------------------------------------------------------
-- Ammo
-------------------------------------------------------------------------------
local function UsesAmmo()
    -- Build 70170 added UnitUsesAmmo; prefer the client's answer, else infer from the weapon type.
    local uses=Read(_G.UnitUsesAmmo,'player')
    if type(uses)=='boolean' then return uses end
    local id=Read(GetInventoryItemID,'player',RANGED_SLOT)
    if not id then return false end
    local instant=C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if type(instant)~='function' then return false end
    local ok,_,_,_,_,_,classID,subclassID=pcall(instant,id)
    if not ok or not Public(classID) or not Public(subclassID) then return false end
    return classID==2 and AMMO_WEAPONS[subclassID]==true
end
-- Ammo that fits the ranged weapon: bows and crossbows take arrows (2), guns take bullets (3).
local AMMO_FOR,AMMO_NAME={[2]=2,[18]=2,[3]=3},{[2]='Arrows',[3]='Bullets'}
local function Instant(id)
    local instant=C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if not id or type(instant)~='function' then return end
    local ok,_,_,_,_,_,classID,subclassID=pcall(instant,id)
    if ok and Public(classID) and Public(subclassID) then return classID,subclassID end
end
local function WantedAmmo()
    local classID,subclassID=Instant(Read(GetInventoryItemID,'player',RANGED_SLOT))
    return classID==2 and AMMO_FOR[subclassID] or nil
end
-- Only scanned when the slot is empty or wrong, so it costs nothing while you shoot.
local function FitsInBags(want)
    local C=C_Container
    if not (C and C.GetContainerNumSlots and C.GetContainerItemID) then return false end
    for bag=0,(_G.NUM_BAG_SLOTS or 4) do
        local slots=Read(C.GetContainerNumSlots,bag)
        for slot=1,Number(slots) and slots or 0 do
            local classID,subclassID=Instant(Read(C.GetContainerItemID,bag,slot))
            if classID==6 and subclassID==want then return true end
        end
    end
    return false
end
NS.EllesmereAmmoName=function(want) return AMMO_NAME[want] or 'Ammo' end
function NS.EllesmereAmmoState()
    if not UsesAmmo() then return nil end
    local ok,id=pcall(GetInventoryItemID,'player',AMMO_SLOT)
    if not ok or not Public(id) then return nil end
    -- Wrong type (arrows with a gun) or an empty slot with fitting ammo in the bags: say which.
    local want=WantedAmmo()
    if want then
        local classID,subclassID=Instant(id)
        if id and classID==6 and subclassID~=want then return 'wrong',0,want,FitsInBags(want) end
        if not id and FitsInBags(want) then return 'empty',0,want,true end
    end
    local count=0
    if id then count=Read(GetInventoryItemCount,'player',AMMO_SLOT) end
    if not Number(count) then return nil end
    local s=NS.EllesmereWarningSettings()
    if count<=(Number(s.ammoCritical) and s.ammoCritical or 50) then return 'critical',count end
    if count<(Number(s.ammoLow) and s.ammoLow or 200) then return 'low',count end
    return 'ok',count
end
local function CheckAmmo()
    local s=NS.EllesmereWarningSettings()
    local state,count,want,inBags=nil,0
    if s.ammo then state,count,want,inBags=NS.EllesmereAmmoState() end
    local name=NS.EllesmereAmmoName(want)
    if state=='wrong' then
        Show('ammo',inBags and ('Wrong Ammo - Equip ' .. name) or ('Wrong Ammo - No ' .. name .. ' in Bags'),RED,nil,true)
    elseif state=='empty' then
        Show('ammo','Ammo Slot Empty - Equip ' .. name,RED,nil,true)
    elseif state=='critical' then
        Show('ammo',count==0 and 'Out of Ammo' or ('Ammo Critical (' .. count .. ')'),RED,nil,true)
    elseif state=='low' and not InCombatLockdown() then
        Show('ammo','Low Ammo (' .. count .. ')',AMBER)
    else Hide('ammo') end
end

-------------------------------------------------------------------------------
-- Unspent talent points (whichever talent API this client provides)
-------------------------------------------------------------------------------
function NS.EllesmereUnspentTalentPoints()
    local best=0
    local function Take(fn,...)
        if type(fn)~='function' then return end
        local ok,a,b,c=pcall(fn,...)
        if not ok or not Public(a) or not Public(b) or not Public(c) then return end
        local n=Number(a) and a or ((Number(b) and b or 0)+(Number(c) and c or 0))
        if a==false then n=0 end
        if n>best then best=n end
    end
    Take(_G.UnitCharacterPoints,'player')
    Take(_G.GetUnspentTalentPoints)
    Take(C_ClassTalents and C_ClassTalents.HasUnspentTalentPoints)
    return best
end
local function CheckTalents()
    local n=NS.EllesmereWarningSettings().talents and not InCombatLockdown() and NS.EllesmereUnspentTalentPoints() or 0
    if n>0 then
        local c=EUI.GetAccentColor and {EUI.GetAccentColor()} or AMBER
        Show('talents',n==1 and 'Unspent Talent Point' or ('Unspent Talent Points (' .. n .. ')'),c,true)
    else Hide('talents') end
end

-------------------------------------------------------------------------------
-- Aspects and pets: never infer a warning from restricted or missing reads.
-------------------------------------------------------------------------------
local function PlayerAura(id)
    local aura=Read(C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID,id)
    return type(aura)=='table'
end
local function CheckAspects()
    local s=NS.EllesmereWarningSettings()
    if NS.AspectAdvisor and NS.AspectAdvisor.Enabled() then Hide('aspects');return end
    if not s.aspects or not Hunter() or not InCombatLockdown() then Hide('aspects');return end
    if PlayerAura(13159) then Show('aspects','Aspect of the Pack - Combat',RED,nil,true)
    elseif PlayerAura(5118) then Show('aspects','Aspect of the Cheetah - Combat',RED,nil,true)
    else Hide('aspects') end
end
local function PetAlive()
    return Read(UnitExists,'pet')==true and Read(UnitIsDeadOrGhost,'pet')==false
end
-- No / Low Pet Food (plan 10.3 item 5): out of combat, from PetFood.lua's cached edible count.
local function CheckPetFood()
    local s=NS.EllesmereWarningSettings()
    if s.petFood~=true or not Hunter() or Read(InCombatLockdown)~=false or not PetAlive() or not NS.EllesmerePetFoodCount then Hide('petFood');return end
    if NS.HunterTalents and Read(NS.HunterTalents.Has,'loneWolf')==true then Hide('petFood');return end
    if Read(C_SpellBook and C_SpellBook.IsSpellKnown,6991)~=true and Read(_G.IsPlayerSpell,6991)~=true then Hide('petFood');return end
    local count=NS.EllesmerePetFoodCount()
    if count==0 then Show('petFood','No Pet Food',AMBER)
    elseif Number(s.petFoodLow) and count<s.petFoodLow then Show('petFood','Low Pet Food ('..count..')',AMBER)
    else Hide('petFood') end
end
NS.CheckEllesmerePetFood=CheckPetFood
local feedDriver,feedQueued,feedEpoch=nil,false,0
local function CheckPetFeed()
    local s=NS.EllesmereWarningSettings()
    if s.feed~=true or not Hunter() or Read(InCombatLockdown)~=false or not PetAlive() or
        Read(UnitIsDeadOrGhost,'player')~=false or Read(IsMounted)~=false or Read(UnitOnTaxi,'player')~=false or
        Read(UnitHasVehicleUI,'player')~=false then Hide('feed');return end
    if NS.HunterTalents and Read(NS.HunterTalents.Has,'loneWolf')==true then Hide('feed');return end
    if Read(C_SpellBook and C_SpellBook.IsSpellKnown,6991)~=true and Read(_G.IsPlayerSpell,6991)~=true then Hide('feed');return end
    local mood=Read(C_PetInfo and C_PetInfo.GetPetHappiness)
    if Number(mood) and mood==1 then Show('feed','Feed Pet (Unhappy)',RED,true)
    elseif Number(mood) and mood==2 and s.feedContent==true then Show('feed','Feed Pet (Content)',AMBER,true)
    else Hide('feed') end
end
local function SyncPetFeed()
    feedEpoch=feedEpoch+1;feedQueued=false
    if feedDriver then feedDriver:UnregisterAllEvents() end
    local on=NS.EllesmereWarningSettings().feed==true and Hunter()
    if on then
        if not feedDriver then
            feedDriver=CreateFrame('Frame')
            feedDriver:SetScript('OnEvent',function(_,_,unit)
                if not Public(unit) or unit and unit~='player' and unit~='pet' or feedQueued then return end
                feedQueued=true;local token=feedEpoch
                local function Refresh() if token==feedEpoch then feedQueued=false;CheckPetFeed() end end
                if C_Timer and C_Timer.After then C_Timer.After(0,Refresh) else Refresh() end
            end)
        end
        for _,event in ipairs({'UNIT_HAPPINESS','UNIT_FLAGS'}) do feedDriver:RegisterUnitEvent(event,'pet','player') end
        feedDriver:RegisterUnitEvent('UNIT_PET','player')
        for _,event in ipairs({'PLAYER_ENTERING_WORLD','PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED','SPELLS_CHANGED',
            'PLAYER_MOUNT_DISPLAY_CHANGED','PLAYER_CONTROL_GAINED','PLAYER_CONTROL_LOST'}) do
            if not C_EventUtils or Read(C_EventUtils.IsEventValid,event)==true then feedDriver:RegisterEvent(event) end
        end
    end
    CheckPetFeed()
end
local function MendName()
    local name=Read(C_Spell and C_Spell.GetSpellName,136)
    if type(name)=='string' then return name end
    local info=Read(C_Spell and C_Spell.GetSpellInfo,136)
    if type(info)=='table' and Public(info.name) and type(info.name)=='string' then return info.name end
end
local function MendRange()
    local name=MendName()
    return Read(C_Spell and C_Spell.IsSpellInRange,name or 136,'pet')
end
local function MendKnown()
    local fn=C_SpellBook and C_SpellBook.IsSpellKnown
    return not fn or Read(fn,136)==true
end
local function CheckPetHealth()
    local s=NS.EllesmereWarningSettings()
    if not s.petHealth or not Hunter() or not PetAlive() or not MendKnown() then Hide('petHealth');return end
    local hp,max=Read(UnitHealth,'pet'),Read(UnitHealthMax,'pet')
    if not Number(hp) or not Number(max) or max<=0 or hp<=0 then Hide('petHealth');return end
    local threshold=Number(s.petLow) and math.max(5,math.min(90,s.petLow)) or 40
    if hp/max*100>threshold then Hide('petHealth');return end
    local name=MendName()
    if not name then Hide('petHealth');return end
    local aura,_,_,known=Read(C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName,'pet',name,'HELPFUL')
    if not known or type(aura)=='table' or MendRange()==false then Hide('petHealth');return end
    Show('petHealth','Mend Pet (' .. math.floor(hp/max*100+.5) .. '%)',AMBER,true,true)
end
-- Distance alone is normal for a hunter shooting while the pet tanks (player:
-- "no idea what that's for"). It warns only when it matters: the pet is below
-- the Mend Pet threshold and out of Mend range, and says what to do.
local function CheckPetRange()
    local s=NS.EllesmereWarningSettings()
    if not s.petRange or not Hunter() or not PetAlive() or not MendKnown() or MendRange()~=false then
        Hide('petRange');return
    end
    local hp,max=Read(UnitHealth,'pet'),Read(UnitHealthMax,'pet')
    local threshold=Number(s.petLow) and math.max(5,math.min(90,s.petLow)) or 40
    if Number(hp) and Number(max) and max>0 and hp>0 and hp/max*100<=threshold then
        Show('petRange','Move Closer To Mend Pet',AMBER,true,true)
    else Hide('petRange') end
end
local function CheckPetStatus()
    local s=NS.EllesmereWarningSettings()
    if not s.petStatus or not Hunter() or not InCombatLockdown() or Read(UnitIsDeadOrGhost,'player')~=false or
        Read(IsMounted)==true or Read(UnitOnTaxi,'player')==true or Read(UnitHasVehicleUI,'player')==true then
        Hide('petStatus');return
    end
    local known=Read(C_SpellBook and C_SpellBook.IsSpellKnown,883)
    if known~=true then Hide('petStatus');return end
    -- Lone Wolf (Forever talent) plays without a pet on purpose.
    if NS.HunterTalents and NS.HunterTalents.Has('loneWolf') then Hide('petStatus');return end
    local exists=Read(UnitExists,'pet')
    if exists==true and Read(UnitIsDeadOrGhost,'pet')==true then
        Show('petStatus','Revive Pet',RED,true,true)
    elseif exists==false then
        -- An absent unit cannot distinguish a dismissed pet from a dead one.
        Show('petStatus','Call / Revive Pet',AMBER,true,true)
    else Hide('petStatus') end
end

-- Frenzy on an enemy target is a Tranquilizing Shot call (Magmadar, Flamegor,
-- Chromaggus, Huhuran, Gluth). Quiet until the spell is known; restricted aura
-- reads never produce a warning.
local function FrenzyAura(aura)
    if type(aura)~='table' then return false end
    local name,dispel=aura.name,aura.dispelName
    return (Public(name) and name=='Frenzy') or (Public(dispel) and dispel=='Enrage')
end
local function CheckFrenzy()
    local s=NS.EllesmereWarningSettings()
    if not s.tranq or not Hunter() or not InCombatLockdown() or
        Read(C_SpellBook and C_SpellBook.IsSpellKnown,19801)~=true or Read(UnitCanAttack,'player','target')~=true then
        Hide('tranq');return
    end
    local byIndex=C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    for i=1,40 do
        local aura,_,_,ok=Read(byIndex,'target',i,'HELPFUL')
        if not ok or type(aura)~='table' then break end
        if FrenzyAura(aura) then Show('tranq','Tranquilizing Shot - Frenzy',RED,nil,true);return end
    end
    Hide('tranq')
end

-------------------------------------------------------------------------------
-- Events (registered only while a warning is on)
-------------------------------------------------------------------------------
driver=CreateFrame('Frame')
-- Range changes have no dedicated event for an arbitrary pet spell target.
-- The engine timer runs only while this reminder has a living pet to check.
local rangeHost=CreateFrame('Frame')
local lastPetRange
local petTicker=EUI.Tick and EUI.Tick.NewAnimTicker and EUI.Tick.NewAnimTicker(rangeHost,function()
    local s=NS.EllesmereWarningSettings()
    if not (s.petRange or s.petHealth) or not Hunter() or not PetAlive() or not MendKnown() then Hide('petRange');return false end
    local range=MendRange()
    if range~=lastPetRange then lastPetRange=range;CheckPetRange();CheckPetHealth() end
    return true
end,.25)
local pendingCheck=false
local function Flush()
    NS.SyncEllesmereNativeWarningOutline()
    pendingCheck=false;if NS.PetFood then NS.PetFood.Invalidate() end;CheckPetFood();CheckAmmo();CheckTalents();CheckAspects();CheckPetStatus();CheckPetHealth();CheckPetRange();CheckFrenzy()
    if petTicker then
        local s=NS.EllesmereWarningSettings()
        if (s.petRange or s.petHealth) and Hunter() and PetAlive() and MendKnown() then petTicker.Start()
        else petTicker.Stop();lastPetRange=nil end
    end
end
driver:SetScript('OnEvent',function(_,event,unit)
    if not Public(unit) then return end
    if event=='UNIT_INVENTORY_CHANGED' and unit~='player' then return end
    if event:find('^UNIT_') and unit and unit~='player' and unit~='pet' and unit~='target' then return end
    if pendingCheck then return end
    pendingCheck=true
    C_Timer.After(0,Flush)
end)
-- Talent-gated warnings re-check once the shared talent ranks settle.
if NS.HunterTalents then
    NS.HunterTalents.OnChange(function()
        CheckPetFeed()
        if pendingCheck then return end
        pendingCheck=true
        C_Timer.After(0,Flush)
    end)
end
local AMMO_EVENTS={'PLAYER_ENTERING_WORLD','PLAYER_EQUIPMENT_CHANGED','UNIT_INVENTORY_CHANGED','BAG_UPDATE_DELAYED',
    'PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED'}
local TALENT_EVENTS={'PLAYER_ENTERING_WORLD','PLAYER_LEVEL_UP','CHARACTER_POINTS_CHANGED','PLAYER_TALENT_UPDATE',
    'TRAIT_CONFIG_UPDATED','PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED'}
local ASPECT_EVENTS={'PLAYER_ENTERING_WORLD','UNIT_AURA','PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED'}
local PET_EVENTS={'PLAYER_ENTERING_WORLD','UNIT_PET','UNIT_HEALTH','UNIT_MAXHEALTH','UNIT_FLAGS','UNIT_AURA',
    'UNIT_IN_RANGE_UPDATE','UNIT_DISTANCE_CHECK_UPDATE','SPELLS_CHANGED','PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED',
    'PLAYER_MOUNT_DISPLAY_CHANGED','PLAYER_CONTROL_GAINED','PLAYER_CONTROL_LOST','PET_BAR_UPDATE'}
local FOOD_EVENTS={'PLAYER_ENTERING_WORLD','BAG_UPDATE_DELAYED','UNIT_PET','PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED'}
local TRANQ_EVENTS={'PLAYER_TARGET_CHANGED','UNIT_AURA','SPELLS_CHANGED','PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED'}
local function Valid(event)
    return not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(event)
end
function NS.SyncEllesmereWarnings()
    local s=NS.EllesmereWarningSettings()
    driver:UnregisterAllEvents()
    for _,list in ipairs({s.ammo and AMMO_EVENTS or {},s.talents and TALENT_EVENTS or {},
        s.aspects and Hunter() and not (NS.AspectAdvisor and NS.AspectAdvisor.Enabled()) and ASPECT_EVENTS or {},(s.petHealth or s.petRange or s.petStatus) and Hunter() and PET_EVENTS or {},
        s.tranq and Hunter() and TRANQ_EVENTS or {},s.petFood and Hunter() and FOOD_EVENTS or {},
        -- The centre lane follows combat even when only one warning is on.
        s.critical~=false and {'PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED'} or {}}) do
        for _,event in ipairs(list) do if Valid(event) then driver:RegisterEvent(event) end end
    end
    SyncPetFeed()
    NS.SyncEllesmereErrorRoutes() -- a route follows its cue's toggle
    if NS.EllesmereVividTextEnabled and NS.EllesmereVividTextEnabled() and not nativeWarningText and
        (not EllesmereUIDB or EllesmereUIDB.repairWarning~=false) then
        driver:RegisterEvent('UPDATE_INVENTORY_DURABILITY');driver:RegisterEvent('UPDATE_INVENTORY_ALERTS')
    end
    Flush()
end
function NS.PreviewEllesmereWarnings()
    Show('ammo','Low Ammo (Preview)',AMBER)
    Show('talents','Unspent Talent Points (Preview)',EUI.GetAccentColor and {EUI.GetAccentColor()} or AMBER,true)
    local s=NS.EllesmereWarningSettings()
    if s.aspects and not (NS.AspectAdvisor and NS.AspectAdvisor.Enabled()) then Show('aspects','Aspect of the Cheetah - Combat (Preview)',RED) end
    if s.petHealth then Show('petHealth','Mend Pet (Preview)',AMBER,true) end
    if s.petRange then Show('petRange','Move Closer To Mend Pet (Preview)',AMBER,true) end
    if s.feed==true then Show('feed','Feed Pet (Preview)',AMBER,true) end
    if s.petFood==true then Show('petFood','Low Pet Food (Preview)',AMBER) end
    if s.petStatus then Show('petStatus','Call / Revive Pet (Preview)',AMBER,true) end
    C_Timer.After(4,Flush)
end
-- Keeps critical below low (audit F11): moving one past the other drags the other along.
function NS.SetEllesmereAmmoThreshold(key,v)
    local s=NS.EllesmereWarningSettings()
    s[key]=v
    local moved
    if key=='ammoLow' and s.ammoCritical>=v then s.ammoCritical=math.max(0,v-50);moved='Critical Ammo At' end
    if key=='ammoCritical' and s.ammoLow<=v then s.ammoLow=math.min(1000,v+50);moved='Low Ammo Below' end
    if moved then
        print(('FHK: %s moved to %d so critical stays below low.'):format(moved,key=='ammoLow' and s.ammoCritical or s.ammoLow))
        if EUI.RefreshPage then EUI:RefreshPage() end
    end
    Flush()
    return moved
end
function NS.AddEllesmereWarningOptions(Row)
    local s=NS.EllesmereWarningSettings()
    Row({type='toggle',text='Low Ammo Warning',tooltip='Warns below the low threshold out of combat, and always when nearly out, the ammo slot is empty or the ammo does not fit your weapon.',
        getValue=function() return s.ammo end,setValue=function(v) s.ammo=v; NS.SyncEllesmereWarnings() end},
        {type='toggle',text='Unspent Talent Warning',tooltip='Shows out of combat while you have talent points to spend.',
        getValue=function() return s.talents end,setValue=function(v) s.talents=v; NS.SyncEllesmereWarnings() end})
    Row({type='slider',text='Low Ammo Below',min=50,max=1000,step=50,
        getValue=function() return s.ammoLow end,setValue=function(v) NS.SetEllesmereAmmoThreshold('ammoLow',v) end},
        {type='slider',text='Critical Ammo At',min=0,max=200,step=10,
        getValue=function() return s.ammoCritical end,setValue=function(v) NS.SetEllesmereAmmoThreshold('ammoCritical',v) end})
    Row({type='toggle',text='Cheetah / Pack Combat Warning',tooltip='Warns while either movement aspect is active in combat. When Aspect Element is enabled, its red edge shows this warning instead.',
        getValue=function() return s.aspects end,setValue=function(v) s.aspects=v;NS.SyncEllesmereWarnings() end},
        {type='toggle',text='Mend Pet Reminder',tooltip='Warns below the pet health threshold; hides while Mend Pet is already active or the pet is out of range.',
        getValue=function() return s.petHealth end,setValue=function(v) s.petHealth=v;NS.SyncEllesmereWarnings() end})
    Row({type='toggle',text='Pet Too Far To Mend',tooltip='Warns only when your pet is below the Mend Pet health threshold and out of Mend Pet range. Distance alone stays quiet.',
        getValue=function() return s.petRange end,setValue=function(v) s.petRange=v;NS.SyncEllesmereWarnings() end},
        {type='slider',text='Mend Pet At Health %',min=5,max=90,step=5,
        getValue=function() return s.petLow end,setValue=function(v) s.petLow=v;Flush() end})
    Row({type='toggle',text='Missing / Dead Pet In Combat',tooltip='Shows Call / Revive Pet when absent and Revive Pet when death is confirmed. Quiet while you are dead, mounted, on a taxi or in a vehicle.',
        getValue=function() return s.petStatus end,setValue=function(v) s.petStatus=v;NS.SyncEllesmereWarnings() end},
        {type='label',text='Pet health and happiness use separate colors'})
    Row({type='toggle',text='Feed Pet Reminder',tooltip='Out of combat: amber for a content pet and red for an unhappy pet. Quiet for Lone Wolf, missing/dead pets, travel, and unreadable happiness.',
        getValue=function() return s.feed==true end,setValue=function(v) s.feed=v;NS.SyncEllesmereWarnings() end},
        {type='toggle',text='Remind When Content',getValue=function() return s.feedContent==true end,setValue=function(v) s.feedContent=v;NS.SyncEllesmereWarnings() end,
        disabled=function() return s.feed~=true end,disabledTooltip='Feed Pet Reminder'})
    Row({type='toggle',text='Pet Food Warning',tooltip='Out of combat: No Pet Food when nothing in your bags is food your pet eats, Low Pet Food below the amount you set.',
        getValue=function() return s.petFood==true end,setValue=function(v) s.petFood=v;NS.SyncEllesmereWarnings() end},
        {type='slider',text='Low Pet Food Below',min=0,max=60,step=5,
        disabled=function() return s.petFood~=true end,disabledTooltip='Pet Food Warning',
        getValue=function() return s.petFoodLow end,setValue=function(v) s.petFoodLow=v;Flush() end})
    Row({type='toggle',text='Top Alert Lane',tooltip='Moves the red game error line (Out of range, No target) to the top of the screen, large, in the warning font, with these warnings directly beneath it. Off restores the native error line and puts warnings back under Low Durability.',
        getValue=function() return s.errorRaise end,setValue=function(v) s.errorRaise=v;NS.SyncEllesmereErrorText() end},
        {type='slider',text='Error Text Distance From Top',min=20,max=400,step=10,
        getValue=function() return s.errorY end,setValue=function(v) s.errorY=v;NS.SyncEllesmereErrorText() end})
    Row({type='toggle',text='Hide Spam Errors',tooltip='Hides "Spell is not ready yet", "Ability is not ready yet", "Out of range" and "Not enough mana" and their voice lines, like retail does. Errors that need an action still show in red.',
        getValue=function() return s.errorFilter end,setValue=function(v) s.errorFilter=v;NS.SyncEllesmereErrorFilter() end},
        {type='toggle',text='Hide Errors A Warning Shows',tooltip='Hides the red error line when a warning already shows the same problem: Target too close (range indicator), facing (Face Target), out of ammo (ammo warning) and a dead pet (pet warning).',
        getValue=function() return s.errorRoute==true end,setValue=function(v) s.errorRoute=v;NS.SyncEllesmereErrorRoutes() end})
    Row({type='toggle',text='Frenzy: Tranquilizing Shot',tooltip='In combat, warns when your enemy target has a Frenzy effect. Quiet until you know Tranquilizing Shot.',
        getValue=function() return s.tranq end,setValue=function(v) s.tranq=v;NS.SyncEllesmereWarnings() end})
    local soundValues={none='None',raid='Raid Warning',alarm='Alarm',ready='Ready Check',tick='Soft Tick'}
    local soundOrder={'none','raid','alarm','ready','tick'}
    Row({type='dropdown',text='Act-Now Warning Sound',values=soundValues,order=soundOrder,
        tooltip='Plays when a red or above-the-character warning appears (out of ammo, dead pet, Stop Attack...).',
        getValue=function() return s.dangerSound end,setValue=function(v) s.dangerSound=v;Sound('preview',true) end},
        {type='dropdown',text='Other Warning Sound',values=soundValues,order=soundOrder,
        tooltip='Plays when any other warning appears.',
        getValue=function() return s.warnSound end,setValue=function(v) s.warnSound=v;Sound('preview2',false) end})
    Row({type='toggle',text='Combat Warnings Above Character',tooltip='In combat, warnings that need an action now (pet health, dead pet, out of ammo, Frenzy, unsafe aspect) move above your character. Information stays in the top lane.',
        getValue=function() return s.critical end,setValue=function(v) s.critical=v;NS.SyncEllesmereWarnings() end},
        {type='slider',text='Combat Warning Height',min=60,max=300,step=10,
        getValue=function() return s.criticalY end,setValue=function(v) s.criticalY=v;Layout() end})
    if NS.EllesmereColorRow then
        Row(NS.EllesmereColorRow('alert','Act-Now Warning Color','Red warnings: out of ammo, dead pet, Stop Attack, Feign Death.'),
            NS.EllesmereColorRow('caution','Caution Warning Color','Amber warnings: low ammo, feed pet, low pet food. Also the dead-zone approach color.'))
        Row(NS.EllesmereResetColors({'alert','caution'},'Reset Warning Colors'),{type='label',text='Shown the next time a warning appears'})
    end
    Row({type='button',text='Preview Warnings',onClick=function() NS.PreviewEllesmereWarnings() end},
        {type='label',text='Top of the screen, under the game error line'})
end

local boot=CreateFrame('Frame')
boot:RegisterEvent('PLAYER_LOGIN')
boot:SetScript('OnEvent',function(self)
    self:UnregisterAllEvents(); NS.SyncEllesmereWarnings(); NS.SyncEllesmereErrorText(); NS.SyncEllesmereErrorFilter()
end)
