local component = require("component")
local event = require("event")
local filesystem = require("filesystem")
local modem = component.modem
local gpu = component.gpu

os.execute("cls")
modem.open(2)
local Address
local trial = 1
local width,height = gpu.getResolution()

repeat
  trial = trial + 1
  assert(trial < 4,"No nanomachines found")
  modem.broadcast(1,"nanomachines","setResponsePort",2)
  local port,name
  _,_,Address,port,_,name = event.pull(1,"modem_message")  
until Address and port == 2 and name == "nanomachines"

local numberOfInputs
trial = 0

repeat 
  trial = trial +1
  assert(trial < 4,"Coult not get Input Count")
  modem.send(Address,1,"nanomachines","getTotalInputCount")
  local port,name,msgtype,a
  _,_,a,port,_,name,msgtype,numberOfInputs = event.pull(1,"modem_message")
until a == Address and name == "nanomachines" and msgtype == "totalInputCount" and numberOfInputs
local inputs = {}



  local function newinput(a,q,s,pf,ef,bf)
    return {isActive = a,Querrying = q,sync = s,particleflag = pf,effectflag = ef,badflg = bf}
  end

  local fpath = "//usr/nanites"
  
local messageQueue = {}

function messageQueue:add(i,...)
  if i == "bottom" then
  self[#self+1] = {...}
  elseif i == "top" then
  table.insert(self,#self > 1 and 2 or 1,{...})
  end
end



function messageQueue.timeout()
  messageQueue.isWaiting = false
end

function messageQueue:sucscess()
  self.isWaiting = false
  table.remove(self,1)
end

function messageQueue:get()
  return self[1]
end

function messageQueue:removeDuplicates(msg)
  for i = #messageQueue,2,-1 do
    if #msg == #messageQueue[i] then
      local same = false
      for n = 1,#messageQueue[i] do
        same = msg[n] ~= messageQueue[i][n] or same
      end
      if not same then table.remove(self,i) end
    end
  end
end


function messageQueue:tick()
  if self[1] and not messageQueue.isWaiting then
    modem.send(Address,1,"nanomachines",table.unpack(self[1]))
    messageQueue.isWaiting = true
    event.timer(1,self.timeout,1)
  end
end  
do
  if not filesystem.exists(fpath) then
    filesystem.makeDirectory(fpath) 
  end
  fpath = fpath.."/inputs.lua"
  local datafile = io.open(fpath,"r")
  local data = datafile and datafile:read("*a") or ""
    
  local function indexData(i,v)
    local id = (i-1)*4+v
    return data:sub(id,id) == "1"
  end
  
  for i = 1,numberOfInputs do
    inputs[i] = newinput(indexData(i,1) or false,#data/4 < i,false,indexData(i,2) or false,indexData(i,3) or false,indexData(i,4) or false)
    messageQueue:add("bottom","getInput",i)
  end
end


local perRow = 5

local function rectangle(x,y,w,h,color)
  gpu.setBackground(color)
  gpu.fill(x,y,w,h," ")
end

local effects = ""

local function draw()
  gpu.set(1,1,tostring(#messageQueue))
  for i = 1,#inputs do
    local v = inputs[i]
    local x,y = (i-1)%perRow*16,math.floor((i-1)/perRow)*8 
    rectangle(x+8,10+y,9,4,v.Querrying and 0xffff00 or v.isActive and 0x00ff00 or 0xff0000)
    rectangle(x+12,14+y,5,1,v.sync and 0x22ff22 or 0xff2222)
    rectangle(x+8,9+y,3,1,v.particleflag and 0x77ff22 or 0x222222)
    rectangle(x+11,9+y,3,1,v.effectflag and 0x11ff11 or 0x333333)
    rectangle(x+14,9+y,3,1,v.badflag and 0xff2222 or 0x222222)
  end
  rectangle(70,1,2,height," ",0x222222)
  gpu.set(75,2,effects:match("%b{}"))
  gpu.setBackground(0)
end


local handler = {}

messageQueue:add("bottom","getActiveEffects")

function handler.touch(x,y)
  for i = 1,#inputs do
    local ix,iy = (i-1)%perRow*16,math.floor((i-1)/perRow)*8
    if not inputs[i].Querrying and x >= ix+8 and x <= ix+17 and y >= iy+10 and y <= iy + 14 then
      messageQueue:add("top","setInput",i,not inputs[i].isActive)
      inputs[i].Querrying = true
      inputs[i].sync = false
    elseif not inputs[i].sync and x >= ix+11 and x <= ix+17 and y >= iy+14 and y <= iy + 15 then
        inputs[i].sync = false
    elseif y == iy+9  then
      if x >= ix+8 and x <= ix+10 then
        inputs[i].particleflag = not inputs[i].particleflag
      elseif x >= ix+11 and x <= ix+13 then
        inputs[i].effectflag = not inputs[i].effectflag
      elseif x >= ix+14 and x <= ix+16 then 
        inputs[i].badflag = not inputs[i].badflag
      end
    end
  end
end


local function saveData()
  local data = ""
  for i = 1,#inputs do
    data = data ..(inputs[i].isActive and 1 or 0)  
    ..(inputs[i].particleflag and 1 or 0)
    ..(inputs[i].effectflag and 1 or 0)
    ..(inputs[i].badflag and 1 or 0)
  end
    
  local datafile = io.open(fpath,"w")
  datafile:write(data)
  datafile:close()
end

local function exit()
  saveData()
  os.execute("cls")
  os.exit()  
end

function handler.key_down() 
  exit()
end

local msgtypes = {getInput = "input",setInput = "input" ,getActiveEffects = "effects"}

local function queueEventQuerry()
  messageQueue:add("top","getActiveEffects")
end


function handler.modem_message(_,_,_,name,typeofmsg,value1,value2)
  
  local msg = messageQueue:get()
  if msg then
    if msgtypes[msg[1]] == typeofmsg then
      if msgtypes[msg[1]] == "input" and msg[2] == value1 and type(value2) == "boolean"  then
        inputs[value1].isActive = value2
        inputs[value1].Querrying = false
        inputs[value1].sync = true
        messageQueue:removeDuplicates(msg)
        messageQueue:sucscess()
      elseif value1 == "too many active inputs" then
        inputs[msg[2]].Querrying = false
        inputs[msg[2]].sync = false
        messageQueue:add("top","getInput",msg[2])
        messageQueue:sucscess()
      elseif msg[1] == "getActiveEffects" then
        effects = value1
        event.timer(3,queueEventQuerry,1)
        messageQueue:sucscess()
      end
    end
  end
end


local function update()
  messageQueue:tick()
  local name,_,a1,a2,a3,a4,a5,a6,a7 = event.pull(0) 
  if handler[name] then handler[name](a1,a2,a3,a4,a5,a6,a7) end
end


while true do
  draw()
  update()
end


