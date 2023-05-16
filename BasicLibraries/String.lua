String = {}
-- String.Keys = {["Alternate: "] = "A_ ", ["Iron"] = "Irn ", ["Copper"] = "Cpr ", ["Ingot"] = "Igt ", ["Smart"] = "Smrt ", ["Automated"] = "Atm "}

function String.addLine(string, line)
    if string == {} then string = line else string = string .. "\n" .. line end
    return string
end

function String.KeyGenerator(name)
    local key = name

    key = string.gsub(key, "Alternate: ", "A_ ")
    key = string.gsub(key, "Iron", "Irn ")
    key = string.gsub(key, "Copper", "Cpr ")
    key = string.gsub(key, "Ingot", "Igt ")
    key = string.gsub(key, "Smart", "Smrt ")
    key = string.gsub(key, "Automated", "Atm ")

    key = string.gsub(key, " ", "")
    return key
end