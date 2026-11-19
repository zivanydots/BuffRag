local _, F = ...
F.stoneTypes = {
    soul = { ids = {20757,20756,20755,20752,693}, items = {16896,16895,16893,16892,5232} },
    fire = { ids = {17953,17952,17951,6366}, items = {13701,13700,13699,1254} },
    spell = { ids = {17728,17727,2362}, items = {13603,13602,5522} },
    health = { ids = {11730,11729,5699,6202,6201},
        -- Each tier: Improved Healthstone 2/2, 1/2, then untalented.
        items = {19013,19012,9421,19011,19010,5510,19009,19008,5509,
            19007,19006,5511,19005,19004,5512} },
}

-- A catalogue entry is a buff family, not a single spell rank. New class
-- mechanics belong here; the queue, targeting and UI do not branch on class.
local function S(key, label, ids, options)
    local entry = options or {}
    entry.key, entry.label, entry.ids = key, label, ids
    return entry
end
F.classCatalogues = {
 WARLOCK = {
    S("armor", "Demon Armor / Demon Skin", {11735,11734,11733,1086,706,696,687}, {selfOnly=true, default=true}),
    S("sense", "Sense Demons", {5500}, {selfOnly=true,kind="tracking"}),
    S("detect", "Detect Invisibility", {11743,11742,132}),
    S("breath", "Unending Breath", {5697}),
    S("soulLink", "Soul Link", {19028}, {selfOnly=true,auraIDs={25228}}),
    S("shadowWard", "Shadow Ward", {28610,11740,11739,6229}, {selfOnly=true,hideOnCooldown=true}),
    S("soul", "Soulstone", {20757,20756,20755,20752,693}, {kind="soul",stone="soul",auraIDs={20707,20762,20763,20764,20765}}),
    S("fire", "Firestone", {17953,17952,17951,6366}, {selfOnly=true,kind="stoneWeapon",stone="fire",exclusive="weapon"}),
    S("spell", "Spellstone", {17728,17727,2362}, {selfOnly=true,kind="stoneWeapon",stone="spell",exclusive="weapon"}),
    S("health", "Healthstone", {11730,11729,5699,6202,6201}, {selfOnly=true,kind="stoneConsumable",stone="health",default=true}),
 },
 PRIEST = {
    S("fortitude", "Power Word: Fortitude", {10938,10937,2791,1245,1244,1243}, {default=true,exclusive="fortitude",auraIDs={21562,21564}}),
    S("prayerFortitude", "Prayer of Fortitude", {21564,21562}, {exclusive="fortitude",auraIDs={10938,10937,2791,1245,1244,1243}}),
    S("spirit", "Divine Spirit", {27841,14819,14818,14752}, {default=true,exclusive="spirit",auraIDs={27681}}),
    S("prayerSpirit", "Prayer of Spirit", {27681}, {exclusive="spirit",auraIDs={27841,14819,14818,14752}}),
    S("shadowProtection", "Shadow Protection", {10958,10957,976}, {exclusive="shadowProtection",auraIDs={27683}}),
    S("prayerShadow", "Prayer of Shadow Protection", {27683}, {exclusive="shadowProtection",auraIDs={10958,10957,976}}),
    S("innerFire", "Inner Fire", {10952,10951,10950,1006,7128,588}, {selfOnly=true,default=true}),
    S("fearWard", "Fear Ward", {6346}, {cooldownLimited=true}),
    S("touchWeakness", "Touch of Weakness", {19266,19265,19264,19263,19262,2652}, {selfOnly=true}),
    S("shadowguard", "Shadowguard", {19312,19311,19310,19309,19308,18137}, {selfOnly=true}),
 },
 MAGE = {
    S("intellect", "Arcane Intellect", {10157,10156,1461,1460,1459}, {default=true,exclusive="intellect",auraIDs={23028}}),
    S("brilliance", "Arcane Brilliance", {23028}, {exclusive="intellect",auraIDs={10157,10156,1461,1460,1459}}),
    S("iceArmor", "Frost / Ice Armor", {10220,10219,7320,7302,7301,7300,168}, {selfOnly=true,default=true,exclusive="armor"}),
    S("mageArmor", "Mage Armor", {22783,22782,6117}, {selfOnly=true,exclusive="armor"}),
    S("iceBarrier", "Ice Barrier", {13033,13032,13031,11426}, {selfOnly=true,hideOnCooldown=true,auraIDs={1326891}}),
    S("fireWard", "Fire Ward", {10225,10223,8458,8457,543}, {selfOnly=true,hideOnCooldown=true}),
    S("frostWard", "Frost Ward", {28609,10177,8462,8461,6143}, {selfOnly=true,hideOnCooldown=true}),
    S("dampenMagic", "Dampen Magic", {10175,10174,8451,8450,604}, {exclusive="magic"}),
    S("amplifyMagic", "Amplify Magic", {10170,10169,8455,1008}, {exclusive="magic"}),
    S("conjureWater", "Conjured Water - keep in bags", {10140,10139,10138,6127,5506,5505,5504}, {selfOnly=true,kind="created",stockOnly=true,created={[10140]={8079},[10139]={8078},[10138]={8077},[6127]={3772},[5506]={2136},[5505]={2288},[5504]={5350}}}),
    S("conjureFood", "Conjured Food - keep in bags", {28612,10145,10144,6129,990,597,587}, {selfOnly=true,kind="created",stockOnly=true,created={[28612]={22895},[10145]={8076},[10144]={8075},[6129]={1487},[990]={1114},[597]={5349},[587]={5347}}}),
    S("manaGem", "Mana Gem", {10054,10053,3552,759}, {selfOnly=true,kind="created",keepKey="manaGem",resource="mana",created={[10054]={8008},[10053]={8007},[3552]={5513},[759]={5514}}}),
 },
 DRUID = {
    S("mark", "Mark of the Wild", {9885,9884,8907,5234,6756,5232,1126}, {default=true,exclusive="mark",auraIDs={21849,21850}}),
    S("gift", "Gift of the Wild", {21850,21849}, {exclusive="mark",auraIDs={9885,9884,8907,5234,6756,5232,1126}}),
    S("thorns", "Thorns", {9910,9756,8914,1075,782,467}),
 },
 PALADIN = {
    S("might", "Blessing of Might", {25291,19838,19837,19836,19835,19740}, {exclusive="blessing",auraIDs={25782,25916}}),
    S("wisdom", "Blessing of Wisdom", {25290,19854,19853,19852,19850,19742}, {exclusive="blessing",auraIDs={25894,25918}}),
    S("kings", "Blessing of Kings", {20217}, {exclusive="blessing",auraIDs={25898}}),
    S("oathLight", "Oath of Light", {1328548}, {singleRecipient=true,duration=300}),
    S("greaterMight", "Greater Blessing of Might", {25916,25782}, {exclusive="blessing",auraIDs={25291,19838,19837,19836,19835,19740}}),
    S("greaterWisdom", "Greater Blessing of Wisdom", {25918,25894}, {exclusive="blessing",auraIDs={25290,19854,19853,19852,19850,19742}}),
    S("greaterKings", "Greater Blessing of Kings", {25898}, {exclusive="blessing",auraIDs={20217}}),
    S("devotion", "Devotion Aura", {10293,10292,10291,1032,643,10290,465}, {selfOnly=true,exclusive="aura"}),
    S("retribution", "Retribution Aura", {10301,10300,10299,7294}, {selfOnly=true,exclusive="aura"}),
    S("concentration", "Concentration Aura", {19746}, {selfOnly=true,exclusive="aura"}),
    S("fireResistance", "Fire Resistance Aura", {19900,19899,19891}, {selfOnly=true,exclusive="aura"}),
    S("frostResistance", "Frost Resistance Aura", {19898,19897,19888}, {selfOnly=true,exclusive="aura"}),
    S("shadowResistance", "Shadow Resistance Aura", {19896,19895,19876}, {selfOnly=true,exclusive="aura"}),
    S("righteousFury", "Righteous Fury", {25780}, {selfOnly=true}),
 },
 HUNTER = {
    S("hawk", "Aspect of the Hawk", {25296,14322,14321,14320,14319,14318,13165}, {selfOnly=true,exclusive="aspect"}),
    S("monkey", "Aspect of the Monkey", {13163}, {selfOnly=true,exclusive="aspect"}),
    S("cheetah", "Aspect of the Cheetah", {5118}, {selfOnly=true,exclusive="aspect"}),
    S("pack", "Aspect of the Pack", {13159}, {selfOnly=true,exclusive="aspect"}),
    S("wild", "Aspect of the Wild", {20190,20043}, {selfOnly=true,exclusive="aspect"}),
    S("beast", "Aspect of the Beast", {13161}, {selfOnly=true,exclusive="aspect"}),
    S("trueshot", "Trueshot Aura", {20906,20905,19506}, {selfOnly=true,default=true}),
    S("trackBeasts", "Track Beasts", {1494}, {selfOnly=true,kind="tracking",exclusive="tracking"}),
    S("trackHumanoids", "Track Humanoids", {19883}, {selfOnly=true,kind="tracking",exclusive="tracking"}),
    S("trackUndead", "Track Undead", {19884}, {selfOnly=true,kind="tracking",exclusive="tracking"}),
    S("trackHidden", "Track Hidden", {19885}, {selfOnly=true,kind="tracking",exclusive="tracking"}),
    S("trackElementals", "Track Elementals", {19880}, {selfOnly=true,kind="tracking",exclusive="tracking"}),
    S("trackDemons", "Track Demons", {19878}, {selfOnly=true,kind="tracking",exclusive="tracking"}),
    S("trackDragonkin", "Track Dragonkin", {19879}, {selfOnly=true,kind="tracking",exclusive="tracking"}),
    S("trackGiants", "Track Giants", {19882}, {selfOnly=true,kind="tracking",exclusive="tracking"}),
 },
 SHAMAN = {
    S("lightningShield", "Lightning Shield", {10432,10431,10430,905,945,325,324}, {selfOnly=true,default=true,exclusive="elementalShield"}),
    S("waterShield", "Water Shield", {408510}, {selfOnly=true,exclusive="elementalShield"}),
    S("waterBreathing", "Water Breathing", {131}),
    S("waterWalking", "Water Walking", {546}),
    S("rockbiter", "Rockbiter Weapon", {16316,16315,16314,10399,8019,8018,8017}, {selfOnly=true,kind="weapon",exclusive="weapon"}),
    S("flametongue", "Flametongue Weapon", {16342,16341,16339,10445,8030,8027,8024}, {selfOnly=true,kind="weapon",exclusive="weapon"}),
    S("frostbrand", "Frostbrand Weapon", {16356,16355,10456,8038,8033}, {selfOnly=true,kind="weapon",exclusive="weapon"}),
    S("windfury", "Windfury Weapon", {16362,16361,10486,8235,8232}, {selfOnly=true,kind="weapon",exclusive="weapon"}),
    S("strengthTotem", "Strength of Earth Totem", {25361,10442,8161,8160,8075}, {selfOnly=true,kind="totem",slot=2,exclusive="earthTotem"}),
    S("stoneskinTotem", "Stoneskin Totem", {10408,10407,10406,8155,8154,8071}, {selfOnly=true,kind="totem",slot=2,exclusive="earthTotem"}),
    S("tremorTotem", "Tremor Totem", {8143}, {selfOnly=true,kind="totem",slot=2,exclusive="earthTotem"}),
    S("manaSpring", "Mana Spring Totem", {10497,10496,10495,5675}, {selfOnly=true,kind="totem",slot=3,exclusive="waterTotem"}),
    S("healingStream", "Healing Stream Totem", {10463,10462,10461,6377,6375,5394}, {selfOnly=true,kind="totem",slot=3,exclusive="waterTotem"}),
    S("poisonCleansing", "Poison Cleansing Totem", {8166}, {selfOnly=true,kind="totem",slot=3,exclusive="waterTotem"}),
    S("diseaseCleansing", "Disease Cleansing Totem", {8170}, {selfOnly=true,kind="totem",slot=3,exclusive="waterTotem"}),
    S("fireResTotem", "Fire Resistance Totem", {10538,10537,8184}, {selfOnly=true,kind="totem",slot=3,exclusive="waterTotem"}),
    S("windfuryTotem", "Windfury Totem", {10614,10613,8512}, {selfOnly=true,kind="totem",slot=4,exclusive="airTotem",incompatible={flametongueTotem=true}}),
    S("graceAir", "Grace of Air Totem", {25359,10627,8835}, {selfOnly=true,kind="totem",slot=4,exclusive="airTotem"}),
    S("windwall", "Windwall Totem", {15112,15111,15107}, {selfOnly=true,kind="totem",slot=4,exclusive="airTotem"}),
    S("natureResTotem", "Nature Resistance Totem", {10601,10600,10595}, {selfOnly=true,kind="totem",slot=4,exclusive="airTotem"}),
    S("flametongueTotem", "Flametongue Totem", {16389,10587,10586,8227}, {selfOnly=true,kind="totem",slot=1,exclusive="fireTotem",incompatible={windfuryTotem=true}}),
    S("frostResTotem", "Frost Resistance Totem", {10479,10478,8181}, {selfOnly=true,kind="totem",slot=1,exclusive="fireTotem"}),
 },
 WARRIOR = {
    S("battleShout", "Battle Shout", {25289,11551,11550,11549,6192,5242,6673}, {selfOnly=true,default=true}),
 },
 ROGUE = {
    S("instantPoison", "Instant Poison", {11343,11342,11341,8691,8687,8681}, {selfOnly=true,kind="poison",poisonItems={8928,8927,8926,6950,6949,6947}}),
    S("deadlyPoison", "Deadly Poison", {25347,11358,11357,2837,2835}, {selfOnly=true,kind="poison",poisonItems={20844,8985,8984,2893,2892}}),
    S("cripplingPoison", "Crippling Poison", {3421,3420}, {selfOnly=true,kind="poison",poisonItems={3776,3775}}),
    S("mindNumbingPoison", "Mind-numbing Poison", {11400,8694,5763}, {selfOnly=true,kind="poison",poisonItems={9186,6951,5237}}),
    S("woundPoison", "Wound Poison", {13230,13229,13228,13220}, {selfOnly=true,kind="poison",poisonItems={10922,10921,10920,10918}}),
    S("occultPoison", "Occult Poison", {1214168,458822}, {selfOnly=true,kind="poison",poisonItems={234444,226374}}),
    S("atrophicPoison", "Atrophic Poison", {439503}, {selfOnly=true,kind="poison",poisonItems={217347}}),
    S("numbingPoison", "Numbing Poison", {439505}, {selfOnly=true,kind="poison",poisonItems={217346}}),
    S("sebaciousPoison", "Sebacious Poison", {439500}, {selfOnly=true,kind="poison",poisonItems={217345}}),
 },
}
-- Items are a movable insertion point shared by every class, even when empty.
for _, entries in pairs(F.classCatalogues) do
    entries[#entries+1] = S("items", "Pots / Items", {}, {kind="items",default=true})
end
-- Preparation/maintenance belongs on Buffs; short defensive and placed
-- combat abilities belong on Combat. Keep their rank/item metadata shared.
F.allClassCatalogues,F.combatClassCatalogues={},{}
for class,entries in pairs(F.classCatalogues) do
    F.allClassCatalogues[class]=entries
    local buffs,combat={},{}
    for _,entry in ipairs(entries) do
        entry.combatOnly=entry.hideOnCooldown or entry.cooldownLimited or entry.singleRecipient or entry.kind=="totem" or false
        if entry.combatOnly then combat[#combat+1]=entry else buffs[#buffs+1]=entry end
    end
    F.classCatalogues[class],F.combatClassCatalogues[class]=buffs,combat
end
