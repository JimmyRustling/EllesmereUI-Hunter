-- Companion settings ride with the Ellesmere profile (audit F01/F41).
-- Gameplay and appearance keys live on EllesmereUIDB.profiles[name].fhkEllesmere
-- and are read through a metatable on FHKEllesmereDB, so switch, copy, rename,
-- delete and export follow Ellesmere natively. Per-character keys (binding
-- ownership, restore snapshots, version flags) stay in FHKEllesmereDB itself.
local addon = ...
local EUI, NS = _G.EllesmereUI, _G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end

local STORE_KEY = 'fhkEllesmere'
-- Keys that describe how the UI looks and behaves. Everything else stays per character.
local PROFILE_KEYS = {}
for _, key in ipairs({
    -- range, corpse and marker cues
    'indicators', 'attackPulses', 'attackCueSize', 'showRangeUnits', 'nameplateRangeText', 'rangeNameColors',
    'targetRangeGlow', 'nonTargetRange', 'lootCues', 'skinCues', 'cueFades', 'cueOutAlpha', 'nameplateOpacity',
    'rarityMarkers', 'rarityLevelColours', 'rarityIcons', 'rarityMarkerStyle', 'rarityIconSize',
    'rarityIconPosition', 'raritySkulls', 'rarityQuestCount',
    -- colours and bars
    'damageTrails', 'healthBarColors', 'resourceBarColors', 'healthTextColors', 'resourceTextColors',
    'petHappinessColors', 'petMoodIcon', 'petMoodStyle', 'petMoodStrip', 'petMoodHideHappy', 'resourceBarZones', 'alignPowerText', 'statusIconBadge', 'darkHealthLine', 'fleeTick', 'aggroPlates', 'petAggroPlates', 'combatFadeGuides', 'totOnYou', 'extraCombatIcons', 'petCombatIcon', 'petCombatSize', 'petCombatX', 'petCombatY', 'combatBlockSize', 'combatIconStyle', 'lootInHealthText',
    'vividCueText', 'vividBarFills', 'pixelIconEdges', 'pixelBarSeparators',
    -- warnings, XP, press feedback, swing cursor
    'warnings', 'xpBar', 'actionPress', 'swingCursor', 'reduceMotion', 'chromeVisibility', 'chatQuiet', 'keyboardKeyLabels', 'autoGearMode', 'aspectAdvisor', 'petElements', 'petFood', 'hunterCues', 'levelingQoL', 'hunterColors', 'cdmLabels',
    -- centre HUD position
    'point', 'relPoint', 'x', 'y', 'fhkGearSettings',
}) do PROFILE_KEYS[key] = true end
NS.EllesmereProfileKeys = PROFILE_KEYS
-- Shared idle gate (audit F35): sweeps run at full rate only while something
-- live can change (combat, a target or focus, visible nameplates, unlock mode).
local function Yes(v) return not (issecretvalue and issecretvalue(v)) and v == true end
function NS.EllesmereBusy()
    if Yes(InCombatLockdown()) or EUI._unlockActive then return true end
    if Yes(UnitExists('target')) or Yes(UnitExists('focus')) then return true end
    local np = _G.EllesmereNameplates_NS
    return np and type(np.plates) == 'table' and next(np.plates) ~= nil or false
end
local function Interval() return NS.EllesmereBusy() and .15 or 1 end
NS.EllesmereSweepInterval = Interval
-- One shared reduced-motion preference (audit F46): animated features read this.
function NS.EllesmereReduceMotion() return type(FHKEllesmereDB) == 'table' and FHKEllesmereDB.reduceMotion == true end

local function Copy(v)
    if type(v) ~= 'table' then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = Copy(x) end
    return out
end

local fallback, lastStore, loadedName
local function ActiveProfile()
    local root = _G.EllesmereUIDB
    local name = root and root.activeProfile or 'Default'
    local profile = root and type(root.profiles) == 'table' and root.profiles[name]
    return type(profile) == 'table' and profile or nil, name
end
-- The active profile's companion table. A profile seen for the first time
-- starts as a copy of the last one, so switching never drops you to defaults.
local function Store()
    local profile = ActiveProfile()
    if not profile then fallback = fallback or {}; return fallback end
    local store = profile[STORE_KEY]
    if type(store) ~= 'table' then
        store = Copy(lastStore or fallback or {})
        profile[STORE_KEY] = store
    end
    lastStore = store
    return store
end
NS.EllesmereProfileStore = Store

local proxy = {
    __index = function(_, key) if PROFILE_KEYS[key] then return Store()[key] end end,
    __newindex = function(t, key, value)
        if PROFILE_KEYS[key] then Store()[key] = value else rawset(t, key, value) end
    end,
}

-- First load: move this character's existing settings onto the active profile
-- (unless that profile already carries companion settings from another
-- character, which win). Replaced values are kept under _preProfile.
local function Attach(db)
    if getmetatable(db) == proxy then return end
    local store = Store()
    local moved
    for key in pairs(PROFILE_KEYS) do
        local value = rawget(db, key)
        if value ~= nil then
            if store[key] == nil then store[key] = value
            else
                db._preProfile = db._preProfile or {}
                db._preProfile[key] = value
            end
            rawset(db, key, nil); moved = true
        end
    end
    if moved then db.profileMigrated = 1 end
    setmetatable(db, proxy)
    loadedName = select(2, ActiveProfile())
end
NS.AttachEllesmereProfile = Attach

-- Re-sync live features after the active profile changes.
local function Resync()
    for _, name in ipairs({'SyncEllesmereAspects', 'SyncEllesmerePetElements', 'SyncEllesmerePetFood', 'SyncEllesmereHunterCues', 'SyncEllesmereLeveling', 'ApplyEllesmereHunterColours', 'SyncEllesmereCdmLabels', 'SyncEllesmereWarnings', 'SyncEllesmerePressFeedback', 'SyncEllesmereCueFades', 'SyncEllesmereNameplateOpacity',
        'SyncEllesmereXPBar', 'SyncEllesmereChromeVisibility', 'ApplyEllesmereIndicators', 'RefreshEllesmereRarity',
        'SyncEllesmereUnitRefinements', 'SyncEllesmereReviewedProfile', 'SyncEllesmereVividTheme', 'SyncEllesmereCueText',
        'ApplySwingCursor', 'ApplyEllesmereChatQuiet', 'PaintEllesmereResourceBars', 'SyncEllesmereAutoGearMode', 'SyncEllesmereClassHUD', 'SyncEllesmereGearProfile'}) do
        if type(NS[name]) == 'function' then pcall(NS[name]) end
    end
    if EUI.RefreshPage then pcall(EUI.RefreshPage, EUI) end
end
NS.SyncEllesmereProfileFeatures = Resync
local function CheckSwitch()
    local name = select(2, ActiveProfile())
    if loadedName and name ~= loadedName then
        loadedName = name
        Store(); Resync()
    end
end
NS.CheckEllesmereProfileSwitch = CheckSwitch

-- Imports start from the recipient's profile and overlay known keys only, so
-- copy our table across explicitly. Subset imports keep the recipient's.
local function AfterImport(payload, profileName)
    if type(payload) == 'string' and EUI.DecodeImportString then payload = EUI.DecodeImportString(payload) end
    local data = type(payload) == 'table' and payload.type == 'full' and payload.data
    if type(data) ~= 'table' or type(data[STORE_KEY]) ~= 'table' or data.partialImport then return end
    local root = _G.EllesmereUIDB
    local name = profileName or (root and root.activeProfile) or 'Default'
    local profile = root and root.profiles and root.profiles[name]
    if type(profile) ~= 'table' then return end
    profile[STORE_KEY] = Copy(data[STORE_KEY])
    if name == select(2, ActiveProfile()) then lastStore = profile[STORE_KEY]; Resync() end
end
NS.EllesmereProfileAfterImport = AfterImport

-- A native module Reset also resets the companion settings shown on that
-- module's pages (audit F02). Entries are whole keys or {key, subkey}.
local RESET_KEYS = {
    _EUIGlobal = {'vividCueText','vividBarFills','pixelIconEdges','pixelBarSeparators','reduceMotion','chatQuiet','autoGearMode','fhkGearSettings'},
    EllesmereUINameplates = {'showRangeUnits', 'nameplateRangeText', 'rangeNameColors', 'targetRangeGlow',
        'nonTargetRange', 'lootCues', 'skinCues', 'cueFades', 'cueOutAlpha', 'nameplateOpacity', 'rarityMarkers', 'rarityLevelColours',
        'rarityIcons', 'rarityMarkerStyle', 'rarityIconSize', 'rarityIconPosition', 'raritySkulls', 'rarityQuestCount',
        'aggroPlates', 'petAggroPlates', {'indicators', 'plate'}, {'damageTrails', 'nameplates'}},
    EllesmereUIUnitFrames = {'aspectAdvisor', 'petElements', 'petFood', 'healthBarColors', 'healthTextColors', 'resourceTextColors', 'petHappinessColors', 'petMoodIcon', 'petMoodStyle', 'petMoodHideHappy',
        'petMoodStrip', 'alignPowerText', 'statusIconBadge', 'darkHealthLine', 'fleeTick', 'totOnYou', 'petCombatIcon', 'combatIconStyle', 'petCombatSize', 'petCombatX', 'petCombatY', 'combatBlockSize', 'lootInHealthText', {'indicators', 'frame'}, {'damageTrails', 'unitframes'}},
    EllesmereUIResourceBars = {'resourceBarZones', 'resourceBarColors', 'attackPulses', 'attackCueSize',
        {'indicators', 'range'}, {'indicators', 'attacks'}, 'point', 'relPoint', 'x', 'y'},
    EllesmereUIActionBars = {'xpBar', 'actionPress', 'chromeVisibility', 'keyboardKeyLabels'},
    EllesmereUIQoL = {'warnings', 'swingCursor', 'hunterCues', 'levelingQoL', 'hunterColors'},
}
NS.EllesmereResetKeys = RESET_KEYS
function NS.ResetEllesmereCompanionFor(folder)
    local list = RESET_KEYS[folder]
    if not list then return false end
    local store = Store()
    for _, entry in ipairs(list) do
        if type(entry) == 'table' then
            local t = store[entry[1]]
            if type(t) == 'table' then t[entry[2]] = nil end
        else store[entry] = nil end
    end
    return true
end

-- Per-character tables still keyed by profile name follow rename and delete.
local NAME_KEYED = {'themePresets', 'classHUD', 'chromeVisibilityBefore'}
local function Renamed(oldName, newName)
    local db = _G.FHKEllesmereDB
    if type(db) ~= 'table' or oldName == nil or newName == nil then return end
    if db.reviewedProfileBefore and db.reviewedProfileBefore.name==oldName then db.reviewedProfileBefore.name=newName end
    for _, key in ipairs(NAME_KEYED) do
        local t = rawget(db, key)
        if type(t) == 'table' and t[oldName] ~= nil then t[newName] = t[oldName]; t[oldName] = nil end
    end
    if loadedName == oldName then loadedName = newName end
end
local function Deleted(name)
    local db = _G.FHKEllesmereDB
    if type(db) ~= 'table' or name == nil then return end
    if db.reviewedProfileBefore and db.reviewedProfileBefore.name==name then db.reviewedProfileBefore=nil end
    for _, key in ipairs(NAME_KEYED) do
        local t = rawget(db, key)
        if type(t) == 'table' then t[name] = nil end
    end
end
NS.EllesmereProfileRenamed, NS.EllesmereProfileDeleted = Renamed, Deleted

local hooked
local function Hook()
    if hooked then return end
    hooked = true
    if type(EUI.ImportProfile) == 'function' then
        hooksecurefunc(EUI, 'ImportProfile', function(importStr, profileName) pcall(AfterImport, importStr, profileName) end)
    end
    if type(EUI.OnProfileRenamed) == 'function' then hooksecurefunc(EUI, 'OnProfileRenamed', Renamed) end
    if type(EUI.OnProfileDeleted) == 'function' then hooksecurefunc(EUI, 'OnProfileDeleted', Deleted) end
    if EUI.RegisterDarkModeRefresh then EUI.RegisterDarkModeRefresh(CheckSwitch) end
end

local driver = CreateFrame('Frame')
driver:RegisterEvent('ADDON_LOADED'); driver:RegisterEvent('PLAYER_LOGIN'); driver:RegisterEvent('PLAYER_LOGOUT')
driver:SetScript('OnEvent', function(_, event, name)
    if event == 'ADDON_LOADED' then
        if name ~= addon then return end
        if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end
        Attach(FHKEllesmereDB); Hook()
    elseif event == 'PLAYER_LOGIN' then
        CheckSwitch()
    elseif event == 'PLAYER_LOGOUT' then
        -- Ellesmere had no profile table yet: keep the settings with the character.
        if fallback and not ActiveProfile() and type(FHKEllesmereDB) == 'table' then
            setmetatable(FHKEllesmereDB, nil)
            for key, value in pairs(fallback) do rawset(FHKEllesmereDB, key, value) end
        end
    end
end)
