local _,F=...

function F:SetCombatModeEnabled(enabled)
    if InCombatLockdown() then return end
    self.db.combatClicks=enabled==true
    self:Refresh()
end

function F:CreateGlobalSettings(panel)
    local window=self:CreateFloatingOptions("BuffRagGlobalSettings",492,416)
    self:AddOptionsHeadingText(window,"Global Settings",12,-11)
    local close=CreateFrame("Button",nil,window,"UIPanelButtonTemplate")
    close:SetPoint("TOPRIGHT",-8,-7);close:SetSize(22,22);close:SetText("X")
    close:SetScript("OnClick",function() window:Hide() end)
    local defaults=CreateFrame("Button",nil,window,"UIPanelButtonTemplate")
    defaults:SetPoint("BOTTOMLEFT",12,9);defaults:SetSize(92,22);defaults:SetText("Defaults")
    defaults:SetScript("OnClick",function()
        F:ResetDisplayedDefaults(false,true)
        window:SetScale(panel:GetScale())
    end)
    local footer=CreateFrame("Button",nil,window,"UIPanelButtonTemplate")
    footer:SetPoint("BOTTOMRIGHT",-12,9);footer:SetSize(92,22);footer:SetText("Save")
    footer:SetScript("OnClick",function() F:SaveOptions() end)
    window.save,window.defaults=footer,defaults

    local tabs,pages={},{}
    local function selectPage(index)
        if panel.CancelBindingCapture then panel:CancelBindingCapture() end
        for i,page in ipairs(pages) do
            page:SetShown(i==index)
            F:SelectOptionsTab(tabs[i],i==index)
        end
    end
    for index,label in ipairs({"Buff Mode","Combat Mode","DR","General"}) do
        local tab=self:CreateOptionsTab(window,label,114,22)
        tab:SetPoint("TOPLEFT",12+(index-1)*118,-39)
        tab:SetScript("OnClick",function() selectPage(index) end)
        tabs[index]=tab
        local page=CreateFrame("Frame",nil,window)
        page:SetPoint("TOPLEFT",12,-75);page:SetSize(468,300)
        pages[index]=page
    end
    self:AddOptionsDivider(window,12,-61,464)
    local buffs,combat,dr,general=pages[1],pages[2],pages[3],pages[4]
    local syncers={}
    local function text(page,value,x,y,width)
        return F:AddOptionsText(page,value,x,y,width or 440)
    end
    local function check(page,name,key,label,description,y,available)
        local button=CreateFrame("CheckButton",name,page,"UICheckButtonTemplate")
        button:SetPoint("TOPLEFT",0,y);button.text:SetText(label)
        local labelText=text(page,description,30,y-24,420)
        syncers[#syncers+1]=function()
            local enabled=not available or available()
            button:SetChecked(F.db[key]);button:SetEnabled(enabled);labelText:SetAlpha(enabled and 1 or .5)
        end
        button:SetScript("OnClick",function()
            if InCombatLockdown() or (available and not available()) then return end
            if key=="combatClicks" then F:SetCombatModeEnabled(not not button:GetChecked());return end
            F.db[key]=not not button:GetChecked()
            if key=="bypassEnabled" and F.db[key] and F.db.priorityModifier=="off" then F.db.priorityModifier="ctrl" end
            if key=="drEnabled" or key=="drEstimates" then
                window:Sync();F:RefreshDR();F:UpdateSaveButton()
            else F:Refresh() end
        end)
        return button
    end
    local function modifier(name,key,title,y,allowOff)
        local label=text(buffs,title,0,y,222)
        local control=CreateFrame("DropdownButton",name,buffs,"WowStyle1DropdownTemplate")
        control:SetSize(204,24);control:SetPoint("TOPLEFT",4,y-17)
        local choices={{"Shift","shift"},{"Ctrl","ctrl"},{"Alt","alt"}}
        if allowOff then choices[#choices+1]={"Disabled","off"} end
        local function available() return allowOff or F.db.bypassEnabled end
        control:SetupMenu(function(_,root)
            for _,choice in ipairs(choices) do
                local value=choice[2]
                root:CreateRadio(choice[1],function() return F.db[key]==value end,function()
                    if InCombatLockdown() or not available() then return end
                    F.db[key]=value;F:Refresh()
                end)
            end
        end)
        syncers[#syncers+1]=function()
            for _,choice in ipairs(choices) do
                if choice[2]==F.db[key] then control:SetDefaultText(choice[1]);break end
            end
            control:SetEnabled(available());label:SetAlpha(available() and 1 or .5)
            if control.GenerateMenu then control:GenerateMenu() end
        end
    end
    local function slider(page,title,key,min,max,x,y,available)
        local name="BuffRagSlider_"..key
        local control=CreateFrame("Slider",name,page,"OptionsSliderTemplate")
        control:SetPoint("TOPLEFT",x,y);control:SetWidth(420)
        control:SetMinMaxValues(min,max);control:SetValueStep(1);control:SetObeyStepOnDrag(true)
        _G[name.."Low"]:SetText(min);_G[name.."High"]:SetText(max)
        syncers[#syncers+1]=function()
            local enabled=not available or available()
            control:SetEnabled(enabled);control:SetAlpha(enabled and 1 or .5)
            control:SetValue(F.db[key]);_G[name.."Text"]:SetText(title.." ("..F.db[key].."%)")
        end
        control:SetScript("OnValueChanged",function(_,value)
            if window.syncing or InCombatLockdown() or (available and not available()) then return end
            value=math.floor(value+.5)
            if key=="windowZoom" then F:ApplyWindowZoom(value);window:SetScale(panel:GetScale())
            else F.db[key]=value end
            if key=="drOpacity" then
                _G[name.."Text"]:SetText(title.." ("..value.."%)")
                F:RefreshDR();F:UpdateSaveButton()
            else F:Refresh() end
        end)
    end

    modifier("BuffRagFrameModifier","frameModifier","Standard queue frame modifier",0,true)
    text(buffs,"Hold this key and click a unit frame to use the next eligible entry marked Queue.",235,-3,214)
    panel.bypassCheckbox=check(buffs,"BuffRagBypassEnabled","bypassEnabled","Enable Bypass Q","Show Bypass Q in Buff Mode and Bag Items.",-54)
    modifier("BuffRagPriorityModifier","priorityModifier","Bypass Q frame modifier",-108,false)
    text(buffs,"Hold this key and click a frame to use only Bypass Q entries in list order, skipping the standard queue.",235,-111,214)
    self:CreateBindingControls(panel,buffs)

    local function combatEnabled() return F.db.combatClicks end
    check(combat,"BuffRagCombatClicks","combatClicks","Enable Combat Mode","Show your configured spell and item actions on unit frames during combat.",0)
    check(combat,"BuffRagCombatIncludeBuffs","combatIncludeBuffs","Include Buff Mode abilities","Make Buff Mode spells available when configuring friendly Combat Mode frames.",-59,combatEnabled)
    check(combat,"BuffRagCombatFeedback","combatFeedback","Show cast feedback","Show a green check for a completed cast or a red X for a failed or interrupted cast.",-118,combatEnabled)
    self:CreateCombatFeedbackExamples(combat,10,171)
    slider(combat,"Combat icon opacity","combatOpacity",0,100,5,-241,combatEnabled)
    text(combat,"Adjust combat icon brightness. Out-of-range icons use half this opacity.",0,-264)

    local function drEnabled() return F.db.drEnabled end
    check(dr,"BuffRagEnableDR","drEnabled","Enable diminishing returns (DR) tracking",
        "Show DR reset timers for hostile players on Target and Focus. A ~ marks an estimated reset time.",0)
    local opacityY=-88
    if self.class=="WARLOCK" then
        check(dr,"BuffRagDREstimates","drEstimates","Estimate from unconfirmed casts",
            "Show a rough timer for supported crowd-control casts when the game cannot confirm they landed.",-70,drEnabled)
        opacityY=-158
    end
    slider(dr,"DR icon opacity","drOpacity",0,100,5,opacityY,drEnabled)
    text(dr,"Adjust the opacity of live DR icons. Green shading identifies the layout preview.",0,opacityY-23)

    slider(general,"Window zoom","windowZoom",65,100,5,-16)
    text(general,"Resize the Buff Rag interface without changing the size of your unit-frame icons.",0,-39)
    panel.minimapCheckbox=check(general,"BuffRagMinimapEnabled","minimapEnabled","Show minimap icon","Add a Buff Rag shortcut to the minimap.",-91)
    local reset=CreateFrame("Button","BuffRagGlobalResetDefaults",general,"UIPanelButtonTemplate")
    reset:SetPoint("TOPLEFT",0,-174);reset:SetSize(165,24);reset:SetText("Global Reset Settings")
    reset:SetScript("OnClick",function() F:ResetDisplayedDefaults(true) end)
    text(general,"Restore defaults for all Buff Rag tabs, frame icons and the buff shortcut. Click Save to keep the reset.",0,-207)
    panel.globalReset=reset

    function window:Sync()
        self.syncing=true
        for _,sync in ipairs(syncers) do sync() end
        self.syncing=false
        panel:UpdateBindingControl()
    end
    window:HookScript("OnHide",function() panel:CancelBindingCapture() end)
    window.tabs,window.pages=tabs,pages
    panel.globalSettings=window
    selectPage(1)
end

function F:ToggleGlobalSettings()
    if InCombatLockdown() then return end
    local panel=self.options
    local window=panel.globalSettings
    if window:IsShown() then window:Hide();return end
    if panel.CancelCombatKeyCapture then panel:CancelCombatKeyCapture() end
    self:PositionFloatingOptions(window,panel,"CENTER",0,0)
    window:Sync()
    window:Show()
end
