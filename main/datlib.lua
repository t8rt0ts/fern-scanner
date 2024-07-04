--Paths
local datLibMD = "metadata/.datLib.json"
local biomeMD = "metadata/biomes.json"
--Constants
local e = require("cc.expect")
local expect,range = e.expect,e.range
local DEFAULT_MD = {byteSizes = {}}
local DAT = {
    metadata = DEFAULT_MD,
    biomes = {},
    ids = {}
}

if fs.exists(datLibMD) then
    local file = fs.open(datLibMD,"r")
    DAT.metadata = textutils.unserialiseJSON(file.readAll()) or DEFAULT_MD
    file.close()
end
if fs.exists(biomeMD) then
    local file = fs.open(biomeMD,"r")
    DAT.biomes = textutils.unserialiseJSON(file.readAll()) or {}
    file.close()
    --Add the reverse biome list
    for k,v in ipairs(DAT.biomes) do
        DAT.ids[v] = k
    end
end

function DAT.addBiome(biomeStr)
    expect(1,biomeStr,"string")
    if DAT.ids[biomeStr] then return nil,"biome already exists" end
    table.insert(DAT.biomes,biomeStr)
    local file = fs.open(biomeMD,"w+")
    file.write(textutils.serialiseJSON(DAT.biomes))
    file.close()
    DAT.ids[biomeStr] = #DAT.biomes
    return #DAT.biomes
end

function DAT:getByteSize()
    if not self.path then return nil,"No path" end
    if not DAT.metadata.byteSizes[self.path] then
        DAT.metadata.byteSizes[self.path] = 1
        local file = fs.open(datLibMD,"w+")
        file.write(textutils.serialiseJSON(DAT.metadata))
        file.close()
        return 1
    end
    return DAT.metadata.byteSizes[self.path]
end

function DAT:increaseByteSize()
    self.file.seek("set",0)
    local oldData = self.file.readAll()
    local byteSize = self:getByteSize()
    self.file.seek("set",0)
    self.file.write(oldData:gsub(string.rep(".",byteSize),function(str) return string.char(0) .. str end))
    self.file.flush()
    DAT.metadata.byteSizes[self.path] = byteSize + 1
    local file = fs.open(datLibMD,"w+")
    file.write(textutils.serialiseJSON(DAT.metadata))
    file.close()
    self.byteSize = byteSize + 1
    return byteSize + 1
end

function DAT:open(path)
    expect(1,path,"string")
    local dat = {}
    setmetatable(dat,self)
    self.__index = self
    dat.path = path
    dat.byteSize = dat:getByteSize()
    if not fs.exists(path) then
        local file = fs.open(path,"w+")
        file.write(string.rep(string.char(0),16384*dat.byteSize))
        file.close()
    end
    dat.file = assert(fs.open(path,"r+b"))
    return dat
end

function DAT:close()
    if self.file then return self.file.close() end
end

function DAT:getBiome(cX,cZ,biomes)
    range(cX,0,127)
    range(cZ,0,127)
    expect(3,biomes,"table","nil")
    if not self.file then error("No attached file") end
    self.file.seek("set",self.byteSize*(cX+cZ*128))
    local id = 0
    for i=1,self.byteSize do
        id = id*256+self.file.read()
    end
    biomes = biomes or DAT.biomes
    return biomes[id]
end

function DAT:setBiome(cX,cZ,biome)
    range(cX,0,127)
    range(cZ,0,127)
    expect(3,biome,"string")
    if not self.path then error("No path to dat file") end
    local id = DAT.ids[biome]
    if not id then id = DAT.addBiome(biome) end
    if id >= 256^self.byteSize then self:increaseByteSize() end
    self.file.seek("set",self.byteSize*(cX+cZ*128))
    local str = ""
    for i=1,self.byteSize do
        str = string.char(id%256) .. str
        id = math.floor(id/256)
    end
    self.file.write(str)
    self.file.flush()
    return true
end

function DAT:getNextChunk()
    self.file.seek("set",0)
    local data = self.file.readAll()
    local index = data:find(string.rep(string.char(0),self.byteSize))
    if index then return (index-1)%128,math.floor((index-1)/128) end
end
    
return DAT
