-- File: client/main.lua (Tối ưu hóa)

local QBCore = exports['qb-core']:GetCoreObject()
local ParkedVehicles = {}
local EntityZones = {}

-- State variables to be managed by a single thread
local CurrentParkZone = nil
local IsNearParkMarker = false
local CurrentInteractSpot = nil

-- =================================================================
-- VEHICLE SPAWNING / DESPAWNING FUNCTIONS (REWRITTEN FOR EFFICIENCY)
-- =================================================================

-- NEW: Spawns a single vehicle without affecting others
local function spawnSingleVehicle(parkId, vehicle)
    if not vehicle or not vehicle.spot_id then return end
    
    local spots = Config.Zones[parkId].VehicleSpots
    local spot = spots[vehicle.spot_id]
    if not spot then return end

    -- Prevent duplicates if this vehicle is already spawned
    if ParkedVehicles[parkId] and ParkedVehicles[parkId][vehicle.plate] then return end
    
    local model = GetHashKey(vehicle.model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end

    local vehEntity = CreateVehicle(model, spot.x, spot.y, spot.z, false, false)
    SetEntityHeading(vehEntity, spot.w)
    
    if not ParkedVehicles[parkId] then ParkedVehicles[parkId] = {} end
    ParkedVehicles[parkId][vehicle.plate] = {
        car = vehEntity,
        plate = vehicle.plate,
        owner = vehicle.citizenid,
        model = vehicle.model,
        mods = vehicle.mods,
        spotId = vehicle.spot_id
    }

    QBCore.Functions.SetVehicleProperties(vehEntity, json.decode(vehicle.mods))
    SetModelAsNoLongerNeeded(model)
    SetVehicleOnGroundProperly(vehEntity)
    SetEntityInvincible(vehEntity, true)
    SetVehicleDoorsLocked(vehEntity, 3)
    FreezeEntityPosition(vehEntity, true)

    if Config.UseTarget then
        EntityZones[vehEntity] = exports['qb-target']:AddTargetEntity(vehEntity, {
            options = {
                {
                    type = 'client',
                    event = 'personalparking:client:tryRetrieveVehicle',
                    icon = 'fas fa-car-side',
                    label = 'Lấy Xe',
                    owner = vehicle.citizenid,
                    plate = vehicle.plate,
                }
            },
            distance = 2.5
        })
    end
end

-- NEW: Despawns a single vehicle by its plate
local function despawnSingleVehicle(parkId, plate)
    if not parkId or not ParkedVehicles[parkId] or not ParkedVehicles[parkId][plate] then return end
    
    local vehicle = ParkedVehicles[parkId][plate]
    if DoesEntityExist(vehicle.car) then
        QBCore.Functions.DeleteVehicle(vehicle.car)
    end
    if Config.UseTarget and EntityZones[vehicle.car] then
        exports['qb-target']:RemoveTargetEntity(vehicle.car)
        EntityZones[vehicle.car] = nil
    end
    ParkedVehicles[parkId][plate] = nil
end

-- Spawns all vehicles on initial zone entry
local function spawnAllParkedVehicles(parkId, vehicles)
    if not vehicles then return end
    for _, vehicle in ipairs(vehicles) do
        spawnSingleVehicle(parkId, vehicle)
    end
end

-- Despawns all vehicles when leaving the zone
local function despawnAllParkedVehicles(parkId)
    if not parkId or not ParkedVehicles[parkId] then return end
    for plate, _ in pairs(ParkedVehicles[parkId]) do
        despawnSingleVehicle(parkId, plate)
    end
    ParkedVehicles[parkId] = {}
end

-- =================================================================
-- ZONE CREATION AND MANAGEMENT (REWRITTEN FOR EFFICIENCY)
-- =================================================================

local function CreateZones()
    for parkId, zoneData in pairs(Config.Zones) do
        -- Main PolyZone to detect entry/exit
        local pZone = PolyZone:Create(zoneData.PolyZone, {
            name = parkId,
            minZ = zoneData.MinZ,
            maxZ = zoneData.MaxZ,
            debugPoly = false
        })

        pZone:onPlayerInOut(function(isPointInside)
            if isPointInside then
                CurrentParkZone = parkId
                QBCore.Functions.TriggerCallback('personalparking:server:getParkedVehicles', function(vehicles)
                    spawnAllParkedVehicles(CurrentParkZone, vehicles)
                end, CurrentParkZone)
            elseif CurrentParkZone == parkId then
                despawnAllParkedVehicles(parkId)
                CurrentParkZone = nil
            end
        end)

        -- CircleZone for parking - ONLY UPDATES STATE
        local markerZone = CircleZone:Create(vec3(zoneData.ParkVehicleZone.x, zoneData.ParkVehicleZone.y, zoneData.ParkVehicleZone.z), 3.0, {
            name = 'ParkMarker'..parkId,
            debugPoly = false,
        })

        markerZone:onPlayerInOut(function(isPointInside)
            IsNearParkMarker = isPointInside
        end)

        -- BoxZones for vehicle spots (non-target) - ONLY UPDATES STATE
        if not Config.UseTarget then
            for spotId, spotCoords in ipairs(zoneData.VehicleSpots) do
                local vehicleZone = BoxZone:Create(vec3(spotCoords.x, spotCoords.y, spotCoords.z), 2.5, 4.5, {
                    name = 'VehicleSpot'..parkId..spotId,
                    heading = spotCoords.w,
                    debugPoly = false,
                    minZ = spotCoords.z - 2,
                    maxZ = spotCoords.z + 2,
                })

                vehicleZone:onPlayerInOut(function(isPointInside)
                    if isPointInside then
                        CurrentInteractSpot = spotId
                    elseif CurrentInteractSpot == spotId then
                        CurrentInteractSpot = nil
                    end
                end)
            end
        end
    end
end

-- =================================================================
-- MAIN INTERACTION THREAD (PERFORMANCE IMPROVEMENT)
-- =================================================================

-- This single thread handles all interactions, preventing creation of multiple threads.
CreateThread(function()
    while true do
        Wait(5)
        local playerPed = PlayerPedId()
        local isInVehicle = IsPedInAnyVehicle(playerPed, false)
        local interactionTextShown = false

        if CurrentParkZone then
            -- Handle Parking
            if IsNearParkMarker and isInVehicle then
                interactionTextShown = true
                exports['qb-core']:DrawText('[E] - Đậu Xe', 'left')
                if IsControlJustReleased(0, 38) then -- Key E
                    TriggerEvent('personalparking:client:tryParkVehicle')
                end
            
            -- Handle Retrieving (if not using qb-target)
            elseif not Config.UseTarget and CurrentInteractSpot and not isInVehicle then
                local parkedCarData = nil
                if ParkedVehicles[CurrentParkZone] then
                    for _, vehData in pairs(ParkedVehicles[CurrentParkZone]) do
                        if vehData.spotId == CurrentInteractSpot then
                            parkedCarData = vehData
                            break
                        end
                    end
                end

                if parkedCarData then
                    interactionTextShown = true
                    exports['qb-core']:DrawText('[E] - Lấy Xe', 'left')
                    if IsControlJustReleased(0, 38) then -- Key E
                        TriggerEvent('personalparking:client:tryRetrieveVehicle', {
                            owner = parkedCarData.owner,
                            plate = parkedCarData.plate
                        })
                    end
                end
            end
        end

        if not interactionTextShown then
            exports['qb-core']:HideText()
        end
    end
end)

-- =================================================================
-- EVENTS (REWRITTEN FOR INCREMENTAL UPDATES)
-- =================================================================

-- NEW: Event to add just one vehicle to the world for all players
RegisterNetEvent('personalparking:client:addParkedVehicle', function(parkId, vehicleData)
    if CurrentParkZone and CurrentParkZone == parkId then
        spawnSingleVehicle(parkId, vehicleData)
    end
end)

-- NEW: Event to remove just one vehicle from the world for all players
RegisterNetEvent('personalparking:client:removeParkedVehicle', function(parkId, plate)
    if CurrentParkZone and CurrentParkZone == parkId then
        despawnSingleVehicle(parkId, plate)
    end
end)

RegisterNetEvent('personalparking:client:tryParkVehicle', function()
    if not CurrentParkZone then return end
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if not vehicle then
        QBCore.Functions.Notify('Bạn cần ở trong một phương tiện.', 'error')
        return
    end

    local plate = QBCore.Functions.GetPlate(vehicle)
    QBCore.Functions.TriggerCallback('personalparking:server:checkVehicleOwner', function(isOwner)
        if isOwner then
            local spots = Config.Zones[CurrentParkZone].VehicleSpots
            local parkedSpots = {}
            if ParkedVehicles[CurrentParkZone] then
                for _, vehData in pairs(ParkedVehicles[CurrentParkZone]) do
                    parkedSpots[vehData.spotId] = true
                end
            end
            local freeSpot = nil
            for i = 1, #spots do
                if not parkedSpots[i] then
                    freeSpot = i
                    break
                end
            end

            if freeSpot then
                local vehicleProps = QBCore.Functions.GetVehicleProperties(vehicle)
                QBCore.Functions.TriggerCallback('personalparking:server:getVehicleModel', function(modelName)
                    if modelName then
                        local vehicleData = { plate = plate, model = modelName, mods = vehicleProps }
                        TriggerServerEvent('personalparking:server:parkVehicle', CurrentParkZone, freeSpot, vehicleData)
                        QBCore.Functions.DeleteVehicle(vehicle)
                    end
                end, plate)
            else
                QBCore.Functions.Notify('Không còn chỗ trống trong bãi đậu xe này.', 'error')
            end
        else
            QBCore.Functions.Notify('Đây không phải là xe của bạn.', 'error')
        end
    end, plate)
end)

RegisterNetEvent('personalparking:client:tryRetrieveVehicle', function(data)
    local pData = QBCore.Functions.GetPlayerData()
    if pData.citizenid == data.owner then
        TriggerServerEvent('personalparking:server:retrieveVehicle', CurrentParkZone, data.plate)
    else
        QBCore.Functions.Notify('Đây không phải xe của bạn.', 'error')
    end
end)

RegisterNetEvent('personalparking:client:spawnRetrievedVehicle', function(vehData)
    local spawnPoint = Config.Zones[CurrentParkZone].RetrieveVehicleSpawn
    QBCore.Functions.TriggerCallback('QBCore:Server:SpawnVehicle', function(netId)
        local veh = NetToVeh(netId)
        SetVehicleNumberPlateText(veh, vehData.plate)
        SetEntityHeading(veh, spawnPoint.w)
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
        SetVehicleFuelLevel(veh, 100)
        TriggerEvent('vehiclekeys:client:SetOwner', GetVehicleNumberPlateText(veh))
        SetVehicleEngineOn(veh, true, true)
        QBCore.Functions.SetVehicleProperties(veh, json.decode(vehData.mods))
    end, vehData.model, spawnPoint, true)
end)

-- Removed 'personalparking:client:refreshVehicles' as it's no longer needed

-- Keep threads for blips and resource management
CreateThread(function()
    for parkId, zoneData in pairs(Config.Zones) do
        local blip = AddBlipForCoord(zoneData.ParkVehicleZone.x, zoneData.ParkVehicleZone.y, zoneData.ParkVehicleZone.z)
        SetBlipSprite(blip, 357)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.7)
        SetBlipAsShortRange(blip, true)
        SetBlipColour(blip, 2)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Bãi Đậu Xe Cá Nhân')
        EndTextCommandSetBlipName(blip)
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        CreateZones()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if CurrentParkZone then
            despawnAllParkedVehicles(CurrentParkZone)
        end
    end
end)