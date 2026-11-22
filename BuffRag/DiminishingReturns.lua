local _, F = ...
local units={"target","focus"}
local spells={
    fear={name="Fear",category="Disorient",categoryID=5,estimatedReset=18,ids={[5782]=true,[6213]=true,[6215]=true},
        auras={5782,6213,6215,1324448,1324451,1324453},icon="Interface\\Icons\\Spell_Shadow_Possession"},
    sap={name="Sap",category="Incapacitate",categoryID=4,estimatedReset=16,ids={[6770]=true,[2070]=true,[11297]=true},
        auras={6770,2070,11297,1324482,1324483,1324484},icon="Interface\\Icons\\Ability_Sap"},
}
local spellByClass={WARLOCK=spells.fear,ROGUE=spells.sap}
function F:DREstimateSpell() return spellByClass[self.class] end
local nativeEvent="UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED"
local events=CreateFrame("Frame")
local tracking,records,rows,pending=false,{},{},nil
local nameplateRows={}
local nameplateListening
local outcomeListening,settling
local outcomeWindow=.10
local nativeEvents,nativeSeen=0,0
local lastCast="no supported cast observed"
local traceEvents=CreateFrame("Frame")
local trace,lastTrace
F.drPreviewSpells={
    DRUID={339,5211,9005}, HUNTER={19503,19577,1513}, MAGE={118,122},
    PALADIN={853,20066}, PRIEST={8122,605,15487}, ROGUE={1833,408,6770},
    WARLOCK={5782,6358,5484}, WARRIOR={5246,20252,12809},
}

local function public(value)
    return not (issecretvalue and issecretvalue(value))
end

local function enemyGUID(unit)
    local exists=UnitExists(unit)
    if not public(exists) then return nil,"unit availability restricted" end
    if not exists then return nil,"no unit" end
    local enemy=UnitCanAttack and UnitCanAttack("player",unit)
    local player=UnitIsPlayer and UnitIsPlayer(unit)
    if not public(enemy) or not public(player) then return nil,"unit classification restricted" end
    if not enemy or not player then return nil,"no hostile player" end
    local guid=UnitGUID(unit)
    if public(guid) and type(guid)=="string" and guid~="" then return guid end
    return nil,"player identity unavailable"
end

local function categoryFor(spell)
    return Enum and Enum.SpellDiminishCategory and Enum.SpellDiminishCategory[spell.category] or spell.categoryID
end

local function traceLine(message)
    if not trace then return end
    if #trace.lines>=160 then trace.dropped=(trace.dropped or 0)+1;return end
    trace.lines[#trace.lines+1]=string.format("+%.2fs  %s",GetTime()-trace.started,message)
end

local function traceSnapshot()
    if trace.receiver then return "Self "..trace.spell.name.." aura: "..(trace.selfAuraStatus or "no observation") end
    local parts={}
    local now=GetTime()
    for _,unit in ipairs(units) do
        local guid,reason=enemyGUID(unit)
        local state=guid and records[guid] and records[guid][categoryFor(trace.spell)]
        parts[#parts+1]=unit.." "..(state and state.expires>now and string.format("%.2fs left%s",state.expires-now,state.estimated and " (~)" or "")
            or (guid and "no "..trace.spell.name.." timer" or reason))
        if guid and trace.spell==spells.sap and UnitAffectingCombat then
            local combat=UnitAffectingCombat(unit)
            parts[#parts]=parts[#parts].." / combat "..(not public(combat) and "unavailable" or combat and "yes" or "no")
        end
    end
    return table.concat(parts," / ")
end

local function stopTrace()
    traceEvents:UnregisterAllEvents()
    if not trace then return end
    traceLine(traceSnapshot())
    local nativeSummary=trace.receiver and ("native self DR events "..(trace.selfNative or 0))
        or string.format("native events %d / readable native updates %d",nativeEvents-trace.nativeEvents,nativeSeen-trace.nativeSeen)
    lastTrace={trace.header,trace.registration,string.format("Captured %.1fs / %s",GetTime()-trace.started,nativeSummary),
        string.format("%s: COMBAT_TEXT_UPDATE %d / UNIT_COMBAT %d / UI_ERROR_MESSAGE %d",
            trace.receiver and "Events during capture" or "Events near "..trace.spell.name.." casts",
            trace.feedback.COMBAT_TEXT_UPDATE or 0,trace.feedback.UNIT_COMBAT or 0,trace.feedback.UI_ERROR_MESSAGE or 0)}
    for _,line in ipairs(trace.lines) do lastTrace[#lastTrace+1]=line end
    if trace.dropped then lastTrace[#lastTrace+1]=trace.dropped.." additional entries omitted." end
    trace=nil
end

function F:StartDRTrace(receiver,spellName)
    if not receiver and not tracking then self:Print("Enable DR tracking in Global Settings first.");return end
    local spell=spells[spellName or ""] or (receiver and spells.fear or self:DREstimateSpell())
    if not spell then self:Print("Caster traces are supported for Warlock Fear and Rogue Sap.");return end
    stopTrace()
    local _,build=GetBuildInfo()
    local capture={started=GetTime(),receiver=receiver,spell=spell,lines={},feedback={},nativeEvents=nativeEvents,nativeSeen=nativeSeen,
        header=string.format("Buff Rag v%s / Client build %s / %s %s trace / server start %s",self.version,
            tostring(build or "?"),receiver and "receiver" or "caster",spell.name,GetServerTime and tostring(GetServerTime()) or "unavailable")}
    if not receiver then capture.header=capture.header.." / cast estimates "..(self.db.drEstimates and "on" or "off") end
    trace=capture
    local registered={}
    local subscriptions=receiver and {"COMBAT_TEXT_UPDATE","UNIT_COMBAT","UNIT_AURA",nativeEvent,"DUEL_FINISHED","PLAYER_ENTERING_WORLD"}
        or {"COMBAT_TEXT_UPDATE","UNIT_COMBAT","UI_ERROR_MESSAGE","DUEL_FINISHED"}
    for _,event in ipairs(subscriptions) do
        local ok
        if event=="UNIT_AURA" or (receiver and event=="UNIT_COMBAT") then
            ok=pcall(traceEvents.RegisterUnitEvent,traceEvents,event,"player")
        elseif event=="UNIT_COMBAT" then ok=pcall(traceEvents.RegisterUnitEvent,traceEvents,event,"target","focus")
        else ok=pcall(traceEvents.RegisterEvent,traceEvents,event) end
        registered[#registered+1]=event..(ok and " registered" or " unavailable")
    end
    capture.registration=table.concat(registered," / ")
    traceLine(traceSnapshot())
    C_Timer.After(180,function()
        if trace==capture then stopTrace();F:Print("DR trace finished. Run /brag debug dr print.") end
    end)
    self:Print("DR trace started for up to 3 minutes. Use /brag debug dr print to finish and copy it.")
end

function F:PrintDRTrace()
    stopTrace()
    if not lastTrace then self:Print("Run /brag debug dr start before testing.");return end
    if InCombatLockdown() then
        self:Print("DR trace saved. Run /brag debug dr print again outside combat to copy it.")
    else self:ShowPerformanceReport(lastTrace,"DR Trace") end
end

function F:MarkDRTrace(mark)
    if not trace then self:Print("Run /brag debug dr start first.");return end
    if mark~="immune" and mark~="landed" and mark~="ended" and mark~="resist" then
        self:Print("Use /brag debug dr mark immune, landed, ended or resist.")
        return
    end
    traceLine("Observed by player: "..mark.." / "..traceSnapshot())
end

local outcomes={IMMUNE=true,RESIST=true,MISS=true,EVADE=true,DEFLECT=true,REFLECT=true}
local function observeReceiverAura(update)
    local spell=trace.spell
    local blocked=false
    local lookup=C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID
    if not lookup then blocked=true end
    if lookup then
        for _,id in ipairs(spell.auras) do
            local ok,aura=pcall(lookup,"player",id)
            if not ok or not public(aura) then blocked=true
            elseif type(aura)=="table" then
                local instance,expires=aura.auraInstanceID,aura.expirationTime
                if not public(instance) or type(instance)~="number" then instance=nil end
                local endTime=public(expires) and type(expires)=="number" and expires>0 and expires or nil
                local status="readable "..spell.name.." aura "..id..(endTime and string.format(" / scheduled end +%.2fs",endTime-trace.started) or " / end time unavailable")
                if status~=trace.selfAuraStatus or instance~=trace.selfAuraInstance then traceLine(status) end
                trace.selfAuraStatus,trace.selfAuraInstance=status,instance
                return
            end
        end
    end
    local removed=public(update) and type(update)=="table" and update.removedAuraInstanceIDs
    if trace.selfAuraInstance and public(removed) and type(removed)=="table" then
        for _,instance in ipairs(removed) do
            if public(instance) and instance==trace.selfAuraInstance then
                traceLine("Confirmed removal of the previously readable "..spell.name.." aura")
                trace.selfAuraInstance=nil
                break
            end
        end
    end
    local status=blocked and "lookup restricted or unavailable" or "no readable "..spell.name.." aura"
    if status~=trace.selfAuraStatus then traceLine("Self "..spell.name.." aura: "..status) end
    trace.selfAuraStatus=status
end

traceEvents:SetScript("OnEvent",function(_,event,first,second,third)
    if not trace then return end
    if event=="DUEL_FINISHED" then traceLine("Duel finished");return end
    if event=="PLAYER_ENTERING_WORLD" then stopTrace();return end
    if trace.receiver then
        if event=="UNIT_AURA" then
            if public(first) and first=="player" then observeReceiverAura(second) end
            return
        elseif event==nativeEvent then
            if public(first) and first=="player" then
                trace.selfNative=(trace.selfNative or 0)+1
                local category=public(second) and type(second)=="table" and second.category
                if public(category) and category==categoryFor(trace.spell) then
                    local start,duration,immune=second.startTime,second.duration,second.isImmune
                    traceLine("Native self DR update / "..(public(start) and public(duration) and type(start)=="number" and type(duration)=="number"
                        and string.format("reset +%.2fs",start+duration-trace.started) or "timing restricted")
                        ..(public(immune) and immune==true and " / immune" or ""))
                elseif not public(category) or not category then traceLine("Native self DR category unavailable") end
            end
            return
        end
    elseif not (trace.spell==spells.sap and event=="UI_ERROR_MESSAGE")
        and (not trace.lastCast or GetTime()-trace.lastCast>5) then return end
    trace.feedback[event]=(trace.feedback[event] or 0)+1
    if event=="COMBAT_TEXT_UPDATE" then
        if not public(first) then traceLine("COMBAT_TEXT_UPDATE outcome restricted")
        elseif type(first)=="string" and outcomes[first:gsub("^SPELL_","")] then
            traceLine("COMBAT_TEXT_UPDATE "..first.." (spell and unit attribution unavailable)")
        end
    elseif event=="UNIT_COMBAT" then
        if not public(first) or not public(second) or not public(third) then
            traceLine("UNIT_COMBAT outcome or unit restricted")
        elseif (first=="target" or first=="focus" or first=="player") and (outcomes[second] or outcomes[third]) then
            traceLine("UNIT_COMBAT "..first.." "..(outcomes[second] and second or third).." (no spell ID)")
        end
    elseif event=="UI_ERROR_MESSAGE" then
        local code=public(first) and type(first)=="number" and tostring(first) or "unavailable"
        local text=public(second) and type(second)=="string" and second:gsub("[%c|]"," "):sub(1,120) or "restricted"
        traceLine("UI_ERROR_MESSAGE "..code.." "..text)
    end
end)

local function createIcon(row)
    local icon=CreateFrame("Frame",nil,row)
    icon.visual=icon
    icon:EnableMouse(false)
    icon.texture=icon:CreateTexture(nil,"BACKGROUND")
    icon.texture:SetAllPoints()
    F:CreateCombatCooldown(icon)
    local label=icon:CreateFontString(nil,"OVERLAY","NumberFontNormalSmall")
    label:SetPoint("TOPLEFT",1,-1)
    icon.label=label
    return icon
end

local function render(row,frame,states,now,kind)
    if not frame or not frame:IsVisible() or not states then
        if row then row:Hide() end
        return row
    end
    if not row then
        row=CreateFrame("Frame",nil,UIParent)
        row:SetFrameStrata("HIGH")
        row:EnableMouse(false)
        row.icons={}
    end
    local displayed,categories={},{}
    for category,state in pairs(states) do
        if state.expires>now and (not state.fromCast or F.db.drEstimates) then
            categories[#categories+1]=category
        end
    end
    table.sort(categories)
    for index,category in ipairs(categories) do
        local state=states[category]
        local icon=row.icons[index] or createIcon(row)
        row.icons[index]=icon
        icon.texture:SetTexture(state.icon)
        icon.label:SetText(state.estimated and "~" or (state.immune and "IMM" or ""))
        icon.label:SetTextColor(state.estimated and .75 or 1,state.estimated and .75 or .82,state.estimated and .75 or 0)
        if icon.cooldown.SetHideCountdownNumbers then icon.cooldown:SetHideCountdownNumbers(not state.showCountdown) end
        icon.cooldown:SetCooldown(state.start,state.duration)
        icon:Show()
        displayed[index]=icon
    end
    for index=#displayed+1,#row.icons do row.icons[index]:Hide() end
    if #displayed>0 then F:LayoutIndicators(row,frame,false,displayed,kind) end
    row:SetAlpha(F.db.drOpacity/100)
    row:SetShown(#displayed>0)
    return row
end

local function hideNameplateRow(row)
    if not row.plateUnit then return end
    row:Hide()
    row:ClearAllPoints()
    row.plateUnit=nil
end

local function renderNameplate(plate,unit,now)
    if not public(plate) or not plate then return end
    local row=nameplateRows[plate]
    if plate:IsForbidden() or not public(unit) or type(unit)~="string" or not unit:match("^nameplate%d+$") then
        if row then hideNameplateRow(row) end
        return
    end
    local states=records[enemyGUID(unit)]
    row=render(row,plate,states,now,F.drLayoutKinds.nameplate)
    if row then
        nameplateRows[plate]=row
        if row:IsShown() then row.plateUnit=unit else hideNameplateRow(row) end
    end
end

local function refreshNameplates(now)
    if nameplateListening and not F.testUI and next(records) then
        local plates=C_NamePlate.GetNamePlates()
        if not public(plates) or type(plates)~="table" then return end
        for _,plate in ipairs(plates) do
            if public(plate) and not plate:IsForbidden() and plate.GetUnit then
                renderNameplate(plate,plate:GetUnit(),now)
            end
        end
    else
        for _,row in pairs(nameplateRows) do hideNameplateRow(row) end
    end
end

function F:RefreshDR()
    local enabled=self.db and self.db.drEnabled and not self.conflictPaused
    if not enabled then
        if tracking then
            if trace and not trace.receiver then stopTrace() end
            events:UnregisterAllEvents()
            records,pending,tracking={},nil,false
            outcomeListening,settling,nameplateListening=nil,nil,nil
            lastCast="no supported cast observed"
        end
        for _,row in pairs(rows) do row:Hide() end
        refreshNameplates()
        return
    end
    if not tracking then
        tracking=true
        for _,event in ipairs({nativeEvent,"PLAYER_TARGET_CHANGED","PLAYER_FOCUS_CHANGED","PLAYER_ENTERING_WORLD",
            "UNIT_SPELLCAST_SENT","UNIT_SPELLCAST_SUCCEEDED","UNIT_SPELLCAST_FAILED","UNIT_SPELLCAST_FAILED_QUIET","UNIT_SPELLCAST_INTERRUPTED"}) do
            pcall(events.RegisterEvent,events,event)
        end
        if events.RegisterUnitEvent then events:RegisterUnitEvent("UNIT_AURA","target","focus") end
    end
    if self.db.drEstimates and self:DREstimateSpell() then
        if outcomeListening==nil then
            outcomeListening=pcall(events.RegisterUnitEvent,events,"UNIT_COMBAT","target","focus")
        end
    else
        if outcomeListening then events:UnregisterEvent("UNIT_COMBAT") end
        outcomeListening,pending,settling=nil,nil,nil
    end
    local showNameplates=self.db.drNameplates and C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlateForUnit
    if showNameplates and not nameplateListening then
        nameplateListening=true
        events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    elseif not showNameplates and nameplateListening then
        nameplateListening=nil
        events:UnregisterEvent("NAME_PLATE_UNIT_ADDED")
        events:UnregisterEvent("NAME_PLATE_UNIT_REMOVED")
    end
    local now=GetTime()
    for guid,states in pairs(records) do
        for category,state in pairs(states) do if state.expires<=now then states[category]=nil end end
        if not next(states) then records[guid]=nil end
    end
    for _,unit in ipairs(units) do
        local frame=unit=="target" and TargetFrame or (unit=="focus" and FocusFrame)
        rows[unit]=render(rows[unit],frame,not self.testUI and self.db.drFrameTimers and records[enemyGUID(unit)],now,self.drLayoutKinds[unit])
    end
    refreshNameplates(now)
end

local function saveState(guid,category,state)
    local states=records[guid] or {}
    records[guid]=states
    states[category]=state
    if trace and not trace.receiver and category==categoryFor(trace.spell) then
        local source=state.fromCast and "unconfirmed cast" or state.auraExpires and ("readable "..trace.spell.name.." aura")
            or state.estimated and "readable early aura removal" or "native update"
        traceLine("Timer from "..source.." / "..traceSnapshot())
    end
    F:RefreshDR()
    C_Timer.After(math.max(0,state.expires-GetTime()),function()
        if records[guid] and records[guid][category]==state then F:RefreshDR() end
    end)
end

local function nativeUpdate(unit,info)
    nativeEvents=nativeEvents+1
    if not public(unit) or type(unit)~="string" or not public(info) or type(info)~="table" then return end
    local guid=enemyGUID(unit)
    if not guid or (guid~=enemyGUID("target") and guid~=enemyGUID("focus")) then return end
    local category,start,duration,immune,countdown=info.category,info.startTime,info.duration,info.isImmune,info.showCountdown
    if not public(category) or not public(start) or not public(duration) or not public(immune) or not public(countdown)
        or type(category)~="number" or type(start)~="number" or type(duration)~="number" then return end
    nativeSeen=nativeSeen+1
    if duration<=0 or start+duration<=GetTime() then
        if records[guid] then records[guid][category]=nil;F:RefreshDR() end
        if trace and not trace.receiver and category==categoryFor(trace.spell) then
            traceLine("Native "..trace.spell.name.." reset / "..traceSnapshot())
        end
        return
    end
    local texture="Interface\\Icons\\INV_Misc_QuestionMark"
    for _,spell in pairs(spells) do
        if category==categoryFor(spell) then texture=spell.icon;break end
    end
    if C_SpellDiminish and C_SpellDiminish.GetSpellDiminishCategoryInfo then
        local ok,data=pcall(C_SpellDiminish.GetSpellDiminishCategoryInfo,category)
        if ok and public(data) and data and public(data.icon) and data.icon then texture=data.icon end
    end
    saveState(guid,category,{start=start,duration=duration,expires=start+duration,immune=immune,
        icon=texture,showCountdown=countdown})
end

local function recipientGUID(recipient)
    if not public(recipient) or type(recipient)~="string" or recipient=="" then return nil,"recipient unavailable or restricted" end
    local match
    for _,unit in ipairs(units) do
        local guid=enemyGUID(unit)
        if guid then
            local name,surname=UnitName(unit)
            if public(name) and type(name)=="string" and public(surname) then
                local full=name
                if type(surname)=="string" and surname~="" then
                    full=NameUtil and NameUtil.GetFullNameWithoutRealm and NameUtil.GetFullNameWithoutRealm(name,surname)
                        or name.." "..surname
                end
                if recipient==full or recipient==name then
                    if match and match~=guid then return nil,"recipient ambiguous between Target and Focus" end
                    match=guid
                end
            end
        end
    end
    return match,not match and "recipient did not match an identifiable hostile Target or Focus" or nil
end

local rejectedOutcomes={IMMUNE=true,RESIST=true,MISS=true}
local function castOutcome(unit,event,flag)
    local attempt=settling or pending
    if not attempt or not public(unit) or (unit~="target" and unit~="focus") then return end
    local outcome=public(event) and rejectedOutcomes[event] and event
        or public(flag) and rejectedOutcomes[flag] and flag
    if not outcome then return end
    local now=GetTime()
    if attempt.completed and now-attempt.completed>outcomeWindow then return end
    if enemyGUID(unit)==attempt.guid then attempt.outcome,attempt.outcomeAt=outcome,now end
end

local function castEvent(event,unit,first,second,third)
    local tracing=trace and not trace.receiver and trace
    local spell=F:DREstimateSpell()
    if not spell or (not F.db.drEstimates and not tracing) or not public(unit) or unit~="player" then return end
    if event=="UNIT_SPELLCAST_SENT" then
        if not public(third) or not spell.ids[third] then return end
        local guid,reason=recipientGUID(first)
        if tracing then
            local scope=guid and ((guid==enemyGUID("target") and "Target" or "Focus"))
            trace.lastCast=GetTime()
            traceLine(spell.name.." "..third.." sent / "..(scope or reason).." / "..traceSnapshot())
        end
        if not F.db.drEstimates or not public(second) or type(second)~="string" then return end
        lastCast=guid and "matched recipient; waiting for cast result" or reason
        pending=guid and {guid=guid,cast=second,spell=third,sent=GetTime()} or nil
        return
    end
    if tracing and public(second) and spell.ids[second] then
        trace.lastCast=GetTime()
        traceLine(spell.name.." "..second.." "..event.." / "..traceSnapshot())
    end
    if not F.db.drEstimates then return end
    if not pending then return end
    if not public(first) or not public(second) then
        lastCast="cast result identity restricted"
        return
    end
    if pending.cast~=first or pending.spell~=second then return end
    local attempt=pending
    pending=nil
    if event~="UNIT_SPELLCAST_SUCCEEDED" then lastCast="cast failed or was interrupted";return end
    if GetTime()-attempt.sent>10 or (attempt.guid~=enemyGUID("target") and attempt.guid~=enemyGUID("focus")) then
        lastCast="recipient no longer identifiable on Target or Focus"
        return
    end
    local now=GetTime()
    attempt.completed=now
    if attempt.outcomeAt and now-attempt.outcomeAt>.03 then attempt.outcome=nil end
    local function settle()
        if settling~=attempt then return end
        settling=nil
        if attempt.outcome then
            lastCast="matched "..attempt.outcome.."; no timer restart"
            if tracing and trace==tracing then traceLine(lastCast.." / "..traceSnapshot()) end
            return
        end
        local category=categoryFor(spell)
        local existing=records[attempt.guid] and records[attempt.guid][category]
        if existing and not existing.fromCast and existing.expires>GetTime() then
            lastCast="retained the native or aura-based timer"
            return
        end
        saveState(attempt.guid,category,{start=now,duration=spell.estimatedReset,expires=now+spell.estimatedReset,
            estimated=true,fromCast=true,icon=spell.icon,showCountdown=true})
        lastCast="showing an estimated timer"
    end
    settling=attempt
    if outcomeListening and not attempt.outcome then C_Timer.After(outcomeWindow,settle) else settle() end
end

local function observeAura(unit,update,spell)
    if not public(unit) or (unit~="target" and unit~="focus") or not C_UnitAuras or not C_UnitAuras.GetUnitAuraBySpellID then return end
    local guid=enemyGUID(unit)
    if not guid then return end
    local now,category=GetTime(),categoryFor(spell)
    local existing=records[guid] and records[guid][category]
    if existing and not existing.estimated and existing.expires>now then return end
    for _,id in ipairs(spell.auras) do
        local ok,aura=pcall(C_UnitAuras.GetUnitAuraBySpellID,unit,id)
        if ok and public(aura) and type(aura)=="table" then
            local expires,instance=aura.expirationTime,aura.auraInstanceID
            if public(expires) and type(expires)=="number" and expires>now then
                if not public(instance) or type(instance)~="number" then instance=nil end
                local reset=expires+spell.estimatedReset
                if not existing or existing.auraExpires~=expires or existing.auraInstance~=instance then
                    saveState(guid,category,{start=now,duration=reset-now,expires=reset,
                        estimated=true,icon=spell.icon,showCountdown=true,auraInstance=instance,auraExpires=expires})
                end
                return
            end
        end
    end
    if existing and existing.auraInstance and now<existing.auraExpires and public(update) and type(update)=="table" then
        local removed=update.removedAuraInstanceIDs
        if public(removed) and type(removed)=="table" then
            for _,instance in ipairs(removed) do
                if public(instance) and instance==existing.auraInstance then
                    saveState(guid,category,{start=now,duration=spell.estimatedReset,expires=now+spell.estimatedReset,
                        estimated=true,icon=spell.icon,showCountdown=true})
                    return
                end
            end
        end
    end
end

events:SetScript("OnEvent",function(_,event,...)
    if event==nativeEvent then nativeUpdate(...)
    elseif event=="UNIT_AURA" then
        local unit,update=...
        local spell=F:DREstimateSpell()
        if spell==spells.sap then observeAura(unit,update,spell) end
        observeAura(unit,update,spells.fear)
    elseif event=="UNIT_COMBAT" then castOutcome(...)
    elseif event=="NAME_PLATE_UNIT_ADDED" then
        local unit=...
        if not F.testUI and next(records) and public(unit) and type(unit)=="string" then
            renderNameplate(C_NamePlate.GetNamePlateForUnit(unit),unit,GetTime())
        end
    elseif event=="NAME_PLATE_UNIT_REMOVED" then
        local unit=...
        if public(unit) and unit then
            for _,row in pairs(nameplateRows) do
                if row.plateUnit==unit then hideNameplateRow(row);break end
            end
        end
    elseif event=="PLAYER_ENTERING_WORLD" then
        if trace then stopTrace() end
        records,pending,settling={},nil,nil;F:RefreshDR()
    elseif event=="PLAYER_TARGET_CHANGED" or event=="PLAYER_FOCUS_CHANGED" then F:RefreshDR()
    else castEvent(event,...) end
end)

function F:ReportDR()
    local supported=C_SpellDiminish and C_SpellDiminish.IsSystemSupported
    self:Print("DR tracking "..(tracking and "on" or "off").."; native events: "..nativeEvents.."; readable updates for Target or Focus: "..nativeSeen
        .."; native API support: "..(supported and supported() and "yes" or "no")..".")
    local spell=self:DREstimateSpell()
    if spell then
        local estimates=self.db and self.db.drEstimates
        self:Print(spell.name.." cast estimates "..(estimates and "on; last "..spell.name..": "..lastCast or "off")..".")
    end
    for _,unit in ipairs(units) do
        local guid,reason=enemyGUID(unit)
        self:Print(unit..": "..(guid and (rows[unit] and rows[unit]:IsShown() and "DR active" or "hostile player identified; no active DR display")
            or reason)..".")
    end
end
