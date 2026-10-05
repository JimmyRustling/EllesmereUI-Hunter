-- Cooldown Manager key labels (forum FR28). Ellesmere labels a cooldown icon with the key of
-- the action button holding the spell; a conditional macro ("[mod:ctrl] Aspect of the Hawk;
-- Aspect of the Cheetah") gives every spell in it the macro's bare key. Two fixes, both
-- label-only (bindings are never touched):
--   Macro Modifier Labels: spells cast from Forever Hunter Keys' modifier macros show their
--     exact key (C-X for Hawk on Ctrl+X).
--   Manual labels: /fhkcdm label <spell> = <text>, saved with the Ellesmere profile.
-- Applied by hooking each icon's own keybind text, so Ellesmere's styling, visibility and
-- "Show Keybind" switch stay in charge; an icon Ellesmere shows no key for stays blank.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end
local K={}
NS.CdmLabels=K
local DEFAULTS={macroKeys=true}
function NS.EllesmereCdmLabelSettings()
    if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end
    local s=FHKEllesmereDB.cdmLabels
    if type(s)~='table' then s={};FHKEllesmereDB.cdmLabels=s end
    for k,v in pairs(DEFAULTS) do if s[k]==nil then s[k]=v end end
    if type(s.labels)~='table' then s.labels={} end
    return s
end
local function Plain(v) return not (issecretvalue and issecretvalue(v)) end

-- Spell name -> exact key from FHK's macro groups ({keys = {X, SHIFT-X, CTRL-X, ALT-X}, body}).
local function Short(key)
    if type(key)~='string' then return nil end
    return (key:gsub('CTRL%-','C-'):gsub('SHIFT%-','S-'):gsub('ALT%-','A-'))
end
-- Forever Hunter Keys' action groups live in its own namespace (FHKEllesmereNS.groups
-- is only a fallback for tests and hand-made setups).
local function Groups()
    local fhk=rawget(_G,'ForeverHunterKeysNS')
    if type(fhk)=='table' and type(fhk.groups)=='table' then return fhk.groups end
    return type(NS.groups)=='table' and NS.groups or {}
end
local macroKeys={}
function K.RefreshMacroKeys()
    macroKeys={}
    for _,group in ipairs(Groups()) do
        local body=type(group.body)=='string' and group.body:match('/cast ([^\n]+)')
        if body and type(group.keys)=='table' then
            for clause in body:gmatch('[^;]+') do
                local mod,spell=clause:match('%[mod:(%a+)%]%s*!?(.-)%s*$')
                if not spell then spell=clause:match('^%s*!?([^%[]-)%s*$') end
                if spell and spell~='' then
                    spell=spell:gsub('%s*%(Rank %d+%)','')
                    local prefix=mod and (mod:upper()..'-') or nil
                    for _,bind in ipairs(group.keys) do
                        local plain=not bind:find('-',1,true)
                        if (prefix and bind:sub(1,#prefix)==prefix) or (not prefix and plain) then
                            macroKeys[spell]=macroKeys[spell] or Short(bind)
                            break
                        end
                    end
                end
            end
        end
    end
    return macroKeys
end
function K.LabelFor(spellName)
    if type(spellName)~='string' then return nil end
    local s=NS.EllesmereCdmLabelSettings()
    local own=s.labels[spellName]
    if type(own)=='string' and own~='' then return own end
    if s.macroKeys then return macroKeys[spellName] end
end

-- Hook every Cooldown Manager icon's keybind text once.
local hooked=setmetatable({},{__mode='k'})
local function CDM() return EUI._ModuleNS and EUI._ModuleNS.EllesmereUICooldownManager end
local function SpellOf(icon)
    local cdm=CDM()
    local fc=cdm and cdm._ecmeFC and cdm._ecmeFC[icon]
    local id=fc and fc.spellID
    if not (Plain(id) and type(id)=='number' and id>0) then return nil end
    if not (C_Spell and type(C_Spell.GetSpellName)=='function') then return nil end
    local ok,name=pcall(C_Spell.GetSpellName,id)
    if ok and Plain(name) and type(name)=='string' then return name end
end
local function Relabel(text)
    local state=hooked[text]
    if not state or state.painting then return end
    local label=K.LabelFor(SpellOf(state.icon))
    if not state.hasNative or state.native==nil or state.native=='' then label=state.native
    else label=label or state.native end
    local ok,current=pcall(text.GetText,text)
    if not ok or not Plain(current) or label==nil or current==label then return end
    state.painting=true
    pcall(text.SetText,text,label)
    state.painting=false
end
K.Relabel=Relabel
function K.Discover()
    local cdm=CDM()
    if not (cdm and type(cdm.cdmBarIcons)=='table') then return 0 end
    local count=0
    for _,icons in pairs(cdm.cdmBarIcons) do
        for _,icon in ipairs(type(icons)=='table' and icons or {}) do
            local fd=cdm._hookFrameData and cdm._hookFrameData[icon]
            local text=fd and fd.keybindText or icon._keybindText
            if text and text.SetText then
                if not hooked[text] then
                    local ok,value=pcall(text.GetText,text)
                    hooked[text]={icon=icon,native=ok and Plain(value) and value or nil,hasNative=ok and Plain(value)}
                    hooksecurefunc(text,'SetText',function(_,value)
                        local state=hooked[text]
                        if state.painting then return end
                        state.native=Plain(value) and value or nil;state.hasNative=Plain(value)
                        Relabel(text)
                    end)
                end
                hooked[text].icon=icon
                Relabel(text);count=count+1
            end
        end
    end
    return count
end
local pending
function K.Soon(delay)
    if pending then return end
    if not (C_Timer and C_Timer.After) then K.Discover();return end
    pending=true
    C_Timer.After(delay or 0,function() pending=nil;K.Discover() end)
end
local cdmHooked=false
local function HookCDM()
    local cdm=CDM()
    if cdmHooked or not cdm then return end
    cdmHooked=true
    -- The options page applies through ns.ApplyCachedKeybinds. Ellesmere's own rebuilds call
    -- local functions, but every keybind text passes ns.ShowCDMKeybindBadge: an unhooked one
    -- (a new or rebuilt icon) schedules one discovery pass for the next frame.
    if type(cdm.ApplyCachedKeybinds)=='function' then hooksecurefunc(cdm,'ApplyCachedKeybinds',K.Discover) end
    if type(cdm.ShowCDMKeybindBadge)=='function' then
        hooksecurefunc(cdm,'ShowCDMKeybindBadge',function(text) if text and not hooked[text] then K.Soon(0) end end)
    end
end

local driver
function NS.SyncEllesmereCdmLabels()
    NS.EllesmereCdmLabelSettings()
    K.RefreshMacroKeys();HookCDM()
    if not driver then
        driver=CreateFrame('Frame')
        driver:SetScript('OnEvent',function() K.RefreshMacroKeys();K.Soon(.2) end)
        driver:RegisterEvent('PLAYER_ENTERING_WORLD');driver:RegisterEvent('UPDATE_BINDINGS');driver:RegisterEvent('UPDATE_MACROS')
    end
    K.Discover()
end

SLASH_FHKCDM1='/fhkcdm'
SlashCmdList.FHKCDM=function(msg)
    local s=NS.EllesmereCdmLabelSettings()
    msg=type(msg)=='string' and msg or ''
    local spell,label=msg:match('^%s*label%s+(.-)%s*=%s*(.-)%s*$')
    if spell and spell~='' then
        s.labels[spell]=label~='' and label:sub(1,6) or nil
        print(('FHK: Cooldown label for %s: %s'):format(spell,s.labels[spell] or 'cleared'))
        K.Discover();return
    end
    local clear=msg:match('^%s*clear%s+(.-)%s*$')
    if clear and clear~='' then s.labels[clear]=nil;print('FHK: Cooldown label cleared for '..clear);K.Discover();return end
    print('FHK: /fhkcdm label <spell> = <text>  |  /fhkcdm clear <spell>')
    for name,text in pairs(s.labels) do print('  '..name..' = '..text) end
end

function NS.AddEllesmereCdmLabelOptions(Row)
    local s=NS.EllesmereCdmLabelSettings()
    if _G.ForeverHunterKeysNS==nil then
        Row({type='label',text='Manual label: /fhkcdm label Rapid Fire = S-3'},
            {type='button',text='Clear Manual Labels',onClick=function() s.labels={};K.Discover() end})
        return
    end
    Row({type='toggle',text='Macro Modifier Key Labels',tooltip='Spells cast from Forever Hunter Keys modifier macros show their exact key on cooldown icons, for example C-X for Aspect of the Hawk on Ctrl+X, instead of the macro\'s bare key.',
        getValue=function() return s.macroKeys end,setValue=function(v) s.macroKeys=v;K.Discover() end},
        {type='button',text='Clear Manual Labels',onClick=function() s.labels={};K.Discover() end})
    Row({type='label',text='Manual label: /fhkcdm label Rapid Fire = S-3'},{type='label',text='Bindings are never changed'})
end

local boot=CreateFrame('Frame')
boot:RegisterEvent('PLAYER_LOGIN')
boot:SetScript('OnEvent',function(self) self:UnregisterAllEvents();NS.SyncEllesmereCdmLabels() end)
