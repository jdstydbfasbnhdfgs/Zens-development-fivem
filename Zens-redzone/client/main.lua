local zones = {}

-- Create zones
CreateThread(function()
    for zoneId, zoneData in ipairs(Config.Zones) do
        local zone = lib.zones.sphere({
            coords = zoneData.coords,
            radius = zoneData.radius,
            debug = true,
            onEnter = function(self)
                TriggerServerEvent('sd-redzones:server:addLoadout', zoneId)
            end,
            onExit = function(self)
                TriggerServerEvent('sd-redzones:server:removeLoadout', zoneId)
            end
        })

        -- Blip Creation
        local blip = AddBlipForRadius(zoneData.coords.x, zoneData.coords.y, zoneData.coords.z, zoneData.radius + 450.0)
        SetBlipSprite(blip, 1)
        SetBlipColour(blip, 1)
        SetBlipAlpha(blip, 80)

        table.insert(zones, zone)
    end
end)

-- Event to handle player death
RegisterNetEvent('sd-redzones:client:handleDeath', function(nearestPoint)
    local player = PlayerPedId()
    DoScreenFadeOut(1000)
    Wait(1000)

    SetEntityCoords(PlayerPedId(), nearestPoint.x, nearestPoint.y, nearestPoint.z)

    Wait(2500) -- Wait for the player to be teleported

    SetEntityMaxHealth(player, 200)
    SetEntityHealth(player, 200)
    ClearPedBloodDamage(player)
    SetPlayerSprint(PlayerId(), true)

    -- qb-ambulancejob specific events to revive player
    TriggerEvent('hospital:client:Revive')

    DoScreenFadeIn(1000)

end)

-- Respawn ONLY when dying in a redzone
CreateThread(function()
    while true do
        Wait(1000)
        local player = PlayerPedId()
        if IsEntityDead(player) then
            local coords = GetEntityCoords(player)
            local diedInRedzone = false
            local nearestZone = nil
            local minDist = 9999.0

            -- Check if the death occurred inside a redzone
            for _, zoneData in ipairs(Config.Zones) do
                local dist = #(coords - zoneData.coords)
                if dist <= zoneData.radius then
                    diedInRedzone = true
                    if dist < minDist then
                        minDist = dist
                        nearestZone = zoneData
                    end
                end
            end

            -- Only respawn if death occurred inside redzone
            if diedInRedzone and nearestZone then
                -- Calculate a point just outside the redzone
                local heading = GetEntityHeading(player)
                local radius = nearestZone.radius + 10.0 -- 10 units outside the redzone
                local offsetX = math.cos(math.rad(heading)) * radius
                local offsetY = math.sin(math.rad(heading)) * radius
                local outsideCoords = vector3(
                    nearestZone.coords.x + offsetX,
                    nearestZone.coords.y + offsetY,
                    nearestZone.coords.z
                )

                -- Trigger respawn
                TriggerEvent('sd-redzones:client:handleDeath', outsideCoords)
            end

            -- Wait until player is alive again
            while IsEntityDead(PlayerPedId()) do
                Wait(1000)
            end
        end
    end
end)

-- Create zones
CreateThread(function()
    for zoneId, zoneData in ipairs(Config.Zones) do
        local zone = lib.zones.sphere({
            coords = zoneData.coords,
            radius = zoneData.radius,
            debug = false,
            onEnter = function(self)
                -- Check if player is in a vehicle
                local ped = PlayerPedId()
                if IsPedInAnyVehicle(ped, false) then
                    local vehicle = GetVehiclePedIsIn(ped, false)
                    TaskLeaveVehicle(ped, vehicle, 0)
                    Wait(500)

                    -- Optional: Delete the vehicle
                    SetEntityAsMissionEntity(vehicle, true, true)
                    DeleteVehicle(vehicle)

                    -- Optional: Notify player
                    lib.notify({
                        title = "RedZone",
                        description = "Vehicles are not allowed in the RedZone!",
                        type = "error"
                    })
                end

                -- Give redzone loadout (existing behavior)
                TriggerServerEvent('sd-redzones:server:addLoadout', zoneId)
            end,
            onExit = function(self)
                TriggerServerEvent('sd-redzones:server:removeLoadout', zoneId)
            end
        })

        -- Blip
        local blip = AddBlipForRadius(zoneData.coords.x, zoneData.coords.y, zoneData.coords.z, zoneData.radius + 450.0)
        SetBlipSprite(blip, 1)
        SetBlipColour(blip, 1)
        SetBlipAlpha(blip, 80)

        table.insert(zones, zone)
    end
end)

-- Prevent multiple rewards per body
local recentlyKilled = {}

CreateThread(function()
    while true do
        Wait(0)
        local player = PlayerPedId()
        if IsPedArmed(player, 6) then
            local _, targetPed = GetEntityPlayerIsFreeAimingAt(PlayerId())
            if DoesEntityExist(targetPed) and IsEntityAPed(targetPed) and IsPedAPlayer(targetPed) then
                if IsPedDeadOrDying(targetPed, true) then
                    local victimId = NetworkGetPlayerIndexFromPed(targetPed)
                    local victimServerId = GetPlayerServerId(victimId)

                    -- Only trigger once per body
                    if victimServerId and not recentlyKilled[victimServerId] then
                        recentlyKilled[victimServerId] = true

                        -- Check if killer is inside redzone before sending event
                        local coords = GetEntityCoords(PlayerPedId())
                        for _, zoneData in ipairs(Config.Zones) do
                            local dist = #(coords - zoneData.coords)
                            if dist <= zoneData.radius then
                                TriggerServerEvent('sd-redzones:server:onPlayerKilled', victimServerId)
                                break
                            end
                        end

                        -- Cooldown before re-allowing
                        SetTimeout(5000, function()
                            recentlyKilled[victimServerId] = nil
                        end)
                    end
                end
            end
        end
    end
end)

local killedPlayers = {}

local killedPlayers = {}

AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local victim = args[1]
        local attacker = args[2]
        local weaponHash = args[5]
        local hitBone = args[7] -- ✅ Correct bone index

        print("^3[RedZone CLIENT]^7 Event:", name)
        print("^3[RedZone CLIENT]^7 Victim:", victim, "Attacker:", attacker)
        print("^3[RedZone CLIENT]^7 Hit Bone:", hitBone)

        if attacker == PlayerPedId() and IsPedAPlayer(victim) and IsEntityDead(victim) then
            local victimId = NetworkGetPlayerIndexFromPed(victim)
            if victimId then
                local victimServerId = GetPlayerServerId(victimId)
                if not killedPlayers[victimServerId] then
                    killedPlayers[victimServerId] = true

                    local headshotBones = {
                        [31086] = true, -- SKEL_Head
                        [20] = true,    -- Fallback head
                        [39317] = true  -- Possibly upper skull in some models
                    }

                    local isHeadshot = headshotBones[hitBone] or false
                    print("^2[RedZone CLIENT]^7 Sending reward. Headshot:", isHeadshot)

                    -- Trigger server reward
                    TriggerServerEvent('sd-redzones:server:handleKillReward', victimServerId, isHeadshot)

                    SetTimeout(5000, function()
                        killedPlayers[victimServerId] = nil
                    end)
                end
            end
        end
    end
end)




local kills, deaths, headshots = 0, 0, 0

-- Better styled text
function DrawStyledText(x, y, text, scale)
    SetTextFont(6) -- Better looking bold font
    SetTextProportional(0)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 255) -- White
    SetTextOutline()
    SetTextCentre(false)
    SetTextDropshadow(1, 1, 1, 1, 255)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

-- Draw box background with layered gradient effect
function DrawCoolBox(x, y, width, height)
    -- Outer darker layer
    DrawRect(x, y, width + 0.005, height + 0.005, 20, 20, 20, 180)
    -- Main inner layer
    DrawRect(x, y, width, height, 0, 150, 255, 180)
    -- Highlight top layer for gradient-like effect
    DrawRect(x, y - (height / 3.5), width, height / 5, 0, 180, 255, 220)
end

-- Update stats from server
RegisterNetEvent('sd-redzones:client:updateKillStats', function(newKills, newDeaths, newHeadshots)
    kills, deaths, headshots = newKills, newDeaths, newHeadshots
end)

-- Check if player is inside redzone
local function isInRedzone()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    for _, zone in ipairs(Config.Zones) do
        if #(coords - zone.coords) <= zone.radius then
            return true
        end
    end
    return false
end

-- Display HUD
CreateThread(function()
    while true do
        Wait(0)
        if isInRedzone() then
            local boxX, boxY = 0.93, 0.92
            local boxWidth, boxHeight = 0.17, 0.13

            -- Text positions
            local textX = boxX - boxWidth / 2 + 0.015
            local textY = boxY - boxHeight / 2 + 0.018
            local scale = 0.39

            -- Draw fancy text with emojis/icons
            DrawStyledText(textX, textY, ("🔫 Kills: %d"):format(kills), scale)
            DrawStyledText(textX, textY + 0.032, ("💀 Deaths: %d"):format(deaths), scale)
        else
            Wait(500)
        end
    end
end)








