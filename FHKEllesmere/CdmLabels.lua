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
    FHKEllesmereDB=FHKEllesmereDB or {}
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
local macroKeys={}
function K.RefreshMacroKeys()
    macroKeys={}
    for _,group in ipairs(type(NS.groups)=='table' and NS.groups or {}) do
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
    local ok,name=pcall(C_Spell.GetSpellName,id)
    if ok and Plain(name) and type(name)=='string' then return name end
end
local function Relabel(text)
    local state=hooked[text]
    if not state or state.painting then return end
    local label=K.LabelFor(SpellOf(state.icon))
    if not label then return end
    local ok,current=pcall(text.GetText,text)
    if ok and current==label then return end
    state.painting=true;text:SetText(label);state.painting=false
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
                    hooked[text]={icon=icon}
                    hooksecurefunc(text,'SetText',Relabel)
                end
                hooked[text].icon=icon
                Relabel(text);count=count+1
            end
        end
    end
    return count
end
local cdmHooked=false
local function HookCDM()
    local cdm=CDM()
    if cdmHooked or not cdm then return end
    cdmHooked=true
    -- The tick loop applies through ns.ApplyCachedKeybinds; catch new icons there.
    if type(cdm.ApplyCachedKeybinds)=='function' then hooksecurefunc(cdm,'ApplyCachedKeybinds',K.Discover) end
    if type(cdm.UpdateCDMKeybinds)=='function' then
        hooksecurefunc(cdm,'UpdateCDMKeybinds',function() if C_Timer and C_Timer.After then C_Timer.After(.05,K.Discover) end end)
    end
end

local driver
function NS.SyncEllesmereCdmLabels()
    NS.EllesmereCdmLabelSettings()
    K.RefreshMacroKeys();HookCDM()
    if not driver then
        driver=CreateFrame('Frame')
        driver:SetScript('OnEvent',function() K.RefreshMacroKeys();if C_Timer and C_Timer.After then C_Timer.After(.2,K.Discover) else K.Discover() end end)
        driver:RegisterEvent('PLAYER_ENTERING_WORLD');driver:RegisterEvent('UPDATE_BINDINGS')
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
    Row({type='toggle',text='Macro Modifier Key Labels',tooltip='Spells cast from Forever Hunter Keys modifier macros show their exact key on cooldown icons, for example C-X for Aspect of the Hawk on Ctrl+X, instead of the macro\'s bare key.',
        getValue=function() return s.macroKeys end,setValue=function(v) s.macroKeys=v;K.Discover() end},
        {type='button',text='Clear Manual Labels',onClick=function() s.labels={};K.Discover() end})
    Row({type='label',text='Manual label: /fhkcdm label Rapid Fire = S-3'},{type='label',text='Bindings are never changed'})
end

local boot=CreateFrame('Frame')
boot:RegisterEvent('PLAYER_LOGIN')
boot:SetScript('OnEvent',function(self) self:UnregisterAllEvents();NS.SyncEllesmereCdmLabels() end)
