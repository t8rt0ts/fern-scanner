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
return {BIOME_METADATA_PATH=BIOME_METADATA_PATH,biomeToNum=biomeToNum,numToBiome=numToBiome,readDat=readDat,writeDat=writeDat}