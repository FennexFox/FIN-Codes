Station = {}
GasStation = {}
LogiStation ={}

function Station:New(identifier)
  local station = {}

  station.Proxy = component.proxy(component.findComponent(identifier)[1])
  station.FuelType, station.Items = "N/A", {}
  station.Inv = station.Proxy:getInv()
  
  function Station:CheckInv()
    self.Inv:sort()
    local item, item_i, items = "item", "item", {}

    for i=0, self.Inv.size-1 do
      if self.Inv:getStack(i) ~= nil then
        item = item_i
        item_i = self.Inv:getStack(i).item.type
        self.OccupiedSlots = i

        if item_i ~= item then
          table.insert(items, self.Inv:getStack(i).item.type)
        end

      else break end
    end

    if station.Proxy:getFuelInv():getStack(0) ~= nil then
      self.FuelType = station.Proxy:getFuelInv():getStack(0).item.type 
    else
      self.FuelType = "N/A"
    end

    self.Items = items
    self.AvailableSlots = self.Inv.size - self.OccupiedSlots
  end

  function Station:Standby()
    print("Error: Standby() Not Set")
  end

  function Station:Action(storedItem)
    print("Error: Action() Not Set")
  end
  
  function Station:Sleep(bool, seconds)
    while self.Proxy.isLoadUnloading == bool do
      event.pull(seconds)
    end
  end

  function Station:GetVehicleInv()
    local dockedVehicle = self.Proxy:getDocked()
    local storageInv = dockedVehicle:getStorageInv()
    local item, item_i, storedItem = "item", "item", {}
    storageInv:sort()

    for i=0, storageInv.size-1 do
      if self.Inv:getStack(i) ~= nil then
        item = item_i
        item_i = self.Inv:getStack(i).item.type
        if item_i ~= item then
          table.insert(storedItem, self.Inv:getStack(i).item.type)
        end
      else break end
    end

    return storedItem
  end

  function Station:Run()
    while true do
      if self.Proxy.isLoadUnloading == false then
        print("Vehicle Not Docked")
        self:Sleep(false, 0.05)
      else
        print("Vehicle Docked")
        self:Sleep(true, 0.05)
      end
    end
  end

  setmetatable(station, {__index = Station})
  return station

end

function GasStation:New(identifier)
  local gasStation = Station:New(identifier)
  local base = Station:New(identifier)

  function GasStation:Standby()
    for i=1, gasStation.AvailableSize-1 do
      self.Inv:splitStackAtIndex(1, 1)
    end
  end

  function GasStation:Action(storedItem)
    self.CheckInv()

    if storedItem[1] ~= self.FuelType then
      self.Inv:splitStackAtIndex(1, 1)
    else
      self.Inv:sort()
    end

  end

  function GasStation:Run()
    while true do
      if self.Proxy.isLoadUnloading == false then
        self:Standby()
        self:Sleep(false, 0.05)
      else
        local storedItem = self:GetVehicleInv()
        self:Action(storedItem)
        self:Sleep(true, 0.05)
      end
    end
  end

  return gasStation
end

function LogiStation:New(Freight, isBuffered)
  local logiStation = Station:New("LogiStation " .. Freight)
  local base = Station:New(Freight)
  if isBuffered then
    logiStation.Buffer = component.proxy(component.findComponent(Freight, "Buffer")[1])
    logiStation.Output = component.proxy(component.findComponent(Freight, "Output"))
    logiStation.Input = component.proxy(component.findComponent(Freight, "Input"))
  end

  function LogiStation:BufferControl(TargetInvQ, Tolerance)
    local targetMin, targetMax = TargetInvQ - Tolerance, TargetInvQ + Tolerance
    
    if self.Inv.itemCount < targetMin then
      for _, v in pairs(self.Input) do
        v:transferItem(1)
      end
    elseif self.Inv.itemCount > targetMax then
      for _, v in pairs(self.Output) do
        v:transferItem(1)
      end
    end
  end

  function LogiStation:Run()
    
    if self.Buffer then
      self:BufferControl()
    end
  end

  return logiStation
end