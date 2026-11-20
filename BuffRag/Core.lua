local _, F = ...
BuffRag = F
F.version = "0.2.34"
F.headerHeight = 72
F.itemsIcon = "Interface\\Icons\\INV_Misc_Bag_08"
F.maxIndicators = 15
F.defaults = {
    enabled=true,linkIconSizes=true,linkRaidIconSize=false,size=20,selfSize=20,spacing=3,offset=31,selfOffset=15,
    itemsEnabled=true,items={},iconVertical=0,selfIconVertical=0,
    windowScale=.85,windowZoom=85,windowWidth=1160,windowHeight=678,headerLayoutVersion=1,combatClicks=false,combatOpacity=100,combatFeedback=false,combatIncludeBuffs=false,frameModifier="shift",minimapEnabled=true,
    combatRows={},combatOrders={},combatOrder={"__shift","__ctrl","__alt"},
    grow="right",selfGrow="right",raidPartyGrow="right",raidGrow="right",targetGrow="right",focusGrow="right",
    placement="right",selfPlacement="right",topAlign="right",selfTopAlign="right",vertical=3,selfVertical=3,
    raidPartyPlacement="right",raidPartySize=20,raidPartyOffset=31,raidPartyIconVertical=0,raidPartyTopAlign="right",raidPartyVertical=3,
    raidPlacement="center",raidSize=15,raidOffset=-20,raidIconVertical=-12,raidTopAlign="right",raidVertical=3,
    focusPlacement="right",focusSize=20,focusOffset=31,focusIconVertical=0,focusTopAlign="right",focusVertical=3,
    targetPlacement="right",targetSize=20,targetOffset=31,targetIconVertical=0,targetTopAlign="right",targetVertical=3,
}
F.overlays = {}
local function public(value) return not (issecretvalue and issecretvalue(value)) end
function F:IsSelf(unit)
    if not public(unit) or not unit then return false end
    if unit == "player" then return true end
    local same = UnitIsUnit(unit, "player")
                                                                         
                                                                         
    return public(same) and (same==true or same==1) or false
end
local function publicBoolean(value)
    if public(value) and type(value)=="boolean" then return value end
end
function F:RememberRefreshUnit(unit)
    if self.refreshUnits[unit] then return end
    local exists=UnitExists(unit)
    if not public(exists) or not exists then return end
    local state={
        dead=publicBoolean(UnitIsDeadOrGhost(unit)),
        connected=publicBoolean(UnitIsConnected(unit)),
        friendly=publicBoolean(UnitIsFriend("player",unit)),
        hostile=UnitCanAttack and publicBoolean(UnitCanAttack("player",unit)),
    }
    self.refreshUnits[unit]=state
    local guid=UnitGUID(unit)
    if public(guid) and guid then self.refreshUnitGUIDs[guid]=state end
end
function F:RefreshUnitStateChanged(unit,healthOnly)
    if not self.refreshUnits or not public(unit) or not unit then return false end
    local state=self.refreshUnits[unit]
    if not state then
        local guid=UnitGUID(unit)
        if public(guid) and guid then state=self.refreshUnitGUIDs[guid] end
    end
    if not state then return false end
    local dead=publicBoolean(UnitIsDeadOrGhost(unit))
    if dead~=nil and dead~=state.dead then return true end
    if healthOnly then return false end
    local connected=publicBoolean(UnitIsConnected(unit))
    local friendly=publicBoolean(UnitIsFriend("player",unit))
    local hostile=UnitCanAttack and publicBoolean(UnitCanAttack("player",unit))
    return (connected~=nil and connected~=state.connected)
        or (friendly~=nil and friendly~=state.friendly)
        or (hostile~=nil and hostile~=state.hostile)
end
function F:ResetDefaults()
    self:ResetDisplayedDefaults()
end
function F:CarriedStone(kind)
    for _, id in ipairs(self.stoneTypes[kind].items) do
        if C_Item.GetItemCount(id) > 0 then return id end
    end
end
local function createCreationMark(parent)
    local mark=CreateFrame("Frame",nil,parent)
    mark:EnableMouse(false)
    mark:SetPoint("CENTER",parent,"CENTER",0,0)
    mark:SetSize(20,20)
    for layer,stroke in ipairs({{10,4,0},{8,2,1}}) do
        local length,width,shade=stroke[1],stroke[2],stroke[3]
        local horizontal=mark:CreateTexture(nil,"OVERLAY",nil,layer)
        local vertical=mark:CreateTexture(nil,"OVERLAY",nil,layer)
        horizontal:SetPoint("CENTER")
        vertical:SetPoint("CENTER")
        horizontal:SetSize(length,width)
        vertical:SetSize(width,length)
        horizontal:SetSnapToPixelGrid(false)
        vertical:SetSnapToPixelGrid(false)
        horizontal:SetColorTexture(shade,shade,shade,1)
        vertical:SetColorTexture(shade,shade,shade,1)
    end
    return mark
end
function F:PaintIcon(square, spellID, itemID, creation)
    local texture
    if itemID and C_Item.GetItemIconByID then texture = C_Item.GetItemIconByID(itemID) end
    if not texture and spellID then
        if C_Spell.GetSpellTexture then texture = C_Spell.GetSpellTexture(spellID) end
        if not texture then
            local info = C_Spell.GetSpellInfo(spellID)
            texture = info and info.iconID
        end
    end
    square.texture:SetTexture(public(texture) and texture and texture~=0 and texture~="" and texture or "Interface\\Icons\\INV_Misc_QuestionMark")
                                                                      
    square.texture:SetAlpha(creation and .75 or 1)
    square.text:SetText("")
    if creation and not square.creationMark then square.creationMark=createCreationMark(square.visual) end
    if square.creationMark then square.creationMark:SetShown(creation==true) end
end
function F:CreateIconOverlay(square)
    square.text=square.visual:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    square.text:SetPoint("CENTER")
    square.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",11,"THICKOUTLINE")
    square.text:SetTextColor(1,1,1)
end
function F:ItemReady(id)
    local start,duration,enabled=C_Item.GetItemCooldown(id)
    return public(start) and public(duration) and public(enabled)
        and (enabled == true or enabled == 1)
        and (start == 0 or start + duration <= GetTime())
end
function F:SetAction(button, prefix, action)
    for _, key in ipairs({"type", "spell", "item", "macrotext"}) do
        local attribute=prefix..key.."1"
        local value=action and action[key] or (key=="type" and "" or nil)
        if button:GetAttribute(attribute)~=value then button:SetAttribute(attribute,value) end
    end
end
function F:UpdateActivation()
    if not self.activate then
        local button = CreateFrame("Button", "BuffRagActivateButton", UIParent,
            "SecureActionButtonTemplate,SecureHandlerStateTemplate")
        button:SetSize(1,1); button:SetPoint("TOPLEFT"); button:SetAlpha(0); button:EnableMouse(false)
                                                                          
                                                                             
        button:RegisterForClicks("AnyDown")
        button:SetAttribute("useOnKeyDown", true)
        button:SetAttribute("unit", "player")
        button:SetAttribute("checkselfcast", false)
        button:SetAttribute("checkfocuscast", false)
        button:SetAttribute("_onstate-combat", [[
            for i = 0, 3 do
                local prefix = i == 0 and "" or (i == 1 and "shift-" or (i == 2 and "ctrl-" or "alt-"))
                for j = 1, 4 do
                    local key = j == 1 and "type1" or (j == 2 and "spell1" or (j == 3 and "item1" or "macrotext1"))
                    local attribute = prefix .. key
                    if newstate == "combat" then
                        self:SetAttribute(attribute, key == "type1" and "" or nil)
                    else
                        self:SetAttribute(attribute, self:GetAttribute("safe-" .. attribute))
                    end
                end
            end
        ]])
        RegisterStateDriver(button, "combat", "[combat] combat; safe")
        self.activate = button
    end
    local action = self.selfAction
    local button = self.activate
    self:SetAction(button, "", action)
    for _,prefix in ipairs({"shift-","ctrl-","alt-"}) do self:SetAction(button,prefix,nil) end
    local modifier=self.db.priorityModifier
    if modifier=="shift" or modifier=="ctrl" or modifier=="alt" then
        self:SetAction(button,modifier.."-",self.selfPriorityAction)
    end
    for _,prefix in ipairs({"","shift-","ctrl-","alt-"}) do
        for _,key in ipairs({"type1","spell1","item1","macrotext1"}) do
            button:SetAttribute("safe-"..prefix..key,button:GetAttribute(prefix..key))
        end
    end
end
function F:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd200Buff Rag:|r " .. message)
end
function F:Tracking(name)
    if not C_Minimap or not C_Minimap.GetNumTrackingTypes then return true end
    for index = 1, C_Minimap.GetNumTrackingTypes() do
        local info = C_Minimap.GetTrackingInfo(index)
        if info and info.name == name then return info.active end
    end
    return false
end
function F:TargetMacro(unit, spellID, itemID)
    if not unit or not (unit == "player" or unit == "target" or unit == "focus" or unit:match("^party%d+$") or unit:match("^raid%d+$")) then return end
    local condition = "[@" .. unit .. ",exists,help,nodead] "
    if itemID then return "/use " .. condition .. "item:" .. itemID end
    local info = C_Spell.GetSpellInfo(spellID)
    if not info then return end
    local rank = C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(spellID)
    local spell = info.name .. (rank and rank ~= "" and ("(" .. rank .. ")") or "")
    return "/cast " .. condition .. spell
end
function F:RangeStatus(unit, spellID, itemID)
    if self:IsSelf(unit) then return true end
    local exists = UnitExists(unit)
    if public(exists) and not exists then return false end
    if UnitIsVisible then
        local visible = UnitIsVisible(unit)
        if public(visible) and not visible then return false end
    end
    local result
    if itemID and C_Item.IsItemInRange then result = C_Item.IsItemInRange(itemID, unit)
    elseif spellID and C_Spell.IsSpellInRange then result = C_Spell.IsSpellInRange(spellID, unit) end
    if public(result) and result ~= nil then return result end
                                                                              
    if UnitInRange then
        local inRange, checked = UnitInRange(unit)
        if public(inRange) and public(checked) and checked and not inRange then return false end
    end
end
function F:UpdateRange(fromRefresh)
    if not self.db then return end
    local combat=InCombatLockdown()
    local perf=self.perfRecording and not fromRefresh and self:BeginPerfRange()
    local icons=0
    local opacity=self.db.combatOpacity/100
    for _, overlay in pairs(self.overlays) do
        for _, button in ipairs(overlay.indicators.squares) do
            if button:IsShown() and button.buffUnit then
                if perf then icons=icons+1 end
                local inRange
                if button.pet then
                    local exists,dead=UnitExists("pet"),UnitIsDeadOrGhost("pet")
                    if (public(exists)and not exists)or(public(dead)and dead)then inRange=false
                    elseif C_SpellBook and C_SpellBook.IsSpellBookItemInRange and self:PetSpellSlotMatches(button)then
                        local ok,result=pcall(C_SpellBook.IsSpellBookItemInRange,button.petSlot,button.petBank,button.buffUnit)
                        if ok and public(result)then inRange=result end
                    end
                else inRange=self:RangeStatus(button.buffUnit, button.buffSpellID, button.rangeItem)end
                                                              
                button.outOfRange = inRange == false
                local out = public(inRange) and inRange == false
                if button.customItem then self:UpdateCustomItemVisual(button) end
                button.visual:SetAlpha((combat and button.combatOnly and opacity or 1)*(out and .5 or 1))
                self:UpdateCombatCooldown(button)
                self:UpdateDispelReminder(button)
                if not combat then
                    local actionType=out and "" or (button:GetAttribute("buff-action") or "")
                    if button:GetAttribute("type1")~=actionType then button:SetAttribute("type1",actionType) end
                end
            end
        end
    end
    if perf then self:EndPerfRange(perf,icons,combat) end
end
function F:RequestRefresh(reason)
    if self.perfRecording then self:NotePerfRefreshRequest(reason) end
    if self.refreshPending then return end
    self.refreshPending=true
    C_Timer.After(0,function()
        self.refreshPending=false
        local capture=self.perfRecording
        local triggers=capture and capture.pendingRefreshTriggers
        if capture then capture.pendingRefreshTriggers={} end
        self:Refresh(triggers)
    end)
end
function F:EnsureIndicators(frame,indicators,needed)
    for i = #indicators.squares+1, needed do
        local square = CreateFrame("Button", nil, indicators,
            "SecureActionButtonTemplate,SecureHandlerStateTemplate")
        square:SetFrameLevel(frame:GetFrameLevel() + 21)
        square:RegisterForClicks("AnyUp", "AnyDown")
        square:SetAttribute("useOnKeyDown", false)
        square:SetAttribute("checkselfcast", false)
        square:SetAttribute("checkfocuscast", false)
                                                                            
                                                   
        square:SetAttribute("_onstate-combat", [[
            if newstate == "combat" then
                if self:GetAttribute("combat-clicks") then
                    self:SetAttribute("type1", self:GetAttribute("buff-action") or "")
                else
                    self:SetAttribute("type1", "")
                end
                self:SetAlpha(1)
            else
                self:SetAttribute("type1", self:GetAttribute("buff-action") or "")
                self:SetAlpha(1)
            end
        ]])
        RegisterStateDriver(square, "combat", "[combat] combat; safe")
        square:SetScript("OnEnter", function(button)
            if not button.buffName then return end
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText(button.buffName, 1, 1, 1)
            if button.combatOnly then GameTooltip:AddLine(button.outOfCombat and "Out-of-combat action" or "Combat action",1,.82,0)end
            if button.cleanupOnly then GameTooltip:AddLine('Post-combat: dispel or resurrection available.',1,.82,0,true)end
            if button.pet then GameTooltip:AddLine("Cast by your summoned pet.",1,.82,0)end
            if button.combatOnly and not button.outOfCombat and button.combatModifier then GameTooltip:AddLine(button.combatModifier:upper().." + left-click this frame, or click this icon.",.8,.8,.8,true)end
            if button.keybind then GameTooltip:AddLine("Keybind: "..button.keybind,.8,.8,.8)end
            if (not button.customItem or button.customParty) and button.buffUnit then
                local name,surname=UnitName(button.buffUnit)
                if public(name) and type(name)=="string" and name~="" then
                    if public(surname) and type(surname)=="string" and surname~="" then
                        name=NameUtil and NameUtil.GetFullNameWithoutRealm
                            and NameUtil.GetFullNameWithoutRealm(name,surname) or (name.." "..surname)
                    end
                    GameTooltip:AddLine("Target: " .. name, .8, .8, .8)
                end
            end
            if button.poison then
                GameTooltip:AddLine((button.weaponSlot==17 and "Off hand" or "Main hand").." poison. "..self:CustomItemCount(button.customItem).." carried.",.8,.8,.8)
                GameTooltip:AddLine(button.itemMissing and "No poison carried. Craft or buy more before applying." or "Left-click to coat the selected weapon. Existing poison is preserved until it expires or runs out of charges.",.8,.8,.8,true)
            elseif button.customItem then
                local data=F:CustomItemData(button.customItem,button.buffUnit)
                GameTooltip:AddLine(not data.usable and data.status or (data.count==0 and "Not carried." or
                    (button.customParty and "Left-click to use on this unit." or "Left-click to use from your bags.")),.8,.8,.8)
                if data.usable and data.count>0 then GameTooltip:AddLine(data.status,.8,.8,.8) end
            end
            if InCombatLockdown() and not F.db.combatClicks then
                GameTooltip:AddLine("Casting disabled in combat.", .8, .8, .8)
            elseif button.outOfRange then
                GameTooltip:AddLine("Out of range.", 1, .4, .2)
            elseif button.customItem then
                                                            
            elseif button.isCreation then
                GameTooltip:AddLine("Left-click to create this item. Reagents may be required.", .85, .85, .85)
                if button.onDemand then
                    GameTooltip:AddLine("Outside combat, this icon changes to item use after creation. During combat it keeps its prepared creation action.", .8, .8, .8, true)
                end
            elseif button.weaponItem then
                GameTooltip:AddLine("Left-click to apply to your main-hand weapon.", .85, .85, .85)
            elseif button.consumeItem then
                GameTooltip:AddLine("Left-click to use this item.", .85, .85, .85)
            else
                GameTooltip:AddLine(button.combatOnly and "Left-click to cast this ability."or "Left-click to apply this buff.", .85, .85, .85)
            end
            local entry=F.spells[button.buffKey]
            if entry and entry.singleRecipient then GameTooltip:AddLine("Choose this recipient. Your active Oath is preserved until it ends; this spell has no cooldown.",.8,.8,.8,true) end
            if entry and entry.cooldownLimited then GameTooltip:AddLine("Available on eligible frames while ready; hidden everywhere during its cooldown.",.8,.8,.8,true) end
            if button.buffKey == "soul" and not button.isCreation then
                GameTooltip:AddLine("Uses a Soulstone already in your bags.", .8, .8, .8)
            end
            GameTooltip:Show()
        end)
        square:SetScript("OnLeave", function() GameTooltip:Hide() end)
        square:SetScript("OnHide", function(button)
            if GameTooltip:GetOwner() == button then GameTooltip:Hide() end
        end)
        square.visual = CreateFrame("Frame", nil, square)
        square.visual:SetAllPoints()
        square.texture = square.visual:CreateTexture(nil, "BACKGROUND")
        square.texture:SetAllPoints()
        self:CreateIconOverlay(square)
        self:CreateItemSlash(square)
        self:CreateCastFeedbackVisual(square)
        self:CreateCombatCooldown(square)
        self:UpdateDispelReminder(square)
        square:SetScript("PreClick",function(button,mouseButton,down) F:BeginIconCast(button,mouseButton,down) end)
        square:SetScript("PostClick",function(button,mouseButton,down) F:EndIconCast(button,mouseButton,down) end)
        indicators.squares[i] = square
    end
end
function F:Attach(frame, kind)
    if kind==true then kind="raidParty" end
    local compact=kind=="raidParty" or kind=="raid"
    if self.overlays[frame] then
        if kind then self.overlays[frame].frameKind=kind; self.overlays[frame].compact=compact end
        return
    end
    local indicators = CreateFrame("Frame", nil, frame)
    indicators:SetPoint("LEFT", frame, "RIGHT", 3, 0)
    indicators:SetSize(1, 1)
    indicators.squares = {}
    self:EnsureIndicators(frame,indicators,self:IndicatorCapacity(frame))
                                                                          
                                                                           
    local click = CreateFrame("Button", nil, frame, "SecureActionButtonTemplate,SecureHandlerStateTemplate")
    click:SetAllPoints(frame)
    click:SetFrameLevel(frame:GetFrameLevel() + 20)
    click:RegisterForClicks("AnyUp", "AnyDown")
    click:SetAttribute("useOnKeyDown", false)
    click:SetAttribute("checkselfcast", false)
    click:SetAttribute("checkfocuscast", false)
                                                                      
                                                                       
    click:SetAttribute("_onstate-combat", [[
        for i = 1, 3 do
            local modifier = i == 1 and "shift" or (i == 2 and "ctrl" or "alt")
            for j = 1, 4 do
                local key = j == 1 and "type1" or (j == 2 and "spell1" or (j == 3 and "item1" or "macrotext1"))
                local attribute = modifier .. "-" .. key
                if newstate == "combat" then
                    local profile = self:GetAttribute("dual-profile") and ((self:GetAttribute("state-relation") or "enemy") .. "-") or ""
                    self:SetAttribute(attribute, self:GetAttribute("combat-" .. profile .. attribute) or (key == "type1" and "" or nil))
                else
                    self:SetAttribute(attribute, self:GetAttribute("safe-" .. attribute))
                end
            end
        end
    ]])
    click:SetAttribute('_onstate-relation',[[
        if self:GetAttribute('state-combat') == 'combat' and self:GetAttribute('dual-profile') then
            for i = 1, 3 do
                local modifier = i == 1 and 'shift' or (i == 2 and 'ctrl' or 'alt')
                for j = 1, 4 do
                    local key = j == 1 and 'type1' or (j == 2 and 'spell1' or (j == 3 and 'item1' or 'macrotext1'))
                    local attribute = modifier .. '-' .. key
                    self:SetAttribute(attribute, self:GetAttribute('combat-' .. newstate .. '-' .. attribute) or (key == 'type1' and '' or nil))
                end
            end
        end
    ]])
    RegisterStateDriver(click, "combat", "[combat] combat; safe")
    click:SetScript("PreClick",function(button,mouse,down)F:BeginFrameCombatCast(button,mouse,down)end)
    click:SetScript("PostClick",function(button,mouse,down)F:EndFrameCombatCast(button,mouse,down)end)
    self.overlays[frame] = { indicators = indicators, click = click, compact = compact, frameKind=kind or "party" }
end
function F:Discover()
    local function consider(frame, kind)
        if not frame or frame:IsForbidden() then return end
        local unit=frame.unit or frame:GetAttribute("unit")
        if public(unit) and not self:IsGroupPreviewFrame(kind,unit) then self:Attach(frame, kind) end
    end
    consider(PlayerFrame,"self")
    consider(TargetFrame,"target")
    consider(FocusFrame,"focus")
    if CompactPartyFrame and CompactPartyFrame.memberUnitFrames then
        for _, member in ipairs(CompactPartyFrame.memberUnitFrames) do consider(member, "raidParty") end
    end
    for i = 1, 4 do
        consider(_G["PartyMemberFrame" .. i],"party")
        if PartyFrame then consider(PartyFrame["MemberFrame" .. i],"party") end
    end
    for i = 1, 5 do consider(_G["CompactPartyFrameMember" .. i], "raidParty") end
    for i = 1, 40 do consider(_G["CompactRaidFrame" .. i], "raid") end
    for group = 1, 8 do
        local raidGroup = _G["CompactRaidGroup" .. group]
        if raidGroup and raidGroup.memberUnitFrames then
            for _, member in ipairs(raidGroup.memberUnitFrames) do consider(member, "raid") end
        end
        for member = 1, 5 do consider(_G["CompactRaidGroup" .. group .. "Member" .. member], "raid") end
    end
end
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, name, success, spellID)
    if event=="UNIT_PET" and (not public(name) or name~="player") then return end
    local perf=F.perfRecording and F:BeginPerfTransition(event)
    local cooldownEvent=event=="SPELL_UPDATE_COOLDOWN"or event=="SPELL_UPDATE_CHARGES"or event=="BAG_UPDATE_COOLDOWN"or event=="PET_BAR_UPDATE_COOLDOWN"or event=="UNIT_PET"or event=="PLAYER_REGEN_DISABLED"or event=="PLAYER_REGEN_ENABLED"
    if cooldownEvent then F.cooldownGeneration=(F.cooldownGeneration or 0)+1 end
    if event=="UNIT_SPELLCAST_SUCCEEDED" then F:RecordSingleRecipientCast(name,spellID) end
    if event=="SPELLS_CHANGED" then
        F.spellCacheDirty=true;F.combatBookDirty=true
        if F.perfRecording then
            F:NotePerfCacheInvalidation("spellbook",event)
            F:NotePerfCacheInvalidation("combatBook",event)
        end
    end
    if event=="PET_BAR_UPDATE" or event=="UNIT_PET" then F.petBookDirty=event end
    if event=="UNIT_INVENTORY_CHANGED" and (not public(name) or name~="player") then return end
    if event=="GET_ITEM_INFO_RECEIVED" and F.itemRequests then F.itemRequests[name]=success and "loaded" or "failed" end
    if event == "ADDON_LOADED" then
        F:NoteAddonLoaded(name)
        if name ~= "BuffRag" then
            if F.db then F:CheckAddonConflicts() end
            return
        end
        local _, class = UnitClass("player")
        F.class = class
        BuffRagDB = F:UpgradeSettings(BuffRagDB or {})
        BuffRagDB.enabled = true                                                      
        BuffRagDB.healthstoneLimit = nil                                               
                                                                                 
        if BuffRagDB.selfSize == nil then BuffRagDB.selfSize = BuffRagDB.size end
        if BuffRagDB.selfOffset == nil then BuffRagDB.selfOffset = BuffRagDB.offset end
        F.db = BuffRagDB
        for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "UNIT_AURA",
            "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "UNIT_HEALTH", "UNIT_FLAGS", "UNIT_CONNECTION", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
            "SPELLS_CHANGED", "BAG_UPDATE_DELAYED", "SPELL_UPDATE_COOLDOWN",
            "MINIMAP_UPDATE_TRACKING", "PLAYER_ROLES_ASSIGNED", "GET_ITEM_INFO_RECEIVED", "UNIT_INVENTORY_CHANGED", "WEAPON_ENCHANT_CHANGED", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_PET", "PET_BAR_UPDATE", "PET_BAR_UPDATE_COOLDOWN", "UNIT_SPELLCAST_SUCCEEDED", "SPELL_UPDATE_CHARGES", "BAG_UPDATE_COOLDOWN", "UPDATE_BINDINGS" }) do pcall(events.RegisterEvent,events,e) end
        C_Timer.NewTicker(0.2, function() F:UpdateRange() end)
        F:CreateOptions()
        F:CreateLauncher()
        F:Print("v" .. F.version .. " loaded. /brag for settings and frame-click modifiers.")
        C_Timer.After(0,function() F:CheckAddonConflicts() end)
    end
    if event=="PLAYER_LOGIN" or event=="PLAYER_ENTERING_WORLD" then
        F.spellCacheDirty=true;F.combatBookDirty=true
        F:CheckAddonConflicts()
        C_Timer.After(1,function() F:CheckAddonConflicts();if not InCombatLockdown() then F:RequestRefresh("Login follow-up") end end)
        C_Timer.After(3,function() F:CheckAddonConflicts() end)
    elseif event=="PLAYER_REGEN_ENABLED" then
        F:CheckAddonConflicts()
    end
    if event == "PLAYER_REGEN_DISABLED" then
        if F.testUI then F:SetTestUI(false) end                                                 
        F:DeferAddonConflictPrompt()
        F.awaitingOptionsDecision = false
        if F.savePrompt then F.savePrompt:Hide() end
        if F.perfReportWindow then F.perfReportWindow:Hide() end
                                                                                 
        GameTooltip:Hide()
    end
    if InCombatLockdown() then
        if event=='UNIT_AURA' and public(name) and name then F:InvalidateDispelSnapshots(name)
        elseif event=='PLAYER_REGEN_DISABLED' or event=='PLAYER_TARGET_CHANGED' or event=='PLAYER_FOCUS_CHANGED' or event=='GROUP_ROSTER_UPDATE' then F:InvalidateDispelSnapshots() end
        if perf then F:EndPerfTransition(event,perf) end
        return
    end
    if perf then F:EndPerfTransition(event,perf) end
    if event=="UNIT_HEALTH" then
        if not F:RefreshUnitStateChanged(name,true) then return end
    elseif event=="UNIT_FLAGS" or event=="UNIT_CONNECTION" then
        local changed=F:RefreshUnitStateChanged(name)
        if not changed and event=="UNIT_FLAGS" and public(name) and name=="player" then
            changed=F:RefreshUnitStateChanged("target") or F:RefreshUnitStateChanged("focus")
        end
        if not changed then return end
    end
    F:RequestRefresh(event)
end)
BINDING_HEADER_BUFFRAG = "Buff Rag"
_G["BINDING_NAME_CLICK BuffRagActivateButton:LeftButton"] = "Activate Buff Rag (Buffs order)"
