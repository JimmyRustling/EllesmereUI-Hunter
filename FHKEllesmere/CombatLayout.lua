-- Combat Layout (UI audit, 2026-10-03): one reversible preset that builds a
-- centre stack around the swing bar, so the combat loop (swing, shot cooldowns,
-- own and pet health, "is it on me") stays within about 300 px of the character.
-- Every value it writes goes through the owning Ellesmere module's own profile
-- and refresh; the exact previous values are kept per character and profile.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end

local driver=CreateFrame('Frame')
local pending
local function Copy(v)
    if type(v)~='table' then return v end
    local out={};for k,x in pairs(v) do out[k]=Copy(x) end;return out
end
local function ProfileName() return EllesmereUIDB and EllesmereUIDB.activeProfile or 'Default' end
local function Module(name) return EUI._ModuleNS and EUI._ModuleNS[name] end
local function UnitFrames()
    local ns=Module('EllesmereUIUnitFrames')
    return ns,ns and ns.db and ns.db.profile
end
local function Cooldowns()
    local ns=Module('EllesmereUICooldownManager')
    return ns,ns and ns.ECME and ns.ECME.db and ns.ECME.db.profile
end
local function ResourceBars()
    local ns=Module('EllesmereUIResourceBars')
    return ns,ns and ns.ERB and ns.ERB.db and ns.ERB.db.profile
end
local function ActionBars()
    local ns=Module('EllesmereUIActionBars')
    return ns,ns and ns.EAB and ns.EAB.db and ns.EAB.db.profile
end

-- Geometry in UI units from the screen centre (y up). The native swing timer is
-- the spine: 260 wide, two 16-unit rows (35 tall). It moves 10.5 units down from
-- its native -137 so the range block sits centred directly above it (player).
local SWING_ANCHOR=-147.5
local SWING_HALF,SWING_TOP,SWING_BOTTOM=130,-130,-165
local ROW_TOP=-72            -- frames and the essential cooldown row share this top
local BLOCK_W,BLOCK_H=48,14  -- range block: SWING_TOP+2 .. +16
-- Attack squares sit either side of the range block with labels underneath
-- (player, option A): the block and squares lift 10 units so the 8-unit labels
-- end 2 units above the swing bar; the essential row rises to stay clear.
local ATTACK_ICON,LIFT=18,10
local ATTACK_BOTTOM=SWING_TOP+2+LIFT  -- -118: block and squares share this line
local GAP,TIGHT,CAST=8,4,14
-- Frames sit 12 units out from the swing bar: room for the target's range strip,
-- which faces the centre (player), plus the 4-unit tight gap.
local FRAME_GAP=12
local ESSENTIAL,UTILITY,PROCS=40,30,24
local SIDE_BARS={'Bar4','Bar5','Bar6','Bar7'}
local MAIN_BARS={'MainBar','Bar2','Bar3'}
local VISIBILITY={'barVisibility','visibilityModes','visibilityMatch','alwaysHidden','mouseoverEnabled',
    'mouseoverAlpha','_savedBarAlpha','combatHideEnabled','combatShowEnabled'}
local RETIRED={'player.rightTextSize','player.rightTextColorR',
    'player.rightTextColorG','player.rightTextColorB','pet.rightTextColorR',
    'pet.rightTextColorG','pet.rightTextColorB','target.powerHeight'}
local DIM_RANGE={r=.38,g=.40,b=.45}   -- out of range dims; red stays for danger
-- Cursor rings (player: they took loads of screen; then still a little large).
-- Sized for the player's 16-inch 2560x1440 panel at UI scale 0.8 (1 unit = 1.5 px
-- = 0.21 mm). Stack: cursor 17, GCD, Auto Shot, melee, then the cast ring, in
-- thin ring art with 1.5-unit (2 px) gaps. SwingCursor nests the swing rings
-- from the GCD radius.
-- Third pass (player: "weapon swing timer rings are huge"): the swing rings hug
-- the GCD and the cast ring goes outermost, shown only while casting (the Auto
-- Shot ring already turns rose for shot casts). Auto Shot r13.8 (41 px), melee
-- r16.9 (51 px, only when melee is actionable), cast r21 outside them.
local CURSOR_GCD,CURSOR_CAST,SWING_MIN,RING_TEX=11,21,10,'thin'
-- The crossed swords over plates and under the character are the game's
-- soft-target icons. Ellesmere hides the enemy one only while the attackable
-- read is public, so in combat it came back: one combat glyph means these go.
local ICON_CVARS={SoftTargetIconEnemy='0',SoftTargetIconFriend='0'}

-- Undo: {root,path...} -> {value}. A path seen once keeps its first value.
local function Store(write)
    if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end
    local all=rawget(FHKEllesmereDB,'combatLayout')
    if write and not all then all={};rawset(FHKEllesmereDB,'combatLayout',all) end
    local name=ProfileName()
    if write and not all[name] then all[name]={} end
    if write and NS.EllesmereStampSnapshot then NS.EllesmereStampSnapshot('combatLayout',name) end
    return all and all[name]
end
local function Set(undo,area,tbl,path,key,value)
    undo[area]=undo[area] or {}
    local slot=path..'.'..key
    if undo[area][slot]==nil then undo[area][slot]={value=Copy(tbl[key]),path=path,key=key} end
    tbl[key]=Copy(value)
end
local function Walk(root,path)
    local t=root
    for part in path:gmatch('[^%.]+') do
        local index=tonumber(part)
        local nextT=t[index or part]
        if type(nextT)~='table' then nextT={};t[index or part]=nextT end
        t=nextT
    end
    return t
end
local function CdmBar(p,key)
    for i,bar in ipairs(p.cdmBars and p.cdmBars.bars or {}) do
        if bar.key==key then return bar,'cdmBars.bars.'..i end
    end
end
local function Dimensions(uf,unit,w,h)
    if uf.GetFrameDimensions then
        local ok,fw,fh=pcall(uf.GetFrameDimensions,unit)
        if ok and type(fw)=='number' and type(fh)=='number' and fw>0 and fh>0 then return fw,fh end
    end
    return w,h
end
local function Place(x,y) return {point='CENTER',relPoint='CENTER',x=x,y=y} end

local function Refresh()
    local uf=UnitFrames()
    if uf then
        if uf.ReloadFrames then pcall(uf.ReloadFrames) end
        for _,unit in ipairs({'player','target','pet','targettarget','focus'}) do
            local f=uf.frames and uf.frames[unit]
            if f and uf.ApplyFramePosition then pcall(uf.ApplyFramePosition,f,unit) end
        end
    end
    local cdm=Cooldowns()
    if cdm and cdm.BuildAllCDMBars then pcall(cdm.BuildAllCDMBars) end
    local ab=ActionBars()
    if ab and ab._eabApplyAll then pcall(ab._eabApplyAll) end
    local rb=ResourceBars()
    if rb and rb.ERB and rb.ERB.ApplyAll then pcall(rb.ERB.ApplyAll,rb.ERB) end
    if EUI._applySavedPositions then pcall(EUI._applySavedPositions) end
    for _,name in ipairs({'_ECL_Apply','_ECL_ApplyGCDCircle','_ECL_ApplyCastCircle'}) do
        if type(_G[name])=='function' then pcall(_G[name]) end
    end
    if NS.ApplySwingCursor then NS.ApplySwingCursor() end
    if NS.ApplyEllesmereIndicators then NS.ApplyEllesmereIndicators() end
    if NS.SyncEllesmereUnitRefinements then NS.SyncEllesmereUnitRefinements() end
    if NS.SyncEllesmereCombatFade then NS.SyncEllesmereCombatFade() end
end

function NS.EllesmereCombatLayoutApplied()
    local s=Store()
    return s~=nil and s.applied==true
end
function NS.ApplyEllesmereCombatLayout()
    if InCombatLockdown() then pending={apply=true,profile=ProfileName()};driver:RegisterEvent('PLAYER_REGEN_ENABLED');return false,'Combat Layout queued until combat ends.' end
    local uf,ufp=UnitFrames()
    local _,cdp=Cooldowns()
    local abns,abp=ActionBars()
    if not ufp then return false,'Ellesmere Unit Frames are not loaded.' end
    local undo=Store(true)
    ufp.positions=ufp.positions or {}
    -- Unit frame text and sizes first: positions are computed from the new sizes.
    local function U(unit,key,value) Set(undo,'uf',Walk(ufp,unit),unit,key,value) end
    -- Retired from the layout after review (player): the slim target power row
    -- crushed its text, and a grey raw value on a coloured fill read muddy. A
    -- profile that took them gets its own values back here.
    for _,slot in ipairs(RETIRED) do
        local entry=undo.uf and undo.uf[slot]
        if entry and entry.key then Walk(ufp,entry.path)[entry.key]=Copy(entry.value);undo.uf[slot]=nil end
    end
    -- Readouts face the centre (player): health and power on the player frame's
    -- right, on the target frame's left, so the eye stays near the swing bar.
    U('player','leftTextContent','none');U('player','rightTextContent','perhpnum')
    U('player','powerPercentText','right')
    -- Target matches the player: health % | # and power % | #. Level leads the
    -- name, so a long name truncates instead of the level (player screenshot).
    U('target','leftTextContent','perhpnum');U('target','rightTextContent','levelname')
    U('target','powerPercentText','left');U('target','powerTextFormat','perppnum')
    -- The pet sits under the player's inner half, so its health faces the centre too.
    U('pet','leftTextContent','none');U('pet','rightTextContent','perhpnum')
    -- Target auras above the frame: below it they covered target of target.
    U('target','debuffAnchor','topleft');U('target','buffAnchor','topright')
    -- Player debuffs above the frame too (below it they covered the pet frame);
    -- buffs keep the left, so the two frames mirror each other.
    U('player','debuffAnchor','topright')
    -- Status column (player): status icons sit just outside each frame's outer
    -- edge, vertically centred, never over bars or numbers. Player: combat.
    -- Pet: combat (drawn by UnitRefinements) then the happiness square. Every
    -- status slot is 16 units, centred 12 units out, so the white combat blocks
    -- on both frames share one line.
    local playerHealth=ufp.player and ufp.player.healthHeight or 46
    U('player','combatIndicatorPosition','topleft');U('player','combatIndicatorSize',16)
    U('player','combatIndicatorX',-20);U('player','combatIndicatorY',-(playerHealth-16)/2)
    -- Target: its own combat state (player: "combat indicator on target frame is
    -- missing"), mirrored outside the right edge. The white block draws over it.
    local targetHealth=ufp.target and ufp.target.healthHeight or 46
    U('target','combatIndicatorStyle','standard');U('target','combatIndicatorPosition','topright')
    U('target','combatIndicatorSize',16);U('target','combatIndicatorX',20);U('target','combatIndicatorY',-(targetHealth-16)/2)
    U('pet','happinessAlign','left');U('pet','happinessSize',16);U('pet','happinessX',-24);U('pet','happinessY',0)
    U('targettarget','frameWidth',181);U('targettarget','healthHeight',20)
    local pw,ph=Dimensions(uf,'player',181,60)
    local tw,th=Dimensions(uf,'target',181,52)
    local petw,peth=Dimensions(uf,'pet',101,25)
    local ttw,tth=Dimensions(uf,'targettarget',181,20)
    local fw,fh=Dimensions(uf,'focus',160,48)
    -- Frames flank the swing bar 12 units out, tops level with the cooldown row.
    local top=ROW_TOP
    local px,tx=-(SWING_HALF+FRAME_GAP+pw/2),SWING_HALF+FRAME_GAP+tw/2
    -- Below each frame: room for its anchored cast bar, then pet / target of target.
    local below=top-math.max(ph,th)-TIGHT-CAST-TIGHT
    local positions={
        player=Place(px,top-ph/2),
        target=Place(tx,top-th/2),
        pet=Place(px+pw/2-petw/2,below-peth/2),     -- inner edges flush (player)
        targettarget=Place(tx+tw/2-ttw/2,below-tth/2),
        focus=Place(tx+tw/2-fw/2,below-tth-GAP-fh/2),
    }
    for unit,pos in pairs(positions) do Set(undo,'uf',ufp.positions,'positions',unit,pos) end
    -- Cooldown Manager: essential row over the swing bar, procs above it,
    -- utility under it; all centred and the swing bar's width at six icons.
    if cdp then
        cdp.cdmBarPositions=cdp.cdmBarPositions or {}
        -- Procs sit under utility: above the essential row they reached the
        -- character's feet and the centre cast bar.
        for key,spec in pairs({cooldowns={ESSENTIAL,4,ATTACK_BOTTOM+ATTACK_ICON+2+ESSENTIAL/2},
            utility={UTILITY,4,SWING_BOTTOM-GAP-UTILITY/2},buffs={PROCS,2,SWING_BOTTOM-GAP-UTILITY-6-PROCS/2}}) do
            local bar,path=CdmBar(cdp,key)
            if bar then
                Set(undo,'cdm',bar,path,'iconSize',spec[1]);Set(undo,'cdm',bar,path,'spacing',spec[2])
                Set(undo,'cdm',bar,path,'anchorTo','none')
                -- Undo finds the bar by its key, not its list position (review R11).
                for _,field in ipairs({'iconSize','spacing','anchorTo'}) do
                    local entry=undo.cdm and undo.cdm[path..'.'..field]
                    if entry then entry.barKey=key end
                end
                Set(undo,'cdm',cdp.cdmBarPositions,'cdmBarPositions',key,Place(0,spec[3]))
            end
        end
    end
    -- Swing timer down 10.5 units: the range block takes the space above it.
    local rbns,rbp=ResourceBars()
    if rbp and type(rbp.swingTimer)=='table' then Set(undo,'rb',rbp.swingTimer,'swingTimer','anchorY',SWING_ANCHOR) end
    -- Action bars: side clusters on hover only; out-of-range icons dim instead of red.
    if abp and abp.bars and EUI.SetVisibilitySelection and abns and abns.EAB and abns.EAB.VisibilityCompat then
        for _,key in ipairs(SIDE_BARS) do
            local s=abp.bars[key]
            if s then
                for _,field in ipairs(VISIBILITY) do Set(undo,'ab',s,'bars.'..key,field,s[field]) end
                s.visibilityMatch='any'
                EUI.SetVisibilitySelection(s,'barVisibility',{mouseover=true},abns.EAB.VisibilityCompat.ApplyMode)
            end
        end
        for _,key in ipairs(MAIN_BARS) do
            local s=abp.bars[key]
            if s then
                Set(undo,'ab',s,'bars.'..key,'outOfRangeColoring',true)
                Set(undo,'ab',s,'bars.'..key,'outOfRangeColor',DIM_RANGE)
            end
        end
    end
    -- Companion: range as a weapon icon instead of a full-width row,
    -- names keep their colour for priority, a wider black-edged frame strip, the
    -- attack cue under the utility row, and quiet guides in combat.
    local db=FHKEllesmereDB
    local function F(path,tbl,key,value) Set(undo,'fhk',tbl,path,key,value) end
    if NS.EllesmereIndicatorSettings then
        -- Range stays, as a weapon icon whose border is the range colour, beside
        -- the attack cue (player: "an action bar icon that changes colour").
        local rs=NS.EllesmereIndicatorSettings('range')
        F('indicators.range',rs,'orientation','block')
        F('indicators.range',rs,'blockWidth',BLOCK_W);F('indicators.range',rs,'blockHeight',BLOCK_H)
        F('indicators.range',rs,'enabled',true)
        F('indicators.range',rs,'position',{point='TOP',relPoint='CENTER',x=0,y=ATTACK_BOTTOM+BLOCK_H})
        F('indicators.frame',NS.EllesmereIndicatorSettings('frame'),'borderSize',3)
        F('indicators.frame',NS.EllesmereIndicatorSettings('frame'),'side','left') -- faces the centre
        F('indicators.frame',NS.EllesmereIndicatorSettings('frame'),'thickness',7)
        -- Attack indicators flank the range block (player): framed squares,
        -- Auto Shot / Shoot left (it turns lime RETRY when retrying), melee
        -- right, 6 units from the block, labels underneath.
        local attacks=NS.EllesmereIndicatorSettings('attacks')
        F('indicators.attacks',attacks,'orientation','flank');F('indicators.attacks',attacks,'gap',6)
        F('indicators.attacks',attacks,'labels',true)
        F('indicators.attacks',attacks,'position',{point='TOP',relPoint='CENTER',x=0,y=ATTACK_BOTTOM+ATTACK_ICON})
        F('',db,'attackCueSize',ATTACK_ICON)
    end
    local getCVar,setCVar=C_CVar and C_CVar.GetCVar,C_CVar and C_CVar.SetCVar
    if getCVar and setCVar then
        -- These CVars are character-wide (review R10): one original per character, kept until
        -- the last profile with the layout is undone.
        local before=rawget(FHKEllesmereDB,'combatLayoutCVars')
        if type(before)~='table' then before={};rawset(FHKEllesmereDB,'combatLayoutCVars',before) end
        for name,value in pairs(ICON_CVARS) do
            local now=getCVar(name)
            if type(now)=='string' then
                if before[name]==nil then before[name]=now end
                setCVar(name,value)
            end
        end
    end
    local ecl=_G._ECL_AceDB and _G._ECL_AceDB.profile
    if ecl then
        -- The class-coloured cursor ring takes the same thin art (player: align it
        -- with the others). At its 17-unit size its edge already sits 1.5 units
        -- inside the GCD ring, the gap every ring keeps.
        Set(undo,'cursor',ecl,'','texture','ring_thin')
        if type(ecl.gcd)=='table' then
            Set(undo,'cursor',ecl.gcd,'gcd','radius',CURSOR_GCD);Set(undo,'cursor',ecl.gcd,'gcd','ringTex',RING_TEX)
        end
        if type(ecl.castCircle)=='table' then
            Set(undo,'cursor',ecl.castCircle,'castCircle','radius',CURSOR_CAST);Set(undo,'cursor',ecl.castCircle,'castCircle','ringTex',RING_TEX)
        end
    end
    if type(db.swingCursor)=='table' then
        F('swingCursor',db.swingCursor,'radius',SWING_MIN);F('swingCursor',db.swingCursor,'avoidCast',false)
    end
    F('',db,'rangeNameColors',false)
    F('',db,'combatFadeGuides',true)
    undo.applied=true
    pending=nil
    Refresh()
    return true
end
local function Restore(area,root,undo)
    for slot,entry in pairs(undo[area] or {}) do
        if type(entry)=='table' and entry.key and not entry.barKey then
            local t=entry.path~='' and Walk(root,entry.path) or root
            t[entry.key]=Copy(entry.value)
        end
    end
end
function NS.UndoEllesmereCombatLayout()
    if InCombatLockdown() then pending={undo=true,profile=ProfileName()};driver:RegisterEvent('PLAYER_REGEN_ENABLED');return false,'Undo queued until combat ends.' end
    local undo=Store()
    if not undo or not undo.applied then return false,'Combat Layout is not applied on this profile.' end
    local _,ufp=UnitFrames()
    local _,cdp=Cooldowns()
    local _,abp=ActionBars()
    if ufp then Restore('uf',ufp,undo) end
    if cdp then
        for _,entry in pairs(undo.cdm or {}) do
            if type(entry)=='table' and entry.barKey and entry.key then
                local bar=CdmBar(cdp,entry.barKey)
                if bar then bar[entry.key]=Copy(entry.value) end
            end
        end
        Restore('cdm',cdp,undo)
    end
    if abp then Restore('ab',abp,undo) end
    local _,rbp=ResourceBars()
    if rbp then Restore('rb',rbp,undo) end
    local ecl=_G._ECL_AceDB and _G._ECL_AceDB.profile
    if ecl then Restore('cursor',ecl,undo) end
    -- Companion paths are relative to the indicator tables or the flat store.
    for slot,entry in pairs(undo.fhk or {}) do
        if type(entry)=='table' and entry.key then
            local kind=entry.path:match('^indicators%.(.+)$')
            local t=kind and NS.EllesmereIndicatorSettings and NS.EllesmereIndicatorSettings(kind) or
                entry.path~='' and Walk(FHKEllesmereDB,entry.path) or FHKEllesmereDB
            t[entry.key]=Copy(entry.value)
        end
    end
    local all=rawget(FHKEllesmereDB,'combatLayout');if all then all[ProfileName()]=nil end
    local others=false
    for _,record in pairs(all or {}) do if type(record)=='table' and record.applied then others=true end end
    local setCVar=C_CVar and C_CVar.SetCVar
    if setCVar and not others then
        -- Older records kept the originals per profile; the character copy wins when present.
        local before=rawget(FHKEllesmereDB,'combatLayoutCVars')
        for name,value in pairs(type(before)=='table' and before or undo.cvar or {}) do setCVar(name,value) end
        rawset(FHKEllesmereDB,'combatLayoutCVars',nil)
    end
    pending=nil
    Refresh()
    return true
end

-- Guides and split timers fade to 40 % in combat (background information).
local GUIDES={'RXPFrame','ForeverSplitsOverlay'}
local faded={}
function NS.SyncEllesmereCombatFade()
    local on=FHKEllesmereDB and FHKEllesmereDB.combatFadeGuides==true
    if on then driver:RegisterEvent('PLAYER_REGEN_DISABLED');driver:RegisterEvent('PLAYER_REGEN_ENABLED')
    elseif not pending then driver:UnregisterEvent('PLAYER_REGEN_DISABLED');driver:UnregisterEvent('PLAYER_REGEN_ENABLED') end
    local fight=on and InCombatLockdown()
    for _,name in ipairs(GUIDES) do
        local f=_G[name]
        if f and f.SetAlpha and f.GetAlpha then
            if fight and not faded[name] then faded[name]=f:GetAlpha();f:SetAlpha(faded[name]*.4)
            elseif not fight and faded[name] then f:SetAlpha(faded[name]);faded[name]=nil end
        end
    end
end
driver:RegisterEvent('PLAYER_LOGIN')
driver:SetScript('OnEvent',function(_,event)
    if event=='PLAYER_LOGIN' then NS.SyncEllesmereCombatFade();return end
    if event=='PLAYER_REGEN_ENABLED' and pending then
        -- A request made on another profile is dropped, not replayed later (review R13).
        local todo=pending;pending=nil
        if todo.profile==ProfileName() then
            if todo.apply then NS.ApplyEllesmereCombatLayout() elseif todo.undo then NS.UndoEllesmereCombatLayout() end
        end
    end
    NS.SyncEllesmereCombatFade()
end)

SLASH_FHKLAYOUT1='/fhklayout'
SlashCmdList.FHKLAYOUT=function(input)
    local cmd=tostring(input or ''):lower():match('^%s*(%S*)')
    local ok,message
    if cmd=='undo' then ok,message=NS.UndoEllesmereCombatLayout()
    elseif (cmd=='' or cmd=='apply') and _G.ForeverHunterKeysNS==nil then
        -- The owner's arrangement: never applied on a published install (undo still works).
        print('FHK: the Combat Layout is part of the Forever Hunter Keys setup; /fhklayout undo restores an earlier one.');return
    elseif cmd=='' or cmd=='apply' then ok,message=NS.ApplyEllesmereCombatLayout()
    else print('FHK: /fhklayout applies the Combat Layout; /fhklayout undo restores your previous layout.');return end
    print('FHK: '..(ok and (cmd=='undo' and 'Combat Layout undone; your previous layout is back.' or
        'Combat Layout applied. /fhklayout undo restores your previous layout.') or message or 'Combat Layout could not be applied.'))
end
