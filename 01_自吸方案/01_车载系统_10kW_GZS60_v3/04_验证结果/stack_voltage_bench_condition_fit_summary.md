# Bench-Condition Stack Voltage Fit Summary

Date: 2026-06-05

## Scope

- Voltage fitting uses bench stack test conditions only.
- The vehicle humidifier, compressor, intercooler and cooling auxiliaries are not fitting targets.
- The voltage equation is rewritten in direct book theta form.
- Accepted candidate auto-applied: true.

## Formula

- `V_cell = V_nt - V_act - V_ohm - V_conc`
- `V_nt = 1.229 - 8.5e-4*(T_st - 298.15) + R*T_st/(2F)*ln(pH2*sqrt(pO2))`
- `V_act = theta1 + theta2*T_st + theta3*T_st*ln(C_O2) + theta4*T_st*ln(I_st)`
- `C_O2 = 1.97e-7*pO2*exp(498/T_st)`
- `V_ohm = I_st*(L_m/(A_cell*(theta5*lambda_m+theta6)*exp(theta7*(1/303.15-1/T_st))) + theta8)`
- `V_conc = theta9*exp(theta10*I_st)`

## Bench Condition Fit

- Raw book reference RMSE: 5.4302 V/cell, high-current bias -5.1359 V/cell.
- Current applied params RMSE: 0.0047 V/cell, high-current bias -0.0011 V/cell.
- Book-theta refit RMSE: 0.0042 V/cell, high-current bias -0.0025 V/cell.
- Selected candidate: book_theta_refit (bench stack condition fit passes error and sign gates).
- Selected RMSE: 0.0042 V/cell, max abs 0.0071 V/cell.
- Selected max positive voltage step: 0.0000 V/cell.
- Selected terms physical: true.

## Parameter Movement

- theta1: 0.7084 -> 0.30834965 -> 0.30401719.
- theta2: 0.00143 -> 2.1394978e-05 -> 2.2530616e-05.
- theta3: -0.0001527 -> -1.0358993e-26 -> -2.4322043e-40.
- theta4: 0.0001043 -> 6.2251637e-05 -> 6.6267871e-05.
- theta5: 0.525 -> 0.094296359 -> 0.045547324.
- theta6: 0.2173 -> 0.014595518 -> 6.5768466e-05.
- theta7: -302.06 -> -6.9768547e-17 -> -1.5287418.
- theta8: 0.000513 -> 0.00015630667 -> 9.6381364e-05.
- theta9: 5.2e-10 -> 7.9414035e-41 -> 2.4286926e-06.
- theta10: 0.0335 -> 5.9886101e-15 -> 0.009792891.

## Decision

- Decision: bench_condition_voltage_refit_candidate_accepted.
- Accepted candidate is applied to `00_输入参数/电堆物理模型/stack_voltage_book_theta_params.csv`.
- Do not fit voltage parameters against vehicle auxiliary boundary errors.

## Output Files

- `04_验证结果/stack_voltage_bench_condition_fit_diagnostic.csv`
- `04_验证结果/stack_voltage_bench_condition_fit_candidates.csv`
- `04_验证结果/stack_voltage_bench_candidate_vehicle_check.csv`
- `00_输入参数/电堆物理模型/stack_voltage_book_theta_params_candidate.csv`
- `00_输入参数/电堆物理模型/stack_voltage_book_theta_params.csv`
