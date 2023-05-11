Input, Outputs = {}, {}
ProcessSystem = {}

function Input:New(Nick)
  local inputSytem = {}
  
end

function Outputs:New(Nick)
  
end

function ProcessSystem:Probing()

end

--[[
TestConst = component.proxy(component.findComponent("TestConst"))
TestComp = component.proxy(component.findComponent("TestComp"))[1]

print(TestComp:getType()["Name"])

for k, v in pairs(TestConst) do
  print(k .. ": " .. v:getType()["Name"] .. " / " .. v:getRecipe():getProducts()[1].Type.Name .. " * " .. v:getRecipe():getProducts()[1].Amount .. " / " ..  v:getRecipe():getIngredients()[1].Type.Name .. " * " .. v:getRecipe():getProducts()[1].Amount .. " @ " .. v:getRecipe().Duration .. "s")
end

TestClass = TestConst[1].getType()

Test = component.proxy(component.findComponent(findClass(TestClass["Name"]))

print(Test)

for k, v in pairs(Test) do
  print(k .. ": " .. v:getRecipe().Duration .. "s")
end

↓
Computer_C
1: Build_ManufacturerMk1_C / High-Speed Connector * 1 / Quickwire * 1 @ 16.0s
2: Build_ConstructorMk1_C / Iron Plate * 2 / Iron Ingot * 2 @ 6.0s
table: 0000024A265D5C80
1: 16.0s
2: 12.0s
--]]