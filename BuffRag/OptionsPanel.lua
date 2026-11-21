local _, F = ...
function F:CreateOptionsTab(parent,title,width,height)
    local tab=CreateFrame("Button",nil,parent)
    tab:SetSize(width,height)
    tab.background=tab:CreateTexture(nil,"BACKGROUND");tab.background:SetAllPoints();tab.background:SetColorTexture(.22,.21,.18,1)
    tab.selected=tab:CreateTexture(nil,"ARTWORK");tab.selected:SetAllPoints();tab.selected:SetColorTexture(.42,.04,.025,1)
    tab.label=tab:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");tab.label:SetPoint("CENTER");tab:SetFontString(tab.label);tab:SetText(title)
    local highlight=tab:CreateTexture(nil,"HIGHLIGHT");highlight:SetAllPoints();highlight:SetColorTexture(1,1,1,.07);tab:SetHighlightTexture(highlight)
    return tab
end
function F:SelectOptionsTab(tab,selected)
    tab.selected:SetShown(selected);tab:SetEnabled(not selected)
    tab.label:SetTextColor(1,selected and .82 or 1,selected and 0 or 1)
end
function F:CenterItemPlaceholder(row,nameStart,firstMove)
    row.configured:ClearAllPoints()
    row.configured:SetPoint("LEFT",row,"LEFT",nameStart+row.label:GetStringWidth()+16,0)
    row.configured:SetPoint("RIGHT",firstMove,"LEFT",-12,0)
    row.configured:SetJustifyH("CENTER")
end
function F:SetScopeTooltip(control,scope)
    local descriptions={
        self="Add icon to your character frame.",
        party="Add icon to party frames.",
        raid="Add icon to raid frames.",
        target="Add icon to the friendly target frame.",
        focus="Add icon to the friendly focus frame.",
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
function F:AddPrimaryOptionsHeading(parent,title,x,y)
    local label,line=self:AddOptionsHeading(parent,title,x,y,950)
    self.primaryHeadings=self.primaryHeadings or {}
    self.primaryHeadings[#self.primaryHeadings+1]={label=label,line=line,class=self.class}
    return label,line
end
function F:CreateClassPortrait(panel)
    local frame=CreateFrame('Frame',nil,panel)
    frame:SetSize(76,76);frame:SetPoint('TOPLEFT',panel,'TOPLEFT',-12,12)
    frame:SetFrameLevel(panel:GetFrameLevel()+3)
    local function circle(size,layer,r,g,b)
        local texture=frame:CreateTexture(nil,layer)
        texture:SetSize(size,size);texture:SetPoint('CENTER');texture:SetColorTexture(r,g,b,1)
        local mask=frame:CreateMaskTexture(nil,'OVERLAY')
        mask:SetTexture('Interface\\CharacterFrame\\TempPortraitAlphaMask','CLAMPTOBLACKADDITIVE','CLAMPTOBLACKADDITIVE')
        mask:SetAllPoints(texture);texture:AddMaskTexture(mask)
        return texture,mask
    end
    local rim=circle(76,'BACKGROUND',.66,.51,.25)
    local inset=circle(71,'BORDER',.06,.06,.06)
    local icon=frame:CreateTexture(nil,"ARTWORK")
    icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
    local coords=(CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[self.class]) or classCoords[self.class]
    if coords then
                                                                              
        local insetX,insetY=(coords[2]-coords[1])*.06,(coords[4]-coords[3])*.06
        icon:SetTexCoord(coords[1]+insetX,coords[2]-insetX,coords[3]+insetY,coords[4]-insetY)
    end
    icon:SetSize(64,64);icon:SetPoint('CENTER')
    local mask=frame:CreateMaskTexture(nil,"OVERLAY")
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(icon); icon:AddMaskTexture(mask)
    panel.classPortrait={frame=frame,icon=icon,mask=mask,rim=rim,inset=inset,class=self.class}
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
                                                                             
        line:SetHeight(PixelUtil.GetNearestPixelSize(1,scale,1))
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT",entry.parent,"TOPLEFT",PixelUtil.GetNearestPixelSize(entry.x,scale),PixelUtil.GetNearestPixelSize(entry.y,scale))
    end
end
function F:AddOptionsText(parent,value,x,y,width)
    local font=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    font:SetPoint("TOPLEFT",x,y)
                                                                          
                                                                             
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
    if content.listPage then self:LayoutListColumns() end
end
function F:CreateTableBody(page,top,footer,customWidth)
    local scroll=CreateFrame("ScrollFrame",nil,page,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",page,"TOPLEFT",0,-top)
    scroll:SetPoint("BOTTOMRIGHT",page,"BOTTOMRIGHT",-28,footer)
    local content=CreateFrame("Frame",nil,scroll)
    content:SetSize(970,1); scroll:SetScrollChild(content); content.scroll=scroll
    if not customWidth then
        self.optionContents=self.optionContents or {};self.optionContents[#self.optionContents+1]=content
        page.listContent=content
        content.listPage,content.listFooter=page,footer
        scroll.scrollBarHideable=true
        scroll:HookScript("OnSizeChanged",function() self:LayoutListColumns() end)
    end
    content:SetWidth(self.options:GetWidth()-70)
    return content
end
local function hideOwnedTooltip(owner)
    if GameTooltip:GetOwner()==owner then GameTooltip:Hide() end
end
function F:ResizeRowNameTooltip(label)
    local area=label.tooltipArea
    if not area then return end
    local available,text=label:GetWidth(),label:GetText()
    if area.nameWidth==available and area.nameText==text then return end
    area.nameWidth,area.nameText=available,text
    local width=math.min(available,label:GetStringWidth())
    area:SetShown(width>0)
    if width>0 then area:SetSize(width,math.min(label:GetParent():GetHeight(),label:GetStringHeight())) end
end
function F:SetRowDetailTooltip(row,showDetail)
    local function hoverArea()
        local area=CreateFrame("Frame",nil,row)
        area:SetMouseClickEnabled(false)
        area:SetMouseMotionEnabled(true)
        area:SetScript("OnEnter",showDetail)
        area:SetScript("OnLeave",hideOwnedTooltip)
        area:SetScript("OnHide",hideOwnedTooltip)
        return area
    end
    row.iconTooltip=hoverArea()
    row.iconTooltip:SetAllPoints(row.icon)
    local label=row.label or row.name
    label.tooltipArea=hoverArea()
    label.tooltipArea:SetPoint("LEFT",label,"LEFT",0,0)
    label.tooltipArea:Hide()
end
function F:CreateReorderArrow(row,x,direction,move,edge)
    local button=CreateFrame("Button",nil,row,"UIPanelButtonTemplate")
    button:SetSize(18,24);button:SetText("")
    if x then button:SetPoint("LEFT",x,0);self:FlexColumn(button) end
    local sign=direction==-1 and 1 or -1
    local function stroke(dx,dy,width,height,angle)
        local texture=button:CreateTexture(nil,"OVERLAY");texture:SetColorTexture(1,.82,0,1)
        texture:SetSnapToPixelGrid(false);texture:SetTexelSnappingBias(0)
        texture:SetPoint("CENTER",button,"CENTER",dx,dy*sign);texture:SetSize(width,height)
        if angle then texture:SetRotation(angle*sign)end
        return texture
    end
    stroke(0,-1,1,8);stroke(-2,1,6,1,math.pi/4);stroke(2,1,6,1,-math.pi/4)
    if edge then button.edgeBar=stroke(0,6,10,1)end
    button:SetScript("OnClick",move)
    button:SetScript("OnEnter",function()
        GameTooltip:SetOwner(button,"ANCHOR_RIGHT")
        GameTooltip:SetText(edge and(direction==-1 and "Move to top"or "Move to bottom")or(direction==-1 and "Move up"or "Move down"))
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave",hideOwnedTooltip)
    return button
end
                                                                               
                                                                              
function F:EnableRowReorder(row,content,rows,stride,getID,move,available,offset)
    row:RegisterForDrag("LeftButton")
    local source,sourceIndex,preview,marker,destination
    row:SetScript("OnEnter",function()
        if source or InCombatLockdown() or not available() then return end
        GameTooltip:SetOwner(row,"ANCHOR_RIGHT")
        GameTooltip:SetText("Drag row or use arrows to change order")
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave",hideOwnedTooltip)
    local function clear()
        source=nil; destination=nil
        row:SetScript("OnUpdate",nil)
        if preview then preview:Hide();marker:Hide() end
    end
    local function update(_,elapsed)
        if InCombatLockdown() or not available() then clear();return end
        local scroll=content.scroll
        local x,y=GetCursorPosition(); local scale=scroll:GetEffectiveScale()
        x,y=x/scale,y/scale
        local parentScale=F.options:GetEffectiveScale()
        preview:ClearAllPoints();preview:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",x*scale/parentScale+14,y*scale/parentScale-12)
        local top,left=scroll:GetTop(),scroll:GetLeft()
        destination=nil;marker:Hide()
        if not top or not left or x<left or x>left+scroll:GetWidth() or y>top or y<top-scroll:GetHeight() then return end
        local delta=y>top-22 and -1 or (y<top-scroll:GetHeight()+22 and 1 or 0)
        local maximum=math.max(0,content:GetHeight()-scroll:GetHeight())
        if delta~=0 and (elapsed or 0)>0 then
            scroll:SetVerticalScroll(math.max(0,math.min(maximum,scroll:GetVerticalScroll()+delta*220*elapsed)))
        end
        local count=0
        for _,candidate in ipairs(rows) do if candidate:IsShown() then count=count+1 end end
        local boundary=math.max(0,math.min(count-(offset or 0),math.floor((content:GetTop()-y)/stride+.5)))
        local before=boundary+1+(offset or 0)
        destination=math.max(1+(offset or 0),math.min(count,before-(sourceIndex<before and 1 or 0)))
        local markerY=top-content:GetTop()+boundary*stride
        if markerY>=0 and markerY<=scroll:GetHeight() then
            marker:ClearAllPoints();marker:SetPoint("TOPLEFT",scroll,"TOPLEFT",0,-math.max(0,math.min(scroll:GetHeight()-2,markerY)))
            marker:SetSize(scroll:GetWidth(),2);marker:Show()
        end
    end
    local function finish()
        if not source then return end
        update(nil,0)
        local id,to=source,destination;clear()
        if id and to then move(id,to) end
        F:Refresh()
    end
    row:SetScript("OnDragStart",function()
        if InCombatLockdown() or not available() then return end
        if not preview then
            preview=CreateFrame("Frame",nil,F.options);preview:SetFrameLevel(F.options:GetFrameLevel()+90);preview:EnableMouse(false)
            local background=preview:CreateTexture(nil,"BACKGROUND");background:SetAllPoints();background:SetColorTexture(.09,.08,.05,.95)
            local rule=preview:CreateTexture(nil,"BORDER");rule:SetPoint("BOTTOMLEFT");rule:SetPoint("BOTTOMRIGHT");rule:SetHeight(2);rule:SetColorTexture(1,.82,0,1)
            preview.icon=preview:CreateTexture(nil,"ARTWORK");preview.icon:SetPoint("LEFT",10,0);preview.icon:SetSize(26,26)
            preview.label=preview:CreateFontString(nil,"OVERLAY","GameFontNormal");preview.label:SetPoint("LEFT",46,0);preview.label:SetJustifyH("LEFT")
            marker=CreateFrame("Frame",nil,content.scroll);marker:SetFrameLevel(F.options:GetFrameLevel()+85);marker:EnableMouse(false)
            local line=marker:CreateTexture(nil,"OVERLAY");line:SetAllPoints();line:SetColorTexture(1,.82,0,1);line:SetSnapToPixelGrid(false);line:SetTexelSnappingBias(0)
            row.dragPreview,row.dropMarker=preview,marker
        end
        for index,candidate in ipairs(rows) do if candidate==row then sourceIndex=index;break end end
        preview:SetSize(row:GetWidth(),stride-2);preview.icon:SetTexture(row.icon:GetTexture())
        preview.label:SetWidth(math.max(1,row:GetWidth()-60));preview.label:SetText((row.label or row.name):GetText());preview:Show()
        source=getID(); row:SetAlpha(.6); GameTooltip:Hide()
        row:SetScript("OnUpdate",update);update(nil,0)
    end)
    row:SetScript("OnDragStop",finish)
    row:SetScript("OnMouseUp",function(_,button) if button=="LeftButton" then finish() end end)
    row:SetScript("OnHide",function()
        clear()
        hideOwnedTooltip(row)
    end)
end
function F:CreateOptions()
    self.optionUnderlines={}
    self.primaryHeadings={}
    local panel = CreateFrame("Frame", "BuffRagOptions", UIParent, "BasicFrameTemplateWithInset,SecureHandlerStateTemplate")
    panel:SetAttribute("_onstate-combat",[[if newstate == "combat" then self:Hide() end]])
    RegisterStateDriver(panel,"combat","[combat] combat; safe")
    panel:SetSize(self.db.windowWidth or 1160,self.db.windowHeight or F.defaults.windowHeight)
    panel:SetScale((self.db.windowZoom or 85)/100)
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
        if panel.collapsed then
            local left,top=panel:GetLeft(),panel:GetTop()
            panel:ClearAllPoints()
            panel:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",left,top)
        end
        local point, _, relativePoint, x, y = panel:GetPoint()
        F.db.windowPosition = { point = point, relativePoint = relativePoint, x = x, y = y }
        F:Refresh()
    end)
    panel:Hide()
                                                                                    
    local escape=CreateFrame("Frame","BuffRagOptionsEscape",UIParent)
    escape:Hide()
    tinsert(UISpecialFrames,"BuffRagOptionsEscape")
    escape:SetScript("OnHide",function()
        if not panel:IsShown() or InCombatLockdown() then return end
        if F.awaitingOptionsDecision then F.savePrompt:Hide()
        else F:RequestOptionsClose() end
        if panel:IsShown() then escape:Show() end
    end)
    local inheritedClose=panel.CloseButton
    local close=CreateFrame("Button",nil,panel,"UIPanelCloseButtonNoScripts,SecureActionButtonTemplate")
    close:SetAllPoints(inheritedClose)
    inheritedClose:Hide()
    panel.CloseButton=close
    F:SetupOptionsCloseAction(close,function() return F:RequestOptionsClose(true) end)
    panel:SetScript("OnShow", function() F:BeginOptions();escape:Show() end)
    panel:SetScript("OnHide", function()
        escape:Hide()
        if F.savePrompt then F.savePrompt:Hide() end
        if panel.iconOptions then panel.iconOptions:Hide() end
        if panel.itemBuffEditor then panel.itemBuffEditor:Hide() end
        if panel.helpWindow then panel.helpWindow:Hide() end
        if panel.globalSettings then panel.globalSettings:Hide() end
        if panel.CancelCombatKeyCapture then panel:CancelCombatKeyCapture() end
        if InCombatLockdown() then F:SetTestUI(false); GameTooltip:Hide(); return end
        panel:StopMovingOrSizing()
        if panel.StopResizing then panel:StopResizing() end
        if panel.CancelBindingCapture then panel:CancelBindingCapture() end
        F:SetTestUI(false)
        if F.editingOptions and not F:OptionsDirty() then F:FinishOptions(false) end
    end)
    panel.syncers = {}
    function panel:SyncFields()
        F:ApplyWindowScale(F.db.windowScale)
        if self.iconOptions then self.iconOptions:Sync() end
        for _, sync in ipairs(self.syncers) do sync() end
        if self.globalSettings and self.globalSettings:IsShown() then self.globalSettings:Sync() end
        if self.UpdateBuffRows then self:UpdateBuffRows() end
    end
    local banner = panel:CreateTexture(nil, "ARTWORK")
    banner:SetPoint("TOPLEFT", 4, -28)
    banner:SetSize(1152,F.headerHeight)
    banner:SetColorTexture(.16,.16,.16,.95)
    local wordmark=panel:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    wordmark:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",40,"OUTLINE")
    wordmark:SetText("Buff Rag"); wordmark:SetTextColor(1,.82,0)
    wordmark:SetPoint("CENTER",banner,"CENTER",0,9)
    wordmark:SetShadowColor(0,0,0,1); wordmark:SetShadowOffset(2,-2)
    panel.banner,panel.wordmark=banner,wordmark
    local credit=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    credit:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",14,"OUTLINE")
    credit:SetText("By Zivany Dots")
    credit:SetPoint("TOP",wordmark,"BOTTOM",0,-1)
    credit:SetJustifyH("CENTER")
    credit:SetShadowColor(0,0,0,1); credit:SetShadowOffset(1,-1)
    panel.bannerCredit=credit
    self:CreateClassPortrait(panel)
    local collapse=CreateFrame("Frame",nil,panel,"MaximizeMinimizeButtonFrameTemplate")
    collapse:SetFrameLevel(panel:GetFrameLevel()+4)
    collapse:SetPoint("RIGHT",panel.CloseButton,"LEFT",0,0)
    collapse:SetOnMinimizedCallback(function() F:SetOptionsCollapsed(true) end)
    collapse:SetOnMaximizedCallback(function() F:SetOptionsCollapsed(false) end)
    collapse.MinimizeButton:SetNormalAtlas("RedButton-Expand")
    collapse.MinimizeButton:SetPushedAtlas("RedButton-Expand-Pressed")
    collapse.MinimizeButton:SetDisabledAtlas("RedButton-Expand-Disabled")
    collapse.MaximizeButton:SetNormalAtlas("RedButton-Condense")
    collapse.MaximizeButton:SetPushedAtlas("RedButton-Condense-Pressed")
    collapse.MaximizeButton:SetDisabledAtlas("RedButton-Condense-disabled")
    for _,button in ipairs({collapse.MinimizeButton,collapse.MaximizeButton}) do
        button:SetScript("OnEnter",function(control)
            GameTooltip:SetOwner(control,"ANCHOR_RIGHT")
            GameTooltip:SetText(control==collapse.MaximizeButton and "Expand Buff Rag" or "Collapse Buff Rag")
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave",function() GameTooltip:Hide() end)
    end
    panel.collapseButton=collapse
    self:CreateHelpButton(panel,collapse)
    local body=CreateFrame("Frame",nil,panel)
    body:SetPoint("TOPLEFT",panel,"TOPLEFT")
    body:SetSize(panel:GetWidth(),panel:GetHeight())
    panel.body=body
    local pages, tabs = {}, {}
    local settingsButton=CreateFrame("Button",nil,panel)
    settingsButton:SetSize(24,24)
    settingsButton:SetPoint("BOTTOMRIGHT",banner,"BOTTOMRIGHT",-13,7)
    local settingsIcon=settingsButton:CreateTexture(nil,"ARTWORK")
    settingsIcon:SetAllPoints()
    settingsIcon:SetAtlas("OptionsIcon-Brown")
    panel.settingsButton=settingsButton
    local function selectTab(index)
        if panel.CancelCombatKeyCapture then panel:CancelCombatKeyCapture() end
        if panel.CancelBindingCapture then panel:CancelBindingCapture() end
        panel.selectedTab = index
        for i, page in ipairs(pages) do
            page:SetShown(i == index)
            if tabs[i] then F:SelectOptionsTab(tabs[i],i==index) end
        end
    end
    settingsButton:SetScript("OnClick",function()
        F:ToggleGlobalSettings()
    end)
    settingsButton:SetScript("OnEnter",function(button)
        settingsIcon:SetAlpha(1)
        GameTooltip:SetOwner(button,"ANCHOR_RIGHT")
        GameTooltip:SetText("Global Settings")
        GameTooltip:Show()
    end)
    settingsButton:SetScript("OnLeave",function()
        settingsIcon:SetAlpha(.8)
        GameTooltip:Hide()
    end)
    for i, name in ipairs({ "Buff Mode", "Bag Items", "Combat Mode" }) do
        local index = i
        local page = CreateFrame("Frame", nil, body)
        page:SetPoint("TOPLEFT", 20, -199)
        page:SetPoint("BOTTOMRIGHT", -20, 60)
        pages[i] = page
        local tab = F:CreateOptionsTab(body,name,162,28)
        tab:SetPoint("TOPLEFT", 20 + (i - 1) * 167, -159)
        tab:SetScript("OnClick", function() selectTab(index) end)
        tabs[i] = tab
    end
    panel.pages, panel.tabs = pages, tabs
                                                                        
                                                                              
    panel.tabDivider=self:AddOptionsDivider(body,20,-187,1000)
    local reset = CreateFrame("Button", "BuffRagResetDefaults", body, "UIPanelButtonTemplate")
    reset:SetSize(150, 24)
    reset:SetPoint("BOTTOMLEFT", 20, 20)
    reset:SetText("Defaults")
    reset:SetScript("OnClick", function() F:ResetDefaults() end)
    reset:SetScript('OnEnter',function()GameTooltip:SetOwner(reset,'ANCHOR_RIGHT');GameTooltip:SetText('Defaults for this view');GameTooltip:AddLine(F:ResetHelp(),.8,.8,.8,true);GameTooltip:Show()end)
    reset:SetScript('OnLeave',function()GameTooltip:Hide()end)
    local save = CreateFrame("Button", "BuffRagSaveOptions", body, "UIPanelButtonTemplate")
    save:SetSize(150,24)
    save:SetPoint("BOTTOMRIGHT", -20,20)
    save:SetText("Save")
    save:SetScript("OnClick", function() F:SaveOptions() end)
    local configure = CreateFrame("Button", "BuffRagConfigureFrameIcons", body, "UIPanelButtonTemplate,SecureActionButtonTemplate")
    configure:SetSize(220,24)
    configure:SetPoint("BOTTOM",0,20)
    configure:SetText("Configure Frame Icons")
    configure:RegisterForClicks("LeftButtonUp")
    configure:SetAttribute("useOnKeyDown",false)
    configure:SetAttribute("*type1","macro")
    configure:SetAttribute("*macrotext1","/target [@player] player\n/focus [@player]")
    configure:SetScript("PostClick",function()
        F:SetOptionsCollapsed(true)
        F:OpenFrameIconOptions()
        C_Timer.After(0,function() if F.testUI then F:Refresh() end end)
    end)
    panel.configureFrameIcons=configure
    panel.save = save
    selectTab(1)
    self.options = panel
    self:CreateGlobalSettings(panel)
    local buffs,pots,combat=pages[1],pages[2],pages[3]
    self:CreateItemsPage(panel,pots)
    self:CreateBuffList(panel,buffs)
    self:CreateCombatPage(panel,combat)
    self:CreateResizeGrip(panel)
    self:ApplyWindowSize(self.db.windowWidth,self.db.windowHeight)
    self:UpdateSaveButton()
end
