local _, F = ...
function F:NormalizeItems(items)
    local result,seen={},{}
    for _,entry in ipairs(type(items)=="table" and items or {}) do
        local raw=type(entry)=="table" and entry.id
        local id=(type(raw)=="number" or type(raw)=="string") and tonumber(raw)
        if id and id>0 and id<=2147483647 and id==math.floor(id) and not seen[id] then
            local mode=(entry.buffMode=="spell" or entry.buffMode=="off") and entry.buffMode or "auto"
            local buffID=tonumber(type(entry.buffSpellID)=="number" and entry.buffSpellID or "")
            if buffID and (buffID<=0 or buffID>2147483647 or buffID~=math.floor(buffID)) then buffID=nil end
            result[#result+1]={id=id,enabled=entry.enabled~=false,queue=entry.queue~=false,party=entry.party==true,buffMode=mode,buffSpellID=buffID,
                buffVisible=entry.buffVisible==nil and entry.combat~=true or entry.buffVisible==true,
                buffName=type(entry.buffName)=="string" and entry.buffName or nil}; seen[id]=true
        end
    end
    return result
end
function F:IsCustomItemEquipment(id)
    if C_Item.IsEquippableItem then
        local equipment=C_Item.IsEquippableItem(id)
        if issecretvalue and issecretvalue(equipment) then return true end
        if equipment==true or equipment==1 then return true end
    end
    if C_Item.GetItemInfoInstant then
        local _,_,_,location=C_Item.GetItemInfoInstant(id)
        return type(location)=="string" and location~="INVTYPE_NON_EQUIP_IGNORE" and location:match("^INVTYPE_")~=nil
    end
    return false
end
function F:HasCustomItems()
    if not self.db.itemsEnabled then return false end
    for _,entry in ipairs(self.db.items) do if entry.enabled then return true end end
    return false
end
function F:CustomItemCount(id)
    local count=C_Item.GetItemCount(id)
    if issecretvalue and issecretvalue(count) then return 0 end
    if count and count>0 then return count end
    return 0
end
function F:BagItemReady(id)
    local start,duration=C_Item.GetItemCooldown(id)
    if issecretvalue and (issecretvalue(start) or issecretvalue(duration)) then return false end
    if start==nil and duration==nil then return true end                            
    if type(start)~="number" or type(duration)~="number" then return false end
                                                                           
                                                                            
    return duration==0 or start==0 or start+duration<=GetTime()
end
function F:CustomItemData(id,unit)
    local name=C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    self.itemRequests=self.itemRequests or {}
    if not name and not self.itemRequests[id] and C_Item.RequestLoadItemDataByID then
        self.itemRequests[id]="pending"; C_Item.RequestLoadItemDataByID(id)
    end
    local usable=not self:IsCustomItemEquipment(id)
    local count=self:CustomItemCount(id)
    local buffActive=usable and self:IsCustomItemBuffActive(id,name,unit or "player") or false
    local ready=usable and not buffActive and count>0 and self:BagItemReady(id)
    local status=buffActive and "Buff active" or (not usable and "Equipment unsupported" or (not name and (self.itemRequests[id]=="failed" and "Unknown item" or "Loading...")
        or (count==0 and "Not carried" or (ready and "Ready" or "Cooldown"))))
    return {name=name or ("Item #"..id),count=count,ready=ready,usable=usable,status=status,buffActive=buffActive}
end
function F:AddCustomItem(input)
    if InCombatLockdown() then return false,"Edit items outside combat." end
    local value=tostring(input or "")
    local id=tonumber(value:match("item:(%d+)") or value:match("^%s*(%d+)%s*$"))
    if not id or id<=0 or id>2147483647 or id~=math.floor(id) then return false,"Drop an item here, or paste its item link / ID." end
    if self:IsCustomItemEquipment(id) then return false,"Equipment is not supported. Add an item used from your bags." end
    for _,entry in ipairs(self.db.items) do if entry.id==id then return false,"That item is already in your list." end end
    self.db.items[#self.db.items+1]={id=id,enabled=true,buffVisible=true,queue=true,self=true,party=false,raid=false,target=false,focus=false,prioritySelected=false,buffMode="auto",useOn='auto',cleanupRole='auto'}
    self.db.itemsEnabled=true
    self.db.selfPriority=self:NormalizeSelfPriority(self.db.selfPriority)
    self:Refresh()
    return true
end
function F:MoveCustomItem(index,direction)
    if InCombatLockdown() or (direction~=-1 and direction~=1) then return end
    local entries=self.db.items; local other=index+direction
    if entries[index] and entries[other] then entries[index],entries[other]=entries[other],entries[index]; self:Refresh() end
end
function F:RemoveCustomItem(index)
    if InCombatLockdown() then return end
    if self.db.items[index] then table.remove(self.db.items,index); self:Refresh() end
end
function F:OpenMissingItemMenu(button)
    if InCombatLockdown() or self.testUI or button.buffKey~="items" or not button.customItem
        or not MenuUtil or not MenuUtil.CreateContextMenu then return end
    local id=button.customItem
    local function findMissingEntry()
        if InCombatLockdown() then return end
        local count=C_Item.GetItemCount(id)
        if (issecretvalue and issecretvalue(count)) or count~=0 then return end
        for index,entry in ipairs(self.db.items) do
            if entry.id==id and entry.enabled then return index,entry end
        end
    end
    if not findMissingEntry() then return end
    MenuUtil.CreateContextMenu(button,function(_,root)
        root:CreateTitle(button.buffName or "Bag Items")
        root:CreateButton("Disable item",function()
            local _,entry=findMissingEntry()
            if entry then entry.enabled=false;self:Refresh() end
        end)
        root:CreateButton("Remove from Bag Items",function()
            local index=findMissingEntry()
            if index then self:RemoveCustomItem(index) end
        end)
    end)
end
function F:CreateItemSlash(button)
    local slash=button.visual:CreateTexture(nil,"OVERLAY")
    slash:SetPoint("CENTER"); slash:SetColorTexture(1,.1,.1,1); slash:SetRotation(-math.pi/4)
    slash:Hide(); button.missingSlash=slash
end
function F:UpdateCustomItemVisual(button)
    local count=self:CustomItemCount(button.customItem)
    button.itemMissing=count==0
    button.texture:SetAlpha(count==0 and .4 or 1)
    button.text:SetText((button.poison or count>1 or count==0) and tostring(count) or "")
    button.missingSlash:SetSize(button:GetWidth()*1.2,2)
    button.missingSlash:SetShown(count==0)
end
function F:CreateItemsPage(panel,page)
    local function text(value,x,y,width)
        return F:AddOptionsText(page,value,x,y,width or 950)
    end
    F:AddPrimaryOptionsHeading(page,"Custom bag items",0,0)
    F:FlexName(text("Add items from your bags and choose where and when you can use them.",0,-30))
    local message=text("",0,-46,330); message:SetTextColor(1,.4,.3)
                                                                               
                                                                                 
                                                                       
    local dropTarget=CreateFrame("Frame",nil,panel);dropTarget:SetAllPoints(panel)
    dropTarget:SetFrameLevel(panel:GetFrameLevel()+100);dropTarget:EnableMouse(false)
    panel.itemDropTarget=dropTarget
    local function drop()
        if InCombatLockdown() or panel.selectedTab~=2 then return end
        local kind,id=GetCursorInfo()
        if kind=="item" then
            local ok,reason=F:AddCustomItem(id)
            message:SetText(reason or "")
            if ok then ClearCursor() end
            dropTarget:EnableMouse(false)
        end
    end
    dropTarget:SetScript("OnReceiveDrag",drop);dropTarget:SetScript("OnMouseDown",drop)
    dropTarget:SetScript("OnUpdate",function()
        dropTarget:EnableMouse(panel.selectedTab==2 and not InCombatLockdown() and GetCursorInfo()=="item")
    end)
    local tableTop=90
    local content=F:CreateTableBody(page,tableTop,8)
    panel.itemContent=content
    local cogX,columnStep=956,44
    local combatX=cogX-columnStep-(32-24)/2
    local queueX=combatX-7*columnStep
    local statusX=queueX-76
    local nameWidth=statusX-192
    text("Enabled",22,-64,65)
    local buffHeading=text("Enable in\nBuff Mode",71,-54,48);buffHeading:SetJustifyH("CENTER")
    text("Item",182,-64,nameWidth)
    F:FlexColumn(text("Status",statusX,-64,65),columnStep,columnStep)
    local combatHeading,bypassHeading
    for index,label in ipairs({"Queue","Self","Party","Raid","Target","Focus","Bypass Q","Enable in\nCombat\nMode"}) do
        local queue=label=="Queue" or label=="Bypass Q"
        local x=queueX-11+(index-1)*columnStep
        local bypassShift=index<=6 and columnStep or 0
        local combatShift=index<=7 and columnStep or 0
        local heading=text(label,x,queue and -46 or index==8 and -48 or -64,columnStep); heading:SetJustifyH("CENTER");F:FlexColumn(heading,bypassShift,combatShift)
        if queue then
            local modifier=text("",x,-64,columnStep);modifier:SetJustifyH("CENTER");F:FlexColumn(modifier,bypassShift,combatShift)
            if label=="Queue" then panel.itemQueueModifier=modifier else panel.itemBypassModifier=modifier end
        end
        if index==8 then combatHeading=heading end
        if label=="Bypass Q" then bypassHeading=heading end
    end
    local hint=content.scroll:CreateFontString(nil,"OVERLAY","GameFontNormal")
    hint:SetText("Drag and drop a bag item to add.");hint:SetJustifyH("CENTER")
    hint:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",14,"")
    panel.itemDropHint=hint
    function panel:UpdateItemDropHint()
        local scroll=content.scroll
        local blankTop=math.max(0,(self.visibleBagItems or #F.db.items)*36-scroll:GetVerticalScroll())
        local height=scroll:GetHeight()-blankTop
        hint:SetShown(height>=30)
        if height>=30 then
            hint:ClearAllPoints();hint:SetPoint("TOP",page,"TOP",0,-tableTop-blankTop)
            hint:SetSize(page:GetWidth(),height)
        end
    end
    content.scroll:HookScript("OnVerticalScroll",function()panel:UpdateItemDropHint()end)
    content.scroll:HookScript("OnSizeChanged",function()panel:UpdateItemDropHint()end)
    local rows={}
    local search=F:CreateListSearch(page,function() panel:UpdateItemRows();content.scroll:SetVerticalScroll(0) end)
    panel.itemSearch=search
    local function createRow(index)
        local i=index
        local row=CreateFrame("Frame",nil,content); row:SetPoint("TOPLEFT",0,-(i-1)*36); row:SetSize(970,34)
        row.listContent=content
        local background=row:CreateTexture(nil,"BACKGROUND");background:SetAllPoints()
        background:SetColorTexture(1,.82,0,i%2==0 and .055 or 0)
        row.number=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        row.number:SetPoint("LEFT",6,0); row.number:SetWidth(22); row.number:SetJustifyH("LEFT")
        row.enabled=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate"); row.enabled:SetPoint("LEFT",30,0)
        row.buffVisible=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate");row.buffVisible:SetPoint("LEFT",82,0)
        row:EnableMouse(true)
        row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(26,26); row.icon:SetPoint("LEFT",148,0)
        row.name=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); row.name:SetPoint("LEFT",182,0); row.name:SetWidth(nameWidth); row.name:SetJustifyH("LEFT")
        F:SetRowDetailTooltip(row,function(area)
            local entry=F.db.items[row.itemIndex]
            if not entry then return end
            GameTooltip:SetOwner(area,"ANCHOR_RIGHT")
            if GameTooltip.SetItemByID then GameTooltip:SetItemByID(entry.id) else GameTooltip:SetText(F:CustomItemData(entry.id).name) end
            GameTooltip:Show()
        end)
        row.status=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); row.status:SetPoint("LEFT",statusX,0); row.status:SetWidth(65); row.status:SetJustifyH("LEFT")
        for slot,column in ipairs({"queue","self","party","raid","target","focus","priority","combat"}) do
            local checkbox=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate")
            checkbox:SetPoint("LEFT",queueX+(slot-1)*columnStep,0)
            F:FlexColumn(checkbox,slot<=6 and columnStep or 0,slot<=7 and columnStep or 0)
            row[column]=checkbox
        end
        for _,scope in ipairs({"self","party","raid","target","focus"}) do F:SetScopeTooltip(row[scope],scope) end
        row.priority:SetScript("OnClick",function()
            local entry=F.db.items[row.itemIndex]
            if not InCombatLockdown() and F.db.bypassEnabled and entry and not entry.combat then entry.prioritySelected=row.priority:GetChecked(); F:Refresh() end
        end)
        row.priority:SetScript("OnEnter",function()
            GameTooltip:SetOwner(row.priority,"ANCHOR_RIGHT"); GameTooltip:SetText("Bypass queue")
            GameTooltip:AddLine(F:PriorityHelp(),.8,.8,.8,true); GameTooltip:Show()
        end)
        row.priority:SetScript("OnLeave",function() GameTooltip:Hide() end)
        row.combat:SetScript("OnClick",function()
            local entry=F.db.items[row.itemIndex]
            if InCombatLockdown() or not entry then return end
            entry.combat=row.combat:GetChecked()==true
            if entry.combat then entry.queue=false; entry.prioritySelected=false end
            F:Refresh()
        end)
        F:SetCombatTooltip(row.combat)
        row.buffVisible:SetScript("OnClick",function()
            local entry=F.db.items[row.itemIndex]
            if InCombatLockdown() or not entry then return end
            entry.buffVisible=row.buffVisible:GetChecked()==true
            F:Refresh()
        end)
        row.buffVisible:SetScript("OnEnter",function()
            GameTooltip:SetOwner(row.buffVisible,"ANCHOR_RIGHT");GameTooltip:SetText("Enable in Buff Mode")
            GameTooltip:AddLine("Show this item on selected frames outside combat. Combat items remain outside the buff queues.",.8,.8,.8,true)
            GameTooltip:Show()
        end)
        row.buffVisible:SetScript("OnLeave",function()GameTooltip:Hide()end)
        for _,scope in ipairs({"self","raid","target","focus"}) do
            local key=scope
            row[key]:SetScript("OnClick",function()
                if not InCombatLockdown() and F.db.items[row.itemIndex] then F.db.items[row.itemIndex][key]=row[key]:GetChecked(); F:Refresh() end
            end)
        end
        row.party:SetScript("OnClick",function()
            if not InCombatLockdown() and F.db.items[row.itemIndex] then F.db.items[row.itemIndex].party=row.party:GetChecked(); F:Refresh() end
        end)
        row.buff=CreateFrame("Button",nil,row,"UIPanelButtonTemplate"); row.buff:SetPoint("LEFT",cogX,0); row.buff:SetSize(24,24)
        local settingsIcon=row.buff:CreateTexture(nil,"OVERLAY")
        settingsIcon:SetAtlas("OptionsIcon-Brown")
        settingsIcon:SetSize(16,16); settingsIcon:SetPoint("CENTER")
        row.buff:SetScript("OnClick",function()
            local entry=F.db.items[row.itemIndex]
            if entry then F:OpenItemBuffEditor(entry.id) end
        end)
        row.buff:SetScript("OnEnter",function()
            GameTooltip:SetOwner(row.buff,"ANCHOR_RIGHT"); GameTooltip:SetText("Configure item modes, targets and effect detection"); GameTooltip:Show()
        end)
        row.buff:SetScript("OnLeave",function() GameTooltip:Hide() end)
        row.queue:SetScript("OnEnter",function()
            GameTooltip:SetOwner(row.queue,"ANCHOR_RIGHT"); GameTooltip:SetText("Standard queue")
            GameTooltip:AddLine(F:QueueHelp(),.8,.8,.8,true); GameTooltip:Show()
        end)
        row.queue:SetScript("OnLeave",function() GameTooltip:Hide() end)
        row.enabled:SetScript("OnClick",function()
            if not InCombatLockdown() and F.db.items[row.itemIndex] then F.db.items[row.itemIndex].enabled=row.enabled:GetChecked(); F:Refresh() end
        end)
        row.queue:SetScript("OnClick",function()
            local entry=F.db.items[row.itemIndex]
            if not InCombatLockdown() and entry and not entry.combat then entry.queue=row.queue:GetChecked(); F:Refresh() end
        end)
        row.up=F:CreateReorderArrow(row,998,-1,function() F:MoveCustomItem(row.itemIndex,-1) end)
        row.down=F:CreateReorderArrow(row,1024,1,function() F:MoveCustomItem(row.itemIndex,1) end)
        row.remove=CreateFrame("Button",nil,row,"UIPanelButtonTemplate"); row.remove:SetSize(24,24); row.remove:SetPoint("LEFT",1054,0); row.remove:SetText("X")
        row.remove:SetScript("OnClick",function() F:RemoveCustomItem(row.itemIndex) end)
        row.remove:SetScript("OnEnter",function() GameTooltip:SetOwner(row.remove,"ANCHOR_RIGHT"); GameTooltip:SetText("Remove item"); GameTooltip:Show() end)
        row.remove:SetScript("OnLeave",function() GameTooltip:Hide() end)

        F:EnableRowReorder(row,content,rows,36,function() return F.db.items[row.itemIndex] and F.db.items[row.itemIndex].id end,function(id,to)
            local from
            for position,item in ipairs(F.db.items) do if item.id==id then from=position; break end end
            to=math.min(#F.db.items,to)
            if from and from~=to then table.insert(F.db.items,to,table.remove(F.db.items,from)) end
        end,function() return row.itemIndex~=nil and not panel.itemSearching end)

        F:FlexRow(row);F:FlexName(row.name,columnStep,columnStep)
        F:FlexColumn(row.status,columnStep,columnStep)
        for _,control in ipairs({row.buff,row.remove})do F:FlexColumn(control)end
        rows[i]=row
    end
    function panel:UpdateItemRows()
        self.itemQueueModifier:SetText("("..F.db.frameModifier:upper()..")")
        self.itemBypassModifier:SetText("("..F.db.priorityModifier:upper()..")")
        bypassHeading:SetShown(F.db.bypassEnabled);self.itemBypassModifier:SetShown(F.db.bypassEnabled)
        combatHeading:SetShown(F.db.combatClicks)
        local query=search.query or ""
        self.itemSearching=query~=""
        local visible={}
        for index,entry in ipairs(F.db.items) do
            local data=F:CustomItemData(entry.id)
            if query=="" or data.name:lower():find(query,1,true) or tostring(entry.id):find(query,1,true) then
                visible[#visible+1]={entry=entry,index=index,data=data}
            end
        end
        self.visibleBagItems=#visible
        for index=#rows+1,#visible do createRow(index) end
        F:SizeOptionsContent(content,math.max(108,#visible*36))
        self:UpdateItemDropHint()
        for index,row in ipairs(rows) do
            local match=visible[index]
            local entry=match and match.entry
            row.itemIndex=match and match.index
            row:SetShown(entry~=nil)
            if entry then
                row.number:SetText(match.index)
                local data=match.data
                local queuesEnabled=not entry.combat and not InCombatLockdown()
                local queueAlpha=queuesEnabled and 1 or .35
                row.enabled:SetChecked(entry.enabled); row.queue:SetChecked(not entry.combat and entry.queue); row.party:SetChecked(entry.party==true); row.self:SetChecked(entry.self~=false); row.raid:SetChecked(entry.raid==true)
                row.queue:SetEnabled(queuesEnabled)
                row.queue:SetAlpha(queueAlpha); row.priority:SetAlpha(queueAlpha)
                row.priority:SetChecked(not entry.combat and entry.prioritySelected==true); row.priority:SetEnabled(queuesEnabled)
                row.priority:SetShown(F.db.bypassEnabled)
                row.buffVisible:SetChecked(entry.buffVisible==true);row.buffVisible:SetEnabled(not InCombatLockdown())
                row.combat:SetShown(F.db.combatClicks); row.combat:SetChecked(entry.combat==true); row.combat:SetEnabled(not InCombatLockdown())
                row.focus:SetChecked(entry.focus==true);row.focus:SetEnabled(not InCombatLockdown())
                row.target:SetChecked(entry.target==true); row.target:SetEnabled(not InCombatLockdown())
                row.name:SetText(data.name); row.status:SetText(data.status..(data.count>0 and (" ("..data.count..")") or ""))
                F:ResizeRowNameTooltip(row.name)
                row.icon:SetTexture(C_Item.GetItemIconByID and C_Item.GetItemIconByID(entry.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.up:SetEnabled(not self.itemSearching and index>1); row.down:SetEnabled(not self.itemSearching and index<#F.db.items)
                row.up:SetAlpha(index>1 and 1 or .4); row.down:SetAlpha(index<#F.db.items and 1 or .4)
                row:SetAlpha(entry.enabled and 1 or .5)
            end
        end
    end
    panel.itemRows=rows
    self:CreateItemBuffEditor(panel)
    panel.syncers[#panel.syncers+1]=function() panel:UpdateItemRows(); message:SetText("") end
    panel:UpdateItemRows()
end
