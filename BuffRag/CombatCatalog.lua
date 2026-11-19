local _,F=...
local modifiers={"shift","ctrl","alt"}
F.combatModifiers=modifiers
local function public(v)return not (issecretvalue and issecretvalue(v))end
local function read(fn,...)
    if not fn then return end
    local ok,v=pcall(fn,...)
    if ok and public(v) then return v end
end
local function known(id)
    return read(IsPlayerSpell,id) or read(IsSpellKnown,id)
        or (C_SpellBook and read(C_SpellBook.IsSpellKnown,id,Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0))
end
local resurrection={2006,7328,2008,20484,50769}
local noSelf={19752,2006,7328,2008,20484,50769}
                                                                                        
local nonCastable={}
for _,id in ipairs({
    12705,12964,                 
    67,1310897,                                                    
    3674,14296,13481,13535,13797,14298,14299,14300,14301,13812,14314,14315,19185,24406,24529,1310725,                       
    13977,                    
    2943,19249,19251,19252,19253,19254,7001,27873,27874,23455,23458,23459,27803,27804,27805,
    27813,27828,28377,28378,28379,28380,28381,28382,                                 
    16177,16246,21169,26363,26364,26365,26366,26367,26369,26370,30165,                                               
    11103,12355,1239832,12484,12494,12536,21098,22959,28534,28547,29074,29077,29441,29442,                          
    18093,23759,23760,23761,23762,                           
    16870,22845,                                                              
}) do nonCastable[id]=true end
local combatTargetOverrides={SHAMAN={[16166]='self'},PALADIN={[4987]='friendly',[1310994]='enemy'}}
                                                                         
                                                                         
local warlockRules={}
local function warlockRule(ids,rule)for _,id in ipairs(ids)do warlockRules[id]=rule end end
warlockRule({126,18788,7812,19438,19440,19441,19442,19443},"self")                                                
warlockRule({755,3698,3699,3700,11693,11694,11695,11698},"omit")                                  
warlockRule({23759,23760,23761,23762,23784,23785,23830,23831,23832},"omit")                               
warlockRule({6307,7804,7805,11766,11767,19577,24394},"omit")                                             
warlockRule({4511,7870,17767,17850,17851,17852,17853,17854},"omit")                                                       
warlockRule({19505,19731,19734,19736,1302511},"both")                                                           
local hunterRules={}
for _,id in ipairs({883,2641,1002,19574,19577})do hunterRules[id]='self'end                         
for _,id in ipairs({136,3111,3661,3662,13542,13543,13544,982,6991,24406})do hunterRules[id]='omit'end                                            
local petTriggers={[19577]=true,[24394]=true,[1278934]=true}
local function sameFamily(ids,name)
    for _,id in ipairs(ids)do local info=read(C_Spell.GetSpellInfo,id);if info and info.name==name then return true end end
end
local function petSpellID(item,slot,bank)
    if not item then return end
    if public(item.spellID)and type(item.spellID)=="number"then return item.spellID end
    local book=C_SpellBook
    local link=book and read(book.GetSpellBookItemLink,slot,bank)
    if type(link)=="string"then local id=tonumber(link:match("spell:(%d+)"));if id then return id end end
                                                                            
                                                                            
    local name=item.name or(book and read(book.GetSpellBookItemName,slot,bank))
    local info=read(C_Spell.GetSpellInfo,item.actionID)
    if not info or type(name)~="string"or info.name~=name then return end
    for _,token in ipairs({"PET_ACTION_ATTACK","PET_ACTION_FOLLOW","PET_ACTION_STAY","PET_ACTION_MOVE_TO","PET_MODE_PASSIVE","PET_MODE_DEFENSIVE","PET_MODE_AGGRESSIVE","PET_MODE_ASSIST"})do
        if name==token or name==_G[token]then return end
    end
    return item.actionID
end
function F:DiscoverCombatSpells(perf)
    if InCombatLockdown() then return end
    if self.combatBookDirty==false and self.combatCatalogue then
        if self.combatNormalizedDB~=self.db then
            if perf then perf.cache.combatBook="reused, settings order refreshed" end
            self:NormalizeCombatOrder()
        end
        return
    end
    if self.perfRecording then self:NotePerfCacheRebuild("combatBook",perf,not self.combatCatalogue) end
    local groups,byName={},{}
    local function add(id,source,slot,bank,score,learned,pet,familyLabel)
        if nonCastable[id] then return end
        local classTargets=combatTargetOverrides[self.class]
        local rule=(classTargets and classTargets[id])or(self.class=='WARLOCK'and warlockRules[id])or(self.class=='HUNTER'and hunterRules[id])
        local effect=self:ActionMetadata(id)
        if not pet and not rule and effect.dualHeal then rule='both' end
        if not pet and not rule and F.offensiveCombatSpells[id] then rule="enemy" end
        if pet then rule=petTriggers[id]and 'omit'or rule or (self.petTargetRules or {})[id]end
        if rule=="omit"then return end
        local info=read(C_Spell.GetSpellInfo,id)
        if not info or read(C_Spell.IsSpellPassive,id) or (source and source.passive) then return end
        if not source and read(C_Spell.GetSpellTradeSkillLink,id) then return end
        local name=info.name
        if not public(name) or type(name)~="string" then return end
        local family=source
        if not family and not pet then
            for _,entry in ipairs(self.allClassCatalogues[self.class] or {})do
                for _,spell in ipairs(entry.ids)do
                    local other=read(C_Spell.GetSpellInfo,spell)
                    if spell==id or (not entry.created and other and other.name==name) then family=entry;break end
                end
                if family then break end
            end
        end
        if family and family.kind=="items" then return end
        if family and family.combatTarget then rule=family.combatTarget end
        local key=pet and ("pet:"..name)or(family and ("family:"..family.key) or ("spell:"..name))
        local saved=self.db.combatRows and self.db.combatRows[key]
        local available=pet and learned==true
        if pet then
            learned=available or (saved and saved.petLearnedIDs and saved.petLearnedIDs[tostring(id)]==true)or false
        end
        local group=groups[key]
        if not group then
            group={key=key,name=family and family.label or name,spellName=name,source=family,ranks={},rankSet={},buff=family and self.spells[family.key]~=nil or false}
            groups[key]=group
        end
        if self.class=='HUNTER'and not pet and hunterRules[id]=='self'then group.ownerCommand=true end
        if pet then
            group.pet=true;group.petFamilies=group.petFamilies or {}
            group.available=group.available or available
            if familyLabel then group.petFamilies[familyLabel]=true end
            if slot then group.petSlot,group.petBank=slot,bank end
        end
        local sub=read(C_Spell.GetSpellSubtext,id) or ""
        local helpful=read(C_Spell.IsSpellHelpful,id)
        local harmful=read(C_Spell.IsSpellHarmful,id)
        if slot and C_SpellBook then
            local bookHelp=read(C_SpellBook.IsSpellBookItemHelpful,slot,bank)
            local bookHarm=read(C_SpellBook.IsSpellBookItemHarmful,slot,bank)
            if bookHelp~=nil then helpful=bookHelp end
            if bookHarm~=nil then harmful=bookHarm end
            if pet and not group.targetingFromPetBook then group.allowed=nil;group.targetingFromPetBook=true end
        end
        if pet and not rule and not(saved and saved.petAllowed and not slot)then
            rule=harmful and(helpful and 'both'or 'enemy')or 'self'
        end
        local selfOnly=family and family.selfOnly or info.maxRange==0
        if helpful==nil and family and not family.selfOnly then helpful=true end
        group.allowed=group.allowed or {self=false,party=false,raid=false,target=false,focus=false}
        if harmful and not helpful then
            group.allowed.target=true;group.allowed.focus=true
        elseif selfOnly or (not helpful and not harmful) then group.allowed.self=true
        else
            if helpful then group.allowed.self=true;group.allowed.party=true;group.allowed.raid=true;group.allowed.focus=true end
            if harmful then group.allowed.target=true;group.allowed.focus=true end
        end
        if rule=="self"then group.allowed={self=true,party=false,raid=false,target=false,focus=false}
        elseif rule=="both"then group.allowed={self=true,party=true,raid=true,target=true,focus=true}
        elseif rule=='enemy'then group.allowed={self=false,party=false,raid=false,target=true,focus=true}
        elseif rule=='friendly'then group.allowed={self=true,party=true,raid=true,target=false,focus=true}
        elseif pet and not slot and saved and saved.petAllowed then
            group.allowed=self:CopySettings(saved.petAllowed)
        end
        if not pet and rule=="enemy" then group.enemyOnly=true end
        group.deadTarget=group.deadTarget or sameFamily(resurrection,name)
        if sameFamily(noSelf,name)then group.allowed.self=false end
        if group.rankSet[id] then
            if learned or(not pet and known(id))then
                group.learned=true
                for _,rank in ipairs(group.ranks)do if rank.id==id then
                    rank.learned=true
                    if pet and available then rank.available=true;rank.petSlot,rank.petBank=slot,bank end
                end end
            end
            return
        end
        group.rankSet[id]=true
        learned=learned==true or(not pet and known(id)==true)
        group.learned=group.learned or learned
        local level=read(C_Spell.GetSpellLevelLearned,id)
        group.ranks[#group.ranks+1]={id=id,learned=learned,label=sub~="" and sub or ("Level "..(level or "—")),score=tonumber(sub:match("%d+")) or level or score or 0}
        if pet then local rank=group.ranks[#group.ranks];rank.available=available;rank.petSlot,rank.petBank=slot,bank end
        byName[name]=group
    end
    for _,entry in ipairs(self.allClassCatalogues[self.class] or {})do
        if entry.kind~="items" then
            for index,id in ipairs(entry.ids)do add(id,entry,nil,nil,#entry.ids-index)end
            local _,id=self:LearnedSpell(entry.ids,entry.created~=nil)
            if id then
                add(id,entry,nil,nil,#entry.ids,true)
                local group=groups["family:"..entry.key]
                if group then group.learned=true;for _,rank in ipairs(group.ranks)do if rank.id==id then rank.learned=true end end end
            end
            if entry.kind=="poison" and self:PoisonAvailable(entry)then
                add(entry.ids[1],entry,nil,nil,0,true)
                local group=groups["family:"..entry.key];if group then group.learned=true;group.ranks[1].learned=true end
            end
        end
    end
    for _,id in ipairs(self.combatSpellIDs[self.class] or {})do add(id)end
    for _,entry in ipairs(self.combatPetSpellIDs[self.class]or {})do add(entry.id,nil,nil,nil,0,false,true,entry.family)end
                                                                            
                                                                            
    for _,config in pairs(self.db.combatRows or {})do
        for id in pairs(config.petIDs or {})do add(tonumber(id),nil,nil,nil,0,false,true)end
    end
    local book=C_SpellBook
    if book and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo and book.GetSpellBookItemInfo then
        local bank=Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        local spellType=Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1
        local futureType=Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.FutureSpell
        for line=1,book.GetNumSpellBookSkillLines()do
            local info=book.GetSpellBookSkillLineInfo(line)
            if info and not info.isGuild and not info.shouldHide and not info.offSpecID then
                for slot=info.itemIndexOffset+1,info.itemIndexOffset+info.numSpellBookItems do
                    local item=book.GetSpellBookItemInfo(slot,bank)
                    if item and (item.itemType==spellType or (futureType and item.itemType==futureType)) and (item.spellID or item.actionID) and not item.isOffSpec
                        and not read(book.IsSpellBookItemPassive,slot,bank) then add(item.spellID or item.actionID,nil,slot,bank,slot,not item.isUnlearned and item.itemType==spellType)end
                end
            end
        end
    end
    if book and book.HasPetSpells and book.GetSpellBookItemInfo then
        local count=read(book.HasPetSpells)or 0
        local bank=Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet or 1
        for slot=1,count do
            local item=read(book.GetSpellBookItemInfo,slot,bank)
            local id=petSpellID(item,slot,bank)
            if id and not read(book.IsSpellBookItemPassive,slot,bank)then
                add(id,nil,slot,bank,slot,item.isUnlearned~=true,true)
            end
        end
    end
    for _,group in pairs(groups)do
        if group.enemyOnly then group.allowed={self=false,party=false,raid=false,target=true,focus=true} end
        group.allowed.targetFriendly=group.allowed.party==true
        group.allowed.focusFriendly=group.allowed.party==true
        group.allowed.focus=group.allowed.target==true
        group.effects={}
        for _,rank in ipairs(group.ranks)do
            for key,value in pairs(self:ActionMetadata(rank.id))do group.effects[key]=value end
        end
        if group.effects.casterGroupHeal then
            group.allowed={self=true,party=true,raid=false,target=false,focus=false,targetFriendly=false,focusFriendly=false}
        end
        group.deadTarget=group.deadTarget or group.effects.resurrect
        if group.deadTarget then
            if group.effects.selfRes then group.allowed={self=true,party=false,raid=false,target=false,focus=false,targetFriendly=false,focusFriendly=false}
            else group.allowed={self=false,party=true,raid=true,target=false,focus=false,targetFriendly=true,focusFriendly=true}end
        end
        table.sort(group.ranks,function(a,b)return a.score>b.score or (a.score==b.score and a.id>b.id)end)
    end
    groups['combat:items']={key='combat:items',name='Bag Items',itemPlaceholder=true,learned=true,ranks={},allowed={self=true,party=true,raid=true,target=true,focus=true,targetFriendly=true,focusFriendly=true}}
    self.combatCatalogue,self.combatBookDirty=groups,false
    self:NormalizeCombatOrder()
end
function F:PetSpellSlotMatches(button)
    if not button.petSlot or not C_SpellBook or not C_SpellBook.GetSpellBookItemInfo then return false end
    local info=read(C_SpellBook.GetSpellBookItemInfo,button.petSlot,button.petBank)
    return petSpellID(info,button.petSlot,button.petBank)==button.buffSpellID
end
local scopes={"self","party","raid","target","focus","targetFriendly","focusFriendly"}
local enemyScopes={target=true,focus=true}
function F:CombatGroupVisible(group,scope)
    return group and (not group.buff or (self.db.combatIncludeBuffs and not enemyScopes[scope]))
end

function F:CopyCombatProfile(source,destination)
    if InCombatLockdown() or not self.db.combatClicks or source==destination
        or enemyScopes[source]~=enemyScopes[destination] then return end
    local sourceOrder=self.db.combatOrders[source]
    local destinationOrder=self.db.combatOrders[destination]
    if not sourceOrder or not destinationOrder then return end
    local copied,order,modifiers={},{},{}
    for _,key in ipairs(sourceOrder) do
        local group=self.combatCatalogue[key]
        local config=self.db.combatRows[key]
        if group and group.allowed[source] and group.allowed[destination] and config and config.frames[source] then
            local binding=config.bindings[source]
            local destinationKey=config.frames[destination] and config.frames[destination].keybind
            local frame=self:CopySettings(config.frames[source])
            frame.keybind=binding=="icon" and destinationKey or nil
            config.frames[destination],config.bindings[destination]=frame,binding
            if binding and binding~="icon" then modifiers[binding]=true end
            copied[key]=true
            order[#order+1]=key
        end
    end
    local index=1
    for position,key in ipairs(destinationOrder) do
        if copied[key] then
            destinationOrder[position]=order[index]
            index=index+1
        else
            local config=self.db.combatRows[key]
            if config and config.bindings and modifiers[config.bindings[destination]] then
                config.bindings[destination]="icon"
            end
        end
    end
    self:Refresh()
    return true
end
function F:CombatScope(scope)
    return scope or(self.options and self.options.combatScope)or "self"
end
function F:NormalizeCombatOrder()
    local db=self.db
    self.combatNormalizedDB=db
    db.combatRows=type(db.combatRows)=="table"and db.combatRows or {}
    db.combatOrder=type(db.combatOrder)=="table"and db.combatOrder or {}
    db.combatOrders=type(db.combatOrders)=="table"and db.combatOrders or {}
    local oldOrder=db.combatOrder
    local additions={}
    for key in pairs(self.combatCatalogue or {})do additions[#additions+1]=key end
    table.sort(additions,function(a,b)
        if a=='combat:items'then return false elseif b=='combat:items'then return true end
        return self.combatCatalogue[a].name<self.combatCatalogue[b].name
    end)
    local function normalize(source)
        local result,seen={},{}
        for _,key in ipairs(source)do
            if type(key)=="string"and key:sub(1,2)~="__"and not seen[key]then result[#result+1]=key;seen[key]=true end
        end
        for _,key in ipairs(additions)do if not seen[key]then result[#result+1]=key;seen[key]=true end end
        return result
    end
    for key,group in pairs(self.combatCatalogue or {})do
        local config=db.combatRows[key]
        if not config then config={enabled=false};db.combatRows[key]=config end
        if group.pet then
            config.petIDs=config.petIDs or {}
            config.petLearnedIDs=config.petLearnedIDs or {}
            for _,rank in ipairs(group.ranks)do
                config.petIDs[tostring(rank.id)]=true
                if rank.learned then config.petLearnedIDs[tostring(rank.id)]=true end
            end
            if group.available then config.petAllowed=self:CopySettings(group.allowed)end
        end
        if not config.bindings then
            local targets=config.targets or {}
            local any=targets.self or targets.party or targets.raid or targets.target or targets.focus
            local mod
            for index=1,3 do if oldOrder[index]==key then mod=modifiers[index]end end
            config.bindings={}
            for _,scope in ipairs(scopes)do
                local on=targets[scope]or(not any and(scope=="self"and group.allowed.self or scope=="target"and not group.allowed.self))
                config.bindings[scope]=group.allowed[scope]and on and(mod or "icon")or "off"
            end
        end
        config.frames=type(config.frames)=="table"and config.frames or {}
        for _,scope in ipairs({"targetFriendly","focusFriendly"})do
            local base=scope:gsub('Friendly$','')
            if not config.frames[scope]and config.frames[base]then
                config.frames[scope]=self:CopySettings(config.frames[base]);config.bindings[scope]=config.bindings[base]
            end
        end
        for _,scope in ipairs(scopes)do
            local binding=config.bindings[scope]
            if not config.frames[scope]then
                config.frames[scope]={enabled=config.enabled==true and binding~=nil and binding~="off"and group.allowed[scope]==true,rankID=config.rankID}
            end
            local frame=config.frames[scope]
            if group.itemPlaceholder then frame.enabled=true;binding="icon"end
            if not group.allowed[scope]then frame.enabled=false;binding="icon"end
            if binding~="shift"and binding~="ctrl"and binding~="alt"then binding="icon"end
            config.bindings[scope]=binding
            if group.itemPlaceholder or not group.allowed[scope] then frame.outOfCombat=nil end
            if group.itemPlaceholder or not group.allowed[scope] or binding~='icon'
                or not self:CombatKeyUnit(scope) or type(frame.keybind)~='string' or frame.keybind=='' then frame.keybind=nil end
            if frame.rankID then
                local valid=false
                for _,rank in ipairs(group.ranks)do if rank.id==frame.rankID and(rank.learned or group.pet)then valid=true end end
                if not valid then frame.rankID=nil end
            end
        end
        config.enabled,config.rankID,config.targets=nil,nil,nil
    end
    db.combatOrder=normalize(oldOrder)
    for _,scope in ipairs(scopes)do
        db.combatOrders[scope]=normalize(db.combatOrders[scope]or db.combatOrders[scope:gsub('Friendly$','')]or db.combatOrder)
        local used={}
        for _,key in ipairs(db.combatOrders[scope])do
            local config=self.combatCatalogue[key] and db.combatRows[key]
            local binding=config and config.bindings and config.bindings[scope]
            if binding and binding~="icon"then
                if used[binding]then config.bindings[scope]="icon"else used[binding]=true end
            end
        end
    end
end
function F:CombatFrameSettings(key,scope)
    local config=self.db.combatRows[key]
    return config and config.frames and config.frames[self:CombatScope(scope)]
end
function F:CombatDisplayRows(scope,filtered,enabledField)
    scope=self:CombatScope(scope)
    local assigned,tail={},{}
    local slots={shift=1,ctrl=2,alt=3}
    for index,key in ipairs(self.db.combatOrders[scope]or {})do
        local group=self.combatCatalogue and self.combatCatalogue[key]
        local dispel=group and group.effects and(group.effects.cleanse or group.effects.purge)
        local config=self.db.combatRows[key]
        local frame=config and config.frames and config.frames[scope]
        if self:CombatGroupVisible(group,scope)and group.allowed[scope]and frame
            and (not enabledField or (frame.enabled and frame[enabledField] and group.learned))then
            local row={key=key,index=index,group=group,config=config,frame=frame,scope=scope}
            local slot=slots[config.bindings[scope]]
            if slot then row.modifier=config.bindings[scope];assigned[slot]=row else tail[#tail+1]=row end
        end
    end
    local rows={}
    for slot=1,3 do
        rows[slot]=assigned[slot]or {key="__"..modifiers[slot],scope=scope,modifier=modifiers[slot]}
        rows[slot].position=slot
    end
    for _,row in ipairs(tail)do row.position=#rows+1;rows[#rows+1]=row end
    if filtered and self.options and self.options.combatDispelsOnly then
        local shown={}
        for _,row in ipairs(rows)do
            local effects=row.group and row.group.effects or {}
            if row.modifier or effects.cleanse or effects.purge then shown[#shown+1]=row end
        end
        return shown
    end
    return rows
end
function F:CombatRowsForScope(scope)
    local rows,last={},3
    for _,row in ipairs(self:CombatDisplayRows(scope,nil,'enabled'))do
        if row.group then
            if not row.modifier then last=last+1 end
            row.combatPosition=row.modifier and row.position or last
            rows[#rows+1]=row
        end
    end
    return rows,last
end
function F:SetCombatOutOfCombat(key,scope,enabled)
    if InCombatLockdown() then return end
    local group=self.combatCatalogue[key];local frame=self:CombatFrameSettings(key,scope)
    if not group or group.itemPlaceholder or not group.learned or not group.allowed[scope] or not frame or not frame.enabled then return end
    frame.outOfCombat=enabled==true or nil
    self:Refresh()
end
function F:SetCombatEnabled(key,scope,enabled)
    if InCombatLockdown()then return end
    local group=self.combatCatalogue[key];local frame=self:CombatFrameSettings(key,scope)
    if not group or not group.learned or not group.allowed[scope]or not frame then return end
    frame.enabled=enabled==true;self:Refresh()
end
function F:SetCombatBinding(key,scope,value)
    if InCombatLockdown()then return end
    local group=self.combatCatalogue[key];local config=self.db.combatRows[key]
    if not group or group.itemPlaceholder or not group.learned or not group.allowed[scope]or not config then return end
    if value=="off"then self:SetCombatEnabled(key,scope,false);return end
    if value~="icon"and value~="shift"and value~="ctrl"and value~="alt"then return end
    local previous=config.bindings[scope]
    if value~="icon"then
        local occupant
        for otherKey,other in pairs(self.db.combatRows)do
            if otherKey~=key and self.combatCatalogue[otherKey] and other.bindings and other.bindings[scope]==value then
                other.bindings[scope]=previous;occupant=otherKey
            end
        end
        config.frames[scope].keybind=nil
        if occupant then
            local order=self.db.combatOrders[scope];local from,to
            for index,otherKey in ipairs(order)do if otherKey==key then from=index elseif otherKey==occupant then to=index end end
            if from and to then order[from],order[to]=order[to],order[from]end
        end
    end
    config.bindings[scope]=value;self:Refresh()
    if value~="icon"and self.options and self.options.combatScope==scope and self.options.combatContent then self.options.combatContent.scroll:SetVerticalScroll(0)end
end
function F:ReorderCombatRow(key,toVisible,scope)
    if InCombatLockdown()then return end
    scope=self:CombatScope(scope)
    local rows=self:CombatDisplayRows(scope)
    local source
    for _,row in ipairs(rows)do if row.key==key then source=row;break end end
    if not source or source.modifier then return end
    toVisible=math.max(4,math.min(#rows,toVisible))
    local target=rows[toVisible];if not target or not target.index then return end
    local order=self.db.combatOrders[scope]
    table.insert(order,target.index,table.remove(order,source.index));self:Refresh()
end
function F:MoveCombatRow(index,direction,scope)
    local rows=self:CombatDisplayRows(scope)
    for i,row in ipairs(rows)do if row.index==index and not row.modifier and i+direction>=4 and rows[i+direction]then self:ReorderCombatRow(row.key,i+direction,scope);return end end
end
function F:MoveCombatToEdge(key,bottom,scope)
    if InCombatLockdown()then return end
    scope=self:CombatScope(scope)
    local rows=self:CombatDisplayRows(scope)
    self:ReorderCombatRow(key,bottom and #rows or 4,scope)
    local content=self.options and self.options.combatContent
    if content and self:CombatScope()==scope then content.scroll:SetVerticalScroll(bottom and math.max(0,content:GetHeight()-content.scroll:GetHeight())or 0)end
end
function F:CombatChosenRank(group,scope,requireAvailable)
    local frame=self:CombatFrameSettings(group.key,scope)
    local selected=frame and frame.rankID
    local function usable(rank)return rank.learned and(not requireAvailable or not group.pet or rank.available)end
    for _,rank in ipairs(group.ranks)do if usable(rank)and(not selected or rank.id==selected)then return rank.id end end
    for _,rank in ipairs(group.ranks)do if usable(rank)then return rank.id end end
end
function F:CombatSpellAction(group,unit,id,scope)
    local info=C_Spell.GetSpellInfo(id)
    local sub=C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id)or ""
    local spell=info.name..(sub~=''and '('..sub..')'or '')
    local guard=group.pet and "/stopmacro [@pet,noexists][@pet,dead]\n"or ""
                                                                           
                                                                       
    if group.ownerCommand or group.effects.casterGroupHeal or(group.pet and group.allowed.self and not group.allowed.party and not group.allowed.target)then
        return {type='macro',macrotext=guard..'/cast '..spell}
    end
    local qualifier="help"
    if unit=="target"or unit=="focus"then
        if scope then qualifier=scope:find('Friendly',1,true)and 'help'or 'harm'
        else qualifier=group.allowed.party and(group.allowed.target and nil or 'help')or 'harm'end
    end
    local condition="[@"..unit..",exists,"..(qualifier and qualifier.."," or "")..(group.deadTarget and "dead" or "nodead").."] "
    return {type="macro",macrotext=guard.."/cast "..condition..spell}
end
