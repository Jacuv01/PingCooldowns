local _, PingCooldowns = ...

function PingCooldowns:OnLogin()
    self:Log("PingCooldowns addon loaded successfully!")
    
    if self.RateLimiter and self.RateLimiter.Initialize then
        self.RateLimiter:Initialize()
    end
    
    self.hookedViewers = self.hookedViewers or {}
    
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("ADDON_LOADED") 
    self:RegisterEvent("SPELLS_CHANGED")
    self:RegisterEvent("UI_INFO_MESSAGE")
end

function PingCooldowns:PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi)
    if isInitialLogin or isReloadingUi then
        self:Log("World loaded, searching for cooldown managers...")
        self:HookCooldownViewers()
        
        C_Timer.After(1, function()
            self:Log("Secondary search for late-loading addons...")
            self:HookCooldownViewers()
        end)
    end
end

function PingCooldowns:ADDON_LOADED(addonName)
    local cooldownAddons = {
        "EssentialCooldowns",
        "UtilityCooldowns", 
        "BuffIconCooldowns",
        "WeakAuras",
        "TellMeWhen",
        "OmniCC",
        "ElvUI",
        "Bartender4",
        "Dominos"
    }
    
    for _, cooldownAddon in ipairs(cooldownAddons) do
        if addonName == cooldownAddon then
            self:Log("Cooldown addon detected: " .. addonName)
            C_Timer.After(0.5, function()
                self:Log("Searching for " .. addonName .. " elements...")
                self:HookCooldownViewers()
            end)
            break
        end
    end
end

function PingCooldowns:SPELLS_CHANGED()
    C_Timer.After(0.1, function()
        self:HookCooldownViewers()
    end)
end

function PingCooldowns:UI_INFO_MESSAGE()
    C_Timer.After(0.2, function()
        self:HookCooldownViewers()
    end)
end

