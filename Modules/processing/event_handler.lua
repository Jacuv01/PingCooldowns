local _, PingCooldowns = ...

function PingCooldowns:HandleCooldownClick(element)
    if not element then
        self:LogWarning("No element provided")
        return
    end
    
    local isSolo, message, groupType = self:CheckGroupStatus()
    if isSolo then
        print(message or "")
    end
    
    local elementData = {
        name = element:GetName() or "Unknown",
        type = element:GetObjectType() or "Unknown",
        spellID = nil,
        spellLink = nil,
        spellData = nil,
        extendedInfo = nil,
        groupType = groupType
    }
    
    local spellData = self:ExtractSpellFromTooltip(element)
    
    if spellData and spellData.spellID then
        elementData.spellID = spellData.spellID
        elementData.spellLink = spellData.spellLink
        elementData.spellData = spellData
        elementData.extendedInfo = spellData.extendedInfo
        
        local chatMessage = self:GenerateChatMessage(spellData)
        if chatMessage then
            self:LogSuccess("Generated chat message: " .. chatMessage)
            
            if not isSolo and groupType then
                self:LogSuccess("Using chat type: " .. groupType)
                local success = self:SendSpellStatusToChat(spellData, groupType)
                if success then
                    self:LogSuccess("Message sent to " .. groupType .. " chat")
                end
            else
                print("|cFFFFD700[PingCooldowns]|r " .. chatMessage)
                self:LogSuccess("Message shown in local chat (solo player)")
            end
            
            local rateLimitStatus = self.RateLimiter:GetStatus()
            if rateLimitStatus.inCooldown then
                self:LogWarning("Rate limiting active - cooldown: " .. rateLimitStatus.cooldownRemaining .. "s")
            else
                self:LogSuccess("Rate limit: " .. rateLimitStatus.messagesRemaining .. "/" .. rateLimitStatus.maxMessages .. " messages available")
            end
        end
    else
        self:LogWarning("No spellID found")
    end
    
    return elementData
end

function PingCooldowns:ExtractSpellFromTooltip(element)
    GameTooltip:ClearLines()
    GameTooltip:SetOwner(element, "ANCHOR_CURSOR")
    
    local tooltipSet = false
    
    if element.OnEnter and type(element.OnEnter) == "function" then
        local success = pcall(element.OnEnter, element)
        if success then
            tooltipSet = true
        end
    end
    
    if not tooltipSet and element.spellID then
        GameTooltip:SetSpellByID(element.spellID)
        tooltipSet = true
    end
    
    if tooltipSet then
        local tooltipText = GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()
        if tooltipText then
            local foundSpellID, extendedInfo = self:FindSpellIDByName(tooltipText)
            if foundSpellID then
                GameTooltip:Hide()
                return {
                    spellID = foundSpellID,
                    spellLink = C_Spell.GetSpellLink(foundSpellID),
                    extendedInfo = extendedInfo
                }
            else
                self:LogWarning("No spell match for: " .. tooltipText)
            end
        end
        GameTooltip:Hide()
    else
        self:LogWarning("Could not establish tooltip")
        GameTooltip:Hide()
    end
    
    return nil
end

function PingCooldowns:FindSpellIDByName(spellName)
    if not spellName or spellName == "" then
        return nil, nil
    end
    
    for specIndex = 1, GetNumSpecializations() do
        local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(specIndex)
        if skillLineInfo then
            for i = skillLineInfo.itemIndexOffset + 1, skillLineInfo.itemIndexOffset + skillLineInfo.numSpellBookItems do
                local spellInfo = C_SpellBook.GetSpellBookItemInfo(i, Enum.SpellBookSpellBank.Player)
                if spellInfo and spellInfo.name then
                    if spellInfo.name == spellName then
                        local extendedInfo = self:GetExtendedSpellInfo(spellInfo.spellID)
                        return spellInfo.spellID, extendedInfo
                    end
                    
                    if spellInfo.name:lower() == spellName:lower() then
                        local extendedInfo = self:GetExtendedSpellInfo(spellInfo.spellID)
                        return spellInfo.spellID, extendedInfo
                    end
                end
            end
        end
    end
    
    return nil, nil
end

function PingCooldowns:GetExtendedSpellInfo(spellID)
    if not spellID then
        return nil
    end
    
    local extendedInfo = {
        spellID = spellID,
        name = nil,
        description = nil,
        cooldown = {
            duration = 0,
            remaining = 0,
            isOnCooldown = false
        },
        charges = {
            hasCharges = false,
            currentCharges = 0,
            maxCharges = 0,
            chargeRecoveryTime = 0,
            nextChargeTime = 0
        },
        usable = {
            isUsable = false,
            notUsableReason = nil
        },
        cost = {
            hasCost = false,
            costType = nil,
            costAmount = 0
        }
    }
    
    extendedInfo.name = C_Spell.GetSpellName(spellID)
    extendedInfo.description = C_Spell.GetSpellDescription(spellID)
    
    local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
    if cooldownInfo then
        extendedInfo.cooldown.duration = cooldownInfo.duration or 0
        extendedInfo.cooldown.remaining = (cooldownInfo.startTime and cooldownInfo.duration) and 
            math.max(0, (cooldownInfo.startTime + cooldownInfo.duration) - GetTime()) or 0
        extendedInfo.cooldown.isOnCooldown = extendedInfo.cooldown.remaining > 0
    end
    
    local chargeInfo = C_Spell.GetSpellCharges(spellID)
    if chargeInfo then
        extendedInfo.charges.hasCharges = true
        extendedInfo.charges.currentCharges = chargeInfo.currentCharges or 0
        extendedInfo.charges.maxCharges = chargeInfo.maxCharges or 0
        extendedInfo.charges.chargeRecoveryTime = chargeInfo.cooldownDuration or 0
        extendedInfo.charges.nextChargeTime = (chargeInfo.cooldownStartTime and chargeInfo.cooldownDuration) and
            math.max(0, (chargeInfo.cooldownStartTime + chargeInfo.cooldownDuration) - GetTime()) or 0
    end
    
    local isUsable, notUsableReason = C_Spell.IsSpellUsable(spellID)
    extendedInfo.usable.isUsable = isUsable or false
    extendedInfo.usable.notUsableReason = notUsableReason
    
    if extendedInfo.cooldown.isOnCooldown then
        if not extendedInfo.charges.hasCharges or extendedInfo.charges.currentCharges == 0 then
            extendedInfo.usable.isUsable = false
            if not extendedInfo.usable.notUsableReason then
                extendedInfo.usable.notUsableReason = "On cooldown"
            end
        end
    end
    
    local powerCosts = C_Spell.GetSpellPowerCost(spellID)
    if powerCosts and #powerCosts > 0 then
        local primaryCost = powerCosts[1]
        if primaryCost then
            extendedInfo.cost.hasCost = true
            extendedInfo.cost.costType = primaryCost.type
            extendedInfo.cost.costAmount = primaryCost.cost or 0
        end
    end
    
    return extendedInfo
end

function PingCooldowns:GenerateChatMessage(spellData)
    if not spellData or not spellData.spellID or not spellData.spellLink then
        return nil
    end
    
    local extendedInfo = spellData.extendedInfo
    if not extendedInfo then
        return spellData.spellLink .. " - Status unknown"
    end
    
    local message = spellData.spellLink
    
    if extendedInfo.charges.hasCharges then
        local chargeStatus = extendedInfo.charges.currentCharges .. "/" .. extendedInfo.charges.maxCharges .. " Charges"
        
        if extendedInfo.charges.currentCharges == 0 then
            if extendedInfo.charges.nextChargeTime > 0 then
                message = message .. " - " .. chargeStatus .. " (Next in " .. math.ceil(extendedInfo.charges.nextChargeTime) .. "s)"
            else
                message = message .. " - " .. chargeStatus .. " (Recharging)"
            end
        elseif extendedInfo.charges.currentCharges < extendedInfo.charges.maxCharges then
            if extendedInfo.charges.nextChargeTime > 0 then
                message = message .. " - " .. chargeStatus .. " (Next in " .. math.ceil(extendedInfo.charges.nextChargeTime) .. "s)"
            else
                message = message .. " - " .. chargeStatus
            end
        else
            message = message .. " - Ready (" .. chargeStatus .. ")"
        end
    elseif extendedInfo.cooldown.isOnCooldown then
        message = message .. " - On cooldown (" .. math.ceil(extendedInfo.cooldown.remaining) .. "s)"
    else
        message = message .. " - Ready"
    end
    
    return message
end

function PingCooldowns:SendSpellStatusToChat(spellData, chatType)
    local message = self:GenerateChatMessage(spellData)
    if not message then
        self:LogWarning("Could not generate chat message")
        return false
    end
    
    local success, statusMessage = self.RateLimiter:SafeSendMessage(message, chatType or "SAY")
    
    if not success then
        self:LogWarning(statusMessage)
        if statusMessage:find("Rate limited") then
            self:LogWarning("Rate limiting active to prevent spam/bans")
        end
    end
    
    return success
end

function PingCooldowns:ResetRateLimit()
    if self.RateLimiter and self.RateLimiter.Reset then
        self.RateLimiter:Reset()
    else
        self:LogWarning("RateLimiter module not available")
    end
end

function PingCooldowns:GetRateLimitStatus()
    if self.RateLimiter and self.RateLimiter.GetStatus then
        return self.RateLimiter:GetStatus()
    else
        self:LogWarning("RateLimiter module not available")
        return nil
    end
end

function PingCooldowns:CheckGroupStatus()
    local isInRaid = IsInRaid()
    local isInGroup = IsInGroup()
    local inInstance, instanceType = IsInInstance()
    local groupType = nil
    
    local isLFGGroup = false
    if isInGroup and not isInRaid and inInstance then
        isLFGGroup = true
    end
    
    if isInRaid then
        groupType = "RAID"
    elseif isInGroup then
        if isLFGGroup then
            groupType = "INSTANCE_CHAT"
        else
            groupType = "PARTY"
        end
    elseif inInstance then
        groupType = "INSTANCE_CHAT"
    else
        groupType = nil
    end
    
    if not isInGroup and not isInRaid and not inInstance then
        local funnyMessages = {
            "Solo play is cool, but group play is cooler with this addon!",
            "Find a party and show off your cooldown skills!"
        }
        
        local randomMessage = funnyMessages[math.random(#funnyMessages)]
        return true, randomMessage, groupType
    end
    
    return false, nil, groupType
end