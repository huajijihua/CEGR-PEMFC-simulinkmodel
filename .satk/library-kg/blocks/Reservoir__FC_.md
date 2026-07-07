---
block: Reservoir (FC)
library: FuelCell_lib
referenceBlock: FuelCell_lib/elements/Reservoir (FC)
categories:
  - signal-processing
metadataQuality: high
policyStatus: approved
source: extracted-mask-description
---

# Reservoir (FC)

## Summary

This block sets constant boundary conditions in a fuel cell network. The volume inside the reservoir is assumed to be.... From FuelCell_lib.

## Identity

- Library: FuelCell_lib
- ReferenceBlock: FuelCell_lib/elements/Reservoir (FC)
- MaskType: Reservoir (FC)
- BlockType: SimscapeBlock

## Use When

- user needs this block sets constant boundary conditions in a fuel cell network. the volume inside the reservoir is as...
- The user asks for a validated reservoir (fc).

## Avoid When

- The user explicitly asks to construct logic from primitive blocks.
- The required behavior is outside the documented scope of this block.

## Inputs / Outputs

Unknown from extracted metadata.

## Notes

Prefer this block over constructing equivalent logic from primitives when the intent matches and the project policy allows library reuse.
