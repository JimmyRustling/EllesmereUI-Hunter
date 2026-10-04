-- Extend the installed text-zone API and option widgets without editing EUI.
local EUI, FHK = _G.EllesmereUI, (_G.FHKEllesmereNS or _G.ForeverHunterKeysNS)
if EUI_CLIENT_BLOCKED or not EUI or not FHK then return end
local driver = CreateFrame('Frame')
local installed, widgetFactory, powerFeedbackHooked
local function IsUnitFrame(frame)
    local kind = type(frame)
    return (kind == 'table' or kind == 'userdata') and type(frame.GetFrameLevel) == 'function' and
        type(frame._euiUnit or frame._euiBaseUnit) == 'string'
end
local C = FHK.Colours or {}
local white, coolWhite, amber, coral = C.text or {.96, .945, .925}, C.resourceText or {.87, .91, .96},
    C.caution or {1, .82, 0}, C.danger or {1, .3, .25}
local orange = C.worry or {1, .5, .25}
local resourceZones = setmetatable({}, {__mode='k'})
-- True when the bar fill carries the health warning, so the number can stay
-- white like Blizzard's own frames (one warning at a time). Assigned below,
-- after the dark-mode helpers.
local FillsWarn
-- The unit's resource colour as neon (dark mode power text and line). Assigned
-- below, beside ResourceColor.
local ResourceNeon
local function PublicNumber(v)
    return not (issecretvalue and issecretvalue(v)) and type(v) == 'number'
end
local function Dark() return FHK.EllesmereDarkMode and FHK.EllesmereDarkMode() or false end
local function OwnUnit(unit)
    if (issecretvalue and issecretvalue(unit)) or type(unit)~='string' then return false end
    if unit=='player' or unit=='pet' then return true end
    if UnitIsUnit then
        local player,pet=UnitIsUnit(unit,'player'),UnitIsUnit(unit,'pet')
        return (not (issecretvalue and issecretvalue(player)) and player==true) or
            (not (issecretvalue and issecretvalue(pet)) and pet==true)
    end
    return false
end
-- Neon: a colour at full brightness with at least 60 % saturation, so it glows
-- against the black of dark mode while keeping its hue.
local function Neon(r, g, b)
    if not (PublicNumber(r) and PublicNumber(g) and PublicNumber(b)) then return nil end
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    if mx - mn < .001 then return {1, 1, 1} end
    local s = math.max((mx - mn) / math.max(mx, .001), .6)
    local function Channel(c) return 1 - s * (1 - (c - mn) / (mx - mn)) end
    return {Channel(r), Channel(g), Channel(b)}
end
-- Dark mode text at rest: the player's class colour as neon (theme aligned; for
-- a hunter, neon lime, WoW's own healthy green). Warnings take over below 60 %.
local function NeonClass()
    local _, class = UnitClass('player')
    if not class or (issecretvalue and issecretvalue(class)) then return white end
    local c = EUI.GetClassColor and EUI.GetClassColor(class) or RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return c and Neon(c.r, c.g, c.b) or white
end
FHK.EllesmereNeon, FHK.EllesmereNeonClass = Neon, NeonClass
-- Text ramp in WoW's own order: rest colour (white, or neon in dark mode), gold
-- at 40 %, orange at 25 %, red at 10 %.
local function HealthColorAt(pct, top)
    top = top or white
    if pct >= .60 then return top end
    if pct <= .10 then return coral end
    local from, to, t
    if pct >= .40 then from, to, t = amber, top, (pct - .40) / .20
    elseif pct >= .25 then from, to, t = orange, amber, (pct - .25) / .15
    else from, to, t = coral, orange, (pct - .10) / .15 end
    t = t * t * (3 - 2 * t)
    return {from[1] + (to[1] - from[1]) * t,
        from[2] + (to[2] - from[2]) * t, from[3] + (to[3] - from[3]) * t}
end
local function HealthColor(unit, context, key)
    if not OwnUnit(unit) then return end
    if not unit or not UnitExists(unit) then return end
    if context and FillsWarn(context, key, unit) then return white end
    local hp, max = UnitHealth(unit), UnitHealthMax(unit)
    if not PublicNumber(hp) or not PublicNumber(max) or max <= 0 then return end
    -- Off hands text colour back to Ellesmere (audit F16).
    if FHKEllesmereDB and FHKEllesmereDB.healthTextColors == false then return end
    return HealthColorAt(math.max(0, math.min(1, hp / max)), Dark() and NeonClass() or nil)
end
FHK.EllesmereHealthColor = HealthColor
-- Health text keeps warning when health is restricted (combat): the same colour
-- ramp as a native curve, evaluated C-side by UnitHealthPercent and applied as a
-- vertex tint over white text, so Lua never compares the value.
-- One curve per rest colour (white, or the neon of dark mode), built once each.
local healthTextCurves = {}
local function HealthTextCurve()
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return end
    local top = Dark() and NeonClass() or white
    local id = string.format('%.3f/%.3f/%.3f', top[1], top[2], top[3])
    if healthTextCurves[id] then return healthTextCurves[id] end
    local curve = C_CurveUtil.CreateColorCurve()
    for i = 0, 40 do
        local c = HealthColorAt(i / 40, top)
        curve:AddPoint(i / 40, CreateColor(c[1], c[2], c[3], 1))
    end
    healthTextCurves[id] = curve
    return curve
end
-- context/key name the bar beside the text ('unitframes', 'nameplates',
-- 'resourcebars' + key). Without one the text always warns.
function FHK.PaintEllesmereHealthText(fs, unit, context, key)
    if not fs or not fs.SetTextColor then return false end
    if FHK.ApplyEllesmereCueText then FHK.ApplyEllesmereCueText(fs,'bar') end
    if not OwnUnit(unit) then
        if fs._fhkTint then fs:SetVertexColor(1,1,1,1);fs._fhkTint=nil end
        if not (FHKEllesmereDB and FHKEllesmereDB.healthTextColors==false) then fs:SetTextColor(unpack(white)) end
        return false -- enemy values retain native colour, with the stronger outline
    end
    local off = FHKEllesmereDB and FHKEllesmereDB.healthTextColors == false
    if not off and context and unit and UnitExists(unit) and FillsWarn(context, key, unit) then
        if fs._fhkTint then fs:SetVertexColor(1, 1, 1, 1); fs._fhkTint = nil end
        fs:SetTextColor(white[1], white[2], white[3], 1)
        return true
    end
    local c = not off and HealthColor(unit)
    if c then
        if fs._fhkTint then fs:SetVertexColor(1, 1, 1, 1); fs._fhkTint = nil end
        fs:SetTextColor(c[1], c[2], c[3], 1)
        return true
    end
    if not off and unit and UnitExists(unit) and UnitHealthPercent and fs.SetVertexColor then
        local curve = HealthTextCurve()
        local colour = curve and UnitHealthPercent(unit, true, curve)
        if colour and colour.GetRGB then
            fs:SetTextColor(1, 1, 1, 1); fs:SetVertexColor(colour:GetRGB()); fs._fhkTint = true
            return true
        end
    end
    if fs._fhkTint then fs:SetVertexColor(1, 1, 1, 1); fs._fhkTint = nil end
    return false
end
local function HealthEscape(unit)
    local c = HealthColor(unit, 'unitframes')
    if not c then return '' end
    return string.format('|cff%02x%02x%02x', math.floor(c[1] * 255 + .5),
        math.floor(c[2] * 255 + .5), math.floor(c[3] * 255 + .5))
end
local function ResourceType(unit)
    local resolved = _G._EUI_ResolvedPowerType and _G._EUI_ResolvedPowerType[unit]
    if unit == 'player' and EUI.GetPlayerPowerOverride then resolved = EUI.GetPlayerPowerOverride() or resolved end
    if PublicNumber(resolved) then return resolved end
    local kind = UnitPowerType(unit)
    return PublicNumber(kind) and kind or nil
end
local barStates = setmetatable({}, {__mode='k'})
-- Fills: deeper versions of the same WoW gold/orange/red, readable under white text.
local fillMid, fillLow, fillCritical = C.healthMid or {.772, .632, 0}, C.healthLow or {.717, .338, .086},
    C.healthCritical or {.695, .137, .097}
local function Blend(a, b, t)
    if t >= 1 then return b[1],b[2],b[3] end
    if t <= 0 then return a[1],a[2],a[3] end
    t = t * t * (3 - 2 * t)
    return a[1]+(b[1]-a[1])*t, a[2]+(b[2]-a[2])*t, a[3]+(b[3]-a[3])*t
end
-- Health warns with colour (base -> yellow -> orange -> red). Resources keep
-- their own colour and only lose brightness as they empty, so warm warning
-- colours always mean health.
local RESOURCE_FLOOR = .45
local VIVID_HOLD = .6
local function Shade(state, p)
    local base=state.vividBase or state.base
    if state.resource then
        local k = RESOURCE_FLOOR + (1 - RESOURCE_FLOOR) * p
        return base[1]*k, base[2]*k, base[3]*k
    end
    local mid,low,critical=state.warningMid or fillMid,state.warningLow or fillLow,state.warningCritical or fillCritical
    -- Coloured holds the class colour while health is not a concern: a long
    -- RGB blend of deep class green toward gold reads olive (player rejected).
    if state.vividBase then
        if p>=VIVID_HOLD then return base[1],base[2],base[3] end
        if p>=.5 then return Blend(mid,base,(p-.5)/(VIVID_HOLD-.5)) end
    end
    if p>=.5 then return Blend(mid,base,(p-.5)/.5)
    elseif p>=.25 then return Blend(low,mid,(p-.25)/.25) end
    return Blend(critical,low,p/.25)
end
local vividWarningStops
-- Pet health is WoW's friendly green, deepened (#2E9E33, hue 123: the friendly
-- reaction hue). 34 deg from hunter lime, 39 deg from the jade shooting fill
-- (the old #2C9F5F sat 16 deg from jade, audit 2026-10-03).
local vividPetBase={46/255,158/255,51/255}
local vividClassBases={}
local function VividBase(state)
    local healthy=OwnUnit(state.unit)
    local on=healthy and FHK.EllesmereVividFillEnabled and FHK.EllesmereVividFillEnabled()
    local base=state.base
    local classIdentity=false
    if on and not state.resource then
        local pet=state.unit=='pet' or UnitIsUnit and UnitIsUnit(state.unit,'pet')
        if not (issecretvalue and issecretvalue(pet)) and pet==true then
            base=vividPetBase
        else
            local _,class=UnitClass('player')
            if not (issecretvalue and issecretvalue(class)) and type(class)=='string' then
                local c=EUI.GetClassColor and EUI.GetClassColor(class)
                if c and not (issecretvalue and issecretvalue(c)) and
                    PublicNumber(c.r) and PublicNumber(c.g) and PublicNumber(c.b) then
                    local cached=state.classBase
                    if not cached or cached[1]~=c.r or cached[2]~=c.g or cached[3]~=c.b then
                        cached={c.r,c.g,c.b};state.classBase=cached
                    end
                    base=cached;classIdentity=true
                else
                    local w=EUI.CLASS_COLOR_MAP and EUI.CLASS_COLOR_MAP[class]
                    if w then
                        local cached=vividClassBases[class]
                        if not cached then cached={w.r,w.g,w.b};vividClassBases[class]=cached end
                        base=cached;classIdentity=true
                    end
                end
            end
        end
    end
    if state.vividOn==on and state.vividHealthy==healthy and state.vividR==base[1] and
        state.vividG==base[2] and state.vividB==base[3] and state.vividClass==classIdentity then return end
    state.vividClass=classIdentity
    state.vividOn,state.vividHealthy=on,healthy
    state.vividR,state.vividG,state.vividB=base[1],base[2],base[3]
    local prior=state.vividBase
    state.vividBase=nil
    state.warningMid,state.warningLow,state.warningCritical=nil,nil,nil
    if on and FHK.EllesmereReadableBarFill then
        -- Your class bar is WoW's class colour as is (player); pet and warning
        -- fills keep the readable cap.
        local r,g,b=base[1],base[2],base[3]
        if not classIdentity then r,g,b=FHK.EllesmereReadableBarFill(base[1],base[2],base[3]) end
        if prior and prior[1]==r and prior[2]==g and prior[3]==b then state.vividBase=prior
        else state.vividBase={r,g,b} end
        if not vividWarningStops then
            vividWarningStops={{FHK.EllesmereReadableBarFill(unpack(fillMid))},
                {FHK.EllesmereReadableBarFill(unpack(fillLow))},{FHK.EllesmereReadableBarFill(unpack(fillCritical))}}
        end
        state.warningMid,state.warningLow,state.warningCritical=unpack(vividWarningStops)
    end
    if state.vividBase~=prior then state.curve=nil end
end
-- Hunter pet: the paw icon shows happiness (Forever C_PetInfo, 1-3); the pet's
-- bar shows health like every other bar (player decision). Happiness as the
-- fill colour is opt-in (petHappinessColors == true).
local HAPPINESS = {[1]=C.unhappy or {1,.3,.25},[2]=C.content or {1,.82,0},[3]=C.happy or {.30,.85,.30}}
local function Mood()
    if not (C_PetInfo and C_PetInfo.GetPetHappiness) then return end
    local ok, happiness = pcall(C_PetInfo.GetPetHappiness)
    if ok and PublicNumber(happiness) then return HAPPINESS[happiness], happiness end
end
-- Hide When Happy (forum request): happiness shows only when it needs attention.
local function HideHappy() return FHKEllesmereDB and FHKEllesmereDB.petMoodHideHappy == true end
local function ShownMood()
    local colour, happiness = Mood()
    if happiness == 3 and HideHappy() then return end
    return colour
end
local function PetHappinessColor(state)
    if state.resource or state.unit ~= 'pet' then return end
    if not (FHKEllesmereDB and FHKEllesmereDB.petHappinessColors == true) then return end
    return Mood()
end
local function NativeDark()
    local uf=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIUnitFrames
    return uf and uf.db and uf.db.profile and uf.db.profile.darkTheme
end
-- Dark mode owns the bar fill; warnings move to the text (player decision).
-- Unit frames share one switch; Resource Bars have one per bar (health/primary).
local function DarkFor(state)
    if state.context == 'unitframes' then return NativeDark() end
    -- Ellesmere has no dark nameplates; the companion follows the same switch.
    if state.context == 'nameplates' then return Dark() end
    if state.context == 'resourcebars' then
        local rb = EUI._ModuleNS and EUI._ModuleNS.EllesmereUIResourceBars
        local p = rb and rb.ERB and rb.ERB.db and rb.ERB.db.profile
        local section = p and state.key and p[state.key]
        return type(section) == 'table' and section.darkTheme == true
    end
end
FillsWarn = function(context, key, unit)
    local db = FHKEllesmereDB
    if db and db.healthBarColors == false then return false end
    -- An opt-in happiness fill no longer shows health, so the text keeps warning.
    if unit == 'pet' and db and db.petHappinessColors == true then return false end
    return not DarkFor({context=context, key=key})
end
-- Dark themes keep the pet fill dark and show happiness as a thin placeable strip.
local MOOD_DEFAULTS={side='top',thickness=2,gap=0,length=100,align='center',opacity=1,always=false}
function FHK.EllesmerePetMoodSettings()
    FHKEllesmereDB=FHKEllesmereDB or {}
    local s=FHKEllesmereDB.petMoodStrip
    if type(s)~='table' then s={}; FHKEllesmereDB.petMoodStrip=s end
    -- The icon now carries happiness in every theme: the "all themes" strip that
    -- an earlier reviewed preset forced on is switched off once (player decision).
    if s.iconCarriesMood==nil then s.always=false; s.iconCarriesMood=true end
    for k,v in pairs(MOOD_DEFAULTS) do if s[k]==nil then s[k]=v end end
    return s
end
local function MoodStripWanted()
    return NativeDark() or FHK.EllesmerePetMoodSettings().always==true
end
local function Pixel(v) return EUI.PP and EUI.PP.FromPixels and EUI.PP.FromPixels(v) or v end
local function PaintMoodStrip(frame, colour)
    local t = frame._fhkMoodStrip
    if not colour then if t then t:Hide() end return end
    local host = frame.Health
    if not host then return end
    if not t then
        local holder = CreateFrame('Frame', nil, frame)
        holder:SetAllPoints(host); holder:SetFrameLevel(frame:GetFrameLevel() + 21); holder:EnableMouse(false)
        t = holder:CreateTexture(nil, 'OVERLAY'); frame._fhkMoodStrip = t
    end
    local s = FHK.EllesmerePetMoodSettings()
    local width = host:GetWidth() or 0
    local key = table.concat({s.side, s.thickness, s.gap, s.length, s.align, math.floor(width + .5)}, ':')
    if t._key ~= key then
        t:ClearAllPoints()
        local size, gap = Pixel(s.thickness), Pixel(s.gap)
        if s.side == 'left' or s.side == 'right' then
            local edge = s.side == 'left' and 'LEFT' or 'RIGHT'
            local dx = s.side == 'left' and -gap or gap
            t:SetPoint('TOP'..edge, host, 'TOP'..edge, dx, 0); t:SetPoint('BOTTOM'..edge, host, 'BOTTOM'..edge, dx, 0)
            t:SetWidth(size)
        else
            local edge = s.side == 'bottom' and 'BOTTOM' or 'TOP'
            local dy = edge == 'TOP' and gap or -gap
            if (s.length or 100) >= 100 then
                t:SetPoint(edge..'LEFT', host, edge..'LEFT', 0, dy); t:SetPoint(edge..'RIGHT', host, edge..'RIGHT', 0, dy)
            else
                local point = edge .. (s.align == 'left' and 'LEFT' or s.align == 'right' and 'RIGHT' or '')
                t:SetPoint(point, host, point, 0, dy); t:SetWidth(width * s.length / 100)
            end
            t:SetHeight(size)
        end
        t._key = key
    end
    t:SetColorTexture(colour[1], colour[2], colour[3], s.opacity or 1)
    t:Show()
end
FHK.PaintEllesmerePetMoodStrip = PaintMoodStrip
-- Ellesmere's pet frame carries Blizzard's stock mood faces. Restyle that icon
-- as a flat paw glyph tinted with the same mood colour as the bar; its position,
-- size options and hover tooltip stay native. Off restores the stock art.
local PAW = (FHK.RefinementsMediaRoot or 'Interface\\AddOns\\FHKEllesmere\\media\\') .. 'menu-paw.png'
-- Square happiness (player: the paw and Blizzard's faces looked out of place;
-- "something clean, just a square"): a 12-unit block in the mood colour with a
-- black outline, the same grammar as the range block. Drawn on our own textures
-- inside the native icon's slot, so native refreshes and the tooltip stay.
local MOOD_SQUARE = 12
local function PaintMoodSquare(h, mood)
    local sq = h._fhkSquare
    if not mood then
        if sq then sq:Hide(); h._tex:SetAlpha(1) end
        return
    end
    -- The shared framed block: the racial icons' pixel border (player).
    if not sq then
        if not FHK.CreateEllesmereFramedBlock then return end
        sq = FHK.CreateEllesmereFramedBlock(h); h._fhkSquare = sq
    end
    sq:ClearAllPoints(); sq:SetPoint('CENTER', h, 'CENTER', 0, 0); sq:SetSize(MOOD_SQUARE, MOOD_SQUARE)
    sq.fill:SetVertexColor(mood[1], mood[2], mood[3], 1)
    sq:Show(); h._tex:SetAlpha(0)
end
local function StylePetMood(h)
    if type(h) ~= 'table' or not h._tex then return end
    -- Fade the native icon (a plain hover frame) instead of hiding it, so native
    -- Show/Hide stays in charge; hover is dropped while it is faded.
    local _, happiness = Mood()
    local hidden = happiness == 3 and HideHappy()
    if h._fhkHappyHidden ~= hidden then
        h:SetAlpha(hidden and 0 or 1)
        if h.EnableMouseMotion then h:EnableMouseMotion(not hidden) end
        h._fhkHappyHidden = hidden
    end
    local mood
    if not (FHKEllesmereDB and FHKEllesmereDB.petMoodIcon == false) then mood = Mood() end
    local square = not (FHKEllesmereDB and FHKEllesmereDB.petMoodStyle == 'paw')
    PaintMoodSquare(h, square and mood or nil)
    if square and mood then return end
    if FHK.ApplyEllesmereIconEdge then FHK.ApplyEllesmereIconEdge(h._tex) end
    if mood then
        -- Ellesmere repaints its stock face only when its atlas changes, so the
        -- atlas is part of the key: a native repaint is always restyled again.
        if h._fhkMood ~= mood or h._fhkAtlas ~= h._atlas then
            h._tex:SetTexture(PAW); h._tex:SetTexCoord(0, 1, 0, 1)
            h._tex:SetVertexColor(mood[1], mood[2], mood[3], 1)
            h._fhkMood, h._fhkAtlas = mood, h._atlas
        end
    elseif h._fhkMood then
        h._fhkMood, h._fhkAtlas = nil, nil
        h._tex:SetVertexColor(1, 1, 1, 1)
        if h._atlas then h._tex:SetAtlas(h._atlas) end
    end
end
FHK.StyleEllesmerePetMood = StylePetMood
-- The paw joins the combat icon as an edge badge (player request): in its
-- default Right position it straddles the top of the pet bar's right corner
-- instead of floating beside the frame. Left/Top stay native; X/Y still nudge.
local function PlacePetMood(pf, uf)
    local h = pf and pf._petHappy
    local s = uf and uf.db and uf.db.profile and uf.db.profile.pet
    if not h or not s or (FHKEllesmereDB and FHKEllesmereDB.statusIconBadge == false) then return end
    if (s.happinessAlign or 'right') ~= 'right' then return end
    local size, x, y = s.happinessSize or 20, s.happinessX or 0, s.happinessY or 0
    if not PublicNumber(size) or not PublicNumber(x) or not PublicNumber(y) then return end
    h:ClearAllPoints()
    h:SetPoint('CENTER', pf.Health or pf, 'TOPRIGHT', x - size / 2 - 2, y)
end
local petMoodHooked
local function HookPetMood(frame, uf)
    local h = frame and frame._petHappy
    if not h then return end
    if not h._fhkHooked then h:HookScript('OnEvent', StylePetMood); h._fhkHooked = true end
    if not petMoodHooked and uf and type(uf.UF_RefreshPetHappiness) == 'function' then
        hooksecurefunc(uf, 'UF_RefreshPetHappiness', StylePetMood); petMoodHooked = true
        -- Settings passes rebuild or re-seat the icon; restyle after each one.
        if type(uf.UF_ApplyPetHappiness) == 'function' then
            hooksecurefunc(uf, 'UF_ApplyPetHappiness', function()
                local pf = uf.frames and uf.frames.pet
                if pf then PlacePetMood(pf, uf); StylePetMood(pf._petHappy) end
            end)
        end
    end
    if not h._fhkPlaced then PlacePetMood(frame, uf); h._fhkPlaced = true end
    StylePetMood(h)
end
-- After a colour toggle is switched off, let Ellesmere repaint its own text colours.
function FHK.RestoreEllesmereNativeText()
    local uf = EUI._ModuleNS and EUI._ModuleNS.EllesmereUIUnitFrames
    if uf and uf.ReloadFrames and not InCombatLockdown() then pcall(uf.ReloadFrames) end
    local np = _G.EllesmereNameplates_NS
    if np and np.RefreshAllSettings then pcall(np.RefreshAllSettings) end
    local rb = EUI._ModuleNS and EUI._ModuleNS.EllesmereUIResourceBars
    if rb and rb.ERB and rb.ERB.ApplyAll then pcall(rb.ERB.ApplyAll, rb.ERB) end
end
local function Curve(state)
    if state.curve or not C_CurveUtil or not C_CurveUtil.CreateColorCurve or not CreateColor then return state.curve end
    local curve=C_CurveUtil.CreateColorCurve()
    for i=0,32 do
        local p=i/32
        local r,g,b=Shade(state,p)
        curve:AddPoint(p,CreateColor(r,g,b,1))
    end
    state.curve=curve
    return curve
end
-- Dark mode health line (player request: black bars that still say everything).
-- Dark health bars are a dark shade of black over black, so a 1px line along the
-- top of the remaining health carries the amount at a glance, in the same colour
-- ramp as the number: light, then WoW gold, orange and red. Anchored to the fill
-- texture, so it follows the bar natively, restricted values included.
local function PaintDarkLine(bar, state, dark)
    local line = state.darkLine
    -- Health everywhere dark; power on the unit frames (player request), in its resource colour.
    local wanted = dark and (not state.resource or state.context == 'unitframes') and
        not (FHKEllesmereDB and FHKEllesmereDB.darkHealthLine == false)
    local unit = state.unit
    local gone = unit and UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)
    if not wanted or not unit or not UnitExists(unit) or (not (issecretvalue and issecretvalue(gone)) and gone == true) then
        if line then line:Hide() end
        return
    end
    local host = state.texture and bar.GetParent and bar:GetParent() or bar
    local fill = state.texture and bar or bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if not host or not fill or not host.CreateTexture then return end
    if not line then
        line = host:CreateTexture(nil, 'OVERLAY', nil, 7)
        line:SetPoint('TOPLEFT', fill, 'TOPLEFT', 0, 0)
        line:SetPoint('TOPRIGHT', fill, 'TOPRIGHT', 0, 0)
        line:SetHeight(Pixel(1))
        line:SetColorTexture(1, 1, 1, 1)
        state.darkLine = line
    end
    if state.resource then
        local c = ResourceNeon(unit) or coolWhite
        line:SetVertexColor(c[1], c[2], c[3], 1); line:Show()
        return
    end
    if not OwnUnit(unit) then line:SetVertexColor(white[1],white[2],white[3],1);line:Show();return end
    local textOff = FHKEllesmereDB and FHKEllesmereDB.healthTextColors == false
    local c = textOff and white or HealthColor(unit)
    if c then line:SetVertexColor(c[1], c[2], c[3], 1)
    else
        local curve = HealthTextCurve()
        local colour = curve and UnitHealthPercent and UnitHealthPercent(unit, true, curve)
        if colour and colour.GetRGB then line:SetVertexColor(colour:GetRGB()) end
    end
    line:Show()
end
-- A neutral creature turns hostile when it has aggro on the player or pet.
-- Public threat/target signals only; health amount never changes this hue.
local function NeutralAggroColor(state)
    local unit=state.unit
    if state.resource or OwnUnit(unit) or type(unit)~='string' or not UnitReaction then return end
    local reaction=UnitReaction(unit,'player')
    if not PublicNumber(reaction) or reaction~=4 then return end
    local tapped=UnitIsTapDenied and UnitIsTapDenied(unit)
    if not (issecretvalue and issecretvalue(tapped)) and tapped then return end
    local status=UnitThreatSituation and UnitThreatSituation('player',unit)
    local aggro=PublicNumber(status) and status>=2
    if not aggro and UnitIsUnit and UnitAffectingCombat then
        local combat=UnitAffectingCombat(unit)
        if not (issecretvalue and issecretvalue(combat)) and combat==true then
            local player=UnitIsUnit(unit..'target','player')
            local pet=UnitIsUnit(unit..'target','pet')
            aggro=(not (issecretvalue and issecretvalue(player)) and player==true) or
                (not (issecretvalue and issecretvalue(pet)) and pet==true)
        end
    end
    if not aggro then return end
    local c
    if state.context=='nameplates' then
        local np=_G.EllesmereNameplates_NS
        local p=np and ((np.NP_GetProfile and np.NP_GetProfile()) or (np.db and np.db.profile))
        c=p and p.hostile
    elseif state.context=='unitframes' then
        local uf=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIUnitFrames
        local p=uf and uf.db and uf.db.profile
        c=p and p.enemyColors and p.enemyColors.hostile
    end
    c=c or C.reactionHostile or {.784,.188,.165}
    local r,g,b=c.r or c[1],c.g or c[2],c.b or c[3]
    if PublicNumber(r) and PublicNumber(g) and PublicNumber(b) then return r,g,b end
end
local function PaintBar(bar, state)
    if not state.painting then PaintDarkLine(bar, state, DarkFor(state)) end
    if state.painting or not state.base then return end
    local r, g, b = unpack(state.base)
    local unit = state.unit
    if not unit or not UnitExists(unit) then return end
    local enabled = OwnUnit(unit) and (not FHKEllesmereDB or FHKEllesmereDB[state.resource and 'resourceBarColors' or 'healthBarColors'] ~= false)
    local nativeDark=DarkFor(state)
    VividBase(state)
    -- Dark mode: unit-frame power and nameplate health become the dark fill too
    -- (Ellesmere darkens neither); the line and the neon text carry the detail.
    if nativeDark and (state.resource and state.context == 'unitframes' or state.context == 'nameplates') then
        local d = FHK.darkFill or {.11, .114, .13}
        if state.r == d[1] and state.g == d[2] and state.b == d[3] and state.a == 1 then return end
        state.painting = true
        if state.texture then bar:SetVertexColor(d[1], d[2], d[3], 1) else bar:SetStatusBarColor(d[1], d[2], d[3], 1) end
        state.painting = nil
        state.r, state.g, state.b, state.a = d[1], d[2], d[3], 1
        return
    end
    -- Native Dark Mode owns its flat health and resource fills; warnings stay in the text.
    if nativeDark then enabled=false end
    local value, max
    if state.resource then
        local kind = ResourceType(unit)
        if kind ~= nil then value, max = UnitPower(unit, kind), UnitPowerMax(unit, kind) end
    else value, max = UnitHealth(unit), UnitHealthMax(unit) end
    local isDead = UnitIsDead(unit)
    if not nativeDark and not (issecretvalue and issecretvalue(isDead)) and not isDead then
        local x,y,z=NeutralAggroColor(state)
        if x then r,g,b=x,y,z end
    end
    -- Pet happiness is the pet's bar colour, unless the strip shows it (dark themes).
    local mood = not (state.context == 'unitframes' and MoodStripWanted()) and PetHappinessColor(state)
    if mood and not (issecretvalue and issecretvalue(isDead)) and not isDead then
        r, g, b = mood[1], mood[2], mood[3]
        enabled = false
    end
    -- Target of target is you: its bar turns WoW gold, the "act now" colour the
    -- gold plate edge uses (player request). On your pet it is pet green; other
    -- units keep their colour. A restricted identity read stays native. Gold is
    -- act now, so only a hostile target counts; a friend or yourself targeting
    -- you keeps your class colour, which already reads as you (player, after review).
    if not state.resource and unit == 'targettarget' and state.context == 'unitframes' and
        not (FHKEllesmereDB and FHKEllesmereDB.totOnYou == false) and UnitIsUnit then
        local you = UnitIsUnit('targettarget', 'player')
        local hostile = UnitCanAttack and UnitCanAttack('player', 'target')
        if not (issecretvalue and (issecretvalue(you) or issecretvalue(hostile))) and you == true and hostile == true then
            local c = C.healthMid or {.772, .632, 0}
            if FHK.EllesmereReadableBarFill then r, g, b = FHK.EllesmereReadableBarFill(c[1], c[2], c[3])
            else r, g, b = c[1], c[2], c[3] end
            enabled = false
        end
    end
    -- Let the native colour curve evaluate restricted health/resource values.
    -- Its components go straight to allowed setters; Lua never compares them.
    if enabled and not (issecretvalue and issecretvalue(isDead)) and not isDead and
        (not PublicNumber(value) or not PublicNumber(max)) then
        local curve=Curve(state)
        local color
        if curve and state.resource and UnitPowerPercent then
            color=UnitPowerPercent(unit,ResourceType(unit),false,curve)
        elseif curve and UnitHealthPercent then color=UnitHealthPercent(unit,true,curve) end
        if color and color.GetRGB then
            state.painting=true
            if state.texture then bar:SetVertexColor(color:GetRGB()) else bar:SetStatusBarColor(color:GetRGB()) end
            state.painting=nil
            state.r,state.g,state.b,state.a=nil,nil,nil,nil
            return
        end
    end
    if enabled and PublicNumber(value) and PublicNumber(max) and max > 0 and
        not (issecretvalue and issecretvalue(isDead)) and not isDead then
        r,g,b = Shade(state, math.max(0, math.min(1, value/max)))
    end
    local alpha = state.base[4]
    if r == state.r and g == state.g and b == state.b and alpha == state.a then return end
    state.painting = true
    if state.texture then bar:SetVertexColor(r,g,b,alpha) else bar:SetStatusBarColor(r,g,b,alpha) end
    state.painting = nil
    state.r,state.g,state.b,state.a = r,g,b,alpha
end
local function RefineBar(bar, unit, resource, texture, context, key)
    local getter=texture and 'GetVertexColor' or 'GetStatusBarColor'
    local setter=texture and 'SetVertexColor' or 'SetStatusBarColor'
    if not bar or type(bar[getter]) ~= 'function' then return end
    if not resource and context=='unitframes' and not (issecretvalue and issecretvalue(unit)) and unit=='pet' and FHK.ObserveEllesmerePetBar then
        FHK.ObserveEllesmerePetBar(bar)
    end
    local state = barStates[bar]
    if not state then
        state = {unit=unit,resource=resource,texture=texture,context=context,key=key}; barStates[bar]=state
        local r,g,b,a = bar[getter](bar)
        if PublicNumber(r) and PublicNumber(g) and PublicNumber(b) then state.base={r,g,b,a} end
        hooksecurefunc(bar,setter,function(self,r,g,b,a)
            if state.painting then return end
            -- Preserve each new native class/reaction colour, including recycled plates.
            state.r,state.g,state.b,state.a = nil,nil,nil,nil
            if PublicNumber(r) and PublicNumber(g) and PublicNumber(b) then
                local old=state.base
                if not old or old[1]~=r or old[2]~=g or old[3]~=b then state.curve=nil end
                state.base={r,g,b,a}; PaintBar(self,state)
            else state.base=nil end
        end)
    end
    state.unit,state.resource,state.context,state.key=unit,resource,context,key
    PaintBar(bar,state)
end
FHK.RefineEllesmereBar=RefineBar
-- Group bars retain native class/health identity. Deepen public fill colours
-- under labels without dimming the shared class palette used by names/icons.
local raidBars=setmetatable({},{__mode='k'})
local raidInstalled
local function PaintRaidBar(bar,state)
    if state.painting or not state.base then return end
    local r,g,b,a=unpack(state.base)
    if FHK.EllesmereVividFillEnabled and FHK.EllesmereVividFillEnabled() and FHK.EllesmereReadableBarFill then
        local x,y,z=FHK.EllesmereReadableBarFill(r,g,b)
        if x then r,g,b=x,y,z end
    end
    if not (issecretvalue and issecretvalue(a)) and state.r==r and state.g==g and state.b==b and state.a==a then return end
    state.painting=true;bar:SetStatusBarColor(r,g,b,a);state.painting=nil
    state.r,state.g,state.b,state.a=r,g,b,a
end
local function AttachRaidButton(button)
    local ns=raidInstalled
    if not button or not ns then return end
    local unit=button.GetAttribute and button:GetAttribute('unit')
    if issecretvalue and issecretvalue(unit) then return end
    if type(unit)=='string' and UnitCanAttack then
        local attackable=UnitCanAttack('player',unit)
        if not (issecretvalue and issecretvalue(attackable)) and attackable==true then return end
    end
    local data=ns.GetFFD and ns.GetFFD(button)
    local bar=button._health or (data and data.health)
    if not bar or not bar.GetStatusBarColor or not bar.SetStatusBarColor then return end
    local state=raidBars[bar]
    if not state then
        state={};raidBars[bar]=state
        local r,g,b,a=bar:GetStatusBarColor()
        if PublicNumber(r) and PublicNumber(g) and PublicNumber(b) then state.base={r,g,b,a} end
        hooksecurefunc(bar,'SetStatusBarColor',function(self,r,g,b,a)
            if state.painting then return end
            state.r,state.g,state.b,state.a=nil,nil,nil,nil
            state.base=PublicNumber(r) and PublicNumber(g) and PublicNumber(b) and {r,g,b,a} or nil
            PaintRaidBar(self,state)
        end)
    end
    PaintRaidBar(bar,state)
end
local function InstallRaidFills()
    local ns=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIRaidFrames
    if not ns or ns==raidInstalled then return end
    raidInstalled=ns
    for _,key in ipairs({'_UpdateButtonHealth','_StyleButtonSecure'}) do
        if type(ns[key])=='function' then hooksecurefunc(ns,key,AttachRaidButton) end
    end
    if ns._FB and type(ns._FB.StyleVisuals)=='function' then hooksecurefunc(ns._FB,'StyleVisuals',AttachRaidButton) end
    for _,list in ipairs({ns._allButtons or {},ns._flatButtons or {},ns._PF and ns._PF.buttons or {}}) do
        for _,button in pairs(list) do AttachRaidButton(button) end
    end
end
FHK.EllesmereResourceType=ResourceType
ResourceNeon = function(unit)
    local kind = ResourceType(unit)
    if kind == nil then return end
    local r, g, b
    if EUI.ResolveUnitPowerColor then r, g, b = EUI.ResolveUnitPowerColor(unit) end
    if not PublicNumber(r) then
        local key = EUI.POWER_ENUM_TO_KEY and EUI.POWER_ENUM_TO_KEY[kind]
        local info = key and EUI.GetPowerColor and EUI.GetPowerColor(key)
        r, g, b = info and info.r, info and info.g, info and info.b
    end
    return Neon(r, g, b)
end
FHK.EllesmereResourceNeon = ResourceNeon
local function ResourceColor(unit)
    if not OwnUnit(unit) then return end
    local kind = ResourceType(unit)
    if kind == nil then return coolWhite end
    -- Dark mode (player request): the number in its resource colour, as neon.
    if Dark() and not (FHKEllesmereDB and FHKEllesmereDB.resourceTextColors == false) then
        local neon = ResourceNeon(unit)
        if neon then return neon end
    end
    local r, g, b
    if EUI.ResolveUnitPowerColor then r, g, b = EUI.ResolveUnitPowerColor(unit) end
    local key = EUI.POWER_ENUM_TO_KEY and EUI.POWER_ENUM_TO_KEY[kind]
    local info = key and EUI.GetPowerColor and EUI.GetPowerColor(key)
    if not PublicNumber(r) then r, g, b = info and info.r, info and info.g, info and info.b end
    local normal = {coolWhite[1], coolWhite[2], coolWhite[3]}
    if PublicNumber(r) and PublicNumber(g) and PublicNumber(b) then
        normal = {normal[1] * .88 + r * .12, normal[2] * .88 + g * .12, normal[3] * .88 + b * .12}
    end
    if FHKEllesmereDB and FHKEllesmereDB.resourceTextColors == false then return end
    local value, max = UnitPower(unit, kind), UnitPowerMax(unit, kind)
    if not PublicNumber(value) or not PublicNumber(max) or max <= 0 then return normal end
    local pct = math.max(0, math.min(1, value / max))
    -- Pale at full reserves, richer blue/tint when spent. Never dim below a
    -- readable pastel, and never imply that empty rage is a health warning.
    local low = kind == 0 and {.48,.70,.96} or {
        .58 + (PublicNumber(r) and r or .5) * .24,
        .58 + (PublicNumber(g) and g or .5) * .24,
        .58 + (PublicNumber(b) and b or .5) * .24}
    local t = math.min(1, pct / .65); t = t * t * (3 - 2 * t)
    return {low[1] + (normal[1] - low[1]) * t,
        low[2] + (normal[2] - low[2]) * t, low[3] + (normal[3] - low[3]) * t}
end
FHK.EllesmereResourceColor = ResourceColor
local function ResourceEscape(unit)
    local c = ResourceColor(unit)
    if not c then return '' end
    return string.format('|cff%02x%02x%02x', math.floor(c[1] * 255 + .5),
        math.floor(c[2] * 255 + .5), math.floor(c[3] * 255 + .5))
end
local function ResourceText(unit)
    local kind = ResourceType(unit)
    if kind == nil then return '' end
    local current, max = UnitPower(unit, kind), UnitPowerMax(unit, kind)
    if not PublicNumber(current) or not PublicNumber(max) or max <= 0 then return '' end
    local percent = math.floor(math.max(0, math.min(1, current / max)) * 100 + .5)
    local key = EUI.POWER_ENUM_TO_KEY and EUI.POWER_ENUM_TO_KEY[kind]
    local name = kind == 0 and 'MP' or key and (key:gsub('_', ' '):lower():gsub('^%l', string.upper)) or 'Resource'
    return string.format(' | %s%s %d%%|r', ResourceEscape(unit), name, percent)
end
local function Departed(unit)
    if type(unit)~='string' or not UnitIsDeadOrGhost then return false end
    local gone=UnitIsDeadOrGhost(unit)
    return not (issecretvalue and issecretvalue(gone)) and gone==true
end
-- A dead unit's resource reads like its health, "0% | DEAD" (player), instead of
-- the last value it had.
local function ResourceNumber(unit)
    local kind = ResourceType(unit)
    if kind == nil then return '' end
    if Departed(unit) then return 'DEAD' end
    local value, max = UnitPower(unit, kind), UnitPowerMax(unit, kind)
    local ns = EUI._ModuleNS and EUI._ModuleNS.EllesmereUIUnitFrames
    if not PublicNumber(value) or not PublicNumber(max) then
        -- EUI's native display lane accepts restricted numbers; keep the value
        -- visible even when this client forbids inspecting it for a gradient.
        return ns and ns.TextPieces and ns.TextPieces.curpp(unit) or ''
    end
    if max <= 0 then return '' end
    local abbreviate = ns and ns.AbbreviateNumbers or AbbreviateNumbers
    local config = _G._EUI_AbbrevDecimalCfg
    if not abbreviate then return tostring(math.floor(value)) end
    return config and abbreviate(value, config) or abbreviate(value)
end
local function ResourcePercentPlain(unit)
    local kind = ResourceType(unit)
    if kind == nil then return '' end
    if Departed(unit) then return '0' end
    local value, max = UnitPower(unit, kind), UnitPowerMax(unit, kind)
    if not PublicNumber(value) or not PublicNumber(max) then
        local ns = EUI._ModuleNS and EUI._ModuleNS.EllesmereUIUnitFrames
        return ns and ns.TextPieces and ns.TextPieces.perpp(unit) or ''
    end
    if max <= 0 then return '' end
    return string.format('%d', math.floor(math.max(0, math.min(1, value / max)) * 100 + .5))
end
local function ResourcePercent(unit)
    local value = ResourcePercentPlain(unit)
    if not (issecretvalue and issecretvalue(value)) and value == '' then return '' end
    return string.format('%s%%', value)
end
local function BothResource(unit, percentFirst)
    local value, percent = ResourceNumber(unit), ResourcePercent(unit)
    if not (issecretvalue and issecretvalue(percent)) and percent == '' then return '' end
    return percentFirst and string.format('%s | %s', percent, value) or string.format('%s | %s', value, percent)
end
local resourceFormats = {
    perpp = {'%s', {ResourcePercent}}, curpp = {'%s', {ResourceNumber}},
    fhk_manaboth = {'%s', {function(unit) return BothResource(unit) end}},
    fhk_manaperfirst = {'%s', {function(unit) return BothResource(unit, true) end}},
}
local function Settings(ns, frame)
    local unit = frame._euiBaseUnit or frame._euiUnit
    if type(unit) ~= 'string' then return end
    return ns.db and ns.db.profile and ns.db.profile[unit:match('^boss') and 'boss' or unit]
end
local separators=setmetatable({},{__mode='k'})
local function PaintBarSeparator(frame)
    if not frame then return end
    local power=frame and frame.Power
    local line=separators[frame]
    if line and line._fhkPower~=power then line:Hide();line=nil;separators[frame]=nil end
    local stock=(installed and installed.UF_Blizz and installed.UF_Blizz()) or frame._blizzGeom
    local on=frame.Health and power and not stock and FHK.EllesmereVividThemeEnabled and
        FHK.EllesmereVividThemeEnabled() and not (FHKEllesmereDB and FHKEllesmereDB.pixelBarSeparators==false)
    if not line and on and power.CreateTexture and not InCombatLockdown() then
        line=power:CreateTexture(nil,'OVERLAY',nil,7);separators[frame]=line
        line._fhkPower=power
        line:SetColorTexture(0,0,0,1)
        line:SetPoint('TOPLEFT',power,'TOPLEFT',0,0);line:SetPoint('TOPRIGHT',power,'TOPRIGHT',0,0)
    end
    if line then
        local scale=power:GetEffectiveScale()
        if PublicNumber(scale) and scale>0 then
            local px=(EUI.PP and EUI.PP.perfect or 1)/scale
            if line._fhkHeight~=px then line:SetHeight(px);line._fhkHeight=px end
        end
        line:SetShown(on)
    end
    return line
end
FHK.PaintEllesmereBarSeparator=PaintBarSeparator
-- Native health and power edge text use different insets (5 vs 2).
-- Match the inset without changing fonts, row anchors or native offset controls.
local function AlignPowerText(frame,fs,s)
    if not fs or not s or FHKEllesmereDB and FHKEllesmereDB.alignPowerText==false then return end
    local hasStock=installed and type(installed.UF_Blizz)=='function'
    if hasStock and installed.UF_Blizz() or not hasStock and frame._blizzGeom or not fs.GetPoint then return end
    local pos=s.powerPercentText
    if pos~='left' and pos~='right' then return end
    -- Rebuild the placement from Ellesmere's own settings and overlay instead of
    -- reading it back: on 9.3.5 GetPoint can return secret anchors.
    -- Only power text reaches here. During construction frame.Power is not yet
    -- set; the text's parent is the same native overlay.
    local power=frame.Power
    local relative=power and power._ppFS==fs and power._ppTextOvr or fs.GetParent and fs:GetParent()
    if not relative or issecretvalue and issecretvalue(relative) then return end
    local edge=pos=='left' and 'LEFT' or 'RIGHT'
    local offset,y=s.powerPercentX or 0,s.powerPercentY or 0
    local healthOffset=s[pos=='left' and 'leftTextX' or 'rightTextX'] or 0
    if not PublicNumber(offset) or not PublicNumber(healthOffset) or not PublicNumber(y) then return end
    local wanted=(pos=='left' and 5 or -5)+healthOffset+offset
    fs:ClearAllPoints()
    -- Same pixel-perfect helper Ellesmere used for the native placement.
    if EUI.PP and EUI.PP.Point then EUI.PP.Point(fs,edge,relative,edge,wanted,y)
    else fs:SetPoint(edge,relative,edge,wanted,y) end
end
-- A dead or ghost unit has no usable resource. The health row already says
-- DEAD, so the power fill and power-only text go empty instead of showing the
-- mana the unit died with. Alpha only: values and native painting are untouched.
-- Most beasts have no resource at all; their row read "0 | 0%" (player report).
-- A public zero maximum hides it. In combat the maximum is restricted (secret),
-- so the reading taken for the same unit before combat is kept; any unit change
-- forgets it, and a unit never read publicly keeps its row.
local powerless={}
local function Powerless(unit)
    if type(unit)~='string' or not UnitPowerMax or not UnitExists(unit) then return false end
    local ok,max=pcall(UnitPowerMax,unit)
    if ok and PublicNumber(max) then powerless[unit]=max<=0;return max<=0 end
    return powerless[unit]==true
end
-- The power value text and any zone that shows only power.
local function PowerTexts(frame)
    local power,list=frame.Power,{}
    if power and power._ppFS then list[#list+1]=power._ppFS end
    local P=installed and installed.TextPieces
    for _,z in ipairs(frame._euiTextZones or {}) do
        local resource,health=resourceZones[z.fs],false
        for _,piece in ipairs(z.pieces or {}) do
            if P and (piece==P.perpp or piece==P.curpp) then resource=true end
            if P and (piece==P.perhp or piece==P.curhpshort or piece==P.perhpnosign) then health=true end
        end
        if resource and not health and z.fs~=list[1] then list[#list+1]=z.fs end
    end
    return list
end
-- An NPC first targeted mid-fight has a restricted maximum and no earlier
-- reading. A native curve over its power percent tints the text clear at 0 %
-- and leaves it untouched above, so "0 | 0%" disappears for a resourceless enemy
-- without Lua ever reading the value. A vertex tint multiplies over Ellesmere's
-- own text colour. Players keep their rows (a warrior can sit at 0 rage).
local emptyCurve
local function EmptyPowerCurve()
    if emptyCurve or not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return emptyCurve end
    emptyCurve=C_CurveUtil.CreateColorCurve()
    emptyCurve:AddPoint(0,CreateColor(1,1,1,0))
    emptyCurve:AddPoint(.005,CreateColor(1,1,1,1))
    emptyCurve:AddPoint(1,CreateColor(1,1,1,1))
    return emptyCurve
end
local function PaintEmptyPower(frame,unit)
    local colour
    if type(unit)=='string' and UnitPowerPercent and UnitExists(unit) and not OwnUnit(unit) then
        local player=UnitIsPlayer and UnitIsPlayer(unit)
        local okMax,max=pcall(UnitPowerMax,unit)
        if not (issecretvalue and issecretvalue(player)) and not player and okMax and
            not PublicNumber(max) and not powerless[unit] then
            local curve=EmptyPowerCurve()
            local ok,c=pcall(UnitPowerPercent,unit,ResourceType(unit),false,curve)
            if ok and c and c.GetRGBA then colour=c end
        end
    end
    for _,fs in ipairs(PowerTexts(frame)) do
        if colour then
            if pcall(fs.SetVertexColor,fs,colour:GetRGBA()) then fs._fhkEmpty=true end
        elseif fs._fhkEmpty then fs:SetVertexColor(1,1,1,1);fs._fhkEmpty=nil end
    end
end
local function PaintPowerDeath(frame,unit)
    local power=frame.Power
    if not power then return end
    PaintEmptyPower(frame,unit)
    local gone,none=Departed(unit),Powerless(unit)
    local alpha=(gone or none) and 0 or 1   -- the fill empties on death
    local textAlpha=none and 0 or 1          -- the text stays: "0% | DEAD"
    local fill=power.GetStatusBarTexture and power:GetStatusBarTexture()
    if frame._fhkPowerAlpha==alpha and frame._fhkPowerTextAlpha==textAlpha and frame._fhkPowerObject==power and frame._fhkPowerFill==fill and
        frame._fhkPowerText==power._ppFS and frame._fhkPowerZones==frame._euiTextZones then return end
    local changed=frame._fhkPowerGone~=gone
    frame._fhkPowerAlpha,frame._fhkPowerObject,frame._fhkPowerFill=alpha,power,fill
    frame._fhkPowerTextAlpha,frame._fhkPowerGone=textAlpha,gone
    frame._fhkPowerText,frame._fhkPowerZones=power._ppFS,frame._euiTextZones
    if fill then fill:SetAlpha(alpha) end
    -- Restore everything faded last time, even a zone since changed to other content.
    local faded=frame._fhkPowerFaded or {}
    for fs in pairs(faded) do fs:SetAlpha(1); faded[fs]=nil end
    frame._fhkPowerFaded=faded
    -- Death and release do not always fire a power event: repaint the text now.
    if changed and installed and installed.UF_PaintPowerText then installed.UF_PaintPowerText(frame,unit) end
    if textAlpha==1 then return end
    for _,fs in ipairs(PowerTexts(frame)) do faded[fs]=true end
    for fs in pairs(faded) do fs:SetAlpha(0) end
end
FHK.PaintEllesmerePowerDeath=PaintPowerDeath
-- Status icons as an edge badge (player report: the centred combat swords and
-- loot bag covered the name and values). While Ellesmere's combat icon is in its
-- default Center position it straddles the health bar's top edge instead, clear
-- of the vertically centred text; its X/Y offsets still apply. A Portrait or
-- corner position is the player's choice and stays native.
local function EdgeBadge(s)
    if FHKEllesmereDB and FHKEllesmereDB.statusIconBadge==false then return false end
    local pos=s and s.combatIndicatorPosition or 'healthbar'
    return pos=='healthbar' or pos=='center'
end
local function PlaceCombatBadge(frame)
    local combat,health=frame._combatIndicator,frame.Health
    if not combat or not health or not installed then return end
    local s=Settings(installed,frame)
    if not EdgeBadge(s) then return end
    local x,y=s and s.combatIndicatorX or 0,s and s.combatIndicatorY or 0
    if not PublicNumber(x) or not PublicNumber(y) then return end
    combat._fhkPlacing=true
    combat:ClearAllPoints()
    combat:SetPoint('CENTER',health,'TOP',x,y)
    combat._fhkPlacing=nil
end
local function HookCombatBadge(frame)
    local combat=frame._combatIndicator
    if combat and FHK.ApplyEllesmereIconEdge then FHK.ApplyEllesmereIconEdge(combat) end
    if not combat or combat._fhkBadgeHooked then return end
    combat._fhkBadgeHooked=true
    -- Ellesmere re-anchors on every settings apply; follow it once it has.
    hooksecurefunc(combat,'SetPoint',function(self)
        if not self._fhkPlacing then PlaceCombatBadge(frame) end
    end)
    PlaceCombatBadge(frame)
end
local function PaintPowerFeedback(frame,unit)
    if not IsUnitFrame(frame) then return end
    unit=unit or frame._euiUnit or frame._euiBaseUnit
    PaintPowerDeath(frame,unit)
    RefineBar(frame.Power,unit,true,false,'unitframes')
    local c=ResourceColor(unit)
    if not c then return end
    for _,z in ipairs(frame._euiTextZones or {}) do
        local resource,health=resourceZones[z.fs],false
        for _,piece in ipairs(z.pieces or {}) do
            local p=installed and installed.TextPieces
            if p then
                if piece==p.perpp or piece==p.curpp then resource=true end
                if piece==p.perhp or piece==p.curhpshort or piece==p.perhpnosign then health=true end
            end
        end
        if resource and not health then z.fs:SetTextColor(c[1],c[2],c[3],1) end
    end
    if frame.Power and frame.Power._ppFS then frame.Power._ppFS:SetTextColor(c[1],c[2],c[3],1) end
end
local function InstallText()
    local ns = EUI._ModuleNS and EUI._ModuleNS.EllesmereUIUnitFrames
    if installed or not ns or not ns.db or not ns.db.profile or not ns.ContentToZone or not ns.TextPieces then return end
    installed = ns
    if type(ns.UF_PaintPowerText)=='function' then
        hooksecurefunc(ns,'UF_PaintPowerText',PaintPowerFeedback)
        powerFeedbackHooked=true
    end
    -- The native engine already subscribes and paints power zones. Only older
    -- engines without that channel need our event fallback.
    if not ns.Engine then
        for _, event in ipairs({'UNIT_POWER_UPDATE','UNIT_POWER_FREQUENT','UNIT_MAXPOWER','UNIT_DISPLAYPOWER'}) do
            driver:RegisterEvent(event)
        end
    end
    local original, P = ns.ContentToZone, ns.TextPieces
    -- Seed a visible player resource once, then native controls own it.
    FHKEllesmereDB = FHKEllesmereDB or {}
    local player = ns.db and ns.db.profile and ns.db.profile.player
    if player and not FHKEllesmereDB.resourceTextSeeded then
        if not player.powerPercentText or player.powerPercentText == 'none' then
            player.powerPercentText = 'center'
            if not player.powerTextFormat or player.powerTextFormat == 'perpp' then player.powerTextFormat = 'both' end
            player.powerPercentSize = 10
            player.powerHeight = math.max(player.powerHeight or 5, 14)
            if ns.ReloadFrames then ns.ReloadFrames() end
        end
        FHKEllesmereDB.resourceTextSeeded = true
    end
    -- Native content keys and text zones retain EUI's positioning and formatting.
    ns.ContentToZone = function(content, prefix, settings)
        local healthSlot = not (prefix and prefix:match('^btb'))
        if healthSlot and resourceFormats[content] then
            local def = resourceFormats[content]
            return def[1], def[2]
        end
        if healthSlot and (content == 'perhp_perpp' or content == 'curhp_curpp') then
            local full = content == 'curhp_curpp'
            return '%s%s', {
                function(unit)
                    local hp = P.perhp(unit)
                    local text = full and string.format('%s | %s%%', P.curhpshort(unit), hp) or
                        string.format('%s%%', hp)
                    return HealthEscape(unit) .. text .. '|r'
                end,
                ResourceText,
            }
        end
        return original(content, prefix, settings)
    end
    hooksecurefunc(ns, 'SetTextZone', function(frame, fs, content, prefix)
        resourceZones[fs] = resourceFormats[content] and not (prefix and prefix:match('^btb')) or nil
        if content ~= 'perhp_perpp' and content ~= 'curhp_curpp' and not resourceFormats[content] then return end
        if prefix and prefix:match('^btb') then return end
        for _, zone in ipairs(frame._euiTextZones or {}) do
            if zone.fs == fs then zone.power = true end
        end
        if frame._euiBaseUnit == 'player' and ns.UF_PowerValSync then ns.UF_PowerValSync(frame) end
        if ns.UF_PaintPowerText then ns.UF_PaintPowerText(frame, frame._euiUnit or frame._euiBaseUnit) end
    end)
    if ns.SetTextZoneRaw then
        local originalRaw = ns.SetTextZoneRaw
        ns.SetTextZoneRaw = function(frame, fs, fmt, pieces)
            local power = frame.Power
            local s = Settings(ns, frame)
            -- During construction the local Power element is not yet attached
            -- to frame.Power. Recognise the native power pieces in that pass.
            local powerZone = power and power._ppFS == fs
            if not powerZone and pieces and #pieces > 0 then
                powerZone = true
                for _, piece in ipairs(pieces) do
                    if piece ~= P.perpp and piece ~= P.curpp then powerZone = false; break end
                end
            end
            resourceZones[fs] = fmt and powerZone or nil
            if fmt and powerZone and s then
                local suffix = s.powerShowPercent ~= false and '%%' or ''
                if s.powerTextFormat == 'perppnum' then
                    fmt, pieces = '%s' .. suffix .. ' | %s', {ResourcePercentPlain, ResourceNumber}
                elseif s.powerTextFormat == 'both' then
                    fmt, pieces = '%s | %s' .. suffix, {ResourceNumber, ResourcePercentPlain}
                end
            end
            local result = originalRaw(frame, fs, fmt, pieces)
            -- Native layout can replace or repurpose zones while death is unchanged.
            frame._fhkPowerAlpha=nil
            if fmt and powerZone then
                AlignPowerText(frame,fs,s)
                for _, z in ipairs(frame._euiTextZones or {}) do if z.fs == fs then z.power = true end end
                if ns.UF_PowerValSync then ns.UF_PowerValSync(frame) end
                if ns.UF_PaintPowerText then ns.UF_PaintPowerText(frame, frame._euiUnit or frame._euiBaseUnit) end
            end
            return result
        end
    end
    -- Rebuild the already spawned zones to pick up the extended formatter.
    for key, frame in pairs(ns.frames or {}) do
        if IsUnitFrame(frame) then
            local s = Settings(ns, frame)
            if s and frame._applyTextTags then
                frame._applyTextTags(s.leftTextContent, s.rightTextContent, s.centerTextContent, s.extraTextContent)
            end
            if s and frame.Power and frame.Power._applyPowerPercentText then
                frame.Power._applyPowerPercentText(s)
            end
        end
    end
end
local powerMenus = setmetatable({}, {__mode='k'})
local function ExtendConfig(cfg)
    local values = cfg and cfg.values
    if not values then return end
    local keys
    if cfg.text == 'Power Text' and values.smart and values.curpp and values.perpp and
        (values.both == 'Value | %' or powerMenus[values]) then
        -- The existing Power Text dropdown, including mini-frame versions.
        powerMenus[values] = true
        values.curpp, values.perpp = 'Resource #', 'Resource %'
        values.both, values.perppnum = 'Resource # | %', 'Resource % | #'
        keys = {'perppnum'}
    elseif values.both and values.levelname and values.healabsorb then
        values.perpp, values.curpp = 'Resource %', 'Resource #'
        values.fhk_manaboth, values.fhk_manaperfirst = 'Resource # | %', 'Resource % | #'
        values.perhp_perpp = 'Health % | Resource %'
        values.curhp_curpp = 'Health # | % | Resource %'
        keys = {'perpp', 'curpp', 'fhk_manaboth', 'fhk_manaperfirst', 'perhp_perpp', 'curhp_curpp'}
    else return end
    -- The UF health-content table is distinct from resource/cast text tables.
    if cfg.order then
        for _, key in ipairs(keys) do
            local found
            for _, existing in ipairs(cfg.order) do if existing == key then found = true; break end end
            if not found then cfg.order[#cfg.order + 1] = key end
        end
    end
    return true
end
local previews = setmetatable({}, {__mode='k'})
local function ExtendPreview(cfg)
    if not cfg or not cfg.getValue then return end
    local field = ({['Left Text']='_nameFS', ['Right Text']='_hpFS', ['Center Text']='_centerFS',
        ['Power Text']='_ppFS'})[cfg.text]
    if not field then return end
    local function Visit(parent, depth)
        if not parent or depth > 3 or not parent.GetChildren then return end
        if parent._health and parent[field] then
            local fs = parent[field]
            local state = previews[fs]
            if state then state.get = cfg.getValue; return end
            state = {get=cfg.getValue}; previews[fs] = state
            hooksecurefunc(fs, 'SetText', function(self, text)
                if state.painting or type(text) ~= 'string' then return end
                local key, ns = state.get(), installed
                local value
                if cfg.text == 'Power Text' and (key == 'both' or key == 'perppnum') then
                    local percent = tonumber(text:match('(%d+)%%')) or tonumber(text:match('(%d+)%s*$')) or 85
                    local suffix = text:find('%%') and '%' or ''
                    local number = ns.AbbreviateNumbers(18200)
                    value = key == 'perppnum' and string.format('%d%s | %s', percent, suffix, number) or
                        string.format('%s | %d%s', number, percent, suffix)
                elseif key == 'fhk_manaboth' or key == 'fhk_manaperfirst' then
                    local percent = parent._ppFS and parent._ppFS:GetText()
                    percent = type(percent) == 'string' and tonumber(percent:match('(%d+)%%')) or 85
                    percent = percent or 85
                    local max = UnitPowerMax('player', ResourceType('player'))
                    if PublicNumber(max) then
                        local number = ns.AbbreviateNumbers(math.floor(max * percent / 100))
                        value = key == 'fhk_manaperfirst' and string.format('%d%% | %s', percent, number) or
                            string.format('%s | %d%%', number, percent)
                    end
                end
                if value then state.painting=true; self:SetText(value); state.painting=nil end
            end)
        end
        for _, child in ipairs({parent:GetChildren()}) do Visit(child, depth+1) end
    end
    if installed and installed.AbbreviateNumbers then Visit(EUI._contentHeader, 0) end
end
local function InstallOptions()
    local W = EUI.Widgets
    if not W or widgetFactory == W or not W.DualRow then return end
    widgetFactory = W
    local original = W.DualRow
    W.DualRow = function(self, parent, y, left, right)
        if ExtendConfig(left) then ExtendPreview(left) end
        if ExtendConfig(right) then ExtendPreview(right) end
        return original(self, parent, y, left, right)
    end
end
-- NPCs that flee do so near 20 % health: a tick on the target bar marks the point
-- to have Concussive Shot ready (audit P3). Restricted reads draw nothing.
-- Creature type alone misses fleers (player screenshot: a Ghostpaw Runner, a
-- beast, ran at 14 %), so besides humanoids the mark learns: a mob whose
-- "attempts to run away in fear" emote has been seen keeps it by name, per character.
local function FleeLearned(write)
    FHKEllesmereDB=FHKEllesmereDB or {}
    local t=rawget(FHKEllesmereDB,'fleeLearned')
    if write and type(t)~='table' then t={};rawset(FHKEllesmereDB,'fleeLearned',t) end
    return type(t)=='table' and t or nil
end
local function LearnFlee(text,name)
    if type(text)~='string' or (issecretvalue and issecretvalue(text)) or not text:lower():find('run away in fear',1,true) then return end
    if type(name)~='string' or (issecretvalue and issecretvalue(name)) or name=='' then name=text:match('^(.-) attempts to run away') end
    if type(name)=='string' and name~='' and not name:find('%%') then FleeLearned(true)[name]=true end
end
FHK.LearnEllesmereFlee=LearnFlee
local function Yes(v) return not (issecretvalue and issecretvalue(v)) and v==true end
local function FleeingKind(unit)
    local kind=UnitCreatureType and UnitCreatureType(unit)
    local flees=not (issecretvalue and issecretvalue(kind)) and kind=='Humanoid'
    if not flees then
        local learned,name=FleeLearned(),UnitName and UnitName(unit)
        flees=learned and type(name)=='string' and not (issecretvalue and issecretvalue(name)) and learned[name]==true
    end
    if not flees then return false end
    local player=UnitIsPlayer(unit)
    return not (issecretvalue and issecretvalue(player)) and player==false and Yes(UnitCanAttack('player',unit))
end
local function PaintFleeTick(frame,unit)
    local bar=frame.Health
    if not bar then return end
    local tick=bar._fhkFleeTick
    local width=bar.GetWidth and bar:GetWidth()
    local want=unit=='target' and not (FHKEllesmereDB and FHKEllesmereDB.fleeTick==false) and
        PublicNumber(width) and width>0 and FleeingKind(unit)
    local low=bar._fhkFleeTickLow
    if not want then if tick then tick:Hide();low:Hide();tick.edge:Hide();low.edge:Hide() end return end
    -- Two short notches on the top and bottom edges, like a ruler mark (player:
    -- a full-height line ran through the centre-facing health text). Solid white
    -- with a black pixel edge each side (player: "needs to be clearer"), so it
    -- reads on red, gold and class-colour fills alike.
    if not tick then
        local function Notch()
            local t=bar:CreateTexture(nil,'OVERLAY',nil,7)
            t.edge=bar:CreateTexture(nil,'OVERLAY',nil,6);t.edge:SetColorTexture(0,0,0,1)
            return t
        end
        tick=Notch();bar._fhkFleeTick=tick
        low=Notch();bar._fhkFleeTickLow=low
    end
    local px=(EUI.PP and EUI.PP.perfect or 1)/bar:GetEffectiveScale()
    local x=width*.2
    local height=bar.GetHeight and bar:GetHeight()
    local notch=PublicNumber(height) and height>0 and math.max(4*px,height*.3) or 5*px
    local reverse=bar.GetReverseFill and bar:GetReverseFill()
    local side,dx=reverse and 'RIGHT' or 'LEFT',reverse and -x or x
    tick:ClearAllPoints();tick:SetPoint('TOP'..side,bar,'TOP'..side,dx,0)
    low:ClearAllPoints();low:SetPoint('BOTTOM'..side,bar,'BOTTOM'..side,dx,0)
    for _,t in ipairs({tick,low}) do
        -- Bold (player): a 3 px white core inside a 5 px black outline.
        t:SetSize(3*px,notch);t:SetColorTexture(1,1,1,1);t:Show()
        t.edge:ClearAllPoints();t.edge:SetPoint('CENTER',t,'CENTER',0,0);t.edge:SetSize(5*px,notch);t.edge:Show()
    end
end
-- An enemy attacking you rather than your pet gets a WoW-gold edge on its plate:
-- the "act now" colour (Feign Death, reposition, let the pet take it back).
-- Restricted target reads draw nothing (audit P3).
-- Opt-in (forum: "who is the enemy hitting"): an enemy on your pet gets a pet-green
-- edge, so gold (you), green (pet) and none (someone else) read at a glance.
local AGGRO=C.aggroYou or C.caution or {1,.82,0}
local ON_PET=C.aggroPet or C.happy or {.30,.85,.30}
local function PaintAggro(plate)
    local hp=plate.health
    if not hp then return end
    local unit=plate.unit
    local db=FHKEllesmereDB
    local you,pet=not (db and db.aggroPlates==false),db and db.petAggroPlates==true
    local engaged=(you or pet) and type(unit)=='string' and
        not (issecretvalue and issecretvalue(unit)) and Yes(UnitAffectingCombat(unit)) and Yes(UnitCanAttack('player',unit))
    local colour=engaged and (you and Yes(UnitIsUnit(unit..'target','player')) and AGGRO or
        pet and Yes(UnitIsUnit(unit..'target','pet')) and ON_PET) or nil
    local on=colour~=nil
    local edge=hp._fhkAggro
    if not on then if edge then edge:Hide() end return end
    if not edge then
        edge=CreateFrame('Frame',nil,hp);edge:EnableMouse(false);edge.sides={}
        for i=1,4 do edge.sides[i]=edge:CreateTexture(nil,'OVERLAY',nil,7) end
        hp._fhkAggro=edge
    end
    local px=(EUI.PP and EUI.PP.perfect or 1)/hp:GetEffectiveScale()
    if edge._px~=px then
        local w=2*px
        edge:ClearAllPoints();edge:SetPoint('TOPLEFT',hp,'TOPLEFT',-w,w);edge:SetPoint('BOTTOMRIGHT',hp,'BOTTOMRIGHT',w,-w)
        local t,b,l,r=unpack(edge.sides)
        t:ClearAllPoints();t:SetPoint('TOPLEFT');t:SetPoint('TOPRIGHT');t:SetHeight(w)
        b:ClearAllPoints();b:SetPoint('BOTTOMLEFT');b:SetPoint('BOTTOMRIGHT');b:SetHeight(w)
        l:ClearAllPoints();l:SetPoint('TOPLEFT');l:SetPoint('BOTTOMLEFT');l:SetWidth(w)
        r:ClearAllPoints();r:SetPoint('TOPRIGHT');r:SetPoint('BOTTOMRIGHT');r:SetWidth(w)
        edge._px=px
    end
    if edge._colour~=colour or edge._r~=colour[1] or edge._g~=colour[2] or edge._b~=colour[3] then
        edge._r,edge._g,edge._b=colour[1],colour[2],colour[3]
        for _,t in ipairs(edge.sides) do t:SetColorTexture(colour[1],colour[2],colour[3],1) end
        edge._colour=colour
    end
    edge:SetFrameLevel(hp:GetFrameLevel()+5);edge:Show()
end
-- Combat icons as white blocks (player: "simplify them to white blocks"). Ellesmere's
-- own Square style is red and drawn exactly as authored, and red is the danger
-- colour, so the block is ours: white with a black outline, drawn in the native
-- icon's slot (the range block and happiness square grammar). Ellesmere keeps
-- showing and hiding its icon; the block follows it.
local COMBAT_BLOCK=12
local function SyncCombatBlock(icon)
    local block=icon._fhkBlock
    if FHKEllesmereDB and FHKEllesmereDB.combatIconStyle=='native' then
        if block then block:Hide();icon:SetAlpha(1) end
        return
    end
    local owner=icon.GetParent and icon:GetParent()
    if not owner then return end
    if not block then
        if not owner.CreateTexture or not FHK.CreateEllesmereFramedBlock then return end
        -- The shared framed block: the racial icons' pixel border (player).
        block=FHK.CreateEllesmereFramedBlock(owner);block.fill:SetVertexColor(1,1,1,1);icon._fhkBlock=block
        for _,method in ipairs({'Show','Hide','SetShown'}) do
            hooksecurefunc(icon,method,function() SyncCombatBlock(icon) end)
        end
    end
    block:ClearAllPoints();block:SetPoint('CENTER',icon,'CENTER',0,0);block:SetSize(COMBAT_BLOCK,COMBAT_BLOCK)
    local shown=icon:IsShown()
    shown=not (issecretvalue and issecretvalue(shown)) and shown and true or false
    block:SetShown(shown);icon:SetAlpha(0)
end
FHK.SyncEllesmereCombatBlock=SyncCombatBlock
-- Pet combat icon (player: "combat indicators are important, on both"). It sits in
-- the status column outside the pet frame's outer edge, beside the happiness
-- square, and matches the player frame's combat icon so both read as one.
local PET_COMBAT_SIZE=16
local function PaintPetCombat(frame,ns)
    local hp=frame.Health or frame
    local icon=frame._fhkPetCombat
    local on=not (FHKEllesmereDB and FHKEllesmereDB.petCombatIcon==false) and Yes(UnitExists('pet')) and
        Yes(UnitAffectingCombat('pet')) and not Yes(UnitIsDead('pet'))
    if not on then if icon then icon:Hide() end return end
    if not icon then
        local holder=CreateFrame('Frame',nil,frame);holder:SetAllPoints(frame);holder:EnableMouse(false)
        holder:SetFrameLevel(frame:GetFrameLevel()+22)
        icon=holder:CreateTexture(nil,'OVERLAY',nil,7);frame._fhkPetCombat=icon
    end
    local source=ns and ns.frames and ns.frames.player and ns.frames.player._combatIndicator
    local tex=source and source.GetTexture and source:GetTexture()
    if tex and not (issecretvalue and issecretvalue(tex)) then
        icon:SetTexture(tex)
        if source.GetTexCoord then icon:SetTexCoord(source:GetTexCoord()) end
        if source.GetVertexColor then icon:SetVertexColor(source:GetVertexColor()) end
    else
        icon:SetTexture('Interface\\AddOns\\EllesmereUI\\media\\combat\\combat-indicator-custom.png');icon:SetTexCoord(0,1,0,1)
    end
    icon:SetSize(PET_COMBAT_SIZE,PET_COMBAT_SIZE)
    icon:ClearAllPoints();icon:SetPoint('RIGHT',hp,'LEFT',-4,0)
    if FHK.ApplyEllesmereIconEdge then FHK.ApplyEllesmereIconEdge(icon) end
    icon:Show()
    SyncCombatBlock(icon)
end
-- Loot in the health readout (player: replace a dead enemy's 0% with the loot bag).
-- A corpse's 0 % says nothing; the bag (or skinning knife) in the same spot says
-- what to do next, white within reach. Only a zone that shows health alone
-- gives way, so names, levels and power values never disappear.
local function LootTextZone(frame,P)
    if not P or (FHKEllesmereDB and FHKEllesmereDB.lootInHealthText==false) then return end
    for _,zone in ipairs(frame._euiTextZones or {}) do
        local health,other=false,false
        for _,piece in ipairs(zone.pieces or {}) do
            if piece==P.perhp or piece==P.perhpnosign or piece==P.curhpshort then health=true else other=true end
        end
        if health and not other and zone.fs then return zone.fs end
    end
end
local function Paint()
    InstallRaidFills()
    InstallText(); InstallOptions()
    local ns = installed
    if ns then
        local P = ns.TextPieces
        for _, frame in pairs(ns.frames or {}) do
            if IsUnitFrame(frame) then
                local unit = frame._euiUnit or frame._euiBaseUnit
                PaintBarSeparator(frame)
                RefineBar(frame.Health,unit,false,false,'unitframes')
                RefineBar(frame.Power,unit,true,false,'unitframes')
                PaintPowerDeath(frame,unit)
                PaintFleeTick(frame,unit)
                HookCombatBadge(frame)
                if frame._combatIndicator then SyncCombatBlock(frame._combatIndicator) end
                if FHK.AttachEllesmereDamageTrail then FHK.AttachEllesmereDamageTrail(frame.Health,unit,'unitframes') end
                if unit == 'pet' then
                    local dead = UnitIsDead('pet')
                    local alive = not (issecretvalue and issecretvalue(dead)) and not dead and UnitExists('pet')
                    PaintMoodStrip(frame, alive and MoodStripWanted() and ShownMood() or nil)
                    HookPetMood(frame, ns)
                    PaintPetCombat(frame, ns)
                end
                if frame.Power and frame.Power._ppFS then
                    local power=frame.Power
                    if type(power._applyPowerPercentText)=='function' and not power._fhkTextInsetHooked then
                        hooksecurefunc(power,'_applyPowerPercentText',function(s)
                            AlignPowerText(frame,power._ppFS,s)
                            PaintPowerFeedback(frame,frame._euiUnit or frame._euiBaseUnit)
                        end)
                        power._fhkTextInsetHooked=true
                    end
                    AlignPowerText(frame,power._ppFS,Settings(ns,frame))
                end
                local lootColor, lootAlpha, lootTexture
                if FHK.EllesmereLootAppearance then
                    local ignored
                    lootColor, ignored, lootAlpha, lootTexture = FHK.EllesmereLootAppearance(unit)
                end
                if lootColor and not frame._fhkLootIcon then
                    local holder = CreateFrame('Frame', nil, frame)
                    holder:SetAllPoints(frame); holder:SetFrameLevel(frame:GetFrameLevel() + 22)
                    holder:EnableMouse(false)
                    frame._fhkLootIcon = holder:CreateTexture(nil, 'OVERLAY')
                    frame._fhkLootIcon:SetTexture('Interface\\AddOns\\EllesmereUI\\media\\micromenu\\menu-bags.png')
                end
                local loot = frame._fhkLootIcon
                local lootText = lootColor and LootTextZone(frame, P) or nil
                if frame._fhkLootText and frame._fhkLootText ~= lootText then frame._fhkLootText:SetAlpha(1) end
                frame._fhkLootText = lootText
                if lootText then lootText:SetAlpha(0) end
                if loot then
                    loot:SetShown(lootColor ~= nil)
                    if not lootColor and FHK.ResetEllesmereCueAlpha then FHK.ResetEllesmereCueAlpha(loot) end
                    if lootColor then
                        loot:SetTexture(lootTexture)
                        local settings = ns.db and ns.db.profile and ns.db.profile[frame._euiBaseUnit or unit] or {}
                        local native = frame._combatIndicator
                        loot:ClearAllPoints()
                        if lootText then
                            -- Sized to the text it replaces, on the same side.
                            local _, fontSize = lootText:GetFont()
                            local size = PublicNumber(fontSize) and math.max(14, math.min(24, math.floor(fontSize * 1.3 + .5))) or 18
                            loot:SetSize(size, size)
                            local justify = lootText.GetJustifyH and lootText:GetJustifyH()
                            local point = (justify == 'LEFT' or justify == 'CENTER') and justify or 'RIGHT'
                            loot:SetPoint(point, lootText, point, 0, 0)
                        -- An enabled native combat icon is the position authority.
                        elseif native and settings.combatIndicatorStyle and settings.combatIndicatorStyle ~= 'none' then
                            loot:SetAllPoints(native)
                        else
                            local size, x, y = settings.combatIndicatorSize or 18,
                                settings.combatIndicatorX or 0, settings.combatIndicatorY or 0
                            loot:SetSize(size, size)
                            local pos = settings.combatIndicatorPosition or 'healthbar'
                            local anchor = pos == 'portrait' and frame.Portrait or pos == 'textbar' and frame._btb or frame.Health or frame
                            local point = ({topright='TOPRIGHT',bottomright='BOTTOMRIGHT',bottomleft='BOTTOMLEFT',topleft='TOPLEFT'})[pos] or 'CENTER'
                            -- Same edge badge as the combat icon, so the bag never covers the name.
                            if point=='CENTER' and anchor==(frame.Health or frame) and EdgeBadge(settings) then
                                loot:SetPoint('CENTER', anchor, 'TOP', x, y)
                            else loot:SetPoint(point, anchor, point, x, y) end
                        end
                        if FHK.SetEllesmereCueAlpha then
                            loot:SetVertexColor(lootColor[1],lootColor[2],lootColor[3],1)
                            FHK.SetEllesmereCueAlpha(loot,unit,lootAlpha)
                        else loot:SetVertexColor(lootColor[1],lootColor[2],lootColor[3],lootAlpha) end
                        if native then native:Hide() end
                        if FHK.ApplyEllesmereIconEdge then FHK.ApplyEllesmereIconEdge(loot) end
                    end
                end
                local rc = ResourceColor(unit)
                do
                    for _, zone in ipairs(frame._euiTextZones or {}) do
                        if FHK.ApplyEllesmereCueText then FHK.ApplyEllesmereCueText(zone.fs,'bar') end
                        -- Colour health pieces only. Names and class fills are untouched.
                        local health, resource = nil, resourceZones[zone.fs]
                        for _, piece in ipairs(zone.pieces or {}) do
                            if piece == P.perhp or piece == P.curhpshort or piece == P.perhpnosign then health = true end
                            if piece == P.perpp or piece == P.curpp then resource = true end
                        end
                        if health then
                            FHK.PaintEllesmereHealthText(zone.fs, unit, 'unitframes')
                        elseif resource and rc then zone.fs:SetTextColor(rc[1], rc[2], rc[3], 1) end
                    end
                end
                if rc and frame.Power and frame.Power._ppFS then
                    if FHK.ApplyEllesmereCueText then FHK.ApplyEllesmereCueText(frame.Power._ppFS,'bar') end
                    frame.Power._ppFS:SetTextColor(rc[1], rc[2], rc[3], 1)
                end
            end
        end
    end
    local np = _G.EllesmereNameplates_NS
    local dark = Dark()
    for _, plate in pairs(np and np.plates or {}) do
        -- Dark mode: lost health is black, as on the unit frames. Re-set each sweep,
        -- since Ellesmere may repaint the background on a settings refresh.
        local bg = plate.healthBG
        if bg and dark then bg:SetColorTexture(0, 0, 0, 1); plate._fhkDarkBG = true
        elseif bg and plate._fhkDarkBG then
            local p = np.db and np.db.profile
            local c, a = p and p.bgColor or {r=.12, g=.12, b=.12}, p and p.bgAlpha or 1
            bg:SetColorTexture(c.r, c.g, c.b, a); plate._fhkDarkBG = nil
        end
        RefineBar(plate.health,plate.unit,false,false,'nameplates')
        PaintAggro(plate)
        if FHK.AttachEllesmereDamageTrail then FHK.AttachEllesmereDamageTrail(plate.health,plate.unit,'nameplates') end
        for _, key in ipairs({'hpText', 'hpNumber'}) do
            if plate[key] then FHK.PaintEllesmereHealthText(plate[key], plate.unit, 'nameplates') end
        end
    end
end
-- A colour swatch changed a token: cached colour curves rebuild from the new values.
function FHK.ResetEllesmereColourCurves()
    for _,state in pairs(barStates) do state.curve=nil end
end
function FHK.SyncEllesmereUnitRefinements()
    if installed then
        for _,frame in pairs(installed.frames or {}) do
            if IsUnitFrame(frame) and frame.Power and frame.Power._applyPowerPercentText then
                local s=Settings(installed,frame)
                if s then frame.Power._applyPowerPercentText(s) end
            end
        end
    end
    Paint()
    for bar,state in pairs(raidBars) do PaintRaidBar(bar,state) end
end
driver:RegisterEvent('PLAYER_LOGIN')
driver:RegisterEvent('ADDON_LOADED')
driver:RegisterEvent('CHAT_MSG_MONSTER_EMOTE') -- learns fleeing creatures
-- Repaint at once when what the frames show changes; idle sweeps slow down (audit F35).
for _, event in ipairs({'PLAYER_TARGET_CHANGED', 'PLAYER_FOCUS_CHANGED', 'PLAYER_REGEN_DISABLED', 'UNIT_PET', 'UNIT_HAPPINESS',
    'UNIT_THREAT_SITUATION_UPDATE','UNIT_THREAT_LIST_UPDATE','UNIT_FACTION','UNIT_TARGET'}) do
    driver:RegisterEvent(event)
end
local BATCHED = {UNIT_THREAT_SITUATION_UPDATE=true, UNIT_THREAT_LIST_UPDATE=true, UNIT_FACTION=true, UNIT_TARGET=true}
local queued = false
driver:SetScript('OnEvent', function(_, event, unit, sender)
    if event=='CHAT_MSG_MONSTER_EMOTE' then LearnFlee(unit,sender);return end
    -- Forget only the units this event changed (UNIT_TARGET is frequent in combat).
    if event=='PLAYER_TARGET_CHANGED' then powerless.target,powerless.targettarget=nil,nil
    elseif event=='PLAYER_FOCUS_CHANGED' then powerless.focus,powerless.focustarget=nil,nil
    elseif event=='UNIT_PET' then powerless.pet=nil
    elseif event=='UNIT_TARGET' and type(unit)=='string' and not (issecretvalue and issecretvalue(unit)) then
        powerless[unit..'target']=nil
    end
    if event == 'UNIT_PET' or event=='UNIT_HAPPINESS' then Paint()
    elseif BATCHED[event] then
        -- Threat, faction and target changes arrive from every mob in a fight.
        -- Nameplate copies are skipped (the target/focus token fires too) and
        -- the rest share one repaint on the next frame.
        if type(unit)=='string' and not (issecretvalue and issecretvalue(unit)) and unit:find('^nameplate') then return end
        queued=true
    elseif event:find('^UNIT_') then
        if installed and installed.UF_PaintPowerText then
            for _, f in pairs(installed.frames or {}) do
                if IsUnitFrame(f) and (f._euiUnit or f._euiBaseUnit) == unit then
                    installed.UF_PaintPowerText(f, unit)
                    -- Older engines expose no native power-text painter hook at install.
                    if not powerFeedbackHooked then PaintPowerFeedback(f,unit) end
                end
            end
        end
    else Paint() end
end)
local elapsed = 0
driver:SetScript('OnUpdate', function(_, dt)
    elapsed = elapsed + dt
    if queued then queued = false; elapsed = 0; Paint(); return end
    if elapsed < (FHK.EllesmereSweepInterval and FHK.EllesmereSweepInterval() or .15) then return end
    elapsed = 0; Paint()
end)
