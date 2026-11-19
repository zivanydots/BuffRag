local _, F = ...
function F:CopySettings(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = type(value) == "table" and self:CopySettings(value) or value
    end
    return copy
end
local settingKeys={'frameModifier','priorityModifier','combatClicks','combatOpacity','combatFeedback','combatIncludeBuffs','minimapEnabled','windowZoom','windowScale'}
local placementKeys={'grow','selfGrow','raidPartyGrow','raidGrow','targetGrow','focusGrow','placement','topAlign','vertical','selfPlacement','selfTopAlign','selfVertical',
    'raidPartyPlacement','raidPartyTopAlign','raidPartyVertical','raidPlacement','raidTopAlign','raidVertical',
    'targetPlacement','targetTopAlign','targetVertical','focusPlacement','focusTopAlign','focusVertical'}
local iconKeys={'linkIconSizes','linkRaidIconSize','size','offset','iconVertical','selfSize','selfOffset','selfIconVertical','spacing',
    'raidPartySize','raidPartyOffset','raidPartyIconVertical','raidSize','raidOffset','raidIconVertical',
    'targetSize','targetOffset','targetIconVertical','focusSize','focusOffset','focusIconVertical'}
local frameIconKeys={placementKeys,iconKeys}
function F:ResetHelp()
    local tab=self.options and self.options.selectedTab or 1
    if tab==1 then return 'Restore Buffs rows, targets, queues and order. Item contents, combat assignments, general settings and placement are retained. Shared keep-in-bag choices shown here also reset.'end
    if tab==2 then return 'Restore Bag Items to its default empty list. Buffs order, combat spell assignments, settings and placement are retained. Save to keep the reset, or discard it when closing.'end
    if tab==3 then return 'Restore only the current Combat frame/profile: enabled rows, ranks, modifiers and visible row order. Dispels only limits the reset to displayed rows. Other frames/profiles and items are retained. Shared keep-in-bag choices shown here also reset.'end
    return 'Restore Global Settings and the Buff Rag keyboard shortcut. Frame icon placement and spell and item lists are retained.'
end
function F:ResetFrameIconDefaults()
    if InCombatLockdown() then return end
    for _,keys in ipairs(frameIconKeys) do
        for _,key in ipairs(keys) do self.db[key]=self.defaults[key] end
    end
    self:Refresh()
end
function F:SaveFrameIconOptions()
    if InCombatLockdown() or not BuffRagDB then return end
    for _,keys in ipairs(frameIconKeys) do
        for _,key in ipairs(keys) do BuffRagDB[key]=self.db[key] end
    end
    self:UpdateSaveButton()
end
function F:ResetDisplayedDefaults(global)
    if InCombatLockdown()or not self.db then return end
    local fresh=self:UpgradeSettings({})
    local tab=self.options and self.options.selectedTab or 1
    local function copy(key)
        self.db[key]=type(fresh[key])=='table'and self:CopySettings(fresh[key])or fresh[key]
    end
    local function keep(entry)
        if entry.stone then self.db.keepStones[entry.stone]=fresh.keepStones[entry.stone]end
        if entry.keepKey then self.db.keepCreated[entry.keepKey]=fresh.keepCreated[entry.keepKey]end
    end
    if global then
                                                                           
                                                             
        fresh.knownPoisons=self:CopySettings(self.db.knownPoisons or {})
        for key,row in pairs(self.db.combatRows or {})do
            if row.petIDs then fresh.combatRows[key]={petIDs=self:CopySettings(row.petIDs),
                petLearnedIDs=self:CopySettings(row.petLearnedIDs or {}),petAllowed=row.petAllowed and self:CopySettings(row.petAllowed)or nil}end
        end
        self.db=fresh
        if self.options then self.options:ClearAllPoints();self.options:SetPoint('CENTER')end
    elseif tab==1 then
        for _,key in ipairs({'priority','selfPriority','targetScopes','buffs','priorityBuffs','standardQueue','buffEnabled','itemsEnabled','poisonHands'})do copy(key)end
        for _,entry in ipairs(self.catalogue)do keep(entry)end
    elseif tab==2 then
        copy('items');copy('itemsEnabled')
        if self.options.itemBuffEditor then self.options.itemBuffEditor:Hide()end
    elseif tab==3 then
        if not self.db.combatClicks then self:Print('Enable combat mode to reset the displayed frame/profile.');return end
        local scope=self:CombatScope()
        local visible,sorted={},{}
        for _,row in ipairs(self:CombatDisplayRows(scope,true))do
            if row.group then
                visible[row.key]=true;sorted[#sorted+1]=row.key
                row.config.bindings[scope]='icon'
                row.config.frames[scope]={enabled=row.group.itemPlaceholder==true}
                if row.group.source then keep(row.group.source)end
            end
        end
        table.sort(sorted,function(a,b)
            if a=='combat:items'then return false elseif b=='combat:items'then return true end
            return self.combatCatalogue[a].name<self.combatCatalogue[b].name
        end)
        local nextKey=1
        for index,key in ipairs(self.db.combatOrders[scope])do
            if visible[key]then self.db.combatOrders[scope][index]=sorted[nextKey];nextKey=nextKey+1 end
        end
        if self.options.combatContent then self.options.combatContent.scroll:SetVerticalScroll(0)end
    else
        for _,key in ipairs(settingKeys)do copy(key)end
    end
    if (global or tab==4)and self.editingOptions then
        if self.options.CancelBindingCapture then self.options:CancelBindingCapture()end
        self:StageBuffRagBinding(nil)
    end
    if not self.editingOptions then BuffRagDB=self.db end
    self.combatBookDirty=true
    self:Refresh()
    if self.options and self.options.SyncFields then self.options:SyncFields()end
    self:UpdateSaveButton()
    self:Print((global and 'All settings' or 'Displayed settings')..(self.editingOptions and ' reset in preview. Click Save to keep them.'or ' reset to defaults.'))
end
local function equal(a, b, ignoreWindowPosition)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do
        if not (ignoreWindowPosition and key=="windowPosition") and not equal(value, b[key]) then return false end
    end
    for key in pairs(b) do
        if not (ignoreWindowPosition and key=="windowPosition") and a[key] == nil then return false end
    end
    return true
end
function F:OptionsDirty()
    return self.editingOptions and (not equal(self.db, BuffRagDB, true) or self:BindingDirty()) or false
end
function F:UpdateSaveButton()
    if self.options and self.options.save then
        local moved=self.editingOptions and not equal(self.db.windowPosition,BuffRagDB.windowPosition)
        self.options.save:SetEnabled((self:OptionsDirty() or moved) and not InCombatLockdown())
    end
    local window=self.options and self.options.iconOptions
    if window and window.save then
        local changed=false
        for _,keys in ipairs(frameIconKeys) do
            for _,key in ipairs(keys) do
                if self.db[key]~=BuffRagDB[key] then changed=true;break end
            end
            if changed then break end
        end
        window.save:SetEnabled(changed and not InCombatLockdown())
    end
end
function F:BeginOptions()
    if not self.editingOptions then
        self.db = self:CopySettings(BuffRagDB)
        self.editingOptions = true
    end
    if self.options.SyncFields then self.options:SyncFields() end
    self:UpdateSaveButton()
end
function F:SaveOptions()
    if InCombatLockdown() then return false end
    if not self:SaveBuffRagBinding() then return false end
    if self.editingOptions then BuffRagDB = self:CopySettings(self.db) end
    if self.options.UpdateBindingControl then self.options:UpdateBindingControl() end
    self:UpdateSaveButton()
    return true
end
function F:FinishOptions(save)
    if InCombatLockdown() then return end
    if save and not self:SaveOptions() then return end
    self.bindingDraft=nil
    self.editingOptions, self.awaitingOptionsDecision = false, false
    self.db = BuffRagDB
    local position = self.db.windowPosition
    self:SetOptionsCollapsed(false)
    self.options:ClearAllPoints()
    self:ApplyWindowScale(self.db.windowScale)
    if position then
        self.options:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    else self.options:SetPoint("CENTER") end
    if self.savePrompt then self.savePrompt:Hide() end
    self.options:Hide()
    self:Refresh()
end
function F:OptionsHidden()
    if InCombatLockdown() then return end                                
    if not self.editingOptions then return end
    if not self:OptionsDirty() then self:FinishOptions(false); return end
    if not self.savePrompt then
        local prompt = CreateFrame("Frame", "BuffRagSavePrompt", UIParent, "BasicFrameTemplateWithInset")
        prompt:SetSize(420,150); prompt:SetPoint("CENTER")
        prompt:SetFrameStrata("FULLSCREEN_DIALOG"); prompt:SetClampedToScreen(true)
        prompt.TitleText:SetText("Unsaved Buff Rag settings")
        local message = prompt:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        message:SetPoint("TOPLEFT",20,-40); message:SetWidth(380)
        message:SetText("Save your changes before closing?")
        local function button(label,x,callback)
            local control = CreateFrame("Button",nil,prompt,"UIPanelButtonTemplate")
            control:SetSize(115,26); control:SetPoint("BOTTOMLEFT",x,18)
            control:SetText(label); control:SetScript("OnClick",callback)
        end
        button("Save",20,function() F:FinishOptions(true) end)
        button("Don't save",152,function() F:FinishOptions(false) end)
        button("Cancel",284,function() prompt:Hide() end)
        prompt:SetScript("OnHide",function()
            if F.awaitingOptionsDecision then
                F.awaitingOptionsDecision=false
                if not InCombatLockdown() then F.options:Show() end
            end
        end)
        tinsert(UISpecialFrames,"BuffRagSavePrompt")
        self.savePrompt=prompt
    end
    self.awaitingOptionsDecision=true
    self.savePrompt:Show()
end
