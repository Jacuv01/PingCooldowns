local addonName, addon = ...

-- Ping Service Module
-- Handles sending ping messages for cooldowns

local PingService = {}
addon.PingService = PingService

function PingService:Initialize()
    addon.Logger:Debug("PingService", "Ping service initialized")
end

-- Safe function to get talent override spells using available APIs
function PingService:GetTalentOverrideSpell(spellID)
    if not spellID then
        return spellID
    end
    
    -- Try different APIs in order of preference
    local overrideID = spellID
    
    -- Method 1: Try FindSpellOverrideByID (most common)
    if FindSpellOverrideByID then
        local result = FindSpellOverrideByID(spellID)
        if result and result ~= spellID then
            overrideID = result
        end
    end
    
    -- Method 2: Try C_SpellBook.GetOverrideSpell if it exists
    if overrideID == spellID and C_SpellBook and C_SpellBook.GetOverrideSpell then
        local result = C_SpellBook.GetOverrideSpell(spellID)
        if result and result ~= spellID then
            overrideID = result
        end
    end
    
    return overrideID
end

function PingService:PingSpellCooldown(spellID)
    if not spellID then
        addon.Logger:Error("PingService", "No spell ID provided")
        return
    end

    -- Check for talent overrides first using safe method
    local finalSpellID = self:GetTalentOverrideSpell(spellID)
    
    if finalSpellID ~= spellID then
        addon.Logger:Debug("PingService", string.format("Talent override detected: %d -> %d", spellID, finalSpellID))
    end

    -- Check rate limiter if available
    if addon.RateLimiter and addon.RateLimiter.CanSendMessage then
        local canSend, reason = addon.RateLimiter:CanSendMessage()
        if not canSend then
            addon.Logger:Warning("PingService", "Rate limited: " .. (reason or "Unknown"))
            return
        end
    end

    -- Get spell link (this will use the correct talent version)
    local spellLink = C_Spell.GetSpellLink(finalSpellID)
    if not spellLink then
        addon.Logger:Error("PingService", string.format("Could not get spell link for ID: %d", finalSpellID))
        return
    end

    -- Get cooldown information  
    local cooldownInfo = C_Spell.GetSpellCooldown(finalSpellID)
    local isOnCooldown = cooldownInfo and cooldownInfo.duration > 0
    
    -- Create message with spell link
    local message = string.format("%s - %s", 
        spellLink,
        isOnCooldown and "On Cooldown" or "Ready"
    )

    -- Check if we're in a group
    local chatTarget = self:GetChatTarget()
    
    addon.Logger:Info("PingService", string.format("Sending ping: %s to %s", message, chatTarget))
    
    -- Send message
    if chatTarget ~= "SELF" then
        SendChatMessage(message, chatTarget)
        -- Record message sent for rate limiting
        if addon.RateLimiter and addon.RateLimiter.RecordSentMessage then
            addon.RateLimiter:RecordSentMessage()
        end
    else
        print("|cFFFFD700[PingCooldowns]|r " .. message)
    end
end

function PingService:GetChatTarget()
    -- Determine appropriate chat channel
    if IsInRaid() then
        return "RAID"
    elseif IsInGroup() then
        return "PARTY"
    else
        return "SELF"
    end
end

return PingService
