-- Rank belongs in the native level element, leaving target glow and quest marks alone.
local EUI, NS = _G.EllesmereUI, _G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end
local driver=CreateFrame('Frame')
local installed
-- Gold / silver come from the shared colour tokens (Mob Rarity swatches change them in place).
local C=NS.Colours or {}
local gold,silver=C.rarityElite or {1,215/255,154/255},C.rarityRare or {197/255,204/255,214/255}
local levelColours={elite=gold,worldboss=gold,rare=silver,rareelite=silver}
local function Hex(c) return ('%02x%02x%02x'):format(math.floor(c[1]*255+.5),math.floor(c[2]*255+.5),math.floor(c[3]*255+.5)) end
local colours=setmetatable({},{__index=function(_,k) local c=levelColours[k];return c and Hex(c) or nil end})
local letters={elite='E',rare='R',rareelite='RE',worldboss='B'}
local atlases={elite='nameplates-icon-elite-gold',worldboss='nameplates-icon-elite-gold',
    rareelite='nameplates-icon-elite-silver',rare='nameplates-icon-rareelite'}
local function PaintLevelBox(plate)
    local box=plate and plate._fvLevelBox
    if not box or not box._fs or not plate.unit then return end
    if NS.ApplyEllesmereCueText then NS.ApplyEllesmereCueText(box._fs,'world') end
    local rank=UnitClassification(plate.unit)
    if issecretvalue and issecretvalue(rank) then return end
    local db=FHKEllesmereDB or {}
    local letter=db.rarityMarkers~=false and db.rarityMarkerStyle=='letters' and letters[rank]
    if letter and UnitEffectiveLevel then
        local level=UnitEffectiveLevel(plate.unit)
        if not (issecretvalue and issecretvalue(level)) and type(level)=='number' and level>=0 then
            box._fs:SetText(tostring(level)..letter)
        end
    end
    if db.rarityLevelColours==false then return end
    local colour=levelColours[rank]
    if colour then box._fs:SetTextColor(colour[1],colour[2],colour[3],1) end
end
function NS.PositionEllesmereRarityBadge(plate)
    local icon=plate and plate._euiRarityBadge
    if not icon then return end
    local position=FHKEllesmereDB and FHKEllesmereDB.rarityIconPosition or 'bottomleft'
    local anchor=position=='bottomleft' and plate.cast and plate.cast:IsShown() and plate.cast or plate.health
    -- Forum FR27: a quest mark must never cover the elite/rare mark. When both want the top
    -- right corner, the badge moves just left of the quest mark (its count grows rightward).
    local np=installed
    local slot=np and np.GetClassificationSlot and np.GetClassificationSlot()
    local quest=position=='topright' and slot=='topright' and plate.classFrame and plate.classFrame:IsShown() and
        np.IsQuestMob and np.IsQuestMob(plate.unit) and true or false
    if quest then anchor=plate.classFrame end
    if icon._position==position and icon._anchor==anchor then return end
    icon:ClearAllPoints()
    if quest then icon:SetPoint('RIGHT',plate.classFrame,'LEFT',-3,0)
    elseif position=='bottomleft' then icon:SetPoint('TOPRIGHT',anchor,'BOTTOMLEFT',-5,-3)
    else icon:SetPoint('BOTTOMLEFT',plate.health,'TOPRIGHT',5,3) end
    icon._position,icon._anchor=position,anchor
end
-- Quest count (player report: "0/2" sat on the mob name). Ellesmere centres
-- the count on its small corner icon frame, so a count wider than the icon
-- runs into the centred name. In a top corner slot it moves just outside the
-- bar corner, growing away from the name, and takes the quest colour so it
-- reads as a quest mark, not part of the name. Other slots keep the native
-- placement. Native size is retained; theme outlines follow the shared treatment.
local function PaintQuestCount(plate)
    local text=plate and plate.classText
    if not text or not plate.classFrame then return end
    if NS.ApplyEllesmereCueText then NS.ApplyEllesmereCueText(text,'world') end
    local np=installed
    local slot=np and np.GetClassificationSlot and np.GetClassificationSlot()
    local on=not FHKEllesmereDB or FHKEllesmereDB.rarityQuestCount~=false
    local place=on and (slot=='topleft' and 'left' or slot=='topright' and 'right') or 'native'
    if text._fhkPlace~=place then
        text:ClearAllPoints()
        if place=='left' then
            text:SetPoint('RIGHT',plate.classFrame,'LEFT',-2,0); text:SetJustifyH('RIGHT')
        elseif place=='right' then
            text:SetPoint('LEFT',plate.classFrame,'RIGHT',2,0); text:SetJustifyH('LEFT')
        else
            text:SetPoint('CENTER',plate.classFrame,'CENTER',0,0); text:SetJustifyH('CENTER')
        end
        text._fhkPlace=place
    end
    local c=on and (NS.Colours and NS.Colours.quest or {1,.82,0}) or {1,1,1}
    text:SetTextColor(c[1],c[2],c[3],1)
end
NS.PaintEllesmereQuestCount=PaintQuestCount
local function PaintBadge(plate)
    if plate then PaintQuestCount(plate) end
    if not plate or not plate.health or not plate.unit then return end
    local db=FHKEllesmereDB or {}
    local icon=plate._euiRarityBadge
    local dead=UnitIsDeadOrGhost and UnitIsDeadOrGhost(plate.unit)
    if db.rarityIcons==false or (issecretvalue and issecretvalue(dead)) or dead then
        if icon then icon:Hide() end
        return
    end
    local classification=UnitClassification(plate.unit)
    if issecretvalue and issecretvalue(classification) then if icon then icon:Hide() end; return end
    local atlas=atlases[classification]
    if not atlas then if icon then icon:Hide() end; return end
    -- Keep native classification art when its slot is not occupied by a quest
    -- mark. The Forever variant suppresses that art, so it needs this badge.
    local np=installed
    if np and not np._npForever and plate.classFrame and plate.classFrame:IsShown()
        and not (np.IsQuestMob and np.IsQuestMob(plate.unit)) then
        if icon then icon:Hide() end
        return
    end
    if not icon then
        local holder=CreateFrame('Frame',nil,plate.health)
        holder:SetAllPoints(plate.health)
        holder:SetFrameLevel(plate.health:GetFrameLevel()+3)
        icon=holder:CreateTexture(nil,'OVERLAY')
        plate._euiRarityBadge=icon
    end
    local size=db.rarityIconSize or 16
    if icon._size~=size then icon:SetSize(size,size); icon._size=size end
    if icon._atlas~=atlas then icon:SetAtlas(atlas); icon._atlas=atlas end
    NS.PositionEllesmereRarityBadge(plate)
    icon:Show()
end
local function Attach(plate)
    if not plate or not plate.health then return end
    if not plate._euiRarityHooked then
        plate._euiRarityHooked=true
        for _,method in ipairs({'SetUnit','UpdateClassification','ApplyAppearance'}) do
            if type(plate[method])=='function' then hooksecurefunc(plate,method,PaintBadge) end
        end
    end
    PaintBadge(plate)
end
function NS.RefreshEllesmereRarity()
    local np=_G.EllesmereNameplates_NS
    for _,plate in pairs(np and np.plates or {}) do Attach(plate) end
end
local function Install()
    local ns=_G.EllesmereNameplates_NS
    if installed==ns or not ns or type(ns.GetUnitLevelText)~='function' or type(UnitClassification)~='function' then return end
    installed=ns
    local original=ns.GetUnitLevelText
    ns.GetUnitLevelText=function(unit,plain,...)
        local text=original(unit,plain,...)
        local classification=UnitClassification(unit)
        if issecretvalue and (issecretvalue(classification) or issecretvalue(text)) then return text end
        if type(text)~='string' then return text end
        local db=FHKEllesmereDB or {}
        if not plain and db.raritySkulls~=false and UnitEffectiveLevel then
            local level=UnitEffectiveLevel(unit)
            if not (issecretvalue and issecretvalue(level)) and type(level)=='number' and level<0 and CreateAtlasMarkup then
                return CreateAtlasMarkup('ui-hud-nameplates-levelindicator-skull',12,12)
            end
        end
        local colour=colours[classification]
        if not colour then return text end
        local suffix=''
        if db.rarityMarkers~=false then
            if db.rarityMarkerStyle=='letters' then suffix=letters[classification] or ''
            elseif classification=='elite' then suffix='+'
            elseif classification=='worldboss' then suffix='++'
            elseif classification=='rare' or classification=='rareelite' then
                local mark=db.rarityIcons~=false and '' or
                    (CreateAtlasMarkup and CreateAtlasMarkup('nameplates-icon-rareelite',10,10) or '*')
                suffix=(classification=='rareelite' and '+' or '') .. mark
            end
        end
        -- The native plain contract is used by stock level art. Normal mobs and
        -- the optional difficulty palette keep their original renderer colours.
        if not plain and db.rarityLevelColours~=false then
            return '|cff' .. colour .. text:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','') .. suffix .. '|r'
        end
        if text:sub(-2)=='|r' then return text:sub(1,-3) .. suffix .. '|r' end
        return text .. suffix
    end
    if type(ns.NP_UpdateForeverLevel)=='function' then hooksecurefunc(ns,'NP_UpdateForeverLevel',PaintLevelBox) end
    if ns.RefreshAllSettings then hooksecurefunc(ns,'RefreshAllSettings',NS.RefreshEllesmereRarity); ns.RefreshAllSettings() end
    NS.RefreshEllesmereRarity()
end
driver:RegisterEvent('ADDON_LOADED'); driver:RegisterEvent('PLAYER_LOGIN')
driver:RegisterEvent('NAME_PLATE_UNIT_ADDED'); driver:RegisterEvent('UNIT_CLASSIFICATION_CHANGED')
driver:RegisterEvent('UNIT_FLAGS'); driver:RegisterEvent('UNIT_HEALTH')
driver:SetScript('OnEvent',function(_,event,unit)
    if event=='ADDON_LOADED' or event=='PLAYER_LOGIN' then Install(); NS.RefreshEllesmereRarity()
    elseif event=='NAME_PLATE_UNIT_ADDED' then
        C_Timer.After(0,function()
            local np=_G.EllesmereNameplates_NS
            Attach(np and np.plates and np.plates[unit])
        end)
    else
        local np=_G.EllesmereNameplates_NS
        local plate=np and np.plates and np.plates[unit]
        if plate and event=='UNIT_HEALTH' then
            -- Health traffic only hides a badge on death; rank artwork is static
            -- and is refreshed by classification/flags/settings events instead.
            local icon=plate._euiRarityBadge
            if icon and icon:IsShown() and UnitIsDeadOrGhost then
                local dead=UnitIsDeadOrGhost(unit)
                if not (issecretvalue and issecretvalue(dead)) and dead then icon:Hide() end
            end
        elseif plate then PaintBadge(plate) end
    end
end)
Install()
