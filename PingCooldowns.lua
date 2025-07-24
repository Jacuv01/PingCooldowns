local addonName, addon = ...

addon.Logger = addon.Logger or {}
addon.PingService = addon.PingService or {}
addon.ElementHooker = addon.ElementHooker or {}
addon.RateLimiter = addon.RateLimiter or {}

local mainFrame = CreateFrame("Frame", "PingCooldownsMainFrame")
mainFrame:RegisterEvent("ADDON_LOADED")
mainFrame:RegisterEvent("PLAYER_LOGIN")

mainFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddonName = ...
        if loadedAddonName == addonName then
            addon.Logger:Info("Core", "PingCooldowns addon files loaded")
            
            if not PingCooldownsDB then
                PingCooldownsDB = { 
                    locked = false,
                    debugMode = false,
                    chatTarget = "PARTY"
                }
            end
        end
    elseif event == "PLAYER_LOGIN" then
        addon:Initialize()
        
        SLASH_PINGTEST1 = "/pingtest"
        SlashCmdList["PINGTEST"] = function(msg)
            local spellID = tonumber(msg) or 1953
            addon.Logger:Info("Core", "Testing ping with spell ID: " .. spellID)
            if addon.PingService and addon.PingService.PingSpellCooldown then
                addon.PingService:PingSpellCooldown(spellID)
            else
                print("PingService not available")
            end
        end
        
        SLASH_PINGDEBUG1 = "/pingdebug"
        SlashCmdList["PINGDEBUG"] = function(msg)
            addon.Logger:Info("Core", "=== PingCooldowns Debug Info ===")
            
            local viewers = {
                { name = "EssentialCooldownViewer", viewer = _G["EssentialCooldownViewer"] },
                { name = "UtilityCooldownViewer", viewer = _G["UtilityCooldownViewer"] },
                { name = "BuffIconCooldownViewer", viewer = _G["BuffIconCooldownViewer"] },
                { name = "BuffBarCooldownViewer", viewer = _G["BuffBarCooldownViewer"] }
            }
            
            for _, viewerData in ipairs(viewers) do
                local viewer = viewerData.viewer
                if viewer then
                    local poolCount = 0
                    if viewer.itemFramePool then
                        for frame in viewer.itemFramePool:EnumerateActive() do
                            poolCount = poolCount + 1
                        end
                    end
                    addon.Logger:Info("Core", string.format("%s: Found, Pool: %s, Active frames: %d", 
                        viewerData.name, 
                        viewer.itemFramePool and "Yes" or "No",
                        poolCount
                    ))
                else
                    addon.Logger:Info("Core", string.format("%s: NOT FOUND", viewerData.name))
                end
            end
            
            addon.Logger:Info("Core", string.format("System initialized: %s", 
                addon.ElementHooker and "Yes" or "No"))
            
            PingCooldownsDB.debugMode = true
            addon.Logger:Info("Core", "Debug mode enabled")
            
            if addon.ElementHooker and addon.ElementHooker.RefreshSystem then
                addon.ElementHooker:RefreshSystem(0)
            end
        end
        
        SLASH_PINGRESET1 = "/pingreset"
        SlashCmdList["PINGRESET"] = function()
            print("|cFFFFD700[PingCooldowns]|r Resetting system...")
            if addon.ElementHooker then
                addon.ElementHooker:Cleanup()
                C_Timer.After(1, function()
                    addon.ElementHooker:Initialize()
                    print("|cFF00FF00[PingCooldowns]|r System reset complete")
                end)
            else
                print("|cFFFF0000[PingCooldowns]|r ElementHooker not available")
            end
        end
        
        print("|cFFFFD700[PingCooldowns]|r Commands: /pingtest [spellID], /pingdebug, /pingreset")
    end
end)

