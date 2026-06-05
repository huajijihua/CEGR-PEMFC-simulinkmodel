# Condition Extension Summary

Date: 2026-06-05 19:29:45
Run mode: `egr_ratio`.

## Frozen No-EGR Baseline
- points: 13
- pressure_order_ok: 13/13
- V_cell RMSE vs bench: 0.0085 V/cell
- T_stack range: 61.90-80.29 C
- pO2_ca_in range: 27.72-47.72 kPa
- min lambda_O2_actual: 1.788

## Same-Current EGR Ratio Scan
- points: 30
- severe oxygen starvation points: 0
- EGR results are qualitative trend checks only.

## Boundary
- Frozen no-EGR baseline uses the current pressurefix + thermal Stage A + humidifier-first + bench-voltage-fit parameter set.
- EGR ratio is `m_egr / m_humidifier_wet_out`.
- If `lambda_O2_actual < 1`, the point is marked as severe oxygen starvation and should not be interpreted as normal stack operation.
- For constant-pO2 EGR, the target is the same-current no-EGR `pO2_ca_in_kPa`.
