ThroughputCounter = {}

function ThroughputCounter:New(tCounters, this, other, isInflow)
    local instance, counters = {}, tCounters
    setmetatable(instance, {__index = self})



    return instance
end