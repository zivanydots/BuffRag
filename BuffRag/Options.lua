local _, F = ...
SLASH_BUFFRAG1 = "/brag"
SlashCmdList.BUFFRAG = function(input)
    local command=type(input)=="string" and input:lower():match("^%s*(.-)%s*$") or ""
    if command:match("^debug(%s.*)$") or command=="debug" then
        local topic=command:match("^debug%s+(.+)$")
        if topic=="cast" then F:ReportCastFeedback()
        elseif topic=="combat" then F:ReportCombatSetup()
        elseif topic=="post-combat" then F:ReportPostCombat()
        elseif topic=="preview" then F:Print(F.groupPreviewError or "No group preview creation error recorded.")
        elseif topic=="perf start" then F:StartPerformanceCapture()
        elseif topic=="perf print" then F:PrintPerformanceCapture()
        elseif topic and (topic=="perf" or topic:match("^perf%s")) then
            F:Print("Use /brag debug perf start to record and /brag debug perf print to stop and show the report.")
        else
            for _,line in ipairs(F.debugHelp) do F:Print(line[1]) end
        end
        return
    end
    if command=="conflicts" then
        if not F.ReportAddonConflicts then
            F:Print("Conflict detector did not load. Install the full BuffRag folder and fully restart WoW.")
        else F:ReportAddonConflicts() end
        return
    end
    F:ToggleOptions()
end
