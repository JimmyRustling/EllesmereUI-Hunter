-- Hunter polish: sets Ellesmere's own action-bar options for a ranged/weave
-- Hunter, so everything stays native and each choice can be changed back in
-- Ellesmere's Action Bars options. Applied once; re-apply from Action Bars.
local addon=...
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end
-- 2: the Cooldown Manager's clean icon look on the bars (player request):
-- its 8% icon trim and a softer keybind colour so the art reads first.
local POLISH_VERSION=2
local BARS={'MainBar','Bar2','Bar3','Bar4','Bar5','Bar6','Bar7','Bar8'}
local ICON_ZOOM=8
local KEY_COLOUR={r=.86,g=.88,b=.92}
local driver=CreateFrame('Frame')
local pending

-- Returns false only when a native refresh exists and errors (audit F37).
local function Call(eab,name,...)
    local fn=eab[name]
    if type(fn)~='function' then return true end
    return (pcall(fn,eab,...))
end

function NS.ApplyEllesmereHunterPolish()
    if InCombatLockdown() then pending=true; return false end
    local ns=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIActionBars
    local eab=ns and ns.EAB
    local p=eab and eab.db and eab.db.profile
    if not p then return false end
    -- One undo step (audit F14/F34): the exact values this replaces. An earlier
    -- version's undo is kept, so Undo still returns to the look before any polish.
    local upgrading=(p.fhkHunterPolishVersion or 0)<POLISH_VERSION
    local undo=upgrading and p.fhkPolishUndo or nil
    if not undo then
        undo={pushedTextureType=p.pushedTextureType,highlightTextureType=p.highlightTextureType,
            showCastHighlight=p.showCastHighlight,desaturateOnCooldown=p.desaturateOnCooldown,cdSwipeAlpha=p.cdSwipeAlpha,
            countdown=C_CVar and C_CVar.GetCVar and C_CVar.GetCVar('countdownForCooldowns') or nil,range={}}
        for _,key in ipairs(BARS) do
            local bar=p.bars and p.bars[key]
            undo.range[key]=bar and bar.outOfRangeColoring
            if undo.range[key]==nil then undo.range[key]='nil' end
        end
    end
    if not undo.icons then
        undo.icons={}
        for _,key in ipairs(BARS) do
            local bar=p.bars and p.bars[key] or {}
            local c=bar.keybindFontColor
            undo.icons[key]={zoom=bar.iconZoom==nil and 'nil' or bar.iconZoom,
                colour=c and {r=c.r,g=c.g,b=c.b} or 'nil'}
        end
    end
    p.fhkPolishUndo=undo
    -- Press: a crisp accent border instead of a dark overlay. Hover: light.
    p.pushedTextureType,p.highlightTextureType,p.showCastHighlight=5,1,true
    -- Cooldowns read at a glance: grey while cooling, lighter swipe, numbers on.
    local wasDesat=p.desaturateOnCooldown or false
    p.desaturateOnCooldown,p.cdSwipeAlpha=true,60
    -- Out of range turns the icon red: the deadzone/range check on every bar.
    p.bars=p.bars or {}
    for _,key in ipairs(BARS) do
        local bar=p.bars[key] or {}; p.bars[key]=bar
        bar.outOfRangeColoring=true
        -- Clean icons: the Cooldown Manager's trim; quieter keybind text.
        bar.iconZoom=ICON_ZOOM
        bar.keybindFontColor={r=KEY_COLOUR.r,g=KEY_COLOUR.g,b=KEY_COLOUR.b}
    end
    if C_CVar and C_CVar.SetCVar then C_CVar.SetCVar('countdownForCooldowns','1') end
    local ok=true
    for _,name in ipairs({'ApplyPushedTextures','ApplyHighlightTextures','ApplyCheckedTextures','ApplyCooldownSwipeColor','ApplyRangeColoring',
        'ApplyBorders','ApplyShapes','ApplyFonts'}) do
        ok=Call(eab,name) and ok
    end
    if not wasDesat and type(eab._DesatSettingChanged)=='function' then ok=pcall(eab._DesatSettingChanged,true) and ok end
    -- The settings are saved either way and apply natively on reload; the version is
    -- recorded after the refresh so the result is reported honestly.
    p.fhkHunterPolishVersion=POLISH_VERSION
    pending=nil
    if not ok then
        print('FHK: Hunter polish saved, but part of the live refresh failed. /reload to finish applying it.')
        return 'partial'
    end
    return true
end
local function Profile()
    local ns=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIActionBars
    return ns and ns.EAB, ns and ns.EAB and ns.EAB.db and ns.EAB.db.profile
end
function NS.CanUndoEllesmereHunterPolish()
    local _,p=Profile()
    return p and p.fhkPolishUndo~=nil or false
end
function NS.UndoEllesmereHunterPolish()
    if InCombatLockdown() then print('FHK: leave combat to undo the polish.');return false end
    local eab,p=Profile()
    local undo=p and p.fhkPolishUndo
    if not undo then return false end
    p.pushedTextureType,p.highlightTextureType,p.showCastHighlight=undo.pushedTextureType,undo.highlightTextureType,undo.showCastHighlight
    p.desaturateOnCooldown,p.cdSwipeAlpha=undo.desaturateOnCooldown,undo.cdSwipeAlpha
    for key,value in pairs(undo.range or {}) do
        local bar=p.bars and p.bars[key]
        if bar then if value=='nil' then bar.outOfRangeColoring=nil else bar.outOfRangeColoring=value end end
    end
    for key,value in pairs(undo.icons or {}) do
        local bar=p.bars and p.bars[key]
        if bar then
            if value.zoom=='nil' then bar.iconZoom=nil else bar.iconZoom=value.zoom end
            if value.colour=='nil' then bar.keybindFontColor=nil else bar.keybindFontColor=value.colour end
        end
    end
    if undo.countdown~=nil and C_CVar and C_CVar.SetCVar then C_CVar.SetCVar('countdownForCooldowns',undo.countdown) end
    p.fhkPolishUndo=nil
    for _,name in ipairs({'ApplyPushedTextures','ApplyHighlightTextures','ApplyCheckedTextures','ApplyCooldownSwipeColor','ApplyRangeColoring',
        'ApplyBorders','ApplyShapes','ApplyFonts'}) do
        Call(eab,name)
    end
    if type(eab._DesatSettingChanged)=='function' then pcall(eab._DesatSettingChanged,p.desaturateOnCooldown==true) end
    print('FHK: action bar look restored to before the Hunter polish.')
    return true
end

local function Initial()
    -- Same scope as the bar preset: the user's own FHK Hunter setup.
    if addon~='FHKEllesmere' or not _G.ForeverHunterKeysNS or select(2,UnitClass('player'))~='HUNTER' then return end
    local ns=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIActionBars
    local p=ns and ns.EAB and ns.EAB.db and ns.EAB.db.profile
    if p and (p.fhkHunterPolishVersion or 0)<POLISH_VERSION then NS.ApplyEllesmereHunterPolish() end
end
-- Keyboard-first key labels (player request): a button bound to both a keyboard
-- key and a Naga output shows the keyboard key (Shift-G -> "SG", not "SF12"), and
-- Insert/Delete shorten so labels are never cut off. Runs after Ellesmere paints
-- its labels; text only, bindings are untouched.
local NAGA={F9=true,F10=true,F11=true,F12=true,INSERT=true,DELETE=true}
local NAGA_CHORD={['CTRL-SHIFT-B']=true,['CTRL-SHIFT-C']=true,['ALT-I']=true}
local COMMANDS={MainBar='ACTIONBUTTON',Bar2='MULTIACTIONBAR1BUTTON',Bar3='MULTIACTIONBAR2BUTTON',
    Bar4='MULTIACTIONBAR3BUTTON',Bar5='MULTIACTIONBAR4BUTTON',Bar6='MULTIACTIONBAR5BUTTON',
    Bar7='MULTIACTIONBAR6BUTTON',Bar8='MULTIACTIONBAR7BUTTON'}
local function Public(v) return not (issecretvalue and issecretvalue(v)) end
local function IsNaga(key) return NAGA[key:match('[^%-]+$') or ''] or NAGA_CHORD[key] end
-- Labels over three characters were cut off on 30-unit buttons ("SM..." for
-- Shift-wheel, audit 2026-10-03): the wheel is WU/WD, and a label that is still
-- long writes its modifiers in narrower lower case so the key stays whole.
local MODIFIERS={CTRL='C',ALT='A',SHIFT='S',META='M'}
function NS.EllesmereKeyboardLabel(key)
    local mods,base='',key
    while true do
        local m,rest=base:match('^(%u+)%-(.+)$')
        if not (m and MODIFIERS[m]) then break end
        mods,base=mods..MODIFIERS[m],rest
    end
    base=base:gsub('MOUSEWHEELUP','WU'):gsub('MOUSEWHEELDOWN','WD'):gsub('BUTTON','M')
        :gsub('INSERT','Ins'):gsub('DELETE','Del'):gsub('CAPSLOCK','Caps')
    local text=mods..base
    if #text>3 then text=mods:lower()..base end
    return text
end
local function KeyboardFirst(command)
    local keys={GetBindingKey(command)}
    local first
    for _,key in ipairs(keys) do
        if Public(key) and type(key)=='string' then
            first=first or key
            if not IsNaga(key) then return key end
        end
    end
    return first
end
function NS.RelabelEllesmereBar(barKey)
    if FHKEllesmereDB and FHKEllesmereDB.keyboardKeyLabels==false then return end
    local ns=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIActionBars
    local prefix=COMMANDS[barKey]
    local buttons=ns and ns.barButtons and ns.barButtons[barKey]
    local p=ns and ns.EAB and ns.EAB.db and ns.EAB.db.profile
    local s=p and p.bars and p.bars[barKey]
    if not prefix or type(buttons)~='table' or (s and s.hideKeybind) then return end
    for i,btn in ipairs(buttons) do
        local hk=btn and btn.HotKey
        local key=hk and KeyboardFirst(prefix..i)
        if key then
            local text=NS.EllesmereKeyboardLabel(key)
            if hk:GetText()~=text then hk:SetText(text) end
        end
    end
end
local relabelHooked
local function HookLabels()
    local ns=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIActionBars
    local eab=ns and ns.EAB
    if relabelHooked or not eab or type(eab.ApplyFontsForBar)~='function' then return end
    hooksecurefunc(eab,'ApplyFontsForBar',function(_,barKey) NS.RelabelEllesmereBar(barKey) end)
    relabelHooked=true
    for key in pairs(COMMANDS) do NS.RelabelEllesmereBar(key) end
end
NS.HookEllesmereKeyboardLabels=HookLabels
driver:RegisterEvent('PLAYER_LOGIN'); driver:RegisterEvent('PLAYER_REGEN_ENABLED')
driver:SetScript('OnEvent',function(_,event)
    if event=='PLAYER_LOGIN' then HookLabels();C_Timer.After(1.5,Initial)
    elseif pending then NS.ApplyEllesmereHunterPolish() end
end)
