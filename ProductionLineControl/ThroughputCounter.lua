-- dependent on String

ThroughputCounter = {}

function ThroughputCounter:New(tCounters, from, to, ikey)
    local instance = {}
    local fromName, toName = {String.NameParser(from.Name)}, {String.NameParser(to.Name)}
    setmetatable(instance, {__index = self})

    instance.counters = component.proxy(tCounters)
    fromName = (fromName[1] == "PN") and fromName[2] or fromName[1]
    toName = (toName[1] == "PN") and toName[2] or toName[1]

    function ThroughputCounter:GetIPM()
        local ipm = 0
        for _, counter in pairs(self.counters) do
            ipm = ipm + counter:GetCurrentIPM()
        end
        return ipm
    end

    function ThroughputCounter:GetLimit()
        local limit = 0
        for _, counter in pairs(self.counters) do
            limit = limit + counter:GetThroughputLimit()
        end
        return limit
    end

    function ThroughputCounter:SetLimit(int)
        local limit = int / #self.counters
        for _, counter in pairs(self.counters) do
            counter:SetThroughputLimit(limit)
        end
    end

    for i, counter in ipairs(instance.counters) do
        counter.nick = string.format("[TC] %s / %s -> %s / %02d", ikey, fromName, toName, i)
    end

    return instance
end