# Route A cEGR-PEMFC model_check warning ledger

文件类型：只读审计证据
记录日期：2026-07-29
目标模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`

## 1. Scope and evidence

本 ledger 只覆盖当前模型 root scope 的 `unconnected_ports` 检查结果，并把运行时 warning 单独列在第 4 节。`model_check` 报 warning 不等于物理网络存在真实断线；每一条必须结合当前拓扑读回、仿真结果和信号注册范围判断。

| ID | 检查或产物 | 实际结果 |
|---|---|---|
| MC-UP-20260729 | `model_check(root, checks=["unconnected_ports"])` | 77 warnings，0 errors |
| MC-UL-20260729 | `model_check(root, checks=["unconnected_lines"])` | healthy |
| MR-1495 | `model_read(scope=blk_1495, depth=1)` | A、B、M_i 已连接；M、Phi_out 未使用 |
| MR-SENSORS-20260729 | `model_read(scope=blk_983/blk_1265/blk_1134, depth=1)` | 入口 A 和已注册输出连接状态可读回；未注册 x_i/y_i/W 保留为未观测 |
| MR-PIPES-20260729 | `model_read(scope=blk_1015/blk_1092/blk_1295, depth=1)` | A/H/B 主气路或热路连接；MIn/TIn 未使用 |
| MR-RECIRC-20260729 | `model_read(scope=blk_959, depth=1)` | A/B/C/H 已连接；MIn/TIn/pC/TC/yC_i 未使用 |
| SIM-P0-3600-20260729 | P0 acceptance report | Current/Power 3600 s 通过；Voltage 3600 s 完成但未达到稳态门；气相闭合和 tail purge 检查通过 |

## 2. Classification policy

| Code | 类别 | 判定和处置 |
|---|---|---|
| R1 | readback-confirmed | `model_check` 报告端口，但当前 `model_read` 能确认其连接。保留真实连接，不做结构性修改。 |
| R2 | optional-wrapper-interface | 子系统封装层或内部 Connection Port 未接入当前活动边界。保持接口，不能用 Terminator 伪闭合。 |
| R3 | unused-observation | 传感器测量输出未进入当前 observation registry。记录为未观测能力，不宣称有该测量，也不为清零 warning 强行接线。 |
| R4 | unused-physical-input | Pipe/Chamber 的可选 MIn/TIn 外部注入端口未使用。当前气路由真实物理网络提供，不新增人工质量源或温度源。 |

本次 77 条的计数为：R1 `22`、R2 `36`、R3 `11`、R4 `8`。所有条目的 owner、影响和处置如下。

## 3. Itemized ledger

| # | Code | Block / port | Owner | Impact | Disposition | Evidence |
|---:|---|---|---|---|---|---|
| 1 | R1 | `blk_1495.A` | 阴极入口观测 | 入口气路已接入当前阴极支路 | 保留，不改线 | MC-UP, MR-1495 |
| 2 | R3 | `blk_1495.M` | 阴极入口观测 | 总质量流量未注册为当前观测量 | 保留为未观测 | MC-UP, MR-1495 |
| 3 | R3 | `blk_1495.Phi_out` | 阴极入口观测 | 组分流量输出未注册为当前观测量 | 保留为未观测 | MC-UP, MR-1495 |
| 4 | R1 | `blk_1495.M_i` | 阴极入口观测 | 组分质量流量已接入 `blk_1496` | 保留，不改线 | MC-UP, MR-1495 |
| 5 | R1 | `blk_1495.B` | 阴极入口观测 | 入口传感器出口已接入 `blk_1402` | 保留，不改线 | MC-UP, MR-1495 |
| 6 | R2 | `blk_1418.LConn1` | 阴极供气封装 | 当前活动边界未使用该封装接口 | 保留接口，不加 Terminator | MC-UP, MR-1418 |
| 7 | R2 | `blk_1418.LConn2` | 阴极供气封装 | 当前接口由内部气路管理，不作为 root 边界 | 保留接口，不加 Terminator | MC-UP, MR-1418, MR-1495 |
| 8 | R2 | `blk_1418.RConn1` | 阴极供气封装 | 可选物理出口未纳入当前活动路径 | 保留接口，不加 Terminator | MC-UP, MR-1418 |
| 9 | R2 | `blk_1418.RConn2` | 阴极供气封装 | 可选物理出口未纳入当前活动路径 | 保留接口，不加 Terminator | MC-UP, MR-1418 |
| 10 | R2 | `blk_1418.RConn3` | 阴极供气封装 | 可选物理出口未纳入当前活动路径 | 保留接口，不加 Terminator | MC-UP, MR-1418 |
| 11 | R2 | `blk_1418.RConn4` | 阴极供气封装 | 可选物理出口未纳入当前活动路径 | 保留接口，不加 Terminator | MC-UP, MR-1418 |
| 12 | R2 | `blk_1429.LConn1` | 阴极排气与水管理 | 当前外壳连接端口不是活动 root 边界 | 保留接口，不加 Terminator | MC-UP, MR-1429 |
| 13 | R2 | `blk_1429.LConn2` | 阴极排气与水管理 | 当前外壳连接端口不是活动 root 边界 | 保留接口，不加 Terminator | MC-UP, MR-1429 |
| 14 | R2 | `blk_1429.LConn3` | 阴极排气与水管理 | 当前外壳连接端口不是活动 root 边界 | 保留接口，不加 Terminator | MC-UP, MR-1429 |
| 15 | R2 | `blk_1429.LConn4` | 阴极排气与水管理 | 当前外壳连接端口不是活动 root 边界 | 保留接口，不加 Terminator | MC-UP, MR-1429 |
| 16 | R2 | `blk_1429.LConn5` | 阴极排气与水管理 | 当前外壳连接端口不是活动 root 边界 | 保留接口，不加 Terminator | MC-UP, MR-1429 |
| 17 | R2 | `blk_1429.LConn6` | 阴极排气与水管理 | 当前外壳连接端口不是活动 root 边界 | 保留接口，不加 Terminator | MC-UP, MR-1429 |
| 18 | R2 | `blk_1429.RConn1` | 阴极排气与水管理 | 当前外壳连接端口不是活动 root 边界 | 保留接口，不加 Terminator | MC-UP, MR-1429 |
| 19 | R2 | `blk_1429.RConn2` | 阴极排气与水管理 | 当前外壳连接端口不是活动 root 边界 | 保留接口，不加 Terminator | MC-UP, MR-1429 |
| 20 | R2 | `blk_1429.RConn3` | 阴极排气与水管理 | 当前外壳连接端口不是活动 root 边界 | 保留接口，不加 Terminator | MC-UP, MR-1429 |
| 21 | R2 | `blk_1429.RConn4` | 阴极排气与水管理 | 当前外壳连接端口不是活动 root 边界 | 保留接口，不加 Terminator | MC-UP, MR-1429 |
| 22 | R2 | `blk_1429.RConn5` | 阴极排气与水管理 | 当前外壳连接端口不是活动 root 边界 | 保留接口，不加 Terminator | MC-UP, MR-1429 |
| 23 | R2 | `blk_1429.RConn6` | 阴极排气与水管理 | 当前外壳连接端口不是活动 root 边界 | 保留接口，不加 Terminator | MC-UP, MR-1429 |
| 24 | R2 | `blk_1429.RConn7` | 阴极排气与水管理 | 当前外壳连接端口不是活动 root 边界 | 保留接口，不加 Terminator | MC-UP, MR-1429 |
| 25 | R2 | `blk_1402.LConn1` | 电堆核心 | 当前 stack wrapper 的可选输入端口未作为活动边界 | 保留官方封装接口 | MC-UP, MR-1402 |
| 26 | R2 | `blk_1402.LConn2` | 电堆核心 | 当前 stack wrapper 的可选输入端口未作为活动边界 | 保留官方封装接口 | MC-UP, MR-1402 |
| 27 | R2 | `blk_1402.LConn3` | 电堆核心 | 当前 stack wrapper 的可选输入端口未作为活动边界 | 保留官方封装接口 | MC-UP, MR-1402 |
| 28 | R2 | `blk_1402.LConn4` | 电堆核心 | 当前 stack wrapper 的可选输入端口未作为活动边界 | 保留官方封装接口 | MC-UP, MR-1402 |
| 29 | R2 | `blk_1402.LConn5` | 电堆核心 | 当前 stack wrapper 的可选输入端口未作为活动边界 | 保留官方封装接口 | MC-UP, MR-1402 |
| 30 | R2 | `blk_1402.LConn6` | 电堆核心 | 当前 stack wrapper 的可选输入端口未作为活动边界 | 保留官方封装接口 | MC-UP, MR-1402 |
| 31 | R2 | `blk_1402.LConn7` | 电堆核心 | 当前 stack wrapper 的可选输入端口未作为活动边界 | 保留官方封装接口 | MC-UP, MR-1402 |
| 32 | R2 | `blk_1402.LConn8` | 电堆核心 | 当前 stack wrapper 的可选输入端口未作为活动边界 | 保留官方封装接口 | MC-UP, MR-1402 |
| 33 | R2 | `blk_1402.LConn9` | 电堆核心 | 当前 stack wrapper 的可选输入端口未作为活动边界 | 保留官方封装接口 | MC-UP, MR-1402 |
| 34 | R2 | `blk_1402.LConn10` | 电堆核心 | 当前 stack wrapper 的可选输入端口未作为活动边界 | 保留官方封装接口 | MC-UP, MR-1402 |
| 35 | R2 | `blk_1402.RConn1` | 电堆核心 | 当前 stack wrapper 的可选输出端口未作为活动边界 | 保留官方封装接口 | MC-UP, MR-1402 |
| 36 | R2 | `blk_1402.RConn2` | 电堆核心 | 当前 stack wrapper 的可选输出端口未作为活动边界 | 保留官方封装接口 | MC-UP, MR-1402 |
| 37 | R2 | `blk_1402.RConn3` | 电堆核心 | 当前 stack wrapper 的可选输出端口未作为活动边界 | 保留官方封装接口 | MC-UP, MR-1402 |
| 38 | R2 | `blk_1402.RConn4` | 电堆核心 | 当前 stack wrapper 的可选输出端口未作为活动边界 | 保留官方封装接口 | MC-UP, MR-1402 |
| 39 | R2 | `blk_1402.RConn5` | 电堆核心 | 当前 stack wrapper 的可选输出端口未作为活动边界 | 保留官方封装接口 | MC-UP, MR-1402 |
| 40 | R1 | `blk_983.A` | 阳极入口湿度观测 | 阳极湿化器入口已接入 `blk_981.B` | 保留，不改线 | MC-UP, MR-983 |
| 41 | R3 | `blk_983.x_i` | 阳极入口湿度观测 | 摩尔分数输出未注册为当前观测量 | 保留为未观测 | MC-UP, MR-983 |
| 42 | R3 | `blk_983.y_i` | 阳极入口湿度观测 | 质量分数输出未注册为当前观测量 | 保留为未观测 | MC-UP, MR-983 |
| 43 | R1 | `blk_983.W` | 阳极入口湿度观测 | 湿度比已接入 `blk_618` | 保留，不改线 | MC-UP, MR-983 |
| 44 | R1 | `blk_1265.A` | 阳极排气观测 | 阳极排气入口已接入 `blk_1015.A` | 保留，不改线 | MC-UP, MR-1265 |
| 45 | R3 | `blk_1265.x_i` | 阳极排气观测 | 摩尔分数输出未注册为当前观测量 | 保留为未观测 | MC-UP, MR-1265 |
| 46 | R1 | `blk_1265.y_i` | 阳极排气观测 | 质量分数输出已接入 `blk_1271` | 保留，不改线 | MC-UP, MR-1265 |
| 47 | R3 | `blk_1265.W` | 阳极排气观测 | 湿度比输出未注册为当前观测量 | 保留为未观测 | MC-UP, MR-1265 |
| 48 | R1 | `blk_1015.A` | 阳极排气管路 | 主气路入口已接入 `blk_1265.A` | 保留，不改线 | MC-UP, MR-1015 |
| 49 | R1 | `blk_1015.H` | 阳极排气热路 | 热端口已接入 `blk_275` | 保留，不改线 | MC-UP, MR-1015 |
| 50 | R1 | `blk_1015.B` | 阳极排气管路 | 主气路出口已接入 `blk_1016` | 保留，不改线 | MC-UP, MR-1015 |
| 51 | R4 | `blk_1015.MIn` | 阳极排气管路 | 当前不需要外部质量流量注入 | 保留未使用端口 | MC-UP, MR-1015 |
| 52 | R4 | `blk_1015.TIn` | 阳极排气管路 | 当前不需要外部温度注入 | 保留未使用端口 | MC-UP, MR-1015 |
| 53 | R4 | `blk_959.MIn` | 阳极回流 chamber | 当前回流 chamber 未启用外部质量注入 | 保留未使用端口 | MC-UP, MR-959 |
| 54 | R4 | `blk_959.TIn` | 阳极回流 chamber | 当前回流 chamber 未启用外部温度注入 | 保留未使用端口 | MC-UP, MR-959 |
| 55 | R1 | `blk_959.A` | 阳极回流 chamber | 回流入口已接入 `blk_955` | 保留，不改线 | MC-UP, MR-959 |
| 56 | R1 | `blk_959.B` | 阳极回流 chamber | 回流源支路已接入 `blk_958` | 保留，不改线 | MC-UP, MR-959 |
| 57 | R1 | `blk_959.C` | 阳极回流 chamber | 回流出口已接入 `blk_956` | 保留，不改线 | MC-UP, MR-959 |
| 58 | R3 | `blk_959.pC` | 阳极回流 chamber | 压力测量输出未进入当前 observation registry | 保留为未观测 | MC-UP, MR-959 |
| 59 | R3 | `blk_959.TC` | 阳极回流 chamber | 温度测量输出未进入当前 observation registry | 保留为未观测 | MC-UP, MR-959 |
| 60 | R3 | `blk_959.yC_i` | 阳极回流 chamber | 组分测量输出未进入当前 observation registry | 保留为未观测 | MC-UP, MR-959 |
| 61 | R1 | `blk_959.H` | 阳极回流热路 | 热端口已接入 `blk_953` 绝热支路 | 保留，不改线 | MC-UP, MR-959 |
| 62 | R1 | `blk_1295.A` | cEGR 管路 | EGR 阀和下游压力温度传感器已接入 | 保留，不改线 | MC-UP, MR-1295, MR-1418 |
| 63 | R1 | `blk_1295.H` | cEGR 热路 | 已接入 `blk_1296` 绝热支路 | 保留，不改线 | MC-UP, MR-1295 |
| 64 | R1 | `blk_1295.B` | cEGR 管路 | 已接入 Oxygen Source 的 cEGR 入口 | 保留，不改线 | MC-UP, MR-1295 |
| 65 | R4 | `blk_1295.MIn` | cEGR 管路 | 当前 cEGR 由物理网络产生，不需外部质量注入 | 保留未使用端口 | MC-UP, MR-1295 |
| 66 | R4 | `blk_1295.TIn` | cEGR 管路 | 当前 cEGR 由物理网络携带温度，不需外部温度注入 | 保留未使用端口 | MC-UP, MR-1295 |
| 67 | R2 | `blk_1423.RConn1` | cEGR BOP 封装 | 内部 Connection Port 未纳入当前活动边界 | 保留接口，不加 Terminator | MC-UP, MR-1423, MR-1418 |
| 68 | R2 | `blk_1424.RConn1` | cEGR BOP 封装 | 内部 Connection Port 未纳入当前活动边界 | 保留接口，不加 Terminator | MC-UP, MR-1424, MR-1418 |
| 69 | R1 | `blk_1134.A` | 阴极湿化器观测 | 阴极湿化器气路入口已接入 `blk_1099.B` | 保留，不改线 | MC-UP, MR-1134 |
| 70 | R3 | `blk_1134.x_i` | 阴极湿化器观测 | 摩尔分数输出未注册为当前观测量 | 保留为未观测 | MC-UP, MR-1134 |
| 71 | R3 | `blk_1134.y_i` | 阴极湿化器观测 | 质量分数输出未注册为当前观测量 | 保留为未观测 | MC-UP, MR-1134 |
| 72 | R1 | `blk_1134.W` | 阴极湿化器观测 | 湿度比已接入 `blk_1166` | 保留，不改线 | MC-UP, MR-1134 |
| 73 | R1 | `blk_1092.A` | 阴极排气管路 | 主气路入口已接入 `blk_1086` | 保留，不改线 | MC-UP, MR-1092 |
| 74 | R1 | `blk_1092.H` | 阴极排气热路 | 热端口已接入 `blk_1067` | 保留，不改线 | MC-UP, MR-1092 |
| 75 | R1 | `blk_1092.B` | 阴极排气管路 | 主气路出口已接入 `blk_1071` | 保留，不改线 | MC-UP, MR-1092 |
| 76 | R4 | `blk_1092.MIn` | 阴极排气管路 | 当前不需要外部质量流量注入 | 保留未使用端口 | MC-UP, MR-1092 |
| 77 | R4 | `blk_1092.TIn` | 阴极排气管路 | 当前不需要外部温度注入 | 保留未使用端口 | MC-UP, MR-1092 |

## 4. Runtime warning outside the 77 structural rows

| ID | Object | Owner | Impact | Disposition | Evidence |
|---|---|---|---|---|---|
| RT-H2-20260729 | `Anode_Hydrogen_BOP/Hydrogen Source` residual dangling-line warning | 阳极氢源与 solver connectivity | 修复前 `sim()` 重复报告 warning；修复后 Hydrogen Source 内部 12/12 条线均已解析连接，10 s smoke 和正式 P0 3600 s 均未再报告该 warning | 已关闭。通过 `model_edit` 断开 `Pressure-Reducing Valve/LConn1` 和 `Fuel Tank/A` 的旧分支，再重建唯一直接物理连接；未删除 Solver Configuration、未增加人工质量源或 Terminator | MR-H2-20260729、SIM-H2-SMOKE-20260729、SIM-P0-3600-20260729 |

P0 acceptance 期间还观察到 `getChecksumImpl` 对 `ToWorkspace` 的 `Timeseries` 兼容性提示。该提示不属于上述 77 条 `model_check` 结构行，也没有产生 SimulationOutput error；后续单独作为 runner/toolchain hygiene 项处理，不修改物理网络以消除它。

## 5. Current conclusion

- 77 条结构 warning 已逐条分类并有当前读回证据；本轮没有发现需要新增物理连接、Terminator、人工质量源或删除 Solver Configuration 的 P0 阻断项。
- `model_check(unconnected_lines)` healthy，且 P0 3600 s Current/Power 完成；Voltage 仍是收敛问题，不是这些 warning 已被“清零”的证据。
- 该 ledger 不改变 S5 的剩余范围：Hydrogen Source runtime warning 已关闭；cold Voltage 的周期响应已纳入 P0 验收，但 600 s/面板/完整 cold 矩阵仍需后续专项处理。
