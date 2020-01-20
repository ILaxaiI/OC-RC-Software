local comps = require("component")
local reactor = comps.nc_fission_reactor
local gpu = comps.gpu
local event = require("event")
local width,height = 100,50

gpu.setResolution(width,height)

local function exit()
  reactor.deactivate()
  gpu.setResolution(gpu.maxResolution())
  os.execute("cls")
  os.exit()
end



local safety = {off = false,heat = true, energy = true}

local buttons = {
  {x = 95, y = 2,w = 4,h = 2, funct = exit,color = 0xff0000},
  {x = 70,y = 10,w = 4,h = 2,funct = function() safety.heat = not safety.heat end,color = 0xff0000},
  {x = 70,y = 14,w = 4,h = 2,funct = function() safety.energy = not safety.energy end,color = 0xff0000},
  {x = 70,y = 25,w = 4,h = 2,funct = function() safety.off = not safety.off end,color = 0xffff00},
}




local ui = {}
local state = {
  heat = 0,maxHeat = 0,
  energy = 0,maxEnergy = 0,
  isActive = false,
  charged = true,
  overHeating = true,
}



function ui.key_down (_,scancode)
  if scancode == 19 then
    exit()
  end
end

function ui.touch(x,y)
  for i = 1,#buttons do
    if x >= buttons[i].x and x <= buttons[i].x+buttons[i].w
    and y >= buttons[i].y and y <= buttons[i].y+buttons[i].h then
      buttons[i].funct()
    end
  end
end

local function userInput()
  local type,_,arg1,arg2,arg3 = event.pull(0.1)
  if ui[type] then ui[type](arg1,arg2,arg3) end
end




local Paused = {b = false, reason = ""}
local function unpause()
  Paused.b = false  
end

local function getReason()
  return (safety.off and "Deactivated") or ((state.overHeating and safety.heat) and "Heat Critical") or ((state.charged and safety.energy) and "Fully Charged") or "Unknown"
end

local function update()
  state.heat,state.maxHeat = reactor.getHeatLevel(),reactor.getMaxHeatLevel()
  state.energy,state.maxEnergy,state.isActive = reactor.getEnergyStored(),reactor.getMaxEnergyStored(),reactor.isProcessing()
  
  state.charged = state.energy >= state.maxEnergy*0.95
  state.overHeating = state.heat >= state.maxHeat/2
  local status = ((state.charged and safety.energy) or (state.overHeating and safety.heat)) 
  
  if state.isActive and (status or safety.off) then
    reactor.deactivate()
    state.isActive = false
    Paused.b = true
    Paused.reason = getReason()
    event.timer(1,unpause)
  elseif not Paused.b and not state.isActive and not (status or safety.off) then
    reactor.activate()
    state.isActive = true
  end
  
  buttons[2].color = safety.heat and 0x0ff00 or 0xff0000
  buttons[3].color = safety.energy and 0x00ff00 or 0xff0000
    
end


local function draw()  
  local Hpercent = state.heat/state.maxHeat
  local RFpercent = state.energy/state.maxEnergy
  os.execute("cls")
  gpu.setForeground(state.isActive and 0x00ff00 or 0xff0000)
  gpu.set(10,5,"Reactor Status: " .. (state.isActive and "Running" or "Offline"))
  gpu.setForeground(0xffffff)
  
  if Paused.b then
    gpu.set(10,6,"Reason: ".. Paused.reason)
  elseif not state.isActive then
    gpu.set(10,6,"Reason: ".. getReason())
  end

  
  gpu.setForeground(state.overHeating and 0xff0000 or 0xffffff)
  gpu.set(10,10,"Heat: "..state.heat.."/"..state.maxHeat)

  gpu.setForeground(state.charged and 0x00ff00 or 0xffffff)
  gpu.set(10,21,"RF: "..state.energy.."/"..state.maxEnergy)
  gpu.setForeground(0xffffff)
  gpu.set(70,8,"Safety Modes")
  gpu.set(70,9,"Heat: ".. (safety.heat and "on" or "off"))
  gpu.set(70,13,"Energy: ".. (safety.energy and "on" or "off"))
  gpu.set(70,24,"Toggle Reactor ".. (safety.off and "on" or "off"))


  gpu.setBackground(0x555555)
  
  gpu.fill(1,0,2,height," ")
  gpu.fill(width-1,0,2,height," ")
  gpu.fill(1,0,width,2," ")
  gpu.fill(1,height-2,width,2," ")
  
  gpu.setBackground(0x444444)
  gpu.fill(10,12,43,4," ")
  gpu.fill(10,23,43,4," ")
  gpu.setBackground(0)
  gpu.fill(12,13,40,2," ")
  gpu.fill(12,24,40,2," ")
  
  
  
  
  gpu.setBackground(0x33ff33)
  gpu.fill(11,13,math.floor(40*Hpercent+0.5),2," ")
  gpu.fill(11,24,math.floor(40*RFpercent+0.5),2," ")
  
  
  for i = 1,#buttons do
    gpu.setBackground(buttons[i].color)
    gpu.fill(buttons[i].x,buttons[i].y,buttons[i].w,buttons[i].h," ")
  end
  gpu.setBackground(0)
end


while true do
  userInput()
  update()
  draw()
  os.sleep(0.1)
end




