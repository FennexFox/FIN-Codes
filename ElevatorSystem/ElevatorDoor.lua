local eCabin = component.findComponent("Elevator Shaft")[1] -- ToDo: multiple shafts, maybe?
local eController = component.findComponent("Controller")[1]
local eSigns, eDoors, eInterface = {}, {}, {}
local eData = {floors = {}, moduleFloors = {}}

eCabin, eController = component.proxy(eCabin), component.proxy(eController)

-- Initializing the Elevator system.
-- ToDo: auto-find components based on floorHeight in case of no matching Nicks

for i = 1, 20 do
  local floorHeight, floorName = eCabin:getFloorInfo(i-1)

  if floorName == "" then
  else
    local door = component.findComponent("Door " .. tostring(i))[1]
    local sign = component.findComponent("Sign  " .. tostring(i))[1]
    local interface = component.findComponent("Interface " .. tostring(i))[1]

    eDoors[i] = component.proxy(door)
	  eSigns[i] = component.proxy(sign)
	  eInterface[i] = component.proxy(interface)
	  eData.floors[i] = {name = floorName, height = floorHeight, iModules = {}}

	  local interface = component.proxy(interface):getModules()

	  eInterface[i] = {
      Btn = {module = interface[1], name = interface[1].internalName},
      Ptm = {module = interface[2], name = interface[2].internalName},
      Dsp = {module = interface[3], name = interface[3].internalName},
      Scr = {module = interface[4], name = interface[4].internalname}
      }

    for k, v in pairs(eInterface[i]) do
      eData.floors[i].iModules[k] = v.module
      eData.moduleFloors[v.name] = i

      event.listen(v.module)
    end

    print(i .. "F: " .. floorName .. " at " .. floorHeight .. "m")
  end
end

-- Initializing eInterface Modules to current floor

local cFloor= eCabin:getCurrentFloor()+1

for floor, floorData in pairs(eData.floors) do
  local floorName = floorData.name

  local prefabSign = eSigns[floor]:getPrefabSignData()
  local prefab1, prefab2 = prefabSign:getTextElements()
  prefab2 = {floorName, floor}
  prefabSign:setTextElements(prefab1, prefab2)
  eSigns[floor]:setPrefabSignData(prefabSign)

  local interface = eInterface[floor]
  interface.Dsp.module:setText(cFloor)
  interface.Dsp.module:setColor(1, 1, 1, 0.1)
  interface.Btn.module:setColor(1, 1, 1, 0.1)
  interface.Ptm.module.min = 1
  interface.Ptm.module.max = #eData.floors
  interface.Ptm.module.value = cFloor
end

-- Main loop
local cHeight, cHeightPrev, cHeightDelta, dFloor, isOpen
local iFloor

while true do
  local event = {event.pull(0.1)}
  local e, s, v, data
  local cFloor = eCabin:getCurrentFloor()+1
  
  cHeightPrev = cHeight or 1
  cHeight = eCabin:GetCurrentPlatformHeight()
  cHeightDelta = math.floor(math.abs(cHeight - cHeightPrev + 0.5))

  for floor=1, #eData.floors do  
    if cHeightDelta < 1 then -- when cabin is not moving
      if floor == cFloor then
        eInterface[floor].Dsp.module:setColor(1, 1, 1, 0.1)
        eInterface[floor].Btn.module:setColor(1, 1, 1, 0.1)
        if eDoors[floor]:getConfiguration() ~= 0 then
	        if floor == iFloor and isOpen then
		        eDoors[floor]:setConfiguration(2)
		        print(iFloor)
		        isOpen = false
		    else
   		        eDoors[floor]:setConfiguration(0)
	        end
        end
      else
		eInterface[floor].Btn.module:setColor(1, 0, 0, 0.1)
      if eDoors[floor]:getConfiguration() ~= 1 then
        eDoors[floor]:setConfiguration(1)
      end
      end
    else -- when cabin is moving
      eInterface[floor].Dsp.module:setText(cFloor)
      if eDoors[floor]:getConfiguration() ~= 1 then
	      eDoors[floor]:setConfiguration(1)
	  end
      if cFloor == floor then
        eInterface[floor].Btn.module:setColor(0, 1, 0, 0.1)
      else
        eInterface[floor].Btn.module:setColor(1, 0, 0, 0.1)
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
  	eCabin:MoveToFloor(dFloor - 1)
  	isOpen = true
  elseif e == "valueChanged" then dFloor = v
  end
end