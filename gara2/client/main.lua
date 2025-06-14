local QBCore = exports['qb-core']:GetCoreObject()
local CurrentParkZone = nil
local ActiveZones = {}
local EntityZones = {}
local ParkedVehicles = {}

-- ==========================================================================================
--                              HÀM TIỆN ÍCH
-- ==========================================================================================

local function getFreeSpot(parkId)
    local spots = Config.Zones[parkId].VehicleSpots
    local parkedSpots = {}
    if ParkedVehicles[parkId] then
        for _, vehicle in pairs(ParkedVehicles[parkId]) do
            parkedSpots[vehicle.spotId] = true
        end
    end

    local freeSpots = {}
    for i = 1, #spots do
        if not parkedSpots[i] then
            table.insert(freeSpots, i)
        end
    end

    if #freeSpots > 0 then
        local randomIndex = math.random(#freeSpots)
        return freeSpots[randomIndex]
    end

    return nil
end

local function spawnParkedVehicles(parkId, vehicles)
    if not vehicles then return end
    local spots = Config.Zones[parkId].VehicleSpots
    if not ParkedVehicles[parkId] then ParkedVehicles[parkId] = {} end

    for _, vehicle in ipairs(vehicles) do
        local mods = json.decode(vehicle.mods)
        local spotId = mods.parking_spot -- Đọc vị trí đã lưu từ mods

        if spotId then
            mods.parking_spot = nil -- Xóa thông tin vị trí khỏi bảng mods trước khi áp dụng
            local spot = spots[spotId]

            local isSpotTaken = false
            if ParkedVehicles[parkId] then
                for _, parkedVeh in pairs(ParkedVehicles[parkId]) do
                    if parkedVeh.spotId == spotId then
                        isSpotTaken = true
                        break
                    end
                end
            end

            if spot and not isSpotTaken then
                local model = GetHashKey(vehicle.vehicle)
                RequestModel(model)
                while not HasModelLoaded(model) do
                    Wait(0)
                end

                local vehEntity = CreateVehicle(model, spot.x, spot.y, spot.z, false, false)
                SetEntityHeading(vehEntity, spot.w)
                
                ParkedVehicles[parkId][vehicle.plate] = {
                    car = vehEntity,
                    plate = vehicle.plate,
                    owner = vehicle.citizenid,
                    model = vehicle.vehicle,
                    mods = json.encode(mods), -- Lưu lại mods đã được làm sạch
                    spotId = spotId
                }

                QBCore.Functions.SetVehicleProperties(vehEntity, mods) -- Áp dụng mods cho xe
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
            else
                print('PersonalParking: Vị trí '..tostring(spotId)..' cho xe ' .. vehicle.plate .. ' không hợp lệ hoặc đã có xe chiếm.')
            end
        else
            print('PersonalParking: Xe ' .. vehicle.plate .. ' không có vị trí được lưu. Không thể spawn.')
        end
    end
end

local function despawnParkedVehicles(parkId)
    if not parkId or not ParkedVehicles[parkId] then return end
    
    for _, vehicle in pairs(ParkedVehicles[parkId]) do
        if DoesEntityExist(vehicle.car) then
            QBCore.Functions.DeleteVehicle(vehicle.car)
        end
        if Config.UseTarget and EntityZones[vehicle.car] then
            exports['qb-target']:RemoveTargetEntity(vehicle.car)
            EntityZones[vehicle.car] = nil
        end
    end
    ParkedVehicles[parkId] = {}
end

-- ==========================================================================================
--                                 KHU VỰC VÀ ZONES
-- ==========================================================================================

local function CreateZones()
    local isNearParkingMarker = {}

    for parkId, zoneData in pairs(Config.Zones) do
        isNearParkingMarker[parkId] = false

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
                    despawnParkedVehicles(CurrentParkZone)
                    spawnParkedVehicles(CurrentParkZone, vehicles)
                end, CurrentParkZone)
            elseif CurrentParkZone == parkId then
                despawnParkedVehicles(parkId)
                CurrentParkZone = nil
            end
        end)

        local markerZone = CircleZone:Create(vec3(zoneData.ParkVehicleZone.x, zoneData.ParkVehicleZone.y, zoneData.ParkVehicleZone.z), 3.0, {
            name = 'ParkMarker'..parkId,
            debugPoly = false,
        })

        markerZone:onPlayerInOut(function(isPointInside)
            if isPointInside then
                isNearParkingMarker[parkId] = true
                CreateThread(function()
                    while isNearParkingMarker[parkId] do
                        local playerPed = PlayerPedId()
                        if IsPedInAnyVehicle(playerPed, false) then
                            exports['qb-core']:DrawText('[E] - Đậu Xe', 'left')
                            if IsControlJustReleased(0, 38) then -- Phím E
                                TriggerEvent('personalparking:client:tryParkVehicle')
                            end
                        else
                            exports['qb-core']:HideText()
                        end
                        Wait(5)
                    end
                end)
            else
                isNearParkingMarker[parkId] = false
                exports['qb-core']:HideText()
            end
        end)

        if not Config.UseTarget then
            local inSpotZone = {}
            for spotId, spotCoords in ipairs(zoneData.VehicleSpots) do
                inSpotZone[spotId] = false
                local vehicleZone = BoxZone:Create(vec3(spotCoords.x, spotCoords.y, spotCoords.z), 2.5, 4.5, {
                    name = 'VehicleSpot'..parkId..spotId,
                    heading = spotCoords.w,
                    debugPoly = false,
                    minZ = spotCoords.z - 2,
                    maxZ = spotCoords.z + 2,
                })

                vehicleZone:onPlayerInOut(function(isPointInside)
                    if isPointInside then
                        inSpotZone[spotId] = true
                        CreateThread(function()
                            while inSpotZone[spotId] do
                                local parkedCarData = nil
                                if ParkedVehicles[parkId] then
                                    for _, vehData in pairs(ParkedVehicles[parkId]) do
                                        if vehData.spotId == spotId then
                                            parkedCarData = vehData
                                            break
                                        end
                                    end
                                end

                                if parkedCarData then
                                    exports['qb-core']:DrawText('[E] - Lấy Xe', 'left')
                                    if IsControlJustReleased(0, 38) then -- Phím E
                                        local targetData = {
                                            owner = parkedCarData.owner,
                                            plate = parkedCarData.plate
                                        }
                                        TriggerEvent('personalparking:client:tryRetrieveVehicle', targetData)
                                    end
                                else
                                    exports['qb-core']:HideText()
                                end
                                Wait(5)
                            end
                        end)
                    else
                        inSpotZone[spotId] = false
                        exports['qb-core']:HideText()
                    end
                end)
            end
        end
    end
end

-- ==========================================================================================
--                                   SỰ KIỆN (EVENTS)
-- ==========================================================================================

RegisterNetEvent('personalparking:client:tryParkVehicle', function()
    if not CurrentParkZone then return end
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if not vehicle then
        QBCore.Functions.Notify('Bạn cần ở trong một phương tiện.', 'error')
        return
    end

    local spotId = getFreeSpot(CurrentParkZone)
    if not spotId then
        QBCore.Functions.Notify('Không còn chỗ trống trong bãi đậu xe này.', 'error')
        return
    end

    local plate = QBCore.Functions.GetPlate(vehicle)
    QBCore.Functions.TriggerCallback('personalparking:server:checkVehicleOwner', function(isOwner)
        if isOwner then
            local vehicleProps = QBCore.Functions.GetVehicleProperties(vehicle)
            QBCore.Functions.TriggerCallback('personalparking:server:getVehicleModel', function(modelName)
                if modelName then
                    local vehicleData = {
                        plate = plate,
                        model = modelName,
                        mods = json.encode(vehicleProps) -- Mã hóa mods thành chuỗi JSON
                    }
                    TriggerServerEvent('personalparking:server:parkVehicle', CurrentParkZone, spotId, vehicleData)
                    QBCore.Functions.DeleteVehicle(vehicle)
                end
            end, plate)
        else
            QBCore.Functions.Notify('Đây không phải là xe của bạn.', 'error')
        end
    end, plate)
end)

RegisterNetEvent('personalparking:client:tryRetrieveVehicle', function(data)
    TriggerServerEvent('personalparking:server:retrieveVehicle', CurrentParkZone, data.plate)
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

RegisterNetEvent('personalparking:client:refreshVehicles', function(parkId)
    if CurrentParkZone and CurrentParkZone == parkId then
        QBCore.Functions.TriggerCallback('personalparking:server:getParkedVehicles', function(vehicles)
            despawnParkedVehicles(CurrentParkZone)
            spawnParkedVehicles(CurrentParkZone, vehicles)
        end, CurrentParkZone)
    end
end)

-- ==========================================================================================
--                                   THREADS & RESOURCE
-- ==========================================================================================

--CreateThread(function()
--    for parkId, zoneData in pairs(Config.Zones) do
--        local blip = AddBlipForCoord(zoneData.ParkVehicleZone.x, zoneData.ParkVehicleZone.y, zoneData.ParkVehicleZone.z)
--        SetBlipSprite(blip, 357)
--        SetBlipDisplay(blip, 4)
--        SetBlipScale(blip, 0.7)
--        SetBlipAsShortRange(blip, true)
--        SetBlipColour(blip, 2)
--        BeginTextCommandSetBlipName('STRING')
--        AddTextComponentSubstringPlayerName('Bãi Đậu Xe Cá Nhân')
 --       EndTextCommandSetBlipName(blip)
--    end
--end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        CreateZones()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if CurrentParkZone then
            despawnParkedVehicles(CurrentParkZone)
        end
    end
end)