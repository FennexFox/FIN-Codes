Conversion = {RGBA = {}, Number = {}}

function Conversion.RGBA.Float2Hex(RGBAfloat)
	local RGBAhex = {}

	for k, v in pairs(RGBAfloat) do
		local hex = Conversion.Number.Float2Hex(v)
		RGBAhex[k] = hex
	end

	if RGBAhex.a == nil then RGBAhex.a = "FF" end

    return RGBAhex

end

function Conversion.RGBA.Hex2Float(RGBAhex)
    local RGBAfloat = {}

	for k, v in pairs(RGBAhex) do
		local float = Conversion.Number.Hex2Float(v)
	    RGBAfloat[k] = float
	end

	return RGBAfloat

end

function Conversion.RGBA.ImportHex(Hex)
	local color = {}
	color.r = string.sub(Hex, 1, 2)
	color.g = string.sub(Hex, 3, 4)
	color.b = string.sub(Hex, 5, 6)

	if string.len(Hex) == 8 then
	  color.a = string.sub(Hex, 7, 8)
	else
	  color.a = "FF"
	end

	color = Conversion.RGBA.Hex2Float(color)
	return color

end

function Conversion.Number.Float2Hex(Float)
	local hex = math.floor(256*Float + 0.5) - 1
	local hex = string.format("%s", string.format("%x", hex))
	
	return hex
end	

function Conversion.Number.Hex2Float(Hex)
	local float = "0x" .. Hex
	local float = string.format("%f", float)/255
	
	return float
end