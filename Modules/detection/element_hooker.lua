local addonName, addon = ...

-- Element Hooker Module
-- This module implements a safe approach similar to CooldownManagerControl
-- Instead of hooking SetLayout, we replace GetCooldownIDs function and use TRAIT_CONFIG_UPDATED

local ElementHooker = {}
addon.ElementHooker = ElementHooker

-- Track whether we've already set up our system
local systemInitialized = false
local originalGetCooldownIDs = {}
local processingInProgress = {} -- Anti-reentry protection

function ElementHooker:Initialize()
    if systemInitialized then
        addon.Logger:Debug("ElementHooker", "System already initialized, skipping")
        return true
    end

    addon.Logger:Info("ElementHooker", "Setting up cooldown viewer system")
    
    -- Don't fail initialization - just set up the event handlers
    -- The actual hooking will happen when events fire
    self:SetupEventHandler()
    
    systemInitialized = true
    addon.Logger:Info("ElementHooker", "Event handlers set up - will hook viewers when they become available")
    
    -- Try to do initial setup, but don't fail if it doesn't work
    C_Timer.After(2, function()
        self:TrySetupViewers()
    end)
    
    return true
end

function ElementHooker:TrySetupViewers()
    addon.Logger:Debug("ElementHooker", "Attempting to set up viewers...")
    
    -- Get references to the cooldown viewers with detailed logging
    local viewers = {
        { name = "EssentialCooldownViewer", viewer = _G["EssentialCooldownViewer"] },
        { name = "UtilityCooldownViewer", viewer = _G["UtilityCooldownViewer"] }, 
        { name = "BuffIconCooldownViewer", viewer = _G["BuffIconCooldownViewer"] },
        { name = "BuffBarCooldownViewer", viewer = _G["BuffBarCooldownViewer"] }
    }
    
    local foundCount = 0
    for _, viewerData in ipairs(viewers) do
        if viewerData.viewer then
            foundCount = foundCount + 1
            addon.Logger:Debug("ElementHooker", string.format("Found %s", viewerData.name))
        else
            addon.Logger:Debug("ElementHooker", string.format("Missing %s", viewerData.name))
        end
    end
    
    if foundCount == 0 then
        addon.Logger:Warning("ElementHooker", "No cooldown viewers found - they may not be enabled or loaded yet")
        return false
    end
    
    addon.Logger:Info("ElementHooker", string.format("Found %d/4 cooldown viewers", foundCount))
    
    -- Set up what we can
    if foundCount > 0 then
        self:SetupCooldownIDReplacements()
        self:SetupLayoutEnhancements()
        self:DoInitialProcessing()
    end
    
    return foundCount > 0
end

function ElementHooker:SetupEventHandler()
    -- Create event frame to handle spec/talent changes
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame", "PingCooldownsEventFrame")
        self.eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
        self.eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED") 
        self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        
        self.eventFrame:SetScript("OnEvent", function(self, event, ...)
            addon.Logger:Debug("ElementHooker", string.format("Event received: %s", event))
            
            -- Use safe delay for critical events to avoid taint
            if event == "TRAIT_CONFIG_UPDATED" or event == "PLAYER_SPECIALIZATION_CHANGED" then
                -- These events can cause taint, so wait longer and be more patient
                addon.Logger:Debug("ElementHooker", "Critical event detected, scheduling delayed refresh")
                C_Timer.After(3, function()
                    ElementHooker:RefreshSystem(0) -- Start with retry count 0
                end)
            elseif event == "PLAYER_ENTERING_WORLD" then
                -- This is usually safe but give it a moment to settle
                C_Timer.After(1, function()
                    ElementHooker:RefreshSystem(0)
                end)
            end
        end)
    end
end

function ElementHooker:SetupCooldownIDReplacements()
    -- DISABLED: This was causing stack overflow
    -- Instead, we'll rely only on SetLayout hooks and periodic refresh
    addon.Logger:Debug("ElementHooker", "Skipping GetCooldownIDs hooks to prevent stack overflow")
end

function ElementHooker:SetupLayoutEnhancements()
    -- Hook into the layout process to add our ping functionality
    local viewers = {
        { viewer = _G["EssentialCooldownViewer"], name = "Essential" },
        { viewer = _G["UtilityCooldownViewer"], name = "Utility" },
        { viewer = _G["BuffIconCooldownViewer"], name = "Buff" },
        { viewer = _G["BuffBarCooldownViewer"], name = "Bar" }
    }

    for _, viewerData in ipairs(viewers) do
        local viewer = viewerData.viewer
        local name = viewerData.name
        
        if viewer and viewer.SetLayout then
            -- Store original SetLayout if we haven't already
            if not self.originalSetLayout then
                self.originalSetLayout = {}
            end
            
            if not self.originalSetLayout[name] then
                self.originalSetLayout[name] = viewer.SetLayout
                
                -- Create enhanced SetLayout
                viewer.SetLayout = function(self, ...)
                    -- Call original SetLayout first
                    ElementHooker.originalSetLayout[name](self, ...)
                    
                    -- Add our ping functionality after layout with longer delay
                    C_Timer.After(0.5, function()
                        ElementHooker:ProcessCooldownElements(self, name)
                    end)
                end
                
                addon.Logger:Debug("ElementHooker", string.format("%s SetLayout enhanced", name))
            end
        end
    end
    
    -- Also set up periodic refresh to catch missed updates
    self:SetupPeriodicRefresh()
end

function ElementHooker:SetupPeriodicRefresh()
    -- Set up a periodic timer to refresh frames every 5 seconds
    if not self.periodicTimer then
        self.periodicTimer = C_Timer.NewTicker(5, function()
            self:DoPeriodicRefresh()
        end)
        addon.Logger:Debug("ElementHooker", "Periodic refresh timer set up")
    end
end

function ElementHooker:DoPeriodicRefresh()
    local viewers = {
        { viewer = _G["EssentialCooldownViewer"], name = "Essential" },
        { viewer = _G["UtilityCooldownViewer"], name = "Utility" },
        { viewer = _G["BuffIconCooldownViewer"], name = "Buff" },
        { viewer = _G["BuffBarCooldownViewer"], name = "Bar" }
    }
    
    for _, viewerData in ipairs(viewers) do
        if viewerData.viewer then
            self:ProcessCooldownElements(viewerData.viewer, viewerData.name)
        end
    end
end

function ElementHooker:ProcessCooldownElements(viewer, viewerType)
    if not viewer then
        return
    end
    
    if not viewer.itemFramePool then
        return
    end

    -- Process all active cooldown frames
    local processedCount = 0
    local totalCount = 0
    
    for frame in viewer.itemFramePool:EnumerateActive() do
        totalCount = totalCount + 1
        if self:SetupCooldownFrameHook(frame, viewerType) then
            processedCount = processedCount + 1
        end
    end

    -- Only log if we actually processed something to reduce spam
    if processedCount > 0 then
        addon.Logger:Info("ElementHooker", string.format("%s viewer: %d/%d frames processed", 
            viewerType, processedCount, totalCount))
    end
end

function ElementHooker:SetupCooldownFrameHook(frame, viewerType)
    if not frame or frame.pingHookSetup then
        return false
    end

    -- Mark this frame as having our hook
    frame.pingHookSetup = true

    -- Get cooldown information
    local cooldownID = frame.cooldownID
    local spellID = nil
    
    if cooldownID then
        local cooldownInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
        if cooldownInfo then
            spellID = cooldownInfo.spellID
        end
    end

    if not spellID then
        return false
    end

    -- Create an invisible clickable frame overlay instead of modifying the original frame
    local clickFrame = CreateFrame("Button", nil, frame)
    clickFrame:SetAllPoints(frame)
    clickFrame:SetFrameLevel(frame:GetFrameLevel() + 1)
    clickFrame:EnableMouse(true)
    clickFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    -- Store reference to prevent garbage collection
    frame.pingClickFrame = clickFrame
    
    clickFrame:SetScript("OnClick", function(self, button, down)
        if button == "LeftButton" then
            addon.Logger:Info("ElementHooker", string.format("Ping: %s spell %d", viewerType, spellID))
            -- Use addon.PingService directly to ensure it's available
            if addon.PingService and addon.PingService.PingSpellCooldown then
                addon.PingService:PingSpellCooldown(spellID)
            else
                addon.Logger:Error("ElementHooker", "PingService not available")
            end
        elseif button == "RightButton" then
            -- Pass through to original frame if it has click handlers
            if frame.GetScript and frame:GetScript("OnClick") then
                frame:GetScript("OnClick")(frame, button, down)
            end
        end
    end)

    return true
end

function ElementHooker:AreViewersReady()
    local viewers = {
        { name = "EssentialCooldownViewer", viewer = _G["EssentialCooldownViewer"] },
        { name = "UtilityCooldownViewer", viewer = _G["UtilityCooldownViewer"] }, 
        { name = "BuffIconCooldownViewer", viewer = _G["BuffIconCooldownViewer"] },
        { name = "BuffBarCooldownViewer", viewer = _G["BuffBarCooldownViewer"] }
    }
    
    local ready = true
    for _, viewerData in ipairs(viewers) do
        local viewer = viewerData.viewer
        if not viewer then
            addon.Logger:Debug("ElementHooker", string.format("%s not found", viewerData.name))
            ready = false
        elseif not viewer.itemFramePool then
            addon.Logger:Debug("ElementHooker", string.format("%s has no itemFramePool", viewerData.name))
            ready = false
        else
            addon.Logger:Debug("ElementHooker", string.format("%s is ready", viewerData.name))
        end
    end
    
    return ready
end

function ElementHooker:RefreshSystem(retryCount)
    retryCount = retryCount or 0
    local maxRetries = 3  -- Reducido significativamente
    
    if retryCount > maxRetries then
        addon.Logger:Warning("ElementHooker", "Max refresh retries reached. Use /pingdebug to check system status")
        return
    end

    addon.Logger:Debug("ElementHooker", string.format("Refresh attempt %d/%d", retryCount + 1, maxRetries + 1))
    
    -- Simple approach: just try to set up viewers again
    if self:TrySetupViewers() then
        addon.Logger:Info("ElementHooker", "System refresh successful")
        return
    end
    
    -- If failed, retry with longer delay
    local delay = 2 + retryCount
    addon.Logger:Debug("ElementHooker", string.format("Refresh failed, retrying in %d seconds", delay))
    C_Timer.After(delay, function()
        self:RefreshSystem(retryCount + 1)
    end)
end

-- Safe cleanup function
function ElementHooker:Cleanup()
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
        self.eventFrame:SetScript("OnEvent", nil)
    end
    
    -- Cancel periodic timer
    if self.periodicTimer then
        self.periodicTimer:Cancel()
        self.periodicTimer = nil
    end
    
    -- Restore original SetLayout functions if needed
    if self.originalSetLayout then
        for name, originalFunc in pairs(self.originalSetLayout) do
            local viewerName = name .. "CooldownViewer"
            if name == "Buff" then
                viewerName = "BuffIconCooldownViewer"
            elseif name == "Bar" then
                viewerName = "BuffBarCooldownViewer"
            end
            
            local viewer = _G[viewerName]
            if viewer then
                viewer.SetLayout = originalFunc
            end
        end
    end
    
    systemInitialized = false
    addon.Logger:Info("ElementHooker", "System cleaned up")
end

function ElementHooker:DoInitialProcessing()
    addon.Logger:Debug("ElementHooker", "Starting initial processing")
    
    -- Process each viewer that exists
    local viewers = {
        { viewer = _G["EssentialCooldownViewer"], name = "Essential" },
        { viewer = _G["UtilityCooldownViewer"], name = "Utility" },
        { viewer = _G["BuffIconCooldownViewer"], name = "Buff" },
        { viewer = _G["BuffBarCooldownViewer"], name = "Bar" }
    }
    
    local processed = 0
    for _, viewerData in ipairs(viewers) do
        if viewerData.viewer then
            self:ProcessCooldownElements(viewerData.viewer, viewerData.name)
            processed = processed + 1
        end
    end
    
    addon.Logger:Info("ElementHooker", string.format("Initial processing completed for %d viewers", processed))
end

return ElementHooker
