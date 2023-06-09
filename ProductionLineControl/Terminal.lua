-- dependent on RecipeTree
-- dependent on String

Terminal = {}

function Terminal:New() -- Terminal class is a placeholder
    local instance = {IBT = {}, OBT = {}}

    function Terminal:NewNode(item, isInbound)
        local isInboundStr, isNew = isInbound and "IBT" or "OBT", false
        local ikey = String.KeyGenerator(item.Name)

        if not self[isInboundStr][ikey] then
            self[isInboundStr][ikey] = {
                Name = "[" .. isInboundStr .. "]_" .. ikey,
                Item = item,
                Stations = {},
                PrevNodes = {},
                NextNodes = {},
                Level = isInbound and 1 or 100
            }
        end

        return self[isInboundStr][ikey], isNew
    end
    
    function Terminal:SetProductionTerminal(pLine, rTree)
        local iCounter, oCounter = 0, 0

        for rkey, _ in pairs(pLine) do
            for ikeyIn, inflow in pairs(rTree[rkey].Inflows) do
                if not pLine:isInChain(ikeyIn, true) then
                    local terminal = self:NewNode(inflow.Item, true)

                    pLine[rkey].PrevNodes[terminal.Name] = terminal
                    pLine:IterateNodes(rkey, true, pLine.SetTags, terminal.Name)
                    table.insert(self.IBT[ikeyIn].NextNodes, pLine[rkey])
                    
                    iCounter = iCounter + 1
                end
            end
            for ikeyOut, outflow in pairs(rTree[rkey].Outflows) do
                if not pLine:isInChain(ikeyOut, false) then
                    local terminal = self:NewNode(outflow.Item, false)

                    pLine[rkey].NextNodes[terminal.Name] = terminal
                    pLine:IterateNodes(rkey, false, pLine.SetTags, terminal.Name)
                    table.insert(self.OBT[ikeyOut].PrevNodes, pLine[rkey])

                    oCounter = oCounter + 1
                end
            end
        end

        self:RegisterStations("DockingStation")
        self:RegisterStations("TrainPlatformCargo")
        self:RegisterStations("DroneStation")

        print("\n  - Logistics Terminal Set: " .. iCounter .. " IBT(s) and " .. oCounter .. " OBT(s)") return true
    end

    function Terminal:RegisterStations(stationClass)
        local stationsA = component.findComponent(findClass(stationClass))
        if not stationsA[1] then return end

        local stationsT = {}
        for _, sA in pairs(stationsA) do stationsT[sA] = true end

        for isInbound, stations in pairs(self) do
            local isLoad = (isInbound == "OBT")
            for ikey, terminal in pairs(stations) do
                local stationsI = component.findComponent(ikey)
                for _, sI in pairs (stationsI) do
                    if stationsT[sI] then
                        local station = component.proxy(sI)
                        station.isLoadMode = isLoad
                        table.insert(self[isInbound][ikey].Stations, station)
                    end
                end
                assert(#self[isInbound][ikey].Stations > 0, terminal.Name .. " has no stations!")
            end
        end
    end

    function Terminal:GetItemLevel(ikey, isInbound)
        local isInboundStr = isInbound and "IBT" or "OBT"
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

    setmetatable(instance, {__index = self})
    return instance
end