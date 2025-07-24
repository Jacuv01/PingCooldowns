local addonName, addon = ...

local RateLimiter = {}
addon.RateLimiter = RateLimiter

local CONFIG = {
    maxMessages = 3,
    timeWindow = 10,
    cooldownPeriod = 30,
}

local state = {
    messages = {},
    lastLimitHit = 0
}

function RateLimiter:Initialize()
    addon.Logger:Info("RateLimiter", "Rate Limiter initialized")
    addon.Logger:Info("RateLimiter", string.format("Config: %d messages per %ds, %ds cooldown", 
        CONFIG.maxMessages, CONFIG.timeWindow, CONFIG.cooldownPeriod))
end

function RateLimiter:CanSendMessage()
    local currentTime = GetTime()
    
    if (currentTime - state.lastLimitHit) < CONFIG.cooldownPeriod then
        return false, "In cooldown period"
    end
    
    local cutoffTime = currentTime - CONFIG.timeWindow
    local validMessages = {}
    for _, timestamp in ipairs(state.messages) do
        if timestamp > cutoffTime then
            table.insert(validMessages, timestamp)
        end
    end
    state.messages = validMessages
    
    if #state.messages >= CONFIG.maxMessages then
        state.lastLimitHit = currentTime
        return false, "Message limit reached"
    end
    
    return true, "OK"
end

function RateLimiter:RecordSentMessage()
    table.insert(state.messages, GetTime())
end

function RateLimiter:GetStatus()
    local currentTime = GetTime()
    local inCooldown = (currentTime - state.lastLimitHit) < CONFIG.cooldownPeriod
    local cooldownRemaining = 0
    
    if inCooldown then
        cooldownRemaining = CONFIG.cooldownPeriod - (currentTime - state.lastLimitHit)
    end
    
    return {
        inCooldown = inCooldown,
        cooldownRemaining = cooldownRemaining,
        messagesInWindow = #state.messages,
        maxMessages = CONFIG.maxMessages
    }
end

function RateLimiter:Reset()
    state.messages = {}
    state.lastLimitHit = 0
    addon.Logger:Info("RateLimiter", "Rate limiting reset")
end

function RateLimiter:UpdateConfig(newConfig)
    if newConfig.maxMessages then CONFIG.maxMessages = newConfig.maxMessages end
    if newConfig.timeWindow then CONFIG.timeWindow = newConfig.timeWindow end
    if newConfig.cooldownPeriod then CONFIG.cooldownPeriod = newConfig.cooldownPeriod end
    
    addon.Logger:Info("RateLimiter", "Rate limiter config updated")
    addon.Logger:Info("RateLimiter", string.format("New config: %d messages per %ds, %ds cooldown",
        CONFIG.maxMessages, CONFIG.timeWindow, CONFIG.cooldownPeriod))
end

function RateLimiter:GetConfig()
    return {
        maxMessages = CONFIG.maxMessages,
        timeWindow = CONFIG.timeWindow,
        cooldownPeriod = CONFIG.cooldownPeriod
    }
end

return RateLimiter