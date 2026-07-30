# Route A cEGR-PEMFC P3 面板布局回归修复实施记录

日期：2026-07-30
对应计划：[RouteA_cEGR_PEMFC_P3_阳极与系统性能参数开放实施计划_v01.md](../../01_当前指导/RouteA_cEGR_PEMFC_P3_阳极与系统性能参数开放实施计划_v01.md)
适用面板：`04_Simulink物理网络模型/03_脚本/RouteA_GasMixture_Derived/RouteA_Panel_v01.m`
适用模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`

## 1. 本轮范围

针对用户截图中的两处 P3 面板回归进行布局修复：高级页打开后四层模式切换栏被内容覆盖，以及阳极高级区标题控件在同一坐标重复绘制。本轮只改面板布局与文字排版，不改 `simCase`、校验器、`SimulationInput`、正式模型或 runner。

## 2. 实际完成项

- 将左侧拆为固定的 `LeftPanel` 顶栏和唯一的 `ConfigScrollPanel` 滚动区；`ModeButtonGroup` 直接挂在 `LeftPanel`，避免被 `AdvancedPanel` 覆盖或随页面滚动隐藏。
- 将原 `ConfigCanvas` 放入 `ConfigScrollPanel`，并关闭 `HelpPanel`/`AdvancedPanel` 的内部滚动，四个配置页共用同一滚动容器。
- 将配置画布高度提升到 `1480`，并在窗口首次显示前执行一次布局，避免最大化窗口首次绘制使用旧尺寸。
- 将阳极区的重复标题拆为单一粗体标题和一行短说明，避免两个 `uilabel` 占用 `[10 280 ...]` 同一位置。
- 将阳极右列输入框统一放入 `x=345`、宽度 `85` 的窄列，标签字号调整为 `10`；右边界为 `430`，适配高级面板初始宽度和后续自适应宽度。

## 3. 验证证据

- MATLAB Code Analyzer：无 error 或 warning；仅保留 4 条既有 info 级动态数组增长提示，位置在结果表/曲线历史循环，不涉及本轮布局代码。
- `git diff --check -- RouteA_Panel_v01.m`：通过。
- 静态读回确认：模式栏父对象为 `LeftPanel`，滚动调用统一指向 `ConfigScrollPanel`；阳极粗体标题位于 `y=280`，说明位于 `y=260`，输入行位于 `y=240/205/170/135/100`，不再共用标题坐标。
- 本轮未运行 Simulink 工况，未保存正式 `.slx`，未新增仿真 KPI 或结果图片；当前已打开窗口未由 agent 操作或重启，需用户按最新版代码重新查看窗口。

## 4. 未决项

- 仍需用户在最新版窗口中确认四层模式栏的实际视觉位置，以及窄窗口下阳极长标签的显示密度。
- 若用户检查发现固定模式栏与左侧配置标题仍有遮挡，只调整该 UI 层的绝对位置，不改变 P3 输入链路。
