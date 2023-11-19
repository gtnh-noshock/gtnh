local os = require("os");
local component = require("component")
local sides = require("sides")

local enable = component.redstone
local ob = component.weather_obelisk;
local storm = ob.weather_modes.storm;

print("start")

while true do
    -- 这条用来读取红石信号，请使用红石 I/O 端口 (Redstone I/O)来接收信号，其中（sides.east)的east是接收红石信号的方向，根据你的布局自行更改
    x = enable.getInput(sides.east);
    if ob.canActivate(storm) and x > 0 then
        ob.activate();
        print("active")
    end

    -- 每30s检测一次，数字可以自行更改，但是不推荐太低，会导致方尖碑二连发
    os.sleep(10);
end