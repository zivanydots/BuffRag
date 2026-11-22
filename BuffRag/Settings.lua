local _, F = ...
local globalOptionKeys={'frameModifier','priorityModifier','bypassEnabled','combatClicks','combatOpacity','combatFeedback',
    'combatIncludeBuffs','minimapEnabled','windowZoom','windowScale','drEnabled','drEstimates','drOpacity'}
function F:CopySettings(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = type(value) == "table" and self:CopySettings(value) or value
    end
    return copy
end
local placementKeys={'grow','selfGrow','raidPartyGrow','raidGrow','targetGrow','focusGrow','placement','topAlign','vertical','selfPlacement','selfTopAlign','selfVertical',
    'raidPartyPlacement','raidPartyTopAlign','raidPartyVertical','raidPlacement','raidTopAlign','raidVertical',
    'targetPlacement','targetTopAlign','targetVertical','focusPlacement','focusTopAlign','focusVertical',
    'drTargetPlacement','drTargetAlign','drTargetGap','drTargetGrow','drFocusPlacement','drFocusAlign','drFocusGap','drFocusGrow'}
local iconKeys={'linkIconSizes','linkRaidIconSize','size','offset','iconVertical','selfSize','selfOffset','selfIconVertical','spacing',
    'raidPartySize','raidPartyOffset','raidPartyIconVertical','raidSize','raidOffset','raidIconVertical',
    'targetSize','targetOffset','targetIconVertical','focusSize','focusOffset','focusIconVertical',
    'drTargetSize','drTargetOffset','drTargetVertical','drFocusSize','drFocusOffset','drFocusVertical'}
local frameIconKeys={placementKeys,iconKeys}
function F:CopyFrameIconOptions(source,destination)
    for _,keys in ipairs(frameIconKeys) do
        for _,key in ipairs(keys) do destination[key]=source[key] end
    end
end
function F:ResetHelp()
    local tab=self.options and self.options.selectedTab or 1
    if tab==1 then return 'Restore Buff Mode rows, targets, queues and order. Item contents, combat assignments, general settings and placement are retained. Shared keep-in-bag choices shown here also reset.'end
    if tab==2 then return 'Restore Bag Items to its default empty list. Buffs order, combat spell assignments, settings and placement are retained. Save to keep the reset, or discard it when closing.'end
    if tab==3 then return 'Restore only the current Combat frame/profile: enabled rows, ranks, modifiers and visible row order. Dispels only limits the reset to displayed rows. Other frames/profiles and items are retained. Shared keep-in-bag choices shown here also reset.'end
    return 'Restore the displayed settings.'
end
function F:ResetFrameIconDefaults()
    if InCombatLockdown() then return end
    self:CopyFrameIconOptions(self.defaults,self.db)
    self:Refresh()
end
function F:SaveFrameIconOptions()
    if InCombatLockdown() or not BuffRagDB then return end
    self:CopyFrameIconOptions(self.db,BuffRagDB)
    self:UpdateSaveButton()
    self:Print("Frame icon settings saved.")
end
function F:ResetDisplayedDefaults(global,settingsOnly)
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
    elseif settingsOnly then
        for _,key in ipairs(globalOptionKeys) do copy(key) end
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
    end
    if (global or settingsOnly) and self.editingOptions then
        if self.options.CancelBindingCapture then self.options:CancelBindingCapture()end
        self:StageBuffRagBinding(nil)
    end
    if not self.editingOptions then BuffRagDB=self.db end
    self.combatBookDirty=true
    if self.perfRecording then self:NotePerfCacheInvalidation("combatBook","settings reset") end
    self:Refresh()
    if self.options and self.options.SyncFields then self.options:SyncFields()end
    self:UpdateSaveButton()
    self:Print((global and 'All settings' or 'Displayed settings')..(self.editingOptions and ' reset in preview. Click Save to keep them.'or ' reset to defaults.'))
end
local windowGeometry={windowPosition=true,windowWidth=true,windowHeight=true}
local function equal(a, b, ignoreWindowGeometry)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do
        if not (ignoreWindowGeometry and windowGeometry[key]) and not equal(value, b[key]) then return false end
    end
    for key in pairs(b) do
        if not (ignoreWindowGeometry and windowGeometry[key]) and a[key] == nil then return false end
    end
    return true
end
function F:OptionsDirty()
    return self.editingOptions and (not equal(self.db, BuffRagDB, true) or self:BindingDirty()) or false
end
function F:UpdateSaveButton()
    if self.options and self.options.save then
        local canSave=not InCombatLockdown() and self:OptionsDirty()
        self.options.save:SetEnabled(canSave)
        if self.options.globalSettings then self.options.globalSettings.save:SetEnabled(canSave) end
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
    local saved,reason=self:SaveOptionBindings()
    if not saved then
        local message="Buff Rag settings are still unsaved. "..reason
        if self.savePrompt and self.savePrompt:IsShown() then self.savePrompt.message:SetText(message)
        elseif UIErrorsFrame then UIErrorsFrame:AddMessage(message,1,.25,.25) end
        self:Print(message)
        self:UpdateSaveButton()
        return false
    end
    if self.editingOptions then BuffRagDB = self:CopySettings(self.db) end
    if self.options.UpdateBindingControl then self.options:UpdateBindingControl() end
    self:UpdateSaveButton()
    self:Print("Settings saved.")
    return true
end
function F:FinishOptions(save)
    if InCombatLockdown() then return end
    if save and not self:SaveOptions() then return end
    self.bindingDraft=nil
    self.resumeOptionsAfterCombat=nil
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
function F:SetupOptionsCloseAction(button,approve)
    button:RegisterForClicks("LeftButtonUp")
    button:SetAttribute("useOnKeyDown",false)
    button:SetAttribute("*macrotext1","/cleartarget\n/clearfocus")
    local approved
    button:SetScript("PreClick",function(control)
        approved=not InCombatLockdown() and approve()
        if not InCombatLockdown() then
            local preview=self.options.iconOptions
            control:SetAttribute("*type1",approved and preview and preview:IsShown() and "macro" or "")
        end
    end)
    button:SetScript("PostClick",function()
        if approved then self:FinishOptions(false) end
    end)
end
function F:RequestOptionsClose(fromCloseButton)
    if InCombatLockdown() or not self.options:IsShown() or self.awaitingOptionsDecision then return end
    local dirty=self:OptionsDirty()
    if not dirty then
        if fromCloseButton then return true end
        if not (self.options.iconOptions and self.options.iconOptions:IsShown()) then self:FinishOptions(false); return end
    end
    if not self.savePrompt then
        local shield = CreateFrame("Frame", nil, self.options)
        shield:SetAllPoints()
        shield:SetFrameStrata("FULLSCREEN_DIALOG")
        shield:EnableMouse(true)
        shield:Hide()
        local prompt = CreateFrame("Frame", "BuffRagSavePrompt", self.options, "BasicFrameTemplateWithInset")
        prompt:SetSize(420,150); prompt:SetPoint("CENTER",self.options,"CENTER")
        prompt:SetFrameStrata("FULLSCREEN_DIALOG"); prompt:SetClampedToScreen(true)
        prompt:SetFrameLevel(shield:GetFrameLevel()+1)
        prompt:EnableMouse(true)
        prompt:Hide()
        local message = prompt:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        message:SetPoint("TOPLEFT",20,-40); message:SetWidth(380)
        local function button(label,x,callback,confirmClose)
            local template=confirmClose and "UIPanelButtonTemplate,SecureActionButtonTemplate" or "UIPanelButtonTemplate"
            local control = CreateFrame("Button",nil,prompt,template)
            control:SetSize(115,26); control:SetPoint("BOTTOMLEFT",x,18)
            control:SetText(label)
            if confirmClose then self:SetupOptionsCloseAction(control,callback)
            else control:SetScript("OnClick",callback) end
            return control
        end
        prompt.message=message
        prompt.save=button("Save",20,function() return self:SaveOptions() end,true)
        prompt.discard=button("Don't save",152,function() return true end,true)
        button("Cancel",284,function() prompt:Hide() end)
        prompt.CloseButton:SetScript("OnClick",function() prompt:Hide() end)
        prompt:SetScript("OnShow",function() shield:Show() end)
        prompt:SetScript("OnHide",function()
            shield:Hide()
            F.awaitingOptionsDecision=false
        end)
        self.savePrompt=prompt
    end
    local prompt=self.savePrompt
    prompt.TitleText:SetText(dirty and "Unsaved Buff Rag settings" or "Close Buff Rag")
    prompt.message:SetText(dirty and "Save your changes before closing?" or "Close the icon preview and clear its target and focus?")
    prompt.save:SetShown(dirty)
    prompt.discard:SetText(dirty and "Don't save" or "Close")
    self.awaitingOptionsDecision=true
    prompt:Show()
end
