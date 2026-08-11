# Route A cEGR-PEMFC P9 首启审计缓存与 P8 汇总表收口

## 范围

- 修复面板首次启动时模型尚未建立 `Simulink.findVars` cached 结果导致的初始化失败。
- 按当前 P8 代码重新生成模型-面板参数汇总表；不修改 `.slx` 拓扑、设备物理方程或模型保存状态。

## 实际实现

1. `routeA_audit_parameter_inventory` 优先使用 `SearchMethod=cached`；缓存不存在时自动回退到官方 `SearchMethod=compiled` 查询。
2. 面板仍通过 `routeA_audit_parameter_inventory(false)` 获取只读模型参数目录，首启不再要求操作人员预先更新模型图。
3. 使用 `routeA_audit_parameter_inventory(true)` 重新生成 `RouteA_cEGR_PEMFC_模型-面板参数汇总表_v01.md`，覆盖 P8 热管理输入后的当前参数数量。

## 验证证据

| 验证 | 实际结果 |
|---|---|
| 审计器静态检查 | 无新增 error/warning；保留 2 条既有 info |
| 无缓存首启审计 | 从未加载模型状态调用审计器成功；`ACTIVE=86`、`MISMATCH=0`、`UNEXPOSED=23` |
| 无缓存首启面板 | 面板实例创建成功，`UIFigure.Visible=on`、`isvalid=1` |
| 汇总表生成 | 生成时间 `2026-08-11 15:07:14`；工作区变量 `138`、活动参数 `86`、引用变量 `86`、失配写入目标 `0` |
| 面板契约回归 | `passed=1`、`simulationStarted=0`、非法输入拒止 `21`、设备页/图谱/cEGR 派生几何/显式 Profile 均通过 |
| 模型状态 | `PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01` 保持 `Dirty=off` |

## 未解决边界

- 契约测试在计算 cold-start checksum 时仍输出既有 `To Workspace` 的 `Timeseries` 格式警告；本次未改变仿真配置，也未启动 `sim()`。
- 本记录验证的是首启可用性、参数目录一致性和输入契约，不替代 P8 已完成的热管理动态响应验证。
