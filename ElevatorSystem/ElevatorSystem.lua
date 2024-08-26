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
            local modules = iPanel:getModules()
            for _, v in pairs(modules) do
              local key = v.internalName

              self.eData.moduleFloors[key] = floor
              self.eData.floors[floor].components.iPanels = self.eData.floors[floor].components.iPanels or {}
              self.eData.floors[floor].components.iPanels[key] = v
              
              if string.find(key, "TextDisplay") then
                v.size = 55
                v.monospace = false
              end

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

	  if not (#self.components.signs < floor) then
	  	local prefabSign = self.components.signs[floor]:getPrefabSignData()

	    prefabSign:setTextElements(prefabSign:getTextElements(), {self.name, floor.."F"})
	    self.components.signs[floor]:setPrefabSignData(prefabSign)
      end

      for _, modules in pairs(floorData.components) do
        for name, module in pairs(modules) do
          if string.find(name, "DisplaySquare") then
            module:setText(cFloor .. "F")
            module:setColor(table.unpack(colors.ready))
          elseif string.find(name, "LargeMicro") then
            module:setText(cFloor .. "M")
            module:setColor(table.unpack(colors.ready))
          elseif string.find(name, "PushButton") then
            module:setColor(table.unpack(colors.ready))
          elseif string.find(name, "TextDisplay") then
	          module.text = string.gsub(floorName, "%s", string.char(10))
          end
        end
      end
    end
  end

---Set IO Panels when the cabin is not moving
---@param iPanels table
---@param cFloor integer
---@param floor integer
  function self:setStandbyiPanel(iPanels, cFloor, floor)
    local floorData = self.eData.floors

    for name, module in pairs(iPanels) do
      if string.find(name, "DisplaySquare") then
        module:setText(cFloor .. "F")
        module:setColor(table.unpack(colors.ready))
      elseif string.find(name, "LargeMicro") then
        local fHeight = floorData[cFloor].height - self.eData.floors[1].height
        fHeight = string.format("%02d", math.floor(fHeight/100 + 0.5))

        module:setText(fHeight .. "M" .. "   ")
        module:setColor(table.unpack(colors.ready))
      elseif string.find(name, "PushButton") then
        if floor == cFloor then
          module:setColor(table.unpack(colors.ready))
        else
          module:setColor(table.unpack(colors.away))
        end
      elseif string.find(name, "TextDisplay") then
        local _, _, temp1, temp2 = string.find(self.eData.floors[cFloor].name, "(%a+)%s?(%a*)")
        local temp = " " .. temp1

        module.text = (temp .. string.char(10) .. " " .. temp2) or temp
      end
    end
  end

---Set IO Panels when the cabin is moving
---@param iPanels table
---@param cFloor integer
---@param iFloor integer
---@param cHeight number
---@param cHeightDelta number
---@param dspText string
  function self:setMovingiPanel(iPanels, cFloor, iFloor, cHeight, cHeightDelta, dspText)
    local cHeight = math.floor(cHeight/100 + 0.5)
    local color

    if (cHeight - self.components.cabin:GetCurrentPlatformHeight()) * cHeightDelta > 0 then
      color = colors.coming
    else
      color = colors.away
    end
    for name, module in pairs(iPanels) do
      if string.find(name, "DisplaySquare") then
        module:setText(dspText .. "F")
        module:setColor(table.unpack(colors.ready))
      elseif string.find(name, "LargeMicro") then
        local movingSymbol

        if cHeightDelta > 0 then movingSymbol = " ▲ "
        else movingSymbol = " ▼ "
        end

        module:setText(string.format("%02d", cHeight) .. "M" .. movingSymbol)
        module:setColor(table.unpack(colors.ready))
      elseif string.find(name, "PushButton") then
        if cFloor == iFloor then
          module:setColor(table.unpack(color))
        else
          module:setColor(table.unpack(color))
        end
      elseif string.find(name, "TextDisplay") then
        local _, _, temp1, temp2 = string.find(self.eData.floors[tonumber(dspText)].name, "(%a+)%s?(%a*)")
        local temp = " " .. temp1

        module.text = (temp .. string.char(10) .. " " .. temp2) or temp
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

  ---Main loop when the cabin is not moving
  ---@param cFloor integer
  ---@param isOpen boolean
  ---@return boolean
  function self:standby(cFloor, isOpen)
  	if not isOpen then isOpen = computer.magicTime() end

    for floor, floorData in pairs(self.eData.floors) do
      for moduleType, comps in pairs(floorData.components) do
        if moduleType == "iPanels" then
          self:setStandbyiPanel(comps, cFloor, floor)
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
  function self:driving(cFloor, iFloor, dspText, cHeightDelta)
    local isOpen = false

    for floor, floorData in ipairs(self.eData.floors) do
      local cHeight = self.components.cabin:GetCurrentPlatformHeight()
      local fHeight = floorData.height - self.eData.floors[1].height

      if math.abs(fHeight - cHeight) < self.eData.ceilingHeight then dspText = tostring(floor) end

      if not floorData.components.iPanels then print("No interface panel at Floor", floor)
      else
        local dspText = dspText or cFloor
        self:setMovingiPanel(floorData.components.iPanels, cFloor, iFloor, cHeight, cHeightDelta, dspText)
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
---@return integer|nil
  function self:eventListener(deltaTime)
    local event, iFloor = {event.pull(deltaTime)}, nil
    if #event < 2 then
    else
      local e, s, v, data = (function(e, s, v, ...)
          return e, s, v, iFloor, {...}
        end)(table.unpack(event))

        iFloor = self.eData.moduleFloors[s.internalName]
      event[e] = {sender = s, value = v, from = iFloor, otherData = data}
    end

    return event, iFloor
  end

---Main loop to control the elevator system
---@param deltaTime number
---@param deltaHeight number
  function self:operate(deltaTime, deltaHeight)
    local cHeight, cHeightPrev, dspText, isOpen
    local deltaTime = deltaTime or 0.05
    local deltaHeight = deltaHeight or 0.01

    while true do
      local event, iFloor = self:eventListener(deltaTime)
      local cFloor = self.components.cabin:getCurrentFloor() + 1
      local cHeightDelta

      cHeightPrev = cHeight or self.components.cabin:GetCurrentPlatformHeight()
      cHeight = self.components.cabin:GetCurrentPlatformHeight()
      cHeightDelta = cHeight - cHeightPrev

      iFloor = iFloor or cFloor

      if event then
        if event.Trigger then
          self.components.cabin:MoveToFloor(iFloor-1)
        end
      end

      if math.abs(cHeightDelta) < deltaHeight then -- when cabin is not moving
        isOpen = self:standby(iFloor, isOpen)
      else  -- when cabin is moving
        dspText = dspText or tostring(cFloor)
        dspText, isOpen = self:driving(cFloor, iFloor, dspText, cHeightDelta)
        print(iFloor, cFloor)
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