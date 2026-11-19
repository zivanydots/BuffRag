local _, F = ...
local function public(value) return not (issecretvalue and issecretvalue(value)) end
local _, playerClass = UnitClass("player")
F.class = playerClass
F.catalogue = F.classCatalogues[playerClass] or {{key="items",label="Pots / Items",ids={},kind="items",default=true}}
F.spells = {}
F.abilityFamilies={}
for _,entry in ipairs(F.allClassCatalogues[playerClass] or {}) do F.abilityFamilies[entry.key]=entry end
F.defaults.priority, F.defaults.selfPriority, F.defaults.targetScopes, F.defaults.buffs = {}, {}, {}, {}
F.defaults.class, F.defaults.schema = playerClass, 6
F.defaults.keepStones = {soul=false,fire=false,spell=false,health=false}
F.defaults.keepCreated = {}
F.defaults.poisonHands = {}
F.defaults.knownPoisons = {}
F.defaults.manaGemMana = 25
F.defaults.priorityModifier = "ctrl"
F.defaults.priorityBuffs = {}
F.defaults.standardQueue = {}
F.defaults.buffEnabled = {}
F.defaults.combatBuffs = {}
for _, entry in ipairs(F.catalogue) do
    F.spells[entry.key] = entry
    table.insert(F.defaults.priority, entry.key)
    table.insert(F.defaults.selfPriority, entry.key)
    local enabled = entry.default == true and not entry.passive
    F.defaults.targetScopes[entry.key] = {self=enabled,party=enabled and not entry.selfOnly,raid=enabled and not entry.selfOnly,target=false,focus=false}
    F.defaults.buffs[entry.key] = enabled
    F.defaults.priorityBuffs[entry.key] = false
    F.defaults.standardQueue[entry.key] = true
    F.defaults.buffEnabled[entry.key] = true
    F.defaults.combatBuffs[entry.key] = false
end
F.defaults.buffTargets = {self=true,group=true}

function F:NormalizeSelfPriority(order)
    local result, seen = {}, {}
    for _, source in ipairs({type(order)=="table" and order or {}, self.defaults.priority}) do
        for _, key in ipairs(source) do
            if self.spells[key] and not seen[key] then result[#result+1]=key; seen[key]=true end
        end
    end
    return result
end
local normalizeItems = F.NormalizeItems
function F:NormalizeItems(items)
    local result = normalizeItems(self, items)
    local original = {}
    for _, item in ipairs(type(items)=="table" and items or {}) do
        if type(item)=="table" and tonumber(item.id) then original[tonumber(item.id)]=item end
    end
    for _, item in ipairs(result) do
        local old=original[item.id] or {}
        item.self = old.self ~= false
        item.party, item.raid = old.party == true, old.raid == true
        item.target = old.target == true
        item.focus = old.focus == true
        item.prioritySelected = old.prioritySelected == true
        item.combat = old.combat == true
        item.useOn=({auto=true,self=true,friendly=true,enemy=true,either=true})[old.useOn]and old.useOn or 'auto'
        item.cleanupRole=({auto=true,none=true,healing=true,cleansing=true})[old.cleanupRole]and old.cleanupRole or 'auto'
        item.cleanseTypes={}
        for _,kind in ipairs({'Magic','Curse','Disease','Poison','Enrage'})do item.cleanseTypes[kind]=type(old.cleanseTypes)=='table'and old.cleanseTypes[kind]==true or nil end
        item.dispelReminders=old.dispelReminders~=false
        item.cleanseOverride=old.cleanseOverride==true
    end
    return result
end
function F:UpgradeSettings(settings)
    if type(settings)~="table" then settings={} end
    if type(settings.keepStones)~="table" then settings.keepStones={} end
    -- v0.1.0 stored keep-stock choices as separate priority rows. Preserve
    -- their switches, then retire those rows instead of creating twice.
    local oldScopes=type(settings.targetScopes)=="table" and settings.targetScopes or {}
    if self.class=="MAGE" and type(oldScopes.frostArmor)=="table" and oldScopes.frostArmor.self then
        oldScopes.iceArmor=oldScopes.iceArmor or {}; oldScopes.iceArmor.self=true
        if type(settings.priorityBuffs)=="table" and settings.priorityBuffs.frostArmor then settings.priorityBuffs.iceArmor=true end
    end
    for oldKey,kind in pairs({stockSoul="soul",stockFire="fire",stockSpell="spell",stockHealth="health"}) do
        if (not settings.schema or settings.schema<2) and type(oldScopes[oldKey])=="table" and oldScopes[oldKey].self then
            settings.keepStones[kind]=true
        end
        oldScopes[oldKey]=nil
        if type(settings.buffs)=="table" then settings.buffs[oldKey]=nil end
    end
    if settings.class and settings.class~=self.class then
        settings.priority, settings.selfPriority, settings.targetScopes = nil,nil,nil
    end
    local function fill(target, source)
        for key,value in pairs(source) do
            if type(value)=="table" then
                if type(target[key])~="table" then target[key]={} end
                fill(target[key],value)
            elseif target[key]==nil then target[key]=value end
        end
    end
    fill(settings, self.defaults)
    if not settings.combatMatrixVersion then
        for key,enabled in pairs(settings.combatBuffs or {}) do
            if enabled and self.abilityFamilies[key] then
                local targets={}
                for _,scope in ipairs({"self","party","raid","target","focus"}) do targets[scope]=oldScopes[key] and oldScopes[key][scope]==true or false end
                settings.combatRows["family:"..key]={enabled=true,targets=targets}
            end
        end
        settings.combatMatrixVersion=1
    end
    settings.class, settings.schema = self.class, 6
    if settings.targetPlacement~="right" and settings.targetPlacement~="top" then settings.targetPlacement="right" end
    for _,key in ipairs({"healthstoneSeparate","healthstoneSize","healthstonePlacement","healthstoneAlign","healthstoneOffset","healthstoneVertical","healthstoneHealth"}) do
        settings[key]=nil
    end
    if settings.priorityModifier~="ctrl" and settings.priorityModifier~="alt" and settings.priorityModifier~="shift" and settings.priorityModifier~="off" then
        settings.priorityModifier="ctrl"
    end
    if self.class=="MAGE" and type(settings.priority)=="table" then
        for index,key in ipairs(settings.priority) do if key=="frostArmor" then settings.priority[index]="iceArmor" end end
    end
    settings.priority=self:NormalizeSelfPriority(settings.priority)
    settings.selfPriority=self:CopySettings(settings.priority)
    settings.items=self:NormalizeItems(settings.items)
    for _,key in ipairs(settings.priority) do
        local hand=settings.poisonHands[key]
        if self.spells[key].kind~="poison" or (hand~="main" and hand~="off" and hand~="both") then settings.poisonHands[key]=nil
        end
    end
    for _,map in ipairs({settings.targetScopes,settings.priorityBuffs,settings.standardQueue,settings.buffEnabled,settings.buffs,settings.combatBuffs}) do
        for key in pairs(map) do if not self.spells[key] then map[key]=nil end end
    end
    for _,entry in ipairs(self.catalogue) do
        settings.combatBuffs[entry.key]=settings.combatBuffs[entry.key]==true
        settings.standardQueue[entry.key]=settings.standardQueue[entry.key]~=false
        local scopes=settings.targetScopes[entry.key]
        for _,scope in ipairs({"self","party","raid","target","focus"}) do scopes[scope]=scopes[scope]==true end
        if entry.selfOnly then scopes.party,scopes.raid,scopes.target,scopes.focus=false,false,false,false end
        if entry.passive then scopes.self,scopes.party,scopes.raid,scopes.target,scopes.focus=false,false,false,false,false end
    end
    return settings
end
function F:BuffRowEnabled(key)
    if key=="items" then return self.db.itemsEnabled end
    return self.db.buffEnabled[key]~=false
end
function F:SetBuffEnabled(key,enabled)
    if InCombatLockdown() or not self:BuffAvailable(self.spells[key]) then return end
    if key=="items" then self.db.itemsEnabled=enabled==true
    else self.db.buffEnabled[key]=enabled==true end
    self:Refresh()
end
function F:SetBuffQueue(key,enabled)
    local entry=self.spells[key]
    if InCombatLockdown() or not self:BuffAvailable(entry) or entry.kind=="items" or entry.manual then return end
    self.db.standardQueue[key]=enabled==true
    self:Refresh()
end
function F:SetBuffScope(key,scope,enabled)
    if InCombatLockdown() or not self.spells[key] then return end
    local entry=self.spells[key]
    if entry.kind=="items" or not self:BuffAvailable(entry) or (entry.selfOnly and scope~="self") then return end
    if scope~="self" and scope~="party" and scope~="raid" and scope~="target" and scope~="focus" then return end
    self.db.targetScopes[key][scope]=enabled==true
    self:Refresh()
end
function F:BuffAvailable(entry)
    if not entry or entry.passive then return false end
    if entry.kind=="items" then return true end
    if entry.kind=="poison" then return self:PoisonAvailable(entry) end
    local _,id=self:LearnedSpell(entry.ids)
    return id~=nil and not (C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(id))
end
function F:SetBuffPriority(key,enabled)
    local entry=self.spells[key]
    if InCombatLockdown() or not self:BuffAvailable(entry) or entry.kind=="items" or entry.manual then return end
    self.db.priorityBuffs[key]=enabled==true
    self:Refresh()
end
function F:SetBuffCombat(key,enabled)
    local entry=self.spells[key]
    if InCombatLockdown() or not self:BuffAvailable(entry) or entry.kind=="items" then return end
    self.db.combatBuffs[key]=enabled==true
    self:Refresh()
end
function F:SetCombatTooltip(check)
    check:SetScript("OnEnter",function()
        GameTooltip:SetOwner(check,"ANCHOR_RIGHT"); GameTooltip:SetText("Combat")
        GameTooltip:AddLine("Keep a fixed clickable item icon during combat. If no Self, Party, Raid, Target or Focus frame is selected, it appears on Self in combat only. Independent of Queue and Bypass Q. Prepared before combat; normal item-use rules apply.",.8,.8,.8,true)
        GameTooltip:Show()
    end)
    check:SetScript("OnLeave",function() GameTooltip:Hide() end)
end
function F:QueueHelp()
    local modifier=self.db.frameModifier
    local action=modifier=="off" and "Frame modifier is disabled in Settings."
        or "Hold "..modifier:upper().." and left-click a unit frame to apply the next eligible entry."
    return "Include in the standard queue, in list order. "..action
end
function F:PriorityHelp()
    local modifier=self.db.priorityModifier
    local action=modifier=="off" and "Frame modifier is disabled in Settings."
        or "Hold "..modifier:upper().." and left-click a unit frame to use it."
    return "Include in Bypass Q. "..action.." Uses only Bypass Q entries in list order, overriding the standard Queue."
end
function F:TableUsageHelp(kind)
    local normal=self.db.frameModifier~="off" and self.db.frameModifier:upper() or "disabled"
    local priority=self.db.priorityModifier~="off" and self.db.priorityModifier:upper() or "disabled"
    if kind=="items" then
        return "Items follow their listed order at the Pots / Items position in Buffs. Targets show icons. Queue includes an item in the standard queue ("..normal.."); Bypass Q includes it in the independent bypass queue ("..priority.."). Leave both off for manual icon use. Bindings/modifiers are in Settings."
    end
    return "Targets show buff icons. Queue selects the standard queue ("..normal.."); Bypass Q selects the independent bypass queue ("..priority.."). Both follow list order. Leave both off to choose individual icons manually. Bindings/modifiers are in Settings; items are in Pots / Items. Unlearned spells are disabled."
end
function F:KeepsEntry(entry)
    return (entry.stone and self.db.keepStones[entry.stone]) or (entry.keepKey and self.db.keepCreated[entry.keepKey]) or false
end
function F:SetKeepInBag(key,enabled)
    local entry=self.spells[key]
    if InCombatLockdown() or not entry or not self:BuffAvailable(entry) then return end
    if entry.stone then self.db.keepStones[entry.stone]=enabled==true
    elseif entry.keepKey then self.db.keepCreated[entry.keepKey]=enabled==true
    else return end
    self:Refresh()
end
function F:MoveBuff(index,direction)
    if InCombatLockdown() or (direction~=-1 and direction~=1) then return end
    local order=self.db.priority
    if not self:BuffAvailable(self.spells[order[index]]) then return end
    if order[index] and order[index+direction] then
        order[index],order[index+direction]=order[index+direction],order[index]
        self.db.selfPriority=self:CopySettings(order)
        self:Refresh()
    end
end
function F:ScopeFor(unit,context)
    if context=="target" or unit=="target" then return "target" end
    if context=="focus" or unit=="focus" then return "focus" end
    if self:IsSelf(unit) then return "self" end
    if context then return context=="raid" and "raid" or "party" end
    return IsInRaid() and "raid" or "party"
end
function F:EntryEnabled(key,unit,context)
    if not self:BuffRowEnabled(key) then return false end
    local entry=self.spells[key]
    if entry and entry.kind=="items" then return true end -- each item owns its target choices
    local scope=self:ScopeFor(unit,context)
    local targets=self.db.targetScopes[key]
    return entry and not entry.passive and targets and targets[scope] and (not entry.selfOnly or scope=="self")
end
function F:BuildSpellCache()
    if not self.spellCacheDirty and self.spellCache then return end
    self.spellCache, self.spellCacheDirty = {}, false
    local book=C_SpellBook
    if not (book and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo and book.GetSpellBookItemInfo) then return end
    local bank=Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local learnedType=Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1
    for line=1,book.GetNumSpellBookSkillLines() do
        local info=book.GetSpellBookSkillLineInfo(line)
        if info then
            for slot=info.itemIndexOffset+1,info.itemIndexOffset+info.numSpellBookItems do
                local item=book.GetSpellBookItemInfo(slot,bank)
                local id=item and item.spellID
                if id and item.itemType==learnedType and not item.isOffSpec and not item.isUnlearned and not (book.IsSpellBookItemPassive and book.IsSpellBookItemPassive(slot,bank)) then
                    local spell=C_Spell.GetSpellInfo(id)
                    if spell then
                        local rank=C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id) or ""
                        local score=tonumber(rank:match("%d+")) or 0
                        local old=self.spellCache[spell.name]
                        if not old or score>=old.score then self.spellCache[spell.name]={id=id,score=score} end
                    end
                end
            end
        end
    end
end
function F:LearnedSpell(ids)
    self:BuildSpellCache()
    for _,id in ipairs(ids) do
        local info=C_Spell.GetSpellInfo(id)
        if info then
            local cached=self.spellCache[info.name]
            if cached then return info.name,cached.id end
            local known=(IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id))
            if not known and C_SpellBook and C_SpellBook.IsSpellKnown then known=C_SpellBook.IsSpellKnown(id,Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0) end
            if known then return info.name,id end
        end
    end
end
function F:Spell(key)
    local entry=self.spells[key]
    if not entry then return end
    local name,id=self:LearnedSpell(entry.ids)
    return name,nil,id
end
function F:FamilyActive(entry,unit)
    local ids,names={},{}
    for _,source in ipairs({entry.ids,entry.auraIDs or {}}) do
        for _,id in ipairs(source) do
            ids[id]=true
            local info=C_Spell.GetSpellInfo(id)
            if info then names[info.name]=true end
        end
    end
    for index=1,255 do
        local ok,aura=pcall(C_UnitAuras.GetAuraDataByIndex,unit,index,"HELPFUL")
        if not ok or not public(aura) then return true end
        if not aura then break end
        if not public(aura.name) or not public(aura.spellId) then return true end
        if ids[aura.spellId] or names[aura.name] then return true end
    end
    return false
end
function F:SpellReady(id)
    if C_Spell.GetSpellCooldown then
        local cooldown=C_Spell.GetSpellCooldown(id)
        if not public(cooldown) then return false end
        if cooldown then
            if not public(cooldown.startTime) or not public(cooldown.duration) then return false end
            if cooldown.duration and cooldown.duration>1.5 and cooldown.startTime+cooldown.duration>GetTime() then return false end
        end
    end
    if C_Spell.IsSpellUsable then
        local usable=C_Spell.IsSpellUsable(id)
        if not public(usable) or not usable then return false end
    end
    return true
end
function F:WeaponImbued(inventorySlot)
    inventorySlot=inventorySlot or 16
    -- Forever has separate imbue and temporary-enchant channels. An oil or
    -- sharpening stone must not hide a missing class imbue.
    local types=Enum and Enum.ItemEnchantType
    local slots=Enum and Enum.WeaponSlot
    if C_Item.GetWeaponEnchantInfo and types and types.Imbue~=nil and slots and slots.MainHand~=nil then
        local weaponSlot=inventorySlot==17 and slots.OffHand or slots.MainHand
        if weaponSlot==nil then return true end
        local list=C_Item.GetWeaponEnchantInfo(weaponSlot)
        if not public(list) or type(list)~="table" then return true end -- unknown: preserve
        for _,enchant in ipairs(list) do
            if not public(enchant) or not public(enchant.hasEnchant) or not public(enchant.enchantType) then return true end
            if enchant.hasEnchant and enchant.enchantType==types.Imbue then
                if not public(enchant.timeLeft) or enchant.timeLeft==nil or enchant.timeLeft>0 then return true end
            end
        end
        return false
    end
    if not GetWeaponEnchantInfo then return true end
    local main,_,_,_,off=GetWeaponEnchantInfo()
    local enchanted=main
    if inventorySlot==17 then enchanted=off end
    return not public(enchanted) or enchanted
end
function F:CreatedItemCandidate(entry,keepOnly,prepare,chosenRank)
    local name,id=self:LearnedSpell(entry.ids)
    if chosenRank then id=chosenRank;local info=C_Spell.GetSpellInfo(id);name=info and info.name end
    if not id or (C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(id)) then return end
    local items=entry.created[id]
    if not items then return end -- no guessed item mapping for an unknown rank
    local carried
    for _,item in ipairs(items) do
        local count=C_Item.GetItemCount(item,false,true)
        if not public(count) then return end
        if count>0 then carried=item; break end
    end
    if not carried or (prepare and entry.stockOnly) then
        return {key=entry.key,name=name,spellID=id,unit="player",creation=true,stockOnly=entry.stockOnly or keepOnly,ready=self:SpellReady(id),queue=true,
            action={type="spell",spell=id}}
    end
    if entry.stockOnly or keepOnly then return end
    local ready=self:BagItemReady(carried)
    if entry.resource=="mana" then
        local power=Enum and Enum.PowerType and Enum.PowerType.Mana or 0
        local current=UnitPower("player",power)
        local maximum=UnitPowerMax("player",power)
        ready=ready and public(current) and public(maximum) and maximum>0 and current*100/maximum<self.db.manaGemMana
    end
    return {key=entry.key,name=(C_Item.GetItemNameByID and C_Item.GetItemNameByID(carried)) or entry.label,
        itemID=carried,unit="player",consumable=true,ready=ready,queue=true,action={type="item",item="item:"..carried}}
end
function F:BuffCandidate(entry,unit,prepare)
    if entry.kind=="poison" then return self:PoisonCandidate(entry,unit,prepare) end
    if entry.created then return self:CreatedItemCandidate(entry,false,prepare) end
    local name,id=self:LearnedSpell(entry.ids)
    if not id or entry.passive or (C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(id)) then return end
    local kind=entry.kind
    if not prepare and (entry.cooldownLimited or entry.singleRecipient or entry.hideOnCooldown) and not self:SpellReady(id) then return end
    if not prepare and entry.singleRecipient and self:SingleRecipientActive(entry) then return end
    local result={key=entry.key,name=name,spellID=id,unit=unit,ready=prepare or self:SpellReady(id),queue=not entry.manual}
    result.manualRecipient=entry.singleRecipient==true
    if kind=="tracking" then
        if not prepare and self:Tracking(name) then return end
    elseif kind=="totem" then
        local have=GetTotemInfo(entry.slot)
        if not prepare and (not public(have) or have) then return end -- preserve any totem in this slot
    elseif kind=="weapon" or kind=="stoneWeapon" then
        if not GetInventoryItemID("player",16) then return end
        if not prepare and self:WeaponImbued() then return end -- preserve an existing class imbue
        if kind=="stoneWeapon" then
            local item=self:CarriedStone(entry.key)
            if item then result.itemID,result.weaponItem=item,item; result.spellID=nil; result.ready=self:ItemReady(item)
            else result.creation=true; result.unit="player" end
        end
    elseif kind=="stoneConsumable" then
        local item=self:CarriedStone(entry.stone)
        if item then
            result.itemID,result.spellID=item,nil
            result.consumable=true
            result.ready=self:ItemReady(item)
        else
            result.creation=true
        end
    elseif kind=="soul" then
        if not prepare and self:FamilyActive(entry,unit) then return end
        local item=self:CarriedStone("soul")
        if item then
            -- Soulstone is a long-cooldown recipient choice, not a reminder
            -- to reapply to every missing target while its use is unavailable.
            if not prepare and not self:ItemReady(item) then return end
            result.itemID,result.spellID=item,nil; result.ready=true
        else result.creation=true; result.unit="player" end
    elseif not prepare and not entry.manual and not entry.cooldownLimited and not entry.singleRecipient and self:FamilyActive(entry,unit) then return end
    result.stoneKind=entry.stone
    if result.itemID then result.name=(C_Item.GetItemNameByID and C_Item.GetItemNameByID(result.itemID)) or entry.label end
    if result.weaponItem then
        result.action={type="macro",macrotext="/use item:"..result.itemID.."\n/use 16"}
    elseif result.itemID then
        result.action=self:IsSelf(result.unit) and {type="item",item="item:"..result.itemID}
            or {type="macro",macrotext=self:TargetMacro(result.unit,nil,result.itemID)}
    elseif self:IsSelf(result.unit) then result.action={type="spell",spell=id}
    else result.action={type="macro",macrotext=self:TargetMacro(result.unit,id)} end
    return result
end
function F:CandidateForEntry(entry,unit,context)
    if not self:BuffRowEnabled(entry.key) then return end
    local candidate
    if self:EntryEnabled(entry.key,unit,context) then candidate=self:BuffCandidate(entry,unit) end
    if not candidate and context~="target" and context~="focus" and entry.created and self:IsSelf(unit) and self:KeepsEntry(entry) then
        return self:CreatedItemCandidate(entry,true)
    end
    if not candidate and context~="target" and context~="focus" and entry.stone and self:IsSelf(unit) and self:KeepsEntry(entry)
        and not self:CarriedStone(entry.stone) then
        local name,id=self:LearnedSpell(entry.ids)
        if id then
            candidate={key=entry.key,name=name,spellID=id,unit="player",creation=true,stockOnly=true,stoneKind=entry.stone,
                ready=self:SpellReady(id),queue=true,action={type="spell",spell=id}}
        end
    end
    return candidate
end
function F:BuildCandidates(unit,context)
    local result={}
    local scope=self:ScopeFor(unit,context)
    for index,key in ipairs(self.db.priority) do
        local entry=self.spells[key]
        if self:BuffRowEnabled(key) and (self:EntryEnabled(key,unit,context) or (scope=="self" and self:KeepsEntry(entry))) then
            if entry.kind=="items" then
                if self.db.itemsEnabled then
                    for itemIndex,item in ipairs(self.db.items) do
                        local profile=(scope=='target'or scope=='focus')and scope..'Friendly'or scope
                        if item.enabled and item[scope]and self:ItemTargetAllowed(self:ItemCategory(item),unit,profile)then
                            local data=self:CustomItemData(item.id,unit)
                            if not data.buffActive then
                                local action=self:ItemAction(item,unit,profile)
                                if not data.usable then action={type=""} end
                                result[#result+1]={key="items",name=data.name,itemID=item.id,customItem=item.id,itemIndex=itemIndex,
                                    score=index+itemIndex/(itemIndex+1),unit=unit,action=action,ready=data.ready,queue=item.queue,
                                    prioritySelected=item.prioritySelected==true}
                            end
                        end
                    end
                end
            else
                local candidate=self:CandidateForEntry(entry,unit,context)
                if candidate then
                    candidate.queue=candidate.queue and self.db.standardQueue[key]~=false
                    candidate.score=index
                    candidate.prioritySelected=self.db.priorityBuffs[key]==true and not entry.manual
                    result[#result+1]=candidate
                end
            end
        end
    end
    return result
end
function F:SelfActionScore(key,extra)
    for index,value in ipairs(self.db.priority) do
        if value==key then return index+(key=="items" and (extra.itemIndex or 1)/((extra.itemIndex or 1)+1) or 0) end
    end
    return 999
end
function F:IndicatorCapacity()
    return math.max(self.maxIndicators,#self.catalogue+#self.db.items)
end
function F:Refresh()
    if self.db then self:SyncMinimapVisibility() end
    if not self.db or InCombatLockdown() then return end
    self.dispelSnapshots={}
    if self:UpdateAddonConflictPause() then self:SuspendForAddonConflict(); return end
    self:BuildSpellCache()
    self:DiscoverCombatSpells()
    self:RefreshItemBuffs()
    self:RefreshSingleRecipientBuffs()
    self:Discover()
    self.selfAction,self.selfPriorityAction=nil,nil
    for frame,overlay in pairs(self.overlays) do
        local unit=(overlay.frameKind=="target"or overlay.frameKind=="focus") and overlay.frameKind or (frame==PlayerFrame and "player" or frame.unit or frame:GetAttribute("unit"))
        local click=overlay.click
        if overlay.frameKind=="target"or overlay.frameKind=="focus" then
            local watched=overlay.frameKind
            local driver=(self.db.combatClicks and ("[combat,@"..watched..",exists] show; [combat] hide; ") or "[combat] hide; ").."[@"..watched..",exists,help] show; hide"
            if overlay.targetDriver~=driver then RegisterStateDriver(overlay.indicators,"visibility",driver); overlay.targetDriver=driver end
        end
        local modifier=self.db.frameModifier
        if modifier~="shift" and modifier~="ctrl" and modifier~="alt" then modifier=nil end
        local priorityModifier=self.db.priorityModifier
        if priorityModifier~="shift" and priorityModifier~="ctrl" and priorityModifier~="alt" then priorityModifier=nil end
        local driver="hide"
        if self.db.enabled and not self.testUI and (modifier or priorityModifier) then
            driver="[combat] hide; "..(modifier and ("[mod:"..modifier.."] show; ") or "")
                ..(priorityModifier and ("[mod:"..priorityModifier.."] show; ") or "").."hide"
            if overlay.frameKind=="target"or overlay.frameKind=="focus" then
                driver="[@"..unit..",noexists][@"..unit..",nohelp][@"..unit..",dead] hide; "..driver
            end
        end
        for _,prefix in ipairs({"shift-","ctrl-","alt-"}) do self:SetAction(click,prefix,nil) end
        click:SetAttribute("unit",public(unit) and unit or nil)
        local displayed,nextAction,nextPriorityAction={},nil,nil
        local keyboardAction,keyboardPriorityAction
        local valid=not self.testUI and self.db.enabled and public(unit) and unit and UnitExists(unit)
            and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) and (self:IsSelf(unit) or UnitIsFriend("player",unit))
        local candidates={}
        local combatCandidates={}
        -- Combat actions stay prepared while testing. They are hidden outside
        -- combat; safe frame modifiers remain disarmed during previews.
        local combatValid=self.db.enabled and public(unit) and unit and UnitExists(unit)
            and UnitIsConnected(unit) and (self:IsSelf(unit)or UnitIsFriend("player",unit))
        if self.db.enabled and self.db.combatClicks and public(unit) and unit
            and (combatValid or (overlay.frameKind=="target"or overlay.frameKind=="focus")) then
            combatCandidates=self:FrameCombatCandidates(unit,overlay.frameKind)
        end
        local cleanup=not self.testUI and combatValid and self:FrameCleanupCandidates(unit,overlay.frameKind,combatCandidates)
        overlay.cleanupMode=not not cleanup;click.cleanupMode=overlay.cleanupMode
        if cleanup then candidates=cleanup
        elseif valid then candidates=self:BuildCandidates(unit,(overlay.frameKind=="target"or overlay.frameKind=="focus")and overlay.frameKind or nil)end
        local normalCount=#candidates
        for _,candidate in ipairs(combatCandidates) do candidates[#candidates+1]=candidate end
        local combatDisplayed={}
        local combatActions={friendly={},enemy={}}
        local cleanupActions={}
        local combatGroups={}
        local combatDriver=""
        click.combatButtons={}
        click.combatButtonsByRelation={friendly={},enemy={}}
        self:EnsureIndicators(frame,overlay.indicators,math.max(self:IndicatorCapacity(),#candidates))
        for index,candidate in ipairs(candidates) do
            local square=overlay.indicators.squares[index]
            square.buffKey,square.buffName,square.buffUnit=candidate.key,candidate.name,candidate.unit
            square.buffSpellID=candidate.spellID
            square.combatOnly=candidate.combatOnly==true
            square.cleanupOnly=candidate.cleanupOnly==true
            square.cleanupUnknown=candidate.cleanupUnknown
            square.effects=candidate.effects
            square.dispelReminders=candidate.dispelReminders
            square.combatPosition=candidate.combatPosition
            square.combatModifier=candidate.combatModifier
            square.combatBindingLabel:SetText(candidate.combatModifier and candidate.combatModifier:upper()or "")
            square.combatBindingLabel:SetShown(square.combatOnly and candidate.combatModifier~=nil)
            square.pet,square.petSlot,square.petBank=candidate.pet,candidate.petSlot,candidate.petBank
            square:SetAlpha(1); square.visual:SetAlpha(square.combatOnly and self.db.combatOpacity/100 or 1)
            square.rangeItem=not self:IsSelf(candidate.unit) and candidate.itemID or nil
            square.customItem,square.itemIndex=candidate.customItem,candidate.itemIndex
            square.poison,square.weaponSlot=candidate.poison,candidate.weaponSlot
            self:UpdatePoisonHandLabel(square)
            square.customParty=candidate.customItem and not self:IsSelf(candidate.unit) or false
            square.isCreation,square.weaponItem=candidate.creation,candidate.weaponItem
            square.consumeItem=candidate.consumable and candidate.itemID or nil
            square.onDemand=candidate.creation and not candidate.stockOnly
            square.missingSlash:Hide()
            square:SetAttribute("unit",candidate.unit)
            self:PrepareCastFeedback(square,candidate,self.db.combatClicks and square.combatOnly)
            square:SetAttribute("combat-clicks",self.db.combatClicks and square.combatOnly and not square.cleanupOnly)
            square:SetAttribute("combat-alpha",self.db.combatOpacity/100)
            square:SetAttribute("buff-action",candidate.action.type)
            self:SetAction(square,"",candidate.action)
            self:PaintIcon(square,candidate.spellID,candidate.itemID,candidate.creation)
            local visibility=square.combatOnly and "[combat] show; hide"
                or "[combat] hide; show"
            if square.combatOnly then visibility=self:CombatVisibility(candidate,unit)end
            if square.paletteVisibility~=visibility then
                RegisterStateDriver(square,"visibility",visibility); square.paletteVisibility=visibility
            end
            square:SetShown(not square.combatOnly or square.cleanupOnly)
            if square.combatOnly and not square.cleanupOnly then
                combatDisplayed[#combatDisplayed+1]=square
                local groupKey=(candidate.profile or 'self')..(candidate.allowDead and ':dead'or ':alive')
                combatGroups[groupKey]=combatGroups[groupKey]or {};table.insert(combatGroups[groupKey],square)
            else displayed[#displayed+1]=square end
            if square.combatOnly and candidate.combatModifier then
                local mod=candidate.combatModifier
                local relation=candidate.targetRule=='enemy'and 'enemy'or 'friendly'
                if square.cleanupOnly then cleanupActions[mod]=candidate.action;click.combatButtons[mod]=square
                elseif not candidate.allowDead or candidate.combatRes then
                    combatActions[relation][mod]=candidate.action
                    click.combatButtonsByRelation[relation][mod]=square
                    local rule=relation=='enemy'and 'harm'or 'help'
                    combatDriver=combatDriver..'[combat,mod:'..mod..',@'..unit..',exists,'..rule..','..(candidate.allowDead and 'dead'or 'nodead')..'] show; '
                end
            end
            local inRange=self:RangeStatus(candidate.unit,candidate.spellID,candidate.itemID)
            if index<=normalCount and not nextAction and candidate.queue and candidate.ready and inRange~=false then nextAction=candidate.action end
            if index<=normalCount and not nextPriorityAction and candidate.prioritySelected and candidate.ready and inRange~=false then nextPriorityAction=candidate.action end
            if index<=normalCount and not candidate.manualRecipient and candidate.ready and inRange~=false then
                if not keyboardAction and candidate.queue then keyboardAction=candidate.action end
                if not keyboardPriorityAction and candidate.prioritySelected then keyboardPriorityAction=candidate.action end
            end
        end
        for index=#candidates+1,#overlay.indicators.squares do
            local square=overlay.indicators.squares[index]
            self:SetAction(square,"",nil); square:SetAttribute("buff-action",""); square:SetAttribute("combat-clicks",false)
            square.combatOnly=false; square.buffUnit=nil
            RegisterStateDriver(square,"visibility","hide"); square.paletteVisibility="hide"; square:Hide()
        end
        if modifier then self:SetAction(click,modifier.."-",nextAction) end
        -- Bypass Q wins if both settings use the same modifier.
        -- An empty selection stays empty instead of falling back to normal buffs.
        if priorityModifier then self:SetAction(click,priorityModifier.."-",nextPriorityAction) end
        if cleanup then
            driver='[combat] hide; '
            for _,mod in ipairs({'shift','ctrl','alt'})do
                self:SetAction(click,mod..'-',cleanupActions[mod])
                if cleanupActions[mod]then driver=driver..'[mod:'..mod..'] show; 'end
            end
            driver=driver..'hide'
        end
        for _,prefix in ipairs({"shift-","ctrl-","alt-"}) do
            for _,key in ipairs({"type1","spell1","item1","macrotext1"}) do
                click:SetAttribute("safe-"..prefix..key,click:GetAttribute(prefix..key))
            end
        end
        for _,mod in ipairs({"shift","ctrl","alt"})do
            local action=combatActions.friendly[mod]or combatActions.enemy[mod]
            for _,key in ipairs({"type","spell","item","macrotext"})do
                click:SetAttribute("combat-"..mod.."-"..key.."1",action and action[key]or (key=="type"and ""or nil))
            end
            for _,relation in ipairs({'friendly','enemy'})do
                local selected=combatActions[relation][mod]
                for _,key in ipairs({'type','spell','item','macrotext'})do
                    click:SetAttribute('combat-'..relation..'-'..mod..'-'..key..'1',selected and selected[key]or(key=='type'and ''or nil))
                end
            end
        end
        -- Drop the old combat-hide prefix before composing the two modes.
        driver=driver:gsub("^%[combat%] hide; ","")
        if overlay.frameKind=="target"or overlay.frameKind=="focus"then
            driver="[@"..unit..",noexists] hide; "..combatDriver.."[combat] hide; [@"..unit..",nohelp] hide; "..driver
        else driver=combatDriver.."[combat] hide; "..driver end
        if overlay.driver~=driver then RegisterStateDriver(click,"visibility",driver);overlay.driver=driver end
        click:SetAttribute('dual-profile',overlay.frameKind=='target'or overlay.frameKind=='focus')
        local relationDriver='[@'..unit..',help] friendly; enemy'
        if click.relationDriver~=relationDriver then RegisterStateDriver(click,'relation',relationDriver);click.relationDriver=relationDriver end
        if not cleanup then click.combatButtons=click.combatButtonsByRelation.friendly end
        if frame==PlayerFrame then self.selfAction,self.selfPriorityAction=keyboardAction,keyboardPriorityAction end
        self:LayoutIndicators(overlay.indicators,frame,self:IsSelf(unit),displayed,overlay.frameKind)
        if not overlay.combatLayout then
            overlay.combatLayout=CreateFrame("Frame",nil,overlay.indicators)
        end
        overlay.combatLayouts=overlay.combatLayouts or {}
        local first=true
        for key,buttons in pairs(combatGroups)do
            local row=overlay.combatLayouts[key]
            if not row then row=CreateFrame('Frame',nil,overlay.indicators);overlay.combatLayouts[key]=row end
            self:LayoutIndicators(row,frame,self:IsSelf(unit),buttons,overlay.frameKind)
            if first then overlay.combatLayout=row;first=false end
        end
        if first then self:LayoutIndicators(overlay.combatLayout,frame,self:IsSelf(unit),{},overlay.frameKind)end
    end
    self:UpdateRange(); self:UpdateActivation()
    if self.testUI then self:RefreshTestUI() end
    if self.options then
        self:RefreshTableFooters()
        self.options:UpdateTargetControls()
        if self.options.UpdateBuffRows then self.options:UpdateBuffRows() end
        if self.options.UpdateItemRows then self.options:UpdateItemRows() end
        if self.options.UpdateCombatRows and self.options:IsShown()then self.options:UpdateCombatRows() end
        if self.options.itemBuffEditor and self.options.itemBuffEditor:IsShown() then self.options:UpdateItemBuffEditor() end
    end
    self:UpdateSaveButton()
end
local spellEvents=CreateFrame("Frame")
spellEvents:RegisterEvent("SPELLS_CHANGED")
spellEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
spellEvents:SetScript("OnEvent",function() F.spellCacheDirty=true end)
