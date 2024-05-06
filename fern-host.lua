local fern_data = require("fern-data")

peripheral.find("modem",rednet.open)
if not rednet.isOpen() then error("Must have a connected rednet to host") end
--Using rednet host so scanners can find this computer
rednet.host("FERN-HOST",""..math.random(999999)) --They force you to use a hostname :(


local function ss_receive()
    --@2m80_
    
    return sender, protocol, message --Just like rednet?
end

local function ss_send(target,protocol,message)
    --@2m80_
    return success --Should include?
end

--Gets the path to the region file for the chunkX,chunkZ
local function getRegionPath(chunkX,chunkZ)
    rX,rZ = math.floor(chunkX/128),math.floor(chunkZ/128) --The region coordinates of the data

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
        local region = {math.floor(tonumber(chunk[1])/256),math.floor(tonumber(chunk[2])/256)}
        --If the turtle does not have permission to edit that region then error
        if tonumber(fern_data.getRegionAssignment(region)) ~= sender then ss_send(sender,"error",{err="invalid_region",protocol=protocol,message=message}) end
        --If no biome was sent or a non-string biome was sent then error
        if type(message.biome) ~= "string" then ss_send(sender,"error",{err="invalid_biome",protocol=protocol,message=message}) end
        local path = getRegionPath(tonumber(chunk[1]),tonumber(chunk[2]))
        fern_data.writeDat(path,chunk[1],chunk[2],message.biome)
    end
end      