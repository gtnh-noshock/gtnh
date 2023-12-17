local component = require("component")
local os = require("os")
local sides = require("sides")
local event = require("event")

local all = {}
local n = 0

-- 输入 从其中抽取
local input = sides.down
-- 输出
local output = sides.up
-- 输出容器中流体的比例, 通常为0.5
local fluid_ratio = 0.5

-- 获取所有的转运器
for address, componentType in component.list() do
    if (componentType == "transposer") then
        print("find transposer: ", address, componentType)
        all[n] = component.proxy(address)
        n = n + 1
    end
end

-- 无限循环,如果想新加入转运器的话直接加入转运器,随后关机再启动程序即可
local keyDown
while (true) do
    _, _, keyDown = event.pull(1, "key_down")
    if keyDown then
        print("BYE!")
        break
    end
    for i, trans in pairs(all) do
        print(i)
        local current = trans.getFluidInTank(output)
        if (
                current ~= nil
                        and current[1] ~= nil
                        and current[1].amount > current[1].capacity * fluid_ratio
        ) then
            local fluid_count = current[1].amount - current[1].capacity * fluid_ratio
            if (trans.transferFluid(input, output, fluid_count)) then
                print("transferred ", fluid_count, " mb fluid")
            else
                print("transfer fluid failed , address: ", trans.address)
            end
        else
            print("skip: ", trans.address)
        end
    end
    -- 每次转运后延迟1t
    os.sleep(0.05)
end