-- dependent on RecipeTree
-- dependent on String
-- dependent on Terminal

ProductionControl, ProductionLine = {Levels = {}}, {}

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

            ProductionControl:InitializeNodes(productionLine, recipeTree, machineIDs)
            ProductionControl:LinkNodes(productionLine, recipeTree)
            ProductionControl:SetTerminal(productionLine, recipeTree, terminal)
            ProductionControl:SortNodes(1)

            print("\n... Production Line of " .. #machineIDs .. " Machines Initialized ...\n")
        end

        return true
    end

    function  ProductionControl:InitializeNodes(pLine, rTree, machineIDs)
        pLine:InitializeNodes(machineIDs, rTree)
    end

    function ProductionControl:LinkNodes(pLine, rTree)
        pLine:ExploreNodes(pLine.LinkNodes, rTree)
    end

    function ProductionControl:SetTerminal(pLine, rTree, terminal)
        terminal:SetTerminal(pLine, rTree)
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

                    print("    * " .. pKey .. " has " .. #IBT.Terminals .. " terminal(s), is before: " .. string)
                end
            elseif k == #self.Levels then
                for pKey, OBT in pairs(pLevel) do
                    local string = ""

                    for _, v in pairs(OBT.PrevNodes) do string = v.Name .. ", " .. string end
                    string = string.sub(string, 1, -3)

                    print("    * " .. pKey .. " has " .. #OBT.Terminals .. " terminal(s), is after: " .. string)
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

    function ProductionControl:UpdateClock(pLine, rkey, clock)
        pLine:UpdateClock(rkey, clock)
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
                PrevNodes = {},
                NextNodes = {},
                Demands = {},
                Supplies = {},
                Level = 1
            }
        else
            table.insert(self[rkey].Machines, machineProxy)
            isNew = false
        end

        return isNew
    end

    function ProductionLine:InitializeNodes(machineIDs, recipeTree)
        local recipeInstances, machineProxies = {}, component.proxy(machineIDs)

        print("  - Scaning " .. #machineIDs .. " Machines to set Production Nodes")

        for _, machineProxy in pairs(machineProxies) do
            local recipeInstance = assert(machineProxy:getRecipe(), machineProxy.internalName .. " has no Recipe!")
            if self:NewNode(machineProxy, recipeInstance) then table.insert(recipeInstances, recipeInstance) end
        end

        print("  - " .. #recipeInstances .. " Production Nodes initialized, Updating RecipeTree")

        recipeTree:NewNodes(recipeInstances)
        return recipeInstances
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

        for ikey1, flowPush in pairs(recipeTree[rkeyThis].Outflows) do
            for ikey2, flowPull in pairs(recipeTree[rkeyNext].Inflows) do
                if ikey1 == ikey2 then
                    self[rkeyThis].NextNodes[rkeyNext], self[rkeyThis].Supplies[rkeyNext] = self[rkeyNext], flowPush
                    self:UpdateThroughput(rkeyThis)

                    self[rkeyNext].PrevNodes[rkeyThis], self[rkeyNext].Demands[rkeyThis] = self[rkeyThis], flowPull
                    self:UpdateThroughput(rkeyNext)

                    itemLinks = itemLinks + 1
                end
            end
        end

        if itemLinks > 0 then
            print("    - " .. itemLinks .. " item(s) linked from " .. self[rkeyThis].Name .. " to " .. self[rkeyNext].Name)
        end

        return math.min(1, itemLinks)
    end

    function ProductionLine:UpdateThroughput(rkey)
        local multiplier1, multiplier2 = #self[rkey].Machines, self[rkey].Clock

        for _, demand in pairs(self[rkey].Demands) do
            demand.Amount = demand.Amount * multiplier1
            demand.Duration = demand.Duration / multiplier2

            if demand.Name then
                demand.Key = String.KeyGenerator(demand.Name)
                demand.Name = nil
            end
        end
        for _, supply in pairs(self[rkey].Supplies) do
            supply.Amount = supply.Amount * multiplier1
            supply.Duration = supply.Duration / multiplier2
            if supply.Name then
                supply.Key = String.KeyGenerator(supply.Name)
                supply.Name = nil
            end
        end
    end

    function ProductionLine:GetSurplusPerMin(rkey, ikey)
        local push, pull = self[rkey].Supplies[ikey], self:GetDemandPerMin(ikey)
        push = push.Amount / push.Duration

        return {Push = push, Pull = pull, Surplus = push - pull, ClockT = pull / push}
    end

    function ProductionLine:GetLeastClockT(rkey)
        local clockT = 0

        for ikey, _ in pairs(self[rkey].Supplies) do
            local clockI = self:GetSurplusPerMin(rkey, ikey).ClockT
            clockT = math.max(clockT, clockI)
        end

        return clockT
    end

    function ProductionLine:GetDemandPerMin(ikey)
        local DPM = 0
        for _, pNode in pairs(self) do
            for _, demand in pairs(pNode.Demands) do
                if demand.Key == ikey then
                    DPM = DPM + demand.Amount / demand.Duration
                end
            end
        end

        return DPM
    end

    function ProductionLine:isInChain(ikey, isInflow)
        local direction = isInflow and "Demands" or "Supplies"

        for _, pNode in pairs(self) do
            for _, throughput in pairs(pNode[direction]) do
                if throughput.Key == ikey then return true end
            end
        end
    end

    function ProductionLine:UpdateClock(rkey)
        for _, machine in pairs(self[rkey].Machines) do machine.potential = self[rkey].Clock end
    end
               
    setmetatable(instance, {__index = self})
    return instance
end