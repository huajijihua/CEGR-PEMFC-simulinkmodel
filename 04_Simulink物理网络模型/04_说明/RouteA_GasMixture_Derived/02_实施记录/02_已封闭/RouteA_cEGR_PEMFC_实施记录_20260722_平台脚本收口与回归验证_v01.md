# RouteA cEGR-PEMFC 实施记录：平台脚本收口与回归验证

文件类型：实施记录（增量维护；本卷已封闭）  
记录日期：2026-07-22  
当前决策和路线入口：[模型裁决与资产处置](../../01_当前指导/RouteA_cEGR_PEMFC_模型裁决与资产处置_v01.md)、[收敛实施路线图](../../01_当前指导/RouteA_cEGR_PEMFC_收敛实施路线图_v01.md)

本卷记录 v09 初态、活动脚本核心拆分、归档和脚本变更后的回归证据。原始完整记录见 [实施记录分卷归档](../../../../../99_历史归档/2026-07-22_Stage1_Implementation_Record_Split/README.md)。

## 1. 平台与脚本收口

- Current、Power、Voltage 三个 v09 branch-compatible 初态完成多周期条件化、原子提升和 2 s 热启动 smoke；跨周期稳定性门均小于 `0.5%`。
- 活动脚本目录收口为统一 electrical-boundary runner、通用输入/KPI/气体/水账本辅助、统一初态链和唯一 cEGR unittest；旧 demo 完整实现、重复初态 wrapper、观测标记脚本和独立阀测试实现移入 `99_历史归档/2026-07-22_Stage1_Script_Core_Split/`。
- 活动 `run_routeA_platform_demo.m` 保留为 10 s 兼容薄 wrapper，不作为正式矩阵、敏感性分析或参数标定入口。

## 2. 短验证与 600 s 风险回归

- 活动 MATLAB 文件通过 Code Analyzer；cEGR 阀 unittest 的关闭正向、关闭反向和打开正向构成判断通过。
- Current、Power、Voltage 各 1 个短 smoke 输入装配成功，`boundaryType` 正确、`StartTime=0`、输出有限且 case 通过；demo summary 兼容变量继续生成。
- 脚本收口后 2-worker 并行 Current 双案例 600 s 回归完成，`2/2 completed`、`failed=0`、`study.passed=1`。
- 随后 Current、Power、Voltage 各选择一个 nominal、cEGR=`0.10` 工况执行 600 s steady 回归，三项均为 `1/1 completed`、`failed=0`、`casePassed=1`、`studyPassed=1`。

## 3. 不可变边界与剩余风险

- 上述回归均使用 `resultFile=""`；没有覆盖三份正式 600 s `.mat`。模型 `Dirty=off`，模型和正式结果文件哈希保持不变，`git diff --check` 通过。
- 2-worker pool 保持开启。剩余风险仅为脚本收口后未重复完整 `9 Current + 3 Power + 3 Voltage` formal 矩阵；该风险由既存 formal 结果读回和三种边界各一例 600 s 回归共同限定，不能把单例回归写成完整矩阵证据。

本卷已封闭。后续阶段必须新建日期/工作包分卷，不向本文件无限追加。
