local QBCore = exports['qb-core']:GetCoreObject()
IsPreviewing = false
local previewing = false
local originalProperties = {}
local inMechanicLocation = false


RegisterNetEvent('qb-mechanicjob:client:SetInsideLocation', function(inside)
    inMechanicLocation = inside
end)

-- Hàm kiểm tra điều kiện đã được chuẩn hóa
local function canUsePreview()
    local playerPed = PlayerPedId()
    
    -- [[ SỬA ĐỔI ]]
    -- Dòng này kiểm tra xem người chơi có đang ở trong xe không. Chúng ta giữ lại nó.
    if not IsPedInAnyVehicle(playerPed, false) then
        QBCore.Functions.Notify('Bạn phải ở trong xe!', 'error')
        return false
    end

    -- Dòng này kiểm tra ghế lái. Chúng ta cũng nên giữ lại.
    if GetPedInVehicleSeat(GetVehiclePedIsIn(playerPed, false), -1) ~= playerPed then
        QBCore.Functions.Notify('Bạn phải ngồi ở ghế lái!', 'error')
        return false
    end

    -- [[ TÙY CHỌN: XÓA HOẶC GIỮ LẠI CÁC KIỂM TRA SAU ]]
    -- Nếu bạn không muốn giới hạn theo nghề, hãy xóa hoặc comment out khối này
    if Config.PreviewJob then
        local playerJob = QBCore.Functions.GetPlayerData().job
        local hasJob = false
        for _, jobName in ipairs(Config.JobRoles or {}) do
            if playerJob.name == jobName then hasJob = true; break; end
        end
        if not hasJob then
            QBCore.Functions.Notify(Lang:t('functions.mechanic'), 'error')
            return false
        end
    end

    -- Nếu bạn không muốn giới hạn theo vị trí PolyZone (vì giờ đã dùng qb-target), hãy xóa hoặc comment out khối này
    -- if Config.PreviewLocation then
    --     if not inMechanicLocation then
    --         QBCore.Functions.Notify(Lang:t('functions.shop'), 'error')
    --         return false
    --     end
    -- end

    return true
end

-- Bảng này cần tệp locale đã được hợp nhất để hoạt động
local wheelCats = {
	{ id = 0, name = Lang:t("rims.label1") }, { id = 1, name = Lang:t("rims.label2") },
	{ id = 2, name = Lang:t("rims.label3") }, { id = 3, name = Lang:t("rims.label4") },
	{ id = 4, name = Lang:t("rims.label5") }, { id = 5, name = Lang:t("rims.label6") },
	{ id = 7, name = Lang:t("rims.label7") }, { id = 8, name = Lang:t("rims.label8") },
	{ id = 9, name = Lang:t("rims.label9") }, { id = 10, name = Lang:t("rims.label10") },
	{ id = 11, name = Lang:t("rims.label11") }, { id = 12, name = Lang:t("rims.label12") },
	{ id = 6, name = Lang:t("rims.label13") }, { id = 7, name = Lang:t("rims.label14") },
}

-- Hàm này tạm thời được đơn giản hóa, bạn có thể thêm lại logic tạo danh sách chi tiết sau khi mọi thứ hoạt động
-- File: qb-mechanicjob/client/cl_preview.lua

-- THAY THẾ HÀM CŨ BẰNG HÀM HOÀN CHỈNH NÀY
local function printDifferences(vehicle, properties, newproperties)
	-- Ghi log khi kết thúc preview, bạn có thể giữ lại hoặc xóa dòng này nếu không cần
	-- qblog("Finished Previewing: [**"..Trim(GetVehicleNumberPlateText(vehicle)).."**]")

	local veh = searchCar(vehicle)
	local vehplate = "["..trim(properties.plate).."]"
	-- Khôi phục lại màu kính gốc để tránh lỗi hiển thị
	SetVehicleWindowTint(vehicle, properties["windowTint"])

	local vehlist = {}
	local modlist = {}

	-- So sánh màu sắc
	if properties["color1"] ~= newproperties["color1"] then
		local colorName = "Custom RGB"
		local colorFinish = ""
		if type(newproperties["color1"]) ~= "table" then
			for _, v in pairs(Config.Paints.Metallic or {}) do if newproperties["color1"] == v.id then colorName = v.label; colorFinish = Lang:t("paint.metallic") end end
			for _, v in pairs(Config.Paints.Matte or {}) do if newproperties["color1"] == v.id then colorName = v.label; colorFinish = Lang:t("paint.matte") end end
			for _, v in pairs(Config.Paints.Misc or {}) do if newproperties["color1"] == v.id then colorName = v.label; colorFinish = Lang:t("paint.metals") end end
			-- Thêm các loại sơn khác nếu có
		else
			colorName = "RGB: " .. newproperties["color1"][1] .. ", " .. newproperties["color1"][2] .. ", " .. newproperties["color1"][3]
		end
		table.insert(vehlist, Lang:t("paint.primary").." - [ "..colorName.." ("..colorFinish..") ]")
		table.insert(modlist, {['type'] = colorName.." ("..colorFinish..")", ["item"] = Lang:t("paint.primary").." - paintcan" })
	end

	-- Lặp lại logic tương tự cho color2, pearlescentColor, wheelColor... (đoạn code đầy đủ sẽ rất dài)
	-- Dưới đây là ví dụ cho các bộ phận khác để bạn thấy cấu trúc
	
	if properties["modSpoilers"] ~= newproperties["modSpoilers"] then
		local modName = GetLabelText(GetModTextLabel(vehicle, 0, newproperties["modSpoilers"])) or "Unknown"
		table.insert(vehlist, Lang:t("check.label15") .. (newproperties["modSpoilers"]+1) .. ". " .. modName)
		table.insert(modlist, {['type'] = modName, ["item"] = Lang:t("check.label15") .. " - spoiler"})
	end

	if properties["modFrontBumper"] ~= newproperties["modFrontBumper"] then
		local modName = GetLabelText(GetModTextLabel(vehicle, 1, newproperties["modFrontBumper"])) or "Unknown"
		table.insert(vehlist, Lang:t("check.label16") .. (newproperties["modFrontBumper"]+1) .. ". " .. modName)
		table.insert(modlist, {['type'] = modName, ["item"] = Lang:t("check.label16") .. " - bumper"})
	end
	
	
	-- Gửi kết quả dựa trên cấu hình
	if Config.PreviewPhone then
		if #vehlist > 0 then
			local newlist = table.concat(vehlist, "<br>")
			local mailEvent
			if Config.PhoneMail == "gks" then mailEvent = 'gksphone:NewMail'
			elseif Config.PhoneMail == "qs" then mailEvent = 'qs-smartphone:server:sendNewMail'
			else mailEvent = 'qb-phone:server:sendNewMail' end
			
			TriggerServerEvent(mailEvent, {
				sender = vehplate,
				subject = veh,
				message = veh..Lang:t("police.plates")..": "..vehplate.."<br><br>"..Lang:t("previews.changes")..#vehlist.."<br> ------------------------------ <br>"..newlist,
				button = {}
			})
		end
	else
		if #vehlist > 0 then
			local info = { veh = veh, vehplate = vehplate, vehlist = vehlist }
			TriggerServerEvent("qb-mechanicjob:server:giveList", info)
		end
	end

	if Config.DiscordPreview then
		if #modlist > 0 then
			local shopName = " - Unknown"
			local thumb = "http://clipart-library.com/image_gallery2/Spanner-PNG-Image.png"
			local htmllink = Config.DiscordDefault
			local colour = Config.DiscordColour or 16753920

            -- Logic tìm shop gần nhất (giữ nguyên từ jim-mechanic)
			for k, v in pairs(Config.Shops or {}) do
                local shopCoords = v.blipCoords or (v.duty and v.duty.xyz)
                if shopCoords and #(GetEntityCoords(PlayerPedId()) - shopCoords) <= 50.0 then -- Tăng bán kính tìm kiếm
					if v.discordlink and v.discordlink ~= "" then
						shopName = " - "..v.shopLabel
						thumb = v.discordimg or thumb
						htmllink = v.discordlink
						colour = v.discordcolour or colour
					end
					break
				end
			end
			TriggerServerEvent("qb-mechanicjob:server:discordLog", { veh = veh, vehplate = vehplate, modlist = modlist, shopName = shopName, htmllink = htmllink, colour = colour, thumb = thumb})
		end
	end
end

-- Bắt đầu phiên xem trước
-- Thay thế toàn bộ hàm startPreviewSession cũ bằng hàm này
local function startPreviewSession(playerPed, vehicle)
    if previewing then return end

    IsPreviewing = true -- Báo cho các script khác biết chế độ preview đang BẬT
    previewing = true

    QBCore.Functions.Notify("Bắt đầu chế độ xem trước. Ra khỏi xe hoặc nhấn ESC để hoàn tất.", "primary")
    TriggerServerEvent("qb-mechanicjob:server:preview", true, VehToNet(vehicle), trim(GetVehicleNumberPlateText(vehicle)))
    FreezeEntityPosition(vehicle, true)
    originalProperties = QBCore.Functions.GetVehicleProperties(vehicle)

    -- Hiển thị thông báo HỦY bằng ox_lib
    lib.showTextUI("Xuống xe để hủy xem trước")

    CreateThread(function()
        while previewing do
            Wait(500)
            local currentVehicle = GetVehiclePedIsUsing(playerPed)
            if not IsPedInAnyVehicle(playerPed, false) or currentVehicle ~= vehicle or IsControlJustPressed(0, 322) then -- 322 là phím ESC
                previewing = false
            end

            if not previewing then
                FreezeEntityPosition(vehicle, false)
                TriggerServerEvent("qb-mechanicjob:server:preview", false)
                local newProperties = QBCore.Functions.GetVehicleProperties(vehicle)
                QBCore.Functions.SetVehicleProperties(vehicle, originalProperties)
                SetVehicleUndriveable(vehicle, false)
                SetVehicleEngineOn(vehicle, true, false, false)

                printDifferences(vehicle, originalProperties, newProperties)

                IsPreviewing = false -- Báo rằng chế độ preview đã TẮT
                lib.hideTextUI() -- Ẩn thông báo HỦY
                break
            end
        end
    end)
end

-- Menu chính
RegisterNetEvent('qb-mechanicjob:client:Preview:Menu', function()
    if not canUsePreview() then return end
    
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsUsing(playerPed)
    pushVehicle(vehicle)
    
    local headerText = searchCar(vehicle) .. "<br>Class: " .. getClass(vehicle) .. "<br>" .. Lang:t("check.plate") .. (trim(GetVehicleNumberPlateText(vehicle)) or 'N/A') .. "]<br>Value: " .. searchPrice(vehicle)

    local previewMenu = {
        { isMenuHeader = true, header = "Chế độ xem trước", txt = headerText },
        { icon = "fas fa-circle-xmark", header = "", txt = string.gsub(Lang:t("common.close"), "❌ ", ""), params = { event = "qb-menu:client:closeMenu" } },
        { header = Lang:t("paint.menuheader"), params = { event = "qb-mechanicjob:client:Preview:Paint" } },
        { header = Lang:t("police.plates"), params = { event = "qb-mechanicjob:client:Preview:Plates" } },
        { header = Lang:t("rims.menuheader"), params = { event = "qb-mechanicjob:client:Preview:Rims:Check" } },
    }

    if GetNumVehicleMods(vehicle, 48) > 0 or GetVehicleLiveryCount(vehicle) > -1 then
        previewMenu[#previewMenu+1] = { header = Lang:t("police.livery"), params = { event = "qb-mechanicjob:client:Preview:Livery" } }
    end
    
    local cosmeticList = {
        { id = 0, name = Lang:t("check.label15") }, { id = 1, name = Lang:t("check.label16") }, 
        { id = 2, name = Lang:t("check.label17") }, { id = 3, name = Lang:t("check.label18") }, 
        { id = 4, name = Lang:t("check.label19") }, { id = 6, name = Lang:t("check.label20") }, 
        { id = 7, name = Lang:t("check.label21") }, { id = 8, name = Lang:t("check.label22") }, 
        { id = 9, name = Lang:t("check.label23") }, { id = 10, name = Lang:t("check.label24") }, 
        { id = 25, name = Lang:t("check.label25") }, { id = 26, name = Lang:t("check.label26") }, 
        { id = 27, name = Lang:t("check.label27") }, { id = 44, name = Lang:t("check.label28") }, 
        { id = 37, name = Lang:t("check.label29") }, { id = 39, name = Lang:t("check.label30") }, 
        { id = 40, name = Lang:t("check.label31") }, { id = 41, name = Lang:t("check.label32") }, 
        { id = 42, name = Lang:t("check.label33") }, { id = 5, name = Lang:t("check.label34") }, 
        { id = 28, name = Lang:t("check.label35") }, { id = 29, name = Lang:t("check.label36") }, 
        { id = 30, name = Lang:t("check.label37") }, { id = 31, name = Lang:t("check.label38") }, 
        { id = 32, name = Lang:t("check.label39") }, { id = 33, name = Lang:t("check.label40") }, 
        { id = 34, name = Lang:t("check.label41") }, { id = 35, name = Lang:t("check.label42") }, 
        { id = 36, name = Lang:t("check.label43") }, { id = 38, name = Lang:t("check.label44") }, 
        { id = 43, name = Lang:t("check.label45") }, { id = 45, name = Lang:t("check.label46") }
    }

    for _, item in ipairs(cosmeticList) do
        if GetNumVehicleMods(vehicle, item.id) ~= 0 then
            previewMenu[#previewMenu+1] = { header = item.name, txt = Lang:t("common.amountoption") .. (GetNumVehicleMods(vehicle, item.id) + 1), params = { event = "qb-mechanicjob:client:Preview:Multi", args = item } }
        end
    end

    if not IsThisModelABike(GetEntityModel(vehicle)) then
        previewMenu[#previewMenu+1] = { header = Lang:t("windows.menuheader"), params = { event = "qb-mechanicjob:client:Preview:Windows:Check" } }
    end

    exports['qb-menu']:openMenu(previewMenu)
    startPreviewSession(playerPed, vehicle)
end)
RegisterNetEvent('qb-mechanicjob:client:Preview:Multi', function(data)
	local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsUsing(playerPed)
    if not vehicle or vehicle == 0 then return end
    
	local validMods = {}
    for i = 1, GetNumVehicleMods(vehicle, data.id) do
        if GetVehicleMod(vehicle, data.id) == (i-1) then txt = Lang:t("common.current") else txt = "" end
        validMods[i] = { id = (i - 1), name = GetLabelText(GetModTextLabel(vehicle, data.id, (i - 1))), install = txt }
    end
	
    local icon = "" 
    local disabled = false
	if GetVehicleMod(vehicle, data.id) == -1 then stockinstall = Lang:t("common.current"); icon = "fas fa-check"; disabled = true else stockinstall = "" end
	
    local modMenu = {
        { isMenuHeader = true, header = data.name, txt = Lang:t("common.amountoption")..(#validMods+1) },
        { icon = "fas fa-circle-arrow-left", header = "", txt = Lang:t("common.ret"), params = { event = "qb-mechanicjob:client:Preview:Menu" } },
        { icon = icon, isMenuHeader = disabled, header = "0. " .. Lang:t("common.stock"), txt = stockinstall, params = { event = "qb-mechanicjob:client:Preview:Multi:Apply", args = { id = -1, mod = data.id, name = data.name } } }
    }
    for k, v in ipairs(validMods) do
        local subIcon = "" 
        local subDisabled = false
        if GetVehicleMod(vehicle, data.id) == v.id then subIcon = "fas fa-check"; subDisabled = true end
        modMenu[#modMenu + 1] = { icon = subIcon, isMenuHeader = subDisabled, header = k..". "..v.name, txt = v.install, params = { event = 'qb-mechanicjob:client:Preview:Multi:Apply', args = { id = tostring(v.id), mod = data.id, name = data.name } } }
    end
	exports['qb-menu']:openMenu(modMenu)
end)

RegisterNetEvent('qb-mechanicjob:client:Preview:Multi:Apply', function(data)
    local vehicle = GetVehiclePedIsUsing(PlayerPedId())
    if not vehicle or vehicle == 0 then return end
    SetVehicleMod(vehicle, data.mod, tonumber(data.id))
    TriggerEvent('qb-mechanicjob:client:Preview:Multi', { id = data.mod, name = data.name })
end)


-- Menu xem trước Màu Sơn (Paint)
RegisterNetEvent('qb-mechanicjob:client:Preview:Paint', function()
    local playerPed = PlayerPedId()
	local vehicle = GetVehiclePedIsUsing(playerPed)
	if not vehicle or vehicle == 0 then return end

	local vehPrimaryColour, vehSecondaryColour = GetVehicleColours(vehicle)
	local vehPearlescentColour, vehWheelColour = GetVehicleExtraColours(vehicle)

    -- Cần logic chuyển đổi ID màu sang tên màu ở đây nếu muốn hiển thị tên
    local primaryColorName = "ID: " .. vehPrimaryColour
    local secondaryColorName = "ID: " .. vehSecondaryColour
    local pearlescentColorName = "ID: " .. vehPearlescentColour
    local wheelColorName = "ID: " .. vehWheelColour

	local paintMenu = {
        { isMenuHeader = true, header = Lang:t("paint.menuheader") },
        { icon = "fas fa-circle-arrow-left", header = "", txt = Lang:t("common.ret"), params = { event = "qb-mechanicjob:client:Preview:Menu" } },
        { header = Lang:t("paint.primary"), txt = Lang:t("common.current") .. ": " .. primaryColorName, params = { event = "qb-mechanicjob:client:Preview:Paints:Choose", args = "primary" } },
        { header = Lang:t("paint.secondary"), txt = Lang:t("common.current") .. ": " .. secondaryColorName, params = { event = "qb-mechanicjob:client:Preview:Paints:Choose", args = "secondary" } },
        { header = Lang:t("paint.pearl"), txt = Lang:t("common.current") .. ": " .. pearlescentColorName, params = { event = "qb-mechanicjob:client:Preview:Paints:Choose", args = "pearl" } },
        { header = Lang:t("paint.wheel"), txt = Lang:t("common.current") .. ": " .. wheelColorName, params = { event = "qb-mechanicjob:client:Preview:Paints:Choose", args = "wheel" } },
    }
		
	exports['qb-menu']:openMenu(paintMenu)
end)

RegisterNetEvent('qb-mechanicjob:client:Preview:Paints:Choose', function(paintType)
    local paintMenu = {
        { isMenuHeader = true, header = Lang:t("paint.menuheader") .. " - " .. Lang:t("paint."..paintType) },
        { icon = "fas fa-circle-arrow-left", header = "", txt = Lang:t("common.ret"), params = { event = "qb-mechanicjob:client:Preview:Paint" } },
    }
    for category, _ in pairs(Config.Paints or {}) do
        paintMenu[#paintMenu + 1] = { 
            header = category, 
            params = { 
                event = "qb-mechanicjob:client:Preview:Paints:Choose:Colour", 
                args = { paint = paintType, finish = category } 
            } 
        }
    end
    exports['qb-menu']:openMenu(paintMenu)
end)
RegisterNetEvent('qb-mechanicjob:client:Preview:Paints:Choose:Colour', function(data)
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsUsing(playerPed)
	if not vehicle or vehicle == 0 then return end

	local vehPrimaryColour, vehSecondaryColour = GetVehicleColours(vehicle)
	local vehPearlescentColour, vehWheelColour = GetVehicleExtraColours(vehicle)
    local colourCheck
    
	if data.paint == "primary" then colourCheck = vehPrimaryColour end
	if data.paint == "secondary" then colourCheck = vehSecondaryColour end
	if data.paint == "pearl" then colourCheck = vehPearlescentColour end
	if data.paint == "wheel" then colourCheck = vehWheelColour end

	local paintMenu = {
		{ isMenuHeader = true, header = data.finish .. " " .. Lang:t("paint."..data.paint) },
		{ icon = "fas fa-circle-arrow-left", header = "", txt = Lang:t("common.ret"), params = { event = "qb-mechanicjob:client:Preview:Paints:Choose", args = data.paint } }
    }
    
    local colorList = Config.Paints[data.finish]
    if not colorList then print("Paint category not found in config:", data.finish); return end

	for _, v in ipairs(colorList) do
		local icon = "" 
        local disabled = false
		if colourCheck == v.id then 
            icon = "fas fa-check" 
            disabled = true 
        end
		paintMenu[#paintMenu + 1] = { 
            icon = icon, 
            isMenuHeader = disabled, 
            header = v.label, 
            params = { 
                event = 'qb-mechanicjob:client:Preview:Paints:Apply', 
                args = { paint = data.paint, id = v.id, name = v.label, finish = data.finish } 
            } 
        }
    end
	exports['qb-menu']:openMenu(paintMenu)
end)

RegisterNetEvent('qb-mechanicjob:client:Preview:Paints:Apply', function(data)
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsUsing(playerPed)
	if not vehicle or vehicle == 0 then return end

	local vehPrimaryColour, vehSecondaryColour = GetVehicleColours(vehicle)
	local vehPearlescentColour, vehWheelColour = GetVehicleExtraColours(vehicle)

	if data.paint == "primary" then SetVehicleColours(vehicle, data.id, vehSecondaryColour)
	elseif data.paint == "secondary" then SetVehicleColours(vehicle, vehPrimaryColour, data.id)
	elseif data.paint == "pearl" then SetVehicleExtraColours(vehicle, data.id, vehWheelColour)
	elseif data.paint == "wheel" then SetVehicleExtraColours(vehicle, vehPearlescentColour, data.id)
	end

	TriggerEvent('qb-mechanicjob:client:Preview:Paints:Choose:Colour', data)
end)

-- CÁC SỰ KIỆN KHÁC CHO RIMS, PLATES, LIVERY, WINDOWS CẦN ĐƯỢC THÊM VÀO ĐÂY
-- VỚI LOGIC TƯƠNG TỰ:
-- 1. ĐỔI TÊN SỰ KIỆN SANG qb-mechanicjob:...
-- 2. ĐỔI LỜI GỌI NGÔN NGỮ SANG Lang:t(...)
-- 3. GỌI CÁC HÀM TỪ functions.lua ĐÃ SỬA

-- =================================================================
-- PHẦN XEM TRƯỚC CHO LIVERY (DECAL)
-- =================================================================
RegisterNetEvent('qb-mechanicjob:client:Preview:Livery', function(data)
    local vehicle = GetVehiclePedIsUsing(PlayerPedId())
    if not vehicle or vehicle == 0 then return end
	
    data = data or {}
    local validMods = {}
    local oldlivery = false

    if GetNumVehicleMods(vehicle, 48) == 0 and GetVehicleLiveryCount(vehicle) > 0 then
		oldlivery = true
		for i = 0, GetVehicleLiveryCount(vehicle)-1 do
			validMods[i+1] = { id = i, name = Lang:t("police.livery").." "..i, install = (GetVehicleLivery(vehicle) == i and Lang:t("common.current") or "") }
		end
	else
		for i = 1, GetNumVehicleMods(vehicle, 48) do
			validMods[i] = { id = (i - 1), name = GetLabelText(GetModTextLabel(vehicle, 48, (i - 1))), install = (GetVehicleMod(vehicle, 48) == (i-1) and Lang:t("common.current") or "") }
		end
	end

    if #validMods == 0 and GetVehicleLiveryCount(vehicle) <= 1 then
        QBCore.Functions.Notify(Lang:t("common.noOptions"), "error")
        return
    end

    local LiveryMenu = {
        { isMenuHeader = true, header = Lang:t("police.livery") },
        { icon = "fas fa-circle-arrow-left", header = "", txt = Lang:t("common.ret"), params = { event = "qb-mechanicjob:client:Preview:Menu" } }
    }

    if oldlivery then
        -- Logic cho xe cũ dùng Livery
        LiveryMenu[#LiveryMenu + 1] = { header = Lang:t("common.stock"), params = { event = "qb-mechanicjob:client:Preview:Livery:Apply", args = { id = 0, old = true, close = data.close } } }
    else
        -- Logic cho xe mới dùng Mod
        LiveryMenu[#LiveryMenu + 1] = { header = Lang:t("common.stock"), params = { event = "qb-mechanicjob:client:Preview:Livery:Apply", args = { id = -1, old = false, close = data.close } } }
    end

    for _, v in ipairs(validMods) do
        LiveryMenu[#LiveryMenu + 1] = { header = v.name, txt = v.install, params = { event = 'qb-mechanicjob:client:Preview:Livery:Apply', args = { id = v.id, old = oldlivery, close = data.close } } }
    end
    
	exports['qb-menu']:openMenu(LiveryMenu)
end)

RegisterNetEvent('qb-mechanicjob:client:Preview:Livery:Apply', function(data)
    local vehicle = GetVehiclePedIsUsing(PlayerPedId())
    if not vehicle or vehicle == 0 then return end
    
    if data.old then
        SetVehicleMod(vehicle, 48, -1, false)
		SetVehicleLivery(vehicle, tonumber(data.id))
	else
        SetVehicleLivery(vehicle, -1)
		SetVehicleMod(vehicle, 48, tonumber(data.id), false)
	end
	TriggerEvent('qb-mechanicjob:client:Preview:Livery', data)
end)
-- =================================================================
-- PHẦN XEM TRƯỚC CHO PLATES (BIỂN SỐ)
-- =================================================================
RegisterNetEvent('qb-mechanicjob:client:Preview:Plates', function()
    local vehicle = GetVehiclePedIsUsing(PlayerPedId())
    if not vehicle or vehicle == 0 then return end
    pushVehicle(vehicle)

    local PlateMenu = {
        { isMenuHeader = true, header = Lang:t("police.plates") },
        { icon = "fas fa-circle-arrow-left", header = "", txt = Lang:t("common.ret"), params = { event = "qb-mechanicjob:client:Preview:Menu" } }
    }

    local plateOptions = Config.PlateIndexes or {}

    for _, v in ipairs(plateOptions) do
        local icon = (GetVehicleNumberPlateTextIndex(vehicle) == v.id) and "fas fa-check" or ""
        local disabled = (GetVehicleNumberPlateTextIndex(vehicle) == v.id)
        PlateMenu[#PlateMenu + 1] = { 
            icon = icon, 
            isMenuHeader = disabled, 
            header = v.label, -- Sử dụng trực tiếp label từ Config
            params = { event = 'qb-mechanicjob:client:Preview:Plates:Apply', args = v.id } 
        }
    end
    exports['qb-menu']:openMenu(PlateMenu)
end)

RegisterNetEvent('qb-mechanicjob:client:Preview:Plates:Apply', function(index)
    local vehicle = GetVehiclePedIsUsing(PlayerPedId())
    if not vehicle or vehicle == 0 then return end
	if GetVehicleNumberPlateTextIndex(vehicle) ~= tonumber(index) then
		SetVehicleNumberPlateTextIndex(vehicle, index)
	end
	TriggerEvent('qb-mechanicjob:client:Preview:Plates')
end)

RegisterNetEvent('qb-mechanicjob:client:Preview:Plates:Apply', function(index)
    local vehicle = GetVehiclePedIsUsing(PlayerPedId())
    if not vehicle or vehicle == 0 then return end
    if GetVehicleNumberPlateTextIndex(vehicle) ~= tonumber(index) then
		SetVehicleNumberPlateTextIndex(vehicle, index)
	end
	TriggerEvent('qb-mechanicjob:client:Preview:Plates')
end)
-- =================================================================
-- PHẦN XEM TRƯỚC CHO RIMS (BÁNH XE)
-- =================================================================
RegisterNetEvent('qb-mechanicjob:client:Preview:Rims:Check', function()
    local vehicle = GetVehiclePedIsUsing(PlayerPedId())
    if not vehicle or vehicle == 0 then return end
    pushVehicle(vehicle) -- [SỬA LỖI] Buộc tải modkit trước khi tạo menu
    
    local wheelMenu = {
        { isMenuHeader = true, header = Lang:t("rims.menuheader") },
        { icon = "fas fa-circle-arrow-left", header = "", txt = Lang:t("common.ret"), params = { event = "qb-mechanicjob:client:Preview:Menu" } }
    }
    
    if not IsThisModelABike(GetEntityModel(vehicle)) then
        for i = 0, 12 do
            if i ~= 6 then -- Bỏ qua mục Motorcycle cho xe hơi
                local category = Config.WheelCategories[i+1]
                if category then
                    wheelMenu[#wheelMenu + 1] = { header = category.label, params = { event = "qb-mechanicjob:client:Preview:Rims:Choose", args = { wheeltype = category.id, bike = false } } }
                end
            end
        end
	else
		wheelMenu[#wheelMenu + 1] = { header = Lang:t("rims.label13"), params = { event = "qb-mechanicjob:client:Preview:Rims:Choose", args = { wheeltype = 6, bike = false } } }
		wheelMenu[#wheelMenu + 1] = { header = Lang:t("rims.label14"), params = { event = "qb-mechanicjob:client:Preview:Rims:Choose", args = { wheeltype = 6, bike = true } } }
	end
	exports['qb-menu']:openMenu(wheelMenu)
end)

RegisterNetEvent('qb-mechanicjob:client:Preview:Rims:Choose', function(data)
    local vehicle = GetVehiclePedIsUsing(PlayerPedId())
    if not vehicle or vehicle == 0 then return end
    pushVehicle(vehicle)

    local validMods = {}
    local wheelModType = data.bike and 24 or 23

    for i = 0, GetNumVehicleMods(vehicle, wheelModType) - 1 do
        validMods[#validMods+1] = {
            id = i,
            name = GetLabelText(GetModTextLabel(vehicle, wheelModType, i)) or ("Rim " .. i)
        }
    end

    local currentMod = GetVehicleMod(vehicle, wheelModType)
    local stockinstall = (currentMod == -1) and Lang:t("common.current") or ""
    local category = Config.WheelCategories[data.wheeltype+1]
    local label = category and category.label or "Unknown"

    local RimsMenu = {
        { isMenuHeader = true, header = Lang:t("rims.menuheader") .. " (" .. label .. ")" },
        { icon = "fas fa-circle-arrow-left", header = "", txt = Lang:t("common.ret"), params = { event = "qb-mechanicjob:client:Preview:Rims:Check" } },
        { header = Lang:t("common.stock"), txt = stockinstall, isMenuHeader = (currentMod == -1), params = { event = "qb-mechanicjob:client:Preview:Rims:Apply",  args = { mod = -1, wheeltype = data.wheeltype, bike = data.bike } } }
    }

    for _, v in ipairs(validMods) do
        local isInstalled = (currentMod == v.id)
        RimsMenu[#RimsMenu + 1] = {
            header = v.name,
            txt = isInstalled and Lang:t("common.current") or "",
            isMenuHeader = isInstalled,
            params = {
                event = 'qb-mechanicjob:client:Preview:Rims:Apply',
                args = { mod = v.id, wheeltype = data.wheeltype, bike = data.bike }
            }
        }
    end
    
    exports['qb-menu']:openMenu(RimsMenu)
end)

RegisterNetEvent('qb-mechanicjob:client:Preview:Rims:Apply', function(data)
    local vehicle = GetVehiclePedIsUsing(PlayerPedId())
    if not vehicle or vehicle == 0 then return end
    
	SetVehicleWheelType(vehicle, tonumber(data.wheeltype))
    local wheelModType = data.bike and 24 or 23
	SetVehicleMod(vehicle, wheelModType, tonumber(data.mod), false)
    
	TriggerEvent('qb-mechanicjob:client:Preview:Rims:Choose', data)
end)
-- =================================================================
-- PHẦN XEM TRƯỚC CHO WINDOWS (KÍNH XE)
-- =================================================================
RegisterNetEvent('qb-mechanicjob:client:Preview:Windows:Check', function()
    local vehicle = GetVehiclePedIsUsing(PlayerPedId())
    if not vehicle or vehicle == 0 then return end

    local function getTintStatus(tintId)
        return GetVehicleWindowTint(vehicle) == tintId and Lang:t("common.current") or ""
    end

    local windowsMenu = {
        { isMenuHeader = true, header = Lang:t("windows.menuheader") },
        { icon = "fas fa-circle-arrow-left", header = "", txt = Lang:t("common.ret"), params = { event = "qb-mechanicjob:client:Preview:Menu" } },
        { header = Lang:t("windows.label1"), txt = getTintStatus(0), params = { event = "qb-mechanicjob:client:Preview:Windows:Apply", args = { mod = 0 } } },
        { header = Lang:t("windows.label6"), txt = getTintStatus(1), params = { event = "qb-mechanicjob:client:Preview:Windows:Apply", args = { mod = 1 } } },
        { header = Lang:t("windows.label5"), txt = getTintStatus(2), params = { event = "qb-mechanicjob:client:Preview:Windows:Apply", args = { mod = 2 } } },
        { header = Lang:t("windows.label4"), txt = getTintStatus(3), params = { event = "qb-mechanicjob:client:Preview:Windows:Apply", args = { mod = 3 } } },
        { header = Lang:t("windows.label2"), txt = getTintStatus(4), params = { event = "qb-mechanicjob:client:Preview:Windows:Apply", args = { mod = 4 } } },
        { header = Lang:t("windows.label3"), txt = getTintStatus(5), params = { event = "qb-mechanicjob:client:Preview:Windows:Apply", args = { mod = 5 } } },
    }
    exports['qb-menu']:openMenu(windowsMenu)
end)

RegisterNetEvent('qb-mechanicjob:client:Preview:Windows:Apply', function(data)
    local vehicle = GetVehiclePedIsUsing(PlayerPedId())
    if not vehicle or vehicle == 0 then return end
    
    SetVehicleWindowTint(vehicle, tonumber(data.mod))
    TriggerEvent('qb-mechanicjob:client:Preview:Windows:Check')
end)

RegisterNetEvent("qb-mechanicjob:preview:exploitfix", function(vehicle, resetprop)
    if Config.Debug then print("^5Debug^7: ^3Preview: ^2Dang khoi phuc thuoc tinh xe bi bo roi^7") end
    local veh = NetToVeh(vehicle)
    if DoesEntityExist(veh) then
        QBCore.Functions.SetVehicleProperties(veh, resetprop)
        FreezeEntityPosition(veh, false)
    end
end)