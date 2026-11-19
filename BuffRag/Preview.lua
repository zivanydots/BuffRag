local _, F = ...
local points = {left={"BOTTOMLEFT","TOPLEFT"}, center={"BOTTOM","TOP"}, right={"BOTTOMRIGHT","TOPRIGHT"}}
local overlayPoints = {left="LEFT",center="CENTER",right="RIGHT"}
function F:FrameLayout(frame,kind)
    local db=self.db
    if kind=="focus" then
        return {size=db.focusSize,offset=db.focusOffset,shift=db.focusIconVertical,placement=db.focusPlacement,align=db.focusTopAlign,gap=db.focusVertical}
    elseif kind=="target" then
        return {size=db.targetSize,offset=db.targetOffset,shift=db.targetIconVertical,placement=db.targetPlacement,align=db.targetTopAlign,gap=db.targetVertical}
    elseif frame==PlayerFrame then
        return {size=db.selfSize,offset=db.selfOffset,shift=db.selfIconVertical,placement=db.selfPlacement,align=db.selfTopAlign,gap=db.selfVertical}
    elseif kind=="raidParty" or kind==true then
        return {size=db.raidPartySize,offset=db.raidPartyOffset,shift=db.raidPartyIconVertical,placement=db.raidPartyPlacement,align=db.raidPartyTopAlign,gap=db.raidPartyVertical}
    elseif kind=="raid" then
        return {size=db.raidSize,offset=db.raidOffset,shift=db.raidIconVertical,placement=db.raidPlacement,align=db.raidTopAlign,gap=db.raidVertical}
    end
    return {size=db.size,offset=db.offset,shift=db.iconVertical,placement=db.placement,align=db.topAlign,gap=db.vertical}
end
function F:LayoutIndicators(row, frame, isSelf, buttons, kind)
    local config=self:FrameLayout(frame,kind)
    local size,offset=config.size,config.offset
    for index,button in ipairs(buttons) do button.layoutIndex=index end
    local combat=buttons[1] and buttons[1].combatOnly
    if combat then
        table.sort(buttons,function(a,b)return a.combatPosition<b.combatPosition end)
    elseif isSelf then
        table.sort(buttons,function(a,b)
            local first=F:SelfActionScore(a.buffKey,{itemIndex=a.itemIndex})
            local second=F:SelfActionScore(b.buffKey,{itemIndex=b.itemIndex})
            return first<second or (first==second and a.layoutIndex<b.layoutIndex)
        end)
    end
    local count=0
    for _,button in ipairs(buttons) do
        button:ClearAllPoints()
        button:SetSize(size,size)
        local slot=count+1
        button:SetPoint("LEFT",row,"LEFT",(slot-1)*(size+self.db.spacing),0)
        count=math.max(count,slot)
    end
    row.displayOrder=buttons
    row:ClearAllPoints()
    row:SetSize(math.max(1,count*size+math.max(0,count-1)*self.db.spacing),size)
    local placement=config.placement
    local verticalShift=config.shift
    if placement=="top" then
        local point=points[config.align] or points.right
        row:SetPoint(point[1],frame,point[2],offset,config.gap+verticalShift)
    elseif placement=="overlay" then
        local point=overlayPoints[config.align] or "RIGHT"
        row:SetPoint(point,frame,point,offset,verticalShift)
    else
        row:SetPoint("LEFT",frame,"RIGHT",offset,verticalShift)
    end
end
function F:SyncTestControls()
    if not self.options or InCombatLockdown()then return end
    if self.options.test then self.options.test:SetChecked(self.testMode=="buffs")end
    if self.options.testCombat then self.options.testCombat:SetChecked(self.testMode=="combat")end
end
function F:SetTestMode(mode)
    if mode~="buffs"and mode~="combat"then mode=nil end
    if mode and InCombatLockdown()then return end
    self.testMode=mode;self.testUI=mode~=nil
    self:SyncTestControls()
    if not self.testUI then
        for _,preview in pairs(self.previews or {})do preview:Hide()end
        for _,frame in ipairs(self.previewParties or {})do frame:Hide()end
        if self.previewRaid then self.previewRaid:Hide()end
        if self.previewTarget then self.previewTarget:Hide()end
        if self.previewFocus then self.previewFocus:Hide()end
    end
    if not InCombatLockdown()then self:Refresh()end
end
function F:SetTestUI(enabled)
    self:SetTestMode(enabled and "buffs"or nil)
end
function F:RefreshTestUI()
    if not self.testUI then return end
    self.previews = self.previews or {}
    for _, preview in pairs(self.previews) do preview:Hide() end
    local function draw(frame,isSelf,kind)
        local row=self.previews[frame]
        if not row then
            row=CreateFrame("Frame",nil,UIParent); row:SetFrameStrata("DIALOG"); row:EnableMouse(false)
            row.squares={}; self.previews[frame]=row
        end
        row:Show()
        local unit=(kind=="target"or kind=="focus") and kind or (isSelf and "player" or (kind=="raid" and "raid1" or "party1"))
        local context=(kind=="target"or kind=="focus") and kind or (kind=="raid" and "raid" or "party")
        local displayed={}
        local function icon(key,itemID,itemIndex,creation,spellID,weaponSlot,candidate)
            local index=#displayed+1
            local square=row.squares[index]
            if not square then
                square=CreateFrame("Frame",nil,row);square:EnableMouse(false)
                square.texture=square:CreateTexture(nil,"BACKGROUND");square.texture:SetAllPoints()
                square.text=square:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");square.text:SetPoint("CENTER")
                square.bindingLabel=square:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
                square.bindingLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",7,"OUTLINE")
                square.bindingLabel:SetPoint("BOTTOM",square,"TOP",0,1)
                square.visual=square;F:CreateItemSlash(square);F:CreateCombatCooldown(square);row.squares[index]=square
            end
            local entry=F.spells[key]or F.abilityFamilies[key]
            local _,id
            if entry then _,id=F:LearnedSpell(entry.ids)end
            square.buffKey,square.customItem,square.itemIndex=key,itemID,itemIndex
            square.buffUnit=unit;square.buffSpellID=spellID or id or(entry and entry.ids[1])
            square.poison=entry and entry.kind=="poison"and weaponSlot~=nil
            square.weaponSlot=weaponSlot;F:UpdatePoisonHandLabel(square)
            square.isCreation=creation==true;square.missingSlash:Hide()
            square.combatOnly=candidate~=nil
            square.combatPosition=candidate and candidate.combatPosition
            square.combatModifier=candidate and candidate.combatModifier
            square.pet=candidate and candidate.pet;square.petSlot=candidate and candidate.petSlot;square.petBank=candidate and candidate.petBank
            square.bindingLabel:SetText(square.combatModifier and square.combatModifier:upper()or "")
            square.bindingLabel:SetShown(square.combatModifier~=nil)
            square.castFeedbackSource={spellID=spellID,itemID=itemID};square.castFeedbackIDs=nil;square.cooldownGeneration=nil
            F:PaintIcon(square,square.buffSpellID,itemID,creation)
            square:Show();displayed[index]=square
        end
        if F.testMode=="combat"then
            local choice=F.options.combatProfiles and F.options.combatProfiles[kind]or 'friendly'
            local profile=(kind=='target'or kind=='focus')and(kind..(choice=='friendly'and 'Friendly'or ''))or nil
            for _,candidate in ipairs(F:BuildCombatCandidates(unit,kind,true,profile))do
                icon(candidate.key,candidate.itemID,candidate.itemIndex,candidate.creation,candidate.spellID,candidate.weaponSlot,candidate)
            end
        else
            for _,key in ipairs(F.db.priority)do
                local entry=F.spells[key]
                local keep=context~="target"and context~="focus"and isSelf and F:KeepsEntry(entry)
                if F:BuffRowEnabled(key)and(F:EntryEnabled(key,unit,context)or keep)then
                    if entry.kind=="items"then
                        local scope=F:ScopeFor(unit,context)
                        for index,item in ipairs(F.db.items)do if item.enabled and item[scope]then icon(key,item.id,index)end end
                    elseif F:BuffAvailable(entry)then
                        if keep and not F:EntryEnabled(key,unit,context)then
                            local _,id=F:LearnedSpell(entry.ids);icon(key,nil,nil,true,id)
                        else
                            local candidate=F:BuffCandidate(entry,unit,true)
                            if candidate then icon(key,candidate.itemID,nil,candidate.creation,candidate.spellID,candidate.weaponSlot)
                            elseif entry.kind~="poison"then icon(key)end
                        end
                    end
                end
            end
        end
        row.sampleOnly=false;row.previewMode=F.testMode
        for index=#displayed+1,#row.squares do row.squares[index]:Hide()end
        F:LayoutIndicators(row,frame,isSelf,displayed,kind)
        for _,square in ipairs(displayed)do
            if square.customItem then F:UpdateCustomItemVisual(square)end
            local alpha=F.testMode=="combat"and F.db.combatOpacity/100 or 1
            local range
            if F.overlays[frame]then
                if square.pet then
                    if C_SpellBook and C_SpellBook.IsSpellBookItemInRange and F:PetSpellSlotMatches(square)then
                        local ok,value=pcall(C_SpellBook.IsSpellBookItemInRange,square.petSlot,square.petBank,unit)
                        if ok and not(issecretvalue and issecretvalue(value))then range=value end
                    end
                else range=F:RangeStatus(unit,square.buffSpellID,square.customItem)end
            end
            square:SetAlpha(range==false and alpha*.5 or alpha)
            F:UpdateCombatCooldown(square,true)
        end

    end
    local groupShown,raidShown,targetShown,focusShown = false,false,false,false
    for frame,overlay in pairs(self.overlays) do
        if frame:IsVisible() then
            local unit = (overlay.frameKind=="target"or overlay.frameKind=="focus") and overlay.frameKind or (frame == PlayerFrame and "player" or frame.unit or frame:GetAttribute("unit"))
            if unit and not (issecretvalue and issecretvalue(unit)) then
                local isSelf = F:IsSelf(unit)
                draw(frame, isSelf, overlay.frameKind)
                if overlay.frameKind=="raid" then raidShown=true end
                if overlay.frameKind=="target" then targetShown=true end
                if overlay.frameKind=="focus" then focusShown=true end
                if not isSelf and overlay.frameKind~="target" and overlay.frameKind~="focus" then groupShown = true end
            end
        end
    end
    -- Solo players can still configure party placement without joining a group.
    if not groupShown then
        self.previewParties=self.previewParties or {}
        for index=1,2 do
            local sample=self.previewParties[index]
            if not sample then
                sample = CreateFrame("Frame", nil, UIParent)
                sample:SetFrameStrata("DIALOG"); sample:SetSize(150, 40); sample:EnableMouse(false)
                local background = sample:CreateTexture(nil, "BACKGROUND")
                background:SetAllPoints(); background:SetColorTexture(.12,.12,.12,.95)
                local label = sample:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
                label:SetPoint("CENTER"); label:SetText(index==1 and "Party frame preview" or "Raid-style party preview")
                self.previewParties[index]=sample
            end
            sample:ClearAllPoints()
            sample:SetPoint("LEFT",UIParent,"LEFT",80,index==1 and 45 or -45)
            sample:Show()
            draw(sample,false,index==2 and "raidParty" or "party")
        end
    else
        for _,sample in ipairs(self.previewParties or {}) do sample:Hide() end
    end
    if not raidShown then
        if not self.previewRaid then
            local sample=CreateFrame("Frame",nil,UIParent)
            sample:SetFrameStrata("DIALOG"); sample:SetSize(110,45); sample:EnableMouse(false)
            local background=sample:CreateTexture(nil,"BACKGROUND")
            background:SetAllPoints(); background:SetColorTexture(.12,.12,.12,.95)
            local label=sample:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            label:SetPoint("CENTER"); label:SetText("Raid frame preview")
            self.previewRaid=sample
        end
        self.previewRaid:ClearAllPoints(); self.previewRaid:SetPoint("LEFT",UIParent,"LEFT",80,-125)
        self.previewRaid:Show(); draw(self.previewRaid,false,"raid")
    elseif self.previewRaid then self.previewRaid:Hide() end
    if not targetShown then
        if not self.previewTarget then
            local sample=CreateFrame("Frame",nil,UIParent)
            sample:SetFrameStrata("DIALOG"); sample:SetSize(180,60); sample:EnableMouse(false)
            local background=sample:CreateTexture(nil,"BACKGROUND")
            background:SetAllPoints(); background:SetColorTexture(.12,.12,.12,.95)
            local label=sample:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            label:SetPoint("CENTER"); label:SetText("Friendly target preview")
            self.previewTarget=sample
        end
        self.previewTarget:ClearAllPoints(); self.previewTarget:SetPoint("LEFT",UIParent,"LEFT",80,-215)
        self.previewTarget:Show(); draw(self.previewTarget,false,"target")
    elseif self.previewTarget then self.previewTarget:Hide() end
    if not focusShown then
        if not self.previewFocus then
            local sample=CreateFrame("Frame",nil,UIParent)
            sample:SetFrameStrata("DIALOG");sample:SetSize(180,60);sample:EnableMouse(false)
            local background=sample:CreateTexture(nil,"BACKGROUND");background:SetAllPoints();background:SetColorTexture(.12,.12,.12,.95)
            local label=sample:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");label:SetPoint("CENTER");label:SetText("Focus frame preview")
            self.previewFocus=sample
        end
        self.previewFocus:ClearAllPoints();self.previewFocus:SetPoint("LEFT",UIParent,"LEFT",80,-295)
        self.previewFocus:Show();draw(self.previewFocus,false,"focus")
    elseif self.previewFocus then self.previewFocus:Hide()end
end
