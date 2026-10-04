-- FHK Gear: legal complete setups and independent reward comparisons.
-- Adapted slot vocabulary from AutoGear; CC BY-NC-SA 4.0. See LICENSE.md.
if EUI_CLIENT_BLOCKED then return end
local _,ns=...
local S,E=ns.Safe,ns.Engine
local SLOTS={INVTYPE_HEAD={1},INVTYPE_NECK={2},INVTYPE_SHOULDER={3},INVTYPE_CHEST={5},INVTYPE_ROBE={5},INVTYPE_WAIST={6},
    INVTYPE_LEGS={7},INVTYPE_FEET={8},INVTYPE_WRIST={9},INVTYPE_HAND={10},INVTYPE_FINGER={11,12},INVTYPE_TRINKET={13,14},INVTYPE_CLOAK={15},
    INVTYPE_WEAPON={16,17},INVTYPE_WEAPONMAINHAND={16},INVTYPE_2HWEAPON={16},INVTYPE_WEAPONOFFHAND={17},INVTYPE_SHIELD={17},INVTYPE_HOLDABLE={17},
    INVTYPE_RANGED={18},INVTYPE_THROWN={18},INVTYPE_RANGEDRIGHT={18},INVTYPE_RELIC={18},INVTYPE_BAG={20,21,22,23},INVTYPE_QUIVER={20,21,22,23}}
E.SLOTS=SLOTS
E.EQUIP_SLOTS={1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17,18,20,21,22,23}
-- Bag slots. Gear numbers them 20-23 (bags 1-4) and 24 (the reagent bag, when the client has one).
-- The client's own inventory IDs differ by build (Forever uses the retail offset, 31-35), so they are
-- asked from C_Container.ContainerIDToInventoryID only where an inventory API is called.
local reagentSlots=rawget(_G,'NUM_REAGENTBAG_SLOTS')
E.HAS_REAGENT_BAG=S.Number(reagentSlots) and reagentSlots>0 or false
if E.HAS_REAGENT_BAG then E.EQUIP_SLOTS[#E.EQUIP_SLOTS+1]=24 end
E.REAGENT_SLOT=24
function E.ContainerFor(slot)
    if slot==24 then
        local index=Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
        return S.Number(index) and index or (NUM_BAG_SLOTS or 4)+1
    end
    return slot-19
end
function E.Inventory(slot)
    if not S.Number(slot) or slot<20 then return slot end
    local id=S.Read(C_Container and C_Container.ContainerIDToInventoryID,E.ContainerFor(slot))
    return S.Number(id) and id or slot
end
function E.FromInventory(id)
    if not S.Number(id) then return id end
    for _,slot in ipairs({20,21,22,23,24}) do if (slot<24 or E.HAS_REAGENT_BAG) and E.Inventory(slot)==id then return slot end end
    return id
end
-- Reagent bags fit only the reagent bag slot, and general bags never go there.
function E.IsReagentBag(info)
    local sub=Enum and Enum.ItemContainerSubclass and Enum.ItemContainerSubclass.ReagentContainer
    return info and info.classID==1 and info.subclassID==(S.Number(sub) and sub or 11) or false
end
-- Ammo containers (quivers, ammo pouches: item class 11) are a Hunter's core bag. A worn one keeps its
-- slot: general bags never replace it, and a new quiver only replaces a quiver (or fills a slot when you
-- wear none). Read from the worn bags once per equipment change.
function E.IsAmmoBag(info) return info and (info.classID==11 or info.equipLoc=='INVTYPE_QUIVER') or false end
local ammoSlots
function E.ResetBagRoles() ammoSlots=nil end
function E.AmmoBagSlots()
    if ammoSlots then return ammoSlots end
    local out={}
    for slot=20,23 do
        local link=S.Read(GetInventoryItemLink,'player',E.Inventory(slot))
        local info=S.Text(link) and ns.Items.Read(link) or nil
        if info and not info.missing and E.IsAmmoBag(info) then out[#out+1]=slot end
    end
    ammoSlots=out;return out
end
local GENERAL_BAG_SLOTS={20,21,22,23}
local function BagSlots(info)
    local ammo=E.AmmoBagSlots()
    if E.IsAmmoBag(info) then
        local _,class=S.Read(UnitClass,'player')
        if class~='HUNTER' then return nil end
        return #ammo>0 and ammo or GENERAL_BAG_SLOTS
    end
    if #ammo==0 then return GENERAL_BAG_SLOTS end
    local out={}
    for _,slot in ipairs(GENERAL_BAG_SLOTS) do local held=false;for _,a in ipairs(ammo) do if a==slot then held=true end end;if not held then out[#out+1]=slot end end
    return out
end
-- Ammo (item class 6: arrows 2, bullets 3) for the worn ranged weapon. Nil when it doesn't apply.
local function AmmoType()
    local _,class=S.Read(UnitClass,'player')
    if class~='HUNTER' then return nil end
    local link=S.Read(GetInventoryItemLink,'player',18)
    local ranged=S.Text(link) and ns.Items.Read(link) or nil
    return ranged and not ranged.missing and ns.HunterData and ns.HunterData.ammoFor[ranged.subclassID] or nil
end
local function AmmoDPS(info) return S.Number(info.stats.DPS) and info.stats.DPS or 0 end
local function AmmoUsable(info) return info.usable and (info.reqLevel or 0)<=ns.Level() and not ns.Char().ignore[info.id] end
local function WornAmmo(want)
    local link=S.Read(GetInventoryItemLink,'player',0)
    local info=S.Text(link) and ns.Items.Read(link) or nil
    if info and not info.missing and info.classID==6 and info.subclassID==want then return info end
end
-- The best usable ammo in your bags when it beats the ammo slot (or the slot is empty or holds the wrong
-- type). Higher-tier ammo becomes usable on level-up, when requirements are re-read.
function E.AmmoJob()
    if not ns.Char().autoAmmo then return nil end
    local want=AmmoType();if not want then return nil end
    local worn=WornAmmo(want)
    local floor=worn and AmmoDPS(worn) or -1
    local best
    for _,job in ipairs(E.BagItems()) do
        local i=job.info
        if i.classID==6 and i.subclassID==want and not i.missing and AmmoUsable(i) and AmmoDPS(i)>floor+0.0001 and (not best or AmmoDPS(i)>AmmoDPS(best.info)) then
            best={bag=job.bag,slot=job.slot,info=i,target=0,delta=AmmoDPS(i)-math.max(0,floor),reason='Better ammo'}
        end
    end
    return best
end
-- One tooltip line for ammo: better than the slot, worse, the wrong type, or usable later.
function E.AmmoVerdict(info)
    if not info or info.missing or info.classID~=6 then return nil end
    local want=AmmoType();if not want then return nil end
    if info.subclassID~=want then return 'does not fit your ranged weapon',false end
    if (info.reqLevel or 0)>ns.Level() then return ('usable at level %d'):format(info.reqLevel),false end
    local worn=WornAmmo(want)
    local diff=AmmoDPS(info)-(worn and AmmoDPS(worn) or 0)
    if not worn or diff>0.0001 then return ('better ammo (+%.1f damage per second)'):format(diff),true end
    if worn.id==info.id then return 'your equipped ammo',false end
    return 'not better than your equipped ammo',false
end
local MAIN,OFF={16},{17}
function E.Slots(info,w)
    if not info or not info.usable or (info.reqLevel or 0)>ns.Level() then return nil end
    local c=ns.Char();if c.ignore[info.id] or c.ignoreLinks[info.link] then return nil end
    local style=c.weaponStyle~='preset' and c.weaponStyle or w and w.weapons or 'any'
    local loc,dual=info.equipLoc,S.Yes(S.Read(CanDualWield))
    if loc=='INVTYPE_BAG' and E.IsReagentBag(info) then return E.HAS_REAGENT_BAG and {E.REAGENT_SLOT} or nil end
    -- Profession bags (container subclass other than general) stay the player's choice.
    if loc=='INVTYPE_BAG' and info.classID==1 and (info.subclassID or 0)~=0 then return nil end
    if loc=='INVTYPE_BAG' or loc=='INVTYPE_QUIVER' then return BagSlots(info) end
    if E.MELEE[loc] then
        if style=='2h' and loc~='INVTYPE_2HWEAPON' then return nil end
        if loc=='INVTYPE_2HWEAPON' and (style=='weapon and shield' or style=='dagger and any' or style=='dual wield' and dual) then return nil end
        if loc=='INVTYPE_WEAPONOFFHAND' then if not dual or style=='weapon and shield' then return nil end;return OFF end
        if loc=='INVTYPE_WEAPONMAINHAND' then if style=='dagger and any' and info.subclassID~=15 then return nil end;return MAIN end
        if loc=='INVTYPE_WEAPON' then
            if style=='dagger and any' and info.subclassID~=15 then return dual and OFF or nil end
            if not dual or style=='weapon and shield' then return MAIN end
        end
    elseif loc=='INVTYPE_SHIELD' and style~='any' and style~='weapon and shield' then return nil
    elseif loc=='INVTYPE_HOLDABLE' and style~='any' then return nil end
    return SLOTS[loc]
end
local function Copy(set) local out={};for k,v in pairs(set) do out[k]=v end;return out end
local function Legal(set)
    local main,off=set[16],set[17]
    if main and main.info and main.info.equipLoc=='INVTYPE_2HWEAPON' and off and off.info then return false end
    local ids,categories,quivers={},{},0
    for _,entry in pairs(set) do
        local info=entry.info
        if info then
            if info.missing then return false end
            if info.classID==11 then quivers=quivers+1;if quivers>1 then return false end end
            ids[info.id]=(ids[info.id] or 0)+1
            if info.unique and ids[info.id]>1 then return false end
            if info.uniqueCategory then
                local key=info.uniqueCategory
                local rule=categories[key] or {count=0,limit=info.uniqueLimit or 1}
                rule.count,rule.limit=rule.count+1,math.min(rule.limit,info.uniqueLimit or 1);categories[key]=rule
                if rule.count>rule.limit then return false end
            end
        elseif entry.link then return false end
    end
    return true
end
E.Legal=Legal
-- Bag space that helps everyone: general containers (item class 1, subclass 0) and ammo containers.
-- Profession bags (herb, enchanting, soul and so on) hold only their own goods, so their slots never
-- count, and a 12-slot herb bag can't replace a 10-slot general bag.
function E.BagCapacity(info)
    if not info then return 0 end
    if E.IsReagentBag(info) then return info.capacity or 0 end
    if info.classID==1 and (info.subclassID or 0)~=0 then return 0 end
    return info.capacity or 0
end
function E.SetupScore(set)
    if not Legal(set) then return nil,false end
    local value,known,sets,seen=0,true,{},{}
    for _,entry in pairs(set) do local i=entry.info;if i and i.setID then sets[i.setID]=(sets[i.setID] or 0)+1 end end
    local useCount,quiverHaste=0,0
    for slot,entry in pairs(set) do
        if entry.temporaryEnchant then known=false end
        local i=entry.info
        if i then
            local v,k=E.Score(i,slot);if not S.Number(v) then return nil,false end
            value=value+v;known=known and k
            if slot>=20 then
                value=value+E.BagCapacity(i)
                if i.quiverHaste then
                    local ranged=set[18] and set[18].info
                    local matches=ranged and ((i.subclassID==3 and ranged.subclassID==3) or (i.subclassID==2 and (ranged.subclassID==2 or ranged.subclassID==18)))
                    -- Ranged haste from ammo containers does not stack: only the best matching one counts.
                    if matches then quiverHaste=math.max(quiverHaste,i.quiverHaste) end
                end
            end
            for _,p in ipairs(i.procs or {}) do if p.kind=='use' then useCount=useCount+1 end end
            for _,effect in ipairs(i.setEffects or {}) do
                local key=tostring(i.setID) .. ':' .. tostring(effect.threshold)
                if i.setID and effect.threshold and (sets[i.setID] or 0)>=effect.threshold and not seen[key] and effect.effect then
                    seen[key]=true;local p=effect.effect
                    if p.kind then local n,k2=E.ProcValue(i,p,ns.Weights.Current() or {});value=value+n;known=known and k2
                    else for stat,amount in pairs(p) do value=value+amount*E.StatWeight(ns.Weights.Current() or {},stat) end end
                end
            end
        end
    end
    value=value+quiverHaste*((ns.Weights.Current() or {}).HastePercent or 1)
    -- Tooltip text cannot identify every shared cooldown group. Such setups need a manual choice.
    if useCount>1 then known=false end
    return value,known
end
local function Replacement(info,slot,set)
    local out=Copy(set);out[slot]={info=info,link=info.link}
    local c=ns.Char()
    if slot==16 and info.equipLoc=='INVTYPE_2HWEAPON' then
        if c.locked[17] and set[17] and set[17].link then return nil end
        out[17]={}
    elseif slot==17 and set[16] and set[16].info and set[16].info.equipLoc=='INVTYPE_2HWEAPON' then return nil end
    return out
end
function E.Verdict(info,set)
    if not info or info.missing then return nil,nil,'Item data pending' end
    local slots=E.Slots(info,ns.Weights.Current());if not slots then return nil,nil,info.reason or 'Blocked by requirements or equipment rules' end
    set=set or E.Equipped()
    local base=E.SetupScore(set);if not S.Number(base) then return nil,nil,'Equipped comparison unavailable' end
    local best,target
    for _,slot in ipairs(slots) do
        if not ns.Char().locked[slot] then
            local current=set[slot]
            if not (current and current.link==info.link) then
                local candidate=Replacement(info,slot,set)
                local score=candidate and E.SetupScore(candidate)
                if S.Number(score) and score>base+0.0000001 and (not best or score>best) then best,target=score,slot end
            end
        end
    end
    if not target then return nil,nil,'No supported upgrade' end
    local current=set[target]
    if not current or not current.info then return best-base,target,'Fills an empty slot' end
    return best-base,target,('+%.1f over %s'):format(best-base,current.info.name or 'equipped item')
end
-- An automatic choice is only as certain as the items it touches: the candidate, whatever it
-- replaces, and a second Use: effect it would sit beside (shared cooldowns are not readable).
-- Uncertain gear elsewhere scores the same on both sides of the comparison, so it no longer
-- blocks unrelated upgrades. (Audit status N01/N02.)
function E.TouchedKnown(set,info,target)
    if not info or not target or not E.AutomationSafe(info) then return false end
    local touched={[target]=true}
    if info.equipLoc=='INVTYPE_2HWEAPON' then touched[17]=true end
    local uses=0
    for _,p in ipairs(info.procs or {}) do if p.kind=='use' then uses=uses+1 end end
    for slot,entry in pairs(set) do
        local worn=entry.info
        if worn then
            if touched[slot] then
                if entry.temporaryEnchant then return false end
                local _,known=E.Score(worn,slot)
                if not known or not E.AutomationSafe(worn) then return false end
            else
                for _,p in ipairs(worn.procs or {}) do if p.kind=='use' then uses=uses+1 end end
            end
        end
    end
    return uses<=1
end
function E.BagItems()
    local out={};local C=C_Container
    for bag=0,NUM_BAG_SLOTS or 4 do
        local n=S.Read(C and C.GetContainerNumSlots,bag)
        if S.Number(n) and n>=0 and n<=200 then
            for slot=1,n do
                local link=S.Read(C.GetContainerItemLink,bag,slot)
                if S.Text(link) then local info=ns.Items.Read(link,bag,slot);if info then out[#out+1]={bag=bag,slot=slot,info=info} end end
            end
        end
    end
    return out
end
local function BagSafe(job)
    local i=job.info
    if i.equipLoc~='INVTYPE_BAG' and i.equipLoc~='INVTYPE_QUIVER' then return true end
    if not ns.Char().autoBags then return false end
    local bag=E.ContainerFor(job.target);if job.bag==bag then return false end
    local n=S.Read(C_Container and C_Container.GetContainerNumSlots,bag)
    if not S.Number(n) then return false end
    for slot=1,n do if S.Read(C_Container.GetContainerItemLink,bag,slot) then return false end end
    return true
end
local function HandPlans(items,set,automatic,eligible)
    -- Multi-step swaps require rollback/capacity verification in the real client.
    -- Keep the complete setup recommendation, but never execute a partial pair automatically.
    if automatic then return nil end
    if ns.Char().locked[16] or ns.Char().locked[17] then return nil end
    local base=E.SetupScore(set);if not base then return nil end
    local mains,offs={},{}
    local function Add(job)
        if job.info.missing or automatic and (not ns.AutoEquipAllowed(job.info) or not E.AutomationSafe(job.info)) then return end
        if job.bag~=nil and eligible and not eligible(job) then return end
        local slots=E.Slots(job.info,ns.Weights.Current())
        for _,slot in ipairs(slots or {}) do
            if slot==16 and job.info.equipLoc~='INVTYPE_2HWEAPON' then mains[#mains+1]=job end
            if slot==17 then offs[#offs+1]=job end
        end
    end
    if set[16] and set[16].info then Add({info=set[16].info,worn=16}) end
    if set[17] and set[17].info then Add({info=set[17].info,worn=17}) end
    for _,job in ipairs(items) do if E.MELEE[job.info.equipLoc] or job.info.equipLoc=='INVTYPE_SHIELD' or job.info.equipLoc=='INVTYPE_HOLDABLE' then Add(job) end end
    if #mains*#offs>4096 then return nil end
    local best,plan=base,nil
    for _,main in ipairs(mains) do for _,off in ipairs(offs) do
        if main~=off and not (main.bag~=nil and main.bag==off.bag and main.slot==off.slot) then
            local candidate=Copy(set);candidate[16]={info=main.info,link=main.info.link};candidate[17]={info=off.info,link=off.info.link}
            local value,known=E.SetupScore(candidate)
            if value and value>best+0.0001 and (not automatic or known) then
                local first=not main.worn and main or not off.worn and off
                if first then
                    best=value;plan={bag=first.bag,slot=first.slot,info=first.info,target=first==main and 16 or 17,delta=value-base,reason='Better main-hand and off-hand setup'}
                    if not main.worn and not off.worn then plan.follow={bag=off.bag,slot=off.slot,info=off.info,target=17} end
                end
            end
        end
    end end
    return plan
end
function E.BagUpgrades(set,automatic,eligible)
    E.BeginPass();set=set or E.Equipped()
    if automatic and not S.Number(E.SetupScore(set)) then E.EndPass();return {} end
    local items,bySlot=E.BagItems(),{}
    for _,job in ipairs(items) do
        if not automatic or ns.AutoEquipAllowed(job.info) and E.AutomationSafe(job.info) then
            if not eligible or eligible(job) then
                local delta,target,reason=E.Verdict(job.info,set)
                if delta and (not automatic or E.TouchedKnown(set,job.info,target)) then
                    job.delta,job.target,job.reason=delta,target,reason
                    if (not automatic or BagSafe(job)) and (not bySlot[target] or delta>bySlot[target].delta) then bySlot[target]=job end
                end
            end
        end
    end
    local pair=HandPlans(items,set,automatic,eligible)
    if pair and (not bySlot[pair.target] or pair.delta>bySlot[pair.target].delta) then bySlot[pair.target]=pair end
    local out={};for _,job in pairs(bySlot) do out[#out+1]=job end
    table.sort(out,function(a,b) return a.delta>b.delta end);E.EndPass();return out
end
function E.BagBaseline()
    local worn=E.Equipped(true)
    -- The baseline is what you own. Uncertain worn items keep their estimate; bag items that are
    -- pending or uncertain are left out instead of aborting the search (audit status N02).
    local bestScore=E.SetupScore(worn)
    if not S.Number(bestScore) then return worn,false end
    local pools,slots,used,ids,categories,limits={},{},{},{},{},{}
    local set,best,steps,exhausted={},Copy(worn),0,false
    local setUpper,seenSet=0,{}
    local function ConsiderEffects(info)
        for _,effect in ipairs(info and info.setEffects or {}) do
            local key=tostring(info.setID) .. ':' .. tostring(effect.threshold)
            if not seenSet[key] and effect.effect then
                seenSet[key]=true;local value=0;local p=effect.effect
                if p.kind then value=E.ProcValue(info,p,ns.Weights.Current() or {})
                else for stat,n in pairs(p) do value=value+n*E.StatWeight(ns.Weights.Current() or {},stat) end end
                setUpper=setUpper+math.max(0,value)
            end
        end
    end
    local function Add(info,key,onlySlot)
        if not info or info.missing then return end
        ConsiderEffects(info)
        for _,slot in ipairs(onlySlot and {onlySlot} or E.Slots(info,ns.Weights.Current()) or {}) do
            if not ns.Char().locked[slot] or onlySlot then
                local value,k=E.Score(info,slot)
                if value then
                    local upper=value+(slot>=20 and (E.BagCapacity(info)+(info.quiverHaste or 0)*((ns.Weights.Current() or {}).HastePercent or 1)) or 0)
                    pools[slot][#pools[slot]+1]={entry={info=info,link=info.link},key=key,value=upper}
                end
            end
        end
    end
    for _,slot in ipairs(E.EQUIP_SLOTS) do
        slots[#slots+1]=slot;pools[slot]={}
        if not ns.Char().locked[slot] or not worn[slot].info then pools[slot][1]={entry={},value=0,known=true} end
    end
    for _,slot in ipairs(slots) do
        local entry=worn[slot]
        if entry.info then
            Add(entry.info,'worn:' .. slot,slot)
            if not ns.Char().locked[slot] then Add(entry.info,'worn:' .. slot) end
        end
    end
    local items=E.BagItems()
    for _,job in ipairs(items) do
        if not job.info.missing and E.AutomationSafe(job.info) then Add(job.info,job.bag .. ':' .. job.slot) end
    end
    local upper={}
    for i,slot in ipairs(slots) do
        table.sort(pools[slot],function(a,b) return a.value>b.value end)
        upper[i]=pools[slot][1] and pools[slot][1].value or 0
    end
    for i=#slots-1,1,-1 do upper[i]=upper[i]+upper[i+1] end
    local function Search(index,value)
        steps=steps+1;if steps>10000 then exhausted=true;return end
        if value+(upper[index] or 0)+setUpper<=bestScore+0.0000001 then return end
        if index>#slots then
            local score=E.SetupScore(set)
            if score and score>bestScore then bestScore,best=score,Copy(set) end
            return
        end
        local slot=slots[index]
        for _,candidate in ipairs(pools[slot]) do
            local info,key=candidate.entry.info,candidate.key
            local id=info and info.id
            local category=info and info.uniqueCategory
            local oldCount,oldLimit=category and categories[category] or 0,category and limits[category] or nil
            local allowed=not key or not used[key]
            if info and info.unique and (ids[id] or 0)>0 then allowed=false end
            if category and oldCount+1>math.min(oldLimit or 1000,info.uniqueLimit or 1) then allowed=false end
            if allowed then
                set[slot]=candidate.entry
                if key then used[key]=true end
                if id then ids[id]=(ids[id] or 0)+1 end
                if category then categories[category],limits[category]=oldCount+1,math.min(oldLimit or 1000,info.uniqueLimit or 1) end
                local hands=slot~=17 or not (set[16] and set[16].info and set[16].info.equipLoc=='INVTYPE_2HWEAPON' and info)
                if hands then Search(index+1,value+candidate.value) end
                if key then used[key]=nil end
                if id then ids[id]=ids[id]-1 end
                if category then categories[category],limits[category]=oldCount,oldLimit end
                set[slot]=nil
                if exhausted then return end
            end
        end
    end
    Search(1,0)
    E.lastBaselineSteps=steps
    return best,not exhausted
end
function E.QuestChoice()
    local n=S.Read(GetNumQuestChoices);if not S.Number(n) or n<1 then return nil,'none' end
    E.BeginPass();local set,complete=E.BagBaseline();local upgrades,nonGear={},false
    if not complete then E.EndPass();return nil,'manual','Setup search incomplete' end
    local index,gain,why,vendor,price,bestInfo,bestTarget
    for i=1,n do
        local link=S.Read(GetQuestItemLink,'choice',i);local info=link and ns.Items.Read(link)
        if not info or info.missing then E.EndPass();return nil,'pending' end
        if not SLOTS[info.equipLoc] then nonGear=true end
        if SLOTS[info.equipLoc] and not E.AutomationSafe(info) then nonGear=true end
        local delta,target,reason=E.Verdict(info,set)
        if delta then upgrades[i]=true;if not gain or delta>gain then index,gain,why,bestInfo,bestTarget=i,delta,reason,info,target end end
        local _,_,count=S.Read(GetQuestItemInfo,'choice',i)
        local value=info.price*(S.Number(count) and count>0 and count or 1)
        if S.Number(value) and (not price or value>price) then price,vendor=value,i end
    end
    -- Only the best reward's own comparison has to be certain (audit status N02).
    local certain=index and E.TouchedKnown(set,bestInfo,bestTarget)
    E.EndPass()
    if nonGear then return nil,'manual',nil,upgrades,not index and vendor or nil end
    if index and not certain then return nil,'manual','Best reward replaces an item Gear cannot price',upgrades end
    if index then return index,'upgrade',why,upgrades end
    return vendor,'vendor','No upgrade: highest vendor value',upgrades,vendor
end
function E.RollChoice(id)
    E.BeginPass()
    local link=S.Read(GetLootRollItemLink,id);local info=link and ns.Items.Read(link)
    if not info or info.missing then E.EndPass();return nil,'pending' end
    local _,_,_,_,_,need,greed=S.Read(GetLootRollItemInfo,id)
    local baseline,complete=E.BagBaseline()
    if not complete then E.EndPass();return nil,'Setup search incomplete: choose manually',info end
    local delta,target,reason=E.Verdict(info,baseline)
    local certain=not delta or E.TouchedKnown(baseline,info,target)
    E.EndPass()
    if not E.AutomationSafe(info) or not certain then return nil,'Model uncertainty: choose manually',info,delta~=nil end
    if delta and S.Yes(need) and ns.Char().rollNeedUpgrades then return 1,reason,info,true end
    if delta and not ns.Char().rollNeedUpgrades then return nil,'Need on upgrades is off: choose manually',info,true end
    if S.Yes(greed) and ns.Char().rollGreedOthers then return 2,delta and 'Upgrade, but Need is not allowed' or 'Not an upgrade',info,delta~=nil end
    return nil,'Greed is not allowed: choose manually',info,delta~=nil
end
