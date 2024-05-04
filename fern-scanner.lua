BIOME_METADATA_PATH = "biomes.json"
--Turtles store their own biome numbers so they are less reliant on a central computer
local function biomeToNum(biome)
    if type(biome) ~= "string" then error("Biome id must be a string") end
    local data = {}
    if fs.exists(BIOME_METADATA_PATH) then --Read biome data
        local file = fs.open(BIOME_METADATA_PATH,"r")
        data = textutils.unserialiseJSON(file.readAll()) or {}
        file.close()
    end
    if data[biome] then return data[biome] end
    local next_num = 1
    for k,v in pairs(data) do
        if v >= next_num then next_num = v+1 end --New biome number will always be greater than previous biome numbers
    end
    data[biome] = next_num
    local file = fs.open(BIOME_METADATA_PATH,"w+") --Open in rewrite mode
    file.write(textutils.serialiseJSON(data))
    file.close()
    return next_num
end
--Gets the biome
local function numToBiome(num)
    num = tonumber(num) or error("Must provide a number for the biome")
    if not fs.exists(BIOME_METADATA_PATH) then error("No biome metadata to read") end
    local file = fs.open(BIOME_METADATA_PATH,"r")
    local data = textutils.unserialiseJSON(file.readAll()) or {}
    file.close()
    for k,v in pairs(data) do
        if v == num then return k end
    end
    error("No biome found")
end
--Dat files contain bytes
--cX,cZ: number 0-127 telling the chunkX and chunkZ position within the region of the .dat
--Bytes in .dat file:
--0 = no chunk data at position
--1-254 = literal numbers 1-254 (used with the biomes.json metadata path)
--255 = do 255 + the next byte (recursively if the next byte is also 255)
local function readDat(path,cX,cZ)
    if type(path) ~= "string" then error("No path provided") end
    if not fs.exists(path) then
        local file = fs.open(path,"w+")
        file.write(string.rep(string.char(0),16384))
        file.close()
        return 0
    end
    if tonumber(cX) and tonumber(cZ) then
        local file = fs.open(path,"rb")
        local index = (tonumber(cX)*128) + tonumber(cZ)
        local str = file.read(index) --If there are no 255s, this is all the data until the data we want to read
        str,matches = str:gsub(string.char(255),"")
        while matches > 0 do --eating up extra bytes to account for the extra bytes added by each 255
            if file.read() ~= 255 then matches = matches - 1 end --If 255, keep going
        end
        local num,char = 0,0
        repeat --read until not hitting 255
            char = file.read()
            num = num + char
        until char ~= 255
        file.close()
        return num
    end
    --If not specific chunk, then return the entire string
    local file = fs.open(path,"rb")
    local data = file.readAll()
    file.close()
    return data
end

local function writeDat(path,cX,cZ,biomeOrNum)
    if type(path) ~= "string" then error("No path provided") end
    if not tonumber(cX) or not tonumber(cZ) then error("No chunk coordinates provided") end
    if not fs.exists(path) then --Filling out default file
        local file = fs.open(path,"w+")
        file.write(string.rep(string.char(0),16384))
        file.close()
    end
    if type(biomeOrNum) == "string" then biomeOrNum = biomeToNum(biomeOrNum) --If string, tries to convert into number, registering the biome if necessary
    elseif type(biomeOrNum) ~= "number" or not numToBiome(biomeOrNum) then error("Invalid biome provided") end --If not a number or not a valid biome, errors
    local file = fs.open(path,"rb")
    local index = (tonumber(cX)*128) + tonumber(cZ)
    local str = file.read(index) --If there are no 255s, this is all the data until the data we want to read
    _,matches = str:gsub(string.char(255),"")
    while matches > 0 do --eating up extra bytes to account for the extra bytes added by each 255
        local char = file.read()
        str = str .. char
        if char ~= 255 then matches = matches - 1 end --If 255, keep going
    end
    --Adding the new biome num
    while biomeOrNum >= 255 do
        str = str .. string.char(255)
        biomeOrNum = biomeOrNum - 255
    end
    str = str .. string.char(biomeOrNum)
    --clearing out the original dat from the file buffer
    local char
    repeat
        char = file.read()
    until char ~= 255
    --Adding the rest of the .dat to the file
    str = str .. file.readAll()
    file.close()
    local file = fs.open(path,"w+")
    file.write(str)
    file.close()
end



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
    return turt
end
