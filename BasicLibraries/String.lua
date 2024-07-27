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

    for word in key:gmatch("%S+") do -- For any substring without spaces, remove all vowels
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

    for v in name:gmatch("%u%U?%U?") do -- finding 3~1 letters starts with a uupercase and then lowercases
        local keyLen = string.len(key:match("%u+") or "")
        if keyLen > 3 then break end -- if key is already longer than 3 letters, abort
        key = key:sub(1, keyLen) .. v -- if not, make it longer
    end

    key = key:upper() .. "xx" -- if key is still shorter than 3 letters, put placeholder
    return size .. key:sub(1, 3)
end

function String.NameParser(name)
    local nodeType = name:gsub("%[(.*)%]_(.*)", "%1")
    local nodeKey = name:gsub("%[(.*)%]_(.*)", "%2")
    
    return nodeType, nodeKey
end

function String.Composer(spacer, ...)
    local query = ""
    for _, v in pairs({...}) do query = query .. spacer .. v end

    return query:gsub("^%s*(.+)", "%1")
end