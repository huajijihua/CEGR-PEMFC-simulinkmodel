# Signal Processing Blocks

Use these blocks for signal processing blocks.

## Recommended Blocks

### Flow Resistance (FC)

- Block: [[blocks/Flow_Resistance__FC_]]
- Library: FuelCell_lib
- ReferenceBlock: FuelCell_lib/elements/Flow Resistance (FC)
- Description: This block represents a generic pressure loss in a fuel cell network. The drop in pressure is proportional to the squ...
- Use when: user needs this block represents a generic pressure loss in a fuel cell network. the drop in pressure is proportional...
- Avoid when: user asks only for a primitive flow resistance (fc) experiment.
- Metadata quality: high

### Local Restriction
(FC)

- Block: [[blocks/Local_Restriction__FC_]]
- Library: FuelCell_lib
- ReferenceBlock: FuelCell_lib/elements/Local Restriction
(FC)
- Description: This block models the pressure loss due to a flow area restriction such as a valve or an orifice in a fuel cell netwo...
- Use when: user needs this block models the pressure loss due to a flow area restriction such as a valve or an orifice in a fuel...
- Avoid when: user asks only for a primitive local restriction
(fc) experiment.
- Metadata quality: high

### Pipe (FC)

- Block: [[blocks/Pipe__FC_]]
- Library: FuelCell_lib
- ReferenceBlock: FuelCell_lib/elements/Pipe (FC)
- Description: This block models pipe flow dynamics for a fuel cell network due to viscous friction losses and convective heat trans...
- Use when: user needs this block models pipe flow dynamics for a fuel cell network due to viscous friction losses and convective...
- Avoid when: user asks only for a primitive pipe (fc) experiment.
- Metadata quality: high

### Reservoir (FC)

- Block: [[blocks/Reservoir__FC_]]
- Library: FuelCell_lib
- ReferenceBlock: FuelCell_lib/elements/Reservoir (FC)
- Description: This block sets constant boundary conditions in a fuel cell network. The volume inside the reservoir is assumed to be...
- Use when: user needs this block sets constant boundary conditions in a fuel cell network. the volume inside the reservoir is as...
- Avoid when: user asks only for a primitive reservoir (fc) experiment.
- Metadata quality: high

### Mass Flow Rate
Sensor (FC)

- Block: [[blocks/Mass_Flow_Rate_Sensor__FC_]]
- Library: FuelCell_lib
- ReferenceBlock: FuelCell_lib/sensors/Mass Flow Rate
Sensor (FC)
- Description: This block measures mass and energy flow rates in a fuel cell network. The sensor is ideal and does not affect the pr...
- Use when: user needs this block measures mass and energy flow rates in a fuel cell network. the sensor is ideal and does not af...
- Avoid when: user asks only for a primitive mass flow rate
sensor (fc) experiment.
- Metadata quality: high

### Pressure and
Temperature Sensor
(FC)

- Block: [[blocks/Pressure_and_Temperature_Sensor__FC_]]
- Library: FuelCell_lib
- ReferenceBlock: FuelCell_lib/sensors/Pressure and
Temperature Sensor
(FC)
- Description: This block measures pressure and temperature in a fuel cell multi-species mixed gas network. There is no mass or ener...
- Use when: user needs this block measures pressure and temperature in a fuel cell multi-species mixed gas network. there is no m...
- Avoid when: user asks only for a primitive pressure and
temperature sensor
(fc) experiment.
- Metadata quality: high

### Thermodynamic
Properties Sensor
(FC)

- Block: [[blocks/Thermodynamic_Properties_Sensor__FC_]]
- Library: FuelCell_lib
- ReferenceBlock: FuelCell_lib/sensors/Thermodynamic
Properties Sensor
(FC)
- Description: This block measures thermodynamic fluid states in a fuel cell multi-species mixed gas network. There is no mass or en...
- Use when: user needs this block measures thermodynamic fluid states in a fuel cell multi-species mixed gas network. there is no...
- Avoid when: user asks only for a primitive thermodynamic
properties sensor
(fc) experiment.
- Metadata quality: high

### Velocity Sensor (FC)

- Block: [[blocks/Velocity_Sensor__FC_]]
- Library: FuelCell_lib
- ReferenceBlock: FuelCell_lib/sensors/Velocity Sensor (FC)
- Description: This block measures the velocity in a fuel cell multi-species mixed gas network. The sensor is ideal so there are no ...
- Use when: user needs this block measures the velocity in a fuel cell multi-species mixed gas network. the sensor is ideal so th...
- Avoid when: user asks only for a primitive velocity sensor (fc) experiment.
- Metadata quality: high

### Volumetric Flow Rate
Sensor (FC)

- Block: [[blocks/Volumetric_Flow_Rate_Sensor__FC_]]
- Library: FuelCell_lib
- ReferenceBlock: FuelCell_lib/sensors/Volumetric Flow Rate
Sensor (FC)
- Description: This block measures volumetric flow rate in a fuel cell multi-species mixed gas network. There is no change in pressu...
- Use when: user needs this block measures volumetric flow rate in a fuel cell multi-species mixed gas network. there is no chang...
- Avoid when: user asks only for a primitive volumetric flow rate
sensor (fc) experiment.
- Metadata quality: high

### Interface (FC-G)

- Block: [[blocks/Interface__FC-G_]]
- Library: FuelCell_lib
- ReferenceBlock: FuelCell_lib/utilities/Interface (FC-G)
- Description: This block represents a flow connection between a Fuel cell network and gas network. Pressure, temperature, and mass ...
- Use when: user needs this block represents a flow connection between a fuel cell network and gas network. pressure, temperature...
- Avoid when: user asks only for a primitive interface (fc-g) experiment.
- Metadata quality: high

## Related Categories

- [[uncategorized]]
- [[control]]
- [[plant-models]]
- [[sensors]]
- [[power]]
