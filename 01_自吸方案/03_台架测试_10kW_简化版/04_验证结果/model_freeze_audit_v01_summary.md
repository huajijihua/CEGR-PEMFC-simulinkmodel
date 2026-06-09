# Model Freeze Audit v01 Summary

This audit checks whether the current simplified 10 kW PEMFC/CEGR model is ready for staged no-EGR and CEGR calibration. It does not fit parameters or modify the model.

## Case Set

- Unified cases: 29
- Initial no-EGR cases: 13
- CEGR0608 cases: 16
- EGR fraction equals zero cases: 17
- Positive EGR fraction cases: 12
- Successful v02 simulations: 29 / 29

## Gate Result

- Result: BLOCKED
- Interpretation: fix blocker items before any voltage or CEGR parameter fitting.

- Blocker count: 2
- Warning count: 2

## Blockers

- `oxygen_excess_not_depleted`: value 0, threshold 1. Actual oxygen excess should remain above one; zero values indicate inlet-flow gating or variable handoff problems.
- `actual_stack_inlet_flow_stable`: value 1.39644e+09, threshold 0.02. Actual stack inlet mass flow should not pulse between zero and target flow in the final window.

## Warnings

- `data_outlet_pressure_fields_present`: value 4, threshold 0. Outlet pressure and cathode dp are important fitting targets; missing 20 A values can be filled or excluded from pressure fitting.
- `anode_inlet_pressure_flow_mode_present`: value 0, threshold 1. Current stack core has no K_an_in; anode inlet is set by anode stoichiometry, not linear pressure-flow.

## Flow Coefficient Audit

- K_ca_in: 0.0003 kg/s/kPa, StackParam(38), used as `mInPressure = KcaIn * max(p_in - p_ca, 0)`.
- K_ca_out: 0.00012 kg/s/kPa, StackParam(13), used as cathode outlet pressure-flow coefficient.
- K_an_out: 6.67e-06 kg/s/kPa, StackParam(14), used as anode outlet pressure-flow coefficient.
- K_an_in: not present in the current stack core; anode inlet hydrogen is calculated from anode stoichiometry and Faraday consumption.

## Calibration Start Order

1. Freeze current mass, pressure, water and voltage decomposition equations.
2. Fit no-EGR baseline first: pressure-flow, thermal balance and base voltage parameters.
3. Use CEGR cases after the no-EGR baseline is fixed or weakly adjusted.
4. Do not use direct EGR voltage penalty or free membrane scaling to hide boundary-condition or water-management errors.

## Key Recorded Metrics

- No-EGR voltage RMSE before calibration: 0.00642447 V
- CEGR voltage RMSE before calibration: 0.0160849 V
- Minimum oxygen excess ratio: 0
- Maximum gas residual: 1.0842e-18 kg/s
- Maximum final mMem limiter delta: 0 kg/s
