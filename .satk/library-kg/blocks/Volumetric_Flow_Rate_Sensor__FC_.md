---
block: Volumetric Flow Rate
Sensor (FC)
library: FuelCell_lib
referenceBlock: FuelCell_lib/sensors/Volumetric Flow Rate
Sensor (FC)
categories:
  - signal-processing
metadataQuality: high
policyStatus: approved
source: extracted-mask-description
---

# Volumetric Flow Rate
Sensor (FC)

## Summary

This block measures volumetric flow rate in a fuel cell multi-species mixed gas network. There is no change in pressu.... From FuelCell_lib.

## Identity

- Library: FuelCell_lib
- ReferenceBlock: FuelCell_lib/sensors/Volumetric Flow Rate
Sensor (FC)
- MaskType: Volumetric Flow Rate
Sensor (FC)
- BlockType: SimscapeBlock

## Use When

- user needs this block measures volumetric flow rate in a fuel cell multi-species mixed gas network. there is no chang...
- The user asks for a validated volumetric flow rate
sensor (fc).

## Avoid When

- The user explicitly asks to construct logic from primitive blocks.
- The required behavior is outside the documented scope of this block.

## Inputs / Outputs

Unknown from extracted metadata.

## Notes

Prefer this block over constructing equivalent logic from primitives when the intent matches and the project policy allows library reuse.
