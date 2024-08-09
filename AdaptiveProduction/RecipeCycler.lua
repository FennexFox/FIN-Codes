local rp = component.proxy(component.findComponent("RemainsProcessor")[1])
local pp = component.proxy(component.findComponent("ProteinProcessor")[1])
local bp = component.proxy(component.findComponent("BiomassProcessor")[1])
local bs = component.proxy(component.findComponent("BiomassSolidifier")[1])
local psp = component.proxy(component.findComponent("PSProcessor")[1])
local AlienRecipes, BioRecipes, PSRecipes, Reciepes = {}, {}, {}, {}

local bpConnector = bp:getFactoryConnectors()
local timeStamp = {rp = 0, pp = 0, bp = 0, bs = 0, psp = 0}
local maxTime = {rp = 0, pp = 0, bp = 90, bs = 0, psp = 0}

function waitTimeLogistics(x)
	local temp = x
	if type(temp) ~= "number" then temp = math.maxinteger end
	temp = math.exp(temp)
	if type(temp) ~= "number" then temp = math.maxinteger end
	temp = 1 / (1 + temp)
	print("temp: " .. temp)
	return temp + 0.5
end

for _, c in pairs(bpConnector) do
	if c.direction == 0 then bpConnector = c break end
end

for _, c in pairs(bpConnector:getConnected().owner:getFactoryConnectors()) do
	if string.find(c:getConnected().owner.internalName, "Splitter") then bpConnector = c:getConnected() end
end

print(bpConnector.owner)
bpConnector.blocked = true
print(bpConnector.blocked)
if bpConnector.allowedItem then print(bpConnector.allowedItem.name) else print("no Items allowed") end
print(bpConnector.unblockedTransfers)

Recipes = rp:getRecipes()

for k, v in pairs(Recipes) do
  if string.find(v.name, "Protein") and not string.find(v.name, "Biomass") then
    AlienRecipes[v.name] = v
  elseif string.find(v.name, "Biomass") and not string.find(v.name, "Protein") then
  	BioRecipes[v.name] = v
  elseif string.find(v.name, "Power Shard") then
  	PSRecipes[v.name] = v
  end
end

local recipeData = {}

while true do
--	local item = event.pull(1)
--	if item then print(item.name) end

    --[[for n, r in pairs(AlienRecipes) do
        print(r.name)
        if rp:getInputInv():getStack(0).count<1 then
        rp:setRecipe(r)
        recipeDuration = r.duration
        event.pull(1)
        else 
        break
        end
    end]]--
    for n, r in pairs(BioRecipes) do
		event.pull(1)
		if timeStamp.bp == 0 then timeStamp.bp = computer.time() end

		if not bp:getRecipe() then bp:setRecipe(r) end
		if not recipeData.bp then recipeData.bp = bp:getRecipe() end

		local inputStack = bp:getInputInv():getStack(0)
		local inputDemand, transferQue = r:getIngredients()[1].type, 0
		local waitTime = recipeData.bp:getIngredients()[1].amount

		if waitTime == inputStack.count % waitTime then waitTime = 0
		else waitTime = inputStack.count % waitTime
		end
		print(waitTime)

--		waitTime = waitTime - (inputStack.count % waitTime)
		waitTime = 1 / waitTime
		print("wT2 " .. waitTime)
		waitTime = waitTimeLogistics(waitTime)
		print("wT1 " .. waitTime)
		waitTime = waitTime * (maxTime.bp - recipeData.bp:getIngredients()[1].amount)
		waitTime = waitTime + recipeData.bp.duration
		print("wT " .. waitTime)

		print(n .. " not matching with " .. bp:getRecipe().name .. "?")
		print(r ~= bp:getRecipe())
	
		if r ~= bp:getRecipe() then
			if inputStack.count < recipeData.bp:getIngredients()[1].amount then
				if (computer.time() - timeStamp.bp) / 24 < math.max(10, waitTime) then
					print("time not passed, jumping loop .. " .. (computer.time() - timeStamp.bp)/24)
				else
					bpConnector:addUnblockedTransfers(-1000)

					print("not r , change bpConnector and recipe to " .. n)

					bpConnector.allowedItem = inputDemand
					bp:setRecipe(r)
					recipeData.bp = r
					print(n)

					timeStamp.bp = computer.time()
				end
			else
				print("input in inputInv, jumping loop .. " .. (computer.time() - timeStamp.bp)/24)
			end
		elseif not r == recipeData.bp then
			print("proceed to set connector, timeStamp at" .. timeStamp.bp)
			
			if not bpConnector.allowedItem == inputDemand then bpConnector.allowedItem = inputDemand end
			if not bp:getRecipe() == r then bp:setRecipe(r) end

			if (computer.time() - timeStamp.bp) / 24 < math.max(10, waitTime) then
				print("matching but time not passed, jumping loop .. " .. (computer.time() - timeStamp.bp)/24)
			else
				timeStamp.bp = computer.time()
			end
		end
		transferQue = math.max(recipeData.bp:getIngredients()[1].amount, inputStack.count % r:getIngredients()[1].amount)

		bpConnector.allowedItem = recipeData.bp:getIngredients()[1].type
		bpConnector:addUnblockedTransfers(transferQue - bpConnector.unblockedTransfers)

		print(bpConnector.allowedItem.name)
		print(bpConnector.unblockedTransfers)
		print(waitTime)
		print(math.max(10, waitTime) .. "-" .. (computer.time() - timeStamp.bp)/24)
  	end
    --[[for n, r in pairs(PSRecipes) do
    	print(r.name)
    	if psp:getInputInv():getStack(0).count<1 then
    	psp:setRecipe(r)
        recipeDuration = math.min(recipeDuration, r.duration)
        event.pull(1)
        else break
    	end
  	end]]--
end