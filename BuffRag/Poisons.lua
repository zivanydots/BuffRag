local _, F = ...
local function public(value) return not (issecretvalue and issecretvalue(value)) end
F.handChoices={{"Choose hand","none"},{"Main hand","main"},{"Off hand","off"},{"Both hands","both"}}
function F:UpdatePoisonHandLabel(icon)
    if not icon.handLabel then
        icon.handLabel=icon.visual:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        icon.handLabel:SetPoint("BOTTOM",icon.visual,"TOP",0,1)
        icon.handLabel:SetTextColor(1,.82,0)
    end
    icon.handLabel:SetText(icon.poison and (icon.weaponSlot==17 and "O" or "M") or "")
    icon.handLabel:SetShown(icon.poison==true)
end
function F:PoisonItem(entry)
    local carried
    for _,id in ipairs(entry.poisonItems) do
        if self:CustomItemCount(id)>0 then
            carried=carried or id
            local usable=not C_Item.IsUsableItem or C_Item.IsUsableItem(id)
            if public(usable) and usable then return id,true end
        end
    end
    if carried then return carried,false end
                                                                                
    for index,id in ipairs(entry.ids) do
        local _,learned=self:LearnedSpell({id})
        if learned then return entry.poisonItems[index],false end
    end
    return entry.poisonItems[1],false
end
function F:PoisonAvailable(entry)
    if self.db and self.db.knownPoisons[entry.key] then return true end
    for _,id in ipairs(entry.poisonItems) do
        if self:CustomItemCount(id)>0 then
            local usable=not C_Item.IsUsableItem or C_Item.IsUsableItem(id)
            if self.db and public(usable) and usable then self.db.knownPoisons[entry.key]=true end
            return true
        end
    end
    local _,id=self:LearnedSpell(entry.ids)
    if id then return true end
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
        for _,recipe in ipairs(entry.ids) do
            local ok,info=pcall(C_TradeSkillUI.GetRecipeInfo,recipe)
            if ok and info and info.learned then
                if self.db then self.db.knownPoisons[entry.key]=true end
                return true
            end
        end
    end
    return false
end
function F:SetPoisonHand(key,hand)
    local entry=self.spells[key]
    if InCombatLockdown() or not entry or entry.kind~="poison" or not self:BuffAvailable(entry) then return end
    if hand~="main" and hand~="off" and hand~="both" then hand=nil end
                                                                             
    self.db.poisonHands[key]=hand
    self:Refresh()
end
function F:PoisonCandidate(entry,unit,prepare,preparedSlot)
    if not self:IsSelf(unit) then return end
    local hand=self.db.poisonHands[entry.key]
    local slot
    for _,candidate in ipairs(hand=="both" and {16,17} or (hand=="main" and {16} or (hand=="off" and {17} or {}))) do
        local weapon=GetInventoryItemID("player",candidate)
        local location
        if weapon and C_Item.GetItemInfoInstant then
            local _,_,_,equipLocation=C_Item.GetItemInfoInstant(weapon); location=equipLocation
        end
        if weapon and location~="INVTYPE_SHIELD" and location~="INVTYPE_HOLDABLE"
            and (not preparedSlot or candidate==preparedSlot) and (prepare or not self:WeaponImbued(candidate)) then slot=candidate; break end
    end
    if not slot then return end
    local item,usable=self:PoisonItem(entry)
    local count=self:CustomItemCount(item)
    local action=usable and count>0 and {type="macro",macrotext="/use item:"..item.."\n/use "..slot} or {type=""}
    return {key=entry.key,name=entry.label,itemID=item,customItem=item,poison=true,weaponSlot=slot,unit="player",queue=true,
        ready=usable and count>0 and self:BagItemReady(item),action=action}
end
