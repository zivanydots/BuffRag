local _, F = ...

F.debugHelp = {
    {"/brag debug", "List the available debug commands."},
    {"/brag debug cast", "Show the most recent tracked cast, its result, and the matching spell events."},
    {"/brag debug combat", "Show which Combat actions and modifiers are prepared for the Self Frame."},
    {"/brag debug dr", "Show native DR event availability for Target and Focus."},
    {"/brag debug dr start  /  /brag debug dr print", "Record Warlock Fear or Rogue Sap and readable feedback for up to 3 minutes. Print opens a copyable report."},
    {"/brag debug dr start receiver [sap]", "Record your own readable aura and combat feedback. Omit sap for Fear."},
    {"/brag debug dr mark <outcome>", "Timestamp a result you saw in game. Use immune, resist, landed or ended."},
    {"/brag debug post-combat", "Show available actions and readable debuff types for visible frames."},
    {"/brag debug preview", "Show the last error creating a Blizzard group frame preview."},
    {"/brag debug perf start", "Start a fresh recording. Tracks sustained refresh work, its causes and Combat transitions."},
    {"/brag debug perf print", "Stop recording and show recent timings in chat and a copyable window outside combat. Run again to reopen the last report."},
    {"/brag conflicts", "Recheck for addon conflicts and show the prompt if a conflict is active."},
}

function F:CreateHelpButton(panel, collapse)
    local button = CreateFrame("Button", nil, panel)
    button:SetSize(23, 23)
    button:SetPoint("RIGHT", collapse, "LEFT", -1, 0)
    local glyph = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    glyph:SetPoint("CENTER")
    button:SetFontString(glyph)
    button:SetText("?")
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText("Help Documentation")
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function()
        GameTooltip:Hide()
        F:OpenHelpDocumentation(panel)
    end)
end

function F:OpenHelpDocumentation(panel)
    if not panel.helpWindow then
        local window = self:CreateDetailOptions("BuffRagHelp", 530, 634)
        window.detailTitle:SetText("Help Documentation")
        window.detailIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        local tab = self:CreateOptionsTab(window, "Debug Commands", 126, 23)
        tab:SetPoint("TOPLEFT", 12, -51)
        self:SelectOptionsTab(tab, true)
        self:AddOptionsDivider(window, 12, -74, 506)
        for index, entry in ipairs(self.debugHelp) do
            local y = -85 - (index - 1) * 43
            self:AddOptionsHeadingText(window, entry[1], 15, y)
            self:AddOptionsText(window, entry[2], 15, y - 16, 498)
        end
        panel.helpWindow = window
    end
    self:PositionFloatingOptions(panel.helpWindow, panel, "CENTER", 0, 0)
    panel.helpWindow:Show()
end

function F:ShowPerformanceReport(report,title)
    local panel = self.options
    if not self.perfReportWindow then
        local window = self:CreateDetailOptions("BuffRagPerformanceReport", 640, 435)
        window.detailIcon:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
        self:AddOptionsText(window, "Click the report, then press Ctrl+A and Ctrl+C to copy it.", 12, -53, 598)
        local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -77)
        scroll:SetPoint("BOTTOMRIGHT", -32, 43)
        local box = CreateFrame("EditBox", nil, scroll)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:EnableMouse(true)
        box:SetFontObject(ChatFontNormal)
        box:SetWidth(590)
        box:SetScript("OnEscapePressed", function() box:ClearFocus() end)
        scroll:SetScrollChild(box)
        window.reportBox, window.reportScroll = box, scroll
        self.perfReportWindow = window
    end
    local window = self.perfReportWindow
    window.detailTitle:SetText(title or "Performance Report")
    self:PositionFloatingOptions(window, panel, "CENTER", 0, 0)
    window.reportBox:SetText(table.concat(report, "\n"))
    window.reportBox:ClearFocus()
    window.reportScroll:SetVerticalScroll(0)
    window:Show()
end
