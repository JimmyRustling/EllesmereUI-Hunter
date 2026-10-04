-- FHK Gear: Ellesmere-style pop-up cards for what Gear did (equipped, quest reward, loot roll) and for
-- upgrades it leaves to you (Upgrade Found, with Equip and Never Equip). Non-modal: never dims the
-- screen or takes clicks away from the game. Built from Ellesmere's own pieces (MakeFont, MakeBorder,
-- accent colour, close icon, the popup palette) and movable in Ellesmere's Unlock Mode.
-- Nothing is created until the first card. Fading uses an AnimationGroup (no OnUpdate).
-- CC BY-NC-SA 4.0 (part of FHK Gear). See LICENSE.md.
if EUI_CLIENT_BLOCKED then return end
local ADDON, ns = ...
local S = ns.Safe
local N = {}
ns.Notify = N
local EUI = _G.EllesmereUI
local WIDTH, MAX_CARDS = 320, 3
local DEFAULT_POS = {point = 'TOP', relPoint = 'TOP', x = 0, y = -180}
local BG = {0.06, 0.08, 0.10} -- Ellesmere popup background
local holder, cards = nil, {}

local function Accent()
    if EUI and EUI.GetAccentColor then
        local r, g, b = EUI.GetAccentColor()
        if S.Number(r) and S.Number(g) and S.Number(b) then return r, g, b end
    end
    return 0.05, 0.82, 0.62
end
local function Font(parent, size, r, g, b)
    if EUI and EUI.MakeFont then return EUI.MakeFont(parent, size, nil, r, g, b) end
    local fs = parent:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
    if r then fs:SetTextColor(r, g, b) end
    return fs
end
local function Border(frame, r, g, b, a)
    if EUI and EUI.MakeBorder then return EUI.MakeBorder(frame, r, g, b, a) end
end
local function Position()
    local p = ns.Char().popPos
    if S.Table(p) and S.Text(p.point) and S.Number(p.x) and S.Number(p.y) then return p end
    return DEFAULT_POS
end
local function ApplyPosition()
    if not holder then return end
    local p = Position()
    holder:ClearAllPoints()
    holder:SetPoint(p.point, UIParent, S.Text(p.relPoint) and p.relPoint or p.point, p.x, p.y)
end
local function Holder()
    if holder then return holder end
    holder = CreateFrame('Frame', 'FHKGearPopUps', UIParent)
    holder:SetSize(WIDTH, 64)
    holder:SetFrameStrata('HIGH')
    ApplyPosition()
    return holder
end

local function Restack()
    local y = 0
    for _, card in ipairs(cards) do
        if card:IsShown() then
            card:ClearAllPoints()
            card:SetPoint('TOP', holder, 'TOP', card.entering and 24 or 0, -y)
            y = y + card:GetHeight() + 6
        end
    end
end
-- A small Ellesmere-style button: dark fill, thin border that turns accent on hover.
local function SmallButton(parent, text, primary)
    local b = CreateFrame('Button', nil, parent)
    b:SetSize(86, 22)
    local bg = b:CreateTexture(nil, 'BACKGROUND'); bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 0.5)
    local r, g, bl = Accent()
    local border = Border(b, primary and r or 1, primary and g or 1, primary and bl or 1, primary and 0.7 or 0.2)
    local label = Font(b, 11, primary and r or 0.8, primary and g or 0.8, primary and bl or 0.8)
    label:SetPoint('CENTER'); label:SetText(text)
    b:SetScript('OnEnter', function() if border and border.SetColor then border:SetColor(r, g, bl, 1) end; label:SetTextColor(1, 1, 1) end)
    b:SetScript('OnLeave', function()
        if border and border.SetColor then border:SetColor(primary and r or 1, primary and g or 1, primary and bl or 1, primary and 0.7 or 0.2) end
        label:SetTextColor(primary and r or 0.8, primary and g or 0.8, primary and bl or 0.8)
    end)
    b.label = label
    return b
end
local function Card()
    local card = CreateFrame('Frame', nil, Holder())
    card:SetSize(WIDTH, 64)
    card:EnableMouse(true)
    local bg = card:CreateTexture(nil, 'BACKGROUND'); bg:SetAllPoints(); bg:SetColorTexture(BG[1], BG[2], BG[3], 0.94)
    Border(card, 1, 1, 1, 0.15)
    card.stripe = card:CreateTexture(nil, 'ARTWORK')
    card.stripe:SetPoint('TOPLEFT'); card.stripe:SetPoint('BOTTOMLEFT'); card.stripe:SetWidth(2)
    local iconFrame = CreateFrame('Frame', nil, card)
    iconFrame:SetSize(36, 36); iconFrame:SetPoint('TOPLEFT', 12, -12)
    card.icon = iconFrame:CreateTexture(nil, 'ARTWORK'); card.icon:SetAllPoints(); card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    card.iconBorder = Border(iconFrame, 1, 1, 1, 0.6)
    card.iconFrame = iconFrame
    card.title = Font(card, 11); card.title:SetPoint('TOPLEFT', iconFrame, 'TOPRIGHT', 10, 1)
    card.name = Font(card, 13); card.name:SetPoint('TOPLEFT', card.title, 'BOTTOMLEFT', 0, -3)
    card.name:SetWidth(WIDTH - 90); card.name:SetJustifyH('LEFT'); card.name:SetWordWrap(false)
    card.detail = Font(card, 11, 0.7, 0.7, 0.7); card.detail:SetPoint('TOPLEFT', card.name, 'BOTTOMLEFT', 0, -3)
    card.detail:SetWidth(WIDTH - 90); card.detail:SetJustifyH('LEFT'); card.detail:SetWordWrap(false)
    card.stats = Font(card, 11, 0.85, 0.85, 0.85); card.stats:SetPoint('TOPLEFT', card.detail, 'BOTTOMLEFT', 0, -3)
    card.stats:SetWidth(WIDTH - 90); card.stats:SetJustifyH('LEFT'); card.stats:SetWordWrap(false)
    local close = CreateFrame('Button', nil, card)
    close:SetSize(14, 14); close:SetPoint('TOPRIGHT', -8, -8)
    local closeTex = close:CreateTexture(nil, 'ARTWORK'); closeTex:SetAllPoints()
    closeTex:SetTexture(EUI and EUI.ICONS_PATH and (EUI.ICONS_PATH .. 'eui-close.png') or 'Interface\\Buttons\\UI-StopButton')
    close:SetAlpha(0.4)
    close:SetScript('OnEnter', function() close:SetAlpha(0.8) end)
    close:SetScript('OnLeave', function() close:SetAlpha(0.4) end)
    close:SetScript('OnClick', function() card:Hide(); Restack() end)
    card.equip = SmallButton(card, 'Equip', true); card.equip:SetPoint('BOTTOMRIGHT', -10, 10)
    card.never = SmallButton(card, 'Never Equip', false); card.never:SetPoint('RIGHT', card.equip, 'LEFT', -6, 0)
    -- Fade out after the chosen time; hovering keeps it.
    local fade = card:CreateAnimationGroup()
    local alpha = fade:CreateAnimation('Alpha')
    alpha:SetFromAlpha(1); alpha:SetToAlpha(0); alpha:SetDuration(0.4)
    fade:SetScript('OnFinished', function() card:Hide(); card:SetAlpha(1); Restack() end)
    card.fade, card.alpha = fade, alpha
    -- Entrance: slide in from the right while fading in, eased out (Ellesmere animations use smoothing).
    local enter = card:CreateAnimationGroup()
    local slide = enter:CreateAnimation('Translation')
    slide:SetOffset(-24, 0); slide:SetDuration(0.25); slide:SetSmoothing('OUT')
    local appear = enter:CreateAnimation('Alpha')
    appear:SetFromAlpha(0); appear:SetToAlpha(1); appear:SetDuration(0.25); appear:SetSmoothing('OUT')
    enter:SetScript('OnPlay', function() card:SetAlpha(1) end)
    enter:SetScript('OnFinished', function() card.entering = false; Restack() end)
    card.enter = enter
    card:SetScript('OnEnter', function(self)
        self.fade:Stop(); self:SetAlpha(1)
        if self.link and GameTooltip then GameTooltip:SetOwner(self, 'ANCHOR_RIGHT'); S.Call('pop-up tooltip', GameTooltip.SetHyperlink, GameTooltip, self.link); GameTooltip:Show() end
    end)
    card:SetScript('OnLeave', function(self) if GameTooltip then GameTooltip:Hide() end; self.alpha:SetStartDelay(2); self.fade:Play() end)
    card:SetScript('OnMouseUp', function(self, button) if button == 'RightButton' then self:Hide(); Restack() end end)
    return card
end
local function NextCard()
    for _, card in ipairs(cards) do if not card:IsShown() then return card end end
    if #cards < MAX_CARDS then local card = Card(); cards[#cards + 1] = card; return card end
    -- All in use: reuse the oldest (top) one.
    local card = table.remove(cards, 1); cards[#cards + 1] = card; return card
end
local function QualityColour(quality)
    local c = ITEM_QUALITY_COLORS and S.Number(quality) and ITEM_QUALITY_COLORS[quality]
    if c and S.Number(c.r) then return c.r, c.g, c.b end
    return 1, 1, 1
end

-- kind: 'equipped' / 'quest' / 'roll' / 'skill' / 'found' / 'preview'. data: link, title, detail, job (found), greed.
function N.Show(kind, data)
    if not S.Table(data) or not S.Text(data.link) or not UIParent then return false end
    local c = ns.Char()
    if kind == 'found' and not c.popFound then return false end
    if kind ~= 'found' and kind ~= 'preview' and not c.popActions then return false end
    if S.Read(InCombatLockdown) == true and kind == 'found' then return false end
    local card = NextCard()
    local info = ns.Items.Read(data.link)
    local quality = info and info.quality
    local name = info and S.Read(C_Item and C_Item.GetItemInfo or _G.GetItemInfo, data.link) or data.link
    local icon = S.Read(C_Item and C_Item.GetItemIconByID or _G.GetItemIcon, info and info.id or data.link)
    local r, g, b = Accent()
    if data.greed then r, g, b = 1, 0.78, 0.2 end
    card.stripe:SetColorTexture(r, g, b, 1)
    card.title:SetTextColor(r, g, b)
    card.title:SetText(data.title or 'Gear')
    card.name:SetTextColor(QualityColour(quality))
    card.name:SetText(S.Text(name) and name or data.link)
    card.detail:SetText(data.detail or '')
    card.stats:SetText(data.stats or '')
    card.icon:SetTexture(icon or 'Interface\\Icons\\INV_Misc_QuestionMark')
    local qr, qg, qb = QualityColour(quality)
    if card.iconBorder and card.iconBorder.SetColor then card.iconBorder:SetColor(qr, qg, qb, 0.8) end
    card.link = data.link
    local job = data.job
    card.equip:SetShown(job ~= nil); card.never:SetShown(job ~= nil)
    local extra = S.Text(data.stats) and data.stats ~= '' and 14 or 0
    card:SetHeight((job and 86 or 62) + extra)
    if job then
        card.equip:SetScript('OnClick', function()
            if S.Read(InCombatLockdown) == true then ns.Say('Gear can equip this after combat.', true); return end
            -- Only the exact item Gear showed, still in the same bag slot.
            if S.Read(C_Container and C_Container.GetContainerItemLink, job.bag, job.slot) ~= data.link then ns.Say('That item has moved; open your bags to equip it.', true); return end
            S.Call('pop-up pickup', C_Container.PickupContainerItem, job.bag, job.slot)
            S.Call('pop-up equip', EquipCursorItem, ns.Engine.Inventory(job.target))
            card:Hide(); Restack()
        end)
        card.never:SetScript('OnClick', function()
            if info and info.id then ns.SetIgnored(info.id, true) end
            card:Hide(); Restack()
        end)
    end
    card.fade:Stop(); card:SetAlpha(1); card:Show()
    -- The card starts one slide-width to the right, so the entrance ends in place.
    card.enter:Stop(); card.entering = true
    card.alpha:SetStartDelay(math.max(3, math.min(30, S.Number(c.popDuration) and c.popDuration or 8)))
    card.fade:Play()
    Restack()
    card.enter:Play()
    return true
end

local function Gain(delta)
    if not S.Number(delta) then return nil end
    local w = ns.Weights.Current()
    if S.Table(w) and S.Number(w.scale) and w.scale > 0 then return ('+%.1f (+%.1f DPS)'):format(delta, delta / w.scale) end
    return ('+%.1f'):format(delta)
end
local function Replaced(oldLink)
    local name = S.Text(oldLink) and S.Read(C_Item and C_Item.GetItemInfo or _G.GetItemInfo, oldLink)
    return S.Text(name) and ('replaces ' .. name) or nil
end
-- "+4 Agility, +1% Crit, -2 Stamina": the biggest stat changes against the item it replaces.
local SHORT = {Agility = 'Agility', Strength = 'Strength', Stamina = 'Stamina', Intellect = 'Intellect', Spirit = 'Spirit',
    AttackPower = 'AP', RangedAttackPower = 'Ranged AP', Crit = '% Crit', Hit = '% Hit', Armor = 'Armor', DPS = 'DPS'}
local function StatChanges(info, oldLink)
    if not (info and info.stats) then return nil end
    local old = S.Text(oldLink) and ns.Items.Read(oldLink) or nil
    local list = {}
    for stat, label in pairs(SHORT) do
        local diff = (S.Number(info.stats[stat]) and info.stats[stat] or 0) - (old and S.Number(old.stats[stat]) and old.stats[stat] or 0)
        if math.abs(diff) > 0.05 then list[#list + 1] = {stat = stat, label = label, diff = diff} end
    end
    table.sort(list, function(a, b) return math.abs(a.diff) > math.abs(b.diff) end)
    local out = {}
    for i = 1, math.min(4, #list) do
        local e = list[i]
        local amount = (e.stat == 'DPS') and ('%+.1f'):format(e.diff) or ('%+d'):format(e.diff > 0 and math.floor(e.diff + 0.5) or -math.floor(-e.diff + 0.5))
        local colour = e.diff > 0 and '|cff40ff59' or '|cffff5a5a'
        out[#out + 1] = colour .. amount .. (e.label:sub(1, 1) == '%' and e.label or (' ' .. e.label)) .. '|r'
    end
    return #out > 0 and table.concat(out, '  ') or nil
end
N.StatChanges = StatChanges
local function Join(...) local t = {}; for i = 1, select('#', ...) do local v = select(i, ...); if S.Text(v) and v ~= '' then t[#t + 1] = v end end; return table.concat(t, ' - ') end

-- Weapon skill (player: "weapon skill can be levelled on an upgrade"): read live, never from the model cache.
local WEAPON_SLOTS = {16, 17, 18}
local function Skill(info)
    local D = ns.HunterData
    local line = D and info and not info.missing and info.classID == 2 and D.skills[info.subclassID]
    if not line then return nil end
    local data = S.Read(C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID, line)
    if not (S.Table(data) and S.Number(data.rank)) then return nil end
    local rank = data.rank + (S.Number(data.modifier) and data.modifier or 0)
    return {line = line, rank = rank, cap = ns.Level() * D.combat.skillPerLevel, name = S.Text(data.name) and data.name or 'Weapon'}
end
N.Skill = Skill
local function SkillText(info)
    local k = Skill(info)
    if k and k.rank < k.cap then return ('%s skill %d/%d: trains as you use it'):format(k.name, k.rank, k.cap) end
end
function N.Equipped(link, delta, oldLink)
    local info = ns.Items.Read(link)
    return N.Show('equipped', {link = link, title = 'Equipped', detail = Join(Gain(delta), Replaced(oldLink), SkillText(info)), stats = StatChanges(info, oldLink)})
end
-- Skill Maxed: a worn weapon's skill reaching your cap after real training (25+ points behind),
-- not the few points every level-up adds. The first pass only remembers where each skill stands.
local TRAINED = 25
local behind, skillPrimed = {}, false
function N.SkillCheck()
    for _, slot in ipairs(WEAPON_SLOTS) do
        local link = S.Read(GetInventoryItemLink, 'player', slot)
        local info = S.Text(link) and ns.Items.Read(link) or nil
        local k = info and Skill(info)
        if k then
            local gap = k.cap - k.rank
            if gap > 0 then behind[k.line] = math.max(behind[k.line] or 0, gap)
            else
                if skillPrimed and (behind[k.line] or 0) >= TRAINED then
                    N.Show('skill', {link = link, title = 'Weapon Skill Maxed', detail = ('%s %d/%d: no more misses from skill'):format(k.name, k.rank, k.cap)})
                end
                behind[k.line] = 0
            end
        end
    end
    skillPrimed = true
end
function N.ResetSkills() behind, skillPrimed = {}, false end
function N.QuestReward(link, how)
    return N.Show('quest', {link = link, title = how == 'vendor' and 'Quest Reward: Best Vendor Value' or 'Quest Reward: Upgrade', greed = how == 'vendor'})
end
function N.Rolled(link, choice)
    return N.Show('roll', {link = link, title = choice == 1 and 'Rolled Need' or 'Rolled Greed', greed = choice ~= 1})
end

-- Upgrade Found: each upgrade Gear will not equip by itself, once per session. The first pass after
-- login only remembers what is already in the bags, so nothing pops up for old items.
local seen, primed, foundQueued = {}, false, nil
function N.ResetFound() seen, primed = {}, false end
local function WillAutoEquip(job)
    return ns.Automating('autoEquip') and ns.AutoEquipAllowed(job.info) and ns.Engine.AutomationSafe(job.info)
end
local function ScanFound()
    foundQueued = nil
    if not ns.FoundPopUps() then return end
    local jobs = ns.Engine.BagUpgrades()
    for _, job in ipairs(jobs) do
        local key = job.info.link
        if not seen[key] then
            seen[key] = true
            if primed and not WillAutoEquip(job) then
                local why = job.reason ~= 'Fills an empty slot' and job.reason or nil
                local worn = S.Read(GetInventoryItemLink, 'player', ns.Engine.Inventory(job.target))
                N.Show('found', {link = key, title = 'Upgrade Found', detail = Join(Gain(job.delta), Replaced(worn)), stats = StatChanges(job.info, worn), job = job, why = why})
            end
        end
    end
    primed = true
end
function N.QueueFound()
    if not ns.FoundPopUps() then return end
    if foundQueued and S.Time() - foundQueued < 2 then return end
    foundQueued = S.Time()
    if not S.Call('pop-up scan', C_Timer and C_Timer.After, 0.6, ScanFound) then ScanFound() end
end
N.ScanFound = ScanFound

function N.Preview()
    local link = S.Read(GetInventoryItemLink, 'player', 18) or S.Read(GetInventoryItemLink, 'player', 5) or 'item:2504'
    N.Show('preview', {link = link, title = 'Equipped', detail = '+3.2 (+0.6 DPS) - replaces your old item'})
    N.Show('preview', {link = link, title = 'Upgrade Found', detail = '+1.8 - above your Auto-Equip rarity', job = {bag = -1, slot = -1, target = 18}})
end

-- Ellesmere Unlock Mode: move the pop-ups like any Ellesmere element.
local registered = false
function N.RegisterUnlock()
    if registered or not (EUI and EUI.RegisterUnlockElements and EUI.MakeUnlockElement) then return end
    registered = true
    S.Call('pop-up unlock', EUI.RegisterUnlockElements, EUI, {EUI.MakeUnlockElement({
        key = 'FHKGear_PopUps', label = 'Gear Pop-Ups', group = 'FHK Gear', order = 900,
        isHidden = function() local c = ns.Char(); return not (c.popActions or c.popFound) end,
        getFrame = function() return Holder() end,
        getSize = function() return WIDTH, 64 end,
        savePos = function(_, point, relPoint, x, y) ns.Char().popPos = {point = point, relPoint = relPoint, x = x, y = y}; ApplyPosition() end,
        loadPos = function() return Position() end,
        clearPos = function() ns.Char().popPos = nil; ApplyPosition() end,
        applyPos = function() Holder(); ApplyPosition() end,
        noResize = true,
    })}, ADDON)
end
