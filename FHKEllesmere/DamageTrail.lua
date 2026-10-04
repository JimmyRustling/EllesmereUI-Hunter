-- Damage flash: the lost-health segment shows in red and drains quickly towards
-- the new value; the real fill and health text stay immediate (player request).
-- Readable values use a timed drain. Restricted (secret) values, the normal case
-- in combat, use an invisible helper bar that eases natively toward the secret
-- value; a red texture between the bar background and fill is anchored to it.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end
local driver=CreateFrame('Frame')
local tracked=setmetatable({}, {__mode='k'})
local active={}
local function Plain(v)
    return not (issecretvalue and issecretvalue(v)) and type(v)=='number' and v==v and math.abs(v)<math.huge
end
function NS.EllesmereDamageTrailSettings(kind)
    FHKEllesmereDB=FHKEllesmereDB or {}
    FHKEllesmereDB.damageTrails=FHKEllesmereDB.damageTrails or {}
    local all=FHKEllesmereDB.damageTrails
    if not rawget(FHKEllesmereDB,'quickDamageTrailApplied') then
        local before={}
        for _,key in ipairs({'unitframes','nameplates'}) do
            local s=all[key]
            if s and s.duration==.28 then before[key]=s.duration;s.duration=.18 end
        end
        rawset(FHKEllesmereDB,'damageTrailDurationBefore',before)
        rawset(FHKEllesmereDB,'quickDamageTrailApplied',true)
    end
    -- colour nil is the damage red; a picked colour is stored.
    all[kind]=all[kind] or {enabled=true,duration=.18,opacity=.85}
    local s=all[kind]
    if s.instantHealth==nil then s.instantHealth=true end
    -- The faint accent default (40%) read as no feedback at all: move the old
    -- default once to the clearer red flash. Picked values are kept.
    if s.redFlash==nil then
        if s.opacity==.4 then s.opacity=.85 end
        s.redFlash=true
    end
    return s
end
local DAMAGE=(NS.Colours and NS.Colours.damage) or {.86,.18,.16}
local function TrailColour(cfg)
    local c=cfg.colour
    if c then return c.r,c.g,c.b end
    return DAMAGE[1],DAMAGE[2],DAMAGE[3]
end
local EASE=Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
local IMMEDIATE=Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate
local function HideNative(state)
    if state.native then state.native:Hide() end
    state.snap=true
end
-- Secret-safe path: never compares or subtracts the value; only hands it to
-- native setters that accept restricted values.
local function Native(bar,state,cfg,value)
    if not EASE or (bar.GetOrientation and bar:GetOrientation()=='VERTICAL') then return false end
    local h=state.helper
    if not h then
        h=CreateFrame('StatusBar',nil,bar);h:SetAllPoints(bar);h:EnableMouse(false)
        h:SetStatusBarTexture('Interface\\Buttons\\WHITE8X8')
        local fill=h:GetStatusBarTexture();if fill and fill.SetAlpha then fill:SetAlpha(0) end
        state.helper=h
        -- BORDER: above the bar background, under the real (ARTWORK) fill.
        state.native=bar:CreateTexture(nil,'BORDER')
    end
    local reverse=bar.GetReverseFill and bar:GetReverseFill() and true or false
    if state.reverse~=reverse then
        state.reverse=reverse;h:SetReverseFill(reverse)
        local t,fill=state.native,h:GetStatusBarTexture()
        t:ClearAllPoints()
        if reverse then
            t:SetPoint('TOPRIGHT',bar,'TOPRIGHT',0,0);t:SetPoint('BOTTOMLEFT',fill,'BOTTOMLEFT',0,0)
        else
            t:SetPoint('TOPLEFT',bar,'TOPLEFT',0,0);t:SetPoint('BOTTOMRIGHT',fill,'BOTTOMRIGHT',0,0)
        end
    end
    h:SetMinMaxValues(bar:GetMinMaxValues())
    local r,g,b=TrailColour(cfg)
    state.native:SetColorTexture(r,g,b,cfg.opacity or .85)
    if state.snap then h:SetValue(value,IMMEDIATE or 0);state.snap=nil
    else h:SetValue(value,EASE) end
    state.native:Show()
    return true
end
local function Clear(bar,state)
    active[bar]=nil;state.value,state.minimum,state.maximum,state.from,state.guid=nil,nil,nil,nil,nil
    if state.texture then state.texture:Hide() end
    HideNative(state)
    if not next(active) then driver:SetScript('OnUpdate',nil) end
end
local function Geometry(bar,state,t)
    local current,old=state.value,state.from
    local span=state.maximum-state.minimum
    local lo=(current-state.minimum)/span
    local hi=(old-state.minimum)/span
    -- Fast ease towards the current health. A rapid second hit extends the
    -- same texture rather than allocating another animation/frame.
    hi=lo+(hi-lo)*(1-t)*(1-t)
    local reverse=bar.GetReverseFill and bar:GetReverseFill()
    local vertical=bar.GetOrientation and bar:GetOrientation()=='VERTICAL'
    local size=vertical and bar:GetHeight() or bar:GetWidth()
    local start=reverse and (1-hi)*size or lo*size
    local length=math.max(0,(hi-lo)*size)
    local tex=state.texture
    tex:ClearAllPoints()
    if vertical then
        tex:SetPoint('BOTTOMLEFT',bar,'BOTTOMLEFT',0,start)
        tex:SetPoint('BOTTOMRIGHT',bar,'BOTTOMRIGHT',0,start);tex:SetHeight(length)
    else
        tex:SetPoint('TOPLEFT',bar,'TOPLEFT',start,0)
        tex:SetPoint('BOTTOMLEFT',bar,'BOTTOMLEFT',start,0);tex:SetWidth(length)
    end
    -- Full strength while it drains; a short fade only at the very end.
    tex:SetAlpha(state.opacity*(t<.7 and 1 or (1-t)/.3));tex:Show()
end
local function Animate(_,dt)
    for bar,state in pairs(active) do
        local cfg=NS.EllesmereDamageTrailSettings(state.kind)
        state.elapsed=state.elapsed+dt
        local t=math.min(1,state.elapsed/state.duration)
        if t>=1 or cfg.enabled==false or not bar:IsShown() then
            if state.texture then state.texture:Hide() end
            active[bar]=nil
        else Geometry(bar,state,t) end
    end
    if not next(active) then driver:SetScript('OnUpdate',nil) end
end
local function Changed(bar,value)
    local state=tracked[bar]
    if not state then return end
    local cfg=NS.EllesmereDamageTrailSettings(state.kind)
    -- Finish native interpolation without inspecting health, including secret values.
    if cfg.enabled~=false and cfg.instantHealth~=false and bar.SetToTargetValue then bar:SetToTargetValue() end
    local guid=state.unit and UnitGUID and UnitGUID(state.unit)
    if issecretvalue and issecretvalue(guid) then guid=nil end
    if state.guid and guid and state.guid~=guid then Clear(bar,state) end
    state.guid=guid or state.guid
    local minimum,maximum=bar:GetMinMaxValues()
    if cfg.enabled==false or NS.EllesmereReduceMotion and NS.EllesmereReduceMotion() then Clear(bar,state);return end
    -- Restricted values cannot be compared or subtracted here: hand them to the
    -- native eased helper instead of dropping the feedback.
    if not Plain(value) or not Plain(minimum) or not Plain(maximum) then
        active[bar]=nil;if state.texture then state.texture:Hide() end
        state.value,state.minimum,state.maximum,state.from=nil,nil,nil,nil
        if not next(active) then driver:SetScript('OnUpdate',nil) end
        if not Native(bar,state,cfg,value) then HideNative(state) end
        return
    end
    if state.native and state.native:IsShown() then HideNative(state) end
    if maximum<=minimum then Clear(bar,state);return end
    value=math.max(minimum,math.min(maximum,value))
    local previous=state.value
    if state.minimum~=minimum or state.maximum~=maximum then
        Clear(bar,state);state.guid=guid;previous=nil
    end
    state.minimum,state.maximum=minimum,maximum
    if previous and value<previous then
        if not state.texture then
            state.texture=bar:CreateTexture(nil,'OVERLAY',nil,1)
            if EUI.PP and EUI.PP.DisablePixelSnap then EUI.PP.DisablePixelSnap(state.texture) end
        end
        local r,g,b=TrailColour(cfg)
        state.texture:SetColorTexture(r,g,b,1)
        local edge=previous
        if active[bar] then
            local progress=math.min(1,state.elapsed/state.duration)
            edge=previous+((state.from or previous)-previous)*(1-progress)*(1-progress)
        end
        state.from=math.max(previous,edge)
        state.value,state.elapsed,state.duration,state.opacity=value,0,math.max(.1,cfg.duration or .18),cfg.opacity or .4
        active[bar]=state
        Geometry(bar,state,0);driver:SetScript('OnUpdate',Animate)
    else
        state.value=value
        if previous and value>previous then
            active[bar]=nil;if state.texture then state.texture:Hide() end
            if not next(active) then driver:SetScript('OnUpdate',nil) end
        end
    end
end
function NS.AttachEllesmereDamageTrail(bar,unit,kind)
    if not bar or not bar.GetValue or not bar.GetMinMaxValues or not bar.SetValue then return end
    local state=tracked[bar]
    if not state then
        state={unit=unit,kind=kind};tracked[bar]=state
        hooksecurefunc(bar,'SetValue',Changed)
        if bar.HookScript then bar:HookScript('OnHide',function() Clear(bar,state) end) end
    elseif state.unit~=unit then Clear(bar,state);state.unit=unit end
    if state.value==nil then Changed(bar,bar:GetValue()) end
end
function NS.ClearEllesmereDamageTrails()
    for bar,state in pairs(tracked) do Clear(bar,state) end
    driver:SetScript('OnUpdate',nil)
end
function NS.AddEllesmereDamageTrailOptions(Row,kind)
    local s=NS.EllesmereDamageTrailSettings(kind)
    Row({type='toggle',text='Damage Flash',tooltip='Lost health shows in red and drains quickly; the real health fill and text update at once.',getValue=function() return s.enabled end,
        setValue=function(v) s.enabled=v;NS.ClearEllesmereDamageTrails() end},
        {type='slider',text='Damage Flash Duration',tooltip='Readable values only; in combat the game eases the flash at its own speed.',min=.1,max=.6,step=.02,
            getValue=function() return s.duration end,setValue=function(v) s.duration=v end})
    Row({type='toggle',text='Instant Health Feedback',
        tooltip='Health text and the real fill update immediately; only the lost-health segment drains. Overrides native health smoothing while Damage Trail is enabled.',
        getValue=function() return s.instantHealth end,setValue=function(v) s.instantHealth=v;NS.ClearEllesmereDamageTrails() end},
        {type='label',text='Only the lost-health segment animates'})
    Row({type='slider',text='Damage Flash Opacity %',min=10,max=100,step=5,
        getValue=function() return math.floor((s.opacity or .85)*100+.5) end,setValue=function(v) s.opacity=v/100 end},
        {type='colorpicker',text='Damage Flash Color',hasAlpha=false,
            getValue=function() local r,g,b=TrailColour(s);return r,g,b,1 end,
            setValue=function(r,g,b) s.colour={r=r,g=g,b=b} end},true)
end
driver:RegisterEvent('PLAYER_TARGET_CHANGED');driver:RegisterEvent('NAME_PLATE_UNIT_ADDED')
driver:RegisterEvent('NAME_PLATE_UNIT_REMOVED');driver:RegisterEvent('PLAYER_ENTERING_WORLD')
driver:SetScript('OnEvent',function(_,event,unit)
    for bar,state in pairs(tracked) do
        if event=='PLAYER_ENTERING_WORLD' or event=='PLAYER_TARGET_CHANGED' and (state.unit=='target' or state.unit=='targettarget') or state.unit==unit then Clear(bar,state) end
    end
    if not next(active) then driver:SetScript('OnUpdate',nil) end
end)
