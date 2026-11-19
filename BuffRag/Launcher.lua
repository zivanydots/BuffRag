local _, F = ...

function F:ToggleOptions()
    if not self.db or not self.options then return end
    if InCombatLockdown() then self:Print("Settings are available out of combat."); return end
    self.options:SetShown(not self.options:IsShown())
end

function F:OpenOptions()
    if not self.db or not self.options then return end
    if InCombatLockdown() then self:Print("Settings are available out of combat."); return end
    if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then HideUIPanel(SettingsPanel) end
    if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() and HideUIPanel then HideUIPanel(InterfaceOptionsFrame) end
    self.options:Show()
end

function F:LauncherTooltip(tooltip)
    tooltip:SetText("Buff Rag")
    tooltip:AddLine("Left Click: Open Settings",1,1,1)
    tooltip:AddLine("Middle Click: Disable Minimap Icon",1,1,1)
    local function line(modifier,queue)
        if modifier=="off" then return queue..": frame modifier disabled" end
        return modifier:upper().." + left-click frame: "..queue
    end
    tooltip:AddLine(line(self.db.frameModifier,"standard queue"),1,1,1)
    tooltip:AddLine(line(self.db.priorityModifier,"priority queue"),1,1,1)
end

function F:SyncMinimapVisibility()
    if not self.minimapButton then return end
    local icons=LibStub("LibDBIcon-1.0")
    local enabled=self.db.minimapEnabled~=false
    BuffRagMinimapDB.hide=not enabled
    if self.minimapButton:IsShown()~=enabled then
        if enabled then icons:Show("BuffRag") else icons:Hide("BuffRag") end
    end
end

function F:DisableMinimapIcon()
    self.db.minimapEnabled=false
    BuffRagDB.minimapEnabled=false
    self:SyncMinimapVisibility()
    LibStub("LibDBIcon-1.0").tooltip:Hide()
    if self.options.minimapCheckbox then self.options.minimapCheckbox:SetChecked(false) end
    self:UpdateSaveButton()
end

function F:CreateLauncher()
    if self.minimapButton or self.addonOptionsPage then return end
    -- A separate saved table keeps library drag updates independent of drafts
    -- and stable when Save replaces BuffRagDB.
    if type(BuffRagMinimapDB)~="table" then BuffRagMinimapDB={minimapPos=tonumber(self.db.minimapAngle) or 225} end
    local broker=LibStub("LibDataBroker-1.1"):NewDataObject("BuffRag",{
        type="launcher",label="Buff Rag",
        icon="Interface\\AddOns\\BuffRag\\Media\\Icon.tga",
        OnClick=function(_,button)
            if button=="LeftButton" then F:OpenOptions()
            elseif button=="MiddleButton" then F:DisableMinimapIcon() end
        end,
        OnTooltipShow=function(tooltip) F:LauncherTooltip(tooltip) end,
    })
    local icons=LibStub("LibDBIcon-1.0")
    icons:Register("BuffRag",broker,BuffRagMinimapDB)
    self.minimapButton=icons:GetMinimapButton("BuffRag")
    self.launcherBroker=broker
    self:SyncMinimapVisibility()

    -- Inherit the native translucent background with a subtle gold base.
    local page=CreateFrame("Frame","BuffRagAddonOptions",UIParent)
    page.name="Buff Rag"; page:Hide()
    local gradient=page:CreateTexture(nil,"BACKGROUND")
    gradient:SetAllPoints(page); gradient:SetColorTexture(1,1,1,1)
    gradient:SetGradient("VERTICAL",CreateColor(.55,.30,0,.4),CreateColor(.55,.30,0,0))
    self.addonOptionsGradient=gradient
    local function label(value,size,point,relativePoint,x,y)
        local font=page:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        font:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",size)
        font:SetTextColor(1,.82,0); font:SetText(value)
        font:SetPoint(point,page,relativePoint,x,y)
        return font
    end
    label("Buff Rag",64,"TOP","TOP",0,-70)
    label("Forever",30,"TOP","TOP",0,-145)
    local open=CreateFrame("Button","BuffRagOpenOptions",page,"UIPanelButtonTemplate")
    open:SetSize(170,30); open:SetPoint("CENTER",page,"CENTER",0,0); open:SetText("Open Options")
    open:SetScript("OnClick",function() F:OpenOptions() end)
    self.addonOptionsOpenButton=open
    label("/brag",52,"CENTER","CENTER",0,-125)
    label("curseforge.com/wow/addons/buffrag",22,"BOTTOM","BOTTOM",0,65)
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category=Settings.RegisterCanvasLayoutCategory(page,page.name)
        Settings.RegisterAddOnCategory(category)
        self.addonOptionsCategory=category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(page)
    end
    self.addonOptionsPage=page
end
