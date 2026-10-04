local addon, NS = ...
local EUI, FHK = EllesmereUI, (_G.FHKEllesmereNS or _G.ForeverHunterKeysNS)
if EUI_CLIENT_BLOCKED or not EUI or not FHK then return end
local skin, pending, elapsed = nil, true, 0
local driver=CreateFrame('Frame')
local retries=0
local SyncRetries
local styled = setmetatable({}, {__mode = 'k'})
local windows = setmetatable({}, {__mode = 'k'})
local muted = setmetatable({}, {__mode = 'k'})
local bagIDs = setmetatable({}, {__mode = 'k'})
local layoutWatched = setmetatable({}, {__mode = 'k'})
local MEDIA = 'Interface\\AddOns\\EllesmereUI\\media\\'
local KEY_ICON = 'Interface\\AddOns\\' .. addon .. '\\media\\menu-keyring.png'

local function Database()
    FHKEllesmereDB = FHKEllesmereDB or {}
    return FHKEllesmereDB
end

local function SeedChrome()
    local db = Database()
    if db.chromeVersion == 1 then return end
    local profile = EUI.GetActiveProfileData and EUI.GetActiveProfileData()
    if profile then
        db.charStyleBefore = {blizzard = profile.charSheetUseBlizzardStyle,
            classic = profile.charSheetUseClassicStyle, forever = profile.charSheetUseForeverStyle}
        profile.charSheetUseBlizzardStyle, profile.charSheetUseClassicStyle, profile.charSheetUseForeverStyle = false, false, false
    end
    if EllesmereUIDB then
        EllesmereUIDB.blizzWindowSkinStyles = EllesmereUIDB.blizzWindowSkinStyles or {}
        db.charWindowBefore = EllesmereUIDB.blizzWindowSkinStyles.charsheet
        EllesmereUIDB.blizzWindowSkinStyles.charsheet = 'modern'
        EllesmereUIDB.themedCharacterSheet = true
    end
    local ns = EUI._ModuleNS and EUI._ModuleNS.EllesmereUIBlizzardSkin
    if ns then ns._csStyle, ns._csForever = nil, nil end -- re-latch the requested look at login
    local bars = EUI._ModuleNS and EUI._ModuleNS.EllesmereUIActionBars
    local eab = bars and bars.EAB
    local p = eab and eab.db and eab.db.profile
    if p then
        db.blizzardXPBefore = p.useBlizzardDataBars
        p.useBlizzardDataBars = false
        p.bars = p.bars or {}
        p.bars.XPBar = p.bars.XPBar or {}
        local xp = p.bars.XPBar
        db.xpBefore = {}; for k, v in pairs(xp) do db.xpBefore[k] = v end
        xp.width, xp.height = math.min(1000, UIParent:GetWidth() * 0.6), 14
        xp.barTexture, xp.colorMode = 'atrocity', 'custom'
        xp.customColor = {r = 0.722, g = 0.631, b = 0.867}
        xp.showLevel, xp.showRawValues, xp.customBorder, xp.barVisibility = true, true, false, 'always'
        p.barPositions = p.barPositions or {}
        db.xpPositionBefore = p.barPositions.XPBar
        p.barPositions.XPBar = {point = 'BOTTOM', relPoint = 'BOTTOM', x = 0, y = 6}
    end
    db.chromeVersion = 1
end

local function SeedFonts()
    local db = Database()
    if db.fontVersion == 1 then return end
    local fonts = EUI.GetFontsDB and EUI.GetFontsDB()
    if fonts then fonts.applyToAllGameText = true end
    local path = EUI.GetFontPath and EUI.GetFontPath()
    if path and EllesmereUIDB then
        EllesmereUIDB.fctFont = path
        _G.DAMAGE_TEXT_FONT = path
        if CombatTextFont then pcall(CombatTextFont.SetFont, CombatTextFont, path, 120, '') end
    end
    db.fontVersion = 1
end

local function MuteTexture(texture)
    if not texture or not texture.IsObjectType or not texture:IsObjectType('Texture') then return end
    texture:SetAlpha(0)
    if muted[texture] then return end
    muted[texture] = true
    -- Native interface-style refreshes restore the bevel; keep only that art muted.
    hooksecurefunc(texture, 'SetAlpha', function(self, alpha)
        if (not issecretvalue or not issecretvalue(alpha)) and alpha ~= 0 then self:SetAlpha(0) end
    end)
end

local function StripDecoration(frame, keep, depth)
    if not frame then return end
    keep = keep or styled[frame] and styled[frame].hover
    if frame.GetRegions then
        for _, region in ipairs({frame:GetRegions()}) do
            if region ~= keep then MuteTexture(region) end
        end
    end
    for _, key in ipairs({'NineSlice', 'Border', 'BorderFrame', 'Background', 'PushedBackground',
        'FlashBorder', 'Shadow', 'PushedShadow', 'Backdrop', 'SlotBackground', 'ArtFrame', 'IconBorder', 'IconOverlay'}) do
        local part = frame[key]
        if part and part ~= frame then
            MuteTexture(part)
            if part.GetRegions then
                for _, region in ipairs({part:GetRegions()}) do MuteTexture(region) end
            end
        end
    end
    if frame.GetChildren and (depth or 0) < 2 then
        for _, child in ipairs({frame:GetChildren()}) do
            local own = styled[frame]
            if not own or child ~= own.face then StripDecoration(child, nil, (depth or 0) + 1) end
        end
    end
end

local function ButtonChrome(button, texture, isBag)
    if not skin or not button or (button.IsForbidden and button:IsForbidden()) then return end
    if InCombatLockdown() then pending = true; return end
    if styled[button] then
        styled[button].icon:SetTexture(texture)
        styled[button].face:SetFrameLevel(button:GetFrameLevel() + 10)
        styled[button].artwork:SetFrameLevel(button:GetFrameLevel() + 11)
        StripDecoration(button, styled[button].hover); return
    end
    -- Paint a noninteractive child. The original secure button still owns all clicks.
    skin.FadeRegions(button)
    if button.NineSlice then skin.FadeNineSlice(button.NineSlice) end
    for _, get in ipairs({'GetNormalTexture', 'GetPushedTexture', 'GetDisabledTexture', 'GetHighlightTexture'}) do
        local t = button[get] and button[get](button)
        if t then t:SetAlpha(0) end
    end
    local face = CreateFrame('Frame', nil, button)
    face:SetPoint('TOPLEFT', button, 'TOPLEFT', 1, -1)
    face:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -1, 1)
    face:SetFrameLevel(button:GetFrameLevel() + 10); face:EnableMouse(false)
    skin.Panel(face, {noBorder = true})
    -- Panel registers its direct regions for later stripping. Put our glyph
    -- on a separate child so loot/mail/window refreshes cannot fade it out.
    local artwork = CreateFrame('Frame', nil, face)
    artwork:SetAllPoints(face); artwork:EnableMouse(false)
    artwork:SetFrameLevel(face:GetFrameLevel() + 1)
    local background = artwork:CreateTexture(nil, 'BACKGROUND')
    background:SetAllPoints(); background:SetColorTexture(.067, .067, .067, 1)
    -- Thin neutral framing covers native bag slot art, including empty slots.
    for _, edge in ipairs({'TOP', 'BOTTOM', 'LEFT', 'RIGHT'}) do
        local line = artwork:CreateTexture(nil, 'BORDER')
        line:SetColorTexture(.28, .25, .22, .8)
        if edge == 'TOP' or edge == 'BOTTOM' then
            line:SetHeight(1); line:SetPoint(edge .. 'LEFT'); line:SetPoint(edge .. 'RIGHT')
        else line:SetWidth(1); line:SetPoint('TOP' .. edge); line:SetPoint('BOTTOM' .. edge) end
    end
    local icon = artwork:CreateTexture(nil, 'ARTWORK')
    icon:SetSize(20, 20); icon:SetPoint('CENTER')
    icon:SetTexture(texture)
    if isBag then
        icon:SetAllPoints(artwork); icon:SetTexCoord(.09, .91, .09, .91)
    else icon:SetVertexColor(.78, .70, .62, 1) end
    local hover = button:CreateTexture(nil, 'HIGHLIGHT')
    hover:SetAllPoints(face); hover:SetColorTexture(1, 1, 1, 0.12)
    styled[button] = {face = face, artwork = artwork, icon = icon, hover = hover}
    StripDecoration(button, hover)
    local count = button.Count or button.count
    if count and count.SetAlpha then
        count:SetParent(artwork); count:ClearAllPoints(); count:SetPoint('BOTTOMRIGHT', face, 'BOTTOMRIGHT', -1, 1)
        count:SetDrawLayer('OVERLAY'); count:SetAlpha(1); skin.Font(count)
    end
end

local menuOrder = {'CharacterMicroButton','ProfessionMicroButton','SpellbookMicroButton','PlayerSpellsMicroButton',
    'TalentMicroButton','LegacyMicroButton','LegacyChallengeMicroButton','QuestLogMicroButton',
    'GuildMicroButton','SocialsMicroButton','LFDMicroButton','CollectionsMicroButton','AchievementMicroButton',
    'PVPMicroButton','EJMicroButton','HousingMicroButton','StoreMicroButton','HelpMicroButton'}
local layingOut, layoutHooks, layoutQueued
local LayoutMenu
local function QueueMenuLayout()
    if layingOut or layoutQueued then return end
    if InCombatLockdown() then pending = true; return end
    layoutQueued = true
    C_Timer.After(0, function() layoutQueued = nil; LayoutMenu() end)
end
LayoutMenu = function()
    local parent, menu = _G.MicroMenu, _G.MainMenuMicroButton
    if not parent or not menu or not menu:IsShown() or layingOut then return end
    if InCombatLockdown() then pending = true; return end
    local list, seen = {}, {}
    local function Add(button)
        if (type(button) == 'table' or type(button) == 'userdata') and
            type(button.IsShown) == 'function' and button ~= menu and not seen[button] and button:IsShown() then
            local name = button.GetName and button:GetName()
            if name and name:lower():find('legacy') then ButtonChrome(button, MEDIA .. 'micromenu\\menu-achievements.png') end
            list[#list+1] = button; seen[button] = true
        end
    end
    for _, entry in ipairs(_G.MICRO_BUTTONS or menuOrder) do
        local button = entry
        if type(entry) == 'string' then button = _G[entry] end
        Add(button)
    end
    for _, name in ipairs(menuOrder) do Add(_G[name]) end
    -- Forever can add a client-specific button outside the shared list.
    for _, child in ipairs({parent:GetChildren()}) do
        local name = child.GetName and child:GetName()
        if name and name:find('MicroButton') then
            Add(child)
        end
    end
    if #list == 0 then return end
    layingOut = true
    local cell, gap, columns = 24, 3, math.max(5, math.ceil(#list / 2))
    local height, width = cell * 2 + gap, columns * (cell + gap) + 34
    parent:SetSize(width, height)
    if _G.MicroMenuContainer then _G.MicroMenuContainer:SetSize(width, height) end
    for i, button in ipairs(list) do
        local column, row = (i-1) % columns, math.floor((i-1) / columns)
        button:SetParent(parent); button:SetScale(1)
        button:SetSize(cell, cell); button:ClearAllPoints()
        button:SetPoint('TOPLEFT', parent, 'TOPLEFT', column * (cell + gap), -row * (cell + gap))
        if not layoutWatched[button] then
            layoutWatched[button]=true
            hooksecurefunc(button,'SetPoint',QueueMenuLayout)
            hooksecurefunc(button,'SetSize',QueueMenuLayout)
        end
    end
    menu:SetParent(parent); menu:SetScale(1)
    menu:SetSize(34, height); menu:ClearAllPoints()
    menu:SetPoint('TOPRIGHT', parent, 'TOPRIGHT')
    if styled[menu] then styled[menu].icon:SetSize(26, 26) end
    if not layoutWatched[menu] then
        layoutWatched[menu]=true
        hooksecurefunc(menu,'SetPoint',QueueMenuLayout)
        hooksecurefunc(menu,'SetSize',QueueMenuLayout)
    end
    layingOut = nil
end

local function BagChrome(button, bagID)
    if not button then return end
    bagID = bagID or bagIDs[button] or button.bagID
    local name = button.GetName and (button:GetName() or ''):lower() or ''
    local keyID = Enum and Enum.BagIndex and Enum.BagIndex.Keyring or -2
    local bags = _G.BagsBar
    if name:find('keyring', 1, true) or bagID == keyID or bagID == -2 or
        bags and (button == bags.KeyRingButton or button == bags.KeyringButton or button == bags.Keyring) then
        bagIDs[button] = keyID
        ButtonChrome(button, KEY_ICON)
        local own = styled[button]
        if own then
            own.icon:SetAlpha(1); own.icon:SetTexCoord(0,1,0,1)
            own.icon:SetVertexColor(221/255,168/255,128/255,1)
            own.icon:ClearAllPoints(); own.icon:SetSize(20,20)
            own.icon:SetPoint('CENTER', own.artwork, 'CENTER')
        end
        return
    end
    if button == _G.MainMenuBarBackpackButton or bagID == 0 then
        ButtonChrome(button, MEDIA .. 'micromenu\\menu-bags.png'); return
    end
    if bagID then bagIDs[button] = bagID end
    local native = button.icon or button.Icon or button.IconTexture
    if not native and button.GetName then native = _G[(button:GetName() or '') .. 'IconTexture'] end
    local texture = native and native.GetTexture and native:GetTexture()
    local equipped = texture ~= nil
    if bagID and C_Container and C_Container.GetContainerNumSlots then
        equipped = C_Container.GetContainerNumSlots(bagID) > 0
    end
    if equipped and bagID and C_Container and C_Container.ContainerIDToInventoryID and GetInventoryItemTexture then
        texture = GetInventoryItemTexture('player', C_Container.ContainerIDToInventoryID(bagID)) or texture
    end
    ButtonChrome(button, equipped and texture or MEDIA .. 'micromenu\\menu-bags.png', equipped)
    local own = styled[button]
    if own then
        own.icon:SetAlpha(equipped and 1 or .3)
        own.icon:SetTexCoord(equipped and .09 or 0, equipped and .91 or 1, equipped and .09 or 0, equipped and .91 or 1)
        own.icon:ClearAllPoints()
        if equipped then own.icon:SetPoint('TOPLEFT', own.artwork, 'TOPLEFT', 2, -2); own.icon:SetPoint('BOTTOMRIGHT', own.artwork, 'BOTTOMRIGHT', -2, 2)
        else own.icon:SetSize(20,20); own.icon:SetPoint('CENTER', own.artwork, 'CENTER') end
        if equipped then own.icon:SetVertexColor(1,1,1,1)
        else own.icon:SetVertexColor(221/255,168/255,128/255,1); own.icon:SetAlpha(.75) end
    end
end

local function WindowChrome(frame)
    if not frame or windows[frame] or (frame.IsForbidden and frame:IsForbidden()) then return end
    skin.Shell(frame)
    if frame.NineSlice then skin.FadeNineSlice(frame.NineSlice) end
    if frame.Inset then skin.Inset(frame.Inset) end
    if frame.CloseButton then skin.CloseButton(frame.CloseButton) end
    local title = frame.TitleText or frame.TitleContainer and frame.TitleContainer.TitleText
    if title then title:SetAlpha(1); skin.Font(title, .91, .92, .94) end
    windows[frame] = true
end

local function RefreshChrome()
    if not skin or InCombatLockdown() then pending = true; return end
    for name, image in pairs({CharacterMicroButton = 'menu-character.png',
        SpellbookMicroButton = 'menu-spellbook.png', PlayerSpellsMicroButton = 'menu-spellbook.png',
        TalentMicroButton = 'menu-vault.png', LegacyMicroButton = 'menu-achievements.png',
        LegacyChallengeMicroButton = 'menu-achievements.png',
        QuestLogMicroButton = 'menu-quests.png', MainMenuMicroButton = 'menu-options.png',
        HelpMicroButton = 'menu-cs.png', MainMenuBarBackpackButton = 'menu-bags.png',
        ProfessionMicroButton = 'menu-professions.png', AchievementMicroButton = 'menu-achievements.png',
        GuildMicroButton = 'menu-guild.png', LFDMicroButton = 'menu-group.png',
        CollectionsMicroButton = 'menu-collections.png', EJMicroButton = 'menu-adventure.png',
        PVPMicroButton = 'menu-pvp.png', SocialsMicroButton = 'menu-friends.png',
        StoreMicroButton = 'menu-shop.png', HousingMicroButton = 'menu-housing.png'}) do
        ButtonChrome(_G[name], MEDIA .. 'micromenu\\' .. image)
    end
    for i = 0, 5 do
        local button = _G['CharacterBag' .. i .. 'Slot']
        if button then
            BagChrome(button, i + 1)
        end
    end
    for _, name in ipairs({'KeyRingButton', 'KeyringButton', 'KeyRingMicroButton', 'KeyRingSlot'}) do
        BagChrome(_G[name], -2)
    end
    local bags = _G.BagsBar
    if bags then BagChrome(bags.KeyRingButton or bags.KeyringButton or bags.Keyring, -2) end
    local mgr = _G.MainMenuBarBagManager
    if mgr and mgr.EnumerateBagButtons then
        for _, button in mgr:EnumerateBagButtons() do
            BagChrome(button, button.GetBagID and button:GetBagID())
        end
    end
    LayoutMenu()
    if not layoutHooks then
        layoutHooks = true
        for _, name in ipairs({'UpdateMicroButtons', 'UpdateMicroButtonsParent', 'MoveMicroButtons'}) do
            if type(_G[name]) == 'function' then hooksecurefunc(_G, name, QueueMenuLayout) end
        end
        for _, frame in ipairs({_G.MicroMenu, _G.MicroMenuContainer}) do
            for _, name in ipairs({'Layout', 'UpdateLayout', 'ResetMicroMenuPosition', 'OverrideMicroMenuPosition'}) do
                if type(frame[name]) == 'function' then hooksecurefunc(frame,name,QueueMenuLayout) end
            end
        end
        if _G.BagsBar and type(_G.BagsBar.Layout) == 'function' then
            hooksecurefunc(_G.BagsBar,'Layout',function()
                if InCombatLockdown() then pending=true; return end
                for button,id in pairs(bagIDs) do BagChrome(button,id) end
                ButtonChrome(_G.MainMenuBarBackpackButton,MEDIA .. 'micromenu\\menu-bags.png')
            end)
        end
    end
    for _, name in ipairs({'MicroMenu', 'MicroMenuContainer', 'BagsBar'}) do StripDecoration(_G[name]) end
    do -- cap options are on the action-bar module, not the Blizzard buttons
        local ns = EUI._ModuleNS and EUI._ModuleNS.EllesmereUIActionBars
        local p = ns and ns.EAB and ns.EAB.db and ns.EAB.db.profile
        if p and p.bars then
            for _, key in ipairs({'MicroBar', 'BagBar'}) do
                local b = p.bars[key]
                if b then b.endCapLeft, b.endCapRight, b.foreverBarBg = false, false, false end
            end
            if ns.AB_ExtraCapsAll then ns.AB_ExtraCapsAll() end
        end
    end
    for _, name in ipairs({'KeyRingFrame', 'KeyringFrame', 'ContainerFrameCombinedBags'}) do WindowChrome(_G[name]) end
    for i = 1, 13 do WindowChrome(_G['ContainerFrame' .. i]) end
    local bars = EUI._ModuleNS and EUI._ModuleNS.EllesmereUIActionBars
    local xp = bars and bars.dataBarFrames and bars.dataBarFrames.XPBar
    if xp then
        if bars.ApplyDataBarLayout then bars.ApplyDataBarLayout('XPBar') end
        if xp._bg then xp._bg:SetColorTexture(0.055, 0.065, 0.075, 0.9) end
        if xp._restedBar then xp._restedBar:SetStatusBarTexture(MEDIA .. 'textures\\atrocity.tga') end
        if xp._text then skin.Font(xp._text, 0.91, 0.92, 0.94) end
    end
    pending = bars~=nil and not xp -- only an installed Action Bars module needs startup retries
    if SyncRetries then SyncRetries() end
end

local function RetryTick(_,dt)
    if not pending or not skin then driver:SetScript('OnUpdate',nil);return end
    if InCombatLockdown() then driver:SetScript('OnUpdate',nil);return end
    elapsed=elapsed+dt
    if elapsed<1 then return end
    elapsed,retries=0,retries+1
    RefreshChrome()
    if retries>=15 then pending=false;driver:SetScript('OnUpdate',nil) end
end
SyncRetries=function()
    if pending and skin and not InCombatLockdown() then
        if not driver:GetScript('OnUpdate') then
            elapsed,retries=0,0;driver:SetScript('OnUpdate',RetryTick)
        end
    else driver:SetScript('OnUpdate',nil) end
end

if EUI.RegisterSkin then
    EUI.RegisterSkin('FHKEllesmere', function(S)
        skin, FHK.EllesmereSkin = S, S
        S.OnLooksChanged(RefreshChrome)
        RefreshChrome()
    end)
end

driver:RegisterEvent('ADDON_LOADED'); driver:RegisterEvent('PLAYER_LOGIN')
driver:RegisterEvent('PLAYER_REGEN_ENABLED'); driver:RegisterEvent('BAG_UPDATE_DELAYED')
if not C_EventUtils or not C_EventUtils.IsEventValid or C_EventUtils.IsEventValid('INPUT_DEVICE_INTERFACE_TRANSITION') then
    driver:RegisterEvent('INPUT_DEVICE_INTERFACE_TRANSITION')
end
driver:SetScript('OnEvent', function(_, event, name)
    if event == 'ADDON_LOADED' then
        if name == addon then SeedChrome(); SeedFonts() end
        pending = true
        elapsed,retries=0,0
        if skin and not InCombatLockdown() then RefreshChrome() end
        return
    end
    if event == 'PLAYER_LOGIN' then SeedChrome(); SeedFonts(); C_Timer.After(1, RefreshChrome)
    else RefreshChrome() end
end)
