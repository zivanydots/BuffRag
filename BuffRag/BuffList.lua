local _, F = ...
function F:CreateBuffList(panel,page)
    self:AddPrimaryOptionsHeading(page,"Buff order and targets",0,0)
    self:FlexName(self:AddOptionsText(page,"Choose which buffs appear on each frame and set their casting order.",0,-30,950))
    local content=self:CreateTableBody(page,90,8)
    panel.buffContent=content
    local hasKeep=false
    for _,entry in ipairs(self.catalogue) do
        if not entry.stockOnly and (entry.stone or entry.keepKey) then hasKeep=true; break end
    end
    panel.hasKeepColumn=hasKeep
    local hasOptions=false
    for _,entry in ipairs(self.catalogue) do if entry.kind=="poison" then hasOptions=true; break end end
    local reorderX,columnStep=1029,62
    local lastCheckboxX=reorderX-columnStep-(32-18)/2
    local priorityX=lastCheckboxX-(hasKeep and columnStep or 0)
    local queueX=priorityX-6*columnStep
    local nameWidth=queueX-142-(hasOptions and 170 or 0)
    local scopeX=queueX+columnStep
    local function column(label,x,y,bypassShift)
        local heading=self:AddOptionsText(page,label,x-19,y or -64,70)
        heading:SetWidth(70)
        heading:SetJustifyH("CENTER")
        F:FlexColumn(heading,bypassShift)
        return heading
    end
    self:AddOptionsText(page,"Enabled",22,-64,65)
    self:AddOptionsText(page,"Buff / Ability",130,-64,nameWidth)
    column("Queue",queueX,-46,columnStep)
    panel.buffQueueModifier=column("",queueX,nil,columnStep)
    for index,label in ipairs({"Self","Party","Raid","Target","Focus"}) do column(label,scopeX+(index-1)*columnStep,nil,columnStep) end
    local bypassHeading=column("Bypass Q",priorityX,-46)
    panel.buffBypassModifier=column("",priorityX)
    if hasKeep then panel.keepHeading=column("Keep in bag",lastCheckboxX) end
    local rows={}
    local function move(source,to)
        local from
        for index,key in ipairs(F.db.priority) do if key==source then from=index end end
        if from and to and from~=to then
            table.remove(F.db.priority,from); table.insert(F.db.priority,to,source)
            F.db.selfPriority=F:CopySettings(F.db.priority)
        end
    end
    local function createRow(index)
        local row=CreateFrame("Frame",nil,content)
        row.listContent=content
        row:SetPoint("TOPLEFT",0,-(index-1)*38); row:SetSize(970,36)
        row:EnableMouse(true); row:RegisterForDrag("LeftButton")
        local background=row:CreateTexture(nil,"BACKGROUND"); background:SetAllPoints()
        background:SetColorTexture(1,.82,0,index%2==0 and .055 or 0)
        row.number=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); row.number:SetPoint("LEFT",6,0)
        row.number:SetText(index)
        row.enabled=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate")
        row.enabled:SetPoint("LEFT",30,0)
        row.enabled:SetScript("OnClick",function() F:SetBuffEnabled(row.key,row.enabled:GetChecked()) end)
        row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetPoint("LEFT",96,0); row.icon:SetSize(26,26)
        row.label=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); row.label:SetPoint("LEFT",130,0)
        row.label:SetWidth(nameWidth); row.label:SetJustifyH("LEFT")
        row.configured=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        row.configured:SetText("Configured in Bag Items tab")
        if hasOptions then
                                                                          
                                                                            
            row.extra=CreateFrame("DropdownButton",nil,row,"WowStyle1DropdownTemplate")
            row.extra:SetPoint("LEFT",scopeX-220,0); row.extra:SetSize(148,26)
            row.extra:SetDefaultText("Choose hand")
            row.extra:SetupMenu(function(_,root)
                for _,choice in ipairs(F.handChoices) do
                    local value=choice[2]
                    root:CreateRadio(choice[1],function() return (F.db.poisonHands[row.key] or "none")==value end,
                        function() F:SetPoisonHand(row.key,value) end)
                end
            end)
        end
        row.queue=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate")
        row.queue:SetPoint("LEFT",queueX,0)
        row.queue:SetScript("OnClick",function() F:SetBuffQueue(row.key,row.queue:GetChecked()) end)
        row.queue:SetScript("OnEnter",function()
            GameTooltip:SetOwner(row.queue,"ANCHOR_RIGHT"); GameTooltip:SetText("Standard queue")
            GameTooltip:AddLine(F:QueueHelp(),.8,.8,.8,true); GameTooltip:Show()
        end)
        row.queue:SetScript("OnLeave",function() GameTooltip:Hide() end)
        row.scopes={}
        for column,scope in ipairs({"self","party","raid","target","focus"}) do
            local key=scope
            local check=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate")
            check:SetPoint("LEFT",scopeX+(column-1)*columnStep,0)
            check:SetScript("OnClick",function() F:SetBuffScope(row.key,key,check:GetChecked()) end)
            F:SetScopeTooltip(check,key)
            row.scopes[key]=check
        end
        row.priority=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate")
        row.priority:SetPoint("LEFT",priorityX,0)
        row.priority:SetScript("OnClick",function() F:SetBuffPriority(row.key,row.priority:GetChecked()) end)
        row.priority:SetScript("OnEnter",function()
            GameTooltip:SetOwner(row.priority,"ANCHOR_RIGHT"); GameTooltip:SetText("Bypass queue")
            GameTooltip:AddLine(F:PriorityHelp(),.8,.8,.8,true); GameTooltip:Show()
        end)
        row.priority:SetScript("OnLeave",function() GameTooltip:Hide() end)
        if hasKeep then
            row.keep=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate")
            row.keep:SetPoint("LEFT",lastCheckboxX,0)
            row.keep:SetScript("OnClick",function() F:SetKeepInBag(row.key,row.keep:GetChecked()) end)
        end
        row.up=F:CreateReorderArrow(row,reorderX,-1,function() F:MoveBuff(index,-1) end)
        row.down=F:CreateReorderArrow(row,reorderX+26,1,function() F:MoveBuff(index,1) end)
        F:EnableRowReorder(row,content,rows,38,function() return row.key end,move,function() return row.available end)
        F:SetRowDetailTooltip(row,function(area)
            local entry=F.spells[row.key]
            if not entry then return end
            GameTooltip:SetOwner(area,"ANCHOR_RIGHT")
            if entry.kind=="items" then
                GameTooltip:SetText(entry.label)
                GameTooltip:AddLine("Items appear at this position. Configure each item on Bag Items.",.8,.8,.8,true)
            else
                local _,id=F:LearnedSpell(entry.ids)
                id=id or entry.ids[1]
                if id and GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(id)
                else GameTooltip:SetText(entry.label) end
            end
            GameTooltip:Show()
        end)
        F:FlexName(row.label,columnStep);F:FlexRow(row)
        F:FlexColumn(row.queue,columnStep);F:FlexColumn(row.priority)
        for _,control in pairs(row.scopes)do F:FlexColumn(control,columnStep)end
        if row.keep then F:FlexColumn(row.keep)end
        if row.extra then F:FlexColumn(row.extra,columnStep)end
        rows[index]=row
    end
    function panel:UpdateBuffRows()
        self.buffQueueModifier:SetText("("..F.db.frameModifier:upper()..")")
        self.buffBypassModifier:SetText("("..F.db.priorityModifier:upper()..")")
        bypassHeading:SetShown(F.db.bypassEnabled);self.buffBypassModifier:SetShown(F.db.bypassEnabled)
        for index=#rows+1,#F.db.priority do createRow(index) end
        for index,row in ipairs(rows) do
            local key=F.db.priority[index]
            row:SetShown(key~=nil)
            if key then
                row.key=key
                local entry=F.spells[key]
                local _,id=F:LearnedSpell(entry.ids)
                local available=F:BuffAvailable(entry)
                local editable=available and not InCombatLockdown()
                local enabled=F:BuffRowEnabled(key)
                row.enabled:SetChecked(enabled); row.enabled:SetEnabled(editable)
                row.available=available
                row.label:SetText(entry.label)
                F:ResizeRowNameTooltip(row.label)
                if entry.kind=="items" then F:CenterItemPlaceholder(row,130,row.up) end
                local poisonItem=entry.kind=="poison" and F:PoisonItem(entry)
                row.icon:SetTexture(poisonItem and C_Item.GetItemIconByID(poisonItem) or (entry.kind=="items" and F.itemsIcon or C_Spell.GetSpellTexture(id or entry.ids[1])) or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.icon:SetDesaturated(not available)
                row:SetAlpha(panel.dragBuffKey==key and .6 or (available and enabled and 1 or .5))
                row:EnableMouse(editable)
                row.configured:SetShown(entry.kind=="items")
                if row.extra then
                    row.extra:SetShown(entry.kind=="poison"); row.extra:SetEnabled(editable)
                    local label="Choose hand"
                    for _,choice in ipairs(F.handChoices) do if choice[2]==F.db.poisonHands[key] then label=choice[1] end end
                    row.extra:SetDefaultText(label)
                    if row.extra.GenerateMenu then row.extra:GenerateMenu() end
                end
                for scope,check in pairs(row.scopes) do
                    check:SetShown(entry.kind~="items" and not entry.buffStockOnly and (scope=="self" or not entry.selfOnly))
                    check:SetChecked(F.db.targetScopes[key][scope])
                    check:SetEnabled(editable)
                end
                if row.keep then
                    local repeatable=not entry.stockOnly and (entry.stone~=nil or entry.keepKey~=nil)
                    row.keep:SetShown(repeatable)
                    row.keep:SetChecked(F:KeepsEntry(entry))
                    row.keep:SetEnabled(editable and repeatable)
                end
                row.priority:SetShown(F.db.bypassEnabled and entry.kind~="items")
                row.queue:SetShown(entry.kind~="items")
                row.queue:SetChecked(F.db.standardQueue[key]~=false)
                row.queue:SetEnabled(editable and not entry.manual)
                row.priority:SetChecked(F.db.priorityBuffs[key])
                row.priority:SetEnabled(editable and not entry.manual)
                row.up:SetEnabled(editable and index>1)
                row.down:SetEnabled(editable and index<#F.db.priority)
                row.up:SetAlpha(editable and index>1 and 1 or .4)
                row.down:SetAlpha(editable and index<#F.db.priority and 1 or .4)
            end
        end
        F:SizeOptionsContent(content,math.max(1,#F.db.priority*38))
    end
    panel.buffRows=rows
    panel.syncers[#panel.syncers+1]=function() panel:UpdateBuffRows() end
    panel:UpdateBuffRows()
end
