local _, F = ...
local limit = 24

local function clock()
    if debugprofilestop then return debugprofilestop() end
    return GetTimePreciseSec() * 1000
end

local function record(capture, message)
    local records = capture.records
    if #records == limit then table.remove(records, 1) end
    records[#records + 1] = string.format("+%.1fs  %s", (clock() - capture.started) / 1000, message)
    capture.total = capture.total + 1
end

local function addTiming(timings,key,elapsed)
    local sample=timings[key]
    if not sample then
        sample={count=0,total=0,peak=0}
        timings[key]=sample
    end
    sample.count=sample.count+1
    sample.total=sample.total+elapsed
    sample.peak=math.max(sample.peak,elapsed)
end

local function addSummary(report,capture,now)
    local elapsed=now-capture.started
    local combatTime=capture.combatTime+(capture.inCombat and now-capture.phaseStarted or 0)
    local safeTime=elapsed-combatTime
    report[#report+1]=string.format("Capture time: %.1fs in combat / %.1fs out of combat.",combatTime/1000,safeTime/1000)
    for _,entry in ipairs({
        {"exitRefresh","First refresh after combat",safeTime},
        {"otherRefresh","Other full refreshes",safeTime},
        {"combatRange","Range/cooldown/dispel ticks in combat",combatTime},
        {"safeRange","Range/cooldown/dispel ticks out of combat",safeTime},
    }) do
        local sample=capture.timings[entry[1]]
        local duration=entry[3]
        if sample and duration>0 then
            report[#report+1]=string.format("%s: %d calls / %.2f ms total / %.2f ms peak / %.2f ms per second",
                entry[2],sample.count,sample.total,sample.peak,sample.total*1000/duration)
        end
    end
    local triggers={}
    for name,counts in pairs(capture.refreshTriggers) do
        triggers[#triggers+1]={name=name,requests=counts.requests,batches=counts.batches}
    end
    table.sort(triggers,function(a,b)
        if a.batches~=b.batches then return a.batches>b.batches end
        if a.requests~=b.requests then return a.requests>b.requests end
        return a.name<b.name
    end)
    if #triggers>0 then
        report[#report+1]="Full refresh triggers (events can share a batch):"
        for index=1,math.min(8,#triggers) do
            local trigger=triggers[index]
            report[#report+1]=string.format("  %s: %d requests / %d batches",trigger.name,trigger.requests,trigger.batches)
        end
    end
end

function F:StartPerformanceCapture()
    if not debugprofilestop and not GetTimePreciseSec then
        self:Print("Performance timing is unavailable on this client.")
        return
    end
    local _, build = GetBuildInfo()
    local started=clock()
    self.perfRecording = {
        started = started, records = {}, total = 0, version = self.version, build = build, cacheReasons = {},
        timings = {}, refreshTriggers = {}, pendingRefreshTriggers = {},
        inCombat = InCombatLockdown(), phaseStarted = started, combatTime = 0,
    }
    self.perfReport = nil
    if self.perfReportWindow then self.perfReportWindow:Hide() end
    self:Print("Performance recording started. Reproduce the issue, then run /brag debug perf print.")
end

function F:PrintPerformanceCapture()
    local capture = self.perfRecording
    if capture then
        self.perfRecording = nil
        local now=clock()
        local report = {
            string.format("Buff Rag v%s / Client build %s / %s / %.1fs recorded", capture.version,
                tostring(capture.build or "?"), self.class or "Unknown class", (now - capture.started) / 1000),
            "Elapsed addon Lua time in ms. Latest " .. #capture.records .. " of " .. capture.total .. " samples.",
        }
        addSummary(report,capture,now)
        if capture.total == 0 then report[#report + 1] = "No combat or Post-combat transitions recorded." end
        for _, line in ipairs(capture.records) do report[#report + 1] = line end
        self.perfReport = report
    end
    if not self.perfReport then
        self:Print("No performance capture. Run /brag debug perf start first.")
        return
    end
    for _, sample in ipairs(self.perfReport) do
        for line in sample:gmatch("[^\n]+") do self:Print(line) end
    end
    if not InCombatLockdown() then self:ShowPerformanceReport(self.perfReport) end
end

function F:BeginPerfTransition(event)
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then return clock() end
end

function F:EndPerfTransition(event, started)
    local now=clock()
    local elapsed = now - started
    local capture = self.perfRecording
    local entering = event == "PLAYER_REGEN_DISABLED"
    if capture.inCombat then capture.combatTime=capture.combatTime+now-capture.phaseStarted end
    capture.inCombat,capture.phaseStarted=entering,now
    capture.firstCombatRange = entering
    capture.firstExitRefresh = not entering
    local group = GetNumGroupMembers()
    record(capture, string.format("Combat %s / event %.2f ms / group %s",
        entering and "entered" or "exited", elapsed, group == 0 and "solo" or tostring(group)))
end

function F:BeginPerfRange()
    return clock()
end

function F:EndPerfRange(started, icons, combat)
    local capture=self.perfRecording
    local elapsed=clock()-started
    addTiming(capture.timings,combat and "combatRange" or "safeRange",elapsed)
    if combat and capture.firstCombatRange then
        capture.firstCombatRange=false
        record(capture,string.format("First Combat range/cooldown/dispel update %.2f ms / %d icons checked",elapsed,icons))
    end
end

function F:NotePerfRefreshRequest(reason)
    local capture=self.perfRecording
    local counts=capture.refreshTriggers[reason]
    if not counts then
        counts={requests=0,batches=0}
        capture.refreshTriggers[reason]=counts
    end
    counts.requests=counts.requests+1
    capture.pendingRefreshTriggers[reason]=counts
end

function F:BeginPerfRefresh(triggers)
    local capture=self.perfRecording
    if triggers and next(triggers) then
        for _,counts in pairs(triggers) do counts.batches=counts.batches+1 end
    else
        local counts=capture.refreshTriggers["Direct refresh"]
        if not counts then
            counts={requests=0,batches=0}
            capture.refreshTriggers["Direct refresh"]=counts
        end
        counts.requests=counts.requests+1
        counts.batches=counts.batches+1
    end
    return {started = clock(), time = {}, cache = {}, frames = 0, icons = 0, slots = 0, entered = 0, left = 0}
end

function F:NotePerfCacheInvalidation(cache, reason)
    local pending = self.perfRecording.cacheReasons
    if not pending[cache] then pending[cache] = {} end
    pending[cache][reason] = true
end

function F:NotePerfCacheRebuild(cache, sample, cold)
    local pending = self.perfRecording.cacheReasons
    local reasons = pending[cache]
    pending[cache] = nil
    if not sample then return end
    local causes = {}
    for reason in pairs(reasons or {}) do causes[#causes + 1] = reason end
    table.sort(causes)
    local cause = #causes > 0 and table.concat(causes, ", ") or (cold and "initial build" or "trigger not captured")
    sample.cache[cache] = "rebuilt: " .. cause
end

function F:MarkPerfRefresh(sample, section)
    local now = clock()
    sample.time[section] = (sample.time[section] or 0) + now - (sample.last or sample.started)
    sample.last = now
end

function F:EndPerfRefresh(sample, paused)
    local elapsed = clock() - sample.started
    local capture = self.perfRecording
    local first = capture.firstExitRefresh
    capture.firstExitRefresh = false
    addTiming(capture.timings,first and "exitRefresh" or "otherRefresh",elapsed)
    if not first and sample.entered == 0 and sample.left == 0 then return end
    local label = first and "First refresh after combat" or "Post-combat refresh"
    if paused then
        record(capture, string.format("%s %.2f ms / paused for addon conflict", label, elapsed))
        return
    end
    local time = sample.time
    local discovery = time.setup + time.spellbook + time.combatBook + time.itemBuffs + time.recipients + time.frameDiscovery
    local summary = string.format("%s %.2f ms / frames %d, actions %d, icon slots %d / Post-combat +%d/-%d",
        label, elapsed, sample.frames, sample.icons, sample.slots, sample.entered, sample.left)
    local detail = string.format("  Discovery %.2f / aura and action checks %.2f / button prep %.2f / layout %.2f / range and UI %.2f ms",
        discovery, time.checks or 0, time.buttons or 0, time.layout or 0, time.finish or 0)
    local spellbook = string.format("  Player spellbook %.2f ms (%s)", time.spellbook, sample.cache.spellbook or "reused")
    local combatBook = string.format("  Combat and pet catalogue %.2f ms (%s)", time.combatBook, sample.cache.combatBook or "reused")
    local other = string.format("  Item buffs %.2f / single-recipient buffs %.2f / frame discovery %.2f / setup %.2f ms",
        time.itemBuffs, time.recipients, time.frameDiscovery, time.setup)
    record(capture, table.concat({summary, detail, spellbook, combatBook, other}, "\n"))
end
