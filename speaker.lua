local f = {}
do
    local perips = {
        "redstoneIntegrator_24",
        "redstoneIntegrator_25",
        "redstoneIntegrator_26",
        "redstoneIntegrator_27",
        "redstoneIntegrator_28",
        "redstoneIntegrator_29",
        "redstoneIntegrator_30",
        "redstoneIntegrator_31",
        "redstoneIntegrator_32",
        "redstoneIntegrator_33",
    }
    local wrapped_perips = {}
    for k,v in pairs(perips) do
        local p = assert(peripheral.wrap(v))
        f[k] = function(side) p.setOutput(side,true);sleep(0.05);p.setOutput(side,false) end
    end
end



local SP = {
    ["--DOXXER--"] = function() f[1]("east") end,
    ["minecraft:overworld"] = function() f[1]("north") end,
    ["minecraft:the_nether"] = function() f[1]("west") end,
    ["minecraft:the_end"] = function() f[1]("south") end,
    ["--DOXXER OUT--"] = function() f[1]("up") end,
    ["-"] = function() f[2]("east") end,
    [" "] = function() f[2]("north") end,
    ["_"] = function() f[2]("west") end,
    [":"] = function() f[2]("south") end,
    [","] = function() f[2]("up") end,
    a = function() f[3]("down") end,
    b = function() f[3]("east") end,
    c = function() f[3]("north") end,
    d = function() f[3]("west") end,
    e = function() f[3]("south") end,
    f=function() f[4]("east") end,
    g=function() f[4]("north") end,
    h=function() f[4]("west") end,
    i=function() f[4]("south") end,
    j=function() f[4]("up") end,
    k = function() f[5]("down") end,
    l = function() f[5]("east") end,
    m = function() f[5]("north") end,
    n = function() f[5]("west") end,
    o = function() f[5]("south") end,
    p=function() f[6]("east") end,
    q=function() f[6]("north") end,
    r=function() f[6]("west") end,
    s=function() f[6]("south") end,
    t=function() f[6]("up") end,
    u = function() f[7]("down") end,
    v = function() f[7]("east") end,
    w = function() f[7]("north") end,
    x = function() f[7]("west") end,
    y = function() f[7]("south") end,
    z = function() f[8]("up") end,
    Perfectellis19 = function() f[8]("east") end,
    ckupen = function() f[8]("north") end,
    t8rt0t = function() f[8]("west") end,
    Superbug3003 = function() f[8]("south") end,
    ["0"] = function() f[9]("down") end,
    ["1"] = function() f[9]("east") end,
    ["2"] = function() f[9]("north") end,
    ["3"] = function() f[9]("west") end,
    ["4"] = function() f[9]("south") end,
    ["5"] = function() f[10]("east") end,
    ["6"] = function() f[10]("north") end,
    ["7"] = function() f[10]("west") end,
    ["8"] = function() f[10]("south") end,
    ["9"] = function() f[10]("up") end
}
local mt = {}

local expect = require("cc.expect").expect

setmetatable(SP,mt)

mt.__index = mt

function mt:__call(name)
    expect(1,name,"string","number")
    if self[name] then self[name]();return true end
    name = tostring(name):lower()
    for i=1,#name do
        if self[name:sub(i,i)] then self[name:sub(i,i)]()
        else return false end
    end
end

return SP
