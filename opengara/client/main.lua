local QBCore = exports['qb-core']:GetCoreObject()
local CurrentParkZone = nil
local ActiveZones = {}
local EntityZones = {}
local ParkedVehicles = {}
local CreatedPolyZones = {}

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

local function getFreeSpot(parkId)
    local spots = Config.Zones[parkId].VehicleSpots
    local parkedSpots = {}
    local availableSpotIndices = {}
    
    if ParkedVehicles[parkId] then
        for _, vehicle in pairs(ParkedVehicles[parkId]) do
            parkedSpots[vehicle.spotId] = true
        end
    end

    for i = 1, #spots do
        if not parkedSpots[i] then
            table.insert(availableSpotIndices, i)
        end
    end

    if #availableSpotIndices > 0 then
        local randomIndex = math.random(1, #availableSpotIndices)
        return availableSpotIndices[randomIndex]
    end

    return nil
end

-- Main Zone Functions
local function CreateZones()
    local isNearParkingMarker = {}

    for parkId, zoneData in pairs(Config.Zones) do
        local pZone = PolyZone:Create(zoneData.PolyZone, {
            name = parkId,
            minZ = zoneData.MinZ,
            maxZ = zoneData.MaxZ,
            debugPoly = false
        })
        CreatedPolyZones[parkId] = pZone
        
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
                            exports['qb-core']:DrawText(Lang:t('info.park_prompt'), 'left')
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
                                    exports['qb-core']:DrawText(Lang:t('info.retrieve_prompt'), 'left')
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
    if not CurrentParkZone then
        QBCore.Functions.Notify(Lang:t('error.cannot_park_no_zone'), 'error')
        return
    end
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if not vehicle then
        QBCore.Functions.Notify(Lang:t('error.not_in_vehicle'), 'error')
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
                        
                        if DoesEntityExist(vehicle) then
                            QBCore.Functions.DeleteVehicle(vehicle)
                        end
                        TaskLeaveVehicle(ped, vehicle, 16)
                    end
                end, plate)
            else
                QBCore.Functions.Notify(Lang:t('error.no_free_spots'), 'error')
            end
        else
            QBCore.Functions.Notify(Lang:t('error.not_your_vehicle'), 'error')
        end
    end, plate)
end)

RegisterNetEvent('personalparking:client:tryRetrieveVehicle', function(data)
    local pData = QBCore.Functions.GetPlayerData()
    if not CurrentParkZone then
        QBCore.Functions.Notify(Lang:t('error.cannot_retrieve_no_zone'), 'error')
        return
    end

    if pData.citizenid == data.owner then
        TriggerServerEvent('personalparking:server:retrieveVehicle', CurrentParkZone, data.plate)
    else
        QBCore.Functions.Notify(Lang:t('error.not_your_vehicle'), 'error')
    end
end)

RegisterNetEvent('personalparking:client:spawnRetrievedVehicle', function(vehData)
    local spawnPoint = Config.Zones[CurrentParkZone].RetrieveVehicleSpawn

    local model = vehData.model or vehData.vehicle
    if not vehData or not model or model == "" then
        QBCore.Functions.Notify("Không thể xác định dữ liệu xe để spawn.", "error")
        print("[ERROR] vehData nil hoặc thiếu model hoặc vehicle:", json.encode(vehData))
        return
    end

    QBCore.Functions.TriggerCallback('QBCore:Server:SpawnVehicle', function(netId)
        if not netId then
            QBCore.Functions.Notify("Không thể spawn xe.", "error")
            return
        end

        local veh = NetToVeh(netId)
        if not veh or veh == 0 then
            QBCore.Functions.Notify("Xe không xuất hiện.", "error")
            return
        end

        SetVehicleNumberPlateText(veh, vehData.plate or "NOPLATE")
        SetEntityHeading(veh, spawnPoint.w)
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
        SetVehicleFuelLevel(veh, 100.0)
        SetVehicleEngineOn(veh, true, true)

        if vehData.mods then
            local ok, mods = pcall(function()
                return type(vehData.mods) == "string" and json.decode(vehData.mods) or vehData.mods
            end)
            if ok and mods then
                QBCore.Functions.SetVehicleProperties(veh, mods)
            else
                QBCore.Functions.Notify("Lỗi khi áp dụng tuỳ chỉnh xe.", "error")
            end
        end

        TriggerEvent('vehiclekeys:client:SetOwner', GetVehicleNumberPlateText(veh))
    end, model, spawnPoint, true)
end)


RegisterNetEvent('personalparking:client:vehicleParkedSuccess', function(parkId, spotId, vehicleData, citizenid)
    vehicleData.spot_id = spotId
    local spots = Config.Zones[parkId].VehicleSpots
    local spot = spots[spotId]
    if spot then
        local model = GetHashKey(vehicleData.model)
        RequestModel(model)
        while not HasModelLoaded(model) do
            Wait(0)
        end

        local vehEntity = CreateVehicle(model, spot.x, spot.y, spot.z, false, false)
        SetEntityHeading(vehEntity, spot.w)
        
        if not ParkedVehicles[parkId] then ParkedVehicles[parkId] = {} end
        ParkedVehicles[parkId][vehicleData.plate] = {
            car = vehEntity,
            plate = vehicleData.plate,
            owner = citizenid,
            model = vehicleData.model,
            mods = vehicleData.mods,
            spotId = spotId
        }

        QBCore.Functions.SetVehicleProperties(vehEntity, vehicleData.mods)
        SetModelAsNoLongerNeeded(model)
        SetEntityInvincible(vehEntity, true)
        SetVehicleDoorsLocked(vehEntity, 3)
        FreezeEntityPosition(vehEntity, true)
        SetVehicleOnGroundProperly(vehEntity)

        if Config.UseTarget then
            EntityZones[vehEntity] = exports['qb-target']:AddTargetEntity(vehEntity, {
                options = {
                    {
                        type = 'client',
                        event = 'personalparking:client:tryRetrieveVehicle',
                        icon = 'fas fa-car-side',
                        label = 'Lấy Xe',
                        owner = citizenid,
                        plate = vehicleData.plate,
                    }
                },
                distance = 2.5
            })
        end
    end
end)


RegisterNetEvent('personalparking:client:refreshVehicles', function(parkId)
    if CurrentParkZone and CurrentParkZone == parkId then
        QBCore.Functions.TriggerCallback('personalparking:server:getParkedVehicles', function(vehicles)
            despawnParkedVehicles(CurrentParkZone)
            spawnParkedVehicles(CurrentParkZone, vehicles)
        end, CurrentParkZone)
    end
end)

-- Marker Parameters (có thể điều chỉnh)
local MarkerType = 1        -- Loại marker (1 là hình giọt nước ngược)
local MarkerScale = 1.0     -- Kích thước marker
local MarkerColorR = 255    -- Màu đỏ
local MarkerColorG = 0      -- Màu xanh lá
local MarkerColorB = 0      -- Màu xanh dương
local MarkerColorA = 150    -- Độ trong suốt (0-255)

-- Luồng mới để vẽ marker
CreateThread(function()
    while true do
        Wait(0) -- Vẽ liên tục để marker hiển thị
        local playerCoords = GetEntityCoords(PlayerPedId())
        for parkId, zoneData in pairs(Config.Zones) do
            local markerCoords = zoneData.ParkVehicleZone
            local dist = #(playerCoords - vec3(markerCoords.x, markerCoords.y, markerCoords.z))

            if dist < 50.0 then -- Chỉ vẽ nếu người chơi ở đủ gần để tiết kiệm tài nguyên
                DrawMarker(
                    MarkerType,
                    markerCoords.x,
                    markerCoords.y,
                    markerCoords.z - 0.9, -- Điều chỉnh trục Z nếu marker bị chìm hoặc lơ lửng
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    MarkerScale, MarkerScale, MarkerScale,
                    MarkerColorR, MarkerColorG, MarkerColorB, MarkerColorA,
                    false, -- bobUpAndDown (nhấp nhô)
                    true,  -- faceCamera (luôn quay về phía camera)
                    2,     -- P19 (thông số bổ sung, thường là 2 hoặc false)
                    true,  -- rotate (xoay)
                    nil,   -- textureDict
                    nil,   -- textureName
                    false  -- drawOnEnts
                )
            end
        end
    end
end)


AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        -- CreateZones() được gọi trực tiếp ở cuối file để đảm bảo nó chạy sớm nhất
    end
end)

-- Kích hoạt logic sinh xe khi người chơi đã tải hoàn chỉnh
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    CreateThread(function()
        Wait(1000) -- Đợi 1 giây để đảm bảo mọi thứ đã khởi tạo
        local playerCoords = GetEntityCoords(PlayerPedId())
        
        local foundZone = false
        for parkId, zoneData in pairs(Config.Zones) do
            local pZone = CreatedPolyZones[parkId]
            if pZone then
                if pZone:isPointInside(playerCoords) then
                    foundZone = true
                    CurrentParkZone = parkId
                    QBCore.Functions.TriggerCallback('personalparking:server:getParkedVehicles', function(vehicles)
                        if vehicles then
                            despawnParkedVehicles(CurrentParkZone)
                            spawnParkedVehicles(CurrentParkZone, vehicles)
                        end
                    end, CurrentParkZone)
                    break
                end
            end
        end
    end)
end)


AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if CurrentParkZone then
            despawnParkedVehicles(CurrentParkZone)
        end
    end
end)

-- GỌI HÀM CREATEZONES TRỰC TIẾP Ở CUỐI FILE ĐỂ ĐẢM BẢO NÓ CHẠY SỚM NHẤT
CreateZones()