local colorMap = {
    --Minecraft Offland Biomes
    ["minecraft:ocean"] = 0x0000FF,
    ["minecraft:deep_ocean"] = 0x0000FF,
    ["minecraft:warm_ocean"] = 0x00F4FC,
    ["minecraft:lukewarm_ocean"] = 0x00A8FC,
    ["minecraft:deep_lukewarm_ocean"] = 0x00A8FC,
    ["minecraft:cold_ocean"] = 0x0008FC,
    ["minecraft:deep_cold_ocean"] = 0x0008FC,
    ["minecraft:frozen_ocean"] = 0x8488FA,
    ["minecraft:deep_frozen_ocean"] = 0x8488FA,
    ["minecraft:mushroom_fields"] = 0xF200FF,
    --Minecraft Highland Biomes
    ["minecraft:jagged_peaks"] = 0xDEDEDE,
    ["minecraft:frozen_peaks"] = 0xA8C3E0,
    ["minecraft:stony_peaks"] = 0x9E9E9E,
    ["minecraft:meadow"] = 0x83BB6D, --Based on grass color
    ["minecraft:cherry_grove"] = 0xF29BF1,
    ["minecraft:grove"] = 0x80B497, --Based on grass color
    ["minecraft:windswept_hills"] = 0x53665A,
    ["minecraft:windswept_gravelly_hills"] = 0x5C6660,
    ["minecraft:windswept_forest"] = 0x53665A,
    --Minecraft Woodland Biomes
    ["minecraft:forest"] = 0x79C05A,
    ["minecraft:flower_forest"] = 0x79C05A,
    ["minecraft:taiga"] = 0x619961,
    ["minecraft:old_growth_pine_taiga"] = 0x5E3A18,
    ["minecraft:old_growth_spruce_taiga"] = 0x5E3A18,
    ["minecraft:snowy_taiga"] = 0xA3E6BB,
    ["minecraft:birch_forest"] = 0x80A755,
    ["minecraft:old_growth_birch_forest"] = 0x80A755,
    ["minecraft:dark_forest"] = 0x23693C,
    ["minecraft:jungle"] = 0x17E862,
    ["minecraft:sparse_jungle"] = 0x02F75A,
    ["minecraft:bamboo_jungle"] = 0x02CF4B,
    --Minecraft Wetland Biomes
    ["minecraft:river"] = 0x0000FF,
    ["minecraft:frozen_river"] = 0x8488FA,
    ["minecraft:swamp"] = 0x6A7039,
    ["minecraft:mangrove_swamp"] = 0x5B7039,
    ["minecraft:beach"] = 0xCCCC1F,
    ["minecraft:snowy_beach"] = 0xFFFFFF,
    ["minecraft:stony_shore"] = 0x707070,
    --Minecraft Flatland Biomes
    ["minecraft:plains"] = 0x77AB2F,
    ["minecraft:sunflower_plains"] = 0x77AB2F,
    ["minecraft:snowy_plains"] = 0xFFFFFF,
    ["minecraft:ice_spikes"] = 0x78FAF8,
    --Minecraft Arid Biomes
    ["minecraft:desert"] = 0xEEFF00,
    ["minecraft:savanna"] = 0xAEA42A,
    ["minecraft:savanna_plateau"] = 0xAEA42A,
    ["minecraft:windswept_savanna"] = 0x87823E,
    ["minecraft:badlands"] = 0xC96D04,
    ["minecraft:eroded_badlands"] = 0xC96D04,
    ["minecraft:wooded_badlands"] = 0x9E814D,
    --Minecraft Cave Biomes (shouldnt need but just in case)
    ["minecraft:deep_dark"] = 0x122124,
    ["minecraft:dripstone_caves"] = 0x735C39,
    ["minecraft:lush_caves"] = 0x26FF00
}
for k,v in pairs(colorMap) do
    colorMap[k] = colorMap[k] + 0xFF000000
end
local function compareColors(r1,g1,b1,r2,g2,b2)
    local R = (r2+r1)/2
    if R >= 128 then
        return 3*(r1-r2)^2+4*(g1-g2)^2+2*(b1-b2)^2
    else
        return 2*(r1-r2)^2+4*(g1-g2)^2+3*(b1-b2)^2
    end
    --return (r1-r2)^2+(g1-g2)^2+(b1-b2)^2
end

local normalColors = {
}
for k,v in pairs(colors) do
    if type(v) == "number" then
        local r,g,b = term.getPaletteColor(v)
        normalColors[v] = {math.floor(r*255),math.floor(g*255),math.floor(b*255)}
    end
end

function colorMap.rgbaToColor(rgba)
    local rgb = rgba%0x1000000
    local r = math.floor(rgb/0x10000)
    local g = math.floor((rgb%0x10000)/0x100)
    local b = rgb%0x100
    local min,idx = math.huge,1
    for k,v in pairs(normalColors) do
        local value = compareColors(v[1],v[2],v[3],r,g,b)
        if value < min then
            idx = k
            min = value
        end
    end
    return idx
end

return colorMap
