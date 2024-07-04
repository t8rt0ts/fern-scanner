--constants
local datlib = require("datlib")
local colorMap = require("colorMap")
local gpu = peripheral.find("tm_gpu")
if not gpu then
    local tName = "monitor_3"
    local bName = "monitor_4"
    local redirect = "monitor_5"
    if not peripheral.wrap(tName) or not peripheral.wrap(bName) then error("Please make sure you have an attached gpu or two attached monitors") end
    tm = peripheral.wrap(tName)
    bm = peripheral.wrap(bName)
    if peripheral.wrap(redirect) then
        local oldTerm = term.current()
        term.redirect(peripheral.wrap(redirect))
    end
end
local inverseColors = {}
for k,v in pairs(colorMap) do
    inverseColors[v] = k
end


local maxX,maxY
local currentDat,currentKey,currentRegion,currentBiome,cache

if gpu then
    gpu.setSize(64)
    gpu.refreshSize()
    gpu.sync()
    gpu.clear()
else
    tm.setTextScale(0.5)
    tm.setBackgroundColor(colors.black)
    tm.clear()
    bm.setTextScale(0.5)
    bm.setBackgroundColor(colors.black)
    bm.clear()
    maxX,maxY = tm.getSize()
end


    

local loaded_dats,loaded_biomes = {},{}


local function drawBiome(x,y,biome)
    if gpu then
        return gpu.filledRectangle(x,y,1,1,colorMap[biome] or 0xFFFFFFFF)
    else
        x,y = x+1,y+1
        if y <= maxY then
            -- print("tm",x,y,biome)
            tm.setCursorPos(x,y)
            tm.setBackgroundColor(colorMap.rgbaToColor(colorMap[biome] or 0xFFFFFFFF))
            tm.write(" ")
        else
            -- print("bm",x,y-maxY,biome,y)
            bm.setCursorPos(x,y-maxY)
            bm.setBackgroundColor(colorMap.rgbaToColor(colorMap[biome] or 0xFFFFFFFF))
            bm.write(" ")
        end
    end
end

--Region path looks like disk82/regions/0_0.dat
--Its corresponding biome path would look like disk82/metadata/biomes.json
local function getBiomeMap(regionPath)
    local file = fs.open(regionPath:match("^%w+").."/metadata/biomes.json","r")
    local map = textutils.unserialiseJSON(file and file.readAll() or "{}")
    if file then file.close() end
    return map
end

local regions = fs.find("*/regions/*.dat")
local loaded_regions = {}

for k,v in pairs(regions) do
    local key = v:match("/(%-?%d+_%-?%d+)%.dat")
    loaded_dats[key] = datlib:open(v)
    loaded_biomes[key] = getBiomeMap(v)
    table.insert(loaded_regions,key)
end

local function renderRegion(regionKey)
    local rX,rZ = regionKey:match("(%-?%d+)_(%-?%d+)")
    if not tonumber(rX) or not tonumber(rZ) then return false end
    local x,z = tonumber(rX)*128,tonumber(rZ)*128
    local biomeMap = loaded_biomes[regionKey]
    local dat = loaded_dats[regionKey]
    for i=0,127 do
        for j=0,127 do
            local biome = dat:getBiome(i,j,biomeMap)
            if biome then
                if gpu then
                    drawBiome(x+i,z+j,biome)
                else
                    drawBiome(i,j,biome)
                    cache[string.format("%d_%d",i,j)] = biome
                end
            end
        end
    end
    --dat:close()
    return true
end

local function refresh()
    gpu.clear()
    gpu.refreshSize()
    for k,v in pairs(loaded_regions) do
        renderRegion(v)
        sleep(0)
    end
    gpu.sync()
end

local function gpuClickWatcher()
    while true do
        local _,x,y,sneaking = os.pullEvent("tm_monitor_touch")
        local rX,rZ = math.floor(x/128),math.floor(y/128)
        local key = string.format("%d_%d.dat",rX,rZ)
        local dat = loaded_dats[key]
        local biome = dat:getBiome(x%128,y%128,loaded_biomes[key])
        term.setTextColor(colorMap.rgbaToColor(colorMap[biome]))
        print(biome)
    end
end

local function monitorClickWatcher(cache)
    -- print(regionKey)
    -- local dat = loaded_dats[regionKey]
    -- local biomeMap = loaded_biomes[regionKey]
    while true do
        _,mon,x,y = os.pullEvent("monitor_touch")
        x,y = math.min(x-1,127),math.min(y-1,127)
        cX,cY = currentRegion[1]*128 + x, currentRegion[2]*128 + y
        local key = string.format("%d_%d",x,y)
        if mon == tName then
            -- local biome = dat:getBiome(x,y,biomeMap)
            local biome = cache[key]
            term.setTextColor(colorMap.rgbaToColor(colorMap[biome] or 0xFFFFFFFF))
            print(cX*16,cY*16,biome)
        else
            -- local biome = dat:getBiome(x,math.min(y+maxY,127),biomeMap)
            local biome = cache[key]
            term.setTextColor(colorMap.rgbaToColor(colorMap[biome] or 0xFFFFFFFF))
            print(cX*16,cY*16,biome)
        end
    end
end

local function refreshLoop()
    while true do
        refresh()
        sleep(60)
    end
end
local args = {...}
local s,err = pcall(function()
        if gpu then
            parallel.waitForAny(gpuClickWatcher,refreshLoop)
        else
            if tonumber(args[1]) and tonumber(args[2]) and loaded_dats[string.format("%d_%d",tonumber(args[1]),tonumber(args[2]))] then
                currentKey = string.format("%d_%d",tonumber(args[1]),tonumber(args[2]))
                cache = {}
                renderRegion(currentKey)
                currentDat = loaded_dats[currentKey]
                currentRegion = {tonumber(args[1]),tonumber(args[2])}
                currentBiome = loaded_biomes[currentKey]
                monitorClickWatcher(cache)
            else
                error("Please provide a region to scan in the format `x (number)` `z (number)`")
            end
        end
end)
if not s then
    for k,v in pairs(loaded_dats) do
        pcall(function() v:close() end)
    end
    if oldTerm then term.redirect(oldTerm) end
    error(err)
end 
