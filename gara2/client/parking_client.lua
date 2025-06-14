-- Nội dung cho parking_client.lua

local QBCore = exports['qb-core']:GetCoreObject()
local parkedVehicles = {}
local currentLot = nil

-- Hàm hiển thị xe (tương tự qb-vehiclesales)
local function spawnParkedVehicles(vehicles, lotName)
    if not vehicles then return end
    local spots = Config.ParkingLots[lotName].Spots
    parkedVehicles[lotName] = {}

    for i=1, #vehicles do
        local vehicle = vehicles[i]
        local spot = spots[i] -- Logic đơn giản: đỗ theo thứ tự
        if spot then
            local modelHash = GetHashKey(vehicle.model)
            RequestModel(modelHash)
            while not HasModelLoaded(modelHash) do Wait(5) end
            local vehEntity = CreateVehicle(modelHash, spot.x, spot.y, spot.z, spot.w, false, false)
            QBCore.Functions.SetVehicleProperties(vehEntity, json.decode(vehicle.mods))
            FreezeEntityPosition(vehEntity, true)
            SetEntityInvincible(vehEntity, true)
            
            parkedVehicles[lotName][i] = {
                entity = vehEntity,
                plate = vehicle.plate,
                owner = vehicle.owner,
                model = vehicle.model,
                mods = vehicle.mods,
                lotName = lotName
            }
        end
    end
end

-- Hàm dọn dẹp xe
local function despawnParkedVehicles(lotName)
    if parkedVehicles[lotName] then
        for _, vehData in pairs(parkedVehicles[lotName]) do
            if DoesEntityExist(vehData.entity) then
                QBCore.Functions.DeleteVehicle(vehData.entity)
            end
        end
        parkedVehicles[lotName] = {}
    end
end

-- Vòng lặp chính để tạo zone, blip và tương tác
CreateThread(function()
    for lotName, lotData in pairs(Config.ParkingLots) do
        -- Tạo Blip
        local blip = AddBlipForCoord(lotData.Blip.Coords)
        SetBlipSprite(blip, lotData.Blip.Sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, lotData.Blip.Scale)
        SetBlipColour(blip, lotData.Blip.Color)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(lotData.Name)
        EndTextCommandSetBlipName(blip)

        -- Tạo Zone lớn bao quanh bãi đỗ xe
        local lotZone = PolyZone:Create(lotData.Area.PolyZone, {
            name = "parking_lot_zone_"..lotName,
            minZ = lotData.Area.MinZ,
            maxZ = lotData.Area.MaxZ,
            debugPoly = false -- Đặt thành true để xem hình dạng của zone
        })

        lotZone:onPlayerInOut(function(isInside)
            if isInside then
                currentLot = lotName
                QBCore.Functions.TriggerCallback('parkinglot:server:getVehicles', function(vehicles)
                    spawnParkedVehicles(vehicles, lotName)
                end, lotName)
            else
                despawnParkedVehicles(lotName)
                currentLot = nil
                exports['qb-core']:HideText()
            end
        end)

        -- Tạo Zone tương tác cho từng vị trí đỗ
        for i, spot in ipairs(lotData.Spots) do
            local spotZone = BoxZone:Create(spot.xyz, 2.5, 5.0, {
                name = "parking_spot_"..lotName..i,
                minZ = spot.z - 1,
                maxZ = spot.z + 2
            })
            spotZone:onPlayerInOut(function(isInside)
                if isInside and currentLot == lotName then
                    local pCoords = GetEntityCoords(PlayerPedId())
                    local vehicle = QBCore.Functions.GetClosestVehicle(pCoords)
                    local dist = #(pCoords - GetEntityCoords(vehicle))
                    local isOccupied = false

                    if parkedVehicles[lotName] then
                       for _, vehData in pairs(parkedVehicles[lotName]) do
                            if #(GetEntityCoords(vehData.entity) - spot.xyz) < 2.0 then
                                isOccupied = true
                                -- Nếu là chủ xe, cho phép lấy xe
                                if vehData.owner == QBCore.Functions.GetPlayerData().citizenid then
                                    exports['qb-core']:DrawText('[E] - Lấy xe', 'left')
                                    if IsControlJustReleased(0, 38) then
                                        TriggerServerEvent('parkinglot:server:retrieveVehicle', vehData.plate)
                                    end
                                end
                                break
                           end
                       end
                    end
                    
                    -- Nếu chỗ trống và người chơi đang trong xe, cho phép gửi xe
                    if not isOccupied and IsPedInAnyVehicle(PlayerPedId(), false) then
                        exports['qb-core']:DrawText('[E] - Gửi xe trưng bày', 'left')
                        if IsControlJustReleased(0, 38) then
                            local playerVeh = GetVehiclePedIsIn(PlayerPedId(), false)
                            local vehicleProps = QBCore.Functions.GetVehicleProperties(playerVeh)
                            TriggerServerEvent('parkinglot:server:parkVehicle', vehicleProps, lotName, i)
                            DeleteEntity(playerVeh)
                        end
                    end
                else
                    exports['qb-core']:HideText()
                end
            end)
        end
    end
end)

-- Sự kiện refresh
RegisterNetEvent('parkinglot:client:refreshVehicles', function(lotName)
    if currentLot == lotName then
        despawnParkedVehicles(lotName)
        QBCore.Functions.TriggerCallback('parkinglot:server:getVehicles', function(vehicles)
            spawnParkedVehicles(vehicles, lotName)
        end, lotName)
    end
end)

-- Sự kiện spawn xe sau khi lấy
RegisterNetEvent('parkinglot:client:spawnRetrievedVehicle', function(vehicleData)
    QBCore.Functions.TriggerCallback('QBCore:Server:SpawnVehicle', function(netId)
        local veh = NetToVeh(netId)
        QBCore.Functions.SetVehicleProperties(veh, json.decode(vehicleData.mods))
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
        TriggerEvent('vehiclekeys:client:SetOwner', GetVehicleNumberPlateText(veh))
    end, vehicleData.model, Config.ParkingLots[vehicleData.lotName].Blip.Coords, true)
end)