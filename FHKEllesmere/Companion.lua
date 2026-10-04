-- All Ellesmere customization lives here; no vendor files are patched.
local EUI, FHK = _G.EllesmereUI, (_G.FHKEllesmereNS or _G.ForeverHunterKeysNS)
if EUI_CLIENT_BLOCKED or not EUI or not FHK or not FHK.GetTargetRange then return end
local DASH, DOT = '\226\128\147', '\194\183' -- en dash, middle dot: shared range text format
local CHAT_FADE_DELAY = 5 -- seconds of quiet before chat fades out
local driver = CreateFrame('Frame')
local hunter = select(2, UnitClass('player')) == 'HUNTER'
local class = select(2, UnitClass('player'))
local hud, range, combat, preview, db, cues
local palette = {}
local samples, samplesAt = {}, -1
local overlays = setmetatable({}, {__mode = 'k'})
local fades = setmetatable({}, {__mode = 'k'})
local rangedEquipType,throwPulseUntil
local function RangedEquipment()
    if not GetInventoryItemID then return end
    local id=GetInventoryItemID('player',18)
    if issecretvalue and issecretvalue(id) then return end
    local info=C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if id and info then
        local _,_,_,equip=info(id)
        if not (issecretvalue and issecretvalue(equip)) then rangedEquipType=equip end
    else rangedEquipType=nil end
end

function FHK.FadeEllesmere(frame, visible)
    if frame._fhkSwingKind and FHK.EllesmereNativeSwingOwnsBars then visible = false end
    local target = visible and 1 or 0
    local f = fades[frame]
    if f and f.target == target then if visible and not frame:IsShown() then frame:Show() end; return end
    local current = f and f.current or frame:GetAlpha()
    if current == target then
        if visible then frame:Show() elseif frame._fhkHideAfterFade then frame:Hide() end
        return
    end
    fades[frame] = {from = current, current = current, target = target, elapsed = 0,
        duration = target == 1 and 0.2 or 0.35}
    if visible then frame:Show() end
end

local function StepFades(dt)
    for frame, f in pairs(fades) do
        if f.current ~= f.target then
            f.elapsed = f.elapsed + dt
            local t = math.min(1, f.elapsed / f.duration)
            t = t * t * (3 - 2 * t)
            f.current = f.from + (f.target - f.from) * t
            frame:SetAlpha(f.current)
            if f.current==0 and frame._fhkHideAfterFade then frame:Hide() end
        end
        if f.current == f.target then fades[frame] = nil end
    end
end

local function CleanTrue(value)
    if issecretvalue and issecretvalue(value) then return false end
    return value == true or value == 1
end

local function SampleUnit(unit)
    unit = unit or 'target'
    if CleanTrue(UnitIsUnit(unit, 'target')) then unit = 'target' end
    local now = GetTime()
    if now < samplesAt or now - samplesAt >= 0.1 then
        for key in pairs(samples) do samples[key] = nil end
        samplesAt = now
    end
    local guid = UnitGUID and UnitGUID(unit)
    local public = not (issecretvalue and issecretvalue(guid))
    local hit = samples[unit]
    if public and hit and hit.guid == guid then return hit.value end
    local value = FHK.GetEllesmereRange and FHK.GetEllesmereRange(unit) or FHK.GetUnitRange(unit)
    if public then samples[unit] = {guid=guid, value=value} end
    return value
end
FHK.GetEllesmereRangeSample = SampleUnit
local function Sample() return SampleUnit('target') end

local function Color(info, fallback)
    return info and {info.r, info.g, info.b} or fallback
end

local function RefreshPalette()
    -- Semantic tokens from Bootstrap (audit F19); copies so nothing mutates the shared set.
    local C = FHK.Colours or {}
    local function Token(c, fallback) c = c or fallback; return {c[1], c[2], c[3]} end
    palette.shoot = Token(C.shoot, {0.25, 0.84, 0.66}) -- jade
    palette.warning = Token(C.caution, {1, 0.82, 0}) -- approaching the deadzone (WoW gold)
    palette.melee = Token(C.melee, {199/255, 135/255, 1}) -- violet #C787FF
    palette.close = Token(C.danger, {1, 0.3, 0.25}) -- WoW red: the deadzone, a hunter's danger
    palette.boundary = palette.close
    -- Out of range (35+) is no action available, not danger (player, 2026-10-03):
    -- the same grey as unknown range and the dimmed action buttons. Red is left
    -- meaning only the deadzone.
    palette.distance, palette.unknown = Token(C.neutral, {0.62, 0.66, 0.70}), Token(C.neutral, {0.62, 0.66, 0.70})
    palette.far, palette.out, palette.beyond = palette.distance, palette.distance, palette.distance
    -- Rings and icons over the world use the bright set. Retry is acid lime.
    local cast = Token(C.cast, {1, 0.435, 0.694})
    palette.retry = Token(C.retry, {198/255, 1, 61/255}) -- acid lime: its own colour
    -- Both timers cooling is a wait, not a danger: slate, so red keeps meaning
    -- out of range / hostile / low health (player rule: not actionable = quiet).
    FHK.EllesmereSwingColors = {ranged = palette.shoot, melee = palette.melee,
        ready = palette.melee, blocked = palette.distance,
        cast = cast,
        retry = palette.retry}
    -- Bars carry white labels, so they take the deep fills of the same colours.
    FHK.EllesmereSwingFillColors = {ranged = Token(C.shootFill, {0.183, 0.615, 0.483}),
        melee = Token(C.meleeFill, {0.762, 0.358, 0.991}), blocked = Token(C.quiet, {0.25, 0.26, 0.29}),
        cast = Token(C.castFill, {254/255, 81/255, 164/255}), retry = Token(C.retryFill, {184/255, 235/255, 46/255})}
    FHK.EllesmerePalette = palette
end

local function Font(fs, size)
    if EUI.ApplyModuleFont then EUI.ApplyModuleFont(fs, nil, size, 'extras')
    else
        fs:SetFont((EUI.GetFontPath and EUI.GetFontPath('extras')) or EUI.EXPRESSWAY or
            'Fonts\\FRIZQT__.TTF', size, 'OUTLINE')
        fs:SetShadowOffset(0, 0)
    end
    if FHK.ApplyEllesmereCueText then FHK.ApplyEllesmereCueText(fs,'world') end
end

local function Pixels(n)
    return EUI.PP and EUI.PP.FromPixels and EUI.PP.FromPixels(n) or n
end

local function Solid(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer)
    t:SetColorTexture(r, g, b, a)
    return t
end

local function ClassIcon(parent, size)
    local t = parent:CreateTexture(nil, 'OVERLAY')
    t:SetSize(size, size)
    t:SetPoint('CENTER')
    local coords = EUI.CLASS_ICON_SPRITE_COORDS and EUI.CLASS_ICON_SPRITE_COORDS[class]
    if coords then
        t:SetTexture('Interface\\AddOns\\EllesmereUI\\media\\combat\\combat-indicator-class-custom.png')
        t:SetTexCoord(unpack(coords))
    else t:SetAtlas('classicon-' .. class:lower()) end
    return t
end

local function AnchorHUD()
    hud:ClearAllPoints()
    hud:SetPoint(db.point or 'CENTER', UIParent, db.relPoint or 'CENTER', db.x or 0, db.y or -125)
end

local function CreateHUD()
    hud = CreateFrame('Frame', 'FHKEllesmereHUD', UIParent)
    hud:SetSize(260, 62)
    hud:SetFrameStrata('MEDIUM')
    hud:SetMovable(true)
    hud:SetClampedToScreen(true)
    hud:RegisterForDrag('LeftButton')
    hud:SetScript('OnDragStart', function(self) if preview then self:StartMoving() end end)
    hud:SetScript('OnDragStop', function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
    end)
    hud:EnableMouse(false)
    AnchorHUD()
    FHK.EllesmereSwingAnchor = hud
    hud.drag = Solid(hud, 'BACKGROUND', 0.04, 0.05, 0.06, 0.8)
    hud.drag:SetAllPoints(); hud.drag:Hide()

    range = CreateFrame('Frame', 'FHKEllesmereRange', hud)
    range:SetSize(260, 22)
    range:SetPoint('TOP')
    range.left = range:CreateFontString(nil, 'OVERLAY')
    range.left:SetPoint('TOPLEFT', 2, -1)
    range.right = range:CreateFontString(nil, 'OVERLAY')
    range.right:SetPoint('TOPRIGHT', -2, -1)
    Font(range.left, 11); Font(range.right, 11)
    range.rail = Solid(range, 'BACKGROUND', 0.12, 0.14, 0.16, 0.9)
    range.rail:SetPoint('BOTTOMLEFT'); range.rail:SetPoint('BOTTOMRIGHT'); range.rail:SetHeight(Pixels(3))
    range.fill = range:CreateTexture(nil, 'ARTWORK')
    range.fill:SetTexture('Interface\\AddOns\\EllesmereUI\\media\\textures\\atrocity.tga')
    range.fill:SetPoint('BOTTOMLEFT'); range.fill:SetPoint('BOTTOMRIGHT'); range.fill:SetHeight(Pixels(3))
    combat = CreateFrame('Frame', 'FHKEllesmereCombat', hud)
    combat:SetSize(24, 24)
    combat:SetPoint('BOTTOM', hud, 'TOP', 0, 6)
    ClassIcon(combat, 24)
    combat:Hide()
    cues = CreateFrame('Frame', 'FHKEllesmereAttackCues', hud)
    cues:SetSize(74, 24)
    cues:SetPoint('TOP', hud, 'BOTTOM', 0, -3)
    cues.cells = {}
    for i, label in ipairs({'AUTO', 'MELEE'}) do
        local cell = CreateFrame('Frame', nil, cues)
        cell:SetSize(34, 30); cell:SetPoint('LEFT', (i - 1) * 40, 0)
        cell.icon = ClassIcon(cell, db.attackCueSize or 28)
        if i == 2 then
            cell.icon:SetTexture('Interface\\AddOns\\EllesmereUI\\media\\combat\\combat-indicator-custom.png')
            cell.icon:SetTexCoord(0, 1, 0, 1)
        end
        cell.text = cell:CreateFontString(nil, 'OVERLAY')
        cell.text:SetPoint('TOP', cell, 'BOTTOM', 0, 0); Font(cell.text, 8)
        cell.text:SetText(label); cell:SetAlpha(0)
        cues.cells[i] = cell
    end
    cues.retry=CreateFrame('Frame',nil,cues)
    cues.retry:SetSize(28,28); cues.retry:SetPoint('LEFT',cues,'RIGHT',12,0)
    cues.retry.icon=cues.retry:CreateTexture(nil,'ARTWORK'); cues.retry.icon:SetAllPoints()
    cues.retry.icon:SetTexture('Interface\\AddOns\\EllesmereUI\\media\\icons\\undo.png')
    cues.retry.text=cues.retry:CreateFontString(nil,'OVERLAY'); Font(cues.retry.text,8)
    cues.retry.text:SetPoint('TOP',cues.retry,'BOTTOM',0,0); cues.retry.text:SetText('RETRY')
    cues.retry:SetAlpha(0)
end
FHK.UpdateEllesmereRetryCue=function(active)
    if not cues or not cues.retry then return end
    -- Beside the range block, retry is the Auto Shot square's own state (player:
    -- only Auto Shot can be retried), so the separate retry glyph stays hidden.
    if cues._flank then
        FHK.FadeEllesmere(cues.retry,false)
        local retrying=active and true or false
        if cues._retrying~=retrying then
            cues._retrying=retrying
            FHK.UpdateEllesmereAttackCues(nil,nil,GetTime())
        end
        return
    end
    cues._retrying=nil
    local c=palette.retry or palette.warning
    cues.retry.icon:SetVertexColor(c[1],c[2],c[3],1)
    cues.retry.text:SetTextColor(c[1],c[2],c[3],1)
    FHK.FadeEllesmere(cues.retry,active)
end

-- Attack cues: one smooth pulse when an attack starts, then static; a smooth
-- fade when it stops (player). Native animation groups, no per-frame maths;
-- reduced motion switches straight between states.
local function CueGroup(cell, steps)
    local ag = cell:CreateAnimationGroup()
    ag._steps = {}
    for i, step in ipairs(steps) do
        local a = ag:CreateAnimation('Alpha')
        a:SetOrder(i); a:SetDuration(step[1]); a:SetSmoothing(step[2])
        ag._steps[i] = a
    end
    return ag
end
local function SetCue(cell, on, opacity, calm)
    if cell._fhkOn == on and cell._fhkOpacity == opacity then return end
    if not cell._fhkOnset and type(cell.CreateAnimationGroup) ~= 'function' then
        cell._fhkOn, cell._fhkOpacity = on, opacity
        cell:SetAlpha(on and opacity or 0); return
    end
    if not cell._fhkOnset then
        cell._fhkOnset = CueGroup(cell, {{.2, 'OUT'}, {.35, 'IN_OUT'}, {.35, 'IN_OUT'}})
        cell._fhkFadeOut = CueGroup(cell, {{.3, 'IN_OUT'}})
    end
    local was, shown = cell._fhkOn, cell._fhkOpacity or opacity
    cell._fhkOn, cell._fhkOpacity = on, opacity
    if on then
        cell._fhkFadeOut:Stop()
        cell:SetAlpha(opacity)
        if not was and not calm then
            local s = cell._fhkOnset._steps
            s[1]:SetFromAlpha(0); s[1]:SetToAlpha(opacity)
            s[2]:SetFromAlpha(opacity); s[2]:SetToAlpha(opacity * .5)
            s[3]:SetFromAlpha(opacity * .5); s[3]:SetToAlpha(opacity)
            cell._fhkOnset:Play()
        end
    else
        cell._fhkOnset:Stop()
        cell:SetAlpha(0)
        if was and not calm then
            local s = cell._fhkFadeOut._steps
            s[1]:SetFromAlpha(shown); s[1]:SetToAlpha(0)
            cell._fhkFadeOut:Play()
        end
    end
end

-- The start/stop event state of each attack, for the swing timers and rings.
FHK.EllesmereAttackState = function()
    if not cues then return false, false end
    return cues._rangedActive and true or false, cues._meleeActive and true or false
end
FHK.UpdateEllesmereAttackCues = function(rangedActive, meleeActive, now)
    if not cues then return end
    if rangedActive~=nil then cues._rangedActive=CleanTrue(rangedActive) end
    if meleeActive~=nil then cues._meleeActive=CleanTrue(meleeActive) end
    local shot=IsCurrentSpell and CleanTrue(IsCurrentSpell(75))
    local shoot=IsCurrentSpell and CleanTrue(IsCurrentSpell(5019))
    local throwing=IsCurrentSpell and CleanTrue(IsCurrentSpell(2764))
    local repeating=IsAutoRepeatSpell and CleanTrue(IsAutoRepeatSpell())
    local pulsing=throwPulseUntil and throwPulseUntil>now
    rangedActive=not not (cues._rangedActive or shot or shoot or throwing or repeating or pulsing)
    -- /fhkautodebug: name the source when the ranged cue lights outside combat.
    if FHK.AutoCueDebug and rangedActive and not cues._debugOn and not InCombatLockdown() then
        print(string.format('FHK auto cue on out of combat: event=%s autoShot=%s shoot=%s throw=%s repeat=%s pulse=%s',
            tostring(cues._rangedActive),tostring(shot),tostring(shoot),tostring(throwing),tostring(repeating),tostring(pulsing)))
    end
    cues._debugOn=rangedActive
    meleeActive=not not (cues._meleeActive or IsCurrentSpell and CleanTrue(IsCurrentSpell(6603)))
    local label=(throwing or rangedEquipType=='INVTYPE_THROWN') and 'THROW' or shoot and 'SHOOT' or hunter and 'AUTO' or 'SHOOT'
    if cues._rangedLabel~=label then cues.cells[1].text:SetText(label);cues._rangedLabel=label end
    local settings=FHK.EllesmereIndicatorSettings and FHK.EllesmereIndicatorSettings('attacks')
    cues:SetShown(not settings or settings.enabled~=false or EUI._unlockActive)
    if cues._flank then
        -- Framed squares beside the range block (player): a square appears only
        -- while its attack is switched on, in the attack's fill, with lime RETRY
        -- on the Auto Shot square. One pulse as it lights, then it holds.
        local calm=EUI._unlockActive or (FHK.EllesmereReduceMotion and FHK.EllesmereReduceMotion())
        local C=FHK.Colours or {}
        local fills=FHK.EllesmereSwingFillColors or {}
        local quiet,grey=C.quiet or {.25,.26,.29},palette.distance or {.62,.66,.70}
        local opacity=settings and settings.opacity or 1
        local showIdle=settings and settings.showIdle==true
        for i=1,2 do
            local cell=cues.cells[i]
            local allowed=not settings or (i==1 and settings.ranged~=false or i==2 and settings.melee~=false)
            local retry=i==1 and cues._retrying
            local active=retry or (i==1 and rangedActive or i==2 and meleeActive)
            local visible=db.attackPulses~=false and allowed and (active or showIdle or EUI._unlockActive) and true or false
            FHK.FadeEllesmere(cell,visible)
            if cell._fhkOpacity~=opacity then
                cell._fhkOpacity=opacity
                if cell.square then cell.square:SetAlpha(opacity) end
                cell.text:SetAlpha(opacity)
            end
            local state=retry and 'retry' or active and (i==1 and 'ranged' or 'melee') or 'idle'
            local text=retry and 'RETRY' or i==1 and label or 'MELEE'
            if cell.text:GetText()~=text then cell.text:SetText(text) end
            if cell._fhkState~=state then
                local fill=state=='idle' and quiet or fills[state] or palette[state] or quiet
                local tc=state=='idle' and grey or state=='retry' and (palette.retry or fill) or
                    (i==1 and palette.shoot or palette.melee)
                if cell.square then cell.square.fill:SetVertexColor(fill[1],fill[2],fill[3],1) end
                cell.text:SetTextColor(tc[1],tc[2],tc[3],1)
                if state~='idle' and cell._fhkState=='idle' and not calm and cell.square and cell.square.CreateAnimationGroup then
                    if not cell.square._fhkPulse then
                        cell.square._fhkPulse=CueGroup(cell.square,{{.35,'IN_OUT'},{.5,'IN_OUT'}})
                    end
                    local s=cell.square._fhkPulse._steps
                    s[1]:SetFromAlpha(opacity);s[1]:SetToAlpha(opacity*.45);s[2]:SetFromAlpha(opacity*.45);s[2]:SetToAlpha(opacity)
                    cell.square._fhkPulse:Play()
                end
                cell._fhkState=state
            end
        end
        return
    end
    for i=1,2 do
        local active=i==1 and rangedActive or i==2 and meleeActive
        local cell, c = cues.cells[i], i == 1 and palette.shoot or palette.melee
        cell.icon:SetVertexColor(c[1], c[2], c[3], 1)
        cell.text:SetTextColor(c[1], c[2], c[3], 1)
        local allowed=not settings or (i==1 and settings.ranged~=false or i==2 and settings.melee~=false)
        local on = db.attackPulses ~= false and allowed and (active or EUI._unlockActive) and true or false
        SetCue(cell, on, settings and settings.opacity or 1,
            EUI._unlockActive or (FHK.EllesmereReduceMotion and FHK.EllesmereReduceMotion()))
    end
end

function FHK.ApplyAttackCueSize()
    if not cues then return end
    local size = db.attackCueSize or 28
    local settings=FHK.EllesmereIndicatorSettings and FHK.EllesmereIndicatorSettings('attacks') or {}
    local vertical=settings.orientation=='vertical'
    -- Either side of the range block (player): Auto Shot / Shoot / Throw on the
    -- left, melee on the right, retry in the middle over the block while it
    -- shows. Gap is the space between each icon and the block.
    local flank=settings.orientation=='flank'
    local gap=settings.gap or 20
    local rs=FHK.EllesmereIndicatorSettings and FHK.EllesmereIndicatorSettings('range') or {}
    local middle=rs.orientation=='block' and rs.blockWidth or 48
    if flank then cues:SetSize(middle+2*gap+2*size,size)
    else cues:SetSize(vertical and size+12 or size*2+gap+6,vertical and size*2+gap+12 or size+12) end
    -- Switching layouts hands the cells to the other painter from a clean state.
    if cues._flank~=flank then
        for _,cell in ipairs(cues.cells) do cell._fhkState,cell._fhkOn,cell._fhkOpacity=nil,nil,nil;cell.text:SetAlpha(1) end
    end
    cues._flank=flank
    for i,cell in ipairs(cues.cells) do
        cell:SetSize(flank and size or size+6,size); cell.icon:SetSize(size,size)
        cell:ClearAllPoints()
        if flank then cell:SetPoint(i==1 and 'LEFT' or 'RIGHT',cues,i==1 and 'LEFT' or 'RIGHT',0,0)
        elseif vertical then cell:SetPoint('TOP',cues,'TOP',0,-(i-1)*(size+gap))
        else cell:SetPoint('LEFT',cues,'LEFT',(i-1)*(size+gap),0) end
        -- Beside the range block each cell is a framed square (the racial icons'
        -- border) with its label underneath; the other layouts keep the glyph.
        if flank and not cell.square and FHK.CreateEllesmereFramedBlock then
            cell.square=FHK.CreateEllesmereFramedBlock(cell);cell.square:SetAllPoints(cell)
        end
        if cell.square then cell.square:SetShown(flank) end
        cell.icon:SetShown(not flank)
        cell.text:ClearAllPoints();cell.text:SetPoint('TOP',cell,'BOTTOM',0,flank and -1 or 0)
        cell.text:SetShown(settings.labels~=false)
        if FHK.ApplyEllesmereIconEdge then FHK.ApplyEllesmereIconEdge(cell.icon) end
        if i==1 then
            local coords=EUI.CLASS_ICON_SPRITE_COORDS and EUI.CLASS_ICON_SPRITE_COORDS[class]
            if settings.style~='combat' and coords then
                cell.icon:SetTexture('Interface\\AddOns\\EllesmereUI\\media\\combat\\combat-indicator-class-custom.png');cell.icon:SetTexCoord(unpack(coords))
            elseif settings.style=='combat' then
                cell.icon:SetTexture('Interface\\AddOns\\EllesmereUI\\media\\combat\\combat-indicator-custom.png');cell.icon:SetTexCoord(0,1,0,1)
            else cell.icon:SetAtlas('classicon-'..class:lower()) end
        end
    end
    if cues.retry then
        -- Beside the range block retry lives in the Auto Shot square instead.
        cues.retry:ClearAllPoints();cues.retry:SetSize(28,28);cues.retry:SetPoint('LEFT',cues,'RIGHT',12,0)
        cues.retry.text:SetShown(settings.labels~=false)
        if flank then cues.retry:SetAlpha(0) end
    end
    if FHK.ApplyEllesmereIconEdge and cues.retry then FHK.ApplyEllesmereIconEdge(cues.retry.icon) end
end
function FHK.StyleEllesmereSwingBar(bar, kind)
    if not hud then return end
    local status = bar.StatusBar
    if not status then return end
    bar._fhkSwingKind = kind
    bar:ClearAllPoints()
    bar:SetParent(hud)
    bar:SetSize(260, kind == 'ranged' and 18 or 14)
    bar:SetPoint('TOP', hud, 'TOP', 0, kind == 'ranged' and -26 or -47)
    bar:SetFrameStrata('MEDIUM')
    if bar.Background then
        if kind == 'melee' then bar.Background:SetColorTexture(57/255, 47/255, 40/255, 0.95)
        else bar.Background:SetColorTexture(0.055, 0.065, 0.075, 0.95) end
    end
    if bar.Border then bar.Border:SetColorTexture(0, 0, 0, 0.85) end
    -- The old atlas border is replaced by a background; no gold trim remains.
    if bar.Border then bar.Border:SetDrawLayer('BACKGROUND', -1) end
    status:ClearAllPoints()
    status:SetPoint('TOPLEFT', bar, 'TOPLEFT', Pixels(1), -Pixels(1))
    status:SetPoint('BOTTOMRIGHT', bar, 'BOTTOMRIGHT', -Pixels(1), Pixels(1))
    status.fill:SetTexture('Interface\\AddOns\\EllesmereUI\\media\\textures\\atrocity.tga')
    status:SetStatusBarTexture(status.fill)
    status.Pip:SetColorTexture(1, 1, 1, 0.75)
    status.Pip:SetSize(Pixels(1), kind == 'ranged' and 16 or 12)
    Font(status.TypeLabel, 10); Font(status.TimeLabel, 10)
    status.TypeLabel:SetTextColor(0.94, 0.94, 0.94)
    status.TimeLabel:SetTextColor(0.94, 0.94, 0.94)
end

local function StyleSwings()
    for _, entry in ipairs({{'ForeverHunterKeysSwingBar', 'ranged'}, {'ForeverHunterKeysMeleeSwingBar', 'melee'}}) do
        local bar = _G[entry[1]]
        if bar then FHK.StyleEllesmereSwingBar(bar, entry[2]) end
    end
end

local function ShootingColor(sample)
    local distance = sample.exact and tonumber(sample.exact:match('^([%d%.]+) yd$'))
    local low = tonumber(sample.bracket:match('^([%d%.]+)' .. DASH))
    -- A broad bracket may include the near edge: prefer a cautious warning.
    distance = distance or low or sample.minimum
    local comfortable = math.min(sample.maximum, sample.minimum + 12)
    local t = math.max(0, math.min(1, (distance - sample.minimum) / math.max(1, comfortable - sample.minimum)))
    t = t * t * (3 - 2 * t)
    local warm, mint = palette.warning, palette.shoot
    return {warm[1] + (mint[1] - warm[1]) * t,
        warm[2] + (mint[2] - warm[2]) * t, warm[3] + (mint[3] - warm[3]) * t}
end

local function RangeAppearance(sample)
    if not hunter then
        local c=sample.state=='melee' and palette.melee or
            (sample.state=='out' or sample.state=='far' or sample.state=='beyond') and palette.out or
            sample.state=='unknown' and palette.unknown or
            sample.distance and sample.distance>=.8*(sample.maximum or 40) and palette.warning or palette.shoot
        return c,sample.state=='melee' and 'Melee' or ''
    end
    local low, high = sample.bracket:match('^([%d%.]+)' .. DASH .. '([%d%.]+) yd$')
    local boundary = sample.state == 'distance' and tonumber(low) and tonumber(low) >= 5 and
        tonumber(low) < sample.minimum and tonumber(high) > sample.minimum
    local c = sample.state == 'shoot' and ShootingColor(sample) or
        palette[boundary and 'boundary' or sample.state] or palette.unknown
    return c, sample.state == 'close' and 'DEADZONE' or boundary and 'DEADZONE?' or sample.title
end

local function PaintRange(sample)
    local c, label = RangeAppearance(sample)
    range.left:SetText(label)
    range.right:SetText(FHK.EllesmereDistanceText(sample.bracket ~= '' and sample.bracket or '? yd'))
    range.left:SetTextColor(unpack(c)); range.right:SetTextColor(unpack(c))
    local settings=FHK.EllesmereIndicatorSettings and FHK.EllesmereIndicatorSettings('range')
    local custom=settings and settings.colourMode=='custom' and settings.colour
    range.fill:SetVertexColor(custom and custom.r or c[1],custom and custom.g or c[2],custom and custom.b or c[3],settings and settings.opacity or .95)
    -- Weapon icon style follows the equipped ranged weapon.
    if range.icon and range.icon:IsShown() and GetInventoryItemTexture then
        local tex=GetInventoryItemTexture('player',18)
        if tex and range.icon._tex~=tex then range.icon:SetTexture(tex);range.icon._tex=tex end
    end
end

function FHK.EllesmereDistanceText(text)
    if FHKEllesmereDB and FHKEllesmereDB.showRangeUnits then return text end
    return (text:gsub(' yd', ''))
end


local function RestorePlateGlow(f, ns)
    if not f.tintedGlow then return end
    local color = ns.GetTargetGlowColor and ns.GetTargetGlowColor() or {r = 1, g = 1, b = 1}
    local alpha = ns.GetTargetGlowAlpha and ns.GetTargetGlowAlpha() or 1
    for _, tex in ipairs(f.tintedGlow) do tex:SetVertexColor(color.r, color.g, color.b, alpha) end
    f.tintedGlow = nil
end

local function PlateOverlay(plate)
    if overlays[plate] then return overlays[plate] end
    if not plate.health then return end
    local f = CreateFrame('Frame', nil, plate)
    f:SetAllPoints(plate.health)
    f:SetFrameLevel(plate:GetFrameLevel() + 35)
    f.icon = ClassIcon(f, 12)
    -- The health value needs the middle of the bar; put combat beside the name.
    f.icon:ClearAllPoints()
    f.icon:SetPoint('LEFT', plate.health, 'TOPRIGHT', 5, 10)
    f.loot = f:CreateTexture(nil, 'OVERLAY')
    f.loot:SetTexture('Interface\\AddOns\\EllesmereUI\\media\\micromenu\\menu-bags.png')
    f.loot:SetSize(14, 14)
    f.loot:SetPoint('LEFT', plate.health, 'TOPRIGHT', 5, 10)
    f.rangeStrip = f:CreateTexture(nil, 'OVERLAY')
    -- Full-height accent inside the right edge, independent of target glow.
    f.rangeStrip:SetPoint('TOPRIGHT', plate.health, 'TOPRIGHT', 0, 0)
    f.rangeStrip:SetPoint('BOTTOMRIGHT', plate.health, 'BOTTOMRIGHT', 0, 0)
    f.rangeStrip:SetWidth(Pixels(6))
    f.rangeStrip:SetColorTexture(1, 1, 1, 1)
    f.rangeStrip:Hide()
    f.text = f:CreateFontString(nil, 'OVERLAY')
    plate._euiRangeDefaultText=f.text
    Font(f.text, 10)
    f.icon:Hide(); f.loot:Hide(); f.text:Hide()
    if plate.name then
        f.baseNameColor = {plate.name:GetTextColor()}
        hooksecurefunc(plate.name, 'SetTextColor', function(self, r, g, b, a)
            if f.settingName then return end
            f.baseNameColor = {r, g, b, a or 1}
            if f.nameColor then
                f.settingName = true; self:SetTextColor(unpack(f.nameColor)); f.settingName = nil
            end
        end)
    end
    overlays[plate] = f
    return f
end

local function PaintPlateName(plate, f, color)
    f.nameColor = color
    if not plate.name then return end
    if FHK.ApplyEllesmereCueText then FHK.ApplyEllesmereCueText(plate.name,'world') end
    local c = color or f.baseNameColor
    if c and #c >= 3 then
        f.settingName = true; plate.name:SetTextColor(unpack(c)); f.settingName = nil
    end
end

local lootCursorProbe, lootCursorReferences
local function CorpseCursorAction(unit)
    if type(SetUnitCursorTexture) ~= 'function' then return end
    if not lootCursorProbe then
        lootCursorProbe = driver:CreateTexture(nil, 'BACKGROUND'); lootCursorProbe:Hide()
        lootCursorReferences = {}
        for _, name in ipairs({'Loot', 'LootAll', 'UnableLoot', 'UnableLootAll', 'Skin', 'UnableSkin'}) do
            local reference = driver:CreateTexture(nil, 'BACKGROUND'); reference:Hide()
            reference:SetTexture('Interface\\Cursor\\' .. name)
            lootCursorReferences[#lootCursorReferences+1] = {texture=reference,
                action=name:find('Skin') and 'skin' or 'loot', ready=not name:find('Unable')}
        end
    end
    -- Query this corpse, not whichever unit the player currently hovers.
    -- Clear first: a failed/no-cursor query must not reuse another corpse's art.
    lootCursorProbe:SetTexture(nil)
    lootCursorProbe:SetVertexColor(1,1,1,1)
    lootCursorProbe:SetDesaturated(false)
    local style = Enum and Enum.CursorStyle and Enum.CursorStyle.Mouse
    -- Hover aliases use the same unit route as the hardware cursor. Never
    -- borrow another corpse's cursor just because it is currently hovered.
    local query = CleanTrue(UnitIsUnit(unit,'mouseover')) and 'mouseover' or unit
    local ok, hasCursor = pcall(SetUnitCursorTexture, lootCursorProbe, query, style, true)
    if not ok or not CleanTrue(hasCursor) then return end
    local texture = lootCursorProbe:GetTexture()
    local desaturated = lootCursorProbe.IsDesaturated and lootCursorProbe:IsDesaturated()
    local function AppearanceReady(ready)
        -- Some styles reuse the ready file and desaturate/dim it for an error.
        if CleanTrue(desaturated) then return false end
        if lootCursorProbe.GetVertexColor then
            local r,g,b = lootCursorProbe:GetVertexColor()
            if type(r)=='number' and type(g)=='number' and type(b)=='number' and
                not (issecretvalue and (issecretvalue(r) or issecretvalue(g) or issecretvalue(b))) and
                math.max(r,g,b) < .8 then return false end
        end
        return ready
    end
    if not (issecretvalue and issecretvalue(texture)) and texture then
        for _, reference in ipairs(lootCursorReferences) do
            local expected = reference.texture:GetTexture()
            if not (issecretvalue and issecretvalue(expected)) and expected and texture == expected then
                return reference.action, AppearanceReady(reference.ready)
            end
        end
    end
    -- Some client styles expose an atlas/path instead of the reference file ID.
    local atlas = lootCursorProbe.GetAtlas and lootCursorProbe:GetAtlas()
    for _, name in ipairs({type(texture)=='string' and texture or '', type(atlas)=='string' and atlas or ''}) do
        if not (issecretvalue and issecretvalue(name)) then
            name = name:lower():gsub('[^%a]', '')
            if name:find('unableloot',1,true) then return 'loot', false end
            if name:match('lootall$') or name:match('loot$') or name:match('lootallblp$') or name:match('lootblp$') then return 'loot', AppearanceReady(true) end
            if name:find('unableskin',1,true) then return 'skin', false end
            if name:match('skin$') or name:match('skinblp$') or name:match('skinning$') then return 'skin', AppearanceReady(true) end
        end
    end
end

local function LootAppearance(unit)
    local lootOff = FHKEllesmereDB and FHKEllesmereDB.lootCues == false
    local skinOff = FHKEllesmereDB and FHKEllesmereDB.skinCues == false
    if lootOff and skinOff then return end
    if not unit or not CanLootUnit or not UnitGUID or not CleanTrue(UnitExists(unit)) or
        not CleanTrue(UnitIsDead(unit)) then return end
    local guid = UnitGUID(unit)
    if (issecretvalue and issecretvalue(guid)) or not guid then return end
    local ok, hasLoot, allowed = pcall(CanLootUnit, guid)
    if not ok or (issecretvalue and issecretvalue(hasLoot)) or hasLoot == nil then return end
    local action, cursorReady = CorpseCursorAction(unit)
    local looting = CleanTrue(hasLoot)
    -- Loot always takes priority. Offer skinning only after the loot is gone,
    -- and only when the client reports a skinning cursor for this corpse.
    -- Each cue honours only its own toggle (audit F05).
    if looting and lootOff then return end
    if not looting and (action ~= 'skin' or skinOff) then return end
    local logic = FHK.RangeLogic
    local yards = logic and logic.ReadDistance(unit)
    local bracket = not yards and logic and logic.ReadLibraryBracket(unit)
    local nearby = action == 'loot' and cursorReady
    if action ~= 'loot' then nearby = nil end
    if nearby == nil then
        nearby = yards and yards <= 5 or bracket and bracket.high and bracket.high <= 5
    end
    -- A resolved native cursor includes the client's interaction eligibility.
    -- Only the distance fallback needs a separate ownership check. The old
    -- duel-distance fallback could light this up anywhere inside a 0-8 bracket.
    local ready = looting and (action == 'loot' and cursorReady == true or action ~= 'loot' and nearby and CleanTrue(allowed)) or
        not looting and cursorReady == true
    local color = ready and {1, 1, 1} or palette.unknown
    local distance = yards and string.format('%.1f yd', yards) or bracket and
        (bracket.high and string.format('%g' .. DASH .. '%g yd', bracket.low, bracket.high) or string.format('%g+ yd', bracket.low))
    local icon = looting and 'Interface\\AddOns\\EllesmereUI\\media\\micromenu\\menu-bags.png' or
        (FHK.RefinementsMediaRoot or 'Interface\\AddOns\\FHKEllesmere\\media\\') .. 'menu-skinning.png'
    return color, (looting and 'Loot ' .. DOT .. ' ' or 'Skin ' .. DOT .. ' ') .. FHK.EllesmereDistanceText(distance or '? yd'), ready and .9 or .28, icon
end
FHK.EllesmereLootAppearance = LootAppearance
FHK.EllesmereCursorDiagnostics = function(unit)
    local action, ready = CorpseCursorAction(unit)
    local guid = UnitGUID(unit)
    local hasLoot, allowed
    if not (issecretvalue and issecretvalue(guid)) and guid and CanLootUnit then hasLoot,allowed=CanLootUnit(guid) end
    local function Value(v) return issecretvalue and issecretvalue(v) and '<restricted>' or tostring(v) end
    print('Ellesmere cursor: ' .. Value(unit) .. ' | action=' .. Value(action) ..
        ' | ready=' .. Value(ready) .. ' | loot=' .. Value(hasLoot) .. ' | allowed=' .. Value(allowed))
    if lootCursorProbe then
        local texture=lootCursorProbe:GetTexture()
        if not (issecretvalue and issecretvalue(texture)) then print('Cursor texture: ' .. tostring(texture)) end
    end
end

-- Dark mode plate names show who a unit is, in WoW's bright reaction colours.
local function ReactionColour(unit)
    local reaction = unit and UnitReaction and UnitReaction(unit, 'player')
    if not reaction or (issecretvalue and issecretvalue(reaction)) then return nil end
    if reaction == 4 then return palette.warning end -- neutral: WoW gold
    if reaction <= 3 then return palette.close end   -- hostile: WoW red
    local C = FHK.Colours or {}
    return C.happy or {.30, .85, .30}                 -- friendly: WoW green
end
local function UpdatePlates(sample)
    local ns = _G.EllesmereNameplates_NS
    if not ns or not ns.plates then return end
    local dark = FHK.EllesmereDarkMode and FHK.EllesmereDarkMode() or false
    for _, plate in pairs(ns.plates) do
        local unit = plate.unit
        local f = PlateOverlay(plate)
        if f then
            -- One combat glyph (player frame): the engaged mark repeats what the gold
            -- aggro edge and the plate's own state say. Opt back in with Extra Combat Icons.
            local engaged = db.extraCombatIcons == true and unit and UnitAffectingCombat(unit)
            f.icon:SetShown(CleanTrue(engaged) and not CleanTrue(UnitIsDead(unit)))
            if FHK.ApplyEllesmereIconEdge then FHK.ApplyEllesmereIconEdge(f.icon) end
            local lootColor, lootText, lootAlpha, lootIcon = LootAppearance(unit)
            f.loot:SetShown(lootColor ~= nil)
            if not lootColor and FHK.ResetEllesmereCueAlpha then FHK.ResetEllesmereCueAlpha(f.loot) end
            local enemy = unit and CleanTrue(UnitExists(unit)) and CleanTrue(UnitCanAttack('player', unit)) and
                not CleanTrue(UnitIsDead(unit))
            local reading = enemy and (CleanTrue(UnitIsUnit(unit, 'target')) and sample or SampleUnit(unit))
            if FHK.ApplyEllesmereNameplateOpacity then FHK.ApplyEllesmereNameplateOpacity(plate,reading) end
            local showGlow = enemy and reading and reading.state ~= 'unknown'
            local selected = unit and CleanTrue(UnitIsUnit(unit, 'target'))
            -- Dark mode: every enemy plate carries its range strip (player request).
            local mark = showGlow and (dark or not selected and db.nonTargetRange ~= false)
            if FHK.SetEllesmereRangeMarkShown then FHK.SetEllesmereRangeMarkShown(plate, f, mark)
            else f.rangeStrip:SetShown(mark) end
            local native = not dark and db.targetRangeGlow ~= false and showGlow and selected and plate.glowFrame and plate.glowFrame:IsShown() and plate.glowTextures
            if dark and selected and plate.glowTextures then
                -- On black the target glow overpowers everything: a faint light edge instead.
                for _, tex in ipairs(plate.glowTextures) do tex:SetVertexColor(1, 1, 1, .3) end
                f.tintedGlow = plate.glowTextures
            elseif not native then RestorePlateGlow(f, ns) end
            local rangeText = db.nameplateRangeText ~= false and not dark
            -- Selected plates use only EUI's original glow, never our fallback.
            f.text:SetShown(lootColor ~= nil or enemy and reading and rangeText)
            if enemy and reading then
                local c, label = RangeAppearance(reading)
                PaintPlateName(plate, f, dark and ReactionColour(unit) or db.rangeNameColors ~= false and c or nil)
                if FHK.PaintEllesmereRangeStripe then FHK.PaintEllesmereRangeStripe(plate,f,c)
                else f.rangeStrip:SetVertexColor(c[1],c[2],c[3],.7) end
                if native then
                    for _, tex in ipairs(native) do tex:SetVertexColor(c[1], c[2], c[3], 0.7) end
                    f.tintedGlow = native
                end
                f.text:SetTextColor(unpack(c))
                f.text:SetText(FHK.EllesmereDistanceText((label == 'DEADZONE' or label == 'DEADZONE?') and
                    (reading.bracket .. ' ' .. DOT .. ' ' .. label) or (reading.bracket ~= '' and reading.bracket or '? yd')))
                f.text:ClearAllPoints()
                local anchor = plate.cast and plate.cast:IsShown() and plate.cast or plate.health
                f.text:SetPoint('TOP', anchor, 'BOTTOM', 0, -5)
                if FHK.PaintEllesmereRangeText then
                    -- Dark mode: the strip carries range, so the text stays off.
                    local assigned=FHK.PaintEllesmereRangeText(plate,f,FHK.EllesmereDistanceText(reading.bracket),label,c,rangeText)
                    f.text:SetShown(not assigned and rangeText)
                end
            elseif lootColor then
                if FHK.PaintEllesmereRangeText then FHK.PaintEllesmereRangeText(plate,f,'','',palette.unknown,false) end
                PaintPlateName(plate, f, nil)
                f.loot:SetTexture(lootIcon)
                if FHK.SetEllesmereCueAlpha then
                    f.loot:SetVertexColor(lootColor[1],lootColor[2],lootColor[3],1)
                    FHK.SetEllesmereCueAlpha(f.loot,unit,lootAlpha)
                else f.loot:SetVertexColor(lootColor[1],lootColor[2],lootColor[3],lootAlpha) end
                if FHK.ApplyEllesmereIconEdge then FHK.ApplyEllesmereIconEdge(f.loot) end
                f.text:SetText(lootText); f.text:SetTextColor(unpack(lootColor))
                f.text:ClearAllPoints(); f.text:SetPoint('TOP', plate.health, 'BOTTOM', 0, -5)
            else
                if FHK.PaintEllesmereRangeText then FHK.PaintEllesmereRangeText(plate,f,'','',palette.unknown,false) end
                PaintPlateName(plate,f,nil)
            end
            if FHK.PositionEllesmereRarityBadge then FHK.PositionEllesmereRarityBadge(plate) end
        end
    end
    -- A recycled plate may have been removed from ns.plates before this tick.
    for plate, f in pairs(overlays) do
        if not plate.unit or ns.plates[plate.unit] ~= plate then
            RestorePlateGlow(f, ns); PaintPlateName(plate, f, nil); f:Hide()
        else f:Show() end
    end
end

local function ChatSettings()
    local ns = EUI._ModuleNS and EUI._ModuleNS.EllesmereUIChat
    local chat = ns and ns.ECHAT
    if not chat or not chat.DB then return end
    local cfg = chat.DB()
    if not db.chatConfigured then
        db.chatBefore = {enabled = cfg.idleFadeEnabled, delay = cfg.idleFadeDelay, strength = cfg.idleFadeStrength}
        cfg.idleFadeEnabled, cfg.idleFadeDelay, cfg.idleFadeStrength = true, CHAT_FADE_DELAY, 100
        db.chatConfigured = true
        if chat.ResetIdleTimer then chat.ResetIdleTimer() end
    end
    -- 2: the player found 10 s too long. Only our own earlier value is shortened;
    -- a delay the player set in the native Chat options is left alone.
    if (rawget(db, 'chatFadeVersion') or 1) < 2 then
        rawset(db, 'chatFadeVersion', 2)
        if cfg.idleFadeDelay == 10 then
            cfg.idleFadeDelay = CHAT_FADE_DELAY
            if chat.ResetIdleTimer then chat.ResetIdleTimer() end
        end
    end
    -- The player wants chat out of the way in combat: switched on once; the
    -- Hide Chat In Combat toggle turns it off again for good.
    if not rawget(db, 'chatCombatHideApplied') and FHK.SetEllesmereChatHiddenInCombat then
        if FHK.SetEllesmereChatHiddenInCombat(true) then rawset(db, 'chatCombatHideApplied', true) end
    end
    if FHK.ApplyEllesmereChatQuiet then FHK.ApplyEllesmereChatQuiet() end
end

-- Quiet chat (player request): chat is fully hidden unless you are typing or
-- hovering it; it fades CHAT_QUIET_DELAY seconds after the mouse leaves. Public
-- chat lines no longer wake it (whispers still do). Uses Ellesmere's own idle
-- fade; the previous fade settings are kept on the chat profile and restored.
local CHAT_QUIET_DELAY = 2
local chatWakeHooked
function FHK.EllesmereChatQuiet() return db and db.chatQuiet ~= false end
function FHK.ApplyEllesmereChatQuiet()
    local ns = EUI._ModuleNS and EUI._ModuleNS.EllesmereUIChat
    local chat = ns and ns.ECHAT
    if not chat or not chat.DB then return false end
    local cfg = chat.DB()
    if FHK.EllesmereChatQuiet() then
        if not cfg.fhkQuietBefore then
            cfg.fhkQuietBefore = {enabled = cfg.idleFadeEnabled, delay = cfg.idleFadeDelay, strength = cfg.idleFadeStrength}
        end
        cfg.idleFadeEnabled, cfg.idleFadeDelay, cfg.idleFadeStrength = true, CHAT_QUIET_DELAY, 100
        if not chatWakeHooked and type(chat.ResetIdleTimer) == 'function' and type(chat.EngineSetIdleObserver) == 'function' then
            -- Ellesmere re-arms its chat-line wake on every timer reset; drop it while quiet.
            hooksecurefunc(chat, 'ResetIdleTimer', function()
                if FHK.EllesmereChatQuiet() then chat.EngineSetIdleObserver(nil) end
            end)
            chatWakeHooked = true
        end
    else
        local before = cfg.fhkQuietBefore
        if before then
            cfg.idleFadeEnabled, cfg.idleFadeDelay, cfg.idleFadeStrength = before.enabled, before.delay, before.strength
            cfg.fhkQuietBefore = nil
        end
    end
    if chat.ResetIdleTimer then chat.ResetIdleTimer() end
    if chat.ApplyIdleFadeHoverMotion then chat.ApplyIdleFadeHoverMotion() end
    return true
end

-- Hide chat in combat through Ellesmere's own visibility lanes (hide_in_combat):
-- the native chat module re-evaluates on combat changes. The previous
-- visibility is kept on the chat profile and restored when switched off.
local function ChatStore()
    local ns = EUI._ModuleNS and EUI._ModuleNS.EllesmereUIChat
    local chat = ns and ns.ECHAT
    return chat and chat.DB and chat.DB(), chat
end
function FHK.EllesmereChatHiddenInCombat()
    local cfg = ChatStore()
    if not cfg or not EUI.GetVisibilitySelection then return false end
    local selection = EUI.GetVisibilitySelection(cfg, 'visibility')
    return selection.hide_in_combat == true
end
function FHK.SetEllesmereChatHiddenInCombat(on)
    local cfg, chat = ChatStore()
    if not cfg or not EUI.SetVisibilitySelection or not EUI.GetVisibilitySelection then return false end
    if on then
        if FHK.EllesmereChatHiddenInCombat() then return true end
        local selection = EUI.GetVisibilitySelection(cfg, 'visibility')
        local before = {}
        for k, v in pairs(selection) do before[k] = v end
        cfg.fhkVisibilityBefore = before
        local wanted = {}
        for k, v in pairs(selection) do wanted[k] = v end
        wanted.hide_in_combat = true
        EUI.SetVisibilitySelection(cfg, 'visibility', wanted)
    else
        local before = cfg.fhkVisibilityBefore
        if before then EUI.SetVisibilitySelection(cfg, 'visibility', before)
        else
            local selection = EUI.GetVisibilitySelection(cfg, 'visibility')
            selection.hide_in_combat = nil
            EUI.SetVisibilitySelection(cfg, 'visibility', selection)
        end
        cfg.fhkVisibilityBefore = nil
    end
    if chat and chat.RefreshVisibility then chat.RefreshVisibility() end
    return true
end

-- Neutral reaction fill: WoW gold under shadowed white text (Colours.reactionNeutral).
-- Version 2 wrote the old pastel caution yellow here, which left neutral mobs
-- cream with unreadable white text (player report); version 3 replaced exactly
-- that value with an olive gold, which read as mustard beside the vivid fills
-- (player report), then an amber that read as orange. Version 5 replaces any
-- of those exact old values with WoW gold and leaves any colour the player picked.
local function NeutralFill()
    local c = (FHK.Colours and FHK.Colours.reactionNeutral) or {.772, .632, 0}
    return {r = c[1], g = c[2], b = c[3]}
end
local function OldPastelNeutral(c)
    if type(c) ~= 'table' or type(c.r) ~= 'number' or type(c.g) ~= 'number' or type(c.b) ~= 'number' then return false end
    local function Is(r, g, b) return math.abs(c.r - r) < .001 and math.abs(c.g - g) < .001 and math.abs(c.b - b) < .001 end
    return Is(.914, .835, .541) or Is(.62, .53, .10) or Is(.797, .579, .098)
end
local function MigrateNeutralFill()
    local np = _G.EllesmereNameplates_NS
    if np and np.db and np.db.profile and OldPastelNeutral(np.db.profile.neutral) then
        np.db.profile.neutral = NeutralFill()
        if np.RefreshAllSettings then np.RefreshAllSettings() end
    end
    local uf = EUI._ModuleNS and EUI._ModuleNS.EllesmereUIUnitFrames
    local p = uf and uf.db and uf.db.profile
    if p and p.enemyColors and OldPastelNeutral(p.enemyColors.neutral) then
        p.enemyColors.neutral = NeutralFill()
        if uf.ApplyEnemyColors then uf.ApplyEnemyColors() end
    end
    -- Theme preset backups captured the pastel as "original"; Restore must not bring it back.
    for _, state in pairs(db.themePresets or {}) do
        local backup = type(state) == 'table' and state.backup
        if backup and backup.enemyColors and OldPastelNeutral(backup.enemyColors.neutral) then backup.enemyColors.neutral = NeutralFill() end
        if backup and backup.plate and OldPastelNeutral(backup.plate.neutral) then backup.plate.neutral = NeutralFill() end
    end
end

FHK.MigrateEllesmereNeutralFill = MigrateNeutralFill
local function RefineNativeIndicators()
    if db.refinementVersion == 5 then return end
    if db.refinementVersion and db.refinementVersion >= 2 then MigrateNeutralFill(); db.refinementVersion = 5; return end
    db.targetDistanceBefore = EllesmereUIDB and EllesmereUIDB.targetDistanceEnabled
    if EllesmereUIDB then EllesmereUIDB.targetDistanceEnabled = false end
    if EUI._applyTargetDistance then EUI._applyTargetDistance() end
    local np = _G.EllesmereNameplates_NS
    if np and np.db and np.db.profile then
        db.neutralBefore = np.db.profile.neutral
        np.db.profile.neutral = NeutralFill()
        db.rangeTextBefore = np.db.profile.rangeTextEnabled
        np.db.profile.rangeTextEnabled = false
        if np.RangeText_Apply then np.RangeText_Apply() end
        if np.RefreshAllSettings then np.RefreshAllSettings() end
    end
    local uf = EUI._ModuleNS and EUI._ModuleNS.EllesmereUIUnitFrames
    if uf and uf.db and uf.db.profile then
        local p = uf.db.profile
        p.enemyColors = p.enemyColors or {}
        db.unitNeutralBefore = p.enemyColors.neutral
        p.enemyColors.neutral = NeutralFill()
        if uf.ApplyEnemyColors then uf.ApplyEnemyColors() end
    end
    db.refinementVersion = 5
end

local function InstallRangeAdapters()
    if not hunter then return end
    -- Retain original implementations for every other class/custom cutoff.
    if EUI.Range_GetAttackCutoff then
        local original = EUI.Range_GetAttackCutoff
        EUI.Range_GetAttackCutoff = function(custom, holy)
            if tonumber(custom) then return original(custom, holy) end
            return Sample().maximum
        end
    end
    if EUI.Range_ItemBracket then
        local original = EUI.Range_ItemBracket
        EUI.Range_ItemBracket = function(unit, stop)
            if unit == 'target' and CleanTrue(UnitCanAttack('player', 'target')) then
                local s = Sample()
                if s.state == 'close' then return 5, s.minimum end
                if s.state == 'melee' then return 0, 5 end
                if s.state == 'shoot' then
                    local low, high = s.bracket:match('^([%d%.]+)' .. DASH .. '([%d%.]+) yd$')
                    if low then return tonumber(low), tonumber(high) end
                end
            end
            return original(unit, stop)
        end
    end
    if EUI.Range_LowerBound then
        local original = EUI.Range_LowerBound
        EUI.Range_LowerBound = function(unit)
            if unit == 'target' and CleanTrue(UnitCanAttack('player', 'target')) then
                local s = Sample()
                if s.state == 'close' then return 5 end
                if s.state == 'melee' then return 0 end
                if s.state == 'shoot' then return tonumber(s.bracket:match('^([%d%.]+)')) end
            end
            return original(unit)
        end
    end
    if EUI.Range_IsBeyondAttackRange then
        local original = EUI.Range_IsBeyondAttackRange
        EUI.Range_IsBeyondAttackRange = function(unit, cutoff)
            if unit == 'target' then
                local s = Sample()
                if not cutoff or cutoff == s.maximum then
                    if s.state == 'close' or s.state == 'far' then return true end
                    if s.state == 'shoot' or s.state == 'melee' then return false end
                    return nil
                end
            end
            return original(unit, cutoff)
        end
    end
    -- Native plate fades use the sweep API, not the single-target adapter.
    if EUI.Range_SweepBeyond then
        local original = EUI.Range_SweepBeyond
        EUI.Range_SweepBeyond = function(unit, cutoff)
            if not unit then return nil end
            local np = _G.EllesmereNameplates_NS
            local p = np and np.db and np.db.profile
            if cutoff and p and p.outOfRangeMode == 'custom' then return original(unit, cutoff) end
            local s = SampleUnit(unit)
            if cutoff and cutoff ~= s.maximum then return original(unit, cutoff) end
            if s.state == 'close' or s.state == 'far' or s.state == 'out' then return true end
            if s.state == 'shoot' or s.state == 'melee' then return false end
            return nil
        end
    end
end

-- Apply the player's request once; later native opacity choices remain theirs.
function FHK.EnableEllesmereRequestedRangeFade()
    if not db or rawget(db,'rangeOpacityRequested') then return end
    local np=_G.EllesmereNameplates_NS
    local p=np and np.db and np.db.profile
    if not p or not np.RangeText_Apply then return end
    rawset(db,'rangeOpacityBefore',{mode=p.outOfRangeMode,alpha=p.outOfRangeAlpha})
    if p.outOfRangeMode==nil or p.outOfRangeMode=='disabled' then p.outOfRangeMode='auto' end
    if p.outOfRangeAlpha==nil or p.outOfRangeAlpha==100 then p.outOfRangeAlpha=50 end
    np.RangeText_Apply()
    rawset(db,'rangeOpacityRequested',true)
end

-- Range bar on Ellesmere target / focus / target-of-target frames.
local FRAME_MARK_UNITS = {target = true, focus = true, targettarget = true}
local function UpdateFrameMarks(sample)
    local uf = EUI._ModuleNS and EUI._ModuleNS.EllesmereUIUnitFrames
    if not uf or not uf.frames or not FHK.PaintEllesmereFrameRangeMark or not FHK.EllesmereIndicatorSettings then return end
    local settings = FHK.EllesmereIndicatorSettings('frame')
    for _, frame in pairs(uf.frames) do
        local unit = type(frame) == 'table' and (frame._euiUnit or frame._euiBaseUnit)
        if FRAME_MARK_UNITS[unit] and type(frame.GetFrameLevel) == 'function' then
            local reading
            if settings.enabled ~= false and settings[unit] ~= false and CleanTrue(UnitExists(unit)) and
                CleanTrue(UnitCanAttack('player', unit)) and not CleanTrue(UnitIsDead(unit)) then
                reading = unit == 'target' and sample or SampleUnit(unit)
            end
            if reading and reading.state ~= 'unknown' then
                FHK.PaintEllesmereFrameRangeMark(frame, (RangeAppearance(reading)), true)
            else FHK.PaintEllesmereFrameRangeMark(frame, nil, false) end
        end
    end
end

-- Repeatable preview scenarios (audit F32): fixed range states for the centre
-- indicator, so a style change can be compared on the same state every time.
local SCENARIOS = {
    inrange = {state='shoot',title='Shooting',bracket='25' .. DASH .. '30 yd',exact='27.0 yd',minimum=8,maximum=35},
    approaching = {state='shoot',title='Shooting',bracket='8' .. DASH .. '10 yd',minimum=8,maximum=35},
    deadzone = {state='close',title='Deadzone',bracket='5' .. DASH .. '8 yd',minimum=8,maximum=35},
    melee = {state='melee',title='Melee',bracket='0' .. DASH .. '5 yd',minimum=8,maximum=35},
    out = {state='far',title='Out of range',bracket='35+ yd',minimum=8,maximum=35},
    unknown = {state='unknown',title='Range unavailable',bracket='',minimum=8,maximum=35},
}
local scenario, scenarioToken
local Tick
local facing={untilTime=0,token=0}
local function FacingEnabled()
    local s=FHK.EllesmereIndicatorSettings and FHK.EllesmereIndicatorSettings('range')
    return not s or s.enabled~=false and (s.facingWarning~=false or s.castFailureWarning==true)
end
local function ClearFacing()
    facing.untilTime=0;facing.token=facing.token+1
    if facing.timer then facing.timer:Cancel();facing.timer=nil end
end
local function FacingError(id,message)
    if issecretvalue and (issecretvalue(id) or issecretvalue(message)) then return false end
    local s=FHK.EllesmereIndicatorSettings and FHK.EllesmereIndicatorSettings('range')
    if not s or s.facingWarning~=false then
        for _,key in ipairs({'ERR_BADATTACKFACING','SPELL_FAILED_UNIT_NOT_INFRONT','SPELL_FAILED_NOT_INFRONT'}) do
            local expected=_G[key]
            if type(expected)=='string' and message==expected then return 'FACE TARGET' end
        end
        for _,key in ipairs({'LE_GAME_ERR_BADATTACKFACING','LE_GAME_ERR_SPELL_FAILED_NOT_IN_FRONT','LE_GAME_ERR_SPELL_FAILED_UNIT_NOT_INFRONT'}) do
            local expected=_G[key]
            if type(expected)=='number' and id==expected then return 'FACE TARGET' end
        end
    end
    if s and s.castFailureWarning==true then
        for key,label in pairs({SPELL_FAILED_LINE_OF_SIGHT='NO LINE OF SIGHT',SPELL_FAILED_MOVING='STOP MOVING'}) do
            local expected=_G[key]
            if type(expected)=='string' and message==expected then return label end
        end
    end
    return false
end
function FHK.SyncEllesmereFacingCue()
    if not db then return end
    local s=FHK.EllesmereIndicatorSettings and FHK.EllesmereIndicatorSettings('range')
    if facing.label and s and (facing.label=='FACE TARGET' and s.facingWarning==false or
        facing.label~='FACE TARGET' and s.castFailureWarning~=true) then ClearFacing() end
    if not FacingEnabled() then
        if facing.events then facing.events:UnregisterAllEvents() end
        ClearFacing();if Tick then Tick() end;return
    end
    if not facing.events then
        facing.events=CreateFrame('Frame')
        facing.events:SetScript('OnEvent',function(_,event,a,b,c)
            if event=='UI_ERROR_MESSAGE' then
                local label=FacingError(a,b)
                if not label or not CleanTrue(UnitExists('target')) then return end
                ClearFacing();facing.label=label;facing.untilTime=GetTime()+1.2
                local token=facing.token
                local function Expire()
                    if token~=facing.token then return end
                    facing.untilTime=0;facing.timer=nil;Tick()
                end
                if C_Timer.NewTimer then facing.timer=C_Timer.NewTimer(1.2,Expire)
                else C_Timer.After(1.2,Expire) end
            elseif event=='UNIT_SPELLCAST_SUCCEEDED' then
                if issecretvalue and (issecretvalue(a) or issecretvalue(c)) then return end
                if a~='player' then return end
                local ok,harmful=false,false
                if C_Spell and C_Spell.IsSpellHarmful then ok,harmful=pcall(C_Spell.IsSpellHarmful,c) end
                if not ok or not CleanTrue(harmful) then return end
                ClearFacing()
            else ClearFacing() end
            Tick()
        end)
    end
    for _,event in ipairs({'UI_ERROR_MESSAGE','UNIT_SPELLCAST_SUCCEEDED','PLAYER_TARGET_CHANGED','PLAYER_ENTERING_WORLD'}) do
        facing.events:RegisterEvent(event)
    end
end
-- Diagnostic only: public coordinates do not establish spell-specific facing rules.
function FHK.ReadEllesmereFacingPosition()
    if not UnitPosition or not GetPlayerFacing then return nil,'position or facing API unavailable' end
    local function Position(unit)
        local ok,x,y,z,map=pcall(UnitPosition,unit)
        local function Number(v)
            return not (issecretvalue and issecretvalue(v)) and type(v)=='number' and v==v and math.abs(v)<math.huge
        end
        if ok and Number(x) and Number(y) and Number(z) and Number(map) then return x,y,map end
    end
    local px,py,pm=Position('player')
    local tx,ty,tm=Position('target')
    local ok,angle=pcall(GetPlayerFacing)
    if not ok or issecretvalue and issecretvalue(angle) or type(angle)~='number' or
        angle~=angle or math.abs(angle)==math.huge or not px or not tx then return nil,'positions or character facing unreadable' end
    if pm~=tm then return nil,'units are on different maps' end
    local dx,dy=tx-px,ty-py
    if dx*dx+dy*dy<.01 then return nil,'positions are coincident or unavailable' end
    return dx*math.cos(angle)+dy*math.sin(angle)>=0,'public position estimate'
end
function FHK.ExplainEllesmereFacing()
    local front,why=FHK.ReadEllesmereFacingPosition()
    print('FHK facing: '..(front==nil and why or front and 'position estimate: target in the forward half' or 'position estimate: target behind the character')..
        '. Character direction determines facing; camera free-look can differ.')
    print('FACE TARGET uses the client\'s confirmed facing error and clears on a harmful cast, target change or after 1.2 seconds.')
end
SLASH_FHKFACING1='/fhkfacing'
SlashCmdList.FHKFACING=function() FHK.ExplainEllesmereFacing() end
function FHK.SetEllesmerePreviewScenario(name)
    if name == 'warnings' then return FHK.PreviewEllesmereWarnings and FHK.PreviewEllesmereWarnings() or nil end
    if name == 'history' then return FHK.PreviewEllesmereActionHistory and FHK.PreviewEllesmereActionHistory() or nil end
    scenario = SCENARIOS[name] and name or nil
    local started = scenario ~= nil
    local token = {}; scenarioToken = token
    Tick()
    if started and C_Timer then C_Timer.After(10, function() if scenarioToken == token then scenario = nil; Tick() end end) end
    return started
end
FHK.EllesmerePreviewScenarios = SCENARIOS

Tick = function()
    if not db then return end
    local s = Sample()
    if hud then
        local target = CleanTrue(UnitExists('target')) and CleanTrue(UnitCanAttack('player', 'target')) and not CleanTrue(UnitIsDead('target'))
        local settings=FHK.EllesmereIndicatorSettings and FHK.EllesmereIndicatorSettings('range')
        FHK.FadeEllesmere(range,(not settings or settings.enabled~=false) and (preview or scenario or EUI._unlockActive or target))
        FHK.FadeEllesmere(combat, db.extraCombatIcons == true and (preview or CleanTrue(UnitAffectingCombat('player'))))
        if scenario then PaintRange(SCENARIOS[scenario])
        elseif (preview or EUI._unlockActive) and not target then
            PaintRange(hunter and {state='close',title='Deadzone',bracket='5' .. DASH .. '8 yd',minimum=8,maximum=35} or
                {state='distance',title='Distance',bracket='5' .. DASH .. '10 yd',minimum=0,maximum=40,distance=7})
        elseif target then PaintRange(s) end
        if target and FacingEnabled() and facing.untilTime>GetTime() then
            range.left:SetText(facing.label or 'FACE TARGET');range.left:Show()
            range.left:SetTextColor(unpack(palette.close))
            range.fill:SetVertexColor(palette.close[1],palette.close[2],palette.close[3],settings and settings.opacity or .95)
        elseif settings then
            range.left:SetShown(settings.text~=false and settings.orientation~='icon' and settings.orientation~='block')
            if settings.orientation=='block' then range.right:Hide() end
        end
    end
    UpdatePlates(s)
    UpdateFrameMarks(s)
    if FHK.UpdateEllesmereMarkerFades then FHK.UpdateEllesmereMarkerFades() end
    FHK.UpdateEllesmereAttackCues(nil,nil,GetTime())
end

-- Hunter colours (plan section 5, player: selectable colours). The identity tokens change
-- in place, so every cached reference follows; a token's bar fill follows its colour (the
-- palette's fills sit at 73 % of the bright value). Unset keys keep the shipped palette.
local HUNTER_COLOURS={shoot='shootFill',melee='meleeFill',cast='castFill',retry='retryFill',danger=false,caution=false}
local shipped
local function ApplyHunterColours(restyle)
    local C=FHK.Colours
    if type(C)~='table' then RefreshPalette();return end
    if not shipped then
        shipped={}
        for key,fill in pairs(HUNTER_COLOURS) do
            if type(C[key])=='table' then shipped[key]={C[key][1],C[key][2],C[key][3]} end
            if fill and type(C[fill])=='table' then shipped[fill]={C[fill][1],C[fill][2],C[fill][3]} end
        end
    end
    local saved=FHKEllesmereDB and FHKEllesmereDB.hunterColors
    for key,fill in pairs(HUNTER_COLOURS) do
        local own=type(saved)=='table' and type(saved[key])=='table' and saved[key] or nil
        local base=shipped[key]
        if base and type(C[key])=='table' then
            local v=own or base
            C[key][1],C[key][2],C[key][3]=v[1],v[2],v[3]
            if fill and shipped[fill] and type(C[fill])=='table' then
                local f=own and {v[1]*.73,v[2]*.73,v[3]*.73} or shipped[fill]
                C[fill][1],C[fill][2],C[fill][3]=f[1],f[2],f[3]
            end
        end
    end
    RefreshPalette()
    if restyle then
        if hunter then StyleSwings() end
        if FHK.ApplySwingCursor then pcall(FHK.ApplySwingCursor) end
        if FHK.ApplyEllesmereIndicators then pcall(FHK.ApplyEllesmereIndicators) end
        Tick()
    end
end
FHK.ApplyEllesmereHunterColours=function() ApplyHunterColours(true) end
FHK.EllesmereHunterColourDefaults=function() return shipped end

local function Initialize()
    FHKEllesmereDB = FHKEllesmereDB or {}
    db = FHKEllesmereDB
    ApplyHunterColours(false)
    RangedEquipment()
    CreateHUD(); FHK.ApplyAttackCueSize()
    if FHK.RegisterEllesmereIndicators then FHK.RegisterEllesmereIndicators(range,cues,hud) end
    if hunter then StyleSwings() end
    ChatSettings()
    RefineNativeIndicators()
    InstallRangeAdapters()
    FHK.EnableEllesmereRequestedRangeFade()
    if FHK.SyncEllesmereNameplateOpacity then FHK.SyncEllesmereNameplateOpacity() end
    FHK.SyncEllesmereFacingCue()
    if EUI.ApplyColorsToOUF then hooksecurefunc(EUI, 'ApplyColorsToOUF', function()
        RefreshPalette(); StyleSwings(); Tick()
    end) end
    if EUI.RegAccent then EUI.RegAccent({type = 'callback', fn = function() RefreshPalette(); StyleSwings(); Tick() end}) end
    Tick()
end

driver:RegisterEvent('PLAYER_LOGIN')
driver:RegisterEvent('PLAYER_TARGET_CHANGED')
driver:RegisterEvent('PLAYER_FOCUS_CHANGED')
driver:RegisterEvent('NAME_PLATE_UNIT_ADDED')
driver:RegisterEvent('NAME_PLATE_UNIT_REMOVED')
driver:RegisterEvent('PLAYER_REGEN_DISABLED')
driver:RegisterEvent('PLAYER_REGEN_ENABLED')
driver:RegisterEvent('SPELLS_CHANGED')
driver:RegisterEvent('PLAYER_EQUIPMENT_CHANGED');driver:RegisterEvent('PLAYER_SWING')
driver:RegisterEvent('START_AUTOREPEAT_SPELL');driver:RegisterEvent('STOP_AUTOREPEAT_SPELL')
driver:SetScript('OnEvent', function(_, event,duration,swingType)
    if event=='PLAYER_EQUIPMENT_CHANGED' then RangedEquipment()
    elseif event=='START_AUTOREPEAT_SPELL' and cues then cues._rangedActive=true
    elseif event=='STOP_AUTOREPEAT_SPELL' and cues then cues._rangedActive=false
    elseif event=='PLAYER_SWING' and rangedEquipType=='INVTYPE_THROWN' and
        not (issecretvalue and issecretvalue(swingType)) and swingType==(Enum.PlayerSwingType.Ranged or 2) then
        throwPulseUntil=GetTime()+.75
    end
    for key in pairs(samples) do samples[key] = nil end
    samplesAt = -1
    if event == 'PLAYER_LOGIN' then C_Timer.After(0, Initialize) else Tick() end
end)
local elapsed = 0
driver:SetScript('OnUpdate', function(_, dt)
    StepFades(dt)
    elapsed = elapsed + dt
    -- Range and corpse cues only move while something is live (audit F35).
    local interval = (preview or scenario or not FHK.EllesmereSweepInterval) and 0.15 or FHK.EllesmereSweepInterval()
    if elapsed < interval then return end
    elapsed = 0
    Tick()
end)

-- /fhkperf: the game's own addon profiler, ranked (player report: FPS dropped).
-- Read-only; nothing runs until the command is typed. /fhkperf mark sets a
-- baseline, so later reports count slow frames in play, not the login spike.
SLASH_FHKPERF1 = '/fhkperf'
local perfMark
SlashCmdList.FHKPERF = function(input)
    local command = tostring(input or ''):lower():match('^%s*(%S*)')
    local P, M = C_AddOnProfiler, Enum and Enum.AddOnProfilerMetric
    local fps = GetFramerate and GetFramerate() or 0
    print(string.format('FHK perf: %.0f FPS (%.1f ms per frame)', fps, fps > 0 and 1000 / fps or 0))
    if not (P and P.GetAddOnMetric and M and M.RecentAverageTime and C_AddOns) then
        print('FHK perf: the addon profiler is not available on this client.'); return
    end
    if P.IsEnabled and not P.IsEnabled() then print('FHK perf: the addon profiler reports it is off; numbers may be zero.') end
    local marking = command == 'mark'
    if marking then perfMark = {} end
    local rows, total = {}, 0
    for i = 1, C_AddOns.GetNumAddOns() do
        local name = C_AddOns.GetAddOnInfo(i)
        if name and C_AddOns.IsAddOnLoaded(name) then
            local ok, recent = pcall(P.GetAddOnMetric, name, M.RecentAverageTime)
            local okPeak, peak = pcall(P.GetAddOnMetric, name, M.PeakTime)
            -- Peak includes login/reload; the 50 ms count separates one load spike from repeated stutter.
            local okSlow, slow = false, nil
            if M.CountTimeOver50Ms then okSlow, slow = pcall(P.GetAddOnMetric, name, M.CountTimeOver50Ms) end
            if marking then perfMark[name] = okSlow and type(slow) == 'number' and slow or 0 end
            if ok and type(recent) == 'number' then
                rows[#rows + 1] = {name, recent, okPeak and type(peak) == 'number' and peak or 0,
                    okSlow and type(slow) == 'number' and slow or nil,
                    perfMark and perfMark[name] and okSlow and type(slow) == 'number' and slow - perfMark[name] or nil}
                total = total + recent
            end
        end
    end
    if marking then
        print('FHK perf: marked. Play normally, then /fhkperf counts slow frames since now.'); return
    end
    table.sort(rows, function(a, b) return a[2] > b[2] end)
    for i = 1, math.min(12, #rows) do
        local r = rows[i]
        local slow = r[5] and string.format(', %d over 50 ms since mark', r[5]) or
            r[4] and string.format(', %d over 50 ms', r[4]) or ''
        print(string.format('%2d. %s  %.3f ms/frame  (peak %.1f ms%s)', i, r[1], r[2], r[3], slow))
    end
    print(string.format('FHK perf: all addons %.2f ms per frame.', total))
    if not perfMark then print('FHK perf: peaks include login and loading screens. /fhkperf mark, play, then /fhkperf to count only in-play stutter.') end
end

-- /fhkautodebug: session-only trace for the Auto Shot cue (player report:
-- it flashes outside combat). Prints nothing until switched on.
SLASH_FHKAUTODEBUG1 = '/fhkautodebug'
SlashCmdList.FHKAUTODEBUG = function()
    FHK.AutoCueDebug = not FHK.AutoCueDebug
    print('FHK: Auto Shot cue trace '..(FHK.AutoCueDebug and 'on. It prints the cause when the cue lights outside combat.' or 'off.'))
end

SLASH_FHKELLESMERE1 = '/fhkeui'
SlashCmdList.FHKELLESMERE = function(input)
    if not db then return end
    local command, value = tostring(input or ''):lower():match('^%s*(%S*)%s*(%S*)')
    if command == 'unlock' and hud then
        preview = true; hud:EnableMouse(true); hud.drag:Show(); Tick()
        print('FHK Ellesmere: drag the centre HUD, then /fhkeui lock.')
    elseif command == 'lock' and hud then
        preview = false; hud:StopMovingOrSizing(); hud:EnableMouse(false); hud.drag:Hide(); Tick()
    elseif command == 'reset' and hud then
        db.point, db.relPoint, db.x, db.y = nil, nil, nil, nil
        AnchorHUD()
    elseif command == 'chat' then
        local ns = EUI._ModuleNS and EUI._ModuleNS.EllesmereUIChat
        local chat = ns and ns.ECHAT
        if chat and chat.DB then
            local cfg = chat.DB()
            -- An explicit fade choice replaces quiet chat.
            db.chatQuiet = false; cfg.fhkQuietBefore = nil
            if value == 'restore' and db.chatBefore then
                cfg.idleFadeEnabled, cfg.idleFadeDelay, cfg.idleFadeStrength =
                    db.chatBefore.enabled, db.chatBefore.delay, db.chatBefore.strength
            else
                cfg.idleFadeEnabled, cfg.idleFadeDelay, cfg.idleFadeStrength = true, math.max(1, tonumber(value) or 10), 100
            end
            if chat.ResetIdleTimer then chat.ResetIdleTimer() end
            print('FHK Ellesmere: native chat fade settings applied.')
        end
    elseif command == 'units' then
        db.showRangeUnits = value == 'on'
        Tick()
        print('FHK Ellesmere: range units ' .. (db.showRangeUnits and 'shown.' or 'hidden.'))
    elseif command == 'status' then
        print('FHK Ellesmere 1.8.0: companion active; vendor files unchanged.')
        if hunter then local s = Sample(); print('Range: ' .. s.title .. ' | ' .. s.bracket) end
    elseif command == 'cursor' then
        FHK.EllesmereCursorDiagnostics(value ~= '' and value or 'mouseover')
      else print('/fhkeui unlock | lock | reset | chat [seconds/restore] | units [on/off] | cursor [unit] | status') end
end

SLASH_FHKPREVIEW1 = '/fhkpreview'
SlashCmdList.FHKPREVIEW = function(input)
    local name = tostring(input or ''):lower():match('^%s*(%S*)')
    if name == '' or name == 'off' then FHK.SetEllesmerePreviewScenario(nil); return end
    if not FHK.SetEllesmerePreviewScenario(name) and not (name == 'warnings' or name == 'history') then
        print('FHK preview: inrange, approaching, deadzone, melee, out, unknown, warnings, history, off')
    end
end
