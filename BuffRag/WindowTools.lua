local _, F = ...
local bindingAction="CLICK BuffRagActivateButton:LeftButton"
function F:CreateFloatingOptions(name,width,height)
    local window=CreateFrame("Frame",name,UIParent,"BackdropTemplate")
    window:SetSize(width,height)
    window:SetClampedToScreen(true)
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    window:SetBackdropColor(.07,.07,.07,1)
    window:SetBackdropBorderColor(.44,.37,.23,1)
    window:SetMovable(true)
    function window:SavePosition()
        if type(BuffRagDB)~="table" then return end
        local point,_,relativePoint,x,y=self:GetPoint()
        if type(point)~="string" or type(relativePoint)~="string"
            or type(x)~="number" or type(y)~="number" then return end
        local position={point=point,relativePoint=relativePoint,x=x,y=y}
        BuffRagDB.floatingWindowPositions=BuffRagDB.floatingWindowPositions or {}
        BuffRagDB.floatingWindowPositions[name]=position
        if F.db~=BuffRagDB then
            F.db.floatingWindowPositions=F.db.floatingWindowPositions or {}
            F.db.floatingWindowPositions[name]=F:CopySettings(position)
        end
    end
    function window:MakeDraggable(region)
        region:EnableMouse(true)
        region:RegisterForDrag("LeftButton")
        region:SetScript("OnDragStart",function() self:StartMoving() end)
        region:SetScript("OnDragStop",function() self:StopMovingOrSizing();self:SavePosition() end)
    end
    window:MakeDraggable(window)
    window:SetScript("OnHide",function() window:StopMovingOrSizing() end)
    window:Hide()
    return window
end
function F:CreateDetailOptions(name,width,height)
    local window=self:CreateFloatingOptions(name,width,height)
    local icon=window:CreateTexture(nil,"ARTWORK")
    icon:SetPoint("TOPLEFT",12,-9);icon:SetSize(26,26)
    local title=self:AddOptionsHeadingText(window,"",47,-15)
    title:SetWidth(width-95);title:SetJustifyH("LEFT")
    local line=window:CreateTexture(nil,"OVERLAY")
    line:SetPoint("TOPLEFT",12,-43);line:SetSize(width-24,1);line:SetColorTexture(1,.82,0,.35)
    local close=CreateFrame("Button",nil,window,"UIPanelButtonTemplate")
    close:SetPoint("TOPRIGHT",-8,-9);close:SetSize(22,22);close:SetText("X")
    close:SetScript("OnClick",function() window:Hide() end)
    local ok=CreateFrame("Button",nil,window,"UIPanelButtonTemplate")
    ok:SetPoint("BOTTOMRIGHT",-12,9);ok:SetSize(92,22);ok:SetText("OK")
    ok:SetScript("OnClick",function() window:Hide() end)
    window.detailIcon,window.detailTitle=icon,title
    return window,ok
end
function F:PositionFloatingOptions(window,panel,point,x,y)
    if window:IsShown() then window:Raise();return end
    window:SetScale(panel:GetScale())
    local saved=BuffRagDB and BuffRagDB.floatingWindowPositions and BuffRagDB.floatingWindowPositions[window:GetName()]
    if type(saved)=="table" and type(saved.point)=="string" and type(saved.relativePoint)=="string"
        and type(saved.x)=="number" and type(saved.y)=="number" then
        window:ClearAllPoints()
        window:SetPoint(saved.point,UIParent,saved.relativePoint,saved.x,saved.y)
        return
    end
    local centerX,centerY=panel:GetCenter()
    window:ClearAllPoints()
    if not centerX or not centerY then window:SetPoint("CENTER",UIParent,"CENTER");window:SavePosition();return end
    local ratio=panel:GetEffectiveScale()/window:GetEffectiveScale()
    if point=="TOP" then
        centerY=centerY-panel:GetHeight()/2
    elseif point=="RIGHT" then
        local left,top=panel:GetLeft(),panel:GetTop()
        if left and top then
            window:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",(left+panel:GetWidth()+x)*ratio,(top+y)*ratio)
            window:SavePosition()
            return
        end
    end
    window:SetPoint(point,UIParent,"BOTTOMLEFT",(centerX+x)*ratio,(centerY+y)*ratio)
    window:SavePosition()
end
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
    if key and self:IsCombatKeyReserved(key) then return false,"That key is already assigned to a Combat Target ability." end
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
function F:SaveOptionBindings()
    local confirmed,frames=self:CollectCombatKeyOverrides()
    if not confirmed then return false,frames end
    local unbind,bind={},{}
    for key in pairs(confirmed) do unbind[key]=true end
    if self:BindingDirty() then
        local draft=self.bindingDraft
        if GetCurrentBindingSet()~=draft.set then return false,"WoW changed the binding profile. Set the buff shortcut again." end
        for _,key in ipairs(currentKeys()) do unbind[key]=true end
        for _,key in ipairs(draft.keys) do
            local action=GetBindingAction(key)
            if confirmed[key] or (action and action~="" and action~=bindingAction) then
                return false,"The buff shortcut is now assigned to another action. Choose another key."
            end
            unbind[key]=nil
            if action~=bindingAction then bind[key]=true end
        end
    end
    if next(unbind) or next(bind) then
        local previous={}
        local function change(key,queue)
            previous[key]=GetBindingAction(key) or ""
            if queue then return SetBindingClick(key,"BuffRagActivateButton","LeftButton") end
            return SetBinding(key)
        end
        local function restore()
            for key,action in pairs(previous) do SetBinding(key,action~="" and action or nil) end
            return false,"WoW couldn't save the keybind changes. Check your keybinds and try again."
        end
        for key in pairs(unbind) do if not change(key,false) then return restore() end end
        for key in pairs(bind) do if not change(key,true) then return restore() end end
        if SaveBindings(GetCurrentBindingSet())==false then return restore() end
    end
    for _,frame in ipairs(frames) do frame.keybindOverride=nil end
    self.bindingDraft=nil
    return true
end
function F:CreateBindingControls(panel,page)
    panel.keyboardHeading=F:AddOptionsHeading(page,"Self-buff shortcut",0,-174,464)
    local description=F:AddOptionsText(page,"Press this shortcut to use the next eligible entry marked Queue on yourself.",0,-201,450)
    local label=F:AddOptionsText(page,"",0,-229,450)
    local status=F:AddOptionsText(page,"",0,-282,450)
    local capture=CreateFrame("Button","BuffRagSetBinding",page,"UIPanelButtonTemplate")
    capture:SetPoint("TOPLEFT",0,-250); capture:SetSize(145,26); capture:SetText("Set binding")
    capture:EnableKeyboard(false)
    local clear=CreateFrame("Button","BuffRagClearBinding",page,"UIPanelButtonTemplate")
    clear:SetPoint("TOPLEFT",160,-250); clear:SetSize(145,26); clear:SetText("Clear bindings")
    function panel:UpdateBindingControl()
        local keys=F.bindingDraft and F.bindingDraft.keys or currentKeys()
        local labels={}
        for _,key in ipairs(keys) do labels[#labels+1]=GetBindingText and GetBindingText(key) or key end
        label:SetText("Current: "..(#labels>0 and table.concat(labels," / ") or "Not bound")..(F:BindingDirty() and " (unsaved)" or ""))
        description:SetText("Press this shortcut to use the next eligible Queue entry on yourself."
            ..(F:BypassModifier() and " Hold the Bypass Q modifier to use that queue." or ""))
        capture:SetEnabled(not InCombatLockdown()); clear:SetEnabled(not InCombatLockdown() and #keys>0)
    end
    function panel:CancelBindingCapture()
        capture.capturing=false; capture:EnableKeyboard(false); capture:SetText("Set binding"); status:SetText("")
    end
    capture:SetScript("OnClick",function()
        if InCombatLockdown() then return end
        if panel.CancelCombatKeyCapture then panel:CancelCombatKeyCapture() end
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
    local grip=CreateFrame("Button","BuffRagResizeGrip",panel.body)
    grip:SetSize(18,18); grip:SetPoint("BOTTOMRIGHT",-1,1)
    local artwork=grip:CreateTexture(nil,"OVERLAY")
    artwork:SetAllPoints(); artwork:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:EnableMouse(true)
    grip:SetScript("OnEnter",function()
        GameTooltip:SetOwner(grip,"ANCHOR_LEFT")
        GameTooltip:AddLine("Drag to resize the Buff Rag window.",1,1,1)
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
