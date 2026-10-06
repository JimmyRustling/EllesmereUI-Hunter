-- Companion options: native sections on 9.3.4 suite pages, or (9.3.5+) a RegisterPlugin section of our own.
local ADDON = ...
local EUI, NS = _G.EllesmereUI, _G.FHKEllesmereNS
if not EUI or not NS or EUI_CLIENT_BLOCKED then return end
if type(ADDON) ~= 'string' then ADDON = 'FHKEllesmere' end
local driver = CreateFrame('Frame')
local wrapped = setmetatable({}, {__mode='k'})
local function DB() if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end; return FHKEllesmereDB end
local function Toggle(text, key, inverted)
    return {type='toggle',text=text,getValue=function()
        return inverted and DB()[key] == true or not inverted and DB()[key] ~= false
    end,setValue=function(v)
        DB()[key]=v
        if (key=='healthTextColors' or key=='resourceTextColors') and v==false and NS.RestoreEllesmereNativeText then
            NS.RestoreEllesmereNativeText()
        end
        if key:find('^rarity') and _G.EllesmereNameplates_NS and _G.EllesmereNameplates_NS.RefreshAllSettings then
            _G.EllesmereNameplates_NS.RefreshAllSettings()
        end
    end}
end
-- Advanced rows (audit F47): an options-window preference, kept per character.
local function ShowAdvanced() return rawget(DB(),'advancedOptions')==true end
local function SetAdvanced(on)
    rawset(DB(),'advancedOptions',on and true or false)
    if EUI.InvalidatePageCache then EUI:InvalidatePageCache() end
    if EUI.RefreshPage then EUI:RefreshPage(true) end
end
NS.SetEllesmereAdvancedOptions=SetAdvanced
-- One setting shown on two pages: say so (audit F09).
local function Shared(cfg, other)
    cfg.tooltip = (cfg.tooltip and cfg.tooltip .. ' ' or '') .. 'Shared setting: also changes ' .. other .. '.'
    return cfg
end
-- Renders one companion section with native widgets. Fine-tuning rows are tagged
-- 'advanced' and stay hidden until the player asks for them (audit F47).
-- Player report: switching a toggle on (Aspect Element, Pet Auras) left the options under
-- it greyed out until the tab was changed. Ellesmere's own rows call RefreshPage after a
-- change, which re-reads every row's value and disabled state in place; every companion
-- toggle, dropdown and button now does the same.
local LIVE={toggle=true,checkbox=true,dropdown=true}
local function Live(cfg)
    if type(cfg)~='table' or cfg.fhkLive then return cfg end
    local key=LIVE[cfg.type] and 'setValue' or cfg.type=='button' and 'onClick' or nil
    local fn=key and cfg[key]
    if type(fn)~='function' then return cfg end
    cfg[key]=function(...)
        -- A button that navigated away has nothing to refresh (review P7): refreshing the new
        -- page would rebuild it a second time.
        local function Where()
            local m=type(EUI.GetActiveModule)=='function' and EUI:GetActiveModule()
            local p=type(EUI.GetActivePage)=='function' and EUI:GetActivePage()
            return m,p
        end
        local m,p=Where()
        local a,b=fn(...)
        local m2,p2=Where()
        if EUI.RefreshPage and m==m2 and p==p2 then pcall(EUI.RefreshPage,EUI) end
        return a,b
    end
    cfg.fhkLive=true
    return cfg
end
NS.EllesmereLiveRow=Live
-- Ellesmere's inline row tools (player: "ellesmere uses cogs for settings, multidirectional
-- arrows for text size, an eye for previews; get those into our UI"). A row half may carry:
--   swatches = {{tooltip,getValue,setValue,hasAlpha}, ...}  inline colour swatches
--   move     = {title, rows={cog rows}}  position cog with Ellesmere's directions icon
--   cog      = {title, rows={cog rows}}  settings cog
--   preview  = {tip, show=fn(), hide=fn() or duration}  eye that previews the element
-- They are built in Ellesmere's order (swatches, then move/cog, then the eye, each further
-- left), share the half's disabled state and explain it the same way. Cog rows use the native
-- popup ({type='slider'|'toggle'|'dropdown'|'colorpicker', label, get, set, ...}).
local function Eye(region,cfg)
    local p=cfg.preview
    local visible,invisible=EUI.EYE_VISIBLE_ICON,EUI.EYE_INVISIBLE_ICON
    if not (visible and invisible) then return end
    local off=type(p.disabled)=='function' and p.disabled or type(cfg.disabled)=='function' and cfg.disabled or nil
    local tip=p.disabledTooltip or cfg.disabledTooltip
    local shown,token=false,0
    local btn=CreateFrame('Button',nil,region)
    btn:SetSize(26,26)
    btn:SetPoint('RIGHT',region._lastInline or region._control or region,'LEFT',-8,0)
    region._lastInline=btn
    btn:SetFrameLevel(region:GetFrameLevel()+5)
    local tex=btn:CreateTexture(nil,'OVERLAY');tex:SetAllPoints()
    local function Paint()
        tex:SetTexture(shown and invisible or visible)
        btn:SetAlpha(off and off() and .15 or (btn:IsMouseOver() and .7 or .4))
    end
    local function Set(on)
        shown=on;token=token+1;Paint()
        if on then
            if p.show then pcall(p.show) end
            -- A one-shot preview flips back by itself.
            if not p.hide and C_Timer and C_Timer.After then
                local mine=token
                C_Timer.After(p.duration or 3,function() if mine==token then shown=false;Paint() end end)
            end
        elseif p.hide then pcall(p.hide) end
    end
    btn:SetScript('OnEnter',function(self) self:SetAlpha(.7);if EUI.ShowWidgetTooltip then EUI.ShowWidgetTooltip(self,p.tip or 'Preview') end end)
    btn:SetScript('OnLeave',function() if EUI.HideWidgetTooltip then EUI.HideWidgetTooltip() end;Paint() end)
    btn:SetScript('OnClick',function() Set(not shown) end)
    local block=CreateFrame('Frame',nil,btn);block:SetAllPoints();block:SetFrameLevel(btn:GetFrameLevel()+10);block:EnableMouse(true)
    block:SetScript('OnEnter',function()
        if EUI.ShowWidgetTooltip and tip then EUI.ShowWidgetTooltip(btn,EUI.DisabledTooltip and EUI.DisabledTooltip(tip) or tip) end
    end)
    block:SetScript('OnLeave',function() if EUI.HideWidgetTooltip then EUI.HideWidgetTooltip() end end)
    local function Refresh()
        local disabled=off and off() or false
        block:SetShown(disabled)
        if disabled and shown then Set(false) end
        Paint()
    end
    Refresh()
    if EUI.RegisterWidgetRefresh then EUI.RegisterWidgetRefresh(Refresh) end
    return btn
end
local OPEN_ICON='Interface\\AddOns\\EllesmereUI\\media\\icons\\eui-open.png'
local function Extras(row,side,cfg)
    if type(cfg)~='table' or not (cfg.swatches or cfg.move or cfg.cog or cfg.preview or cfg.link) then return end
    if EUI._prebuilding or type(row)~='table' then return end
    local region=row[side]
    if type(region)~='table' then return end
    local disabled,tip=cfg.disabled,cfg.disabledTooltip
    if cfg.swatches and EUI.BuildInlineSwatches then
        pcall(EUI.BuildInlineSwatches,region,cfg.swatches,{disabled=disabled,disabledTooltip=tip})
    end
    for _,kind in ipairs({'move','cog'}) do
        local o=cfg[kind]
        if type(o)=='table' and EUI.BuildInlineCog then
            local spec={}
            for k,x in pairs(o) do spec[k]=x end
            if kind=='move' then spec.icon=EUI.DIRECTIONS_ICON;spec.gap=9 end
            spec.disabled=spec.disabled or disabled
            if spec.disabled then spec.disabledTooltip=spec.disabledTooltip or tip or cfg.text end
            pcall(EUI.BuildInlineCog,region,spec)
        end
    end
    if type(cfg.preview)=='table' then pcall(Eye,region,cfg) end
    -- Hunter hub rows: the open icon goes to the section where the feature lives.
    if type(cfg.link)=='table' and EUI.BuildInlineCog then
        pcall(EUI.BuildInlineCog,region,{icon=OPEN_ICON,gap=9,tip='Open '..tostring(cfg.link.section or cfg.link.page),
            show=function() if NS.OpenEllesmereCompanionSection then NS.OpenEllesmereCompanionSection(cfg.link) end end})
    end
end
NS.EllesmereRowExtras=Extras
local function RenderSection(W, header, parent, v, y)
    -- The header waits for the first row, so a section with nothing to show
    -- (AutoGear not installed, for example) leaves no empty title behind.
    local titled
    local function Title()
        if titled then return end
        titled=true
        local _,h=header(W,parent,v.title,y); y=y-h
    end
    local hidden=0
    v.builder(function(left,right,advanced)
        if advanced and not ShowAdvanced() then hidden=hidden+1;return nil end
        Title()
        local row,height=W:DualRow(parent,y,Live(left),Live(right)); y=y-height
        Extras(row,'_leftRegion',left);Extras(row,'_rightRegion',right)
        return row
    end)
    if hidden>0 then
        Title()
        local _,height=W:DualRow(parent,y,{type='label',text=hidden..' advanced '..(hidden==1 and 'row' or 'rows')..' hidden'},
            {type='button',text='Show Advanced Options',onClick=function() SetAdvanced(true) end})
        y=y-height
    end
    return y
end

-- Ellesmere 9.3.5+ seals its own pages from outside addons and offers
-- RegisterPlugin instead: there the companion gets its own sidebar section,
-- one page per suite module it refines. 9.3.4 keeps the in-page sections.
local PLUGIN_ID='FHKForever'
local PLUGIN_PAGES={'Class','General','Action Bars','Unit Frames','Nameplates','Resource Bars','Warnings'}
local PLUGIN_PAGE_FOR={EllesmereUIActionBars='Action Bars',EllesmereUIUnitFrames='Unit Frames',
    EllesmereUINameplates='Nameplates',EllesmereUIResourceBars='Resource Bars',EllesmereUIQoL='Warnings'}
local pluginSections,pluginRegistered={},false
local function PluginMode() return type(EUI.RegisterPlugin)=='function' end
NS.EllesmereOptionsPluginMode=PluginMode
-- Options follow the logged-in character's class (player, 2026-10-06: "hide irrelevant
-- options from their class"). A class never changes in a session, so the gate is read
-- when sections register. Sections not listed show for every class.
local function PlayerClass() local ok,_,class=pcall(UnitClass,'player');return ok and class or nil end
NS.EllesmerePlayerClass=PlayerClass
local PET_CLASSES={HUNTER=true,WARLOCK=true}
local SECTION_CLASSES={
    ['ASPECTS']={HUNTER=true},['PET FOOD']={HUNTER=true},['HUNTER CUES']=PET_CLASSES,
    ['HUNTER RANGE AND CORPSES']={HUNTER=true},['HUNTER TIMING COMPATIBILITY']={HUNTER=true},
    ['AUTO ATTACK INDICATORS']={HUNTER=true},['REVIEWED HUNTER CUES']={HUNTER=true},
    ['PET AURAS AND TARGET']=PET_CLASSES,['PETS AND SUMMONS']=PET_CLASSES,['PET CUES']=PET_CLASSES,
    -- class kits: each section only where its class has the feature
    ['CLASS BUFFS']={PALADIN=true,PRIEST=true,MAGE=true,WARLOCK=true,SHAMAN=true,DRUID=true,WARRIOR=true},
    ['CLASS SUPPLIES']={WARLOCK=true,SHAMAN=true,ROGUE=true,MAGE=true,PALADIN=true,PRIEST=true,DRUID=true},
    ['BEHIND INDICATOR']={ROGUE=true,DRUID=true},['ENERGY TICK']={ROGUE=true,DRUID=true},
    ['CLASS CUES']={ROGUE=true,DRUID=true,WARRIOR=true},
}
local function SectionAllowed(title)
    local set=SECTION_CLASSES[title]
    if not set then return true end
    local class=PlayerClass()
    -- An unreadable class keeps every section, so nothing is lost on a client fault.
    return class==nil or set[class]==true
end
NS.EllesmereSectionAllowed=SectionAllowed
-- Shared sections named for the hunter keep a class-neutral title on other classes.
-- Warlocks keep the pet cues (player, 2026-10-06: "warlocks have pets so some options are applicable").
local NEUTRAL_TITLES={['HUNTER WARNINGS']='WARNINGS',['HUNTER COLORS']='CUE COLORS',['HUNTER CUES']='PET CUES'}
local function ClassTitle(title)
    local class=PlayerClass()
    if class==nil or class=='HUNTER' then return title end
    return NEUTRAL_TITLES[title] or title
end
NS.EllesmereClassSectionTitle=ClassTitle
local function QueuePluginSection(module,title,builder)
    local page=PLUGIN_PAGE_FOR[module] or 'General'
    local list=pluginSections[page] or {};pluginSections[page]=list
    for _,v in ipairs(list) do if v.title==title then return end end
    list[#list+1]={title=title,builder=builder}
end
local function BuildPluginPage(page,parent,offset)
    local W=EUI.Widgets
    local y=offset or 0
    if not W then return math.abs(y) end
    for _,v in ipairs(pluginSections[page] or {}) do y=RenderSection(W,W.SectionHeader,parent,v,y) end
    return math.abs(y)
end
NS.BuildEllesmerePluginPage=BuildPluginPage
-- Hunter hub (player, 2026-10-06: "hunter specifics should be under a hunter tab"; chosen: a
-- hub with each feature's toggle and a link to its full settings, which stay where the
-- element lives). Rows are the features' own option rows, read from their sections when
-- the page builds, so the hub stores nothing and always matches the full sections.
local HUNTER_HUB={
    {'RANGE AND DEAD ZONE',{
        {'Resource Bars','RANGE INDICATOR','Range Indicator'},{'Resource Bars','RANGE INDICATOR','Range Bracket Preset'},
        {'Nameplates','HUNTER RANGE AND CORPSES','Range Cue Preset'},{'Unit Frames','RANGE BAR','Unit Frame Range Bar'},
        {'Resource Bars','RANGE INDICATOR','Facing Failure Cue'},{'Resource Bars','RANGE INDICATOR','Line Of Sight / Movement Failure Cue'},
        {'Warnings','LEVELING HELPERS','Target Range Fade'}}},
    {'SHOOTING AND WEAVING',{
        {'Resource Bars','AUTO ATTACK INDICATORS','Auto Attack Indicators'},{'Warnings','HUNTER CUES','Mongoose Bite / Counterattack Glow'},
        {'Warnings','HUNTER CUES','Rapid Killing Proc'},{'Warnings','HUNTER CUES','Stop Attack On Your Crowd Control'},
        {'Warnings','HUNTER CUES','Not Shooting'}}},
    {'ASPECTS',{
        {'Unit Frames','ASPECTS','Aspect Element'},{'Unit Frames','ASPECTS','Aspect Visibility'},
        {'Unit Frames','ASPECTS','Travel Advice'},{'Warnings','HUNTER WARNINGS','Cheetah / Pack Combat Warning'}}},
    {'PET: HEALTH AND STATE',{
        {'Warnings','HUNTER WARNINGS','Missing / Dead Pet In Combat'},{'Warnings','HUNTER WARNINGS','Mend Pet Reminder'},
        {'Warnings','HUNTER WARNINGS','Pet Too Far To Mend'},{'Warnings','HUNTER CUES','Pet Idle'},
        {'Unit Frames','PET AURAS AND TARGET','Pet Auras'},{'Unit Frames','PET AURAS AND TARGET','Pet Target'},
        {'Unit Frames','COLOUR AND TEXT REFINEMENTS','Pet Combat Icon'},{'Warnings','HUNTER CUES','Growl Reminder'},
        {'Unit Frames','PETS AND SUMMONS','Pets And Summons Bar'},{'Unit Frames','PETS AND SUMMONS','Summon Hawk Button'},
        {'Warnings','HUNTER WARNINGS','Pet On Passive Warning'},{'Warnings','HUNTER WARNINGS','Pet Level Warning'}}},
    {'PET: HAPPINESS, FOOD AND GROWTH',{
        {'Unit Frames','COLOUR AND TEXT REFINEMENTS','Pet Happiness Icon'},{'Warnings','HUNTER WARNINGS','Feed Pet Reminder'},
        {'Unit Frames','PET FOOD','Feeding View'},{'Warnings','HUNTER WARNINGS','Pet Food Warning'},
        {'Unit Frames','PET FOOD','Pet Food Button'},
        {'Unit Frames','PET AURAS AND TARGET','Pet XP Bar'}}},
    {'COMBAT CUES',{
        {'Warnings','HUNTER CUES','Feign Death Warnings'},{'Warnings','HUNTER CUES','Trap Broken'},
        {'Warnings','HUNTER WARNINGS','Frenzy: Tranquilizing Shot'},{'Warnings','HUNTER CUES',"Hunter's Mark On Elites"},
        {'Warnings','HUNTER CUES','Trueshot Aura Missing'},{'Unit Frames','COLOUR AND TEXT REFINEMENTS','Gold Target of Target on You'},
        {'Unit Frames','COLOUR AND TEXT REFINEMENTS','Flee Mark'}}},
    {'AMMO, TRACKING AND LEVELING',{
        {'Warnings','HUNTER WARNINGS','Low Ammo Warning'},
        {'Warnings','HUNTER CUES','Tracking Reminder'},{'Warnings','LEVELING HELPERS','Gathering Tracking Reminder'},
        {'Warnings','HUNTER CUES','Beast Tooltip'},{'Warnings','LEVELING HELPERS','Loot Left Behind'},
        {'Warnings','LEVELING HELPERS','Zone Levels On Map'}}},
}
-- Every class page ends with the shared restock, training and alert rows. A 4th field marks a
-- row only some classes have (drink, reagents, ammo, pet food): it is skipped quietly elsewhere.
local SHARED_HUB={
    {'VENDOR RESTOCK',{
        {'Warnings','VENDOR RESTOCK','Auto-Buy Food'},{'Warnings','VENDOR RESTOCK','Auto-Buy Drink',true},
        {'Warnings','VENDOR RESTOCK','Auto-Buy Class Reagents',true},{'Warnings','VENDOR RESTOCK','Auto-Buy Ammo',true},
        {'Warnings','VENDOR RESTOCK','Auto-Buy Pet Food',true},{'Warnings','VENDOR RESTOCK','Max Spend Per Visit'}}},
    {'TRAINING AND TALENTS',{
        {'Warnings','TRAINING','Auto Train'},{'Warnings','TRAINING','Open Trainer From Conversation'},
        {'Warnings','TRAINING','Talent Planner'},{'Warnings','TRAINING','Learn Planned Talents'},
        {'Warnings','HUNTER WARNINGS','Unspent Talent Warning'},{'Warnings','NEW SPELLS','New Spell Alerts'},
        {'Warnings','NEW SPELLS','List New Spells In Chat'}}},
    {'ALERTS',{
        {'Warnings','HUNTER WARNINGS','Top Alert Lane'},{'Warnings','HUNTER WARNINGS','Combat Warnings Above Character'},
        {'Warnings','HUNTER WARNINGS','Hide Spam Errors'},{'Warnings','HUNTER WARNINGS','Hide Errors A Warning Shows'},
        {'Warnings','HUNTER WARNINGS','Warning Text Style'}}},
}
-- Class hub page (player, 2026-10-06: class kits for every class). The page is named after
-- the player's class; each class lists its own groups, then the shared ones. Rows a build
-- does not offer (another class, an older core) are skipped when the page builds.
local CB,WE,CS,CC={'Unit Frames','CLASS BUFFS'},{'Unit Frames','WEAPON ENCHANTS'},{'Warnings','CLASS SUPPLIES'},{'Warnings','CLASS CUES'}
local BI,ET={'Resource Bars','BEHIND INDICATOR'},{'Resource Bars','ENERGY TICK'}
local function R(at,label) return {at[1],at[2],label} end
local BUFF_ROWS={R(CB,'Class Buff Bar'),R(CB,'Class Buff Bar Visibility'),R(CB,'Missing / Expiring Cues'),R(CB,'Cue Sound')}
local SUPPLY_ROWS={R(CS,'Class Supplies'),R(CS,'Supplies Visibility'),R(CS,'Supply Warnings'),R(CS,'Supply Warning Sound')}
local CLASS_HUB={HUNTER={title='HUNTER',page='Hunter',groups=HUNTER_HUB},
    WARRIOR={groups={{'SHOUT AND WEAPON',{R(CB,'Class Buff Bar'),R(CB,'Missing / Expiring Cues'),R(WE,'Weapon Enchants'),R(WE,'Weapon Enchant Visibility')}},
        {'STANCES AND REACTIONS',{R(CC,'Wrong Stance Cue'),R(CC,'Reactive Ability Glow'),R(CC,'Stance Mismatch Hint')}}}},
    PALADIN={groups={{'AURAS, SEALS AND BLESSINGS',{R(CB,'Class Buff Bar'),R(CB,'Class Buff Bar Visibility'),R(CB,'Missing / Expiring Cues'),
        R(CB,'Preferred Blessing'),R(CB,'Righteous Fury Cue'),R(CB,'Seals Cue')}},{'SYMBOLS AND WEAPON',{R(CS,'Class Supplies'),R(CS,'Supply Warnings'),R(WE,'Weapon Enchants')}}}},
    ROGUE={groups={{'POISONS',{R(WE,'Weapon Enchants'),R(WE,'Weapon Enchant Visibility'),R(WE,'Main Hand Poison'),R(WE,'Off Hand Poison'),
        R(WE,'Missing Enchant Cue'),R(WE,'Expiring Cue')}},
        {'POSITION AND OPENERS',{R(BI,'Behind Indicator'),R(CC,'Stealth First Cue'),R(CC,'Must Be Behind Cue'),R(CC,'Stealth Opener Cue')}},
        {'COMBAT',{R(CC,'Riposte Glow'),R(CC,'Slice And Dice Cue'),R(ET,'Energy Tick Spark')}},{'SUPPLIES',SUPPLY_ROWS}}},
    PRIEST={groups={{'BUFFS',BUFF_ROWS},{'CANDLES AND FEATHERS',SUPPLY_ROWS},{'WAND AND WEAPON',{R(WE,'Weapon Enchants')}}}},
    MAGE={groups={{'ARMOR AND INTELLECT',BUFF_ROWS},{'CONJURES AND RUNES',SUPPLY_ROWS}}},
    WARLOCK={groups={{'DEMONS',{{'Unit Frames','PETS AND SUMMONS','Pets And Summons Bar'},{'Unit Frames','PET AURAS AND TARGET','Pet Auras'},
        {'Unit Frames','PET AURAS AND TARGET','Pet Target'},{'Unit Frames','COLOUR AND TEXT REFINEMENTS','Pet Combat Icon'},
        {'Warnings','HUNTER WARNINGS','Missing / Dead Pet In Combat'},{'Warnings','HUNTER WARNINGS','Pet On Passive Warning'},
        {'Warnings','HUNTER WARNINGS','Health Funnel Reminder'},{'Warnings','HUNTER CUES','Pet Idle'}}},
        {'ARMOR',BUFF_ROWS},{'SHARDS AND STONES',{R(CS,'Class Supplies'),R(CS,'Supplies Visibility'),R(CS,'Soulstone Timer'),R(CS,'Soul Bag Full Warning'),R(WE,'Weapon Enchants')}}}},
    SHAMAN={groups={{'SHIELDS AND IMBUES',{R(CB,'Class Buff Bar'),R(CB,'Missing / Expiring Cues'),R(WE,'Weapon Enchants'),R(WE,'Preferred Imbue'),R(WE,'Missing Enchant Cue')}},
        {'ANKH AND REAGENTS',SUPPLY_ROWS}}},
    DRUID={groups={{'BUFFS (CASTER FORM)',BUFF_ROWS},
        {'CAT FORM',{R(BI,'Behind Indicator'),R(ET,'Energy Tick Spark'),R(CC,'Prowl First Cue'),R(CC,'Prowl Opener Cue'),R(CC,'Must Be Behind Cue'),R(CC,'Leave Form Cue')}},
        {'SEEDS AND HERBS',SUPPLY_ROWS}}},
}
local function HubGroups(hub)
    local groups={}
    for _,g in ipairs(hub.groups or {}) do groups[#groups+1]=g end
    for _,g in ipairs(SHARED_HUB) do groups[#groups+1]=g end
    return groups
end
-- The set "Turn On Recommended" switches on: companion keys only, each the hub row's own toggle.
local RECOMMENDED={['Mend Pet Reminder']=true,['Missing / Dead Pet In Combat']=true,['Feed Pet Reminder']=true,
    ['Pet Food Warning']=true,['Cheetah / Pack Combat Warning']=true,['Stop Attack On Your Crowd Control']=true,
    ['Feign Death Warnings']=true,['Trap Broken']=true,['Pet Idle']=true,['Growl Reminder']=true,['Aspect Element']=true,
    ['Pet Auras']=true,['Pet Target']=true,['Pet XP Bar']=true,['Pet Happiness Icon']=true,['Top Alert Lane']=true,
    ['Combat Warnings Above Character']=true,['Hide Spam Errors']=true,['Low Ammo Warning']=true,['Unspent Talent Warning']=true,
    ['Range Indicator']=true,['Auto Attack Indicators']=true,['Facing Failure Cue']=true}
-- One section's rows, by label, from its own builder. Builders only describe rows here.
local function Harvest(page,section)
    local out={}
    for _,v in ipairs(pluginSections[page] or {}) do
        if v.title==section then
            pcall(v.builder,function(left,right)
                if type(left)=='table' and left.text then out[left.text]=left end
                if type(right)=='table' and right.text then out[right.text]=right end
            end)
        end
    end
    return out
end
-- Hub labels a page build could not find (a renamed row): read by the standalone test.
local hubMissing={}
function NS.EllesmereHubMissing() return hubMissing end
local function HubRows(items)
    local cache,rows={}, {}
    for _,item in ipairs(items) do
        local page,section,label=item[1],ClassTitle(item[2]),item[3]
        local key=page..'|'..section
        cache[key]=cache[key] or Harvest(page,section)
        local cfg=cache[key][label]
        if cfg then
            local copy={}
            for k,v in pairs(cfg) do copy[k]=v end
            copy.link={page=page,section=section,row=label}
            rows[#rows+1]=copy
        elseif not item[4] and pluginSections[page] and SectionAllowed(item[2]) then
            -- Only a section that exists here can be missing a row (other classes skip theirs).
            for _,v in ipairs(pluginSections[page]) do if v.title==section then hubMissing[page..' > '..section..' > '..label]=true end end
        end
    end
    return rows
end
-- Turn On remembers each row's previous value (per character); Undo puts exactly those back, so a
-- shared feature that was already on (Low Ammo, the alert lane) is never forced off (review R3-1).
local function SetRecommended(on)
    if type(FHKEllesmereDB)~='table' then return end
    local before=FHKEllesmereDB.hunterSetBefore
    if not on and type(before)~='table' then
        print('FHK: nothing to undo: Turn On Recommended Hunter Set has not been used on this character.')
        return
    end
    local saved=on and (type(before)=='table' and before or {}) or nil
    for _,group in ipairs(HubGroups(CLASS_HUB.HUNTER)) do
        for _,cfg in ipairs(HubRows(group[2])) do
            if RECOMMENDED[cfg.text] and cfg.type=='toggle' and type(cfg.getValue)=='function' and type(cfg.setValue)=='function' then
                local ok,current=pcall(cfg.getValue)
                if ok then
                    current=current and true or false
                    if on then
                        if saved[cfg.text]==nil then saved[cfg.text]=current end
                        if not current then pcall(cfg.setValue,true) end
                    elseif type(before[cfg.text])=='boolean' and before[cfg.text]~=current then pcall(cfg.setValue,before[cfg.text]) end
                end
            end
        end
    end
    FHKEllesmereDB.hunterSetBefore=saved
    if EUI.RefreshPage then pcall(EUI.RefreshPage,EUI) end
    print(on and 'FHK: Recommended Hunter set turned on. Undo puts each setting back as it was.' or 'FHK: Recommended Hunter set undone: each setting is back as it was.')
end
NS.SetEllesmereRecommendedHunterSet=SetRecommended
function NS.OpenEllesmereCompanionSection(link)
    if type(link)~='table' then return end
    local key=EUI.GetPluginModuleKey and EUI.GetPluginModuleKey(PLUGIN_ID,'companion')
    if key and EUI.NavigateToElementSettings then
        EUI:NavigateToElementSettings(key,link.page,link.section,nil,link.row)
    elseif EUI.OpenPlugin then EUI.OpenPlugin(PLUGIN_ID,'companion',link.page) end
end
local function ClassHubSections(hub)
    local list={}
    for _,group in ipairs(HubGroups(hub)) do
        list[#list+1]={title=group[1],builder=function(Row)
            local rows=HubRows(group[2])
            if #rows==0 then Row({type='label',text='Nothing here on this build'},EUI.BlankRowCfg and EUI.BlankRowCfg() or {type='label',text=''}) end
            for i=1,#rows,2 do Row(rows[i],rows[i+1] or (EUI.BlankRowCfg and EUI.BlankRowCfg() or {type='label',text=''})) end
        end}
    end
    return list
end
local function HubSections()
    local list={{title='HUNTER',builder=function(Row)
        Row({type='button',text='Turn On Recommended Hunter Set',
            tooltip='Turns on the pet, aspect, range and combat warnings most hunters want. Only companion settings change; two of them (Hide Spam Errors, Hide Errors A Warning Shows) filter the game\'s red error text.',
            onClick=function() SetRecommended(true) end},
            {type='button',text='Undo Recommended Hunter Set',tooltip='Puts each of those settings back to how it was before Turn On. Settings you changed since stay as you set them only if Turn On had not touched them.',
            disabled=function() return type(FHKEllesmereDB)~='table' or type(FHKEllesmereDB.hunterSetBefore)~='table' end,disabledTooltip='Turn On Recommended Hunter Set',
            onClick=function() SetRecommended(false) end})
        Row({type='label',text='Each row is the feature itself; the open icon goes to all of its settings'},EUI.BlankRowCfg and EUI.BlankRowCfg() or {type='label',text=''})
    end}}
    for _,group in ipairs(HubGroups(CLASS_HUB.HUNTER)) do
        list[#list+1]={title=group[1],builder=function(Row)
            local rows=HubRows(group[2])
            for i=1,#rows,2 do Row(rows[i],rows[i+1] or (EUI.BlankRowCfg and EUI.BlankRowCfg() or {type='label',text=''})) end
        end}
    end
    return list
end
local CLASS_PAGE_NAMES={WARRIOR='Warrior',PALADIN='Paladin',HUNTER='Hunter',ROGUE='Rogue',PRIEST='Priest',
    SHAMAN='Shaman',MAGE='Mage',WARLOCK='Warlock',DRUID='Druid'}
-- The class page: the hunter keeps its recommended-set header; every class gets its groups
-- and the shared ones. Returns the page name, or nil for an unreadable class.
local function ClassPage()
    local class=PlayerClass()
    local name=class and CLASS_PAGE_NAMES[class]
    if not name then return nil end
    if not pluginSections[name] then
        pluginSections[name]=class=='HUNTER' and HubSections() or ClassHubSections(CLASS_HUB[class] or {})
    end
    return name
end
NS.EllesmereClassHubPage=function() return PlayerClass() and CLASS_PAGE_NAMES[PlayerClass()] end
local function RegisterPluginPages()
    if pluginRegistered or not PluginMode() or not next(pluginSections) then return end
    local classPage=ClassPage()
    local pages={}
    for _,page in ipairs(PLUGIN_PAGES) do
        if page=='Class' then page=classPage end
        if page and pluginSections[page] then pages[#pages+1]=page end
    end
    local ok,registered=pcall(EUI.RegisterPlugin,PLUGIN_ID,{label='Forever Companion',position='bottom',modules={{
        key='companion',title='Forever Companion',
        description='Range, colors, warnings, history and Hunter refinements for the Ellesmere suite.',
        pages=pages,buildPage=BuildPluginPage,
        -- The suite's own Reset buttons are sealed from outside addons; this one
        -- resets every companion setting on the active profile.
        onReset=function()
            for folder in pairs(NS.EllesmereResetKeys or {}) do
                if NS.ResetEllesmereCompanionFor then NS.ResetEllesmereCompanionFor(folder) end
            end
            if NS.SyncEllesmereProfileFeatures then NS.SyncEllesmereProfileFeatures() end
        end}}})
    pluginRegistered=ok and registered==true
end

-- With the local core patch's options-extension API (Ellesmere-Core-Patch F40),
-- companion settings are reachable from the Ellesmere pages they refine:
-- the theme presets sit on Global Settings > Style (player request), and each
-- refined page ends with a button to its Forever Companion page. Extension rows
-- are copied once, so only live-reading controls are placed natively; profile-
-- scoped tables stay on the plugin pages, which rebuild on every visit.
local NATIVE_LINKS={
    {'_EUIGlobal','General','General'},
    {'EllesmereUIActionBars','XP Bar','Action Bars'},
    {'EllesmereUIActionBars','Bar Animations','Action Bars'},
    {'EllesmereUIUnitFrames','Main Frames','Unit Frames'},
    {'EllesmereUINameplates','Display','Nameplates'},
    {'EllesmereUINameplates','General','Nameplates'},
    {'EllesmereUIResourceBars','Class, Power and Health Bars','Resource Bars'},
    {'EllesmereUIChat','Chat','General'},
    {'EllesmereUIQoL','QoL','Warnings'},
}
local nativeDone,themesNative={},false
local function RegisterNative()
    if not PluginMode() or type(EUI.RegisterOptionsExtension)~='function' then return end
    local global=EUI.GLOBAL_KEY or '_EUIGlobal'
    if not nativeDone.themes and NS.GetEllesmereThemePreset and NS.ApplyEllesmereThemePreset then
        local function Apply(key)
            local ok,message=NS.ApplyEllesmereThemePreset(key);if not ok and message then print('FHK: '..message) end
        end
        local rows={
                {id='darkMode',type='toggle',text='Dark Mode',
                    tooltip='Applies the Dark preset to health and resource bars across the suite. Off restores your previous look.',
                    getValue=function() return NS.GetEllesmereThemePreset()=='dark' end,
                    setValue=function(v) Apply(v and 'dark' or 'current') end,
                    disabled=function() return EUI.IsColorEditingLocked and EUI.IsColorEditingLocked() or false end,
                    disabledTooltip='Select The Palette Source Profile'},
                {id='preset',type='dropdown',text='Forever Theme Preset',
                    values={current='Original / Restore',coloured='Colored',dark='Dark',afterglow='Afterglow'},
                    order={'current','coloured','dark','afterglow'},
                    tooltip='Colored, Dark and Afterglow looks for the whole suite. Layout and keybinds stay as set.',
                    getValue=function() return NS.GetEllesmereThemePreset() end,setValue=Apply,
                    disabled=function() return EUI.IsColorEditingLocked and EUI.IsColorEditingLocked() or false end,
                    disabledTooltip='Select The Palette Source Profile'},
                {id='restore',type='labeledButton',text='Restore Original Look',buttonText='Restore',
                    onClick=function() Apply('current') end},
            }
        if NS.AddEllesmereThemeDetailOptions then
            NS.AddEllesmereThemeDetailOptions(function(left,right)
                -- Keep appearance pairs together, with Restore on the last row.
                table.insert(rows,#rows,left);table.insert(rows,#rows,right)
            end)
        end
        local ok=EUI.RegisterOptionsExtension(ADDON,'themePresets',{module=global,page='Style',point='page.end'},{{
            id='themes',title='FOREVER THEME PRESETS',rows=rows}})
        if ok then
            nativeDone.themes,themesNative=true,true
            -- One home for the presets: drop the copy queued for the plugin page.
            for _,list in pairs(pluginSections) do
                for i=#list,1,-1 do if list[i].title=='FOREVER THEME PRESETS' then table.remove(list,i) end end
            end
        end
    end
    for i,link in ipairs(NATIVE_LINKS) do
        if not nativeDone[i] then
            local module,page,target=link[1],link[2],link[3]
            if module=='_EUIGlobal' then module=global end
            local rows={{id='open',type='labeledButton',text='Forever Companion: '..target,buttonText='Open',
                tooltip='Hunter and Forever refinements for this part of the UI.',
                onClick=function() if EUI.OpenPlugin then EUI.OpenPlugin(PLUGIN_ID,'companion',target) end end}}
            if module==global and page=='General' then
                rows[#rows+1]={id='appearance',type='labeledButton',text='Dark Mode / UI Look',buttonText='Open Style',
                    onClick=function()
                        if EUI.NavigateToElementSettings then EUI:NavigateToElementSettings(global,'Style','FOREVER THEME PRESETS',nil,'Dark Mode') end
                    end}
            end
            local ok=EUI.RegisterOptionsExtension(ADDON,'companionLink'..i,{module=module,page=page,point='page.end'},{{
                id='companion',title='FOREVER COMPANION',rows=rows}})
            if ok then nativeDone[i]=true end
        end
    end
end
NS.RegisterEllesmereNativeOptions=RegisterNative

local function Append(module, title, builder, pageName, afterSection)
    if not SectionAllowed(title) then return end
    if PluginMode() then
        if not (themesNative and title=='FOREVER THEME PRESETS') then QueuePluginSection(module,title,builder) end
        return
    end
    local cfg = EUI._modules and EUI._modules[module]
    if not cfg or not cfg.buildPage then return end
    local entry={title=title,builder=builder,page=pageName or cfg.pages[1],after=afterSection}
    if wrapped[cfg] then
        for _,v in ipairs(wrapped[cfg]) do if v.title==title then return end end
        wrapped[cfg][#wrapped[cfg]+1]=entry
        return
    end
    local entries={entry}; wrapped[cfg]=entries
    local original = cfg.buildPage
    cfg.buildPage = function(page, parent, offset)
        local W=EUI.Widgets
        if not W then return original(page,parent,offset) end
        local header=W.SectionHeader
        local dual=W.DualRow
        local added,armed={},{}
        local function Build(v,y)
            y=RenderSection(W,header,parent,v,y)
            added[v]=true
            return y
        end
        -- Insert the rank section at the end of native Health and Cast Bar.
        -- Return its extra height to the existing builder so every later row
        -- keeps its native layout. Restore the widget even if a builder errors.
        W.SectionHeader=function(self,host,text,y,...)
            local oldY=y
            for _,v in ipairs(entries) do
                if host==parent and page==v.page and v.after and armed[v] and not added[v] then y=Build(v,y) end
                if host==parent and page==v.page and text==v.after then armed[v]=true end
            end
            local frame,h=header(self,host,text,y,...)
            return frame,h+(oldY-y)
        end
        if module=='EllesmereUINameplates' and NS.AddEllesmereRangeSlotChoices then
            W.DualRow=function(self,host,y,left,right,...)
                NS.AddEllesmereRangeSlotChoices(left);NS.AddEllesmereRangeSlotChoices(right)
                return dual(self,host,y,left,right,...)
            end
        end
        local ok,height=pcall(original,page,parent,offset)
        W.SectionHeader=header
        W.DualRow=dual
        if not ok then error(height,0) end
        if not height then return height end
        local y=-height
        for _,v in ipairs(entries) do if page==v.page and not added[v] then y=Build(v,y) end end
        return math.abs(y)
    end
end
-- Native module Reset also resets this module's companion settings (audit F02).
-- The native confirm popup reloads the UI straight after onReset.
local resetWrapped = setmetatable({}, {__mode='k'})
local function WrapResets()
    for folder in pairs(NS.EllesmereResetKeys or {}) do
        local cfg = EUI._modules and EUI._modules[folder]
        if cfg and type(cfg.onReset) == 'function' and not resetWrapped[cfg] then
            local original = cfg.onReset
            cfg.onReset = function(...)
                if NS.ResetEllesmereCompanionFor then pcall(NS.ResetEllesmereCompanionFor, folder) end
                return original(...)
            end
            resetWrapped[cfg] = true
        end
    end
end
-- Owner-only presets (player: "those come from our helper app and are specific to me; we
-- shouldn't be overwriting others' settings, keybinds, macros"): anything that writes key
-- bindings, macros or another module's settings to the owner's taste is shown only alongside
-- ForeverHunterKeys. Everyone else gets the companion's own features with their defaults.
local function Owner() return _G.ForeverHunterKeysNS~=nil end
NS.EllesmereOwnerInstall=Owner
local function Install()
    WrapResets()
    if Owner() then
        Append(EUI.GLOBAL_KEY or '_EUIGlobal','REVIEWED HUNTER CUES',function(Row)
            if NS.AddEllesmereReviewedProfileOptions then NS.AddEllesmereReviewedProfileOptions(Row) end
        end,'General')
    end
    Append(EUI.GLOBAL_KEY or '_EUIGlobal','FOREVER THEME PRESETS',function(Row)
        if NS.AddEllesmereThemeOptions then NS.AddEllesmereThemeOptions(Row) end
    end,'Style') -- with Ellesmere's own look choices (player request)
    Append(EUI.GLOBAL_KEY or '_EUIGlobal','AUTOGEAR',function(Row)
        if NS.AddEllesmereAutoGearOptions then NS.AddEllesmereAutoGearOptions(Row) end
    end,'General')
    -- One shared motion preference for every companion animation (audit F46).
    Append(EUI.GLOBAL_KEY or '_EUIGlobal','FOREVER MOTION',function(Row)
        Row({type='toggle',text='Reduce Companion Motion',
            tooltip='Warnings stay steady instead of pulsing, history icons fade without sliding, cue fades and XP fill are instant, and the XP glow and damage trail are off.',
            getValue=function() return DB().reduceMotion==true end,
            setValue=function(v) DB().reduceMotion=v
                for _,name in ipairs({'SyncEllesmereWarnings','SyncEllesmerePressFeedback','SyncEllesmereCueFades','SyncEllesmereXPBar'}) do
                    if NS[name] then pcall(NS[name]) end
                end
                if NS.ClearEllesmereDamageTrails then NS.ClearEllesmereDamageTrails() end
            end},
            {type='label',text='Feature settings are kept; switching off restores motion'})
        Row({type='toggle',text='Show Advanced Companion Options',
            tooltip='Shows fine-tuning rows (sizes, offsets, opacities, custom colors) in every Forever section.',
            getValue=ShowAdvanced,setValue=SetAdvanced},
            {type='label',text='Off: each section shows its main choices only'})
        local scenarioNames={inrange='In Range',approaching='Approaching Deadzone',deadzone='Deadzone',melee='Melee',
            out='Out of Range',unknown='Range Unknown',warnings='Warnings',history='Action History'}
        local lastScenario='inrange'
        Row({type='dropdown',text='Preview Scenario',values=scenarioNames,
            order={'inrange','approaching','deadzone','melee','out','unknown','warnings','history'},
            tooltip='Shows the same fixed state every time for about ten seconds, to compare styles. /fhkpreview <name> also works.',
            getValue=function() return lastScenario end,
            setValue=function(v) lastScenario=v;if NS.SetEllesmerePreviewScenario then NS.SetEllesmerePreviewScenario(v) end end,
            preview={tip='Preview this scenario again',duration=10,show=function()
                if NS.SetEllesmerePreviewScenario then NS.SetEllesmerePreviewScenario(lastScenario) end end}},
            {type='label',text='The eye shows it again'})
    end,'General')
    -- Settings live where the task is (audit F08): class resources with Resource Bars,
    -- XP with the native XP page, press feedback with bar animations.
    -- Colour swatches (player: every colour customisable, in its own section). Native picker
    -- with hex input; the shared token changes in place and the companion repaints.
    local function ColorRow(key,text,tip)
        return {type='colorpicker',text=text,hasAlpha=false,tooltip=tip,
            getValue=function() local c=NS.Colours and NS.Colours[key] or {1,1,1};return c[1],c[2],c[3],1 end,
            setValue=function(r,g,b)
                if type(r)~='number' or type(g)~='number' or type(b)~='number' then return end
                FHKEllesmereDB.hunterColors=type(FHKEllesmereDB.hunterColors)=='table' and FHKEllesmereDB.hunterColors or {}
                FHKEllesmereDB.hunterColors[key]={r,g,b}
                if NS.ApplyEllesmereHunterColours then NS.ApplyEllesmereHunterColours() end
            end}
    end
    local function ResetColors(keys,text)
        return {type='button',text=text,onClick=function()
            local saved=FHKEllesmereDB.hunterColors
            if type(saved)=='table' then for _,k in ipairs(keys) do saved[k]=nil end end
            if NS.ApplyEllesmereHunterColours then NS.ApplyEllesmereHunterColours() end
            if EUI.RefreshPage then EUI:RefreshPage() end
        end}
    end
    -- The same token as an inline swatch (row tools) or a multiSwatch entry.
    local function ColorSwatch(key,tip)
        local row=ColorRow(key,tip,tip)
        return {tooltip=tip,hasAlpha=false,getValue=row.getValue,setValue=row.setValue}
    end
    NS.EllesmereColorRow,NS.EllesmereResetColors,NS.EllesmereColorSwatch=ColorRow,ResetColors,ColorSwatch
    -- A toggle with its colours as inline swatches (Ellesmere's row tools).
    local function With(cfg,...) cfg.swatches={...};return cfg end
    Append('EllesmereUIResourceBars','FOREVER CLASS HUD',function(Row)
        if NS.AddEllesmereClassHUDOptions then NS.AddEllesmereClassHUDOptions(Row) end
        -- Class setup by goal (audit F24): each button opens the existing tool for it.
        -- A module that is not loaded would open an empty page (suite review SC-4): grey the button.
        local function Go(text,module,page)
            local function Missing()
                local A=C_AddOns
                if not (A and type(A.IsAddOnLoaded)=='function') then return false end
                local ok,loaded=pcall(A.IsAddOnLoaded,module)
                return ok and loaded==false
            end
            return {type='button',text=text,disabled=Missing,disabledTooltip=module:gsub('^EllesmereUI','EllesmereUI '),onClick=function()
                if not Missing() and EUI.NavigateToElementSettings then EUI:NavigateToElementSettings(module,page) end end}
        end
        Row(Go('Track Cooldowns And Procs','EllesmereUICooldownManager','CDM Bars'),
            Go('Track Buff Durations','EllesmereUICooldownManager','Tracking Bars'))
        Row(Go('Warn When A Buff Is Missing','EllesmereUIAuraBuffReminders','Auras, Buffs & Consumables'),
            Go('Show My Auras As Bars','EllesmereUIUnitFrames','Player Aura Bars'))
        if select(2,UnitClass('player'))=='HUNTER' then
            Row(Go('Hunter Warnings','EllesmereUIQoL','QoL'),Go('Swing Timer And Weaving','EllesmereUIResourceBars','Swing Timer'))
        end
    end,'Class, Power and Health Bars')
    local function KeyLabels()
        return {type='toggle',text='Keyboard-First Key Labels',
            tooltip='A button bound to a keyboard key and a Naga button shows the keyboard key (SG, not SF12); Insert and Delete shorten to Ins and Del. Bindings are unchanged.',
            getValue=function() return NS.EllesmereKeyboardLabelsOn and NS.EllesmereKeyboardLabelsOn() or false end,
            setValue=function(v)
                DB().keyboardKeyLabels=v
                local eab=EUI._ModuleNS.EllesmereUIActionBars and EUI._ModuleNS.EllesmereUIActionBars.EAB
                if eab and eab.ApplyFonts then eab:ApplyFonts() end
            end}
    end
    local function MenuVisibility()
        return {type='dropdown',text='Menu And Bags Visibility',
            values={native='Native Settings',mouseover='Show On Hover',combat_hover='Combat Or Hover'},
            order={'mouseover','combat_hover','native'},
            tooltip='Show On Hover hides the menu and bag bar, including the keyring, until hovered in or out of combat. Combat Or Hover also shows them automatically in combat. Native Settings restores this profile\'s captured visibility.',
            getValue=function() return NS.EllesmereChromeVisibility and NS.EllesmereChromeVisibility() or 'native' end,
            setValue=function(v) if NS.SetEllesmereChromeVisibility then NS.SetEllesmereChromeVisibility(v) end end}
    end
    if not Owner() then
        -- Published install: the display options only; no layout, polish or key/macro presets.
        Append('EllesmereUIActionBars','KEY LABELS AND MENU',function(Row)
            Row(KeyLabels(),MenuVisibility())
        end)
    end
    if Owner() then Append('EllesmereUIActionBars','HUNTER KEYBOARD LAYOUT',function(Row)
        Row({type='button',text='Apply Hunter Layout',onClick=function()
            if NS.ApplyEllesmereHunterLayout then NS.ApplyEllesmereHunterLayout() end
        end},{type='button',text='Apply Hunter Polish',onClick=function()
            if NS.ApplyEllesmereHunterPolish then NS.ApplyEllesmereHunterPolish() end
        end})
        Row(KeyLabels(),{type='label',text='Polish: Cooldown Manager icon trim, softer keybind text'})
        Row({type='button',text='Undo Hunter Layout',onClick=function()
            if NS.UndoEllesmereHunterLayout and NS.UndoEllesmereHunterLayout() and EUI.RefreshPage then EUI:RefreshPage() end
        end,disabled=function() return not (NS.CanUndoEllesmereHunterLayout and NS.CanUndoEllesmereHunterLayout()) end,
            disabledTooltip='Nothing to undo'},
            {type='button',text='Undo Hunter Polish',onClick=function()
            if NS.UndoEllesmereHunterPolish and NS.UndoEllesmereHunterPolish() and EUI.RefreshPage then EUI:RefreshPage() end
        end,disabled=function() return not (NS.CanUndoEllesmereHunterPolish and NS.CanUndoEllesmereHunterPolish()) end,
            disabledTooltip='Nothing to undo'})
        Row({type='label',text='Layout: combat rows center, pets left, items right, RXP above right'},
            {type='label',text='Polish: range coloring, cooldown grey, accent press'})
        Row({type='toggle',text='Fade Wing Bars While Idle',tooltip='Pet, tracking, item and guide bars return on hover or in combat. Changes wait until combat ends. Switching off restores previous visibility settings.',
            getValue=function() return NS.EllesmereIdleWingsEnabled and NS.EllesmereIdleWingsEnabled() or false end,
            setValue=function(v) if NS.ApplyEllesmereIdleWings then NS.ApplyEllesmereIdleWings(v) end end},
            {type='label',text='Uses native visibility; center combat rows stay visible'})
        Row(MenuVisibility(),{type='label',text='Changes made in combat apply when it ends'})
        Row({type='toggle',text='Guide Quest Bar (Bar 8)',
            tooltip='Keeps RestedXP targeting and the guide items on bar 8: U targets; Shift-U, I and Ctrl+Naga 12 use the active item. Keys you rebind yourself are left alone. Off restores your previous keys and RestedXP\'s own item panel.',
            getValue=function() local v=DB().questBar;if v==nil then return (_G.ForeverHunterKeysNS~=nil) end;return v~=false end,
            setValue=function(v) if NS.SetEllesmereQuestBarEnabled then NS.SetEllesmereQuestBarEnabled(v) end end},
            {type='label',text='/fhkquestbar lists the keys it owns'})
    end) end
    Append('EllesmereUIActionBars','XP BAR REFINEMENTS',function(Row)
        if NS.AddEllesmereXPBarOptions then NS.AddEllesmereXPBarOptions(Row) end
    end,'Menu, Bags & XP Bars')
    Append('EllesmereUIActionBars','KEY PRESS AND ACTION HISTORY',function(Row)
        if NS.AddEllesmerePressOptions then NS.AddEllesmerePressOptions(Row) end
    end,'Bar Animations')
    Append('EllesmereUIUnitFrames','ASPECTS',function(Row)
        if NS.AddEllesmereAspectOptions then NS.AddEllesmereAspectOptions(Row) end
    end)
    Append('EllesmereUIUnitFrames','PETS AND SUMMONS',function(Row)
        if NS.AddEllesmereSummonOptions then NS.AddEllesmereSummonOptions(Row) end
    end)
    Append('EllesmereUIUnitFrames','RESOURCE TEXT PAIRS',function(Row)
        if NS.AddEllesmereUnitTextVariantRows then NS.AddEllesmereUnitTextVariantRows(Row) end
    end)
    Append('EllesmereUIUnitFrames','CLASS BUFFS',function(Row)
        if NS.AddEllesmereClassBuffsOptions then NS.AddEllesmereClassBuffsOptions(Row) end
    end)
    Append('EllesmereUIUnitFrames','WEAPON ENCHANTS',function(Row)
        if NS.AddEllesmereWeaponEnchantsOptions then NS.AddEllesmereWeaponEnchantsOptions(Row) end
    end)
    Append('EllesmereUIUnitFrames','PET AURAS AND TARGET',function(Row)
        if NS.AddEllesmerePetElementOptions then NS.AddEllesmerePetElementOptions(Row) end
    end)
    Append('EllesmereUIUnitFrames','PET FOOD',function(Row)
        if NS.AddEllesmerePetFoodOptions then NS.AddEllesmerePetFoodOptions(Row) end
    end)
    Append('EllesmereUIUnitFrames','COLOUR AND TEXT REFINEMENTS',function(Row)
        Row(With(Shared(Toggle('Health Bar Colors','healthBarColors'),'Nameplates'),ColorSwatch('healthMid','Health 50% Color'),
            ColorSwatch('healthLow','Health 25% Color'),ColorSwatch('healthCritical','Health Critical Color')),Toggle('Resource Bar Colors','resourceBarColors'))
        Row(Toggle('Health Text Colors','healthTextColors'),Toggle('Resource Text Colors','resourceTextColors'))
        if PlayerClass()~=nil and PlayerClass()~='HUNTER' then
            Row(ResetColors({'healthMid','healthLow','healthCritical'},'Reset Health Colors'),{type='label',text=''})
        else
        Row({type='toggle',text='Pet Happiness Bar Color',tooltip='Off (default): the pet bar shows health like every bar and the happiness icon shows happiness. On: the pet fill uses the happiness color instead.',
            getValue=function() return FHKEllesmereDB.petHappinessColors==true end,
            setValue=function(v) FHKEllesmereDB.petHappinessColors=v;if NS.SyncEllesmereUnitRefinements then NS.SyncEllesmereUnitRefinements() end end},
            With({type='toggle',text='Pet Happiness Icon',tooltip='Shows pet happiness as a small block with a black outline: green happy, gold content, red unhappy. Off restores the stock face.',
            getValue=function() if NS.EllesmereFrameSetting then return NS.EllesmereFrameSetting('petMoodIcon')==true end return FHKEllesmereDB.petMoodIcon~=false end,
            setValue=function(v) FHKEllesmereDB.petMoodIcon=v;if NS.SyncEllesmereUnitRefinements then NS.SyncEllesmereUnitRefinements() end end},
            ColorSwatch('happy','Happy Color'),ColorSwatch('content','Content Color'),ColorSwatch('unhappy','Unhappy Color')))
        Row(ResetColors({'healthMid','healthLow','healthCritical','happy','content','unhappy'},'Reset Health And Happiness Colors'),
            {type='dropdown',text='Pet Happiness Style',values={square='Square',paw='Paw'},order={'square','paw'},
            tooltip='Square: a flat colored block. Paw: the tinted paw icon.',
            getValue=function() return FHKEllesmereDB.petMoodStyle=='paw' and 'paw' or 'square' end,
            setValue=function(v) FHKEllesmereDB.petMoodStyle=v;if NS.SyncEllesmereUnitRefinements then NS.SyncEllesmereUnitRefinements() end end},true)
        Row({type='toggle',text='Hide When Happy',tooltip='The happiness icon and strip show only when your pet is content or unhappy.',
            getValue=function() return FHKEllesmereDB.petMoodHideHappy==true end,
            setValue=function(v) FHKEllesmereDB.petMoodHideHappy=v;if NS.SyncEllesmereUnitRefinements then NS.SyncEllesmereUnitRefinements() end end},
            {type='label',text='Green means nothing to do, so it can go'},true)
        if NS.EllesmerePetMoodSettings then
            local m=NS.EllesmerePetMoodSettings()
            local function Set(key,v)
                m[key]=v
                if NS.SyncEllesmereUnitRefinements then NS.SyncEllesmereUnitRefinements() end
            end
            local function MoodSlider(text,key,min,max,step,scale)
                return {type='slider',text=text,min=min,max=max,step=step,
                    getValue=function() return scale and m[key]*scale or m[key] end,
                    setValue=function(v) Set(key,scale and v/scale or v) end}
            end
            Row({type='dropdown',text='Happiness Strip Position',values={top='Top',bottom='Bottom',left='Left',right='Right'},
                order={'top','bottom','left','right'},getValue=function() return m.side end,setValue=function(v) Set('side',v) end},
                MoodSlider('Happiness Strip Thickness','thickness',1,8,1))
            Row(MoodSlider('Happiness Strip Length %','length',10,100,5),
                {type='dropdown',text='Happiness Strip Alignment',values={left='Left',center='Center',right='Right'},
                order={'left','center','right'},getValue=function() return m.align end,setValue=function(v) Set('align',v) end,
                tooltip='Top and bottom strips shorter than 100%'},true)
            Row(MoodSlider('Happiness Strip Gap','gap',0,8,1),MoodSlider('Happiness Strip Opacity %','opacity',10,100,5,100),true)
            Row({type='toggle',text='Happiness Strip In All Themes',tooltip='Dark themes always add the strip. On: show the strip in colored themes too (the paw icon already shows happiness).',
                getValue=function() return m.always==true end,setValue=function(v) Set('always',v) end},
                {type='label',text='Dark / Afterglow: pet fill stays dark; strip shows happiness'})
        end
        end
        local function PlayerResourceSettings()
            local uf=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIUnitFrames
            local profile=uf and uf.db and uf.db.profile
            local s=type(profile)=='table' and profile.player
            if type(s)=='table' then return uf,s end
        end
        Row({type='dropdown',text='Player Resource Format',values={none='Hidden',perpp='Resource %',curpp='Resource #',
            both='Resource # | %',perppnum='Resource % | #'},order={'none','perpp','curpp','both','perppnum'},
            disabled=function() return PlayerResourceSettings()==nil end,
            disabledTooltip='Enable Ellesmere Unit Frames to change player resource text.',
            getValue=function()
                local _,s=PlayerResourceSettings()
                if not s then return 'none' end
                if s.powerPercentText == 'none' then return 'none' end
                local pairs_=type(FHKEllesmereDB.ufTextVariants)=='table' and FHKEllesmereDB.ufTextVariants.player
                if type(pairs_)=='table' and pairs_.powerText=='perppnum' then return 'perppnum' end
                return s.powerTextFormat or 'both'
            end,setValue=function(v)
                local uf,s=PlayerResourceSettings()
                if not s then return end
                -- Ellesmere's own profile keeps only its native keys (suite review SC-2): the companion's
                -- "% | #" pair is drawn over the native 'both' and saved in the companion store.
                local variants=type(FHKEllesmereDB.ufTextVariants)=='table' and FHKEllesmereDB.ufTextVariants or {}
                variants.player=type(variants.player)=='table' and variants.player or {}
                variants.player.powerText=(v=='perppnum') and 'perppnum' or nil
                FHKEllesmereDB.ufTextVariants=variants
                if v=='perppnum' then v='both' end
                if v == 'none' then s.powerPercentText='none'
                else
                    if not s.powerPercentText or s.powerPercentText == 'none' then s.powerPercentText='center' end
                    -- Format only; bar height stays under the native Power Height control (audit F13).
                    s.powerTextFormat=v; s.powerPercentSize=s.powerPercentSize or 10
                end
                -- Refresh only the player's power text when the frame supports it (audit F36).
                local refreshed
                for _,f in pairs(uf.frames or {}) do
                    if type(f)=='table' and f._euiBaseUnit=='player' and f.Power and f.Power._applyPowerPercentText then
                        refreshed=pcall(f.Power._applyPowerPercentText,s)
                        if refreshed and uf.UF_PaintPowerText then pcall(uf.UF_PaintPowerText,f,'player') end
                    end
                end
                if not refreshed and uf.ReloadFrames then uf.ReloadFrames() end
                if EUI.RefreshPage then EUI:RefreshPage() end
            end}, {type='toggle',text='Align Power and Health Text',
                tooltip='Use matching left/right text insets. Font sizes and native X/Y offset controls stay independent.',
                getValue=function() return DB().alignPowerText~=false end,
                setValue=function(v)
                    DB().alignPowerText=v
                    if NS.SyncEllesmereUnitRefinements then NS.SyncEllesmereUnitRefinements() end
                end})
        Row({type='toggle',text='Status Icons on Frame Edge',
            tooltip='While the Combat Indicator is in its Center position, it and the loot bag sit on the health bar\'s top edge instead of over the name and values. The pet happiness paw, in its Right position, sits on the pet bar\'s top-right corner.',
            getValue=function() if NS.EllesmereFrameSetting then return NS.EllesmereFrameSetting('statusIconBadge')==true end return DB().statusIconBadge~=false end,
            setValue=function(v)
                DB().statusIconBadge=v
                local uf=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIUnitFrames
                if uf and uf.ReloadFrames then uf.ReloadFrames() end
                if NS.SyncEllesmereUnitRefinements then NS.SyncEllesmereUnitRefinements() end
            end},
            {type='label',text='Combat Center and paw Right only; other positions stay as set'})
        Row({type='toggle',text='Dark Mode Health Line',
            tooltip='In Dark Mode, a thin line along the top of the remaining health shows the amount and turns gold, orange and red with the health number.',
            getValue=function() return DB().darkHealthLine~=false end,
            setValue=function(v)
                DB().darkHealthLine=v
                if NS.SyncEllesmereUnitRefinements then NS.SyncEllesmereUnitRefinements() end
            end},
            {type='label',text='Dark Mode only; colored bars warn with their fill'})
        Row({type='toggle',text='Flee Mark',
            tooltip='A thin mark at 20% on the target health bar where an enemy NPC may run: every humanoid, plus any creature you have seen run away in fear. Have Concussive Shot ready.',
            getValue=function() return DB().fleeTick~=false end,
            setValue=function(v)
                DB().fleeTick=v
                if NS.SyncEllesmereUnitRefinements then NS.SyncEllesmereUnitRefinements() end
            end},
            {type='label',text='Learns each creature that runs away in fear'})
        Row({type='toggle',text='Loot Icon Replaces 0%',
            tooltip='On a dead unit you can loot or skin, the loot bag or skinning icon takes the place of the 0% health text: white within reach, dim when farther away.',
            getValue=function() return DB().lootInHealthText~=false end,
            setValue=function(v) DB().lootInHealthText=v;if NS.SyncEllesmereUnitRefinements then NS.SyncEllesmereUnitRefinements() end end},
            {type='label',text='Uses the Loot Icons setting under Nameplates'})
        -- Size and position (player: "anything that allows us to move the combat indicators?").
        -- The player frame's own indicator moves with Ellesmere's native combat indicator options.
        local function Num(label,key,default,min,max)
            return {type='slider',label=label,min=min,max=max,step=1,get=function() local v=DB()[key];return type(v)=='number' and v or default end,
                set=function(v) DB()[key]=v;if NS.SyncEllesmereUnitRefinements then NS.SyncEllesmereUnitRefinements() end end}
        end
        local petOff=function() return DB().petCombatIcon==false end
        local petCombat={type='toggle',text='Pet Combat Icon',
            tooltip='Shows the combat icon beside your pet frame while your pet is in combat, matching the player frame icon.',
            getValue=function() return DB().petCombatIcon~=false end,
            setValue=function(v) DB().petCombatIcon=v;if NS.SyncEllesmereUnitRefinements then NS.SyncEllesmereUnitRefinements() end end}
        petCombat.cog={title='Pet Combat Icon',disabled=petOff,disabledTooltip='Pet Combat Icon',rows={Num('Size','petCombatSize',16,8,32)}}
        petCombat.move={title='Pet Combat Icon Position',disabled=petOff,disabledTooltip='Pet Combat Icon',
            rows={Num('X Offset','petCombatX',-4,-200,200),Num('Y Offset','petCombatY',0,-200,200)}}
        local style={type='dropdown',text='Combat Icon Style',values={block='White Block',native='Ellesmere Icon'},order={'block','native'},
            tooltip='White Block: a small white square with a black outline on the player and pet frames while in combat. Ellesmere Icon: the style chosen in the Unit Frames combat indicator options, which also move the player icon.',
            getValue=function() local v=NS.EllesmereFrameSetting and NS.EllesmereFrameSetting('combatIconStyle') or DB().combatIconStyle;return v=='native' and 'native' or 'block' end,
            setValue=function(v) DB().combatIconStyle=v;if NS.SyncEllesmereUnitRefinements then NS.SyncEllesmereUnitRefinements() end end}
        style.cog={title='White Block',disabled=function() local v=NS.EllesmereFrameSetting and NS.EllesmereFrameSetting('combatIconStyle') or DB().combatIconStyle;return v=='native' end,disabledTooltip='Combat Icon Style: White Block',
            rows={Num('Block Size','combatBlockSize',12,6,24)}}
        if PlayerClass()==nil or PET_CLASSES[PlayerClass()] then Row(petCombat,style) else Row(style,{type='label',text=''}) end
        if NS.AddEllesmereTargetOfTargetRow then NS.AddEllesmereTargetOfTargetRow(Row) end
        if NS.AddEllesmereDamageTrailOptions then NS.AddEllesmereDamageTrailOptions(Row,'unitframes') end
    end)
    -- The owner's frame and bar arrangement: owner install only (publishing rule).
    if Owner() then Append('EllesmereUIUnitFrames','COMBAT LAYOUT',function(Row)
        Row({type='button',text='Apply Combat Layout',
            tooltip='Places the cooldown rows around the swing bar, player and target beside it, pet and target of target under them, side action bars on hover, and fades guides in combat. Undo restores every value it changed.',
            onClick=function()
                local ok,message=NS.ApplyEllesmereCombatLayout and NS.ApplyEllesmereCombatLayout()
                print('FHK: '..(ok and 'Combat Layout applied.' or message or 'Combat Layout could not be applied.'))
                if EUI.RefreshPage then EUI:RefreshPage() end
            end},
            {type='button',text='Undo Combat Layout',onClick=function()
                local ok,message=NS.UndoEllesmereCombatLayout and NS.UndoEllesmereCombatLayout()
                print('FHK: '..(ok and 'Combat Layout undone.' or message or 'Nothing to undo.'))
                if EUI.RefreshPage then EUI:RefreshPage() end
            end,disabled=function() return not (NS.EllesmereCombatLayoutApplied and NS.EllesmereCombatLayoutApplied()) end,
            disabledTooltip='Nothing to undo'})
        Row({type='label',text='Add your shots to the Cooldown Manager Essential row to fill it'},
            {type='label',text='/fhklayout and /fhklayout undo do the same'})
    end) end
    Append('EllesmereUIUnitFrames','RANGE BAR',function(Row)
        if NS.AddEllesmereIndicatorOptions then NS.AddEllesmereIndicatorOptions(Row,'frame') end
    end)
    Append('EllesmereUINameplates','HUNTER RANGE AND CORPSES',function(Row)
        Row({type='dropdown',text='Range Cue Preset',values={minimal='Minimal',weaving='Weaving',detailed='Detailed',custom='Custom'},
            order={'minimal','weaving','detailed','custom'},
            tooltip='Minimal: target glow and center line. Weaving: adds plate text, range names, non-target glow and the unit-frame bar. Detailed: adds yard units and target-of-target.',
            getValue=function() return NS.GetEllesmereRangePreset and NS.GetEllesmereRangePreset() or 'custom' end,
            setValue=function(v) if v~='custom' and NS.ApplyEllesmereRangePreset then NS.ApplyEllesmereRangePreset(v) end
                if EUI.RefreshPage then EUI:RefreshPage() end end},
            {type='label',text='Changing any range option below switches to Custom'})
        Row(Shared(Toggle('Health Bar Colors','healthBarColors'),'Unit Frames'),{type='label',text='Native color -> yellow -> orange -> red'})
        Row(Toggle('Range Text','nameplateRangeText'),Toggle('Show Range Units','showRangeUnits',true))
        Row(Toggle('Range-Colored Names','rangeNameColors'),Toggle('Tint Target Glow','targetRangeGlow'))
        Row(Toggle('Non-Target Range Mark','nonTargetRange'),Toggle('Loot Icons','lootCues'))
        -- The floating icon over objects is engine-drawn and already range-gated: it only
        -- appears while the object is in interact range (audit F25). Expose its native CVar.
        Row({type='toggle',text='Object Interact Icon',
            tooltip='The game\'s own icon over a nearby object you can interact with (quest objects, chests, herbs). It appears only within interact range.',
            getValue=function() return GetCVarBool and GetCVarBool('SoftTargetIconGameObject') or false end,
            setValue=function(v) if SetCVar then SetCVar('SoftTargetIconGameObject',v and '1' or '0') end end},
            {type='label',text='Shown by the game only while in interact range'})
        Row({type='toggle',text='Soft-Target Sword Icons',
            tooltip='The crossed-sword icon the game draws over the enemy or friend your soft target picks. Turn them off to keep one combat icon, on the player frame.',
            getValue=function() return GetCVarBool and (GetCVarBool('SoftTargetIconEnemy') or GetCVarBool('SoftTargetIconFriend')) or false end,
            setValue=function(v) if SetCVar then SetCVar('SoftTargetIconEnemy',v and '1' or '0');SetCVar('SoftTargetIconFriend',v and '1' or '0') end end},
            {type='label',text='A game setting, saved with your client'})
        Row({type='toggle',text='Extra Combat Icons',
            tooltip='Also shows the in-combat class icon beside engaged enemy nameplates and above the center HUD. Off keeps one combat icon, on your player frame.',
            getValue=function() return DB().extraCombatIcons==true end,
            setValue=function(v) DB().extraCombatIcons=v end},
            {type='label',text='Off: one combat icon, on the player frame'})
        Row(Toggle('Skinning Icons','skinCues'),{type='label',text='White: ready; translucent grey: unavailable'})
        Row(With({type='toggle',text='Gold Edge When Attacking You',
            tooltip='In combat, an enemy whose target is you, not your pet, gets a thin gold edge on its nameplate.',
            getValue=function() return DB().aggroPlates~=false end,
            setValue=function(v) DB().aggroPlates=v;if NS.SyncEllesmereUnitRefinements then NS.SyncEllesmereUnitRefinements() end end},
            ColorSwatch('aggroYou','On You Edge Color')),
            {type='label',text='Gold means act now: Feign Death or let the pet take it back'})
        Row(With({type='toggle',text='Green Edge When Attacking Your Pet',
            tooltip='In combat, an enemy whose target is your pet gets a thin pet-green edge: gold is you, green is your pet, no edge is someone else.',
            getValue=function() return DB().petAggroPlates==true end,
            setValue=function(v) DB().petAggroPlates=v;if NS.SyncEllesmereUnitRefinements then NS.SyncEllesmereUnitRefinements() end end},
            ColorSwatch('aggroPet','On Pet Edge Color')),
            ResetColors({'aggroYou','aggroPet'},'Reset Edge Colors'))
        local fades={type='toggle',text='Smooth Cue Fades',tooltip='Smooth corpse readiness and range fades on guide, rarity and raid markers. Whole-nameplate opacity uses Opacity Priority when enabled, otherwise native settings.',
            getValue=function() return DB().cueFades==true end,
            setValue=function(v) DB().cueFades=v;NS.SyncEllesmereCueFades() end}
        fades.cog={title='Cue Fades',disabled=function() return DB().cueFades~=true end,disabledTooltip='Smooth Cue Fades',rows={
            {type='slider',label='Marker Out Of Range %',min=0,max=100,step=5,
                tooltip='Extra marker opacity, multiplied by the nameplate\'s opacity. Use /fhkopacity while hovering a plate to see the active layers.',
                get=function() return (DB().cueOutAlpha or .28)*100 end,set=function(v) DB().cueOutAlpha=v/100;NS.SyncEllesmereCueFades() end}}}
        Row(fades,{type='label',text='Fades guide, rarity and raid markers with range'})
        if NS.AddEllesmereDamageTrailOptions then NS.AddEllesmereDamageTrailOptions(Row,'nameplates') end
    end)
    Append('EllesmereUINameplates','NAMEPLATE OPACITY PRIORITY',function(Row)
        if NS.AddEllesmereNameplateOpacityOptions then NS.AddEllesmereNameplateOpacityOptions(Row) end
    end)
    Append('EllesmereUINameplates','RANGE INDICATOR STYLE',function(Row)
        if NS.AddEllesmereIndicatorOptions then NS.AddEllesmereIndicatorOptions(Row,'plate') end
    end,'Display')
    Append('EllesmereUINameplates','MOB RARITY',function(Row)
        local badges=Toggle('Native Elite / Rare Badges','rarityIcons')
        badges.cog={title='Rarity Badges',disabled=function() return DB().rarityIcons==false end,disabledTooltip='Native Elite / Rare Badges',rows={
            {type='slider',label='Badge Size',min=10,max=24,step=1,get=function() return DB().rarityIconSize or 16 end,
                set=function(v) DB().rarityIconSize=v; if NS.RefreshEllesmereRarity then NS.RefreshEllesmereRarity() end end}}}
        Row(Toggle('Elite / Rare Level Markers','rarityMarkers'),
            With(Toggle('Gold / Silver Level Colors','rarityLevelColours'),ColorSwatch('rarityElite','Elite Level Color'),ColorSwatch('rarityRare','Rare Level Color')))
        Row(badges,{type='label',text='Gold: elite / boss; silver: rare / rare elite'})
        Row({type='label',text='Disable colors to use native level difficulty colors'},
            ResetColors({'rarityElite','rarityRare','quest'},'Reset Rarity Colors'))
        Row(Toggle('Skull-Ranked Level Icon','raritySkulls'),
            {type='label',text='Uses the game\'s skull rank, not a fixed level gap'})
        Row(With(Toggle('Quest Count Beside Bar Corner','rarityQuestCount'),ColorSwatch('quest','Quest Count Color')),
            {type='label',text='Quest yellow, clear of the mob name'})
        Row({type='dropdown',text='Rarity Badge Position',values={bottomleft='Below Left',topright='Beside Name'},order={'bottomleft','topright'},
            getValue=function() return DB().rarityIconPosition or 'bottomleft' end,
            setValue=function(v) DB().rarityIconPosition=v;if NS.RefreshEllesmereRarity then NS.RefreshEllesmereRarity() end end},
            {type='label',text='Below Left sits beside the range text'})
        Row({type='dropdown',text='Rarity Level Format',values={symbols='+ / ++ / Rare Badge',letters='E / R / RE / B'},order={'symbols','letters'},
            getValue=function() return DB().rarityMarkerStyle or 'symbols' end,
            setValue=function(v) DB().rarityMarkerStyle=v
                local np=_G.EllesmereNameplates_NS;if np and np.RefreshAllSettings then np.RefreshAllSettings() end
            end}, {type='label',text='13E elite, 13R rare, 13RE rare elite; badges are independent'})
    end,'Display','HEALTH AND CAST BAR')
    Append('EllesmereUIResourceBars','HEALTH AND RESOURCE TEXT SLOTS',function(Row)
        if not NS.ResourceBarZoneSettings then return end
        local values={none='Hidden',curhp='Health #',perhp='Health %',bothhp='Health # | %',perhpnum='Health % | #',
            curpp='Resource #',perpp='Resource %',bothpp='Resource # | %',perppnum='Resource % | #'}
        local order={'none','curhp','perhp','bothhp','perhpnum','curpp','perpp','bothpp','perppnum'}
        for _,kind in ipairs({'health','primary'}) do
            local s=NS.ResourceBarZoneSettings(kind)
            local title=kind=='health' and 'Health Bar' or 'Resource Bar'
            Row({type='toggle',text=title .. ' Text Slots',getValue=function() return s.enabled end,
                setValue=function(v) s.enabled=v; NS.PaintEllesmereResourceBars() end},
                Toggle(title .. ' Colors',kind=='health' and 'healthBarColors' or 'resourceBarColors'))
            for _,position in ipairs({'left','center','right'}) do
                local row=Row({type='dropdown',text=title .. ' ' .. position:gsub('^%l',string.upper),values=values,order=order,
                    getValue=function() return s[position] end,setValue=function(v) s[position]=v; NS.PaintEllesmereResourceBars() end},
                    {type='label',text=position=='center' and 'Hide the centre for amount left / percentage right' or ''})
                if NS.AddEllesmereResourceTextCog then NS.AddEllesmereResourceTextCog(row,kind,position) end
            end
        end
    end)
    Append('EllesmereUIResourceBars','RANGE INDICATOR',function(Row)
        if NS.AddEllesmereIndicatorOptions then NS.AddEllesmereIndicatorOptions(Row,'range') end
    end)
    Append('EllesmereUIResourceBars','BEHIND INDICATOR',function(Row)
        if NS.AddEllesmereBehindOptions then NS.AddEllesmereBehindOptions(Row) end
    end)
    Append('EllesmereUIResourceBars','ENERGY TICK',function(Row)
        if NS.AddEllesmereEnergyTickOptions then NS.AddEllesmereEnergyTickOptions(Row) end
    end)
    Append('EllesmereUIResourceBars','AUTO ATTACK INDICATORS',function(Row)
        if NS.AddEllesmereIndicatorOptions then NS.AddEllesmereIndicatorOptions(Row,'attacks') end
    end)
    Append('EllesmereUIChat','FOREVER CHAT',function(Row)
        Row({type='toggle',text='Hide Chat In Combat',
            tooltip='Uses Ellesmere\'s own visibility rules: chat hides as combat starts and returns when it ends. Off restores your previous chat visibility.',
            getValue=function() return NS.EllesmereChatHiddenInCombat and NS.EllesmereChatHiddenInCombat() or false end,
            setValue=function(v) if NS.SetEllesmereChatHiddenInCombat then NS.SetEllesmereChatHiddenInCombat(v) end end},
            {type='toggle',text='Show Chat Only When Typing Or Hovered',
            tooltip='Chat stays hidden and appears while you type or hover it, fading 2 seconds after the mouse leaves. Public chat lines no longer bring it back; whispers still do. Off restores your Idle Fade settings.',
            getValue=function() return NS.EllesmereChatQuiet and NS.EllesmereChatQuiet() or false end,
            setValue=function(v) FHKEllesmereDB.chatQuiet=v;if NS.ApplyEllesmereChatQuiet then NS.ApplyEllesmereChatQuiet() end end})
    end)
    Append('EllesmereUIQoL',ClassTitle('HUNTER WARNINGS'),function(Row)
        if NS.AddEllesmereWarningOptions then NS.AddEllesmereWarningOptions(Row) end
    end)
    Append('EllesmereUIQoL',ClassTitle('HUNTER CUES'),function(Row)
        if NS.AddEllesmereHunterCueOptions then NS.AddEllesmereHunterCueOptions(Row) end
    end)
    Append('EllesmereUIQoL','NEW SPELLS',function(Row)
        if NS.AddEllesmereRankNotifierOptions then NS.AddEllesmereRankNotifierOptions(Row) end
    end)
    Append('EllesmereUIQoL','VENDOR RESTOCK',function(Row)
        if NS.AddEllesmereAmmoBuyOptions and (not NS.EllesmereAmmoBuyAvailable or NS.EllesmereAmmoBuyAvailable()) then NS.AddEllesmereAmmoBuyOptions(Row) end
        if NS.AddEllesmereRestockOptions then NS.AddEllesmereRestockOptions(Row) end
    end)
    Append('EllesmereUIQoL','CLASS CUES',function(Row)
        if NS.AddEllesmereClassCueOptions then NS.AddEllesmereClassCueOptions(Row) end
    end)
    Append('EllesmereUIQoL','CLASS SUPPLIES',function(Row)
        if NS.AddEllesmereClassStockOptions then NS.AddEllesmereClassStockOptions(Row) end
    end)
    Append('EllesmereUIQoL','TRAINING',function(Row)
        if NS.AddEllesmereAutoTrainOptions then NS.AddEllesmereAutoTrainOptions(Row) end
        if NS.AddEllesmereTalentPlannerOptions then NS.AddEllesmereTalentPlannerOptions(Row) end
    end)
    Append('EllesmereUIQoL','LEVELING HELPERS',function(Row)
        if NS.AddEllesmereLevelingOptions then NS.AddEllesmereLevelingOptions(Row) end
    end)
    Append('EllesmereUICooldownManager','COOLDOWN KEY LABELS',function(Row)
        if NS.AddEllesmereCdmLabelOptions then NS.AddEllesmereCdmLabelOptions(Row) end
    end)
    Append('EllesmereUIQoL',ClassTitle('HUNTER COLORS'),function(Row)
        -- Plan section 5: the identity colours used by range, swing, cast and warning cues.
        local function Swatch(key,text,tip)
            return {type='colorpicker',text=text,hasAlpha=false,tooltip=tip,
                getValue=function() local c=NS.Colours and NS.Colours[key] or {1,1,1};return c[1],c[2],c[3],1 end,
                setValue=function(r,g,b)
                    if type(r)~='number' or type(g)~='number' or type(b)~='number' then return end
                    FHKEllesmereDB.hunterColors=type(FHKEllesmereDB.hunterColors)=='table' and FHKEllesmereDB.hunterColors or {}
                    FHKEllesmereDB.hunterColors[key]={r,g,b}
                    if NS.ApplyEllesmereHunterColours then NS.ApplyEllesmereHunterColours() end
                end}
        end
        local function Spec(key,text,tip) local c=Swatch(key,text,tip);return {tooltip=text..': '..tip,hasAlpha=false,getValue=c.getValue,setValue=c.setValue} end
        -- One row of swatches, the native multiSwatch (Ellesmere's row tools).
        Row({type='multiSwatch',text='Range And Attack Colors',tooltip='Shooting, melee, cast and retry: rings, bars, icons and cue text. Bars use a deeper shade.',
            -- Shooting and Retry are Auto Shot colors: hunters only (review R3-2).
            swatches=(PlayerClass()==nil or PlayerClass()=='HUNTER') and {Spec('shoot','Shooting','in shooting range, Auto Shot rings, bars and icons'),Spec('melee','Melee','in melee range, the melee swing and Melee Ready'),
                Spec('cast','Cast','your casts: the cast ring and world cues'),Spec('retry','Retry','Auto Shot retry: ring, icon and cue text')}
                or {Spec('melee','Melee','in melee range and the melee swing'),Spec('cast','Cast','your casts: the cast ring and world cues')}},
            {type='multiSwatch',text='Warning Colors',tooltip='Danger: the dead zone and act-now warnings. Caution: approaching the dead zone, low ammo and other warnings.',
            swatches={Spec('danger','Danger','the dead zone and act-now warnings'),Spec('caution','Caution','approaching the dead zone, low ammo')}})
        -- Only this section's own colors: health, happiness, rarity and aggro colors set in their
        -- own sections keep their values (review R3-2).
        Row({type='button',text=(PlayerClass()==nil or PlayerClass()=='HUNTER') and 'Reset Hunter Colors' or 'Reset Cue Colors',onClick=function()
            local t=FHKEllesmereDB.hunterColors
            if type(t)=='table' then for _,key in ipairs({'shoot','melee','cast','retry','danger','caution'}) do t[key]=nil end end
            if NS.ApplyEllesmereHunterColours then NS.ApplyEllesmereHunterColours() end
            if EUI.RefreshPage then EUI:RefreshPage() end
        end},{type='label',text='Unset colors keep the Forever palette'})
    end)
    Append('EllesmereUIResourceBars','HUNTER TIMING COMPATIBILITY',function(Row)
        if select(2,UnitClass('player'))=='HUNTER' and NS.AddEllesmereTimingOptions then NS.AddEllesmereTimingOptions(Row) end
    end,'Swing Timer')
    RegisterPluginPages()
    RegisterNative()
end
driver:RegisterEvent('ADDON_LOADED'); driver:RegisterEvent('PLAYER_LOGIN')
-- Ellesmere's options load on demand: retry the native placements when a page opens.
if type(EUI.ShowModule)=='function' then hooksecurefunc(EUI,'ShowModule',function() RegisterNative() end) end
driver:SetScript('OnEvent',Install)
Install()
