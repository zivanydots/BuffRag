local _,F=...
local function public(value)return not(issecretvalue and issecretvalue(value))end
local function read(fn,...)
    if not fn then return end
    local ok,value=pcall(fn,...)
    if ok and public(value)then return value end
end
function F:ActionMetadata(id)
    if id==8166 then return {cleanse={Poison=true}}elseif id==8170 then return {cleanse={Disease=true}}end
    return (self.actionEffects or {})[id]or {}
end
function F:ItemCategory(entry)
    local metadata={}
    local effect,id
    if C_Item.GetItemSpell then
        local ok,a,b=pcall(C_Item.GetItemSpell,entry.id)
        if ok then effect,id=a,b end
        if not(public(id)and type(id)=='number')then
            id=nil
            if public(effect)and type(effect)=='number'then id=effect
            elseif public(effect)and type(effect)=='table'then
                local parsed,value=pcall(function()return effect.spellID or effect.spellId end)
                if parsed and public(value)and type(value)=='number'then id=value end
            end
        end
        if id then metadata=self:ActionMetadata(id)end
    end
    local use=entry.useOn
    if not use or use=='auto'then
        if metadata.selfHealOnly then use='self'
        elseif metadata.heal or metadata.cleanse then use=metadata.purge and 'either'or 'friendly'
        elseif metadata.purge then use='enemy'
        elseif public(id)and type(id)=='number'then
            local help=read(C_Spell.IsSpellHelpful,id)
            local harm=read(C_Spell.IsSpellHarmful,id)
            use=help and(harm and 'either'or 'friendly')or(harm and 'enemy'or 'self')
        else use='friendly'end
    end
    local role=entry.cleanupRole
    if not role or role=='auto'then role=metadata.heal and 'healing'or(metadata.cleanse and 'cleansing'or 'none')end
    local types=entry.cleanseTypes
    if not entry.cleanseOverride and(not types or not next(types))then types=metadata.cleanse end
    return {useOn=use,role=role,cleanse=role=='cleansing'and types or nil,heal=role=='healing',selfHealOnly=use=='self',purge=metadata.purge}
end
function F:ItemTargetAllowed(category,unit,scope)
    local friendly=scope=='targetFriendly'or scope=='focusFriendly'or(scope~='target'and scope~='focus')
    if category.useOn=='self'then return scope=='self'end
    if category.useOn=='enemy'then return not friendly end
    if category.useOn=='friendly'then return friendly end
    return true
end
function F:ItemAction(entry,unit,scope)
    local use=self:ItemCategory(entry).useOn
    local qualifier=(scope=='target'or scope=='focus')and 'harm'or 'help'
    if use=='self'then unit='player';qualifier='help'end
    return {type='macro',macrotext='/use [@'..unit..',exists,'..qualifier..',nodead] item:'..entry.id}
end
-- A blocked/secret scan is unknown, never an assertion that effects are absent.
function F:DispelSnapshot(unit,filter)
    self.dispelSnapshots=self.dispelSnapshots or {}
    local key=unit..':'..filter
    if self.dispelSnapshots[key]then return self.dispelSnapshots[key]end
    local snapshot={types={},complete=false}
    self.dispelSnapshots[key]=snapshot
    local api=C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not api then return snapshot end
    for index=1,255 do
        local ok,aura=pcall(api,unit,index,filter)
        if not ok or not public(aura)then return snapshot end
        if aura==nil then snapshot.complete=true;return snapshot end
        local parsed=pcall(function()
            local kind=aura.dispelName or aura.dispelType
            if not public(kind)then error('restricted dispel type')end
            if type(kind)=='number'then kind=({[1]='Magic',[2]='Curse',[3]='Disease',[4]='Poison',[9]='Enrage'})[kind]end
            if kind then snapshot.types[kind]=true end
        end)
        if not parsed then return snapshot end
    end
    return snapshot
end
function F:MatchingDispel(types,snapshot)
    for kind in pairs(types or {})do if snapshot.types[kind]then return true end end
    if snapshot.complete then return false end
end
function F:CleanupCandidates(unit,candidates)
    if InCombatLockdown()or not self.db.combatClicks then return nil end
    local friend=read(UnitIsFriend,'player',unit)
    if not self:IsSelf(unit)and friend~=true then return nil end
    local dead=read(UnitIsDeadOrGhost,unit)
    local health,maximum=read(UnitHealth,unit,false),read(UnitHealthMax,unit)
    local injured
    if type(health)=='number'and type(maximum)=='number'and maximum>0 then injured=health<maximum end
    local snapshot
    local result={}
    for _,candidate in ipairs(candidates)do
        local effects=candidate.effects or {}
        local relevant=false
        if dead==true then relevant=candidate.allowDead==true
        elseif dead==false and not candidate.allowDead then
            if effects.heal and(not effects.selfHealOnly or self:IsSelf(unit))and injured~=false then relevant=true end
            if effects.cleanse and candidate.dispelReminders~=false then
                snapshot=snapshot or self:DispelSnapshot(unit,'HARMFUL')
                local match=self:MatchingDispel(effects.cleanse,snapshot)
                relevant=relevant or match~=false
                candidate.dispelNeeded=match==true
            end
        end
        if candidate.customItem and self:CustomItemCount(candidate.customItem)==0 then relevant=false end
        if relevant then
            candidate=self:CopySettings(candidate)
            candidate.cleanupOnly=true;candidate.queue=false;candidate.prioritySelected=false
            candidate.cleanupUnknown=dead==nil or(dead==false and((effects.heal and injured==nil)or(effects.cleanse and snapshot and not snapshot.complete)))
            result[#result+1]=candidate
        end
    end
    return #result>0 and result or nil
end
function F:UpdateDispelReminder(button)
    if not button.dispelMark then
        if InCombatLockdown()then return end
        button.dispelMark=button.visual:CreateFontString(nil,'OVERLAY','GameFontNormal')
        button.dispelMark:SetPoint('CENTER',button.visual,'TOP',0,0)
        button.dispelMark:SetText('!');button.dispelMark:SetTextColor(1,.82,0)
    end
    local needed=false
    local effects=button.effects or {}
    if button.dispelReminders~=false and(effects.cleanse or effects.purge)then
        local friend=read(UnitIsFriend,'player',button.buffUnit)
        local types=friend==true and effects.cleanse or(friend==false and effects.purge or nil)
        if types then needed=self:MatchingDispel(types,self:DispelSnapshot(button.buffUnit,friend and 'HARMFUL'or 'HELPFUL'))==true end
    end
    button.dispelMark:SetShown(needed)
end
function F:FrameCombatCandidates(unit,kind)
    local all={}
    local profiles=(kind=='target'or kind=='focus')and {kind,kind..'Friendly'}or {self:CombatScopeFor(unit,kind)}
    for _,profile in ipairs(profiles)do
        for _,candidate in ipairs(self:BuildCombatCandidates(unit,kind,false,profile))do all[#all+1]=candidate end
    end
    return all
end
function F:FrameCleanupCandidates(unit,kind,candidates)
    local selected={}
    local profile=(kind=='target'or kind=='focus')and(kind..'Friendly')or self:CombatScopeFor(unit,kind)
    for _,candidate in ipairs(candidates)do if candidate.profile==profile then selected[#selected+1]=candidate end end
    return self:CleanupCandidates(unit,selected)
end
function F:CombatVisibility(candidate,unit)
    local relation=candidate.targetRule=='enemy'and 'harm,'or 'help,'
    local condition='[@'..unit..',exists,'..relation..(candidate.allowDead and 'dead'or 'nodead')..']'
    if candidate.cleanupOnly then return '[combat] hide; '..condition..' show; hide'end
    if candidate.allowDead and not candidate.combatRes then return 'hide'end
    return '[combat,@'..unit..',exists,'..relation..(candidate.allowDead and 'dead'or 'nodead')..'] show; hide'
end
