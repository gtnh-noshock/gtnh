local c = require("component")
local internet = require("internet")
local event = require("event")

local gtMachine = nil

for address, _ in pairs(c.list("gt_machine")) do
  gtMachine = address
end

print("station: " .. gtMachine)

local i = 60
local ascii

while true do
  _, _, ascii = event.pull(1, "key_down")
  if ascii == 115 then
      print("BYE!")
      break
  end
  i = i + 1
  if i >= 60 then
  	i = 0
    local obj = ""
    for _, v in pairs(c.proxy(gtMachine).getSensorInformation()) do
      obj = obj .. "\n" .. v
    end
    print(obj)
    local req = internet.request("http://localhost:8008/oc/energy", obj, { ["content-type"] = "text/plain" })
  end
	os.sleep(1)
end