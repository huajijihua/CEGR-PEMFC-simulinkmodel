# Customer Library Reuse Index

This project has declared reusable Simulink libraries. Prefer these blocks when they match the modeling intent.

## Policy

The active policy mode is defined in `.satk/block-policy.json`.

- Always use customer library blocks when available. 
- Do NOT make domain-level judgments about library relevance.
- Never fall back to built-in primitives if the same block exists in a declared library.
- Only use built-in blocks when NO equivalent exists in any declared customer library after your search.
- Do not invent customer block names.
- If uncertain, inspect the relevant category page or ask the user.
- CRITICAL: Before using ANY block, search this index and the category pages for that specific block type first

## Libraries

- FuelCell_lib: MathWorks FuelCell four-species Simscape example library for PEMFC-cEGR physical network construction
- RouteAEjector_lib: Project FuelCell-domain three-port quasi-steady ejector component for post-intercooler passive cEGR

## Commonly Used Blocks

- [[blocks/Constant_Volume_Chamber__FC_]] — This block models mass and energy capacitance in a fuel cell network. The chamber represents a control volume of a ga... from FuelCell_lib
- [[blocks/Mass_Flow_Rate_Source__FC_]] — The block represents an ideal mechanical energy source in a fuel cell multi-species mixed gas network that can mainta... from FuelCell_lib
- [[blocks/Pressure_Source__FC_]] — This block represents an ideal mechanical energy source in a fuel cell multi-species mixed gas network that can maint... from FuelCell_lib
- [[blocks/Volumetric_Flow_Rate_Source__FC_]] — The block represents an ideal mechanical energy source in a fuel cell multi-species mixed gas network that can mainta... from FuelCell_lib
- [[blocks/Membrane_Electrode_Assembly]] — This block models a stack of membrane electrode assemblies (MEA) for a proton exchange membrane (PEM) fuel cell. Hydr... from FuelCell_lib
- [[blocks/Ejector__FC_]] — The component preserves four-species mass, species, and energy balance. It is a gas-phase L2 component and does not m... from RouteAEjector_lib
- [[blocks/Composition_and_Humidity_Sensor__FC_]] — This block measures the species composition (mass and mole fraction) as well as the relative humidity for species tha... from FuelCell_lib
- [[blocks/Flow_Resistance__FC_]] — This block represents a generic pressure loss in a fuel cell network. The drop in pressure is proportional to the squ... from FuelCell_lib
- [[blocks/Local_Restriction__FC_]] — This block models the pressure loss due to a flow area restriction such as a valve or an orifice in a fuel cell netwo... from FuelCell_lib
- [[blocks/Pipe__FC_]] — This block models pipe flow dynamics for a fuel cell network due to viscous friction losses and convective heat trans... from FuelCell_lib
- [[blocks/Reservoir__FC_]] — This block sets constant boundary conditions in a fuel cell network. The volume inside the reservoir is assumed to be... from FuelCell_lib
- [[blocks/Mass_Flow_Rate_Sensor__FC_]] — This block measures mass and energy flow rates in a fuel cell network. The sensor is ideal and does not affect the pr... from FuelCell_lib
- [[blocks/Absolute_Reference__FC_]] — This block represents a reference node in a fuel cell network where pressure and temperature are equal to absolute ze... from FuelCell_lib
- [[blocks/Cap__FC_]] — This block represents a terminus in a fuel cell network. There is no mass or energy flow through the cap. This block ... from FuelCell_lib
- [[blocks/Infinite_Flow_Resistance__FC_]] — This block represents a break in a fuel cell network. There is no mass or energy flow through the break. However, gas... from FuelCell_lib
- [[blocks/Gas_Mixture_Properties__FC_]] — This block provides ideal gas properties to the connected fuel cell multi-species mixed gas network. The fuel cell ne... from FuelCell_lib

## Categories

- [[uncategorized]] — blocks with insufficient metadata for confident categorization
- [[control]] — PID controllers, regulators, feedback components
- [[signal-processing]] — filters, scaling, interpolation, signal conditioning
- [[plant-models]] — physical dynamics, thermal, mechanical models
- [[sensors]] — sensor interfaces, measurement blocks, transducers
- [[power]] — inverters, converters, motors, power stage components
