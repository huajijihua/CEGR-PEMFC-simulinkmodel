# R00.5 cEGR literature mapping v02

## Record metadata

| Field | Value |
|---|---|
| Record ID | `R00_5_cegr_literature_mapping_20260724_v02` |
| Phase | Phase 0.5: literature-to-model mapping and first closed-loop use case |
| Status | `PASSED_WITH_OPEN_RISKS` |
| Date | 2026-07-24 (Asia/Shanghai) |
| Executor | RouteA_v2 sole main execution agent |
| Previous record | `R00_5_cegr_literature_mapping_20260724_v01.md` |
| Model change | None; this record is literature and decision evidence only |

## Reading scope

All eight local direct-cEGR papers under `E:\agentwork_pemfc_cEGR_0519\00_支撑材料\03_cEGR阴极循环技术研究\` were reviewed against the extracted text under `E:\agentwork_pemfc_cEGR_0519\tmp\pdfs\cegr_round1\`. The source PDFs remain the authoritative local source; the text files are read-only extraction aids and were not modified.

The review records the required fields: object scale/evidence type, gas path, actuator, states, measurements, scope, assumptions, non-transferable parameters, RouteA variable mapping, and the minimal case or KPI that each paper can support.

## Paper-by-paper fields

| ID and local source | Object scale and evidence | Gas path and actuator | States and measurements | Scope, assumptions, and non-transferable items | RouteA mapping and minimal use |
|---|---|---|---|---|---|
| **L01** `2014-采用废气再循环技术的空气供应系统模型——用于延长燃料电池使用寿命.pdf` | Control-oriented air-system simulation; 520 cells, 300 cm2, 50 kW context and low-load high-voltage focus. Evidence type B/D: model, no direct experiment. | Compressor/supply manifold/humidifier/cathode exhaust return; fresh and return throttle control; condenser. | Lumped cavity pressure, flow, O2/N2/H2O composition, cell voltage and oxygen-related response. | Ideal gas, constant temperature, ignored cooling and hydrogen/anode, ideal humidifier/condenser, lumped volumes. Fixed stack/model assumptions are not platform defaults. | Map pressure inventory, `mdot`, `pO2`, `yO2`, and voltage suppression to `y/z`. Use as mechanism evidence only; do not copy throttle or stack parameters. |
| **L02** `2017-聚合物电解质膜燃料电池双循环实验研究.pdf` | 10 kW, 50-cell, 261 cm2 stack experiment; direct evidence A. | Cathode recirculation pump, hydrogen recirculation pump, humidifiers, back-pressure/purge/bypass valves. | Stack/current/cell voltage, cathode flow, RH, inlet/outlet O2, pump speed and fresh-flow reduction. | Ideal-gas steady theory, no condensation, no N2 crossover, air treated as O2/N2; 10 kW hardware and pump range are non-transferable. | Direct trend evidence for `mdot_fresh`, `mdot_cegr`, O2, RH, voltage and parasitic-power questions. Use low-load O2/RH/voltage audit, not default gains or hardware size. |
| **L03** `2020-阴极循环对氢燃料电池系统高电位限制和自加湿的影响.pdf` | 30 kW, 100 cells, 500 cm2 stack experiment; direct evidence A with orthogonal operating cases. | Cathode exhaust pump to inlet, exhaust stop valve, fresh-air valve, compressor/backpressure system. | Current density, pump speed, fresh flow, inlet/outlet O2, RH, pressure, voltage, high-frequency impedance and single-cell consistency. | Ideal mixing/no condensation and constant pump temperature; pump MAP, stack geometry, and measured ranges are not platform defaults. | Supports low-load voltage suppression, O2/RH tradeoff, and a deferred pump-parasitic KPI. High-load liquid-water effect is a deferred risk, not a new module. |
| **L04** `2021-质子交换膜燃料电池发动机空气自循环系统自增湿效应.pdf` | 30 kW, 100 cells, 350 cm2 dynamic control-oriented model with bench validation; evidence A/B. | Passive three-way cathode outlet valve and self-circulation; no active recirculation pump in the main passive configuration; compressor/backpressure and anode recycle remain. | O2/N2/vapor inventories, vapor/liquid/membrane water, condensation, valve flow, compressor dynamics, RH, voltage, current and temperature. | Manufacturer/membrane parameters and constant-stack-temperature simplifications are non-transferable; liquid-water model is higher fidelity than current L2 platform closure. | Supports passive pressure-driven topology and RH/O2/voltage observability. Treat liquid/membrane water as a later L3/local-check boundary, not an automatic v2 module. |
| **L05** `2024-循环负载过程中氢氧质子交换膜燃料电池反应物饥饿的优化策略.pdf` | Single cell with about 50 cm2 active area, dead-ended pure H2/O2 dynamic loading and 500-cycle durability tests; evidence A/C. | Cathode peristaltic pump, buffer tank, purge and dead-ended reactant path. | Current steps, voltage undershoot, liquid-water removal, EIS/CV/ECSA and degradation. | Dead-ended H2/O2, cell geometry, pump speed and water-handling hardware are not automotive air-side defaults. | Deferred starvation/liquid-water risk evidence. Map to future `w/z` dynamic-starvation and water KPI; do not introduce this pump or dead-ended topology into the first cEGR case. |
| **L06** `2024-阴极废气再循环降低聚合物电解质膜燃料电池系统空转功率并实现快速冷启动的概念分析.pdf` | Conceptual 0D quasi-steady system model; 359 cells, 250 cm2, 5-560 A; evidence D, not full-system validation. | Preferred passive valve upstream of compressor plus water separator/collection tank; alternative post-compressor route rejected by the paper. | O2/N2 composition, lambda, valve/ratio, voltage, idle power and cold-start temperature trajectory; no dynamic gas inventory or vapor state. | Neglects vapor and dynamic inventory; stack/vehicle assumptions and claimed cold-start gains are non-transferable. | Supports passive-valve architecture and idle/cold-start boundary questions. Separator and cold-start are deferred; no new water-separator gas modifier is allowed in Phase 0. |
| **L07** `2024-阴极循环策略对质子交换膜燃料电池内部极化和外部特性的影响分析.pdf` | 25 cm2 single-cell G20 experiment; current density 0-0.2 A/cm2, fresh-air stoich 2-5, recirculation ratio 0-1, 60 C and 0.2 MPa backpressure; evidence A. | Test bench simulates cathode recirculation through fixed-total-inlet-flow composition calculation; ratio is the manipulated study variable; EIS workstation is the diagnostic actuator/measurement context. | Voltage, cathode inlet RH, current density, O2/N2/vapor composition, EIS and DRT polarization processes. | Saturated outlet vapor, only O2/N2/vapor recirculated, ideal gas, no physical dynamic inventory in the test calculation; single-cell hardware is non-transferable. | Directly supports the first low-load voltage/RH/O2 KPI set. DRT is a diagnostic evidence method, not a new RouteA plant block. |
| **L08** `2024-长期耐久性 FCV 电力系统低负荷条件下 PEMFC 阴极循环及其优化控制研究.pdf` | 25 cm2 single-cell experiment plus validated automotive system/SIL model; 360 cells, 300 cm2 system parameters, 40/50/70 A linearization points; evidence A/B. | Compressor plus circulation pump model, supply/return manifolds, cathode/anode gas inventories and backpressure. Control input is pump speed; current is disturbance; voltage is measurement. | Manifold/cathode/anode pressures, O2/N2/vapor partial pressures, current, voltage, RH, compressor/pump flow, controller ISE/ITSE/TV and disturbance response. | Semi-empirical voltage model, ideal-gas balances, identified compressor/pump maps and vehicle stack parameters are non-transferable; reported controller gains are not RouteA defaults. | Provides the control contract analogue `w=I_cmd`, `y=V_cell`, actuator=cEGR valve area, with `pO2`/RH auxiliary audits. Use as closed-loop KPI evidence after physical port closure. |

## Cross-check with system-level water/thermal material

| Local material | Decision boundary for RouteA_v2 |
|---|---|
| `用于质子交换膜燃料电池湿度控制的膜式加湿器热力学模型.pdf` | Exhaust-to-fresh humidification is a dynamic pressure/flow/temperature/RH problem; it supports logging these variables, but it is not a license to replace the current physical cEGR path with an ideal humidifier. |
| `波动运行条件下 PEMFC 系统动态特性的仿真.pdf` | Simulink system studies should expose transient pressure, RH and load effects and validate against measurements; these become `y/z` and acceptance KPIs, not automatic new cEGR modules. |
| `基于物理学的低温质子交换膜燃料电池模型综述：用于系统级水与热管理研究.pdf` and the matching English-title PDF | The review of low-cost physics-based models emphasizes the complexity/validation tradeoff and recommends validating existing models rather than rebuilding blindly. This supports the v2 staged fidelity boundary. |
| `Investigation of Water and Heat Transfer Mechanism in PEMFCs Based on a Two-Phase Non-Isothermal Model.pdf` | Liquid water, dissolved water, and through-plane heat transfer are local high-fidelity mechanisms. They remain future L3/COMSOL or explicit water-model checks, not hidden assumptions in the first gas-phase cEGR loop. |

## Mechanism-to-model decision

The following paper findings are treated as research impacts and KPIs, not automatic new cEGR modules:

- oxygen dilution and oxygen partial-pressure reduction;
- cathode self-humidification and membrane hydration;
- drainage, flooding, and liquid-water accumulation;
- low-load high-potential suppression;
- dynamic reactant starvation;
- recirculation/compressor/pump parasitic power;
- cold start and freeze behavior.

The physical RouteA cEGR chain remains the only first-order module boundary: cathode outlet -> split -> valve/local restriction -> pipe or volume -> inlet mixing. Recirculated species, temperature, pressure, and humidity must come from that physical exhaust network. No paper-specific stack, pump, valve, controller gain, or workbook calibration is promoted into `platform_default`.

## First closed-loop use case decision

### UC-01: low-load passive-cEGR voltage clamp with O2/RH audit

| Field | Decision |
|---|---|
| Electrical boundary | `Current` adapter into the single plant and single internal `I_cmd`; current profile is the load disturbance for the cEGR loop. |
| Parameter layer | `platform_default`; `external_case=false`. |
| Device configuration | Passive pressure-driven cEGR through the existing outlet split, `EGRValveRestriction`, `EGRPipe`, and compressor-inlet mixer. No active cEGR pump in the first case. |
| Manipulated variable | Physical cEGR valve-area command. `cegr_ratio_cmd` remains a target/setpoint and is not assigned as `mdot_cegr`. |
| Primary controlled variable | Per-cell voltage `V_cell = V_stack / stack_num_cells`, with the low-load high-potential threshold represented around the literature 0.80 V level. This is a KPI threshold, not a new voltage source. |
| Secondary audits | `pO2_ca_in`, `yO2_ca_in`, `RH_ca_in/out`, `mdot_fresh`, `mdot_cegr`, `mdot_mix_in`, both raw cEGR ratios, cathode pressures/temperature, water estimate, and actuator effort/parasitic proxy. |
| First smoke order | After structural closure: warm-start convenience smoke to isolate the cEGR mechanism, followed by the required cold-nominal and `cegr=0` cases. Warm-start output cannot be called v2 formal performance evidence. |
| Acceptance direction | Voltage stays below the high-potential threshold without unphysical flow/species sources; increasing cEGR must be traceable to outlet-derived flow/composition/RH and must preserve pressure and mass-flow closure. |
| Deferred | Active pump, liquid separator as a gas-composition modifier, dynamic starvation, full liquid-water/freeze model, cold-start claim, durability/EIS controller claim, and long formal matrices. |

This use case is selected because L02/L03/L07/L08 jointly support the O2/RH/voltage mechanism, while L04/L06 support a passive-valve topology. It is narrow enough to validate the physical cEGR path before adding higher-fidelity water or dynamic-starvation mechanisms.

## Phase 0.5 exit conditions

Completed:

- all eight direct-cEGR papers have the required field-level mapping;
- system-level water/thermal references have been used to set the fidelity boundary;
- impact/KPI items are separated from physical cEGR module scope;
- UC-01 and its passive device configuration, interface, and KPI direction are selected.

Open risks:

- the current Source_Conditioner and multiple physical BOP ports are still structurally open;
- input-side `pO2`/`yO2` and fresh/mixed-flow observability must be proven after closure;
- the current parameter target ratio and closed valve variant require an explicit case-level decision before execution;
- no v2 update/compile/smoke or formal performance result exists.

Phase 1 remains `DEFERRED` until the user confirms the two v02 records and authorizes the first one-scope structural closure. The next permitted change is limited to a named physical port group and must follow locate -> modify -> readback -> `model_check` -> update/compile -> minimal smoke -> save/disk verification.

## Evidence paths

- direct-cEGR PDFs: `E:\agentwork_pemfc_cEGR_0519\00_支撑材料\03_cEGR阴极循环技术研究\`
- read-only text extraction: `E:\agentwork_pemfc_cEGR_0519\tmp\pdfs\cegr_round1\`
- system-level water/thermal PDFs: `E:\agentwork_pemfc_cEGR_0519\00_支撑材料\02_PEMFC系统级建模与仿真\`
- v2 system/architecture/implementation/test/literature specifications: `E:\agentwork_pemfc_cEGR_0519\RouteA_v2_PEMFC_cEGR_simulink\04_说明\RouteA_v2_GasMixture_Derived\`
- model and parameter source: `E:\agentwork_pemfc_cEGR_0519\RouteA_v2_PEMFC_cEGR_simulink\01_模型\RouteA_v2_GasMixture_Derived\`
