String = {}

function String.KeyGenerator(name)
    local key, temp = name, {}

    local patterns = {
        {"Alternate: ", "/Alt_ "},
        {"Ore", "/O"},
        {"Iron", "/Fe"},
        {"Copper", "/Cu"},
        {"Almuinum", "/Al"},
        {"Almuina", "/Al"},
        {"Utranium", "/U"},
        {"Plutonium", "/Pu"},
    }

    for _, pattern in ipairs(patterns) do
        key = string.gsub(key, pattern[1], pattern[2])
    end

    for word in key:gmatch("%S+") do
        local firstLetter, restOfWord = word:sub(1, 1), word:sub(2)
        if firstLetter == "/" then firstLetter = ""
        else restOfWord = restOfWord:gsub("[AEIOUaeiou]", "")
        end

        table.insert(temp, firstLetter .. restOfWord)
    end
    
    local key = table.concat(temp)
    return key
end

function String.ItemKeyGenerator(itemType)
    local name, key = String.KeyGenerator(itemType.name), ""
    local size = string.format("%02.0f", itemType.max/50)

    for v in name:gmatch("%u%U?%U?") do
        local keyLen = string.len(key:match("%u+") or "")
        if keyLen > 3 then break end
        key = key:sub(1, keyLen) .. v
    end

    key = key:upper() .. "xx"
    return size .. key:sub(1, 3)
end

function String.NameParser(name)
    local type = name:gsub("%[(.*)%]_(.*)", "%1")
    local key = name:gsub("%[(.*)%]_(.*)", "%2")
    
    return type, key
end