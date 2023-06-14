ThroughputCounter = {}

function ThroughputCounter:New()
    local instance = {}

    function ThroughputCounter:Initialize(nodeSerieze)
        
    end

    setmetatable(instance, {__index = self})
    return instance
end