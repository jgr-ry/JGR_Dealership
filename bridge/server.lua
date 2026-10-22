--[[
    Bridge (servidor) - QBCore / Qbox / ESX / standalone-ox_core

    Tablas de vehículos en propiedad según framework:
      - QBCore / Qbox : player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state)
      - ESX Legacy    : owned_vehicles  (owner, plate, vehicle JSON, type, stored)
      - ox_core / standalone : no hay tabla común → el vehículo se entrega pero NO se guarda
                               (se avisa una vez en consola). Ver README.

    Dinero:
      - QBCore / Qbox : Player.Functions.GetMoney / RemoveMoney / AddMoney ('cash' | 'bank')
      - ESX           : efectivo = getMoney/removeMoney/addMoney · banco = cuenta 'bank'
      - ox_core / standalone : solo efectivo, como item 'money' de ox_inventory (sin banco)
]]

Bridge = {}

local RESOURCE = GetCurrentResourceName()
local QBCore, ESX = nil, nil
local warned = {}

local function WarnOnce(key, message)
    if warned[key] then return end
    warned[key] = true
    print(('^3[%s]^7 %s'):format(RESOURCE, message))
end

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

local function HasOxInventory()
    return GetResourceState('ox_inventory') == 'started'
end

-- ============================================================================
-- JUGADOR
-- ============================================================================

---@param src number
---@return table|nil Player (QB/Qbox) o xPlayer (ESX)
function Bridge.GetPlayer(src)
    local fw = Framework.Get()
    if fw == 'qbx' then
        local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
        return ok and player or nil
    elseif fw == 'qb' then
        local core = GetQBCore()
        return core and core.Functions.GetPlayer(src) or nil
    elseif fw == 'esx' then
        local esx = GetESX()
        return esx and esx.GetPlayerFromId(src) or nil
    end
    return nil
end

--- true si el jugador existe y (si hay framework) tiene el personaje cargado
---@param src number
---@return boolean
function Bridge.IsPlayerLoaded(src)
    if not src or src <= 0 or not GetPlayerName(src) then return false end
    local fw = Framework.Get()
    if fw == 'standalone' or fw == 'ox' then return true end
    return Bridge.GetPlayer(src) ~= nil
end

--- citizenid (QB/Qbox) · identifier (ESX) · licencia (standalone/ox_core)
---@param src number
---@return string|nil
function Bridge.GetIdentifier(src)
    local fw = Framework.Get()
    if fw == 'qbx' or fw == 'qb' then
        local player = Bridge.GetPlayer(src)
        return player and player.PlayerData.citizenid or nil
    elseif fw == 'esx' then
        local xPlayer = Bridge.GetPlayer(src)
        return xPlayer and xPlayer.identifier or nil
    end
    return GetPlayerIdentifierByType(src, 'license') or GetPlayerIdentifierByType(src, 'license2')
end

--- Admin: ACE `jgr_dealership.admin` (o `command`) en cualquier framework, o el admin del framework.
---@param src number
---@return boolean
function Bridge.IsAdmin(src)
    if src == 0 then return true end
    if IsPlayerAceAllowed(src, 'jgr_dealership.admin') or IsPlayerAceAllowed(src, 'command') then
        return true
    end
    local fw = Framework.Get()
    if fw == 'qbx' then
        return IsPlayerAceAllowed(src, 'group.admin')
    elseif fw == 'qb' then
        local core = GetQBCore()
        return core ~= nil and (core.Functions.HasPermission(src, 'admin') or core.Functions.HasPermission(src, 'god'))
    elseif fw == 'esx' then
        local xPlayer = Bridge.GetPlayer(src)
        local group = xPlayer and xPlayer.getGroup() or nil
        return group == 'admin' or group == 'superadmin'
    end
    return false
end

---@param src number
---@param message string
---@param ntype string|nil
---@param duration number|nil
function Bridge.Notify(src, message, ntype, duration)
    if src == 0 then
        print(('[%s] %s'):format(RESOURCE, message))
        return
    end
    TriggerClientEvent(RESOURCE .. ':client:Notify', src, message, ntype or 'primary', duration)
end

-- ============================================================================
-- DINERO
-- ============================================================================

---@param src number
---@return { cash: number, bank: number }
function Bridge.GetBalances(src)
    local fw = Framework.Get()
    if fw == 'qbx' or fw == 'qb' then
        local player = Bridge.GetPlayer(src)
        local money = player and player.PlayerData.money or {}
        return { cash = money.cash or 0, bank = money.bank or 0 }
    elseif fw == 'esx' then
        local xPlayer = Bridge.GetPlayer(src)
        if not xPlayer then return { cash = 0, bank = 0 } end
        local bank = xPlayer.getAccount('bank')
        return { cash = xPlayer.getMoney() or 0, bank = bank and bank.money or 0 }
    end

    if HasOxInventory() then
        return { cash = exports.ox_inventory:GetItemCount(src, 'money') or 0, bank = 0 }
    end
    WarnOnce('no_money', 'Sin framework ni ox_inventory no hay sistema de dinero: las compras fallarán.')
    return { cash = 0, bank = 0 }
end

---@param src number
---@param account 'cash'|'bank'
---@param amount number
---@param reason string|nil
---@return boolean
function Bridge.RemoveMoney(src, account, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end

    local fw = Framework.Get()
    if fw == 'qbx' or fw == 'qb' then
        local player = Bridge.GetPlayer(src)
        return player ~= nil and player.Functions.RemoveMoney(account, amount, reason) == true
    elseif fw == 'esx' then
        local xPlayer = Bridge.GetPlayer(src)
        if not xPlayer then return false end
        if account == 'cash' then
            if (xPlayer.getMoney() or 0) < amount then return false end
            xPlayer.removeMoney(amount, reason)
        else
            local bank = xPlayer.getAccount('bank')
            if not bank or bank.money < amount then return false end
            xPlayer.removeAccountMoney('bank', amount, reason)
        end
        return true
    end

    if account == 'cash' and HasOxInventory() then
        if (exports.ox_inventory:GetItemCount(src, 'money') or 0) < amount then return false end
        return exports.ox_inventory:RemoveItem(src, 'money', amount) == true
    end
    return false
end

---@param src number
---@param account 'cash'|'bank'
---@param amount number
---@param reason string|nil
function Bridge.AddMoney(src, account, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end

    local fw = Framework.Get()
    if fw == 'qbx' or fw == 'qb' then
        local player = Bridge.GetPlayer(src)
        if player then player.Functions.AddMoney(account, amount, reason) end
    elseif fw == 'esx' then
        local xPlayer = Bridge.GetPlayer(src)
        if not xPlayer then return end
        if account == 'cash' then
            xPlayer.addMoney(amount, reason)
        else
            xPlayer.addAccountMoney('bank', amount, reason)
        end
    elseif account == 'cash' and HasOxInventory() then
        exports.ox_inventory:AddItem(src, 'money', amount)
    end
end

--- ¿Este framework tiene cuenta bancaria?
---@return boolean
function Bridge.SupportsBank()
    local fw = Framework.Get()
    return fw == 'qbx' or fw == 'qb' or fw == 'esx'
end

-- ============================================================================
-- VEHÍCULOS EN PROPIEDAD
-- ============================================================================

--- ¿Se guardan los vehículos comprados en base de datos con este framework?
---@return boolean
function Bridge.CanPersistVehicles()
    local fw = Framework.Get()
    return fw == 'qbx' or fw == 'qb' or fw == 'esx'
end

---@param plate string
---@return boolean
function Bridge.PlateExists(plate)
    local fw = Framework.Get()
    local query
    if fw == 'qbx' or fw == 'qb' then
        query = 'SELECT 1 FROM player_vehicles WHERE plate = ? LIMIT 1'
    elseif fw == 'esx' then
        query = 'SELECT 1 FROM owned_vehicles WHERE plate = ? LIMIT 1'
    else
        return false
    end
    return MySQL.scalar.await(query, { plate }) ~= nil
end

--- Garaje que más usa el jugador (solo QBCore/Qbox: player_vehicles.garage)
---@param identifier string
---@param isIgnored fun(name: string): boolean
---@return string|nil
function Bridge.GetMostUsedGarage(identifier, isIgnored)
    if not Framework.IsQBLike() or not identifier then return nil end
    local rows = MySQL.query.await([[
        SELECT garage, COUNT(*) AS cnt FROM player_vehicles
        WHERE citizenid = ? AND garage IS NOT NULL AND garage != ''
        GROUP BY garage ORDER BY cnt DESC LIMIT 12
    ]], { identifier })
    for _, row in ipairs(rows or {}) do
        if type(row.garage) == 'string' and row.garage ~= '' and not isIgnored(row.garage) then
            return row.garage
        end
    end
    return nil
end

--- Guarda el vehículo comprado en la tabla del framework.
---@param src number
---@param data { model: string, plate: string, garage: string|nil, state: number }
---@return boolean ok
function Bridge.SaveOwnedVehicle(src, data)
    local fw = Framework.Get()

    if fw == 'qbx' or fw == 'qb' then
        local player = Bridge.GetPlayer(src)
        if not player then return false end
        local id = MySQL.insert.await(
            'INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            {
                player.PlayerData.license,
                player.PlayerData.citizenid,
                data.model,
                joaat(data.model),
                '{}',
                data.plate,
                data.garage,
                data.state,
            }
        )
        return id ~= nil
    elseif fw == 'esx' then
        local xPlayer = Bridge.GetPlayer(src)
        if not xPlayer then return false end
        local props = json.encode({ model = joaat(data.model), plate = data.plate })
        local affected = MySQL.update.await(
            'INSERT INTO owned_vehicles (owner, plate, vehicle, type, stored) VALUES (?, ?, ?, ?, ?)',
            {
                xPlayer.identifier,
                data.plate,
                props,
                (Config.ESX and Config.ESX.vehicleType) or 'car',
                data.state,
            }
        )
        return (affected or 0) > 0
    end

    WarnOnce('no_persist', 'ox_core/standalone: los vehículos comprados no se guardan en base de datos (no hay tabla común).')
    return true
end

-- ============================================================================
-- CALLBACKS (cliente → RESOURCE:cb:request → servidor)
-- ============================================================================

local callbacks = {}

---@param name string
---@param handler fun(source: number, cb: function, ...)
function Bridge.RegisterCallback(name, handler)
    callbacks[name] = handler
end

RegisterNetEvent(RESOURCE .. ':cb:request', function(name, id, ...)
    local src = source
    if type(name) ~= 'string' or type(id) ~= 'number' then return end

    local responded = false
    local function respond(...)
        if responded then return end
        responded = true
        TriggerClientEvent(RESOURCE .. ':cb:response', src, id, ...)
    end

    local handler = callbacks[name]
    if not handler then
        respond(nil)
        return
    end

    local ok, err = pcall(handler, src, respond, ...)
    if not ok then
        print(('^1[%s]^7 Error en callback %s: %s'):format(RESOURCE, name, tostring(err)))
        respond(nil)
    end
end)

CreateThread(function()
    Wait(0)
    print(('^2[%s]^7 Framework detectado: ^5%s^7'):format(RESOURCE, Framework.Label()))
end)
