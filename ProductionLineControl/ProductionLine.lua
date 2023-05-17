-- dependent on RecipeTree
-- dependent on String

ProductionLine = {}

function ProductionLine:New(doInitialize, doPrint) -- each entry of ProductionLine is ProductionNode
    local instance, recipeTree = {}, {}
    local productionChain, flowTree, terminal = {}, {}, {} -- these are private classes, and they have only one instance, so also their own instances
    recipeTree = RecipeTree:New() -- This is a clone of RecipeTree from Central DB

    function ProductionLine:Initialize()
        --recipeTree = ProductionLine:GetRecipeTree()
        local machineIDs = component.findComponent(findClass("Manufacturer"))

        if #machineIDs == 0 then
            error("No Manufacturer Found!")
        else
            ProductionLine:CacheNodes(machineIDs)
            ProductionLine:LinkNodes()
            print("Production Line Initialized") return true
        end 
    end

    function ProductionLine:CacheNodes(machineIDs)
        local machineProxies_trim, counter = {}, 0
        local machineProxies = component.proxy(machineIDs)

        for _, v in pairs(machineProxies) do
            local status, recipeInstance = pcall(v.getRecipe, v)
            if not status then error(v.internalName .. " has no Recipe!")
            else 
                table.insert(machineProxies_trim, ProductionLine:NodeNew(v, recipeInstance))
                counter = counter + 1
            end
        end

        print(counter .. " Production Nodes found, cacheing Recipe Nodes")
        recipeTree:Cache(machineProxies_trim)

        for rkey, pNode in pairs(self) do
            if not recipeTree[rkey] then error("RecipeNode " .. rkey .." not set, abort linking!")
            else
                local recipeNode = recipeTree[rkey]

                pNode.Recipe = recipeNode
                if not productionChain[rkey] then productionChain:NewNode(rkey) end
                if not flowTree[rkey] then flowTree:NewNode(rkey) end

                productionChain:SetNode(recipeTree, rkey)
                for _, i in pairs(recipeNode.Ingredients) do
                    flowTree:SetNode(pNode, recipeNode, i, 1)
                end
                for _, p in pairs(recipeNode.Products) do
                    flowTree:SetNode(pNode, recipeNode, p, 1)
                end
            end
        end

        print("ProductionNode Cacheing Complete") return true
    end

    function ProductionLine:LinkNodes()
        for rkeyPrev, nodePrev in pairs(self) do
            for rkeyThis, _ in pairs(self) do
                for ikeyPush, flowPush in pairs(flowTree[rkeyPrev].Outflows) do
                    for ikeyPull, flowPull in pairs(flowTree[rkeyThis].Inflows) do
                        if flowPush.Name == flowPull.Name then -- I know, ikeyPush and ikeyPull are same, but I do this for easy understanding
                            productionChain[rkeyPrev].Next[ikeyPush] = self[rkeyThis]
                            productionChain[rkeyThis].Prev[ikeyPull] = self[rkeyPrev]
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

        if not self[rkey] then print(recipeInstance.Name .. " is newly added")
            ProductionLine:ChainNew(rkey)
            ProductionLine:FlowNodeNew(rkey)
            self[rkey] = {Machines = {machineProxy}, Clock = 1, Link = {}, Flow = flowTree[rkey], Recipe = {}} -- recipeTree is not yet chached
        else print(recipeInstance.Name .. " already cached")
            table.insert(self[rkey].Machines, machineProxy)
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

        flowTree[rkey][isInflow][ikey] = {Name = iName, TPM_s = iAmount / recipeNode.Duration, TPM_a = iAmount / recipeNode.Duration * clock, ProductionNode = self[rkey]}
    end

    function ProductionLine:ChainPrint()
       print("\n * Printing Production Chain")
       for rkey, node in pairs(self) do

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

    function productionChain:New()
        local instanceChain = {}
        function productionChain:NewNode(rkey)
            self[rkey] = {Prev = {}, Next = {}}
        end
    
        function productionChain:SetNode(recipeTree, rkey)
            for ikeyIn, _ in pairs(recipeTree[rkey].Ingredients) do
                self[rkey].Prev[ikeyIn] = {}
            end
            for ikeyOut, _ in pairs(recipeTree[rkey].Products) do
                self[rkey].Next[ikeyOut] = {}
            end
        end
    
        function productionChain:LinkNode()
                    
        end
    
        setmetatable(instanceChain, {__index = self})
        return instanceChain
    end
    
    function flowTree:New()
        local instanceFlowTree = {}
    
        function flowTree:NewNode(rkey)
            self[rkey] = {Inflows = {}, Outflows = {}} 
        end
    
        function flowTree:SetNode(productionNode, recipeNode, throughputNode, clock)
            local iName, iAmount = throughputNode.Name, throughputNode.Amount
            local ikey, rkey, fkey = String.KeyGenerator(iName), String.KeyGenerator(recipeNode.Name), ""
            
            if throughputNode.isIngredient then fkey = "Inflows" else fkey = "Outflows" end
    
            self[rkey][fkey][ikey] = {Name = iName, TPM_s = iAmount / recipeNode.Duration, TPM_a = iAmount / recipeNode.Duration * clock, ProductionNode = productionNode[rkey]}
        end
    
        function flowTree:LinkNode()
            
        end
    
        setmetatable(instanceFlowTree, {__index = self})
        return instanceFlowTree
    end
    
    function terminal:New()
        local instanceTerminal = {Inbound = {}, Outbound = {}}
    
        function terminal:SetNode(ikey, isInbound) -- Terminal class is a placeholder
            if isInbound then isInbound = "Inbound" else isInbound = "Outbound" end
            self[isInbound][ikey] = {Recipe = {Name = isInbound .. " Terminal"}}
            return self[isInbound][ikey]
        end
    
        function terminal:LinkNode()
        end
    
        setmetatable(instanceTerminal, {__index = self})
        return instanceTerminal
    end

    setmetatable(instance, {__index = self})
    if doInitialize then instance:Initialize() end
    if doPrint then instance:ChainPrint() end
    return instance
end