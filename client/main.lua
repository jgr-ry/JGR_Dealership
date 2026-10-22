local uiOpen = false
local staffPanelOpen = false
local previewVehicle = nil
local previewCam = nil
local previewLightsOn = false
local dealerPeds = {}
local dealerBlips = {}
local pedToDealerKey = {}
local currentDealerKey = 'Main'
local nearestDealerKey = nil
local testDriveActive = false
local testDriveVehicle = nil
local testDriveInBucket = false
local testDriveEnding = false

local function GetDealerConfig(key)
    key = key or currentDealerKey or 'Main'
    local d = Config.Dealerships and Config.Dealerships[key]
    if not d and Config.Dealerships and Config.Dealerships.Main then
        return Config.Dealerships.Main, 'Main'
    end
    return d, key
end

local function DeletePreviewVehicle()
    previewLightsOn = false
    if previewVehicle and DoesEntityExist(previewVehicle) then
        DeleteEntity(previewVehicle)
        previewVehicle = nil
    end
end

local function DestroyPreviewCam()
    if previewCam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(previewCam, false)
        previewCam = nil
    end
end

local function CreatePreviewCam()
    local dealer, _ = GetDealerConfig(currentDealerKey)
    if not dealer or not dealer.PreviewCam then return end
    if not previewCam then
        previewCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', dealer.PreviewCam.x, dealer.PreviewCam.y, dealer.PreviewCam.z, 0.0, 0.0, 0.0, 60.0, false, 0)
        SetCamActive(previewCam, true)
        RenderScriptCams(true, true, 500, true, true)
    end
end

local function EndTestDrive(reason)
    if testDriveEnding then return end
    if not testDriveActive and not testDriveVehicle and not testDriveInBucket then return end
    testDriveEnding = true
    testDriveActive = false

    local ped = PlayerPedId()
    if testDriveVehicle and DoesEntityExist(testDriveVehicle) then
        if GetVehiclePedIsIn(ped, false) == testDriveVehicle then
            TaskLeaveVehicle(ped, testDriveVehicle, 16)
            Wait(400)
        end
        SetEntityAsMissionEntity(testDriveVehicle, true, true)
        DeleteEntity(testDriveVehicle)
        testDriveVehicle = nil
    end

    if testDriveInBucket then
        TriggerServerEvent('jgr_dealership:server:TestDriveExit')
        testDriveInBucket = false
        Wait(150)
    end

    local td = Config.TestDrive
    if td and td.returnCoords then
        DoScreenFadeOut(350)
        while not IsScreenFadedOut() do Wait(0) end
        SetEntityCoords(ped, td.returnCoords.x, td.returnCoords.y, td.returnCoords.z, false, false, false, false)
        SetEntityHeading(ped, td.returnCoords.w or 0.0)
        DoScreenFadeIn(400)
    end

    if reason == 'time' then
        Bridge.Notify('Prueba de manejo finalizada.', 'primary', 4500)
    elseif reason == 'cancel' then
        Bridge.Notify('Has cancelado la prueba de manejo.', 'error', 3500)
    elseif reason == 'exit' then
        Bridge.Notify('Te has bajado del vehículo. Vuelves al concesionario.', 'primary', 5000)
    end
    testDriveEnding = false
end

local function StartTestDrive(model)
    if testDriveActive or testDriveEnding then return end
    if not Config.TestDrive or not Config.TestDrive.enabled then
        Bridge.Notify('Las pruebas de manejo están desactivadas.', 'error')
        return
    end
    local td = Config.TestDrive
    if not td.spawn or not model or model == '' then return end

    Bridge.TriggerCallback('jgr_dealership:server:TestDriveEnter', function(ok)
        if not ok then
            Bridge.Notify('No se pudo iniciar la prueba (sesión). Inténtalo de nuevo.', 'error')
            return
        end

        testDriveInBucket = true
        uiOpen = false
        staffPanelOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'closeUI' })
        DeletePreviewVehicle()
        DestroyPreviewCam()

        if not Bridge.LoadModel(model) then
            TriggerServerEvent('jgr_dealership:server:TestDriveExit')
            testDriveInBucket = false
            Bridge.Notify('No se pudo cargar el modelo del vehículo.', 'error')
            return
        end
        testDriveActive = true
        local hash = GetHashKey(model)
        testDriveVehicle = CreateVehicle(hash, td.spawn.x, td.spawn.y, td.spawn.z, td.spawn.w or 0.0, true, false)
        SetEntityAsMissionEntity(testDriveVehicle, true, true)
        SetEntityHeading(testDriveVehicle, td.spawn.w or 0.0)
        SetVehicleNumberPlateText(testDriveVehicle, 'TEST')
        SetVehicleEngineOn(testDriveVehicle, true, true, false)
        SetVehicleFuelLevel(testDriveVehicle, 100.0)
        SetVehicleDirtLevel(testDriveVehicle, 0.0)
        TaskWarpPedIntoVehicle(PlayerPedId(), testDriveVehicle, -1)
        SetModelAsNoLongerNeeded(hash)
        Bridge.GiveKeys(testDriveVehicle)

        local duration = tonumber(td.duration) or 90
        Bridge.Notify(('Prueba aislada: %s s · [G] cancelar · Si te bajas, vuelves al concesionario.'):format(duration), 'success', 6500)

        CreateThread(function()
            local endAt = GetGameTimer() + (duration * 1000)
            local wasInTest = false
            while testDriveActive do
                Wait(100)
                local p = PlayerPedId()
                if not testDriveVehicle or not DoesEntityExist(testDriveVehicle) then
                    EndTestDrive('cancel')
                    break
                end
                local inNow = GetVehiclePedIsIn(p, false)
                if inNow == testDriveVehicle then
                    wasInTest = true
                elseif wasInTest and inNow ~= testDriveVehicle then
                    EndTestDrive('exit')
                    break
                end
                if IsControlJustPressed(0, 47) then
                    EndTestDrive('cancel')
                    break
                end
                if GetGameTimer() >= endAt then
                    EndTestDrive('time')
                    break
                end
            end
        end)
    end)
end

local function SendOpenDealershipPayload()
    Bridge.TriggerCallback('jgr_dealership:server:GetVehicles', function(vehicles)
        Bridge.TriggerCallback('jgr_dealership:server:GetBalances', function(balances)
            SendNUIMessage({
                action = 'openDealership',
                vehicles = vehicles or {},
                balances = balances or { cash = 0, bank = 0 },
                ui = {
                    locale = (Config.UI and Config.UI.Locale) or 'es',
                    currency = (Config.UI and Config.UI.CurrencySymbol) or '$',
                    brand = Config.Brand or {},
                    testDrive = Config.TestDrive and Config.TestDrive.enabled == true,
                    testDriveDuration = Config.TestDrive and tonumber(Config.TestDrive.duration) or 90
                }
            })
        end)
    end)
end

local function OpenDealership()
    if testDriveActive then
        Bridge.Notify('Termina la prueba de manejo antes de abrir el menú.', 'error')
        return
    end
    uiOpen = true
    staffPanelOpen = false
    SetNuiFocus(true, true)
    SendOpenDealershipPayload()
end

local function CloseDealership()
    uiOpen = false
    staffPanelOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeUI' })
    DeletePreviewVehicle()
    DestroyPreviewCam()
end

-- Spawn peds & blips for each dealership entry
CreateThread(function()
    local pedModelName = (Config.DealerPed and Config.DealerPed.model) or 's_m_y_dealer_01'
    local model = GetHashKey(pedModelName)
    RequestModel(model)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(10)
    end

    for key, dealer in pairs(Config.Dealerships or {}) do
        if dealer.coords then
            local c = dealer.coords
            if HasModelLoaded(model) then
                local ped = CreatePed(4, model, c.x, c.y, c.z - 1.0, dealer.PreviewSpawn and dealer.PreviewSpawn.w or 0.0, false, true)
                SetEntityHeading(ped, dealer.PreviewSpawn and dealer.PreviewSpawn.w or 0.0)
                SetEntityAsMissionEntity(ped, true, true)
                FreezeEntityPosition(ped, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetPedFleeAttributes(ped, 0, 0)
                SetPedCombatAttributes(ped, 17, 1)
                SetEntityInvincible(ped, true)
                dealerPeds[key] = ped
                pedToDealerKey[ped] = key

                if Config.UseTarget and Bridge.GetTargetSystem() then
                    local dealerKey = key
                    Bridge.AddTargetEntity(ped, 'Abrir concesionario', 'fas fa-car', function()
                        if testDriveActive then return end
                        currentDealerKey = dealerKey
                        OpenDealership()
                    end)
                end
            end

            local blip = AddBlipForCoord(c.x, c.y, c.z)
            SetBlipSprite(blip, (Config.DealerPed and Config.DealerPed.blipSprite) or 225)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, (Config.DealerPed and Config.DealerPed.blipScale) or 0.8)
            SetBlipColour(blip, (Config.DealerPed and Config.DealerPed.blipColor) or 3)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString((Config.DealerPed and Config.DealerPed.blipLabel) or 'Concesionario')
            EndTextCommandSetBlipName(blip)
            dealerBlips[key] = blip
        end
    end
    SetModelAsNoLongerNeeded(model)

    while true do
        local wait = 1000
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        nearestDealerKey = nil
        local bestDist = 9999.0
        local targetOk = Config.UseTarget and Bridge.GetTargetSystem() ~= nil

        for key, dealer in pairs(Config.Dealerships or {}) do
            if dealer.coords then
                local dist = #(pos - dealer.coords)
                if dist < bestDist then
                    bestDist = dist
                    nearestDealerKey = key
                end
                if dist < 15.0 and not targetOk then
                    -- Solo cada frame cuando estás al lado del vendedor; si no, 250 ms
                    if dist < 3.0 then
                        wait = 0
                    elseif wait > 250 then
                        wait = 250
                    end
                    if dist < 1.6 then
                        if not uiOpen and not staffPanelOpen and not testDriveActive then
                            local dPed = dealerPeds[key]
                            local tx, ty, tz = dealer.coords.x, dealer.coords.y, dealer.coords.z + 1.0
                            if dPed and DoesEntityExist(dPed) then
                                local pc = GetEntityCoords(dPed)
                                tx, ty, tz = pc.x, pc.y, pc.z + 1.0
                            end
                            Bridge.DrawText3D(tx, ty, tz, '[E] Abrir concesionario')
                            if IsControlJustPressed(0, 38) then
                                currentDealerKey = key
                                OpenDealership()
                            end
                        end
                    end
                end
            end
        end
        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    uiOpen = false
    staffPanelOpen = false
    testDriveActive = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'forceClose' })
    if testDriveVehicle and DoesEntityExist(testDriveVehicle) then
        DeleteEntity(testDriveVehicle)
        testDriveVehicle = nil
    end
    if testDriveInBucket then
        TriggerServerEvent('jgr_dealership:server:TestDriveExit')
        testDriveInBucket = false
    end
    for _, p in pairs(dealerPeds) do
        if p and DoesEntityExist(p) then
            DeleteEntity(p)
        end
    end
    dealerPeds = {}
    pedToDealerKey = {}
    for _, b in pairs(dealerBlips) do
        if b and DoesBlipExist(b) then
            RemoveBlip(b)
        end
    end
    dealerBlips = {}
    DeletePreviewVehicle()
    DestroyPreviewCam()
end)

RegisterNUICallback('close', function(_, cb)
    CloseDealership()
    cb({})
end)

RegisterNUICallback('stopPreview', function(_, cb)
    DeletePreviewVehicle()
    DestroyPreviewCam()
    cb({})
end)

RegisterNUICallback('previewVehicle', function(data, cb)
    local model = data and data.model
    if type(model) ~= 'string' or model == '' then cb({}) return end
    DeletePreviewVehicle()

    local dealer = select(1, GetDealerConfig(currentDealerKey))
    if not dealer or not dealer.PreviewSpawn then cb({}) return end

    -- Antes QBCore.Functions.LoadModel esperaba para siempre si el modelo no existía
    if not Bridge.LoadModel(model) then
        Bridge.Notify('El modelo "' .. model .. '" no existe o no se pudo cargar.', 'error')
        cb({})
        return
    end
    CreatePreviewCam()

    previewVehicle = CreateVehicle(GetHashKey(model), dealer.PreviewSpawn.x, dealer.PreviewSpawn.y, dealer.PreviewSpawn.z, dealer.PreviewSpawn.w, false, false)
    SetEntityHeading(previewVehicle, dealer.PreviewSpawn.w)
    SetVehicleModKit(previewVehicle, 0)
    SetVehicleDirtLevel(previewVehicle, 0.0)
    FreezeEntityPosition(previewVehicle, true)
    SetEntityInvincible(previewVehicle, true)
    SetVehicleDoorsLocked(previewVehicle, 2)
    SetModelAsNoLongerNeeded(GetHashKey(model))

    if previewCam then
        PointCamAtEntity(previewCam, previewVehicle, 0.0, 0.0, 0.0, true)
    end
    cb({})
end)

RegisterNUICallback('rotateCam', function(data, cb)
    if previewVehicle and previewCam then
        local heading = GetEntityHeading(previewVehicle)
        if data.dir == 'left' then
            SetEntityHeading(previewVehicle, heading + 5.0)
        elseif data.dir == 'right' then
            SetEntityHeading(previewVehicle, heading - 5.0)
        end
    end
    cb({})
end)

RegisterNUICallback('changeColor', function(data, cb)
    if not previewVehicle or not DoesEntityExist(previewVehicle) then cb({}) return end
    SetVehicleModKit(previewVehicle, 0)
    local r, g, b = tonumber(data.r), tonumber(data.g), tonumber(data.b)
    if r and g and b then
        r = math.floor(math.max(0, math.min(255, r)))
        g = math.floor(math.max(0, math.min(255, g)))
        b = math.floor(math.max(0, math.min(255, b)))
        SetVehicleColours(previewVehicle, 0, 0)
        SetVehicleExtraColours(previewVehicle, 0, 0)
        SetVehicleCustomPrimaryColour(previewVehicle, r, g, b)
        SetVehicleCustomSecondaryColour(previewVehicle, r, g, b)
    elseif data.colorId ~= nil then
        local cid = tonumber(data.colorId) or 0
        SetVehicleColours(previewVehicle, cid, cid)
    end
    cb({})
end)

RegisterNUICallback('togglePreviewLights', function(_, cb)
    if previewVehicle and DoesEntityExist(previewVehicle) then
        previewLightsOn = not previewLightsOn
        SetVehicleLights(previewVehicle, previewLightsOn and 2 or 1)
    end
    cb({})
end)

RegisterNUICallback('buyVehicle', function(data, cb)
    if data and data.vehicle then
        TriggerServerEvent('jgr_dealership:server:BuyVehicle', data.vehicle, data.paymentType or 'bank')
    end
    cb({})
end)

RegisterNUICallback('startTestDrive', function(data, cb)
    cb({})
    if data and data.model then
        StartTestDrive(data.model)
    end
end)

RegisterNUICallback('refreshBalances', function(_, cb)
    Bridge.TriggerCallback('jgr_dealership:server:GetBalances', function(balances)
        cb(balances or { cash = 0, bank = 0 })
    end)
end)

RegisterNetEvent('jgr_dealership:client:PurchaseFailed', function()
    SendNUIMessage({ action = 'purchaseFailed' })
end)

RegisterNetEvent('jgr_dealership:client:VehicleBought', function(model, plate)
    CloseDealership()
    local dealer = select(1, GetDealerConfig(currentDealerKey))
    if not dealer or not dealer.BuySpawn then return end

    if not Bridge.LoadModel(model) then
        Bridge.Notify('No se pudo cargar el modelo del vehículo comprado. Recógelo en tu garaje.', 'error')
        return
    end
    local vehicle = CreateVehicle(GetHashKey(model), dealer.BuySpawn.x, dealer.BuySpawn.y, dealer.BuySpawn.z, dealer.BuySpawn.w, true, false)
    SetVehicleNumberPlateText(vehicle, plate)
    SetEntityHeading(vehicle, dealer.BuySpawn.w)
    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
    Bridge.GiveKeys(vehicle)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetModelAsNoLongerNeeded(GetHashKey(model))
end)

RegisterNetEvent('jgr_dealership:client:OpenStaffPanel', function()
    staffPanelOpen = true
    uiOpen = false
    DeletePreviewVehicle()
    DestroyPreviewCam()
    SetNuiFocus(true, true)
    Bridge.TriggerCallback('jgr_dealership:server:GetVehicles', function(vehicles)
        SendNUIMessage({
            action = 'openStaffPanel',
            vehicles = vehicles or {}
        })
    end)
end)

RegisterNUICallback('staffAdd', function(data, cb)
    TriggerServerEvent('jgr_dealership:server:AddVehicle', data)
    cb({})
end)

RegisterNUICallback('staffEdit', function(data, cb)
    TriggerServerEvent('jgr_dealership:server:EditVehicle', data)
    cb({})
end)

RegisterNUICallback('staffDelete', function(data, cb)
    if data and data.id ~= nil then
        TriggerServerEvent('jgr_dealership:server:DeleteVehicle', data.id)
    end
    cb({})
end)

RegisterNetEvent('jgr_dealership:client:RefreshVehicles', function()
    -- Solo si hay alguna interfaz abierta (antes todos los jugadores pedían el catálogo)
    if not uiOpen and not staffPanelOpen then return end
    Bridge.TriggerCallback('jgr_dealership:server:GetVehicles', function(vehicles)
        if not vehicles then return end
        SendNUIMessage({
            action = 'refreshStaff',
            vehicles = vehicles
        })
        if uiOpen then
            Bridge.TriggerCallback('jgr_dealership:server:GetBalances', function(balances)
                SendNUIMessage({
                    action = 'refreshDealership',
                    vehicles = vehicles,
                    balances = balances
                })
            end)
        end
    end)
end)
