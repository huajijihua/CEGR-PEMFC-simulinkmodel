# R00 baseline and interface freeze v02

## Record metadata

| Field | Value |
|---|---|
| Record ID | `R00_baseline_and_interface_freeze_20260724_v02` |
| Phase | Phase 0: asset, baseline, and interface freeze |
| Status | `PASSED_WITH_OPEN_RISKS` |
| Date | 2026-07-24 (Asia/Shanghai) |
| Executor | RouteA_v2 sole main execution agent |
| Previous record | `R00_baseline_and_interface_freeze_20260724_v01.md` |
| Model | `RouteA_v2_GasMixture_Derived/PEMFuelCellSystem_GasMixture_cEGR_RouteA_v2_v01.slx` |
| Model root | `PEMFuelCellSystem_GasMixture_cEGR_RouteA_v2_v01` |

## Scope and immutable boundaries

This record covers the required read-only inventory and interface audit. No `.slx` structure, model parameter, MATLAB script, result file, initial-state file, or cache was modified. No update, compile, `sim`, `parsim`, `save_system`, or model save was executed.

The audit uses the v2 tree only. The original RouteA tree, support material, archive, and existing unrelated dirty changes were not modified, staged, or cleaned.

## Baseline and assets

| Asset | Evidence and current meaning |
|---|---|
| v2 model | `E:\agentwork_pemfc_cEGR_0519\RouteA_v2_PEMFC_cEGR_simulink\01_模型\RouteA_v2_GasMixture_Derived\PEMFuelCellSystem_GasMixture_cEGR_RouteA_v2_v01.slx`; SHA256 `0211A2FEE5BE4DA06A792ADBA80CC49CC34A4FEC65A854A7B5097F5B82DC81EB`; 275,383 bytes; unchanged during this audit. |
| v2 parameter source | `...\01_模型\RouteA_v2_GasMixture_Derived\PEMFuelCellSystemWithACustomLibraryParameters.m`; model workspace readback is `routeA_parameter_layer="platform_default"`, `routeA_external_case_enabled=false`. |
| Drive-cycle support | `...\PEMFuelCellSystemWithACustomLibraryDriveCycle.mat`; retained as an input asset, not a runtime result. |
| Initial state | `...\RouteA_v2_legacy_source_initial_state_from_RouteA_v01.mat`; explicitly legacy-source convenience only. It is not v2 formal evidence and is not treated as a closed cold initial state. |
| Active script tree | `...\03_脚本\RouteA_v2_GasMixture_Derived\`; `run_routeA_electrical_boundary_study.m` is the only formal runner. Helpers cover boundary assembly, output assessment, cEGR/gas and water ledgers, initial-state preparation, and readback. |
| v2 result tree | `...\05_结果\README.md` confirms the result directory is empty; no RouteA v09/v10 result was copied into v2. |
| shared reuse gate | v2 has no local `.satk` directory. The project-level `E:\agentwork_pemfc_cEGR_0519\.satk\reuse-libraries.json`, `block-policy.json`, and `library-kg/index.md` were read; the FuelCell library path and reuse policy are inherited project assets, not newly created v2 files. |

Git readback was `master...origin/master` at `d5f800b0bb9ecc8d390aeab2f92de9e2af63df91`. Existing dirty files are outside the v2 active tree and remain untouched.

## Formal model inventory

The required order was executed through Codex MATLAB MCP:

1. `model_overview(model, scope="root", detail="full")`
2. `model_read(model, scope="root", depth="0")`
3. `model_read(model, scope="root", depth="1")`
4. `model_check(model, scope="root", checks=["all"])`

### Root facts

`model_overview` returned 23 internal containers, 0 external containers, and 30 root-level physical/signal connections. The principal containers are:

| Container | Readback role |
|---|---|
| `blk_1402 Stack_Core` | official Gas Mixture stack gas domains, MEA, cathode outlet chamber, thermal connections |
| `blk_1418 Cathode_Air_cEGR_BOP` | official air path, compressor/inlet mixer, EGR valve restriction, EGR pipe, oxygen source |
| `blk_1429 Cathode_Exhaust_Backpressure_Water` | cathode exhaust, outlet pressure path, EGR mass-flow sensor, humidity/composition readback, water KPI observer |
| `blk_1453 Anode_Hydrogen_BOP` | hydrogen source, anode humidifier/exhaust, recirculation and purge path |
| `blk_1458 Thermal_Management_BOP` | cooling and heat dissipation path |
| `blk_1461 System_Control_Observability` | electrical load, FCU controls, measurements, scopes, ToWorkspace outputs |
| `blk_1478 cEGR_Mode_Selector` | current pass-through/variant connection for the cEGR path |

The physical cEGR chain is present in the readback as cathode outlet path -> EGR mass-flow sensing/separation interface -> valve restriction -> EGR pipe -> `Oxygen Source.cEGR` -> compressor inlet mixing path. The command path is separate: `routeA_egr_valve_area_cmd` is produced by the FCU and enters `Cathode_Air_cEGR_BOP`; `cegr_ratio_cmd` is a target/control quantity and is not a physical mass-flow or composition source.

### Solver and parameter entry

Read-only `model_query_params` returned:

| Configuration | Value |
|---|---|
| Solver | `VariableStepAuto` |
| StartTime | `0.0 s` |
| StopTime | `2500 s` |
| MaxStep | `auto` |
| LoadInitialState | `off` |
| SignalLogging | `on` |
| SimscapeLogType | `all` |
| ReturnWorkspaceOutputs | `off` |

Selected Model Workspace values were read back without changing them:

| Variable | Value |
|---|---|
| `routeA_parameter_layer` | `platform_default` |
| `routeA_external_case_enabled` | `false` |
| `routeA_cegr_enabled` | `true` |
| `routeA_cegr_valve_mode_id` | `0` (closed-valve variant) |
| `routeA_egr_control_mode_id` | `1` (target-ratio control) |
| `routeA_target_egr_ratio_comp_in` | `0.02` |
| `routeA_target_mdot_comp_inlet` | `0.045 kg/s` |
| `routeA_target_oer` | `2.5` |
| `routeA_cathode_source_conditioner_volume_L` | `0.05 L` |
| `routeA_cathode_source_conditioner_nominal_flow_kg_s` | `0.045 kg/s` |
| `routeA_anode_source_conditioner_volume_L` | `0.05 L` |
| `routeA_anode_source_conditioner_nominal_flow_kg_s` | `0.002 kg/s` |
| `routeA_command_profile_fields` | 22 command fields; the 2 x 23 `routeA_command_profile` includes time plus those fields |

The combination `routeA_cegr_enabled=true`, target ratio `0.02`, and closed valve mode `0` is a configuration risk: a target exists, but the active valve variant does not currently represent an open cEGR capacity case. It is recorded only; it was not changed in Phase 0.

## Frozen u/w/y/z interface

| Class | Frozen semantic contract | Current v2 evidence |
|---|---|---|
| `u` | Internal manipulated commands: one plant-side `I_cmd` supplied by the Current/Power/Voltage adapters; air target/direct commands; cEGR ratio target or direct valve-area command; backpressure, RH, anode, and thermal control commands. | `System_Control_Observability`, `FCU_BoP_Control`, `routeA_command_profile`, `routeA_egr_valve_area_cmd`, and the parameter source script. |
| `w` | External boundary/disturbance profiles: electrical boundary reference or load disturbance, ambient pressure/temperature/RH, and explicitly selected external-case inputs. | Runner input assembly and `env_*` model-workspace variables; no external case is enabled. |
| `y` | Physical measurements: stack `i`, `v`, `P`, `T`; compressor inlet flow/pressure/temperature; EGR valve pressures; cathode outlet flow/pressure/temperature/composition/RH; source-side and anode measurements. | `Measurements`, FuelCell sensors, named `routeA_*` signals, scopes, and ToWorkspace blocks. |
| `z` | Truth/audit quantities: raw fresh/EGR/mixed flows, fresh/mixed oxygen excess ratios, inlet `pO2`/`yO2`, RH/water ledgers, pressure closure, controller error, source-conditioner states/port status, and warning ledger. | `routeA_stage1_cathode_gas_closure_from_outputs.m`, `routeA_stage1_water_ledger_from_outputs.m`, output assessment, and the readback signals. |

There is one intended physical plant and one internal current command. Current, Power, and Voltage remain electrical-boundary adapters into that plant; they are not three copied plants.

## cEGR raw-quantity definitions

The raw definitions are frozen independently of the control target:

```text
cegr_ratio_wet       = abs(mdot_cegr) / max(abs(mdot_mix_in), epsilon)
cegr_to_fresh_ratio  = abs(mdot_cegr) / max(abs(mdot_fresh), epsilon)
mdot_mix_in          = mdot_fresh + mdot_cegr
```

Every cEGR case must retain `mdot_fresh`, `mdot_cegr`, `mdot_mix_in`, `lambda_fresh`, `lambda_mix`, `pO2`, `yO2`, and RH with units and sign convention. The current `routeA_target_egr_ratio_comp_in` is documented against total compressor-inlet flow and is a control target; it must not be reported as `cegr_ratio_wet` without the physical fresh/mixed flow readback.

## Warning ledger baseline

`model_check(all, scope="root")` returned `status=warnings`, `total_warnings=77`, and no reported error. The root-scope warning groups are:

| Block | Warning count | Classification | Owner/decision |
|---|---:|---|---|
| `blk_1495 CathodeInletMassFlowSensor_FC` | 5 | observability physical ports | blocking until sensor path is either closed or explicitly removed from the audit contract |
| `blk_1418 Cathode_Air_cEGR_BOP` | 6 | cathode physical interface ports | structural closure owner: Phase 1 |
| `blk_1429 Cathode_Exhaust_Backpressure_Water` | 13 | exhaust/cEGR physical interface ports | structural closure owner: Phase 1 |
| `blk_1402 Stack_Core` | 15 | stack gas/thermal physical interface ports | structural closure owner: Phase 1 |
| `blk_983` anode humidifier composition sensor | 4 | anode observability ports | retain only if connected to a named `y` signal; otherwise remove/defer |
| `blk_1265` anode exhaust composition sensor | 4 | anode exhaust observability ports | same as above |
| `blk_1015` anode exhaust `Pipe (FC)` | 5 | anode exhaust physical path | structural closure owner: Phase 1 |
| `blk_959` anode recirculation `Constant Volume Chamber (FC)` | 9 | anode recirculation chamber ports | source/initial-state closure owner: Phase 1 |
| `blk_1295 EGRPipe` | 5 | cEGR physical path ports | structural closure owner: Phase 1 |
| `blk_1423 Conn1` | 1 | dangling connector port | classify after parent interface readback |
| `blk_1424 Conn2` | 1 | dangling connector port | classify after parent interface readback |
| `blk_1134` cathode humidifier composition sensor | 4 | cathode observability ports | retain only with a named output contract |
| `blk_1092 Pipe (N Gas)1` | 5 | cathode exhaust physical path | structural closure owner: Phase 1 |
| **Root total** | **77** |  |  |

The warning ledger is scope-sensitive. Targeted checks returned 9 warnings for `blk_1607 Anode_Source_Conditioner` and 9 for `blk_1606 Cathode_Source_Conditioner`; parent-scope checks returned 21 for `blk_893 Hydrogen Source` and 39 for `blk_21 Oxygen Source`. These are supplemental scoped audits and are not arithmetically added to the root total, because the root and nested checks do not enumerate the same variant/subsystem scope.

No warning is accepted as a harmless placeholder until its physical meaning, owner, and validation status are recorded. In particular, no Terminator or forced mass-flow source may be added to make this ledger appear clean.

## Source_Conditioner port classification

| Conditioner | External interface | Internal mixing chamber | Readback classification |
|---|---|---|---|
| `blk_1607 Anode_Source_Conditioner` | one physical port: `Conditioned_Fuel`; connected to the anode source restriction path | `blk_1636 Mixing_Chamber` has `MIn`, `TIn`, `A`, `B`, `C`, `pC`, `TC`, `yC_i`, `H` all reported unconnected by targeted `model_check` | not a two-sided closed gas source; input/conditioning state and chamber physical ports are unresolved |
| `blk_1606 Cathode_Source_Conditioner` | one physical port: `Conditioned_Air`; connected to the oxygen/compressor inlet path | `blk_1609 Mixing_Chamber` has `MIn`, `TIn`, `A`, `B`, `C`, `pC`, `TC`, `yC_i`, `H` all reported unconnected by targeted `model_check` | not a two-sided closed gas source; input/conditioning state and chamber physical ports are unresolved |

`model_read` shows intended block-to-block expressions for several chamber ports, but the targeted `model_check` result is the authoritative structural evidence for this phase. Therefore these are classified as open physical interfaces, not as verified connections. The source conditioners consume `From` commands for source flow/species/pressure/temperature and use nominal flow parameters; they are not the cEGR return path and must not be used to fabricate cEGR flow or composition.

## Phase 0 exit conditions

Completed in this record:

- v2 model/script/result asset table and hash baseline;
- `u/w/y/z` interface table;
- raw cEGR quantity definitions and distinction from control target;
- root warning ledger plus scoped Source_Conditioner warning evidence;
- Source_Conditioner external-port and internal-chamber classification;
- solver, initial-state, and parameter-entry readback.

Open risks and not-yet-verified items:

- no v2 update/compile or minimal smoke has been run;
- no v2 cold nominal initial state has been generated or validated;
- the current warning ledger has unresolved physical ports in the stack, BOP, cEGR, anode, and observability paths;
- input-side `pO2`/`yO2` and mixed-flow closure must be read back after the physical ports are closed;
- liquid water and separator behavior remains an L2/KPI boundary, not a verified two-phase closure.

Phase 1 structural modification is therefore deferred pending Phase 0.5 record completion and user confirmation. The only allowed next model action is a documented, one-scope-at-a-time closure step followed by readback, `model_check`, update/compile, minimal smoke, and disk verification.

## Evidence paths

- v2 model: `E:\agentwork_pemfc_cEGR_0519\RouteA_v2_PEMFC_cEGR_simulink\01_模型\RouteA_v2_GasMixture_Derived\PEMFuelCellSystem_GasMixture_cEGR_RouteA_v2_v01.slx`
- v2 parameter source: `E:\agentwork_pemfc_cEGR_0519\RouteA_v2_PEMFC_cEGR_simulink\01_模型\RouteA_v2_GasMixture_Derived\PEMFuelCellSystemWithACustomLibraryParameters.m`
- v2 script README: `E:\agentwork_pemfc_cEGR_0519\RouteA_v2_PEMFC_cEGR_simulink\03_脚本\RouteA_v2_GasMixture_Derived\README.md`
- v2 result README: `E:\agentwork_pemfc_cEGR_0519\RouteA_v2_PEMFC_cEGR_simulink\05_结果\README.md`
- formal tool evidence: Codex MATLAB MCP outputs for `model_overview`, `model_read(depth=0/1)`, `model_check(root/all)`, targeted `model_read(blk_1607/blk_1606)`, targeted `model_check`, `model_query_params`, and Model Workspace readback on 2026-07-24.
