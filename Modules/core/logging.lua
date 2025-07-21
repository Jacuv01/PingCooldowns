local _, PingCooldowns = ...

local ENABLE_LOGS = false

function PingCooldowns:ToggleLogging()
    self.LOGGING_ENABLED = not self.LOGGING_ENABLED
    if self.LOGGING_ENABLED then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[PingCooldowns]|r Logging ENABLED")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[PingCooldowns]|r Logging DISABLED")
    end
end

function PingCooldowns:Log(msg)
    if ENABLE_LOGS and self.LOGGING_ENABLED and self.DEBUG and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[PingCooldowns]|r " .. tostring(msg))
    end
end

function PingCooldowns:LogError(msg)
    if ENABLE_LOGS and self.LOGGING_ENABLED and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[PingCooldowns ERROR]|r " .. tostring(msg))
    end
end

function PingCooldowns:LogSuccess(msg)
    if ENABLE_LOGS and self.LOGGING_ENABLED and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[PingCooldowns SUCCESS]|r " .. tostring(msg))
    end
end

function PingCooldowns:LogWarning(msg)
    if ENABLE_LOGS and self.LOGGING_ENABLED and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[PingCooldowns WARNING]|r " .. tostring(msg))
    end
end
