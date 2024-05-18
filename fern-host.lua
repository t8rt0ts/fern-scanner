local fern_data = require("fern-data")

peripheral.find("modem",rednet.open)
if not rednet.isOpen() then error("Must have a connected rednet to host") end
--Using rednet host so scanners can find this computer
rednet.host("FERN-HOST",""..math.random(999999)) --They force you to use a hostname :(


local function ss_receive()
    --@2m80_
    local sender,protocol,message = rednet.receive()
    
    return sender, protocol, message --Just like rednet?
end

local function ss_send(target,protocol,message)
    --@2m80_
    rednet.send(target,protocol,message) --temporary
    return success --Should include?
end

local function canDiskFitRegion(disk,rx,rz)
    local path = "disk"
    if disk >= 2 then
        path = "disk" .. disk
    end
    if not fs.isDir(path) then error("No disk space") end
    --case where region file is in disk
    if fs.exists(path .. "/region/".. rx .. "_" .. rz .. ".dat") then
        if fs.getFreeSpace(path) < 100 then
            return false,path .. "/region/".. rx .. "_" .. rz .. ".dat"
        end
        return true,path .. "/region/".. rx .. "_" .. rz .. ".dat"
    else
        if fs.getFreeSpace(path) < 17000 then
            return false
        end
        return true,path .. "/region/".. rx .. "_" .. rz .. ".dat"
    end
end     

--Gets the path to the region file for the chunkX,chunkZ
local function getRegionPath(chunkX,chunkZ)
    local rX,rZ = math.floor(chunkX/128),math.floor(chunkZ/128) --The region coordinates of the data
    local index = 1
    local canFit = false
    local pathToCopy,path
    while not canFit do
        canFit,path = canDiskFitRegion()
        if not canFit and path then pathToCopy = path end
    end
    if pathToCopy then
        fs.copy(pathToCopy,path)
    end
    --@2m80
    --path would look like "disk0/regions/rX_rZ.dat"?
    --It would ensure there is room for the region to be written as well
    --If there is no room for additional data in the disk, it moves the existing region file to a new disk and returns that new path
    return path
end


local function handle_messages(sender,protocol,message)
    if protocol == "get_region" then
        ss_send(sender,"region_assignment",fern_data.getRegionAssignment(sender))
    --Ideal "data" protocol message:
        --{chunk={cX,cZ},biome="forest"}
    elseif protocol == "data" then
        --Invalid message type error
        if type(message) ~= "table" or type(message.chunk) ~= "table" or not tonumber(chunk[1]) or not tonumber(chunk[2]) then ss_send(sender,"error",{err="invalid_message",protocol=protocol,message=message}) end
        local chunk = message.chunk
        local region = {math.floor(tonumber(chunk[1])/128),math.floor(tonumber(chunk[2])/128)}
        --If the turtle does not have permission to edit that region then error
        if tonumber(fern_data.getRegionAssignment(region)) ~= sender then ss_send(sender,"error",{err="invalid_region",protocol=protocol,message=message}) end
        --If no biome was sent or a non-string biome was sent then error
        if type(message.biome) ~= "string" then ss_send(sender,"error",{err="invalid_biome",protocol=protocol,message=message}) end
        local path = getRegionPath(tonumber(chunk[1]),tonumber(chunk[2]))
        fern_data.writeDat(path,chunk[1]%128,chunk[2]%128,message.biome)
        ss_send(sender,"data_success",message.biome)
    elseif protocol == "synchronize" then
        --TODO: fill out
        ss_send(sender,"synchronize_response","cod")
    elseif protocol == "pong" then
        --TODO
    end
end

if fs.exists("latest.log") then
    local file = fs.open("latest.log","r")
    local time = file.readLine()
    file.close()
    if fs.exists("logs/" .. time .. ".log") then fs.delete("logs/" .. time .. ".log") end
    pcall(function() fs.move("latest.log","logs/" .. time .. ".log") end)
    if fs.exists("latest.log") then fs.delete("latest.log") end
end
local log_file = fs.open("latest.log")
log_file.writeLine(os.date("%y-%m-%d_%H:%M"))
log_file.flush()
    
local function log(msg)
    log_file.writeLine(msg)
    log_file.flush()
end

local function main()
    while true do
        local sender,protocol,message = ss_receive()
        local result = {pcall(function() handle_messages(sender,protocol,message) end)}
        if not result[1] then
            for i=2,#result do
                log("Error" .. tostring(result[i]))
            end
        end
    end
end
