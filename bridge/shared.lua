--[[
    Bridge (shared) - detección de framework
    -----------------------------------------------------------------------
    Orden automático: qbx_core → qb-core → es_extended → ox_core → standalone.
    Se puede forzar con Config.Framework = 'qbx' | 'qb' | 'esx' | 'ox' | 'standalone'.
    El resto del recurso solo llama a Bridge.* (nunca a un framework directamente).
]]

Framework = {}

local RESOURCE = GetCurrentResourceName()

local RESOURCES = {
    qbx = 'qbx_core',
    qb = 'qb-core',
    esx = 'es_extended',
    ox = 'ox_core',
}

local DETECTION_ORDER = { 'qbx', 'qb', 'esx', 'ox' }

local ALIASES = { qbox = 'qbx', qbcore = 'qb', ['qb-core'] = 'qb', ['qbx_core'] = 'qbx', es_extended = 'esx', ox_core = 'ox' }

local LABELS = {
    qbx = 'Qbox',
    qb = 'QBCore',
    esx = 'ESX Legacy',
    ox = 'ox_core',
    standalone = 'Standalone',
}

local detected = nil

---@param resource string
---@return boolean
local function isRunning(resource)
    local state = GetResourceState(resource)
    return state == 'started' or state == 'starting'
end

---@return 'qbx'|'qb'|'esx'|'ox'|'standalone'
function Framework.Get()
    if detected then return detected end

    local forced = Config.Framework and tostring(Config.Framework):lower() or 'auto'
    forced = ALIASES[forced] or forced

    if forced == 'standalone' then
        detected = 'standalone'
    elseif RESOURCES[forced] then
        if not isRunning(RESOURCES[forced]) then
            print(('^3[%s]^7 Config.Framework = \'%s\' pero %s no está iniciado. Revisa el orden en server.cfg.'):format(RESOURCE, forced, RESOURCES[forced]))
        end
        detected = forced
    else
        if forced ~= 'auto' then
            print(('^3[%s]^7 Config.Framework = \'%s\' no es válido; se usa detección automática.'):format(RESOURCE, forced))
        end
        for i = 1, #DETECTION_ORDER do
            local key = DETECTION_ORDER[i]
            if isRunning(RESOURCES[key]) then
                detected = key
                break
            end
        end
        detected = detected or 'standalone'
    end

    return detected
end

---@return string
function Framework.Label()
    return LABELS[Framework.Get()] or 'Standalone'
end

--- QBCore o Qbox (misma estructura de PlayerData y tabla player_vehicles)
---@return boolean
function Framework.IsQBLike()
    local fw = Framework.Get()
    return fw == 'qb' or fw == 'qbx'
end
