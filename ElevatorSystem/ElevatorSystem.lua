ElevatorSystem = {}

function ElevatorSystem:New(elevName)
  local instance = {name = elevName}
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

---Initializing the Elevator doors, Signs, IO Panels <br>
---maxFloor starts from 1, not 0 <br>
---cielingHeight defines how high each elevator stop floor is
---@param maxFloor integer
---@param ceilingHeight number
function self:initializeComp(ceilingHeight, maxFloor)
    ceilingHeight = ceilingHeight*100 or 400
    self.eData.ceilingHeight = ceilingHeight
    maxFloor = maxFloor or 20

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
          else
          	print("No Doors at Floor ", floor)
          end
        end
        for _, sign in pairs(self.components.signs) do
          if sign.location.z > floorHeight and sign.location.z < floorHeight + ceilingHeight then
            self.eData.floors[floor].components.signs = self.eData.floors[floor].components.signs or {}
            table.insert(self.eData.floors[floor].components.signs, sign)
          else print("No Signage at Floor ", floor)
          end
        end
        for _, iPanel in pairs(self.components.iPanels) do
          if iPanel.location.z > floorHeight and iPanel.location.z < floorHeight + self.eData.ceilingHeight then
            local module, modules = iPanel:getModules(), {}
            for _, v in pairs(module) do
              local key = v.internalName
              modules[key] = v

              self.eData.moduleFloors[key] = floor
              self.eData.floors[floor].components.iPanels = self.eData.floors[floor].components.iPanels or {}
              self.eData.floors[floor].components.iPanels[key] = v
              
              event.listen(v)
            end
          else print("No Interface Panel at Floor ", floor)
          end
        end

        print(floor .. "F: " .. floorName .. " at " .. math.floor(floorHeight/100+0.5) .. "m ASL")
      end
    end
  end

---Initializing eInterface System with modules
  function self:initializeSystem()
    local cFloor= self.components.cabin:getCurrentFloor()+1

    for floor, floorData in pairs(self.eData.floors) do
      local floorName = floorData.name
      local screens = {}

	  if not (#self.components.signs < floor) then
	  	local prefabSign = self.components.signs[floor]:getPrefabSignData()

	    prefabSign:setTextElements(prefabSign:getTextElements(), {self.name, floor.."F"})
	    self.components.signs[floor]:setPrefabSignData(prefabSign)
      end

      for _, modules in pairs(floorData.components) do
        for name, module in pairs(modules) do
          if string.find(name, "Pot") then
            module.min, module.max, module.value = 1, #self.eData.floors, floor
            module:setColor(1, 1, 1, 0.1)
          elseif string.find(name, "LargeMicroDIsplay") then
            module:setText(cFloor .. "F")
            module:setColor(1, 1, 1, 0.1)
          elseif string.find(name, "PushButton") then
            module:setColor(1, 1, 1, 0.1)
          elseif string.find(name, "TextDisplay") then
          	module.size = 55
          	module.monospace = false
--          	module.text = "12345678901234"
			module.text = "Pioneer\'s" .. string.char(10) .. "Quarter   / 4F "
          end
        end
      end
    end
  end

---Set IO Panels when the cabin is not moving
---@param iPanels table
---@param cFloor integer
---@param floor integer
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

---Set IO Panels when the cabin is moving
---@param iPanels table
---@param cFloor integer
---@param floor integer
---@param cHeightDelta number
---@param dspText string
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

---Lock or open elevator doors
---@param doors table
---@param cFloor integer
---@param floor integer
---@param isOpen boolean
  function self:setDoors(doors, cFloor, floor, isOpen)
    for _, door in pairs(doors) do
      if floor == cFloor then
        if isOpen > computer.magicTime() - 6 then
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

  ---Call this function after binding the target screen
  function self:drawScreen(targetScreen, text)
    local GPU = self.graphics.GPU
    GPU:bindScreen(targetScreen)

    local sizeX, sizeY = GPU:getSize()
    print(GPU:getScreen().internalName)
    
    GPU:setForeground(1, 1, 1, 0.1)
    GPU:setBackground(0, 0, 0, 0)
    GPU:fill(0, 0, sizeX, sizeY, text)
    GPU:flush()
  end

  ---Main loop when the cabin is not moving
  ---@param cFloor integer
  ---@param isOpen boolean
  ---@return boolean
  function self:standby(cFloor, isOpen)
  	if not isOpen then isOpen = computer.magicTime() end

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

---Main loop when the cabin is moving
---@param cFloor integer
---@param dspText string
---@param cHeightDelta number
---@return string
---@return boolean
  function self:driving(cFloor, dspText, cHeightDelta)
    local dspText = dspText or ""
    local isOpen = false

    for floor, floorData in ipairs(self.eData.floors) do
      local cHeight = self.components.cabin:getCurrentPlatformHeight()
      local fHeight = floorData.height - self.eData.floors[1].height

      if math.abs(fHeight - cHeight) < self.eData.ceilingHeight then dspText = tostring(floor) end

	  if not floorData.components.iPanels then print("No interface panel at Floor", floor)
	  else
	    self:setMovingiPanel(floorData.components.iPanels, cFloor, floor, cHeightDelta, dspText)
	  end
	  
	  if not floorData.components.doors then print("No doors at Floor", floor)
	  else
	    for _, door in pairs(floorData.components.doors) do
	      if door:getConfiguration() ~= 1 then door:setConfiguration(1) end
	    end
	  end
    end

    return dspText, isOpen
  end

---Event listener that parses event message and returns data
---@param deltaTime number
---@return table
---@return integer
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

---Main loop to control the elevator system
---@param deltaTime number
---@param deltaHeight number
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

Elev = ElevatorSystem:New("HUB Elevator")

Elev:initializeComp(5)
Elev:initializeSystem()
Elev:operate()