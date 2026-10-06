-- Weapon Enchants (class kits row B, engine E1, 2026-10-06; CLASS_KITS_2026-10-06.md): one pod per
-- weapon slot (main hand, off hand) showing the temporary enchant (rogue poison, shaman imbue,
-- sharpening stone / weightstone, wizard / mana oil, Forever's Firestone / Spellstone): icon, time
-- left, charges and the bag count of the item to use next. Missing / expiring / low-charge / out
-- of items cues go to the warning lane. Click applies out of combat (secure, attributes changed
-- only out of combat). Data: C_Item.GetWeaponEnchantInfo(Enum.WeaponSlot.*) (ItemDocumentation),
-- fallback C_PaperDollInfo.GetTemporaryEnchantmentInfo(INVSLOT). Item and enchant IDs come from
-- wago.tools DB2 build 1.60.1.70205 (ItemXItemEffect -> ItemEffect -> SpellEffect 54/360 ->
-- SpellItemEnchantment); enchant IDs the table lacks are learned at runtime from the last
-- applied item or imbue. Off by default; no frames, events or tickers while off.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end
local W={}
NS.WeaponEnchants=W

-------------------------------------------------------------------------------
-- Data (pure tables). Items per family in rank order: {itemID, required level, enchantID}.
-------------------------------------------------------------------------------
local FAMILIES={
    instant={name='Instant Poison',kind='poison',items={{6947,20,323},{6949,28,324},{6950,36,325},{8926,44,623},{8927,52,624},{8928,60,625}}},
    deadly={name='Deadly Poison',kind='poison',items={{2892,30,7},{2893,38,8},{8984,46,626},{8985,54,627},{20844,60,2630}}},
    crippling={name='Crippling Poison',kind='poison',items={{3775,20,22},{3776,50,603}}},
    mindnumbing={name='Mind-numbing Poison',kind='poison',items={{5237,24,35},{6951,38,23},{9186,52,643}}},
    wound={name='Wound Poison',kind='poison',items={{10918,32,703},{10920,40,704},{10921,48,705},{10922,56,706}}},
    occult={name='Occult Poison',kind='poison',items={{226374,54,7542},{234444,60,7651}}},
    sharpening={name='Sharpening Stone',kind='stone',items={{2862,1,40},{2863,5,13},{2871,15,14},{7964,25,483},{12404,35,1643},{18262,50,2506}}},
    weight={name='Weightstone',kind='stone',items={{3239,1,19},{3240,5,20},{3241,15,21},{7965,25,484},{12643,35,1703}}},
    wizard={name='Wizard Oil',kind='stone',items={{20744,5,2623},{20746,30,2626},{20750,40,2627},{20749,45,2628}}},
    mana={name='Mana Oil',kind='stone',items={{20745,20,2624},{20747,40,2625},{20748,45,2629}}},
    firestone={name='Firestone',kind='stone',class='WARLOCK',items={{1254,0,1803},{13699,0,1823},{13700,0,1824},{13701,0,1825}}},
    spellstone={name='Spellstone',kind='stone',class='WARLOCK',items={{5522,0,8059},{13602,0,8060},{13603,0,8061}}},
    -- Shaman imbues: spell ranks (any known rank means the imbue is known; cast by name = highest rank).
    windfury={name='Windfury Weapon',kind='imbue',spell=8232,ranks={8232,8235,10486,16362},enchants={283,284,525,1669,7569}},
    rockbiter={name='Rockbiter Weapon',kind='imbue',spell=8017,ranks={8017,8018,8019,10399,16314,16315,16316},enchants={29,6,1,503,1663,683,1664,7568}},
    flametongue={name='Flametongue Weapon',kind='imbue',spell=8024,ranks={8024,8027,8030,16339,16341,16342},enchants={5,4,3,523,1665,1666,7567}},
    frostbrand={name='Frostbrand Weapon',kind='imbue',spell=8033,ranks={8033,8038,10456,16355,16356},enchants={2,12,524,1667,1668,7566}},
}
W.FAMILIES=FAMILIES
local POISON_ORDER={'instant','deadly','occult','wound','mindnumbing','crippling'}
local IMBUE_ORDER={'windfury','rockbiter','flametongue','frostbrand'}
local STONE_ORDER={'sharpening','weight','wizard','mana','firestone','spellstone'}
W.POISON_ORDER,W.IMBUE_ORDER,W.STONE_ORDER=POISON_ORDER,IMBUE_ORDER,STONE_ORDER
-- Recognised without a family (shown by name, never preferred): Shadow / Frost Oil, the undead
-- stone and oil, Forever's Numbing / Sebacious / Atrophic Poison and the Blackfathom items.
local OTHER={[25]=3824,[26]=3829,[2684]=23122,[2685]=23123,[7255]=217346,[7254]=217345,[7256]=217347,[7098]=211845,[7099]=211848}
local ENCHANT,ITEM_FAMILY={},{}
for key,f in pairs(FAMILIES) do
    for _,it in ipairs(f.items or {}) do ENCHANT[it[3]]={family=key,item=it[1]};ITEM_FAMILY[it[1]]=key end
    for _,id in ipairs(f.enchants or {}) do ENCHANT[id]={family=key} end
end
for id,item in pairs(OTHER) do ENCHANT[id]={item=item} end
W.ENCHANT=ENCHANT
local POISONS_SKILL=2842
local INV={main=16,off=17}
local SLOTS={{key='main',inv=16,enum='MainHand',index=0,label='Main Hand',short='MAIN HAND'},
    {key='off',inv=17,enum='OffHand',index=1,label='Off Hand',short='OFF HAND'}}
W.SLOTS=SLOTS
-- Weapon subclasses (ItemWeaponSubclass): ranged ones take no pod; edged take stones, blunt weights.
local RANGED={[2]=true,[3]=true,[16]=true,[18]=true,[19]=true}
local SHARP={[0]=true,[1]=true,[6]=true,[7]=true,[8]=true,[15]=true}
local BLUNT={[4]=true,[5]=true,[10]=true}
local FISHING=20

-------------------------------------------------------------------------------
-- Settings.
-------------------------------------------------------------------------------
local DEFAULTS={enabled=false,size=32,spacing=4,orientation='horizontal',visibility='always',offHand=true,click=true,
    missingCue=true,missingCombat=false,expiringCue=true,expiringMinutes=5,lowChargesCue=true,lowCharges=20,
    noItemsCue=true,sound='none',mainPoison='auto',offPoison='auto',imbue='auto',stones=false,stone='auto'}
local function Choices(list) local t={auto=true};for _,k in ipairs(list) do t[k]=true end;return t end
local CHOICES={orientation={horizontal=true,vertical=true},visibility={always=true,combat=true,mouseover=true,attention=true},
    sound={none=true,raid=true,alarm=true,ready=true,tick=true},mainPoison=Choices(POISON_ORDER),offPoison=Choices(POISON_ORDER),
    imbue=Choices(IMBUE_ORDER),stone=Choices(STONE_ORDER)}
local LIMITS={size={20,48},spacing={0,12},expiringMinutes={1,15},lowCharges={5,60}}
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
function NS.EllesmereWeaponEnchantSettings()
    if not Table(FHKEllesmereDB) then FHKEllesmereDB={} end
    local s=FHKEllesmereDB.weaponEnchants
    if not Table(s) then s={};FHKEllesmereDB.weaponEnchants=s end
    for k,v in pairs(DEFAULTS) do
        local x=s[k]
        if type(v)=='boolean' then if not Plain(x) or type(x)~='boolean' then s[k]=v end
        elseif LIMITS[k] then if not Number(x) or x<LIMITS[k][1] or x>LIMITS[k][2] then s[k]=v end
        elseif CHOICES[k] then if not Text(x) or not CHOICES[k][x] then s[k]=v end end
    end
    if s.colors~=nil and not Table(s.colors) then s.colors=nil end
    return s
end
-- Per character (lead: classify as character): enchant IDs learned at runtime, the family last
-- seen on each slot (the Auto choice re-applies it) and the longest time left seen per enchant ID
-- (its duration, for the expiring threshold: SCENARIO_REVIEW S37).
function NS.EllesmereWeaponEnchantMemory()
    if not Table(FHKEllesmereDB) then FHKEllesmereDB={} end
    local m=FHKEllesmereDB.weaponEnchantsLearned
    if not Table(m) then m={};FHKEllesmereDB.weaponEnchantsLearned=m end
    if not Table(m.enchants) then m.enchants={} end
    if not Table(m.last) then m.last={} end
    if not Table(m.durations) then m.durations={} end
    for id,v in pairs(m.durations) do if not Number(id) or not Number(v) or v<=0 then m.durations[id]=nil end end
    for id,v in pairs(m.enchants) do
        if not Number(id) or not Table(v) or not Text(v.f) or not FAMILIES[v.f] or (v.i~=nil and not Number(v.i)) then m.enchants[id]=nil end
    end
    for k,v in pairs(m.last) do if not INV[k] or not Text(v) or not FAMILIES[v] then m.last[k]=nil end end
    return m
end

-------------------------------------------------------------------------------
-- Game reads (each guarded; a restricted or failed read is "unknown", never "missing").
-------------------------------------------------------------------------------
local function Class() local _,c=Read(_G.UnitClass,'player');return c end
W.Class=Class
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
local function ItemIcon(id) local t=Read(C_Item and C_Item.GetItemIconByID,id);return (Number(t) or Text(t)) and t or nil end
local function Count(id)
    if not Number(id) then return nil end
    local n=Read(C_Item and C_Item.GetItemCount or _G.GetItemCount,id)
    return Number(n) and n or nil
end
local function Level() local l=Read(_G.UnitLevel,'player');return Number(l) and l>0 and l or nil end
function W.PoisonsKnown() return Known(POISONS_SKILL) end
function W.ImbueKnown(key)
    local f=FAMILIES[key]
    if not f or f.kind~='imbue' then return false end
    for _,id in ipairs(f.ranks) do if Known(id) then return true end end
    return false
end
-- The weapon in a slot: itemID, classID, subclassID (nil when empty or unreadable).
local function Weapon(slot)
    local id=Read(_G.GetInventoryItemID,'player',slot.inv)
    if not Number(id) then return nil end
    local fn=C_Item and C_Item.GetItemInfoInstant or _G.GetItemInfoInstant
    if type(fn)~='function' then return id end
    local ok,_,_,_,_,_,classID,sub=pcall(fn,id)
    if not ok then return id end
    return id,Number(classID) and classID or nil,Number(sub) and sub or nil
end
-- Pod for this slot? Main hand: any non-ranged weapon (unreadable info counts). Off hand: a
-- readable weapon only (shields and held-in-off-hand items take no enchant).
local function Holds(i,id,classID,sub)
    if not id then return false end
    if classID==nil then return i==1 end
    return classID==2 and not (sub and RANGED[sub])
end
-- Read the temporary enchant: ok, has, enchantID, timeLeft (ms), charges, iconID.
function W.ReadEnchant(slot)
    local C=C_Item
    if C and type(C.GetWeaponEnchantInfo)=='function' then
        local E=_G.Enum and Enum.WeaponSlot
        local index=Table(E) and Number(E[slot.enum]) and E[slot.enum] or slot.index
        local ok,list=pcall(C.GetWeaponEnchantInfo,index)
        if not ok or not Table(list) then return false end
        -- pairs, as Blizzard's BuffFrame does: a sparse or keyed list still reads (R1-10).
        -- Non-table fields (a count, say) are skipped; a secret entry makes the read unknown.
        for _,e in pairs(list) do
            if not Plain(e) then return false end
            if type(e)=='table' then
                if not Plain(e.hasEnchant) then return false end
                local kind=e.enchantType
                -- ItemEnchantType: 2 Temporary, 3 Imbue; None (0) and Permanent (1) are not ours.
                if e.hasEnchant==true and not (Number(kind) and kind<2) then
                    local id,t,c,icon=e.enchantID,e.timeLeft,e.charges,e.enchantIconID
                    return true,true,Number(id) and id>0 and id or nil,Number(t) and t or nil,Number(c) and c or nil,Number(icon) and icon>0 and icon or nil
                end
            end
        end
        return true,false
    end
    local P=C_PaperDollInfo
    if P and type(P.GetTemporaryEnchantmentInfo)=='function' then
        local ok,info=pcall(P.GetTemporaryEnchantmentInfo,slot.inv)
        if not ok then return false end
        if info==nil then return true,false end
        if not Table(info) then return false end
        local id,t,c=info.enchantID,info.remainingTimeMs,info.chargesRemaining
        return true,true,Number(id) and id>0 and id or nil,Number(t) and t or nil,Number(c) and c or nil,nil
    end
    return false
end

-------------------------------------------------------------------------------
-- Decisions (pure given reads).
-------------------------------------------------------------------------------
-- New poison ranks by name (Forever adds tiers): an unknown bag item whose name starts with a
-- poison family's name and ends in a higher Roman numeral joins that family.
local ROMAN={I=1,II=2,III=3,IV=4,V=5,VI=6,VII=7,VIII=8,IX=9,X=10}
local scanned={}
function W.ConsiderItem(id)
    if not Number(id) or ITEM_FAMILY[id] or scanned[id]~=nil then return end
    local name=Read(C_Item and C_Item.GetItemNameByID,id)
    if not Text(name) then return end -- not cached yet: try again on the next bag update
    scanned[id]=false
    for _,key in ipairs(POISON_ORDER) do
        local f=FAMILIES[key]
        if name:sub(1,#f.name)==f.name then
            local rank=ROMAN[name:match(' (%u+)$') or ''] or 1
            if rank>#f.items then
                -- Required level (R1-13): GetItemInfo's itemMinLevel, else today's level as a floor.
                local fn=C_Item and C_Item.GetItemInfo
                local ok,_,_,_,_,minLevel
                if type(fn)=='function' then ok,_,_,_,_,minLevel=pcall(fn,id) end
                local now=Read(_G.UnitLevel,'player')
                local level=ok and Number(minLevel) and minLevel or Number(now) and now or 0
                f.items[#f.items+1]={id,level,0};ITEM_FAMILY[id]=key;scanned[id]=key
            end
            return
        end
    end
end
local function ScanBags()
    local C=C_Container
    if not (C and type(C.GetContainerNumSlots)=='function' and type(C.GetContainerItemID)=='function') then return end
    for bag=0,(Number(_G.NUM_BAG_SLOTS) and NUM_BAG_SLOTS or 4) do
        local n=Read(C.GetContainerNumSlots,bag)
        if Number(n) then for slot=1,n do W.ConsiderItem(Read(C.GetContainerItemID,bag,slot)) end end
    end
end
-- Highest rank in bags usable at this level: itemID, count. With none, the highest usable rank and 0.
function W.BestItem(key,level)
    local f=FAMILIES[key]
    if not f or not f.items then return nil,nil end
    local fallback
    for i=#f.items,1,-1 do
        local it=f.items[i]
        if not level or it[2]<=level then
            local n=Count(it[1])
            if n and n>0 then return it[1],n end
            fallback=fallback or it[1]
        end
    end
    return fallback,fallback and 0 or nil
end
local function Fits(key,sub,class)
    local f=FAMILIES[key]
    if not f or f.kind~='stone' then return false end
    if f.class and f.class~=class then return false end
    if key=='sharpening' then return not (sub and BLUNT[sub]) end
    if key=='weight' then return not (sub and SHARP[sub]) end
    return true
end
W.Fits=Fits
-- Which kind of enchant this slot wants: poison, imbue, stone, or none (display only). For
-- classes other than rogue and shaman the master toggle is the stone and oil reminder (S38); a
-- rogue before Poisons and a shaman (off hand, or before an imbue) use the Stone And Oil row.
function W.Kind(class,i,sub,cfg)
    if sub==FISHING then return 'none' end
    if class=='ROGUE' and W.PoisonsKnown() then return 'poison' end
    if class=='SHAMAN' and i==1 then
        for _,k in ipairs(IMBUE_ORDER) do if W.ImbueKnown(k) then return 'imbue' end end
    end
    if class~='ROGUE' and class~='SHAMAN' then return 'stone' end
    return cfg.stones and 'stone' or 'none'
end
W.StoneRow=function(class) return class=='ROGUE' or class=='SHAMAN' end
-- The family to apply: the setting, else (Auto) the family last seen on this slot, else the first
-- available in priority order.
function W.Preferred(kind,i,sub,class,cfg,level,last)
    if kind=='poison' then
        local pref=i==1 and cfg.mainPoison or cfg.offPoison
        if pref~='auto' then return pref end
        if last and FAMILIES[last] and FAMILIES[last].kind=='poison' then return last end
        for _,k in ipairs(POISON_ORDER) do local _,n=W.BestItem(k,level);if n and n>0 then return k end end
        return 'instant'
    elseif kind=='imbue' then
        if cfg.imbue~='auto' and W.ImbueKnown(cfg.imbue) then return cfg.imbue end
        if last and FAMILIES[last] and FAMILIES[last].kind=='imbue' and W.ImbueKnown(last) then return last end
        for _,k in ipairs(IMBUE_ORDER) do if W.ImbueKnown(k) then return k end end
    elseif kind=='stone' then
        if cfg.stone~='auto' then return Fits(cfg.stone,sub,class) and cfg.stone or nil end
        if last and Fits(last,sub,class) then local _,n=W.BestItem(last,level);if n and n>0 then return last end end
        for _,k in ipairs(STONE_ORDER) do
            if Fits(k,sub,class) then local _,n=W.BestItem(k,level);if n and n>0 then return k end end
        end
    end
end
-- Time text: minutes (rounded up) from a minute, else seconds.
function W.Format(sec)
    if not Number(sec) or sec<=0 then return '' end
    local s=math.ceil(sec)
    if s>=60 then return math.ceil(sec/60)..'m' end
    return s..'s'
end

-------------------------------------------------------------------------------
-- State, frames, cues.
-------------------------------------------------------------------------------
local holder
local pods={}
local state={{},{}}
local driver=CreateFrame('Frame')
local enabled,pending,dirty,bagsDirty,cfg=false,false,false,false,nil
local ticker,previewUntil
local pendingApply -- {family, item, at}: the last applied item or imbue, for learning enchant IDs
local cueText={} -- lane key -> text shown
local CUE_KEYS={'fhkWeaponMissing','fhkWeaponTimer'}
local resting,atVendor=false,false -- the Smart window for none-in-bags lines (S36)
local function Font(fs,size)
    local path=Read(EUI.GetFontPath,'extras')
    fs:SetFont(Text(path) and path or 'Fonts\\FRIZQT__.TTF',size,'OUTLINE')
end
local function Color(key)
    local c=cfg and Table(cfg.colors) and cfg.colors[key]
    if Table(c) and Number(c[1]) and Number(c[2]) and Number(c[3]) then return c[1],c[2],c[3] end
    local C=NS.Colours or {}
    c=key=='active' and (C.happy or {.30,.85,.30}) or key=='expiring' and (C.caution or {1,.82,0})
        or key=='low' and (C.worry or {1,.5,.25}) or key=='missing' and (C.danger or {1,.3,.25}) or {.25,.25,.28}
    return c[1],c[2],c[3]
end
W.Color=function(key) return Color(key) end
local colourBuf={}
local function ColourTable(key) local r,g,b=Color(key);colourBuf[key]=colourBuf[key] or {};local t=colourBuf[key];t[1],t[2],t[3]=r,g,b;return t end
local function Position()
    if not holder or not OutsideCombat() then pending=true;return end
    local p=NS.EllesmereWeaponEnchantSettings().position
    local valid=Table(p) and Text(p.point) and POINTS[p.point] and Text(p.relPoint) and POINTS[p.relPoint] and Number(p.x) and Number(p.y)
    holder:ClearAllPoints()
    holder:SetPoint(valid and p.point or 'CENTER',UIParent,valid and p.relPoint or 'CENTER',valid and p.x or 260,valid and p.y or -200)
end
local function Hover(frame)
    frame:HookScript('OnEnter',function() if cfg and cfg.visibility=='mouseover' and holder then holder:SetAlpha(1) end end)
    frame:HookScript('OnLeave',function()
        if cfg and cfg.visibility=='mouseover' and holder and not holder:IsMouseOver() then holder:SetAlpha(0) end
    end)
end
local function Build()
    if holder then return end
    holder=CreateFrame('Frame','FHKEllesmereWeaponEnchants',UIParent,'SecureHandlerStateTemplate')
    holder:SetSize(32,32);holder:SetFrameStrata('MEDIUM');holder:EnableMouse(false);Hover(holder)
    if EUI.MakeUnlockElement and EUI.RegisterUnlockElements then
        EUI:RegisterUnlockElements({EUI.MakeUnlockElement({key='FHKEllesmereWeaponEnchants',label='Weapon Enchants',group='Unit Frames',order=622,noResize=true,
            getFrame=function() return holder end,getSize=function() return holder:GetWidth(),holder:GetHeight() end,
            isHidden=function() return not enabled end,
            savePos=function(_,point,relPoint,x,y) if Text(point) and POINTS[point] and Text(relPoint) and POINTS[relPoint] and Number(x) and Number(y) then NS.EllesmereWeaponEnchantSettings().position={point=point,relPoint=relPoint,x=x,y=y};Position() end end,
            loadPos=function() return NS.EllesmereWeaponEnchantSettings().position end,
            clearPos=function() NS.EllesmereWeaponEnchantSettings().position=nil;Position() end,applyPos=Position
        })},'FHKEllesmere')
    end
end
local function Tooltip(self)
    if not GameTooltip then return end
    local st=state[self.slotIndex]
    local slot=SLOTS[self.slotIndex]
    GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
    GameTooltip:SetText(slot.label,1,1,1)
    local cur=st.curName or (st.has and 'Unknown enchant') or 'No enchant'
    GameTooltip:AddLine(cur..(st.expires and (' ('..W.Format(st.expires-Now())..')') or '')..(st.charges and st.charges>0 and (', '..st.charges..' charges') or ''),1,.82,0,true)
    local f=st.family and FAMILIES[st.family]
    if f then
        if f.kind=='imbue' then GameTooltip:AddLine('Click: cast '..f.name..'.',.8,.8,.8,true)
        elseif st.item then
            local name=Read(C_Item and C_Item.GetItemNameByID,st.item)
            GameTooltip:AddLine((Text(name) and name or f.name)..' in bags: '..(st.count or '?'),.8,.8,.8,true)
            if st.count and st.count>0 then GameTooltip:AddLine('Click: apply it to this weapon.',.8,.8,.8,true) end
        end
    end
    GameTooltip:Show()
end
local function Pod(i)
    if pods[i] then return pods[i] end
    local b=CreateFrame('Button','FHKEllesmereWeaponEnchant'..i,holder,'SecureActionButtonTemplate')
    b.slotIndex=i
    b:RegisterForClicks('AnyUp')
    b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetAllPoints(b);b.icon:SetTexCoord(.08,.92,.08,.92)
    b.border=Read(EUI.MakeBorder,b,0,0,0,1)
    b.time=b:CreateFontString(nil,'OVERLAY');Font(b.time,12);b.time:SetPoint('TOP',b,'BOTTOM',0,-2)
    b.charges=b:CreateFontString(nil,'OVERLAY');Font(b.charges,10);b.charges:SetPoint('TOPLEFT',b,'TOPLEFT',2,-2)
    b.count=b:CreateFontString(nil,'OVERLAY');Font(b.count,11);b.count:SetPoint('BOTTOMRIGHT',b,'BOTTOMRIGHT',-1,2)
    b:HookScript('OnEnter',Tooltip)
    b:HookScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
    -- Remember what this click applies, to learn enchant IDs the table lacks (insecure, read only).
    b:HookScript('PreClick',function(self)
        local st=state[self.slotIndex]
        if self.applies and st.family then pendingApply={family=st.family,item=st.item,at=Now()} end
    end)
    Hover(b)
    pods[i]=b
    return b
end
local ATTRS={'type','spell','item','target-slot'}
local function Attributes(b,st,slot)
    local sig='none'
    if cfg.click and st.relevant then
        local f=st.family and FAMILIES[st.family]
        if f and f.kind=='imbue' then local n=SpellName(f.spell);if n then sig='spell:'..n end
        elseif f and st.item and st.count and st.count>0 then sig='item:'..st.item end
    end
    if b.sig==sig then return true end
    if not OutsideCombat() then return false end
    for _,k in ipairs(ATTRS) do b:SetAttribute(k,nil) end
    if sig:sub(1,6)=='spell:' then b:SetAttribute('type','spell');b:SetAttribute('spell',sig:sub(7))
    elseif sig~='none' then b:SetAttribute('type','item');b:SetAttribute('item',sig);b:SetAttribute('target-slot',slot.inv) end
    b.sig=sig;b.applies=sig~='none'
    return true
end
local layoutAttention -- Attention() when the layout last ran (Needs Attention visibility)
local function Attention()
    for i=1,#SLOTS do if state[i].cue then return true end end
    return false
end
local function VisibilityDriver()
    if cfg.visibility=='combat' then return '[combat] show; hide' end
    -- Needs Attention: hidden for real while all is well (no invisible clickable pods, R1-6).
    if cfg.visibility=='attention' and not Attention() and not (previewUntil and Now()<previewUntil) then return 'hide' end
    return 'show'
end
local function Shown(i)
    if previewUntil and Now()<previewUntil then return true end
    return state[i].relevant==true
end
function W.Layout()
    if not holder or not cfg or not OutsideCombat() then pending=true;return end
    pending=false
    local size,gap,n=cfg.size,cfg.spacing,0
    for i=1,#SLOTS do
        local b=Pod(i)
        if Shown(i) then
            n=n+1
            b:SetSize(size,size);b:ClearAllPoints()
            -- Room under each pod for its timer.
            b:SetPoint('TOPLEFT',holder,'TOPLEFT',cfg.orientation=='horizontal' and (n-1)*(size+gap) or 0,cfg.orientation=='vertical' and -(n-1)*(size+gap+14) or 0)
            Attributes(b,state[i],SLOTS[i])
            b:Show()
        else Attributes(b,state[i],SLOTS[i]);b:Hide() end
    end
    local long=math.max(1,n)*size+math.max(0,n-1)*gap
    holder:SetSize(cfg.orientation=='horizontal' and long or size,cfg.orientation=='vertical' and (long+math.max(0,n-1)*14) or size)
    local drive=n>0 and VisibilityDriver() or 'hide'
    if type(RegisterStateDriver)=='function' then RegisterStateDriver(holder,'visibility',drive)
    else holder:SetShown(drive~='hide') end
    layoutAttention=Attention()
    holder:EnableMouse(cfg.visibility=='mouseover')
    Position()
    W.Paint()
end
local function Alpha()
    if not holder then return end
    if previewUntil and Now()<previewUntil then holder:SetAlpha(1);return end
    if cfg.visibility=='mouseover' then if not holder:IsMouseOver() then holder:SetAlpha(0) end
    elseif cfg.visibility=='attention' then holder:SetAlpha(Attention() and 1 or 0)
    else holder:SetAlpha(1) end
end
local SAMPLE={{family='instant',has=true,left=1680,charges=48},{family='deadly',has=false}}
function W.Paint()
    if not enabled or not holder or not cfg then return end
    local now=Now()
    local preview=previewUntil and now<previewUntil
    for i,b in ipairs(pods) do
        local st=state[i]
        if b:IsShown() then
            local icon,time,charges,count,colour,alpha='','','','','quiet',1
            if preview then
                local p=SAMPLE[i]
                local f=FAMILIES[p.family]
                icon=ItemIcon(f.items[1][1]);time=p.has and W.Format(p.left) or ''
                charges=p.charges and tostring(p.charges) or '';count='12';colour=p.has and 'active' or 'missing'
            else
                local f=st.family and FAMILIES[st.family]
                icon=st.curIcon or (f and (f.kind=='imbue' and SpellIcon(f.spell) or st.item and ItemIcon(st.item))) or Read(_G.GetInventoryItemTexture,'player',SLOTS[i].inv)
                if st.has then
                    time=st.expires and W.Format(st.expires-now) or ''
                    charges=st.charges and st.charges>0 and tostring(st.charges) or ''
                end
                if st.item and st.count and f and f.kind~='imbue' then count=tostring(st.count) end
                colour=st.cue or (st.has and 'active') or (st.known==nil and 'quiet') or (st.kind=='none' and 'quiet') or 'missing'
                if not st.has and (st.kind=='none' or st.known==nil) then alpha=.5 end
            end
            if b.iconPaint~=icon then b.iconPaint=icon;b.icon:SetTexture(icon) end
            local grey=not preview and not st.has
            if b.greyPaint~=grey and b.icon.SetDesaturated then b.greyPaint=grey;b.icon:SetDesaturated(grey) end
            if b.timePaint~=time then b.timePaint=time;b.time:SetText(time) end
            if b.chargesPaint~=charges then b.chargesPaint=charges;b.charges:SetText(charges) end
            if b.countPaint~=count then b.countPaint=count;b.count:SetText(count) end
            local r,g,bl=Color(colour)
            if b.border and type(b.border.SetColor)=='function' and (b.cr~=r or b.cg~=g or b.cb~=bl) then b.cr,b.cg,b.cb=r,g,bl;b.border:SetColor(r,g,bl,1) end
            if b.alphaPaint~=alpha then b.alphaPaint=alpha;b:SetAlpha(alpha) end
        end
    end
    Alpha()
end
-- Away state (SCENARIO_REVIEW S2): the shared Bootstrap rule. 'buff' quiets missing / expiring
-- cues while dead, on a taxi or vehicle, or mounted (S39); 'bought' quiets none-in-bags lines.
local function Away(kind)
    local fn=NS.EllesmereAway
    if type(fn)~='function' then return nil end
    local ok,r=pcall(fn,kind)
    return ok and Plain(r) and r or nil
end
local soundFree=false -- one module sound per refresh (S1): the first new line carries it
local function Lane(key,text,colourKey)
    if text then
        if cueText[key]==text then return end -- unchanged: no lane work on the 1 s tick
        local sound
        if cueText[key]==nil and soundFree and cfg and cfg.sound~='none' then sound=cfg.sound;soundFree=false end
        cueText[key]=text
        if NS.ShowEllesmereWarning then NS.ShowEllesmereWarning(key,text,ColourTable(colourKey),true,false,sound) end
    elseif cueText[key]~=nil then
        cueText[key]=nil
        if NS.HideEllesmereWarning then NS.HideEllesmereWarning(key) end
    end
end
local function HideCues() for _,k in ipairs(CUE_KEYS) do Lane(k,nil) end;state[1].cue=nil;state[2].cue=nil end
-- The expiring threshold: the setting, capped at 20% of the duration seen (S37), so a short
-- enchant never reads "expiring" from the moment it is applied.
function W.ExpiringLimit(minutes,duration)
    local limit=minutes*60
    if Number(duration) and duration>0 and duration*.2<limit then limit=duration*.2 end
    return limit
end
-- Cues, two lane lines at most (S36):
--   fhkWeaponMissing: "NO INSTANT POISON" (a slot named only when one of two lacks it). With none
--     in bags it reads "NO INSTANT POISON: NONE IN BAGS" and shows only while resting or at a
--     vendor; else, with the enchant on but none left, "OUT OF INSTANT POISON" in the same window.
--   fhkWeaponTimer: "<ENCHANT> EXPIRING" or "<ENCHANT> LOW CHARGES".
function W.Cues()
    if not enabled or not cfg then return end
    soundFree=true
    local now=Now()
    local combat=not OutsideCombat()
    local buffAway=Away('buff')
    local smart=(resting or atVendor) and not combat and not Away('bought')
    local relevant,missing,missName,missMixed,noneInBags,missSlot=0,0,nil,false,true,nil
    local timerKind,timerName,timerMixed,timerCount,timerSlot,outName=nil,nil,false,0,nil,nil
    for i=1,#SLOTS do
        local st=state[i]
        st.cue=nil;st.timer=nil
        if st.relevant and st.kind~='none' and st.known then
            relevant=relevant+1
            local f=st.family and FAMILIES[st.family]
            if not st.has then
                -- A stone reminder needs something to apply (Auto with nothing that fits stays quiet).
                if f then
                    missing=missing+1;missSlot=i
                    if missName==nil then missName=f.name elseif missName~=f.name then missMixed=true end
                    if f.kind=='imbue' or not (st.item and st.count==0) then noneInBags=false end
                end
            else
                if cfg.expiringCue and st.expires and st.expires-now<=W.ExpiringLimit(cfg.expiringMinutes,st.duration) then st.timer='expiring'
                elseif cfg.lowChargesCue and st.charges and st.charges>0 and st.charges<=cfg.lowCharges then st.timer='low' end
                if not outName and f and f.kind~='imbue' and st.item and st.count==0 then outName=f.name end
            end
            if st.timer and (timerKind==nil or (st.timer=='expiring' and timerKind=='low')) then
                timerKind,timerName,timerMixed,timerCount,timerSlot=st.timer,nil,false,0,nil
            end
            if timerKind and st.timer==timerKind then
                local name=st.curName or (f and f.name) or 'Weapon Enchant'
                timerCount=timerCount+1;timerSlot=i
                if timerName==nil then timerName=name elseif timerName~=name then timerMixed=true end
            end
        end
    end
    -- Missing, or out of items.
    local text,colour
    if missing>0 and cfg.missingCue then
        local label='NO '..(missMixed and 'WEAPON ENCHANT' or missName:upper())..((missing==1 and relevant>1) and (' ('..SLOTS[missSlot].short..')') or '')
        if noneInBags then
            if smart then text=label..(cfg.noItemsCue and ': NONE IN BAGS' or '');colour='low' end
        elseif not buffAway and (cfg.missingCombat or not combat) then text=label;colour='missing' end
        if text then
            for i=1,#SLOTS do local st=state[i];if st.relevant and st.known and st.has==false and st.kind~='none' and st.family then st.cue='missing' end end
        end
    end
    if not text and outName and cfg.noItemsCue and smart then text='OUT OF '..outName:upper();colour='low' end
    Lane('fhkWeaponMissing',text,colour)
    -- Expiring or low charges.
    text=nil
    if timerKind and not buffAway then
        text=(timerMixed and 'WEAPON ENCHANTS' or timerName:upper())..(timerKind=='expiring' and ' EXPIRING' or ' LOW CHARGES')
            ..((timerCount==1 and relevant>1) and (' ('..SLOTS[timerSlot].short..')') or '')
        for i=1,#SLOTS do local st=state[i];if st.timer==timerKind then st.cue=timerKind end end
    end
    Lane('fhkWeaponTimer',text,timerKind)
    -- Needs Attention: show or hide the holder when attention changes (protected: out of combat;
    -- in combat only the alpha follows and the layout waits for combat end).
    if cfg.visibility=='attention' and holder and Attention()~=layoutAttention then
        if OutsideCombat() then W.Layout() else pending=true end
    end
end
local function Countdown()
    for i=1,#SLOTS do local st=state[i];if st.relevant and st.has and st.expires then return true end end
    return false
end
local function Ticker(on)
    if on and not ticker and C_Timer and C_Timer.NewTicker then
        ticker=C_Timer.NewTicker(1,function()
            if not enabled then if ticker then ticker:Cancel();ticker=nil end;return end
            local now=Now()
            for i=1,#SLOTS do local st=state[i];if st.expires and st.expires<=now then W.MarkDirty() end end
            W.Cues();W.Paint()
            if not Countdown() and ticker then ticker:Cancel();ticker=nil end
        end)
    elseif not on and ticker then ticker:Cancel();ticker=nil end
end
-- Identify the enchant on a slot: family, item and display name.
local function Identify(st,memory,changed)
    local id=st.enchantID
    local e=id and (ENCHANT[id] or memory.enchants[id])
    if e then
        local family,item=e.family or e.f,e.item or e.i
        return family,item
    end
    if not st.has then return end
    -- Unknown ID: learn it from the item or imbue applied in the last 15 seconds.
    if changed and id and pendingApply and Now()-pendingApply.at<=15 then
        memory.enchants[id]={f=pendingApply.family,i=pendingApply.item}
        local family,item=pendingApply.family,pendingApply.item
        pendingApply=nil
        return family,item
    end
    -- Else the enchant icon, when it matches the preferred item or imbue.
    local f=st.family and FAMILIES[st.family]
    if st.icon and f then
        local icon=f.kind=='imbue' and SpellIcon(f.spell) or st.item and ItemIcon(st.item)
        if icon and icon==st.icon then return st.family,st.item end
    end
end
function W.Refresh()
    dirty=false
    if not enabled or not cfg then return end
    local now=Now()
    local class=Class()
    local level=Level()
    local memory=NS.EllesmereWeaponEnchantMemory()
    if bagsDirty then bagsDirty=false;if class=='ROGUE' then ScanBags() end end
    local relayout=false
    for i,slot in ipairs(SLOTS) do
        local st=state[i]
        local id,classID,sub=Weapon(slot)
        local relevant=Holds(i,id,classID,sub) and (i==1 or cfg.offHand)
        if relevant~=(st.relevant==true) then relayout=true end
        st.relevant=relevant
        st.kind=W.Kind(class,i,sub,cfg)
        local ok,has,eid,left,charges,icon=W.ReadEnchant(slot)
        local changed=false
        if ok then
            changed=st.enchantID~=(has and eid or nil) or st.has~=has
            st.known=true;st.has=has
            st.enchantID=has and eid or nil
            st.expires=has and left and left>0 and now+left/1000 or nil
            st.charges=has and charges or nil
            st.icon=has and icon or nil
            -- Duration (S37): the longest time left seen for this enchant ID, else at this apply.
            local secs=has and left and left>0 and left/1000 or nil
            if secs and st.enchantID then
                local d=memory.durations[st.enchantID]
                if not d or secs>d then memory.durations[st.enchantID]=secs end
                st.duration=memory.durations[st.enchantID]
            elseif secs then st.duration=(changed or not st.duration or secs>st.duration) and secs or st.duration
            else st.duration=nil end
        end -- unreadable: keep the last known state (nil before the first read)
        st.family=W.Preferred(st.kind,i,sub,class,cfg,level,memory.last[slot.key])
        st.item,st.count=nil,nil
        if st.family and FAMILIES[st.family].items then st.item,st.count=W.BestItem(st.family,level) end
        local curFamily,curItem=Identify(st,memory,changed)
        st.curFamily=curFamily
        st.curName=curItem and Read(C_Item and C_Item.GetItemNameByID,curItem) or curFamily and FAMILIES[curFamily].name or nil
        if not Text(st.curName) then st.curName=nil end
        st.curIcon=st.has and (st.icon or curItem and ItemIcon(curItem) or curFamily and FAMILIES[curFamily].spell and SpellIcon(FAMILIES[curFamily].spell)) or nil
        if relevant and curFamily and memory.last[slot.key]~=curFamily then memory.last[slot.key]=curFamily end
        -- The click follows the new preference (protected: out of combat, else queued).
        if pods[i] and not Attributes(pods[i],st,slot) then pending=true end
    end
    if relayout then W.Layout() end
    W.Cues();W.Paint()
    Ticker(Countdown())
end
function W.MarkDirty()
    if dirty then return end
    dirty=true
    if C_Timer and C_Timer.After then C_Timer.After(0,function() if dirty then W.Refresh() end end) else W.Refresh() end
end
-- Preview (eye): sample pods for a few seconds and one sample lane warning.
function NS.PreviewEllesmereWeaponEnchants()
    if not holder or not enabled then return end
    previewUntil=Now()+3
    if OutsideCombat() then W.Layout();holder:Show() end
    W.Paint()
    if NS.ShowEllesmereWarning then NS.ShowEllesmereWarning('fhkWeaponPreview','INSTANT POISON EXPIRING (MAIN HAND)',ColourTable('expiring'),true,false) end
    if C_Timer and C_Timer.After then C_Timer.After(3.1,function()
        previewUntil=nil
        if NS.HideEllesmereWarning then NS.HideEllesmereWarning('fhkWeaponPreview') end
        if enabled and OutsideCombat() then W.Layout() elseif enabled then pending=true;W.Paint() end
    end) end
end
local castFamily={} -- spellID -> family key or false (one name read per spell)
local AWAY_EVENTS={PLAYER_DEAD=true,PLAYER_ALIVE=true,PLAYER_UNGHOST=true,PLAYER_CONTROL_LOST=true,PLAYER_CONTROL_GAINED=true,
    PLAYER_MOUNT_DISPLAY_CHANGED=true,UNIT_ENTERED_VEHICLE=true,UNIT_EXITED_VEHICLE=true}
W.AWAY_EVENTS=AWAY_EVENTS
local awayRecheck=false
local function AwayChanged()
    W.Cues();W.Paint()
    if not awayRecheck and C_Timer and C_Timer.After then
        awayRecheck=true
        C_Timer.After(.5,function() awayRecheck=false;if enabled then W.Cues();W.Paint() end end)
    end
end
function W.OnEvent(_,event,unit,_,spellID)
    if not enabled then
        -- Turned off in combat: the queued hide runs once combat ends.
        if event=='PLAYER_REGEN_ENABLED' and holder then
            driver:UnregisterAllEvents()
            if type(UnregisterStateDriver)=='function' then UnregisterStateDriver(holder,'visibility') end
            holder:Hide();pending=false
        end
        return
    end
    if event=='PLAYER_REGEN_ENABLED' then
        if not holder then NS.SyncEllesmereWeaponEnchants();return end -- turned on in combat
        if pending then pending=false;W.Layout();W.Refresh() else W.Cues() end
        return
    end
    if event=='PLAYER_REGEN_DISABLED' then W.Cues();W.Paint();return end
    if AWAY_EVENTS[event] then
        if (event=='UNIT_ENTERED_VEHICLE' or event=='UNIT_EXITED_VEHICLE') and unit~='player' then return end
        AwayChanged();return
    end
    -- The Smart window for none-in-bags lines: resting or at a vendor.
    if event=='PLAYER_UPDATE_RESTING' then resting=Yes(Read(_G.IsResting));W.Cues();W.Paint();return end
    if event=='MERCHANT_SHOW' or event=='MERCHANT_CLOSED' then atVendor=event=='MERCHANT_SHOW';W.Cues();W.Paint();return end
    if event=='UNIT_SPELLCAST_SUCCEEDED' then
        if unit~='player' or not Number(spellID) then return end
        -- Item or imbue cast by hand: remember its family for an enchant ID the table lacks.
        local family=castFamily[spellID]
        if family==nil then
            local name=SpellName(spellID)
            if not name then return end
            family=false
            for key,f in pairs(FAMILIES) do if name:sub(1,#f.name)==f.name then family=key;break end end
            castFamily[spellID]=family
        end
        if family then pendingApply={family=family,at=Now()} end
        return
    end
    if event=='UNIT_INVENTORY_CHANGED' and unit~='player' then return end
    if event=='BAG_UPDATE_DELAYED' or event=='PLAYER_ENTERING_WORLD' then bagsDirty=true end
    W.MarkDirty()
end
driver:SetScript('OnEvent',W.OnEvent)
function W.State() return {holder=holder,pods=pods,state=state,enabled=enabled,pending=pending,ticker=ticker,driver=driver,cues=cueText} end
local EVENTS={'PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED','PLAYER_ENTERING_WORLD','WEAPON_ENCHANT_CHANGED','WEAPON_SLOT_CHANGED',
    'PLAYER_EQUIPMENT_CHANGED','BAG_UPDATE_DELAYED','SPELLS_CHANGED','PLAYER_LEVEL_UP','PLAYER_UPDATE_RESTING','MERCHANT_SHOW','MERCHANT_CLOSED'}
function NS.SyncEllesmereWeaponEnchants()
    cfg=NS.EllesmereWeaponEnchantSettings()
    enabled=cfg.enabled==true and Class()~=nil
    driver:UnregisterAllEvents()
    if not enabled then
        Ticker(false);HideCues()
        if holder and OutsideCombat() then
            if type(UnregisterStateDriver)=='function' then UnregisterStateDriver(holder,'visibility') end
            holder:Hide()
        elseif holder then pending=true;driver:RegisterEvent('PLAYER_REGEN_ENABLED') end
        return
    end
    -- Secure frames are first built out of combat.
    if not holder and not OutsideCombat() then pending=true;driver:RegisterEvent('PLAYER_REGEN_ENABLED');return end
    Build()
    for _,event in ipairs(EVENTS) do driver:RegisterEvent(event) end
    if driver.RegisterUnitEvent then
        driver:RegisterUnitEvent('UNIT_INVENTORY_CHANGED','player');driver:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED','player')
    end
    -- Away state (R1-1): only while a cue can show; events this client lacks are skipped.
    if cfg.missingCue or cfg.expiringCue or cfg.lowChargesCue or cfg.noItemsCue then
        local valid=C_EventUtils and C_EventUtils.IsEventValid
        for event in pairs(AWAY_EVENTS) do
            if not (type(valid)=='function' and Read(valid,event)==false) then
                if event:sub(1,5)=='UNIT_' then if driver.RegisterUnitEvent then driver:RegisterUnitEvent(event,'player') end
                else driver:RegisterEvent(event) end
            end
        end
    end
    for i=1,#SLOTS do Pod(i) end
    resting=Yes(Read(_G.IsResting))
    bagsDirty=true
    W.Refresh()
    W.Layout()
end

-------------------------------------------------------------------------------
-- Options: Unit Frames > WEAPON ENCHANTS.
-------------------------------------------------------------------------------
local SOUND_VALUES={none='None',raid='Raid Warning',alarm='Alarm',ready='Ready Check',tick='Soft Tick'}
local SOUND_ORDER={'none','raid','alarm','ready','tick'}
function NS.AddEllesmereWeaponEnchantsOptions(Row)
    local class=Class()
    if EUI.IsSearchPrebuild and EUI.IsSearchPrebuild() then
        local pairs_={{'Weapon Enchants','Weapon Enchant Visibility'},{'Missing Enchant Cue','Missing Cue In Combat'},{'Expiring Cue','Expiring At (Minutes)'},
            {'Low Charges Cue','Low Charges At'},{'Out Of Items Cue','Weapon Enchant Sound'}}
        if class=='ROGUE' then pairs_[#pairs_+1]={'Main Hand Poison','Off Hand Poison'} end
        if class=='SHAMAN' then pairs_[#pairs_+1]={'Preferred Imbue','Click To Apply'};pairs_[#pairs_+1]={'Stone And Oil Reminder',''}
        elseif class=='ROGUE' then pairs_[#pairs_+1]={'Click To Apply','Stone And Oil Reminder'}
        else pairs_[#pairs_+1]={'Click To Apply',''} end
        pairs_[#pairs_+1]={'Preferred Stone Or Oil','Reset Weapon Enchants'}
        pairs_[#pairs_+1]={'Move the icons in Unlock Mode: Weapon Enchants',''}
        for _,p in ipairs(pairs_) do Row({type='label',text=p[1]},{type='label',text=p[2]}) end
        return
    end
    local function Settings() return NS.EllesmereWeaponEnchantSettings() end
    local function Off() return not Settings().enabled end
    local function Set(k,v)
        if LIMITS[k] then if not Number(v) or v<LIMITS[k][1] or v>LIMITS[k][2] then return end
        elseif CHOICES[k] then if not Text(v) or not CHOICES[k][v] then return end
        elseif type(DEFAULTS[k])=='boolean' then if not Plain(v) or type(v)~='boolean' then return end end
        Settings()[k]=v;NS.SyncEllesmereWeaponEnchants()
    end
    local function Swatch(key,text)
        return {tooltip=text,hasAlpha=false,getValue=function()
            local saved=cfg;cfg=Settings();local r,g,b=Color(key);cfg=saved;return r,g,b,1
        end,setValue=function(r,g,b)
            if not Number(r) or not Number(g) or not Number(b) or r<0 or r>1 or g<0 or g>1 or b<0 or b>1 then return end
            local s=Settings();s.colors=Table(s.colors) and s.colors or {};s.colors[key]={r,g,b}
            cfg=s;W.Paint();if NS.RepaintEllesmereWarnings then NS.RepaintEllesmereWarnings() end
        end}
    end
    local function Toggle(text,key,tip,disabled,need)
        return {type='toggle',text=text,tooltip=tip,disabled=disabled or Off,disabledTooltip=need or 'Weapon Enchants',
            getValue=function() return Settings()[key] end,setValue=function(v) Set(key,v) end}
    end
    local function Dropdown(text,key,values,order,tip,disabled,need)
        return {type='dropdown',text=text,values=values,order=order,tooltip=tip,disabled=disabled or Off,disabledTooltip=need or 'Weapon Enchants',
            getValue=function() return Settings()[key] end,setValue=function(v) Set(key,v) end}
    end
    local function Slider(text,key,tip,disabled,need)
        return {type='slider',text=text,min=LIMITS[key][1],max=LIMITS[key][2],step=1,tooltip=tip,disabled=disabled or Off,disabledTooltip=need or 'Weapon Enchants',
            getValue=function() return Settings()[key] end,setValue=function(v) Set(key,v) end}
    end
    local stoneRow=W.StoneRow(class)
    local master={type='toggle',text='Weapon Enchants',
        tooltip=stoneRow and 'One icon per weapon: the poison, imbue, stone or oil on it, its time left, charges and how many you carry. Click to apply.'
            or 'One icon per weapon with its sharpening stone, weightstone or oil: time left and how many you carry, plus reminders when one is missing or running out. Click to apply.',
        getValue=function() return Settings().enabled end,setValue=function(v) Set('enabled',v) end}
    master.swatches={Swatch('active','Active Color'),Swatch('expiring','Expiring Color'),Swatch('low','Low Charges Color'),Swatch('missing','Missing Color')}
    master.preview={tip='Preview the weapon icons',show=NS.PreviewEllesmereWeaponEnchants,duration=3,disabled=Off,disabledTooltip='Weapon Enchants'}
    master.cog={title='Weapon Enchant Layout',disabled=Off,disabledTooltip='Weapon Enchants',rows={
        {type='slider',label='Icon Size',min=20,max=48,step=1,get=function() return Settings().size end,set=function(v) Set('size',v) end},
        {type='slider',label='Spacing',min=0,max=12,step=1,get=function() return Settings().spacing end,set=function(v) Set('spacing',v) end},
        {type='dropdown',label='Orientation',values={horizontal='Horizontal',vertical='Vertical'},order={'horizontal','vertical'},
            get=function() return Settings().orientation end,set=function(v) Set('orientation',v) end},
        {type='toggle',label='Show Off Hand',get=function() return Settings().offHand end,set=function(v) Set('offHand',v) end}}}
    Row(master,Dropdown('Weapon Enchant Visibility','visibility',{always='Always',combat='In Combat',mouseover='Mouseover',attention='Needs Attention'},
        {'always','combat','mouseover','attention'},'Needs Attention shows the icons only while an enchant is missing, expiring or low on charges.'))
    local function NoMissing() return Off() or not Settings().missingCue end
    Row(Toggle('Missing Enchant Cue','missingCue','One line when a weapon has no poison, imbue, stone or oil to hand. Out of combat only unless the next option is on; quiet while mounted, dead or on a taxi.'),
        Toggle('Missing Cue In Combat','missingCombat','Also warn about a missing enchant during combat.',NoMissing,'Missing Enchant Cue'))
    Row(Toggle('Expiring Cue','expiringCue','A warning when an enchant has less time left than this.'),
        Slider('Expiring At (Minutes)','expiringMinutes',nil,function() return Off() or not Settings().expiringCue end,'Expiring Cue'))
    Row(Toggle('Low Charges Cue','lowChargesCue','A warning when a poison has this many charges or fewer.'),
        Slider('Low Charges At','lowCharges',nil,function() return Off() or not Settings().lowChargesCue end,'Low Charges Cue'))
    Row(Toggle('Out Of Items Cue','noItemsCue','While resting or at a vendor: says when you carry none of the poison, stone or oil to apply next.'),
        (function()
            local d=Dropdown('Weapon Enchant Sound','sound',SOUND_VALUES,SOUND_ORDER,'Plays when a weapon enchant warning appears (None: the warning lane sound).')
            d.setValue=function(v) Set('sound',v);if v~='none' and NS.PlayEllesmereCueSound then NS.PlayEllesmereCueSound(v,'fhkWeaponPreview') end end
            return d
        end)())
    if class=='ROGUE' then
        local values,order={auto='Auto (Last Used)'},{'auto'}
        for _,k in ipairs(POISON_ORDER) do values[k]=FAMILIES[k].name;order[#order+1]=k end
        local tip='The poison the icon applies: the highest rank in your bags for your level. Poisons need the Poisons skill (level 20).'
        Row(Dropdown('Main Hand Poison','mainPoison',values,order,tip),Dropdown('Off Hand Poison','offPoison',values,order,tip))
    end
    if class=='SHAMAN' then
        local values,order={auto='Auto (Last Used)'},{'auto'}
        for _,k in ipairs(IMBUE_ORDER) do if W.ImbueKnown(k) then values[k]=FAMILIES[k].name;order[#order+1]=k end end
        Row(Dropdown('Preferred Imbue','imbue',values,order,'The main hand imbue the icon casts (highest rank you know). Only imbues you know are listed.'),
            Toggle('Click To Apply','click','Click an icon out of combat to apply the poison, imbue, stone or oil.'))
        Row(Toggle('Stone And Oil Reminder','stones','Treat a missing sharpening stone, weightstone or oil as missing (off hand, or main hand before your first imbue).'),
            EUI.BlankRowCfg and EUI.BlankRowCfg() or {type='label',text=''})
    elseif class=='ROGUE' then
        Row(Toggle('Click To Apply','click','Click an icon out of combat to apply the poison, imbue, stone or oil.'),
            Toggle('Stone And Oil Reminder','stones','Before you learn Poisons: treat a missing sharpening stone, weightstone or oil as missing.'))
    else
        -- Other classes: the master toggle is the stone and oil reminder (S38), so no extra row.
        Row(Toggle('Click To Apply','click','Click an icon out of combat to apply the stone or oil.'),EUI.BlankRowCfg and EUI.BlankRowCfg() or {type='label',text=''})
    end
    local values,order={auto='Auto (Fits The Weapon)'},{'auto'}
    for _,k in ipairs(STONE_ORDER) do
        if not FAMILIES[k].class or FAMILIES[k].class==class then values[k]=FAMILIES[k].name;order[#order+1]=k end
    end
    Row(Dropdown('Preferred Stone Or Oil','stone',values,order,'Auto picks what you carry that fits the weapon: sharpening stones for edged weapons, weightstones for blunt ones, or an oil.',
            stoneRow and function() return Off() or not Settings().stones end or nil,stoneRow and 'Stone And Oil Reminder' or nil),
        {type='button',text='Reset Weapon Enchants',tooltip='Restores every Weapon Enchants setting and color except the on/off toggle and the position.',onClick=function()
            local s=Settings()
            for k,v in pairs(DEFAULTS) do if k~='enabled' then s[k]=v end end
            s.colors=nil;NS.SyncEllesmereWeaponEnchants()
        end})
    Row({type='label',text='Move the icons in Unlock Mode: Weapon Enchants'},EUI.BlankRowCfg and EUI.BlankRowCfg() or {type='label',text=''})
end

local boot=CreateFrame('Frame')
boot:RegisterEvent('PLAYER_LOGIN')
boot:SetScript('OnEvent',function(self) self:UnregisterAllEvents();NS.SyncEllesmereWeaponEnchants() end)
