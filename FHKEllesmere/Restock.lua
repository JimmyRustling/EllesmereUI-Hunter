-- Vendor Restock categories (scenario review 2026-10-06 sections 4, 5 and 12; player: "auto buy
-- food/drink up to x amount 1 stack 2 stacks, mages have conjure so no reason for them to ever be
-- out"). Planners on the engine in AmmoBuy.lua (NS.EllesmereRestock), which owns combat, Shift,
-- the merchant closing, the visit budget, bag space, bundles and the no-gain guard. Every
-- category is off by default; while all are off the engine registers nothing.
--
--   Class Reagents (priority 2): ClassStock's KITS entries that carry a Keep (bought reagents,
--     never stones, conjures or gems). The top-rank seed or candle. Minimum pass to Low (the
--     same number as the Class Supplies cue), fill pass to Keep. Thieves' Tools is one-time.
--   Drink (priority 3, mana users) and Food (priority 4, every class): offers found at runtime
--     (item class 0 / 5 whose use spell is named like spell 430 "Drink" or 433 "Food"; buff food
--     is skipped). Keep in stacks or a count (default 1 stack). Tiers by required level
--     1/5/15/25/35/45/55; a better tier within Levels Ahead at 75% XP buys only the Bridge
--     Amount; the first visit after a tier unlocks buys at least that much of it; lower grade
--     counts with Use Up Old Stock (never 2 or more tiers down). Conjured food and water count.
--     A mage who knows Conjure Water / Food pauses Drink / Food unless Buy Anyway is on.
--   Pet Food (priority 5, hunters; was PetFood's own Auto-Buy): Food Choice and Keep Pet Food,
--     a per-family diet cache (per character) so it restocks with the pet dismissed, and a
--     reservation: the last 3 player foods the engine bought are not pet food while the
--     player's food is at or under their Food Keep (S19).
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end
local E=NS.EllesmereRestock
if type(E)~='table' or type(E.Register)~='function' then return end
local R={}
NS.Restock=R

local function Plain(v) return not (issecretvalue and issecretvalue(v)) end
local function Num(v) return Plain(v) and type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function Clean(ok,...)
    if not ok then return end
    for i=1,select('#',...) do if not Plain((select(i,...))) then return end end
    return ...
end
local function Read(fn,...)
    if type(fn)~='function' then return end
    return Clean(pcall(fn,...))
end
local function Now() local t=Read(_G.GetTime);return Num(t) and t or 0 end
local function Bags() return _G.NUM_BAG_SLOTS or 4 end
local function Say(text)
    local chat=_G.DEFAULT_CHAT_FRAME
    if chat and chat.AddMessage then chat:AddMessage('|cffdda880FHK|r '..text) end
end
local function Class() return select(2,Read(_G.UnitClass,'player')) end
R.Class=Class
local function Refresh() if EUI.RefreshPage then pcall(EUI.RefreshPage,EUI) end end
-- name, itemLevel, minLevel, stack size, quality (each nil when unknown).
local function ItemInfo(id)
    if not Num(id) then return end
    local name,_,quality,itemLevel,minLevel,_,_,stack=Read(C_Item and C_Item.GetItemInfo or _G.GetItemInfo,id)
    return type(name)=='string' and name or nil,Num(itemLevel) and itemLevel or nil,Num(minLevel) and minLevel or nil,
        Num(stack) and stack>0 and stack or nil,Num(quality) and quality or nil
end
local function Instant(id)
    if not Num(id) then return end
    local _,_,_,_,_,classID,subclassID=Read(C_Item and C_Item.GetItemInfoInstant or _G.GetItemInfoInstant,id)
    if Num(classID) and Num(subclassID) then return classID,subclassID end
end
local function MaxStack(id)
    local n=Read(C_Item and C_Item.GetItemMaxStackSizeByID,id)
    if Num(n) and n>0 then return n end
    local _,_,_,stack=ItemInfo(id)
    return stack
end
local function ItemCount(id)
    local n=Read(C_Item and C_Item.GetItemCount or _G.GetItemCount,id)
    if Num(n) then return n end
end
local function Known(id)
    return Read(C_SpellBook and C_SpellBook.IsSpellKnown,id)==true or Read(_G.IsPlayerSpell,id)==true
end

-------------------------------------------------------------------------------
-- Settings: FHKEllesmereDB.vendorRestock (profile). Character state:
-- FHKEllesmereDB.restockCharacter (rawset, per character).
-------------------------------------------------------------------------------
local CAT_DEFAULTS={enabled=false,unit='stacks',stacks=1,count=20,bridge=true,bridgeLevels=1,bridgeAmount=5,useOld=true,buyAnyway=false}
local PET_DEFAULTS={enabled=false,unit='stacks',stacks=1,count=20}
local LIMITS={stacks={1,5},count={1,200},bridgeLevels={1,3},bridgeAmount={5,20},keep={1,100},low={0,40}}
local CHOICES={unit={stacks=true,count=true}}
R.LIMITS=LIMITS
local function Valid(t,defaults)
    for k,v in pairs(defaults) do
        local x=t[k]
        if type(v)=='boolean' then if not Plain(x) or type(x)~='boolean' then t[k]=v end
        elseif LIMITS[k] then if not Num(x) or x<LIMITS[k][1] or x>LIMITS[k][2] then t[k]=v else t[k]=math.floor(x) end
        elseif CHOICES[k] then if not Plain(x) or not CHOICES[k][x] then t[k]=v end end
    end
end
-- Bought reagents the engine may restock: ClassStock KITS entries with a Keep (section 9).
local function Kit(class)
    local S=NS.ClassStock
    local kit=S and type(S.KITS)=='table' and class and S.KITS[class]
    if type(kit)~='table' then return nil end
    for _,e in ipairs(kit) do if e.keep then return kit,S end end
    return nil
end
R.Kit=Kit
local function ReagentKey(key)
    local S=NS.ClassStock
    if not (S and type(S.KITS)=='table') then return true end -- unknown yet: keep the value
    for _,kit in pairs(S.KITS) do for _,e in ipairs(kit) do if e.key==key and e.keep then return true end end end
    return false
end
function NS.EllesmereVendorRestockSettings()
    if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end
    local s=FHKEllesmereDB.vendorRestock
    if type(s)~='table' then s={};FHKEllesmereDB.vendorRestock=s end
    for _,k in ipairs({'food','drink','petFood','reagents'}) do if type(s[k])~='table' then s[k]={} end end
    Valid(s.food,CAT_DEFAULTS);Valid(s.drink,CAT_DEFAULTS);Valid(s.petFood,PET_DEFAULTS)
    local g=s.reagents
    if not Plain(g.enabled) or type(g.enabled)~='boolean' then g.enabled=false end
    if type(g.items)~='table' then g.items={} end
    if type(g.keeps)~='table' then g.keeps={} end
    for k,v in pairs(g.items) do if not Plain(v) or type(v)~='boolean' or not ReagentKey(k) then g.items[k]=nil end end
    for k,v in pairs(g.keeps) do if not Num(v) or v<LIMITS.keep[1] or v>LIMITS.keep[2] or not ReagentKey(k) then g.keeps[k]=nil end end
    -- Once per profile: PetFood's own Auto-Buy Pet Food and Keep Pet Food move here (S21).
    if s.petMigrated~=true then
        local old=FHKEllesmereDB.petFood
        if type(old)=='table' then
            if old.autoBuy==true then s.petFood.enabled=true end
            local keep=old.buyKeep
            if Num(keep) and keep>=LIMITS.count[1] and keep<=LIMITS.count[2] and (old.autoBuy==true or keep~=20) then
                s.petFood.unit='count';s.petFood.count=math.floor(keep)
            end
            old.autoBuy=nil;old.buyKeep=nil
        end
        s.petMigrated=true
    end
    return s
end
local Settings=NS.EllesmereVendorRestockSettings
-- Character state: player food set (last 3 IDs), diet cache per pet family, one-time buys,
-- last tier seen per category, conjure messages said.
local function Char()
    if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end
    local c=rawget(FHKEllesmereDB,'restockCharacter')
    if type(c)~='table' then c={};rawset(FHKEllesmereDB,'restockCharacter',c) end
    local list=c.playerFood
    local ok=type(list)=='table' and #list<=3
    if ok then for i=1,#list do if not Num(list[i]) then ok=false end end end
    if not ok then
        local clean={}
        if type(list)=='table' then for _,id in ipairs(list) do if Num(id) and #clean<3 then clean[#clean+1]=id end end end
        c.playerFood=clean
    end
    for _,k in ipairs({'diet','oneTime','seen','told'}) do if type(c[k])~='table' then c[k]={} end end
    return c
end
R.Char=Char

-------------------------------------------------------------------------------
-- Classes, conjures and what an item is.
-------------------------------------------------------------------------------
local MANA={PRIEST=true,MAGE=true,WARLOCK=true,DRUID=true,PALADIN=true,SHAMAN=true,HUNTER=true}
function R.Available(kind)
    local class=Class()
    if kind=='food' then return class~=nil end
    if kind=='drink' then return MANA[class]==true end
    if kind=='petFood' then return class=='HUNTER' end
    if kind=='reagents' then return Kit(class)~=nil end
    return false
end
local CONJURE={food={587,597,990,6129,10144,10145,28612},drink={5504,5505,5506,6127,10138,10139,10140,468766}}
-- A mage who knows any rank (a Forever rank not listed is found by name).
function R.Conjures(kind)
    if Class()~='MAGE' or not CONJURE[kind] then return false end
    for _,id in ipairs(CONJURE[kind]) do if Known(id) then return true end end
    local name=Read(C_Spell and C_Spell.GetSpellName,CONJURE[kind][1])
    local info=type(name)=='string' and Read(C_Spell and C_Spell.GetSpellInfo,name)
    return type(info)=='table' and Num(info.spellID) and Known(info.spellID) or false
end
function R.Paused(kind)
    return (kind=='food' or kind=='drink') and Settings()[kind].buyAnyway~=true and R.Conjures(kind)
end
-- Conjured food and water count in every class's bags (water from a party mage).
local CONJURED={[5349]='food',[1113]='food',[1114]='food',[1487]='food',[8075]='food',[8076]='food',[22895]='food',
    [5350]='drink',[2288]='drink',[2136]='drink',[3772]='drink',[8077]='drink',[8078]='drink',[8079]='drink',[231778]='drink'}
local SPELL={food=433,drink=430}
local WELL_FED=19705 -- "Well Fed": buff food names it in its use spell's text
local BUFF_SPELLS={[25660]=true}
local kindCache={}
-- true/false when known; second value false while the spell text is still loading.
local function BuffFood(spellID)
    if not Num(spellID) then return false,true end
    if BUFF_SPELLS[spellID] then return true,true end
    local desc=Read(C_Spell and C_Spell.GetSpellDescription,spellID)
    local fed=Read(C_Spell and C_Spell.GetSpellName,WELL_FED)
    if type(desc)~='string' or desc=='' or type(fed)~='string' or fed=='' then return false,false end
    return desc:lower():find(fed:lower(),1,true)~=nil,true
end
-- 'food', 'drink', false (something else) or nil (unknown: never counted, never bought).
function R.Kind(id)
    if not Num(id) then return nil end
    local k=CONJURED[id]
    if k then return k end
    k=kindCache[id]
    if k~=nil then return k end
    local classID,subclassID=Instant(id)
    if not classID then return nil end
    if classID~=0 or subclassID~=5 then kindCache[id]=false;return false end
    local name,spellID=Read(C_Item and C_Item.GetItemSpell,id)
    local food,drink=Read(C_Spell and C_Spell.GetSpellName,SPELL.food),Read(C_Spell and C_Spell.GetSpellName,SPELL.drink)
    if type(name)~='string' or type(food)~='string' or type(drink)~='string' then return nil end
    local out,sure=false,true
    if name==drink then out='drink'
    elseif name==food then
        local buff
        buff,sure=BuffFood(spellID)
        out=not buff and 'food' or false
    end
    if sure then kindCache[id]=out end
    return out
end
R.CONJURED=CONJURED

-------------------------------------------------------------------------------
-- Pet diet cache (S20) and the player food reservation (S19).
-------------------------------------------------------------------------------
-- Item.ItemPetFoodID of the standard vendor food (DB2 1.60.1.70205, E1): 1 meat, 2 fish,
-- 3 cheese, 4 bread, 5 fungus, 6 fruit. One answer for an item teaches its whole column.
local DIET_BIT={}
for bit,ids in pairs({[1]={117,2287,3770,3771,4599,8952,238638},[2]={787,4592,4593,4594,21552,8957},
    [3]={2070,414,422,1707,3927,8932},[4]={4540,4541,4542,4544,4601,8950},[5]={4604,4605,4606,4607,4608,8948},
    [6]={4536,4537,4538,4539,4602,8953}}) do for _,id in ipairs(ids) do DIET_BIT[id]=bit end end
R.DIET_BIT=DIET_BIT
local DIET_MAX=300
local function FamilyKey()
    local name,id=Read(_G.UnitCreatureFamily,'pet')
    if Num(id) then return id end
    if type(name)=='string' and name~='' then return name end
end
local function PetOut() return Read(_G.UnitExists,'pet')==true and Read(_G.UnitIsDead,'pet')~=true end
-- Learn one CanPetEatItem answer for the current pet's family (PetFood's hook and vendor reads).
function R.Learn(id,eats)
    if not Num(id) or type(eats)~='boolean' then return end
    local fam=FamilyKey()
    if fam==nil then return end
    local c=Char()
    c.lastFamily=fam
    local d=c.diet[fam]
    if type(d)~='table' then d={};c.diet[fam]=d end
    if type(d.items)~='table' then d.items={} end
    if type(d.bits)~='table' then d.bits={} end
    if not Num(d.n) then d.n=0 end
    if d.items[id]==nil then
        if d.n>=DIET_MAX then return end
        d.n=d.n+1
    end
    d.items[id]=eats
    if DIET_BIT[id] then d.bits[DIET_BIT[id]]=eats end
end
function R.DietEats(fam,id)
    local d=fam~=nil and Char().diet[fam]
    if type(d)~='table' then return nil end
    local v=type(d.items)=='table' and d.items[id]
    if type(v)=='boolean' then return v end
    v=DIET_BIT[id] and type(d.bits)=='table' and d.bits[DIET_BIT[id]]
    if type(v)=='boolean' then return v end
    return nil
end
-- Can the hunter's pet eat this? Live with the pet out (and learnt), else the cached diet.
function R.PetEats(id)
    if PetOut() then
        local v=Read(C_PetInfo and C_PetInfo.CanPetEatItem,id)
        if type(v)=='boolean' then R.Learn(id,v);return v end
        return nil
    end
    return R.DietEats(Char().lastFamily,id)
end
local function FoodKeep(cfg,id)
    if cfg.unit=='stacks' then return cfg.stacks*(MaxStack(id) or 20) end
    return cfg.count
end
-- The player's food: a set of item IDs and the Food Keep in items, or nil (Food off, none bought).
function NS.EllesmerePlayerFoodReservation()
    local db=type(FHKEllesmereDB)=='table' and FHKEllesmereDB.vendorRestock
    if type(db)~='table' or type(db.food)~='table' or db.food.enabled~=true then return nil end
    local list=Char().playerFood
    if #list==0 then return nil end
    local set={}
    for _,id in ipairs(list) do set[id]=true end
    return set,FoodKeep(Settings().food,list[1])
end
local function RememberPlayerFood(id)
    local list=Char().playerFood
    for i=#list,1,-1 do if list[i]==id then table.remove(list,i) end end
    table.insert(list,1,id)
    while #list>3 do table.remove(list) end
    if NS.PetFood and NS.PetFood.Invalidate then NS.PetFood.Invalidate() end
end
R.RememberPlayerFood=RememberPlayerFood

-------------------------------------------------------------------------------
-- Food and Drink planners.
-------------------------------------------------------------------------------
local TIERS={1,5,15,25,35,45,55}
local function Tier(minLevel)
    local m=Num(minLevel) and math.max(minLevel,1) or 1
    local n=0
    for i,t in ipairs(TIERS) do if m>=t then n=i end end
    return n
end
R.Tier=Tier
local function XPFraction()
    local xp,max=Read(_G.UnitXP,'player'),Read(_G.UnitXPMax,'player')
    if Num(xp) and Num(max) and max>0 then return xp/max end
end
-- The bridge: a better tier fewer than Levels Ahead away, or exactly that far at 75% XP.
function R.Bridges(cfg,level,nextLevel)
    if not cfg.bridge or not Num(nextLevel) or not Num(level) then return false end
    local gap=nextLevel-level
    if gap<1 then return false end
    if gap<cfg.bridgeLevels then return true end
    if gap>cfg.bridgeLevels then return false end
    local frac=XPFraction()
    return frac~=nil and frac>=.75
end
local function Better(a,b)
    if not b then return true end
    if a.minLevel~=b.minLevel then return a.minLevel>b.minLevel end
    if a.petEats~=b.petEats then return not a.petEats end
    if (a.quality==1)~=(b.quality==1) then return a.quality==1 end
    return a.unit<b.unit
end
-- Bag stock of the kind: total that counts toward Keep, the best tier's count, the lower-grade
-- part and the raw count (the engine's gain check). nil when anything is unreadable. A hunter
-- with Pet Food on: food the pet eats that is not the player's (S19 set) is the pet's.
local function Stock(state)
    local C=C_Container
    if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return nil end
    local total,best,older,raw=0,0,0,0
    local mine
    if state.petShare then
        mine={}
        for _,id in ipairs(Char().playerFood) do mine[id]=true end
    end
    for bag=0,Bags() do
        local slots=Read(C.GetContainerNumSlots,bag)
        if not Num(slots) then return nil end
        for slot=1,slots do
            local info=Read(C.GetContainerItemInfo,bag,slot)
            if type(info)=='table' then
                local id=info.itemID
                if not Num(id) then return nil end
                local k=R.Kind(id)
                if k==nil then return nil end
                if k==state.kind and mine and not mine[id] then
                    local eats=state.petShare[id]
                    if eats==nil then eats=R.PetEats(id)==true;state.petShare[id]=eats end
                    if eats then k=false end
                end
                if k==state.kind then
                    local n=info.stackCount
                    if not Num(n) then return nil end
                    raw=raw+n
                    local _,_,minLevel=ItemInfo(id)
                    if not minLevel then return nil end
                    if minLevel<=state.level then
                        local t=Tier(minLevel)
                        if t>=state.pick.tier then best=best+n;total=total+n
                        elseif state.cfg.useOld and state.myTier-t<2 then older=older+n;total=total+n end
                    end
                end
            end
        end
    end
    return total,best,older,raw
end
R.Stock=Stock
local function Consumable(kind,label,priority)
    local P={key=kind,label=label,priority=priority}
    function P.Enabled()
        return Settings()[kind].enabled==true and R.Available(kind) and not R.Paused(kind)
    end
    function P.Begin()
        local cfg=Settings()[kind]
        local level=Read(_G.UnitLevel,'player')
        if not Num(level) then return nil end
        local myTier=Tier(level)
        -- A hunter's own food: prefer what the pet will not eat (S19).
        local hunter=kind=='food' and Class()=='HUNTER'
        local best,nextLevel,nextName
        for i=1,E.NumOffers() do
            local o=E.Offer(i)
            if o and o.price>0 and o.purchasable and not o.extended and R.Kind(o.id)==kind then
                local name,_,minLevel,_,quality=ItemInfo(o.id)
                if minLevel then -- an uncached item is never bought blind
                    minLevel=math.max(minLevel,1)
                    o.name=o.name or name;o.minLevel=minLevel;o.tier=Tier(minLevel);o.unit=o.price/o.bundle;o.quality=quality or 1
                    if minLevel>level then
                        if not nextLevel or minLevel<nextLevel then nextLevel,nextName=minLevel,o.name end
                    elseif o.usable and o.available~=0 and myTier-o.tier<2 then
                        o.petEats=hunter and R.PetEats(o.id)==true or false
                        if Better(o,best) then best=o end
                    end
                end
            end
        end
        if not best then return nil end
        for _,t in ipairs(TIERS) do if t>level and (not nextLevel or t<nextLevel) then nextLevel,nextName=t,nil end end
        local keep=FoodKeep(cfg,best.id)
        if not Num(keep) then return nil end
        local state={kind=kind,cfg=cfg,level=level,myTier=myTier,pick=best,keep=keep,added=0}
        if hunter and NS.EllesmereRestockPetFoodOn and NS.EllesmereRestockPetFoodOn() then state.petShare={} end
        local total,bestCount=Stock(state)
        if not total then return nil end
        if R.Bridges(cfg,level,nextLevel) then state.bridge,state.bridgeName=nextLevel,nextName end
        local seen=Char().seen[kind]
        state.newTier=(not Num(seen) or best.minLevel>seen) and bestCount<cfg.bridgeAmount
        return state
    end
    function P.Measure(state) local _,_,_,raw=Stock(state);return raw end
    function P.Next(state,pass)
        local total,best=Stock(state)
        if not total then return nil end
        local cfg,pick=state.cfg,state.pick
        local need=(pass=='minimum' and math.min(pick.bundle,state.keep) or state.keep)-total
        if state.newTier then need=math.max(need,cfg.bridgeAmount-best) end
        if need<=0 then return nil end
        need=math.ceil(need/pick.bundle)*pick.bundle
        if state.bridge then need=math.min(need,math.floor((cfg.bridgeAmount-state.added)/pick.bundle)*pick.bundle) end
        if need<=0 then return nil end
        return {index=pick.index,quantity=need,reason=state.bridge and 'bridge' or state.newTier and 'newTier' or pass}
    end
    function P.Purchased(state,count,offer)
        state.added=state.added+count
        if kind=='food' and offer and Num(offer.id) then RememberPlayerFood(offer.id) end
    end
    function P.Summary(state,bought)
        local n=0
        for _,b in ipairs(bought) do n=n+b.count end
        local text=n..' '..(state.pick.name or kind)
        if state.bridge then text=text..' ('..(state.bridgeName or ('better '..kind))..' at '..state.bridge..')' end
        local _,_,older=Stock(state)
        if Num(older) and older>0 then text=text..' (carrying '..older..' older)' end
        return text
    end
    function P.Finish(state,bought)
        local _,best=Stock(state)
        local seen=Char().seen
        if #bought>0 or (Num(best) and best>=state.cfg.bridgeAmount) then
            seen[kind]=math.max(Num(seen[kind]) and seen[kind] or 0,state.pick.minLevel)
        end
    end
    E.Register(P)
    return P
end
R.drink=Consumable('drink','Auto-Buy Drink',3)
R.food=Consumable('food','Auto-Buy Food',4)

-------------------------------------------------------------------------------
-- Class Reagents planner.
-------------------------------------------------------------------------------
function R.ReagentOn(e,g)
    g=g or Settings().reagents
    local v=g.items[e.key]
    if type(v)=='boolean' then return v end
    return e.buy==true
end
function R.ReagentKeep(e,g)
    g=g or Settings().reagents
    if e.oneTime then return 1 end
    local v=g.keeps[e.key]
    return Num(v) and v or e.keep or 1
end
-- The same number the Class Supplies cue warns below (S22).
function R.ReagentLow(e)
    local S=NS.ClassStock
    if e.oneTime then return 1 end
    if S and S.Threshold and NS.EllesmereClassStockSettings then return S.Threshold(e.group,NS.EllesmereClassStockSettings(),e) end
    return e.low or 1
end
-- Will the engine buy this ClassStock entry (so the Smart cue stays quiet at that vendor)?
function NS.EllesmereRestockBuys(key)
    local db=type(FHKEllesmereDB)=='table' and FHKEllesmereDB.vendorRestock
    if type(db)~='table' or type(db.reagents)~='table' or db.reagents.enabled~=true then return false end
    local kit=Kit(Class())
    if not kit then return false end
    local g=Settings().reagents
    for _,e in ipairs(kit) do
        if e.key==key and e.keep then return R.ReagentOn(e,g) and not (e.oneTime and Char().oneTime[e.key]==true) end
    end
    return false
end
local function Count(x)
    local n=0
    for _,id in ipairs(x.r.countItems or {x.item}) do
        local c=ItemCount(id)
        if not c then return nil end
        n=n+c
    end
    return n
end
local RG={key='reagents',label='Auto-Buy Class Reagents',priority=2}
R.reagents=RG
function RG.Enabled() return Settings().reagents.enabled==true and Kit(Class())~=nil end
function RG.Measure(state)
    local n=0
    for _,x in ipairs(state.list) do local c=Count(x);if not c then return nil end;n=n+c end
    return n
end
function RG.Begin()
    local kit,S=Kit(Class())
    if not kit or type(S.Resolve)~='function' then return nil end
    local g,c=Settings().reagents,Char()
    local sold={}
    for i=1,E.NumOffers() do local id=Read(_G.GetMerchantItemID,i);if Num(id) and not sold[id] then sold[id]=i end end
    local list={}
    for _,e in ipairs(kit) do
        -- Made items (stones, conjures, gems) have no Keep and are never bought.
        if e.keep and R.ReagentOn(e,g) and not (e.oneTime and c.oneTime[e.key]==true) then
            local r=S.Resolve(e)
            local item=r and r.item
            if item and sold[item] then list[#list+1]={entry=e,r=r,item=item,index=sold[item]} end
        end
    end
    if #list==0 then return nil end
    local state={list=list,g=g}
    -- A one-time item already carried is done for good.
    for _,x in ipairs(list) do
        if x.entry.oneTime then local n=Count(x);if n and n>=1 then c.oneTime[x.entry.key]=true;x.done=true end end
    end
    if not RG.Measure(state) then return nil end
    return state
end
function RG.Next(state,pass)
    local now=Now()
    for _,x in ipairs(state.list) do
        if not x.done and (E.skipUntil[x.item] or 0)<=now then
            local n=Count(x)
            if not n then return nil end
            local target=pass=='minimum' and R.ReagentLow(x.entry) or R.ReagentKeep(x.entry,state.g)
            if x.entry.oneTime then target=1 end
            if n<target then
                local o=E.Offer(x.index)
                if o and o.id==x.item then
                    return {index=x.index,quantity=math.ceil((target-n)/o.bundle)*o.bundle,reason=pass}
                end
                x.done=true -- the vendor list moved or cannot be read
            end
        end
    end
    return nil
end
function RG.Purchased(state,_,offer)
    for _,x in ipairs(state.list) do
        if offer and x.item==offer.id and x.entry.oneTime then Char().oneTime[x.entry.key]=true;x.done=true end
    end
end
function RG.Summary(_,bought)
    local order,by={},{}
    for _,b in ipairs(bought) do
        if not by[b.id] then by[b.id]={n=0,name=b.name or (ItemInfo(b.id)) or ('item '..b.id)};order[#order+1]=b.id end
        by[b.id].n=by[b.id].n+b.count
    end
    local parts={}
    for _,id in ipairs(order) do parts[#parts+1]=by[id].n..' '..by[id].name end
    return table.concat(parts,', ')
end
E.Register(RG)

-------------------------------------------------------------------------------
-- Pet Food planner (moved from PetFood.lua's Auto-Buy).
-------------------------------------------------------------------------------
local PF={key='petFood',label='Auto-Buy Pet Food',priority=5}
R.petFood=PF
function PF.Enabled() return Class()=='HUNTER' and Settings().petFood.enabled==true end
-- Pet food in the bags: available to the pet (after the player's reservation) and raw.
local function PetStock(state)
    local C=C_Container
    if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return nil end
    local set,keep=NS.EllesmerePlayerFoodReservation()
    local raw,reservedEdible,reservedAll=0,0,0
    for bag=0,Bags() do
        local slots=Read(C.GetContainerNumSlots,bag)
        if not Num(slots) then return nil end
        for slot=1,slots do
            local info=Read(C.GetContainerItemInfo,bag,slot)
            if type(info)=='table' then
                local id,n=info.itemID,info.stackCount
                if not Num(id) or not Num(n) then return nil end
                local eats=state.eats[id]
                if eats==nil then
                    eats=R.PetEats(id)
                    if eats==nil and state.out then return nil end
                    eats=eats==true;state.eats[id]=eats
                end
                if eats then raw=raw+n end
                if set and set[id] then reservedAll=reservedAll+n;if eats then reservedEdible=reservedEdible+n end end
            end
        end
    end
    local hold=set and math.min(reservedEdible,math.max(0,keep-(reservedAll-reservedEdible))) or 0
    return raw-hold,raw
end
R.PetStock=PetStock
function PF.Begin()
    local cfg,c=Settings().petFood,Char()
    local out=PetOut()
    if out then
        local fam=FamilyKey()
        if fam~=nil then c.lastFamily=fam end
        local lvl=Read(_G.UnitLevel,'pet')
        if Num(lvl) then c.lastPetLevel=lvl end
    elseif c.lastFamily==nil then return nil end
    local offers={}
    for i=1,E.NumOffers() do
        local o=E.Offer(i)
        if o and o.price>0 and o.purchasable and not o.extended and o.usable and o.available~=0 and R.PetEats(o.id)==true then
            local name,itemLevel=ItemInfo(o.id)
            offers[#offers+1]={index=i,id=o.id,name=o.name or name,level=itemLevel,price=o.price/o.bundle,count=0,bag=0,slot=i,bundle=o.bundle}
        end
    end
    if #offers==0 then return nil end
    local petLevel=out and Read(_G.UnitLevel,'pet') or c.lastPetLevel
    local state={cfg=cfg,offers=offers,petLevel=Num(petLevel) and petLevel or nil,out=out,eats={},added=0}
    if not R.PetPick(state) or not PetStock(state) then return nil end
    return state
end
-- The pick is made per step: the Food planner (same pass, earlier) may just have made an offer
-- the player's own food. Food Choice ranks what is left; the player's food only as a last resort.
function R.PetPick(state)
    local set=NS.EllesmerePlayerFoodReservation() or {}
    local list,reserved={},{}
    for _,f in ipairs(state.offers) do if set[f.id] then reserved[#reserved+1]=f else list[#list+1]=f end end
    if #list==0 then list=reserved end
    local F=NS.PetFood
    local choice=NS.EllesmerePetFoodSettings and NS.EllesmerePetFoodSettings().choice
    local pick
    if F and F.Rank then pick=(choice=='cheap' and F.RankCheap or F.Rank)(list,state.petLevel)[1] else pick=list[1] end
    local keep=pick and FoodKeep(state.cfg,pick.id)
    if not Num(keep) then return nil end
    state.pick,state.keep=pick,keep
    return pick
end
function PF.Measure(state) local _,raw=PetStock(state);return raw end
function PF.Next(state,pass)
    if not R.PetPick(state) then return nil end
    local avail=PetStock(state)
    if not avail then return nil end
    local need=(pass=='minimum' and math.min(state.pick.bundle,state.keep) or state.keep)-avail
    if need<=0 then return nil end
    return {index=state.pick.index,quantity=math.ceil(need/state.pick.bundle)*state.pick.bundle,reason=pass}
end
function PF.Purchased(state,count) state.added=state.added+count;if NS.PetFood and NS.PetFood.Invalidate then NS.PetFood.Invalidate() end end
function PF.Summary(state,bought)
    local n=0
    for _,b in ipairs(bought) do n=n+b.count end
    return n..' '..(state.pick.name or 'pet food')..' for your pet'
end
E.Register(PF)
function NS.EllesmereRestockPetFoodOn() return PF.Enabled() end

-------------------------------------------------------------------------------
-- Sync: the engine's events, the mage conjure watch and PetFood's diet hook.
-------------------------------------------------------------------------------
local watch
local KINDS={'drink','food'}
local MESSAGE={drink='Conjure Water learned: Drink restock paused.',food='Conjure Food learned: Food restock paused.'}
local function Watching()
    if Class()~='MAGE' then return false end
    local s,want=Settings(),false
    for _,kind in ipairs(KINDS) do
        local c=s[kind]
        if c.enabled and not c.buyAnyway then
            if R.Conjures(kind) then Char().told[kind]=true else want=true end
        end
    end
    return want
end
function R.OnSpells()
    local s,told=Settings(),Char().told
    for _,kind in ipairs(KINDS) do
        local c=s[kind]
        if c.enabled and not c.buyAnyway and R.Conjures(kind) and told[kind]~=true then told[kind]=true;Say(MESSAGE[kind]) end
    end
    NS.SyncEllesmereRestock()
end
function NS.SyncEllesmereRestock()
    Settings()
    if watch then watch:UnregisterAllEvents() end
    if Watching() then
        if not watch then watch=CreateFrame('Frame');watch:SetScript('OnEvent',function() R.OnSpells() end) end
        watch:RegisterEvent('SPELLS_CHANGED')
    end
    local F=NS.PetFood
    if F then
        F.OnEdible=PF.Enabled() and R.Learn or nil
        if F.Invalidate then F.Invalidate() end
    end
    E.Sync()
end
function R.State() return {watch=watch,engine=E.State()} end

-------------------------------------------------------------------------------
-- Options: Warnings > VENDOR RESTOCK (after the ammo rows), every class.
-------------------------------------------------------------------------------
local function KeepKey(c) return c.unit=='stacks' and ('s'..c.stacks) or ('c'..c.count) end
local function KeepValues(c)
    local values={s1='1 Stack (20)',s2='2 Stacks (40)',s3='3 Stacks (60)',s4='4 Stacks (80)',s5='5 Stacks (100)'}
    local counts={5,10,15}
    if c.unit=='count' then
        local have=false
        for _,n in ipairs(counts) do if n==c.count then have=true end end
        if not have then counts[#counts+1]=c.count;table.sort(counts) end
    end
    local order={}
    for _,n in ipairs(counts) do values['c'..n]=tostring(n);order[#order+1]='c'..n end
    for i=1,5 do order[#order+1]='s'..i end
    return values,order
end
local function SetKeep(c,key)
    if type(key)~='string' then return false end
    local u,n=key:match('^([sc])(%d+)$')
    n=tonumber(n)
    if u=='s' and n and n>=LIMITS.stacks[1] and n<=LIMITS.stacks[2] then c.unit,c.stacks='stacks',n;return true end
    if u=='c' and n and n>=LIMITS.count[1] and n<=LIMITS.count[2] then c.unit,c.count='count',n;return true end
    return false
end
R.SetKeep=SetKeep
local function AnyOn()
    if NS.EllesmereAmmoBuySettings and NS.EllesmereAmmoBuyAvailable and NS.EllesmereAmmoBuyAvailable() and NS.EllesmereAmmoBuySettings().enabled==true then return true end
    local s=Settings()
    for _,k in ipairs({'food','drink','reagents','petFood'}) do if s[k].enabled==true and R.Available(k) then return true end end
    return false
end
R.AnyOn=AnyOn
local NOUN={food='Food',drink='Drink',petFood='Pet Food'}
function NS.AddEllesmereRestockOptions(Row)
    local class=Class()
    local mana,hunter,kit=MANA[class]==true,class=='HUNTER',Kit(class)
    local blank=function() return EUI.BlankRowCfg and EUI.BlankRowCfg() or {type='label',text=''} end
    if EUI.IsSearchPrebuild and EUI.IsSearchPrebuild() then
        Row({type='label',text='Auto-Buy Food'},{type='label',text='Keep Food'})
        if mana then Row({type='label',text='Auto-Buy Drink'},{type='label',text='Keep Drink'}) end
        if kit then Row({type='label',text='Auto-Buy Class Reagents'},blank()) end
        if hunter then Row({type='label',text='Auto-Buy Pet Food'},{type='label',text='Keep Pet Food'}) end
        Row({type='label',text='Keep At Least (Gold)'},{type='label',text='Max Spend Per Visit'})
        Row({type='label',text='Leave Free Bag Slots'},{type='label',text='Reset Vendor Restock'})
        return
    end
    local function Sync() NS.SyncEllesmereRestock() end
    local function Cat(k) return Settings()[k] end
    local function SetCat(k,key,v)
        local c=Cat(k)
        if type(CAT_DEFAULTS[key])=='boolean' then if not Plain(v) or type(v)~='boolean' then return end
        elseif LIMITS[key] then if not Num(v) or v<LIMITS[key][1] or v>LIMITS[key][2] then return end;v=math.floor(v)
        else return end
        c[key]=v;Sync()
    end
    local function Consumables(k)
        local noun=NOUN[k]
        local title='Auto-Buy '..noun
        local mage=class=='MAGE' and (k=='food' or k=='drink')
        local function Off() return not Cat(k).enabled end
        local function Paused() return mage and R.Paused(k) end
        local tooltip=k=='petFood'
            and 'At a vendor that sells food your pet eats, tops it up to Keep Pet Food with Food Choice, even with the pet dismissed (its diet is remembered). Your own food is never counted as pet food while you are at or under Keep Food.'
            or ('At a vendor, buys the best '..noun:lower()..' you can use up to Keep '..noun..'. Close to a better tier it buys only a little. Conjured '..(k=='food' and 'food' or 'water')..' in your bags counts. Hold Shift as the vendor opens to skip.')
        local toggle={type='toggle',text=title,tooltip=tooltip,
            getValue=function() return Cat(k).enabled end,setValue=function(v) SetCat(k,'enabled',v==true);Refresh() end}
        if mage then
            toggle.disabled=Paused
            toggle.disabledTooltip='This option is paused: you conjure '..(k=='food' and 'food' or 'water')..'. Turn on Buy Anyway in its cog to buy '..noun:lower()..' too.'
        end
        local rows
        if k=='petFood' then
            rows={{type='dropdown',label='Food Choice',values={level='Closest To Pet Level',cheap='Cheapest'},order={'level','cheap'},
                tooltip='Closest To Pet Level pleases your pet most. Cheapest buys the lowest price that is no more than 20 levels below your pet. Shared with the Pet Food Button.',
                get=function() return NS.EllesmerePetFoodSettings and NS.EllesmerePetFoodSettings().choice or 'level' end,
                set=function(v) if (v=='level' or v=='cheap') and NS.EllesmerePetFoodSettings then NS.EllesmerePetFoodSettings().choice=v;if NS.SyncEllesmerePetFood then NS.SyncEllesmerePetFood() end end end}}
        else
            rows={{type='toggle',label='Use Up Old Stock',tooltip='Lower-grade '..noun:lower()..' you carry counts toward Keep (never two or more tiers behind).',
                    get=function() return Cat(k).useOld end,set=function(v) SetCat(k,'useOld',v==true) end},
                {type='toggle',label='Buy Less Before Better '..noun,tooltip='When better '..noun:lower()..' unlocks next level and you are 75% through this one, buys only the Bridge Amount.',
                    get=function() return Cat(k).bridge end,set=function(v) SetCat(k,'bridge',v==true) end},
                {type='slider',label='Levels Ahead',min=LIMITS.bridgeLevels[1],max=LIMITS.bridgeLevels[2],step=1,
                    get=function() return Cat(k).bridgeLevels end,set=function(v) SetCat(k,'bridgeLevels',v) end},
                {type='slider',label='Bridge Amount',min=LIMITS.bridgeAmount[1],max=LIMITS.bridgeAmount[2],step=5,
                    get=function() return Cat(k).bridgeAmount end,set=function(v) SetCat(k,'bridgeAmount',v) end}}
            if mage then
                rows[#rows+1]={type='toggle',label='Buy Anyway',tooltip='Buys '..noun:lower()..' even though you conjure it.',
                    get=function() return Cat(k).buyAnyway end,set=function(v) SetCat(k,'buyAnyway',v==true);Refresh() end}
            end
        end
        -- A paused mage still reaches Buy Anyway.
        toggle.cog={title=title,rows=rows,disabledTooltip=title,disabled=function() return Off() and not Paused() end}
        local values,order=KeepValues(Cat(k))
        Row(toggle,{type='dropdown',text='Keep '..noun,values=values,order=order,
            tooltip='How much to carry: a count, or whole stacks of the item you buy.',
            disabled=function() return Off() or Paused() end,disabledTooltip=title,
            getValue=function() return KeepKey(Cat(k)) end,setValue=function(v) if SetKeep(Cat(k),v) then Sync() end end})
    end
    Consumables('food')
    if mana then Consumables('drink') end
    if kit then
        local function Off() return not Cat('reagents').enabled end
        Row({type='toggle',text='Auto-Buy Class Reagents',
            tooltip='At a vendor that sells them, tops up the reagents below for the spells you know: first to Warn Below, then to Keep. Never stones, conjures or gems.',
            getValue=function() return Cat('reagents').enabled end,setValue=function(v) if type(v)~='boolean' then return end;Cat('reagents').enabled=v;Sync();Refresh() end},blank())
        local subs={}
        for _,e in ipairs(kit) do
            if e.keep then
                local key=e.key
                local t={type='toggle',text='Buy '..e.label..(e.oneTime and ' (Once)' or ''),disabled=Off,disabledTooltip='Auto-Buy Class Reagents',
                    tooltip=e.oneTime and 'Bought once; never bought again after that. Turning this off and on allows one more.' or ('Keeps '..e.label..' stocked.'),
                    getValue=function() return R.ReagentOn(e) end,
                    setValue=function(v)
                        if not Plain(v) or type(v)~='boolean' then return end
                        Cat('reagents').items[key]=v
                        if v and e.oneTime then Char().oneTime[key]=nil end
                        Sync()
                    end}
                if not e.oneTime then
                    t.cog={title=e.label,disabled=function() return Off() or not R.ReagentOn(e) end,disabledTooltip='Buy '..e.label,rows={
                        {type='slider',label='Keep',min=LIMITS.keep[1],max=LIMITS.keep[2],step=1,
                            get=function() return R.ReagentKeep(e) end,
                            set=function(v) if not Num(v) or v<LIMITS.keep[1] or v>LIMITS.keep[2] then return end;Cat('reagents').keeps[key]=math.floor(v) end},
                        {type='slider',label='Warn Below',min=LIMITS.low[1],max=LIMITS.low[2],step=1,
                            tooltip='Shared with Class Supplies: the cue warns below this, and the first restock pass buys up to it.',
                            get=function() return R.ReagentLow(e) end,
                            set=function(v)
                                if not Num(v) or v<LIMITS.low[1] or v>LIMITS.low[2] or not NS.EllesmereClassStockSettings then return end
                                NS.EllesmereClassStockSettings().lows[key]=math.floor(v)
                                if NS.SyncEllesmereClassStock then NS.SyncEllesmereClassStock() end
                            end}}}
                end
                subs[#subs+1]=t
            end
        end
        for i=1,#subs,2 do Row(subs[i],subs[i+1] or blank()) end
    end
    if hunter then Consumables('petFood') end
    local engine=NS.EllesmereRestockSettings
    local EL=E.LIMITS
    local function SetEngine(k,v)
        local l=EL[k]
        if not Num(v) or v<l[1] or v>l[2] then return end
        engine()[k]=math.floor(v)
    end
    local function Idle() return not AnyOn() end
    local parent='a Vendor Restock category'
    Row({type='slider',text='Keep At Least (Gold)',min=EL.keepGold[1],max=100,step=1,disabled=Idle,disabledTooltip=parent,
        tooltip='Restock never takes your money below this. The repair bill at a vendor that repairs is always kept as well.',
        getValue=function() return engine().keepGold end,setValue=function(v) SetEngine('keepGold',v) end},
        {type='slider',text='Max Spend Per Visit',min=EL.maxSpendPct[1],max=EL.maxSpendPct[2],step=5,disabled=Idle,disabledTooltip=parent,
        tooltip='Percent of your money one vendor visit may spend. Ammo, then reagents, drink, food and pet food get their essentials first.',
        getValue=function() return engine().maxSpendPct end,setValue=function(v) SetEngine('maxSpendPct',v) end})
    Row({type='slider',text='Leave Free Bag Slots',min=EL.leaveFree[1],max=EL.leaveFree[2],step=1,disabled=Idle,disabledTooltip=parent,
        tooltip='Free slots restock never fills in your general bags, so loot still fits. A quiver is not a general bag.',
        getValue=function() return engine().leaveFree end,setValue=function(v) SetEngine('leaveFree',v) end},
        {type='button',text='Reset Vendor Restock',onClick=function() R.Reset();Refresh() end})
end
-- Section Reset: every setting back to its default; the category toggles stay as they are.
function R.Reset()
    local s=Settings()
    for _,k in ipairs({'food','drink','petFood'}) do
        local c=s[k]
        for key,v in pairs(k=='petFood' and PET_DEFAULTS or CAT_DEFAULTS) do if key~='enabled' then c[key]=v end end
    end
    s.reagents.items={};s.reagents.keeps={}
    local r=NS.EllesmereRestockSettings and NS.EllesmereRestockSettings()
    if r and E.DEFAULTS then for k,v in pairs(E.DEFAULTS) do r[k]=v end end
    if NS.EllesmereAmmoBuySettings then
        local a=NS.EllesmereAmmoBuySettings()
        for k in pairs(a) do if k~='enabled' then a[k]=nil end end
        NS.EllesmereAmmoBuySettings()
    end
    NS.SyncEllesmereRestock()
end

local boot=CreateFrame('Frame')
boot:RegisterEvent('PLAYER_LOGIN')
boot:SetScript('OnEvent',function(self) self:UnregisterAllEvents();NS.SyncEllesmereRestock() end)
