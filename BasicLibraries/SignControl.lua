-- Dependent on Conversion

SignControl = {}
ColorPreset = {
  Ficsit = {Primary = "FA9549", Secondary = "5F668C", Background = "583113"},
  Traffic = {R = "FF0000", Y = "FFCC00", G= "009900"},
  Basic = {White = "FFFFFF", Black = "000000"}
} -- this might be separated into its own "library" or be merged into member field of SignControl. Let me see.

function SignControl:Get (Identifier)
  local signProxy = component.proxy(component.findComponent(Identifier)[1])
  local prefabSignData = signProxy:getPrefabSignData()
  local sign = {signProxy, prefabSignData}

  setmetatable(sign, self)
  self.__index = self

  return sign
end

function SignControl:Refresh ()
  self[1]:setPrefabSignData(self[2])
end

function SignControl:SetColor (ColorLayerPair)
  for k, v in pairs(ColorLayerPair) do
    self[2][k] = v 
  end
end

function SignControl:SetColorPreset (ColorLayerPair)
  for k, v in pairs(ColorLayerPair) do
    self[2][k] = RGBA.importHexCodes(v)
  end
end

--[[ Below here might be excluded from "the basic library"

function SignControl:SetStandby ()
  self[2]:setTextElement("Name", "Standby")
  self[2]:setIconElement("Icon", 598)
  local clp = {foreground = ColorPreset.Ficsit.Secondary}
  self:SetColorPreset(clp)
end

function SignControl:SetScanning ()
  self[2]:setTextElement("Name", "Scanning")
  self[2]:setIconElement("Icon", 644)
  local clp = {foreground = ColorPreset.Ficsit.Secondary}
  self:SetColorPreset(clp)
end

function SignControl:SetUnregistered ()
  self[2]:setTextElement("Name", "Unregistered")
  self[2]:setIconElement("Icon", 362)
  local clp = {foreground = ColorPreset.Traffic.R}
  self:SetColorPreset(clp)
end

function SignControl:SetUnassigned ()
  self[2]:setTextElement("Name", "Unassigned")
  self[2]:setIconElement("Icon", 362)
  local clp = {foreground = ColorPreset.Traffic.Y}
  self:SetColorPreset(clp)
end

function SignControl:SetAllGreen ()
  self[2]:setTextElement("Name", "Vehicle All Set")
  self[2]:setIconElement("Icon", 339)
  local clp = {foreground = ColorPreset.Traffic.G}
  SignControl:SetColorPreset(clp)
end

]]--