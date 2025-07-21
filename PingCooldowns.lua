local addonName, addonTable = ...
PingCooldowns = addonTable

PingCooldowns.LOGGING_ENABLED = true
PingCooldowns.DEBUG = true

PingCooldowns.frame = CreateFrame("Frame")
PingCooldowns.frame:RegisterEvent("ADDON_LOADED")
PingCooldowns.frame:RegisterEvent("PLAYER_LOGIN")

function PingCooldowns:RegisterEvent(event)
    if self.frame then
        self.frame:RegisterEvent(event)
        self:Log("Registered event: " .. event)
    end
end

PingCooldowns.frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddonName = ...
        if loadedAddonName == addonName then
            PingCooldowns:Log("PingCooldowns addon files loaded")
            if not PingCooldownsDB then
                PingCooldownsDB = { locked = false }
            end
        else
            if PingCooldowns.ADDON_LOADED then
                PingCooldowns:ADDON_LOADED(loadedAddonName)
            end
        end
    elseif event == "PLAYER_LOGIN" then
        PingCooldowns:OnLogin()
    elseif event == "PLAYER_ENTERING_WORLD" then
        if PingCooldowns.PLAYER_ENTERING_WORLD then
            PingCooldowns:PLAYER_ENTERING_WORLD(...)
        end
    elseif event == "SPELLS_CHANGED" then
        if PingCooldowns.SPELLS_CHANGED then
            PingCooldowns:SPELLS_CHANGED(...)
        end
    end
end)

