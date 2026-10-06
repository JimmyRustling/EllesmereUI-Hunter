-- Ease world cues and resolve enemy nameplate opacity by interaction priority.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end

local states=setmetatable({},{__mode='k'})
local animations=setmetatable({},{__mode='k'})
local guides=setmetatable({},{__mode='k'})
local verdicts={}
local function Public(v) return not (issecretvalue and issecretvalue(v)) end
local function Number(v)
    return Public(v) and type(v)=='number' and v==v and v>-math.huge and v<math.huge
end
local function Enabled() return FHKEllesmereDB and FHKEllesmereDB.cueFades==true end
local function Identity(unit)
    local guid=unit and UnitGUID and UnitGUID(unit)
    return Public(guid) and guid or unit
end
function NS.ResetEllesmereCueAlpha(region)
    local s=states[region]
    if not s then return end
    if s.group then s.group:Stop() end
    states[region]=nil
    region:SetAlpha(s.base)
end
local function WriteAlpha(region,s,alpha)
    s.writing=true;region:SetAlpha(alpha);s.writing=false
end
function NS.SetEllesmereCueAlpha(region,unit,alpha)
    if not region or not Number(alpha) then return end
    alpha=math.max(0,math.min(1,alpha))
    if not Enabled() then
        NS.ResetEllesmereCueAlpha(region)
        region:SetAlpha(alpha)
        return
    end
    local key=Identity(unit)
    local s=states[region]
    if not s then
        local base=region:GetAlpha()
        s=animations[region] or {}
        s.base=Number(base) and base or 1
        s.key,s.target,s.running,s.factor=nil,nil,false,nil
        states[region]=s
        if not s.group then
            local group=region:CreateAnimationGroup()
            local anim=group:CreateAnimation('Alpha')
            anim:SetDuration(.23);anim:SetSmoothing('OUT');group:SetToFinalAlpha(true)
            group:SetScript('OnFinished',function()
                if states[region]~=s then return end
                s.running=false;WriteAlpha(region,s,s.target)
            end)
            s.group,s.anim=group,anim
            animations[region]=s
            hooksecurefunc(region,'SetAlpha',function(_,value)
                if states[region]~=s or s.writing then return end
                if not Number(value) then
                    s.group:Stop();s.running=false;states[region]=nil;return
                end
                -- Native settings remain the base opacity while our fade is active.
                s.base=value
                if s.factor then
                    s.group:Stop();s.running=false;s.target=value*s.factor
                    WriteAlpha(region,s,s.target)
                end
            end)
        end
    end
    if s.key and s.key~=key then
        s.group:Stop();s.running=false;s.target=alpha;s.key=key;WriteAlpha(region,s,alpha)
        return
    end
    if NS.EllesmereReduceMotion and NS.EllesmereReduceMotion() then
        s.group:Stop();s.running=false;s.target=alpha;s.key=key;WriteAlpha(region,s,alpha);return
    end
    if s.target==alpha then return end
    local from=s.target or s.base
    if s.running then
        local ok,p=pcall(s.anim.GetSmoothProgress,s.anim)
        if ok and Number(p) then from=s.from+(s.target-s.from)*math.max(0,math.min(1,p)) end
    end
    s.group:Stop()
    s.key,s.from,s.target,s.running=key,from,alpha,true
    WriteAlpha(region,s,from)
    s.anim:SetFromAlpha(from);s.anim:SetToAlpha(alpha);s.group:Play()
end
function NS.RegisterEllesmereGuideCue(region,plate,unit)
    if region then
        local cue=guides[region] or {};guides[region]=cue
        cue.plate,cue.unit=plate,unit
    end
end
local function Beyond(unit)
    local hit=verdicts[unit]
    if hit~=nil then return hit==1 end
    local fn=EUI.Range_SweepBeyond or EUI.Range_IsBeyondAttackRange
    if not fn then return end
    local ok,result=pcall(fn,unit)
    result=ok and Public(result) and result==true
    verdicts[unit]=result and 1 or 0
    return result
end
local function Visible(region)
    if not region then return false end
    if region.IsVisible then return region:IsVisible() end
    local parent=region.GetParent and region:GetParent()
    return region:IsShown() and (not parent or parent:IsShown())
end
local function Marker(region,unit,beyond)
    if not region then return end
    if not Visible(region) then NS.ResetEllesmereCueAlpha(region);return end
    local value=FHKEllesmereDB and FHKEllesmereDB.cueOutAlpha
    if not Number(value) then value=.28 end
    local s=states[region]
    local base=s and s.base or region:GetAlpha()
    if not Number(base) then return end
    local factor=beyond and math.max(0,math.min(1,value)) or 1
    NS.SetEllesmereCueAlpha(region,unit,base*factor)
    states[region].factor=factor
end
function NS.UpdateEllesmereMarkerFades()
    if not Enabled() then return end
    for unit in pairs(verdicts) do verdicts[unit]=nil end
    local np=_G.EllesmereNameplates_NS
    for _,plate in pairs(np and np.plates or {}) do
        if plate.unit and plate:IsShown() then
            local beyond
            if Visible(plate._euiRarityBadge) or Visible(plate.raid) or Visible(plate.nameRaid) then beyond=Beyond(plate.unit) end
            Marker(plate._euiRarityBadge,plate.unit,beyond)
            Marker(plate.raid,plate.unit,beyond)
            Marker(plate.nameRaid,plate.unit,beyond)
        else
            NS.ResetEllesmereCueAlpha(plate._euiRarityBadge)
            NS.ResetEllesmereCueAlpha(plate.raid)
            NS.ResetEllesmereCueAlpha(plate.nameRaid)
        end
    end
    for region,cue in pairs(guides) do
        if cue.plate and cue.plate:IsShown() and cue.plate.unit==cue.unit and Visible(region) then
            Marker(region,cue.unit,Beyond(cue.unit))
        else NS.ResetEllesmereCueAlpha(region) end
    end
end

-- enabled has no stored default (suite review SF-4): Opacity Priority replaces Ellesmere's
-- Non-Target and Out-of-Range opacity, so it is on by itself only on the owner's install
-- (publishing rule). A value the player chose is kept (chosen=true marks it).
local opacityDefaults={target=1,focus=.85,mouseover=.75,idle=.55,out=.25}
local opacityOrder={'target','focus','mouseover'}
local opacityFrame,opacityNative,opacityHover
local function Owner()
    if NS.EllesmerePersonalSetup then return NS.EllesmerePersonalSetup()==true end
    return _G.ForeverHunterKeysNS~=nil
end
local function OpacityEnabled()
    if type(FHKEllesmereDB)~='table' then return false end
    local s=FHKEllesmereDB.nameplateOpacity
    local on=type(s)=='table' and s.enabled
    if type(on)=='boolean' and (on==false or s.chosen==true or Owner()) then return on end
    return Owner()
end
NS.EllesmereNameplateOpacityEnabled=OpacityEnabled
function NS.EllesmereNameplateOpacitySettings()
    if type(FHKEllesmereDB)~='table' then return opacityDefaults end
    local s=FHKEllesmereDB.nameplateOpacity
    if type(s)~='table' then s={};FHKEllesmereDB.nameplateOpacity=s end
    for key,value in pairs(opacityDefaults) do if s[key]==nil then s[key]=value end end
    -- Earlier versions stored enabled=true as the default for everyone: on a published
    -- install that unchosen value goes back to following Ellesmere.
    if s.enabled==true and s.chosen~=true and not Owner() then s.enabled=nil end
    if s.enabled~=nil and type(s.enabled)~='boolean' then s.enabled=nil end
    return s
end
local function Flag(fn,...)
    if not fn then return end
    local ok,value=pcall(fn,...)
    if ok and Public(value) and type(value)=='boolean' then return value end
end
local function OpacityValue(key)
    local s=FHKEllesmereDB and FHKEllesmereDB.nameplateOpacity
    local value=s and s[key]
    return Number(value) and math.max(0,math.min(1,value)) or opacityDefaults[key]
end
local function Priority(plate,reading)
    local unit=plate.unit
    for _,key in ipairs(opacityOrder) do
        local match=Flag(UnitIsUnit,unit,key)
        if match==true then return OpacityValue(key),key end
        -- An unreadable selection flag must not hide an important plate.
        if match==nil then return 1,'unavailable' end
    end
    local attackable=Flag(UnitCanAttack,'player',unit)
    local deceased=Flag(UnitIsDead,unit)
    if attackable==false or deceased==true then return end
    if attackable==nil or deceased==nil then return 1,'unavailable' end
    local np=_G.EllesmereNameplates_NS
    local p=np and np.db and np.db.profile
    local beyond
    if p and p.outOfRangeMode=='custom' and EUI.Range_SweepBeyond and EUI.Range_GetAttackCutoff then
        -- An explicit native distance still wins over the class-range preset.
        local cutoff=EUI.Range_GetAttackCutoff(p.outOfRangeCustomRange)
        beyond=Flag(EUI.Range_SweepBeyond,unit,cutoff)
    else
        reading=reading or (NS.GetEllesmereRangeSample and NS.GetEllesmereRangeSample(unit))
        local state=reading and Public(reading) and reading.state
        if Public(state) then beyond=state=='far' or state=='close' or state=='out' end
    end
    local key=beyond==true and 'out' or 'idle'
    return OpacityValue(key),key
end
function NS.ApplyEllesmereNameplateOpacity(plate,reading)
    if not opacityNative or not OpacityEnabled() or not plate or not plate.unit then return false end
    -- The player's own Ellesmere Non-Target Opacity wins while it is set (SF-4).
    local np=_G.EllesmereNameplates_NS
    local nt=np and np._ntAlpha
    if Number(nt) and nt<1 then
        if plate._fhkOpacityState then plate._fhkOpacityState=nil;plate._ntCurAlpha=-1 end
        return false
    end
    local alpha,key=Priority(plate,reading)
    if alpha==nil then return false end
    -- Ellesmere's Out-of-Range fade multiplies idle plates instead of our own out bucket.
    local oor=plate._oorCurAlpha
    if (key=='idle' or key=='out') and Number(oor) and np and Number(np._oorAlpha) and np._oorAlpha<1 then
        alpha,key=OpacityValue('idle')*oor,'native range'
    end
    local current=plate:GetAlpha()
    if not Number(current) then return true end
    plate._fhkOpacityState=key
    -- The native pool reset uses this cache to restore released plates to 100%.
    plate._ntCurAlpha=alpha
    if current~=alpha then plate:SetAlpha(alpha) end
    return true
end
local function ApplyOpacityAll()
    local np=_G.EllesmereNameplates_NS
    if not OpacityEnabled() then return end
    for _,plate in pairs(np and np.plates or {}) do
        if not NS.ApplyEllesmereNameplateOpacity(plate) and opacityNative then opacityNative(plate) end
    end
end
function NS.SyncEllesmereNameplateOpacity()
    local np=_G.EllesmereNameplates_NS
    local on=OpacityEnabled() and np and type(np.NT_Apply)=='function'
    if EUI.Range_SetActive then EUI.Range_SetActive('fhkNameplateOpacity',on==true) end
    if on then
        NS.EllesmereNameplateOpacitySettings()
        if not opacityNative then
            opacityNative=np.NT_Apply
            np.NT_Apply=function(plate)
                if not NS.ApplyEllesmereNameplateOpacity(plate) then return opacityNative(plate) end
            end
            if np._UpdateMouseover then hooksecurefunc(np,'_UpdateMouseover',function()
                if not OpacityEnabled() then return end
                local previous,current=opacityHover,np._currentMouseoverPlate
                opacityHover=current
                if previous and previous.unit then np.NT_Apply(previous) end
                if current and current~=previous then np.NT_Apply(current) end
            end) end
        end
        if not opacityFrame then
            opacityFrame=CreateFrame('Frame')
            opacityFrame:SetScript('OnEvent',function(_,event,unit)
                if event=='NAME_PLATE_UNIT_ADDED' then
                    -- Paint now when the plate is already registered, so it never shows at
                    -- full opacity for a frame; otherwise right after native registration.
                    if np.plates and np.plates[unit] then np.NT_Apply(np.plates[unit])
                    else C_Timer.After(0,function()
                        if OpacityEnabled() and np.plates and np.plates[unit] then np.NT_Apply(np.plates[unit]) end
                    end) end
                else ApplyOpacityAll() end
            end)
        end
        for _,event in ipairs({'PLAYER_TARGET_CHANGED','PLAYER_FOCUS_CHANGED','PLAYER_ENTERING_WORLD','NAME_PLATE_UNIT_ADDED'}) do
            opacityFrame:RegisterEvent(event)
        end
        ApplyOpacityAll()
    else
        opacityHover=nil
        if opacityFrame then opacityFrame:UnregisterAllEvents() end
        if opacityNative then
            for _,plate in pairs(np and np.plates or {}) do
                if plate._fhkOpacityState then
                    plate._fhkOpacityState=nil
                    plate._ntCurAlpha=-1
                    opacityNative(plate)
                end
            end
        end
    end
end
function NS.AddEllesmereNameplateOpacityOptions(Row)
    Row({type='toggle',text='Nameplate Opacity Priority',
        tooltip='Target, focus and mouseover stay readable even outside attack range. Idle plates use class attack range, or your native Custom range. Ellesmere Non-Target Opacity, when set below 100%, and its Out-of-Range fade still apply.',
        getValue=function() return OpacityEnabled() end,
        setValue=function(v) local s=NS.EllesmereNameplateOpacitySettings();s.enabled=v==true;s.chosen=true;NS.SyncEllesmereNameplateOpacity() end},
        {type='label',text='100% = fully visible; 0% = invisible'})
    local function Slider(text,key)
        return {type='slider',text=text..' Opacity %',min=0,max=100,step=5,
            disabled=function() return not OpacityEnabled() end,disabledTooltip='Enable Nameplate Opacity Priority',
            getValue=function() return OpacityValue(key)*100 end,
            setValue=function(v) NS.EllesmereNameplateOpacitySettings()[key]=v/100;NS.SyncEllesmereNameplateOpacity() end}
    end
    Row(Slider('Target','target'),Slider('Focus','focus'))
    Row(Slider('Mouseover','mouseover'),Slider('In Range Idle','idle'))
    Row(Slider('Out of Range Idle','out'),{type='label',text='Target > focus > mouseover > range'})
end

-- Read-only explanation of the actual opacity layers on a hovered or selected plate.
function NS.ExplainEllesmereOpacity(unit)
    unit=unit or 'mouseover'
    local np=_G.EllesmereNameplates_NS
    local plate=np and np.plates and np.plates[unit]
    if not plate and np then
        for _,candidate in pairs(np.plates or {}) do
            local same=UnitIsUnit(candidate.unit,unit)
            if Public(same) and same==true then plate=candidate;break end
        end
    end
    if not plate then print('FHK opacity: hover an enemy nameplate, or use /fhkopacity target.');return end
    local function Percent(v) return Number(v) and string.format('%.0f%%',v*100) or 'unavailable' end
    local function Value(v) return Public(v) and tostring(v) or 'restricted' end
    local p=np.db and np.db.profile or {}
    local parent=plate:GetParent()
    print('FHK opacity: '..Value(plate.unit)..' | plate '..Percent(plate:GetAlpha())..
        ' | game parent '..Percent(parent and parent:GetAlpha())..
        ' | effective '..Percent(plate.GetEffectiveAlpha and plate:GetEffectiveAlpha()))
    print('Native range: '..Value(p.outOfRangeMode or 'disabled')..' | multiplier '..Percent(plate._oorCurAlpha or 1)..
        ' | non-target '..Percent(np._ntAlpha or 1)..' | no target '..Percent(np._ntNoTarget or 1))
    print('Opacity priority: '..(OpacityEnabled() and 'on' or 'off')..' | state '..Value(plate._fhkOpacityState or 'native'))
    local reading=NS.GetEllesmereRangeSample and NS.GetEllesmereRangeSample(plate.unit)
    if reading then print('Hunter range: '..Value(reading.state)..' | '..Value(reading.bracket)) end
    print('Marker fade: '..(Enabled() and 'on' or 'off')..' | extra out-of-range opacity '..
        Percent(FHKEllesmereDB and FHKEllesmereDB.cueOutAlpha or .28))
end
SLASH_FHKOPACITY1='/fhkopacity'
SlashCmdList.FHKOPACITY=function(input)
    local unit=tostring(input or ''):lower():match('^%s*(%S*)')
    NS.ExplainEllesmereOpacity(unit~='' and unit or 'mouseover')
end
function NS.SyncEllesmereCueFades()
    if EUI.Range_SetActive then EUI.Range_SetActive('fhkCueFades',Enabled()) end
    if not Enabled() then
        for region in pairs(states) do NS.ResetEllesmereCueAlpha(region) end
    else
        if NS.EllesmereReduceMotion and NS.EllesmereReduceMotion() then
            for region,s in pairs(states) do
                if s.running and Number(s.target) then
                    s.group:Stop();s.running=false;WriteAlpha(region,s,s.target)
                end
            end
        end
        NS.UpdateEllesmereMarkerFades()
    end
end
local boot=CreateFrame('Frame')
boot:RegisterEvent('PLAYER_LOGIN')
boot:SetScript('OnEvent',function(self) self:UnregisterAllEvents();NS.SyncEllesmereCueFades() end)
