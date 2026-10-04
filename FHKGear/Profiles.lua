-- FHK Gear: versioned bridge through the owned companion profile store.
-- CC BY-NC-SA 4.0. See LICENSE.md. Ownership and restore snapshots never transfer.
if EUI_CLIENT_BLOCKED then return end
local _,ns=...
local S=ns.Safe
local applying=false
local CHOICES={source={auto=true,weights=true,forevergear=true},phase={auto=true,levelling=true,endgame=true},
    ratingUnits={unknown=true,percent=true,rating=true},comparisonModel={weights=true,rotation=true},
    weaponStyle={preset=true,any=true,['2h']=true,['dual wield']=true,['weapon and shield']=true,['dagger and any']=true},
    objective={damage=true},markerStyle={border=true,arrow=true,diamond=true,plus=true},greedMarkerStyle={border=true,coin=true,diamond=true,plus=true},
    markerPosition={TOPLEFT=true,TOPRIGHT=true,BOTTOMLEFT=true,BOTTOMRIGHT=true,CENTER=true},
    hunterPet={auto=true,pet=true,none=true}}
local LIMITS={autoEquipMaxQuality={0,5},phaseLevel={10,60},fightLength={1,600},meleeShare={0,1},incomingHits={0,10},useUptime={0,1},markerSize={8,48},markerOpacity={0.1,1},markerOffsetX={-32,32},markerOffsetY={-32,32},multiTargets={1,10},popDuration={3,30}}
function ns.ParseProcRate(text)
    if not S.Text(text) or #text>512 then return nil,'Enter an item ID and a proc rate.' end
    local id,body=text:match('^%s*(%d+)%s*,%s*(.+)$')
    id=tonumber(id)
    if not S.Number(id) or id<1 or id>1000000000 then return nil,'Enter a valid item ID.' end
    if body:match(',%s*,') or body:match(',%s*$') then return nil,'Remove empty proc rate entries.' end
    local out={}
    for entry in (body or ''):gmatch('[^,]+') do
        local key,number=entry:match('^%s*(%a+)%s*=%s*(%S+)%s*$')
        local value=tonumber(number)
        local maximum=key=='ppm' and 60 or key=='chance' and 100 or key=='icd' and 600
        if not maximum or out[key]~=nil or not S.Number(value) or value<0 or value>maximum then return nil,'Invalid proc rate entry: ' .. entry end
        out[key]=value
    end
    if (out.ppm==nil)==(out.chance==nil) then return nil,'Enter either ppm or chance, plus an optional icd.' end
    return id,out
end
function ns.ExportProfile(includeWeights,includeRules)
    local c,out=ns.Char(),{version=1,settings={}}
    for key in pairs(ns.CHAR_DEFAULTS) do out.settings[key]=S.Copy(c[key]) end
    out.settings.spec=S.Text(c.spec) and c.spec or nil
    for _,key in ipairs({'rotation','procRates','ratingConversions','markerColours','hunterTalents'}) do out.settings[key]=S.Copy(c[key]) end
    if includeRules then out.rules={locked=S.Copy(c.locked),ignore=S.Copy(c.ignore),ignoreLinks=S.Copy(c.ignoreLinks)} end
    if includeWeights then out.weights=S.Copy(ns.Account().weights);out.imported=S.Copy(ns.Account().imported) end
    return out
end
local function Map(value,check)
    if not S.Table(value) then return false end
    local count=0
    for key,entry in pairs(value) do
        count=count+1
        if count>2048 or not check(key,entry) then return false end
    end
    return true
end
local function PositiveID(key) return S.Number(key) and key>=1 and key<=1000000000 and key==math.floor(key) end
local function Finite(value,minimum,maximum) return S.Number(value) and value>=minimum and value<=maximum end
local function NestedSetting(key,value)
    if key=='rotation' then return Map(value,function(id,n) return PositiveID(id) and Finite(n,0,1000) end) end
    if key=='hunterTalents' then
        local talents=ns.HunterData and ns.HunterData.talents or {}
        return Map(value,function(name,n) return S.Text(name) and talents[name] and Finite(n,0,talents[name].max) and n==math.floor(n) end)
    end
    if key=='ratingConversions' then
        local supported={Crit=true,Hit=true,SpellCrit=true,SpellHit=true,Haste=true,Dodge=true,Parry=true,Block=true}
        return Map(value,function(stat,n) return S.Text(stat) and supported[stat] and Finite(n,0.000001,100000) end)
    end
    if key=='markerColours' then
        return Map(value,function(name,colour)
            return S.Text(name) and (name=='upgrade' or name=='greed') and Map(colour,function(index,n)
                return S.Number(index) and index==math.floor(index) and index>=1 and index<=3 and Finite(n,0,1)
            end) and S.Number(colour[1]) and S.Number(colour[2]) and S.Number(colour[3])
        end)
    end
    return Map(value,function(id,rate)
        return PositiveID(id) and Map(rate,function(field,n)
            return S.Text(field) and ((field=='ppm' and Finite(n,0,60)) or (field=='chance' and Finite(n,0,100)) or (field=='icd' and Finite(n,0,600)))
        end) and ((rate.ppm~=nil)~=(rate.chance~=nil))
    end)
end
local function WeightLibrary(value)
    local stats={};for _,stat in ipairs(ns.Weights.STATS) do stats[stat]=true end
    return Map(value,function(name,scale)
        return S.Text(name) and #name<=100 and Map(scale,function(stat,n)
            return S.Text(stat) and (stats[stat] and Finite(n,0,100000) or stat=='weapons' and S.Text(n) and CHOICES.weaponStyle[n])
        end)
    end)
end
function ns.ValidateProfile(payload)
    if not S.Table(payload) or not S.Number(payload.version) or payload.version~=1 or not S.Table(payload.settings) then return nil,'Unsupported Gear profile' end
    local out={version=1,settings={}}
    for key,default in pairs(ns.CHAR_DEFAULTS) do
        local value=payload.settings[key]
        if value~=nil then
            if type(default)=='boolean' and S.Plain(value) and type(value)=='boolean' then out.settings[key]=value
            elseif LIMITS[key] and S.Number(value) and value>=LIMITS[key][1] and value<=LIMITS[key][2] then out.settings[key]=value
            elseif CHOICES[key] and S.Text(value) and CHOICES[key][value] then out.settings[key]=value
            elseif key=='targetType' and S.Text(value) and #value<=40 then out.settings[key]=value
            else return nil,'Invalid Gear profile setting: ' .. key end
        end
    end
    if payload.settings.spec~=nil and (not S.Text(payload.settings.spec) or #payload.settings.spec>64) then return nil,'Invalid Gear profile spec' end
    out.settings.spec=payload.settings.spec
    for _,key in ipairs({'rotation','procRates','ratingConversions','markerColours','hunterTalents'}) do
        if payload.settings[key]~=nil then
            if not NestedSetting(key,payload.settings[key]) then return nil,'Invalid Gear profile table: ' .. key end
            out.settings[key]=S.Copy(payload.settings[key])
        end
    end
    if payload.rules~=nil then
        local valid=Map(payload.rules,function(key,value)
            if key=='locked' then return Map(value,function(slot,on) return PositiveID(slot) and slot<=24 and S.Plain(on) and type(on)=='boolean' end) end
            if key=='ignore' then return Map(value,function(id,on) return PositiveID(id) and S.Plain(on) and type(on)=='boolean' end) end
            if key=='ignoreLinks' then return Map(value,function(link,on) return S.Text(link) and #link<=512 and link:find('item:%d+') and S.Plain(on) and type(on)=='boolean' end) end
            return false
        end)
        if not valid then return nil,'Invalid Gear profile equipment rules' end
        out.rules=S.Copy(payload.rules)
    end
    for _,key in ipairs({'weights','imported'}) do
        if payload[key]~=nil then
            if not WeightLibrary(payload[key]) then return nil,'Invalid Gear profile weight library' end
            out[key]=S.Copy(payload[key])
        end
    end
    return out
end
function ns.ApplyProfile(payload)
    local value,why=ns.ValidateProfile(payload);if not value then S.Note('profile',why);return false end
    applying=true
    local c=ns.Char()
    c.spec=value.settings.spec
    for key,v in pairs(value.settings) do c[key]=v end
    if value.rules then for _,key in ipairs({'locked','ignore','ignoreLinks'}) do c[key]=value.rules[key] or {} end end
    if value.weights then ns.Account().weights=value.weights end
    if value.imported then ns.Account().imported=value.imported end
    local ok=S.Call('apply Gear profile',ns.Changed,'items');applying=false;return ok
end
function ns.StoreProfile()
    if applying then return end
    local companion=rawget(_G,'FHKEllesmereNS')
    if not S.Table(companion) or type(companion.EllesmereProfileStore)~='function' or not S.Table(FHKEllesmereDB) then return end
    local c=ns.Char()
    FHKEllesmereDB.fhkGearSettings=ns.ExportProfile(c.profileIncludeWeights,c.profileIncludeRules)
end
function ns.InstallProfileBridge()
    local companion=rawget(_G,'FHKEllesmereNS')
    if not S.Table(companion) or type(companion.EllesmereProfileStore)~='function' or not S.Table(FHKEllesmereDB) then return false end
    if companion.SyncEllesmereGearProfile then return true end
    local talents=companion.HunterTalents
    if S.Table(talents) and type(talents.OnChange)=='function' then
        S.Call('talent context callback',talents.OnChange,function()
            ns.Context.Invalidate();ns.Weights.Invalidate();ns.Engine.Invalidate()
            if ns.InvalidateOptions then ns.InvalidateOptions() end
        end)
    end
    companion.SyncEllesmereGearProfile=function()
        local payload=FHKEllesmereDB.fhkGearSettings
        if payload then ns.ApplyProfile(payload) else ns.StoreProfile() end
    end
    companion.SyncEllesmereGearProfile();return true
end
