local _, F = ...
local function public(value) return not (issecretvalue and issecretvalue(value)) end
local function castID(value) return public(value) and type(value)=="string" and value~="" end

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
end

function F:SetIconFeedback(button,state)
    button.castFeedbackState=state
    local mark,question=button.castFeedbackMark,button.castFeedbackQuestion
    if not mark then return end
    if state=="success" or state=="failed" then
        mark:SetTexture(state=="success" and "Interface\\RaidFrame\\ReadyCheck-Ready" or "Interface\\RaidFrame\\ReadyCheck-NotReady")
        mark:SetAlpha(1); question:SetAlpha(0)
    else
        mark:SetAlpha(0); question:SetAlpha((state=="pending" or state=="unknown") and 1 or 0)
    end
end

function F:ClearIconFeedback(button)
    local attempt=button.castFeedbackAttempt
    if attempt then
        attempt.finished=true
        if attempt.guid and self.feedbackByCast then self.feedbackByCast[attempt.guid]=nil end
    end
    button.castFeedbackAttempt=nil
    if self.feedbackAttempts then self.feedbackAttempts[button]=nil end
    self:SetIconFeedback(button,nil)
end

function F:PrepareCastFeedback(button,candidate,allowed)
    self:ClearIconFeedback(button)
    button.castFeedbackAllowed=allowed
    local ids={}
    local function add(id) if public(id) and type(id)=="number" then ids[id]=true end end
    if candidate.spellID then add(candidate.spellID)
    elseif candidate.itemID and C_Item.GetItemSpell then
        local ok,effect,id=pcall(C_Item.GetItemSpell,candidate.itemID)
        if ok then
            add(id)
            if public(effect) and type(effect)=="table" then add(effect.spellID); add(effect.spellId) end
        end
    end
    local entry=self.spells[candidate.key]
    if entry and entry.stone=="soul" and not candidate.creation then
        for _,id in ipairs(entry.auraIDs or {}) do add(id) end
    end
    button.castFeedbackIDs=ids
    button.castFeedbackSelfOnly=entry and entry.selfOnly and self:IsSelf(candidate.unit)
    local name,realm=UnitName(candidate.unit)
    button.castFeedbackName=public(name) and type(name)=="string" and name or nil
    button.castFeedbackFullName=button.castFeedbackName
    if button.castFeedbackName and public(realm) and type(realm)=="string" and realm~="" then
        button.castFeedbackFullName=name.."-"..realm
    end
end

function F:BeginIconCast(button,mouseButton,down)
    if not public(mouseButton) or mouseButton~="LeftButton" or not public(down) or down then return end
    if not InCombatLockdown() or self.testUI or not self.db or not self.db.combatClicks or not button.castFeedbackAllowed then return end
    self:ClearIconFeedback(button)
    local attempt={button=button,clicked=GetTime()}
    button.castFeedbackAttempt=attempt
    self.feedbackAttempts=self.feedbackAttempts or {}; self.feedbackAttempts[button]=attempt
    self:SetIconFeedback(button,"pending")
    -- Missing/secret events are not failures. Keep an honest unconfirmed mark.
    C_Timer.After(20,function()
        if not attempt.finished and button.castFeedbackAttempt==attempt then
            attempt.finished=true
            if attempt.guid and F.feedbackByCast then F.feedbackByCast[attempt.guid]=nil end
            F.feedbackAttempts[button]=nil; F:SetIconFeedback(button,"unknown")
        end
    end)
end

function F:CastFeedbackEvent(event,unit,arg2,arg3,arg4)
    if event=="PLAYER_REGEN_ENABLED" then
        for _,overlay in pairs(self.overlays) do
            for _,button in ipairs(overlay.indicators.squares) do self:ClearIconFeedback(button) end
        end
        self.feedbackAttempts,self.feedbackByCast={},{}
        return
    end
    if not public(unit) or unit~="player" or not InCombatLockdown() then return end
    if event=="UNIT_SPELLCAST_SENT" then
        local target,guid,id=arg2,arg3,arg4
        if not public(target) or type(target)~="string" or not castID(guid) or not public(id) or type(id)~="number" then return end
        local match
        for button,attempt in pairs(self.feedbackAttempts or {}) do
            if not attempt.finished and not attempt.guid and GetTime()-attempt.clicked<=1
                and button.castFeedbackIDs[id]
                and (target==button.castFeedbackName or target==button.castFeedbackFullName or (target=="" and button.castFeedbackSelfOnly)) then
                if match then return end -- Ambiguous clicks must never earn a guessed tick.
                match=attempt
            end
        end
        if match then
            match.guid,match.spellID=guid,id
            self.feedbackByCast=self.feedbackByCast or {}; self.feedbackByCast[guid]=match
        end
        return
    end
    if event~="UNIT_SPELLCAST_SUCCEEDED" and event~="UNIT_SPELLCAST_FAILED" and event~="UNIT_SPELLCAST_FAILED_QUIET" and event~="UNIT_SPELLCAST_INTERRUPTED" then return end
    local guid,id=arg2,arg3
    if not castID(guid) or not public(id) or type(id)~="number" then return end
    local attempt=self.feedbackByCast and self.feedbackByCast[guid]
    if not attempt or attempt.finished or attempt.spellID~=id or attempt.button.castFeedbackAttempt~=attempt then return end
    local state=event=="UNIT_SPELLCAST_SUCCEEDED" and "success" or "failed"
    attempt.finished=true; self.feedbackByCast[guid]=nil; self.feedbackAttempts[attempt.button]=nil
    self:SetIconFeedback(attempt.button,state)
end

local events=CreateFrame("Frame")
for _,event in ipairs({"UNIT_SPELLCAST_SENT","UNIT_SPELLCAST_SUCCEEDED","UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_FAILED_QUIET","UNIT_SPELLCAST_INTERRUPTED","PLAYER_REGEN_ENABLED"}) do
    pcall(events.RegisterEvent,events,event)
end
events:SetScript("OnEvent",function(_,event,...) F:CastFeedbackEvent(event,...) end)

function F:CreateCombatFeedbackExamples(parent)
    for index,example in ipairs({{"success","Cast completed"},{"failed","Failed / interrupted"},{"unknown","Unconfirmed"}}) do
        local sample=CreateFrame("Frame",nil,parent)
        sample:SetPoint("TOPLEFT",500+(index-1)*150,-210); sample:SetSize(26,26)
        local icon=sample:CreateTexture(nil,"BACKGROUND"); icon:SetAllPoints(sample)
        icon:SetTexture("Interface\\Icons\\Spell_Shadow_SoulGem")
        self:CreateCastFeedbackVisual(sample); self:SetIconFeedback(sample,example[1])
        self:AddOptionsText(parent,example[2],532+(index-1)*150,-216,115)
    end
end
