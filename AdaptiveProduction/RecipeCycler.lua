local bp = component.proxy(component.findComponent("BiomassProcessor")[1])
local ss = {instances = component.proxy(component.findComponent("SushiSplitter")), itemToFeed}
local BioRecipes = {}

local timeStamp = {bp = 0}
local maxTime = {bp = 90}

function WaitTimeLogistics(x)
	local temp = (1 / (1 + math.exp(-x))) - 0.5

	return temp
end

event.listen(ss.instances[1])

function ss:operate(portsToFeed, Aux)
	local portsToFeed = self.portsToFeed or portsToFeed
	local portsToOverflow = self.portsToOverflow or {}
	local itemToFeed = ss.itemToFeed or Aux
	
	if #portsToFeed  < 1 then print("no feeding ports set!") return end
	if #portsToOverflow < 1 then
		for i = 1, 3 do
			if not portsToFeed[i] then portsToOverflow[i] = i end
		end
	end

	for _, ss in pairs(self.instances) do
		if ss:getInput().type == itemToFeed then
			for i = 1, 3 do
				if portsToFeed[i] then ss:transferItem(i) end
			end
		else
			for i = 1, 3 do
				if portsToOverflow[i] then ss:transferItem(i) end
			end
		end
	end
end

Recipes = bp:getRecipes()

for k, v in pairs(Recipes) do
  if string.find(v.name, "Biomass") and not string.find(v.name, "Protein") then
  	BioRecipes[v.name] = v
  end
end

local recipeData = {}

while true do
    for n, r in pairs(BioRecipes) do
		event.pull(1)

		if not bp:getRecipe() then bp:setRecipe(r) end
		if not recipeData.bp then recipeData.bp = bp:getRecipe() end

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