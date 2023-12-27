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
        print(trans)
        print(input)
        print(output)
        print(trans.isPresent(input))
        print(trans.isPresent(output))
        if trans.isPresent(input) and trans.isPresent(output) then
            local origin = trans.getStackInSlot(input, 0)
            local current = trans.getStackInSlot(output, 0)
            if (current ~= nil
                    and origin ~= nil
                    and current.name == "minecraft:air"
                    and origin.size >= 1
            ) then
                if (trans.transferItem(input, output, 1)) then
                    print("transferred " .. 1 .. " " .. origin.name)
                else
                    print("transfer item failed, address: ", trans.address)
                end
            end
        end
    end
    -- 每次转运后延迟
    os.sleep(1)
end