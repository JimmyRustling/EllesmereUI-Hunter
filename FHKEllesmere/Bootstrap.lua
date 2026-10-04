-- Public module bridge: FHK is optional. These files can be included by EUI.
local addon, namespace = ...
_G.FHKEllesmereNS = _G.ForeverHunterKeysNS or namespace
if EUI_CLIENT_BLOCKED then return end
_G.FHKEllesmereNS.RefinementsVersion = '1.9.3'
_G.FHKEllesmereNS.RefinementsMediaRoot = _G.FHKEllesmereNS.RefinementsMediaRoot or
    ('Interface\\AddOns\\' .. addon .. '\\media\\')
-- Semantic gameplay colours (audit F19). One meaning per token; modules read
-- these instead of their own literals. Precedence: ELLESMERE_STYLE_GUIDE.md.
_G.FHKEllesmereNS.Colours = _G.FHKEllesmereNS.Colours or {
    text = {.96, .945, .925},        -- calm health/value text
    resourceText = {.87, .91, .96},  -- calm resource text
    -- Warning family taken from WoW itself (QuestDifficultyColors, NORMAL_FONT_COLOR),
    -- so it reads like the game's own yellow/orange/red. Text and lines use these
    -- bright values; bar fills use the deeper health* values below.
    caution = {1, .82, 0},           -- WoW gold: health 40 %, approaching the deadzone, low ammo
    worry = {1, .5, .25},            -- WoW orange: health 25 %
    danger = {1, .3, .25},           -- WoW red, lifted for dark backgrounds: critical health, deadzone
    -- Fills: the same three as saturated icon-art tones, deep enough for white
    -- text (3.1, 4.3 and 6.0 : 1). Lightness also steps down (L* 57, 48, 39), so
    -- the ramp still reads for red-green colour blindness. The gold is Forever's bronze.
    healthMid = {.772, .632, 0},     -- WoW gold #C5A100 at 50 % (one gold: also neutral and retry)
    healthLow = {.717, .338, .086},  -- burnt orange #B75616 at 25 %
    healthCritical = {.695, .137, .097}, -- crimson #B12319 at 0 %
    alert = {1, .27, .27},           -- urgent warnings (critical ammo, combat aspects)
    damage = {.86, .18, .16},        -- health just lost (damage flash)
    -- Attack identities. Bright values for icons, rings and lines over the world;
    -- *Fill values for bars that carry outlined white labels (3 : 1, L* 58).
    -- Ranged jade and melee violet stay distinct from health and warning hues.
    shoot = {.25, .84, .66},         -- in ranged range, Auto Shot (bright jade #40D6A8)
    shootFill = {.183, .615, .483},  -- Auto Shot bar fill #2F9D7B
    -- Bright state set shares one perceived lightness (OKLCH L ~0.74-0.88) so no
    -- state reads heavier than another; violet lifted from #C45CFF (L 0.67) to
    -- match jade and stay clear on dark forest ground (7.6 : 1 on the track).
    melee = {199/255, 135/255, 1},   -- violet #C787FF: melee range, swing and ready
    meleeFill = {.762, .358, .991},   -- violet fill #C25BFD under outlined labels
    -- Your casts are rose (player: "we can change the colour of the cast bar"):
    -- the blue matched mana 8 units away. Measured: at least 13.8 dE OKLab from
    -- every neighbour, and still distinct for protan/deutan vision.
    cast = {1, .435, .694},          -- rose #FF6FB1: cast ring, world cues (7.4 : 1 on the track)
    castFill = {254/255, 81/255, 164/255}, -- rose fill #FE51A4 at the 3 : 1 white-label cap
    -- Retry has its own colour (player, 2026-10-03): acid lime. Measured at least
    -- 14 dE OKLab from every token (20 from jade beside it), also for protan and
    -- deutan vision. Its bar keeps white outlined labels (player: dark text read badly).
    retry = {198/255, 1, 61/255},      -- acid lime #C6FF3D: ring, icon, cue text
    retryFill = {184/255, 235/255, 46/255}, -- lime fill #B8EB2E under white outlined labels
    -- Coloured preset reaction fills: deep WoW red / gold / green for white text.
    reactionHostile = {.784, .188, .165}, -- #C8302A, lifted to sit with the 3 : 1 fills
    reactionNeutral = {.772, .632, 0},  -- WoW gold #C5A100 (FFD100 deepened), same as the 50 % stop and retry
    reactionFriendly = {.20, .55, .22},  -- #338C38
    reactionTapped = {.42, .42, .42},
    neutral = {.62, .66, .70},       -- no action available: out of range (35+), unknown range
    quiet = {.25, .26, .29},         -- present but not actionable now (melee ready while shooting)
    questXP = {1, .82, 0},           -- pending quest XP
    xpFill = {118/255,45/255,178/255}, -- earned XP: deep electric violet
    xpAccent = {196/255,92/255,1},
    xpRestedFill = {20/255,110/255,134/255}, -- rested bonus: deep Mage cyan-blue
    xpRestedAccent = {63/255,199/255,235/255},
    quest = {1, .82, 0},             -- quest objective count on nameplates
    happy = {.30, .85, .30}, content = {1, .82, 0}, unhappy = {1, .3, .25}, -- pet mood, WoW green/gold/red
}
-- Dark mode follows Ellesmere's own unit-frame switch (the Dark preset turns it on).
-- In it, companion bars and rings go black and colour appears only as a thin
-- state accent: colour has to mean something there (player principle).
_G.FHKEllesmereNS.darkFill = {0x1C/255, 0x1D/255, 0x21/255} -- a dark shade of black
function _G.FHKEllesmereNS.EllesmereDarkMode()
    local uf = _G.EllesmereUI and _G.EllesmereUI._ModuleNS and _G.EllesmereUI._ModuleNS.EllesmereUIUnitFrames
    local p = uf and uf.db and uf.db.profile
    return type(p) == 'table' and p.darkTheme == true
end
-- Earlier vivid class colours. Classes now use WoW's own class colours; this
-- table only lets the Coloured preset recognise and remove its earlier writes.
local NS=_G.FHKEllesmereNS
NS.EllesmereVividClassPalette={
    WARRIOR={accent='FF5A68',fill='F15562'}, PALADIN={accent='FF70B7',fill='DC619E'},
    HUNTER={accent='A7F05A',fill='71970F',oldFill='6A9939'}, ROGUE={accent='FEF367',fill='AFA847'},
    PRIEST={accent='FFC04D',fill='CF9C3F'}, SHAMAN={accent='3FA7FF',fill='3791DD'},
    MAGE={accent='3FC7EB',fill='3097B3'}, WARLOCK={accent='C45CFF',fill='C25BFD'},
    DRUID={accent='FE7B0D',fill='DE6B0B'},
}
NS.EllesmereVividPowerPalette={
    MANA={accent='3FA7FF',fill='3791DD'}, RAGE={accent='FF5A68',fill='F15562'},
    ENERGY={accent='FEF367',fill='AFA847'}, FOCUS={accent='FE7B0D',fill='DE6B0B'},
}
local cueFonts=setmetatable({},{__mode='k'})
local iconEdges=setmetatable({},{__mode='k'})
local function Public(v) return not (issecretvalue and issecretvalue(v)) end
function NS.EllesmereVividThemeEnabled()
    return NS.GetEllesmereThemePreset and NS.GetEllesmereThemePreset()~='current'
end
function NS.EllesmereVividTextEnabled()
    return not (FHKEllesmereDB and FHKEllesmereDB.vividCueText==false) and NS.EllesmereVividThemeEnabled()
end
-- Preserve native font paths/sizes; only the outline and black shadow change.
function NS.ApplyEllesmereCueText(fs,role,native)
    if not fs or not fs.GetFont or not fs.SetFont then return end
    local path,size,flags=fs:GetFont()
    if not Public(path) or not Public(size) or not Public(flags) or
        type(path)~='string' or type(size)~='number' then return end
    flags=flags or ''
    local state=cueFonts[fs]
    if state and state.painting then return end
    local on=NS.EllesmereVividTextEnabled()
    if not state and not on then return end
    if not state then state={};cueFonts[fs]=state end
    if native or state.applied==nil or flags~=state.applied then
        state.flags=flags
        if fs.GetShadowColor then
            local r,g,b,a=fs:GetShadowColor()
            if Public(r) and Public(g) and Public(b) and Public(a) and
                (native=='module' or state.applied==nil or r~=0 or g~=0 or b~=0 or a~=1) then state.shadow={r,g,b,a} end
        end
        if fs.GetShadowOffset then
            local x,y=fs:GetShadowOffset()
            if Public(x) and Public(y) and (native=='module' or state.applied==nil or x~=1 or y~=-1) then state.offset={x,y} end
        end
    end
    state.role=role or state.role or 'bar'
    local wanted=state.flags
    -- Text on a filled bar keeps the native font flags (the player's Ellesmere
    -- setting is shadow): a solid fill at 3 : 1 needs only the soft black shadow,
    -- the modern treatment. Outlines stay for text over the 3D world.
    if on and state.role~='bar' then
        local mono=flags:find('MONOCHROME',1,true) and ',MONOCHROME' or ''
        local slug=flags:find('SLUG',1,true) and ',SLUG' or ''
        -- Stroke weight follows type size (player review, "modern"): the heavy
        -- outline is about 2 px, which clogs letters and eats the colour of red or
        -- jade text below 16 px. Large warnings keep it; names and numbers go thin.
        local thick=(state.role=='world' or state.role=='cue') and size>=16
        wanted=(thick and 'THICKOUTLINE' or 'OUTLINE')..mono..slug
    end
    state.painting=true
    if flags~=wanted then fs:SetFont(path,size,wanted) end
    if fs.SetShadowColor and (native or state.on~=on) then
        if on then fs:SetShadowColor(0,0,0,1)
        elseif state.shadow then fs:SetShadowColor(unpack(state.shadow)) end
    end
    if fs.SetShadowOffset and (native or state.on~=on) then
        if on then fs:SetShadowOffset(1,-1)
        elseif state.offset then fs:SetShadowOffset(unpack(state.offset)) end
    end
    state.applied=on and wanted or nil
    state.on=on;state.painting=nil
end
function NS.SyncEllesmereCueText()
    if NS.SyncEllesmereNativeWarningOutline then NS.SyncEllesmereNativeWarningOutline() end
    if NS.SyncEllesmereRangeOutline then NS.SyncEllesmereRangeOutline() end
    if NS.SyncEllesmereXPBarEdges then NS.SyncEllesmereXPBarEdges() end
    for fs,state in pairs(cueFonts) do NS.ApplyEllesmereCueText(fs,state.role) end
    for icon,state in pairs(iconEdges) do NS.ApplyEllesmereIconEdge(icon,state.solid) end
end
-- Indicator framing (player: the range block, combat and happiness squares and
-- attack squares all use the racial icons' framing). Ellesmere's Cooldown
-- Manager frames its icons with PP.CreateBorder: a one-pixel black border drawn
-- inside the frame. Every indicator gets that same border from here.
function NS.AddEllesmereFrameBorder(frame)
    if not frame or not frame.CreateTexture then return end
    if frame._fhkFrameBorder then return frame._fhkFrameBorder end
    local pp=_G.EllesmereUI and _G.EllesmereUI.PP
    local border=pp and pp.CreateBorder and pp.CreateBorder(frame,0,0,0,1,1,'OVERLAY',7)
    if not border then
        border=CreateFrame('Frame',nil,frame);border:SetAllPoints(frame);border:EnableMouse(false)
        border:SetFrameLevel(frame:GetFrameLevel()+1)
        local px=1/(frame.GetEffectiveScale and frame:GetEffectiveScale() or 1)
        for i,side in ipairs({'TOP','BOTTOM','LEFT','RIGHT'}) do
            local t=border:CreateTexture(nil,'OVERLAY',nil,7);t:SetColorTexture(0,0,0,1)
            if i<=2 then t:SetPoint(side..'LEFT',border,side..'LEFT',0,0);t:SetPoint(side..'RIGHT',border,side..'RIGHT',0,0);t:SetHeight(px)
            else t:SetPoint('TOP'..side,border,'TOP'..side,0,0);t:SetPoint('BOTTOM'..side,border,'BOTTOM'..side,0,0);t:SetWidth(px) end
        end
    end
    frame._fhkFrameBorder=border
    return border
end
-- A framed block: a flat fill inside that border (range block grammar).
function NS.CreateEllesmereFramedBlock(parent)
    local f=CreateFrame('Frame',nil,parent);f:EnableMouse(false)
    f.fill=f:CreateTexture(nil,'ARTWORK');f.fill:SetAllPoints(f);f.fill:SetTexture('Interface\\Buttons\\WHITE8X8')
    NS.AddEllesmereFrameBorder(f)
    return f
end
-- Solid icon artwork gets a square pixel border. Transparent glyphs get a
-- black one-pixel silhouette, so swords/paws/bags stay recognisable shapes.
function NS.ApplyEllesmereIconEdge(icon,solid)
    if not icon or not icon.GetParent or not icon.GetTexture then return end
    local owner=icon:GetParent()
    if not owner or not owner.CreateTexture then return end
    local on=NS.EllesmereVividThemeEnabled() and not (FHKEllesmereDB and FHKEllesmereDB.pixelIconEdges==false)
    local state=iconEdges[icon]
    if not state and not on then return end
    local source=icon:GetTexture()
    local atlas=icon.GetAtlas and icon:GetAtlas()
    if not Public(source) or not Public(atlas) then return end
    if not state then
        if InCombatLockdown and InCombatLockdown() then return end
        local layer,level='ARTWORK',0
        if icon.GetDrawLayer then layer,level=icon:GetDrawLayer() end
        if not Public(layer) or not Public(level) then return end
        state={solid=solid};iconEdges[icon]=state
        layer=type(layer)=='string' and layer or 'ARTWORK'
        level=type(level)=='number' and math.max(-8,level-1) or -1
        if solid then
            state.holder=CreateFrame('Frame',nil,owner);state.holder:EnableMouse(false)
            state.holder:SetFrameLevel(owner:GetFrameLevel()+1)
            local pp=_G.EllesmereUI and _G.EllesmereUI.PP
            if pp and pp.CreateBorder then state.border=pp.CreateBorder(state.holder,0,0,0,1,1,'OVERLAY',0) end
            if not state.border then
                state.strips={}
                for i=1,4 do
                    local t=state.holder:CreateTexture(nil,'OVERLAY');t:SetColorTexture(0,0,0,1);state.strips[i]=t
                end
            end
        else
            state.copies={}
            for i=1,8 do state.copies[i]=owner:CreateTexture(nil,layer,nil,level) end
        end
        local function Update() NS.ApplyEllesmereIconEdge(icon,state.solid) end
        for _,method in ipairs({'SetTexture','SetAtlas','SetTexCoord','SetAlpha','SetVertexColor','Show','Hide','SetShown'}) do
            if type(icon[method])=='function' and hooksecurefunc then hooksecurefunc(icon,method,Update) end
        end
    end
    local shown=not icon.IsShown or icon:IsShown()
    if not Public(shown) then return end
    local alpha=icon.GetAlpha and icon:GetAlpha() or 1
    local tint=icon.GetVertexColor and select(4,icon:GetVertexColor()) or 1
    if not Public(alpha) or not Public(tint) then return end
    alpha=alpha*(type(tint)=='number' and tint or 1)
    local visible=on and shown and (source~=nil or atlas~=nil)
    if state.holder then state.holder:SetShown(visible);state.holder:SetAlpha(alpha) end
    if not visible then
        for _,t in ipairs(state.copies or {}) do t:Hide() end
        state.visible=false
        return
    end
    local scale=owner.GetEffectiveScale and owner:GetEffectiveScale() or 1
    if not Public(scale) or type(scale)~='number' or scale<=0 then return end
    local pp=_G.EllesmereUI and _G.EllesmereUI.PP
    local px=(pp and pp.perfect or 1)/scale
    if state.solid then
        if state.px~=px then
            local h=state.holder
            h:ClearAllPoints();h:SetPoint('TOPLEFT',icon,'TOPLEFT',-px,px);h:SetPoint('BOTTOMRIGHT',icon,'BOTTOMRIGHT',px,-px)
            if state.strips then
                for i,t in ipairs(state.strips) do
                    local side=({'TOP','BOTTOM','LEFT','RIGHT'})[i]
                    if i<=2 then
                        t:SetPoint(side..'LEFT',h,side..'LEFT',0,0)
                        t:SetPoint(side..'RIGHT',h,side..'RIGHT',0,0);t:SetHeight(px)
                    else
                        t:ClearAllPoints();t:SetPoint('TOP'..side,h,'TOP'..side,0,0)
                        t:SetPoint('BOTTOM'..side,h,'BOTTOM'..side,0,0);t:SetWidth(px)
                    end
                end
            end
            state.px=px
        end
        return
    end
    local coords=icon.GetTexCoord and {icon:GetTexCoord()} or {0,1,0,1}
    for _,v in ipairs(coords) do if not Public(v) then return end end
    local changed=state.px~=px or state.source~=source or state.atlas~=atlas or state.alpha~=alpha or not state.visible
    for i,v in ipairs(coords) do if not state.coords or state.coords[i]~=v then changed=true end end
    if not changed then return end
    local offsets={{-1,-1},{0,-1},{1,-1},{-1,0},{1,0},{-1,1},{0,1},{1,1}}
    for i,t in ipairs(state.copies) do
        if state.source~=source or state.atlas~=atlas then
            if atlas then t:SetAtlas(atlas) else t:SetTexture(source) end
        end
        t:SetTexCoord(unpack(coords))
        if state.px~=px then
            local x,y=offsets[i][1]*px,offsets[i][2]*px
            t:SetPoint('TOPLEFT',icon,'TOPLEFT',x,y);t:SetPoint('BOTTOMRIGHT',icon,'BOTTOMRIGHT',x,y)
        end
        t:SetVertexColor(0,0,0,alpha);t:Show()
    end
    state.source,state.atlas,state.px=source,atlas,px
    state.coords,state.alpha,state.visible=coords,alpha,true
end
local fontHooked
function NS.InstallEllesmereCueFontHook()
    local eui=_G.EllesmereUI
    if fontHooked or not eui or type(eui.ApplyModuleFont)~='function' or not hooksecurefunc then return end
    fontHooked=true
    local modules={nameplates=true,unitFrames=true,resourceBars=true,raidFrames=true,
        actionBars=true,cooldownManager=true,extras=true}
    hooksecurefunc(eui,'ApplyModuleFont',function(fs,_,_,module)
        if modules[module] or cueFonts[fs] then
            NS.ApplyEllesmereCueText(fs,cueFonts[fs] and cueFonts[fs].role or (module=='nameplates' and 'cue' or 'bar'),'module')
        end
    end)
end
-- All calculations below use public palette channels, never unit values.
-- Labelled fills stop at 3 : 1 against the white values (player review): every
-- bar label carries a black outline, which does the separating, as on WoW's
-- own bright bars. The earlier 4.75 : 1 pressed yellows and greens to olive
-- while red and blue stayed vivid, so the frames read as two palettes.
NS.ReadableFillContrast=3
-- Golds and yellows (hue 35-65) stop at 2.2 : 1 instead (player: "the gold we use
-- for neutrals seems out of place"). Below about L* 65 every yellow turns olive or
-- mustard, whatever its hue, while red, blue and jade stay vivid at L* 58. The
-- black shadow or outline on every label carries the edge contrast, as on WoW's
-- own bright yellow bars.
-- Amber read as orange (player), so the gold is WoW's own hue, fully saturated:
-- muted yellow is what turns olive.
NS.ReadableGoldContrast=2.2
local function GoldHue(r,g,b)
    local mx,mn=math.max(r,g,b),math.min(r,g,b)
    if mx<=0 or mx==mn or mx~=r and mx~=g then return false end
    local h=mx==r and ((g-b)/(mx-mn))%6 or (b-r)/(mx-mn)+2
    h=h*60
    return h>=35 and h<=65
end
local fillCache={}
function NS.EllesmereReadableBarFill(r,g,b)
    if not Public(r) or not Public(g) or not Public(b) or type(r)~='number' or
        type(g)~='number' or type(b)~='number' or r~=r or g~=g or b~=b or
        r<0 or g<0 or b<0 or r>1 or g>1 or b>1 then return end
    local id=string.format('%.6f/%.6f/%.6f',r,g,b)
    local hit=fillCache[id];if hit then return unpack(hit) end
    local function L(v) return v<=.04045 and v/12.92 or ((v+.055)/1.055)^2.4 end
    local function Light(k) return .2126*L(r*k)+.7152*L(g*k)+.0722*L(b*k) end
    local text=NS.Colours.text
    local ratio=GoldHue(r,g,b) and NS.ReadableGoldContrast or NS.ReadableFillContrast
    local maxLum=(.2126*L(text[1])+.7152*L(text[2])+.0722*L(text[3])+.05)/ratio-.05
    local k=1
    if Light(k)>maxLum then
        local lo,hi=0,1
        for _=1,16 do local mid=(lo+hi)/2;if Light(mid)>maxLum then hi=mid else lo=mid end end
        k=lo
    end
    hit={r*k,g*k,b*k};fillCache[id]=hit;return unpack(hit)
end
if addon=='EllesmereUIForeverRefinements' then
    -- The upstream child replaces the companion and shares its public bridge.
    _G.FHKEllesmereNS.EllesmereHUDActive=function() return not EUI_CLIENT_BLOCKED and _G.EllesmereUI~=nil end
end
