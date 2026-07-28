# Route A cEGR-PEMFC Phase D D3 闭环与 D4 首个矩阵实施记录

文件类型：实施记录（Phase D 连续实施线）  
记录日期：2026-07-28  
当前模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`  
对应计划：[RouteA_cEGR_PEMFC_PhaseD_实施计划_v01.md](../../../../PLAN/RouteA_cEGR_PEMFC_PhaseD_实施计划_v01.md)

## 1. 实际完成工作

### 1.1 计划和接口校正

- 覆盖更新 Phase D 计划，纠正“D3 仿真已触发”的不实状态。
- 固定当前模型真实接口：
  - Current：`drive_cycle_time` + `drive_cycle_current`
  - Power：`drive_cycle_time` + `drive_cycle_power`
  - Voltage：`drive_cycle_time` + `drive_cycle_voltage`
- 确认 cEGR 和气路控制通过模型工作区 `routeA_*` 变量驱动，不使用不存在的 `cEGRControl_ModeSwitch` 路径。
- 读取 `Oxygen Source/Air Intake` Reservoir，确认入口组成由 `env_yO2/env_yH20` 的 `y0` 表达式驱动。

### 1.2 D3-A 输入装配修复

修改文件：

- `routeA_block_paths.m`
- `routeA_platform_default_parameters.m`
- `routeA_simCase_template.m`
- `routeA_validate_case.m`
- `routeA_panel_build_simulation_input.m`
- `routeA_panel_extract_results.m`

实际修复：

- Voltage PI 默认结构由 `routeA_platform_default_parameters` 派生，不再为空。
- 三种电边界统一使用 `routeA_normalize_electrical_profile` 和真实 `FromWorkspace` 变量。
- 显式覆盖 `routeA_command_profile`、气路控制变量、cEGR 控制变量、PI 参数和 `env_yO2/env_yH20`。
- 增加模型自动加载、关键块路径存在性检查和 ramp/stopTime 前置检查。
- 结果提取优先使用 `routeA_stack_power_kW` 日志，缺失时才回退到 V×I，并记录 `power_source`。
- 缺失 logsout、缺失信号、空尾窗和时间轴不一致时明确报错。
- Voltage 校验规则调整为：未提供 controller 时继承平台默认；显式提供 controller 时必须字段完整。
- 面板运行不再隐式 `save_system`，只应用 `SimulationInput`，避免 GUI 运行产生模型保存副作用。

### 1.3 D3-D 面板能力

文件：`RouteA_Panel_v01.m`

- 基础/高级模式回调已实现。
- 高级模式增加电边界、OER、背压、阴极 RH、cEGR、StopTime、O2/H2O 和 Voltage PI 字段。
- 电边界模式切换会更新命令默认值和单位。
- Run 期间禁用 Run/Matrix 按钮，结束后恢复。
- 增加矩阵按钮入口、结果表回填和矩阵电压曲线叠加。
- 当前主交付仍是程序化 `.m` AppBase 类；`RouteA_Panel_v01.mlapp` 尚未生成。

### 1.4 D4 首个矩阵 runner

新增：`routeA_panel_run_matrix.m`

- 支持电边界命令、cEGR 比、OER、入口 O2 四轴笛卡尔积。
- 每个 case 独立构造 `simCase` 和 `SimulationInput`。
- 支持 serial；parallel 路径使用 2 workers 的 `parsim`。
- 短时矩阵按 finite KPI 作为 smoke 判据。
- 正式矩阵增加电边界跟踪误差、cEGR 误差和尾窗稳定性判据。

## 2. 实际验证证据

以下结果来自 MATLAB 当前会话的实际 `sim()` / runner 输出，不是预写计划数值。

### 2.1 三模式单工况

| Case | 关键设置 | 尾窗结果 | 结果 |
|---|---|---|---|
| Current 平台默认 | 100 A，cEGR=0，anode RH=1.0 | `V=409.976977 V`，`I=100.000000 A`，`P=40.997698 kW`，span=`0.06109%` | 仿真无 ErrorMessage；平台默认基线 |
| Current Phase C 兼容 | 100 A，cEGR=0，anode RH=0.5，anode inlet P=0.15 MPa | `V=409.200935 V`，`I=100.000000 A`，`P=40.920093 kW`，span=`0.06938%` | PASS；与 Phase C `409.2011 V` 相差约 `0.00004%` |
| Power | 40 kW，cEGR=0 | `V=410.379289 V`，`I=97.470810 A`，`P=40.000002 kW` | PASS；功率误差约 `4e-8%` |
| Voltage | 410 V，cEGR=0 | `V=409.849797 V`，`I=100.329794 A`，`P=41.120146 kW` | PASS；电压误差约 `0.03664%`，span 约 `0.03629%` |

所有 600 s 单工况均无 `SimulationOutput.ErrorMessage`，日志信号有限且尾窗非空。

### 2.2 cEGR 和入口组成

| Case | 设置 | 尾窗结果 | 结果 |
|---|---|---|---|
| cEGR | Current 100 A，target ratio 0.3，enabled=true | `V=406.580678 V`，actual cEGR=`0.300001` | PASS；cEGR 跟踪有效 |
| O2 | Current 100 A，`cathode.o2MoleFraction=0.18` | `V=409.063774 V` | PASS；相对平台默认 0.21 O2 case 有氧稀释响应 |

入口 O2 的第一次试验未产生响应，根因是 profile 对应的模型信号在当前模型内接 Terminator；补充 `env_yO2/env_yH20` 工作区覆盖后，O2 case 产生有效响应。

### 2.3 面板和矩阵 smoke

| 测试 | 结果 |
|---|---|
| 面板基础/高级回调 | PASS；高级面板显示、基础面板隐藏，Voltage 更新为 410 V/V 单位 |
| 面板 Current 10 s Run 回调 | PASS；KPI 表写入 1 行，日志写入 11 行，状态为完成 |
| D4 Power 40 kW × cEGR `[0,0.1,0.3]`，10 s serial | PASS；3/3 finite KPI |
| D4 Power 40 kW × cEGR `[0,0.1,0.3]`，600 s serial | PASS；3/3 formal PASS |

正式矩阵结果：

| Case | Tail P | Actual cEGR | 稳态相对变化 | 结果 |
|---|---:|---:|---:|---|
| cEGR 0 | `40.000000 kW` | `0.000000` | `0.0352%` | PASS |
| cEGR 0.1 | `40.000000 kW` | `0.099996` | `0.0331%` | PASS |
| cEGR 0.3 | `40.000000 kW` | `0.299989` | `0.0274%` | PASS |

### 2.4 输入拒止和静态检查

| 测试 | 结果 |
|---|---|
| T6：OER=10 | PASS，`RouteA:ValidateRange` |
| T7：显式缺少 Voltage PI 字段 | PASS，`RouteA:ValidateElectricalMutex` |
| T8：stopTime=10 s、ramp=60 s | PASS，`RouteA:PanelRampDuration` |
| Code Analyzer：platform/template/validate/build/extract/matrix | 无代码错误或告警 |

## 3. 阻塞点和未决项

1. 当前模型 `model_check` 仍有 warning-only 物理端口/非活动 Variant 警告；本轮没有扩大模型拓扑整改，仿真本身无 ErrorMessage。
2. 当前保留的 `.m` 程序化面板不是 `.mlapp`，App Designer 保存/打包尚未完成。
3. 高级面板目前覆盖了核心 D3 输入和 Voltage PI/O2/H2O，但没有覆盖全部 CR2 阳极、热管理、环境和 solver 容差字段。
4. 面板 `sim()` 仍为同步调用；D4 serial/parallel runner 可用，但后台异步调度和进度取消尚未实现。
5. 矩阵正式验收目前覆盖 Power 40 kW × cEGR 三点；OER/O2 多轴正式矩阵和 6 case 以上并行矩阵尚未验收。
6. 当前平台默认 anode RH=1.0 与 Phase C 兼容 case 的 RH=0.5 不同。两者必须作为不同参数集报告，不能混用基线。
7. anode Reservoir 的 H2 组成来自 `tank_yH2`，但高级面板还未暴露阳极组分和全部阳极边界字段。

## 4. 当前状态

**D3：已闭环。** 三种电边界、cEGR、入口 O2 覆盖和面板 Current smoke 均有实际证据。  
**D4：首个正式矩阵已闭环。** Power 40 kW × cEGR `[0,0.1,0.3]` serial 600 s 全部 PASS。  
**D5：未完成。** 仍需补齐完整测试矩阵、`.mlapp` 交付形式、实施记录最终收口和必要的 git 提交前审查。
