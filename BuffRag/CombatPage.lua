local _,F=...
function F:CreateCombatPage(panel,page)
    self:AddPrimaryOptionsHeading(page,"Combat actions",0,0)
    local function responsiveText(value,x,y,width)
        local label=self:AddOptionsText(page,value,x,y,width)
        self:FlexName(label)
        return label
    end
    local explanation={responsiveText("Buffs prepares you outside combat; normal icons disappear when combat starts. Enable combat mode in Settings for fixed manual actions and Post-combat recovery. Each frame/profile has independent SHIFT / CTRL / ALT assignments. Pet abilities require the correct pet. Combat health never changes protected actions or positions.",0,-30,1070)}
    for index,example in ipairs({{"Interface\\Icons\\Spell_Holy_FlashHeal","Party SHIFT: heal"},{"Interface\\Icons\\Spell_Shadow_Possession","Target SHIFT: Fear"},{"Interface\\Icons\\Spell_Shadow_MindRot","Focus CTRL: pet interrupt"}})do
        local icon=page:CreateTexture(nil,"ARTWORK");icon:SetSize(24,24);icon:SetPoint("TOPLEFT",(index-1)*350,-103);icon:SetTexture(example[1])
        explanation[#explanation+1]=icon
        explanation[#explanation+1]=responsiveText(example[2],32+(index-1)*350,-107,310)
    end
    explanation[#explanation+1]=responsiveText("Each frame has independent SHIFT / CTRL / ALT assignments. Visible icons pack together. After combat, relevant healing, cleansing and resurrection actions remain until that friendly unit has recovered, then Buff mode returns. Native cooldown swipes and optional fading cast-result marks provide feedback.",0,-136,1070)
    local instruction=responsiveText("Select a frame and Friendly/Enemy profile where applicable. Rows 1–3 assign SHIFT / CTRL / ALT; displayed icons pack together. Post-combat retains relevant heals, dispels and resurrection spells.",0,-30,1070)
    local chrome=CreateFrame("Frame",nil,page);chrome:SetAllPoints(page)
    local tableChrome=CreateFrame("Frame",nil,chrome)
    tableChrome:SetPoint("TOPLEFT",0,0);tableChrome:SetPoint("BOTTOMRIGHT",0,0)
    local function header(label,x,width,y)
        local text=F:AddOptionsText(tableChrome,label,x,y or -106,width);text:SetJustifyH("CENTER");return text
    end
    local nameX=162
    header("Enabled",20,60);header("Out of\ncombat",72,50,-100)
    local spellHeading=header("Spell / Ability",nameX,335)
    local rankHeading=header("Level / Rank",0,140)
    local modifierHeading=header("Modifier",0,105)
    local keyHeading=header("Keybind",0,82)
    local frameTabs={}
    panel.combatScope=panel.combatScope or "self"
    panel.combatFrameScope=panel.combatFrameScope or 'self'
    panel.combatProfiles=panel.combatProfiles or {target='friendly',focus='friendly'}
    for index,choice in ipairs({{"Self Frame","self"},{"Party Frames","party"},{"Raid Frames","raid"},{"Target Frame","target"},{"Focus Frame","focus"}})do
        local scope=choice[2]
        local tab=F:CreateOptionsTab(chrome,choice[1],140,22);tab:SetPoint("TOPLEFT",(index-1)*145,-62)
        tab.scope=scope
        tab:SetScript("OnClick",function()panel:SelectCombatScope(scope)end)
        frameTabs[index]=tab
    end
    local profileTabs={}
    for index,choice in ipairs({{'Friendly','friendly'},{'Enemy','enemy'}})do
        local tab=F:CreateOptionsTab(chrome,choice[1],70,21)
        tab.profile=choice[2];tab:SetScript('OnClick',function()panel:SelectCombatProfile(choice[2])end)
        profileTabs[index]=tab
    end
    local dispels=CreateFrame('CheckButton',nil,chrome,'UICheckButtonTemplate');dispels:SetPoint('TOPLEFT',850,-61);dispels.text:SetText('Dispels only')
    dispels:SetScript('OnClick',function()panel.combatDispelsOnly=dispels:GetChecked();panel:UpdateCombatRows()end)
    F:AddOptionsDivider(tableChrome,0,-92,950)
    local keepHeading=header("Keep in bag",0,76)
    local pinned=CreateFrame('Frame',nil,tableChrome);pinned:SetPoint('TOPLEFT',0,-132);pinned:SetSize(1090,114);F:FlexRow(pinned)
    panel.combatPinnedRule=F:AddOptionsDivider(tableChrome,0,-248,950)
    panel.combatTableChrome=tableChrome
    local content=self:CreateTableBody(page,252,8)
    local rows={}
    local keyInput=CreateFrame("EditBox",nil,UIParent)
    keyInput:SetSize(1,1);keyInput:SetAlpha(0);keyInput:SetAutoFocus(false);keyInput:EnableMouse(false)
    keyInput:SetFontObject(GameFontHighlightSmall)
    keyInput:SetPropagateKeyboardInput(false)
    keyInput:Hide()
    local function syncKeybindLabel(row)
        local capture=panel.combatKeyCapture
        local frame=row.data and row.data.frame
        local key=frame and frame.keybind
        local capturing=capture~=nil and capture.row==row
        row.keybind.prompt:SetShown(capturing)
        row.keybind:SetText(capturing and "" or (key and (GetBindingText and GetBindingText(key) or key) or "Set key"))
    end
    function panel:CancelCombatKeyCapture()
        local capture=self.combatKeyCapture
        if not capture then return end
        self.combatKeyCapture=nil
        keyInput:ClearFocus();keyInput:Hide()
        if GameTooltip:GetOwner()==capture.row.keybind then GameTooltip:Hide() end
        syncKeybindLabel(capture.row)
    end
    keyInput:SetScript("OnEditFocusLost",function() panel:CancelCombatKeyCapture() end)
    keyInput:SetScript("OnEscapePressed",function() panel:CancelCombatKeyCapture() end)
    keyInput:SetScript("OnKeyDown",function(_,pressed)
        local capture=panel.combatKeyCapture
        if not capture then return end
        if pressed=="ESCAPE" or InCombatLockdown() then panel:CancelCombatKeyCapture();return end
        local key=GetConvertedKeyOrButton and GetConvertedKeyOrButton(pressed) or pressed
        if IsKeyPressIgnoredForBinding(key) then return end
        local chord=CreateKeyChordStringUsingMetaKeyState(key)
        if not chord or chord=="" then return end
        local applied,reason=F:SetCombatKeybind(capture.key,capture.scope,chord)
        if applied then panel:CancelCombatKeyCapture();return end
        GameTooltip:SetOwner(capture.row.keybind,"ANCHOR_RIGHT")
        GameTooltip:SetText(reason);GameTooltip:Show()
    end)
    panel.combatKeyInput=keyInput
    local function dropdown(row,width)
        local control=CreateFrame("DropdownButton",nil,row,"WowStyle1DropdownTemplate")
        control:SetSize(width,26);return control
    end
    local function showOutOfCombatTooltip(control,data,checkbox)
        local modifier=data and data.group and data.modifier
        local queue
        if modifier and modifier==F.db.priorityModifier then queue="bypass"
        elseif modifier and modifier==F.db.frameModifier then queue="standard" end
        if not checkbox and not queue then return end
        GameTooltip:SetOwner(control,"ANCHOR_RIGHT")
        GameTooltip:SetText("Enable in out of combat, Buff mode")
        if queue then
            GameTooltip:AddLine(modifier:upper().." runs your "..queue.." buff queue in Buff mode, so this ability's frame-click assignment is ignored.",1,1,1,true)
            if data.scope=="target" or data.scope=="targetFriendly" then
                GameTooltip:AddLine("To cast this ability with a keybind in Buff mode, choose Icon only and assign a keybind.",1,1,1,true)
            else
                GameTooltip:AddLine("Click the ability's icon to cast it in Buff mode.",1,1,1,true)
            end
        end
        GameTooltip:Show()
    end
    local function createRow(index)
        local row=CreateFrame("Frame",nil,index<=3 and pinned or content);row:SetPoint("TOPLEFT",0,-(index<=3 and index-1 or index-4)*38);row:SetSize(1090,36);F:FlexRow(row)
        local background=row:CreateTexture(nil,"BACKGROUND");background:SetAllPoints();background:SetColorTexture(1,.82,0,index%2==0 and .055 or 0)
        row.number=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");row.number:SetPoint("LEFT",6,0)
        row.enabled=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate");row.enabled:SetPoint("LEFT",30,0)
        row.outOfCombat=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate");row.outOfCombat:SetPoint("LEFT",81,0)
        row.outOfCombat:SetScript("OnClick",function()
            if row.data then F:SetCombatOutOfCombat(row.data.key,row.data.scope,row.outOfCombat:GetChecked()) end
        end)
        row.outOfCombat:SetScript("OnEnter",function()
            showOutOfCombatTooltip(row.outOfCombat,row.data,true)
        end)
        row.outOfCombat:SetScript("OnLeave",function()GameTooltip:Hide()end)
        row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetPoint("LEFT",130,0);row.icon:SetSize(26,26)
        row.label=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");row.label:SetPoint("LEFT",nameX,0);row.label:SetJustifyH("LEFT")
        row.rank=dropdown(row,rankHeading:GetWidth())
        row.configured=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        row.configured:SetText("Configured in Bag Items tab")
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
                create(root,'Dispel reminders (symbols and Post-combat)',function()return data.frame.dispelReminders~=false end,function()data.frame.dispelReminders=data.frame.dispelReminders==false;F:Refresh()end)
            end
        end)
        row.modifier=dropdown(row,modifierHeading:GetWidth())
        row.modifier:HookScript("OnEnter",function(button) showOutOfCombatTooltip(button,row.data,false) end)
        row.modifier:HookScript("OnLeave",function(button)
            if GameTooltip:GetOwner()==button then GameTooltip:Hide() end
        end)
        row.modifier:SetupMenu(function(_,root)
            local data=row.data;if not data or not data.group then return end
            for _,choice in ipairs({{"SHIFT","shift"},{"CTRL","ctrl"},{"ALT","alt"},{"Icon only","icon"}})do
                local value=choice[2]
                root:CreateRadio(choice[1],function()return data.config.bindings[data.scope]==value end,function()F:SetCombatBinding(data.key,data.scope,value)end)
            end
        end)
        row.keybind=CreateFrame("Button",nil,row,"UIPanelButtonTemplate")
        row.keybind:SetSize(keyHeading:GetWidth(),23)
        row.keybind:RegisterForClicks("LeftButtonUp","RightButtonUp")
        row.keybind.prompt=row.keybind:CreateFontString(nil,"OVERLAY","GameFontNormal")
        row.keybind.prompt:SetPoint("LEFT",8,0);row.keybind.prompt:SetText("_");row.keybind.prompt:Hide()
        row.keybind:SetScript("OnClick",function(button,mouse)
            local data=row.data
            if not data or not F:ValidateCombatKeybind(data.key,data.scope) then return end
            panel:CancelCombatKeyCapture()
            GameTooltip:Hide()
            if mouse=="RightButton" then
                F:SetCombatKeybind(data.key,data.scope,nil)
            else
                if panel.CancelBindingCapture then panel:CancelBindingCapture() end
                panel.combatKeyCapture={row=row,key=data.key,scope=data.scope}
                keyInput:ClearAllPoints();keyInput:SetPoint("CENTER",button,"CENTER")
                keyInput:SetText("");keyInput:Show();keyInput:SetFocus()
            end
            syncKeybindLabel(row)
        end)
        row.keybind:SetScript("OnEnter",function(button)
            local frame=row.data and row.data.frame
            GameTooltip:SetOwner(button,"ANCHOR_RIGHT")
            GameTooltip:SetText(frame and frame.keybind and "Right click to clear keybinding" or "Click to set key binding")
            GameTooltip:Show()
        end)
        row.keybind:SetScript("OnLeave",function() GameTooltip:Hide() end)
        row.keybind:SetScript("OnHide",function()
            if panel.combatKeyCapture and panel.combatKeyCapture.row==row then panel:CancelCombatKeyCapture() end
        end)
        row.keep=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate")
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
            if data.group.itemPlaceholder then GameTooltip:SetText('Bag Items');GameTooltip:AddLine('Insert this frame\'s combat items here, in Bag Items order. Configure targeting and Post-combat in each item\'s options.',.8,.8,.8,true);GameTooltip:Show();return end
            local id=F:CombatChosenRank(data.group,data.scope)or data.group.ranks[1].id
            if GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(id)else GameTooltip:SetText(data.group.name)end
            if data.group.pet then
                local families={};for family in pairs(data.group.petFamilies or {})do families[#families+1]=family end;table.sort(families)
                GameTooltip:AddLine(data.group.learned and (data.group.available and "Cast by your summoned pet."or "Learned ability: configure now; summon the required pet to cast.")or("Requires a pet with this ability"..(#families>0 and ": "..table.concat(families,", ")or ".")),1,.82,0,true)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave",function()GameTooltip:Hide()end)
        F:EnableRowReorder(row,content,rows,38,function()return row.data and row.data.key end,function(key,to)F:ReorderCombatRow(key,to,panel.combatScope)end,function()return not panel.combatDispelsOnly and row.data and row.data.group and row.data.group.learned and row.data.frame.enabled and not row.data.modifier end,3)
        rows[index]=row
    end
    local hasKeyColumn,hasKeepColumn=false,false
    local layoutWidth,layoutRows,layoutKey,layoutKeep
    function panel:LayoutCombatColumns()
        local width=self:GetWidth()
        if layoutWidth==width and layoutRows==#rows and layoutKey==hasKeyColumn and layoutKeep==hasKeepColumn then return end
        layoutWidth,layoutRows,layoutKey,layoutKeep=width,#rows,hasKeyColumn,hasKeepColumn
        local edge=width-154
        local function place(heading,visible)
            local x=edge-heading:GetWidth()
            heading:SetPoint("TOPLEFT",x,-106)
            if visible then edge=x-8 end
            return x
        end
        local keepX=place(keepHeading,hasKeepColumn)
        local keyX=place(keyHeading,hasKeyColumn)
        local modifierX=place(modifierHeading,true)
        local rankX=place(rankHeading,true)
        local nameWidth=rankX-nameX-12
        spellHeading:SetWidth(nameWidth)
        for _,row in ipairs(rows) do
            row.label:SetWidth(nameWidth)
            row.rank:SetPoint("LEFT",row,"LEFT",rankX,0)
            row.modifier:SetPoint("LEFT",row,"LEFT",modifierX,0)
            row.keybind:SetPoint("LEFT",row,"LEFT",keyX,0)
            row.keep:SetPoint("LEFT",row,"LEFT",keepX+(keepHeading:GetWidth()-row.keep:GetWidth())/2,0)
        end
    end
    function panel:SelectCombatScope(scope)
        if InCombatLockdown()then return end
        local valid=false;for _,tab in ipairs(frameTabs)do if tab.scope==scope then valid=true end end
        if not valid then return end
        self:CancelCombatKeyCapture()
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
        local profiles=self.combatFrameScope=='target'or self.combatFrameScope=='focus'
        local showKeys=self.combatFrameScope=='target'
        keyHeading:SetShown(showKeys)
        local extra=profiles and 26 or 0
        tableChrome:SetPoint('TOPLEFT',chrome,'TOPLEFT',0,-extra)
        content.scroll:SetPoint('TOPLEFT',page,'TOPLEFT',0,-252-extra)
        for _,region in ipairs(explanation)do region:SetShown(not enabled)end
        instruction:SetShown(enabled);chrome:SetShown(enabled);content.scroll:SetShown(enabled)
        for _,tab in ipairs(frameTabs)do
            local selected=tab.scope==self.combatFrameScope
            tab:SetShown(enabled);F:SelectOptionsTab(tab,selected)
        end
        for index,tab in ipairs(profileTabs)do
            tab:SetShown(enabled and profiles)
            tab:ClearAllPoints();tab:SetPoint('TOPLEFT',(self.combatFrameScope=='focus'and 580 or 435)+(index-1)*73,-88)
            F:SelectOptionsTab(tab,tab.profile==self.combatProfile)
        end
        local data=F:CombatDisplayRows(self.combatScope,true)
        for index=#rows+1,#data do createRow(index)end
        local hasKeep=false
        for index,row in ipairs(rows)do
            local value=data[index];row.data=value;row:SetShown(value~=nil)
            local capture=self.combatKeyCapture
            if capture and capture.row==row and (not value or capture.key~=value.key or capture.scope~=value.scope
                or not F:ValidateCombatKeybind(value.key,value.scope)) then self:CancelCombatKeyCapture() end
            if value then
                local group,config,frame=value.group,value.config,value.frame
                local canEnable=group and group.learned and not InCombatLockdown()
                local editable=canEnable and frame.enabled
                row.configured:SetShown(group~=nil and group.itemPlaceholder==true)
                row.number:SetText(value.position)
                row.label:SetText(group and(group.name..(group.pet and " (pet)"or ""))or(value.modifier:upper().." - assign an ability below"))
                if group and group.itemPlaceholder then F:CenterItemPlaceholder(row,nameX,row.top) end
                row.icon:SetTexture(group and(group.itemPlaceholder and F.itemsIcon or C_Spell.GetSpellTexture(F:CombatChosenRank(group,value.scope)or group.ranks[1].id))or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.icon:SetDesaturated(not(group and group.learned))
                row:SetAlpha(group and group.learned and frame.enabled and 1 or .5)
                row:EnableMouse(group~=nil)
                row.enabled:SetShown(group~=nil and not group.itemPlaceholder);row.enabled:SetChecked(frame and frame.enabled);row.enabled:SetEnabled(canEnable==true)
                row.outOfCombat:SetShown(group~=nil and not group.itemPlaceholder)
                row.outOfCombat:SetChecked(frame and frame.outOfCombat==true);row.outOfCombat:SetEnabled(editable==true)
                row.rank:SetShown(group~=nil and not group.itemPlaceholder);row.rank:SetEnabled(editable==true);row.modifier:SetShown(not(group and group.itemPlaceholder));row.modifier:SetEnabled(editable==true)
                local rankLabel="Highest learned"
                if group and frame.rankID then for _,rank in ipairs(group.ranks)do if rank.id==frame.rankID then rankLabel=rank.label end end end
                row.rank:SetDefaultText(rankLabel)
                local binding=group and config.bindings[value.scope]or value.modifier
                row.modifier:SetDefaultText(binding=="icon"and "Icon only"or binding:upper())
                local canBind=showKeys and editable and F:CanBindCombatRow(group,value.scope)
                row.keybind:SetShown(showKeys and group~=nil and not group.itemPlaceholder)
                row.keybind:SetEnabled(canBind==true);row.keybind:SetAlpha(canBind and 1 or .35)
                syncKeybindLabel(row)
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
        hasKeyColumn,hasKeepColumn=showKeys,hasKeep
        self:LayoutCombatColumns()
    end
    panel.combatFrameTabs=frameTabs
    panel.combatProfileTabs=profileTabs
    panel.combatPinned=pinned
    panel.combatRows,panel.combatContent=rows,content
    panel.syncers[#panel.syncers+1]=function()panel:UpdateCombatRows()end
end
