function f (x) print(x) return x end
print(f(nil) or not f(6))

--[[local lol = require("lol")
print("from test.lua: " .. lol)

local bottles = 5
 
local function plural (bottles) if bottles == 1 then return '' end return 's' end
while bottles > 0 do
    print (bottles..' bottle'..plural(bottles)..' of beer on the wall')
    print (bottles..' bottle'..plural(bottles)..' of beer')
    print ('Take one down, pass it around')
    bottles = bottles - 1
    print (bottles..' bottle'..plural(bottles)..' of beer on the wall')
    print ()
end]]
