---
block: Gas Mixture
Properties (FC)
library: FuelCell_lib
referenceBlock: FuelCell_lib/utilities/Gas Mixture
Properties (FC)
categories:
  - uncategorized
metadataQuality: high
policyStatus: approved
source: extracted-mask-description
---

# Gas Mixture
Properties (FC)

## Summary

This block provides ideal gas properties to the connected fuel cell multi-species mixed gas network. The fuel cell ne.... From FuelCell_lib.

## Identity

- Library: FuelCell_lib
- ReferenceBlock: FuelCell_lib/utilities/Gas Mixture
Properties (FC)
- MaskType: Gas Mixture
Properties (FC)
- BlockType: SimscapeBlock

## Use When

- user needs this block provides ideal gas properties to the connected fuel cell multi-species mixed gas network. the f...
- The user asks for a validated gas mixture
properties (fc).

## Avoid When

- The user explicitly asks to construct logic from primitive blocks.
- The required behavior is outside the documented scope of this block.

## Inputs / Outputs

Unknown from extracted metadata.

## Notes

Prefer this block over constructing equivalent logic from primitives when the intent matches and the project policy allows library reuse.
