--Pastebin updater for the fern scanner

local files = {
    {"yTARGS6A","fern-scanner.lua",true}
}

local function update(pstbnCode,fileName,run,...)
    fs.delete(fileName)
    shell.run("pastebin get "..pstbnCode .. " " .. fileName)
    if run then shell.run(fileName,...) end
end

for k,v in pairs(files) do
    update(unpack(v))
end