local _, F = ...

local layouts = {
    self = {"selfPlacement","selfTopAlign","selfVertical","selfSize","selfOffset","selfIconVertical","selfGrow"},
    party = {"placement","topAlign","vertical","size","offset","iconVertical","grow"},
    raidParty = {"raidPartyPlacement","raidPartyTopAlign","raidPartyVertical","raidPartySize","raidPartyOffset","raidPartyIconVertical","raidPartyGrow"},
    raid = {"raidPlacement","raidTopAlign","raidVertical","raidSize","raidOffset","raidIconVertical","raidGrow"},
    target = {"targetPlacement","targetTopAlign","targetVertical","targetSize","targetOffset","targetIconVertical","targetGrow"},
    focus = {"focusPlacement","focusTopAlign","focusVertical","focusSize","focusOffset","focusIconVertical","focusGrow"},
}

local function sizeIsLinked(kind)
    return F.db.linkIconSizes and (kind~="raid" or F.db.linkRaidIconSize)
end

local function setLinkedSizes(size)
    for kind,keys in pairs(layouts) do
        if sizeIsLinked(kind) then F.db[keys[4]]=size end
    end
end

function F:CreateFrameIconOptions(panel)
    local window=self:CreateFloatingOptions("BuffRagFrameIconOptions",panel,492,384)
    window.scope,window.kind,window.partyStyle,window.mode="self","self","party","buffs"
    local title=CreateFrame("Frame",nil,window)
    title:SetPoint("TOPLEFT",1,-1)
    title:SetPoint("TOPRIGHT",-1,-1)
    title:SetWidth(490)
    title:SetHeight(32)
    window:MakeDraggable(title)
    self:AddOptionsHeadingText(title,"Configure Frame Icons",10,-9)
    local close=CreateFrame("Button",nil,title,"UIPanelButtonTemplate,SecureActionButtonTemplate")
    close:SetSize(22,22)
    close:SetPoint("RIGHT",-5,0)
    close:SetText("X")
    close:RegisterForClicks("LeftButtonUp")
    close:SetAttribute("useOnKeyDown",false)
    close:SetAttribute("*type1","macro")
    close:SetAttribute("*macrotext1","/cleartarget\n/clearfocus")
    close:SetScript("PostClick",function() window:Hide() end)
    local modeTabs={}
    for index,choice in ipairs({{"Buff Icons","buffs"},{"Combat Icons","combat"}}) do
        local tab=self:CreateOptionsTab(title,choice[1],86,21)
        tab:SetPoint("RIGHT",-32-(2-index)*86,0)
        tab:SetScript("OnClick",function()
            if not F.db.combatClicks then return end
            window.mode=choice[2]
            window:Sync()
            F:SetTestMode(window.mode)
        end)
        modeTabs[choice[2]]=tab
    end

    local tabs,partyTabs={},{}
    for index,choice in ipairs({{"Self","self"},{"Party","party"},{"Raid","raid"},{"Target","target"},{"Focus","focus"}}) do
        local tab=self:CreateOptionsTab(window,choice[1],90,22)
        tab:SetPoint("TOPLEFT",12+(index-1)*94,-40)
        tab:SetScript("OnClick",function()
            window.scope=choice[2]
            window:Sync()
            F:RefreshTestUI()
        end)
        tabs[choice[2]]=tab
    end
    local rule=window:CreateTexture(nil,"OVERLAY")
    rule:SetPoint("TOPLEFT",12,-62)
    rule:SetSize(466,1)
    rule:SetColorTexture(1,.82,0,.35)
    for index,choice in ipairs({{"Standard","party"},{"Raid Style","raidParty"}}) do
        local tab=self:CreateOptionsTab(window,choice[1],88,20)
        tab:SetPoint("TOPLEFT",106+(index-1)*90,-69)
        tab:SetScript("OnClick",function()
            window.partyStyle=choice[2]
            window:Sync()
            F:RefreshTestUI()
        end)
        partyTabs[choice[2]]=tab
    end

    local controls=CreateFrame("Frame",nil,window)
    controls:SetSize(466,232)
    window:MakeDraggable(controls)
    local function change(index,value)
        if window.syncing or InCombatLockdown() then return end
        local keys=layouts[window.kind]
        if index==4 and sizeIsLinked(window.kind) then setLinkedSizes(value)
        else F.db[keys[index]]=value end
        window:Sync()
        F:Refresh()
    end
    local function dropdown(label,index,x,choices)
        if label~="" then F:AddOptionsText(controls,label,x,0,210) end
        local control=CreateFrame("DropdownButton",nil,controls,"WowStyle1DropdownTemplate")
        control:SetPoint("TOPLEFT",x,-15)
        control:SetSize(211,24)
        control:SetupMenu(function(_,root)
            for _,choice in ipairs(choices) do
                local value=choice[2]
                root:CreateRadio(choice[1],function() return F.db[layouts[window.kind][index]]==value end,
                    function() change(index,value) end)
            end
        end)
        return function()
            for _,choice in ipairs(choices) do
                if F.db[layouts[window.kind][index]]==choice[2] then control:SetDefaultText(choice[1]); break end
            end
            if control.GenerateMenu then control:GenerateMenu() end
        end,control
    end
    local syncAnchor,anchorMenu=dropdown("Anchor",1,0,{{"Left","left"},{"Right","right"},{"Top","top"},{"Bottom","bottom"},{"Center","center"}})
    local syncGrow,growMenu=dropdown("Grow icons",7,244,{{"Left","left"},{"Right","right"}})
    window.raidPreviewSize=10
    local raidSizeTabs={}
    for index,size in ipairs({10,25,40}) do
        local tab=self:CreateOptionsTab(window,tostring(size),54,20)
        tab:SetPoint("TOPLEFT",200+(index-1)*57,-69)
        tab:SetScript("OnClick",function()
            window.raidPreviewSize=size
            window:Sync()
            F:RefreshTestUI()
        end)
        raidSizeTabs[size]=tab
    end
    local alignLabel=self:AddOptionsText(controls,"Alignment",244,0,210)
    local syncAlign,align=dropdown("",2,244,{{"Left","left"},{"Centre","center"},{"Right","right"}})
    local sliders={}
    local function slider(id,label,index,min,max,x,y,width)
        local name="BuffRagFrameIcon"..id
        local control=CreateFrame("Slider",name,controls,"OptionsSliderTemplate")
        control:SetPoint("TOPLEFT",x,y)
        control:SetWidth(width)
        control:SetMinMaxValues(min,max)
        control:SetValueStep(1)
        control:SetObeyStepOnDrag(true)
        _G[name.."Low"]:SetText(min)
        _G[name.."High"]:SetText(max)
        control:SetScript("OnValueChanged",function(_,value) change(index,math.floor(value+.5)) end)
        sliders[index]=function()
            local value=F.db[layouts[window.kind][index]]
            control:SetValue(value)
            _G[name.."Text"]:SetText(label..": "..value)
        end
        return control
    end
    slider("Size","Icon size",4,10,40,4,-64,207)
    slider("Horizontal","Horizontal position",5,-400,200,4,-116,450)
    slider("Vertical","Vertical position",6,-200,200,4,-167,450)
    local gap=slider("Gap","Gap from frame",3,0,80,244,-218,207)
    local linked=CreateFrame("CheckButton",nil,controls,"UICheckButtonTemplate")
    linked:SetSize(22,22)
    linked:SetPoint("TOPLEFT",244,-57)
    linked.text:SetText("Link icon sizes across frames")
    linked:SetScript("OnClick",function()
        if InCombatLockdown() then return end
        local checked=not not linked:GetChecked()
        if window.kind=="raid" then
            F.db.linkRaidIconSize=checked
            if checked then F.db.linkIconSizes=true end
        else
            F.db.linkIconSizes=checked
            if not checked then F.db.linkRaidIconSize=false end
        end
        if checked then setLinkedSizes(F.db[layouts[window.kind][4]]) end
        window:Sync()
        F:Refresh()
    end)

    local status=self:AddOptionsText(window,"",12,-320,466)
    local defaults=CreateFrame("Button",nil,window,"UIPanelButtonTemplate")
    defaults:SetSize(92,22)
    defaults:SetPoint("BOTTOMLEFT",12,9)
    defaults:SetText("Defaults")
    defaults:SetScript("OnClick",function()
        window.raidPreviewSize=10
        F:ResetFrameIconDefaults()
        window:Sync()
    end)
    local save=CreateFrame("Button",nil,window,"UIPanelButtonTemplate")
    save:SetSize(92,22)
    save:SetPoint("BOTTOMRIGHT",-12,9)
    save:SetText("Save")
    save:SetScript("OnClick",function() F:SaveFrameIconOptions() end)
    window.save=save

    function window:SyncModes()
        local enabled=F.db.combatClicks
        if not enabled then
            self.mode="buffs"
            if self:IsShown() and F.testMode=="combat" then F.testMode="buffs" end
        end
        for mode,tab in pairs(modeTabs) do
            tab:SetShown(enabled)
            F:SelectOptionsTab(tab,self.mode==mode)
        end
    end

    function window:Sync()
        self.syncing=true
        self.kind=self.scope=="party" and self.partyStyle or self.scope
        local showParty=self.scope=="party"
        local showRaid=self.scope=="raid"
        local hasSubtabs=showParty or showRaid
        controls:SetPoint("TOPLEFT",12,hasSubtabs and -103 or -78)
        self:SetHeight(hasSubtabs and 414 or 384)
        status:SetPoint("TOPLEFT",12,hasSubtabs and -350 or -320)
        for kind,tab in pairs(tabs) do F:SelectOptionsTab(tab,self.scope==kind) end
        for kind,tab in pairs(partyTabs) do
            tab:SetShown(showParty)
            F:SelectOptionsTab(tab,self.partyStyle==kind)
        end
        self:SyncModes()
        syncAnchor()
        syncGrow()
        syncAlign()
        local anchor=F.db[layouts[self.kind][1]]
        for size,tab in pairs(raidSizeTabs) do
            tab:SetShown(showRaid)
            F:SelectOptionsTab(tab,self.raidPreviewSize==size)
        end
        local verticalAnchor=anchor=="top" or anchor=="bottom"
        alignLabel:SetPoint("TOPLEFT",244,-42)
        align:SetPoint("TOPLEFT",244,-55)
        linked:SetPoint("TOPLEFT",244,verticalAnchor and -82 or -57)
        align:SetShown(verticalAnchor)
        alignLabel:SetShown(verticalAnchor)
        gap:SetShown(verticalAnchor)
        for _,sync in pairs(sliders) do sync() end
        linked:SetChecked(sizeIsLinked(self.kind))
        self.syncing=false
        self:UpdatePreviewStatus(F.frameIconPreviewKinds or {})
    end

    function window:UpdatePreviewStatus(kinds)
        local message=self.mode=="combat" and "Orange icons are previews." or "Blue icons are previews."
        if not kinds[self.kind] then
            if self.scope=="party" or self.scope=="raid" then
                message="The Blizzard frame preview could not open. Use /brag debug preview for details."
            elseif self.scope=="target" then message="Select a target to preview its icons."
            elseif self.scope=="focus" then message="Set a focus to preview its icons." end
        end
        status:SetText(message)
    end
    window:HookScript("OnHide",function()
        if panel:IsShown() then F:SetOptionsCollapsed(false) end
        if F.testUI then F:SetTestMode(nil) end
    end)
    panel.iconOptions=window
    window.modeTabs,window.frameTabs,window.partyTabs=modeTabs,tabs,partyTabs
    window.raidSizeTabs=raidSizeTabs
    window.linked=linked
    window.anchor=anchorMenu
    window.grow=growMenu
    window.close=close
    return window
end

function F:OpenFrameIconOptions()
    if InCombatLockdown() then return end
    local window=self.options.iconOptions or self:CreateFrameIconOptions(self.options)
    self:PositionFloatingOptions(window,self.options,"TOP",0,-8)
    window:Show()
    window:Sync()
    self:SetTestMode(window.mode)
end
