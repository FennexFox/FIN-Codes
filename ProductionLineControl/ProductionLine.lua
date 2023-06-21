-- dependent on RecipeTree
-- dependent on String
-- dependent on Terminal

ProductionControl, ProductionLine = {Levels = {}}, {}

function ProductionControl:New(doInitialize, doPrint)
    local instance = {}
    local recipeTree, productionLine, terminals = {}, {}, {} -- these are private fields, shall not be directly referenced
    recipeTree = RecipeTree:New() -- This is a clone of RecipeTree from Central DB; should be changed to Fetch()
    productionLine, terminals = ProductionLine:New(), Terminal:New()

    function ProductionControl:Initialize()
        local machineIDs = component.findComponent(findClass("Manufacturer"))

        if #machineIDs == 0 then error("Production Line not Initialized: No Machines Found!")
        else
            print("\n... Production Line of " .. #machineIDs .. " Machines Initializing ...\n")

            ProductionControl:InitializeNodes(productionLine, recipeTree, machineIDs)
            ProductionControl:LinkNodes(productionLine, recipeTree)
            ProductionControl:SetTerminals(productionLine, recipeTree, terminals)
            ProductionControl:LinkTerminals(productionLine, terminals)
            ProductionControl:SortNodes(1, terminals)
            ProductionControl:IterateAllNodes(self.SetCounters)

            print("\n... Production Line of " .. #machineIDs .. " Machines Initialized ...\n")
        end

        return true
    end

    function  ProductionControl:InitializeNodes(pLine, rTree, machineIDs)
        pLine:InitializeNodes(machineIDs, rTree)
    end

    function ProductionControl:LinkNodes(pLine, rTree)
        pLine:IterateNodesPair(pLine.LinkThroughputs, rTree)
    end

    function ProductionControl:SetTerminals(pLine, rTree, terminal)
        terminal:SetProductionTerminal(pLine, rTree)
        self.Levels[1] = self.Levels[1] or {}
    end

    function ProductionControl:LinkTerminals(pLine, terminal)
        for isInboundsStr, terminals in pairs(terminal) do
            local isInbound = (isInboundsStr == "IBT")
            for ikey, terminalNode in pairs(terminals) do
                local name, flow = terminalNode.Name, isInbound and {"NextNodes", "Demands"} or {"PrevNodes", "Supplies"}
                self:IterateInLine(terminalNode, isInbound, ProductionControl.SetTags, name)
                if isInbound then self.Levels[1][ikey] = terminalNode end
                for pKey, _ in pairs(terminalNode[flow[1]]) do
                    pLine:LinkNodes(pKey, terminalNode, isInbound)
                    pLine[pKey][flow[2]][isInboundsStr][ikey] = {}
                end
            end
        end
    end

    function ProductionControl:SortNodes(i, terminal)
        local j, isLast = i + 1, true
        self.Levels[j] = self.Levels[j] or {}

        for _, iNode in pairs(self.Levels[i]) do
            for jKey, jNode in pairs(iNode.NextNodes) do
                local type, _ = String.NameParser(jNode.Name)
                if type == "OBT" then break
                elseif type == "IBT" then error("Production Line not Sorted: IBT at Level " .. j .. "!")
                end

                self.Levels[j][jNode.Name] = jNode
                isLast = false
            end
        end

        if not isLast then
            self:SortNodes(j, terminal)
        else
            for _, outboundT in pairs(terminal.OBT) do self.Levels[j][outboundT.Name] = outboundT end
        end
    end

    function ProductionControl:GetNodeTree(type)
        local nodeTree = {}

        if type == "RN" then nodeTree = recipeTree
        elseif type == "PN" then nodeTree = productionLine
        else nodeTree = terminals
        end

        return nodeTree
    end

    function ProductionControl:IterateInLine(nodeI, isIncremental, callback, ...)
        local direction = isIncremental and "NextNodes" or "PrevNodes"
        local type, keyI = String.NameParser(nodeI.Name)
        local nodeTree = self:GetNodeTree(type)

        callback(nodeTree, keyI, type, ...)

        for _, nodeJ in pairs(nodeI[direction]) do
            self:IterateInLine(nodeJ, isIncremental, callback, ...)
        end
    end

    function ProductionControl:IterateAllNodes(callback, ...)
        for _, nodes in ipairs(self.Levels) do
            for _, node in pairs(nodes) do
                local type, key = String.NameParser(node.Name)
                local nodeTree = self:GetNodeTree(type)

                callback(nodeTree, key, type, ...)
            end
        end
    end

    function ProductionControl.SetTags(nodeTree, key, type, tag)
        nodeTree.SetTags(nodeTree, key, tag, type)
    end

    function ProductionControl.SetCounters(nodeTree, key, type, ...)
        nodeTree.SetCounters(nodeTree, key, type)
    end

    function ProductionControl.UpdateThroughput(nodeTree, rkeyI, type)
        nodeTree.UpdateThroughput(nodeTree, rkeyI, type)
    end

    function ProductionControl:Print()
       print("\n... Printing Production Line ...")

        for k, pLevel in ipairs(self.Levels) do
            print("\n  * Production Node Level " .. k)
            if k == 1 then
                for pKey, IBT in pairs(pLevel) do
                    local string = ""

                    for _, v in pairs(IBT.NextNodes) do string = v.Name .. ", " .. string end
                    string = string:gsub("(.+),%s*", "%1")

                    print("    * " .. pKey .. " has " .. #IBT.Stations .. " terminal(s), is before: " .. string)
                end
            elseif k == #self.Levels then
                for pKey, OBT in pairs(pLevel) do
                    local string = ""

                    for _, v in pairs(OBT.PrevNodes) do string = v.Name .. ", " .. string end
                    string = string:gsub("(.+),%s*", "%1")

                    print("    * " .. pKey .. " has " .. #OBT.Stations .. " terminal(s), is after: " .. string)
                end
            else
                for pKey, pNode in pairs(pLevel) do
                    local prevString, nextString = "", ""

                    for _, v in pairs(pNode.PrevNodes) do prevString = v.Name .. ", " .. prevString end
                    for _, w in pairs(pNode.NextNodes) do nextString = w.Name .. ", " .. nextString end

                    prevString = prevString:gsub("(.+),%s*", "%1")
                    nextString = nextString:gsub("(.+),%s*", "%1")

                    print("    * " .. pKey .. " has " .. #pNode.Machines .. " machine(s), is")
                    print("       after: " .. prevString .. "\n       before: " .. nextString)
                end
            end
        end

       print("\n... End of the Production Line ...\n")
    end

    function ProductionControl:Main()
        while true do
            event.pull(1)

            local itemLevels = terminals:GetItemLevels()

            for ikey, iLevel in pairs(itemLevels.IBT) do
                local ratioAmount = math.min(1, iLevel.RatioAmount * 24)
                self:IterateInLine(terminals.IBT[ikey], true, productionLine.SetClock1, productionLine, ratioAmount)
            end

            for ikey, iLevel in pairs(itemLevels.OBT) do
                local ratioAmount, tag = math.max(0.8, iLevel.RatioAmount), "[OBT]_" .. ikey
                if ratioAmount > 0.8 then
                    ratioAmount = 1 - (ratioAmount - 0.8) / 0.2
                elseif ratioAmount < 0.2 then
                    ratioAmount = math.max(2.5, 0.2 / ratioAmount)
                else break
                end
                
                self:IterateInLine(terminals.OBT[ikey], false, productionLine.SetClock2, productionLine, ratioAmount, {tag})
            end

            for rkey, _ in pairs(productionLine) do productionLine:UpdateClock(rkey) end
        end
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
                Demands = {IBT = {}},
                Supplies = {OBT = {}},
                Tags = {},
            }
        else
            table.insert(self[rkey].Machines, machineProxy)
            isNew = false
        end

        machineProxy.nick = name .. " " .. string.format("%02d", #self[rkey].Machines)

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
        local _, keyOther = String.NameParser(nodeOther.Name)
        local flow = isInflow and {"PrevNodes", "Demands"} or {"NextNodes", "Supplies"}

        self[keyThis][flow[1]][keyOther] = nodeOther
        if type == "PN" then
            self[keyThis][flow[2]][keyOther] = {}
        else
            self[keyThis][flow[2]][type] = {}
        end
    end

    function ProductionLine:LinkThroughputs(rkeyThis, rkeyNext, recipeTree)
        local itemLinks = 0

        for ikeyPush, flowPush in pairs(recipeTree[rkeyThis].Outflows) do
            for ikeyPull, flowPull in pairs(recipeTree[rkeyNext].Inflows) do
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
                local type, _ = String.NameParser(nodeOther.Name)
                local from, to = nodeOther, pNode
                if type ~= "PN" then keyOther = type end
                if nodeOthers == "NextNodes" then from, to = to, from end

                for ikey, _ in pairs(pNode[throughputs][keyOther]) do
                    local tCounters = component.proxy(component.findComponent(String.Composer(" ", keyThis, keyOther, ikey)))
                    self[keyThis][throughputs][keyOther][ikey].Counters = ThroughputCounter:New(tCounters, from, to, ikey)
                    print("    - " .. pNode.Name .. " got " .. #tCounters .. " " .. ikey .. " counter(s) " .. dir3 .. " " .. nodeOther.Name)
                end
            end
        end
    end

    function ProductionLine:UpdateThroughput(rkey)
        local multiplier1, multiplier2 = #self[rkey].Machines, self[rkey].Clock
        local direction = {"Demands", "Supplies"}

        for _, dir in pairs(direction) do
            for _, throughputs in pairs(self[rkey][dir]) do
                throughputs.Amount = throughputs.Amount * multiplier1
                throughputs.Duration = throughputs.Duration / multiplier2
            end
        end
    end

--[[
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
--[[
    function ProductionLine:SetClock1(nodeI, rkeyI, clock)
        if not self[rkeyI] then return end
        nodeI.Clock = clock
    end

    function ProductionLine:SetClock2(nodeI, rkeyI, clock, tags)
        if not #self[rkeyI].Tags > 0 then return end
        local tagsChecked = {}

        for _, tag1 in pairs(nodeI.Tags) do
            local isTags = false
            tagsChecked[tag1] = true
            for _, tag2 in pairs(tags) do
                if tag1 == tag2 then isTags = true end
            end
            if isTags == false then return end
        end

        for _, tag2 in pairs(tags) do
            if tagsChecked[tag2] == true then break end
            local isTags = false
            for _, tag1 in pairs(nodeI.Tags) do
                if tag1 == tag2 then isTags = true end
            end
            if isTags == false then return end
        end

        nodeI.Clock = clock
    end
]]--
    function ProductionLine:UpdateClock(rkey)
        for _, machine in pairs(self[rkey].Machines) do machine.potential = self[rkey].Clock end
    end
               
    setmetatable(instance, {__index = self})
    return instance
end