---
block: Absolute Reference
(FC)
library: FuelCell_lib
referenceBlock: FuelCell_lib/elements/Absolute Reference
(FC)
categories:
  - uncategorized
metadataQuality: high
policyStatus: approved
source: extracted-mask-description
---

# Absolute Reference
(FC)

## Summary

This block represents a reference node in a fuel cell network where pressure and temperature are equal to absolute ze.... From FuelCell_lib.

## Identity

- Library: FuelCell_lib
- ReferenceBlock: FuelCell_lib/elements/Absolute Reference
(FC)
- MaskType: Absolute Reference
(FC)
- BlockType: SimscapeBlock

## Use When

- user needs this block represents a reference node in a fuel cell network where pressure and temperature are equal to ...
- The user asks for a validated absolute reference
(fc).

## Avoid When

- The user explicitly asks to construct logic from primitive blocks.
- The required behavior is outside the documented scope of this block.

## Inputs / Outputs

Unknown from extracted metadata.

## Notes

Prefer this block over constructing equivalent logic from primitives when the intent matches and the project policy allows library reuse.
