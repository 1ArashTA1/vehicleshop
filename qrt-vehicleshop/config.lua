Config = {}
Config.UsingTarget = true
-- ==========================================
-- Custom Trunk/Glovebox Storage (per model)
-- وزن‌ها به گرم (GRAMS)
-- ==========================================
Config.CustomVehicleStorage = {
    -- ['fnf4r34']  = { trunkWeight = 120000, trunkSlots = 90, gloveWeight = 30000, gloveSlots = 12 },
    -- ['police2'] = { trunkWeight = 120000, trunkSlots = 60, gloveWeight = 30000, gloveSlots = 12 },
}
Config.Commission = 0.23 -- Percent that goes to sales person from a full car sale 10%
Config.FinanceCommission = 0.11 -- Percent that goes to sales person from a finance sale 5%
Config.FinanceZone = vector3(-55.59, 68.25, 71.95)-- Where the finance menu is located
Config.PaymentWarning = 10 -- time in minutes that player has to make payment before repo
Config.PaymentInterval = 24 -- time in hours between payment being due
Config.MinimumDown = 10 -- minimum percentage allowed down
Config.MaximumPayments = 24 -- maximum payments allowed
Config.PreventFinanceSelling = true -- allow/prevent players from using /transfervehicle if financed
Config.FilterByMake = false -- adds a make list before selecting category in shops
Config.SortAlphabetically = true -- will sort make, category, and vehicle selection menus alphabetically
Config.HideCategorySelectForOne = true -- will hide the category selection menu if a shop only sells one category of vehicle or a make has only one category
Config.Shops = {
    ['pdm'] = {
        ['Type'] = 'managed', -- no player interaction is required to purchase a car
        ['Zone'] = {
            ['Shape'] = {--polygon that surrounds the shop
                vector2(-56.727394104004, -1086.2325439453),
                vector2(-60.612808227539, -1096.7795410156),
                vector2(-58.26834487915, -1100.572265625),
                vector2(-35.927803039551, -1109.0034179688),
                vector2(-34.427627563477, -1108.5111083984),
                vector2(-32.02657699585, -1101.5877685547),
                vector2(-33.342102050781, -1101.0377197266),
                vector2(-31.292987823486, -1095.3717041016)
            },
            ['minZ'] = 25.0, -- min height of the shop zone
            ['maxZ'] = 28.0, -- max height of the shop zone
            ['size'] = 2.75 -- size of the vehicles zones
        },
        ['Job'] = 'cardealer', -- Name of job or none
        ['ShopLabel'] = 'Premium Deluxe Motorsport', -- Blip name
        ['showBlip'] = true, -- true or false
        ['blipSprite'] = 820, -- Blip sprite
        ['blipColor'] = 5, -- Blip color
        ['TestDriveTimeLimit'] = 0.5, -- Time in minutes until the vehicle gets deleted
        ['Location'] = vector3(-43.74, -1101.81, 26.44), -- Blip Location
        ['ReturnLocation'] = vector3(-45.38, -1083.04, 26.72), -- Location to return vehicle, only enables if the vehicleshop has a job owned
        ['VehicleSpawn'] = vector4(-10.25, -1096.83, 26.67, 108.66), -- Spawn location when vehicle is bought
        ['TestDriveSpawn'] = vector4(-10.91, -1100.26, 26.67, 100.42), -- Spawn location for test drive
        ['RentDriveSpawn'] = vector4(-9.53, -1087.89, 26.68, 338.88), -- Spawn location for test drive
        ['ShowroomVehicles'] = {
            [1] = {
                coords = vector4(-32.02, -1103.02, 25.44, 114.43), -- where the vehicle will spawn on display
                defaultVehicle = 'neon', -- Default display vehicle
                chosenVehicle = 'neon', -- Same as default but is dynamically changed when swapping vehicles
            },
            [2] = {
                coords = vector4(-58.96, 64.72, 70.90, 121.51),
                defaultVehicle = 'schafter2',
                chosenVehicle = 'schafter2'
            },
            [3] = {
                coords = vector4(-51.42, -1089.06, 25.44, 122.03),
                defaultVehicle = 'elegy',
                chosenVehicle = 'elegy'
            }
        },
    },
    ['larryscars'] = { 
        ['Type'] = 'managed', -- meaning a real player has to sell the car
        ['Zone'] = {
            ['Shape'] = {
                vector2(1211.6774902344, 2693.9978027344),
                vector2(1210.3582763672, 2747.8112792969),
                vector2(1238.0860595703, 2748.0539550781),
                vector2(1239.3293457031, 2729.0361328125),
                vector2(1242.5383300781, 2725.3308105469),
                vector2(1251.6617431641, 2722.5654296875),
                vector2(1253.9809570312, 2706.0593261719),
                vector2(1259.0677490234, 2694.7819824219)
            },
            ['minZ'] = 37.651748657227,
            ['maxZ'] = 38.129211425781,
            ['size'] = 2.75 -- size of the vehicles zones
        },
        ['Job'] = 'cardealer', -- Name of job or none
        ['ShopLabel'] = 'Larrys Cars',
        ['showBlip'] = true, -- true or false
        ['blipSprite'] = 800, -- Blip sprite
        ['blipColor'] = 82, -- Blip color
        ['TestDriveTimeLimit'] = 0.5,
        ['Location'] = vector3(1227.87, 2726.55, 38.09),
        ['ReturnLocation'] = vector3(1207.74, 2723.04, 38.01),
        ['VehicleSpawn'] = vector4(1207.74, 2723.04, 38.01, 172.86),
        ['TestDriveSpawn'] = vector4(1244.26, 2700.22, 38.01, 225.45), -- Spawn location for test drive
        ['RentDriveSpawn'] = vector4(1242.39, 2720.17, 38.01, 91.94), -- Spawn location for test drive
        ['ShowroomVehicles'] = {
            [1] = {
                coords = vector4(1218.94, 2732.62, 36.61, 327.97),
                defaultVehicle = 'chino',
                chosenVehicle = 'chino'
            },
            [2] = {
                coords = vector4(1215.59, 2732.91, 36.46, 324.41),
                defaultVehicle = 'hermes',
                chosenVehicle = 'hermes'
            },
            [3] = {
                coords = vector4(1213.96, 2734.76, 36.57, 320.53),
                defaultVehicle = 'wolfsbane',
                chosenVehicle = 'wolfsbane'
            },
            [4] = {
                coords = vector4(1234.06, 2732.65, 36.74, 358.36),
                defaultVehicle = 'slamvan',
                chosenVehicle = 'slamvan'
            },
            [5] = {
                coords = vector4(1228.58, 2732.72, 36.54, 358.79),
                defaultVehicle = 'greenwood',
                chosenVehicle = 'greenwood'
            },
            [6] = {
                coords = vector4(1231.18, 2732.96, 36.57, 358.23),
                defaultVehicle = 'sanchez',
                chosenVehicle = 'sanchez'
            },
        }
    }, -- Add your next table under this comma
    ['boats'] = {
        ['Type'] = 'free-use', -- no player interaction is required to purchase a vehicle
        ['Zone'] = {
            ['Shape'] = {--polygon that surrounds the shop
                vector2(-729.39, -1315.84),
                vector2(-766.81, -1360.11),
                vector2(-754.21, -1371.49),
                vector2(-716.94, -1326.88)
            },
            ['minZ'] = 0.0, -- min height of the shop zone
            ['maxZ'] = 5.0, -- max height of the shop zone
            ['size'] = 6.2 -- size of the vehicles zones
        },
        ['Job'] = 'none', -- Name of job or none
        ['ShopLabel'] = 'Marina Shop', -- Blip name
        ['showBlip'] = true, -- true or false
        ['blipSprite'] = 410, -- Blip sprite
        ['blipColor'] = 3, -- Blip color
        ['TestDriveTimeLimit'] = 1.5, -- Time in minutes until the vehicle gets deleted
        ['Location'] = vector3(-738.25, -1334.38, 1.6), -- Blip Location
        ['ReturnLocation'] = vector3(-714.34, -1343.31, 0.0), -- Location to return vehicle, only enables if the vehicleshop has a job owned
        ['VehicleSpawn'] = vector4(-727.87, -1353.1, -0.17, 137.09), -- Spawn location when vehicle is bought
        ['TestDriveSpawn'] = vector4(-722.23, -1351.98, 0.14, 135.33), -- Spawn location for test drive
        ['ShowroomVehicles'] = {
            [1] = {
                coords = vector4(-727.05, -1326.59, 0.00, 229.5), -- where the vehicle will spawn on display
                defaultVehicle = 'seashark', -- Default display vehicle
                chosenVehicle = 'seashark' -- Same as default but is dynamically changed when swapping vehicles
            },
            -- [2] = {
            --     coords = vector4(-732.84, -1333.5, -0.50, 229.5),
            --     defaultVehicle = 'dinghy',
            --     chosenVehicle = 'dinghy'
            -- },
            -- [3] = {
            --     coords = vector4(-737.84, -1340.83, -0.50, 229.5),
            --     defaultVehicle = 'speeder',
            --     chosenVehicle = 'speeder'
            -- },
            -- [4] = {
            --     coords = vector4(-741.53, -1349.7, -2.00, 229.5),
            --     defaultVehicle = 'marquis',
            --     chosenVehicle = 'marquis'
            -- },
        },
    },
    ['air'] = {
        ['Type'] = 'managed', -- no player interaction is required to purchase a vehicle
        ['Zone'] = {
            ['Shape'] = {--polygon that surrounds the shop
                vector2(-1607.58, -3141.7),
                vector2(-1672.54, -3103.87),
                vector2(-1703.49, -3158.02),
                vector2(-1646.03, -3190.84)
            },
            ['minZ'] = 12.99, -- min height of the shop zone
            ['maxZ'] = 16.99, -- max height of the shop zone
            ['size'] = 7.0, -- size of the vehicles zones
        },
        ['Job'] = 'air', -- Name of job or none
        ['ShopLabel'] = 'Air Shop', -- Blip name
        ['showBlip'] = true, -- true or false
        ['blipSprite'] = 251, -- Blip sprite
        ['blipColor'] = 3, -- Blip color
        ['TestDriveTimeLimit'] = 1.5, -- Time in minutes until the vehicle gets deleted
        ['Location'] = vector3(-1652.76, -3143.4, 13.99), -- Blip Location
        ['ReturnLocation'] = vector3(-1628.44, -3104.7, 13.94), -- Location to return vehicle, only enables if the vehicleshop has a job owned
        ['VehicleSpawn'] = vector4(-1617.49, -3086.17, 13.94, 329.2), -- Spawn location when vehicle is bought
        ['TestDriveSpawn'] = vector4(-1625.19, -3103.47, 13.94, 330.28), -- Spawn location for test drive
        ['ShowroomVehicles'] = {
            [1] = {
                coords = vector4(-1651.36, -3162.66, 12.99, 346.89), -- where the vehicle will spawn on display
                defaultVehicle = 'volatus', -- Default display vehicle
                chosenVehicle = 'volatus' -- Same as default but is dynamically changed when swapping vehicles
            },
            [2] = {
                coords = vector4(-1668.53, -3152.56, 12.99, 303.22),
                defaultVehicle = 'luxor2',
                chosenVehicle = 'luxor2'
            },
            [3] = {
                coords = vector4(-1632.02, -3144.48, 12.99, 31.08),
                defaultVehicle = 'nimbus',
                chosenVehicle = 'nimbus'
            },
            [4] = {
                coords = vector4(-1663.74, -3126.32, 12.99, 275.03),
                defaultVehicle = 'frogger',
                chosenVehicle = 'frogger'
            },
        },
    -- },
    -- ['truck'] = {
    --     ['Type'] = 'free-use', -- no player interaction is required to purchase a car
    --     ['Zone'] = {
    --         ['Shape'] = {--polygon that surrounds the shop
    --             vector2(872.23, -1173.5),
    --             vector2(868.88, -1162.7),
    --             vector2(900.91, -1156.54),
    --             vector2(901.96, -1173.71),
    --             vector2(883.59, -1174.47),
    --             vector2(884.59, -1161.29),
    --             vector2(890.06, -1155.0),
    --             vector2(907.71, -1168.71)
    --         },
    --         ['minZ'] = 23.0, -- min height of the shop zone
    --         ['maxZ'] = 28.0, -- max height of the shop zone
    --         ['size'] = 5.75 -- size of the vehicles zones
    --     },
    --     ['Job'] = 'none', -- Name of job or none
    --     ['ShopLabel'] = 'Truck Motor Shop', -- Blip name
    --     ['showBlip'] = true, -- true or false
    --     ['blipSprite'] = 477, -- Blip sprite
    --     ['blipColor'] = 2, -- Blip color
    --     ['TestDriveTimeLimit'] = 0.5, -- Time in minutes until the vehicle gets deleted
    --     ['Location'] = vector3(900.47, -1155.74, 25.16), -- Blip Location
    --     ['ReturnLocation'] = vector3(900.47, -1155.74, 25.16), -- Location to return vehicle, only enables if the vehicleshop has a job owned
    --     ['VehicleSpawn'] = vector4(909.35, -1181.58, 25.55, 177.57), -- Spawn location when vehicle is bought
    --     ['TestDriveSpawn'] = vector4(867.65, -1192.4, 25.37, 95.72), -- Spawn location for test drive
    --     ['ShowroomVehicles'] = {
    --         [1] = {
    --             coords = vector4(890.84, -1170.92, 25.08, 269.58), -- where the vehicle will spawn on display
    --             defaultVehicle = 'hauler', -- Default display vehicle
    --             chosenVehicle = 'hauler', -- Same as default but is dynamically changed when swapping vehicles
    --         },
    --         [2] = {
    --             coords = vector4(878.45, -1171.04, 25.05, 273.08),
    --             defaultVehicle = 'phantom',
    --             chosenVehicle = 'phantom'
    --         },
    --         [3] = {
    --             coords = vector4(880.44, -1163.59, 24.87, 273.08),
    --             defaultVehicle = 'mule',
    --             chosenVehicle = 'mule'
    --         },
    --         [4] = {
    --             coords = vector4(896.95, -1162.62, 24.98, 273.08),
    --             defaultVehicle = 'mixer',
    --             chosenVehicle = 'mixer'
    --         },
    --     },
     },
}
