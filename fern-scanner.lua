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