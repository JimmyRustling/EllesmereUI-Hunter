-- Use EUI's native engine-driven rows, options, visibility and unlock mover.
-- Our shared hunter clock adds bow resets after melee; no duplicate renderer.
local EUI, NS = _G.EllesmereUI, _G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS or select(2,UnitClass('player')) ~= 'HUNTER' then return end
local driver = CreateFrame('Frame')
local installed, queued, optionsWrapper
local rows = setmetatable({}, {__mode='k'})
local function Plain(value)
    return not (issecretvalue and issecretvalue(value)) and type(value)=='number' and value==value
end
local function Config()
    local ns=EUI._ModuleNS and EUI._ModuleNS.EllesmereUIResourceBars
    local db=ns and ns.ERB and ns.ERB.db
    return ns,db and db.profile and db.profile.swingTimer
end
-- Melee readiness only earns its colour when melee is an option (player review:
-- a full violet MELEE READY bar at 30-35 yd was the loudest thing on screen).
-- Range is sampled at most five times a second, and only while the row is ready.
-- Actionable = in melee, or in the deadzone (one step in). A momentary unknown
-- read (player: violet flashed as an Auto Shot fired, at any range) keeps the
-- last real answer for the same target; only a target never read counts as yes.
local nearAt,nearValue,knownValue,knownGuid
local QUIET={.25,.26,.29}
local function MeleeActionable(now)
    if nearAt and now-nearAt<.2 then return nearValue end
    local guid=UnitGUID and UnitGUID('target')
    if issecretvalue and issecretvalue(guid) then guid=nil end
    if guid~=knownGuid then knownGuid,knownValue=guid,nil end
    local range=NS.GetUnitRange and NS.GetUnitRange('target')
    local s=range and range.state
    if s==nil or s=='unknown' then
        if knownValue==nil then nearValue=true else nearValue=knownValue end
    else
        nearValue=s=='melee' or s=='close'
        knownValue=nearValue
    end
    nearAt=now
    return nearValue
end
-- Shared with the cursor rings, so MELEE READY means the same thing on both.
NS.EllesmereMeleeActionable=MeleeActionable
-- An attack's timer shows only while that attack is switched on (player: "when
-- Auto Shot is active it shows, when auto attack is active it shows"). Live
-- current-spell reads, plus the companion's start/stop event state.
local function Current(id)
    local getter=C_Spell and C_Spell.IsCurrentSpell or IsCurrentSpell
    if type(getter)~='function' then return false end
    local ok,v=pcall(getter,id)
    return ok and not (issecretvalue and issecretvalue(v)) and v==true
end
local function AttacksOn()
    local rangedFlag,meleeFlag
    if NS.EllesmereAttackState then rangedFlag,meleeFlag=NS.EllesmereAttackState() end
    return (rangedFlag or Current(75) or Current(5019) or Current(2764)) and true or false,
        (meleeFlag or Current(6603)) and true or false
end
NS.EllesmereAttacksOn=AttacksOn
function NS.EllesmereRealMeleeSwing(duration)
    return Plain(duration) and duration>=.5
end
-- Auto Shot is actionable inside shooting range; unknown counts as yes.
local function RangedActionable()
    local range=NS.GetUnitRange and NS.GetUnitRange('target')
    local s=range and range.state
    return s==nil or s=='shoot' or s=='unknown'
end
-- Spark colour per weapon (forum request; off = the restrained white line). Bright
-- tones of the row colours, so the spark reads against the deep fill.
local sparkStamp=0
local SPARK_KEYS={}
local function SparkDefaults()
    local c=NS.Colours or {}
    return {ranged=c.shoot or {.25,.84,.66},main=c.melee or {199/255,135/255,1},off={.96,.945,.925}}
end
local function SparkKind(def)
    local t=Enum.PlayerSwingType
    return def.type==t.Ranged and 'ranged' or def.type==t.MainHand and 'main' or 'off'
end
local function SparkColour(cfg,kind)
    if not cfg.fhkSparkColors then return nil end
    local own=type(cfg.fhkSpark)=='table' and cfg.fhkSpark[kind]
    return type(own)=='table' and own or SparkDefaults()[kind]
end
NS.EllesmereSparkColour=SparkColour
-- Auto Shot latency zone (forum request: "so Hunters know when it's safe to move"):
-- the last world-latency milliseconds of the ranged row. Latency is read at most
-- every 10 seconds, and only while the zone shows.
local latencyAt,latencyMs=nil,0
local function Latency(now)
    if latencyAt and now-latencyAt<10 then return latencyMs end
    latencyAt=now
    if type(GetNetStats)=='function' then
        local ok,_,_,home,world=pcall(GetNetStats)
        local ms=ok and (Plain(world) and world>0 and world or Plain(home) and home) or nil
        if Plain(ms) then latencyMs=ms end
    end
    return latencyMs
end
NS.EllesmereSwingLatency=function(now) latencyAt=nil;return Latency(now or GetTime()) end
local function PaintLatency(row,state,cfg,show,duration,now)
    local zone=state.zone
    if not show then if zone then zone:Hide() end return end
    local ms=Latency(now)
    local width=row._bar.GetWidth and row._bar:GetWidth()
    if not (Plain(width) and width>0 and ms>0) then if zone then zone:Hide() end return end
    if not zone then
        zone=row._bar:CreateTexture(nil,'OVERLAY',nil,5)
        zone:SetColorTexture(1,1,1,1)
        state.zone=zone
    end
    local size=math.max(1,math.min(1,ms/1000/duration)*width)
    -- The swing ends at the right edge while filling, at the left edge while depleting.
    local edge=cfg.depleteFill and 'LEFT' or 'RIGHT'
    if state.zoneSize~=size or state.zoneEdge~=edge then
        zone:ClearAllPoints()
        zone:SetPoint('TOP'..edge,row._bar,'TOP'..edge,0,0)
        zone:SetPoint('BOTTOM'..edge,row._bar,'BOTTOM'..edge,0,0)
        zone:SetWidth(size)
        state.zoneSize,state.zoneEdge=size,edge
    end
    local c=NS.Colours and NS.Colours.danger or {1,.3,.25}
    zone:SetVertexColor(c[1],c[2],c[3],.45)
    zone:Show()
end
-- Raptor Strike queue (plan 9.9): Ellesmere colours a queued on-next-swing attack for
-- Warriors and Druids only (its QUEUE_SPELLS list is private). Same behaviour for Hunters:
-- IsCurrentSpell by name while Raptor Strike waits for the next swing, the native Queue
-- Highlight switch and queue colour, and the native "MELEE - <name>" label.
local RAPTOR=2973
local raptorName
local queueColour={1,.7,.2}
local function RaptorQueued(cfg)
    if cfg.queueHighlight==false or not (C_Spell and C_Spell.IsCurrentSpell) then return false end
    if not raptorName then
        local ok,name=pcall(C_Spell.GetSpellName,RAPTOR)
        if ok and type(name)=='string' and not (issecretvalue and issecretvalue(name)) then raptorName=name else return false end
    end
    local ok,cur=pcall(C_Spell.IsCurrentSpell,raptorName)
    return ok and not (issecretvalue and issecretvalue(cur)) and cur==true
end
NS.EllesmereRaptorQueued=RaptorQueued
-- Auto Shot clipping marker (plan 10.3 P3): while Aimed Shot or Multi-Shot casts, a tick
-- on Ellesmere's cast bar marks when the next Auto Shot is due; finishing the cast after it
-- delays that shot. Advisory, from the shared ranged clock; hidden when the shot falls
-- outside the cast or the clock is unknown.
local CLIPPERS={[19434]=true,[2643]=true}
local clipTick
function NS.PaintEllesmereClipMarker()
    local _,cfg=Config()
    local bar=_G.ERB_CastBar
    local show=false
    if cfg and cfg.fhkClipMarker and bar and bar.CreateTexture and UnitCastingInfo then
        local ok,_,_,_,startMS,endMS,_,_,_,spellID=pcall(UnitCastingInfo,'player')
        local finish
        if NS.GetCursorSwingClock then local _;_,_,finish=NS.GetCursorSwingClock('ranged') end
        if ok and Plain(startMS) and Plain(endMS) and Plain(spellID) and CLIPPERS[spellID] and Plain(finish) and endMS>startMS then
            local frac=(finish-startMS/1000)/((endMS-startMS)/1000)
            local width=bar.GetWidth and bar:GetWidth()
            if frac>0 and frac<1 and Plain(width) and width>0 then
                if not clipTick then
                    clipTick=bar:CreateTexture(nil,'OVERLAY',nil,7);clipTick:SetColorTexture(1,1,1,1)
                end
                clipTick:ClearAllPoints()
                clipTick:SetPoint('TOP',bar,'TOPLEFT',width*frac,0);clipTick:SetPoint('BOTTOM',bar,'BOTTOMLEFT',width*frac,0)
                clipTick:SetWidth(EUI.PP and EUI.PP.FromPixels and EUI.PP.FromPixels(2) or 2)
                local c=NS.Colours and NS.Colours.shoot or {.25,.84,.66}
                clipTick:SetVertexColor(c[1],c[2],c[3],1)
                clipTick:Show();show=true
            end
        end
    end
    if not show and clipTick then clipTick:Hide() end
end
local children,childCount,childShell={}
local function RefineRows()
    local shell=_G.ERB_SwingTimerFrame
    local ns,cfg=Config()
    if not shell or not cfg or not cfg.enabled then driver:SetScript('OnUpdate',nil); return end
    local start,duration,finish=NS.GetCursorSwingClock('ranged')
    local meleeStart,meleeDuration,meleeEnd=NS.GetCursorSwingClock('melee')
    local now=GetTime()
    local cue,cs,cd,ce
    if NS.GetAutoShotCue then cue,cs,cd,ce=NS.GetAutoShotCue() end
    local rangedBusy=Plain(finish) and finish>now
    local meleeBusy=Plain(meleeEnd) and meleeEnd>now
    if cfg.showRetry~=false and (cue=='cast' or cue=='retry') and Plain(ce) and ce>now then
        start,duration,finish=cs,cd,ce
        rangedBusy=true
    else cue=nil end
    local shooting,swinging=AttacksOn()
    local raptor=RaptorQueued(cfg)
    -- Each Auto Shot touches the melee clock for about 0.1 s (player trace), which
    -- blinked MELEE READY away and the Auto Shot row to BOTH CD on every shot. A
    -- real melee swing lasts the weapon speed: it counts with or without auto
    -- attack on, so a weave still shows BOTH CD after stepping out (player).
    meleeBusy=meleeBusy and (swinging or NS.EllesmereRealMeleeSwing(meleeDuration))
    -- BOTH CD lives in the melee row (player: the melee swing is what puts both
    -- on cooldown). Its full bar is the time until the first attack frees up;
    -- then the other one runs a fresh bar for just its remainder (player: melee
    -- 2.8 s, Auto Shot 2 s -> BOTH fills over 2 s, AUTO SHOT READY comes up and
    -- the top bar shows the remaining 0.8 s of melee). A faster melee weapon is
    -- the mirror: MELEE READY on top, the Auto Shot row runs its remainder. The
    -- Auto Shot row folds away while both cool.
    local combined=cfg.hunterMode~='separate'
    local both=combined and not cue and rangedBusy and meleeBusy and not cfg.combineHands and
        Plain(meleeStart) and Plain(meleeDuration)
    local bothStart,bothDuration,bothEnd
    if both then
        if meleeEnd<=finish then bothStart,bothDuration,bothEnd=meleeStart,meleeDuration,meleeEnd
        else bothStart,bothDuration,bothEnd=start,duration,finish end
    end
    -- Remainders after a BOTH phase: the clock that outlived the other one runs
    -- from the moment the other freed up.
    local meleeRest
    if combined and not both and meleeBusy and Plain(finish) and Plain(meleeStart) and
        finish>meleeStart and finish<meleeEnd and finish<=now then
        meleeRest=finish
    end
    if combined and not both and not cue and rangedBusy and Plain(meleeEnd) and Plain(start) and
        NS.EllesmereRealMeleeSwing(meleeDuration) and meleeEnd>start and meleeEnd<finish and meleeEnd<=now then
        start,duration=meleeEnd,finish-meleeEnd
    end
    -- The row list changes only when Ellesmere adds a row; this loop runs 20 times a second.
    local count=shell.GetNumChildren and shell:GetNumChildren()
    if not count or count~=childCount or shell~=childShell then children,childCount,childShell={shell:GetChildren()},count,shell end
    for _,row in ipairs(children) do
        if row._def and row._bar and row._tag then
            local def=row._def
            if not rows[row] then
                rows[row]={}
                local state=rows[row]
                hooksecurefunc(row._tag,'SetText',function(self,text)
                    if state.painting then return end
                    local replacement=text=='MH' and 'MELEE' or text=='R' and 'AUTO SHOT'
                    if replacement then state.painting=true; self:SetText(replacement); state.painting=nil end
                end)
                local fill=row._bar.GetStatusBarTexture and row._bar:GetStatusBarTexture()
                -- A native repaint (Ellesmere's own swing events) gets our colour back
                -- at once, so it never shows for a frame.
                if fill then hooksecurefunc(fill,'SetVertexColor',function(self)
                    if state.painting then return end
                    if row._merged then state.color=nil;return end -- native hides merged rows
                    local c=state.color
                    if c then state.painting=true;self:SetVertexColor(c[1],c[2],c[3],1);state.painting=nil end
                end) end
            end
            local state=rows[row]
            if NS.ApplyEllesmereCueText then
                NS.ApplyEllesmereCueText(row._tag,'cue')
                NS.ApplyEllesmereCueText(row._time,'cue')
            end
            local text=row._tag:GetText()
            if text=='MH' or text=='R' then row._tag:SetText(text) end
            -- Restore the restrained spark after native style/size changes; a weapon
            -- colour when Weapon Spark Colors is on.
            if row._spark and not row._merged and (state.sparkHeight~=(cfg.height or 16) or state.sparkStamp~=sparkStamp) then
                row._spark:SetTexture('Interface\\Buttons\\WHITE8x8')
                row._spark:SetSize(1,cfg.height or 16)
                local c=SparkColour(cfg,SparkKind(def))
                if c then row._spark:SetVertexColor(c[1],c[2],c[3],1) else row._spark:SetVertexColor(1,1,1,.75) end
                state.sparkHeight,state.sparkStamp=cfg.height or 16,sparkStamp
            end
            if def.type==Enum.PlayerSwingType.Ranged and not EUI._unlockActive and
                Plain(start) and Plain(duration) and Plain(finish) and duration>0 and finish>GetTime() and
                (state.start~=start or state.duration~=duration or row._end~=finish) then
                -- Let the native event path update its live-row count and idle
                -- visibility before correcting the duration to our shared clock.
                local handler=shell:GetScript('OnEvent')
                if handler and row:IsShown() then
                    handler(shell,'PLAYER_SWING',duration,def.type)
                    row._end,row._dur=finish,duration
                    row._durObj:SetTimeFromStart(start,duration)
                    row._bar:SetTimerDuration(row._durObj,Enum.StatusBarInterpolation.Immediate,
                        cfg.depleteFill and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime)
                    state.start,state.duration=start,duration
                end
            end
            if row:IsShown() and not row._merged and not EUI._unlockActive then
                local isRanged=def.type==Enum.PlayerSwingType.Ranged
                local isMain=def.type==Enum.PlayerSwingType.MainHand
                local busy
                if isRanged then busy=rangedBusy elseif isMain and cfg.hunterMode~='separate' then busy=meleeBusy
                else busy=Plain(row._end) and row._end>now end
                -- Melee ready also shows while shooting, for weaving (player: another mob
                -- may be in reach without being the target); grey when the target is out
                -- of reach, violet when it is in reach.
                -- Active Row Only (forum request): the row of the attack you are using;
                -- no weave READY states, and the other row only while it really cools.
                local activeOnly=cfg.fhkActiveRowOnly==true
                local ready=isMain and not busy and (swinging or shooting and not activeOnly) and cfg.showMeleeReady~=false
                -- The mirror after a weave with a slower melee weapon (player): the
                -- bow frees up first, so AUTO SHOT READY shows while melee still cools,
                -- but only with Auto Shot off: switched on, it fires by itself, and a
                -- READY there only flashed between shots (player).
                if isRanged and not busy and meleeBusy and not shooting and not activeOnly then ready=true end
                -- A row shows whenever its timer is cooling (player: "show whenever
                -- something's on cooldown"), plus the READY states for weaving. While
                -- both cool, the melee row carries BOTH CD and the Auto Shot row folds.
                -- With Auto Shot on its row holds through the gap before the next shot,
                -- instead of fading out and back in on every cycle.
                local wanted=busy or ready or isRanged and shooting or isMain and raptor or cfg.hideWhenIdle==false
                if both then wanted=isMain or not isRanged and wanted end
                if activeOnly and isRanged and swinging and not shooting then wanted=false end
                PaintLatency(row,state,cfg,cfg.fhkLatencyZone==true and isRanged and busy and not cue and wanted and
                    Plain(duration) and duration>0,duration,now)
                if NS.FadeEllesmere then NS.FadeEllesmere(row,wanted) end
                -- The melee row's timer: BOTH CD to the first attack free, else its own
                -- swing (re-armed whenever Ellesmere's own swing event moved it).
                if isMain and combined then
                    local s,d,e
                    if both then s,d,e=bothStart,bothDuration,bothEnd
                    elseif busy and meleeRest then s,d,e=meleeRest,meleeEnd-meleeRest,meleeEnd
                    elseif busy then s,d,e=meleeStart,meleeDuration,meleeEnd end
                    if s and Plain(s) and Plain(d) and Plain(e) and d>0 and row._end~=e and row._durObj then
                        row._end,row._dur=e,d
                        row._durObj:SetTimeFromStart(s,d)
                        row._bar:SetTimerDuration(row._durObj,Enum.StatusBarInterpolation.Immediate,
                            cfg.depleteFill and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime)
                    end
                end
                -- Deep fills under the white bar labels; bright set as the fallback.
                -- Dark mode: a black fill, and the state colour as a 2px strip along
                -- the bottom of the fill, so colour only ever means a state.
                local dark=NS.EllesmereDarkMode and NS.EllesmereDarkMode()
                local function Pick(palette)
                    return isRanged and (cue and palette[cue] or palette.ranged) or
                        isMain and (both and palette.blocked or palette.melee)
                end
                local accent=Pick(NS.EllesmereSwingColors or {})
                local color=dark and NS.darkFill or Pick(NS.EllesmereSwingFillColors or NS.EllesmereSwingColors or {})
                -- Out of melee reach the melee row is quiet whether ready or cooling: an
                -- Auto Shot resets the shared clock, which briefly reads as a melee
                -- swing (player: violet flashed on every shot at range).
                if isMain and not both and (ready or busy) and not MeleeActionable(now) or isRanged and ready and not RangedActionable() then
                    if dark then accent=nil else color=NS.Colours and NS.Colours.quiet or QUIET end
                end
                -- Queued Raptor Strike: the native queue colour on the melee row.
                if isMain and raptor then
                    local q=queueColour
                    if q[1]~=(cfg.queueR or 1) or q[2]~=(cfg.queueG or .7) or q[3]~=(cfg.queueB or .2) then
                        queueColour={cfg.queueR or 1,cfg.queueG or .7,cfg.queueB or .2};q=queueColour
                    end
                    if dark then accent=q else color=q end
                end
                local fill=row._bar.GetStatusBarTexture and row._bar:GetStatusBarTexture()
                if color and state.color~=color and fill then
                    state.painting=true; fill:SetVertexColor(color[1],color[2],color[3],1); state.painting=nil
                    state.color=color
                end
                -- /fhkswingdebug: print each change of the melee row's state.
                if NS.SwingRowDebug and isMain then
                    local range=NS.GetUnitRange and NS.GetUnitRange('target')
                    local sig=string.format('wanted=%s ready=%s busy=%s rangedBusy=%s reach=%s range=%s fill=%.2f,%.2f,%.2f alpha=%.2f',
                        tostring(wanted),tostring(ready),tostring(busy),tostring(rangedBusy),tostring(MeleeActionable(now)),
                        tostring(range and range.state),color and color[1] or -1,color and color[2] or -1,color and color[3] or -1,row:GetAlpha() or -1)
                    if sig~=state.debugSig then state.debugSig=sig;print(string.format('FHK melee row %.2f: %s',now,sig)) end
                end
                local strip=state.strip
                if dark and accent and fill then
                    if not strip then
                        strip=row._bar:CreateTexture(nil,'OVERLAY',nil,6)
                        strip:SetPoint('BOTTOMLEFT',fill,'BOTTOMLEFT',0,0)
                        strip:SetPoint('BOTTOMRIGHT',fill,'BOTTOMRIGHT',0,0)
                        strip:SetHeight(EUI.PP and EUI.PP.FromPixels and EUI.PP.FromPixels(2) or 2)
                        strip:SetColorTexture(1,1,1,1)
                        state.strip=strip
                    end
                    strip:SetVertexColor(accent[1],accent[2],accent[3],1)
                    strip:Show()
                elseif strip then strip:Hide() end
                local label=isRanged and (cue=='retry' and 'RETRY' or cue=='cast' and 'CAST' or
                    ready and 'AUTO SHOT READY' or 'AUTO SHOT') or
                    isMain and (raptor and ('MELEE - '..raptorName) or both and 'BOTH CD' or ready and 'MELEE READY' or 'MELEE')
                if label and row._tag:GetText()~=label then row._tag:SetText(label) end
                if ready and not state.ready then
                    row._durObj:SetTimeFromStart(now-1,1)
                    row._bar:SetTimerDuration(row._durObj,Enum.StatusBarInterpolation.Immediate,Enum.StatusBarTimerDirection.ElapsedTime)
                    row._bar:SetValue(1)
                end
                state.ready=ready
            end
        end
    end
    if NS.UpdateEllesmereRetryCue then NS.UpdateEllesmereRetryCue(cue=='retry') end
    -- Native fills animate in the engine; this loop updates only readiness and
    -- the short retry/cast state, and stops at the final cooldown edge.
    if rangedBusy or meleeBusy or cue then
        if not driver:GetScript('OnUpdate') then
            local elapsed=0
            driver:SetScript('OnUpdate',function(_,dt)
                elapsed=elapsed+dt
                if elapsed<.05 then return end
                elapsed=0; RefineRows()
            end)
        end
    else driver:SetScript('OnUpdate',nil) end
end
local function InstallOptions()
    local ns,cfg=Config()
    if not ns or not cfg or type(ns.ERB_BuildSwingTimerPage)~='function' or ns.ERB_BuildSwingTimerPage==optionsWrapper then return end
    local original=ns.ERB_BuildSwingTimerPage
    optionsWrapper=function(page,parent,offset)
        local height=original(page,parent,offset)
        local W,y,h=EUI.Widgets,-height
        local _
        _,h=W:SectionHeader(parent,'HUNTER TIMING',y); y=y-h
        _,h=W:DualRow(parent,y,
            {type='dropdown',text='Hunter Layout',values={combined='Both - Combined',separate='Both - Separate'},order={'combined','separate'},
                getValue=function() return cfg.hunterMode or 'combined' end,
                setValue=function(v) cfg.hunterMode=v; ns.ST_Apply() end},
            {type='toggle',text='Show Melee Ready',getValue=function() return cfg.showMeleeReady~=false end,
                setValue=function(v) cfg.showMeleeReady=v; ns.ST_Apply() end}); y=y-h
        _,h=W:DualRow(parent,y,
            {type='toggle',text='Auto Shot Cast / Retry',getValue=function() return cfg.showRetry~=false end,
                setValue=function(v) cfg.showRetry=v; ns.ST_Apply() end},
            {type='label',text='Main / off hand, ranged and Combine Hands: settings above'}); y=y-h
        _,h=W:DualRow(parent,y,
            {type='toggle',text='Active Row Only',
                tooltip='Shows only the row of the attack you are using: no weave READY states, and the other row only while it really cools.',
                getValue=function() return cfg.fhkActiveRowOnly==true end,
                setValue=function(v) cfg.fhkActiveRowOnly=v; ns.ST_Apply() end},
            {type='toggle',text='Auto Shot Latency Zone',
                tooltip='Shades the end of the Auto Shot row by your world latency: moving inside it can still cancel the shot.',
                getValue=function() return cfg.fhkLatencyZone==true end,
                setValue=function(v) cfg.fhkLatencyZone=v; NS.EllesmereSwingLatency(); ns.ST_Apply() end}); y=y-h
        local sparkRow
        sparkRow,h=W:DualRow(parent,y,
            {type='toggle',text='Weapon Spark Colors',
                tooltip='Colors the moving spark per weapon: ranged, main hand and off hand. Off keeps the thin white line.',
                getValue=function() return cfg.fhkSparkColors==true end,
                setValue=function(v) cfg.fhkSparkColors=v; sparkStamp=sparkStamp+1; ns.ST_Apply(); if EUI.RefreshPage then EUI:RefreshPage() end end},
            {type='toggle',text='Auto Shot Clip Marker',
                tooltip='While Aimed Shot or Multi-Shot casts, a tick on the cast bar marks when the next Auto Shot is due. Finishing the cast after it delays that shot.',
                getValue=function() return cfg.fhkClipMarker==true end,
                setValue=function(v) cfg.fhkClipMarker=v; NS.PaintEllesmereClipMarker() end}); y=y-h
        local region=sparkRow and sparkRow._leftRegion
        if region and not EUI._prebuilding and type(EUI.BuildInlineSwatches)=='function' then
            local function Swatch(kind,label)
                return {tooltip=label,
                    disabled=function() return not cfg.fhkSparkColors end,disabledTooltip='Weapon Spark Colors',
                    getValue=function() local c=SparkColour(cfg,kind) or SparkDefaults()[kind]; return c[1],c[2],c[3],1 end,
                    setValue=function(r,g,b)
                        cfg.fhkSpark=type(cfg.fhkSpark)=='table' and cfg.fhkSpark or {}
                        cfg.fhkSpark[kind]={r,g,b}
                        sparkStamp=sparkStamp+1; RefineRows()
                    end}
            end
            pcall(EUI.BuildInlineSwatches,region,{Swatch('ranged','Ranged Spark'),Swatch('main','Main Hand Spark'),Swatch('off','Off Hand Spark')})
        end
        _,h=W:DualRow(parent,y,
            {type='button',text='Cursor Swing Settings',onClick=function()
                if EUI.ShowModule then EUI:ShowModule('EllesmereUIQoL') end
                if EUI.SelectPage then EUI:SelectPage('Cursor') end
            end},
            {type='label',text='Cursor has four modes, radius and readiness toggles'}); y=y-h
        return math.abs(y)
    end
    ns.ERB_BuildSwingTimerPage=optionsWrapper
end
local function Install()
    if installed then return end
    local ns,cfg=Config()
    if not cfg or type(ns.ST_Apply)~='function' or not _G.ERB_SwingTimerFrame or
        not NS.GetCursorSwingClock then return end
    installed=ns
    FHKEllesmereDB=FHKEllesmereDB or {}
    if not FHKEllesmereDB.nativeSwingVersion then
        if not cfg.enabled then
            cfg.enabled=true
            cfg.width,cfg.height,cfg.rowSpacing=260,16,3
            cfg.anchorY=(FHKEllesmereDB.y or -125)-12
            cfg.hideWhenIdle,cfg.showOH,cfg.depleteFill=true,false,false
            cfg.idleShowFill=true
            cfg.visibility='always'
            cfg.textSize,cfg.borderSize,cfg.texture=10,0,'atrocity'
            cfg.bgR,cfg.bgG,cfg.bgB,cfg.bgA=.055,.065,.075,.95
            cfg.showSpark=true
        end
        cfg.classColored=false
        cfg.rR,cfg.rG,cfg.rB,cfg.rA=.183,.615,.483,1 -- jade fill (Colours.shootFill)
        cfg.mhR,cfg.mhG,cfg.mhB,cfg.mhA=.762,.358,.991,1 -- violet fill (Colours.meleeFill)
    end
    if (FHKEllesmereDB.nativeSwingVersion or 0)<2 then
        cfg.hideWhenIdle=true
        cfg.hunterMode='combined'
        FHKEllesmereDB.nativeSwingVersion=2
    end
    NS.EllesmereNativeSwingOwnsBars=true
    -- Legacy bars remain clock providers only, including when native bars are
    -- disabled in options; that toggle must never resurrect the old renderer.
    for _,name in ipairs({'ForeverHunterKeysSwingBar','ForeverHunterKeysMeleeSwingBar'}) do
        local bar=_G[name]
        if bar and NS.FadeEllesmere then NS.FadeEllesmere(bar,false) end
    end
    hooksecurefunc(ns,'ST_Apply',function()
        for _,state in pairs(rows) do state.color,state.sparkHeight,state.zoneSize=nil,nil,nil end
        RefineRows()
    end)
    -- Preserve native layout bounds while smoothing visibility on this shell.
    -- The native helper continues to own every other element.
    if type(EUI.SetElementVisibility)=='function' and NS.FadeEllesmere then
        local original=EUI.SetElementVisibility
        EUI.SetElementVisibility=function(frame,visible,...)
            if frame~=_G.ERB_SwingTimerFrame then return original(frame,visible,...) end
            NS.FadeEllesmere(frame,visible); frame:EnableMouse(false)
        end
    end
    ns.ST_Apply()
    InstallOptions()
end
local resetWorld
local function QueueSync(world)
    resetWorld=resetWorld or world
    if queued then return end
    queued=true
    C_Timer.After(0,function()
        queued=nil
        if resetWorld and _G.ERB_SwingTimerFrame then
            local handler=_G.ERB_SwingTimerFrame:GetScript('OnEvent')
            if handler then handler(_G.ERB_SwingTimerFrame,'PLAYER_DEAD') end
            for _,state in pairs(rows) do state.start,state.duration=nil,nil end
        end
        resetWorld=nil
        RefineRows()
    end)
end
driver:RegisterEvent('ADDON_LOADED'); driver:RegisterEvent('PLAYER_LOGIN')
driver:RegisterEvent('PLAYER_SWING'); driver:RegisterEvent('PLAYER_ENTERING_WORLD')
for _,event in ipairs({'STOP_AUTOREPEAT_SPELL','START_AUTOREPEAT_SPELL','PLAYER_ENTER_COMBAT','PLAYER_LEAVE_COMBAT'}) do driver:RegisterEvent(event) end
-- Raptor Strike queue state changes (one coalesced row pass per frame at most).
driver:RegisterEvent('ACTIONBAR_UPDATE_STATE')
-- Player casts only: any nearby unit's cast used to queue a full row sync.
for _,event in ipairs({'UNIT_SPELLCAST_START','UNIT_SPELLCAST_FAILED_QUIET','UNIT_SPELLCAST_SUCCEEDED','UNIT_SPELLCAST_INTERRUPTED'}) do
    if driver.RegisterUnitEvent then driver:RegisterUnitEvent(event,'player') else driver:RegisterEvent(event) end
end
driver:SetScript('OnEvent',function(_,event)
    if event=='UNIT_SPELLCAST_START' or event=='UNIT_SPELLCAST_INTERRUPTED' or event=='UNIT_SPELLCAST_SUCCEEDED' or event=='UNIT_SPELLCAST_FAILED_QUIET' then
        NS.PaintEllesmereClipMarker()
    end
    if not installed then Install() end
    InstallOptions()
    if installed and event~='ADDON_LOADED' and event~='PLAYER_LOGIN' then QueueSync(event=='PLAYER_ENTERING_WORLD') end
end)
Install()

-- /fhkswingdebug: trace the melee swing row state changes to chat (player report:
-- MELEE READY misbehaving around Auto Shot).
SLASH_FHKSWINGDEBUG1='/fhkswingdebug'
SlashCmdList.FHKSWINGDEBUG=function()
    NS.SwingRowDebug=not NS.SwingRowDebug
    print('FHK swing row trace: '..(NS.SwingRowDebug and 'on' or 'off'))
end
