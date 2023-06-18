-- dependent on RecipeTree
-- dependent on String

Terminal = {}

function Terminal:New() -- Terminal class is a placeholder
    local instance = {IBT = {}, OBT = {}}

    function Terminal:NewNode(itemType, isInbound)
        local isNew, ikey = false, String.ItemKeyGenerator(itemType)
        local isInboundStr = isInbound and "IBT" or "OBT"

        if not self[isInboundStr][ikey] then
            self[isInboundStr][ikey] = {
                Name = "[" .. isInboundStr .. "]_" .. ikey,
                Shipments = {Item = itemType},
                Stations = {},
                PrevNodes = {},
                NextNodes = {},
                Throughput = {},
                Tags = {},
            }
        end

        return self[isInboundStr][ikey], isNew
    end
    
    function Terminal:SetProductionTerminal(pLine, rTree)
        local iCounter, oCounter = 0, 0
        local direction, nodeOther = {"Inflows", "Outflows"}, {"NextNodes", "PrevNodes"}

        for dir1, dir2 in pairs(direction) do
            local bool = (dir1 == 1)
            for rkeyOther, pNode in pairs(pLine) do
                for ikey, flow in pairs(rTree[rkeyOther][dir2]) do
                    if not pLine:isInChain(ikey, bool) then
                        local terminal = self:NewNode(flow.Item, bool)
                        local type, _ = String.NameParser(terminal.Name)

                        self[type][ikey][nodeOther[dir1]][rkeyOther] = pNode
                        self[type][ikey].Throughput[rkeyOther] = {}

                        if bool then iCounter = iCounter + 1 else oCounter = oCounter + 1 end
                    end
                end
            end
        end

        self:RegisterStations()

        print("\n  - Logistics Terminal Set: " .. iCounter .. " IBT(s) and " .. oCounter .. " OBT(s)") return true
    end

    function Terminal:RegisterStations()
        for isInbound, stations in pairs(self) do
            for ikey, terminal in pairs(stations) do
                local stationsI = component.findComponent(String.NickQueryComposer(isInbound, ikey))
                for _, sI in pairs (stationsI) do
                    local station = component.proxy(sI)
                    station.isLoadMode = (isInbound == "OBT")
                    table.insert(self[isInbound][ikey].Stations, station)
                end
                assert(#self[isInbound][ikey].Stations > 0, terminal.Name .. " has no stations!")
            end
        end
    end

    function Terminal:SetTags(rkeyI, tag, isInboundStr)
        table.insert(self[isInboundStr][rkeyI].Tags, tag)
    end

    function Terminal:SetCounters(ikey, type)
        local terminal = self[type][ikey]
        local keyThis = (type == "IBT") and "Inbound" or "Outbound"
        local nodeOthers = isInbound and terminal.NextNodes or terminal.PrevNodes

        for keyOther, nodeOther in pairs(nodeOthers) do
            local tCounters = component.proxy(component.findComponent(String.NickQueryComposer(ikey, keyThis, keyOther)))
            self[type][ikey].Throughput[keyOther] = ThroughputCounter:New(tCounters, terminal, nodeOther, type == "IBT")
            print("    - " .. terminal.Name .. " got " .. #tCounters .. " " .. ikey .. " throughput counter(s)")
        end
    end
--[[
    function Terminal:UpdateThroughput(ikey, type)
        self[type][ikey].Throughput.Amount = 0
        self[type][ikey].Throughput.Duration = 0
    end
]]--
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