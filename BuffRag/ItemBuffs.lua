local _, F = ...
local function public(value) return not (issecretvalue and issecretvalue(value)) end
local function spellID(value)
    if not public(value) or type(value)~="number" or value<=0 or value>2147483647 or value~=math.floor(value) then return end
    return value
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
    for index=1,255 do
        local ok,aura=pcall(C_UnitAuras.GetAuraDataByIndex,unit,index,"HELPFUL")
        if not ok or not public(aura) then break end
        if not aura then break end
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
    if InCombatLockdown() then return false end -- combat icons are manual actions, never aura reminders
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
    -- Optional metadata is used only to identify an active buff. It never
    -- determines whether an otherwise valid bag item can be clicked.
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
    self.options.itemBuffEditor.itemID=id
    self.options.itemBuffEditor:Show()
    self.options:UpdateItemBuffEditor()
end
function F:CreateItemBuffEditor(panel)
    local editor=CreateFrame("Frame","BuffRagItemBuffEditor",panel,"BasicFrameTemplateWithInset")
    editor:SetPoint("CENTER",panel,"CENTER",0,0); editor:SetSize(720,590); editor:SetFrameLevel(panel:GetFrameLevel()+60)
    editor.TitleText:SetText("Item options"); editor:EnableMouse(true)
    local function text(value,x,y)
        local label=editor:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        label:SetPoint("TOPLEFT",x,y); label:SetWidth(665); label:SetJustifyH("LEFT"); label:SetText(value)
        return label
    end
    local itemName=text("",25,-45)
    text("Hide the icon while its buff is active on that frame's player",25,-85)
    local mode=CreateFrame("DropdownButton","BuffRagItemBuffMode",editor,"WowStyle1DropdownTemplate")
    mode:SetPoint("TOPLEFT",25,-108); mode:SetWidth(655); mode:SetDefaultText("Automatic")
    mode:SetupMenu(function(_,root)
        local entry=F:FindCustomItem(editor.itemID)
        if not entry then return end
        for _,choice in ipairs({{"Automatic (match item or effect)","auto"},{"Track a selected buff","spell"},{"Always show the icon","off"}}) do
            root:CreateRadio(choice[1],function(value) return (entry.buffMode or "auto")==value end,
                function(value) F:SetCustomItemBuff(editor.itemID,value) end,choice[2])
        end
    end)
    text("Select a buff currently on you",25,-165)
    local buff=CreateFrame("DropdownButton","BuffRagItemBuffChoice",editor,"WowStyle1DropdownTemplate")
    buff:SetPoint("TOPLEFT",25,-188); buff:SetWidth(655); buff:SetDefaultText("Choose a buff")
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
    local hint=text("",25,-240)
    text("Automatic matches the item or its use effect. If detection misses an unusual effect, use it on yourself once and select its buff above. Each frame then checks that player's buff, and the icon returns when it expires or is removed.",25,-270)
    text("Buff detection applies outside combat only. Combat selections stay available as manual actions, with cast-result feedback; icons refresh normally after combat.",25,-325)
    local categoryControls={}
    local function categoryDropdown(label,field,y,choices)
        text(label,25,y)
        local control=CreateFrame('DropdownButton',nil,editor,'WowStyle1DropdownTemplate')
        control:SetPoint('TOPLEFT',200,y+6);control:SetSize(475,26)
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
    categoryDropdown('Use on','useOn',-375,{{'Automatic','auto'},{'Self','self'},{'Friendly (including self)','friendly'},{'Enemy','enemy'},{'Either','either'}})
    categoryDropdown('Clean-up role','cleanupRole',-415,{{'Automatic','auto'},{'None','none'},{'Healing','healing'},{'Cleansing','cleansing'}})
    text('Cleansing types (override)',25,-455)
    local typeChecks={}
    for index,kind in ipairs({'Magic','Curse','Disease','Poison','Enrage'})do
        local check=CreateFrame('CheckButton',nil,editor,'UICheckButtonTemplate');check:SetPoint('TOPLEFT',200+(index-1)*95,-447);check.text:SetText(kind)
        check:SetScript('OnClick',function()
            local entry=F:FindCustomItem(editor.itemID);if not entry or InCombatLockdown()then return end
            if not entry.cleanseOverride then entry.cleanseTypes=F:CopySettings(F:ItemCategory(entry).cleanse or {})end
            entry.cleanseOverride=true;entry.cleanseTypes=entry.cleanseTypes or {};entry.cleanseTypes[kind]=check:GetChecked()or nil;F:Refresh()
        end)
        typeChecks[kind]=check
    end
    local categoryHint=text('',25,-495)
    local reminders=CreateFrame('CheckButton',nil,editor,'UICheckButtonTemplate');reminders:SetPoint('TOPLEFT',200,-535);reminders.text:SetText('Dispel reminders (! and Clean-up)')
    reminders:SetScript('OnClick',function()
        local entry=F:FindCustomItem(editor.itemID);if not entry or InCombatLockdown()then return end
        entry.dispelReminders=reminders:GetChecked();F:Refresh()
    end)
    local close=CreateFrame("Button",nil,editor,"UIPanelButtonTemplate")
    close:SetPoint("BOTTOMLEFT",20,18); close:SetSize(110,24); close:SetText("Back")
    close:SetScript("OnClick",function() editor:Hide() end)
    function panel:UpdateItemBuffEditor()
        local entry=F:FindCustomItem(editor.itemID)
        if not entry then editor:Hide(); return end
        local name=C_Item.GetItemNameByID and C_Item.GetItemNameByID(entry.id)
        itemName:SetText(name or ("Item #"..entry.id))
        buff:SetEnabled(entry.buffMode=="spell")
        if mode.GenerateMenu then mode:GenerateMenu() end
        if buff.GenerateMenu then buff:GenerateMenu() end
        hint:SetText(entry.buffMode=="spell" and not entry.buffSpellID and "Choose a buff to link this item." or "")
        for _,setting in ipairs(categoryControls)do
            local label='Automatic'
            for _,choice in ipairs(setting.choices)do if choice[2]==entry[setting.field]then label=choice[1]end end
            setting.control:SetDefaultText(label);setting.control:SetEnabled(not InCombatLockdown())
            if setting.control.GenerateMenu then setting.control:GenerateMenu()end
        end
        local category=F:ItemCategory(entry)
        for kind,check in pairs(typeChecks)do check:SetChecked(category.cleanse and category.cleanse[kind]);check:SetEnabled(not InCombatLockdown())end
        reminders:SetChecked(entry.dispelReminders~=false);reminders:SetEnabled(not InCombatLockdown())
        categoryHint:SetText('Resolved: '..category.useOn..'; Clean-up: '..category.role..'. Unknown effects do not enable Clean-up. Override unusual items here; all casts still require your click.')
    end
    editor:SetScript("OnShow",function() F:RefreshItemBuffs() end)
    editor:Hide(); panel.itemBuffEditor=editor
end
