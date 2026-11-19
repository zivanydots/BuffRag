local _,F=...
function F:CreateCombatPage(panel,page)
    self:AddPrimaryOptionsHeading(page,"Combat actions",0,0)
    local explanation={self:AddOptionsText(page,"Buffs prepares you outside combat; normal icons disappear when combat starts. Enable combat mode in Settings for fixed manual actions and after-combat Clean-up. Each frame/profile has independent SHIFT / CTRL / ALT assignments. Pet abilities require the correct pet. Combat health never changes protected actions or positions.",0,-30,1070)}
    for index,example in ipairs({{"Interface\\Icons\\Spell_Holy_FlashHeal","Party SHIFT: heal"},{"Interface\\Icons\\Spell_Shadow_Possession","Target SHIFT: Fear"},{"Interface\\Icons\\Spell_Shadow_MindRot","Focus CTRL: pet interrupt"}})do
        local icon=page:CreateTexture(nil,"ARTWORK");icon:SetSize(24,24);icon:SetPoint("TOPLEFT",(index-1)*350,-103);icon:SetTexture(example[1])
        explanation[#explanation+1]=icon
        explanation[#explanation+1]=self:AddOptionsText(page,example[2],32+(index-1)*350,-107,310)
    end
    explanation[#explanation+1]=self:AddOptionsText(page,"Each frame has independent SHIFT / CTRL / ALT assignments. Visible icons pack together. After combat, relevant healing, cleansing and resurrection actions remain until that friendly unit has recovered, then Buff mode returns. Native cooldown swipes and optional fading cast-result marks provide feedback.",0,-136,1070)
    local instruction=self:AddOptionsText(page,"Select a frame and Friendly/Enemy profile where applicable. Rows 1–3 assign SHIFT / CTRL / ALT; displayed icons pack together. Healing, cleansing and resurrection remain available for out-of-combat Clean-up.",0,-30,1070)
    local chrome=CreateFrame("Frame",nil,page);chrome:SetAllPoints(page)
    local function header(label,x,width,flex)
        local text=F:AddOptionsText(chrome,label,x,-132,width or 60);text:SetJustifyH("CENTER");if flex then F:FlexColumn(text)end;return text
    end
    header("Enabled",20,60);header("Spell / Ability",104,540)
    header("Level / Rank",662,140,true)
    header("Modifier",820,125,true)
    local frameTabs={}
    panel.combatScope=panel.combatScope or "self"
    panel.combatFrameScope=panel.combatFrameScope or 'self'
    panel.combatProfiles=panel.combatProfiles or {target='friendly',focus='friendly'}
    for index,choice in ipairs({{"Self Frame","self"},{"Party Frames","party"},{"Raid Frames","raid"},{"Target Frame","target"},{"Focus Frame","focus"}})do
        local scope=choice[2]
        local tab=CreateFrame("Button",nil,chrome);tab:SetSize(140,22);tab:SetPoint("TOPLEFT",(index-1)*145,-62)
        local background=tab:CreateTexture(nil,"BACKGROUND");background:SetAllPoints();background:SetColorTexture(.12,.10,.07,.85)
        local selected=tab:CreateTexture(nil,"ARTWORK");selected:SetAllPoints();selected:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
        local label=tab:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");label:SetPoint("CENTER");label:SetText(choice[1])
        tab:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2","ADD")
        tab.scope,tab.label,tab.selected=scope,label,selected
        tab:SetScript("OnClick",function()panel:SelectCombatScope(scope)end)
        frameTabs[index]=tab
    end
    local profileTabs={}
    for index,choice in ipairs({{'Friendly','friendly'},{'Enemy','enemy'}})do
        local tab=CreateFrame('Button',nil,chrome);tab:SetSize(70,21)
        tab.label=tab:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');tab.label:SetPoint('CENTER');tab.label:SetText(choice[1])
        tab.selected=tab:CreateTexture(nil,'BACKGROUND');tab.selected:SetAllPoints();tab.selected:SetTexture('Interface\\Buttons\\UI-Listbox-Highlight2')
        tab:SetHighlightTexture('Interface\\Buttons\\UI-Listbox-Highlight2','ADD')
        tab.profile=choice[2];tab:SetScript('OnClick',function()panel:SelectCombatProfile(choice[2])end)
        profileTabs[index]=tab
    end
    local dispels=CreateFrame('CheckButton',nil,chrome,'UICheckButtonTemplate');dispels:SetPoint('TOPLEFT',850,-61);dispels.text:SetText('Dispels only')
    dispels:SetScript('OnClick',function()panel.combatDispelsOnly=dispels:GetChecked();panel:UpdateCombatRows()end)
    F:AddOptionsDivider(chrome,0,-118,950)
    local keepHeading=header("Keep in bag",960,70,true)
    local pinned=CreateFrame('Frame',nil,chrome);pinned:SetPoint('TOPLEFT',page,'TOPLEFT',0,-158);pinned:SetSize(1090,114);F:FlexRow(pinned)
    local content=self:CreateTableBody(page,278,65)
    local footer=self:CreateTableFooter(page,content,function()
        return "Enabled controls only this frame tab. Rows 1–3 reserve SHIFT / CTRL / ALT and cannot be moved. Move to Top starts at 4. Enabled icon-only actions pack together; disabled rows create no icon gaps. Unlearned abilities are greyed out. Rank defaults to Highest learned."
    end)
    local rows={}
    local function dropdown(row,x,width)
        local control=CreateFrame("DropdownButton",nil,row,"WowStyle1DropdownTemplate")
        control:SetPoint("LEFT",x,0);control:SetSize(width,26);F:FlexColumn(control);return control
    end
    local function createRow(index)
        local row=CreateFrame("Frame",nil,index<=3 and pinned or content);row:SetPoint("TOPLEFT",0,-(index<=3 and index-1 or index-4)*38);row:SetSize(1090,36);F:FlexRow(row)
        local background=row:CreateTexture(nil,"BACKGROUND");background:SetAllPoints();background:SetColorTexture(1,.82,0,index%2==0 and .055 or 0)
        row.number=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");row.number:SetPoint("LEFT",6,0)
        row.enabled=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate");row.enabled:SetPoint("LEFT",30,0)
        row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetPoint("LEFT",72,0);row.icon:SetSize(26,26)
        row.label=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");row.label:SetPoint("LEFT",104,0);row.label:SetWidth(540);row.label:SetJustifyH("LEFT");F:FlexName(row.label)
        row.rank=dropdown(row,662,140)
        row.rank:SetupMenu(function(_,root)
            local data=row.data;if not data or not data.group then return end
            root:CreateRadio("Highest learned",function()return not data.frame.rankID end,function()data.frame.rankID=nil;F:Refresh()end)
            for _,rank in ipairs(data.group.ranks)do
                local id=rank.id
                local item=root:CreateRadio(rank.label,function()return data.frame.rankID==id end,function()if rank.learned then data.frame.rankID=id;F:Refresh()end end)
                if item and item.SetEnabled then item:SetEnabled(rank.learned==true)end
            end
            if data.group.effects and(data.group.effects.cleanse or data.group.effects.purge)then
                local create=root.CreateCheckbox or root.CreateRadio
                create(root,'Dispel reminders (! and Clean-up)',function()return data.frame.dispelReminders~=false end,function()data.frame.dispelReminders=data.frame.dispelReminders==false;F:Refresh()end)
            end
        end)
        row.modifier=dropdown(row,820,125)
        row.modifier:SetupMenu(function(_,root)
            local data=row.data;if not data or not data.group then return end
            for _,choice in ipairs({{"SHIFT","shift"},{"CTRL","ctrl"},{"ALT","alt"},{"Icon only","icon"}})do
                local value=choice[2]
                root:CreateRadio(choice[1],function()return data.config.bindings[data.scope]==value end,function()F:SetCombatBinding(data.key,data.scope,value)end)
            end
        end)
        row.keep=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate");row.keep:SetPoint("LEFT",980,0);F:FlexColumn(row.keep)
        row.keep:SetScript("OnClick",function()local source=row.data and row.data.group and row.data.group.source;if source then F:SetKeepInBag(source.key,row.keep:GetChecked())end end)
        row.keep:SetScript("OnEnter",function()GameTooltip:SetOwner(row.keep,"ANCHOR_RIGHT");GameTooltip:SetText("Maintain replacement stock outside combat. Shared with Buffs.");GameTooltip:Show()end)
        row.keep:SetScript("OnLeave",function()GameTooltip:Hide()end)
        row.enabled:SetScript("OnClick",function()if row.data and not InCombatLockdown()then F:SetCombatEnabled(row.data.key,row.data.scope,row.enabled:GetChecked())end end)
        local function arrow(x,direction,edge)
            local button=CreateFrame("Button",nil,row,"UIPanelButtonTemplate");button:SetPoint("LEFT",x,0);button:SetSize(18,24);button:SetText("");F:FlexColumn(button)
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
            button:SetScript("OnClick",function()
                if row.data then
                    if edge then F:MoveCombatToEdge(row.data.key,direction==1,row.data.scope)else F:MoveCombatRow(row.data.index,direction,row.data.scope)end
                end
            end)
            button:SetScript("OnEnter",function()GameTooltip:SetOwner(button,"ANCHOR_RIGHT");GameTooltip:SetText(edge and(direction==-1 and "Move to top"or "Move to bottom")or(direction==-1 and "Move up"or "Move down"));GameTooltip:Show()end)
            button:SetScript("OnLeave",function()GameTooltip:Hide()end)
            return button
        end
        row.top,row.up,row.down,row.bottom=arrow(1012,-1,true),arrow(1032,-1),arrow(1052,1),arrow(1072,1,true)
        row:SetScript("OnEnter",function()
            local data=row.data;if not data or not data.group then return end
            GameTooltip:SetOwner(row,"ANCHOR_RIGHT")
            if data.group.itemPlaceholder then GameTooltip:SetText('Pots / Items');GameTooltip:AddLine('Insert this frame\'s combat items here, in Pots / Items order. Configure targeting and Clean-up in each item\'s options.',.8,.8,.8,true);GameTooltip:Show();return end
            local id=F:CombatChosenRank(data.group,data.scope)or data.group.ranks[1].id
            if GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(id)else GameTooltip:SetText(data.group.name)end
            if data.group.pet then
                local families={};for family in pairs(data.group.petFamilies or {})do families[#families+1]=family end;table.sort(families)
                GameTooltip:AddLine(data.group.learned and (data.group.available and "Cast by your summoned pet."or "Learned ability: configure now; summon the required pet to cast.")or("Requires a pet with this ability"..(#families>0 and ": "..table.concat(families,", ")or ".")),1,.82,0,true)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave",function()GameTooltip:Hide()end)
        F:EnableRowReorder(row,content,rows,38,function()return row.data and row.data.key end,function(key,to)F:ReorderCombatRow(key,to,panel.combatScope)end,function()return not panel.combatDispelsOnly and row.data and row.data.group and row.data.group.learned and not row.data.modifier end,3)
        rows[index]=row
    end
    function panel:SelectCombatScope(scope)
        if InCombatLockdown()then return end
        local valid=false;for _,tab in ipairs(frameTabs)do if tab.scope==scope then valid=true end end
        if not valid then return end
        self.combatScrolls=self.combatScrolls or {}
        self.combatScrolls[self.combatScope]=content.scroll:GetVerticalScroll()
        self.combatFrameScope=scope
        self.combatProfile=self.combatProfiles[scope]or 'friendly'
        self.combatScope=(scope=='target'or scope=='focus')and(scope..(self.combatProfile=='friendly'and 'Friendly'or ''))or scope
        self:UpdateCombatRows();F:RefreshTableFooters()
        content.scroll:SetVerticalScroll(math.min(self.combatScrolls[scope]or 0,math.max(0,content:GetHeight()-content.scroll:GetHeight())))
    end
    function panel:SelectCombatProfile(profile)
        local scope=self.combatFrameScope
        if InCombatLockdown()or(scope~='target'and scope~='focus')or(profile~='friendly'and profile~='enemy')then return end
        self.combatProfiles[scope]=profile;self:SelectCombatScope(scope)
        if F.testMode=='combat'then F:RefreshTestUI()end
    end
    function panel:UpdateCombatRows()
        local enabled=F.db.combatClicks
        for _,region in ipairs(explanation)do region:SetShown(not enabled)end
        instruction:SetShown(enabled);chrome:SetShown(enabled);content.scroll:SetShown(enabled);footer:SetShown(enabled)
        for _,tab in ipairs(frameTabs)do
            local selected=tab.scope==self.combatFrameScope
            tab:SetShown(enabled);tab.selected:SetShown(selected);tab:SetEnabled(not selected)
            tab.label:SetTextColor(1,selected and .82 or 1,selected and 0 or 1)
        end
        for index,tab in ipairs(profileTabs)do
            tab:SetShown(enabled and(self.combatFrameScope=='target'or self.combatFrameScope=='focus'))
            tab:ClearAllPoints();tab:SetPoint('TOPLEFT',(self.combatFrameScope=='focus'and 580 or 435)+(index-1)*73,-88)
            tab.selected:SetShown(tab.profile==self.combatProfile);tab:SetEnabled(tab.profile~=self.combatProfile)
        end
        local data=F:CombatDisplayRows(self.combatScope,true)
        for index=#rows+1,#data do createRow(index)end
        local hasKeep=false
        for index,row in ipairs(rows)do
            local value=data[index];row.data=value;row:SetShown(value~=nil)
            if value then
                local group,config,frame=value.group,value.config,value.frame
                local editable=group and group.learned and not InCombatLockdown()
                row.number:SetText(value.position)
                row.label:SetText(group and(group.name..(group.pet and " (pet)"or ""))or(value.modifier:upper().." - assign an ability below"))
                row.icon:SetTexture(group and(group.itemPlaceholder and F.itemsIcon or C_Spell.GetSpellTexture(F:CombatChosenRank(group,value.scope)or group.ranks[1].id))or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.icon:SetDesaturated(not(group and group.learned))
                row:SetAlpha(group and(group.learned and(frame.enabled and 1 or .75)or .5)or .5)
                row:EnableMouse(group~=nil)
                row.enabled:SetShown(group~=nil and not group.itemPlaceholder);row.enabled:SetChecked(frame and frame.enabled);row.enabled:SetEnabled(editable==true)
                row.rank:SetShown(group~=nil and not group.itemPlaceholder);row.rank:SetEnabled(editable==true);row.modifier:SetShown(not(group and group.itemPlaceholder));row.modifier:SetEnabled(editable==true)
                local rankLabel="Highest learned"
                if group and frame.rankID then for _,rank in ipairs(group.ranks)do if rank.id==frame.rankID then rankLabel=rank.label end end end
                row.rank:SetDefaultText(rankLabel)
                local binding=group and config.bindings[value.scope]or value.modifier
                row.modifier:SetDefaultText(binding=="icon"and "Icon only"or binding:upper())
                if row.rank.GenerateMenu then row.rank:GenerateMenu();row.modifier:GenerateMenu()end
                local source=group and group.source
                local keep=source and not source.stockOnly and(source.stone or source.keepKey)and source or nil
                hasKeep=hasKeep or keep~=nil;row.keep:SetShown(keep~=nil);row.keep:SetEnabled(editable==true and keep~=nil);row.keep:SetChecked(keep and F:KeepsEntry(keep))
                local movable=group~=nil and index>3 and not self.combatDispelsOnly
                for _,button in ipairs({row.top,row.up,row.down,row.bottom})do button:SetShown(movable)end
                row.up:SetEnabled(editable==true and index>4);row.top:SetEnabled(editable==true and index>4)
                row.down:SetEnabled(editable==true and index<#data);row.bottom:SetEnabled(editable==true and index<#data)
                for _,button in ipairs({row.top,row.up})do button:SetAlpha(editable and index>4 and 1 or .4)end
                for _,button in ipairs({row.down,row.bottom})do button:SetAlpha(editable and index<#data and 1 or .4)end
            end
        end
        keepHeading:SetShown(hasKeep);F:SizeOptionsContent(content,math.max(38,(#data-3)*38))
    end
    panel.combatFrameTabs=frameTabs
    panel.combatProfileTabs=profileTabs
    panel.combatPinned=pinned
    panel.combatRows,panel.combatContent=rows,content
    panel.syncers[#panel.syncers+1]=function()panel:UpdateCombatRows()end
end
