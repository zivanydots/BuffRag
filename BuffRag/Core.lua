local _, F = ...
BuffRag = F
F.version = "0.1.21"
F.maxIndicators = 15
F.defaults = {
    enabled=true,size=20,selfSize=20,spacing=3,offset=31,selfOffset=15,
    itemsEnabled=true,items={},iconVertical=0,selfIconVertical=0,
    windowScale=.85,combatClicks=true,combatOpacity=60,frameModifier="shift",minimapEnabled=true,
    healthstoneHealth=25,
    placement="right",selfPlacement="right",topAlign="right",selfTopAlign="right",vertical=3,selfVertical=3,
    raidPartyPlacement="right",raidPartySize=20,raidPartyOffset=31,raidPartyIconVertical=0,raidPartyTopAlign="right",raidPartyVertical=3,
    raidPlacement="right",raidSize=20,raidOffset=31,raidIconVertical=0,raidTopAlign="right",raidVertical=3,
    targetPlacement="right",targetSize=20,targetOffset=31,targetIconVertical=0,targetTopAlign="right",targetVertical=3,
}
F.overlays = {}
local function public(value) return not (issecretvalue and issecretvalue(value)) end
function F:IsSelf(unit)
    if not public(unit) or not unit then return false end
    if unit == "player" then return true end
    local same = UnitIsUnit(unit, "player")
    -- Unit comparisons can be restricted in instances, including between
    -- range ticks. Never branch on an opaque result or treat it as self.
    return public(same) and (same==true or same==1) or false
end
local defaults
function F:ResetDefaults()
    if InCombatLockdown() then return end
    local settings = {}
    defaults(settings, self.defaults)
    settings.selfSize = settings.size
    if not self.editingOptions then BuffRagDB = settings end
    self.db = settings
    if self.options then
        self.options:ClearAllPoints(); self.options:SetPoint("CENTER")
        if self.options.SyncFields then self.options:SyncFields() end
    end
    self:Refresh()
    self:Print(self.editingOptions and "Default settings previewed. Click Save to keep them." or "Default settings restored.")
end
function F:CarriedStone(kind)
    for _, id in ipairs(self.stoneTypes[kind].items) do
        if C_Item.GetItemCount(id) > 0 then return id end
    end
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
    -- Stage opacity composes with range/combat and opaque health alpha.
    square.texture:SetAlpha(creation and .75 or 1)
    square.text:SetText(creation and "+" or "")
end
function F:ItemReady(id)
    local start,duration,enabled=C_Item.GetItemCooldown(id)
    return public(start) and public(duration) and public(enabled)
        and (enabled == true or enabled == 1)
        and (start == 0 or start + duration <= GetTime())
end
function F:HealthstoneRecommended()
    if InCombatLockdown() or not self.db.buffs.health then return false end
    local health, maximum = UnitHealth("player"), UnitHealthMax("player")
    if not public(health) or not public(maximum) or maximum <= 0 then return false end
    return health * 100 / maximum < self.db.healthstoneHealth
end
function F:HealthstoneAlpha()
    if not self.db.buffs.health then return 0 end
    if UnitHealthPercent and C_CurveUtil and C_CurveUtil.CreateCurve and Enum
        and Enum.LuaCurveType and Enum.LuaCurveType.Step then
        if not self.healthCurve or self.healthCurveThreshold ~= self.db.healthstoneHealth then
            local curve = C_CurveUtil.CreateCurve()
            curve:SetType(Enum.LuaCurveType.Step)
            curve:AddPoint(0, 1)
            curve:AddPoint(self.db.healthstoneHealth / 100, 0)
            if self.db.healthstoneHealth < 100 then curve:AddPoint(1, 0) end
            self.healthCurve, self.healthCurveThreshold = curve, self.db.healthstoneHealth
        end
        -- This result may be secret. Pass it directly to the display API;
        -- never inspect it to choose or change a protected action.
        return UnitHealthPercent("player", false, self.healthCurve)
    end
    return self:HealthstoneRecommended() and 1 or 0
end
function F:SetAction(button, prefix, action)
    for _, key in ipairs({"type", "spell", "item", "macrotext"}) do
        button:SetAttribute(prefix .. key .. "1", key == "type" and "" or nil)
    end
    if not action then return end
    button:SetAttribute(prefix .. "type1", action.type)
    if action.spell then button:SetAttribute(prefix .. "spell1", action.spell) end
    if action.item then button:SetAttribute(prefix .. "item1", action.item) end
    if action.macrotext then button:SetAttribute(prefix .. "macrotext1", action.macrotext) end
end
function F:UpdateActivation()
    if not self.activate then
        local button = CreateFrame("Button", "BuffRagActivateButton", UIParent,
            "SecureActionButtonTemplate,SecureHandlerStateTemplate")
        button:SetSize(1,1); button:SetPoint("TOPLEFT"); button:SetAlpha(0); button:EnableMouse(false)
        -- Native CLICK bindings deliver a key-down event. Execute exactly
        -- that edge instead of relying on a key-up callback being delivered.
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
defaults = function(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            defaults(target[key], value)
        elseif target[key] == nil then target[key] = value end
    end
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
    if not unit or not (unit == "player" or unit == "target" or unit:match("^party%d+$") or unit:match("^raid%d+$")) then return end
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
    -- A remote unit can yield nil for spell range; group range is a fallback.
    if UnitInRange then
        local inRange, checked = UnitInRange(unit)
        if public(inRange) and public(checked) and checked and not inRange then return false end
    end
end
function F:UpdateRange()
    if not self.db then return end
    for _, overlay in pairs(self.overlays) do
        for _, button in ipairs(overlay.indicators.squares) do
            if button:IsShown() and button.buffUnit then
                local inRange = self:RangeStatus(button.buffUnit, button.buffSpellID, button.rangeItem)
                button.outOfRange = inRange == false
                -- nil/secret means unknown, not out of range.
                local out = public(inRange) and inRange == false
                if button.customItem then self:UpdateCustomItemVisual(button) end
                if button.healthstoneReminder then
                    if button.isCreation and InCombatLockdown() then
                        button.visual:SetAlpha(0) -- no ready Healthstone to use in combat
                    else
                        button.visual:SetAlpha(self:HealthstoneAlpha())
                    end
                else
                    button.visual:SetAlpha(out and 0.5 or 1)
                end
                if not InCombatLockdown() then
                    button:SetAttribute("type1", out and "" or (button:GetAttribute("buff-action") or ""))
                end
            end
        end
    end
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
        -- Combat uses the actions assigned out of combat; never retarget or
        -- rebuild protected buttons during combat.
        square:SetAttribute("_onstate-combat", [[
            if newstate == "combat" then
                if self:GetAttribute("combat-clicks") then
                    self:SetAttribute("type1", self:GetAttribute("buff-action") or "")
                else
                    self:SetAttribute("type1", "")
                end
                self:SetAlpha(self:GetAttribute("combat-alpha") or 0.6)
            else
                self:SetAttribute("type1", self:GetAttribute("buff-action") or "")
                self:SetAlpha(1)
            end
        ]])
        RegisterStateDriver(square, "combat", "[combat] combat; safe")
        square:SetScript("OnEnter", function(button)
            if button.castFeedbackState=="failed" then self:ClearIconFeedback(button) end
            if not button.buffName then return end
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText(button.buffName, 1, 1, 1)
            local target = (not button.customItem or button.customParty) and button.buffUnit and UnitName(button.buffUnit)
            if public(target) and target then GameTooltip:AddLine("Target: " .. target, .8, .8, .8) end
            if button.poison then
                GameTooltip:AddLine((button.weaponSlot==17 and "Off hand" or "Main hand").." poison. "..self:CustomItemCount(button.customItem).." carried.",.8,.8,.8)
                GameTooltip:AddLine(button.itemMissing and "No poison carried. Craft or buy more before applying." or "Left-click to coat the selected weapon. Existing poison is preserved until it expires or runs out of charges.",.8,.8,.8,true)
            elseif button.customItem then
                local data=F:CustomItemData(button.customItem,button.buffUnit)
                GameTooltip:AddLine(not data.usable and data.status or (data.count==0 and "Not carried." or
                    (button.customParty and "Left-click to use on this party / raid member." or "Left-click to use from your bags.")),.8,.8,.8)
                if data.usable and data.count>0 then GameTooltip:AddLine(data.status,.8,.8,.8) end
            end
            if InCombatLockdown() and (button.isCreation or not F.db.combatClicks) then
                GameTooltip:AddLine(button.isCreation and "Create items before combat." or "Casting disabled in combat.", .8, .8, .8)
            elseif button.outOfRange then
                GameTooltip:AddLine("Out of range or in another zone.", 1, .4, .2)
            elseif button.customItem then
                -- Custom-item instructions are shown above.
            elseif button.isCreation then
                GameTooltip:AddLine("Left-click to create this item. Reagents may be required.", .85, .85, .85)
                if button.onDemand then
                    GameTooltip:AddLine("Once created, click this icon again to use it. Prepare stones before combat.", .8, .8, .8, true)
                end
            elseif button.weaponItem then
                GameTooltip:AddLine("Left-click to apply to your main-hand weapon.", .85, .85, .85)
            elseif button.consumeItem then
                GameTooltip:AddLine(button.buffKey=="health" and "Left-click to consume your Healthstone." or "Left-click to use this conjured item.", .85, .85, .85)
            else
                GameTooltip:AddLine("Left-click to apply this buff.", .85, .85, .85)
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
        square.text = square.visual:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        square.text:SetPoint("CENTER")
        square.text:SetTextColor(1, 1, 1)
        self:CreateItemSlash(square)
        self:CreateCastFeedbackVisual(square)
        square:SetScript("PreClick",function(button,mouseButton,down) F:BeginIconCast(button,mouseButton,down) end)
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
    if kind=="target" then
        RegisterStateDriver(indicators,"visibility","[combat] hide; [@target,exists,help,nodead] show; hide")
    end
    self:EnsureIndicators(frame,indicators,self:IndicatorCapacity(frame))
    -- Modifier layer is out of combat only. Secure state changes clear all
    -- actions during combat so no stale Healthstone bypasses its threshold.
    local click = CreateFrame("Button", nil, frame, "SecureActionButtonTemplate,SecureHandlerStateTemplate")
    click:SetAllPoints(frame)
    click:SetFrameLevel(frame:GetFrameLevel() + 20)
    click:RegisterForClicks("AnyUp", "AnyDown")
    click:SetAttribute("useOnKeyDown", false)
    click:SetAttribute("checkselfcast", false)
    click:SetAttribute("checkfocuscast", false)
    -- Restricted snippets reject literal tables, even as loop inputs.
    -- Use numeric loops and scalar names instead of allocating tables.
    click:SetAttribute("_onstate-combat", [[
        for i = 1, 3 do
            local modifier = i == 1 and "shift" or (i == 2 and "ctrl" or "alt")
            for j = 1, 4 do
                local key = j == 1 and "type1" or (j == 2 and "spell1" or (j == 3 and "item1" or "macrotext1"))
                local attribute = modifier .. "-" .. key
                if newstate == "combat" then
                    self:SetAttribute(attribute, key == "type1" and "" or nil)
                else
                    self:SetAttribute(attribute, self:GetAttribute("safe-" .. attribute))
                end
            end
        end
    ]])
    RegisterStateDriver(click, "combat", "[combat] combat; safe")
    self.overlays[frame] = { indicators = indicators, click = click, compact = compact, frameKind=kind or "party" }
end
function F:Discover()
    local function consider(frame, kind)
        if frame and not frame:IsForbidden() then self:Attach(frame, kind) end
    end
    consider(PlayerFrame,"self")
    consider(TargetFrame,"target")
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
    if event=="UNIT_SPELLCAST_SUCCEEDED" then F:RecordSingleRecipientCast(name,spellID) end
    if event=="SPELLS_CHANGED" then F.spellCacheDirty=true end
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
        BuffRagDB.enabled = true -- disabling is now handled by the game's AddOns menu
        BuffRagDB.healthstoneLimit = nil -- superseded by the single Healthstone toggle
        -- Preserve the existing self appearance when upgrading to split layouts.
        if BuffRagDB.selfSize == nil then BuffRagDB.selfSize = BuffRagDB.size end
        if BuffRagDB.selfOffset == nil then BuffRagDB.selfOffset = BuffRagDB.offset end
        F.db = BuffRagDB
        for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "UNIT_AURA",
            "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "SPELLS_CHANGED", "BAG_UPDATE_DELAYED", "SPELL_UPDATE_COOLDOWN",
            "MINIMAP_UPDATE_TRACKING", "PLAYER_ROLES_ASSIGNED", "GET_ITEM_INFO_RECEIVED", "UNIT_INVENTORY_CHANGED", "WEAPON_ENCHANT_CHANGED", "PLAYER_TARGET_CHANGED", "UNIT_SPELLCAST_SUCCEEDED" }) do pcall(events.RegisterEvent,events,e) end
        C_Timer.NewTicker(1, function() F:Refresh() end)
        C_Timer.NewTicker(0.2, function() F:UpdateRange() end)
        F:CreateOptions()
        F:CreateLauncher()
        F:Print("v" .. F.version .. " loaded. /brag for settings and frame-click modifiers.")
        C_Timer.After(0,function() F:CheckAddonConflicts() end)
    end
    if event=="PLAYER_LOGIN" or event=="PLAYER_ENTERING_WORLD" then
        F:CheckAddonConflicts()
        C_Timer.After(1,function() F:CheckAddonConflicts() end)
        C_Timer.After(3,function() F:CheckAddonConflicts() end)
    elseif event=="PLAYER_REGEN_ENABLED" then F:CheckAddonConflicts() end
    if event == "PLAYER_REGEN_DISABLED" then
        F:DeferAddonConflictPrompt()
        F.awaitingOptionsDecision = false
        if F.savePrompt then F.savePrompt:Hide() end
        -- The protected options parent closes through its secure combat handler.
        GameTooltip:Hide()
    end
    F:Refresh()
end)
BINDING_HEADER_BUFFRAG = "Buff Rag"
_G["BINDING_NAME_CLICK BuffRagActivateButton:LeftButton"] = "Activate Buff Rag (Buffs order)"
