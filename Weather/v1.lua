local os = require("os");
local component = require("component");


local function startsWith(text, prefix)
    return text:find(prefix, 1, true) == 1
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



local ob = getComponent("weather_obelisk");
print(ob);
printTable(ob);