---@enum direction
local portsDirection = {left = 1, middle = 2, right = 3}

---@class recipe
---@field duration number
---@field name string
local recipe = {}

---@class itemAmount
---@field type table
---@field amount integer

---@class itemType
---@field max integer
---@field name string

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
---@field minTime number
---@field maxTime number
---@field timeStamp number
local machine = {}

---comment
---@param direction direction
---@param splitter splitter
---@return splitterPort splitterPort
function splitterPort:new(splitter, direction)

    local instance = {
        connector = {},
        splitter = splitter,
        isOverflow = true,
        direction = direction % 3, --- due to FIN bug
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

---@return itemAmount itemType
---@return integer amount
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
                machines[machineName].splitterPort = self
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
---@return FINproxy connected
---@return string nick
---@return FINproxy machine
---@return table history
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

---comment
---@param itemInput itemType
---@param feedMultiplier integer
---@return string|boolean
    function splitter:feed(itemInput, feedMultiplier)
        local feederNum = #self.feederPortsDict
        local randNum = math.ceil(math.random(0, feederNum))
        local returnString = false

        for i = 1, #self.feederPortsDict do
            ---@type splitterPort
            local feederPort = self.feederPortsDict[(i + randNum) % feederNum + 1]
            local demandItem = feederPort.machine.demandItem
            local amountToFeed = demandItem.amount * feedMultiplier
            amountToFeed = math.min(amountToFeed, itemInput.max)
            
            print("aTF:", amountToFeed, "fA:", feederPort.fedAmount)

            if itemInput == feederPort.machine.demandItem.type and amountToFeed > feederPort.fedAmount then
                print("attmped to feed")
                if self.proxy:transferItem(feederPort.direction) then
                    feederPort.fedAmount = feederPort.fedAmount + 1

                    returnString = itemInput.name .. " has fed to port " .. feederPort.direction
                end
            end
        end

        return returnString
    end

---Sometimes it misbehaves and transfers item to a wrong port
---suspected to be FIN bug, conditions unknown
---@param itemInput? itemType
---@return string|boolean
    function splitter:overflow(itemInput)
        local overflowNum = #self.overflowPortDict
        local randNum = math.ceil(math.random(0, overflowNum))
        local returnString = false

        if not itemInput then itemInput = {name = "forceOverlow", max = 1} end

        for i = 1, overflowNum do
            ---@type splitterPort
            local overflowPort = self.overflowPortDict[(i + randNum) % overflowNum + 1]
            
            if self.proxy:transferItem(overflowPort.direction) then
                returnString = itemInput.name .. " has overflown to port " .. overflowPort.direction
            end
        end

        return returnString
    end
    
    function splitter:runSplitter(itemInput, feedMultiplier)
        local isFed = self:feed(itemInput, feedMultiplier)

        if isFed == false then
            print(self:overflow(itemInput))
        else
            print(isFed)
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
        recipeOrder = 1,
        minTime = 5,
        maxTime = 20,
        timeStamp = computer.magicTime()}

---comment
---@return recipe recipe new recipe set
    function machine:cycleRecipe()
        local recipeNum = (self.recipeOrder % #self.recipes) + 1
        local recipe = self:setRecipe(recipeNum)

        self.recipeOrder = recipeNum
        self.timeStamp = computer.magicTime()
        self.splitterPort:fedAmountClear()

        return recipe
    end
    
    function machine:setRecipe(int)
    	local recipe = self.recipes[int]

    	self.proxy:setRecipe(self.recipes[int])
    	self.demandItem = recipe:getIngredients()[1]
    	
    	return recipe
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

---comment
---@return number waitTime
---@return boolean waitMore
    function machine:waitTime()
        local inputCount = self.proxy:getInputInv().itemCount
        local inputAmount = self.demandItem.amount
        local duration = self.recipes[self.recipeOrder].duration

        local temp = inputAmount - (inputCount % inputAmount)
		temp = inputAmount / temp
		temp = math.min(math.maxinteger, math.max(math.mininteger, temp))
		temp = (1 / (1 + math.exp(-temp+1))) - 0.5

		local waitTime = 2 * temp * (self.maxTime - duration) + duration
		waitTime = math.max(self.minTime, waitTime)

        local waitMore = (inputCount >= inputAmount) or self.proxy.progress > 0.1

		return math.floor(waitTime*100+0.5)/100, waitMore
    end

    setmetatable(instance, {__index = self})
    return instance
end

---comment
---@return table recipeCycler
function recipeCycler:new()
    local instance = {
        splitters = {},
        machines = {},
        timeStamp = computer.magicTime(),
    }

---comment
---@param nick string
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

            event.listen(comp)
        end

        for _, splitter in pairs(self.splitters) do
            if #splitter.ports < 3 then
                local errorString = "Splitter " .. splitter.proxy.internalName .. " not properly set! " .. #splitter.ports
                error(errorString)
            else
                for _, splitterPort in pairs(splitter.ports) do
                    splitterPort:getMachinePair(nick, self.machines)
                end
            end
        end
    end

---comment
---@param includeStrings table
---@param excludeStrings table
---@param minTime? integer
---@param maxTime? integer
---@param number2Set? integer number of machines to config; must be bigger than 0 and smaller than number of machines
    function recipeCycler:configMachines(includeStrings, excludeStrings, minTime, maxTime, number2Set)
        local arraySize, loopCount = 0, 0

        for _, _ in pairs(self.machines) do
            arraySize = arraySize + 1
        end

        local numberMachines = number2Set or arraySize

        if numberMachines <= 0 or numberMachines > arraySize then
            error("Number of machines to config is out of range!")
        end

        while numberMachines > 0 do
            for _, machine in pairs(self.machines) do
                if loopCount + numberMachines > arraySize then
                    error("No more machines left to config!")
                elseif #machine.recipes < 1 then
                    machine:defineRecipes(includeStrings, excludeStrings)
                    machine.minTime = machine.minTime or minTime
                    machine.maxTime = machine.maxTime or maxTime
                    numberMachines = numberMachines - 1
                end

                loopCount = loopCount + 1
            end
        end
        
        for _, machine in pairs(self.machines) do
        	machine:setRecipe(1)
        end
    end

---comment
---@param deltaTime number
---@param filterString? string
---@return table event
    function recipeCycler:eventListener(deltaTime, filterString)
		local filterString = filterString or nil
		local event = {event.pull(deltaTime, filterString)}
		local e, s, v, t, data = (function(e, s, v, ...)
			return e, s, v, computer.magicTime(), {...}
		end)(table.unpack(event))

		if e then
			event = {type = e, sender = s, value = v, time = t, otherData = data}
--			if e == "ItemRequest" then event.value = event.value or event.sender:getInput() end
		else
			event = {type = "TimeOut", sender = "Ficsit_OS", value = "magicTime", time = t}
		end

		return event
	end


    function recipeCycler:cycleRecipe()
        local timeNow = computer.magicTime()

        for internalName, machine in pairs(self.machines) do
            local timePassed = timeNow - machine.timeStamp
            local waitTime, waitMore = machine:waitTime()

            if waitMore then
            elseif timePassed > waitTime then
                local newRecipe = machine:cycleRecipe()
                print(timePassed, "s has passed,", internalName, "switching recipe to " .. newRecipe.name)

                machine.splitterPort.fedAmount = 0
            end
        end
    end

    function recipeCycler:main(feedMultiplier, deltaTime)
        while true do
            local event = self:eventListener(deltaTime)

            if event.type == "ItemRequest" then
            	local splitterName = event.sender.internalName
                self.splitters[splitterName]:runSplitter(event.value.type, feedMultiplier)
            elseif event.type == "TimeOut" then
                for _, splitter in pairs(self.splitters) do
                    splitter:overflow()
                end
            end

            self:cycleRecipe()
        end
    end

    setmetatable(instance, {__index = self})
    return instance
end

local test = recipeCycler:new()
test:initBuildables("Biomass") -- initiate builables (contructor, codeableSplitter) with nuck
test:configMachines({"Biomass"}, {"Alien"}) -- getting recipes; string to included and string to excluded
test:main(100, 0.04) -- setting how mnay stacks to feed and deltaTime