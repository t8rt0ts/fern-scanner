--Pastebin updater for the fern scanner

local files = {
    {"yTARGS6A","fern-scanner.lua",true}
}

--Clears out comments and whitespace
local function saveSpace(path)
    if not fs.exists(path) or fs.isDir(path) then return false end
    local file = fs.open(path,"r")
    local data = file.readAll()
    file.close()
    data = data:gsub("--.*\n","\n") --removes comments
    data = data:gusb("\n%s+","\n") --Removing beginning whitespace
    data = data:gusb("%s+\n","\n") --Removing ending whitespace
    return data  
end

local function update(pstbnCode,fileName,run,...)
    fs.delete("downloads")
    shell.run("pastebin get "..pstbnCode .. " /downloads/" .. fileName)
    local file = fs.open(fileName,"w+")
    file.write(saveSpace("/downloads/"..fileName))
    file.close()
    if run then shell.run(fileName,...) end
end

for k,v in pairs(files) do
    update(unpack(v))
end
