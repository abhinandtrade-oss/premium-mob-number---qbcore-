local QBCore = exports['qb-core']:GetCoreObject()

-- ==========================================
-- MySQL Global Fallback Wrapper
-- ==========================================
if not MySQL then
    MySQL = {}
    
    local function execute(method, query, params)
        local export = exports.oxmysql
        if not export then
            error("[custom_mob] oxmysql resource is not started or cannot be found!")
        end
        if export[method .. '_async'] then
            return export[method .. '_async'](export, query, params)
        elseif export[method] then
            return export[method](export, query, params)
        else
            error("[custom_mob] oxmysql export not found for method: " .. method)
        end
    end

    MySQL.query = {
        await = function(query, params) return execute('query', query, params) end
    }
    MySQL.single = {
        await = function(query, params) return execute('single', query, params) end
    }
    MySQL.update = {
        await = function(query, params) return execute('update', query, params) end
    }
    MySQL.insert = {
        await = function(query, params) return execute('insert', query, params) end
    }
    MySQL.scalar = {
        await = function(query, params) return execute('scalar', query, params) end
    }
end

-- Debug Print Helper
local function DebugPrint(msg)
    if Config.Debug then
        print("[custom_mob] [DEBUG] " .. tostring(msg))
    end
end

-- ==========================================
-- Utility: Update SBF Phone Numbers Database
-- ==========================================
local function UpdateSBFPhoneNumber(citizenid, newPhoneNumber)
    -- Check if entry exists in sbf_phone_numbers
    local exists = MySQL.single.await('SELECT id FROM sbf_phone_numbers WHERE identifier = ?', { citizenid })
    if exists then
        MySQL.update.await('UPDATE sbf_phone_numbers SET phone_number = ? WHERE identifier = ?', { newPhoneNumber, citizenid })
        DebugPrint("Updated SBF Phone number to '" .. newPhoneNumber .. "' for " .. citizenid)
    else
        MySQL.insert.await('INSERT INTO sbf_phone_numbers (identifier, phone_number) VALUES (?, ?)', { citizenid, newPhoneNumber })
        DebugPrint("Inserted new SBF Phone number '" .. newPhoneNumber .. "' for " .. citizenid)
    end
end


-- ==========================================
-- Admin Command Registration
-- ==========================================
QBCore.Commands.Add(Config.CommandName, "Open Premium Telecom Authority Admin Panel", {}, false, function(source)
    if QBCore.Functions.HasPermission(source, Config.AdminPermission) or QBCore.Functions.HasPermission(source, "god") then
        TriggerClientEvent('custom_mob:client:openUI', source)
    else
        TriggerClientEvent('QBCore:Notify', source, "You do not have permission to use this command.", "error")
    end
end, Config.AdminPermission)

-- ==========================================
-- Utility: Check for duplicate phone number
-- ==========================================
local function IsPhoneDuplicate(phoneNumber, excludeCitizenId)
    -- Clean the phone number input (remove spaces/dashes if database matches raw numeric strings, but we search exactly as entered)
    local checkStr = '%"phone":"' .. phoneNumber .. '"%'
    
    -- 1. Check in players table
    local playerMatch = MySQL.single.await('SELECT citizenid FROM players WHERE charinfo LIKE ?', { checkStr })
    if playerMatch then
        if not excludeCitizenId or playerMatch.citizenid ~= excludeCitizenId then
            DebugPrint("Duplicate phone number found in players table: " .. phoneNumber .. " (CitizenID: " .. playerMatch.citizenid .. ")")
            return true
        end
    end

    -- 2. Check in premium_phone_numbers table
    local premiumMatch = MySQL.single.await('SELECT citizenid FROM premium_phone_numbers WHERE custom_number = ?', { phoneNumber })
    if premiumMatch then
        if not excludeCitizenId or premiumMatch.citizenid ~= excludeCitizenId then
            DebugPrint("Duplicate phone number found in premium_phone_numbers table: " .. phoneNumber .. " (CitizenID: " .. premiumMatch.citizenid .. ")")
            return true
        end
    end

    return false
end

-- ==========================================
-- Event: Fetch all online players and premium status
-- ==========================================
RegisterNetEvent('custom_mob:server:getOnlinePlayers', function()
    local src = source
    if not (QBCore.Functions.HasPermission(src, Config.AdminPermission) or QBCore.Functions.HasPermission(src, "god")) then
        TriggerClientEvent('QBCore:Notify', src, "You do not have permission to view player data.", "error")
        return
    end

    local players = QBCore.Functions.GetQBPlayers()
    local onlinePlayersList = {}
    
    -- Fetch all premium phone records first to avoid querying database in a loop
    local premiumRecords = MySQL.query.await('SELECT citizenid, custom_number, expiry_date FROM premium_phone_numbers')
    local premiumMap = {}
    if premiumRecords then
        for _, rec in ipairs(premiumRecords) do
            premiumMap[rec.citizenid] = {
                custom = rec.custom_number,
                expiry = rec.expiry_date
            }
        end
    end

    for _, v in pairs(players) do
        local citizenid = v.PlayerData.citizenid
        local charinfo = v.PlayerData.charinfo
        local fullName = (charinfo.firstname or "") .. " " .. (charinfo.lastname or "")
        
        local premiumData = premiumMap[citizenid]
        local isPremium = premiumData ~= nil
        local customNumber = isPremium and premiumData.custom or nil
        local expiry = isPremium and premiumData.expiry or nil

        table.insert(onlinePlayersList, {
            id = v.PlayerData.source,
            citizenid = citizenid,
            name = fullName,
            phone = charinfo.phone or "",
            isPremium = isPremium,
            customNumber = customNumber,
            expiry = expiry
        })
    end
    
    TriggerClientEvent('custom_mob:client:setOnlinePlayers', src, onlinePlayersList)
end)

-- ==========================================
-- Event: Fetch all premium phone number entries
-- ==========================================
RegisterNetEvent('custom_mob:server:getPremiumNumbers', function()
    local src = source
    if not (QBCore.Functions.HasPermission(src, Config.AdminPermission) or QBCore.Functions.HasPermission(src, "god")) then
        TriggerClientEvent('QBCore:Notify', src, "You do not have permission to view premium records.", "error")
        return
    end

    local results = MySQL.query.await('SELECT p.charinfo, p.citizenid, pr.custom_number, pr.original_number, pr.expiry_date FROM premium_phone_numbers pr LEFT JOIN players p ON pr.citizenid = p.citizenid')
    local premiumList = {}

    if results then
        for _, row in ipairs(results) do
            local name = "Offline Player"
            if row.charinfo then
                local charinfo = json.decode(row.charinfo)
                if charinfo and charinfo.firstname and charinfo.lastname then
                    name = charinfo.firstname .. " " .. charinfo.lastname
                end
            end

            table.insert(premiumList, {
                citizenid = row.citizenid,
                name = name,
                customNumber = row.custom_number,
                originalNumber = row.original_number,
                expiry = row.expiry_date
            })
        end
    end

    TriggerClientEvent('custom_mob:client:setPremiumNumbers', src, premiumList)
end)

-- ==========================================
-- Event: Assign Premium Number
-- ==========================================
RegisterNetEvent('custom_mob:server:assignPremiumNumber', function(data)
    local src = source
    if not (QBCore.Functions.HasPermission(src, Config.AdminPermission) or QBCore.Functions.HasPermission(src, "god")) then
        TriggerClientEvent('QBCore:Notify', src, "You do not have permission to assign premium numbers.", "error")
        return
    end

    local target = data.target -- Can be server ID (string/number) or Citizen ID
    local customNumber = data.customNumber
    local expiryDays = tonumber(data.expiryDays) or 30

    if not target or not customNumber or customNumber == "" then
        TriggerClientEvent('custom_mob:client:actionResult', src, false, "Missing target identifier or custom phone number.", "assign")
        return
    end

    -- Attempt to find target player online
    local targetPlayer = nil
    local targetCitizenId = nil
    
    if tonumber(target) then
        targetPlayer = QBCore.Functions.GetPlayer(tonumber(target))
        if targetPlayer then
            targetCitizenId = targetPlayer.PlayerData.citizenid
        end
    else
        targetPlayer = QBCore.Functions.GetPlayerByCitizenId(target)
        if targetPlayer then
            targetCitizenId = target
        else
            targetCitizenId = target -- If offline, target is the CitizenID itself
        end
    end

    if not targetCitizenId or targetCitizenId == "" then
        TriggerClientEvent('custom_mob:client:actionResult', src, false, "Invalid player ID or Citizen ID.", "assign")
        return
    end

    -- Duplicate Check
    if IsPhoneDuplicate(customNumber, targetCitizenId) then
        TriggerClientEvent('custom_mob:client:actionResult', src, false, "Duplicate Check Failed! Phone number '" .. customNumber .. "' is already in use.", "assign")
        return
    end

    -- Calculate Expiry Date string for SQL insertion
    local expiryTimestamp = os.time() + (expiryDays * 24 * 60 * 60)
    local expiryDateStr = os.date('%Y-%m-%d %H:%M:%S', expiryTimestamp)

    -- Retrieve existing premium record to maintain original number if upgrading/changing
    local existingRecord = MySQL.single.await('SELECT original_number FROM premium_phone_numbers WHERE citizenid = ?', { targetCitizenId })
    local originalNumber = nil

    if targetPlayer then
        -- Player is Online
        originalNumber = existingRecord and existingRecord.original_number or targetPlayer.PlayerData.charinfo.phone

        -- Update premium database record
        if existingRecord then
            MySQL.update.await('UPDATE premium_phone_numbers SET custom_number = ?, expiry_date = ? WHERE citizenid = ?', {
                customNumber, expiryDateStr, targetCitizenId
            })
        else
            MySQL.insert.await('INSERT INTO premium_phone_numbers (citizenid, custom_number, original_number, expiry_date) VALUES (?, ?, ?, ?)', {
                targetCitizenId, customNumber, originalNumber, expiryDateStr
            })
        end

        -- Update active player instance in memory
        -- Update active player instance in memory
        targetPlayer.PlayerData.charinfo.phone = customNumber
        targetPlayer.Functions.Save() -- Force save to db

        -- Update SBF Phone table
        UpdateSBFPhoneNumber(targetCitizenId, customNumber)

        -- Sync player data to target client
        TriggerClientEvent('QBCore:Player:SetPlayerData', targetPlayer.PlayerData.source, targetPlayer.PlayerData)
        TriggerClientEvent('QBCore:Notify', targetPlayer.PlayerData.source, "Your phone number has been updated to premium: " .. customNumber .. "! Expiry: " .. expiryDays .. " days.", "success", Config.Notify.Duration)
        
        DebugPrint("Assigned custom phone number '" .. customNumber .. "' to online player (ID: " .. targetPlayer.PlayerData.source .. ", CitizenID: " .. targetCitizenId .. ")")
        TriggerClientEvent('custom_mob:client:actionResult', src, true, "Successfully assigned '" .. customNumber .. "' to online player " .. targetPlayer.PlayerData.charinfo.firstname .. " " .. targetPlayer.PlayerData.charinfo.lastname .. " (ID: " .. targetPlayer.PlayerData.source .. ").", "assign")
    else
        -- Player is Offline
        -- Retrieve player's charinfo from database
        local playerRow = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { targetCitizenId })
        if not playerRow then
            TriggerClientEvent('custom_mob:client:actionResult', src, false, "Citizen ID '" .. targetCitizenId .. "' does not exist in the database.", "assign")
            return
        end

        local charinfo = json.decode(playerRow.charinfo)
        originalNumber = existingRecord and existingRecord.original_number or charinfo.phone

        -- Update premium database record
        if existingRecord then
            MySQL.update.await('UPDATE premium_phone_numbers SET custom_number = ?, expiry_date = ? WHERE citizenid = ?', {
                customNumber, expiryDateStr, targetCitizenId
            })
        else
            MySQL.insert.await('INSERT INTO premium_phone_numbers (citizenid, custom_number, original_number, expiry_date) VALUES (?, ?, ?, ?)', {
                targetCitizenId, customNumber, originalNumber, expiryDateStr
            })
        end

        -- Update players table
        charinfo.phone = customNumber
        local updatedCharinfo = json.encode(charinfo)
        MySQL.update.await('UPDATE players SET charinfo = ? WHERE citizenid = ?', { updatedCharinfo, targetCitizenId })

        -- Update SBF Phone table
        UpdateSBFPhoneNumber(targetCitizenId, customNumber)

        DebugPrint("Assigned custom phone number '" .. customNumber .. "' to offline player (CitizenID: " .. targetCitizenId .. ")")
        TriggerClientEvent('custom_mob:client:actionResult', src, true, "Successfully assigned '" .. customNumber .. "' to offline player (CitizenID: " .. targetCitizenId .. ").", "assign")
    end
end)

-- ==========================================
-- Event: Revoke Premium Number
-- ==========================================
RegisterNetEvent('custom_mob:server:revokePremiumNumber', function(data)
    local src = source
    if not (QBCore.Functions.HasPermission(src, Config.AdminPermission) or QBCore.Functions.HasPermission(src, "god")) then
        TriggerClientEvent('QBCore:Notify', src, "You do not have permission to revoke premium numbers.", "error")
        return
    end

    local citizenid = data.citizenid
    if not citizenid or citizenid == "" then
        TriggerClientEvent('custom_mob:client:actionResult', src, false, "Missing Citizen ID.", "revoke")
        return
    end

    -- Look up premium details
    local premiumRecord = MySQL.single.await('SELECT original_number, custom_number FROM premium_phone_numbers WHERE citizenid = ?', { citizenid })
    if not premiumRecord then
        TriggerClientEvent('custom_mob:client:actionResult', src, false, "This player does not have a premium phone number assigned.", "revoke")
        return
    end

    local originalNumber = premiumRecord.original_number
    local customNumber = premiumRecord.custom_number

    -- Delete premium record
    MySQL.query.await('DELETE FROM premium_phone_numbers WHERE citizenid = ?', { citizenid })

    -- Revert number
    local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if targetPlayer then
        -- Update online player session
        targetPlayer.PlayerData.charinfo.phone = originalNumber
        targetPlayer.Functions.Save()

        -- Update SBF Phone table
        UpdateSBFPhoneNumber(citizenid, originalNumber)

        -- Sync player data to client
        TriggerClientEvent('QBCore:Player:SetPlayerData', targetPlayer.PlayerData.source, targetPlayer.PlayerData)
        TriggerClientEvent('QBCore:Notify', targetPlayer.PlayerData.source, "Your premium phone number has expired or was revoked. Reverted to " .. originalNumber .. ".", "error", Config.Notify.Duration)
        
        DebugPrint("Revoked premium number '" .. customNumber .. "' and reverted to '" .. originalNumber .. "' for online player " .. citizenid)
        TriggerClientEvent('custom_mob:client:actionResult', src, true, "Successfully revoked number. Reverted online player to original: " .. originalNumber, "revoke")
    else
        -- Update offline player in players table
        local playerRow = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { citizenid })
        if playerRow then
            local charinfo = json.decode(playerRow.charinfo)
            charinfo.phone = originalNumber
            local updatedCharinfo = json.encode(charinfo)
            MySQL.update.await('UPDATE players SET charinfo = ? WHERE citizenid = ?', { updatedCharinfo, citizenid })
        end

        -- Update SBF Phone table
        UpdateSBFPhoneNumber(citizenid, originalNumber)

        DebugPrint("Revoked premium number '" .. customNumber .. "' and reverted to '" .. originalNumber .. "' for offline player " .. citizenid)
        TriggerClientEvent('custom_mob:client:actionResult', src, true, "Successfully revoked number. Reverted offline database entry to original: " .. originalNumber, "revoke")
    end
end)

-- ==========================================
-- Expiry Background Task (Hourly Cron)
-- ==========================================
local function CheckExpiredNumbers()
    DebugPrint("Running background task to check for expired custom phone numbers...")
    
    local expiredRecords = MySQL.query.await('SELECT citizenid, custom_number, original_number FROM premium_phone_numbers WHERE expiry_date <= NOW()')
    if not expiredRecords or #expiredRecords == 0 then
        DebugPrint("No expired custom numbers found.")
        return
    end

    DebugPrint("Found " .. #expiredRecords .. " expired premium number records. Processing...")

    for _, row in ipairs(expiredRecords) do
        local citizenid = row.citizenid
        local originalNumber = row.original_number
        local customNumber = row.custom_number

        -- Revert player phone number
        local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(citizenid)
        if targetPlayer then
            -- Revert online player
            targetPlayer.PlayerData.charinfo.phone = originalNumber
            targetPlayer.Functions.Save()

            -- Update SBF Phone table
            UpdateSBFPhoneNumber(citizenid, originalNumber)

            -- Sync
            TriggerClientEvent('QBCore:Player:SetPlayerData', targetPlayer.PlayerData.source, targetPlayer.PlayerData)
            TriggerClientEvent('QBCore:Notify', targetPlayer.PlayerData.source, "Your premium phone number (" .. customNumber .. ") has expired. Reverted to " .. originalNumber, "error", Config.Notify.Duration)
        else
            -- Revert offline player
            local playerRow = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { citizenid })
            if playerRow then
                local charinfo = json.decode(playerRow.charinfo)
                charinfo.phone = originalNumber
                local updatedCharinfo = json.encode(charinfo)
                MySQL.update.await('UPDATE players SET charinfo = ? WHERE citizenid = ?', { updatedCharinfo, citizenid })
            end

            -- Update SBF Phone table
            UpdateSBFPhoneNumber(citizenid, originalNumber)
        end

        -- Delete from premium table
        MySQL.query.await('DELETE FROM premium_phone_numbers WHERE citizenid = ?', { citizenid })
        DebugPrint("Reverted expired phone number '" .. customNumber .. "' -> '" .. originalNumber .. "' for character " .. citizenid)
    end
end

CreateThread(function()
    -- Wait 30 seconds after server starts up to do the first check
    Wait(30000)
    while true do
        CheckExpiredNumbers()
        Wait(Config.ExpiryCheckInterval * 60 * 1000)
    end
end)
