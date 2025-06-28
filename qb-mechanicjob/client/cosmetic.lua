QBCore = exports['qb-core']:GetCoreObject()
local particleEffects = {}
local isPainting = false

-- Paint

local function HexToRGB(hex)
    if type(hex) ~= 'string' or not hex:match('^#?[%x]+$') or (#hex ~= 6 and #hex ~= 7) then return end
    hex = hex:gsub('#', '')
    return {
        r = tonumber('0x' .. hex:sub(1, 2)),
        g = tonumber('0x' .. hex:sub(3, 4)),
        b = tonumber('0x' .. hex:sub(5, 6))
    }
end

local function GetHex(category, id)
    local hex
    for i = 1, #Config.Paints[category] do
        if Config.Paints[category][i].id == tonumber(id) then
            hex = Config.Paints[category][i].hex
            break
        end
    end
    return hex
end

local function GetPaints(category)
    local Paints = {}
    Paints[#Paints + 1] = { value = 'none', text = Lang:t('menu.none') }
    for i = 1, #Config.Paints[category] do
        Paints[#Paints + 1] = {
            value = Config.Paints[category][i].id,
            text = Config.Paints[category][i].label
        }
    end
    return Paints
end

local function PaintList(category)
    local paintOptions = GetPaints(category)
    local dialog = exports['qb-input']:ShowInput({
        header = Lang:t('menu.paint_vehicle'),
        submitText = Lang:t('menu.submit'),
        inputs = {
            {
                text = Lang:t('menu.primary'),
                name = 'primarypaint',
                type = 'select',
                options = paintOptions
            },
            {
                text = Lang:t('menu.secondary'),
                name = 'secondarypaint',
                type = 'select',
                options = paintOptions
            },
            {
                text = Lang:t('menu.pearlescent'),
                name = 'pearlescentpaint',
                type = 'select',
                options = paintOptions
            },
            {
                text = Lang:t('menu.wheels'),
                name = 'wheelpaint',
                type = 'select',
                options = paintOptions
            }
        }
    })
    if not dialog then return end
    if dialog.primarypaint and dialog.secondarypaint and dialog.pearlescentpaint and dialog.wheelpaint then
        local colors = {
            primary = dialog.primarypaint ~= 'none' and HexToRGB(GetHex(category, dialog.primarypaint)) or nil,
            secondary = dialog.secondarypaint ~= 'none' and HexToRGB(GetHex(category, dialog.secondarypaint)) or nil,
            pearlescent = dialog.pearlescentpaint ~= 'none' and HexToRGB(GetHex(category, dialog.pearlescentpaint)) or nil,
            wheel = dialog.wheelpaint ~= 'none' and HexToRGB(GetHex(category, dialog.wheelpaint)) or nil
        }
        local vehicle, distance = QBCore.Functions.GetClosestVehicle()
        if vehicle == 0 or distance > 5.0 then return end
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        if isPainting then return end
        TriggerServerEvent('qb-mechanicjob:server:sprayVehicle', netId, dialog.primarypaint, dialog.secondarypaint, dialog.pearlescentpaint, dialog.wheelpaint, colors)
    end
end

local function CustomColor()
    local dialog = exports['qb-input']:ShowInput({
        header = Lang:t('menu.custom_color'),
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
                text = Lang:t('menu.section'),
                name = 'section',
                type = 'radio',
                options = {
                    { value = 'primary',   text = Lang:t('menu.primary') },
                    { value = 'secondary', text = Lang:t('menu.secondary') }
                }
            },
            {
                text = Lang:t('menu.type'),
                name = 'paintType',
                type = 'radio',
                options = {
                    { value = 'metallic', text = Lang:t('menu.metallic') },
                    { value = 'matte',    text = Lang:t('menu.matte') },
                    { value = 'chrome',   text = Lang:t('menu.chrome') }
                }
            }
        }
    })
    if not dialog then return end
    if (dialog.hex or dialog.colorpicker) and dialog.section then
        local color = (dialog.hex and dialog.hex ~= '') and dialog.hex or dialog.colorpicker
        local vehicle, distance = QBCore.Functions.GetClosestVehicle()
        if vehicle == 0 or distance > 5.0 then return end
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        if isPainting then return end
        TriggerServerEvent('qb-mechanicjob:server:sprayVehicleCustom', netId, dialog.section, dialog.paintType, HexToRGB(color))
    end
end

function PaintCategories()
    local Paints = { { header = Lang:t('menu.paints'), isMenuHeader = true, icon = 'fas fa-fill' } }
    Paints[#Paints + 1] = {
        header = Lang:t('menu.custom_color'),
        params = {
            isAction = true,
            event = function()
                CustomColor()
            end,
            args = {}
        }
    }
    for k in pairs(Config.Paints) do
        Paints[#Paints + 1] = {
            header = k,
            params = {
                isAction = true,
                event = function()
                    PaintList(k)
                end,
                args = {}
            }
        }
    end
    exports['qb-menu']:openMenu(Paints)
end

-- Events

RegisterNetEvent('qb-mechanicjob:client:vehicleSetColors', function(netId, section, colorIndex)
    if not NetworkDoesEntityExistWithNetworkId(netId) then return end
    local vehicle = NetworkGetEntityFromNetworkId(netId)

    if section == 'primary' then
        local _, colorSecondary = GetVehicleColours(vehicle)
        ClearVehicleCustomPrimaryColour(vehicle)
        SetVehicleColours(vehicle, tonumber(colorIndex), colorSecondary)
    end

    if section == 'secondary' then
        local colorPrimary, _ = GetVehicleColours(vehicle)
        ClearVehicleCustomSecondaryColour(vehicle)
        SetVehicleColours(vehicle, colorPrimary, tonumber(colorIndex))
    end

    if section == 'pearlescent' then
        local _, wheelColor = GetVehicleExtraColours(vehicle)
        SetVehicleExtraColours(vehicle, tonumber(colorIndex), wheelColor)
    end

    if section == 'wheel' then
        local pearlescentColor, _ = GetVehicleExtraColours(vehicle)
        SetVehicleExtraColours(vehicle, pearlescentColor, tonumber(colorIndex))
    end

        
    local props = QBCore.Functions.GetVehicleProperties(vehicle)
    TriggerServerEvent('qb-mechanicjob:server:SaveVehicleProps', props)
end)

RegisterNetEvent('qb-mechanicjob:client:startParticles', function(netId, color)
    isPainting = true
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not color then color = { r = 255, g = 255, b = 255 } end
    UseParticleFxAsset('core')
    local offsetX, offsetY, offsetZ = 0.0, 0.0, 3.0
    local xRot, yRot, zRot = 0.0, 180.0, 0.0
    local scale = 1.5
    local effect = StartNetworkedParticleFxLoopedOnEntity('ent_amb_steam', vehicle, offsetX, offsetY, offsetZ, xRot, yRot, zRot, scale, false, false, false)
    particleEffects[#particleEffects + 1] = effect
    SetParticleFxLoopedAlpha(effect, 100.0)
    SetParticleFxLoopedColour(effect, color.r / 255.0, color.g / 255.0, color.b / 255.0, 0)
end)

RegisterNetEvent('qb-mechanicjob:client:stopParticles', function()
    isPainting = false
    for _, effect in ipairs(particleEffects) do
        StopParticleFxLooped(effect, true)
    end
end)

-- Sự kiện installCosmetic chỉ nên gọi các menu nội bộ (PaintCategories) hoặc loại bỏ hoàn toàn nếu bạn không dùng item cosmetic cho sơn
RegisterNetEvent('qb-mechanicjob:client:installCosmetic', function(item)
    local vehicle, distance = QBCore.Functions.GetClosestVehicle()
    if vehicle == 0 or distance > 5.0 then return end
    local vehicleClass = GetVehicleClass(vehicle)
    if Config.IgnoreClasses[vehicleClass] then return end
    if GetVehicleModKit(vehicle) ~= 0 then SetVehicleModKit(vehicle, 0) end

    -- Chỉ giữ lại logic liên quan đến sơn nếu bạn có một item "veh_paint"
    if item == 'veh_paint' then -- Đổi tên item nếu cần
        PaintCategories()
        TriggerServerEvent('qb-mechanicjob:server:removeItem', item)
    end
    -- Các phần 'veh_interior', 'veh_exterior', 'veh_wheels', v.v. đã được chuyển sang các file khác
end)


-- Threads

CreateThread(function()
    RequestNamedPtfxAsset('core')
    while not HasNamedPtfxAssetLoaded('core') do
        Wait(0)
        RequestNamedPtfxAsset('core')
    end
end)
RegisterNetEvent('qb-mechanicjob:client:toggleSonSpray', function(toggle)
    if toggle then
        -- Gọi hàm từ tài nguyên 'son' để bật hiệu ứng
        exports['son']:StartSonSprayEffect()
    else
        -- Gọi hàm từ tài nguyên 'son' để tắt hiệu ứng
        exports['son']:StopSonSprayEffect()
    end
end)