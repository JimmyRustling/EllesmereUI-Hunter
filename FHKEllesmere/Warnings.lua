-- Hunter warnings in the style of Ellesmere's Low Durability warning (same
-- font, size, pulse and position, stacked just below it): low/empty ammo and
-- unspent talent points, unsafe aspects and pet status. New reminders are opt-in.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end

local DEFAULTS={ammo=true,ammoLow=200,ammoCritical=50,talents=true,aspects=false,petHealth=false,petLow=40,petRange=false,petStatus=false,
    feed=false,feedContent=true,petFood=false,petFoodLow=10,dangerSound='none',warnSound='none',
    errorRaise=false,errorY=110,errorX=0,errorFilter=false,critical=true,criticalY=150,criticalX=0,tranq=true,
    -- Text style (player, 2026-10-06): off follows Ellesmere's Low Durability text.
    textCustom=false,textSize=30,combatTextSize=22,textOutline='native',
    -- Class kits (2026-10-06), all off: Pet On Passive (hunter and warlock), Missing / Dead Pet
    -- out of combat, "I Play Without A Pet", and the pet level warning.
    petPassive=false,petPassiveOOC=false,petStatusOOC=false,noPet=false,petLevel=false,petLevelGap=3,
    -- Warriors and rogues with a stat bow or gun (review S11): off; out of combat only, never critical.
    ammoOthers=false}
-- New keys are validated on every read (corrupted SavedVariables fall back to the default).
local NEW_BOOLS={'petPassive','petPassiveOOC','petStatusOOC','noPet','petLevel','ammoOthers'}
local LIMITS={petLevelGap={1,10},ammoLow={50,1000},ammoCritical={0,200}}
local OUTLINES={native=true,outline='OUTLINE',thick='THICKOUTLINE',none=''}
-- Sounds by choice key. 'eui:<key>' picks a sound from Ellesmere's alert catalogue.
local SOUNDS={raid=_G.SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959,alarm=_G.SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3 or 12889,
    ready=_G.SOUNDKIT and SOUNDKIT.READY_CHECK or 8960,tick=_G.SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856}
local euiSoundPaths,euiSoundNames,euiSoundOrder
local function EuiSounds()
    if euiSoundPaths==nil then
        euiSoundPaths=false
        if type(EUI.BuildAlertSoundTables)=='function' then
            local ok,paths,names,order=pcall(EUI.BuildAlertSoundTables)
            if ok and type(paths)=='table' and type(names)=='table' and type(order)=='table' then
                euiSoundPaths,euiSoundNames,euiSoundOrder=paths,names,order
            end
        end
    end
    return euiSoundPaths or nil
end
local function EuiPath(choice)
    if type(choice)~='string' or choice:sub(1,4)~='eui:' then return end
    local paths=EuiSounds()
    local path=paths and paths[choice:sub(5)]
    return type(path)=='string' and path or nil
end
local function ValidSound(choice)
    return choice=='none' or SOUNDS[choice]~=nil or EuiPath(choice)~=nil
end
local AMMO_WEAPONS={[2]=true,[3]=true,[18]=true} -- bows, guns, crossbows
local AMMO_SLOT,RANGED_SLOT=_G.INVSLOT_AMMO or 0,_G.INVSLOT_RANGED or 18
local C=NS.Colours or {}
local RED,AMBER=C.alert or {1,0.27,0.27},C.caution or {1,0.82,0}
local function Public(v) return not (issecretvalue and issecretvalue(v)) end
local function Text(v) return Public(v) and type(v)=='string' and v~='' end
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
local function PlayerClass() return select(2,Read(UnitClass,'player')) end
-- Away policy (review S2, section 0): Bootstrap's NS.EllesmereAway(kind) when present.
-- kind 'bought' (low supplies) shows while mounted; 'act' and 'buff' do not.
local function AwayFor(kind)
    local fn=NS.EllesmereAway
    if type(fn)=='function' then
        local ok,v=pcall(fn,kind)
        if ok then return v~=nil end
    end
    -- Same rule as Bootstrap: an unreadable state is not a reason.
    if Read(UnitIsDeadOrGhost,'player')==true or Read(UnitOnTaxi,'player')==true or Read(UnitHasVehicleUI,'player')==true then return true end
    return kind~='bought' and Read(IsMounted)==true
end
-- Classes besides hunters that can fire ammo (a stat bow or gun).
local AMMO_CLASSES={WARRIOR=true,ROGUE=true}

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
-- Warning text size: our own when Warning Text Style is on, else Ellesmere's Low Durability size.
local function WarnSize()
    local s=NS.EllesmereWarningSettings()
    if s.textCustom==true and Number(s.textSize) then return math.max(10,math.min(60,s.textSize)) end
    local db=EllesmereUIDB
    return (db and db.durWarnTextSize) or 30
end
local function WarnOutline()
    local s=NS.EllesmereWarningSettings()
    local o=s.textCustom==true and OUTLINES[s.textOutline]
    if type(o)=='string' then return o,true end
    return EUI.GetFontOutlineFlag and EUI.GetFontOutlineFlag('extras') or 'OUTLINE',false
end
local function ErrorSize()
    return math.floor(WarnSize()*.8+.5)
end
local function ErrorTop()
    local s=NS.EllesmereWarningSettings()
    return Number(s.errorY) and s.errorY or 110
end
local function ErrorX()
    local s=NS.EllesmereWarningSettings()
    return Number(s.errorX) and math.max(-1200,math.min(1200,s.errorX)) or 0
end
function NS.EllesmereWarningLaneTop()
    if NS.EllesmereWarningSettings().errorRaise==false then return end
    return ErrorTop()+ErrorSize()+8
end
local errorMoved=false
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
    -- Off: put the frame back once if we moved it, then leave it alone (review R6).
    if s.errorRaise==false and not errorMoved then
        if NS.LayoutEllesmereWarnings then NS.LayoutEllesmereWarnings() end
        return
    end
    errorMoved=s.errorRaise~=false
    errorPlacing=true
    f:ClearAllPoints()
    if s.errorRaise~=false then
        -- One line tall: the newest error replaces the last instead of stacking
        -- down into the warnings beneath it.
        local size=ErrorSize()
        f:SetPoint('TOP',UIParent,'TOP',ErrorX(),-ErrorTop())
        f:SetWidth(math.max(errorBase.width,900));f:SetHeight(size+8)
        local outline,own=WarnOutline()
        f:SetFont(EUI.GetFontPath and EUI.GetFontPath('extras') or errorBase.font[1],size,own and outline or errorBase.font[3])
    else
        for _,p in ipairs(errorBase.points) do f:SetPoint(unpack(p)) end
        f:SetWidth(errorBase.width);f:SetHeight(errorBase.height)
        f:SetFont(errorBase.font[1],errorBase.font[2],errorBase.font[3])
    end
    errorPlacing=nil
    if errorMoved and not select(2,WarnOutline()) and NS.ApplyEllesmereCueText then NS.ApplyEllesmereCueText(f,'world',true) end
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

-- Errors a cue already shows (plan section 1.K: one problem shows once). The client gives
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
    if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end
    local s=FHKEllesmereDB.warnings
    if type(s)~='table' then s={}; FHKEllesmereDB.warnings=s end
    -- Moving and filtering the game's error line is the owner's setup by default (review R4).
    if s.errorRaise==nil then s.errorRaise=_G.ForeverHunterKeysNS~=nil end
    if s.errorFilter==nil then s.errorFilter=_G.ForeverHunterKeysNS~=nil end
    for k,v in pairs(DEFAULTS) do if s[k]==nil then s[k]=v end end
    for _,k in ipairs(NEW_BOOLS) do if type(s[k])~='boolean' then s[k]=DEFAULTS[k] end end
    for k,l in pairs(LIMITS) do
        if not Number(s[k]) or s[k]<l[1] or s[k]>l[2] then s[k]=DEFAULTS[k] end
        s[k]=math.floor(s[k])
    end
    if type(s.overrides)~='table' then s.overrides={} end
    return s
end

-------------------------------------------------------------------------------
-- Per-warning lane and sound (review C3). s.overrides[key]={lane=,sound=}; each entry is
-- validated when read, so a corrupted entry acts as the default and never errors.
-------------------------------------------------------------------------------
local LANES={top=true,combat=true}
-- One toggle can own several lane keys (Feign Death shows the countdown and Resisted).
local OVERRIDE_OF={feignResist='feign'}
local function Override(key)
    local list=NS.EllesmereWarningSettings().overrides
    local o=list[OVERRIDE_OF[key] or key]
    if type(o)~='table' then return nil,nil end
    local lane,sound=o.lane,o.sound
    return LANES[lane] and lane or nil,ValidSound(sound) and sound or nil
end
NS.EllesmereWarningOverride=Override
local function Effective(key,critical)
    local lane=Override(key)
    if lane=='top' then return false elseif lane=='combat' then return true end
    return critical==true
end

-- One row per warning, built on first use.
local rows,order={}, {'tranq','aspects','ammo','petStatus','petPassive','petHealth','petRange','feed','petFood','petLevel','talents'}
local container,centre
-- The combat-lane preview (review C5) shows the centre lane out of combat for a moment.
local previewCentre,previewToken=false,0
-- In combat, warnings that need an action now sit above the character, inside
-- the eye's working field (audit); information and game errors stay at the top.
local function CentreLane()
    local s=NS.EllesmereWarningSettings()
    return s.critical~=false and (previewCentre or InCombatLockdown())
end
local function CentreSize()
    local s=NS.EllesmereWarningSettings()
    if s.textCustom==true and Number(s.combatTextSize) then return math.max(10,math.min(48,s.combatTextSize)) end
    return math.min(WarnSize(),22)
end
-- Ellesmere Aura Buff Reminders (review SQ-6): its icon row sits at screen centre + yOffset (200
-- by default). While it is loaded and on, lanes the player has not moved start clear of that
-- band. The band's half height is a probe (icon size and scale are not read).
local ABR_HALF=24
local function BuffRemindersY()
    local loaded=Read(C_AddOns and C_AddOns.IsAddOnLoaded,'EllesmereUIAuraBuffReminders')
    if loaded~=true then return nil end
    local db=EllesmereUIDB
    local profiles=type(db)=='table' and db.profiles
    local profile=type(profiles)=='table' and profiles[type(db.activeProfile)=='string' and db.activeProfile or 'Default']
    local addons=type(profile)=='table' and profile.addons
    local abr=type(addons)=='table' and addons.EllesmereUIAuraBuffReminders
    local d=type(abr)=='table' and abr.display
    if type(d)~='table' then d=nil end
    if d and d.remindersEnabled==false then return nil end
    if d and Number(d.xOffset) and math.abs(d.xOffset)>300 then return nil end
    return d and Number(d.yOffset) and d.yOffset or 200
end
NS.EllesmereBuffRemindersY=BuffRemindersY
-- The combat lane's bottom: the player's position, or the default kept under the icon band
-- (two rows of room).
local function CombatY()
    local s=NS.EllesmereWarningSettings()
    local y=Number(s.criticalY) and s.criticalY or 150
    if y==150 and (not Number(s.criticalX) or s.criticalX==0) then
        local abr=BuffRemindersY()
        if abr then y=math.min(y,abr-ABR_HALF-2*(CentreSize()+10)) end
    end
    return y
end
local function Anchor()
    container:ClearAllPoints()
    local lane=NS.EllesmereWarningLaneTop and NS.EllesmereWarningLaneTop()
    if lane then container:SetPoint('TOP',UIParent,'TOP',ErrorX(),-lane);return end
    local db=EllesmereUIDB
    local pos=db and db.durWarnPos
    local size=(db and db.durWarnTextSize) or 30
    if pos and pos.point then
        container:SetPoint('TOP',UIParent,pos.relPoint or pos.point,pos.x or 0,(pos.y or 250)-size*0.75)
    else
        local top=((db and db.durWarnYOffset) or 250)-size*0.75
        -- Ellesmere's default durability spot sits right over the buff reminders: start below them.
        local abr=not (db and db.durWarnYOffset) and BuffRemindersY()
        if abr then top=math.min(top,abr-ABR_HALF) end
        container:SetPoint('TOP',UIParent,'CENTER',0,top)
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
    local cx=Number(s.criticalX) and math.max(-1200,math.min(1200,s.criticalX)) or 0
    centre:ClearAllPoints();centre:SetPoint('BOTTOM',UIParent,'CENTER',cx,CombatY())
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
local soundAt={}
-- A sound by choice key (range brackets use the same list), at most every 3 s per caller key.
-- Ellesmere's own alert sounds ('eui:<key>') play their file.
function NS.PlayEllesmereCueSound(choice,key)
    local id,path=SOUNDS[choice],EuiPath(choice)
    if not id and not path then return end
    local play
    if id then play=_G.PlaySound else play=_G.PlaySoundFile end
    if type(play)~='function' then return end
    local now=GetTime and GetTime() or 0
    key=key or choice
    if soundAt[key] and now-soundAt[key]<3 then return end
    soundAt[key]=now
    pcall(play,id or path,'Master')
end
-- One sound per lane key when it first appears (review S1): the player's per-warning choice,
-- else the module's own sound (a valid choice; 'none' silences), else the lane default.
local function Sound(key,critical,moduleSound)
    local s=NS.EllesmereWarningSettings()
    local _,own=Override(key)
    if not own and moduleSound~=nil and ValidSound(moduleSound) then own=moduleSound end
    NS.PlayEllesmereCueSound(own or (critical and s.dangerSound or s.warnSound),key)
end
NS.EllesmereWarningSound=Sound
-- Warning text through Ellesmere's module font (review C14): a "" flag (Drop Shadow / None)
-- gets Ellesmere's drop shadow. An outline chosen in Warning Text Style keeps no shadow.
local function PaintFont(fs,font,size,outline,own)
    if not own and type(EUI.ApplyModuleFont)=='function' and pcall(EUI.ApplyModuleFont,fs,font,size,'extras',outline) then return end
    if own and type(EUI.PrimeFontShadow)=='function' then pcall(EUI.PrimeFontShadow,fs,false) end
    fs:SetFont(font,size,outline)
end
local function Show(key,text,colour,slow,critical,sound)
    local row=Row(key)
    row.asked=critical==true
    critical=Effective(key,critical)
    row.critical=critical
    local db=EllesmereUIDB
    local size=(row.critical and CentreLane()) and CentreSize() or WarnSize()
    local font=EUI.GetFontPath and EUI.GetFontPath('extras') or EUI.EXPRESSWAY or 'Fonts\\FRIZQT__.TTF'
    local outline,ownOutline=WarnOutline()
    local calm=Calm()
    local last=row.warningPaint
    row.warningColor=colour
    if row:IsShown() and not row.leaving and last and last.text==text and last.r==colour[1] and last.g==colour[2] and
        last.b==colour[3] and last.slow==slow and last.critical==row.critical and last.size==size and last.font==font and last.outline==outline and last.calm==calm then return end
    row.warningPaint={text=text,r=colour[1],g=colour[2],b=colour[3],slow=slow,critical=row.critical,size=size,font=font,outline=outline,calm=calm}
    PaintFont(row.text,font,size,outline,ownOutline)
    -- An outline chosen here is kept; otherwise the theme's world-cue outline applies.
    if not ownOutline and NS.ApplyEllesmereCueText then NS.ApplyEllesmereCueText(row.text,'world',true) end
    row:SetHeight(size+10)
    row.text:SetText(text); row.text:SetTextColor(colour[1],colour[2],colour[3],1)
    local d=slow and 0.5 or 0.35
    row.pulseOut:SetDuration(d); row.pulseBack:SetDuration(d)
    -- A warning that returns while fading out simply stays.
    local arriving=not row:IsShown()
    if row.leaving then row.leaving=nil; row.fadeOut:Stop() end
    row:Show(); Layout()
    if arriving then row.fade:Play(); if not Calm() then row.pulse:Play() end; Sound(key,critical,sound) end
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
-- sound (optional): a module's own choice ('raid', 'alarm', 'ready', 'tick', 'eui:<key>' or
-- 'none'); nil keeps the lane default. Modules no longer play a sound beside Show.
function NS.ShowEllesmereWarning(key,text,colour,slow,critical,sound)
    local listed=false
    for _,k in ipairs(order) do if k==key then listed=true;break end end
    if not listed then
        if FRONT[key] then table.insert(order,1,key) else table.insert(order,math.max(1,#order),key) end
    end
    Show(key,text,colour,slow,critical,sound)
end
NS.HideEllesmereWarning=Hide

-- Cog rows for a warning toggle: its lane and its sound (review C3). Other modules call this
-- on their own toggles with their lane key.
local LANE_VALUES={auto='Automatic',top='Top Lane',combat='Above Character In Combat'}
local LANE_ORDER={'auto','top','combat'}
local BASE_SOUND_VALUES={none='None',raid='Raid Warning',alarm='Alarm',ready='Ready Check',tick='Soft Tick'}
local BASE_SOUND_ORDER={'none','raid','alarm','ready','tick'}
local function SoundChoices()
    local values,list={default='Lane Default'},{'default'}
    for _,k in ipairs(BASE_SOUND_ORDER) do values[k]=BASE_SOUND_VALUES[k];list[#list+1]=k end
    if EuiSounds() then
        for _,k in ipairs(euiSoundOrder) do
            if k~='none' and type(euiSoundPaths[k])=='string' and type(euiSoundNames[k])=='string' then
                values['eui:'..k]=euiSoundNames[k];list[#list+1]='eui:'..k
            end
        end
    end
    return values,list
end
function NS.SetEllesmereWarningOverride(key,field,value)
    if type(key)~='string' or (field~='lane' and field~='sound') then return false end
    if field=='lane' and value~='auto' and not LANES[value] then return false end
    if field=='sound' and value~='default' and not ValidSound(value) then return false end
    local list=NS.EllesmereWarningSettings().overrides
    local o=type(list[key])=='table' and list[key] or {}
    if value=='auto' or value=='default' then o[field]=nil else o[field]=value end
    if next(o) then list[key]=o else list[key]=nil end
    -- A warning on screen changes lane at once.
    for k,row in pairs(rows) do
        if (OVERRIDE_OF[k] or k)==key and row:IsShown() and row.asked~=nil then
            row.critical=Effective(k,row.asked);row.warningPaint=nil
        end
    end
    Layout()
    return true
end
function NS.AttachEllesmereWarningOverrides(cfg,key,isOn)
    if type(cfg)~='table' or type(key)~='string' then return cfg end
    local values,list=SoundChoices()
    local add={
        {type='dropdown',label='Lane',values=LANE_VALUES,order=LANE_ORDER,
            tooltip='Automatic: act-now warnings move above your character in combat. Top Lane always stays at the top. Above Character In Combat always moves there in combat.',
            get=function() return (Override(key)) or 'auto' end,set=function(v) NS.SetEllesmereWarningOverride(key,'lane',v) end},
        {type='dropdown',label='Sound',values=values,order=list,tooltip='Lane Default uses the Act-Now or Other Warning Sound below.',
            get=function() return select(2,Override(key)) or 'default' end,
            set=function(v)
                if NS.SetEllesmereWarningOverride(key,'sound',v) and v~='default' then
                    soundAt['preview:'..key]=nil;NS.PlayEllesmereCueSound(v,'preview:'..key)
                end
            end}}
    if type(cfg.cog)=='table' and type(cfg.cog.rows)=='table' then
        for _,r in ipairs(add) do cfg.cog.rows[#cfg.cog.rows+1]=r end
    else
        cfg.cog={title=cfg.text,rows=add,disabledTooltip=cfg.text,
            disabled=type(isOn)=='function' and function() return not isOn() end or nil}
    end
    return cfg
end
function NS.RepaintEllesmereWarnings()
    for _,row in pairs(rows) do
        local c=row.warningColor
        if c and row:IsShown() then
            row.text:SetTextColor(c[1],c[2],c[3],1)
            row.warningPaint=nil
        end
    end
end

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
-- Every round of the fitting type in the bags (review S12; the equipped stack is in the bags
-- too). Cached until the bags or the equipment change; false when unreadable.
local totalCache={}
local function TotalAmmo(want)
    local hit=totalCache[want]
    if hit~=nil then return hit end
    local C=C_Container
    local total=false
    if C and C.GetContainerNumSlots and C.GetContainerItemInfo then
        total=0
        for bag=0,(_G.NUM_BAG_SLOTS or 4) do
            local slots=Read(C.GetContainerNumSlots,bag)
            if not Number(slots) then total=false;break end
            for slot=1,slots do
                local info=Read(C.GetContainerItemInfo,bag,slot)
                if type(info)=='table' and Number(info.itemID) then
                    local classID,subclassID=Instant(info.itemID)
                    if classID==6 and subclassID==want and Number(info.stackCount) then total=total+info.stackCount end
                end
            end
            if total==false then break end
        end
    end
    totalCache[want]=total
    return total
end
local function ItemName(id)
    local name=Number(id) and Read(C_Item and C_Item.GetItemInfo or _G.GetItemInfo,id)
    return type(name)=='string' and name or nil
end
-- Ammo types a warrior or rogue carried this session (review S11).
local carriedAmmo={}
local function CheckAmmo()
    local s=NS.EllesmereWarningSettings()
    local class=PlayerClass()
    local hunter=class=='HUNTER' or type(class)~='string'
    local on=hunter and s.ammo or not hunter and s.ammoOthers==true and AMMO_CLASSES[class]==true
    local state,count,want,inBags=nil,0
    if on then state,count,want,inBags=NS.EllesmereAmmoState() end
    if state and not want then want=WantedAmmo() end
    local combat=InCombatLockdown()
    local crit=Number(s.ammoCritical) and s.ammoCritical or 50
    local low=Number(s.ammoLow) and s.ammoLow or 200
    local text,colour,critical,inCombat
    local name=NS.EllesmereAmmoName(want)
    if state=='wrong' then
        text,colour,critical,inCombat=inBags and ('Wrong Ammo - Equip ' .. name) or ('Wrong Ammo - No ' .. name .. ' in Bags'),RED,true,true
    elseif state=='empty' then
        text,colour,critical,inCombat='Ammo Slot Empty - Equip ' .. name,RED,true,true
    elseif state=='critical' or state=='low' then
        -- The total of fitting ammo decides how bad it is; the equipped stack only says what to equip.
        local total=want and TotalAmmo(want)
        if not Number(total) or total<count then total=count end
        if total<=crit then
            text,colour,critical,inCombat=count==0 and total==0 and 'Out of Ammo' or ('Ammo Critical (' .. total .. ')'),RED,true,true
        elseif total<low then
            text,colour=('Low Ammo (' .. total .. ')'),AMBER
        elseif total>count then
            local equipped=ItemName(Read(GetInventoryItemID,'player',AMMO_SLOT))
            text,colour,inCombat=('Low ' .. (equipped or 'Ammo') .. ' (' .. count .. '): ' .. (total-count) .. ' More In Bags'),AMBER,count<=crit
        end
    end
    if want and Number(count) and count>0 then carriedAmmo[want]=true end
    if not hunter then
        -- Warriors and rogues: out of combat only, never the critical lane, and only for ammo they carried.
        if not (want and carriedAmmo[want]) then text=nil end
        colour,critical,inCombat=AMBER,false,false
    end
    if not text or (combat and not inCombat) or AwayFor(critical and 'act' or 'bought') then Hide('ammo');return end
    Show('ammo',text,colour,nil,critical)
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
        -- Forever answers with C_ClassTalents.HasUnspentTalentPoints(): a boolean (API audit).
        if a==true then n=math.max(1,(Number(b) and b or 0)+(Number(c) and c or 0)) end
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
        local text=n==1 and 'Unspent Talent Point' or ('Unspent Talent Points (' .. n .. ')')
        -- With a talent plan, say what is next (Talent Planner).
        local nextTalent=NS.EllesmereNextPlannedTalent and NS.EllesmereNextPlannedTalent()
        if type(nextTalent)=='string' then text=text..': '..nextTalent end
        Show('talents',text,c,true)
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
    if s.petFood~=true or not Hunter() or Read(InCombatLockdown)~=false or not PetAlive() or not NS.EllesmerePetFoodCount or AwayFor('bought') then Hide('petFood');return end
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
-- Warlocks: Health Funnel (755) is the Mend Pet of a demon. Its range read is not verified on
-- Forever, so the warlock version never uses range (and Pet Too Far stays hunter only).
local HEALTH_FUNNEL=755
local function SpellNameOf(id)
    local name=Read(C_Spell and C_Spell.GetSpellName,id)
    if type(name)=='string' then return name end
    local info=Read(C_Spell and C_Spell.GetSpellInfo,id)
    if type(info)=='table' and Public(info.name) and type(info.name)=='string' then return info.name end
end
local function CheckPetHealth()
    local s=NS.EllesmereWarningSettings()
    local warlock=PlayerClass()=='WARLOCK'
    if not s.petHealth or not (warlock or Hunter()) or not PetAlive() then Hide('petHealth');return end
    if warlock then
        if Read(C_SpellBook and C_SpellBook.IsSpellKnown,HEALTH_FUNNEL)~=true then Hide('petHealth');return end
    elseif not MendKnown() then Hide('petHealth');return end
    local hp,max=Read(UnitHealth,'pet'),Read(UnitHealthMax,'pet')
    if not Number(hp) or not Number(max) or max<=0 or hp<=0 then Hide('petHealth');return end
    local threshold=Number(s.petLow) and math.max(5,math.min(90,s.petLow)) or 40
    if hp/max*100>threshold then Hide('petHealth');return end
    local name=warlock and SpellNameOf(HEALTH_FUNNEL) or not warlock and MendName()
    if not name then Hide('petHealth');return end
    local aura,_,_,known=Read(C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName,'pet',name,'HELPFUL')
    if not known or type(aura)=='table' or (not warlock and MendRange()==false) then Hide('petHealth');return end
    Show('petHealth',(warlock and name or 'Mend Pet')..' (' .. math.floor(hp/max*100+.5) .. '%)',AMBER,true,true)
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
-- Travel, death and vehicles: nothing a pet warning can ask for.
local function Away() return AwayFor('act') end
-- Lone Wolf (Forever talent 415370), a warlock's Demonic Sacrifice, or the player's own
-- "I Play Without A Pet" choice.
local LONE_WOLF=415370
-- Demonic Sacrifice leaves one of these buffs (matched by aura name). Aura reads can turn
-- secret in combat: the last readable answer is kept, and no answer at all stays quiet.
-- By spell ID (review R2-5): the names are English-only and Fel Stamina is also a Demonology
-- talent. 18789 Burning Wish, 18790 Fel Stamina, 18791 Touch of Shadow, 18792 Fel Energy.
local SACRIFICE={18789,18790,18791,18792}
local sacrificed=nil
function NS.EllesmereDemonSacrificed()
    local get=C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if type(get)~='function' then return sacrificed end
    local readable=true
    for i=1,#SACRIFICE do
        local ok,aura=pcall(get,SACRIFICE[i])
        if not ok or not Public(aura) then readable=false
        elseif type(aura)=='table' then sacrificed=true;return true end
    end
    if readable then sacrificed=false end
    return sacrificed
end
local function NoPetByChoice(s,warlock)
    if s.noPet==true then return true end
    if warlock then return NS.EllesmereDemonSacrificed()~=false end
    if NS.HunterTalents and Read(NS.HunterTalents.Has,'loneWolf')==true then return true end
    return Read(C_SpellBook and C_SpellBook.IsSpellKnown,LONE_WOLF)==true
end
NS.EllesmereNoPetByChoice=function() return NoPetByChoice(NS.EllesmereWarningSettings(),PlayerClass()=='WARLOCK') end
local SUMMONS={688,697,712,713,691} -- Imp, Voidwalker, Succubus, Incubus, Felhunter
local function SummonKnown(warlock)
    local known=C_SpellBook and C_SpellBook.IsSpellKnown
    if not warlock then return Read(known,883)==true end
    for i=1,#SUMMONS do if Read(known,SUMMONS[i])==true then return true end end
    return false
end
-- Out of combat a missing pet waits a moment: zoning, landing and resurrection bring it back.
local MISSING_GRACE=3
local missingSince,missingToken=nil,0
local CheckPetStatus
CheckPetStatus=function()
    local s=NS.EllesmereWarningSettings()
    local combat=Read(InCombatLockdown)
    local class=PlayerClass()
    local warlock=class=='WARLOCK'
    if not s.petStatus or not (warlock or class=='HUNTER') or type(combat)~='boolean' or (not combat and s.petStatusOOC~=true) or Away() then
        missingSince=nil;Hide('petStatus');return
    end
    if not SummonKnown(warlock) or NoPetByChoice(s,warlock) then missingSince=nil;Hide('petStatus');return end
    local exists=Read(UnitExists,'pet')
    -- A warlock's demon is summoned again, never revived.
    local missing=warlock and 'Summon Demon' or 'Call / Revive Pet'
    if exists==true and Read(UnitIsDeadOrGhost,'pet')==true then
        missingSince=nil
        local text=warlock and 'Summon Demon' or 'Revive Pet'
        if combat then Show('petStatus',text,RED,true,true) else Show('petStatus',text,AMBER,true) end
    elseif exists==false then
        -- An absent unit cannot distinguish a dismissed pet from a dead one.
        if combat then missingSince=nil;Show('petStatus',missing,AMBER,true,true);return end
        local now=GetTime and GetTime() or 0
        if not missingSince then
            missingSince=now;missingToken=missingToken+1
            local token=missingToken
            if C_Timer and C_Timer.After then C_Timer.After(MISSING_GRACE,function() if token==missingToken then CheckPetStatus() end end) end
        end
        if now-missingSince>=MISSING_GRACE then Show('petStatus',missing,AMBER,true) else Hide('petStatus') end
    else missingSince=nil;Hide('petStatus') end
end

-- Pet On Passive (review H3): the pet bar's active stance token, hunters and warlocks.
-- true = Passive, false = another stance, nil = unknown (no pet bar or an unreadable answer).
local function PetClass()
    local class=select(2,Read(UnitClass,'player'))
    return class=='HUNTER' or class=='WARLOCK'
end
function NS.EllesmerePetPassive()
    local info=_G.GetPetActionInfo
    if type(info)~='function' then return nil end
    for i=1,(_G.NUM_PET_ACTION_SLOTS or 10) do
        local ok,name,_,isToken,isActive=pcall(info,i)
        if not ok or not Public(name) or not Public(isToken) or not Public(isActive) then return nil end
        if isToken==true and isActive==true and type(name)=='string' and name:find('^PET_MODE_') then
            return name=='PET_MODE_PASSIVE'
        end
    end
    return nil
end
local function CheckPetPassive()
    local s=NS.EllesmereWarningSettings()
    local combat=Read(InCombatLockdown)
    if s.petPassive~=true or not PetClass() or type(combat)~='boolean' or (not combat and s.petPassiveOOC~=true) or
        not PetAlive() or Away() then Hide('petPassive');return end
    if NS.EllesmerePetPassive()==true then
        if combat then Show('petPassive','Pet On Passive',RED,nil,true) else Show('petPassive','Pet On Passive',AMBER,true) end
    else Hide('petPassive') end
end

-- Pet level behind yours (review H6): out of combat, from public unit levels only.
-- A 10 s notice (review S14) on login, a new pet and your level-up: the gap is a state that
-- only clears as the pet levels, so it is news only then. The pet XP tooltip keeps it after.
local LEVEL_NOTICE=10
local levelUntil,levelToken,levelKey=nil,0,nil
local CheckPetLevel
-- Once per pet and player level (review R2-17): a loading screen with the same pet is not news.
-- newLevel: PLAYER_LEVEL_UP's own argument (UnitLevel can still be the old level then).
local function PetLevelNotice(newLevel)
    local guid=Read(UnitGUID,'pet')
    if type(guid)~='string' then guid=Read(UnitName,'pet') end
    local mine=Number(newLevel) and newLevel or Read(UnitLevel,'player')
    local key=tostring(guid)..':'..tostring(mine)
    if key==levelKey then return end
    levelKey=key
    local now=GetTime and GetTime() or 0
    levelUntil=now+LEVEL_NOTICE;levelToken=levelToken+1
    local token=levelToken
    if C_Timer and C_Timer.After then C_Timer.After(LEVEL_NOTICE,function() if token==levelToken then levelUntil=nil;CheckPetLevel() end end) end
end
NS.EllesmerePetLevelNotice=PetLevelNotice
CheckPetLevel=function()
    local s=NS.EllesmereWarningSettings()
    local now=GetTime and GetTime() or 0
    if s.petLevel~=true or not Hunter() or Read(InCombatLockdown)~=false or not PetAlive() or not levelUntil or now>=levelUntil or AwayFor('bought') then Hide('petLevel');return end
    local pet,mine=Read(UnitLevel,'pet'),Read(UnitLevel,'player')
    if not Number(pet) or not Number(mine) or pet<=0 or mine<=0 then Hide('petLevel');return end
    local behind=mine-pet
    if behind>=s.petLevelGap then
        Show('petLevel','Pet Level '..pet..' ('..behind..(behind==1 and ' Level' or ' Levels')..' Below You)',AMBER,true)
    else Hide('petLevel') end
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
-- Combat start or end re-lays every row (review R2-2): a critical row must change lane even
-- when its text and size are unchanged, and rows owned by other modules move too.
local laneDirty=false
local function Flush()
    pendingCheck=false
    if laneDirty then
        laneDirty=false
        for _,row in pairs(rows) do row.warningPaint=nil end
    end
    CheckPetFood();CheckAmmo();CheckTalents();CheckAspects();CheckPetStatus();CheckPetPassive();CheckPetHealth();CheckPetRange();CheckPetLevel();CheckFrenzy()
    if petTicker then
        local s=NS.EllesmereWarningSettings()
        if (s.petRange or s.petHealth) and Hunter() and PetAlive() and MendKnown() then petTicker.Start()
        else petTicker.Stop();lastPetRange=nil end
    end
    Layout()
end
-- Bag, equipment and zoning change the ammo total (review R2-1); nothing else clears it.
local BAG_EVENTS={BAG_UPDATE_DELAYED=true,PLAYER_EQUIPMENT_CHANGED=true,UNIT_INVENTORY_CHANGED=true,PLAYER_ENTERING_WORLD=true}
-- Death, travel and vehicles (review R2-8): re-check now and once more 0.5 s later, since the
-- mounted and taxi reads can lag the event.
local AWAY_EVENTS={PLAYER_DEAD=true,PLAYER_ALIVE=true,PLAYER_UNGHOST=true,PLAYER_CONTROL_LOST=true,PLAYER_CONTROL_GAINED=true,
    PLAYER_MOUNT_DISPLAY_CHANGED=true,UNIT_ENTERED_VEHICLE=true,UNIT_EXITED_VEHICLE=true}
local awayQueued=false
local function Queue()
    if pendingCheck then return end
    pendingCheck=true
    C_Timer.After(0,Flush)
end
local function OnEvent(_,event,unit)
    if not Public(unit) then return end
    -- Durability events are registered only while the native warning label is being found.
    if event=='UPDATE_INVENTORY_DURABILITY' or event=='UPDATE_INVENTORY_ALERTS' then NS.SyncEllesmereNativeWarningOutline();return end
    if BAG_EVENTS[event] and (event~='UNIT_INVENTORY_CHANGED' or unit=='player') then for k in pairs(totalCache) do totalCache[k]=nil end end
    if event=='PLAYER_REGEN_ENABLED' or event=='PLAYER_REGEN_DISABLED' then laneDirty=true end
    if AWAY_EVENTS[event] and not awayQueued and C_Timer and C_Timer.After then
        awayQueued=true
        C_Timer.After(.5,function() awayQueued=false;Queue() end)
    end
    if (event=='PLAYER_ENTERING_WORLD' or event=='PLAYER_LEVEL_UP' or event=='UNIT_PET' and unit=='player') and
        NS.EllesmereWarningSettings().petLevel==true then PetLevelNotice(event=='PLAYER_LEVEL_UP' and unit or nil) end
    -- Pet food counts change only with the bags or the pet.
    if NS.PetFood and (event=='BAG_UPDATE_DELAYED' or event=='UNIT_PET' and unit=='player') then NS.PetFood.Invalidate(event=='UNIT_PET') end
    if event=='UNIT_INVENTORY_CHANGED' and unit~='player' then return end
    if event:find('^UNIT_') and unit and unit~='player' and unit~='pet' and unit~='target' then return end
    Queue()
end
driver:SetScript('OnEvent',OnEvent)
-- The target's auras (Frenzy) on a second frame, so the main driver's UNIT_AURA stays player and pet.
local targetDriver
-- Talent-gated warnings re-check once the shared talent ranks settle.
if NS.HunterTalents then
    NS.HunterTalents.OnChange(function()
        CheckPetFeed()
        if pendingCheck then return end
        pendingCheck=true
        C_Timer.After(0,Flush)
    end)
end
local AWAY_LIST={'PLAYER_DEAD','PLAYER_ALIVE','PLAYER_UNGHOST','PLAYER_CONTROL_LOST','PLAYER_CONTROL_GAINED',
    'PLAYER_MOUNT_DISPLAY_CHANGED','UNIT_ENTERED_VEHICLE','UNIT_EXITED_VEHICLE'}
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
local PASSIVE_EVENTS={'PLAYER_ENTERING_WORLD','UNIT_PET','PET_BAR_UPDATE','PET_UI_UPDATE','PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED',
    'PLAYER_MOUNT_DISPLAY_CHANGED','PLAYER_CONTROL_GAINED','PLAYER_CONTROL_LOST'}
local LEVEL_EVENTS={'PLAYER_ENTERING_WORLD','UNIT_PET','UNIT_LEVEL','PLAYER_LEVEL_UP','PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED'}
local function Valid(event)
    return not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(event)
end
-- Units per unit event (review R2-11): nothing else wakes the handler.
local UNITS={UNIT_AURA={'player','pet'},UNIT_HEALTH={'pet'},UNIT_MAXHEALTH={'pet'},UNIT_FLAGS={'player','pet'},UNIT_PET={'player'},
    UNIT_LEVEL={'pet'},UNIT_INVENTORY_CHANGED={'player'},UNIT_IN_RANGE_UPDATE={'pet'},UNIT_DISTANCE_CHECK_UPDATE={'pet'},
    UNIT_ENTERED_VEHICLE={'player'},UNIT_EXITED_VEHICLE={'player'}}
local function Register(frame,event,a,b)
    if not Valid(event) then return end
    if a and frame.RegisterUnitEvent then frame:RegisterUnitEvent(event,a,b) else frame:RegisterEvent(event) end
end
function NS.SyncEllesmereWarnings()
    local s=NS.EllesmereWarningSettings()
    driver:UnregisterAllEvents()
    if targetDriver then targetDriver:UnregisterAllEvents() end
    for k in pairs(totalCache) do totalCache[k]=nil end
    local class=PlayerClass()
    local ammoOn=s.ammo and (class=='HUNTER' or type(class)~='string') or s.ammoOthers==true and AMMO_CLASSES[class]==true
    for _,list in ipairs({ammoOn and AMMO_EVENTS or {},s.talents and TALENT_EVENTS or {},
        s.aspects and Hunter() and not (NS.AspectAdvisor and NS.AspectAdvisor.Enabled()) and ASPECT_EVENTS or {},(s.petHealth or s.petRange or s.petStatus) and PetClass() and PET_EVENTS or {},
        s.tranq and Hunter() and TRANQ_EVENTS or {},s.petFood and Hunter() and FOOD_EVENTS or {},
        s.petPassive==true and PetClass() and PASSIVE_EVENTS or {},s.petLevel==true and Hunter() and LEVEL_EVENTS or {},
        -- The centre lane follows combat even when only one warning is on.
        s.critical~=false and {'PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED'} or {},
        -- Cues under the away policy re-check on death, travel and vehicles (review R2-8).
        (ammoOn or s.petFood==true or s.petStatus or s.petPassive==true or s.petLevel==true) and AWAY_LIST or {}}) do
        for _,event in ipairs(list) do
            local u=UNITS[event]
            Register(driver,event,u and u[1],u and u[2])
        end
    end
    if s.tranq and Hunter() then
        if not targetDriver then targetDriver=CreateFrame('Frame');targetDriver:SetScript('OnEvent',OnEvent) end
        Register(targetDriver,'UNIT_AURA','target')
    end
    SyncPetFeed()
    NS.SyncEllesmereErrorRoutes() -- a route follows its cue's toggle
    if NS.EllesmereVividTextEnabled and NS.EllesmereVividTextEnabled() and not nativeWarningText and
        (not EllesmereUIDB or EllesmereUIDB.repairWarning~=false) then
        driver:RegisterEvent('UPDATE_INVENTORY_DURABILITY');driver:RegisterEvent('UPDATE_INVENTORY_ALERTS')
    end
    Flush()
    NS.SyncEllesmereNativeWarningOutline()
    NS.SyncEllesmereErrorText();NS.SyncEllesmereErrorFilter()
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
    if s.petPassive==true then Show('petPassive','Pet On Passive (Preview)',AMBER,true) end
    if s.petLevel==true then Show('petLevel','Pet Level 18 (4 Levels Below You) (Preview)',AMBER,true) end
    C_Timer.After(4,Flush)
end
-- The combat lane out of combat (review C5): act-now samples above the character for 4 s.
function NS.PreviewEllesmereCombatWarnings()
    previewToken=previewToken+1
    local token=previewToken
    previewCentre=true
    Show('ammo','Out of Ammo (Preview)',RED,nil,true)
    Show('petStatus','Revive Pet (Preview)',RED,true,true)
    Show('petPassive','Pet On Passive (Preview)',RED,nil,true)
    Layout()
    C_Timer.After(4,function()
        if token~=previewToken then return end
        previewCentre=false
        for _,row in pairs(rows) do row.warningPaint=nil end
        Flush();Layout()
    end)
end
-- One lane sample for one warning key (the eye on a single warning toggle).
local singleToken={}
function NS.PreviewEllesmereWarning(key,text,colour,critical,seconds)
    if type(key)~='string' or type(text)~='string' then return end
    singleToken[key]=(singleToken[key] or 0)+1
    local token=singleToken[key]
    Show(key,text..' (Preview)',type(colour)=='table' and colour or AMBER,true,critical)
    C_Timer.After(Number(seconds) and seconds or 3,function() if token==singleToken[key] then Hide(key);Flush() end end)
end
-- Keeps critical below low (audit F11): moving one past the other drags the other along.
function NS.SetEllesmereAmmoThreshold(key,v)
    local s=NS.EllesmereWarningSettings()
    local l=(key=='ammoLow' or key=='ammoCritical') and LIMITS[key]
    if not l or not Number(v) or v<l[1] or v>l[2] then return nil end
    v=math.floor(v)
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
    -- Rows by class (player: "warlocks have pets so some options are applicable"): hunters get
    -- every row, warlocks the pet rows that work for demons, other classes only the generic rows.
    -- An unreadable class shows everything.
    local class=PlayerClass()
    local unknown=type(class)~='string'
    local hunter=unknown or class=='HUNTER'
    local warlock=unknown or class=='WARLOCK'
    local petClass=hunter or warlock
    -- Ellesmere's row tools: thresholds in the cogs, positions behind the move arrows, the
    -- preview eye, and the lane colours as swatches.
    local ammo={type='toggle',text='Low Ammo Warning',tooltip='Warns below the low threshold out of combat, and always when nearly out, the ammo slot is empty or the ammo does not fit your weapon.',
        getValue=function() return s.ammo end,setValue=function(v) s.ammo=v; NS.SyncEllesmereWarnings() end}
    ammo.cog={title='Ammo Thresholds',disabled=function() return not s.ammo end,disabledTooltip='Low Ammo Warning',rows={
        {type='slider',label='Low Ammo Below',min=50,max=1000,step=50,get=function() return s.ammoLow end,set=function(v) NS.SetEllesmereAmmoThreshold('ammoLow',v) end},
        {type='slider',label='Critical Ammo At',min=0,max=200,step=10,get=function() return s.ammoCritical end,set=function(v) NS.SetEllesmereAmmoThreshold('ammoCritical',v) end}}}
    -- Each warning's lane and sound sit in its cog (review C3).
    local Lane=NS.AttachEllesmereWarningOverrides
    local function On(key) return function() return s[key]==true end end
    Lane(ammo,'ammo',On('ammo'))
    local talents=Lane({type='toggle',text='Unspent Talent Warning',tooltip='Shows out of combat while you have talent points to spend.',
        getValue=function() return s.talents end,setValue=function(v) s.talents=v; NS.SyncEllesmereWarnings() end},'talents',On('talents'))
    local mend={type='toggle',text='Mend Pet Reminder',tooltip='Warns below the pet health threshold; hides while Mend Pet is already active or the pet is out of range.',
        getValue=function() return s.petHealth end,setValue=function(v) s.petHealth=v;NS.SyncEllesmereWarnings() end}
    mend.cog={title='Mend Pet',disabled=function() return not (s.petHealth or s.petRange) end,disabledTooltip='Mend Pet Reminder or Pet Too Far To Mend',rows={
        {type='slider',label='Mend Pet At Health %',min=5,max=90,step=5,get=function() return s.petLow end,set=function(v) s.petLow=v;Flush() end}}}
    Lane(mend,'petHealth',On('petHealth'))
    -- The warlock version of Mend Pet: Health Funnel, same setting, no range check.
    local funnel={type='toggle',text='Health Funnel Reminder',tooltip='Warns below the demon health threshold while you know Health Funnel; hides while Health Funnel is already on your demon.',
        getValue=function() return s.petHealth end,setValue=function(v) s.petHealth=v;NS.SyncEllesmereWarnings() end}
    funnel.cog={title='Health Funnel',disabled=function() return not s.petHealth end,disabledTooltip='Health Funnel Reminder',rows={
        {type='slider',label='Health Funnel At Health %',min=5,max=90,step=5,get=function() return s.petLow end,set=function(v) s.petLow=v;Flush() end}}}
    Lane(funnel,'petHealth',On('petHealth'))
    local aspects=Lane({type='toggle',text='Cheetah / Pack Combat Warning',tooltip='Warns while either movement aspect is active in combat. When Aspect Element is enabled, its red edge shows this warning instead.',
        getValue=function() return s.aspects end,setValue=function(v) s.aspects=v;NS.SyncEllesmereWarnings() end},'aspects',On('aspects'))
    local status={type='toggle',text='Missing / Dead Pet In Combat',tooltip='Hunters: Call / Revive Pet when absent and Revive Pet when death is confirmed. Warlocks: Summon Demon. Quiet while you are dead, mounted, on a taxi or in a vehicle, for Lone Wolf, after Demonic Sacrifice, and when you play without a pet. The cog adds an out-of-combat reminder.',
        getValue=function() return s.petStatus end,setValue=function(v) s.petStatus=v;NS.SyncEllesmereWarnings() end}
    status.cog={title='Missing / Dead Pet',disabled=function() return not s.petStatus end,disabledTooltip='Missing / Dead Pet In Combat',rows={
        {type='toggle',label='Also Out Of Combat',tooltip='Out of combat too, in amber in the top lane. A missing pet waits 3 seconds first, so zoning and landing stay quiet.',
            get=function() return s.petStatusOOC==true end,set=function(v) s.petStatusOOC=v==true;NS.SyncEllesmereWarnings() end},
        {type='toggle',label='I Play Without A Pet',tooltip='Never asks for a pet. Lone Wolf hunters and a warlock\'s Demonic Sacrifice are detected without this.',
            get=function() return s.noPet==true end,set=function(v) s.noPet=v==true;NS.SyncEllesmereWarnings() end}}}
    Lane(status,'petStatus',On('petStatus'))
    local range=Lane({type='toggle',text='Pet Too Far To Mend',tooltip='Warns only when your pet is below the Mend Pet health threshold and out of Mend Pet range. Distance alone stays quiet.',
        getValue=function() return s.petRange end,setValue=function(v) s.petRange=v;NS.SyncEllesmereWarnings() end},'petRange',On('petRange'))
    -- Pet On Passive and Pet Level (reviews H3, H6).
    local passive={type='toggle',text='Pet On Passive Warning',tooltip='Hunter and warlock pets: red above your character while your pet is set to Passive in combat. The cog adds an out-of-combat reminder.',
        getValue=function() return s.petPassive==true end,setValue=function(v) s.petPassive=v==true;NS.SyncEllesmereWarnings() end}
    passive.cog={title='Pet On Passive',disabled=function() return s.petPassive~=true end,disabledTooltip='Pet On Passive Warning',rows={
        {type='toggle',label='Also Out Of Combat',get=function() return s.petPassiveOOC==true end,set=function(v) s.petPassiveOOC=v==true;NS.SyncEllesmereWarnings() end}}}
    passive.preview={tip='Preview the warning',duration=3,disabled=function() return s.petPassive~=true end,disabledTooltip='Pet On Passive Warning',
        show=function() NS.PreviewEllesmereWarning('petPassive','Pet On Passive',AMBER,false,3) end}
    Lane(passive,'petPassive',On('petPassive'))
    local level={type='toggle',text='Pet Level Warning',tooltip='Out of combat: your pet is the set number of levels or more below you. A pet far behind earns less experience and holds threat poorly.',
        getValue=function() return s.petLevel==true end,setValue=function(v) s.petLevel=v==true;NS.SyncEllesmereWarnings() end}
    level.cog={title='Pet Level',disabled=function() return s.petLevel~=true end,disabledTooltip='Pet Level Warning',rows={
        {type='slider',label='Levels Below You',min=1,max=10,step=1,get=function() return s.petLevelGap end,
            set=function(v) if Number(v) and v>=1 and v<=10 then s.petLevelGap=math.floor(v);Flush() end end}}}
    level.preview={tip='Preview the warning',duration=3,disabled=function() return s.petLevel~=true end,disabledTooltip='Pet Level Warning',
        show=function() NS.PreviewEllesmereWarning('petLevel','Pet Level 18 (4 Levels Below You)',AMBER,false,3) end}
    Lane(level,'petLevel',On('petLevel'))
    local feed=Lane({type='toggle',text='Feed Pet Reminder',tooltip='Out of combat: amber for a content pet and red for an unhappy pet. Quiet for Lone Wolf, missing/dead pets, travel, and unreadable happiness.',
        getValue=function() return s.feed==true end,setValue=function(v) s.feed=v;NS.SyncEllesmereWarnings() end},'feed',On('feed'))
    local content={type='toggle',text='Remind When Content',getValue=function() return s.feedContent==true end,setValue=function(v) s.feedContent=v;NS.SyncEllesmereWarnings() end,
        disabled=function() return s.feed~=true end,disabledTooltip='Feed Pet Reminder'}
    local food={type='toggle',text='Pet Food Warning',tooltip='Out of combat: No Pet Food when nothing in your bags is food your pet eats, Low Pet Food below the amount you set.',
        getValue=function() return s.petFood==true end,setValue=function(v) s.petFood=v;NS.SyncEllesmereWarnings() end}
    food.cog={title='Pet Food Warning',disabled=function() return s.petFood~=true end,disabledTooltip='Pet Food Warning',rows={
        {type='slider',label='Low Pet Food Below',min=0,max=60,step=5,get=function() return s.petFoodLow end,set=function(v) s.petFoodLow=v;Flush() end}}}
    Lane(food,'petFood',On('petFood'))
    local tranq=Lane({type='toggle',text='Frenzy: Tranquilizing Shot',tooltip='In combat, warns when your enemy target has a Frenzy effect. Quiet until you know Tranquilizing Shot.',
        getValue=function() return s.tranq end,setValue=function(v) s.tranq=v;NS.SyncEllesmereWarnings() end},'tranq',On('tranq'))
    -- The class's rows, in order, paired two per line (a hunter keeps the original pairs).
    local list={}
    local function Add(on,cfg) if on then list[#list+1]=cfg end end
    -- Warriors and rogues: their own ammo switch, off by default (review S11).
    local ammoOther={type='toggle',text='Low Ammo Warning',tooltip='For a stat bow, gun or crossbow: low ammo out of combat only, once you have carried that ammo this session. Never above your character.',
        getValue=function() return s.ammoOthers==true end,setValue=function(v) s.ammoOthers=v==true;NS.SyncEllesmereWarnings() end}
    Add(not hunter and AMMO_CLASSES[class]==true,Lane(ammoOther,'ammo',On('ammoOthers')))
    Add(hunter,ammo);Add(true,talents);Add(hunter,aspects);Add(hunter,mend)
    Add(warlock and not hunter,funnel);Add(hunter,range);Add(petClass,status);Add(petClass,passive);Add(hunter,level)
    Add(hunter,feed);Add(hunter,content);Add(hunter,food);Add(hunter,tranq)
    for i=1,#list,2 do Row(list[i],list[i+1] or (EUI.BlankRowCfg and EUI.BlankRowCfg()) or {type='label',text=''}) end
    if unknown then Row(funnel,EUI.BlankRowCfg and EUI.BlankRowCfg() or {type='label',text=''}) end
    Row({type='toggle',text='Hide Spam Errors',tooltip='Hides "Spell is not ready yet", "Ability is not ready yet", "Out of range" and "Not enough mana" and their voice lines, like retail does. Errors that need an action still show in red.',
        getValue=function() return s.errorFilter end,setValue=function(v) s.errorFilter=v;NS.SyncEllesmereErrorFilter() end},
        {type='toggle',text='Hide Errors A Warning Shows',tooltip='Hides the red error line when a warning already shows the same problem: Target too close (range indicator), facing (Face Target), out of ammo (ammo warning) and a dead pet (pet warning).',
        getValue=function() return s.errorRoute==true end,setValue=function(v) s.errorRoute=v;NS.SyncEllesmereErrorRoutes() end})
    local lane={type='toggle',text='Top Alert Lane',tooltip='Moves the red game error line (Out of range, No target) to the top of the screen, large, in the warning font, with these warnings directly beneath it. Off restores the native error line and puts warnings back under Low Durability.',
        getValue=function() return s.errorRaise end,setValue=function(v) s.errorRaise=v;NS.SyncEllesmereErrorText() end}
    lane.move={title='Top Alert Lane Position',disabled=function() return not s.errorRaise end,disabledTooltip='Top Alert Lane',rows={
        {type='slider',label='Distance From Top',min=20,max=400,step=10,get=function() return s.errorY end,set=function(v) s.errorY=v;NS.SyncEllesmereErrorText() end},
        {type='slider',label='Horizontal Offset',min=-800,max=800,step=10,get=function() return s.errorX end,set=function(v) s.errorX=v;NS.SyncEllesmereErrorText() end}}}
    lane.preview={tip='Preview warnings',show=function() NS.PreviewEllesmereWarnings() end,duration=4}
    local above={type='toggle',text='Combat Warnings Above Character',tooltip='In combat, warnings that need an action now (pet health, dead pet, out of ammo, Frenzy, unsafe aspect) move above your character. Information stays in the top lane.',
        getValue=function() return s.critical end,setValue=function(v) s.critical=v;NS.SyncEllesmereWarnings() end}
    above.move={title='Combat Warning Position',disabled=function() return not s.critical end,disabledTooltip='Combat Warnings Above Character',rows={
        {type='slider',label='Height Above Character',min=60,max=300,step=10,get=function() return s.criticalY end,set=function(v) s.criticalY=v;Layout() end},
        {type='slider',label='Horizontal Offset',min=-800,max=800,step=10,get=function() return s.criticalX end,set=function(v) s.criticalX=v;Layout() end}}}
    above.preview={tip='Preview the combat lane',show=function() NS.PreviewEllesmereCombatWarnings() end,duration=4,
        disabled=function() return s.critical==false end,disabledTooltip='Combat Warnings Above Character'}
    Row(lane,above)
    local function Restyle() NS.SyncEllesmereErrorText();for _,row in pairs(rows) do row.warningPaint=nil end;NS.SyncEllesmereWarnings() end
    local style={type='toggle',text='Warning Text Style',
        tooltip='On: warnings, the game error line and the combat lane use the size and outline set in the cog. Off: they follow Ellesmere\'s Low Durability warning text (Quality of Life).',
        getValue=function() return s.textCustom==true end,setValue=function(v) s.textCustom=v;Restyle() end}
    style.cog={title='Warning Text',disabled=function() return s.textCustom~=true end,disabledTooltip='Warning Text Style',rows={
        {type='slider',label='Text Size',min=12,max=48,step=1,get=function() return s.textSize end,set=function(v) s.textSize=v;Restyle() end},
        {type='slider',label='Combat Warning Size',min=12,max=40,step=1,get=function() return s.combatTextSize end,set=function(v) s.combatTextSize=v;Restyle() end},
        {type='dropdown',label='Outline',values={native='Theme Outline',outline='Outline',thick='Thick Outline',none='None'},order={'native','outline','thick','none'},
            get=function() return s.textOutline end,set=function(v) s.textOutline=v;Restyle() end}}}
    style.preview={tip='Preview warnings',show=function() NS.PreviewEllesmereWarnings() end,duration=4}
    Row(style,{type='label',text='Move both lanes in Unlock Mode: Quality of Life'})
    -- Our sounds plus Ellesmere's alert catalogue (review C3).
    local soundValues,soundOrder=SoundChoices()
    soundValues.default=nil;table.remove(soundOrder,1)
    Row({type='dropdown',text='Act-Now Warning Sound',values=soundValues,order=soundOrder,
        tooltip='Plays when a red or above-the-character warning appears (out of ammo, dead pet, Stop Attack...).',
        getValue=function() return s.dangerSound end,setValue=function(v) s.dangerSound=v;Sound('preview',true) end},
        {type='dropdown',text='Other Warning Sound',values=soundValues,order=soundOrder,
        tooltip='Plays when any other warning appears.',
        getValue=function() return s.warnSound end,setValue=function(v) s.warnSound=v;Sound('preview2',false) end})
    if NS.EllesmereColorSwatch then
        Row({type='multiSwatch',text='Warning Colors',tooltip='Act-Now (red: out of ammo, dead pet, Stop Attack, Feign Death) and Caution (amber: low ammo, feed pet, low pet food, the dead-zone approach).',
            swatches={NS.EllesmereColorSwatch('alert','Act-Now Warning Color'),NS.EllesmereColorSwatch('caution','Caution Warning Color')}},
            NS.EllesmereResetColors({'alert','caution'},'Reset Warning Colors'))
    end
end

-- Unlock Mode movers (player, 2026-10-06: "is it movable on the screen"). Each lane keeps one
-- stored form, offsets from the top of the screen / its centre point, so the cog sliders and the
-- mover always agree.
local laneProxy,combatProxy
local function Proxy()
    local p=CreateFrame('Frame',nil,UIParent);p:SetSize(500,40);p:EnableMouse(false);return p
end
local function PlaceLaneProxy()
    laneProxy=laneProxy or Proxy()
    laneProxy:ClearAllPoints();laneProxy:SetPoint('TOP',UIParent,'TOP',ErrorX(),-ErrorTop())
    laneProxy:SetHeight(ErrorSize()+8+WarnSize()+10)
end
local function PlaceCombatProxy()
    combatProxy=combatProxy or Proxy()
    local s=NS.EllesmereWarningSettings()
    combatProxy:ClearAllPoints();combatProxy:SetPoint('BOTTOM',UIParent,'CENTER',Number(s.criticalX) and s.criticalX or 0,CombatY())
    combatProxy:SetHeight(CentreSize()+10)
end
local function Offsets(frame,point,relPoint,x,y)
    frame:ClearAllPoints();frame:SetPoint(point,UIParent,relPoint,x,y)
    local l,b,w,h=frame:GetRect()
    local pl,pb,pw,ph=UIParent:GetRect()
    if not (Number(l) and Number(b) and Number(w) and Number(h) and Number(pw) and Number(ph)) then return end
    return math.floor(l+w/2-(pl+pw/2)+.5),b,h,pb,ph
end
local function RegisterMovers()
    if not (EUI.MakeUnlockElement and EUI.RegisterUnlockElements) then return end
    PlaceLaneProxy();PlaceCombatProxy()
    EUI:RegisterUnlockElements({
        EUI.MakeUnlockElement({key='FHKEllesmereAlertLane',label='Top Alert Lane',group='Quality of Life',order=905,noResize=true,
            getFrame=function() PlaceLaneProxy();return laneProxy end,getSize=function() return laneProxy:GetWidth(),laneProxy:GetHeight() end,
            isHidden=function() return NS.EllesmereWarningSettings().errorRaise~=true end,
            savePos=function(_,point,relPoint,x,y)
                if not (Text(point) and Text(relPoint) and Number(x) and Number(y)) then return end
                local cx,b,h,pb,ph=Offsets(laneProxy,point,relPoint,x,y)
                if not cx then return end
                local s=NS.EllesmereWarningSettings()
                s.errorX=cx;s.errorY=math.max(0,math.floor(pb+ph-(b+h)+.5))
                NS.SyncEllesmereErrorText();PlaceLaneProxy()
            end,
            loadPos=function() return {point='TOP',relPoint='TOP',x=ErrorX(),y=-ErrorTop()} end,
            clearPos=function() local s=NS.EllesmereWarningSettings();s.errorX,s.errorY=0,110;NS.SyncEllesmereErrorText();PlaceLaneProxy() end,
            applyPos=PlaceLaneProxy}),
        EUI.MakeUnlockElement({key='FHKEllesmereCombatWarnings',label='Combat Warnings',group='Quality of Life',order=906,noResize=true,
            getFrame=function() PlaceCombatProxy();return combatProxy end,getSize=function() return combatProxy:GetWidth(),combatProxy:GetHeight() end,
            isHidden=function() return NS.EllesmereWarningSettings().critical==false end,
            savePos=function(_,point,relPoint,x,y)
                if not (Text(point) and Text(relPoint) and Number(x) and Number(y)) then return end
                local cx,b,_,pb,ph=Offsets(combatProxy,point,relPoint,x,y)
                if not cx then return end
                local s=NS.EllesmereWarningSettings()
                s.criticalX=cx;s.criticalY=math.floor(b-(pb+ph/2)+.5)
                Layout();PlaceCombatProxy()
            end,
            loadPos=function() local s=NS.EllesmereWarningSettings();return {point='BOTTOM',relPoint='CENTER',x=s.criticalX or 0,y=CombatY()} end,
            clearPos=function() local s=NS.EllesmereWarningSettings();s.criticalX,s.criticalY=0,150;Layout();PlaceCombatProxy() end,
            applyPos=PlaceCombatProxy})},'FHKEllesmere')
end
NS.RegisterEllesmereWarningMovers=RegisterMovers

local boot=CreateFrame('Frame')
boot:RegisterEvent('PLAYER_LOGIN')
boot:SetScript('OnEvent',function(self)
    self:UnregisterAllEvents(); NS.SyncEllesmereWarnings(); NS.SyncEllesmereErrorText(); NS.SyncEllesmereErrorFilter()
    RegisterMovers()
end)
