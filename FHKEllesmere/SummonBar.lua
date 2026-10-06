-- Pets And Summons bar (player, 2026-10-06: "a pet summon bar ... warlocks can maybe have an
-- available/summoned pet bar and a click on that bar allows you to summon that pet, similar to
-- the hunter aspect bar"). Research (FEATURE_REVIEW_2026-10-06.md section B): Forever hunters
-- have one pet out (PetConsts_Camelot MAX_SUMMONABLE_HUNTER_PETS = 1) plus the stable, so the
-- hunter bar is the pet's own controls and Summon Hawk; warlocks get one button per learned
-- demon. Shamans keep Ellesmere's native Call Totem Bar. Secure buttons; layout out of combat.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end
local S={}
NS.SummonBar=S
local DEFAULTS={enabled=false,size=30,spacing=4,orientation='horizontal',visibility='always',hawk=true,eyes=false,
    extras=false,felDom=true,dim=true,keysHint=true}
local CHOICES={orientation={horizontal=true,vertical=true},visibility={always=true,combat=true,mouseover=true,missing=true}}
local LIMITS={size={20,48},spacing={0,12}}
local POINTS={CENTER=true,TOP=true,BOTTOM=true,LEFT=true,RIGHT=true,TOPLEFT=true,TOPRIGHT=true,BOTTOMLEFT=true,BOTTOMRIGHT=true}
local function Plain(v) return not (issecretvalue and issecretvalue(v)) end
local function Number(v) return Plain(v) and type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function Text(v) return Plain(v) and type(v)=='string' and v~='' end
local function Table(v) return Plain(v) and type(v)=='table' end
local function Read(fn,...)
    if type(fn)~='function' then return end
    local ok,a,b,c,d=pcall(fn,...)
    if ok and Plain(a) then return a,Plain(b) and b or nil,Plain(c) and c or nil,Plain(d) and d or nil end
end
local function Yes(v) return Plain(v) and v==true end
local function OutsideCombat() local v=Read(_G.InCombatLockdown);return Plain(v) and v==false end
local function Now() local n=Read(_G.GetTime);return Number(n) and n or 0 end
local function Known(id)
    if not Number(id) then return false end
    return Yes(Read(C_SpellBook and C_SpellBook.IsSpellKnown,id)) or Yes(Read(_G.IsPlayerSpell,id)) or Yes(Read(_G.IsSpellKnown,id))
end
local function SpellName(id)
    local n=Read(C_Spell and C_Spell.GetSpellName,id)
    if not Text(n) then n=Read(_G.GetSpellInfo,id) end
    return Text(n) and n or nil
end
local function SpellIcon(id) local t=Read(C_Spell and C_Spell.GetSpellTexture,id);return (Number(t) or Text(t)) and t or nil end
function NS.EllesmereSummonSettings()
    if not Table(FHKEllesmereDB) then FHKEllesmereDB={} end
    local s=FHKEllesmereDB.summonBar
    if not Table(s) then s={};FHKEllesmereDB.summonBar=s end
    for k,v in pairs(DEFAULTS) do
        local x=s[k]
        if type(v)=='boolean' then if not Plain(x) or type(x)~='boolean' then s[k]=v end
        elseif LIMITS[k] then if not Number(x) or x<LIMITS[k][1] or x>LIMITS[k][2] then s[k]=v end
        elseif CHOICES[k] then if not Text(x) or not CHOICES[k][x] then s[k]=v end end
    end
    return s
end

-------------------------------------------------------------------------------
-- Providers: per class, the buttons (pure data, testable).
-------------------------------------------------------------------------------
local CALL,REVIVE,DISMISS,MEND,EYES=883,982,2641,136,1002
S.HAWK_IDS={1293241,1293525,1293526,1293527}
local LONE_WOLF=415370
-- Warlock demons in trainer order; Incubus is Forever's (WarlockTomes data).
S.DEMONS={{key='imp',id=688,family='Imp',free=true},{key='voidwalker',id=697,family='Voidwalker'},
    {key='succubus',id=712,family='Succubus'},{key='incubus',id=713,family='Incubus'},{key='felhunter',id=691,family='Felhunter'}}
-- reagent: the item the spell consumes (Infernal Stone, Demonic Figurine, a Soul Shard), SCENARIO_REVIEW S51.
S.WARLOCK_EXTRAS={{key='infernal',id=1122,reagent=5565},{key='doom',id=18540,reagent=16583},{key='enslave',id=1098,reagent=6265}}
local FEL_DOMINATION,SOUL_SHARD=18708,6265
local function Class() local _,c=Read(_G.UnitClass,'player');return c end
S.Class=Class
function S.Entries(class,s)
    s=s or NS.EllesmereSummonSettings()
    local out={}
    if class=='HUNTER' then
        local call,revive,mend,dismiss=SpellName(CALL),SpellName(REVIVE),SpellName(MEND),SpellName(DISMISS)
        if Known(CALL) or Known(REVIVE) then
            -- One smart pet button: revive the dead pet, call a missing one, else Mend Pet.
            local parts={}
            if revive and Known(REVIVE) then parts[#parts+1]='[@pet,dead] '..revive end
            if call and Known(CALL) then parts[#parts+1]='[nopet] '..call end
            if mend and Known(MEND) then parts[#parts+1]=mend end
            out[#out+1]={key='pet',kind='pet',macro='/cast '..table.concat(parts,'; '),
                right=Known(REVIVE) and revive or nil,shift=Known(DISMISS) and dismiss or nil,icon=SpellIcon(CALL),
                tip='Left: Revive / Call / Mend Pet. Right: Revive Pet. Shift: Dismiss Pet.'}
        end
        if s.hawk then
            for _,id in ipairs(S.HAWK_IDS) do
                if Known(id) then out[#out+1]={key='hawk',kind='hawk',spell=SpellName(id) or SpellName(S.HAWK_IDS[1]),icon=SpellIcon(id),tip='Summon Hawk: up to two hawks for 18 seconds.'};break end
            end
        end
        if s.eyes and Known(EYES) then out[#out+1]={key='eyes',kind='spell',spell=SpellName(EYES),icon=SpellIcon(EYES)} end
    elseif class=='WARLOCK' then
        local fel=s.felDom and Known(FEL_DOMINATION) and SpellName(FEL_DOMINATION)
        for _,d in ipairs(S.DEMONS) do
            if Known(d.id) then
                local name=SpellName(d.id)
                if name then out[#out+1]={key=d.key,kind='demon',family=d.family,free=d.free,spell=name,icon=SpellIcon(d.id),
                    rightMacro=fel and ('/cast '..fel..'\n/cast '..name) or nil,
                    tip=fel and 'Left: summon. Right: Fel Domination, then summon.' or 'Summons this demon.'} end
            end
        end
        if s.extras then
            for _,d in ipairs(S.WARLOCK_EXTRAS) do
                if Known(d.id) then local name=SpellName(d.id);if name then out[#out+1]={key=d.key,kind='spell',spell=name,icon=SpellIcon(d.id),reagent=d.reagent} end end
            end
        end
    end
    return out
end

-------------------------------------------------------------------------------
-- Frames.
-------------------------------------------------------------------------------
local holder
local buttons,entries={},{}
local driver=CreateFrame('Frame')
local pending,enabled,cfg=false,false,nil
local hawks={} -- expiry times, newest last
local lastDemon
local function Font(fs,size)
    local path=Read(EUI.GetFontPath,'extras')
    fs:SetFont(Text(path) and path or 'Fonts\\FRIZQT__.TTF',size,'OUTLINE')
end
local function Color(key)
    local c=cfg and Table(cfg.colors) and cfg.colors[key]
    if Table(c) and Number(c[1]) and Number(c[2]) and Number(c[3]) then return c[1],c[2],c[3] end
    local C=NS.Colours or {}
    c=key=='alive' and (C.happy or {.30,.85,.30}) or key=='dead' and (C.danger or {1,.3,.25}) or key=='missing' and (C.caution or {1,.78,.2})
        or key=='hawk' and (C.shoot or {.25,.84,.66}) or key=='active' and (C.happy or {.30,.85,.30}) or {.6,.6,.6}
    return c[1],c[2],c[3]
end
S.Color=function(key) return Color(key) end
local function SetBorder(border,r,g,b,a) if border and type(border.SetColor)=='function' then border:SetColor(r,g,b,a) end end
local function Position()
    if not holder or not OutsideCombat() then pending=true;return end
    local p=NS.EllesmereSummonSettings().position
    local valid=Table(p) and Text(p.point) and POINTS[p.point] and Text(p.relPoint) and POINTS[p.relPoint] and Number(p.x) and Number(p.y)
    holder:ClearAllPoints()
    holder:SetPoint(valid and p.point or 'CENTER',UIParent,valid and p.relPoint or 'CENTER',valid and p.x or -260,valid and p.y or -200)
end
local function Hover(frame)
    frame:HookScript('OnEnter',function() if cfg and cfg.visibility=='mouseover' and holder then holder:SetAlpha(1) end end)
    frame:HookScript('OnLeave',function()
        if cfg and cfg.visibility=='mouseover' and holder and not holder:IsMouseOver() then holder:SetAlpha(0) end
    end)
end
local function Build()
    if holder then return end
    holder=CreateFrame('Frame','FHKEllesmereSummons',UIParent,'SecureHandlerStateTemplate')
    holder:SetSize(30,30);holder:SetFrameStrata('MEDIUM');holder:EnableMouse(true);Hover(holder)
    if EUI.MakeUnlockElement and EUI.RegisterUnlockElements then
        EUI:RegisterUnlockElements({EUI.MakeUnlockElement({key='FHKEllesmereSummons',label='Pets And Summons',group='Unit Frames',order=621,noResize=true,
            getFrame=function() return holder end,getSize=function() return holder:GetWidth(),holder:GetHeight() end,
            isHidden=function() return not enabled end,
            savePos=function(_,point,relPoint,x,y) if Text(point) and POINTS[point] and Text(relPoint) and POINTS[relPoint] and Number(x) and Number(y) then NS.EllesmereSummonSettings().position={point=point,relPoint=relPoint,x=x,y=y};Position() end end,
            loadPos=function() return NS.EllesmereSummonSettings().position end,
            clearPos=function() NS.EllesmereSummonSettings().position=nil;Position() end,applyPos=Position
        })},'FHKEllesmere')
    end
end
local function Button(i)
    if buttons[i] then return buttons[i] end
    local b=CreateFrame('Button','FHKEllesmereSummonButton'..i,holder,'SecureActionButtonTemplate')
    b:RegisterForClicks('AnyUp')
    b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetAllPoints(b);b.icon:SetTexCoord(.08,.92,.08,.92)
    b.border=Read(EUI.MakeBorder,b,0,0,0,1)
    b.count=b:CreateFontString(nil,'OVERLAY');Font(b.count,11);b.count:SetPoint('BOTTOMRIGHT',b,'BOTTOMRIGHT',-1,2)
    b.cooldown=CreateFrame('Cooldown',nil,b,'CooldownFrameTemplate');b.cooldown:SetAllPoints(b)
    b:HookScript('OnEnter',function(self)
        if self.entry and self.entry.tip and GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText(self.entry.tip,1,1,1,1,true);GameTooltip:Show() end
    end)
    b:HookScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
    Hover(b)
    buttons[i]=b
    return b
end
local function Attributes(b,e)
    for _,k in ipairs({'type','spell','macrotext','type2','spell2','macrotext2','shift-type1','shift-spell1'}) do b:SetAttribute(k,nil) end
    if e.macro then b:SetAttribute('type','macro');b:SetAttribute('macrotext',e.macro)
    else b:SetAttribute('type','spell');b:SetAttribute('spell',e.spell) end
    if e.right then b:SetAttribute('type2','spell');b:SetAttribute('spell2',e.right) end
    if e.rightMacro then b:SetAttribute('type2','macro');b:SetAttribute('macrotext2',e.rightMacro) end
    if e.shift then b:SetAttribute('shift-type1','spell');b:SetAttribute('shift-spell1',e.shift) end
end
local function VisibilityDriver()
    local v=cfg.visibility
    if v=='combat' then return '[combat] show; hide' end
    -- When Pet Missing: a Lone Wolf hunter plays without a pet on purpose.
    if v=='missing' then
        local T=NS.HunterTalents
        if Class()=='HUNTER' and (Known(LONE_WOLF) or T and T.Has and T.Has('loneWolf')) then return 'hide' end
        return '[nopet] show; [@pet,dead] show; hide'
    end
    return 'show'
end
function S.Layout()
    if not holder or not cfg or not OutsideCombat() then pending=true;return end
    pending=false
    entries=S.Entries(Class(),cfg)
    local size,gap=cfg.size,cfg.spacing
    for i,e in ipairs(entries) do
        local b=Button(i);b.entry=e;Attributes(b,e)
        b:SetSize(size,size);b.icon:SetTexture(e.icon)
        b:ClearAllPoints()
        b:SetPoint('TOPLEFT',holder,'TOPLEFT',cfg.orientation=='horizontal' and (i-1)*(size+gap) or 0,cfg.orientation=='vertical' and -(i-1)*(size+gap) or 0)
        b:Show()
    end
    for i=#entries+1,#buttons do buttons[i].entry=nil;buttons[i]:Hide() end
    local long=math.max(1,#entries)*size+math.max(0,#entries-1)*gap
    holder:SetSize(cfg.orientation=='horizontal' and long or size,cfg.orientation=='vertical' and long or size)
    if type(RegisterStateDriver)=='function' then RegisterStateDriver(holder,'visibility',#entries>0 and VisibilityDriver() or 'hide')
    else holder:SetShown(#entries>0) end
    holder:SetAlpha(cfg.visibility=='mouseover' and 0 or 1)
    Position()
    S.Paint()
end
-- Pet state from public reads: alive, dead or missing (absent pets cannot tell dismissed from dead).
function S.PetState()
    if Yes(Read(_G.UnitExists,'pet')) then return Yes(Read(_G.UnitIsDead,'pet')) and 'dead' or 'alive' end
    return 'missing'
end
function S.HawkCount(now)
    now=now or Now()
    local n=0
    for i=#hawks,1,-1 do if hawks[i]<=now then table.remove(hawks,i) else n=n+1 end end
    return n,hawks[1]
end
function S.Paint()
    if not enabled or not holder or not cfg then return end
    local now=Now()
    local petState=S.PetState()
    local family=petState=='alive' and Read(_G.UnitCreatureFamily,'pet') or nil
    local shards=Read(C_Item and C_Item.GetItemCount or _G.GetItemCount,SOUL_SHARD)
    for _,b in ipairs(buttons) do
        local e=b.entry
        if e and b:IsShown() then
            local r,g,bl,a,alpha=.25,.25,.28,1,1
            local count=''
            if e.kind=='pet' then
                r,g,bl=Color(petState)
                if petState=='alive' and type(SetPortraitTexture)=='function' then pcall(SetPortraitTexture,b.icon,'pet')
                else b.icon:SetTexture(petState=='dead' and SpellIcon(REVIVE) or e.icon) end
            elseif e.kind=='hawk' then
                local n=S.HawkCount(now)
                count=n>0 and tostring(n) or ''
                if n>0 then r,g,bl=Color('hawk') end
            elseif e.kind=='demon' then
                -- The pet's family decides; the last summon cast is the fallback when it cannot be read.
                local active
                if Text(family) then active=family==e.family else active=lastDemon==e.key and petState~='missing' end
                if active then r,g,bl=Color('active') end
                if cfg.dim and not active then alpha=.55 end
                -- No Soul Shard: a demon that needs one cannot be summoned (the one out stays bright).
                if not active and not e.free and Number(shards) and shards<1 then alpha=.3 end
            elseif e.kind=='spell' and e.reagent then
                -- Without its reagent the spell cannot be cast: dim it, the same as a demon without a shard.
                local n=e.reagent==SOUL_SHARD and shards or Read(C_Item and C_Item.GetItemCount or _G.GetItemCount,e.reagent)
                if Number(n) and n<1 then alpha=.3 end
            end
            SetBorder(b.border,r,g,bl,a);b:SetAlpha(alpha);b.count:SetText(count)
        end
    end
end
-- Preview (eye): the bar shows for a few seconds wherever it is.
local previewUntil
function NS.PreviewEllesmereSummons()
    if not holder then return end
    previewUntil=Now()+3
    if OutsideCombat() then holder:Show();holder:SetAlpha(1) end
    if C_Timer and C_Timer.After then C_Timer.After(3.1,function() if OutsideCombat() then S.Layout() end end) end
end
local ticker
local function Ticker(on)
    if on and not ticker and C_Timer and C_Timer.NewTicker then ticker=C_Timer.NewTicker(.5,function()
        S.Paint()
        if S.HawkCount()==0 and ticker then ticker:Cancel();ticker=nil end
    end) elseif not on and ticker then ticker:Cancel();ticker=nil end
end
local HAWK={};for _,id in ipairs(S.HAWK_IDS) do HAWK[id]=true end
local DEMON_BY_ID={};for _,d in ipairs(S.DEMONS) do DEMON_BY_ID[d.id]=d.key end
function S.OnEvent(_,event,unit,_,spellID)
    if event=='PLAYER_REGEN_ENABLED' then if pending then S.Layout() end;return end
    if event=='UNIT_SPELLCAST_SUCCEEDED' then
        if unit~='player' or not Number(spellID) then return end
        if HAWK[spellID] then
            -- Two hawks at most: a third replaces the oldest (to confirm in game).
            hawks[#hawks+1]=Now()+18
            while #hawks>2 do table.remove(hawks,1) end
            Ticker(true)
        elseif DEMON_BY_ID[spellID] then lastDemon=DEMON_BY_ID[spellID] end
        S.Paint();return
    end
    if event=='SPELLS_CHANGED' or event=='PLAYER_ENTERING_WORLD' or event=='LEARNED_SPELL_IN_TAB' then S.Layout();return end
    if event=='UNIT_PET' and unit=='player' and not Yes(Read(_G.UnitExists,'pet')) then lastDemon=nil end
    S.Paint()
end
driver:SetScript('OnEvent',S.OnEvent)
function S.State() return {holder=holder,buttons=buttons,entries=entries,enabled=enabled,pending=pending} end
function NS.SyncEllesmereSummons()
    cfg=NS.EllesmereSummonSettings()
    local class=Class()
    enabled=cfg.enabled==true and (class=='HUNTER' or class=='WARLOCK')
    driver:UnregisterAllEvents()
    if not enabled then
        Ticker(false)
        if holder and OutsideCombat() then
            if type(UnregisterStateDriver)=='function' then UnregisterStateDriver(holder,'visibility') end
            holder:Hide()
        elseif holder then pending=true;driver:RegisterEvent('PLAYER_REGEN_ENABLED') end
        return
    end
    Build()
    for _,event in ipairs({'PLAYER_REGEN_ENABLED','SPELLS_CHANGED','PLAYER_ENTERING_WORLD','BAG_UPDATE_DELAYED'}) do driver:RegisterEvent(event) end
    if driver.RegisterUnitEvent then
        driver:RegisterUnitEvent('UNIT_PET','player');driver:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED','player')
        driver:RegisterUnitEvent('UNIT_HEALTH','pet');driver:RegisterUnitEvent('UNIT_FLAGS','pet')
    end
    S.Layout()
end

-------------------------------------------------------------------------------
-- Options: Unit Frames > PETS AND SUMMONS.
-------------------------------------------------------------------------------
function NS.AddEllesmereSummonOptions(Row)
    local class=Class()
    if class~='HUNTER' and class~='WARLOCK' then return end
    if EUI.IsSearchPrebuild and EUI.IsSearchPrebuild() then
        Row({type='label',text='Pets And Summons Bar'},{type='label',text='Summon Bar Visibility'})
        return
    end
    local function Settings() return NS.EllesmereSummonSettings() end
    local function Off() return not Settings().enabled end
    local function Set(k,v)
        if LIMITS[k] then if not Number(v) or v<LIMITS[k][1] or v>LIMITS[k][2] then return end
        elseif CHOICES[k] then if not Text(v) or not CHOICES[k][v] then return end
        elseif type(DEFAULTS[k])=='boolean' then if not Plain(v) or type(v)~='boolean' then return end end
        Settings()[k]=v;NS.SyncEllesmereSummons()
    end
    local function Swatch(key,text)
        return {tooltip=text,hasAlpha=false,getValue=function()
            local saved=cfg;cfg=Settings();local r,g,b=Color(key);cfg=saved;return r,g,b,1
        end,setValue=function(r,g,b)
            if not Number(r) or not Number(g) or not Number(b) then return end
            local s=Settings();s.colors=Table(s.colors) and s.colors or {};s.colors[key]={r,g,b};S.Paint()
        end}
    end
    local hunter=class=='HUNTER'
    local bar={type='toggle',text='Pets And Summons Bar',
        tooltip=hunter and 'One pet button (left: revive, call or Mend Pet; right: Revive; Shift: Dismiss) and Summon Hawk with its hawk count. Forever hunters have one pet out; the others wait at the Stable Master.'
            or 'One button per demon you know: click to summon. Right click casts Fel Domination first when you know it. The demon that is out is highlighted; demons are dimmed without a Soul Shard.',
        getValue=function() return Settings().enabled end,setValue=function(v) Set('enabled',v) end}
    bar.swatches=hunter and {Swatch('alive','Pet Alive Color'),Swatch('dead','Pet Dead Color'),Swatch('missing','Pet Missing Color'),Swatch('hawk','Hawks Up Color')}
        or {Swatch('active','Active Demon Color')}
    bar.preview={tip='Preview the bar',show=NS.PreviewEllesmereSummons,duration=3,disabled=Off,disabledTooltip='Pets And Summons Bar'}
    bar.cog={title='Summon Bar Layout',disabled=Off,disabledTooltip='Pets And Summons Bar',rows={
        {type='slider',label='Icon Size',min=20,max=48,step=1,get=function() return Settings().size end,set=function(v) Set('size',v) end},
        {type='slider',label='Spacing',min=0,max=12,step=1,get=function() return Settings().spacing end,set=function(v) Set('spacing',v) end},
        {type='dropdown',label='Orientation',values={horizontal='Horizontal',vertical='Vertical'},order={'horizontal','vertical'},
            get=function() return Settings().orientation end,set=function(v) Set('orientation',v) end}}}
    Row(bar,{type='dropdown',text='Summon Bar Visibility',values={always='Always',combat='In Combat',mouseover='Mouseover',missing='When Pet Missing'},
        order={'always','combat','mouseover','missing'},disabled=Off,disabledTooltip='Pets And Summons Bar',
        tooltip='When Pet Missing shows the bar only while your pet is dead or not out (never for a Lone Wolf hunter).',
        getValue=function() return Settings().visibility end,setValue=function(v) Set('visibility',v) end})
    if hunter then
        Row({type='toggle',text='Summon Hawk Button',tooltip='With the Summon Hawk talent: its button shows how many hawks are out (two at most, 18 seconds each).',
            disabled=Off,disabledTooltip='Pets And Summons Bar',getValue=function() return Settings().hawk end,setValue=function(v) Set('hawk',v) end},
            {type='toggle',text='Eyes Of The Beast Button',disabled=Off,disabledTooltip='Pets And Summons Bar',
            getValue=function() return Settings().eyes end,setValue=function(v) Set('eyes',v) end})
    else
        Row({type='toggle',text='Right Click: Fel Domination',tooltip='Right click casts Fel Domination, then the summon, when you know Fel Domination.',
            disabled=Off,disabledTooltip='Pets And Summons Bar',getValue=function() return Settings().felDom end,setValue=function(v) Set('felDom',v) end},
            {type='toggle',text='Infernal, Ritual And Enslave',tooltip='Adds Inferno, Ritual of Doom and Enslave Demon when you know them.',
            disabled=Off,disabledTooltip='Pets And Summons Bar',getValue=function() return Settings().extras end,setValue=function(v) Set('extras',v) end})
        Row({type='toggle',text='Dim Inactive Demons',disabled=Off,disabledTooltip='Pets And Summons Bar',
            getValue=function() return Settings().dim end,setValue=function(v) Set('dim',v) end},EUI.BlankRowCfg and EUI.BlankRowCfg() or {type='label',text=''})
    end
    Row({type='label',text='Move the bar in Unlock Mode: Pets And Summons'},
        {type='button',text='Reset Summon Bar Colors',onClick=function() Settings().colors=nil;S.Paint() end})
end

local boot=CreateFrame('Frame')
boot:RegisterEvent('PLAYER_LOGIN')
boot:SetScript('OnEvent',function(self) self:UnregisterAllEvents();NS.SyncEllesmereSummons() end)
