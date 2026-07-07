---
block: Mass Flow Rate
Sensor (FC)
library: FuelCell_lib
referenceBlock: FuelCell_lib/sensors/Mass Flow Rate
Sensor (FC)
categories:
  - signal-processing
metadataQuality: high
policyStatus: approved
source: extracted-mask-description
---

# Mass Flow Rate
Sensor (FC)

## Summary

This block measures mass and energy flow rates in a fuel cell network. The sensor is ideal and does not affect the pr.... From FuelCell_lib.

## Identity

- Library: FuelCell_lib
- ReferenceBlock: FuelCell_lib/sensors/Mass Flow Rate
Sensor (FC)
- MaskType: Mass Flow Rate
Sensor (FC)
- BlockType: SimscapeBlock

## Use When

- user needs this block measures mass and energy flow rates in a fuel cell network. the sensor is ideal and does not af...
- The user asks for a validated mass flow rate
sensor (fc).

## Avoid When

- The user explicitly asks to construct logic from primitive blocks.
- The required behavior is outside the documented scope of this block.

## Inputs / Outputs

Unknown from extracted metadata.

## Notes

Prefer this block over constructing equivalent logic from primitives when the intent matches and the project policy allows library reuse.
