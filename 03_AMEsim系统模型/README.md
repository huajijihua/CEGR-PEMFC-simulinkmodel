# AMEsim 系统模型——跨工作区引用

本项目 `03_AMEsim系统模型/` 不直接持有 `.ame` 模型文件。AMEsim 正式建模主工作区位于：

```text
E:\agentwork_AMEsim_0625
```

## 工作区结构

```
E:\agentwork_AMEsim_0625/
├── AGENTS.md
├── AMEsim-Codex工作流记忆.md
├── 系统级仿真建模路线规划.md
├── 项目Codex-AMEsim系统建模工作流.md
└── workbench/
    ├── pure_amesim_v0/         # 纯 AMEsim 原生脚本（已验证 smoke test）
    │   ├── DynamicPEMFCstackH2.ame
    │   ├── QuasiStaticPEMFCstackH2.ame
    │   ├── module_registry.json
    │   ├── parameter_registry.json
    │   └── ...
    └── circuit_api_poc_v2/     # Circuit API 概念验证（POC）
        ├── CodexCircuitPOC.ame
        ├── poc_architecture_schema.json
        └── ...
```

## 协作规范

1. **参数传递**：通过 `interface_contract`（JSON 格式）在 PEMFC-cEGR Simulink 模型和 AMEsim 模型之间同步参数
2. **合同模板**：存放在 `00_支撑材料/interface_contracts/template.json`
3. **结果引用**：AMEsim 结果以 KPI 摘要形式回灌到本项目，不复制完整 `.ame` 模型
4. **工具入口**：`D:\amesimsoft\Simcenter_Amesim_2511\Amesim\AMEPython.bat`

## Claude-AMEsim 工作流（2026-06-29 建立）

AMEsim 主工作区已完成 Claude 入口配置，切换目录后按顺序读取以下文件即可重建完整上下文：

| 优先级 | 文件 | 内容 |
|--------|------|------|
| 1 | `E:\agentwork_AMEsim_0625\CLAUDE.md` | Claude 工作区规则和自举指南 |
| 2 | `E:\agentwork_AMEsim_0625\SHARED_CONTEXT.md` | Codex-Claude 共享事实和已验证结论 |
| 3 | `E:\agentwork_AMEsim_0625\docs\00_AMEsim环境与API完整参考.md` | 环境、两套 API 完整参考、Data Path 规则 |
| 4 | `E:\agentwork_AMEsim_0625\docs\01_Claude-AMEsim工作流SOP.md` | 三种任务类型的标准操作程序 |
| 5 | `E:\agentwork_AMEsim_0625\docs\02_PEMFC-cEGR建模交接.md` | PEMFC-cEGR 任务背景、分阶段计划、关键参数 |

PEMFC-cEGR 建模任务目录：`E:\agentwork_AMEsim_0625\workbench\pemfc_cegr_v0\`（待填充）
