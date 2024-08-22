---@alias	object				"an object, ya know" | table
---@alias	component			"FIN component" | table
---@alias	components			"array of components" | table
---@alias	factoryConnector	"FIN factoryConnector" | table
---@alias	proxyArray			"array of component proxies" | table
---@alias	proxy				"FIN component proxy" | table

---@alias	itemType			"FIN itemType" | table

---@alias	itemStack
---| 'count' # stack size in integer
---| 'type'	# itemType

---@alias	itemAmount
---| 'amount' # item amount integer
---| 'type'	# itemType

---@alias	recipe				"FIN recipe" | table
---@alias	recipes				"array of recipes" | table

---@class	splitterPorts
---| '0' # left port
---| '1' # middle port
---| '2' # right port

---@class 	machineArray
---| "proxy" # component proxy of manufacturers
---| "timeStamp" # timeStamp of the last recipe change
---| "demandNow" # itemAmount of recipe ingredient
---| "recipeNow" # recipe now

---@class	splitterArray
---| "proxy" # component proxy of codeable splitters
---| "feedport" # splitterPorts

---@alias machineFeederPair "Tuple of [splitter] = machine" | table

---@class recipeCycler
---| "machines" # table Array of machine proxies
---| "splitters" # table Array of splitter proxies
---| "machineFeederPair" # "Tuple of [machine] = splitter"
---| "recipes" # table Array of recipes
---| "timeStamp" # last time cycleRecipe() executed
RecipeCycler = {}

---comment
---@param maxTime number maximum time in seconds to wait before cycle to the next recipe
---@param minTime number minimum time in seconds to wait before cycle to the next recipe
---@return table
function RecipeCycler:new(maxTime, minTime)
	local instance = {
		machines = {},
		splitters = {},
		machineFeederPair = {},
		feederMachinePair = {},
		recipes = {},
		maxTime = maxTime or 90,
		minTime = minTime or 10,
		timeStamp = 0
	}

	local tempLibraries = {} -- this shall be moved to external libraries someday

	function self:initBuildables(nick, includeString, excludeString)
		local temp = component.proxy(component.findComponent(nick))

		for _, comp in pairs(temp) do
			local className = comp:getType().name

			if string.match(className, "Constructor") then
				local machine = {proxy = comp, timeStamp = 0, recipeNow = nil, recipeOrder = 1}
				self.machines[comp.internalName] = machine

				if #self.recipes < 1 then
					self.recipes = self:defineRecipes(comp, includeString, excludeString)
				end

				self:setRecipes(machine, self.recipes)

			elseif string.match(className, "Splitter") then
				local splitter = {proxy = comp, feedport = {false, false, false}, fedAmount = 0}
				self.splitters[comp.internalName] = splitter
			elseif string.match(className, "Merger") then -- not yet designed
			else
				print("unidentified class " , className .. " of " .. comp.internalName, " in group ", nick)
			end

			event.listen(comp)
		end

		for _, machine in pairs(self.machines) do
			local connection
			for _, connector in pairs(machine.proxy:getFactoryConnectors()) do
				if connector.direction == 0 then connection = connector break end
			end

			local connected  = connection:getConnected().owner
			local _, splitter, feedingPort = tempLibraries.getFactoryConnectors_R(connection, connected, _, nick)

			if feedingPort then
				print("machine " .. machine.proxy.internalName .. " paired with " .. splitter.internalName)

				self.splitters[splitter.internalName].feedport[feedingPort+1] = true
				self.machineFeederPair[splitter.internalName] = {machine = machine, timeStamp = computer.magicTime()}
				self.feederMachinePair[machine.proxy.internalName] = self.machineFeederPair[splitter.internalName]
			end
		end
		self.timeStamp = computer.magicTime()
	end

---recursive function to establish machine-splitter pair
---@param connection any
---@param connected component
---@param feedingPort integer | nil
---@return any
---@return component
---@return integer | nil
function tempLibraries.getFactoryConnectors_R(connection, connected, feedingPort, group)
	print(connection.internalName, " / ", connected)
	local feedingPort = feedingPort or nil

	if string.match(connected.internalName, "Conveyor") then
		for _, connector in pairs(connected:getFactoryConnectors()) do
			local connectionR = connector:getConnected()
			local connectedR = connectionR.owner

			connection, connected = tempLibraries.getFactoryConnectors_R(connectionR, connectedR, feedingPort, group)
			if string.match(connected.internalName, "Splitter") then
				_, _, feedingPort = string.find(connection.internalName, "Output(%d)")
				break
			end
		end
	end

	return connection, connected, tonumber(feedingPort)
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
			if e == "ItemRequest" then
				event.value = event.sender:getInput()
			end
		else
			event = {type = "timeOut", sender = "Ficsit_OS", value = "magicTime", time = t}
		end

		return event
	end

---Defien recipes to cycle; include any string and exclude any string
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
	function self:waitTime(inputCount, inputAmount, recipeDuration)
		local temp = inputAmount - (inputCount % inputAmount)
		temp = inputAmount / temp

		temp = math.min(math.maxinteger, math.max(math.mininteger, temp))
		temp = (1 / (1 + math.exp(-temp+1))) - 0.5

		local waitTime = 2 * temp * (self.maxTime - recipeDuration) + recipeDuration
		waitTime = math.max(self.minTime, waitTime)

		return math.floor(waitTime*100+0.5)/100
	end

---Transfer items with matching itemType to feedports, others to overflow
---@param itemInput itemType "itemType of the item the splitter catches"
---@param itemToFeed itemType "itemType of the ingredient of set recipe"
function self:runSplitters(itemInput, itemToFeed, amountToFeed)
	if type(itemInput) == "string" then itemInput = {name = itemInput} end
	if type(itemToFeed) == "string" then itemToFeed = {name = itemToFeed} end

	local isFeed = itemInput == itemToFeed
	print("run for ", amountToFeed, " reps of ", itemToFeed.name, ", got ", itemInput.name)
		for k, splitter in pairs(self.splitters) do
			if type(k) == "number" then 
			else
--				local itemInInv = self.machineFeederPair[k]:getInputInv().itemCount
				local fedAmount = splitter.fedAmount
				for i = 1, 3 do
					print("feedport " , i-1 , " isFeeder: " , splitter.feedport[i], " isFeed: ", isFeed)
					if splitter.feedport[i] then
						print("feedingAmount " , amountToFeed - fedAmount)

						if amountToFeed <= fedAmount then
							splitter.fedAmount = 0
							break
						elseif isFeed and splitter.proxy:canOutput(i-1) then
							splitter.proxy:transferItem(i-1)
							print(itemInput.name .. " fed to port #" .. i-1)
							fedAmount = fedAmount + 1
							print(fedAmount, " items fed, ", amountToFeed - fedAmount, " items to feed")
							break
						end
					elseif splitter.proxy:canOutput(i-1) then
						splitter.proxy:transferItem(i-1)
						print(itemInput.name .. " overflowed to port #" .. i-1)
					end
				end
				splitter.fedAmount = fedAmount
			end
		end
	end

	function self:cycleRecipe(recipes)
		local timeNow = computer.magicTime()
		for k, splitter in pairs(self.splitters) do
			local machineFeederPair = self.machineFeederPair[k]
			local machine = machineFeederPair.machine
			local machineRecipe = self.recipes[machine.recipeOrder]

			local inputCount = machine.proxy:getInputInv().itemCount
			local inputAmount = machineRecipe:getIngredients()[1].amount
			local waitTime = self:waitTime(inputCount, inputAmount, machineRecipe.duration)

			local timePassed = timeNow - machineFeederPair.timeStamp
			local waitMore = inputCount > inputAmount or machine.proxy.progress > 0.01
			
			if waitMore then waitTime = waitTime + timePassed end

			if timePassed < waitTime then
				print(timePassed, "s has passed with ",  recipes[machine.recipeOrder].name, ", ",
				inputCount, " items in inputInv," ,  waitTime - timePassed, "s more to wait ..")
			else
				machine.recipeOrder = machine.recipeOrder % #recipes + 1
				print(timePassed, "s has passed, switching recipe to " .. recipes[machine.recipeOrder].name)
				machine.proxy:setRecipe(recipes[machine.recipeOrder])
				self.machineFeederPair[k].timeStamp = computer.magicTime()
				self.splitters[k].fedAmount = 0
			end
		end

		self.timeStamp = computer.magicTime()
	end

	function self:unstuck()
		print("unstuck splitter inputs")
		for _, splitter in pairs(self.splitters) do
			self:runSplitters("it's stuck!", "unblockConnector", 2)
		end
	end

	function self:resetFedAmount()
		for _, splitter in pairs(self.splitters) do
			splitter.fedAmount = 0
		end
	end

---main loop of this thing
---@param deltaTime number
	function self:main(deltaTime)
	local feedingAmount
		while true do
		local event = tempLibraries.eventListener(deltaTime)
			print(event.type, event.value, event.sender)

			if event.type == "ItemRequest" then -- transfer items
				local s = event.sender
				local m = self.machineFeederPair[s.internalName].machine
				local recipe = m.recipeNow or m.proxy:getRecipe()
				local inputItem = recipe:getIngredients()[1] -- currently only the first ingredient, would be configurable

				self:runSplitters(event.value.type, inputItem.type, inputItem.amount*3)
			elseif event.type == "ItemOutputted" then -- trace if there's items on the belt

			elseif event.type == "ItemTransfer" then -- trace if there's items on the belt
			
			elseif event.type == "ProductionChanged" and event.value == 1 then

			elseif event.type == "timeOut" then -- cycle recipe
				self:cycleRecipe(self.recipes)
				self:unstuck()
			elseif event.type == "Trigger" then -- for easier testing
				if string.find(event.sender.internalName, "Mushroom") then
					self:resetFedAmount()
					self:unstuck()
				else
					self:unstuck()
				end
			end
			
			if computer.magicTime() - self.timeStamp > 1 then
				self:cycleRecipe(self.recipes)
			end
		end
	end

	setmetatable(instance, {__index = self})
	return instance
end

local temp = component.proxy(component.findComponent("CP")[1]):getModules()
for _, v in pairs(temp) do event.listen(v) end

local a = RecipeCycler:new(90, 15)
a:initBuildables("Biomass", {"Biomass"}, {"Alien", "Mycelia"})
--a:defineRecipes({"Biomass"}, {"Alien"})

event.clear()
a:main(1)


--[[
local timeStamp = {bp = 0}


function ss:operate(portsToFeed, Aux)

local recipeData = {}

while true do
    for n, r in pairs(BioRecipes) do
		event.pull(1)

		local inputStack = bp:getInputInv():getStack(0)
		local inputAmount = recipeData.bp:getIngredients()[1].amount
		local waitTime, waitMore
	
		waitTime = inputAmount - (inputStack.count % inputAmount)
		waitTime = math.min(inputAmount / waitTime, math.maxinteger)
		waitTime = WaitTimeLogistics(waitTime-1) * 2*(maxTime.bp - recipeData.bp.duration) + recipeData.bp.duration
		
		waitMore = inputStack.count > inputAmount or bp.progress > 0.01

		local isTime = computer.magicTime() - timeStamp.bp < math.min(math.max(10, waitTime), maxTime.bp)

		if r ~= recipeData.bp then
			print("Set recipe " .. recipeData.bp.name .. " not matching loop")
			if isTime then
				print("time not passed, jumping loop .. ")
			elseif waitMore then
				print("time passed but wait more .. ")
			else
				print("time passed, switching recipe to " .. n)

				bp:setRecipe(r)
				recipeData.bp = r

				timeStamp.bp = computer.magicTime()
			end
		else
			print("Set recipe " .. recipeData.bp.name .. " matching loop")
		end

		local inputDemand = inputStack.item.type or recipeData.bp:getIngredients()[1].type
		ss:operate({1}, inputDemand)

		print(math.floor(math.max(10, waitTime)*100)/100 .. "-" .. computer.magicTime() - timeStamp.bp .. " @ " .. inputStack.count)
  	end
end
]]--

-- cycleRecipe makes FeedingAmount negative, needs to fix