-- Punto de entrada del addon
local addonName, PingCooldowns = ...

-- Inicializar la base de datos del addon
if not PingCooldownsDB then
    PingCooldownsDB = { locked = false }
end

DEFAULT_CHAT_FRAME:AddMessage("PingCooldowns successfully loaded!")