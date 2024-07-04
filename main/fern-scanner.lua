--paths
regionAssignment = "metadata/.region.json"
validFuelsPath = "metadata/fuels.json"
regionPathFormat = "regions/%d_%d.dat"
--constants
local datlib = require("datlib")
local sps = require("sps")
local modemID = "computercraft:wireless_modem_advanced"
local environmentID = "advancedperipherals:environment_detector"
local validFuels = {
    ["minecraft:coal"] = 80,
    ["minecraft:coal_block"] = 800,
    ["createaddition:biomass_pellet_block"] = 2880,
    ["createaddition:biomass_pellet"] = 320,
    ["quark:blaze_lantern"] = 1200,
    ["quark:charcoal_block"] = 800
}
local fuelLimit = turtle.getFuelLimit()
local dat = {}
local scanHeight = 310

local REGION,HOME


--Util Functions
local function selectSlot(slot)
    return (turtle.getSelectedSlot() == slot) or turtle.select(slot)
end
local function selectItem(name)
    for i=1,16 do
        if (turtle.getItemDetail(i) or {}).name == name then
            selectSlot(i)
            return i
        end
    end
    return false
end
local function equipModem()
    if peripheral.getType("left") == "modem" then 
        rednet.open("left")
        return rednet.isOpen()
    elseif selectItem(modemID) then
        turtle.equipLeft()
        rednet.open("left")
        return rednet.isOpen()
    end
    return false
end
local function equipEnvironment()
    if peripheral.getType("left") == "environmentDetector" then
        return peripheral.wrap("left")
    elseif selectItem(environmentID) then
        turtle.equipLeft()
        return peripheral.wrap("left")
    end
    return false
end
local function dist(x,y,z,a,b,c)
    return math.abs(x-a) + math.abs(y-b) + math.abs(z-c)
end
local function refuel()
    local x,y,z = sps.locate()
    local distance = dist(x,y,z,HOME[1],HOME[2],HOME[3])
    if turtle.getFuelLevel() > distance*1.5 and turtle.getFuelLevel() * 2 > fuelLimit then 
        print("Skipping refuel, have enough to make it to HOME 1.5 times")
        return true 
    end
    for i=1,16 do
        if turtle.getItemCount(i) > 0 and validFuels[turtle.getItemDetail(i).name] then
            local amount = math.min( (fuelLimit - turtle.getFuelLevel())/validFuels[turtle.getItemDetail(i).name],64)
            selectSlot(i)
            turtle.refuel(amount)
            if amount < 64 then 
                print("Refuelled to max value!")
                return true 
            end
        end
    end
    if turtle.getFuelLevel() > distance*1.5 and turtle.getFuelLevel() * 2 > fuelLimit then 
        print("Refuelled enough to make it to HOME 1.5 times")
        return true 
    end
    print("Refuel failure, no fuel found!")
    return false
end

--------------------Init
term.clear()
--Init checks
print("Init Checks")
assert(turtle,"This computer is not a turtle!")
assert(peripheral.getType("right") == "chunky","Make sure you put a chunkloader inside the right slot!")
assert(equipModem(),"Make sure to provide a modem for gps and communication")
assert(equipEnvironment(),"Make sure to provide an environment detector so the turtle can actually scan!")
--SPS init
print("Init SPS")
if not sps.init() then
    equipModem()
    local s,x,y,z = pcall(gps.locate)
    if not s or not x then
        print("Please enter the coordinates as `[x] [y] [z]`")
        x,y,z = read():gsub("[%s,]+"," "):match("(%-?%d+) (%-?%d+) (%-?%d+)")
        if not tonumber(x) or not tonumber(y) or not tonumber(z) then error("Please provide valid coordinates") end
    end
    print("Please enter the direction the turtle is facing (use f3) as `north|south|east|west`)")
    local facing = read():lower()
    assert(sps.init(facing,tonumber(x),tonumber(y),tonumber(z)),"Could not initialize Safe Positioning System")
end
--Metadata init
print("loading metadata")
if fs.exists(regionAssignment) then
    local file = fs.open(regionAssignment,"r")
    local data = textutils.unserialiseJSON(file.readAll())
    if data then REGION,HOME = data[1],data[2] end
    file.close()
end
do
    local updateFileFlag
    if not HOME then
        HOME = {sps.locate()}
        updateFileFlag = true
    end
    if not REGION then
        print("Please enter the region you wish the turtle to scan in in the format `regionX,regionZ`")
        local x,z = read():gsub("%s+",""):match("(%-?%d+),(%-?%d+)")
        if not tonumber(x) or not tonumber(z) then error("Please provide a valid region") end
        REGION = {tonumber(x),tonumber(z)}
        updateFileFlag = true
    end
    if updateFileFlag then
        local file = fs.open(regionAssignment,"w+")
        file.write(textutils.serialiseJSON({REGION,HOME}))
        file.close()
    end
end
print("Loaded metadata")
print("REGION:",textutils.serialise(REGION,{compact=true}))
print("HOME:",textutils.serialise(HOME,{compact=true}))
--Fuel init
if fs.exists(validFuelsPath) then
    print("Loading valid fuels")
    local file = fs.open(validFuelsPath,"r")
    local fuels = textutils.unserialiseJSON(file.readAll())
    file.close()
    for k,v in pairs(fuels or {}) do
        validFuels[k] = v
    end
else
    print("No valid fuels overrides to load, skipping")
end
--dat file init
print("loading dat file")
dat = datlib:open(regionPathFormat:format(REGION[1],REGION[2]))
print("Initial refuel")
repeat
    sleep(1)
until refuel()
print("Initial refuel complete!")

-------Data Functions
local function getRegionPos(x,z)
    return math.floor(x/2048),math.floor(z/2048)
end
local function isInRegion(x,z)
    local rx,rz = getRegionPos(x,z)
    return rx == REGION[1] and rz == REGION[2]
end
local function getLocalChunk(x,z)
    return math.floor(x/16)%128,math.floor(z/16)%128
end
local function scanBroadcastAndWrite()
    local environmentDetector = assert(equipEnvironment())
    local biome = environmentDetector.getBiome()
    local x,y,z = sps.locate()
    equipModem()
    rednet.broadcast({x,y,z,biome},"DATA")
    print("DATA:",x,y,z,biome)
    if isInRegion(x,z) then
        local cX,cZ = getLocalChunk(x,z)
        print("data is within region, adding to file at chunk indices:",cX,cZ)
        dat:setBiome(cX,cZ,biome)
    end
    return true
end

-------Movement Functions
local function rotate(dir)
    local _,facing = sps.facing()
    if (dir-facing)%4 > 2 then
        return turtle.turnLeft()
    end
    while facing ~= dir do
        turtle.turnRight()
        _,facing = sps.facing()
    end
    return true
end
local up = turtle.up
local down = turtle.down
local forward = turtle.forward
-- for k,v in ipairs({forward=turtle.forward,back=turtle.back,up=turtle.up,down=turtle.down}) do
--     _G[k] = v
-- end
local function moveToPos(x,y,z)
    print("Moving to pos:",x,y,z)
    local x0,y0,z0 = sps.locate()
    print("Current Pos:",x0,y0,z0)
    while y0 < y do
        _ = up() or refuel()
        x0,y0 = sps.locate()
    end
    while y0 > y do
        _ = down() or refuel()
        x0,y0 = sps.locate()
    end
    local index = 0
    if z0 < z then rotate(2)
    elseif z0 > z then rotate(0) end
    while z0 ~= z do
        _ = forward() or refuel()
        x0,y0,z0 = sps.locate()
        index = index + 1
        if index == 16 then
            scanBroadcastAndWrite()
            index = 0
            assert(refuel())
        end
    end
    if x0 < x then rotate(1) --x after z to simplify dat pathfinding
    elseif x0 > x then rotate(3) end
    while x0 ~= x do
        _ = forward() or refuel()
        x0 = sps.locate()
        index = index + 1
        if index == 16 then
            scanBroadcastAndWrite()
            index = 0
            assert(refuel())
        end
    end
    scanBroadcastAndWrite()
    if x0 ~= x or y0 ~= y or z0 ~= z then error("Coordinates do not match") end
    return true
end

local function goHome()
    print("Going home!")
    moveToPos(HOME[1],scanHeight,HOME[3])
    moveToPos(HOME[1],HOME[2],HOME[3])
end

local function SOS()
    equipModem()
    local function awaitReboot()
        while true do
            pcall(function()
                    local sndr,msg,prtcl = rednet.receive()
                    if prtcl == "REBOOT" then
                        os.reboot()
                    elseif prtcl == "HOME" then
                        local x,y,z = sps.locate()
                        if dist(x,y,z,HOME[1],HOME[2],HOME[3]) <= turtle.getFuelLevel() then 
                            goHome()
                        else
                            rednet.send(sndr,string.format("Lack fuel to go to %d %d %d",HOME[1],HOME[2],HOME[3]),"ERROR")
                        end
                    end 
            end)
        end
    end
    local function broadcastPosition()
        while true do
            pcall(function() 
                    rednet.broadcast({pos={sps.locate()},fuel=turtle.getFuelLevel(),facing=sps.facing()},"SOS")
                    rednet.broadcast({pos={sps.locate()},fuel=turtle.getFuelLevel(),facing=sps.facing()},"SOS_ERR")
                    sleep(1)
            end)
        end
    end
    local function updatePos()
        while true do
            pcall(function()
                    local s,x,y,z = pcall(gps.locate)
                    if s and x and y and z then
                        sps.updatePosition(x,y,z)
                        return true
                    end
                    sleep(0) 
            end)
        end
    end
    parallel.waitForAll(updatePos,broadcastPosition,awaitReboot)
end

print("Ready to start main sequence")
--Main
local function cycle()
    local cX,cZ = dat:getNextChunk()
    if not cX then
        goHome()
        fs.delete(regionAssignment)
        os.shutDown()
    else
        print(string.format("Target Chunk at %d %d",cX,cZ))
        moveToPos((REGION[1]*128+cX)*16,scanHeight,(REGION[2]*128+cZ)*16)
    end
end
while true do
    local s,err = pcall(cycle)
    if not s then
        print("SOS",err)
        SOS(tostring(err))
    end
    sleep(0)
end  
