-- Dependent on String

RecipeTree = {}

function RecipeTree:New()
    local instance = {}

    function RecipeTree:sync() -- sync this instance with the RecipeTree on Central DB
        
    end

    function RecipeTree:NewNode(recipeInstance)
        local recipe = recipeInstance
        local status, rkey = pcall(String.KeyGenerator, recipe.Name)
        local iCounter, pCounter = 0, 0

        if not status then error("Cannot find Name of the Recipe!")
        elseif self[rkey] then error(recipe.Name .. " already listed; abort adding RecipeNode")
        else
            self[rkey] = {Name = recipe.Name, Duration = recipe.Duration, Inflows = {}, Outflows = {}, Recipe = recipe}
            print(recipe.Name .. " detected; cacheing ingredients and products")
            local ingredients, products = recipe:getIngredients(), recipe:getProducts()

            for _, i in pairs(ingredients) do
                local ikey = String.KeyGenerator(i.Type.Name)
                self[rkey].Ingredients[ikey] = self:SetThroughtputs(self[rkey], i, true)
                iCounter = iCounter + 1
            end
            for _, p in pairs(products) do
                local ikey = String.KeyGenerator(p.Type.Name)
                self[rkey].Products[ikey] = self:SetThroughtputs(self[rkey], p, nil)
                pCounter = pCounter + 1
            end

            print(iCounter .. " ingredients and " .. pCounter .. " products added") return true
        end
    end
    
    function RecipeTree:Cache(machineProxies)
        for _, v in ipairs(machineProxies) do
            local status, recipeInstance = pcall(v.getRecipe, v)
            if not status then error(v.internalName .. " has no Recipe!")
            else self:NewNode(recipeInstance)
            end
        end

        print("RecipeNode Cacheing Complete") return true
    end

    function RecipeTree:SetThroughputs(recipeNode, itemAmount, isIngredient)
        local rkey, ikey, fkey = String.KeyGenerator(recipeNode.Name), String.KeyGenerator(itemAmount.Type.Name), ""
        if isIngredient then fkey = "Inflows" else fkey = "Outflows" end

        self[rkey][fkey][ikey] = {Name = itemAmount.Type.Name, Amount = itemAmount.Amount, Duration = recipeNode.Duration, Recipe = recipeNode, IsIngredient = isIngredient}
    end

    setmetatable(instance, {__index = self})
    return instance
end