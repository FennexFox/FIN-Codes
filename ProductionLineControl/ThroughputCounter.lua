ThroughputCounter = {}

function ThroughputCounter:New()
    local instance = {}

    function ThroughputCounter:NewNodeP(productionNode)
        local _, rkeyThis = String.NameParser(productionNode.Name)

        for rkeyPrev, demands in pairs(productionNode.Demands) do
            for ikey, _ in pairs(demands) do
                local tCounters = component.proxy(component.findComponent(ikey, rkeyThis))
                productionNode.Demands[rkeyPrev][ikey] = tCounters
                print("    - " .. productionNode.Name .. " got " .. #tCounters .. " inflow counter(s) for " .. ikey)
            end
        end 
        for rkeyNext, supplies in pairs(productionNode.Supplies) do
            for ikey, _ in pairs(supplies) do
                local tCounters = component.proxy(component.findComponent(ikey, rkeyThis))
                productionNode.Supplies[rkeyNext][ikey] = tCounters
                print("    - " .. productionNode.Name .. " got " .. #tCounters .. " outflow counter(s) for " .. ikey)
            end
        end 
    end

    function ThroughputCounter:NewNodeT(terminalNode)
        local terminalType, ikey = String.NameParser(terminalNode.Name)
        local tCounters = component.proxy(component.findComponent(ikey, terminalType))
        terminalNode.Counters = tCounters
        print("    - " .. terminalNode.Name .. " got " .. #tCounters .. " hroughput counter(s) for " .. ikey)
    end

    setmetatable(instance, {__index = self})
    return instance
end