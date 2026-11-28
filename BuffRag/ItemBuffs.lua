local _, F = ...
local function public(value) return not (issecretvalue and issecretvalue(value)) end
local function spellID(value)
    if not public(value) or type(value)~="number" or value<=0 or value>2147483647 or value~=math.floor(value) then return end
    return value
end
function F:ReadHelpfulAuras(unit)
    local cache=self.helpfulAuraCache
    if cache and cache[unit] then return cache[unit] end
    local snapshot={auras={},complete=false}
    if cache then cache[unit]=snapshot end
    for index=1,255 do
        local ok,aura=pcall(C_UnitAuras.GetAuraDataByIndex,unit,index,"HELPFUL")
        if not ok or not public(aura) then break end
        if not aura then snapshot.complete=true;break end
        snapshot.auras[#snapshot.auras+1]=aura
    end
    return snapshot
end
function F:GetItemBuffSnapshot(unit)
    if not public(unit) or type(unit)~="string" or not (unit=="player" or unit:match("^party%d+$") or unit:match("^raid%d+$")) then return end
    if unit~="player" and self:IsSelf(unit) then unit="player" end
    self.itemBuffSnapshots=self.itemBuffSnapshots or {}
    if self.itemBuffSnapshots[unit] then return self.itemBuffSnapshots[unit] end
    if InCombatLockdown() then return end
    local snapshot={ids={},names={},choices={}}
    self.itemBuffSnapshots[unit]=snapshot
    if not self.db or #self.db.items==0 then return snapshot end
    if unit~="player" and UnitIsVisible then
        local visible=UnitIsVisible(unit)
        if not public(visible) or not visible then return snapshot end
    end
    for _,aura in ipairs(self:ReadHelpfulAuras(unit).auras) do
        local id=spellID(aura.spellId)
        local name=public(aura.name) and type(aura.name)=="string" and aura.name or nil
        if name then snapshot.names[name]=true end
        if id then
            snapshot.ids[id]=true
            if name then snapshot.choices[#snapshot.choices+1]={id=id,name=name} end
        end
    end
    table.sort(snapshot.choices,function(a,b) return a.name<b.name or (a.name==b.name and a.id<b.id) end)
    return snapshot
end
function F:RefreshItemBuffs()
    if InCombatLockdown() then return end
    self.itemBuffSnapshots={}
    self.itemBuffSnapshot=self:GetItemBuffSnapshot("player")
end
function F:FindCustomItem(id)
    for _,entry in ipairs(self.db.items) do if entry.id==id then return entry end end
end
function F:IsCustomItemBuffActive(id,itemName,unit)
    if InCombatLockdown() then return false end                                                         
    local entry=self:FindCustomItem(id)
    if not entry or entry.buffMode=="off" then return false end
    local snapshot=self:GetItemBuffSnapshot(unit or "player")
    if not snapshot then return false end
    if not next(snapshot.ids) and not next(snapshot.names) then return false end
    local function matchID(value)
        local candidate=spellID(value)
        if not candidate then return false end
        if snapshot.ids[candidate] then return true end
        local info=C_Spell.GetSpellInfo(candidate)
        return info and public(info.name) and type(info.name)=="string" and snapshot.names[info.name] or false
    end
    local function matchName(value)
        return public(value) and type(value)=="string" and snapshot.names[value] or false
    end
    if entry.buffMode=="spell" then return matchID(entry.buffSpellID) or matchName(entry.buffName) end
    if matchName(itemName) then return true end
                                                                          
                                                                     
    if C_Item.GetItemSpell then
        local effect,effectID=C_Item.GetItemSpell(id)
        if matchID(effectID) or matchID(effect) then return true end
        if public(effect) and type(effect)=="table" then
            return matchID(effect.spellID) or matchID(effect.spellId)
                or matchName(effect.name) or matchName(effect.spellName)
        end
        if matchName(effect) then return true end
    end
    return false
end
function F:SetCustomItemBuff(id,mode,buffID)
    if InCombatLockdown() or (mode~="auto" and mode~="spell" and mode~="off") then return end
    local entry=self:FindCustomItem(id)
    if not entry then return end
    entry.buffMode=mode
    if buffID~=nil then
        entry.buffSpellID=spellID(buffID); entry.buffName=nil
        for _,aura in ipairs((self.itemBuffSnapshot or {}).choices or {}) do
            if aura.id==entry.buffSpellID then entry.buffName=aura.name; break end
        end
    end
    self:Refresh()
end
function F:OpenItemBuffEditor(id)
    if InCombatLockdown() or not self:FindCustomItem(id) then return end
    local editor=self.options.itemBuffEditor
    editor.itemID=id
    local entry=self:FindCustomItem(id)
    editor.optionPage=entry.combat and not entry.buffVisible and "combat" or "buff"
    self:PositionFloatingOptions(editor,self.options,"CENTER",0,0)
    editor:Show()
    self.options:UpdateItemBuffEditor()
end
function F:CreateItemBuffEditor(panel)
    local editor=self:CreateDetailOptions("BuffRagItemBuffEditor",460,285)
    local buffOptions=CreateFrame("Frame",nil,editor);buffOptions:SetAllPoints()
    local combatOptions=CreateFrame("Frame",nil,editor);combatOptions:SetAllPoints()
    local buffTab=self:CreateOptionsTab(editor,"Buff options",210,22)
    buffTab:SetPoint("TOPLEFT",12,-55)
    buffTab:SetScript("OnClick",function()editor.optionPage="buff";panel:UpdateItemBuffEditor()end)
    local combatTab=self:CreateOptionsTab(editor,"Combat options",210,22)
    combatTab:SetPoint("TOPRIGHT",-12,-55)
    combatTab:SetScript("OnClick",function()editor.optionPage="combat";panel:UpdateItemBuffEditor()end)
    self:AddOptionsText(editor,"Automatic uses the item's effect to choose valid targets. Change this if the item is classified incorrectly.",12,-126,436)
    self:AddOptionsText(buffOptions,"Buff detection",12,-164,436)
    local mode=CreateFrame("DropdownButton","BuffRagItemBuffMode",buffOptions,"WowStyle1DropdownTemplate")
    mode:SetPoint("TOPLEFT",12,-181); mode:SetSize(436,24); mode:SetDefaultText("Automatic")
    mode:SetupMenu(function(_,root)
        local entry=F:FindCustomItem(editor.itemID)
        if not entry then return end
        for _,choice in ipairs({{"Automatic (match item or effect)","auto"},{"Track a selected buff","spell"},{"Always show the icon","off"}}) do
            root:CreateRadio(choice[1],function(value) return (entry.buffMode or "auto")==value end,
                function(value) F:SetCustomItemBuff(editor.itemID,value) end,choice[2])
        end
    end)
    local buffLabel=self:AddOptionsText(buffOptions,"Select a buff currently on you",12,-216,436)
    local buff=CreateFrame("DropdownButton","BuffRagItemBuffChoice",buffOptions,"WowStyle1DropdownTemplate")
    buff:SetPoint("TOPLEFT",12,-234); buff:SetSize(436,24); buff:SetDefaultText("Choose a buff")
    buff:SetupMenu(function(_,root)
        local entry=F:FindCustomItem(editor.itemID)
        if not entry then return end
        local seen={}
        if entry.buffSpellID then
            local info=C_Spell.GetSpellInfo(entry.buffSpellID)
            local name=entry.buffName or (info and public(info.name) and info.name) or "Linked buff"
            root:CreateRadio(name,function(value) return entry.buffSpellID==value end,
                function(value) F:SetCustomItemBuff(editor.itemID,"spell",value) end,entry.buffSpellID)
            seen[entry.buffSpellID]=true
        end
        for _,aura in ipairs((F.itemBuffSnapshot or {}).choices or {}) do
            if not seen[aura.id] then
                seen[aura.id]=true
                root:CreateRadio(aura.name,function(value) return entry.buffSpellID==value end,
                    function(value) F:SetCustomItemBuff(editor.itemID,"spell",value) end,aura.id)
            end
        end
        if not next(seen) then root:CreateTitle("No readable buffs. Use the item, then reopen this list.") end
    end)
    local hint=self:AddOptionsText(buffOptions,"",12,-212,436)
    local categoryControls={}
    local function categoryDropdown(parent,label,field,y,choices)
        self:AddOptionsText(parent,label,12,y,118)
        local control=CreateFrame('DropdownButton',nil,parent,'WowStyle1DropdownTemplate')
        control:SetPoint('TOPLEFT',132,y+6);control:SetSize(316,24)
        control:SetupMenu(function(_,root)
            local entry=F:FindCustomItem(editor.itemID);if not entry then return end
            for _,choice in ipairs(choices)do
                local value=choice[2]
                root:CreateRadio(choice[1],function()return (entry[field]or 'auto')==value end,function()
                    if InCombatLockdown()then return end
                    entry[field]=value;F:Refresh()
                end)
            end
        end)
        categoryControls[#categoryControls+1]={control=control,field=field,choices=choices}
    end
    categoryDropdown(editor,'Use item on','useOn',-95,{{'Automatic','auto'},{'Self','self'},{'Friendly (including self)','friendly'},{'Enemy','enemy'},{'Either','either'}})
    categoryDropdown(combatOptions,'Post-combat role','cleanupRole',-164,{{'Automatic','auto'},{'None','none'},{'Cleansing','cleansing'}})
    self:AddOptionsText(combatOptions,'Automatic detects cleansing items. Choose Cleansing if this item removes a debuff but was not detected.',12,-195,436)
    local typesLabel=self:AddOptionsText(combatOptions,'Cleansing types (override)',12,-222,436)
    local typeChecks={}
    for index,kind in ipairs({'Magic','Curse','Disease','Poison','Bleed','Enrage'})do
        local check=CreateFrame('CheckButton',nil,combatOptions,'UICheckButtonTemplate')
        check:SetSize(21,21);check:SetPoint('TOPLEFT',10+(index-1)*73,-239);check.text:SetText(kind)
        check:SetScript('OnClick',function()
            local entry=F:FindCustomItem(editor.itemID);if not entry or InCombatLockdown()then return end
            if not entry.cleanseOverride then entry.cleanseTypes=F:CopySettings(F:ItemCategory(entry).cleanse or {})end
            entry.cleanseOverride=true;entry.cleanseTypes=entry.cleanseTypes or {};entry.cleanseTypes[kind]=check:GetChecked()or nil;F:Refresh()
        end)
        typeChecks[kind]=check
    end
    local categoryHint=self:AddOptionsText(editor,'',12,-248,436)
    local reminders=CreateFrame('CheckButton',nil,combatOptions,'UICheckButtonTemplate')
    reminders:SetSize(21,21);reminders:SetPoint('TOPLEFT',10,-267);reminders.text:SetText('Dispel reminders (symbols and Post-combat)')
    reminders:SetScript('OnClick',function()
        local entry=F:FindCustomItem(editor.itemID);if not entry or InCombatLockdown()then return end
        entry.dispelReminders=reminders:GetChecked();F:Refresh()
    end)
    function panel:UpdateItemBuffEditor()
        local entry=F:FindCustomItem(editor.itemID)
        if not entry then editor:Hide(); return end
        local name=C_Item.GetItemNameByID and C_Item.GetItemNameByID(entry.id)
        editor.detailTitle:SetText(name or ("Item #"..entry.id))
        editor.detailIcon:SetTexture(C_Item.GetItemIconByID and C_Item.GetItemIconByID(entry.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
        local page=editor.optionPage or "buff"
        F:SelectOptionsTab(buffTab,page=="buff")
        F:SelectOptionsTab(combatTab,page=="combat")
        buffOptions:SetShown(page=="buff");combatOptions:SetShown(page=="combat")
        local pickBuff=page=="buff" and entry.buffMode=="spell"
        buffLabel:SetShown(pickBuff);buff:SetShown(pickBuff);buff:SetEnabled(pickBuff)
        local category=F:ItemCategory(entry)
        local cleansing=page=="combat" and category.role=="cleansing"
        typesLabel:SetShown(cleansing)
        reminders:SetShown(cleansing)
        for _,check in pairs(typeChecks)do check:SetShown(cleansing) end
        editor:SetHeight(page=="combat" and (cleansing and 338 or 265) or (pickBuff and 345 or 285))
        categoryHint:SetPoint("TOPLEFT",12,page=="combat" and (cleansing and -299 or -226) or (pickBuff and -301 or -248))
        if page=="buff" and mode.GenerateMenu then mode:GenerateMenu() end
        if pickBuff and buff.GenerateMenu then buff:GenerateMenu() end
        hint:SetPoint("TOPLEFT",12,pickBuff and -265 or -212)
        hint:SetText(pickBuff and "Use the item on yourself, then choose its active buff."
            or (entry.buffMode=="off" and "The icon stays available while this item is eligible."
            or "The icon returns when the matched buff expires or is removed."))
        for _,setting in ipairs(categoryControls)do
            local label='Automatic'
            for _,choice in ipairs(setting.choices)do if choice[2]==entry[setting.field]then label=choice[1]end end
            setting.control:SetDefaultText(label);setting.control:SetEnabled(not InCombatLockdown())
            if (setting.field=='useOn' or page=="combat") and setting.control.GenerateMenu then setting.control:GenerateMenu()end
        end
        for kind,check in pairs(typeChecks)do check:SetChecked(category.cleanse and category.cleanse[kind]);check:SetEnabled(not InCombatLockdown())end
        reminders:SetChecked(entry.dispelReminders~=false);reminders:SetEnabled(not InCombatLockdown())
        categoryHint:SetText('Resolved use: '..category.useOn..(page=="combat" and ('  |  Post-combat: '..category.role) or ''))
    end
    editor:SetScript("OnShow",function() F:RefreshItemBuffs() end)
    editor.buffOptions,editor.combatOptions=buffOptions,combatOptions
    editor:Hide(); panel.itemBuffEditor=editor
end
