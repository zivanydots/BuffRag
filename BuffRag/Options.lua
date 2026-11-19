local _, F = ...
SLASH_BUFFRAG1 = "/brag"
SlashCmdList.BUFFRAG = function(input)
    local command=type(input)=="string" and input:lower():match("^%s*(.-)%s*$") or ""
    if command:match("^debug(%s.*)$") or command=="debug" then
        local topic=command:match("^debug%s+(.+)$")
        if topic=="cast" then F:ReportCastFeedback()
        elseif topic=="combat" then F:ReportCombatSetup()
        else F:Print("Debug commands: /brag debug cast; /brag debug combat") end
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
