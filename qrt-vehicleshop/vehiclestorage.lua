--[[
    ================================================
    |  Vehicle Storage Manager — qrt-vehicleshop   |
    ================================================
    Override trunk & glovebox weight/slots per vehicle model
    qrt-inventory reads these values via export
]]

local QBCore = exports['qb-core']:GetCoreObject()

local function NormalizeModel(model)
    if type(model) == 'number' then
        return string.lower(GetDisplayNameFromVehicleModel(model))
    end
    return string.lower(tostring(model))
end

--- خواندن تنظیمات یک مدل (توسط qrt-inventory صدا زده می‌شود)
local function GetVehicleStorage(model)
    local name = NormalizeModel(model)
    if Config.CustomVehicleStorage and Config.CustomVehicleStorage[name] then
        return Config.CustomVehicleStorage[name]
    end
    return nil
end
exports('GetVehicleStorage', GetVehicleStorage)

--- تغییر تنظیمات در Runtime از هر اسکریپت دیگر
exports('SetVehicleStorage', function(model, data)
    Config.CustomVehicleStorage = Config.CustomVehicleStorage or {}
    Config.CustomVehicleStorage[NormalizeModel(model)] = data
    return true
end)

--- کامند ادمین: /vehstorage model trunkKG trunkSlots gloveKG gloveSlots
RegisterCommand('vehstorage', function(source, args)
    if #args < 5 then
        QBCore.Functions.Notify('Usage: /vehstorage <model> <trunkKG> <trunkSlots> <gloveKG> <gloveSlots>', 'error')
        return
    end
    local model = NormalizeModel(args[1])
    Config.CustomVehicleStorage = Config.CustomVehicleStorage or {}
    Config.CustomVehicleStorage[model] = {
        trunkWeight = (tonumber(args[2]) or 60) * 1000,
        trunkSlots  = tonumber(args[3]) or 35,
        gloveWeight = (tonumber(args[4]) or 15) * 1000,
        gloveSlots  = tonumber(args[5]) or 8,
    }
    QBCore.Functions.Notify('Storage updated for: ' .. model, 'success')
end, true) -- restricted → نیاز به ace permission