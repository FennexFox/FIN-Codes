# FIN-Codes
Some randome Ficsit-Netowork projects I use in my Satisfactory playthrough

## FicsitOS<sup>tm</sup>
Some Out-Of-Box<sup>tm</sup> OS-thingy, primariliy comes with a bsic blueprint-thingy for standard IO terminal with CLI and Package Installer to import some libary-thingies from online(this github, maybe?) or from mainframe of your factory, to reduce ad-hoc implementations all over the factories and efficient installations on new production sites. Might be a fork of [this resource](https://discord.com/channels/735877487808086088/735879752522399804/1259111023093485630)?

## BasicLibraries<sup>OOD</sup>
Some useful libraries like unit conversion, vanilla sign control and etc. Need to be updated to use Structs and other stuffs.

## LogisticsControl
I wanted to keep track of non-belt logistics, so I tried to code some control systems and its database. I need some more time to figure out what to do. It would heavily utilize [`ModularLoadBalancer`](https://ficsit.app/mod/LoadBalancers). Might have a few features from cancelled `AdaptiveProduction`.

## ElevatorSystem
The primary purpose is to lock the elevator door when the cabin is not at the floor, so you won't fall off; which is not yet possible due to [`LinearMotion`](https://ficsit.app/mod/LinearMotion) limitations. Hopefully, this will be resolved soon<sup>tm</sup>. Secondary purposes are to make a nice-looking and practical interface console and indicators.
