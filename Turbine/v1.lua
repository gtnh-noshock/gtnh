local component = require("component")
local os = require("os")
local sides = require("sides")
local event = require("event")

local all = {}
local n = 0

-- 输入
local input = sides.up
-- 输出
local output = sides.down
-- 输出容器中流体的目标量 锡等离子体 254/s
local fluid_target = 254

-- 获取所有的转运器
for address, componentType in component.list() do
    if (componentType == "transposer") then
        print("find transposer: ", address, componentType)
        all[n] = component.proxy(address)
        n = n + 1
    end
end

-- 无限循环,如果想新加入转运器的话直接加入转运器,随后关机再启动程序即可
local ascii
while (true) do
    _, _, ascii = event.pull(1, "key_down")
    if ascii == 115 then
        print("BYE!")
        break
    end
    for _, trans in pairs(all) do
        local origin = trans.getFluidInTank(input)
        local current = trans.getFluidInTank(output)
        if (current ~= nil
                and origin ~= nil
                and current[1] ~= nil
                and origin[1] ~= nil
                and current[1].amount < fluid_target
                and origin[1].amount > fluid_target
        ) then
            local fluid_count = fluid_target - current[1].amount
            if (trans.transferFluid(input, output, fluid_count)) then
                print("transferred ", fluid_count, " mb fluid")
            else
                print("transfer fluid failed, address: ", trans.address)
            end
        end
    end
    -- 每次转运后延迟1t
    os.sleep(0.05)
end