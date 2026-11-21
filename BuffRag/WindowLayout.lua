local _,F=...
F.minimumWindowWidth=1020
local function hiddenColumnShift(entry,bypass,combat)
    return (not bypass and entry.bypassShift or 0)+(not combat and entry.combatShift or 0)
        +(entry.content and entry.content.listExtra or 0)
end
function F:FlexColumn(region,bypassShift,combatShift)
    local point,parent,relative,x,y=region:GetPoint()
    if type(parent)=="number"then x,y,parent,relative=parent,relative,region:GetParent(),point end
    self.flexColumns=self.flexColumns or {}
    local entry={region=region,point=point,parent=parent,relative=relative,x=x or 0,y=y or 0,bypassShift=bypassShift or 0,
        combatShift=combatShift or 0,content=region:GetParent().listContent}
    self.flexColumns[#self.flexColumns+1]=entry
    local shift=hiddenColumnShift(entry,self.db.bypassEnabled,self.db.combatClicks)
    region:SetPoint(point,parent,relative,entry.x+(self.options:GetWidth()-1160)+shift,entry.y)
end
function F:FlexName(region,bypassShift,combatShift)
    local entry={region=region,width=region:GetWidth(),bypassShift=bypassShift or 0,combatShift=combatShift or 0,
        content=region:GetParent().listContent}
    self.flexNames=self.flexNames or {};self.flexNames[#self.flexNames+1]=entry
    local shift=hiddenColumnShift(entry,self.db.bypassEnabled,self.db.combatClicks)
    region:SetWidth(entry.width+(self.options:GetWidth()-1160)+shift)
end
function F:LayoutListColumns(force)
    local bypass,combat=self.db.bypassEnabled,self.db.combatClicks
    local width=self.options:GetWidth()
    local changed=force or self.bypassLayout~=bypass or self.combatColumnLayout~=combat
    self.bypassLayout,self.combatColumnLayout=bypass,combat
    for _,content in ipairs(self.optionContents or {})do
        local scroll=content.scroll
        local needsScroll=content:GetHeight()-scroll:GetHeight()>=1
        local reclaimed=needsScroll and 0 or 28
        if force or content.listExtra~=reclaimed then
            content.listExtra=reclaimed
            content:SetWidth(width-70+reclaimed)
            scroll:SetPoint("BOTTOMRIGHT",content.listPage,"BOTTOMRIGHT",-28+reclaimed,content.listFooter)
            scroll.ScrollBar:SetShown(needsScroll)
            changed=true
        end
    end
    if not changed then return end
    local extra=width-1160
    for _,entry in ipairs(self.flexColumns or {})do
        local shift=hiddenColumnShift(entry,bypass,combat)
        entry.region:SetPoint(entry.point,entry.parent,entry.relative,entry.x+extra+shift,entry.y)
    end
    for _,entry in ipairs(self.flexNames or {})do
        local shift=hiddenColumnShift(entry,bypass,combat)
        entry.region:SetWidth(entry.width+extra+shift)
        self:ResizeRowNameTooltip(entry.region)
    end
    for _,row in ipairs(self.flexRows or {})do row:SetWidth(row.listContent:GetWidth())end
end
function F:FlexRow(row)
    self.flexRows=self.flexRows or {};self.flexRows[#self.flexRows+1]=row
    row:SetWidth(row.listContent:GetWidth())
end
function F:LayoutOptionsWindow()
    local panel=self.options;if not panel or not panel.banner or not panel.pages then return end
    local width,height=panel:GetWidth(),panel:GetHeight()
    local bannerWidth=width-8;local bannerHeight=F.headerHeight
    panel.banner:SetSize(bannerWidth,bannerHeight)
    local tabsTop=28+bannerHeight+11
    local pageTop=tabsTop+40
    local gap = 5
    local tabWidth = (width-40-(#panel.tabs-1)*gap)/#panel.tabs
    for index,tab in ipairs(panel.tabs) do
        local x = 20+(index-1)*(tabWidth+gap)
        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT",x,-tabsTop)
        tab:SetWidth(tabWidth)
    end
    panel.tabDivider:SetPoint("TOPLEFT",20,-tabsTop-28);panel.tabDivider:SetWidth(width-40)
    for _,page in ipairs(panel.pages)do page:SetPoint("TOPLEFT",20,-pageTop)end
    self:LayoutListColumns(true)
    if panel.LayoutCombatColumns then panel:LayoutCombatColumns() end
    for _,entry in ipairs(self.primaryHeadings or {})do
        entry.line:SetWidth(width-90)
    end
                                                                                         
    self:RefreshOptionsUnderlines()
    panel.tabDivider:ClearAllPoints();panel.tabDivider:SetPoint("TOPLEFT",20,-tabsTop-28)
    if panel.UpdateItemDropHint then panel:UpdateItemDropHint() end
end
function F:ApplyWindowSize(width,height,anchor)
    if not self.options or InCombatLockdown()then return end
    local zoom=math.max(65,math.min(100,tonumber(self.db.windowZoom)or 85))/100
    width=math.max(self.minimumWindowWidth,math.min((UIParent:GetWidth()-20)/zoom,tonumber(width)or 1160))
    local bannerHeight=F.headerHeight
                                                                             
    local minimumHeight=28+bannerHeight+11+40+60+278+8+38
    height=math.max(minimumHeight,math.min((UIParent:GetHeight()-20)/zoom,tonumber(height)or self.defaults.windowHeight))
    width,height=math.floor(width+.5),math.floor(height+.5)
    local panel=self.options
    local visibleHeight=panel.collapsed and (28+F.headerHeight) or height
    local changed=panel:GetWidth()~=width or panel:GetHeight()~=visibleHeight or panel:GetScale()~=zoom or not self.windowLayoutReady
    self.options:SetScale(zoom)
    if changed then panel:SetSize(width,visibleHeight)end
    if panel.body then panel.body:SetSize(width,height) end
    self.db.windowScale,self.db.windowZoom,self.db.windowWidth,self.db.windowHeight=zoom,math.floor(zoom*100+.5),width,height
    if anchor then
        local scale=self.options:GetEffectiveScale()
        self.options:ClearAllPoints();self.options:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",anchor.left/scale,anchor.top/scale)
        local point,_,relativePoint,x,y=self.options:GetPoint()
        self.db.windowPosition={point=point,relativePoint=relativePoint,x=x,y=y}
    end
    if changed then self:LayoutOptionsWindow();self.windowLayoutReady=true end
    self:UpdateSaveButton()
end
function F:SetOptionsCollapsed(collapsed)
    local panel=self.options
    if not panel or InCombatLockdown() or (panel.collapsed==true)==collapsed then return end
    local left,top=panel:GetLeft(),panel:GetTop()
    panel:StopResizing()
    if panel.CancelBindingCapture then panel:CancelBindingCapture() end
    if panel.CancelCombatKeyCapture then panel:CancelCombatKeyCapture() end
    if left and top then
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",left,top)
    end
    panel.collapsed=collapsed
    panel.body:SetShown(not collapsed)
    if collapsed then panel.collapseButton:Minimize(true,true)
    else panel.collapseButton:Maximize(true,true) end
    self:ApplyWindowSize(self.db.windowWidth,self.db.windowHeight)
end
function F:ApplyWindowZoom(value)
    if not self.options or InCombatLockdown()then return end
    local panel=self.options;local scale=panel:GetEffectiveScale()
    local anchor={left=panel:GetLeft()*scale,top=panel:GetTop()*scale}
    self.db.windowZoom=value
    self:ApplyWindowSize(panel:GetWidth(),self.db.windowHeight,anchor)
end
