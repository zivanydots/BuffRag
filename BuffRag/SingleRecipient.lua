local _, F = ...
local function public(value) return not (issecretvalue and issecretvalue(value)) end
                                                                             
                                                                           
                                                                      
function F:RefreshSingleRecipientBuffs()
    self.singleRecipientBuffs=self.singleRecipientBuffs or {}
    for _,entry in ipairs(self.catalogue) do
        if entry.singleRecipient then
            local previous=self.singleRecipientBuffs[entry.key]
            local found,previousVisible=false,false
            local units={"player","target"}
            for i=1,4 do units[#units+1]="party"..i end
            for i=1,40 do units[#units+1]="raid"..i end
            for _,unit in ipairs(units) do
                local exists=UnitExists(unit)
                local visible=not UnitIsVisible or UnitIsVisible(unit)
                if public(exists) and exists and public(visible) and visible then
                    local guid=UnitGUID and UnitGUID(unit)
                    local complete=true
                    for index=1,255 do
                        local ok,aura=pcall(C_UnitAuras.GetAuraDataByIndex,unit,index,"HELPFUL")
                        if not ok or not public(aura) then complete=false; break end
                        if not aura then break end
                        if not public(aura.spellId) or not public(aura.sourceUnit) then complete=false; break end
                        local matches=false
                        for _,id in ipairs(entry.ids) do if aura.spellId==id then matches=true; break end end
                        if matches and not aura.sourceUnit then complete=false; break end
                        if matches and aura.sourceUnit and F:IsSelf(aura.sourceUnit) then
                            local expires=public(aura.expirationTime) and type(aura.expirationTime)=="number" and aura.expirationTime>GetTime()
                                and aura.expirationTime or GetTime()+entry.duration
                            found={unit=unit,guid=public(guid) and guid or nil,expires=expires}
                            break
                        end
                    end
                    if previous and previous.guid and public(guid) and previous.guid==guid and complete then previousVisible=true end
                    if found then break end
                end
            end
            if found then self.singleRecipientBuffs[entry.key]=found
            elseif previous and ((previousVisible and GetTime()>=(previous.graceUntil or 0)) or previous.expires<=GetTime()) then
                self.singleRecipientBuffs[entry.key]=nil
            end
        end
    end
end
function F:RecordSingleRecipientCast(unit,spellID)
    if unit~="player" or not public(spellID) then return end
    for _,entry in ipairs(self.catalogue) do
        if entry.singleRecipient then
            for _,id in ipairs(entry.ids) do
                if id==spellID then
                    self.singleRecipientBuffs=self.singleRecipientBuffs or {}
                    self.singleRecipientBuffs[entry.key]={expires=GetTime()+entry.duration,graceUntil=GetTime()+1}
                    return
                end
            end
        end
    end
end
function F:SingleRecipientActive(entry)
    local active=self.singleRecipientBuffs and self.singleRecipientBuffs[entry.key]
    return active and active.expires>GetTime() or false
end
