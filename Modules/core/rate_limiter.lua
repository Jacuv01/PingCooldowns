local _, PingCooldowns = ...

PingCooldowns.RateLimiter = {}

local CONFIG = {
    maxMessages = 3,
    timeWindow = 10,
    cooldownPeriod = 30,
}

local state = {
    messages = {},
    lastLimitHit = 0
}

function PingCooldowns.RateLimiter:Initialize()
    if PingCooldowns and PingCooldowns.LogSuccess then
        PingCooldowns:LogSuccess("Rate Limiter initialized")
        PingCooldowns:LogSuccess("Config: " .. CONFIG.maxMessages .. " messages per " .. CONFIG.timeWindow .. "s, " .. CONFIG.cooldownPeriod .. "s cooldown")
    end
end

function PingCooldowns.RateLimiter:CanSendMessage()
    local currentTime = GetTime()
    
    if state.lastLimitHit > 0 and (currentTime - state.lastLimitHit) < CONFIG.cooldownPeriod then
        local remainingCooldown = math.ceil(CONFIG.cooldownPeriod - (currentTime - state.lastLimitHit))
        return false, "Rate limited - wait " .. remainingCooldown .. "s"
    end
    
    local newMessages = {}
    for _, timestamp in ipairs(state.messages) do
        if (currentTime - timestamp) < CONFIG.timeWindow then
            table.insert(newMessages, timestamp)
        end
    end
    state.messages = newMessages
    
    if #state.messages >= CONFIG.maxMessages then
        state.lastLimitHit = currentTime
        return false, "Rate limited - max " .. CONFIG.maxMessages .. " messages per " .. CONFIG.timeWindow .. "s"
    end
    
    return true, nil
end

function PingCooldowns.RateLimiter:RecordSentMessage()
    table.insert(state.messages, GetTime())
end

function PingCooldowns.RateLimiter:GetStatus()
    local currentTime = GetTime()
    
    local recentMessages = 0
    for _, timestamp in ipairs(state.messages) do
        if (currentTime - timestamp) < CONFIG.timeWindow then
            recentMessages = recentMessages + 1
        end
    end
    
    local status = {
        messagesUsed = recentMessages,
        messagesRemaining = CONFIG.maxMessages - recentMessages,
        maxMessages = CONFIG.maxMessages,
        timeWindow = CONFIG.timeWindow,
        inCooldown = false,
        cooldownRemaining = 0,
        config = CONFIG
    }
    
    if state.lastLimitHit > 0 and (currentTime - state.lastLimitHit) < CONFIG.cooldownPeriod then
        status.inCooldown = true
        status.cooldownRemaining = math.ceil(CONFIG.cooldownPeriod - (currentTime - state.lastLimitHit))
    end
    
    return status
end

function PingCooldowns.RateLimiter:Reset()
    state.messages = {}
    state.lastLimitHit = 0
    if PingCooldowns and PingCooldowns.LogSuccess then
        PingCooldowns:LogSuccess("Rate limiting reset")
    end
end

function PingCooldowns.RateLimiter:UpdateConfig(newConfig)
    if newConfig.maxMessages and newConfig.maxMessages > 0 then
        CONFIG.maxMessages = newConfig.maxMessages
    end
    if newConfig.timeWindow and newConfig.timeWindow > 0 then
        CONFIG.timeWindow = newConfig.timeWindow
    end
    if newConfig.cooldownPeriod and newConfig.cooldownPeriod > 0 then
        CONFIG.cooldownPeriod = newConfig.cooldownPeriod
    end
    
    if PingCooldowns and PingCooldowns.LogSuccess then
        PingCooldowns:LogSuccess("Rate limiter config updated")
        PingCooldowns:LogSuccess("New config: " .. CONFIG.maxMessages .. " messages per " .. CONFIG.timeWindow .. "s, " .. CONFIG.cooldownPeriod .. "s cooldown")
    end
end

function PingCooldowns.RateLimiter:GetConfig()
    return {
        maxMessages = CONFIG.maxMessages,
        timeWindow = CONFIG.timeWindow,
        cooldownPeriod = CONFIG.cooldownPeriod
    }
end

function PingCooldowns.RateLimiter:ValidateChatContext(chatType)
    if chatType == "GUILD" and not IsInGuild() then
        return false, "Not in a guild"
    elseif (chatType == "PARTY" or chatType == "INSTANCE_CHAT") and not IsInGroup() then
        return false, "Not in a group"
    elseif chatType == "RAID" and not IsInRaid() then
        return false, "Not in a raid"
    end
    
    return true, nil
end

function PingCooldowns.RateLimiter:SafeSendMessage(message, chatType)
    if not message or message == "" then
        return false, "Empty message"
    end
    
    local canSend, rateLimitReason = self:CanSendMessage()
    if not canSend then
        if PingCooldowns and PingCooldowns.LogWarning then
            PingCooldowns:LogWarning("Message blocked: " .. rateLimitReason)
        end
        return false, rateLimitReason
    end
    
    local validContext, contextReason = self:ValidateChatContext(chatType or "SAY")
    if not validContext then
        if PingCooldowns and PingCooldowns.LogWarning then
            PingCooldowns:LogWarning("Invalid chat context: " .. contextReason)
        end
        return false, contextReason
    end
    
    local targetChat = chatType or "SAY"
    
    local success = pcall(SendChatMessage, message, targetChat)
    if success then
        self:RecordSentMessage()
        if PingCooldowns and PingCooldowns.LogSuccess then
            PingCooldowns:LogSuccess("Message sent to " .. targetChat)
        end
        
        local status = self:GetStatus()
        if PingCooldowns and PingCooldowns.LogSuccess then
            PingCooldowns:LogSuccess("Rate limit: " .. status.messagesRemaining .. "/" .. status.maxMessages .. " messages remaining")
        end
        
        return true, "Message sent successfully"
    else
        if PingCooldowns and PingCooldowns.LogWarning then
            PingCooldowns:LogWarning("Failed to send message to " .. targetChat)
        end
        return false, "Send failed"
    end
end
