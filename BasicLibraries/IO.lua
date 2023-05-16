InterfaceComps = {}

function InterfaceComps:New(Identifier, Name)
  local instance = {}

  instance.Panel = component.proxy(component.findComponent(Identifier)[1])
  instance.PanelName = Name
  instance.isOn = {Master = false}
  instance.Comps = {}

  function InterfaceComps:Set(Coordinate, CompName)
    local ioComp = self.Panel:getModule(Coordinate[1], Coordinate[2], Coordinate[3])
    local compPath, i = self.Comps, 1
    local v = CompName[i]
    local n = v

    while i < #CompName do

      if not(compPath[v]) then
        compPath[v] = {}
      end
      compPath = compPath[v]
      i = i + 1
      v = CompName[i]
      n = n .. "." .. v
    end

    compPath[v] = ioComp

    print(compPath[v].internalName .. " has registered to Interface Components of " .. self.PanelName .. " as " .. n)
  end

  
  function InterfaceComps:Get()
    local ioComps = {}
  
    for k, v in pairs(self.Comps) do
      ioComps[k] = v
    end
  
    return ioComps
  end
  
  function InterfaceComps:On()
    for k in pairs(self.isOn) do
      self.isOn[k] = true
    end

    print (self.PanelName .. " Turned On")
  end
  
  function InterfaceComps:Off()
    for k in pairs(self.isOn) do
      self.isOn[k] = false
    end

    print (self.PanelName .. " Turned Off")
  end
  
  function InterfaceComps:Run()
    print("Error: Interface Control Not Set")
  end

  setmetatable(instance, {__index = self})

  return instance
end