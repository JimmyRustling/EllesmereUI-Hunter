-- Movable Hunter aspect icon, secure bar and advice badge.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS or not NS.AspectLogic then return end
local L,A=NS.AspectLogic,{}
NS.AspectAdvisor=A
A.ORDER,A.SPELLS,A.Decide=L.ORDER,L.SPELLS,L.Decide
local DEFAULTS={enabled=false,display='icon',size=30,spacing=4,orientation='horizontal',keys=true,name=false,
    travel=true,monkey=true,style='auto',dim=true,click=false,visibility='always'}
local CHOICES={display={icon=true,bar=true,current=true},orientation={horizontal=true,vertical=true},
    style={auto=true,ranged=true,weave=true,melee=true},visibility={always=true,combat=true,mouseover=true}}
local LIMITS={size={20,48},spacing={0,12}}
local POINTS={CENTER=true,TOP=true,BOTTOM=true,LEFT=true,RIGHT=true,TOPLEFT=true,TOPRIGHT=true,BOTTOMLEFT=true,BOTTOMRIGHT=true}
local function Plain(v) return not (issecretvalue and issecretvalue(v)) end
local function Number(v) return Plain(v) and type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function Text(v) return Plain(v) and type(v)=='string' end
local function Table(v) return Plain(v) and type(v)=='table' end
local function Call(fn,...)
    if type(fn)~='function' then return false end
    local ok,a,b,c,d=pcall(fn,...)
    return ok,a,b,c,d
end
local function Read(fn,...)
    local ok,a,b,c,d=Call(fn,...)
    if ok and Plain(a) then return a,Plain(b) and b or nil,Plain(c) and c or nil,Plain(d) and d or nil end
end
local function Yes(v) return Plain(v) and v==true end
local function OutsideCombat() local v=Read(_G.InCombatLockdown);return Plain(v) and v==false end
local function Now() local n=Read(_G.GetTime);return Number(n) and n or 0 end
function NS.EllesmereAspectSettings()
    if not Table(FHKEllesmereDB) then FHKEllesmereDB={} end
    local s=FHKEllesmereDB.aspectAdvisor
    if not Table(s) then s={};FHKEllesmereDB.aspectAdvisor=s end
    for k,v in pairs(DEFAULTS) do
        local x=s[k]
        if type(v)=='boolean' then if not Plain(x) or type(x)~='boolean' then s[k]=v end
        elseif LIMITS[k] then if not Number(x) or x<LIMITS[k][1] or x>LIMITS[k][2] then s[k]=v end
        elseif not Text(x) or not CHOICES[k][x] then s[k]=v end
    end
    return s
end
local names,icons,known,ids,keys={},{},{},{},{}
local active,auraReady
local holder,visual,badge,label,root,flyout,clicker
local buttons={}
local driver=CreateFrame('Frame')
local ticker,queued,pending,epoch=nil,false,false,0
local cfg,enabled=false,false
local stable,advice={},{}
local movingSince,shotAt,previewUntil=nil,nil,nil
local meleeTalents={'predatorsEdge','laceratingStrikes','exposePrey','striderKick'}
local function Known(id)
    if not Number(id) then return false end
    return Yes(Read(C_SpellBook and C_SpellBook.IsSpellKnown,id)) or
        Yes(Read(_G.IsPlayerSpell,id)) or Yes(Read(_G.IsSpellKnown,id))
end
function A.RefreshKnown()
    for _,key in ipairs(L.ORDER) do
        local base=L.SPELLS[key]
        local name=Read(C_Spell and C_Spell.GetSpellName,base)
        if not Text(name) then name=Read(_G.GetSpellInfo,base) end
        names[key]=Text(name) and name or nil
        local info=names[key] and Read(C_Spell and C_Spell.GetSpellInfo,names[key])
        local id=Table(info) and Number(info.spellID) and info.spellID or base
        local learned=Known(id)
        if not learned and Known(base) then id,learned=base,true end
        ids[key]=id
        known[key]=learned and true or nil
        local icon=Table(info) and info.iconID or Read(C_Spell and C_Spell.GetSpellTexture,id)
        icons[key]=(Number(icon) or Text(icon)) and icon or nil
    end
end
function A.Known() return known end
function A.RefreshAura()
    active,auraReady=nil,true
    for _,key in ipairs(L.ORDER) do if known[key] then
        local fn=C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
        local ok,aura
        if type(fn)=='function' and names[key] then ok,aura=Call(fn,'player',names[key],'HELPFUL')
        else ok,aura=Call(C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID,ids[key]) end
        if not ok or not Plain(aura) or aura~=nil and not Table(aura) then auraReady=false
        elseif aura then active=key end
    end end
end
function A.Active() return active end
local function Short(key)
    if not Text(key) then return nil end
    key=key:gsub('CTRL%-','C-'):gsub('SHIFT%-','S-'):gsub('ALT%-','A-')
    return #key<=3 and key or nil
end
function A.RefreshKeys()
    keys={}
    for _,key in ipairs(L.ORDER) do if names[key] then keys[key]=Short(Read(_G.GetBindingKey,'SPELL '..names[key])) end end
    for _,group in ipairs(Table(NS.groups) and NS.groups or {}) do
        local index=Text(group.name) and Read(_G.GetMacroIndexByName,group.name)
        local body=Number(index) and index>0 and Read(_G.GetMacroBody,index)
        local bind=Text(group.name) and Read(_G.GetBindingKey,'MACRO '..group.name)
        if Text(body) and Text(bind) then
            local matched=false
            for clause in (body:match('/cast%s+([^\n]+)') or ''):gmatch('[^;]+') do
                local mod,spell=clause:match('^%s*%[mod:(%a+)%]%s*!?(.-)%s*$')
                if not spell then spell=clause:match('^%s*!?([^%[]-)%s*$') end
                local prefix=mod=='ctrl' and 'CTRL-' or mod=='shift' and 'SHIFT-' or mod=='alt' and 'ALT-' or ''
                if not spell or mod and prefix=='' then break end
                local hasMod=bind:find('CTRL-',1,true) or bind:find('SHIFT-',1,true) or bind:find('ALT-',1,true)
                local boundMatch=mod and prefix~='' and hasMod and bind:find(prefix,1,true)
                local reachable=not matched and (mod and prefix~='' and (not hasMod or boundMatch) or not mod)
                for _,key in ipairs(L.ORDER) do if reachable and spell==names[key] and not keys[key] then
                    keys[key]=Short(mod and not hasMod and prefix..bind or bind)
                end end
                if boundMatch or not mod and spell then matched=true end
            end
        end
    end
end
function A.Key(key) return keys[key] end
local function Style(s,now)
    if s.style~='auto' then return s.style end
    local T=NS.HunterTalents
    if known.beast and Table(T) and type(T.Has)=='function' then
        for _,key in ipairs(meleeTalents) do if Yes(Read(T.Has,key)) then return 'melee' end end
    end
    return (shotAt and now>=shotAt and now-shotAt<3) and 'weave' or 'ranged'
end
local function HostileTarget()
    return Yes(Read(_G.UnitExists,'target')) and Yes(Read(_G.UnitCanAttack,'player','target')) and Read(_G.UnitIsDead,'target')==false
end
function A.Inputs(now)
    now=now or Now()
    local s=cfg or NS.EllesmereAspectSettings()
    local combat=Read(_G.InCombatLockdown)
    local hostile=HostileTarget()
    local range
    if hostile then
        local sample=Read(NS.GetUnitRange,'target')
        local value=Table(sample) and Text(sample.state) and sample.state or nil
        range=L.StableRange(stable,value,now)
    else stable={} end
    local dead=Read(_G.UnitIsDeadOrGhost,'player')
    local mounted,taxi=Read(_G.IsMounted),Read(_G.UnitOnTaxi,'player')
    return {combat=Yes(combat),range=range,hostile=hostile,
        onYou=Yes(Read(_G.UnitIsUnit,'targettarget','player')),dead=Yes(dead),
        mounted=Yes(mounted) or Yes(taxi) or Yes(Read(_G.UnitInVehicle,'player')),
        unknown=not auraReady or type(combat)~='boolean' or type(dead)~='boolean' or type(mounted)~='boolean' or type(taxi)~='boolean',
        moving=movingSince~=nil and now-movingSince>=3,indoors=Read(_G.IsIndoors)~=false,
        active=active,known=known,style=Style(s,now),travel=s.travel,monkey=s.monkey}
end
function A.Advice(now)
    now=now or Now()
    local i=A.Inputs(now)
    local key,tier=L.Decide(i)
    if previewUntil and now<previewUntil then key,tier='hawk','action' end
    return L.StableAdvice(advice,key,tier,now,i.combat)
end
function A.ResetAdvice() stable,advice={},{} end
local function Color(key)
    local c=cfg and Table(cfg.colors) and cfg.colors[key]
    if Table(c) and Number(c[1]) and c[1]>=0 and c[1]<=1 and Number(c[2]) and c[2]>=0 and c[2]<=1 and Number(c[3]) and c[3]>=0 and c[3]<=1 then return c[1],c[2],c[3] end
    local C=NS.Colours or {}
    c=key=='danger' and C.danger or key=='action' and C.caution or key=='hawk' and C.shoot or key=='beast' and C.melee
    if c then return c[1],c[2],c[3] end
    local r,g,b=Read(EUI.GetAccentColor)
    if Number(r) and Number(g) and Number(b) then return r,g,b end
    return .86,.65,.5
end
local function Font(fs,size)
    local path=Read(EUI.GetFontPath,'extras')
    fs:SetFont(Text(path) and path or 'Fonts\\FRIZQT__.TTF',size,'OUTLINE')
end
local function Square(frame)
    frame.icon=frame:CreateTexture(nil,'ARTWORK');frame.icon:SetAllPoints(frame);frame.icon:SetTexCoord(.08,.92,.08,.92)
    frame.border=Read(EUI.MakeBorder,frame,0,0,0,1)
    frame.edge=CreateFrame('Frame',nil,frame);frame.edge:SetPoint('TOPLEFT',frame,'TOPLEFT',-2,2);frame.edge:SetPoint('BOTTOMRIGHT',frame,'BOTTOMRIGHT',2,-2)
    frame.edge:EnableMouse(false)
    frame.edgeBorder=Read(EUI.MakeBorder,frame.edge,1,1,1,1)
    local g=frame.edge:CreateAnimationGroup();local a=g:CreateAnimation('Alpha')
    a:SetFromAlpha(1);a:SetToAlpha(.35);a:SetDuration(.45);a:SetSmoothing('IN_OUT');g:SetToFinalAlpha(false)
    frame.pulse=g;frame.edge:SetAlpha(0)
end
local function SetBorder(border,r,g,b,a) if border and type(border.SetColor)=='function' then border:SetColor(r,g,b,a) end end
local function Edge(frame,tier,loop)
    local reduced=NS.EllesmereReduceMotion and NS.EllesmereReduceMotion()
    local signature=tostring(tier)..tostring(loop)..tostring(reduced)
    local r,g,b=Color(tier=='danger' and 'danger' or 'action')
    SetBorder(frame.edgeBorder,r,g,b,1)
    if frame.paintSignature==signature then return end
    frame.paintSignature=signature;frame.pulse:Stop()
    frame.edge:SetAlpha((tier=='danger' or tier=='action') and 1 or 0)
    if (tier=='danger' or tier=='action') and not reduced then
        frame.pulse:SetLooping(loop and 'BOUNCE' or 'NONE');frame.pulse:Play()
    end
end
local function Position()
    if not holder or not OutsideCombat() then pending=true;return end
    local p=NS.EllesmereAspectSettings().position
    local valid=Table(p) and Text(p.point) and POINTS[p.point] and Text(p.relPoint) and POINTS[p.relPoint] and Number(p.x) and Number(p.y)
    holder:ClearAllPoints()
    holder:SetPoint(valid and p.point or 'CENTER',UIParent,valid and p.relPoint or 'CENTER',valid and p.x or -260,valid and p.y or -160)
end
A.Position=Position
local hoverEnter=[[if control:GetAttribute("hover") then control:SetAlpha(1) end
if control:GetAttribute("expand") then local f=control:GetFrameRef("flyout");if f then f:Show() end end]]
local hoverLeave=[[if not control:IsUnderMouse(true) then
if control:GetAttribute("expand") then local f=control:GetFrameRef("flyout");if f then f:Hide() end end
if control:GetAttribute("hover") then control:SetAlpha(0) end end]]
local function Hover(frame)
    if type(SecureHandlerWrapScript)=='function' then
        SecureHandlerWrapScript(frame,'OnEnter',holder,hoverEnter)
        SecureHandlerWrapScript(frame,'OnLeave',holder,hoverLeave)
    end
end
local function Build()
    if holder then return end
    holder=CreateFrame('Frame','FHKEllesmereAspects',UIParent,'SecureHandlerStateTemplate')
    holder:SetSize(30,30);holder:SetFrameStrata('MEDIUM');holder:EnableMouse(true)
    visual=CreateFrame('Frame',nil,holder);visual:SetPoint('TOPLEFT',holder,'TOPLEFT');visual:EnableMouse(false);Square(visual)
    visual.empty=visual:CreateFontString(nil,'OVERLAY');Font(visual.empty,12);visual.empty:SetPoint('CENTER',visual,'CENTER')
    visual.key=visual:CreateFontString(nil,'OVERLAY');Font(visual.key,9);visual.key:SetPoint('TOPLEFT',visual,'TOPLEFT',1,-2)
    badge=CreateFrame('Frame',nil,visual);badge:EnableMouse(false);Square(badge)
    badge.key=badge:CreateFontString(nil,'OVERLAY');Font(badge.key,9);badge.key:SetPoint('TOP',badge,'BOTTOM',0,-1)
    label=holder:CreateFontString(nil,'OVERLAY');Font(label,10);label:SetPoint('TOP',holder,'BOTTOM',0,-3)
    Hover(holder)
    if EUI.MakeUnlockElement and EUI.RegisterUnlockElements then
        EUI:RegisterUnlockElements({EUI.MakeUnlockElement({key='FHKEllesmereAspects',label='Aspects',group='Unit Frames',order=620,noResize=true,
            getFrame=function() return holder end,getSize=function() return holder:GetWidth(),holder:GetHeight() end,
            isHidden=function() return not enabled end,
            savePos=function(_,point,relPoint,x,y) if Text(point) and POINTS[point] and Text(relPoint) and POINTS[relPoint] and Number(x) and Number(y) then NS.EllesmereAspectSettings().position={point=point,relPoint=relPoint,x=x,y=y};Position() end end,
            loadPos=function() return NS.EllesmereAspectSettings().position end,
            clearPos=function() NS.EllesmereAspectSettings().position=nil;Position() end,applyPos=Position
        })},'FHKEllesmere')
    end
end
local function Bar()
    if root then return end
    root=CreateFrame('Frame',nil,holder,'SecureHandlerBaseTemplate');root:EnableMouse(true)
    root:SetPoint('TOPLEFT',holder,'TOPLEFT');Hover(root)
    flyout=CreateFrame('Frame',nil,root,'SecureHandlerBaseTemplate');flyout:EnableMouse(true);Hover(flyout)
    holder:SetFrameRef('flyout',flyout)
end
local function Button(index)
    if buttons[index] then return buttons[index] end
    local b=CreateFrame('Button','FHKEllesmereAspectButton'..index,flyout,'SecureActionButtonTemplate')
    b:RegisterForClicks('AnyUp');b:SetAttribute('type','spell');Square(b);Hover(b)
    b.key=b:CreateFontString(nil,'OVERLAY');Font(b.key,9);b.key:SetPoint('TOPRIGHT',b,'TOPRIGHT',-1,-2)
    b.cooldown=CreateFrame('Cooldown',nil,b,'CooldownFrameTemplate');b.cooldown:SetAllPoints(b)
    buttons[index]=b
    return b
end
function A.Layout()
    if not holder or not cfg or not OutsideCombat() then pending=true;return end
    local bar=cfg.display~='icon'
    local size,gap=cfg.size,cfg.spacing
    visual:SetSize(size,size)
    badge:SetSize(math.floor(size/2+.5),math.floor(size/2+.5));badge:ClearAllPoints();badge:SetPoint('CENTER',visual,'TOPRIGHT',0,0)
    if bar then
        Bar();root:SetSize(size,size)
        local count=0
        for _,key in ipairs(L.ORDER) do if known[key] then
            count=count+1;local b=Button(count);b.aspect=key;b:SetAttribute('spell',ids[key]);b:SetSize(size,size)
            b.icon:SetTexture(icons[key]);b:ClearAllPoints()
            b:SetPoint('TOPLEFT',flyout,'TOPLEFT',cfg.orientation=='horizontal' and (count-1)*(size+gap) or 0,cfg.orientation=='vertical' and -(count-1)*(size+gap) or 0)
            b:Show()
        end end
        for i=count+1,#buttons do buttons[i].aspect=nil;buttons[i]:Hide() end
        local long=math.max(1,count)*size+math.max(0,count-1)*gap
        flyout:SetSize(cfg.orientation=='horizontal' and long or size,cfg.orientation=='vertical' and long or size)
        flyout:ClearAllPoints()
        flyout:SetPoint('TOPLEFT',root,cfg.display=='current' and 'BOTTOMLEFT' or 'TOPLEFT',0,0)
        holder:SetSize(cfg.display=='bar' and flyout:GetWidth() or size,cfg.display=='bar' and flyout:GetHeight() or size)
        holder:SetAttribute('expand',cfg.display=='current');root:Show()
        if cfg.display=='bar' then flyout:Show() else flyout:Hide() end
    else
        holder:SetSize(size,size);holder:SetAttribute('expand',false)
        if root then root:Hide();flyout:Hide() end
    end
    if cfg.click and not bar and type(RegisterStateDriver)=='function' then
        if not clicker then
            clicker=CreateFrame('Button',nil,holder,'SecureActionButtonTemplate');clicker:RegisterForClicks('AnyUp');clicker:SetAllPoints(visual)
            Hover(clicker)
        end
        RegisterStateDriver(clicker,'visibility','[combat] hide; show')
        clicker:Show()
    elseif clicker then
        if type(UnregisterStateDriver)=='function' then UnregisterStateDriver(clicker,'visibility') end
        clicker:Hide()
    end
    if type(RegisterStateDriver)=='function' then RegisterStateDriver(holder,'visibility',cfg.visibility=='combat' and '[combat] show; hide' or 'show') else holder:Show() end
    holder:SetAttribute('hover',cfg.visibility=='mouseover');holder:SetAlpha(cfg.visibility=='mouseover' and 0 or 1)
    Position()
end
function A.Paint(now)
    if not enabled or not holder or not cfg then return end
    local key,tier=A.Advice(now)
    local single=cfg.display~='bar'
    visual:SetAlpha(single and 1 or 0)
    visual.icon:SetTexture(active and icons[active] or nil);visual.icon:SetAlpha(1)
    visual.empty:SetText(active and '' or auraReady and '--' or '?')
    visual.key:SetText(cfg.keys and active and keys[active] or '')
    if active then local r,g,b=Color(active);SetBorder(visual.border,r,g,b,1) else SetBorder(visual.border,.6,.6,.6,.6) end
    Edge(visual,single and tier or nil,single and tier=='danger')
    local show=single and key and key~=active and icons[key]
    badge:SetAlpha(show and (tier=='info' and .55 or 1) or 0)
    if show then
        badge.icon:SetTexture(icons[key]);badge.key:SetText(cfg.keys and keys[key] or '')
        local r,g,b=Color(key);SetBorder(badge.border,r,g,b,1)
    end
    for _,b in ipairs(buttons) do if b.aspect then
        local chosen=b.aspect==active
        b:SetAlpha((chosen or not cfg.dim) and 1 or .55)
        if chosen then local r,g,blue=Color(b.aspect);SetBorder(b.border,r,g,blue,1) else SetBorder(b.border,0,0,0,1) end
        b.key:SetText(cfg.keys and keys[b.aspect] or '')
        Edge(b,b.aspect==key and tier or nil,not single and b.aspect==key and tier=='danger')
    end end
    label:SetText(cfg.name and (active and names[active] or auraReady and 'No Aspect' or 'Aspect Unknown') or '')
    if clicker and cfg.click and OutsideCombat() then
        local cast=key and known[key] and not (previewUntil and (now or Now())<previewUntil)
        clicker:SetAttribute('type',cast and 'spell' or nil);clicker:SetAttribute('spell',cast and ids[key] or nil)
    end
end
local function Cooldowns()
    if not cfg or cfg.display=='icon' then return end
    for _,b in ipairs(buttons) do if b.aspect then
        local info=Read(C_Spell and C_Spell.GetSpellCooldown,ids[b.aspect])
        if Table(info) and Number(info.startTime) and Number(info.duration) then b.cooldown:SetCooldown(info.startTime,info.duration)
        else b.cooldown:Clear() end
    end end
end
local function Tick(on)
    if on and not ticker and C_Timer and type(C_Timer.NewTicker)=='function' then ticker=C_Timer.NewTicker(.25,function()
        if enabled then A.Paint();if not HostileTarget() then Tick(false) end end
    end)
    elseif not on and ticker then ticker:Cancel();ticker=nil end
end
local function Queue()
    if queued or not enabled then return end
    queued=true;local token=epoch
    local function Flush()
        if token~=epoch then return end
        queued=false;if not enabled then return end
        A.RefreshKnown();A.RefreshKeys();A.RefreshAura()
        if OutsideCombat() then A.Layout() else pending=true end
        A.Paint();Cooldowns()
    end
    if C_Timer and C_Timer.After then C_Timer.After(.1,Flush) else Flush() end
end
local events={'PLAYER_ENTERING_WORLD','PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED','PLAYER_TARGET_CHANGED','SPELLS_CHANGED',
    'PLAYER_STARTED_MOVING','PLAYER_STOPPED_MOVING','PLAYER_SWING',
    'UPDATE_BINDINGS','UPDATE_MACROS','PLAYER_MOUNT_DISPLAY_CHANGED','SPELL_UPDATE_COOLDOWN',
    'PLAYER_DEAD','PLAYER_ALIVE','PLAYER_UNGHOST','PLAYER_CONTROL_GAINED','PLAYER_CONTROL_LOST'}
function A.OnEvent(_,event,unit,kind)
    if event=='PLAYER_LOGIN' then NS.SyncEllesmereAspects();return end
    if event=='PLAYER_REGEN_ENABLED' and pending then NS.SyncEllesmereAspects();return end
    if not enabled then return end
    if event=='SPELLS_CHANGED' or event=='PLAYER_ENTERING_WORLD' then Queue();return end
    local now=Now()
    if event=='UNIT_AURA' then if unit~='player' then return end;A.RefreshAura()
    elseif event=='UPDATE_BINDINGS' or event=='UPDATE_MACROS' then A.RefreshKeys()
    elseif event=='PLAYER_TARGET_CHANGED' then A.ResetAdvice()
    elseif event=='PLAYER_STARTED_MOVING' then
        movingSince=now;local token=epoch
        if C_Timer and C_Timer.After then C_Timer.After(3.05,function() if enabled and token==epoch then A.Paint() end end) end
    elseif event=='PLAYER_STOPPED_MOVING' then movingSince=nil
    elseif event=='PLAYER_SWING' and Number(kind) and Enum and Enum.PlayerSwingType and kind==Enum.PlayerSwingType.Ranged then shotAt=now
    elseif event=='SPELL_UPDATE_COOLDOWN' then Cooldowns();return end
    Tick(HostileTarget());A.Paint(now)
end
function NS.SyncEllesmereAspects()
    if not OutsideCombat() then pending=true;driver:RegisterEvent('PLAYER_REGEN_ENABLED');return end
    epoch=epoch+1;queued=false;pending=false;Tick(false)
    driver:UnregisterAllEvents()
    local s=NS.EllesmereAspectSettings();local _,class=Read(_G.UnitClass,'player')
    enabled=s.enabled and class=='HUNTER'
    if not enabled then
        if holder then
            if type(UnregisterStateDriver)=='function' then UnregisterStateDriver(holder,'visibility') end
            holder:Hide()
        end
        if clicker then
            if type(UnregisterStateDriver)=='function' then UnregisterStateDriver(clicker,'visibility') end
            clicker:Hide()
        end
        for _,b in ipairs(buttons) do Edge(b,nil,false) end
        if visual then Edge(visual,nil,false) end
        if NS.SyncEllesmereWarnings then NS.SyncEllesmereWarnings() end
        return
    end
    cfg={};for k,v in pairs(s) do cfg[k]=v end
    local speed=Read(_G.GetUnitSpeed,'player')
    movingSince=Number(speed) and speed>0 and Now() or nil
    local start=Read(NS.GetCursorSwingClock,'ranged')
    shotAt=Number(start) and Now()>=start and Now()-start<3 and start or nil
    Build();A.RefreshKnown();A.RefreshKeys();A.RefreshAura();A.ResetAdvice()
    for _,event in ipairs(events) do
        local useful=not (event=='SPELL_UPDATE_COOLDOWN' and cfg.display=='icon') and
            not (event=='PLAYER_SWING' and cfg.style~='auto')
        if useful and (not C_EventUtils or Yes(Read(C_EventUtils.IsEventValid,event))) then driver:RegisterEvent(event) end
    end
    if driver.RegisterUnitEvent then driver:RegisterUnitEvent('UNIT_AURA','player');driver:RegisterUnitEvent('UNIT_TARGET','target') end
    A.Layout();A.Paint();Cooldowns();Tick(HostileTarget())
    if NS.SyncEllesmereWarnings then NS.SyncEllesmereWarnings() end
end
function NS.PreviewEllesmereAspects()
    if not enabled then return end
    previewUntil=Now()+3;A.Paint();local token=epoch
    if C_Timer and C_Timer.After then C_Timer.After(3.05,function() if enabled and token==epoch then previewUntil=nil;A.Paint() end end) end
end
function A.State() return {holder=holder,visual=visual,badge=badge,buttons=buttons,flyout=flyout,driver=driver,enabled=enabled,pending=pending,ticker=ticker} end
function A.Enabled() return enabled end
-- Static search labels never create settings or frames.
function NS.AddEllesmereAspectOptions(Row)
    if EUI.IsSearchPrebuild and EUI.IsSearchPrebuild() then
        local labels={'Aspect Element','Aspect Display','Aspect Icon Size','Aspect Bar Spacing','Aspect Bar Orientation','Dim Inactive Aspects',
            'Aspect Key Labels','Aspect Name','Travel Advice','Monkey When Mob Is On You','Melee Style','Aspect Visibility','Click Advice Out of Combat','Aspect Preview',
            'Move Aspects in Unlock Mode','Current Only: hover for the learned bar','Advice Edge Color','Danger Edge Color',
            'Hawk Edge Color','Monkey Edge Color','Cheetah Edge Color','Pack Edge Color','Beast Edge Color','Wild Edge Color','Reset Aspect Colors'}
        for i=1,#labels,2 do Row({type='label',text=labels[i]},labels[i+1] and {type='label',text=labels[i+1]} or EUI.BlankRowCfg()) end
        return
    end
    local function Settings() return NS.EllesmereAspectSettings() end
    local function Off() return not Settings().enabled end
    local function NotBar() return Off() or Settings().display=='icon' end
    local function Set(k,v)
        if LIMITS[k] then if not Number(v) or v<LIMITS[k][1] or v>LIMITS[k][2] then return end
        elseif CHOICES[k] then if not Text(v) or not CHOICES[k][v] then return end
        elseif type(DEFAULTS[k])=='boolean' then if not Plain(v) or type(v)~='boolean' then return end end
        Settings()[k]=v;NS.SyncEllesmereAspects()
    end
    local function Toggle(text,k,disabled)
        return {type='toggle',text=text,getValue=function() return Settings()[k] end,setValue=function(v) Set(k,v) end,disabled=disabled,disabledTooltip='Aspect Element'}
    end
    local function Drop(text,k,values,order,disabled)
        return {type='dropdown',text=text,values=values,order=order,getValue=function() return Settings()[k] end,setValue=function(v) Set(k,v) end,disabled=disabled,disabledTooltip='Aspect Element'}
    end
    Row(Toggle('Aspect Element','enabled'),Drop('Aspect Display','display',{icon='Icon',bar='Bar',current='Current Only'},{'icon','bar','current'},Off))
    Row({type='slider',text='Aspect Icon Size',min=20,max=48,step=1,getValue=function() return Settings().size end,setValue=function(v) Set('size',v) end,disabled=Off,disabledTooltip='Aspect Element'},
        {type='slider',text='Aspect Bar Spacing',min=0,max=12,step=1,getValue=function() return Settings().spacing end,setValue=function(v) Set('spacing',v) end,disabled=NotBar,disabledTooltip='Aspect Display: Bar or Current Only'})
    Row(Drop('Aspect Bar Orientation','orientation',{horizontal='Horizontal',vertical='Vertical'},{'horizontal','vertical'},NotBar),Toggle('Dim Inactive Aspects','dim',NotBar))
    Row(Toggle('Aspect Key Labels','keys',Off),Toggle('Aspect Name','name',Off))
    Row(Toggle('Travel Advice','travel',Off),Toggle('Monkey When Mob Is On You','monkey',Off))
    Row(Drop('Melee Style','style',{auto='Auto',ranged='Ranged',weave='Ranged + Weave',melee='Melee'},{'auto','ranged','weave','melee'},Off),
        Drop('Aspect Visibility','visibility',{always='Always',combat='In Combat',mouseover='Mouseover'},{'always','combat','mouseover'},Off))
    Row(Toggle('Click Advice Out of Combat','click',function() return Off() or Settings().display~='icon' end),
        {type='button',text='Aspect Preview',onClick=NS.PreviewEllesmereAspects,disabled=Off,disabledTooltip='Aspect Element'})
    Row({type='label',text='Move Aspects in Unlock Mode'},{type='label',text='Current Only: hover for the learned bar'})
    local function Swatch(key,text)
        return {type='colorpicker',text=text,hasAlpha=false,getValue=function()
            local saved=cfg;cfg=Settings();local r,g,b=Color(key);cfg=saved;return r,g,b,1
        end,setValue=function(r,g,b)
            if not Number(r) or not Number(g) or not Number(b) or r<0 or r>1 or g<0 or g>1 or b<0 or b>1 then return end
            local s=Settings();s.colors=Table(s.colors) and s.colors or {};s.colors[key]={r,g,b};NS.SyncEllesmereAspects()
        end}
    end
    Row(Swatch('action','Advice Edge Color'),Swatch('danger','Danger Edge Color'))
    for i=1,#L.ORDER,2 do local a,b=L.ORDER[i],L.ORDER[i+1];Row(Swatch(a,a:gsub('^%l',string.upper)..' Edge Color'),Swatch(b,b:gsub('^%l',string.upper)..' Edge Color')) end
    Row({type='button',text='Reset Aspect Colors',onClick=function() Settings().colors=nil;NS.SyncEllesmereAspects() end},EUI.BlankRowCfg())
end
driver:SetScript('OnEvent',A.OnEvent);driver:RegisterEvent('PLAYER_LOGIN')
if NS.HunterTalents and NS.HunterTalents.OnChange then NS.HunterTalents.OnChange(function() if enabled and cfg.style=='auto' then Queue() end end) end

