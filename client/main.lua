local QBCore = exports['qb-core']:GetCoreObject()

local insideZone = false
local uiOpen = false
local staffPanelOpen = false
local previewVehicle = nil
local previewCam = nil
local dealerPed = nil
local dealerBlip = nil

-- Create Dealership Interaction Point
CreateThread(function()
    -- Spawn dealer NPC and blip on resource start
    local coords = Config.Dealerships.Main.coords
    local modelName = 's_m_y_dealer_01'
    local model = GetHashKey(modelName)
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(10)
    end
    if HasModelLoaded(model) then
        dealerPed = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, 0.0, false, true)
        SetEntityHeading(dealerPed, Config.Dealerships.Main.PreviewSpawn.w or 0.0)
        SetEntityAsMissionEntity(dealerPed, true, true)
        FreezeEntityPosition(dealerPed, true)
        SetBlockingOfNonTemporaryEvents(dealerPed, true)
        SetPedFleeAttributes(dealerPed, 0, 0)
        SetPedCombatAttributes(dealerPed, 17, 1)
        SetEntityInvincible(dealerPed, true)
    end

    -- Create blip
    if coords then
        dealerBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(dealerBlip, 225)
        SetBlipDisplay(dealerBlip, 4)
        SetBlipScale(dealerBlip, 0.8)
        SetBlipAsShortRange(dealerBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Concesionario')
        EndTextCommandSetBlipName(dealerBlip)
    end

    while true do
        local wait = 1000
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local dist = #(pos - Config.Dealerships.Main.coords)

        if dist < 15.0 then
            wait = 0
            -- No marker needed here
            
            if dist < 1.5 then
                if not uiOpen and not staffPanelOpen then
                    -- Prefer showing prompt at NPC head if available
                    local tx, ty, tz = Config.Dealerships.Main.coords.x, Config.Dealerships.Main.coords.y, Config.Dealerships.Main.coords.z + 1.0
                    if dealerPed and DoesEntityExist(dealerPed) then
                        local pedCoords = GetEntityCoords(dealerPed)
                        tx, ty, tz = pedCoords.x, pedCoords.y, pedCoords.z + 1.0
                    end
                    QBCore.Functions.DrawText3D(tx, ty, tz, "[E] Abrir Concesionario")
                    if IsControlJustPressed(0, 38) then -- E
                        OpenDealership()
                    end
                end
            end
        end
        Wait(wait)
    end
end)

-- Cleanup ped and blip when resource stops
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    uiOpen = false
    staffPanelOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'forceClose' })
    if dealerPed and DoesEntityExist(dealerPed) then
        DeleteEntity(dealerPed)
        dealerPed = nil
    end
    if dealerBlip and DoesBlipExist(dealerBlip) then
        RemoveBlip(dealerBlip)
        dealerBlip = nil
    end
    DeletePreviewVehicle()
    DestroyPreviewCam()
end)

function OpenDealership()
    uiOpen = true
    staffPanelOpen = false
    SetNuiFocus(true, true)
    
    QBCore.Functions.TriggerCallback('jgr_dealership:server:GetVehicles', function(vehicles)
        SendNUIMessage({
            action = 'openDealership',
            vehicles = vehicles
        })
    end)
end

function CloseDealership()
    uiOpen = false
    staffPanelOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeUI' })
    DeletePreviewVehicle()
    DestroyPreviewCam()
end

-- Preview Vehicle Logic
function DeletePreviewVehicle()
    if previewVehicle and DoesEntityExist(previewVehicle) then
        DeleteEntity(previewVehicle)
        previewVehicle = nil
    end
end

function DestroyPreviewCam()
    if previewCam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(previewCam, false)
        previewCam = nil
    end
end

function CreatePreviewCam()
    if not previewCam then
        previewCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", Config.Dealerships.Main.PreviewCam.x, Config.Dealerships.Main.PreviewCam.y, Config.Dealerships.Main.PreviewCam.z, 0.0, 0.0, 0.0, 60.0, false, 0)
        SetCamActive(previewCam, true)
        RenderScriptCams(true, true, 500, true, true)
    end
end

RegisterNUICallback('close', function(data, cb)
    uiOpen = false
    staffPanelOpen = false
    SetNuiFocus(false, false)
    DeletePreviewVehicle()
    DestroyPreviewCam()
    cb({})
end)

RegisterNUICallback('stopPreview', function(data, cb)
    DeletePreviewVehicle()
    DestroyPreviewCam()
    cb({})
end)

RegisterNUICallback('previewVehicle', function(data, cb)
    local model = data.model
    QBCore.Functions.LoadModel(model)
    
    DeletePreviewVehicle()
    CreatePreviewCam()

    previewVehicle = CreateVehicle(GetHashKey(model), Config.Dealerships.Main.PreviewSpawn.x, Config.Dealerships.Main.PreviewSpawn.y, Config.Dealerships.Main.PreviewSpawn.z, Config.Dealerships.Main.PreviewSpawn.w, false, false)
    SetEntityHeading(previewVehicle, Config.Dealerships.Main.PreviewSpawn.w)
    FreezeEntityPosition(previewVehicle, true)
    SetEntityInvincible(previewVehicle, true)
    SetVehicleDoorsLocked(previewVehicle, 2)
    
    PointCamAtEntity(previewCam, previewVehicle, 0.0, 0.0, 0.0, true)
    
    cb({})
end)

RegisterNUICallback('rotateCam', function(data, cb)
    if previewVehicle and previewCam then
        -- Simple rotation for the vehicle itself when dragging UI
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
    if previewVehicle then
        -- Convert hex to RGB roughly, since exact hex is complex natively, using closest primary color based on string or custom logic.
        -- We will use a predefined set of colors for simplicity or map them.
        SetVehicleColours(previewVehicle, data.colorId, data.colorId) 
    end
    cb({})
end)

RegisterNUICallback('buyVehicle', function(data, cb)
    if data and data.vehicle then
        TriggerServerEvent('jgr_dealership:server:BuyVehicle', data.vehicle, data.paymentType or 'bank')
    end
    cb({})
end)

RegisterNetEvent('jgr_dealership:client:PurchaseFailed', function()
    SendNUIMessage({ action = 'purchaseFailed' })
end)

RegisterNetEvent('jgr_dealership:client:VehicleBought', function(model, plate)
    CloseDealership()
    
    QBCore.Functions.LoadModel(model)
    local vehicle = CreateVehicle(GetHashKey(model), Config.Dealerships.Main.BuySpawn.x, Config.Dealerships.Main.BuySpawn.y, Config.Dealerships.Main.BuySpawn.z, Config.Dealerships.Main.BuySpawn.w, true, false)
    SetVehicleNumberPlateText(vehicle, plate)
    SetEntityHeading(vehicle, Config.Dealerships.Main.BuySpawn.w)
    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
    TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(vehicle))
    SetVehicleEngineOn(vehicle, true, true)
end)

-- Staff Panel NUI
RegisterNetEvent('jgr_dealership:client:OpenStaffPanel', function()
    staffPanelOpen = true
    uiOpen = false
    DeletePreviewVehicle()
    DestroyPreviewCam()
    SetNuiFocus(true, true)
    QBCore.Functions.TriggerCallback('jgr_dealership:server:GetVehicles', function(vehicles)
        SendNUIMessage({
            action = 'openStaffPanel',
            vehicles = vehicles
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
    QBCore.Functions.TriggerCallback('jgr_dealership:server:GetVehicles', function(vehicles)
        SendNUIMessage({
            action = 'refreshStaff',
            vehicles = vehicles
        })
        -- If dealership is open, refresh that too
        if uiOpen then
            SendNUIMessage({
                action = 'refreshDealership',
                vehicles = vehicles
            })
        end
    end)
end)
