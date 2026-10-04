-- One-time personal keyboard layout; all subsequent edits use native EUI movers.
local addon=...
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end
local driver=CreateFrame('Frame')
local pending,pendingPet
local pendingIdle
local keys={'MainBar','Bar2','Bar3','Bar4','Bar5','Bar6','Bar7','Bar8','PetBar'}
-- 2: quest bar leaves the centre stack; right wing reordered. A higher
-- version re-applies the preset once; Unlock Mode edits are kept after that.
local LAYOUT_VERSION=2
-- The native pet action bar joined the preset later; it is placed once on its own.
-- 2: one row in the gap under the pet unit frame (5x2 overlapped that frame).
-- 3: centred above the three combat rows (player's choice).
local PET_BAR_VERSION=3
local wings={'Bar4','Bar5','Bar6','Bar7','Bar8','PetBar'}
local visibilityFields={'barVisibility','visibilityModes','visibilityMatch','alwaysHidden','mouseoverEnabled',
    'mouseoverAlpha','_savedBarAlpha','combatHideEnabled','combatShowEnabled'}
local function Copy(v)
    if type(v)~='table' then return v end
    local result={};for k,value in pairs(v) do result[k]=Copy(value) end;return result
end
local function ActionBars()
    local ns=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIActionBars
    return ns,ns and ns.EAB and ns.EAB.db and ns.EAB.db.profile
end
local function ProfileName() return EllesmereUIDB and EllesmereUIDB.activeProfile or 'Default' end
local function Request(value)
    local _,p=ActionBars()
    return {value=value,profile=p,name=ProfileName()}
end
local function IsCurrent(request,p)
    return request and request.profile~=nil and request.profile==p and request.name==ProfileName()
end
function NS.EllesmereIdleWingsEnabled()
    local _,p=ActionBars()
    if IsCurrent(pendingIdle,p) then return pendingIdle.value end
    return p and p.fhkWingFadeBefore~=nil or false
end
function NS.ApplyEllesmereIdleWings(enabled)
    if InCombatLockdown() then pendingIdle=Request(enabled and true or false);return false end
    local ns,p=ActionBars()
    local compat=ns and ns.EAB and ns.EAB.VisibilityCompat
    if not p or not p.bars or not ns._eabApplyAll or not EUI.SetVisibilitySelection or not compat then return false end
    if enabled then
        local before=p.fhkWingFadeBefore or {};p.fhkWingFadeBefore=before
        for _,key in ipairs(wings) do
            local s=p.bars[key]
            if s then
                if not before[key] then
                    before[key]={}
                    for _,field in ipairs(visibilityFields) do before[key][field]=Copy(s[field]) end
                end
                s.visibilityMatch='any'
                EUI.SetVisibilitySelection(s,'barVisibility',{in_combat=true,mouseover=true},compat.ApplyMode)
            end
        end
    elseif p.fhkWingFadeBefore then
        for key,saved in pairs(p.fhkWingFadeBefore) do
            local s=p.bars[key]
            if s then for _,field in ipairs(visibilityFields) do s[field]=Copy(saved[field]) end end
        end
        p.fhkWingFadeBefore=nil
    end
    pendingIdle=nil;ns._eabApplyAll();return true
end
-- Micro menu and bag bar (with the keyring) hide in combat through Ellesmere's
-- own hide_in_combat lane; its combat refresh shows them again afterwards.
-- The exact previous visibility is kept per bar and restored when switched off.
local CHROME={'MicroBar','BagBar'}
local pendingChrome
function NS.EllesmereChromeHiddenInCombat()
    local _,p=ActionBars()
    if IsCurrent(pendingChrome,p) then return pendingChrome.value end
    local s=p and p.bars and p.bars.MicroBar
    return s and s.fhkCombatHideBefore~=nil or false
end
function NS.SetEllesmereChromeHiddenInCombat(on)
    if InCombatLockdown() then pendingChrome=Request(on and true or false);return false end
    local ns,p=ActionBars()
    local compat=ns and ns.EAB and ns.EAB.VisibilityCompat
    if not p or not ns._eabApplyAll or not EUI.SetVisibilitySelection or not EUI.GetVisibilitySelection or not compat then return false end
    p.bars=p.bars or {}
    for _,key in ipairs(CHROME) do
        local s=p.bars[key] or {};p.bars[key]=s
        if on and not s.fhkCombatHideBefore then
            s.fhkCombatHideBefore={}
            for _,field in ipairs(visibilityFields) do s.fhkCombatHideBefore[field]=Copy(s[field]) end
            local selection=EUI.GetVisibilitySelection(s,'barVisibility')
            selection.hide_in_combat=true
            EUI.SetVisibilitySelection(s,'barVisibility',selection,compat.ApplyMode)
        elseif not on and s.fhkCombatHideBefore then
            for _,field in ipairs(visibilityFields) do s[field]=Copy(s.fhkCombatHideBefore[field]) end
            s.fhkCombatHideBefore=nil
        end
    end
    pendingChrome=nil;ns._eabApplyAll();return true
end
local chromeModes={native=true,mouseover=true,combat_hover=true}
local pendingChromeIdleProfile
function NS.EllesmereChromeVisibility()
    local mode=FHKEllesmereDB and FHKEllesmereDB.chromeVisibility
    return chromeModes[mode] and mode or 'native'
end
local function ChromeProfileName()
    return EllesmereUIDB and EllesmereUIDB.activeProfile or 'Default'
end
function NS.SyncEllesmereChromeVisibility()
    local ns,p=ActionBars()
    local compat=ns and ns.EAB and ns.EAB.VisibilityCompat
    local db=FHKEllesmereDB
    if not db or not p or not ns._eabApplyAll or not EUI.SetVisibilitySelection or not compat then return false end
    local mode=NS.EllesmereChromeVisibility()
    local restores=rawget(db,'chromeVisibilityBefore')
    local name=ChromeProfileName()
    local before=restores and restores[name]
    if mode=='native' and not before then return true end
    if InCombatLockdown() then pendingChromeIdleProfile=p;return false end
    p.bars=p.bars or {}
    if mode~='native' then
        if not restores then restores={};rawset(db,'chromeVisibilityBefore',restores) end
        before=before or {};restores[name]=before
        for _,key in ipairs(CHROME) do
            local s=p.bars[key] or {};p.bars[key]=s
            if not before[key] then
                before[key]={}
                -- Migrate our earlier combat-only preset from its ORIGINAL baseline.
                local original=s.fhkCombatHideBefore or s
                for _,field in ipairs(visibilityFields) do before[key][field]=Copy(original[field]) end
            end
            s.fhkCombatHideBefore=nil
            s.visibilityMatch='any'
            local selection={mouseover=true}
            if mode=='combat_hover' then selection.in_combat=true end
            EUI.SetVisibilitySelection(s,'barVisibility',selection,compat.ApplyMode)
        end
    else
        for _,key in ipairs(CHROME) do
            local s=p.bars[key]
            if s and before[key] then
                for _,field in ipairs(visibilityFields) do s[field]=Copy(before[key][field]) end
                s.fhkCombatHideBefore=nil
            end
        end
        restores[name]=nil
    end
    pendingChromeIdleProfile=nil
    ns._eabApplyAll();return true
end
function NS.SetEllesmereChromeVisibility(mode)
    if not chromeModes[mode] or not FHKEllesmereDB then return false end
    FHKEllesmereDB.chromeVisibility=mode
    return NS.SyncEllesmereChromeVisibility()
end
-- The character's native profile uses 30px squares. Read actual UI width
-- after EUI's scale settles; preserve that size when the display fits it.
local function Geometry()
    local size=math.max(26,math.min(30,math.floor((UIParent:GetWidth()-160)/26)-2))
    local step=size+2
    local wing=9*step+12
    -- Centre: three combat rows only (rotation, control, cooldowns). Left wing:
    -- pet commands, then tracking/beast tools. The native pet action bar is one
    -- row centred just above the three combat rows, under the swing HUD.
    -- Right wing: recovery/items, rare buffs, then the RestedXP quest bar (4x2).
    return size,{MainBar={0,50,1},Bar2={0,50+step+4,1},Bar3={0,50+2*(step+4),1},
        Bar4={-wing,50,2},Bar7={-wing,50+2*step+10,2},PetBar={0,50+3*(step+4)+8,1},
        Bar6={wing,50,2},Bar5={wing,50+2*step+10,2},Bar8={wing,50+4*step+20,2}}
end
local function Snapshot(undo,p,key)
    undo.bars[key]=p.bars[key]~=nil and Copy(p.bars[key]) or false
    undo.positions[key]=p.barPositions[key]~=nil and Copy(p.barPositions[key]) or false
    for _,map in ipairs({'unlockAnchors','unlockWidthMatch','unlockHeightMatch'}) do
        local t=EllesmereUIDB and EllesmereUIDB[map]
        undo.links[map]=undo.links[map] or {}
        undo.links[map][key]=t and t[key]~=nil and Copy(t[key]) or false
    end
end
local function Place(p,key,size,position)
    local b=p.bars[key] or {}; p.bars[key]=b
    b.enabled,b.alwaysHidden,b.barVisibility=true,false,'always'
    b.buttonWidth,b.buttonHeight,b.buttonPadding=size,size,2
    b.numIcons,b.numRows,b.orientation=key=='Bar8' and 8 or key=='PetBar' and 10 or 12,position[3],'horizontal'
    b.overrideNumIcons,b.overrideNumRows=b.numIcons,b.numRows
    b.targetWidth,b.targetHeight=0,0
    b.hideMacroText,b.hideKeybind,b.keybindFontSize=true,false,10
    b.bgEnabled,b.foreverBarBg,b.endCapLeft,b.endCapRight=false,false,false,false
    b.alwaysShowButtons,b.mouseoverEnabled,b.combatHideEnabled=false,false,false
    b.buttonShape,b.growDirection,b.iconOrder='none','up',nil
    b.reverseIconOrder=false
    p.barPositions[key]={point='BOTTOM',relPoint='BOTTOM',x=position[1],y=position[2]}
    for _,map in ipairs({'unlockAnchors','unlockWidthMatch','unlockHeightMatch'}) do
        if EllesmereUIDB and EllesmereUIDB[map] then EllesmereUIDB[map][key]=nil end
    end
end
function NS.ApplyEllesmereHunterLayout()
    if InCombatLockdown() then pending=Request(true); return false end
    local ns=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIActionBars
    local p=ns and ns.EAB and ns.EAB.db and ns.EAB.db.profile
    if not p or not ns._eabApplyAll or not EUI._applySavedPositions then return false end
    p.bars,p.barPositions=p.bars or {},p.barPositions or {}
    -- One undo step (audit F14/F34): everything this preset touches, kept on the
    -- native profile so it travels with profile copies.
    local undo={bars={},positions={},links={}}
    for _,key in ipairs(keys) do Snapshot(undo,p,key) end
    p.fhkLayoutUndo=undo
    local size,placements=Geometry()
    for _,key in ipairs(keys) do Place(p,key,size,placements[key]) end
    EUI._anchorLinksStamp=(EUI._anchorLinksStamp or 0)+1
    p.fhkKeyboardLayoutVersion=LAYOUT_VERSION
    p.fhkPetBarVersion=PET_BAR_VERSION
    ns._eabApplyAll()
    EUI._applySavedPositions()
    if p.fhkWingFadeBefore then NS.ApplyEllesmereIdleWings(true) end
    pending=nil
    print('FHK: Hunter layout applied to 9 action bars (including the pet bar). Undo: Action Bars -> Hunter Keyboard Layout.')
    return true
end
function NS.CanUndoEllesmereHunterLayout()
    local _,p=ActionBars()
    return p and p.fhkLayoutUndo~=nil or false
end
function NS.UndoEllesmereHunterLayout()
    if InCombatLockdown() then print('FHK: leave combat to undo the layout.');return false end
    local ns=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIActionBars
    local p=ns and ns.EAB and ns.EAB.db and ns.EAB.db.profile
    local undo=p and p.fhkLayoutUndo
    if not undo then return false end
    for _,key in ipairs(keys) do
        -- A bar the snapshot never covered (older undo steps predate the pet bar) is left as is.
        if undo.bars[key]~=nil then
            p.bars[key]=undo.bars[key] or nil
            p.barPositions[key]=undo.positions[key] or nil
            for map,saved in pairs(undo.links or {}) do
                local t=EllesmereUIDB and EllesmereUIDB[map]
                if t then t[key]=saved[key] or nil end
            end
        end
    end
    p.fhkLayoutUndo=nil
    EUI._anchorLinksStamp=(EUI._anchorLinksStamp or 0)+1
    if ns._eabApplyAll then ns._eabApplyAll() end
    if EUI._applySavedPositions then EUI._applySavedPositions() end
    print('FHK: action bars restored to before the Hunter layout.')
    return true
end
-- Shows and places only the native pet action bar, keeping every other bar as
-- the player left it. Joins the existing undo step, so Undo also hides it again.
function NS.ApplyEllesmerePetBar()
    if InCombatLockdown() then pendingPet=Request(true); return false end
    local ns,p=ActionBars()
    if not p or not ns._eabApplyAll or not EUI._applySavedPositions then return false end
    p.bars,p.barPositions=p.bars or {},p.barPositions or {}
    local undo=p.fhkLayoutUndo
    if undo and undo.bars and undo.bars.PetBar==nil then Snapshot(undo,p,'PetBar') end
    local size,placements=Geometry()
    Place(p,'PetBar',size,placements.PetBar)
    EUI._anchorLinksStamp=(EUI._anchorLinksStamp or 0)+1
    p.fhkPetBarVersion=PET_BAR_VERSION
    pendingPet=nil
    ns._eabApplyAll();EUI._applySavedPositions()
    if p.fhkWingFadeBefore then NS.ApplyEllesmereIdleWings(true) end
    print('FHK: pet action bar centred above the combat rows. Move it in Unlock Mode like any bar.')
    return true
end
local function Initial()
    if addon=='FHKEllesmere' and FHKEllesmereDB then
        -- Apply this player's idle-visibility request once; later choices persist.
        if not rawget(FHKEllesmereDB,'chromeIdleRequested') and (_G.ForeverHunterKeysNS~=nil) then
            if FHKEllesmereDB.chromeVisibility==nil then FHKEllesmereDB.chromeVisibility='mouseover' end
            rawset(FHKEllesmereDB,'chromeIdleRequested',true)
        end
        NS.SyncEllesmereChromeVisibility()
    end
    -- Upstream module exposes the preset as an opt-in button. The companion
    -- applies it once only for the user's explicitly requested FHK setup.
    if addon~='FHKEllesmere' or not _G.ForeverHunterKeysNS or select(2,UnitClass('player'))~='HUNTER' then return end
    local ns=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIActionBars
    local p=ns and ns.EAB and ns.EAB.db and ns.EAB.db.profile
    if p and (p.fhkKeyboardLayoutVersion or 0)<LAYOUT_VERSION then NS.ApplyEllesmereHunterLayout()
    elseif p and (p.fhkPetBarVersion or 0)<PET_BAR_VERSION then NS.ApplyEllesmerePetBar() end
end
driver:RegisterEvent('PLAYER_LOGIN'); driver:RegisterEvent('PLAYER_REGEN_ENABLED')
driver:SetScript('OnEvent',function(_,event)
    if event=='PLAYER_LOGIN' then C_Timer.After(1,Initial)
    else
        local _,p=ActionBars()
        local layout,pet,idle,chrome=pending,pendingPet,pendingIdle,pendingChrome
        pending,pendingPet,pendingIdle,pendingChrome=nil,nil,nil,nil
        if IsCurrent(layout,p) then NS.ApplyEllesmereHunterLayout()
        elseif IsCurrent(pet,p) then NS.ApplyEllesmerePetBar() end
        if IsCurrent(idle,p) then NS.ApplyEllesmereIdleWings(idle.value) end
        if IsCurrent(chrome,p) then NS.SetEllesmereChromeHiddenInCombat(chrome.value) end
        if pendingChromeIdleProfile then
            local _,p=ActionBars()
            if p==pendingChromeIdleProfile then NS.SyncEllesmereChromeVisibility() end
            pendingChromeIdleProfile=nil
        end
    end
end)
