local _, F = ...
local function public(value) return not (issecretvalue and issecretvalue(value)) end
local _, playerClass = UnitClass("player")
F.class = playerClass
F.catalogue = F.classCatalogues[playerClass] or {{key="items",label="Bag Items",ids={},kind="items",default=true}}
F.spells = {}
F.abilityFamilies={}
for _,entry in ipairs(F.allClassCatalogues[playerClass] or {}) do F.abilityFamilies[entry.key]=entry end
F.defaults.priority, F.defaults.selfPriority, F.defaults.targetScopes, F.defaults.buffs = {}, {}, {}, {}
F.defaults.class, F.defaults.schema = playerClass, 6
F.defaults.keepStones = {soul=false,fire=false,spell=false,health=false}
F.defaults.keepCreated = {}
F.defaults.poisonHands = {}
F.defaults.knownPoisons = {}
F.defaults.priorityModifier = "ctrl"
F.defaults.bypassEnabled = false
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
        item.combat = old.combat == true
        item.queue = not item.combat and item.queue
        item.prioritySelected = not item.combat and old.prioritySelected == true
        item.useOn=({auto=true,self=true,friendly=true,enemy=true,either=true})[old.useOn]and old.useOn or 'auto'
        item.cleanupRole=({auto='auto',none='none',healing='none',cleansing='cleansing'})[old.cleanupRole] or 'auto'
        item.cleanseTypes={}
        for _,kind in ipairs({'Magic','Curse','Disease','Poison','Bleed','Enrage'})do item.cleanseTypes[kind]=type(old.cleanseTypes)=='table'and old.cleanseTypes[kind]==true or nil end
        item.dispelReminders=old.dispelReminders~=false
        item.cleanseOverride=old.cleanseOverride==true
    end
    return result
end
function F:UpgradeSettings(settings)
    if type(settings)~="table" then settings={} end
    if settings.linkIconSizes==nil then
        local previousSize=settings.selfSize or settings.size or self.defaults.selfSize
        for _,key in ipairs({"size","raidPartySize","targetSize","focusSize"}) do
            if (settings[key] or self.defaults[key])~=previousSize then
                settings.linkIconSizes=false
                break
            end
        end
    end
    local legacyHeader=settings.headerLayoutVersion==nil and type(settings.windowHeight)=='number'
    if type(settings.keepStones)~="table" then settings.keepStones={} end
                                                                           
                                                                        
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
    if legacyHeader then
        local previousHeight=(math.max(1160,tonumber(settings.windowWidth)or 1160)-24)*120/1016
        settings.windowHeight=math.floor(settings.windowHeight-math.max(0,previousHeight-self.headerHeight)+.5)
    end
    settings.headerLayoutVersion=1
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
    local anchors={left=true,right=true,top=true,bottom=true,center=true}
    for _,keys in pairs(self.frameIconLayouts) do
        local key=keys[1]
        if settings[key]=="overlay" then settings[key]="center"
        elseif not anchors[settings[key]] then settings[key]="right" end
    end
    for kind in pairs(self.frameIconLayouts) do self:NormalizeFrameIconOffsets(settings,kind) end
    for _,keys in pairs(self.frameIconLayouts) do
        local key=keys[7]
        if settings[key]~="left" then settings[key]="right" end
    end
    for _,key in ipairs({"healthstoneSeparate","healthstoneSize","healthstonePlacement","healthstoneAlign","healthstoneOffset","healthstoneVertical","healthstoneHealth"}) do
        settings[key]=nil
    end
    if settings.priorityModifier~="ctrl" and settings.priorityModifier~="alt" and settings.priorityModifier~="shift" and settings.priorityModifier~="off" then
        settings.priorityModifier="ctrl"
    end
    settings.bypassEnabled=settings.bypassEnabled==true
    if settings.bypassEnabled and settings.priorityModifier=="off" then settings.priorityModifier="ctrl" end
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
        if entry.buffStockOnly then scopes.self=false end
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
    if entry.kind=="items" or entry.buffStockOnly or not self:BuffAvailable(entry) or (entry.selfOnly and scope~="self") then return end
    if scope~="self" and scope~="party" and scope~="raid" and scope~="target" and scope~="focus" then return end
    self.db.targetScopes[key][scope]=enabled==true
    self:Refresh()
end
function F:BuffAvailable(entry)
    if not entry or entry.passive then return false end
    if entry.kind=="items" then return true end
    if entry.kind=="poison" then return self:PoisonAvailable(entry) end
    local _,id=self:LearnedSpell(entry.ids,entry.created~=nil)
    return id~=nil and not (C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(id))
end
function F:SetBuffPriority(key,enabled)
    local entry=self.spells[key]
    if InCombatLockdown() or not self.db.bypassEnabled or not self:BuffAvailable(entry) or entry.kind=="items" or entry.manual then return end
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
        GameTooltip:SetOwner(check,"ANCHOR_RIGHT"); GameTooltip:SetText("Enable in Combat Mode")
        GameTooltip:AddLine("Reserve this item for Combat and eligible Post-combat. Clears Queue and Bypass Q. If no frame is selected, the icon defaults to Self.",.8,.8,.8,true)
        GameTooltip:Show()
    end)
    check:SetScript("OnLeave",function() GameTooltip:Hide() end)
end
function F:QueueHelp()
    local modifier=self.db.frameModifier
    local action=modifier=="off" and "Frame modifier is disabled in Global Settings."
        or "Hold "..modifier:upper().." and left-click a unit frame to apply the next eligible entry."
    return "Include in the standard queue, in list order. "..action
end
function F:PriorityHelp()
    local modifier=self:BypassModifier()
    return "Add to Bypass Q. "..(modifier and "Hold "..modifier:upper().." and left-click a unit frame to use only Bypass Q entries, skipping the standard queue." or "Enable Bypass Q in Global Settings.")
end
function F:BypassModifier()
    if self.db.bypassEnabled then return self.db.priorityModifier end
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
    if entry and entry.kind=="items" then return true end                                     
    local scope=self:ScopeFor(unit,context)
    local targets=self.db.targetScopes[key]
    return entry and not entry.passive and not entry.buffStockOnly and targets and targets[scope] and (not entry.selfOnly or scope=="self")
end
function F:BuildSpellCache(perf)
    if not self.spellCacheDirty and self.spellCache then return end
    if self.perfRecording then self:NotePerfCacheRebuild("spellbook",perf,not self.spellCache) end
    self.spellCache, self.spellCacheIDs, self.spellCacheDirty = {}, {}, false
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
                    self.spellCacheIDs[id]=true
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
function F:LearnedSpell(ids,exact)
    self:BuildSpellCache()
    for _,id in ipairs(ids) do
        local info=C_Spell.GetSpellInfo(id)
        if info then
            local cached=not exact and self.spellCache[info.name]
            if cached then return info.name,cached.id end
            local known=(self.spellCacheIDs and self.spellCacheIDs[id]) or (IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id))
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
            if public(info) and info and public(info.name) and info.name then names[info.name]=true end
        end
    end
    local snapshot=self:ReadHelpfulAuras(unit)
    for _,aura in ipairs(snapshot.auras) do
        if not public(aura.name) or not public(aura.spellId) then return true end
        if ids[aura.spellId] or names[aura.name] then return true end
    end
    return not snapshot.complete
end
local function spellUsable(id)
    local usable=C_Spell.IsSpellUsable(id)
    return public(usable) and usable==true
end
function F:BuffSpellUsabilityChanged()
    for id,usable in pairs(self.buffSpellUsability or {}) do
        if spellUsable(id)~=usable then return true end
    end
    return false
end
function F:SpellReady(id)
    local active
    if C_Spell.GetSpellCooldownDuration then
        local ok,result=pcall(function()
            local duration=C_Spell.GetSpellCooldownDuration(id,true)
            if not public(duration) then return end
            if not duration then return false end
            return duration:IsActive()
        end)
        if ok and public(result) and type(result)=="boolean" then active=result end
    end
    if active==true then return false,true end
    if active==nil and C_Spell.GetSpellCooldown then
        local cooldown=C_Spell.GetSpellCooldown(id)
        if not public(cooldown) then return false,true end
        if cooldown then
            if not public(cooldown.startTime) or not public(cooldown.duration) then return false,true end
            if cooldown.duration and cooldown.duration>1.5 and cooldown.startTime+cooldown.duration>GetTime() then return false,true end
        end
    end
    if C_Spell.IsSpellUsable then
        local checked=self.refreshSpellUsability
        local usable=checked and checked[id]
        if usable==nil then
            usable=spellUsable(id)
            if checked then checked[id]=usable end
        end
        return usable,false
    end
    return true,false
end
function F:WeaponImbued(inventorySlot)
    inventorySlot=inventorySlot or 16
                                                                           
                                                            
    local types=Enum and Enum.ItemEnchantType
    local slots=Enum and Enum.WeaponSlot
    if C_Item.GetWeaponEnchantInfo and types and types.Imbue~=nil and slots and slots.MainHand~=nil then
        local weaponSlot=inventorySlot==17 and slots.OffHand or slots.MainHand
        if weaponSlot==nil then return true end
        local list=C_Item.GetWeaponEnchantInfo(weaponSlot)
        if not public(list) or type(list)~="table" then return true end                     
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
    local name,id
    if chosenRank then id=chosenRank;local info=C_Spell.GetSpellInfo(id);name=info and info.name
    else name,id=self:LearnedSpell(entry.ids,true) end
    if not id or (C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(id)) then return end
    local items=entry.created[id]
    if not items then return end                                               
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
    return {key=entry.key,name=(C_Item.GetItemNameByID and C_Item.GetItemNameByID(carried)) or entry.label,
        itemID=carried,unit="player",consumable=true,ready=self:BagItemReady(carried),queue=true,action={type="item",item="item:"..carried}}
end
function F:BuffCandidate(entry,unit,prepare,chosenRank)
    if entry.kind=="poison" then return self:PoisonCandidate(entry,unit,prepare) end
    if entry.created then return self:CreatedItemCandidate(entry,false,prepare) end
    local name,id
    if chosenRank then id=chosenRank;local info=C_Spell.GetSpellInfo(id);name=info and info.name
    else name,id=self:LearnedSpell(entry.ids) end
    if not id or entry.passive or (C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(id)) then return end
    local kind=entry.kind
    local ready,onCooldown=true,false
    if not prepare then ready,onCooldown=self:SpellReady(id) end
    if onCooldown and (entry.cooldownLimited or entry.singleRecipient or entry.hideOnCooldown) then return end
    if not prepare and entry.singleRecipient and self:SingleRecipientActive(entry) then return end
    local result={key=entry.key,name=name,spellID=id,unit=unit,ready=ready,queue=not entry.manual}
    result.manualRecipient=entry.singleRecipient==true
    if kind=="tracking" then
        if not prepare and self:Tracking(name) then return end
    elseif kind=="totem" then
        local have=GetTotemInfo(entry.slot)
        if not prepare and (not public(have) or have) then return end                                    
    elseif kind=="weapon" or kind=="stoneWeapon" then
        if not GetInventoryItemID("player",16) then return end
        if not prepare and self:WeaponImbued() then return end                                    
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
                                                                            
                                                                               
            if not prepare and not self:ItemReady(item) then return end
            result.itemID,result.spellID=item,nil; result.ready=true
        elseif self:IsSelf(unit) then result.creation=true; result.unit="player"
        else return end
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
                        if item.enabled and not item.combat and item[scope]and self:ItemTargetAllowed(self:ItemCategory(item),unit,profile)then
                            local data=self:CustomItemData(item.id,unit)
                            if not data.buffActive then
                                local action=self:ItemAction(item,unit,profile)
                                if not data.usable then action={type=""} end
                                result[#result+1]={key="items",name=data.name,itemID=item.id,customItem=item.id,itemIndex=itemIndex,
                                    score=index+itemIndex/(itemIndex+1),unit=unit,action=action,ready=data.ready,itemMissing=data.count==0,queue=item.queue,
                                    prioritySelected=self.db.bypassEnabled and item.prioritySelected==true}
                            end
                        end
                    end
                end
            else
                local candidate=self:CandidateForEntry(entry,unit,context)
                if candidate then
                    if candidate.spellID and candidate.action.type=="macro" and candidate.unit==unit then
                        candidate.queueAction={type="spell",spell=candidate.spellID}
                    end
                    candidate.queue=candidate.queue and self.db.standardQueue[key]~=false
                    candidate.score=index
                    candidate.prioritySelected=self.db.bypassEnabled and self.db.priorityBuffs[key]==true and not entry.manual
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
local function pickQueueAction(action,blocked,candidate,ready)
    if action then return action,blocked end
    local attempt=candidate.queueAction or candidate.action
    if ready then return attempt,blocked end
    return nil,blocked or attempt
end
local function frameUnit(frame,kind)
    if kind=="target" or kind=="focus" then return kind end
    if frame==PlayerFrame then return "player" end
    return frame.unit or frame:GetAttribute("unit")
end
function F:SelectFrameQueueAction(queue,priority,squares)
    local blocked,outOfRange
    for index=1,queue.count do
        local candidate=queue.candidates[index]
        local selected=priority and candidate.prioritySelected or not priority and candidate.queue
        if selected and candidate.action.type~="" and not candidate.itemMissing then
            local square=squares and squares[index]
            local out
            if square then out=square.outOfRange
            else out=self:RangeStatus(candidate.unit,candidate.spellID,candidate.itemID)==false end
            if out then outOfRange=true
            else
                local action
                action,blocked=pickQueueAction(nil,blocked,candidate,candidate.ready)
                if action then return action,blocked,outOfRange,square end
            end
        end
    end
    return nil,blocked,outOfRange
end
function F:PrepareBuffQueueClick(button,frame,mouse,down)
    if InCombatLockdown() or self:IsDuelCombat() or button.cleanupMode or mouse~="LeftButton" or down then return end
    local queue=button.buffQueue
    if not queue then return end
    local shift,ctrl,alt=IsShiftKeyDown(),IsControlKeyDown(),IsAltKeyDown()
    if (shift and (ctrl or alt)) or (ctrl and alt) then return end
    local modifier=shift and "shift" or ctrl and "ctrl" or alt and "alt"
    local priority=modifier and modifier==queue.bypass
    if not modifier or (not priority and modifier~=queue.standard) then return end
    local prefix=modifier.."-"
    local unit=frameUnit(frame,queue.kind)
    if not public(unit) or unit~=queue.unit then
        self:SetAction(button,prefix,nil)
        return
    end
    local exists,dead,friendly=UnitExists(unit),UnitIsDeadOrGhost(unit),UnitIsFriend("player",unit)
    if not public(exists) or not exists or not public(dead) or dead
        or (not self:IsSelf(unit) and (not public(friendly) or not friendly)) then
        self:SetAction(button,prefix,nil)
        return
    end
    local guid=UnitGUID(unit)
    if queue.guid and public(guid) and guid~=queue.guid then
        self:SetAction(button,prefix,nil)
        self:RequestRefresh("Unit frame reassigned")
        return
    end
    local action,blocked,outOfRange=self:SelectFrameQueueAction(queue,priority)
    self:SetAction(button,prefix,action or blocked)
    if not action and not blocked and outOfRange and UIErrorsFrame then
        local message=SPELL_FAILED_OUT_OF_RANGE or ERR_OUT_OF_RANGE
        if message then UIErrorsFrame:AddMessage(message,1,.1,.1) end
    end
end
function F:Refresh(triggers)
    local perf=self.perfRecording and not InCombatLockdown() and self:BeginPerfRefresh(triggers)
    if self.db then self:SyncMinimapVisibility() end
    if not self.db or InCombatLockdown() then return end
    self.dispelSnapshots={}
    if self:UpdateAddonConflictPause() then
        self.buffSpellUsability=nil
        self:SuspendForAddonConflict()
        self:RefreshDR()
        if perf then self:EndPerfRefresh(perf,true) end
        return
    end
    if perf then self:MarkPerfRefresh(perf,"setup") end
    self:BuildSpellCache(perf)
    if perf then self:MarkPerfRefresh(perf,"spellbook") end
    self:DiscoverCombatSpells(perf)
    if perf then self:MarkPerfRefresh(perf,"combatBook") end
    self.helpfulAuraCache={}
    self:RefreshItemBuffs()
    if perf then self:MarkPerfRefresh(perf,"itemBuffs") end
    self:RefreshSingleRecipientBuffs()
    if perf then self:MarkPerfRefresh(perf,"recipients") end
    self:Discover()
    if perf then self:MarkPerfRefresh(perf,"frameDiscovery") end
    self.refreshUnits,self.refreshUnitGUIDs={},{}
    self.refreshSpellUsability={}
    self.selfAction,self.selfPriorityAction=nil,nil
    local combatRows,keybinds={},{}
    local duel=self:IsDuelCombat()
    local combatCondition=duel and "" or "combat,"
    for frame,overlay in pairs(self.overlays) do
        local unit=frameUnit(frame,overlay.frameKind)
        if public(unit) and self:IsGroupPreviewFrame(overlay.frameKind,unit) then unit=nil end
        if public(unit) and unit then self:RememberRefreshUnit(unit) end
        local click=overlay.click
        local dual=overlay.frameKind=="target" or overlay.frameKind=="focus"
        if dual then
            local watched=overlay.frameKind
            local driver=(self.db.combatClicks and ("[combat,@"..watched..",exists] show; ") or "")
                .."[combat] hide; [@"..watched..",exists,help] show; "
                ..(self.db.combatClicks and ("[@"..watched..",exists,harm,nodead] show; ") or "").."hide"
            if overlay.targetDriver~=driver then RegisterStateDriver(overlay.indicators,"visibility",driver); overlay.targetDriver=driver end
        end
        local modifier=self.db.frameModifier
        if modifier~="shift" and modifier~="ctrl" and modifier~="alt" then modifier=nil end
        local priorityModifier=self:BypassModifier()
        if priorityModifier~="shift" and priorityModifier~="ctrl" and priorityModifier~="alt" then priorityModifier=nil end
        local driver="hide"
        if self.db.enabled and not self.testUI and (modifier or priorityModifier) then
            driver="[combat] hide; "..(modifier and ("[mod:"..modifier.."] show; ") or "")
                ..(priorityModifier and ("[mod:"..priorityModifier.."] show; ") or "").."hide"
            if overlay.frameKind=="target"or overlay.frameKind=="focus" then
                driver="[@"..unit..",noexists][@"..unit..",nohelp][@"..unit..",dead] hide; "..driver
            end
        end
        click:SetAttribute("unit",public(unit) and unit or nil)
        local displayed,nextAction,nextPriorityAction={},nil,nil
        local keyboardAction,keyboardPriorityAction
        local blockedAction,blockedPriorityAction,blockedKeyboardAction,blockedKeyboardPriorityAction
        local valid=not duel and not self.testUI and self.db.enabled and public(unit) and unit and UnitExists(unit)
            and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) and (self:IsSelf(unit) or UnitIsFriend("player",unit))
        local candidates={}
        local combatCandidates={}
                                                                              
                                                                        
        local combatValid=self.db.enabled and public(unit) and unit and UnitExists(unit)
            and UnitIsConnected(unit) and (self:IsSelf(unit)or UnitIsFriend("player",unit))
        if self.db.enabled and self.db.combatClicks and public(unit) and unit
            and (combatValid or (overlay.frameKind=="target"or overlay.frameKind=="focus")) then
            combatCandidates=self:FrameCombatCandidates(unit,overlay.frameKind,combatRows)
        end
        local cleanup=not duel and not self.testUI and combatValid and self:FrameCleanupCandidates(unit,overlay.frameKind,combatCandidates)
        if perf and not self.testUI and (not not cleanup)~=overlay.cleanupMode then
            if cleanup then perf.entered=perf.entered+1
            elseif overlay.cleanupMode then perf.left=perf.left+1 end
        end
        overlay.cleanupMode=not not cleanup;click.cleanupMode=overlay.cleanupMode
        if not duel and not self.testUI and #combatCandidates>0 and UnitExists(unit) and UnitIsConnected(unit) then
            candidates=self:FrameOutOfCombatCandidates(unit,overlay.frameKind,combatCandidates,cleanup)
        elseif cleanup then candidates=cleanup end
        if not cleanup and valid then
            for _,candidate in ipairs(self:BuildCandidates(unit,(overlay.frameKind=="target"or overlay.frameKind=="focus")and overlay.frameKind or nil)) do
                candidates[#candidates+1]=candidate
            end
        end
        local normalCount=#candidates
        click.buffQueue=nil
        if valid and not cleanup and normalCount>0 and (modifier or priorityModifier) then
            local guid=UnitGUID(unit)
            click.buffQueue={unit=unit,kind=overlay.frameKind,guid=public(guid) and guid or nil,
                standard=modifier,bypass=priorityModifier,candidates=candidates,count=normalCount}
        end
        for _,candidate in ipairs(combatCandidates) do
            if not candidate.allowDead or candidate.combatRes then candidates[#candidates+1]=candidate end
        end
        if perf then
            perf.frames=perf.frames+1
            perf.icons=perf.icons+#candidates
            self:MarkPerfRefresh(perf,"checks")
        end
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
            square.outOfCombat=candidate.outOfCombat==true
            square.cleanupOnly=candidate.cleanupOnly==true
            square.keybind=candidate.keybind
            square.effects=candidate.effects
            square.creatureTargets=candidate.creatureTargets
            square.wrongCreatureType=false
            square.dispelRelation=candidate.targetRule or "friendly"
            square.dispelReminders=candidate.dispelReminders
            square.combatPosition=candidate.combatPosition
            square.combatModifier=candidate.combatModifier
            square.pet,square.petSlot,square.petBank=candidate.pet,candidate.petSlot,candidate.petBank
            square:SetAlpha(1); square.visual:SetAlpha(1)
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
            square:SetAttribute("combat-clicks",self.db.combatClicks and square.combatOnly and not square.cleanupOnly and not square.outOfCombat)
            square:SetAttribute("combat-alpha",self.db.combatOpacity/100)
            square:SetAttribute("buff-action",candidate.action.type)
            self:SetAction(square,"",candidate.action)
            self:PaintIcon(square,candidate.spellID,candidate.itemID,candidate.creation)
            local combatOnly=square.combatOnly and not square.cleanupOnly and not square.outOfCombat
            if square.nativeDispel or (combatOnly and square.effects and (square.effects.cleanse or square.effects.purge)) then
                self:PrepareNativeDispel(square,combatOnly)
            end
            self:UpdateDispelReminder(square,combatOnly)
            local visibility=square.combatOnly and "[combat] show; hide"
                or "[combat] hide; show"
            if square.combatOnly then visibility=self:CombatVisibility(candidate,unit,duel)end
            if not square.combatOnly and (overlay.frameKind=="target"or overlay.frameKind=="focus") then
                visibility="[combat] hide; [@"..unit..",exists,help,nodead] show; hide"
            end
            if square.paletteVisibility~=visibility then
                square:SetShown(not square.combatOnly or square.cleanupOnly or square.outOfCombat)
                RegisterStateDriver(square,"visibility",visibility); square.paletteVisibility=visibility
            end
            if candidate.keybind and (overlay.frameKind=='target' or overlay.frameKind=='focus') then
                self:CollectCombatKeybind(keybinds,candidate,square,overlay.frameKind)
            end
            if square.combatOnly and not square.cleanupOnly and not square.outOfCombat then
                combatDisplayed[#combatDisplayed+1]=square
                local groupKey=(candidate.profile or 'self')..(candidate.allowDead and ':dead'or ':alive')
                combatGroups[groupKey]=combatGroups[groupKey]or {};table.insert(combatGroups[groupKey],square)
            else displayed[#displayed+1]=square end
            if square.combatOnly and not square.outOfCombat and candidate.combatModifier then
                local mod=candidate.combatModifier
                local relation=candidate.targetRule=='enemy'and 'enemy'or 'friendly'
                if square.cleanupOnly then cleanupActions[mod]=candidate.action;click.combatButtons[mod]=square
                elseif not candidate.allowDead or candidate.combatRes then
                    combatActions[relation][mod]=candidate.action
                    click.combatButtonsByRelation[relation][mod]=square
                    local rule=relation=="enemy" and "harm" or (dual and "help,noharm" or "help")
                    combatDriver=combatDriver.."["..combatCondition.."mod:"..mod..",@"..unit..",exists,"..rule..","..(candidate.allowDead and "dead" or "nodead").."] show; "
                end
            end
            local inRange=self:RangeStatus(candidate.unit,candidate.spellID,candidate.itemID)
            if index<=normalCount and candidate.action.type~="" and not candidate.itemMissing and inRange~=false then
                local ready=candidate.ready
                local onSelfBinding=frame==PlayerFrame and not candidate.manualRecipient
                if candidate.queue then
                    nextAction,blockedAction=pickQueueAction(nextAction,blockedAction,candidate,ready)
                    if onSelfBinding then
                        keyboardAction,blockedKeyboardAction=pickQueueAction(keyboardAction,blockedKeyboardAction,candidate,ready)
                    end
                end
                if candidate.prioritySelected then
                    nextPriorityAction,blockedPriorityAction=pickQueueAction(nextPriorityAction,blockedPriorityAction,candidate,ready)
                    if onSelfBinding then
                        keyboardPriorityAction,blockedKeyboardPriorityAction=pickQueueAction(keyboardPriorityAction,blockedKeyboardPriorityAction,candidate,ready)
                    end
                end
            end
        end
        for index=#candidates+1,#overlay.indicators.squares do
            local square=overlay.indicators.squares[index]
            if square.nativeDispel and square.nativeDispel.unit then self:PrepareNativeDispel(square,false) end
            if square.paletteVisibility~="hide" then
                self:SetAction(square,"",nil); square:SetAttribute("buff-action",""); square:SetAttribute("combat-clicks",false)
                RegisterStateDriver(square,"visibility","hide"); square.paletteVisibility="hide"; square:Hide()
            end
            square.combatOnly=false; square.buffUnit=nil
        end
        local safeActions=cleanup and cleanupActions or {}
        if not cleanup then
            if modifier then safeActions[modifier]=nextAction or blockedAction or nil end
            if priorityModifier then safeActions[priorityModifier]=nextPriorityAction or blockedPriorityAction or nil end
        end
        if cleanup then
            driver='[combat] hide; '
            for _,mod in ipairs({'shift','ctrl','alt'})do
                if cleanupActions[mod]then driver=driver..'[mod:'..mod..'] show; 'end
            end
            driver=driver..'hide'
        end
        for _,prefix in ipairs({"shift-","ctrl-","alt-"}) do
            self:SetAction(click,prefix,safeActions[prefix:sub(1,-2)])
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
                                                                          
        driver=driver:gsub("^%[combat%] hide; ","")
        if duel then
            driver=combatDriver.."hide"
        elseif dual then
            driver="[@"..unit..",noexists] hide; "..combatDriver.."[combat] hide; [@"..unit..",nohelp] hide; "..driver
        else driver=combatDriver.."[combat] hide; "..driver end
        if overlay.driver~=driver then RegisterStateDriver(click,"visibility",driver);overlay.driver=driver end
        click:SetAttribute('dual-profile',dual)
        local relation="friendly"
        if dual then
            local relationDriver='[@'..unit..',harm] enemy; [@'..unit..',help] friendly; enemy'
            if click.relationDriver~=relationDriver then RegisterStateDriver(click,'relation',relationDriver);click.relationDriver=relationDriver end
            if duel then
                relation=SecureCmdOptionParse and SecureCmdOptionParse(relationDriver) or click:GetAttribute("state-relation") or "enemy"
            end
        end
        if duel then
            for _,mod in ipairs({"shift","ctrl","alt"}) do self:SetAction(click,mod.."-",combatActions[relation][mod]) end
        end
        local combatState=duel and "combat" or "[combat] combat; safe"
        if click.combatState~=combatState then
            RegisterStateDriver(click,"combat",combatState)
            click.combatState=combatState
        end
        if not cleanup then click.combatButtons=click.combatButtonsByRelation[relation] end
        if frame==PlayerFrame then
            self.selfAction=keyboardAction or blockedKeyboardAction or nil
            self.selfPriorityAction=keyboardPriorityAction or blockedKeyboardPriorityAction or nil
        end
        if perf then
            perf.slots=perf.slots+#overlay.indicators.squares
            self:MarkPerfRefresh(perf,"buttons")
        end
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
        if perf then self:MarkPerfRefresh(perf,"layout") end
    end
    self.helpfulAuraCache=nil
    self.buffSpellUsability,self.refreshSpellUsability=self.refreshSpellUsability,nil
    self:UpdateRange(true); self:UpdateActivation(); self:SyncCombatKeybinds(keybinds)
    if self.testUI then self:RefreshTestUI() end
    self:RefreshDR()
    if self.options then
        local settings=self.options.globalSettings
        if settings and settings:IsShown() then settings:Sync() end
        if self.options.UpdateBuffRows then self.options:UpdateBuffRows() end
        if self.options.UpdateItemRows then self.options:UpdateItemRows() end
        if self.options.UpdateCombatRows and self.options:IsShown()then self.options:UpdateCombatRows() end
        if self.options.itemBuffEditor and self.options.itemBuffEditor:IsShown() then self.options:UpdateItemBuffEditor() end
    end
    self:UpdateSaveButton()
    if perf then
        self:MarkPerfRefresh(perf,"finish")
        self:EndPerfRefresh(perf)
    end
end
local spellEvents=CreateFrame("Frame")
spellEvents:RegisterEvent("SPELLS_CHANGED")
spellEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
spellEvents:SetScript("OnEvent",function(_,event)
    F.spellCacheDirty=true
    if F.perfRecording then F:NotePerfCacheInvalidation("spellbook",event) end
end)
