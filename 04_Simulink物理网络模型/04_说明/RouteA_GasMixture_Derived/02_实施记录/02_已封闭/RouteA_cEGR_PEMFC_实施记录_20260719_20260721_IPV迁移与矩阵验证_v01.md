# RouteA cEGR-PEMFC 实施记录：I/P/V 迁移与矩阵验证

文件类型：实施记录（增量维护；本卷已封闭）  
记录范围：2026-07-19 至 2026-07-21  
当前决策和路线入口：[模型裁决与资产处置](../../01_当前指导/RouteA_cEGR_PEMFC_模型裁决与资产处置_v01.md)、[收敛实施路线图](../../01_当前指导/RouteA_cEGR_PEMFC_收敛实施路线图_v01.md)

本卷记录统一 Current/Power/Voltage profile、输入装配、初态匹配和正式研究协议形成前后的阶段证据。拆分前的完整历史细节保存在 [原始增量总记录](../../../../../99_历史归档/2026-07-22_Stage1_Implementation_Record_Split/RouteA_cEGR_PEMFC_实施与验证路线_v01_原始增量总记录.md)。

## 1. 通用运行合同

- 研究入口收口为 profile 规范化 -> `SimulationInput` 装配 -> 一个 `.slx` -> `SimulationOutput` -> 统一 KPI/气体/水账本审计。
- 一个 study 只允许一种电边界：`Current`、`Power` 或 `Voltage`；三种边界分开调用，不按边界复制模型或 runner。
- 正常稳态研究采用逻辑 `600 s`、尾窗 `[540,600] s`、`StartTime=0 s`、`MaxStep=5 s`；瞬态研究保留完整时间曲线。
- 并行只改变调度方式，不修改模型；正式入口支持 serial/parsim，默认 2 workers、上限 4 workers。

## 2. I/P/V 分支与证据

- Current、Power、Voltage 均形成与 Electrical Load 分支匹配的 `ModelOperatingPoint`，Power/Voltage 不能直接冒用 Current 快照。
- 2026-07-20 完成直接阀面积配置下的 low/nominal/high 恒流主证据；2026-07-21 完成 nominal 恒功率和堆端恒电压接口验证。
- 恒功率验证证明的是堆端负载命令下的系统气路和 cEGR 响应，不等同于真实压缩机轴功率、效率或整车功率系统匹配。
- 堆端恒电压验证证明的是 Electrical Load 电压控制接口和电流联动，不外推为 DCDC 或母线稳压能力。

## 3. 结果边界

气相物种闭合、供氧、cEGR、压力方向、有限值和选定 WM-L1+ 气相账本已形成统一审计链；显式液水库存、液水输运/排液和分离器效率仍未闭合。

本卷已封闭。2026-07-22 的平台收口、脚本归档和回归验证不再追加到本卷。
