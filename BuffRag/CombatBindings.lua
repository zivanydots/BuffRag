local _,F=...
local keyUnits={target='target',targetFriendly='target',focus='focus',focusFriendly='focus'}
local slots={'type','spell','item','macrotext'}
local contexts={'combat-friendly','combat-friendly-dead','combat-enemy','safe-friendly','safe-friendly-dead','safe-enemy'}
local targetDriver=table.concat({
    '[combat,@target,help,dead] combat-friendly-dead',
    '[combat,@target,harm,nodead] combat-enemy',
    '[combat,@target,help,nodead] combat-friendly',
    '[combat] none',
    '[@target,help,dead] safe-friendly-dead',
    '[@target,harm,nodead] safe-enemy',
    '[@target,help,nodead] safe-friendly',
    'none',
},'; ')
local drivers={target=targetDriver,focus=targetDriver:gsub('@target','@focus')}

function F:CombatKeyUnit(scope)
    return keyUnits[scope]
end

function F:CanBindCombatRow(group,scope)
    local config=group and self.db.combatRows[group.key]
    local frame=config and config.frames and config.frames[scope]
    return keyUnits[scope] and self:CombatGroupVisible(group,scope) and group.learned and not group.itemPlaceholder and group.allowed[scope]
        and frame and frame.enabled and config.bindings[scope]=='icon'
end

function F:IsCombatKeyReserved(key)
    for _,row in pairs(self.db.combatRows) do
        for scope in pairs(keyUnits) do
            local frame=row.frames and row.frames[scope]
            if frame and frame.keybind==key then return true end
        end
    end
    return false
end

local function freeKey(self,key)
    if GetBindingAction then
        local action=GetBindingAction(key)
        if action and action~='' then return false end
        local override=GetBindingAction(key,true)
        if override and override~='' and not (self.combatKeyActionNames and self.combatKeyActionNames[override]) then return false end
    end
    return true
end

function F:ValidateCombatKeybind(key,scope,chord)
    if InCombatLockdown() or not self.db.combatClicks or not self:CanBindCombatRow(self.combatCatalogue[key],scope) then
        return false,'Use an Icon only row on the Target or Focus tab.'
    end
    if not chord then return true end
    if not freeKey(self,chord) then return false,'That key is already bound. Choose another key.' end
    for _,staged in ipairs(self.bindingDraft and self.bindingDraft.keys or {}) do
        if staged==chord then return false,'That key is reserved for the Buff Rag queue.' end
    end
    for other,config in pairs(self.db.combatRows) do
        local frame=config.frames and config.frames[scope]
        if other~=key and frame and frame.keybind==chord then return false,'That key is already assigned on this profile.' end
        for otherScope,unit in pairs(keyUnits) do
            local otherFrame=config.frames and config.frames[otherScope]
            if unit~=keyUnits[scope] and otherFrame and otherFrame.keybind==chord then
                return false,'That key is already assigned to the '..(unit=='target' and 'Target' or 'Focus')..' Frame.'
            end
        end
    end
    return true
end

function F:SetCombatKeybind(key,scope,chord)
    local valid,reason=self:ValidateCombatKeybind(key,scope,chord)
    if not valid then return false,reason end
    self:CombatFrameSettings(key,scope).keybind=chord
    self:Refresh()
    return true
end

function F:CollectCombatKeybind(bindings,candidate,square,unit)
    local safe=candidate.outOfCombat or candidate.cleanupOnly
    if not safe and candidate.allowDead and not candidate.combatRes then return end
    local context=(safe and 'safe-' or 'combat-')..(candidate.targetRule or 'friendly')..(candidate.allowDead and '-dead' or '')
    local routes=bindings[candidate.keybind] or {unit=unit}
    if routes.unit~=unit then return end
    routes[context]={action=candidate.action,icon=square}
    bindings[candidate.keybind]=routes
end

local function createKeyButton(self,owner)
    local name='BuffRagCombatKey'..(#self.combatKeyPool+1)
    local button=CreateFrame('Button',name,owner,'SecureActionButtonTemplate,SecureHandlerStateTemplate')
    button:RegisterForClicks('AnyDown')
    button:SetAttribute('useOnKeyDown',true)
    button:SetAttribute('checkselfcast',false)
    button:SetAttribute('checkfocuscast',false)
    button:SetAttribute('_onstate-keycontext',[[
        self:SetAttribute('*type1',self:GetAttribute(newstate..'-type'))
        self:SetAttribute('*spell1',self:GetAttribute(newstate..'-spell'))
        self:SetAttribute('*item1',self:GetAttribute(newstate..'-item'))
        self:SetAttribute('*macrotext1',self:GetAttribute(newstate..'-macrotext'))
    ]])
    button:SetScript('PreClick',function(_,mouse)
        local route=button.routes and button.routes[button:GetAttribute('state-keycontext') or 'none']
        button.feedbackIcon=route and route.icon
        if button.feedbackIcon then F:BeginIconCast(button.feedbackIcon,mouse,false) end
    end)
    button:SetScript('PostClick',function(_,mouse)
        if button.feedbackIcon then F:EndIconCast(button.feedbackIcon,mouse,false) end
        button.feedbackIcon=nil
    end)
    self.combatKeyActionNames['CLICK '..name..':LeftButton']=true
    return button
end

function F:SyncCombatKeybinds(bindings)
    if InCombatLockdown() or not SetOverrideBindingClick or not ClearOverrideBindings then return end
    if not self.combatKeyOwner then
        if not next(bindings) then return end
        self.combatKeyOwner=CreateFrame('Frame',nil,UIParent)
        self.combatKeyPool,self.combatKeyActionNames,self.combatKeyAssignments={},{},{}
    end
    local keys={}
    for key in pairs(bindings) do if freeKey(self,key) then keys[#keys+1]=key end end
    table.sort(keys)
    local changed=#keys~=#self.combatKeyAssignments
    for index,key in ipairs(keys) do
        local button=self.combatKeyPool[index]
        if not button then button=createKeyButton(self,self.combatKeyOwner);self.combatKeyPool[index]=button end
        changed=changed or self.combatKeyAssignments[index]~=key
        local routes=bindings[key]
        for _,context in ipairs(contexts) do
            local action=routes[context] and routes[context].action
            for _,slot in ipairs(slots) do
                local attribute=context..'-'..slot
                local value=action and action[slot]
                if button:GetAttribute(attribute)~=value then button:SetAttribute(attribute,value) end
            end
        end
        button.routes=routes
        local driver=drivers[routes.unit]
        local changedUnit=button.keyDriver~=driver
        if changedUnit then
            RegisterStateDriver(button,'keycontext',driver)
            button.keyDriver=driver
        end
        local state=(not changedUnit and button:GetAttribute('state-keycontext'))
            or (SecureCmdOptionParse and SecureCmdOptionParse(driver)) or 'none'
        for _,slot in ipairs(slots) do
            local attribute='*'..slot..'1'
            local value=button:GetAttribute(state..'-'..slot)
            if button:GetAttribute(attribute)~=value then button:SetAttribute(attribute,value) end
        end
    end
    if changed then
        ClearOverrideBindings(self.combatKeyOwner)
        for index,key in ipairs(keys) do SetOverrideBindingClick(self.combatKeyOwner,false,key,self.combatKeyPool[index]:GetName(),'LeftButton') end
        self.combatKeyAssignments=keys
    end
end

