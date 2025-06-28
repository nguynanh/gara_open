local QBCore = exports['qb-core']:GetCoreObject()
RegisterNetEvent('QBCore:Server:UpdateObject', function() if source ~= '' then return false end QBCore = exports['qb-core']:GetCoreObject() end)

local VehicleNitrous = { }
local nosColour = { }

AddEventHandler('onResourceStart', function(resource) if GetCurrentResourceName() ~= resource then return end
	TriggerEvent("qb-mechanicjob:GetNosUpdate")
	TriggerEvent("qb-mechanicjob:GetNosColourUpdate")
end)

--These events sync the VehicleNitrous table with the server, making them able to be synced with the players
RegisterNetEvent('qb-mechanicjob:server:LoadNitrous', function(Plate)
	VehicleNitrous[Plate] = { hasnitro = 1, level = 100 }
	TriggerClientEvent('qb-mechanicjob:client:LoadNitrous',-1, Plate)
	TriggerEvent('qb-mechanicjob:database:LoadNitro', Plate)
end)

RegisterNetEvent('qb-mechanicjob:server:UnloadNitrous', function(Plate)
	VehicleNitrous[Plate] = nil
	TriggerClientEvent('qb-mechanicjob:client:UnloadNitrous', -1, Plate)
	TriggerEvent('qb-mechanicjob:database:UnloadNitro', Plate)
end)

RegisterNetEvent('qb-mechanicjob:server:UpdateNitroLevel', function(Plate, level)
	VehicleNitrous[Plate] = { hasnitro = 1, level = level }
	TriggerClientEvent('qb-mechanicjob:client:UpdateNitroLevel', -1, Plate, level)
end)

--Event called on script start to grab Database info about nos
RegisterNetEvent("qb-mechanicjob:GetNosUpdate", function()
	local result = MySQL.Sync.fetchAll('SELECT * FROM player_vehicles WHERE hasnitro = ?', {1})
	if result and result[1] then
		for _, v in pairs(result) do
			if Config.Debug then print("^5Debug^7: ^3GetNosUpdate^7: ^2VehicleNitrous^7[^6"..tostring(v["plate"]).."^7] = { ^2level ^7= ^6"..tonumber(v["noslevel"]).."^7, ^2hasnitro ^7= ^6"..tostring(v["hasnitro"]).."^7 }") end
			VehicleNitrous[v["plate"]] = { hasnitro = v["hasnitro"], level = tonumber(v["noslevel"]), }
		end
		if Config.Debug then print("^5Debug^7: ^3GetNosUpdate^7: ^2VehicleNitrous Results Found^7: ^6"..#result.."^7") end
	else if Config.Debug then print("^5Debug^7: ^3GetNosUpdate^7: ^2Checked Database and found no vehicles with NOS^7") end end
end)

--Callback to send Database info to Client
QBCore.Functions.CreateCallback('qb-mechanicjob:GetNosLoaded', function(source, cb) cb(VehicleNitrous) end)

--Database interactions
RegisterNetEvent('qb-mechanicjob:database:LoadNitro', function(Plate) MySQL.Async.execute('UPDATE player_vehicles SET noslevel = ?, hasnitro = ? WHERE plate = ?', {100, true, Plate}) end)
RegisterNetEvent('qb-mechanicjob:database:UnloadNitro', function(plate) MySQL.Async.execute('UPDATE player_vehicles SET noslevel = ?, hasnitro = ? WHERE plate = ?', {0, false, plate}) end)
RegisterNetEvent('qb-mechanicjob:database:UpdateNitroLevel', function(plate, level)
	if Config.Debug then print("^5Debug^7: ^2Database ^6noslevel^2 updated "..plate.." "..level.."^7") end
	MySQL.Async.execute('UPDATE player_vehicles SET noslevel = ? WHERE plate = ?', {level, plate})
end)

--Syncing stuff
RegisterNetEvent('qb-mechanicjob:server:SyncPurge', function(netId, enabled, size) TriggerClientEvent('qb-mechanicjob:client:SyncPurge', -1, netId, enabled, size) end)
RegisterNetEvent('qb-mechanicjob:server:SyncTrail', function(netId, enabled) TriggerClientEvent('qb-mechanicjob:client:SyncTrail', -1, netId, enabled) end)
RegisterNetEvent('qb-mechanicjob:server:SyncFlame', function(netId, scale) TriggerClientEvent('qb-mechanicjob:client:SyncFlame', -1, netId, scale) end)

QBCore.Functions.CreateUseableItem("noscolour", function(source, item) TriggerClientEvent("qb-mechanicjob:client:NOS:rgbORhex", source) end)

--Event called on script start to grab Database info about nos
RegisterNetEvent("qb-mechanicjob:GetNosColourUpdate", function()
	local result = MySQL.Sync.fetchAll("SELECT `nosColour`, `plate` FROM `player_vehicles` WHERE 1")
	if result and result[1] then
		for _, v in pairs(result) do
			if v["nosColour"] then
				json.decode(v["nosColour"])
				local newColour = json.decode(v["nosColour"])
				if Config.Debug then print("^5Debug^7: ^3nosColour^7[^6"..tostring(v["plate"]).."^7] = { ^2RBG^7: ^6"..newColour[1].."^7, ^6"..newColour[2].."^7, ^6"..newColour[3].." ^7}") end
				nosColour[v["plate"]] = newColour
			end
		end
	end
end)

--Callback to send Database info to Client
QBCore.Functions.CreateCallback('qb-mechanicjob:GetNosColour', function(source, cb) cb(nosColour) end)

-- This event is to make it so every car's purge colour is synced
-- If you change the colour of the purge on a car, everyone who gets in THAT car will spray this colour
RegisterNetEvent('qb-mechanicjob:server:ChangeColour', function(plate, newColour)
    if not plate or not newColour then return end

    -- Cập nhật màu ở phía server để đồng bộ cho người chơi mới vào
    nosColour[plate] = newColour 
    
    -- Gửi sự kiện đến tất cả client để cập nhật màu ngay lập tức
    TriggerClientEvent('qb-mechanicjob:client:ChangeColour', -1, plate, newColour) 
    
    -- Lưu màu mới vào cơ sở dữ liệu
    MySQL.Async.execute('UPDATE player_vehicles SET nosColour = ? WHERE plate = ?', {
        json.encode(newColour),
        plate
    }, function(affectedRows)
        if affectedRows > 0 then
            print("[NOS] Updated nosColour for plate: " .. plate)
        end
    end)
end)
-- Callback xử lý việc nạp lại NOS
QBCore.Functions.CreateCallback('qb-mechanicjob:server:NosRefill', function(source, cb, price)
    local Player = QBCore.Functions.GetPlayer(source)
    local hasEmptyCan = Player.Functions.GetItemByName('noscan')

    if hasEmptyCan and Player.Functions.GetMoney('cash') >= price then
        Player.Functions.RemoveMoney('cash', price)
        Player.Functions.RemoveItem('noscan', 1)
        Player.Functions.AddItem('nos', 1)
        cb(true) -- Trả về thành công
    else
        cb(false) -- Trả về thất bại
    end
end)