---
block: Velocity Sensor (FC)
library: FuelCell_lib
referenceBlock: FuelCell_lib/sensors/Velocity Sensor (FC)
categories:
  - signal-processing
metadataQuality: high
policyStatus: approved
source: extracted-mask-description
---

# Velocity Sensor (FC)

## Summary

This block measures the velocity in a fuel cell multi-species mixed gas network. The sensor is ideal so there are no .... From FuelCell_lib.

## Identity

- Library: FuelCell_lib
- ReferenceBlock: FuelCell_lib/sensors/Velocity Sensor (FC)
- MaskType: Velocity Sensor (FC)
- BlockType: SimscapeBlock

## Use When

- user needs this block measures the velocity in a fuel cell multi-species mixed gas network. the sensor is ideal so th...
- The user asks for a validated velocity sensor (fc).

## Avoid When

- The user explicitly asks to construct logic from primitive blocks.
- The required behavior is outside the documented scope of this block.

## Inputs / Outputs

Unknown from extracted metadata.

## Notes

Prefer this block over constructing equivalent logic from primitives when the intent matches and the project policy allows library reuse.
