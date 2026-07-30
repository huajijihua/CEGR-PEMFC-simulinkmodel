# Route A cEGR-PEMFC 控制接口汇总表

文件类型：规划设计文件（平台能力清单）  
日期：2026-07-27  
版本：v01

---

## 1. 总览

本文件是 Route A 仿真平台的**完整控制接口清单**，明确列出所有可主动控制的量、所有可观测的响应量，以及每个量的名称、单位、范围、默认值、实现方式。本文件作为后续所有脚本清理、模型优化和面板设计的唯一接口依据。

**核心原则：**
- 主动控制量 = 用户/脚本可以设定的量
- 响应量 = 模型计算产生的量，用户不能直接设定
- 编译时固定量 = 仿真开始前确定，仿真期间不可变

---

## 2. 主动控制量

### 2.1 电边界控制

| 控制量 | 变量名 | 单位 | 范围 | 默认值 | 实现方式 | 时序 | 备注 |
|--------|--------|------|------|--------|----------|------|------|
| 电边界模式 | `input_type` | — | Current/Power/Voltage | Current | `setBlockParameter` | 编译时 | 一次计算只选一种 |
| 电流命令 | `drive_cycle_current` | A | [0, 392] | 0 | workspace 变量 | 时序 | 仅 Current 模式 |
| 功率命令 | `drive_cycle_power` | kW | [0, 150] | 0 | workspace 变量 | 时序 | 仅 Power 模式 |
| 电压命令 | `drive_cycle_voltage` | V | [0, 500] | 427.6 | workspace 变量 | 时序 | 仅 Voltage 模式 |
| 电压 PI Kp | `routeA_voltage_pi_Kp` | A/V | (0, ∞) | 1 | workspace 变量 | 编译时 | 仅 Voltage 模式 |
| 电压 PI Ki | `routeA_voltage_pi_Ki` | A/V/s | (0, ∞) | 0.05 | workspace 变量 | 编译时 | 仅 Voltage 模式 |
| 电流下限 | `routeA_voltage_current_min_A` | A | [0, 392] | 0 | workspace 变量 | 编译时 | 仅 Voltage 模式 |
| 电流上限 | `routeA_voltage_current_max_A` | A | [0, 392] | 392 | workspace 变量 | 编译时 | 仅 Voltage 模式 |

### 2.2 阴极气路控制

| 控制量 | 变量名 | 单位 | 范围 | 默认值 | 实现方式 | 时序 | 备注 |
|--------|--------|------|------|--------|----------|------|------|
| 空气控制模式 | `routeA_air_control_mode_id` | — | 1/2/3 | 2 (OER) | workspace 变量 | 编译时 | 1=目标质量流量闭环/2=OER闭环/3=空压机执行命令 |
| 目标 OER | `cathode_outlet_pressure_MPa_abs` → `air_target_oer` | — | [1.5, 5] | 3.0 | workspace 变量 | 时序 | 需 OER 模式 |
| 目标质量流量 | `air_target_mdot_kg_s` | kg/s | (0, ∞) | 0.045 | workspace 变量 | 时序 | 需流量模式 |
| 空压机执行命令 | `air_direct_command` | — | [0, 1] | 0.5 | workspace 变量 | 时序 | 模式 3；归一化空压机执行命令，跳过目标流量/OER换算和流量 PI，但仍经过空压机图谱，不是直接给电堆气体 |
| 阴极源压力 | `cathode_source_pressure_MPa_abs` | MPa(abs) | [0.1, 0.5] | 0.15 | workspace 变量 | 时序 | 新鲜空气边界 |
| 阴极源温度 | `cathode_source_temperature_C` | °C | [10, 60] | 20 | workspace 变量 | 时序 | 新鲜空气边界 |
| 阴极 O2 分数 | `cathode_source_o2_mole_fraction` | — | [0.15, 0.21] | 0.21 | workspace 变量 | 编译时 | 通过 `env_yO2` 间接控制 |
| 阴极 H2O 分数 | `cathode_source_h2o_mole_fraction` | — | [0.005, 0.04] | 0.0115 | workspace 变量 | 编译时 | 通过 `env_yH20` 间接控制 |
| 阴极出口压力 | `cathode_outlet_pressure_MPa_abs` | MPa(abs) | [0.1, 0.3] | 0.1613 | workspace 变量 | 时序 | 背压设定 |
| 加湿器 RH | `cathode_humidifier_rh` | — | [0, 1] | 0.9 | workspace 变量 | 时序 | 加湿器出口/阴极入口 RH；温度参考为模型现有 `T_stack`/加湿温度 |
| 加湿器启用 | `cathode_humidifier_gain` | — | 0/1 | 1 | workspace 变量 | 时序 | 0=旁路/1=启用 |

### 2.3 cEGR 控制

| 控制量 | 变量名 | 单位 | 范围 | 默认值 | 实现方式 | 时序 | 备注 |
|--------|--------|------|------|--------|----------|------|------|
| cEGR 启用 | `routeA_cegr_enabled` | — | true/false | true | workspace 变量 | 编译时 | 禁用时阀全关 |
| cEGR 目标比 | `cegr_ratio` | — | [0, 0.5] | 0 | workspace 变量 | 时序 | 质量流量比目标 |
| cEGR 阀模式 | `routeA_cegr_valve_mode_id` | — | 1/2 | 1 | workspace 变量 | 编译时 | 1=开度控制/2=压力控制 |
| EGR 控制模式 | `routeA_egr_control_mode_id` | — | 1 | 1 | workspace 变量 | 编译时 | 当前固定为 1 |
| EGR 目标输入模式 | `routeA_egr_target_input_mode_id` | — | 1 | 1 | workspace 变量 | 编译时 | 当前固定为 1 |

### 2.4 阳极控制

| 控制量 | 变量名 | 单位 | 范围 | 默认值 | 实现方式 | 时序 | 备注 |
|--------|--------|------|------|--------|----------|------|------|
| 阳极源压力 | `anode_source_pressure_MPa_abs` | MPa(abs) | [0.2, 0.5] | 0.3 | workspace 变量 | 时序 | 氢源压力设定 |
| 阳极源温度 | `anode_source_temperature_C` | °C | [10, 60] | 20 | workspace 变量 | 时序 | 氢源温度设定 |
| 阳极 H2 分数 | `tank_yH2`（profile: `anode_source_h2_mole_fraction`） | — | [0.9, 1.0] | 0.9997 | `SimulationInput.setVariable` + profile | 编译时 + profile | Fuel Tank 初始组分；面板输入在仿真前写入 |
| 阳极入口压力 | `anode_inlet_pressure_MPa_abs` | MPa(abs) | [0.1, 0.3] | 0.1613 | `routeA_command_profile` | 时序 | 减压阀输出设定 |
| 阳极加湿 RH | `anode_humidifier_rh` | — | [0, 1] | 1.0 | `routeA_command_profile` | 时序 | 阳极入口 RH；默认值以 `platform_default` 为准 |
| 回流基础命令 | `anode_recirculation_base` | — | [0, 1] | 0.2 | workspace 变量 | 时序 | 回流泵基础命令 |
| 回流电流增益 | `anode_recirculation_current_gain_A_inv` | 1/A | [0, 1] | 0.00204 | workspace 变量 | 时序 | 电流相关回流补偿 |
| 吹扫启用 | `anode_purge_enable` | — | 0/1 | 1 | workspace 变量 | 时序 | 0=禁用/1=启用 |
| 吹扫开启 N2 阈值 | `anode_purge_on_n2_mole_fraction` | — | [0, 1] | 0.5 | workspace 变量 | 时序 | N2 积累超过此值触发吹扫 |
| 吹扫关闭 N2 阈值 | `anode_purge_off_n2_mole_fraction` | — | [0, 1] | 0.1 | workspace 变量 | 时序 | N2 吹扫至低于此值停止 |

### 2.5 热管理控制

| 控制量 | 变量名 | 单位 | 范围 | 默认值 | 实现方式 | 时序 | 备注 |
|--------|--------|------|------|--------|----------|------|------|
| 堆温设定 | `stack_temperature_set_C` | °C | [60, 100] | 80 | workspace 变量 | 时序 | 冷却系统目标温度；当前模型同一 `T_stack` 路径也作为阴极加湿器 TIn 温度参考 |

### 2.6 环境/边界条件

| 控制量 | 变量名 | 单位 | 范围 | 默认值 | 实现方式 | 时序 | 备注 |
|--------|--------|------|------|--------|----------|------|------|
| 环境 O2 分数 | `env_yO2` | — | [0.15, 0.21] | 0.21 | workspace 变量 | 编译时 | Air Intake Reservoir y0 |
| 环境 H2O 分数 | `env_yH20` | — | [0.005, 0.04] | 0.0115 | workspace 变量 | 编译时 | Air Intake Reservoir y0 |
| 阳极 H2 分数 | `tank_yH2` | — | [0.9, 1.0] | 0.9997 | workspace 变量 | 编译时 | Fuel Tank y0 |

---

## 3. 可观测量/响应量

### 3.1 电堆测量

| 可观测量 | logsout 信号名 | 单位 | 说明 |
|---------|---------------|------|------|
| 堆电流 | `routeA_stack_current_A` | A | 电堆端电流 |
| 堆电压 | `routeA_stack_voltage_V` | V | 电堆端电压 |
| 堆功率 | 计算值 = I × V × 1e-3 | kW | 电功率 |
| 电流密度 | 计算值 = I / (n_cells × A_cell) | A/cm² | 归一化电流 |

### 3.2 阴极气路测量

| 可观测量 | logsout 信号名 | 单位 | 说明 |
|---------|---------------|------|------|
| 压缩机入口流量 | `routeA_mdot_comp_inlet` | kg/s | 新鲜空气流量 |
| 压缩机入口压力 | `routeA_p_comp_inlet` | MPa | 压缩机前压力 |
| 压缩机入口温度 | `routeA_T_comp_inlet` | °C | 压缩机前温度 |
| 压缩机命令 | `routeA_compressor_cmd` | — | 压缩机控制命令 |
| 压缩机转速 | `routeA_compressor_rpm` | rpm | 压缩机实际转速 |
| 空气流量设定 | `routeA_air_mdot_set` | kg/s | 空气流量设定值 |
| 空气控制误差 | `routeA_air_control_error` | kg/s | 流量控制误差 |
| 阴极入口 RH | `routeA_RH_ca_in` | — | 加湿后入口相对湿度 |
| 阴极出口 RH | `routeA_RH_ca_out` | — | 阴极出口相对湿度 |
| 阴极出口压力 | `routeA_p_outlet` | MPa | 电堆出口压力（背压） |
| 物种入口质量流量 | `routeA_mdot_species_ca_in_ts` | kg/s | 各物种入口质量流量（4 物种） |
| 排气质量流量 | 通过 `routeA_ExhaustMdot_Diagnostics` | kg/s | 阴极排气流量 |

### 3.3 cEGR 测量

| 可观测量 | logsout 信号名 | 单位 | 说明 |
|---------|---------------|------|------|
| 实际 cEGR 比 | `routeA_egr_ratio_comp_in` | — | 压缩机入口处实际回流比 |
| cEGR 质量流量 | `routeA_egr_mdot` | kg/s | EGR 管路质量流量 |
| 阀前压力 | `routeA_p_egr_valve_up` | MPa | EGR 阀前压力 |
| 阀后压力 | `routeA_p_egr_valve_down` | MPa | EGR 阀后压力 |
| 阀面积命令 | `routeA_egr_valve_area_cmd` | m² | EGR 阀有效开度 |

### 3.4 阳极测量

| 可观测量 | logsout 信号名 | 单位 | 说明 |
|---------|---------------|------|------|
| 阳极入口压力 | 待确认 | MPa | 阳极供氢压力 |
| 阳极出口压力 | 待确认 | MPa | 阳极排气压力 |
| 吹扫状态 | 待确认 | — | 吹扫阀开关状态 |
| 阳极 N2 分数 | 待确认 | — | 阳极侧 N2 积累（需确认） |

### 3.5 热管理测量

| 可观测量 | logsout 信号名 | 单位 | 说明 |
|---------|---------------|------|------|
| 堆温度 | `routeA_stack_temperature_C` | °C | 电堆冷却液出口温度 |
| 水分离速率 | `routeA_m_water_sep` | kg/s | 水分离器输出速率 |

### 3.6 电压模式专用

| 可观测量 | logsout 信号名 | 单位 | 说明 |
|---------|---------------|------|------|
| 电流饱和 | `routeA_voltage_current_saturated` | — | PI 输出是否饱和 |
| 电流限制命令 | `routeA_voltage_current_cmd_limited_A` | A | 限幅后的电流命令 |

### 3.7 审计/守恒量

| 可观测量 | 来源 | 说明 |
|---------|------|------|
| 阴极气体闭合 | `routeA_stage1_cathode_gas_closure_from_outputs.m` | 质量守恒审计 |
| 水账本 | `routeA_stage1_water_ledger_from_outputs.m` | 水管理审计 |
| MEA 内部状态 | `routeA_simscape_log_mea.m` | MEA 膜水合、温度等 |

---

## 4. 控制模式与互斥关系

### 4.1 电边界模式互斥

一次计算任务只能选择一种电边界模式：

```
电边界模式（input_type）
├── Current
│   ├── 必须设置: drive_cycle_time, drive_cycle_current
│   └── 不需要: PI 控制器参数
├── Power
│   ├── 必须设置: drive_cycle_time, drive_cycle_power
│   └── 不需要: PI 控制器参数
└── Voltage
    ├── 必须设置: drive_cycle_time, drive_cycle_voltage
    └── 必须设置: 电压 PI 参数（Kp, Ki, currentMin, currentMax）
```

### 4.2 空气控制模式互斥

```
空气控制模式（routeA_air_control_mode_id）
├── 1: 流量模式 — 使用 targetMdot 设定
├── 2: OER 模式 — 使用 targetOer 设定（推荐默认）
└── 3: 直接模式 — 使用 directCommand 设定
```

### 4.3 cEGR 控制说明

- `cegr_enabled=false`：cEGR 阀全关，拓扑保留但无回流
- `cegr_enabled=true` + `cegr_ratio=0`：cEGR 拓扑启用但目标回流量为零
- `cegr_enabled=true` + `cegr_ratio>0`：主动 cEGR 控制

---

## 5. 备注与限制

| 编号 | 限制 | 说明 |
|------|------|------|
| 1 | 入口气体组分编译时固定 | `env_yO2`/`env_yH20`/`tank_yH2` 在仿真开始前确定，仿真期间不能变化。如需变化需修改模型结构（Reservoir → Controlled Reservoir） |
| 2 | 22 列 profile 承载时序控制 | 当前所有"时序"控制量通过 22 列 `routeA_command_profile` 矩阵传递，后续将收缩为结构体（Phase B） |
| 3 | 电边界模式通过 `setBlockParameter` 切换 | 当前在脚本中切换，后续可考虑移入模型 Mask 参数 |
| 4 | 初态策略 | 活动 panel/runner 固定 `initializationPolicy="cold_start_only"` 并设置 `LoadInitialState="off"`；v09 和 v10 I/P/V bundle 仅作历史审计/对比 |

---

## 6. 关联文件

- [平台能力建设需求](RouteA_cEGR_PEMFC_平台能力建设需求_v01.md)
- [CR3 三要素 Schema 定义](RouteA_cEGR_PEMFC_CR3三要素schema_v01.md)
- [收敛实施路线图](RouteA_cEGR_PEMFC_收敛实施路线图_v01.md)
