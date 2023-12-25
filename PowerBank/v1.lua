local component = require("component")
local event = require("event")
local filesystem = require("filesystem")
local serialization = require("serialization")
local term = require("term")
local coroutine = require("coroutine")

local function startsWith(text, prefix)
    return text:find(prefix, 1, true) == 1
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

-- END OF UTILITIES

-- inputs
local redstoneEnergy20 = getComponent("redstone", "741")
local redstoneEnergy50 = getComponent("redstone", "ce8")
local redstoneEnergy95 = getComponent("redstone", "9f6")

-- outputs
local redstoneStartTurbine = getComponent("redstone", "5df")
local redstoneStartBlastFurnace = getComponent("redstone", "a74")

local States = {
    LOW = 0, -- <20
    TURBINE_CHARGING = 1, -- 20-95
    FULL = 2, -- >95
}

local state = 0

local function setState(newState)
    if state ~= newState then
        state = newState
        print("State: " .. newState)
    end
end

local function updateState()
    if redstoneEnergy20.getInput(sides.up) == 0 then
        setState(States.LOW)
        return
    end

    if redstoneEnergy95.getInput(sides.up) > 0 then
        setState(States.FULL)
        return
    end

    if redstoneEnergy50.getInput(sides.up) == 0 then
        setState(States.TURBINE_CHARGING)
        return
    end
end

local function updateRedstoneOutputs()
    if state == States.LOW then
        redstoneStartTurbine.setOutput(sides.up, 15)
    elseif state == States.TURBINE_CHARGING then
        redstoneStartTurbine.setOutput(sides.up, 15)
    elseif state == States.FULL then
        redstoneStartTurbine.setOutput(sides.up, 0)
    end
    
    if redstoneEnergy20.getInput(sides.up) > 0 then
        redstoneStartBlastFurnace.setOutput(sides.up, 15)
    end
end

-- 无限循环,如果想新加入转运器的话直接加入转运器,随后关机再启动程序即可
local ascii
while (true) do
    -- check exit
    _, _, ascii = event.pull(1, "key_down")
    if ascii == 115 then
        print("BYE!")
        break
    end

    updateState()
    updateRedstoneOutputs()

    os.sleep(0.05)
end