BIOME_METADATA_PATH = "biomes.json"
REGION_METADATA_PATH = "region_assignment.json"
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

--Drew all this out, hopefully this is the good formula
local function getNextRegion(tX,tZ)
    if tX+tZ < 0 then
        if tX - tZ > 0 then return tX - 1,tZ
        else return tX, tZ + 1 end
    else
        if tX - tZ < 0 then return tX + 1, tZ
        else return tX, tZ - 1 end
    end
end

--turtleID = id of the computer setting the region
--region = the {x,z} data values of the region.
local function setRegionAssignment(turtleID,region)
    if type(region) ~= "table" or not string.match(textutils.serialiseJSON(region) or "","^%[%-?%d+,%-?%d+%]$") or not tonumber(turtleID) then return false end
    local region_data = {}
    if fs.exists(REGION_METADATA_PATH) then 
        local file = fs.open(REGION_METADATA_PATH,"r")
        region_data = textutils.unserialiseJSON(file.readAll()) or {}
        file.close()
    end
    region_data[textutils.serialiseJSON(region)] = tonumber(turtleID)
    local file = fs.open(REGION_METADATA_PATH,"w+")
    file.write(textutils.serialiseJSON(region_data))
    file.close()
    return true
end
--Gets the region assigned to a specific turtle
--If no turtleID provided, returns the entire region assignment data as a table
--If turtleID provided as a region (json string or table) then it tries to return the turtleID for that region
--Otherwise, returns the region corresponding to the turtle id
local function getRegionAssignment(turtleID)
    local region_data = {}
    if fs.exists(REGION_METADATA_PATH) then 
        local file = fs.open(REGION_METADATA_PATH,"r")
        region_data = textutils.unserialiseJSON(file.readAll()) or {}
        file.close()
    end
    if not turtleID then return region_data
    elseif type(turtleID) == "table" or type(turtleID) == "string" then
        if region_data[turtleID] then return region_data[turtleID] end
        return
    end
    if not tonumber(turtleID) then error("Invalid arguments") end
    local tX,tZ = 0,0
    while true do
        local key = string.format("[%d,%d]",tX,tZ)
        if region_data[key] == turtleID then return {tX,tZ}
        elseif not region_data[key] then
            setRegionAssignment(turtleID,{tX,tZ})
            return {tX,tZ}
        end
        tX,tZ = getNextRegion(tX,tZ)
    end
end

return {BIOME_METADATA_PATH=BIOME_METADATA_PATH, biomeToNum=biomeToNum, numToBiome=numToBiome, readDat=readDat, writeDat=writeDat, getRegionAssignment=getRegionAssignment}
