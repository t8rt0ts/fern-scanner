local fern_data = require("fern-data")

--Rot: 0=N,1=E,2=S,3=W
local function Turtle(x,y,z,rot)
    local turt = {x=x,y=y,z=z,rot=rot}
    function turt:equipItem(item,side)
        if type(item) ~= "string" then error("Must be an item") end
        for i=1,16 do
            if (turtle.getItemDetail(i) or {}).name == item then
                turtle.select(i)
                if side == "left" then return turtle.equipLeft() end
                return turtle.equipRight()
            end
        end
        return false
    end
    function turt:updatePosition()
        self:equipItem("computercraft:wireless_modem_advanced")
        peripheral.find("modem",rednet.open)
        local x,y,z = gps.locate()
        if not x then error("Can not find turtle") end
        self.x,self.y,self.z = x,y,z
        if turtle.forward() then
            local x2,y2,z2 = gps.locate()
            if not x2 then error("Can not find turtle") end
            if z2 < z then self.rot = 0
            elseif z2 > z then self.rot = 2
            elseif x2 > x then self.rot = 1
            elseif x2 < x then self.rot = 3
            else error("Could not calculate rotation") end
            assert(turtle.back())
        elseif turtle.back() then
            local x2,y2,z2 = gps.locate()
            if not x2 then error("Can not find turtle") end
            if z2 < z then self.rot = 2
            elseif z2 > z then self.rot = 0
            elseif x2 > x then self.rot = 3
            elseif x2 < x then self.rot = 1
            else error("Could not calculate rotation") end
            assert(turtle.forward())
        else
            error("Please make sure that turtle has space to move to perform the rotation calculation")
        end
    end
    if not tonumber(x) or not tonumber(y) or not tonumber(z) or not tonumber(rot) then turt:updatePosition() end
    function turt:rot(dir)
        if tonumber(dir) then
            local amt = (math.floor(tonumber(dir)) - self.rot)%4
            if amt == 3 then
                assert(turtle.turnLeft())
            else
                for i=1,amt do
                    assert(turtle.turnRight())
                end
            end
            return true
        elseif type(dir) == "string" then
            local dirs = {n=0,e=1,s=2,w=3,north=0,east=1,south=2,west=3}
            local amt = dirs[dir:lower()]
            if not amt then return false end
            return self:rot(amt)
        else
            return false
        end
    end
    function turt:refuel()
        if turtle.getFuelLimit() - turtle.getFuelLevel() <= 2000 then return turtle.getFuelLevel() end
        for i=1,16 do
            turtle.select(i)
            if turtle.refuel(0) then
                local oldLvl = turtle.getFuelLevel()
                turtle.refuel(1)
                local amt = turtle.getFuelLevel() - oldLvl
                local itemsToBurn = math.floor((turtle.getFuelLimit() - turtle.getFuelLevel())/amt)
                turtle.refuel(math.min(turtle.getItemCount(i),itemsToBurn))
            end
            if turtle.getFuelLimit() - turtle.getFuelLevel() <= 2000 then return turtle.getFuelLevel() end
        end
        return turtle.getFuelLevel()
    end       
    function turt:moveToPos(x,y,z,verticalLast)
        if not tonumber(x) or not tonumber(z) then error("Must provide coordinates to travel to") end
        x,y,z = math.floor(tonumber(x)), math.floor(tonumber(y) or 310), math.floor(tonumber(z))
        if not verticalLast then
            if math.abs(self.y - y) > self:refuel() then error("Lack sufficient fuel") end
            while self.y < y do
                assert(turtle.up())
                self.y = self.y + 1
            end
            while self.y > y do
                assert(turtle.down())
                self.y = self.y - 1
            end
        end
        if math.abs(self.x - x) > self:refuel() then error("Lack sufficient fuel") end
        if self.x > x then
            self:rotate("W") --Face west if you are more east than your target
            while self.x ~= x do
                assert(turtle.forward())
                self.x = self.x - 1
            end
        elseif self.x < x then
            self:rotate("E")
            while self.x ~= x do
                assert(turtle.forward())
                self.x = self.x + 1
            end
        end
        if math.abs(self.z - z) > self:refuel() then error("Lack sufficient fuel") end
        if self.z > z then
            self:rotate("N") --Face north (-z) if you are more south(+z) than your target
            while self.x ~= x do
                assert(turtle.forward())
                self.x = self.x - 1
            end
        elseif self.z < z then
            self:rotate("S")
            while self.z ~= z do
                assert(turtle.forward())
                self.z = self.z + 1
            end
        end
        if verticalLast then
            if math.abs(self.y - y) > self:refuel() then error("Lack sufficient fuel") end
            while self.y < y do
                assert(turtle.up())
                self.y = self.y + 1
            end
            while self.y > y do
                assert(turtle.down())
                self.y = self.y - 1
            end
        end
    end
    --Checks and equips the necessary items
    function turt:checkNeededItems()
        if peripheral.getType("left") ~= "chunky" then --If chunkloader not in left slot, try to make sure it is
            if peripheral.getType("right") == "chunky" then --If chunkloader in the wrong slot, put it in the right slot
                if self:equip("computercraft:wireless_modem_advanced") or self:equip("advancedperipherals:environment_detector") then
                    if not self:equip("advancedperipherals:chunk_controller","left") then return false end --If you could replace the right slot with its typical peripherals and put the chunk controller in the left slot then you're okay
                else
                    return false
                end
            else
                if not self:equip("advancedperipherals:chunk_controller","left") then return false end
            end
        end
        if peripheral.getType("right") ~= "environmentDetector" and not self:equip("advancedperipherals:environment_detector") then return false end
        if (peripheral.getType("right") ~= "modem" or not peripheral.wrap("right").isWireless()) and not self:equip("computercraft:wireless_modem_advanced") then return false end
        return true
    end
    function turt:moveToChunk(cX,cZ)
        if not tonumber(cX) or not tonumber(cZ) then return false end
        return self:moveToPos(cX*16,nil,cZ*16)
    end
    return turt
end
