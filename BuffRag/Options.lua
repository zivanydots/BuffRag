local _, F = ...
SLASH_BUFFRAG1 = "/brag"
SlashCmdList.BUFFRAG = function(input)
    local command=type(input)=="string" and input:lower():match("^%s*(.-)%s*$") or ""
    if command=="conflicts" then
        if not F.ReportAddonConflicts then
            F:Print("Conflict detector did not load. Install the full BuffRag folder and fully restart WoW.")
        else F:ReportAddonConflicts() end
        return
    end
    F:ToggleOptions()
end
