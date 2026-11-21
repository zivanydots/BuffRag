local _, F = ...
local points = {left={"BOTTOMLEFT","TOPLEFT"}, center={"BOTTOM","TOP"}, right={"BOTTOMRIGHT","TOPRIGHT"}}
local bottomPoints = {left={"TOPLEFT","BOTTOMLEFT"}, center={"TOP","BOTTOM"}, right={"TOPRIGHT","BOTTOMRIGHT"}}
function F:TintPreviewIcon(texture,combat)
    if combat then texture:SetColorTexture(1,.42,.06,.27)
    else texture:SetColorTexture(.15,.48,1,.27) end
end
F.frameIconLayouts = {
    self = {"selfPlacement","selfTopAlign","selfVertical","selfSize","selfOffset","selfIconVertical","selfGrow"},
    party = {"placement","topAlign","vertical","size","offset","iconVertical","grow"},
    raidParty = {"raidPartyPlacement","raidPartyTopAlign","raidPartyVertical","raidPartySize","raidPartyOffset","raidPartyIconVertical","raidPartyGrow"},
    raid = {"raidPlacement","raidTopAlign","raidVertical","raidSize","raidOffset","raidIconVertical","raidGrow"},
    target = {"targetPlacement","targetTopAlign","targetVertical","targetSize","targetOffset","targetIconVertical","targetGrow"},
    focus = {"focusPlacement","focusTopAlign","focusVertical","focusSize","focusOffset","focusIconVertical","focusGrow"},
}
function F:FrameIconOffsetBounds(anchor,gap)
    local minX=(anchor=="left" or anchor=="right") and 0 or -400
    local minY=anchor=="top" and -gap or -200
    local maxY=anchor=="bottom" and gap or 200
    return minX,200,minY,maxY
end
function F:NormalizeFrameIconOffsets(settings,kind)
    local keys=self.frameIconLayouts[kind]
    settings[keys[3]]=math.max(0,math.min(80,tonumber(settings[keys[3]]) or self.defaults[keys[3]]))
    local minX,maxX,minY,maxY=self:FrameIconOffsetBounds(settings[keys[1]],settings[keys[3]])
    settings[keys[5]]=math.max(minX,math.min(maxX,tonumber(settings[keys[5]]) or self.defaults[keys[5]]))
    settings[keys[6]]=math.max(minY,math.min(maxY,tonumber(settings[keys[6]]) or self.defaults[keys[6]]))
end
function F:FrameLayout(frame,kind)
    if kind~="target" and kind~="focus" and frame==PlayerFrame then kind="self" end
    local keys=self.frameIconLayouts[kind==true and "raidParty" or kind] or self.frameIconLayouts.party
    local db=self.db
    return {placement=db[keys[1]],align=db[keys[2]],gap=db[keys[3]],size=db[keys[4]],offset=db[keys[5]],shift=db[keys[6]],grow=db[keys[7]]}
end
function F:LayoutIndicators(row, frame, isSelf, buttons, kind)
    local config=self:FrameLayout(frame,kind)
    local size=config.size
    for index,button in ipairs(buttons) do button.layoutIndex=index end
    local combat=buttons[1] and buttons[1].combatOnly and not buttons[1].outOfCombat
    if combat then
        table.sort(buttons,function(a,b)return a.combatPosition<b.combatPosition end)
    elseif isSelf then
        table.sort(buttons,function(a,b)
            if a.outOfCombat~=b.outOfCombat then return a.outOfCombat==true end
            if a.outOfCombat then return a.layoutIndex<b.layoutIndex end
            local first=F:SelfActionScore(a.buffKey,{itemIndex=a.itemIndex})
            local second=F:SelfActionScore(b.buffKey,{itemIndex=b.itemIndex})
            return first<second or (first==second and a.layoutIndex<b.layoutIndex)
        end)
    end
    local count=0
    local edge=config.grow=="left" and "RIGHT" or "LEFT"
    local direction=edge=="RIGHT" and -1 or 1
    for _,button in ipairs(buttons) do
        button:ClearAllPoints()
        button:SetSize(size,size)
        if button.creationMark and button.creationMark:IsShown() then
            button.creationMark:SetScale(size/20)
        end
        local slot=count+1
        button:SetPoint(edge,row,edge,direction*(slot-1)*(size+self.db.spacing),0)
        count=math.max(count,slot)
    end
    row.displayOrder=buttons
    row:SetSize(math.max(1,count*size+math.max(0,count-1)*self.db.spacing),size)
    self:PositionIconRow(row,frame,config)
end
function F:PositionIconRow(row,frame,config)
    row:ClearAllPoints()
    local placement,offset,verticalShift=config.placement,config.offset,config.shift
    if placement=="top" then
        local point=points[config.align] or points.right
        row:SetPoint(point[1],frame,point[2],offset,config.gap+verticalShift)
    elseif placement=="bottom" then
        local point=bottomPoints[config.align] or bottomPoints.right
        row:SetPoint(point[1],frame,point[2],offset,verticalShift-config.gap)
    elseif placement=="center" then
        row:SetPoint("CENTER",frame,"CENTER",offset,verticalShift)
    elseif placement=="left" then
        row:SetPoint("RIGHT",frame,"LEFT",-offset,verticalShift)
    else
        row:SetPoint("LEFT",frame,"RIGHT",offset,verticalShift)
    end
end
function F:SetTestMode(mode)
    if mode~="buffs"and mode~="combat"then mode=nil end
    if mode and InCombatLockdown()then return end
    self.testMode=mode;self.testUI=mode~=nil
    if not self.testUI then
        for _,preview in pairs(self.previews or {})do preview:Hide()end
        if self.groupPreviewHost and not InCombatLockdown() then self.groupPreviewHost:Hide() end
    end
    if not InCombatLockdown()then self:Refresh()end
end
function F:SetTestUI(enabled)
    self:SetTestMode(enabled and "buffs"or nil)
end
function F:PreviewBuffEnabled(entry,scope)
    if entry.kind=="items" then return true end
    local targets=self.db.targetScopes[entry.key]
    return not entry.passive and not entry.buffStockOnly and targets and targets[scope] and (not entry.selfOnly or scope=="self")
end
function F:IsGroupPreviewFrame(kind,unit)
    local edit=EditModeManagerFrame
    if not edit or not edit.IsEditModeActive or not edit:IsEditModeActive() then return false end
    if kind=="raid" then
        return edit.AreRaidFramesForcedShown and edit:AreRaidFramesForcedShown()
            and (not unit or not unit:match("^raid%d+$") or not UnitExists(unit))
    end
    if kind=="party" or kind=="raidParty" then
        return edit.ArePartyFramesForcedShown and edit:ArePartyFramesForcedShown()
            and (not unit or not UnitExists(unit) or (unit=="player" and not IsInGroup()))
    end
    return false
end
local previewNames={party="BuffRagStandardPartyPreview",raidParty="BuffRagRaidStylePartyPreview",raid="BuffRagRaidPreview"}

local function fillPreviewBar(bar)
    if not bar then return end
    bar:SetMinMaxValues(0,1)
    bar:SetValue(1)
    bar:Show()
end

local function compactDimension(method,groupType,fallback)
    local manager=EditModeManagerFrame
    if not manager or not manager[method] or not groupType then return fallback end
    local ok,value=pcall(manager[method],manager,groupType,fallback)
    if ok and type(value)=="number" and value>0 then return value end
    return fallback
end

local function configureGroupMember(host,kind,name)
    local standard=kind=="party"
    local template=standard and "PartyMemberFrameTemplate" or "CompactUnitFrameTemplate"
    local member=CreateFrame("Button",name,host,template)
    member:UnregisterAllEvents()
    member:SetScript("OnUpdate",nil)
    member:SetScript("OnShow",nil)
    member:SetScript("OnHide",nil)
    member:EnableMouse(false)
    member:SetFrameStrata("MEDIUM")
    local name=UnitName("player")
    if standard then
        if member.Name then member.Name:SetText(name) end
        if member.Portrait then SetPortraitTexture(member.Portrait,"player") end
        if member.Texture then member.Texture:Show() end
        if member.HealthBarContainer then fillPreviewBar(member.HealthBarContainer.HealthBar) end
        fillPreviewBar(member.ManaBar)
    else
        local types=CompactRaidGroupTypeEnum
        member.groupType=types and (kind=="raidParty" and types.Party or types.Raid)
        member:SetSize(compactDimension("GetRaidFrameWidth",member.groupType,72),
            compactDimension("GetRaidFrameHeight",member.groupType,36))
        local bar=member.healthBar
        if bar then
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT",1,-1)
            bar:SetPoint("BOTTOMRIGHT",-1,1)
            bar:SetStatusBarColor(.12,.56,.22)
            fillPreviewBar(bar)
        end
        if member.name then
            member.name:ClearAllPoints()
            member.name:SetPoint("CENTER")
            member.name:SetText(name)
        end
        if member.powerBar then member.powerBar:Hide() end
        if member.selectionHighlight then member.selectionHighlight:Hide() end
        if member.aggroHighlight then member.aggroHighlight:Hide() end
    end
    return member
end

function F:ShowGroupIconPreview(kind,count)
    local host=self.groupPreviewHost
    if not kind then
        if host then host:Hide() end
        return
    end
    if not host then
        host=CreateFrame("Frame",nil,UIParent,"SecureHandlerStateTemplate")
        host:SetAllPoints(UIParent)
        host:EnableMouse(false)
        host:SetAttribute("_onstate-combat",[[if newstate=="combat" then self:Hide() end]])
        RegisterStateDriver(host,"combat","[combat] combat; safe")
        host.members={}
        host:Hide()
        self.groupPreviewHost=host
    end

    local native=kind=="raid" and CompactRaidFrameContainer or PartyFrame
    local scale=native and native:GetEffectiveScale()
    local left,top
    if native then left,top=native:GetLeft(),native:GetTop() end
    scale=scale or host:GetEffectiveScale()
    if not left or not top then
        left,top=80,UIParent:GetHeight()*.70
        scale=host:GetEffectiveScale()
    end

    for key,members in pairs(host.members) do
        for index,member in ipairs(members) do
            if member and (key~=kind or index>count) then member:Hide() end
        end
    end
    local members=host.members[kind] or {}
    host.members[kind]=members
    local visible={}
    for index=1,count do
        if members[index]==nil then
            local name=previewNames[kind]..index
            local ok,member=pcall(configureGroupMember,host,kind,name)
            members[index]=ok and member or false
            if not members[index] then
                self.groupPreviewError=not ok and tostring(member) or "Template creation returned no frame"
                local incomplete=_G[name]
                if incomplete then incomplete:UnregisterAllEvents(); incomplete:Hide() end
            end
        end
        local member=members[index]
        if member then
            member:SetScale(scale/host:GetEffectiveScale())
            if member.PetFrame then member.PetFrame:Hide() end
            local row=(index-1)%5
            local column=math.floor((index-1)/5)
            local verticalGap=kind=="party" and 10 or 2
            member:ClearAllPoints()
            member:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",
                left+column*(member:GetWidth()+8),top-row*(member:GetHeight()+verticalGap))
            member:Show()
            visible[#visible+1]=member
        end
    end
    host:SetShown(#visible>0)
    return visible
end

function F:RefreshTestUI()
    if not self.testUI then return end
    self.previews = self.previews or {}
    for _, preview in pairs(self.previews) do preview:Hide() end
    local window=self.options.iconOptions
    local canDrag=window and window:IsShown() and not InCombatLockdown()
    local function draw(frame,kind,unit,isSample)
        local isSelf=kind=="self" or (not isSample and kind~="target" and kind~="focus" and F:IsSelf(unit))
        local scope=(kind=="raidParty" and "party") or (isSelf and "self") or kind
        local row=self.previews[frame]
        if not row then
            row=CreateFrame("Frame",nil,UIParent); row:SetFrameStrata("HIGH"); row:EnableMouse(false)
            row.squares={}; self.previews[frame]=row
        end
        row.previewKind=kind
        row:Show()
        local context=(kind=="target" or kind=="focus") and kind or scope
        local displayed={}
        local function icon(key,itemID,itemIndex,creation,spellID,weaponSlot,candidate)
            local index=#displayed+1
            local square=row.squares[index]
            if not square then
                square=CreateFrame("Frame",nil,row);square:EnableMouse(false)
                square:SetScript("OnMouseDown",function(_,button)
                    local options=F.options.iconOptions
                    if button=="LeftButton" and options and options:IsShown() then options:StartIconDrag(row) end
                end)
                square.texture=square:CreateTexture(nil,"BACKGROUND");square.texture:SetAllPoints()
                square.previewTint=square:CreateTexture(nil,"ARTWORK");square.previewTint:SetAllPoints()
                square.visual=square;F:CreateIconOverlay(square);F:CreateItemSlash(square);F:CreateCombatCooldown(square);row.squares[index]=square
            end
            square:EnableMouse(not not canDrag)
            local entry=F.spells[key]or F.abilityFamilies[key]
            local _,id
            if entry then _,id=F:LearnedSpell(entry.ids)end
            square.buffKey,square.customItem,square.itemIndex=key,itemID,itemIndex
            square.buffUnit=unit;square.buffSpellID=spellID or id or(entry and entry.ids[1])
            square.poison=entry and entry.kind=="poison"and weaponSlot~=nil
            square.weaponSlot=weaponSlot;F:UpdatePoisonHandLabel(square)
            square.isCreation=creation==true;square.missingSlash:Hide()
            square.combatOnly=candidate~=nil
            square.outOfCombat=candidate and candidate.outOfCombat==true or false
            square.combatPosition=candidate and candidate.combatPosition
            square.pet=candidate and candidate.pet;square.petSlot=candidate and candidate.petSlot;square.petBank=candidate and candidate.petBank
            square.castFeedbackSource={spellID=spellID,itemID=itemID};square.castFeedbackIDs=nil;square.cooldownGeneration=nil
            F:PaintIcon(square,square.buffSpellID,itemID,creation)
            F:TintPreviewIcon(square.previewTint,F.testMode=="combat" or square.outOfCombat)
            square:Show();displayed[index]=square
        end
        local choice=F.options.combatProfiles and F.options.combatProfiles[kind]or 'friendly'
        local profile=(kind=='target'or kind=='focus')and(kind..(choice=='friendly'and 'Friendly'or ''))or nil
        if F.testMode=="combat"then
            for _,candidate in ipairs(F:BuildCombatCandidates(unit,kind,true,profile))do
                if not candidate.allowDead or candidate.combatRes then
                    icon(candidate.key,candidate.itemID,candidate.itemIndex,candidate.creation,candidate.spellID,candidate.weaponSlot,candidate)
                end
            end
        else
            if F.db.combatClicks then
                for _,candidate in ipairs(F:FrameOutOfCombatCandidates(unit,kind,nil,nil,profile)) do
                    icon(candidate.key,candidate.itemID,candidate.itemIndex,candidate.creation,candidate.spellID,candidate.weaponSlot,candidate)
                end
            end
            for _,key in ipairs(F.db.priority)do
                local entry=F.spells[key]
                local keep=context~="target"and context~="focus"and isSelf and F:KeepsEntry(entry)
                if F:BuffRowEnabled(key)and(F:PreviewBuffEnabled(entry,scope)or keep)then
                    if entry.kind=="items"then
                        for index,item in ipairs(F.db.items)do if item.enabled and not item.combat and item[scope]then icon(key,item.id,index)end end
                    elseif F:BuffAvailable(entry)then
                        if keep and not F:PreviewBuffEnabled(entry,scope)then
                            if entry.buffStockOnly then
                                local candidate=F:CandidateForEntry(entry,unit,context)
                                if candidate then icon(key,nil,nil,true,candidate.spellID) end
                            else
                                local _,id=F:LearnedSpell(entry.ids);icon(key,nil,nil,true,id)
                            end
                        else
                            local candidate=F:BuffCandidate(entry,unit,true)
                            if candidate then icon(key,candidate.itemID,nil,candidate.creation,candidate.spellID,candidate.weaponSlot)
                            elseif entry.kind~="poison"and entry.kind~="soul"then icon(key)end
                        end
                    end
                end
            end
        end
        row.sampleOnly=#displayed==0
        if row.sampleOnly then
            for index=1,3 do icon(nil) end
        end
        row.previewMode=F.testMode
        for index=#displayed+1,#row.squares do row.squares[index]:Hide()end
        F:LayoutIndicators(row,frame,isSelf,displayed,kind)
        for _,square in ipairs(displayed)do
            if square.customItem then F:UpdateCustomItemVisual(square)end
            local alpha=not row.sampleOnly and F.testMode=="combat" and F.db.combatOpacity/100 or 1
            local range
            if not isSample and not row.sampleOnly then
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
    local drawn,kinds = {},{}
    if window and window:IsShown() then window:SyncModes() end
    local selected=window and window:IsShown() and window.kind
    local selectedGroup=selected=="party" or selected=="raidParty" or selected=="raid"
    local function visit(frame,kind)
        if not frame or frame:IsForbidden() or not frame:IsVisible() or drawn[frame] then return end
        local unit = (kind=="target" or kind=="focus") and kind
            or (kind=="self" and "player") or frame.unit or frame:GetAttribute("unit")
        if unit and issecretvalue and issecretvalue(unit) then return end
        local sample = self:IsGroupPreviewFrame(kind,unit)
        if sample and selected and kind~=selected then return end
        if not sample and (not unit or not UnitExists(unit)) then return end
        drawn[frame] = true
        kinds[kind] = true
        unit = sample and (kind=="raid" and "raid1" or "party1") or unit
        draw(frame,kind,unit,sample)
    end
    local party = PartyFrame
    for index=1,4 do
        local member = party and party.GetPartyMemberFrame and party:GetPartyMemberFrame(index)
        visit(member or (party and party["MemberFrame"..index]) or _G["PartyMemberFrame"..index],"party")
    end
    if CompactPartyFrame then
        for _,member in ipairs(CompactPartyFrame.memberUnitFrames or {}) do visit(member,"raidParty") end
    end
    if CompactRaidFrameContainer and CompactRaidFrameContainer.ApplyToFrames then
        local container=CompactRaidFrameContainer
        container:ApplyToFrames("normal",function(frame)
            local parent=frame:GetParent()
            while parent and parent~=container do parent=parent:GetParent() end
            if parent==container then visit(frame,"raid") end
        end)
    end
    for frame,overlay in pairs(self.overlays) do visit(frame,overlay.frameKind) end
    local sampleKind=selectedGroup and not kinds[selected] and selected or nil
    local count=sampleKind=="raid" and window.raidPreviewSize or (sampleKind=="party" and 4 or 5)
    local samples=self:ShowGroupIconPreview(sampleKind,count)
    if samples and #samples>0 then
        kinds[sampleKind]=true
        for _,sample in ipairs(samples) do
            draw(sample,sampleKind,sampleKind=="raid" and "raid1" or "party1",true)
        end
    end
    self.frameIconPreviewKinds=kinds
    if self.options.iconOptions then self.options.iconOptions:UpdatePreviewStatus(kinds) end
end
