local playerLoadouts = {}
local playerZones = {}

-- Function to check if player is in a zone
isPlayerInZone = function(playerId, zoneCoords, radius)
    local playerCoords = GetEntityCoords(GetPlayerPed(playerId))
    local distance = #(playerCoords - zoneCoords)
    return distance <= radius
end

-- Helper function to calculate the nearest point outside the zone's radius
getNearestPointOutsideZone = function(playerCoords, zoneCoords, radius)
    local direction = playerCoords - zoneCoords
    direction = direction / #direction
    local nearestPoint = zoneCoords + direction * (radius + 5.0) 
    return nearestPoint
end

-- Event to give a loadout to a player.
RegisterNetEvent('sd-redzones:server:addLoadout', function(zoneId)
    local src = source
    local zoneData = Config.Zones[zoneId]

    if zoneData and isPlayerInZone(src, zoneData.coords, zoneData.radius) then
        local identifier = GetIdentifier(src)
        playerLoadouts[identifier] = {}
        playerZones[src] = zoneId

        for _, item in ipairs(Config.LoadoutItems) do
            AddItem(src, item, 1)
            table.insert(playerLoadouts[identifier], item)
        end
    end
end)

-- Event to remove a loadout from a player.
RegisterNetEvent('sd-redzones:server:removeLoadout', function(zoneId, playerId)
    local src = playerId or source

    if playerZones[src] == zoneId then
        local identifier = GetIdentifier(src)
        local loadout = playerLoadouts[identifier]

        if loadout then
            for _, item in ipairs(loadout) do
                RemoveItem(src, item, 1)
            end

            playerLoadouts[identifier] = nil
            playerZones[src] = nil
        end
    end
end)


-- Event to handle player death
RegisterNetEvent('baseevents:onPlayerDied', function()
    local src = source
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    
    for zoneId, zoneData in ipairs(Config.Zones) do
        if isPlayerInZone(src, zoneData.coords, zoneData.radius) then
            local nearestPoint = getNearestPointOutsideZone(playerCoords, zoneData.coords, zoneData.radius)
            TriggerClientEvent('sd-redzones:client:handleDeath', src, nearestPoint)

            break
        end
    end
end)

-- Event to remove loadout in the case of player disconnect
AddEventHandler('playerDropped', function(reason)
    local playerId = source

    if playerZones[playerId] then
        TriggerEvent('sd-redzones:server:removeLoadout', playerZones[playerId], playerId)
    end
end)

local playerStats = {}

-- Helper to init stats for a player
local function InitStats(playerId)
    if not playerStats[playerId] then
        playerStats[playerId] = { kills = 0, deaths = 0, headshots = 0 }
    end
end

-- When a player dies (increase deaths)
AddEventHandler('baseevents:onPlayerDied', function()
    local victimId = source
    InitStats(victimId)
    playerStats[victimId].deaths = playerStats[victimId].deaths + 1

    -- Update victim client
    TriggerClientEvent('sd-redzones:client:updateKillStats', victimId,
        playerStats[victimId].kills,
        playerStats[victimId].deaths,
        playerStats[victimId].headshots)
end)

-- When a player kills another
RegisterNetEvent('sd-redzones:server:handleKillReward', function(victimId, wasHeadshot)
    local killerId = source
    local killerPed = GetPlayerPed(killerId)
    
    -- Safety check
    if not killerPed or killerPed == -1 then return end

    local killerCoords = GetEntityCoords(killerPed)

    -- ✅ Check if killer is inside ANY redzone
    local isInRedzone = false
    for _, zone in pairs(Config.Zones) do
        if #(killerCoords - zone.coords) <= zone.radius then
            isInRedzone = true
            break
        end
    end

    -- ❌ If NOT in redzone, cancel
    if not isInRedzone then
        print(("^1[RedZone]^7 No reward - %s killed outside the redzone."):format(killerId))
        return
    end

    -- ✅ Continue reward logic
    InitStats(killerId)
    InitStats(victimId)

    playerStats[killerId].kills = playerStats[killerId].kills + 1
    if wasHeadshot then
        playerStats[killerId].headshots = playerStats[killerId].headshots + 1
    end

    playerStats[victimId].deaths = playerStats[victimId].deaths + 1

    -- Update HUDs
    TriggerClientEvent('sd-redzones:client:updateKillStats', killerId,
        playerStats[killerId].kills,
        playerStats[killerId].deaths,
        playerStats[killerId].headshots)

    TriggerClientEvent('sd-redzones:client:updateKillStats', victimId,
        playerStats[victimId].kills,
        playerStats[victimId].deaths,
        playerStats[victimId].headshots)

    -- 🎁 Reward using ox_inventory
    if invState == 'started' then
        local rewards = {
            { item = 'ammo-9', amount = 15 },
            { item = 'ammo-rifle', amount = 15 },
            { item = 'rzpill', amount = 5 }
        }

        for _, reward in ipairs(rewards) do
            exports.ox_inventory:AddItem(killerId, reward.item, reward.amount)
        end

        TriggerClientEvent('ox_lib:notify', killerId, {
            title = 'RedZone',
            description = 'You received 1x ammo-9, 1x ammo-rifle, and 1x rzpill for the kill!',
            type = 'success'
        })
    end
end)
