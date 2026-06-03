local QBCore = exports['qb-core']:GetCoreObject()
local isOpen = false

-- ==========================================
-- Events
-- ==========================================
RegisterNetEvent('custom_mob:client:openUI', function()
    if isOpen then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "open"
    })
end)

RegisterNetEvent('custom_mob:client:setOnlinePlayers', function(players)
    if not isOpen then return end
    SendNUIMessage({
        action = "setOnlinePlayers",
        players = players
    })
end)

RegisterNetEvent('custom_mob:client:setPremiumNumbers', function(premiumList)
    if not isOpen then return end
    SendNUIMessage({
        action = "setPremiumNumbers",
        premiumList = premiumList
    })
end)

RegisterNetEvent('custom_mob:client:actionResult', function(success, message, actionType)
    if not isOpen then return end
    SendNUIMessage({
        action = "actionResult",
        success = success,
        message = message,
        type = actionType
    })
end)

-- Clean up NUI on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SetNuiFocus(false, false)
        SendNUIMessage({
            action = "close"
        })
    end
end)

-- ==========================================
-- NUI Callbacks
-- ==========================================
RegisterNUICallback('closeUI', function(data, cb)
    isOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('getOnlinePlayers', function(data, cb)
    cb('ok')
    TriggerServerEvent('custom_mob:server:getOnlinePlayers')
end)

RegisterNUICallback('getPremiumNumbers', function(data, cb)
    cb('ok')
    TriggerServerEvent('custom_mob:server:getPremiumNumbers')
end)

RegisterNUICallback('assignPremiumNumber', function(data, cb)
    cb('ok')
    TriggerServerEvent('custom_mob:server:assignPremiumNumber', data)
end)

RegisterNUICallback('revokePremiumNumber', function(data, cb)
    cb('ok')
    TriggerServerEvent('custom_mob:server:revokePremiumNumber', data)
end)

