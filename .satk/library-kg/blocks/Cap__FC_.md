---
block: Cap (FC)
library: FuelCell_lib
referenceBlock: FuelCell_lib/elements/Cap (FC)
categories:
  - uncategorized
metadataQuality: high
policyStatus: approved
source: extracted-mask-description
---

# Cap (FC)

## Summary

This block represents a terminus in a fuel cell network. There is no mass or energy flow through the cap. This block .... From FuelCell_lib.

## Identity

- Library: FuelCell_lib
- ReferenceBlock: FuelCell_lib/elements/Cap (FC)
- MaskType: Cap (FC)
- BlockType: SimscapeBlock

## Use When

- user needs this block represents a terminus in a fuel cell network. there is no mass or energy flow through the cap. ...
- The user asks for a validated cap (fc).

## Avoid When

- The user explicitly asks to construct logic from primitive blocks.
- The required behavior is outside the documented scope of this block.

## Inputs / Outputs

Unknown from extracted metadata.

## Notes

Prefer this block over constructing equivalent logic from primitives when the intent matches and the project policy allows library reuse.
