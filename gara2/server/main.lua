local QBCore = exports['qb-core']:GetCoreObject()

-- Callbacks
QBCore.Functions.CreateCallback('personalparking:server:getParkedVehicles', function(source, cb, parkId)
    -- Thay đổi: Truy vấn từ player_vehicles thay vì player_parked_vehicles
    local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE garage = ? AND state = 1', { parkId })
    cb(result or {})
end)

QBCore.Functions.CreateCallback('personalparking:server:checkVehicleOwner', function(source, cb, plate)
    local pData = QBCore.Functions.GetPlayer(source)
    local result = MySQL.scalar.await('SELECT plate FROM player_vehicles WHERE plate = ? AND citizenid = ?', { plate, pData.PlayerData.citizenid })
    cb(result ~= nil)
end)

QBCore.Functions.CreateCallback('personalparking:server:getVehicleModel', function(source, cb, plate)
    local result = MySQL.scalar.await('SELECT vehicle FROM player_vehicles WHERE plate = ?', { plate })
    cb(result)
end)


-- Events
RegisterNetEvent('personalparking:server:parkVehicle', function(parkId, spotId, vehicleData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local parkFee = Config.ParkFee

    if not Player then return end

    if Player.Functions.GetMoney('bank') >= parkFee then
        Player.Functions.RemoveMoney('bank', parkFee, 'parking-fee')

        -- Thay đổi: Cập nhật player_vehicles thay vì xóa và chèn vào bảng khác
        local updated = MySQL.update.await('UPDATE player_vehicles SET garage = ?, state = 1, depotprice = 0 WHERE plate = ? AND citizenid = ?', {
            parkId,
            vehicleData.plate,
            Player.PlayerData.citizenid
        })

        if updated > 0 then
            -- Logic để lưu vị trí đỗ xe. Chúng ta có thể lưu nó trong cột `mods` hoặc một cột mới nếu bạn tùy chỉnh bảng player_vehicles.
            -- Ở đây, chúng ta sẽ thêm nó vào vehicleData trước khi lưu.
            -- LƯU Ý: Điều này yêu cầu bạn đảm bảo rằng khi lấy xe ra, bạn phải xóa thông tin này khỏi `mods`.
            -- Để đơn giản hóa, chúng ta sẽ không lưu vị trí cụ thể trong ví dụ này, xe sẽ xuất hiện ngẫu nhiên khi vào khu vực.
            -- Nếu muốn lưu vị trí, bạn cần một logic phức tạp hơn để quản lý `mods`.

            TriggerClientEvent('QBCore:Notify', src, 'Bạn đã đậu xe với phí là $'..parkFee, 'success')
            TriggerEvent('qb-log:server:CreateLog', 'personalparking', 'Vehicle Parked', 'green', '**'..Player.PlayerData.name..'** đã đậu xe **'..vehicleData.model..'** (`'..vehicleData.plate..'`) tại **'..parkId..'** với phí $'..parkFee..'.')
            TriggerClientEvent('personalparking:client:refreshVehicles', -1, parkId)
        else
            Player.Functions.AddMoney('bank', parkFee, 'parking-fee-refund')
            TriggerClientEvent('QBCore:Notify', src, 'Không thể đậu xe, đã hoàn lại phí.', 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'Bạn không có đủ tiền để trả phí đậu xe ($'..parkFee..').', 'error')
    end
end)

RegisterNetEvent('personalparking:server:retrieveVehicle', function(parkId, vehiclePlate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then return end

    -- Thay đổi: Truy vấn từ player_vehicles
    local parkedVehicle = MySQL.query.await('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ? AND garage = ?', { vehiclePlate, Player.PlayerData.citizenid, parkId })

    if parkedVehicle and parkedVehicle[1] then
        local veh = parkedVehicle[1]
        
        -- Thay đổi: Cập nhật trạng thái xe thay vì chèn mới
        MySQL.update.await('UPDATE player_vehicles SET state = 0, garage = "none" WHERE plate = ?', { veh.plate })

        -- Tạo dữ liệu xe để gửi về client
        local vehicleData = {
            plate = veh.plate,
            model = veh.vehicle,
            mods = veh.mods
        }

        TriggerClientEvent('personalparking:client:spawnRetrievedVehicle', src, vehicleData)
        TriggerClientEvent('QBCore:Notify', src, 'Bạn đã lấy xe của mình.', 'success')
        TriggerEvent('qb-log:server:CreateLog', 'personalparking', 'Vehicle Retrieved', 'blue', '**'..Player.PlayerData.name..'** đã lấy xe **'..veh.vehicle..'** (`'..veh.plate..'`) từ **'..parkId..'**.')
        TriggerClientEvent('personalparking:client:refreshVehicles', -1, parkId)
    else
        TriggerClientEvent('QBCore:Notify', src, 'Đây không phải xe của bạn hoặc nó không được đậu ở đây.', 'error')
    end
end)