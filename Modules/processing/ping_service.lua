local addonName, addon = ...

local PingService = {}
addon.PingService = PingService

function PingService:Initialize()
    addon.Logger:Debug("PingService", "Ping service initialized")
end

function PingService:GetTalentOverrideSpell(spellID)
    if not spellID then
        return spellID
    end
    
    local overrideID = spellID
    
    if FindSpellOverrideByID then
        local result = FindSpellOverrideByID(spellID)
        if result and result ~= spellID then
            overrideID = result
        end
    end
    
    if overrideID == spellID and C_SpellBook and C_SpellBook.GetOverrideSpell then
        local result = C_SpellBook.GetOverrideSpell(spellID)
        if result and result ~= spellID then
            overrideID = result
        end
    end
    
    return overrideID
end

function PingService:GetSpellCharges(spellID)
    if not spellID then
        return nil, nil, nil
    end
    
    local chargeInfo = C_Spell.GetSpellCharges(spellID)
    if not chargeInfo then
        return nil, nil, nil
    end
    
    return chargeInfo.currentCharges, chargeInfo.maxCharges, chargeInfo.cooldownDuration
end

function PingService:FormatCooldownTime(timeRemaining)
    if timeRemaining <= 0 then
        return "0s"
    end
    
    if timeRemaining < 60 then
        return string.format("%.0fs", timeRemaining)
    elseif timeRemaining < 3600 then
        local minutes = math.floor(timeRemaining / 60)
        local seconds = math.floor(timeRemaining % 60)
        return string.format("%dm %ds", minutes, seconds)
    else
        local hours = math.floor(timeRemaining / 3600)
        local minutes = math.floor((timeRemaining % 3600) / 60)
        return string.format("%dh %dm", hours, minutes)
    end
end

function PingService:GetChargesCooldownTime(spellID)
    if not spellID then
        return false, 0
    end
    
    local chargeInfo = C_Spell.GetSpellCharges(spellID)
    if not chargeInfo then
        return false, 0
    end
    
    if chargeInfo.cooldownDuration <= 0 then
        return false, 0
    end
    
    local currentTime = GetTime()
    local timeRemaining = (chargeInfo.cooldownStartTime + chargeInfo.cooldownDuration) - currentTime
    
    if timeRemaining <= 0 then
        return false, 0
    end
    
    return true, timeRemaining
end

function PingService:GetCooldownTime(spellID)
    if not spellID then
        return nil, nil
    end
    
    local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
    if not cooldownInfo or cooldownInfo.duration <= 0 then
        return false, 0
    end
    
    local currentTime = GetTime()
    local timeRemaining = (cooldownInfo.startTime + cooldownInfo.duration) - currentTime
    
    if timeRemaining <= 0 then
        return false, 0
    end
    
    return true, timeRemaining
end

function PingService:PingSpellCooldown(spellID)
    if not spellID then
        addon.Logger:Error("PingService", "No spell ID provided")
        return
    end

    local finalSpellID = self:GetTalentOverrideSpell(spellID)
    
    if finalSpellID ~= spellID then
        addon.Logger:Debug("PingService", string.format("Talent override detected: %d -> %d", spellID, finalSpellID))
    end

    if addon.RateLimiter and addon.RateLimiter.CanSendMessage then
        local canSend, reason = addon.RateLimiter:CanSendMessage()
        if not canSend then
            addon.Logger:Warning("PingService", "Rate limited: " .. (reason or "Unknown"))
            return
        end
    end

    local spellLink = C_Spell.GetSpellLink(finalSpellID)
    if not spellLink then
        addon.Logger:Error("PingService", string.format("Could not get spell link for ID: %d", finalSpellID))
        return
    end

    local currentCharges, maxCharges, chargeCooldown = self:GetSpellCharges(finalSpellID)
    local statusText
    
    if currentCharges and maxCharges and maxCharges > 1 then
        -- Spell has charges
        if currentCharges == maxCharges then
            local chargeText = (maxCharges == 1) and "Charge" or "Charges"
            statusText = string.format("%d/%d %s Ready!", currentCharges, maxCharges, chargeText)
        elseif currentCharges > 0 then
            local _, timeRemaining = self:GetChargesCooldownTime(finalSpellID)
            local chargeText = (currentCharges == 1) and "Charge" or "Charges"
            statusText = string.format("%d/%d %s Ready!, next charge in (%s)", 
                currentCharges, maxCharges, chargeText, self:FormatCooldownTime(timeRemaining))
        else
            local _, timeRemaining = self:GetChargesCooldownTime(finalSpellID)
            statusText = string.format("0/%d Charges, next charge in (%s)", 
                maxCharges, self:FormatCooldownTime(timeRemaining))
        end
    else
        -- Single charge spell
        local isOnCooldown, timeRemaining = self:GetCooldownTime(finalSpellID)
        if isOnCooldown then
            statusText = string.format("On cooldown (%s)", self:FormatCooldownTime(timeRemaining))
        else
            statusText = "Ready!"
        end
    end
    
    local message = string.format("%s - %s", spellLink, statusText)

    -- Check if we're in a group
    local chatTarget = self:GetChatTarget()
    
    if chatTarget == "SELF" then
        addon.Logger:Info("PingService", string.format("Displaying ping locally: %s", message))
        print("|cFFFFD700[PingCooldowns]|r " .. message)
    else
        addon.Logger:Info("PingService", string.format("Sending ping: %s to %s", message, chatTarget))
        -- Cast to proper chat type for SendChatMessage
        local validChatTarget = (chatTarget == "RAID" and "RAID") or (chatTarget == "PARTY" and "PARTY") or "SAY"
        SendChatMessage(message, validChatTarget)
        if addon.RateLimiter and addon.RateLimiter.RecordSentMessage then
            addon.RateLimiter:RecordSentMessage()
        end
    end
end

function PingService:GetChatTarget()
    if IsInRaid() then
        return "RAID"
    elseif IsInGroup() then
        return "PARTY"
    else
        return "SELF"
    end
end

return PingService
