---@diagnostic disable: empty-block
local cabin = component.findComponent(classes.Build_Elevator_8x8_Master_C)[1]
local controller = component.findComponent(classes.ComputerCase)[1]
local doors = component.findComponent(classes.Door)
local signs = component.findComponent(classes.WidgetSign)
local iPanels = component.findComponent(classes.SizeableModulePanel)

local eData = {floors = {}, moduleFloors = {}}

cabin, controller = component.proxy(cabin, controller)
doors, signs, iPanels = component.proxy(doors, signs, iPanels)

-- Initializing the Elevator system.
-- ToDo: auto-find components based on floorHeight in case of no matching Nicks

for floor = 1, 20 do
  local floorHeight, floorName = cabin:getFloorInfo(floor-1)
  floorHeight = math.floor(floorHeight) * 100 + cabin.location.z

  if floorName == "" then
  else
    eData.floors[floor] = {name = floorName, height = floorHeight, doors = {}, signs = {}, iPanels = {}}
    for _, door in pairs(doors) do
      if door.location.z > floorHeight and door.location.z < floorHeight + 400 then
        table.insert(eData.floors[floor].doors, door)
      end
    end
    for _, sign in pairs(signs) do
      if sign.location.z > floorHeight and sign.location.z < floorHeight + 400 then
        table.insert(eData.floors[floor].signs, sign)
      end
    end
    for _, iPanel in pairs(iPanels) do
      if iPanel.location.z > floorHeight and iPanel.location.z < floorHeight + 400 then
        local temp1, temp2 = iPanel:getModules(), {}
        for _, v in pairs(temp1) do
          temp2[v.internalName] = v
          eData.moduleFloors[v.internalName] = floor
          event.listen(v)
        end

        table.insert(eData.floors[floor].iPanels, temp2)
      end
    end

    print(floor .. "F: " .. floorName .. " at " .. math.floor(floorHeight/100+0.5) .. "m ASL")
  end
end

-- Initializing eInterface Modules to current floor

local cFloor= cabin:getCurrentFloor()+1

for floor, floorData in pairs(eData.floors) do
  local floorName = floorData.name

  local prefabSign = signs[floor]:getPrefabSignData()
  local prefab1, prefab2 = prefabSign:getTextElements()
  prefab2 = {floorName, floor}
  prefabSign:setTextElements(prefab1, prefab2)
  signs[floor]:setPrefabSignData(prefabSign)

  for _, modules in pairs(floorData.iPanels) do
    for name, module in pairs(modules) do
      if string.find(name, "Potentiometer") then
        module.min, module.max, module.value = 1, #eData.floors, cFloor
      elseif string.find(name, "LargeMicroDIsplay") then
        module:setText(cFloor .. "F")
        module:setColor(1, 1, 1, 0.1)
      elseif string.find(name, "PushButton") then
        module:setColor(1, 1, 1, 0.1)
      elseif string.find(name, "ModuleScreen") then
      end
    end
  end
end

-- Main loop
local cHeight, cHeightPrev, cFloorTemp
local dFloor, iFloor, isOpen

while true do
  local event = {event.pull(0.1)}
  local e, s, v, data
  local cFloor = cabin:getCurrentFloor()+1
  local cHeightDelta

  cHeightPrev = cHeight or 1
  cHeight = cabin:GetCurrentPlatformHeight()
  cHeightDelta = cHeight - cHeightPrev

  if math.abs(cHeightDelta) < 10 then -- when cabin is not moving
    for floor, floorData in pairs(eData.floors) do
      for _, modules in pairs(floorData.iPanels) do
        for name, module in pairs(modules) do
          if string.find(name, "Potentiometer") then
          elseif string.find(name, "LargeMicroDIsplay") then
            module:setText(cFloor .. "F")
            module:setColor(1, 1, 1, 0.1)
          elseif string.find(name, "PushButton") then
            if floor == cFloor then module:setColor(1, 1, 1, 0.1)
            else module:setColor(1, 0, 0, 0.1)
            end
          elseif string.find(name, "ModuleScreen") then
          end
        end
        if floor == cFloor and doors[floor] and doors[floor]:getConfiguration() ~= 0 then
          if floor == iFloor and isOpen then
            doors[floor]:setConfiguration(2)
            isOpen = false
          else
            doors[floor]:setConfiguration(0)
          end
        elseif floor ~= cFloor and doors[floor] and doors[floor]:getConfiguration() ~= 1 then
          doors[floor]:setConfiguration(1)
        end
      end
    end
  else  -- when cabin is moving
  
    	local cHeightTemp = cHeight
      for f, fD in ipairs(eData.floors) do
        local fHeightTemp = (fD.height - cabin.location.z)

        if math.abs(cHeightTemp - fHeightTemp) < 400 then
          cFloorTemp = f
else
        end
      end
    for floor, floorData in pairs(eData.floors) do
    
      for _, modules in pairs(floorData.iPanels) do
      
        for name, module in pairs(modules) do
          if string.find(name, "Potentiometer") then
          elseif string.find(name, "LargeMicroDIsplay") then
            local movingSymbol, dspText = "", tostring(cFloorTemp)

            if cHeightDelta > 5 then movingSymbol = " ▲ "
            else movingSymbol = " ▼ "
            end

            dspText = movingSymbol .. dspText .. "F" .. movingSymbol

            module:setText(dspText)
            module:setColor(1, 1, 1, 0.1)
          elseif string.find(name, "PushButton") then
            if cFloor == floor then
              module:setColor(0, 1, 0, 0.1)
            else
              module:setColor(1, 0, 0, 0.1)
            end
          elseif string.find(name, "ModuleScreen") then
          end
        end
      end
      if doors[floor]:getConfiguration() ~= 1 and doors[floor] then
        doors[floor]:setConfiguration(1)
      end
    end
  end


  if #event < 2 then
  else
    e, s, v, iFloor, data = (function(e, s, v, ...)
    local temp = eData.moduleFloors[s.internalName]
      return e, s, v, temp, {...}
    end)(table.unpack(event))
  end

  if e == "Trigger" then
  	dFloor = dFloor or iFloor
  	cabin:MoveToFloor(dFloor - 1)
  	isOpen = true
  elseif e == "valueChanged" then dFloor = v
  end
end