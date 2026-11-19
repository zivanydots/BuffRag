local _, F = ...
local limit = 12

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

function F:StartPerformanceCapture()
    if not debugprofilestop and not GetTimePreciseSec then
        self:Print("Performance timing is unavailable on this client.")
        return
    end
    local _, build = GetBuildInfo()
    self.perfRecording = {
        started = clock(), records = {}, total = 0, version = self.version, build = build,
    }
    self.perfReport = nil
    if self.perfReportWindow then self.perfReportWindow:Hide() end
    self:Print("Performance recording started. Reproduce the issue, then run /brag debug perf print.")
end

function F:PrintPerformanceCapture()
    local capture = self.perfRecording
    if capture then
        self.perfRecording = nil
        local report = {
            string.format("Buff Rag v%s / Client build %s / %s / %.1fs recorded", capture.version,
                tostring(capture.build or "?"), self.class or "Unknown class", (clock() - capture.started) / 1000),
            "Elapsed addon Lua time in ms. Latest " .. #capture.records .. " of " .. capture.total .. " samples.",
        }
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
    local elapsed = clock() - started
    local capture = self.perfRecording
    local entering = event == "PLAYER_REGEN_DISABLED"
    capture.firstCombatRange = entering
    capture.firstExitRefresh = not entering
    local group = GetNumGroupMembers()
    record(capture, string.format("Combat %s / event %.2f ms / group %s",
        entering and "entered" or "exited", elapsed, group == 0 and "solo" or tostring(group)))
end

function F:BeginPerfRange(combat)
    if combat and self.perfRecording.firstCombatRange then
        self.perfRecording.firstCombatRange = false
        return clock()
    end
end

function F:EndPerfRange(started, icons)
    record(self.perfRecording, string.format("First Combat range/cooldown/dispel update %.2f ms / %d icons checked",
        clock() - started, icons))
end

function F:BeginPerfRefresh()
    return {started = clock(), time = {}, frames = 0, icons = 0, slots = 0, entered = 0, left = 0}
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
    if not first and sample.entered == 0 and sample.left == 0 then return end
    local label = first and "First refresh after combat" or "Post-combat refresh"
    if paused then
        record(capture, string.format("%s %.2f ms / paused for addon conflict", label, elapsed))
        return
    end
    local time = sample.time
    local summary = string.format("%s %.2f ms / frames %d, actions %d, icon slots %d / Post-combat +%d/-%d",
        label, elapsed, sample.frames, sample.icons, sample.slots, sample.entered, sample.left)
    local detail = string.format("  Discovery %.2f / aura and action checks %.2f / button prep %.2f / layout %.2f / range and UI %.2f ms",
        time.discovery or 0, time.checks or 0, time.buttons or 0, time.layout or 0, time.finish or 0)
    record(capture, summary .. "\n" .. detail)
end
