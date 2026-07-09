# RouteA A9 50 kW 平台参数治理第二轮 v01

日期：2026-07-09  
对象模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`  
执行入口：`run_routeA_a9_parameter_governance_audit.m`

## 1. 第二轮目标

A9 第二轮只处理第一轮留下的 3 个非阻塞警告，不进入 A10/A11 结构改版，不升级两相水模型，不替换官方空压机 map。

第一轮改前基线：

| 项 | 改前值 | 第一轮问题 |
|---|---:|---|
| 名义 50 kW 阳极低压氢估算速度 | 130.35 `m/s` | 阳极 10 mm 管径偏硬 |
| 阴极水分离器名义流量裕度 | 0.892 | `0.05 kg/s` 接近名义空气需求 |
| 阴极水分离器高功率流量裕度 | 0.521 | 高功率包络不足 |
| `cegr_valve_max_area / cegr_pipe_area` | 0.8 | 最大阀面积接近主管全开 |

## 2. 参数修改

| 参数 | 改前 | 改后 | 目的 |
|---|---:|---:|---|
| `anode_tube_D` | 0.01 `m` | 0.02 `m` | 降低 50 kW 名义点阳极低压氢估算速度 |
| `cathode_separator_mdot_nominal` | 0.05 `kg/s` | 0.10 `kg/s` | 覆盖名义和高功率阴极空气需求 |
| `cegr_valve_area_frac_max` | 未显式 | 0.02 | 显式约束 CEGR 阀最大面积比例 |
| `cegr_valve_max_area` | `0.8*cegr_pipe_area` | `cegr_valve_area_frac_max*cegr_pipe_area` | 避免最大阀面积近似主管全开 |

同步派生：

- `anode_separator_D = anode_tube_D`
- `anode_separator_area = pi*anode_separator_D^2/4`
- `cegr_valve_max_area = cegr_valve_area_frac_max * cegr_pipe_area`

## 3. 审计硬门槛

`run_routeA_a9_parameter_governance_audit.m` 已把第一轮 warning 升级为第二轮硬门槛：

| 门槛 | 要求 | 通过值 |
|---|---:|---:|
| 名义阳极低压氢估算速度 | `< 40 m/s` | 32.587 `m/s` |
| 阴极水分离器名义流量裕度 | `>= 1.5` | 1.7846 |
| 阴极水分离器高功率流量裕度 | `>= 1.0` | 1.041 |
| `cegr_valve_max_area / cegr_pipe_area` | `<= 0.05` 且大于低 EGR 阀面积比 | 0.02 |
| `max_cegr_area_sanity` | 30 s 仿真完成，压力链和 KPI 有限 | 通过 |

## 4. 验证记录

执行结果：`passed=1`

| 检查项 | 结果 | 关键证据 |
|---|---:|---|
| 参数隔离 | 通过 | `platform_default`；外部案例默认禁用；旧台架默认依赖为 0 |
| 公式包络 | 通过 | 三档包络有限；第二轮 warning 清零 |
| 参数归类 | 通过 | 38 个治理项均可归类；A8 参数全部覆盖 |
| A8 回归 | 通过 | 三组 30 s smoke 全部通过 |
| `nominal_50kW_steady` | 通过 | 目标功率 51 kW；实际功率 51 kW；压力链、RH、水量 KPI 均通过 |
| `max_cegr_area_sanity` | 通过 | EGR 入口比约 0.1988；出口分流比约 0.1824；压力链和 KPI 有限 |

第二轮公式结果：

| 工况 | 阳极低压氢速度 | 阴极水分离压降 | 阴极水分离流量裕度 |
|---|---:|---:|---:|
| `low_load_cegr` | 9.31 `m/s` | 0.0128 `kPa` | 6.25 |
| `nominal_50kW` | 32.6 `m/s` | 0.157 `kPa` | 1.78 |
| `high_power_envelope` | 55.9 `m/s` | 0.461 `kPa` | 1.04 |

## 5. 剩余边界

- `cegr_valve_max_area=0.02*cegr_pipe_area` 只是 50 kW 平台 sanity 上限，不是产品阀门标定。
- 阳极 purge 策略仍未产品化；第二轮只解决供氢管径量级偏硬问题。
- 阴极水分离器仍为 L2 压降接口，不具备主动液态水移除能力。
- 空压机 map、冷却 UA、加湿器水热动态和两相水传输仍留到后续阶段。
