--[[
    Bridge (cliente) - QBCore / Qbox / ESX / standalone-ox_core
]]

Bridge = {}

local RESOURCE = GetCurrentResourceName()
local QBCore, ESX = nil, nil

local function GetQBCore()
    if not QBCore and GetResourceState('qb-core') == 'started' then
        local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
        if ok then QBCore = obj end
    end
    return QBCore
end

local function GetESX()
    if not ESX and GetResourceState('es_extended') == 'started' then
        local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
        if ok then ESX = obj end
    end
    return ESX
end

-- ============================================================================
-- NOTIFICACIONES
-- ============================================================================

local OX_TYPES = { primary = 'inform', info = 'inform', inform = 'inform', success = 'success', error = 'error', warning = 'warning' }

---@param message string
---@param ntype string|nil 'primary' | 'success' | 'error' | 'warning'
---@param duration number|nil
function Bridge.Notify(message, ntype, duration)
    message = tostring(message)
    ntype = ntype or 'primary'
    duration = duration or 5000

    local fw = Framework.Get()
    if fw == 'qbx' then
        if pcall(function() exports.qbx_core:Notify(message, OX_TYPES[ntype] or 'inform', duration) end) then return end
    elseif fw == 'qb' then
        local core = GetQBCore()
        if core then
            core.Functions.Notify(message, ntype, duration)
            return
        end
    elseif fw == 'esx' then
        local esx = GetESX()
        if esx then
            esx.ShowNotification(message)
            return
        end
    end

    if GetResourceState('ox_lib') == 'started' then
        if pcall(function()
            exports.ox_lib:notify({ description = message, type = OX_TYPES[ntype] or 'inform', duration = duration })
        end) then return end
    end

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, true)
end

RegisterNetEvent(RESOURCE .. ':client:Notify', function(message, ntype, duration)
    Bridge.Notify(message, ntype, duration)
end)

-- ============================================================================
-- CALLBACKS (sistema propio, igual en todos los frameworks)
-- ============================================================================

local pending = {}
local seq = 0

---@param name string
---@param cb function
---@param ... any
function Bridge.TriggerCallback(name, cb, ...)
    seq = seq + 1
    local id = seq
    pending[id] = cb
    TriggerServerEvent(RESOURCE .. ':cb:request', name, id, ...)
    SetTimeout(15000, function()
        local fn = pending[id]
        if fn then
            pending[id] = nil
            fn(nil)
        end
    end)
end

RegisterNetEvent(RESOURCE .. ':cb:response', function(id, ...)
    local fn = pending[id]
    if not fn then return end
    pending[id] = nil
    fn(...)
end)

-- ============================================================================
-- VEHÍCULOS / MODELOS
-- ============================================================================

--- Carga un modelo con timeout. Devuelve false si el modelo no existe o no carga.
---@param model string|number
---@return boolean
function Bridge.LoadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        return false
    end
    RequestModel(hash)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return false end
        Wait(10)
    end
    return true
end

---@param vehicle number
---@return string|nil
function Bridge.GetPlate(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end
    local plate = GetVehicleNumberPlateText(vehicle)
    return plate and (plate:gsub('^%s+', ''):gsub('%s+$', '')) or nil
end

--- Llaves: delega en Config.GiveVehicleKeys (editable en config.lua)
---@param vehicle number
function Bridge.GiveKeys(vehicle)
    if type(Config.GiveVehicleKeys) ~= 'function' then return end
    local ok, err = pcall(Config.GiveVehicleKeys, vehicle, Bridge.GetPlate(vehicle), Framework.Get())
    if not ok then
        print(('^1[%s]^7 Error en Config.GiveVehicleKeys: %s'):format(RESOURCE, tostring(err)))
    end
end

-- ============================================================================
-- TEXTO 3D / TARGET
-- ============================================================================

function Bridge.DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 215)
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    SetDrawOrigin(x, y, z, 0)
    EndTextCommandDisplayText(0.0, 0.0)
    local factor = string.len(text) / 370
    DrawRect(0.0, 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

--- Nombre del sistema de target disponible ('ox_target' | 'qb-target' | nil)
---@return string|nil
function Bridge.GetTargetSystem()
    if GetResourceState('ox_target') == 'started' then return 'ox_target' end
    if GetResourceState('qb-target') == 'started' then return 'qb-target' end
    return nil
end

--- Añade una opción de target a una entidad local. Devuelve true si se pudo.
---@param entity number
---@param label string
---@param icon string
---@param onSelect function
---@return boolean
function Bridge.AddTargetEntity(entity, label, icon, onSelect)
    local system = Bridge.GetTargetSystem()
    if system == 'ox_target' then
        return pcall(function()
            exports.ox_target:addLocalEntity(entity, {
                {
                    name = RESOURCE .. ':open',
                    label = label,
                    icon = icon,
                    distance = 2.5,
                    onSelect = onSelect,
                }
            })
        end)
    elseif system == 'qb-target' then
        return pcall(function()
            exports['qb-target']:AddTargetEntity(entity, {
                options = {
                    { icon = icon, label = label, action = onSelect }
                },
                distance = 2.5
            })
        end)
    end
    return false
end
