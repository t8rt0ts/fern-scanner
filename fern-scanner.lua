local fern_data = require("fern-data")
local CHUNK_LIST = {}
local TURTLE
local HOST
local REG_X,REG_Z,REGION
local data_send_queue



--Rot: 0=N,1=E,2=S,3=W
local function Turtle(x,y,z,rot)
    local turt = {x=x,y=y,z=z,rot=rot}
    function turt:equipItem(item,side)
        if type(item) ~= "string" then error("Must be an item") end
        for i=1,16 do
            if (turtle.getItemDetail(i) or {}).name == item then
                turtle.select(i)
                if side == "left" then return turtle.equipLeft() end
                return turtle.equipRight()
            end
        end
        return false
    end
    function turt:updatePosition()
        self:equipItem("computercraft:wireless_modem_advanced")
        peripheral.find("modem",rednet.open)
        local x,y,z = gps.locate()
        if not x then error("Can not find turtle") end
        self.x,self.y,self.z = x,y,z
        if turtle.forward() then
            local x2,y2,z2 = gps.locate()
            if not x2 then error("Can not find turtle") end
            if z2 < z then self.rot = 0
            elseif z2 > z then self.rot = 2
            elseif x2 > x then self.rot = 1
            elseif x2 < x then self.rot = 3
            else error("Could not calculate rotation") end
            assert(turtle.back())
        elseif turtle.back() then
            local x2,y2,z2 = gps.locate()
            if not x2 then error("Can not find turtle") end
            if z2 < z then self.rot = 2
            elseif z2 > z then self.rot = 0
            elseif x2 > x then self.rot = 3
            elseif x2 < x then self.rot = 1
            else error("Could not calculate rotation") end
            assert(turtle.forward())
        else
            error("Please make sure that turtle has space to move to perform the rotation calculation")
        end
    end
    if not tonumber(x) or not tonumber(y) or not tonumber(z) or not tonumber(rot) then turt:updatePosition() end
    function turt:rot(dir)
        if tonumber(dir) then
            local amt = (math.floor(tonumber(dir)) - self.rot)%4
            if amt == 3 then
                assert(turtle.turnLeft())
            else
                for i=1,amt do
                    assert(turtle.turnRight())
                end
            end
            return true
        elseif type(dir) == "string" then
            local dirs = {n=0,e=1,s=2,w=3,north=0,east=1,south=2,west=3}
            local amt = dirs[dir:lower()]
            if not amt then return false end
            return self:rot(amt)
        else
            return false
        end
    end
    function turt:refuel()
        if turtle.getFuelLimit() - turtle.getFuelLevel() <= 2000 then return turtle.getFuelLevel() end
        for i=1,16 do
            turtle.select(i)
            if turtle.refuel(0) then
                local oldLvl = turtle.getFuelLevel()
                turtle.refuel(1)
                local amt = turtle.getFuelLevel() - oldLvl
                local itemsToBurn = math.floor((turtle.getFuelLimit() - turtle.getFuelLevel())/amt)
                turtle.refuel(math.min(turtle.getItemCount(i),itemsToBurn))
            end
            if turtle.getFuelLimit() - turtle.getFuelLevel() <= 2000 then return turtle.getFuelLevel() end
        end
        return turtle.getFuelLevel()
    end       
    function turt:moveToPos(x,y,z,verticalLast)
        if not tonumber(x) or not tonumber(z) then error("Must provide coordinates to travel to") end
        x,y,z = math.floor(tonumber(x)), math.floor(tonumber(y) or 310), math.floor(tonumber(z))
        if not verticalLast then
            if math.abs(self.y - y) > self:refuel() then error("Lack sufficient fuel") end
            while self.y < y do
                assert(turtle.up())
                self.y = self.y + 1
            end
            while self.y > y do
                assert(turtle.down())
                self.y = self.y - 1
            end
        end
        if math.abs(self.x - x) > self:refuel() then error("Lack sufficient fuel") end
        if self.x > x then
            self:rotate("W") --Face west if you are more east than your target
            while self.x ~= x do
                assert(turtle.forward())
                self.x = self.x - 1
            end
        elseif self.x < x then
            self:rotate("E")
            while self.x ~= x do
                assert(turtle.forward())
                self.x = self.x + 1
            end
        end
        if math.abs(self.z - z) > self:refuel() then error("Lack sufficient fuel") end
        if self.z > z then
            self:rotate("N") --Face north (-z) if you are more south(+z) than your target
            while self.x ~= x do
                assert(turtle.forward())
                self.x = self.x - 1
            end
        elseif self.z < z then
            self:rotate("S")
            while self.z ~= z do
                assert(turtle.forward())
                self.z = self.z + 1
            end
        end
        if verticalLast then
            if math.abs(self.y - y) > self:refuel() then error("Lack sufficient fuel") end
            while self.y < y do
                assert(turtle.up())
                self.y = self.y + 1
            end
            while self.y > y do
                assert(turtle.down())
                self.y = self.y - 1
            end
        end
    end
    --Checks and equips the necessary items
    function turt:checkNeededItems()
        if peripheral.getType("left") ~= "chunky" then --If chunkloader not in left slot, try to make sure it is
            if peripheral.getType("right") == "chunky" then --If chunkloader in the wrong slot, put it in the right slot
                if self:equip("computercraft:wireless_modem_advanced") or self:equip("advancedperipherals:environment_detector") then
                    if not self:equip("advancedperipherals:chunk_controller","left") then return false end --If you could replace the right slot with its typical peripherals and put the chunk controller in the left slot then you're okay
                else
                    return false
                end
            else
                if not self:equip("advancedperipherals:chunk_controller","left") then return false end
            end
        end
        if peripheral.getType("right") ~= "environmentDetector" and not self:equip("advancedperipherals:environment_detector") then return false end
        if (peripheral.getType("right") ~= "modem" or not peripheral.wrap("right").isWireless()) and not self:equip("computercraft:wireless_modem_advanced") then return false end
        return true
    end
    function turt:moveToChunk(cX,cZ)
        if not tonumber(cX) or not tonumber(cZ) then return false end
        return self:moveToPos(cX*16,nil,cZ*16)
    end
    function turt:openRednet()
        self:equipItem("computercraft:wireless_modem_advanced")
        peripheral.find("modem",rednet.open)
        local s = rednet.isOpen()
        local _,r = pcall(function() fs.list("region")[1] end)
        if s then pcall(function() rednet.host("fern-scanner-turtle",r or ""..os.getComputerID()) end) end
        return s
    end
    function turt:getBiome()
        self:equipItem("advancedperipherals:environment_detector")
        local envDet = peripheral.find("environmentDetector")
        if not envDet then error("No environment detector found") end
        return envDet.getBiome()
    end
    function turt:getChunk()
        return {math.floor(self.x/16),math.floor(self.z/16)}
    end
    function turt:diagnostics()
        self:openRednet()
        local pos = {gps.locate()} --gps locate pos
        local ipos = {self.x,self.y,self.z} --What the turtle thinks its at
        local fuel = turtle.getFuelLevel()
        local items = {}
        for i=1,16 do
            items[i] = turtle.getItemDetail(i)
        end
        return {pos=pos,fuel=fuel,items=items,ipos=ipos}
    end
    return turt
end

TURTLE = Turtle()
if not TURTLE:checkNeededItems() then error("Lacking items to start") end
assert(TURTLE:openRednet())
HOST = assert(rednet.lookup("fern-scanner-host"),"No host found")

local ss_receive,ss_send

ss_receive = function()
    TURTLE:openRednet()
    --@2m80_
    local sender,protocol,message = rednet.receive() --temporary solution
    if protocol == "ping" then
        ss_send(s,"pong",TURTLE:diagnostics())
    end
    return sender, protocol, message --Just like rednet?
end

ss_send = function(target,protocol,message,response_protocol)
    TURTLE:openRednet()
    rednet.send(target,protocol,message) --temporary solution
    --@2m80_
    if response_protocol then
        local s,p,m = ss_receive()
        while s ~= target or p ~= response_protocol do
            s,p,m = ss_receive()
            if p == "ping" then
                ss_send(s,"pong",TURTLE:diagnostics())
            end
            if s == target and p == "error" then error(message) end
        end
        return s,p,m
    end
    return success --Should include?
end

local function requireRegion()
    while not fs.isDir("region") or #fs.list("region") <= 0 do
        local _,__,message = ss_send(HOST,"get_region","","region_assignment")
        if type(message) == "table" and #message == 2 and tonumber(message[1]) and tonumber(message[2]) then
            fern_data.readDat(string.format("region/%d_%d.dat",tonumber(message[1]),tonumber(message[2])),0,0)
        end
    end
    local region = assert(fs.list("region")[1],"failed to get region")
    local rX,rZ = region:match("(-?%d+)_(-?%d+)")
    rX,rZ = assert(tonumber(rX)),assert(tonumber(rZ))
    return rX,rZ,region
end
REG_X,REG_Z,REGION = requireRegion()

--Gets the chunk list of chunks needed to explore
local function getChunkList()
    if not fs.exists(REGION) then error("No region file") end
    local file = fs.open("region/"..REGION,"rb")
    local chunkList = {}
    --region file
    for x=0,127 do
        local row = {}
        for z=0,127 do
            local char = file.read()
            if not char then error("invalid region file") end --If the file doesnt contain all 16384 chunks, error
            if char == 0 then table.insert(row,{REG_X + x,REG_Z+z}) --If chunk isnt filled out yet, add to list
            elseif char == 256 then --If variable char, continue eating bytes until you are at the next char
                repeat
                    char = file.read()
                until char ~= 256
            end
        end
        local lb,ub,step = 1,#row,-1
        if x%2 == 0 then lb,ub,step = #row,1,-1 end --switch order so the turtle follows a snake path through a region
        for i=lb,ub,step do
            table.insert(chunkList,row[i])
        end
    end
    return chunkList
end
CHUNK_LIST = getChunkList()

local function synchronize_data()
    local data = fern_data.readDat(REGION)
    local file = fs.open(fern_data.BIOME_METADATA_PATH,"r")
    local metadata = textutils.unserialiseJSON(file.readAll()) or {}
    file.close()
    local _,__,message = ss_send(HOST,"synchronize",{data=data,metadata=metadata},"synchronize_response")
    if type(message) == "table" and message.sync then
        if type(message.data) == "string" and type(message.metadata) == table then
            local file = fs.open(fern_data.BIOME_METADATA_PATH,"w+")
            file.write(textutils.serialiseJSON(message.metadata))
            file.close()
            local file = fs.open("region/"..REGION,"w+")
            file.write(message.data)
            file.close()
        end
    end
end

local function sendData()
    local biome = TURTLE:getBiome()
    local _,__,message = ss_send(HOST,"data",{chunk=TURTLE:getChunk(),biome=biome},"data_success")
end

local function main()
    synchronize_data()
    while #CHUNK_LIST > 0 do
        local chunk = table.remove(CHUNK_LIST)
        parallel.waitForAny(function() TURTLE:moveToChunk(chunk[1],chunk[2]) end,function() while true do ss_receive() end end)
        sendData()
    end
    synchronize_data()
end
