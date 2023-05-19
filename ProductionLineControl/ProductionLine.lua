-- dependent on RecipeTree
-- dependent on String

ProductionLine, ProductionChain, FlowTree, Terminal = {}, {}, {}, {}

function ProductionLine:New(doInitialize, doPrint) -- each entry of ProductionLine is ProductionNode
    local instance, recipeTree, productionChain, flowTree, terminal = {}, {}, {}, {}, {}
    recipeTree = RecipeTree:New() -- This is a clone of RecipeTree from Central DB; should be changed to Sync()
    productionChain, flowTree, terminal = ProductionChain:New(), FlowTree:New(), Terminal:New()

    function ProductionLine:Initialize()
        --recipeTree = ProductionLine:GetRecipeTree()
        local machineIDs = component.findComponent(findClass("Manufacturer"))

        if #machineIDs == 0 then
            error("No Manufacturer Found!")
        else
            print("\n... Production Line of " .. #machineIDs .. " Machines Initializing ...\n")

            ProductionLine:NewNodes(machineIDs)
            ProductionLine:NewAuxNodes()
            ProductionLine:LinkNodes()

            print("\n... Production Line of " .. #machineIDs .. " Machines Initialized ...\n")

            return true
        end 
    end

    function ProductionLine:NewNode(machineProxy, recipeInstance)
        local isNew, rkey = true, String.KeyGenerator(recipeInstance.Name)
        local name = "[PN]_" .. rkey

        if not self[rkey] then
            print("New Production Node " .. rkey .. " Found")
            self[rkey] = {Name = name, Machines = {machineProxy}, Clock = 1, Link = {}, Flow = flowTree[rkey], Recipe = {}}
        else
            table.insert(self[rkey].Machines, machineProxy)
            isNew = false
        end

        return isNew, counter
    end

    function ProductionLine:NewNodes(machineIDs)
        local recipeInstances = {}
        local counter = 0
        local machineProxies = component.proxy(machineIDs)

        for _, machineProxy in pairs(machineProxies) do
            local status, recipeInstance = pcall(machineProxy.getRecipe, machineProxy)
            if not status then error(machineProxy.internalName .. " has no Recipe!")
            elseif ProductionLine:NewNode(machineProxy, recipeInstance) then
                table.insert(recipeInstances, recipeInstance)
                counter = counter + 1
            end
        end

        print(counter .. " Production Node set")
        recipeTree:NewNodes(recipeInstances)
        return true
    end

    function ProductionLine:NewAuxNodes()
        local counter = 0

        for rkey, rNode in pairs(recipeTree) do
            if not rNode then error("RecipeNode " .. rkey .." not set, cannot set Auxiliary Nodes!")
            else
                self[rkey].Recipe = rNode
                productionChain:SetNode(rNode)
                flowTree:SetNode(rNode)
                counter = counter + 1
            end
        end

        print(counter .. " Auxiliary Nodes set")
        return true
    end

    function ProductionLine:LinkNodes()
        local isIsolated, nodesIsoloated, iCounter, oCounter = true, {}, 0, 0

        for rkeyPrev, _ in pairs(recipeTree) do
            for rkeyThis, _ in pairs(recipeTree) do
                productionChain:LinkNodes(rkeyPrev, self[rkeyPrev], rkeyThis, self[rkeyThis], flowTree)
                isIsolated = false
            end
            self[rkeyPrev].Link = productionChain[rkeyPrev]
            if isIsolated then
                table.insert(nodesIsoloated, rkeyPrev)
                isIsolated = true
            end
        end

        for rkey, _ in pairs(recipeTree) do
            for ikey, w in pairs(self[rkey].Link.Prev) do
                if not w.Machines then
                  self[rkey].Link.Prev[ikey] = terminal:SetNode(ikey, true)
                  iCounter = iCounter + 1
                end
            end
            for ikey, w in pairs(self[rkey].Link.Next) do
                if not w.Machines then
                  self[rkey].Link.Next[ikey] = terminal:SetNode(ikey, nil)
                  oCounter = oCounter + 1
                end
            end
        end

        if not #nodesIsoloated == 0 then error(#nodesIsoloated .. " Isolated Node(s) Found")
        else print("Production Nodes Linked: " .. iCounter .. " IBT and " .. oCounter .. " OBT set") return true
        end
    end

    function ProductionLine:Print()
       print("\n... Printing Production Chain ...\n")

       for rkey, _ in pairs(recipeTree) do
         local pNode, prevString, nextString = self[rkey], "", ""

         for _, v in pairs(self[rkey].Link.Prev) do prevString = v.Name .. ", " .. prevString end
         for _, w in pairs(self[rkey].Link.Next) do nextString = w.Name .. ", " .. nextString end

         prevString = string.sub(prevString, 1, -3)
         nextString = string.sub(nextString, 1, -3)

         print("  - " .. pNode.Name .. " has " .. #pNode.Machines .. " machine(s), is")
         print("   after: " .. prevString .. "\n   before: " .. nextString .. "\n")
       end
       print("\n... End of the Production Chain ...\n")
    end

    setmetatable(instance, {__index = self})
    if doInitialize then instance:Initialize() end
    if doPrint then instance:Print() end
    return instance
end

function ProductionChain:New()
    local instance = {}

    function ProductionChain:SetNode(recipeNode)
        local isNew, rkey = false, string.sub(recipeNode.Name, 6, -1)

        if not self[rkey] then
            self[rkey] = {Prev = {}, Next = {}}
            isNew = true
        end

        for ikeyIn, _ in pairs(recipeNode.ThroughputMatrix.Inflows) do self[rkey].Prev[ikeyIn] = {} end
        for ikeyOut, _ in pairs(recipeNode.ThroughputMatrix.Outflows) do self[rkey].Next[ikeyOut] = {} end

        return isNew
    end

    function ProductionChain:LinkNodes(prevKey, prevNode, thisKey, thisNode, fTree)
        local isLinked = false
        for ikeyPush, flowPush in pairs(fTree[prevKey].Outflows) do
            for ikeyPull, flowPull in pairs(fTree[thisKey].Inflows) do
                if flowPush.Name == flowPull.Name then -- I know, ikeyPush and ikeyPull are same, but I do this for easy understanding
                    self[prevKey].Next[ikeyPush] = thisNode
                    self[thisKey].Prev[ikeyPull] = prevNode
                    isLinked = true
                end
            end
        end

        return isLinked
    end
           
    setmetatable(instance, {__index = self})
    return instance
end

function FlowTree:New()
    local instance = {}

    function FlowTree:SetNode(recipeNode)
        local isNew, rkey = false, string.sub(recipeNode.Name, 6, -1)

        if not self[rkey] then
            self[rkey] = {Inflows = {}, Outflows = {}}
            isNew = true
        end

        for direction, throughputs in pairs(recipeNode.ThroughputMatrix) do
            for _, throughput in pairs(throughputs) do
                local iName, iAmount = throughput.Name, throughput.Amount
                local ikey, throughputPerMin = String.KeyGenerator(iName), iAmount/recipeNode.Duration
                

                self[rkey][direction][ikey] = {Name = iName, TPM_s = throughputPerMin, TPM_a = throughputPerMin * 1} -- 1 is supposed to be ClockSpeed
            end
        end

        return isNew
    end
    
    setmetatable(instance, {__index = self})
    return instance
end

function Terminal:New()
    local instance = {IBT = {}, OBT = {}}

    function Terminal:SetNode(ikey, isInbound) -- Terminal class is a placeholder
        if isInbound then isInbound = "IBT" else isInbound = "OBT" end

        self[isInbound][ikey] = {Name = "[" .. isInbound .. "]_" .. ikey}
        return self[isInbound][ikey]
    end

    function Terminal:LinkNode()
    end

    setmetatable(instance, {__index = self})
    return instance
end