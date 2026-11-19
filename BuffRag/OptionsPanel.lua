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
function F:AddPrimaryOptionsHeading(parent,title,x,y,width)
    local label,line=self:AddOptionsHeading(parent,title,x,y,width or 950)
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
    self.optionUnderlines[#self.optionUnderlines+1]={line=line,parent=parent,x=x,y=y,width=width}
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
end
function F:CreateTableBody(page,top,footer)
    local scroll=CreateFrame("ScrollFrame",nil,page,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",page,"TOPLEFT",0,-top)
    scroll:SetPoint("BOTTOMRIGHT",page,"BOTTOMRIGHT",-28,footer)
    local content=CreateFrame("Frame",nil,scroll)
    content:SetSize(970,1); scroll:SetScrollChild(content); content.scroll=scroll
    self.optionContents=self.optionContents or {};self.optionContents[#self.optionContents+1]=content
    content:SetWidth(self.options:GetWidth()-70)
    return content
end
function F:CreateTableFooter(page,content,getText)
    local note=self:AddOptionsText(page,"",0,0,955)
    note:ClearAllPoints(); note:SetPoint("BOTTOMLEFT",page,"BOTTOMLEFT",0,8); note:SetWidth(955)
    local function sync()
        note:SetWidth(F.options:GetWidth()-85)
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
                                                                               
                                                                              
function F:EnableRowReorder(row,content,rows,stride,getID,move,available,offset)
    row:RegisterForDrag("LeftButton")
    local source,sourceIndex,preview,marker,destination
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
        if GameTooltip:GetOwner()==row then GameTooltip:Hide() end
    end)
end
function F:CreateOptions()
    self.optionUnderlines={}
    self.primaryHeadings={}
    self.tableFooterSyncers={}
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
    panel:SetScript("OnShow", function() F:BeginOptions() end)
    panel:SetScript("OnHide", function()
        if panel.iconOptions then panel.iconOptions:Hide() end
        if panel.itemBuffEditor then panel.itemBuffEditor:Hide() end
        if panel.helpWindow then panel.helpWindow:Hide() end
        if panel.CancelCombatKeyCapture then panel:CancelCombatKeyCapture() end
        if InCombatLockdown() then F:SetTestUI(false); GameTooltip:Hide(); return end
        panel:StopMovingOrSizing()
        if panel.StopResizing then panel:StopResizing() end
        if panel.CancelBindingCapture then panel:CancelBindingCapture() end
        F:SetTestUI(false)
        if not InCombatLockdown() then
                                                                        
                                                                          
            C_Timer.After(0, function()
                if not panel:IsShown() then F:OptionsHidden() end
            end)
        end
    end)
    panel.syncers = {}
    function panel:SyncFields()
        F:ApplyWindowScale(F.db.windowScale)
        if self.iconOptions then self.iconOptions:Sync() end
        for _, sync in ipairs(self.syncers) do sync() end
        self:UpdateTargetControls()
        if self.UpdateBuffRows then self:UpdateBuffRows() end
    end
    tinsert(UISpecialFrames, "BuffRagOptions")
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
    local collapse=CreateFrame("Button",nil,panel)
    collapse:SetSize(24,22)
    collapse:SetPoint("BOTTOMRIGHT",banner,"BOTTOMRIGHT",-37,5)
    local glyph=collapse:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    glyph:SetPoint("CENTER");collapse:SetFontString(glyph);collapse:SetText("^")
    collapse:SetScript("OnClick",function() F:SetOptionsCollapsed(not panel.collapsed) end)
    collapse:SetScript("OnEnter",function()
        GameTooltip:SetOwner(collapse,"ANCHOR_RIGHT")
        GameTooltip:SetText(panel.collapsed and "Expand Buff Rag" or "Collapse Buff Rag")
        GameTooltip:Show()
    end)
    collapse:SetScript("OnLeave",function() GameTooltip:Hide() end)
    panel.collapseButton=collapse
    self:CreateHelpButton(panel,collapse)
    local body=CreateFrame("Frame",nil,panel)
    body:SetPoint("TOPLEFT",panel,"TOPLEFT")
    body:SetSize(panel:GetWidth(),panel:GetHeight())
    panel.body=body
    local function text(parent,value,x,y,width) return F:AddOptionsText(parent,value,x,y,width) end
    local pages, tabs = {}, {}
    local function selectTab(index)
        if panel.CancelCombatKeyCapture then panel:CancelCombatKeyCapture() end
        if panel.CancelBindingCapture then panel:CancelBindingCapture() end
        panel.selectedTab = index
        for i, page in ipairs(pages) do
            page:SetShown(i == index)
            F:SelectOptionsTab(tabs[i],i==index)
        end
    end
    for i, name in ipairs({ "Buffs", "Bag Items", "Combat", "Global Settings" }) do
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

    local buffs,pots,combat,settings = pages[1],pages[2],pages[3],pages[4]
    local function scrollContent(page,height)
        local scroll=CreateFrame("ScrollFrame",nil,page,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT"); scroll:SetPoint("BOTTOMRIGHT",-28,0)
        local content=CreateFrame("Frame",nil,scroll)
        content:SetSize(970,height); scroll:SetScrollChild(content); content.scroll=scroll
        self.optionContents=self.optionContents or {};self.optionContents[#self.optionContents+1]=content
        return content
    end
    settings=scrollContent(settings,810)
    panel.buffContent,panel.itemContent=buffs,pots
    local function heading(parent,title,x,y,width) return F:AddOptionsHeading(parent,title,x,y,width) end
    function panel:UpdateTargetControls()
        for _,entry in ipairs(gated) do
            local enabled=entry.enabled()
            entry.control:SetEnabled(enabled); entry.control:SetAlpha(enabled and 1 or .4)
            if entry.label then entry.label:SetAlpha(enabled and 1 or .4) end
        end
    end
    local function slider(titleText, key, minimum, maximum, x, y, parent, available)
        local control = CreateFrame("Slider", "BuffRagSlider_" .. key, parent, "OptionsSliderTemplate")
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
            if key=="windowZoom"then F:ApplyWindowZoom(value)end
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
    check(settings,"BuffRagCombatIncludeBuffs","Include Buffs tab abilities in Combat",500,-120,
        function()return F.db.combatIncludeBuffs end,function(v)F.db.combatIncludeBuffs=v end)
    check(settings,"BuffRagCombatFeedback","Show combat cast-result overlays (opt in)",500,-150,
        function()return F.db.combatFeedback end,function(v)F.db.combatFeedback=v end)
    text(settings,"Enable Combat and item Combat choices. Each frame has its own assignments; Target and Focus also have Friendly/Enemy profiles. Rows 1–3 assign SHIFT / CTRL / ALT; visible icons pack together. Bag Items has a movable insertion row. Configure before combat.",500,-190,450)
    self:CreateCombatFeedbackExamples(settings,500,280)
    text(settings,"Optional tick = cast completed; cross = failed/interrupted; ? = pending/unavailable confirmation. Each mark immediately fades over one GCD (estimated if timing is restricted). Hover does not clear it. A tick does not prove lasting buff presence.",500,-315,450)
    local dispelExample=CreateFrame('Frame',nil,settings);dispelExample:SetPoint('TOPLEFT',500,-370);dispelExample:SetSize(24,24)
    local dispelTexture=dispelExample:CreateTexture(nil,'BACKGROUND');dispelTexture:SetAllPoints();dispelTexture:SetTexture('Interface\\Icons\\Spell_Holy_DispelMagic')
    dispelExample.visual=dispelExample;F:PaintDispelTypes(dispelExample,{Poison=true})
    text(settings,'Dispel symbol = matching removable effect detected.',532,-375,418)
    text(settings,"Icons and actions are protected in combat: only preconfigured combat actions appear, with cooldown/GCD swipes and optional cast feedback. Range/zone uses half combat opacity. After combat, each friendly frame retains relevant heals, cleanses (dispel symbols) or dead-only resurrection until recovered, then returns to Buff mode. Post-combat keeps combat modifiers; buff queues never take over a failed or unavailable Post-combat action. Post-combat requires a confirmed need. Normal buff tracking resumes outside combat.",500,-400,450)
    slider("Combat opacity (%)","combatOpacity",0,100,510,-550,settings)
    heading(settings,"Window",0,-640,450)
    slider("Window zoom (%)","windowZoom",65,100,10,-695,settings)
    text(settings,"Default 85%. Zoom scales the settings window; the resize grip changes width and height independently. Unit-frame icons keep their configured size.",0,-750,450)
    dropdown(settings,"BuffRagPriorityModifier","Bypass Q frame buff modifier","priorityModifier",{
        {"Ctrl (default)","ctrl"},{"Alt","alt"},{"Shift","shift"},{"Disabled","off"},
    },0,-190)
    text(settings,F:PriorityHelp().." Choose different modifiers for the two queues; if they match, Bypass Q takes precedence.",0,-265,450)
    text(settings,"Save keeps choices and order; closing the window lets you save or discard changes.",500,-730,450)
    heading(settings,"Minimap",500,-640,450)
    panel.minimapCheckbox=check(settings,"BuffRagMinimapEnabled","Enable minimap icon",500,-665,
        function() return F.db.minimapEnabled~=false end,function(v) F.db.minimapEnabled=v end)
    local globalReset=CreateFrame('Button','BuffRagGlobalResetDefaults',settings,'UIPanelButtonTemplate')
    globalReset:SetPoint('TOPLEFT',500,-775);globalReset:SetSize(210,24);globalReset:SetText('Global Reset Settings')
    globalReset:SetScript('OnClick',function()F:ResetDisplayedDefaults(true)end)
    globalReset:SetScript('OnEnter',function()
        GameTooltip:SetOwner(globalReset,'ANCHOR_RIGHT');GameTooltip:SetText('Global Reset Settings')
        GameTooltip:AddLine('Reset all tabs, lists, combat profiles, placement, window appearance and the Buff Rag keyboard shortcut. Learned pet abilities are retained. Click Save to keep the reset; closing lets you discard it.',.8,.8,.8,true);GameTooltip:Show()
    end)
    globalReset:SetScript('OnLeave',function()GameTooltip:Hide()end)
    panel.globalReset=globalReset
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
    panel:UpdateTargetControls()
    selectTab(1)
    self.options = panel
    self:CreateBindingControls(panel,settings)
    self:CreateItemsPage(panel,pots)
    self:CreateBuffList(panel,buffs)
    self:CreateCombatPage(panel,combat)
    self:CreateResizeGrip(panel)
    self:ApplyWindowSize(self.db.windowWidth,self.db.windowHeight)
    self:UpdateSaveButton()
end
