-- dependent on RecipeTree
-- dependent on String

Terminal = {}

function Terminal:New() -- Terminal class is a placeholder
    local instance = {IBT = {}, OBT = {}}

    function Terminal:NewNode(itemType, isInbound)
        local isInboundStr, isNew = isInbound and "IBT" or "OBT", false
        local ikey = String.ItemKeyGenerator(itemType)

        if not self[isInboundStr][ikey] then
            self[isInboundStr][ikey] = {
                Name = "[" .. isInboundStr .. "]_" .. ikey,
                Shipments = {},
                Stations = {},
                PrevNodes = {},
                NextNodes = {},
                Counters = {},
                Tags = {},
                Level = isInbound and 1 or 100
            }
        end

        return self[isInboundStr][ikey], isNew
    end
    
    function Terminal:SetProductionTerminal(pLine, rTree)
        local iCounter, oCounter = 0, 0

        for rkey, pNode in pairs(pLine) do
            for ikeyIn, inflow in pairs(rTree[rkey].Inflows) do
                if not pLine:isInChain(ikeyIn, true) then
                    local terminal = self:NewNode(inflow.Item, true)

                    pLine[rkey].PrevNodes[terminal.Name] = terminal
                    pLine:IterateNodes(pNode, true, pLine.SetTags, terminal.Name)
                    table.insert(self.IBT[ikeyIn].NextNodes, pNode)
                    
                    iCounter = iCounter + 1
                end
            end
            for ikeyOut, outflow in pairs(rTree[rkey].Outflows) do
                if not pLine:isInChain(ikeyOut, false) then
                    local terminal = self:NewNode(outflow.Item, false)

                    pLine[rkey].NextNodes[terminal.Name] = terminal
                    pLine:IterateNodes(pNode, false, pLine.SetTags, terminal.Name)
                    table.insert(self.OBT[ikeyOut].PrevNodes, pNode)

                    oCounter = oCounter + 1
                end
            end
        end

        self:RegisterStations()

        print("\n  - Logistics Terminal Set: " .. iCounter .. " IBT(s) and " .. oCounter .. " OBT(s)") return true
    end

    function Terminal:RegisterStations()
        for isInbound, stations in pairs(self) do
            for ikey, terminal in pairs(stations) do
                local stationsI = component.findComponent(isInbound, ikey)
                for _, sI in pairs (stationsI) do
                    local station = component.proxy(sI)
                    station.isLoadMode = (isInbound == "OBT")
                    table.insert(self[isInbound][ikey].Stations, station)
                end
                assert(#self[isInbound][ikey].Stations > 0, terminal.Name .. " has no stations!")
            end
        end
    end

    function Terminal:GetItemLevel(ikey, isInboundStr)
        local itemLevel = {
            StockAmount = 0,
            StockStack = 0,
            CapacityAmount = 0,
            CapacityStack = 0,
            RatioAmount = 0,
            RatioStack = 0
        }

        for _, station in pairs(self[isInboundStr][ikey].Stations) do
            local inventory, stackSize = station:getInv(), self[isInboundStr][ikey].Item.Max

            itemLevel.StockAmount = itemLevel.StockAmount + inventory.itemCount
            itemLevel.StockStack = itemLevel.StockStack + math.ceil(inventory.itemCount / stackSize)
            itemLevel.CapacityAmount = itemLevel.CapacityAmount + inventory.size * stackSize
            itemLevel.CapacityStack = itemLevel.CapacityStack + inventory.size
            itemLevel.RatioAmount = itemLevel.StockAmount / itemLevel.CapacityAmount
            itemLevel.RatioStack = itemLevel.StockStack / itemLevel.CapacityStack
        end

        return itemLevel
    end

    function Terminal:GetItemLevels()
        local itemLevels = {IBT = {}, OBT = {}}
        for isInboundStr, terminals in pairs(self) do
            for ikey, _ in pairs(terminals) do
                itemLevels[isInboundStr][ikey] = self:GetItemLevel(ikey, isInboundStr)
            end
        end

        return itemLevels
    end

    function Terminal:Main()

    end

    setmetatable(instance, {__index = self})
    return instance
end