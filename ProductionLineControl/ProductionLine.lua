-- dependent on RecipeTree
-- dependent on String

ProductionLine = {}

function ProductionLine:New()
    local instance = {}
    local ProductionNode, ProductionChain, FlowTree = {}, {}, {} -- these are private fields
    local recipeTree = {} -- This is a clone of RecipeTree from Central DB

    function ProductionLine:Initialize()
        recipeTree = ProductionLine:GetRecipeTree()
        local machineIDs = component.findComponent(findClass("Manufacturer"))

        if machineIDs[1] == nil then
            print("Error: No Manufacturer Found!") return nil
        else
            print(#machineIDs .. " Manufacturers found, Cacheing Production Nodes")
            if not ProductionLine:NodeCache(machineIDs) then return nil
            else print("Linking Production Nodes to draw Production Chain")
                if not ProductionLine:NodeLink() then return nil
                else print("Production Line Initialized")
                end
            end
        end 
    end

    function ProductionLine:NodeCache(machineIDs)
        local mP_trim = {}
        local machineProxies = component.proxy(machineIDs)

        for _, v in machineProxies do
            local status, recipeInstance = pcall(v.getRecipe, v)
            if not status then print("Error: " .. v.internalName .. " has no Recipe!") return nil
            else
                table.insert(mP_trim, ProductionLine:NodeNew(v, recipeInstance))
            end
        end

        print(#ProductionNode .. " Production Nodes found, cacheing Recipe Nodes")
        recipeTree:Cache(mP_trim)

        for rkey, _ in pairs(ProductionNode) do
            if not recipeTree[rkey] then print("Error: RecipeTree has not cached, abort linking") return nil
            else
            local ingredients, products = recipeTree[rkey]:getIngredients(), recipeTree[rkey]:getProducts()
                for _, i in ipairs(ingredients) do
                    FlowTree[rkey] = ProductionLine:FlowNodeNew(i, recipeTree[rkey], true, 1)
                end
                for _, p in ipairs(products) do
                    FlowTree[rkey] = ProductionLine:FlowNodeNew(p, recipeTree[rkey], nil, 1)
                end
            end
        end

        print("ProductionNode Cacheing Complete") return true
    end
    function ProductionLine:NodeLink()
        for rkey1, v in pairs(FlowTree) do
            for rkey2, w in pairs(FlowTree) do
                for ikey1, inflow in pairs(v.Inflow) do
                    for ikey2, outflow in pairs(w.Outflow) do
                        if inflow.Name == outflow.Name then
                            ProductionChain[rkey1].Prev[ikey1] = ProductionNode[rkey2]
                            ProductionChain[rkey2].Next[ikey2] = ProductionNode[rkey1]
                        elseif not ProductionChain[rkey1].Prev[ikey1] then
                            ProductionChain[rkey1].Prev[ikey1] = self:TerminalNew(ikey1, true)
                        elseif not ProductionChain[rkey2].Next[ikey2] then
                            ProductionChain[rkey2].Next[ikey2] = self:TerminalNew(ikey2, nil)
                        end
                    end
                end
            end
        end
    end

    function ProductionLine:NodeNew(machineProxy, recipeInstance)
        local mP_trim, rkey = machineProxy, String.KeyGenerator(recipeInstance.Name)

        if not ProductionNode[rkey] then
            ProductionChain[rkey], FlowTree[rkey] = {Prev = {}, Next = {}}, {Inflow = {}, Outflow = {}}
            ProductionNode[rkey] = {Machines = machineProxy, Clock = 1, Link = ProductionChain[rkey], Flow = FlowTree[rkey], Recipe = {}}
        else
            table.insert(ProductionNode[rkey].Machines, machineProxy)
            mP_trim = nil
        end

        return mP_trim
    end

    function ProductionLine:FlowNodeNew(itemAmount, recipeNode, isInflow, clock)
        local iName, iAmount = itemAmount.Type.Name, itemAmount.Amount
        local ikey, rkey = String.KeyGenerator(iName), String.KeyGenerator(recipeNode.Name)
        
        if isInflow then isInflow = "Inflow" else isInflow = "Outflow" end
        FlowTree[rkey][isInflow][ikey] = {Name = iName, TPM_s = iAmount / recipeNode.Duration, TPM_a = iAmount / recipeNode.Duration * clock}
    end

    function ProductionLine:TerminalNew(ikey, isInbound)
        if isInbound then isInbound = "Inbound" else isInbound = "Outbound" end

        ProductionNode[isInbound][ikey] = {}
    end

    setmetatable(instance, {__index = ProductionLine})
    return instance
end