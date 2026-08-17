# Route A cEGR-PEMFC 外部案例与归档资产索引

文件类型：当前指导（资产恢复与边界）  
适用范围：不属于活动 Route A `platform_default` 的历史模型、台架数据、标定脚本和归档结果。

## 1. 使用原则

1. 当前活动资产、唯一主模型和参数分层以[模型裁决与资产处置](RouteA_cEGR_PEMFC_模型裁决与资产处置_v01.md)为准。
2. 本文列出的资产均不在当前默认 MATLAB path、默认参数链或默认验收标准内；路径仅表示历史来源，不表示当前工作树可直接调用。
3. 需要回放时，先从外部归档或 Git 历史恢复到显式 `external_case` 工作位置，记录源版本、适用工况、单位和恢复范围，再由专用开关启用。不得将恢复资产复制为新的活动主线。

## 2. 历史分支

| 分支 | 历史来源 | 角色与边界 |
|---|---|---|
| 车载系统 v3 | `01_自吸方案/01_车载系统_10kW_GZS60_v3/` | L2 标定型历史背景；含 GZS60 膜加湿器、中冷器和空压机 BOP。 |
| 台架测试 v1 | `01_自吸方案/02_台架测试_10kW/` | L2 标定型历史背景；无加湿器，DQ60 空压机等效。 |
| 简化台架 v1 | `01_自吸方案/03_台架测试_10kW_简化版/` | 外部案例；直接以台架入堆条件为边界，不是通用平台。 |
| COMSOL 机理 | `02_多物理场机理模型演示/` | 外置归档的 L3 局部机理资产；Route A 当前不依赖其文件。 |

## 3. 简化台架 v1 的可恢复入口

恢复后只能作为 `external_case` 使用：

| 用途 | 历史入口 | 边界 |
|---|---|---|
| 参数默认值 | `init_testbench_10kw_simplified_defaults.m` | 仅旧台架 P 结构体。 |
| 工况装配 | `init_testbench_10kw_simplified_egr(caseIndex, dataMode)` | 仅旧稳态点回放。 |
| 电压、压力、温度标定 | `calibrate_testbench_10kw_simplified_*.m` | 不得提升为 Route A 默认标定。 |
| 批量审计与进气研究 | `run_core_fix_v01_audit.m`、`run_testbench_10kw_simplified_custom_inlet_study.m` | 仅回归或边界研究。 |
| 模型 | `CEGR_TestBench_10kW_SimplifiedEGR_v01.slx` | 仅恢复后的外部案例模型。 |

`simplified_*.csv`、`combined_noegr_cegr_fit_points.csv`、DQ60 map、10 kW workbook 及其派生结果不得被活动 Route A 初始化链自动读取。
