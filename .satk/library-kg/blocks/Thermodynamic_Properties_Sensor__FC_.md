---
block: Thermodynamic
Properties Sensor
(FC)
library: FuelCell_lib
referenceBlock: FuelCell_lib/sensors/Thermodynamic
Properties Sensor
(FC)
categories:
  - signal-processing
metadataQuality: high
policyStatus: approved
source: extracted-mask-description
---

# Thermodynamic
Properties Sensor
(FC)

## Summary

This block measures thermodynamic fluid states in a fuel cell multi-species mixed gas network. There is no mass or en.... From FuelCell_lib.

## Identity

- Library: FuelCell_lib
- ReferenceBlock: FuelCell_lib/sensors/Thermodynamic
Properties Sensor
(FC)
- MaskType: Thermodynamic
Properties Sensor
(FC)
- BlockType: SimscapeBlock

## Use When

- user needs this block measures thermodynamic fluid states in a fuel cell multi-species mixed gas network. there is no...
- The user asks for a validated thermodynamic
properties sensor
(fc).

## Avoid When

- The user explicitly asks to construct logic from primitive blocks.
- The required behavior is outside the documented scope of this block.

## Inputs / Outputs

Unknown from extracted metadata.

## Notes

Prefer this block over constructing equivalent logic from primitives when the intent matches and the project policy allows library reuse.
