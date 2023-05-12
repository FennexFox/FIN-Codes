ProcessSystem = {}

function ProcessSystem:New()
    local instance = {}

    local errorString, recipeTree = "", {}
    local factories = component.findComponent(findClass("Manufacturer"))

    function ProcessSystem:Initialize()
        if factories[1] == nil then errorString = "Error: No Manufacturer Found"
        else 
            recipeTree = ProcessSystem:Probe(factories, recipeTree)
            recipeTree = ProcessSystem:Cache(recipeTree)
            recipeTree = ProcessSystem:Link(recipeTree)

            -- ProcessSystem:Print(recipeTree)
        end
        if errorString == "" then return recipeTree else print(errorString) end
    end

    function ProcessSystem:KeyGenerator(recipeName)
        local key = string.gsub(recipeName, "Alternate: ", "A_")
        key = string.gsub(key, " ", "")
        return key
    end

    function ProcessSystem:Probe(factories, recipeTree) -- iterate all machines in the network to get reciepes
        for k, v in ipairs(factories) do
            local recipe = component.proxy(v):getRecipe()
            local key = self:KeyGenerator(recipe.Name)
            if recipeTree[key] == nil then
                recipeTree[key] = {Name = recipe.Name, Duration = recipe.Duration, temp = {is = recipe:getIngredients(), ps = recipe:getProducts()}}
            end
        end

        recipeTree.Input = {Name = "Input", Duration = 0, Inflows = {From = {}}, Outflows = {To = {}}}
        recipeTree.Output = {Name = "Output", Duration = 0, Inflows = {From = {}}, Outflows = {To = {}}}
        
    
        return recipeTree
    
    end

    function ProcessSystem:Cache(recipeTree)
        for _, v in pairs(recipeTree) do -- cacheing recipe data
            v.Inflows, v.Outflows = {}, {}
            if v.temp then
                for _, i in pairs(v.temp.is) do
                    local key = self:KeyGenerator(i.Type.Name)
                    v.Inflows[key] = {Name = i.Type.Name, DPS_s = i.Amount/v.Duration, From = {}}
                    v.Inflows[key].From[0] = v.Input
                end
                for _, p in pairs(v.temp.ps) do
                    local key = self:KeyGenerator(p.Type.Name)
                    v.Outflows[key] = {Name = p.Type.Name, SPS_s = p.Amount/v.Duration, To = {}}
                    v.Outflows[key].To[0] = v.Output
                end   
                v.temp = nil
            end
        end
    
        return recipeTree
    
    end
    
    function ProcessSystem:Link(recipeTree) -- linking recipeTree[k] with matching ingredients and products
        local InflowLinks = {}
        local OutflowLinks = {}
    
        for _, v in pairs(recipeTree) do
            for _, w in pairs(recipeTree) do
                for _, vOutflow in pairs(v.Outflows) do
                    for _, wInflow in pairs(w.Inflows) do
                        if vOutflow.Name == wInflow.Name then
                            if InflowLinks[wInflow.Name] == nil then
                                table.insert(wInflow.From, v)
                                InflowLinks[wInflow.Name] = true
                            end
                            if OutflowLinks[vOutflow.Name] == nil then
                                table.insert(vOutflow.To, w)
                                OutflowLinks[vOutflow.Name] = true
                            end
                        end
                    end
                end
            end
        end

        for _, v in pairs(recipeTree) do
            for _, inflow in pairs(v.Inflows) do
                if InflowLinks[inflow.Name] then else inflow.From = recipeTree.Input end
            end
            for _, outflow in pairs(v.Outflows) do
                if OutflowLinks[outflow.Name] then else outflow.To = recipeTree.Output end
            end
        end
    
        return recipeTree

    end

    function ProcessSystem:Print(recipeTree)
        for k, v in pairs(recipeTree) do
            local iString, iString1, pString, pString1
            if v.Inflows then
                for _, vInflow in pairs(v.Inflows) do
                  iString1 = vInflow.Name .. " * " .. vInflow.DPS_s
                  if not vInflow.Name == "Input" then iString1 = "(" .. iString1 .. ") by" .. vInflow.From[1].Name end
                  if iString then iString = iString .. " and " .. iString1 else iString = iString1 end
                end
            end
            if v.Outflows then 
                for _, vOutflow in pairs(v.Outflows) do
                  pString1 = vOutflow.Name .. " * " .. vOutflow.SPS_s
                  if not vOutflow.Name == "Output" then pString1 = "(" .. pString1 .. ") by" .. vOutflow.To[1].Name end
                  if pString then pString = pString .. " and " .. pString1 else pString = pString1 end
                end
            end

            print(k, ": from ", iString, " to ", pString)

        end
    end

    setmetatable(instance, {__index = ProcessSystem})
    return instance

end

what = ProcessSystem:New()
what:Initialize()


--[[
for _, v in pairs(recipeTree) do
    keyv = self:KeyGenerator(v.Name)
    for _, inflow in pairs(v.Inflows) do
        for _, from in pairs(inflow.From) do
            if type(from) == "number" then print(keyv .. " makes number") else
            keyx = ProcessSystem:KeyGenerator(tostring(from.Name))
            print("from " .. keyx)
            end
        end
    end
end


from IronPlate
from nil
from nil
from nil
A_CoatedIronCanister makes number
from nil
from nil
from nil
A_AutomatedMiner makes number
from nil
from nil
from nil
A_AutomatedMiner makes number
from nil
from nil
from nil
A_AutomatedMiner makes number
from nil
from nil
from nil
IronPlate makes number
]]--