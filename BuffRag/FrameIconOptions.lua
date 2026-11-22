local _, F = ...

local layouts = F.frameIconLayouts

local function sizeIsLinked(kind)
    return kind~="drTarget" and kind~="drFocus" and F.db.linkIconSizes and (kind~="raid" or F.db.linkRaidIconSize)
end

local function setLinkedSizes(size)
    for kind,keys in pairs(layouts) do
        if sizeIsLinked(kind) then F.db[keys[4]]=size end
    end
end

function F:CreateFrameIconOptions(panel)
    local window=self:CreateFloatingOptions("BuffRagFrameIconOptions",492,408)
    window.scope,window.kind,window.partyStyle,window.mode="self","self","party","buffs"
    window.drScope="target"
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
    for index,choice in ipairs({{"Buff Mode","buffs"},{"Combat Mode","combat"},{"DR","dr"}}) do
        local tab=self:CreateOptionsTab(title,choice[1],choice[2]=="dr" and 40 or 86,21)
        tab:SetPoint("RIGHT",-32-(index<3 and 42+(2-index)*86 or 0),0)
        tab:SetScript("OnClick",function()
            if choice[2]=="combat" and not F.db.combatClicks then return end
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
            if window.mode=="dr" then window.drScope=choice[2]
            else window.scope=choice[2] end
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
    controls:SetSize(466,256)
    window:MakeDraggable(controls)
    local function change(index,value)
        if window.syncing or InCombatLockdown() then return end
        local keys=layouts[window.kind]
        if index==4 and sizeIsLinked(window.kind) then setLinkedSizes(value)
        else F.db[keys[index]]=value end
        F:NormalizeFrameIconOffsets(F.db,window.kind)
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
            if control.SignalUpdate then control:SignalUpdate() end
        end,control
    end
    local syncAnchor,anchorMenu=dropdown("Anchor",1,0,{{"Left","left"},{"Right","right"},{"Top","top"},{"Bottom","bottom"},{"Center","center"}})
    local syncGrow,growMenu=dropdown("Icon stack grow direction",7,244,{{"Left","left"},{"Right","right"}})
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
    local function closeMenu(control)
        if control.IsMenuOpen and control:IsMenuOpen() then control:CloseMenu() end
    end
    local function closeMenus()
        closeMenu(anchorMenu)
        closeMenu(growMenu)
        closeMenu(align)
    end
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
        control:SetScript("OnValueChanged",function(_,value)
            local reverse=index==5 and F.db[layouts[window.kind][1]]=="left"
            change(index,math.floor((reverse and -value or value)+.5))
        end)
        sliders[index]=function()
            local keys=layouts[window.kind]
            local anchor=F.db[keys[1]]
            local value=F.db[keys[index]]
            if index==5 or index==6 then
                local minX,maxX,minY,maxY=F:FrameIconOffsetBounds(anchor,F.db[keys[3]])
                local low,high=minY,maxY
                if index==5 then
                    low,high=minX,maxX
                    if anchor=="left" then low,high,value=-maxX,-minX,-value end
                end
                control:SetMinMaxValues(low,high)
                _G[name.."Low"]:SetText(low)
                _G[name.."High"]:SetText(high)
            end
            control:SetValue(value)
            _G[name.."Text"]:SetText(label..": "..value)
        end
        return control
    end
    local sizeSlider=slider("Size","Icon size",4,10,40,4,-74,207)
    local dragNote=self:AddOptionsText(controls,"Click a preview icon to select its frame. Drag to position.",4,-115,450)
    slider("Horizontal","Horizontal position",5,-400,200,4,-148,450)
    slider("Vertical","Vertical position",6,-200,200,4,-199,450)
    local gap=slider("Gap","Gap from frame",3,0,80,244,-239,207)
    local linked=CreateFrame("CheckButton",nil,controls,"UICheckButtonTemplate")
    linked:SetSize(22,22)
    linked:SetPoint("LEFT",sizeSlider,"RIGHT",33,0)
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

    local status=self:AddOptionsText(controls,"",4,-218,225)
    local legend=self:AddOptionsText(window,"Blue icons indicate the enabled buff icon layout, while orange icons indicate the enabled combat icon layout.",12,-344,466)
    local defaults=CreateFrame("Button",nil,window,"UIPanelButtonTemplate")
    defaults:SetSize(92,22)
    defaults:SetPoint("BOTTOMLEFT",12,9)
    defaults:SetText("Defaults")
    defaults:SetScript("OnClick",function()
        window.raidPreviewSize=10
        F:ResetFrameIconDefaults()
        window:Sync()
    end)
    local reset=CreateFrame("Button",nil,window,"UIPanelButtonTemplate")
    reset:SetSize(92,22)
    reset:SetPoint("BOTTOM",0,9)
    reset:SetText("Reset")
    reset:SetScript("OnClick",function()
        if InCombatLockdown() or not window.sessionOptions then return end
        window:SetScript("OnUpdate",nil)
        F:CopyFrameIconOptions(window.sessionOptions,F.db)
        window.raidPreviewSize=window.sessionRaidPreviewSize
        window:Sync()
        F:Refresh()
    end)
    local save=CreateFrame("Button",nil,window,"UIPanelButtonTemplate")
    save:SetSize(92,22)
    save:SetPoint("BOTTOMRIGHT",-12,9)
    save:SetText("Save")
    save:SetScript("OnClick",function() F:SaveFrameIconOptions() end)
    window.save=save

    function window:StartIconDrag(row)
        if InCombatLockdown() or not F.testUI then return end
        local kind=row.previewKind
        if kind~=self.kind then
            if self.mode=="dr" then self.drScope=kind=="drFocus" and "focus" or "target"
            elseif kind=="party" or kind=="raidParty" then self.scope,self.partyStyle="party",kind
            else self.scope=kind end
            self:Sync()
            F:RefreshTestUI()
        end
        local keys=layouts[kind]
        local x,y=GetCursorPosition()
        local scale=row:GetEffectiveScale()
        local baseX,baseY=F.db[keys[5]],F.db[keys[6]]
        local direction=F.db[keys[1]]=="left" and -1 or 1
        local changed=false
        self:SetScript("OnUpdate",function()
            if InCombatLockdown() or self.kind~=kind or not IsMouseButtonDown("LeftButton") then
                self:SetScript("OnUpdate",nil)
                if changed and not InCombatLockdown() then F:Refresh() end
                return
            end
            local cursorX,cursorY=GetCursorPosition()
            local oldX,oldY=F.db[keys[5]],F.db[keys[6]]
            F.db[keys[5]]=math.floor(baseX+(cursorX-x)/scale*direction+.5)
            F.db[keys[6]]=math.floor(baseY+(cursorY-y)/scale+.5)
            F:NormalizeFrameIconOffsets(F.db,kind)
            if F.db[keys[5]]==oldX and F.db[keys[6]]==oldY then return end
            changed=true
            self.syncing=true
            sliders[5]();sliders[6]()
            self.syncing=false
            for frame,preview in pairs(F.previews) do
                if preview.previewKind==kind and preview:IsShown() then F:PositionIconRow(preview,frame,F:FrameLayout(frame,kind)) end
            end
        end)
    end

    function window:SyncModes()
        local enabled=F.db.combatClicks
        if not enabled and self.mode=="combat" then
            self.mode="buffs"
            if self:IsShown() and F.testMode=="combat" then F.testMode="buffs" end
        end
        if self.syncedMode~=self.mode then
            closeMenus()
            self.syncedMode=self.mode
        end
        for mode,tab in pairs(modeTabs) do
            tab:SetShown(enabled or mode~="combat")
            F:SelectOptionsTab(tab,self.mode==mode)
        end
        modeTabs.buffs:ClearAllPoints()
        modeTabs.buffs:SetPoint("RIGHT",-32-42-(enabled and 86 or 0),0)
    end

    function window:Sync()
        self.syncing=true
        self:SyncModes()
        local dr=self.mode=="dr"
        local kind=dr and F.drLayoutKinds[self.drScope] or (self.scope=="party" and self.partyStyle or self.scope)
        if kind~=self.kind then closeMenus() end
        self.kind=kind
        local showParty=not dr and self.scope=="party"
        local showRaid=not dr and self.scope=="raid"
        local hasSubtabs=showParty or showRaid
        controls:SetPoint("TOPLEFT",12,hasSubtabs and -103 or -78)
        self:SetHeight(hasSubtabs and 438 or 408)
        legend:SetPoint("TOPLEFT",12,hasSubtabs and -374 or -344)
        for index,scope in ipairs({"self","party","raid","target","focus"}) do
            local tab=tabs[scope]
            local show=not dr or F.drLayoutKinds[scope]~=nil
            tab:SetShown(show)
            if show then
                tab:ClearAllPoints()
                tab:SetPoint("TOPLEFT",12+(index-(dr and 4 or 1))*94,-40)
                F:SelectOptionsTab(tab,(dr and self.drScope or self.scope)==scope)
            end
        end
        for kind,tab in pairs(partyTabs) do
            tab:SetShown(showParty)
            F:SelectOptionsTab(tab,self.partyStyle==kind)
        end
        linked:SetShown(not dr)
        legend:SetText(dr and "Green icons preview the DR layout. Change tracking and live opacity in Global Settings."
            or "Blue icons indicate the enabled buff icon layout, while orange icons indicate the enabled combat icon layout.")
        syncAnchor()
        syncGrow()
        local anchor=F.db[layouts[self.kind][1]]
        for size,tab in pairs(raidSizeTabs) do
            tab:SetShown(showRaid)
            F:SelectOptionsTab(tab,self.raidPreviewSize==size)
        end
        local verticalAnchor=anchor=="top" or anchor=="bottom"
        if not verticalAnchor then closeMenu(align) end
        alignLabel:SetPoint("TOPLEFT",244,-42)
        align:SetPoint("TOPLEFT",244,-55)
        sizeSlider:SetPoint("TOPLEFT",4,verticalAnchor and -86 or -74)
        dragNote:SetPoint("TOPLEFT",4,verticalAnchor and -127 or -115)
        align:SetShown(verticalAnchor)
        alignLabel:SetShown(verticalAnchor)
        gap:SetShown(verticalAnchor)
        if verticalAnchor then syncAlign() end
        for _,sync in pairs(sliders) do sync() end
        linked:SetChecked(sizeIsLinked(self.kind))
        self.syncing=false
        self:UpdatePreviewStatus(F.frameIconPreviewKinds or {})
    end

    function window:UpdatePreviewStatus(kinds)
        local message=""
        if not kinds[self.kind] then
            local scope=self.mode=="dr" and self.drScope or self.scope
            if scope=="party" or scope=="raid" then
                message="The Blizzard frame preview could not open. Use /brag debug preview for details."
            elseif scope=="target" then message="Select a target to preview its icons."
            elseif scope=="focus" then message="Set a focus to preview its icons." end
        end
        status:SetText(message)
    end
    window:HookScript("OnHide",function()
        closeMenus()
        window:SetScript("OnUpdate",nil)
        if panel:IsShown() then F:SetOptionsCollapsed(false) end
        if F.testUI then F:SetTestMode(nil) end
    end)
    panel.iconOptions=window
    window.modeTabs,window.frameTabs,window.partyTabs=modeTabs,tabs,partyTabs
    window.raidSizeTabs=raidSizeTabs
    window.linked=linked
    window.anchor=anchorMenu
    window.grow=growMenu
    window.align=align
    window.close=close
    return window
end

function F:OpenFrameIconOptions()
    if InCombatLockdown() then return end
    local window=self.options.iconOptions or self:CreateFrameIconOptions(self.options)
    if not window:IsShown() then
        window.sessionOptions={}
        window.sessionRaidPreviewSize=window.raidPreviewSize
        self:CopyFrameIconOptions(self.db,window.sessionOptions)
    end
    self:PositionFloatingOptions(window,self.options,"TOP",0,-8)
    window:Show()
    window:Sync()
    self:SetTestMode(window.mode)
end
