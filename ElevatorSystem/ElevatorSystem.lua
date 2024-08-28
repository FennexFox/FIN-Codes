ElevatorSystem = {}
local tempLibraries = {}

---comment
---@param elevName string
---@param config table
---@return table
function ElevatorSystem:New(elevName, config)
  local instance = {name = elevName}
  local colors = {ready = {1, 1, 1, 0.1}, coming = {0, 1, 0, 0.1}, away = {1, 0, 0, 0.1}}

  self.components = {
    cabin = component.findComponent(classes.Build_Elevator_8x8_Master_C)[1],
    controller = component.findComponent(classes.ComputerCase)[1],
    doors = component.findComponent(classes.Door),
    signs = component.findComponent(classes.WidgetSign),
    iPanels = component.findComponent(classes.SizeableModulePanel)
  }

  for key, comps in pairs(self.components) do
  	self.components[key] = component.proxy(comps)
  end

  self.eData = {
    floors = {},
    moduleFloors = {},
    tiemStamp = 0,
    deltaTime = config.deltaTime,
    deltaHeight = config.deltaHeight,
    ceilingHeight = config.ceilingHeight
  }

---Initializing the Elevator doors, Signs, IO Panels <br>
---maxFloor starts from 1, not 0 <br>
---cielingHeight defines how high each elevator stop floor is
---@param maxFloor integer | nil
function self:initializeComp(maxFloor)
  local ceilingHeight = self.eData.ceilingHeight*100
  local maxFloor = maxFloor or 20

  event.ignoreAll()
  event.clear()

  for floor = 1, maxFloor do
    local floorHeight, floorName = self.components.cabin:getFloorInfo(floor-1)

    if floorName == "" then
    else
      self.eData.floors[floor] = {name = floorName, height = floorHeight, components = {}}
      floorHeight = math.floor(floorHeight) * 100 + self.components.cabin.location.z
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
        if iPanel.location.z > floorHeight and iPanel.location.z < floorHeight + ceilingHeight then
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
    local sFloor= self.components.cabin:getCurrentFloor()+1

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
            module:setText(sFloor .. "F")
            module:setColor(table.unpack(colors.ready))
          elseif string.find(name, "LargeMicro") then
            module:setText(sFloor .. "M")
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
---@param sFloor integer
---@param floor integer
  function self:setStandbyiPanel(iPanels, sFloor, floor)
    local floorData = self.eData.floors

    for name, module in pairs(iPanels) do
      if string.find(name, "DisplaySquare") then
        module:setText(sFloor .. "F")
        module:setColor(table.unpack(colors.ready))
      elseif string.find(name, "LargeMicro") then
        local fHeight = floorData[sFloor].height - self.eData.floors[1].height
        fHeight = string.format("%02d", math.floor(fHeight + 0.5))

        module:setText(fHeight .. "M")
        module:setColor(table.unpack(colors.ready))
      elseif string.find(name, "PushButton") then
        if floor == sFloor then
          module:setColor(table.unpack(colors.ready))
        else
          module:setColor(table.unpack(colors.away))
        end
      elseif string.find(name, "TextDisplay") then
        local _, _, temp1, temp2 = string.find(self.eData.floors[sFloor].name, "(%a+)%s?(%a*)")
        local temp = " " .. temp1

        module.text = (temp .. string.char(10) .. " " .. temp2) or temp
      end
    end
  end

---Set IO Panels when the cabin is moving
---@param iPanels table
---@param sFloor integer
---@param cHeight number
---@param cHeightDelta number
---@param iFloor integer
---@param nFloor integer
  function self:setMovingiPanel(iPanels, sFloor, iFloor, nFloor, cHeight, cHeightDelta)
    local color
    local iHeight = self.eData.floors[iFloor].height

    if (iHeight - cHeight) * cHeightDelta > 0 then color = colors.coming
    else color = colors.away
    end

    for name, module in pairs(iPanels) do
      if string.find(name, "DisplaySquare") then
        module:setText(tostring(nFloor) .. "F")
        module:setColor(table.unpack(colors.ready))
      elseif string.find(name, "LargeMicro") then
        local movingSymbol

        if cHeightDelta > 0 then movingSymbol = "▲"
        else movingSymbol = "▼"
        end

        module:setText(string.format(movingSymbol .. "%02.0f", cHeight) .. "M" .. movingSymbol)
        module:setColor(table.unpack(colors.ready))
      elseif string.find(name, "PushButton") then
        if sFloor == iFloor then
          module:setColor(table.unpack(color))
        else
          module:setColor(table.unpack(color))
        end
      elseif string.find(name, "TextDisplay") then
        local _, _, temp1, temp2 = string.find(self.eData.floors[nFloor].name, "(%a+)%s?(%a*)")
        local temp = " " .. temp1

        module.text = (temp .. string.char(10) .. " " .. temp2) or temp
      end
    end
  end

---Lock or open elevator doors
---@param doors table
---@param cFloor integer
---@param iFloor integer
---@param timeStamp number
  function self:setDoors(doors, cFloor, iFloor, timeStamp)
    for _, door in pairs(doors) do
      if iFloor == cFloor then
        if timeStamp > computer.magicTime() - 6 then
          if door:getConfiguration() ~= 2 then door:setConfiguration(2)
          end
        elseif
          door:getConfiguration() ~= 0 then door:setConfiguration(0)
        end
      elseif iFloor ~= cFloor and door:getConfiguration() ~= 1 then
        door:setConfiguration(1)
      end
    end
  end

  ---Main loop when the cabin is not moving
  ---@param sFloor integer
  ---@param timeStamp number
  ---@return number
  function self:standby(sFloor, timeStamp)
  	local timeStamp = timeStamp or computer.magicTime()

    for iFloor, floorData in pairs(self.eData.floors) do
      for moduleType, comps in pairs(floorData.components) do
        if moduleType == "iPanels" then
          self:setStandbyiPanel(comps, sFloor, iFloor)
        elseif moduleType == "doors" then
          self:setDoors(comps, sFloor, iFloor, timeStamp)
        end
      end
    end
    return timeStamp
  end

---Main loop when the cabin is moving
---@param sFloor integer
---@param cHeightDelta number
  function self:driving(sFloor, cHeightDelta)
    local cHeight = self.components.cabin:GetCurrentPlatformHeight()
    local nFloor

    cHeight = math.floor(cHeight/100 + 0.5)
    for i = 1, #self.eData.floors - 1 do
      local nBar = self.eData.floors[i+1].height / 2
      local nHeight = cHeight - self.eData.floors[i].height
      nHeight = nHeight - nBar

      if nHeight < 0 then nFloor = i break end
    end	

    for iFloor, floorData in ipairs(self.eData.floors) do
      if not floorData.components.iPanels then print("No interface panel at Floor", iFloor)
      else
        self:setMovingiPanel(floorData.components.iPanels, sFloor, iFloor, nFloor, cHeight, cHeightDelta)
      end
      
      if not floorData.components.doors then print("No doors at Floor", iFloor)
      else
        for _, door in pairs(floorData.components.doors) do
          if door:getConfiguration() ~= 1 then door:setConfiguration(1) end
        end
      end
    end
  end

 	---Event listener that parses event message and returns data
	---@param filterString string | nil
  ---@param deltaTime number | nil
	---@return table
	function tempLibraries.eventListener(deltaTime, filterString)
		local deltaTime = self.eData.deltaTime or deltaTime

		local event = {event.pull(deltaTime, filterString)}
		local e, s, v, t, data = (function(e, s, v, ...)
			return e, s, v, computer.magicTime(), {...}
		end)(table.unpack(event))

		if e then
			event = {type = e, sender = s, value = v, time = t, otherData = data}
		else
			event = {type = "timeOut", sender = "Ficsit_OS", value = "magicTime", time = t}
		end

		return event
	end

---Main loop to control the elevator system
---@param deltaTime number | nil
---@param deltaHeight number | nil
function self:operate(deltaTime, deltaHeight)
  local cHeight, cHeightPrev, tiemStamp
  local deltaTime = self.eData.deltaTime or deltaTime
  local deltaHeight = deltaHeight or 0.1

  while true do
    local event = tempLibraries.eventListener(deltaTime)
    local sFloor = self.components.cabin:getCurrentFloor() + 1
    local dFloor = self.eData.moduleFloors[event.sender.internalName]
    local cHeightDelta

    cHeightPrev = cHeight or self.components.cabin:GetCurrentPlatformHeight()
    cHeight = self.components.cabin:GetCurrentPlatformHeight()
    cHeightDelta = cHeight - cHeightPrev

    dFloor = dFloor or sFloor -- this enables manual control of the elevator

    if event then
      if event.type == "Trigger" then
        self.eData.tiemStamp = event.time
        self.components.cabin:MoveToFloor(dFloor-1)
      end
    end

    if (math.abs(cHeightDelta) < deltaHeight) then -- when cabin is not moving
      if computer.magicTime() - self.eData.tiemStamp > self.eData.deltaTime then -- to prevent premature update
        tiemStamp = self:standby(dFloor, tiemStamp)
      end
    else  -- when cabin is moving
      tiemStamp = self:driving(sFloor, cHeightDelta)
    end
  end
end

  setmetatable(instance, {__index = self})
  instance:initializeComp()
  instance:initializeSystem()

  return instance
end

Elev = ElevatorSystem:New("HUB Elevator", {deltaTime = 0.1, deltaHeight = 0.1, ceilingHeight = 5})
Elev:operate()