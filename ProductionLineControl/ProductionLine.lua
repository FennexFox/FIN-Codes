-- dependent on RecipeTree
-- dependent on String

ProductionLine, ProductionNode, ProductionChain, FlowTree, Terminal = {}, {}, {}, {}, {}

function ProductionLine:New(doInitialize, doPrint)
    local instance = {}
    local productionNode, productionChain, flowTree, terminal = {}, {}, {}, {} -- these are private fields
    local recipeTree = RecipeTree:New() -- This is a clone of RecipeTree from Central DB

    function ProductionLine:Initialize()
        --recipeTree = ProductionLine:GetRecipeTree()
        local machineIDs = component.findComponent(findClass("Manufacturer"))

        if #machineIDs == 0 then
            error("No Manufacturer Found!")
        else
            print(#machineIDs .. " Manufacturers found, Cacheing Production Nodes")
            if not ProductionLine:NodeCache(machineIDs) then error("Production Node not Cached!")
            else print("Linking Production Nodes to draw Production Chain")
                if not ProductionLine:NodeLink() then error("Production Nodes not Linked!")
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
            if not status then error(v.internalName .. " has no Recipe!")
            else 
                table.insert(mP_trim, ProductionLine:NodeNew(v, recipeInstance))
                counter = counter + 1
            end
        end

        print(counter .. " Production Nodes found, cacheing Recipe Nodes")
        recipeTree:Cache(mP_trim)

        for rkey, v in pairs(productionNode) do
            if not recipeTree[rkey] then error("RecipeTree has not cached, abort linking!")
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
        for rkeyPrev, nodePrev in pairs(productionNode) do
            for rkeyThis, _ in pairs(productionNode) do
                for ikeyPush, flowPush in pairs(flowTree[rkeyPrev].Outflows) do
                    for ikeyPull, flowPull in pairs(flowTree[rkeyThis].Inflows) do
                        if flowPush.Name == flowPull.Name then -- I know, ikeyPush and ikeyPull are same, but I do this for easy understanding
                            productionChain[rkeyPrev].Next[ikeyPush] = productionNode[rkeyThis]
                            productionChain[rkeyThis].Prev[ikeyPull] = productionNode[rkeyPrev]
                        end
                    end
                end
            end
            nodePrev.Link = productionChain[rkeyPrev]
        end

        for _, v in pairs(productionChain) do
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

        if not productionNode[rkey] then print(recipeInstance.Name .. " is newly added")
            ProductionLine:ChainNew(rkey)
            ProductionLine:FlowNodeNew(rkey)
            productionNode[rkey] = {Machines = {machineProxy}, Clock = 1, Link = {}, Flow = flowTree[rkey], Recipe = {}} -- recipeTree is not yet chached
        else print(recipeInstance.Name .. " already cached")
            table.insert(productionNode[rkey].Machines, machineProxy)
            mP_trim = nil
        end

        return mP_trim
    end

    function ProductionLine:ChainNew(rkey)
        productionChain[rkey] = {Prev = {}, Next = {}}
    end

    function ProductionLine:ChainSet(rkey)
        for ikeyIn, _ in pairs(recipeTree[rkey].Ingredients) do
            productionChain[rkey].Prev[ikeyIn] = {}
        end
        for ikeyOut, _ in pairs(recipeTree[rkey].Products) do
            productionChain[rkey].Next[ikeyOut] = {}
        end
    end

    function ProductionLine:FlowNodeNew(rkey)
        flowTree[rkey] = {Inflows = {}, Outflows = {}}
    end

    function ProductionLine:FlowNodeSet(throughputNode, recipeNode, isInflow, clock)
        local iName, iAmount = throughputNode.Name, throughputNode.Amount
        local ikey, rkey = String.KeyGenerator(iName), String.KeyGenerator(recipeNode.Name)
        
        if isInflow then isInflow = "Inflows" else isInflow = "Outflows" end

        flowTree[rkey][isInflow][ikey] = {Name = iName, TPM_s = iAmount / recipeNode.Duration, TPM_a = iAmount / recipeNode.Duration * clock, ProductionNode = productionNode[rkey]}
    end

    function ProductionLine:ChainPrint()
       print("\n * Printing Production Chain")
       for rkey, node in pairs(productionNode) do

         print("ProductNode " .. rkey .. " is after:")
         for _, v in pairs(node.Link.Prev) do
           print("- " .. v.Recipe.Name)
         end

         print("ProductNode " .. rkey .. " is before:")
         for _, w in pairs(node.Link.Next) do
           print("- " .. w.Recipe.Name)
         end

       end
    end
 
    function ProductionLine:TerminalSet(ikey, isInbound) -- Terminal class is a placeholder
        if isInbound then isInbound = "Inbound" else isInbound = "Outbound" end
        terminal[isInbound][ikey] = {Recipe = {Name = isInbound .. " Terminal"}}
        return terminal[isInbound][ikey]
    end

    setmetatable(instance, {__index = self})
    if doInitialize then instance:Initialize() end
    if doPrint then instance:ChainPrint() end
    return instance
end

function ProductionNode:New()
    local instance = {}

    setmetatable(instance, {__index = self})
    return instance
end

function ProductionChain:New()
    local instance = {}

    setmetatable(instance, {__index = self})
    return instance
end

function FlowTree:New()
    local instance = {}

    setmetatable(instance, {__index = self})
    return instance
end

function Terminal:New()
    local instance = {}

    setmetatable(instance, {__index = self})
    return instance
end