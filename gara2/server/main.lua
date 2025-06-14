-- File: server/main.lua (Tối ưu hóa)

local QBCore = exports['qb-core']:GetCoreObject()

-- Callbacks remain the same
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

-- =================================================================
-- EVENTS (REWRITTEN FOR INCREMENTAL UPDATES)
-- =================================================================

RegisterNetEvent('personalparking:server:parkVehicle', function(parkId, spotId, vehicleData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    -- Gợi ý: Chuyển dòng này vào config.lua để dễ dàng chỉnh sửa
    local parkFee = 1000 

    if not Player then return end

    if Player.Functions.GetMoney('bank') >= parkFee then
        Player.Functions.RemoveMoney('bank', parkFee, 'parking-fee')
        local deleted = MySQL.update.await('DELETE FROM player_vehicles WHERE plate = ? AND citizenid = ?', { vehicleData.plate, Player.PlayerData.citizenid })

        if deleted > 0 then
            local modsJson = json.encode(vehicleData.mods)
            local newParkedVehicle = {
                citizenid = Player.PlayerData.citizenid,
                plate = vehicleData.plate,
                model = vehicleData.model,
                mods = modsJson,
                park_id = parkId,
                spot_id = spotId
            }

            MySQL.insert('INSERT INTO player_parked_vehicles (citizenid, plate, model, mods, park_id, spot_id) VALUES (?, ?, ?, ?, ?, ?)', {
                newParkedVehicle.citizenid, newParkedVehicle.plate, newParkedVehicle.model, newParkedVehicle.mods, newParkedVehicle.park_id, newParkedVehicle.spot_id
            })
            
            TriggerClientEvent('QBCore:Notify', src, 'Bạn đã đậu xe với phí là $'..parkFee, 'success')
            TriggerEvent('qb-log:server:CreateLog', 'personalparking', 'Vehicle Parked', 'green', '**'..Player.PlayerData.name..'** đã đậu xe **'..vehicleData.model..'** (`'..vehicleData.plate..'`) tại **'..parkId..'** với phí $'..parkFee..'.')
            
            -- !!! PERFORMANCE IMPROVEMENT !!!
            -- Thay vì làm mới toàn bộ, chỉ gửi thông tin về chiếc xe vừa đỗ.
            -- Client cần vehicleData gốc (chưa encode mods)
            newParkedVehicle.mods = vehicleData.mods 
            TriggerClientEvent('personalparking:client:addParkedVehicle', -1, parkId, newParkedVehicle)
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

    local parkedVehicle = MySQL.query.await('SELECT * FROM player_parked_vehicles WHERE plate = ? AND citizenid = ? AND park_id = ?', { vehiclePlate, Player.PlayerData.citizenid, parkId })

    if parkedVehicle and parkedVehicle[1] then
        local veh = parkedVehicle[1]
        
        MySQL.insert('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, state, garage) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
            Player.PlayerData.license, Player.PlayerData.citizenid, veh.model, joaat(veh.model), veh.mods, veh.plate, 0, 'none'
        })

        MySQL.update.await('DELETE FROM player_parked_vehicles WHERE id = ?', { veh.id })

        TriggerClientEvent('personalparking:client:spawnRetrievedVehicle', src, veh)
        TriggerClientEvent('QBCore:Notify', src, 'Bạn đã lấy xe của mình.', 'success')
        TriggerEvent('qb-log:server:CreateLog', 'personalparking', 'Vehicle Retrieved', 'blue', '**'..Player.PlayerData.name..'** đã lấy xe **'..veh.model..'** (`'..veh.plate..'`) từ **'..parkId..'**.')
        
        -- !!! PERFORMANCE IMPROVEMENT !!!
        -- Thay vì làm mới toàn bộ, chỉ gửi thông báo xóa chiếc xe vừa lấy.
        TriggerClientEvent('personalparking:client:removeParkedVehicle', -1, parkId, vehiclePlate)
    else
        TriggerClientEvent('QBCore:Notify', src, 'Đây không phải xe của bạn hoặc nó không được đậu ở đây.', 'error')
    end
end)