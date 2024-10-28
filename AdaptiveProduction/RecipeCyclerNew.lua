---@enum direction
local portsDirection = {left = 1, middle = 2, right = 3}

---@class itemAmount

---@class itemType

---@class FINproxy proxy of FIN component

---@class FINcomponent

---@class recipeCycler
---@field splitters table
---@field machines table
---@field timeStamp number
local recipeCycler = {}

---@class splitterPort
---@field connector FINcomponent
---@field splitter splitter
---@field isOverflow boolean
---@field direction direction
---@field machine machine
---@field fedAmount integer
local splitterPort = {}

---@class splitter
---@field proxy FINproxy
---@field ports table
---@field feederPortsDict table
---@field overflowPortDict table
local splitter = {}

---@class machine
---@field proxy FINproxy
---@field splitterPort splitterPort
---@field demandItem itemAmount
---@field recipes table
---@field recipeOrder integer
local machine = {}

---comment
---@param direction direction
---@param splitter splitter
---@return splitterPort
function splitterPort:new(splitter, direction)

    local instance = {
        connector = {},
        splitter = splitter,
        isOverflow = true,
        direction = direction,
        machine = {},
        fedAmount = 0}

---comment
---@param addInt? integer
    function splitterPort:fedAmountAdd(addInt)
        self.fedAmount = self.fedAmount + (addInt or 1)
    end

    function splitterPort:fedAmountClear()
        self.fedAmount = 0
    end

---@return itemAmount
---@return integer
    function splitterPort:getIngredient()
        local temp = self.machine.demandItem

        return temp.type, temp.amount
    end

---comment
---@param nick string
    function splitterPort:getMachinePair(nick, machines)
    	if self.connector:getConnected() then
	        local connected = self.connector:getConnected().owner
	        local _, _, matchingMachine = self:getMachinePair_R(connected, nick)
            local machineName = matchingMachine.internalName or nil

			if machines[machineName] then
                self.machine = machines[machineName]
                self.isOverflow = false

                print("machine", machineName, "paired with", self.splitter.proxy.internalName, "at feedport", self.direction)
                table.insert(self.splitter.feederPortsDict, self)
            else
                print(self.splitter.proxy.internalName, "overflows to", self.direction)
                table.insert(self.splitter.overflowPortDict, self)
	        end
        else
            self.isOverflow = false
        end
    end

---comment
---@param connected FINproxy
---@param nick string
---@param machine? FINproxy
---@param history? table
---@return FINproxy
---@return string
---@return FINproxy
---@return table
    function splitterPort:getMachinePair_R(connected, nick, machine, history)
        local machine = machine or {}
        local history = history or {}

        for _, connectorR in pairs(connected:getFactoryConnectors()) do
        	if connectorR:getConnected() then
	            local connectedR = connectorR:getConnected().owner
	            history[connectedR] = true

	            if connectedR == self.splitter.proxy then
	            elseif connectedR.isNetworkComponent and string.match(connectedR.nick, nick) then
	                machine = connectedR
	            elseif not history[connectedR]then
	                connected, _, machine = self:getMachinePair_R(connectedR, nick, machine)
	            end
            end
        end

        return connected, nick, machine, history
    end

    setmetatable(instance, {__index = self})

    return instance
end

---comment
---@param splitterProxy FINproxy
---@return splitter
function splitter:new(splitterProxy)
    ---@type splitter
    local instance = {
        proxy = splitterProxy,
        ports = {},
        feederPortsDict = {},
        overflowPortDict = {}}

    for direction = 1, 3 do
        local temp = splitterPort:new(instance, direction)
        
        temp.connector = instance.proxy:getConnectorByIndex(direction)
        temp.splitter = instance

        instance.ports[direction] = temp
    end

    function splitter:runSplitter(itemInput, feedMultiplier)
        local isOverflow = true
        local feederNum, overflowNum = #self.feederPortsDict, #self.overflowPortDict
        local randNum1 = math.ceil(math.random(0, feederNum)) + 1
        local randNum2 = math.ceil(math.random(0, overflowNum)) + 1

        for i = 1, feederNum do
            ---@type splitterPort
            local feederPort = self.feederPortsDict[(i + randNum1) % feederNum]

            if itemInput == feederPort.machine.demandItem then
                isOverflow = false
                self.proxy:transferItem(feederPort.direction)
            end
        end

        if isOverflow then
            for i = 1, overflowNum do
                ---@type splitterPort
                local overflowPort = self.overflowPortDict[(i + randNum2) % overflowNum]
                self.proxy:transferItem(overflowPort.direction) 
            end
        end
    end

    setmetatable(instance, {__index = self})
    return instance
end

---comment
---@param machineProxy FINproxy
---@return machine
function machine:new(machineProxy)
    local instance = {
        proxy = machineProxy,
        splitterPort = {},
        demandItem = {},
        recipes = {},
        recipeOrder = 1}

    function machine:cycleRecipe(recipe)
        local recipeNum = (self.recipeOrder + 1) % #self.recipes

        self.proxy:setRecipe(self.recipes[recipeNum])
        self.demandItem = recipe:getIngredients()[1]
    end

---comment
---@param includeStrings table
---@param excludeStrings table
    function machine:defineRecipes(includeStrings, excludeStrings)
        local recipeTemp1, recipeTemp2 = {}, self.proxy:getRecipes()
        local recipes = {}

        for _, recipe in pairs(recipeTemp2) do
            for _, include in pairs(includeStrings) do
                if string.find(recipe.name, include) then
                    recipeTemp1[recipe.name] = recipe
                    print(recipe.name, " has added to the recipes of", self.proxy.internalName)
                end
            end
        end

        for name, _ in pairs(recipeTemp1) do
            for _, exclude in pairs(excludeStrings) do
                if string.find(name, exclude) then
                    recipeTemp1[name] = nil
                    print(name, " has deleted from the recipes of", self.proxy.internalName)
                end
            end
        end

        for _, recipe in pairs(recipeTemp1) do
            table.insert(recipes, recipe)
        end

        self.recipes = recipes
    end


    setmetatable(instance, {__index = self})
    return instance
end

function recipeCycler:new()
    local instance = {
        splitters = {},
        machines = {},
        timeStamp = computer.magicTime(),
    }

    function recipeCycler:initBuildables(nick)
        ---@type FINproxy
        local temp = component.proxy(component.findComponent(nick))

        for _, comp in pairs(temp) do
            local class = comp:getType()

            if string.match(class.name, "CodeableSplitter") then
                self.splitters[comp.internalName] = splitter:new(comp)
            elseif string.match(class.name, "Constructor") then
                self.machines[comp.internalName] = machine:new(comp)
            end
        end

        for _, splitter in pairs(self.splitters) do
            if #splitter.ports < 3 then
                local errorString = "Splitter " .. splitter.internalName .. " not properly set! " .. #splitter.ports
                error(errorString)
            else
                for _, splitterPort in pairs(splitter.ports) do
                    splitterPort:getMachinePair(nick, self.machines)
                end
            end
        end
    end

    function recipeCycler:initCycle(feedMultiplier, cycleTime)
    end

    function recipeCycler:run(deltaTime)
    end

    setmetatable(instance, {__index = self})
    return instance
end

local test = recipeCycler:new()
test:initBuildables("Biomass")