-- FHK Gear: bounded action transactions and item-data waiters.
-- CC BY-NC-SA 4.0. See LICENSE.md. No protected frame changes.
if EUI_CLIENT_BLOCKED then return end
local _, ns = ...
local S, A, H = ns.Safe, {}, ns.handlers
ns.Actions = A
local generation, queued, transaction = 0, false, nil
local waiters, failures, rolls = {}, {}, {}
local budgets={}
local questGeneration, questOpen, questShift = 0, false, false
local retryQueued, cursorRetries = false, 0
-- Slots the player changed by hand (review GC1): auto-equip leaves them until the next level.
local manual, ownedUntil = {}, 0
-- Items Gear itself took off (review GC4): live Hunter weights move with the worn item, so two near-equal
-- items could otherwise swap back and forth.
local removed = {}
local function Timer(delay, fn)
    if not S.Call('timer', C_Timer and C_Timer.After, delay, fn) then S.Note('scheduler','Timer unavailable') end
end
local function Busy()
    local cursor,targeting=S.Read(CursorHasItem),S.Read(SpellIsTargeting)
    -- Dead, or dragging a spell, macro or money (review GC10): a pickup would drop what the player holds.
    local dead,held=S.Read(UnitIsDeadOrGhost,'player'),S.Read(GetCursorInfo)
    return not S.OutsideCombat() or not S.Plain(cursor) or cursor~=false or not S.Plain(targeting) or targeting~=false or dead==true or held~=nil
end
local function Key(job) return job.bag .. ':' .. job.slot .. ':' .. job.info.link end
local function Source(job)
    local C=C_Container
    local info=S.Read(C and C.GetContainerItemInfo,job.bag,job.slot)
    return S.Table(info) and S.Text(info.hyperlink) and info.hyperlink==job.info.link and info.isLocked==false
end
local function CursorIs(link)
    local kind,id,hyperlink=S.Read(GetCursorInfo)
    if not (S.Text(kind) and kind=='item') then return false end
    if S.Text(hyperlink) then return hyperlink==link end
    -- An ID alone cannot prove ownership of an enchanted/random-suffix variant.
    return false
end
local function ClearOwned(tx)
    if tx and (CursorIs(tx.link) or tx.oldLink and CursorIs(tx.oldLink)) then S.Call('clear owned cursor',ClearCursor) end
end
local function Failed(tx)
    if not tx then return end
    local size=0
    for key,record in pairs(failures) do
        -- Expired records are kept 10 minutes so a repeat failure still counts (review GC3).
        if record.untilTime+600<S.Time() then failures[key]=nil else size=size+1 end
    end
    if size>=128 then failures={} end
    local rec=failures[tx.key] or {tries=0}
    -- A declined bind prompt, or a second failure, ends retries for the session (review GC3).
    rec.tries=rec.tries+(tx.declined and 2 or 1)
    rec.untilTime=S.Time()+(rec.tries>=2 and 1e9 or 60)
    if rec.tries>=2 and not rec.told then rec.told=true;ns.Say('Auto-equip skips ' .. tostring(tx.link) .. ' this session. Equip it by hand if you want it.') end
    failures[tx.key]=rec
    ClearOwned(tx);transaction=nil
end
function A.Acknowledge(slot)
    local tx=transaction
    if not tx or slot and ns.Engine.FromInventory(slot)~=tx.target then return false end
    if S.Read(GetInventoryItemLink,'player',ns.Engine.Inventory(tx.target))~=tx.link then return false end
    failures[tx.key]=nil;ClearOwned(tx);transaction=nil
    -- The equip event (and a displaced off hand's) can land after this acknowledgement.
    ownedUntil=S.Time()+2
    if S.Text(tx.oldLink) then removed[tx.oldLink]=S.Time()+600 end
    ns.Engine.InvalidateEquipped()
    local shown=false
    if ns.Notify then local _,ok=S.Call('pop-up equipped',ns.Notify.Equipped,tx.link,tx.delta,tx.oldLink);shown=ok==true end
    ns.SayAction('Equipped ' .. tx.link .. '.',shown)
    -- Continue a checked hand-pair plan only after the first hand is acknowledged.
    if tx.follow then
        local follow=tx.follow
        follow.planned=true
        Timer(0.3,function() if tx.generation==generation and ns.Automating('autoEquip') then A.Equip(follow) end end)
    end
    return true
end
-- A slot change Gear did not make is the player's choice (review GC1): never swap it straight back.
function A.Changed(slot)
    if not S.Number(slot) or slot==0 or transaction or S.Time()<ownedUntil then return end
    local target=ns.Engine.FromInventory(slot)
    if manual[target] then return end
    manual[target]=true
    if ns.Automating('autoEquip') then ns.Say('Auto-equip leaves that slot as you set it until your next level.') end
end
function A.ClearManual() manual={} end
function A.Manual(target) return manual[target]==true end
function A.Eligible(job)
    if manual[job.target] or job.info.equipLoc=='INVTYPE_2HWEAPON' and manual[17] then return false end
    local back=removed[job.info.link]
    -- Into an empty slot, or the ammo slot (not weight-scored), it may go straight back on.
    if back and not job.planned and job.target~=0 then
        if back<=S.Time() then removed[job.info.link]=nil
        elseif S.Text(S.Read(GetInventoryItemLink,'player',ns.Engine.Inventory(job.target))) then return false end
    end
    if not Source(job) then return false end
    if job.info.equipLoc=='INVTYPE_2HWEAPON' and S.Text(S.Read(GetInventoryItemLink,'player',17)) then
        local free=0
        for bag=0,NUM_BAG_SLOTS or 4 do
            local count,family=S.Read(C_Container and C_Container.GetContainerNumFreeSlots,bag)
            if S.Number(count) and count>0 and (bag==0 or S.Number(family) and family==0) then free=free+count end
        end
        -- The candidate's vacated slot covers one displaced weapon. The other needs general storage.
        if free<1 then return false end
    end
    local rec=failures[Key(job)]
    return not rec or rec.untilTime<S.Time()
end
function A.Equip(job)
    if not ns.Automating('autoEquip') or Busy() or transaction or not ns.AutoEquipAllowed(job.info) or not A.Eligible(job) then return false end
    local tx={generation=generation,key=Key(job),link=job.info.link,target=job.target,oldLink=S.Read(GetInventoryItemLink,'player',ns.Engine.Inventory(job.target)),follow=job.follow,
        binding=job.info.bound=='boe',stage='pickup',delta=job.delta}
    transaction=tx
    if not S.Call('pickup',C_Container and C_Container.PickupContainerItem,job.bag,job.slot) or not CursorIs(tx.link) then Failed(tx);ns.QueueEquip(0.3);return false end
    tx.stage='equip'
    if not S.Call('equip cursor',EquipCursorItem,ns.Engine.Inventory(job.target)) then Failed(tx);return false end
    -- The ammo slot only references a stack: if the client leaves it on the cursor, put it back.
    if job.target==0 and S.Read(CursorHasItem)==true and CursorIs(tx.link) then S.Call('ammo cursor',ClearCursor) end
    if A.Acknowledge() then return true end
    local function Timeout() if transaction==tx then Failed(tx);if ns.Automating('autoEquip') then ns.QueueEquip(0.3) end end end
    Timer(2,function()
        if transaction==tx and tx.awaitingBind then Timer(13,function() if transaction==tx then tx.declined=true end;Timeout() end) else Timeout() end
    end)
    return true
end
local function WakeEvent()
    ns.Want('GET_ITEM_INFO_RECEIVED',next(waiters)~=nil)
end
local function ArmWaiters()
    if retryQueued or not next(waiters) then return end
    retryQueued=true
    Timer(1,function()
        retryQueued=false
        local calls={}
        for key,job in pairs(waiters) do
            waiters[key]=nil
            if job.generation==generation and S.Time()<=job.deadline and job.tries<3 then
                job.tries=job.tries+1;calls[#calls+1]={key,job}
            end
        end
        for _,pair in ipairs(calls) do
            local key,job=pair[1],pair[2]
            A.Wait(key,job.fn,job.tries,job.deadline)
            job.fn()
        end
        WakeEvent();ArmWaiters()
    end)
end
function A.Wait(key,fn,tries,deadline,requested)
    local ids={}
    for id in pairs(requested or ns.Engine.PendingIDs()) do if ns.Items.PendingIDs()[id] then ids[id]=true end end
    if not next(ids) then
        -- No item ID to wait on yet, e.g. a reward link not built (review GC7): retry on a timer, same budget.
        if requested or tries then waiters[key],budgets[key]=nil,nil;WakeEvent();return end
        local budget=budgets[key] or {tries=0,deadline=S.Time()+10};budgets[key]=budget
        budget.tries=budget.tries+1
        if budget.tries>3 or S.Time()>budget.deadline then waiters[key],budgets[key]=nil,nil;WakeEvent();return end
        local epoch=generation
        Timer(1,function() if epoch==generation and budgets[key]==budget then fn() end end)
        return
    end
    local size=0;for _ in pairs(waiters) do size=size+1 end
    if not waiters[key] and size>=64 then S.Note('waiters','Item waiter limit reached');return end
    local old=waiters[key]
    local budget=budgets[key] or {tries=0,deadline=S.Time()+10};budgets[key]=budget
    budget.tries=math.max(budget.tries,tries or old and old.tries or 0)
    if deadline then budget.deadline=math.min(budget.deadline,deadline) end
    if budget.tries>=3 or S.Time()>budget.deadline then waiters[key]=nil;S.Note('wait timeout:' .. key,'Item work left manual after retry budget');WakeEvent();return end
    waiters[key]={ids=ids,fn=fn,tries=budget.tries,deadline=budget.deadline,generation=generation}
    WakeEvent();ArmWaiters()
end
function A.Cancel()
    generation=generation+1;queued=false
    ClearOwned(transaction);transaction=nil;waiters={};rolls={};budgets={}
    questGeneration=questGeneration+1;questOpen=false;questShift=false;cursorRetries=0
    WakeEvent()
end
function A.Refresh()
    if not ns.Automating('autoEquip') then queued=false;ClearOwned(transaction);transaction=nil end
    if not ns.Automating('autoQuest') then waiters.quest=nil end
    if not ns.Automating('autoRoll') then rolls={} end
    if not ns.ActiveFeatures() then A.Cancel() end
    WakeEvent()
end
function A.PendingCount() local n=0;for _ in pairs(waiters) do n=n+1 end;return n end
function ns.QueueEquip(delay)
    if queued or transaction or not ns.Automating('autoEquip') then return end
    queued=true
    local epoch=generation
    Timer(delay or 0.3,function()
        if epoch~=generation then return end
        queued=false
        if not ns.Automating('autoEquip') then return end
        if not S.OutsideCombat() then ns.Want('PLAYER_REGEN_ENABLED',true);return end
        if Busy() then
            cursorRetries=cursorRetries+1
            if cursorRetries<=8 then ns.QueueEquip(0.5) end
            return
        end
        cursorRetries=0
        local jobs=ns.Engine.BagUpgrades(nil,true,A.Eligible)
        if ns.Engine.HasPending() then A.Wait('equip',function() ns.QueueEquip(0.3) end) else waiters.equip,budgets.equip=nil,nil;WakeEvent() end
        local acted=false
        for _,job in ipairs(jobs) do if A.Equip(job) then acted=true;break end end
        -- Gear first, then ammo for the ranged weapon now worn.
        if not acted then local ammo=ns.Engine.AmmoJob();if ammo then A.Equip(ammo) end end
    end)
end
H.PLAYER_REGEN_ENABLED=function()
    ns.Want('PLAYER_REGEN_ENABLED',false);ns.QueueEquip(0.3)
    -- Bag work and Upgrade Found scans held during combat (review GU5, GU6).
    if ns.BagsAfterCombat then ns.BagsAfterCombat() end
    if ns.Notify and ns.Notify.AfterCombat then ns.Notify.AfterCombat() end
end
H.EQUIP_BIND_CONFIRM=function(slot)
    if not S.Number(slot) then return end
    local tx=transaction
    -- Never infer ownership from a time window. Exact pending target and owned cursor are required.
    if tx and tx.generation==generation and tx.stage=='equip' and tx.binding and ns.Engine.FromInventory(slot)==tx.target and
        ns.Automating('autoEquip') and S.OutsideCombat() and CursorIs(tx.link) then
        tx.awaitingBind=true
        if not ns.Char().confirmEquipBinds then return end
        if not S.Call('owned bind confirm',EquipPendingItem,slot) then Failed(tx) else A.Acknowledge(slot) end
    end
end
H.GET_ITEM_INFO_RECEIVED=function(id,success)
    if not ns.Items.Arrived(id,success) then return end
    ns.Engine.InvalidateEquipped()
    local calls={}
    for key,job in pairs(waiters) do
        if job.ids[id] then
            waiters[key]=nil
            if budgets[key] then budgets[key].tries=budgets[key].tries+1 end
            calls[#calls+1]=job
        end
    end
    for _,job in ipairs(calls) do if job.generation==generation and S.Time()<=job.deadline then job.fn() end end
    WakeEvent()
end
-- Shift held as the reward window opens, or while Gear would pick (review G3): the choice is yours.
-- Rewards are still marked. The flag lasts for this window only.
local function ShiftDown() local v=S.Read(IsShiftKeyDown);return S.Plain(v) and v==true end
-- EllesmereUI's Quest Tracker hands in a quest with one reward (or none) itself when its Auto Turn-In
-- is on: Gear only marks that reward, so the window never gets two hand-ins (suite review SQ-4).
local function EllesmereTurnsIn()
    local Q=_G.EllesmereUIQuestTracker
    if type(Q)~='table' or type(Q.Cfg)~='function' then return false end
    local okE,enabled=pcall(Q.Cfg,'enabled')
    if okE and enabled==false then return false end
    local ok,on=pcall(Q.Cfg,'autoTurnIn')
    if not ok or on~=true then return false end
    local n=S.Read(GetNumQuestChoices)
    return S.Number(n) and n<=1 or false
end
A.EllesmereTurnsIn=EllesmereTurnsIn
local function Quest(token)
    if not questOpen or token~=questGeneration then return end
    local index,how,_,upgrades,vendor=ns.Engine.QuestChoice()
    if ns.MarkQuestRewards then ns.MarkQuestRewards(upgrades or {},vendor) end
    if how=='pending' then A.Wait('quest',function() Quest(token) end);return end
    waiters.quest,budgets.quest=nil,nil;WakeEvent()
    if index and ns.Automating('autoQuest') and questOpen and token==questGeneration and S.OutsideCombat() then
        if questShift or ShiftDown() then questShift=true;return end
        if EllesmereTurnsIn() then return end
        local link=S.Read(GetQuestItemLink,'choice',index)
        if S.Call('quest reward',GetQuestReward,index) and S.Text(link) then
            local shown=false
            if ns.Notify then local _,ok=S.Call('pop-up quest',ns.Notify.QuestReward,link,how);shown=ok==true end
            ns.SayAction('Picked quest reward ' .. link .. (how=='vendor' and ' (best vendor value).' or '.'),shown)
        end
    end
end
A.QuestShift=function() return questShift end
H.QUEST_COMPLETE=function()
    questGeneration=questGeneration+1;questOpen=true
    questShift=ns.Automating('autoQuest') and ShiftDown() or false
    Quest(questGeneration)
end
H.QUEST_FINISHED=function() questGeneration=questGeneration+1;questOpen=false;questShift=false;waiters.quest,budgets.quest=nil,nil;WakeEvent();if ns.ClearQuestMarks then ns.ClearQuestMarks() end end
local function Roll(id,rec)
    if rolls[id]~=rec or S.Time()>rec.deadline then rolls[id]=nil;waiters['roll:' .. id]=nil;return end
    local choice,why,info,upgrade=ns.Engine.RollChoice(id)
    if ns.MarkRoll then
        ns.MarkRoll(id,info,upgrade)
        Timer(0.1,function() if rolls[id]==rec and ns.Char().markRoll then ns.MarkRoll(id,info,upgrade) end end)
    end
    if why=='pending' then A.Wait('roll:' .. id,function() Roll(id,rec) end);return end
    waiters['roll:' .. id],budgets['roll:' .. id]=nil,nil;WakeEvent()
    -- RollOnLoot is not protected (review GC5): rolls are answered in combat too.
    if choice and ns.Automating('autoRoll') then
        rec.choice=choice
        local link=S.Read(GetLootRollItemLink,id)
        if not S.Call('loot roll',RollOnLoot,id,choice) then rolls[id]=nil
        elseif S.Text(link) then
            local shown=false
            if ns.Notify then local _,ok=S.Call('pop-up roll',ns.Notify.Rolled,link,choice);shown=ok==true end
            ns.SayAction(('Rolled %s on %s (%s).'):format(choice==1 and 'Need' or 'Greed',link,tostring(why or '')),shown)
        end
    end
end
H.START_LOOT_ROLL=function(id,time)
    if not S.Number(id) then return end
    local n=0;for _ in pairs(rolls) do n=n+1 end;if n>=64 then return end
    local duration=S.Number(time) and math.min(300,time/1000) or 60
    local rec={deadline=S.Time()+math.max(1,duration)};rolls[id]=rec
    Roll(id,rec)
    Timer(math.max(1,duration),function() if rolls[id]==rec then H.CANCEL_LOOT_ROLL(id) end end)
end
H.CANCEL_LOOT_ROLL=function(id) if not S.Number(id) then return end;rolls[id]=nil;waiters['roll:' .. id],budgets['roll:' .. id]=nil,nil;WakeEvent();if ns.ClearRollMark then ns.ClearRollMark(id) end end
H.CONFIRM_LOOT_ROLL=function(id,choice)
    if not S.Number(id) or not S.Number(choice) then return end
    local rec=rolls[id]
    if ns.Char().confirmLootRolls and rec and rec.choice==choice and S.Time()<=rec.deadline and ns.Automating('autoRoll') then
        S.Call('owned roll confirm',ConfirmLootRoll,id,choice);H.CANCEL_LOOT_ROLL(id)
    end
end
