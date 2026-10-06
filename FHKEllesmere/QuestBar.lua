-- RestedXP belongs on Ellesmere's actual Action Bar 8 (slots 169-176).
local EUI, FHK = EllesmereUI, (_G.FHKEllesmereNS or _G.ForeverHunterKeysNS)
if EUI_CLIENT_BLOCKED or not EUI or not FHK then return end
-- Bar 8 slots: 1 RestedXP targeting, 2-8 the guide's active items (RestedXP
-- Follow is not part of this setup). The active item sits on two quick keys.
local SLOT_KEYS = {{'U'}, {'SHIFT-U', 'I'}, {'SHIFT-I'}, {'CTRL-I'}, {'CTRL-U'}, {'ALT-U'}, {'ALT-SHIFT-U'}, {}}
-- Naga 12 sends Alt+I (Interact); Shift+Naga 12 is RestedXP targeting (FHK);
-- Ctrl+Naga 12 (Alt+Ctrl+I) uses the active guide item, the same slot as Shift+U and I.
local NAGA_ITEM_KEY, NAGA_ITEM_BUTTON = 'ALT-CTRL-I', 2
FHK.QuestBarOwnsCtrlNaga = true
local started, pending, hooked, configured, lastSignature, lastError
local elapsed = 0

local function DB()
    if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end
    return FHKEllesmereDB
end
-- RestedXP is read only through FHK's adapter (audit F39).
local function Adapter()
    local fhk = _G.ForeverHunterKeysNS
    return fhk and fhk.RXPAdapter
end
-- Keys and macros on bar 8 are the owner's setup: on by default only alongside
-- ForeverHunterKeys; everyone else turns it on themselves.
local function Enabled()
    local v = DB().questBar
    if v == nil then return (_G.ForeverHunterKeysNS~=nil) end
    return v ~= false
end

local function ConfigureBar()
    local ns = EUI._ModuleNS and EUI._ModuleNS.EllesmereUIActionBars
    local eab = ns and ns.EAB
    local p = eab and eab.db and eab.db.profile
    if not p then return false end
    if configured == p then return true end
    local db = DB()
    if db.questBar8Version ~= 1 then
        p.bars = p.bars or {}; p.bars.Bar8 = p.bars.Bar8 or {}
        local b, source = p.bars.Bar8, p.bars.Bar2 or p.bars.MainBar or {}
        -- Native bar settings provide all icon, cooldown and key-label styling.
        for _, k in ipairs({'buttonWidth', 'buttonHeight', 'buttonPadding', 'borderThickness', 'borderTexture',
            'borderColor', 'buttonShape', 'iconZoom', 'keybindFontSize', 'keybindFontColor',
            'countFontSize', 'countFontColor', 'cooldownFontSize', 'cooldownTextColor'}) do
            if source[k] ~= nil then b[k] = source[k] end
        end
        b.enabled, b.alwaysHidden, b.barVisibility = true, false, 'always'
        b.numIcons, b.numRows, b.orientation = 8, 1, 'horizontal'
        b.overrideNumIcons, b.overrideNumRows = nil, nil
        b.alwaysShowButtons, b.hideMacroText, b.hideKeybind = false, true, false
        b.mouseoverEnabled, b.combatShowEnabled, b.combatHideEnabled = false, false, false
        b.clickThrough, b.bgEnabled, b.foreverBarBg = false, false, false
        b.endCapLeft, b.endCapRight = false, false
        p.barPositions = p.barPositions or {}
        p.barPositions.Bar8 = db.questPosition or {point = 'BOTTOM', relPoint = 'BOTTOM', x = 460, y = 275}
        db.questBar8Version = 1
    end
    if eab.RefreshRuntimeVisibility then eab:RefreshRuntimeVisibility() end
    if ns._eabApplyAll then ns._eabApplyAll() end
    configured = p
    return true
end

local function SlotMacroName(slot)
    local kind, index = GetActionInfo(slot)
    if kind == 'macro' then
        local text = C_ActionBar and C_ActionBar.GetActionText and C_ActionBar.GetActionText(slot)
        return text or GetMacroInfo(index)
    end
end

local function PlaceMacro(slot, index)
    local name = GetMacroInfo(index)
    if SlotMacroName(slot) == name then return end
    PickupMacro(index)
    if select(1, GetCursorInfo()) ~= 'macro' then
        ClearCursor(); error('Cannot pick up quest macro ' .. tostring(name))
    end
    if C_ActionBar and C_ActionBar.PutActionInSlot then C_ActionBar.PutActionInSlot(slot)
    else PlaceAction(slot) end
    ClearCursor()
    if SlotMacroName(slot) ~= name then error('Cannot place quest action in bar 8 slot ' .. slot) end
end

local function ItemMacro(source, i)
    local kind = source:GetAttribute('type1') or source:GetAttribute('type')
    local body, tooltip
    if kind == 'item' then
        tooltip = source:GetAttribute('item')
        if tooltip then body = '/use ' .. tooltip end
    elseif kind == 'spell' then
        tooltip = source:GetAttribute('spell')
        if tooltip then body = '/cast ' .. tooltip end
    elseif kind == 'macro' then
        body = source:GetAttribute('macrotext')
        if not body then
            local index = source:GetAttribute('macro')
            if index then return tonumber(index) or GetMacroIndexByName(index) end
        end
    end
    if not body or body == '' then return end
    body = '#showtooltip' .. (tooltip and ' ' .. tooltip or '') .. '\n' .. body
    if #body > (MAX_MACRO_LENGTH or 255) then error('Guide item macro is too long for a native action slot.') end
    local name = 'FHK_QuestItem' .. i
    local icon = source.icon and source.icon:GetTexture() or 134400
    local index = GetMacroIndexByName(name)
    if index and index > 0 then
        local _, oldIcon, oldBody = GetMacroInfo(index)
        if oldIcon ~= icon or oldBody ~= body then EditMacro(index, name, icon, body) end
    else
        local account, character = GetNumMacros()
        -- Forever keeps the limits in Constants.MacroConsts (API audit 2026-10-06: 120 / 30).
        local consts = Constants and Constants.MacroConsts or {}
        local perCharacter = character < (consts.MAX_CHARACTER_MACROS or MAX_CHARACTER_MACROS or 18)
        if not perCharacter and account >= (consts.MAX_ACCOUNT_MACROS or MAX_ACCOUNT_MACROS or 120) then error('Free a macro slot for the quest action bar.') end
        index = CreateMacro(name, icon, body, perCharacter)
    end
    return index
end

local function Signature()
    local parts = {}
    local A = Adapter()
    for _, b in ipairs(A and A.ItemButtons() or {}) do
        if b:IsShown() then
            parts[#parts + 1] = tostring(b.itemId) .. ':' .. tostring(b:GetAttribute('type1')) .. ':' ..
                tostring(b:GetAttribute('item')) .. ':' .. tostring(b:GetAttribute('spell')) .. ':' ..
                tostring(b:GetAttribute('macrotext')) .. ':' .. tostring(b:GetAttribute('macro'))
        end
    end
    parts[#parts + 1] = tostring(GetMacroIndexByName('RXPTargeting')) .. ':' .. tostring(GetMacroIndexByName('RXPFollow'))
    return table.concat(parts, '|')
end

local function ShowGuidePanel(shown)
    local A = Adapter()
    local frame = A and A.ItemFrame()
    if frame then
        frame:SetAlpha(shown and 1 or 0); frame:EnableMouse(shown)
        for _, b in ipairs(A.ItemButtons()) do b:EnableMouse(shown) end
    end
end
local function HideDuplicatePanels()
    ShowGuidePanel(false)
    for _, name in ipairs({'ForeverHunterKeysRXPPanel', 'FHKEllesmereQuestBar'}) do
        local frame = _G[name]; if frame then frame:Hide() end
    end
end

-- Key ownership (audit F03). A key is claimed once, remembering what it did
-- before. If the player later rebinds a claimed key, it is left alone and
-- reported, never silently reclaimed. Disabling restores what was replaced.
local conflictsReported = {}
local function Claim(key, command, isOurs, bind)
    local db = DB()
    db.questBarKeys = db.questBarKeys or {}
    db.questBarPrevious = db.questBarPrevious or {}
    local current = GetBindingAction(key)
    if isOurs(current) then db.questBarKeys[key] = current; return false end
    -- A key still on another bar-8 button is our own earlier layout: move it.
    local ownBar = current:find('^MULTIACTIONBAR7BUTTON%d$') ~= nil
    if db.questBarKeys[key] and current ~= '' and not ownBar then
        db.questBarConflicts = db.questBarConflicts or {}
        db.questBarConflicts[key] = current
        if not conflictsReported[key] then
            conflictsReported[key] = true
            print(('FHK quest bar 8: %s is now bound to %s, so it was left as you set it.'):format(key, current))
        end
        return false
    end
    if db.questBarPrevious[key] == nil then db.questBarPrevious[key] = current end
    if bind() then
        db.questBarKeys[key] = command
        if db.questBarConflicts then db.questBarConflicts[key] = nil end
        return true
    end
    return false
end

local function Refresh()
    if not Enabled() then return end
    if InCombatLockdown() or GetCursorInfo() then pending = true; return end
    local A = Adapter()
    if not A or not A.Targeting() or not ConfigureBar() then pending = true; return end
    local actions = {GetMacroIndexByName('RXPTargeting')}
    local used = 0
    local buttons = A.ItemButtons()
    for _, b in ipairs(buttons) do
        if b:IsShown() and used < 7 then
            used = used + 1; actions[used + 1] = ItemMacro(b, used)
        end
    end
    local db = DB(); db.questSlotMacros = db.questSlotMacros or {}
    local changed = false
    for i = 1, 8 do
        local index, slot = actions[i], 168 + i
        if index and index > 0 then
            PlaceMacro(slot, index); db.questSlotMacros[i] = GetMacroInfo(index)
        elseif db.questSlotMacros[i] and SlotMacroName(slot) == db.questSlotMacros[i] then
            PickupAction(slot); ClearCursor(); db.questSlotMacros[i] = nil
        end
        local command = 'MULTIACTIONBAR7BUTTON' .. i
        for _, key in ipairs(SLOT_KEYS[i]) do
            if Claim(key, command, function(c) return c == command end,
                function() return SetBinding(key, command) end) then changed = true end
        end
    end
    -- Ctrl+Naga 12 clicks RestedXP's own first active-item button (its own
    -- secure button, so its item/spell/macro choice is used as-is). Before
    -- RestedXP has built that button, fall back to the same item on bar 8.
    local first = buttons[1]
    local firstName = first and first.GetName and first:GetName()
    local itemCommand = 'MULTIACTIONBAR7BUTTON' .. NAGA_ITEM_BUTTON
    local clickCommand = firstName and SetBindingClick and 'CLICK ' .. firstName .. ':LeftButton'
    local function OursNaga(c) return c == itemCommand or c == clickCommand or c:find('^CLICK RXP') ~= nil end
    local bindNaga
    if clickCommand then
        bindNaga = function() return SetBindingClick(NAGA_ITEM_KEY, firstName, 'LeftButton') end
    else bindNaga = function() return SetBinding(NAGA_ITEM_KEY, itemCommand) end end
    local current = GetBindingAction(NAGA_ITEM_KEY)
    if OursNaga(current) and current ~= (clickCommand or itemCommand) then
        if bindNaga() then changed = true; DB().questBarKeys[NAGA_ITEM_KEY] = clickCommand or itemCommand end
    elseif Claim(NAGA_ITEM_KEY, clickCommand or itemCommand, OursNaga, bindNaga) then changed = true end
    if changed then SaveBindings(GetCurrentBindingSet()) end
    if changed and _G._EAB_UpdateKeybinds then _G._EAB_UpdateKeybinds() end
    HideDuplicatePanels()
    if not hooked then
        hooked = A.OnItemFrameUpdate(function()
            pending = true
            if Enabled() then ShowGuidePanel(false) end
        end)
    end
    pending, lastSignature = false, Signature()
end

-- Turning the quest bar off hands everything back: keys it still owns return to
-- what they did before, its macros leave bar 8 and RestedXP's own panel returns.
function FHK.SetEllesmereQuestBarEnabled(on)
    local db = DB()
    -- It creates macros and binds keys: part of the owner's Forever Hunter Keys setup, never a
    -- published install's (publishing rule). Turning it off is always allowed.
    if on and _G.ForeverHunterKeysNS == nil then
        print('FHK: the guide quest bar is part of the Forever Hunter Keys setup; it is not available here.')
        return false
    end
    -- Refused cleanup must retain both the setting and FHK's key ownership.
    if not on then
        if InCombatLockdown() then print('FHK quest bar 8: leave combat to turn it off.'); return false end
        if GetCursorInfo() then print('FHK quest bar 8: finish dragging before turning it off.'); return false end
    end
    db.questBar = on and true or false
    FHK.QuestBarOwnsCtrlNaga = db.questBar
    if on then pending = true; if FHK.SyncEllesmereQuestBarPolling then FHK.SyncEllesmereQuestBarPolling() end; return true end
    local changed = false
    for key, command in pairs(db.questBarKeys or {}) do
        if GetBindingAction(key) == command then
            local previous = db.questBarPrevious and db.questBarPrevious[key]
            if previous and previous ~= '' then SetBinding(key, previous) else SetBinding(key) end
            changed = true
        end
    end
    db.questBarKeys, db.questBarPrevious, db.questBarConflicts = nil, nil, nil
    for i, name in pairs(db.questSlotMacros or {}) do
        local slot = 168 + i
        if SlotMacroName(slot) == name then PickupAction(slot); ClearCursor() end
    end
    db.questSlotMacros = nil
    if changed then SaveBindings(GetCurrentBindingSet()) end
    ShowGuidePanel(true)
    return true
end
function FHK.EllesmereQuestBarStatus()
    local db, lines = DB(), {}
    for key, command in pairs(db.questBarKeys or {}) do lines[#lines + 1] = key .. ' -> ' .. command end
    for key, command in pairs(db.questBarConflicts or {}) do lines[#lines + 1] = key .. ' kept as ' .. command .. ' (you rebound it)' end
    table.sort(lines)
    return lines
end

local function TryRefresh()
    local ok, err = pcall(Refresh)
    if not ok then
        pending = true
        if err ~= lastError then print('FHK quest bar 8: ' .. tostring(err)); lastError = err end
    else lastError = nil end
end

local events = CreateFrame('Frame')
for _, event in ipairs({'PLAYER_ENTERING_WORLD', 'PLAYER_REGEN_ENABLED', 'UPDATE_MACROS', 'BAG_UPDATE_DELAYED'}) do events:RegisterEvent(event) end
-- The half-second poll runs only while the quest bar is on (performance review: it used to
-- tick every frame on installs that never use it).
local function Poll(_, dt)
    if not started or not Enabled() then events:SetScript('OnUpdate', nil); return end
    elapsed = elapsed + dt; if elapsed < 0.5 then return end; elapsed = 0
    if not InCombatLockdown() and Signature() ~= lastSignature then pending = true end
    if pending then TryRefresh() end
end
local function Polling() events:SetScript('OnUpdate', Enabled() and Poll or nil) end
FHK.SyncEllesmereQuestBarPolling = Polling
events:SetScript('OnEvent', function(_, event)
    if event == 'PLAYER_ENTERING_WORLD' then
        FHK.QuestBarOwnsCtrlNaga = Enabled()
        started, pending = true, true; C_Timer.After(2, TryRefresh)
        Polling()
    else pending = true end
end)

SLASH_FHKQUESTBAR1 = '/fhkquestbar'
SlashCmdList.FHKQUESTBAR = function(input)
    local command = tostring(input or ''):lower():match('^%s*(%S*)')
    if command == 'off' or command == 'on' then
        if FHK.SetEllesmereQuestBarEnabled(command == 'on') then
            print('FHK quest bar 8: ' .. (command == 'on' and 'on.' or 'off; your previous keys and the RestedXP panel are back.'))
            if command == 'on' then TryRefresh() end
        end
        return
    end
    TryRefresh()
    print('Quest actions use Action Bar 8. Move/style it in Ellesmere Unlock Mode. U targets; Shift+U, I or Ctrl+Naga 12 use the active guide item.')
    for _, line in ipairs(FHK.EllesmereQuestBarStatus()) do print('  ' .. line) end
    print('  /fhkquestbar off hands the keys and panel back.')
end
