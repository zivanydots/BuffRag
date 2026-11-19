local _,F=...
local function public(value)return not(issecretvalue and issecretvalue(value))end
function F:GCDSeconds()
    if C_Spell.GetSpellCooldown then
        local ok,info=pcall(C_Spell.GetSpellCooldown,61304)
        if ok and public(info) and info and public(info.duration) and type(info.duration)=="number"and info.duration>0 and info.duration<=2.5 then return info.duration end
    end
    local _,class=UnitClass("player")
    local power=UnitPowerType and UnitPowerType("player")
    if class=="ROGUE"or power==3 then return 1 end
    local ok,haste=pcall(function()return UnitSpellHaste and UnitSpellHaste("player")or 0 end)
    return ok and public(haste)and type(haste)=="number"and math.max(1,1.5/(1+haste/100))or 1.5
end
function F:CreateCombatCooldown(button)
    local cooldown=CreateFrame("Cooldown",nil,button.visual,"CooldownFrameTemplate")
    cooldown:SetAllPoints(button.visual);cooldown:EnableMouse(false)
    if cooldown.SetDrawEdge then cooldown:SetDrawEdge(true)end
    if cooldown.SetDrawBling then cooldown:SetDrawBling(false)end
    if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(true)end
    button.cooldown=cooldown
end
function F:UpdateCombatCooldown(button,preview)
    local cooldown=button.cooldown
    if not cooldown then return end
    if button.cooldownGeneration==(self.cooldownGeneration or 0)then return end
    button.cooldownGeneration=self.cooldownGeneration or 0
    if not button.combatOnly or(not InCombatLockdown()and not preview and not button.cleanupOnly and not button.outOfCombat)then if cooldown.Clear then pcall(cooldown.Clear,cooldown)end;return end
    if button.activeCastGUID then
        local fn=button.activeChannel and UnitChannelDuration or UnitCastingDuration
        if fn and cooldown.SetCooldownFromDurationObject then
                                                                               
            local ok=pcall(function()cooldown:SetCooldownFromDurationObject(fn(button.pet and "pet"or "player"))end)
            if ok then return end
        end
    end
    if button.pet and self:PetSpellSlotMatches(button)and C_SpellBook.GetSpellBookItemCooldownDuration and cooldown.SetCooldownFromDurationObject then
        local ok=pcall(function()cooldown:SetCooldownFromDurationObject(C_SpellBook.GetSpellBookItemCooldownDuration(button.petSlot,button.petBank))end)
        if ok then return end
    end
    local source=button.castFeedbackSource or {}
    if source.itemID and C_Item.GetItemCooldown then
        local ok,start,duration=pcall(C_Item.GetItemCooldown,source.itemID)
                                                                                    
        if ok and (not public(duration)or(type(duration)=="number"and duration>0))then
            if pcall(cooldown.SetCooldown,cooldown,start,duration)then return end
        end
    end
    local id=source.spellID
    if not id then for effect in pairs(button.castFeedbackIDs or {})do id=effect;break end end
    id=id or 61304
    if C_Spell.GetSpellCooldownDuration and cooldown.SetCooldownFromDurationObject then
        local ok=pcall(function()cooldown:SetCooldownFromDurationObject(C_Spell.GetSpellCooldownDuration(id))end)
        if ok then return end
    end
    local ok,info=pcall(C_Spell.GetSpellCooldown,id)
    if ok and public(info)and info and public(info.startTime)and public(info.duration)and type(info.startTime)=="number"and type(info.duration)=="number"then
        pcall(cooldown.SetCooldown,cooldown,info.startTime,info.duration)
    elseif cooldown.Clear then pcall(cooldown.Clear,cooldown)end
end
