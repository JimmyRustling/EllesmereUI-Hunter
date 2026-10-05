-- Native Resource Bars keep their geometry, smoothing and visibility.
-- Extend their actual fill textures and add optional independent text slots.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end
local driver=CreateFrame('Frame')
local states=setmetatable({}, {__mode='k'})
local function Plain(v)
    return not (issecretvalue and issecretvalue(v)) and type(v)=='number' and v==v and math.abs(v)<math.huge
end
-- Constant lists: Paint runs on every player power tick, so it allocates nothing.
local POSITIONS={'left','center','right'}
local FIELDS={leftX=true,leftY=true,centerX=true,centerY=true,rightX=true,rightY=true}
local BARS={{'ERB_HealthBar','health',false},{'ERB_PrimaryBar','primary',true}}
local function Settings(key)
    if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end
    FHKEllesmereDB.resourceBarZones=FHKEllesmereDB.resourceBarZones or {}
    local zones=FHKEllesmereDB.resourceBarZones
    zones[key]=zones[key] or {enabled=false,left=key=='health' and 'curhp' or 'curpp',center='none',right=key=='health' and 'perhp' or 'perpp'}
    local s=zones[key]
    for field in pairs(FIELDS) do
        if not Plain(s[field]) then s[field]=0 end
    end
    return s
end
NS.ResourceBarZoneSettings=Settings
local function Value(key,ns)
    if key=='none' then return '' end
    local hp=key=='curhp' or key=='perhp' or key=='bothhp' or key=='perhpnum'
    local kind=NS.EllesmereResourceType and NS.EllesmereResourceType('player')
    local cur,max
    if hp then cur,max=UnitHealth('player'),UnitHealthMax('player')
    else cur,max=UnitPower('player',kind),UnitPowerMax('player',kind) end
    local amount
    if ns and ns.AbbreviateNumbers then amount=ns.AbbreviateNumbers(cur)
    else amount=string.format('%.0f',cur) end
    local pct
    if hp and UnitHealthPercent then pct=UnitHealthPercent('player',true,CurveConstants and CurveConstants.ScaleTo100)
    elseif not hp and UnitPowerPercent then pct=UnitPowerPercent('player',kind,false,CurveConstants and CurveConstants.ScaleTo100)
    elseif Plain(cur) and Plain(max) and max>0 then pct=cur/max*100
    else return amount,hp end
    if key=='curhp' or key=='curpp' then return amount,hp end
    if key=='perhp' or key=='perpp' then return string.format('%.0f%%',pct),hp end
    if key=='perhpnum' or key=='perppnum' then return string.format('%.0f%% | %s',pct,amount),hp end
    return string.format('%s | %.0f%%',amount,pct),hp
end
local function Paint()
    local ns=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIResourceBars
    for _,item in ipairs(BARS) do
        local bar=_G[item[1]]
        if bar and bar.GetStatusBarTexture and NS.RefineEllesmereBar then
            local fill=bar:GetStatusBarTexture()
            if fill then NS.RefineEllesmereBar(fill,'player',item[3],true,'resourcebars',item[2]) end
            local cfg=Settings(item[2])
            local state=states[bar]
            if not state and cfg.enabled then
                state={}; states[bar]=state
                for _,position in ipairs(POSITIONS) do
                    local text=bar:CreateFontString(nil,'OVERLAY')
                    text:SetPoint(position:upper(),bar,position:upper(),position=='left' and 5 or position=='right' and -5 or 0,0)
                    text:SetJustifyH(position:upper())
                    state[position]=text
                end
                if bar._text then hooksecurefunc(bar._text,'SetAlpha',function(self,alpha)
                    if Settings(item[2]).enabled and not state.painting and
                        ((issecretvalue and issecretvalue(alpha)) or alpha~=0) then
                        state.painting=true; self:SetAlpha(0); state.painting=nil
                    end
                end) end
            end
            if state then
                if bar._text then bar._text:SetAlpha(cfg.enabled and 0 or 1) end
                local font,size,flags
                if bar._text then font,size,flags=bar._text:GetFont() end
                for _,position in ipairs(POSITIONS) do
                    local text=state[position]
                    text:SetShown(cfg.enabled)
                    if cfg.enabled then
                        local x,y=cfg[position..'X'],cfg[position..'Y']
                        if state[position..'X']~=x or state[position..'Y']~=y then
                            local inset=position=='left' and 5 or position=='right' and -5 or 0
                            text:ClearAllPoints()
                            text:SetPoint(position:upper(),bar,position:upper(),inset+x,y)
                            state[position..'X'],state[position..'Y']=x,y
                        end
                        if state.font~=font or state.size~=size or state.flags~=flags then
                            if EUI.ApplyModuleFont then EUI.ApplyModuleFont(text,nil,size or 11,'resourceBars')
                            else text:SetFont(font or EUI.EXPRESSWAY or 'Fonts\\FRIZQT__.TTF',size or 11,flags or '') end
                            if NS.ApplyEllesmereCueText then NS.ApplyEllesmereCueText(text,'bar') end
                        end
                        local value,health=Value(cfg[position],ns)
                        -- Formatting and setters accept secret values. Never compare the formatted result.
                        if issecretvalue and issecretvalue(value) then text:SetText(value)
                        elseif state[position..'Value']~=value then text:SetText(value); state[position..'Value']=value end
                        if health and NS.PaintEllesmereHealthText then NS.PaintEllesmereHealthText(text,'player','resourcebars','health')
                        else
                            local color=NS.EllesmereResourceColor('player')
                            if color then text:SetTextColor(color[1],color[2],color[3],1) end
                        end
                    end
                end
                state.font,state.size,state.flags=font,size,flags
            end
        end
    end
end
NS.PaintEllesmereResourceBars=Paint
function NS.AddEllesmereResourceTextCog(row,kind,position)
    if not row or not row._leftRegion or not EUI.BuildInlineCog then return end
    local s=Settings(kind)
    local title=(kind=='health' and 'Health Bar ' or 'Resource Bar ')..position:gsub('^%l',string.upper)
    local function Axis(axis)
        return {type='slider',label=axis..' Offset',min=-500,max=500,step=1,
            get=function() return s[position..axis] end,
            set=function(v) s[position..axis]=v;Paint() end}
    end
    EUI.BuildInlineCog(row._leftRegion,{title=title..' Position',icon=EUI.DIRECTIONS_ICON,gap=9,
        disabled=function() return not s.enabled or s[position]=='none' end,
        disabledTooltip='Enable Text Slots And Choose A Visible Value',rows={Axis('X'),Axis('Y')}})
end
for _,event in ipairs({'PLAYER_LOGIN','ADDON_LOADED','UPDATE_SHAPESHIFT_FORM'}) do driver:RegisterEvent(event) end
-- Player only: health and power events from every nameplate used to wake this up.
for _,event in ipairs({'UNIT_HEALTH','UNIT_MAXHEALTH','UNIT_POWER_UPDATE','UNIT_POWER_FREQUENT','UNIT_MAXPOWER','UNIT_DISPLAYPOWER'}) do
    if driver.RegisterUnitEvent then driver:RegisterUnitEvent(event,'player') else driver:RegisterEvent(event) end
end
driver:SetScript('OnEvent',function(_,event,unit) if not event:find('^UNIT_') or unit=='player' then Paint() end end)
local elapsed=0
-- Player health/power events repaint at once; the sweep only catches settings changes (audit F35).
driver:SetScript('OnUpdate',function(_,dt)
    elapsed=elapsed+dt
    if elapsed<(NS.EllesmereSweepInterval and NS.EllesmereSweepInterval() or .15) then return end
    elapsed=0; Paint()
end)
