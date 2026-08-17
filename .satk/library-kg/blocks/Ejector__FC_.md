---
block: Ejector (FC)
library: RouteAEjector_lib
referenceBlock: RouteAEjector_lib/Ejector (FC)
categories:
  - power
metadataQuality: high
policyStatus: approved
source: extracted-mask-description
---

# Ejector (FC)

## Summary

The component preserves four-species mass, species, and energy balance. It is a gas-phase L2 component and does not m.... From RouteAEjector_lib.

The current formal copy keeps `ejector_enabled=false` for the cold-start baseline. Enable the pressure-driven equations only after pressure-window and initialization validation.

## Identity

- Library: RouteAEjector_lib
- ReferenceBlock: RouteAEjector_lib/Ejector (FC)
- MaskType: Ejector (FC)
- BlockType: SimscapeBlock

## Use When

- user needs the component preserves four-species mass, species, and energy balance. it is a gas-phase l2 component and...
- The user asks for a validated ejector (fc).

## Avoid When

- The user explicitly asks to construct logic from primitive blocks.
- The required behavior is outside the documented scope of this block.

## Inputs / Outputs

Unknown from extracted metadata.

## Notes

Prefer this block over constructing equivalent logic from primitives when the intent matches and the project policy allows library reuse.
