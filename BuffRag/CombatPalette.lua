local _,F=...
local beast,dragonkin,demon,elemental,undead,humanoid,critter=1,2,3,4,6,7,8
local creatureTargets={}
local function creatureRule(types,ids)
    local allowed={}
    for _,kind in ipairs(types) do allowed[kind]=true end
    for _,id in ipairs(ids) do creatureTargets[id]=allowed end
end
creatureRule({beast},{1462,1513,1515,2908,8955,9901,14326,14327,1324506,1324507,1324510})
creatureRule({beast,dragonkin},{2637,18657,18658})
creatureRule({beast,humanoid,critter},{118,12824,12825,12826,28270,28271,28272,434754})
creatureRule({demon},{1098,11725,11726,1324468})
creatureRule({demon,elemental},{710,18647,1324462,1324463})
creatureRule({demon,undead},{879,5614,5615,10312,10313,10314,1328372,1328373,1328374})
creatureRule({undead},{2878,5627,9484,9485,10326,10955,1324415,1324420,1324422,1324543,1324545,1324546})
creatureRule({humanoid},{453,605,2070,6358,6770,8192,10911,10912,10953,11297,1324482,1324483,1324484})

function F:CombatCreatureType(unit,cache)
    local kind=cache[unit]
    if kind~=nil then return kind end
    if UnitCreatureType then
        local _,id=UnitCreatureType(unit)
        if not (issecretvalue and issecretvalue(id)) and type(id)=="number" and id>0 then kind=id end
    end
    cache[unit]=kind or false
    return cache[unit]
end

function F:CombatScopeFor(unit,context)
    if context=="raidParty"then return "party"end
    if context=="self"or context=="party"or context=="raid"or context=="target"or context=="focus"or context=="targetFriendly"or context=="focusFriendly"then return context end
    return self:ScopeFor(unit,context)
end
function F:CombatScopeSelected(targets,scope,allowed)
    if allowed and not allowed[scope]then return false end
    if targets[scope]then return true end
    return scope=="self" and not(targets.self or targets.party or targets.raid or targets.target or targets.focus)
end
function F:BeginFrameCombatCast(frame,mouse,down)
    local combat=InCombatLockdown() or self:IsDuelCombat()
    if not combat and not frame.cleanupMode then return end
    local mod,count=nil,0
    for _,pair in ipairs({{"shift",IsShiftKeyDown},{"ctrl",IsControlKeyDown},{"alt",IsAltKeyDown}})do
        if pair[2] and pair[2]()then mod=pair[1];count=count+1 end
    end
    if count==1 then
        local buttons=frame.combatButtons
        if combat and frame:GetAttribute('dual-profile')then buttons=frame.combatButtonsByRelation and frame.combatButtonsByRelation[frame:GetAttribute('state-relation')or 'enemy']end
        frame.feedbackCombatButton=buttons and buttons[mod]
        if frame.feedbackCombatButton then self:BeginIconCast(frame.feedbackCombatButton,mouse,down)end
    end
end
function F:EndFrameCombatCast(frame,mouse,down)
    if frame.feedbackCombatButton then self:EndIconCast(frame.feedbackCombatButton,mouse,down)end
    frame.feedbackCombatButton=nil
end
function F:BuildCombatCandidates(unit,context,preview,profile,rowCache)
    local result={}
    if not self.db.combatClicks and not preview then return result end
    local scope=profile or self:CombatScopeFor(unit,context)
    local rows=rowCache and rowCache[scope]
    if not rows then
        rows=self:CombatRowsForScope(scope)
        if rowCache then rowCache[scope]=rows end
    end
    for _,row in ipairs(rows)do
        local group,config=row.group,row.config
        if group and group.itemPlaceholder then
            if self.db.itemsEnabled then
                local base=scope:gsub('Friendly$','')
                for index,item in ipairs(self.db.items)do
                    local category=self:ItemCategory(item)
                    if item.enabled and item.combat and self:CombatScopeSelected(item,base)and self:ItemTargetAllowed(category,unit,scope)then
                        local data=self:CustomItemData(item.id,unit)
                        if data.usable then result[#result+1]={key='items',name=data.name,itemID=item.id,customItem=item.id,itemIndex=index,unit=unit,
                            combatOnly=true,combatPosition=row.combatPosition+index/(#self.db.items+1),profile=scope,
                            effects=category,dispelReminders=item.dispelReminders~=false,targetRule=scope:find('Friendly',1,true)and 'friendly'or((scope=='target'or scope=='focus')and 'enemy'or nil),
                            action=self:ItemAction(item,unit,scope)}end
                    end
                end
            end
        elseif group and group.learned and (preview or not group.pet or group.available) then
            local id=self:CombatChosenRank(group,scope,not preview)
            local function add(candidate,extra)
                if not candidate then return end
                candidate.combatOnly=true;candidate.queue=false;candidate.prioritySelected=false
                candidate.rankBadge=group.baseKey and row.frame.showRankBadge and group.ranks[1].label:match("[Rr]ank%s*(%d+)")
                candidate.showOutOfCombat=self:CombatSupportsOutOfCombat(group) and row.frame.outOfCombat==true
                candidate.keybind=not extra and not row.modifier and row.frame.keybind or nil
                if candidate.keybind then candidate.keybindOverride=row.frame.keybindOverride end
                candidate.combatModifier=not extra and row.modifier or nil
                candidate.combatPosition=row.combatPosition+(extra and .001 or 0)
                candidate.profile=scope;candidate.effects=candidate.itemID and self:ItemCategory({id=candidate.itemID})or self:ActionMetadata(id)
                candidate.creatureTargets=creatureTargets[id]
                if (id==2878 or id==5627 or id==10326) and C_Spell.GetOverrideSpell then
                    local override=C_Spell.GetOverrideSpell(id)
                    if not (issecretvalue and issecretvalue(override)) then
                        candidate.creatureTargets=creatureTargets[override] or candidate.creatureTargets
                    end
                end
                candidate.dispelReminders=row.frame.dispelReminders~=false
                candidate.pet=group.pet;candidate.petSlot=group.petSlot;candidate.petBank=group.petBank
                if group.pet then for _,rank in ipairs(group.ranks)do if rank.id==id then candidate.petSlot,candidate.petBank=rank.petSlot,rank.petBank end end end
                candidate.targetRule=(unit=="target"or unit=="focus")and(scope:find('Friendly',1,true)and 'friendly'or 'enemy')or nil
                candidate.allowDead=group.deadTarget
                candidate.combatRes=group.deadTarget and self:IsBattleResurrection(id)
                result[#result+1]=candidate
            end
            local source=group.source
            if source and source.kind then
                if source.kind=="poison" and self.db.poisonHands[source.key]=="both"then
                    add(self:PoisonCandidate(source,unit,true,16))
                    add(self:PoisonCandidate(source,unit,true,17),true)
                else
                    local candidate
                    if source.created then candidate=self:CreatedItemCandidate(source,false,true,id)
                    else candidate=self:BuffCandidate(source,unit,true,id) end
                    if candidate and candidate.creation then
                        candidate.spellID=id;candidate.action={type="spell",spell=id}
                    end
                    add(candidate)
                end
            else
                add({key=source and source.key or group.key,name=group.name,spellID=id,unit=unit,action=self:CombatSpellAction(group,unit,id,scope)})
            end
        end
    end
    table.sort(result,function(a,b)return a.combatPosition<b.combatPosition end)
    return result
end
function F:FrameOutOfCombatCandidates(unit,kind,combatCandidates,cleanup,previewProfile)
    local result=cleanup or {}
    local profile=previewProfile or self:CombatScopeFor(unit,kind)
    if not previewProfile and (kind=='target' or kind=='focus') then
        local friendly=UnitIsFriend('player',unit)
        if not (issecretvalue and issecretvalue(friendly)) and friendly then profile=kind..'Friendly' end
        if profile==kind and UnitCanAttack then
            local hostile=UnitCanAttack('player',unit)
            if (issecretvalue and issecretvalue(hostile)) or not hostile then return result end
        end
    end
    local dead=UnitIsDeadOrGhost(unit)
    if issecretvalue and issecretvalue(dead) then return result end
    local recoveryPositions,types
    if cleanup then
        recoveryPositions={}
        for _,candidate in ipairs(cleanup) do recoveryPositions[candidate.combatPosition]=true end
    end
    for _,candidate in ipairs(combatCandidates or self:BuildCombatCandidates(unit,kind,false,profile)) do
        if candidate.showOutOfCombat and candidate.profile==profile and (candidate.allowDead==true)==(dead==true)
            and not (recoveryPositions and recoveryPositions[candidate.combatPosition]) then
            local allowed=candidate.creatureTargets
            local kind
            if allowed and not previewProfile then
                types=types or {}
                kind=self:CombatCreatureType(unit,types)
            end
            if not kind or allowed[kind] then
                local copy=self:CopySettings(candidate)
                copy.outOfCombat=true
                result[#result+1]=copy
            end
        end
    end
    return result
end
function F:ReportCombatSetup()
    self:Print("v"..self.version.." combat mode "..(self.db.combatClicks and "enabled"or "disabled").."; combat "..(InCombatLockdown()and "active"or "inactive")..".")
    self:Print("Duel mode "..(self:IsDuelCombat() and "active" or "inactive")..".")
    local overlay=self.overlays[PlayerFrame]
    local icons=overlay and overlay.combatLayout and overlay.combatLayout.displayOrder or {}
    for _,icon in ipairs(icons)do
        self:Print(icon.buffName.."; position="..icon.combatPosition.."; "..(icon.combatModifier and icon.combatModifier:upper()or "direct click").."; prepared="..(icon.buffSpellID or "item")..".")
    end
    self:Print("Prepared self combat icons: "..#icons..". SHIFT / CTRL / ALT use configuration rows 1 / 2 / 3; visible icons pack together. Ordinary queues are out of combat only.")
end
