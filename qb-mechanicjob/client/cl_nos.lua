-- =================================================================
-- TỆP CL_NOS.LUA HOÀN CHỈNH VÀ CUỐI CÙNG
-- =================================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Biến cục bộ
local NitrousActivated = false
local VehicleNitrous = {}
local nosColour = {}
local boosting = false
local forceStop = false
local damageTimer = 0
local CurrentVehicle
local Plate
local purgemode = true
local purgeSize = 0.4
local boostLevel = 1
local purgeCool = 0
local soundId = GetSoundId()
local vehiclePurge = {}
local vehicleTrails = {}

-- Các hàm khởi tạo
function GetNos()
	QBCore.Functions.TriggerCallback('qb-mechanicjob:GetNosLoaded', function(vehs) VehicleNitrous = vehs or {} end)
end

function GetNosColour()
	QBCore.Functions.TriggerCallback('qb-mechanicjob:GetNosColour', function(vehs) nosColour = vehs or {} end)
end

AddEventHandler('onResourceStart', function(resource)
    if GetCurrentResourceName() == resource then
        GetNos()
        GetNosColour()
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    GetNos()
    GetNosColour()
end)

-- Hàm hiệu ứng màn hình
function SetNitroBoostScreenEffectsEnabled(enabled)
    if enabled then
        StopScreenEffect('RaceTurbo', false)
        StartScreenEffect('RaceTurbo', 0, false)
        SetTimecycleModifier('rply_motionblur')
        ShakeGameplayCam('SKY_DIVING_SHAKE', 0.25)
    else
        StopGameplayCamShaking(true)
        ClearTimecycleModifier()
    end
end

-- Sự kiện lắp đặt NOS
-- =================================================================
-- KHỐI LOGIC LẮP ĐẶT NOS ĐẦY ĐỦ VỚI MINIGAME
-- =================================================================

-- Hàm xử lý khi thất bại minigame
local function HandleNosInstallFailure(vehicle, playerPed)
    triggerNotify(nil, Lang:t('nos.failed'), "error")
    SetVehicleDoorShut(vehicle, 4, false)
    emptyHands(playerPed)
    if Config.explosiveFail then
        local chance = math.random(1, 10)
        -- Nếu không phải thợ máy hoặc thợ máy cũng có thể gây nổ
        if (not jobChecks() and not Config.explosiveFailJob) or Config.explosiveFailJob then
            if chance == 10 then -- 10% cơ hội nổ
                SetVehicleDoorBroken(vehicle, 4, 0) -- Văng nắp capo
                Wait(100)
                AddExplosion(GetOffsetFromEntityInWorldCoords(vehicle, 0.0, 1.6, 1.0), 2, 0.8, 1, 0, 1.0, true)
            end
        end
    end
end

-- Hàm xử lý khi thành công minigame
local function RunNosInstallationProgressbar(vehicle, playerPed)
    local time = math.random(8000, 12000)
    QBCore.Functions.Progressbar("installing_nos", Lang:t('nos.installing'), time, false, true, {
        disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true,
    }, {
        animDict = "mini@repair", anim = "fixing_a_ped", flags = 8,
    }, {}, {}, function() -- On Success
        SetVehicleModKit(vehicle, 0)
        ClearPedTasks(playerPed)
        if VehicleNitrous and VehicleNitrous[trim(GetVehicleNumberPlateText(vehicle))] then
            toggleItem(true, "noscan")
        end
        TriggerServerEvent('qb-mechanicjob:server:LoadNitrous', trim(GetVehicleNumberPlateText(vehicle)))
        SetVehicleDoorShut(vehicle, 4, false)
        updateCar(vehicle)
        toggleItem(false, "nos")
        triggerNotify(nil, Lang:t('nos.installed'), "success")
        emptyHands(playerPed)
    end, function() -- On Cancel
        HandleNosInstallFailure(vehicle, playerPed)
    end, "nos")
end

-- Sự kiện chính khi sử dụng vật phẩm
RegisterNetEvent('qb-mechanicjob:client:applyNOS', function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)

    if not inCar() then return end
    if not nearPoint(coords) then return end

    local vehicle = getClosest(coords)
    if not DoesEntityExist(vehicle) then return end

    pushVehicle(vehicle)
    if lockedCar(vehicle) then return end

    if not IsToggleModOn(vehicle, 18) then
        triggerNotify(nil, Lang:t('nos.notinstalled'), "error")
        return
    end

    local found = false
    for _, v in pairs({"engine"}) do
        if #(GetEntityCoords(playerPed) - GetWorldPositionOfEntityBone(vehicle, GetEntityBoneIndexByName(vehicle, v))) <= 2.5 then
            lookVeh(GetWorldPositionOfEntityBone(vehicle, GetEntityBoneIndexByName(vehicle, v)))
            found = true
            break
        end
    end
    if not found then return end

    SetVehicleEngineOn(vehicle, false, false, true)
    TaskTurnPedToFaceEntity(playerPed, vehicle, 1000)
    Wait(1000)
    SetVehicleDoorOpen(vehicle, 4, false, false)
    playAnim("mini@repair", "fixing_a_ped", 15000, 16)

    -- Bắt đầu logic skill check
    if Config.skillcheck == "qb-lock" then
        local success = exports['qb-lock']:StartLockPickCircle(math.random(2, 4), math.random(7, 10), success)
        if success then
            RunNosInstallationProgressbar(vehicle, playerPed)
        else
            HandleNosInstallFailure(vehicle, playerPed)
        end
    elseif Config.skillcheck == "ps-ui" then
        exports['ps-ui']:Circle(function(success)
            if success then
                RunNosInstallationProgressbar(vehicle, playerPed)
            else
                HandleNosInstallFailure(vehicle, playerPed)
            end
        end, 2, 20)
    elseif Config.skillcheck == "qb-skillbar" then
        local Skillbar = exports['qb-skillbar']:GetSkillbarObject()
        Skillbar.Start({ duration = math.random(2500, 5000), pos = math.random(10, 30), width = math.random(10, 20) }, 
        function() -- On Success
            RunNosInstallationProgressbar(vehicle, playerPed)
        end, function() -- On Fail
            HandleNosInstallFailure(vehicle, playerPed)
        end)
    else
        -- Trường hợp không có skillcheck
        RunNosInstallationProgressbar(vehicle, playerPed)
    end
end)
-- Các sự kiện cập nhật và đồng bộ
RegisterNetEvent('qb-mechanicjob:client:UpdateNitroLevel', function(Plate, level) VehicleNitrous[Plate] = { hasnitro = true, level = level } end)
RegisterNetEvent('qb-mechanicjob:client:LoadNitrous', function(Plate)
    if not LocalPlayer.state.isLoggedIn then return end
    VehicleNitrous[Plate] = { hasnitro = true, level = 100 }
end)
RegisterNetEvent('qb-mechanicjob:client:UnloadNitrous', function(Plate)
    if not LocalPlayer.state.isLoggedIn then return end
    VehicleNitrous[Plate] = nil
end)

-- Điều khiển
RegisterKeyMapping('levelUP', 'Boost/Purge lvl Up', 'keyboard', 'PAGEUP')
RegisterCommand('levelUP', function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId())
    if not DoesEntityExist(vehicle) then return end
	local plate = trim(GetVehicleNumberPlateText(vehicle))
	if VehicleNitrous[plate] and VehicleNitrous[plate].hasnitro and GetPedInVehicleSeat(vehicle, -1) == PlayerPedId() then
		if purgemode and purgeSize < 1.0 then
			purgeSize = purgeSize + 0.1
			if purgeSize >= 1.0 then purgeSize = 1.0 end
		elseif not purgemode and boostLevel < 3 and not NitrousActivated then
			boostLevel = boostLevel + 1
		end
	end
end)

RegisterKeyMapping('levelDown', 'Boost/Purge lvl Down', 'keyboard', 'PAGEDOWN')
RegisterCommand('levelDown', function()
	local vehicle = GetVehiclePedIsIn(PlayerPedId())
    if not DoesEntityExist(vehicle) then return end
	local plate = trim(GetVehicleNumberPlateText(vehicle))
	if VehicleNitrous[plate] and VehicleNitrous[plate].hasnitro and GetPedInVehicleSeat(vehicle, -1) == PlayerPedId() then
		if purgemode and purgeSize > 0.1 then
			purgeSize = purgeSize - 0.1
			if purgeSize < 0.1 then purgeSize = 0.1 end
		elseif not purgemode and boostLevel > 1 and not NitrousActivated then
			boostLevel = boostLevel - 1
		end
	end
end)

RegisterKeyMapping('nosSwitch', 'Boost/Purge Switch', 'keyboard', 'LCONTROL')
RegisterCommand('nosSwitch', function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId())
    if not DoesEntityExist(vehicle) then return end
	local plate = trim(GetVehicleNumberPlateText(vehicle))
	if VehicleNitrous[plate] and VehicleNitrous[plate].hasnitro and GetPedInVehicleSeat(vehicle, -1) == PlayerPedId() then
		purgemode = not purgemode
        triggerNotify(nil, purgemode and Lang:t('nos.purgemode') or Lang:t('nos.boostmode'), "success")
	end
end)

-- Logic sử dụng NOS
RegisterKeyMapping('+nosBoost', 'Boost', 'keyboard', 'LSHIFT')
RegisterCommand('+nosBoost', function()
	CurrentVehicle = GetVehiclePedIsIn(PlayerPedId())
	if IsPedInAnyVehicle(PlayerPedId()) then
		Plate = trim(GetVehicleNumberPlateText(CurrentVehicle))
		if VehicleNitrous[Plate] and VehicleNitrous[Plate].hasnitro and GetPedInVehicleSeat(CurrentVehicle, -1) == PlayerPedId() then
			forceStop = true
			if purgemode then
				if not boosting then
					boosting = true
					TriggerServerEvent('qb-mechanicjob:server:SyncPurge', VehToNet(CurrentVehicle), true, purgeSize)
					CreateThread(function() while boosting do purgeCool = purgeCool + 1; Wait(500) end end)
				end
			else
				if (GetEntitySpeed(CurrentVehicle) * 3.6) > 25.0 and not boosting and not IsEntityInAir(CurrentVehicle) then
					boosting = true
					NitrousActivated = true
					ModifyVehicleTopSpeed(CurrentVehicle, Config.NosTopSpeed or -1.0)
					ApplyForceToEntity(CurrentVehicle, 3, 0, Config.NosBoostPower[boostLevel], 0, 0.0, -1.2, 0.0, 0, true, true, true, false, true)
					if Config.EnableScreen then SetNitroBoostScreenEffectsEnabled(true) end
					if Config.EnableTrails then TriggerServerEvent('qb-mechanicjob:server:SyncTrail', VehToNet(CurrentVehicle), true) end
					SetVehicleBoostActive(CurrentVehicle, 1)
					
					CreateThread(function()
						while NitrousActivated do
							if VehicleNitrous[Plate] and VehicleNitrous[Plate].level > 0 then
								local useRate = Config.NitrousUseRate
								if boostLevel == 1 then useRate = useRate / 2 end
								if boostLevel == 3 then useRate = useRate * 1.5 end
								if Config.EnableFlame then TriggerServerEvent('qb-mechanicjob:server:SyncFlame', VehToNet(CurrentVehicle), true) end
								TriggerServerEvent('qb-mechanicjob:server:UpdateNitroLevel', Plate, VehicleNitrous[Plate].level - useRate)
							else
								NitrousActivated = false -- Dừng vòng lặp
							end
							Wait(100)
						end
                        -- Logic dừng khi hết NOS
						if boosting then
							TriggerServerEvent('qb-mechanicjob:server:UnloadNitrous', Plate)
							toggleItem(true, "noscan")
						end
						boosting = false
						forceStop = false
						SetVehicleBoostActive(CurrentVehicle, 0)
						if Config.EnableFlame then TriggerServerEvent('qb-mechanicjob:server:SyncFlame', VehToNet(CurrentVehicle), false) end
						if Config.EnableScreen then SetNitroBoostScreenEffectsEnabled(false) end
						if Config.EnableTrails then TriggerServerEvent('qb-mechanicjob:server:SyncTrail', VehToNet(CurrentVehicle), false) end
						ModifyVehicleTopSpeed(CurrentVehicle, -1.0)
					end)
				end
			end
		end
	end
end)

RegisterCommand('-nosBoost', function()
    if not CurrentVehicle or not DoesEntityExist(CurrentVehicle) then return end
    TriggerServerEvent('qb-mechanicjob:server:SyncPurge', VehToNet(CurrentVehicle), false)
    boosting = false
	if NitrousActivated then
		NitrousActivated = false
		StopSound(soundId)
		SetVehicleBoostActive(CurrentVehicle, 0)
		if Config.EnableFlame then TriggerServerEvent('qb-mechanicjob:server:SyncFlame', VehToNet(CurrentVehicle), false) end
		ModifyVehicleTopSpeed(CurrentVehicle, -1.0)
		if Config.EnableTrails then TriggerServerEvent('qb-mechanicjob:server:SyncTrail', VehToNet(CurrentVehicle), false) end
		if Config.EnableScreen then SetNitroBoostScreenEffectsEnabled(false) end
	end
end)

-- Xử lý hiệu ứng được đồng bộ từ server
RegisterNetEvent('qb-mechanicjob:client:SyncPurge', function(netid, enabled, size)
    if not NetworkDoesEntityExistWithNetworkId(netid) then return end
    local vehicle = NetToVeh(netid)
    if DoesEntityExist(vehicle) then
        SetVehicleNitroPurgeEnabled(vehicle, enabled, size)
    end
end)

RegisterNetEvent('qb-mechanicjob:client:SyncTrail', function(netid, enabled)
    if not NetworkDoesEntityExistWithNetworkId(netid) then return end
    local vehicle = NetToVeh(netid)
    if DoesEntityExist(vehicle) then
        SetVehicleLightTrailEnabled(vehicle, enabled)
    end
end)

RegisterNetEvent('qb-mechanicjob:client:SyncFlame', function(netid, enable)
    if not NetworkDoesEntityExistWithNetworkId(netid) then return end
    local vehicle = NetToVeh(netid)
    if DoesEntityExist(vehicle) then
        if enable then
            if boostLevel == 1 then CreateVehicleExhaustBackfire(vehicle) end
            if boostLevel >= 2 then
                RequestNamedPtfxAsset("veh_xs_vehicle_mods")
                while not HasNamedPtfxAssetLoaded("veh_xs_vehicle_mods") do Wait(0) end
                SetVehicleNitroEnabled(vehicle, true)
            end
        else
            SetVehicleNitroEnabled(vehicle, false)
        end
    end
end)

-- Các hàm tạo hiệu ứng
function CreateVehicleExhaustBackfire(vehicle)
    -- Danh sách các tên "bone" (khung xương) có thể có của ống xả
    local exhaustNames = { "exhaust" }
    for i = 2, 16 do
        table.insert(exhaustNames, "exhaust_" .. i)
    end

    -- Đảm bảo asset hiệu ứng đã được tải
    RequestNamedPtfxAsset("core")
    while not HasNamedPtfxAssetLoaded("core") do
        Wait(10)
    end

    for _, exhaustName in ipairs(exhaustNames) do
        local boneIndex = GetEntityBoneIndexByName(vehicle, exhaustName)
        
        -- Nếu tìm thấy bone ống xả trên xe
        if boneIndex ~= -1 then
            -- Lấy tọa độ chính xác của ống xả trong thế giới game
            local exhaustPos = GetWorldPositionOfEntityBone(vehicle, boneIndex)
            
            -- Sử dụng hàm này để "chuẩn bị" cho việc gọi hiệu ứng tiếp theo
            UseParticleFxAssetNextCall("core")

            -- Tạo hiệu ứng tại tọa độ đã lấy, không phải ở tâm xe
            StartParticleFxNonLoopedAtCoord(
                "veh_backfire",          -- Tên hiệu ứng
                exhaustPos.x,            -- Tọa độ X
                exhaustPos.y,            -- Tọa độ Y
                exhaustPos.z,            -- Tọa độ Z
                0.0, 0.0, 0.0,           -- Góc xoay của hiệu ứng (không cần)
                1.25,                    -- Kích thước hiệu ứng
                false, false, false
            )
        end
    end
end

function CreateVehiclePurgeSpray(vehicle, xOffset, yOffset, zOffset, xRot, yRot, zRot, scale)
    if not LocalPlayer.state.isLoggedIn then return end
    if DoesEntityExist(vehicle) then
        RequestNamedPtfxAsset('core')
        while not HasNamedPtfxAssetLoaded('core') do Wait(0) end
        UseParticleFxAssetNextCall('core')
        return StartParticleFxLoopedOnEntity('ent_sht_steam', vehicle, xOffset, yOffset, zOffset, xRot, yRot, zRot, scale, 0, 0, 0)
    end
end

function SetVehicleNitroPurgeEnabled(vehicle, enabled, size)
    if enabled and DoesEntityExist(vehicle) then
        RequestAmbientAudioBank("CARWASH_SOUNDS", 0)
        PlaySoundFromEntity(soundId, "SPRAY", vehicle, "CARWASH_SOUNDS", 1, 0)
        local off = GetOffsetFromEntityGivenWorldCoords(vehicle, GetWorldPositionOfEntityBone(vehicle, GetEntityBoneIndexByName(vehicle, 'engine')))
        local ptfxs = {}
        local manFound = false
        for i=0,3 do
            if IsThisModelABike(GetEntityModel(vehicle)) then
                ptfxs[#ptfxs+1] = CreateVehiclePurgeSpray(vehicle, off.x - 0.1, off.y-0.2, off.z, 40.0, -90.0, 70.0, size) -- Left
                ptfxs[#ptfxs+1] = CreateVehiclePurgeSpray(vehicle, off.x + 0.1, off.y-0.2, off.z, 40.0, 90.0, -70.0, size)	--Right
            else
                for k in pairs(manualPurgeLoc) do
                    if GetEntityModel(vehicle) == k then
                        manFound = true
                        for _, v in pairs(manualPurgeLoc[k]) do
                            ptfxs[#ptfxs+1] = CreateVehiclePurgeSpray(vehicle, off.x + v[1], off.y + v[2], off.z + v[3], v[4], v[5], v[6], size)
                        end
                    end
                end
                if not manFound then
                    off = GetOffsetFromEntityGivenWorldCoords(vehicle, GetWorldPositionOfEntityBone(vehicle, GetEntityBoneIndexByName(vehicle, 'bonnet')))
                    ptfxs[#ptfxs+1] = CreateVehiclePurgeSpray(vehicle, off.x - 0.2, off.y + 0.5, off.z, 40.0, -20.0, 0.0, size)
                    ptfxs[#ptfxs+1] = CreateVehiclePurgeSpray(vehicle, off.x + 0.2, off.y + 0.5, off.z, 40.0, 20.0, 0.0, size)
                end
            end
            if nosColour and nosColour[trim(GetVehicleNumberPlateText(vehicle))] then
                for i=1, #ptfxs do
                    SetParticleFxLoopedColour(ptfxs[i],
                    nosColour[trim(GetVehicleNumberPlateText(vehicle))][1]/255,
                    nosColour[trim(GetVehicleNumberPlateText(vehicle))][2]/255,
                    nosColour[trim(GetVehicleNumberPlateText(vehicle))][3]/255)
                end
            else
                for i=1, #ptfxs do
                    SetParticleFxLoopedColour(ptfxs[i], 255/255, 255/255, 255/255)
                end
            end
        end
            vehiclePurge[vehicle] = ptfxs
    else
        StopSound(soundId)
        if vehiclePurge[vehicle] and #vehiclePurge[vehicle] > 0 then
            for _, v in ipairs(vehiclePurge[vehicle]) do
                StopParticleFxLooped(v, false)
            end
        end
        vehiclePurge[vehicle] = nil
    end
end

function SetVehicleLightTrailEnabled(vehicle, enabled)
    if enabled then
        vehicleTrails[vehicle] = {
            CreateVehicleLightTrail(vehicle, GetEntityBoneIndexByName(vehicle, "taillight_l"), 1.0),
            CreateVehicleLightTrail(vehicle, GetEntityBoneIndexByName(vehicle, "taillight_r"), 1.0),
        }
    else
        if vehicleTrails[vehicle] and #vehicleTrails[vehicle] > 0 then
            for _, particleId in ipairs(vehicleTrails[vehicle]) do StopVehicleLightTrail(particleId, 500) end
        end
        vehicleTrails[vehicle] = nil
    end
end

function CreateVehicleLightTrail(vehicle, bone, scale)
    if DoesEntityExist(vehicle) then
        RequestNamedPtfxAsset("core")
        while not HasNamedPtfxAssetLoaded("core") do Wait(0) end
        UseParticleFxAsset("core")
        local ptfx = StartParticleFxLoopedOnEntityBone('veh_light_red_trail', vehicle, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, bone, scale, false, false, false)
        SetParticleFxLoopedEvolution(ptfx, "speed", 1.0, false)
        return ptfx
    end
end

function StopVehicleLightTrail(ptfx, duration)
    CreateThread(function()
        local startTime = GetGameTimer()
        local endTime = GetGameTimer() + duration
        while GetGameTimer() < endTime do
            Wait(0)
            local now = GetGameTimer()
            local scale = (endTime - now) / duration
            SetParticleFxLoopedScale(ptfx, scale)
            SetParticleFxLoopedAlpha(ptfx, scale)
        end
        StopParticleFxLooped(ptfx, false)
    end)
end

-- ===========================================================
-- LOGIC MỞ MENU CHỌN MÀU CHO NOS PURGE
-- ===========================================================

RegisterNetEvent('qb-mechanicjob:client:NOS:rgbORhex', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicle = getClosest(coords)
    if not outCar() then return end -- Phải ở trong xe
    local plate = trim(GetVehicleNumberPlateText(vehicle))

    local currentRBGCol, currentHEXCol
    if nosColour[plate] then
        local r, g, b = table.unpack(nosColour[plate])
        currentRBGCol = "[<span style='color:#"..rgbToHex(r, g, b):upper().."; text-shadow: -1px 0 black, 0 1px black, 1px 0 black, 0 -1px black, 0em 0em 0.5em white, 0em 0em 0.5em white'> "..r.." "..g.." "..b.." </span>]<br>"
        currentHEXCol = "[#<span style='color:#"..rgbToHex(r, g, b):upper().."; text-shadow: -1px 0 black, 0 1px black, 1px 0 black, 0 -1px black, 0em 0em 0.5em white, 0em 0em 0.5em white'>"..rgbToHex(r, g, b):upper().." </span>]<br>"
    else
        currentRBGCol = "[<span style='color:#FFFFFF; text-shadow: -1px 0 black, 0 1px black, 1px 0 black, 0 -1px black, 0em 0em 0.5em white, 0em 0em 0.5em white'> 255 255 255 </span>]<br>"
        currentHEXCol = "[#<span style='color:#FFFFFF; text-shadow: -1px 0 black, 0 1px black, 1px 0 black, 0 -1px black, 0em 0em 0.5em white, 0em 0em 0.5em white'>FFFFFF </span>]<br>"
    end

    if DoesEntityExist(vehicle) then
        local PaintMenu = {
            { icon = "noscolour", header = Lang:t('nos.nosColour'), text = Lang:t('paintrgb.customheader'), isMenuHeader = true },
            { icon = "fas fa-circle-xmark", header = "", txt = string.gsub(Lang:t('common.close'), "❌ ", ""), params = { event = "qb-mechanicjob:client:Menu:Close" } },
            { header = Lang:t('paintrgb.hex'), text = Lang:t('common.current')..":<br>"..currentHEXCol, params = { event = "qb-mechanicjob:client:NOS:HEXPicker" }, },
            { header = Lang:t('paintrgb.rgb'), text = Lang:t('common.current')..":<br>"..currentRBGCol, params = { event = "qb-mechanicjob:client:NOS:RGBPicker" }, }
        }
        exports['qb-menu']:openMenu(PaintMenu)
    end
end)

RegisterNetEvent('qb-mechanicjob:client:NOS:RGBPicker', function()
    local dialog = exports['qb-input']:ShowInput({
        header = "<center>"..Lang:t('nos.nosColour').."<br>"..Lang:t('paintrgb.rgb'),
        inputs = {
            { type = 'number', name = 'Red', text = 'R' },
            { type = 'number', name = 'Green', text = 'G' },
            { type = 'number', name = 'Blue', text = 'B' },
        }
    })
    if dialog then
        local r, g, b = tonumber(dialog.Red) or 0, tonumber(dialog.Green) or 0, tonumber(dialog.Blue) or 0
        if r > 255 then r = 255 end
        if g > 255 then g = 255 end
        if b > 255 then b = 255 end
        TriggerEvent('qb-mechanicjob:client:NOS:RGBApply', { r, g, b })
    end
end)

RegisterNetEvent('qb-mechanicjob:client:NOS:HEXPicker', function()
    local dialog = exports['qb-input']:ShowInput({
        header = "<center>"..Lang:t('nos.nosColour').."<br>"..Lang:t('paintrgb.hex'),
        inputs = { { type = 'text', name = 'hex', text = '#' } }
    })
    if dialog and dialog.hex then
        local hex = dialog.hex:gsub("#","")
        while string.len(hex) < 6 do hex = hex.."0" Wait(10) end
        local r, g, b = HexTorgb(hex)
        TriggerEvent('qb-mechanicjob:client:NOS:RGBApply', { r, g, b })
    end
end)

RegisterNetEvent('qb-mechanicjob:client:NOS:RGBApply', function(data)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if not DoesEntityExist(vehicle) then return end
    TaskTurnPedToFaceEntity(ped, vehicle, 1000)
    Wait(1000)
    SetVehicleDoorOpen(vehicle, 4, false, false)
    playAnim("mini@repair", "fixing_a_ped", 8000, 16)
    RequestNamedPtfxAsset("scr_recartheft")
    while not HasNamedPtfxAssetLoaded("scr_recartheft") do Wait(10) end
    UseParticleFxAssetNextCall("scr_recartheft")
    SetParticleFxNonLoopedColour(data[1] / 255, data[2] / 255, data[3] / 255)
    SetParticleFxNonLoopedAlpha(1.0)
    Wait(1000)
    StartNetworkedParticleFxNonLoopedAtCoord("scr_wheel_burnout", GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 0.6, 0.8), 0.0, 0.0, GetEntityHeading(vehicle), 0.5, 0.0, 0.0, 0.0)
    Wait(3000)
    TriggerServerEvent("qb-mechanicjob:server:ChangeColour", trim(GetVehicleNumberPlateText(vehicle)), data)
    SetVehicleDoorShut(vehicle, 4, false)
    emptyHands(ped)
    -- toggleItem(false, "noscolour") -- Bạn có thể bật lại dòng này nếu muốn vật phẩm bị xóa sau khi dùng
    triggerNotify(nil, Lang:t('nos.nosColour').." "..Lang:t('check.tireinst'), "success")
end)
-- ===========================================================
-- SỰ KIỆN ĐỒNG BỘ MÀU TỪ SERVER (PHẦN BỊ THIẾU)
-- ===========================================================
RegisterNetEvent('qb-mechanicjob:client:ChangeColour', function(plate, newColour)
    if not LocalPlayer.state.isLoggedIn then return end

    -- Cập nhật bảng màu cục bộ của client
    nosColour[plate] = newColour

    -- Dòng debug để bạn có thể kiểm tra trong console F8
    if Config.Debug then
        print("^5Debug^7: ^2Nhan duoc mau NOS moi cho bien so^7[^6"..tostring(plate).."^7] = { ^2RBG: ^7= ^6"..nosColour[plate][1].."^7, ^6"..nosColour[plate][2].."^7, ^6"..nosColour[plate][3].." ^7}")
    end
end)

-- Logic tạo trạm nạp NOS
-- File: qb-mechanicjob/client/cl_nos.lua

-- XÓA CreateThread cũ và THAY BẰNG CreateThread mới này
CreateThread(function()
    local station = Config.NosRefillStation
    if not station then return end

    -- Chỉ tạo blip nếu được bật trong config
    if station.blip and station.blip.enabled and station.blip.id then
        local nosBlip = AddBlipForCoord(station.coords)
        SetBlipSprite(nosBlip, station.blip.id)
        SetBlipDisplay(nosBlip, 4)
        SetBlipScale(nosBlip, station.blip.scale)
        SetBlipColour(nosBlip, station.blip.colour)
        SetBlipAsShortRange(nosBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Trạm nạp NOS")
        EndTextCommandSetBlipName(nosBlip)
    end
    
    -- Tạo vùng tương tác qb-target (giữ nguyên)
    exports['qb-target']:AddCircleZone("nos_refill_station", station.coords, 1.5, {
        name = "nos_refill_station",
        useZ = true,
        debugPoly = false
    }, {
        options = {
            {
                type = "client",
                event = "qb-mechanicjob:client:NosRefill",
                icon = station.target.icon,
                label = station.target.label,
                item = station.target.item,
            }
        },
        distance = 2.5
    })

    -- Chỉ vẽ marker 3D nếu được bật trong config
    if station.marker and station.marker.enabled then
        while true do
            local sleep = 1000
            local playerCoords = GetEntityCoords(PlayerPedId())
            
            if #(playerCoords - station.coords) < station.marker.drawDist then
                sleep = 5
                DrawMarker(
                    station.marker.type,
                    station.coords.x, station.coords.y, station.coords.z + station.marker.zOffset,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    station.marker.size.x, station.marker.size.y, station.marker.size.z,
                    station.marker.color.r, station.marker.color.g, station.marker.color.b, station.marker.color.a,
                    false, true, 2, nil, nil, false
                )
            end
            Wait(sleep)
        end
    end
end)

-- Sự kiện được gọi khi người chơi tương tác với trạm nạp
RegisterNetEvent('qb-mechanicjob:client:NosRefill', function(data)
    QBCore.Functions.TriggerCallback('qb-mechanicjob:server:NosRefill', function(success)
        if success then
            triggerNotify(nil, "Nạp đầy bình NOS thành công!", "success")
        else
            triggerNotify(nil, "Không đủ tiền hoặc không có bình rỗng!", "error")
        end
    end, Config.NosRefillCharge)
end)
-- Bảng dữ liệu vị trí xả khói cho từng loại xe
manualPurgeLoc = {
	--SUPER CARS
	[`autarch`] = {
		{ 0.25, -0.6, -0.2, 40.0, -80.0, 90.0 }, --Left
		{ -0.25, -0.6, -0.2, 40.0, 80.0, -90.0 }, --Right
	},
	[`bullet`] = {
		{ 0.60, -1, 0.25, 40.0, 20.0, 0.0 }, --Left
		{ -0.60, -1, 0.25, 40.0, -20.0, 0.0 }, --Right
	},
	[`banshee2`] = {
		{ 0.40, 0.15, 0.25, 75.0, 20.0, 0.0 }, --Left
		{ -0.40, 0.15, 0.25, 75.0, -20.0, 0.0 }, --Right
	},
	[`cheetah`] = {
		{ 0.40, 0.15, 0.25, 75.0, 20.0, 0.0 }, --Left
		{ -0.40, 0.15, 0.25, 75.0, -20.0, 0.0 }, --Right
	},
	[`cyclone`] = {
		{ 0.40, -0.55, 0.05, 75.0, 20.0, 0.0 }, --Left
		{ -0.40, -0.55, 0.05, 75.0, -20.0, 0.0 }, --Right
	},
	[`deveste`] = {
		{ 0.20, 0.0, 0.19, 75.0, 20.0, 0.0 }, --Left
		{ 0.17, -0.15, 0.17, 75.0, 20.0, 0.0 }, --Left
		{ 0.15, -0.30, 0.15, 75.0, 20.0, 0.0 }, --Left
		{ -0.20, 0.0, 0.19, 75.0, -20.0, 0.0 }, --Right
		{ -0.17, -0.15, 0.17, 75.0, -20.0, 0.0 }, --Right
		{ -0.15, -0.30, 0.15, 75.0, -20.0, 0.0 }, --Right
	},
	[`emerus`] = {
		{ 0.50, 0, 0.19, 60.0, 20.0, 0.0 }, --Left
		{ -0.50, 0, 0.19, 60.0, -20.0, 0.0 }, --Right
	},
	[`entity2`] = {
		{ 0.60, 0.2, 0.10, 75.0, 20.0, 0.0 }, --Left
		{ -0.60, 0.2, 0.10, 75.0, -20.0, 0.0 }, --Right
	},
	[`entityxf`] = {
		{ 0.60, 0.2, 0.20, 40.0, 20.0, 0.0 }, --Left
		{ -0.60, 0.2, 0.20, 40.0, -20.0, 0.0 }, --Right
	},
	[`fmj`] = {
		{ 0.25, -0.6, 0.15, 75.0, 20.0, 0.0 }, --Left
		{ -0.25, -0.6, 0.15, 75.0, -20.0, 0.0 }, --Right
	},
	[`furia`] = {
		{ 0.40, -0.55, 0.05, 75.0, 20.0, 0.0 }, --Left
		{ -0.40, -0.55, 0.05, 75.0, -20.0, 0.0 }, --Right
	},
	[`gp1`] = {
		{ 0.25, -0.70, 0.25, 20.0, 20.0, 0.0 }, --Left
		{ 0.25, -0.80, 0.25, 20.0, 20.0, 0.0 }, --Left
		{ 0.25, -0.90, 0.25, 20.0, 20.0, 0.0 }, --Left

		{ -0.25, -0.70, 0.25, 20.0, -20.0, 0.0 }, --Right
		{ -0.25, -0.80, 0.25, 20.0, -20.0, 0.0 }, --Right
		{ -0.25, -0.90, 0.25, 20.0, -20.0, 0.0 }, --Right
	},
	[`infernus`] = {
		{ 0.50, 0.3, 0.45, 50.0, 20.0, 0.0 }, --Left
		{ -0.50, 0.3, 0.45, 50.0, -20.0, 0.0 }, --Right
	},
	[`italigtb`] = {
		{ 0.30, 2.3, 0.05, 40.0, 30.0, 0.0 }, --Left
		{ -0.30, 2.3, 0.05, 40.0, -30.0, 0.0 }, --Right
	},
	[`italigtb2`] = {
		{ 0.30, 2.3, 0.05, 40.0, 30.0, 0.0 }, --Left
		{ -0.30, 2.3, 0.05, 40.0, -30.0, 0.0 }, --Right
	},
	[`krieger`] = {
		{ 0.30, 2.3, 0.05, 40.0, 30.0, 0.0 }, --Left
		{ -0.30, 2.3, 0.05, 40.0, -30.0, 0.0 }, --Right
	},
	[`le7b`] = {
		{ 0.30, 2.3, 0.05, 40.0, 30.0, 0.0 }, --Left
		{ -0.30, 2.3, 0.05, 40.0, -30.0, 0.0 }, --Right
	},
	[`nero`] = {
		{ 0.30, 2.2, 0.0, 40.0, 30.0, 0.0 }, --Left
		{ -0.30, 2.2, 0.0, 40.0, -30.0, 0.0 }, --Right
	},
	[`nero2`] = {
		{ 0.40, -0.5, 0.16, 60.0, 20.0, 0.0 }, --Left
		{ -0.40, -0.5, 0.16, 60.0, -20.0, 0.0 }, --Right
	},
	[`osiris`] = {
		{ 0.35, -0.4, 0.12, 60.0, 20.0, 0.0 }, --Left
		{ -0.35, -0.4, 0.12, 60.0, -20.0, 0.0 }, --Right
	},
	[`penetrator`] = {
		{ 0.35, -0.6, 0.12, 60.0, 20.0, 0.0 }, --Left
		{ -0.35, -0.6, 0.12, 60.0, -20.0, 0.0 }, --Right
	},
	[`pfister811`] = {
		{ 0.0, 0.35, 0.28, 0.0, 0.0, 0.0 },
		{ 0.0, 0.15, 0.25, 10.0, 0.0, 0.0 },
		{ 0.0, -0.05, 0.20, 20.0, 0.0, 0.0 },
		{ 0.0, -0.25, 0.15, 30.0, 0.0, 0.0 },
		{ 0.0, -0.50, 0.11, 40.0, 0.0, 0.0 },
	},
	[`prototipo`] = {
		{ 0.30, -0, 0.05, 40.0, 30.0, 0.0 }, --Left
		{ -0.30, -0, 0.05, 40.0, -30.0, 0.0 }, --Right
	},
	[`sc1`] = {
		{ 0.30, -0.65, 0.05, 40.0, 30.0, 0.0 }, --Left
		{ -0.30, -0.65, 0.05, 40.0, -30.0, 0.0 }, --Right
	},
	[`t20`] = {
		{ 0.25, -0.65, 0.10, 40.0, 10.0, 0.0 }, --Left
		{ -0.25, -0.65, 0.10, 40.0, -10.0, 0.0 }, --Right
	},
	[`taipan`] = {
		{ 0.32, 2.3, 0.00, 40.0, 30.0, 0.0 }, --Left
		{ -0.32, 2.3, 0.00, 40.0, -30.0, 0.0 }, --Right
	},
	[`tempesta`] = {
		{ 0.50, -0.65, 0.60, 40.0, 10.0, 0.0 }, --Left
		{ -0.50, -0.65, 0.60, 40.0, -10.0, 0.0 }, --Right
	},
	[`tezeract`] = {
		{ 0.50, -0.65, 0.60, 40.0, 10.0, 0.0 }, --Left
		{ -0.50, -0.65, 0.60, 40.0, -10.0, 0.0 }, --Right
	},
	[`thrax`] = {
		{ 0.50, -0.65, 0.10, 40.0, 10.0, 0.0 }, --Left
		{ -0.50, -0.65, 0.10, 40.0, -10.0, 0.0 }, --Right
	},
	[`tigon`] = {
		{ 0.50, -0.65, 0.20, 40.0, 10.0, 0.0 }, --Left
		{ -0.50, -0.65, 0.20, 40.0, -10.0, 0.0 }, --Right
	},
	[`turismor`] = {
		{ 0.50, -0.65, 0.17, 90.0, 10.0, 0.0 }, --Left
		{ -0.50, -0.65, 0.17, 90.0, -10.0, 0.0 }, --Right
	},
	[`tyrant`] = {
		{ 0.32, 2.8, 0.25, 40.0, 30.0, 0.0 }, --Left
		{ -0.32, 2.8, 0.25, 40.0, -30.0, 0.0 }, --Right
	},
	[`vagner`] = {
		{ 0.50, -0.65, 0.10, 40.0, 10.0, 0.0 }, --Left
		{ -0.50, -0.65, 0.10, 40.0, -10.0, 0.0 }, --Right
	},
	[`voltic`] = {
		{ 0.50, -0.65, 0.10, 40.0, 10.0, 0.0 }, --Left
		{ -0.50, -0.65, 0.10, 40.0, -10.0, 0.0 }, --Right
	},
	[`voltic2`] = {
		{ 0.50, -0.65, 0.10, 40.0, 10.0, 0.0 }, --Left
		{ -0.50, -0.65, 0.10, 40.0, -10.0, 0.0 }, --Right
	},
	[`xa21`] = {
		{ 0.50, -0.55, 0.00, 40.0, 10.0, 0.0 }, --Left
		{ -0.50, -0.55, 0.00, 40.0, -10.0, 0.0 }, --Right
	},
	[`zentorno`] = {
		--Left
		{ -0.12, 0.28, 0.28, 0.0, -10.0, 0.0 },
		{ -0.12, 0.05, 0.25, 10.0, -10.0, 0.0 },
		{ -0.12, -0.18, 0.20, 20.0, -10.0, 0.0 },
		{ -0.12, -0.40, 0.15, 30.0, -10.0, 0.0 },
		{ -0.12, -0.60, 0.11, 40.0, -10.0, 0.0 },
		{ -0.12, -0.82, 0.05, 50.0, -10.0, 0.0 },
		--Right
		{ 0.12, 0.28, 0.28, 0.0, 10.0, 0.0 },
		{ 0.12, 0.05, 0.25, 10.0, 10.0, 0.0 },
		{ 0.12, -0.18, 0.20, 20.0, 10.0, 0.0 },
		{ 0.12, -0.40, 0.15, 30.0, 10.0, 0.0 },
		{ 0.12, -0.60, 0.11, 40.0, 10.0, 0.0 },
		{ 0.12, -0.82, 0.05, 50.0, 10.0, 0.0 },
	},
	[`zorrusso`] = {
		--Left
		{ -0.20, -0.2, 0.0, 40.0, -20.0, 0.0 },
		{ -0.20, 0.0, 0.0, 10.0, -20.0, 0.0 },
		--Right
		{ 0.20, -0.2, 0.0, 40.0, 20.0, 0.0 },
		{ 0.20, 0.0, 0.0, 10.0, 20.0, 0.0 },
	},
	---DLC 2699
	[`brioso3`] = {
		{ 0.50, -0.30, -0.10, 40.0, 10.0, 0.0 }, --Left
		{ -0.50, -0.30, -0.10, 40.0, -10.0, 0.0 }, --Right
	},
	[`corsita`] = {
		{ 0.30, 2.3, 0.05, 40.0, 30.0, 0.0 }, --Left
		{ -0.30, 2.3, 0.05, 40.0, -30.0, 0.0 }, --Right
	},
	[`draugur`] = {
		{ 0.50, -0.55, 0.30, 40.0, 10.0, 0.0 }, --Left
		{ -0.50, -0.55, 0.30, 40.0, -10.0, 0.0 }, --Right
	},
	[`kanjosj`] = {
		{ 0.30, -0.50, 0.15, 40.0, 30.0, 0.0 }, --Left
		{ -0.30, -0.50, 0.15, 40.0, -30.0, 0.0 }, --Right
	},
	[`lm87`] = {
		{ 0.30, 2.3, -0.15, 40.0, 30.0, 0.0 }, --Left
		{ -0.30, 2.3, -0.15, 40.0, -30.0, 0.0 }, --Right
	},
	[`postlude`] = {
		{ 0.60, -0.35, 0.20, 40.0, 10.0, 0.0 }, --Left
		{ -0.60, -0.35, 0.20, 40.0, -10.0, 0.0 }, --Right
	},
	[`sentinel4`] = {
		{ 0.50, -0.55, 0.20, 40.0, 10.0, 0.0 }, --Left
		{ -0.50, -0.55, 0.20, 40.0, -10.0, 0.0 }, --Right
	},
	[`sm722`] = {
		{ 0.50, -0.55, 0.15, 40.0, 30.0, 0.0 }, --Left
		{ -0.50, -0.55, 0.15, 40.0, -30.0, 0.0 }, --Right
	},
	[`tenf2`] = {
		{ 0.30, -0.80, 0.15, 40.0, 30.0, 0.0 }, --Left
		{ -0.30, -0.80, 0.15, 40.0, -30.0, 0.0 }, --Right
	},
	[`torero2`] = {
		{ 0.30, -0.80, 0.15, 40.0, 30.0, 0.0 }, --Left
		{ -0.30, -0.80, 0.15, 40.0, -30.0, 0.0 }, --Right
	},
	[`weevil2`] = {
		{ 0.50, -0.25, 0.20, 40.0, 40.0, 0.0 }, --Left
		{ -0.50, -0.25, 0.20, 40.0, -40.0, 0.0 }, --Right
	},
}