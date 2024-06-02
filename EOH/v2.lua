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
        transferFluid = function(sinkSide, count)
            --if targetSlot == nil then
            --    targetSlot = findEmptySlot(t.getAllStacks(targetSide).getAll())
            --end
            -- sourceSide, sinkSide, count, sourceSlot, sinkSlot
            return t.transferFluid(side, sinkSide, count)
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
    print("参数错误, ./v1.lua <氢气数量 M> <氮气数量 M> <鸿蒙运行时间 秒>")
    exit(0)
end

local hydrogenAmount = tonumber(args[1])
local nitrogenAmount = tonumber(args[2])
local transferAmount = 0.5 -- G
--local transferAmount = tonumber(args[3])
local eohRuntime = tonumber(args[3])
colorPrint(GREEN, "参数: 氢气数量 = " .. tostring(hydrogenAmount) .. " G")
colorPrint(GREEN, "参数: 氮气数量 = " .. tostring(nitrogenAmount) .. " G")
--colorPrint(GREEN, "参数: 每次转运数量 = " .. tostring(transferAmount) .. " G")
colorPrint(GREEN, "参数: 鸿蒙运行时间 = " .. tostring(eohRuntime) .. " 秒")

local masterSwitchComponent = getComponent("redstone", "")
local masterSwitch = {
    isOn = function()
        return masterSwitchComponent.getInput(sides.down) > 0
    end,
}

local transposer = getComponent("transposer", "")

local inputH = getTransposerSide(transposer, sides.up, "inputH")
local inputN = getTransposerSide(transposer, sides.down, "inputN")
local outputSide = sides.east
--local output = getTransposerSide(transposer, sides.east, "output")


--- logic


local States = {
    PUSHING_FLUIDS = 1, -- 等流体进入鸿蒙
    RUNNING = 2, -- 鸿蒙正在跑
}

local state = States.PUSHING_FLUIDS
local timeCounter = 0
local tickDelay = 1 -- seconds

local function setState(newState)
    if state ~= newState then
        state = newState
        return true
    end
    return false
end

local ONE_G = 1000000000

local function update()
    if not masterSwitch.isOn() then
        colorPrint(GREEN, "主控已关闭, 停止控制")
        return
    end

    if state == States.PUSHING_FLUIDS then
        colorPrint(GREEN, "开始转移氢气")
        local pushedH = 0
        while hydrogenAmount - pushedH > 1e-6 do
            local remainingToPush = hydrogenAmount - pushedH;

            local thisTimePush = transferAmount;
            if remainingToPush < transferAmount then
                thisTimePush = remainingToPush;
            end

            colorPrint(GREEN, "请求转移 " .. tostring(thisTimePush) .. " G, 总共还缺少 " .. tostring(remainingToPush) .. " G")
            local success, transferred = inputH.transferFluid(outputSide, thisTimePush * ONE_G)
            if success then
                pushedH = pushedH + transferred / ONE_G;
                colorPrint(GREEN, "转移: " .. tostring(transferred / ONE_G) .. " G")
            else
                colorPrint(RED, "转移失败, 睡一会")
            end
            os.sleep(2)
        end

        colorPrint(GREEN, "开始转移氮气")
        local pushedN = 0
        while nitrogenAmount - pushedN > 1e-6 do
            local remainingToPush = nitrogenAmount - pushedN;

            local thisTimePush = transferAmount;
            if remainingToPush < transferAmount then
                thisTimePush = remainingToPush;
            end

            colorPrint(GREEN, "请求转移 " .. tostring(thisTimePush) .. " G, 总共还缺少 " .. tostring(remainingToPush) .. " G")
            local success, transferred = inputN.transferFluid(outputSide, thisTimePush * ONE_G)
            if success then
                pushedN = pushedN + transferred / ONE_G;
                colorPrint(GREEN, "转移成功: " .. tostring(transferred / ONE_G) .. " G")
            else
                colorPrint(RED, "转移失败, 睡一会")
            end
            os.sleep(2)
        end

        colorPrint(BLUE, "鸿蒙开始工作了, 开始等待 " .. tostring(eohRuntime) .. " 秒")

        timeCounter = 0
        tickDelay = 60
        if tickDelay > eohRuntime then
            tickDelay = eohRuntime
        end
        setState(States.RUNNING)
    elseif state == States.RUNNING then
        if timeCounter <= eohRuntime then
            if timeCounter % 60 == 0 then
                colorPrint(GREEN, "等待鸿蒙工作, 倒计时: " .. tostring(eohRuntime - timeCounter))
            end
            return
        end
        colorPrint(BLUE, "鸿蒙工作完成")

        --local items = input.getAllItems()
        --for i = 0, 107 do
        --    local item = items[i];
        --    if not isNullOrEmpty(item) then
        --        input.moveItem(i + 1, output, nil)
        --        colorPrint(GREEN, "转移物品: " .. item.label)
        --    end
        --end
        --
        --colorPrint(BLUE, "转移完成, 继续等待 AE 推送物品")

        timeCounter = 0
        tickDelay = 1
        setState(States.PUSHING_FLUIDS)
    end
end

colorPrint(GREEN, "Hello")
--colorPrint(GREEN, "等待 AE 推送物品")

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