-- Vendor Restock engine and its first category, Auto-Buy Ammo (reviews H2, S3-S10, scenario
-- review section 12). Everything is off by default; while off nothing is registered.
--
-- Engine (NS.EllesmereRestock): categories plug in as planners. A visit is a "minimum" pass
-- (essentials, in priority order) then a "fill" pass (up to each target, same order). A planner
-- proposes one purchase at a time; the engine owns every guard:
--   combat; Shift held as the vendor opens (the visit is skipped and said once); the merchant
--   closing; a visit budget = money - Keep At Least - the repair bill (when this vendor repairs,
--   so Ellesmere's Auto Repair is never starved), capped at Max Spend Per Visit, spent from a
--   running local balance (GetMoney lags mid-visit); bag space (bag families, Leave Free Bag
--   Slots in general bags, partial stacks); the vendor bundle (stackCount), the per-purchase
--   maximum and the item's own stack size; and the loop guard (one purchase per step, the next
--   step waits for BAG_UPDATE_DELAYED; a purchase that added nothing skips that item for the
--   visit and 60 s; one 0.6 s retry for late vendor data, only before anything was bought).
--   One summary line per visit; a blocking reason prints once per session and level.
--
-- Ammo (hunters; warriors and rogues with a bow, gun or crossbow): the ammo the equipped ranged
-- weapon fires, the best common tier you can use (cog: best tier), never worse than the ammo you
-- have equipped unless you are below the Low Ammo threshold. Modes: Fill Quiver (default), Fill
-- Quiver And Bags, Keep At Least. A better tier within Levels Ahead (or 75% into the level
-- before it) buys only the Bridge Amount; the first visit after a tier unlocks buys at least
-- 200 of it. Unreadable answers never buy.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end

local function Plain(v) return not (issecretvalue and issecretvalue(v)) end
local function Num(v) return Plain(v) and type(v)=='number' and v==v and v>-math.huge and v<math.huge end
-- Every return must be public, or the whole answer is unknown (nothing returned).
local function Clean(ok,...)
    if not ok then return end
    for i=1,select('#',...) do if not Plain((select(i,...))) then return end end
    return ...
end
local function Read(fn,...)
    if type(fn)~='function' then return end
    return Clean(pcall(fn,...))
end
-- Bitwise AND of two small non-negative integers (bag families), allocation free.
local function Band(a,b)
    if _G.bit and type(bit.band)=='function' then local ok,v=pcall(bit.band,a,b);if ok then return v end end
    local r,p=0,1
    while a>0 and b>0 do
        if a%2==1 and b%2==1 then r=r+p end
        a,b,p=math.floor(a/2),math.floor(b/2),p*2
    end
    return r
end
local function Bags() return _G.NUM_BAG_SLOTS or 4 end
local function Now() return GetTime and GetTime() or 0 end
local function Say(text)
    local chat=_G.DEFAULT_CHAT_FRAME
    if chat and chat.AddMessage then chat:AddMessage('|cffdda880FHK|r '..text) end
end
local function Coins(copper)
    local text=C_CurrencyInfo and Read(C_CurrencyInfo.GetCoinTextureString,copper) or Read(_G.GetCoinTextureString,copper)
    if type(text)=='string' then return text end
    return copper..'c'
end
-- name, itemLevel, minLevel, stack size, quality (each nil when unknown).
local function ItemInfo(id)
    if not Num(id) then return end
    local name,_,quality,itemLevel,minLevel,_,_,stack=Read(C_Item and C_Item.GetItemInfo or _G.GetItemInfo,id)
    return type(name)=='string' and name or nil,Num(itemLevel) and itemLevel or nil,Num(minLevel) and minLevel or nil,
        Num(stack) and stack>0 and stack or nil,Num(quality) and quality or nil
end
local function Instant(id)
    local get=C_Item and C_Item.GetItemInfoInstant or _G.GetItemInfoInstant
    if not Num(id) then return end
    local _,_,_,_,_,classID,subclassID=Read(get,id)
    if Num(classID) and Num(subclassID) then return classID,subclassID end
end
local GOLD=10000

-------------------------------------------------------------------------------
-- Engine settings (shared by every category): money and bags.
-------------------------------------------------------------------------------
local E={planners={},skipUntil={},told={}}
NS.EllesmereRestock=E
NS.EllesmereMerchantEngine=E
local ENGINE_DEFAULTS={keepGold=0,maxSpendPct=25,leaveFree=2}
local ENGINE_LIMITS={keepGold={0,1000},maxSpendPct={5,100},leaveFree={0,16}}
-- The budget rows live in Restock.lua's options (Warnings > VENDOR RESTOCK).
E.DEFAULTS,E.LIMITS=ENGINE_DEFAULTS,ENGINE_LIMITS
function NS.EllesmereRestockSettings()
    if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end
    local s=FHKEllesmereDB.restock
    if type(s)~='table' then s={};FHKEllesmereDB.restock=s end
    for k,v in pairs(ENGINE_DEFAULTS) do
        local l=ENGINE_LIMITS[k]
        if not Num(s[k]) or s[k]<l[1] or s[k]>l[2] then s[k]=v end
        s[k]=math.floor(s[k])
    end
    return s
end

-------------------------------------------------------------------------------
-- Engine reads.
-------------------------------------------------------------------------------
-- One vendor row, re-read every time (C_MerchantFrame first, legacy fallback); nil when unreadable.
function E.Offer(i)
    if not Num(i) then return end
    local id=Read(_G.GetMerchantItemID,i)
    local name,price,bundle,available,purchasable,usable,extended
    local info=C_MerchantFrame and Read(C_MerchantFrame.GetItemInfo,i)
    if type(info)=='table' then
        name,price,bundle,available,purchasable,usable,extended=info.name,info.price,info.stackCount,info.numAvailable,info.isPurchasable,info.isUsable,info.hasExtendedCost
    else
        local _
        name,_,price,bundle,available,purchasable,usable,extended=Read(_G.GetMerchantItemInfo,i)
    end
    if not (Num(id) and Num(price) and Plain(available) and Plain(purchasable) and Plain(usable) and Plain(extended) and Plain(name)) then return end
    bundle=Num(bundle) and bundle>0 and math.floor(bundle) or 1
    return {index=i,id=id,name=type(name)=='string' and name or nil,price=price,bundle=bundle,
        available=Num(available) and available or -1,purchasable=purchasable~=false,usable=usable~=false,extended=extended==true}
end
function E.NumOffers()
    local n=Read(_G.GetMerchantNumItems)
    return Num(n) and n or 0
end
-- General bags (family 0), and special bags whose family takes the item (a quiver for arrows).
function E.AnyFittingBag(family,itemFamily) return family==0 or Band(family,itemFamily)~=0 end
function E.SpecialBag(family,itemFamily) return family~=0 and Band(family,itemFamily)~=0 end
E.Band=Band
-- Room for item id in the bags fits(family,itemFamily) accepts: free slots times the item's stack
-- size (general bags keep leaveFree slots empty) plus what its partial stacks can still take.
-- nil when unreadable.
function E.Room(id,fits,leaveFree)
    local C=C_Container
    local _,_,_,stack=ItemInfo(id)
    if not stack or not (C and C.GetContainerNumFreeSlots and C.GetContainerNumSlots and C.GetContainerItemInfo) then return nil end
    local itemFamily=Read(C_Item and C_Item.GetItemFamily,id)
    itemFamily=Num(itemFamily) and itemFamily or 0
    local special,general,partial=0,0,0
    for bag=0,Bags() do
        local free,family=Read(C.GetContainerNumFreeSlots,bag)
        if not Num(free) then return nil end
        family=Num(family) and family or 0
        if fits(family,itemFamily) then
            if family==0 then general=general+free else special=special+free end
            local slots=Read(C.GetContainerNumSlots,bag)
            if not Num(slots) then return nil end
            for slot=1,slots do
                local info=Read(C.GetContainerItemInfo,bag,slot)
                if type(info)=='table' and Num(info.itemID) and info.itemID==id and Num(info.stackCount) then
                    partial=partial+math.max(0,stack-info.stackCount)
                end
            end
        end
    end
    return (special+math.max(0,general-(leaveFree or 0)))*stack+partial
end
-- The repair bill to keep in reserve at a vendor that repairs (0 when there is none or it is unknown).
function E.RepairReserve()
    if Read(_G.CanMerchantRepair)~=true then return 0 end
    local cost=Read(_G.GetRepairAllCost)
    return Num(cost) and cost>0 and cost or 0
end
local function Level()
    local l=Read(_G.UnitLevel,'player')
    return Num(l) and l or 0
end

-------------------------------------------------------------------------------
-- Engine flow.
-------------------------------------------------------------------------------
-- planner = {key, label, priority (lower first), Enabled(), Begin(E)->state|nil,
--   Next(state,pass,E)->{index,quantity,reason}|nil (pass 'minimum' then 'fill'),
--   Measure(state)->stock|nil, Fits(state,family,itemFamily,pass)->bool (optional),
--   Purchased(state,count,offer) (optional), Summary(state,bought)->fragment|nil,
--   Finish(state,bought) (optional)}.
function E.Register(planner)
    if type(planner)~='table' or type(planner.key)~='string' or type(planner.Next)~='function' or type(planner.Begin)~='function' then return false end
    for _,p in ipairs(E.planners) do if p.key==planner.key then return false end end
    E.planners[#E.planners+1]=planner
    table.sort(E.planners,function(a,b) return (a.priority or 50)<(b.priority or 50) end)
    -- Saved settings exist only after login; a later planner resyncs at once.
    if E.ready then E.Sync() end
    return true
end
local driver,session,queued=nil,nil,false
local function AnyEnabled()
    for _,p in ipairs(E.planners) do if type(p.Enabled)=='function' and p.Enabled()==true then return true end end
    return false
end
function E.Sync()
    if driver then driver:UnregisterAllEvents() end
    session=nil
    if not AnyEnabled() then return end
    if not driver then driver=CreateFrame('Frame');driver:SetScript('OnEvent',function(_,event) E.OnEvent(event) end) end
    driver:RegisterEvent('MERCHANT_SHOW');driver:RegisterEvent('MERCHANT_CLOSED')
end
E.REASONS={junk='is marked as junk in your bags: not bought',money='not enough money in this visit\'s budget (Keep At Least, repair bill, Max Spend Per Visit)',
    space='no bag space left (Leave Free Bag Slots counts)',unreadable='the vendor or your bags could not be read',
    gain='a purchase added nothing (bags full, sold out or another addon); skipped for a minute'}
-- A blocking reason prints once per session and level (review S9).
local function Tell(run,why,extra)
    local key=run.planner.key..':'..why..(extra or '')
    if E.told[key]==Level() then return end
    E.told[key]=Level()
    run.notes=run.notes or {}
    if why=='junk' then
        run.notes[#run.notes+1]=(run.planner.label or 'Restock')..': '..(extra or 'an item')..' '..E.REASONS.junk..'.'
        return
    end
    run.notes[#run.notes+1]=(run.planner.label or 'Restock')..': '..(E.REASONS[why] or why)..(extra and (' ('..extra..')') or '')..'.'
end
local function Stop(run,why,extra)
    run.done=why
    if E.REASONS[why] then Tell(run,why,extra) end
end
local function Begin(s,p)
    local state=p.Begin(E)
    if state~=nil then s.runs[#s.runs+1]={planner=p,state=state,bought={},spent=0} end
    return state~=nil
end
local function Finish(why)
    local s=session
    if not s then return end
    session=nil
    if driver then
        for _,event in ipairs({'MERCHANT_UPDATE','BAG_UPDATE_DELAYED','PLAYER_REGEN_DISABLED'}) do driver:UnregisterEvent(event) end
    end
    local parts,cost={},0
    for _,run in ipairs(s.runs) do
        if #run.bought>0 then
            local text=type(run.planner.Summary)=='function' and run.planner.Summary(run.state,run.bought) or nil
            if text then parts[#parts+1]=text end
            for _,b in ipairs(run.bought) do cost=cost+b.cost end
        end
        if type(run.planner.Finish)=='function' then pcall(run.planner.Finish,run.state,run.bought) end
    end
    if #parts>0 then Say('Restocked: '..table.concat(parts,', ')..' ('..Coins(math.floor(cost+.5))..').') end
    for _,run in ipairs(s.runs) do for _,note in ipairs(run.notes or {}) do Say(note) end end
    E.last={why=why,runs=s.runs,budget=s.budget}
end
-- Trim a proposal by every guard: the quantity to buy (0 = this category stops) and the offer.
-- Ellesmere Bags' Junk Marker (review SQ-3) sells a marked item ID at any quality when the
-- vendor opens, so buying it would be a money loop. EUI_CategoryManager:IsJunk(itemID, quality)
-- (EllesmereUIBags_Categories); quality is optional. Unreadable means not junk.
function E.IsJunk(id)
    local cm=_G.EUI_CategoryManager
    if type(cm)~='table' or type(cm.IsJunk)~='function' then return false end
    local ok,junk=pcall(cm.IsJunk,cm,id)
    return ok and Plain(junk) and junk==true
end
local function Guard(s,run,p,pass)
    local o=E.Offer(p.index)
    if not o or not o.purchasable or o.extended or o.price<=0 or o.available==0 then return 0,'offer' end
    if E.IsJunk(o.id) then return 0,'junk',o end
    if (E.skipUntil[o.id] or 0)>Now() then return 0,'skipped' end
    local q=math.floor((Num(p.quantity) and p.quantity or 0)/o.bundle)*o.bundle
    if q<=0 then return 0,'nothing' end
    local maxStack=Read(_G.GetMerchantItemMaxStack,o.index)
    if Num(maxStack) and maxStack>0 then q=math.min(q,math.max(o.bundle,math.floor(maxStack/o.bundle)*o.bundle)) end
    -- Never more than one stack of the item per purchase (its own stack size, not a guess).
    local _,_,_,stack=ItemInfo(o.id)
    if not stack then return 0,'unreadable' end
    q=math.min(q,math.max(o.bundle,math.floor(stack/o.bundle)*o.bundle))
    if o.available>0 then q=math.min(q,o.available*o.bundle) end
    if not Num(s.budget) then return 0,'unreadable' end
    q=math.min(q,math.floor(math.max(0,s.budget)/o.price)*o.bundle)
    if q<=0 then return 0,'money' end
    local fits=E.AnyFittingBag
    if type(run.planner.Fits)=='function' then fits=function(f,i) return run.planner.Fits(run.state,f,i,pass) end end
    local room=E.Room(o.id,fits,s.leaveFree)
    if not Num(room) then return 0,'unreadable' end
    q=math.min(q,math.floor(room/o.bundle)*o.bundle)
    if q<=0 then return 0,'space' end
    return q,nil,o
end
local function Step()
    queued=false
    local s=session
    if not s or s.waiting then return end
    if Read(_G.InCombatLockdown)~=false then Finish('combat');return end
    while true do
        for _,run in ipairs(s.runs) do
            if not run.done and not run[s.pass] then
                local p=run.planner.Next(run.state,s.pass,E)
                if type(p)~='table' then run[s.pass]=true
                else
                    local q,why,o=Guard(s,run,p,s.pass)
                    if q<=0 then Stop(run,why,why=='junk' and o and (o.name or ('item '..o.id)) or nil)
                    else
                        local before=run.planner.Measure(run.state)
                        local money=Read(_G.GetMoney)
                        if not Num(before) then Stop(run,'unreadable')
                        elseif not pcall(_G.BuyMerchantItem,o.index,q) then Stop(run,'failed')
                        else
                            local cost=o.price*q/o.bundle
                            s.budget=s.budget-cost;run.spent=run.spent+cost;s.bought=true
                            run.bought[#run.bought+1]={id=o.id,name=o.name,count=q,cost=cost,reason=p.reason,pass=s.pass}
                            if type(run.planner.Purchased)=='function' then run.planner.Purchased(run.state,q,o) end
                            s.waiting={run=run,before=before,id=o.id,name=o.name,money=money,count=q,cost=cost}
                            s.token=s.token+1
                            local token=s.token
                            -- No gain within 3 s is the only "added nothing" verdict (review SQ-1).
                            if C_Timer and C_Timer.After then C_Timer.After(3,function() if session==s and s.token==token and s.waiting then E.Settle(true) end end) end
                            return
                        end
                    end
                end
            end
        end
        if s.pass=='minimum' then s.pass='fill' else break end
    end
    Finish('done')
end
local function Queue()
    if queued or not session then return end
    queued=true
    if C_Timer and C_Timer.After then C_Timer.After(0,Step) else Step() end
end
-- After a purchase (review SQ-1). A bag update settles it only when the category's stock rose:
-- Ellesmere's junk sales at the same vendor send bag updates of their own. With no gain the
-- purchase keeps waiting; the 3 s timeout (timeout=true) is the only "added nothing" verdict.
-- A timeout with unchanged money is a dropped buy: it is undone and tried once more.
function E.Settle(timeout)
    local s=session
    if not s or not s.waiting then return end
    local w=s.waiting
    local after=w.run.planner.Measure(w.run.state)
    if Num(after) and after>w.before then s.waiting=nil;Queue();return end
    if not timeout then return end
    s.waiting=nil
    local money=Read(_G.GetMoney)
    if Num(after) and not w.run.rebought and Num(money) and Num(w.money) and money>=w.money then
        w.run.rebought=true
        s.budget=s.budget+w.cost;w.run.spent=w.run.spent-w.cost
        table.remove(w.run.bought)
        if type(w.run.planner.Refunded)=='function' then w.run.planner.Refunded(w.run.state,w.count) end
    elseif not Num(after) then Stop(w.run,'unreadable')
    else
        E.skipUntil[w.id]=Now()+60
        Stop(w.run,'gain',w.name)
    end
    Queue()
end
-- Begin the planners still pending; keep the ones that still have nothing to plan.
local function TryPending(s)
    local keep={}
    for _,p in ipairs(s.pending) do if p.Enabled()==true and not Begin(s,p) then keep[#keep+1]=p end end
    s.pending=keep
end
local function Retry()
    local s=session
    if not s or s.retried then return end
    s.retried=true
    if not s.bought then TryPending(s) end
    s.pending={}
    if #s.runs==0 then Finish('nothing') elseif not s.waiting then Queue() end
end
function E.OnEvent(event)
    if not driver then return end
    if event=='MERCHANT_SHOW' then
        session=nil
        if Read(_G.InCombatLockdown)~=false then return end
        if Read(_G.IsShiftKeyDown)==true then Say('Restock skipped (Shift).');return end
        local r=NS.EllesmereRestockSettings()
        local money=Read(_G.GetMoney)
        local s={runs={},pending={},token=0,pass='minimum',leaveFree=r.leaveFree}
        if Num(money) then
            s.budget=math.min(money-r.keepGold*GOLD-E.RepairReserve(),math.floor(money*r.maxSpendPct/100))
        end
        session=s
        for _,p in ipairs(E.planners) do
            if type(p.Enabled)=='function' and p.Enabled()==true and not Begin(s,p) then s.pending[#s.pending+1]=p end
        end
        driver:RegisterEvent('MERCHANT_UPDATE');driver:RegisterEvent('BAG_UPDATE_DELAYED');driver:RegisterEvent('PLAYER_REGEN_DISABLED')
        if #s.pending>0 and C_Timer and C_Timer.After then C_Timer.After(.6,Retry) end
        if #s.runs>0 then Queue() elseif #s.pending==0 then Finish('nothing') end
    elseif event=='MERCHANT_CLOSED' then Finish('closed')
    elseif event=='PLAYER_REGEN_DISABLED' then Finish('combat')
    elseif not session then return
    elseif event=='BAG_UPDATE_DELAYED' then
        if session.waiting then E.Settle() end
    elseif event=='MERCHANT_UPDATE' then
        if #session.pending>0 then TryPending(session) end
        if #session.runs>0 and not session.waiting then Queue() end
    end
end
function E.State() return {driver=driver,session=session} end

-------------------------------------------------------------------------------
-- Ammo planner.
-------------------------------------------------------------------------------
local A={}
NS.AmmoBuy=A
local CLASSES={HUNTER=true,WARRIOR=true,ROGUE=true}
local function Class() return select(2,Read(_G.UnitClass,'player')) end
function NS.EllesmereAmmoBuyAvailable() return CLASSES[Class()]==true end
-- Keep default by class (review S8): a warrior or rogue pulls with it once per mob.
local function KeepDefault() return Class()=='HUNTER' and 1000 or 200 end
local DEFAULTS={enabled=false,mode='quiver',bridge=true,bridgeLevels=1,bridgeAmount=200,useOld=true,tier='common'}
local LIMITS={keep={200,3000},bridgeLevels={0,3},bridgeAmount={200,1000}}
local CHOICES={mode={keep=true,quiver=true,quiverBags=true},tier={common=true,best=true}}
function NS.EllesmereAmmoBuySettings()
    if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end
    local s=FHKEllesmereDB.ammoBuy
    if type(s)~='table' then s={};FHKEllesmereDB.ammoBuy=s end
    for k,v in pairs(DEFAULTS) do
        local l=LIMITS[k]
        if type(v)=='boolean' then if type(s[k])~='boolean' then s[k]=v end
        elseif l then if not Num(s[k]) or s[k]<l[1] or s[k]>l[2] then s[k]=v end;s[k]=math.floor(s[k])
        elseif not CHOICES[k][s[k]] then s[k]=v end
    end
    if not Num(s.keep) or s.keep<LIMITS.keep[1] or s.keep>LIMITS.keep[2] then s.keep=KeepDefault() end
    s.keep=math.floor(s.keep)
    return s
end
local RANGED_SLOT,AMMO_SLOT=_G.INVSLOT_RANGED or 18,_G.INVSLOT_AMMO or 0
local WEAPON,PROJECTILE=2,6
local AMMO_FOR={[2]=2,[18]=2,[3]=3} -- bow, crossbow: arrows (2); gun: bullets (3)
local AMMO_NAME={[2]='arrows',[3]='bullets'}
local NEW_TIER=200 -- FHKGear equips new ammo once it has a real stack of 200
-- Vendor ammo tiers (wago.tools DB2 build 1.60.1.70205, E1): the fallback when this vendor
-- does not list the next tier. {required level, item}.
local TIERS={[2]={{1,2512},{10,2515},{25,3030},{40,11285},{51,19316}},[3]={{1,2516},{10,2519},{25,3033},{40,11284},{51,19317}}}
-- Arrows (2) or bullets (3) for the equipped ranged weapon; nil for thrown, wands or none.
function A.WantedAmmo()
    local classID,subclassID=Instant(Read(_G.GetInventoryItemID,'player',RANGED_SLOT))
    if classID==WEAPON then return AMMO_FOR[subclassID] end
end
local function Grade(minLevel,itemLevel) return (minLevel or -1)*1000+(itemLevel or 0) end
-- Tier index of a required level (1 = level 1 ammo).
local function TierIndex(want,minLevel)
    local n=0
    for i,t in ipairs(TIERS[want] or {}) do if minLevel and minLevel>=t[1] then n=i end end
    return n
end
-- Stock of that type: total that counts toward the target, the best tier's own count, and the
-- lower-grade part. Ammo above your level never counts; with Use Up Old Ammo off only the best
-- tier counts; lower grade 2 or more tiers below never counts. nil when unreadable.
function A.Stock(state)
    local C=C_Container
    if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return nil end
    local total,best,older=0,0,0
    local bestTier=TierIndex(state.want,state.pick.minLevel)
    for bag=0,Bags() do
        local slots=Read(C.GetContainerNumSlots,bag)
        if not Num(slots) then return nil end
        for slot=1,slots do
            local info=Read(C.GetContainerItemInfo,bag,slot)
            if type(info)=='table' then
                if not Num(info.itemID) then return nil end
                local classID,subclassID=Instant(info.itemID)
                if classID==PROJECTILE and subclassID==state.want then
                    if not Num(info.stackCount) then return nil end
                    local _,itemLevel,minLevel=ItemInfo(info.itemID)
                    if not (minLevel and minLevel>state.level) then
                        if info.itemID==state.pick.id or Grade(minLevel,itemLevel)>=state.pick.grade then
                            best=best+info.stackCount;total=total+info.stackCount
                        elseif state.s.useOld and bestTier-TierIndex(state.want,minLevel)<2 then
                            older=older+info.stackCount;total=total+info.stackCount
                        end
                    end
                end
            end
        end
    end
    return total,best,older
end
-- The vendor's ammo of that type: the best one you can use and the next better tier it lists.
function A.Choose(want,level,tierChoice)
    local best,nextTier
    for i=1,E.NumOffers() do
        local o=E.Offer(i)
        local classID,subclassID=Instant(o and o.id)
        if o and classID==PROJECTILE and subclassID==want and o.price>0 and o.purchasable and not o.extended then
            local name,itemLevel,minLevel,_,quality=ItemInfo(o.id)
            o.name=o.name or name;o.minLevel=minLevel;o.grade=Grade(minLevel,itemLevel)
            if minLevel and minLevel>level then
                if not nextTier or minLevel<nextTier.minLevel then nextTier=o end
            elseif o.usable and o.available~=0 and minLevel and not (tierChoice=='common' and quality and quality>1) then
                if not best or o.grade>best.grade or (o.grade==best.grade and o.price/o.bundle<best.price/best.bundle) then best=o end
            end
        end
    end
    -- The DB2 table names a tier this vendor does not list.
    for _,t in ipairs(TIERS[want] or {}) do
        if t[1]>level and (not nextTier or t[1]<nextTier.minLevel) then nextTier={id=t[2],minLevel=t[1],name=(ItemInfo(t[2]))} end
    end
    return best,nextTier
end
-- XP fraction into the current level; nil when unreadable.
local function XPFraction()
    local xp,max=Read(_G.UnitXP,'player'),Read(_G.UnitXPMax,'player')
    if Num(xp) and Num(max) and max>0 then return xp/max end
end
-- The bridge (review S3): a better tier within Levels Ahead, or one level further when you are
-- 75% or more through this level.
function A.Bridges(s,level,nextTier)
    if not s.bridge or not nextTier or not Num(nextTier.minLevel) then return false end
    local gap=nextTier.minLevel-level
    if gap<=s.bridgeLevels then return true end
    local frac=XPFraction()
    return gap==s.bridgeLevels+1 and frac~=nil and frac>=.75
end
local function LowAmmo()
    local w=NS.EllesmereWarningSettings and NS.EllesmereWarningSettings()
    return w and Num(w.ammoLow) and w.ammoLow or 200
end
local function Seen()
    -- Per character (not a profile key): the best tier bought or carried per ammo type.
    local t=rawget(FHKEllesmereDB,'restockSeen')
    if type(t)~='table' then t={};rawset(FHKEllesmereDB,'restockSeen',t) end
    return t
end
A.planner={key='ammo',label='Auto-Buy Ammo',priority=1}
local P=A.planner
function P.Enabled() return NS.EllesmereAmmoBuySettings().enabled==true and NS.EllesmereAmmoBuyAvailable() end
function P.Begin()
    local s=NS.EllesmereAmmoBuySettings()
    local want=A.WantedAmmo()
    if not want then return nil end
    local level=Read(_G.UnitLevel,'player')
    if not Num(level) then return nil end
    local best,nextTier=A.Choose(want,level,s.tier)
    if not best then return nil end
    local state={want=want,level=level,pick=best,s=s,added=0}
    local total,bestCount=A.Stock(state)
    if not Num(total) then return nil end
    -- Never worse than the ammo you have equipped, unless you are nearly out.
    local equipped=Read(_G.GetInventoryItemID,'player',AMMO_SLOT)
    if Num(equipped) and equipped~=best.id then
        local _,itemLevel,minLevel=ItemInfo(equipped)
        local classID,subclassID=Instant(equipped)
        if classID==PROJECTILE and subclassID==want and Grade(minLevel,itemLevel)>best.grade then
            if total>=LowAmmo() then return nil end
            state.low=true
        end
    end
    if A.Bridges(s,level,nextTier) then state.bridge=nextTier end
    local seen=Seen()[want]
    state.newTier=(not Num(seen) or best.minLevel>seen) and bestCount<NEW_TIER
    -- Fill modes fix their amount when the vendor opens (the game may put ammo in any bag).
    if s.mode=='quiver' then state.cap=E.Room(best.id,E.SpecialBag,0)
    elseif s.mode=='quiverBags' then state.cap=E.Room(best.id,E.AnyFittingBag,NS.EllesmereRestockSettings().leaveFree) end
    if s.mode~='keep' and not Num(state.cap) then return nil end
    return state
end
function P.Measure(state) return (A.Stock(state)) end
function P.Fits(state,family,itemFamily,pass)
    -- Fill Quiver buys essentials into general bags too, never the fill.
    if state.s.mode=='quiver' and pass=='fill' then return E.SpecialBag(family,itemFamily) end
    return E.AnyFittingBag(family,itemFamily)
end
function P.Purchased(state,count) state.added=state.added+count end
function P.Refunded(state,count) state.added=math.max(0,state.added-count) end
function P.Next(state,pass)
    -- A weapon swapped mid-visit ends the plan.
    if A.WantedAmmo()~=state.want then return nil end
    local s,pick=state.s,state.pick
    local total,bestCount=A.Stock(state)
    if not Num(total) then return nil end
    local need
    if pass=='minimum' then
        -- Essentials: never below one bundle-sized stack, and 200 of a newly unlocked tier.
        need=math.max(math.min(NEW_TIER,s.keep)-total,state.newTier and NEW_TIER-bestCount or 0)
        need=math.ceil(math.max(0,need)/pick.bundle)*pick.bundle
    elseif s.mode=='keep' then
        need=math.ceil(math.max(0,s.keep-total)/pick.bundle)*pick.bundle
    else
        need=state.cap-state.added
    end
    if state.bridge then need=math.min(need,s.bridgeAmount-state.added) end
    if need<=0 then return nil end
    return {index=pick.index,quantity=need,reason=state.bridge and 'bridge' or pass}
end
function P.Summary(state,bought)
    local n=0
    for _,b in ipairs(bought) do n=n+b.count end
    local text=n..' '..(state.pick.name or AMMO_NAME[state.want])
    if state.bridge then text=text..' ('..(state.bridge.name or 'better ammo')..' at '..state.bridge.minLevel..')' end
    local _,_,older=A.Stock(state)
    if Num(older) and older>0 then text=text..' (carrying '..older..' older)' end
    return text
end
function P.Finish(state,bought)
    local _,bestCount=A.Stock(state)
    if #bought>0 or (Num(bestCount) and bestCount>=NEW_TIER) then Seen()[state.want]=state.pick.minLevel end
end
E.Register(P)

function A.State() return E.State() end
function NS.SyncEllesmereAmmoBuy() E.Sync() end

-------------------------------------------------------------------------------
-- Options (Warnings > VENDOR RESTOCK).
-------------------------------------------------------------------------------
function NS.AddEllesmereAmmoBuyOptions(Row)
    -- Only classes that fire ammo get the ammo rows. The shared budget rows (Keep At Least,
    -- Max Spend Per Visit, Leave Free Bag Slots) are built by NS.AddEllesmereRestockOptions.
    if not NS.EllesmereAmmoBuyAvailable() then return end
    if EUI.IsSearchPrebuild and EUI.IsSearchPrebuild() then
        Row({type='label',text='Auto-Buy Ammo'},{type='label',text='Ammo Buy Mode'})
        Row({type='label',text='Keep Ammo'},{type='label',text='Buy Less Before Better Ammo'})
        return
    end
    local function Settings() return NS.EllesmereAmmoBuySettings() end
    local function Off() return not Settings().enabled end
    local function Set(k,v)
        local l=LIMITS[k]
        if l then if not Num(v) or v<l[1] or v>l[2] then return end;v=math.floor(v)
        elseif CHOICES[k] then if not CHOICES[k][v] then return end
        elseif type(v)~='boolean' then return end
        Settings()[k]=v;NS.SyncEllesmereAmmoBuy()
    end
    local buy={type='toggle',text='Auto-Buy Ammo',
        tooltip='At a vendor that sells ammo for your ranged weapon (arrows for bows and crossbows, bullets for guns), buys the best one you can use, never worse than the ammo you have equipped. One summary line in chat. Hold Shift as the vendor opens to skip.',
        getValue=function() return Settings().enabled end,setValue=function(v) Set('enabled',v==true);if EUI.RefreshPage then EUI:RefreshPage() end end}
    buy.cog={title='Auto-Buy Ammo',disabled=Off,disabledTooltip='Auto-Buy Ammo',rows={
        {type='toggle',label='Use Up Old Ammo',tooltip='Older, lower-grade ammo you carry counts toward the amount you keep (never ammo two or more tiers behind).',
            get=function() return Settings().useOld end,set=function(v) Set('useOld',v==true) end},
        {type='dropdown',label='Ammo Tier',values={common='Best Common Tier',best='Best Tier'},order={'common','best'},
            tooltip='Best Common Tier skips uncommon ammo such as Ice Threaded Arrows.',
            get=function() return Settings().tier end,set=function(v) Set('tier',v) end}}}
    Row(buy,{type='dropdown',text='Ammo Buy Mode',values={quiver='Fill Quiver',quiverBags='Fill Quiver And Bags',keep='Keep At Least'},
        order={'quiver','quiverBags','keep'},disabled=Off,disabledTooltip='Auto-Buy Ammo',
        tooltip='Fill Quiver fills only your quiver or ammo pouch. Fill Quiver And Bags also fills your bags, leaving the free slots set below. Keep At Least tops your ammo up to Keep Ammo. Every mode first makes sure you carry at least 200.',
        getValue=function() return Settings().mode end,setValue=function(v) Set('mode',v);if EUI.RefreshPage then EUI:RefreshPage() end end})
    local bridge={type='toggle',text='Buy Less Before Better Ammo',
        tooltip='When better ammo unlocks next level (or you are 75% through the level before it), buys only the bridge amount.',
        disabled=Off,disabledTooltip='Auto-Buy Ammo',
        getValue=function() return Settings().bridge end,setValue=function(v) Set('bridge',v==true) end}
    bridge.cog={title='Buy Less Before Better Ammo',disabled=function() return Off() or not Settings().bridge end,disabledTooltip='Buy Less Before Better Ammo',rows={
        {type='slider',label='Levels Ahead',min=LIMITS.bridgeLevels[1],max=LIMITS.bridgeLevels[2],step=1,get=function() return Settings().bridgeLevels end,set=function(v) Set('bridgeLevels',v) end},
        {type='slider',label='Bridge Amount',min=LIMITS.bridgeAmount[1],max=LIMITS.bridgeAmount[2],step=200,get=function() return Settings().bridgeAmount end,set=function(v) Set('bridgeAmount',v) end}}}
    Row({type='slider',text='Keep Ammo',min=LIMITS.keep[1],max=LIMITS.keep[2],step=100,
        disabled=function() return Off() or Settings().mode~='keep' end,disabledTooltip='Auto-Buy Ammo (Keep At Least)',
        getValue=function() return Settings().keep end,setValue=function(v) Set('keep',v) end},bridge)
end

local boot=CreateFrame('Frame')
boot:RegisterEvent('PLAYER_LOGIN')
boot:SetScript('OnEvent',function(self) self:UnregisterAllEvents();E.ready=true;NS.SyncEllesmereAmmoBuy() end)
