# Zens-redzone

I created a basic red zone script that creates Blips and a red sphere zone around configurable areas. It provides players with weapons (Config.LoadoutItems) when entering the zone, rewards them for eliminating other players within the designated zone, and then transports the deceased or injured individuals outside the zone and revives them. 

I put this together in around 30-40 minutes. If anyone is interested, I'm willing to keep working on it to make it better. Feel free to submit PR requests if you have ideas for improvement or open an issue in case you come across a bug that needs fixing.

# Dependencies
- ox_lib

qb-ambulancejob events are currently being used to revive the player, you can edit them/replace them with your ambulance scripts equivalent in the sd-redzones:client:handleDeath event in the client.
