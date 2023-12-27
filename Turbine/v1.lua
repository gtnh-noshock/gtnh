local component = require("component")
local os = require("os")
local sides = require("sides")
local event = require("event")

local all = {}
local n = 0

-- 输入
local input = sides.down
-- 输出
local output = sides.up

-- 获取所有的转运器
for address, componentType in component.list() do
    if (componentType == "transposer") then
        print("find transposer: ", address, componentType)
        all[n] = component.proxy(address)
        n = n + 1
    end
end

-- 无限循环, 如果想新加入转运器的话直接加入转运器, 随后关机再启动程序即可
local ascii
while (true) do
    _, _, ascii = event.pull(1, "key_down")
    if ascii == 115 then
        print("BYE!")
        break
    end
    for _, trans in pairs(all) do
        if trans.getInventoryName(input) ~= nil and trans.getInventoryName(output) ~= nil then
            local getItem = trans.getStackInSlot(input, 1)
            local putItem = trans.getStackInSlot(output, 1)
            if (putItem == nil
                    and getItem ~= nil
                    and getItem.size >= 1
            ) then
                if (trans.transferItem(input, output, 1)) then
                    print("transferred " .. 1 .. " " .. getItem.name)
                else
                    print("transfer item failed, address: ", trans.address)
                end
            end
        end
    end
    -- 每次转运后延迟
    os.sleep(1)
end