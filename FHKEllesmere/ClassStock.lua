-- Class Supplies (build plan row C, CLASS_KITS engine E3, 2026-10-06): a compact strip of the
-- class's reagents and made items with their bag counts, colored when low or gone, warning-lane
-- cues (out of combat by default) and secure click-to-create for warlock stones and mage
-- conjures. Only spells you know add an icon; a class with no supplies gets no frames, events or
-- option rows. Data (E1): Forever client tables, build 1.60.1.70205 (SpellReagents, SpellEffect
-- create-item, SpellName/NameSubtext): every spell and item ID below was checked there.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end
local S={}
NS.ClassStock=S
local DEFAULTS={enabled=false,size=28,spacing=3,orientation='horizontal',visibility='always',counts=true,dim=true,
    cues='auto',sound='none',shardLow=3,conjuredLow=6,soulTimer=true,bagWarn=true}
local CHOICES={orientation={horizontal=true,vertical=true},visibility={always=true,combat=true,nocombat=true,mouseover=true,low=true},
    cues={off=true,auto=true,ooc=true,rest=true,always=true},sound={none=true,raid=true,alarm=true,ready=true,tick=true}}
local LIMITS={size={18,48},spacing={0,12},shardLow={0,32},conjuredLow={0,40}}
local LOW_LIMIT={0,40}
local POINTS={CENTER=true,TOP=true,BOTTOM=true,LEFT=true,RIGHT=true,TOPLEFT=true,TOPRIGHT=true,BOTTOMLEFT=true,BOTTOMRIGHT=true}
local function Plain(v) return not (issecretvalue and issecretvalue(v)) end
local function Number(v) return Plain(v) and type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function Text(v) return Plain(v) and type(v)=='string' and v~='' end
local function Table(v) return Plain(v) and type(v)=='table' end
local function Read(fn,...)
    if type(fn)~='function' then return end
    local ok,a,b=pcall(fn,...)
    if ok and Plain(a) then return a,Plain(b) and b or nil end
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
    return Text(n) and n or nil
end
-- A rank Forever added that is not listed here: the name gives the highest learned rank.
local function KnownByName(id)
    local name=SpellName(id)
    if not name then return false end
    local info=Read(C_Spell and C_Spell.GetSpellInfo,name)
    return Table(info) and Number(info.spellID) and Known(info.spellID) or false
end

-------------------------------------------------------------------------------
-- Data: per class, in strip order. ranks = {spell, item} low to high (the item that rank makes
-- or uses); gate = spells that make the entry relevant; extra = more items that count; all =
-- count every rank's item (else only the highest known rank's); create = click casts the
-- highest known rank ('missing' = the highest whose item is not in the bags); group = which
-- threshold applies (stone and tool: warn only when none is left); def = per-item default.
-- Vendor Restock (Restock.lua, scenario review section 9): keep = the count the engine buys to
-- (only bought supplies have one; made items are never bought), buy = its per-reagent default,
-- oneTime = bought once, never again (Thieves' Tools). low is shared by the cue and the engine.
-------------------------------------------------------------------------------
S.SOUL_SHARD=6265
S.KITS={
    WARLOCK={
        {key='shards',label='Soul Shards',items={6265},group='shard',def=true,
            gate={1120,8288,8289,11675,697,1322007,691,712,6201,693,698,2362,6366,17877}},
        {key='healthstone',label='Healthstone',group='stone',def=true,all=true,create=true,
            ranks={{6201,5512},{6202,5511},{5699,5509},{11729,5510},{11730,9421}},
            extra={19004,19005,19006,19007,19008,19009,19010,19011,19012,19013}},
        {key='soulstone',label='Soulstone',group='stone',def=true,all=true,create=true,
            ranks={{693,5232},{20752,16892},{20755,16893},{20756,16895},{20757,16896}}},
        {key='spellstone',label='Spellstone',group='stone',def=false,all=true,create=true,equip=true,
            ranks={{2362,5522},{17727,13602},{17728,13603}}},
        {key='firestone',label='Firestone',group='stone',def=false,all=true,create=true,equip=true,
            ranks={{6366,1254},{17951,13699},{17952,13700},{17953,13701}}},
        {key='infernalStone',label='Infernal Stone',items={5565},gate={1122},group='reagent',def=false,low=1,keep=1,buy=false},
        {key='figurine',label='Demonic Figurine',items={16583},gate={18540},group='reagent',def=false,low=1,keep=1,buy=false},
    },
    SHAMAN={
        {key='ankh',label='Ankh',items={17030},gate={20608},group='reagent',def=true,low=1,keep=2,buy=true},
        {key='fishOil',label='Fish Oil',items={17058},gate={546},group='reagent',def=false,low=1,keep=5,buy=false},
        {key='fishScales',label='Shiny Fish Scales',items={17057},gate={131},group='reagent',def=false,low=1,keep=5,buy=false},
    },
    ROGUE={
        {key='flashPowder',label='Flash Powder',items={5140},gate={1856,1857,1285372},group='reagent',def=true,low=3,keep=10,buy=true},
        {key='blindingPowder',label='Blinding Powder',items={5530},gate={2094},group='reagent',def=true,low=2,keep=5,buy=true},
        {key='thievesTools',label="Thieves' Tools",items={5060},gate={1804},group='tool',def=false,keep=1,buy=false,oneTime=true},
        {key='thistleTea',label='Thistle Tea',items={7676},group='tool',def=false},
    },
    MAGE={
        {key='water',label='Conjured Water',group='conjured',def=true,all=true,create=true,
            ranks={{5504,5350},{5505,2288},{5506,2136},{6127,3772},{10138,8077},{10139,8078},{10140,8079},{468766,231778}}},
        {key='food',label='Conjured Food',group='conjured',def=true,all=true,create=true,
            ranks={{587,5349},{597,1113},{990,1114},{6129,1487},{10144,8075},{10145,8076},{28612,22895}}},
        {key='manaGem',label='Mana Gem',group='stone',def=true,all=true,create='missing',
            ranks={{759,5514},{3552,5513},{10053,8007},{10054,8008}}},
        {key='teleportRune',label='Rune of Teleportation',items={17031},gate={3561,3562,3563,3565,3566,3567,1297659},group='reagent',def=true,low=2,keep=5,buy=true},
        {key='portalRune',label='Rune of Portals',items={17032},gate={10059,11416,11417,11418,11419,11420},group='reagent',def=false,low=2,keep=5,buy=false},
        {key='mageFeather',label='Light Feather',items={17056},gate={130},group='reagent',def=false,low=3,keep=10,buy=false},
        {key='arcanePowder',label='Arcane Powder',items={17020},gate={23028},group='reagent',def=true,low=5,keep=20,buy=true},
    },
    PALADIN={
        {key='divinity',label='Symbol of Divinity',items={17033},gate={19752},group='reagent',def=false,low=1,keep=1,buy=false},
        {key='kings',label='Symbol of Kings',items={21177},gate={25782,25890,25894,25895,25898,25916,25918},group='reagent',def=true,low=10,keep=40,buy=true},
    },
    PRIEST={
        -- Prayer of Fortitude 1 takes Holy Candles; rank 2, Spirit and Shadow Protection take Sacred.
        {key='candles',label='Candles',group='reagent',def=true,low=5,ranks={{21562,17028},{27683,17029},{27681,17029},{21564,17029}},keep=20,buy=true},
        {key='priestFeather',label='Light Feather',items={17056},gate={1706},group='reagent',def=false,low=2,keep=5,buy=false},
    },
    DRUID={
        -- Rebirth rank N takes exactly seed N.
        {key='seeds',label='Rebirth Seeds',group='reagent',def=true,low=1,ranks={{20484,17034},{20739,17035},{20742,17036},{20747,17037},{20748,17038}},keep=2,buy=true},
        {key='giftHerbs',label='Gift of the Wild Herbs',group='reagent',def=true,low=3,ranks={{21849,17021},{21850,17026}},keep=10,buy=true},
    },
}
S.SOULSTONE_RES={[20707]=true,[20762]=true,[20763]=true,[20764]=true,[20765]=true}
S.SOULSTONE_SECONDS=1800
local ITEM_DEFAULTS={}
for _,kit in pairs(S.KITS) do for _,e in ipairs(kit) do ITEM_DEFAULTS[e.key]=e.def end end
S.ITEM_DEFAULTS=ITEM_DEFAULTS

function NS.EllesmereClassStockSettings()
    if not Table(FHKEllesmereDB) then FHKEllesmereDB={} end
    local s=FHKEllesmereDB.classStock
    if not Table(s) then s={};FHKEllesmereDB.classStock=s end
    for k,v in pairs(DEFAULTS) do
        local x=s[k]
        if type(v)=='boolean' then if not Plain(x) or type(x)~='boolean' then s[k]=v end
        elseif LIMITS[k] then if not Number(x) or x<LIMITS[k][1] or x>LIMITS[k][2] then s[k]=v end
        elseif CHOICES[k] then if not Text(x) or not CHOICES[k][x] then s[k]=v end end
    end
    if not Table(s.items) then s.items={} end
    for k,v in pairs(ITEM_DEFAULTS) do local x=s.items[k];if not Plain(x) or type(x)~='boolean' then s.items[k]=v end end
    -- Per-item Warn Below (S22): unset keeps the item's own default.
    if not Table(s.lows) then s.lows={} end
    for k,v in pairs(s.lows) do if ITEM_DEFAULTS[k]==nil or not Number(v) or v<LOW_LIMIT[1] or v>LOW_LIMIT[2] then s.lows[k]=nil end end
    if s.colors~=nil and not Table(s.colors) then s.colors=nil end
    if s.position~=nil and not Table(s.position) then s.position=nil end
    return s
end
local function Class() local _,c=Read(_G.UnitClass,'player');return c end
S.Class=Class
function S.HasKit(class) return class~=nil and S.KITS[class]~=nil end

-------------------------------------------------------------------------------
-- Resolve (on spell changes) and count (on bag changes): pure, testable.
-------------------------------------------------------------------------------
local function ItemCount(id)
    local fn=C_Item and C_Item.GetItemCount or _G.GetItemCount
    local n=Read(fn,id)
    if Number(n) then return n end
end
local function Equipped(id)
    local fn=C_Item and C_Item.IsEquippedItem or _G.IsEquippedItem
    return Yes(Read(fn,id))
end
-- One resolved entry: what to count, which item to show, what a click casts.
function S.Resolve(e)
    local top,topItem
    if e.ranks then
        for i=#e.ranks,1,-1 do if Known(e.ranks[i][1]) then top=i;break end end
        if not top and KnownByName(e.ranks[1][1]) then top=#e.ranks end
        if not top then return nil end
        topItem=e.ranks[top][2]
    elseif e.gate then
        local ok=false
        for _,id in ipairs(e.gate) do if Known(id) then ok=true;break end end
        if not ok then ok=KnownByName(e.gate[1]) end
        if not ok then return nil end
    end
    local r={entry=e,key=e.key,group=e.group,item=topItem or (e.items and e.items[1]),count=nil,state='unknown'}
    local list={}
    if e.items then for _,id in ipairs(e.items) do list[#list+1]=id end end
    if e.ranks then
        -- A higher rank made by another player counts too.
        if e.all then for i=1,#e.ranks do list[#list+1]=e.ranks[i][2] end
        else list[#list+1]=topItem end
    end
    if e.extra then for _,id in ipairs(e.extra) do list[#list+1]=id end end
    r.countItems=list
    if e.create and e.ranks then
        r.knownRanks={}
        for i=1,top do if Known(e.ranks[i][1]) then r.knownRanks[#r.knownRanks+1]=e.ranks[i] end end
        if #r.knownRanks==0 then r.knownRanks[1]=e.ranks[top] end
    end
    return r
end
function S.Entries(class,s)
    s=s or NS.EllesmereClassStockSettings()
    local out={}
    local kit=class and S.KITS[class]
    if not kit then return out end
    for _,e in ipairs(kit) do
        if s.items[e.key] then local r=S.Resolve(e);if r then out[#out+1]=r end end
    end
    return out
end
-- Warn below this count. Reagents: per item (S22: four Ankhs are plenty, ten Symbols of Kings
-- are not); shards and conjures: the group slider; stones and tools: only when none is left.
function S.Threshold(group,s,e)
    s=s or NS.EllesmereClassStockSettings()
    if group=='shard' then return s.shardLow
    elseif group=='reagent' then local v=e and Table(s.lows) and s.lows[e.key];return Number(v) and v or (e and e.low) or 1
    elseif group=='conjured' then return s.conjuredLow end
    return 1
end
-- Count, state (ok / low / none / unknown) and the create spell for one resolved entry.
function S.Count(r,s)
    local n=0
    for _,id in ipairs(r.countItems) do
        local c=ItemCount(id)
        if not c then r.count,r.state=nil,'unknown';return r end
        n=n+c
    end
    if r.entry.equip and n==0 then for _,id in ipairs(r.countItems) do if Equipped(id) then n=1;break end end end
    r.count=n
    local low=S.Threshold(r.group,s,r.entry)
    r.state=n==0 and 'none' or n<low and 'low' or 'ok'
    if r.knownRanks then
        local pick=r.knownRanks[#r.knownRanks]
        if r.entry.create=='missing' then
            for i=#r.knownRanks,1,-1 do local c=ItemCount(r.knownRanks[i][2]);if c==0 then pick=r.knownRanks[i];break end end
        end
        r.create=SpellName(pick[1]) or pick[1]
        if r.entry.create=='missing' then r.item=pick[2] end
    end
    return r
end
-- Bag room for shards (bag family bit 4 = soul bags): 'soul' when the soul bags are full,
-- 'full' when no bag can take a new shard, nil otherwise or when unreadable.
function S.BagState()
    local C=C_Container
    if not (C and C.GetContainerNumFreeSlots) then return nil end
    local soulBag,soulFree,normalFree=false,0,0
    for bag=0,(Number(_G.NUM_BAG_SLOTS) and _G.NUM_BAG_SLOTS or 4) do
        local free,family=Read(C.GetContainerNumFreeSlots,bag)
        if not Number(free) then return nil end
        family=Number(family) and family or 0
        if math.floor(family/4)%2==1 then soulBag=true;soulFree=soulFree+free
        elseif family==0 then normalFree=normalFree+free end
    end
    if soulFree==0 and normalFree==0 then return 'full' end
    if soulBag and soulFree==0 then return 'soul' end
    return nil
end

-------------------------------------------------------------------------------
-- Frames.
-------------------------------------------------------------------------------
local holder
local buttons,active,shown,activeByKey={},{},{},{}
local driver=CreateFrame('Frame')
local pending,enabled,cfg,class=false,false,nil,nil
local bagState
local resting,atVendor=false,false
local soldHere -- item ID set of the open vendor (nil: unknown or none)
local restUntil=0 -- Smart: bought-reagent cues show for 10 s after entering rest (S23)
local soul -- {expires, target}
local previewUntil=0
local laneShown,lastState={},{}
local Flush
local function Font(fs,size)
    local path=Read(EUI.GetFontPath,'extras')
    fs:SetFont(Text(path) and path or 'Fonts\\FRIZQT__.TTF',size,'OUTLINE')
end
local function Color(key)
    local c=cfg and Table(cfg.colors) and cfg.colors[key]
    if Table(c) and Number(c[1]) and Number(c[2]) and Number(c[3]) then return c[1],c[2],c[3] end
    local C=NS.Colours or {}
    c=key=='low' and (C.caution or {1,.82,0}) or key=='none' and (C.danger or {1,.3,.25}) or key=='full' and (C.worry or {1,.5,.25})
        or key=='timer' and (C.happy or {.30,.85,.30}) or (C.text or {.96,.945,.925})
    return c[1],c[2],c[3]
end
S.Color=function(key) return Color(key) end
local function SetBorder(border,r,g,b,a) if border and type(border.SetColor)=='function' then border:SetColor(r,g,b,a) end end
local itemNames={}
local function ItemName(r)
    -- Only rank-matched reagents (seeds, candles, herbs) name the item; the rest keep their label.
    if not (r.entry.ranks and not r.entry.all) then return r.entry.label end
    local id=r.item
    if id and itemNames[id] then return itemNames[id] end
    local n=id and Read(C_Item and C_Item.GetItemNameByID,id)
    if Text(n) then itemNames[id]=n;return n end
    return r.entry.label
end
local function Position()
    if not holder or not OutsideCombat() then pending=true;return end
    local p=NS.EllesmereClassStockSettings().position
    local valid=Table(p) and Text(p.point) and POINTS[p.point] and Text(p.relPoint) and POINTS[p.relPoint] and Number(p.x) and Number(p.y)
    holder:ClearAllPoints()
    holder:SetPoint(valid and p.point or 'CENTER',UIParent,valid and p.relPoint or 'CENTER',valid and p.x or 260,valid and p.y or -200)
end
local function Hover(frame)
    frame:HookScript('OnEnter',function() if cfg and cfg.visibility=='mouseover' and holder then holder:SetAlpha(1) end end)
    frame:HookScript('OnLeave',function()
        if cfg and cfg.visibility=='mouseover' and holder and not holder:IsMouseOver() and Now()>=previewUntil then holder:SetAlpha(0) end
    end)
end
local function Build()
    if holder then return end
    holder=CreateFrame('Frame','FHKEllesmereClassStock',UIParent,'SecureHandlerStateTemplate')
    holder:SetSize(28,28);holder:SetFrameStrata('MEDIUM');holder:EnableMouse(true);Hover(holder)
    if EUI.MakeUnlockElement and EUI.RegisterUnlockElements then
        EUI:RegisterUnlockElements({EUI.MakeUnlockElement({key='FHKEllesmereClassStock',label='Class Supplies',group='Quality of Life',order=623,noResize=true,
            getFrame=function() return holder end,getSize=function() return holder:GetWidth(),holder:GetHeight() end,
            isHidden=function() return not enabled end,
            savePos=function(_,point,relPoint,x,y) if Text(point) and POINTS[point] and Text(relPoint) and POINTS[relPoint] and Number(x) and Number(y) then NS.EllesmereClassStockSettings().position={point=point,relPoint=relPoint,x=x,y=y};Position() end end,
            loadPos=function() return NS.EllesmereClassStockSettings().position end,
            clearPos=function() NS.EllesmereClassStockSettings().position=nil;Position() end,applyPos=Position
        })},'FHKEllesmere')
    end
end
local function Tooltip(self)
    local r=self.entry
    if not r or not GameTooltip then return end
    GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
    if r.item and type(GameTooltip.SetItemByID)=='function' then pcall(GameTooltip.SetItemByID,GameTooltip,r.item)
    else GameTooltip:SetText(r.entry.label,1,1,1,1,true) end
    if r.create and OutsideCombat() then GameTooltip:AddLine('Click: '..tostring(r.create),.6,.8,1) end
    if r.key=='soulstone' and soul and soul.expires>Now() then
        GameTooltip:AddLine(('Soulstone on %s: %d min'):format(soul.target or 'someone',math.ceil((soul.expires-Now())/60)),Color('timer'))
    end
    GameTooltip:Show()
end
local function Button(i)
    if buttons[i] then return buttons[i] end
    local b=CreateFrame('Button','FHKEllesmereClassStockButton'..i,holder,'SecureActionButtonTemplate')
    b:RegisterForClicks('AnyUp')
    b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetAllPoints(b);b.icon:SetTexCoord(.08,.92,.08,.92)
    b.border=Read(EUI.MakeBorder,b,0,0,0,1)
    b.count=b:CreateFontString(nil,'OVERLAY');Font(b.count,11);b.count:SetPoint('BOTTOMRIGHT',b,'BOTTOMRIGHT',-1,2)
    b.timer=b:CreateFontString(nil,'OVERLAY');Font(b.timer,10);b.timer:SetPoint('TOP',b,'TOP',0,-2)
    b:HookScript('OnEnter',Tooltip)
    b:HookScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
    Hover(b)
    buttons[i]=b
    return b
end
local function Attributes(b,r)
    local want=r and r.create or nil
    if b.castAttr==want and b.castSet then return end
    if want then b:SetAttribute('type','spell');b:SetAttribute('spell',want)
    else b:SetAttribute('type',nil);b:SetAttribute('spell',nil) end
    b.castAttr,b.castSet=want,true
end
local function VisibilityDriver()
    local v=cfg.visibility
    if v=='combat' then return '[combat] show; hide' end
    if v=='nocombat' then return '[combat] hide; show' end
    return 'show'
end
-- Which resolved entries get an icon: all, or with Only When Low those not ok (preview: all).
local function Showing()
    local out={}
    local all=cfg.visibility~='low' or Now()<previewUntil
    for _,r in ipairs(active) do if all or r.state=='low' or r.state=='none' then out[#out+1]=r end end
    return out
end
local function Signature(list)
    local t={}
    for i,r in ipairs(list) do t[i]=r.key..'='..tostring(r.create) end
    return table.concat(t,';')
end
local laidOut
function S.Layout()
    if not holder or not cfg then pending=true;return end
    -- Secure buttons: new icons, sizes and click spells wait for combat to end; counts still paint.
    if not OutsideCombat() then pending=true;S.Paint();return end
    pending=false
    shown=Showing()
    laidOut=Signature(shown)
    local size,gap=cfg.size,cfg.spacing
    for i,r in ipairs(shown) do
        local b=Button(i);b.entry=r;Attributes(b,r)
        b:SetSize(size,size)
        b:ClearAllPoints()
        b:SetPoint('TOPLEFT',holder,'TOPLEFT',cfg.orientation=='horizontal' and (i-1)*(size+gap) or 0,cfg.orientation=='vertical' and -(i-1)*(size+gap) or 0)
        b:Show()
    end
    for i=#shown+1,#buttons do buttons[i].entry=nil;Attributes(buttons[i],nil);buttons[i]:Hide() end
    local long=math.max(1,#shown)*size+math.max(0,#shown-1)*gap
    holder:SetSize(cfg.orientation=='horizontal' and long or size,cfg.orientation=='vertical' and long or size)
    if type(RegisterStateDriver)=='function' then RegisterStateDriver(holder,'visibility',#shown>0 and VisibilityDriver() or 'hide')
    else holder:SetShown(#shown>0) end
    holder:SetAlpha((cfg.visibility=='mouseover' and Now()>=previewUntil) and 0 or 1)
    Position()
    S.Paint()
end
local function TimerText(left)
    if left>=60 then return math.ceil(left/60)..'m' end
    return math.max(0,math.floor(left))..'s'
end
function S.Paint()
    if not enabled or not holder or not cfg then return end
    local now=Now()
    for _,b in ipairs(buttons) do
        -- Spells learned in combat: the button keeps its old entry, the count comes from the new one.
        local r=b.entry and activeByKey[b.entry.key] or b.entry
        if r and b:IsShown() then
            local icon=r.item and Read(C_Item and C_Item.GetItemIconByID,r.item)
            if b.iconID~=icon then b.iconID=icon;b.icon:SetTexture(icon) end
            local st=r.state
            local edge=(st=='low' or st=='none') and st or nil
            -- Soul Shards: no room for new shards colors the edge too (red when no bag has room).
            if not edge and r.key=='shards' and bagState then edge=bagState=='full' and 'none' or 'full' end
            local br,bg,bb=.25,.25,.28
            if edge then br,bg,bb=Color(edge) end
            SetBorder(b.border,br,bg,bb,1)
            local tr,tg,tb=Color((st=='low' or st=='none') and st or 'ok')
            if type(b.count.SetTextColor)=='function' then b.count:SetTextColor(tr,tg,tb,1) end
            b.count:SetText(cfg.counts and (r.count and tostring(r.count) or '?') or '')
            if type(b.icon.SetDesaturated)=='function' then b.icon:SetDesaturated(cfg.dim and st=='none') end
            local timer=''
            if r.key=='soulstone' and soul and soul.expires>now then
                timer=TimerText(soul.expires-now)
                if type(b.timer.SetTextColor)=='function' then b.timer:SetTextColor(Color('timer')) end
            end
            b.timer:SetText(timer)
        end
    end
end

-------------------------------------------------------------------------------
-- Warning-lane cues.
-------------------------------------------------------------------------------
local function InCombat() return not OutsideCombat() end
-- Smart (default, lead review 2026-10-06): a bought reagent warns only where it can be bought
-- (resting or at a vendor), so a rogue without Flash Powder is not nagged across the zone; what
-- the player makes or farms (stones, conjures, shards) warns whenever out of combat.
local function Bought(group) return group=='reagent' or group=='tool' end
-- Does the open vendor sell this supply? (S23: "No Flash Powder" at the armorer helps nobody.)
local function SoldHere(r)
    if not soldHere or not r then return false end
    for _,id in ipairs(r.countItems or {}) do if soldHere[id] then return true end end
    return false
end
S.SoldHere=SoldHere
function S.CueWindow(group,r)
    if not cfg or cfg.cues=='off' then return false end
    -- Never while the player cannot act: dead, on a taxi or in a vehicle; made items also while mounted (S2, S25).
    if NS.EllesmereAway and NS.EllesmereAway(Bought(group) and 'bought' or 'made') then return false end
    if cfg.cues=='always' then return true end
    if InCombat() then return false end
    if cfg.cues=='rest' then return resting or atVendor end
    if cfg.cues=='auto' and Bought(group) then
        if atVendor then return r==nil or SoldHere(r) end
        return resting and Now()<restUntil
    end
    return true
end
local function Lane(key,text,colourKey,sound)
    if not NS.ShowEllesmereWarning then return end
    local r,g,b=Color(colourKey)
    NS.ShowEllesmereWarning(key,text,{r,g,b},true,false,sound)
    laneShown[key]=true
end
local function Unlane(key)
    if laneShown[key] then laneShown[key]=nil;if NS.HideEllesmereWarning then NS.HideEllesmereWarning(key) end end
end
local function HideAllCues() for key in pairs(laneShown) do Unlane(key) end end
S.HideAllCues=HideAllCues
function S.Cues()
    if not enabled or not cfg then HideAllCues();return end
    local want={}
    local shardsOut=false
    for _,r in ipairs(active) do if r.key=='shards' and r.state=='none' then shardsOut=true end end
    local blocked={}
    for _,r in ipairs(active) do
        local key='classStock_'..r.key
        local buyHere=cfg.cues=='auto' and atVendor and Bought(r.group) and SoldHere(r)
        -- Vendor Restock buys it here instead: no cue at this vendor (scenario review 12.8).
        local engineBuys=atVendor and Bought(r.group) and SoldHere(r) and NS.EllesmereRestockBuys and NS.EllesmereRestockBuys(r.key)
        -- No shard: a stone cannot be made, so one shard line names them instead (S24).
        if engineBuys then -- the engine restocks it; the bag update clears the state
        elseif shardsOut and r.entry.create and r.state=='none' and (r.key=='healthstone' or r.key=='soulstone' or r.key=='spellstone' or r.key=='firestone') then
            blocked[#blocked+1]=r.entry.label
        elseif buyHere and (r.state=='none' or r.state=='low') then want[key]={'Buy '..ItemName(r)..' here ('..r.count..')',r.state,r.group,r}
        elseif r.state=='none' then want[key]={'No '..ItemName(r),'none',r.group,r}
        elseif r.state=='low' then want[key]={'Low '..ItemName(r)..' ('..r.count..')','low',r.group,r} end
        if r.key=='shards' and cfg.bagWarn and bagState then
            want.classStock_bags=bagState=='full' and {'Bags Full - No Room for Shards','none','shard'} or {'Soul Bag Full','full','shard'}
        end
    end
    if #blocked>0 and want.classStock_shards then want.classStock_shards[1]='No Soul Shards ('..table.concat(blocked,', ')..')' end
    if soul and soul.expired and cfg.soulTimer then want.classStock_soulExpired={'Soulstone Expired','none','stone'} end
    -- A problem sounds once when it is first shown; it sounds again only after it was solved.
    for key in pairs(lastState) do if not want[key] then lastState[key]=nil end end
    for key in pairs(laneShown) do local w=want[key];if not w or not S.CueWindow(w[3],w[4]) then Unlane(key) end end
    -- One sound per refresh, through the lane (S1): a module choice of None keeps the lane's own sound.
    local sound=cfg.sound~='none' and cfg.sound or nil
    for key,w in pairs(want) do
        if S.CueWindow(w[3],w[4]) then
            local new=lastState[key]~=w[2]
            lastState[key]=w[2]
            Lane(key,w[1],w[2],new and sound or nil)
            if new then sound=nil end
        end
    end
end

-------------------------------------------------------------------------------
-- Soulstone on someone: the cast of Soulstone Resurrection (the item's spell) starts a 30
-- minute timer named after the target from UNIT_SPELLCAST_SENT. No combat log on Forever, so
-- an early use (the target died and took it) is not seen; a new Soulstone replaces the timer.
-------------------------------------------------------------------------------
local ticker
local sentTarget,sentGUID
local function SaveSoul()
    if not Table(FHKEllesmereDB) then return end
    FHKEllesmereDB.classStockSoulstone=soul and not soul.expired and {expires=soul.expires,target=soul.target} or nil
end
local function LoadSoul()
    local v=Table(FHKEllesmereDB) and FHKEllesmereDB.classStockSoulstone
    soul=nil
    if Table(v) and Number(v.expires) then
        local left=v.expires-Now()
        -- GetTime restarts with the computer: a timer further away than 30 minutes is stale.
        if left>0 and left<=S.SOULSTONE_SECONDS then soul={expires=v.expires,target=Text(v.target) and v.target or nil} end
    end
    if not soul and Table(FHKEllesmereDB) then FHKEllesmereDB.classStockSoulstone=nil end
end
local function StopTicker() if ticker then ticker:Cancel();ticker=nil end end
local function Tick()
    if not enabled or not soul then StopTicker();return end
    local now=Now()
    if soul.expired then
        if now>=soul.expiredUntil then soul=nil;StopTicker();S.Cues() end
        return
    end
    if now>=soul.expires then
        soul.expired=true;soul.expiredUntil=now+20;SaveSoul();S.Cues()
    end
    S.Paint()
end
S.Tick=Tick
local function StartTicker()
    if ticker or not (C_Timer and C_Timer.NewTicker) then return end
    ticker=C_Timer.NewTicker(1,Tick)
end
function S.Soulstone() return soul end
local function SoulActive() return enabled and cfg and cfg.soulTimer and class=='WARLOCK' end

-------------------------------------------------------------------------------
-- Events: coalesced to one refresh per frame.
-------------------------------------------------------------------------------
local queued,dirtySpells=false,false
local function Queue(spells)
    if spells then dirtySpells=true end
    if queued then return end
    queued=true
    if C_Timer and C_Timer.After then C_Timer.After(0,function() Flush() end) else Flush() end
end
function Flush()
    queued=false
    if not enabled then return end
    local relayout=false
    if dirtySpells then
        dirtySpells=false
        active=S.Entries(class,cfg)
        activeByKey={};for _,r in ipairs(active) do activeByKey[r.key]=r end
        relayout=true
    end
    for _,r in ipairs(active) do S.Count(r,cfg) end
    bagState=nil
    if class=='WARLOCK' and cfg.bagWarn then
        for _,r in ipairs(active) do if r.key=='shards' then bagState=S.BagState() end end
    end
    if relayout or pending or Signature(Showing())~=laidOut then S.Layout() else S.Paint() end
    S.Cues()
end
S.Flush=function() Flush() end
local AWAY_EVENTS={PLAYER_DEAD=true,PLAYER_ALIVE=true,PLAYER_UNGHOST=true,PLAYER_CONTROL_LOST=true,PLAYER_CONTROL_GAINED=true,
    PLAYER_MOUNT_DISPLAY_CHANGED=true,UNIT_ENTERED_VEHICLE=true,UNIT_EXITED_VEHICLE=true}
-- The open vendor's stock, as item IDs. Unreadable means unknown (no "Buy here").
function S.ReadMerchant()
    local n=Read(_G.GetMerchantNumItems)
    if not Number(n) then soldHere=nil;return end
    local set={}
    for i=1,math.min(n,200) do local id=Read(_G.GetMerchantItemID,i);if Number(id) then set[id]=true end end
    soldHere=set
end
-- Smart: entering rest shows the bought-reagent cues for 10 s, then the icon carries it.
function S.RestWindow()
    restUntil=Now()+10
    if C_Timer and C_Timer.After then C_Timer.After(10.1,function() if enabled then S.Cues() end end) end
end
-- Payloads: SENT (unit, target, castGUID, spellID); SUCCEEDED (unit, castGUID, spellID).
function S.OnEvent(_,event,unit,a,b,c)
    if not enabled then
        -- Turned off in combat: finish hiding the secure strip once combat ends.
        if event=='PLAYER_REGEN_ENABLED' and pending then NS.SyncEllesmereClassStock() end
        return
    end
    if event=='UNIT_SPELLCAST_SENT' then
        if unit~='player' or not SoulActive() or not Number(c) or not S.SOULSTONE_RES[c] then return end
        -- The target name can be restricted: then the timer runs without a name.
        sentTarget=Text(a) and a or nil
        sentGUID=Text(b) and b or nil
        return
    end
    if event=='UNIT_SPELLCAST_SUCCEEDED' then
        if unit~='player' or not SoulActive() or not Number(b) or not S.SOULSTONE_RES[b] then return end
        local target=(sentGUID==nil or (Text(a) and a==sentGUID)) and sentTarget or nil
        soul={expires=Now()+S.SOULSTONE_SECONDS,target=target}
        sentTarget,sentGUID=nil,nil
        SaveSoul();StartTicker();S.Cues();S.Paint()
        return
    end
    if event=='PLAYER_UPDATE_RESTING' then
        local was=resting
        resting=Yes(Read(_G.IsResting))
        if resting and not was then S.RestWindow() end
    elseif event=='MERCHANT_SHOW' then atVendor=true;S.ReadMerchant()
    -- Later updates (a purchase, a junk sale) re-read only while the list is still empty (suite review SQ-14).
    elseif event=='MERCHANT_UPDATE' then atVendor=true;if not soldHere or next(soldHere)==nil then S.ReadMerchant() end
    elseif event=='MERCHANT_CLOSED' then atVendor=false;soldHere=nil
    elseif AWAY_EVENTS[event] then
        -- Taxi and mount state settles a moment after the event.
        S.Cues();if C_Timer and C_Timer.After then C_Timer.After(.5,function() if enabled then S.Cues() end end) end;return
    elseif event=='PLAYER_REGEN_DISABLED' then S.Cues();return
    elseif event=='PLAYER_REGEN_ENABLED' then
        if not holder then NS.SyncEllesmereClassStock();return end
        if pending then S.Layout() end
        S.Cues();return
    end
    Queue(event=='SPELLS_CHANGED' or event=='PLAYER_ENTERING_WORLD')
end
driver:SetScript('OnEvent',S.OnEvent)
function S.State() return {holder=holder,buttons=buttons,active=active,shown=shown,enabled=enabled,pending=pending,driver=driver,
    ticker=ticker,laneShown=laneShown,bagState=bagState} end

-- Preview (eye): every supply icon shows for a few seconds, wherever the strip is.
function NS.PreviewEllesmereClassStock()
    if not holder or not enabled then return end
    previewUntil=Now()+3
    if OutsideCombat() then S.Layout();holder:Show();holder:SetAlpha(1) end
    if C_Timer and C_Timer.After then C_Timer.After(3.1,function() if OutsideCombat() and enabled then S.Layout() end end) end
end

function NS.SyncEllesmereClassStock()
    cfg=NS.EllesmereClassStockSettings()
    class=Class()
    enabled=cfg.enabled==true and S.HasKit(class)
    driver:UnregisterAllEvents()
    if not enabled then
        StopTicker();HideAllCues()
        active,activeByKey={},{}
        if holder and OutsideCombat() then
            pending=false
            if type(UnregisterStateDriver)=='function' then UnregisterStateDriver(holder,'visibility') end
            holder:Hide()
        elseif holder then pending=true;driver:RegisterEvent('PLAYER_REGEN_ENABLED') end
        return
    end
    local where=cfg.cues=='rest' or cfg.cues=='auto'
    if not where then resting,atVendor,soldHere=false,false,nil end
    -- Turned on in combat: the secure strip is built once combat ends.
    if not holder and not OutsideCombat() then pending=true;driver:RegisterEvent('PLAYER_REGEN_ENABLED');return end
    Build()
    for _,event in ipairs({'PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED','SPELLS_CHANGED','PLAYER_ENTERING_WORLD','BAG_UPDATE_DELAYED'}) do driver:RegisterEvent(event) end
    if where then
        for _,event in ipairs({'PLAYER_UPDATE_RESTING','MERCHANT_SHOW','MERCHANT_UPDATE','MERCHANT_CLOSED'}) do driver:RegisterEvent(event) end
        local was=resting
        resting=Yes(Read(_G.IsResting))
        if resting and not was then S.RestWindow() end
    end
    -- Away changes (dead, taxi, mount, vehicle) re-check the cues; never while warnings are off.
    if cfg.cues~='off' then
        for event in pairs(AWAY_EVENTS) do
            if event:find('^UNIT_') then if driver.RegisterUnitEvent then driver:RegisterUnitEvent(event,'player') end
            elseif not (C_EventUtils and C_EventUtils.IsEventValid and Read(C_EventUtils.IsEventValid,event)==false) then driver:RegisterEvent(event) end
        end
    end
    if class=='WARLOCK' then
        if cfg.items.spellstone or cfg.items.firestone then driver:RegisterEvent('PLAYER_EQUIPMENT_CHANGED') end
        if cfg.soulTimer and driver.RegisterUnitEvent then
            driver:RegisterUnitEvent('UNIT_SPELLCAST_SENT','player');driver:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED','player')
        end
    end
    if SoulActive() then
        if not soul then LoadSoul() end
        if soul then StartTicker() end
    else StopTicker() end
    dirtySpells=true
    Flush()
end

-------------------------------------------------------------------------------
-- Options: Warnings > CLASS SUPPLIES.
-------------------------------------------------------------------------------
local GROUP_ROWS={shard={'shardLow','Low Soul Shards Below','Soul Shards under this count turn the icon gold and add a lane warning. 0 warns only when none are left.'},
    conjured={'conjuredLow','Low Food And Water Below','Conjured food or water under this count turns the icon gold and adds a lane warning. 0 warns only when none are left.'}}
function NS.AddEllesmereClassStockOptions(Row)
    local cls=Class()
    local kit=cls and S.KITS[cls]
    if not kit then return end
    if EUI.IsSearchPrebuild and EUI.IsSearchPrebuild() then
        Row({type='label',text='Class Supplies'},{type='label',text='Supplies Visibility'})
        Row({type='label',text='Supply Warnings'},{type='label',text='Supply Warning Sound'})
        return
    end
    local function Settings() return NS.EllesmereClassStockSettings() end
    local function Off() return not Settings().enabled end
    local function Set(k,v)
        if LIMITS[k] then if not Number(v) or v<LIMITS[k][1] or v>LIMITS[k][2] then return end
        elseif CHOICES[k] then if not Text(v) or not CHOICES[k][v] then return end
        elseif type(DEFAULTS[k])=='boolean' then if not Plain(v) or type(v)~='boolean' then return end
        else return end
        Settings()[k]=v;NS.SyncEllesmereClassStock()
    end
    local function Swatch(key,text)
        return {tooltip=text,hasAlpha=false,getValue=function()
            local saved=cfg;cfg=Settings();local r,g,b=Color(key);cfg=saved;return r,g,b,1
        end,setValue=function(r,g,b)
            if not Number(r) or not Number(g) or not Number(b) or r<0 or r>1 or g<0 or g>1 or b<0 or b>1 then return end
            local s=Settings();s.colors=Table(s.colors) and s.colors or {};s.colors[key]={r,g,b}
            if enabled then cfg=s;S.Paint();S.Cues() end
        end}
    end
    local warlock=cls=='WARLOCK'
    local master={type='toggle',text='Class Supplies',
        tooltip='A strip of your class reagents and made items with their bag counts: gold when low, red when none. Only spells you know add an icon. Warlock stones and mage conjures create on click (out of combat changes only).',
        getValue=function() return Settings().enabled end,setValue=function(v) Set('enabled',v) end}
    master.swatches={Swatch('ok','Count Color'),Swatch('low','Low Color'),Swatch('none','None Left Color')}
    if warlock then master.swatches[#master.swatches+1]=Swatch('full','Soul Bag Full Color');master.swatches[#master.swatches+1]=Swatch('timer','Soulstone Timer Color') end
    master.preview={tip='Preview the strip',show=NS.PreviewEllesmereClassStock,duration=3,disabled=Off,disabledTooltip='Class Supplies'}
    master.cog={title='Class Supplies Layout',disabled=Off,disabledTooltip='Class Supplies',rows={
        {type='slider',label='Icon Size',min=18,max=48,step=1,get=function() return Settings().size end,set=function(v) Set('size',v) end},
        {type='slider',label='Spacing',min=0,max=12,step=1,get=function() return Settings().spacing end,set=function(v) Set('spacing',v) end},
        {type='dropdown',label='Orientation',values={horizontal='Horizontal',vertical='Vertical'},order={'horizontal','vertical'},
            get=function() return Settings().orientation end,set=function(v) Set('orientation',v) end},
        {type='toggle',label='Show Counts',get=function() return Settings().counts end,set=function(v) Set('counts',v) end},
        {type='toggle',label='Gray Out When None',get=function() return Settings().dim end,set=function(v) Set('dim',v) end}}}
    Row(master,{type='dropdown',text='Supplies Visibility',values={always='Always',combat='In Combat',nocombat='Out of Combat',mouseover='Mouseover',low='Only When Low'},
        order={'always','combat','nocombat','mouseover','low'},disabled=Off,disabledTooltip='Class Supplies',
        tooltip='Only When Low shows just the supplies that are low or gone (the strip updates out of combat).',
        getValue=function() return Settings().visibility end,setValue=function(v) Set('visibility',v) end})
    local function CuesOff() return Off() or Settings().cues=='off' end
    Row({type='dropdown',text='Supply Warnings',values={off='Off',auto='Smart',ooc='Out of Combat',rest='Resting or at a Vendor',always='Always'},
        order={'off','auto','ooc','rest','always'},disabled=Off,disabledTooltip='Class Supplies',
        tooltip='Low and none-left warnings in the warning lane. Smart: reagents you buy warn when resting or at a vendor, things you make or farm warn out of combat. Resting or at a Vendor waits for an inn, a city or a merchant window.',
        getValue=function() return Settings().cues end,setValue=function(v) Set('cues',v) end},
        {type='dropdown',text='Supply Warning Sound',values={none='None',raid='Raid Warning',alarm='Alarm',ready='Ready Check',tick='Soft Tick'},
        order={'none','raid','alarm','ready','tick'},disabled=CuesOff,disabledTooltip='Supply Warnings',
        getValue=function() return Settings().sound end,
        setValue=function(v) Set('sound',v);if NS.PlayEllesmereCueSound then NS.PlayEllesmereCueSound(v,'classStockPreview') end end})
    -- Thresholds for the groups this class has.
    local sliders,seen={},{}
    for _,e in ipairs(kit) do
        local g=GROUP_ROWS[e.group]
        if g and not seen[e.group] then
            seen[e.group]=true
            sliders[#sliders+1]={type='slider',text=g[2],tooltip=g[3],min=LIMITS[g[1]][1],max=LIMITS[g[1]][2],step=1,disabled=Off,disabledTooltip='Class Supplies',
                getValue=function() return Settings()[g[1]] end,setValue=function(v) Set(g[1],v) end}
        end
    end
    local blank=function() return EUI.BlankRowCfg and EUI.BlankRowCfg() or {type='label',text=''} end
    for i=1,#sliders,2 do Row(sliders[i],sliders[i+1] or blank()) end
    -- One toggle per supply.
    local toggles={}
    for _,e in ipairs(kit) do
        local key=e.key
        local t={type='toggle',text=e.label,disabled=Off,disabledTooltip='Class Supplies',
            tooltip=e.create and 'Shows the count once you know the spell; click the icon to create one.' or 'Shows the count once you know a spell that uses it.',
            getValue=function() return Settings().items[key] end,
            setValue=function(v) if not Plain(v) or type(v)~='boolean' then return end;Settings().items[key]=v;NS.SyncEllesmereClassStock() end}
        if e.group=='reagent' then
            t.cog={title=e.label,disabled=function() return Off() or not Settings().items[key] end,disabledTooltip=e.label,rows={
                {type='slider',label='Warn Below',min=LOW_LIMIT[1],max=LOW_LIMIT[2],step=1,
                    get=function() return S.Threshold('reagent',Settings(),e) end,
                    set=function(v) if not Number(v) or v<LOW_LIMIT[1] or v>LOW_LIMIT[2] then return end;Settings().lows[key]=v;NS.SyncEllesmereClassStock() end}}}
        end
        toggles[#toggles+1]=t
    end
    if warlock then
        toggles[#toggles+1]={type='toggle',text='Soulstone Timer',disabled=Off,disabledTooltip='Class Supplies',
            tooltip='Using a Soulstone on someone starts a 30 minute timer on the Soulstone icon, and a lane warning when it runs out. An early use cannot be seen.',
            getValue=function() return Settings().soulTimer end,setValue=function(v) Set('soulTimer',v) end}
        toggles[#toggles+1]={type='toggle',text='Soul Bag Full Warning',disabled=Off,disabledTooltip='Class Supplies',
            tooltip='Warns when your soul bags are full, and in red when no bag has room for a new shard.',
            getValue=function() return Settings().bagWarn end,setValue=function(v) Set('bagWarn',v) end}
    end
    for i=1,#toggles,2 do Row(toggles[i],toggles[i+1] or blank()) end
    Row({type='label',text='Move the strip in Unlock Mode: Class Supplies'},
        {type='button',text='Reset Class Supplies',onClick=function()
            local s=Settings()
            for k,v in pairs(DEFAULTS) do if k~='enabled' then s[k]=v end end
            s.items={};s.lows={};s.colors=nil
            NS.SyncEllesmereClassStock()
        end})
end

local boot=CreateFrame('Frame')
boot:RegisterEvent('PLAYER_LOGIN')
boot:SetScript('OnEvent',function(self) self:UnregisterAllEvents();NS.SyncEllesmereClassStock() end)
