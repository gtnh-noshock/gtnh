local component = require("component")
local event = require("event")
local filesystem = require("filesystem")
local serialization = require("serialization")
local term = require("term")
local coroutine = require("coroutine")

local coolerTemperatureThreshold = 0.85
local enableReactorByEnergyLevelInertia = 60

local SIDES = {
    down = 0,
    top = 1,
    north = 2,
    south = 3,
    west = 4,
    east = 5
}
---
-- CONST as Config
---


---
-- Reactor Design
---

ReactorDesign = {
    fuel_slots = {},
    cool_slots = {},
    mapping = {},
}

function ReactorDesign:fromTemplate(src)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    local row = 0
    local counter = 0
    for s in src:gmatch("[^\r\n]+") do
        s = s:gsub("^%s*(.-)%s*$", "%1")
        if s == "" then
            goto continue
        end
        row = row + 1
        if string.len(s) ~= 9 then
            error("Each row has 9 slots")
        end
        for i = 1, #s do
            local type = string.sub(s, i, i)
            if type == "F" then
                table.insert(self.fuel_slots, counter)
            elseif type == "C" then
                table.insert(self.cool_slots, counter)
            else
                error("Unknown type " .. type)
            end
            self.mapping[counter] = type
            counter = counter + 1
        end
        :: continue ::
    end
    if row ~= 6 then
        error("Should have 6 rows")
    end
    return obj
end
function ReactorDesign:fuelSlots()
    return self.fuel_slots
end
function ReactorDesign:coolSlots()
    return self.cool_slots
end
function ReactorDesign:numOfFuel()
    return #self.fuel_slots
end
function ReactorDesign:numOfCool()
    return #self.cool_slots
end
function ReactorDesign:slotType(slotNum)
    return self.mapping[slotNum]
end


---
-- Helper functions
---
local function startsWith(text, prefix)
    return text:find(prefix, 1, true) == 1
end

local function printTable(table)
    if table == nil then
        print("nil table")
        return
    end
    if isNullOrEmpty(table) then
        print("empty table")
        return
    end
    for k, v in pairs(table) do
        print(k, v)
    end
end

function isNullOrEmpty(table)
    if table == nil then
        return true;
    end
    for i, v in pairs(table) do
        return false;
    end
    return true;
end

---
-- Returns the component only if the type and name prefixes match only one in the network
---
local function getComponent(type, idPrefix)
    -- Get component
    local matched = 0
    local matchedK = nil
    local matchedV = nil
    for k, v in pairs(component.list(t)) do
        if startsWith(k, idPrefix) then
            matchedK = k
            matchedV = v
            matched = matched + 1
        end
    end
    if matched == 1 then
        return component.proxy(matchedK, matchedV)
    end
    if matched > 1 then
        error("duplicate match for " .. type .. " with prefix " .. idPrefix)
    else
        error("no match for " .. type .. " with prefix " .. idPrefix)
    end
end

local function findNonEmptyIndex(item_in_box)

    local boxLocation = 0

    for idx = 0, #item_in_box, 1 do
        if ((not isNullOrEmpty(item_in_box[idx])) and item_in_box[idx].size > 0) then
            boxLocation = idx + 1
            break
        end
    end
    if boxLocation == 0 then
        return nil
    end
    return boxLocation
end

local function getTransposerSide(t, side, name)
    return {
        getAllItems = function()
            return t.getAllStacks(side).getAll()
        end,
        transposer = t,
        side = side,
        moveItem = function(sourceSlot, target, count, targetSlot)
            if count == nil then
                count = 1
            end
            --if targetSlot == nil then
            --    targetSlot = findEmptySlot(t.getAllStacks(targetSide).getAll())
            --end
            -- sourceSide, sinkSide, count, sourceSlot, sinkSlot
            if targetSlot == nil then
                t.transferItem(side, target.side, count, sourceSlot)
            else
                t.transferItem(side, target.side, count, sourceSlot, targetSlot + 1)
            end
        end,
        name = name,
    }
end

local gpu = getComponent("gpu", "a93")
gpu.setDepth(gpu.maxDepth())

local RED, YELLOW, GREEN, BLUE, PURPLE, CYAN, WHITE, BG, FG, BLACK, CLEAR
function initColor()
    local palette = {
        0x21252B, 0xABB2BF, 0x21252B, 0xE06C75, 0x98C379, 0xE5C07B,
        0x61AFEF, 0xC678DD, 0x56B6C2, 0xABB2BF
    }
    gpu.setBackground(palette[1])
    gpu.setForeground(palette[2])
    RED = function()
        gpu.setForeground(palette[4])
        return ""
    end
    YELLOW = function()
        gpu.setForeground(palette[6])
        return ""
    end
    GREEN = function()
        gpu.setForeground(palette[5])
        return ""
    end
    BLUE = function()
        gpu.setForeground(palette[7])
        return ""
    end
    PURPLE = function()
        gpu.setForeground(palette[8])
        return ""
    end
    CYAN = function()
        gpu.setForeground(palette[9])
        return ""
    end
    WHITE = function()
        gpu.setForeground(palette[10])
        return ""
    end
    BG = function()
        gpu.setBackground(palette[1])
        return ""
    end
    FG = function()
        gpu.setForeground(palette[2])
        return ""
    end
    BLACK = function()
        gpu.setForeground(palette[3])
        return ""
    end
end
initColor()

function colorPrint(color, string)
    color()
    print(string)
    FG()
end

-- local transposer = getComponent("transposer", "264")
local masterSwitch = getComponent("redstone", "fb8")
local masterSwitchSide = SIDES.north
local backupEnergySide = SIDES.top
local energyStationSide = SIDES.west

local reactorThermostat = getComponent("redstone", "fa5")
local reactorThermostatSide = SIDES.top
local reactorController = getComponent("redstone", '027')
local reactorEnabled = false
local enableReactorSide = SIDES.west

local transposer = getComponent("transposer", "992")  -- 只能用一个 transposer
local chestNewFuel = getTransposerSide(transposer, SIDES.east, "chestNewFuel")
local chestNewCooler = getTransposerSide(transposer, SIDES.south, "chestNewCooler")
local chestDamagedCooler = getTransposerSide(transposer, SIDES.north, "chestDamagedCooler")
local chestDamagedFuel = getTransposerSide(transposer, SIDES.top, "chestDamagedFuel")
local reactor = getTransposerSide(transposer, SIDES.west, "reactor")

local design = ReactorDesign:fromTemplate(
        [[
FFCFFFCFF
CFFFCFFFC
FFFCFFFCF
FCFFFCFFF
CFFFCFFFC
FFCFFFCFF
]])
local tes_design = ReactorDesign:fromTemplate(
        [[FFCFFCFFC
              CFFFFCFFF
              FFFCFFFCF
              FCFFFCFFF
              FFFCFFFFC
              CFFCFFCFF
        ]]
)

function initSystem()
    print("Backup energy: " .. tostring(masterSwitch.getInput(backupEnergySide)))
    print("Master switch: " .. tostring(masterSwitch.getInput(masterSwitchSide)))
    print("Energy station: " .. tostring(masterSwitch.getInput(energyStationSide)))
    disableReactor()
end

function disableReactor()
    reactorController.setOutput(enableReactorSide, 0)
    reactorEnabled = false
end

function enableReactor()
    reactorController.setOutput(enableReactorSide, 15)
    reactorEnabled = true
end

function isHighTemperature()
    return reactorThermostat.getInput(reactorThermostatSide) ~= 0
end

function checkTemperature()
    --if reactorController.getInput(enableReactorSide) == 0 then
    --    print("Reactor is disabled. Ignoring temperature check.")
    --    return
    --end,"

    if isHighTemperature() then
        if reactorEnabled then
            colorPrint(RED, "Disabling reactor due to high temperature!")
            disableReactor()
        end
        return
    end

end

local function keyDown(t)
    -- get key. it t defined, the function will wait the key elapsed t most.
    local result
    if t then
        _, _, result = event.pull(t, "key_down")
    else
        _, _, result = event.pull("key_down")
    end
    if not result then
        result = 0
    end
    return result
end

local enableReactorCounter = 0

local function checker()
    while true do
        while true do
            if masterSwitch.getInput(masterSwitchSide) == 0 then
                if reactorEnabled then
                    colorPrint(CYAN, "Master switch is off.")
                    disableReactor()
                end
                coroutine.yield()
            else
                break ;
            end
        end

        while true do
            if masterSwitch.getInput(energyStationSide) ~= 0 then
                enableReactorCounter = enableReactorByEnergyLevelInertia
            end
            if enableReactorCounter == 0 then
                if reactorEnabled then
                    colorPrint(CYAN, "Energy is full!")
                    disableReactor()
                end
                coroutine.yield()
            else
                enableReactorCounter = enableReactorCounter - 1
                break
            end
        end

        checkTemperature()

        local disableReactorSafe = function()
            if reactorEnabled then
                disableReactor()
                coroutine.yield()
            end
        end

        local reactorItems = reactor.getAllItems()
        for i = 0, 53 do
            local item = reactorItems[i]
            local slotType = design:slotType(i)

            --print("Checking i=" .. i .. " type= " .. slotType)
            --printTable(item)

            --if (item == nil or item.maxDamage == 0) then
            --    print("replace fuel at " .. i)
            --    reactor.moveItem(i, chestDamagedFuel)
            --    goto continue
            --end

            if ((not isNullOrEmpty(item)) and slotType == 'C') then
                --replace nearly damaged
                --check if it is already damaged
                local damaged = (item.maxDamage == 0 or ((0.1 + item.damage) / (0.1 + item.maxDamage)) > coolerTemperatureThreshold)
                if damaged then
                    disableReactorSafe()
                    colorPrint(GREEN, "Remove cooler at " .. (i + 1))
                    reactor.moveItem(i + 1, chestDamagedCooler)
                    item = nil
                end
            end

            -- 拿出来坏的 fuel
            if ((not isNullOrEmpty(item)) and slotType == 'F') then
                --阳光化合物
                local damaged = (item.maxDamage == 0)
                if startsWith(item.name, "gregtech:gt.sunnar") then
                    damaged = true
                    colorPrint(GREEN, "Find sunnarium! ")
                end
                if damaged then
                    disableReactorSafe()
                    colorPrint(GREEN, "Remove fuel at " .. (i + 1))
                    reactor.moveItem(i + 1, chestDamagedFuel)
                    item = nil
                end
            end

            if (isNullOrEmpty(item)) then
                disableReactorSafe()
                local newItem = nil
                local src = nil
                if slotType == 'F' then
                    newItem = findNonEmptyIndex(chestNewFuel.getAllItems())
                    src = chestNewFuel
                elseif slotType == 'C' then
                    newItem = findNonEmptyIndex(chestNewCooler.getAllItems())
                    src = chestNewCooler
                end

                if newItem == nil then
                    colorPrint(RED, "Nothing to move!! from " .. src.name)
                else
                    colorPrint(GREEN, "Moving from " .. src.name .. "." .. tostring(newItem) .. " to " .. reactor.name .. "." .. tostring(i))
                    src.moveItem(newItem, reactor, 1, i)
                end
            end
        end

        --开机iff

        local anyEmpty = false
        for i = 0, 53 do
            local item = reactorItems[i]
            local slotType = design:slotType(i)
            if isNullOrEmpty(item) then
                anyEmpty = true
            end
        end

        if not anyEmpty and not isHighTemperature() and not reactorEnabled then
            colorPrint(YELLOW, "Enabling reactor!")
            enableReactor()
        end
        coroutine.yield()
    end
end

local reactorThread = coroutine.create(checker)

initSystem()

while true do
    coroutine.resume(reactorThread)

    if masterSwitch.getInput(backupEnergySide) == 0 then
        colorPrint(RED, "No backup energy!")
        disableReactor()
        return
    end

    local key = keyDown(1) -- capture key
    if key == 115 then
        colorPrint(RED, "BYE!")
        disableReactor()
        break ;
    end
end