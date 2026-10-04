-- FHK Gear: public-value guards and bounded diagnostics. CC BY-NC-SA 4.0; see LICENSE.md.
if EUI_CLIENT_BLOCKED then return end
local _, ns = ...
local S = {errors = {}, counts = {}}
ns.Safe = S
function S.Plain(v) return not (issecretvalue and issecretvalue(v)) end
function S.Number(v)
    return S.Plain(v) and type(v) == 'number' and v == v and v > -math.huge and v < math.huge
end
function S.Text(v) return S.Plain(v) and type(v) == 'string' end
function S.Table(v) return S.Plain(v) and type(v) == 'table' end
function S.Yes(v) return S.Plain(v) and v==true end
function S.OutsideCombat() local value=S.Read(InCombatLockdown);return S.Plain(value) and value==false end
function S.Note(key, message)
    if not S.Text(key) then key = 'API' end
    if S.counts[key] then S.counts[key] = S.counts[key] + 1; return end
    if #S.errors >= 32 then return end
    S.counts[key] = 1
    S.errors[#S.errors + 1] = {key = key, message = S.Text(message) and message or 'Public data unavailable'}
end
function S.Read(fn, ...)
    if type(fn) ~= 'function' then return end
    local ok, a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q = pcall(fn, ...)
    if not ok then S.Note('read:' .. tostring(fn), a); return end
    return a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q
end
function S.Call(key, fn, ...)
    if type(fn) ~= 'function' then S.Note(key, 'API unavailable'); return false end
    local ok, a,b,c = pcall(fn, ...)
    if not ok then S.Note(key, a); return false end
    return true, a,b,c
end
function S.Copy(value, depth, seen)
    if not S.Plain(value) then return nil end
    if type(value) == 'number' then return S.Number(value) and value or nil end
    if type(value) ~= 'table' then
        if type(value) == 'string' or type(value) == 'boolean' then return value end
        return nil
    end
    depth, seen = depth or 0, seen or {}
    if depth > 8 or seen[value] then return nil end
    seen[value] = true
    local out, count = {}, 0
    for k,v in pairs(value) do
        count = count + 1
        if count > 2048 then break end
        if S.Text(k) or S.Number(k) then out[k] = S.Copy(v, depth + 1, seen) end
    end
    seen[value] = nil
    return out
end
function S.Time() local v = S.Read(GetTime); return S.Number(v) and v or 0 end
