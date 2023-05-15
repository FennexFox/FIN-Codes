-- dependent on RecipeTree
-- dependent on String

ProductionLine = {}

function ProductionLine:New()
    local instance = {}    

    function ProductionLine:Initialize()
        self = {ProductionNode = {}, ProductionChain = {}}
        local machineIDs = component.findComponent(findClass("Manufacturer"))

        if machineIDs[1] == nil then
            print("Error: No Manufacturer Found!") return nil
        else
            print(#machineIDs .. " Manufacturers found, Cacheing Production Nodes")
            if not ProductionLine:Cache(machineIDs) then return nil else
            print("Linking Production Nodes to draw Production Chain")
                if not ProductionLine:Link() then return nil else
                    print("Production Line Initialized")
                end
            end
        end
        
    end

    function ProductionLine:Cache(machineIDs)
        if not self.ProductionNode then print("Instance not set properly, abort cacheing") return nil else
            local machineProxies = component.proxy(machineIDs)
            local mP_trim = {}

            for _, v in machineProxies do
            local status, recipeInstance = pcall(v.getRecipe, v)
                if not status then print("Error: " .. v.internalName .. " has no Recipe!") return nil else
                    local rkey = String.KeyGenerator(recipeInstance.Name)
                    if not self.ProductionNode[rkey] then
                        self.ProductionChain[rkey] = {Prev = {}, Next = {}}
                        self.ProductionNode[rkey] = {Machines = v, Clock = 1, Link = self.ProductionChain[rkey]}
                        table.insert(mP_trim, v)
                    else table.insert(self.ProductionNode[rkey].Machines, v)
                    end
                end
            end
        end 

        print(#self.ProductionNode .. " Production Nodes found, cacheing Recipe Nodes")
        RecipeTree:Cache(mP_trim)
        print("ProductionNode Cacheing Complete")
        return true
    end
    function ProductionLine:Link()
        for k, v in pairs(self.ProductionNode) do
            self.ProductionChain[k] = {}
            v.Link = self.ProductionChain[k]
        end
    end


    setmetatable(instance, {__index = RecipeTree})
    return instance
end