-- Class Buff Bar (build plan row A, 2026-10-06; CLASS_KITS engine E2). A data-driven self-buff
-- bar for every class but the hunter (who has the Aspect bar): paladin auras, seals, blessings
-- and Righteous Fury; priest Inner Fire, Fortitude, Shadowform, Fear Ward and racial buffs; mage
-- and warlock armors; Arcane Intellect; shaman shields; druid Mark, Thorns and Omen; warrior
-- Battle Shout. Rank-aware by name: one aura read by name covers every rank, and the buttons
-- cast by name, so the highest learned rank is used. Secure buttons: attributes, size, anchors
-- and show/hide change out of combat only (queued for PLAYER_REGEN_ENABLED).
-- Forever data (wago.tools DB2 build 1.60.1.70205, E1): blessings, Fortitude and Arcane
-- Intellect last 60 min; seals 30 s; Inner Fire 10 min with 20 charges; Righteous Fury 30 min;
-- mage and warlock armors 30 min; Fear Ward 3 min; Lightning / Water Shield 3 charges, Earth
-- Shield 6 or 9. Forever's priest racials Divine Grace, Chastise, Contingency Plan and Dark
-- Sacrifice are heals, attacks or short wards, not self-buffs, so the racial group holds the
-- self-buffs that are: Touch of Weakness (Undead) and Shadowguard (Troll).
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end
local B={}
NS.ClassBuffs=B

-------------------------------------------------------------------------------
-- Data. Group: key, label (options), abr (Ellesmere AuraBuff Reminders' raid-buff key: the
-- Forever raid buffs it reminds the caster about in instances), noun (cue text; else the spell name), grace (seconds a
-- dropped buff stays quiet: Judgement eats the seal, a priest leaves Shadowform to heal), exclusive (one
-- active at a time), when (cue timing: always / rest = out of combat / combat / melee =
-- in combat while auto-attacking), long (the expiring cue applies), lowKey (low-charge
-- threshold setting), caster (druid: caster form only), preferred (blessing choice), fury.
-- Entry: ids (rank IDs, base first; the name comes from the first), name (fallback),
-- alt (a group version, e.g. Greater Blessing, read under its own name), any (another
-- caster's copy counts), supersededBy (hidden once that sibling is known), cancel (right
-- click cancels it), resist (Resistance Auras toggle).
-------------------------------------------------------------------------------
B.GROUPS={
    PALADIN={
        {key='aura',label='Auras',noun='AURA',exclusive=true,when='always',entries={
            {key='devotion',ids={465},name='Devotion Aura'},
            {key='retribution',ids={7294},name='Retribution Aura'},
            {key='concentration',ids={19746},name='Concentration Aura'},
            {key='sanctity',ids={20218},name='Sanctity Aura'},
            {key='shadowRes',ids={19876},name='Shadow Resistance Aura',resist=true},
            {key='frostRes',ids={19888},name='Frost Resistance Aura',resist=true},
            {key='fireRes',ids={19891},name='Fire Resistance Aura',resist=true}}},
        {key='seal',label='Seals',noun='SEAL',exclusive=true,when='melee',grace=1.6,castDuration=30,entries={
            {key='righteousness',ids={21084,20154},name='Seal of Righteousness'},
            {key='crusader',ids={21082,20162},name='Seal of the Crusader'},
            {key='command',ids={20375},name='Seal of Command'},
            {key='fury',ids={1311649,20163},name='Seal of Fury'},
            {key='wisdom',ids={20166},name='Seal of Wisdom'},
            {key='light',ids={20165},name='Seal of Light'},
            {key='justice',ids={20164},name='Seal of Justice'}}},
        {key='blessing',label='Blessings',noun='BLESSING',exclusive=true,when='rest',long=true,preferred=true,entries={
            {key='might',ids={19740},alt={25782},name='Blessing of Might',any=true},
            {key='wisdom',ids={19742},alt={25894},name='Blessing of Wisdom',any=true},
            {key='kings',ids={20217},alt={25898},name='Blessing of Kings',any=true},
            {key='salvation',ids={1038},alt={25895},name='Blessing of Salvation',any=true},
            {key='light',ids={19977},alt={25890},name='Blessing of Light',any=true},
            {key='sanctuary',ids={20911},alt={25899},name='Blessing of Sanctuary',any=true}}},
        {key='fury',label='Righteous Fury',when='always',fury=true,entries={
            {key='fury',ids={25780},name='Righteous Fury',cancel=true}}},
    },
    PRIEST={
        {key='innerFire',label='Inner Fire',when='always',long=true,lowKey='lowInnerFire',entries={
            {key='innerFire',ids={588},name='Inner Fire'}}},
        {key='fortitude',label='Fortitude',when='rest',long=true,abr='fort',entries={
            {key='fortitude',ids={1243},alt={21562},name='Power Word: Fortitude',any=true}}},
        {key='shadowform',label='Shadowform',when='rest',grace=10,entries={
            {key='shadowform',ids={15473},name='Shadowform',cancel=true}}},
        {key='fearWard',label='Fear Ward',when='rest',entries={
            {key='fearWard',ids={6346},name='Fear Ward',any=true}}},
        {key='racial',label='Racial Buffs',when='rest',long=true,exclusive=true,entries={
            {key='touch',ids={2652},name='Touch of Weakness'},
            {key='shadowguard',ids={18137},name='Shadowguard'}}},
    },
    MAGE={
        {key='armor',label='Armors',noun='ARMOR',exclusive=true,when='rest',long=true,entries={
            {key='frost',ids={168},name='Frost Armor',supersededBy='ice'},
            {key='ice',ids={7302},name='Ice Armor'},
            {key='mage',ids={6117},name='Mage Armor'},
            {key='molten',ids={428741},name='Molten Armor'}}},
        {key='intellect',label='Arcane Intellect',when='rest',long=true,abr='ai',entries={
            {key='intellect',ids={1459},alt={23028},name='Arcane Intellect',any=true}}},
    },
    WARLOCK={
        {key='armor',label='Armors',noun='ARMOR',exclusive=true,when='rest',long=true,entries={
            {key='skin',ids={687},name='Demon Skin',supersededBy='armor'},
            {key='armor',ids={706},name='Demon Armor'},
            {key='fel',ids={403619},name='Fel Armor'}}},
    },
    SHAMAN={
        {key='shield',label='Shields',noun='SHIELD',exclusive=true,when='rest',long=true,lowKey='lowShield',entries={
            {key='lightning',ids={324},name='Lightning Shield'},
            {key='water',ids={408510},name='Water Shield'},
            {key='earth',ids={974,408514},name='Earth Shield'}}},
    },
    DRUID={
        {key='mark',label='Mark Of The Wild',when='rest',long=true,caster=true,abr='motw',entries={
            {key='mark',ids={1126},alt={21849},name='Mark of the Wild',any=true}}},
        {key='thorns',label='Thorns',when='rest',long=true,caster=true,entries={
            {key='thorns',ids={467},name='Thorns',any=true}}},
        {key='omen',label='Omen Of Clarity',when='rest',long=true,caster=true,entries={
            {key='omen',ids={16864},name='Omen of Clarity'}}},
    },
    WARRIOR={
        {key='shout',label='Battle Shout',when='combat',abr='bshout',entries={
            {key='shout',ids={6673},name='Battle Shout',any=true}}},
    },
}
for _,list in pairs(B.GROUPS) do for _,g in ipairs(list) do g.cueKey,g.showKey,g.cueToggle='classBuffs_'..g.key,'show_'..g.key,'cue_'..g.key end end

-------------------------------------------------------------------------------
-- Settings.
-------------------------------------------------------------------------------
local DEFAULTS={enabled=false,size=30,spacing=4,orientation='horizontal',visibility='always',timers=true,charges=true,
    dim=true,pulse=true,formsHide=true,cues=false,expiry=120,sound='none',blessing='any',allBlessings=false,
    resistAuras=false,fury='ignore',lowInnerFire=5,lowShield=0,quietResting=true,sealCritical=false,leaveRaidBuffs=true}
local CHOICES={orientation={horizontal=true,vertical=true},visibility={always=true,combat=true,mouseover=true,missing=true},
    sound={none=true,raid=true,alarm=true,ready=true,tick=true},
    blessing={any=true,might=true,wisdom=true,kings=true,salvation=true,light=true,sanctuary=true},
    fury={ignore=true,wanted=true,unwanted=true}}
local LIMITS={size={20,48},spacing={0,12},expiry={0,600},lowInnerFire={0,19},lowShield={0,8}}
-- Optional groups start off: Fear Ward (buttons and cue), Battle Shout cue (rage), Righteous Fury
-- button (its cue is the Wanted / Unwanted choice), Thorns cue (mostly cast on tanks; S35). The
-- shield Low cue is 0 (off) by default: many levellers skip Lightning Shield (S34).
local SHOW_OFF,CUE_OFF={fearWard=true,fury=true},{fearWard=true,shout=true,thorns=true}
for _,list in pairs(B.GROUPS) do for _,g in ipairs(list) do
    DEFAULTS['show_'..g.key]=not SHOW_OFF[g.key]
    if not g.fury then DEFAULTS['cue_'..g.key]=not CUE_OFF[g.key] end
end end
B.DEFAULTS=DEFAULTS
local POINTS={CENTER=true,TOP=true,BOTTOM=true,LEFT=true,RIGHT=true,TOPLEFT=true,TOPRIGHT=true,BOTTOMLEFT=true,BOTTOMRIGHT=true}
local function Plain(v) return not (issecretvalue and issecretvalue(v)) end
local function Number(v) return Plain(v) and type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function Text(v) return Plain(v) and type(v)=='string' and v~='' end
local function Table(v) return Plain(v) and type(v)=='table' end
local function Read(fn,...)
    if type(fn)~='function' then return end
    local ok,a,b,c,d=pcall(fn,...)
    if ok and Plain(a) then return a,Plain(b) and b or nil,Plain(c) and c or nil,Plain(d) and d or nil end
end
local function Yes(v) return Plain(v) and v==true end
local function OutsideCombat() local v=Read(_G.InCombatLockdown);return Plain(v) and v==false end
local function Now() local n=Read(_G.GetTime);return Number(n) and n or 0 end
local function Valid(k,v)
    local d=DEFAULTS[k]
    if type(d)=='boolean' then return Plain(v) and type(v)=='boolean' end
    if LIMITS[k] then return Number(v) and v>=LIMITS[k][1] and v<=LIMITS[k][2] end
    if CHOICES[k] then return Text(v) and CHOICES[k][v]==true end
    return false
end
function NS.EllesmereClassBuffSettings()
    if not Table(FHKEllesmereDB) then FHKEllesmereDB={} end
    local s=FHKEllesmereDB.classBuffs
    if not Table(s) then s={};FHKEllesmereDB.classBuffs=s end
    for k,v in pairs(DEFAULTS) do if not Valid(k,s[k]) then s[k]=v end end
    if s.colors~=nil and not Table(s.colors) then s.colors=nil end
    if s.position~=nil and not Table(s.position) then s.position=nil end
    return s
end

-------------------------------------------------------------------------------
-- Spells: names, icons, learned state (refreshed on SPELLS_CHANGED, out of the paint path).
-------------------------------------------------------------------------------
local function Class() local _,c=Read(_G.UnitClass,'player');return Text(c) and c or nil end
B.Class=Class
local function Known(id)
    if not Number(id) then return false end
    return Yes(Read(C_SpellBook and C_SpellBook.IsSpellKnown,id)) or Yes(Read(_G.IsPlayerSpell,id)) or Yes(Read(_G.IsSpellKnown,id))
end
local function SpellName(id)
    local n=Read(C_Spell and C_Spell.GetSpellName,id)
    if not Text(n) then n=Read(_G.GetSpellInfo,id) end
    return Text(n) and n or nil
end
local info,auras,lastActive={},{},{}
B.info,B.auras=info,auras
function B.RefreshKnown(class)
    class=class or Class()
    local list=class and B.GROUPS[class]
    if not list then return end
    for _,g in ipairs(list) do
        local byKey={}
        for _,e in ipairs(g.entries) do
            local i=info[e] or {};info[e]=i
            i.name=SpellName(e.ids[1]) or e.name
            i.altName=e.alt and (SpellName(e.alt[1]) or nil) or nil
            local spell=Read(C_Spell and C_Spell.GetSpellInfo,i.name)
            local id=Table(spell) and Number(spell.spellID) and spell.spellID or nil
            local learned=Known(id)
            for _,rank in ipairs(e.ids) do if learned then break end;learned=Known(rank) end
            -- A passive spell has nothing to cast (Omen of Clarity is passive on some builds).
            if learned and Yes(Read(C_Spell and C_Spell.IsSpellPassive,id or e.ids[1])) then learned=false end
            i.known=learned
            local icon=Table(spell) and spell.iconID or nil
            if not (Number(icon) or Text(icon)) then icon=Read(C_Spell and C_Spell.GetSpellTexture,id or e.ids[1]) end
            i.icon=(Number(icon) or Text(icon)) and icon or nil
            byKey[e.key]=i
        end
        for _,e in ipairs(g.entries) do
            local over=e.supersededBy and byKey[e.supersededBy]
            info[e].hidden=over and over.known or false
        end
    end
end

-------------------------------------------------------------------------------
-- Aura reads. A restricted or failed read is "unknown", never "missing"; in combat the last
-- known state is kept. With C_Secrets.ShouldAurasBeSecret() nothing is read at all.
-------------------------------------------------------------------------------
local combatFlag,melee=nil,false
local function InCombat()
    if combatFlag~=nil then return combatFlag end
    return Yes(Read(_G.InCombatLockdown))
end
local function AurasSecret()
    local fn=C_Secrets and C_Secrets.ShouldAurasBeSecret
    if type(fn)~='function' then return false end
    local ok,v=pcall(fn)
    if not ok or not Plain(v) then return true end
    return v==true
end
local function Find(name,filter)
    local fn=C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
    if type(fn)~='function' or not name then return false end
    local ok,a=pcall(fn,'player',name,filter)
    if not ok or not Plain(a) then return false end
    if a==nil then return true,nil end
    if type(a)~='table' then return false end
    return true,a
end
function B.ReadAura(e)
    local i=info[e]
    if not i then return end
    local st=auras[e] or {};auras[e]=st
    local filter=e.any and 'HELPFUL' or 'HELPFUL|PLAYER'
    local ok,a=Find(i.name,filter)
    if ok and not a and i.altName then ok,a=Find(i.altName,filter) end
    if not ok then
        if not (InCombat() and st.state) then st.state,st.expires,st.charges='unknown',nil,nil end
        return
    end
    if not a then st.state,st.expires,st.charges='missing',nil,nil;return end
    st.state='active'
    local x=a.expirationTime
    st.expires=Number(x) and x>0 and x or nil
    local c=a.applications
    if not (Number(c) and c>0) then c=a.charges end
    st.charges=Number(c) and c>0 and c or nil
end
local groups -- the player's class groups while enabled
function B.RefreshAuras()
    if not groups or AurasSecret() then return end
    for _,g in ipairs(groups) do
        local active
        for _,e in ipairs(g.entries) do
            if info[e] and info[e].known then
                B.ReadAura(e)
                if auras[e].state=='active' and not active then active=e end
            end
        end
        if active then lastActive[g.key]=active end
    end
end
-- A buff cannot outlast its expiration: past it, a kept (unreadable) state reads missing.
local function Effective(e,now)
    local st=auras[e]
    if not st or not st.state then return 'unknown' end
    if st.state=='active' and st.expires and st.expires<=now then return 'missing' end
    return st.state
end
B.Effective=Effective

-------------------------------------------------------------------------------
-- Rules (pure on info/auras/settings): what a group needs and which button it points at.
-------------------------------------------------------------------------------
local cfg
function B.Evaluate(g,now,s)
    s=s or cfg
    if g.fury then
        local e=g.entries[1]
        if not (info[e] and info[e].known) then return end
        local st=Effective(e,now)
        if s.fury=='wanted' and st=='missing' then return 'missing',e end
        if s.fury=='unwanted' and st=='active' then return 'unwanted',e end
        return nil,e
    end
    local target,active,first,unknown
    for _,e in ipairs(g.entries) do
        local i=info[e]
        if i and i.known then
            if not first and not i.hidden and not (e.resist and not s.resistAuras) then first=e end
            if g.preferred and s.blessing==e.key then target=e end
            local st=Effective(e,now)
            if st=='active' then active=active or e elseif st=='unknown' then unknown=true end
        end
    end
    if not first and not active then return end
    if target then
        local st=Effective(target,now)
        if st=='unknown' then return end
        if st=='missing' then return 'missing',target end
        active=target
    elseif not active then
        if unknown then return end
        local last=lastActive[g.key]
        if not (last and info[last] and info[last].known and not info[last].hidden) then last=first end
        return 'missing',last
    end
    local st=auras[active]
    if g.long and s.expiry>0 and st.expires and st.expires-now<=s.expiry then return 'expiring',active,st.expires-now end
    if g.lowKey and s[g.lowKey]>0 and st.charges and st.charges<=s[g.lowKey] then return 'low',active,st.charges end
    return nil,active
end
-- Which buttons the bar shows, in order (pure; testable).
function B.Buttons(class,s)
    s=s or NS.EllesmereClassBuffSettings()
    local out={}
    for _,g in ipairs(B.GROUPS[class] or {}) do if s[g.showKey] then
        local narrow=g.preferred and s.blessing~='any' and not s.allBlessings
        if narrow then
            local pick
            for _,e in ipairs(g.entries) do if e.key==s.blessing and info[e] and info[e].known then pick=e end end
            narrow=pick~=nil
        end
        for _,e in ipairs(g.entries) do
            local i=info[e]
            if i and i.known and not i.hidden and not (e.resist and not s.resistAuras) and not (narrow and e.key~=s.blessing) then
                out[#out+1]={group=g,entry=e}
            end
        end
    end end
    return out
end
-- Dead, ghost, taxi, vehicle or mounted: the shared away policy for missing self-buffs (S2).
local function Blocked() return Read(NS.EllesmereAway,'buff')~=nil end
-- Quiet While Resting (S32): a city or inn, never inside an instance.
local function Resting()
    return cfg.quietResting and Yes(Read(_G.IsResting)) and not Yes(Read(_G.IsInInstance)) or false
end
-- Leave Raid Buffs To Ellesmere (suite review SQ-7, coexistence rule 2). Ellesmere's AuraBuff
-- Reminders (9.3.9) reminds the caster about Fortitude, Arcane Intellect, Mark of the Wild and
-- Battle Shout in instances (EABR.CollectForeverRaidBuffs). Read-only, from its Lite db
-- (EllesmereUI.Lite._dbRegistry, folder EllesmereUIAuraBuffReminders, db.profile):
-- display.remindersEnabled, raidBuffs.enabled[key] and raidBuffs.whereToShow, bucketed like
-- EABR.CurrentWhereBucket. Any read that fails means "not covered", so our cue stays.
local ABR='EllesmereUIAuraBuffReminders'
local INSTANCE={party=true,raid=true,scenario=true,arena=true,pvp=true}
local function AbrBucket(kind,d)
    if kind=='party' then
        if d==23 or d==8 then return 'dungeon_mythic' end
        if d==1 or d==2 or d==205 then return 'dungeon_nonmythic' end
        if d==24 then return 'timewalking' end
    elseif kind=='raid' then
        if d==16 or d==233 then return 'raid_mythic' end
        if d==15 or d==6 then return 'raid_heroic' end
        if d==14 or d==3 or d==4 or d==5 or d==17 or d==7 or d==9 or d==148 then return 'raid_normal_lfr' end
        if d==33 then return 'timewalking' end
    elseif kind=='scenario' and d==208 then return 'delve' end
end
local function AbrCovers(key,combat)
    local lite=EUI.Lite
    local reg=Table(lite) and lite._dbRegistry
    if not Table(reg) then return false end
    if type(EUI.IsModuleAddonLoaded)=='function' and not Yes(Read(EUI.IsModuleAddonLoaded,ABR)) then return false end
    local p
    for _,db in ipairs(reg) do if Table(db) and db.folder==ABR then p=db.profile end end
    if not Table(p) then return false end
    if Table(p.display) and p.display.remindersEnabled==false then return false end
    local rb=p.raidBuffs
    if not (Table(rb) and Table(rb.enabled) and rb.enabled[key]==true) then return false end
    local _,kind,d=Read(_G.GetInstanceInfo)
    if not (Text(kind) and INSTANCE[kind]) then return false end
    local w=rb.whereToShow
    if w~=nil and not Table(w) then return false end
    if w then
        if w.in_combat==false and combat then return false end
        local bucket=AbrBucket(kind,Number(d) and d or 0)
        if bucket and w[bucket]==false then return false end
    end
    return true
end
function B.EllesmereCovers(key,combat)
    local ok,covered=pcall(AbrCovers,key,combat)
    return ok and covered==true
end
local function Form(class)
    if class~='DRUID' then return 0 end
    local v=Read(_G.GetShapeshiftForm)
    return Number(v) and v or nil
end
-- Cue timing per group; an unreadable form counts as shapeshifted (unknown is not missing).
function B.CueAllowed(g,combat,autoAttack,form)
    if g.caster and form~=0 then return false end
    if g.when=='rest' then return not combat end
    if g.when=='combat' then return combat end
    if g.when=='melee' then return combat and autoAttack end
    return true
end

-------------------------------------------------------------------------------
-- Frames.
-------------------------------------------------------------------------------
local holder
local buttons,list={},{}
local driver=CreateFrame('Frame')
local enabled,pending,epoch,queued,dirtyKnown=false,false,0,false,false
local ticker,edgeAt,previewUntil
local needOf,targetOf,shownCues={},{},{}
local myClass
local function Font(fs,size)
    local path=Read(EUI.GetFontPath,'extras')
    fs:SetFont(Text(path) and path or 'Fonts\\FRIZQT__.TTF',size,'OUTLINE')
end
local function Color(key)
    local c=cfg and Table(cfg.colors) and cfg.colors[key]
    if Table(c) and Number(c[1]) and c[1]>=0 and c[1]<=1 and Number(c[2]) and c[2]>=0 and c[2]<=1 and Number(c[3]) and c[3]>=0 and c[3]<=1 then
        return c[1],c[2],c[3]
    end
    local C=NS.Colours or {}
    c=key=='active' and (C.happy or {.30,.85,.30}) or key=='missing' and (C.caution or {1,.82,0})
        or key=='expiring' and (C.worry or {1,.5,.25}) or (C.neutral or {.62,.66,.70})
    return c[1],c[2],c[3]
end
B.Color=Color
local function SetBorder(border,r,g,b,a) if border and type(border.SetColor)=='function' then border:SetColor(r,g,b,a) end end
local function Position()
    if not holder or not OutsideCombat() then pending=true;return end
    local p=NS.EllesmereClassBuffSettings().position
    local valid=Table(p) and Text(p.point) and POINTS[p.point] and Text(p.relPoint) and POINTS[p.relPoint] and Number(p.x) and Number(p.y)
    holder:ClearAllPoints()
    holder:SetPoint(valid and p.point or 'CENTER',UIParent,valid and p.relPoint or 'CENTER',valid and p.x or 0,valid and p.y or -240)
end
local function Hover(frame)
    frame:HookScript('OnEnter',function() if cfg and cfg.visibility=='mouseover' and holder then holder:SetAlpha(1) end end)
    frame:HookScript('OnLeave',function()
        if cfg and cfg.visibility=='mouseover' and holder and not holder:IsMouseOver() then holder:SetAlpha(0) end
    end)
end
local function Build()
    if holder then return end
    holder=CreateFrame('Frame','FHKEllesmereClassBuffs',UIParent,'SecureHandlerStateTemplate')
    holder:SetSize(30,30);holder:SetFrameStrata('MEDIUM');holder:EnableMouse(true);Hover(holder)
    if EUI.MakeUnlockElement and EUI.RegisterUnlockElements then
        EUI:RegisterUnlockElements({EUI.MakeUnlockElement({key='FHKEllesmereClassBuffs',label='Class Buffs',group='Unit Frames',order=622,noResize=true,
            getFrame=function() return holder end,getSize=function() return holder:GetWidth(),holder:GetHeight() end,
            isHidden=function() return not enabled end,
            savePos=function(_,point,relPoint,x,y)
                if Text(point) and POINTS[point] and Text(relPoint) and POINTS[relPoint] and Number(x) and Number(y) then
                    NS.EllesmereClassBuffSettings().position={point=point,relPoint=relPoint,x=x,y=y};Position()
                end
            end,
            loadPos=function() return NS.EllesmereClassBuffSettings().position end,
            clearPos=function() NS.EllesmereClassBuffSettings().position=nil;Position() end,applyPos=Position
        })},'FHKEllesmere')
    end
end
local function Button(i)
    if buttons[i] then return buttons[i] end
    local b=CreateFrame('Button','FHKEllesmereClassBuffButton'..i,holder,'SecureActionButtonTemplate')
    b:RegisterForClicks('AnyUp')
    b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetAllPoints(b);b.icon:SetTexCoord(.08,.92,.08,.92)
    b.border=Read(EUI.MakeBorder,b,0,0,0,1)
    b.edge=CreateFrame('Frame',nil,b);b.edge:SetPoint('TOPLEFT',b,'TOPLEFT',-2,2);b.edge:SetPoint('BOTTOMRIGHT',b,'BOTTOMRIGHT',2,-2)
    b.edge:EnableMouse(false);b.edgeBorder=Read(EUI.MakeBorder,b.edge,1,1,1,1);b.edge:SetAlpha(0)
    local g=b.edge:CreateAnimationGroup();local a=g:CreateAnimation('Alpha')
    a:SetFromAlpha(1);a:SetToAlpha(.35);a:SetDuration(.45);a:SetSmoothing('IN_OUT');g:SetToFinalAlpha(false);b.pulse=g
    b.timer=b:CreateFontString(nil,'OVERLAY');Font(b.timer,10);b.timer:SetPoint('BOTTOM',b,'BOTTOM',0,2)
    b.count=b:CreateFontString(nil,'OVERLAY');Font(b.count,10);b.count:SetPoint('TOPRIGHT',b,'TOPRIGHT',-1,-2)
    b.timerText,b.countText='',''
    b:HookScript('OnEnter',function(self)
        local i=self.entry and info[self.entry]
        if i and GameTooltip then
            GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
            GameTooltip:SetText(i.name..(self.entry.cancel and '\nLeft: cast. Right: cancel.' or '\nClick: cast on yourself (highest rank).'),1,1,1,1,true)
            GameTooltip:Show()
        end
    end)
    b:HookScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
    Hover(b)
    buttons[i]=b
    return b
end
local function Attributes(b,e)
    local name=info[e].name
    b:SetAttribute('type','macro');b:SetAttribute('macrotext','/cast [@player] '..name)
    if e.cancel then b:SetAttribute('type2','macro');b:SetAttribute('macrotext2','/cancelaura '..name)
    else b:SetAttribute('type2',nil);b:SetAttribute('macrotext2',nil) end
end
local function VisibilityDriver()
    local base=cfg.visibility=='combat' and '[combat] show; hide' or 'show'
    if myClass=='DRUID' and cfg.formsHide then base='[form] hide; '..base end
    return base
end
function B.Layout()
    if not holder or not cfg or not OutsideCombat() then pending=true;return end
    pending=false
    list=B.Buttons(myClass,cfg)
    local size,gap,horizontal=cfg.size,cfg.spacing,cfg.orientation=='horizontal'
    for i,it in ipairs(list) do
        local b=Button(i);b.entry,b.group=it.entry,it.group;Attributes(b,it.entry)
        b:SetSize(size,size);b.icon:SetTexture(info[it.entry].icon)
        b:ClearAllPoints()
        b:SetPoint('TOPLEFT',holder,'TOPLEFT',horizontal and (i-1)*(size+gap) or 0,horizontal and 0 or -(i-1)*(size+gap))
        b:Show()
    end
    for i=#list+1,#buttons do buttons[i].entry,buttons[i].group=nil,nil;buttons[i]:Hide() end
    local long=math.max(1,#list)*size+math.max(0,#list-1)*gap
    holder:SetSize(horizontal and long or size,horizontal and size or long)
    if cfg.visibility=='missing' then
        -- Only When Missing: shown and hidden out of combat by the rules (B.Update).
        if type(UnregisterStateDriver)=='function' then UnregisterStateDriver(holder,'visibility') end
    elseif type(RegisterStateDriver)=='function' then RegisterStateDriver(holder,'visibility',#list>0 and VisibilityDriver() or 'hide')
    elseif #list>0 then holder:Show() else holder:Hide() end
    holder:SetAlpha(cfg.visibility=='mouseover' and 0 or 1)
    Position()
end
local function Edge(b,on,r,g,bl)
    local reduced=NS.EllesmereReduceMotion and NS.EllesmereReduceMotion() or not cfg.pulse
    if on then SetBorder(b.edgeBorder,r,g,bl,1) end
    local sig=on and (reduced and 'still' or 'pulse') or 'off'
    if b.edgeSig==sig then return end
    b.edgeSig=sig;b.pulse:Stop()
    b.edge:SetAlpha(on and 1 or 0)
    if on and not reduced then b.pulse:SetLooping('BOUNCE');b.pulse:Play() end
end
local function Clock(t)
    if t>=5400 then return string.format('%dh',math.floor(t/3600+.5)) end
    if t>=60 then return string.format('%dm',math.ceil(t/60)) end
    return string.format('%d',math.max(0,math.ceil(t)))
end
B.Clock=Clock
local function SetText(fs,field,b,value)
    if b[field]~=value then b[field]=value;fs:SetText(value) end
end
-- Returns whether a seconds countdown is visible (the ticker runs only then) and, for minute
-- countdowns, when the next minute label changes (one timer, no ticker).
local function Paint(now,form)
    local tick,textEdge=false,nil
    for _,b in ipairs(buttons) do
        local e,g=b.entry,b.group
        if e and b:IsShown() then
            local st=Effective(e,now)
            local a=auras[e]
            local need,target=needOf[g],targetOf[g]
            local pointed=target==e
            local r,gg,bl,alpha=0,0,0,1
            if st=='active' then
                if pointed and (need=='expiring' or need=='low') then r,gg,bl=Color('expiring')
                elseif pointed and need=='unwanted' then r,gg,bl=Color('missing')
                else r,gg,bl=Color('active') end
            elseif st=='unknown' then r,gg,bl=Color('unknown');alpha=.8
            elseif pointed and need=='missing' then r,gg,bl=Color('missing')
            elseif g.exclusive and cfg.dim then alpha=.55 end
            if g.caster and form~=0 then alpha=math.min(alpha,.4) end
            SetBorder(b.border,r,gg,bl,1);b:SetAlpha(alpha)
            local loud=pointed and (need=='missing' or need=='unwanted')
            if loud then local cr,cg,cb=Color('missing');Edge(b,true,cr,cg,cb) else Edge(b,false) end
            local timer=''
            if cfg.timers then
                if st=='active' and a and a.expires then
                    local left=a.expires-now;timer=Clock(left)
                    if left<61 then tick=true else
                        local edge=now+left-60*(math.ceil(left/60)-1)
                        if not textEdge or edge<textEdge then textEdge=edge end
                    end
                elseif st=='unknown' then timer='?' end
            end
            SetText(b.timer,'timerText',b,timer)
            SetText(b.count,'countText',b,cfg.charges and st=='active' and a and a.charges and tostring(a.charges) or '')
        end
    end
    return tick,textEdge
end
local cueColour={}
-- The module sound rides on the lane (S1): None falls back to the lane's own sound, and only the
-- first new cue of a refresh carries it. Returns whether this cue was new.
local function ShowCue(key,text,colourKey,critical,sound)
    local r,g,b=Color(colourKey)
    local c=cueColour[key] or {};cueColour[key]=c;c[1],c[2],c[3]=r,g,b
    local new=not shownCues[key]
    if NS.ShowEllesmereWarning then NS.ShowEllesmereWarning(key,text,c,false,critical,new and sound or nil) end
    shownCues[key]=text
    return new
end
local function HideCue(key)
    if shownCues[key] then shownCues[key]=nil;if NS.HideEllesmereWarning then NS.HideEllesmereWarning(key) end end
end
local function HideCues() for key in pairs(shownCues) do HideCue(key) end end
local function Upper(e) local i=info[e];return string.upper(i and i.name or e.name) end
function B.CueText(g,need,e,s)
    s=s or cfg
    if need=='missing' then
        if g.noun and not (g.preferred and s.blessing~='any') then return 'NO '..g.noun end
        return 'NO '..Upper(e)
    elseif need=='expiring' then return Upper(e)..' EXPIRING'
    elseif need=='low' then return Upper(e)..' LOW'
    elseif need=='unwanted' then return Upper(e)..' ON' end
end
local function Ticker(on)
    if on and not ticker and C_Timer and type(C_Timer.NewTicker)=='function' then
        ticker=C_Timer.NewTicker(.5,function() if enabled then B.Update() else B.StopTicker() end end)
    elseif not on and ticker then ticker:Cancel();ticker=nil end
end
function B.StopTicker() Ticker(false) end
-- With no seconds countdown, one timer wakes the bar at the next edge: a minute label, an
-- expiring threshold or an expiration.
local graceUntil,wasActive={},{}
local function Schedule(now,textEdge)
    local nextEdge=textEdge
    for _,stop in pairs(graceUntil) do if stop>now and (not nextEdge or stop<nextEdge) then nextEdge=stop end end
    for _,g in ipairs(groups) do for _,e in ipairs(g.entries) do
        local a=auras[e]
        if a and a.state=='active' and a.expires and info[e] and info[e].known then
            local edges=g.long and cfg.expiry>0 and a.expires-cfg.expiry or nil
            if edges and edges>now and (not nextEdge or edges<nextEdge) then nextEdge=edges end
            if a.expires>now and (not nextEdge or a.expires<nextEdge) then nextEdge=a.expires end
        end
    end end
    if ticker or not nextEdge or not (C_Timer and type(C_Timer.After)=='function') then edgeAt=nil;return end
    if edgeAt==nextEdge then return end
    edgeAt=nextEdge;local token=epoch
    C_Timer.After(nextEdge-now+.05,function() if token==epoch and edgeAt==nextEdge and enabled then edgeAt=nil;B.Update() end end)
end
function B.Update(now)
    if not enabled or not groups then return end
    now=now or Now()
    local combat,blocked,form,resting=InCombat(),Blocked(),Form(myClass),Resting()
    local attention=false
    local sound=cfg.sound~='none' and cfg.sound or nil
    for _,g in ipairs(groups) do
        local need,e=B.Evaluate(g,now,cfg)
        needOf[g],targetOf[g]=need,e
        -- Grace: a buff that just dropped (read, or past its kept expiration) stays quiet a moment.
        local up=need~='missing' and e~=nil and Effective(e,now)=='active'
        if g.grace and wasActive[g.key] and not up then graceUntil[g.key]=now+g.grace end
        wasActive[g.key]=up
        local stop=graceUntil[g.key]
        if stop and now>=stop then graceUntil[g.key],stop=nil,nil end
        local allowed=need and not blocked and not stop and not (resting and (g.when=='rest' or g.when=='always'))
            and B.CueAllowed(g,combat,melee,form)
        if need and not blocked and cfg[g.showKey] and (g.when=='rest' or g.when=='always') and not (g.caster and form~=0) then attention=true end
        local cueOn=cfg.cues and (g.fury and cfg.fury~='ignore' or cfg[g.cueToggle])
        if allowed and cueOn and g.abr and cfg.leaveRaidBuffs and B.EllesmereCovers(g.abr,combat) then allowed=false end
        if allowed and cueOn then
            local critical=g.key=='seal' and cfg.sealCritical and need=='missing'
            if ShowCue(g.cueKey,B.CueText(g,need,e,cfg),(need=='expiring' or need=='low') and 'expiring' or 'missing',critical,sound) then sound=nil end
        else HideCue(g.cueKey) end
    end
    local previewing=previewUntil and now<previewUntil
    if holder and cfg.visibility=='missing' then
        if OutsideCombat() then
            if (attention or previewing) and #list>0 and not (myClass=='DRUID' and cfg.formsHide and form~=0) then holder:Show() else holder:Hide() end
        else pending=true end
    end
    local tick,textEdge=false,nil
    if holder then tick,textEdge=Paint(now,form) end
    Ticker(tick)
    Schedule(now,textEdge)
end

-------------------------------------------------------------------------------
-- Events: coalesced (one refresh per frame), registered only while the bar is on.
-------------------------------------------------------------------------------
local function Flush()
    if not queued then return end
    queued=false
    if not enabled then return end
    if dirtyKnown then dirtyKnown=false;B.RefreshKnown(myClass);B.Layout() end
    B.RefreshAuras();B.Update()
end
local function Queue(known)
    if known then dirtyKnown=true end
    if queued then return end
    queued=true
    if C_Timer and type(C_Timer.After)=='function' then C_Timer.After(0,Flush) else Flush() end
end
B.Queue=Queue
local judgement -- Judgement's name (every rank shares it)
-- Cast evidence (review R1-4): with aura reads restricted in combat, a seal the player casts
-- would never show. A successful cast of a known seal counts as that seal up for its 30 s
-- (and the others gone) until a readable aura event says otherwise.
function B.CastEvidence(name)
    if not groups then return false end
    for _,g in ipairs(groups) do if g.castDuration then
        local hit
        for _,e in ipairs(g.entries) do local i=info[e];if i and i.known and i.name==name then hit=e end end
        if hit then
            if not AurasSecret() and Find(name,'HELPFUL|PLAYER') then return false end
            local now=Now()
            for _,e in ipairs(g.entries) do
                local st=auras[e] or {};auras[e]=st
                if e==hit then st.state,st.expires,st.charges='active',now+g.castDuration,nil
                elseif st.state=='active' then st.state,st.expires,st.charges='missing',nil,nil end
            end
            lastActive[g.key]=hit
            return true
        end
    end end
    return false
end
function B.OnEvent(_,event,unit,_,spellID)
    if event=='PLAYER_REGEN_DISABLED' then combatFlag=true
    elseif event=='PLAYER_REGEN_ENABLED' then combatFlag=false
    elseif event=='PLAYER_ENTERING_WORLD' then combatFlag=nil end
    if not enabled then
        if event=='PLAYER_REGEN_ENABLED' and pending then NS.SyncEllesmereClassBuffs() end
        return
    end
    if event=='UNIT_AURA' then if unit=='player' then Queue(false) end;return end
    if event=='SPELLS_CHANGED' or event=='LEARNED_SPELL_IN_SKILL_LINE' or event=='PLAYER_ENTERING_WORLD' then Queue(true);return end
    if event=='PLAYER_REGEN_ENABLED' then
        melee=false
        if pending then B.Layout() end
        Queue(false);return
    end
    if event=='UNIT_SPELLCAST_SUCCEEDED' then
        if unit~='player' or not Number(spellID) then return end
        local name=SpellName(spellID)
        if not name then return end
        if name==judgement then graceUntil.seal=Now()+1.6
        elseif not B.CastEvidence(name) then return end
    end
    if event=='PLAYER_ENTER_COMBAT' then melee=true elseif event=='PLAYER_LEAVE_COMBAT' then melee=false end
    B.Update()
end
driver:SetScript('OnEvent',B.OnEvent)
local EVENTS={'PLAYER_ENTERING_WORLD','PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED','SPELLS_CHANGED','LEARNED_SPELL_IN_SKILL_LINE',
    'PLAYER_DEAD','PLAYER_ALIVE','PLAYER_UNGHOST','PLAYER_MOUNT_DISPLAY_CHANGED','PLAYER_CONTROL_LOST','PLAYER_CONTROL_GAINED','PLAYER_UPDATE_RESTING'}
local function Register(event)
    if not C_EventUtils or Yes(Read(C_EventUtils.IsEventValid,event)) then driver:RegisterEvent(event) end
end
function B.State() return {holder=holder,buttons=buttons,list=list,driver=driver,enabled=enabled,pending=pending,ticker=ticker,cues=shownCues} end
function NS.SyncEllesmereClassBuffs()
    cfg=NS.EllesmereClassBuffSettings()
    local class=Class()
    local list_=class and B.GROUPS[class]
    epoch=epoch+1;queued=false;dirtyKnown=false;edgeAt=nil
    for k in pairs(graceUntil) do graceUntil[k]=nil end
    for k in pairs(wasActive) do wasActive[k]=nil end
    -- Re-read combat (review R1-5): the regen events were not watched while the bar was off.
    combatFlag=nil
    driver:UnregisterAllEvents()
    Ticker(false)
    if not (cfg.enabled==true and list_) then
        enabled,groups=false,nil
        HideCues()
        if holder and OutsideCombat() then
            pending=false
            if type(UnregisterStateDriver)=='function' then UnregisterStateDriver(holder,'visibility') end
            holder:Hide()
        elseif holder then pending=true;driver:RegisterEvent('PLAYER_REGEN_ENABLED') end
        return
    end
    -- The secure holder cannot be created in combat: wait for it to end.
    if not holder and not OutsideCombat() then enabled=false;pending=true;driver:RegisterEvent('PLAYER_REGEN_ENABLED');return end
    enabled,groups,myClass=true,list_,class
    Build()
    melee=Yes(Read(C_Spell and C_Spell.IsCurrentSpell,6603))
    for _,event in ipairs(EVENTS) do Register(event) end
    if class=='PALADIN' then
        Register('PLAYER_ENTER_COMBAT');Register('PLAYER_LEAVE_COMBAT')
        judgement=SpellName(20271)
        if driver.RegisterUnitEvent then driver:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED','player') end
    end
    if class=='DRUID' then Register('UPDATE_SHAPESHIFT_FORM') end
    if driver.RegisterUnitEvent then driver:RegisterUnitEvent('UNIT_AURA','player') else driver:RegisterEvent('UNIT_AURA') end
    B.RefreshKnown(class);B.RefreshAuras();B.Layout();B.Update()
end
-- Preview (eye): the bar and a sample cue for three seconds.
function NS.PreviewEllesmereClassBuffs()
    if not enabled or not holder then return end
    previewUntil=Now()+3
    if OutsideCombat() then holder:Show();holder:SetAlpha(1) end
    local g=groups[1]
    local r,gg,b=Color('missing')
    if NS.ShowEllesmereWarning then NS.ShowEllesmereWarning('classBuffsPreview',g.noun and 'NO '..g.noun or 'NO '..string.upper(g.label),{r,gg,b},false,false) end
    local token=epoch
    if C_Timer and type(C_Timer.After)=='function' then C_Timer.After(3.05,function()
        previewUntil=nil
        if NS.HideEllesmereWarning then NS.HideEllesmereWarning('classBuffsPreview') end
        if token==epoch and enabled then B.Layout();B.Update() end
    end) end
end

-------------------------------------------------------------------------------
-- Options: Unit Frames > CLASS BUFFS. A class without data gets no rows.
-------------------------------------------------------------------------------
function NS.AddEllesmereClassBuffsOptions(Row)
    local class=Class()
    local mine=class and B.GROUPS[class]
    if not mine then return end
    local blank=function() return EUI.BlankRowCfg and EUI.BlankRowCfg() or {type='label',text=''} end
    if EUI.IsSearchPrebuild and EUI.IsSearchPrebuild() then
        local labels={'Class Buff Bar','Class Buff Bar Visibility','Buff Timers','Buff Charges','Missing / Expiring Cues','Cue Sound',
            'Expiring Warning Time','Quiet While Resting'}
        for _,g in ipairs(mine) do if g.abr then labels[#labels+1]='Leave Raid Buffs To Ellesmere';break end end
        for _,g in ipairs(mine) do
            labels[#labels+1]=g.label..(g.fury and ' Button' or ' Buttons')
            labels[#labels+1]=g.fury and 'Righteous Fury Cue' or g.label..' Cue'
        end
        if class=='PALADIN' then labels[#labels+1]='Seal Cue Above Character';labels[#labels+1]='Preferred Blessing';labels[#labels+1]='All Known Blessings';labels[#labels+1]='Resistance Auras' end
        if class=='PRIEST' then labels[#labels+1]='Inner Fire Low Charges' end
        if class=='SHAMAN' then labels[#labels+1]='Shield Low Charges' end
        labels[#labels+1]='Reset Class Buff Colors';labels[#labels+1]='Reset Class Buff Bar'
        for i=1,#labels,2 do Row({type='label',text=labels[i]},labels[i+1] and {type='label',text=labels[i+1]} or blank()) end
        return
    end
    local function Settings() return NS.EllesmereClassBuffSettings() end
    local function Off() return not Settings().enabled end
    local function NoCues() return Off() or not Settings().cues end
    local function Set(k,v)
        if not Valid(k,v) then return end
        Settings()[k]=v;NS.SyncEllesmereClassBuffs()
    end
    local MASTER='Class Buff Bar'
    local function Toggle(text,k,tip,disabled,disabledTip)
        return {type='toggle',text=text,tooltip=tip,disabled=disabled or Off,disabledTooltip=disabledTip or MASTER,
            getValue=function() return Settings()[k] end,setValue=function(v) Set(k,v) end}
    end
    local function Slider(text,k,min,max,step,tip,disabled,disabledTip)
        return {type='slider',text=text,tooltip=tip,min=min,max=max,step=step,disabled=disabled or Off,disabledTooltip=disabledTip or MASTER,
            getValue=function() return Settings()[k] end,setValue=function(v) Set(k,v) end}
    end
    local function Drop(text,k,values,order,tip,disabled,disabledTip)
        return {type='dropdown',text=text,tooltip=tip,values=values,order=order,disabled=disabled or Off,disabledTooltip=disabledTip or MASTER,
            getValue=function() return Settings()[k] end,setValue=function(v) Set(k,v) end}
    end
    local function Swatch(key,text)
        return {tooltip=text,hasAlpha=false,getValue=function()
            local saved=cfg;cfg=Settings();local r,g,b=Color(key);cfg=saved;return r,g,b,1
        end,setValue=function(r,g,b)
            if not Number(r) or not Number(g) or not Number(b) or r<0 or r>1 or g<0 or g>1 or b<0 or b>1 then return end
            local s=Settings();s.colors=Table(s.colors) and s.colors or {};s.colors[key]={r,g,b};NS.SyncEllesmereClassBuffs()
        end}
    end
    local bar=Toggle(MASTER,'enabled','One button per self-buff you know, cast by name so your highest rank is used. The buff that is up is highlighted; a missing one gets the missing color.')
    bar.disabled,bar.disabledTooltip=nil,nil
    bar.swatches={Swatch('active','Active Buff Color'),Swatch('missing','Missing Buff Color'),Swatch('expiring','Expiring Buff Color')}
    bar.preview={tip='Preview the bar and a cue',show=NS.PreviewEllesmereClassBuffs,duration=3,disabled=Off,disabledTooltip=MASTER}
    local cogRows={
        {type='slider',label='Icon Size',min=20,max=48,step=1,get=function() return Settings().size end,set=function(v) Set('size',v) end},
        {type='slider',label='Spacing',min=0,max=12,step=1,get=function() return Settings().spacing end,set=function(v) Set('spacing',v) end},
        {type='dropdown',label='Orientation',values={horizontal='Horizontal',vertical='Vertical'},order={'horizontal','vertical'},
            get=function() return Settings().orientation end,set=function(v) Set('orientation',v) end},
        {type='toggle',label='Dim Inactive Buffs',get=function() return Settings().dim end,set=function(v) Set('dim',v) end},
        {type='toggle',label='Pulse Missing Buffs',get=function() return Settings().pulse end,set=function(v) Set('pulse',v) end}}
    if class=='DRUID' then
        cogRows[#cogRows+1]={type='toggle',label='Hide In Forms',get=function() return Settings().formsHide end,set=function(v) Set('formsHide',v) end}
    end
    bar.cog={title='Class Buff Bar Layout',disabled=Off,disabledTooltip=MASTER,rows=cogRows}
    Row(bar,Drop('Class Buff Bar Visibility','visibility',{always='Always',combat='In Combat',mouseover='Mouseover',missing='Only When Missing'},
        {'always','combat','mouseover','missing'},'Only When Missing shows the bar out of combat while a buff is missing or expiring; it does not change in combat.'))
    Row(Toggle('Buff Timers','timers','Time left on each buff that is up.'),Toggle('Buff Charges','charges','Charges left (Inner Fire, shields).'))
    local soundDrop=Drop('Cue Sound','sound',{none='None',raid='Raid Warning',alarm='Alarm',ready='Ready Check',tick='Tick'},{'none','raid','alarm','ready','tick'},
        'Played when a class buff cue appears, in place of the lane sound. None keeps the lane sound.',NoCues,'Missing / Expiring Cues')
    soundDrop.setValue=function(v)
        Set('sound',v)
        if Valid('sound',v) and v~='none' and NS.PlayEllesmereCueSound then NS.PlayEllesmereCueSound(v,'classBuffsSoundPreview') end
    end
    Row(Toggle('Missing / Expiring Cues','cues','Missing, expiring and low-charge warnings in the warning lane. Most buffs warn out of combat; seals only while you melee in combat.'),soundDrop)
    local extra=blank()
    if class=='PRIEST' then extra=Slider('Inner Fire Low Charges','lowInnerFire',0,19,1,'Warn when Inner Fire has this many charges or fewer (Forever: 20). 0 is off.',NoCues,'Missing / Expiring Cues')
    elseif class=='SHAMAN' then extra=Slider('Shield Low Charges','lowShield',0,8,1,'Warn when your shield has this many charges or fewer. 0 is off.',NoCues,'Missing / Expiring Cues') end
    Row(Slider('Expiring Warning Time','expiry',0,600,15,'Seconds left on a long buff (10 minutes or more) when the expiring cue starts. 0 is off.',NoCues,'Missing / Expiring Cues'),extra)
    local abrGroup
    for _,g in ipairs(mine) do if g.abr then abrGroup=g;break end end
    Row(Toggle('Quiet While Resting','quietResting','No buff cues in a city or inn. They return when you leave or enter an instance.',NoCues,'Missing / Expiring Cues'),
        class=='PALADIN' and Toggle('Seal Cue Above Character','sealCritical','NO SEAL in the combat lane above your character. It waits 1.6 seconds after a seal drops or a Judgement.',NoCues,'Missing / Expiring Cues')
        or abrGroup and Toggle('Leave Raid Buffs To Ellesmere','leaveRaidBuffs','In instances, Ellesmere\'s AuraBuff Reminders already reminds you about '..abrGroup.label..'. Its cue here stays quiet there; the button and highlight stay.',NoCues,'Missing / Expiring Cues')
        or blank())
    for _,g in ipairs(mine) do
        if g.fury then
            Row(Toggle('Righteous Fury Button','show_fury','Left click casts Righteous Fury; right click cancels it.'),
                Drop('Righteous Fury Cue','fury',{ignore='Ignore',wanted='Wanted',unwanted='Unwanted'},{'ignore','wanted','unwanted'},
                    'Wanted: warn while it is missing (tanking). Unwanted: warn while it is on.',NoCues,'Missing / Expiring Cues'))
        else
            Row(Toggle(g.label..' Buttons','show_'..g.key),Toggle(g.label..' Cue','cue_'..g.key,nil,NoCues,'Missing / Expiring Cues'))
        end
    end
    if class=='PALADIN' then
        Row(Drop('Preferred Blessing','blessing',{any='Any Blessing',might='Might',wisdom='Wisdom',kings='Kings',salvation='Salvation',light='Light',sanctuary='Sanctuary'},
            {'any','might','wisdom','kings','salvation','light','sanctuary'},'The blessing to keep on yourself. A Greater Blessing or another paladin\'s copy counts.'),
            Toggle('All Known Blessings','allBlessings','Show every blessing you know, not only the preferred one.',function() return Off() or Settings().blessing=='any' end,'Preferred Blessing'))
        Row(Toggle('Resistance Auras','resistAuras','Adds Shadow, Frost and Fire Resistance Aura buttons.'),blank())
    end
    Row({type='label',text='Move the bar in Unlock Mode: Class Buffs'},
        {type='button',text='Reset Class Buff Colors',onClick=function() Settings().colors=nil;NS.SyncEllesmereClassBuffs() end})
    Row({type='button',text='Reset Class Buff Bar',onClick=function()
        local s=Settings();local keep,where=s.enabled,s.position
        for k in pairs(s) do s[k]=nil end
        s.enabled,s.position=keep,where;NS.SyncEllesmereClassBuffs()
    end},blank())
end

local boot=CreateFrame('Frame')
boot:RegisterEvent('PLAYER_LOGIN')
boot:SetScript('OnEvent',function(self) self:UnregisterAllEvents();NS.SyncEllesmereClassBuffs() end)
