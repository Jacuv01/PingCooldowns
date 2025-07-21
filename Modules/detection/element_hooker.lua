local _, PingCooldowns = ...

function PingCooldowns:HookCooldownViewers()
    if not self.hookedViewers then
        self.hookedViewers = {}
    end
    
    local found = {}
    
    local essentialViewer = _G["EssentialCooldownViewer"]
    if essentialViewer and essentialViewer:IsVisible() and not self.hookedViewers["EssentialCooldownViewer"] then
        self:HookCooldownButtons(essentialViewer, "EssentialCooldownViewer")
        table.insert(found, "EssentialCooldownViewer")
        self.hookedViewers["EssentialCooldownViewer"] = true
    end
    
    local utilityViewer = _G["UtilityCooldownViewer"]
    if utilityViewer and utilityViewer:IsVisible() and not self.hookedViewers["UtilityCooldownViewer"] then
        self:HookCooldownButtons(utilityViewer, "UtilityCooldownViewer")
        table.insert(found, "UtilityCooldownViewer")
        self.hookedViewers["UtilityCooldownViewer"] = true
    end
    
    local buffIconViewer = _G["BuffIconCooldownViewer"]
    if buffIconViewer and buffIconViewer:IsVisible() and not self.hookedViewers["BuffIconCooldownViewer"] then
        self:HookCooldownButtons(buffIconViewer, "BuffIconCooldownViewer")
        table.insert(found, "BuffIconCooldownViewer")
        self.hookedViewers["BuffIconCooldownViewer"] = true
    end
    
    if #found > 0 then
        self:LogSuccess("Cooldown Viewers found: " .. table.concat(found, ", "))
    else
        self:Log("No new Cooldown Viewers found")
    end
end

function PingCooldowns:HookCooldownButtons(container, viewerName)
    if not container or not container.GetNumChildren then
        return
    end
    
    local elementsFound = 0
    
    for i = 1, container:GetNumChildren() do
        local child = select(i, container:GetChildren())
        if child then
            local childType = child:GetObjectType() or "unknown"
            local childName = "unnamed"
            
            if child.GetName and type(child.GetName) == "function" then
                local success, name = pcall(child.GetName, child)
                if success and name then
                    childName = name
                end
            end
            
            local shouldHook = false
            
            if child.spellID or child.itemID or child.cooldownID then
                shouldHook = true
            elseif childType == "Button" and child.GetAttribute then
                local hasSpell = child:GetAttribute("spell")
                local hasItem = child:GetAttribute("item")
                if hasSpell or hasItem then
                    shouldHook = true
                end
            end
            
            if shouldHook then
                self:HookCooldownElement(child)
                elementsFound = elementsFound + 1
            end
        end
    end
    
    self:LogSuccess(viewerName .. ": " .. elementsFound .. " elements hooked")
    
    if container.HookScript then
        container:HookScript("OnShow", function()
            C_Timer.After(0.1, function()
                self:HookCooldownButtons(container, viewerName)
            end)
        end)
    end
end

function PingCooldowns:HookCooldownElement(element)
    if element.hookedByPingCooldowns then
        return
    end
   
    element.hookedByPingCooldowns = true
    element.pingCooldownsLastClick = 0
    element.pingCooldownsMouseOver = false
    element.pingCooldownsAltDetected = false
   
    local function ResetClickState(self)
        self.pingCooldownsAltDetected = false
    end
   
    if element.HookScript then
        local hoverSuccess = pcall(function()
            element:HookScript("OnEnter", function(self)
                self.pingCooldownsMouseOver = true
                if IsAltKeyDown() then
                    self.pingCooldownsAltDetected = true
                    PingCooldowns:Log("Alt+Hover detected, ready for click...")
                end
            end)
            
            element:HookScript("OnLeave", function(self)
                self.pingCooldownsMouseOver = false
                C_Timer.After(3.0, function()
                    if self then
                        ResetClickState(self)
                    end
                end)
            end)
            
            element:HookScript("OnUpdate", function(self)
                if self.pingCooldownsMouseOver and IsAltKeyDown() and not self.pingCooldownsAltDetected then
                    self.pingCooldownsAltDetected = true
                    PingCooldowns:Log("Alt pressed during hover, ready for click...")
                end
            end)
            
            element:HookScript("OnMouseDown", function(self, button)
                if button == "LeftButton" and self.pingCooldownsAltDetected and IsAltKeyDown() then
                    local currentTime = GetTime()
                    local timeSinceLastClick = currentTime - (self.pingCooldownsLastClick or 0)
                    
                    if timeSinceLastClick > 0.5 then
                        PingCooldowns:Log("Alt+Click detected! Triggering cooldown share...")
                        PingCooldowns:HandleCooldownClick(self)
                        ResetClickState(self)
                        self.pingCooldownsLastClick = currentTime
                    else
                        PingCooldowns:Log("Click too soon, ignoring...")
                    end
                end
            end)
        end)
    else
        self:Log("Element does not support HookScript")
    end
end
