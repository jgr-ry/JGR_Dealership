if GetCurrentResourceName() ~= 'JGR_Dealership' then
    print(('^1[JGR]^0 Renombra la carpeta del recurso a ^3JGR_Dealership^0 (actual: ^1%s^0).'):format(GetCurrentResourceName()))
    StopResource(GetCurrentResourceName())
    return
end

-- Distancia máxima (m) a un concesionario para comprar o iniciar una prueba
local MAX_DEALER_DISTANCE = 60.0

local DEFAULT_VEHICLES = {
    { 'adder', 'Truffade Adder', 1000000, 'superdeportivos' },
    { 't20', 'Progen T20', 2200000, 'superdeportivos' },
    { 'tailgater', 'Obey Tailgater', 55000, 'sedanes' },
    { 'schafter2', 'Benefactor Schafter V12', 116000, 'sedanes' },
    { 'dubsta', 'Benefactor Dubsta', 70000, 'suvs' },
    { 'sanchez', 'Maibatsu Sanchez', 8000, 'motos' },
}

-- ============================================================================
-- BASE DE DATOS (se crea sola; sql/jgr_dealership.sql es solo de referencia)
-- ============================================================================

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `jgr_dealership_vehicles` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `model` varchar(50) NOT NULL,
            `name` varchar(100) NOT NULL,
            `price` int(11) NOT NULL DEFAULT 10000,
            `category` varchar(50) NOT NULL,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    -- Migrar categorías antiguas (supers/sedans/motorcycles → nuevas claves)
    MySQL.update.await([[UPDATE jgr_dealership_vehicles SET category = 'superdeportivos' WHERE category = 'supers']])
    MySQL.update.await([[UPDATE jgr_dealership_vehicles SET category = 'sedanes' WHERE category = 'sedans']])
    MySQL.update.await([[UPDATE jgr_dealership_vehicles SET category = 'motos' WHERE category = 'motorcycles']])

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM jgr_dealership_vehicles') or 0
    if count == 0 then
        for _, v in ipairs(DEFAULT_VEHICLES) do
            MySQL.insert.await('INSERT INTO jgr_dealership_vehicles (model, name, price, category) VALUES (?, ?, ?, ?)', v)
        end
        print('^2[JGR_Dealership]^7 Base de datos creada y llenada con vehículos por defecto.')
    else
        print('^2[JGR_Dealership]^7 Base de datos cargada correctamente.')
    end
end)

-- ============================================================================
-- UTILIDADES
-- ============================================================================

--- ¿Está el jugador cerca de algún concesionario configurado?
---@param src number
---@return boolean
local function IsNearDealership(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    for _, dealer in pairs(Config.Dealerships or {}) do
        if dealer.coords and #(pos - vector3(dealer.coords.x, dealer.coords.y, dealer.coords.z)) <= MAX_DEALER_DISTANCE then
            return true
        end
    end
    return false
end

---@param vehicleData table
---@return table|nil fila de jgr_dealership_vehicles
local function FindCatalogVehicle(vehicleData)
    if type(vehicleData) ~= 'table' then return nil end
    local id = tonumber(vehicleData.id)
    if id then
        return MySQL.single.await('SELECT * FROM jgr_dealership_vehicles WHERE id = ? LIMIT 1', { id })
    end
    local model = vehicleData.model and tostring(vehicleData.model) or nil
    if model and model ~= '' then
        return MySQL.single.await('SELECT * FROM jgr_dealership_vehicles WHERE model = ? ORDER BY price ASC LIMIT 1', { model })
    end
    return nil
end

-- ============================================================================
-- CALLBACKS
-- ============================================================================

Bridge.RegisterCallback('jgr_dealership:server:GetVehicles', function(source, cb)
    cb(MySQL.query.await('SELECT * FROM jgr_dealership_vehicles ORDER BY category ASC, price ASC, name ASC') or {})
end)

Bridge.RegisterCallback('jgr_dealership:server:GetBalances', function(source, cb)
    cb(Bridge.GetBalances(source))
end)

-- Prueba de manejo: routing bucket (dimensión) aislada; se restaura la anterior al salir
local TestDrivePrevBucket = {}

Bridge.RegisterCallback('jgr_dealership:server:TestDriveEnter', function(source, cb)
    local src = source
    if not Config.TestDrive or not Config.TestDrive.enabled then
        cb(false)
        return
    end
    if TestDrivePrevBucket[src] ~= nil or not IsNearDealership(src) then
        cb(false)
        return
    end
    local minB = tonumber(Config.TestDrive.routingBucketMin) or 5
    local maxB = tonumber(Config.TestDrive.routingBucketMax) or 999999
    if maxB < minB then minB, maxB = maxB, minB end
    local prev = GetPlayerRoutingBucket(src)
    local span = maxB - minB + 1
    local rnd = math.random(0, span - 1)
    -- Mezcla con src para reducir colisiones si varios entran el mismo tick
    local mix = (src * 1103515245 + 12345) % span
    local newB = minB + ((rnd + mix) % span)
    TestDrivePrevBucket[src] = prev
    SetPlayerRoutingBucket(src, newB)
    cb(true)
end)

RegisterNetEvent('jgr_dealership:server:TestDriveExit', function()
    local src = source
    local prev = TestDrivePrevBucket[src]
    -- Solo se restaura si de verdad estaba en una prueba (antes cualquier cliente podía
    -- llamar al evento y forzarse al bucket 0, saliendo de otras dimensiones)
    if prev == nil then return end
    TestDrivePrevBucket[src] = nil
    SetPlayerRoutingBucket(src, prev)
end)

AddEventHandler('playerDropped', function()
    TestDrivePrevBucket[source] = nil
end)

-- ============================================================================
-- STAFF
-- ============================================================================

RegisterCommand('staffconcesionario', function(source)
    if source == 0 then return end
    if not Bridge.IsAdmin(source) then
        Bridge.Notify(source, 'No tienes permiso para usar este comando', 'error')
        return
    end
    TriggerClientEvent('jgr_dealership:client:OpenStaffPanel', source)
end, false)

---@param data table
---@return string|nil name, string|nil category, integer|nil price
local function ReadStaffVehicle(data)
    local name = tostring(data.name or ''):sub(1, 100)
    local category = tostring(data.category or ''):sub(1, 50)
    local price = math.floor(tonumber(data.price) or 0)
    if name == '' or category == '' or price <= 0 or price > 2147483647 then return nil end
    return name, category, price
end

RegisterNetEvent('jgr_dealership:server:AddVehicle', function(data)
    local src = source
    if type(data) ~= 'table' or not Bridge.IsAdmin(src) then return end
    local model = tostring(data.model or ''):sub(1, 50)
    local name, category, price = ReadStaffVehicle(data)
    if model == '' or not name then return end
    MySQL.insert('INSERT INTO jgr_dealership_vehicles (model, name, price, category) VALUES (?, ?, ?, ?)', {
        model, name, price, category
    }, function()
        Bridge.Notify(src, 'Vehículo añadido correctamente', 'success')
        TriggerClientEvent('jgr_dealership:client:RefreshVehicles', -1)
    end)
end)

RegisterNetEvent('jgr_dealership:server:EditVehicle', function(data)
    local src = source
    if type(data) ~= 'table' or not Bridge.IsAdmin(src) then return end
    local id = tonumber(data.id)
    local name, category, price = ReadStaffVehicle(data)
    if not id or not name then return end
    MySQL.update('UPDATE jgr_dealership_vehicles SET name = ?, price = ?, category = ? WHERE id = ?', {
        name, price, category, id
    }, function()
        Bridge.Notify(src, 'Vehículo editado correctamente', 'success')
        TriggerClientEvent('jgr_dealership:client:RefreshVehicles', -1)
    end)
end)

RegisterNetEvent('jgr_dealership:server:DeleteVehicle', function(id)
    local src = source
    local vid = tonumber(id)
    if not vid or not Bridge.IsAdmin(src) then return end
    MySQL.update('DELETE FROM jgr_dealership_vehicles WHERE id = ?', { vid }, function()
        Bridge.Notify(src, 'Vehículo eliminado', 'success')
        TriggerClientEvent('jgr_dealership:client:RefreshVehicles', -1)
    end)
end)

-- ============================================================================
-- GARAJE DETECTADO + ESTADO "FUERA" AL COMPRAR (QBCore / Qbox)
-- ============================================================================

local function IsIgnoredGarageName(name)
    if not name or name == '' then return true end
    local n = string.lower(tostring(name))
    local t = (Config.GarageResolver and Config.GarageResolver.ignoreGarageNames) or {}
    for bad, _ in pairs(t) do
        if string.lower(tostring(bad)) == n then
            return true
        end
    end
    return false
end

--- Garaje "lógico" para player_vehicles.garage (el script de garajes lo usará al guardar).
--- En ESX / standalone devuelve nil (owned_vehicles no tiene columna de garaje estándar).
local function ResolveGarageForNewVehicle(src)
    if not Framework.IsQBLike() then return nil end

    local gr = Config.GarageResolver
    local cid = Bridge.GetIdentifier(src)

    if gr and type(gr.tryExports) == 'table' then
        for _, ex in ipairs(gr.tryExports) do
            if type(ex) == 'table' and ex.resource and ex.export and GetResourceState(ex.resource) == 'started' then
                local ok, result = pcall(function()
                    local res = exports[ex.resource]
                    if ex.type == 'citizenid' then
                        return res[ex.export](res, cid)
                    end
                    return res[ex.export](res, src)
                end)
                if ok and type(result) == 'string' and result ~= '' and not IsIgnoredGarageName(result) then
                    return result
                end
            end
        end
    end

    if gr == nil or gr.sqlFallback ~= false then
        local garage = Bridge.GetMostUsedGarage(cid, IsIgnoredGarageName)
        if garage then return garage end
    end

    return Config.DefaultGarage or 'pillboxgarage'
end

-- ============================================================================
-- COMPRA
-- ============================================================================

local LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'

local function RandomLetters(n)
    local out = {}
    for i = 1, n do
        local r = math.random(1, #LETTERS)
        out[i] = LETTERS:sub(r, r)
    end
    return table.concat(out)
end

local function RandomDigits(n)
    local out = {}
    for i = 1, n do out[i] = tostring(math.random(0, 9)) end
    return table.concat(out)
end

--- Matrícula de 8 caracteres (formato QBCore: 1 número, 2 letras, 3 números, 2 letras) única en la tabla del framework
local function GeneratePlate()
    for _ = 1, 50 do
        local plate = (RandomDigits(1) .. RandomLetters(2) .. RandomDigits(3) .. RandomLetters(2)):upper()
        if not Bridge.PlateExists(plate) then
            return plate
        end
    end
    return nil
end

local purchasing = {}

RegisterNetEvent('jgr_dealership:server:BuyVehicle', function(vehicleData, paymentType)
    local src = source
    if purchasing[src] then return end
    if not Bridge.IsPlayerLoaded(src) then return end

    local function failed(message)
        if message then Bridge.Notify(src, message, 'error') end
        TriggerClientEvent('jgr_dealership:client:PurchaseFailed', src)
    end

    if not IsNearDealership(src) then
        failed('Tienes que estar en el concesionario para comprar.')
        return
    end

    -- El precio y el modelo salen SIEMPRE de la base de datos, nunca del cliente
    local row = FindCatalogVehicle(vehicleData)
    if not row then
        failed('Ese vehículo no está a la venta.')
        return
    end
    local price = math.floor(tonumber(row.price) or 0)
    local model = tostring(row.model or '')
    local vehName = tostring(row.name or model)
    if price <= 0 or model == '' then
        failed()
        return
    end

    if paymentType ~= 'bank' and paymentType ~= 'cash' then paymentType = 'bank' end
    if paymentType == 'bank' and not Bridge.SupportsBank() then paymentType = 'cash' end

    purchasing[src] = true

    local plate = GeneratePlate()
    if not plate then
        purchasing[src] = nil
        failed('No se pudo generar una matrícula. Inténtalo de nuevo.')
        return
    end

    if not Bridge.RemoveMoney(src, paymentType, price, 'vehicle-bought-dealership') then
        purchasing[src] = nil
        failed('No tienes suficiente dinero en tu ' .. (paymentType == 'bank' and 'cuenta bancaria' or 'cartera'))
        return
    end

    local outState = Config.VehicleOutState
    if outState == nil then outState = 0 end

    local saved = Bridge.SaveOwnedVehicle(src, {
        model = model,
        plate = plate,
        garage = ResolveGarageForNewVehicle(src),
        state = outState,
    })

    purchasing[src] = nil

    if not saved then
        -- Si no se pudo guardar, se devuelve el dinero
        Bridge.AddMoney(src, paymentType, price, 'vehicle-bought-dealership-refund')
        failed('Error al registrar el vehículo. Se te ha devuelto el dinero.')
        return
    end

    TriggerClientEvent('jgr_dealership:client:VehicleBought', src, model, plate)
    Bridge.Notify(src,
        'Has comprado un ' .. vehName .. ' por ' .. ((Config.UI and Config.UI.CurrencySymbol) or '$') .. price
        .. ' (' .. (paymentType == 'bank' and 'banco' or 'efectivo') .. '). '
        .. 'Te lo llevas desde aquí; en base de datos queda fuera de garaje hasta que lo guardes con tu script de garajes.',
        'success', 8000)
end)

AddEventHandler('playerDropped', function()
    purchasing[source] = nil
end)
