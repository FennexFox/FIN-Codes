---@alias object    table an object, ya know
---@alias component   table FIN component
---@alias components   table array of components
---@alias factoryConnector table FIN factoryConnector
---@alias proxyArray   table array of component proxies
---@alias proxy    table FIN component proxy
---@alias itemType   table FIN itemType
---@alias recipe    table FIN recipe
---@alias recipes    table array of recipes

---@class itemStack
---@field count integer stack size in integer
---@field iType itemType itemType

---@class itemAmount
---@field amount integer item amount integer
---@field iType itemType itemType

---@class splitterPorts
---| '0' # left port
---| '1' # middle port
---| '2' # right port

---@class machineArray
---@field proxy proxy component proxy of manufacturers
---@field recipeNow recipe # recipe now
---@field recipeOrder integer current iteration of recipes

---@class splitterArray
---@field proxy proxy component proxy of codeable splitters
---@field outputPort table information of each output ports
---@field fedAmountTotal integer number of fedAmount for all outputPorts
---@field portsToFeed integer number of outputPorts that feed machines

---@alias machineFeederPair "Tuple of [splitter] = machine" | table

local RecipeCycler = {}

---@return table
function RecipeCycler:new()
 local instance, groupDict = {}, {}

 	local tempLibraries = {} -- this shall be moved to external libraries someday

	---@param nick string
	---@param includeString table
	---@param excludeString table
	---@param maxTime integer
	---@param minTime integer
	function self:initGroup(nick, includeString, excludeString, maxTime, minTime)
		local temps = component.proxy(component.findComponent(nick))
		self[nick] = {
			recipes = {},
			machines = {},
			splitters = {},
			pairs = {},
			maxTime = maxTime,
			minTime = minTime,
			timeStamp = computer.magicTime()
		}

		self:initBuildables(nick, includeString, excludeString, temps)
		self:pairBuildables(nick)
	end

	---@param nick string
	---@param includeString table
	---@param excludeString table
	---@param comps proxyArray
	function self:initBuildables(nick, includeString, excludeString, comps)
		for _, comp in pairs(comps) do
			local className = comp:getType().name
			groupDict[comp.internalName] = nick

			if string.match(className, "Constructor") then
				local machine = {proxy = comp, recipeNow = nil, recipeOrder = 1}
				self[nick].machines[comp.internalName] = machine

				if #self[nick].recipes < 1 then
				self[nick].recipes = self:defineRecipes(comp, includeString, excludeString)
				end

				self:setRecipes(machine, self[nick].recipes)
			elseif string.match(className, "Splitter") then
				local splitter = {proxy = comp, outputPort = {}, fedAmountTotal = 0, portsToFeed = 0}
				self[nick].splitters[comp.internalName] = splitter
			elseif string.match(className, "Merger") then -- not yet designed
			else
				print("unidentified class " , className .. " of " .. comp.internalName, " in group ", nick)
			end

		event.listen(comp)
		end
	end

	---@param nick string
	function self:pairBuildables(nick)
		for machineName, machine in pairs(self[nick].machines) do
			local connection
			for _, connector in pairs(machine.proxy:getFactoryConnectors()) do
				if connector.direction == 0 then connection = connector break end
			end

			local connected  = connection:getConnected().owner
			local connection, splitter, feedingPort = tempLibraries.getFactoryConnectors_R(connection, connected, nick)

			if feedingPort then
				local portNum
				local splitterName = splitter.internalName

				for i = 0, 2 do
					if splitter:getConnectorByIndex(i).internalName == feedingPort then
						portNum = i
						break
					end
				end

				print("machine", machine.proxy.internalName, "paired with", splitterName, "at feedport", portNum)
				self[nick].splitters[splitterName].outputPort[portNum] = {connection = connection, fedAmount = 0}
				self[nick].splitters[splitterName].portsToFeed = self[nick].splitters[splitterName].portsToFeed + 1

				local pair = {
					splitter = self[nick].splitters[splitterName],
					machine = self[nick].machines[machineName],
					timeStamp = computer.magicTime()
				}

				self[nick].pairs[splitter.internalName] = pair
				self[nick].pairs[machine.proxy.internalName] = pair
			end
		end
	end

---recursive function to establish machine-splitter pair
---@param connection any
---@param connected component
---@param feedingPort string | nil
---@return any
---@return component
---@return string | nil
function tempLibraries.getFactoryConnectors_R(connection, connected, feedingPort, group)
	print(connection.internalName, " / ", connected)
	local feedingPort = feedingPort or nil
   
	if string.match(connected.internalName, "Conveyor") then
		for _, connector in pairs(connected:getFactoryConnectors()) do
			local connectionR = connector:getConnected()
			local connectedR = connectionR.owner
		
			connection, connected = tempLibraries.getFactoryConnectors_R(connectionR, connectedR, feedingPort, group)
			if string.match(connected.internalName, "Splitter") then
				feedingPort = connection.internalName
				break
			end
		end
	end
   
	return connection, connected, feedingPort
   end
   
	---Event listener that parses event message and returns data
	---@param deltaTime number
	---@return table
	function tempLibraries.eventListener(deltaTime, filterString)
		local filterString = filterString or nil
		local event = {event.pull(deltaTime, filterString)}
		local e, s, v, t, data = (function(e, s, v, ...)
			return e, s, v, computer.magicTime(), {...}
		end)(table.unpack(event))
	
		if e then
			event = {type = e, sender = s, value = v, time = t, otherData = data}
			if e == "ItemRequest" then event.value = event.sender:getInput() end
		else
			event = {type = "timeOut", sender = "Ficsit_OS", value = "magicTime", time = t}
		end
	
		return event
	end
   
   ---Defien recipes to cycle; include any string and exclude any string
   ---@param machineSample proxy
   ---@param includeString table
   ---@param excludeString table
   ---@return recipes
	function self:defineRecipes(machineSample, includeString, excludeString)
		local recipeTemp1, recipeTemp2 = {}, machineSample:getRecipes()
		local recipes = {}
	
		for _, recipe in pairs(recipeTemp2) do
			for _, include in pairs(includeString) do
				if string.find(recipe.name, include) then
					recipeTemp1[recipe.name] = recipe
					print(recipe.name .. " has added to the list")
				end
			end
		end
	
		for name, _ in pairs(recipeTemp1) do
			for _, exclude in pairs(excludeString) do
				if string.find(name, exclude) then
					recipeTemp1[name] = nil
					print(name .. " has deleted from the list")
				end
			end
		end
	
		for _, recipe in pairs(recipeTemp1) do
			table.insert(recipes, recipe)
		end
	
		return recipes
	end
   
	function self:setRecipes(machine, recipes)
		local getRecipe = machine.proxy:getRecipe()
		local setRecipe = recipes[machine.recipeOrder]
	
		if not (getRecipe == setRecipe) then machine.proxy:setRecipe(setRecipe) end
	end
   
   ---calculate how many seconds to wait before cycle to the next recipe
   ---@param inputCount number item count of the machine's input inventory
   ---@param inputAmount number item amount of the recipe's ingredient
   ---@param recipeDuration number duration of the recipe
   ---@return number time to wait in seconds
	function self:waitTime(inputCount, inputAmount, recipeDuration, group)
		local temp = inputAmount - (inputCount % inputAmount)
		temp = inputAmount / temp
	
		temp = math.min(math.maxinteger, math.max(math.mininteger, temp))
		temp = (1 / (1 + math.exp(-temp+1))) - 0.5

		local waitTime = 2 * temp * (group.maxTime - recipeDuration) + recipeDuration
		waitTime = math.max(group.minTime, waitTime)
	
		return math.floor(waitTime*100+0.5)/100
	end
   
   ---Transfer items with matching itemType to feedports, others to overflow
   ---@param splitterData splitterArray
   ---@param itemInput itemType | string "itemType of the item the splitter catches"
   ---@param itemToFeed itemType | string "itemType of the ingredient of set recipe"
   ---@param amountToFeed integer
	function self:runSplitter(itemInput, itemToFeed, amountToFeed, splitterData)
		if type(itemInput) == "string" then itemInput = {name = itemInput} end
		if type(itemToFeed) == "string" then itemToFeed = {name = itemToFeed} end
	
		local isFeed = itemInput == itemToFeed
		print("run for ", amountToFeed, " reps of ", itemToFeed.name, ", got ", itemInput.name)

	
		local splitter = splitterData.proxy
		for i = 0, 2 do
			local outputPort = splitter:getConnectorByIndex(i)
			if outputPort.isConnected  then
				if isFeed then
					if splitterData.outputPort[i] then
						local feedPort = splitterData.outputPort[i]
						if amountToFeed > splitterData.outputPort[i].fedAmount then
							if  splitter:transferItem(i) then
								print(itemInput.name, "fed to port", i)
								feedPort.fedAmount = feedPort.fedAmount + 1
								splitterData.fedAmountTotal = splitterData.fedAmountTotal + 1
							end
						end
					elseif (amountToFeed * splitterData.portsToFeed) <= splitterData.fedAmountTotal then
						if splitter:transferItem(i) then print(itemInput.name, "is", isFeed, "and overflew to port", i) end
					end
				elseif not splitterData.outputPort[i] then
					if splitter:transferItem(i) then print(itemInput.name, "is", isFeed, "and overflew to port", i) end
				end
			else print("feedport", i, "is not connected!")
			end
		end
	end
 
	function self:cycleRecipe(recipes, group)
	local timeNow = computer.magicTime()

	for machineName, machine in pairs(group.machines) do
		local inputCount = machine.proxy:getInputInv().itemCount

		local machineRecipe = group.recipes[machine.recipeOrder]
		local inputAmount = machineRecipe:getIngredients()[1].amount
		local waitTime = self:waitTime(inputCount, inputAmount, machineRecipe.duration, group)
	
		local timePassed = timeNow - group.pairs[machineName].timeStamp
		local waitMore = (inputCount > inputAmount) or machine.proxy.progress > 0.01
		
		if waitMore then waitTime = waitTime + timePassed end
	
		if timePassed < waitTime then
			print(timePassed, "s has passed with ",  recipes[machine.recipeOrder].name, ", ",
			inputCount, " items in inputInv," ,  waitTime - timePassed, "s more to wait ..")
		else
			machine.recipeOrder = machine.recipeOrder % #recipes + 1
			print(timePassed, "s has passed, switching recipe to " .. recipes[machine.recipeOrder].name)
			machine.proxy:setRecipe(recipes[machine.recipeOrder])

			group.pairs[machineName].timeStamp = computer.magicTime()
			group.pairs[machineName].splitter.fedAmountTotal = 0

			for i = 0, 2 do
				if group.pairs[machineName].splitter.outputPort[i] then group.pairs[machineName].splitter.outputPort[i].fedAmount = 0 end
			end
			
			self:unstuck(group)
		end
	end

	end
 
	function self:unstuck(group)
		print("unstuck splitter inputs")
		for _, splitter in pairs(group.splitters) do
			for i = 0, 2 do
				if not splitter.outputPort[i] then splitter.proxy:transferItem(i) end
			end
		end
	end
 
	function self:resetFedAmount()
		for _, splitter in pairs(self.splitters) do
			splitter.fedAmount = 0
		end
	end
 
 ---main loop of this thing
 ---@param deltaTime number
	function self:main(deltaTime, feedMultiplier)
	
		while true do
		local event = tempLibraries.eventListener(deltaTime)
		print(event.type, event.value, event.sender)
		
			if event.type == "ItemRequest" then -- transfer items
				local splitterName = event.sender.internalName
				local groupName = groupDict[splitterName]
				local machineData = self[groupName].pairs[splitterName].machine
				local splitterData = self[groupName].pairs[splitterName].splitter

				local recipe = machineData.recipeNow or machineData.proxy:getRecipe()
				local inputItem = recipe:getIngredients()[1] -- currently only the first ingredient, would be configurable
			
				self:runSplitter(event.value.type, inputItem.type, inputItem.amount * feedMultiplier, splitterData)
			elseif event.type == "ItemOutputted" then -- trace if there's items on the belt
				local splitterName = event.sender.internalName
				local groupName = groupDict[event.sender.internalName]
				local group = self[groupName]
				local timeStamp = group.pairs[splitterName].timeStamp

				if timeStamp + deltaTime <= computer.magicTime() then
					self:cycleRecipe(self[groupName].recipes, group)
				end
		
			elseif event.type == "ItemTransfer" then -- trace if there's items on the belt

			elseif event.type == "ProductionChanged" and event.value == 1 then
		
			elseif event.type == "timeOut" then -- cycle recipe
				for _, group in pairs(self) do
					self:cycleRecipe(group.recipes, group)
				end
			elseif event.type == "Trigger" then -- for easier testing
			end
		end
	end
 
  setmetatable(instance, {__index = self})
  return instance
end
 
local a = RecipeCycler:new()
a:initGroup("Biomass", {"Biomass"}, {"Protein", "Mycelia"}, 90, 5)
a:initGroup("Alien", {"Protein"}, {"Biomass"}, 90, 5)

event.clear()
a:main(1, 10)

-- check amountToFeed, fedAmount and fedAmountTotal