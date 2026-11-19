local _, F = ...
function F:SetScopeTooltip(control,scope)
    local descriptions={
        self="Add icon to your character frame.",
        party="Add icon to party frames.",
        raid="Add icon to raid frames.",
        target="Add icon to the friendly target frame.",
    }
    control:SetScript("OnEnter",function()
        GameTooltip:SetOwner(control,"ANCHOR_RIGHT")
        GameTooltip:SetText(descriptions[scope]); GameTooltip:Show()
    end)
    control:SetScript("OnLeave",function() GameTooltip:Hide() end)
end
local classCoords={
    WARRIOR={0,.25,0,.25},MAGE={.25,.5,0,.25},ROGUE={.5,.75,0,.25},DRUID={.75,1,0,.25},
    HUNTER={0,.25,.25,.5},SHAMAN={.25,.5,.25,.5},PRIEST={.5,.75,.25,.5},WARLOCK={.75,1,.25,.5},PALADIN={0,.25,.5,.75},
}
function F:AddPrimaryOptionsHeading(parent,title,x,y,width)
    local label,line=self:AddOptionsHeading(parent,title,x,y,width or 950)
    local icon=parent:CreateTexture(nil,"OVERLAY")
    icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
    local coords=(CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[self.class]) or classCoords[self.class]
    if coords then
        -- Crop the atlas tile's outer edge before applying the portrait mask.
        local insetX,insetY=(coords[2]-coords[1])*.06,(coords[4]-coords[3])*.06
        icon:SetTexCoord(coords[1]+insetX,coords[2]-insetX,coords[3]+insetY,coords[4]-insetY)
    end
    icon:SetSize(32,32); icon:SetPoint("CENTER",line,"RIGHT",950-(width or 950),0)
    local mask=parent:CreateMaskTexture(nil,"OVERLAY")
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(icon); icon:AddMaskTexture(mask)
    self.primaryHeadings=self.primaryHeadings or {}
    self.primaryHeadings[#self.primaryHeadings+1]={label=label,line=line,icon=icon,mask=mask,class=self.class}
    return label,line
end
function F:AddOptionsHeadingText(parent,title,x,y)
    local label=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    label:SetPoint("TOPLEFT",x,y); label:SetText(title)
    return label
end
function F:AddOptionsHeading(parent,title,x,y,width)
    local label=self:AddOptionsHeadingText(parent,title,x,y)
    return label,self:AddOptionsDivider(parent,x,y-18,width or 450)
end
function F:AddOptionsDivider(parent,x,y,width)
    local line=parent:CreateTexture(nil,"OVERLAY")
    -- Scroll offsets can land between physical pixels. Avoid snapping a thin
    -- rule completely out of a pixel as its parent moves through the viewport.
    line:SetSnapToPixelGrid(false); line:SetTexelSnappingBias(0)
    line:SetPoint("TOPLEFT",x,y); line:SetSize(width,1); line:SetColorTexture(1,.82,0,.35)
    self.optionUnderlines=self.optionUnderlines or {}
    self.optionUnderlines[#self.optionUnderlines+1]={line=line,parent=parent,x=x,y=y}
    self:RefreshOptionsUnderlines()
    return line
end
function F:RefreshOptionsUnderlines()
    if not PixelUtil or not PixelUtil.GetNearestPixelSize then return end
    for _,entry in ipairs(self.optionUnderlines or {}) do
        local line=entry.line
        local scale=line:GetEffectiveScale()
        -- Retain a thin line, but never let scaling round it to zero pixels.
        line:SetHeight(PixelUtil.GetNearestPixelSize(1,scale,1))
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT",entry.parent,"TOPLEFT",PixelUtil.GetNearestPixelSize(entry.x,scale),PixelUtil.GetNearestPixelSize(entry.y,scale))
    end
end
function F:AddOptionsText(parent,value,x,y,width)
    local font=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    font:SetPoint("TOPLEFT",x,y)
    -- Keep a gutter inside the scroll viewport. Text extending beyond the
    -- child width is clipped, with scale/pixel rounding changing the cutoff.
    font:SetWidth(math.max(1,math.min(width or 450,parent:GetWidth()-x-12)))
    font:SetJustifyH("LEFT"); font:SetText(value)
    return font
end
function F:SizeOptionsContent(content,height)
    content:SetHeight(height)
    local scroll=content.scroll
    if scroll and scroll.GetVerticalScroll then
        scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(),math.max(0,height-scroll:GetHeight())))
    end
end
function F:CreateTableBody(page,top,footer)
    local scroll=CreateFrame("ScrollFrame",nil,page,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",page,"TOPLEFT",0,-top)
    scroll:SetPoint("BOTTOMRIGHT",page,"BOTTOMRIGHT",-28,footer)
    local content=CreateFrame("Frame",nil,scroll)
    content:SetSize(970,1); scroll:SetScrollChild(content); content.scroll=scroll
    return content
end
function F:CreateTableFooter(page,content,getText)
    local note=self:AddOptionsText(page,"",0,0,955)
    note:ClearAllPoints(); note:SetPoint("BOTTOMLEFT",page,"BOTTOMLEFT",0,8); note:SetWidth(955)
    local function sync()
        note:SetText(getText())
        local height=math.max(58,math.ceil(note:GetStringHeight())+20)
        content.scroll:SetPoint("BOTTOMRIGHT",page,"BOTTOMRIGHT",-28,height)
        F:SizeOptionsContent(content,content:GetHeight())
    end
    self.tableFooterSyncers=self.tableFooterSyncers or {}
    self.tableFooterSyncers[#self.tableFooterSyncers+1]=sync
    sync()
    return note
end
function F:RefreshTableFooters()
    for _,sync in ipairs(self.tableFooterSyncers or {}) do sync() end
end
-- Resolve drops from cursor coordinates rather than the mouse-capturing source
-- row. This also respects the clipped viewport and its current scroll offset.
function F:EnableRowReorder(row,content,rows,stride,getID,move,available)
    row:RegisterForDrag("LeftButton")
    local source
    local function finish()
        if not source then return end
        local id=source; source=nil
        row:SetScript("OnUpdate",nil)
        if not InCombatLockdown() and available() then
            local x,y=GetCursorPosition()
            local scroll=content.scroll
            local scale=scroll:GetEffectiveScale()
            x,y=x/scale,y/scale
            local left,top=scroll:GetLeft(),scroll:GetTop()
            if left and top and x>=left and x<=left+scroll:GetWidth() and y<=top and y>=top-scroll:GetHeight() then
                local to=math.floor((content:GetTop()-y)/stride)+1
                to=math.max(1,math.min(#rows,to))
                move(id,to)
            end
        end
        F:Refresh()
    end
    row:SetScript("OnDragStart",function()
        if InCombatLockdown() or not available() then return end
        source=getID(); row:SetAlpha(.6); GameTooltip:Hide()
        row:SetScript("OnUpdate",function(_,elapsed)
            if InCombatLockdown() then source=nil; row:SetScript("OnUpdate",nil); return end
            local scroll=content.scroll
            local x,y=GetCursorPosition(); local scale=scroll:GetEffectiveScale()
            x,y=x/scale,y/scale
            local top,left=scroll:GetTop(),scroll:GetLeft()
            if not top or not left or x<left or x>left+scroll:GetWidth() then return end
            local delta=y>top-22 and -1 or (y<top-scroll:GetHeight()+22 and 1 or 0)
            local maximum=math.max(0,content:GetHeight()-scroll:GetHeight())
            scroll:SetVerticalScroll(math.max(0,math.min(maximum,scroll:GetVerticalScroll()+delta*220*elapsed)))
        end)
    end)
    row:SetScript("OnDragStop",finish)
    row:SetScript("OnMouseUp",function(_,button) if button=="LeftButton" then finish() end end)
    row:SetScript("OnHide",function()
        source=nil; row:SetScript("OnUpdate",nil)
        if GameTooltip:GetOwner()==row then GameTooltip:Hide() end
    end)
end
function F:CreateOptions()
    self.optionUnderlines={}
    self.primaryHeadings={}
    self.tableFooterSyncers={}
    local panel = CreateFrame("Frame", "BuffRagOptions", UIParent, "BasicFrameTemplateWithInset,SecureHandlerStateTemplate")
    -- Test UI contains a secure self-target button, so its protected parent
    -- must close through a secure state handler when combat begins.
    panel:SetAttribute("_onstate-combat",[[if newstate == "combat" then self:Hide() end]])
    RegisterStateDriver(panel,"combat","[combat] combat; safe")
    panel:SetSize(1040, 693)
    panel:SetScale(self.db.windowScale)
    local position = self.db.windowPosition
    if position then
        panel:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    else panel:SetPoint("CENTER") end
    panel.TitleText:SetText("Buff Rag v" .. self.version)
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function() panel:StartMoving() end)
    panel:SetScript("OnDragStop", function()
        panel:StopMovingOrSizing()
        local point, _, relativePoint, x, y = panel:GetPoint()
        F.db.windowPosition = { point = point, relativePoint = relativePoint, x = x, y = y }
        F:Refresh()
    end)
    panel:Hide()
    panel:SetScript("OnShow", function() F:BeginOptions() end)
    panel:SetScript("OnHide", function()
        if InCombatLockdown() then F:SetTestUI(false); GameTooltip:Hide(); return end
        panel:StopMovingOrSizing()
        if panel.StopResizing then panel:StopResizing() end
        if panel.itemBuffEditor then panel.itemBuffEditor:Hide() end
        if panel.CancelBindingCapture then panel:CancelBindingCapture() end
        F:SetTestUI(false)
        if not InCombatLockdown() then
            -- Let Escape finish closing existing special windows before
            -- opening the confirmation, or the same Escape closes it too.
            C_Timer.After(0, function()
                if not panel:IsShown() then F:OptionsHidden() end
            end)
        end
    end)
    panel.syncers = {}
    panel.placementControls = {}
    function panel:SyncFields()
        F:ApplyWindowScale(F.db.windowScale)
        if self.test then self.test:SetChecked(F.testUI==true) end
        for _, sync in ipairs(self.syncers) do sync() end
        self:UpdateTargetControls()
        if self.UpdateBuffRows then self:UpdateBuffRows() end
    end
    tinsert(UISpecialFrames, "BuffRagOptions")
    local banner = panel:CreateTexture(nil, "ARTWORK")
    banner:SetPoint("TOPLEFT", 12, -28)
    banner:SetSize(1016, 120)
    banner:SetTexCoord(0,1,.17,.524330709)
    if banner:SetTexture("Interface\\AddOns\\BuffRag\\Media\\Header.tga")==false then
        self:Print("Header texture could not be loaded. Reinstall the full BuffRag folder and restart WoW.")
    end
    local wordmark=panel:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    wordmark:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",52,"OUTLINE")
    wordmark:SetText("Buff Rag"); wordmark:SetTextColor(1,.82,0)
    wordmark:SetPoint("CENTER",banner,"CENTER",0,0)
    wordmark:SetShadowColor(0,0,0,1); wordmark:SetShadowOffset(2,-2)
    panel.banner,panel.wordmark=banner,wordmark
    local credit=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    credit:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",14,"OUTLINE")
    credit:SetText("By Zivany Dots")
    credit:SetPoint("TOPLEFT",wordmark,"BOTTOMLEFT",0,-2)
    credit:SetJustifyH("LEFT")
    credit:SetShadowColor(0,0,0,1); credit:SetShadowOffset(1,-1)
    panel.bannerCredit=credit
    local function text(parent,value,x,y,width) return F:AddOptionsText(parent,value,x,y,width) end
    local pages, tabs = {}, {}
    local function selectTab(index)
        if panel.itemBuffEditor then panel.itemBuffEditor:Hide() end
        if panel.CancelBindingCapture then panel:CancelBindingCapture() end
        panel.selectedTab = index
        for i, page in ipairs(pages) do
            page:SetShown(i == index)
            tabs[i]:SetEnabled(i ~= index)
        end
    end
    for i, name in ipairs({ "Buffs", "Pots / Items", "Settings", "Frame Placement", "Icon Placement" }) do
        local index = i
        local page = CreateFrame("Frame", nil, panel)
        page:SetPoint("TOPLEFT", 20, -199)
        page:SetPoint("BOTTOMRIGHT", -20, 60)
        pages[i] = page
        local tab = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        tab:SetSize(196, 28)
        tab:SetPoint("TOPLEFT", 20 + (i - 1) * 201, -159)
        tab:SetText(name)
        tab:SetScript("OnClick", function() selectTab(index) end)
        tabs[i] = tab
    end
    panel.pages, panel.tabs = pages, tabs
    -- Banner -> tabs and divider -> page content both have an 11px gap.
    -- The one-pixel rule directly adjoins the bottom edge of the tab buttons.
    panel.tabDivider=self:AddOptionsDivider(panel,20,-187,1000)
    local gated = {}
    local function gate(control, enabled, label)
        gated[#gated + 1] = {control=control, enabled=enabled, label=label}
        return control
    end
    local function check(parent, name, value, x, y, getter, setter, available)
        local button = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
        button:SetPoint("TOPLEFT", x, y)
        button.text:SetText(value)
        button.text:SetWidth(math.max(1,math.min(450,parent:GetWidth()-x-44)))
        button.text:SetJustifyH("LEFT")
        local function sync() button:SetChecked(getter()) end
        button:SetScript("OnShow", sync)
        panel.syncers[#panel.syncers+1] = sync
        button:SetScript("OnClick", function()
            if InCombatLockdown() or (available and not available()) then button:SetChecked(getter()); return end
            setter(button:GetChecked()); F:Refresh()
        end)
        if available then gate(button, available) end
        return button
    end
    local function dropdown(parent, name, titleText, key, choices, x, y, available, placeholder)
        local label = text(parent, titleText, x, y)
        local control = CreateFrame("DropdownButton", name, parent, "WowStyle1DropdownTemplate")
        control.label = label
        control:SetPoint("TOPLEFT", x, y - 24)
        control:SetWidth(math.max(1,math.min(450,parent:GetWidth()-x-12)))
        control:SetDefaultText(placeholder or choices[1][1])
        control:SetupMenu(function(_, root)
            for _, entry in ipairs(choices) do
                root:CreateRadio(entry[1], function(v) return F.db[key] == v end, function(v)
                    if InCombatLockdown() or (available and not available()) then return end
                    F.db[key] = v; F:Refresh()
                end, entry[2])
            end
        end)
        panel.syncers[#panel.syncers+1] = function()
            if control.GenerateMenu then control:GenerateMenu() end
        end
        if available then gate(control, available, label) end
        return control
    end

    local buffs,pots,settings,layout,ui = pages[1],pages[2],pages[3],pages[4],pages[5]
    local function scrollContent(page,height)
        local scroll=CreateFrame("ScrollFrame",nil,page,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT"); scroll:SetPoint("BOTTOMRIGHT",-28,0)
        local content=CreateFrame("Frame",nil,scroll)
        content:SetSize(970,height); scroll:SetScrollChild(content); content.scroll=scroll
        return content
    end
    settings=scrollContent(settings,650)
    layout,ui=scrollContent(layout,650),scrollContent(ui,790)
    panel.buffContent,panel.itemContent=buffs,pots
    panel.layoutContent,panel.iconContent=layout,ui
    local function heading(parent,title,x,y,width) return F:AddOptionsHeading(parent,title,x,y,width) end
    function panel:UpdateTargetControls()
        for _,entry in ipairs(gated) do
            local enabled=entry.enabled()
            entry.control:SetEnabled(enabled); entry.control:SetAlpha(enabled and 1 or .4)
            if entry.label then entry.label:SetAlpha(enabled and 1 or .4) end
        end
        for _,entry in ipairs(self.placementControls) do
            local shown=entry.visible()
            entry.control:SetShown(shown)
            if entry.control.label then entry.control.label:SetShown(shown) end
        end
        if self.UpdatePlacementLayout then self:UpdatePlacementLayout() end
    end
    local function slider(titleText, key, minimum, maximum, x, y, parent, available)
        local control = CreateFrame("Slider", "BuffRagSlider_" .. key, parent or ui, "OptionsSliderTemplate")
        control:SetPoint("TOPLEFT", x, y)
        control:SetWidth(420)
        control:SetMinMaxValues(minimum, maximum)
        control:SetValueStep(1)
        control:SetObeyStepOnDrag(true)
        local name = control:GetName()
        _G[name .. "Low"]:SetText(minimum)
        _G[name .. "High"]:SetText(maximum)
        local syncing = false
        local function sync()
            syncing = true; control:SetValue(F.db[key])
            _G[name .. "Text"]:SetText(titleText .. ": " .. F.db[key]); syncing = false
        end
        control:SetScript("OnShow", sync)
        panel.syncers[#panel.syncers+1] = sync
        control:SetScript("OnValueChanged", function(_, value)
            if syncing or InCombatLockdown() then return end
            if available and not available() then return end
            value = math.floor(value + .5)
            F.db[key] = value
            _G[name .. "Text"]:SetText(titleText .. ": " .. value)
            F:Refresh()
        end)
        if available then gate(control, available) end
        return control
    end

    F:AddPrimaryOptionsHeading(settings,"General",0,0)
    text(settings,"Class: "..(LOCALIZED_CLASS_NAMES_MALE[F.class] or F.class)..". Settings are saved for this character.",0,-30,955)
    dropdown(settings,"BuffRagFrameModifier","Queue frame buff modifier","frameModifier",{
        {"Shift","shift"},{"Ctrl","ctrl"},{"Alt","alt"},{"Disabled","off"},
    },0,-65)
    text(settings,"Hold the modifier and left-click a Blizzard unit frame to apply the next eligible buff in your list.",0,-135,450)
    heading(settings,"Combat",500,-65,450)
    check(settings,"BuffRagCombatClicks","Enable in combat",500,-90,
        function() return F.db.combatClicks end,function(v) F.db.combatClicks=v end)
    text(settings,"Combat casting icons are protected, so they stay in place instead of disappearing after a successful cast. For spell and Pots / Items icons: green tick = cast completed; red cross = failed/interrupted. A tick confirms the cast, not an active buff or resurrection.",500,-130,450)
    self:CreateCombatFeedbackExamples(settings)
    text(settings,"A yellow ? means awaiting or unavailable confirmation; restricted or missing events are never guessed. Hover a red cross to clear it, then click to retry. Marks clear and icons refresh when combat ends.",500,-250,450)
    slider("Combat opacity (%)","combatOpacity",0,100,510,-335,settings)
    dropdown(settings,"BuffRagPriorityModifier","Priority Q frame buff modifier","priorityModifier",{
        {"Ctrl (default)","ctrl"},{"Alt","alt"},{"Shift","shift"},{"Disabled","off"},
    },0,-190)
    text(settings,F:PriorityHelp().." Choose different modifiers for the two queues; if they match, Priority takes precedence.",0,-265,450)
    text(settings,"Buff choices and item order are edited on their tabs. Save keeps the changes; closing the window lets you save or discard them.",500,-520,450)
    heading(settings,"Minimap",500,-420,450)
    panel.minimapCheckbox=check(settings,"BuffRagMinimapEnabled","Enable minimap icon",500,-445,
        function() return F.db.minimapEnabled~=false end,function(v) F.db.minimapEnabled=v end)
    local function iconGroup(title,sizeKey,offsetKey,verticalKey,x,y)
        if x==0 and y==0 then F:AddPrimaryOptionsHeading(ui,title,x,y,450)
        else heading(ui,title,x,y) end
        slider("Icon size",sizeKey,10,40,x+10,y-45)
        slider("Horizontal position",offsetKey,-400,200,x+10,y-110)
        slider("Vertical position",verticalKey,-200,200,x+10,y-175)
    end
    iconGroup("Self frame","selfSize","selfOffset","selfIconVertical",0,0)
    iconGroup("Standard party frames","size","offset","iconVertical",500,0)
    iconGroup("Raid style party frames","raidPartySize","raidPartyOffset","raidPartyIconVertical",0,-250)
    iconGroup("Raid Frames","raidSize","raidOffset","raidIconVertical",500,-250)
    iconGroup("Target frame","targetSize","targetOffset","targetIconVertical",0,-500)
    heading(ui,"Shared icon settings",500,-510,450)
    slider("Icon spacing","spacing",0,15,510,-555)
    text(ui,"Out-of-range icons use 50% opacity. Target icons are hidden in combat because the selected target can change.",500,-620,450)
    local alignments={{"Left","left"},{"Centre","center"},{"Right","right"}}
    local positions={{"Right of frame","right"},{"Above frame","top"}}
    local raidPositions={{"Right of frame","right"},{"Above frame","top"},{"On frame (overlay)","overlay"}}
    local groups={}
    local function frameGroup(title,name,key,alignName,alignKey,gapKey,choices)
        local group=CreateFrame("Frame",nil,layout)
        group:SetSize(450,230)
        if #groups==0 then F:AddPrimaryOptionsHeading(group,title,0,0,450)
        else heading(group,title,0,0) end
        dropdown(group,name,"Position",key,choices,0,-25)
        local alignment=dropdown(group,alignName,"Frame alignment",alignKey,alignments,0,-95)
        local gap=slider("Gap above frame",gapKey,0,80,10,-185,group)
        group.placementKey=key
        groups[#groups+1]=group
        panel.placementControls[#panel.placementControls+1]={control=alignment,visible=function() return F.db[key]~="right" end}
        panel.placementControls[#panel.placementControls+1]={control=gap,visible=function() return F.db[key]=="top" end}
        return group
    end
    frameGroup("Self frame","BuffRagSelfPlacement","selfPlacement","BuffRagSelfAlign","selfTopAlign","selfVertical",positions)
    frameGroup("Standard party frames","BuffRagPartyPlacement","placement","BuffRagPartyAlign","topAlign","vertical",positions)
    frameGroup("Raid style party frames","BuffRagRaidPartyPlacement","raidPartyPlacement","BuffRagRaidPartyAlign","raidPartyTopAlign","raidPartyVertical",raidPositions)
    frameGroup("Raid Frames","BuffRagRaidPlacement","raidPlacement","BuffRagRaidAlign","raidTopAlign","raidVertical",raidPositions)
    frameGroup("Target frame","BuffRagTargetPlacement","targetPlacement","BuffRagTargetAlign","targetTopAlign","targetVertical",positions)
    panel.framePlacementGroups=groups
    function panel:UpdatePlacementLayout()
        local bottom={0,0}
        for index,group in ipairs(groups) do
            local column=(index-1)%2+1
            local mode=F.db[group.placementKey]
            local height=mode=="top" and 230 or (mode=="overlay" and 165 or 90)
            group:ClearAllPoints(); group:SetPoint("TOPLEFT",layout,"TOPLEFT",(column-1)*500,-bottom[column])
            group:SetHeight(height); bottom[column]=bottom[column]+height+25
        end
        F:SizeOptionsContent(layout,math.max(bottom[1],bottom[2]))
    end
    F:SizeOptionsContent(ui,740)
    local reset = CreateFrame("Button", "BuffRagResetDefaults", panel, "UIPanelButtonTemplate")
    reset:SetSize(150, 24)
    reset:SetPoint("BOTTOMLEFT", 20, 20)
    reset:SetText("Default settings")
    reset:SetScript("OnClick", function() F:ResetDefaults() end)
    local save = CreateFrame("Button", "BuffRagSaveOptions", panel, "UIPanelButtonTemplate")
    save:SetSize(150,24)
    save:SetPoint("BOTTOMRIGHT", -20,20)
    save:SetText("Save")
    save:SetScript("OnClick", function() F:SaveOptions() end)
    local test = CreateFrame("CheckButton", "BuffRagTestUI", panel, "UICheckButtonTemplate,SecureActionButtonTemplate")
    test:SetPoint("BOTTOM", -30, 16)
    test.text:SetText("Test UI")
    test:RegisterForClicks("LeftButtonUp")
    test:SetAttribute("useOnKeyDown",false)
    test:SetAttribute("unit","player")
    test:SetAttribute("checkselfcast",false)
    test:SetAttribute("checkfocuscast",false)
    test:SetAttribute("type1","target")
    test:SetScript("PreClick",function(button)
        if InCombatLockdown() then return end
        -- Enabling selects self through Blizzard's secure action handler.
        -- Disabling leaves the player's current target alone.
        button:SetAttribute("type1",not F.testUI and "target" or "")
    end)
    test:SetScript("PostClick",function()
        if not InCombatLockdown() then
            F:SetTestUI(not F.testUI)
            C_Timer.After(0,function() if F.testUI then F:Refresh() end end)
        end
    end)
    test:SetScript("OnEnter",function()
        GameTooltip:SetOwner(test,"ANCHOR_TOP"); GameTooltip:SetText("Test UI")
        GameTooltip:AddLine("Targets your character and previews icon placement. Sample target icons appear if no target entries are selected. Preview only; no buffs or items are used.",.8,.8,.8,true); GameTooltip:Show()
    end)
    test:SetScript("OnLeave",function() GameTooltip:Hide() end)
    panel.test = test
    panel.save = save
    panel:UpdateTargetControls()
    selectTab(1)
    self.options = panel
    self:CreateBindingControls(panel,settings)
    self:CreateItemsPage(panel,pots)
    self:CreateBuffList(panel,buffs)
    self:CreateResizeGrip(panel)

    self:UpdateSaveButton()
end
