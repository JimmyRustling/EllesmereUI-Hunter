-- Optional native Forever class HUD setup and an inventory-backed shard counter.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS or not EUI.IS_FOREVER then return end
local driver=CreateFrame('Frame')
local counter,pending,requestedItem
local SHARD_ITEM=6265
local function Public(v) return not (issecretvalue and issecretvalue(v)) end
local function ProfileName() return EllesmereUIDB and EllesmereUIDB.activeProfile or 'Default' end
local function State(write)
    if write then
        FHKEllesmereDB=FHKEllesmereDB or {};FHKEllesmereDB.classHUD=FHKEllesmereDB.classHUD or {}
        local states=FHKEllesmereDB.classHUD;local key=ProfileName()
        states[key]=states[key] or {};return states[key]
    end
    return FHKEllesmereDB and FHKEllesmereDB.classHUD and FHKEllesmereDB.classHUD[ProfileName()]
end
local function ResourceProfile()
    local ns=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIResourceBars
    return ns and ns.ERB and ns.ERB.db and ns.ERB.db.profile,ns
end
local function PlayerClass()
    local _,token=UnitClass('player');if Public(token) then return token end
end
function NS.EllesmereClassHUDEnabled() local s=State();return s and s.enabled==true or false end
local function ItemID()
    local s=State();local id=s and s.shardItemID
    if Public(id) and type(id)=='number' and id>0 and id==math.floor(id) then return id end
    return SHARD_ITEM
end
local function PaintCounter()
    if not NS.EllesmereClassHUDEnabled() or PlayerClass()~='WARLOCK' then if counter then counter:Hide() end;return end
    local item=ItemID()
    local ok,count=pcall(function() return C_Item.GetItemCount(item,false,false,false,false) end)
    local infoOK,name=pcall(function() return C_Item.GetItemInfo(item) end)
    if not infoOK or not Public(name) or type(name)~='string' then
        if counter then counter:Hide() end
        if requestedItem~=item and C_Item and C_Item.RequestLoadItemDataByID then
            requestedItem=item;pcall(C_Item.RequestLoadItemDataByID,item)
        end
        return
    end
    if not ok or not Public(count) or type(count)~='number' or count<0 or count~=math.floor(count) then
        if counter then counter:Hide() end;return
    end
    local anchor=_G.ERB_PrimaryBar
    if not anchor then if counter then counter:Hide() end;return end
    if not counter then
        if InCombatLockdown() then driver:RegisterEvent('PLAYER_REGEN_ENABLED');return end
        counter=CreateFrame('Frame',nil,anchor);counter:SetSize(108,18);counter:EnableMouse(false)
        counter:SetPoint('TOPLEFT',anchor,'BOTTOMLEFT',0,-2)
        counter.bg=counter:CreateTexture(nil,'BACKGROUND');counter.bg:SetAllPoints()
        counter.bg:SetColorTexture(.07,.08,.11,.92)
        counter.text=counter:CreateFontString(nil,'OVERLAY');counter.text:SetAllPoints()
    elseif counter:GetParent()~=anchor then
        if InCombatLockdown() then counter:Hide();driver:RegisterEvent('PLAYER_REGEN_ENABLED');return end
        counter:SetParent(anchor);counter:ClearAllPoints();counter:SetPoint('TOPLEFT',anchor,'BOTTOMLEFT',0,-2)
    end
    if EUI.ApplyModuleFont then EUI.ApplyModuleFont(counter.text,nil,10,'resourceBars')
    else counter.text:SetFont(EUI.GetFontPath and EUI.GetFontPath('resourceBars') or 'Fonts\\FRIZQT__.TTF',10,'OUTLINE') end
    if NS.ApplyEllesmereCueText then NS.ApplyEllesmereCueText(counter.text,'cue') end
    local color=EUI.GetClassResourceColor and EUI.GetClassResourceColor('SoulShards')
    counter.text:SetTextColor(color and color.r or .72,color and color.g or .61,color and color.b or 1)
    counter.text:SetText(name..': '..count)
    if counter.text.GetStringWidth then
        local width=counter.text:GetStringWidth()
        if Public(width) and type(width)=='number' then counter:SetWidth(math.max(108,width+12)) end
    end
    counter:Show()
end
local function SyncEvents()
    local shards=NS.EllesmereClassHUDEnabled() and PlayerClass()=='WARLOCK'
    for _,event in ipairs({'BAG_UPDATE_DELAYED','PLAYER_ENTERING_WORLD','GET_ITEM_INFO_RECEIVED','ITEM_DATA_LOAD_RESULT'}) do
        if shards then driver:RegisterEvent(event) else driver:UnregisterEvent(event) end
    end
    if pending or (shards and InCombatLockdown()) then driver:RegisterEvent('PLAYER_REGEN_ENABLED')
    else driver:UnregisterEvent('PLAYER_REGEN_ENABLED') end
end
function NS.SyncEllesmereClassHUD()
    if not NS.EllesmereClassHUDEnabled() then requestedItem=nil end
    SyncEvents();PaintCounter()
end
function NS.ApplyEllesmereClassHUD(enabled)
    if InCombatLockdown() then
        pending={enabled=enabled==true,profile=ProfileName()};SyncEvents();return false,'Class HUD queued until combat ends.'
    end
    local p,ns=ResourceProfile()
    if not p or not p.primary or not p.secondary then return false,'Native Resource Bars is unavailable.' end
    local s=State(true);local class=PlayerClass()
    if enabled and not class then return false,'The player class is unavailable.' end
    if enabled then
        if not s.backup then
            s.backup={primary=p.primary.enabled,class=class}
            if class=='ROGUE' or class=='DRUID' then s.backup.secondary=p.secondary.enabled;s.backup.points=true end
            if class=='DRUID' and p.primary.foreverDruidMana then
                s.backup.druidMana=p.primary.foreverDruidMana.enabled;s.backup.mana=true
            end
            if class=='SHAMAN' and p.totemBar then
                local classes=p.totemBar.enabledClasses
                s.backup.totems=true;s.backup.totemHadTable=classes~=nil;s.backup.totemShaman=classes and classes.SHAMAN
                if p.callTotemBar and _G.MultiCastActionBarFrame then
                    s.backup.calls=true;s.backup.callTotems=p.callTotemBar.enabled
                end
            end
        end
        p.primary.enabled=true
        -- The native resolver owns forms, target points, custom resources and art.
        if class=='ROGUE' or class=='DRUID' then p.secondary.enabled=true end
        if class=='DRUID' and p.primary.foreverDruidMana then p.primary.foreverDruidMana.enabled=true end
        if class=='SHAMAN' and p.totemBar then
            p.totemBar.enabledClasses=p.totemBar.enabledClasses or {};p.totemBar.enabledClasses.SHAMAN=true
            if p.callTotemBar and _G.MultiCastActionBarFrame then p.callTotemBar.enabled=true end
        end
    elseif s.backup then
        local saved=s.backup
        p.primary.enabled=saved.primary
        if saved.points then p.secondary.enabled=saved.secondary end
        if saved.mana and p.primary.foreverDruidMana then p.primary.foreverDruidMana.enabled=saved.druidMana end
        if saved.totems and p.totemBar and p.totemBar.enabledClasses then
            p.totemBar.enabledClasses.SHAMAN=saved.totemShaman
            if not saved.totemHadTable and not next(p.totemBar.enabledClasses) then p.totemBar.enabledClasses=nil end
        end
        if saved.calls and p.callTotemBar then p.callTotemBar.enabled=saved.callTotems end
        s.backup=nil
    end
    s.enabled=enabled==true;pending=nil
    if ns.ERB.ApplyAll then ns.ERB:ApplyAll() end
    NS.SyncEllesmereClassHUD()
    if EUI.RefreshPage then EUI:RefreshPage() end
    return true
end
function NS.AddEllesmereClassHUDOptions(Row)
    Row({type='toggle',text='Forever Class HUD',tooltip='Enable native power, Rogue/Cat combo points, shifted Druid mana and Shaman totems for this character. Warlocks also get a bag shard counter. Turning off restores saved native settings.',
        getValue=NS.EllesmereClassHUDEnabled,setValue=function(value)
            local ok,message=NS.ApplyEllesmereClassHUD(value);if not ok and message then print('FHK: '..message) end
        end}, {type='label',text='Separate from theme; keeps native positions and motion.'})
end
driver:RegisterEvent('PLAYER_LOGIN')
driver:SetScript('OnEvent',function(_,event,item)
    if event=='PLAYER_LOGIN' then driver:UnregisterEvent('PLAYER_LOGIN') end
    if event=='PLAYER_REGEN_ENABLED' and pending then
        local todo=pending;pending=nil
        if todo.profile==ProfileName() then NS.ApplyEllesmereClassHUD(todo.enabled) end
    end
    if event=='GET_ITEM_INFO_RECEIVED' or event=='ITEM_DATA_LOAD_RESULT' then
        if not Public(item) or item~=ItemID() then return end
    end
    NS.SyncEllesmereClassHUD()
end)
if EUI.RegisterDarkModeRefresh then EUI.RegisterDarkModeRefresh(NS.SyncEllesmereClassHUD) end
SLASH_FHKCLASSHUD1='/fhkclasshud'
SlashCmdList.FHKCLASSHUD=function(input)
    local cmd=tostring(input or ''):lower():match('^%s*(%S*)')
    if cmd=='on' or cmd=='off' then
        local ok,message=NS.ApplyEllesmereClassHUD(cmd=='on')
        print('FHK: '..(ok and ('Class HUD '..cmd..'.') or message));return
    end
    print('FHK class HUD: '..(NS.EllesmereClassHUDEnabled() and 'on' or 'off')..'. Use /fhkclasshud on or off.')
end
