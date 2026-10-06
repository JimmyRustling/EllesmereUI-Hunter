-- Completed quest XP, native easing, gain highlights and session stats for Ellesmere's XP bar.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end

local DEFAULTS={quests=true,smooth=true,glow=true,ticks=true,tooltip=true,fullNumbers=true}
-- {min,max,default}. The quest overlay has no stored default: the Colored theme mixes it
-- opaque and other themes show it at 55 %, until the player picks a value.
local OPACITY={tickOpacity={.05,.6,.12},glowOpacity={.1,1,.85},questOpacity={.1,1}}
local driver=CreateFrame('Frame')
local holder,bar,overlay,tickHost,ticks,gain,fade
local nativeSetValue,nativeDividers,hookedDividers
local lastValue,lastMax,lastLevel
local previous,sessionStart,sessionXP,tracking=nil,nil,0,false
local pendingXP,knownRewards,completedQuests=0,0,0
local generation,questQueued,xpQueued=0,false,false
local applied=false
local scanning=false
local RefreshReadout,InstallFullNumbers -- assigned below
local colourLines=setmetatable({},{__mode='k'})
local function Secret(v) return issecretvalue and issecretvalue(v) end
local function Plain(v)
    return not Secret(v) and type(v)=='number' and v==v and math.abs(v)<math.huge
end
local function Read(fn,...)
    if type(fn)~='function' then return nil end
    local ok,value=pcall(fn,...)
    if ok and not Secret(value) then return value end
end
function NS.EllesmereXPBarSettings()
    if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end
    local s=FHKEllesmereDB.xpBar
    if type(s)~='table' then s={};FHKEllesmereDB.xpBar=s end
    for k,v in pairs(DEFAULTS) do if s[k]==nil then s[k]=v end end
    -- Opacities (review C12), stored 0-1 and validated on every read.
    for k,l in pairs(OPACITY) do
        local v=s[k]
        if v~=nil or l[3]~=nil then s[k]=Plain(v) and math.max(l[1],math.min(l[2],v)) or l[3] end
    end
    local c=s.questColour
    if c~=nil and not (type(c)=='table' and Plain(c.r) and Plain(c.g) and Plain(c.b)) then s.questColour=nil end
    return s
end
-- Ellesmere 9.3.8 has its own Quest XP Overlay (XP Bar > Quest XP Overlay). While it is on,
-- ours stands down so the bar never shows two overlays.
local function NativeQuestOverlay()
    local ab=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIActionBars
    local p=ab and ab.EAB and ab.EAB.db and ab.EAB.db.profile
    local x=p and type(p.bars)=='table' and p.bars.XPBar
    return type(x)=='table' and x.questOverlay==true
end
NS.EllesmereNativeQuestOverlay=NativeQuestOverlay
local function QuestsOn(s) return s.quests and not NativeQuestOverlay() end
-- Quest events stay registered while the option is on (review X6), so turning Ellesmere's
-- own overlay off brings ours back on the next quest log update, not the next zone.
local function QuestsWanted(s) return s.quests and true or false end
local function Coloured() return NS.GetEllesmereThemePreset and NS.GetEllesmereThemePreset()=='coloured' end
local function Enabled()
    local s=NS.EllesmereXPBarSettings()
    return QuestsWanted(s) or s.smooth or s.glow or s.ticks or s.tooltip or NS.EllesmereXPNumberFormat()~='native' or Coloured()
end
local function Snapshot()
    local xp,maxXP,level=Read(UnitXP,'player'),Read(UnitXPMax,'player'),Read(UnitLevel,'player')
    if not Plain(xp) or not Plain(maxXP) or not Plain(level) or maxXP<=0 then return nil end
    return {xp=xp,max=maxXP,level=level}
end
local function Accent()
    if EUI.GetAccentColor then return EUI.GetAccentColor() end
    return 220/255,167/255,127/255
end
-- Pending quest XP in Coloured is a dimmed tint of the earned fill (player
-- decision: a forecast, not a second hue), mixed opaque over Ellesmere's track
-- so rested blue never shows through. Native gold otherwise; custom swatches win.
local QUEST_GOLD,QUEST_ALPHA=NS.Colours and NS.Colours.questXP or {1,.82,0},.55
local FORECAST,FORECAST_EDGE,TRACK=.5,.6,{.06,.06,.08}
local function EarnedColour()
    local r,g,b
    -- 9.3.8 gradient fills set the bar white and paint the colour as a gradient (review X5).
    local gradient=bar and type(bar._xpGrad)=='table' and bar._xpGrad.on
    if bar and not gradient then r,g,b=bar:GetStatusBarColor() end
    if Plain(r) and Plain(g) and Plain(b) then return r,g,b end
    local c=NS.Colours and NS.Colours.xpFill or {118/255,45/255,178/255}
    return c[1],c[2],c[3]
end
local function Forecast()
    local r,g,b=EarnedColour()
    return {r*FORECAST+TRACK[1]*(1-FORECAST),g*FORECAST+TRACK[2]*(1-FORECAST),b*FORECAST+TRACK[3]*(1-FORECAST)}
end
local function QuestColour(s)
    local c=s and s.questColour
    if type(c)=='table' and Plain(c.r) and Plain(c.g) and Plain(c.b) then return {c.r,c.g,c.b} end
    if Coloured() then return Forecast() end
    return QUEST_GOLD
end
-- A one-pixel bright edge follows each native fill; fill extent stays C-side.
local function ColourLine(source,sublevel,fill,accent,soft)
    if not source then return end
    local line=colourLines[source]
    local on=Coloured() and not (FHKEllesmereDB and FHKEllesmereDB.pixelIconEdges==false)
    local texture=on and source:GetStatusBarTexture()
    local r,g,b,a=source:GetStatusBarColor()
    if not texture or not Plain(r) or not Plain(g) or not Plain(b) or Secret(a) or a~=nil and not Plain(a) then
        if line then line:Hide() end
        return
    end
    if not line then
        if InCombatLockdown() then driver:RegisterEvent('PLAYER_REGEN_ENABLED');return end
        line=source:CreateTexture(nil,'ARTWORK',nil,sublevel);colourLines[source]=line
    end
    local vertical=source:GetOrientation()=='VERTICAL'
    local px=(EUI.PP and EUI.PP.perfect or 1)/source:GetEffectiveScale()
    if line._fill~=texture or line._vertical~=vertical or line._pixel~=px then
        line:ClearAllPoints()
        if vertical then
            line:SetPoint('TOPRIGHT',texture,'TOPRIGHT');line:SetPoint('BOTTOMRIGHT',texture,'BOTTOMRIGHT');line:SetWidth(px)
        else
            line:SetPoint('TOPLEFT',texture,'TOPLEFT');line:SetPoint('TOPRIGHT',texture,'TOPRIGHT');line:SetHeight(px)
        end
        line._fill,line._vertical,line._pixel=texture,vertical,px
    end
    if line._r~=r or line._g~=g or line._b~=b or line._a~=a or line._accent~=accent then
        line._accent=accent
        local neon=NS.EllesmereNeon and NS.EllesmereNeon(r,g,b)
        if fill and accent then
            local x,y,z=unpack(fill)
            if NS.EllesmereReadableBarFill then x,y,z=NS.EllesmereReadableBarFill(x,y,z) end
            if r==x and g==y and b==z then neon=accent end
        end
        local mx=math.max(r,g,b)
        if not neon then neon=mx>0 and {r/mx,g/mx,b/mx} or {0,0,0} end
        line:SetColorTexture(neon[1],neon[2],neon[3],(a or 1)*(soft or 1))
        line._r,line._g,line._b,line._a,line._edge=r,g,b,a,neon
    end
    line:Show()
end
local function PaintColours()
    if not bar then return end
    local C=NS.Colours or {}
    ColourLine(bar,4,C.xpFill,C.xpAccent)
    ColourLine(holder._restedBar,2,C.xpRestedFill,C.xpRestedAccent)
    -- The forecast edge repeats the earned edge, softer.
    local earned=colourLines[bar]
    ColourLine(overlay,3,Forecast(),earned and earned._edge,FORECAST_EDGE)
    if holder._text and NS.ApplyEllesmereCueText then NS.ApplyEllesmereCueText(holder._text,'bar') end
end
function NS.SyncEllesmereXPBarEdges() PaintColours() end
local function L(text) return EUI.L and EUI.L(text) or text end
-- XP number format (player: "nearest K, full value"): Ellesmere's own (full below 10,000,
-- 17.6K above), Full (17,600) or Rounded (18K). Every XP text Ellesmere draws goes through
-- the module formatter wrapped below, in 9.3.5's single readout and 9.3.8's text slots.
-- Saved as xpBar.numbers; an older Full XP Numbers toggle (fullNumbers) maps across.
function NS.EllesmereXPNumberFormat()
    local s=NS.EllesmereXPBarSettings()
    if s.numbers=='full' or s.numbers=='round' or s.numbers=='native' then return s.numbers end
    return s.fullNumbers==false and 'native' or 'full'
end
local function Number(n) return BreakUpLargeNumbers and BreakUpLargeNumbers(math.floor(n)) or tostring(math.floor(n)) end
local function SelectionAPI()
    -- Match Forever's vanilla quest window when its log-index API exists.
    if type(_G.GetQuestLogSelection)=='function' and type(_G.SelectQuestLogEntry)=='function' then
        return _G.GetQuestLogSelection,_G.SelectQuestLogEntry,true
    end
    if C_QuestLog then return C_QuestLog.GetSelectedQuest,C_QuestLog.SetSelectedQuest,false end
end

function NS.GetEllesmerePendingQuestXP()
    local log=C_QuestLog
    local count=log and Read(log.GetNumQuestLogEntries)
    if not Plain(count) or count<0 then return 0,0,0 end
    local total,known,complete,seen=0,0,0,{}
    local getSelected,setSelected,byIndex=SelectionAPI()
    local selected=Read(getSelected)
    local canSelect=Plain(selected) and type(setSelected)=='function'
    scanning=true
    for i=1,count do
        local info=Read(log.GetInfo,i)
        if type(info)=='table' and not Secret(info.isHeader) and not info.isHeader then
            local id=info.questID
            if Plain(id) and id>0 and not seen[id] then
                seen[id]=true
                if Read(log.ReadyForTurnIn,id)==true or Read(log.IsComplete,id)==true then
                    complete=complete+1
                    -- The native UI reads the selected quest without arguments.
                    -- Preserve selection; never assume a legacy API accepts a quest ID.
                    local reward
                    if canSelect and type(_G.GetQuestLogRewardXP)=='function' then
                        local wanted=id
                        if byIndex then
                            if Secret(info.questLogIndex) then wanted=nil else wanted=info.questLogIndex or i end
                        end
                        if Plain(wanted) then
                            if Read(getSelected)~=wanted then pcall(setSelected,wanted) end
                            if Read(getSelected)==wanted then reward=Read(_G.GetQuestLogRewardXP) end
                        end
                    end
                    if Plain(reward) and reward>0 then total=total+reward;known=known+1 end
                end
            end
        end
    end
    if canSelect and Read(getSelected)~=selected then pcall(setSelected,selected) end
    scanning=false
    return total,known,complete
end

local function StopGlow()
    if fade then fade:Stop() end
    if gain then gain:Hide() end
end
local function LayoutTicks()
    if not tickHost then return end
    local s=NS.EllesmereXPBarSettings()
    tickHost:SetShown(s.ticks)
    if not s.ticks then return end
    -- Ellesmere names it _divHost (review X3); _fvDivHost was only ever the test mock's name.
    nativeDividers=holder._divHost or holder._fvDivHost
    if nativeDividers then
        if hookedDividers~=nativeDividers then
            hookedDividers=nativeDividers
            nativeDividers:HookScript('OnShow',function(self)
                if applied and NS.EllesmereXPBarSettings().ticks then self:Hide() end
            end)
        end
        nativeDividers:Hide()
    end
    tickHost:SetFrameLevel(bar:GetFrameLevel()+1)
    local vertical=bar:GetOrientation()=='VERTICAL'
    local length=vertical and bar:GetHeight() or bar:GetWidth()
    local pixel=(EUI.PP and EUI.PP.perfect or 1)/tickHost:GetEffectiveScale()
    for i,t in ipairs(ticks) do
        -- Soft light marks in every theme (player review: black ticks chopped the
        -- coloured fill into blocks; modern progress bars keep one calm surface).
        if t._alpha~=s.tickOpacity then t:SetColorTexture(1,1,1,s.tickOpacity);t._alpha=s.tickOpacity end
        t:ClearAllPoints()
        if vertical then
            t:SetPoint('BOTTOMLEFT',bar,'BOTTOMLEFT',0,length*i/10)
            t:SetPoint('BOTTOMRIGHT',bar,'BOTTOMRIGHT',0,length*i/10);t:SetHeight(pixel)
        else
            t:SetPoint('TOPLEFT',bar,'TOPLEFT',length*i/10,0)
            t:SetPoint('BOTTOMLEFT',bar,'BOTTOMLEFT',length*i/10,0);t:SetWidth(pixel)
        end
    end
end
local function ForecastColour(s)
    local c=QuestColour(s)
    local r,g,b=c[1],c[2],c[3]
    if Coloured() and NS.EllesmereVividFillEnabled and NS.EllesmereVividFillEnabled() and NS.EllesmereReadableBarFill then
        r,g,b=NS.EllesmereReadableBarFill(r,g,b)
    end
    overlay:SetStatusBarColor(r,g,b,s and s.questOpacity or (Coloured() and 1 or QUEST_ALPHA))
end
-- Native earned-colour changes re-derive the forecast tint, then the edges.
local function EarnedRecoloured()
    if applied and overlay and overlay:IsShown() then ForecastColour(NS.EllesmereXPBarSettings()) end
    PaintColours()
end
local function Paint()
    if not applied or not bar then return end
    local s=NS.EllesmereXPBarSettings()
    if QuestsOn(s) then
        if not overlay then
            overlay=CreateFrame('StatusBar',nil,holder);overlay:SetAllPoints(bar)
            overlay:EnableMouse(false)
        end
        local now=Snapshot()
        if now and pendingXP>0 then
            local texture=bar:GetStatusBarTexture()
            overlay:SetFrameLevel(bar:GetFrameLevel())
            overlay:SetStatusBarTexture(texture and texture:GetTexture() or 'Interface\\Buttons\\WHITE8x8')
            overlay:GetStatusBarTexture():SetDrawLayer('ARTWORK',3)
            overlay:SetOrientation(bar:GetOrientation())
            overlay:SetRotatesTexture(bar:GetOrientation()=='VERTICAL')
            overlay:SetReverseFill(bar:GetReverseFill())
            overlay:SetMinMaxValues(0,now.max)
            overlay:SetValue(math.min(now.xp+pendingXP,now.max))
            ForecastColour(s);overlay:Show()
        else overlay:Hide() end
    elseif overlay then overlay:Hide() end
    if s.ticks and not tickHost then
        tickHost=CreateFrame('Frame',nil,bar);tickHost:SetAllPoints(bar);tickHost:EnableMouse(false)
        ticks={}
        for i=1,9 do
            local t=tickHost:CreateTexture(nil,'OVERLAY');t:SetColorTexture(1,1,1,s.tickOpacity);t._alpha=s.tickOpacity;ticks[i]=t
        end
    end
    LayoutTicks()
    PaintColours()
    if not s.glow then StopGlow() end
end
local function Calm() return NS.EllesmereReduceMotion and NS.EllesmereReduceMotion() end
local function Glow(from,to,maxXP)
    if not bar or not holder:IsShown() or to<=from or Calm() then return end
    if not gain then
        gain=bar:CreateTexture(nil,'OVERLAY',nil,1)
        fade=gain:CreateAnimationGroup()
        local alpha=fade:CreateAnimation('Alpha')
        alpha:SetFromAlpha(.85);alpha:SetToAlpha(0);alpha:SetDuration(.8);alpha:SetSmoothing('OUT')
        fade:SetScript('OnFinished',function() gain:Hide() end)
        fade.fromAlpha=alpha
    end
    StopGlow()
    local vertical=bar:GetOrientation()=='VERTICAL'
    local reverse=bar:GetReverseFill()
    local size=vertical and bar:GetHeight() or bar:GetWidth()
    local start=(reverse and 1-to/maxXP or from/maxXP)*size
    local length=(to-from)/maxXP*size
    gain:ClearAllPoints()
    if vertical then
        gain:SetPoint('BOTTOMLEFT',bar,'BOTTOMLEFT',0,start)
        gain:SetPoint('BOTTOMRIGHT',bar,'BOTTOMRIGHT',0,start);gain:SetHeight(length)
    else
        gain:SetPoint('TOPLEFT',bar,'TOPLEFT',start,0)
        gain:SetPoint('BOTTOMLEFT',bar,'BOTTOMLEFT',start,0);gain:SetWidth(length)
    end
    local r,g,b
    if Coloured() then r,g,b=bar:GetStatusBarColor() else r,g,b=Accent() end
    if not Plain(r) or not Plain(g) or not Plain(b) then r,g,b=Accent() end
    gain:SetColorTexture(r+(1-r)*.4,g+(1-g)*.4,b+(1-b)*.4,1)
    local opacity=NS.EllesmereXPBarSettings().glowOpacity
    fade.fromAlpha:SetFromAlpha(opacity)
    gain:SetAlpha(opacity);gain:Show();fade:Play()
end
local function XPChanged()
    local now=Snapshot()
    local s=NS.EllesmereXPBarSettings()
    if not now then previous=nil;StopGlow();Paint();return end
    if previous then
        local delta,from=0,previous.xp
        if now.level==previous.level and now.max==previous.max then delta=now.xp-previous.xp
        elseif now.level==previous.level+1 then delta=previous.max-previous.xp+now.xp;from=0 end
        if delta>0 then
            if s.tooltip then sessionXP=sessionXP+delta end
            if s.glow then Glow(from,now.xp,now.max) end
        elseif now.level~=previous.level or now.xp<previous.xp then StopGlow() end
    end
    previous=now;Paint()
end
local function Tooltip(self)
    if not applied or not GameTooltip or not GameTooltip:IsOwned(self) then return end
    local s=NS.EllesmereXPBarSettings()
    -- Pending quest XP is shown on the bar itself (player decision); no tooltip lines.
    if s.tooltip then
        local elapsed=sessionStart and GetTime()-sessionStart or 0
        local rate=elapsed>0 and sessionXP*3600/elapsed or 0
        GameTooltip:AddDoubleLine(L('This Session'),'+'..Number(sessionXP)..' ('..Number(rate)..'/hr)',1,1,1,1,1,1)
        local now=Snapshot()
        local seconds=now and rate>0 and (now.max-now.xp)*3600/rate
        local time=seconds and string.format('%dh %02dm',math.floor(seconds/3600),math.floor(seconds/60)%60) or L('Gathering Data')
        GameTooltip:AddDoubleLine(L('Time to Level'),time,1,1,1,1,1,1)
    end
    GameTooltip:Show()
end
local function Attach()
    if bar then return true end
    local rested=_G.EllesmereEAB_XPBar_Rested
    local candidate=rested and rested:GetParent()
    if not candidate or not candidate._bar or not candidate._bar.SetValue then return false end
    holder,bar=candidate,candidate._bar
    nativeSetValue=bar.SetValue
    hooksecurefunc(bar,'SetStatusBarColor',EarnedRecoloured)
    hooksecurefunc(holder._restedBar,'SetStatusBarColor',PaintColours)
    if holder._text and NS.ApplyEllesmereCueText then
        hooksecurefunc(holder._text,'SetFont',function(self) NS.ApplyEllesmereCueText(self,'bar',true) end)
    end
    lastValue,lastMax,lastLevel=Read(UnitXP,'player'),Read(UnitXPMax,'player'),Read(UnitLevel,'player')
    if not Plain(lastValue) or not Plain(lastMax) or not Plain(lastLevel) then lastValue,lastMax,lastLevel=nil,nil,nil end
    bar.SetValue=function(self,value,interpolation)
        if not applied then return nativeSetValue(self,value,interpolation) end
        local s=NS.EllesmereXPBarSettings()
        local maximum,level=Read(UnitXPMax,'player'),Read(UnitLevel,'player')
        if s.smooth and not Calm() and Plain(value) and Plain(maximum) and Plain(level) then
            local style=Enum and Enum.StatusBarInterpolation
            if style then
                interpolation=lastValue and lastLevel==level and lastMax==maximum and value>lastValue
                    and style.ExponentialEaseOut or style.Immediate
            end
            lastValue,lastMax,lastLevel=value,maximum,level
        else lastValue,lastMax,lastLevel=nil,nil,nil end
        local result=nativeSetValue(self,value,interpolation)
        Paint()
        return result
    end
    holder:HookScript('OnEnter',Tooltip)
    holder:HookScript('OnSizeChanged',function() StopGlow();Paint() end)
    holder:HookScript('OnShow',Paint)
    holder:HookScript('OnHide',StopGlow)
    return true
end
local function RefreshQuests()
    if QuestsOn(NS.EllesmereXPBarSettings()) then pendingXP,knownRewards,completedQuests=NS.GetEllesmerePendingQuestXP()
    else pendingXP,knownRewards,completedQuests=0,0,0 end
    Paint()
end
local function Queue(kind,delay,fn)
    if kind=='quest' then if questQueued then return end;questQueued=true
    else if xpQueued then return end;xpQueued=true end
    local token=generation
    C_Timer.After(delay,function()
        if token~=generation or not applied then return end
        if kind=='quest' then questQueued=false else xpQueued=false end
        fn()
    end)
end
driver:SetScript('OnEvent',function(_,event,unit)
    if event=='PLAYER_LOGIN' then NS.SyncEllesmereXPBar();return end
    if not applied or scanning then return end
    if event=='PLAYER_REGEN_ENABLED' then driver:UnregisterEvent(event);Paint();return end
    if event=='PLAYER_XP_UPDATE' and unit and unit~='player' then return end
    if event=='ADDON_LOADED' then Attach();Paint()
    elseif event=='QUEST_LOG_UPDATE' or event=='QUEST_TURNED_IN' then Queue('quest',.3,RefreshQuests)
    elseif event=='UI_SCALE_CHANGED' or event=='DISPLAY_SIZE_CHANGED' then StopGlow();Paint()
    elseif event=='PLAYER_ENTERING_WORLD' then
        Attach();previous=Snapshot();StopGlow();Queue('quest',.3,RefreshQuests);Paint()

    else Queue('xp',0,XPChanged) end
end)
-- Redraws the native readout after the full-number setting changes.
RefreshReadout=function()
    InstallFullNumbers()
    local ab=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIActionBars
    if ab and ab.ApplyDataBarLayout then pcall(ab.ApplyDataBarLayout,'XPBar') end
end
function NS.SyncEllesmereXPBar()
    generation=generation+1;questQueued,xpQueued=false,false
    driver:UnregisterAllEvents()
    applied=Enabled()
    local s=NS.EllesmereXPBarSettings()
    if s.tooltip and not tracking then sessionStart,sessionXP,previous=GetTime(),0,Snapshot() end
    tracking=s.tooltip
    if applied then
        Attach()
        RefreshReadout()
        local baseline=Snapshot()
        lastValue,lastMax,lastLevel=baseline and baseline.xp,baseline and baseline.max,baseline and baseline.level
        driver:RegisterEvent('ADDON_LOADED');driver:RegisterEvent('PLAYER_ENTERING_WORLD')
        if s.ticks or Coloured() then driver:RegisterEvent('UI_SCALE_CHANGED');driver:RegisterEvent('DISPLAY_SIZE_CHANGED') end
        if QuestsWanted(s) then driver:RegisterEvent('QUEST_LOG_UPDATE');driver:RegisterEvent('QUEST_TURNED_IN') end
        if s.glow or s.smooth or s.tooltip then
            driver:RegisterEvent('PLAYER_XP_UPDATE');driver:RegisterEvent('PLAYER_LEVEL_UP')
            previous=previous or Snapshot()
        end
        RefreshQuests()
    else
        previous,sessionStart,sessionXP=nil,nil,0
        if overlay then overlay:Hide() end
        if tickHost then tickHost:Hide() end
        StopGlow()
    end
    PaintColours()
    if not s.ticks and nativeDividers then
        local ab=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIActionBars
        if ab and ab.ApplyDataBarLayout then ab.ApplyDataBarLayout('XPBar') end
    end
end
-- Full XP values (player: "19k/25k need values in full not rounded"). Ellesmere's
-- XP readout is the only user of its module's number formatter, so supplying
-- grouped full numbers there makes the very first draw full; a rewrite after
-- the draw lost the race at login. Restricted values keep the native format.
InstallFullNumbers=function()
    local ab=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIActionBars
    if not ab or type(ab.AbbreviateLargeNumbers)~='function' or ab._fhkFullNumbers then return end
    local native=ab.AbbreviateLargeNumbers
    ab._fhkFullNumbers=native
    ab.AbbreviateLargeNumbers=function(n)
        local mode=NS.EllesmereXPNumberFormat()
        if Plain(n) and type(n)=='number' then
            if mode=='full' then return Number(n) end
            if mode=='round' and n>=1000 then
                local k=math.floor(n/1000+.5)
                return k>=1000 and (math.floor(k/100+.5)/10)..'M' or k..'K'
            end
        end
        return native(n)
    end
end
function NS.AddEllesmereXPBarOptions(Row)
    local s=NS.EllesmereXPBarSettings()
    local function Toggle(key,text,tooltip)
        return {type='toggle',text=text,tooltip=tooltip,getValue=function() return s[key] end,
            setValue=function(v) s[key]=v;NS.SyncEllesmereXPBar() end}
    end
    -- Ellesmere's row tools (review C12): each look has its opacity cog and colour swatch on
    -- its own toggle; they grey out with the reason while the toggle is off (review C9).
    local function Percent(label,key,min,max,fallback,tooltip)
        return {type='slider',label=label,min=min,max=max,step=1,tooltip=tooltip,
            get=function() local v=s[key];if not Plain(v) then v=fallback() end;return math.floor(v*100+.5) end,
            set=function(v) if Plain(v) then s[key]=v/100;NS.EllesmereXPBarSettings();NS.SyncEllesmereXPBar();Paint() end end}
    end
    local NATIVE="Ellesmere's Quest XP Overlay (XP Bar page)"
    local questsOff=function() return not s.quests or NativeQuestOverlay() end
    local questsWhy=function() return NativeQuestOverlay() and 'This option is off while Ellesmere\'s own Quest XP Overlay is on' or 'Completed Quest XP' end
    local quests=Toggle('quests','Completed Quest XP','Shows known XP from completed quests awaiting turn-in. Stands down while Ellesmere\'s own Quest XP Overlay is on.')
    quests.disabled=NativeQuestOverlay;quests.disabledTooltip=NATIVE;quests.requireState='disabled'
    quests.swatches={{tooltip='Completed Quest XP Color',hasAlpha=false,disabled=questsOff,disabledTooltip=questsWhy,
        getValue=function() local c=QuestColour(s);return c[1],c[2],c[3],1 end,
        setValue=function(r,g,b) if Plain(r) and Plain(g) and Plain(b) then s.questColour={r=r,g=g,b=b};Paint() end end}}
    quests.cog={title='Completed Quest XP',disabled=questsOff,disabledTooltip=questsWhy,rows={
        Percent('Opacity %','questOpacity',10,100,function() return Coloured() and 1 or QUEST_ALPHA end,
            'The Colored theme shows it opaque and other themes at 55% until you choose.')}}
    Row(quests,
        Toggle('smooth','Smooth XP Fill','Eases gains and snaps when the level changes.'))
    local glow=Toggle('glow','XP Gain Glow','Briefly highlights the experience you just earned.')
    glow.cog={title='XP Gain Glow',disabled=function() return not s.glow end,disabledTooltip='XP Gain Glow',rows={
        Percent('Opacity %','glowOpacity',10,100,function() return OPACITY.glowOpacity[3] end)}}
    local ticks=Toggle('ticks','10% XP Ticks','Replaces native dividers with subtle ten-percent marks.')
    ticks.cog={title='10% XP Ticks',disabled=function() return not s.ticks end,disabledTooltip='10% XP Ticks',rows={
        Percent('Opacity %','tickOpacity',5,60,function() return OPACITY.tickOpacity[3] end)}}
    Row(glow,ticks)
    Row(Toggle('tooltip','Session XP Tooltip','Adds session XP, XP per hour and estimated time to level.'),
        {type='dropdown',text='XP Number Format',values={native='Ellesmere (17.6K)',full='Full (17,600)',round='Rounded (18K)'},order={'native','full','round'},
            tooltip='How XP numbers show. Ellesmere: in full below 10,000, then one decimal (17.6K). Full: always every digit. Rounded: the nearest thousand (18K). Ellesmere 9.3.8 text slots always show values under 10,000 in full.',
            getValue=function() return NS.EllesmereXPNumberFormat() end,
            setValue=function(v) s.numbers=v;s.fullNumbers=(v=='full');NS.SyncEllesmereXPBar() end})
    Row({type='label',text='Quest XP unavailable? Check /fhkxp'},
        {type='button',text='Default Quest XP Color',tooltip='Returns the completed quest XP to the theme color.',
            disabled=function() return s.questColour==nil end,disabledTooltip='This option is available after picking a quest XP color',
            onClick=function() s.questColour=nil;Paint() end})
    if NS.EllesmereSectionReset then
        Row(NS.EllesmereSectionReset('XP Bar Refinements',function()
            for k in pairs(s) do s[k]=nil end
            NS.EllesmereXPBarSettings();NS.SyncEllesmereXPBar();Paint()
        end),{type='label',text='Text slots show values under 10,000 in full'})
    end
end
InstallFullNumbers()
SLASH_FHKXP1='/fhkxp'
SlashCmdList.FHKXP=function()
    local xp,known,complete=NS.GetEllesmerePendingQuestXP()
    local status=type(_G.GetQuestLogRewardXP)=='function' and 'present (rewards need an in-game check)' or 'unavailable'
    local getSelected,setSelected,byIndex=SelectionAPI()
    local selection=Plain(Read(getSelected)) and type(setSelected)=='function'
    print('FHK XP: reward API '..status..'; selection API '..(selection and 'ready' or 'unavailable')..
        (selection and (byIndex and ' (log index)' or ' (quest ID)') or '')..
        '; completed '..complete..'; known rewards '..known..'; pending XP '..Number(xp)..'.')
end
if EUI.RegAccent then EUI.RegAccent({type='callback',fn=Paint}) end
driver:RegisterEvent('PLAYER_LOGIN')
