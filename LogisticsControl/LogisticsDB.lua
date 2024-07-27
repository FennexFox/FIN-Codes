VehicleDB = {}
RouteDB = {} -- Item = RouteID = {Stats = {Load, Unload, Net, Timestamp}, Fleet = {VehicleInternalName, VehicleNumber}}

function VehicleDB:New()
  local vDB = {}

  for i = 1, 9999 do
    table.insert(vDB.VeNumSeed, i)
  end

    function VehicleDB:Register(VehicleInternalName, VehicleNumber)
      self[VehicleNumber] = "Unassigned"
      self[VehicleInternalName] = {self[VehicleNumber], VehicleNumber}

      local vNumber = VehicleNumber:sub(1,4)

      for i = 1, vNumber do
        if self.VeNumSeed[i] == vNumber then
          table.remove(self.VeNumSeed, i)
          break
        end
      end

    end
    
    function VehicleDB:Dispose(VehicleInternalName)
      local ReturnedNumber = self[VehicleInternalName][2]:sub(1,4)

      if self.VeNumSeed[1] > ReturnedNumber then
        table.insert(self.VeNumSeed, 1, ReturnedNumber)
      else
        for i = 1, ReturnedNumber do
          if self.VeNumSeed[i] > ReturnedNumber then
            table.insert(self.VeNumSeed, i-1, ReturnedNumber)
            break
          end
        end
      end

      table.remove(self[VehicleInternalName])
    end
    
    function VehicleDB:Assign(VehicleInternalName, Route)
      if self[VehicleInternalName][1] ~= nil then
        self:Discharge(VehicleInternalName)
      end
      self[VehicleInternalName][1] = RouteDB[Route]
      RouteDB:Assign(VehicleInternalName)
    end
    
    function VehicleDB:Discharge(VehicleInternalName)
      self[VehicleInternalName][1] = "Unassigned"
      RouteDB:Discharge(VehicleInternalName)
    end

    setmetatable(vDB, {__index = self})
    return vDB

end

function RouteDB:New()
  local rDB = {}
  rDB.Data = {LocationID = {}, Category = {}, Item = {}}
  rDB.Data.Category = {"Resources", "Consumables", "Components", "Products", "Others"}

  function RouteDB:NewLocation(LocationName, LocationID)
    if self.Data[LocationID] == nil then
      self.Data[LocationID] = {LocationName, RouteFrom = {}, RouteTo = {}}
    else
      print("Error: Location Duplicated")
    end
  end

  function RouteDB:NewItem(Category, Name)
    local item = Name:sub(1,1) .. string.len(Name)
    item = Category .. item

    if self.Data.Item.item == nil then
      self.Data.Item = {item = Name}
      self[Name] = {}
    else
      print("Error: Item Duplicated")
    end
  end

  function RouteDB:NewRoute(RouteID)
    if self[RouteID] == nil then
      self[RouteID] = {Stats = {}, Fleet = {}}
      local item = self.Data.Item[RouteID:sub(4,6)]
      table.insert(self[item], RouteID)
    else
      print("Error: RouteID Duplicated")
    end
  end

  function RouteDB:Assign(VehicleInternalName)
    local vNumber = VehicleDB.VehicleInternalName[2]

    if self.Route.Fleet[vNumber] ~= nil then
      self:Discharge(VehicleInternalName)
    end
    self.Route.Fleet[vNumber] = VehicleInternalName
  end

  function RouteDB:Discharge(VehicleInternalName)
    local vNumber = VehicleDB.VehicleInternalName[2]
    self.Route.Fleet[vNumber] = nil
  end

  setmetatable(rDB, {__index = self})
  return rDB

end

--[[
function VehicleDB:CrossProduct(ThatVehicleDB)
  local thisvDB = self
  local thatvDB = ThatVehicleDB
  local resultvDB = {}

  for k, v in pairs(thisvDB) do
    if thatvDB[k] == nil then
      resultvDB[k] = thisvDB[k]
    else
      if thatvDB[Time] > thisvDB[TIme] then
        resultvDB[k] = thatvDB[k]
        table.remove(thatvDB[k])
      else
        resultvDB[k] = thisvDB[k]
      end
    end
  end

  for k, v in pairs(thatvDB) do
    if thisvDB[k] == nil then
      resultvDB[k] = thatvDB[k]
    end
  end


end

VehicleDB.__mul = VehicleDB:CrossProduct

event.ignoreAll()
event.listen(net)
net:open(41) -- VehicleCheck
net:open(42) -- VehicleRegister
net:open(43) -- VehicleAssign

while true do

  local data = {event.pull()}
  local e, s, sender, port, data = (function(e,s,sender,port,...)
    return e, s, sender, port, {...}
  end)(table.unpack(data))

  if e == "NetworkMessage" then
    print("Parsing Incoming Netowrk Signal")
    if port == 41 then
      if d1 == "Check" then
        print("Chekcing Vehicle DB with " .. d2)

        if VehicleDB[d2] == nil then
          VehicleCheck = {"Unregistered", "Unassigned"}
        else
          VehicleCheck = VehicleDB[d2]
        end

        print("Sending Result")
        net:send(sender, port, d1, d2, VehicleCheck[1], VehicleCheck[2], VehicleCheck[Time])
      elseif d1 == "Sync" then
        print("Vehicle DB Serialize ...")
        --
      elseif port == 42 then
        if d1 == "VehicleRegister" then
        elseif d1 == "VehicleDispose" then
        elseif d1 == "VehicleNumberSeedInquiry" then
        end
      elseif port == 43 then
        if d1 == "VehicleAssign" then
        elseif d1 == "VehicleDischarge" then
        elseif d1 == "LogiRouteSync" then
        end
      end
    end
  end
end

]]--