-- Optional swing rings on Ellesmere's existing Cursor settings page.
local EUI, FHK = _G.EllesmereUI, (_G.FHKEllesmereNS or _G.ForeverHunterKeysNS)
if EUI_CLIENT_BLOCKED or not EUI or not FHK or not FHK.GetCursorSwingClock then return end
local driver = CreateFrame('Frame')
local root, rings, retryIcon, subscribed, optionsWrapper, resetWrapper, swingFollow, fallbackElapsed
local textures = {thin=true, light=true, normal=true, heavy=true, thick=true}
-- Ring nesting (player: the cursor circles took too much screen). Each ring's inner
-- edge sits RING_GAP units outside the ring it surrounds, instead of fixed 8 and 6
-- unit steps that made the stack 88 units wide and let the two swing rings touch.
-- Inner edges are the measured 50%-alpha band of Ellesmere's ring art (radius = 1).
local RING_INNER = {thin=.906, light=.859, normal=.813, heavy=.766, thick=.688}
-- 1.5 units is about 2 px at UI scale 0.8 on the player's 2560x1440 16-inch panel.
-- Auto Shot, the ring a hunter watches most, sits innermost of the two swing
-- rings; melee, the rare one, goes outside it (player: the stack read large,
-- with an empty band between the GCD and the Auto Shot ring).
local RING_GAP = 1.5
local function PublicNumber(v)
    return not (issecretvalue and issecretvalue(v)) and type(v)=='number' and v==v and v>-math.huge and v<math.huge
end
local MODES = {ranged=true, melee=true, combined=true, separate=true}
-- Saved on/off keys and the value a damaged entry falls back to; OPTIONAL keys read ~=false.
local FLAGS = {enabled=false, matchGCD=true, combatOnly=false, readinessColors=true, showMeleeReady=true,
    showRangedReady=false, avoidCast=true}
local OPTIONAL = {'avoidGCD', 'showRetry', 'resetOnMelee'}
local function Settings()
    if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end
    FHKEllesmereDB.swingCursor = FHKEllesmereDB.swingCursor or {
        enabled=false, mode='ranged', matchGCD=true, radius=27, ringTex='light', alpha=80, combatOnly=false,
        readinessColors=true, showMeleeReady=true, showRangedReady=false, combinedRings='two',
    }
    if type(FHKEllesmereDB.swingCursor)~='table' then FHKEllesmereDB.swingCursor = nil; return Settings() end
    local cfg = FHKEllesmereDB.swingCursor
    if cfg.mode == 'both' then cfg.mode = 'combined' end
    -- Damaged saved values (a hand edit, an old version) fall back to their defaults.
    if not MODES[cfg.mode] then cfg.mode = 'ranged' end
    for key, default in pairs(FLAGS) do
        if cfg[key] ~= nil and type(cfg[key]) ~= 'boolean' then cfg[key] = default end
    end
    for _, key in ipairs(OPTIONAL) do if type(cfg[key]) ~= 'boolean' then cfg[key] = nil end end
    if cfg.radius ~= nil and not PublicNumber(cfg.radius) then cfg.radius = 27 end
    if cfg.alpha ~= nil and not PublicNumber(cfg.alpha) then cfg.alpha = 80 end
    if cfg.ringTex ~= nil and not textures[cfg.ringTex] then cfg.ringTex = 'light' end
    if cfg.combinedRings ~= 'one' and cfg.combinedRings ~= 'two' then cfg.combinedRings = nil end
    if cfg.readinessColors == nil then cfg.readinessColors = true end
    if cfg.showMeleeReady == nil then cfg.showMeleeReady = true end
    if cfg.showRangedReady == nil then cfg.showRangedReady = false end
    if cfg.avoidCast == nil then cfg.avoidCast = true end
    cfg.combinedRings = cfg.combinedRings or 'two'
    return cfg
end
local anchor, lastX, lastY
local function Position(x, y, force)
    if not root or not root:IsShown() then return end
    local cursor = _G.EllesmereUICursorFrame
    local gcd = _G._ECL_AceDB and _G._ECL_AceDB.profile and _G._ECL_AceDB.profile.gcd
    local native = cursor and cursor:IsShown() and cursor or
        (gcd and gcd.enabled and gcd.attached ~= false and _G.ECL_GCDRoot and _G.ECL_GCDRoot:IsShown() and _G.ECL_GCDRoot)
    if native then
        if anchor ~= native then
            root:ClearAllPoints(); root:SetPoint('CENTER', native, 'CENTER', 0, 0); anchor = native
        end
        -- Preserve its centre if the native reticle is hidden during camera look.
        if native.GetCenter then lastX, lastY = native:GetCenter() end
        return
    end
    -- Mouselook freezes the cursor sample; a ring that appears during it still takes that
    -- frozen point once (review S4) instead of where the last swing ended.
    local looking=IsMouselooking and IsMouselooking()
    if not force and not (issecretvalue and issecretvalue(looking)) and looking==true then return end
    -- Offsets are in the anchor's coordinate system, not the ring's own scale.
    local scale = UIParent:GetEffectiveScale()
    if not PublicNumber(x) or not PublicNumber(y) or not PublicNumber(scale) or scale<=0 then return end
    x, y = x / scale, y / scale
    if anchor ~= UIParent or lastX ~= x or lastY ~= y then
        root:ClearAllPoints(); root:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', x, y)
        anchor, lastX, lastY = UIParent, x, y
    end
end
local function StopSwingFollow()
    if swingFollow then EUI.Mouse.UnsubscribeFrame('fhkSwingCursorFollow');swingFollow=nil end
end
local function SyncSwingFollow(x,y)
    if not root or not root:IsShown() then StopSwingFollow();return end
    local mouse=EUI.Mouse
    if mouse and mouse.Get and mouse.SubscribeFrame and mouse.UnsubscribeFrame then
        root:SetScript('OnUpdate',nil)
        if not swingFollow then
            local mx,my=mouse.Get()
            Position(mx,my,true)
            mouse.SubscribeFrame('fhkSwingCursorFollow',Position,true)
            swingFollow=true
        else
            -- State ticks already carry the shared sample. Re-anchor on visibility
            -- changes even at rest, without querying the cursor again each tick.
            if not PublicNumber(x) or not PublicNumber(y) then x,y=mouse.rawX,mouse.rawY end
            Position(x,y)
        end
    elseif not root:GetScript('OnUpdate') then
        Position(GetCursorPosition())
        root:SetScript('OnUpdate',function() Position(GetCursorPosition()) end)
    end
end
local function Create()
    root = CreateFrame('Frame', 'FHKEllesmereSwingCursor', UIParent)
    root:SetSize(64, 64); root:SetFrameStrata('TOOLTIP'); root:SetFrameLevel(9990); root:EnableMouse(false)
    rings = {}
    for _, kind in ipairs({'ranged', 'melee'}) do
        local cd = CreateFrame('Cooldown', nil, root, 'CooldownFrameTemplate')
        -- The template anchors to all of the 64-unit root, so SetSize alone never
        -- resized the sweep (player: the rings stayed large through every pass).
        cd:ClearAllPoints(); cd:SetPoint('CENTER'); cd:SetFrameLevel(root:GetFrameLevel() + 1)
        cd:SetHideCountdownNumbers(true); cd:SetDrawEdge(false); cd:SetDrawBling(false); cd:SetReverse(true)
        cd:EnableMouse(false); cd:Hide()
        cd.ready = root:CreateTexture(nil, 'OVERLAY')
        cd.ready:SetPoint('CENTER'); cd.ready:Hide()
        -- Dark mode backing: a black ring under the thin coloured sweep.
        cd.track = root:CreateTexture(nil, 'ARTWORK')
        cd.track:SetPoint('CENTER'); cd.track:Hide()
        rings[kind] = cd
    end
    root:Hide()
    root:SetAlpha(0)
    root._fhkHideAfterFade=true
    retryIcon=root:CreateTexture(nil,'OVERLAY')
    retryIcon:SetSize(16,16); retryIcon:SetTexture('Interface\\AddOns\\EllesmereUI\\media\\icons\\undo.png')
    retryIcon:Hide()
    root:SetScript('OnShow',SyncSwingFollow)
    root:SetScript('OnHide',StopSwingFollow)
end
local function Active(start, duration, finish, now)
    return type(start) == 'number' and type(duration) == 'number' and type(finish) == 'number' and
        (not issecretvalue or not (issecretvalue(start) or issecretvalue(duration) or issecretvalue(finish))) and
        duration > 0 and finish > now
end
-- Reused every tick (20 per second): Refresh allocates nothing.
local KINDS = {'ranged', 'melee'}
local starts, durations, finishes, busy = {}, {}, {}, {}
local function Refresh(x,y)
    local cfg = Settings()
    if not cfg.enabled then if root then root:Hide() end;StopSwingFollow();return end
    if not root then Create() end
    if EUI._unlockActive or cfg.combatOnly and not UnitAffectingCombat('player') then root:Hide();StopSwingFollow();return end
    local gcd = _G._ECL_AceDB and _G._ECL_AceDB.profile and _G._ECL_AceDB.profile.gcd or {}
    -- Scale and the retry anchor change rarely: set them only on change (review S7, 20 ticks a second).
    local scale = cfg.matchGCD and (gcd.scale or 100) / 100 or 1
    if root._fhkScale ~= scale then root:SetScale(scale); root._fhkScale = scale end
    local texture = cfg.matchGCD and gcd.ringTex or cfg.ringTex
    texture = textures[texture] and texture or 'light'
    local inner = RING_INNER[texture]
    local function Outside(edge) return (edge + RING_GAP) / inner end
    local radius = cfg.radius or 27
    if cfg.avoidGCD ~= false and gcd.enabled and gcd.attached ~= false then
        local nativeScale = (gcd.scale or 100) / 100
        local ourScale = cfg.matchGCD and nativeScale or 1
        radius = math.max(radius, Outside((gcd.radius or 30) * nativeScale / ourScale))
    end
    local cast = _G._ECL_AceDB and _G._ECL_AceDB.profile and _G._ECL_AceDB.profile.castCircle
    if cfg.avoidCast ~= false and cast and cast.enabled and cast.attached ~= false then
        local ourScale = cfg.matchGCD and (gcd.scale or 100) / 100 or 1
        radius = math.max(radius, Outside((cast.radius or 30) * (cast.scale or 100) / 100 / ourScale))
    end
    local outer = Outside(radius) -- melee ring around Auto Shot
    local alpha = (cfg.matchGCD and gcd.alpha or cfg.alpha or 80) / 100
    local now, shown = GetTime(), false
    for _, kind in ipairs(KINDS) do
        starts[kind], durations[kind], finishes[kind] = FHK.GetCursorSwingClock(kind)
        busy[kind] = Active(starts[kind], durations[kind], finishes[kind], now)
    end
    local combined = cfg.mode == 'combined'
    local palette = FHK.EllesmerePalette or {}
    -- Cooling rings keep their weapon colour, also when both cool: a grey swing
    -- ring read like the white GCD ring beside it (player). Two sweeping rings
    -- already say both are cooling; the bars keep their BOTH CD label.
    local green, brown = palette.shoot or {.25,.84,.66}, palette.melee or {.78,.61,.43}
    local cue, cueStart, cueDuration, cueEnd
    if FHK.GetAutoShotCue then cue,cueStart,cueDuration,cueEnd=FHK.GetAutoShotCue() end
    local showCue=cfg.showRetry ~= false and (cue=='retry' or cue=='cast') and
        (combined or cfg.mode=='separate' or cfg.mode=='ranged') and Active(cueStart,cueDuration,cueEnd,now)
    if showCue then
        starts.ranged,durations.ranged,finishes.ranged=cueStart,cueDuration,cueEnd
        busy.ranged=true
    end
    local retryColour = palette.retry or {198/255,1,61/255} -- retry: acid lime, its own colour
    retryIcon:SetVertexColor(retryColour[1],retryColour[2],retryColour[3],alpha)
    if retryIcon._fhkOuter ~= outer then retryIcon:ClearAllPoints(); retryIcon:SetPoint('TOP',root,'CENTER',0,-outer-6); retryIcon._fhkOuter = outer end
    retryIcon:SetShown(showCue and cue=='retry' or false)
    -- Melee ready lights only when melee is actionable, like the swing bar's
    -- MELEE READY (player screenshot: a violet ring at 20-25 yards).
    local meleeReach = not FHK.EllesmereMeleeActionable or FHK.EllesmereMeleeActionable(now)
    -- Like the bars: rings show while cooling; melee counts with auto attack on or a real swing.
    local shooting, swinging = true, true
    if FHK.EllesmereAttacksOn then shooting, swinging = FHK.EllesmereAttacksOn() end
    -- Each Auto Shot touches the shared melee clock for about 0.1 s (review S2): like the bars,
    -- the melee clock only counts with auto attack on or a real swing.
    busy.melee = busy.melee and (swinging or FHK.EllesmereRealMeleeSwing and FHK.EllesmereRealMeleeSwing(durations.melee)) and true or false
    for kind, cd in pairs(rings) do
        local wanted = combined or cfg.mode == 'separate' or cfg.mode == kind
        local ready = wanted and not busy[kind] and
            (kind == 'melee' and cfg.showMeleeReady and (busy.ranged or swinging) and meleeReach or
             kind == 'ranged' and cfg.showRangedReady and busy.melee)
        local start, duration = starts[kind], durations[kind]
        -- Melee cooling counts only with auto attack on (the bars' rule).
        local cooling = wanted and busy[kind] and (kind ~= 'melee' or meleeReach and (swinging or
            FHK.EllesmereRealMeleeSwing and FHK.EllesmereRealMeleeSwing(durations.melee)))
        local single = combined and cfg.combinedRings == 'one'
        local clock = kind
        if single then
            ready = false
            if kind == 'melee' then cooling = false
            elseif busy.ranged then cooling = true
            -- One ring on the melee clock wears the melee colour, with the melee gating (review S3).
            elseif busy.melee and meleeReach then cooling = true; clock = 'melee'; start, duration = starts.melee, durations.melee end
        end
        if cooling or ready then
            cd.fading=nil
            local twoRings = combined and not single or cfg.mode == 'separate'
            local size = (twoRings and kind == 'melee' and outer or radius) * 2
            cd:SetSize(size, size)
            local c = FHK.EllesmereSwingColors and FHK.EllesmereSwingColors[clock] or {1, 1, 1}
            if cfg.readinessColors then
                -- Melee-ready brown only when melee is an option (review S3: it showed at 20-35 yd).
                if single and busy.ranged and not busy.melee and cfg.showMeleeReady and meleeReach then c = brown
                else c = clock == 'melee' and ready and brown or clock == 'ranged' and green or c end
            end
            if kind=='ranged' and showCue then c=cue=='retry' and retryColour or
                (FHK.EllesmereSwingColors and FHK.EllesmereSwingColors.cast or {1,.435,.694}) end
            -- Dark mode: a black outline ring, with the state colour as a thin sweep on it.
            local dark = FHK.EllesmereDarkMode and FHK.EllesmereDarkMode()
            local path = 'Interface\\AddOns\\EllesmereUIQoL\\Media\\ring_' .. (dark and 'thin' or texture) .. '.tga'
            if dark then
                local track = 'Interface\\AddOns\\EllesmereUIQoL\\Media\\ring_heavy.tga'
                if cd.trackTexture ~= track then cd.track:SetTexture(track); cd.trackTexture = track end
                cd.track:SetSize(size, size); cd.track:SetVertexColor(0, 0, 0, .85 * alpha); cd.track:Show()
            else cd.track:Hide() end
            -- Resetting swipe textures continuously can interrupt client drawing.
            if cd.texture ~= path then cd:SetSwipeTexture(path); cd.ready:SetTexture(path); cd.texture = path end
            cd:SetSwipeColor(c[1], c[2], c[3], alpha)
            cd.ready:SetSize(size, size); cd.ready:SetVertexColor(c[1],c[2],c[3],alpha)
            cd.ready:SetShown(ready)
            if cooling and (cd.start ~= start or cd.duration ~= duration or not cd:IsShown() or not root:IsShown()) then
                cd.start, cd.duration = start, duration; cd:SetCooldown(start, duration)
            end
            cd:SetShown(cooling); shown = true
        elseif not busy.ranged and not busy.melee and root._fhkCursorCooling then
            -- Hold the terminal ring during the shared smooth fade-out.
            cd:Hide(); cd.ready:SetShown(cd.start~=nil or cd.fading==true)
            cd.fading=cd.ready:IsShown()
            if not cd.fading then cd.track:Hide() end
            cd.start,cd.duration=nil,nil
        else cd:Hide(); cd.ready:Hide(); cd.track:Hide(); cd.start,cd.duration,cd.fading=nil,nil,nil end
    end
    if shown then root._fhkCursorCooling=true end
    if FHK.FadeEllesmere then FHK.FadeEllesmere(root,shown)
    else root:SetShown(shown) end
    SyncSwingFollow(x,y)
end
local function Apply()
    local cfg, mouse = Settings(), EUI.Mouse
    if cfg.enabled and mouse and not subscribed then
        mouse.SubscribeTick('fhkSwingCursorState', .05, Refresh)
        subscribed = true
    elseif not cfg.enabled and mouse and subscribed then
        mouse.UnsubscribeTick('fhkSwingCursorState')
        subscribed = nil
    end
    if cfg.enabled and not mouse then
        if not driver:GetScript('OnUpdate') then
            fallbackElapsed=0
            driver:SetScript('OnUpdate',function(_,dt)
                fallbackElapsed=fallbackElapsed+dt
                if fallbackElapsed<.15 then return end
                fallbackElapsed=0;Apply()
            end)
        end
    else driver:SetScript('OnUpdate',nil) end
    Refresh()
end
FHK.ApplySwingCursor = Apply
local function InstallOptions()
    local reset = _G._EBS_ResetCursor
    if reset and reset ~= resetWrapper then
        resetWrapper = function(...)
            if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end; FHKEllesmereDB.swingCursor = nil
            Apply(); return reset(...)
        end
        _G._EBS_ResetCursor = resetWrapper
    end
    local original = _G._EBS_BuildCursorPage
    if not original or original == optionsWrapper then return end
    optionsWrapper = function(page, parent, offset)
        local height = original(page, parent, offset)
        local W, y, h = EUI.Widgets, -height
        local cfg = Settings()
        local function Refresh() if EUI.RefreshPage then EUI:RefreshPage() end end
        -- Every row stays on the page and greys out with its reason (review C9) rather than
        -- appearing and disappearing as the switches above it change.
        local off = function() return not cfg.enabled end
        local OFF = 'Enable Swing Timer'
        local function Needs(c, test, why)
            c.disabled = function() return off() or (test and test() or false) end
            c.disabledTooltip = function() return off() and OFF or why end
            return c
        end
        local function Add(left, right)
            local row, rowHeight = W:DualRow(parent, y, left, right); y = y - (rowHeight or 0)
            -- Ellesmere's row tools (swatches) on the native page, as on companion sections.
            if FHK.EllesmereRowExtras then
                pcall(FHK.EllesmereRowExtras, row, '_leftRegion', left); pcall(FHK.EllesmereRowExtras, row, '_rightRegion', right)
            end
        end
        local _
        _, h = W:SectionHeader(parent, 'SWING TIMER', y); y = y - h
        Add({type='toggle', text='Enable Swing Timer', tooltip='Swing rings around the cursor for Auto Shot and melee, next to the GCD ring.',
                getValue=function() return cfg.enabled end, setValue=function(v) cfg.enabled=v; Apply(); Refresh() end},
            Needs({type='dropdown', text='Mode', values={ranged='Auto Shot',melee='Melee',combined='Both - Combined',separate='Both - Separate'},
                tooltip='Which swing clocks get a ring. Combined shares one area; Separate always draws both rings.',
                order={'combined','melee','ranged','separate'}, getValue=function() return cfg.mode end,
                setValue=function(v) cfg.mode=v; Apply(); Refresh() end}))
        local pulsesOff = function() return FHKEllesmereDB.attackPulses == false end
        Add({type='toggle',text='Attack Pulses',tooltip='The auto attack squares by the range indicator. Shared with Auto Attack Indicators on the Resource Bars page.',
                getValue=function() return FHKEllesmereDB.attackPulses ~= false end,
                setValue=function(v) FHKEllesmereDB.attackPulses=v
                    if FHK.EllesmereIndicatorSettings then FHK.EllesmereIndicatorSettings('attacks').enabled=v;FHK.ApplyEllesmereIndicators() end
                    Refresh() end},
            {type='slider',text='Pulse Icon Size',min=16,max=48,step=1,tooltip='Size of the auto attack squares.',
                disabled=pulsesOff, disabledTooltip='Attack Pulses',
                getValue=function() local v=FHKEllesmereDB.attackCueSize; return PublicNumber(v) and v or 28 end,
                setValue=function(v) FHKEllesmereDB.attackCueSize=v; if FHK.ApplyAttackCueSize then FHK.ApplyAttackCueSize() end end})
        Add(Needs({type='toggle', text='Match GCD Appearance', getValue=function() return cfg.matchGCD end,
                tooltip='Use the GCD ring texture, scale and opacity. Swing Radius stays independent.',
                setValue=function(v) cfg.matchGCD=v; Apply(); Refresh() end}),
            Needs({type='toggle', text='Combat Only', tooltip='Shows the swing rings only while you are in combat.',
                getValue=function() return cfg.combatOnly end, setValue=function(v) cfg.combatOnly=v; Apply() end}))
        local swatch = FHK.EllesmereColorSwatch
        local readiness = Needs({type='toggle', text='Readiness Colors', getValue=function() return cfg.readinessColors end,
            tooltip='On: Auto Shot cools in the Shooting color and a ready melee ring shows in the Melee color. Off: each ring keeps its swing timer color. The swatches are the shared Hunter colors.',
            setValue=function(v) cfg.readinessColors=v; Apply() end})
        if type(swatch)=='function' then
            readiness.swatches={swatch('shoot','Shooting Color (shared)'),swatch('melee','Melee Color (shared)'),swatch('retry','Retry Color (shared)')}
        end
        Add(Needs({type='slider', text='Radius', min=12,max=100,step=1,getValue=function() return cfg.radius or 27 end,
                tooltip='Smallest swing ring radius. Swing rings sit just outside an attached GCD or cast ring; the melee ring sits just outside Auto Shot.',
                setValue=function(v) cfg.radius=v; Apply() end}), readiness)
        local noMelee = function() return cfg.mode == 'ranged' end
        local noRanged = function() return cfg.mode == 'melee' end
        Add(Needs({type='toggle',text='Show Melee Ready Ring',getValue=function() return cfg.showMeleeReady end,
                tooltip='Keeps a full melee circle visible when melee is ready and Auto Shot is still cooling.',
                setValue=function(v) cfg.showMeleeReady=v; Apply() end}, noMelee, 'This option needs a Mode with a melee ring'),
            Needs({type='toggle',text='Show Auto Shot Ready',getValue=function() return cfg.showRangedReady end,
                tooltip='Keeps a full Auto Shot circle visible when Auto Shot is ready and melee is still cooling.',
                setValue=function(v) cfg.showRangedReady=v; Apply() end}, noRanged, 'This option needs a Mode with an Auto Shot ring'))
        Add(Needs({type='toggle',text='Keep Clear of GCD',getValue=function() return cfg.avoidGCD ~= false end,
                tooltip='Keeps the swing rings just outside an attached GCD ring, whatever the Radius.',
                setValue=function(v) cfg.avoidGCD=v; Apply() end}),
            Needs({type='toggle',text='Restart Bow After Melee',getValue=function() if FHK.WeaveTiming then return FHK.WeaveTiming.RangedResetsOnMelee() end; return cfg.resetOnMelee ~= false end,
                tooltip='Restarts the bow cycle after a melee swing. Uses the ForeverHunterKeys timing setting when it is installed.',
                setValue=function(v) cfg.resetOnMelee=v
                    if FHK.WeaveTiming and SlashCmdList.FHKTIMING then SlashCmdList.FHKTIMING('rangedreset ' .. (v and 'on' or 'off')) end
                    Apply() end}))
        Add(Needs({type='toggle',text='Show Auto Shot Retry',getValue=function() return cfg.showRetry ~= false end,
                tooltip='Shows the short retry cycle and undo glyph when an active Auto Shot fails quietly.',
                setValue=function(v) cfg.showRetry=v; Apply() end}, noRanged, 'This option needs a Mode with an Auto Shot ring'),
            Needs({type='toggle',text='Keep Clear of Cast Ring',getValue=function() return cfg.avoidCast ~= false end,
                tooltip='Keeps the swing rings just outside an attached cast ring, accounting for both scales.',
                setValue=function(v) cfg.avoidCast=v; Apply() end}))
        Add(Needs({type='dropdown',text='Combined Layout',values={one='One Ring',two='Two Rings'},order={'one','two'},
                tooltip='Two Rings: Auto Shot inside, melee outside. One Ring: one sweep for whichever clock is running.',
                getValue=function() return cfg.combinedRings end,setValue=function(v) cfg.combinedRings=v; Apply() end},
                function() return cfg.mode ~= 'combined' end, 'This option requires Mode set to Both - Combined'),
            {type='label',text='Inner: Auto Shot; outer: melee'})
        local matched = function() return cfg.matchGCD end
        local MATCHED = 'This option follows the GCD ring while Match GCD Appearance is on'
        Add(Needs({type='dropdown', text='Ring Texture', values={thin='Thin',light='Light',normal='Normal',heavy='Heavy',thick='Thick'},
                tooltip='Thickness of the swing rings.',
                order={'thin','light','normal','heavy','thick'}, getValue=function() return cfg.ringTex end,
                setValue=function(v) cfg.ringTex=v; Apply() end}, matched, MATCHED),
            Needs({type='slider',text='Ring Opacity %',min=10,max=100,step=1,tooltip='Opacity of the swing rings.',
                getValue=function() return cfg.alpha end, setValue=function(v) cfg.alpha=v; Apply() end}, matched, MATCHED))
        if FHK.EllesmereSectionReset then
            Add(FHK.EllesmereSectionReset('Swing Timer', function()
                    FHKEllesmereDB.swingCursor = nil
                    local fresh = Settings()
                    for k in pairs(cfg) do cfg[k] = nil end
                    for k, v in pairs(fresh) do cfg[k] = v end
                    FHKEllesmereDB.swingCursor = cfg
                    Apply()
                end, 'Restores the swing ring settings to their defaults (off). Attack Pulses and the shared colors keep theirs.'),
                {type='label',text='Ellesmere\'s cursor Reset also clears these'})
        end
        return math.abs(y)
    end
    _G._EBS_BuildCursorPage = optionsWrapper
end

-- Attached casting follows the shared mouse sample, independently of the reticle.
local castFollow,castListener
local castHooks={}
local function CastFollowActive()
    local p=_G._ECL_AceDB and _G._ECL_AceDB.profile
    local c=p and p.castCircle
    return castFollow and c and c.enabled and c.attached~=false and not EUI._unlockActive and
        castFollow.frame:IsShown() and castFollow.ring:IsShown()
end
local function StopCastFollow()
    if castFollow and castFollow.subscribed then
        EUI.Mouse.UnsubscribeFrame('fhkCastCursorFollow')
        castFollow.subscribed=false
    end
end
local function CastPosition(x,y)
    if not CastFollowActive() then StopCastFollow();return end
    local looking=IsMouselooking and IsMouselooking()
    -- A ring that starts during mouselook still takes the frozen point once (review S4).
    if not castFollow.dirty and not (issecretvalue and issecretvalue(looking)) and looking==true then return end
    local scale=UIParent:GetEffectiveScale()
    if not PublicNumber(x) or not PublicNumber(y) or not PublicNumber(scale) or scale<=0 then return end
    x,y=math.floor(x/scale+.5),math.floor(y/scale+.5)
    local s=castFollow
    if s.x==x and s.y==y and not s.dirty then return end
    s.x,s.y,s.dirty=x,y,false
    s.writing=true
    s.frame:ClearAllPoints();s.frame:SetPoint('CENTER',UIParent,'BOTTOMLEFT',x,y)
    s.writing=false
end
function FHK.SyncEllesmereCastCursor()
    local mouse=EUI.Mouse
    if not mouse or not mouse.SubscribeFrame or not mouse.UnsubscribeFrame or not mouse.Get then return end
    local frame=_G.ECL_CastRoot
    if frame and (not castFollow or castFollow.frame~=frame) then
        StopCastFollow()
        local ring
        for _,child in ipairs({frame:GetChildren()}) do
            if child.StartRing and child.StopRing then ring=child;break end
        end
        if not ring then return end
        castFollow={frame=frame,ring=ring,dirty=true}
        for _,method in ipairs({'StartRing','StartRingFromDuration','StopRing'}) do
            if ring[method] then hooksecurefunc(ring,method,function() FHK.SyncEllesmereCastCursor() end) end
        end
        frame:HookScript('OnShow',function() FHK.SyncEllesmereCastCursor() end)
        frame:HookScript('OnHide',function()
            if castFollow and castFollow.frame==frame then StopCastFollow() end
        end)
        hooksecurefunc(frame,'SetPoint',function()
            if castFollow.frame~=frame or castFollow.writing or not CastFollowActive() then return end
            castFollow.dirty=true;CastPosition(mouse.Get())
        end)
    end
    if CastFollowActive() then
        castFollow.dirty=true
        CastPosition(mouse.Get())
        if not castFollow.subscribed then
            mouse.SubscribeFrame('fhkCastCursorFollow',CastPosition,true)
            castFollow.subscribed=true
        end
    else StopCastFollow() end
end
local function InstallCastFollow()
    for _,name in ipairs({'_ECL_ApplyCastCircle','_ECL_UpdateVisibility','_ECL_Apply'}) do
        if type(_G[name])=='function' and not castHooks[name] then
            castHooks[name]=true
            hooksecurefunc(_G,name,function() FHK.SyncEllesmereCastCursor() end)
        end
    end
    if not castListener and EUI.RegisterUnlockModeListener then
        EUI:RegisterUnlockModeListener('FHKEllesmereCastCursor',function(active)
            if active then StopCastFollow() else FHK.SyncEllesmereCastCursor() end
        end)
        castListener=true
    end
    FHK.SyncEllesmereCastCursor()
end
driver:RegisterEvent('PLAYER_LOGIN'); driver:RegisterEvent('PLAYER_ENTERING_WORLD')
driver:RegisterEvent('ADDON_LOADED'); driver:RegisterEvent('PLAYER_SWING')
driver:RegisterEvent('PLAYER_REGEN_ENABLED'); driver:RegisterEvent('PLAYER_REGEN_DISABLED')
driver:SetScript('OnEvent', function(_,event)
    InstallOptions(); Apply();InstallCastFollow()
    if event=='PLAYER_LOGIN' then C_Timer.After(1,InstallCastFollow) end
end)
