-- dependent on RecipeTree
-- dependent on String

Terminal = {}

function Terminal:New() -- Terminal class is a placeholder
    local instance = {IBT = {}, OBT = {}}

    function Terminal:NewNode(ikey, isInbound)
        local isInboundStr, isNew = isInbound and "IBT" or "OBT", false

        if not self[isInboundStr][ikey] then
            self[isInboundStr][ikey] = {
                Name = "[" .. isInboundStr .. "]_" .. ikey,
                Terminals = {},
                PrevNodes = {},
                NextNodes = {},
                Level = isInbound and 1 or 100
            }
        end

        return self[isInboundStr][ikey], isNew
    end

    function Terminal:RegisterStations(stationClass)
        local stationsA = component.findComponent(findClass(stationClass))
        local stationsT = {}

        for _, sA in pairs(stationsA) do
            stationsT[sA] = true
        end

        for isInbound, terminals in pairs(self) do
            local isLoad = (isInbound == "OBT")
            for ikey, terminal in pairs(terminals) do
                local stationsI = component.findComponent(ikey)
                for _, sI in pairs (stationsI) do
                    if stationsT[sI] then
                        local station = component.proxy(sI)
                        station.isLoadMode = isLoad
                        table.insert(self[isInbound][ikey].Terminals, station)
                    end
                end
                assert(#self[isInbound][ikey].Terminals > 0, terminal.Name .. " has no stations!")
            end
        end
    end
    
    function Terminal:SetTerminal(pLine, rTree)
        local iCounter, oCounter = 0, 0

        for rkey, _ in pairs(pLine) do
            for ikeyIn, _ in pairs(rTree[rkey].Inflows) do
                if not pLine:isInChain(ikeyIn, true) then
                  pLine[rkey].PrevNodes[ikeyIn] = self:NewNode(ikeyIn, true)
                  table.insert(self.IBT[ikeyIn].NextNodes, pLine[rkey])
                  iCounter = iCounter + 1
                end
            end
            for ikeyOut, _ in pairs(rTree[rkey].Outflows) do
                if not pLine:isInChain(ikeyOut, false) then
                  pLine[rkey].NextNodes[ikeyOut] = self:NewNode(ikeyOut, false)
                  table.insert(self.OBT[ikeyOut].PrevNodes, pLine[rkey])
                  oCounter = oCounter + 1
                end
            end
        end

        self:RegisterStations("DockingStation")

        print("\n  - Logistics Terminal Set: " .. iCounter .. " IBT(s) and " .. oCounter .. " OBT(s)") return true
    end

    setmetatable(instance, {__index = self})
    return instance
end