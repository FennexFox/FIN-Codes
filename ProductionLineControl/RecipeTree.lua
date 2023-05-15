-- Dependent on String

RecipeTree = {}

function RecipeTree:New()
    local instance = {}

    function RecipeTree:sync() -- sync this instance with the RecipeTree on Central DB
        
    end

    function RecipeTree:NewThroughtputNode(recipeNode, itemAmount, isIngredient)
        local throughtput = {Name = itemAmount.Type.Name, Amount = itemAmount.Amount, Duration = recipeNode.Duration, Recipe = recipeNode, IsIngredient = isIngredient}
        return throughtput
    end
    
    function RecipeTree:NewRecipeNode(recipeInstance)
        local recipe = recipeInstance
        local status, rkey = pcall(String.KeyGenerator, recipe.Name)

        if not status then print("Error: Can't find Name of the Recipe!") return nil
        elseif self[rkey] then print(recipe.Name .. " already listed; abort adding RecipeNode") return nil
        else
            self[rkey] = {Name = recipe.Name, Duration = recipe.Duration, Ingredients = {}, Products = {}}
            print(recipe.Name .. " detected; cacheing ingredients and products")
            local ingredients, products = recipe:getIngredients(), recipe:getProducts()

            for _, i in pairs(ingredients) do
                local ikey = String.KeyGenerator(i.Type.Name)
                self[rkey].Ingredients[ikey] = self:NewThroughtputNode(self[rkey], i, true)
            end
            for _, p in pairs(products) do
                local ikey = String.KeyGenerator(p.Type.Name)
                self[rkey].Products[ikey] = self:NewThroughtputNode(self[rkey], p, nil)
            end
            print(#self[rkey].Ingredients .. " ingredients and " .. #self[rkey].Products .. " products added") return true
        end
    end
    
    function RecipeTree:Cache(machineProxies)
        for _, v in ipairs(machineProxies) do
            local status, recipeInstance = pcall(v.getRecipe, v)
            if not status then print("Error: " .. v.internalName .. " has no Recipe!") return nil
            else self:NewRecipeNode(recipeInstance)
            end
        end

        print("RecipeNode Cacheing Complete") return true
    end

    setmetatable(instance, {__index = RecipeTree})
    return instance
end