-- Levelling helpers (plan 10.3 priority 2/3 and section 11 forum picks). Each is a separate
-- toggle and registers its events only while on.
--   Breath / Fatigue / Feign Death bars (player: "skin the breath bar"): Forever's
--     MirrorTimerContainer bars get the flat Ellesmere look: dark track, 1 px border, state
--     colour, the suite font. Blizzard keeps the timers, layout and Edit Mode position.
--   Target Range Fade (forum, 22 + 6): the target frame fades while the target is out of
--     range by our Hunter range states; never in the dead zone, where the range cue speaks.
--   Loot Left Behind (player idea): when a loot window closes with items of a chosen
--     rarity still in it (full bags, rushing), say what was left and whether bags are full.
--   Gathering Tracking (FR25): out of combat with no tracking at all, name the learned
--     Find Herbs / Find Minerals.
--   Zone Levels (FR22): the world map shows the shown zone's level range, coloured for you.
--     Classic ranges; Forever may differ (E3).
--   Close Bags Opened By NPCs (FR32): a vendor, mailbox, auction house or trade window opens
--     the bags through OpenAllBags, which Ellesmere follows, but nothing closes Ellesmere's
--     bags again. When that window closes, bags that opened with it (within half a second)
--     close through Ellesmere; bags you had open, opened later, or a Feed Pet selection stay.
--   Show When Mana Missing (FR23): Ellesmere's own "Show When Health Missing" also reveals
--     the player frame while mana is below full (drinking between pulls). Mana only, never
--     rage or energy; an unreadable value counts as full, so the frame never sticks.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end
local L={}
local unpack=unpack or table.unpack
NS.LevelingQoL=L
local DEFAULTS={mirrorSkin=true,rangeFade=false,rangeAlpha=.45,lootLeft=true,lootQuality=2,gatherTrack=false,zoneLevels=true,manaVisible=false,closeBags=true}
function NS.EllesmereLevelingSettings()
    FHKEllesmereDB=FHKEllesmereDB or {}
    local s=FHKEllesmereDB.levelingQoL
    if type(s)~='table' then s={};FHKEllesmereDB.levelingQoL=s end
    for k,v in pairs(DEFAULTS) do if s[k]==nil then s[k]=v end end
    return s
end
local function Plain(v) return not (issecretvalue and issecretvalue(v)) end
local function Public(v) if Plain(v) then return v end end
local function Read(fn,...)
    if type(fn)~='function' then return end
    local ok,a,b,c,d,e,f,g,h=pcall(fn,...)
    if ok then return Public(a),Public(b),Public(c),Public(d),Public(e),Public(f),Public(g),Public(h) end
end
local function Num(v) return Plain(v) and type(v)=='number' and v==v end
local function InCombat() return Read(_G.InCombatLockdown)~=false end
local function Font(fs,size)
    if not (fs and fs.SetFont) then return end
    local path=EUI.GetFontPath and EUI.GetFontPath('extras') or 'Fonts\\FRIZQT__.TTF'
    fs:SetFont(path,size,'OUTLINE')
end
local C=NS.Colours or {}

-------------------------------------------------------------------------------
-- Breath / Fatigue / Feign Death bars.
-------------------------------------------------------------------------------
local MIRROR={BREATH=C.mirrorBreath or {.25,.6,1},EXHAUSTION=C.mirrorFatigue or C.caution or {1,.82,0},
    FEIGNDEATH=C.mirrorFeign or {.7,.62,.85},DEATH=C.danger or {1,.3,.25}}
local skinned={}
function L.SkinMirror(frame)
    if not (frame and frame.StatusBar) then return end
    local on=NS.EllesmereLevelingSettings().mirrorSkin
    local bar=frame.StatusBar
    local st=skinned[frame]
    if not on then
        if st then
            if frame.Border then frame.Border:SetAlpha(st.borderAlpha or 1) end
            if frame.TextBorder then frame.TextBorder:SetAlpha(st.textBorderAlpha or 1) end
            if st.font and frame.Text then frame.Text:SetFont(unpack(st.font)) end
            if st.bg then st.bg:Hide() end
            if st.border and st.border.SetAlpha then st.border:SetAlpha(0) end
            if frame.timer and _G.MirrorTimerAtlas and bar.SetStatusBarTexture then bar:SetStatusBarTexture(MirrorTimerAtlas[frame.timer]) end
            if bar.SetStatusBarColor then bar:SetStatusBarColor(1,1,1,1) end
        end
        return
    end
    if not st then
        st={}
        st.borderAlpha=frame.Border and Read(frame.Border.GetAlpha,frame.Border)
        st.textBorderAlpha=frame.TextBorder and Read(frame.TextBorder.GetAlpha,frame.TextBorder)
        if frame.Text then
            local path,size,flags=Read(frame.Text.GetFont,frame.Text)
            if type(path)=='string' and Num(size) then st.font={path,size,flags or ''} end
        end
        st.bg=bar:CreateTexture(nil,'BACKGROUND',nil,-7);st.bg:SetAllPoints();st.bg:SetColorTexture(.055,.065,.075,.95)
        st.border=EUI.MakeBorder and EUI.MakeBorder(bar,0,0,0,1) or nil
        skinned[frame]=st
    end
    for _,t in ipairs({frame.Border,frame.TextBorder}) do if t then t:SetAlpha(0) end end
    st.bg:Show()
    if st.border and st.border.SetAlpha then st.border:SetAlpha(1) end
    if bar.SetStatusBarTexture then bar:SetStatusBarTexture('Interface\\Buttons\\WHITE8x8') end
    local c=MIRROR[frame.timer] or MIRROR.BREATH
    if bar.SetStatusBarColor then bar:SetStatusBarColor(c[1],c[2],c[3],1) end
    Font(frame.Text,11)
end
local mirrorHooked=false
function L.HookMirror()
    local box=rawget(_G,'MirrorTimerContainer')
    if type(box)~='table' or type(box.mirrorTimers)~='table' then return end
    if not mirrorHooked then
        for _,frame in ipairs(box.mirrorTimers) do
            if type(frame.Setup)=='function' then hooksecurefunc(frame,'Setup',L.SkinMirror) end
        end
        mirrorHooked=true
    end
    for _,frame in ipairs(box.mirrorTimers) do if frame.timer then L.SkinMirror(frame) end end
end

-------------------------------------------------------------------------------
-- Target Range Fade.
-------------------------------------------------------------------------------
local FAR={far=true,out=true,beyond=true}
local faded,fadeTicker=nil,nil
local function TargetFrame()
    local uf=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIUnitFrames
    return uf and uf.frames and uf.frames.target
end
function L.CheckRange()
    local s=NS.EllesmereLevelingSettings()
    local f=TargetFrame()
    local want=false
    if s.rangeFade and f and Read(_G.UnitExists,'target')==true and NS.GetUnitRange then
        local r=NS.GetUnitRange('target')
        want=r and FAR[r.state] or false
    end
    if faded and faded.frame~=f then faded.frame:SetAlpha(faded.alpha);faded=nil end
    if want and not faded and f then
        faded={frame=f,alpha=Read(f.GetAlpha,f) or 1}
    end
    if want and f then f:SetAlpha(Num(s.rangeAlpha) and s.rangeAlpha or .45)
    elseif faded then
        faded.frame:SetAlpha(faded.alpha)
        faded=nil
    end
end
local function RangeTicker(on)
    if on and not fadeTicker and C_Timer and C_Timer.NewTicker then fadeTicker=C_Timer.NewTicker(.25,L.CheckRange)
    elseif not on and fadeTicker then fadeTicker:Cancel();fadeTicker=nil end
end

-------------------------------------------------------------------------------
-- Loot Left Behind.
-------------------------------------------------------------------------------
local loot,cleared,lootActive={}, {},false
local lootToken=0
local function FreeSlots()
    local free=0
    for bag=0,(_G.NUM_BAG_SLOTS or 4) do
        local n=Read(C_Container and C_Container.GetContainerNumFreeSlots,bag)
        if Num(n) then free=free+n end
    end
    return free
end
function L.LootOpened()
    if not NS.EllesmereLevelingSettings().lootLeft then return end
    if not lootActive then loot,cleared={},{};lootActive=true end
    local n=Read(_G.GetNumLootItems)
    for i=1,Num(n) and n or 0 do
        local _,_,count,_,quality,locked=Read(_G.GetLootSlotInfo,i)
        local link=Read(_G.GetLootSlotLink,i)
        local kind=Read(_G.GetLootSlotType,i)
        local isItem=kind==nil or kind==(Enum and Enum.LootSlotType and Enum.LootSlotType.Item or 1)
        -- Locked slots (a group roll, someone else's loot) were never yours to take.
        if not cleared[i] and type(link)=='string' and isItem and locked~=true then loot[i]={link=link,count=Num(count) and count or 1,quality=Num(quality) and quality or 0} end
    end
end
function L.LootCleared(slot) if Num(slot) then cleared[slot]=true;loot[slot]=nil end end
function L.LootClosed()
    local s=NS.EllesmereLevelingSettings()
    lootActive=false
    if not s.lootLeft then loot,cleared={},{};return end
    local left={}
    for _,item in pairs(loot) do if item.quality>=(s.lootQuality or 2) then left[#left+1]=item end end
    loot,cleared={},{}
    if #left==0 then return end
    local full=FreeSlots()==0
    local parts={}
    for _,item in ipairs(left) do parts[#parts+1]=item.link..(item.count>1 and ('x'..item.count) or '') end
    local line='|cffdda880FHK|r Left in the loot window: '..table.concat(parts,', ')..(full and ' |cffff4d40(bags full)|r' or '')
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage(line) end
    if NS.ShowEllesmereWarning then
        NS.ShowEllesmereWarning('lootLeft','Loot Left Behind ('..#left..')'..(full and ' - Bags Full' or ''),C.caution or {1,.82,0})
        lootToken=lootToken+1
        local token=lootToken
        if C_Timer and C_Timer.After then C_Timer.After(5,function() if token==lootToken and NS.HideEllesmereWarning then NS.HideEllesmereWarning('lootLeft') end end) end
    end
    return left,full
end

-------------------------------------------------------------------------------
-- Gathering Tracking.
-------------------------------------------------------------------------------
local GATHER={2383,2580} -- Find Herbs, Find Minerals
local function SpellName(id)
    local name=C_Spell and Read(C_Spell.GetSpellName,id)
    return type(name)=='string' and name or nil
end
local function Known(id) return Read(C_SpellBook and C_SpellBook.IsSpellKnown,id)==true or Read(_G.IsPlayerSpell,id)==true end
function L.CheckGather()
    local s=NS.EllesmereLevelingSettings()
    local show
    if s.gatherTrack and not InCombat() then
        local M=C_Minimap
        local n=M and Read(M.GetNumTrackingTypes)
        local any,readable=false,Num(n)
        for i=1,Num(n) and n or 0 do
            local info=Read(M.GetTrackingInfo,i)
            if type(info)~='table' or not Plain(info.type) or not Plain(info.active) then readable=false
            elseif info.type=='spell' and info.active==true then any=true end
        end
        if readable and not any then
            for _,id in ipairs(GATHER) do if Known(id) then show=SpellName(id);break end end
        end
    end
    if show and NS.ShowEllesmereWarning then NS.ShowEllesmereWarning('gather',show,{.96,.945,.925})
    elseif NS.HideEllesmereWarning then NS.HideEllesmereWarning('gather') end
end

-------------------------------------------------------------------------------
-- Zone Levels on the world map (Classic ranges, English zone names).
-------------------------------------------------------------------------------
L.ZONES={
    ['Elwynn Forest']={1,10},['Dun Morogh']={1,10},['Tirisfal Glades']={1,10},['Durotar']={1,10},['Mulgore']={1,10},['Teldrassil']={1,10},
    ['Westfall']={10,20},['Loch Modan']={10,20},['Silverpine Forest']={10,20},['Darkshore']={10,20},['The Barrens']={10,25},
    ['Redridge Mountains']={15,25},['Stonetalon Mountains']={15,27},['Duskwood']={18,30},['Ashenvale']={18,30},
    ['Wetlands']={20,30},['Hillsbrad Foothills']={20,30},['Thousand Needles']={25,35},['Alterac Mountains']={30,40},
    ['Arathi Highlands']={30,40},['Desolace']={30,40},['Stranglethorn Vale']={30,45},['Badlands']={35,45},
    ['Swamp of Sorrows']={35,45},['Dustwallow Marsh']={35,45},['The Hinterlands']={40,50},['Feralas']={40,50},
    ['Tanaris']={40,50},['Searing Gorge']={43,50},['Azshara']={45,55},['Blasted Lands']={45,55},['Felwood']={48,55},
    ["Un'Goro Crater"]={48,55},['Burning Steppes']={50,58},['Western Plaguelands']={51,58},['Eastern Plaguelands']={53,60},
    ['Winterspring']={55,60},['Silithus']={55,60},['Deadwind Pass']={55,60},
}
local zoneLabel
function L.ZoneText(name,level)
    local range=type(name)=='string' and L.ZONES[name]
    if not range then return nil end
    local text=range[1]==range[2] and ('Level '..range[1]) or ('Levels '..range[1]..'-'..range[2])
    local c=Num(level) and type(GetQuestDifficultyColor)=='function' and Read(GetQuestDifficultyColor,math.floor((range[1]+range[2])/2))
    return text,c
end
function L.PaintZone()
    local map=rawget(_G,'WorldMapFrame')
    if type(map)~='table' then return end
    local s=NS.EllesmereLevelingSettings()
    local id=map.GetMapID and Read(map.GetMapID,map)
    local info=Num(id) and C_Map and Read(C_Map.GetMapInfo,id)
    local text,c=nil,nil
    if s.zoneLevels and type(info)=='table' then text,c=L.ZoneText(info.name,Read(_G.UnitLevel,'player')) end
    if not text then if zoneLabel then zoneLabel:Hide() end return end
    if not zoneLabel then
        local host=map.ScrollContainer or map
        zoneLabel=host:CreateFontString(nil,'OVERLAY');Font(zoneLabel,14)
        zoneLabel:SetPoint('TOP',host,'TOP',0,-10)
    end
    zoneLabel:SetText(text)
    if type(c)=='table' and Num(c.r) then zoneLabel:SetTextColor(c.r,c.g,c.b) else zoneLabel:SetTextColor(1,.82,0) end
    zoneLabel:Show()
end
local mapHooked=false
local function HookMap()
    local map=rawget(_G,'WorldMapFrame')
    if mapHooked or type(map)~='table' then return end
    if type(map.OnMapChanged)=='function' then hooksecurefunc(map,'OnMapChanged',L.PaintZone) end
    if map.HookScript then map:HookScript('OnShow',L.PaintZone) end
    mapHooked=true
end

-------------------------------------------------------------------------------
-- Close Bags Opened By NPCs.
-------------------------------------------------------------------------------
local OPEN_EVENTS={MERCHANT_SHOW=true,MAIL_SHOW=true,AUCTION_HOUSE_SHOW=true,TRADE_SHOW=true}
local CLOSE_EVENTS={MERCHANT_CLOSED=true,MAIL_CLOSED=true,AUCTION_HOUSE_CLOSED=true,TRADE_CLOSED=true}
local bagsShownAt,interactionAt,bagsHooked=nil,nil,false
local closeToken=0
local function Now() return GetTime and GetTime() or 0 end
local function BagsRoot()
    local root=rawget(_G,'EUI_Bags')
    return type(root)=='table' and root or nil
end
function L.WatchBags()
    local root=BagsRoot()
    if bagsHooked or not root or not root.HookScript then return end
    bagsHooked=true
    root:HookScript('OnShow',function() bagsShownAt=Now() end)
    root:HookScript('OnHide',function() bagsShownAt=nil end)
    if Read(root.IsShown,root)==true then bagsShownAt=-100 end
end
function L.Interaction(event)
    local root=BagsRoot()
    if not root then return end
    if OPEN_EVENTS[event] then closeToken=closeToken+1;interactionAt=Now();return end
    if not CLOSE_EVENTS[event] or not interactionAt then return end
    local started=interactionAt;interactionAt=nil
    if not NS.EllesmereLevelingSettings().closeBags or Read(root.IsShown,root)~=true or not bagsShownAt then return end
    if NS.PetFood and NS.PetFood.FeedTargeting and NS.PetFood.FeedTargeting() then return end
    -- Opened with the window: shown at most half a second either side of it opening.
    if math.abs(bagsShownAt-started)>.5 then return end
    closeToken=closeToken+1
    local token,shownAt=closeToken,bagsShownAt
    C_Timer.After(0,function()
        if token~=closeToken or interactionAt or bagsShownAt~=shownAt or not NS.EllesmereLevelingSettings().closeBags then return end
        if NS.PetFood and NS.PetFood.FeedTargeting and NS.PetFood.FeedTargeting() then return end
        if Read(root.IsShown,root)==true and type(ToggleAllBags)=='function' then pcall(ToggleAllBags) end
    end)
end

-------------------------------------------------------------------------------
-- Show When Mana Missing: wraps Ellesmere's two health-reveal writers for the player.
-------------------------------------------------------------------------------
local MANA=(Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
function L.ManaMissing()
    if not NS.EllesmereLevelingSettings().manaVisible then return false end
    local cur,max=Read(_G.UnitPower,'player',MANA),Read(_G.UnitPowerMax,'player',MANA)
    return Num(cur) and Num(max) and max>0 and cur<max or false
end
local manaHooked=false
local function HookManaReveal()
    local uf=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIUnitFrames
    if manaHooked or type(uf)~='table' or type(uf.HealthVisibilityAlpha)~='function' or type(uf.UpdateHealthVisibilityUnit)~='function' then return end
    manaHooked=true
    local alphaOf,update=uf.HealthVisibilityAlpha,uf.UpdateHealthVisibilityUnit
    uf.HealthVisibilityAlpha=function(settings,frame,baseAlpha,...)
        local alpha=alphaOf(settings,frame,baseAlpha,...)
        if frame and frame._healthVisLive and frame._euiUnit=='player' and L.ManaMissing() then return 1 end
        return alpha
    end
    uf.UpdateHealthVisibilityUnit=function(unit,...)
        update(unit,...)
        local frame=uf.frames and uf.frames[unit]
        if unit=='player' and frame and frame._healthVisLive and L.ManaMissing() then
            local shown=frame._visWrap or frame
            shown:SetAlpha(1)
            local model=frame.Portrait and frame.Portrait.backdrop and frame.Portrait.backdrop._3d
            if model then model:SetAlpha(1) end
            local mini=uf.UF_MINI_OF and uf.frames[uf.UF_MINI_OF[unit]]
            local p=uf.db and uf.db.profile
            if mini and not (p and p.pet and p.pet.alwaysShow) then mini:SetAlpha(1) end
            return
        end
    end
end
L.HookManaReveal=HookManaReveal
function L.ManaChanged()
    local uf=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIUnitFrames
    if uf and type(uf.UpdateHealthVisibilityUnit)=='function' then pcall(uf.UpdateHealthVisibilityUnit,'player') end
end

-------------------------------------------------------------------------------
-- Events and options.
-------------------------------------------------------------------------------
local driver
function L.OnEvent(_,event,arg1)
    if event=='UNIT_POWER_UPDATE' or event=='UNIT_MAXPOWER' then if arg1=='player' then L.ManaChanged() end return end
    if OPEN_EVENTS[event] or CLOSE_EVENTS[event] then L.WatchBags();L.Interaction(event);return end
    if event=='LOOT_OPENED' or event=='LOOT_READY' then L.LootOpened()
    elseif event=='LOOT_SLOT_CLEARED' then L.LootCleared(arg1)
    elseif event=='LOOT_CLOSED' then L.LootClosed()
    elseif event=='PLAYER_TARGET_CHANGED' then
        L.CheckRange();RangeTicker(NS.EllesmereLevelingSettings().rangeFade and Read(_G.UnitExists,'target')==true)
    elseif event=='ADDON_LOADED' then
        if arg1=='Blizzard_MirrorTimer' then L.HookMirror() end
        if arg1=='Blizzard_WorldMap' then HookMap() end
    else
        L.CheckGather()
        if event=='PLAYER_ENTERING_WORLD' then L.HookMirror();HookMap() end
    end
end
function NS.SyncEllesmereLeveling()
    local s=NS.EllesmereLevelingSettings()
    if not s.lootLeft then
        loot,cleared,lootActive={}, {},false;lootToken=lootToken+1
        if NS.HideEllesmereWarning then NS.HideEllesmereWarning('lootLeft') end
    end
    if not s.closeBags then interactionAt=nil;closeToken=closeToken+1 end
    if not driver then driver=CreateFrame('Frame');driver:SetScript('OnEvent',L.OnEvent) end
    driver:UnregisterAllEvents()
    driver:RegisterEvent('ADDON_LOADED');driver:RegisterEvent('PLAYER_ENTERING_WORLD')
    if s.lootLeft then for _,e in ipairs({'LOOT_OPENED','LOOT_READY','LOOT_SLOT_CLEARED','LOOT_CLOSED'}) do driver:RegisterEvent(e) end end
    if s.rangeFade then driver:RegisterEvent('PLAYER_TARGET_CHANGED') end
    if s.gatherTrack then for _,e in ipairs({'MINIMAP_UPDATE_TRACKING','PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED','SPELLS_CHANGED'}) do driver:RegisterEvent(e) end end
    if s.closeBags then
        L.WatchBags()
        for e in pairs(OPEN_EVENTS) do driver:RegisterEvent(e) end
        for e in pairs(CLOSE_EVENTS) do driver:RegisterEvent(e) end
    end
    if s.manaVisible then
        HookManaReveal()
        if driver.RegisterUnitEvent then driver:RegisterUnitEvent('UNIT_POWER_UPDATE','player');driver:RegisterUnitEvent('UNIT_MAXPOWER','player')
        else driver:RegisterEvent('UNIT_POWER_UPDATE');driver:RegisterEvent('UNIT_MAXPOWER') end
    end
    L.ManaChanged()
    L.HookMirror();HookMap();L.PaintZone();L.CheckGather();L.CheckRange()
    RangeTicker(s.rangeFade and Read(_G.UnitExists,'target')==true)
end
function NS.AddEllesmereLevelingOptions(Row)
    local s=NS.EllesmereLevelingSettings()
    local function Set(key,v) s[key]=v;NS.SyncEllesmereLeveling();if EUI.RefreshPage then EUI:RefreshPage() end end
    Row({type='toggle',text='Skin Breath And Fatigue Bars',tooltip='Breath, fatigue and Feign Death bars take the flat Ellesmere look: dark track, thin border, a color per timer. Move them in Blizzard Edit Mode.',
        getValue=function() return s.mirrorSkin end,setValue=function(v) Set('mirrorSkin',v) end},
        {type='toggle',text='Loot Left Behind',tooltip='When a loot window closes with items still in it (full bags or rushing), lists them in chat and warns, saying when your bags are full.',
        getValue=function() return s.lootLeft end,setValue=function(v) Set('lootLeft',v) end})
    if NS.EllesmereColorRow then
        local off=function() return not s.mirrorSkin end
        local function Row2(key,text)
            local r=NS.EllesmereColorRow(key,text);r.disabled=off;r.disabledTooltip='Skin Breath And Fatigue Bars';return r
        end
        Row(Row2('mirrorBreath','Breath Bar Color'),Row2('mirrorFatigue','Fatigue Bar Color'))
        Row(Row2('mirrorFeign','Feign Death Bar Color'),NS.EllesmereResetColors({'mirrorBreath','mirrorFatigue','mirrorFeign'},'Reset Bar Colors'))
    end
    Row({type='dropdown',text='Loot Left Behind From',values={['0']='Poor',['1']='Common',['2']='Uncommon',['3']='Rare',['4']='Epic'},order={'0','1','2','3','4'},
        disabled=function() return not s.lootLeft end,disabledTooltip='Loot Left Behind',
        getValue=function() return tostring(s.lootQuality) end,setValue=function(v) Set('lootQuality',tonumber(v) or 2) end},
        {type='toggle',text='Zone Levels On Map',tooltip='The world map shows the level range of the zone it shows, colored for your level. Classic ranges.',
        getValue=function() return s.zoneLevels end,setValue=function(v) Set('zoneLevels',v) end})
    Row({type='toggle',text='Target Range Fade',tooltip='The target frame fades while your target is out of range. Never in the dead zone, where the range indicator already says so.',
        getValue=function() return s.rangeFade end,setValue=function(v) Set('rangeFade',v) end},
        {type='slider',text='Out Of Range Opacity',min=10,max=90,step=5,
        disabled=function() return not s.rangeFade end,disabledTooltip='Target Range Fade',
        getValue=function() return math.floor(s.rangeAlpha*100+.5) end,setValue=function(v) s.rangeAlpha=v/100;L.CheckRange() end})
    Row({type='toggle',text='Close Bags Opened By NPCs',tooltip='When a vendor, mailbox, auction house or trade window closes, your bags close too if they opened with it. Bags you had open or opened yourself stay.',
        getValue=function() return s.closeBags end,setValue=function(v) Set('closeBags',v) end},
        {type='label',text='The bank already does this natively'})
    Row({type='toggle',text='Show When Mana Missing',tooltip='With Unit Frames > Show When Health Missing on, the player frame also shows while your mana is below full, for drinking between pulls. Mana only.',
        getValue=function() return s.manaVisible end,setValue=function(v) Set('manaVisible',v) end},
        {type='label',text='Uses Ellesmere\'s own health-missing reveal'})
    Row({type='toggle',text='Gathering Tracking Reminder',tooltip='Out of combat with no tracking on: names your learned Find Herbs or Find Minerals.',
        getValue=function() return s.gatherTrack end,setValue=function(v) Set('gatherTrack',v) end},
        {type='label',text='Tracking spells share one slot: Track Beasts wins'})
end

local boot=CreateFrame('Frame')
boot:RegisterEvent('PLAYER_LOGIN')
boot:SetScript('OnEvent',function(self) self:UnregisterAllEvents();NS.SyncEllesmereLeveling() end)
