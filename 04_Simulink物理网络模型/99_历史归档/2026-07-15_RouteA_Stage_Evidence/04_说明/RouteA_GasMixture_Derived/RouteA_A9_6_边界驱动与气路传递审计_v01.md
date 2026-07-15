# RouteA A9.6 边界驱动与气路传递审计 v01

执行日期：2026-07-10

## 1. 目标与边界

A9.6 用只读方式盘点当前 Route A 通用基底模型的边界输入、气路变量传递和控制开放度。脚本不保存 `.slx`，不新增结构探针，不读取旧 10 kW/DQ60/公司资料。

本轮重点是先分清：

- 哪些量是可外部设定的边界。
- 哪些量只是 model workspace 参数或初始条件。
- 哪些量由 Simscape/FC 物理网络求解。
- 哪些工程控制接口尚未暴露。

## 2. 当前边界输入结论

| 类别 | 当前可见入口 | 当前语义 | 开放度判断 |
|---|---|---|---|
| 电负载边界 | `drive_cycle_time`, `drive_cycle_power` | 官方功率命令链路 | 可设定功率；未直接暴露电流密度/电流命令 |
| 外界空气组分 | `env_yO2`, `env_yH20`, `env_p`, `env_T` | 外界空气源和环境状态 | 可设定；不是完整 cathode inlet 控制器 |
| 阳极氢源 | `tank_p`, `tank_yH2`, `tank_V` | 氢罐/氢源边界 | 可设定源状态；未暴露阳极计量比控制 |
| cEGR 阀 | `cegr_valve_area_closed`, `cegr_valve_area_low`, `cegr_valve_max_area` | 阀面积参数 | 可设定阀面积；不是目标 EGR ratio 控制 |
| 压缩机 | `comp_mdot_corr_TLU`, `comp_p_ratio_TLU`, `comp_rpm_TLU` | 压缩机性能 map | 设备性能参数；质量流由网络求解 |
| 中冷/水分离 L2 接口 | `intercooler_*`, `cathode_separator_*`, `anode_separator_*` | 等效压降、几何、初值 | 设备参数；不是直接流量边界 |
| 加湿器 | `routeA_cathode_humidifier_gain` | 启用/旁路 gain | 可设定；详细加湿控制策略未展开 |
| 初始状态 | `*_p0`, `*_T0` | 初始压力/温度 | 不应当作运行时控制量 |

关键结论：当前没有直接命名的 `stoich/lambda` 或外部指定 `mdot` 控制变量。气体质量流量主要由压缩机 map、阀面积、管路/分离器阻力、容腔状态和下游边界共同求解。

## 3. 气路传递链

阴极主链：

`fresh_air_environment -> compressor_inlet_mixer -> compressor/map -> intercooler_L2 -> cathode_humidifier_or_bypass -> cathode_gas_channels -> cathode_outlet_chamber -> cathode_separator/split -> exhaust_branch + cegr_valve_pipe_return -> compressor_inlet_mixer`

阳极基本链：

`hydrogen_tank/source -> anode_gas_channels -> recirculation -> anode_separator/recycle`

当前可测量的阴极关键 KPI 包括：

- `routeA_mdot_comp_inlet`
- `routeA_cegr_mdot`
- `routeA_exhaust_mdot`
- `routeA_p_comp_inlet`
- `routeA_T_comp_inlet`
- `routeA_yi_comp_inlet`
- `routeA_p_outlet`
- `routeA_T_outlet`
- `routeA_yi_outlet`
- `routeA_p_egr_valve_up/down`
- `routeA_RH_ca_in/out`
- `routeA_m_water_sep`

尚未统一为 A9 KPI 的关键项：

- cathode stack inlet 的统一 p/T 测点。
- cathode/anode 计量比。
- anode inlet/outlet p/T/mdot 摘要。
- 目标 EGR ratio 到阀面积的控制器或迭代器。

## 4. 证据工况

`run_routeA_a9_6_boundary_drive_audit.m` 读取两个 30 s nominal 证据工况：

| case | power | `egr_ratio_comp_in` | `egr_split_ratio_out` | comp inlet mdot | RH in | RH out |
|---|---:|---:|---:|---:|---:|---:|
| `no_egr_nominal_load` | `50.96 kW` | `1.019e-05` | `9.514e-06` | `0.04488 kg/s` | `0.9700` | `1.0047` |
| `mid_egr_nominal_load` | `50.96 kW` | `0.02015` | `0.01880` | `0.04490 kg/s` | `0.9695` | `1.0046` |

### no-EGR nominal 末值

| 量 | 数值 |
|---|---:|
| stack power | `50.9600 kW` |
| stack heat KPI | `12.4224 kW` |
| cathode outlet pressure | `162.253 kPa(abs)` |
| cathode outlet temperature | `347.642 K` |
| compressor inlet pressure | `101.325 kPa(abs)` |
| compressor inlet temperature | `293.150 K` |
| cEGR mdot | `4.573e-07 kg/s` |
| fresh inlet mdot estimate | `0.044882 kg/s` |
| exhaust mdot | `0.048066 kg/s` |
| separated-water KPI | `0.01124` |

Compressor inlet mole fraction `[N2, O2, H2, H2O]`：

`[0.778456, 0.210000, ~0, 0.011544]`

Cathode outlet mole fraction `[N2, O2, H2, H2O]`：

`[0.659101, 0.107066, ~0, 0.233833]`

### mid-EGR nominal 末值

| 量 | 数值 |
|---|---:|
| stack power | `50.9600 kW` |
| stack heat KPI | `12.4464 kW` |
| cathode outlet pressure | `162.237 kPa(abs)` |
| cathode outlet temperature | `348.158 K` |
| compressor inlet pressure | `101.325 kPa(abs)` |
| compressor inlet temperature | `294.399 K` |
| cEGR mdot | `0.0009048 kg/s` |
| fresh inlet mdot estimate | `0.043993 kg/s` |
| exhaust mdot | `0.047236 kg/s` |
| separated-water KPI | `0.01150` |

Compressor inlet mole fraction `[N2, O2, H2, H2O]`：

`[0.775745, 0.207673, ~0, 0.016582]`

Cathode outlet mole fraction `[N2, O2, H2, H2O]`：

`[0.655943, 0.105098, ~0, 0.238960]`

## 5. 接口缺口

| 缺口 | 严重度 | 当前状态 | 后续动作 |
|---|---|---|---|
| 直接电流/电流密度负载接口 | medium | 当前是功率命令 | A9.7 决定是否封装电流命令 |
| 目标 EGR ratio 控制 | high | 当前只能设阀面积 | A9.7 做目标 EGR 到阀面积搜索 |
| 阴极总流量/计量比控制 | high | 未发现直接变量 | 先做氧气供给后处理，再决定控制接口 |
| 阳极计量比控制 | medium | 未发现直接变量 | 明确氢气过量、purge 和 recycle 假设 |
| cathode stack inlet p/T KPI | high | 目前未统一 | 后续如只读不足，再最小化加测点 |
| anode p/T/mdot KPI | medium | A9 脚本未系统汇总 | 后续补阳极边界证据 |
| 真实入口温压控制 | medium | `env_p/env_T` 不是完整运行控制器 | 不把初始条件误当运行控制 |
| 液态水物理 | deferred | 仅保留 RH 和分离/冷凝水 KPI | 待气路边界和 EGR 控制稳定后再展开 |

## 6. 验证状态

- `checkcode run_routeA_a9_6_boundary_drive_audit.m`：通过。
- `run_routeA_a9_6_boundary_drive_audit.m`：`generated=1`，`passed=1`，`cases=2/2`。
- A9.5 filter 回归：`mid_egr_nominal_load` 通过，`passed=1`。

本轮不保存模型、不导出全量 timeseries、不生成 CSV。
