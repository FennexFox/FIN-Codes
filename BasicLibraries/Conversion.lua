RGBA, Number = {}, {}

function RGBA.floats2HexCodes(Color)
	local hex = {}

	for k, v in pairs(Color) do
		local hex = Number.float2Hex(v)
		hex[k] = hex
	end

	hex = hex.r .. hex.g .. hex.b .. hex.a

    return hex
end

function RGBA.hexCodes2Float(hexCode, Color)
	local color = {}
	for k, v in pairs(hexCode) do
		local float = Number.hex2Float(v)
	    color[k] = float
	end

	Color = Color or color
	return Color
end

function RGBA.importHexCodes(Color, hexCode)
	local color = {}
	color.r = string.sub(hexCode, 1, 2)
	color.g = string.sub(hexCode, 3, 4)
	color.b = string.sub(hexCode, 5, 6)

	if string.len(hexCode) == 8 then
	  color.a = string.sub(hexCode, 7, 8)
	else
	  color.a = "FF"
	end

	Color = RGBA.hex2Float(color)
	return Color

end

function Number.float2Hex(Float)
	local hex = math.floor(256*Float + 0.5) - 1
	local hex = string.format("%s", string.format("%x", hex))
	
	return hex
end	

function Number.hex2Float(Hex)
	local float = "0x" .. Hex
	local float = string.format("%f", float)/255
	
	return float
end