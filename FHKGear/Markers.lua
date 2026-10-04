-- FHK Gear: optional overlays on public Blizzard frames, held outside those frames.
-- Adapted from AutoGear; CC BY-NC-SA 4.0. See LICENSE.md.
if EUI_CLIENT_BLOCKED then return end
local _,ns=...
local S=ns.Safe
local GREEN,GOLD,GREY={0.25,1,0.35},{1,0.78,0.2},{0.6,0.6,0.6}
local marks=setmetatable({},{__mode='k'})
local bags=setmetatable({},{__mode='k'})
local textures={border='Interface\\Buttons\\UI-ActionButton-Border',arrow='Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up',
    diamond='Interface\\TargetingFrame\\UI-RaidTargetingIcon_3',plus='Interface\\Buttons\\UI-PlusButton-Up',coin='Interface\\MoneyFrame\\UI-GoldIcon'}
local function Paint(button,kind,colour,arrow)
    if not button then return end
    local record=marks[button]
    if not record then
        if not colour or S.Read(InCombatLockdown)==true then return end
        local texture=S.Read(button.CreateTexture,button,nil,'OVERLAY')
        if not texture then return end
        record={texture=texture,kind=kind};marks[button]=record
        S.Call('marker blend',texture.SetBlendMode,texture,'ADD')
    end
    if colour and S.Read(button.IsShown,button)==true then
        local c=ns.Char();local greed=colour==GOLD
        local style=greed and c.greedMarkerStyle or c.markerStyle
        if not textures[style] then style='border' end
        local texture=record.texture
        local size=S.Number(c.markerSize) and math.max(8,math.min(48,c.markerSize)) or 18
        local anchor=style=='border' and 'CENTER' or c.markerPosition
        if not ({TOPLEFT=true,TOPRIGHT=true,BOTTOMLEFT=true,BOTTOMRIGHT=true,CENTER=true})[anchor] then anchor='TOPRIGHT' end
        local x,y=S.Number(c.markerOffsetX) and c.markerOffsetX or 0,S.Number(c.markerOffsetY) and c.markerOffsetY or 0
        S.Call('marker texture',texture.SetTexture,texture,textures[style])
        S.Call('marker size',texture.SetSize,texture,style=='border' and size*2.3 or size,style=='border' and size*2.3 or size)
        if texture.ClearAllPoints then S.Call('marker anchors',texture.ClearAllPoints,texture) end
        S.Call('marker anchor',texture.SetPoint,texture,anchor,button,anchor,x,y)
        local custom=c.markerColours[greed and 'greed' or 'upgrade']
        if S.Table(custom) and S.Number(custom[1]) and S.Number(custom[2]) and S.Number(custom[3]) then colour=custom end
        local alpha=S.Number(c.markerOpacity) and math.max(0.1,math.min(1,c.markerOpacity)) or 1
        S.Call('marker colour',record.texture.SetVertexColor,record.texture,colour[1],colour[2],colour[3],alpha)
        S.Call('marker show',record.texture.Show,record.texture)
    else S.Call('marker hide',record.texture.Hide,record.texture) end
end
local function Clear(kind) for _,record in pairs(marks) do if not kind or record.kind==kind then S.Call('marker hide',record.texture.Hide,record.texture) end end end
local function AddLine(tooltip,link)
    if not ns.Char().tooltip or not S.Text(link) then return end
    local info=ns.Items.Read(link);if not info then return end
    if info.missing then
        S.Call('tooltip pending',tooltip.AddLine,tooltip,'Gear: item data pending',GREY[1],GREY[2],GREY[3])
        if ns.Actions and info.id then ns.Actions.Wait('tooltip',function() end,nil,nil,{[info.id]=true}) end
        return
    end
    if info.classID==6 and ns.Engine.AmmoVerdict then
        local text,better=ns.Engine.AmmoVerdict(info)
        if text then local colour=better and GREEN or GREY;S.Call('tooltip ammo',tooltip.AddLine,tooltip,'Gear: ' .. text,colour[1],colour[2],colour[3]) end
        return
    end
    if not ns.Engine.SLOTS[info.equipLoc] then return end
    local set=ns.Engine.Equipped()
    local delta,target,reason=ns.Engine.Verdict(info,set)
    local score,known,uncertain=ns.Engine.Score(info)
    local text,colour
    if delta then
        text='Gear: ' .. (reason=='Fills an empty slot' and reason or ('+%.1f upgrade'):format(delta))
        -- With the Hunter model, scores are in Agility units: also say what that is in damage per second.
        local w=ns.Weights.Current()
        if S.Table(w) and S.Number(w.scale) and w.scale>0 and reason~='Fills an empty slot' then text=text .. (' (+%.1f DPS)'):format(delta/w.scale) end
        colour=GREEN
    elseif not info.usable then text='Gear: blocked - ' .. (info.reason or 'requirements');colour=GREY
    else
        local worn=false;for _,entry in pairs(set) do if entry.link==link then worn=true end end
        text=S.Number(score) and ('Gear: %s, score %.1f'):format(worn and 'matches worn gear' or 'not an upgrade',score) or 'Gear: score unavailable'
        if reason and reason~='No supported upgrade' then text=text .. ' (' .. reason .. ')' end
        colour=GREY
    end
    if not known then text=text .. ' [estimate: ' .. (uncertain or 'ability context incomplete') .. ']' end
    -- Weapon skill below your cap: say so, and whether it becomes an upgrade once trained (it trains with use).
    local w=ns.Weights.Current()
    local skillLine
    if ns.HunterModel and S.Table(w) and w.scale and (ns.Engine.RANGED[info.equipLoc] or ns.Engine.MELEE[info.equipLoc]) then
        local slot=ns.Engine.RANGED[info.equipLoc] and 18 or (info.equipLoc=='INVTYPE_WEAPONOFFHAND' and 17 or 16)
        local note=ns.HunterModel.SkillNote(info,slot,w)
        if note and note.gain>0 then
            local itemScore=ns.Engine.Score(info,slot)
            local wornScore=set[slot] and set[slot].score or 0
            local after=S.Number(itemScore) and itemScore+note.gain>wornScore+0.0001
            skillLine=('%s skill %d/%d: +%.1f more once trained'):format(note.name,note.skill,note.cap,note.gain)
            if not delta and after then skillLine=skillLine .. ' (upgrade then)' end
        end
    end
    if ns.Char().ignore[info.id] or ns.Char().ignoreLinks[link] then text='Gear: Never Equip' end
    local slots=ns.Engine.Slots(info,ns.Weights.Current())
    if slots then for _,slot in ipairs(slots) do if ns.Char().locked[slot] and #slots==1 then text='Gear: slot locked' end end end
    S.Call('tooltip line',tooltip.AddLine,tooltip,text,colour[1],colour[2],colour[3])
    if skillLine then S.Call('tooltip skill line',tooltip.AddLine,tooltip,'Gear: ' .. skillLine,GOLD[1],GOLD[2],GOLD[3]) end
end
ns.AddTooltipLine=AddLine
-- The options preview paints its sample icons with the same code and settings as real markers.
function ns.PaintSample(button,greed) Paint(button,'preview',greed and GOLD or GREEN) end
local installed
function ns.InstallMarkers()
    if installed then return end
    local api=TooltipDataProcessor
    if api and Enum and Enum.TooltipDataType and type(api.AddTooltipPostCall)=='function' then
        installed=S.Call('tooltip hook',api.AddTooltipPostCall,Enum.TooltipDataType.Item,function(tooltip)
            if not ns.Char().tooltip and not ns.Char().markBags then return end
            local _,link=S.Read(tooltip and tooltip.GetItem,tooltip)
            if ns.DiscoverBagButton then ns.DiscoverBagButton(tooltip,link) end
            AddLine(tooltip,link)
        end)
    elseif GameTooltip and type(GameTooltip.HookScript)=='function' then
        installed=S.Call('tooltip hook',GameTooltip.HookScript,GameTooltip,'OnTooltipSetItem',function(tooltip)
            if ns.Char().tooltip or ns.Char().markBags then
                local _,link=S.Read(tooltip.GetItem,tooltip)
                if ns.DiscoverBagButton then ns.DiscoverBagButton(tooltip,link) end
                AddLine(tooltip,link)
            end
        end)
    end
end
local function VisitChoices(fn)
    local seen={}
    local function Visit(button) if button and not seen[button] and button.type=='choice' then seen[button]=true;fn(button) end end
    local rewards=QuestInfoFrame and QuestInfoFrame.rewardsFrame
    for _,button in pairs(rewards and rewards.RewardButtons or {}) do Visit(button) end
    for _,button in pairs(QuestInfoRewardsFrame and QuestInfoRewardsFrame.RewardButtons or {}) do Visit(button) end
    for i=1,10 do Visit(_G['QuestInfoItem' .. i]) end
end
function ns.ClearQuestMarks() Clear('quest') end
function ns.MarkQuestRewards(upgrades,vendor)
    if not ns.Char().markQuest then Clear('quest');return end
    if upgrades==nil then local _,_,_,u,v=ns.Engine.QuestChoice();upgrades,vendor=u,v end
    VisitChoices(function(button)
        local id=S.Read(button.GetID,button)
        Paint(button,'quest',upgrades and upgrades[id] and GREEN or vendor==id and GOLD or nil)
    end)
end
-- An optional bag addon can register its public item buttons without exposing private fields.
function ns.RegisterBagButton(button,bag,slot)
    if not button or not S.Number(bag) or not S.Number(slot) then return false end
    bags[button]={bag=bag,slot=slot};return true
end
function ns.DiscoverBagButton(tooltip,link)
    if not ns.Char().markBags or not S.Text(link) then return false end
    local owner=S.Read(tooltip and tooltip.GetOwner,tooltip)
    local bag,slot=S.Read(owner and owner.GetBagID,owner),S.Read(owner and owner.GetID,owner)
    if not S.Number(bag) or not S.Number(slot) or bag<0 or bag>(NUM_BAG_SLOTS or 4) or slot<1 then return false end
    if S.Read(C_Container and C_Container.GetContainerItemLink,bag,slot)~=link then return false end
    ns.RegisterBagButton(owner,bag,slot)
    local delta=ns.Engine.Verdict(ns.Items.Read(link,bag,slot))
    Paint(owner,'bag',delta and GREEN or nil,true)
    return true
end
function ns.MarkRoll(id,info,upgrade)
    if not ns.Char().markRoll then Clear('roll');return end
    for i=1,4 do local frame=_G['GroupLootFrame' .. i];if frame and S.Number(frame.rollID) and frame.rollID==id then Paint(frame,'roll',info and (upgrade and GREEN or GOLD) or nil) end end
end
function ns.ClearRollMark(id)
    for button,record in pairs(marks) do if record.kind=='roll' and S.Number(button.rollID) and button.rollID==id then S.Call('marker hide',record.texture.Hide,record.texture) end end
end
local characterSlots={[1]='Head',[2]='Neck',[3]='Shoulder',[5]='Chest',[6]='Waist',[7]='Legs',[8]='Feet',[9]='Wrist',[10]='Hands',
    [11]='Finger0',[12]='Finger1',[13]='Trinket0',[14]='Trinket1',[15]='Back',[16]='MainHand',[17]='SecondaryHand',[18]='Ranged'}
-- EllesmereUI Bags: its item buttons are ContainerFrameItemButtonTemplate children of the public EUI_Bags
-- frame (slot = button ID, bag = parent ID). Found on each of its refreshes, so marks show without a hover.
local function EllesmereBagButtons(frame,depth)
    if depth>6 then return end
    local kids={pcall(frame.GetChildren,frame)}
    if not kids[1] then return end
    for i=2,#kids do
        local child=kids[i]
        local kind=S.Read(child.GetObjectType,child)
        if (kind=='ItemButton' or kind=='Button') and child.IconBorder then
            local parent=S.Read(child.GetParent,child)
            local bag=S.Read(child.GetBagID,child)
            bag=S.Number(bag) and bag or S.Read(parent and parent.GetID,parent)
            local slot=S.Read(child.GetID,child)
            if S.Number(bag) and bag>=0 and bag<=(NUM_BAG_SLOTS or 4) and S.Number(slot) and slot>0 then ns.RegisterBagButton(child,bag,slot) end
        else EllesmereBagButtons(child,depth+1) end
    end
end
local ellesmereHooked=false
local function HookEllesmereBags()
    local root=rawget(_G,'EUI_Bags')
    if ellesmereHooked or type(root)~='table' or type(root.RefreshInventory)~='function' or type(hooksecurefunc)~='function' then return root end
    ellesmereHooked=S.Call('Ellesmere bags hook',hooksecurefunc,root,'RefreshInventory',function()
        if ns.Char().markBags then ns.RefreshMarkers() end
    end)
    return root
end
local markerQueued=false
function ns.RefreshMarkers()
    local c=ns.Char()
    if not c.markQuest then Clear('quest') end
    if not c.markRoll then Clear('roll') end
    if not c.markBags then Clear('bag') end
    if not c.markCharacter then Clear('character') end
    if not c.markBags and not c.markCharacter then return end
    if markerQueued then return end;markerQueued=true
    S.Call('marker timer',C_Timer and C_Timer.After,0.2,function()
        markerQueued=false
        local settings=ns.Char();if not settings.markBags and not settings.markCharacter then return end
        local jobs=ns.Engine.BagUpgrades();local targets,positions={},{}
        for _,job in ipairs(jobs) do targets[job.target]=true end
        for _,job in ipairs(ns.Engine.BagItems()) do if ns.Engine.Verdict(job.info) then positions[job.bag .. ':' .. job.slot]=true end end
        if settings.markBags then
            local root=HookEllesmereBags()
            if type(root)=='table' and S.Read(root.IsShown,root)==true then EllesmereBagButtons(root,1) end
            for i=1,13 do for j=1,36 do
                local button=_G['ContainerFrame' .. i .. 'Item' .. j]
                if button and S.Read(button.IsShown,button)==true then
                    local bag=S.Read(button.GetBagID,button)
                    local parent=S.Read(button.GetParent,button)
                    bag=S.Number(bag) and bag or S.Read(parent and parent.GetID,parent)
                    local slot=S.Read(button.GetID,button)
                    ns.RegisterBagButton(button,bag,slot)
                end
            end end
            for button,position in pairs(bags) do
                Paint(button,'bag',positions[position.bag .. ':' .. position.slot] and GREEN or nil,true)
            end
        end
        if settings.markCharacter then
            for slot,name in pairs(characterSlots) do Paint(_G['Character' .. name .. 'Slot'],'character',targets[slot] and GREEN or nil) end
        end
    end)
end
