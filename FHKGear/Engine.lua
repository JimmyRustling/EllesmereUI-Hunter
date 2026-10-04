-- FHK Gear: finite scoring with explicit effect assumptions.
-- Adapted from AutoGear; CC BY-NC-SA 4.0. See LICENSE.md.
if EUI_CLIENT_BLOCKED then return end
local _,ns=...
local S,E=ns.Safe,{}
ns.Engine=E
local epsilon=0.000001
local RANGED={INVTYPE_RANGED=true,INVTYPE_THROWN=true,INVTYPE_RANGEDRIGHT=true}
local MELEE={INVTYPE_WEAPON=true,INVTYPE_WEAPONMAINHAND=true,INVTYPE_WEAPONOFFHAND=true,INVTYPE_2HWEAPON=true}
E.RANGED,E.MELEE=RANGED,MELEE
local scores=setmetatable({},{__mode='k'})
local providerSnapshot,providerTime,providerMethod,version,passDepth=nil,-1,nil,-1,0
local equippedCache,equippedVersion,equippedItems
local function Provider(force)
    local api=rawget(_G,'ForeverGearAPI')
    local method=S.Table(api) and api.IsReady
    if not force and (passDepth>0 or S.Time()-providerTime<0.25 and providerMethod==method) then return providerSnapshot end
    providerTime,providerMethod=S.Time(),method
    local c=ns.Char();local class,spec=ns.Weights.ClassSpec()
    local custom=ns.Weights.Custom(class,spec,ns.Weights.Phase())
    local imported=ns.Account().imported and ns.Account().imported[class .. ':' .. spec]
    local hunterModel=ns.HunterModel and ns.HunterModel.Active()
    local chosen=c.source=='forevergear' or c.source=='auto' and not hunterModel and ns.Level()<=20 and not imported and not (custom and next(custom))
    local ready=chosen and ns.AddOnLoaded('ForeverGear') and S.Table(api) and api.apiVersion==1 and type(api.GetUpgradeState)=='function' and S.Yes(S.Read(method,api))
    local nextProvider=ready and api or nil
    if nextProvider~=providerSnapshot then scores=setmetatable({},{__mode='k'});equippedCache=nil end
    providerSnapshot=nextProvider;return providerSnapshot
end
function E.ForeverGearAvailable()
    local api=rawget(_G,'ForeverGearAPI')
    return ns.AddOnLoaded('ForeverGear') and S.Table(api) and api.apiVersion==1 and type(api.GetUpgradeState)=='function' and S.Yes(S.Read(api.IsReady,api))
end
function E.UsesForeverGear() return Provider()~=nil end
local lastPending={}
function E.BeginPass() if passDepth==0 then Provider(true);ns.Items.BeginScope() end;passDepth=passDepth+1 end
function E.EndPass() passDepth=math.max(0,passDepth-1);if passDepth==0 then lastPending=ns.Items.EndScope() end end
function E.PendingIDs()
    local ids,out=passDepth>0 and ns.Items.ScopeIDs() or lastPending,{}
    for id in pairs(ids) do if ns.Items.PendingIDs()[id] then out[id]=true end end
    return out
end
function E.HasPending() return next(E.PendingIDs())~=nil end
function E.InvalidateEquipped() equippedCache=nil;if E.ResetBagRoles then E.ResetBagRoles() end end
function E.Invalidate() scores=setmetatable({},{__mode='k'});version=-1;providerTime=-1;equippedCache=nil;if E.ResetBagRoles then E.ResetBagRoles() end end
function E.StatWeight(w,stat)
    if stat=='RangedAttackPower' then return w.RangedAttackPower or w.AttackPower or 0 end
    if stat:match('Damage$') and stat~='Damage' then return ns.Context.SchoolWeight(stat,w) or 0 end
    if stat=='HastePercent' then return w.HastePercent or 0 end
    return w[stat] or 0
end
function E.ProcRate(info,p,w)
    local c=ns.Char()
    local seconds=S.Number(c.fightLength) and math.max(1,math.min(600,c.fightLength)) or 15
    if p.kind=='use' then
        if not S.Number(p.cooldown) or p.cooldown<=0 then return 0,false,'Use cooldown unknown' end
        local uptime=S.Number(c.useUptime) and math.max(0,math.min(1,c.useUptime)) or 0.8
        return (1+math.floor((seconds-0.001)/p.cooldown))*uptime/seconds,true,'uses per fight'
    end
    local override=c.procRates[info.id]
    local reference=ns.ProcReference.items[info.id]
    local ppm=S.Table(override) and override.ppm or reference and reference.ppm or w.Procs or 1
    local chance=S.Table(override) and override.chance or p.chance
    local icd=S.Table(override) and override.icd or 0
    local share=1
    if MELEE[info.equipLoc] then share=S.Number(c.meleeShare) and math.max(0,math.min(1,c.meleeShare)) or 0.175 end
    local rate,known,note
    if p.kind=='struck' then
        local hits=S.Number(c.incomingHits) and math.max(0,c.incomingHits) or 0
        rate=hits*(S.Number(chance) and chance/100 or 0)
        known=hits==0 or S.Number(chance);note='incoming hits per second x chance'
    elseif S.Number(chance) and chance>=0 and chance<=100 then
        local speed=S.Number(info.speed) and info.speed or nil
        rate=speed and share/speed*chance/100 or 0;known=speed~=nil;note='chance per eligible auto attack; specials not modeled'
    else
        rate=(S.Number(ppm) and math.max(0,math.min(60,ppm)) or 1)/60*share
        -- A default or reference PPM is an estimate. It may drive automation unless the player turns
        -- estimates off (Model page); a player-entered PPM is always known. (Audit status N01.)
        known=S.Table(override) and S.Number(override.ppm) or c.allowEstimates==true
        note=reference and ('sim reference: ' .. reference.note) or 'default PPM estimate'
    end
    if S.Number(icd) and icd>0 then rate=rate/(1+rate*icd) end
    return rate,known,note
end
function E.ProcValue(info,p,w)
    local rate,known,note=E.ProcRate(info,p,w)
    if p.partial then known=false;note='Part of this effect is not modeled' end
    local c=ns.Char();local fight=S.Number(c.fightLength) and math.max(1,c.fightLength) or 15
    local duration=S.Number(p.duration) and math.max(0,p.duration) or 0
    if next(p.stats or {}) and duration==0 then known=false;note='Buff duration unknown' end
    local uptime=math.min(1,math.min(duration,fight)*rate)
    local damage=p.damage or 0
    if duration>fight and (p.tick or p.totalOverTime) then damage=damage*fight/duration end
    local direct=w.DirectDPS or w.RangedDPS or w.MeleeDPS or w.DPS or 0
    local value=damage*rate*direct+(p.heal or 0)*rate*5*(w.Hp5 or 0)+(p.mana or 0)*rate*5*(w.Mp5 or 0)
    for stat,amount in pairs(p.stats or (p.stat and {[p.stat]=p.amount} or {})) do value=value+amount*uptime*E.StatWeight(w,stat) end
    if not S.Number(value) then return 0,false,'Invalid effect value' end
    return value,known,note
end
function E.Score(info,slot)
    if not info then return 0,true end
    if info.missing then return nil,false,'Item data pending' end
    if version~=ns.Weights.version then scores=setmetatable({},{__mode='k'});version=ns.Weights.version end
    local provider=Provider()
    local record=scores[info]
    local cached=record and record[slot or 0]
    if cached then return cached.value,cached.known,cached.reason end
    local score,known,reason=0,true,nil
    if provider then
        local _,value=S.Read(provider.GetUpgradeState,provider,info.link)
        if not S.Number(value) then return nil,false,'ForeverGear score unavailable' end
        score=value
    elseif ns.Char().source=='forevergear' then return nil,false,'ForeverGear is not ready'
    else
        local w=ns.Weights.Current() or {}
        for stat,value in pairs(info.stats or {}) do
            if not S.Number(value) then return nil,false,'Invalid ' .. tostring(stat) end
            local weight
            -- The Hunter model prices weapon damage itself (speed, ammo, skill): skip the flat DPS weight.
            if stat=='DPS' and w.scale and (RANGED[info.equipLoc] or MELEE[info.equipLoc]) then weight=0
            elseif stat=='DPS' then weight=RANGED[info.equipLoc] and (w.RangedDPS or w.DPS) or MELEE[info.equipLoc] and (w.MeleeDPS or w.DPS) or w.DPS
            else weight=E.StatWeight(w,stat) end
            if weight~=nil and not S.Number(weight) then return nil,false,'Invalid weight' end
            local factor=stat=='DPS' and ns.Char().comparisonModel=='rotation' and slot==17 and MELEE[info.equipLoc] and 0.5 or 1
            score=score+(weight or 0)*value*factor
        end
        for _,p in ipairs(info.procs or {}) do local v,k,n=E.ProcValue(info,p,w);score=score+v;if not k then known=false;reason=n end end
        for _,effect in ipairs(info.conditional or {}) do
            if ns.Char().targetType==effect.creature then score=score+effect.amount*E.StatWeight(w,effect.stat) end
        end
        for _,amount in pairs(info.skills or {}) do score=score+amount*(w.WeaponSkill or 0) end
        if w.scale and ns.HunterModel and (RANGED[info.equipLoc] or MELEE[info.equipLoc]) then
            local value,k,why=ns.HunterModel.WeaponValue(info,slot,w)
            score=score+(S.Number(value) and value or 0)
            if not k then known=false;reason=why or 'Weapon skill unread' end
        elseif slot then
            local value,k=ns.Context.WeaponValue(info,slot,w)
            if value==nil then return nil,false,'Ability weapon requirement' end
            score=score+value;known=known and k
        end
    end
    if #(info.unknown or {})>0 then known=false;reason=info.unknown[1] end
    if #(info.unparsed or {})>0 then known=false;reason='Unscored tooltip effect' end
    if not S.Number(score) then return nil,false,'Non-finite score' end
    if score==0 then score=epsilon end
    record=record or {};record[slot or 0]={value=score,known=known,reason=reason};scores[info]=record
    return score,known,reason
end
function E.AutomationSafe(info)
    local score,known=E.Score(info)
    local w=ns.Weights.Current() or {}
    return S.Number(score) and known and #(info.unparsed or {})==0 and not (info.skills and (w.WeaponSkill or 0)==0)
end
function E.Equipped(fresh)
    Provider()
    if not fresh and equippedCache and equippedVersion==ns.Weights.version and equippedItems==ns.Items.version then return equippedCache end
    local out,complete={},true
    for _,slot in ipairs(E.EQUIP_SLOTS) do
        local link=S.Read(GetInventoryItemLink,'player',E.Inventory and E.Inventory(slot) or slot)
        local info=S.Text(link) and ns.Items.Read(link) or nil
        local score=info and E.Score(info,slot) or 0
        if link and (not info or info.missing or not S.Number(score)) then complete=false end
        out[slot]={info=info,score=score,link=S.Text(link) and link or nil}
        if info and slot>=16 and slot<=18 and C_Item and type(C_Item.GetWeaponEnchantInfo)=='function' then
            local enchants=S.Read(C_Item.GetWeaponEnchantInfo,slot==16 and 0 or slot==17 and 1 or 2)
            for _,enchant in ipairs(S.Table(enchants) and enchants or {}) do
                if S.Table(enchant) and S.Plain(enchant.hasEnchant) and enchant.hasEnchant==true and S.Number(enchant.enchantType) and enchant.enchantType~=1 then
                    out[slot].temporaryEnchant=true
                end
            end
        end
    end
    if complete then equippedCache,equippedVersion,equippedItems=out,ns.Weights.version,ns.Items.version end
    return out
end
