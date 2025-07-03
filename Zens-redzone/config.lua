Config = {}

Config.Zones = {
    {
        coords = vector3(-81.4447, -2007.7911, 18.0169), radius = 30.0 --  near Grove Street
    },
    {
        coords = vector3(524.1433, -2990.7722, 6.0443), radius = 50.0 -- creats
    },
    {
        coords = vector3(451.9193, -1514.9149, 29.1611), radius = 55.0 -- creats
    },
    --[[ { -- Example of adding additional zones.
        coords = vector3(500.75, -1941.19, 20.8), radius = 200.0 -- Grove Street
    }, ]]
}

-- Define loadout items
Config.LoadoutItems = { "", "", --[[ 'ammo' ]]}

-- Define Items that will be awarded to the player when they enter the zone and kill another player.
Config.Rewards = {
    Item = { name = 'ammo-9', count = 20 }
}

-- Names for the Core that'll be used to split ESX/QBCore Logic.
Config.CoreNames = {
    QBCore = 'qb-core', -- Edit, if you've renamed qb-core.
    ESX = 'es_extended', -- Edit, if you've renamed es_extended
}

-- Name that will check for to then use ox_inventory specific exports.
Config.InvName = {
    OX = 'ox_inventory' -- Edit if you've renamed ox_inventory
}

if GetResourceState(Config.CoreNames.QBCore) == 'started' then Framework = 'qb' elseif GetResourceState(Config.CoreNames.ESX) == 'started' then Framework = 'esx' end
invState = GetResourceState(Config.InvName.OX)
