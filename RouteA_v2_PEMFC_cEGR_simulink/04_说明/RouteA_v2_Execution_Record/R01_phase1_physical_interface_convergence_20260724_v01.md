# RouteA_v2 Phase 1 物理接口收敛执行记录 v01

| Field | Value |
|---|---|
| Phase | Phase 1: physical interface convergence |
| Status | `BLOCKED` |
| Date | 2026-07-24 (Asia/Shanghai) |
| Executor | RouteA_v2 sole main execution agent |
| Model | `PEMFuelCellSystem_GasMixture_cEGR_RouteA_v2_v01.slx` |
| Scope | RouteA_v2 model, v2 scripts, v2 execution record/result directories only |
| Parent baseline | `d5f800b0bb9ecc8d390aeab2f92de9e2af63df91` plus preserved pre-existing dirty worktree |

## 1. Objective and frozen boundaries

This record executes the approved Phase 1 plan in three gates:

1. `1A`: retain the cathode `Source_Conditioner` as the fresh-air boundary and close or classify its physical/measurement interfaces.
2. `1B`: retain one physical cEGR path and close or classify the compressor-inlet mixer, cEGR pipe, cathode exhaust and inlet-flow observation interfaces.
3. `1C`: make cold runner preparation independent of the hot-state file, generate a formal v2 Current initial-state candidate after structural closure, and run the minimum smoke cases.

The following are immutable for this phase:

- The official Gas Mixture/FuelCell gas domain, MEA, stack thermal path, existing cEGR route, BOP assets and one-plant electrical boundary remain the source structure.
- `Cathode_Source_Conditioner` owns fresh N2/O2/H2O boundary commands only. It is not a second cEGR mixer.
- cEGR remains `cathode outlet split -> valve/restriction -> EGRPipe -> CompressorInletMixer.C`.
- `cegr_ratio_cmd` remains a setpoint. Actual `mdot_cegr`, composition, temperature and pressure are physical-network outputs.
- No new `Source_Conditioner`, global command field, forced mass-flow source, Terminator used to suppress an active physical port, active pump, or gas-composition water modifier is allowed.
- Original RouteA, historical material, and unrelated pre-existing dirty files are outside the write scope.

## 2. Phase 1 entry evidence

### 2.1 Existing v2 baseline

| Item | Evidence |
|---|---|
| Model path | `E:\agentwork_pemfc_cEGR_0519\RouteA_v2_PEMFC_cEGR_simulink\01_模型\RouteA_v2_GasMixture_Derived\PEMFuelCellSystem_GasMixture_cEGR_RouteA_v2_v01.slx` |
| Model root | `PEMFuelCellSystem_GasMixture_cEGR_RouteA_v2_v01` |
| Model size | 23 internal containers, 0 external containers, 30 root connections |
| Solver baseline | `VariableStepAuto`, `StartTime=0`, `StopTime=2500`, `RelTol`/`MaxStep` retained from model configuration |
| Root structural baseline | `model_check(root, all)` returned warnings, 77 root warnings, no reported error |
| v2 model hash before Phase 1 | `0211A2FEE5BE4DA06A792ADBA80CC49CC34A4FEC65A854A7B5097F5B82DC81EB` |
| v2 model hash after 1A save | `2BEF5581F494A35DEDACBFD6DEE4580B802A373BB57268881A359A4BB4F92945` |
| Initial-state baseline | Only legacy-source convenience MAT is present; formal `RouteA_v2_platform_default_initial_state.mat` is absent |
| Formal runner | `03_脚本\RouteA_v2_GasMixture_Derived\run_routeA_electrical_boundary_study.m` |

### 2.2 Target read-back

| Target | Read-back fact | Phase 1 action |
|---|---|---|
| `blk_1606 Cathode_Source_Conditioner` | One external `Conditioned_Air` port; internal H2O/N2/O2 mass sources, source pressure and temperature commands; `Mixing_Chamber` has `MIn=?`, `TIn=?`, `pC=?`, `TC=?`, `yC_i=?` | Preserve source boundary; connect pC/TC/yC_i to local named diagnostics; classify MIn/TIn only after port-direction confirmation; do not fabricate flow or temperature feedback |
| `blk_1287 CompressorInletMixer` | `A=blk_1606.RConn1`, `B=compressor path`, `C=blk_1292.RConn1`; pC/TC/yC_i already connected to existing converters; MIn/TIn unconnected | Preserve one fresh/cEGR physical mixing point; classify MIn/TIn as legal boundary only if no traceable feedback exists |
| `blk_1292 cEGR` | External connection port connected to `blk_1287.C` | Preserve as the sole cEGR inlet to the compressor mixer |
| `blk_1295 EGRPipe` | FuelCell `Pipe (FC)`; `B` is connected to `blk_21.cEGR`, `A` is linked to internal `blk_1311.A` in read-back, `MIn/TIn` unresolved by structural check | Trace and close the actual upstream A path; classify MIn/TIn without adding a source if they are non-active pipe feedback ports |
| `blk_1429 Cathode_Exhaust_Backpressure_Water` | Outlet, cEGR and exhaust sensors/converters exist; `blk_1092 Pipe (N Gas)1`, `Conn1`, `Conn2` contribute root warnings | Preserve outlet split and existing water KPI boundary; close real ports or classify explicit legal boundaries |
| `blk_1495 CathodeInletMassFlowSensor_FC` | Root warning group has 5 entries and is part of the inlet audit contract | Retain and close to the actual inlet flow path, or explicitly remove from the audit contract with evidence; no silent placeholder |

## 3. Phase 1A: Source_Conditioner

### Allowed changes

- Add only the minimum local measurement conversion/diagnostic wiring needed for `pC`, `TC` and `yC_i`.
- Use existing FuelCell library blocks and local named diagnostics; do not add root command fields or a second physical boundary.
- Preserve the current three-source fresh-air composition and source P/T ownership for this phase. The composition/flow audit is performed at the output and compressor mixer.

### Port decision

- `pC`, `TC`, `yC_i`: measurement outputs; connect to local named diagnostic signals.
- `MIn`, `TIn`: do not connect to a guessed source. After official block-direction confirmation, classify as a legal source-boundary interface if no downstream feedback can be traced. Such warnings remain explicitly recorded, not hidden.

### Gate 1A

- `model_read(blk_1606)` shows intended diagnostic connections and no accidental cEGR connection.
- `model_check(blk_1606)` and root are rerun; warning changes are classified against the 77-warning baseline.
- `update/compile` succeeds with no error-severity structural issue.
- The model is saved only after read-back and check results are recorded.

### 3.1 1A execution result

| Check | Result | Evidence/interpretation |
|---|---|---|
| Structural edit | `PASSED` | `model_edit(scope=blk_1606)` created `blk_1675/1676` for pC, `blk_1677/1678` for TC and `blk_1679/1680` for yC_i |
| Read-back | `PASSED` | `blk_1609.pC -> blk_1675 -> blk_1676`; `blk_1609.TC -> blk_1677 -> blk_1678`; `blk_1609.yC_i -> blk_1679 -> blk_1680` |
| MIn/TIn treatment | `PASSED_WITH_OPEN_RISK` | No guessed feedback or forced source was added; both remain explicit source-boundary classification items |
| Targeted model check | `PASSED_WITH_OPEN_RISK` | `blk_1606` still reports 9 warnings, including the three connected read-back ports; this is a static-check/read-back inconsistency and is not counted as warning reduction |
| Update/compile | `PASSED` | MATLAB MCP `set_param(model, SimulationCommand, update)` returned `UPDATE_1A_OK` |
| Root model check | `PASSED_WITH_OPEN_RISK` | Root remains `status=warnings`, `total_warnings=77`, no reported error and no new root warning group |
| Save/disk verification | `PASSED` | `save_system` returned `SAVE_1A_OK`; file size `275794` bytes; hash recorded above |

1A is therefore `PASSED_WITH_OPEN_RISKS`: the local diagnostic chain is physically read back and compiles, while the SATK warning detector still classifies the library chamber ports as unconnected. No structural claim is made that those warnings are closed until a subsequent runtime or lower-level port audit proves their semantics.

## 4. Phase 1B: cEGR and cathode exhaust interfaces

### Allowed changes

- Work one subsystem scope at a time: `blk_1287`, `blk_1418`, `blk_1429`, `blk_1295`, and `blk_1495` as needed.
- Preserve `A/B/C` physical topology and the existing passive restriction/valve path.
- Close only traceable physical connections and existing diagnostic outputs. MIn/TIn on chambers/pipes are classified rather than filled with artificial sources when no physical owner exists.

### Gate 1B

- cEGR flow, composition, temperature and pressure still originate at the cathode outlet network.
- `blk_1287.C` remains the only cEGR entry to the compressor inlet mixer.
- `model_read` confirms no duplicate mixer, pump or command-to-flow shortcut.
- Targeted and root `model_check` results contain no new unclassified warnings.
- Update/compile succeeds and the model is saved with a disk hash.

### 4.1 1B execution result

| Check | Result | Evidence/interpretation |
|---|---|---|
| Inlet flow observation | `PASSED` | Added local `PS-Simulink Converter` plus `ToWorkspace` chains for `blk_1495.M` and `blk_1495.Phi_out`; read-back confirms both originate at the existing `CathodeInletMassFlowSensor_FC` and do not alter the physical path. Variables are `routeA_mdot_ca_in_ts` and `routeA_phi_ca_in_ts`. |
| Dangling interface connectors | `PASSED` | Read-back showed `blk_1423 Conn1` and `blk_1424 Conn2` had no parent or child physical connection. Both were removed inside `blk_1418`; the remaining `Conn3/Conn4/Conn5/B` interfaces and the existing EGR valve/pipe path were preserved. |
| cEGR topology | `PASSED_WITH_OPEN_RISK` | Read-back confirms `blk_1292.cEGR -> blk_1287.C`, `blk_1295.B -> blk_21.cEGR`, the upstream/downstream valve restriction and pressure/temperature sensors remain in the same single path. No pump, separator, second mixer or command-to-flow shortcut was added. |
| `MIn/TIn` classification | `PASSED_WITH_OPEN_RISK` | `blk_1287`, `blk_1295` and exhaust `blk_1092` retain unresolved `MIn/TIn` ports in the structural checker. Their physical A/B/H and cEGR/outlet connections are read back; no traceable feedback owner was found, so these are recorded as legal library boundary candidates for a later port-semantics audit rather than connected to fabricated sources. |
| Targeted/root model check | `PASSED_WITH_OPEN_RISK` | Root `model_check(all)` after 1B reports `status=warnings`, `total_warnings=68`, no reported error. The count change is 77 -> 72 after the inlet M/Phi observation closure and 72 -> 68 after the two dangling connector removals. Remaining groups are classified as active-path library boundary/diagnostic boundaries (`blk_1295`, `blk_1092`, `blk_1418`, `blk_1429`) or pre-existing anode/stack observer and wrapper interfaces (`blk_983`, `blk_1265`, `blk_1015`, `blk_959`, `blk_1134`, `blk_1402`) owned by later audits; no new warning group was introduced. |
| Update/compile | `PASSED` | MATLAB MCP update returned `UPDATE_1B_SENSOR_OK` after the observation edit and `UPDATE_1B_CONNECTOR_OK` after the connector removal. |
| Save/disk verification | `PASSED` | `save_system` returned `SAVE_1B_OK`; size `273844` bytes; SHA-256 `2F3A32FB72F98E1898A8175A880F3D6957CB797A7C5BD900A830FD77D1B6AB4A`; modified `2026-07-24 15:38:49` local time. |

1B is therefore `PASSED_WITH_OPEN_RISKS`: the one-path cEGR topology and the relevant inlet observation boundary are preserved and read back, while the library checker still reports explicit `MIn/TIn`/wrapper warnings that remain classified for later semantics work. No physical gap was hidden with a Terminator or artificial flow source.

## 5. Phase 1C: runner, initial state and smoke

### Runner change

Modify the v2 runner path so that:

- `cold` selection does not require `RouteA_v2_platform_default_initial_state.mat` and does not attempt to load a ModelOperatingPoint.
- Cold command baselines are read from the existing model-workspace `routeA_command_profile_fields` and `routeA_command_profile_baseline`, plus existing platform electrical defaults.
- `hot`/`auto` continue to require and validate the formal v2 initial-state metadata.
- No new command fields are introduced.

### Initial-state asset

After 1A/1B update/compile, run the existing v2 initial-state generator for the Current branch, audit the candidate metadata and quiet-window result, then promote only a validated candidate to `RouteA_v2_platform_default_initial_state.mat`. The legacy MAT remains convenience-only.

### 5.1 1C execution result

| Check | Result | Evidence/interpretation |
|---|---|---|
| Cold runner preflight | `PASSED` | With an explicitly nonexistent initial-state file, `routeA_prepare_electrical_boundary_input` assembled a `SimulationInput` using `hotStartPolicy=cold`, `mode=cold`, `researchStart=0`, Current baseline `28 A`, and the existing 22-field command profile. No operating point was attached. |
| Hot/auto guard | `PASSED` | The same missing-file preflight with `hotStartPolicy=hot` still raised `RouteA:MissingPlatformDefaultInitialState`; the hot/auto admission contract remains active. |
| Script static analysis | `PASSED` | MATLAB Code Analyzer returned no issues for `routeA_attach_platform_default_initial_state.m` and `routeA_generate_platform_default_initial_state.m`. |
| Model update/compile | `PASSED` | MATLAB MCP update after the 1C runner edit returned `UPDATE_1C_RUNNER_OK`. |
| Current formal candidate generation | `BLOCKED` | `routeA_generate_platform_default_initial_state(struct('loadInputType',"Current"))` stopped in `routeA_prepare_parameter_consistent_initial_state>runCondition` line 498. Solver Configuration reported first IC solve failure, a retry with relaxed priorities also failed, and the error listed existing `Anode_Hydrogen_BOP/Anode Humidifier/Pipe (N Gas)`, `Cathode_Air_cEGR_BOP/EGRPipe` (flow and heat equations), `Anode Exhaust/Pipe (FC)`, and `Anode Exhaust/Purge Valve`. |
| Candidate/formal state files | `NOT_GENERATED` | The Current candidate MAT was not created and the formal `RouteA_v2_platform_default_initial_state.mat` remains absent. No promotion was attempted because the generator did not produce a validated ModelOperatingPoint. |
| Stop-condition handling | `BLOCKED` | No hot reference, cold nominal, or cold cEGR smoke was run after the IC failure. The model disk hash and timestamp remained unchanged from the saved 1B model: `2F3A32FB72F98E1898A8175A880F3D6957CB797A7C5BD900A830FD77D1B6AB4A`, `273844` bytes, `2026-07-24 15:38:49`. |

1C is `BLOCKED`. The runner cold-file dependency is removed and verified, but the formal Current initial-state gate cannot be passed while the existing physical network has an unsatisfied IC solve. The next admission condition is a traceable physical initial-condition/port-owner correction for the listed pipe and purge-valve equations, followed by `model_check -> update/compile -> generator` on the same model and solver. No solver relaxation, artificial mass-flow source, Terminator, or cEGR topology expansion is permitted as a workaround.

### Smoke cases

Use Current, 28 A, `VariableStepAuto`, serial execution, 10 s minimum duration, and mode-1 open-valve topology:

1. `hot_start_reference`: cEGR target 0, convenience only.
2. `cold_nominal_current`: cEGR target 0, formal cold evidence.
3. `cold_cegr_small`: target ratio 0.02, actual cEGR measured from the physical network.

Required audits are finite I/V/P/T, fresh/EGR/mixed flow closure, species closure, inlet pO2/yO2/RH, valve pressure difference, controller error and cEGR ratio. Initial engineering limits are 1% mass/species closure and `max(1e-4, 0.01*max(target,1e-3))` cEGR ratio error.

## 6. Stop conditions and exit status

Pause immediately if any new warning, update/compile error, `NE_DAE_IC_Failure`, NaN/Inf, pressure/mass/species inconsistency or missing physical owner appears. Record the smallest reproduction input, model hash, stack and next admission condition.

Phase 1 may be marked `PASSED_WITH_OPEN_RISKS` only when target scopes are closed, all root warnings are classified, cold preparation no longer fails on the absent hot-state file, and the three smoke results are recorded. It must not be called a full v2 performance validation.

## 7. Execution evidence

Formal evidence sources used for this entry:

- Codex MATLAB MCP `model_read` for `blk_1606`, `blk_1287`, `blk_1292`, `blk_1295`, `blk_1429`, `blk_1418`, `blk_1495`.
- Codex MATLAB MCP `model_check(root, all)` on 2026-07-24.
- Official Gas Mixture model `blk_1041 Cathode Gas Channels` read-back and FuelCell library reuse gate.
- Phase 0 and Phase 0.5 records `R00_baseline_and_interface_freeze_20260724_v02.md` and `R00_5_cegr_literature_mapping_20260724_v02.md`.

## 8. Current execution state

The record was created before structural modification. 1A and 1B are complete with saved read-back evidence. 1C cold runner preflight is complete, but formal Current candidate generation is blocked by the recorded Solver Configuration IC failure. The three smoke cases and formal promotion remain deferred until the listed physical initial-condition/port-owner issue is resolved and revalidated.
