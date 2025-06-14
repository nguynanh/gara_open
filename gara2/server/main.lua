local QBCore = exports['qb-core']:GetCoreObject()

-- Callbacks
QBCore.Functions.CreateCallback('personalparking:server:getParkedVehicles', function(source, cb, parkId)
    local result = MySQL.query.await('SELECT * FROM player_parked_vehicles WHERE park_id = ?', { parkId })
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
    local parkFee = 1000 -- <<<< BẠN CÓ THỂ THAY ĐỔI PHÍ GỬI XE TẠI ĐÂY

    if not Player then return end

    -- Kiểm tra xem người chơi có đủ tiền không (kiểm tra trong tài khoản ngân hàng)
    if Player.Functions.GetMoney('bank') >= parkFee then
        -- Trừ tiền phí đậu xe
        Player.Functions.RemoveMoney('bank', parkFee, 'parking-fee')

        -- Xóa xe khỏi bảng player_vehicles
        local deleted = MySQL.update.await('DELETE FROM player_vehicles WHERE plate = ? AND citizenid = ?', { vehicleData.plate, Player.PlayerData.citizenid })

        if deleted > 0 then
            -- Thêm xe vào bảng player_parked_vehicles
            MySQL.insert('INSERT INTO player_parked_vehicles (citizenid, plate, model, mods, park_id, spot_id) VALUES (?, ?, ?, ?, ?, ?)', {
                Player.PlayerData.citizenid,
                vehicleData.plate,
                vehicleData.model,
                json.encode(vehicleData.mods),
                parkId,
                spotId
            })
            TriggerClientEvent('QBCore:Notify', src, 'Bạn đã đậu xe với phí là $'..parkFee, 'success')
            TriggerEvent('qb-log:server:CreateLog', 'personalparking', 'Vehicle Parked', 'green', '**'..Player.PlayerData.name..'** đã đậu xe **'..vehicleData.model..'** (`'..vehicleData.plate..'`) tại **'..parkId..'** với phí $'..parkFee..'.')
            TriggerClientEvent('personalparking:client:refreshVehicles', -1, parkId)
        else
            -- Nếu việc xóa xe khỏi player_vehicles thất bại, hoàn lại tiền cho người chơi
            Player.Functions.AddMoney('bank', parkFee, 'parking-fee-refund')
            TriggerClientEvent('QBCore:Notify', src, 'Không thể đậu xe, đã hoàn lại phí.', 'error')
        end
    else
        -- Thông báo nếu không đủ tiền
        TriggerClientEvent('QBCore:Notify', src, 'Bạn không có đủ tiền để trả phí đậu xe ($'..parkFee..').', 'error')
    end
end)

RegisterNetEvent('personalparking:server:retrieveVehicle', function(parkId, vehiclePlate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then return end

    local parkedVehicle = MySQL.query.await('SELECT * FROM player_parked_vehicles WHERE plate = ? AND citizenid = ? AND park_id = ?', { vehiclePlate, Player.PlayerData.citizenid, parkId })

    if parkedVehicle and parkedVehicle[1] then
        local veh = parkedVehicle[1]
        
        -- Add back to player_vehicles
        MySQL.insert('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, state, garage) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
            Player.PlayerData.license,
            Player.PlayerData.citizenid,
            veh.model,
            joaat(veh.model),
            veh.mods,
            veh.plate,
            0,
            'none' -- Or your default garage
        })

        -- Remove from player_parked_vehicles
        MySQL.update.await('DELETE FROM player_parked_vehicles WHERE id = ?', { veh.id })

        TriggerClientEvent('personalparking:client:spawnRetrievedVehicle', src, veh)
        TriggerClientEvent('QBCore:Notify', src, 'Bạn đã lấy xe của mình.', 'success')
        TriggerEvent('qb-log:server:CreateLog', 'personalparking', 'Vehicle Retrieved', 'blue', '**'..Player.PlayerData.name..'** đã lấy xe **'..veh.model..'** (`'..veh.plate..'`) từ **'..parkId..'**.')
        TriggerClientEvent('personalparking:client:refreshVehicles', -1, parkId)
    else
        TriggerClientEvent('QBCore:Notify', src, 'Đây không phải xe của bạn hoặc nó không được đậu ở đây.', 'error')
    end
end)