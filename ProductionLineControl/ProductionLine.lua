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

        for rkey, v in pairs(ProductionNode) do
            if not recipeTree[rkey] then print("Error: RecipeTree has not cached, abort linking!") return nil
            else
                local recipeNode = recipeTree[rkey]

                v.Recipe = recipeNode
                ProductionLine:ChainSet(rkey)

                for _, i in pairs(recipeNode.Ingredients) do
                    ProductionLine:FlowNodeSet(i, recipeNode, true, 1)
                end
                for _, p in pairs(recipeNode.Products) do
                    ProductionLine:FlowNodeSet(p, recipeNode, nil, 1)
                end
            end
        end

        print("ProductionNode Cacheing Complete") return true
    end

    function ProductionLine:NodeLink()
        for rkeyPrev, nodePrev in pairs(ProductionNode) do
            for rkeyThis, _ in pairs(ProductionNode) do
                for ikeyPush, flowPush in pairs(FlowTree[rkeyPrev].Outflows) do
                    for ikeyPull, flowPull in pairs(FlowTree[rkeyThis].Inflows) do
                        if flowPush.Name == flowPull.Name then -- I know, ikeyPush and ikeyPull are same, but I do this for easy understanding
                            ProductionChain[rkeyPrev].Next[ikeyPush] = ProductionNode[rkeyThis]
                            ProductionChain[rkeyThis].Prev[ikeyPull] = ProductionNode[rkeyPrev]
                        end
                    end
                end
            end
            nodePrev.Link = ProductionChain[rkeyPrev]
        end

        for _, v in pairs(ProductionChain) do
            for ikey, w in pairs(v.Prev) do
                if not w.Machines then v.Prev[ikey] = ProductionLine:TerminalSet(ikey, true) end
            end
            for ikey, w in pairs(v.Next) do
                if not w.Machines then v.Next[ikey] = ProductionLine:TerminalSet(ikey, nil) end
            end
        end

        return true
    end

    function ProductionLine:NodeNew(machineProxy, recipeInstance)
        local mP_trim, rkey = machineProxy, String.KeyGenerator(recipeInstance.Name)

        if not ProductionNode[rkey] then print(recipeInstance.Name .. " is newly added")
            ProductionLine:ChainNew(rkey)
            ProductionLine:FlowNodeNew(rkey)
            ProductionNode[rkey] = {Machines = {machineProxy}, Clock = 1, Link = {}, Flow = FlowTree[rkey], Recipe = {}} -- recipeTree is not yet chached
        else print(recipeInstance.Name .. " already cached")
            table.insert(ProductionNode[rkey].Machines, machineProxy)
            mP_trim = nil
        end

        return mP_trim
    end

    function ProductionLine:ChainNew(rkey)
        ProductionChain[rkey] = {Prev = {}, Next = {}}
    end

    function ProductionLine:ChainSet(rkey)
        for ikeyIn, _ in pairs(recipeTree[rkey].Ingredients) do
            ProductionChain[rkey].Prev[ikeyIn] = {}
        end
        for ikeyOut, _ in pairs(recipeTree[rkey].Products) do
            ProductionChain[rkey].Next[ikeyOut] = {}
        end
    end

    function ProductionLine:FlowNodeNew(rkey)
        FlowTree[rkey] = {Inflows = {}, Outflows = {}}
    end

    function ProductionLine:FlowNodeSet(throughputNode, recipeNode, isInflow, clock)
        local iName, iAmount = throughputNode.Name, throughputNode.Amount
        local ikey, rkey = String.KeyGenerator(iName), String.KeyGenerator(recipeNode.Name)
        
        if isInflow then isInflow = "Inflows" else isInflow = "Outflows" end

        FlowTree[rkey][isInflow][ikey] = {Name = iName, TPM_s = iAmount / recipeNode.Duration, TPM_a = iAmount / recipeNode.Duration * clock, ProductionNode = ProductionNode[rkey]}
    end

    function ProductionLine:ChainPrint()
       print("\n * Printing Production Chain")
       for rkey, node in pairs(ProductionNode) do
         print("ProductNode " .. rkey .. " is after:")
         local isTerminal = true
         for ikey, v in pairs(node.Link.Prev) do
           print(v.Recipe.Name)
           isTerminal = false
         end
         if isTerminal then print("Inbound Terminal") isTerminal = true end

         print("ProductNode " .. rkey .. " is before:")
         for _, w in pairs(node.Link.Next) do
           print(w.Recipe.Name)
           isTerminal = false
         end
         if isTerminal then print("Outbound Terminal") end
       end
    end
 
    function ProductionLine:TerminalSet(ikey, isInbound) -- Terminal class is a placeholder
        if isInbound then isInbound = "Inbound" else isInbound = "Outbound" end
        Terminal[isInbound][ikey] = {Recipe = {Name = isInbound}}
        return Terminal[isInbound][ikey]
    end

    setmetatable(instance, {__index = ProductionLine})
    return instance
end