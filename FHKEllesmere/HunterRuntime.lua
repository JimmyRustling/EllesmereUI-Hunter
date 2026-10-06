-- Standalone Forever weapon clocks. FHK, when installed, owns the same public API.
if EUI_CLIENT_BLOCKED then return end
local _, NS = ...
NS = _G.FHKEllesmereNS or NS
if NS.GetCursorSwingClock or select(2, UnitClass('player')) ~= 'HUNTER' then return end
local driver = CreateFrame('Frame')
local clocks, ends, bars = {}, {}, {}
local autoRepeat, castEnd, retryEnd, castDuration = false, nil, nil, .52
local types = Enum and Enum.PlayerSwingType or {}
local kinds = {[types.MainHand or 0]='main',[types.OffHand or 1]='off',[types.Ranged or 2]='ranged'}
local function Number(v)
    return not (issecretvalue and issecretvalue(v)) and type(v) == 'number' and v == v and v > 0 and v < math.huge
end
function NS.GetCursorSwingClock(kind)
    local c = clocks[kind]
    if c then return c.start, c.duration, c.finish end
end
function NS.GetAutoShotCue()
    local now=GetTime()
    if castEnd and castEnd>now then return 'cast',castEnd-castDuration,castDuration,castEnd end
    if retryEnd and retryEnd>now and math.max(ends.main or 0,ends.off or 0,ends.ranged or 0)<=now then
        return 'retry',retryEnd-.5,.5,retryEnd
    end
end
local function SetClock(kind, now, duration)
    clocks[kind] = {start=now,duration=duration,finish=now+duration}
end
local function CreateBar(kind)
    local bar = CreateFrame('Frame', nil, UIParent)
    bar.StatusBar = CreateFrame('StatusBar', nil, bar)
    local status = bar.StatusBar
    status:SetMinMaxValues(0,1)
    status.fill = status:CreateTexture(nil,'ARTWORK')
    status.Pip = status:CreateTexture(nil,'OVERLAY'); status.Pip:SetPoint('RIGHT',status.fill,'RIGHT')
    status.TypeLabel = status:CreateFontString(nil,'OVERLAY')
    status.TypeLabel:SetPoint('LEFT',status,'LEFT',7,0)
    status.TimeLabel = status:CreateFontString(nil,'OVERLAY')
    status.TimeLabel:SetPoint('RIGHT',status,'RIGHT',-7,0)
    bar.Background = bar:CreateTexture(nil,'BACKGROUND'); bar.Background:SetAllPoints(bar)
    bar.Border = bar:CreateTexture(nil,'BACKGROUND'); bar.Border:SetAllPoints(bar)
    NS.StyleEllesmereSwingBar(bar, kind)
    bars[kind] = bar
    return bar
end
local elapsed, idleSince, meleeOn = 0, nil, false
local KINDS = {'ranged','melee'}
-- The ticker runs only while a clock, cue or attack is live, then sleeps (review: it ran at 20 Hz
-- forever on a standalone install). Every event below wakes it.
local function Live(now)
    return next(clocks) ~= nil or autoRepeat or meleeOn or (castEnd and castEnd > now) or (retryEnd and retryEnd > now)
end
local Tick
local function Wake() idleSince = nil; if driver:GetScript('OnUpdate') ~= Tick then driver:SetScript('OnUpdate', Tick) end end
Tick = function(_, dt)
    if not NS.StyleEllesmereSwingBar or not NS.EllesmereSwingAnchor then return end
    elapsed = elapsed + dt; if elapsed < .05 then return end; elapsed=0
    local now = GetTime()
    for _, kind in ipairs(KINDS) do
        local c = clocks[kind]
        if c and not NS.EllesmereNativeSwingOwnsBars then
            local bar = bars[kind] or CreateBar(kind)
            local left = math.max(0,c.finish-now)
            bar.StatusBar:SetValue(math.min(1,math.max(0,1-left/c.duration)))
            local color = NS.EllesmereSwingColors and NS.EllesmereSwingColors[kind] or {1,1,1}
            bar.StatusBar:SetStatusBarColor(unpack(color))
            bar.StatusBar.TypeLabel:SetText(kind == 'melee' and (left>0 and 'MELEE' or 'MELEE READY') or 'AUTO SHOT')
            bar.StatusBar.TimeLabel:SetText(string.format('%.1f',left))
            NS.FadeEllesmere(bar, left>0)
            if left == 0 then clocks[kind] = nil end
        end
    end
    if NS.UpdateEllesmereAttackCues then
        -- C_Spell first; auto attack also follows PLAYER_ENTER/LEAVE_COMBAT (API audit 2026-10-06).
        local current = C_Spell and C_Spell.IsCurrentSpell or IsCurrentSpell
        local function Current(id) if type(current) ~= 'function' then return nil end local ok, v = pcall(current, id); return ok and v == true end
        local auto = autoRepeat or Current(75)
        local melee = meleeOn or Current(6603)
        NS.UpdateEllesmereAttackCues(auto == true, melee == true, now)
    end
    -- One second idle (fades and the last cue update finish), then sleep.
    if Live(now) then idleSince = nil
    elseif not idleSince then idleSince = now
    elseif now - idleSince > 1 then idleSince = nil; driver:SetScript('OnUpdate', nil) end
end
Wake()
driver:RegisterEvent('PLAYER_SWING'); driver:RegisterEvent('PLAYER_ENTERING_WORLD')
-- Auto attack on and off (melee has no autorepeat events).
driver:RegisterEvent('PLAYER_ENTER_COMBAT'); driver:RegisterEvent('PLAYER_LEAVE_COMBAT')
driver:RegisterEvent('START_AUTOREPEAT_SPELL'); driver:RegisterEvent('STOP_AUTOREPEAT_SPELL')
-- Player casts only: the client drops every other unit's casts before Lua runs.
for _,event in ipairs({'UNIT_SPELLCAST_START','UNIT_SPELLCAST_SUCCEEDED','UNIT_SPELLCAST_FAILED_QUIET','UNIT_SPELLCAST_INTERRUPTED'}) do
    if driver.RegisterUnitEvent then driver:RegisterUnitEvent(event,'player') else driver:RegisterEvent(event) end
end
driver:SetScript('OnEvent', function(_, event, duration, swingType, spellID)
    Wake()
    if event == 'PLAYER_ENTER_COMBAT' then meleeOn = true; return end
    if event == 'PLAYER_LEAVE_COMBAT' then meleeOn = false; return end
    if event == 'PLAYER_ENTERING_WORLD' then
        meleeOn = false
        clocks, ends = {}, {}
        autoRepeat,castEnd,retryEnd=false,nil,nil
        if NS.WeaveTiming then NS.WeaveTiming.ResetClock() end
        for _, bar in pairs(bars) do
            if NS.FadeEllesmere then NS.FadeEllesmere(bar,false) else bar:Hide() end
        end
        return
    end
    if event=='START_AUTOREPEAT_SPELL' then autoRepeat=true; return end
    if event=='STOP_AUTOREPEAT_SPELL' then autoRepeat,castEnd,retryEnd=false,nil,nil; return end
    if event:find('UNIT_SPELLCAST_',1,true) then
        if duration~='player' or (issecretvalue and issecretvalue(spellID)) or spellID~=75 then return end
        local now=GetTime()
        if NS.AutoCueDebug and not InCombatLockdown() then
            print('FHK auto cue: '..event..' for Auto Shot out of combat (autoRepeat='..tostring(autoRepeat)..')')
        end
        if event=='UNIT_SPELLCAST_START' then
            castDuration=.52
            if UnitCastingInfo then
                local _,_,_,startMS,endMS=UnitCastingInfo('player')
                if Number(startMS) and Number(endMS) and endMS>startMS then castDuration=(endMS-startMS)/1000 end
            end
            castEnd,retryEnd=now+castDuration,nil
        elseif event=='UNIT_SPELLCAST_FAILED_QUIET' and autoRepeat and
            math.max(ends.main or 0,ends.off or 0,ends.ranged or 0)<=now then retryEnd,castEnd=now+.5,nil
        elseif event=='UNIT_SPELLCAST_INTERRUPTED' then castEnd=nil
        elseif event=='UNIT_SPELLCAST_SUCCEEDED' then castEnd,retryEnd=nil,nil end
        return
    end
    local kind = not (issecretvalue and issecretvalue(swingType)) and kinds[swingType]
    if not kind or not Number(duration) then return end
    local now = GetTime(); ends[kind] = now+duration
    if NS.AutoCueDebug and not InCombatLockdown() then
        print(string.format('FHK auto cue: PLAYER_SWING %s %.2fs out of combat',kind,duration))
    end
    if kind == 'ranged' then
        SetClock('ranged',now,duration)
        if NS.WeaveTiming then NS.WeaveTiming.RangedSwing() end
    else
        if NS.WeaveTiming then NS.WeaveTiming.MeleeSwing(now,duration) end
        local finish = math.max(ends.main or 0,ends.off or 0)
        -- A later hand extends the clock from its own start (review C10): no jump back to 0 %.
        local c = clocks.melee
        if not c or c.finish <= now then SetClock('melee',now,finish-now)
        elseif finish > c.finish then c.duration, c.finish = finish-c.start, finish end
        local cfg = FHKEllesmereDB and FHKEllesmereDB.swingCursor or {}
        local reset=NS.WeaveTiming and NS.WeaveTiming.RangedResetsOnMelee() or not NS.WeaveTiming and cfg.resetOnMelee~=false
        if reset then
            local speed = UnitRangedDamage and UnitRangedDamage('player')
            if not Number(speed) then speed = clocks.ranged and clocks.ranged.duration end
            if Number(speed) then SetClock('ranged',now,speed) end
        end
    end
    castEnd,retryEnd=nil,nil
end)
