local RecipeCycler = {}

function RecipeCycler:new()
	local instance, groupDict = {}, {}

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

		if #temps > 0 then
			self:initBuildables(nick, includeString, excludeString, temps)
			self:pairBuildables(nick)
		end
	end

	function self:initBuildables(nick, includeString, excludeString, comps)
		for _, comp in pairs(comps) do
			local className = comp:getType().name
			groupDict[comp.internalName] = nick

			if string.match(className, "Constructor") then
				local machine = {proxy = comp, recipeNow = nil, recipeOrder = 1, state = 0}
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

	function self:pairBuildables(nick)
		for machineName, machine in pairs(self[nick].machines) do
			local connection
			for _, connector in pairs(machine.proxy:getFactoryConnectors()) do
				if connector.direction == 0 then connection = connector break end
			end

			local connected  = connection:getConnected().owner
			local connection, splitter, feedingPort = self:getFactoryConnectors_R(connection, connected, nick)

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

	function self:getFactoryConnectors_R(connection, connected, feedingPort, group)
		print(connection.internalName, " / ", connected)
		local feedingPort = feedingPort or nil

		if string.match(connected.internalName, "Conveyor") then
			for _, connector in pairs(connected:getFactoryConnectors()) do
				local connectionR = connector:getConnected()
				local connectedR = connectionR.owner

				connection, connected = self:getFactoryConnectors_R(connectionR, connectedR, feedingPort, group)
				if string.match(connected.internalName, "Splitter") then
					feedingPort = connection.internalName
					break
				end
			end
		end

		return connection, connected, feedingPort
	end

	function self:eventListener(deltaTime, filterString)
		local filterString = filterString or nil
		local event = {event.pull(deltaTime, filterString)}
		local e, s, v, t, data = (function(e, s, v, ...)
			return e, s, v, computer.magicTime(), {...}
		end)(table.unpack(event))

		if e then
			event = {type = e, sender = s, value = v, time = t, otherData = data}
			if e == "ItemRequest" then event.value = event.value or event.sender:getInput() end
		else
			event = {type = "TimeOut", sender = "Ficsit_OS", value = "magicTime", time = t}
		end

		return event
	end



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



	function self:waitTime(inputCount, inputAmount, recipeDuration, group)
		local temp = inputAmount - (inputCount % inputAmount)
		temp = inputAmount / temp

		temp = math.min(math.maxinteger, math.max(math.mininteger, temp))
		temp = (1 / (1 + math.exp(-temp+1))) - 0.5

		local waitTime = 2 * temp * (group.maxTime - recipeDuration) + recipeDuration
		waitTime = math.max(group.minTime, waitTime)

		return math.floor(waitTime*100+0.5)/100
	end



	function self:runSplitter(itemInput, itemToFeed, amountToFeed, splitterData)
		local isFeed = itemInput == itemToFeed

		local splitter = splitterData.proxy
		for i = 0, 2 do
			local outputPort = splitter:getConnectorByIndex(i)
			if outputPort.isConnected  then
				if isFeed then
					if splitterData.outputPort[i] then
						local feedPort = splitterData.outputPort[i]
						if amountToFeed > splitterData.outputPort[i].fedAmount then
							if  splitter:transferItem(i) then
								feedPort.fedAmount = feedPort.fedAmount + 1
								splitterData.fedAmountTotal = splitterData.fedAmountTotal + 1
							end
						end
					elseif (amountToFeed * splitterData.portsToFeed) <= splitterData.fedAmountTotal then
						splitter:transferItem(i)
					end
				elseif not splitterData.outputPort[i] then
					splitter:transferItem(i)
				end
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
		local waitMore = (inputCount >= inputAmount) or (machine.state == 1)

		if waitMore then
			group.pairs[machineName].timeStamp = computer.magicTime()
		elseif timePassed > waitTime then
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



	function self:main(deltaTime, feedMultiplier)

		while true do
		local event = self:eventListener(deltaTime)

			if event.type == "ItemRequest" then -- transfer items
				local splitterName = event.sender.internalName
				local group = self[groupDict[splitterName]]
				local machineData = group.pairs[splitterName].machine
				local splitterData = group.pairs[splitterName].splitter

				local recipe = machineData.recipeNow or machineData.proxy:getRecipe()
				local inputItem = recipe:getIngredients()[1] -- currently only the first ingredient, would be configurable

				self:runSplitter(event.value.type, inputItem.type, inputItem.amount * feedMultiplier, splitterData)
			elseif event.type == "ItemOutputted" then -- trace if there's items on the belt
				local splitterName = event.sender.internalName
				local group = self[groupDict[splitterName]]
				local timeStamp = group.pairs[splitterName].timeStamp

				if timeStamp + deltaTime <= computer.magicTime() then
					self:cycleRecipe(group.recipes, group)
				end

			elseif event.type == "ItemTransfer" then -- trace if there's items on the belt

			elseif event.type == "ProductionChanged" and event.value == 1 then
				local machineName = event.sender.internalName
				local group = self[groupDict[machineName]]
				local machineData = group.pairs[machineName].machine

				machineData.state = event.value
			elseif event.type == "TimeOut" then -- cycle recipe
				for _, group in pairs(self) do
					self:cycleRecipe(group.recipes, group)
				end
			end
		end
	end

  setmetatable(instance, {__index = self})
  return instance
end

local SushiBelt = RecipeCycler:new()
SushiBelt:initGroup("Biomass", {"Biomass"}, {"Protein"}, 20, 5)
SushiBelt:initGroup("Alien", {"Protein"}, {"Biomass"}, 10, 5)
SushiBelt:initGroup("PowerShard", {"Power"}, {}, 10, 5)
SushiBelt:initGroup("misc", {"Color", "Concrete", "Silica", "Solid", "DNA", "Ingot"}, {"Pure"}, 60, 5)

event.clear()
SushiBelt:main(1, 100)