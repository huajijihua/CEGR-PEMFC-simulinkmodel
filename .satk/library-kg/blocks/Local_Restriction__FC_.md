---
block: Local Restriction
(FC)
library: FuelCell_lib
referenceBlock: FuelCell_lib/elements/Local Restriction
(FC)
categories:
  - signal-processing
metadataQuality: high
policyStatus: approved
source: extracted-mask-description
---

# Local Restriction
(FC)

## Summary

This block models the pressure loss due to a flow area restriction such as a valve or an orifice in a fuel cell netwo.... From FuelCell_lib.

## Identity

- Library: FuelCell_lib
- ReferenceBlock: FuelCell_lib/elements/Local Restriction
(FC)
- MaskType: Local Restriction
(FC)
- BlockType: SimscapeBlock

## Use When

- user needs this block models the pressure loss due to a flow area restriction such as a valve or an orifice in a fuel...
- The user asks for a validated local restriction
(fc).

## Avoid When

- The user explicitly asks to construct logic from primitive blocks.
- The required behavior is outside the documented scope of this block.

## Inputs / Outputs

Unknown from extracted metadata.

## Notes

Prefer this block over constructing equivalent logic from primitives when the intent matches and the project policy allows library reuse.
