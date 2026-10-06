-- New Spell Alerts (player, 2026-10-06: "notifications eg for rogues they have new tier of poison
-- available"). CLASS_KITS_2026-10-06.md engine E4. On level up (and once after login, and when
-- your spells or Poisons skill change) it lists the spells and ranks your class trainer now
-- teaches that you have not learned: a lane cue ("New: Instant Poison III", "3 new spells at your
-- trainer") and/or a chat list. Data: ClassTrainingData.lua, generated from Forever's own client
-- tables (FHK-Ellesmere-Patch/tools/GenerateTrainingData.js). At a class trainer, the trainer's own
-- list corrects the data for the session (level, Poisons skill, learned). Off by default; while
-- off it registers no events and builds no data.
-- APIs (Forever docs): C_SpellBook.IsSpellKnown, C_SkillInfo.GetSkillLineInfoByID (rank),
-- C_Spell.GetSpellName / GetSpellSubtext, UnitLevel, UnitRace (raceID), IsResting, the trainer
-- service globals Forever's Blizzard_TrainerUI uses (incl. GetTrainerServiceCost), GetMoney, PLAYER_LEVEL_UP, SPELLS_CHANGED,
-- SKILL_LINES_CHANGED, TRAINER_SHOW / UPDATE / CLOSED.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end
local R={}
NS.RankNotifier=R
local DEFAULTS={enabled=false,lane=true,hold=8,chat=true,sound='none',levelUpOnly=false,notResting=false,report=false}
local CHOICES={sound={none=true,raid=true,alarm=true,ready=true,tick=true}}
local LIMITS={hold={3,30}}
local WARN_KEY='rankNotifier'
local LOGIN_DELAY,COALESCE=5,.5
local MAX_IGNORE,MAX_NOTES,MAX_LISTED=100,40,10
local function Plain(v) return not (issecretvalue and issecretvalue(v)) end
local function Number(v) return Plain(v) and type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function Text(v) return Plain(v) and type(v)=='string' and v~='' end
local function Table(v) return Plain(v) and type(v)=='table' end
local function Yes(v) return Plain(v) and v==true end
-- A call whose secret or failed result reads as "unknown" (nil), never as "missing".
local function Read(fn,...)
    if type(fn)~='function' then return end
    local ok,a,b,c,d,e=pcall(fn,...)
    if not ok or not Plain(a) then return end
    return a,Plain(b) and b or nil,Plain(c) and c or nil,Plain(d) and d or nil,Plain(e) and e or nil
end

-------------------------------------------------------------------------------
-- Settings: look and behaviour per profile; the ignore list per character.
-------------------------------------------------------------------------------
function NS.EllesmereRankNotifierSettings()
    if not Table(FHKEllesmereDB) then FHKEllesmereDB={} end
    local s=FHKEllesmereDB.rankNotifier
    if not Table(s) then s={};FHKEllesmereDB.rankNotifier=s end
    for k,v in pairs(DEFAULTS) do
        local x=s[k]
        if type(v)=='boolean' then if not Plain(x) or type(x)~='boolean' then s[k]=v end
        elseif LIMITS[k] then if not Number(x) or x<LIMITS[k][1] or x>LIMITS[k][2] then s[k]=v end
        elseif CHOICES[k] then if not Text(x) or not CHOICES[k][x] then s[k]=v end end
    end
    if s.colors~=nil then
        local c=Table(s.colors) and s.colors.cue
        if not (Table(c) and Number(c[1]) and Number(c[2]) and Number(c[3])) then s.colors=nil end
    end
    return s
end
function NS.EllesmereRankNotifierIgnore()
    if not Table(FHKEllesmereDB) then FHKEllesmereDB={} end
    local list=FHKEllesmereDB.rankNotifierIgnore
    if not Table(list) then list={};FHKEllesmereDB.rankNotifierIgnore=list end
    local n=0
    for k,v in pairs(list) do
        if not Text(k) or v~=true or n>=MAX_IGNORE then list[k]=nil else n=n+1 end
    end
    return list
end

-------------------------------------------------------------------------------
-- Data: only the player's class is built, only while the alerts are on.
-------------------------------------------------------------------------------
local function Class() local _,c=Read(_G.UnitClass,'player');return Text(c) and c or nil end
R.Class=Class
local built -- {class, groups, index}
local trainer={} -- spell ID -> {kind, level, skill}: this session's trainer window
local notes,noteSeen={}, {}
local function SpellName(id) local n=Read(C_Spell and C_Spell.GetSpellName,id);return Text(n) and n or nil end
local function Key(name,rank) return name:lower()..'|'..rank end
function R.Data(class)
    class=class or Class()
    local D=NS.ClassTrainingData
    if not class or not Table(D) or type(D[class])~='function' then return nil end
    if built and built.class==class then return built.groups,built.index end
    local ok,groups=pcall(D[class])
    if not ok or type(groups)~='table' then return nil end
    -- Trainer lines are matched by name and rank (English data names and the client's own names).
    local index={}
    for _,g in ipairs(groups) do
        for i=2,#g do
            local e=g[i]
            local hit={g=g,e=e}
            index[Key(e[4] or g[1],e[3])]=hit
            index[Key(g[1],e[3])]=index[Key(g[1],e[3])] or hit
            local own=SpellName(e[1])
            if own then index[Key(own,e[3])]=index[Key(own,e[3])] or hit end
            -- Tiers named by numeral ("Instant Poison III") may be listed without a rank.
            if e[4] then
                index[Key(e[4],0)]=index[Key(e[4],0)] or hit
                if own then index[Key(own,0)]=index[Key(own,0)] or hit end
            end
        end
    end
    built={class=class,groups=groups,index=index}
    return groups,index
end

-------------------------------------------------------------------------------
-- What is new: per spell group, the best rank you may train that neither it nor a higher rank
-- is known. Talent ranks need the talent; racial spells your race; poisons the Poisons skill.
-------------------------------------------------------------------------------
local function KnownAPI() return (C_SpellBook and type(C_SpellBook.IsSpellKnown)=='function') or type(_G.IsPlayerSpell)=='function' end
-- true, false, or nil when a read failed or was secret (unknown: never announced as new).
local function Known(id)
    local unknown=false
    for _,fn in ipairs({C_SpellBook and C_SpellBook.IsSpellKnown or false,_G.IsPlayerSpell or false}) do
        if type(fn)=='function' then
            local ok,v=pcall(fn,id)
            if not ok or not Plain(v) then unknown=true elseif v==true then return true end
        end
    end
    if unknown then return nil end
    return false
end
R.Known=Known
local function KnownEntry(e)
    local t=trainer[e[1]]
    if t and t.kind=='used' then return true end
    return Known(e[1])~=false
end
function R.PoisonSkill()
    local info=Read(C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID,NS.ClassTrainingData and NS.ClassTrainingData.poisonSkillLine or 40)
    if not Table(info) then return nil end
    local rank=info.rank
    if not Number(rank) or rank<1 then return nil end
    return rank
end
local function RaceBit()
    local _,_,raceID=Read(_G.UnitRace,'player')
    local map=NS.ClassTrainingData and NS.ClassTrainingData.RACE_BIT
    return Number(raceID) and Table(map) and map[raceID] or nil
end
local function HasBit(mask,bit) return math.floor(mask/2^bit)%2==1 end
local function Available(g,e,level,skill)
    local t=trainer[e[1]]
    if t and t.kind=='available' then return true end
    if (t and t.level or e[2])>level then return false end
    if g.p then
        if not skill then return false end -- no Poisons skill (or unreadable): unknown, not new
        if skill<(t and t.skill or e.s or 0) then return false end
    end
    return true
end
local function Display(g,e)
    local name=SpellName(e[1]) or e[4] or g[1]
    if e[3]>0 and not e[4] then
        local sub=Read(C_Spell and C_Spell.GetSpellSubtext,e[1])
        name=name..' ('..(Text(sub) and sub or ('Rank '..e[3]))..')'
    end
    return name
end
-- Returns the list of new items {key, id, name, group, level}, or nil when it cannot be told.
function R.Compute(level)
    local groups=R.Data()
    if not groups or not KnownAPI() then return nil end
    if not Number(level) then level=Read(_G.UnitLevel,'player') end
    if not Number(level) or level<1 then return nil end
    local ignore=NS.EllesmereRankNotifierIgnore()
    local race,raceRead,skill,skillRead
    local out={}
    for _,g in ipairs(groups) do
        local name=g[1]
        local ok=not ignore[name]
        if ok and g.r then
            if not raceRead then race,raceRead=RaceBit(),true end
            ok=race~=nil and HasBit(g.r,race) -- race unreadable: unknown, not new
        end
        if ok and g.p and not skillRead then skill,skillRead=R.PoisonSkill(),true end
        local best
        if ok then for i=#g,2,-1 do if Available(g,g[i],level,skill) then best=i;break end end end
        if best then
            local known=false
            for i=#g,best,-1 do if KnownEntry(g[i]) then known=true;break end end
            if not known and g.t then
                -- A talent rank: only once you have the talent (or an earlier rank of it).
                local has=Known(g.t)==true
                for i=2,best-1 do if has then break end;has=Known(g[i][1])==true end
                known=not has
            end
            if not known then
                local e=g[best]
                local plain=Display(g,e)
                -- Mage teleports and portals: a portal trainer in a capital teaches them (S44).
                out[#out+1]={key=name..'|'..e[3],id=e[1],plain=plain,name=g.v and (plain..' (portal trainer)') or plain,
                    group=name,level=e[2],portal=g.v==1}
            end
        end
    end
    table.sort(out,function(a,b) if a.level~=b.level then return a.level>b.level end return a.name<b.name end)
    return out
end

-------------------------------------------------------------------------------
-- Output: lane cue (held for a few seconds), chat list, sound.
-------------------------------------------------------------------------------
local cfg
local enabled=false
local driver=CreateFrame('Frame')
local lastKeys -- keys of the last result; nil until the first run
local deferred -- items waiting for combat or resting to end
local holdToken=0
local function Say(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cff0cd29fForever Companion:|r '..text) end
end
local function Color()
    local c=cfg and Table(cfg.colors) and cfg.colors.cue
    if Table(c) and Number(c[1]) and Number(c[2]) and Number(c[3]) then return c end
    local C=NS.Colours or {}
    return C.happy or {.30,.85,.30}
end
R.Color=Color
local function HideCue()
    holdToken=holdToken+1
    if NS.HideEllesmereWarning then NS.HideEllesmereWarning(WARN_KEY) end
end
local function Split(items)
    local class,portal={}, {}
    for _,it in ipairs(items) do if it.portal then portal[#portal+1]=it else class[#class+1]=it end end
    return class,portal
end
-- Class-trainer spells are counted; portal-trainer spells are named apart (S44).
function R.CueText(items)
    local class,portal=Split(items)
    local extra=#portal>0 and (', '..#portal..' at the portal trainer') or ''
    if #class==0 then
        if #portal==1 then return 'New: '..portal[1].name end
        return #portal..' new spells at the portal trainer'
    end
    if #class==1 then return 'New: '..class[1].name..extra end
    return #class..' new spells at your trainer'..extra
end
-- sound: the module's choice for the lane (nil = the lane's default sound), review S1.
local function ShowCue(text,hold,sound)
    if not NS.ShowEllesmereWarning then return false end
    NS.ShowEllesmereWarning(WARN_KEY,text,Color(),true,false,sound)
    holdToken=holdToken+1
    local mine=holdToken
    if C_Timer and C_Timer.After then C_Timer.After(hold,function() if holdToken==mine and NS.HideEllesmereWarning then NS.HideEllesmereWarning(WARN_KEY) end end) end
    return true
end
local function List(items,key)
    local names={}
    for i=1,math.min(#items,MAX_LISTED) do names[i]=items[i][key] end
    local text=table.concat(names,', ')
    if #items>MAX_LISTED then text=text..' and '..(#items-MAX_LISTED)..' more' end
    return text..'.'
end
function R.ChatText(items)
    local class,portal=Split(items)
    local parts={}
    if #class>0 then parts[#parts+1]='New at your trainer: '..List(class,'name') end
    if #portal>0 then parts[#parts+1]='New at the portal trainer: '..List(portal,'plain') end
    return table.concat(parts,' ')
end
local function OutsideCombat() return Read(_G.InCombatLockdown)~=true end
local function Defer(items)
    deferred=items
    if not OutsideCombat() then driver:RegisterEvent('PLAYER_REGEN_ENABLED') end
    if cfg.notResting then driver:RegisterEvent('PLAYER_UPDATE_RESTING') end
end
local function Announce(items,total)
    if not enabled or #items==0 then return end
    -- Never during combat (a level-up kill); with Not While Resting, not in an inn or city.
    if not OutsideCombat() or (cfg.notResting and Yes(Read(_G.IsResting))) then Defer(items);return end
    deferred=nil
    local sound=(cfg.sound~='none') and cfg.sound or nil
    local shown=cfg.lane and ShowCue(R.CueText(items),cfg.hold,sound)
    if cfg.chat then Say(R.ChatText(items)) end
    -- The lane plays the sound with the cue; without a lane cue the sound plays alone.
    if sound and not shown and NS.PlayEllesmereCueSound then NS.PlayEllesmereCueSound(sound,WARN_KEY) end
end
-- reason: 'levelup' and 'login' announce everything new; 'changed' only what just appeared
-- (a Poisons skill-up); 'silent' only refreshes (and hides the cue once all is learned).
function R.Run(reason,level)
    if not enabled then return end
    local items=R.Compute(level)
    if not items then return end
    local first=lastKeys==nil
    local keys,fresh={}, {}
    for _,it in ipairs(items) do keys[it.key]=true;if not first and not lastKeys[it.key] then fresh[#fresh+1]=it end end
    lastKeys=keys
    R.items=items
    if #items==0 then HideCue();deferred=nil;return end
    if reason=='levelup' then Announce(items,#items)
    elseif reason=='login' and not cfg.levelUpOnly then Announce(items,#items)
    elseif reason=='changed' and not cfg.levelUpOnly and #fresh>0 then Announce(fresh,#fresh) end
end
local function Resume()
    if not deferred then return end
    if not OutsideCombat() or (cfg.notResting and Yes(Read(_G.IsResting))) then return end
    driver:UnregisterEvent('PLAYER_REGEN_ENABLED');driver:UnregisterEvent('PLAYER_UPDATE_RESTING')
    local items=R.Compute()
    local wanted={};for _,it in ipairs(deferred) do wanted[it.key]=true end
    deferred=nil
    if not items then return end
    local still={}
    for _,it in ipairs(items) do if wanted[it.key] then still[#still+1]=it end end
    Announce(still,#still)
end

-------------------------------------------------------------------------------
-- Trainer window: the trainer's list is authoritative for this session.
-------------------------------------------------------------------------------
local atTrainer=false
local function AddNote(text)
    if noteSeen[text] or #notes>=MAX_NOTES then return end
    noteSeen[text]=true;notes[#notes+1]=text
end
function R.Notes() return notes end
local function ClassTrainer()
    if Yes(Read(_G.IsTradeskillTrainer)) then return false end
    local kind=C_Trainer and Read(C_Trainer.GetTrainerType)
    local types=Enum and Enum.TrainerType or {}
    return kind==nil or kind==(types.General or 0)
end
-- Returns how many of the open trainer's lines are class spells (0 at a weapon master, which is
-- also a General trainer: review R2-13). Notes and the session overlay are kept only when >0.
function R.ScanTrainer()
    local _,index=R.Data()
    if not index then return 0 end
    local n=Read(_G.GetNumTrainerServices)
    if not Number(n) then return 0 end
    -- Auto Train's class-name set (English data names) also counts, when it has one.
    local AT=NS.AutoTrain
    local set=AT and type(AT.ClassNames)=='function' and Read(AT.ClassNames) or nil
    local classHits=0
    local found,pendingNotes={}, {}
    local function Note(text) pendingNotes[#pendingNotes+1]=text end
    -- What this trainer offers now, with its live costs (S45).
    local offer={count=0,costs={}}
    for i=1,math.min(n,500) do
        local name,kind,_,reqLevel,sub=Read(_G.GetTrainerServiceInfo,i)
        if Text(name) and (kind=='available' or kind=='unavailable' or kind=='used') then
            local rank=tonumber(Text(sub) and sub:match('(%d+)') or '') or 0
            local hit=index[Key(name,rank)]
            if hit or (Table(set) and type(AT.ClassSpell)=='function' and Read(AT.ClassSpell,set,name)==true) then classHits=classHits+1 end
            if kind=='available' then
                offer.count=offer.count+1
                local cost=Read(_G.GetTrainerServiceCost,i)
                if Number(cost) and cost>=0 then offer.costs[#offer.costs+1]=cost end
            end
            local label=name..(Text(sub) and (' ('..sub..')') or '')
            if hit then
                local t={kind=kind}
                if Number(reqLevel) and reqLevel>0 then
                    t.level=reqLevel
                    if reqLevel~=hit.e[2] then Note(label..': trainer level '..reqLevel..', data '..hit.e[2]) end
                end
                if hit.g.p then
                    local _,skillRank=Read(_G.GetTrainerServiceSkillReq,i)
                    if Number(skillRank) then
                        t.skill=skillRank
                        if skillRank~=(hit.e.s or 0) then Note(label..': Poisons '..skillRank..' needed, estimated '..(hit.e.s or 0)) end
                    end
                end
                found[hit.e[1]]=t
            elseif kind~='used' then Note(label..': at the trainer, not in the data') end
        end
    end
    if classHits==0 then return 0 end
    for id,t in pairs(found) do trainer[id]=t end
    for _,text in ipairs(pendingNotes) do AddNote(text) end
    R.offer=offer
    return classHits
end
local function Coins(copper)
    local text=C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString and Read(C_CurrencyInfo.GetCoinTextureString,copper)
    if Text(text) then return text end
    local g,sv,c=math.floor(copper/10000),math.floor(copper/100)%100,copper%100
    return (g>0 and (g..'g ') or '')..((g>0 or sv>0) and (sv..'s ') or '')..c..'c'
end
-- "6 spells to learn here: you can afford 2 (1g 20s of 5g 10s)." Cheapest first; costs live.
function R.OfferText(offer,money)
    if not Table(offer) or offer.count<1 then return nil end
    local spells=offer.count..(offer.count==1 and ' spell' or ' spells')..' to learn here'
    if #offer.costs==0 or not Number(money) then return spells..'.' end
    local costs={};for i,c in ipairs(offer.costs) do costs[i]=c end
    table.sort(costs)
    local total,spend,afford=0,0,0
    for _,c in ipairs(costs) do
        total=total+c
        if spend+c<=money then spend=spend+c;afford=afford+1 end
    end
    if afford>=offer.count and #costs==offer.count then return spells..' for '..Coins(total)..'; you can afford them all.' end
    return spells..': you can afford '..afford..' ('..Coins(spend)..' of '..Coins(total)..').'
end
local function TrainerShow()
    if not ClassTrainer() then return end
    R.offer=nil
    -- Weapon masters and other General trainers without class spells: no notes, no hint.
    if R.ScanTrainer()==0 then return end
    atTrainer=true
    HideCue()
    R.Run('silent')
    local text=R.OfferText(R.offer,Read(_G.GetMoney))
    if text and cfg.chat then
        local at=NS.EllesmereAutoTrainSettings and NS.EllesmereAutoTrainSettings()
        if NS.EllesmereAutoTrainSettings and not (Table(at) and at.enabled==true) then
            text=text..' Auto Train can learn them for you: Forever Companion options, General, Auto Train.'
        end
        Say(text)
    end
end
local function TrainerClosed()
    if not atTrainer then return end
    atTrainer=false
    if cfg.report and #notes>0 then
        Say('Training data differs from this trainer ('..#notes..'): '..table.concat(notes,'; ',1,math.min(#notes,5))..(#notes>5 and '; ...' or '')..'.')
    end
    R.Run('silent')
end

-------------------------------------------------------------------------------
-- Events: coalesced; nothing registered while off.
-------------------------------------------------------------------------------
local PRIORITY={silent=0,changed=1,login=2,levelup=3}
local pendingReason,pendingLevel,trainerDirty
local function Flush()
    local reason,level=pendingReason,pendingLevel
    pendingReason,pendingLevel=nil,nil
    if trainerDirty then trainerDirty=false;if atTrainer then R.ScanTrainer() end end
    if reason then R.Run(reason,level) end
end
local function Queue(reason,level,delay)
    if not pendingReason or PRIORITY[reason]>PRIORITY[pendingReason] then pendingReason=reason end
    if Number(level) and (not pendingLevel or level>pendingLevel) then pendingLevel=level end
    if C_Timer and C_Timer.After then
        if not R.scheduled then R.scheduled=true;C_Timer.After(delay or COALESCE,function() R.scheduled=false;Flush() end) end
    else Flush() end
end
function R.OnEvent(_,event,a)
    if not enabled then return end
    if event=='PLAYER_LEVEL_UP' then Queue('levelup',Number(a) and a or nil)
    elseif event=='SPELLS_CHANGED' or event=='SKILL_LINES_CHANGED' then Queue(atTrainer and 'silent' or 'changed')
    elseif event=='TRAINER_SHOW' then TrainerShow()
    elseif event=='TRAINER_UPDATE' then if atTrainer then trainerDirty=true;Queue('silent') end
    elseif event=='TRAINER_CLOSED' then TrainerClosed()
    elseif event=='PLAYER_REGEN_ENABLED' or event=='PLAYER_UPDATE_RESTING' then Resume() end
end
driver:SetScript('OnEvent',R.OnEvent)
local function Register(event)
    if not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(event) then driver:RegisterEvent(event) end
end
function R.State() return {enabled=enabled,driver=driver,deferred=deferred,trainer=trainer,lastKeys=lastKeys,built=built} end
function NS.SyncEllesmereRankNotifier(atLogin)
    cfg=NS.EllesmereRankNotifierSettings()
    local class=Class()
    local D=NS.ClassTrainingData
    local was=enabled
    enabled=cfg.enabled==true and class~=nil and Table(D) and type(D[class])=='function'
    driver:UnregisterAllEvents()
    pendingReason,pendingLevel,trainerDirty=nil,nil,false
    if not enabled then
        if was then HideCue() end
        built,lastKeys,deferred,atTrainer=nil,nil,nil,false
        return
    end
    for _,event in ipairs({'PLAYER_LEVEL_UP','SPELLS_CHANGED','TRAINER_SHOW','TRAINER_UPDATE','TRAINER_CLOSED'}) do Register(event) end
    if class=='ROGUE' then Register('SKILL_LINES_CHANGED') end
    if deferred then Resume();if deferred then Defer(deferred) end end
    -- At login, one look after the client has settled; turning it on later just takes stock.
    if atLogin==true then Queue('login',nil,LOGIN_DELAY) elseif not was then R.Run('silent') end
end

-------------------------------------------------------------------------------
-- Ignore list (per character) and preview.
-------------------------------------------------------------------------------
-- Toggles a spell (by name, any rank) on the ignore list; returns the group name and whether it
-- is now ignored, or nil when your class trainer has no spell of that name.
function R.ToggleIgnore(text)
    if not Text(text) then return nil end
    text=text:gsub('|',''):gsub('^%s+',''):gsub('%s+$','')
    if text=='' then return nil end
    local want=text:lower()
    local groups=R.Data()
    if not groups then return nil end
    for _,g in ipairs(groups) do
        local own=g[2] and SpellName(g[2][1])
        if g[1]:lower()==want or (own and own:lower()==want) or (g[2] and g[2][4] and g[2][4]:lower()==want) then
            local list=NS.EllesmereRankNotifierIgnore()
            if list[g[1]] then list[g[1]]=nil else list[g[1]]=true end
            if enabled then R.Run('silent') else built=nil end
            return g[1],list[g[1]]==true
        end
    end
    if not enabled then built=nil end
    return nil
end
function R.IgnoreCount() local n=0;for _ in pairs(NS.EllesmereRankNotifierIgnore()) do n=n+1 end;return n end
function NS.PreviewEllesmereRankNotifier()
    cfg=cfg or NS.EllesmereRankNotifierSettings()
    local items=R.items
    local text
    if items and #items>0 then text=R.CueText(items)
    else text=Class()=='ROGUE' and 'New: Instant Poison III' or '3 new spells at your trainer' end
    ShowCue(text,3,(cfg.sound~='none') and cfg.sound or nil)
end

-------------------------------------------------------------------------------
-- Options: Warnings > NEW SPELLS.
-------------------------------------------------------------------------------
function NS.AddEllesmereRankNotifierOptions(Row)
    if EUI.IsSearchPrebuild and EUI.IsSearchPrebuild() then
        Row({type='label',text='New Spell Alerts'},{type='label',text='List New Spells In Chat'})
        Row({type='label',text='New Spell Lane Cue'},{type='label',text='New Spell Sound'})
        Row({type='label',text='Clear Ignore List'},{type='label',text='Reset New Spell Alerts'})
        return
    end
    local D=NS.ClassTrainingData
    local class=Class()
    if not class or not Table(D) or type(D[class])~='function' then return end
    local function Settings() return NS.EllesmereRankNotifierSettings() end
    local function Off() return not Settings().enabled end
    local OFF='New Spell Alerts'
    local function Set(k,v)
        if LIMITS[k] then if not Number(v) or v<LIMITS[k][1] or v>LIMITS[k][2] then return end
        elseif CHOICES[k] then if not Text(v) or not CHOICES[k][v] then return end
        elseif type(DEFAULTS[k])=='boolean' then if not Plain(v) or type(v)~='boolean' then return end
        else return end
        Settings()[k]=v
        if k=='enabled' or k=='notResting' then NS.SyncEllesmereRankNotifier() else cfg=Settings() end
    end
    local master={type='toggle',text='New Spell Alerts',
        tooltip='After a level up (and once after login) tells you which spells and ranks your class trainer now teaches that you have not learned, including new poison tiers. At a trainer, the trainer\'s own list corrects it.',
        getValue=function() return Settings().enabled end,setValue=function(v) Set('enabled',v) end}
    master.swatches={{tooltip='New Spell Cue Color',hasAlpha=false,
        getValue=function() local saved=cfg;cfg=Settings();local c=Color();cfg=saved;return c[1],c[2],c[3],1 end,
        setValue=function(r,g,b)
            if not Number(r) or not Number(g) or not Number(b) or r<0 or r>1 or g<0 or g>1 or b<0 or b>1 then return end
            local s=Settings();s.colors={cue={r,g,b}};cfg=s
        end}}
    master.preview={tip='Preview the cue',show=NS.PreviewEllesmereRankNotifier,duration=3,disabled=Off,disabledTooltip=OFF}
    master.cog={title='New Spell Alerts',disabled=Off,disabledTooltip=OFF,rows={
        {type='slider',label='Cue Hold Time (Sec)',min=3,max=30,step=1,get=function() return Settings().hold end,set=function(v) Set('hold',v) end},
        {type='toggle',label='Only On Level Up',get=function() return Settings().levelUpOnly end,set=function(v) Set('levelUpOnly',v) end},
        {type='toggle',label='Not While Resting',get=function() return Settings().notResting end,set=function(v) Set('notResting',v) end},
        {type='toggle',label='Note Trainer Differences',get=function() return Settings().report end,set=function(v) Set('report',v) end},
        {type='input',label='Ignore Or Unignore A Spell',get=function() return '' end,set=function(v)
            local name,now=R.ToggleIgnore(v)
            if name then Say(now and ('Ignoring '..name..' in New Spell Alerts.') or ('No longer ignoring '..name..'.'))
            elseif Text(v) and v:match('%S') then Say('No trainer spell named "'..v:gsub('|','')..'" for your class.') end
        end}}}
    Row(master,{type='toggle',text='List New Spells In Chat',disabled=Off,disabledTooltip=OFF,
        tooltip='Lists the new spells in chat. At a trainer, mentions Auto Train when it is off.',
        getValue=function() return Settings().chat end,setValue=function(v) Set('chat',v) end})
    local values={none='None',raid='Raid Warning',alarm='Alarm',ready='Ready Check',tick='Tick'}
    Row({type='toggle',text='New Spell Lane Cue',disabled=Off,disabledTooltip=OFF,
        tooltip='Shows "New: Instant Poison III" or "3 new spells at your trainer" on the warning lane for the hold time (cog).',
        getValue=function() return Settings().lane end,setValue=function(v) Set('lane',v) end},
        {type='dropdown',text='New Spell Sound',values=values,order={'none','raid','alarm','ready','tick'},disabled=Off,disabledTooltip=OFF,
        getValue=function() return Settings().sound end,
        setValue=function(v) Set('sound',v);if CHOICES.sound[v] and NS.PlayEllesmereCueSound then NS.PlayEllesmereCueSound(v,WARN_KEY..'Preview') end end})
    Row({type='button',text='Clear Ignore List',
        tooltip='Spells you ignore (cog: Ignore Or Unignore A Spell) are never announced on this character.',
        onClick=function()
            local list=NS.EllesmereRankNotifierIgnore()
            for k in pairs(list) do list[k]=nil end
            if enabled then R.Run('silent') end
            Say('New Spell Alerts: ignore list cleared.')
        end},
        {type='button',text='Reset New Spell Alerts',tooltip='Puts this section\'s options and color back to their defaults (it stays on or off, and keeps the ignore list).',
        onClick=function()
            local s=Settings()
            for k,v in pairs(DEFAULTS) do if k~='enabled' then s[k]=v end end
            s.colors=nil
            NS.SyncEllesmereRankNotifier()
        end})
end

local boot=CreateFrame('Frame')
boot:RegisterEvent('PLAYER_LOGIN')
boot:SetScript('OnEvent',function(self) self:UnregisterAllEvents();NS.SyncEllesmereRankNotifier(true) end)
