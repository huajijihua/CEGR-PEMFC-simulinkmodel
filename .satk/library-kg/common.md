# Common Customer Blocks

Prefer these blocks when their intent matches the user request.

| Intent | Preferred Block | Library | Notes |
|---|---|---|---|
| this block models mass and energy capacitance in a fuel c... | [[blocks/Constant_Volume_Chamber__FC_]] | FuelCell_lib | This block models mass and energy capacitance in a fuel cell network. The chamber represents a control volume of a ga... |
| the block represents an ideal mechanical energy source in... | [[blocks/Mass_Flow_Rate_Source__FC_]] | FuelCell_lib | The block represents an ideal mechanical energy source in a fuel cell multi-species mixed gas network that can mainta... |
| this block represents an ideal mechanical energy source i... | [[blocks/Pressure_Source__FC_]] | FuelCell_lib | This block represents an ideal mechanical energy source in a fuel cell multi-species mixed gas network that can maint... |
| the block represents an ideal mechanical energy source in... | [[blocks/Volumetric_Flow_Rate_Source__FC_]] | FuelCell_lib | The block represents an ideal mechanical energy source in a fuel cell multi-species mixed gas network that can mainta... |
| this block models a stack of membrane electrode assemblie... | [[blocks/Membrane_Electrode_Assembly]] | FuelCell_lib | This block models a stack of membrane electrode assemblies (MEA) for a proton exchange membrane (PEM) fuel cell. Hydr... |
| the component preserves four-species mass | [[blocks/Ejector__FC_]] | RouteAEjector_lib | The component preserves four-species mass, species, and energy balance. It is a gas-phase L2 component and does not m... |
| this block measures the species composition (mass and mol... | [[blocks/Composition_and_Humidity_Sensor__FC_]] | FuelCell_lib | This block measures the species composition (mass and mole fraction) as well as the relative humidity for species tha... |
| this block represents a generic pressure loss in a fuel c... | [[blocks/Flow_Resistance__FC_]] | FuelCell_lib | This block represents a generic pressure loss in a fuel cell network. The drop in pressure is proportional to the squ... |
| this block models the pressure loss due to a flow area re... | [[blocks/Local_Restriction__FC_]] | FuelCell_lib | This block models the pressure loss due to a flow area restriction such as a valve or an orifice in a fuel cell netwo... |
| this block models pipe flow dynamics for a fuel cell netw... | [[blocks/Pipe__FC_]] | FuelCell_lib | This block models pipe flow dynamics for a fuel cell network due to viscous friction losses and convective heat trans... |
| this block sets constant boundary conditions in a fuel ce... | [[blocks/Reservoir__FC_]] | FuelCell_lib | This block sets constant boundary conditions in a fuel cell network. The volume inside the reservoir is assumed to be... |
| this block measures mass and energy flow rates in a fuel ... | [[blocks/Mass_Flow_Rate_Sensor__FC_]] | FuelCell_lib | This block measures mass and energy flow rates in a fuel cell network. The sensor is ideal and does not affect the pr... |
| this block represents a reference node in a fuel cell net... | [[blocks/Absolute_Reference__FC_]] | FuelCell_lib | This block represents a reference node in a fuel cell network where pressure and temperature are equal to absolute ze... |
| this block represents a terminus in a fuel cell network | [[blocks/Cap__FC_]] | FuelCell_lib | This block represents a terminus in a fuel cell network. There is no mass or energy flow through the cap. This block ... |
| this block represents a break in a fuel cell network | [[blocks/Infinite_Flow_Resistance__FC_]] | FuelCell_lib | This block represents a break in a fuel cell network. There is no mass or energy flow through the break. However, gas... |
| this block provides ideal gas properties to the connected... | [[blocks/Gas_Mixture_Properties__FC_]] | FuelCell_lib | This block provides ideal gas properties to the connected fuel cell multi-species mixed gas network. The fuel cell ne... |
