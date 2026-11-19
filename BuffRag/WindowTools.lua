local _, F = ...
local bindingAction="CLICK BuffRagActivateButton:LeftButton"
local function currentKeys()
    return GetBindingKey and {GetBindingKey(bindingAction)} or {}
end
function F:BindingDirty()
    if not self.bindingDraft then return false end
    local actual=currentKeys()
    if #actual~=#self.bindingDraft.keys then return true end
    for index,key in ipairs(actual) do if key~=self.bindingDraft.keys[index] then return true end end
    return false
end
function F:StageBuffRagBinding(key)
    if InCombatLockdown() or not self.editingOptions then return false,"Edit bindings outside combat." end
    local action=key and GetBindingAction(key)
    if action and action~="" and action~=bindingAction then return false,"That key is already bound. Choose another key." end
    local old=self.bindingDraft and self.bindingDraft.keys or currentKeys()
    local keys={}
    if key then
        keys[1]=key
        for index=2,#old do if old[index]~=key then keys[#keys+1]=old[index] end end
    end
    self.bindingDraft={keys=keys,set=GetCurrentBindingSet()}
    self:UpdateSaveButton()
    if self.options.UpdateBindingControl then self.options:UpdateBindingControl() end
    return true
end
function F:SaveBuffRagBinding()
    if not self:BindingDirty() then self.bindingDraft=nil; return true end
    if InCombatLockdown() then return false end
    local draft=self.bindingDraft
    if GetCurrentBindingSet()~=draft.set then self:Print("Binding profile changed. Choose the BuffRag key again."); return false end
    for _,key in ipairs(draft.keys) do
        local action=GetBindingAction(key)
        if action and action~="" and action~=bindingAction then self:Print("BuffRag key is now assigned to another action. Choose another key."); return false end
    end
    local old=currentKeys()
    local function restore()
        for _,key in ipairs(currentKeys()) do SetBinding(key) end
        for _,key in ipairs(old) do SetBindingClick(key,"BuffRagActivateButton","LeftButton") end
        self:Print("Could not save the BuffRag binding. Your previous keys were restored.")
        return false
    end
    for _,key in ipairs(old) do if not SetBinding(key) then return restore() end end
    for _,key in ipairs(draft.keys) do if not SetBindingClick(key,"BuffRagActivateButton","LeftButton") then return restore() end end
    if SaveBindings(draft.set)==false then return restore() end
    self.bindingDraft=nil
    return true
end
function F:CreateBindingControls(panel,page)
    panel.keyboardHeading=F:AddOptionsHeading(page,"Keyboard shortcut",0,-350,325)
    local description=F:AddOptionsText(page,"The key applies the next eligible self entry selected for Queue. Hold the Bypass buff modifier to use Bypass Q entries instead.",0,-380,325)
    local label=F:AddOptionsText(page,"",0,-435,325)
    F:AddOptionsText(page,"Change the primary key here. Alternate keys are kept. Click Save to apply binding changes.",0,-510,325)
    local status=F:AddOptionsText(page,"",0,-560,325)
    local capture=CreateFrame("Button","BuffRagSetBinding",page,"UIPanelButtonTemplate")
    capture:SetPoint("TOPLEFT",0,-470); capture:SetSize(145,26); capture:SetText("Set binding")
    capture:EnableKeyboard(false)
    local clear=CreateFrame("Button","BuffRagClearBinding",page,"UIPanelButtonTemplate")
    clear:SetPoint("TOPLEFT",160,-470); clear:SetSize(145,26); clear:SetText("Clear bindings")
    function panel:UpdateBindingControl()
        local keys=F.bindingDraft and F.bindingDraft.keys or currentKeys()
        local labels={}
        for _,key in ipairs(keys) do labels[#labels+1]=GetBindingText and GetBindingText(key) or key end
        label:SetText("Current: "..(#labels>0 and table.concat(labels," / ") or "Not bound")..(F:BindingDirty() and " (unsaved)" or ""))
        capture:SetEnabled(not InCombatLockdown()); clear:SetEnabled(not InCombatLockdown() and #keys>0)
    end
    function panel:CancelBindingCapture()
        capture.capturing=false; capture:EnableKeyboard(false); capture:SetText("Set binding"); status:SetText("")
    end
    capture:SetScript("OnClick",function()
        if InCombatLockdown() then return end
        if capture.capturing then panel:CancelBindingCapture(); return end
        capture.capturing=true; capture:EnableKeyboard(true); capture:SetPropagateKeyboardInput(false)
        capture:SetText("Press a key..."); status:SetText("Press a key with optional Shift, Ctrl or Alt. Escape cancels.")
    end)
    capture:SetScript("OnKeyDown",function(_,key)
        if not capture.capturing then return end
        if InCombatLockdown() or key=="ESCAPE" then panel:CancelBindingCapture(); return end
        if IsKeyPressIgnoredForBinding(key) then return end
        local chord=CreateKeyChordStringUsingMetaKeyState(key)
        local ok,reason=F:StageBuffRagBinding(chord)
        if ok then panel:CancelBindingCapture() else status:SetText(reason) end
    end)
    clear:SetScript("OnClick",function() panel:CancelBindingCapture(); F:StageBuffRagBinding(nil) end)
    capture:RegisterEvent("UPDATE_BINDINGS"); capture:RegisterEvent("PLAYER_REGEN_DISABLED")
    capture:SetScript("OnEvent",function(_,event)
        if event=="PLAYER_REGEN_DISABLED" then panel:CancelBindingCapture() end
        panel:UpdateBindingControl(); F:UpdateSaveButton()
    end)
    panel.bindingLabel,panel.bindingStatus,panel.bindingCapture=label,status,capture
    panel.bindingDescription=description
    panel.syncers[#panel.syncers+1]=function() panel:UpdateBindingControl() end
    panel:UpdateBindingControl()
end
function F:ApplyWindowScale()
    self:ApplyWindowSize(self.db.windowWidth,self.db.windowHeight)
end
function F:CreateResizeGrip(panel)
    local grip=CreateFrame("Button","BuffRagResizeGrip",panel)
    grip:SetSize(18,18); grip:SetPoint("BOTTOMRIGHT",-1,1)
    local artwork=grip:CreateTexture(nil,"OVERLAY")
    artwork:SetAllPoints(); artwork:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:EnableMouse(true)
    grip:SetScript("OnEnter",function()
        GameTooltip:SetOwner(grip,"ANCHOR_LEFT")
        GameTooltip:SetText("Drag to resize width and height independently. Controls keep their size. Save to keep the dimensions.",1,1,1)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave",function() GameTooltip:Hide() end)
    function panel:StopResizing()
        self.resizeStart=nil; grip:SetScript("OnUpdate",nil)
    end
    grip:SetScript("OnMouseDown",function(_,button)
        if button~="LeftButton" or InCombatLockdown() then return end
        local x,y=GetCursorPosition()
        local scale=panel:GetEffectiveScale()
        panel.resizeStart={x=x,y=y,width=panel:GetWidth(),height=panel:GetHeight(),scale=scale,
            left=panel:GetLeft()*scale,top=panel:GetTop()*scale}
        grip:SetScript("OnUpdate",function()
            if InCombatLockdown() or not panel:IsShown()
                or (IsMouseButtonDown and not IsMouseButtonDown("LeftButton")) then panel:StopResizing(); return end
            local start=panel.resizeStart
            local cursorX,cursorY=GetCursorPosition()
            local dx=(cursorX-start.x)/start.scale
            local dy=(start.y-cursorY)/start.scale
            F:ApplyWindowSize(start.width+dx,start.height+dy,start)
        end)
    end)
    grip:SetScript("OnMouseUp",function() panel:StopResizing() end)
    panel.resizeGrip=grip
end
