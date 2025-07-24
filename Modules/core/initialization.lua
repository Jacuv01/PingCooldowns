local addonName, addon = ...

function addon:Initialize()
    addon.Logger:Info("Core", "PingCooldowns addon loading...")
    
    if addon.RateLimiter and addon.RateLimiter.Initialize then
        addon.RateLimiter:Initialize()
        addon.Logger:Debug("Core", "Rate limiter initialized")
    end

    if addon.PingService and addon.PingService.Initialize then
        addon.PingService:Initialize()
        addon.Logger:Debug("Core", "Ping service initialized")
    end

    self:SetupEvents()
    self:SetupEvents()
    
    addon.Logger:Info("Core", "PingCooldowns addon loaded successfully!")
end

function addon:SetupEvents()
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame", "PingCooldownsCoreFrame")
        self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        self.eventFrame:RegisterEvent("ADDON_LOADED")
        
        self.eventFrame:SetScript("OnEvent", function(self, event, ...)
            if event == "PLAYER_ENTERING_WORLD" then
                addon:OnPlayerEnteringWorld(...)
            elseif event == "ADDON_LOADED" then
                addon:OnAddonLoaded(...)
            end
        end)
    end
end

function addon:OnPlayerEnteringWorld(isInitialLogin, isReloadingUi)
    addon.Logger:Info("Core", "Player entering world")
    
    if isInitialLogin or isReloadingUi then
        C_Timer.After(1, function()
            addon.Logger:Info("Core", "Initializing element hooker system...")
            
            if addon.ElementHooker and addon.ElementHooker.Initialize then
                if addon.ElementHooker:Initialize() then
                    addon.Logger:Info("Core", "Element hooker system ready")
                else
                    addon.Logger:Error("Core", "Failed to initialize element hooker system")
                end
            else
                addon.Logger:Error("Core", "ElementHooker module not found")
            end
        end)
        
        C_Timer.After(3, function()
            if addon.ElementHooker and addon.ElementHooker.RefreshSystem then
                addon.Logger:Debug("Core", "Secondary system refresh")
                addon.ElementHooker:RefreshSystem()
            end
        end)
    end
end

function addon:OnAddonLoaded(loadedAddonName)
    local cooldownAddons = {
        "Blizzard_CooldownViewer",
        "WeakAuras",
        "TellMeWhen", 
        "OmniCC",
        "ElvUI",
        "Bartender4",
        "Dominos"
    }
    
    for _, cooldownAddon in ipairs(cooldownAddons) do
        if loadedAddonName == cooldownAddon then
            addon.Logger:Info("Core", string.format("Cooldown addon detected: %s", loadedAddonName))
            
            C_Timer.After(0.5, function()
                if addon.ElementHooker and addon.ElementHooker.RefreshSystem then
                    addon.Logger:Debug("Core", string.format("Refreshing system after %s load", loadedAddonName))
                    addon.ElementHooker:RefreshSystem()
                end
            end)
            break
        end
    end
end

