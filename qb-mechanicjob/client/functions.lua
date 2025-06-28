-- =================================================================
-- TỆP FUNCTIONS.LUA PHIÊN BẢN ĐÃ SỬA LỖI VÀ HOÀN CHỈNH
-- =================================================================
QBCore = exports['qb-core']:GetCoreObject()

-- Các hàm tiện ích
function trim(str) -- ĐÃ SỬA: Tên hàm đổi thành chữ thường
    if type(str) == 'string' then
        return str:match("^%s*(.-)%s*$")
    end
    return str
end

function triggerNotify(title, message, type)
    QBCore.Functions.Notify(message, type or "primary", 5000)
end

function pushVehicle(entity)
	if DoesEntityExist(entity) then
		SetVehicleModKit(entity, 0)
		if not NetworkHasControlOfEntity(entity) then
			NetworkRequestControlOfEntity(entity)
			local timeout = 2000
			while timeout > 0 and not NetworkHasControlOfEntity(entity) do
				Wait(100)
				timeout = timeout - 100
			end
		end
		if not IsEntityAMissionEntity(entity) then
			SetEntityAsMissionEntity(entity, true, true)
			local timeout = 2000
			while timeout > 0 and not IsEntityAMissionEntity(entity) do
				Wait(100)
				timeout = timeout - 100
			end
		end
	end
end

-- Các hàm lấy thông tin xe
function searchCar(vehicle)
    if not DoesEntityExist(vehicle) then return "Unknown Vehicle" end
    local vehicleName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    local brand = GetMakeNameFromVehicleModel(GetEntityModel(vehicle))
    local vehicleData = QBCore.Shared.Vehicles[vehicleName:lower()]
    if vehicleData and vehicleData.name then
        return vehicleData.brand .. " " .. vehicleData.name
    end
    return brand .. " " .. vehicleName
end

function getClass(vehicle)
    if not DoesEntityExist(vehicle) then return "Unknown" end
	local classlist = {
		"Compacts", "Sedans", "SUVs", "Coupes", "Muscle", "Sports Classics", "Sports", "Super", "Motorcycles",
		"Off-road", "Industrial", "Utility", "Vans", "Cycles", "Boats", "Helicopters", "Planes", "Service",
		"Emergency", "Military", "Commercial", "Trains"
	}
	local classId = GetVehicleClass(vehicle)
	return classlist[classId + 1] or "Unknown"
end

function searchPrice(vehicle)
    if not DoesEntityExist(vehicle) then return "$0" end
    local vehicleName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)):lower()
    for k, v in pairs(QBCore.Shared.Vehicles) do
        if k == vehicleName then
            local price = v.price
            local formatted = price
            while true do
                formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
                if (k==0) then break end
            end
            return "$" .. formatted
        end
    end
    return "$0"
end

-- Các hàm kiểm tra điều kiện (từ jim-mechanic)
function inCar()
	if IsPedSittingInAnyVehicle(PlayerPedId()) then
		triggerNotify(nil, Lang:t('functions.inCar'), "error")
		return false
	end
	return true
end

function outCar()
	if not IsPedSittingInAnyVehicle(PlayerPedId()) then
		triggerNotify(nil, Lang:t('functions.outCar'), "error")
		return false
	end
	return true
end

function nearPoint(coords)
	if not IsAnyVehicleNearPoint(coords.x, coords.y, coords.z, 3.5) then
        triggerNotify(nil, Lang:t('functions.nearby'), "error")
        return false
	end
    return true
end

function lockedCar(vehicle)
	if GetVehicleDoorLockStatus(vehicle) >= 2 then
		triggerNotify(nil, Lang:t('functions.locked'), "error")
		return true
	end
	return false
end

function getClosest(coords)
	local vehs = { 71, 0, 2, 4, 6, 7, 23, 127, 260, 2146, 2175, 12294, 16834, 16386, 20503, 32768, 67590, 67711, 98309, 100359 }
    local closestVehicle = 0
	for _, flag in ipairs(vehs) do
        closestVehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 3.5, 0, flag)
        if closestVehicle ~= 0 then
            break
        end
    end
	return closestVehicle
end

function lookVeh(vehicle)
	if type(vehicle) == "vector3" then
		if not IsPedHeadingTowardsPosition(PlayerPedId(), vehicle, 30.0) then
			TaskTurnPedToFaceCoord(PlayerPedId(), vehicle, 1500)
			Wait(1500)
		end
	else
		if DoesEntityExist(vehicle) then
			if not IsPedHeadingTowardsPosition(PlayerPedId(), GetEntityCoords(vehicle), 30.0) then
				TaskTurnPedToFaceCoord(PlayerPedId(), GetEntityCoords(vehicle), 1500)
				Wait(1500)
			end
		end
	end
end

function playAnim(animDict, animName, duration, flag)
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do Wait(10) end
    TaskPlayAnim(PlayerPedId(), animDict, animName, 1.0, -1.0, duration, flag, 1, false, false, false)
end

function emptyHands(playerPed)
    ClearPedTasks(playerPed)
end

function updateCar(vehicle)
    local vehicleProps = QBCore.Functions.GetVehicleProperties(vehicle)
    TriggerServerEvent('qb-mechanicjob:server:SaveVehicleProps', vehicleProps)
end

function toggleItem(give, item, amount)
    TriggerServerEvent('qb-mechanicjob:server:toggleItem', give, item, amount)
end

function jobChecks()
    if not Config.RequireJob then return true end
    local playerJob = QBCore.Functions.GetPlayerData().job
    for _, jobName in ipairs(Config.JobRoles or {}) do
        if playerJob.name == jobName then return true end
    end
    triggerNotify(nil, Lang:t('functions.mechanic'), 'error')
    return false
end

function locationChecks()
    return true
end

function rgbToHex(r,g,b)
	local rgb = (r * 0x10000) + (g * 0x100) + b
	return string.format("%06x", rgb)
end

function HexTorgb(hex)
	local hex = hex:gsub("#","")
	return tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6))
end

function nosBar(level)
	local full, empty = "▓", "░"
	local green, yellow, red, grey = "green", "yellow", "red", "grey"
	local bartable = {}
	for i = 1, 10 do bartable[i] = "<span style='color:"..green.."'>"..full.."</span>" end
	if level <= 91 then bartable[10] = "<span style='color:"..grey.."'>"..empty.."</span>" end
	if level <= 81 then bartable[9] = "<span style='color:"..grey.."'>"..empty.."</span>" end
	if level <= 71 then bartable[8] = "<span style='color:"..grey.."'>"..empty.."</span>"; for i = 1, 7 do bartable[i] = "<span style='color:"..yellow.."'>"..full.."</span>" end end
	if level <= 61 then bartable[7] = "<span style='color:"..grey.."'>"..empty.."</span>" end
	if level <= 51 then bartable[6] = "<span style='color:"..grey.."'>"..empty.."</span>" end
	if level <= 41 then bartable[5] = "<span style='color:"..grey.."'>"..empty.."</span>" end
	if level <= 31 then bartable[4] = "<span style='color:"..grey.."'>"..empty.."</span>"; for i = 1, 3 do bartable[i] = "<span style='color:"..red.."'>"..full.."</span>" end end
	if level <= 21 then bartable[3] = "<span style='color:"..grey.."'>"..empty.."</span>" end
	if level <= 11 then bartable[2] = "<span style='color:"..grey.."'>"..empty.."</span>" end
	if level <= 1 then bartable[1] = "<span style='color:"..grey.."'>"..empty.."</span>" end
	local bar = ""
	for i = 1, 10 do bar = bar..bartable[i] end
	return bar
end