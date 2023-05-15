String = {}

function String.addLine(string, line)
    if string == {} then string = line else string = string .. "\n" .. line end
    return string
end

function String.KeyGenerator(name)
    local key = string.gsub(name, "Alternate: ", "A_ ")
    key = string.gsub(key, "Iron", "Irn ")
    key = string.gsub(key, "Copper", "Cpr ")
    key = string.gsub(key, "Ingot", "Ing ")
    key = string.gsub(key, " ", "")
    return key
end