local _, F = ...
local function public(value) return not (issecretvalue and issecretvalue(value)) end
local function castID(value)
    if not public(value) then return false end
    return (type(value)=="string" and value~="")
        or (type(value)=="number" and value>0 and value<math.huge and value==math.floor(value))
end

-- All regions are created outside combat. Results change artwork only, never
-- the protected button's visibility, position, unit or action attributes.
function F:CreateCastFeedbackVisual(button)
    local layer=CreateFrame("Frame",nil,button)
    layer:SetAllPoints(button); layer:SetFrameLevel(button:GetFrameLevel()+3)
    local mark=layer:CreateTexture(nil,"OVERLAY"); mark:SetAllPoints(layer); mark:SetAlpha(0)
    local question=layer:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    question:SetPoint("CENTER"); question:SetText("?"); question:SetTextColor(1,.82,0); question:SetAlpha(0)
    question:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",18,"OUTLINE")
    button.castFeedbackMark,button.castFeedbackQuestion=mark,question
    layer:SetScript("OnUpdate",function()
        if not button.feedbackFadeStart then return end
        local alpha=math.max(0,1-(GetTime()-button.feedbackFadeStart)/button.feedbackFadeDuration)
        if button.castFeedbackState=="success"or button.castFeedbackState=="failed"then mark:SetAlpha(alpha)else question:SetAlpha(alpha)end
        if alpha==0 then button.feedbackFadeStart=nil end
    end)
end

function F:SetIconFeedback(button,state)
    button.castFeedbackState=state
    local mark,question=button.castFeedbackMark,button.castFeedbackQuestion
    if not mark then return end
    button.feedbackFadeStart=nil
    if not button.feedbackExample and (not self.db or not self.db.combatFeedback)then mark:SetAlpha(0);question:SetAlpha(0);return end
    if state=="success" or state=="failed" then
        mark:SetTexture(state=="success" and "Interface\\RaidFrame\\ReadyCheck-Ready" or "Interface\\RaidFrame\\ReadyCheck-NotReady")
        mark:SetAlpha(1); question:SetAlpha(0)
    else
        mark:SetAlpha(0); question:SetAlpha((state=="pending" or state=="unknown") and 1 or 0)
    end
    if state and not button.feedbackExample then button.feedbackFadeStart=GetTime();button.feedbackFadeDuration=self:GCDSeconds()end
end

function F:ClearIconFeedback(button)
    local attempt=button.castFeedbackAttempt
    if attempt then
        if not attempt.finished and attempt.outcome=="pending" then
            attempt.outcome="unknown"
            attempt.matchReason=attempt.matchReason or "Click cleared before matching cast confirmation."
        end
        attempt.finished=true
        if self.feedbackClickWindow==attempt then self.feedbackClickWindow=nil end
        if attempt.guid and self.feedbackByCast then self.feedbackByCast[attempt.guid]=nil end
    end
    button.castFeedbackAttempt=nil
    button.activeCastGUID=nil;button.activeChannel=nil
    if self.feedbackAttempts then self.feedbackAttempts[button]=nil end
    self:SetIconFeedback(button,nil)
end

function F:ResolveCastFeedbackIDs(candidate)
    local ids={}
    local function add(id)
        if public(id) and type(id)=="number" and id>0 and id<math.huge and id==math.floor(id) then ids[id]=true; return true end
    end
    local function spell(id)
        if not add(id) then return end
        -- Event IDs can use the client's base/override identity. Resolve these
        -- through native metadata rather than guessing from every aura/rank.
        for _,resolver in ipairs({C_Spell.GetBaseSpell or false,C_Spell.GetOverrideSpell or false}) do
            if resolver then local ok,alias=pcall(resolver,id); if ok then add(alias) end end
        end
        if C_Spell.GetSpellInfo then
            local ok,info=pcall(C_Spell.GetSpellInfo,id)
            if ok and public(info) and type(info)=="table" then add(info.spellID) end
        end
    end
    if candidate.spellID then spell(candidate.spellID)
    elseif candidate.itemID and C_Item.GetItemSpell then
        local ok,effect,id=pcall(C_Item.GetItemSpell,candidate.itemID)
        if ok then
            spell(id)
            if public(effect) and type(effect)=="table" then spell(effect.spellID); spell(effect.spellId)
            elseif public(effect) and type(effect)=="number" then spell(effect) end
        end
    end
    local entry=self.spells[candidate.key]
    if not next(ids) and candidate.itemID then
        if not InCombatLockdown() and C_Item.RequestLoadItemDataByID then
            self.feedbackItemRequests=self.feedbackItemRequests or {}
            if not self.feedbackItemRequests[candidate.itemID] then
                self.feedbackItemRequests[candidate.itemID]=true
                pcall(C_Item.RequestLoadItemDataByID,candidate.itemID)
            end
        end
        if entry and entry.stone=="soul" and not candidate.creation then
            for _,id in ipairs(entry.auraIDs or {}) do spell(id) end
        end
    end
    return ids
end

function F:PrepareCastFeedback(button,candidate,allowed)
    self:ClearIconFeedback(button)
    button.castFeedbackAllowed=allowed
    button.cooldownGeneration=nil
    button.castFeedbackSource={key=candidate.key,spellID=candidate.spellID,itemID=candidate.itemID,creation=candidate.creation,pet=candidate.pet}
    local ids=self:ResolveCastFeedbackIDs(button.castFeedbackSource)
    button.castFeedbackIDs=ids
end

function F:BeginIconCast(button,mouseButton,down)
    if not public(mouseButton) or mouseButton~="LeftButton" or not public(down) or down then return end
    if (not InCombatLockdown()and not button.cleanupOnly)or self.testUI or not self.db or not self.db.combatClicks or not button.castFeedbackAllowed then return end
    self:ClearIconFeedback(button)
    self.cooldownGeneration=(self.cooldownGeneration or 0)+1
    -- An item may finish loading after the combat snapshot. Refresh feedback
    -- metadata only; the protected spell/item action remains untouched.
    if button.castFeedbackSource then button.castFeedbackIDs=self:ResolveCastFeedbackIDs(button.castFeedbackSource) end
    local attempt={actor=button.pet and "pet"or "player",button=button,clicked=GetTime(),name=button.buffName or "spell/item",outcome="pending",events={},ids=button.castFeedbackIDs or {}}
    local expected={}
    for id in pairs(button.castFeedbackIDs or {}) do expected[#expected+1]=tostring(id) end
    table.sort(expected); attempt.expected=table.concat(expected,", ")
    local source=button.castFeedbackSource or {}
    attempt.source=source.itemID and ("Use item #"..source.itemID) or ((source.creation and "Create spell #" or "Cast spell #")..tostring(source.spellID or "unavailable"))
    self.feedbackClickWindow=attempt
    self.feedbackLastAttempt=attempt
    button.castFeedbackAttempt=attempt
    self.feedbackAttempts=self.feedbackAttempts or {}; self.feedbackAttempts[button]=attempt
    self:SetIconFeedback(button,"pending")
    -- Missing/secret events are not failures. Keep an honest unconfirmed mark.
    C_Timer.After(20,function()
        if not attempt.finished and button.castFeedbackAttempt==attempt then
            attempt.finished=true
            attempt.outcome="unknown"
            if F.feedbackClickWindow==attempt then F.feedbackClickWindow=nil end
            if attempt.guid and F.feedbackByCast then F.feedbackByCast[attempt.guid]=nil end
            F.feedbackAttempts[button]=nil; F:SetIconFeedback(button,"unknown")
        end
    end)
end

function F:EndIconCast(button,mouseButton,down)
    if not public(mouseButton) or mouseButton~="LeftButton" or not public(down) or down then return end
    if self.feedbackClickWindow and self.feedbackClickWindow.button==button then self.feedbackClickWindow=nil end
end

local function availability(value)
    if not public(value) then return "restricted" end
    if value==nil or value=="" then return "missing" end
    return "available"
end

function F:ReportCastFeedback()
    local attempt=self.feedbackLastAttempt
    if not attempt then self:Print("No combat icon click has been recorded this session."); return end
    self:Print("v"..self.version.." last combat icon: "..attempt.name.."; result: "..attempt.outcome..".")
    self:Print("Expected spell IDs: "..(attempt.expected~="" and attempt.expected or "item effect unavailable")..".")
    self:Print("Action: "..attempt.source..".")
    if attempt.matchReason then self:Print("Matching: "..attempt.matchReason) end
    for _,message in ipairs(attempt.events) do self:Print(message) end
    if #attempt.events==0 then self:Print("No cast events were observed for this click.") end
end

function F:CastFeedbackEvent(event,unit,arg2,arg3,arg4)
    if event=="PLAYER_REGEN_ENABLED" then
        for _,overlay in pairs(self.overlays) do
            for _,button in ipairs(overlay.indicators.squares) do self:ClearIconFeedback(button) end
        end
        self.feedbackAttempts,self.feedbackByCast={},{}
        return
    end
    local last=self.feedbackLastAttempt
    if last and not last.finished and #last.events<10 and (not public(unit) or unit==(last.actor or "player")) then
        local sent=event=="UNIT_SPELLCAST_SENT"
        local guid,id
        if sent then guid,id=arg3,arg4 else guid,id=arg2,arg3 end
        local spell=public(id) and type(id)=="number" and tostring(id) or availability(id)
        local unitInfo=public(unit) and type(unit)=="string" and unit or availability(unit)
        local guidInfo=availability(guid)..(public(guid) and (" ("..type(guid)..")") or "")
        last.events[#last.events+1]=string.format("+%.3fs ",GetTime()-last.clicked)..event..": unit="..unitInfo..", cast ID="..guidInfo..", spell="..spell..(sent and (", recipient="..availability(arg2)) or "")
    end
    if not public(unit)or(unit~="player"and unit~="pet")or(not InCombatLockdown()and not(last and last.button.cleanupOnly))then return end
    if event=="UNIT_SPELLCAST_START"or event=="UNIT_SPELLCAST_CHANNEL_START"or event=="UNIT_SPELLCAST_STOP"or event=="UNIT_SPELLCAST_CHANNEL_STOP"then
        if last and (last.actor or "player")==unit and castID(arg2)and last.guid==arg2 and public(arg3)and last.ids[arg3]then
            local start=event=="UNIT_SPELLCAST_START"or event=="UNIT_SPELLCAST_CHANNEL_START"
            last.button.activeCastGUID=start and arg2 or nil
            last.button.activeChannel=event=="UNIT_SPELLCAST_CHANNEL_START"
            self.cooldownGeneration=(self.cooldownGeneration or 0)+1
            self:UpdateCombatCooldown(last.button)
        end
        return
    end
    if event=="UNIT_SPELLCAST_SENT" then
        local target,guid,id=arg2,arg3,arg4
        if not castID(guid) or not public(id) or type(id)~="number" then
            if last and not last.finished then last.matchReason="SENT has no usable public cast/spell identity." end
            return
        end
        local current=self.feedbackClickWindow
        if current and GetTime()-current.clicked>.1 then current=nil end
        if current and (current.actor or "player")==unit and current.ids[id] then current.sentObserved=true end
        -- The completed player cast is what the marker confirms. Recipient
        -- names can be aliases, qualified differently or restricted, so they
        -- must not veto a public matching spell/cast ID from the click.
        local match
        for button,attempt in pairs(self.feedbackAttempts or {}) do
            if (attempt.actor or "player")==unit and not attempt.finished and not attempt.guid and GetTime()-attempt.clicked<=1
                and attempt.ids[id] then
                if match then
                    match.matchReason="More than one pending click matches this spell; result is ambiguous."
                    attempt.matchReason=match.matchReason
                    return
                end
                match=attempt
            end
        end
        if match then
            match.guid,match.spellID=guid,id
            match.matchReason="Player SENT matched the expected spell; awaiting its cast ID result."
            self.feedbackByCast=self.feedbackByCast or {}; self.feedbackByCast[guid]=match
        elseif last and not last.finished then
            last.matchReason="SENT did not match a pending expected spell within the click window."
        end
        return
    end
    if event~="UNIT_SPELLCAST_SUCCEEDED" and event~="UNIT_SPELLCAST_FAILED" and event~="UNIT_SPELLCAST_FAILED_QUIET" and event~="UNIT_SPELLCAST_INTERRUPTED" then return end
    local guid,id=arg2,arg3
    if not public(id) or type(id)~="number" then
        if last and not last.finished then last.matchReason="Result spell identity is unavailable or restricted." end
        return
    end
    local readableGUID=castID(guid)
    local attempt=readableGUID and self.feedbackByCast and self.feedbackByCast[guid]
    -- Instant casts can finish inside this button's secure click before a
    -- usable SENT event. Only the same synchronous click and public spell
    -- identity can confirm that case; unrelated later casts stay unconfirmed.
    if not attempt then
        local current=self.feedbackClickWindow
        if current and (current.actor or "player")==unit and GetTime()-current.clicked<=.1 and not current.finished
            and (not current.sentObserved or current.guid~=nil) and current.ids[id] then
            attempt=current; attempt.spellID=id
        end
    end
    if not attempt or (attempt.actor or "player")~=unit or attempt.finished or attempt.spellID~=id or attempt.button.castFeedbackAttempt~=attempt then
        if last and not last.finished then last.matchReason="Result has no matching pending cast ID and spell." end
        return
    end
    local state=event=="UNIT_SPELLCAST_SUCCEEDED" and "success" or "failed"
    attempt.finished=true; attempt.outcome=state
    attempt.matchReason="Confirmed matching player spellcast: "..state.."."
    if self.feedbackByCast then
        if readableGUID then self.feedbackByCast[guid]=nil end
        if attempt.guid then self.feedbackByCast[attempt.guid]=nil end
    end
    self.feedbackAttempts[attempt.button]=nil
    self:SetIconFeedback(attempt.button,state)
end

local events=CreateFrame("Frame")
for _,event in ipairs({"UNIT_SPELLCAST_SENT","UNIT_SPELLCAST_SUCCEEDED","UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_FAILED_QUIET","UNIT_SPELLCAST_INTERRUPTED","PLAYER_REGEN_ENABLED",
    "UNIT_SPELLCAST_START","UNIT_SPELLCAST_STOP","UNIT_SPELLCAST_CHANNEL_START","UNIT_SPELLCAST_CHANNEL_STOP"}) do
    pcall(events.RegisterEvent,events,event)
end
events:SetScript("OnEvent",function(_,event,...) F:CastFeedbackEvent(event,...) end)

function F:CreateCombatFeedbackExamples(parent,x,y)
    x,y=x or 500,y or 210
    for index,example in ipairs({{"success","Cast completed"},{"failed","Failed / interrupted"},{"unknown","Unconfirmed"}}) do
        local sample=CreateFrame("Frame",nil,parent)
        sample:SetPoint("TOPLEFT",x+(index-1)*150,-y); sample:SetSize(26,26)
        local icon=sample:CreateTexture(nil,"BACKGROUND"); icon:SetAllPoints(sample)
        icon:SetTexture("Interface\\Icons\\Spell_Shadow_SoulGem")
        sample.feedbackExample=true
        self:CreateCastFeedbackVisual(sample); self:SetIconFeedback(sample,example[1])
        self:AddOptionsText(parent,example[2],x+32+(index-1)*150,-y-6,115)
    end
end
