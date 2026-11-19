local _,F=...
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
    if not InCombatLockdown()and not frame.cleanupMode then return end
    local mod,count=nil,0
    for _,pair in ipairs({{"shift",IsShiftKeyDown},{"ctrl",IsControlKeyDown},{"alt",IsAltKeyDown}})do
        if pair[2] and pair[2]()then mod=pair[1];count=count+1 end
    end
    if count==1 then
        local buttons=frame.combatButtons
        if InCombatLockdown()and frame:GetAttribute('dual-profile')then buttons=frame.combatButtonsByRelation and frame.combatButtonsByRelation[frame:GetAttribute('state-relation')or 'enemy']end
        frame.feedbackCombatButton=buttons and buttons[mod]
        if frame.feedbackCombatButton then self:BeginIconCast(frame.feedbackCombatButton,mouse,down)end
    end
end
function F:EndFrameCombatCast(frame,mouse,down)
    if frame.feedbackCombatButton then self:EndIconCast(frame.feedbackCombatButton,mouse,down)end
    frame.feedbackCombatButton=nil
end
function F:BuildCombatCandidates(unit,context,preview,profile)
    local result={}
    if not self.db.combatClicks and not preview then return result end
    local scope=profile or self:CombatScopeFor(unit,context)
    local rows=self:CombatRowsForScope(scope)
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
        elseif group and group.learned and (not group.pet or group.available) and row.frame.enabled then
            local id=self:CombatChosenRank(group,scope,true)
            local function add(candidate,extra)
                if not candidate then return end
                candidate.combatOnly=true;candidate.queue=false;candidate.prioritySelected=false
                candidate.combatModifier=not extra and row.modifier or nil
                candidate.combatPosition=row.combatPosition+(extra and .001 or 0)
                candidate.profile=scope;candidate.effects=candidate.itemID and self:ItemCategory({id=candidate.itemID})or self:ActionMetadata(id)
                candidate.dispelReminders=row.frame.dispelReminders~=false
                candidate.pet=group.pet;candidate.petSlot=group.petSlot;candidate.petBank=group.petBank
                if group.pet then for _,rank in ipairs(group.ranks)do if rank.id==id then candidate.petSlot,candidate.petBank=rank.petSlot,rank.petBank end end end
                candidate.targetRule=(unit=="target"or unit=="focus")and(scope:find('Friendly',1,true)and 'friendly'or 'enemy')or nil
                candidate.allowDead=group.deadTarget
                candidate.combatRes=group.deadTarget and (id==20484 or id==20739 or id==20742 or id==20747 or id==20748)
                result[#result+1]=candidate
            end
            local source=group.source
            if source and source.kind then
                if source.kind=="poison" and self.db.poisonHands[source.key]=="both"then
                    add(self:PoisonCandidate(source,unit,true,16))
                    add(self:PoisonCandidate(source,unit,true,17),true)
                else
                    local candidate=source.created and self:CreatedItemCandidate(source,false,true,id)or self:BuffCandidate(source,unit,true)
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
function F:ReportCombatSetup()
    self:Print("v"..self.version.." combat mode "..(self.db.combatClicks and "enabled"or "disabled").."; combat "..(InCombatLockdown()and "active"or "inactive")..".")
    local overlay=self.overlays[PlayerFrame]
    local icons=overlay and overlay.combatLayout and overlay.combatLayout.displayOrder or {}
    for _,icon in ipairs(icons)do
        self:Print(icon.buffName.."; position="..icon.combatPosition.."; "..(icon.combatModifier and icon.combatModifier:upper()or "direct click").."; prepared="..(icon.buffSpellID or "item")..".")
    end
    self:Print("Prepared self combat icons: "..#icons..". SHIFT / CTRL / ALT use configuration rows 1 / 2 / 3; visible icons pack together. Ordinary queues are out of combat only.")
end
