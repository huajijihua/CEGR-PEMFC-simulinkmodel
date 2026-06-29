# 项目 Codex-COMSOL 自动建模工作流

本说明面向普适的 Codex-COMSOL 自动建模，不是某个标定脚本的说明。当前 PEMFC-cEGR 多物理场模型只是默认应用场景：Codex 负责规格化、脚本化、证据链和验证闭环；COMSOL 负责几何、多物理场、边界条件、网格、求解和局部机理响应。

## 固定工具入口

- COMSOL 根目录：`D:\COMSOL63\Multiphysics`
- GUI：`D:\COMSOL63\Multiphysics\bin\win64\comsol.exe`
- Server：`D:\COMSOL63\Multiphysics\bin\win64\comsolmphserver.exe`
- Batch：`D:\COMSOL63\Multiphysics\bin\win64\comsolbatch.exe`
- MATLAB LiveLink：`D:\COMSOL63\Multiphysics\mli`
- 默认 Server 地址：`localhost:2036`
- 当前项目模型目录：`E:\agentwork_pemfc_cEGR_0519\02_多物理场机理模型演示`

## 通用任务分型

1. 新建模型：先写清 `model_spec`、`build_plan` 和 `verification_plan`，再通过 API 创建 geometry、selection、materials、physics、mesh、study、solver 和 probes。
2. 增量修改：先只读盘点当前 `.mph`，定位真实 tag、selection、feature 和 solver，再做小步修改。
3. 模型审查：只读检查模型结构、方程证据、边界条件、求解器链和结果变量，默认不修改。
4. 仿真验证：优先运行最小必要工况、已有 study 或已有验证脚本，不默认全模型长时间求解。

## 自动建模主流程

1. 定义问题：研究目标、模型维度、几何抽象、物理场、耦合关系、输入输出、工况、约束和验收指标。
2. 定义接口：参数名、单位、边界变量、材料来源、selection 命名、probe/derived value 输出和结果读取方式。
3. 只读盘点：连接同一 COMSOL Server，读取当前模型 tag、组件、几何、材料、physics、feature、selection、study、solver 和 solution 摘要。
4. 构建或修改：按 `geometry -> selection -> material -> physics feature -> mesh -> study/solver -> probe/result` 的顺序小步实施。
5. 回读验证：每一步修改后读取真实 API 路径和值，确认节点存在、表达式正确、selection 指向正确。
6. 求解验证：先做局部检查、粗网格或单工况 smoke test，再扩大到目标 study。
7. 结果审计：只输出 KPI、关键变量、证据路径、错误栈摘要和剩余风险。

## 共享会话规则

1. 用户启动 COMSOL Server，默认端口 `2036`。
2. 用户用 COMSOL GUI 连接该 Server，并打开目标 `.mph`。
3. Codex 通过 MATLAB LiveLink、Java API、Python/mph 或等价 API 连接同一个 Server 会话。
4. 默认由 GUI 检查并保存模型；后台脚本不得擅自保存 `.mph`。
5. 同一模型默认只允许一条 Codex 控制链路，避免 GUI、MATLAB LiveLink、Python/mph 或后台脚本并发修改。

## 证据链要求

- 不直接按二进制、XML 或文本方式修改 `.mph`。
- 不假设 `comp1`、`geom1`、`solid`、`ht`、`spf` 等默认标签可靠；必须从当前模型读取真实 tag。
- 涉及边界条件、入口出口、反应、源项、材料和初始值时，必须追到具体 feature 节点。
- 父 physics 节点设置不能替代完整方程或边界证据。
- 典型证据路径应类似 `component/comp1/physics/br/feature/inl1`、`component/comp1/material/mat1`、`study/std1`、`solver/sol1`。

## Token 与产物控制

- 不默认回传完整模型树、完整 Java dump、完整变量表、完整求解日志、完整网格信息或批量图片。
- 不默认生成模型副本、CSV、报告或截图。
- 必须生成中间产物时，放入任务专用目录，并在任务结束时说明保留文件及用途。
- Codex 输出应压缩为模型规格、操作摘要、证据路径、KPI、失败原因和下一步建议。

## 只读盘点入口

推荐脚本：

```matlab
addpath('E:\agentwork_pemfc_cEGR_0519\02_多物理场机理模型演示\02_脚本')
summary = comsol_readonly_inventory();
```

该脚本只是通用流程中的“只读盘点工具”：连接 `localhost:2036`，读取当前 Server 中的模型摘要，不运行求解、不修改参数、不保存模型、不导出结果文件。

## 常见排查

- `mphstart` 找不到：确认 MATLAB 已添加 `D:\COMSOL63\Multiphysics\mli`。
- 无法连接 Server：确认 `comsolmphserver.exe` 已启动，端口为 `2036`，且防火墙没有拦截本机连接。
- Server 中没有模型：用 GUI 连接同一 Server 并打开目标 `.mph`，或确认脚本没有连接到另一个端口。
- GUI 未显示脚本修改：在 GUI 中选中相关节点，必要时刷新、重建几何或重新计算相关 study。
- 求解器旧报错干扰判断：区分当前有效 study/solver/solution 与历史残留求解节点，不用旧失败日志直接否定当前求解链。
