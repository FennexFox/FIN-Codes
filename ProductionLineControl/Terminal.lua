-- dependent on RecipeTree
-- dependent on String

Terminal = {}

function Terminal:New(productionControl) -- Terminal class is a placeholder
    local instance = {IBT = {}, OBT = {}}
    setmetatable(instance, {__index = self})

    local pControl = productionControl

    function Terminal:NewNode(itemType, isInbound)
        local isNew, ikey = false, String.ItemKeyGenerator(itemType)
        local type = isInbound and "IBT" or "OBT"

        if not self[type][ikey] then
            self[type][ikey] = {
                Name = "[" .. type .. "]_" .. ikey,
                Shipments = {Item = itemType},
                Stations = {},
                PrevNodes = {},
                NextNodes = {},
                Throughput = {},
                Tags = {},
            }
        end

        return self[type][ikey], isNew
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

        print("\n  - Logistics Terminal Set: " .. iCounter .. " IBT(s) and " .. oCounter .. " OBT(s)") return self
    end

    function Terminal:RegisterStations()
        for type, stations in pairs(self) do
            for ikey, terminal in pairs(stations) do
                local stationsI = component.findComponent(String.Composer(" ", "terminal", type, ikey))
                for i, sI in ipairs (stationsI) do
                    local station = component.proxy(sI)
                    station.nick = string.gsub(terminal.Name, "_", " ") .. " " .. string.format("%02d", i)
                    station.isLoadMode = (type == "OBT")
                    table.insert(self[type][ikey].Stations, station)
                end
                assert(#self[type][ikey].Stations > 0, terminal.Name .. " has no stations!")
            end
        end
    end

    function Terminal:SetTags(rkeyI, tag, type)
        table.insert(self[type][rkeyI].Tags, tag)
    end

    function Terminal:SetCounters(ikey, type)
        local terminal = self[type][ikey]
        local nodeOthers = (type == "IBT") and terminal.NextNodes or terminal.PrevNodes

        for keyOther, nodeOther in pairs(nodeOthers) do
            local tCounters = component.findComponent(String.Composer(" ", ikey, type, keyOther))
            
            local from, to = terminal, nodeOther
            if type == "OBT" then from, to = to, from end

            self[type][ikey].Throughput[keyOther] = ThroughputCounter:New(tCounters, from, to, ikey)
            print("    - " .. terminal.Name .. " got " .. #tCounters .. " " .. ikey .. " throughput counter(s)")
        end
    end

    function Terminal:GrossCounterFunction(ikey, type, fName, ...)
        local terminal = self[type][ikey]
        local temp = ... or 0

        for _, counter in pairs(terminal.Throughput) do
            if fName == "GetIPM" then temp = temp + counter:GetIPM()
            elseif fName == "GetLimit" then temp = temp + counter:GetLimit()
            elseif fName == "SetLimit" then counter:SetLimit(temp / #terminal.Throughput)
            else error("Counter Function Incorrect!")
            end
        end

        return temp
    end

    function Terminal:GetItemLevel(ikey, type)
        local itemLevel = {
            StockAmount = 0,
            CapacityAmount = 0,
            RatioAmount = 0,
            ThroughputPerMin = 0
        }

        for _, terminal in pairs(self[type][ikey]) do
            itemLevel.ThroughputPerMin = self:GrossCounterFunction(ikey, type, "GetIPM")
            for _, station in pairs(terminal.Stations) do
                local inventory, stackSize = station:getInv(), self[type][ikey].Item.Max

                itemLevel.StockAmount = itemLevel.StockAmount + inventory.itemCount
                itemLevel.CapacityAmount = itemLevel.CapacityAmount + inventory.size * stackSize
                itemLevel.RatioAmount = itemLevel.StockAmount / itemLevel.CapacityAmount
            end
        end

        return itemLevel
    end

    function Terminal:GetItemLevels()
        local itemLevels = {IBT = {}, OBT = {}}
        for type, terminals in pairs(self) do
            for ikey, _ in pairs(terminals) do
                itemLevels[type][ikey] = self:GetItemLevel(ikey, type)
            end
        end

        return itemLevels
    end

    function Terminal:Main()

    end

    return instance
end