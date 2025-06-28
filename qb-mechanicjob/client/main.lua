-- =================================================================
-- NỘI DUNG HOÀN CHỈNH CHO: qb-mechanicjob/client/main.lua
-- Đã thêm lại Blip cho điểm Preview
-- =================================================================

local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local currentShopBlips = {}
local inMechanicLocation = false

-- Handlers
AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
end)

RegisterNetEvent('qb-mechanicjob:client:SetInsideLocation', function(inside)
    inMechanicLocation = inside
end)

-- Local Functions
local function SpawnListVehicle(model, spawnPoint)
    QBCore.Functions.TriggerCallback('QBCore:Server:SpawnVehicle', function(netId)
        local veh = NetToVeh(netId)
        SetVehicleNumberPlateText(veh, 'MECH' .. tostring(math.random(1000, 9999)))
        SetEntityHeading(veh, spawnPoint.w)
        if exports[Config.FuelResource] then
            exports[Config.FuelResource]:SetFuel(veh, 100.0)
        end
        TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(veh))
        SetVehicleEngineOn(veh, true, true, false)
    end, model, spawnPoint, true)
end

local function VehicleList(shop)
    local vehicleMenu = { { header = Lang:t('menu.vehicle_list'), isMenuHeader = true } }

    if not Config.Shops[shop] or not Config.Shops[shop].vehicles or not Config.Shops[shop].vehicles.list then
        print('^1[ERROR] Khong tim thay danh sach xe cho garage: ' .. shop .. ' trong config.lua^7')
        QBCore.Functions.Notify("Garage này chưa được cấu hình danh sách xe!", "error")
        return
    end

    local list = Config.Shops[shop].vehicles.list
    for i = 1, #list do
        local vehicleData = QBCore.Shared.Vehicles[list[i]]
        local vehicleName = (vehicleData and vehicleData.name) or list[i]
        vehicleMenu[#vehicleMenu + 1] = {
            header = vehicleName,
            params = {
                event = 'qb-mechanicjob:client:SpawnListVehicle',
                args = {
                    spawnName = list[i],
                    location = Config.Shops[shop].vehicles.spawn
                }
            }
        }
    end

    vehicleMenu[#vehicleMenu + 1] = {
        header = Lang:t('menu.close'),
        params = { event = 'qb-menu:client:closeMenu' }
    }
    exports['qb-menu']:openMenu(vehicleMenu)
end

-- Events
RegisterNetEvent('qb-mechanicjob:client:SpawnListVehicle', function(data)
    SpawnListVehicle(data.spawnName, data.location)
end)

-- Main Thread - Thiết lập các điểm tương tác và Blip (chỉ chạy một lần)
CreateThread(function()
    -- 1. TẠO TARGET VÀ BLIP CHO CÁC CỬA HÀNG (Benny's, etc.)
    if Config.Shops and type(Config.Shops) == 'table' then
        for k, v in pairs(Config.Shops) do
            if v and type(v) == 'table' then
               if v.polyzone then
                   local shopZone = PolyZone:Create(v.polyzone, { name = k, debugPoly = Config.Debug })
                   shopZone:onPlayerInOut(function(isPointInside)
                      TriggerEvent("qb-mechanicjob:client:SetInsideLocation", isPointInside)
                   end)
              end
                if v.showBlip and v.blipCoords and not currentShopBlips[k] then
                    local blip = AddBlipForCoord(v.blipCoords.x, v.blipCoords.y, v.blipCoords.z)
                    SetBlipSprite(blip, v.blipSprite); SetBlipDisplay(blip, 4); SetBlipScale(blip, 0.6); SetBlipColour(blip, v.blipColor); SetBlipAsShortRange(blip, true)
                    BeginTextCommandSetBlipName('STRING'); AddTextComponentString(v.shopLabel); EndTextCommandSetBlipName(blip)
                    currentShopBlips[k] = blip
                end
                if v.duty then
                    exports['qb-target']:AddCircleZone(k .. '_duty', v.duty, 0.5, { name = k .. '_duty', useZ = true }, { options = { { event = 'QBCore:ToggleDuty', type = 'server', label = Lang:t('target.duty'), icon = 'fas fa-user-clock', job = v.managed and k or nil } }, distance = 2.0 })
                end
                if v.stash then
                    exports['qb-target']:AddCircleZone(k .. '_stash', v.stash, 0.5, { name = k .. '_stash', useZ = true }, { options = { { event = 'qb-mechanicjob:server:stash', type = 'server', data = { job = k }, label = Lang:t('target.stash'), icon = 'fas fa-box-open', job = v.managed and k or nil } }, distance = 2.0 })
                end
                if v.paint then
                    exports['qb-target']:AddCircleZone(k .. '_paintbooth', v.paint, 2.5, { name = k .. '_paintbooth', useZ = true }, { options = { { label = Lang:t('target.paint'), icon = 'fas fa-fill-drip', job = v.managed and k or nil, action = function() PaintCategories() end } }, distance = 2.5 })
                end
                if v.vehicles and v.vehicles.withdraw then
                    exports['qb-target']:AddCircleZone(k .. '_spawner', v.vehicles.withdraw, 1.5, { name = k .. '_spawner', useZ = true }, {
                        options = {
                            {
                                label = Lang:t('target.withdraw'), icon = 'fas fa-car', job = v.managed and k or nil,
                                canInteract = function() return GetVehiclePedIsUsing(PlayerPedId()) == 0 end,
                                action = function() VehicleList(k) end
                            },
                            {
                                label = Lang:t('target.deposit'), icon = 'fas fa-car', job = k,
                                canInteract = function() return GetVehiclePedIsUsing(PlayerPedId()) ~= 0 end,
                                action = function() DeleteEntity(GetVehiclePedIsUsing(PlayerPedId())) end
                            }
                        },
                        distance = 2.5
                    })
                end
            end
        end
    end

    -- 2. TẠO BLIP TRÊN BẢN ĐỒ CHO ĐIỂM XEM TRƯỚC (PREVIEW SPOT)
    if Config.PreviewSpot3 and Config.PreviewSpot3.blip and Config.PreviewSpot3.blip.enabled then
        local spotCfg = Config.PreviewSpot3
        local mapBlip = AddBlipForCoord(spotCfg.coords.x, spotCfg.coords.y, spotCfg.coords.z)
        SetBlipSprite(mapBlip, spotCfg.blip.sprite)
        SetBlipDisplay(mapBlip, spotCfg.blip.display)
        SetBlipScale(mapBlip, spotCfg.blip.scale)
        SetBlipColour(mapBlip, spotCfg.blip.color)
        SetBlipAsShortRange(mapBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(spotCfg.blip.label)
        EndTextCommandSetBlipName(mapBlip)
    end
    if Config.PreviewSpot2 and Config.PreviewSpot2.blip and Config.PreviewSpot2.blip.enabled then
        local spotCfg = Config.PreviewSpot2
        local mapBlip = AddBlipForCoord(spotCfg.coords.x, spotCfg.coords.y, spotCfg.coords.z)
        SetBlipSprite(mapBlip, spotCfg.blip.sprite)
        SetBlipDisplay(mapBlip, spotCfg.blip.display)
        SetBlipScale(mapBlip, spotCfg.blip.scale)
        SetBlipColour(mapBlip, spotCfg.blip.color)
        SetBlipAsShortRange(mapBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(spotCfg.blip.label)
        EndTextCommandSetBlipName(mapBlip)
    end
end)

-- Vòng lặp riêng để xử lý Marker và tương tác "E" cho điểm Preview
-- File: qb-mechanicjob/client/main.lua
-- Thêm đoạn mã này vào trong CreateThread ở đầu tệp, sau các logic tạo shop

-- Tự động tạo Blip và Vùng tương tác cho TẤT CẢ các điểm Preview trong Config
-- File: qb-mechanicjob/client/main.lua
-- THAY THẾ TOÀN BỘ LOGIC XỬ LÝ PREVIEW SPOT BẰNG ĐOẠN MÃ ĐÃ SỬA LỖI NÀY

-- Tự động tạo Blip và Vùng tương tác cho TẤT CẢ các điểm Preview trong Config
if Config.PreviewSpots and #Config.PreviewSpots > 0 then
    for i, spotCfg in ipairs(Config.PreviewSpots) do
        -- Chỉ xử lý các điểm được bật
        if spotCfg.enabled then
            -- 1. Tạo Blip trên bản đồ
            if spotCfg.blip and spotCfg.blip.enabled then
                local mapBlip = AddBlipForCoord(spotCfg.coords.x, spotCfg.coords.y, spotCfg.coords.z)
                SetBlipSprite(mapBlip, spotCfg.blip.sprite)
                SetBlipDisplay(mapBlip, spotCfg.blip.display)
                SetBlipScale(mapBlip, spotCfg.blip.scale)
                SetBlipColour(mapBlip, spotCfg.blip.color)
                SetBlipAsShortRange(mapBlip, true)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(spotCfg.blip.label)
                EndTextCommandSetBlipName(mapBlip)
            end

            -- 2. Tạo một Thread riêng để quản lý Marker và Tương tác cho mỗi điểm
            CreateThread(function()
                local isPromptShowing = false
                while true do
                    local sleep = 1000
                    local playerPed = PlayerPedId()
                    local playerCoords = GetEntityCoords(playerPed)

                    if #(playerCoords - spotCfg.coords) < spotCfg.marker.drawDist then
                        sleep = 5
                        
                        -- [[ SỬA LỖI TẠI ĐÂY ]]
                        -- Bây giờ, chúng ta chỉ vẽ marker và hiển thị tương tác KHI người chơi ở trong xe.
                        if IsPedInAnyVehicle(playerPed, false) then
                            -- Hiển thị Marker trên mặt đất
                            if spotCfg.marker and spotCfg.marker.enabled then
                                DrawMarker(
                                    spotCfg.marker.type,
                                    spotCfg.coords.x, spotCfg.coords.y, spotCfg.coords.z + spotCfg.marker.zOffset,
                                    0.0, 0.0, 0.0, 0.0, 180.0, 0.0,
                                    spotCfg.marker.size.x, spotCfg.marker.size.y, spotCfg.marker.size.z,
                                    spotCfg.marker.color.r, spotCfg.marker.color.g, spotCfg.marker.color.b, spotCfg.marker.color.a,
                                    false, true, 2, nil, nil, false
                                )
                            end

                            -- Xử lý tương tác [E]
                            if GetPedInVehicleSeat(GetVehiclePedIsIn(playerPed, false), -1) == playerPed then
                                if #(playerCoords - spotCfg.coords) < spotCfg.interaction.radius then
                                    if not isPromptShowing then
                                        lib.showTextUI('[E] - ' .. spotCfg.interaction.label)
                                        isPromptShowing = true
                                    end
                                    
                                    if IsControlJustReleased(0, 38) then -- Phím E
                                        TriggerEvent("qb-mechanicjob:client:Preview:Menu")
                                    end
                                else
                                    if isPromptShowing then
                                        lib.hideTextUI()
                                        isPromptShowing = false
                                    end
                                end
                            end
                        else
                            -- Nếu người chơi không ở trong xe, ẩn thông báo tương tác
                            if isPromptShowing then
                                lib.hideTextUI()
                                isPromptShowing = false
                            end
                        end
                    else
                         if isPromptShowing then
                            lib.hideTextUI()
                            isPromptShowing = false
                        end
                    end
                    Wait(sleep)
                end
            end)
        end
    end
end