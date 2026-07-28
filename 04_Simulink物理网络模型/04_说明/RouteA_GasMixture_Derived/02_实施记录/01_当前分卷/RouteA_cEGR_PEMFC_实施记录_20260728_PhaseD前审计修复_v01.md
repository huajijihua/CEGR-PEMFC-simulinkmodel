# Route A cEGR-PEMFC Phase D 前审计修复记录

文件类型：实施记录（Phase D 前审计修复）
记录日期：2026-07-28
前置：[Phase C 实施记录](./RouteA_cEGR_PEMFC_实施记录_20260728_PhaseC脚本清理与参数接线_v01.md)
当前模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`
回归基线：409.2011V（恒电流 100A + cEGR=0）

---

## 1. 审计背景

进入 Phase D（App Designer 面板）前，对平台进行完整审计，重点对照 [平台能力建设需求](../../01_当前指导/RouteA_cEGR_PEMFC_平台能力建设需求_v01.md)。发现 17 个问题（11 个模型工作区残留 + 3 个脚本层硬编码 + 3 个设计一致性），提出 5 个抉择点，用户全部认可建议方向。

---

## 2. 修复内容

### 2.1 R5：模型工作区清理（13 删 + 5 改）

**删除 13 个死变量**（`Simulink.findVars` 确认 0 块引用）：

| 变量 | 来源 |
|---|---|
| `routeA_cathode_source_conditioner_nominal_flow_kg_s` | Source_Conditioner 残留（S1 已删组件） |
| `routeA_cathode_source_conditioner_volume_L` | 同上 |
| `routeA_anode_source_conditioner_nominal_flow_kg_s` | 同上 |
| `routeA_anode_source_conditioner_volume_L` | 同上 |
| `routeA_demo_power_kW` / `stop_time` / `target_egr_ratio_comp_in` / `target_mdot_comp_inlet` / `target_p_ca_out_MPa` | demo 脚本残留 |
| `routeA_current_model` / `routeA_current_system` | stale，指向已归档 `PEMFuelCellSystem_Before_v01` |
| `routeA_target_egr_ratio_comp_in_profile` | 旧 EGR ratio 命令时序，已被 profile col11 接管 |
| `routeA_compressor_cmd_direct` | 与 `params.controls.air_direct_command` 重复 |

**修正 5 个变量值**：

| 变量 | 旧值 | 新值 | 原因 |
|---|---|---|---|
| `drive_cycle_current` | 1050×1 | 4×1 `[0;0;0;0]` | conditioning 残留，运行时被覆盖 |
| `drive_cycle_voltage` | 1050×1 | 4×1 `[0;0;0;0]` | 同上 |
| `drive_cycle_power` | 4×2（含时间列） | 4×1 `[0;0;0;0]` | 格式错误，S2 修过 FromWorkspace 维度但工作区变量本身未改 |
| `routeA_command_profile_baseline[6]` | 2.5 | 3.0 | OER 对齐参数文件 |
| `routeA_command_profile_baseline[8]` | 0.161325 | 0.1613 | 背压对齐参数文件 |

**保留**：`routeA_target_egr_ratio_comp_in`（1 个块引用：`FCU_BoP_Control/Target EGR Ratio`）。

### 2.2 R1：simCase.cathode/anode 补组分字段

`routeA_simCase_template.m`：
- `cathode` 域新增 `o2MoleFraction`、`h2oMoleFraction`（从 `params.environment` 派生）
- `anode` 域新增 `h2MoleFraction`（从 `params.anode.tank.yH2` 派生）

修复了组分控制路径断裂：此前 `routeA_assemble_command_profile` 的 `getField(controls, 'cathode', 'o2MoleFraction', ...)` 永远从 cathode 域取不到值，只能用 default。现在 simCase 可直接设置阴极 O2/H2O 和阳极 H2 组分。

### 2.3 R2：控制接口汇总表默认值同步

[控制接口汇总表_v01.md](../../01_当前指导/RouteA_cEGR_PEMFC_控制接口汇总表_v01.md) 7 处默认值同步到参数文件值：

| 字段 | 旧默认值 | 新默认值 |
|---|---|---|
| `air_target_mdot_kg_s` | 0.005 | 0.045 |
| `air_direct_command` | 0 | 0.5 |
| `anode_recirculation_base` | 0 | 0.2 |
| `anode_recirculation_current_gain_A_inv` | 0 | 0.00204 |
| `anode_purge_enable` | 0 | 1 |
| `anode_purge_on_n2_mole_fraction` | 0.1 | 0.5 |
| `anode_purge_off_n2_mole_fraction` | 0.05 | 0.1 |

### 2.4 R3：实现 `routeA_validate_case.m`

按 [CR3 schema §7](../../01_当前指导/RouteA_cEGR_PEMFC_CR3三要素schema_v01.md) 实现校验函数：
- **默认值填充**：从 `routeA_simCase_template` 递归填充缺失字段
- **类型校验**：caseId 格式、initialState.mode、electrical.mode、airControlMode
- **范围校验**：targetOer [1.5,5]、cegrRatio [0,0.5]、humidifierRH [0,1]、relTol (0,1)
- **互斥校验**：Voltage 模式必须有 voltageController 且 currentMin < currentMax、Kp/Ki > 0

5 个测试用例全部通过（Current/Power/Voltage 正常 + OER 越界拦截 + Voltage 缺 controller 拦截）。

### 2.5 R4：标记 `routeA_prepare_electrical_boundary_input` 为 legacy

在函数头部添加 LEGACY NOTICE：该函数绑定 v09 初态链（当前不可用），Phase D 面板不应使用。推荐装配路径：`simCase -> routeA_validate_case -> routeA_assemble_command_profile -> SimulationInput`。

### 2.6 #12：PI 控制器硬编码改为参数文件派生

`routeA_prepare_electrical_boundary_input.m:439` 的 `getControllerConfig` 函数，PI 默认值（Kp=1, Ki=0.05, currentMin=0, currentMax=392）改为从 `routeA_platform_default_parameters().controls` 派生。

---

## 3. 验证

| 步骤 | 结果 |
|---|---|
| 工作区变量删除后 `hws.reload` + `save_system` | ✅ 13 个变量全部删除，未回写 |
| `routeA_validate_case` 5 个测试 | ✅ 全部通过 |
| 回归验证 `run_routeA_phaseB_regression` | ✅ **409.2011V，span 0.0694%，0.0761%**，与修复前完全一致 |

---

## 4. Phase D 准入状态

审计发现的 17 个问题全部修复。Phase D 面板的推荐装配链路已就绪：

```
simCase_template (从参数文件派生默认值)
  -> routeA_validate_case (校验 + 填充默认值)
  -> routeA_assemble_command_profile (生成 22 列 profile)
  -> SimulationInput (直接构建，不走 v09 初态链)
  -> sim / parsim
```

**无阻断项，可进入 Phase D。**
