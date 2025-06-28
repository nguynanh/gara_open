QBCore = exports['qb-core']:GetCoreObject()

-- Hàm tiện ích (có thể đã có trong functions.lua, nhưng giữ lại ở đây để đảm bảo)
-- local function HexToRGB(hex) ... end -- Hàm này không cần thiết ở đây nữa nếu chỉ là nội thất thuần

-- ===============================================
-- Các hàm liên quan đến INTERIOR
-- ===============================================

-- Interior
local function OpenInteriors(vehicle)
    local mods = { { header = Lang:t('menu.interior'), isMenuHeader = true, icon = 'fas fa-car-side' } }
    -- Lặp qua các danh mục nội thất ngoại trừ Horns (id = 14)
    for i = 1, #Config.InteriorCategories do
        if Config.InteriorCategories[i].id ~= 14 then -- Bỏ qua Horns ở đây
            local modCount = GetNumVehicleMods(vehicle, Config.InteriorCategories[i].id)
            if modCount > 0 then
                mods[#mods + 1] = {
                    header = Config.InteriorCategories[i].label,
                    params = {
                        isAction = true,
                        event = function()
                            InteriorModList(Config.InteriorCategories[i].id, vehicle, Config.InteriorCategories[i].label)
                        end,
                        args = {}
                    }
                }
            end
        end
    end
    exports['qb-menu']:openMenu(mods)
end

function InteriorModList(id, vehicle, label)
    local mods = { { header = label, isMenuHeader = true, icon = 'fas fa-car-side' } }
    mods[#mods + 1] = {
        header = Lang:t('menu.back'),
        icon = 'fas fa-backward',
        params = {
            isAction = true,
            event = function()
                OpenInteriors(vehicle)
            end,
            args = {}
        }
    }
    for i = 0, GetNumVehicleMods(vehicle, id) - 1 do
        local modHeader
        -- Đảm bảo Horns không được xử lý ở đây nữa
        if id == 14 then -- Trường hợp này sẽ không xảy ra nếu OpenInteriors đã bỏ qua Horns, nhưng để an toàn
            modHeader = Config.HornLabels[i] or Lang:t('menu.unknown')
        else
            local modTextLabel = GetModTextLabel(vehicle, id, i)
            modHeader = modTextLabel and GetLabelText(modTextLabel) or 'Mod ' .. i
        end

        mods[#mods + 1] = {
            header = modHeader,
            params = {
                isAction = true,
                event = function(data)
                    SetVehicleModKit(vehicle, 0)
                    SetVehicleMod(vehicle, data.modType, data.modIndex, false)
                    -- if id == 14 then -- Loại bỏ phần này vì Horns sẽ có hàm riêng
                    --     StartVehicleHorn(vehicle, 10000, 0, false)
                    -- end
                    InteriorModList(id, vehicle, label)
                end,
                args = {
                    modType = id,
                    modIndex = i
                }
            }
        }
    end
    exports['qb-menu']:openMenu(mods)
end

-- ===============================================
-- Hàm riêng cho HORNS (CÒI)
-- ===============================================
local function OpenHorns(vehicle)
    local hornsMenu = { { header = Lang:t('menu.horns'), isMenuHeader = true, icon = 'fas fa-horn' } } -- Giả định icon 'fas fa-horn' có sẵn hoặc dùng icon khác
    hornsMenu[#hornsMenu + 1] = {
        header = Lang:t('menu.back'),
        icon = 'fas fa-backward',
        params = {
            isAction = true,
            event = function()
                OpenInteriors(vehicle) -- Quay lại menu nội thất chính
            end,
            args = {}
        }
    }

    -- Horns có ID 14 và các nhãn được định nghĩa trong Config.HornLabels
    for i = 0, #Config.HornLabels -1 do -- Loop qua số lượng còi có sẵn trong game
        local hornLabel = Config.HornLabels[i] or Lang:t('menu.unknown')
        hornsMenu[#hornsMenu + 1] = {
            header = hornLabel,
            params = {
                isAction = true,
                event = function(data)
                    SetVehicleModKit(vehicle, 0)
                    SetVehicleMod(vehicle, 14, data.hornIndex, false) -- 14 là ID cho Horns
                    StartVehicleHorn(vehicle, 10000, 0, false) -- Phát âm thanh còi để nghe thử
                    -- Bạn có thể thêm một Wait(ví dụ: 1000) ở đây để còi kêu trong 1 khoảng thời gian rồi tắt
                    -- StopVehicleHorn(vehicle, false)
                    OpenHorns(vehicle) -- Mở lại menu Horns
                end,
                args = {
                    hornIndex = i
                }
            }
        }
    end
    exports['qb-menu']:openMenu(hornsMenu)
end


-- Events (chỉnh sửa lại cho phù hợp với logic mới)
RegisterNetEvent('qb-mechanicjob:client:installCosmetic', function(item)
    local vehicle, distance = QBCore.Functions.GetClosestVehicle()
    if vehicle == 0 or distance > 5.0 then return end
    local vehicleClass = GetVehicleClass(vehicle)
    if Config.IgnoreClasses[vehicleClass] then return end
    if GetVehicleModKit(vehicle) ~= 0 then SetVehicleModKit(vehicle, 0) end
    
    -- Xử lý các loại item nội thất tại đây
    if item == 'veh_interior' then
        OpenInteriors(vehicle)
        TriggerServerEvent('qb-mechanicjob:server:removeItem', item)
    elseif item == 'veh_horns' then -- Bắt sự kiện cho item còi mới
        OpenHorns(vehicle)
        TriggerServerEvent('qb-mechanicjob:server:removeItem', item)
    end
end)