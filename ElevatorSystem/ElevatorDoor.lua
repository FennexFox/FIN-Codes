local eCabin = component.findComponent("Elevator Shaft")[1] -- ToDo: multiple shafts, maybe?
local eSigns, eDoors, eInterface = {}, {}, {}
local eData = {floors = {}, modules = {}}

eCabin = component.proxy(eCabin)

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
      Scr = {module = interface[1], name = interface[1].internalName},
      Dsp = {module = interface[2], name = interface[2].internalName},
      Bzz = {module = interface[3], name = interface[3].internalName},
      Btn = {module = interface[4], name = interface[4].internalname}
      }

    for k, v in pairs(eInterface[i]) do
      eData.floors[i].iModules[k] = v.module
      eData.modules[v.name] = i

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

  if floor==cFloor then
  	eDoors[floor]:setConfiguration(0)
	interface.Btn.module:setColor(1, 1, 1, 0.1)
  else
  	eDoors[floor]:setConfiguration(1)
	interface.Btn.module:setColor(1, 0.1, 0.1, 0)
  end
end

-- Main loop

while true do
  local data = {event.pull(0.1)}
  local e, s, v, floor
  if #data < 2 then
  else
      e, s, v, floor, data = (function(e, s, v, ...)
      local f = eData.modules[s.internalName]
      return e, s, v, f, {...}
    end)(table.unpack(data))
  end

  if cFloor == eCabin:getCurrentFloor()+1 then
  else
    cFloor = eCabin:getCurrentFloor()+1
    
	for f=1, #eData.floors do
	eInterface[f].Dsp.module:setText(cFloor)
	    if f == cFloor then 
		  	eDoors[f]:setConfiguration(0)
			eInterface[f].Btn.module:setColor(1, 1, 1, 0.1)
		  else
		  	eDoors[f]:setConfiguration(1)
			eInterface[f].Btn.module:setColor(1, 0.1, 0.1, 0)
		end
  	end
  end

  if e == "Trigger" then -- calling elevator cabin
  end
end