local _,F=...
local function public(value)return not(issecretvalue and issecretvalue(value))end
local visualAuraLimit=4
local function read(fn,...)
    if not fn then return end
    local ok,value=pcall(fn,...)
    if ok and public(value)then return value end
end
local dispelOverrides={
    [8166]={cleanse={Poison=true}},
    [8170]={cleanse={Disease=true}},
}
function F:ActionMetadata(id)
    if dispelOverrides[id] then return dispelOverrides[id] end
    return (self.actionEffects or {})[id]or {}
end
function F:ItemCategory(entry)
    local metadata={}
    local effect,id
    if C_Item.GetItemSpell then
        local ok,a,b=pcall(C_Item.GetItemSpell,entry.id)
        if ok then effect,id=a,b end
        if not(public(id)and type(id)=='number')then
            id=nil
            if public(effect)and type(effect)=='number'then id=effect
            elseif public(effect)and type(effect)=='table'then
                local parsed,value=pcall(function()return effect.spellID or effect.spellId end)
                if parsed and public(value)and type(value)=='number'then id=value end
            end
        end
        if id then metadata=self:ActionMetadata(id)end
    end
    if not metadata.heal and C_Item.GetItemInfoInstant and Enum and Enum.ItemClass and Enum.ItemConsumableSubclass then
        local _,_,_,_,_,class,subclass=C_Item.GetItemInfoInstant(entry.id)
        if public(class) and public(subclass) and class==Enum.ItemClass.Consumable
            and Enum.ItemConsumableSubclass.Bandage~=nil and subclass==Enum.ItemConsumableSubclass.Bandage then
            metadata={heal=true}
        end
    end
    local use=entry.useOn
    if not use or use=='auto'then
        if metadata.selfHealOnly then use='self'
        elseif metadata.heal or metadata.cleanse then use=metadata.purge and 'either'or 'friendly'
        elseif metadata.purge then use='enemy'
        elseif public(id)and type(id)=='number'then
            local help=read(C_Spell.IsSpellHelpful,id)
            local harm=read(C_Spell.IsSpellHarmful,id)
            use=help and(harm and 'either'or 'friendly')or(harm and 'enemy'or 'self')
        else use='friendly'end
    end
    local role=entry.cleanupRole
    if role=='healing' then role='none' end
    if not role or role=='auto'then role=metadata.cleanse and 'cleansing'or 'none' end
    local types=entry.cleanseTypes
    if not entry.cleanseOverride and(not types or not next(types))then types=metadata.cleanse end
    return {useOn=use,role=role,cleanse=role=='cleansing'and types or nil,purge=metadata.purge}
end
function F:ItemTargetAllowed(category,unit,scope)
    local friendly=scope=='targetFriendly'or scope=='focusFriendly'or(scope~='target'and scope~='focus')
    if category.useOn=='self'then return scope=='self'end
    if category.useOn=='enemy'then return not friendly end
    if category.useOn=='friendly'then return friendly end
    return true
end
function F:ItemAction(entry,unit,scope)
    local use=self:ItemCategory(entry).useOn
    local qualifier=(scope=='target'or scope=='focus')and 'harm'or 'help'
    if use=='self'then unit='player';qualifier='help'end
    return {type='macro',macrotext='/use [@'..unit..',exists,'..qualifier..',nodead] item:'..entry.id}
end
                                                                                
function F:InvalidateDispelSnapshots(unit)
    if not unit then self.dispelSnapshots={};return end
    for key in pairs(self.dispelSnapshots or {}) do
        local cachedUnit=key:match('^[^:]+')
        local same=read(UnitIsUnit,unit,cachedUnit)
        if unit==cachedUnit or same==true or same==1 or (same==nil and (cachedUnit=='target' or cachedUnit=='focus')) then
            self.dispelSnapshots[key]=nil
        end
    end
end
function F:DispelSnapshot(unit,filter)
    self.dispelSnapshots=self.dispelSnapshots or {}
    local key=unit..':'..filter
    if self.dispelSnapshots[key]then return self.dispelSnapshots[key]end
    local snapshot={types={},unreadableIDs={},complete=false}
    self.dispelSnapshots[key]=snapshot
    if unit~='player' and self:IsSelf(unit) then
        snapshot=self:DispelSnapshot('player',filter)
        self.dispelSnapshots[key]=snapshot
        return snapshot
    end
    local unreadable=false
    local auraAPI=C_UnitAuras
    local combat=InCombatLockdown()
    if combat and auraAPI and auraAPI.GetAuraDispelTypeColor and auraAPI.GetUnitAuraInstanceIDs then
        local dispellable=AuraUtil and AuraUtil.AuraFilters and AuraUtil.AuraFilters.Dispellable or 'DISPELLABLE'
        local ids=read(auraAPI.GetUnitAuraInstanceIDs,unit,filter..'|'..dispellable,visualAuraLimit)
        if type(ids)=='table' then
            snapshot.nativeIDs={}
            pcall(function()
                for _,id in ipairs(ids) do
                    if public(id) and type(id)=='number' then
                        snapshot.nativeIDs[#snapshot.nativeIDs+1]=id
                        if #snapshot.nativeIDs==visualAuraLimit then break end
                    end
                end
            end)
        end
    end
    local function collect(aura,id)
        if not public(aura) then
            unreadable=true
            if id then snapshot.unreadableIDs[id]=true end
        elseif aura then
            local parsed,kind=pcall(function()
                local value=aura.dispelName
                if public(value) and value==nil then value=aura.dispelType end
                return value
            end)
            if not parsed or not public(kind) then
                unreadable=true
                id=id or read(function() return aura.auraInstanceID end)
                if type(id)=='number' then snapshot.unreadableIDs[id]=true end
            else
                if type(kind)=='number' then
                    local enum=Enum and Enum.DispelType
                    kind=(enum and enum.Bleed==kind and 'Bleed') or ({[1]='Magic',[2]='Curse',[3]='Disease',[4]='Poison',[9]='Enrage'})[kind]
                end
                if type(kind)=='string' then snapshot.types[kind]=true
                elseif combat then
                    id=id or read(function() return aura.auraInstanceID end)
                    if type(id)=='number' then snapshot.unreadableIDs[id]=true end
                end
            end
        elseif combat and id then
            snapshot.unreadableIDs[id]=true
        end
    end
    if C_UnitAuras and C_UnitAuras.GetUnitAuras then
        local ok,auras=pcall(C_UnitAuras.GetUnitAuras,unit,filter)
        if ok and public(auras) and type(auras)=='table' then
            local listed=false
            local scanned=pcall(function()
                for _,aura in ipairs(auras) do listed=true;collect(aura) end
            end)
            if scanned and not unreadable and (not combat or listed) then
                snapshot.complete=true;return snapshot
            end
        end
    end
    if snapshot.nativeIDs and #snapshot.nativeIDs>0 then return snapshot end
    local ids=auraAPI and read(auraAPI.GetUnitAuraInstanceIDs,unit,filter)
    if type(ids)=='table' then
        local scanned=pcall(function()
            for _,id in ipairs(ids) do
                if public(id) then
                    local ok,aura=pcall(auraAPI.GetAuraDataByAuraInstanceID,unit,id)
                    if ok then collect(aura,id) else unreadable=true end
                    if not ok or not public(aura) then snapshot.unreadableIDs[id]=true end
                else unreadable=true end
            end
        end)
        if not scanned then unreadable=true end
    end
    local api=auraAPI and auraAPI.GetAuraDataByIndex
    if not api then return snapshot end
    for index=1,255 do
        local ok,aura=pcall(api,unit,index,filter)
        if not ok then return snapshot end
        if public(aura) and aura==nil then snapshot.complete=not unreadable;return snapshot end
        collect(aura)
    end
    return snapshot
end
function F:MatchingDispel(types,snapshot)
    for kind in pairs(types or {})do if snapshot.types[kind]then return true end end
    if snapshot.complete then return false end
end
function F:CleanupCandidates(unit,candidates)
    if InCombatLockdown()or not self.db.combatClicks then return nil end
    local friend=read(UnitIsFriend,'player',unit)
    if not self:IsSelf(unit)and friend~=true then return nil end
    local dead=read(UnitIsDeadOrGhost,unit)
    local snapshot
    local result={}
    for _,candidate in ipairs(candidates)do
        local effects=candidate.effects or {}
        local relevant=false
        if dead==true then relevant=candidate.allowDead==true
        elseif dead==false and not candidate.allowDead and not candidate.showOutOfCombat
            and effects.cleanse and candidate.dispelReminders~=false then
            snapshot=snapshot or self:DispelSnapshot(unit,'HARMFUL')
            relevant=self:MatchingDispel(effects.cleanse,snapshot)==true
        end
        if candidate.customItem and self:CustomItemCount(candidate.customItem)==0 then relevant=false end
        if relevant then
            candidate=self:CopySettings(candidate)
            candidate.cleanupOnly=true;candidate.queue=false;candidate.prioritySelected=false
            result[#result+1]=candidate
        end
    end
    return #result>0 and result or nil
end
local dispelStyles={
    {"Magic","M",{.2,.6,1},1},
    {"Curse","C",{.65,.28,1},2},
    {"Disease","D",{.78,.54,.22},3},
    {"Poison","P",{.1,.8,.3},4},
    {"Bleed","B",{.9,.22,.22}},
    {"Enrage","E",{1,.52,.1},9},
}
local dispelCurves={}
local enrageIcon='Interface\\TargetingFrame\\UI-RaidTargetingIcon_2'
local function dispelCurve(id)
    if not dispelCurves[id] then
        local curve=C_CurveUtil.CreateColorCurve()
        curve:SetType(Enum.LuaCurveType.Step)
        curve:AddPoint(id-1,CreateColor(1,1,1,0))
        curve:AddPoint(id,CreateColor(1,1,1,1))
        curve:AddPoint(id+1,CreateColor(1,1,1,0))
        dispelCurves[id]=curve
    end
    return dispelCurves[id]
end

local function createDispelSymbol(parent,style)
    local icon=parent:CreateTexture(nil,"OVERLAY",nil,4)
    icon:SetSize(13,13)
    local text=parent:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    text:SetPoint("CENTER",icon,"CENTER",0,0)
    text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",10,"OUTLINE")
    local atlas=AuraUtil and AuraUtil.GetAuraDispelTypeIcon and AuraUtil.GetAuraDispelTypeIcon(style[1])
    if style[1]=='Enrage' then
        icon:SetTexture(enrageIcon)
    elseif atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        icon:SetAtlas(atlas)
        text:SetText("")
    else
        local color=style[3]
        text:SetText(style[2])
        text:SetTextColor(color[1],color[2],color[3])
    end
    return {icon=icon,text=text}
end

function F:CreateDispelExamples(parent,y,hunter)
    for index,style in ipairs(dispelStyles) do
        local enrage=style[1]=="Enrage"
        local left,top=(index-1)%3*128,y+math.floor((index-1)/3)*38
        if enrage then left,top=0,0 end
        local sample=CreateFrame('Frame',nil,enrage and hunter or parent)
        sample:SetPoint('TOPLEFT',left,-top)
        sample:SetSize(32,32)
        local background=sample:CreateTexture(nil,'BACKGROUND')
        background:SetAllPoints()
                                                                     
        background:SetTexture(enrage and 136020 or 'Interface\\Icons\\Spell_Holy_DispelMagic')
        sample.visual=sample
        self:PaintDispelTypes(sample,{[style[1]]=true})
        local symbol=sample.dispelSymbols and sample.dispelSymbols[style[1]]
        if symbol then
            symbol.icon:SetSize(19,19)
            symbol.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",15,"OUTLINE")
        end
        if not enrage then self:AddOptionsText(parent,style[1],left+40,-top-9,80) end
    end
end

function F:PaintDispelTypes(button,types,capabilities,snapshot,unit)
    local symbols=button.dispelSymbols
    if not symbols then
        if InCombatLockdown() then return end
        symbols={}
        button.dispelSymbols=symbols
        for _,style in ipairs(dispelStyles) do
            symbols[style[1]]=createDispelSymbol(button.visual,style)
        end
    end
    local native=C_UnitAuras and C_UnitAuras.GetAuraDispelTypeColor and C_CurveUtil and C_CurveUtil.CreateColorCurve
        and CreateColor and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step
    local nativeIDs=snapshot and snapshot.nativeIDs
    local filteredIDs=nativeIDs and #nativeIDs>0
    local opaque=native and InCombatLockdown() and snapshot and (filteredIDs or next(snapshot.unreadableIDs)~=nil)
    local positions=opaque and capabilities or types
    local count=0
    for _,style in ipairs(dispelStyles) do if positions and positions[style[1]] then count=count+1 end end
    local index=0
    for _,style in ipairs(dispelStyles) do
        local kind,id=style[1],style[4]
        local symbol=symbols[kind]
        local capable=capabilities and capabilities[kind]
        local show=types and types[kind]==true
        if native and capable and id and not symbol.native and not InCombatLockdown() then
            symbol.native={}
            for i=1,visualAuraLimit do symbol.native[i]=createDispelSymbol(button.visual,style) end
        end
        local offset=0
        if positions and positions[kind] then
            index=index+1
            offset=(index-(count+1)/2)*12
        end
        if show then
            symbol.icon:ClearAllPoints()
            symbol.icon:SetPoint("CENTER",button.visual,"CENTER",offset,0)
        end
        symbol.icon:SetShown(show==true)
        symbol.text:SetShown(show==true)
        if symbol.native then
                                                                                 
                                                                          
            local auraID=opaque and capable and not show and (filteredIDs and nativeIDs[1] or next(snapshot.unreadableIDs)) or nil
            for layerIndex,layer in ipairs(symbol.native) do
                local ok,alpha
                if auraID then
                    snapshot.nativeColorAttempted=true
                    ok,alpha=pcall(function()
                        local color=C_UnitAuras.GetAuraDispelTypeColor(unit,auraID,dispelCurve(id))
                        local _,_,_,value=color:GetRGBA()
                        return value
                    end)
                    if ok then snapshot.nativeColorApplied=true end
                    if filteredIDs then auraID=nativeIDs[layerIndex+1]
                    else auraID=next(snapshot.unreadableIDs,auraID) end
                end
                layer.icon:ClearAllPoints()
                layer.icon:SetPoint("CENTER",button.visual,"CENTER",offset,0)
                if not ok then alpha=0 end
                layer.icon:SetAlpha(alpha)
                layer.text:SetAlpha(alpha)
            end
        end
    end
end
function F:UpdateDispelReminder(button,prepareOnly)
    if button.nativeDispel and button.nativeDispel.unit and InCombatLockdown() then return end
    local matches,types,snapshot,unit
    local effects=button.effects or {}
    if button.buffUnit and button.dispelReminders~=false and(effects.cleanse or effects.purge)then
        local friend
        if button.dispelRelation then friend=button.dispelRelation=="friendly"
        elseif self:IsSelf(button.buffUnit) then friend=true
        else friend=read(UnitIsFriend,'player',button.buffUnit) end
        types=friend==true and effects.cleanse or(friend==false and effects.purge or nil)
        if types then
            unit=self:IsSelf(button.buffUnit) and 'player' or button.buffUnit
            if not prepareOnly then snapshot=self:DispelSnapshot(unit,friend and 'HARMFUL'or 'HELPFUL') end
        end
    end
    if types==button.paintedDispelTypes and snapshot==button.paintedDispelSnapshot then return end
    button.paintedDispelTypes,button.paintedDispelSnapshot=types,snapshot
    if snapshot then
        matches={}
        for kind in pairs(types) do if snapshot.types[kind] then matches[kind]=true end end
    end
    if effects.cleanse or effects.purge or button.dispelSymbols then self:PaintDispelTypes(button,matches,types,snapshot,unit) end
end

local function setNativeDispelSlot(state,button,key,filter,candidates)
    local container=state.container
    if state.slots[key] then
        container:SetAuraSlotFilterString(key,filter)
        container:SetAuraSlotCandidateFilters(key,candidates)
        container:SetAuraSlotEnabled(key,true)
        return
    end
    local styles=Enum.CustomAuraButtonDispelTypeTextureStyle
    container:AddAuraSlot(key,filter,{
        sortMethod=AuraContainerSortMethod.UnitFrameDebuff,
        candidateFilters=candidates,
        initializeFrame=function(frame)
            frame:SetPoint('CENTER',button.visual,'CENTER')
            frame:SetSize(13,13)
            frame:SetMouseClickEnabled(false)
            frame:SetMouseMotionEnabled(false)
            local icon=frame:CreateTexture(nil,'OVERLAY')
            icon:SetAllPoints()
            if key=='enrage' then
                icon:SetTexture(enrageIcon)
                frame:AddDispelTypeTexture(icon,{
                    style=styles.PreserveAsset,showWhenHelpful=true,showWithoutDispelType=true,
                    customDispelColorCurve=dispelCurve(9),
                })
            else
                frame:AddDispelTypeTexture(icon,{style=styles.Icon,showWhenHelpful=true})
            end
        end,
    })
    state.slots[key]=true
end

local function sameDispelTypes(first,second)
    if first==second then return true end
    if not first or not second then return false end
    for kind in pairs(first) do if not second[kind] then return false end end
    for kind in pairs(second) do if not first[kind] then return false end end
    return true
end

function F:PrepareNativeDispel(button,combatOnly)
    local friendly=button.dispelRelation~='enemy'
    local effects=button.effects or {}
    local types=combatOnly and button.dispelReminders~=false
        and (friendly and effects.cleanse or (not friendly and effects.purge))
    local unit=types and button.buffUnit or nil
    if unit and self:IsSelf(unit) then unit='player' end
    local state=button.nativeDispel
    if not unit then
        if state and state.unit then
            state.container:SetEnabled(false)
            state.container:Hide()
            state.unit=nil
        end
        return
    end
    local filter
    if button.customItem then filter=friendly and 'HARMFUL|DISPELLABLE' or 'HELPFUL|DISPELLABLE'
    else filter=friendly and 'HARMFUL|RAID' or 'HELPFUL|RAID_PLAYER_DISPELLABLE' end
    local sameFilters=state and state.filter==filter and sameDispelTypes(state.types,types)
    if state and (state.error or (state.unit==unit and sameFilters)) then return end
    local styles=Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
    local sort=AuraContainerSortMethod and AuraContainerSortMethod.UnitFrameDebuff
    state=state or {slots={}}
    button.nativeDispel=state
    if not styles or styles.Icon==nil or sort==nil then
        state.error='API unavailable'
        return
    end
    local ok=pcall(function()
        local container=state.container
        if not container then
            container=CreateFrame('AuraContainer',nil,button.visual,'CustomAuraContainerTemplate')
            state.container=container
            container:Hide()
            container:SetPoint('CENTER',button.visual,'CENTER')
            container:SetSize(1,1)
            container:SetMouseClickEnabled(false)
            container:SetMouseMotionEnabled(false)
        end
        if not sameFilters then
            local named={}
            for _,style in ipairs(dispelStyles) do
                local kind=style[1]
                if kind~='Enrage' and types[kind] then named[kind]=true end
            end
            if next(named) then
                setNativeDispelSlot(state,button,'dispel',filter,{includeDispelTypes=named})
            elseif state.slots.dispel then container:SetAuraSlotEnabled('dispel',false) end
            if not friendly and types.Enrage then
                setNativeDispelSlot(state,button,'enrage',filter,{
                    excludeDispelTypes={Magic=true,Curse=true,Disease=true,Poison=true,Bleed=true},
                })
            elseif state.slots.enrage then container:SetAuraSlotEnabled('enrage',false) end
        end
        container:SetUnit(unit)
        container:SetEnabled(true)
        container:Show()
    end)
    if ok then
        state.unit,state.types,state.filter=unit,self:CopySettings(types),filter
    else
        if state.container then state.container:Hide() end
        state.unit=nil
        state.error='setup failed'
    end
end
function F:FrameCombatCandidates(unit,kind,rowCache)
    local all={}
    local profiles=(kind=='target'or kind=='focus')and {kind,kind..'Friendly'}or {self:CombatScopeFor(unit,kind)}
    for _,profile in ipairs(profiles)do
        for _,candidate in ipairs(self:BuildCombatCandidates(unit,kind,false,profile,rowCache))do all[#all+1]=candidate end
    end
    return all
end
function F:FrameCleanupCandidates(unit,kind,candidates)
    local selected={}
    local profile=(kind=='target'or kind=='focus')and(kind..'Friendly')or self:CombatScopeFor(unit,kind)
    for _,candidate in ipairs(candidates)do if candidate.profile==profile then selected[#selected+1]=candidate end end
    return self:CleanupCandidates(unit,selected)
end
function F:ReportPostCombat()
    local combat=InCombatLockdown()
    self:Print('v'..self.version..' Post-combat diagnostics ('..(combat and 'in combat' or 'out of combat')..').')
    if not combat then self.dispelSnapshots={} end
    for frame,overlay in pairs(self.overlays) do
        local unit=overlay.frameKind=='self' and 'player' or frame.unit
        if public(unit) and unit and frame:IsVisible() and read(UnitExists,unit) then
            local names,nativeOverlays={},{}
            for _,button in ipairs(overlay.indicators.squares) do
                if button:IsShown() and (button.cleanupOnly or button.outOfCombat or (combat and button.combatOnly)) then
                    names[#names+1]=button.buffName
                    local native=button.nativeDispel
                    if native and (native.unit or native.error) then
                        nativeOverlays[#nativeOverlays+1]=button.buffName..' '..(native.unit and 'ready' or native.error)
                    end
                end
            end
            local snapshot=self:DispelSnapshot(unit,'HARMFUL')
            local auraTypes={}
            for kind in pairs(snapshot.types) do auraTypes[#auraTypes+1]=kind end
            table.sort(auraTypes)
            self:Print(overlay.frameKind..' ['..unit..']: actions '..(#names>0 and table.concat(names,', ') or 'none')
                ..'; readable harmful types '..(#auraTypes>0 and table.concat(auraTypes,', ') or 'none')
                ..'; aura scan '..(snapshot.complete and 'complete' or 'restricted/incomplete')
                ..(combat and ('; filtered dispel IDs '..#(snapshot.nativeIDs or {})
                 ..'; native colour '..(snapshot.nativeColorApplied and 'applied' or (snapshot.nativeColorAttempted and 'unavailable' or 'not used'))
                 ..(#nativeOverlays>0 and ('; Blizzard overlays '..table.concat(nativeOverlays,', ')) or '')) or '')..'.')
        end
    end
end
function F:CombatVisibility(candidate,unit,duel)
    local dual=unit=="target" or unit=="focus"
    local relation=dual and (candidate.targetRule=="enemy" and "harm," or "help,noharm,") or ""
    local condition='[@'..unit..',exists,'..relation..(candidate.allowDead and 'dead'or 'nodead')..']'
    if candidate.cleanupOnly or candidate.outOfCombat then return '[combat] hide; '..condition..' show; hide'end
    if candidate.allowDead and not candidate.combatRes then return 'hide'end
    return "["..(duel and "" or "combat,").."@"..unit..",exists,"..relation..(candidate.allowDead and "dead" or "nodead").."] show; hide"
end
