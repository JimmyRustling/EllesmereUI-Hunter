-- Talent Planner (player, 2026-10-06: "auto talent training, where the user can customise by
-- level which talent they want to pick by pulling up a talent screen duplicate and assigning each
-- to a level ... so we don't have to build out presets"). Forever's talents are a Traits tree
-- (API audit 2026-10-06), drawn here from the client's own node positions, so every class and
-- every Forever change is covered without data of ours. Click a talent to add its next rank to
-- the plan; the plan is learned in order, one point per level from 10 (Classic rule, shown as a
-- level beside each pick). Learning is opt-in: talents cost gold to reset.
-- APIs (documented, used by Forever's Blizzard_SharedTalentFrame): C_ClassTalents.GetActiveConfigID,
-- C_Traits.GetConfigInfo / GetTreeNodes / GetNodeInfo / GetEntryInfo / GetDefinitionInfo /
-- CanPurchaseRank / PurchaseRank / SetSelection / CommitConfig / ConfigHasStagedChanges.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end
local P={}
NS.TalentPlanner=P
local FIRST_LEVEL=10
local function Plain(v) return not (issecretvalue and issecretvalue(v)) end
local function Number(v) return Plain(v) and type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function Read(fn,...)
    if type(fn)~='function' then return end
    local ok,a,b,c,d=pcall(fn,...)
    if ok and Plain(a) then return a,b,c,d end
end
local function Say(text) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cff0cd29fForever Companion:|r '..text) end end
local function Class() local _,c=Read(_G.UnitClass,'player');return c end
-- Per character (a plan belongs to the character, not to an Ellesmere profile).
function NS.EllesmereTalentPlan()
    if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end
    local s=FHKEllesmereDB.talentPlan
    if type(s)~='table' or s.class~=Class() then s={class=Class(),picks={},auto=false};FHKEllesmereDB.talentPlan=s end
    if type(s.picks)~='table' then s.picks={} end
    if type(s.auto)~='boolean' then s.auto=false end
    for i=#s.picks,1,-1 do
        local p=s.picks[i]
        if type(p)~='table' or not Number(p.node) then table.remove(s.picks,i) end
    end
    return s
end
function P.LevelOf(index) return FIRST_LEVEL+index-1 end

-------------------------------------------------------------------------------
-- The tree, read live: nodeID -> {x, y, entries={{entry, spell, name, icon, max}}, rank, max}
-------------------------------------------------------------------------------
function P.Config()
    local CT=C_ClassTalents
    local id=CT and Read(CT.GetActiveConfigID)
    return Number(id) and id or nil
end
function P.Tree()
    local T,config=C_Traits,P.Config()
    if not (T and config) then return nil end
    local info=Read(T.GetConfigInfo,config)
    if type(info)~='table' or type(info.treeIDs)~='table' then return nil end
    local nodes,order={},{}
    for _,tree in ipairs(info.treeIDs) do
        local ids=Read(T.GetTreeNodes,tree)
        for _,nodeID in ipairs(type(ids)=='table' and ids or {}) do
            local n=Read(T.GetNodeInfo,config,nodeID)
            if type(n)=='table' and n.isVisible~=false and Number(n.posX) and Number(n.posY) and type(n.entryIDs)=='table' and #n.entryIDs>0 then
                local node={id=nodeID,x=n.posX,y=n.posY,rank=Number(n.activeRank) and n.activeRank or 0,max=Number(n.maxRanks) and n.maxRanks or 1,entries={},
                    active=type(n.activeEntry)=='table' and n.activeEntry.entryID or nil}
                for _,entryID in ipairs(n.entryIDs) do
                    local e=Read(T.GetEntryInfo,config,entryID)
                    local d=type(e)=='table' and e.definitionID and Read(T.GetDefinitionInfo,e.definitionID)
                    local spell=type(d)=='table' and Number(d.spellID) and d.spellID or nil
                    local name=spell and (Read(C_Spell and C_Spell.GetSpellName,spell) or nil)
                    local icon=spell and (Read(C_Spell and C_Spell.GetSpellTexture,spell) or nil)
                    node.entries[#node.entries+1]={entry=entryID,spell=spell,name=d and d.overrideName or name,icon=d and d.overrideIcon or icon,
                        max=type(e)=='table' and Number(e.maxRanks) and e.maxRanks or node.max}
                end
                nodes[nodeID]=node;order[#order+1]=node
            end
        end
    end
    return nodes,order,config
end

-------------------------------------------------------------------------------
-- The plan: an ordered list of {node, entry}; each element is one talent point.
-------------------------------------------------------------------------------
local blockedNode -- the plan pick last reported as blocked, so the reason is said once (reset on edits)
function P.Planned(nodeID,upto)
    local n=0
    for i,p in ipairs(NS.EllesmereTalentPlan().picks) do
        if upto and i>upto then break end
        if p.node==nodeID then n=n+1 end
    end
    return n
end
function P.Add(node,entry)
    if not node then return false end
    if P.Planned(node.id)>=node.max then return false end
    local picks=NS.EllesmereTalentPlan().picks
    if #picks>=60 then return false end
    picks[#picks+1]={node=node.id,entry=entry or (node.entries[1] and node.entries[1].entry)}
    blockedNode=nil
    return true
end
function P.RemoveLast(nodeID)
    local picks=NS.EllesmereTalentPlan().picks
    for i=#picks,1,-1 do if picks[i].node==nodeID then table.remove(picks,i);blockedNode=nil;return true end end
    return false
end
function P.Clear() NS.EllesmereTalentPlan().picks={};blockedNode=nil end
-- The next pick the character does not have yet, in plan order (ranks already owned fill the
-- earliest picks of their talent first).
function P.Next(nodes)
    nodes=nodes or select(1,P.Tree())
    if not nodes then return nil end
    local used={}
    for i,p in ipairs(NS.EllesmereTalentPlan().picks) do
        local node=nodes[p.node]
        if node then
            used[p.node]=(used[p.node] or 0)+1
            if used[p.node]>node.rank then return p,node,i end
        end
    end
end
function NS.EllesmereNextPlannedTalent()
    local p,node=P.Next()
    if not p then return nil end
    for _,e in ipairs(node.entries) do if e.entry==p.entry then return e.name end end
    return node.entries[1] and node.entries[1].name
end

-- Learning: strictly in plan order, out of combat, only while points are there to spend.
local learning=false
function P.Learn()
    local s=NS.EllesmereTalentPlan()
    if learning or not s.auto or Read(_G.InCombatLockdown)~=false then return 0 end
    local T,CT=C_Traits,C_ClassTalents
    if not T then return 0 end
    -- No point to spend: nothing to read (review R2-12).
    if CT and Read(CT.HasUnspentTalentPoints)==false then return 0 end
    -- Picks the player staged in Blizzard's talent frame are theirs to apply: never commit them (R2-6).
    local start=P.Config()
    if start and Read(T.ConfigHasStagedChanges,start)==true then return 0 end
    learning=true
    local count,names=0,{}
    -- Ranks bought in this pass, per node: an activeRank that leaves staged purchases out never
    -- makes the loop buy the same talent twice (R2-7).
    local before,bought={}, {}
    for _=1,60 do
        local nodes,_,config=P.Tree()
        for id,c in pairs(bought) do local n=nodes and nodes[id];if n and n.rank<before[id]+c then n.rank=before[id]+c end end
        local p,node,index=P.Next(nodes)
        if not (p and config) then break end
        if Read(T.CanPurchaseRank,config,p.node,p.entry)~=true then
            -- Points are waiting but the next pick is not available yet: name it once (S48).
            local CT=C_ClassTalents
            if CT and Read(CT.HasUnspentTalentPoints)==true and blockedNode~=p.node then
                blockedNode=p.node
                local name
                for _,e in ipairs(node.entries or {}) do if e.entry==p.entry then name=e.name end end
                Say('Talent plan paused at '..(name or 'the next pick')..': it is not available yet. Spend points earlier in its tree or learn what it needs, or change the plan.')
            end
            break
        end
        blockedNode=nil
        local ok
        if #node.entries>1 and type(T.SetSelection)=='function' and node.active~=p.entry then ok=Read(T.SetSelection,config,p.node,p.entry)
        else ok=Read(T.PurchaseRank,config,p.node) end
        if ok~=true then break end
        if before[p.node]==nil then before[p.node]=node.rank-(bought[p.node] or 0) end
        bought[p.node]=(bought[p.node] or 0)+1
        count=count+1
        for _,e in ipairs(node.entries) do if e.entry==p.entry then names[#names+1]=(e.name or '?')..' ('..P.Planned(p.node,index)..'/'..node.max..')' end end
    end
    local config=P.Config()
    if count>0 and config and (Read(T.ConfigHasStagedChanges,config)~=false) then
        -- Commit the way Forever's own talent frame does (C_ClassTalents), and check it (R2-6).
        local committed
        if CT and type(CT.CommitConfig)=='function' then committed=Read(CT.CommitConfig) else committed=Read(T.CommitConfig,config) end
        if committed~=true then
            Read(T.RollbackConfig,config)
            count=0
            Say('Talent plan: the game did not accept the change, so nothing was learned. It tries again after your next talent point or combat.')
        end
    end
    learning=false
    if count>0 then Say('Learned '..table.concat(names,', ')..' from your talent plan.') end
    if P.Refresh then P.Refresh() end
    return count
end

-------------------------------------------------------------------------------
-- The planner window.
-------------------------------------------------------------------------------
local frame,buttons,orderLines=nil,{},{}
local function Font(fs,size)
    local path=Read(EUI.GetFontPath,'extras')
    fs:SetFont(type(path)=='string' and path or 'Fonts\\FRIZQT__.TTF',size,'OUTLINE')
end
local function Build()
    if frame then return end
    frame=CreateFrame('Frame','FHKEllesmereTalentPlanner',UIParent,'BackdropTemplate')
    frame:SetSize(820,560);frame:SetPoint('CENTER');frame:SetFrameStrata('DIALOG');frame:SetClampedToScreen(true)
    frame:EnableMouse(true);frame:SetMovable(true);frame:RegisterForDrag('LeftButton')
    frame:SetScript('OnDragStart',frame.StartMoving);frame:SetScript('OnDragStop',frame.StopMovingOrSizing)
    frame.bg=frame:CreateTexture(nil,'BACKGROUND');frame.bg:SetAllPoints();frame.bg:SetColorTexture(.05,.06,.07,.96)
    frame.border=Read(EUI.MakeBorder,frame,0,0,0,1)
    frame.title=frame:CreateFontString(nil,'OVERLAY');Font(frame.title,14);frame.title:SetPoint('TOPLEFT',14,-12)
    frame.title:SetText('Talent Planner')
    frame.hint=frame:CreateFontString(nil,'OVERLAY');Font(frame.hint,10);frame.hint:SetPoint('TOPLEFT',frame.title,'BOTTOMLEFT',0,-4)
    frame.hint:SetText('Left click: plan the next rank. Right click: remove its last planned rank. The number is the level you learn it at.')
    frame.hint:SetTextColor(.7,.72,.75)
    frame.close=CreateFrame('Button',nil,frame,'UIPanelCloseButton');frame.close:SetPoint('TOPRIGHT',-2,-2)
    frame.tree=CreateFrame('Frame',nil,frame);frame.tree:SetPoint('TOPLEFT',14,-52);frame.tree:SetSize(560,490)
    frame.list=CreateFrame('Frame',nil,frame);frame.list:SetPoint('TOPLEFT',frame.tree,'TOPRIGHT',14,0);frame.list:SetSize(220,440)
    frame.listTitle=frame.list:CreateFontString(nil,'OVERLAY');Font(frame.listTitle,12);frame.listTitle:SetPoint('TOPLEFT');frame.listTitle:SetText('Order')
    frame.clear=CreateFrame('Button',nil,frame,'UIPanelButtonTemplate');frame.clear:SetSize(100,22)
    frame.clear:SetPoint('BOTTOMRIGHT',-14,12);frame.clear:SetText('Clear Plan')
    frame.clear:SetScript('OnClick',function() P.Clear();P.Refresh() end)
    frame.learn=CreateFrame('Button',nil,frame,'UIPanelButtonTemplate');frame.learn:SetSize(120,22)
    frame.learn:SetPoint('RIGHT',frame.clear,'LEFT',-8,0);frame.learn:SetText('Learn Now')
    frame.learn:SetScript('OnClick',function()
        local s=NS.EllesmereTalentPlan();local was=s.auto;s.auto=true;P.Learn();s.auto=was
    end)
    frame:Hide()
    if type(UISpecialFrames)=='table' then table.insert(UISpecialFrames,'FHKEllesmereTalentPlanner') end
end
local function NodeButton(i)
    if buttons[i] then return buttons[i] end
    local b=CreateFrame('Button',nil,frame.tree)
    b:SetSize(30,30);b:RegisterForClicks('LeftButtonUp','RightButtonUp')
    b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetAllPoints();b.icon:SetTexCoord(.08,.92,.08,.92)
    b.border=Read(EUI.MakeBorder,b,0,0,0,1)
    b.rank=b:CreateFontString(nil,'OVERLAY');Font(b.rank,9);b.rank:SetPoint('BOTTOMRIGHT',b,'BOTTOMRIGHT',2,-2)
    b.plan=b:CreateFontString(nil,'OVERLAY');Font(b.plan,10);b.plan:SetPoint('TOPLEFT',b,'TOPLEFT',-2,2)
    b:SetScript('OnClick',function(self,mouse)
        if mouse=='RightButton' then P.RemoveLast(self.node.id) else P.Add(self.node) end
        P.Refresh()
    end)
    b:SetScript('OnEnter',function(self)
        local e=self.node and self.node.entries[1]
        if GameTooltip and e and e.spell then
            GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
            if GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(e.spell) else GameTooltip:SetText(e.name or '') end
            GameTooltip:Show()
        end
    end)
    b:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
    buttons[i]=b
    return b
end
function P.Refresh()
    if not frame or not frame:IsShown() then return end
    local nodes,order=P.Tree()
    for _,b in ipairs(buttons) do b:Hide() end
    for _,l in ipairs(orderLines) do l:SetText('') end
    if not nodes or #order==0 then
        frame.hint:SetText('Talents are not readable yet. Open it again after your first talent point (level 10).');return
    end
    -- Fit the client's own node positions into the window.
    local minX,maxX,minY,maxY=math.huge,-math.huge,math.huge,-math.huge
    for _,n in ipairs(order) do minX,maxX,minY,maxY=math.min(minX,n.x),math.max(maxX,n.x),math.min(minY,n.y),math.max(maxY,n.y) end
    local w,h=frame.tree:GetWidth()-34,frame.tree:GetHeight()-34
    local sx,sy=(maxX>minX) and w/(maxX-minX) or 1,(maxY>minY) and h/(maxY-minY) or 1
    -- Plan levels per node: the first planned rank's level is shown on the icon.
    local firstLevel={}
    for i,p in ipairs(NS.EllesmereTalentPlan().picks) do if not firstLevel[p.node] then firstLevel[p.node]=P.LevelOf(i) end end
    for i,n in ipairs(order) do
        local b=NodeButton(i);b.node=n
        b:ClearAllPoints();b:SetPoint('TOPLEFT',frame.tree,'TOPLEFT',(n.x-minX)*sx,-(n.y-minY)*sy)
        local e=n.entries[1]
        b.icon:SetTexture(e and e.icon or 134400)
        local planned=P.Planned(n.id)
        b.rank:SetText(n.rank..'/'..n.max)
        b.plan:SetText(firstLevel[n.id] and tostring(firstLevel[n.id]) or '')
        b.icon:SetDesaturated(n.rank==0 and planned==0)
        local r,g,bl=.3,.3,.32
        if n.rank>=n.max then r,g,bl=1,.82,0 elseif planned>0 then r,g,bl=.25,.84,.66 elseif n.rank>0 then r,g,bl=.9,.9,.9 end
        if b.border and b.border.SetColor then b.border:SetColor(r,g,bl,1) end
        b:Show()
    end
    -- The order list: level, talent and rank.
    local picks=NS.EllesmereTalentPlan().picks
    for i=1,math.min(#picks,40) do
        local line=orderLines[i]
        if not line then
            line=frame.list:CreateFontString(nil,'OVERLAY');Font(line,10)
            line:SetPoint('TOPLEFT',frame.list,'TOPLEFT',0,-16-(i-1)*11);line:SetJustifyH('LEFT');orderLines[i]=line
        end
        local p=picks[i];local n=nodes[p.node];local name='?'
        if n then for _,e in ipairs(n.entries) do if e.entry==p.entry then name=e.name or '?' end end end
        line:SetText(('%d  %s %d/%d'):format(P.LevelOf(i),name,P.Planned(p.node,i),n and n.max or 0))
        local done=n and P.Planned(p.node,i)<=n.rank
        if done then line:SetTextColor(.5,.5,.52) else line:SetTextColor(.92,.92,.94) end
    end
end
function NS.OpenEllesmereTalentPlanner()
    if Read(_G.InCombatLockdown)==true then Say('The talent planner opens out of combat.');return end
    Build();frame:Show();P.Refresh()
    if not frame.syncHooked then frame.syncHooked=true;frame:HookScript('OnHide',function() NS.SyncEllesmereTalentPlanner() end) end
    NS.SyncEllesmereTalentPlanner()
end
SLASH_FHKTALENTPLAN1='/fhktalentplan'
SlashCmdList.FHKTALENTPLAN=function() NS.OpenEllesmereTalentPlanner() end

local driver=CreateFrame('Frame')
driver:SetScript('OnEvent',function(_,event)
    if event=='PLAYER_REGEN_ENABLED' or event=='PLAYER_LEVEL_UP' or event=='TRAIT_CONFIG_UPDATED' or event=='PLAYER_LOGIN' or event=='TRAIT_TREE_CURRENCY_INFO_UPDATED' then
        if C_Timer and C_Timer.After then C_Timer.After(.5,function() P.Learn();P.Refresh() end) else P.Learn() end
    end
end)
function NS.SyncEllesmereTalentPlanner()
    driver:UnregisterAllEvents()
    -- Zero cost while unused (R2-12): only with Learn Planned Talents on or the window open.
    if not (NS.EllesmereTalentPlan().auto or (frame and frame:IsShown())) then return end
    for _,event in ipairs({'PLAYER_LOGIN','PLAYER_LEVEL_UP','TRAIT_CONFIG_UPDATED','PLAYER_REGEN_ENABLED','TRAIT_TREE_CURRENCY_INFO_UPDATED'}) do
        if not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(event) then driver:RegisterEvent(event) end
    end
end
-- Saved settings arrive after this file loads: the first sync waits for login.
local boot=CreateFrame('Frame')
boot:RegisterEvent('PLAYER_LOGIN')
boot:SetScript('OnEvent',function(self) self:UnregisterAllEvents();NS.SyncEllesmereTalentPlanner()
    if NS.EllesmereTalentPlan().auto and C_Timer and C_Timer.After then C_Timer.After(1,function() P.Learn() end) end end)

function NS.AddEllesmereTalentPlannerOptions(Row)
    Row({type='button',text='Talent Planner',tooltip='Your class talent tree: click talents in the order you want them, each stamped with the level you learn it at. Also /fhktalentplan.',
        onClick=function() NS.OpenEllesmereTalentPlanner() end},
        {type='toggle',text='Learn Planned Talents',
        tooltip='When you have a talent point, learns the next talents of your plan in order, out of combat, and lists them in chat. Off: the Unspent Talent warning names the next planned talent. Talents cost gold to reset.',
        getValue=function() return NS.EllesmereTalentPlan().auto end,setValue=function(v) NS.EllesmereTalentPlan().auto=v;NS.SyncEllesmereTalentPlanner();if v then P.Learn() end end})
end
