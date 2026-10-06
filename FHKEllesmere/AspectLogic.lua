-- Aspect advice rules. No client calls or rendering.
local EUI,NS=_G.EllesmereUI,_G.FHKEllesmereNS
if EUI_CLIENT_BLOCKED or not EUI or not NS then return end
local L={}
NS.AspectLogic=L
L.ORDER={'hawk','monkey','cheetah','pack','beast','wild'}
L.SPELLS={hawk=13165,monkey=13163,cheetah=5118,pack=13159,beast=13161,wild=20043}
local shoot={shoot=true,distance=true}
local near={shoot=true,distance=true,melee=true}
local function CombatAspect(i)
    local known=i.known or {}
    if i.style=='melee' and known.beast then return 'beast' end
    if known.hawk then return 'hawk' end
    if known.monkey then return 'monkey' end
end
function L.Decide(i)
    if i.unknown or i.dead or i.mounted then return nil end
    local k,active,range=i.known or {},i.active,i.range
    if not active and next(k)==nil then return nil end
    local travel=active=='cheetah' or active=='pack'
    if i.combat then
        if travel or not active then
            local want
            if range=='melee' and i.style~='weave' then
                if i.style=='melee' and k.beast then want='beast'
                elseif i.onYou and i.monkey and k.monkey then want='monkey' end
            end
            return want or CombatAspect(i),'danger'
        end
        if not i.hostile then return nil end
        if shoot[range] and active~='hawk' and k.hawk then return 'hawk','action' end
        if range=='melee' then
            if i.style=='weave' then return nil end
            if i.style=='melee' then
                if k.beast and active~='beast' then return 'beast','action' end
            elseif i.onYou and i.monkey and k.monkey and active~='monkey' then return 'monkey','action' end
        end
        return nil
    end
    if travel and i.hostile and near[range] then return CombatAspect(i),'action' end
    if not active then
        if i.moving and i.travel and not i.indoors and not i.swimming and not i.hostile and k.cheetah then return 'cheetah','info' end
        local want=CombatAspect(i)
        if want then return want,i.hostile and 'action' or 'info' end
        return nil
    end
    -- Swimming: Cheetah does not raise swim speed (SCENARIO_REVIEW S49).
    if i.moving and i.travel and not i.indoors and not i.swimming and not i.hostile and k.cheetah and not travel then return 'cheetah','info' end
end
function L.StableRange(state,value,now)
    if value~=state.pending then state.pending,state.since=value,now end
    if now-(state.since or now)>=0.75 then state.range=value end
    return state.range
end
function L.StableAdvice(state,key,tier,now,combat)
    if key~=state.key or tier~=state.tier then
        if not combat or tier=='danger' or key==nil or state.tier=='danger' or now-(state.at or -10)>=2 then
            state.key,state.tier,state.at=key,tier,now
        end
    end
    return state.key,state.tier
end

