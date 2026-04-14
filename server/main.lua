local QBCore = exports['qb-core']:GetCoreObject()

-- Auto-import SQL en el inicio del script
MySQL.ready(function()
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `jgr_dealership_vehicles` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `model` varchar(50) NOT NULL,
            `name` varchar(100) NOT NULL,
            `price` int(11) NOT NULL DEFAULT 10000,
            `category` varchar(50) NOT NULL,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]], {}, function()
        -- Migrar categorías antiguas (supers/sedans/motorcycles → nuevas claves)
        MySQL.Async.execute([[UPDATE jgr_dealership_vehicles SET category = 'superdeportivos' WHERE category = 'supers']], {})
        MySQL.Async.execute([[UPDATE jgr_dealership_vehicles SET category = 'sedanes' WHERE category = 'sedans']], {})
        MySQL.Async.execute([[UPDATE jgr_dealership_vehicles SET category = 'motos' WHERE category = 'motorcycles']], {})
        MySQL.Async.fetchAll('SELECT COUNT(*) as count FROM jgr_dealership_vehicles', {}, function(result)
            if result[1] and result[1].count == 0 then
                MySQL.Async.execute([[
                    INSERT INTO `jgr_dealership_vehicles` (`model`, `name`, `price`, `category`) VALUES
                    ('adder', 'Truffade Adder', 1000000, 'superdeportivos'),
                    ('t20', 'Progen T20', 2200000, 'superdeportivos'),
                    ('tailgater', 'Obey Tailgater', 55000, 'sedanes'),
                    ('schafter2', 'Benefactor Schafter V12', 116000, 'sedanes'),
                    ('dubsta', 'Benefactor Dubsta', 70000, 'suvs'),
                    ('sanchez', 'Maibatsu Sanchez', 8000, 'motos');
                ]])
                print("^2[JGR_Dealership]^7 Base de datos creada y llenada con vehículos por defecto.")
            else
                print("^2[JGR_Dealership]^7 Base de datos cargada correctamente.")
            end
        end)
    end)
end)

-- Fetch Vehicles Callback
QBCore.Functions.CreateCallback('jgr_dealership:server:GetVehicles', function(source, cb)
    MySQL.Async.fetchAll('SELECT * FROM jgr_dealership_vehicles', {}, function(result)
        cb(result)
    end)
end)

-- Staff Command
QBCore.Commands.Add('staffconcesionario', 'Abre el panel de administración del concesionario', {}, false, function(source, args)
    TriggerClientEvent('jgr_dealership:client:OpenStaffPanel', source)
end, 'admin')

-- Staff Actions
RegisterNetEvent('jgr_dealership:server:AddVehicle', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    if QBCore.Functions.HasPermission(src, 'admin') then
        local model = tostring(data.model or '')
        local name = tostring(data.name or '')
        local category = tostring(data.category or '')
        local price = tonumber(data.price) or 0
        if model == '' or name == '' or category == '' or price <= 0 then return end
        MySQL.Async.insert('INSERT INTO jgr_dealership_vehicles (model, name, price, category) VALUES (?, ?, ?, ?)', {
            model, name, price, category
        }, function(id)
            TriggerClientEvent('QBCore:Notify', src, 'Vehículo añadido correctamente', 'success')
            TriggerClientEvent('jgr_dealership:client:RefreshVehicles', -1)
        end)
    end
end)

RegisterNetEvent('jgr_dealership:server:EditVehicle', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    if QBCore.Functions.HasPermission(src, 'admin') then
        local id = tonumber(data.id)
        local name = tostring(data.name or '')
        local category = tostring(data.category or '')
        local price = tonumber(data.price) or 0
        if not id or name == '' or category == '' or price <= 0 then return end
        MySQL.Async.execute('UPDATE jgr_dealership_vehicles SET name = ?, price = ?, category = ? WHERE id = ?', {
            name, price, category, id
        }, function(affectedRows)
            TriggerClientEvent('QBCore:Notify', src, 'Vehículo editado correctamente', 'success')
            TriggerClientEvent('jgr_dealership:client:RefreshVehicles', -1)
        end)
    end
end)

RegisterNetEvent('jgr_dealership:server:DeleteVehicle', function(id)
    local src = source
    local vid = tonumber(id)
    if not vid then return end
    if QBCore.Functions.HasPermission(src, 'admin') then
        MySQL.Async.execute('DELETE FROM jgr_dealership_vehicles WHERE id = ?', {vid}, function(affectedRows)
            TriggerClientEvent('QBCore:Notify', src, 'Vehículo eliminado', 'success')
            TriggerClientEvent('jgr_dealership:client:RefreshVehicles', -1)
        end)
    end
end)

-- Buy Vehicle
local function GeneratePlate()
    local plate = QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(2)
    local result = MySQL.Sync.fetchScalar('SELECT plate FROM player_vehicles WHERE plate = ?', {plate})
    if result then
        return GeneratePlate()
    else
        return plate:upper()
    end
end

RegisterNetEvent('jgr_dealership:server:BuyVehicle', function(vehicleData, paymentType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if type(vehicleData) ~= 'table' then return end
    local price = tonumber(vehicleData.price) or 0
    local model = tostring(vehicleData.model or '')
    local vehName = tostring(vehicleData.name or model)
    if price <= 0 or model == '' then
        TriggerClientEvent('jgr_dealership:client:PurchaseFailed', src)
        return
    end

    if paymentType ~= 'bank' and paymentType ~= 'cash' then paymentType = 'bank' end

    if Player.Functions.RemoveMoney(paymentType, price, 'vehicle-bought-dealership') then
        local plate = GeneratePlate()
        MySQL.Async.insert('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
            Player.PlayerData.license,
            Player.PlayerData.citizenid,
            model,
            GetHashKey(model),
            '{}',
            plate,
            'pillboxgarage', 
            0
        }, function(id)
            TriggerClientEvent('jgr_dealership:client:VehicleBought', src, model, plate)
            TriggerClientEvent('QBCore:Notify', src, 'Has comprado un ' .. vehName .. ' por $' .. price .. ' con ' .. (paymentType == 'bank' and 'tarjeta' or 'efectivo'), 'success')
        end)
    else
        TriggerClientEvent('QBCore:Notify', src, 'No tienes suficiente dinero en tu ' .. (paymentType == 'bank' and 'cuenta bancaria' or 'cartera'), 'error')
        TriggerClientEvent('jgr_dealership:client:PurchaseFailed', src)
    end
end)
