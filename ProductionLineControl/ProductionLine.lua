-- dependent on RecipeTree
-- dependent on String

ProductionLine = {}

function ProductionLine:New()
    local instance = {}
    local ProductionNode, ProductionChain, FlowTree, Terminal = {}, {}, {}, {Inbound = {}, Outbound = {}} -- these are private fields
    local recipeTree = RecipeTree:New() -- This is a clone of RecipeTree from Central DB

    function ProductionLine:Initialize()
        --recipeTree = ProductionLine:GetRecipeTree()
        local machineIDs = component.findComponent(findClass("Manufacturer"))

        if machineIDs[1] == nil then
            print("Error: No Manufacturer Found!") return nil
        else
            print(#machineIDs .. " Manufacturers found, Cacheing Production Nodes")
            if not ProductionLine:NodeCache(machineIDs) then print("Error: Production Node not Cached!") return nil
            else print("Linking Production Nodes to draw Production Chain")
                if not ProductionLine:NodeLink() then print("Error: Production Nodes not Linked!") return nil
                else print("Production Line Initialized")
                end
            end
        end 
    end

    function ProductionLine:NodeCache(machineIDs)
        local mP_trim, counter = {}, 0
        local machineProxies = component.proxy(machineIDs)

        for _, v in pairs(machineProxies) do
            local status, recipeInstance = pcall(v.getRecipe, v)
            if not status then print("Error: " .. v.internalName .. " has no Recipe!") return nil
            else 
                table.insert(mP_trim, ProductionLine:NodeNew(v, recipeInstance))
                counter = counter + 1
            end
        end

        print(counter .. " Production Nodes found, cacheing Recipe Nodes")
        recipeTree:Cache(mP_trim)

        for rkey, _ in pairs(ProductionNode) do
            if not recipeTree[rkey] then print("Error: RecipeTree has not cached, abort linking!") return nil
            else
            local ingredients, products = recipeTree[rkey].Recipe:getIngredients(), recipeTree[rkey].Recipe:getProducts()
                for _, i in ipairs(ingredients) do
                    ProductionLine:FlowNodeSet(i, recipeTree[rkey], true, 1)
                end
                for _, p in ipairs(products) do
                    ProductionLine:FlowNodeSet(p, recipeTree[rkey], nil, 1)
                end
            end
        end

        print("ProductionNode Cacheing Complete") return true
    end

    function ProductionLine:NodeLink()
        for rkey1, v in pairs(ProductionNode) do
            for rkey2, w in pairs(ProductionNode) do
                local inflows, outflows = {}, {}
                if FlowTree[rkey1].Inflow and FlowTree[rkey2].Outflow then
                    inflows = FlowTree[rkey1].Inflow
                    outflows = FlowTree[rkey2].Outflow
                elseif FlowTree[rkey1].Outflow and FlowTree[rkey2].Inflow then
                    outflows = FlowTree[rkey1].Outflow
                    inflows = FlowTree[rkey2].Inflow
                else break
                end
                for ikey1, inflow in pairs(inflows) do
                    for ikey2, outflow in pairs(outflows) do
                        if inflow.Name == outflow.Name then
                            ProductionChain[rkey1].Prev[ikey1] = ProductionNode[rkey2]
                            ProductionChain[rkey2].Next[ikey2] = ProductionNode[rkey1]
                        end
                    end
                end
            end
        end

        for _, v in pairs(ProductionChain) do
            for ikey, w in pairs(v.Prev) do
                if #w == 0 then w = ProductionLine:TerminalNew(ikey, true) end
            end
            for ikey, w in pairs(v.Next) do
                if #w == 0 then w = ProductionLine:TerminalNew(ikey, nil) end
            end
        end

        return true
    end

    function ProductionLine:NodeNew(machineProxy, recipeInstance)
        local mP_trim, rkey = machineProxy, String.KeyGenerator(recipeInstance.Name)

        if not ProductionNode[rkey] then print(recipeInstance.Name .. " is newly added")
            ProductionLine:ChainNew(rkey)
            ProductionLine:FlowNodeNew(rkey)
            ProductionNode[rkey] = {Machines = {machineProxy}, Clock = 1, Link = ProductionChain[rkey], Flow = FlowTree[rkey], Recipe = {}} -- recipeTree is not yet chached
        else print(recipeInstance.Name .. " already cached")
            table.insert(ProductionNode[rkey].Machines, machineProxy)
            mP_trim = nil
        end

        return mP_trim
    end

    function ProductionLine:ChainNew(rkey)
        ProductionChain[rkey] = {Prev = {}, Next = {}}
    end

    function ProductionLine:FlowNodeNew(rkey)
        FlowTree[rkey] = {Inflow = {}, Outflow = {}}
    end

    function ProductionLine:FlowNodeSet(itemAmount, recipeNode, isInflow, clock)
        local iName, iAmount = itemAmount.Type.Name, itemAmount.Amount
        local ikey, rkey = String.KeyGenerator(iName), String.KeyGenerator(recipeNode.Name)
        
        if isInflow then isInflow = "Inflow" else isInflow = "Outflow" end

        FlowTree[rkey][isInflow][ikey] = {Name = iName, TPM_s = iAmount / recipeNode.Duration, TPM_a = iAmount / recipeNode.Duration * clock}
    end

    function ProductionLine:FlowNodePrint()
       for rkey, v in pairs(ProductionNode) do print(rkey)
         print("Product Node " .. rkey .. " is next to:")
         if FlowTree[rkey].Inflow then
           for _, w in pairs(FlowTree[rkey].Inflow) do
             print(w.Name)
           end
         end
         print("Product Node " .. rkey .. " is before:")
         if FlowTree[rkey].Outflow then
           for _, x in pairs(FlowTree[rkey].Outflow) do
             print(x.Name)
           end
         end
       end
    end
 
    function ProductionLine:TerminalNew(ikey, isInbound)
        if isInbound then isInbound = "Inbound" else isInbound = "Outbound" end

        Terminal[isInbound][ikey] = {}
    end

    setmetatable(instance, {__index = ProductionLine})
    return instance
end