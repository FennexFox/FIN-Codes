-- dependent on RecipeTree
-- dependent on String

ProductionControl = {Levels = {}}
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
            ProductionControl:SortNodes(1)

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
        pLine:ExploreNodes(pLine.LinkNodes, rTree)
    end

    function ProductionControl:SetTerminal(pLine, terminal)
        terminal:LinkNodes(pLine)
        self.Levels[1] = self.Levels[1] or {}
        for _, v in pairs(terminal.IBT) do self.Levels[1][v.Name] = v end
    end

    function ProductionControl:SortNodes(i)
        local j, nodeCounter = i + 1, 0
        self.Levels[j] = self.Levels[j] or {}

        for _, iNode in pairs(self.Levels[i]) do
            for _, jNode in pairs(iNode.NextNodes) do
                if jNode.Level >= j then break
                elseif jNode.Level > 1 then self.Levels[jNode.Level][jNode.Name] = nil
                end

                jNode.Level, nodeCounter = j, nodeCounter + 1
                self.Levels[j][jNode.Name] = jNode
            end
        end

        if nodeCounter > 0 then
            self:SortNodes(j)
        else
            for k, v in pairs(terminal.OBT) do
                terminal.OBT[k].Level = j
                self.Levels[j][v.Name] = v
            end
        end
    end

    function ProductionControl:Print()
       print("\n... Printing Production Line ...")

    for k, pLevel in ipairs(self.Levels) do
        print("\n  * Production Node Level " .. k)
        if k == 1 then
            for pKey, IBT in pairs(pLevel) do
                local string = ""

                for _, v in pairs(IBT.NextNodes) do string = v.Name .. ", " .. string end
                string = string.sub(string, 1, -3)

                print("    * " .. pKey .. " has " .. IBT.Terminals .. " terminal(s), is before: " .. string)
            end
        elseif k == #self.Levels then
            for pKey, OBT in pairs(pLevel) do
                local string = ""

                for _, v in pairs(OBT.PrevNodes) do string = v.Name .. ", " .. string end
                string = string.sub(string, 1, -3)

                print("    * " .. pKey .. " has " .. OBT.Terminals .. " terminal(s), is after: " .. string)
            end
        else
            for pKey, pNode in pairs(pLevel) do
                local prevString, nextString = "", ""

                for _, v in pairs(pNode.PrevNodes) do prevString = v.Name .. ", " .. prevString end
                for _, w in pairs(pNode.NextNodes) do nextString = w.Name .. ", " .. nextString end

                prevString = string.sub(prevString, 1, -3)
                nextString = string.sub(nextString, 1, -3)

                print("    * " .. pKey .. " has " .. #pNode.Machines .. " machine(s), is")
                print("       after: " .. prevString .. "\n       before: " .. nextString)
            end
        end
    end


       print("\n... End of the Production Line ...\n")
    end

    function ProductionControl:GetThroughputs()
        
    end

    function ProductionControl:UpdateClock(rkey, clock)
        productionLine:UpdateClock(rkey, clock)
    end

    setmetatable(instance, {__index = self})
    if doInitialize then instance:Initialize() end
    if doPrint then instance:Print() end
    return instance
end

function ProductionLine:New()
    local instance = {}

    function ProductionLine:NewNode(machineProxy, recipeInstance, clockSpeed)
        local isNew, rkey, clock = true, String.KeyGenerator(recipeInstance.Name), clockSpeed or 1
        local name = "[PN]_" .. rkey

        if not self[rkey] then
            print("    - New Production Node " .. rkey .. " Found")

            self[rkey] = {
                Name = name,
                Machines = {machineProxy},
                Clock = clock,
                PrevNode = {},
                NextNode = {},
                Inflows = {},
                Outflows = {},
                Level = 1
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
            local recipeInstance = assert(machineProxy:getRecipe(), machineProxy.internalName .. " has no Recipe!")
            if self:NewNode(machineProxy, recipeInstance) then table.insert(recipeInstances, recipeInstance) end
        end

        print("  - " .. #recipeInstances .. " Production Nodes set, Updating RecipeTree")

        recipeTree:NewNodes(recipeInstances)
        return recipeInstances
    end

    function ProductionLine:SetNodes(recipeTree)
        local counter = 0

        for rkey, _ in pairs(self) do
            local rNode =  assert(recipeTree[rkey], "RecipeNode " .. rkey .." not found, cannot expand Production Node!")

            for ikeyIn, _ in pairs(rNode.Inflows) do self[rkey].PrevNodes[ikeyIn] = {} end
            for ikeyOut, _ in pairs(rNode.Outflows) do self[rkey].NextNodes[ikeyOut] = {} end

            counter = counter + 1
        end

        print("  - " .. counter .. " Production Nodes ready to Link")
        return true
    end

    function ProductionLine:ExploreNodes(callback, ...)
        local nodeCounter = 1

        for rkeyThis, _ in pairs(self) do
            for rkeyNext, _ in pairs(self) do
                nodeCounter = nodeCounter + callback(self, rkeyThis, rkeyNext, ...)
            end
        end

        assert(nodeCounter > 1, "No relations between Production Nodes found!")

        print("  - " .. nodeCounter .. " Production Nodes processed")
        return true
    end

    function ProductionLine:LinkNodes(rkeyThis, rkeyNext, recipeTree)
        local itemLinks = 0

        for ikey, flowPush in pairs(recipeTree[rkeyThis].Outflows) do
            for _, flowPull in pairs(recipeTree[rkeyNext].Inflows) do
                if flowPush.Name == flowPull.Name then
                    self[rkeyThis].NextNodes[ikey], self[rkeyThis].Outflows[ikey] = self[rkeyNext], recipeTree[rkeyThis].Outflows[ikey]
                    self[rkeyNext].PrevNodes[ikey], self[rkeyNext].Inflows[ikey] = self[rkeyThis], recipeTree[rkeyNext].Inflows[ikey]
                    itemLinks = itemLinks + 1
                end
            end
        end

        if itemLinks > 0 then
            print("    - " .. itemLinks .. " item(s) linked from " .. self[rkeyThis].Name .. " to " .. self[rkeyNext].Name)
        end

        return math.min(1, itemLinks)
    end

    function ProductionLine:GetThroughputs()
        
    end

    function ProductionLine:UpdateClock(rkey)
        for _, machine in pairs(self[rkey].Machines) do machine.potential = self[rkey].Clock end
    end
               
    setmetatable(instance, {__index = self})
    return instance
end

function Terminal:New() -- Terminal class is a placeholder
    local instance = {IBT = {}, OBT = {}}

    function Terminal:NewNode(ikey, isInbound)
        local isInboundStr = isInbound and "IBT" or "OBT"

        if not self[isInboundStr][ikey] then
            self[isInboundStr][ikey] = {
                Name = "[" .. isInboundStr .. "]_" .. ikey,
                Terminals = 1,
                PrevNode = {},
                NextNode = {},
                Level = isInbound and 1 or 100
            }
        else
            self[isInboundStr][ikey].Terminals = self[isInboundStr][ikey].Terminals + 1
        end

        return self[isInboundStr][ikey]
    end
    
    function Terminal:LinkNodes(productionLine)
        local iCounter, oCounter = 0, 0

        for rkey, pNode in pairs(productionLine) do
            for ikey, pNodePrev in pairs(pNode.PrevNodes) do
                if not pNodePrev.Machines then
                  productionLine[rkey].PrevNodes[ikey] = self:NewNode(ikey, true)
                  table.insert(self.IBT[ikey].NextNodes, productionLine[rkey])
                  iCounter = iCounter + 1
                end
            end
            for ikey, pNodeNext in pairs(pNode.NextNodes) do
                if not pNodeNext.Machines then
                  productionLine[rkey].NextNodes[ikey] = self:NewNode(ikey, nil)
                  table.insert(self.OBT[ikey].PrevNodes, productionLine[rkey])
                  oCounter = oCounter + 1
                end
            end
        end

        print("\n  - Production Nodes Linked: " .. iCounter .. " IBT(s) and " .. oCounter .. " OBT(s) set") return true
    end

    setmetatable(instance, {__index = self})
    return instance
end