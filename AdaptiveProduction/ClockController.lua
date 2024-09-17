function pidControl(kP, kI, kD, targetInv, machienProxy)
    local nowError, prevError, integral, derivative = 0, 0, 0, 0
    local productionRate
    local cycleTime = machienProxy.cycleTime

    while true do
        event.pull(cycleTime)
        local readingInv = machienProxy:getInputInv():getStack(0).count

        prevError = nowError
        nowError = targetInv - readingInv
        derivative = nowError - prevError

        if productionRate == machienProxy.maxPotential then
            integral = integral
        else
            integral = integral + nowError
        end
    
        productionRate = kP*nowError + kI*integral + kD*derivative
        machienProxy.potential = productionRate
    end
end