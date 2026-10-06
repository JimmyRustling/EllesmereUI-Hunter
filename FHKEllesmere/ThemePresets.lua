-- Reversible colour presets using native Ellesmere palettes and class accents.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS or not EUI.IS_FOREVER then return end

local driver=CreateFrame('Frame')
local trim=setmetatable({},{__mode='k'})
local pending,applying,pendingXP
local SyncEvents
local function Copy(v)
    if type(v)~='table' then return v end
    local out={};for k,x in pairs(v) do out[k]=Copy(x) end;return out
end
local function ProfileName() return EllesmereUIDB and EllesmereUIDB.activeProfile or 'Default' end
local function State(write)
    local name=ProfileName()
    if write then
        if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end
        FHKEllesmereDB.themePresets=FHKEllesmereDB.themePresets or {}
        local presets=FHKEllesmereDB.themePresets
        presets[name]=presets[name] or {}
        if NS.EllesmereStampSnapshot then NS.EllesmereStampSnapshot('themePresets',name) end
        return presets[name]
    end
    return FHKEllesmereDB and FHKEllesmereDB.themePresets and FHKEllesmereDB.themePresets[name]
end
local function RGB(hex)
    return {r=tonumber(hex:sub(1,2),16)/255,g=tonumber(hex:sub(3,4),16)/255,b=tonumber(hex:sub(5,6),16)/255}
end
local CLASS_HEX={WARRIOR='D9A078',PALADIN='F3A9C8',HUNTER='B5E66A',ROGUE='F0D77A',
    PRIEST='E9E5F4',SHAMAN='66AEFF',MAGE='79DDE8',WARLOCK='B79CFF',DRUID='EAA06A'}
local POWER_HEX={MANA='62A8F8',RAGE='E97567',ENERGY='F0D77A',FOCUS='DFA35C'}
local RB_FIELDS={primary={'darkTheme','customColored','bgR','bgG','bgB','bgA'},
    secondary={'darkTheme','classColored','resourceColored','bgR','bgG','bgB','bgA','barBgR','barBgG','barBgB','barBgA'}}
local RAID_FIELDS={'healthColorMode','party_healthColorMode','partyTargetHealthColorMode',
    '_darkPrevHealthColorMode','_darkPrevPartyHealthColorMode','_darkPrevPartyTargetHealthColorMode'}
local VIVID_VERSION=4 -- 2: 3 : 1 fills, lifted hostile red; 3: one gold; 4: WoW gold (re-applies Colored once)
local XP_VERSION=1
local CAST_VERSION=2 -- 1: your cast bar is rose; 2: enemy cast states share the palette
local XP_FIELDS={'colorMode','customColor','restedColor'}
local function XPProfile()
    local ab=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIActionBars
    local p=ab and ab.EAB and ab.EAB.db and ab.EAB.db.profile
    return p and p.bars and p.bars.XPBar,ab
end
local function CaptureXP()
    local p=XPProfile()
    if not p then return end
    local saved={}
    for _,key in ipairs(XP_FIELDS) do saved[key]=Copy(p[key]) end
    return saved
end
local function ApplyXPColours()
    local p=XPProfile()
    if not p then return false end
    local C=NS.Colours or {}
    local function Fill(c)
        local r,g,b=unpack(c)
        if NS.EllesmereReadableBarFill then r,g,b=NS.EllesmereReadableBarFill(r,g,b) end
        return {r=r,g=g,b=b}
    end
    p.colorMode='custom'
    p.customColor=Fill(C.xpFill or {118/255,45/255,178/255})
    p.restedColor=Fill(C.xpRestedFill or {20/255,110/255,134/255})
    p.restedColor.a=1
    return true
end
local function ResourceProfile()
    local ns=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIResourceBars
    return ns and ns.ERB and ns.ERB.db and ns.ERB.db.profile,ns
end
-- Reaction fills (who a unit is) live in the unit-frame and nameplate profiles.
local function UnitFrameProfile()
    local uf=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIUnitFrames
    return uf and uf.db and uf.db.profile,uf
end
-- Your own cast bar carries the rose cast colour; enemy cast bars stay neutral,
-- so rose only ever means "you are casting".
local function CapturePlayerCast()
    local ufp=UnitFrameProfile()
    local p=ufp and ufp.player
    if not p then return nil end
    return {fill=Copy(p.castbarFillColor),class=p.castbarClassColored}
end
local function ApplyPlayerCast()
    local ufp=UnitFrameProfile()
    local p=ufp and ufp.player
    if not p then return false end
    local c=NS.Colours and NS.Colours.castFill or {254/255,81/255,164/255}
    p.castbarFillColor={r=c[1],g=c[2],b=c[3]};p.castbarClassColored=false
    return true
end
-- Enemy cast states speak the same language as the rest of the UI (player:
-- "the cast bar has colours for uninterruptible and interruptible"):
--   normal cast      tan     #9A8660  calm; violet meant melee on the same plate
--   interrupt ready  gold    #C5A100  act now (also when it comes ready mid-cast)
--   not interruptible slate  #575C68  nothing to act on: quiet
--   important        red     #FF4D40  danger, apart from the hostile health fill
--   interrupted      white   #F2F2F5  a result, not a danger
local CAST_STATES={tan={r=.604,g=.525,b=.376},gold={r=.772,g=.632,b=0},slate={r=.341,g=.361,b=.408},
    danger={r=1,g=.3,b=.25},flash={r=.949,g=.949,b=.961}}
local UF_CAST_UNITS={'target','focus','boss'}
local UF_CAST={castbarFillColor='tan',castbarInterruptReadyColor='gold',castbarInterruptMidCastColor='gold',
    castbarUninterruptibleColor='slate',castbarImportantGlowColor='danger'}
local NP_CAST={castBar='tan',interruptReady='gold',interruptMidCastColor='gold',castBarUninterruptible='slate',
    castBarImportant='danger',importantCastGlowColor='danger',interruptedFlashColor='flash'}
local function PlateProfile()
    local np=_G.EllesmereNameplates_NS
    return np and np.db and np.db.profile,np
end
local PLATE_REACTION={'hostile','neutral','tapped'}
local function CaptureCastStates()
    local saved={uf={},np={}}
    local ufp=UnitFrameProfile()
    for _,unit in ipairs(UF_CAST_UNITS) do
        local p=ufp and ufp[unit]
        -- rawget (review T8): AceDB defaults must stay defaults after a Restore.
        if p then saved.uf[unit]={};for key in pairs(UF_CAST) do saved.uf[unit][key]=Copy(rawget(p,key)) end end
    end
    local npp=PlateProfile()
    if npp then for key in pairs(NP_CAST) do saved.np[key]=Copy(rawget(npp,key)) end end
    return saved
end
local function ApplyCastStates()
    local ufp=UnitFrameProfile()
    for _,unit in ipairs(UF_CAST_UNITS) do
        local p=ufp and ufp[unit]
        if p then for key,state in pairs(UF_CAST) do p[key]=Copy(CAST_STATES[state]) end end
    end
    local npp=PlateProfile()
    if npp then for key,state in pairs(NP_CAST) do npp[key]=Copy(CAST_STATES[state]) end end
end
local function RestoreCastStates(saved)
    if type(saved)~='table' then return end
    local ufp=UnitFrameProfile()
    for unit,fields in pairs(saved.uf or {}) do
        local p=ufp and ufp[unit]
        if p then for key in pairs(UF_CAST) do p[key]=Copy(fields[key]) end end
    end
    local npp=PlateProfile()
    if npp and saved.np then for key in pairs(NP_CAST) do npp[key]=Copy(saved.np[key]) end end
end
local function NativeColors()
    return EUI.GetCustomColorsDB and EUI.GetCustomColorsDB()
end
local function Replace(target,source)
    if type(target)~='table' then return end
    for key in pairs(target) do target[key]=nil end
    for key,value in pairs(source or {}) do target[key]=Copy(value) end
end
-- Player edits made after a preset (review T1): a key whose value differs from what the preset
-- wrote is the player's, and survives a switch to another preset. Restore Original Look and a
-- version migration re-apply keep no edits.
local NONE={} -- transient sentinel: the player cleared this key
local function Same(a,b)
    if type(a)~='table' or type(b)~='table' then return a==b end
    for k,v in pairs(a) do if not Same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function Edits(current,applied)
    local out={}
    if type(current)~='table' or type(applied)~='table' then return out end
    for k,v in pairs(current) do if not Same(v,applied[k]) then out[k]=Copy(v) end end
    for k in pairs(applied) do if current[k]==nil then out[k]=NONE end end
    return out
end
local function Reapply(target,edits)
    if type(target)~='table' or type(edits)~='table' then return end
    for k,v in pairs(edits) do if v==NONE then target[k]=nil else target[k]=Copy(v) end end
end
local function DarkStates()
    local out={}
    for _,provider in ipairs(EUI._darkModeToggles or {}) do
        if provider.id then
            local ok,on=pcall(provider.isOn)
            if ok and not (issecretvalue and issecretvalue(on)) then out[provider.id]=on==true end
        end
    end
    return out
end
local function Capture()
    local data=EUI.GetActiveProfileData and EUI.GetActiveProfileData()
    local saved={colors=Copy(NativeColors()),dark=Copy(EUI.GetDarkModeDB()),
        accent=Copy(data and data.euiAccent),panel=EllesmereUIDB and EllesmereUIDB.activeTheme,
        flags=DarkStates(),resources={},xp=CaptureXP()}
    local ufp=UnitFrameProfile()
    if ufp then saved.enemyColors=Copy(ufp.enemyColors);saved.playerCast=CapturePlayerCast() end
    local npp=PlateProfile()
    saved.casts=CaptureCastStates()
    if npp then
        saved.plate={}
        for _,key in ipairs(PLATE_REACTION) do saved.plate[key]=Copy(rawget(npp,key)) end
    end
    local raid=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIRaidFrames
    if raid and raid.db and raid.db.profile then
        saved.raid={}
        for _,key in ipairs(RAID_FIELDS) do saved.raid[key]=Copy(raid.db.profile[key]) end
    end
    local p=ResourceProfile()
    for kind,fields in pairs(RB_FIELDS) do
        if p and p[kind] then
            local values={};saved.resources[kind]=values
            for _,key in ipairs(fields) do values[key]=Copy(p[kind][key]) end
        end
    end
    return saved
end
local function Restore(saved)
    Replace(NativeColors(),saved.colors)
    Replace(EUI.GetDarkModeDB(),saved.dark)
    local data=EUI.GetActiveProfileData and EUI.GetActiveProfileData()
    if data then data.euiAccent=Copy(saved.accent) end
    local xp=XPProfile()
    if xp and saved.xp then
        for _,key in ipairs(XP_FIELDS) do xp[key]=Copy(saved.xp[key]) end
    end
    -- A toggle registered after the backup was taken was off then (review T4).
    for _,provider in ipairs(EUI._darkModeToggles or {}) do
        if provider.id and type(saved.flags)=='table' then provider.setOn(saved.flags[provider.id]==true) end
    end
    local raid=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIRaidFrames
    if saved.raid and raid and raid.db and raid.db.profile then
        for _,key in ipairs(RAID_FIELDS) do raid.db.profile[key]=Copy(saved.raid[key]) end
        if raid.ReloadFrames then raid.ReloadFrames() end
        if raid.ReloadPartyFrames then raid.ReloadPartyFrames() end
    end
    local p=ResourceProfile()
    for kind,fields in pairs(RB_FIELDS) do
        if p and p[kind] and saved.resources[kind] then
            for _,key in ipairs(fields) do p[kind][key]=Copy(saved.resources[kind][key]) end
        end
    end
    local ufp,uf=UnitFrameProfile()
    if ufp and ufp.player and saved.playerCast then
        ufp.player.castbarFillColor=Copy(saved.playerCast.fill);ufp.player.castbarClassColored=saved.playerCast.class
    end
    if ufp and saved.enemyColors~=nil then
        ufp.enemyColors=Copy(saved.enemyColors)
        if uf.ApplyEnemyColors then uf.ApplyEnemyColors() end
    end
    local npp=PlateProfile()
    RestoreCastStates(saved.casts)
    if npp and saved.plate then
        for _,key in ipairs(PLATE_REACTION) do npp[key]=Copy(saved.plate[key]) end
    end
    if EUI.SetActiveTheme then EUI.SetActiveTheme(saved.panel or EUI.DEFAULT_THEME) end
end
-- Coloured preset (player review): reaction fills were pale (neutral cream under
-- white text). Deep WoW red / olive gold / green, matching the health fills.
local function ApplyReactionFills()
    local C=NS.Colours or {}
    local function Swatch(c,fallback) c=c or fallback; return {r=c[1],g=c[2],b=c[3]} end
    local hostile=Swatch(C.reactionHostile,{.784,.188,.165})
    local neutral=Swatch(C.reactionNeutral,{.772,.632,0})
    local friendly=Swatch(C.reactionFriendly,{.20,.55,.22})
    local tapped=Swatch(C.reactionTapped,{.42,.42,.42})
    local ufp,uf=UnitFrameProfile()
    if ufp then
        ufp.enemyColors={hostile=hostile,neutral=neutral,friendly=friendly,tapped=tapped}
        if uf.ApplyEnemyColors then uf.ApplyEnemyColors() end
    end
    local npp,np=PlateProfile()
    if npp then
        npp.hostile,npp.neutral,npp.tapped=Copy(hostile),Copy(neutral),Copy(tapped)
        if np.RefreshAllSettings then np.RefreshAllSettings() end
    end
end
local function IsAfterglow()
    local s=State();return s and s.active=='afterglow'
end
local function Public(v) return not (issecretvalue and issecretvalue(v)) end
local function PaintTrim()
    if not IsAfterglow() then
        for _,edges in pairs(trim) do edges[1]:Hide();edges[2]:Hide() end
        return
    end
    local uf=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIUnitFrames
    for _,frame in pairs(uf and uf.frames or {}) do
        if (type(frame)=='table' or type(frame)=='userdata') and frame.Health and frame.Health.CreateTexture then
            local unit=frame._euiUnit or frame._euiBaseUnit
            local class
            if Public(unit) and unit and UnitClass then local _,token=UnitClass(unit);if Public(token) then class=token end end
            local edges=trim[frame.Health]
            if not edges and not InCombatLockdown() then
                edges={frame.Health:CreateTexture(nil,'OVERLAY'),frame.Health:CreateTexture(nil,'OVERLAY')}
                trim[frame.Health]=edges
                for i,edge in ipairs(edges) do
                    local side=i==1 and 'TOP' or 'BOTTOM'
                    if EUI.PP and EUI.PP.Point then
                        EUI.PP.Point(edge,side..'LEFT',frame.Health,side..'LEFT',0,0)
                        EUI.PP.Point(edge,side..'RIGHT',frame.Health,side..'RIGHT',0,0)
                    else
                        edge:SetPoint(side..'LEFT',frame.Health,side..'LEFT',0,0)
                        edge:SetPoint(side..'RIGHT',frame.Health,side..'RIGHT',0,0)
                    end
                    if EUI.PP and EUI.PP.Height then EUI.PP.Height(edge,1) else edge:SetHeight(1) end
                end
            end
            if edges then
                local color=EUI.GetClassColor and class and EUI.GetClassColor(class)
                local r,g,b=EUI.GetAccentColor()
                if color then r,g,b=color.r,color.g,color.b end
                edges[1]:SetColorTexture(r,g,b,.55);edges[2]:SetColorTexture(r,g,b,.22)
                edges[1]:Show();edges[2]:Show()
            end
        end
    end
end
local function Refresh()
    local _,uf=UnitFrameProfile()
    if uf and uf.ReloadFrames then uf.ReloadFrames() end
    -- Plates repaint on every preset change, Restore included (review T7).
    local _,np=PlateProfile()
    if np and np.RefreshAllSettings then pcall(np.RefreshAllSettings) end
    if EUI.RefreshDarkMode then EUI.RefreshDarkMode() end
    if EUI.RefreshAccent then EUI.RefreshAccent() end
    local _,rb=ResourceProfile()
    if rb and rb.ERB.ApplyAll then rb.ERB:ApplyAll() end
    PaintTrim()
    SyncEvents()
    if NS.SyncEllesmereCueText then NS.SyncEllesmereCueText() end
    if NS.SyncEllesmereUnitRefinements then NS.SyncEllesmereUnitRefinements() end
    if NS.PaintEllesmereResourceBars then NS.PaintEllesmereResourceBars() end
    local _,ab=XPProfile()
    if ab and ab.ApplyDataBarLayout then ab.ApplyDataBarLayout('XPBar') end
    if NS.SyncEllesmereXPBar then NS.SyncEllesmereXPBar() end
end
local function Dark(on,resources)
    for _,provider in ipairs(EUI._darkModeToggles or {}) do
        local enabled=on
        if provider.id=='resourceBars' then enabled=resources end
        provider.setOn(enabled)
    end
    local p=ResourceProfile()
    if p then
        if p.primary then p.primary.darkTheme=resources end
        if p.secondary then p.secondary.darkTheme=resources end
    end
end
local function ApplyPalette()
    local cc=NativeColors()
    cc.class,cc.power,cc.classResource,cc.resource=cc.class or {},cc.power or {},cc.classResource or {},cc.resource or {}
    for class,hex in pairs(CLASS_HEX) do cc.class[class]=RGB(hex);cc.resource[class]=RGB(hex) end
    for key,hex in pairs(POWER_HEX) do cc.power[key]=RGB(hex) end
    cc.classResource.ComboPoints=RGB('F0D77A');cc.classResource.SoulShards=RGB('B79CFF')
    local d=EUI.GetDarkModeDB()
    -- Health: ink fill over a lighter slate for missing health. Native Dark is
    -- #111111 on #4F4F4F (2.3:1); keep at least that step so remaining health reads.
    -- Resources keep the deeper ink-slate backing so coloured fills stand out.
    local fill,missing,bg=RGB('12141D'),RGB('4A5470'),RGB('202638')
    d.fillR,d.fillG,d.fillB,d.fillA=fill.r,fill.g,fill.b,1
    d.bgR,d.bgG,d.bgB,d.bgA=missing.r,missing.g,missing.b,1
    d.classDarken,d.powerDarken,d.resourceDarken,d.powerBgDarken=0,0,0,0
    local p=ResourceProfile()
    if p then
        for _,kind in ipairs({'primary','secondary'}) do
            local c=p[kind]
            if c then c.bgR,c.bgG,c.bgB,c.bgA=bg.r,bg.g,bg.b,.9 end
        end
        if p.primary then p.primary.customColored=false end
        if p.secondary then
            p.secondary.classColored,p.secondary.resourceColored=false,true
            p.secondary.barBgR,p.secondary.barBgG,p.secondary.barBgB,p.secondary.barBgA=fill.r,fill.g,fill.b,.9
        end
    end
    local _,class=UnitClass('player')
    local color=(Public(class) and cc.class[class]) or RGB('79DDE8')
    EUI.SetAccentColor(color.r,color.g,color.b)
    if EUI.SetActiveTheme then EUI.SetActiveTheme('Pixels') end
end
local function ApplyVividPalette()
    local cc=NativeColors()
    cc.class,cc.power,cc.classResource,cc.resource=cc.class or {},cc.power or {},cc.classResource or {},cc.resource or {}
    -- Classes use WoW's own class colours (player: "for classes just use the wow
    -- class colour, let's simplify things"): the preset leaves class colours as
    -- the profile had them, which is Ellesmere's WoW default unless you chose one.
    -- Power colours are labelled fills. Text/lines brighten the same hue.
    for kind,pair in pairs(NS.EllesmereVividPowerPalette or {}) do cc.power[kind]=RGB(pair.fill) end
    local d=EUI.GetDarkModeDB()
    d.classDarken,d.powerDarken,d.resourceDarken=0,0,0
    local p=ResourceProfile()
    if p and p.primary then p.primary.customColored=false end
    local _,class=UnitClass('player')
    local c=Public(class) and (cc.class[class] or EUI.CLASS_COLOR_MAP and EUI.CLASS_COLOR_MAP[class])
    if c then EUI.SetAccentColor(c.r,c.g,c.b) end
end
-- Our earlier vivid class colours, recognised exactly so only they are removed.
local function Ours(c,hex)
    return type(c)=='table' and type(hex)=='string' and math.abs((c.r or -1)-tonumber(hex:sub(1,2),16)/255)<.002 and
        math.abs((c.g or -1)-tonumber(hex:sub(3,4),16)/255)<.002 and math.abs((c.b or -1)-tonumber(hex:sub(5,6),16)/255)<.002
end
local function ReturnClassColours()
    local cc=NativeColors()
    if not cc then return false end
    for class,pair in pairs(NS.EllesmereVividClassPalette or {}) do
        if cc.class and Ours(cc.class[class],pair.accent) then cc.class[class]=nil end
        if cc.resource then
            for _,hex in ipairs({pair.fill,pair.oldFill}) do if Ours(cc.resource[class],hex) then cc.resource[class]=nil end end
        end
    end
    local rogue,warlock=NS.EllesmereVividClassPalette and NS.EllesmereVividClassPalette.ROGUE,
        NS.EllesmereVividClassPalette and NS.EllesmereVividClassPalette.WARLOCK
    if cc.classResource then
        if rogue and Ours(cc.classResource.ComboPoints,rogue.accent) then cc.classResource.ComboPoints=nil end
        if warlock and Ours(cc.classResource.SoulShards,warlock.accent) then cc.classResource.SoulShards=nil end
    end
    EUI._colorCacheDirty=true
    return true
end
function NS.EllesmereVividFillEnabled()
    return NS.GetEllesmereThemePreset()=='coloured' and not (FHKEllesmereDB and FHKEllesmereDB.vividBarFills==false)
end
function NS.SyncEllesmereVividTheme()
    local s=State()
    if s and s.active=='coloured' and s.vividVersion~=VIVID_VERSION then
        NS.ApplyEllesmereThemePreset('coloured',true)
    end
    NS.SyncEllesmereXPTheme()
    -- Existing Coloured profiles return to WoW class colours once; only our own
    -- earlier vivid values are removed, a colour you picked stays.
    s=State()
    if s and s.active=='coloured' and s.classVersion~=1 and ReturnClassColours() then
        s.classVersion=1
        local _,class=UnitClass('player')
        local c=Public(class) and EUI.GetClassColor and EUI.GetClassColor(class)
        if c and EUI.SetAccentColor then EUI.SetAccentColor(c.r,c.g,c.b) end
        Refresh()
    end
    -- Existing Coloured profiles take the rose cast bar once; later edits stay.
    s=State()
    if s and s.active=='coloured' and s.castVersion~=CAST_VERSION and UnitFrameProfile() then
        if s.backup and s.backup.playerCast==nil then s.backup.playerCast=CapturePlayerCast() end
        if s.backup and s.backup.casts==nil then s.backup.casts=CaptureCastStates() end
        ApplyCastStates()
        local _,np=PlateProfile()
        if np and np.RefreshAllSettings then pcall(np.RefreshAllSettings) end
        if ApplyPlayerCast() then
            s.castVersion=CAST_VERSION
            local _,uf=UnitFrameProfile()
            if uf and uf.ReloadFrames then uf.ReloadFrames() end
        end
    end
    if NS.InstallEllesmereCueFontHook then NS.InstallEllesmereCueFontHook() end
    if NS.SyncEllesmereCueText then NS.SyncEllesmereCueText() end
end
-- Migrate only XP on existing Coloured profiles; later class/XP swatches remain.
function NS.SyncEllesmereXPTheme()
    local s=State()
    if not s or s.active~='coloured' then pendingXP=nil;SyncEvents();return end
    if s.xpVersion==XP_VERSION or not XPProfile() then return end
    if InCombatLockdown() then pendingXP=ProfileName();SyncEvents();return end
    if s.backup and s.backup.xp==nil then s.backup.xp=CaptureXP() end
    if ApplyXPColours() then
        s.xpVersion=XP_VERSION
        local _,ab=XPProfile()
        if ab and ab.ApplyDataBarLayout then ab.ApplyDataBarLayout('XPBar') end
        if NS.SyncEllesmereXPBar then NS.SyncEllesmereXPBar() end
    end
    pendingXP=nil
end
function NS.GetEllesmereThemePreset()
    local s=State();return s and s.active or 'current'
end
function NS.ApplyEllesmereThemePreset(key,migrating)
    if key~='coloured' and key~='dark' and key~='afterglow' and key~='current' then return false,'Unknown preset.' end
    if not EUI.IS_FOREVER then return false,'These presets are for WoW Forever.' end
    if not EUI.GetDarkModeDB or not NativeColors() or not EUI.SetAccentColor then return false,'Native colour controls are unavailable.' end
    if EUI.IsColorEditingLocked and EUI.IsColorEditingLocked() then return false,'Select the palette source profile in Global Settings -> Colors.' end
    if InCombatLockdown() then
        pending={key=key,profile=ProfileName()};SyncEvents();return false,'Theme queued until combat ends.'
    end
    local s=State(true)
    if key=='current' and not s.backup then pending=nil;SyncEvents();return true end
    local before=Capture()
    if not s.backup then s.backup=Copy(before) end
    -- Backups made before reaction fills existed: those colours are still the
    -- player's own, so record them now and Restore can return them.
    if s.backup.enemyColors==nil then s.backup.enemyColors=Copy(before.enemyColors) end
    if s.backup.plate==nil then s.backup.plate=Copy(before.plate) end
    if s.backup.xp==nil then s.backup.xp=Copy(before.xp) end
    if s.backup.playerCast==nil then s.backup.playerCast=Copy(before.playerCast) end
    if s.backup.casts==nil then s.backup.casts=Copy(before.casts) end
    -- Restore Original Look stays an exact roundtrip to the original (tested contract).
    local edits=not migrating and key~='current' and type(s.applied)=='table' and {colors=Edits(NativeColors(),s.applied.colors),dark=Edits(EUI.GetDarkModeDB(),s.applied.dark)} or nil
    applying=true
    local ok=pcall(function()
        Restore(s.backup)
        if key=='coloured' then
            Dark(false,false)
            ApplyVividPalette()
            ApplyReactionFills()
            ApplyXPColours()
            ApplyPlayerCast()
            ApplyCastStates()
        elseif key=='dark' then
            Dark(true,true)
            -- Clean dark (player request): health you have is a dark shade of black,
            -- health lost is black, so nothing grey draws the eye to the missing part.
            -- The health line (UnitRefinements) carries amount and warning colour.
            -- Colour has to mean something here (player): power is near-black navy, so
            -- only state colours stand out; the mana number carries depletion.
            local d=EUI.GetDarkModeDB()
            d.fillR,d.fillG,d.fillB,d.fillA=0x1C/255,0x1D/255,0x21/255,1
            d.bgR,d.bgG,d.bgB,d.bgA=0,0,0,1
            d.classDarken,d.resourceDarken=0,0
            d.powerDarken,d.powerBgDarken=70,85
            if EUI.SetActiveTheme then EUI.SetActiveTheme('Dark') end
        elseif key=='afterglow' then ApplyPalette();Dark(true,false) end
        if edits then Reapply(NativeColors(),edits.colors);Reapply(EUI.GetDarkModeDB(),edits.dark) end
    end)
    if not ok then
        local restored=pcall(Restore,before);applying=nil;pending=nil;pcall(Refresh)
        if restored then return false,'The native theme could not be applied. The previous palette was restored.' end
        return false,'Native theme controls failed. Use Restore Original Look after fixing the addon error.'
    end
    s.active=key
    if key=='coloured' then s.vividVersion=VIVID_VERSION end
    if key=='coloured' and XPProfile() then s.xpVersion=XP_VERSION end
    if key=='coloured' then s.castVersion=CAST_VERSION end
    if key=='current' then s.active=nil end
    if key=='current' then s.backup=nil end
    -- What the preset wrote, so later player edits can be told apart (review T1).
    s.applied=key~='current' and {colors=Copy(NativeColors()),dark=Copy(EUI.GetDarkModeDB())} or nil
    pending=nil;pendingXP=nil;applying=nil;Refresh()
    if EUI.Conditions_Recheck then EUI.Conditions_Recheck() end
    if EUI.RefreshPage then EUI:RefreshPage() end
    return true
end
function NS.AddEllesmereThemeOptions(Row)
    Row({type='toggle',text='Dark Mode',tooltip='Applies the Dark preset to health and resource bars across the suite. Off restores your previous look.',
        getValue=function() return NS.GetEllesmereThemePreset()=='dark' end,
        disabled=function() return EUI.IsColorEditingLocked and EUI.IsColorEditingLocked() end,
        disabledTooltip='Select The Palette Source Profile',
        setValue=function(v)
            local ok,message=NS.ApplyEllesmereThemePreset(v and 'dark' or 'current')
            if not ok and message then print('FHK: '..message) end
        end},
        {type='button',text='Restore Original Look',onClick=function()
            local ok,message=NS.ApplyEllesmereThemePreset('current');if not ok and message then print('FHK: '..message) end
        end})
    Row({type='dropdown',text='Forever Theme Preset',values={current='Original / Restore',coloured='Colored',dark='Dark',afterglow='Afterglow'},
        order={'current','coloured','dark','afterglow'},getValue=NS.GetEllesmereThemePreset,
        tooltip='Colored, Dark and Afterglow use native color sharing. Layout and keybinds stay as set.',
        disabled=function() return EUI.IsColorEditingLocked and EUI.IsColorEditingLocked() end,
        disabledTooltip='Select The Palette Source Profile',
        setValue=function(v) local ok,message=NS.ApplyEllesmereThemePreset(v);if not ok and message then print('FHK: '..message) end end},
        {type='label',text='Afterglow: ink, slate and class accents; colored resources'})
    NS.AddEllesmereThemeDetailOptions(Row)
end
-- Shared by legacy/plugin pages and the native Style extension. Callbacks read
-- the active profile live because native extension descriptors are copied once.
function NS.AddEllesmereThemeDetailOptions(Row)
    Row({id='strongOutlines',type='toggle',text='Strong Theme Outlines',tooltip='Keeps native fonts and sizes, with stronger black outlines on world cues and finer outlines on small bar labels.',
        getValue=function() return not (FHKEllesmereDB and FHKEllesmereDB.vividCueText==false) end,
        setValue=function(v)
            if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end;FHKEllesmereDB.vividCueText=v
            if NS.SyncEllesmereCueText then NS.SyncEllesmereCueText() end
        end},
        {id='readableFills',type='toggle',text='Readable Colored Fills',tooltip='Your health starts in your class color, then warns gold, orange and red. Resources keep their own hue and brighten as they fill. Enemy bars keep their reaction colors.',
        getValue=function() return not (FHKEllesmereDB and FHKEllesmereDB.vividBarFills==false) end,
        setValue=function(v)
            if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end;FHKEllesmereDB.vividBarFills=v
            if NS.SyncEllesmereUnitRefinements then NS.SyncEllesmereUnitRefinements() end
            if NS.PaintEllesmereResourceBars then NS.PaintEllesmereResourceBars() end
        end})
    Row({id='pixelEdges',type='toggle',text='Pixel Icon Edges',tooltip='Adds black pixel borders to square cue icons and a thin black edge around transparent status symbols. Native art, tint and positioning stay in place.',
        getValue=function() return not (FHKEllesmereDB and FHKEllesmereDB.pixelIconEdges==false) end,
        setValue=function(v)
            if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end;FHKEllesmereDB.pixelIconEdges=v
            if NS.SyncEllesmereCueText then NS.SyncEllesmereCueText() end
            if NS.SyncEllesmereUnitRefinements then NS.SyncEllesmereUnitRefinements() end
            if NS.ApplyAttackCueSize then NS.ApplyAttackCueSize() end
        end},{id='powerSeparator',type='toggle',text='Health / Power Separator',tooltip='A black physical-pixel line between health and power on custom unit frames. Follows power-bar visibility and preserves native layout.',
        getValue=function() return not (FHKEllesmereDB and FHKEllesmereDB.pixelBarSeparators==false) end,
        setValue=function(v)
            if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end;FHKEllesmereDB.pixelBarSeparators=v
            if NS.SyncEllesmereUnitRefinements then NS.SyncEllesmereUnitRefinements() end
        end})
end
SyncEvents=function()
    for _,event in ipairs({'PLAYER_REGEN_ENABLED','PLAYER_TARGET_CHANGED','GROUP_ROSTER_UPDATE','UNIT_NAME_UPDATE'}) do
        if IsAfterglow() or (event=='PLAYER_REGEN_ENABLED' and (pending or pendingXP)) then driver:RegisterEvent(event)
        else driver:UnregisterEvent(event) end
    end
end
if EUI.RegisterDarkModeRefresh then EUI.RegisterDarkModeRefresh(function()
    if not applying then PaintTrim();SyncEvents() end
end) end
driver:RegisterEvent('PLAYER_LOGIN')
driver:SetScript('OnEvent',function(_,event,unit)
    if event=='PLAYER_LOGIN' then driver:UnregisterEvent('PLAYER_LOGIN');NS.SyncEllesmereVividTheme() end
    if event=='PLAYER_REGEN_ENABLED' and pending then
        local todo=pending;pending=nil
        if todo.profile==ProfileName() then NS.ApplyEllesmereThemePreset(todo.key) end
    end
    if event=='PLAYER_REGEN_ENABLED' and pendingXP then
        local name=pendingXP;pendingXP=nil
        if name==ProfileName() then NS.SyncEllesmereXPTheme() end
    end
    if event~='UNIT_NAME_UPDATE' or Public(unit) then PaintTrim() end
    SyncEvents()
end)
SLASH_FHKTHEME1='/fhktheme'
SlashCmdList.FHKTHEME=function(input)
    local key=tostring(input or ''):lower():match('^%s*(%S*)')
    if key=='restore' then key='current' end
    if key=='' or key=='status' then print('FHK theme: '..NS.GetEllesmereThemePreset());return end
    local ok,message=NS.ApplyEllesmereThemePreset(key)
    print('FHK: '..(ok and ('Theme '..key..' applied.') or message))
end
