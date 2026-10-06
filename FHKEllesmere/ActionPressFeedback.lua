-- Show every action-bar press and an optional animated, movable input history.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end

local DEFAULTS={flash=false,history=false,nagaLabels=false,mode='presses',count=5,size=32,gap=4,direction='horizontal',
    keys=true,keySize=10,keyPosition='bottom',hold=6,opacity=1,olderOpacity=.45,fold=true,mouse=false,
    flashOpacity=.85,flashDuration=.18,zoom=.06}
local LIMITS={count={3,8},size={16,64},gap={0,16},keySize={8,18},hold={1,15},opacity={.2,1},
    olderOpacity={.1,1},flashOpacity={.1,1},flashDuration={.08,.5},zoom={0,.2}}
local MODIFIERS={{'SHIFT-','IsShiftKeyDown'},{'CTRL-','IsControlKeyDown'},{'ALT-','IsAltKeyDown'}}
local CAST_EVENTS={UNIT_SPELLCAST_SUCCEEDED=true,UNIT_SPELLCAST_FAILED=true,
    UNIT_SPELLCAST_FAILED_QUIET=true,UNIT_SPELLCAST_INTERRUPTED=true}
local bindings={MainBar='ACTIONBUTTON',Bar9='EUI_BAR9_BUTTON',Bar10='EUI_BAR10_BUTTON',
    PetBar='BONUSACTIONBUTTON',StanceBar='SHAPESHIFTBUTTON'}
local nativeBars={MultiBarBottomLeft='Bar2',MultiBarBottomRight='Bar3',MultiBarRight='Bar4',
    MultiBarLeft='Bar5',MultiBar5='Bar6',MultiBar6='Bar7',MultiBar7='Bar8'}
for i=2,8 do bindings['Bar'..i]='MULTIACTIONBAR'..(i-1)..'BUTTON' end
local flashes,attached=setmetatable({},{__mode='k'}),setmetatable({},{__mode='k'})
local nativeHooks,applyHooks={},setmetatable({},{__mode='k'})
local driver=CreateFrame('Frame')
local activeFlash,activeHistory=false,false
local history,entries,pool,inputs=nil,{},{},{}
local castGeneration,castQueued,castEvents=0,false,{}
local unlockPreview=false
local function Public(v) return not (issecretvalue and issecretvalue(v)) end
local function Number(v)
    return Public(v) and type(v)=='number' and v==v and v>-math.huge and v<math.huge
end
local function Read(fn,...)
    if type(fn)~='function' then return end
    local ok,a,b,c=pcall(fn,...)
    if ok and Public(a) and Public(b) and Public(c) then return a,b,c end
end
function NS.EllesmerePressSettings()
    if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end
    local s=FHKEllesmereDB.actionPress
    if type(s)~='table' then s={};FHKEllesmereDB.actionPress=s end
    for key,value in pairs(DEFAULTS) do if s[key]==nil then s[key]=value end end
    for key,limits in pairs(LIMITS) do
        local v=s[key]
        s[key]=Number(v) and math.max(limits[1],math.min(limits[2],v)) or DEFAULTS[key]
    end
    s.count=math.floor(s.count)
    local c=s.flashColour
    if c~=nil and not (type(c)=='table' and Number(c.r) and Number(c.g) and Number(c.b)) then s.flashColour=nil end
    return s
end
local function Bars() return EUI._ModuleNS and EUI._ModuleNS.EllesmereUIActionBars end
local function Accent()
    if EUI.GetAccentColor then return EUI.GetAccentColor() end
    return .86,.65,.50
end
-- The press flash follows the live accent unless the player picked its own colour.
local function FlashColour(s)
    local c=s.flashColour
    if c then return c.r,c.g,c.b end
    return Accent()
end
local function Border(frame,r,g,b,a)
    if EUI.MakeBorder then return EUI.MakeBorder(frame,r,g,b,a) end
end
local function Flash(button)
    local s=NS.EllesmerePressSettings()
    local f=flashes[button]
    if not f then
        f=CreateFrame('Frame',nil,button)
        f:SetAllPoints(button);f:SetFrameLevel(button:GetFrameLevel()+25);f:EnableMouse(false)
        f.border=Border(f,FlashColour(s))
        f.fill=f:CreateTexture(nil,'OVERLAY');f.fill:SetAllPoints()
        local group=f:CreateAnimationGroup();local a=group:CreateAnimation('Alpha')
        a:SetToAlpha(0);a:SetSmoothing('OUT');group:SetToFinalAlpha(true)
        group:SetScript('OnFinished',function() f:Hide() end)
        f.group,f.anim=group,a;flashes[button]=f
    end
    local r,g,b=FlashColour(s)
    if f.border then f.border:SetColor(r,g,b,1) end
    f.fill:SetColorTexture(r,g,b,.07)
    f.group:Stop();f:SetAlpha(s.flashOpacity);f:Show()
    f.anim:SetFromAlpha(s.flashOpacity);f.anim:SetDuration(s.flashDuration);f.group:Play()
end
local function Short(key)
    return (key:gsub('SHIFT%-','S+'):gsub('CTRL%-','C+'):gsub('ALT%-','A+'):
        gsub('MOUSEWHEELUP','MwU'):gsub('MOUSEWHEELDOWN','MwD'):gsub('BUTTON','M'))
end
-- Optional physical labels for a Razer Naga on the default Synapse outputs
-- (audit F44). Only outputs a keyboard doesn't also produce are renamed.
local NAGA_KEYS={F9='N1',F10='N2',F11='N3',F12='N4',INSERT='N5',DELETE='N6'}
local NAGA_CHORDS={{'CTRL-SHIFT-B','N9'},{'CTRL-SHIFT-C','N11'},{'ALT-I','N12'}}
local function Naga(key)
    for _,chord in ipairs(NAGA_CHORDS) do
        if key==chord[1] then return chord[2] end
        if key:sub(-#chord[1]-1)=='-'..chord[1] then return Short(key:sub(1,-#chord[1]-1))..chord[2] end
    end
    local base=key:match('[^%-]+$')
    if base and NAGA_KEYS[base] then return Short(key:sub(1,-#base-1))..NAGA_KEYS[base] end
end
local function Compact(key)
    if not Public(key) or type(key)~='string' then return '' end
    local s=NS.EllesmerePressSettings and NS.EllesmerePressSettings()
    if s and s.nagaLabels then
        local label=Naga(key)
        if label then return label end
    end
    return Short(key)
end
NS.EllesmereKeyLabel=Compact
local function Base(key) return key:sub(-1)=='-' and '-' or key:match('[^%-]+$') end
local function Held(key)
    if not Public(key) or type(key)~='string' or Read(IsKeyDown,Base(key))~=true then return false end
    for _,pair in ipairs(MODIFIERS) do
        local fn=_G[pair[2]]
        if fn and (Read(fn)==true)~=(key:find(pair[1],1,true)~=nil) then return false end
    end
    return true
end
local function Key(command)
    local a,b=Read(GetBindingKey,command)
    if Held(a) then return Compact(a),true end
    if Held(b) then return Compact(b),true end
    return Compact(a or b),false
end
local function Icon(button)
    local region=button and (button.icon or button.Icon)
    return region and Read(region.GetTexture,region)
end
local function Spell(button)
    local slot=button and (Read(button.GetAttribute,button,'action') or button.action)
    if not Number(slot) then return end
    local kind,id,subType=Read(GetActionInfo,slot)
    if not Public(kind) or not Number(id) then return end
    if kind=='spell' then return id end
    if kind=='macro' then
        if subType=='spell' then return id end
        if subType=='item' then local _,spell=Read(C_Item and C_Item.GetItemSpell,id);return spell end
        local name=Read(GetActionText,slot) or Read(C_ActionBar and C_ActionBar.GetActionText,slot)
        local index=name and Read(GetMacroIndexByName,name)
        return Read(GetMacroSpell,Number(index) and index>0 and index or id)
    end
    if kind=='item' then local _,spell=Read(C_Item and C_Item.GetItemSpell,id);return spell end
end
local function Place(cell,x,y)
    cell:ClearAllPoints();cell:SetPoint('BOTTOMLEFT',history,'BOTTOMLEFT',x,y)
    cell.x,cell.y=x,y
end
local function Progress(cell)
    if not cell.animating then return cell.x or 0,cell.y or 0,cell:GetAlpha() end
    local p=Read(cell.motion.GetSmoothProgress,cell.motion)
    p=Number(p) and math.max(0,math.min(1,p)) or 1
    return cell.fromX+(cell.toX-cell.fromX)*p,cell.fromY+(cell.toY-cell.fromY)*p,
        cell.fromAlpha+(cell.toAlpha-cell.fromAlpha)*p
end
local function Move(cell,x,y,alpha,exit)
    if cell.toX==x and cell.toY==y and cell.toAlpha==alpha and cell.exiting==exit then return end
    local fx,fy,fa=Progress(cell)
    cell.group:Stop();Place(cell,fx,fy);cell:SetAlpha(fa);cell:Show()
    cell.fromX,cell.fromY,cell.fromAlpha=fx,fy,fa
    cell.toX,cell.toY,cell.toAlpha,cell.exiting=x,y,alpha,exit
    -- Reduced motion: jump to the new spot and only fade (audit F46).
    if NS.EllesmereReduceMotion and NS.EllesmereReduceMotion() then
        Place(cell,x,y);cell.fromX,cell.fromY=x,y;cell.motion:SetOffset(0,0)
    else cell.motion:SetOffset(x-fx,y-fy) end
    cell.fade:SetFromAlpha(fa);cell.fade:SetToAlpha(alpha)
    cell.animating=true;cell.group:Play()
end
local function Cell()
    for _,cell in ipairs(pool) do if not cell.active and not cell.exiting then cell.active=true;return cell end end
    -- At most two transient exit cells beyond the eight visible entries.
    if #pool>=10 then
        for _,cell in ipairs(pool) do if cell.exiting then
            cell.group:Stop();cell.active,cell.exiting,cell.animating=true,false,false;return cell
        end end
    end
    local cell=CreateFrame('Frame',nil,history)
    cell:EnableMouse(false)
    cell.icon=cell:CreateTexture(nil,'ARTWORK');cell.icon:SetAllPoints()
    cell.border=Border(cell,0,0,0,.9)
    cell.key=cell:CreateFontString(nil,'OVERLAY');cell.repeats=cell:CreateFontString(nil,'OVERLAY')
    local group=cell:CreateAnimationGroup();group:SetToFinalAlpha(true)
    cell.motion=group:CreateAnimation('Translation');cell.fade=group:CreateAnimation('Alpha')
    for _,a in ipairs({cell.motion,cell.fade}) do a:SetOrder(1);a:SetDuration(.25);a:SetSmoothing('OUT') end
    group:SetScript('OnFinished',function()
        cell.animating=false;Place(cell,cell.toX,cell.toY);cell:SetAlpha(cell.toAlpha)
        if cell.exiting then cell:Hide();cell.active,cell.exiting=false,false end
    end)
    cell.group,cell.active=group,true;pool[#pool+1]=cell;return cell
end
local function Clear(wipeInputs)
    entries={};if wipeInputs~=false then inputs={} end
    if history then history.group:Stop();history:Hide() end
    for _,cell in ipairs(pool) do
        cell.group:Stop();cell:Hide();cell.active,cell.exiting,cell.animating=false,false,false
        cell.toX,cell.toY,cell.toAlpha=nil,nil,nil
    end
end
local function Geometry(s)
    local label=s.keys and s.keyPosition=='bottom' and s.keySize+3 or 0
    if s.direction=='vertical' then return s.size,s.count*(s.size+label)+(s.count-1)*s.gap,label end
    return s.count*s.size+(s.count-1)*s.gap,s.size+label,label
end
local function Position()
    if not history then return end
    local p=NS.EllesmerePressSettings().position or {point='BOTTOM',relPoint='BOTTOM',x=0,y=200}
    history:ClearAllPoints();history:SetPoint(p.point,UIParent,p.relPoint or p.point,p.x or 0,p.y or 0)
end
local Render,Preview
local function Build()
    if history then return end
    history=CreateFrame('Frame','FHKEllesmereActionHistory',UIParent)
    history:SetFrameStrata('MEDIUM');history:EnableMouse(false);history:Hide()
    local group=history:CreateAnimationGroup();local a=group:CreateAnimation('Alpha')
    a:SetToAlpha(0);a:SetDuration(.35);a:SetSmoothing('OUT');group:SetToFinalAlpha(true)
    group:SetScript('OnFinished',function() if not unlockPreview then Clear(false) end end)
    history.group,history.fade=group,a
    if EUI.MakeUnlockElement and EUI.RegisterUnlockElements then
        EUI:RegisterUnlockElements({EUI.MakeUnlockElement({key='ForeverActionHistory',label='Recent Actions',group='Action Bars',
            order=290,linkedDimensions=true,
            getFrame=function() return activeHistory and history or nil end,
            getSize=function() return Geometry(NS.EllesmerePressSettings()) end,
            isHidden=function() return not activeHistory end,
            savePos=function(_,point,relPoint,x,y) NS.EllesmerePressSettings().position={point=point,relPoint=relPoint,x=x,y=y} end,
            loadPos=function() return NS.EllesmerePressSettings().position end,
            clearPos=function() NS.EllesmerePressSettings().position=nil end,
            applyPos=Position,
            setWidth=function(w)
                local s=NS.EllesmerePressSettings()
                if Number(w) then s.size=s.direction=='vertical' and w or (w-(s.count-1)*s.gap)/s.count;Render() end
            end,
            setHeight=function(h)
                local s=NS.EllesmerePressSettings();local _,_,label=Geometry(s)
                if Number(h) then s.size=s.direction=='vertical' and (h-(s.count-1)*s.gap)/s.count-label or h-label;Render() end
            end,
        -- Our own folder (suite review SC-3): a suite folder stamp sent the anchor along with
        -- that module's export and dropped it on importing the module.
        })},'FHKEllesmere')
    end
end
local function Style(cell,data,s)
    cell:SetSize(s.size,s.size);cell.icon:SetTexture(data.texture)
    cell.icon:SetTexCoord(s.zoom,1-s.zoom,s.zoom,1-s.zoom)
    local font=EUI.GetFontPath and EUI.GetFontPath('actionBars') or EUI.EXPRESSWAY or 'Fonts\\FRIZQT__.TTF'
    for _,text in ipairs({cell.key,cell.repeats}) do
        if EUI.ApplyIconTextFont then EUI.ApplyIconTextFont(text,font,s.keySize,'actionBars')
        else text:SetFont(font,s.keySize,'OUTLINE') end
    end
    cell.key:ClearAllPoints()
    if s.keyPosition=='bottom' then cell.key:SetPoint('TOP',cell,'BOTTOM',0,-2)
    else cell.key:SetPoint('TOPRIGHT',cell,'TOPRIGHT',-1,-1) end
    -- Bright: the key was seen held. Dim: looked up from the action's binding (audit F04).
    cell.key:SetText(s.keys and data.key or '');cell.key:SetTextColor(1,1,1,data.observed and 1 or .55)
    cell.repeats:ClearAllPoints();cell.repeats:SetPoint('BOTTOMLEFT',cell,'BOTTOMLEFT',2,2)
    cell.repeats:SetText(data.count and data.count>1 and ('x'..data.count) or '')
    local r,g,b=Accent();cell.repeats:SetTextColor(r,g,b,1)
end
Render=function()
    if not history then return end
    local s=NS.EllesmerePressSettings();local w,h,label=Geometry(s)
    history:SetSize(w,h);Position()
    local step=s.size+s.gap+(s.direction=='vertical' and label or 0)
    while #entries>s.count do
        local data=table.remove(entries,1);local cell=data.cell
        if cell then local x,y=Progress(cell)
            Move(cell,s.direction=='vertical' and x or x-step,s.direction=='vertical' and y+step or y,0,true)
        end
    end
    for i,data in ipairs(entries) do
        local cell=data.cell;local index=s.count-#entries+i-1
        local x=s.direction=='vertical' and 0 or index*step
        local y=label+(s.direction=='vertical' and (s.count-1-index)*step or 0)
        if not cell then
            cell=Cell();data.cell=cell;cell:SetAlpha(0);cell.animating=false
            cell.toX,cell.toY,cell.toAlpha=nil,nil,nil
            Place(cell,s.direction=='vertical' and x or x+step,s.direction=='vertical' and y-step or y)
        end
        Style(cell,data,s)
        local opacity=#entries==1 and 1 or s.olderOpacity+(1-s.olderOpacity)*(i-1)/(#entries-1)
        Move(cell,x,y,opacity,false)
    end
    if #entries==0 then history:Hide();return end
    history.group:Stop();history:SetAlpha(s.opacity);history:Show()
    if not unlockPreview then history.fade:SetFromAlpha(s.opacity);history.fade:SetStartDelay(s.hold);history.group:Play() end
    if EUI._unlockActive and EUI.NotifyElementResized then EUI.NotifyElementResized('ForeverActionHistory') end
end
local function Push(data)
    if not data.texture then return end
    Build()
    local s=NS.EllesmerePressSettings();local last=entries[#entries]
    if s.mode=='presses' and s.fold and last and last.command==data.command and last.key==data.key and last.texture==data.texture then
        last.count=(last.count or 1)+1
    else entries[#entries+1]=data end
    Render()
end
local function Matches(data,spell,texture)
    return data.spell==spell or not data.spell and texture and data.texture==texture
end
local function Press(button,command,mouseButton,click)
    if not activeFlash and not activeHistory then return end
    if not button then return end
    if activeFlash then Flash(button) end
    if not activeHistory or unlockPreview then return end
    local s=NS.EllesmerePressSettings();local key,held=Key(command)
    local mouse=click and not held and Read(button.IsUnderMouse,button)==true
    if mouse then key=s.mouse and (mouseButton=='RightButton' and 'RClick' or 'Click') or '' end
    local data={texture=Icon(button),key=key,command=command,count=1,observed=held or mouse}
    if s.mode=='casts' then
        -- Include Mouse Clicks off keeps clicked casts out of the list too (review X9).
        if mouse and not s.mouse then return end
        data.spell=Spell(button);data.time=GetTime()
        inputs[#inputs+1]=data;if #inputs>12 then table.remove(inputs,1) end
        -- An instant cast can succeed inside the native handler, just before
        -- this post-hook. Keep each same-frame success tied to its own input.
        local event=castEvents[#castEvents]
        if event and not event.input and event.time==data.time and Matches(data,event.spell,event.texture) then
            event.input=data;data.event=event
        end
    elseif not mouse or s.mouse then Push(data) end
end
local function Scan()
    if not activeFlash and not activeHistory or InCombatLockdown() then return end
    local ns=Bars()
    for bar,list in pairs(ns and ns.barButtons or {}) do
        for index,button in ipairs(list) do
            if bar~='StanceBar' and not attached[button] then
                attached[button]=true
                local command=bindings[bar] and bindings[bar]..index
                button:HookScript('PostClick',function(self,mouseButton,down)
                    if Public(down) and (down==true or bar=='PetBar' and down==false) then Press(self,command,mouseButton,true) end
                end)
            end
        end
    end
    if ns and type(ns._eabApplyAll)=='function' and not applyHooks[ns] then
        applyHooks[ns]=true;hooksecurefunc(ns,'_eabApplyAll',Scan)
    end
end
local function Native(bar,id,click)
    if not activeFlash and not activeHistory or not Number(id) then return end
    local ns=Bars();local list=ns and ns.barButtons and ns.barButtons[bar]
    local button=list and list[id]
    if button then Press(button,(bindings[bar] or '')..id,'LeftButton',click) end
end
local function Hooks()
    if type(ActionButtonDown)=='function' and not nativeHooks.main then
        nativeHooks.main=true;hooksecurefunc('ActionButtonDown',function(id) Native('MainBar',id) end)
    end
    if type(MultiActionButtonDown)=='function' and not nativeHooks.multi then
        nativeHooks.multi=true;hooksecurefunc('MultiActionButtonDown',function(name,id)
            if Public(name) then local bar=nativeBars[name];if bar then Native(bar,id) end end
        end)
    end
    if PetActionBar and type(PetActionBar.PetActionButtonDown)=='function' and not nativeHooks.pet then
        nativeHooks.pet=true;hooksecurefunc(PetActionBar,'PetActionButtonDown',function(_,id) Native('PetBar',id) end)
    end
    -- Stance bindings and their AnyUp mouse buttons both call Select.
    if StanceBar and type(StanceBar.Select)=='function' and not nativeHooks.stance then
        nativeHooks.stance=true;hooksecurefunc(StanceBar,'Select',function(_,id) Native('StanceBar',id,true) end)
    end
end
local function Cast(event)
    local spell=event.spell
    if not activeHistory or not Number(spell) or NS.EllesmerePressSettings().mode~='casts' then return end
    local texture=Read(C_Spell and C_Spell.GetSpellTexture,spell);local now=GetTime()
    for i=#inputs,1,-1 do
        local data=inputs[i]
        local eligible=event.input and data==event.input or not event.input and not data.event
        if eligible and now-data.time<=30 and Matches(data,spell,texture) then
            if event.success then Push({texture=texture or data.texture,key=data.key,command=data.command,count=1,observed=data.observed}) end
            for j=i,1,-1 do if inputs[j].spell==data.spell and inputs[j].command==data.command then table.remove(inputs,j) end end
            return
        end
    end
end
Preview=function()
    Build();Clear()
    local s=NS.EllesmerePressSettings()
    local textures={'INV_Weapon_Bow_07','Ability_Hunter_SniperShot','Ability_MeleeDamage','Ability_Ensnare','Ability_Hunter_MendPet'}
    local keys={'1','2','F','C','S+V'}
    for i=1,s.count do local n=(i-1)%#textures+1
        entries[i]={texture='Interface\\Icons\\'..textures[n],key=keys[n],command='preview'..i,count=1}
    end
    Render()
end
function NS.SyncEllesmerePressFeedback()
    local s=NS.EllesmerePressSettings()
    activeFlash,activeHistory=s.flash==true,s.history==true
    castGeneration=castGeneration+1;castQueued=false;castEvents={}
    driver:UnregisterAllEvents()
    if activeFlash or activeHistory then
        driver:RegisterEvent('UPDATE_BINDINGS');driver:RegisterEvent('PLAYER_ENTERING_WORLD')
        driver:RegisterEvent('ADDON_LOADED');driver:RegisterEvent('PLAYER_REGEN_ENABLED')
        if activeHistory and s.mode=='casts' then for event in pairs(CAST_EVENTS) do
            if driver.RegisterUnitEvent then driver:RegisterUnitEvent(event,'player') else driver:RegisterEvent(event) end
        end end
        Hooks();Scan()
    end
    if not activeFlash then for _,f in pairs(flashes) do f.group:Stop();f:Hide() end end
    if not activeHistory then Clear()
    else
        Build()
        if EUI.RegisterUnlockModeListener then
            EUI:RegisterUnlockModeListener('FHKEllesmereActionHistory',function(on)
                unlockPreview=on and activeHistory
                if unlockPreview then Preview() else Clear() end
            end)
        end
        if unlockPreview then Preview() else Render() end
    end
    if not activeHistory and EUI.UnregisterUnlockModeListener then EUI:UnregisterUnlockModeListener('FHKEllesmereActionHistory');unlockPreview=false end
end
driver:SetScript('OnEvent',function(_,event,unit,_,spell)
    if CAST_EVENTS[event] then
        if not Public(unit) or unit~='player' or not Number(spell) then return end
        castEvents[#castEvents+1]={spell=spell,time=GetTime(),texture=Read(C_Spell and C_Spell.GetSpellTexture,spell),
            success=event=='UNIT_SPELLCAST_SUCCEEDED'}
        if castQueued then return end
        castQueued=true
        local generation=castGeneration
        -- Cast results can fire synchronously inside UseAction, before our post-hook
        -- captures the input. Drain after the protected key handler returns.
        C_Timer.After(0,function()
            if generation~=castGeneration then return end
            local pending=castEvents;castEvents={};castQueued=false
            for _,cast in ipairs(pending) do Cast(cast) end
        end)
    else Hooks();Scan() end
end)
function NS.PreviewEllesmereActionHistory() Preview() end
function NS.AddEllesmerePressOptions(Row)
    local s=NS.EllesmerePressSettings()
    local function Set(key,value)
        local changedMode=key=='mode' and s.mode~=value
        s[key]=value;if changedMode then Clear() end
        NS.SyncEllesmerePressFeedback()
        -- Dependent controls grey out or return (audit F10).
        if (key=='flash' or key=='history' or key=='mode') and EUI.RefreshPage then EUI:RefreshPage() end
    end
    -- Dependency states (audit F10): controls dim with the reason until their feature is on.
    local flashOff={fn=function() return not s.flash end,why='Flash Every Action Press'}
    local historyOff={fn=function() return not s.history end,why='Recent Action History'}
    local function Needs(cfg,need)
        if need then cfg.disabled,cfg.disabledTooltip=need.fn,need.why end
        return cfg
    end
    local function Toggle(text,key,tooltip,need) return Needs({type='toggle',text=text,tooltip=tooltip,
        getValue=function() return s[key] end,setValue=function(v) Set(key,v) end},need) end
    local function Slider(text,key,min,max,step,need) return Needs({type='slider',text=text,min=min,max=max,step=step or 1,
        getValue=function() return s[key] end,setValue=function(v) Set(key,v) end},need) end
    -- Opacity reads as a percentage everywhere (audit F28); stored as 0-1.
    local function Percent(text,key,min,need) return Needs({type='slider',text=text,min=min,max=100,step=5,
        getValue=function() return math.floor((s[key] or 1)*100+.5) end,setValue=function(v) Set(key,v/100) end},need) end
    local function Drop(text,key,values,order,need) return Needs({type='dropdown',text=text,values=values,order=order,
        getValue=function() return s[key] end,setValue=function(v) Set(key,v) end},need) end
    -- Ellesmere's row tools: fine-tuning in the cogs, the preview on the eye.
    local function CogSlider(label,key,min,max,step) return {type='slider',label=label,min=min,max=max,step=step or 1,
        get=function() return s[key] end,set=function(v) Set(key,v) end} end
    local function CogPercent(label,key,min) return {type='slider',label=label,min=min,max=100,step=5,
        get=function() return math.floor((s[key] or 1)*100+.5) end,set=function(v) Set(key,v/100) end} end
    local function CogDrop(label,key,values,order) return {type='dropdown',label=label,values=values,order=order,
        get=function() return s[key] end,set=function(v) Set(key,v) end} end
    local flash=Toggle('Flash Every Action Press','flash','A short accent border responds to each key-down, even when the ability cannot fire.')
    flash.swatches={{tooltip='Press Flash Color (default: the Ellesmere accent)',hasAlpha=false,disabled=flashOff.fn,disabledTooltip=flashOff.why,
        getValue=function() local r,g,b=FlashColour(s);return r,g,b,1 end,
        setValue=function(r,g,b) if Number(r) and Number(g) and Number(b) then s.flashColour={r=r,g=g,b=b} end end}}
    flash.cog={title='Press Flash',disabled=flashOff.fn,disabledTooltip=flashOff.why,rows={
        CogPercent('Opacity %','flashOpacity',10),CogSlider('Duration','flashDuration',.08,.5,.02)}}
    local history=Toggle('Recent Action History','history','A separate movable unit in native Unlock Mode. Icons slide in and fade away.')
    local hold=CogSlider('Hide After Idle (sec)','hold',1,15,1)
    hold.tooltip='The whole strip fades this long after your last action. Older icons leave when new ones push them out.'
    history.cog={title='Action History',disabled=historyOff.fn,disabledTooltip=historyOff.why,rows={
        CogSlider('Icon Count','count',3,8,1),CogSlider('Icon Size','size',16,64,1),CogSlider('Icon Spacing','gap',0,16,1),
        CogSlider('Icon Zoom','zoom',0,.2,.01),CogDrop('Direction','direction',{horizontal='Horizontal',vertical='Vertical'},{'horizontal','vertical'}),
        hold,CogPercent('Opacity %','opacity',20),CogPercent('Older Icon Opacity %','olderOpacity',10)}}
    history.preview={tip='Preview action history',show=Preview,duration=4}
    Row(flash,history)
    -- Two history displays, two questions (audit F26): ours shows what you pressed
    -- (with keys); Damage Meters' Spell History shows what was cast.
    Row({type='label',text='Recent Actions: what you pressed, with keys. Spell History: what was cast.'},
        {type='button',text='Open Native Spell History',onClick=function()
            if EUI.NavigateToElementSettings then EUI:NavigateToElementSettings('EllesmereUIDamageMeters','Spell History') end
        end})
    -- Cast mode only lists casts that came from an action-bar key (audit F04).
    local records=Drop('History Records','mode',{presses='Key Presses',casts='Casts From Bar Keys'},{'presses','casts'},historyOff)
    records.tooltip='Key Presses: every attempted press. Casts From Bar Keys: successful casts that started from an action-bar key; casts from elsewhere are not listed.'
    local fold=Toggle('Fold Repeated Presses','fold','Groups consecutive presses of the same binding with an xN count.')
    fold.disabled=function() return not s.history or s.mode=='casts' end
    fold.disabledTooltip=function() return not s.history and historyOff.why or 'This option applies when History Records is Key Presses' end
    Row(records,fold)
    local keyLabels=Toggle('Show History Key Labels','keys','Bright label: the key was seen held. Dim label: the action\'s assigned binding, shown when the actual key could not be seen.',historyOff)
    keyLabels.cog={title='History Key Labels',disabled=function() return not (s.history and s.keys) end,
        disabledTooltip=function() return not s.history and historyOff.why or 'Show History Key Labels' end,rows={
        CogSlider('Font Size','keySize',8,18,1),CogDrop('Position','keyPosition',{bottom='Below Icon',corner='Top Right'},{'bottom','corner'})}}
    Row(keyLabels,Toggle('Include Mouse Clicks','mouse','Includes mouse clicks in press history; labels them Click or RClick.',historyOff))
    Row(Toggle('Naga Button Labels','nagaLabels','Shows N1-N6 for F9-F12 / Insert / Delete, N9 / N11 / N12 for the Synapse chords, instead of the keys they send.',historyOff),
        Needs({type='button',text='Move / Resize History',tooltip='Opens Unlock Mode, where Recent Actions moves and resizes like Ellesmere elements.',onClick=function()
            if s.history and EUI.ToggleUnlockMode then EUI:ToggleUnlockMode() end
        end},historyOff))
    if NS.EllesmereSectionReset then
        Row(NS.EllesmereSectionReset('Key Press And Action History',function()
            local position=s.position
            for k in pairs(s) do s[k]=nil end
            s.position=position
            Clear();NS.EllesmerePressSettings();NS.SyncEllesmerePressFeedback()
        end, 'Restores the press flash and action history settings to their defaults, which are off. The history keeps its position.'),
            {type='label',text='Both start off; nothing shows until you turn one on'})
    end
end
if EUI.RegAccent then EUI.RegAccent({type='callback',fn=function() if activeHistory then Render() end end}) end
local boot=CreateFrame('Frame')
boot:RegisterEvent('PLAYER_LOGIN')
boot:SetScript('OnEvent',function(self) self:UnregisterAllEvents();NS.SyncEllesmerePressFeedback() end)
