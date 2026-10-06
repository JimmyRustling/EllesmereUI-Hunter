-- Learned-talent checks for talent-driven Hunter features. Shared with the optional Hunter addon.
-- Ranks are read when talents change (never per frame): first from the talent window's own API,
-- matched by the talent's localized name, else from "is the talent's spell known". A rank that
-- cannot be read is nil, and callers keep their talent-free default instead of guessing.
if EUI_CLIENT_BLOCKED then return end
local _, NS = ...
NS = _G.FHKEllesmereNS or NS
if NS.HunterTalents then return end
local Talents = {}
NS.HunterTalents = Talents

-- Forever Hunter talents that change what we show (spell IDs: ForeverDB talent calculator,
-- client build 1.60.1.70205). Features read these through Has/Rank; see FOREVER_HUNTER_COVERAGE_PLAN.md section 0.
Talents.list = {
    loneWolf = 415370,            -- +20 % damage without a pet: no missing-pet nagging
    focusedFire = 1223755,        -- +2 % damage while the pet is out
    summonHawk = 1293241,         -- hawk slots and timers
    sniperShot = 1310687,         -- next 3 shots +10 yd: widen the range indicator
    rapidKilling = 415405,        -- kill -> next Shot +20 %: proc cue
    exposePrey = 1310532,         -- Hunter's Mark attacks can enable Mongoose Bite
    improvedTracking = 24293,     -- +5 % damage to the tracked creature type: tracking cue
    deadlyAspects = 19552,        -- Hawk / Beast attack-speed procs
    trueshotAura = 1299346,       -- party aura: missing-aura reminder
    bestialWrath = 19574,
    intimidation = 19577,
    hawkEye = 19498,              -- longer ranged range
    improvedStings = 1310661,
    carefulAim = 1223984,
    rapidRecuperation = 1223987,
    scatterShot = 19503,
    predatorsEdge = 1310627,
    counterattack = 19306,
    resourcefulness = 440529,
    survivalistsDiscipline = 1310496,
    striderKick = 1317257,
    laceratingStrikes = 1310533,
    readiness = 23989,
}

local ranks, methods, listeners = {}, {}, {}
local queued, driver = false, nil
local function Plain(v) return not (issecretvalue and issecretvalue(v)) end
local function Read(fn, ...)
    if type(fn) ~= 'function' then return end
    local ok, a, b, c, d, e, f = pcall(fn, ...)
    if ok and Plain(a) then return a, b, c, d, e, f end
end
local function SpellName(id)
    local name = C_Spell and Read(C_Spell.GetSpellName, id)
    if type(name) ~= 'string' then name = Read(_G.GetSpellInfo, id) end
    return type(name) == 'string' and name or nil
end
local function Known(id)
    local book = C_SpellBook and C_SpellBook.IsSpellKnown
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    -- Passive talents are not in the spellbook (review AP5): any API saying known counts.
    local a, b, c = Read(book, id, bank), Read(_G.IsPlayerSpell, id), Read(_G.IsSpellKnown, id)
    if a == true or b == true or c == true then return true end
    if a == false or b == false or c == false then return false end
end

-- name -> {rank, maxRank} from whichever talent API the client offers.
local function TalentWindow()
    local byName, any = {}, false
    local count = _G.GetNumTalents
    local info = C_SpecializationInfo and C_SpecializationInfo.GetTalentInfo
    for tab = 1, 5 do
        local n = Read(count, tab)
        if type(n) ~= 'number' or n <= 0 then break end
        for i = 1, n do
            local name, rank, maxRank
            local t = info and Read(info, {specializationIndex = tab, talentIndex = i, tier = 1, column = 1})
            if type(t) == 'table' then name, rank, maxRank = t.name, t.rank, t.maxRank end
            if type(name) ~= 'string' then
                local legacyName, _, _, _, legacyRank, legacyMax = Read(_G.GetTalentInfo, tab, i)
                name, rank, maxRank = legacyName, legacyRank, legacyMax
            end
            if Plain(name) and type(name) == 'string' and Plain(rank) and type(rank) == 'number' then
                byName[name] = {rank = rank, maxRank = maxRank}
                any = true
            end
        end
    end
    return any and byName or nil
end

-- Forever talents are a Traits tree (API audit 2026-10-06: the Classic talent-tab API is missing,
-- so every talent read as rank 1 by its known spell). name -> {rank, maxRank} from the active
-- config; nil when the client has no Traits config (other flavours, or before login).
local function Traits()
    local CT, T = C_ClassTalents, C_Traits
    if not (CT and T) then return nil end
    local config = Read(CT.GetActiveConfigID)
    if type(config) ~= 'number' then return nil end
    local info = Read(T.GetConfigInfo, config)
    if type(info) ~= 'table' or type(info.treeIDs) ~= 'table' then return nil end
    local byName, any = {}, false
    for _, tree in ipairs(info.treeIDs) do
        local nodes = Read(T.GetTreeNodes, tree)
        for _, nodeID in ipairs(type(nodes) == 'table' and nodes or {}) do
            local node = Read(T.GetNodeInfo, config, nodeID)
            if type(node) == 'table' and type(node.entryIDs) == 'table' then
                local active = type(node.activeEntry) == 'table' and node.activeEntry.entryID
                for _, entryID in ipairs(node.entryIDs) do
                    local entry = Read(T.GetEntryInfo, config, entryID)
                    local def = type(entry) == 'table' and entry.definitionID and Read(T.GetDefinitionInfo, entry.definitionID)
                    local name = type(def) == 'table' and type(def.spellID) == 'number' and SpellName(def.spellID)
                    if name then
                        -- A choice node ranks only its chosen entry.
                        local rank = (active == nil or active == entryID) and node.activeRank or 0
                        if type(rank) == 'number' and Plain(rank) then
                            byName[name] = {rank = rank, maxRank = entry.maxRanks, source = 'talent tree'}
                            any = true
                        end
                    end
                end
            end
        end
    end
    return any and byName or nil
end

local function Refresh()
    queued = false
    local window = Traits() or TalentWindow()
    for key, id in pairs(Talents.list) do
        local name, rank, method = SpellName(id), nil, nil
        local row = window and name and window[name]
        if row then rank, method = row.rank, row.source or 'talent window'
        else
            -- A known talent spell proves at least one rank; an unreadable answer stays nil.
            local known = Known(id)
            if known == true then rank, method = 1, 'spell known'
            elseif known == false then rank, method = 0, 'spell not known' end
        end
        ranks[key], methods[key] = rank, method
    end
    for _, fn in ipairs(listeners) do pcall(fn) end
end
local function Queue()
    if queued then return end
    queued = true
    if C_Timer and C_Timer.After then C_Timer.After(0, Refresh) else Refresh() end
end

-- Rank learned (0 = not learned), or nil when the client would not say.
function Talents.Rank(key)
    if ranks[key] == nil and not queued and next(ranks) == nil then Refresh() end
    return ranks[key]
end
function Talents.Has(key) return (Talents.Rank(key) or 0) > 0 end
function Talents.Method(key) return methods[key] end
-- Called (protected) after every talent change, once per burst of events.
function Talents.OnChange(fn) if type(fn) == 'function' then listeners[#listeners + 1] = fn end end
Talents.Refresh = Refresh

if select(2, UnitClass('player')) == 'HUNTER' then
    driver = CreateFrame('Frame')
    for _, event in ipairs({'PLAYER_LOGIN', 'SPELLS_CHANGED', 'CHARACTER_POINTS_CHANGED', 'PLAYER_TALENT_UPDATE', 'TRAIT_CONFIG_UPDATED',
        'ACTIVE_TALENT_GROUP_CHANGED', 'PLAYER_LEVEL_UP'}) do
        pcall(driver.RegisterEvent, driver, event)
    end
    driver:SetScript('OnEvent', Queue)
end

SLASH_FHKTALENTS1 = '/fhktalents'
SlashCmdList.FHKTALENTS = function()
    Refresh()
    local keys = {}
    for key in pairs(Talents.list) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local rank = ranks[key]
        print(('FHK talents: %s (%d) = %s via %s'):format(key, Talents.list[key],
            rank == nil and 'unknown' or tostring(rank), methods[key] or 'no readable source'))
    end
end

-- /fhkprobe: one-shot read of the Forever client facts the coverage plan needs (plan section 7).
-- Prints a summary and saves every answer to FHKEllesmereDB.probe (per character), which the game
-- writes to disk on /reload or logout. For 5 minutes afterwards it also notes combat-log sub-events
-- and whether choosing Feed Pet's food counts as spell targeting. Nothing runs until typed.
local function Show(v)
    if not Plain(v) then return '<secret>' end
    if type(v) == 'table' then
        local parts, n = {}, 0
        for k, x in pairs(v) do
            n = n + 1
            if n > 12 then parts[#parts + 1] = '...'; break end
            parts[#parts + 1] = tostring(k) .. '=' .. (Plain(x) and tostring(x) or '<secret>')
        end
        return '{' .. table.concat(parts, ', ') .. '}'
    end
    return tostring(v)
end
local function Joined(ok, ...)
    if not ok then return 'error: ' .. tostring((...)) end
    local parts = {}
    for i = 1, select('#', ...) do parts[i] = Show((select(i, ...))) end
    return #parts > 0 and table.concat(parts, ' | ') or 'no returns'
end
local function Call(fn, ...)
    if type(fn) ~= 'function' then return 'missing' end
    return Joined(pcall(fn, ...))
end
local function SpellByName(name)
    local info = C_Spell and Read(C_Spell.GetSpellInfo, name)
    if type(info) == 'table' and info.spellID then return info.spellID end
    local _, _, _, _, _, _, id = Read(_G.GetSpellInfo, name)
    return id
end

local function ProbeRows()
    local rows = {}
    local function Add(key, value) rows[#rows + 1] = key .. ' = ' .. value end
    local P, M, S = C_PetInfo or {}, C_Minimap or {}, C_SpecializationInfo or {}
    Add('build', Call(_G.GetBuildInfo))
    Add('player', Call(_G.UnitClass, 'player') .. ' | level ' .. Call(_G.UnitLevel, 'player'))
    Add('issecretvalue', type(_G.issecretvalue))
    -- talents and top ranks (plan 7.1, 7.8)
    Add('loneWolf IsPlayerSpell(415370)', Call(_G.IsPlayerSpell, 415370))
    Add('GetNumTalents(1/2/3)', Call(_G.GetNumTalents, 1) .. ' / ' .. Call(_G.GetNumTalents, 2) .. ' / ' .. Call(_G.GetNumTalents, 3))
    -- Forever's GetTalentInfo wants query.tier (probe 2026-10-04); try the tier/column shapes too.
    Add('C_SpecializationInfo.GetTalentInfo{tier=1,column=1}', Call(S.GetTalentInfo, {tier = 1, column = 1}))
    Add('C_SpecializationInfo.GetTalentInfo{spec=1,tier=1,column=1}', Call(S.GetTalentInfo, {specializationIndex = 1, tier = 1, column = 1}))
    Add('C_SpecializationInfo.GetNumSpecializations', Call(S.GetNumSpecializations))
    Add('C_ClassTalents / C_Traits', type(_G.C_ClassTalents) .. ' / ' .. type(_G.C_Traits))
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or _G.IsAddOnLoaded
    for _, ui in ipairs({'Blizzard_TalentUI', 'Blizzard_PlayerSpells', 'Blizzard_ClassTalentUI'}) do
        Add('talent UI ' .. ui .. ' loaded', Call(loaded, ui))
    end
    Add('GetTalentInfo(1,1)', Call(_G.GetTalentInfo, 1, 1))
    Add('GetTalentTabInfo(1)', Call(_G.GetTalentTabInfo, 1))
    Add('C_SpecializationInfo.GetSpecialization', Call(S.GetSpecialization))
    local describe = C_Spell and C_Spell.GetSpellDescription or _G.GetSpellDescription
    for _, name in ipairs({'Aspect of the Hawk', "Hunter's Mark", 'Trueshot Aura', 'Aspect of the Beast',
        'Aspect of the Monkey', 'Aspect of the Cheetah', 'Feed Pet', 'Tame Beast'}) do
        local id = SpellByName(name)
        Add('spell ' .. name, id and (tostring(id) .. ' | ' .. Call(describe, id)) or 'not known by name')
    end
    -- pet (plan 7.2, 7.7)
    Add('pet UnitExists / UnitIsDead / HasPetUI', Call(_G.UnitExists, 'pet') .. ' / ' .. Call(_G.UnitIsDead, 'pet') .. ' / ' .. Call(_G.HasPetUI))
    Add('GetPetExperience', Call(_G.GetPetExperience))
    Add('C_PetInfo.GetPetLoyalty', Call(P.GetPetLoyalty))
    Add('C_PetInfo.GetPetTrainingPoints', Call(P.GetPetTrainingPoints))
    Add('C_PetInfo.GetPetHappiness', Call(P.GetPetHappiness))
    Add('C_PetInfo.GetPetTalentTree', Call(P.GetPetTalentTree))
    Add('C_PetInfo.GetPetFoodTypes', Call(P.GetPetFoodTypes))
    Add('legacy GetPetHappiness / GetPetLoyalty', Call(_G.GetPetHappiness) .. ' / ' .. Call(_G.GetPetLoyalty))
    -- pet bar autocast flags and the passive token (plan 7.6)
    Add('PET_MODE_PASSIVE', Show(_G.PET_MODE_PASSIVE))
    for i = 1, (_G.NUM_PET_ACTION_SLOTS or 10) do
        if Read(_G.GetPetActionInfo, i) then
            Add('petbar ' .. i, Call(_G.GetPetActionInfo, i) .. ' | passive ' .. Call(P.IsPetActionPassive, i))
        end
    end
    -- tracking API (plan 7.4)
    for _, fn in ipairs({'GetNumTrackingTypes', 'GetTrackingInfo', 'GetTrackingFilter', 'IsFilteredOut', 'SetTracking'}) do
        Add('C_Minimap.' .. fn, type(M[fn]))
    end
    for _, fn in ipairs({'GetTrackingTexture', 'GetNumTrackingTypes', 'GetTrackingInfo', 'SetTracking'}) do
        Add('global ' .. fn, type(_G[fn]))
    end
    local count = Read(M.GetNumTrackingTypes)
    if type(count) ~= 'number' then count = Read(_G.GetNumTrackingTypes) end
    if type(count) == 'number' then
        for i = 1, math.min(count, 20) do Add('tracking ' .. i, Call(M.GetTrackingInfo or _G.GetTrackingInfo, i)) end
    end
    Add('GetTrackingTexture', Call(_G.GetTrackingTexture))
    -- combat log and Feed Pet targeting (plan 7.3, 7.5; also watched, below)
    Add('CombatLogGetCurrentEventInfo', type(_G.CombatLogGetCurrentEventInfo))
    Add('C_CombatLog', Show(_G.C_CombatLog and (function() local k = {}; for name in pairs(C_CombatLog) do k[#k + 1] = name end; table.sort(k); return k end)()))
    Add('SpellIsTargeting now', Call(_G.SpellIsTargeting))
    -- item and character stats for the gear engine (plan 7.8)
    local link = Read(_G.GetInventoryItemLink, 'player', 18)
    if not link then link = Read(_G.GetInventoryItemLink, 'player', 16) end
    Add('ranged / main-hand link', Show(link))
    if link then
        Add('C_Item.GetItemStats', Call(C_Item and C_Item.GetItemStats, link))
        Add('GetItemStats', Call(_G.GetItemStats, link))
    end
    Add('crit melee / ranged', Call(_G.GetCritChance) .. ' / ' .. Call(_G.GetRangedCritChance))
    Add('GetHitModifier', Call(_G.GetHitModifier))
    return rows
end

local watch = {subEvents = {}, targeting = {}, fires = 0}
local watcher
local watchEpoch = 0
local lastBlock
local blockDriver = CreateFrame('Frame')
blockDriver:RegisterEvent('ADDON_ACTION_BLOCKED')
blockDriver:RegisterEvent('ADDON_ACTION_FORBIDDEN')
blockDriver:SetScript('OnEvent', function(_, event, owner, action)
    if not Plain(owner) or not Plain(action) then return end
    if owner ~= 'FHKEllesmere' and owner ~= 'ForeverHunterKeys' and owner ~= 'FHKGear' then return end
    local trace = Read(_G.debugstack, 2, 12, 12)
    lastBlock = {event = event, owner = owner, action = type(action) == 'string' and action or 'unknown',
        trace = type(trace) == 'string' and trace or 'No stack available'}
    if type(FHKEllesmereDB) == 'table' then rawset(FHKEllesmereDB, 'lastBlockedAction', lastBlock) end
    print('FHK: ' .. owner .. ' blocked ' .. lastBlock.action .. '. /fhkprobe blocked copies the report.')
end)
local function Watch()
    watch.untilTime = GetTime() + 300
    watchEpoch = watchEpoch + 1
    local token = watchEpoch
    if C_Timer and C_Timer.After then C_Timer.After(300, function()
        if token ~= watchEpoch or not watcher then return end
        watcher:UnregisterAllEvents(); watcher:SetScript('OnEvent', nil); watcher = nil
    end) end
    if watcher then return end
    watcher = CreateFrame('Frame')
    pcall(watcher.RegisterEvent, watcher, 'CURRENT_SPELL_CAST_CHANGED')
    local reader = _G.C_CombatLog and C_CombatLog.GetCurrentEventInfo or _G.CombatLogGetCurrentEventInfo
    local restricted = Read(_G.C_CombatLog and C_CombatLog.IsCombatLogRestricted)
    if type(reader) ~= 'function' then watch.combatLog = 'unavailable: no public reader'
    elseif restricted == true then watch.combatLog = 'restricted by client'
    elseif restricted ~= false then watch.combatLog = 'unavailable: restriction state unknown'
    else watch.combatLog = pcall(watcher.RegisterEvent, watcher, 'COMBAT_LOG_EVENT_UNFILTERED') and 'registered' or 'refused' end
    watcher:SetScript('OnEvent', function(self, event)
        if GetTime() > watch.untilTime then self:UnregisterAllEvents(); self:SetScript('OnEvent', nil); watcher = nil; return end
        if event == 'COMBAT_LOG_EVENT_UNFILTERED' then
            watch.fires = watch.fires + 1
            local reader = _G.C_CombatLog and C_CombatLog.GetCurrentEventInfo or _G.CombatLogGetCurrentEventInfo
            local _, sub = Read(reader)
            if type(sub) == 'string' then
                if not watch.firstPayload then watch.firstPayload = Call(reader) end
                watch.subEvents[sub] = (watch.subEvents[sub] or 0) + 1
            end
        elseif Read(_G.SpellIsTargeting) == true and #watch.targeting < 10 then
            watch.targeting[#watch.targeting + 1] = ('SpellIsTargeting true at %.1f'):format(GetTime())
        end
    end)
end

-- Copy window: every answer in a selectable box, so results can be pasted instead of screenshotted.
local copyFrame
local function CopyText(rows)
    local lines = {('FHK probe %s'):format(date and date('%Y-%m-%d %H:%M:%S') or '')}
    for _, row in ipairs(rows) do lines[#lines + 1] = row end
    lines[#lines + 1] = ('combat log %s, %d events'):format(tostring(watch.combatLog), watch.fires)
    lines[#lines + 1] = 'combat log first payload = ' .. tostring(watch.firstPayload)
    for sub, n in pairs(watch.subEvents) do lines[#lines + 1] = ('combat log %s = %d'):format(sub, n) end
    lines[#lines + 1] = ('Feed Pet targeting samples = %d'):format(#watch.targeting)
    for _, sample in ipairs(watch.targeting) do lines[#lines + 1] = sample end
    return table.concat(lines, '\n')
end
local function ShowCopy(text)
    if not copyFrame then
        local f = CreateFrame('Frame', 'FHKProbeCopyFrame', UIParent)
        f:SetSize(620, 420); f:SetPoint('CENTER'); f:SetFrameStrata('DIALOG')
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag('LeftButton')
        f:SetScript('OnDragStart', f.StartMoving); f:SetScript('OnDragStop', f.StopMovingOrSizing)
        local bg = f:CreateTexture(nil, 'BACKGROUND'); bg:SetAllPoints(); bg:SetColorTexture(0.05, 0.05, 0.06, 0.95)
        local line = f:CreateTexture(nil, 'BORDER'); line:SetPoint('TOPLEFT'); line:SetPoint('TOPRIGHT'); line:SetHeight(1)
        line:SetColorTexture(0.85, 0.65, 0.13, 1)
        local title = f:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
        title:SetPoint('TOPLEFT', 12, -10); title:SetText('FHK probe  -  Ctrl+C copies, Esc closes')
        local close = CreateFrame('Button', nil, f, 'UIPanelCloseButton'); close:SetPoint('TOPRIGHT', 2, 2)
        local scroll = CreateFrame('ScrollFrame', nil, f, 'UIPanelScrollFrameTemplate')
        scroll:SetPoint('TOPLEFT', 12, -34); scroll:SetPoint('BOTTOMRIGHT', -32, 12)
        local box = CreateFrame('EditBox', nil, scroll)
        box:SetMultiLine(true); box:SetAutoFocus(false); box:SetFontObject(ChatFontNormal); box:SetWidth(570)
        box:SetScript('OnEscapePressed', function() f:Hide() end)
        -- Read-only: typing restores the text, so a stray key can't spoil the copy.
        box:SetScript('OnTextChanged', function(self, user) if user then self:SetText(f.text or ''); self:HighlightText() end end)
        scroll:SetScrollChild(box)
        f.box = box
        tinsert(UISpecialFrames, 'FHKProbeCopyFrame')
        copyFrame = f
    end
    copyFrame.text = text
    copyFrame.box:SetText(text)
    copyFrame:Show()
    copyFrame.box:SetFocus()
    copyFrame.box:HighlightText()
end

SLASH_FHKPROBE1 = '/fhkprobe'
SlashCmdList.FHKPROBE = function(msg)
    if type(msg) == 'string' and msg:lower():match('^%s*blocked%s*$') then
        local b = lastBlock or type(FHKEllesmereDB) == 'table' and rawget(FHKEllesmereDB, 'lastBlockedAction')
        local text = type(b) == 'table' and ('FHK blocked action\n' .. tostring(b.event) .. '\nAddon: ' .. tostring(b.owner) ..
            '\nAction: ' .. tostring(b.action) .. '\n' .. tostring(b.trace)) or 'FHK: no owned-addon block recorded since this patch loaded.'
        print(text)
        pcall(ShowCopy, text)
        return
    end
    local rows = ProbeRows()
    Watch()
    local kinds = 0
    for _ in pairs(watch.subEvents) do kinds = kinds + 1 end
    local shown, why = pcall(ShowCopy, CopyText(rows))
    local db = _G.FHKEllesmereDB
    if type(db) == 'table' then
        rawset(db, 'probe', {time = date and date('%Y-%m-%d %H:%M:%S') or '', rows = rows, combatLog = watch.combatLog,
            combatLogFires = watch.fires, combatLogSubEvents = watch.subEvents, combatLogFirstPayload = watch.firstPayload, feedPetTargeting = watch.targeting})
    end
    -- The full list goes to chat only on request (/fhkprobe all); the saved copy always has it.
    if type(msg) == 'string' and msg:lower():find('all', 1, true) then
        for _, row in ipairs(rows) do print('|cffd9a521FHK probe|r ' .. row:sub(1, 180)) end
    end
    print(('|cffd9a521FHK probe|r %d answers; combat log %s (%d events, %d sub-event types); Feed Pet targeting samples %d. %s'):format(
        #rows, tostring(watch.combatLog), watch.fires, kinds, #watch.targeting,
        shown and 'Copy window open (Ctrl+C).' or ('Copy window failed: ' .. tostring(why))))
    print('|cffd9a521FHK probe|r ' .. (type(db) == 'table'
        and 'Saved. Next 5 min: cast Feed Pet then cancel it, type /fhkprobe again. After a Blizzard block: /fhkprobe blocked.'
        or 'Not saved: FHKEllesmereDB is missing.'))
end
