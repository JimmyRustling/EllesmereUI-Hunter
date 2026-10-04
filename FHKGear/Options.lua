-- FHK Gear: its own "Gear" section in the Ellesmere sidebar (EllesmereUI.RegisterPlugin), built only
-- with Ellesmere's widgets. With the local core patch's options-extension API, the QoL page also
-- gets one row that opens it. CC BY-NC-SA 4.0 (part of FHK Gear). See LICENSE.md.
if EUI_CLIENT_BLOCKED then return end
local ADDON, ns = ...
local EUI = _G.EllesmereUI
local S=ns.Safe
if not (EUI and EUI.RegisterPlugin) then return end

local function C() return ns.Char() end
function ns.InvalidateOptions()
    local key=EUI.GetPluginModuleKey and EUI.GetPluginModuleKey(ADDON,'gear')
    if key and EUI.InvalidateModulePageCache then S.Call('Gear page cache',EUI.InvalidateModulePageCache,EUI,key) end
end
local function Active()
    local key = EUI.GetPluginModuleKey and EUI.GetPluginModuleKey(ADDON, 'gear')
    return key and EUI.GetActiveModule and EUI:GetActiveModule() == key and EUI.RefreshPage
end
-- Hard rebuild: rows appear or disappear (lists, optional sections, labels that show state).
local function Rebuild(change)
    if change ~= false then ns.Changed() end
    if Active() then EUI:RefreshPage(true) end
end
local RefreshPreview
-- Soft apply: the same rows, new values. Ellesmere re-evaluates every disabled() and value in place,
-- so a slider drag or swatch pick never tears the page down.
-- A slider drag or swatch pick fires many times a second: the preview follows at once, and the full
-- change (rescoring, profile write, event set) runs once, 0.15 s after the last tick.
local softQueued=nil -- time queued; expires so a lost timer never blocks settings
local function Settle()
    softQueued=nil
    ns.Changed()
    if ns.RefreshMarkers then ns.RefreshMarkers() end
end
local function Apply(soft)
    if RefreshPreview then RefreshPreview() end
    if soft then
        if not (softQueued and S.Time()-softQueued<1) then
            softQueued=S.Time()
            if not S.Call('settings timer',C_Timer and C_Timer.After,0.15,Settle) then Settle() end
        end
        return
    end
    Settle()
    if Active() then EUI:RefreshPage() end
end
-- Ellesmere calls cfg.disabled() as a function: every gate below is a function, never a boolean.
local function Needs(...)
    local keys={...}
    return function() local c=C();for i=1,#keys do if not c[keys[i]] then return true end end;return false end
end
local function Toggle(text, key, tooltip, off, offTip)
    return {type = 'toggle', text = text, tooltip = tooltip, disabled = off, disabledTooltip = off and offTip or nil,
        getValue = function() return C()[key] == true end,
        setValue = function(v) C()[key] = v and true or false; Apply() end}
end
-- A toggle whose change alters the status line or which rows exist: rebuild the page.
local function HardToggle(text, key, tooltip)
    local cfg = Toggle(text, key, tooltip)
    cfg.setValue = function(v) C()[key] = v and true or false; Rebuild() end
    return cfg
end
local function Slider(text,key,min,max,step,tooltip,percent,off,offTip)
    return {type='slider',text=text,tooltip=tooltip,min=min,max=max,step=step,disabled=off,disabledTooltip=off and offTip or nil,
        getValue=function() local v=C()[key];if not S.Number(v) then v=ns.CHAR_DEFAULTS[key] end;return percent and math.floor(v*100+0.5) or v end,
        setValue=function(v)
            if not S.Number(v) then return end
            v=math.max(min,math.min(max,v))
            C()[key]=percent and v/100 or v;Apply(true)
        end}
end
local function Drop(text,key,values,order,tooltip,off,offTip)
    return {type='dropdown',text=text,values=values,order=order,tooltip=tooltip,disabled=off,disabledTooltip=off and offTip or nil,
        getValue=function() return C()[key] end,
        setValue=function(v) if values[v] then C()[key]=v;if key=='ratingUnits' then ns.Items.Invalidate() end;Apply() end end}
end

local function Header(W, parent, text, y)
    local _, h = W:SectionHeader(parent, text, y)
    return y - h
end
local function Row(W, parent, y, left, right)
    local row, h = W:DualRow(parent, y, left, right or EUI.BlankRowCfg())
    return y - h, row
end
local function Spacer(W, parent, y)
    if not W.Spacer then return y end
    local _, h = W:Spacer(parent, y, 20)
    return y - (h or 20)
end
-- Inline extras exist only on real rows (never in the search pre-build or older Ellesmere builds).
local function Inline(row, side)
    if EUI._prebuilding or (EUI.IsSearchPrebuild and EUI.IsSearchPrebuild()) then return nil end
    return row and row[side == 'left' and '_leftRegion' or '_rightRegion']
end

-- Blizzard's own quality colours (ITEM_QUALITY_COLORS); the fallbacks are the same hex values.
local RARITIES = {}
local rarityNames = {'Poor (Grey)', 'Common (White)', 'Uncommon (Green)', 'Rare (Blue)', 'Epic (Purple)', 'Legendary (Orange)'}
local rarityColours = {'9d9d9d', 'ffffff', '1eff00', '0070dd', 'a335ee', 'ff8000'}
local RARITY_ORDER = {0, 1, 2, 3, 4, 5}
for quality = 0, 5 do
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    local hex = c and type(c.hex) == 'string' and c.hex or ('|cff' .. rarityColours[quality + 1])
    RARITIES[quality] = hex .. rarityNames[quality + 1] .. '|r'
end

-- One line that says what Gear will do right now, in the state's own colour (green acting, gold marks only).
local function StatusText()
    local c = C()
    local acting = {}
    if c.autoEquip then acting[#acting + 1] = 'equips upgrades' end
    if c.autoQuest then acting[#acting + 1] = 'picks quest rewards' end
    if c.autoRoll then acting[#acting + 1] = 'rolls on loot' end
    if ns.AutoGearActive() then return '|cffffc733Marks only: AutoGear is enabled|r' end
    if #acting == 0 then return '|cffffc733Marks only: every automatic action is off|r' end
    if ns.LevellingCapped() then return ('|cffffc733Marks only: level %d (Levelling Mode)|r'):format(ns.MAX_LEVEL) end
    return '|cff40ff59Active: ' .. table.concat(acting, ', ') .. '|r'
end

local function AutomationPage(W, parent, y)
    local equipOff = Needs('autoEquip')
    y = Row(W, parent, y, {type = 'label', text = StatusText()})
    y = Header(W, parent, 'AUTOMATIC ACTIONS', y)
    y = Row(W, parent, y,
        HardToggle('Auto-Equip Upgrades', 'autoEquip', 'Equips better gear from your bags out of combat. Off: upgrades are only marked.'),
        HardToggle('Auto-Pick Quest Rewards', 'autoQuest', 'Takes the best upgrade, or the highest vendor value when nothing is an upgrade. Choices that include non-gear items stay yours.'))
    y = Row(W, parent, y,
        HardToggle('Auto-Roll on Loot', 'autoRoll', 'Need on upgrades you may Need on, Greed on everything else.'),
        HardToggle('Levelling Mode', 'levellingOnly', 'Automatic actions run only at levels 1-59. From level 60 Gear only marks, and stops listening to bag and loot events.'))
    y = Row(W, parent, y,
        {type = 'dropdown', text = 'Auto-Equip Up To', values = RARITIES, order = RARITY_ORDER,
            tooltip = 'Automatic equipping includes this rarity and below. Higher rarities are still marked as upgrades.',
            disabled = equipOff, disabledTooltip = 'Auto-Equip Upgrades',
            getValue = function() return C().autoEquipMaxQuality end,
            setValue = function(v)
                if type(v) == 'number' and RARITIES[v] then C().autoEquipMaxQuality = v; Apply() end
            end},
        Toggle('Auto-Equip Empty Bag Upgrades','autoBags','Allows empty bag and suitable quiver upgrades. Occupied bags remain manual.',equipOff,'Auto-Equip Upgrades'))
    y = Row(W, parent, y,
        Toggle('Auto-Equip Better Ammo','autoAmmo','Puts the best usable arrows or bullets for your ranged weapon in the ammo slot, including a higher tier the moment you reach its level.',equipOff,'Auto-Equip Upgrades'))
    y = Spacer(W, parent, y)
    y = Header(W, parent, 'POP-UPS', y)
    local popOff = function() local c = C(); return not (c.popActions or c.popFound) end
    y = Row(W, parent, y,
        Toggle('Action Pop-Ups', 'popActions', 'A card when Gear equips an item, picks a quest reward or rolls on loot.'),
        Toggle('Upgrade Found Pop-Ups', 'popFound', 'A card with Equip and Never Equip when an upgrade lands in your bags that Gear leaves to you.'))
    y = Row(W, parent, y,
        Slider('Pop-Up Duration', 'popDuration', 3, 30, 1, 'Seconds a card stays; hovering keeps it.', false, popOff, 'Action Pop-Ups or Upgrade Found Pop-Ups'),
        {type = 'labeledButton', text = 'Pop-Up Preview', buttonText = 'Show', tooltip = 'Shows two sample cards. Move them in Ellesmere Unlock Mode (Gear Pop-Ups).',
            disabled = popOff, disabledTooltip = 'Action Pop-Ups or Upgrade Found Pop-Ups',
            onClick = function() if ns.Notify then ns.Notify.Preview() end end})
    y = Spacer(W, parent, y)
    y = Header(W, parent, 'BIND ON EQUIP', y)
    y = Row(W, parent, y,
        Toggle('Auto-Equip Bind-on-Equip', 'equipBoE', 'Lets auto-equip use bind-on-equip items up to your Auto-Equip rarity. Off: they stay in your bags, marked.', equipOff, 'Auto-Equip Upgrades'),
        Toggle('Auto-Confirm Bind Prompt', 'confirmEquipBinds', 'Accepts the bind prompt, but only for the item Gear is equipping. Off: the prompt waits for you.', Needs('autoEquip','equipBoE'), 'Auto-Equip Bind-on-Equip'))
    y = Spacer(W, parent, y)
    local rollOff = Needs('autoRoll')
    y=Header(W,parent,'LOOT ROLLS',y)
    y=Row(W,parent,y,Toggle('Need on Upgrades','rollNeedUpgrades','Auto-Roll chooses Need only for supported upgrades. Off: upgrades remain a manual choice.',rollOff,'Auto-Roll on Loot'),
        Toggle('Greed on Other Loot','rollGreedOthers','Auto-Roll chooses Greed only when the roll permits it. Off: other loot remains a manual choice.',rollOff,'Auto-Roll on Loot'))
    y=Row(W,parent,y,Toggle('Auto-Confirm Roll Prompt','confirmLootRolls','Accepts the bind prompt only for a Need or Greed roll Gear made. Off: confirm it yourself.',rollOff,'Auto-Roll on Loot'),
        Toggle('Chat Messages', 'chat', 'One line in chat for each automatic action.'))
    if ns.AutoGearActive() then
        y = Spacer(W, parent, y)
        y = Header(W, parent, 'AUTOGEAR', y)
        y = Row(W, parent, y, {type = 'labeledButton', text = 'AutoGear is enabled, so Gear only marks', buttonText = 'Disable AutoGear',
            tooltip = 'Turns AutoGear off for this character and reloads. Its imported weights were copied to Gear.',
            onClick = function()
                EUI:ShowConfirmPopup({title = 'Disable AutoGear', message = 'Gear replaces AutoGear. Disable AutoGear and reload?',
                    confirmText = 'Disable and Reload', cancelText = 'Cancel', reload = true,
                    onConfirm = function()
                        local disable = C_AddOns and C_AddOns.DisableAddOn or _G.DisableAddOn
                        local guid=S.Read(UnitGUID,'player')
                        if not S.Text(guid) then ns.Say('Could not identify this character. Disable AutoGear in AddOns.',true);return end
                        S.Call('disable AutoGear',disable,'AutoGear',guid)
                    end})
            end})
    end
    return y
end

local PHASES = {auto = 'By Level', levelling = 'Levelling', endgame = 'Endgame'}
local function Sources()
    local values, order = {auto = 'Automatic', weights = 'Stat Weights'}, {'auto', 'weights'}
    if ns.HunterModel and ns.HunterModel.Available() then values.hunter = 'Hunter Model (Live Stats)'; table.insert(order, 2, 'hunter') end
    if ns.Engine.ForeverGearAvailable() then
        values.forevergear = 'ForeverGear'
        order[#order + 1] = 'forevergear'
    elseif C().source=='forevergear' then
        values.unavailable='Unavailable (Manual)';order[#order+1]='unavailable'
    end
    return values, order
end
local function WeightsPage(W, parent, y)
    local _, class = UnitClass('player')
    local specs, order = {}, {''}
    specs[''] = 'Detected (' .. ns.Weights.DetectedSpec(class) .. ')'
    for _, spec in ipairs(ns.Weights.Specs(class)) do specs[spec] = spec; order[#order + 1] = spec end
    y = Header(W, parent, 'WEIGHTS IN USE', y)
    y = Row(W, parent, y,
        {type = 'dropdown', text = 'Spec', values = specs, order = order,
            getValue = function() return C().spec or '' end,
            setValue = function(v) C().spec = v ~= '' and v or nil; Rebuild() end},
        {type = 'dropdown', text = 'Phase', values = PHASES, order = {'auto', 'levelling', 'endgame'},
            tooltip = 'By Level: Levelling weights below the level on the right, Endgame from it.',
            getValue = function() return C().phase end, setValue = function(v) C().phase = v; Rebuild() end})
    local sources, sourceOrder = Sources()
    y = Row(W, parent, y,
        {type = 'dropdown', text = 'Score Source', values = sources, order = sourceOrder,
            disabledValues={unavailable=true},
            tooltip = 'Automatic: the Hunter model for Hunters; otherwise ForeverGear at levels 1-20 when installed, then stat weights.',
            getValue = function() return sources[C().source] and C().source or C().source=='forevergear' and 'unavailable' or 'weights' end,
            setValue = function(v) if sources[v] and v~='unavailable' then C().source = v; Rebuild() end end},
        {type = 'slider', text = 'Endgame From Level', min = 10, max = 60, step = 1,
            tooltip = 'With Phase set to By Level, Endgame weights apply from this level.',
            disabled = function() return C().phase ~= 'auto' end, disabledTooltip = 'Phase: By Level',
            getValue = function() return C().phaseLevel end,
            setValue = function(v) if S.Number(v) then C().phaseLevel = v; Apply(true) end end})
    local spec = select(2, ns.Weights.ClassSpec())
    local phase = ns.Weights.Phase()
    local weightTitle = ns.Engine.UsesForeverGear() and 'FALLBACK STAT WEIGHTS' or 'STAT WEIGHTS'
    y = Spacer(W, parent, y)
    y = Header(W, parent, ('%s: %s, %s'):format(weightTitle, spec:upper(), phase:upper()), y)
    local current = ns.Weights.Current() or {}
    if current.scale then
        y = Row(W, parent, y, {type = 'label', text = '|cff40ff59Hunter model in use:|r these weights follow your live stats. Typing a weight switches this spec and phase to your own numbers.'})
    end
    local function Input(stat)
        if not stat then return nil end
        return {type = 'input', text = ns.Weights.LABELS[stat] or stat, inputWidth = 70,
            getValue = function() return ('%.3g'):format(current[stat] or 0) end,
            setValue = function(text)
                local v = tonumber(text)
                if not S.Number(v) or v < 0 or v>100000 then ns.Say('Enter a finite weight from 0 to 100000.',true);return end
                ns.Weights.Custom(class, spec, phase, true)[stat] = v
                Rebuild()
            end}
    end
    local stats = ns.Weights.STATS
    for i = 1, #stats, 2 do y = Row(W, parent, y, Input(stats[i]), Input(stats[i + 1])) end
    y = Row(W, parent, y,
        {type = 'labeledButton', text = 'Weight Scale', buttonText = 'Import',
            tooltip = 'Paste a Pawn scale or stat=value pairs. They become your weights for this spec and phase.',
            onClick = function()
                EUI:ShowInputPopup({title = 'Import Weights', message = 'Paste a Pawn scale or stat=value pairs.',
                    placeholder = '( Pawn: v1: "Hunter: Beast Mastery": Agility=1, ... )', confirmText = 'Import',
                    onConfirm = function(text)
                        local parsed, why = ns.Weights.Parse(text)
                        if not parsed then ns.Say(why,true); return end
                        local custom = ns.Weights.Custom(class, spec, phase, true)
                        for k in pairs(custom) do custom[k] = nil end
                        for k, v in pairs(parsed) do custom[k] = v end
                        ns.Say(('Imported weights for %s (%s).'):format(spec, phase))
                        Rebuild()
                    end})
            end},
        {type = 'labeledButton', text = 'Share These Weights', buttonText = 'Export',
            tooltip = 'Copies these weights in the lossless FHK Gear format.',
            onClick = function()
                EUI:ShowCopyPopup('Export Weights', 'Lossless FHK Gear format. Supports zeroes and separate spell damage.', ns.Weights.Export(current, ('%s: %s'):format(class, spec)))
            end})
    y = Row(W, parent, y, {type = 'labeledButton', text = 'Your Changes for This Spec and Phase', buttonText = 'Reset',
        tooltip = 'Returns this spec and phase to the built-in weights.',
        onClick = function()
            local custom = ns.Weights.Custom(class, spec, phase)
            if custom then for k in pairs(custom) do custom[k] = nil end end
            Rebuild()
        end})
    if ns.AddOnLoaded('Pawn') then
        y=Row(W,parent,y,{type='labeledButton',text='Pawn Compatibility',buttonText='Export Pawn',onClick=function()
            local text,warning=ns.Weights.ExportPawn(current,class .. ' ' .. spec);EUI:ShowCopyPopup('Export Pawn',warning,text)
        end})
    end
    if ns.MythicSimAvailable() then
        y = Spacer(W, parent, y)
        y = Header(W, parent, 'MYTHICSIM', y)
        y = Row(W, parent, y,
            {type = 'labeledButton', text = 'MythicSim Character', buttonText = 'Export Character',
                tooltip = 'Opens the installed MythicSim exporter with your character, talents and gear.',
                onClick = function() ns.OpenMythicSim() end},
            {type = 'labeledButton', text = 'MythicSim Website', buttonText = 'Copy Link',
                onClick = function() EUI:ShowCopyPopup('MythicSim', 'Paste your character export on this page.', 'https://mythicsim.com/wow-forever/sim') end})
    end
    return y
end

local DEFAULT_COLOURS = {upgrade = {0.25, 1, 0.35}, greed = {1, 0.78, 0.2}}
local function Swatch(key, tooltip)
    return {tooltip = tooltip, hasAlpha = false,
        getValue = function() local colour = C().markerColours[key] or DEFAULT_COLOURS[key]; return colour[1], colour[2], colour[3], 1 end,
        setValue = function(r, g, b) if S.Number(r) and S.Number(g) and S.Number(b) then C().markerColours[key] = {r, g, b}; Apply(true) end end}
end
local function MarkersPage(W, parent, y)
    y = Header(W, parent, 'MARKERS', y)
    y = Row(W, parent, y,
        Toggle('Tooltip Score', 'tooltip', 'One line on gear tooltips: the upgrade amount, or the score when it is not an upgrade.'),
        Toggle('Quest Reward Borders', 'markQuest', 'Upgrade colour on the best reward; greed colour on the highest vendor value when nothing is an upgrade.'))
    y=Row(W,parent,y,Toggle('Bag Upgrade Icons','markBags','Marks upgrades in Blizzard and Ellesmere bags, including above your automatic rarity limit.'),
        Toggle('Loot Roll Marks','markRoll','Upgrade colour for a supported upgrade; greed colour for other loot.'))
    y=Row(W,parent,y,Toggle('Character Slot Marks','markCharacter','Marks character sheet slots that have an upgrade in your bags.'))
    y = Spacer(W, parent, y)
    local off = function() local c = C(); return not (c.markQuest or c.markBags or c.markRoll or c.markCharacter) end
    local offTip = 'A marker above'
    y = Header(W, parent, 'APPEARANCE', y)
    local styleRow
    y, styleRow = Row(W,parent,y,
        Drop('Upgrade Marker Style','markerStyle',{border='Native Border',arrow='Upgrade Arrow',diamond='Diamond',plus='Plus'},{'border','arrow','diamond','plus'},
            'How an upgrade is marked. The swatch sets its colour; the cog places icon styles on the slot.',off,offTip),
        Drop('Greed Marker Style','greedMarkerStyle',{border='Native Border',coin='Gold Coin',diamond='Diamond',plus='Plus'},{'border','coin','diamond','plus'},
            'How greed loot and the best vendor reward are marked. The swatch sets its colour.',off,offTip))
    local left, right = Inline(styleRow, 'left'), Inline(styleRow, 'right')
    if left and EUI.BuildInlineSwatches then
        S.Call('upgrade swatch', EUI.BuildInlineSwatches, left, {Swatch('upgrade', 'Upgrade Colour')}, {disabled = off, disabledTooltip = offTip})
    end
    if left and EUI.BuildInlineCog then
        S.Call('marker cog', EUI.BuildInlineCog, left, {title = 'Icon Placement', disabled = off, disabledTooltip = offTip,
            rows = {
                {type = 'dropdown', label = 'Icon Position', values = {TOPLEFT='Top Left',TOPRIGHT='Top Right',BOTTOMLEFT='Bottom Left',BOTTOMRIGHT='Bottom Right',CENTER='Centre'},
                    order = {'TOPLEFT','TOPRIGHT','BOTTOMLEFT','BOTTOMRIGHT','CENTER'},
                    get = function() return C().markerPosition end, set = function(v) C().markerPosition = v; Apply(true) end},
                {type = 'slider', label = 'X Offset', min = -32, max = 32, step = 1,
                    get = function() return C().markerOffsetX end, set = function(v) C().markerOffsetX = v; Apply(true) end},
                {type = 'slider', label = 'Y Offset', min = -32, max = 32, step = 1,
                    get = function() return C().markerOffsetY end, set = function(v) C().markerOffsetY = v; Apply(true) end},
            }})
    end
    if right and EUI.BuildInlineSwatches then
        S.Call('greed swatch', EUI.BuildInlineSwatches, right, {Swatch('greed', 'Greed and Vendor Colour')}, {disabled = off, disabledTooltip = offTip})
    end
    y=Row(W,parent,y,Slider('Icon Size','markerSize',8,48,1,'Size of icon markers; the native border scales with it.',false,off,offTip),
        Slider('Marker Opacity','markerOpacity',10,100,5,'Opacity of every Gear marker.',true,off,offTip))
    y=Row(W,parent,y,{type='labeledButton',text='Marker Appearance',buttonText='Reset',tooltip='Returns marker styles, colours, size, opacity and placement to their defaults.',
        onClick=function()
            local c=C();c.markerColours={};for _,key in ipairs({'markerStyle','greedMarkerStyle','markerSize','markerOpacity','markerPosition','markerOffsetX','markerOffsetY'}) do c[key]=ns.CHAR_DEFAULTS[key] end;Rebuild()
        end})
    return y
end

-- Live preview above the Markers page: one upgrade and one greed sample, painted by the real marker code.
local preview = {}
RefreshPreview = function()
    if not (preview.upgrade and ns.PaintSample) then return end
    S.Call('preview upgrade', ns.PaintSample, preview.upgrade, false)
    S.Call('preview greed', ns.PaintSample, preview.greed, true)
end
local function Sample(header, icon, text, x)
    local button = CreateFrame('Frame', nil, header)
    button:SetSize(37, 37)
    button:SetPoint('TOPLEFT', header, 'TOP', x, -14)
    local texture = button:CreateTexture(nil, 'ARTWORK')
    texture:SetAllPoints()
    texture:SetTexture(icon)
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- Ellesmere's own options font when available, like its preview hints.
    local label = EUI.MakeFont and EUI.MakeFont(button, 11, nil, 1, 1, 1) or button:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    label:SetPoint('TOP', button, 'BOTTOM', 0, -4)
    label:SetText(text)
    return button
end
local function MarkersHeader(header, width)
    if not preview.upgrade or preview.parent ~= header then
        preview.parent = header
        preview.upgrade = Sample(header, 'Interface\\Icons\\INV_Weapon_Bow_07', 'Upgrade', -80)
        preview.greed = Sample(header, 'Interface\\Icons\\INV_Chest_Leather_09', 'Greed / Vendor', 43)
    end
    RefreshPreview()
    return 76
end

local function EquipmentRulesPage(W, parent, y)
    local labels = {[1] = 'Head', [2] = 'Neck', [3] = 'Shoulder', [5] = 'Chest', [6] = 'Waist',
        [7] = 'Legs', [8] = 'Feet', [9] = 'Wrist', [10] = 'Hands', [11] = 'Ring 1', [12] = 'Ring 2',
        [13] = 'Trinket 1', [14] = 'Trinket 2', [15] = 'Back', [16] = 'Main Hand', [17] = 'Off Hand', [18] = 'Ranged',
        [20]='Bag 1',[21]='Bag 2',[22]='Bag 3',[23]='Bag 4',[24]='Reagent Bag'}
    local function Lock(slot)
        if not slot then return nil end
        return {type = 'toggle', text = labels[slot], tooltip = 'On: Gear keeps this slot unchanged and stops marking replacements for it.',
            getValue = function() return C().locked[slot] == true end,
            setValue = function(v) ns.SetSlotLocked(slot, v); Rebuild(false) end}
    end
    y = Header(W, parent, 'LOCKED SLOTS', y)
    local slots = ns.Engine.EQUIP_SLOTS
    for i = 1, #slots, 2 do y = Row(W, parent, y, Lock(slots[i]), Lock(slots[i + 1])) end
    y = Spacer(W, parent, y)
    y = Header(W, parent, 'NEVER EQUIP', y)
    local ignored = {}
    for id, on in pairs(C().ignore) do if on and type(id) == 'number' then ignored[#ignored + 1] = id end end
    table.sort(ignored)
    y = Row(W, parent, y, {type = 'labeledButton', text = 'Never Equip an Item', buttonText = 'Add Item',
        tooltip = 'Gear will not equip or mark this item as an upgrade. It can still be chosen for vendor value.',
        onClick = function()
            EUI:ShowInputPopup({title = 'Never Equip an Item', message = 'Paste an item link or enter its item ID.',
                placeholder = 'Item link or item ID', confirmText = 'Add Item',
                onConfirm = function(text)
                    if ns.SetIgnored(text, true) then Rebuild(false) else ns.Say('Enter an item link or a positive whole-number item ID.',true) end
                end})
        end}, {type = 'label', text = #ignored == 0 and 'No items excluded' or ('%d items excluded'):format(#ignored)})
    local function Allow(id)
        if not id then return nil end
        local get = C_Item and C_Item.GetItemInfo or _G.GetItemInfo
        local ok, name = pcall(get, 'item:' .. id)
        return {type = 'labeledButton', text = ok and name or ('Item ' .. id), buttonText = 'Allow',
            tooltip = 'Remove this item from Never Equip.',
            onClick = function() ns.SetIgnored(id, false); Rebuild(false) end}
    end
    for i = 1, #ignored, 2 do y = Row(W, parent, y, Allow(ignored[i]), Allow(ignored[i + 1])) end
    y=Row(W,parent,y,{type='labeledButton',text='Never Equip This Variant',buttonText='Add Variant',
        tooltip='Excludes one enchanted or random-suffix version of an item, by its full link.',onClick=function()
        EUI:ShowInputPopup({title='Never Equip This Variant',message='Paste the full item link. This rule matches its enchant and variant, not every item with the same ID.',confirmText='Add Variant',
            onConfirm=function(link) if ns.SetIgnored(link,true,true) then Rebuild(false) else ns.Say('Paste a full item link.',true) end end})
    end},{type='labeledButton',text='AutoGear Slot Locks',buttonText='Import Locks',tooltip='Copies the slot locks saved from AutoGear.',onClick=function()
        local rules=ns.Account().migrationRules
        EUI:ShowConfirmPopup({title='Import AutoGear Slot Locks',message='Copy the saved AutoGear locked slots to Gear. Automatic actions stay as configured.',confirmText='Import Locks',cancelText='Cancel',
            onConfirm=function() for slot,on in pairs(rules and rules.locked or {}) do if on then ns.SetSlotLocked(slot,true) end end;Rebuild(false) end})
    end})
    for link,on in pairs(C().ignoreLinks) do if on then y=Row(W,parent,y,{type='labeledButton',text=link,buttonText='Allow Variant',onClick=function() ns.SetIgnored(link,false,true);Rebuild(false) end}) end end
    return y
end

-- The live Hunter model: what it reads, its talent ranks (detected or yours), and a copyable report.
local function HunterSection(W,parent,y)
    local M,D=ns.HunterModel,ns.HunterData
    local modelOff=function() return not M.Active() end
    local offTip='Score Source: Automatic or Hunter Model'
    y=Spacer(W,parent,y)
    y=Header(W,parent,'HUNTER MODEL',y)
    local w=M.Current()
    local status=w and ('|cff40ff59Model DPS %.1f (levelling estimate); 1 Agility = %.3f DPS|r'):format(w.base,w.dps.Agility)
        or (M.Active() and '|cffffc733No ranged weapon or stats to model yet|r' or '|cffffc733Off: Score Source is Stat Weights|r')
    y=Row(W,parent,y,{type='label',text=status},{type='labeledButton',text='Model Report',buttonText='Show',tooltip='Every live input, assumption and weight, ready to copy.',
        onClick=function() EUI:ShowCopyPopup('FHK Gear Hunter Model','Live inputs, assumptions and weights. Ctrl+C to copy.',M.Report()) end})
    y=Row(W,parent,y,Drop('Pet','hunterPet',{auto='Detect',pet='Always Out',none='No Pet (Lone Wolf)'},{'auto','pet','none'},
            'Whether your pet counts: it gains 22% of your ranged attack power and 30% of your Stamina.',modelOff,offTip),
        Slider('Multi-Shot Targets','multiTargets',1,5,1,'Targets a typical Multi-Shot hits while you level.',false,modelOff,offTip))
    local function Rank(key)
        if not key then return nil end
        local t=D.talents[key]
        local _,how=M.TalentRank(key)
        return {type='slider',text=t.name,min=0,max=t.max,step=1,disabled=modelOff,disabledTooltip=offTip,
            tooltip=('Ranks you have. Detected: %s. Moving it sets your own value.'):format(how),
            getValue=function() return (M.TalentRank(key)) end,
            setValue=function(v) if S.Number(v) and v>=0 and v<=t.max then C().hunterTalents[key]=math.floor(v+0.5);Apply(true) end end}
    end
    local order=D.talentOrder
    for i=1,#order,2 do y=Row(W,parent,y,Rank(order[i]),Rank(order[i+1])) end
    y=Row(W,parent,y,{type='labeledButton',text='Talent Ranks',buttonText='Use Detected',tooltip='Forgets the ranks you set and reads them from the client again.',
        disabled=modelOff,disabledTooltip=offTip,onClick=function() C().hunterTalents={};Rebuild() end})
    return y
end
local function ModelPage(W,parent,y)
    y=Header(W,parent,'MODEL ASSUMPTIONS',y)
    y=Row(W,parent,y,Drop('Comparison Model','comparisonModel',{weights='Approximate Stat Weights',rotation='Ability Adjusted (Experimental)'},{'weights','rotation'},
            'Ability Adjusted adds your learned abilities below to weapon comparisons.'),
        Drop('Weapon Preference','weaponStyle',{preset='Spec Default',any='Any Legal Setup',['2h']='Two-Hander',['dual wield']='Dual Wield',['weapon and shield']='Weapon and Shield',['dagger and any']='Main-Hand Dagger'},{'preset','any','2h','dual wield','weapon and shield','dagger and any'},
            'Which weapon setups Gear compares.'))
    y=Row(W,parent,y,Slider('Fight Length (Seconds)','fightLength',1,600,1,'Typical fight length; sets how much Use effects and short procs are worth.'),
        Slider('Melee Participation','meleeShare',0,100,1,'Share of your damage from melee swings; sets the value of melee-only procs.',true))
    y=Row(W,parent,y,Slider('Use Effect Availability','useUptime',0,100,1,'How often a Use effect is ready and used when it matters.',true),
        Slider('Incoming Hits per Second','incomingHits',0,10,0.1,'How often you are struck; sets the value of "when struck" effects.'))
    y=Row(W,parent,y,Toggle('Automate With Proc Estimates','allowEstimates','On: "Chance on hit" items without a stated rate use the default procs per minute, and automatic actions may use them. Off: such items are only marked.'),
        Drop('Target Creature','targetType',{any='Any',undead='Undead',beast='Beast',demon='Demon',dragonkin='Dragonkin',elemental='Elemental',humanoid='Humanoid'},{'any','undead','beast','demon','dragonkin','elemental','humanoid'},
            'Counts "when fighting" bonuses against this creature type.'))
    y=Row(W,parent,y,Drop('Rating Units','ratingUnits',{unknown='Unconfirmed (Manual)',percent='Percentage Points',rating='Rating (Conversion Required)'},{'unknown','percent','rating'},
            'How crit and hit on items are read. Unconfirmed keeps such items manual.'),
        {type='labeledButton',text='Rating Conversions',buttonText='Set Conversions',tooltip='Rating points per 1% for each stat.',
            disabled=function() return C().ratingUnits~='rating' end,disabledTooltip='Rating Units: Rating',onClick=function()
        EUI:ShowInputPopup({title='Rating Conversions',message='Verified rating points per 1%. Example: Crit=14, Hit=10. Use current Forever level/build values.',confirmText='Save',onConfirm=function(text)
            local parsed,why=ns.Weights.Parse(text)
            if not parsed then ns.Say(why,true);return end
            local values={}
            for key,value in pairs(parsed) do if ({Crit=true,Hit=true,SpellCrit=true,SpellHit=true,Haste=true,Dodge=true,Parry=true,Block=true})[key] and S.Number(value) and value>0 then values[key]=value end end
            C().ratingConversions=values;ns.Items.Invalidate();Rebuild()
        end})
    end})
    y=Spacer(W,parent,y)
    y=Header(W,parent,'PER-ITEM PROC RATES',y)
    y=Row(W,parent,y,{type='labeledButton',text='Proc Rate Override',buttonText='Set Rate',tooltip='Use a sourced PPM or chance per eligible hit. An internal cooldown is in seconds.',onClick=function()
        EUI:ShowInputPopup({title='Proc Rate Override',message='Format: itemID, ppm=value or chance=percent, icd=seconds. Example: 14555, ppm=1, icd=0',confirmText='Save',onConfirm=function(text)
            local id,out=ns.ParseProcRate(text)
            if not id then ns.Say(out,true);return end
            C().procRates[id]=out;Rebuild()
        end})
    end},{type='labeledButton',text='Proc Rates',buttonText='Reset Rates',tooltip='Removes every proc rate you entered.',onClick=function() C().procRates={};Rebuild() end})
    for id,rate in pairs(C().procRates) do if S.Number(id) and S.Table(rate) then
        local itemID=id
        y=Row(W,parent,y,{type='labeledButton',text=('Item %d: %s; ICD %ss'):format(id,S.Number(rate.ppm) and (rate.ppm .. ' PPM') or tostring(rate.chance) .. '% per hit',tostring(rate.icd or 0)),
            buttonText='Remove Rate',onClick=function() C().procRates[itemID]=nil;Rebuild() end})
    end end
    y=Spacer(W,parent,y)
    y=Header(W,parent,'LEARNED ABILITIES',y)
    y=Row(W,parent,y,{type='label',text=ns.Context.Description()},{type='label',text='Talents, enchants and unknown effects need explicit evidence'})
    local context=ns.Context.Get()
    local rotationOff=function() return C().comparisonModel~='rotation' end
    for id,ability in pairs(ns.Context.Abilities) do if ability.class==context.class then
        local spellID=id
        y=Row(W,parent,y,{type='input',text=ability.name .. ' Casts per Fight',inputWidth=80,tooltip='Casts in a typical fight, for Ability Adjusted comparisons.',
            disabled=rotationOff,disabledTooltip='Comparison Model: Ability Adjusted',
            getValue=function() return tostring(C().rotation[spellID] or 0) end,
            setValue=function(text) local n=tonumber(text);if S.Number(n) and n>=0 and n<=1000 then C().rotation[spellID]=n;Apply() end end})
    end end
    if ns.HunterModel and ns.HunterModel.Available() then y=HunterSection(W,parent,y) end
    y=Spacer(W,parent,y)
    y=Header(W,parent,'ELLESMERE PROFILE',y)
    y=Row(W,parent,y,Toggle('Include Weight Library','profileIncludeWeights','Copies Gear weight scales with the Ellesmere profile through the companion.'),
        Toggle('Include Locks and Never Equip','profileIncludeRules','Copies character equipment rules with the Ellesmere profile. Off: rules stay on this character.'))
    return y
end
local PREBUILD_LABELS = {
    Automation={'Auto-Equip Upgrades','Auto-Pick Quest Rewards','Auto-Roll on Loot','Levelling Mode','Auto-Equip Up To','Auto-Equip Empty Bag Upgrades','Auto-Equip Better Ammo',
        'Action Pop-Ups','Upgrade Found Pop-Ups','Pop-Up Duration','Pop-Up Preview','Auto-Equip Bind-on-Equip','Auto-Confirm Bind Prompt','Need on Upgrades','Greed on Other Loot','Auto-Confirm Roll Prompt','Chat Messages'},
    ['Stat Weights']={'Spec','Phase','Score Source','Endgame From Level','Weight Scale','Share These Weights'},
    Markers={'Tooltip Score','Quest Reward Borders','Bag Upgrade Icons','Loot Roll Marks','Character Slot Marks','Upgrade Marker Style',
        'Greed Marker Style','Icon Size','Marker Opacity','Marker Appearance'},
    ['Equipment Rules']={'Never Equip an Item','Never Equip This Variant','AutoGear Slot Locks'},
    Model={'Comparison Model','Weapon Preference','Fight Length (Seconds)','Melee Participation','Use Effect Availability','Incoming Hits per Second',
        'Automate With Proc Estimates','Target Creature','Rating Units','Rating Conversions','Proc Rate Override','Model Report','Pet','Multi-Shot Targets',
        'Talent Ranks','Include Weight Library','Include Locks and Never Equip'},
}
local PAGES = {Automation = AutomationPage, ['Stat Weights'] = WeightsPage, Markers = MarkersPage, ['Equipment Rules'] = EquipmentRulesPage,['Model'] = ModelPage}
EUI.RegisterPlugin(ADDON, {label = 'Gear', position = 'bottom', modules = {{
    key = 'gear', title = 'Gear',
    description = 'Upgrade scores, quest reward choice and auto-equip for levelling.',
    pages = {'Automation', 'Stat Weights', 'Markers', 'Equipment Rules','Model'},
    buildPage = function(page, parent, yOffset)
        local W = EUI.Widgets
        local build = PAGES[page]
        if not (W and build) then return 0 end
        if EUI.IsSearchPrebuild and EUI.IsSearchPrebuild() then
            local y=yOffset or 0
            y=Header(W,parent,page,y)
            -- Each page indexes only its own labels, so a search result opens the right page (audit status N06).
            local names=PREBUILD_LABELS[page] or {}
            for i=1,#names,2 do y=Row(W,parent,y,{type='label',text=names[i]},names[i+1] and {type='label',text=names[i+1]} or nil) end
            return math.abs(y)
        end
        if parent then parent._showRowDivider = true end
        return math.abs(build(W, parent, yOffset or 0))
    end,
    getHeaderBuilder = function(page) if page == 'Markers' then return MarkersHeader end end,
    onReset = function() ns.ResetSettings() end,
    onPageCacheRestore=function() Rebuild(false) end,
}}})

-- One row on Ellesmere's QoL page when the local core patch offers its extension API.
local linked=false
function ns.TryQoLLink()
    if linked or type(EUI.RegisterOptionsExtension) ~= 'function' then return end
    local ok,accepted,why=S.Call('QoL link',EUI.RegisterOptionsExtension, ADDON, 'gearLink', {module = 'EllesmereUIQoL', page = 'QoL', point = 'page.end'}, {{
        id = 'gear', title = 'GEAR', rows = {{id = 'open', type = 'labeledButton', text = 'Upgrades, Quest Rewards and Auto-Equip',
            buttonText = 'Open', onClick = function() EUI.OpenPlugin(ADDON) end}}}})
    linked=ok and accepted==true
    if not linked and why then S.Note('QoL link',why) end
end
