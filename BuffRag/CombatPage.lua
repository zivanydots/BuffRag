local _,F=...
function F:CreateCombatPage(panel,page)
    self:AddPrimaryOptionsHeading(page,"Combat actions",0,0)
    local summary=self:AddOptionsText(page,"Assign spells and items to frame clicks, icons, or keybinds for each frame.",0,-30,950)
    self:FlexName(summary)
    local overview=self:CreateTableBody(page,30,8,true)
    local overviewScroll=overview.scroll
    overviewScroll.scrollBarHideable=true
    overview:SetHeight(542)
    local intro=self:AddOptionsText(overview,"Combat Mode lets you configure combat abilities and show their icons next to unit frames during combat. Buff Mode uses queues to apply missing buffs. In Combat Mode, the icons stay in place so you can choose when to cast.",0,0,1090)
    local getStarted=self:AddOptionsText(overview,"Use Enable Combat Mode below to start configuring your combat actions.",0,-31,1090)
    local examples={
        {title="Frame clicks", icons={{"Spell_Holy_FlashHeal","SHIFT"},{"Spell_Holy_DispelMagic","CTRL"}},
            description="Assign Shift, Ctrl or Alt to cast on the frame you click. For example, Shift-click a party member to heal them."},
        {title="Icons, keybinds and bag items", icons={{"INV_Misc_Bandage_08","BANDAGE"},{135826,"IRON GRENADE"}},
            description="Cast spells by icon or use Target and Focus keybinds. Drag a bandage for healing or an Iron Grenade for PvP into Bag Items. Tick Combat and choose frames. Move the Bag Items row in Combat Mode to place their icons."},
        {title="Openers and recovery", icons={{"Spell_Nature_Polymorph","OUT OF COMBAT"},{"Spell_Holy_Resurrection","POST-COMBAT"}},
            description="Check Out of combat for openers like Polymorph or Fear. Post-combat shows eligible dispels and enabled resurrection spells on dead allies."},
    }
    local cards={}
    for index,example in ipairs(examples) do
        local card=CreateFrame("Frame",nil,overview)
        card:SetSize(290,135)
        local background=card:CreateTexture(nil,"BACKGROUND")
        background:SetAllPoints();background:SetColorTexture(.22,.21,.18,.55)
        for slot,icon in ipairs(example.icons) do
            local anchor=slot==1 and "TOPLEFT" or "TOP"
            local texture=card:CreateTexture(nil,"ARTWORK")
            texture:SetPoint("TOPLEFT",card,anchor,10,-11);texture:SetSize(30,30)
            texture:SetTexture(type(icon[1])=="number" and icon[1] or "Interface\\Icons\\"..icon[1])
            local label=self:AddOptionsText(card,icon[2],0,0,96)
            label:ClearAllPoints();label:SetPoint("LEFT",texture,"RIGHT",8,0)
        end
        self:AddOptionsHeadingText(card,example.title,10,-49)
        card.description=self:AddOptionsText(card,example.description,10,-67,268)
        cards[index]=card
    end
    local _,dispelRule=self:AddOptionsHeading(overview,"Dispel overlays",0,-210,620)
    local dispelHelp=self:AddOptionsText(overview,"Dispels configured in Combat Mode show an overlay when they can remove a matching effect. The symbol identifies the effect you can remove.",0,-237,620)
    local hunter=CreateFrame("Frame",nil,overview)
    hunter:SetPoint("TOPLEFT",0,-352);hunter:SetSize(550,39)
    self:AddOptionsHeadingText(hunter,"Enrage (Hunter only)",42,0)
    local hunterHelp=self:AddOptionsText(hunter,"Tranquilizing Shot shows the Enrage overlay when an enemy is enraged.",42,-18,490)
    self:CreateDispelExamples(overview,264,hunter)
    local previews=CreateFrame("Frame",nil,overview)
    previews:SetPoint("TOPRIGHT",0,-210);previews:SetSize(410,137)
    local _,previewRule=self:AddOptionsHeading(previews,"Customisable combat icons",0,0,410)
    local previewHelp=self:AddOptionsText(previews,"Use Configure Frame Icons to adjust size, position and growth. In the Buff Mode preview, orange Out of combat icons appear before blue buffs. In the Combat Mode preview, combat icons are orange.",0,-27,392)
    for index,label in ipairs({"Buff Mode","Combat Mode"}) do
        local anchor=index==1 and "TOPLEFT" or "TOP"
        local icons=index==1 and {"Spell_Nature_Polymorph","Spell_Holy_WordFortitude"} or {"Spell_Shadow_Possession"}
        local lastIcon
        for slot,artwork in ipairs(icons) do
            local icon=previews:CreateTexture(nil,"ARTWORK")
            icon:SetSize(32,32);icon:SetPoint("TOPLEFT",previews,anchor,(slot-1)*36,-86)
            icon:SetTexture("Interface\\Icons\\"..artwork)
            local tint=previews:CreateTexture(nil,"OVERLAY")
            tint:SetAllPoints(icon);self:TintPreviewIcon(tint,slot==1)
            lastIcon=icon
        end
        local caption=self:AddOptionsText(previews,label,0,0,108)
        caption:ClearAllPoints();caption:SetPoint("LEFT",lastIcon,"RIGHT",8,0)
    end
    local _,drRule=self:AddOptionsHeading(overview,"PvP diminishing returns (DR)",0,-403,1090)
    local drExample=overview:CreateTexture(nil,"ARTWORK")
    drExample:SetSize(34,34);drExample:SetPoint("TOPLEFT",0,-430)
    local drSpell=self:DREstimateSpell()
    drExample:SetTexture(drSpell and drSpell.icon or "Interface\\Icons\\Spell_Shadow_Possession")
    local estimate=overview:CreateFontString(nil,"OVERLAY","NumberFontNormalSmall")
    estimate:SetPoint("TOPLEFT",drExample,"TOPLEFT",1,-1);estimate:SetText("~")
    local countdown=overview:CreateFontString(nil,"OVERLAY","GameFontNormal")
    countdown:SetPoint("CENTER",drExample,"CENTER");countdown:SetText("12")
    local drHelp={
        self:AddOptionsText(overview,"Crowd control in the same DR group can shorten later effects on the same player. Sap shares DR with Polymorph, and Fear shares DR with Psychic Scream.",46,-430,1044),
        self:AddOptionsText(overview,"Timers count down to the DR reset. A ~ marks an estimate. Supported abilities can estimate from your casts or from readable effects applied by you or your pet.",46,-451,1044),
        self:AddOptionsText(overview,"Enable tracking in Global Settings → DR, even with Combat Mode off. In Configure Frame Icons → DR, choose Target and Focus frames, enemy nameplates, or both.",46,-472,1044),
    }
    local enable=CreateFrame("Button",nil,overview,"UIPanelButtonTemplate")
    enable:SetSize(182,24);enable:SetPoint("BOTTOM",0,6);enable:SetText("Enable Combat Mode")
    enable:SetScript("OnClick",function() F:SetCombatModeEnabled(true) end)
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
    local copyProfile=CreateFrame("DropdownButton",nil,chrome,"WowStyle1DropdownTemplate")
    copyProfile:SetDefaultText("Copy from...")
    copyProfile.Text:SetJustifyH("LEFT")
    local labelWidth=math.ceil(copyProfile.Text:GetUnboundedStringWidth())
    copyProfile:SetSize(labelWidth+copyProfile.Arrow:GetWidth()+14,24)
    local friendlySources={{"Self Frame","self"},{"Party Frames","party"},{"Raid Frames","raid"},{"Target Frame (Friendly)","targetFriendly"},{"Focus Frame (Friendly)","focusFriendly"}}
    local enemySources={{"Target Frame (Enemy)","target"},{"Focus Frame (Enemy)","focus"}}
    copyProfile:SetupMenu(function(_,root)
        local destination=panel.combatScope
        local sources=(destination=="target" or destination=="focus") and enemySources or friendlySources
        root:CreateTitle("Copy settings from:")
        for _,choice in ipairs(sources) do
            local source=choice[2]
            if source~=destination then
                root:CreateButton(choice[1],function()
                    panel:CancelCombatKeyCapture()
                    F:CopyCombatProfile(source,destination)
                end)
            end
        end
    end)
    panel.combatCopyProfile=copyProfile
    local dispels=CreateFrame('CheckButton',nil,chrome,'UICheckButtonTemplate')
    dispels:SetPoint("RIGHT",copyProfile,"LEFT",-80,0)
    dispels.text:SetText('Dispels only')
    dispels:SetScript('OnClick',function()panel.combatDispelsOnly=dispels:GetChecked();panel:UpdateCombatRows()end)
    local learned=CreateFrame('CheckButton',nil,chrome,'UICheckButtonTemplate')
    learned:SetPoint("RIGHT",dispels,"LEFT",-88,0)
    learned.text:SetText('Learned only')
    learned:SetChecked(panel.combatLearnedOnly~=false)
    learned:SetScript('OnClick',function()
        panel.combatLearnedOnly=not not learned:GetChecked()
        panel:UpdateCombatRows()
    end)
    panel.combatLearnedFilter=learned
    local frameRule=F:AddOptionsDivider(tableChrome,0,-92,1090)
    local keepHeading=header("Keep in bag",0,76)
    local pinned=CreateFrame('Frame',nil,tableChrome);pinned:SetPoint('TOPLEFT',0,-132);pinned:SetSize(1090,114)
    local pinnedRule=F:AddOptionsDivider(tableChrome,0,-248,1090)
    panel.combatPinnedRule=pinnedRule
    panel.combatTableChrome=tableChrome
    local content=self:CreateTableBody(page,252,8,true)
    local scroll=content.scroll
    scroll.scrollBarHideable=true
    panel.combatSearch=self:CreateListSearch(chrome,function()
        panel:UpdateCombatRows()
        scroll:SetVerticalScroll(0)
    end)
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
        if capture.overrideChord==chord and not capture.overrideReleased then return end
        local confirmed=capture.overrideChord==chord and capture.overrideAction or nil
        local applied,reason,action=F:SetCombatKeybind(capture.key,capture.scope,chord,confirmed)
        if applied then panel:CancelCombatKeyCapture();return end
        capture.overrideChord,capture.overrideAction=action and chord or nil,action
        capture.overrideKey,capture.overrideReleased=action and key or nil,false
        F:Print(reason)
        GameTooltip:SetOwner(capture.row.keybind,"ANCHOR_RIGHT")
        GameTooltip:SetText(reason,1,1,1,true);GameTooltip:Show()
    end)
    keyInput:SetScript("OnKeyUp",function(_,pressed)
        local capture=panel.combatKeyCapture
        local key=GetConvertedKeyOrButton and GetConvertedKeyOrButton(pressed) or pressed
        if capture and capture.overrideKey==key then capture.overrideReleased=true end
    end)
    panel.combatKeyInput=keyInput
    local function dropdown(row,width)
        local control=CreateFrame("DropdownButton",nil,row,"WowStyle1DropdownTemplate")
        control:SetSize(width,26);return control
    end
    local function showOutOfCombatTooltip(control,data,checkbox)
        local group=data and data.group
        if not F:CombatSupportsOutOfCombat(group) then
            if checkbox and group and group.buff then
                GameTooltip:SetOwner(control,"ANCHOR_RIGHT")
                GameTooltip:SetText("Configure this ability's out-of-combat icon in Buff Mode.")
                GameTooltip:Show()
            end
            return
        end
        local modifier=data and data.group and data.modifier
        local queue
        if modifier and modifier==F:BypassModifier() then queue="bypass"
        elseif modifier and modifier==F.db.frameModifier then queue="standard" end
        if not checkbox and not queue then return end
        GameTooltip:SetOwner(control,"ANCHOR_RIGHT")
        GameTooltip:SetText("Enable in Buff mode, out of combat.")
        if queue then
            GameTooltip:AddLine(modifier:upper().." runs your "..queue.." buff queue in Buff mode, so this ability's frame-click assignment is ignored.",1,1,1,true)
            if F:CombatKeyUnit(data.scope) then
                GameTooltip:AddLine("To cast this ability with a keybind in Buff mode, choose Icon only and assign a keybind.",1,1,1,true)
            else
                GameTooltip:AddLine("Click the ability's icon to cast it in Buff mode.",1,1,1,true)
            end
        end
        GameTooltip:Show()
    end
    local function createRow(index)
        local row=CreateFrame("Frame",nil,index<=3 and pinned or content);row:SetPoint("TOPLEFT",0,-(index<=3 and index-1 or index-4)*38);row:SetSize(1090,36)
        local background=row:CreateTexture(nil,"BACKGROUND");background:SetAllPoints();background:SetColorTexture(1,.82,0,index%2==0 and .055 or 0)
        row.number=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");row.number:SetPoint("LEFT",6,0)
        row.enabled=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate");row.enabled:SetPoint("LEFT",30,0)
        row.outOfCombat=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate");row.outOfCombat:SetPoint("LEFT",81,0)
        if row.outOfCombat.SetMotionScriptsWhileDisabled then row.outOfCombat:SetMotionScriptsWhileDisabled(true) end
        row.outOfCombat:SetScript("OnClick",function()
            if row.data then F:SetCombatOutOfCombat(row.data.key,row.data.scope,row.outOfCombat:GetChecked()) end
        end)
        row.outOfCombat:SetScript("OnEnter",function()
            showOutOfCombatTooltip(row.outOfCombat,row.data,true)
        end)
        row.outOfCombat:SetScript("OnLeave",function()GameTooltip:Hide()end)
        local deadOnly=CreateFrame("Frame",nil,row)
        deadOnly:SetPoint("CENTER",row.outOfCombat,"CENTER")
        deadOnly:SetSize(50,24)
        deadOnly:EnableMouse(true)
        local status=deadOnly:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        status:SetPoint("CENTER")
        status:SetText("Dead only")
        deadOnly:SetScript("OnEnter",function()
            local data=row.data
            local id=F:CombatChosenRank(data.group,data.scope) or data.group.ranks[1].id
            GameTooltip:SetOwner(deadOnly,"ANCHOR_RIGHT")
            GameTooltip:SetText("Resurrection")
            local timing=F:IsBattleResurrection(id) and "in and out of combat" or "out of combat"
            GameTooltip:AddLine("Enable this row to show the spell "..timing.." when the unit on this frame is dead.",1,1,1,true)
            GameTooltip:Show()
        end)
        deadOnly:SetScript("OnLeave",function()GameTooltip:Hide()end)
        row.deadOnly=deadOnly
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
        local function arrow(direction,edge)
            return F:CreateReorderArrow(row,nil,direction,function()
                if row.data then
                    if edge then F:MoveCombatToEdge(row.data.key,direction==1,row.data.scope)else F:MoveCombatRow(row.data.index,direction,row.data.scope)end
                end
            end,edge)
        end
        row.top,row.up,row.down,row.bottom=arrow(-1,true),arrow(-1),arrow(1),arrow(1,true)
        F:SetRowDetailTooltip(row,function(area)
            local data=row.data;if not data or not data.group then return end
            GameTooltip:SetOwner(area,"ANCHOR_RIGHT")
            if data.group.itemPlaceholder then GameTooltip:SetText('Bag Items');GameTooltip:AddLine('Insert this frame\'s combat items here, in Bag Items order. Configure targeting and Post-combat in each item\'s options.',.8,.8,.8,true);GameTooltip:Show();return end
            local id=F:CombatChosenRank(data.group,data.scope)or data.group.ranks[1].id
            if GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(id)else GameTooltip:SetText(data.group.name)end
            if data.group.pet then
                local families={};for family in pairs(data.group.petFamilies or {})do families[#families+1]=family end;table.sort(families)
                GameTooltip:AddLine(data.group.learned and (data.group.available and "Cast by your summoned pet."or "Learned ability: configure now; summon the required pet to cast.")or("Requires a pet with this ability"..(#families>0 and ": "..table.concat(families,", ")or ".")),1,.82,0,true)
            end
            GameTooltip:Show()
        end)
        F:EnableRowReorder(row,content,rows,38,function()return row.data and row.data.key end,function(key,to)F:ReorderCombatRow(key,to,panel.combatScope)end,function()return not panel.combatDispelsOnly and (panel.combatSearch.query or "")=="" and row.data and row.data.group and row.data.group.learned and row.data.frame.enabled and not row.data.modifier end,3)
        rows[index]=row
    end
    local hasKeyColumn,hasKeepColumn,arrowCount=false,false,0
    local layoutWidth,layoutRows,layoutKey,layoutKeep,layoutArrowCount,layoutScroll,layoutOverviewScroll
    function panel:LayoutCombatColumns()
        local width=self:GetWidth()
        local needsScroll=content:GetHeight()-scroll:GetHeight()>=1
        local overviewNeedsScroll=overview:GetHeight()-overviewScroll:GetHeight()>=1
        if layoutWidth==width and layoutRows==#rows and layoutKey==hasKeyColumn and layoutKeep==hasKeepColumn
            and layoutArrowCount==arrowCount and layoutScroll==needsScroll and layoutOverviewScroll==overviewNeedsScroll then return end
        layoutWidth,layoutRows,layoutKey,layoutKeep,layoutArrowCount,layoutScroll,layoutOverviewScroll=width,#rows,hasKeyColumn,hasKeepColumn,arrowCount,needsScroll,overviewNeedsScroll
        local gutter=needsScroll and 28 or 0
        scroll:SetPoint("BOTTOMRIGHT",page,"BOTTOMRIGHT",-gutter,8)
        scroll.ScrollBar:SetShown(needsScroll)
        local rowRight=width-42-gutter
        local overviewGutter=overviewNeedsScroll and 28 or 0
        overviewScroll:SetPoint("BOTTOMRIGHT",page,"BOTTOMRIGHT",-overviewGutter,8)
        overviewScroll.ScrollBar:SetShown(overviewNeedsScroll)
        local overviewWidth=width-42-overviewGutter
        overview:SetWidth(overviewWidth)
        intro:SetWidth(overviewWidth);getStarted:SetWidth(overviewWidth)
        drRule:SetWidth(overviewWidth)
        for _,label in ipairs(drHelp) do label:SetWidth(overviewWidth-58) end
        local cardWidth=(overviewWidth-28)/#cards
        for index,card in ipairs(cards) do
            card:SetPoint("TOPLEFT",(index-1)*(cardWidth+14),-58)
            card:SetWidth(cardWidth);card.description:SetWidth(cardWidth-20)
        end
        local dispelWidth=math.floor(overviewWidth*.58)
        dispelRule:SetWidth(dispelWidth);dispelHelp:SetWidth(dispelWidth)
        hunter:SetWidth(dispelWidth);hunterHelp:SetWidth(dispelWidth-48)
        local previewWidth=overviewWidth-dispelWidth-24
        previews:SetWidth(previewWidth);previewRule:SetWidth(previewWidth);previewHelp:SetWidth(previewWidth)
        content:SetWidth(rowRight)
        pinned:SetWidth(rowRight)
        copyProfile:SetPoint("TOPRIGHT",chrome,"TOPLEFT",rowRight,-61)
        local filterWidth=learned:GetWidth()+dispels:GetWidth()+88+80
        local tabWidth=math.min(140,math.floor((rowRight-copyProfile:GetWidth()-filterWidth-32)/#frameTabs))
        for index,tab in ipairs(frameTabs) do
            tab:SetWidth(tabWidth)
            tab:SetPoint("TOPLEFT",(index-1)*(tabWidth+5),-62)
        end
        frameRule:SetWidth(rowRight)
        pinnedRule:SetWidth(rowRight)
        local firstArrowX=rowRight-arrowCount*20+2
        local upX=rowRight-(arrowCount==4 and 58 or 38)
        local edge=arrowCount==0 and rowRight or firstArrowX-6
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
            row:SetWidth(rowRight)
            row.label:SetWidth(nameWidth)
            F:ResizeRowNameTooltip(row.label)
            row.rank:SetPoint("LEFT",row,"LEFT",rankX,0)
            row.modifier:SetPoint("LEFT",row,"LEFT",modifierX,0)
            row.keybind:SetPoint("LEFT",row,"LEFT",keyX,0)
            row.keep:SetPoint("LEFT",row,"LEFT",keepX+(keepHeading:GetWidth()-row.keep:GetWidth())/2,0)
            row.top:SetPoint("LEFT",row,"LEFT",rowRight-78,0)
            row.up:SetPoint("LEFT",row,"LEFT",upX,0)
            row.down:SetPoint("LEFT",row,"LEFT",upX+20,0)
            row.bottom:SetPoint("LEFT",row,"LEFT",rowRight-18,0)
        end
    end
    scroll:HookScript("OnSizeChanged",function() panel:LayoutCombatColumns() end)
    overviewScroll:HookScript("OnSizeChanged",function() panel:LayoutCombatColumns() end)
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
        self:UpdateCombatRows()
        content.scroll:SetVerticalScroll(math.min(self.combatScrolls[scope]or 0,math.max(0,content:GetHeight()-content.scroll:GetHeight())))
    end
    function panel:SelectCombatProfile(profile)
        local scope=self.combatFrameScope
        if InCombatLockdown()or(scope~='target'and scope~='focus')or(profile~='friendly'and profile~='enemy')then return end
        self.combatProfiles[scope]=profile;self:SelectCombatScope(scope)
        if F.testUI then F:RefreshTestUI() end
    end
    function panel:UpdateCombatRows()
        local enabled=F.db.combatClicks
        summary:SetShown(enabled)
        overview:SetShown(not enabled)
        overviewScroll:SetShown(not enabled)
        local profiles=self.combatFrameScope=='target'or self.combatFrameScope=='focus'
        local showKeys=F:CombatKeyUnit(self.combatScope)~=nil
        keyHeading:SetShown(showKeys)
        local extra=profiles and 26 or 0
        tableChrome:SetPoint('TOPLEFT',chrome,'TOPLEFT',0,-extra)
        content.scroll:SetPoint('TOPLEFT',page,'TOPLEFT',0,-252-extra)
        chrome:SetShown(enabled);content.scroll:SetShown(enabled)
        for _,tab in ipairs(frameTabs)do
            local selected=tab.scope==self.combatFrameScope
            tab:SetShown(enabled);F:SelectOptionsTab(tab,selected)
        end
        for index,tab in ipairs(profileTabs)do
            tab:SetShown(enabled and profiles)
            local parentTab=self.combatFrameScope=='focus' and frameTabs[5] or frameTabs[4]
            tab:ClearAllPoints();tab:SetPoint('TOPLEFT',parentTab,'BOTTOMLEFT',(index-1)*73,-4)
            F:SelectOptionsTab(tab,tab.profile==self.combatProfile)
        end
        local data=F:CombatDisplayRows(self.combatScope,true)
        local canReorder=not self.combatDispelsOnly and (self.combatSearch.query or "")=="" and #data>3
        local showEdgeArrows=canReorder and #data>10
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
                F:ResizeRowNameTooltip(row.label)
                if group and group.itemPlaceholder then F:CenterItemPlaceholder(row,nameX,showEdgeArrows and row.top or row.up) end
                row.icon:SetTexture(group and(group.itemPlaceholder and F.itemsIcon or C_Spell.GetSpellTexture(F:CombatChosenRank(group,value.scope)or group.ranks[1].id))or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.icon:SetDesaturated(not(group and group.learned))
                row:SetAlpha(group and group.learned and frame.enabled and 1 or .5)
                row:EnableMouse(group~=nil)
                row.enabled:SetShown(group~=nil and not group.itemPlaceholder);row.enabled:SetChecked(frame and frame.enabled);row.enabled:SetEnabled(canEnable==true)
                row.deadOnly:SetShown(group~=nil and group.deadTarget==true)
                local supportsOutOfCombat=F:CombatSupportsOutOfCombat(group)
                row.outOfCombat:SetShown(group~=nil and not group.itemPlaceholder and not group.deadTarget)
                row.outOfCombat:SetChecked(supportsOutOfCombat and frame.outOfCombat==true)
                row.outOfCombat:SetEnabled(editable==true and supportsOutOfCombat)
                row.outOfCombat:SetAlpha(supportsOutOfCombat and 1 or .45)
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
                local movable=group~=nil and index>3 and canReorder
                row.up:SetShown(movable);row.down:SetShown(movable)
                row.top:SetShown(movable and showEdgeArrows);row.bottom:SetShown(movable and showEdgeArrows)
                row.up:SetEnabled(editable==true and index>4);row.top:SetEnabled(editable==true and index>4)
                row.down:SetEnabled(editable==true and index<#data);row.bottom:SetEnabled(editable==true and index<#data)
                for _,button in ipairs({row.top,row.up})do button:SetAlpha(editable and index>4 and 1 or .4)end
                for _,button in ipairs({row.down,row.bottom})do button:SetAlpha(editable and index<#data and 1 or .4)end
            end
        end
        keepHeading:SetShown(hasKeep);F:SizeOptionsContent(content,math.max(38,(#data-3)*38))
        hasKeyColumn,hasKeepColumn=showKeys,hasKeep
        arrowCount=showEdgeArrows and 4 or (canReorder and 2 or 0)
        scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(),math.max(0,content:GetHeight()-scroll:GetHeight())))
        self:LayoutCombatColumns()
    end
    panel.combatFrameTabs=frameTabs
    panel.combatOverview=overview
    panel.enableCombatMode=enable
    panel.combatProfileTabs=profileTabs
    panel.combatPinned=pinned
    panel.combatRows,panel.combatContent=rows,content
    panel.syncers[#panel.syncers+1]=function()panel:UpdateCombatRows()end
end
