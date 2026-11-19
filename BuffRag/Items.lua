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
    if start==nil and duration==nil then return true end -- no exposed bag-use timer
    if type(start)~="number" or type(duration)~="number" then return false end
    -- Bag-use effects can have no cooldown timer or a disabled timer flag.
    -- Neither use-spell metadata nor that flag is needed for a normal /use.
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
    for _,stone in pairs(self.class=="WARLOCK" and self.stoneTypes or {}) do
        for _,stoneID in ipairs(stone.items) do if stoneID==id then return false,"Configure warlock stones on the Buffs tab." end end
    end
    for _,entry in ipairs(self.db.items) do if entry.id==id then return false,"That item is already in your list." end end
    self.db.items[#self.db.items+1]={id=id,enabled=true,queue=true,self=true,party=false,raid=false,target=false,prioritySelected=false,buffMode="auto"}
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
    local master=CreateFrame("CheckButton","BuffRagItemsEnabled",page,"UICheckButtonTemplate")
    master:SetPoint("TOPLEFT",0,-25); master.text:SetText("Show Pots / Items")
    master:SetScript("OnClick",function()
        if not InCombatLockdown() then F.db.itemsEnabled=master:GetChecked(); F:Refresh() end
    end)
    text("Drop a bag-use item here, or paste its item link / ID. Equipment is not supported.",0,-65)
    local input=CreateFrame("EditBox","BuffRagItemInput",page,"InputBoxTemplate")
    input:SetPoint("TOPLEFT",8,-97); input:SetSize(750,24); input:SetAutoFocus(false)
    local message=text("",0,-133); message:SetTextColor(1,.4,.3)
    local function add(value)
        local ok,reason=F:AddCustomItem(value)
        message:SetText(reason or "")
        if ok then input:SetText(""); input:ClearFocus() end
    end
    local function drop()
        if InCombatLockdown() then return end
        local kind,id=GetCursorInfo()
        if kind=="item" then ClearCursor(); add(id) end
    end
    input:SetScript("OnReceiveDrag",drop)
    input:SetScript("OnMouseDown",function() if GetCursorInfo()=="item" then drop() end end)
    input:SetScript("OnEnterPressed",function() add(input:GetText()) end)
    input:SetScript("OnEscapePressed",function() input:ClearFocus() end)
    local addButton=CreateFrame("Button","BuffRagAddItem",page,"UIPanelButtonTemplate")
    addButton:SetPoint("TOPLEFT",800,-97); addButton:SetSize(150,24); addButton:SetText("Add item")
    addButton:SetScript("OnClick",function() add(input:GetText()) end)
    F:AddOptionsHeading(page,"Item queue - drag rows or use arrows to reorder",0,-160,970)
    text("Enabled",22,-190,65); text("Item",130,-190,165); text("Status",305,-190,85); text("Queue",400,-190,45); text("Self",450,-190,45); text("Party",500,-190,45); text("Raid",550,-190,45); text("Target",600,-190,50); text("Priority Q",650,-190,85)
    local content=F:CreateTableBody(page,215,58)
    panel.itemContent=content
    local empty=F:AddOptionsText(content,"Add your first item to build a quick-use list.",38,-20,600)
    local rows={}
    local function createRow(index)
        local i=index
        local row=CreateFrame("Frame",nil,content); row:SetPoint("TOPLEFT",0,-(i-1)*36); row:SetSize(970,34)
        row.number=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        row.number:SetPoint("LEFT",6,0); row.number:SetWidth(22); row.number:SetJustifyH("LEFT")
        row.enabled=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate"); row.enabled:SetPoint("LEFT",30,0)
        row:EnableMouse(true)
        row:SetScript("OnEnter",function()
            local entry=F.db.items[index]
            if not entry then return end
            GameTooltip:SetOwner(row,"ANCHOR_RIGHT")
            if GameTooltip.SetItemByID then GameTooltip:SetItemByID(entry.id) else GameTooltip:SetText(F:CustomItemData(entry.id).name) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave",function() GameTooltip:Hide() end)
        row:SetScript("OnHide",function() if GameTooltip:GetOwner()==row then GameTooltip:Hide() end end)
        row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(26,26); row.icon:SetPoint("LEFT",96,0)
        row.name=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); row.name:SetPoint("LEFT",130,0); row.name:SetWidth(165); row.name:SetJustifyH("LEFT")
        row.status=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); row.status:SetPoint("LEFT",305,0); row.status:SetWidth(85); row.status:SetJustifyH("LEFT")
        row.queue=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate"); row.queue:SetPoint("LEFT",390,0)
        row.party=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate"); row.party:SetPoint("LEFT",490,0)
        row.self=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate"); row.self:SetPoint("LEFT",440,0)
        row.raid=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate"); row.raid:SetPoint("LEFT",540,0)
        row.target=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate"); row.target:SetPoint("LEFT",590,0)
        for _,scope in ipairs({"self","party","raid","target"}) do F:SetScopeTooltip(row[scope],scope) end
        row.priority=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate"); row.priority:SetPoint("LEFT",662,0)
        row.priority:SetScript("OnClick",function()
            if not InCombatLockdown() and F.db.items[index] then F.db.items[index].prioritySelected=row.priority:GetChecked(); F:Refresh() end
        end)
        row.priority:SetScript("OnEnter",function()
            GameTooltip:SetOwner(row.priority,"ANCHOR_RIGHT"); GameTooltip:SetText("Priority queue")
            GameTooltip:AddLine(F:PriorityHelp(),.8,.8,.8,true); GameTooltip:Show()
        end)
        row.priority:SetScript("OnLeave",function() GameTooltip:Hide() end)
        for _,scope in ipairs({"self","raid","target"}) do
            local key=scope
            row[key]:SetScript("OnClick",function()
                if not InCombatLockdown() and F.db.items[index] then F.db.items[index][key]=row[key]:GetChecked(); F:Refresh() end
            end)
        end
        row.party:SetScript("OnClick",function()
            if not InCombatLockdown() and F.db.items[index] then F.db.items[index].party=row.party:GetChecked(); F:Refresh() end
        end)
        row.buff=CreateFrame("Button",nil,row,"UIPanelButtonTemplate"); row.buff:SetPoint("LEFT",740,0); row.buff:SetSize(56,24); row.buff:SetText("Buff")
        row.buff:SetScript("OnClick",function()
            local entry=F.db.items[index]
            if entry then F:OpenItemBuffEditor(entry.id) end
        end)
        row.buff:SetScript("OnEnter",function()
            GameTooltip:SetOwner(row.buff,"ANCHOR_RIGHT"); GameTooltip:SetText("Manually configure buff detection if required"); GameTooltip:Show()
        end)
        row.buff:SetScript("OnLeave",function() GameTooltip:Hide() end)
        row.queue:SetScript("OnEnter",function()
            GameTooltip:SetOwner(row.queue,"ANCHOR_RIGHT"); GameTooltip:SetText("Standard queue")
            GameTooltip:AddLine(F:QueueHelp(),.8,.8,.8,true); GameTooltip:Show()
        end)
        row.queue:SetScript("OnLeave",function() GameTooltip:Hide() end)
        row.enabled:SetScript("OnClick",function()
            if not InCombatLockdown() and F.db.items[index] then F.db.items[index].enabled=row.enabled:GetChecked(); F:Refresh() end
        end)
        row.queue:SetScript("OnClick",function()
            if not InCombatLockdown() and F.db.items[index] then F.db.items[index].queue=row.queue:GetChecked(); F:Refresh() end
        end)
        local function arrow(x,direction)
            local button=CreateFrame("Button",nil,row); button:SetSize(24,24); button:SetPoint("LEFT",x,0)
            local path="Interface\\Buttons\\UI-ScrollBar-Scroll"..(direction==-1 and "Up" or "Down").."Button-"
            button:SetNormalTexture(path.."Up"); button:SetPushedTexture(path.."Down"); button:SetDisabledTexture(path.."Disabled"); button:SetHighlightTexture(path.."Highlight")
            button:SetScript("OnClick",function() F:MoveCustomItem(index,direction) end)
            return button
        end
        row.up=arrow(805,-1); row.down=arrow(840,1)
        row.remove=CreateFrame("Button",nil,row,"UIPanelButtonTemplate"); row.remove:SetSize(80,24); row.remove:SetPoint("LEFT",880,0); row.remove:SetText("Remove")
        row.remove:SetScript("OnClick",function() F:RemoveCustomItem(index) end)

        F:EnableRowReorder(row,content,rows,36,function() return F.db.items[index] and F.db.items[index].id end,function(id,to)
            local from
            for position,item in ipairs(F.db.items) do if item.id==id then from=position; break end end
            to=math.min(#F.db.items,to)
            if from and from~=to then table.insert(F.db.items,to,table.remove(F.db.items,from)) end
        end,function() return F.db.items[index]~=nil end)

        rows[i]=row
    end
    panel.itemFooter=F:CreateTableFooter(page,content,function() return F:TableUsageHelp("items") end)
    function panel:UpdateItemRows()
        for index=#rows+1,#F.db.items do createRow(index) end
        F:SizeOptionsContent(content,math.max(60,#F.db.items*36))
        master:SetChecked(F.db.itemsEnabled); master:SetEnabled(not InCombatLockdown()); addButton:SetEnabled(not InCombatLockdown())
        empty:SetShown(#F.db.items==0)
        for index,row in ipairs(rows) do
            local entry=F.db.items[index]; row:SetShown(entry~=nil)
            if entry then
                row.number:SetText(index)
                local data=F:CustomItemData(entry.id)
                row.enabled:SetChecked(entry.enabled); row.queue:SetChecked(entry.queue); row.party:SetChecked(entry.party==true); row.self:SetChecked(entry.self~=false); row.raid:SetChecked(entry.raid==true)
                row.priority:SetChecked(entry.prioritySelected==true); row.priority:SetEnabled(not InCombatLockdown())
                row.target:SetChecked(entry.target==true); row.target:SetEnabled(not InCombatLockdown())
                row.name:SetText(data.name); row.status:SetText(data.status..(data.count>0 and (" ("..data.count..")") or ""))
                row.icon:SetTexture(C_Item.GetItemIconByID and C_Item.GetItemIconByID(entry.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.up:SetEnabled(index>1); row.down:SetEnabled(index<#F.db.items)
                row:SetAlpha(entry.enabled and 1 or .5)
            end
        end
    end
    panel.itemRows=rows
    self:CreateItemBuffEditor(panel)
    panel.syncers[#panel.syncers+1]=function() panel:UpdateItemRows(); message:SetText("") end
    panel:UpdateItemRows()
end
