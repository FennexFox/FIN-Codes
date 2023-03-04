FS = filesystem

if FS.initFileSystem("/dev") == false then
    computer.panic("Cannot initialize /dev")
end

FS.mount("/dev/8BE14772450982E00C7C568BC65FBAE6", "/Library/")

FS.doFile("Library/Conversion.lua")
FS.doFile("Library/SignControl.lua")
FS.doFile("Library/IO.lua")
FS.doFile("Library/VMIO.lua")

VehicleManagerScanner = component.proxy(component.findComponent("Scanner")[1])
VehicleManagerIO = component.proxy(component.findComponent("IO")[1])
VehicleDBManager = component.proxy(component.findComponent("DB Test")[1])
SignTest = SignControl:Get("SignTest")
Net = computer.getPCIDevices(findClass("NetworkCard"))[1]
VehicleDBCash = {}

VMIOcntl = VMIO:New("IO", "Vehicle Manager IO System")
VMIOcntl:Initialize()

event.ignoreAll()
event.listen(VehicleManagerScanner)
event.listen(VehicleManagerIO)
event.listen(Net)
event.listen(VMIOcntl.Comps.Powers.Panel)
  Net:open(41) -- VehicleCheck
  Net:open(42) -- VehicleRegister
  Net:open(43) -- VehicleAssign

function NetworkComm(e, s, sender, port, data)
  if e == "NetworkMessage" then
    print("Parsing Incoming Network Signal")
    if port == 41 and data[1] == "Check" then
      print("Vehicle Check Query Returned")
      if data[3] ~= nil then
        print("Vehicle Already Registered")
        VehicleDBCash.data[2] = {data[3], data[4]}
        if data[4] ~= nil then
          print("Vehicle Already Assigned")
          SignTest.SetAllGreen()
        else
          print("Initiate Vehicle Assign")
          SIgnTest.SetUnassigned()
        end
      else
        print("Initiate Vehicle Register")
        SignTest.SetUnregistered()
      end
    elseif port == 41 and data[1] == "Sync" then
      print("Vehicle DB incoming ...")
      --
    end
  end

  if e == "OnVehicleEnter" then
    print("Vehicle Detected")
    VehicleSubject = sender
    VehicleCheck = VehicleSubject.internalName
    SignTest.SetScanning()
    print("Vehicle ID: ".. VehicleCheck)
    if VehicleDBCash.VehicleCheck == nil then
      print("Vehicle Check Query Transimitted")
      Net:send("F76BE2A74E8DFA6D65D6CD9326113404", 41, "Check", VehicleCheck)
    elseif VehicleDBCash.VehicleCheck[2] == nil then
      print("Initiate Vehicle Assign")
      SignTest.SetUnassigned()
    else
      print("Vehicle Already Assigned")
      SignTest.SetAllGreen()
    end
  end

  if e == "OnVehicleExit" then
    print("Vehicle Exited")
    SignTest.SetStandby()
    VehicleSubject = nil
  end

  SignTest:Refresh()

end

function SignalHandler()

  while true do
    local data = {event.pull()}
    local e, s, sender, port, data = (function(e,s,sender,port,...)
      return e, s, sender, port, {...}
    end)(table.unpack(data))

    if e == "NetworkMessage" or e == "OnvVehicleEnter" or e == "OnVehicleExit" then
      NetworkComm(e, s, sender, port, data)
    else
      VMIOcntl:Run(e, s, sender, port, data)
    end
  end
end

SignalHandler()