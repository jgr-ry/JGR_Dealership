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
    if QBCore.Functions.HasPermission(src, 'admin') then
        MySQL.Async.insert('INSERT INTO jgr_dealership_vehicles (model, name, price, category) VALUES (?, ?, ?, ?)', {
            data.model, data.name, data.price, data.category
        }, function(id)
            TriggerClientEvent('QBCore:Notify', src, 'Vehículo añadido correctamente', 'success')
            TriggerClientEvent('jgr_dealership:client:RefreshVehicles', -1)
        end)
    end
end)

RegisterNetEvent('jgr_dealership:server:EditVehicle', function(data)
    local src = source
    if QBCore.Functions.HasPermission(src, 'admin') then
        MySQL.Async.execute('UPDATE jgr_dealership_vehicles SET name = ?, price = ?, category = ? WHERE id = ?', {
            data.name, data.price, data.category, data.id
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
    local price = tonumber(vehicleData.price)

    if not paymentType then paymentType = 'bank' end

    if Player.Functions.RemoveMoney(paymentType, price, 'vehicle-bought-dealership') then
        local plate = GeneratePlate()
        MySQL.Async.insert('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
            Player.PlayerData.license,
            Player.PlayerData.citizenid,
            vehicleData.model,
            GetHashKey(vehicleData.model),
            '{}',
            plate,
            'pillboxgarage', 
            0
        }, function(id)
            TriggerClientEvent('jgr_dealership:client:VehicleBought', src, vehicleData.model, plate)
            TriggerClientEvent('QBCore:Notify', src, 'Has comprado un ' .. vehicleData.name .. ' por $' .. price .. ' con ' .. (paymentType == 'bank' and 'tarjeta' or 'efectivo'), 'success')
        end)
    else
        TriggerClientEvent('QBCore:Notify', src, 'No tienes suficiente dinero en tu ' .. (paymentType == 'bank' and 'cuenta bancaria' or 'cartera'), 'error')
        TriggerClientEvent('jgr_dealership:client:PurchaseFailed', src)
    end
end)
