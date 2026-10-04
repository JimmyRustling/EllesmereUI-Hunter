-- Read-only pet auras and a fixed secure pet-target button.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end
local P={};NS.PetElements=P
local DEFAULTS={auras=false,target=false,xp=false,buffs=true,debuffs=true,dispel=true,size=20,count=8,auraY=-8,targetWidth=100,targetHeight=12,targetGap=8,xpHeight=8,xpY=-8}
local limits={size={14,32},count={2,12},auraY={-80,40},targetWidth={60,180},targetHeight={8,24},targetGap={0,60},xpHeight={4,16},xpY={-60,20}}
local function Plain(v) return not (issecretvalue and issecretvalue(v)) end
local function Num(v) return Plain(v) and type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function Str(v) return Plain(v) and type(v)=='string' end
local function Tab(v) return Plain(v) and type(v)=='table' end
local function Read(fn,...)
    if type(fn)~='function' then return nil,false end
    local ok,a,b=pcall(fn,...)
    if ok and Plain(a) then return a,true,Plain(b) and b or nil end
    return nil,false
end
local function OOC() return Read(_G.InCombatLockdown)==false end
function NS.EllesmerePetElementSettings()
    if not Tab(FHKEllesmereDB) then FHKEllesmereDB={} end
    local s=FHKEllesmereDB.petElements
    if not Tab(s) then s={};FHKEllesmereDB.petElements=s end
    for k,v in pairs(DEFAULTS) do
        if type(v)=='boolean' then if not Plain(s[k]) or type(s[k])~='boolean' then s[k]=v end
        elseif not Num(s[k]) or s[k]<limits[k][1] or s[k]>limits[k][2] then s[k]=v end
    end
    s.count=math.floor(s.count)
    return s
end
local driver=CreateFrame('Frame')
local host,root,target,status,xp
local cells={}
local cfg,enabled,pending,queued,epoch=nil,false,false,false,0
local dirtyAura,dirtyTarget,dirtyXP=false,false,false
local canCleanse=false
local auraCache={}
local function Known(id)
    return Read(C_SpellBook and C_SpellBook.IsSpellKnown,id)==true or Read(_G.IsPlayerSpell,id)==true or Read(_G.IsSpellKnown,id)==true
end
local function RefreshTalent()
    -- Public ForeverDB 19572: Mend Pet can cleanse Curse/Disease/Magic/Poison.
    local id=19572
    canCleanse=Known(id)
    local name=Read(C_Spell and C_Spell.GetSpellName,id)
    local info=Str(name) and Read(C_Spell and C_Spell.GetSpellInfo,name)
    if Tab(info) and Num(info.spellID) and Known(info.spellID) then canCleanse=true end
end
local function PetAlive()
    return Read(_G.UnitExists,'pet')==true and Read(_G.UnitIsDeadOrGhost,'pet')==false
end
local cleanse={Curse=true,Disease=true,Magic=true,Poison=true}
function P.SelectAuras(getter,settings)
    local out,unknown,overflow={},false,false
    for _,filter in ipairs({'HARMFUL','HELPFUL'}) do
        local wanted=filter=='HARMFUL' and settings.debuffs or filter=='HELPFUL' and settings.buffs
        if wanted then
            for index=1,settings.count+1 do
                local aura,ok=Read(getter,'pet',index,filter)
                if not ok or aura~=nil and not Tab(aura) then unknown=true;break end
                if not aura then break end
                if #out>=settings.count then overflow=true;break end
                out[#out+1]={data=aura,harmful=filter=='HARMFUL'}
            end
        end
    end
    return out,unknown,overflow
end
local function Font(fs,size)
    local path=Read(EUI.GetFontPath,'extras');fs:SetFont(Str(path) and path or 'Fonts\\FRIZQT__.TTF',size,'OUTLINE')
end
local function Border(f)
    return Read(EUI.MakeBorder,f,0,0,0,1)
end
local function PaintBorder(border,r,g,b)
    if border and border.SetColor then border:SetColor(r,g,b,1) end
end
local function Parent()
    local p=host and Read(host.GetParent,host)
    if Plain(p) and (type(p)=='table' or type(p)=='userdata') and type(p.SetPoint)=='function' then return p end
    return host
end
local function Build()
    if not root then
        root=CreateFrame('Frame',nil,Parent());root:SetFrameStrata('MEDIUM');root:EnableMouse(false)
        status=root:CreateFontString(nil,'OVERLAY');Font(status,10);status:SetPoint('LEFT',root,'RIGHT',3,0)
    end
    for i=#cells+1,cfg.auras and cfg.count or #cells do
        local b=CreateFrame('Frame',nil,root);b:EnableMouse(false)
        b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetAllPoints(b);b.icon:SetTexCoord(.08,.92,.08,.92)
        b.border=Border(b)
        b.count=b:CreateFontString(nil,'OVERLAY');Font(b.count,10);b.count:SetPoint('BOTTOMRIGHT',b,'BOTTOMRIGHT',0,0)
        b.cooldown=CreateFrame('Cooldown',nil,b,'CooldownFrameTemplate');b.cooldown:SetAllPoints(b)
        if b.SetMouseMotionEnabled then b:SetMouseMotionEnabled(true) end
        if b.SetMouseClickEnabled then b:SetMouseClickEnabled(false) end
        b:SetScript('OnEnter',function(self)
            self.hovered=true
            if enabled and cfg.auras and self.tooltip and EUI.ShowWidgetTooltip then EUI.ShowWidgetTooltip(self,self.tooltip) end
        end)
        b:SetScript('OnLeave',function(self) self.hovered=false;if EUI.HideWidgetTooltip then EUI.HideWidgetTooltip() end end)
        cells[i]=b
    end
    if cfg.xp and not xp then
        xp=CreateFrame('StatusBar',nil,Parent());xp:SetStatusBarTexture('Interface\\Buttons\\WHITE8X8');xp:SetMinMaxValues(0,1)
        local color=NS.Colours and NS.Colours.xpFill or {.46,.18,.7};xp:SetStatusBarColor(color[1],color[2],color[3],1);xp.border=Border(xp)
        xp.text=xp:CreateFontString(nil,'OVERLAY');Font(xp.text,9);xp.text:SetPoint('CENTER',xp,'CENTER')
        -- Unspent training points (gold) and the pet's stance letter, on the bar itself.
        xp.badge=xp:CreateFontString(nil,'OVERLAY');Font(xp.badge,9);xp.badge:SetPoint('RIGHT',xp,'RIGHT',-2,0)
        xp.stance=xp:CreateFontString(nil,'OVERLAY');Font(xp.stance,9);xp.stance:SetPoint('LEFT',xp,'LEFT',2,0)
        xp:EnableMouse(false)
        if xp.SetMouseMotionEnabled then xp:SetMouseMotionEnabled(true) end
        if xp.SetMouseClickEnabled then xp:SetMouseClickEnabled(false) end
        xp:SetScript('OnEnter',function(self) if enabled and cfg.xp and self.tooltip and EUI.ShowWidgetTooltip then EUI.ShowWidgetTooltip(self,self.tooltip) end end)
        xp:SetScript('OnLeave',function() if EUI.HideWidgetTooltip then EUI.HideWidgetTooltip() end end)
    end
    if cfg.target and not target then
        target=CreateFrame('Button','FHKEllesmerePetTarget',Parent(),'SecureActionButtonTemplate')
        target:SetAttribute('type','target');target:SetAttribute('unit','pettarget');target:RegisterForClicks('AnyUp')
        target.border=Border(target)
        target.health=CreateFrame('StatusBar',nil,target);target.health:SetAllPoints(target);target.health:SetStatusBarTexture('Interface\\Buttons\\WHITE8X8')
        target.health:SetMinMaxValues(0,1);target.health:SetStatusBarColor(.25,.84,.66,1)
        target.name=target:CreateFontString(nil,'OVERLAY');Font(target.name,10);target.name:SetPoint('BOTTOMLEFT',target,'TOPLEFT',0,2)
        target.name:SetJustifyH('LEFT');target.name:SetWordWrap(false)
        target.value=target:CreateFontString(nil,'OVERLAY');Font(target.value,9);target.value:SetPoint('CENTER',target,'CENTER')
    end
end
local function Layout()
    if not host or not cfg or not OOC() then pending=true;return end
    Build()
    root:SetParent(Parent());root:ClearAllPoints();root:SetPoint('TOPLEFT',host,'BOTTOMLEFT',0,cfg.auraY)
    root:SetSize(cfg.count*(cfg.size+2)-2,cfg.size)
    for i,b in ipairs(cells) do
        b:ClearAllPoints();b:SetPoint('TOPLEFT',root,'TOPLEFT',(i-1)*(cfg.size+2),0);b:SetSize(cfg.size,cfg.size)
    end
    if target then
        target:SetParent(Parent());target:ClearAllPoints();target:SetPoint('LEFT',host,'RIGHT',cfg.targetGap,0);target:SetSize(cfg.targetWidth,cfg.targetHeight)
        target.name:SetWidth(cfg.targetWidth)
        if cfg.target and type(RegisterUnitWatch)=='function' then RegisterUnitWatch(target)
        else
            if type(UnregisterUnitWatch)=='function' then UnregisterUnitWatch(target) end
            target:Hide()
        end
    end
    if xp then
        xp:SetParent(Parent());xp:ClearAllPoints();xp:SetPoint('TOPLEFT',cfg.auras and root or host,'BOTTOMLEFT',0,cfg.xpY)
        local width=Read(host.GetWidth,host);xp:SetSize(Num(width) and width>0 and width or 160,cfg.xpHeight)
        if cfg.xp then xp:Show() else xp:Hide() end
    end
    root:Show()
end
function P.PaintAuras()
    if not root then return end
    local alive=PetAlive()
    root:SetAlpha(enabled and cfg.auras and alive and 1 or 0)
    local now=Read(_G.GetTime);now=Num(now) and now or 0
    for i,b in ipairs(cells) do
        local item=cfg.auras and alive and auraCache[i]
        b:SetAlpha(item and 1 or 0)
        if item then
            local a=item.data
            local icon=Plain(a.icon) and a.icon
            b.icon:SetTexture((Num(icon) or Str(icon)) and icon or 'Interface\\Icons\\INV_Misc_QuestionMark')
            local stacks=Num(a.applications) and a.applications>1 and tostring(a.applications) or ''
            b.count:SetText(stacks)
            local dispellable=item.harmful and cfg.dispel and canCleanse and Str(a.dispelName) and cleanse[a.dispelName]
            b.tooltip=(Str(a.name) and a.name or '?')..(dispellable and '\nMend Pet may cleanse this effect.' or '')
            if b.hovered and EUI.ShowWidgetTooltip then EUI.ShowWidgetTooltip(b,b.tooltip) end
            if dispellable then PaintBorder(b.border,1,.82,0)
            elseif item.harmful then PaintBorder(b.border,1,.3,.25)
            else PaintBorder(b.border,0,0,0) end
            if Num(a.duration) and a.duration>0 and Num(a.expirationTime) and a.expirationTime>now then
                b.cooldown:SetCooldown(a.expirationTime-a.duration,a.duration)
            else b.cooldown:Clear() end
        else
            b.tooltip=nil;b.cooldown:Clear();b.count:SetText('')
            if b.hovered and EUI.HideWidgetTooltip then EUI.HideWidgetTooltip() end
        end
    end
end
function P.RefreshAuras()
    auraCache={}
    if cfg.auras and PetAlive() then
        local unknown,overflow
        auraCache,unknown,overflow=P.SelectAuras(C_UnitAuras and C_UnitAuras.GetAuraDataByIndex,cfg)
        if unknown then auraCache={};status:SetText('?') else status:SetText(overflow and '+' or '') end
    elseif status then status:SetText('') end
    P.PaintAuras()
end
function P.PaintTarget()
    if not target then return end
    local visible=enabled and cfg.target and PetAlive() and Read(_G.UnitExists,'pettarget')==true
    target:SetAlpha(visible and 1 or 0)
    if not visible then return end
    local name=Read(_G.UnitName,'pettarget')
    target.name:SetText(Str(name) and name or '?')
    local hp,max=Read(_G.UnitHealth,'pettarget'),Read(_G.UnitHealthMax,'pettarget')
    if Num(hp) and hp>=0 and Num(max) and max>0 then
        local pct=math.max(0,math.min(1,hp/max))
        target.health:SetValue(pct);target.value:SetText(math.floor(pct*100+.5)..'%')
    else target.health:SetValue(0);target.value:SetText('?') end
end
function P.PaintXP()
    if not xp then return end
    local visible=enabled and cfg.xp and PetAlive()
    xp:SetAlpha(visible and 1 or 0)
    if not visible then xp.tooltip=nil;return end
    local cur,_,needed=Read(_G.GetPetExperience)
    local label='Pet XP: ?'
    if Num(cur) and cur>=0 and Num(needed) and needed>0 then
        xp:SetValue(math.max(0,math.min(1,cur/needed)));label='Pet XP: '..cur..' / '..needed
    elseif Num(needed) and needed==0 then xp:SetValue(1);label='Pet XP: Capped'
    else xp:SetValue(0) end
    xp.text:SetText(label)
    local loyalty=Read(C_PetInfo and C_PetInfo.GetPetLoyalty)
    local total,_,used=Read(C_PetInfo and C_PetInfo.GetPetTrainingPoints)
    local training='Training: ?'
    local free
    if Num(total) and Num(used) and used>=0 and total>=used then
        free=total-used
        training='Training: '..free..' available ('..used..' used / '..total..' total)'
    end
    if xp.badge then xp.badge:SetText(free and free>0 and ('TP '..free) or '');if xp.badge.SetTextColor then xp.badge:SetTextColor(1,.82,0) end end
    -- Pet bar: stance (Assist / Defensive / Passive) and abilities with their autocast state.
    local stance,abilities=nil,{}
    for i=1,(_G.NUM_PET_ACTION_SLOTS or 10) do
        local ok,name,_,isToken,isActive,allowed,auto=false
        if type(_G.GetPetActionInfo)=='function' then ok,name,_,isToken,isActive,allowed,auto=pcall(_G.GetPetActionInfo,i) end
        if not (ok and Plain(isToken) and Plain(isActive) and Plain(allowed) and Plain(auto)) then name=nil end
        if Str(name) then
            if isToken then
                if isActive and name:find('^PET_MODE_') then stance=name end
            elseif allowed then abilities[#abilities+1]=name..(auto and ' (auto)' or ' (auto off)')
            else abilities[#abilities+1]=name end
        end
    end
    local STANCE={PET_MODE_ASSIST={'A','Assist'},PET_MODE_AGGRESSIVE={'A','Aggressive'},PET_MODE_DEFENSIVEASSIST={'D','Defensive'},
        PET_MODE_DEFENSIVE={'D','Defensive'},PET_MODE_PASSIVE={'P','Passive'}}
    local st=stance and STANCE[stance]
    if xp.stance then
        xp.stance:SetText(st and st[1] or '')
        if xp.stance.SetTextColor then
            if stance=='PET_MODE_PASSIVE' then xp.stance:SetTextColor(1,.3,.25) else xp.stance:SetTextColor(.96,.945,.925) end
        end
    end
    xp.tooltip=label..'\nLoyalty: '..(Str(loyalty) and loyalty or '?')..'\n'..training..
        (st and ('\nStance: '..st[2]) or '')..(#abilities>0 and ('\nAbilities: '..table.concat(abilities,', ')) or '')
end
local function Flush()
    queued=false
    if not enabled or not host or not root then return end
    if dirtyAura then dirtyAura=false;P.RefreshAuras() end
    if dirtyTarget then dirtyTarget=false;P.PaintTarget() end
    if dirtyXP then dirtyXP=false;P.PaintXP() end
end
local function Queue(auras,petTarget,petXP)
    dirtyAura,dirtyTarget=dirtyAura or auras,dirtyTarget or petTarget
    dirtyXP=dirtyXP or petXP
    if queued or not enabled then return end
    queued=true;local token=epoch
    if C_Timer and C_Timer.After then C_Timer.After(.05,function() if token==epoch then Flush() end end) else Flush() end
end
local function Observe(bar)
    if bar==host then return end
    host=bar
    if OOC() then Layout();RefreshTalent();Queue(true,true,true)
    else pending=true;driver:RegisterEvent('PLAYER_REGEN_ENABLED') end
end
function P.OnEvent(_,event,unit)
    if event=='PLAYER_LOGIN' then NS.SyncEllesmerePetElements();return end
    if event=='PLAYER_REGEN_ENABLED' and pending then NS.SyncEllesmerePetElements();return end
    if not enabled then return end
    if event=='UNIT_AURA' then if unit=='pet' then Queue(true,false) end
    elseif event=='SPELLS_CHANGED' then RefreshTalent();Queue(true,false)
    elseif event=='UNIT_PET' then if unit=='player' then Queue(true,true,true) end
    elseif event=='UNIT_TARGET' then if unit=='pet' then Queue(false,true) end
    elseif event=='UNIT_FLAGS' and unit=='pet' then Queue(true,true,true)
    elseif event=='UNIT_PET_EXPERIENCE' or event=='UNIT_PET_TRAINING_POINTS' or event=='UNIT_LEVEL' or event=='PLAYER_LEVEL_UP' or event=='PET_UI_UPDATE' or event=='PET_BAR_UPDATE' then Queue(false,false,true)
    elseif event=='PLAYER_ENTERING_WORLD' then NS.SyncEllesmerePetElements()
    else Queue(false,true) end
end
function NS.SyncEllesmerePetElements()
    if not OOC() then pending=true;driver:RegisterEvent('PLAYER_REGEN_ENABLED');return end
    epoch=epoch+1;pending=false;queued=false;dirtyAura,dirtyTarget,dirtyXP=false,false,false
    driver:UnregisterAllEvents()
    local s=NS.EllesmerePetElementSettings()
    local _,_,class=Read(_G.UnitClass,'player')
    enabled=(s.auras or s.target or s.xp) and class=='HUNTER'
    if not enabled then
        NS.ObserveEllesmerePetBar=nil
        if root then root:Hide() end
        if xp then xp:Hide();xp.tooltip=nil end
        if target then
            if type(UnregisterUnitWatch)=='function' then UnregisterUnitWatch(target) end
            target:Hide()
        end
        auraCache={}
        return
    end
    cfg={};for k,v in pairs(s) do cfg[k]=v end
    NS.ObserveEllesmerePetBar=Observe
    if not host and NS.SyncEllesmereUnitRefinements then NS.SyncEllesmereUnitRefinements() end
    if host then Layout();RefreshTalent();P.RefreshAuras();P.PaintTarget();P.PaintXP() end
    driver:RegisterEvent('PLAYER_ENTERING_WORLD');driver:RegisterEvent('PLAYER_REGEN_ENABLED')
    driver:RegisterUnitEvent('UNIT_PET','player')
    if cfg.auras then driver:RegisterUnitEvent('UNIT_AURA','pet');driver:RegisterEvent('SPELLS_CHANGED') end
    if cfg.xp then
        driver:RegisterUnitEvent('UNIT_PET_EXPERIENCE','player')
        driver:RegisterUnitEvent('UNIT_PET_TRAINING_POINTS','player','pet')
        driver:RegisterUnitEvent('UNIT_LEVEL','pet')
        driver:RegisterEvent('PLAYER_LEVEL_UP');driver:RegisterEvent('PET_UI_UPDATE');driver:RegisterEvent('PET_BAR_UPDATE')
    end
    if cfg.target then
        driver:RegisterUnitEvent('UNIT_TARGET','pet')
        for _,event in ipairs({'UNIT_HEALTH','UNIT_MAXHEALTH','UNIT_NAME_UPDATE'}) do driver:RegisterUnitEvent(event,'pettarget') end
        driver:RegisterUnitEvent('UNIT_FLAGS','pet','pettarget')
    else driver:RegisterUnitEvent('UNIT_FLAGS','pet')
    end
end
function P.State() return {root=root,target=target,xp=xp,cells=cells,host=host,driver=driver,enabled=enabled,pending=pending,canCleanse=canCleanse} end
function NS.AddEllesmerePetElementOptions(Row)
    local labels={'Pet Auras','Pet Target','Pet Buffs','Pet Debuffs','Mend Pet Cleanse Edge','Pet Aura Size','Pet Aura Slots','Pet Aura Vertical Offset','Pet Target Width','Pet Target Height','Pet Target Gap','Pet XP Bar','Pet XP Height','Pet XP Vertical Offset'}
    if EUI.IsSearchPrebuild and EUI.IsSearchPrebuild() then
        for i=1,#labels,2 do Row({type='label',text=labels[i]},labels[i+1] and {type='label',text=labels[i+1]} or EUI.BlankRowCfg()) end
        return
    end
    local function Settings() return NS.EllesmerePetElementSettings() end
    local function Set(k,v)
        if limits[k] then if not Num(v) or v<limits[k][1] or v>limits[k][2] then return end
        elseif not Plain(v) or type(v)~='boolean' then return end
        Settings()[k]=v;NS.SyncEllesmerePetElements()
    end
    local function Toggle(text,k,disabled)
        return {type='toggle',text=text,getValue=function() return Settings()[k] end,setValue=function(v) Set(k,v) end,disabled=disabled,disabledTooltip='Pet Auras'}
    end
    local function Slider(text,k,disabled)
        return {type='slider',text=text,min=limits[k][1],max=limits[k][2],step=1,getValue=function() return Settings()[k] end,setValue=function(v) Set(k,v) end,disabled=disabled,disabledTooltip=k:find('target') and 'Pet Target' or k:find('xp') and 'Pet XP Bar' or 'Pet Auras'}
    end
    local function NoAuras() return not Settings().auras end
    local function NoTarget() return not Settings().target end
    local function NoXP() return not Settings().xp end
    Row(Toggle('Pet Auras','auras'),Toggle('Pet Target','target'))
    Row(Toggle('Pet Buffs','buffs',NoAuras),Toggle('Pet Debuffs','debuffs',NoAuras))
    Row(Toggle('Mend Pet Cleanse Edge','dispel',NoAuras),Slider('Pet Aura Size','size',NoAuras))
    Row(Slider('Pet Aura Slots','count',NoAuras),Slider('Pet Aura Vertical Offset','auraY',NoAuras))
    Row(Slider('Pet Target Width','targetWidth',NoTarget),Slider('Pet Target Height','targetHeight',NoTarget))
    Row(Slider('Pet Target Gap','targetGap',NoTarget),Toggle('Pet XP Bar','xp'))
    Row(Slider('Pet XP Height','xpHeight',NoXP),Slider('Pet XP Vertical Offset','xpY',NoXP))
    Row({type='label',text=host and 'Attached To Pet Frame' or 'Pet Frame Not Found'},EUI.BlankRowCfg())
end
driver:SetScript('OnEvent',P.OnEvent);driver:RegisterEvent('PLAYER_LOGIN')

