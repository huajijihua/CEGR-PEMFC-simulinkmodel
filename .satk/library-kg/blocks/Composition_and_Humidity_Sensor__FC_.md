---
block: Composition and
Humidity Sensor (FC)
library: FuelCell_lib
referenceBlock: FuelCell_lib/sensors/Composition and
Humidity Sensor (FC)
categories:
  - sensors
metadataQuality: high
policyStatus: approved
source: extracted-mask-description
---

# Composition and
Humidity Sensor (FC)

## Summary

This block measures the species composition (mass and mole fraction) as well as the relative humidity for species tha.... From FuelCell_lib.

## Identity

- Library: FuelCell_lib
- ReferenceBlock: FuelCell_lib/sensors/Composition and
Humidity Sensor (FC)
- MaskType: Composition and
Humidity Sensor (FC)
- BlockType: SimscapeBlock

## Use When

- user needs this block measures the species composition (mass and mole fraction) as well as the relative humidity for ...
- The user asks for a validated composition and
humidity sensor (fc).

## Avoid When

- The user explicitly asks to construct logic from primitive blocks.
- The required behavior is outside the documented scope of this block.

## Inputs / Outputs

Unknown from extracted metadata.

## Notes

Prefer this block over constructing equivalent logic from primitives when the intent matches and the project policy allows library reuse.
