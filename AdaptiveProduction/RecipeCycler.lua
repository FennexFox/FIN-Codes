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
	local temp = 1 / (1 + math.exp(x))

	print("temp: " .. temp)
	return temp
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

		if not bp:getRecipe() then bp:setRecipe(r) end
		if not recipeData.bp then recipeData.bp = bp:getRecipe() end

		local inputStack = bp:getInputInv():getStack(0)
		local inputDemand = inputStack.item.type or recipeData.bp:getIngredients()[1].type
		local inputAmount = recipeData.bp:getIngredients()[1].amount
		local transferQue, waitTime

		if inputAmount == inputStack.count % inputAmount then waitTime = 0
		else waitTime = inputStack.count % inputAmount
		end
		print(waitTime)

		waitTime = math.min(1 / waitTime, math.maxinteger)
		print("wT2 " .. waitTime)
		waitTime = waitTimeLogistics(waitTime)
		print("wT1 " .. waitTime)
		waitTime = waitTime * (maxTime.bp - recipeData.bp.duration) + recipeData.bp.duration
		print("wT " .. waitTime)
	
		if r ~= recipeData.bp then
			print(n .. " not matching with set recipe " .. recipeData.bp.name)
			if inputStack.count < recipeData.bp:getIngredients()[1].amount then
				if computer.magicTime() - timeStamp.bp < math.max(10, waitTime) then
					print("time not passed, jumping loop .. " .. computer.magicTime() - timeStamp.bp)
				else
					print("time passed, switching recipe to " .. n)
					bpConnector:addUnblockedTransfers(-1000)
					--event.pull()
					bpConnector.allowedItem = inputDemand
					bpConnector:addUnblockedTransfers(inputAmount)

					bp:setRecipe(r)
					recipeData.bp = r

					timeStamp.bp = computer.magicTime()
				end
			end
		else
			print(n .. "matching with set recipe " .. bp:getRecipe().name)
			print("update unblockedTransfers .. " .. bpConnector.unblockedTransfers .." of item " .. bpConnector.allowedItem.name)

			transferQue = math.max(recipeData.bp:getIngredients()[1].amount, inputStack.count % r:getIngredients()[1].amount)

			bpConnector.allowedItem = recipeData.bp:getIngredients()[1].type
			bpConnector:addUnblockedTransfers(transferQue - bpConnector.unblockedTransfers)

			print("unblockedTransfers now " .. bpConnector.unblockedTransfers)
		end
--[[		elseif r ~= recipeData.bp then
			print("proceed to set connector, timeStamp at" .. timeStamp.bp)
			
			if not bpConnector.allowedItem == inputDemand then bpConnector.allowedItem = inputDemand end
			if not bp:getRecipe() == r then bp:setRecipe(r) end

			if (computer.time() - timeStamp.bp) / 24 < math.max(10, waitTime) then
				print("matching but time not passed, jumping loop .. " .. (computer.time() - timeStamp.bp)/24)
			else
				timeStamp.bp = computer.time()
			end]]--

		print(math.min(10, waitTime) .. "-" .. computer.magicTime() - timeStamp.bp)
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