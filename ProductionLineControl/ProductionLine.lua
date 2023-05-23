-- dependent on RecipeTree
-- dependent on String

ProductionControl = {}
ProductionLine, ProductionChain, FlowTree, Terminal = {}, {}, {}, {}

function ProductionControl:New(doInitialize, doPrint)
    local instance = {}
    local recipeTree, productionLine, productionChain, flowTree, terminal = {}, {}, {}, {}, {} -- these are private fields, shall not be directly referenced
    recipeTree = RecipeTree:New() -- This is a clone of RecipeTree from Central DB; should be changed to Fetch()
    productionLine, productionChain, flowTree, terminal = ProductionLine:New(), ProductionChain:New(), FlowTree:New(), Terminal:New()

    function ProductionControl:Initialize()
        local machineIDs = component.findComponent(findClass("Manufacturer"))

        if #machineIDs == 0 then error("Production Line not Initialized: No Machines Found!")
        else
            print("\n... Production Line of " .. #machineIDs .. " Machines Initializing ...\n")

            ProductionControl:NewNodes(productionLine, recipeTree, machineIDs)
            ProductionControl:SetNodes(productionLine, recipeTree, productionChain, flowTree)
            ProductionControl:LinkNodes(productionLine, productionChain, flowTree)
            ProductionControl:SetTerminal(productionLine, terminal)

            print("\n... Production Line of " .. #machineIDs .. " Machines Initialized ...\n")
        end

        return true
    end

    function  ProductionControl:NewNodes(pLine, rTree, machineIDs)
        pLine:NewNodes(machineIDs, rTree)
    end

    function ProductionControl:SetNodes(pLine, rTree, pChain, fTree)
        pLine:SetNodes(rTree, pChain, fTree)
    end

    function ProductionControl:LinkNodes(pLine, pChain, fTree)
        pLine:LinkNodes(pChain, fTree)
    end

    function ProductionControl:SetTerminal(pLine, logisticsTerminal)
        logisticsTerminal:LinkNodes(pLine)
    end

    function ProductionControl:Print()
       print("\n... Printing Production Chain ...\n")

       for _, pNode in pairs(productionLine) do
         local prevString, nextString = "", ""

         for _, v in pairs(pNode.Link.Prev) do prevString = v.Name .. ", " .. prevString end
         for _, w in pairs(pNode.Link.Next) do nextString = w.Name .. ", " .. nextString end

         prevString = string.sub(prevString, 1, -3)
         nextString = string.sub(nextString, 1, -3)

         print("  - " .. pNode.Name .. " has " .. #pNode.Machines .. " machine(s), is")
         print("   after: " .. prevString .. "\n   before: " .. nextString .. "\n")
       end
       print("... End of the Production Chain ...\n")
    end

    function ProductionControl:SetClock(rkey, clock)
        productionLine:SetClock(rkey, clock)
        flowTree:SetClock(rkey, clock)
    end

    setmetatable(instance, {__index = self})
    if doInitialize then instance:Initialize() end
    if doPrint then instance:Print() end
    return instance
end

function ProductionLine:New()
    local instance = {}

    function ProductionLine:NewNode(machineProxy, recipeInstance)
        local isNew, rkey = true, String.KeyGenerator(recipeInstance.Name)
        local name = "[PN]_" .. rkey

        if not self[rkey] then
            print("    - New Production Node " .. rkey .. " Found")

            self[rkey] = {
                Name = name,
                Machines = {machineProxy},
                Clock = 1,
                Link = {},
                Flow = {},
            }
        else
            table.insert(self[rkey].Machines, machineProxy)
            isNew = false
        end

        return isNew
    end

    function ProductionLine:NewNodes(machineIDs, recipeTree)
        local recipeInstances, machineProxies = {}, component.proxy(machineIDs)

        print("  - Scaning " .. #machineIDs .. " Machines to set Production Nodes")

        for _, machineProxy in pairs(machineProxies) do
            local status, recipeInstance = pcall(machineProxy.getRecipe, machineProxy)
            if not status then error(machineProxy.internalName .. " has no Recipe!")
            elseif self:NewNode(machineProxy, recipeInstance) then
                table.insert(recipeInstances, recipeInstance)
            end
        end

        print("  - " .. #recipeInstances .. " Production Nodes set")

        recipeTree:NewNodes(recipeInstances)
        return recipeInstances
    end

    function ProductionLine:SetNodes(recipeTree, productionChain, flowTree)
        local counter = 0

        for rkey, _ in pairs(self) do
            if not recipeTree[rkey] then error("RecipeNode " .. rkey .." not found, cannot expand Production Node!")
            else
                local rNode = recipeTree[rkey]
                productionChain:SetNode(rNode)
                flowTree:SetNode(rNode)
                counter = counter + 1
            end
        end

        print("  - " .. counter .. " Production Nodes expanded")
        return true
    end

    function ProductionLine:LinkNodes(pChain, fTree)
        for rkeyPrev, _ in pairs(fTree) do
            for rkeyThis, _ in pairs(fTree) do
                pChain:LinkNodes(rkeyPrev, rkeyThis, self, fTree)
            end
            self[rkeyPrev].Link, self[rkeyPrev].Flow = pChain[rkeyPrev], fTree[rkeyPrev]
        end
    end

    function ProductionLine:SetClock(rkey, clock)
        self[rkey].Clock = clock
        for _, machine in pairs(self[rkey].Machines) do machine.potential = clock end
    end
               
    setmetatable(instance, {__index = self})
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

    function ProductionChain:LinkNodes(prevKey, thisKey, pLine, fTree)
        local isLinked, counter = false, 0
        for ikey, flowPush in pairs(fTree[prevKey].Outflows) do
            for _, flowPull in pairs(fTree[thisKey].Inflows) do
                if flowPush.Name == flowPull.Name then
                    self[prevKey].Next[ikey] = pLine[thisKey]
                    self[thisKey].Prev[ikey] = pLine[prevKey]
                    isLinked, counter = true, counter + 1
                end
            end
        end

        if isLinked then print("    - " .. counter .. " Linkage from " .. pLine[prevKey].Name .. " to " .. pLine[thisKey].Name .. " set") end
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

    function FlowTree:SetClock(rkey, clock)
        for _, d in pairs(self[rkey]) do
            for _, i in pairs(d) do
                i.TPM_a = i.TPM_s * clock
            end
        end
    end

    function FlowTree:UpdateClock(rkey, pLine)
        local clock = pLine[rkey].Clock
        self.SetClock(rkey, clock)
    end

    setmetatable(instance, {__index = self})
    return instance
end

function Terminal:New() -- Terminal class is a placeholder
    local instance = {IBT = {}, OBT = {}}

    function Terminal:SetNode(ikey, isInbound)
        if isInbound then isInbound = "IBT" else isInbound = "OBT" end

        self[isInbound][ikey] = {Name = "[" .. isInbound .. "]_" .. ikey}
        return self[isInbound][ikey]
    end

    function Terminal:LinkNodes(productionLine)
        local iCounter, oCounter = 0, 0

        for rkey, v in pairs(productionLine) do
            for ikey, w in pairs(v.Link.Prev) do
                if not w.Machines then
                  productionLine[rkey].Link.Prev[ikey] = self:SetNode(ikey, true)
                  iCounter = iCounter + 1
                end
            end
            for ikey, w in pairs(v.Link.Next) do
                if not w.Machines then
                  productionLine[rkey].Link.Next[ikey] = self:SetNode(ikey, nil)
                  oCounter = oCounter + 1
                end
            end
        end

        print("\n  - Production Nodes Linked: " .. iCounter .. " IBT and " .. oCounter .. " OBT set") return true
    end

    setmetatable(instance, {__index = self})
    return instance
end

A = ProductionControl:New(true, true)