-- ✅ SERVER MAIN.LUA - DÙNG VEHICLE MODEL ĐÚNG VÀ DEBUG
local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateCallback('personalparking:server:getParkedVehicles', function(source, cb, parkId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end

    local vehicles = MySQL.query.await([[SELECT * FROM player_vehicles WHERE citizenid = ? AND garage = ? AND state = 1]], {
        Player.PlayerData.citizenid, parkId
    })

    local formatted = {}
    for _, v in pairs(vehicles or {}) do
        table.insert(formatted, {
            plate = v.plate,
            model = v.vehicle or v.model or "",
            mods = v.mods,
            spot_id = v.spot_id or 1,
            citizenid = v.citizenid
        })
    end

    cb(formatted)
end)

QBCore.Functions.CreateCallback('personalparking:server:checkVehicleOwner', function(source, cb, plate)
    local Player = QBCore.Functions.GetPlayer(source)
    local result = MySQL.scalar.await('SELECT plate FROM player_vehicles WHERE plate = ? AND citizenid = ?', {
        plate, Player.PlayerData.citizenid
    })
    cb(result ~= nil)
end)

QBCore.Functions.CreateCallback('personalparking:server:getVehicleModel', function(source, cb, plate)
    local result = MySQL.scalar.await('SELECT vehicle FROM player_vehicles WHERE plate = ?', { plate })
    cb(result)
end)

RegisterNetEvent('personalparking:server:parkVehicle', function(parkId, spotId, vehicleData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local parkFee = 1000

    if not Player then return end

    if Player.Functions.GetMoney('bank') >= parkFee then
        Player.Functions.RemoveMoney('bank', parkFee, 'parking-fee')

        local updated = MySQL.update.await([[UPDATE player_vehicles SET garage = ?, state = 1, mods = ?, spot_id = ? WHERE plate = ? AND citizenid = ?]], {
            parkId, json.encode(vehicleData.mods), spotId, vehicleData.plate, Player.PlayerData.citizenid
        })

        if updated > 0 then
            vehicleData.spot_id = spotId
            TriggerClientEvent('personalparking:client:vehicleParkedSuccess', src, parkId, spotId, vehicleData, Player.PlayerData.citizenid)
            TriggerClientEvent('QBCore:Notify', src, 'Đã đậu xe với phí $'..parkFee, 'success')
        else
            Player.Functions.AddMoney('bank', parkFee, 'parking-fee-refund')
            TriggerClientEvent('QBCore:Notify', src, 'Không thể cập nhật thông tin xe.', 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'Không đủ tiền đậu xe ($'..parkFee..').', 'error')
    end
end)

RegisterNetEvent('personalparking:server:retrieveVehicle', function(parkId, plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local result = MySQL.query.await([[SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ? AND garage = ? AND state = 1]], {
        plate, Player.PlayerData.citizenid, parkId
    })

    if result and result[1] then
        local veh = result[1]
        print("[DEBUG] Retrieved vehicle from DB:", json.encode(veh))

        MySQL.update.await([[UPDATE player_vehicles SET garage = ?, state = ? WHERE plate = ? AND citizenid = ?]], {
            'none', 0, plate, Player.PlayerData.citizenid
        })

        TriggerClientEvent('personalparking:client:spawnRetrievedVehicle', src, veh)
        TriggerClientEvent('QBCore:Notify', src, 'Bạn đã lấy xe thành công.', 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Không tìm thấy xe trong bãi.', 'error')
    end
end)
