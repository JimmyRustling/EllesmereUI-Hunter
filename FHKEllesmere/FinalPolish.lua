-- Apply the player's reviewed Hunter choices once; later edits stay authoritative.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end
local function Copy(v)
    if type(v)~='table' then return v end
    local t={};for k,x in pairs(v) do t[k]=Copy(x) end;return t
end
local function Hunter()
    local _,class=UnitClass('player')
    return not (issecretvalue and issecretvalue(class)) and class=='HUNTER'
end
local function ProfileName() return EllesmereUIDB and EllesmereUIDB.activeProfile or 'Default' end
-- Casting is rose (2026-10-03): mana blue sat 8 units from the mana bar, so a
-- CAST state read as mana. Only our own earlier blue is migrated.
local CAST_HEX,OLD_CAST_HEX='FF6FB1','3FA7FF'
local function Cast() return _G._ECL_AceDB and _G._ECL_AceDB.profile and _G._ECL_AceDB.profile.castCircle end
local function Refresh()
    for _,name in ipairs({'SyncEllesmereWarnings','SyncEllesmereUnitRefinements','ApplyEllesmereIndicators'}) do
        if type(NS[name])=='function' then NS[name]() end
    end
    if type(_G._ECL_ApplyCastCircle)=='function' then _G._ECL_ApplyCastCircle() end
    if EUI.RefreshPage then EUI:RefreshPage() end
end
function NS.SyncEllesmereReviewedProfile()
    local db=FHKEllesmereDB
    local before=db and db.reviewedProfileBefore
    local c=Cast()
    if not before or before.name~=ProfileName() or type(c)~='table' then return end
    if before.castApplied then
        if c.hex==OLD_CAST_HEX and c.useClassColor==false and c.useAccentColor==false then
            c.hex=CAST_HEX
            if type(_G._ECL_ApplyCastCircle)=='function' then _G._ECL_ApplyCastCircle() end
        end
        return
    end
    before.cast={hex=c.hex,useClassColor=c.useClassColor,useAccentColor=c.useAccentColor}
    before.castApplied=true
    c.hex,c.useClassColor,c.useAccentColor=CAST_HEX,false,false
    if type(_G._ECL_ApplyCastCircle)=='function' then _G._ECL_ApplyCastCircle() end
end
function NS.ApplyEllesmereReviewedProfile()
    if not Hunter() or not NS.EllesmereWarningSettings or not NS.EllesmerePetMoodSettings or
        not NS.EllesmereIndicatorSettings then return false end
    if type(FHKEllesmereDB)~='table' then FHKEllesmereDB={} end
    local db=FHKEllesmereDB
    local warnings,mood,range=NS.EllesmereWarningSettings(),NS.EllesmerePetMoodSettings(),NS.EllesmereIndicatorSettings('range')
    if not db.reviewedProfileBefore or db.reviewedProfileBefore.name~=ProfileName() then
        db.reviewedProfileBefore={name=ProfileName(),warnings=Copy(warnings),moodAlways=mood.always,
            castFailureWarning=range.castFailureWarning}
    end
    warnings.aspects,warnings.petHealth,warnings.petRange,warnings.petStatus=true,true,true,true
    -- Happiness is the paw icon now; the strip is not forced (player decision).
    range.castFailureWarning=true
    db.reviewedProfileApplied=true
    NS.SyncEllesmereReviewedProfile()
    local c=Cast()
    if type(c)=='table' then c.hex,c.useClassColor,c.useAccentColor=CAST_HEX,false,false end
    Refresh()
    return true
end
function NS.RestoreEllesmereReviewedProfile()
    local db=FHKEllesmereDB
    local before=db and db.reviewedProfileBefore
    if not before or before.name~=ProfileName() then return false end
    local warnings=NS.EllesmereWarningSettings()
    for _,key in ipairs({'aspects','petHealth','petRange','petStatus'}) do warnings[key]=before.warnings[key] end
    NS.EllesmerePetMoodSettings().always=before.moodAlways
    NS.EllesmereIndicatorSettings('range').castFailureWarning=before.castFailureWarning
    local c=Cast()
    if before.castApplied and type(c)=='table' then
        for _,key in ipairs({'hex','useClassColor','useAccentColor'}) do c[key]=before.cast[key] end
    end
    db.reviewedProfileBefore=nil
    -- Restoring is a choice too; loading the UI must not apply the preset again.
    db.reviewedProfileApplied=true
    Refresh();return true
end
function NS.AddEllesmereReviewedProfileOptions(Row)
    Row({type='button',text='Apply Reviewed Hunter Cues',tooltip='Enable conditional pet/aspect warnings and cast-failure text, and use rose for your casts.',
        onClick=function() NS.ApplyEllesmereReviewedProfile() end,
        disabled=function() return not Hunter() end,disabledTooltip='Hunter profile cues'},
        {type='button',text='Restore Previous Hunter Cues',tooltip='Restores the choices saved before this adjustment for the active profile.',
        onClick=function() NS.RestoreEllesmereReviewedProfile() end,
        disabled=function()
            local before=FHKEllesmereDB and FHKEllesmereDB.reviewedProfileBefore
            return not before or before.name~=ProfileName()
        end,disabledTooltip='No previous choices saved for this profile'})
end
local loggedIn=false
local boot=CreateFrame('Frame')
boot:RegisterEvent('PLAYER_LOGIN');boot:RegisterEvent('ADDON_LOADED')
boot:SetScript('OnEvent',function(_,event)
    if event=='PLAYER_LOGIN' then loggedIn=true end
    if not loggedIn or not Hunter() then return end
    if not (FHKEllesmereDB and FHKEllesmereDB.reviewedProfileApplied) then
        if (_G.ForeverHunterKeysNS~=nil) then NS.ApplyEllesmereReviewedProfile() end
    else NS.SyncEllesmereReviewedProfile() end
end)
