-- Pet food (FOREVER_HUNTER_COVERAGE_PLAN.md sections 3 and 10.3 item 5). Player report:
-- Feed Pet shows every bag item. The Pet Food Row is on by default (player request); the
-- button and Grey Out are opt-in:
--   Food Button: one click feeds the best edible stack (closest to the pet's level); right
--     click opens a chooser with every edible stack. Secure macro buttons, built and
--     re-assigned out of combat only; a state driver hides them in combat and without a pet.
--   Feeding View: Blizzard's own bags already grey out what Feed Pet cannot take (player).
--     Ellesmere's bag buttons are the same ContainerFrameItemButtonTemplate but are never told
--     the item context changed, so this refreshes them through the native method, giving the
--     exact Blizzard overlay. Blizzard's rule (Blizzard_FrameXMLUtil/ItemUtil.lua): the context
--     is Feed Pet when C_Spell.GetTargetSpellID() == 6991; an item matches when
--     C_PetInfo.CanPetEatItem(itemID). Blizzard's own bag frames are left to Blizzard.
--   Food Only (default; player, in-game screenshot: "change the inventory layout to only show
--     the food the pet can eat, shrinking the existing UI"): while Feed Pet waits for food,
--     Ellesmere's own bag grid draws a single "Pet Food" section, with no pinned, recent or
--     empty sections, and the window refits to it. Its category list still sets the
--     shortest height. Clicking a stack feeds it (the native item button). Everything is
--     restored when Feed Pet ends. Ellesmere's renderer is wrapped from here; no Ellesmere file
--     changes, and outside feeding the wrapper only checks one flag.
--   Pet Food Row (player, from an in-game screenshot of the category view): while Feed Pet
--     waits for food, a strip on top of the bags lists everything the pet can eat (raw meat
--     too); a click feeds that stack. Secure buttons, set out of combat only (Feed Pet cannot
--     be cast in combat). Works over Ellesmere's bags in any view, or Blizzard's.
--     Like Blizzard, Feed Pet opens the bags and closes them again if they were closed.
--   Feeding is never automatic (WoW only casts Feed Pet from a key press or click); the
--     Feed Pet Reminder in Warnings says when the pet needs food.
--   Food counts for the No / Low Pet Food warning (Warnings.lua).
--   Feed Pet timer: the food button sweeps while the pet is eating (Feed Pet Effect).
--   Auto-Buy Pet Food (opt-in): at a vendor, tops edible food up to a target count with the
--     Food Choice rule, at most two stacks per visit and never more than a tenth of your
--     money; every purchase is printed.
-- Edible = C_PetInfo.CanPetEatItem(itemID) is readably true; unreadable never counts.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end
local F={}
NS.PetFood=F
local FEED_PET=6991
local unpack=unpack or table.unpack
local MAX_CHOICES=8
-- view: 'filter' (Food Only) / 'row' (Pet Food Row) / 'rowgrey' (row plus Blizzard's overlay on
-- Ellesmere bags) / 'off'.
local DEFAULTS={button=false,view='filter',size=28,choice='level',autoBuy=false,buyKeep=20}
local ROW_SIZE,ROW_MAX=36,12
-- Food far below the pet pleases it little (Classic rule; unverified on Forever): Cheapest
-- only picks food at most this many levels below the pet, else falls back to the closest.
local CHEAP_FLOOR=20
function NS.EllesmerePetFoodSettings()
    if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end
    local s=FHKEllesmereDB.petFood
    if type(s)~='table' then s={};FHKEllesmereDB.petFood=s end
    -- Once: the row replaced Grey Out / Food Only and is on by default (player request).
    if not s.viewRow then
        s.view=(s.view=='grey' or s.view=='rowgrey') and 'rowgrey' or 'row'
        s.viewRow=true
    end
    -- Once: Food Only replaced the plain row as the default (player: shrink the bags instead).
    if not s.viewFilter then
        if s.view=='row' then s.view='filter' end
        s.viewFilter=true
    end
    for k,v in pairs(DEFAULTS) do if s[k]==nil then s[k]=v end end
    return s
end
local function ViewOn() local v=NS.EllesmerePetFoodSettings().view;return v=='filter' or v=='row' or v=='rowgrey' end

local function Plain(v) return not (issecretvalue and issecretvalue(v)) end
local function Read(fn,...)
    if type(fn)~='function' then return end
    local ok,a,b,c,d,e,f,g,h,i,j=pcall(fn,...)
    if ok and Plain(a) then return a,b,c,d,e,f,g,h,i,j end
end
local function Num(v) return Plain(v) and type(v)=='number' and v==v end
local function InCombat() return Read(_G.InCombatLockdown)~=false end
local function Hunter() return select(2,Read(_G.UnitClass,'player'))=='HUNTER' end
local function FeedName()
    local name=C_Spell and Read(C_Spell.GetSpellName,FEED_PET)
    if type(name)~='string' then name=Read(_G.GetSpellInfo,FEED_PET) end
    return type(name)=='string' and name or nil
end
local function FeedKnown()
    return Read(C_SpellBook and C_SpellBook.IsSpellKnown,FEED_PET)==true or Read(_G.IsPlayerSpell,FEED_PET)==true
end

-------------------------------------------------------------------------------
-- Bag scan, cached until the bags or the pet change.
-------------------------------------------------------------------------------
-- The bag list is rebuilt after bag changes; what the pet eats is kept until the pet
-- changes (its diet), so a bag update costs one CanPetEatItem per new item, not per slot.
local cache,edibleById=nil,{}
-- One purchase per vendor visit: bag counts lag behind a purchase, so a retry could buy twice.
local boughtThisVisit=false
function F.Invalidate(petChanged) cache=nil;if petChanged then edibleById={} end end
local function Edible(id)
    local known=edibleById[id]
    if known~=nil then return known end
    local eats=Read(C_PetInfo and C_PetInfo.CanPetEatItem,id)
    -- Unreadable answers are not remembered, so they are asked again next scan.
    if eats==true or eats==false then edibleById[id]=eats end
    return eats==true
end
F.Edible=Edible
local function ItemFacts(id)
    local get=C_Item and C_Item.GetItemInfo or _G.GetItemInfo
    local _,_,_,level,_,_,_,_,_,_,price=Read(get,id)
    return Num(level) and level or nil,Num(price) and price or nil
end
function F.Scan()
    if cache then return cache end
    local list={}
    local C=C_Container
    if Read(_G.UnitExists,'pet')==true and C and C.GetContainerNumSlots then
        for bag=0,(_G.NUM_BAG_SLOTS or 4) do
            local slots=Read(C.GetContainerNumSlots,bag)
            for slot=1,Num(slots) and slots or 0 do
                local info=Read(C.GetContainerItemInfo,bag,slot)
                local id=type(info)=='table' and info.itemID or Read(C.GetContainerItemID,bag,slot)
                if Num(id) and Edible(id) then
                    local count=type(info)=='table' and Num(info.stackCount) and info.stackCount or 1
                    local level,price=ItemFacts(id)
                    list[#list+1]={bag=bag,slot=slot,id=id,count=count,level=level,price=price,
                        icon=type(info)=='table' and info.iconFileID or nil}
                end
            end
        end
    end
    cache=list
    return list
end
function NS.EllesmerePetFoodCount()
    local n=0
    for _,food in ipairs(F.Scan()) do n=n+food.count end
    return n
end
-- Best: closest item level to the pet's (food near the pet's level pleases it most);
-- ties go to the bigger stack. Unknown levels sort last.
function F.Rank(list,petLevel)
    local sorted={}
    for i,food in ipairs(list) do sorted[i]=food end
    local function Gap(food) return food.level and Num(petLevel) and math.abs(food.level-petLevel) or 1000 end
    table.sort(sorted,function(a,b)
        local ga,gb=Gap(a),Gap(b)
        if ga~=gb then return ga<gb end
        if a.count~=b.count then return a.count>b.count end
        return a.bag*100+a.slot<b.bag*100+b.slot
    end)
    return sorted
end
-- Cheapest (player request): the lowest vendor value that still pleases the pet; then the
-- lower level, then the smaller stack, so odd leftovers get used up first.
function F.RankCheap(list,petLevel)
    local fit={}
    for _,food in ipairs(list) do
        if food.level and Num(petLevel) and food.level>=petLevel-CHEAP_FLOOR then fit[#fit+1]=food end
    end
    if #fit==0 then return F.Rank(list,petLevel) end
    table.sort(fit,function(a,b)
        local pa,pb=a.price or math.huge,b.price or math.huge
        if pa~=pb then return pa<pb end
        if a.level~=b.level then return a.level<b.level end
        if a.count~=b.count then return a.count<b.count end
        return a.bag*100+a.slot<b.bag*100+b.slot
    end)
    return fit
end
function F.Ranked()
    local petLevel=Read(_G.UnitLevel,'pet')
    if NS.EllesmerePetFoodSettings().choice=='cheap' then return F.RankCheap(F.Scan(),petLevel) end
    return F.Rank(F.Scan(),petLevel)
end
function F.Best() return F.Ranked()[1] end
local function Macro(food)
    local name=FeedName()
    if not (food and name) then return '' end
    return '/cast '..name..'\n/use '..food.bag..' '..food.slot
end
F.Macro=Macro

-------------------------------------------------------------------------------
-- Food Button and chooser.
-------------------------------------------------------------------------------
local C=NS.Colours or {}
local MOOD={[1]=C.unhappy or {1,.3,.25},[2]=C.content or {1,.82,0},[3]=C.happy or {.30,.85,.30}}
local button,choices,chooserOpen,pending=nil,{},false,false
local function Font(fs,size)
    local path=EUI.GetFontPath and EUI.GetFontPath('extras') or 'Fonts\\FRIZQT__.TTF'
    fs:SetFont(path,size,'OUTLINE')
end
local function Square(b,size)
    b:SetSize(size,size)
    b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetAllPoints();b.icon:SetTexCoord(.08,.92,.08,.92)
    b.border=EUI.MakeBorder and EUI.MakeBorder(b,0,0,0,1) or nil
    b.count=b:CreateFontString(nil,'OVERLAY');Font(b.count,10);b.count:SetPoint('BOTTOMRIGHT',b,'BOTTOMRIGHT',-1,2)
end
local function Tooltip(b)
    if not (GameTooltip and b.food) then return end
    GameTooltip:SetOwner(b,'ANCHOR_RIGHT')
    if GameTooltip.SetBagItem then GameTooltip:SetBagItem(b.food.bag,b.food.slot) end
    GameTooltip:Show()
end
local function Position()
    if not button or InCombat() then return end
    local p=NS.EllesmerePetFoodSettings().position
    button:ClearAllPoints()
    if p then button:SetPoint(p.point,UIParent,p.relPoint or p.point,p.x or 0,p.y or 0);return end
    local uf=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIUnitFrames
    local pf=uf and uf.frames and uf.frames.pet
    if pf then button:SetPoint('LEFT',pf,'RIGHT',6,0) else button:SetPoint('CENTER',UIParent,'CENTER',-160,-220) end
end
F.Position=Position
local function Visibility(b,on)
    if not (RegisterStateDriver and UnregisterStateDriver) then b:SetShown(on);return end
    if on then RegisterStateDriver(b,'visibility','[combat][nopet][@pet,dead] hide; show')
    else UnregisterStateDriver(b,'visibility');b:Hide() end
end
local function CloseChooser()
    chooserOpen=false
    for _,c in ipairs(choices) do Visibility(c,false) end
end
local function OpenChooser()
    if InCombat() or not button then return end
    local s=NS.EllesmerePetFoodSettings()
    local ranked=F.Rank(F.Scan(),Read(_G.UnitLevel,'pet'))
    if s.choice=='cheap' then
        -- The chooser lists everything; Cheapest only reorders it.
        local cheap,seen=F.RankCheap(F.Scan(),Read(_G.UnitLevel,'pet')),{}
        for _,food in ipairs(cheap) do seen[food]=true end
        for _,food in ipairs(ranked) do if not seen[food] then cheap[#cheap+1]=food end end
        ranked=cheap
    end
    chooserOpen=true
    for i=1,math.min(MAX_CHOICES,#ranked) do
        local c=choices[i]
        if not c then
            c=CreateFrame('Button','FHKEllesmerePetFoodChoice'..i,UIParent,'SecureActionButtonTemplate')
            c:RegisterForClicks('AnyUp');c:SetAttribute('type','macro')
            Square(c,s.size);c:SetFrameStrata('DIALOG')
            c:SetScript('OnEnter',Tooltip);c:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
            c:HookScript('PostClick',function() if not InCombat() then CloseChooser() end end)
            choices[i]=c
        end
        local food=ranked[i]
        c.food=food;c:SetSize(s.size,s.size)
        c:SetAttribute('macrotext',Macro(food))
        c.icon:SetTexture(food.icon);c.count:SetText(food.count>1 and tostring(food.count) or '')
        c:ClearAllPoints();c:SetPoint('BOTTOM',button,'TOP',0,4+(i-1)*(s.size+3))
        Visibility(c,true)
    end
    for i=#ranked+1,#choices do Visibility(choices[i],false);choices[i].food=nil end
end
local FEED_EFFECT=1539
function F.FeedTimer()
    if not (button and button.cooldown) then return end
    local name=C_Spell and Read(C_Spell.GetSpellName,FEED_EFFECT)
    local aura=type(name)=='string' and Read(C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName,'pet',name,'HELPFUL')
    if type(aura)=='table' and Num(aura.expirationTime) and Num(aura.duration) and aura.duration>0 then
        button.cooldown:SetCooldown(aura.expirationTime-aura.duration,aura.duration)
    elseif button.cooldown.Clear then button.cooldown:Clear() end
end
function F.Refresh()
    if not button then return end
    if InCombat() then pending=true;return end
    pending=false
    local s=NS.EllesmerePetFoodSettings()
    local best=F.Best()
    button.food=best
    button:SetSize(s.size,s.size)
    button:SetAttribute('macrotext',Macro(best))
    if best then
        button.icon:SetTexture(best.icon);button.icon:SetDesaturated(false);button.icon:SetAlpha(1)
        button.count:SetText(tostring(NS.EllesmerePetFoodCount()))
    else
        -- No food: the Feed Pet icon, greyed, with a zero. Clicking does nothing.
        button.icon:SetTexture(C_Spell and Read(C_Spell.GetSpellTexture,FEED_PET) or nil)
        button.icon:SetDesaturated(true);button.icon:SetAlpha(.5);button.count:SetText('0')
    end
    local mood=C_PetInfo and Read(C_PetInfo.GetPetHappiness)
    local c=Num(mood) and MOOD[mood]
    if button.border and button.border.SetColor then
        if c then button.border:SetColor(c[1],c[2],c[3],1) else button.border:SetColor(0,0,0,1) end
    end
    if chooserOpen then OpenChooser() end
end
local function BuildButton()
    if button then return end
    local s=NS.EllesmerePetFoodSettings()
    button=CreateFrame('Button','FHKEllesmerePetFoodButton',UIParent,'SecureActionButtonTemplate')
    button:RegisterForClicks('AnyUp')
    button:SetAttribute('type1','macro')
    Square(button,s.size)
    button.cooldown=CreateFrame('Cooldown',nil,button,'CooldownFrameTemplate');button.cooldown:SetAllPoints()
    button:SetScript('OnEnter',Tooltip)
    button:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
    button:HookScript('OnClick',function(_,mouse)
        if mouse=='RightButton' and not InCombat() then if chooserOpen then CloseChooser() else OpenChooser() end end
    end)
    Position()
    if EUI.MakeUnlockElement and EUI.RegisterUnlockElements then
        EUI:RegisterUnlockElements({EUI.MakeUnlockElement({key='FHKEllesmerePetFood',label='Pet Food',group='Unit Frames',order=640,
            getFrame=function() return button end,
            getSize=function() local size=NS.EllesmerePetFoodSettings().size;return size,size end,
            isHidden=function() return not NS.EllesmerePetFoodSettings().button end,
            savePos=function(_,point,relPoint,x,y) NS.EllesmerePetFoodSettings().position={point=point,relPoint=relPoint,x=x,y=y} end,
            loadPos=function() return NS.EllesmerePetFoodSettings().position end,
            clearPos=function() NS.EllesmerePetFoodSettings().position=nil end,
            applyPos=Position,noResize=true,
        })},'EllesmereUIUnitFrames')
    end
end

-------------------------------------------------------------------------------
-- Feeding View: Blizzard's Feed Pet context on Ellesmere's bag buttons.
-------------------------------------------------------------------------------
local touched,feeding,openedBags,bagsHooked={},false,false,false
local watch -- safety re-check while feeding, in case a cancel fires no event
local function FeedTargeting()
    local id=C_Spell and Read(C_Spell.GetTargetSpellID)
    if Num(id) then return id==FEED_PET end
    -- Older clients without GetTargetSpellID: Feed Pet must be both targeting and current.
    if Read(_G.SpellIsTargeting)~=true then return false end
    local current=Read(C_Spell and C_Spell.IsCurrentSpell,FEED_PET)
    if current==nil then current=Read(_G.IsCurrentSpell,FEED_PET) end
    return current==true
end
F.FeedTargeting=FeedTargeting
local function EllesmereRoot()
    local root=rawget(_G,'EUI_Bags')
    return type(root)=='table' and root or nil
end
local function EllesmereButtons(fn)
    local root=EllesmereRoot()
    if not root or Read(root.IsShown,root)~=true then return end
    local function Walk(frame,depth)
        if depth>6 then return end
        local kids={pcall(frame.GetChildren,frame)}
        if not kids[1] then return end
        for k=2,#kids do
            local child=kids[k]
            local kind=Read(child.GetObjectType,child)
            if (kind=='ItemButton' or kind=='Button') and child.IconBorder then fn(child)
            else Walk(child,depth+1) end
        end
    end
    Walk(root,1)
end
local function ButtonItem(b)
    local bag=Read(b.GetBagID,b)
    if not Num(bag) then local parent=Read(b.GetParent,b);bag=parent and Read(parent.GetID,parent) end
    local slot=Read(b.GetID,b)
    if not (Num(bag) and Num(slot) and C_Container) then return end
    return Read(C_Container.GetContainerItemID,bag,slot)
end
-- The native method when the button has it (Blizzard's exact overlay); otherwise the same
-- look drawn by us: black at 0.8 over what the pet will not eat.
local function Mark(b,on)
    if type(b.UpdateItemContextMatching)=='function' and b.ItemContextOverlay then
        pcall(b.UpdateItemContextMatching,b)
        touched[b]=on or nil
        return
    end
    local id=on and ButtonItem(b)
    local mismatch=on and Num(id) and not Edible(id)
    if mismatch then
        if not b.fhkFoodShade then
            b.fhkFoodShade=b:CreateTexture(nil,'OVERLAY',nil,7);b.fhkFoodShade:SetAllPoints();b.fhkFoodShade:SetColorTexture(0,0,0,.8)
        end
        b.fhkFoodShade:Show();touched[b]=true
    elseif b.fhkFoodShade then b.fhkFoodShade:Hide();touched[b]=nil end
end
-- Every food the pet eats, in Food Choice order (Cheapest lists the out-of-range rest after).
function F.Ordered()
    local petLevel=Read(_G.UnitLevel,'pet')
    local ranked=F.Rank(F.Scan(),petLevel)
    if NS.EllesmerePetFoodSettings().choice~='cheap' then return ranked end
    local cheap,seen=F.RankCheap(F.Scan(),petLevel),{}
    for _,food in ipairs(cheap) do seen[food]=true end
    for _,food in ipairs(ranked) do if not seen[food] then cheap[#cheap+1]=food end end
    return cheap
end
local row,rowButtons,restorePending=nil,{},false
local function RowHost()
    local root=EllesmereRoot()
    if root and Read(root.IsShown,root)==true then return root end
    for _,name in ipairs({'ContainerFrameCombinedBags','ContainerFrame1'}) do
        local f=rawget(_G,name)
        if type(f)=='table' and Read(f.IsShown,f)==true then return f end
    end
end
local function BuildRow()
    if row then return end
    row=CreateFrame('Frame','FHKEllesmerePetFoodRow',UIParent)
    row:SetFrameStrata('HIGH');row:EnableMouse(true);row:Hide()
    row.bg=row:CreateTexture(nil,'BACKGROUND');row.bg:SetAllPoints();row.bg:SetColorTexture(.06,.08,.10,.96)
    row.border=EUI.MakeBorder and EUI.MakeBorder(row,1,1,1,.15) or nil
    row.title=row:CreateFontString(nil,'OVERLAY');Font(row.title,12)
    row.title:SetPoint('TOPLEFT',row,'TOPLEFT',10,-8)
    if EUI.GetAccentColor then local r,g,b=EUI.GetAccentColor();if r then row.title:SetTextColor(r,g,b) end end
    row.empty=row:CreateFontString(nil,'OVERLAY');Font(row.empty,11)
    row.empty:SetPoint('TOPLEFT',row.title,'BOTTOMLEFT',0,-10);row.empty:SetTextColor(.6,.6,.6)
end
local function RowButton(i)
    local b=rowButtons[i]
    if b then return b end
    b=CreateFrame('Button','FHKEllesmerePetFoodRowItem'..i,row,'SecureActionButtonTemplate')
    b:RegisterForClicks('AnyUp');b:SetAttribute('type','macro')
    Square(b,ROW_SIZE)
    b:SetScript('OnEnter',Tooltip);b:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
    rowButtons[i]=b
    return b
end
function F.ShowRow()
    if InCombat() then return end
    BuildRow()
    local list=F.Ordered()
    local shown=math.min(#list,ROW_MAX*3)
    local perLine=math.max(1,math.min(ROW_MAX,shown))
    local lines=math.max(1,math.ceil(shown/perLine))
    row.title:SetText(shown>0 and ('Pet Food ('..shown..')') or 'Pet Food')
    row.empty:SetText(shown>0 and '' or 'Nothing in your bags your pet eats')
    for i=1,shown do
        local b,food=RowButton(i),list[i]
        b.food=food
        -- While Feed Pet waits for food, /use on a bag slot feeds that item.
        b:SetAttribute('macrotext','/use '..food.bag..' '..food.slot)
        b.icon:SetTexture(food.icon);b.count:SetText(food.count>1 and tostring(food.count) or '')
        b:ClearAllPoints()
        local col,line=(i-1)%perLine,math.floor((i-1)/perLine)
        b:SetPoint('TOPLEFT',row,'TOPLEFT',10+col*(ROW_SIZE+4),-28-line*(ROW_SIZE+4))
        b:Show()
    end
    for i=shown+1,#rowButtons do rowButtons[i]:Hide();rowButtons[i].food=nil end
    local width=math.max(220,20+perLine*(ROW_SIZE+4)-4)
    local height=shown>0 and (36+lines*(ROW_SIZE+4)) or 56
    local host=RowHost()
    if host then width=math.max(width,Read(host.GetWidth,host) or 0) end
    row:SetSize(width,height)
    row:ClearAllPoints()
    if host then
        -- Above the bags, or below them when the bags sit at the top of the screen.
        local top,screen=Read(host.GetTop,host),Read(UIParent.GetTop,UIParent)
        if Num(top) and Num(screen) and top+6+height>screen then row:SetPoint('TOPLEFT',host,'BOTTOMLEFT',0,-6)
        else row:SetPoint('BOTTOMLEFT',host,'TOPLEFT',0,6) end
    else row:SetPoint('CENTER',UIParent,'CENTER',0,120) end
    row:Show()
end
function F.HideRow()
    if not row then return end
    if InCombat() then restorePending=true;return end
    restorePending=false
    row:Hide()
end
-------------------------------------------------------------------------------
-- Food Only: Ellesmere's renderer, fed only what the pet eats.
-------------------------------------------------------------------------------
local filterOn,renderWrapped=false,nil -- renderWrapped: the Ellesmere bags table we wrapped
local function BagsNS() local m=EUI._ModuleNS;return type(m)=='table' and type(m.EllesmereUIBags)=='table' and m.EllesmereUIBags or nil end
local function BagsProfile() return type(EUI._bagsDB)=='table' and type(EUI._bagsDB.profile)=='table' and EUI._bagsDB.profile or {} end
-- Ellesmere's slot data ({bag, slot, info, categoryIndex, ...}) for edible items only.
function F.FoodSlots(list)
    local out={}
    for _,d in ipairs(type(list)=='table' and list or {}) do
        local id=type(d)=='table' and type(d.info)=='table' and d.info.itemID
        if Num(id) and Edible(id) then out[#out+1]=d end
    end
    return out
end
-- A plain category that All Items draws (not pinned, recent, grouped, a set or hidden) carries
-- the one Pet Food section; it is renamed only for the length of the render.
function F.Carrier(cats,food)
    local hidden=BagsProfile().bagHiddenInAllItems or {}
    local function Plain(c) return type(c)=='table' and not (c.isPinned or c.isRecent or c.groupName or c.isEquipSet or c.isSetGear or c.isReagentBag) and not hidden[c._defaultName] end
    for _,d in ipairs(food) do if Plain(cats[d.categoryIndex]) then return d.categoryIndex end end
    for i,c in ipairs(cats) do if Plain(c) then return i end end
end
local function Copy(d,k) local c={};for key,v in pairs(d) do c[key]=v end;c.categoryIndex=k;return c end
function F.WrapRender()
    local bns=BagsNS()
    if not bns then return false end
    if renderWrapped==bns then return true end
    if type(bns.RenderGridView)~='function' or type(bns.GetSelection)~='function' then return false end
    renderWrapped=bns
    local grid,list,selection=bns.RenderGridView,bns.RenderListView,bns.GetSelection
    bns.RenderGridView=function(tempItems,displayItems,emptySlots,child,columns,gridW,gridPadX,showPinned,pinnedSet,...)
        if not filterOn then return grid(tempItems,displayItems,emptySlots,child,columns,gridW,gridPadX,showPinned,pinnedSet,...) end
        local cm=rawget(_G,'EUI_CategoryManager')
        local cats=cm and type(cm.GetCategories)=='function' and cm:GetCategories()
        local root=EllesmereRoot()
        local food=F.FoodSlots(tempItems)
        if type(cats)~='table' or not root then return grid(food,food,{},child,columns,gridW,gridPadX,false,pinnedSet,...) end
        -- The All Items layout, whatever tab is open: one titled section, nothing else.
        local k=F.Carrier(cats,food)
        local items={}
        for i,d in ipairs(food) do items[i]=k and Copy(d,k) or d end
        local recent,canAssign,name,user=root._recentItems,cm.CanAssignToCategory,k and cats[k].name,{}
        for i,c in ipairs(cats) do if c.isUserCreated then user[i]=true;c.isUserCreated=nil end end
        root._recentItems=nil
        cm.CanAssignToCategory=function() return false end
        if k then cats[k].name='Pet Food' end
        bns.GetSelection=function() return 0,nil end
        local ok,y=pcall(grid,items,items,{},child,columns,gridW,gridPadX,false,pinnedSet,...)
        bns.GetSelection=selection
        if k then cats[k].name=name end
        cm.CanAssignToCategory=canAssign
        root._recentItems=recent
        for i in pairs(user) do cats[i].isUserCreated=true end
        if not ok then
            if geterrorhandler then geterrorhandler()(y) end
            return grid(tempItems,displayItems,emptySlots,child,columns,gridW,gridPadX,showPinned,pinnedSet,...)
        end
        return y
    end
    if type(list)=='function' then
        bns.RenderListView=function(items,opts,...)
            if not filterOn or type(opts)~='table' then return list(items,opts,...) end
            local copy={}
            for key,v in pairs(opts) do copy[key]=v end
            copy.emptySlots,copy.pinned,copy.recent=nil,nil,nil
            return list(F.FoodSlots(items),copy,...)
        end
    end
    return true
end
-- Ellesmere only grows its window while open; a fresh size lets it refit both ways.
local function Refit(root)
    root._asCols,root._asMaxGridW,root._asMaxH=nil,nil,nil
    if Read(root.IsShown,root)==true and type(root.RefreshInventory)=='function' then pcall(root.RefreshInventory,root) end
end
function F.Filter(on,refresh)
    local root=EllesmereRoot()
    on=on and root and F.WrapRender() or false
    if on==filterOn then return end
    filterOn=on
    if not root then return end
    if refresh~=false then Refit(root) else root._asCols,root._asMaxGridW,root._asMaxH=nil,nil,nil end
end
F.Filtering=function() return filterOn end
function F.Mark()
    local view=NS.EllesmerePetFoodSettings().view
    -- Without Ellesmere's bag renderer (Blizzard bags, another Ellesmere version) Food Only
    -- falls back to the Pet Food row.
    if view=='filter' then F.Filter(true);if filterOn then return end end
    F.ShowRow()
    if view=='rowgrey' then EllesmereButtons(function(b) Mark(b,true) end) end
end
function F.Unmark()
    for b in pairs(touched) do Mark(b,false) end
    touched={}
    F.HideRow()
    F.Filter(false)
end
local shownAt=0
function F.UpdateView()
    local on=ViewOn() and FeedTargeting()
    local root=EllesmereRoot()
    if root and not root.fhkFoodShowHook and root.HookScript then
        root.fhkFoodShowHook=pcall(root.HookScript,root,'OnShow',function() shownAt=GetTime and GetTime() or 0 end)
    end
    if on and not feeding then
        feeding=true
        local now=GetTime and GetTime() or 0
        -- Filter before the bags open, so their first draw is already food only.
        if root and NS.EllesmerePetFoodSettings().view=='filter' then F.Filter(true,Read(root.IsShown,root)==true) end
        if root and Read(root.IsShown,root)~=true then
            -- Like Blizzard's OpenAllBags on item targeting: open the bags for feeding.
            if type(OpenAllBags)=='function' then pcall(OpenAllBags) end
            openedBags=true
        elseif root and now-shownAt<.25 then
            -- Blizzard's own handler opened them a moment ago, for this cast.
            openedBags=true
        end
        if root and not bagsHooked and type(root.RefreshInventory)=='function' then
            bagsHooked=pcall(hooksecurefunc,root,'RefreshInventory',function() if feeding and not filterOn then F.Mark() end end)
        end
        F.Mark()
        if C_Timer and C_Timer.After then C_Timer.After(0,function() if feeding then F.Mark() end end) end
        if not watch and C_Timer and C_Timer.NewTicker then
            watch=C_Timer.NewTicker(.5,function() if not FeedTargeting() then F.UpdateView() end end)
        end
    elseif not on and feeding then
        feeding=false
        if watch then watch:Cancel();watch=nil end
        -- Bags we opened close without redrawing the full layout first.
        local closing=openedBags and root and Read(root.IsShown,root)==true and type(ToggleAllBags)=='function'
        if closing then F.Filter(false,false) end
        F.Unmark()
        -- Ellesmere replaces ToggleAllBags; closing through it keeps its own state right.
        if closing then pcall(ToggleAllBags) end
        openedBags=false
    elseif on then F.Mark() end
end

-------------------------------------------------------------------------------
-- Auto-Buy Pet Food at vendors.
-------------------------------------------------------------------------------
function F.MerchantFood()
    local list={}
    local n=Read(_G.GetMerchantNumItems)
    for i=1,Num(n) and n or 0 do
        local id=Read(_G.GetMerchantItemID,i)
        local name,_,price,quantity,available,purchasable,_,extended=Read(_G.GetMerchantItemInfo,i)
        if Num(id) and Num(price) and price>0 and purchasable~=false and not extended and Edible(id) then
            local level=ItemFacts(id)
            list[#list+1]={index=i,id=id,price=price,quantity=Num(quantity) and quantity>0 and quantity or 1,
                available=Num(available) and available or -1,level=level,count=0,bag=0,slot=i,name=name}
        end
    end
    return list
end
function F.AutoBuy()
    local s=NS.EllesmerePetFoodSettings()
    if not s.autoBuy or boughtThisVisit or Read(_G.UnitExists,'pet')~=true then return end
    local have=NS.EllesmerePetFoodCount()
    local need=(Num(s.buyKeep) and s.buyKeep or 20)-have
    if need<=0 then return end
    local offers=F.MerchantFood()
    if #offers==0 then return end
    local petLevel=Read(_G.UnitLevel,'pet')
    local pick=(s.choice=='cheap' and F.RankCheap(offers,petLevel) or F.Rank(offers,petLevel))[1]
    if not pick then return end
    local stack=Read(_G.GetMerchantItemMaxStack,pick.index)
    stack=Num(stack) and stack>0 and stack or 20
    local amount=math.min(need,stack*2)
    if pick.available>=0 then amount=math.min(amount,pick.available) end
    local each=pick.price/pick.quantity
    local money=Read(_G.GetMoney)
    if not Num(money) then return end
    amount=math.min(amount,math.floor(money*.1/each))
    if amount<=0 then return end
    local bought=0
    while bought<amount do
        local batch=math.min(stack,amount-bought)
        if not pcall(_G.BuyMerchantItem,pick.index,batch) then break end
        bought=bought+batch
    end
    if bought>0 then boughtThisVisit=true end
    if bought>0 and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        local link=Read(_G.GetMerchantItemLink,pick.index) or pick.name or 'pet food'
        local cost=math.floor(each*bought+.5)
        local coins=type(GetCoinTextureString)=='function' and Read(GetCoinTextureString,cost) or (cost..'c')
        DEFAULT_CHAT_FRAME:AddMessage(('|cffdda880FHK|r Bought %d x %s for your pet (%s).'):format(bought,link,tostring(coins)))
    end
    F.Invalidate()
    return bought,pick
end

-------------------------------------------------------------------------------
-- Events: only for the parts that are on.
-------------------------------------------------------------------------------
local driver
local function OnEvent(_,event,unit)
    if (event=='UNIT_PET' and unit~='player') or (event=='UNIT_LEVEL' and unit~='pet') then return end
    if event=='BAG_UPDATE_DELAYED' or event=='UNIT_LEVEL' then F.Invalidate()
    elseif event=='UNIT_PET' or event=='PLAYER_ENTERING_WORLD' then F.Invalidate(true) end
    if event=='CURRENT_SPELL_CAST_CHANGED' or event=='UPDATE_SPELL_TARGET_ITEM_CONTEXT' or event=='BAG_UPDATE_DELAYED' then F.UpdateView() end
    if event=='MERCHANT_SHOW' then
        boughtThisVisit=false;F.AutoBuy()
        -- Vendor item data can arrive just after the window opens: one more try.
        if C_Timer and C_Timer.After then C_Timer.After(.6,function() F.AutoBuy() end) end
        return
    end
    if event=='MERCHANT_CLOSED' then boughtThisVisit=false;return end
    if event=='UNIT_AURA' then F.FeedTimer();return end
    if event=='PLAYER_REGEN_DISABLED' then if chooserOpen then chooserOpen=false end return end
    -- A row that should have closed in combat closes as soon as combat ends.
    if event=='PLAYER_REGEN_ENABLED' and restorePending then F.HideRow() end
    if event~='CURRENT_SPELL_CAST_CHANGED' and event~='UPDATE_SPELL_TARGET_ITEM_CONTEXT' then
        if event=='PLAYER_REGEN_ENABLED' and not pending then return end
        F.Refresh()
    end
end
F.OnEvent=OnEvent
function NS.SyncEllesmerePetFood()
    local s=NS.EllesmerePetFoodSettings()
    local hunter=Hunter()
    if driver then driver:UnregisterAllEvents() end
    if not ViewOn() and feeding then feeding=false;F.Unmark() end
    if button and not (s.button and hunter) then
        if InCombat() then pending=true else Visibility(button,false);CloseChooser() end
    end
    if not hunter or not (s.button or ViewOn() or s.autoBuy) then return end
    if not driver then driver=CreateFrame('Frame');driver:SetScript('OnEvent',OnEvent) end
    driver:RegisterEvent('BAG_UPDATE_DELAYED');driver:RegisterEvent('PLAYER_ENTERING_WORLD')
    if driver.RegisterUnitEvent then driver:RegisterUnitEvent('UNIT_PET','player');driver:RegisterUnitEvent('UNIT_LEVEL','pet')
    else driver:RegisterEvent('UNIT_PET');driver:RegisterEvent('UNIT_LEVEL') end
    if s.autoBuy then driver:RegisterEvent('MERCHANT_SHOW');driver:RegisterEvent('MERCHANT_CLOSED') end
    if ViewOn() then
        driver:RegisterEvent('CURRENT_SPELL_CAST_CHANGED');driver:RegisterEvent('PLAYER_REGEN_ENABLED');driver:RegisterEvent('PLAYER_REGEN_DISABLED')
        if not C_EventUtils or Read(C_EventUtils.IsEventValid,'UPDATE_SPELL_TARGET_ITEM_CONTEXT')==true then driver:RegisterEvent('UPDATE_SPELL_TARGET_ITEM_CONTEXT') end
    end
    if s.button then
        driver:RegisterEvent('PLAYER_REGEN_ENABLED');driver:RegisterEvent('PLAYER_REGEN_DISABLED')
        if driver.RegisterUnitEvent then driver:RegisterUnitEvent('UNIT_HAPPINESS','pet');driver:RegisterUnitEvent('UNIT_AURA','pet') end
        if InCombat() then pending=true;return end
        BuildButton();Position()
        Visibility(button,FeedKnown())
        F.Invalidate();F.Refresh()
    end
end

function NS.AddEllesmerePetFoodOptions(Row)
    local s=NS.EllesmerePetFoodSettings()
    local function Set(key,v) s[key]=v;NS.SyncEllesmerePetFood();if EUI.RefreshPage then EUI:RefreshPage() end end
    local button={type='toggle',text='Pet Food Button',tooltip='A button beside the pet frame: left click feeds your chosen food; right click lists every food your pet eats. Hidden in combat. The border shows happiness.',
        getValue=function() return s.button end,setValue=function(v) Set('button',v) end}
    button.cog={title='Pet Food Button',disabled=function() return not s.button end,disabledTooltip='Pet Food Button',rows={
        {type='slider',label='Size',min=20,max=44,step=1,get=function() return s.size end,set=function(v) Set('size',v) end}}}
    Row(button,{type='dropdown',text='Feeding View',values={filter='Food Only',row='Pet Food Row',rowgrey='Row + Grey Out',off='Off'},order={'filter','row','rowgrey','off'},
        tooltip='When you cast Feed Pet, your bags open. Food Only shrinks them to one Pet Food section: everything your pet eats, raw meat included. Click one to feed it. Pet Food Row keeps your normal bags and adds a strip of food beside them. Row + Grey Out also greys out the rest.',
        getValue=function() return s.view end,setValue=function(v) Set('view',v) end})
    Row({type='dropdown',text='Food Choice',values={level='Closest To Pet Level',cheap='Cheapest'},order={'level','cheap'},
        tooltip='Closest To Pet Level pleases your pet most. Cheapest uses the lowest vendor value that is no more than 20 levels below your pet.',
        disabled=function() return not (s.button or s.autoBuy) end,disabledTooltip='Pet Food Button',
        getValue=function() return s.choice end,setValue=function(v) Set('choice',v) end},
        {type='label',text='Move the button in Unlock Mode: Pet Food'})
    Row({type='toggle',text='Auto-Buy Pet Food',tooltip='At a vendor that sells food your pet eats, tops it up to the amount you set, using Food Choice. At most two stacks per visit and never more than a tenth of your money; every purchase is printed in chat.',
        getValue=function() return s.autoBuy end,setValue=function(v) Set('autoBuy',v) end},
        {type='slider',text='Keep Pet Food',min=5,max=100,step=5,
        disabled=function() return not s.autoBuy end,disabledTooltip='Auto-Buy Pet Food',
        getValue=function() return s.buyKeep end,setValue=function(v) s.buyKeep=v end})
end

local boot=CreateFrame('Frame')
boot:RegisterEvent('PLAYER_LOGIN')
boot:SetScript('OnEvent',function(self) self:UnregisterAllEvents();NS.SyncEllesmerePetFood() end)
