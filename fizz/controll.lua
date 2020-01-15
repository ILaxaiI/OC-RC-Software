local comps = require("component")
local reactor = comps.nc_fission_reactor
local gpu = comps.gpu
local event = require("event")


local function eventHandler(eventId,...)
  print(eventId,...)
  reactor.deactivate()
end

event.listen("key_down",eventHandler)

while true do
  os.execute("cls")
  print(event.pull(0.1))
  local heat,maxHeat = reactor.getHeatLevel(),reactor.getMaxHeatLevel()
  local energy,maxEnergy = reactor.getEnergyStored(),reactor.getMaxEnergyStored()
  gpu.set(10,10,"Heat: "..heat.."/"..maxHeat)
  gpu.set(10,12,"RF: "..energy.."/"..maxEnergy)
  if energy >= maxEnergy*0.99 or heat >= maxHeat/2 then
    reactor.deactivate()
  else
    reactor.activate()
  end
end




