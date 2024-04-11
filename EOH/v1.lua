local component = require("component")
local event = require("event")
local filesystem = require("filesystem")
local serialization = require("serialization")
local term = require("term")
local coroutine = require("coroutine")
local sides = require("sides")

local function startsWith(text, prefix)
    return text:find(prefix, 1, true) == 1
end

local function getTime()
    local formattedTime = os.date("%Y-%m-%d %H:%M:%S") -- 将时间戳格式化为可读的格式
    return formattedTime
end

local function log(message)
    print(getTime() .. " " .. message)
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
        if v == type and startsWith(k, idPrefix) then
            matchedK = k
            matchedV = v
            matched = matched + 1
            log("[init] getComponent: match " .. type .. " with prefix '" .. idPrefix .. "', found: " .. k)
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
                count = t.getSlotStackSize(side, sourceSlot)
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

local gpu = getComponent("gpu", "")
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

local function colorPrint(color, string)
    color()
    log(string)
    FG()
end


-- END OF UTILITIES

local args = { ... }
if #args < 2 then
    print("参数错误, ./v1.lua <原料输入时间> <鸿蒙运行时间>")
    exit(0)
end

local inputTime = tonumber(args[1])
local eohRuntime = tonumber(args[2])
colorPrint(GREEN, "参数: 原料输入时间 = " .. tostring(inputTime) .. " 秒")
colorPrint(GREEN, "参数: 鸿蒙运行时间 = " .. tostring(eohRuntime) .. " 秒")

local masterSwitchComponent = getComponent("redstone", "")
local masterSwitch = {
    isOn = function()
        return masterSwitchComponent.getInput(sides.down) > 0
    end,
}

local transposer = getComponent("transposer", "")

local input = getTransposerSide(transposer, sides.up, "input")
local output = getTransposerSide(transposer, sides.down, "output")


--- logic


local States = {
    WAITING_FOR_MATERIALS = 0, -- 等 AE 推材料
    PUSHING_FLUIDS = 1, -- 等流体进入鸿蒙
    RUNNING = 2, -- 鸿蒙正在跑
}

local state = States.WAITING_FOR_MATERIALS
local timeCounter = 0
local tickDelay = 1 -- seconds

local function setState(newState)
    if state ~= newState then
        state = newState
        return true
    end
    return false
end

local function update()
    if not masterSwitch.isOn() then
        colorPrint(GREEN, "主控已关闭, 停止控制")
        return
    end

    if state == States.WAITING_FOR_MATERIALS then

        local hasMaterial = false
        local hasProduct = false
        local items = input.getAllItems()
        for i = 0, 10 do
            local item = items[i];
            if not isNullOrEmpty(item) then
                if startsWith(item.name, "gregtech:gt.metaitem.01") then
                    hasMaterial = true
                end
                if startsWith(item.name, "berriespp:Modifier") then
                    hasProduct = true
                end
            end
        end

        if hasMaterial == false or hasProduct == false then
            -- 没有原料
            return
        end

        colorPrint(BLUE, "检测到 AE 原料, 开始等待流体推送")

        timeCounter = 0
        tickDelay = 1
        setState(States.PUSHING_FLUIDS)
    elseif state == States.PUSHING_FLUIDS then
        if timeCounter <= inputTime then
            colorPrint(GREEN, "等待流体推送, 倒计时: " .. tostring(inputTime - timeCounter))
            return
        end
        colorPrint(BLUE, "鸿蒙开始工作了, 开始等待 " .. tostring(eohRuntime) .. " 秒")

        timeCounter = 0
        tickDelay = 60
        setState(States.RUNNING)
    elseif state == States.RUNNING then
        if timeCounter <= eohRuntime then
            if timeCounter % 60 == 0 then
                colorPrint(GREEN, "等待鸿蒙工作, 倒计时: " .. tostring(eohRuntime - timeCounter))
            end
            return
        end
        colorPrint(BLUE, "鸿蒙工作完成, 释放原料和产物")

        local items = input.getAllItems()
        for i = 0, 107 do
            local item = items[i];
            if not isNullOrEmpty(item) then
                input.moveItem(i + 1, output, nil)
                colorPrint(GREEN, "转移物品: " .. item.label)
            end
        end

        colorPrint(BLUE, "转移完成, 继续等待 AE 推送物品")

        timeCounter = 0
        tickDelay = 1
        setState(States.WAITING_FOR_MATERIALS)
    end
end

colorPrint(GREEN, "Hello")
colorPrint(GREEN, "等待 AE 推送物品")

local ascii
while (true) do
    -- check exit
    _, _, ascii = event.pull(1, "key_down")
    if ascii == 115 then
        -- a 或者 s, 忘了是啥
        print("BYE!")
        break
    end

    update()

    os.sleep(tickDelay) -- 不要修改
    timeCounter = timeCounter + tickDelay
end