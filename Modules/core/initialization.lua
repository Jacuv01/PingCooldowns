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
    self:RegisterEvent("PLAYER_TALENT_UPDATE")
    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    self:RegisterEvent("TRAIT_CONFIG_UPDATED")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
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
    self:Log("Spells changed, re-hooking elements...")
    C_Timer.After(0.1, function()
        self:ResetHookedElements()
        self:HookCooldownViewers()
    end)
end

function PingCooldowns:PLAYER_TALENT_UPDATE()
    self:Log("Talents updated, re-hooking elements...")
    C_Timer.After(0.5, function()
        self:ResetHookedElements()
        self:HookCooldownViewers()
    end)
end

function PingCooldowns:ACTIVE_TALENT_GROUP_CHANGED()
    self:Log("Talent group changed, re-hooking elements...")
    C_Timer.After(0.5, function()
        self:ResetHookedElements()
        self:HookCooldownViewers()
    end)
end

function PingCooldowns:TRAIT_CONFIG_UPDATED()
    self:Log("Trait config updated, re-hooking elements...")
    C_Timer.After(0.5, function()
        self:ResetHookedElements()
        self:HookCooldownViewers()
    end)
end

function PingCooldowns:PLAYER_SPECIALIZATION_CHANGED()
    self:Log("Specialization changed, re-hooking elements...")
    C_Timer.After(0.5, function()
        self:ResetHookedElements()
        self:HookCooldownViewers()
    end)
end

function PingCooldowns:UI_INFO_MESSAGE()
    C_Timer.After(0.2, function()
        self:HookCooldownViewers()
    end)
end

function PingCooldowns:ResetHookedElements()
    self:Log("Resetting hooked elements...")
    if self.hookedViewers then
        for viewerName, _ in pairs(self.hookedViewers) do
            self.hookedViewers[viewerName] = nil
        end
    end
    
    if PingCooldowns.hookedElements then
        for element, _ in pairs(PingCooldowns.hookedElements) do
            PingCooldowns.hookedElements[element] = nil
        end
    end
    
    self:Log("All hooked elements reset")
end

