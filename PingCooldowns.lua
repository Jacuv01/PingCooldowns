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
    elseif event == "PLAYER_TALENT_UPDATE" then
        if PingCooldowns.PLAYER_TALENT_UPDATE then
            PingCooldowns:PLAYER_TALENT_UPDATE(...)
        end
    elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
        if PingCooldowns.ACTIVE_TALENT_GROUP_CHANGED then
            PingCooldowns:ACTIVE_TALENT_GROUP_CHANGED(...)
        end
    elseif event == "TRAIT_CONFIG_UPDATED" then
        if PingCooldowns.TRAIT_CONFIG_UPDATED then
            PingCooldowns:TRAIT_CONFIG_UPDATED(...)
        end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if PingCooldowns.PLAYER_SPECIALIZATION_CHANGED then
            PingCooldowns:PLAYER_SPECIALIZATION_CHANGED(...)
        end
    elseif event == "UI_INFO_MESSAGE" then
        if PingCooldowns.UI_INFO_MESSAGE then
            PingCooldowns:UI_INFO_MESSAGE(...)
        end
    end
end)

