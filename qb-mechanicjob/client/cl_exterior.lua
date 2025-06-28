QBCore = exports['qb-core']:GetCoreObject()

-- Hàm tiện ích IsNearBone (Đã được giữ lại và sửa ở đây)
local function IsNearBone(vehicle, boneName, distanceThreshold)
    distanceThreshold = distanceThreshold or 4.0 -- ĐÃ SỬA: Đặt ngưỡng khoảng cách là 4.0 (hoặc 5.0 tùy bạn)

    local boneIndex = GetEntityBoneIndexByName(vehicle, boneName)
    if boneIndex == -1 then
        return false -- Không tìm thấy xương (bone)
    end

    local boneCoords = GetWorldPositionOfEntityBone(vehicle, boneIndex)
    local playerCoords = GetEntityCoords(PlayerPedId())

    return #(playerCoords - boneCoords) < distanceThreshold
end

--> THÊM DÒNG NÀY: print('cl_exterior.lua loaded successfully')

-- ===============================================
-- Hàm chính cho EXTERIOR (ĐÃ SỬA LỖI TRÙNG LẶP)
-- ===============================================
local function OpenExteriors(vehicle)
    --> THÊM DÒNG NÀY: print('OpenExteriors called')
    local mods = { { header = Lang:t('menu.exterior'), isMenuHeader = true, icon = 'fas fa-car-side' } }

    for i = 1, #Config.ExteriorCategories do
        local category = Config.ExteriorCategories[i]
        local modCount = GetNumVehicleMods(vehicle, category.id)
        
        if modCount > 0 or (category.id == 20 or category.id == 22 or category.id == 25 or category.id == 26 or category.id == 46 or category.id == 48) then
            local header = category.label
            local actionEvent = nil
            local args = {}

            if category.id == 0 then -- Spoiler
                actionEvent = function() OpenSpoilers(vehicle, false) end
            elseif category.id == 1 then -- Front Bumper
                actionEvent = function() OpenFrontBumpers(vehicle, false) end
            elseif category.id == 20 then -- Tire Smoke (được gọi từ OpenWheels)
                actionEvent = function() OpenWheels(vehicle) end
            elseif category.id == 22 then -- Headlights (Xenon)
                actionEvent = function() OpenXenon(vehicle) end
            elseif category.id == 24 then -- Rear Wheels (được bao gồm trong OpenWheels)
                actionEvent = function() OpenWheels(vehicle) end
            elseif category.id == 25 or category.id == 26 then -- Plate Holder / Vanity Plates
                actionEvent = function() PlateIndex(vehicle) end
            elseif category.id == 46 then -- Window (Window Tint)
                actionEvent = function() WindowTint(vehicle) end
            elseif category.id == 48 then -- Livery
                 actionEvent = function() TriggerEvent('qb-mechanicjob:client:Preview:Livery') end
            else
                actionEvent = function() ExteriorModList(category.id, vehicle, category.label) end
            end

            if actionEvent then
                mods[#mods + 1] = {
                    header = header,
                    params = {
                        isAction = true,
                        event = actionEvent,
                        args = args
                    }
                }
            end
        end
    end
    
    exports['qb-menu']:openMenu(mods)
end

-- ===============================================
-- Hàm riêng cho FRONT BUMPER (CẢN TRƯỚC)
-- ===============================================
local function OpenFrontBumpers(vehicle, isDirectCall)
    --> THÊM DÒNG NÀY: print('OpenFrontBumpers called')
    isDirectCall = isDirectCall or false

    -- Kiểm tra vị trí (ví dụ: ở phía trước xe, gần xương cản trước)
    local isAtRear = IsNearBone(vehicle, 'front_bumper') or IsNearBone(vehicle, 'boot') or IsNearBone(vehicle, 'chassis')
    if not IsNearBone(vehicle, 'front_bumper') then
        QBCore.Functions.Notify(Lang:t('functions.near_front'), 'error')
        --> THÊM DÒNG NÀY: print('Not near front bumper, returning false')
        return false
    end
    --> THÊM DÒNG NÀY: print('Near front bumper, opening menu')

    local bumperMenu = { { header = Lang:t('menu.front_bumper'), isMenuHeader = true, icon = 'fas fa-car' } }

    -- Chỉ thêm nút "Back" nếu KHÔNG phải là cuộc gọi trực tiếp từ item
    if not isDirectCall then
        bumperMenu[#bumperMenu + 1] = {
            header = Lang:t('menu.back'),
            icon = 'fas fa-backward',
            params = {
                isAction = true,
                event = function()
                    OpenExteriors(vehicle) -- Quay lại menu ngoại thất chính
                end,
                args = {}
            }
        }
    end

    local modType = 1 -- ModType cho Front Bumper (từ Config.ExteriorCategories)
    local numMods = GetNumVehicleMods(vehicle, modType)

    -- Tùy chọn "Stock" (mặc định)
    bumperMenu[#bumperMenu + 1] = {
        header = "0. " .. Lang:t('menu.stock'),
        params = {
            isAction = true,
            event = function()
                SetVehicleModKit(vehicle, 0)

                QBCore.Functions.Progressbar('installing_bumper', Lang:t('progress.installing_bumper'), 5000, false, true, {
                    disableMovement = true,
                    disableCarMovement = true,
                    disableMouse = false,
                    disableCombat = true,
                }, {
                    animDict = 'mini@repair',
                    anim = 'fixing_a_ped',
                    flags = 1,
                }, {
                    model = 'imp_prop_impexp_span_03',
                    bone = 28422,
                    coords = vec3(0.06, 0.01, -0.02),
                    rotation = vec3(0.0, 0.0, 0.0),
                }, {}, function() -- Callback khi thành công
                    RemoveVehicleMod(vehicle, modType)
                    local props = QBCore.Functions.GetVehicleProperties(vehicle)
                    TriggerServerEvent('qb-mechanicjob:server:SaveVehicleProps', props)
                    QBCore.Functions.Notify(Lang:t('menu.bumper_installed'), 'success')
                    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                    exports['qb-menu']:closeMenu()
                end, function() -- Callback khi bị hủy
                    QBCore.Functions.Notify(Lang:t('progress.install_cancelled'), 'error')
                    ClearPedTasks(PlayerPedId())
                    exports['qb-menu']:closeMenu()
                end)
            end,
            args = {}
        }
    }

    for i = 0, numMods - 1 do
        local modHeader = GetModTextLabel(vehicle, modType, i)
        modHeader = modHeader and GetLabelText(modHeader) or 'Bumper ' .. i

        bumperMenu[#bumperMenu + 1] = {
            header = (i + 1) .. ". " .. modHeader,
            params = {
                isAction = true,
                event = function(data)
                    SetVehicleModKit(vehicle, 0)

                    QBCore.Functions.Progressbar('installing_bumper', Lang:t('progress.installing_bumper'), 5000, false, true, {
                        disableMovement = true,
                        disableCarMovement = true,
                        disableMouse = false,
                        disableCombat = true,
                    }, {
                        animDict = 'mini@repair',
                        anim = 'fixing_a_ped',
                        flags = 1,
                    }, {
                        model = 'imp_prop_impexp_span_03',
                        bone = 28422,
                        coords = vec3(0.06, 0.01, -0.02),
                        rotation = vec3(0.0, 0.0, 0.0),
                    }, {}, function() -- Callback khi thành công
                        SetVehicleMod(vehicle, data.modType, data.modIndex, false)
                        local props = QBCore.Functions.GetVehicleProperties(vehicle)
                        TriggerServerEvent('qb-mechanicjob:server:SaveVehicleProps', props)
                        QBCore.Functions.Notify(Lang:t('menu.bumper_installed'), 'success')
                        PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                        exports['qb-menu']:closeMenu()
                    end, function() -- Callback khi bị hủy
                        QBCore.Functions.Notify(Lang:t('progress.install_cancelled'), 'error')
                        ClearPedTasks(PlayerPedId())
                        exports['qb-menu']:closeMenu()
                    end)
                end,
                args = {
                    modType = modType,
                    modIndex = i
                }
            }
        }
    end
    exports['qb-menu']:openMenu(bumperMenu)
    return true
end

-- Tire Smoke

local function GetSmokeList()
    local smokes = {}
    for i = 1, #Config.TyreSmoke do
        smokes[#smokes + 1] = {
            value = Config.TyreSmoke[i].label,
            text = Config.TyreSmoke[i].label
        }
    end
    return smokes
end

local function GetSmokeColors(color)
    for i = 1, #Config.TyreSmoke do
        if Config.TyreSmoke[i].label == color then
            return Config.TyreSmoke[i].r, Config.TyreSmoke[i].g, Config.TyreSmoke[i].b
        end
    end
end

local function TireSmoke(vehicle)
    local dialog = exports['qb-input']:ShowInput({
        header = Lang:t('menu.tire_smoke'),
        submitText = Lang:t('menu.submit'),
        inputs = {
            {
                text = 'HEX',
                name = 'hex',
                type = 'text',
                isRequired = false
            },
            {
                text = '',
                name = 'colorpicker',
                type = 'color',
                isRequired = false
            },
            {
                text = Lang:t('menu.standard'),
                name = 'color',
                type = 'select',
                options = GetSmokeList()
            },
            {
                text = Lang:t('menu.toggle'),
                name = 'toggle',
                type = 'radio',
                options = {
                    { value = 'togglehex',      text = Lang:t('menu.custom') },
                    { value = 'togglestandard', text = Lang:t('menu.standard') },
                }
            }
        }
    })
    if not dialog then return end

    if dialog.toggle == 'togglehex' and dialog.hex ~= '' then
        -- THAY ĐỔI: Gọi HexToRGB từ hàm toàn cục hoặc từ cosmetic.lua
        -- HexToRGB ở cosmetic.lua không được export, bạn có thể thêm nó vào functions.lua và export từ đó
        local color = exports['qb-mechanicjob']:HexToRGB(dialog.hex) -- Cần đảm bảo HexToRGB được export từ qb-mechanicjob
        ToggleVehicleMod(vehicle, 20, true)
        SetVehicleTyreSmokeColor(vehicle, color.r, color.g, color.b)
    elseif dialog.toggle == 'togglestandard' and dialog.colorpicker ~= '' then
        -- THAY ĐỔI: Gọi HexToRGB từ hàm toàn cục hoặc từ cosmetic.lua
        local color = exports['qb-mechanicjob']:HexToRGB(dialog.colorpicker) -- Cần đảm bảo HexToRGB được export từ qb-mechanicjob
        ToggleVehicleMod(vehicle, 20, true)
        SetVehicleTyreSmokeColor(vehicle, color.r, color.g, color.b)
    elseif dialog.toggle == 'togglestandard' and tonumber(dialog.color) then
        ToggleVehicleMod(vehicle, 20, true)
        SetVehicleTyreSmokeColor(vehicle, GetSmokeColors(dialog.color))
    else
        ToggleVehicleMod(vehicle, 20, false)
    end
end

-- Wheels

local function OpenWheels(vehicle)
    local mods = { { header = Lang:t('menu.wheels'), isMenuHeader = true, icon = 'fas fa-truck-monster' } }
    mods[#mods + 1] = {
        header = Lang:t('menu.tire_smoke'),
        icon = 'fas fa-smog',
        params = {
            isAction = true,
            event = function()
                TireSmoke(vehicle)
            end,
            args = {}
        }
    }
    for i = 1, #Config.WheelCategories do
        mods[#mods + 1] = {
            header = Config.WheelCategories[i].label,
            params = {
                isAction = true,
                event = function()
                    OpenWheelList(Config.WheelCategories[i].id, vehicle, Config.WheelCategories[i].label)
                end,
                args = {}
            }
        }
    end
    exports['qb-menu']:openMenu(mods)
end

function OpenWheelList(id, vehicle, label)
    local mods = { { header = label, isMenuHeader = true, icon = 'fas fa-truck-monster' } }
    mods[#mods + 1] = {
        header = Lang:t('menu.back'),
        icon = 'fas fa-backward',
        params = {
            isAction = true,
            event = function()
                OpenWheels(vehicle)
            end,
            args = {}
        }
    }
    SetVehicleWheelType(vehicle, id)
    for i = 1, GetNumVehicleMods(vehicle, 23) - 1 do
        mods[#mods + 1] = {
            header = GetLabelText(GetModTextLabel(vehicle, 23, i)),
            params = {
                isAction = true,
                event = function()
                    SetVehicleModKit(vehicle, 0)
                    SetVehicleMod(vehicle, 23, i, false)
                    OpenWheelList(id, vehicle, label)
                end,
                args = {}
            }
        }
    end
    exports['qb-menu']:openMenu(mods)
end

-- Neons

local function GetNeonList()
    local neons = {}
    for i = 1, #Config.NeonColors do
        neons[#neons + 1] = {
            value = Config.NeonColors[i].label,
            text = Config.NeonColors[i].label
        }
    end
    return neons
end

local function GetNeonColors(color)
    for i = 1, #Config.NeonColors do
        if Config.NeonColors[i].label == color then
            return Config.NeonColors[i].r, Config.NeonColors[i].g, Config.NeonColors[i].b
        end
    end
end

local function OpenNeon(vehicle)
    local dialog = exports['qb-input']:ShowInput({
        header = Lang:t('menu.neons'),
        submitText = Lang:t('menu.submit'),
        inputs = {
            {
                text = Lang:t('menu.color'),
                name = 'color',
                type = 'select',
                options = GetNeonList()
            },
            {
                text = Lang:t('menu.front_toggle'),
                name = 'frontenable',
                type = 'radio',
                options = {
                    { value = 'enable',  text = Lang:t('menu.enabled') },
                    { value = 'disable', text = Lang:t('menu.disabled') },
                }
            }
        }
    })
    if not dialog then return end

    if dialog.frontenable == 'enable' then
        SetVehicleNeonLightEnabled(vehicle, 2, true)
    else
        SetVehicleNeonLightEnabled(vehicle, 2, false)
    end

    if dialog.rearenable == 'enable' then
        SetVehicleNeonLightEnabled(vehicle, 3, true)
    else
        SetVehicleNeonLightEnabled(vehicle, 3, false)
    end

    if dialog.leftenable == 'enable' then
        SetVehicleNeonLightEnabled(vehicle, 0, true)
    else
        SetVehicleNeonLightEnabled(vehicle, 0, false)
    end

    if dialog.rightenable == 'enable' then
        SetVehicleNeonLightEnabled(vehicle, 1, true)
    else
        SetVehicleNeonLightEnabled(vehicle, 1, false)
    end

    SetVehicleNeonLightsColour(vehicle, GetNeonColors(dialog.color))
end

-- Headlights

local function GetXenonList()
    local xenons = {}
    for i = 1, #Config.Xenon do
        xenons[#xenons + 1] = {
            value = Config.Xenon[i].id,
            text = Config.Xenon[i].label
        }
    end
    return xenons
end

local function OpenXenon(vehicle)
    local dialog = exports['qb-input']:ShowInput({
        header = Lang:t('menu.xenon'),
        submitText = Lang:t('menu.submit'),
        inputs = {
            {
                text = 'HEX',
                name = 'hex',
                type = 'text',
                isRequired = false
            },
            {
                text = '',
                name = 'colorpicker',
                type = 'color',
                isRequired = false
            },
            {
                text = Lang:t('menu.color'),
                name = 'color',
                type = 'select',
                options = GetXenonList()
            },
            {
                text = Lang:t('menu.toggle'),
                name = 'toggle',
                type = 'radio',
                options = {
                    { value = 'enable',  text = Lang:t('menu.enabled') },
                    { value = 'disable', text = Lang:t('menu.disabled') },
                }
            }
        }
    })
    if not dialog then return end

    if dialog.toggle == 'disable' then
        ToggleVehicleMod(vehicle, 22, false)
        return
    end

    if dialog.hex and dialog.hex ~= '' then
        local color = HexToRGB(dialog.hex)
        ToggleVehicleMod(vehicle, 22, true)
        SetVehicleXenonLightsCustomColor(vehicle, color.r, color.g, color.b)
        return
    end

    if dialog.colorpicker and dialog.colorpicker ~= '' then
        local color = HexToRGB(dialog.colorpicker)
        ToggleVehicleMod(vehicle, 22, true)
        SetVehicleXenonLightsCustomColor(vehicle, color.r, color.g, color.b)
        return
    end

    if dialog.color and tonumber(dialog.color) then
        ToggleVehicleMod(vehicle, 22, true)
        SetVehicleXenonLightsColor(vehicle, tonumber(dialog.color))
    end
end

-- Window Tint

local function WindowTint(vehicle)
    local tints = { { header = Lang:t('menu.window_tint'), isMenuHeader = true, icon = 'fas fa-window-maximize' } }
    if GetNumVehicleWindowTints() > 0 then
        for i = 1, #Config.WindowTints do
            tints[#tints + 1] = {
                header = Config.WindowTints[i].label,
                params = {
                    isAction = true,
                    event = function()
                        SetVehicleModKit(vehicle, 0)
                        SetVehicleWindowTint(vehicle, Config.WindowTints[i].id)
                        WindowTint(vehicle)
                    end,
                    args = {}
                }
            }
        end
    end
    exports['qb-menu']:openMenu(tints)
end

-- ===============================================
-- Hàm cho SPOILER
-- ===============================================
local function OpenSpoilers(vehicle, isDirectCall)
    isDirectCall = isDirectCall or false

    -- THÊM KIỂM TRA VỊ TRÍ TẠI ĐÂY
    local isAtRear = IsNearBone(vehicle, 'rear_bumper') or IsNearBone(vehicle, 'boot') or IsNearBone(vehicle, 'chassis')
    if not isAtRear then
      QBCore.Functions.Notify(Lang:t('functions.near_rear'), 'error')
      return false
    end

    local spoilersMenu = { { header = "Cánh gió", isMenuHeader = true, icon = 'fas fa-spoiler' } } -- Đã sửa tiêu đề menu cố định (ví dụ)

    -- Chỉ thêm nút "Back" nếu KHÔNG phải là cuộc gọi trực tiếp từ item
    if not isDirectCall then
        spoilersMenu[#spoilersMenu + 1] = {
            header = Lang:t('menu.back'),
            icon = 'fas fa-backward',
            params = {
                isAction = true,
                event = function()
                    OpenExteriors(vehicle) -- Quay lại menu ngoại thất chính
                end,
                args = {}
            }
        }
    end

    local modType = 0 -- ModType cho Spoiler
    local numMods = GetNumVehicleMods(vehicle, modType)

    -- Tùy chọn "Stock" (mặc định)
    spoilersMenu[#spoilersMenu + 1] = {
        header = "0. " .. Lang:t('menu.stock'),
        params = {
            isAction = true,
            event = function()
                SetVehicleModKit(vehicle, 0)

                QBCore.Functions.Progressbar('installing_spoiler', Lang:t('progress.installing_spoiler'), 5000, false, true, {
                    disableMovement = true,
                    disableCarMovement = true,
                    disableMouse = false,
                    disableCombat = true,
                }, {
                    animDict = 'mini@repair',
                    anim = 'fixing_a_ped',
                    flags = 1,
                }, {
                    model = 'imp_prop_impexp_span_03',
                    bone = 28422,
                    coords = vec3(0.06, 0.01, -0.02),
                    rotation = vec3(0.0, 0.0, 0.0),
                }, {}, function() -- Callback khi thành công
                    RemoveVehicleMod(vehicle, modType)
                    local props = QBCore.Functions.GetVehicleProperties(vehicle)
                    TriggerServerEvent('qb-mechanicjob:server:SaveVehicleProps', props)
                    QBCore.Functions.Notify(Lang:t('menu.spoiler_installed'), 'success')
                    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                    exports['qb-menu']:closeMenu()
                end, function() -- Callback khi bị hủy
                    QBCore.Functions.Notify(Lang:t('progress.install_cancelled'), 'error')
                    ClearPedTasks(PlayerPedId())
                    exports['qb-menu']:closeMenu() -- Đóng menu cả khi hủy
                end)
            end,
            args = {}
        }
    }

    for i = 0, numMods - 1 do
        local modHeader = GetModTextLabel(vehicle, modType, i)
        modHeader = modHeader and GetLabelText(modHeader) or 'Spoiler ' .. i

        spoilersMenu[#spoilersMenu + 1] = {
            header = (i + 1) .. ". " .. modHeader,
            params = {
                isAction = true,
                event = function(data)
                    SetVehicleModKit(vehicle, 0)

                    QBCore.Functions.Progressbar('installing_spoiler', Lang:t('progress.installing_spoiler'), 5000, false, true, {
                        disableMovement = true,
                        disableCarMovement = true,
                        disableMouse = false,
                        disableCombat = true,
                    }, {
                        animDict = 'mini@repair',
                        anim = 'fixing_a_ped',
                        flags = 1,
                    }, {
                        model = 'imp_prop_impexp_span_03',
                        bone = 28422,
                        coords = vec3(0.06, 0.01, -0.02),
                        rotation = vec3(0.0, 0.0, 0.0),
                    }, {}, function() -- Callback khi thành công
                        SetVehicleMod(vehicle, data.modType, data.modIndex, false)
                        local props = QBCore.Functions.GetVehicleProperties(vehicle)
                        TriggerServerEvent('qb-mechanicjob:server:SaveVehicleProps', props)
                        QBCore.Functions.Notify(Lang:t('menu.spoiler_installed'), 'success')
                        PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                        exports['qb-menu']:closeMenu()
                    end, function() -- Callback khi bị hủy
                        QBCore.Functions.Notify(Lang:t('progress.install_cancelled'), 'error')
                        ClearPedTasks(PlayerPedId())
                        exports['qb-menu']:closeMenu() -- Đóng menu cả khi hủy
                    end)
                end,
                args = {
                    modType = modType,
                    modIndex = i
                }
            }
        }
    end
    exports['qb-menu']:openMenu(spoilersMenu)
    return true -- THAY ĐỔI: TRẢ VỀ TRUE NẾU MENU ĐƯỢC MỞ THÀNH CÔNG
end


-- Plates

local function PlateIndex(vehicle)
    local plates = { { header = Lang:t('menu.plate'), isMenuHeader = true, icon = 'fas fa-id-card' } }
    for i = 1, #Config.PlateIndexes do
        plates[#plates + 1] = {
            header = Config.PlateIndexes[i].label,
            params = {
                isAction = true,
                event = function()
                    SetVehicleNumberPlateTextIndex(vehicle, Config.PlateIndexes[i].id)
                    PlateIndex(vehicle)
                end,
                args = {}
            }
        }
    end
    exports['qb-menu']:openMenu(plates)
end

RegisterNetEvent('qb-mechanicjob:client:installCosmetic', function(item)
    local vehicle, distance = QBCore.Functions.GetClosestVehicle()
    if vehicle == 0 or distance > 5.0 then return end
    local vehicleClass = GetVehicleClass(vehicle)
    if Config.IgnoreClasses[vehicleClass] then return end
    if GetVehicleModKit(vehicle) ~= 0 then SetVehicleModKit(vehicle, 0) end
    
    -- Xử lý các loại item ngoại thất tại đây
    if item == 'veh_exterior' then
        OpenExteriors(vehicle)
        TriggerServerEvent('qb-mechanicjob:server:removeItem', item)
    elseif item == 'veh_wheels' then
        OpenWheels(vehicle)
        TriggerServerEvent('qb-mechanicjob:server:removeItem', item)
    elseif item == 'veh_neons' then
        OpenNeon(vehicle)
        TriggerServerEvent('qb-mechanicjob:server:removeItem', item)
    elseif item == 'veh_xenons' then
        OpenXenon(vehicle)
        TriggerServerEvent('qb-mechanicjob:server:removeItem', item)
    elseif item == 'veh_tint' then
        WindowTint(vehicle)
        TriggerServerEvent('qb-mechanicjob:server:removeItem', item)
    elseif item == 'veh_plates' then
        if not IsNearBone(vehicle, 'platelight') then return end
        PlateIndex(vehicle)
        TriggerServerEvent('qb-mechanicjob:server:removeItem', item)
    elseif item == 'spoiler' then -- THÊM DÒNG NÀY
        OpenSpoilers(vehicle, true)
        TriggerServerEvent('qb-mechanicjob:server:removeItem', item)
    elseif item == 'bumper' then -- THÊM DÒNG NÀY
        local openedSuccessfully = OpenFrontBumpers(vehicle, true)
        if openedSuccessfully then
            TriggerServerEvent('qb-mechanicjob:server:removeItem', item)
        end    
    end
end)