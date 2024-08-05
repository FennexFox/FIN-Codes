ElevatorSystem = {}

function ElevatorSystem:New()
  local instance = {}
  local colors = {ready = {1, 1, 1, 0.1}, coming = {0, 1, 0, 0.1}, away = {1, 0, 0, 0.1}}

  self.components = {
    cabin = component.findComponent(classes.Build_Elevator_8x8_Master_C)[1],
    controller = component.findComponent(classes.ComputerCase)[1],
    doors = component.findComponent(classes.Door),
    signs = component.findComponent(classes.WidgetSign),
    iPanels = component.findComponent(classes.SizeableModulePanel)
  }

  for k1, comps in pairs(self.components) do
  	self.components[k1] = component.proxy(comps)
  end

  self.eData = {floors = {}, moduleFloors = {}, ceilingHeight = 0}

-- Initializing the Elevator system
  function self:initializeComp(maxFloor, ceilingHeight)
    maxFloor = maxFloor or 20
    ceilingHeight = ceilingHeight*100 or 400
    self.eData.ceilingHeight = ceilingHeight

    event.ignoreAll()

    for floor = 1, maxFloor do
      local floorHeight, floorName = self.components.cabin:getFloorInfo(floor-1)
      floorHeight = math.floor(floorHeight) * 100 + self.components.cabin.location.z

      if floorName == "" then
      else
        self.eData.floors[floor] = {name = floorName, height = floorHeight, components = {}}
        for _, door in pairs(self.components.doors) do
          if door.location.z > floorHeight and door.location.z < floorHeight + ceilingHeight then
            self.eData.floors[floor].components.doors = self.eData.floors[floor].components.doors or {}
            table.insert(self.eData.floors[floor].components.doors, door)
          end
        end
        for _, sign in pairs(self.components.signs) do
          if sign.location.z > floorHeight and sign.location.z < floorHeight + ceilingHeight then
            self.eData.floors[floor].components.signs = self.eData.floors[floor].components.signs or {}
            table.insert(self.eData.floors[floor].components.signs, sign)
          end
        end
        for _, iPanel in pairs(self.components.iPanels) do
          if iPanel.location.z > floorHeight and iPanel.location.z < floorHeight + self.eData.ceilingHeight then
            local module, modules = iPanel:getModules(), {}
            for a, v in pairs(module) do
              local key = v.internalName
              modules[key] = v
              
              self.eData.moduleFloors[v.internalName] = floor
              self.eData.floors[floor].components.iPanels = self.eData.floors[floor].components.iPanels or {}
              self.eData.floors[floor].components.iPanels[key] = v

              event.listen(v)
            end
          end
        end

        print(floor .. "F: " .. floorName .. " at " .. math.floor(floorHeight/100+0.5) .. "m ASL")
      end
    end
  end

-- Initializing eInterface Modules to current floor
  function self:initializeSystem()
    local cFloor= self.components.cabin:getCurrentFloor()+1

    for floor, floorData in pairs(self.eData.floors) do
      local floorName = floorData.name
    
      local prefabSign = self.components.signs[floor]:getPrefabSignData()
      local prefab1, prefab2 = prefabSign:getTextElements()
      prefab2 = {floorName, floor}
      prefabSign:setTextElements(prefab1, prefab2)
      self.components.signs[floor]:setPrefabSignData(prefabSign)
    
      for _, modules in pairs(floorData.components) do
        for name, module in pairs(modules) do
          if string.find(name, "Potentiometer") then
            module.min, module.max, module.value = 1, #self.eData.floors, cFloor
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
  end

  function self:setStanbyiPanel(iPanels, cFloor, floor)
    local inColor, awayColor, readyColor = {0, 1, 0, 0.1}, {1, 0, 0, 0.1}, {1, 1, 1, 0.1}
    for name, module in pairs(iPanels) do
      if string.find(name, "Potentiometer") then
      elseif string.find(name, "LargeMicroDIsplay") then
        module:setText(cFloor .. "F")
        module:setColor(table.unpack(colors.ready))
      elseif string.find(name, "PushButton") then
        if floor == cFloor then
          module:setColor(table.unpack(colors.ready))
        else
          module:setColor(table.unpack(colors.away))
        end
      elseif string.find(name, "ModuleScreen") then
      end
    end
  end

  function self:setMovingiPanel(iPanels, cFloor, floor, cHeightDelta, dspText)
    for name, module in pairs(iPanels) do
      if string.find(name, "Potentiometer") then
      elseif string.find(name, "LargeMicroDIsplay") then
        local movingSymbol

        if cHeightDelta > 0 then movingSymbol = " ▲ "
        else movingSymbol = " ▼ "
        end

        module:setText(movingSymbol .. dspText .. "F" .. movingSymbol)
        module:setColor(table.unpack(colors.ready))
      elseif string.find(name, "PushButton") then
        if cFloor == floor then
          module:setColor(table.unpack(colors.coming))
        else
          module:setColor(table.unpack(colors.away))
        end
      elseif string.find(name, "ModuleScreen") then
      end
    end
  end

  function self:setDoors(doors, cFloor, floor, isOpen)
    for _, door in pairs(doors) do
      if floor == cFloor then
        if isOpen > computer.time() - 6 then
          if door:getConfiguration() ~= 2 then door:setConfiguration(2)
          end
        elseif
          door:getConfiguration() ~= 0 then door:setConfiguration(0)
        end
      elseif floor ~= cFloor and door:getConfiguration() ~= 1 then
        door:setConfiguration(1)
      end
    end
  end

  function self:standby(cFloor, isOpen)
  	if not isOpen then isOpen = computer.time() end

    for floor, floorData in pairs(self.eData.floors) do
      for moduleType, comps in pairs(floorData.components) do
        if moduleType == "iPanels" then
          self:setStanbyiPanel(comps, cFloor, floor)
        elseif moduleType == "doors" then
          self:setDoors(comps, cFloor, floor, isOpen)
        end
      end
    end
    return isOpen
  end

  function self:driving(cFloor, dspText, cHeightDelta)
    local dspText = dspText or ""
    local isOpen = nil

    for floor, floorData in ipairs(self.eData.floors) do
      local cHeight = self.components.cabin:getCurrentPlatformHeight()
      local fHeight = floorData.height - self.eData.floors[1].height

      if math.abs(fHeight - cHeight) < self.eData.ceilingHeight then dspText = floor end

      self:setMovingiPanel(floorData.components.iPanels, cFloor, floor, cHeightDelta, dspText)
      for _, door in pairs(floorData.components.doors) do
        if door:getConfiguration() ~= 1 then door:setConfiguration(1) end
      end
    end

    return dspText, isOpen
  end

  function self:eventListener(deltaTime)
    local event = {event.pull(deltaTime)}
    if #event < 2 then
    else
      local e, s, v, iFloor, data = (function(e, s, v, ...)
        local iFloor = self.eData.moduleFloors[s.internalName]
          return e, s, v, iFloor, {...}
        end)(table.unpack(event))

      event[e] = {sender = s, value = v, from = iFloor, otherData = data}
      return event, iFloor
    end
  end

-- Main loop
  function self:operate(deltaTime, deltaHeight)
    local cHeight, cHeightPrev, dspText, dFloor, isOpen
    local deltaTime = deltaTime or 0.1
    local deltaHeight = deltaHeight or 1

    while true do
      local event, iFloor = self:eventListener(deltaTime)
      local cFloor = self.components.cabin:getCurrentFloor()+1
      local cHeightDelta
      

      cHeightPrev = cHeight or self.components.cabin:GetCurrentPlatformHeight()
      cHeight = self.components.cabin:GetCurrentPlatformHeight()
      cHeightDelta = cHeight - cHeightPrev

      if event then
        if event.valueChanged then
          dFloor = event.valueChanged.value
        elseif event.Trigger then
          dFloor = dFloor or iFloor
          self.components.cabin:MoveToFloor(dFloor-1)
        end
      end

      if math.abs(cHeightDelta) < deltaHeight then -- when cabin is not moving
      	dFloor = dFloor or cFloor
        isOpen = self:standby(cFloor, isOpen)
      else  -- when cabin is moving
        dspText, isOpen = self:driving(cFloor, dspText, cHeightDelta)
      end
    end
  end

  setmetatable(instance, {__index = self})
  return instance
end

Elev = ElevatorSystem:New()
Elev:initializeComp(20, 4)
Elev:initializeSystem()
Elev:operate()