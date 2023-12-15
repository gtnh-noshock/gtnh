component = require("component")
os = require("os")
sides = require("sides")

local all = {}
local n = 0

-- 输出仓的方位
local side_output_hatch = sides.down
-- 此处为想要输出给的缓存器的方位(比如超级缸等)
local side_buffer = sides.up
-- 此处为控制输出仓中流体的比例, 通常为0.5
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
while (true) do
    for _, trans in pairs(all) do
        local current_fluids = trans.getFluidInTank(side_output_hatch)
        if (
                current_fluids ~= nil
                        and current_fluids[1] ~= nil
                        and current_fluids[1].amount > current_fluids[1].capacity * fluid_ratio
        ) then
            local fluid_count = current_fluids[1].amount - current_fluids[1].capacity * fluid_ratio
            local res = trans.transferFluid(side_output_hatch, side_buffer, fluid_count)
            if (res == false) then
                print("transfer fluid failed , address: ", trans.address)
            else
                print("transferred ", fluid_count, " mb fluid")
            end
        end
    end
    -- 每次转运后延迟1t
    os.sleep(0.05)
end