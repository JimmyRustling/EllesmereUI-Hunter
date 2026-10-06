-- FHK Gear: reads an item once and caches it. Stats come from C_Item.GetItemStats (structured, cheap);
-- the tooltip is read only for what that table can't say: whether the player can use the item (red
-- text, e.g. an untrained weapon type or a level requirement), its binding, and "Equip:" lines that
-- are missing from the stat table. AutoGear re-reads every tooltip on every scan; this reads each
-- item once until the player's level or skills change.
-- Adapted from AutoGear (CC BY-NC-SA 4.0); this file is CC BY-NC-SA 4.0. See LICENSE.md.
if EUI_CLIENT_BLOCKED then return end
local _, ns = ...
local Items = {}
ns.Items = Items
local cache, pending, requests = {}, {}, {}
local readScope
function Items.BeginScope() readScope={} end
function Items.ScopeIDs() return readScope or {} end
function Items.EndScope() local ids=readScope or {};readScope=nil;return ids end
Items.cache = cache
Items.CACHE_LIMIT = 256
Items.version = 0
local nodes, oldest, newest, count = {}, nil, nil, 0

local function Touch(key)
    local node = nodes[key]
    if node and node == newest then return end
    if node then
        if node.before then node.before.after = node.after else oldest = node.after end
        if node.after then node.after.before = node.before end
    else
        node = {key = key}
        nodes[key] = node
        count = count + 1
    end
    node.before, node.after = newest, nil
    if newest then newest.after = node else oldest = node end
    newest = node
    while count > Items.CACHE_LIMIT do
        local keyToDrop = oldest.key
        oldest = oldest.after
        if oldest then oldest.before = nil else newest = nil end
        cache[keyToDrop], nodes[keyToDrop] = nil, nil
        count = count - 1
    end
end

local S, F = ns.Safe, ns.Effects
local Plain, Try = S.Plain, S.Read

-- Stat and amount an Equip: line gives, or nil.
local function EquipLine(lower)
    local stats = F.Static(lower)
    if stats then return next(stats) end
end
Items.EquipLine = EquipLine

-- Procs and Use: effects (FHK Gear's own model). Each line becomes the facts the engine needs to
-- price it with the current weights: kind (chance / struck / use), damage per proc, heal, mana,
-- a temporary stat with its duration, and the cooldown. No weights here, so the item cache stays valid.
function Items.AddProc(info, lower)
    local p = F.Proc(lower)
    if not p then return false end
    info.procs = info.procs or {}
    info.procs[#info.procs + 1] = p
    return true
end

local function IsRed(c)
    if not S.Table(c) then return false, c == nil end
    local r, g, b = c.r, c.g, c.b
    if type(c.GetRGB) == 'function' then r, g, b = Try(c.GetRGB,c) end
    if not (S.Number(r) and S.Number(g) and S.Number(b)) then return false, false end
    return r > 0.5 and r > g * 3 and r > b * 3, true
end
Items.IsRed = IsRed

-- Tooltip lines as {left, right, leftRed, rightRed}: C_TooltipInfo when present, else a hidden tooltip.
local scanner
local function Lines(link, bag, slot)
    local info = C_TooltipInfo
    local data
    if info then
        if bag and slot then data = Try(info.GetBagItem, bag, slot) end
        if not data then data = Try(info.GetHyperlink, link) end
    end
    local out = {}
    if S.Table(data) and S.Table(data.lines) then
        local complete = #data.lines > 0
        for i, line in ipairs(data.lines) do
            if not S.Table(line) then complete = false; break end
            local lr,lc = IsRed(line.leftColor)
            local rr,rc = IsRed(line.rightColor)
            if not Plain(line.leftText) or not Plain(line.rightText) or not lc or not rc then complete = false end
            out[i] = {S.Text(line.leftText) and line.leftText or nil, S.Text(line.rightText) and line.rightText or nil,lr,rr,S.Number(line.type) and line.type or nil}
        end
        return out, complete and S.Text(out[1] and out[1][1])
    end
    if not CreateFrame then return out end
    if not scanner then
        scanner = Try(CreateFrame,'GameTooltip', 'FHKGearScanTooltip', nil, 'GameTooltipTemplate')
    end
    if not scanner or not S.Call('scanner owner',scanner.SetOwner,scanner,WorldFrame,'ANCHOR_NONE') then return out,false end
    local ok
    if bag and slot and scanner.SetBagItem then ok=S.Call('scanner bag',scanner.SetBagItem,scanner,bag,slot) else ok=S.Call('scanner link',scanner.SetHyperlink,scanner,link) end
    local n=Try(scanner.NumLines,scanner)
    if not ok or not S.Number(n) or n<1 or n>100 then return out,false end
    local complete=true
    for i = 1, n do
        local left, right = _G['FHKGearScanTooltipTextLeft' .. i], _G['FHKGearScanTooltipTextRight' .. i]
        local function Read(fs)
            if not fs or Try(fs.IsShown,fs)~=true then return nil,false,true end
            local r,g,b=Try(fs.GetTextColor,fs)
            local text=Try(fs.GetText,fs)
            local red,known=IsRed({r=r,g=g,b=b})
            return S.Text(text) and text or nil,red,known and (text==nil or S.Text(text))
        end
        local lt, lr,lc = Read(left)
        local rt, rr,rc = Read(right)
        complete=complete and lc and rc
        out[i] = {lt, rt, lr, rr}
    end
    S.Call('scanner hide',scanner.Hide,scanner)
    return out,complete and S.Text(out[1] and out[1][1])
end
Items.Lines = Lines

local function Request(id)
    if not S.Number(id) then return end
    for requested,record in pairs(requests) do
        if S.Time()-record.time>15 then requests[requested],pending[requested]=nil,nil end
    end
    local t, rec = S.Time(), requests[id]
    if not rec then
        local size = 0; for _ in pairs(requests) do size = size + 1 end
        if size >= 128 then S.Note('item-requests','Item request limit reached'); return end
        rec = {tries=0,time=t}; requests[id] = rec
    end
    if t - rec.time > 15 or rec.tries >= 3 then pending[id] = nil; return end
    pending[id] = true
    if readScope then readScope[id]=true end
    if not rec.last or t - rec.last >= 1 then
        rec.tries,rec.last = rec.tries + 1,t
        Try(C_Item and C_Item.RequestLoadItemDataByID,id)
    end
end
Items.Request = Request
function Items.PendingIDs() return pending end
function Items.HasPending() return next(pending) ~= nil end
function Items.ClearPending() for k in pairs(pending) do pending[k] = nil end end
function Items.Arrived(id, success)
    if not S.Number(id) or not pending[id] then return false end
    pending[id] = nil
    if S.Yes(success) then requests[id] = nil end
    for key,info in pairs(cache) do if info.id == id then cache[key] = nil end end
    -- A missing record is never cached, so targeted wake-up does not flush unrelated facts.
    Items.version = Items.version + 1
    return true
end
function Items.InvalidateRequirements(all)
    local changed=false
    for key,info in pairs(cache) do
        if not info.usable and (all or info.skillRequirement) then cache[key]=nil;changed=true end
    end
    if changed then Items.version=Items.version+1 end
    return changed
end
function Items.Invalidate()
    for k in pairs(cache) do cache[k] = nil end
    nodes, oldest, newest, count = {}, nil, nil, 0
    requests = {}
    Items.ClearPending()
    Items.version = Items.version + 1
end

-- Item model, or nil for a non-item. info.missing = the client hasn't loaded it yet (asked; retry later).
function Items.Read(link, bag, slot)
    if not S.Text(link) then return nil end
    -- Bound state is per bag slot, everything else per link.
    local key = bag and slot and (bag .. ':' .. slot .. ':' .. link) or link
    local hit = cache[key]
    if hit then
        if bag ~= nil and slot ~= nil then
            local location = Try(C_Container and C_Container.GetContainerItemInfo,bag,slot)
            if S.Table(location) and Plain(location.isBound) then
                hit.bound = location.isBound == true and 'bound' or hit.bindType == 2 and 'boe' or hit.tooltipBound
            end
        end
        Touch(key); return hit
    end
    local id, _, _, equipLoc, _, classID, subclassID = Try(_G.GetItemInfoInstant or C_Item and C_Item.GetItemInfoInstant, link)
    if not S.Number(id) then
        id = tonumber(link:match('item:(%d+)'))
        if id then Request(id); return {link=link,id=id,missing=true,reason='Item identity pending'} end
        return nil
    end
    local get = C_Item and C_Item.GetItemInfo or _G.GetItemInfo
    local name, _, quality, itemLevel, reqLevel, _, _, _, _, _, price, _, _, bindType, _, setID = Try(get, link)
    local info = {link = link, id = id, equipLoc = S.Text(equipLoc) and equipLoc or '', classID = S.Number(classID) and classID or nil, subclassID = S.Number(subclassID) and subclassID or nil,
        name = S.Text(name) and name or nil, quality = S.Number(quality) and quality or nil,
        itemLevel = S.Number(itemLevel) and itemLevel or 0, reqLevel = S.Number(reqLevel) and reqLevel or nil,
        price = S.Number(price) and price or nil,bindType=S.Number(bindType) and bindType or nil,setID=S.Number(setID) and setID>0 and setID or nil,
        bag=bag,bagSlot=slot,stats = {}, usable = true, lineStats = {}, unparsed = {},unknown = {},rawRatings={}}
    if not info.name or not info.quality or not info.reqLevel or not info.price or not S.Text(equipLoc) then
        info.missing = true
        Request(id)
        return info -- not cached: read again once the data arrives
    end
    local fromStats, lineTotals, seenLines, enchantTotals = {},{},{},{}
    info.enchantID=tonumber(link:match('item:%d+:(%d+)')) or 0
    local raw = C_Item and C_Item.GetItemStats and Try(C_Item.GetItemStats, link) or Try(_G.GetItemStats, link)
    local rawReady = S.Table(raw)
    if rawReady then
        for k, v in pairs(raw) do
            local stat = S.Text(k) and ns.Weights.ITEM_MOD[k]
            if stat and S.Number(v) then
                if k:find('RATING',1,true) and stat ~= 'Defense' and stat ~= 'BlockValue' then
                    info.rawRatings[stat] = math.max(info.rawRatings[stat] or 0,v)
                elseif stat == 'Resistance' then info.stats[stat] = (info.stats[stat] or 0) + v; fromStats[stat] = true
                else info.stats[stat] = info.stats[stat] and math.max(info.stats[stat],v) or v; fromStats[stat] = true end
            elseif stat then info.unknown[#info.unknown + 1] = 'Restricted or invalid ' .. stat end
        end
    end
    if (equipLoc or '') ~= '' then
        local lines, ready = Lines(link,bag,slot)
        -- Once the tooltip is complete the item is loaded; a nil stat table then means "no
        -- structured stats" (e.g. a Use-only trinket), not "still loading" (audit status N04).
        if ready and not rawReady and raw == nil then raw, rawReady = {}, true end
        if not ready or not rawReady then info.missing=true; info.reason='Tooltip or stats pending'; Request(id); return info end
        local canUse = Try(C_PlayerInfo and C_PlayerInfo.CanUseItem,id)
        if Plain(canUse) and canUse == false then info.usable=false;info.reason='Client requirements not met' end
        local otherBlock = false
        for i, line in ipairs(lines) do
            local left, right = line[1], line[2]
            if i > 1 and (line[3] or line[4]) and not (type(left) == 'string' and left:find('Durability', 1, true)) then
                info.usable = false
                info.reason = (line[3] and left) or right
                -- "Requires Level 30" in red is a block that ends at that level (review G11); anything else stays one.
                local text = line[3] and left or right
                local n = S.Text(text) and tonumber(text:lower():match('level%s+(%d+)'))
                if not (n and info.reqLevel and n == info.reqLevel) then otherBlock = true end
            end
            if type(left) == 'string' then
                if left == ITEM_SOULBOUND or left == ITEM_BIND_ON_PICKUP then info.bound = 'bop'
                elseif left == ITEM_BIND_ON_EQUIP then info.bound = 'boe' end
                if left == ITEM_UNIQUE or left == ITEM_UNIQUE_EQUIPPABLE then info.unique = true end
                local lower = left:lower()
                if lower:find('requires',1,true) and lower:match('%(%d+%)') then info.skillRequirement=true end
                local enchantLine=line[5]==15 or lower:find('enchanted:',1,true)
                local minDamage,maxDamage = lower:match('(%d+%.?%d*)%s*%-%s*(%d+%.?%d*)%s+damage')
                if minDamage and S.Number(tonumber(minDamage)) and S.Number(tonumber(maxDamage)) then info.damageMin,info.damageMax = tonumber(minDamage),tonumber(maxDamage); info.stats.Damage=(info.damageMin+info.damageMax)/2 end
                local speed = (S.Text(right) and right:lower() or lower):match('speed%s+(%d+%.?%d*)')
                if speed then info.speed = tonumber(speed) end
                local capacity = lower:match('(%d+)%s+slot')
                if capacity then info.capacity = tonumber(capacity) end
                local haste = lower:match('ranged attack speed by (%d+%.?%d*)%%')
                if haste then info.quiverHaste=tonumber(haste) end
                local category,limit = left:match('Unique%-Equipped:%s*(.-)%s*%((%d+)%)')
                if category then info.uniqueCategory,info.uniqueLimit=category,tonumber(limit) end
                local threshold = lower:match('%((%d+)%)%s*set:') or lower:match('^(%d+)%s*set:')
                local proc = (lower:find('chance on', 1, true) or lower:find('use:', 1, true) or lower:find('when struck', 1, true))
                if enchantLine then
                    local facts=F.Enchant(left)
                    if facts then for stat,value in pairs(facts) do enchantTotals[stat]=(enchantTotals[stat] or 0)+value end
                    else info.unknown[#info.unknown+1]='Enchant not modeled: ' .. left end
                elseif threshold or lower:find('set:',1,true) then
                    local effect = proc and F.Proc(lower) or F.Static(lower)
                    info.setEffects=info.setEffects or {}
                    info.setEffects[#info.setEffects+1]={threshold=tonumber(threshold),effect=effect,text=left}
                    if not info.setID or not threshold or not effect then info.unparsed[#info.unparsed+1]=left end
                elseif proc then
                    if not Items.AddProc(info, lower) then info.unparsed[#info.unparsed + 1] = left end
                elseif lower:find('equip:', 1, true) and not seenLines[lower] then
                    seenLines[lower]=true
                    -- Forever lists crit/hit as separate Equip: lines; remember which stats came from them,
                    -- and keep lines no rule understood so /fhkgear item can show them.
                    local skill,n = F.Skill(lower)
                    local conditional = F.Conditional(lower)
                    local facts = F.Static(lower)
                    if skill then info.skills=info.skills or {};info.skills[skill]=n
                    elseif conditional then info.conditional=info.conditional or {};info.conditional[#info.conditional+1]=conditional;info.unparsed[#info.unparsed+1]=left
                    elseif facts then for stat,v in pairs(facts) do lineTotals[stat]=(lineTotals[stat] or 0)+v end
                    else info.unparsed[#info.unparsed+1]=left end
                end
            end
        end
        if info.enchantID>0 then
            if not next(enchantTotals) then info.unknown[#info.unknown+1]='Enchant effect/rate unknown (ID ' .. info.enchantID .. ')'
            else
                local baseLink=link:gsub('(item:%d+:)%d+', '%10',1)
                local baseRaw=Try(C_Item and C_Item.GetItemStats or _G.GetItemStats,baseLink)
                local base={}
                for key,value in pairs(S.Table(baseRaw) and baseRaw or {}) do
                    local stat=ns.Weights.ITEM_MOD[key]
                    if stat and S.Number(value) then base[stat]=math.max(base[stat] or 0,value) end
                end
                for stat,value in pairs(enchantTotals) do
                    local difference=(info.stats[stat] or 0)-(base[stat] or 0)
                    if stat=='Damage' then info.unknown[#info.unknown+1]='Weapon damage enchant normalization unknown'
                    elseif not S.Table(baseRaw) or difference>0 and difference<value then info.unknown[#info.unknown+1]='Enchant stat reconciliation unknown: ' .. stat
                    elseif difference<=0 then info.stats[stat]=(info.stats[stat] or 0)+value end
                end
            end
        end
        info.enchantStats=enchantTotals
        info.levelOnly = not info.usable and not otherBlock and (info.reqLevel or 0) > ns.Level() or nil
        for stat,v in pairs(lineTotals) do
            if not fromStats[stat] or info.rawRatings[stat] then info.stats[stat]=v;info.lineStats[stat]=true end
        end
        -- Explicit spell-power wording resolves equivalent structured damage aliases.
        if lineTotals.SpellPower and fromStats.SpellDamage and not fromStats.SpellPower then
            info.stats.SpellPower=math.max(lineTotals.SpellPower,info.stats.SpellDamage or 0)
            info.stats.SpellDamage=lineTotals.SpellDamage
            info.lineStats.SpellPower=true
        elseif fromStats.SpellPower and fromStats.SpellDamage then
            info.stats.SpellDamage=math.max(0,(info.stats.SpellDamage or 0)-(info.stats.SpellPower or 0))
        end
        for stat,v in pairs(info.rawRatings) do
            if not lineTotals[stat] then
                local units=ns.Char().ratingUnits
                local conversion=ns.Char().ratingConversions and ns.Char().ratingConversions[stat]
                if units=='percent' then info.stats[stat]=v
                elseif units=='rating' and S.Number(conversion) and conversion>0 then info.stats[stat]=v/conversion
                else info.unknown[#info.unknown+1]='Unconfirmed rating units: ' .. stat end
            end
        end
        local category,limit = Try(C_Item and C_Item.GetItemUniqueness,link)
        if S.Number(category) and category > 0 and S.Number(limit) and limit > 0 then
            info.uniqueCategory='category:' .. category;info.uniqueLimit=limit
        end
        info.tooltipBound=info.bound
        if info.bindType==2 and not info.bound then info.bound='boe' end
        if bag~=nil and slot~=nil then
            local location=Try(C_Container and C_Container.GetContainerItemInfo,bag,slot)
            if S.Table(location) and Plain(location.isBound) and location.isBound==true then info.bound='bound' end
        end
    end
    pending[id] = nil
    cache[key] = info
    Touch(key)
    return info
end

