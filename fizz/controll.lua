local reactor = require("component").nc_fission_reactor
local event = require("event")



local function eventHandler(eventId,...)
  print(eventId,...)
  reactor.deactivate()
  os.exit()
end

event.listen("key_down",eventHandler)

while true do
  local heat,maxHeat = reactor.getHeatLevel(),reactor.getMaxHeatLevel()
  local energy,maxEnergy = reactor.getEnergyStored(),reactor.getMaxEnergyStored()
  print("Heat: "..heat.."/"..maxHeat.."\nRF: "..energy.."/"..maxEnergy)
  if energy >= maxEnergy*0.99 or heat >= maxHeat/2 then
    reactor.deactivate()
  else
    reactor.activate()
  end
end




