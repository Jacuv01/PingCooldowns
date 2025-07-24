local addonName, addon = ...

local ElementHooker = {}
addon.ElementHooker = ElementHooker

local systemInitialized = false
local originalGetCooldownIDs = {}
local processingInProgress = {}

function ElementHooker:GetTalentOverrideSpell(spellID)
    if not spellID then
        return spellID
    end
    
    local overrideID = spellID
    
    if FindSpellOverrideByID then
        local result = FindSpellOverrideByID(spellID)
        if result and result ~= spellID then
            overrideID = result
        end
    end
    
    if overrideID == spellID and C_SpellBook and C_SpellBook.GetOverrideSpell then
        local result = C_SpellBook.GetOverrideSpell(spellID)
        if result and result ~= spellID then
            overrideID = result
        end
    end
    
    if overrideID == spellID then
        local spellName = C_Spell.GetSpellName(spellID)
        if spellName then
            local numSkillLines = C_SpellBook.GetNumSpellBookSkillLines()
            for skillLineIndex = 1, numSkillLines do
                local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(skillLineIndex)
                if skillLineInfo then
                    for spellIndex = skillLineInfo.itemIndexOffset + 1, skillLineInfo.itemIndexOffset + skillLineInfo.numSpellBookItems do
                        local spellInfo = C_SpellBook.GetSpellBookItemInfo(spellIndex, Enum.SpellBookSpellBank.Player)
                        if spellInfo and spellInfo.name == spellName and spellInfo.spellID and spellInfo.spellID ~= spellID then
                            overrideID = spellInfo.spellID
                            break
                        end
                    end
                    if overrideID ~= spellID then
                        break
                    end
                end
            end
        end
    end
    
    return overrideID
end

function ElementHooker:Initialize()
    if systemInitialized then
        addon.Logger:Debug("ElementHooker", "System already initialized, skipping")
        return true
    end

    addon.Logger:Info("ElementHooker", "Setting up cooldown viewer system")
    
    self:SetupEventHandler()
    
    systemInitialized = true
    addon.Logger:Info("ElementHooker", "Event handlers set up - will hook viewers when they become available")
    
    C_Timer.After(2, function()
        self:TrySetupViewers()
    end)
    
    return true
end

function ElementHooker:TrySetupViewers()
    addon.Logger:Debug("ElementHooker", "Attempting to set up viewers...")
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
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame", "PingCooldownsEventFrame")
        self.eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
        self.eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED") 
        self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        
        self.eventFrame:SetScript("OnEvent", function(self, event, ...)
            addon.Logger:Debug("ElementHooker", string.format("Event received: %s", event))
            
            if event == "TRAIT_CONFIG_UPDATED" or event == "PLAYER_SPECIALIZATION_CHANGED" then
                addon.Logger:Info("ElementHooker", "Talent/spec change detected - clearing old hooks and refreshing")
                ElementHooker:ClearFrameHooks()
                C_Timer.After(3, function()
                    ElementHooker:RefreshSystem(0)
                end)
            elseif event == "PLAYER_ENTERING_WORLD" then
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
            if not originalGetCooldownIDs[name] then
                originalGetCooldownIDs[name] = viewer.GetCooldownIDs
                local isProcessing = false
                viewer.GetCooldownIDs = function(self)
                    if isProcessing then
                        addon.Logger:Debug("ElementHooker", name .. " GetCooldownIDs recursion prevented")
                        return originalGetCooldownIDs[name](self)
                    end
                    isProcessing = true
                    local originalIDs = originalGetCooldownIDs[name](self)
                    isProcessing = false
                    if not originalIDs then
                        return originalIDs
                    end
                    local updatedIDs = {}
                    for i, spellID in ipairs(originalIDs) do
                        local finalID = ElementHooker:GetTalentOverrideSpell(spellID)
                        if finalID ~= spellID then
                            addon.Logger:Debug("ElementHooker", string.format("%s: Spell %d -> %d", name, spellID, finalID))
                        end
                        table.insert(updatedIDs, finalID)
                    end
                    return updatedIDs
                end
                addon.Logger:Debug("ElementHooker", string.format("%s GetCooldownIDs enhanced with talent override detection", name))
            end
        end
    end
end

function ElementHooker:SetupLayoutEnhancements()
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
            if not self.originalSetLayout then
                self.originalSetLayout = {}
            end
            if not self.originalSetLayout[name] then
                self.originalSetLayout[name] = viewer.SetLayout
                viewer.SetLayout = function(self, ...)
                    ElementHooker.originalSetLayout[name](self, ...)
                    C_Timer.After(0.5, function()
                        ElementHooker:ProcessCooldownElements(self, name)
                    end)
                end
                addon.Logger:Debug("ElementHooker", string.format("%s SetLayout enhanced", name))
            end
        end
    end
    self:SetupPeriodicRefresh()
end

function ElementHooker:SetupPeriodicRefresh()
    if not self.periodicTimer then
        self.periodicTimer = C_Timer.NewTicker(5, function()
            self:DoPeriodicRefresh()
        end)
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

    local clickFrame = CreateFrame("Button", nil, frame)
    clickFrame:SetAllPoints(frame)
    clickFrame:SetFrameLevel(frame:GetFrameLevel() + 1)
    clickFrame:EnableMouse(true)
    clickFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    frame.pingClickFrame = clickFrame
    
    clickFrame:SetScript("OnClick", function(self, button, down)
        if button == "LeftButton" then
            ElementHooker:HandleLeftClick(spellID, viewerType)
        elseif button == "RightButton" then
            ElementHooker:HandleRightClick(frame, button, down)
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
    
    if self:TrySetupViewers() then
        addon.Logger:Info("ElementHooker", "System refresh successful")
        return
    end
    
    local delay = 2 + retryCount
    addon.Logger:Debug("ElementHooker", string.format("Refresh failed, retrying in %d seconds", delay))
    C_Timer.After(delay, function()
        self:RefreshSystem(retryCount + 1)
    end)
end

function ElementHooker:ClearFrameHooks()
    local viewers = {
        { viewer = _G["EssentialCooldownViewer"], name = "Essential" },
        { viewer = _G["UtilityCooldownViewer"], name = "Utility" },
        { viewer = _G["BuffIconCooldownViewer"], name = "Buff" },
        { viewer = _G["BuffBarCooldownViewer"], name = "Bar" }
    }
    
    local clearedCount = 0
    for _, viewerData in ipairs(viewers) do
        local viewer = viewerData.viewer
        if viewer and viewer.itemFramePool then
            for frame in viewer.itemFramePool:EnumerateActive() do
                if frame.pingHookSetup then
                    frame.pingHookSetup = nil
                    if frame.pingClickFrame then
                        frame.pingClickFrame:Hide()
                        frame.pingClickFrame:SetScript("OnClick", nil)
                        frame.pingClickFrame = nil
                    end
                    clearedCount = clearedCount + 1
                end
            end
        end
    end
    
    if clearedCount > 0 then
        addon.Logger:Info("ElementHooker", string.format("Cleared %d old frame hooks", clearedCount))
    end
end

function ElementHooker:Cleanup()
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
        self.eventFrame:SetScript("OnEvent", nil)
    end
    
    if self.periodicTimer then
        self.periodicTimer:Cancel()
        self.periodicTimer = nil
    end
    
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

function ElementHooker:HandleLeftClick(spellID, viewerType)
    local finalSpellID = self:GetTalentOverrideSpell(spellID)
    
    if finalSpellID ~= spellID then
        addon.Logger:Debug("ElementHooker", string.format("Click-time override: %d -> %d", spellID, finalSpellID))
    end
    
    addon.Logger:Info("ElementHooker", string.format("Ping: %s spell %d", viewerType, finalSpellID))
    
    if addon.PingService and addon.PingService.PingSpellCooldown then
        addon.PingService:PingSpellCooldown(finalSpellID)
    else
        addon.Logger:Error("ElementHooker", "PingService not available")
    end
end

function ElementHooker:HandleRightClick(frame, button, down)
    if frame.GetScript and frame:GetScript("OnClick") then
        frame:GetScript("OnClick")(frame, button, down)
    end
end

return ElementHooker
