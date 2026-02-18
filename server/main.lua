local ESX = exports['es_extended']:getSharedObject()

local Vehicles
local Customs = {}

RegisterNetEvent('smtrp_lscustom:startModing', function(props, netId)
    local src = tostring(source)
    if Customs[src] then
        Customs[src][tostring(props.plate)] = {props = props, netId = netId}
    else
        Customs[src] = {}
        Customs[src][tostring(props.plate)] = {props = props, netId = netId}
    end
end)

RegisterNetEvent('smtrp_lscustom:stopModing', function(plate)
    local src = tostring(source)
    if Customs[src] then
        Customs[src][tostring(plate)] = nil
    end
end)

AddEventHandler('esx:playerDropped', function(src)
    src = tostring(src)
    local playersCount = #GetPlayers()
    if Customs[src] then
        for _, v in pairs(Customs[src]) do
            local entity = NetworkGetEntityFromNetworkId(v.netId)
            if DoesEntityExist(entity) then
                if playersCount > 0 then
                    TriggerClientEvent('smtrp_lscustom:restoreMods', -1, v.netId, v.props)
                else
                    DeleteEntity(entity)
                end
            end
        end
        Customs[src] = nil
    end
end)

RegisterNetEvent('smtrp_lscustom:clearPendingCustom', function(plate)
    MySQL.update('DELETE FROM lscustom_pending WHERE plate = ?', {plate})
end)

ESX.RegisterServerCallback('smtrp_lscustom:getPendingBill', function(source, cb, targetPlayerId)
    local xTarget = ESX.GetPlayerFromId(targetPlayerId)
    if not xTarget then return cb(0, nil) end

    MySQL.single('SELECT price, plate FROM lscustom_pending WHERE owner = ? ORDER BY price DESC LIMIT 1', {xTarget.identifier}, function(result)
        if result then
            cb(result.price, result.plate)
        else
            cb(0, nil)
        end
    end)
end)

RegisterNetEvent('smtrp_lscustom:savePendingCustom', function(plate, price)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or xPlayer.job.name ~= 'mechanic' then return end

    MySQL.single('SELECT owner FROM owned_vehicles WHERE plate = ?', {plate}, function(result)
        if result then
            MySQL.update('INSERT INTO lscustom_pending (plate, owner, price) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE price = ?', {
                plate, result.owner, price, price
            })
        end
    end)
end)

RegisterNetEvent('smtrp_lscustom:refreshOwnedVehicle', function(vehicleProps, netId)
    local src = tostring(source)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not vehicleProps then return print('^3[WARNING]^0 The vehicle Props could\'nt be found.') end
    if not vehicleProps.plate then return print('^3[WARNING]^0 The vehicle plate could\'nt be found.') end
    if not vehicleProps.model then return print('^3[WARNING]^0 The vehicle model could\'nt be found.') end

    if not xPlayer then return print('^3[WARNING]^0 The player could\'nt be found.') end

    MySQL.single('SELECT vehicle FROM owned_vehicles WHERE plate = ?', {vehicleProps.plate}, function(result)
        if result then
            local vehicle = json.decode(result.vehicle)
            if vehicleProps.model == vehicle.model then
                MySQL.update('UPDATE owned_vehicles SET vehicle = ? WHERE plate = ?', {json.encode(vehicleProps), vehicleProps.plate})
                if Customs[src] then
                    if Customs[src][tostring(vehicleProps.plate)] then
                        Customs[src][tostring(vehicleProps.plate)].props = vehicleProps
                    else
                        Customs[src][tostring(vehicleProps.plate)] = {props = vehicleProps, netId = netId}
                    end
                else
                    Customs[src] = {}
                    Customs[src][tostring(vehicleProps.plate)] = {props = vehicleProps, netId = netId}
                end

                local veh = NetworkGetEntityFromNetworkId(netId)
                local vehState = Entity(veh).state.VehicleProperties
                if vehState then
                    Entity(veh).state:set('VehicleProperties', vehicleProps, true)
                end
            else
                print(('[^3WARNING^7] Player ^5%s^7 Attempted To upgrade with mismatching vehicle model'):format(xPlayer.source))
            end
        end
    end)
end)

ESX.RegisterServerCallback('smtrp_lscustom:getVehiclesPrices', function(source, cb)
    if not Vehicles then
        Vehicles = MySQL.query.await('SELECT model, price FROM vehicles')
    end
    cb(Vehicles)
end)

ESX.RegisterServerCallback('smtrp_lscustom:payPersonal', function(source, cb, price)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(false) end

    price = tonumber(price)
    if not price then return cb(false) end

    if xPlayer.getMoney() >= price then
        xPlayer.removeMoney(price, 'LS Custom Personal')
        MySQL.insert('INSERT INTO banking (identifier, type, amount, time, balance, label) VALUES (?, ?, ?, ?, ?, ?)', {
            xPlayer.getIdentifier(),
            'PAY',
            price,
            os.time() * 1000,
            xPlayer.getAccount('bank').money,
            'SMTRP Customs - Customisation'
        })
        cb(true)
    elseif xPlayer.getAccount('bank').money >= price then
        xPlayer.removeAccountMoney('bank', price, 'LS Custom Personal')
        MySQL.insert('INSERT INTO banking (identifier, type, amount, time, balance, label) VALUES (?, ?, ?, ?, ?, ?)', {
            xPlayer.getIdentifier(),
            'PAY',
            price,
            os.time() * 1000,
            xPlayer.getAccount('bank').money,
            'SMTRP Customs - Customisation'
        })
        cb(true)
    else
        cb(false)
    end
end)
