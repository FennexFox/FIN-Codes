-- Dependent on String

RecipeTree = {}

function RecipeTree:New()
    local instance = {}

    function RecipeTree:Fetch() -- fetch RecipeTree on Central DB
        
    end

    function RecipeTree:NewNode(recipeInstance)
        local recipe = recipeInstance
        local status, rkey = pcall(String.KeyGenerator, recipe.Name)

        if not status then error("Cannot find Name of the Recipe!")
        elseif not self[rkey] then 
            local ingredients, products = recipe:getIngredients(), recipe:getProducts()
            local iCounter, pCounter = 0, 0
            
            self[rkey] = {
                Name = "[RN]_" .. rkey,
                Duration = recipe.Duration,
                ThroughputMatrix = {Inflows = {}, Outflows = {}},
                Recipe = recipe
            }

            for _, i in pairs(ingredients) do
                self:SetThroughputMatrix(self[rkey], i, true)
                iCounter = iCounter + 1
            end
            for _, p in pairs(products) do
                self:SetThroughputMatrix(self[rkey], p, nil)
                pCounter = pCounter + 1
            end

            print("  - " .. self[rkey].Name .. " set: " .. iCounter .. " ingredients & " .. pCounter .. " products")
            return true
        end
    end

    function RecipeTree:NewNodes(recipeInstances)
        local counter = 0

        print("\n... ReciepeTree Updating: Scanning " .. #recipeInstances .. " Recipes ...")

        for _, v in ipairs(recipeInstances) do
            if self:NewNode(v) then counter = counter + 1 end
        end

        print("... ReciepeTree Updated: " .. counter .. " Node Added ...\n")
        return true
    end
    
    function RecipeTree:SetThroughputMatrix(recipeNode, itemAmount, isIngredient)
        local rkey, ikey, fkey = string.sub(recipeNode.Name, 6, -1), String.KeyGenerator(itemAmount.Type.Name), ""
        if isIngredient then fkey = "Inflows" else fkey = "Outflows" end

        self[rkey].ThroughputMatrix[fkey][ikey] = {Name = itemAmount.Type.Name, Amount = itemAmount.Amount, Duration = recipeNode.Duration, Recipe = recipeNode}
    end

    setmetatable(instance, {__index = self})
    return instance
end