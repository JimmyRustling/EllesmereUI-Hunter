-- Public MythicSim reference rates, NOT confirmed Forever server rates.
-- CC BY-NC-SA 4.0. Numbers researched in MIT-licensed wowsims-derived code.
if EUI_CLIENT_BLOCKED then return end
local _,ns=...
ns.ProcReference={
    source='https://github.com/sage3648/mythicsim-forever-engine-go/blob/51da1856fc932401bd880e3691cba14b33039dc1/sim/common/item_effects.go',
    revision='51da1856fc932401bd880e3691cba14b33039dc1',date='2026-10-04',
    items={
        [14555]={ppm=1,note='Classic Armaments reference'},
        [12798]={ppm=1,note='Classic reference; source says may be higher'},
        [12790]={ppm=1,note='Source says assumed, needs testing'},
        [13246]={ppm=1,note='Forever effect changed; rate is Classic reference'},
        [12791]={ppm=1,note='Source says assumed'},
        [14541]={ppm=0.5,note='Source says assumed, needs testing'},
        [13204]={ppm=2,note='Classic Armaments reference'},
    },
}
