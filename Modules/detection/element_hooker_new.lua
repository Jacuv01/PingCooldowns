local addonName, addon = ...

-- Element Hooker Module
-- This module implements a safe approach similar to CooldownManagerControl
-- Instead of hooking SetLayout, we replace GetCooldownIDs function and use TRAIT_CONFIG_UPDATED

local ElementHooker = {}
addon.ElementHooker = ElementHooker

local pingService = addon.PingService

-- Track whether we've already set up our system
local systemInitialized = false
local originalGetCooldownIDs = {}

function ElementHooker:Initialize()
    if systemInitialized then
        addon.Logger:Debug("ElementHooker", "System already initialized, skipping")
        return
    end

    addon.Logger:Info("ElementHooker", "Setting up cooldown viewer system")
    
    -- Get references to the cooldown viewers
    local essentialViewer = _G["EssentialCooldownViewer"]
    local utilityViewer = _G["UtilityCooldownViewer"]
    local buffViewer = _G["BuffIconCooldownViewer"]
    local barViewer = _G["BuffBarCooldownViewer"]
    
    if not essentialViewer or not utilityViewer or not buffViewer or not barViewer then
        addon.Logger:Error("ElementHooker", "One or more cooldown viewers not found")
        return false
    end

    -- Set up event handling for talent/spec changes
    self:SetupEventHandler()

    -- Replace GetCooldownIDs functions with our enhanced versions
    self:SetupCooldownIDReplacements()

    -- Set up our custom layout enhancement
    self:SetupLayoutEnhancements()

    systemInitialized = true
    addon.Logger:Info("ElementHooker", "Cooldown viewer system initialized successfully")
    return true
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
            
            -- Use taint-safe delay for critical events
            if event == "TRAIT_CONFIG_UPDATED" or event == "PLAYER_SPECIALIZATION_CHANGED" then
                -- Use our taint-safe system for these critical events
                if addon.TaintSafeFix then
                    addon.TaintSafeFix:ScheduleSafeRepair()
                else
                    -- Fallback with delay
                    C_Timer.After(2, function()
                        ElementHooker:RefreshSystem()
                    end)
                end
            else
                -- Safe for immediate execution
                ElementHooker:RefreshSystem()
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
    if not viewer or not viewer.itemFramePool then
        addon.Logger:Debug("ElementHooker", string.format("%s viewer has no itemFramePool", viewerType))
        return
    end

    -- Process all active cooldown frames
    local processedCount = 0
    for frame in viewer.itemFramePool:EnumerateActive() do
        if self:SetupCooldownFrameHook(frame, viewerType) then
            processedCount = processedCount + 1
        end
    end

    addon.Logger:Debug("ElementHooker", string.format("Processed %d %s viewer elements", processedCount, viewerType))
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
        addon.Logger:Debug("ElementHooker", string.format("No spell ID found for %s frame", viewerType))
        return false
    end

    -- Set up click handler for pinging (taint-safe)
    frame:EnableMouse(true)
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    frame:SetScript("OnClick", function(self, button, down)
        if not issecure() then
            addon.Logger:Debug("ElementHooker", "Skipping click in non-secure context")
            return
        end
        
        if button == "LeftButton" then
            addon.Logger:Debug("ElementHooker", string.format("Left click on %s spell %d", viewerType, spellID))
            pingService:PingSpellCooldown(spellID)
        elseif button == "RightButton" then
            addon.Logger:Debug("ElementHooker", string.format("Right click on %s spell %d", viewerType, spellID))
            -- Right click could be used for additional functionality
        end
    end)

    addon.Logger:Debug("ElementHooker", string.format("Set up ping hook for %s spell %d", viewerType, spellID))
    return true
end

function ElementHooker:RefreshSystem()
    if not systemInitialized then
        addon.Logger:Debug("ElementHooker", "System not initialized, cannot refresh")
        return
    end

    addon.Logger:Info("ElementHooker", "Refreshing cooldown viewer system")
    
    -- Re-process all viewers with delay to avoid taint
    C_Timer.After(0.5, function()
        if issecure() then
            self:ProcessCooldownElements(_G["EssentialCooldownViewer"], "Essential")
            self:ProcessCooldownElements(_G["UtilityCooldownViewer"], "Utility")
            self:ProcessCooldownElements(_G["BuffIconCooldownViewer"], "Buff")
            self:ProcessCooldownElements(_G["BuffBarCooldownViewer"], "Bar")
            
            addon.Logger:Info("ElementHooker", "System refresh completed")
        else
            addon.Logger:Debug("ElementHooker", "Refresh delayed due to insecure context")
            -- Retry in secure context
            C_Timer.After(1, function()
                self:RefreshSystem()
            end)
        end
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

return ElementHooker
