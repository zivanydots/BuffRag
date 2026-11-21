local _, F = ...
local function isFelBot(value)
    if type(value)~="string" then return false end
    value=value:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):lower():match("^%s*(.-)%s*$")
    return value=="felbot" or value:match("^felbot[%s_%-%.]")~=nil or value:match("^felbotv?%d")~=nil
end
local function query(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b=pcall(fn,...)
    if ok then return a,b end
end
local function loadedState(name)
    local first,fullyLoaded=query(C_AddOns and C_AddOns.IsAddOnLoaded,name)
    if type(fullyLoaded)=="boolean" then return fullyLoaded,true end
    if type(first)=="boolean" then return first,true end
    first,fullyLoaded=query(IsAddOnLoaded,name)
    if type(fullyLoaded)=="boolean" then return fullyLoaded,true end
    if type(first)=="boolean" then return first,true end
    return false,false
end
function F:NoteAddonLoaded(name)
    if type(name)~="string" then return end
    self.loadedAddonNames=self.loadedAddonNames or {}
    self.loadedAddonNames[name]=true
end
function F:FindAddonConflicts()
    local api=C_AddOns or {}
    local count=api.GetNumAddOns or GetNumAddOns
    local info=api.GetAddOnInfo or GetAddOnInfo
    local character=UnitName("player")
    local found,records,seen={},{},{}
    local function consider(name,title,listed)
        if type(name)~="string" or seen[name] then return end
        title=title or query(api.GetAddOnTitle,name) or query(api.GetAddOnMetadata,name,"Title")
        if not (isFelBot(name) or isFelBot(title)) then return end
        local loaded,loadedKnown=loadedState(name)
        if not loadedKnown then loaded=(self.loadedAddonNames and self.loadedAddonNames[name])==true end
        local state=query(api.GetAddOnEnableState,name,character)
        if type(state)~="number" then state=query(GetAddOnEnableState,character,name) end
        local exists=listed or query(api.DoesAddOnExist,name) or loaded or (type(state)=="number" and state>0)
        if not exists then return end
        seen[name]=true
        records[#records+1]={name=name,enabled=type(state)=="number" and state>0 or false,enableKnown=type(state)=="number",loaded=loaded==true,loadedKnown=loadedKnown,installed=exists==true}
    end
    if count and info then
        local total=query(count) or 0
        for index=1,total do
            local name=query(api.GetAddOnName,index)
            local value,title=query(info,name or index)
            if type(value)=="table" then title=value.title; value=value.name or value.addOnName end
            consider(name or value,title,true)
        end
    elseif count and api.GetAddOnName then
        for index=1,(query(count) or 0) do consider(query(api.GetAddOnName,index),nil,true) end
    end
                                                                               
    consider("FelBot",nil,false)
    for name in pairs(self.loadedAddonNames or {}) do consider(name,nil,true) end
                                                                               
                                                                              
    if type(_G.FelBot)=="table" and type(_G.FelBot.db)=="table" then
        if #records==0 then
            local _,known=loadedState("FelBot")
            if not known then records[1]={name="FelBot",enabled=false,loaded=true,installed=true} end
        else
            for _,record in ipairs(records) do if not record.loadedKnown then record.loaded=true end end
        end
    end
    for _,record in ipairs(records) do
        if record.loaded then found[#found+1]=record.name end
    end
    return found,records
end
function F:ReportAddonConflicts()
    self.conflictStartupReady=true
    self.addonConflictWarned=nil
    self:CheckAddonConflicts()
end
function F:UpdateAddonConflictPause(records)
    if not records then local _; _,records=self:FindAddonConflicts() end
    local paused=false
    for _,record in ipairs(records) do if record.loaded then paused=true; break end end
    local changed=self.conflictPaused~=paused
    self.conflictPaused=paused
    return paused,changed
end
function F:SuspendForAddonConflict()
    if InCombatLockdown() then return end
    self:SyncCombatKeybinds({})
    self.selfAction,self.selfPriorityAction=nil,nil
    local function clear(button)
        for _,prefix in ipairs({"","shift-","ctrl-","alt-"}) do
            self:SetAction(button,prefix,nil)
            for _,key in ipairs({"type1","spell1","item1","macrotext1"}) do button:SetAttribute("safe-"..prefix..key,nil) end
        end
    end
    for _,overlay in pairs(self.overlays or {}) do
        RegisterStateDriver(overlay.click,"visibility","hide"); overlay.driver="hide"
        clear(overlay.click); overlay.click:Hide()
        for _,icon in ipairs(overlay.indicators.squares) do
            RegisterStateDriver(icon,"visibility","hide"); icon.paletteVisibility="hide"
            clear(icon); icon:SetAttribute("buff-action",""); icon:SetAttribute("combat-clicks",false); icon:Hide()
        end
        overlay.indicators.displayOrder={}
    end
    if self.activate then clear(self.activate) end
    self.testUI=false
    self.testMode=nil
    for _,preview in pairs(self.previews or {}) do preview:Hide() end
    if self.groupPreviewHost and not InCombatLockdown() then self.groupPreviewHost:Hide() end
    if self.options and self.options.iconOptions then self.options.iconOptions:Hide() end
    if self.options and self.db then
        local settings=self.options.globalSettings
        if settings and settings:IsShown() then settings:Sync() end
        if self.options.UpdateBuffRows then self.options:UpdateBuffRows() end
        if self.options.UpdateItemRows then self.options:UpdateItemRows() end
        self:UpdateSaveButton()
    end
end
function F:OpenConflictAddOns()
    if InCombatLockdown() then return false end
    if AddonList and ShowUIPanel then
        local ok=pcall(ShowUIPanel,AddonList)
        if ok and AddonList:IsShown() then
            if self.addonConflictPrompt then self.addonConflictPrompt:Hide() end
            return true
        end
    end
    self:Print("Open Game Menu > AddOns, untick FelBot, and use WoW's own reload prompt. Buff Rag stays paused while FelBot is running.")
    return false
end
function F:CheckAddonConflicts()
    local conflicts,records=self:FindAddonConflicts()
    local paused,changed=self:UpdateAddonConflictPause(records)
    if paused then self:SuspendForAddonConflict()
    elseif changed and self.db and not InCombatLockdown() then self:Refresh() end
    if #conflicts==0 then
        self.addonConflictPending,self.addonConflictWarned=nil,nil
        if self.addonConflictPrompt then self.addonConflictPrompt:Hide() end
        return
    end
    if self.addonConflictWarned and not self.addonConflictPending then return end
                                                                             
    if not self.conflictStartupReady then self.addonConflictPending=true; return end
    if InCombatLockdown() then self.addonConflictPending=true; return end
    self.addonConflictPending=nil
    if not self.addonConflictPrompt then
        local prompt=CreateFrame("Frame","BuffRagAddonConflictPrompt",UIParent,"BasicFrameTemplateWithInset")
        prompt:SetSize(500,230); prompt:SetPoint("CENTER"); prompt:SetFrameStrata("FULLSCREEN_DIALOG"); prompt:SetClampedToScreen(true)
        prompt.TitleText:SetText("FelBot conflicts with Buff Rag")
        local message=prompt:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        message:SetPoint("TOPLEFT",20,-42); message:SetWidth(460); message:SetJustifyH("LEFT")
        local dismiss=CreateFrame("Button",nil,prompt,"UIPanelButtonTemplate")
        dismiss:SetSize(120,26); dismiss:SetPoint("BOTTOMRIGHT",-20,20); dismiss:SetText("Later")
        dismiss:SetScript("OnClick",function() prompt:Hide() end)
        prompt.dismiss,prompt.message=dismiss,message
        local open=CreateFrame("Button",nil,prompt,"UIPanelButtonTemplate")
        open:SetSize(180,26); open:SetPoint("BOTTOMLEFT",20,20); open:SetText("Open AddOns")
        open:SetScript("OnClick",function() F:OpenConflictAddOns() end)
        prompt.open=open
        tinsert(UISpecialFrames,"BuffRagAddonConflictPrompt")
        self.addonConflictPrompt=prompt
    end
    self.addonConflictPrompt.TitleText:SetText("FelBot conflicts with Buff Rag")
    self.addonConflictPrompt.message:SetText("Buff Rag is temporarily paused while FelBot is running. Your saved Buff Rag settings are preserved.\n\nOpen AddOns, untick FelBot for this character, then use WoW's own reload prompt. Buff Rag will resume after FelBot is no longer loaded. Choosing Later leaves Buff Rag paused while FelBot runs.")
    self.addonConflictPrompt:Show()
    self.addonConflictPrompt.open:SetEnabled(not InCombatLockdown())
    self.addonConflictWarned=true
end
                                                                          
                                                                              
local watcher=CreateFrame("Frame")
for _,event in ipairs({"ADDON_LOADED","PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED"}) do watcher:RegisterEvent(event) end
local function check()
    local ok=pcall(F.CheckAddonConflicts,F)
    if not ok and not F.addonConflictErrorReported then
        F.addonConflictErrorReported=true
        F:Print("Could not show the addon conflict warning. Open Game Menu > AddOns to check for conflicting addons.")
    end
end
watcher:SetScript("OnEvent",function(_,event,name)
    if event=="ADDON_LOADED" then
        F:NoteAddonLoaded(name)
        C_Timer.After(0,check)
    elseif event=="PLAYER_REGEN_DISABLED" then F:DeferAddonConflictPrompt()
    elseif event=="PLAYER_REGEN_ENABLED" then check()
    elseif event=="PLAYER_ENTERING_WORLD" then
        C_Timer.After(2,function()
            F.conflictStartupReady=true
            check()
        end)
        C_Timer.After(5,check)
    elseif event=="PLAYER_LOGIN" then
                                                                            
        F.conflictLoginSeen=true
    end
end)
function F:DeferAddonConflictPrompt()
    if self.addonConflictPrompt and self.addonConflictPrompt:IsShown() then
        self.addonConflictPrompt:Hide(); self.addonConflictPending=true
    end
end
