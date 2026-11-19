local _,F=...
F.minimumWindowWidth=1160
function F:FlexColumn(region)
    local point,parent,relative,x,y=region:GetPoint()
    if type(parent)=="number"then x,y,parent,relative=parent,relative,region:GetParent(),point end
    self.flexColumns=self.flexColumns or {}
    local entry={region=region,point=point,parent=parent,relative=relative,x=x or 0,y=y or 0}
    self.flexColumns[#self.flexColumns+1]=entry
    region:SetPoint(point,parent,relative,entry.x+math.max(0,self.options:GetWidth()-1160),entry.y)
end
function F:FlexName(region)
    self.flexNames=self.flexNames or {};self.flexNames[#self.flexNames+1]={region=region,width=region:GetWidth()}
    region:SetWidth(region:GetWidth()+math.max(0,self.options:GetWidth()-1160))
end
function F:FlexRow(row)
    self.flexRows=self.flexRows or {};self.flexRows[#self.flexRows+1]=row
    row:SetWidth(self.options:GetWidth()-70)
end
function F:LayoutOptionsWindow()
    local panel=self.options;if not panel or not panel.banner or not panel.pages then return end
    local width,height=panel:GetWidth(),panel:GetHeight()
    local extra=math.max(0,width-1160)
    local bannerWidth=width-24;local bannerHeight=bannerWidth*120/1016
    panel.banner:SetSize(bannerWidth,bannerHeight)
    local tabsTop=28+bannerHeight+11
    local pageTop=tabsTop+40
    for index,tab in ipairs(panel.tabs)do
        local tabWidth=(width-40-25)/6
        tab:ClearAllPoints();tab:SetPoint("TOPLEFT",20+(index-1)*(tabWidth+5),-tabsTop);tab:SetWidth(tabWidth)
    end
    panel.tabDivider:SetPoint("TOPLEFT",20,-tabsTop-28);panel.tabDivider:SetWidth(width-40)
    for _,page in ipairs(panel.pages)do page:SetPoint("TOPLEFT",20,-pageTop)end
    for _,content in ipairs(self.optionContents or {})do content:SetWidth(width-70)end
    for _,entry in ipairs(self.flexColumns or {})do entry.region:SetPoint(entry.point,entry.parent,entry.relative,entry.x+extra,entry.y)end
    for _,entry in ipairs(self.flexNames or {})do entry.region:SetWidth(entry.width+extra)end
    for _,row in ipairs(self.flexRows or {})do row:SetWidth(width-70)end
    for _,entry in ipairs(self.optionUnderlines or {})do
        if entry.width and entry.width>=900 and entry.line~=panel.tabDivider then entry.line:SetWidth(entry.width+width-1040)end
    end
    for _,entry in ipairs(self.primaryHeadings or {})do entry.icon:SetPoint("CENTER",entry.line,"RIGHT",width-90-entry.line:GetWidth(),0)end
    -- Set the divider anchor after underline pixel snapping as it moves with the banner.
    self:RefreshOptionsUnderlines()
    panel.tabDivider:ClearAllPoints();panel.tabDivider:SetPoint("TOPLEFT",20,-tabsTop-28)
    self:RefreshTableFooters()
end
function F:ApplyWindowSize(width,height,anchor)
    if not self.options or InCombatLockdown()then return end
    local zoom=math.max(65,math.min(100,tonumber(self.db.windowZoom)or 85))/100
    width=math.max(1160,math.min((UIParent:GetWidth()-20)/zoom,tonumber(width)or 1160))
    local bannerHeight=(width-24)*120/1016
    -- Items needs three full 36px rows below its fixed 215px header and footer.
    local minimumHeight=math.ceil(28+bannerHeight+11+40+60+215+70+108)
    height=math.max(minimumHeight,math.min((UIParent:GetHeight()-20)/zoom,tonumber(height)or 740))
    width,height=math.floor(width+.5),math.floor(height+.5)
    local changed=self.options:GetWidth()~=width or self.options:GetHeight()~=height or self.options:GetScale()~=zoom or not self.windowLayoutReady
    self.options:SetScale(zoom)
    if changed then self.options:SetSize(width,height)end
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
function F:ApplyWindowZoom(value)
    if not self.options or InCombatLockdown()then return end
    local panel=self.options;local scale=panel:GetEffectiveScale()
    local anchor={left=panel:GetLeft()*scale,top=panel:GetTop()*scale}
    self.db.windowZoom=value
    self:ApplyWindowSize(panel:GetWidth(),panel:GetHeight(),anchor)
end
