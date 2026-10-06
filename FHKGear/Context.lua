-- FHK Gear: cached learned-spell context and explicit levelling assumptions.
-- CC BY-NC-SA 4.0. See LICENSE.md.
if EUI_CLIENT_BLOCKED then return end
local _,ns=...
local S,C=ns.Safe,{}
ns.Context=C
-- Source: ForeverDB spell pages, 2026-10-04. Facts, not complete rotations.
C.Abilities={
    [19434]={class='HUNTER',name='Aimed Shot',slot=18,weapon=1,source='https://foreverdb.net/spell/19434'},
    [53]={class='ROGUE',name='Backstab',slot=16,weapon=1.5,dagger=true,source='https://foreverdb.net/spell/53'},
    [116]={class='MAGE',name='Frostbolt',school='FrostDamage',coefficients={0.407,0.489,0.597,0.706,0.814,0.814,0.814,0.814,0.814,0.814,0.814},source='https://foreverdb.net/spell/116'},
}
local snapshot
function C.Invalidate() snapshot=nil end
function C.Get()
    if snapshot then return snapshot end
    local _,class=S.Read(UnitClass,'player')
    local out={class=class,learned={},talents={},complete=false}
    local companion=rawget(_G,'FHKEllesmereNS')
    local talents=S.Table(companion) and companion.HunterTalents
    if class=='HUNTER' and S.Table(talents) then
        for key,id in pairs(talents.list or {}) do
            local rank=S.Read(talents.Rank,key)
            out.talents[key]={id=id,rank=S.Number(rank) and rank or nil,method=S.Read(talents.Method,key)}
        end
    end
    local bank=Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    local api=C_SpellBook
    local n=S.Read(api and api.GetNumSpellBookSkillLines)
    if bank~=nil and S.Number(n) and n>=0 and n<=100 then
        local byName,total={},0
        out.complete=true
        for line=1,n do
            local info=S.Read(api.GetSpellBookSkillLineInfo,line)
            if not S.Table(info) or not S.Number(info.numSpellBookItems) or not S.Number(info.itemIndexOffset) then out.complete=false;break end
            total=total+info.numSpellBookItems
            if total>1024 then out.complete=false;break end
            for index=info.itemIndexOffset+1,info.itemIndexOffset+info.numSpellBookItems do
                local spell=S.Read(api.GetSpellBookItemInfo,index,bank)
                if S.Table(spell) and S.Text(spell.name) and spell.isOffSpec~=true and spell.isPassive~=true then
                    local rank=S.Text(spell.subName) and tonumber(spell.subName:match('(%d+)')) or nil
                    local old=byName[spell.name]
                    if not old or (rank or 0)>(old.rank or 0) then byName[spell.name]={id=spell.spellID or spell.actionID,rank=rank} end
                end
            end
        end
        for id,ability in pairs(C.Abilities) do
            if ability.class==class then
                local spell=S.Read(C_Spell and C_Spell.GetSpellInfo,id)
                local name=S.Table(spell) and S.Text(spell.name) and spell.name or ability.name
                out.learned[id]=byName[name]
            end
        end
    end
    snapshot=out;return out
end
function C.Description()
    local context=C.Get();local n=0;for _ in pairs(context.learned) do n=n+1 end
    local known,unknown=0,0
    for _,talent in pairs(context.talents) do if talent.rank~=nil then known=known+1 else unknown=unknown+1 end end
    return ('Ability context: %d supported learned spells; %s. Talent reads %d known, %d unknown. Modifier coverage is incomplete.'):format(n,context.complete and 'spellbook read' or 'client spellbook unconfirmed',known,unknown)
end
function C.WeaponValue(info,slot,w)
    if ns.Char().comparisonModel~='rotation' then return 0,true end
    local c,context=ns.Char(),C.Get()
    local seconds=S.Number(c.fightLength) and math.max(1,c.fightLength) or 15
    -- The registry does not yet contain every talent/AP normalisation modifier.
    local score,known=0,false
    for id,count in pairs(c.rotation) do
        local a=C.Abilities[tonumber(id)]
        if S.Number(count) and count>0 then
            local learned=a and context.learned[tonumber(id)]
            if not learned then known=false
            elseif a.slot==slot then
                -- No dagger: the ability adds nothing (review GC8). nil here made every comparison unavailable.
                if a.dagger and info.subclassID~=15 then return 0,false end
                local damage=info.stats.Damage
                if not S.Number(damage) then known=false
                else score=score+damage*a.weapon*count/seconds*(w.DirectDPS or w.RangedDPS or w.MeleeDPS or w.DPS or 1) end
            end
        end
    end
    return score,known
end
function C.SchoolWeight(stat,w)
    if ns.Char().comparisonModel~='rotation' then return w[stat] end
    local c,context=ns.Char(),C.Get()
    local total,school=0,0
    for id,count in pairs(c.rotation) do
        local a,learned=C.Abilities[tonumber(id)],context.learned[tonumber(id)]
        if a and learned and a.coefficients and S.Number(count) and count>0 then
            local coefficient=a.coefficients[learned.rank or 0]
            if coefficient then total=total+coefficient*count;if a.school==stat then school=school+coefficient*count end end
        end
    end
    if total==0 then return w[stat] end
    return (w.SpellDamage or w.SpellPower or 0)*school/total
end
