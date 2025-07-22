local addonName, addon = ...

-- Ping Service Module
-- Handles sending ping messages for cooldowns

local PingService = {}
addon.PingService = PingService

function PingService:Initialize()
    addon.Logger:Debug("PingService", "Ping service initialized")
end

function PingService:PingSpellCooldown(spellID)
    if not spellID then
        addon.Logger:Error("PingService", "No spell ID provided")
        return
    end

    -- Check rate limiter if available
    if addon.RateLimiter and addon.RateLimiter.CanSendMessage then
        local canSend, reason = addon.RateLimiter:CanSendMessage()
        if not canSend then
            addon.Logger:Warning("PingService", "Rate limited: " .. (reason or "Unknown"))
            return
        end
    end

    -- Get spell information
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if not spellInfo then
        addon.Logger:Error("PingService", string.format("Could not get spell info for ID: %d", spellID))
        return
    end

    -- Get cooldown information  
    local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
    local isOnCooldown = cooldownInfo and cooldownInfo.duration > 0
    
    -- Create message
    local message = string.format("[%s] - %s", 
        spellInfo.name,
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
