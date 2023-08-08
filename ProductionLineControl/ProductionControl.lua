-- dependent on RecipeTree
-- dependent on String
-- dependent on Terminal

ProductionControl, ProductionLine = {Levels = {}}, {}

function ProductionControl:New(doInitialize, doPrint)
    local instance, privateFields = {}, {}
    setmetatable(instance, {__index = self})

    privateFields.rTree = RecipeTree:New() -- This is a clone of RecipeTree from Central DB; should be changed to Fetch()
    privateFields.pLines = ProductionLine:New(privateFields.rTree)
    privateFields.pTerminals = Terminals:New()

    function ProductionControl:Initialize()
        local machineIDs = component.findComponent(findClass("Manufacturer"))

        if #machineIDs == 0 then error("Production Line not Initialized: No Machines Found!")
        else
            print("\n... Production Line of " .. #machineIDs .. " Machines Initializing ...\n")

            ProductionControl:InitializeNodes(machineIDs)
            ProductionControl:LinkNodes()
            ProductionControl:SetTerminals()
            ProductionControl:SortNodes(1)
            ProductionControl:IterateAllNodes(self.SetCounters)

            print("\n... Production Line of " .. #machineIDs .. " Machines Initialized ...\n")
        end

        return true
    end

    function  ProductionControl:InitializeNodes(machineIDs)
        privateFields.pLines:InitializeNodes(machineIDs, privateFields.rTree)
    end

    function ProductionControl:LinkNodes()
        local callback = privateFields.pLines.LinkThroughputs
        privateFields.pLines:IterateNodesPair(callback)
    end

    function ProductionControl:SetTerminals()
        privateFields.pTerminals:SetProductionTerminal(privateFields.pLines, privateFields.rTree)
        self.Levels[1] = self.Levels[1] or {}

        for type, terminals in pairs(privateFields.pTerminals) do
            local isInbound = (type == "IBT")
            for ikey, terminalNode in pairs(terminals) do
                local name, flow = terminalNode.Name, isInbound and {"NextNodes", "Demands"} or {"PrevNodes", "Supplies"}
                self:IterateInLine(terminalNode, isInbound, instance.SetTags, name)
                if isInbound then self.Levels[1][ikey] = terminalNode end
                for pKey, _ in pairs(terminalNode[flow[1]]) do
                    privateFields.pLines:LinkNodes(pKey, terminalNode, isInbound)
                    privateFields.pLines[pKey][flow[2]][type][ikey] = {}
                end
            end
        end
    end

    function ProductionControl:SortNodes(i)
        local j, isLast = i + 1, true
        self.Levels[j] = self.Levels[j] or {}

        for _, iNode in pairs(self.Levels[i]) do
            for _, jNode in pairs(iNode.NextNodes) do
                local nodeType, _ = String.NameParser(jNode.Name)
                if nodeType == "OBT" then break
                elseif nodeType == "IBT" then error("Production Line not Sorted: IBT at Level " .. j .. "!")
                end

                self.Levels[j][jNode.Name] = jNode
                isLast = false
            end
        end

        if not isLast then
            self:SortNodes(j)
        else
            for _, outboundT in pairs(privateFields.pTerminals.OBT) do self.Levels[j][outboundT.Name] = outboundT end
        end
    end

    function ProductionControl:IterateInLine(nodeI, isIncremental, callback, ...)
        local direction = isIncremental and "NextNodes" or "PrevNodes"
        local nodeType, keyI = String.NameParser(nodeI.Name)

        callback(nodeI.NodeTree, keyI, nodeType, ...)

        for _, nodeJ in pairs(nodeI[direction]) do
            self:IterateInLine(nodeJ, isIncremental, callback, ...)
        end
    end

    function ProductionControl:IterateAllNodes(callback, ...)
        for _, nodes in ipairs(self.Levels) do
            for _, node in pairs(nodes) do
                local nodeType, key = String.NameParser(node.Name)

                callback(node.NodeTree, key, nodeType, ...)
            end
        end
    end

    function ProductionControl.SetTags(nodeTree, key, nodeType, tag)
        nodeTree.SetTags(nodeTree, key, tag, nodeType)
    end

    function ProductionControl.SetCounters(nodeTree, key, nodeType, ...)
        nodeTree.SetCounters(nodeTree, key, nodeType)
    end

    function ProductionControl.UpdateThroughput(nodeTree, key, nodeType)
        nodeTree.UpdateThroughput(nodeTree, key, nodeType)
    end
--[[
    function ProductionControl.ReAllocateResource(itemToReAllocate, linesToFix, linesToProcess)
        local linesTags = {}

        for _, v in pairs(linesToFix) do linesTags[v.Name] = {} end
        for _, v in pairs(linesToProcess) do linesTags[v.Name] = {} end
       
    end
]]--

    function ProductionControl:Print()
       print("\n... Printing Production Line ...")

        for level, sortedNodes in ipairs(self.Levels) do
            print("\n  * Production Node Level " .. level)
            if level == 1 then
                for key, IBT in pairs(sortedNodes) do
                    local string = ""

                    for _, v in pairs(IBT.NextNodes) do string = v.Name .. ", " .. string end
                    string = string:gsub("(.+),%s*", "%1")

                    print("    * " .. key .. " has " .. #IBT.Stations .. " terminal(s), is before: " .. string)
                end
            elseif level == #self.Levels then
                for key, OBT in pairs(sortedNodes) do
                    local string = ""

                    for _, v in pairs(OBT.PrevNodes) do string = v.Name .. ", " .. string end
                    string = string:gsub("(.+),%s*", "%1")

                    print("    * " .. key .. " has " .. #OBT.Stations .. " terminal(s), is after: " .. string)
                end
            else
                for key, pNode in pairs(sortedNodes) do
                    local prevString, nextString = "", ""

                    for _, v in pairs(pNode.PrevNodes) do prevString = v.Name .. ", " .. prevString end
                    for _, w in pairs(pNode.NextNodes) do nextString = w.Name .. ", " .. nextString end

                    prevString = prevString:gsub("(.+),%s*", "%1")
                    nextString = nextString:gsub("(.+),%s*", "%1")

                    print("    * " .. key .. " has " .. #pNode.Machines .. " machine(s), is")
                    print("       after: " .. prevString .. "\n       before: " .. nextString)
                end
            end
        end

       print("\n... End of the Production Line ...\n")
    end

    function ProductionControl:Main()
        while true do
            event.pull(1)

            local itemLevels = privateFields.pTerminals:GetItemLevels()

            for ikey, iLevel in pairs(itemLevels.IBT) do
                local timeToDeplete = iLevel.StockAmount / iLevel.ThroughputPerMin
                if timeToDeplete > 1 then break end
                self:IterateInLine(privateFields.pTerminals.IBT[ikey], true, privateFields.pLines.SetClockComparedTo, privateFields.pLines, timeToDeplete^2, true)
            end
--[[
            for ikey, iLevel in pairs(itemLevels.OBT) do
                local timeToFull = (iLevel.CapacityAmount - iLevel.StockAmount) / iLevel.ThroughputPerMin
                
                self:IterateInLine(terminals.OBT[ikey], false, productionLine.SetClock2, productionLine, timeToFull)
            end
]]--
            for rkey, _ in pairs(privateFields.pLines) do privateFields.pLines:UpdateClock(rkey) end
        end
    end

    function ProductionControl:UpdateClock(pLine, rkey, clock)
        pLine:UpdateClock(rkey, clock)
    end

    if doInitialize then instance:Initialize() end
    if doPrint then instance:Print() end
    return instance, privateFields.pTerminals
end

function ProductionLine:New(reciepeTree)
    local instance, privateFields = {}, {}
    setmetatable(instance, {__index = self})

    privateFields.rTree = reciepeTree

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
                Demands = {IBT = {}},
                Supplies = {OBT = {}},
                Tags = {},
                NodeTree = self,
            }
        else
            table.insert(self[rkey].Machines, machineProxy)
            isNew = false
        end

        machineProxy.nick = string.gsub(name, "_", " ") .. " " .. string.format("%02d", #self[rkey].Machines)

        return isNew
    end

    function ProductionLine:InitializeNodes(machineIDs)
        local recipeInstances, machineProxies = {}, component.proxy(machineIDs)

        print("  - Scaning " .. #machineIDs .. " Machines to set Production Nodes")

        for _, machineProxy in pairs(machineProxies) do
            local recipeInstance = assert(machineProxy:getRecipe(), machineProxy.internalName .. " has no Recipe!")
            if self:NewNode(machineProxy, recipeInstance) then table.insert(recipeInstances, recipeInstance) end
        end

        print("  - " .. #recipeInstances .. " Production Nodes initialized, Updating RecipeTree")

        privateFields.rTree:NewNodes(recipeInstances)

        return privateFields.rTree
    end

    function ProductionLine:IterateNodesPair(callback, ...)
        local nodeCounter = 1

        for rkeyThis, _ in pairs(self) do
            for rkeyOther, _ in pairs(self) do
                if rkeyThis ~= rkeyOther then
                    nodeCounter = nodeCounter + callback(self, rkeyThis, rkeyOther, ...)
                end
            end
        end

        assert(nodeCounter > 1, "No relations between Production Nodes found!")

        print("  - " .. nodeCounter .. " Production Nodes processed")
        return true
    end
    
    function ProductionLine:SetTags(rkeyI, tag)
        table.insert(self[rkeyI].Tags, tag)
    end

    function ProductionLine:LinkNodes(keyThis, nodeOther, isInflow)
        local nodeType, keyOther1 = String.NameParser(nodeOther.Name)
        local keyOther2 = (nodeType == "PN") and keyOther1 or nodeType
        local flow = isInflow and {"PrevNodes", "Demands"} or {"NextNodes", "Supplies"}

        self[keyThis][flow[1]][keyOther1] = nodeOther
        self[keyThis][flow[2]][keyOther2] = {}
    end

    function ProductionLine:LinkThroughputs(rkeyThis, rkeyNext)
        local itemLinks = 0

        for ikeyPush, flowPush in pairs(privateFields.rTree[rkeyThis].Outflows) do
            for ikeyPull, flowPull in pairs(privateFields.rTree[rkeyNext].Inflows) do
                if ikeyPush == ikeyPull then
                    if itemLinks == 0 then
                        self:LinkNodes(rkeyThis, self[rkeyNext], false)
                        self:LinkNodes(rkeyNext, self[rkeyThis], true)
                    end
                    
                    self[rkeyThis].Supplies[rkeyNext][ikeyPush] = flowPush
                    self[rkeyNext].Demands[rkeyThis][ikeyPull] = flowPull

                    itemLinks = itemLinks + 1
                end
            end
        end

        if itemLinks > 0 then
            print("  - " .. itemLinks .. " item(s) linked from " .. self[rkeyThis].Name .. " to " .. self[rkeyNext].Name)
        end

        return math.min(1, itemLinks)
    end

    function ProductionLine:SetCounters(keyThis)
        local pNode, direction = self[keyThis], {PrevNodes = "Demands", NextNodes = "Supplies"}

        for nodeOthers, throughputs in pairs(direction) do
            local dir3 = nodeOthers == "PrevNodes" and "from" or "to"
            for keyOther, nodeOther in pairs(pNode[nodeOthers]) do
                local nodeType, _ = String.NameParser(nodeOther.Name)
                local from, to = nodeOther, pNode
                if nodeType ~= "PN" then keyOther = nodeType end
                if nodeOthers == "NextNodes" then from, to = to, from end

                for ikey, _ in pairs(pNode[throughputs][keyOther]) do
                    local tCounters = component.findComponent(String.Composer(" ", keyThis, keyOther, ikey))
                    self[keyThis][throughputs][keyOther][ikey].Counters = ThroughputCounter:New(tCounters, from, to, ikey)
                    print("    - " .. pNode.Name .. " got " .. #tCounters .. " " .. ikey .. " counter(s) " .. dir3 .. " " .. nodeOther.Name)
                end
            end
        end
    end

    function ProductionLine:UpdateClock(rkey)
        for _, machine in pairs(self[rkey].Machines) do machine.potential = self[rkey].Clock end
    end

    function ProductionLine:UpdateThroughput(rkey)
        local pNode = self[rkey]
        local multiplier1, multiplier2 = #pNode.Machines, pNode.Clock
        local direction = {Inflows = "Demands", Outflows = "Supplies"}

        for dir1, dir2 in pairs(direction) do
            local recipeThroughput = privateFields.rTree[rkey][dir1]
            for ikey, _ in pairs(pNode[dir2]) do
                self[rkey][dir2][ikey].Amount = recipeThroughput[ikey].Amount * multiplier1
                self[rkey][dir2][ikey].Duration = recipeThroughput[ikey].Duration / multiplier2
            end
        end
    end

    function ProductionLine:GetThroughputMultipliers(pNodeThis, ikeyThis, isIncremental)
        local direction = isIncremental and "Supplies" or "Demands"
        local itemAmounts, throughputMultipliers = {}, {}

        for rkeyNext, tpNexts in pairs(pNodeThis[direction]) do
            for ikeyNext, _ in pairs(tpNexts) do
                local temp = privateFields.rTree:GetThroughputItemPair(rkeyNext, ikeyThis, ikeyNext, isIncremental)
                local multiplier = 60 / temp[rkeyNext]

                itemAmounts[ikeyNext] = itemAmounts[ikeyNext] or {AmountThis = 0, AmountNext = 0}
                itemAmounts[ikeyNext].AmountThis = itemAmounts[ikeyNext].AmountThis + temp[ikeyThis] * multiplier
                itemAmounts[ikeyNext].AmountNext = itemAmounts[ikeyNext].AmountNext + temp[ikeyNext] * multiplier
            end
        end

        for iAmounts, ikey in pairs(itemAmounts) do
            throughputMultipliers[ikey] = iAmounts.AmountNext / iAmounts.AmountThis
        end

        return throughputMultipliers
    end

    function ProductionLine:GetThroughputMultipliersRemote(pNodeStart, pkeyEnd, ikeyStart, ikeyThis, isIncremental)
         
    end

--[[
    function ProductionLine:GetThRatioR(pNodeThis, rTree, isIncremental, ikeyEnd, thRatiosR)
        local pNodesNext = isIncremental and pNodeThis.NextNodes or pNodeThis.PrevNodes
        local throughputsNext = isIncremental and pNodeThis.Supplies or pNodeThis.Demands
        local tpRatiosTemp, ikeyNexts, ikeysOnBoth, thRatioR = {}, {}, {}, 0

        for ikeyNext, _ in thRatiosR do ikeyNexts[ikeyNext] = true end

        for rkeyNext, pNodeNext in pairs(pNodesNext) do
            for ikeyNext, _ in pairs(throughputsNext[rkeyNext]) do
                if not ikeyNexts[ikeyNext] then break
                elseif ikeyNext == ikeyEnd then thRatioR = thRatioR + thRatiosR[ikeyEnd]
                end

                local throughtputRatiosNext = instance:GetThRatioA(pNodeNext, ikeyNext, rTree, isIncremental)
                tpRatiosTemp[ikeyNext] = tpRatiosTemp[ikeyNext] or {}

                for ikeyNextNext, throughputRatioNext in pairs(throughtputRatiosNext) do
                    tpRatiosTemp[ikeyNext][ikeyNextNext] = tpRatiosTemp[ikeyNext][ikeyNextNext] or {0, 0}
                    tpRatiosTemp[ikeyNext][ikeyNextNext][1] = tpRatiosTemp[ikeyNext][ikeyNextNext][1] + throughputRatioNext[1]
                    tpRatiosTemp[ikeyNext][ikeyNextNext][2] = tpRatiosTemp[ikeyNext][ikeyNextNext][2] + throughputRatioNext[2]
                    if ikeyNexts[ikeyNextNext] then ikeysOnBoth[ikeyNextNext] = true end
                end
            end
        end


        for ikeyOnBoth, _ in pairs(ikeysOnBoth) do
            for ikeyNextNext, throughputRatio in pairs(tpRatiosTemp[ikeyOnBoth]) do
                thRatiosR[ikeyNextNext] = thRatiosR[ikeyOnBoth] * throughputRatio[1] / throughputRatio[2]
                tpRatiosTemp[ikeyOnBoth] = nil
            end
        end

        for ikeyNext, throughputRatios in pairs(tpRatiosTemp) do
            for ikeyNextNext, throughputRatio in pairs(throughputRatios) do
                thRatiosR[ikeyNextNext] = thRatiosR[ikeyNext] * throughputRatio[1] / throughputRatio[2]
            end
        end

        for _, pNodeNext in pairs(pNodesNext) do
            local nodeType = String.NameParser(pNodeNext.Name)[1]
            if nodeType ~= "PN" then break end
            thRatioR = thRatioR + instance:GetThRatioR(pNodeNext, rTree, isIncremental, ikeyEnd, thRatiosR)
        end

        return thRatioR
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
                if demand.iKey == ikey then
                    DPM = DPM + demand.Amount / demand.Duration
                end
            end
        end

        return DPM
    end
]]--
    function ProductionLine:isInChain(ikeyC, isInflow)
        local isInChain, direction = false, isInflow and "Demands" or "Supplies"

        for _, pNode in pairs(self) do
            for _, throughputs in pairs(pNode[direction]) do
                for ikeyT, _ in pairs(throughputs) do
                    if ikeyT == ikeyC then isInChain = true end
                end
            end
        end

        return isInChain
    end

    function ProductionLine:SetClockCompare(nodeI, rkeyI, clock, isBigger)
        local setClock = nodeI.Clock
        setClock = isBigger and math.max(setClock, clock) or math.min(setClock, clock)
        
        self[rkeyI].Clock = setClock
    end

    return instance
end