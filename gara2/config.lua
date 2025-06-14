Config = Config or {}

Config.UseTarget = GetConvar('UseTarget', 'false') == 'true' -- or true if you prefer qb-target

-- *** THÊM DÒNG NÀY ***
Config.ParkFee = 1000 -- Phí để đậu một chiếc xe trong bãi đậu xe cá nhân

Config.Zones = {
    ["SandyParking"] = {
        -- BusinessName is no longer needed
        ParkVehicleZone = vector4(-414.6, 1195.14, 325.64, 153.1), -- Renamed from SellVehicle
        RetrieveVehicleSpawn = vector4(-396.43, 1191.48, 325.64, 157.0), -- Renamed from BuyVehicle

        PolyZone = {
            vector2(-483.85, 1099.74),
            vector2(-392.73, 1074.69),
            vector2(-350.63, 1239.01),
            vector2(-412.13, 1274.75)
        },
        MinZ = 320.0,
        MaxZ = 340.0,

        VehicleSpots = {
            vector4(-422.01, 1198.27, 324.9, 231.81),
            vector4(-420.78, 1202.93, 325.22, 227.58),
            vector4(-419.48, 1207.03, 325.22, 235.33),
            vector4(-418.38, 1210.98, 325.22, 233.21),
            vector4(-417.26, 1215.17, 325.22, 234.23),
            vector4(-415.84, 1219.61, 325.22, 232.22),
            vector4(-414.86, 1223.82, 325.22, 229.29),
            vector4(-413.67, 1227.89, 325.22, 231.86),
            vector4(-412.67, 1231.99, 325.22, 227.91),
            vector4(-411.68, 1236.15, 325.22, 234.27),
            vector4(-390.07, 1189.85, 325.22, 99.09),
            vector4(-389.08, 1194.05, 325.22, 98.75),
            vector4(-387.99, 1198.31, 325.22, 99.34),
            vector4(-386.71, 1202.31, 325.22, 96.65),
            vector4(-385.99, 1206.45, 325.22, 101.24),
            vector4(-384.55, 1211.01, 325.22, 99.9),
            vector4(-383.61, 1215.06, 325.22, 94.8),
            vector4(-382.37, 1219.14, 325.22, 93.58),
            vector4(-399.7, 1197.47, 325.22, 164.05),
            vector4(-396.2, 1209.65, 325.22, 163.97),
            vector4(-394.51, 1215.69, 325.22, 164.43),
            vector4(-408.8, 1200.31, 325.22, 163.52),
            vector4(-405.6, 1212.17, 325.22, 162.46),
            vector4(-403.95, 1218.03, 325.22, 163.27),
            vector4(-404.7, 1237.83, 325.22, 252.64),
            vector4(-398.61, 1235.93, 325.22, 252.69),
            vector4(-407.16, 1206.33, 325.22, 162.48),
            vector4(-397.99, 1203.85, 325.22, 164.16),
        }
    }
}