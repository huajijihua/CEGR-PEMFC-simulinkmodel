# Route A cEGR-PEMFC Phase C 实施记录：脚本清理与参数接线

文件类型：实施记录（Phase C 脚本清理产物）
记录日期：2026-07-28
前置决策：[平台能力建设需求](../../01_当前指导/RouteA_cEGR_PEMFC_平台能力建设需求_v01.md)、[Phase B 实施记录](./RouteA_cEGR_PEMFC_实施记录_20260727_PhaseB平台能力升级_v01.md)
当前模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`
回归基线：恒电流 100A + cEGR=0，尾窗电压 409.2011V（S3 基线 408.89V，偏差 0.076%）

---

## 0. Phase C 目标

Phase C 是平台能力升级的第三阶段。目标：把 Phase A/B 建立的设计（schema、参数文件、控制接口表）真正接到脚本，消除多写入点和重复脚本，使统一 `SimulationInput` 装配入口可用。采用最小方案（保留现有 runner，抽取共享装配逻辑，不重构为 6 入口）。

---

## 1. C1：参数文件接线

### 1.1 C1.1a：补全参数文件缺失字段

`routeA_platform_default_parameters.m` 的 `params.controls` 域补充 5 个缺失字段：

| 新增字段 | 值 | 来源 | 用途 |
|---|---|---|---|
| `cathode_source_pressure_MPa_abs` | 0.15 | routeA_derived | 阴极新鲜空气源压力 |
| `cathode_source_temperature_C` | 20 | routeA_derived | 阴极新鲜空气源温度 |
| `anode_source_pressure_MPa_abs` | 0.3 | routeA_derived | 阳极氢源压力 |
| `anode_source_temperature_C` | 20 | routeA_derived | 阳极氢源温度 |
| `air_direct_command` | 0.5 | routeA_derived | 空气直接命令（模式 3） |

这些字段原先在 `routeA_assemble_command_profile` 和 `routeA_simCase_template` 中各自硬编码，现在统一到参数文件。

### 1.2 C1.1b：`routeA_assemble_command_profile` defaults 从参数文件派生

重构 `routeA_assemble_command_profile.m:53-79`：

- 新增 `params = routeA_platform_default_parameters()` 调用，派生 `pCtrl/pEnv/pCath/pAnode/pTherm` 五个域引用
- 22 个 `getField` 调用的硬编码默认值全部改为从参数文件对应字段读取
- 逐字段映射表（22 项）见 [PhaseC_实施计划_v01.md](./PhaseC_实施计划_v01.md) 的 C1.1 逐字段映射表

**关键设计决策：** 对 A 类差异（assemble 旧保守值 vs 参数文件平台默认值），采用参数文件值作为 defaults。理由：
1. 参数文件是 Phase B 建立的平台单一真源，`source/unit/description` 元数据完整
2. 回归脚本 `run_routeA_phaseB_regression` 显式设置所有 controls 字段，不依赖 defaults，因此 defaults 值变化不影响回归
3. 保守值（如 purgeEnabled=0、recirculationBase=0）是旧代码遗留，参数文件的值（purgeEnabled=1、recirculationBase=0.2）才是平台默认语义

### 1.3 C1.2：`routeA_simCase_template` 从参数文件派生

重构 `routeA_simCase_template.m` 全文：

- 新增 `params = routeA_platform_default_parameters()` 调用
- initialState / controls / solver 三部分的硬编码默认值全部改为从参数文件对应字段读取
- 改用直接字段赋值（`s.field = value`）替代 `struct(...)` 构造，避免续行符解析问题
- 所有 22 个 controls 字段 + 6 个 initialState 字段 + 5 个 solver 字段均从参数文件派生

验证：`routeA_simCase_template()` 调用成功，所有字段值与参数文件一致（targetOer=3、targetMdot=0.045、outletPressure=0.1613、purgeEnabled=1、recirculationBase=0.2、stackTemperatureSet=80、stopTime=600、relTol=1e-3、o2MoleFraction=0.21）。

### 1.4 C1.3：回归验证

`run_routeA_phaseB_regression`（恒电流 100A + cEGR=0，600s）：

| 判据 | 阈值 | 实测 | 结果 |
|---|---|---|---|
| 无 DAE IC Failure | 仿真完成 | 完成 | ✅ |
| 尾窗(540-600s)电压跨度 | < 0.5% | 0.0694% | ✅ |
| 尾窗电压 vs S3 基线(408.89V)相对偏差 | < 1% | 0.0761% | ✅ |

尾窗电压均值 **409.2011 V**，与接线前完全一致。**PASS**--参数文件接线无回归。

---

## 2. C2：矩阵 runner 列索引改为 schema 具名字段

### 2.1 改动

`run_routeA_power_cegr_matrix.m` 和 `run_routeA_voltage_cegr_matrix.m`：

- 新增 `schema = routeA_command_profile_schema()` 调用
- 用 `find(schema.names == "air_target_oer")` 和 `find(schema.names == "cegr_ratio")` 解析字段索引
- `cp(:,7) = oer` 改为 `cp(:, idxAirTargetOer+1) = oer`
- `cp(:,12) = [0; 0; cr; cr]` 改为 `cp(:, idxCegrRatio+1) = [0; 0; cr; cr]`

### 2.2 验证

schema 索引解析：`air_target_oer` = 6（cp 列 7）、`cegr_ratio` = 11（cp 列 12），与原硬编码列号完全一致。**PASS**。

---

## 3. 完成状态

- ✅ C1.1a 参数文件补全 5 个缺失字段
- ✅ C1.1b `routeA_assemble_command_profile` defaults 从参数文件派生（22 字段）
- ✅ C1.2 `routeA_simCase_template` 从参数文件派生（33 字段）
- ✅ C1.3 回归验证 PASS（409.2011V，与接线前一致）
- ✅ C2.1 `run_routeA_power_cegr_matrix` 列索引改为 schema 具名字段
- ✅ C2.2 `run_routeA_voltage_cegr_matrix` 列索引改为 schema 具名字段
- ✅ C2.3 schema 索引验证 PASS

### 未决项（Phase C 后续或 Phase D）

1. **`routeA_command_profile_baseline` 数组对齐**：模型工作区 `routeA_command_profile_baseline`（OER=2.5 / 背压=0.161325）仍为 conditioning 值，运行时被 `routeA_assemble_command_profile` 的 defaults 覆盖。待后续让 baseline 也从参数文件派生。
2. **`drive_cycle_power/time` 4 行残留**：模型工作区里的 4 行数组残留，待清理。
3. **runner 共享装配函数**：三模式（Current/Power/Voltage）的 SimulationInput 装配逻辑有重复，可抽取共享函数。最小方案暂不做。
4. **临时脚本归档**：`03_脚本/` 下的一次性脚本待审查归档。
