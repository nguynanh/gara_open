local QBCore = exports['qb-core']:GetCoreObject()

-- Lấy danh sách các xe đang đỗ để client hiển thị
QBCore.Functions.CreateCallback('parkinglot:server:getVehicles', function(source, cb, lotName)
    local vehicles = MySQL.query.await('SELECT * FROM display_vehicles WHERE parking_lot = ?', { lotName })
    cb(vehicles)
end)

-- Sự kiện khi người chơi gửi xe
RegisterNetEvent('parkinglot:server:parkVehicle', function(vehicleData, lotName, spotIndex)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local fee = Config.ParkingLots[lotName].ParkingFee

    if not Player or not fee then return end

    if Player.Functions.RemoveMoney('bank', fee, 'parking-fee') then
        MySQL.query('DELETE FROM player_vehicles WHERE plate = ? AND citizenid = ?', { vehicleData.plate, Player.PlayerData.citizenid })

        -- Thêm xe vào bãi đỗ trưng bày, cột `parked_at` sẽ tự động lưu thời gian hiện tại
        MySQL.insert('INSERT INTO display_vehicles (owner, plate, model, mods, parking_lot) VALUES (?, ?, ?, ?, ?)', {
            Player.PlayerData.citizenid,
            vehicleData.plate,
            vehicleData.model,
            json.encode(vehicleData.mods),
            lotName
        })

        TriggerClientEvent('QBCore:Notify', src, 'Bạn đã trả $'..fee..' và gửi xe thành công!', 'success')
        TriggerClientEvent('parkinglot:client:refreshVehicles', -1, lotName)
    else
        TriggerClientEvent('QBCore:Notify', src, 'Bạn không đủ tiền trong tài khoản ngân hàng để trả phí gửi xe!', 'error')
    end
end)

-- Sự kiện khi người chơi lấy xe
RegisterNetEvent('parkinglot:server:retrieveVehicle', function(vehicleData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if Player.PlayerData.citizenid ~= vehicleData.owner then
        TriggerClientEvent('QBCore:Notify', src, 'Đây không phải xe của bạn.', 'error')
        return
    end

    MySQL.query('DELETE FROM display_vehicles WHERE plate = ?', { vehicleData.plate })

    MySQL.insert('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, state) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        Player.PlayerData.license,
        Player.PlayerData.citizenid,
        vehicleData.model,
        GetHashKey(vehicleData.model),
        vehicleData.mods,
        vehicleData.plate,
        0
    })

    TriggerClientEvent('QBCore:Notify', src, 'Bạn đã lấy xe thành công!', 'success')
    TriggerClientEvent('parkinglot:client:refreshVehicles', -1, vehicleData.lotName)
    TriggerClientEvent('parkinglot:client:spawnRetrievedVehicle', src, vehicleData)
end)

-- VÒNG LẶP TỰ ĐỘNG (CRON JOB) ĐỂ TRỪ PHÍ HÀNG NGÀY
CreateThread(function()
    while true do
        -- Đặt thời gian chờ. Ví dụ: 1 giờ (3600000 ms). Script sẽ kiểm tra mỗi giờ.
        Wait(3600000)

        local parkedVehicles = MySQL.query.await('SELECT id, owner, parking_lot, parked_at FROM display_vehicles', {})
        if not parkedVehicles then goto continue end

        for _, vehicle in ipairs(parkedVehicles) do
            local lotName = vehicle.parking_lot
            local dailyFee = Config.ParkingLots[lotName] and Config.ParkingLots[lotName].DailyFee or 0

            if dailyFee > 0 then
                local parkedTime = os.time(vehicle.parked_at)
                local currentTime = os.time()
                local hoursPassed = (currentTime - parkedTime) / 3600

                -- Tính toán số lần 24 giờ đã trôi qua
                local chargeCycles = math.floor(hoursPassed / 24)

                if chargeCycles > 0 then
                    local ownerCitizenId = vehicle.owner
                    local totalFeeToCharge = chargeCycles * dailyFee

                    -- Lấy thông tin người chơi (ngay cả khi offline)
                    local ownerData = MySQL.query.await('SELECT money FROM players WHERE citizenid = ?', { ownerCitizenId })
                    if ownerData and ownerData[1] then
                        local ownerMoney = json.decode(ownerData[1].money)

                        if ownerMoney.bank >= totalFeeToCharge then
                            -- Trừ tiền của người chơi offline
                            ownerMoney.bank = ownerMoney.bank - totalFeeToCharge
                            MySQL.update('UPDATE players SET money = ? WHERE citizenid = ?', { json.encode(ownerMoney), ownerCitizenId })

                            -- Cập nhật lại thời gian đã tính phí để không bị trừ lặp lại
                            -- Ta sẽ cộng thêm số ngày đã tính phí vào thời gian đỗ xe ban đầu
                            local newParkedTimestamp = parkedTime + (chargeCycles * 24 * 3600)
                            MySQL.update('UPDATE display_vehicles SET parked_at = FROM_UNIXTIME(?) WHERE id = ?', { newParkedTimestamp, vehicle.id })

                            -- (Tùy chọn) Gửi email thông báo cho người chơi
                            exports['qb-phone']:sendNewMailToOffline(ownerCitizenId, {
                                sender = "Bãi đỗ xe",
                                subject = "Thông báo phí gửi xe",
                                message = "Chúng tôi đã trừ $" .. totalFeeToCharge .. " từ tài khoản của bạn cho phí duy trì xe tại bãi đỗ."
                            })
                        end
                    end
                end
            end
        end
        ::continue::
    end
end)