-- dependent on RecipeTree
-- dependent on String

ProductionControl = {}
ProductionLine, Terminal = {}, {}

function ProductionControl:New(doInitialize, doPrint)
    local instance = {}
    local recipeTree, productionLine, terminal = {}, {}, {} -- these are private fields, shall not be directly referenced
    recipeTree = RecipeTree:New() -- This is a clone of RecipeTree from Central DB; should be changed to Fetch()
    productionLine, terminal = ProductionLine:New(), Terminal:New()

    function ProductionControl:Initialize()
        local machineIDs = component.findComponent(findClass("Manufacturer"))

        if #machineIDs == 0 then error("Production Line not Initialized: No Machines Found!")
        else
            print("\n... Production Line of " .. #machineIDs .. " Machines Initializing ...\n")

            ProductionControl:NewNodes(productionLine, recipeTree, machineIDs)
            ProductionControl:SetNodes(productionLine, recipeTree)
            ProductionControl:LinkNodes(productionLine, recipeTree)
            ProductionControl:SetTerminal(productionLine, terminal)

            print("\n... Production Line of " .. #machineIDs .. " Machines Initialized ...\n")
        end

        return true
    end

    function  ProductionControl:NewNodes(pLine, rTree, machineIDs)
        pLine:NewNodes(machineIDs, rTree)
    end

    function ProductionControl:SetNodes(pLine, rTree)
        pLine:SetNodes(rTree)
    end

    function ProductionControl:LinkNodes(pLine, rTree)
        pLine:LinkNodes(rTree)
    end

    function ProductionControl:SetTerminal(pLine, logisticsTerminal)
        logisticsTerminal:LinkNodes(pLine)
    end

    function ProductionControl:Print()
       print("\n... Printing Production Line ...\n")

       for _, pNode in pairs(productionLine) do
         local prevString, nextString = "", ""

         for _, v in pairs(pNode.Prev) do prevString = v.Name .. ", " .. prevString end
         for _, w in pairs(pNode.Next) do nextString = w.Name .. ", " .. nextString end

         prevString = string.sub(prevString, 1, -3)
         nextString = string.sub(nextString, 1, -3)

         print("  * " .. pNode.Name .. " has " .. #pNode.Machines .. " machine(s), is")
         print("   after: " .. prevString .. "\n   before: " .. nextString)
       end
       print("\n... End of the Production Line ...\n")
    end

    function ProductionControl:SetClock(rkey, clock)
        productionLine:SetClock(rkey, clock)
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
                Prev = {},
                Next = {},
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

        print("  - " .. #recipeInstances .. " Production Nodes set, Updating RecipeTree")

        recipeTree:NewNodes(recipeInstances)
        return recipeInstances
    end

    function ProductionLine:SetNodes(recipeTree)
        local counter = 0

        for rkey, _ in pairs(self) do
            local rNode =  assert(recipeTree[rkey], "RecipeNode " .. rkey .." not found, cannot expand Production Node!")

            for ikeyIn, _ in pairs(rNode.Inflows) do self[rkey].Prev[ikeyIn] = {} end
            for ikeyOut, _ in pairs(rNode.Outflows) do self[rkey].Next[ikeyOut] = {} end

            counter = counter + 1
        end

        print("  - " .. counter .. " Production Nodes ready to Link")
        return true
    end

    function ProductionLine:LinkNodes(rTree, pChain)
        local isLinked, counter, counters = false, 0, 0

        for rkeyThis, _ in pairs(rTree) do
            for rkeyNext, _ in pairs(rTree) do
                for ikey, flowPush in pairs(rTree[rkeyThis].Outflows) do
                    for _, flowPull in pairs(rTree[rkeyNext].Inflows) do
                        if flowPush.Name == flowPull.Name then
                            self[rkeyThis].Next[ikey] = self[rkeyNext]
                            self[rkeyNext].Prev[ikey] = self[rkeyThis]
                            isLinked, counter = true, counter + 1
                        end
                    end
                end
                
                if isLinked then
                    print("    - " .. counter .. " Linkage from " .. self[rkeyThis].Name .. " to " .. self[rkeyNext].Name .. " set")
                    isLinked, counters = false, counters + counter
                    counter = 0
                end

            end
        end

        return counters
    end

    function ProductionLine:SetClock(rkey, clock)
        self[rkey].Clock = clock
        self:UpdateClock(rkey, clock)
    end

    function ProductionLine:UpdateClock(rkey, clock)
        for _, machine in pairs(self[rkey].Machines) do machine.potential = clock end
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

        for rkey, pNode in pairs(productionLine) do
            for ikey, pNodePrev in pairs(pNode.Prev) do
                if not pNodePrev.Machines then
                  productionLine[rkey].Prev[ikey] = self:SetNode(ikey, true)
                  iCounter = iCounter + 1
                end
            end
            for ikey, pNodeNext in pairs(pNode.Next) do
                if not pNodeNext.Machines then
                  productionLine[rkey].Next[ikey] = self:SetNode(ikey, nil)
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