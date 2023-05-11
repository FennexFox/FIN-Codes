-- dependent on IO

VMInterface = {}

function VMInterface:New(Identifier, Name)
    local instance = InterfaceComps:New(Identifier, Name)
    local base = InterfaceComps:New(Identifier, Name)

    instance.VeNumSeed = {}
    instance.Vehicle = {}
    instance.Location = "WA" -- Temporal
    instance.Vehicle.Type = 2 -- Temporal

    function instance:FetchNumbers(veNumSeed)
        self.VeNumSeed = veNumSeed
        self.Comps.Regi.NumDial1.max, self.Comps.Regi.NumDial2.max = math.modf(self.OccupiedNumbers/100)
        self.Comps.Regi.NumDial2.max = self.Comps.Regi.NumDial2.max * 100
    end

    function instance:RegiNumScr()
        local key = self.Comps.Regi.NumDial1.value * 100 + self.Comps.Regi.NumDial2.value

        if self.VeNumSeed[key] < 1000 then
            self.Comps.Regi.NumScr:setText(0 .. self.VeNumSeed[key] .. instance.Location .. instance.Vehicle.Type)
        else
            self.Comps.Regi.NumScr:setText(self.VeNumSeed[key] .. instance.Location .. instance.Vehicle.Type)
        end
    end

    function instance:RegiRand()
        local key = math.random(#self.VeNumSeed)

        if key < 1000 then
            self.Comps.Regi.NumScr:setText(0 .. self.VeNumSeed[key] .. instance.Location .. instance.Vehicle.Type)
        else
            self.Comps.Regi.NumScr:setText(self.VeNumSeed[key] .. instance.Location .. instance.Vehicle.Type)
        end
    end

    function instance:On()
        self:RegiOn()
        self:AssignOn()
        base.On(self)
    end

    function instance:RegiOn()
        self.isOn.Regi = true
       
        for _, v in pairs(self.Comps.Regi) do
            if pcall(function() v:setColor(1, 1, 1, 0.1) end) then v:setColor(1, 1, 1, 0.1) end
            event.listen(v)
        end
        
        self.Comps.Powers.Regi:setColor(0, 1, 0, 0.1)
        self.Comps.Regi.Rand:setColor(0, 1, 0, 0.1)

        self.Comps.Regi.Scr.text = "Standby"
        self.Comps.Regi.NumScr:setText("0000__0")        
    end

    function instance:AssignOn()
        self.isOn.Assign = true
        
        for _, v in pairs(self.Comps.Assign) do
            if pcall(function() v:setColor(1, 1, 1, 0.1) end) then v:setColor(1, 1, 1, 0.1) end
            event.listen(v)
        end
        self.Comps.Powers.Assign:setColor(0, 1, 0, 0.1)

        self.Comps.Assign.Scr.text = "Standby"
    end

    function instance:Off()
        self:RegiOff()
        self:AssignOff()
        base.Off(self)

        for _, v in pairs(self.Comps.Powers) do
            event.listen(v)
        end
    end

    function instance:RegiOff()
        self.isOn.Regi = false
       
        for _, v in pairs(self.Comps.Regi) do
            if pcall(function() v:setColor(0, 0, 0, 0) end) then v:setColor(0, 0, 0, 0) end
            event.ignore(v)
        end        
        self.Comps.Powers.Regi:setColor(0, 0, 0, 0)

        self.Comps.Regi.Scr.text = ""
        self.Comps.Regi.NumScr:setText("")
    end

    function instance:AssignOff()
        self.isOn.Assign = false
        
        for _, v in pairs(self.Comps.Assign) do
            if pcall(function() v:setColor(0, 0, 0, 0) end) then v:setColor(0, 0, 0, 0) end
            event.ignore(v)
        end
        self.Comps.Powers.Assign:setColor(0, 0, 0, 0)

        self.Comps.Assign.Scr.text = ""

    end

    function instance:AssignNo()
        print('Not Set Yet')
    end

    function instance:Initialize() -- set location and vm

        for i = 1, 9999 do
            table.insert(self.VeNumSeed, i)
        end

        base.Set(self, {0, 8, 0}, {"Powers", "Panel"})
        base.Set(self, {0, 6, 0}, {"Powers", "Regi"})
        self.Comps.Powers.Regi:setColor(0, 0, 0, 0)        
        base.Set(self, {0, 3, 0}, {"Powers", "Assign"})
        self.Comps.Powers.Assign:setColor(0, 0, 0, 0)

        base.Set(self, {3, 8, 0}, {"Regi", "Scr"})
        self.Comps.Regi.Scr.monospace = true self.Comps.Regi.Scr.size = 50
        base.Set(self, {2, 5, 0}, {"Regi", "NumScr"})
        self.Comps.Regi.NumScr:setColor(0, 0, 0, 0)
        base.Set(self, {4, 5, 0}, {"Regi", "NumDial1"})
        self.Comps.Regi.NumDial1.min = 0 self.Comps.Regi.NumDial1.max = 99
        base.Set(self, {5, 5, 0}, {"Regi", "NumDial2"})
        self.Comps.Regi.NumDial2.min = 0 self.Comps.Regi.NumDial2.max = 99
        base.Set(self, {8, 5, 0}, {"Regi", "Rand"})
        self.Comps.Regi.Rand:setColor(0, 0, 0, 0)
        
        base.Set(self, {8, 8, 0}, {"Assign", "Scr"})
        self.Comps.Assign.Scr.monospace = true self.Comps.Assign.Scr.size = 50
        base.Set(self, {2, 2, 0}, {"Assign", "Fr"})
        self.Comps.Assign.Fr:setColor(0, 0, 0, 0)
        base.Set(self, {2, 1, 0}, {"Assign", "FrScr"})
        self.Comps.Assign.FrScr:setColor(0, 0, 0, 0)
        base.Set(self, {3, 2, 0}, {"Assign", "To"})
        self.Comps.Assign.To:setColor(0, 0, 0, 0)
        base.Set(self, {3, 1, 0}, {"Assign", "ToScr"})
        self.Comps.Assign.ToScr:setColor(0, 0, 0, 0)
        base.Set(self, {4, 2, 0}, {"Assign", "Cargo"})
        base.Set(self, {8, 2, 0}, {"Assign", "Mode"})
        self.Comps.Assign.Mode:setColor(0, 0, 0, 0)
        base.Set(self, {8, 1, 0}, {"Assign", "ModeScr"})
        self.Comps.Assign.ModeScr:setColor(0, 0, 0, 0)
        base.Set(self, {9, 2, 0}, {"Assign", "No"})
        self.Comps.Assign.No.min = 0 self.Comps.Assign.No.max = 10
        base.Set(self, {9, 1, 0}, {"Assign", "NoScr"})
        self.Comps.Assign.NoScr:setColor(0, 0, 0, 0)
    end

    function instance:Run(e, s, sender, port, data)
        local powers, regi, assign = self.Comps.Powers, self.Comps.Regi, self.Comps.Assign

        if e == "ChangeState" and s == powers.Panel then
            if sender then
                self:On()
            else
                self:Off()
            end
        elseif e == "Trigger" then
            if s == powers.Regi then
                if self.isOn.Regi then
                    self:RegiOff()
                else
                    self:RegiOn()
                end
            elseif s == powers.Assign then
                if self.isOn.Assign then
                    self:AssignOff()
                else
                    self:AssignOn()
                end
            elseif s == regi.Rand then
                self:RegiRand()
            end
        elseif e == "valueChanged" then
            if s == regi.NumDial1 or s == regi.NumDial2 then
                self:RegiNumScr()
            elseif s == assign.No then
                self:AssignNoScr()
            end
        end

    end

    return instance

end