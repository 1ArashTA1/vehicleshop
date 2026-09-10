-- Variables
local QBCore = exports['qb-core']:GetCoreObject()
local financetimer = {}

-- Handlers
-- Store game time for player when they load
RegisterNetEvent('qrt-vehicleshop:server:addPlayer', function(citizenid)
    financetimer[citizenid] = os.time()
end)

-- Deduct stored game time from player on logout
RegisterNetEvent('qrt-vehicleshop:server:removePlayer', function(citizenid)
    if financetimer[citizenid] then
        local playTime = financetimer[citizenid]
        local financetime = MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ?', {citizenid})
        for _, v in pairs(financetime) do
            if v.balance >= 1 then
                local newTime = (v.financetime-((os.time()-playTime)/60))
                if newTime < 0 then newTime = 0 end
                MySQL.update('UPDATE player_vehicles SET financetime = ? WHERE plate = ?', {math.ceil(newTime), v.plate})
            end
        end
    end
    financetimer[citizenid] = nil
end)

-- Deduct stored game time from player on quit because we can't get citizenid
AddEventHandler('playerDropped', function()
    local src = source
    local license
    for _, v in pairs(GetPlayerIdentifiers(src)) do
        if string.sub(v, 1, string.len("license:")) == "license:" then
            license = v
        end
    end
    if license then
        local vehicles = MySQL.query.await('SELECT * FROM player_vehicles WHERE license = ?', {license})
        if vehicles then
            for _, v in pairs(vehicles) do
                local playTime = financetimer[v.citizenid]
                if v.balance >= 1 and playTime then
                    local newTime = (v.financetime-((os.time()-playTime)/60))
                    if newTime < 0 then newTime = 0 end
                    MySQL.update('UPDATE player_vehicles SET financetime = ? WHERE plate = ?', {math.ceil(newTime), v.plate})
                end
            end
            if vehicles[1] and financetimer[vehicles[1].citizenid] then financetimer[vehicles[1].citizenid] = nil end
        end
    end
end)

-- Functions
local function round(x)
    return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
end

local function calculateFinance(vehiclePrice, downPayment, paymentamount)
    local balance = vehiclePrice - downPayment
    local vehPaymentAmount = balance / paymentamount
    return round(balance), round(vehPaymentAmount)
end

local function calculateNewFinance(paymentAmount, vehData)
    local newBalance = tonumber(vehData.balance - paymentAmount)
    local minusPayment = vehData.paymentsLeft - 1
    local newPaymentsLeft = newBalance / minusPayment
    local newPayment = newBalance / newPaymentsLeft
    return round(newBalance), round(newPayment), newPaymentsLeft
end

local function GeneratePlate()
    local plate = QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(2)
    local result = MySQL.scalar.await('SELECT plate FROM player_vehicles WHERE plate = ?', {plate})
    if result then
        return GeneratePlate()
    else
        return plate:upper()
    end
end

local function comma_value(amount)
    local formatted = amount
    local k
    while true do
        formatted, k = string.gsub(formatted, '^(-?%d+)(%d%d%d)', '%1,%2')
        if (k == 0) then
            break
        end
    end
    return formatted
end

-- Callbacks
QBCore.Functions.CreateCallback('qrt-vehicleshop:server:getVehicles', function(source, cb)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if player then
        local vehicles = MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ?', {player.PlayerData.citizenid})
        if vehicles[1] then
            cb(vehicles)
        end
    end
end)

-- Events

-- Brute force vehicle deletion
RegisterNetEvent('qrt-vehicleshop:server:deleteVehicle', function (netId)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    DeleteEntity(vehicle)
end)

-- Sync vehicle for other players
RegisterNetEvent('qrt-vehicleshop:server:swapVehicle', function(data)
    local src = source
    TriggerClientEvent('qrt-vehicleshop:client:swapVehicle', -1, data)
    Wait(1500)-- let new car spawn
    TriggerClientEvent('qrt-vehicleshop:client:homeMenu', src)-- reopen main menu
end)

-- Send customer for test drive
RegisterNetEvent('qrt-vehicleshop:server:customTestDrive', function(vehicle, playerid)
    local src = source
    local target = tonumber(playerid)
    if not QBCore.Functions.GetPlayer(target) then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.Invalid_ID'), 'error')
        return
    end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target))) < 3 then
        TriggerClientEvent('qrt-vehicleshop:client:customTestDrive', target, vehicle)
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.playertoofar'), 'error')
    end
end)

RegisterNetEvent('qrt-vehicleshop:server:customTestDriveTa', function(vehicle, playerid)
    local src = source
    local target = tonumber(playerid)
    if not QBCore.Functions.GetPlayer(target) then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.Invalid_ID'), 'error')
        return
    end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target))) < 3 then
        TriggerClientEvent('qrt-vehicleshop:client:TestDriveTa', target, vehicle)
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.playertoofar'), 'error')
    end
end)

-- Make a finance payment
RegisterNetEvent('qrt-vehicleshop:server:financePayment', function(paymentAmount, vehData)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local cash = player.PlayerData.money['cash']
    local bank = player.PlayerData.money['bank']
    local plate = vehData.vehiclePlate
    paymentAmount = tonumber(paymentAmount)
    local minPayment = tonumber(vehData.paymentAmount)
    local timer = (Config.PaymentInterval * 60)
    local newBalance, newPaymentsLeft, newPayment = calculateNewFinance(paymentAmount, vehData)
    if newBalance > 0 then
        if player and paymentAmount >= minPayment then
            if cash >= paymentAmount then
                player.Functions.RemoveMoney('cash', paymentAmount)
                MySQL.update('UPDATE player_vehicles SET balance = ?, paymentamount = ?, paymentsleft = ?, financetime = ? WHERE plate = ?', {newBalance, newPayment, newPaymentsLeft, timer, plate})
            elseif bank >= paymentAmount then
                player.Functions.RemoveMoney('bank', paymentAmount)
                MySQL.update('UPDATE player_vehicles SET balance = ?, paymentamount = ?, paymentsleft = ?, financetime = ? WHERE plate = ?', {newBalance, newPayment, newPaymentsLeft, timer, plate})
            else
                TriggerClientEvent('QBCore:Notify', src, Lang:t('error.notenoughmoney'), 'error')
            end
        else
            TriggerClientEvent('QBCore:Notify', src, Lang:t('error.minimumallowed') .. comma_value(minPayment), 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.overpaid'), 'error')
    end
end)


-- Pay off vehice in full
RegisterNetEvent('qrt-vehicleshop:server:financePaymentFull', function(data)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local cash = player.PlayerData.money['cash']
    local bank = player.PlayerData.money['bank']
    local vehBalance = data.vehBalance
    local vehPlate = data.vehPlate
    if player and vehBalance ~= 0 then
        if cash >= vehBalance then
            player.Functions.RemoveMoney('cash', vehBalance)
            MySQL.update('UPDATE player_vehicles SET balance = ?, paymentamount = ?, paymentsleft = ?, financetime = ? WHERE plate = ?', {0, 0, 0, 0, vehPlate})
        elseif bank >= vehBalance then
            player.Functions.RemoveMoney('bank', vehBalance)
            MySQL.update('UPDATE player_vehicles SET balance = ?, paymentamount = ?, paymentsleft = ?, financetime = ? WHERE plate = ?', {0, 0, 0, 0, vehPlate})
        else
            TriggerClientEvent('QBCore:Notify', src, Lang:t('error.notenoughmoney'), 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.alreadypaid'), 'error')
    end
end)

-- Buy public vehicle outright
RegisterNetEvent('qrt-vehicleshop:server:buyShowroomVehicle', function(data)
    local src = source
    if not data or not data.buyVehicle then return end

    local vehicle = data.buyVehicle
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- بررسی وجود خودرو در shared
    if not QBCore.Shared.Vehicles[vehicle] then
        print("[Vehicleshop] Invalid vehicle attempted purchase:", vehicle)
        return
    end

    local vehiclePrice = QBCore.Shared.Vehicles[vehicle].price
    local plate = GeneratePlate()
    local paymentType = nil

    local cash = Player.PlayerData.money.cash
    local bank = Player.PlayerData.money.bank

    -- تعیین نوع پرداخت
    if cash >= vehiclePrice then
        paymentType = "cash"
        Player.Functions.RemoveMoney('cash', vehiclePrice, 'vehicle-bought-in-showroom')
    elseif bank >= vehiclePrice then
        paymentType = "bank"
        Player.Functions.RemoveMoney('bank', vehiclePrice, 'vehicle-bought-in-showroom')
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.notenoughmoney'), 'error')
        return
    end

    -- ثبت ماشین در دیتابیس
    MySQL.insert('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        Player.PlayerData.license,
        Player.PlayerData.citizenid,
        vehicle,
        GetHashKey(vehicle),
        '{}',
        plate,
        'pillboxgarage',
        0
    })

    -- ✅ ثبت History فروش اگر خریدار توسط کارمند فروخته شده باشد
    if Player.PlayerData.job.name == "cardealer" then
        MySQL.insert([[
            INSERT INTO dealer_sales_history 
            (dealer_citizenid, dealer_name, buyer_citizenid, buyer_name, vehicle, plate, price, payment_type)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            Player.PlayerData.citizenid,
            Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
            Player.PlayerData.citizenid,
            Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
            vehicle,
            plate,
            vehiclePrice,
            paymentType
        })
    end

    -- نوتیفیکیشن و تحویل ماشین
    TriggerClientEvent('QBCore:Notify', src, Lang:t('success.purchased'), 'success')
    TriggerClientEvent('qrt-vehicleshop:client:buyShowroomVehicle', src, vehicle, plate)

    print(string.format(
        "[VEHICLE PURCHASE] %s bought %s (%s) for $%s via %s",
        Player.PlayerData.citizenid,
        vehicle,
        plate,
        vehiclePrice,
        paymentType
    ))
end)

-- Finance public vehicle (Self Finance)
RegisterNetEvent('qrt-vehicleshop:server:financeVehicle', function(downPayment, paymentAmount, vehicle)
    local src = source
    downPayment = tonumber(downPayment)
    paymentAmount = tonumber(paymentAmount)
    local pData = QBCore.Functions.GetPlayer(src)
    local cid = pData.PlayerData.citizenid
    local cash = pData.PlayerData.money['cash']
    local bank = pData.PlayerData.money['bank']
    local vehiclePrice = QBCore.Shared.Vehicles[vehicle]['price']
    local timer = (Config.PaymentInterval * 60)
    local minDown = tonumber(round((Config.MinimumDown / 100) * vehiclePrice))
    if downPayment > vehiclePrice then return TriggerClientEvent('QBCore:Notify', src, Lang:t('error.notworth'), 'error') end
    if downPayment < minDown then return TriggerClientEvent('QBCore:Notify', src, Lang:t('error.downtoosmall'), 'error') end
    if paymentAmount > Config.MaximumPayments then return TriggerClientEvent('QBCore:Notify', src, Lang:t('error.exceededmax'), 'error') end
    local plate = GeneratePlate()
    local balance, vehPaymentAmount = calculateFinance(vehiclePrice, downPayment, paymentAmount)
    
    -- ✅ کوئری اصلاح شده برای خرید قسطی شخصی
    local insertQuery = 'INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state, balance, paymentamount, paymentsleft, financetime, seller_citizenid) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
    local insertValues = {
        pData.PlayerData.license, cid, vehicle, GetHashKey(vehicle), '{}', plate, 'pillboxgarage', 0,
        balance, vehPaymentAmount, paymentAmount, timer, nil -- nil چون خودش خریده
    }

    if cash >= downPayment then
        MySQL.insert(insertQuery, insertValues)
        TriggerClientEvent('QBCore:Notify', src, Lang:t('success.purchased'), 'success')
        TriggerClientEvent('qrt-vehicleshop:client:buyShowroomVehicle', src, vehicle, plate)
        pData.Functions.RemoveMoney('cash', downPayment, 'vehicle-bought-in-showroom')
    elseif bank >= downPayment then
        MySQL.insert(insertQuery, insertValues)
        TriggerClientEvent('QBCore:Notify', src, Lang:t('success.purchased'), 'success')
        TriggerClientEvent('qrt-vehicleshop:client:buyShowroomVehicle', src, vehicle, plate)
        pData.Functions.RemoveMoney('bank', downPayment, 'vehicle-bought-in-showroom')
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.notenoughmoney'), 'error')
    end
end)

-- Sell vehicle to customer (Cash/Bank)
RegisterNetEvent('qrt-vehicleshop:server:sellShowroomVehicle', function(data, playerid)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local target = QBCore.Functions.GetPlayer(tonumber(playerid))
    if not target then return TriggerClientEvent('QBCore:Notify', src, Lang:t('error.Invalid_ID'), 'error') end
    
    -- ✅ بررسی وجود آیتم vehicle_transfer_paper
    if not player.Functions.GetItemByName('vehicle_transfer_paper') then
        return TriggerClientEvent('QBCore:Notify', src, '❌ You need a vehicle transfer paper to sell this vehicle', 'error')
    end
    
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target.PlayerData.source))) < 3 then
        local cid = target.PlayerData.citizenid
        local cash = target.PlayerData.money['cash']
        local bank = target.PlayerData.money['bank']
        local vehicle = data
        local vehiclePrice = QBCore.Shared.Vehicles[vehicle]['price']
        local commission = round(vehiclePrice * Config.Commission)
        local plate = GeneratePlate()
        
        -- ✅ کوئری اصلاح شده برای فروش نقدی توسط کارمند
        local insertQuery = 'INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state, seller_citizenid) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
        local insertValues = {
            target.PlayerData.license, cid, vehicle, GetHashKey(vehicle), '{}', plate, 'pillboxgarage', 0, player.PlayerData.citizenid
        }

        if cash >= tonumber(vehiclePrice) then
            MySQL.insert(insertQuery, insertValues)
            TriggerClientEvent('qrt-vehicleshop:client:buyShowroomVehicle', target.PlayerData.source, vehicle, plate)
            target.Functions.RemoveMoney('cash', vehiclePrice, 'vehicle-bought-in-showroom')
            
            -- ✅ حذف آیتم vehicle_transfer_paper پس از فروش موفق
            player.Functions.RemoveItem('vehicle_transfer_paper', 1)
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['vehicle_transfer_paper'], 'remove')
            
            -- ✅ ارسال کمیسیون به حساب شغل cardealer
            exports['qrt-banking']:AddMoney('cardealer', commission, 'Commission from vehicle sale')
            TriggerClientEvent('QBCore:Notify', src, Lang:t('success.earned_commission', {amount = comma_value(commission)}), 'success')
            if GetResourceState('qrt-management') == 'started' then
                exports['qrt-management']:AddMoney(player.PlayerData.job.name, vehiclePrice)
            end
            TriggerClientEvent('QBCore:Notify', target.PlayerData.source, Lang:t('success.purchased'), 'success')
            
        elseif bank >= tonumber(vehiclePrice) then
            MySQL.insert(insertQuery, insertValues)
            TriggerClientEvent('qrt-vehicleshop:client:buyShowroomVehicle', target.PlayerData.source, vehicle, plate)
            target.Functions.RemoveMoney('bank', vehiclePrice, 'vehicle-bought-in-showroom')
            
            -- ✅ حذف آیتم vehicle_transfer_paper پس از فروش موفق
            player.Functions.RemoveItem('vehicle_transfer_paper', 1)
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['vehicle_transfer_paper'], 'remove')
            
            -- ✅ ارسال کمیسیون به حساب شغل cardealer
            exports['qrt-banking']:AddMoney('cardealer', commission, 'Commission from vehicle sale')
            TriggerClientEvent('QBCore:Notify', src, Lang:t('success.earned_commission', {amount = comma_value(commission)}), 'success')
            if GetResourceState('qrt-management') == 'started' then
                exports['qrt-management']:AddMoney(player.PlayerData.job.name, vehiclePrice)
            end
            TriggerClientEvent('QBCore:Notify', target.PlayerData.source, Lang:t('success.purchased'), 'success')
        else
            TriggerClientEvent('QBCore:Notify', src, Lang:t('error.notenoughmoney'), 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.playertoofar'), 'error')
    end
end)

-- Finance vehicle to customer
RegisterNetEvent('qrt-vehicleshop:server:sellfinanceVehicle', function(downPayment, paymentAmount, vehicle, playerid)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local target = QBCore.Functions.GetPlayer(tonumber(playerid))
    if not target then return TriggerClientEvent('QBCore:Notify', src, Lang:t('error.Invalid_ID'), 'error') end
    
    -- ✅ بررسی وجود آیتم vehicle_transfer_paper
    if not player.Functions.GetItemByName('vehicle_transfer_paper') then
        return TriggerClientEvent('QBCore:Notify', src, '❌ You need a vehicle transfer paper to sell this vehicle', 'error')
    end
    
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target.PlayerData.source))) < 3 then
        downPayment = tonumber(downPayment)
        paymentAmount = tonumber(paymentAmount)
        local cid = target.PlayerData.citizenid
        local cash = target.PlayerData.money['cash']
        local bank = target.PlayerData.money['bank']
        local vehiclePrice = QBCore.Shared.Vehicles[vehicle]['price']
        local timer = (Config.PaymentInterval * 60)
        local minDown = tonumber(round((Config.MinimumDown / 100) * vehiclePrice))
        if downPayment > vehiclePrice then return TriggerClientEvent('QBCore:Notify', src, Lang:t('error.notworth'), 'error') end
        if downPayment < minDown then return TriggerClientEvent('QBCore:Notify', src, Lang:t('error.downtoosmall'), 'error') end
        if paymentAmount > Config.MaximumPayments then return TriggerClientEvent('QBCore:Notify', src, Lang:t('error.exceededmax'), 'error') end
        local commission = round(vehiclePrice * Config.FinanceCommission)
        local plate = GeneratePlate()
        local balance, vehPaymentAmount = calculateFinance(vehiclePrice, downPayment, paymentAmount)
        
        -- ✅ کوئری اصلاح شده برای فروش قسطی توسط کارمند
        local insertQuery = 'INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state, balance, paymentamount, paymentsleft, financetime, seller_citizenid) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
        local insertValues = {
            target.PlayerData.license, cid, vehicle, GetHashKey(vehicle), '{}', plate, 'pillboxgarage', 0,
            balance, vehPaymentAmount, paymentAmount, timer, player.PlayerData.citizenid
        }

        if cash >= downPayment then
            MySQL.insert(insertQuery, insertValues)
            TriggerClientEvent('qrt-vehicleshop:client:buyShowroomVehicle', target.PlayerData.source, vehicle, plate)
            target.Functions.RemoveMoney('cash', downPayment, 'vehicle-bought-in-showroom')
            
            -- ✅ حذف آیتم vehicle_transfer_paper پس از فروش موفق
            player.Functions.RemoveItem('vehicle_transfer_paper', 1)
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['vehicle_transfer_paper'], 'remove')
            
            -- ✅ ارسال کمیسیون به حساب شغل cardealer
            exports['qrt-banking']:AddMoney('cardealer', commission, 'Commission from finance sale')
            TriggerClientEvent('QBCore:Notify', src, Lang:t('success.earned_commission', {amount = comma_value(commission)}), 'success')
            if GetResourceState('qrt-management') == 'started' then
                exports['qrt-management']:AddMoney(player.PlayerData.job.name, vehiclePrice)
            end
            TriggerClientEvent('QBCore:Notify', target.PlayerData.source, Lang:t('success.purchased'), 'success')
            
        elseif bank >= downPayment then
            MySQL.insert(insertQuery, insertValues)
            TriggerClientEvent('qrt-vehicleshop:client:buyShowroomVehicle', target.PlayerData.source, vehicle, plate)
            target.Functions.RemoveMoney('bank', downPayment, 'vehicle-bought-in-showroom')
            
            -- ✅ حذف آیتم vehicle_transfer_paper پس از فروش موفق
            player.Functions.RemoveItem('vehicle_transfer_paper', 1)
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['vehicle_transfer_paper'], 'remove')
            
            -- ✅ ارسال کمیسیون به حساب شغل cardealer
            exports['qrt-banking']:AddMoney('cardealer', commission, 'Commission from finance sale')
            TriggerClientEvent('QBCore:Notify', src, Lang:t('success.earned_commission', {amount = comma_value(commission)}), 'success')
            if GetResourceState('qrt-management') == 'started' then
                exports['qrt-management']:AddMoney(player.PlayerData.job.name, vehiclePrice)
            end
            TriggerClientEvent('QBCore:Notify', target.PlayerData.source, Lang:t('success.purchased'), 'success')
        else
            TriggerClientEvent('QBCore:Notify', src, Lang:t('error.notenoughmoney'), 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.playertoofar'), 'error')
    end
end)

-- Check if payment is due
RegisterNetEvent('qrt-vehicleshop:server:checkFinance', function()
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local query = 'SELECT * FROM player_vehicles WHERE citizenid = ? AND balance > 0 AND financetime < 1'
    local result = MySQL.query.await(query, {player.PlayerData.citizenid})
    if result[1] then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('general.paymentduein', {time = Config.PaymentWarning}))
        Wait(Config.PaymentWarning * 60000)
        local vehicles = MySQL.query.await(query, {player.PlayerData.citizenid})
        for _, v in pairs(vehicles) do
            local plate = v.plate
            MySQL.query('DELETE FROM player_vehicles WHERE plate = @plate', {['@plate'] = plate})
            --MySQL.update('UPDATE player_vehicles SET citizenid = ? WHERE plate = ?', {'REPO-'..v.citizenid, plate}) -- Use this if you don't want them to be deleted
            TriggerClientEvent('QBCore:Notify', src, Lang:t('error.repossessed', {plate = plate}), 'error')
        end
    end
end)

-- Transfer vehicle to player in passenger seat
QBCore.Commands.Add('transfervehicle', Lang:t('general.command_transfervehicle'), {{name = 'ID', help = Lang:t('general.command_transfervehicle_help')}, {name = 'amount', help = Lang:t('general.command_transfervehicle_amount')}}, false, function(source, args)
    local src = source
    local buyerId = tonumber(args[1])
    local sellAmount = tonumber(args[2])
    if buyerId == 0 then return TriggerClientEvent('QBCore:Notify', src, Lang:t('error.Invalid_ID'), 'error') end
    local ped = GetPlayerPed(src)
    local targetPed = GetPlayerPed(buyerId)
    if targetPed == 0 then return TriggerClientEvent('QBCore:Notify', src, Lang:t('error.buyerinfo'), 'error') end
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then return TriggerClientEvent('QBCore:Notify', src, Lang:t('error.notinveh'), 'error') end
    local plate = QBCore.Shared.Trim(GetVehicleNumberPlateText(vehicle))
    if not plate then return TriggerClientEvent('QBCore:Notify', src, Lang:t('error.vehinfo'), 'error') end
    local player = QBCore.Functions.GetPlayer(src)
    local target = QBCore.Functions.GetPlayer(buyerId)
    local row = MySQL.single.await('SELECT * FROM player_vehicles WHERE plate = ?', {plate})
    if Config.PreventFinanceSelling then
        if row.balance > 0 then return TriggerClientEvent('QBCore:Notify', src, Lang:t('error.financed'), 'error') end
    end
    if row.citizenid ~= player.PlayerData.citizenid then return TriggerClientEvent('QBCore:Notify', src, Lang:t('error.notown'), 'error') end
    if #(GetEntityCoords(ped) - GetEntityCoords(targetPed)) > 5.0 then return TriggerClientEvent('QBCore:Notify', src, Lang:t('error.playertoofar'), 'error') end
    local targetcid = target.PlayerData.citizenid
    local targetlicense = QBCore.Functions.GetIdentifier(target.PlayerData.source, 'license')
    if not target then return TriggerClientEvent('QBCore:Notify', src, Lang:t('error.buyerinfo'), 'error') end
    if not sellAmount then
        MySQL.update('UPDATE player_vehicles SET citizenid = ?, license = ? WHERE plate = ?', {targetcid, targetlicense, plate})
        TriggerClientEvent('QBCore:Notify', src, Lang:t('success.gifted'), 'success')
        TriggerClientEvent('vehiclekeys:client:SetOwner', buyerId, plate)
        TriggerClientEvent('QBCore:Notify', buyerId, Lang:t('success.received_gift'), 'success')
        return
    end
    if target.Functions.GetMoney('cash') > sellAmount then
        MySQL.update('UPDATE player_vehicles SET citizenid = ?, license = ? WHERE plate = ?', {targetcid, targetlicense, plate})
        player.Functions.AddMoney('cash', sellAmount)
        target.Functions.RemoveMoney('cash', sellAmount)
        TriggerClientEvent('QBCore:Notify', src, Lang:t('success.soldfor') .. comma_value(sellAmount), 'success')
        TriggerClientEvent('vehiclekeys:client:SetOwner', buyerId, plate)
        TriggerClientEvent('QBCore:Notify', buyerId, Lang:t('success.boughtfor') .. comma_value(sellAmount), 'success')
    elseif target.Functions.GetMoney('bank') > sellAmount then
        MySQL.update('UPDATE player_vehicles SET citizenid = ?, license = ? WHERE plate = ?', {targetcid, targetlicense, plate})
        player.Functions.AddMoney('bank', sellAmount)
        target.Functions.RemoveMoney('bank', sellAmount)
        TriggerClientEvent('QBCore:Notify', src, Lang:t('success.soldfor') .. comma_value(sellAmount), 'success')
        TriggerClientEvent('vehiclekeys:client:SetOwner', buyerId, plate)
        TriggerClientEvent('QBCore:Notify', buyerId, Lang:t('success.boughtfor') .. comma_value(sellAmount), 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.buyertoopoor'), 'error')
    end
end)


-- QBCore.Functions.CreateUseableItem('vehicle_transfer_paper', function(source)
--     local src = source
--     local Player = QBCore.Functions.GetPlayer(src)

--     if Player.PlayerData.job.name ~= "cardealer" then
--         TriggerClientEvent('QBCore:Notify', src, "You are not a car dealer", "error")
--         return
--     end

--     TriggerClientEvent('vehicleshop:client:startTransfer', src)
-- end)

RegisterNetEvent('qrt-vehicleshop:server:transferVehicleOwnership', function(plate, targetId)
    local src = source
    local Dealer = QBCore.Functions.GetPlayer(src)
    local Buyer = QBCore.Functions.GetPlayer(tonumber(targetId))

    if not Dealer or not Buyer then
        TriggerClientEvent('QBCore:Notify', src, 'Player not found', 'error')
        return
    end

    if Dealer.PlayerData.job.name ~= 'cardealer' then
        TriggerClientEvent('QBCore:Notify', src, 'You are not a car dealer', 'error')
        return
    end

    -- check paper
    if not Dealer.Functions.RemoveItem('vehicle_transfer_paper', 1) then
        TriggerClientEvent('QBCore:Notify', src, 'You do not have transfer paper', 'error')
        return
    end
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['vehicle_transfer_paper'], 'remove')

    -- update database
    MySQL.update('UPDATE player_vehicles SET citizenid = ?, license = ? WHERE plate = ?',
        { Buyer.PlayerData.citizenid, Buyer.PlayerData.license, plate })

    TriggerClientEvent('vehiclekeys:client:SetOwner', Buyer.PlayerData.source, plate)

    TriggerClientEvent('QBCore:Notify', src, 'Ownership transferred!', 'success')
    TriggerClientEvent('QBCore:Notify', Buyer.PlayerData.source, 'This vehicle is now yours!', 'success')

    print('[qrt-vehicleshop] Vehicle ownership transferred | Plate:', plate, '| From:', Dealer.PlayerData.citizenid, '| To:', Buyer.PlayerData.citizenid)
end)

QBCore.Functions.CreateUseableItem('vehicle_transfer_paper', function(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if Player.PlayerData.job.name ~= 'cardealer' then
        TriggerClientEvent('QBCore:Notify', src, 'You are not a car dealer', 'error')
        return
    end

    TriggerClientEvent('qrt-vehicleshop:client:startTransfer', src)
end)


-- ==========================================
-- ✅ سیستم TestDriveTa (بدون تداخل)
-- ==========================================
RegisterNetEvent('qrt-vehicleshop:server:customTestDriveTa', function(vehicle, playerid)
    local src = source
    local target = tonumber(playerid)
    if not QBCore.Functions.GetPlayer(target) then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.Invalid_ID'), 'error')
        return
    end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target))) < 3 then
        local dealer = QBCore.Functions.GetPlayer(src)
        local buyer = QBCore.Functions.GetPlayer(target)
        local plate = 'RENT' .. math.random(1000, 9999)
        
        -- ثبت در دیتابیس
        MySQL.insert('INSERT INTO dealer_active_testdrives (buyer_citizenid, dealer_citizenid, plate, vehicle_model, start_time) VALUES (?, ?, ?, ?, ?)', {
            buyer.PlayerData.citizenid, dealer.PlayerData.citizenid, plate, vehicle, os.time()
        })
        
        TriggerClientEvent('qrt-vehicleshop:client:TestDriveTa', target, vehicle, plate)
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.playertoofar'), 'error')
    end
end)

-- ==========================================
-- ✅ Callback های Boss Menu (سه منوی اصلی)
-- ==========================================

-- 1️⃣ لیست ماشین‌های فروخته شده نقدی توسط کارمند (Sold Vehicles)
QBCore.Functions.CreateCallback('qrt-vehicleshop:server:getSoldVehicles', function(source, cb)
    local result = MySQL.query.await([[
        SELECT pv.plate, pv.vehicle, pv.citizenid, pv.seller_citizenid, p.charinfo as buyer_char, s.charinfo as seller_char
        FROM player_vehicles pv
        LEFT JOIN players p ON pv.citizenid = p.citizenid
        LEFT JOIN players s ON pv.seller_citizenid = s.citizenid
        WHERE pv.seller_citizenid IS NOT NULL AND (pv.balance = 0 OR pv.balance IS NULL)
        ORDER BY pv.id DESC
        LIMIT 50
    ]])
    
    local list = {}
    for _, v in ipairs(result) do
        local buyer = v.buyer_char and json.decode(v.buyer_char) or {firstname = 'Unknown', lastname = ''}
        local seller = v.seller_char and json.decode(v.seller_char) or {firstname = 'Unknown', lastname = ''}
        table.insert(list, {
            plate = v.plate,
            vehicle = QBCore.Shared.Vehicles[v.vehicle] and QBCore.Shared.Vehicles[v.vehicle].name or v.vehicle,
            buyerName = buyer.firstname .. ' ' .. buyer.lastname,
            sellerName = seller.firstname .. ' ' .. seller.lastname,
            type = 'Sold (Cash)'
        })
    end
    cb(list)
end)

-- 2️⃣ لیست ماشین‌های فعال TestDriveTa
QBCore.Functions.CreateCallback('qrt-vehicleshop:server:getActiveTestDrives', function(source, cb)
    local result = MySQL.query.await('SELECT * FROM dealer_active_testdrives')
    local list = {}
    for _, v in ipairs(result) do
        local buyerChar = MySQL.scalar.await('SELECT charinfo FROM players WHERE citizenid = ?', {v.buyer_citizenid})
        local dealerChar = MySQL.scalar.await('SELECT charinfo FROM players WHERE citizenid = ?', {v.dealer_citizenid})
        local bInfo = buyerChar and json.decode(buyerChar) or {firstname = 'Unknown', lastname = ''}
        local dInfo = dealerChar and json.decode(dealerChar) or {firstname = 'Unknown', lastname = ''}
        
        table.insert(list, {
            id = v.id,
            plate = v.plate,
            vehicle = QBCore.Shared.Vehicles[v.vehicle_model] and QBCore.Shared.Vehicles[v.vehicle_model].name or v.vehicle_model,
            buyerCid = v.buyer_citizenid,
            buyerName = bInfo.firstname .. ' ' .. bInfo.lastname,
            dealerName = dInfo.firstname .. ' ' .. dInfo.lastname,
            duration = math.floor((os.time() - v.start_time) / 60) .. ' min ago'
        })
    end
    cb(list)
end)

-- 3️⃣ لیست ماشین‌های قسطی (Financed Vehicles)
QBCore.Functions.CreateCallback('qrt-vehicleshop:server:getFinancedVehicles', function(source, cb)
    local result = MySQL.query.await([[
        SELECT pv.plate, pv.vehicle, pv.balance, pv.paymentamount, pv.paymentsleft, pv.total_payments, 
               pv.citizenid, pv.seller_citizenid, p.charinfo as buyer_char, s.charinfo as seller_char
        FROM player_vehicles pv
        LEFT JOIN players p ON pv.citizenid = p.citizenid
        LEFT JOIN players s ON pv.seller_citizenid = s.citizenid
        WHERE pv.balance > 0
        ORDER BY pv.id DESC
    ]])
    
    local list = {}
    for _, v in ipairs(result) do
        local buyer = v.buyer_char and json.decode(v.buyer_char) or {firstname = 'Unknown', lastname = ''}
        local seller = v.seller_char and json.decode(v.seller_char) or {firstname = 'Self/System', lastname = ''}
        local total = v.total_payments > 0 and v.total_payments or (v.paymentsleft + 1)
        local paid = total - v.paymentsleft
        table.insert(list, {
            plate = v.plate,
            vehicle = QBCore.Shared.Vehicles[v.vehicle] and QBCore.Shared.Vehicles[v.vehicle].name or v.vehicle,
            buyerName = buyer.firstname .. ' ' .. buyer.lastname,
            sellerName = seller.firstname .. ' ' .. seller.lastname,
            balance = v.balance,
            paymentAmount = v.paymentamount,
            paid = paid,
            unpaid = v.paymentsleft,
            total = total
        })
    end
    cb(list)
end)

-- ==========================================
-- ✅ پایان Test Drive توسط Boss (Repossess / Finish)
-- ==========================================
RegisterNetEvent('qrt-vehicleshop:server:finishTestDrive', function(testDriveId)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player or player.PlayerData.job.name ~= 'cardealer' then return end

    local td = MySQL.single.await('SELECT * FROM dealer_active_testdrives WHERE id = ?', {testDriveId})
    if td then
        MySQL.delete('DELETE FROM dealer_active_testdrives WHERE id = ?', {testDriveId})
        -- ارسال به تمام کلاینت‌ها برای پیدا کردن و حذف ماشین با این پلاک
        TriggerClientEvent('qrt-vehicleshop:client:removeTestDriveVeh', -1, td.plate)
        TriggerClientEvent('QBCore:Notify', src, '✅ Test drive finished & vehicle removed', 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, '❌ Record not found', 'error')
    end
end)



TriggerClientEvent('qrt-vehicleshop:client:openBossMenu', source)