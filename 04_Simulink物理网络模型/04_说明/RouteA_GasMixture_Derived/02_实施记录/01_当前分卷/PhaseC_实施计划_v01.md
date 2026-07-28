# Phase C 实施计划：脚本清理与参数接线

日期：2026-07-28
前置：Phase B 收尾（commit f3cc463）+ 死变量清理（commit 08cfa9e）
当前模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`
初始基线：恒电流 100A + cEGR=0 尾窗电压 409.20V（S3 基线 408.89V，偏差 0.076%）

---

## 任务清单

### C1：参数文件接线（参数 default 值单一真源）

| 步骤 | 入口 | 做法 | 验证 |
|---|---|---|---|
| C1.1 | `routeA_assemble_command_profile.m:55-79` 硬编码 defaults | 改为从 `routeA_platform_default_parameters()` 派生，见下方逐字段映射表 | assemble 输出与现版逐字段一致 |
| C1.2 | `routeA_simCase_template.m` 硬编码默认值 | 改为调用 `routeA_platform_default_parameters()` 填充 controls/initialState/solver 默认值 | simCase 字段与控制接口表一致 |
| C1.3 | `run_routeA_phaseB_regression.m` | 全链路回归（参数文件→assemble→simInput→sim） | 尾窗电压仍 409.2V 量级，PASS |

### C2：runner 收口（最小方案）

| 步骤 | 入口 | 做法 | 验证 |
|---|---|---|---|
| C2.1 | `run_routeA_power_cegr_matrix.m` 列索引注释 | 列索引注释改为 schema 具名字段引用 | 运行结果与 S3 一致 |
| C2.2 | `run_routeA_voltage_cegr_matrix.m` 列索引注释 | 同上 | 同上 |
| C2.3 | 三模式各 1 个代表工况 | 回归 | 与 S3 基线一致 |

### C3：实施记录 + 提交

按新规则，Phase C 完成必须追加实施记录，git 提交。

### C1.1 逐字段映射表

`routeA_assemble_command_profile.m` 当前硬编码 defaults → `routeA_platform_default_parameters` 对应路径：

| 当前代码行 | 缺省值 | 参数文件路径 | 参数文件值 | 匹配？ |
|---|---|---|---|---|
| L55 `targetOer` | 3.0 | `params.controls.target_oer.value` | 3.0 | ✅ |
| L56 `targetMdot_kg_s` | 0.005 | `params.controls.target_mdot_kg_s.value` | 0.045 | ⚠️ 0.005 vs 0.045 |
| L57 `directCommand` | 0.5 | 无对应 | — | ⚠️ 需补入参数文件 |
| L58 `sourcePressure_MPa_abs`(阴极) | 0.15 | 无对应(env ambient=0.101325 不同) | — | ⚠️ 需补入参数文件 |
| L59 `sourceTemperature_C`(阴极) | 20 | `params.environment.ambient_T_C.value` | 20 | ✅ |
| L60 `o2MoleFraction` | 0.21 | `params.environment.o2_mole_fraction.value` | 0.21 | ✅ |
| L61 `h2oMoleFraction` | 0.0115 | `params.environment.h2o_mole_fraction.value` | 0.0115436 | ⚠️ 精度截断 0.0115 vs 0.0115436 |
| L62 `outletPressure_MPa_abs` | 0.1613 | `params.controls.backpressure_MPa_abs.value` | 0.1613 | ✅ |
| L63 `humidifierRH`(阴极) | 0.9 | `params.cathode.humidifier.default_rh.value` | 0.9 | ✅ |
| L64 `humidifierEnabled` | 1 | `params.cathode.humidifier.enabled.value` | 1 | ✅ |
| L66 `targetRatio`(cegr) | 0 | `params.controls.cegr_target_ratio.value` | 0 | ✅ |
| L68 `sourcePressure_MPa_abs`(阳极) | 0.3 | 无对应(tank.p_MPa=70 不同) | — | ⚠️ 需补入参数文件 |
| L69 `sourceTemperature_C`(阳极) | 20 | `params.anode.tank.T_C.value` | 20 | ✅ |
| L70 `h2MoleFraction` | 0.9997 | `params.anode.tank.yH2.value` | 0.9997 | ✅ |
| L71 `inletPressure_MPa_abs`(阳极) | 0.15 | `params.anode.default_pressure_MPa_abs.value` | 0.1613 | ⚠️ 0.15 vs 0.1613 |
| L72 `humidifierRH`(阳极) | 0.5 | `params.anode.humidifier.default_rh.value` | 1.0 | ⚠️ 0.5 vs 1.0 |
| L73 `recirculationBaseCommand` | 0 | `params.controls.anode_recirc_base.value` | 0.2 | ⚠️ 0 vs 0.2 |
| L74 `recirculationCurrentGain_A_inv` | 0 | `params.controls.anode_recirc_gain_A_inv.value` | 0.00204 | ⚠️ 0 vs 0.00204 |
| L75 `purgeEnabled` | 0 | `params.controls.anode_purge_enable.value` | 1 | ⚠️ 0 vs 1 |
| L76 `purgeOnN2MoleFraction` | 0.1 | `params.controls.anode_purge_on_n2.value` | 0.5 | ⚠️ 0.1 vs 0.5 |
| L77 `purgeOffN2MoleFraction` | 0.05 | `params.controls.anode_purge_off_n2.value` | 0.1 | ⚠️ 0.05 vs 0.1 |
| L79 `stackTemperatureSet_C` | 80 | `params.thermal.stack_temperature_set_C.value` | 80 | ✅ |

**结论：** 22 个缺省值中，11 个直接匹配 ✅，11 个有差异 ⚠️。差异分两类：
- **A 类（保守→平台默认）：** assemble 当前用了保守缺省值（关闭吹扫、关闭再循环、关闭加湿等），参数文件有对应值但不同。改为参数文件值会改变模型行为。
- **B 类（缺字段）：** `directCommand`、`sourcePressure_MPa_abs`（阴极/阳极）在参数文件中无对应字段，需补充。

### C1.1 处理策略

**A 类差异（保留现有行为，不改变仿真结果）：** 对与控制器行为直接相关的缺省值（吹扫、再循环、阳极加湿、阳极入口压力），保持当前保守值，**不**立即改为参数文件值。目的是让 C1.1 只做"接线"不改变仿真结果，回归可验证。后续参数文件各字段的"正确默认值"可在 Phase C 完成后统一评审。

**B 类差异（缺字段）：** 在 `routeA_platform_default_parameters.m` 的 `params.controls` 中补充缺失字段：`cathode_source_pressure_MPa_abs`、`cathode_source_temperature_C`、`anode_source_pressure_MPa_abs`、`direct_command` 及默认值来源说明。

### C1.1 具体修改方案

```matlab
function profile = routeA_assemble_command_profile(controls, study)
    % 新增：从参数文件派生的缺省值
    params = routeA_platform_default_parameters();
    pCtrl = params.controls;
    pEnv  = params.environment;
    pCath = params.cathode;
    pAnode = params.anode;
    pTherm = params.thermal;
    
    % 每个 getField 的缺省值改从参数文件读取
    oer = getField(controls, 'cathode', 'targetOer', pCtrl.target_oer.value);
    mdot = getField(controls, 'cathode', 'targetMdot_kg_s', pCtrl.target_mdot_kg_s.value);
    ...
    % 对 A 类差异（保守值），保持原值，加注释说明
    anPurgeEn = getField(controls, 'anode', 'purgeEnabled', 0);  % 保守：关闭吹扫
    ...
```

### 回归验证

每步后用 `run_routeA_phaseB_regression.m` 验证尾窗电压不变（409.20V ± 0.1%）。若回归失败，说明某字段接线改变了行为，回退、排查、再继续。