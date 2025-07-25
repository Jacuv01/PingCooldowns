local addonName, addon = ...

local Logger = {}
addon.Logger = Logger

local ENABLE_LOGS = false

function Logger:ToggleLogging()
    ENABLE_LOGS = not ENABLE_LOGS
    if ENABLE_LOGS then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[PingCooldowns]|r Logging ENABLED")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[PingCooldowns]|r Logging DISABLED")
    end
end

function Logger:Debug(module, msg)
    if ENABLE_LOGS and PingCooldownsDB and PingCooldownsDB.debugMode and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff888888[%s:%s]|r %s", addonName, module, tostring(msg)))
    end
end

function Logger:Info(module, msg)
    if ENABLE_LOGS and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00[%s:%s]|r %s", addonName, module, tostring(msg)))
    end
end

function Logger:Error(module, msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffff0000[%s:%s ERROR]|r %s", addonName, module, tostring(msg)))
    end
end

function Logger:Warning(module, msg)
    if ENABLE_LOGS and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffffff00[%s:%s WARNING]|r %s", addonName, module, tostring(msg)))
    end
end

function Logger:Success(module, msg)
    if ENABLE_LOGS and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00[%s:%s SUCCESS]|r %s", addonName, module, tostring(msg)))
    end
end

return Logger
