-- Dependent on String

RecipeTree = {}

function RecipeTree:New()
    local instance = {}

    function RecipeTree:Fetch() -- fetch RecipeTree on Central DB
        
    end

    function RecipeTree:NewNode(recipeInstance)
        local recipe = recipeInstance
        local rkey = assert(String.KeyGenerator(recipe.Name), "Cannot find Name of the Recipe!")

        if not self[rkey] then
            local ingredients, products = recipe:getIngredients(), recipe:getProducts()
            local iCounter, pCounter = 0, 0
            
            self[rkey] = {
                Name = "[RN]_" .. rkey,
                Duration = recipe.Duration,
                Inflows = {},
                Outflows = {},
                Recipe = recipe,
                Tags = {}
            }

            for _, i in pairs(ingredients) do
                self:SetThroughputMatrix(self[rkey], i, true)
                iCounter = iCounter + 1
            end
            for _, p in pairs(products) do
                self:SetThroughputMatrix(self[rkey], p, nil)
                pCounter = pCounter + 1
            end

            print("    - " .. self[rkey].Name .. " set: " .. iCounter .. " ingredients & " .. pCounter .. " products")
            return true
        end
    end

    function RecipeTree:NewNodes(recipeInstances)
        local counter = 0

        print("\n  - ReciepeTree Updating: Assessing " .. #recipeInstances .. " Recipe(s)")

        for _, v in ipairs(recipeInstances) do
            if self:NewNode(v) then counter = counter + 1 end
        end

        print("  -  ReciepeTree Updated: " .. counter .. " Node(s) Added ...\n")
        return true
    end
    
    function RecipeTree:SetThroughputMatrix(recipeNode, itemAmount, isIngredient)
        local rkey, ikey, fkey = String.KeyGenerator(recipeNode.Recipe.name), String.ItemKeyGenerator(itemAmount.Type), ""
        if isIngredient then fkey = "Inflows" else fkey = "Outflows" end

        self[rkey][fkey][ikey] = {Item = itemAmount.Type, Amount = itemAmount.Amount, Duration = recipeNode.Duration}
    end

    function RecipeTree:GetThroughputItemPair(rkey, ikeyThis, ikeyNext, isIncremental)
        local recipeNode, throughput = self[rkey], {}
        local ikeyOut, ikeyIn

        if isIncremental then ikeyOut, ikeyIn = ikeyNext, ikeyThis else ikeyOut, ikeyIn = ikeyThis, ikeyNext end

        throughput[ikeyOut] = recipeNode.Outflows[ikeyOut].Amount
        throughput[ikeyIn] = recipeNode.Inflows[ikeyIn].Amount
        throughput[rkey] = recipeNode.Duration

        return throughput
    end

    setmetatable(instance, {__index = self})
    return instance
end