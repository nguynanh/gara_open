local QBCore = exports['qb-core']:GetCoreObject()
local CurrentParkZone = nil
local ActiveZones = {}
local EntityZones = {}
local ParkedVehicles = {}

-- Functions
local function spawnParkedVehicles(parkId, vehicles)
    if not vehicles then return end
    local spots = Config.Zones[parkId].VehicleSpots
    if not ParkedVehicles[parkId] then ParkedVehicles[parkId] = {} end

    for _, vehicle in ipairs(vehicles) do
        local spot = spots[vehicle.spot_id]
        if spot then
            local model = GetHashKey(vehicle.model)
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
-- *** HÀM ĐÃ ĐƯỢC THAY ĐỔI ĐỂ TÌM VỊ TRÍ NGẪU NHIÊN ***
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
    -- Thu thập tất cả các vị trí còn trống
    for i = 1, #spots do
        if not parkedSpots[i] then
            table.insert(freeSpots, i)
        end
    end

    -- Nếu có vị trí trống, chọn một vị trí ngẫu nhiên từ danh sách
    if #freeSpots > 0 then
        local randomIndex = math.random(#freeSpots)
        return freeSpots[randomIndex]
    end

    -- Nếu không còn chỗ trống, trả về nil
    return nil
end
-- ==========================================================================================
-- *** KẾT THÚC PHẦN THAY ĐỔI ***
-- ==========================================================================================

-- Main Zone Functions
local function CreateZones()
    local isNearParkingMarker = {}

    for parkId, zoneData in pairs(Config.Zones) do
        isNearParkingMarker[parkId] = false

        -- Polyzone lớn để quản lý việc hiển thị/biến mất của các xe
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

        -- CircleZone nhỏ tại điểm để bắt đầu quá trình đậu xe
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

        -- *** PHẦN ĐƯỢC THÊM VÀO ĐỂ SỬA LỖI ***
        -- Tạo các BoxZone cho từng vị trí xe để tương tác nếu không dùng qb-target
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
                                -- Tìm xe đang đỗ ở vị trí này
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
                                        -- Tạo dữ liệu giống như qb-target sẽ gửi
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

-- Events
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
            local freeSpot = getFreeSpot(CurrentParkZone)
            if freeSpot then
                local vehicleProps = QBCore.Functions.GetVehicleProperties(vehicle)
                QBCore.Functions.TriggerCallback('personalparking:server:getVehicleModel', function(modelName)
                    if modelName then
                        local vehicleData = {
                            plate = plate,
                            model = modelName,
                            mods = vehicleProps
                        }
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

-- Threads and resource management
CreateThread(function()
    for parkId, zoneData in pairs(Config.Zones) do
        local blip = AddBlipForCoord(zoneData.ParkVehicleZone.x, zoneData.ParkVehicleZone.y, zoneData.ParkVehicleZone.z)
        SetBlipSprite(blip, 357) -- Parking blip sprite
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
            despawnParkedVehicles(CurrentParkZone)
        end
    end
end)