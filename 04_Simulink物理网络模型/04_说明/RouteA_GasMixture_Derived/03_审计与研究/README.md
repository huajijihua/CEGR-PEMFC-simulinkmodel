# 审计与研究材料

本目录提供只读资产审计和 CEGR 文献/模型映射。它们用于判断风险、来源和研究准入，不直接定义当前模型结构。

| 文件 | 类型 | 使用边界 |
|---|---|---|
| RouteA_cEGR_PEMFC_Platform_current-audit_20260724_v01.md | 当前资产审计快照 | 说明当前阻断项；随新读回形成新日期版本 |
| RouteA_cEGR_PEMFC_活动资产盘点_20260811_v01.md | 面板/模型/runner 真实资产盘点 | 以当前 `.slx`、MATLAB 脚本和实际测试为证据，给出平台研究准入门槛 |
| RouteA_cEGR_PEMFC_literature-review-and-model-mapping_v01.md | 文献与模型映射 | 提供机制、变量口径和证据等级；不直接覆盖默认参数 |
| RouteA_cEGR_PEMFC_model_check_warning_ledger_20260729_v01.md | 当前结构 warning ledger | 逐条记录 77 条 `unconnected_ports` warning 的 owner、影响、处置和读回证据；不替代模型裁决 |

若审计结果与指导文件冲突，应先更新模型裁决，再形成新的实施记录；不要在本目录内直接改写历史审计结论。
