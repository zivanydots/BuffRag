local _,F=...
local shared={windowPosition=true,windowWidth=true,windowHeight=true,windowScale=true,windowZoom=true,minimapEnabled=true,minimapAngle=true}
local scopes={"self","party","raid","target","targetFriendly","focus","focusFriendly"}
local prefix="BuffRag1:"
local maxExport=524288

local function store()
    if type(BuffRagProfilesDB)~="table" then BuffRagProfilesDB={} end
    local db=BuffRagProfilesDB
    if type(db.profiles)~="table" then db.profiles={} end
    if type(db.active)~="string" then db.active="Default" end
    return db
end

local function snapshot(self,source)
    local copy=self:CopySettings(source)
    for key in pairs(shared) do copy[key]=nil end
    for _,row in pairs(copy.combatRows) do
        for _,frame in pairs(row.frames or {}) do frame.keybindOverride=nil end
    end
    return copy
end

local function copyLocalFacts(self,destination)
    for key in pairs(shared) do destination[key]=BuffRagDB[key] end
    destination.knownPoisons=self:CopySettings(BuffRagDB.knownPoisons or {})
    for key,row in pairs(BuffRagDB.combatRows) do
        if row.petIDs then
            local result=destination.combatRows[key] or {}
            result.petIDs=self:CopySettings(row.petIDs)
            result.petLearnedIDs=self:CopySettings(row.petLearnedIDs or {})
            result.petAllowed=row.petAllowed and self:CopySettings(row.petAllowed) or nil
            destination.combatRows[key]=result
        end
    end
end

local function reportSettings(self,settings)
    local unavailable,conflicts,seen=0,0,{}
    for key,row in pairs(settings.combatRows) do
        local group=self.combatCatalogue and self.combatCatalogue[key]
        local enabled=false
        for _,frame in pairs(row.frames or {}) do
            enabled=enabled or frame.enabled
            local chord=frame.enabled and frame.keybind
            if chord and not seen[chord] and GetBindingAction then
                seen[chord]=true
                local action,override=GetBindingAction(chord),GetBindingAction(chord,true)
                if (action and action~="") or (override and override~="" and not (self.combatKeyActionNames and self.combatKeyActionNames[override])) then
                    conflicts=conflicts+1
                end
            end
        end
        if enabled and (not group or not group.learned) then unavailable=unavailable+1 end
    end
    return unavailable,conflicts
end

function F:ProfileActiveName()
    return store().active
end

function F:SaveNamedProfile(name)
    if InCombatLockdown() then return false,"Save profiles outside combat." end
    name=name:match("^%s*(.-)%s*$")
    if name=="" or #name>48 or name:find("[%c|]") then return false,"Enter a profile name of up to 48 characters." end
    local db=store()
    if name==db.active or db.profiles[name] then return false,"That profile already exists." end
    local previous=snapshot(self,BuffRagDB)
    if self:OptionsDirty() and not self:SaveOptions() then return false,"Resolve any pending keybind conflicts first." end
    db.profiles[db.active],db.active=previous,name
    self:Print("Active profile: "..name)
    return true
end

function F:SwitchNamedProfile(name)
    if InCombatLockdown() then return false,"Switch profiles outside combat." end
    local db=store()
    if name==db.active then return true end
    if self:OptionsDirty() then return false,"Save or discard your changes before switching profiles." end
    local stored=db.profiles[name]
    if not stored then return false,"Profile not found." end
    local settings=self:UpgradeSettings(snapshot(self,stored))
    copyLocalFacts(self,settings)
    local _,conflicts=reportSettings(self,settings)
    db.profiles[db.active]=snapshot(self,BuffRagDB)
    db.profiles[name]=nil
    db.active=name
    BuffRagDB=settings
    self.db=self.editingOptions and self:CopySettings(settings) or settings
    self.combatBookDirty=true
    self:Refresh()
    local manager=self.options and self.options.profileManager
    if manager and manager:IsShown() then manager.active:SetText("Active profile: "..name) end
    self:Print("Active profile: "..name)
    if conflicts>0 then self:Print(conflicts.." Combat shortcuts conflict with existing bindings and stay inactive.") end
    return true
end

function F:OpenProfileMenu(owner)
    if InCombatLockdown() then self:Print("Switch profiles outside combat.");return end
    if not MenuUtil or not MenuUtil.CreateContextMenu then return end
    local db=store()
    local names={db.active}
    for name in pairs(db.profiles) do names[#names+1]=name end
    table.sort(names)
    MenuUtil.CreateContextMenu(owner,function(_,menu)
        menu:CreateTitle("Buff Rag profiles")
        for _,name in ipairs(names) do
            local label=name==db.active and name.." (active)" or name
            menu:CreateButton(label,function()
                local ok,message=F:SwitchNamedProfile(name)
                if not ok then F:Print(message) end
            end)
        end
        menu:CreateButton("Manage profiles",function() F:OpenProfileManager() end)
    end)
end

local function typed(value,kind)
    if type(value)~=kind then return end
    if kind=="number" and (value~=value or math.abs(value)>2147483647) then return end
    if kind=="string" and #value>200 then return end
    return value
end

local function fields(source,schema)
    local result={}
    for key,kind in pairs(schema) do result[key]=typed(source[key],kind) end
    return result
end

local function map(source,kind)
    local result={}
    for key,value in pairs(type(source)=="table" and source or {}) do
        if type(key)=="string" and #key<=200 then result[key]=typed(value,kind) end
    end
    return result
end

local function order(source)
    local result={}
    for _,value in ipairs(type(source)=="table" and source or {}) do
        if type(value)=="string" and #value<=200 then result[#result+1]=value end
    end
    return result
end

local itemSchema={id="number",enabled="boolean",queue="boolean",self="boolean",party="boolean",raid="boolean",target="boolean",
    focus="boolean",combat="boolean",buffVisible="boolean",prioritySelected="boolean",buffMode="string",buffSpellID="number",buffName="string",
    useOn="string",cleanupRole="string",dispelReminders="boolean",cleanseOverride="boolean"}
local frameSchema={enabled="boolean",outOfCombat="boolean",dispelReminders="boolean",rankID="number",keybind="string"}

local function sanitize(self,source)
    local result={class=self.class,schema=self.defaults.schema,combatMatrixVersion=1}
    for key,value in pairs(self.defaults) do
        if not shared[key] and type(value)~="table" then result[key]=typed(source[key],type(value)) end
    end
    local modifiers={shift=true,ctrl=true,alt=true,off=true}
    if not modifiers[result.frameModifier] then result.frameModifier=nil end
    if not modifiers[result.priorityModifier] then result.priorityModifier=nil end
    for _,key in ipairs({"combatOpacity","drOpacity"}) do
        if result[key] then result[key]=math.max(0,math.min(100,result[key])) end
    end
    for key,value in pairs(result) do
        if type(value)=="number" and key:lower():match("size$") then result[key]=math.max(10,math.min(60,value)) end
    end
    if result.spacing then result.spacing=math.max(0,math.min(30,result.spacing)) end
    for _,key in ipairs({"keepStones","keepCreated","priorityBuffs","standardQueue","buffEnabled","buffs"}) do result[key]=map(source[key],"boolean") end
    result.poisonHands=map(source.poisonHands,"string")
    result.priority=order(source.priority)
    result.combatOrder=order(source.combatOrder)
    result.targetScopes={}
    for key,value in pairs(type(source.targetScopes)=="table" and source.targetScopes or {}) do
        if type(key)=="string" and self.spells[key] then result.targetScopes[key]=map(value,"boolean") end
    end
    result.items={}
    for _,item in ipairs(type(source.items)=="table" and source.items or {}) do
        if type(item)=="table" then
            local clean=fields(item,itemSchema)
            clean.cleanseTypes=map(item.cleanseTypes,"boolean")
            result.items[#result.items+1]=clean
        end
    end
    result.combatRows,result.combatOrders={},{}
    for _,scope in ipairs(scopes) do
        if type(source.combatOrders)=="table" and source.combatOrders[scope] then result.combatOrders[scope]=order(source.combatOrders[scope]) end
    end
    for key,row in pairs(type(source.combatRows)=="table" and source.combatRows or {}) do
        if type(key)=="string" and #key<=200 and type(row)=="table" then
            local clean={bindings=map(row.bindings,"string"),frames={}}
            for _,scope in ipairs(scopes) do
                local frame=type(row.frames)=="table" and row.frames[scope]
                if type(frame)=="table" then
                    local values=fields(frame,frameSchema)
                    if values.keybind and (#values.keybind>48 or values.keybind:find("[%c|]")) then values.keybind=nil end
                    clean.frames[scope]=values
                end
            end
            result.combatRows[key]=clean
        end
    end
    return result
end

function F:ExportProfileSettings()
    local codec=C_EncodingUtil
    if not codec or not codec.SerializeCBOR or not codec.EncodeBase64 then return nil,"Settings codes are unavailable in this client." end
    local ok,code=pcall(function()
        local data=sanitize(self,snapshot(self,self.db))
        return codec.EncodeBase64(codec.SerializeCBOR(data))
    end)
    if not ok or not code or #code+#prefix>maxExport then return nil,"Could not create a settings code." end
    return prefix..code
end

function F:ReadProfileSettings(code)
    local codec=C_EncodingUtil
    if not codec or not codec.DecodeBase64 or not codec.DeserializeCBOR then return nil,"Settings codes are unavailable in this client." end
    if #code>maxExport then return nil,"This settings code is too long." end
    code=code:match("^%s*(.-)%s*$")
    if code:sub(1,#prefix)~=prefix then return nil,"Paste a Buff Rag settings code." end
    local ok,data=pcall(function()return codec.DeserializeCBOR(codec.DecodeBase64(code:sub(#prefix+1)))end)
    if not ok or type(data)~="table" or type(data.class)~="string"
        or type(data.items)~="table" or type(data.priority)~="table" or type(data.combatRows)~="table" then
        return nil,"This settings code could not be read."
    end
    if data.class~=self.class then return nil,"This code is for "..data.class..". Import it on a character of that class." end
    local settings=self:UpgradeSettings(sanitize(self,data))
    copyLocalFacts(self,settings)
    return settings
end

function F:OpenProfileManager()
    if InCombatLockdown() then return end
    self:OpenOptions()
    local panel=self.options
    local window=panel.profileManager
    if not window then
        window=self:CreateDetailOptions("BuffRagProfiles",440,210)
        panel.profileManager=window
        window.detailIcon:SetTexture(self.itemsIcon)
        window.detailTitle:SetText("Profiles")
        window.active=self:AddOptionsText(window,"",13,-54,410)
        local name=CreateFrame("EditBox",nil,window,"InputBoxTemplate")
        self:AddOptionsText(window,"New profile name",13,-78,220)
        name:SetPoint("TOPLEFT",19,-98);name:SetSize(220,23);name:SetAutoFocus(false)
        local save=CreateFrame("Button",nil,window,"UIPanelButtonTemplate")
        save:SetPoint("LEFT",name,"RIGHT",10,0);save:SetSize(158,24);save:SetText("Save as profile")
        local switch=CreateFrame("Button",nil,window,"UIPanelButtonTemplate")
        switch:SetPoint("TOPLEFT",13,-133);switch:SetSize(140,24);switch:SetText("Switch profile")
        switch:SetScript("OnClick",function(button) F:OpenProfileMenu(button) end)
        window.message=self:AddOptionsText(window,"",13,-162,410)
        save:SetScript("OnClick",function()
            local ok,message=F:SaveNamedProfile(name:GetText())
            window.message:SetText(message or "Profile saved.")
            if ok then name:SetText("");name:ClearFocus() end
            window.active:SetText("Active profile: "..F:ProfileActiveName())
        end)
        name:SetScript("OnEscapePressed",function()name:ClearFocus()end)
        window:HookScript("OnShow",function()window.active:SetText("Active profile: "..F:ProfileActiveName())end)
    end
    self:PositionFloatingOptions(window,panel,"CENTER",0,0)
    window:Show()
end

function F:OpenProfileTransfer(importing)
    if InCombatLockdown() then return end
    local panel=self.options
    local window=panel.profileTransfer
    if not window then
        local button
        window,button=self:CreateDetailOptions("BuffRagProfileTransfer",590,312)
        panel.profileTransfer=window
        window.detailIcon:SetTexture(self.itemsIcon)
        window.confirm=button
        window.description=self:AddOptionsText(window,"",12,-53,550)
        window.message=self:AddOptionsText(window,"",12,-226,550)
        local scroll=CreateFrame("ScrollFrame",nil,window,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",12,-83);scroll:SetPoint("BOTTOMRIGHT",-32,93)
        local box=CreateFrame("EditBox",nil,scroll)
        box:SetMultiLine(true);box:SetAutoFocus(false);box:EnableMouse(true)
        box:SetFontObject(ChatFontNormal);box:SetWidth(540)
        box:SetScript("OnEscapePressed",function()box:ClearFocus()end)
        scroll:SetScrollChild(box)
        window.box,window.scroll=box,scroll
        box:SetScript("OnTextChanged",function()
            window.pending=nil
            window.message:SetText("")
            window.confirm:SetText(window.importing and "Preview" or "OK")
        end)
        button:SetScript("OnClick",function()
            if not window.importing then window:Hide();return end
            if InCombatLockdown() then return end
            if window.pending then
                F.db=window.pending
                F.bindingDraft=nil
                F.combatBookDirty=true
                F:Refresh()
                F:Print("Settings imported into your draft. Click Save to keep them.")
                window:Hide()
                return
            end
            local settings,reason=F:ReadProfileSettings(box:GetText())
            if not settings then window.message:SetText(reason);return end
            local unavailable,conflicts=reportSettings(F,settings)
            window.pending=settings
            window.message:SetText(string.format("%d bag items. %d unavailable combat abilities. %d conflicting shortcuts stay inactive. Apply replaces the current draft.",#settings.items,unavailable,conflicts))
            button:SetText("Apply")
        end)
    end
    window.importing=importing
    window.detailTitle:SetText(importing and "Import settings" or "Export settings")
    window.description:SetText(importing and "Paste a settings code from the same class, then click Preview." or "Copy this code to back up or share the settings shown in Buff Rag.")
    local code,reason
    if not importing then code,reason=self:ExportProfileSettings() end
    window.box:SetText(code or "")
    window.message:SetText(reason or "")
    window.pending=nil
    window.confirm:SetText(importing and "Preview" or "OK")
    window.scroll:SetVerticalScroll(0)
    self:PositionFloatingOptions(window,panel,"CENTER",0,0)
    window:Show()
    window.box:SetFocus()
    if not importing then window.box:HighlightText() end
end
