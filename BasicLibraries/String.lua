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