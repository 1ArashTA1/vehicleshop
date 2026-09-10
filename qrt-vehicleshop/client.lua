-- Variables
local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData()
local testDriveZone = nil
local vehicleMenu = {}
local Initialized = false
local testDriveVeh, inTestDrive = 0, false
local ClosestVehicle = 1
local zones = {}
local insideShop, tempShop = nil, nil

-- Handlers
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    local citizenid = PlayerData.citizenid
    TriggerServerEvent('qrt-vehicleshop:server:addPlayer', citizenid)
    TriggerServerEvent('qrt-vehicleshop:server:checkFinance')
    if not Initialized then Init() end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end
    if next(PlayerData) ~= nil and not Initialized then
        PlayerData = QBCore.Functions.GetPlayerData()
        local citizenid = PlayerData.citizenid
        TriggerServerEvent('qrt-vehicleshop:server:addPlayer', citizenid)
        TriggerServerEvent('qrt-vehicleshop:server:checkFinance')
        Init()
    end
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    local citizenid = PlayerData.citizenid
    TriggerServerEvent('qrt-vehicleshop:server:removePlayer', citizenid)
    PlayerData = {}
end)

-- Static Headers
local vehHeaderMenu = {
    {
        header = Lang:t('menus.vehHeader_header'),
        txt = Lang:t('menus.vehHeader_txt'),
        icon = 'fa-solid fa-car',
        params = {
            event = 'qrt-vehicleshop:client:showVehOptions'
        }
    }
}

-- local financeMenu = {
--     {
--         header = Lang:t('menus.financed_header'),
--         txt = Lang:t('menus.finance_txt'),
--         icon = 'fa-solid fa-user-ninja',
--         params = {
--             event = 'qrt-vehicleshop:client:getVehicles'
--         }
--     }
-- }

local returnTestDrive = {
    {
        header = Lang:t('menus.returnTestDrive_header'),
        icon = 'fa-solid fa-flag-checkered',
        params = {
            event = 'qrt-vehicleshop:client:TestDriveReturn'
        }
    }
}

-- Functions
local function drawTxt(text, font, x, y, scale, r, g, b, a)
    SetTextFont(font)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, a)
    SetTextOutline()
    SetTextCentre(1)
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(x, y)
end

local function tablelength(T)
    local count = 0
    for _ in pairs(T) do
        count = count + 1
    end
    return count
end

local function comma_value(amount)
    local formatted = amount
    local k
    while true do
        formatted, k = string.gsub(formatted, '^(-?%d+)(%d%d%d)', '%1,%2')
        if k == 0 then
            break
        end
    end
    return formatted
end

local function getVehName()
    return QBCore.Shared.Vehicles[Config.Shops[insideShop]['ShowroomVehicles'][ClosestVehicle].chosenVehicle]['name']
end

local function getVehPrice()
    return comma_value(QBCore.Shared.Vehicles[Config.Shops[insideShop]['ShowroomVehicles'][ClosestVehicle].chosenVehicle]['price'])
end

local function getVehBrand()
    return QBCore.Shared.Vehicles[Config.Shops[insideShop]['ShowroomVehicles'][ClosestVehicle].chosenVehicle]['brand']
end

local function setClosestShowroomVehicle()
    local pos = GetEntityCoords(PlayerPedId(), true)
    local current = nil
    local dist = nil
    local closestShop = insideShop
    for id in pairs(Config.Shops[closestShop]['ShowroomVehicles']) do
        local dist2 = #(pos - vector3(Config.Shops[closestShop]['ShowroomVehicles'][id].coords.x, Config.Shops[closestShop]['ShowroomVehicles'][id].coords.y, Config.Shops[closestShop]['ShowroomVehicles'][id].coords.z))
        if current then
            if dist2 < dist then
                current = id
                dist = dist2
            end
        else
            dist = dist2
            current = id
        end
    end
    if current ~= ClosestVehicle then
        ClosestVehicle = current
    end
end

local function createTestDriveReturn()
    testDriveZone = BoxZone:Create(
        Config.Shops[insideShop]['ReturnLocation'],
        5.2,
        8.0,
        {
            name = 'box_zone_testdrive_return_' .. insideShop,
        })

    testDriveZone:onPlayerInOut(function(isPointInside)
        if isPointInside and IsPedInAnyVehicle(PlayerPedId()) then
            SetVehicleForwardSpeed(GetVehiclePedIsIn(PlayerPedId(), false), 0)
            exports['qb-menu']:openMenu(returnTestDrive)
        else
            exports['qb-menu']:closeMenu()
        end
    end)
end

local function startTestDriveTimer(testDriveTime, prevCoords)
    local gameTimer = GetGameTimer()
    CreateThread(function()
        Wait(2000) -- Avoids the condition to run before entering vehicle
        while inTestDrive do
            if GetGameTimer() < gameTimer + tonumber(1000 * testDriveTime) then
                local secondsLeft = GetGameTimer() - gameTimer
                if secondsLeft >= tonumber(1000 * testDriveTime) - 20 or GetPedInVehicleSeat(NetToVeh(testDriveVeh), -1) ~= PlayerPedId() then
                    TriggerServerEvent('qrt-vehicleshop:server:deleteVehicle', testDriveVeh)
                    testDriveVeh = 0
                    inTestDrive = false
                    SetEntityCoords(PlayerPedId(), prevCoords)
                    QBCore.Functions.Notify(Lang:t('general.testdrive_complete'))
                end
                drawTxt(Lang:t('general.testdrive_timer') .. math.ceil(testDriveTime - secondsLeft / 1000), 4, 0.5, 0.93, 0.50, 255, 255, 255, 180)
            end
            Wait(0)
        end
    end)
end

local function createVehZones(shopName, entity)
    if not Config.UsingTarget then
        for i = 1, #Config.Shops[shopName]['ShowroomVehicles'] do
            zones[#zones + 1] = BoxZone:Create(
                vector3(Config.Shops[shopName]['ShowroomVehicles'][i]['coords'].x,
                    Config.Shops[shopName]['ShowroomVehicles'][i]['coords'].y,
                    Config.Shops[shopName]['ShowroomVehicles'][i]['coords'].z),
                Config.Shops[shopName]['Zone']['size'],
                Config.Shops[shopName]['Zone']['size'],
                {
                    name = 'box_zone_' .. shopName .. '_' .. i,
                    minZ = Config.Shops[shopName]['Zone']['minZ'],
                    maxZ = Config.Shops[shopName]['Zone']['maxZ'],
                    debugPoly = false,
                })
        end
        local combo = ComboZone:Create(zones, { name = 'vehCombo', debugPoly = false })
        combo:onPlayerInOut(function(isPointInside)
            if isPointInside then
                if PlayerData and PlayerData.job and (PlayerData.job.name == Config.Shops[insideShop]['Job'] or Config.Shops[insideShop]['Job'] == 'none') then
                    exports['qb-menu']:showHeader(vehHeaderMenu)
                end
            else
                exports['qb-menu']:closeMenu()
            end
        end)
    else
        exports['qrt-target']:AddTargetEntity(entity, {
            options = {
                {
                    type = 'client',
                    event = 'qrt-vehicleshop:client:showVehOptions',
                    icon = 'fas fa-car',
                    label = Lang:t('general.vehinteraction'),
                    canInteract = function()
                        local closestShop = insideShop
                        return closestShop and (Config.Shops[closestShop]['Job'] == 'none' or PlayerData.job.name == Config.Shops[closestShop]['Job'])
                    end
                },
            },
            distance = 3.0
        })
    end
end

-- Zones
function createFreeUseShop(shopShape, name)
    local zone = PolyZone:Create(shopShape, {
        name = name,
        minZ = shopShape.minZ,
        maxZ = shopShape.maxZ
    })

    zone:onPlayerInOut(function(isPointInside)
        if isPointInside then
            insideShop = name
            CreateThread(function()
                while insideShop do
                    setClosestShowroomVehicle()
                    vehicleMenu = {
                        {
                            isMenuHeader = true,
                            icon = 'fa-solid fa-circle-info',
                            header = getVehBrand():upper() .. ' ' .. getVehName():upper() .. ' - $' .. getVehPrice(),
                        },
                        {
                            header = Lang:t('menus.ta'),
                            txt = Lang:t('menus.tar'),
                            icon = 'fa-solid fa-car-on',
                            params = {
                                event = 'qrt-vehicleshop:client:TestDrive',
                            }
                        },
                        {
                            header = Lang:t('menus.test_header'),
                            txt = Lang:t('menus.freeuse_test_txt'),
                            icon = 'fa-solid fa-car-on',
                            params = {
                                event = 'qrt-vehicleshop:client:TestDriveTa',
                            }
                        },
                        {
                            header = Lang:t('menus.freeuse_buy_header'),
                            txt = Lang:t('menus.freeuse_buy_txt'),
                            icon = 'fa-solid fa-hand-holding-dollar',
                            params = {
                                isServer = true,
                                event = 'qrt-vehicleshop:server:buyShowroomVehicle',
                                args = {
                                    buyVehicle = Config.Shops[insideShop]['ShowroomVehicles'][ClosestVehicle].chosenVehicle
                                }
                            }
                        },
                        {
                            header = Lang:t('menus.finance_header'),
                            txt = Lang:t('menus.freeuse_finance_txt'),
                            icon = 'fa-solid fa-coins',
                            params = {
                                event = 'qrt-vehicleshop:client:openFinance',
                                args = {
                                    price = getVehPrice(),
                                    buyVehicle = Config.Shops[insideShop]['ShowroomVehicles'][ClosestVehicle].chosenVehicle
                                }
                            }
                        },
                        {
                            header = Lang:t('menus.swap_header'),
                            txt = Lang:t('menus.swap_txt'),
                            icon = 'fa-solid fa-arrow-rotate-left',
                            params = {
                                event = Config.FilterByMake and 'qrt-vehicleshop:client:vehMakes' or 'qrt-vehicleshop:client:vehCategories',
                            }
                        },
                    }
                    Wait(1000)
                end
            end)
        else
            insideShop = nil
            ClosestVehicle = 1
        end
    end)
end

function createManagedShop(shopShape, name)
    local zone = PolyZone:Create(shopShape, {
        name = name,
        minZ = shopShape.minZ,
        maxZ = shopShape.maxZ
    })

    zone:onPlayerInOut(function(isPointInside)
        if isPointInside then
            insideShop = name
            CreateThread(function()
                while insideShop and PlayerData.job and PlayerData.job.name == Config.Shops[name]['Job'] do
                    setClosestShowroomVehicle()
                    vehicleMenu = {
                        {
                            isMenuHeader = true,
                            icon = 'fa-solid fa-circle-info',
                            header = getVehBrand():upper() .. ' ' .. getVehName():upper() .. ' - $' .. getVehPrice(),
                        },
                        {
                            header = Lang:t('menus.ta'),
                            txt = Lang:t('menus.tar'),
                            icon = 'fa-solid fa-user-plus',
                            params = {
                                event = 'qrt-vehicleshop:client:openIdMenu',
                                args = {
                                    vehicle = Config.Shops[insideShop]['ShowroomVehicles'][ClosestVehicle].chosenVehicle,
                                    type = 'ta'
                                }
                            }
                        },
                        {
                            header = Lang:t('menus.test_header'),
                            txt = Lang:t('menus.managed_test_txt'),
                            icon = 'fa-solid fa-user-plus',
                            params = {
                                event = 'qrt-vehicleshop:client:openIdMenu',
                                args = {
                                    vehicle = Config.Shops[insideShop]['ShowroomVehicles'][ClosestVehicle].chosenVehicle,
                                    type = 'testDrive'
                                }
                            }
                        },
                        {
                            header = Lang:t('menus.managed_sell_header'),
                            txt = Lang:t('menus.managed_sell_txt'),
                            icon = 'fa-solid fa-cash-register',
                            params = {
                                event = 'qrt-vehicleshop:client:openIdMenu',
                                args = {
                                    vehicle = Config.Shops[insideShop]['ShowroomVehicles'][ClosestVehicle].chosenVehicle,
                                    type = 'sellVehicle'
                                }
                            }
                        },
                        {
                            header = Lang:t('menus.finance_header'),
                            txt = Lang:t('menus.managed_finance_txt'),
                            icon = 'fa-solid fa-coins',
                            params = {
                                event = 'qrt-vehicleshop:client:openCustomFinance',
                                args = {
                                    price = getVehPrice(),
                                    vehicle = Config.Shops[insideShop]['ShowroomVehicles'][ClosestVehicle].chosenVehicle
                                }
                            }
                        },
                        {
                            header = Lang:t('menus.swap_header'),
                            txt = Lang:t('menus.swap_txt'),
                            icon = 'fa-solid fa-arrow-rotate-left',
                            params = {
                                event = Config.FilterByMake and 'qrt-vehicleshop:client:vehMakes' or 'qrt-vehicleshop:client:vehCategories',
                            }
                        },
                    }
                    Wait(1000)
                end
            end)
        else
            insideShop = nil
            ClosestVehicle = 1
        end
    end)
end

function Init()
    Initialized = true
    CreateThread(function()
        for name, shop in pairs(Config.Shops) do
            if shop['Type'] == 'free-use' then
                createFreeUseShop(shop['Zone']['Shape'], name)
            elseif shop['Type'] == 'managed' then
                createManagedShop(shop['Zone']['Shape'], name)
            end
        end
    end)
    CreateThread(function()
        local financeZone = BoxZone:Create(Config.FinanceZone, 2.0, 2.0, {
            name = 'vehicleshop_financeZone',
            offset = { 0.0, 0.0, 0.0 },
            scale = { 1.0, 1.0, 1.0 },
            minZ = Config.FinanceZone.z - 1,
            maxZ = Config.FinanceZone.z + 1,
            debugPoly = false,
        })

        financeZone:onPlayerInOut(function(isPointInside)
            if isPointInside then
                exports['qb-menu']:showHeader(financeMenu)
            else
                exports['qb-menu']:closeMenu()
            end
        end)
    end)
    CreateThread(function()
        for k in pairs(Config.Shops) do
            for i = 1, #Config.Shops[k]['ShowroomVehicles'] do
                local model = GetHashKey(Config.Shops[k]['ShowroomVehicles'][i].defaultVehicle)
                RequestModel(model)
                while not HasModelLoaded(model) do
                    Wait(0)
                end
                local veh = CreateVehicle(model, Config.Shops[k]['ShowroomVehicles'][i].coords.x, Config.Shops[k]['ShowroomVehicles'][i].coords.y, Config.Shops[k]['ShowroomVehicles'][i].coords.z, false, false)
                SetModelAsNoLongerNeeded(model)
                SetVehicleOnGroundProperly(veh)
                SetEntityInvincible(veh, true)
                SetVehicleDirtLevel(veh, 0.0)
                SetVehicleDoorsLocked(veh, 3)
                SetEntityHeading(veh, Config.Shops[k]['ShowroomVehicles'][i].coords.w)
                FreezeEntityPosition(veh, true)
                SetVehicleNumberPlateText(veh, 'BUY ME')
                if Config.UsingTarget then createVehZones(k, veh) end
            end
            if not Config.UsingTarget then createVehZones(k) end
        end
    end)
end

-- Events
RegisterNetEvent('qrt-vehicleshop:client:homeMenu', function()
    exports['qb-menu']:openMenu(vehicleMenu)
end)

RegisterNetEvent('qrt-vehicleshop:client:showVehOptions', function()
    exports['qb-menu']:openMenu(vehicleMenu, true, true)
end)

RegisterNetEvent('qrt-vehicleshop:client:TestDriveTa', function(vehicle)

    if inTestDrive then
        QBCore.Functions.Notify("Already using a vehicle", "error")
        return
    end

    inTestDrive = true

    tempShop = insideShop

    QBCore.Functions.TriggerCallback('QBCore:Server:SpawnVehicle', function(netId)

        local veh = NetToVeh(netId)

        exports['qrt_fuel']:SetFuel(veh, 50)

        Entity(veh).state.rental = true
        SetEntityHeading(veh, Config.Shops[tempShop]['RentDriveSpawn'].w)

        TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(veh))

        testDriveVeh = netId

        QBCore.Functions.Notify("Rental vehicle ready")

    end,
    vehicle,                                  -- ⬅ درست شد
    Config.Shops[tempShop]['RentDriveSpawn'],
    false)

    createTestDriveReturn()

end)


RegisterNetEvent('qrt-vehicleshop:client:TestDrive', function()
    if not inTestDrive and ClosestVehicle ~= 0 then
        inTestDrive = true
        local prevCoords = GetEntityCoords(PlayerPedId())
        tempShop = insideShop -- temp hacky way of setting the shop because it changes after the callback has returned since you are outside the zone
        QBCore.Functions.TriggerCallback('QBCore:Server:SpawnVehicle', function(netId)
            local veh = NetToVeh(netId)
            exports['qrt_fuel']:SetFuel(veh, 100)
            SetVehicleNumberPlateText(veh, 'TESTDRIVE')
            SetEntityHeading(veh, Config.Shops[tempShop]['TestDriveSpawn'].w)
            TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(veh))
            testDriveVeh = netId
            QBCore.Functions.Notify(Lang:t('general.testdrive_timenoti', { testdrivetime = Config.Shops[tempShop]['TestDriveTimeLimit'] }))
        end, Config.Shops[tempShop]['ShowroomVehicles'][ClosestVehicle].chosenVehicle, Config.Shops[tempShop]['TestDriveSpawn'], true)
        createTestDriveReturn()
        startTestDriveTimer(Config.Shops[tempShop]['TestDriveTimeLimit'] * 60, prevCoords)
    else
        QBCore.Functions.Notify(Lang:t('error.testdrive_alreadyin'), 'error')
    end
end)

RegisterNetEvent('qrt-vehicleshop:client:customTestDrive', function(data)
    if not inTestDrive then
        inTestDrive = true
        local vehicle = data
        local prevCoords = GetEntityCoords(PlayerPedId())
        tempShop = insideShop -- temp hacky way of setting the shop because it changes after the callback has returned since you are outside the zone
        QBCore.Functions.TriggerCallback('QBCore:Server:SpawnVehicle', function(netId)
            local veh = NetToVeh(netId)
            exports['qrt_fuel']:SetFuel(veh, 100)
            SetVehicleNumberPlateText(veh, 'TESTDRIVE')
            SetEntityHeading(veh, Config.Shops[tempShop]['TestDriveSpawn'].w)
            TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(veh))
            testDriveVeh = netId
            QBCore.Functions.Notify(Lang:t('general.testdrive_timenoti', { testdrivetime = Config.Shops[tempShop]['TestDriveTimeLimit'] }))
        end, vehicle, Config.Shops[tempShop]['TestDriveSpawn'], true)
        createTestDriveReturn()
        startTestDriveTimer(Config.Shops[tempShop]['TestDriveTimeLimit'] * 60, prevCoords)
    else
        QBCore.Functions.Notify(Lang:t('error.testdrive_alreadyin'), 'error')
    end
end)

RegisterNetEvent('qrt-vehicleshop:client:TestDriveReturn', function()

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped,false)

    if veh == 0 then
        QBCore.Functions.Notify("You must be in vehicle", "error")
        return
    end

    if Entity(veh).state.rental then

        DeleteEntity(veh)

        inTestDrive = false
        testDriveVeh = 0

        if testDriveZone then
            testDriveZone:destroy()
            testDriveZone = nil
        end

        QBCore.Functions.Notify("Vehicle returned")

    else
        QBCore.Functions.Notify("This is not a rental vehicle", "error")
    end
end)


RegisterNetEvent('qrt-vehicleshop:client:vehCategories', function(data)
    local catmenu = {}
    local firstvalue = nil
    local categoryMenu = {
        {
            header = Lang:t('menus.goback_header'),
            icon = 'fa-solid fa-angle-left',
            params = {
                event = Config.FilterByMake and 'qrt-vehicleshop:client:vehMakes' or 'qrt-vehicleshop:client:homeMenu'
            }
        }
    }
    for k, v in pairs(QBCore.Shared.Vehicles) do
        if type(QBCore.Shared.Vehicles[k]['shop']) == 'table' then
            for _, shop in pairs(QBCore.Shared.Vehicles[k]['shop']) do
                if shop == insideShop and (not Config.FilterByMake or QBCore.Shared.Vehicles[k]['brand'] == data.make) then
                    catmenu[v.category] = v.category
                    if firstvalue == nil then
                        firstvalue = v.category
                    end
                end
            end
        elseif QBCore.Shared.Vehicles[k]['shop'] == insideShop and (not Config.FilterByMake or QBCore.Shared.Vehicles[k]['brand'] == data.make) then
            catmenu[v.category] = v.category
            if firstvalue == nil then
                firstvalue = v.category
            end
        end
    end
    if Config.HideCategorySelectForOne and tablelength(catmenu) == 1 then
        TriggerEvent('qrt-vehicleshop:client:openVehCats', { catName = firstvalue, make = Config.FilterByMake and data.make, onecat = true })
        return
    end
    for k, v in pairs(catmenu) do
        categoryMenu[#categoryMenu + 1] = {
            header = v,
            icon = 'fa-solid fa-circle',
            params = {
                event = 'qrt-vehicleshop:client:openVehCats',
                args = {
                    catName = k,
                }
            }
        }
    end
    exports['qb-menu']:openMenu(categoryMenu, Config.SortAlphabetically, true)
end)

RegisterNetEvent('qrt-vehicleshop:client:openVehCats', function(data)
    local vehMenu = {
        {
            header = Lang:t('menus.goback_header'),
            icon = 'fa-solid fa-angle-left',
            params = {
                event = 'qrt-vehicleshop:client:vehCategories',
                args = {
                    make = data.make
                }
            }
        }
    }
    if data.onecat == true then
        vehMenu[1].params = {
            event = 'qrt-vehicleshop:client:vehMakes'
        }
    end
    for k, v in pairs(QBCore.Shared.Vehicles) do
        if QBCore.Shared.Vehicles[k]['category'] == data.catName then
            if type(QBCore.Shared.Vehicles[k]['shop']) == 'table' then
                for _, shop in pairs(QBCore.Shared.Vehicles[k]['shop']) do
                    if shop == insideShop then
                        vehMenu[#vehMenu + 1] = {
                            header = v.name,
                            txt = Lang:t('menus.veh_price') .. v.price,
                            icon = 'fa-solid fa-car-side',
                            params = {
                                isServer = true,
                                event = 'qrt-vehicleshop:server:swapVehicle',
                                args = {
                                    toVehicle = v.model,
                                    ClosestVehicle = ClosestVehicle,
                                    ClosestShop = insideShop
                                }
                            }
                        }
                    end
                end
            elseif QBCore.Shared.Vehicles[k]['shop'] == insideShop then
                vehMenu[#vehMenu + 1] = {
                    header = v.name,
                    txt = Lang:t('menus.veh_price') .. v.price,
                    icon = 'fa-solid fa-car-side',
                    params = {
                        isServer = true,
                        event = 'qrt-vehicleshop:server:swapVehicle',
                        args = {
                            toVehicle = v.model,
                            ClosestVehicle = ClosestVehicle,
                            ClosestShop = insideShop
                        }
                    }
                }
            end
        end
    end
    exports['qb-menu']:openMenu(vehMenu, Config.SortAlphabetically, true)
end)

RegisterNetEvent('qrt-vehicleshop:client:vehMakes', function()
    local makmenu = {}
    local makeMenu = {
        {
            header = Lang:t('menus.goback_header'),
            icon = 'fa-solid fa-angle-left',
            params = {
                event = 'qrt-vehicleshop:client:homeMenu'
            }
        }
    }
    for k, v in pairs(QBCore.Shared.Vehicles) do
        if type(QBCore.Shared.Vehicles[k]['shop']) == 'table' then
            for _, shop in pairs(QBCore.Shared.Vehicles[k]['shop']) do
                if shop == insideShop then
                    makmenu[v.brand] = v.brand
                end
            end
        elseif QBCore.Shared.Vehicles[k]['shop'] == insideShop then
            makmenu[v.brand] = v.brand
        end
    end
    for k, v in pairs(makmenu) do
        makeMenu[#makeMenu + 1] = {
            header = v,
            icon = 'fa-solid fa-circle',
            params = {
                event = 'qrt-vehicleshop:client:vehCategories',
                args = {
                    make = v
                }
            }
        }
    end
    exports['qb-menu']:openMenu(makeMenu, Config.SortAlphabetically, true)
end)

RegisterNetEvent('qrt-vehicleshop:client:openFinance', function(data)
    local dialog = exports['qb-input']:ShowInput({
        header = getVehBrand():upper() .. ' ' .. data.buyVehicle:upper() .. ' - $' .. data.price,
        submitText = Lang:t('menus.submit_text'),
        inputs = {
            {
                type = 'number',
                isRequired = true,
                name = 'downPayment',
                text = Lang:t('menus.financesubmit_downpayment') .. Config.MinimumDown .. '%'
            },
            {
                type = 'number',
                isRequired = true,
                name = 'paymentAmount',
                text = Lang:t('menus.financesubmit_totalpayment') .. Config.MaximumPayments
            }
        }
    })
    if dialog then
        if not dialog.downPayment or not dialog.paymentAmount then return end
        TriggerServerEvent('qrt-vehicleshop:server:financeVehicle', dialog.downPayment, dialog.paymentAmount, data.buyVehicle)
    end
end)

RegisterNetEvent('qrt-vehicleshop:client:openCustomFinance', function(data)
    local dialog = exports['qb-input']:ShowInput({
        header = getVehBrand():upper() .. ' ' .. data.vehicle:upper() .. ' - $' .. data.price,
        submitText = Lang:t('menus.submit_text'),
        inputs = {
            {
                type = 'number',
                isRequired = true,
                name = 'downPayment',
                text = Lang:t('menus.financesubmit_downpayment') .. Config.MinimumDown .. '%'
            },
            {
                type = 'number',
                isRequired = true,
                name = 'paymentAmount',
                text = Lang:t('menus.financesubmit_totalpayment') .. Config.MaximumPayments
            },
            {
                text = Lang:t('menus.submit_ID'),
                name = 'playerid',
                type = 'number',
                isRequired = true
            }
        }
    })
    if dialog then
        if not dialog.downPayment or not dialog.paymentAmount or not dialog.playerid then return end
        TriggerServerEvent('qrt-vehicleshop:server:sellfinanceVehicle', dialog.downPayment, dialog.paymentAmount, data.vehicle, dialog.playerid)
    end
end)

RegisterNetEvent('qrt-vehicleshop:client:swapVehicle', function(data)
    local shopName = data.ClosestShop
    if Config.Shops[shopName]['ShowroomVehicles'][data.ClosestVehicle].chosenVehicle ~= data.toVehicle then
        local closestVehicle, closestDistance = QBCore.Functions.GetClosestVehicle(vector3(Config.Shops[shopName]['ShowroomVehicles'][data.ClosestVehicle].coords.x, Config.Shops[shopName]['ShowroomVehicles'][data.ClosestVehicle].coords.y, Config.Shops[shopName]['ShowroomVehicles'][data.ClosestVehicle].coords.z))
        if closestVehicle == 0 then return end
        if closestDistance < 5 then DeleteEntity(closestVehicle) end
        while DoesEntityExist(closestVehicle) do
            Wait(50)
        end
        Config.Shops[shopName]['ShowroomVehicles'][data.ClosestVehicle].chosenVehicle = data.toVehicle
        local model = GetHashKey(data.toVehicle)
        RequestModel(model)
        while not HasModelLoaded(model) do
            Wait(50)
        end
        local veh = CreateVehicle(model, Config.Shops[shopName]['ShowroomVehicles'][data.ClosestVehicle].coords.x, Config.Shops[shopName]['ShowroomVehicles'][data.ClosestVehicle].coords.y, Config.Shops[shopName]['ShowroomVehicles'][data.ClosestVehicle].coords.z, false, false)
        while not DoesEntityExist(veh) do
            Wait(50)
        end
        SetModelAsNoLongerNeeded(model)
        SetVehicleOnGroundProperly(veh)
        SetEntityInvincible(veh, true)
        SetEntityHeading(veh, Config.Shops[shopName]['ShowroomVehicles'][data.ClosestVehicle].coords.w)
        SetVehicleDoorsLocked(veh, 3)
        FreezeEntityPosition(veh, true)
        SetVehicleNumberPlateText(veh, 'BUY ME')
        if Config.UsingTarget then createVehZones(shopName, veh) end
    end
end)

RegisterNetEvent('qrt-vehicleshop:client:buyShowroomVehicle', function(vehicle, plate)
    tempShop = insideShop -- temp hacky way of setting the shop because it changes after the callback has returned since you are outside the zone
    QBCore.Functions.TriggerCallback('QBCore:Server:SpawnVehicle', function(netId)
        local veh = NetToVeh(netId)
        exports['qrt_fuel']:SetFuel(veh, 100)
        SetVehicleNumberPlateText(veh, plate)
        SetEntityHeading(veh, Config.Shops[tempShop]['VehicleSpawn'].w)
        TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(veh))
        TriggerServerEvent('qb-mechanicjob:server:SaveVehicleProps', QBCore.Functions.GetVehicleProperties(veh))
    end, vehicle, Config.Shops[tempShop]['VehicleSpawn'], true)
end)

RegisterNetEvent('qrt-vehicleshop:client:getVehicles', function()
    QBCore.Functions.TriggerCallback('qrt-vehicleshop:server:getVehicles', function(vehicles)
        local ownedVehicles = {}
        for _, v in pairs(vehicles) do
            if v.balance ~= 0 then
                local name = QBCore.Shared.Vehicles[v.vehicle]['name']
                local plate = v.plate:upper()
                ownedVehicles[#ownedVehicles + 1] = {
                    header = name,
                    txt = Lang:t('menus.veh_platetxt') .. plate,
                    icon = 'fa-solid fa-car-side',
                    params = {
                        event = 'qrt-vehicleshop:client:getVehicleFinance',
                        args = {
                            vehiclePlate = plate,
                            balance = v.balance,
                            paymentsLeft = v.paymentsleft,
                            paymentAmount = v.paymentamount
                        }
                    }
                }
            end
        end
        if #ownedVehicles > 0 then
            exports['qb-menu']:openMenu(ownedVehicles)
        else
            QBCore.Functions.Notify(Lang:t('error.nofinanced'), 'error', 7500)
        end
    end)
end)

RegisterNetEvent('qrt-vehicleshop:client:getVehicleFinance', function(data)
    local vehFinance = {
        {
            header = Lang:t('menus.goback_header'),
            params = {
                event = 'qrt-vehicleshop:client:getVehicles'
            }
        },
        {
            isMenuHeader = true,
            icon = 'fa-solid fa-sack-dollar',
            header = Lang:t('menus.veh_finance_balance'),
            txt = Lang:t('menus.veh_finance_currency') .. comma_value(data.balance)
        },
        {
            isMenuHeader = true,
            icon = 'fa-solid fa-hashtag',
            header = Lang:t('menus.veh_finance_total'),
            txt = data.paymentsLeft
        },
        {
            isMenuHeader = true,
            icon = 'fa-solid fa-sack-dollar',
            header = Lang:t('menus.veh_finance_reccuring'),
            txt = Lang:t('menus.veh_finance_currency') .. comma_value(data.paymentAmount)
        },
        {
            header = Lang:t('menus.veh_finance_pay'),
            icon = 'fa-solid fa-hand-holding-dollar',
            params = {
                event = 'qrt-vehicleshop:client:financePayment',
                args = {
                    vehData = data,
                    paymentsLeft = data.paymentsleft,
                    paymentAmount = data.paymentamount
                }
            }
        },
        {
            header = Lang:t('menus.veh_finance_payoff'),
            icon = 'fa-solid fa-hand-holding-dollar',
            params = {
                isServer = true,
                event = 'qrt-vehicleshop:server:financePaymentFull',
                args = {
                    vehBalance = data.balance,
                    vehPlate = data.vehiclePlate
                }
            }
        },
    }
    exports['qb-menu']:openMenu(vehFinance)
end)

RegisterNetEvent('qrt-vehicleshop:client:financePayment', function(data)
    local dialog = exports['qb-input']:ShowInput({
        header = Lang:t('menus.veh_finance'),
        submitText = Lang:t('menus.veh_finance_pay'),
        inputs = {
            {
                type = 'number',
                isRequired = true,
                name = 'paymentAmount',
                text = Lang:t('menus.veh_finance_payment')
            }
        }
    })
    if dialog then
        if not dialog.paymentAmount then return end
        TriggerServerEvent('qrt-vehicleshop:server:financePayment', dialog.paymentAmount, data.vehData)
    end
end)

RegisterNetEvent('qrt-vehicleshop:client:openIdMenu', function(data)
    local dialog = exports['qb-input']:ShowInput({
        header = QBCore.Shared.Vehicles[data.vehicle]['name'],
        submitText = Lang:t('menus.submit_text'),
        inputs = {
            {
                text = Lang:t('menus.submit_ID'),
                name = 'playerid',
                type = 'number',
                isRequired = true
            }
        }
    })
    if dialog then
        if not dialog.playerid then return end
        if data.type == 'testDrive' then
            TriggerServerEvent('qrt-vehicleshop:server:customTestDrive', data.vehicle, dialog.playerid)
        elseif data.type == 'sellVehicle' then
            TriggerServerEvent('qrt-vehicleshop:server:sellShowroomVehicle', data.vehicle, dialog.playerid)
        elseif data.type == 'ta' then
            TriggerServerEvent('qrt-vehicleshop:server:customTestDriveTa', data.vehicle, dialog.playerid)
        end
    end
end)

-- Threads
CreateThread(function()
    for k, v in pairs(Config.Shops) do
        if v.showBlip then
            local Dealer = AddBlipForCoord(Config.Shops[k]['Location'])
            SetBlipSprite(Dealer, Config.Shops[k]['blipSprite'])
            SetBlipDisplay(Dealer, 4)
            SetBlipScale(Dealer, 0.70)
            SetBlipAsShortRange(Dealer, true)
            SetBlipColour(Dealer, Config.Shops[k]['blipColor'])
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(Config.Shops[k]['ShopLabel'])
            EndTextCommandSetBlipName(Dealer)
        end
    end
end)


RegisterNetEvent('qrt-vehicleshop:client:startTransfer', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh == 0 then
        QBCore.Functions.Notify('You must be sitting inside a vehicle', 'error')
        return
    end

    local plate = QBCore.Shared.Trim(GetVehicleNumberPlateText(veh))

    local dialog = exports['qb-input']:ShowInput({
        header = 'Vehicle Ownership Transfer',
        submitText = 'Transfer',
        inputs = {
            { 
                text = 'Buyer Server ID', 
                name = 'targetid', 
                type = 'number', 
                isRequired = true 
            }
        }
    })

    if not dialog or not dialog.targetid then return end

    TriggerServerEvent('qrt-vehicleshop:server:transferVehicleOwnership', plate, tonumber(dialog.targetid))
end)


-- ✅ حذف ماشین TestDrive از کلاینت (برای Finish Test Drive)
RegisterNetEvent('qrt-vehicleshop:client:removeTestDriveVeh', function(targetPlate)
    local vehs = GetGamePool('CVehicle')
    for _, v in ipairs(vehs) do
        if QBCore.Shared.Trim(GetVehicleNumberPlateText(v)) == targetPlate then
            if NetworkHasControlOfEntity(v) then
                DeleteEntity(v)
            else
                NetworkRequestControlOfEntity(v)
                local timeout = 0
                while not NetworkHasControlOfEntity(v) and timeout < 20 do
                    Wait(100)
                    timeout = timeout + 1
                end
                if NetworkHasControlOfEntity(v) then DeleteEntity(v) end
            end
            QBCore.Functions.Notify('🚨 Rental vehicle returned by dealership', 'error')
            break
        end
    end
end)

-- ==========================================
-- ✅ منوی اصلی Boss Menu (سه گزینه اصلی)
-- ==========================================
RegisterNetEvent('qrt-vehicleshop:client:openBossMenu', function()
    local menu = {
        { header = "🚗 Vehicle Shop Management", isMenuHeader = true, icon = "fa-solid fa-briefcase" },
        {
            header = "💰 Sold Vehicles (Cash)",
            txt = "View all vehicles sold by employees",
            icon = "fa-solid fa-cash-register",
            params = { event = "qrt-vehicleshop:client:openSoldVehiclesMenu" }
        },
        {
            header = "🚗 Active TestDrives (Rent)",
            txt = "View active test drives & finish them",
            icon = "fa-solid fa-key",
            params = { event = "qrt-vehicleshop:client:openTestDrivesMenu" }
        },
        {
            header = "📊 Financed Vehicles",
            txt = "View financed vehicles & payments status",
            icon = "fa-solid fa-file-invoice-dollar",
            params = { event = "qrt-vehicleshop:client:openFinancedMenu" }
        },
        { header = "Close", icon = "fa-solid fa-xmark", params = { event = "qb-menu:closeMenu" } }
    }
    exports['qb-menu']:openMenu(menu)
end)

-- ==========================================
-- ✅ زیرمنو 1: ماشین‌های فروخته شده
-- ==========================================
RegisterNetEvent('qrt-vehicleshop:client:openSoldVehiclesMenu', function()
    QBCore.Functions.TriggerCallback('qrt-vehicleshop:server:getSoldVehicles', function(data)
        local menu = {
            { header = "💰 Sold Vehicles History", isMenuHeader = true, icon = "fa-solid fa-cash-register" },
            { header = "← Back to Boss Menu", icon = "fa-solid fa-arrow-left", params = { event = "qrt-vehicleshop:client:openBossMenu" } }
        }
        if #data == 0 then
            table.insert(menu, { header = "No sold vehicles yet", txt = "Empty", icon = "fa-solid fa-circle-info", isMenuHeader = true })
        else
            for _, v in ipairs(data) do
                table.insert(menu, {
                    header = v.vehicle .. " | " .. v.plate,
                    txt = "👤 Buyer: " .. v.buyerName .. "\n💼 Sold by: " .. v.sellerName .. "\n💵 Type: Cash (Fully Paid)",
                    icon = "fa-solid fa-car-side"
                })
            end
        end
        exports['qb-menu']:openMenu(menu)
    end)
end)

-- ==========================================
-- ✅ زیرمنو 2: TestDrive های فعال (با قابلیت Finish)
-- ==========================================
RegisterNetEvent('qrt-vehicleshop:client:openTestDrivesMenu', function()
    QBCore.Functions.TriggerCallback('qrt-vehicleshop:server:getActiveTestDrives', function(data)
        local menu = {
            { header = "🚗 Active TestDrives", isMenuHeader = true, icon = "fa-solid fa-key" },
            { header = "← Back to Boss Menu", icon = "fa-solid fa-arrow-left", params = { event = "qrt-vehicleshop:client:openBossMenu" } }
        }
        if #data == 0 then
            table.insert(menu, { header = "No active test drives", txt = "Empty", icon = "fa-solid fa-circle-info", isMenuHeader = true })
        else
            for _, v in ipairs(data) do
                table.insert(menu, {
                    header = v.vehicle .. " | " .. v.plate,
                    txt = "👤 Renter: " .. v.buyerName .. "\n💼 Dealer: " .. v.dealerName .. "\n⏱️ Started: " .. v.duration,
                    icon = "fa-solid fa-stopwatch",
                    params = {
                        isServer = true,
                        event = "qrt-vehicleshop:server:finishTestDrive",
                        args = v.id
                    }
                })
            end
        end
        exports['qb-menu']:openMenu(menu)
    end)
end)

-- ==========================================
-- ✅ زیرمنو 3: ماشین‌های قسطی (Finance)
-- ==========================================
RegisterNetEvent('qrt-vehicleshop:client:openFinancedMenu', function()
    QBCore.Functions.TriggerCallback('qrt-vehicleshop:server:getFinancedVehicles', function(data)
        local menu = {
            { header = "📊 Financed Vehicles", isMenuHeader = true, icon = "fa-solid fa-file-invoice-dollar" },
            { header = "← Back to Boss Menu", icon = "fa-solid fa-arrow-left", params = { event = "qrt-vehicleshop:client:openBossMenu" } }
        }
        if #data == 0 then
            table.insert(menu, { header = "No financed vehicles", txt = "Empty", icon = "fa-solid fa-circle-info", isMenuHeader = true })
        else
            for _, v in ipairs(data) do
                table.insert(menu, {
                    header = v.vehicle .. " | " .. v.plate,
                    txt = "👤 Buyer: " .. v.buyerName .. 
                          "\n💼 Seller: " .. v.sellerName .. 
                          "\n💵 Balance: $" .. v.balance ..
                          "\n💳 Recurring: $" .. v.paymentAmount ..
                          "\n✅ Paid: " .. v.paid .. " | ❌ Unpaid: " .. v.unpaid .. " | 📊 Total: " .. v.total,
                    icon = "fa-solid fa-car"
                })
            end
        end
        exports['qb-menu']:openMenu(menu)
    end)
end)

-- ✅ آپدیت ایونت TestDriveTa برای دریافت پلاک از سرور
RegisterNetEvent('qrt-vehicleshop:client:TestDriveTa', function(vehicle, plate)
    if inTestDrive then
        QBCore.Functions.Notify("Already using a vehicle", "error")
        return
    end
    inTestDrive = true
    tempShop = insideShop
    QBCore.Functions.TriggerCallback('QBCore:Server:SpawnVehicle', function(netId)
        local veh = NetToVeh(netId)
        exports['qrt_fuel']:SetFuel(veh, 50)
        Entity(veh).state.rental = true
        SetVehicleNumberPlateText(veh, plate)
        SetEntityHeading(veh, Config.Shops[tempShop]['RentDriveSpawn'].w)
        TriggerEvent('vehiclekeys:client:SetOwner', plate)
        testDriveVeh = netId
        QBCore.Functions.Notify("Rental vehicle ready", "success")
    end, vehicle, Config.Shops[tempShop]['RentDriveSpawn'], false)
    createTestDriveReturn()
end)