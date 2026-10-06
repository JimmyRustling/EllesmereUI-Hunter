-- Native range / attack controls and movers. Rendering stays in Companion.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end
local DASH = '\226\128\147' -- en dash: range text format shared with FHK
local ranges,attacks,rangeHome,attackHome
local revision=0
local defaults={range={enabled=true,orientation='horizontal',length=260,thickness=3,iconSize=30,blockWidth=48,blockHeight=14,style='textured',
    opacity=.95,text=true,fontSize=11,colourMode='range',colour={r=.25,g=.84,b=.66},facingWarning=true,castFailureWarning=false},
    plate={mode='glow',glowOpacity=.45,side='right',thickness=6,gap=0,opacity=.7,style='flat',colourMode='range',
        colour={r=.25,g=.84,b=.66},textColourMode='range',textColour={r=.94,g=.95,b=.97},
        textSize=10,textX=0,textY=-5},
    frame={enabled=true,side='right',placement='outside',thickness=5,borderSize=2,gap=0,opacity=.9,style='flat',colourMode='range',
        colour={r=.25,g=.84,b=.66},target=true,focus=true,targettarget=false},
    attacks={enabled=true,melee=true,ranged=true,labels=true,orientation='horizontal',gap=20,opacity=1,style='class'}}
local function Copy(t)
    local c={};for k,v in pairs(t) do c[k]=type(v)=='table' and Copy(v) or v end;return c
end
function NS.EllesmereIndicatorSettings(kind)
    if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end
    local db=FHKEllesmereDB
    db.indicators=db.indicators or {}
    local s=db.indicators[kind]
    if not s then s=Copy(defaults[kind]);db.indicators[kind]=s end
    -- Unit-frame bar saved before it could extend the frame: the old default
    -- (a 3 px stripe inside the left edge) becomes the outer-right tab.
    if kind=='frame' and s.placement==nil then
        if (s.side==nil or s.side=='left') and (s.thickness==nil or s.thickness==3) then s.side,s.thickness='right',5 end
        s.placement='outside'
    end
    -- Settings added after a profile was saved pick up their defaults.
    for k,v in pairs(defaults[kind]) do if s[k]==nil then s[k]=type(v)=='table' and Copy(v) or v end end
    return s
end
local function Pixel(v) return EUI.PP and EUI.PP.FromPixels and EUI.PP.FromPixels(v) or v end
local function Read(fn,...)
    if type(fn)~='function' then return end
    local ok,v=pcall(fn,...)
    if ok and not (issecretvalue and issecretvalue(v)) then return v end
end
-- Range brackets (player, 2026-10-06: "customisability in what is shown in each bracket"):
-- per bracket, whether the centre indicator shows, what its text says, a custom label, and
-- an optional pulse and sound when the target enters that bracket.
local BRACKETS={{'melee','Melee'},{'deadzone','Dead Zone'},{'shoot','Shooting'},{'far','Too Far'},{'out','Out Of Range'},{'unknown','Unknown'}}
NS.EllesmereRangeBrackets=BRACKETS
local BRACKET_DEFAULT={show=true,content='both',label='',pulse=false,sound='none'}
function NS.EllesmereRangeBracket(key)
    local s=NS.EllesmereIndicatorSettings('range')
    if type(s.brackets)~='table' then s.brackets={} end
    local b=s.brackets[key]
    if type(b)~='table' then b={};s.brackets[key]=b end
    for k,v in pairs(BRACKET_DEFAULT) do if b[k]==nil or type(b[k])~=type(v) then b[k]=v end end
    return b
end
-- Bracket presets: Always Show; Hide While Shooting (the indicator only speaks when you are not
-- shooting); Problems Only (dead zone, too far and out of range, with a pulse on entering).
local BRACKET_PRESETS={
    all={melee={show=true,pulse=false},deadzone={show=true,pulse=false},shoot={show=true,pulse=false},far={show=true,pulse=false},out={show=true,pulse=false},unknown={show=true,pulse=false}},
    quiet={melee={show=true,pulse=false},deadzone={show=true,pulse=false},shoot={show=false,pulse=false},far={show=true,pulse=false},out={show=true,pulse=false},unknown={show=true,pulse=false}},
    problems={melee={show=false,pulse=false},deadzone={show=true,pulse=true},shoot={show=false,pulse=false},far={show=true,pulse=true},out={show=true,pulse=true},unknown={show=false,pulse=false}},
}
function NS.GetEllesmereRangeBracketPreset()
    for name,preset in pairs(BRACKET_PRESETS) do
        local match=true
        for key,fields in pairs(preset) do
            local b=NS.EllesmereRangeBracket(key)
            for k,v in pairs(fields) do if b[k]~=v then match=false end end
        end
        if match then return name end
    end
    return 'custom'
end
function NS.ApplyEllesmereRangeBracketPreset(name)
    local preset=BRACKET_PRESETS[name]
    if not preset then return false end
    for key,fields in pairs(preset) do
        local b=NS.EllesmereRangeBracket(key)
        for k,v in pairs(fields) do b[k]=v end
    end
    NS.ApplyEllesmereIndicators()
    return true
end
function NS.GetEllesmereRange(unit)
    if select(2,UnitClass('player'))=='HUNTER' then return NS.GetUnitRange(unit) end
    local sample={state='unknown',title='Range unavailable',bracket='',minimum=0,maximum=Read(EUI.Range_GetAttackCutoff) or 40}
    if Read(UnitExists,unit)~=true or Read(UnitCanAttack,'player',unit)~=true or Read(UnitIsDead,unit)==true then return sample end
    local api=NS.RangeLogic
    local exact=api and api.ReadDistance and api.ReadDistance(unit)
    local bracket=api and api.ReadLibraryBracket and api.ReadLibraryBracket(unit)
    local low,high=bracket and bracket.low,bracket and bracket.high
    if type(exact)=='number' then
        sample.exact=string.format('%.1f yd',exact)
        low=math.floor(exact/5)*5;high=low+5
        if exact<=5 then low,high=0,5 end
    end
    -- Ellesmere's single-unit helpers keep one-slot caches (review R6): the target only;
    -- other plates use the sweep API.
    local single=unit=='target'
    if type(low)~='number' and single then low=Read(EUI.Range_LowerBound,unit) end
    if type(low)=='number' then
        sample.bracket=type(high)=='number' and string.format('%g' .. DASH .. '%g yd',low,high) or string.format('%g+ yd',low)
        sample.distance=exact or low;sample.state,sample.title='distance','Distance'
    end
    local beyond
    if single then beyond=Read(EUI.Range_IsBeyondAttackRange,unit,sample.maximum)
    else beyond=Read(EUI.Range_SweepBeyond,unit,sample.maximum) end
    if type(exact)=='number' and exact>sample.maximum or beyond==true then sample.state,sample.title='out','Out of range'
    elseif type(high)=='number' and high<=5 then sample.state,sample.title='melee','Melee'
    elseif beyond==false then sample.title='In range' end
    return sample
end
-- Text follows the font of the module that owns it (audit F18): plate text uses
-- Nameplates; the centre range indicator sits with Resource Bars.
local function Font(fs,size,module)
    module=module or 'nameplates'
    if EUI.ApplyModuleFont then EUI.ApplyModuleFont(fs,nil,size,module)
    else fs:SetFont((EUI.GetFontPath and EUI.GetFontPath(module)) or 'Fonts\\FRIZQT__.TTF',size,'OUTLINE') end
    if NS.ApplyEllesmereCueText then NS.ApplyEllesmereCueText(fs,'world') end
end
local function Texture(style)
    return style=='textured' and 'Interface\\AddOns\\EllesmereUI\\media\\textures\\atrocity.tga' or 'Interface\\Buttons\\WHITE8X8'
end
local function Position(frame,settings,home,point)
    frame:ClearAllPoints()
    local pos=settings.position
    if pos then frame:SetPoint(pos.point or 'CENTER',UIParent,pos.relPoint or 'CENTER',pos.x or 0,pos.y or 0)
    else frame:SetPoint(point,home,point,0,point=='TOP' and 0 or -3) end
end
-- A black backdrop extends one physical pixel around the coloured rail only.
-- Anchoring to its texture keeps both orientations and label layout intact.
function NS.PaintEllesmereRangeOutline(frame)
    if not frame or not frame.fill then return end
    local edge=frame._fhkRangeOutline
    local on=NS.EllesmereVividThemeEnabled and NS.EllesmereVividThemeEnabled() and
        not (FHKEllesmereDB and FHKEllesmereDB.pixelIconEdges==false)
    if not on then if edge then edge:Hide() end return end
    if not edge then
        edge=frame:CreateTexture(nil,'BACKGROUND',nil,-1)
        frame._fhkRangeOutline=edge
    end
    local scale=frame:GetEffectiveScale()
    local px=(EUI.PP and EUI.PP.perfect or 1)/scale
    if edge._pixel~=px then
        edge:ClearAllPoints()
        edge:SetPoint('TOPLEFT',frame.fill,'TOPLEFT',-px,px)
        edge:SetPoint('BOTTOMRIGHT',frame.fill,'BOTTOMRIGHT',px,-px)
        edge._pixel=px
    end
    local opacity=NS.EllesmereIndicatorSettings('range').opacity
    if edge._opacity~=opacity then edge:SetColorTexture(0,0,0,opacity);edge._opacity=opacity end
    edge:Show()
    return edge
end
function NS.SyncEllesmereRangeOutline() NS.PaintEllesmereRangeOutline(ranges) end
local function ApplyRange()
    if not ranges then return end
    local s=NS.EllesmereIndicatorSettings('range')
    Position(ranges,s,rangeHome,'TOP')
    ranges.rail:ClearAllPoints();ranges.fill:ClearAllPoints()
    ranges.left:ClearAllPoints();ranges.right:ClearAllPoints()
    local thickness=Pixel(s.thickness)
    -- Icon style (player: "an action bar icon that changes colour rather than the
    -- bar"): the equipped ranged weapon inside a border in the range colour, the
    -- yardage beneath. The fill paints the border, so every state colour,
    -- including facing warnings, reaches it unchanged.
    -- Block style (player: "just a coloured block with a black outline that changes
    -- colour based on the range"): the fill alone, in the range colour, with a
    -- black outline; the yardage stays on the nameplate.
    local iconMode,blockMode=s.orientation=='icon',s.orientation=='block'
    if ranges.icon then ranges.icon:SetShown(iconMode);ranges.iconEdge:SetShown(iconMode) end
    ranges.rail:SetShown(not (iconMode or blockMode))
    -- Block mode uses the shared indicator border (the racial icons' framing).
    local frameBorder=blockMode and NS.AddEllesmereFrameBorder and NS.AddEllesmereFrameBorder(ranges) or ranges._fhkFrameBorder
    if frameBorder then frameBorder:SetShown(blockMode) end
    if blockMode then
        local w,h=s.blockWidth or 48,s.blockHeight or 14
        ranges:SetSize(w,h)
        ranges.fill:SetPoint('TOPLEFT',ranges,'TOPLEFT',0,0);ranges.fill:SetSize(w,h)
        ranges.fill:SetTexture(Texture("flat"))
        if ranges.iconEdge then ranges.iconEdge:Hide() end
        -- Facing errors still name themselves, just under the block.
        ranges.left:SetPoint('TOP',ranges.fill,'BOTTOM',0,-2)
        Font(ranges.left,s.fontSize,'resourceBars')
        ranges.left:Hide();ranges.right:Hide()
        NS.SyncEllesmereRangeOutline()
        return
    end
    if iconMode then
        local size=s.iconSize or 30
        if not ranges.icon then
            ranges.iconEdge=ranges:CreateTexture(nil,'BACKGROUND',nil,-2);ranges.iconEdge:SetColorTexture(0,0,0,1)
            ranges.icon=ranges:CreateTexture(nil,'ARTWORK',nil,2);ranges.icon:SetTexCoord(.08,.92,.08,.92)
        end
        ranges:SetSize(size,size+(s.text and s.fontSize+4 or 0))
        local edge=Pixel(2)
        ranges.fill:SetPoint('TOP',ranges,'TOP',0,0);ranges.fill:SetSize(size,size)
        ranges.iconEdge:ClearAllPoints()
        ranges.iconEdge:SetPoint('TOPLEFT',ranges.fill,'TOPLEFT',-Pixel(1),Pixel(1))
        ranges.iconEdge:SetPoint('BOTTOMRIGHT',ranges.fill,'BOTTOMRIGHT',Pixel(1),-Pixel(1))
        ranges.icon:ClearAllPoints()
        ranges.icon:SetPoint('TOPLEFT',ranges.fill,'TOPLEFT',edge,-edge);ranges.icon:SetPoint('BOTTOMRIGHT',ranges.fill,'BOTTOMRIGHT',-edge,edge)
        ranges.icon:SetTexture(GetInventoryItemTexture and GetInventoryItemTexture('player',18) or 'Interface\\Icons\\INV_Weapon_Bow_02')
        ranges.right:SetPoint('TOP',ranges.fill,'BOTTOM',0,-2)
        ranges.left:SetPoint('TOP',ranges.right,'BOTTOM',0,-1)
        ranges.fill:SetTexture('Interface\\Buttons\\WHITE8X8')
        Font(ranges.left,s.fontSize,'resourceBars');Font(ranges.right,s.fontSize,'resourceBars')
        ranges.left:Hide();ranges.right:SetShown(s.text)
        NS.SyncEllesmereRangeOutline()
        return
    end
    if s.orientation=='vertical' then
        ranges:SetSize(s.text and 110 or thickness,s.length)
        for _,t in ipairs({ranges.rail,ranges.fill}) do
            t:SetPoint('TOPLEFT',ranges,'TOPLEFT',0,0);t:SetPoint('BOTTOMLEFT',ranges,'BOTTOMLEFT',0,0);t:SetWidth(thickness)
        end
        ranges.left:SetPoint('TOPLEFT',ranges,'TOPLEFT',thickness+5,0)
        ranges.right:SetPoint('BOTTOMLEFT',ranges,'BOTTOMLEFT',thickness+5,0)
    else
        ranges:SetSize(s.length,s.text and math.max(22,s.fontSize+thickness+6) or thickness)
        for _,t in ipairs({ranges.rail,ranges.fill}) do
            t:SetPoint('BOTTOMLEFT',ranges,'BOTTOMLEFT',0,0);t:SetPoint('BOTTOMRIGHT',ranges,'BOTTOMRIGHT',0,0);t:SetHeight(thickness)
        end
        ranges.left:SetPoint('TOPLEFT',ranges,'TOPLEFT',2,-1);ranges.right:SetPoint('TOPRIGHT',ranges,'TOPRIGHT',-2,-1)
    end
    ranges.fill:SetTexture(Texture(s.style))
    Font(ranges.left,s.fontSize,'resourceBars');Font(ranges.right,s.fontSize,'resourceBars')
    ranges.left:SetShown(s.text);ranges.right:SetShown(s.text)
    NS.SyncEllesmereRangeOutline()
end
function NS.ApplyEllesmereIndicators()
    revision=revision+1
    ApplyRange()
    if NS.SyncEllesmereFacingCue then NS.SyncEllesmereFacingCue() end
    if attacks then
        Position(attacks,NS.EllesmereIndicatorSettings('attacks'),attackHome,'TOP')
        -- The original pulse anchor sits just below the HUD, not at its top.
        if not NS.EllesmereIndicatorSettings('attacks').position then
            attacks:ClearAllPoints();attacks:SetPoint('TOP',attackHome,'BOTTOM',0,-3)
        end
        if NS.ApplyAttackCueSize then NS.ApplyAttackCueSize() end
    end
    if EUI._unlockActive and EUI.NotifyElementResized then
        EUI.NotifyElementResized('ForeverRangeIndicator');EUI.NotifyElementResized('ForeverAttackIndicators')
    end
end
local function Element(key,label,kind,frame,order)
    return EUI.MakeUnlockElement({key=key,label=label,group='Resource & Cast Bars',order=order,noResize=true,
        getFrame=function() return frame end,getSize=function() return frame:GetWidth(),frame:GetHeight() end,
        isHidden=function() return NS.EllesmereIndicatorSettings(kind).enabled==false end,
        savePos=function(_,point,relPoint,x,y)
            NS.EllesmereIndicatorSettings(kind).position={point=point,relPoint=relPoint,x=x,y=y}
            if not EUI._unlockActive then NS.ApplyEllesmereIndicators() end
        end,
        loadPos=function() return NS.EllesmereIndicatorSettings(kind).position end,
        clearPos=function() NS.EllesmereIndicatorSettings(kind).position=nil end,
        applyPos=function() NS.ApplyEllesmereIndicators() end})
end
function NS.RegisterEllesmereIndicators(rangeFrame,attackFrame,hud)
    ranges,attacks,rangeHome,attackHome=rangeFrame,attackFrame,hud,hud
    ranges:SetParent(UIParent);attacks:SetParent(UIParent)
    NS.ApplyEllesmereIndicators()
    if EUI.MakeUnlockElement and EUI.RegisterUnlockElements then
        EUI:RegisterUnlockElements({Element('ForeverRangeIndicator','Range Indicator','range',ranges,285),
            Element('ForeverAttackIndicators','Auto Attack / Shoot / Throw','attacks',attacks,286)},'FHKEllesmere')
    end
end
-- Range cue presets (audit F23): each cue answers its own question, so a preset
-- picks which questions you want answered rather than repeating one fact.
--   Minimal:  target glow + centre line (am I in range of my target?)
--   Weaving:  + plate text, range names, non-target glow, unit-frame bar (where is everything?)
--   Detailed: + yard units, target-of-target bar, attack labels
local RANGE_PRESETS={
    minimal={flat={nameplateRangeText=false,rangeNameColors=false,targetRangeGlow=true,nonTargetRange=false,showRangeUnits=false},
        range={enabled=true,text=false},frame={enabled=false,targettarget=false},attacks={labels=false}},
    weaving={flat={nameplateRangeText=true,rangeNameColors=true,targetRangeGlow=true,nonTargetRange=true,showRangeUnits=false},
        range={enabled=true,text=true},frame={enabled=true,targettarget=false},attacks={labels=true}},
    detailed={flat={nameplateRangeText=true,rangeNameColors=true,targetRangeGlow=true,nonTargetRange=true,showRangeUnits=true},
        range={enabled=true,text=true},frame={enabled=true,targettarget=true},attacks={labels=true}},
}
local function Flag(v) return v~=false end -- companion toggles default on
function NS.GetEllesmereRangePreset()
    local db=FHKEllesmereDB or {}
    for name,preset in pairs(RANGE_PRESETS) do
        local match=true
        for key,value in pairs(preset.flat) do
            local current=key=='showRangeUnits' and db[key]==true or key~='showRangeUnits' and Flag(db[key])
            if current~=value then match=false end
        end
        for kind,fields in pairs(preset) do
            if kind~='flat' then
                local s=NS.EllesmereIndicatorSettings(kind)
                for key,value in pairs(fields) do if (s[key]~=false)~=value then match=false end end
            end
        end
        if match then return name end
    end
    return 'custom'
end
function NS.ApplyEllesmereRangePreset(name)
    local preset=RANGE_PRESETS[name]
    if not preset then return false end
    if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end
    for key,value in pairs(preset.flat) do FHKEllesmereDB[key]=value end
    for kind,fields in pairs(preset) do
        if kind~='flat' then
            local s=NS.EllesmereIndicatorSettings(kind)
            for key,value in pairs(fields) do s[key]=value end
        end
    end
    NS.ApplyEllesmereIndicators()
    return true
end
-- A stripe along one edge of host; gap moves it outward.
local function PlaceEdge(t,host,s)
    t:ClearAllPoints()
    local side=s.side
    if side=='left' or side=='right' then
        local edge=side=='left' and 'LEFT' or 'RIGHT'
        local dx=side=='left' and -Pixel(s.gap) or Pixel(s.gap)
        t:SetPoint('TOP'..edge,host,'TOP'..edge,dx,0);t:SetPoint('BOTTOM'..edge,host,'BOTTOM'..edge,dx,0)
        t:SetWidth(Pixel(s.thickness))
    else
        local edge=side=='top' and 'TOP' or 'BOTTOM'
        local dy=side=='top' and Pixel(s.gap) or -Pixel(s.gap)
        t:SetPoint(edge..'LEFT',host,edge..'LEFT',0,dy);t:SetPoint(edge..'RIGHT',host,edge..'RIGHT',0,dy)
        t:SetHeight(Pixel(s.thickness))
    end
    t:SetTexture(Texture(s.style))
end
-- Soft range glow for non-target plates: Ellesmere's target-glow art, dimmer and
-- without the centre fill, so the real target glow stays dominant. The ring sits
-- entirely OUTSIDE the bar (extend == corner): an inward overlap met in the middle
-- of short plates and drew a bright line across the health text.
local GLOW_TEX='Interface\\AddOns\\EllesmereUINameplates\\Media\\background.png'
local GLOW_MARGIN,GLOW_CORNER,GLOW_EXTEND=0.48,7,7
local function RangeGlow(plate,f)
    if f.rangeGlow then return f.rangeGlow end
    local g=CreateFrame('Frame',nil,f)
    g:SetFrameStrata('BACKGROUND');g:SetFrameLevel(1)
    g:SetPoint('TOPLEFT',plate.health,'TOPLEFT',-GLOW_EXTEND,GLOW_EXTEND)
    g:SetPoint('BOTTOMRIGHT',plate.health,'BOTTOMRIGHT',GLOW_EXTEND,-GLOW_EXTEND)
    g.textures={}
    local m,c=GLOW_MARGIN,GLOW_CORNER
    local function Tex(l,r,t,b)
        local tex=g:CreateTexture(nil,'BACKGROUND')
        -- Normal blending: an additive glow vanished on bright ground (Barrens,
        -- snow), where every bright hue is under 2.5 : 1 (audit 2026-10-03).
        tex:SetTexture(GLOW_TEX);tex:SetBlendMode('BLEND');tex:SetTexCoord(l,r,t,b)
        g.textures[#g.textures+1]=tex
        return tex
    end
    local tl,tr=Tex(0,m,0,m),Tex(1-m,1,0,m)
    local bl,br=Tex(0,m,1-m,1),Tex(1-m,1,1-m,1)
    for _,corner in ipairs({{tl,'TOPLEFT'},{tr,'TOPRIGHT'},{bl,'BOTTOMLEFT'},{br,'BOTTOMRIGHT'}}) do
        corner[1]:SetSize(c,c);corner[1]:SetPoint(corner[2])
    end
    local top=Tex(m,1-m,0,m);top:SetHeight(c);top:SetPoint('TOPLEFT',tl,'TOPRIGHT');top:SetPoint('TOPRIGHT',tr,'TOPLEFT')
    local bottom=Tex(m,1-m,1-m,1);bottom:SetHeight(c);bottom:SetPoint('BOTTOMLEFT',bl,'BOTTOMRIGHT');bottom:SetPoint('BOTTOMRIGHT',br,'BOTTOMLEFT')
    local left=Tex(0,m,m,1-m);left:SetWidth(c);left:SetPoint('TOPLEFT',tl,'BOTTOMLEFT');left:SetPoint('BOTTOMLEFT',bl,'TOPLEFT')
    local right=Tex(1-m,1,m,1-m);right:SetWidth(c);right:SetPoint('TOPRIGHT',tr,'BOTTOMRIGHT');right:SetPoint('BOTTOMRIGHT',br,'TOPRIGHT')
    g:Hide();f.rangeGlow=g
    return g
end
-- Dark mode (player request): on black plates a glow overpowers everything, so
-- range is a 2px strip along the bottom of every enemy plate instead, the same
-- grammar as the dark swing bars (top line = health, bottom strip = state).
local function DarkMode() return NS.EllesmereDarkMode and NS.EllesmereDarkMode() or false end
local function DarkStrip(plate,f)
    if f.darkStrip then return f.darkStrip end
    local t=f:CreateTexture(nil,'OVERLAY',nil,7)
    t:SetPoint('BOTTOMLEFT',plate.health,'BOTTOMLEFT',0,0);t:SetPoint('BOTTOMRIGHT',plate.health,'BOTTOMRIGHT',0,0)
    t:SetHeight(Pixel(2));t:SetColorTexture(1,1,1,1);t:Hide()
    f.darkStrip=t
    return t
end
-- Shows the non-target range mark in the chosen style and hides the other one.
function NS.SetEllesmereRangeMarkShown(plate,f,shown)
    if DarkMode() then
        f.rangeStrip:Hide();if f.rangeGlow then f.rangeGlow:Hide() end
        DarkStrip(plate,f):SetShown(shown)
        return
    end
    if f.darkStrip then f.darkStrip:Hide() end
    local glow=NS.EllesmereIndicatorSettings('plate').mode~='stripe'
    f.rangeStrip:SetShown(shown and not glow)
    if glow and shown then RangeGlow(plate,f):Show() elseif f.rangeGlow then f.rangeGlow:Hide() end
end
function NS.PaintEllesmereRangeStripe(plate,f,colour)
    local s=NS.EllesmereIndicatorSettings('plate')
    local custom=s.colourMode=='custom' and s.colour or nil
    if DarkMode() then
        DarkStrip(plate,f):SetVertexColor(custom and custom.r or colour[1],custom and custom.g or colour[2],custom and custom.b or colour[3],1)
        return
    end
    if s.mode~='stripe' then
        local g=RangeGlow(plate,f)
        local r,gr,b=custom and custom.r or colour[1],custom and custom.g or colour[2],custom and custom.b or colour[3]
        for _,tex in ipairs(g.textures) do tex:SetVertexColor(r,gr,b,s.glowOpacity or .45) end
        return
    end
    local t=f.rangeStrip
    if f._rangeRevision~=revision then PlaceEdge(t,plate.health,s);f._rangeRevision=revision end
    t:SetVertexColor(custom and custom.r or colour[1],custom and custom.g or colour[2],custom and custom.b or colour[3],s.opacity)
end
-- Outside: a bordered tab joined to the frame's edge, overlapping it by one
-- border pixel so the two borders merge and the tab reads as part of the frame.
-- Inside: the plain accent stripe along the edge.
local function PlaceTab(m,host,s)
    local tab,bar=m.tab,m.bar
    local one=(EUI.PP and EUI.PP.perfect or Pixel(1))/m:GetEffectiveScale()
    local px=one*(s.borderSize or 2)
    tab:ClearAllPoints();bar:ClearAllPoints()
    if s.placement=='inside' then
        tab:SetAllPoints(host);m.border:Hide()
        PlaceEdge(bar,host,s)
        return
    end
    m.border:SetShown(px>0)
    if EUI.PP and EUI.PP.SetBorderSize then EUI.PP.SetBorderSize(tab,s.borderSize or 2) end
    local side,size=s.side,one*s.thickness+2*px
    local off=(s.gap or 0)>0 and one*s.gap or -px
    if side=='left' or side=='right' then
        local near,far=side=='right' and 'LEFT' or 'RIGHT',side=='right' and 'RIGHT' or 'LEFT'
        local dx=side=='right' and off or -off
        tab:SetPoint('TOP'..near,host,'TOP'..far,dx,0);tab:SetPoint('BOTTOM'..near,host,'BOTTOM'..far,dx,0)
        tab:SetWidth(size)
    else
        local near,far=side=='top' and 'BOTTOM' or 'TOP',side=='top' and 'TOP' or 'BOTTOM'
        local dy=side=='top' and off or -off
        tab:SetPoint(near..'LEFT',host,far..'LEFT',0,dy);tab:SetPoint(near..'RIGHT',host,far..'RIGHT',0,dy)
        tab:SetHeight(size)
    end
    bar:SetPoint('TOPLEFT',tab,'TOPLEFT',px,-px);bar:SetPoint('BOTTOMRIGHT',tab,'BOTTOMRIGHT',-px,px)
    bar:SetTexture(Texture(s.style))
end
-- Range bar on Ellesmere unit frames in the range colour, fading in and out
-- with the reading.
function NS.PaintEllesmereFrameRangeMark(frame,colour,visible)
    local m=frame._fhkRangeMark
    if not m then
        if not visible then return end
        m=CreateFrame('Frame',nil,frame)
        m:SetAllPoints(frame);m:SetFrameLevel(frame:GetFrameLevel()+20);m:EnableMouse(false)
        m.tab=CreateFrame('Frame',nil,m);m.tab:EnableMouse(false)
        m.bar=m.tab:CreateTexture(nil,'ARTWORK')
        -- Ellesmere's own pixel-perfect border, so the tab matches the frame's.
        if EUI.PP and EUI.PP.CreateBorder then m.border=EUI.PP.CreateBorder(m.tab,0,0,0,1,2,'OVERLAY',0) end
        if not m.border then
            m.border=m.tab:CreateTexture(nil,'BACKGROUND');m.border:SetAllPoints(m.tab)
            m.border:SetColorTexture(0,0,0,1)
        end
        m:SetAlpha(0);m._fhkHideAfterFade=true;m:Hide()
        frame._fhkRangeMark=m
    end
    local s=NS.EllesmereIndicatorSettings('frame')
    if visible then
        local scale=m:GetEffectiveScale()
        if m._revision~=revision or m._scale~=scale then PlaceTab(m,frame,s);m._revision=revision;m._scale=scale end
        local c=s.colourMode=='custom' and s.colour or nil
        m.bar:SetVertexColor(c and c.r or colour[1],c and c.g or colour[2],c and c.b or colour[3],s.opacity)
    end
    if NS.FadeEllesmere then NS.FadeEllesmere(m,visible) else m:SetShown(visible);m:SetAlpha(visible and 1 or 0) end
end
local slots={
    {key='textSlotTop',anchor='BOTTOM',point='TOP',xOff=0,top=true,justify='CENTER'}, -- SetJustifyH takes LEFT/CENTER/RIGHT only (review)
    {key='textSlotLeft',anchor='LEFT',point='LEFT',xOff=4},
    {key='textSlotCenter',anchor='CENTER',point='CENTER',xOff=0},
    {key='textSlotRight',anchor='RIGHT',point='RIGHT',xOff=-2},
    {key='textSlotBottomLeft',anchor='TOPLEFT',point='BOTTOMLEFT',xOff=0,bottom=true,justify='LEFT'},
    {key='textSlotBottomRight',anchor='TOPRIGHT',point='BOTTOMRIGHT',xOff=0,bottom=true,justify='RIGHT'}}
local kinds={euiRangeDistance=true,euiRangeState=true,euiRangeFull=true}
function NS.PaintEllesmereRangeText(plate,f,distance,state,colour,visible)
    local np=_G.EllesmereNameplates_NS
    local p=np and (np.NP_GetProfile and np.NP_GetProfile() or np.db and np.db.profile) or {}
    p=p or {}
    local s=NS.EllesmereIndicatorSettings('plate')
    f.rangeSlots=f.rangeSlots or {}
    local assigned=false
    for _,slot in ipairs(slots) do
        local key=slot.key
        local element=np and np.GetTextSlot and np.GetTextSlot(key) or p[key]
        local fs=f.rangeSlots[key]
        if kinds[element] then
            assigned=true
            if not fs then fs=f:CreateFontString(nil,'OVERLAY');f.rangeSlots[key]=fs end
            -- Native slot position/size/strata and colour controls remain authoritative.
            local drop=plate.cast and plate.cast:IsShown() and (plate._castDrop or 0) or 0
            if fs._revision~=revision or fs._element~=element or fs._drop~=drop then
                if np.SlotTextHost then fs:SetParent(np.SlotTextHost(plate,key,p[key..'Strata'] or 'MEDIUM')) end
                if np.SetFSFont then np.SetFSFont(fs,np.GetTextSlotSize and np.GetTextSlotSize(key) or 10)
                else Font(fs,p[key..'Size'] or 10) end
                local x,y=p[key..'XOffset'] or 0,p[key..'YOffset'] or 0
                if plate.PlaceSlotText then plate:PlaceSlotText(fs,slot,x,y+(slot.top and 5 or 0))
                else
                    fs:ClearAllPoints();fs:SetPoint(slot.anchor,plate.health,slot.point,slot.xOff+x,y+(slot.bottom and drop-2 or slot.top and 5 or 0))
                end
                fs:SetJustifyH(slot.justify or slot.anchor)
                fs._revision,fs._element,fs._drop=revision,element,drop
            end
            local text=element=='euiRangeState' and state or element=='euiRangeFull' and (distance..' | '..state) or distance
            if fs._text~=text then fs:SetText(text);fs._text=text end
            local custom=s.textColourMode=='custom' and s.textColour or s.textColourMode=='slot' and
                (p[key..'Color'] or np.defaults and np.defaults[key..'Color'])
            fs:SetTextColor(custom and custom.r or colour[1],custom and custom.g or colour[2],custom and custom.b or colour[3],1)
            fs:SetShown(visible)
        elseif fs then fs:Hide() end
    end
    -- Hidden default text keeps its place: the loot cue may be using it (suite review SF-9).
    if not assigned and visible then
        -- Same face and outline as the plate's health numbers (text consistency).
        -- Font and anchor only when they change (review R10); the colour follows range every tick.
        local anchor=plate.cast and plate.cast:IsShown() and plate.cast or plate.health
        if f._fhkTextRevision~=revision or f._fhkTextAnchor~=anchor then
            if np and np.SetFSFont then np.SetFSFont(f.text,s.textSize) else Font(f.text,s.textSize,'nameplates') end
            f.text:ClearAllPoints();f.text:SetPoint('TOP',anchor,'BOTTOM',s.textX,s.textY)
            f._fhkTextRevision,f._fhkTextAnchor=revision,anchor
        end
        local c=s.textColourMode=='custom' and s.textColour or nil
        f.text:SetTextColor(c and c.r or colour[1],c and c.g or colour[2],c and c.b or colour[3],1)
    end
    return assigned
end
function NS.AddEllesmereRangeSlotChoices(cfg)
    if not cfg or cfg.type~='dropdown' or not cfg.values or not cfg.values.enemyName or not cfg.values.healthPercent then return end
    for _,item in ipairs({{'euiRangeDistance','Range'},{'euiRangeState','Range State'},{'euiRangeFull','Range | State'}}) do
        if not cfg.values[item[1]] then
            cfg.values[item[1]]=item[2];if cfg.order then cfg.order[#cfg.order+1]=item[1] end
        end
    end
end
-- Section Reset (review C8): a button that restores only its own section's settings, after
-- Ellesmere's confirm popup when the suite offers one. Shared by every companion builder:
-- reset() does the work, then the page re-reads its rows.
function NS.EllesmereSectionReset(section,reset,tooltip)
    local name=tostring(section)
    local title='Reset '..name
    local function Go()
        local ok,err=pcall(reset)
        if not ok and type(geterrorhandler)=='function' then pcall(geterrorhandler(),err) end
        if EUI.RefreshPage then pcall(EUI.RefreshPage,EUI) end
    end
    return {type='button',text=title,
        tooltip=tooltip or ('Restores the '..name..' settings to their defaults. Other sections keep theirs.'),
        onClick=function()
            if type(EUI.ShowConfirmPopup)=='function' and pcall(EUI.ShowConfirmPopup,EUI,{title=title,
                message='Restore the '..name..' settings to their defaults?',confirmText='Reset',cancelText='Cancel',onConfirm=Go}) then
                return
            end
            Go()
        end}
end
-- One indicator's settings back to DEFAULTS in place (option rows keep their reference);
-- keep lists the keys that stay, such as the Unlock Mode position.
local function ResetIndicator(kind,keep)
    local s=NS.EllesmereIndicatorSettings(kind)
    local kept={}
    for _,k in ipairs(keep or {}) do kept[k]=s[k] end
    for k in pairs(s) do s[k]=nil end
    for k,v in pairs(defaults[kind]) do s[k]=type(v)=='table' and Copy(v) or v end
    for k,v in pairs(kept) do s[k]=v end
    NS.ApplyEllesmereIndicators()
end
NS.ResetEllesmereIndicatorSection=ResetIndicator
local SIDES,SIDE_ORDER={left='Left',right='Right',top='Top',bottom='Bottom'},{'left','right','top','bottom'}
local TEXTURES,TEXTURE_ORDER={flat='Flat',textured='Native Texture'},{'flat','textured'}
-- Saved colours are read defensively: a damaged value falls back to the default.
local function RGB(c,d)
    if type(c)=='table' and type(c.r)=='number' and type(c.g)=='number' and type(c.b)=='number' then return c.r,c.g,c.b end
    return d.r,d.g,d.b
end
-- Ellesmere's row tools (review C10): the main choice on the row, sizes in its cog, its
-- colour as an inline swatch. Rows that do not apply grey out and say why (review C9).
function NS.AddEllesmereIndicatorOptions(Row,kind)
    local s=NS.EllesmereIndicatorSettings(kind)
    local base=defaults[kind]
    local function Set(key,v)
        s[key]=v
        if kind=='attacks' and key=='enabled' then FHKEllesmereDB.attackPulses=v end
        NS.ApplyEllesmereIndicators()
    end
    local function Needs(cfg,off,why) if off then cfg.disabled,cfg.disabledTooltip=off,why end;return cfg end
    local function Toggle(text,key) return {type='toggle',text=text,getValue=function() return s[key]~=false end,setValue=function(v) Set(key,v) end} end
    local function Drop(text,key,values,order) return {type='dropdown',text=text,values=values,order=order,getValue=function() return s[key] end,setValue=function(v) Set(key,v) end} end
    local function Slider(text,key,min,max,step) return {type='slider',text=text,min=min,max=max,step=step or 1,
        getValue=function() local v=s[key];return type(v)=='number' and v or base[key] end,setValue=function(v) Set(key,v) end} end
    local function CogSlider(label,key,min,max,step,off,why) return {type='slider',label=label,min=min,max=max,step=step or 1,disabled=off,disabledTooltip=why,
        get=function() local v=s[key];return type(v)=='number' and v or base[key] end,set=function(v) Set(key,v) end} end
    -- Opacity reads as a percentage (audit F28); stored as 0-1.
    local function CogPercent(label,key,min,off,why) return {type='slider',label=label,min=min,max=100,step=5,disabled=off,disabledTooltip=why,
        get=function() local v=s[key];v=type(v)=='number' and v or base[key] or 1;return math.floor(v*100+.5) end,set=function(v) Set(key,v/100) end} end
    local function CogDrop(label,key,values,order,off,why) return {type='dropdown',label=label,values=values,order=order,disabled=off,disabledTooltip=why,
        get=function() return s[key] end,set=function(v) Set(key,v) end} end
    local function Swatch(key,tip,off,why) return {tooltip=tip,hasAlpha=false,disabled=off,disabledTooltip=why,
        getValue=function() local r,g,b=RGB(s[key],base[key]);return r,g,b,1 end,
        setValue=function(r,g,b)
            if type(r)~='number' or type(g)~='number' or type(b)~='number' then return end
            s[key]={r=r,g=g,b=b};NS.ApplyEllesmereIndicators()
        end} end
    local function ColourMode(text) return Drop(text,'colourMode',{range='Range State',custom='Custom'},{'range','custom'}) end
    if kind=='plate' then
        local glowOff=function() return s.mode=='stripe' end
        local stripeOff=function() return s.mode~='stripe' end
        local GLOW,STRIPE='This option applies to the Soft Glow mark','This option applies to the Edge Stripe mark'
        local mark=Drop('Non-Target Range Mark','mode',{glow='Soft Glow',stripe='Edge Stripe'},{'glow','stripe'})
        mark.tooltip='How enemies other than your target show their range: a soft glow around the plate or a stripe along one edge. Dark Mode always uses a thin bottom strip.'
        mark.cog={title='Range Mark',rows={CogPercent('Glow Opacity %','glowOpacity',10,glowOff,GLOW),
            CogDrop('Stripe Position','side',SIDES,SIDE_ORDER,stripeOff,STRIPE),CogSlider('Stripe Thickness','thickness',1,12,1,stripeOff,STRIPE),
            CogSlider('Stripe Gap','gap',0,12,1,stripeOff,STRIPE),CogPercent('Stripe Opacity %','opacity',10,stripeOff,STRIPE),
            CogDrop('Stripe Texture','style',TEXTURES,TEXTURE_ORDER,stripeOff,STRIPE)}}
        local markColour=ColourMode('Range Mark Color')
        markColour.tooltip='Range State: the glow or stripe follows the range colors. Custom: one color, set with the swatch.'
        markColour.swatches={Swatch('colour','Custom Range Mark Color',function() return s.colourMode~='custom' end,'This option requires Range Mark Color set to Custom')}
        Row(mark,markColour)
        local text=Drop('Range Text Color','textColourMode',{range='Range State',slot='Native Slot Color',custom='Custom'},{'range','slot','custom'})
        text.tooltip='Range State: the text follows the range colors. Native Slot Color: the color set on its text slot. Custom: the swatch color.'
        text.swatches={Swatch('textColour','Custom Range Text Color',function() return s.textColourMode~='custom' end,'This option requires Range Text Color set to Custom')}
        local size=Slider('Default Range Text Size','textSize',8,20)
        size.tooltip='Size of the range text under the plate when no native text slot shows range.'
        size.move={title='Default Range Text Position',rows={CogSlider('X Offset','textX',-150,150),CogSlider('Y Offset','textY',-60,60)}}
        Row(text,size,true)
        Row({type='label',text='Assign Range / Range State / Range | State to any native text slot'},
            {type='label',text='Slot cogs control its font, size, offsets and custom color'})
        Row(NS.EllesmereSectionReset('Range Indicator Style',function() ResetIndicator('plate') end),
            {type='label',text='Native text slot settings are not changed'})
    elseif kind=='frame' then
        local off=function() return s.enabled==false end
        local OFF='Unit Frame Range Bar'
        local bar=Toggle('Unit Frame Range Bar','enabled')
        bar.tooltip='A bar in the range color on the target, focus and target of target frames. It hides while range is unknown.'
        bar.cog={title='Range Bar',disabled=off,disabledTooltip=OFF,rows={
            CogDrop('Position','side',SIDES,SIDE_ORDER),
            CogDrop('Placement','placement',{outside='Extends the Frame',inside='Inside the Frame'},{'outside','inside'}),
            CogSlider('Thickness','thickness',1,12),CogSlider('Gap','gap',0,12),
            CogSlider('Border','borderSize',0,3,1,function() return s.placement=='inside' end,'This option applies when Placement is Extends the Frame'),
            CogPercent('Opacity %','opacity',10),CogDrop('Texture','style',TEXTURES,TEXTURE_ORDER)}}
        local colour=Needs(ColourMode('Range Bar Color'),off,OFF)
        colour.tooltip='Range State: the bar follows the range colors. Custom: one color, set with the swatch.'
        colour.swatches={Swatch('colour','Custom Range Bar Color',function() return s.colourMode~='custom' end,'This option requires Range Bar Color set to Custom')}
        Row(bar,colour)
        Row(Needs(Toggle('Target Frame','target'),off,OFF),Needs(Toggle('Focus Frame','focus'),off,OFF))
        Row(Needs(Toggle('Target of Target Frame','targettarget'),off,OFF),{type='label',text='Enemies only; hidden while range is unknown'})
        -- The frame bar has no free position, so its reset is the section's own (review 2026-10-06).
        Row(NS.EllesmereSectionReset('Range Bar',function() ResetIndicator('frame') end),
            {type='label',text='The bar moves with its unit frame'})
    elseif kind=='range' then
        local off=function() return s.enabled==false end
        local OFF='Range Indicator'
        local indicator=Toggle('Range Indicator','enabled')
        indicator.tooltip='The center range indicator for your target: a bar, a block or your weapon icon in the range color.'
        indicator.preview={tip='Preview the range indicator for ten seconds',duration=10,disabled=off,disabledTooltip=OFF,show=function()
            if NS.SetEllesmerePreviewScenario then NS.SetEllesmerePreviewScenario(select(2,UnitClass('player'))=='HUNTER' and 'deadzone' or 'melee') end
        end}
        local text=Needs(Toggle('Range Indicator Text','text'),function() return off() or s.orientation=='block' end,
            function() return off() and OFF or 'This option does not apply to the Color Block shape' end)
        text.tooltip='Shows the range state and yards beside or under the indicator.'
        text.cog={title='Range Indicator Text',rows={CogSlider('Font Size','fontSize',8,20)}}
        Row(indicator,text)
        Row(Needs({type='toggle',text='Facing Failure Cue',
            tooltip='Shows FACE TARGET beside the range indicator when the client reports a facing failure. Clears after a successful harmful cast, target change or a short timeout.',
            getValue=function() return s.facingWarning~=false end,
            setValue=function(v) s.facingWarning=v;if NS.SyncEllesmereFacingCue then NS.SyncEllesmereFacingCue() end end},off,OFF),
            {type='button',text='Check Facing Data',tooltip='Prints what the client reports about facing your target.',
                onClick=function() if NS.ExplainEllesmereFacing then NS.ExplainEllesmereFacing() end end})
        Row(Needs({type='toggle',text='Line Of Sight / Movement Failure Cue',
            tooltip='Shows NO LINE OF SIGHT or STOP MOVING on the range indicator after a confirmed client error. Clears on target change, a successful harmful cast or after 1.2 seconds.',
            getValue=function() return s.castFailureWarning==true end,
            setValue=function(v) s.castFailureWarning=v;if NS.SyncEllesmereFacingCue then NS.SyncEllesmereFacingCue() end end},off,OFF),
            {type='label',text='Cast failures share the range indicator'})
        local bars=function() return s.orientation=='icon' or s.orientation=='block' end
        local BARS='This option applies to the Horizontal and Vertical Bar shapes'
        local notBlock=function() return s.orientation~='block' end
        local notIcon=function() return s.orientation~='icon' end
        local shape=Needs(Drop('Range Indicator Shape','orientation',{horizontal='Horizontal Bar',vertical='Vertical Bar',icon='Weapon Icon',block='Color Block'},
            {'block','icon','horizontal','vertical'}),off,OFF)
        shape.tooltip='Color Block: a block with a black outline. Weapon Icon: your ranged weapon framed in the range color. Bars: a thin rail with the range text.'
        shape.cog={title='Range Indicator Size',rows={
            CogSlider('Bar Length','length',80,500,1,bars,BARS),CogSlider('Bar Thickness','thickness',1,16,1,bars,BARS),
            CogDrop('Bar Texture','style',TEXTURES,TEXTURE_ORDER,bars,BARS),
            CogSlider('Block Width','blockWidth',16,200,1,notBlock,'This option applies to the Color Block shape'),
            CogSlider('Block Height','blockHeight',6,40,1,notBlock,'This option applies to the Color Block shape'),
            CogSlider('Icon Size','iconSize',20,48,1,notIcon,'This option applies to the Weapon Icon shape'),
            CogPercent('Opacity %','opacity',10)}}
        local colour=Needs(ColourMode('Range Indicator Color'),off,OFF)
        colour.tooltip='Range State: the indicator follows the range colors. Custom: one color, set with the swatch.'
        colour.swatches={Swatch('colour','Custom Range Indicator Color',function() return s.colourMode~='custom' end,'This option requires Range Indicator Color set to Custom')}
        Row(shape,colour)
        -- One row per bracket: show it, what the text says; the cog holds label, pulse and sound.
        Row({type='dropdown',text='Range Bracket Preset',values={all='Always Show',quiet='Hide While Shooting',problems='Problems Only',custom='Custom'},
            order={'all','quiet','problems','custom'},disabled=off,disabledTooltip=OFF,
            tooltip='Always Show: the indicator shows in every bracket. Hide While Shooting: it shows only when you are not in shooting range. Problems Only: dead zone, too far and out of range, each with a pulse as you enter it.',
            getValue=function() return NS.GetEllesmereRangeBracketPreset() end,
            setValue=function(v) if v~='custom' then NS.ApplyEllesmereRangeBracketPreset(v) end end},
            {type='label',text='Changing a bracket below switches to Custom'})
        local soundValues={none='None',raid='Raid Warning',alarm='Alarm',ready='Ready Check',tick='Tick'}
        local soundOrder={'none','raid','alarm','ready','tick'}
        local contents={both='State And Yards',label='State Only',yards='Yards Only',none='Color Only'}
        for _,item in ipairs(BRACKETS) do
            local key,name=item[1],item[2]
            local b=NS.EllesmereRangeBracket(key)
            local function BSet(k,v) b[k]=v;NS.ApplyEllesmereIndicators() end
            local show={type='toggle',text='Show In '..name,disabled=off,disabledTooltip=OFF,
                tooltip='Off hides the range indicator while your target is in this bracket. Plates and unit frames keep their range color.',
                getValue=function() return b.show end,setValue=function(v) BSet('show',v) end}
            show.cog={title=name..' Bracket',disabled=off,disabledTooltip=OFF,rows={
                {type='input',label='Custom Label',get=function() return b.label end,
                    set=function(v)
                        v=type(v)=='string' and v:gsub('|',''):gsub('^%s+',''):gsub('%s+$','') or ''
                        BSet('label',v:sub(1,24))
                    end},
                {type='toggle',label='Pulse On Entering',get=function() return b.pulse end,set=function(v) BSet('pulse',v) end},
                {type='dropdown',label='Sound On Entering',values=soundValues,order=soundOrder,get=function() return b.sound end,
                    set=function(v) BSet('sound',v);if NS.PlayEllesmereCueSound then NS.PlayEllesmereCueSound(v,'bracketPreview') end end}}}
            Row(show,{type='dropdown',text=name..' Text',values=contents,order={'both','label','yards','none'},disabled=off,disabledTooltip=OFF,
                tooltip='What the range indicator text says in this bracket. Color Only keeps just the bar or block color.',
                getValue=function() return b.content end,setValue=function(v) BSet('content',v) end},true)
        end
        Row({type='button',text='Reset Range Position',tooltip='Returns the indicator to its place under the HUD. Move it in Unlock Mode.',
            disabled=function() return s.position==nil end,disabledTooltip='This option is available after moving the indicator in Unlock Mode',
            onClick=function() s.position=nil;NS.ApplyEllesmereIndicators() end},
            NS.EllesmereSectionReset('Range Indicator',function() ResetIndicator('range',{'position'}) end,
                'Restores the Range Indicator shape, colors, brackets and failure cues to their defaults. Its position stays.'))
    else
        local off=function() return s.enabled==false end
        local OFF='Auto Attack Indicators'
        local main=Toggle('Auto Attack Indicators','enabled')
        main.tooltip='Squares by the range indicator that light while Auto Shot, Shoot, Throw or melee auto attack is on.'
        main.cog={title='Auto Attack Indicators',disabled=off,disabledTooltip=OFF,rows={
            CogDrop('Layout','orientation',{flank='Either Side of Range',horizontal='Horizontal',vertical='Vertical'},{'flank','horizontal','vertical'}),
            CogSlider('Gap','gap',0,50),
            CogDrop('Artwork','style',{class='Class Icons',combat='Combat Icons'},{'class','combat'},function() return s.orientation=='flank' end,
                'This option does not apply to the Either Side of Range layout, which uses framed squares'),
            CogPercent('Opacity %','opacity',10),
            {type='slider',label='Size',min=16,max=48,step=1,
                get=function() local v=FHKEllesmereDB.attackCueSize;return type(v)=='number' and v or 28 end,
                set=function(v) FHKEllesmereDB.attackCueSize=v;NS.ApplyEllesmereIndicators() end}}}
        local labels=Needs(Toggle('Attack Indicator Labels','labels'),off,OFF)
        labels.tooltip='Names each square: the ranged one follows Auto Shot, Shoot or Throw.'
        Row(main,labels)
        Row(Needs(Toggle('Melee Attack Indicator','melee'),off,OFF),Needs(Toggle('Ranged / Shoot / Throw Indicator','ranged'),off,OFF))
        Row(Needs({type='toggle',text='Show Attack Squares While Off',tooltip='Keeps the squares visible while no auto attack is on.',
            getValue=function() return s.showIdle==true end,setValue=function(v) Set('showIdle',v) end},off,OFF),
            {type='label',text='Move it in Unlock Mode: Auto Attack / Shoot / Throw'})
        Row({type='button',text='Reset Attack Position',tooltip='Returns the squares to their place under the HUD.',
            disabled=function() return s.position==nil end,disabledTooltip='This option is available after moving the squares in Unlock Mode',
            onClick=function() s.position=nil;NS.ApplyEllesmereIndicators() end},
            NS.EllesmereSectionReset('Auto Attack Indicators',function()
                FHKEllesmereDB.attackPulses=nil;FHKEllesmereDB.attackCueSize=nil
                ResetIndicator('attacks',{'position'})
            end,'Restores the Auto Attack Indicators settings to their defaults. Their position stays.'))
    end
end
function NS.AddEllesmereTimingOptions(Row)
    local timing=NS.WeaveTiming
    if not timing or not SlashCmdList.FHKTIMING then return end
    local function Saved()
        return timing.GetSettings and timing.GetSettings() or ForeverHunterKeysDB and ForeverHunterKeysDB.weaveTiming or {}
    end
    local function Command(cmd,value) SlashCmdList.FHKTIMING(cmd..' '..tostring(value));if NS.RefreshNativeSwingRows then NS.RefreshNativeSwingRows() end end
    Row({type='slider',text='Plant Time Estimate',min=0,max=2,step=.05,
        tooltip='Seconds you stand still before Auto Shot starts after moving. Advice only; the game clock is unchanged.',
        getValue=function() return timing.GetPlantSeconds and timing.GetPlantSeconds() or Saved().plantSeconds or 0 end,
        setValue=function(v) Command('plant',v) end},
        {type='toggle',text='Restart Bow After Melee',tooltip='A melee swing restarts the Auto Shot cycle in the timing advice.',getValue=function() return timing.RangedResetsOnMelee() end,
            setValue=function(v)
                FHKEllesmereDB.swingCursor=FHKEllesmereDB.swingCursor or {};FHKEllesmereDB.swingCursor.resetOnMelee=v
                Command('rangedreset',v and 'on' or 'off')
            end})
    Row({type='slider',text='Aim Window Estimate',min=.1,max=2,step=.05,
        tooltip='Seconds before Auto Shot fires in which moving or casting would delay it.',
        getValue=function() return Saved().aimSeconds or .5 end,setValue=function(v) Command('aim',v) end},
        {type='dropdown',text='Melee Lockout Estimate',values={melee='Actual Melee Swing',fixed='Fixed Estimate'},order={'melee','fixed'},
            getValue=function() return Saved().lockoutMode or 'melee' end,setValue=function(v) Command('lockout',v) end})
    Row({type='slider',text='Fixed Lockout Estimate',min=.1,max=2,step=.05,
        tooltip='How long a melee swing blocks the bow when the lockout is a fixed estimate.',
        disabled=function() return (Saved().lockoutMode or 'melee')~='fixed' end,
        disabledTooltip='This option requires Melee Lockout Estimate set to Fixed Estimate',
        getValue=function() return Saved().lockoutSeconds or 1 end,setValue=function(v) Command('lockout',v) end},
        {type='label',text='Estimates are configurable; measured swing/cast events remain authoritative'})
    Row(NS.EllesmereSectionReset('Hunter Timing',function()
        Command('reset','')
        if type(FHKEllesmereDB.swingCursor)=='table' then FHKEllesmereDB.swingCursor.resetOnMelee=nil end
    end,'Restores the plant, aim and lockout estimates and Restart Bow After Melee to their defaults.'),
        {type='label',text='Shared with ForeverHunterKeys when it is installed'})
end
-- Changes to native text-slot cogs invalidate only layout, not range probes.
local driver=CreateFrame('Frame')
local hooked
local function Install()
    local np=_G.EllesmereNameplates_NS
    if np and np~=hooked and np.RefreshAllSettings then
        hooked=np;hooksecurefunc(np,'RefreshAllSettings',function() revision=revision+1 end)
    end
end
driver:RegisterEvent('PLAYER_LOGIN');driver:RegisterEvent('ADDON_LOADED');driver:RegisterEvent('UI_SCALE_CHANGED')
driver:SetScript('OnEvent',function(_,event)
    -- Pixel geometry depends on the scale (review R9): repaint everything.
    if event=='UI_SCALE_CHANGED' then revision=revision+1;ApplyRange() else Install() end
end)
Install()
