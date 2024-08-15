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
---| "recipes" # table Arrau of recipes
RecipeCycler = {}

---Recipe Cycler to use a single machine for multiple recipies with respective inputs <br>
---Curretnly supports recipes with single input; will supports multiple inputs
---@return recipeCycler
function RecipeCycler:new()
	local instance = {
		machines = {},
		splitters = {},
		machineFeederPair = {},
		recipes = {}
	}

	local tempLibraries = {} -- this shall be moved to external libraries someday

	function self:initializingObjects(nick)
		local temp = component.proxy(component.findComponent(nick))

		for _, comp in pairs(temp) do
			local className = comp:getType().name
			if string.match(className, "Constructor") then
				local machine = {proxy = comp, timeStamp = 0, demandNow = "", recipeNow = ""}
				self.machines[comp.internalName] = machine
				table.insert(self.machines, comp)
			elseif string.match(className, "Splitter") then
				local splitter = {proxy = comp, feedport = {false, false, false}, fedAmount = 0}
				self.splitters[comp.internalName] = splitter
				table.insert(self.splitters, comp)
			else
				print("unidentified class " .. className .. " of " .. comp.internalName)
			end

			event.listen(comp)
		end

		for _, machine in ipairs(self.machines) do
			local connection
			for _, connector in ipairs(machine:getFactoryConnectors()) do
				if connector.direction == 0 then connection = connector break end
			end

			local connected  = connection:getConnected().owner
			local _, splitter, feedingPort = tempLibraries.getFactoryConnectors_R(connection, connected)
			if feedingPort then
				print("machine " .. machine.internalName .. " paired with " .. splitter.internalName)

				self.splitters[splitter.internalName].feedport[feedingPort+1] = true
				self.machineFeederPair[splitter.internalName] = machine
			end
		end
	end

---recursive function to establish machine-splitter pair
---@param connection any
---@param connected component
---@param feedingPort integer | nil
---@return any
---@return component
---@return integer | nil
	function tempLibraries.getFactoryConnectors_R(connection, connected, feedingPort)
		print(connection.internalName, " / ", connected)
		local feedingPort = feedingPort or nil

		if string.match(connected.internalName, "Conveyor") then
			for _, connector in pairs(connected:getFactoryConnectors()) do
				local connectionR = connector:getConnected()
				local connectedR = connectionR.owner

				connection, connected = tempLibraries.getFactoryConnectors_R(connectionR, connectedR, feedingPort)
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
	function self:defineRecipes(includeString, excludeString)
		local recipes = {}
		local recipeTemp = self.machines[1]:getRecipes()

		for _, recipe in pairs(recipeTemp) do
			for _, include in pairs(includeString) do
				if string.find(recipe.name, include) then
					recipes[recipe.name] = recipe
					print(recipe.name .. " has added")
				end
			end
		end

		for name, _ in pairs(recipes) do
			for _, exclude in pairs(excludeString) do
				if string.find(name, exclude) then
					recipes[name] = nil
					print(name .. " has deleted")
				end
			end
		end

		return recipes
	end

---modified logistics function: -0.5 at -inf, 0 at 0, 0.5 at inf
---@param x number
---@return number
	function tempLibraries.LogisticsF(x)
		local temp = math.min(math.maxinteger, math.max(math.mininteger, x))
		temp = (1 / (1 + math.exp(-x))) - 0.5

		return temp
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
					print("feedport " , i-1 , " isOpen: " , splitter.feedport[i], " isFeed: ", isFeed)
					if isFeed then
						print("feedingAmount " , amountToFeed - fedAmount)

						if amountToFeed <= fedAmount then
							splitter.fedAmount = 0
							break
						elseif splitter.feedport[i] and splitter.proxy:transferItem(i-1) then
							print(itemInput.name .. " fed to port #" .. i-1)
							fedAmount = fedAmount + 1
							print(fedAmount, " items fed, ", amountToFeed - fedAmount, " items to feed")
							break
						end
					elseif splitter.proxy:transferItem(i-1) then
						print(itemInput.name .. " overflowed to port #" .. i-1)
						break
					end
				end
				splitter.fedAmount = fedAmount
			end
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
				local m = self.machineFeederPair[s.internalName]
				local inputItem = m:getRecipe():getIngredients()[1] -- currently only the first ingredient, would be configurable

				print(inputItem.type.name, event.value.type.name, inputItem.amount)

				self:runSplitters(event.value.type, inputItem.type, inputItem.amount)
			elseif event.type == "itemOutputted" then -- trace if there's items on the belt

			elseif event.type == "ItemTransfer" then -- trace if there's items on the belt

			elseif event.type == "timeOut" then -- cycle recipe
--				self:cycleRecipe(event.value)
			end
		end
	end

	setmetatable(instance, {__index = self})
	return instance
end


local a = RecipeCycler:new()
a:initializingObjects("Remains")
a:defineRecipes({"Biomass"}, {"Alien"})

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