local _, F = ...
function F:CreateBuffList(panel,page)
    self:AddPrimaryOptionsHeading(page,"Buff order and targets",0,0)
    local hasKeep=false
    for _,entry in ipairs(self.catalogue) do
        if not entry.stockOnly and (entry.stone or entry.keepKey) then hasKeep=true; break end
    end
    panel.hasKeepColumn=hasKeep
    local hasOptions=false
    for _,entry in ipairs(self.catalogue) do if entry.kind=="poison" then hasOptions=true; break end end
    local nameWidth=hasOptions and 230 or (hasKeep and 330 or 400)
    local queueX=hasKeep and 472 or 542
    local scopeX=queueX+62
    local priorityX=queueX+372
    local function column(label,x,y)
        local heading=self:AddOptionsText(page,label,x-19,y or -64,70)
        heading:SetJustifyH("CENTER")
        F:FlexColumn(heading)
        return heading
    end
    self:AddOptionsText(page,"Enabled",22,-64,65)
    self:AddOptionsText(page,"Buff / Ability",130,-64,nameWidth)
    column("Queue",queueX,-46)
    panel.buffQueueModifier=column("",queueX)
    for index,label in ipairs({"Self","Party","Raid","Target","Focus"}) do column(label,scopeX+(index-1)*62) end
    column("Bypass Q",priorityX,-46)
    panel.buffBypassModifier=column("",priorityX)
    if hasKeep then panel.keepHeading=column("Keep in bag",queueX+434) end
    local content=self:CreateTableBody(page,90,58)
    panel.buffContent=content
    local note=self:CreateTableFooter(page,content,function() return "Drag rows or use arrows to set order. Targets enable icons on frames. Queue and Bypass Q select the two independent casting queues." end)
    panel.unlearnedNote=note
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
            check:SetPoint("LEFT",scopeX+(column-1)*62,0)
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
            row.keep:SetPoint("LEFT",queueX+434,0)
            row.keep:SetScript("OnClick",function() F:SetKeepInBag(row.key,row.keep:GetChecked()) end)
        end
        local function arrow(x,direction,label)
            local button=CreateFrame("Button",nil,row,"UIPanelButtonTemplate")
            button:SetPoint("LEFT",x,0); button:SetSize(27,24); button:SetText(label)
            button:SetScript("OnClick",function() F:MoveBuff(index,direction) end)
            return button
        end
        row.up,row.down=arrow(1020,-1,"^"),arrow(1055,1,"v")
        F:EnableRowReorder(row,content,rows,38,function() return row.key end,move,function() return row.available end)
        row:SetScript("OnEnter",function()
            local entry=F.spells[row.key]
            if not entry then return end
            GameTooltip:SetOwner(row,"ANCHOR_RIGHT")
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
        row:SetScript("OnLeave",function() GameTooltip:Hide() end)
        F:FlexName(row.label);F:FlexRow(row)
        for _,control in ipairs({row.queue,row.priority,row.up,row.down})do F:FlexColumn(control)end
        for _,control in pairs(row.scopes)do F:FlexColumn(control)end
        if row.keep then F:FlexColumn(row.keep)end
        if row.extra then F:FlexColumn(row.extra)end
        rows[index]=row
    end
    function panel:UpdateBuffRows()
        self.buffQueueModifier:SetText("("..F.db.frameModifier:upper()..")")
        self.buffBypassModifier:SetText("("..F.db.priorityModifier:upper()..")")
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
                row.priority:SetShown(entry.kind~="items")
                row.queue:SetShown(entry.kind~="items")
                row.queue:SetChecked(F.db.standardQueue[key]~=false)
                row.queue:SetEnabled(editable and not entry.manual)
                row.priority:SetChecked(F.db.priorityBuffs[key])
                row.priority:SetEnabled(editable and not entry.manual)
                row.up:SetEnabled(editable and index>1)
                row.down:SetEnabled(editable and index<#F.db.priority)
            end
        end
        F:SizeOptionsContent(content,math.max(1,#F.db.priority*38))
    end
    panel.buffRows=rows
    panel.syncers[#panel.syncers+1]=function() panel:UpdateBuffRows() end
    panel:UpdateBuffRows()
end
