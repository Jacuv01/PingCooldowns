local addonName, addon = ...

-- Element Hooker Module
-- This module implements a safe approach similar to CooldownManagerControl
-- Instead of hooking SetLayout, we replace GetCooldownIDs function and use TRAIT_CONFIG_UPDATED

local ElementHooker = {}
addon.ElementHooker = ElementHooker

-- Track whether we've already set up our system
local systemInitialized = false
local originalGetCooldownIDs = {}

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
    local viewers = {
        { viewer = _G["EssentialCooldownViewer"], name = "Essential" },
        { viewer = _G["UtilityCooldownViewer"], name = "Utility" },
        { viewer = _G["BuffIconCooldownViewer"], name = "Buff" },
        { viewer = _G["BuffBarCooldownViewer"], name = "Bar" }
    }

    for _, viewerData in ipairs(viewers) do
        local viewer = viewerData.viewer
        local name = viewerData.name
        
        if viewer and viewer.GetCooldownIDs then
            -- Store original function
            originalGetCooldownIDs[name] = viewer.GetCooldownIDs
            
            -- Replace with our enhanced version
            viewer.GetCooldownIDs = function(self)
                addon.Logger:Debug("ElementHooker", string.format("%s GetCooldownIDs called", name))
                
                -- Call original function to get IDs
                local originalIDs = originalGetCooldownIDs[name](self)
                
                -- Process the cooldown elements for ping functionality
                ElementHooker:ProcessCooldownElements(self, name)
                
                return originalIDs
            end
            
            addon.Logger:Debug("ElementHooker", string.format("%s GetCooldownIDs replaced", name))
        end
    end
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
                    addon.Logger:Debug("ElementHooker", string.format("%s SetLayout called", name))
                    
                    -- Call original SetLayout
                    ElementHooker.originalSetLayout[name](self, ...)
                    
                    -- Add our ping functionality after layout
                    C_Timer.After(0.1, function()
                        ElementHooker:ProcessCooldownElements(self, name)
                    end)
                end
                
                addon.Logger:Debug("ElementHooker", string.format("%s SetLayout enhanced", name))
            end
        end
    end
end

function ElementHooker:ProcessCooldownElements(viewer, viewerType)
    if not viewer then
        addon.Logger:Debug("ElementHooker", string.format("%s viewer is nil", viewerType))
        return
    end
    
    if not viewer.itemFramePool then
        addon.Logger:Debug("ElementHooker", string.format("%s viewer has no itemFramePool", viewerType))
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

    addon.Logger:Info("ElementHooker", string.format("%s viewer: %d total frames, %d processed successfully", 
        viewerType, totalCount, processedCount))
end

function ElementHooker:SetupCooldownFrameHook(frame, viewerType)
    if not frame then
        addon.Logger:Debug("ElementHooker", string.format("%s frame is nil", viewerType))
        return false
    end
    
    if frame.pingHookSetup then
        addon.Logger:Debug("ElementHooker", string.format("%s frame already has ping hook", viewerType))
        return false
    end

    -- Mark this frame as having our hook
    frame.pingHookSetup = true

    -- Get cooldown information
    local cooldownID = frame.cooldownID
    local spellID = nil
    
    addon.Logger:Debug("ElementHooker", string.format("%s frame cooldownID: %s", viewerType, tostring(cooldownID)))
    
    if cooldownID then
        local cooldownInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
        if cooldownInfo then
            spellID = cooldownInfo.spellID
            addon.Logger:Debug("ElementHooker", string.format("%s frame spellID: %s", viewerType, tostring(spellID)))
        else
            addon.Logger:Debug("ElementHooker", string.format("%s frame cooldownInfo is nil", viewerType))
        end
    else
        addon.Logger:Debug("ElementHooker", string.format("%s frame has no cooldownID", viewerType))
    end

    if not spellID then
        addon.Logger:Debug("ElementHooker", string.format("No spell ID found for %s frame", viewerType))
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
            addon.Logger:Info("ElementHooker", string.format("Left click on %s spell %d", viewerType, spellID))
            -- Use addon.PingService directly to ensure it's available
            if addon.PingService and addon.PingService.PingSpellCooldown then
                addon.PingService:PingSpellCooldown(spellID)
            else
                addon.Logger:Error("ElementHooker", "PingService not available")
            end
        elseif button == "RightButton" then
            addon.Logger:Debug("ElementHooker", string.format("Right click on %s spell %d", viewerType, spellID))
            -- Pass through to original frame if it has click handlers
            if frame.GetScript and frame:GetScript("OnClick") then
                frame:GetScript("OnClick")(frame, button, down)
            end
        end
    end)

    addon.Logger:Info("ElementHooker", string.format("Set up ping overlay for %s spell %d", viewerType, spellID))
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
    
    -- Restore original functions if needed
    if originalGetCooldownIDs then
        for name, originalFunc in pairs(originalGetCooldownIDs) do
            local viewerName = name .. "CooldownViewer"
            if name == "Buff" then
                viewerName = "BuffIconCooldownViewer"
            elseif name == "Bar" then
                viewerName = "BuffBarCooldownViewer"
            end
            
            local viewer = _G[viewerName]
            if viewer then
                viewer.GetCooldownIDs = originalFunc
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
