Config = {}

-- [[ Framework ]]
-- 'auto' (recomendado) | 'qbx' | 'qb' | 'esx' | 'ox' | 'standalone'
-- 'auto' detecta en este orden: qbx_core → qb-core → es_extended → ox_core → standalone
Config.Framework = 'auto'

-- [[ General ]]
-- Garaje por defecto si no se puede detectar otro (nombre interno de tu script de garajes).
-- Solo QBCore / Qbox (columna player_vehicles.garage). En ESX no se usa.
Config.DefaultGarage = 'pillboxgarage'

--[[
  Al comprar: el jugador spawnea dentro del coche (cliente). En BD:
  - garage = garaje "de casa" detectado (para que tu script de garajes sepa dónde guardarlo luego)
  - state = 0  = vehículo fuera / en calle (no metido en el garaje todavía)
  Ajusta state si tu framework usa otra convención (algunos usan 1=fuera).
  En ESX este valor se guarda en owned_vehicles.stored (0 = fuera, 1 = guardado).
]]
Config.VehicleOutState = 0

Config.GarageResolver = {
    -- Consulta tus vehículos actuales y usa el garaje que más repitas (misma lógica que "el garaje que ya usas")
    sqlFallback = true,
    -- Nombres de garaje que no queremos tomar como "casa" (fantasma / depósito / etc.)
    ignoreGarageNames = {
        [''] = true,
        ['none'] = true,
        ['NONE'] = true,
        ['out'] = true,
        ['OUT'] = true,
        ['depot'] = true,
        ['impound'] = true,
    },
    -- Intentos opcionales (solo QBCore / Qbox): export de otro recurso que devuelva string (nombre de garaje)
    -- type: 'source' = export(src) | 'citizenid' = export(citizenid)
    tryExports = {
        -- { resource = 'qb-garages', export = 'GetDefaultGarage', type = 'source' },
    }
}

Config.Brand = {
    title = 'JGR MOTORS',
    subtitle = 'PREMIUM DEALER',
    tagline = 'Encuentra tu próximo vehículo con garantía y entrega inmediata.'
}

-- [[ ESX ]]
Config.ESX = {
    vehicleType = 'car', -- valor de owned_vehicles.type para los vehículos comprados
}

-- [[ Llaves ]]
-- Se llama en el cliente al entregar el coche comprado y el de la prueba de manejo.
-- Adáptalo a tu script de llaves. framework = 'qbx' | 'qb' | 'esx' | 'ox' | 'standalone'
Config.GiveVehicleKeys = function(vehicle, plate, framework)
    if framework == 'qb' or framework == 'qbx' then
        TriggerEvent('vehiclekeys:client:SetOwner', plate) -- qb-vehiclekeys
    end
    -- Ejemplos para otros sistemas:
    -- exports.wasabi_carlock:GiveKey(plate)
    -- TriggerServerEvent('qs-vehiclekeys:server:GiveVehicleKeys', plate)
end

-- [[ Interacción ]]
-- Si true y tienes ox_target o qb-target, se añade interacción al vendedor.
-- Si no hay target iniciado, se usa la tecla E.
Config.UseTarget = false

Config.DealerPed = {
    model = 's_m_y_dealer_01',
    blipSprite = 225,
    blipScale = 0.8,
    blipColor = 3,
    blipLabel = 'Concesionario'
}

-- [[ Prueba de manejo ]]
Config.TestDrive = {
    enabled = true,
    duration = 90, -- segundos
    -- Routing bucket (dimensión) aleatorio para no cruzarte con otros jugadores en la prueba
    routingBucketMin = 5,
    routingBucketMax = 999999,
    -- Punto de salida de la prueba (cerca del concesionario Legion Square por defecto)
    spawn = vector4(-47.2, -1077.5, 26.7, 70.0),
    -- Donde reaparece el jugador al terminar (acera del concesionario)
    returnCoords = vector4(-33.84, -1102.13, 26.42, 250.0)
}

-- [[ Dealership Locations ]]
-- Puedes duplicar entradas (ej. Sandy, Paleto) con coords y spawns propios
Config.Dealerships = {
    Main = {
        coords = vector3(-33.84, -1102.13, 26.42),
        interactType = 'marker', -- reservado; la interacción real es E / target

        PreviewSpawn = vector4(-44.59, -1098.39, 26.42, 107.41),
        PreviewCam = vector3(-40.24, -1095.83, 27.5),

        BuySpawn = vector4(-31.62, -1090.87, 26.42, 340.35)
    }
}

-- [[ UI Settings ]]
Config.UI = {
    CurrencySymbol = '$',
    Locale = 'es' -- 'es' | 'en' (textos de la NUI que cambian por JS)
}
